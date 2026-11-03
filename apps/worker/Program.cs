using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using Newtonsoft.Json;
using Npgsql;
using OpenTelemetry;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using Prometheus;
using StackExchange.Redis;

namespace Worker
{
    public class Program
    {
        private const string ServiceName = "worker-app";

        // ───────────────────────────────────────────────────────
        // Prometheus Metrics
        // ───────────────────────────────────────────────────────

        private static readonly Counter VotesProcessed = Metrics.CreateCounter(
            "worker_votes_processed_total",
            "Total votes processed",
            new CounterConfiguration
            {
                LabelNames = new[] { "service" },
            });

        private static readonly Counter VoteErrors = Metrics.CreateCounter(
            "worker_vote_errors_total",
            "Total vote processing errors",
            new CounterConfiguration
            {
                LabelNames = new[] { "service", "reason" },
            });

        private static readonly Histogram VoteProcessingDuration = Metrics.CreateHistogram(
            "worker_vote_processing_duration_seconds",
            "Time taken to process a single vote",
            new HistogramConfiguration
            {
                LabelNames = new[] { "service" },
                Buckets = new[] { 0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0 },
            });

        private static readonly Gauge QueueDepth = Metrics.CreateGauge(
            "worker_redis_queue_depth",
            "Current depth of the Redis votes queue");

        public static int Main(string[] args)
        {
            var otelEndpoint =
                Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT");

            var tracerProviderBuilder = Sdk.CreateTracerProviderBuilder()
                .SetResourceBuilder(
                    ResourceBuilder.CreateDefault()
                        .AddService(
                            serviceName: ServiceName,
                            serviceVersion: "1.0.0")
                        .AddAttributes(
                            new[]
                            {
                                new KeyValuePair<string, object>(
                                    "deployment.environment",
                                    Environment.GetEnvironmentVariable("ENV") ?? "prd"),
                            }))
                .AddSource("Worker");

            /*
             * Do not construct new Uri("") when OTEL_EXPORTER_OTLP_ENDPOINT
             * is missing. That would throw UriFormatException at startup.
             */
            if (!string.IsNullOrWhiteSpace(otelEndpoint))
            {
                if (!Uri.TryCreate(
                        otelEndpoint,
                        UriKind.Absolute,
                        out var parsedOtelEndpoint))
                {
                    Console.Error.WriteLine(
                        "[ERROR] Invalid OTEL_EXPORTER_OTLP_ENDPOINT.");

                    return 1;
                }

                tracerProviderBuilder.AddOtlpExporter(
                    options =>
                    {
                        options.Endpoint = parsedOtelEndpoint;
                    });
            }
            else
            {
                Console.WriteLine(
                    "[WARN] OTEL_EXPORTER_OTLP_ENDPOINT is not configured; " +
                    "OTLP export is disabled.");
            }

            using var tracerProvider = tracerProviderBuilder.Build();

            using var metricServer = new MetricServer(port: 9090);
            metricServer.Start();

            Console.WriteLine(
                "[INFO] Prometheus metrics server started on :9090/metrics");

            var databaseConnectionString = BuildDatabaseConnectionString();
            var redisHost =
                Environment.GetEnvironmentVariable("REDIS_HOST") ?? "redis";

            try
            {
                var tracer = TracerProvider.Default.GetTracer("Worker");

                using var pgsql =
                    OpenDbConnection(databaseConnectionString);

                using var redisConnection =
                    OpenRedisConnection(redisHost);

                var redis = redisConnection.GetDatabase();

                var definition = new
                {
                    vote = string.Empty,
                    voter_id = string.Empty,
                };

                while (true)
                {
                    Thread.Sleep(100);

                    /*
                     * ConnectionMultiplexer is designed to reconnect
                     * automatically. AbortOnConnectFail=false is configured
                     * in OpenRedisConnection.
                     */
                    try
                    {
                        QueueDepth.Set(redis.ListLength("votes"));
                    }
                    catch (RedisException ex)
                    {
                        Console.Error.WriteLine(
                            $"[WARN] Could not read Redis queue depth: {ex.Message}");
                    }

                    RedisValue redisValue;

                    try
                    {
                        redisValue = redis.ListLeftPop("votes");
                    }
                    catch (RedisException ex)
                    {
                        Console.Error.WriteLine(
                            $"[WARN] Redis read failed: {ex.Message}");

                        Thread.Sleep(1000);
                        continue;
                    }

                    if (redisValue.IsNullOrEmpty)
                    {
                        EnsureDatabaseConnection(
                            pgsql,
                            databaseConnectionString);

                        using var keepAliveCommand = pgsql.CreateCommand();
                        keepAliveCommand.CommandText = "SELECT 1";
                        keepAliveCommand.ExecuteNonQuery();

                        continue;
                    }

                    var json = redisValue.ToString();

                    using var timer = VoteProcessingDuration
                        .Labels(ServiceName)
                        .NewTimer();

                    using var span = tracer.StartActiveSpan("process-vote");

                    try
                    {
                        var voteData =
                            JsonConvert.DeserializeAnonymousType(
                                json,
                                definition);

                        if (voteData == null)
                        {
                            throw new JsonSerializationException(
                                "The vote payload could not be deserialized.");
                        }

                        if (string.IsNullOrWhiteSpace(voteData.voter_id))
                        {
                            throw new JsonSerializationException(
                                "The vote payload does not contain voter_id.");
                        }

                        if (string.IsNullOrWhiteSpace(voteData.vote))
                        {
                            throw new JsonSerializationException(
                                "The vote payload does not contain vote.");
                        }

                        span.SetAttribute("vote.option", voteData.vote);
                        span.SetAttribute("voter.id", voteData.voter_id);

                        Console.WriteLine(
                            $"[INFO] Processing vote. " +
                            $"vote={voteData.vote}, " +
                            $"voter_id={voteData.voter_id}");

                        EnsureDatabaseConnection(
                            pgsql,
                            databaseConnectionString);

                        UpdateVote(
                            pgsql,
                            voteData.voter_id,
                            voteData.vote);

                        VotesProcessed.Labels(ServiceName).Inc();

                        // TelemetrySpan.SetStatus accepts one Status argument.
                        span.SetStatus(Status.Ok);
                    }
                    catch (Exception ex)
                    {
                        VoteErrors
                            .Labels(ServiceName, ex.GetType().Name)
                            .Inc();

                        /*
                         * Correct OpenTelemetry shim API:
                         * SetStatus receives one Status object.
                         */
                        span.SetStatus(
                            Status.Error.WithDescription(ex.Message));

                        // Records exception type, message and stack trace.
                        span.RecordException(ex);

                        Console.Error.WriteLine(
                            $"[ERROR] Vote processing failed: {ex}");
                    }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(
                    $"[ERROR] Fatal worker error: {ex}");

                return 1;
            }
        }

        private static string BuildDatabaseConnectionString()
        {
            var builder = new NpgsqlConnectionStringBuilder
            {
                Host =
                    Environment.GetEnvironmentVariable("DB_HOST")
                    ?? "127.0.0.1",

                Port = ParsePort(
                    Environment.GetEnvironmentVariable("DB_PORT"),
                    5432),

                Username =
                    Environment.GetEnvironmentVariable("DB_USER")
                    ?? "postgres",

                Password =
                    Environment.GetEnvironmentVariable("DB_PASSWORD")
                    ?? "postgres",

                Database =
                    Environment.GetEnvironmentVariable("DB_NAME")
                    ?? "postgres",
            };

            return builder.ConnectionString;
        }

        private static int ParsePort(string value, int defaultValue)
        {
            return int.TryParse(value, out var port) &&
                   port > 0 &&
                   port <= 65535
                ? port
                : defaultValue;
        }

        private static NpgsqlConnection OpenDbConnection(
            string connectionString)
        {
            while (true)
            {
                NpgsqlConnection connection = null;

                try
                {
                    connection =
                        new NpgsqlConnection(connectionString);

                    connection.Open();

                    Console.WriteLine(
                        "[INFO] Connected to database.");

                    using var command = connection.CreateCommand();

                    command.CommandText =
                        @"CREATE TABLE IF NOT EXISTS votes (
                              id VARCHAR(255) NOT NULL PRIMARY KEY,
                              vote VARCHAR(255) NOT NULL
                          )";

                    command.ExecuteNonQuery();

                    return connection;
                }
                catch (SocketException)
                {
                    connection?.Dispose();

                    Console.Error.WriteLine(
                        "[WARN] Waiting for database (socket error).");

                    Thread.Sleep(1000);
                }
                catch (DbException ex)
                {
                    connection?.Dispose();

                    Console.Error.WriteLine(
                        $"[WARN] Waiting for database: {ex.Message}");

                    Thread.Sleep(1000);
                }
            }
        }

        private static void EnsureDatabaseConnection(
            NpgsqlConnection connection,
            string connectionString)
        {
            if (connection.State == ConnectionState.Open)
            {
                return;
            }

            Console.WriteLine(
                "[WARN] Reconnecting to database.");

            connection.ConnectionString = connectionString;
            connection.Open();
        }

        private static ConnectionMultiplexer OpenRedisConnection(
            string hostname)
        {
            var ipAddress = GetIp(hostname);

            Console.WriteLine(
                $"[INFO] Found Redis at {ipAddress}.");

            var options = new ConfigurationOptions
            {
                AbortOnConnectFail = false,
                ConnectRetry = 5,
            };

            options.EndPoints.Add(ipAddress, 6379);

            while (true)
            {
                try
                {
                    Console.WriteLine(
                        "[INFO] Connecting to Redis.");

                    return ConnectionMultiplexer.Connect(options);
                }
                catch (RedisConnectionException ex)
                {
                    Console.Error.WriteLine(
                        $"[WARN] Waiting for Redis: {ex.Message}");

                    Thread.Sleep(1000);
                }
            }
        }

        private static string GetIp(string hostname)
        {
            var address = Dns.GetHostEntry(hostname)
                .AddressList
                .FirstOrDefault(
                    candidate =>
                        candidate.AddressFamily ==
                        AddressFamily.InterNetwork);

            if (address == null)
            {
                throw new InvalidOperationException(
                    $"No IPv4 address was found for Redis host '{hostname}'.");
            }

            return address.ToString();
        }

        private static void UpdateVote(
            NpgsqlConnection connection,
            string voterId,
            string vote)
        {
            using var command = connection.CreateCommand();

            /*
             * PostgreSQL UPSERT avoids catching every DbException and
             * incorrectly treating it as a duplicate-key condition.
             */
            command.CommandText =
                @"INSERT INTO votes (id, vote)
                  VALUES (@id, @vote)
                  ON CONFLICT (id)
                  DO UPDATE SET vote = EXCLUDED.vote";

            command.Parameters.AddWithValue("id", voterId);
            command.Parameters.AddWithValue("vote", vote);

            command.ExecuteNonQuery();
        }
    }
}
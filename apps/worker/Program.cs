using System;
using System.Data.Common;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;
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
        // ───────────────────────────────────────────────────────
        // Prometheus Metrics
        // ───────────────────────────────────────────────────────
        private static readonly Counter VotesProcessed = Metrics
            .CreateCounter("worker_votes_processed_total", "Total votes processed",
                new CounterConfiguration { LabelNames = new[] { "service" } });

        private static readonly Counter VoteErrors = Metrics
            .CreateCounter("worker_vote_errors_total", "Total vote processing errors",
                new CounterConfiguration { LabelNames = new[] { "service", "reason" } });

        private static readonly Histogram VoteProcessingDuration = Metrics
            .CreateHistogram("worker_vote_processing_duration_seconds",
                "Time taken to process a single vote",
                new HistogramConfiguration
                {
                    LabelNames = new[] { "service" },
                    Buckets = new[] { 0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0 },
                });

        private static readonly Gauge QueueDepth = Metrics
            .CreateGauge("worker_redis_queue_depth", "Current depth of the Redis votes queue");

        public static int Main(string[] args)
        {
            // ───────────────────────────────────────────────────────
            // OpenTelemetry Tracing
            // ───────────────────────────────────────────────────────
            var otelEndpoint = Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT")
                ?? "http://otel-collector.ns-observability.svc.cluster.local:4317";

            using var tracerProvider = Sdk.CreateTracerProviderBuilder()
                .SetResourceBuilder(
                    ResourceBuilder.CreateDefault()
                        .AddService("worker-app", serviceVersion: "1.0.0")
                        .AddAttributes(new[] {
                            new System.Collections.Generic.KeyValuePair<string, object>(
                                "deployment.environment",
                                Environment.GetEnvironmentVariable("ENV") ?? "prd")
                        }))
                .AddSource("Worker")
                .AddOtlpExporter(opts =>
                {
                    opts.Endpoint = new Uri(otelEndpoint);
                })
                .Build();

            // ───────────────────────────────────────────────────────
            // Prometheus metrics HTTP server on :9090
            // ───────────────────────────────────────────────────────
            var metricServer = new MetricServer(port: 9090);
            metricServer.Start();
            Console.WriteLine("[INFO] Prometheus metrics server started on :9090/metrics");

            try
            {
                var tracer = TracerProvider.Default.GetTracer("Worker");

                var pgsql = OpenDbConnection(
                    $"Server={Environment.GetEnvironmentVariable("DB_HOST") ?? "127.0.0.1"};" +
                    $"Port={Environment.GetEnvironmentVariable("DB_PORT") ?? "5432"};" +
                    $"Username={Environment.GetEnvironmentVariable("DB_USER") ?? "postgres"};" +
                    $"Password={Environment.GetEnvironmentVariable("DB_PASSWORD") ?? "postgres"};" +
                    $"Database={Environment.GetEnvironmentVariable("DB_NAME") ?? "postgres"};");

                var redisHost = Environment.GetEnvironmentVariable("REDIS_HOST") ?? "redis";
                var redisConn = OpenRedisConnection(redisHost);
                var redis = redisConn.GetDatabase();

                var keepAliveCommand = pgsql.CreateCommand();
                keepAliveCommand.CommandText = "SELECT 1";

                var definition = new { vote = "", voter_id = "" };
                while (true)
                {
                    Thread.Sleep(100);

                    if (redisConn == null || !redisConn.IsConnected)
                    {
                        Console.WriteLine("[WARN] {\"message\":\"Reconnecting Redis\"}");
                        redisConn = OpenRedisConnection(redisHost);
                        redis = redisConn.GetDatabase();
                    }

                    // Update queue depth gauge
                    try { QueueDepth.Set(redis.ListLength("votes")); } catch { /* ignore */ }

                    string json = redis.ListLeftPopAsync("votes").Result;
                    if (json != null)
                    {
                        using var timer = VoteProcessingDuration.Labels("worker-app").NewTimer();
                        using var span = tracer.StartActiveSpan("process-vote");

                        try
                        {
                            var vote = JsonConvert.DeserializeAnonymousType(json, definition);
                            span.SetAttribute("vote.option", vote.vote);
                            span.SetAttribute("voter.id", vote.voter_id);
                            Console.WriteLine($"[INFO] {{\"message\":\"Processing vote\",\"vote\":\"{vote.vote}\",\"voter_id\":\"{vote.voter_id}\"}}");

                            if (!pgsql.State.Equals(System.Data.ConnectionState.Open))
                            {
                                Console.WriteLine("[WARN] {\"message\":\"Reconnecting DB\"}");
                                pgsql = OpenDbConnection($"Server=127.0.0.1;Username={Environment.GetEnvironmentVariable("DB_USER") ?? "postgres"};Password={Environment.GetEnvironmentVariable("DB_PASSWORD") ?? "postgres"};");
                            }

                            UpdateVote(pgsql, vote.voter_id, vote.vote);
                            VotesProcessed.Labels("worker-app").Inc();
                            span.SetStatus(Status.Ok);
                        }
                        catch (Exception ex)
                        {
                            VoteErrors.Labels("worker-app", ex.GetType().Name).Inc();
                            span.SetStatus(Status.Error, ex.Message);
                            Console.Error.WriteLine($"[ERROR] {{\"message\":\"Vote processing failed\",\"error\":\"{ex.Message}\"}}");
                        }
                    }
                    else
                    {
                        keepAliveCommand.ExecuteNonQuery();
                    }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[ERROR] {{\"message\":\"Fatal error\",\"error\":\"{ex}\"}}");
                return 1;
            }
        }

        private static NpgsqlConnection OpenDbConnection(string connectionString)
        {
            NpgsqlConnection connection;
            while (true)
            {
                try
                {
                    connection = new NpgsqlConnection(connectionString);
                    connection.Open();
                    break;
                }
                catch (SocketException)
                {
                    Console.Error.WriteLine("[WARN] {\"message\":\"Waiting for db (socket)\"}");
                    Thread.Sleep(1000);
                }
                catch (DbException)
                {
                    Console.Error.WriteLine("[WARN] {\"message\":\"Waiting for db (db exception)\"}");
                    Thread.Sleep(1000);
                }
            }

            Console.WriteLine("[INFO] {\"message\":\"Connected to db\"}");

            var command = connection.CreateCommand();
            command.CommandText = @"CREATE TABLE IF NOT EXISTS votes (
                                        id VARCHAR(255) NOT NULL UNIQUE,
                                        vote VARCHAR(255) NOT NULL
                                    )";
            command.ExecuteNonQuery();
            return connection;
        }

        private static ConnectionMultiplexer OpenRedisConnection(string hostname)
        {
            var ipAddress = GetIp(hostname);
            Console.WriteLine($"[INFO] {{\"message\":\"Found redis\",\"address\":\"{ipAddress}\"}}");

            while (true)
            {
                try
                {
                    Console.Error.WriteLine("[INFO] {\"message\":\"Connecting to redis\"}");
                    return ConnectionMultiplexer.Connect(ipAddress);
                }
                catch (RedisConnectionException)
                {
                    Console.Error.WriteLine("[WARN] {\"message\":\"Waiting for redis\"}");
                    Thread.Sleep(1000);
                }
            }
        }

        private static string GetIp(string hostname)
            => Dns.GetHostEntryAsync(hostname)
                .Result
                .AddressList
                .First(a => a.AddressFamily == AddressFamily.InterNetwork)
                .ToString();

        private static void UpdateVote(NpgsqlConnection connection, string voterId, string vote)
        {
            var command = connection.CreateCommand();
            try
            {
                command.CommandText = "INSERT INTO votes (id, vote) VALUES (@id, @vote)";
                command.Parameters.AddWithValue("@id", voterId);
                command.Parameters.AddWithValue("@vote", vote);
                command.ExecuteNonQuery();
            }
            catch (DbException)
            {
                command.CommandText = "UPDATE votes SET vote = @vote WHERE id = @id";
                command.ExecuteNonQuery();
            }
            finally
            {
                command.Dispose();
            }
        }
    }
}

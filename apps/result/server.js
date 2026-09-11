'use strict';

// ──────────────────────────────────────────────────────────────────────────────
// OpenTelemetry — must be initialised BEFORE any other require
// ──────────────────────────────────────────────────────────────────────────────
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { BatchSpanProcessor } = require('@opentelemetry/sdk-trace-base');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { registerInstrumentations } = require('@opentelemetry/instrumentation');
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { ExpressInstrumentation } = require('@opentelemetry/instrumentation-express');
const { PgInstrumentation } = require('@opentelemetry/instrumentation-pg');

const OTEL_ENDPOINT = process.env.OTEL_EXPORTER_OTLP_ENDPOINT
  || 'http://otel-collector.ns-observability.svc.cluster.local:4317';

const provider = new NodeTracerProvider({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'result-app',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
    'deployment.environment': process.env.ENV || 'prd',
  }),
});

provider.addSpanProcessor(
  new BatchSpanProcessor(
    new OTLPTraceExporter({ url: OTEL_ENDPOINT }),
  ),
);
provider.register();

registerInstrumentations({
  instrumentations: [
    new HttpInstrumentation(),
    new ExpressInstrumentation(),
    new PgInstrumentation(),
  ],
});

// ──────────────────────────────────────────────────────────────────────────────
// Prometheus Metrics
// ──────────────────────────────────────────────────────────────────────────────
const client = require('prom-client');
client.collectDefaultMetrics({ prefix: 'result_app_' });

const httpRequestTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'status', 'service'],
});

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request latency in seconds',
  labelNames: ['method', 'service'],
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0],
});

// ──────────────────────────────────────────────────────────────────────────────
// Structured JSON logger (Promtail-friendly)
// ──────────────────────────────────────────────────────────────────────────────
const log = {
  info: (msg, extra = {}) => console.log(JSON.stringify({ level: 'info', message: msg, ...extra, time: new Date().toISOString() })),
  warn: (msg, extra = {}) => console.warn(JSON.stringify({ level: 'warn', message: msg, ...extra, time: new Date().toISOString() })),
  error: (msg, extra = {}) => console.error(JSON.stringify({ level: 'error', message: msg, ...extra, time: new Date().toISOString() })),
};

// ──────────────────────────────────────────────────────────────────────────────
// Application
// ──────────────────────────────────────────────────────────────────────────────
const express = require('express');
const async   = require('async');
const { Pool } = require('pg');
const cookieParser = require('cookie-parser');
const path = require('path');

const app    = express();
const server = require('http').Server(app);
const io     = require('socket.io')(server);

const port = process.env.PORT || 4000;

// Prometheus metrics middleware
app.use((req, res, next) => {
  if (req.path === '/metrics' || req.path === '/healthz') return next();
  const end = httpRequestDuration.labels({ method: req.method, service: 'result-app' }).startTimer();
  res.on('finish', () => {
    httpRequestTotal.labels({ method: req.method, status: res.statusCode, service: 'result-app' }).inc();
    end();
  });
  next();
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

// Health probe
app.get('/healthz', (req, res) => res.json({ status: 'ok' }));

io.on('connection', (socket) => {
  socket.emit('message', { text: 'Welcome!' });
  socket.on('subscribe', (data) => socket.join(data.channel));
});

const pool = new Pool({
  host:     process.env.PGHOST     || '127.0.0.1',
  port:     process.env.PGPORT     || 5432,
  database: process.env.PGDATABASE || 'postgres',
  user:     process.env.PGUSER     || 'postgres',
  password: process.env.PGPASSWORD || 'postgres',
});

async.retry(
  { times: 1000, interval: 1000 },
  (callback) => {
    pool.connect((err, client, done) => {
      if (err) log.warn('Waiting for db', { error: err.message });
      callback(err, client);
    });
  },
  (err, client) => {
    if (err) {
      log.error('Giving up connecting to db', { error: err.message });
      return;
    }
    log.info('Connected to db');
    getVotes(client);
  },
);

function getVotes(client) {
  client.query('SELECT vote, COUNT(id) AS count FROM votes GROUP BY vote', [], (err, result) => {
    if (err) {
      log.error('Error performing query', { error: err.message });
    } else {
      const votes = collectVotesFromResult(result);
      io.sockets.emit('scores', JSON.stringify(votes));
    }
    setTimeout(() => getVotes(client), 1000);
  });
}

function collectVotesFromResult(result) {
  const votes = { a: 0, b: 0 };
  result.rows.forEach((row) => { votes[row.vote] = parseInt(row.count, 10); });
  return votes;
}

app.use(cookieParser());
app.use(express.urlencoded({ extended: false }));
app.use(express.static(`${__dirname}/views`));

app.get('/', (req, res) => {
  res.sendFile(path.resolve(`${__dirname}/views/index.html`));
});

server.listen(port, () => {
  log.info(`Result app running on port ${server.address().port}`);
});

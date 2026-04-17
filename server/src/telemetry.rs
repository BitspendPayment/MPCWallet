//! OpenTelemetry initialization for the MPC Wallet server.
//!
//! When `ENCLAVE_MGMT_TOKEN` is set, wires three OTLP/HTTP protobuf exporters
//! targeting the enclave supervisor on 127.0.0.1:{ENCLAVE_PROXY_PORT|7073}:
//!   - traces  -> POST /v1/enclave-traces
//!   - metrics -> POST /v1/enclave-metrics
//!   - logs    -> POST /v1/logs           (supervisor ingest path)
//!
//! When the token is empty, only a stderr `fmt` layer is installed.

use std::time::Duration;

use opentelemetry::{global, trace::TracerProvider as _, KeyValue};
use opentelemetry_appender_tracing::layer::OpenTelemetryTracingBridge;
use opentelemetry_otlp::{LogExporter, MetricExporter, Protocol, SpanExporter, WithExportConfig, WithHttpConfig};
use opentelemetry_sdk::{
    logs::LoggerProvider,
    metrics::{PeriodicReader, SdkMeterProvider},
    runtime,
    trace::TracerProvider,
    Resource,
};
use opentelemetry_semantic_conventions::resource::{SERVICE_NAME, SERVICE_VERSION};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

const SERVICE_NAME_VALUE: &str = "mpc-wallet-server";
const DEPLOYMENT_ENV_KEY: &str = "deployment.environment.name";

/// Handles returned from init; call `shutdown()` before process exit to flush batches.
pub struct TelemetryGuard {
    tracer_provider: Option<TracerProvider>,
    meter_provider: Option<SdkMeterProvider>,
    logger_provider: Option<LoggerProvider>,
}

impl TelemetryGuard {
    pub fn shutdown(&mut self) {
        if let Some(tp) = self.tracer_provider.take() {
            if let Err(e) = tp.shutdown() {
                eprintln!("OTEL tracer shutdown error: {e}");
            }
        }
        if let Some(mp) = self.meter_provider.take() {
            if let Err(e) = mp.shutdown() {
                eprintln!("OTEL meter shutdown error: {e}");
            }
        }
        if let Some(lp) = self.logger_provider.take() {
            if let Err(e) = lp.shutdown() {
                eprintln!("OTEL logger shutdown error: {e}");
            }
        }
    }
}

fn build_resource() -> Resource {
    let env = std::env::var("DEPLOYMENT_ENVIRONMENT").unwrap_or_else(|_| "production".into());
    Resource::new(vec![
        KeyValue::new(SERVICE_NAME, SERVICE_NAME_VALUE),
        KeyValue::new(SERVICE_VERSION, env!("CARGO_PKG_VERSION")),
        KeyValue::new(DEPLOYMENT_ENV_KEY, env),
    ])
}

pub fn init() -> TelemetryGuard {
    use std::io::IsTerminal as _;

    let env_filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));

    let fmt_layer = tracing_subscriber::fmt::layer()
        .with_timer(tracing_subscriber::fmt::time::uptime())
        .with_target(false)
        .with_ansi(std::io::stderr().is_terminal())
        .compact();

    let token = std::env::var("ENCLAVE_MGMT_TOKEN").unwrap_or_default();
    if token.is_empty() {
        tracing_subscriber::registry()
            .with(env_filter)
            .with(fmt_layer)
            .init();
        return TelemetryGuard {
            tracer_provider: None,
            meter_provider: None,
            logger_provider: None,
        };
    }

    let proxy_port = std::env::var("ENCLAVE_PROXY_PORT").unwrap_or_else(|_| "7073".into());
    let base = format!("http://127.0.0.1:{proxy_port}");

    let mut auth_headers = std::collections::HashMap::new();
    auth_headers.insert("Authorization".to_string(), format!("Bearer {token}"));

    let resource = build_resource();

    let trace_exporter = SpanExporter::builder()
        .with_http()
        .with_protocol(Protocol::HttpBinary)
        .with_endpoint(format!("{base}/v1/enclave-traces"))
        .with_headers(auth_headers.clone())
        .with_timeout(Duration::from_secs(10))
        .build()
        .expect("build OTLP trace exporter");

    let tracer_provider = TracerProvider::builder()
        .with_batch_exporter(trace_exporter, runtime::Tokio)
        .with_resource(resource.clone())
        .build();
    global::set_tracer_provider(tracer_provider.clone());

    let metric_exporter = MetricExporter::builder()
        .with_http()
        .with_protocol(Protocol::HttpBinary)
        .with_endpoint(format!("{base}/v1/enclave-metrics"))
        .with_headers(auth_headers.clone())
        .with_timeout(Duration::from_secs(10))
        .build()
        .expect("build OTLP metric exporter");

    let reader = PeriodicReader::builder(metric_exporter, runtime::Tokio)
        .with_interval(Duration::from_secs(5))
        .build();

    let meter_provider = SdkMeterProvider::builder()
        .with_reader(reader)
        .with_resource(resource.clone())
        .build();
    global::set_meter_provider(meter_provider.clone());

    let log_exporter = LogExporter::builder()
        .with_http()
        .with_protocol(Protocol::HttpBinary)
        .with_endpoint(format!("{base}/v1/logs"))
        .with_headers(auth_headers)
        .with_timeout(Duration::from_secs(10))
        .build()
        .expect("build OTLP log exporter");

    let logger_provider = LoggerProvider::builder()
        .with_batch_exporter(log_exporter, runtime::Tokio)
        .with_resource(resource)
        .build();

    let otel_trace_layer = tracing_opentelemetry::layer()
        .with_tracer(tracer_provider.tracer(SERVICE_NAME_VALUE));

    let otel_log_layer = OpenTelemetryTracingBridge::new(&logger_provider);

    tracing_subscriber::registry()
        .with(env_filter)
        .with(fmt_layer)
        .with(otel_trace_layer)
        .with(otel_log_layer)
        .init();

    tracing::info!("OTEL exporters enabled (traces+metrics+logs) -> {base}");

    TelemetryGuard {
        tracer_provider: Some(tracer_provider),
        meter_provider: Some(meter_provider),
        logger_provider: Some(logger_provider),
    }
}

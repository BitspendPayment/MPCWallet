mod auth;
mod bitcoin;
mod config;
mod crypto_ops;
mod persistence;
mod policy;
mod wallet_service;
mod wasm_manager;

use std::sync::Arc;

use clap::Parser;
use tonic::transport::Server;

// Client-facing wallet API
pub mod wallet_proto {
    tonic::include_proto!("mpc_wallet");
}

#[derive(Parser)]
#[command(
    name = "server",
    about = "MPC Wallet Server with per-user WASM crypto isolation"
)]
struct Args {
    /// Path to the threshold WASM component
    #[arg(
        long,
        default_value = "../cosigner/target/wasm32-wasip1/release/cosigner.wasm"
    )]
    wasm: String,

    /// gRPC listen port
    #[arg(long, default_value = "50051")]
    port: u16,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    use std::io::IsTerminal as _;
    tracing_subscriber::fmt()
        .with_timer(tracing_subscriber::fmt::time::uptime())
        .with_target(false)
        .with_ansi(std::io::stderr().is_terminal())
        .compact()
        .init();

    let args = Args::parse();

    // Load config from environment
    let cfg = config::ServerConfig::from_environment();
    tracing::info!(
        "Config: bitcoin_rpc={}, electrum={}:{}",
        cfg.bitcoin_rpc_url,
        cfg.electrum_url,
        cfg.electrum_port
    );

    // Initialize persistence
    let data_dir = std::path::Path::new(&cfg.data_dir);
    std::fs::create_dir_all(data_dir)?;
    let persistence = Arc::new(persistence::PersistenceStore::open(data_dir)?);
    tracing::info!("Persistence initialized at: {}", cfg.data_dir);

    // Load WASM component
    tracing::info!("Loading WASM component from: {}", args.wasm);
    let manager = wasm_manager::WasmManager::new(&args.wasm)?;

    // Initialize Bitcoin services
    let bitcoin_rpc = Arc::new(bitcoin::BitcoinRpcClient::new(
        &cfg.bitcoin_rpc_url,
        &cfg.bitcoin_rpc_user,
        &cfg.bitcoin_rpc_password,
    ));

    let electrum_client =
        bitcoin::ElectrumClient::new(&cfg.electrum_url, cfg.electrum_port);
    let bitcoin_history = Arc::new(tokio::sync::Mutex::new(
        bitcoin::BitcoinHistoryService::new(electrum_client),
    ));

    // Initialize Electrum connection in background
    let bh = bitcoin_history.clone();
    tokio::spawn(async move {
        let service = bh.lock().await;
        if let Err(e) = service.init().await {
            tracing::error!("Failed to initialize Electrum: {e}");
        }
    });

    // Create auth verifier
    let auth_verifier = Arc::new(auth::AuthVerifier::new());

    // Create wallet service
    let service = wallet_service::WalletService::new(
        manager,
        auth_verifier,
        persistence,
        bitcoin_rpc,
        bitcoin_history,
    );

    let addr = format!("0.0.0.0:{}", args.port).parse()?;
    tracing::info!("MPC Wallet Server listening on {}", addr);

    Server::builder()
        .add_service(
            wallet_proto::mpc_wallet_server::MpcWalletServer::new(service),
        )
        .serve(addr)
        .await?;

    Ok(())
}

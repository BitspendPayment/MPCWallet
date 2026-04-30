use mpc_wallet::mpc_wallet_client::MpcWalletClient;
use mpc_wallet::{DkgStep1Request, DkgStep2Request, DkgStep3Request};
use std::time::{Duration, Instant};
use tokio::task;
use tonic::transport::Channel;
use clap::Parser;
use std::collections::HashMap;

pub mod mpc_wallet {
    tonic::include_proto!("mpc_wallet");
}

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(short, long, default_value = "http://127.0.0.1:50051")]
    server: String,

    #[arg(short, long, default_value_t = 5)]
    concurrency: usize,

    #[arg(short, long, default_value_t = 10)]
    sessions: usize,
}

type ResultAny<T> = std::result::Result<T, Box<dyn std::error::Error + Send + Sync>>;

async fn run_participant(
    server_url: String, 
    user_id: Vec<u8>, 
    participant_id: usize
) -> ResultAny<()> {
    let mut client = MpcWalletClient::connect(server_url).await?;
    
    let identifier = vec![participant_id as u8; 32];
    
    // Step 1: DKG Round 1
    let req1 = DkgStep1Request {
        user_id: user_id.clone(),
        identifier: identifier.clone(),
        round1_package: "{}".to_string(), // Mock
        is_restore: false,
    };
    let _res1 = client.dkg_step1(req1).await?.into_inner();

    // Step 2: DKG Round 2
    let req2 = DkgStep2Request {
        user_id: user_id.clone(),
        identifier: identifier.clone(),
        round1_package: "{}".to_string(),
    };
    let _res2 = client.dkg_step2(req2).await?.into_inner();

    // Step 3: DKG Round 3
    let req3 = DkgStep3Request {
        user_id: user_id.clone(),
        identifier: identifier.clone(),
        round2_packages_for_others: HashMap::new(),
    };
    let _res3 = client.dkg_step3(req3).await?;

    Ok(())
}

async fn run_session(server_url: String, session_id: usize) -> ResultAny<()> {
    let user_id = format!("user_stress_{}", session_id).into_bytes();
    
    // We need 2 participants to join the server's session (Total 3)
    let p1 = run_participant(server_url.clone(), user_id.clone(), 1);
    let p2 = run_participant(server_url.clone(), user_id.clone(), 2);
    
    let (r1, r2) = tokio::join!(p1, p2);
    r1?;
    r2?;
    
    Ok(())
}

#[tokio::main]
async fn main() -> ResultAny<()> {
    let args = Args::parse();
    
    println!("Starting load test with {} concurrent sessions, {} total sessions...", args.concurrency, args.sessions);
    
    let start = Instant::now();
    let mut handles = vec![];
    
    let semaphore = std::sync::Arc::new(tokio::sync::Semaphore::new(args.concurrency));

    for i in 0..args.sessions {
        let permit = semaphore.clone().acquire_owned().await.unwrap();
        let url = args.server.clone();
        handles.push(task::spawn(async move {
            let _permit = permit;
            let res = run_session(url, i).await;
            if let Err(e) = res {
                eprintln!("Session {} failed: {}", i, e);
            }
        }));
    }

    for handle in handles {
        let _ = handle.await;
    }

    let duration = start.elapsed();
    println!("Load test complete in {:?}", duration);
    println!("Sessions/sec: {:.2}", args.sessions as f64 / duration.as_secs_f64());

    Ok(())
}

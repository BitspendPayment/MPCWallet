//! Phase 3c: full SendVtxo happy-path through the guest — Install policy, then Step1
//! (gRPC GetInfo + build → sighashes) and Step2 (sign + gRPC SubmitTx + FinalizeTx →
//! ark_txid), all driven over the guest's gRPC-over-wasi:http to a mock arkd. The keys,
//! session, and ASP choreography live entirely in the guest.

use std::collections::BTreeMap;
use std::convert::Infallible;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

use bitcoin::secp256k1::{Keypair, Secp256k1, SecretKey};
use http_body_util::{BodyExt, Full};
use hyper::body::Bytes;
use hyper_util::rt::{TokioExecutor, TokioIo};
use prost::Message as ProstMessage;
use rand::rngs::OsRng;

use cosigner_proto::{GuestCommand, GuestResponse, SendVtxoStep1Wire, SendVtxoStep2Wire, VtxoInputWire};
use cosigner_runtime::auth::message::{build_auth_message, OP_SEND_VTXO};
use cosigner_runtime::cosigner::guest_instance::{self, GuestInstance};

use threshold::auth::AuthSigner;
use threshold::dkg::{self, Round1Package, Round2Package};
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::random;
use threshold::scalar::scalar_to_bytes;

fn guest_wasm_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join("cosigner/target/wasm32-wasip2/release/cosigner.wasm")
}

fn now_ms() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as i64
}

/// A deterministic valid x-only pubkey (hex) from a seed byte.
fn xonly_hex(seed: u8) -> String {
    let secp = Secp256k1::new();
    let sk = SecretKey::from_slice(&[seed; 32]).unwrap();
    let kp = Keypair::from_secret_key(&secp, &sk);
    let (xonly, _) = kp.x_only_public_key();
    hex::encode(xonly.serialize())
}

/// A deterministic valid regtest p2tr address (string) from a seed byte.
fn regtest_addr(seed: u8) -> String {
    let secp = Secp256k1::new();
    let sk = SecretKey::from_slice(&[seed; 32]).unwrap();
    let (xonly, _) = Keypair::from_secret_key(&secp, &sk).x_only_public_key();
    bitcoin::Address::p2tr(&secp, xonly, None, bitcoin::Network::Regtest).to_string()
}

fn dkg_2of2() -> (Vec<KeyPackage>, PublicKeyPackage) {
    let mut rng = OsRng;
    let (min, max) = (2usize, 2usize);
    let mut r1_secrets = Vec::new();
    let mut r1_packages: BTreeMap<Identifier, Round1Package> = BTreeMap::new();
    for _ in 0..max {
        let secret = random::mod_n_random(&mut rng);
        let coefficients: Vec<_> = (0..min - 1).map(|_| random::mod_n_random(&mut rng)).collect();
        let (secret_pkg, pub_pkg) =
            dkg::dkg_part1(max, min, &secret, &coefficients, &mut rng).expect("dkg_part1");
        r1_packages.insert(secret_pkg.identifier.clone(), pub_pkg);
        r1_secrets.push(secret_pkg);
    }
    let mut r2_secrets = Vec::new();
    let mut all_r2: Vec<BTreeMap<Identifier, Round2Package>> = Vec::new();
    for secret_pkg in &r1_secrets {
        let others: BTreeMap<Identifier, Round1Package> = r1_packages
            .iter()
            .filter(|(id, _)| **id != secret_pkg.identifier)
            .map(|(id, p)| (id.clone(), p.clone()))
            .collect();
        let (r2_secret, r2_out) = dkg::dkg_part2(secret_pkg, &others, &[]).expect("dkg_part2");
        r2_secrets.push(r2_secret);
        all_r2.push(r2_out);
    }
    let mut key_packages = Vec::new();
    let mut pkp_out: Option<PublicKeyPackage> = None;
    for (i, r2_secret) in r2_secrets.iter().enumerate() {
        let others_r1: BTreeMap<Identifier, Round1Package> = r1_packages
            .iter()
            .filter(|(id, _)| **id != r2_secret.identifier)
            .map(|(id, p)| (id.clone(), p.clone()))
            .collect();
        let mut our_r2: BTreeMap<Identifier, Round2Package> = BTreeMap::new();
        for (j, r2_pkgs) in all_r2.iter().enumerate() {
            if j == i {
                continue;
            }
            if let Some(pkg) = r2_pkgs.get(&r2_secret.identifier) {
                our_r2.insert(r1_secrets[j].identifier.clone(), pkg.clone());
            }
        }
        let (kp, pkp) =
            dkg::dkg_part3(&r1_secrets[i], r2_secret, &others_r1, &our_r2, &[]).expect("dkg_part3");
        key_packages.push(kp.into_even_y());
        pkp_out = Some(pkp.into_even_y());
    }
    (key_packages, pkp_out.unwrap())
}

fn grpc_frame<M: ProstMessage>(m: &M) -> Vec<u8> {
    let mut buf = Vec::new();
    m.encode(&mut buf).unwrap();
    let mut framed = vec![0u8];
    framed.extend_from_slice(&(buf.len() as u32).to_be_bytes());
    framed.extend_from_slice(&buf);
    framed
}

/// Mock arkd: answers GetInfo, SubmitTx (echoes checkpoints), and FinalizeTx over h2c.
async fn run_mock_arkd(listener: tokio::net::TcpListener) {
    loop {
        let Ok((tcp, _)) = listener.accept().await else { continue };
        tokio::spawn(async move {
            let svc = hyper::service::service_fn(handle);
            let _ = hyper::server::conn::http2::Builder::new(TokioExecutor::new())
                .serve_connection(TokioIo::new(tcp), svc)
                .await;
        });
    }
}

async fn handle(
    req: hyper::Request<hyper::body::Incoming>,
) -> Result<hyper::Response<Full<Bytes>>, Infallible> {
    use ark::client::proto::{
        FinalizeTxResponse, GetInfoResponse, SubmitTxRequest, SubmitTxResponse,
    };
    let path = req.uri().path().to_string();
    let body = req.into_body().collect().await.unwrap().to_bytes();
    let msg = if body.len() >= 5 { &body[5..] } else { &body[..] };

    let resp = match path.as_str() {
        "/ark.v1.ArkService/GetInfo" => grpc_frame(&GetInfoResponse {
            signer_pubkey: xonly_hex(2),
            forfeit_pubkey: xonly_hex(4),
            forfeit_address: regtest_addr(4),
            network: "regtest".to_string(),
            unilateral_exit_delay: 144,
            boarding_exit_delay: 144,
            ..Default::default()
        }),
        "/ark.v1.ArkService/SubmitTx" => {
            let r = SubmitTxRequest::decode(msg).unwrap();
            grpc_frame(&SubmitTxResponse {
                ark_txid: "fakearktxid".to_string(),
                signed_checkpoint_txs: r.checkpoint_txs, // echo back so finalize matches
                ..Default::default()
            })
        }
        "/ark.v1.ArkService/FinalizeTx" => grpc_frame(&FinalizeTxResponse::default()),
        _ => grpc_frame(&GetInfoResponse::default()),
    };
    Ok(hyper::Response::builder()
        .status(200)
        .header("content-type", "application/grpc")
        .body(Full::new(Bytes::from(resp)))
        .unwrap())
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn guest_send_vtxo_full_flow() {
    let wasm = guest_wasm_path();
    if !wasm.exists() {
        eprintln!("cosigner-guest not built at {wasm:?} (needs `cargo +stable build`); skipping.");
        return;
    }

    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let port = listener.local_addr().unwrap().port();
    tokio::spawn(run_mock_arkd(listener));
    let asp_url = format!("http://127.0.0.1:{port}");

    // Keys: 2-of-2 {user, cosigner}; the wallet owner key = the group key (PKP).
    let (kps, pkp) = dkg_2of2();
    let kp_user = kps[0].clone();
    let kp_cosigner = kps[1].clone();
    let auth = AuthSigner::from_secret_bytes(&scalar_to_bytes(&kp_user.secret_share)).unwrap();
    let user_id = auth.public_key_compressed().to_vec();
    let user_id_hex = hex::encode(&user_id);

    let engine = guest_instance::build_engine().unwrap();
    let component = wasmtime::component::Component::from_file(&engine, &wasm).unwrap();
    let linker = guest_instance::build_linker(&engine).unwrap();
    let mut guest = GuestInstance::spawn(&engine, &component, &linker, None)
        .await
        .unwrap();

    // Install the cosigner's policy.
    let r = guest
        .command(GuestCommand::InstallPolicy {
            group_key: hex::encode(pkp.verifying_key.serialize()),
            key_package_json: kp_cosigner.to_json(),
            public_key_package_json: pkp.to_json(),
            user_signing_identifier_hex: Some(hex::encode(kp_user.identifier.serialize())),
            server_dkg_secret_hex: None,
            contract_pairing: None,
        })
        .await
        .unwrap();
    assert!(matches!(r, GuestResponse::PolicyInstalled), "got {r:?}");

    // Recipient ark address (must use the same ASP signer key the mock returns).
    let signer_xonly = xonly_hex(2);
    let recipient_xonly = xonly_hex(3);
    let recipient_addr =
        ark::client::ark_address(&recipient_xonly, &signer_xonly, 144, bitcoin::Network::Regtest)
            .unwrap();

    // The guest owns the VTXO set — push it before the send.
    guest
        .command(GuestCommand::SetVtxos {
            vtxos: vec![VtxoInputWire {
                txid: hex::encode([9u8; 32]),
                vout: 0,
                amount_sats: 10_000,
                exit_delay: 144,
            }],
        })
        .await
        .unwrap();

    // Step1: build → sighashes (reads VTXOs from the guest store).
    let ts1 = now_ms();
    let resp1 = guest
        .command(GuestCommand::SendVtxoStep1(SendVtxoStep1Wire {
            user_id: user_id.clone(),
            signature: auth.sign(&build_auth_message(OP_SEND_VTXO, ts1, &user_id_hex)).to_vec(),
            timestamp_ms: ts1,
            asp_url: asp_url.clone(),
            recipient_ark_address: recipient_addr,
            amount: 5000,
        }))
        .await
        .unwrap();
    let sighashes = match resp1 {
        GuestResponse::SendVtxoSighashes { messages_to_sign } => messages_to_sign,
        other => panic!("Step1 expected sighashes, got {other:?}"),
    };
    assert!(!sighashes.is_empty(), "Step1 returned no sighashes");

    // Step2: sign each sighash (opaque 64-byte sigs — prepare_submit only checks length),
    // then submit + finalize via gRPC.
    let signed_messages: Vec<Vec<u8>> = sighashes.iter().map(|_| vec![1u8; 64]).collect();
    let ts2 = now_ms();
    let resp2 = guest
        .command(GuestCommand::SendVtxoStep2(SendVtxoStep2Wire {
            user_id: user_id.clone(),
            signature: auth.sign(&build_auth_message(OP_SEND_VTXO, ts2, &user_id_hex)).to_vec(),
            timestamp_ms: ts2,
            asp_url,
            signed_messages,
        }))
        .await
        .unwrap();
    match resp2 {
        GuestResponse::SendVtxoSubmitted { ark_txid, change } => {
            assert_eq!(ark_txid, "fakearktxid");
            // Sent 5000 of 10000 → expect a 5000-sat change VTXO with the change exit delay.
            let (_txid, _vout, amount, exit_delay) = change.expect("expected change VTXO");
            assert_eq!(amount, 5000);
            assert_eq!(exit_delay, 144);
        }
        other => panic!("Step2 expected SendVtxoSubmitted, got {other:?}"),
    }
    println!("guest-owned SendVtxo (gRPC GetInfo+build → sign → SubmitTx+FinalizeTx) end-to-end ✓");
}

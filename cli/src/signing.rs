//! Client half of the 2-of-2 FROST ceremony, plus the Ark flows built on it.
//!
//! Signature assembly matches `app-core/lib/client.dart`: the cosigner returns `(R, Z)` and a
//! BIP-340 signature is `R.x ‖ Z` — compressed R minus its parity byte, then the scalar.
//! `script_path_spend` means raw FROST (no taproot tweak), which Ark sends and boarding use.

use anyhow::{anyhow, Context, Result};
use rand::rngs::OsRng;
use serde_json::{json, Value};

use threshold::commitment::SigningPackage;
use threshold::identifier::Identifier;
use threshold::keys::KeyPackage;
use threshold::nonce::{self, SigningCommitments};
use threshold::point;
use threshold::scalar::scalar_to_bytes;
use threshold::signing;

use crate::client::{signer_from_key_package, Client};
use crate::keystore::Wallet;

use std::collections::BTreeMap;

/// Run one full FROST ceremony over `sighash` and return the 64-byte BIP-340 signature.
pub async fn frost_sign(
    client: &Client,
    wallet: &Wallet,
    sighash: &[u8],
    script_path_spend: bool,
) -> Result<Vec<u8>> {
    let kp = KeyPackage::from_json(&wallet.key_package_json)
        .map_err(|e| anyhow!("bad key package: {e:?}"))?;
    let signer = signer_from_key_package(&wallet.key_package_json)?;

    // Round 1: our nonce + commitments.
    let mut rng = OsRng;
    let our_nonce = nonce::new_nonce(&mut rng, &kp.secret_share);
    let resp1 = client
        .post_signed(
            &wallet.group_key,
            "/sign/step1",
            "SIGN_STEP1",
            &signer,
            json!({
                "hiding_commitment": hex::encode(point::serialize_compressed(&our_nonce.commitments.hiding)),
                "binding_commitment": hex::encode(point::serialize_compressed(&our_nonce.commitments.binding)),
                "message_to_sign": hex::encode(sighash),
                "full_transaction": "",
                "script_path_spend": script_path_spend,
                "ark_tx": "",
            }),
        )
        .await
        .context("sign/step1")?;

    // Sign the sighash WE built, never the one the cosigner echoes back.
    //
    // Taking the server's value made this client sign anything the cosigner asked
    // for: answer step1 with the sighash of a sweep to the cosigner's own address
    // and the 2-of-2 completes, spending the wallet with no user action beyond an
    // unrelated send. The Dart client has always built the package from its own
    // local message (client.dart) — this now matches.
    //
    // A pairing/contract actor legitimately rebuilds the message, so it would trip
    // this check; those flows are out of scope here and must re-derive the sighash
    // locally rather than trust an echo.
    let echoed = hex_field(&resp1, "message_to_sign")?;
    if echoed != sighash {
        return Err(anyhow!(
            "cosigner echoed a different sighash than we asked it to sign \
             (ours {}, theirs {}) — refusing to sign",
            hex::encode(sighash),
            hex::encode(&echoed),
        ));
    }
    let message = sighash.to_vec();

    let commitments = parse_commitments(&resp1)?;
    let pkg = SigningPackage::new(commitments, message);
    let share = signing::sign(&pkg, &our_nonce, &kp).map_err(|e| anyhow!("frost sign: {e:?}"))?;

    // Round 2: hand over our share; the cosigner adds its own and aggregates.
    let resp2 = client
        .post_signed(
            &wallet.group_key,
            "/sign/step2",
            "SIGN_STEP2",
            &signer,
            json!({ "signature_share": hex::encode(scalar_to_bytes(&share.s)) }),
        )
        .await
        .context("sign/step2")?;

    let r_point = hex_field(&resp2, "r_point")?;
    let z_scalar = hex_field(&resp2, "z_scalar")?;
    if r_point.len() != 33 || z_scalar.len() != 32 {
        return Err(anyhow!(
            "unexpected aggregate shape: R={} bytes, Z={} bytes",
            r_point.len(),
            z_scalar.len()
        ));
    }
    let mut sig = Vec::with_capacity(64);
    sig.extend_from_slice(&r_point[1..]); // x-only: drop the parity prefix
    sig.extend_from_slice(&z_scalar);

    // Verify before handing it back, as the Dart client does. Our share alone
    // proves nothing about what the cosigner aggregated, so this is the only
    // local evidence that the finished signature is over OUR sighash and
    // validates under the wallet's group key.
    let group_pk = hex::decode(&wallet.group_key).context("group_key is not hex")?;
    let pk33: &[u8; 33] = group_pk
        .as_slice()
        .try_into()
        .map_err(|_| anyhow!("group_key must be a 33-byte compressed point"))?;
    let sig64: &[u8; 64] = sig
        .as_slice()
        .try_into()
        .map_err(|_| anyhow!("aggregate signature must be 64 bytes"))?;
    if !threshold::auth::verify_schnorr_signature(pk33, sighash, sig64) {
        return Err(anyhow!(
            "aggregated signature does not verify against the wallet group key \
             over our sighash — discarding"
        ));
    }
    Ok(sig)
}

/// Off-chain Ark send. Phase 1 returns sighashes; we FROST-sign each and resubmit.
/// Returns the Ark txid.
pub async fn send_vtxo(
    client: &Client,
    wallet: &Wallet,
    recipient: &str,
    amount_sats: u64,
) -> Result<String> {
    let phase1 = client
        .post_session(&wallet.group_key, "/ark/send", json!({ "recipient_ark_address": recipient, "amount": amount_sats }),
        )
        .await
        .context("ark/send phase 1")?;

    let sighashes = messages_to_sign(&phase1)?;
    if sighashes.is_empty() {
        return Err(anyhow!(
            "send returned no sighashes (status {:?}, error {:?})",
            phase1.get("status"),
            phase1.get("error_message")
        ));
    }
    let script_path = phase1
        .get("script_path_spend")
        .and_then(|v| v.as_bool())
        .unwrap_or(true);

    let mut signed = Vec::with_capacity(sighashes.len());
    for sighash in &sighashes {
        signed.push(hex::encode(
            frost_sign(client, wallet, sighash, script_path).await?,
        ));
    }

    let phase2 = client
        .post_session(&wallet.group_key, "/ark/send", json!({
                "recipient_ark_address": recipient,
                "amount": amount_sats,
                "signed_messages": signed,
            }),
        )
        .await
        .context("ark/send phase 2")?;

    phase2
        .get("ark_txid")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .map(String::from)
        .ok_or_else(|| anyhow!("send did not return a txid: {phase2}"))
}

/// Boarding settle: drive the batch until SETTLED, FROST-signing each round of sighashes. The
/// caller supplies the boarding UTXO — the cosigner does not scan the chain. Returns the
/// commitment txid.
pub async fn settle_boarding(
    client: &Client,
    wallet: &Wallet,
    utxo: (String, u32, u64),
) -> Result<String> {
    const SETTLED: i64 = 2;
    const ERROR: i64 = 3;
    const MAX_ROUNDS: usize = 12;

    let mut signed: Vec<String> = Vec::new();
    let boarding_utxos = json!([{ "txid": utxo.0, "vout": utxo.1, "amount_sats": utxo.2 }]);

    for round in 0..MAX_ROUNDS {
        let resp = client
            .post_session(&wallet.group_key, "/ark/settle", json!({ "signed_messages": signed, "boarding_utxos": boarding_utxos }),
            )
            .await
            .with_context(|| format!("ark/settle round {round}"))?;

        let status = resp.get("status").and_then(|v| v.as_i64()).unwrap_or(0);
        if status == ERROR {
            return Err(anyhow!(
                "settle failed: {}",
                resp.get("error_message").and_then(|v| v.as_str()).unwrap_or("?")
            ));
        }
        if status == SETTLED {
            return Ok(resp
                .get("commitment_txid")
                .and_then(|v| v.as_str())
                .unwrap_or_default()
                .to_string());
        }

        // SIGNING_REQUIRED (or WAITING_FOR_BATCH, which carries no sighashes — just poll again).
        let sighashes = messages_to_sign(&resp)?;
        let script_path = resp
            .get("script_path_spend")
            .and_then(|v| v.as_bool())
            .unwrap_or(false);
        signed.clear();
        for sighash in &sighashes {
            signed.push(hex::encode(
                frost_sign(client, wallet, sighash, script_path).await?,
            ));
        }
        if sighashes.is_empty() {
            // Waiting on the batch — back off briefly rather than hot-looping the ASP.
            tokio::time::sleep(std::time::Duration::from_secs(2)).await;
        }
    }
    Err(anyhow!("settle did not complete within {MAX_ROUNDS} rounds"))
}

fn hex_field(v: &Value, key: &str) -> Result<Vec<u8>> {
    let s = v
        .get(key)
        .and_then(|x| x.as_str())
        .ok_or_else(|| anyhow!("missing `{key}` in response: {v}"))?;
    hex::decode(s).with_context(|| format!("decode {key}"))
}

fn messages_to_sign(v: &Value) -> Result<Vec<Vec<u8>>> {
    let arr = v
        .get("messages_to_sign")
        .and_then(|m| m.as_array())
        .cloned()
        .unwrap_or_default();
    arr.iter()
        .map(|m| {
            hex::decode(m.as_str().unwrap_or_default()).context("decode sighash")
        })
        .collect()
}

/// The cosigner returns `{ identifier_hex: { hiding, binding } }`.
fn parse_commitments(resp: &Value) -> Result<BTreeMap<Identifier, SigningCommitments>> {
    let map = resp
        .get("commitments")
        .and_then(|c| c.as_object())
        .ok_or_else(|| anyhow!("step1 response has no commitments: {resp}"))?;
    let mut out = BTreeMap::new();
    for (id_hex, c) in map {
        let id_bytes: [u8; 32] = hex::decode(id_hex)
            .context("identifier hex")?
            .as_slice()
            .try_into()
            .map_err(|_| anyhow!("identifier must be 32 bytes"))?;
        let id = Identifier::deserialize(&id_bytes).map_err(|e| anyhow!("bad identifier: {e:?}"))?;
        let hiding: [u8; 33] = hex::decode(c.get("hiding").and_then(|v| v.as_str()).unwrap_or(""))
            .context("hiding hex")?
            .as_slice()
            .try_into()
            .map_err(|_| anyhow!("hiding must be 33 bytes"))?;
        let binding: [u8; 33] = hex::decode(c.get("binding").and_then(|v| v.as_str()).unwrap_or(""))
            .context("binding hex")?
            .as_slice()
            .try_into()
            .map_err(|_| anyhow!("binding must be 33 bytes"))?;
        out.insert(
            id,
            SigningCommitments {
                hiding: point::deserialize_compressed(&hiding)
                    .map_err(|e| anyhow!("hiding point: {e:?}"))?,
                binding: point::deserialize_compressed(&binding)
                    .map_err(|e| anyhow!("binding point: {e:?}"))?,
            },
        );
    }
    Ok(out)
}

//! Client half of the 2-of-2 DKG against the cosigner's `/dkg/step{1,2,3}` endpoints.
//!
//! The runtime is the other participant: step1 registers our round-1 package and the server
//! self-inits, step2 drives the server's round-2 computation and returns everyone's round-1
//! packages, step3 exchanges round-2 packages. We then run `dkg_part3` locally to get our key
//! package + the group public key. Both are even-Y normalized, matching the server.

use std::collections::BTreeMap;

use anyhow::{anyhow, Context, Result};
use rand::rngs::OsRng;
use rand::RngCore;
use serde_json::json;

use threshold::dkg::{self, Round1Package, Round2Package};
use threshold::identifier::Identifier;
use threshold::random;

use crate::client::Client;
use crate::keystore::Wallet;

const TOTAL_PARTICIPANTS: usize = 2;
const THRESHOLD_COUNT: usize = 2;

// The DKG packages carry curve points/scalars and use the threshold crate's own JSON codec
// (not serde), matching `onboarding::ceremony` on the server.
fn r1_to_json(p: &Round1Package) -> Result<String> {
    Ok(p.to_json())
}

fn r1_from_json(s: &str) -> Result<Round1Package> {
    Round1Package::from_json(s).map_err(|e| anyhow!("bad round1 package: {e:?}"))
}

fn r2_to_json(p: &Round2Package) -> Result<String> {
    Ok(p.to_json())
}

fn r2_from_json(s: &str) -> Result<Round2Package> {
    Round2Package::from_json(s).map_err(|e| anyhow!("bad round2 package: {e:?}"))
}

/// Run the full DKG and return a wallet ready to use.
pub async fn onboard(client: &Client) -> Result<Wallet> {
    let mut rng = OsRng;

    // A stable per-onboarding id; the server keys its session on it across the three steps. This
    // is NOT our FROST identifier — see below.
    let mut uid = [0u8; 16];
    rng.fill_bytes(&mut uid);
    let user_id_hex = hex::encode(uid);

    // --- Round 1: deal our own package. ---
    let secret = random::mod_n_random(&mut rng);
    let coefficients: Vec<_> = (0..THRESHOLD_COUNT - 1)
        .map(|_| random::mod_n_random(&mut rng))
        .collect();
    let (r1_secret, r1_public) = dkg::dkg_part1(
        TOTAL_PARTICIPANTS,
        THRESHOLD_COUNT,
        &secret,
        &coefficients,
        &mut rng,
    )
    .map_err(|e| anyhow!("dkg_part1: {e:?}"))?;

    // Our FROST identifier is NOT ours to choose: `dkg_part1` derives it from the VSS commitment's
    // verifying key and binds the proof-of-knowledge to it. Announcing any other identifier makes
    // the server's `dkg_part2` reject the PoK.
    let me_hex = hex::encode(r1_secret.identifier.serialize());

    let r1_json = r1_to_json(&r1_public)?;
    client
        .post(
            "/api/dkg/step1",
            json!({
                "user_id": user_id_hex,
                "identifier": me_hex,
                "round1_package": r1_json,
            }),
        )
        .await
        .context("dkg step1")?;

    // --- Step 2: the server computes its round 2; we get every round-1 package. ---
    let step2 = client
        .post(
            "/api/dkg/step2",
            json!({
                "user_id": user_id_hex,
                "identifier": me_hex,
                "round1_package": r1_json,
            }),
        )
        .await
        .context("dkg step2")?;

    let all_r1 = step2
        .get("all_round1_packages")
        .and_then(|v| v.as_object())
        .ok_or_else(|| anyhow!("step2: missing all_round1_packages"))?;

    // Everyone's round-1 package except our own.
    let mut others_r1: BTreeMap<Identifier, Round1Package> = BTreeMap::new();
    for (id_hex, pkg) in all_r1 {
        if id_hex == &me_hex {
            continue;
        }
        others_r1.insert(parse_id(id_hex)?, r1_from_json(pkg.as_str().unwrap_or_default())?);
    }
    if others_r1.is_empty() {
        return Err(anyhow!("step2 returned no peer round-1 packages"));
    }

    // --- Round 2: our packages for the other participants. ---
    let (r2_secret, r2_for_others) =
        dkg::dkg_part2(&r1_secret, &others_r1, &[]).map_err(|e| anyhow!("dkg_part2: {e:?}"))?;

    let mut wire_r2 = serde_json::Map::new();
    for (id, pkg) in &r2_for_others {
        wire_r2.insert(hex::encode(id.serialize()), json!(r2_to_json(pkg)?));
    }

    let step3 = client
        .post(
            "/api/dkg/step3",
            json!({
                "user_id": user_id_hex,
                "identifier": me_hex,
                "round2_packages_for_others": wire_r2,
            }),
        )
        .await
        .context("dkg step3")?;

    let for_me = step3
        .get("round2_packages_for_me")
        .and_then(|v| v.as_object())
        .ok_or_else(|| anyhow!("step3: missing round2_packages_for_me"))?;
    let mut our_r2: BTreeMap<Identifier, Round2Package> = BTreeMap::new();
    for (id_hex, pkg) in for_me {
        our_r2.insert(parse_id(id_hex)?, r2_from_json(pkg.as_str().unwrap_or_default())?);
    }
    if our_r2.is_empty() {
        return Err(anyhow!("step3 returned no round-2 packages for us"));
    }

    // --- Round 3: derive our key package + the group key. Even-Y, matching the server. ---
    let (kp, pkp) = dkg::dkg_part3(&r1_secret, &r2_secret, &others_r1, &our_r2, &[])
        .map_err(|e| anyhow!("dkg_part3: {e:?}"))?;
    let kp = kp.into_even_y();
    let pkp = pkp.into_even_y();

    let group_key = hex::encode(pkp.verifying_key.serialize());
    let signer = crate::client::signer_from_key_package(&kp.to_json())?;

    Ok(Wallet {
        group_key,
        user_id_hex: hex::encode(signer.public_key_compressed()),
        key_package_json: kp.to_json(),
        public_key_package_json: pkp.to_json(),
    })
}

fn parse_id(hex_str: &str) -> Result<Identifier> {
    let bytes = hex::decode(hex_str).context("identifier hex")?;
    let arr: [u8; 32] = bytes
        .as_slice()
        .try_into()
        .map_err(|_| anyhow!("identifier must be 32 bytes"))?;
    Identifier::deserialize(&arr).map_err(|e| anyhow!("bad identifier: {e:?}"))
}

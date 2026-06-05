//! DKG and key refresh operations.

use std::cell::RefCell;

use rand::rngs::OsRng;
use threshold::dkg;
use threshold::random;
use threshold::scalar::scalar_to_bytes;

use crate::exports::component::threshold::types::*;
use crate::convert;
use crate::{Round1SecretState, Round2SecretState};

pub fn dkg_part1(
    max_signers: u32,
    min_signers: u32,
    secret_hex: String,
    coefficients_json: String,
) -> Result<DkgRound1Output, ThresholdError> {
    let secret = convert::parse_scalar_hex(&secret_hex).map_err(convert::to_input_error)?;
    let coefficients =
        convert::parse_coefficients_json(&coefficients_json).map_err(convert::to_input_error)?;

    let mut rng = OsRng;
    let (secret_pkg, pub_pkg) = dkg::dkg_part1(
        max_signers as usize,
        min_signers as usize,
        &secret,
        &coefficients,
        &mut rng,
    )
    .map_err(convert::to_crypto_error)?;

    Ok(DkgRound1Output {
        round1_package_json: convert::serialize_round1_pkg(&pub_pkg),
        secret: Round1Secret::new(Round1SecretState {
            inner: RefCell::new(Some(secret_pkg)),
        }),
    })
}

pub fn dkg_part2(
    secret: Round1Secret,
    round1_packages_json: String,
    receiver_ids_json: String,
) -> Result<DkgRound2Output, ThresholdError> {
    let state = secret.get::<Round1SecretState>();
    let r1_secret = state
        .inner
        .borrow_mut()
        .take()
        .ok_or_else(|| ThresholdError::InvalidInput("round1-secret already consumed".into()))?;

    let round1_pkgs =
        convert::parse_round1_pkgs_json(&round1_packages_json).map_err(convert::to_serde_error)?;

    let receiver_ids = if receiver_ids_json.is_empty() || receiver_ids_json == "[]" {
        Vec::new()
    } else {
        convert::parse_identifier_list_json(&receiver_ids_json).map_err(convert::to_serde_error)?
    };

    let (r2_secret, r2_pkgs) =
        dkg::dkg_part2(&r1_secret, &round1_pkgs, &receiver_ids).map_err(convert::to_crypto_error)?;

    Ok(DkgRound2Output {
        round2_packages_json: convert::serialize_round2_pkgs(&r2_pkgs),
        secret: Round2Secret::new(Round2SecretState {
            inner: RefCell::new(Some(r2_secret)),
        }),
    })
}

pub fn dkg_part3(
    r2_secret: Round2Secret,
    round1_packages_json: String,
    round2_packages_json: String,
    receiver_ids_json: String,
) -> Result<DkgRound3Output, ThresholdError> {
    let r2_state = r2_secret.get::<Round2SecretState>();
    let r2_sec = r2_state
        .inner
        .borrow_mut()
        .take()
        .ok_or_else(|| ThresholdError::InvalidInput("round2-secret already consumed".into()))?;

    let round1_pkgs =
        convert::parse_round1_pkgs_json(&round1_packages_json).map_err(convert::to_serde_error)?;
    let round2_pkgs =
        convert::parse_round2_pkgs_json(&round2_packages_json).map_err(convert::to_serde_error)?;

    let receiver_ids = if receiver_ids_json.is_empty() || receiver_ids_json == "[]" {
        Vec::new()
    } else {
        convert::parse_identifier_list_json(&receiver_ids_json).map_err(convert::to_serde_error)?
    };

    // Create a dummy r1_secret for API compat (dkg_part3 ignores it)
    let dummy_r1 = dkg::Round1SecretPackage {
        identifier: r2_sec.identifier.clone(),
        coefficients: Vec::new(),
        commitment: r2_sec.commitment.clone(),
        min_signers: r2_sec.min_signers,
        max_signers: r2_sec.max_signers,
    };

    let (kp, pkp) = dkg::dkg_part3(
        &dummy_r1,
        &r2_sec,
        &round1_pkgs,
        &round2_pkgs,
        &receiver_ids,
    )
    .map_err(convert::to_crypto_error)?;

    let (kp_json, pkp_json) = convert::serialize_dkg_result(&kp, &pkp);
    Ok(DkgRound3Output {
        key_package_json: kp_json,
        public_key_package_json: pkp_json,
    })
}

pub fn dkg_part3_receive(
    my_id_hex: String,
    dealer_r1_json: String,
    shares_json: String,
    min_signers: u32,
    max_signers: u32,
    all_ids_json: String,
) -> Result<DkgRound3Output, ThresholdError> {
    let my_id = convert::parse_identifier_hex(&my_id_hex).map_err(convert::to_input_error)?;
    let dealer_r1 =
        convert::parse_round1_pkgs_json(&dealer_r1_json).map_err(convert::to_serde_error)?;
    let shares =
        convert::parse_round2_pkgs_json(&shares_json).map_err(convert::to_serde_error)?;
    let all_ids =
        convert::parse_identifier_list_json(&all_ids_json).map_err(convert::to_serde_error)?;

    let (kp, pkp) = dkg::dkg_part3_receive(
        &my_id,
        &dealer_r1,
        &shares,
        min_signers as usize,
        max_signers as usize,
        &all_ids,
    )
    .map_err(convert::to_crypto_error)?;

    let (kp_json, pkp_json) = convert::serialize_dkg_result(&kp, &pkp);
    Ok(DkgRound3Output {
        key_package_json: kp_json,
        public_key_package_json: pkp_json,
    })
}

// ---------------------------------------------------------------------------
// Key Refresh
// ---------------------------------------------------------------------------

pub fn dkg_refresh_part1(
    id_hex: String,
    max_signers: u32,
    min_signers: u32,
    seed: Vec<u8>,
) -> Result<DkgRefreshRound1Output, ThresholdError> {
    let identifier = convert::parse_identifier_hex(&id_hex).map_err(convert::to_input_error)?;

    let mut rng = OsRng;
    let coefficients = if !seed.is_empty() {
        random::generate_coefficients_seeded(min_signers as usize - 1, &seed)
    } else {
        random::generate_coefficients(min_signers as usize - 1, &mut rng)
    };

    let (secret_pkg, pub_pkg) = dkg::dkg_refresh_part1(
        &identifier,
        max_signers as usize,
        min_signers as usize,
        &coefficients,
        &mut rng,
    )
    .map_err(convert::to_crypto_error)?;

    // Return coefficients for evaluatePolynomial on the host side
    let coeffs_hex: Vec<serde_json::Value> = secret_pkg
        .coefficients
        .iter()
        .map(|c| serde_json::Value::String(convert::hex_encode(&scalar_to_bytes(c))))
        .collect();
    let coefficients_json = serde_json::Value::Array(coeffs_hex).to_string();

    Ok(DkgRefreshRound1Output {
        round1_package_json: convert::serialize_round1_pkg(&pub_pkg),
        coefficients_json,
        secret: Round1Secret::new(Round1SecretState {
            inner: RefCell::new(Some(secret_pkg)),
        }),
    })
}

pub fn dkg_refresh_part2(
    secret: Round1Secret,
    round1_packages_json: String,
) -> Result<DkgRound2Output, ThresholdError> {
    let state = secret.get::<Round1SecretState>();
    let r1_secret = state
        .inner
        .borrow_mut()
        .take()
        .ok_or_else(|| ThresholdError::InvalidInput("round1-secret already consumed".into()))?;

    let round1_pkgs =
        convert::parse_round1_pkgs_json(&round1_packages_json).map_err(convert::to_serde_error)?;

    let (r2_secret, r2_pkgs) =
        dkg::dkg_refresh_part2(&r1_secret, &round1_pkgs).map_err(convert::to_crypto_error)?;

    Ok(DkgRound2Output {
        round2_packages_json: convert::serialize_round2_pkgs(&r2_pkgs),
        secret: Round2Secret::new(Round2SecretState {
            inner: RefCell::new(Some(r2_secret)),
        }),
    })
}

pub fn dkg_refresh_part3(
    r2_secret: Round2Secret,
    round1_packages_json: String,
    round2_packages_json: String,
    old_pkp_json: String,
    old_kp_json: String,
) -> Result<DkgRound3Output, ThresholdError> {
    let r2_state = r2_secret.get::<Round2SecretState>();
    let r2_sec = r2_state
        .inner
        .borrow_mut()
        .take()
        .ok_or_else(|| ThresholdError::InvalidInput("round2-secret already consumed".into()))?;

    let round1_pkgs =
        convert::parse_round1_pkgs_json(&round1_packages_json).map_err(convert::to_serde_error)?;
    let round2_pkgs =
        convert::parse_round2_pkgs_json(&round2_packages_json).map_err(convert::to_serde_error)?;

    let old_pkp = threshold::keys::PublicKeyPackage::from_json(&old_pkp_json)
        .map_err(convert::to_serde_error)?;
    let old_kp =
        threshold::keys::KeyPackage::from_json(&old_kp_json).map_err(convert::to_serde_error)?;

    let (kp, pkp) = dkg::dkg_refresh_part3(&r2_sec, &round1_pkgs, &round2_pkgs, &old_pkp, &old_kp)
        .map_err(convert::to_crypto_error)?;

    let (kp_json, pkp_json) = convert::serialize_dkg_result(&kp, &pkp);
    Ok(DkgRound3Output {
        key_package_json: kp_json,
        public_key_package_json: pkp_json,
    })
}

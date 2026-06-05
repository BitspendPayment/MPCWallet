wit_bindgen::generate!({
    world: "threshold-world",
    path: "wit",
});

mod ark_ops;
mod convert;
mod dkg_ops;
mod signing_ops;
mod key_ops;
mod auth_ops;
mod util_ops;
mod session_state;

use std::cell::RefCell;

use crate::exports::component::threshold::types::*;

struct Component;

// ---------------------------------------------------------------------------
// Resource implementations
// ---------------------------------------------------------------------------

pub struct Round1SecretState {
    inner: RefCell<Option<threshold::dkg::Round1SecretPackage>>,
}

impl GuestRound1Secret for Round1SecretState {}

pub struct Round2SecretState {
    inner: RefCell<Option<threshold::dkg::Round2SecretPackage>>,
}

impl GuestRound2Secret for Round2SecretState {}

pub struct SigningNonceState {
    inner: RefCell<Option<threshold::nonce::SigningNonce>>,
}

impl GuestSigningNonce for SigningNonceState {}

pub struct AuthSignerState {
    inner: RefCell<threshold::auth::AuthSigner>,
}

impl GuestAuthSigner for AuthSignerState {
    fn new(secret_hex: String) -> Self {
        let bytes = convert::hex_decode_32(&secret_hex)
            .expect("invalid secret hex for AuthSigner");
        let signer = threshold::auth::AuthSigner::from_secret_bytes(&bytes)
            .expect("AuthSigner creation failed");
        Self {
            inner: RefCell::new(signer),
        }
    }

    fn sign(&self, message: Vec<u8>) -> Result<String, ThresholdError> {
        let signer = self.inner.borrow();
        let sig = signer.sign(&message);
        Ok(convert::hex_encode(&sig))
    }

    fn public_key(&self) -> Result<String, ThresholdError> {
        let signer = self.inner.borrow();
        Ok(convert::hex_encode(&signer.public_key_compressed()))
    }
}

// ---------------------------------------------------------------------------
// ThresholdSession resource
// ---------------------------------------------------------------------------

pub struct ThresholdSessionState;

impl GuestThresholdSession for ThresholdSessionState {
    fn new() -> Self {
        Self
    }

    // ----- DKG -----

    fn dkg_part1(
        &self,
        max_signers: u32,
        min_signers: u32,
        secret_hex: String,
        coefficients_json: String,
    ) -> Result<DkgRound1Output, ThresholdError> {
        dkg_ops::dkg_part1(max_signers, min_signers, secret_hex, coefficients_json)
    }

    fn dkg_part2(
        &self,
        secret: Round1Secret,
        round1_packages_json: String,
        receiver_ids_json: String,
    ) -> Result<DkgRound2Output, ThresholdError> {
        dkg_ops::dkg_part2(secret, round1_packages_json, receiver_ids_json)
    }

    fn dkg_part3(
        &self,
        r2_secret: Round2Secret,
        round1_packages_json: String,
        round2_packages_json: String,
        receiver_ids_json: String,
    ) -> Result<DkgRound3Output, ThresholdError> {
        dkg_ops::dkg_part3(r2_secret, round1_packages_json, round2_packages_json, receiver_ids_json)
    }

    fn dkg_part3_receive(
        &self,
        my_id_hex: String,
        dealer_r1_json: String,
        shares_json: String,
        min_signers: u32,
        max_signers: u32,
        all_ids_json: String,
    ) -> Result<DkgRound3Output, ThresholdError> {
        dkg_ops::dkg_part3_receive(my_id_hex, dealer_r1_json, shares_json, min_signers, max_signers, all_ids_json)
    }

    // ----- Key Refresh -----

    fn dkg_refresh_part1(
        &self,
        id_hex: String,
        max_signers: u32,
        min_signers: u32,
        seed: Vec<u8>,
    ) -> Result<DkgRefreshRound1Output, ThresholdError> {
        dkg_ops::dkg_refresh_part1(id_hex, max_signers, min_signers, seed)
    }

    fn dkg_refresh_part2(
        &self,
        secret: Round1Secret,
        round1_packages_json: String,
    ) -> Result<DkgRound2Output, ThresholdError> {
        dkg_ops::dkg_refresh_part2(secret, round1_packages_json)
    }

    fn dkg_refresh_part3(
        &self,
        r2_secret: Round2Secret,
        round1_packages_json: String,
        round2_packages_json: String,
        old_pkp_json: String,
        old_kp_json: String,
    ) -> Result<DkgRound3Output, ThresholdError> {
        dkg_ops::dkg_refresh_part3(r2_secret, round1_packages_json, round2_packages_json, old_pkp_json, old_kp_json)
    }

    // ----- Signing -----

    fn new_nonce(&self, secret_hex: String) -> Result<NonceOutput, ThresholdError> {
        signing_ops::new_nonce(secret_hex)
    }

    fn frost_sign(
        &self,
        signing_package_json: String,
        nonce: SigningNonce,
        key_package_json: String,
    ) -> Result<String, ThresholdError> {
        signing_ops::frost_sign(signing_package_json, nonce, key_package_json)
    }

    fn frost_aggregate(
        &self,
        signing_package_json: String,
        shares_json: String,
        public_key_package_json: String,
    ) -> Result<String, ThresholdError> {
        signing_ops::frost_aggregate(signing_package_json, shares_json, public_key_package_json)
    }

    // ----- Key Operations -----

    fn key_package_tweak(
        &self,
        kp_json: String,
        merkle_root: Option<Vec<u8>>,
    ) -> Result<String, ThresholdError> {
        key_ops::key_package_tweak(kp_json, merkle_root)
    }

    fn pub_key_package_tweak(
        &self,
        pkp_json: String,
        merkle_root: Option<Vec<u8>>,
    ) -> Result<String, ThresholdError> {
        key_ops::pub_key_package_tweak(pkp_json, merkle_root)
    }

    fn key_package_into_even_y(&self, kp_json: String) -> Result<String, ThresholdError> {
        key_ops::key_package_into_even_y(kp_json)
    }

    fn pub_key_package_into_even_y(&self, pkp_json: String) -> Result<String, ThresholdError> {
        key_ops::pub_key_package_into_even_y(pkp_json)
    }

    // ----- Auth -----

    fn verify_schnorr_signature(
        &self,
        pk_hex: String,
        message: Vec<u8>,
        sig_hex: String,
    ) -> Result<bool, ThresholdError> {
        auth_ops::verify_schnorr_signature(pk_hex, message, sig_hex)
    }

    // ----- Ark Protocol -----

    fn ark_default_vtxo_script_pubkey(
        &self,
        server_pk_hex: String,
        owner_pk_hex: String,
        exit_delay: u32,
    ) -> Result<String, ThresholdError> {
        ark_ops::ark_default_vtxo_script_pubkey(server_pk_hex, owner_pk_hex, exit_delay)
    }

    fn ark_forfeit_spend_info(
        &self,
        server_pk_hex: String,
        owner_pk_hex: String,
        exit_delay: u32,
    ) -> Result<String, ThresholdError> {
        ark_ops::ark_forfeit_spend_info(server_pk_hex, owner_pk_hex, exit_delay)
    }

    fn ark_exit_spend_info(
        &self,
        server_pk_hex: String,
        owner_pk_hex: String,
        exit_delay: u32,
    ) -> Result<String, ThresholdError> {
        ark_ops::ark_exit_spend_info(server_pk_hex, owner_pk_hex, exit_delay)
    }

    // ----- Utils -----

    fn identifier_derive(&self, message: Vec<u8>) -> Result<String, ThresholdError> {
        util_ops::identifier_derive(message)
    }

    fn identifier_from_bigint(&self, hex_str: String) -> Result<String, ThresholdError> {
        util_ops::identifier_from_bigint(hex_str)
    }

    fn generate_coefficients(
        &self,
        count: u32,
        seed: Vec<u8>,
    ) -> Result<String, ThresholdError> {
        util_ops::generate_coefficients(count, seed)
    }

    fn evaluate_polynomial(
        &self,
        id_hex: String,
        coefficients_json: String,
    ) -> Result<String, ThresholdError> {
        util_ops::evaluate_polynomial(id_hex, coefficients_json)
    }

    fn mod_n_random(&self) -> Result<String, ThresholdError> {
        util_ops::mod_n_random()
    }

    fn elem_base_mul(&self, scalar_hex: String) -> Result<String, ThresholdError> {
        util_ops::elem_base_mul(scalar_hex)
    }
}

impl Guest for Component {
    type Round1Secret = Round1SecretState;
    type Round2Secret = Round2SecretState;
    type SigningNonce = SigningNonceState;
    type AuthSigner = AuthSignerState;
    type ThresholdSession = ThresholdSessionState;
    type DkgSession = session_state::DkgSessionState;
    type SigningSession = session_state::SigningSessionState;
    type RefreshSession = session_state::RefreshSessionState;
}

export!(Component);

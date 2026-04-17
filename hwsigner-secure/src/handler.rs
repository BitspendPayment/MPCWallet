//! Signer state and command handlers (Secure world).
//!
//! All secret operations — DKG, nonce generation, signing — happen here.
//! The Non-Secure world never has access to secret key material.

extern crate alloc;
use alloc::collections::BTreeMap;
use alloc::format;
use alloc::string::String;
use alloc::vec::Vec;

use k256::Scalar;
use threshold::dkg::{self, Round1Package, Round1SecretPackage, Round2Package, Round2SecretPackage};
use threshold::identifier::Identifier;
use threshold::keys::{KeyPackage, PublicKeyPackage};
use threshold::nonce::{self, SigningNonce};
use threshold::point;
use threshold::scalar::scalar_to_bytes;
use zeroize::Zeroize;

use crate::rng::SecureRng;

use crate::protocol;

// ---------------------------------------------------------------------------
// Signer state
// ---------------------------------------------------------------------------

pub struct SignerState {
    rng: SecureRng,
    r1_secret: Option<Round1SecretPackage>,
    r2_secret: Option<Round2SecretPackage>,
    key_package: Option<KeyPackage>,
    public_key_package: Option<PublicKeyPackage>,
    pending_nonce: Option<SigningNonce>,
    dkg_secret: Option<[u8; 32]>,
}

impl Drop for SignerState {
    fn drop(&mut self) {
        // Zero all secret material on drop
        if let Some(ref mut secret) = self.dkg_secret {
            secret.zeroize();
        }
        self.r1_secret = None;
        self.r2_secret = None;
        self.pending_nonce = None;
    }
}

impl SignerState {
    pub fn new(rng: SecureRng) -> Self {
        Self {
            rng,
            r1_secret: None,
            r2_secret: None,
            key_package: None,
            public_key_package: None,
            pending_nonce: None,
            dkg_secret: None,
        }
    }

    /// Restore key material loaded from flash.
    pub fn restore_keys(&mut self, kp: KeyPackage, pkp: PublicKeyPackage, dkg_secret: Option<[u8; 32]>) {
        self.key_package = Some(kp);
        self.public_key_package = Some(pkp);
        self.dkg_secret = dkg_secret;
    }

    pub fn key_package(&self) -> Option<&KeyPackage> {
        self.key_package.as_ref()
    }

    pub fn public_key_package(&self) -> Option<&PublicKeyPackage> {
        self.public_key_package.as_ref()
    }

    pub fn dkg_secret(&self) -> Option<&[u8; 32]> {
        self.dkg_secret.as_ref()
    }

    pub fn handle(&mut self, req: protocol::Request) -> protocol::Response {
        use protocol::{Request, Response};
        match req {
            Request::DkgInit { max_signers, min_signers } => {
                self.handle_dkg_init(max_signers, min_signers)
            }
            Request::RestoreInit { max_signers, min_signers } => {
                self.handle_restore_init(max_signers, min_signers)
            }
            Request::DkgRound2 { round1_packages, receiver_identifiers } => {
                self.handle_dkg_round2(round1_packages, receiver_identifiers)
            }
            Request::DkgRound3 { round1_packages, round2_packages, receiver_identifiers } => {
                self.handle_dkg_round3(round1_packages, round2_packages, receiver_identifiers)
            }
            Request::GenerateNonce => self.handle_generate_nonce(),
            Request::Sign { message_hex, commitments, apply_tweak, merkle_root_hex } => {
                self.handle_sign(message_hex, commitments, apply_tweak, merkle_root_hex)
            }
            Request::GetInfo => self.handle_get_info(),
        }
    }

    fn handle_dkg_init(&mut self, max_signers: usize, min_signers: usize) -> protocol::Response {
        let secret = random_scalar(&mut self.rng);
        let mut coefficients = Vec::with_capacity(min_signers - 1);
        for _ in 0..(min_signers - 1) {
            coefficients.push(random_scalar(&mut self.rng));
        }
        self.dkg_secret = Some(scalar_to_bytes(&secret));

        match dkg::dkg_part1(max_signers, min_signers, &secret, &coefficients, &mut self.rng) {
            Ok((secret_pkg, pub_pkg)) => {
                let id_hex = hex_encode(&secret_pkg.identifier.serialize());
                let vk_hex = hex_encode(&pub_pkg.verifying_key.serialize());
                let r1_json = pub_pkg.to_json_value();
                self.r1_secret = Some(secret_pkg);
                protocol::Response::DkgInit { round1_package_json: r1_json, verifying_key_hex: vk_hex, identifier_hex: id_hex }
            }
            Err(e) => protocol::Response::Error { error: format!("dkg_init failed: {}", e) },
        }
    }

    fn handle_restore_init(&mut self, max_signers: usize, min_signers: usize) -> protocol::Response {
        let secret_bytes = match &self.dkg_secret {
            Some(s) => *s,
            None => return protocol::Response::Error { error: "no DKG secret stored; cannot restore".into() },
        };
        let secret = match scalar_from_bytes(&secret_bytes) {
            Ok(s) => s,
            Err(e) => return protocol::Response::Error { error: e },
        };
        let mut coefficients = Vec::with_capacity(min_signers - 1);
        for _ in 0..(min_signers - 1) {
            coefficients.push(random_scalar(&mut self.rng));
        }
        match dkg::dkg_part1(max_signers, min_signers, &secret, &coefficients, &mut self.rng) {
            Ok((secret_pkg, pub_pkg)) => {
                let id_hex = hex_encode(&secret_pkg.identifier.serialize());
                let vk_hex = hex_encode(&pub_pkg.verifying_key.serialize());
                let r1_json = pub_pkg.to_json_value();
                self.r1_secret = Some(secret_pkg);
                protocol::Response::DkgInit { round1_package_json: r1_json, verifying_key_hex: vk_hex, identifier_hex: id_hex }
            }
            Err(e) => protocol::Response::Error { error: format!("restore_init failed: {}", e) },
        }
    }

    fn handle_dkg_round2(&mut self, round1_packages: BTreeMap<String, serde_json::Value>, receiver_identifier_hexes: Vec<String>) -> protocol::Response {
        let r1_secret = match &self.r1_secret {
            Some(s) => s,
            None => return protocol::Response::Error { error: "no round 1 secret package".into() },
        };
        let mut r1_pkgs: BTreeMap<Identifier, Round1Package> = BTreeMap::new();
        for (id_hex, pkg_json) in &round1_packages {
            let id = match parse_identifier(id_hex) { Ok(id) => id, Err(e) => return protocol::Response::Error { error: e } };
            let pkg = match Round1Package::from_json_value(pkg_json) { Ok(p) => p, Err(e) => return protocol::Response::Error { error: format!("failed to parse Round1Package: {}", e) } };
            r1_pkgs.insert(id, pkg);
        }
        let mut receiver_ids = Vec::new();
        for hex_str in &receiver_identifier_hexes {
            match parse_identifier(hex_str) { Ok(id) => receiver_ids.push(id), Err(e) => return protocol::Response::Error { error: e } }
        }
        match dkg::dkg_part2(r1_secret, &r1_pkgs, &receiver_ids) {
            Ok((r2_secret, r2_out)) => {
                let mut r2_map: BTreeMap<String, serde_json::Value> = BTreeMap::new();
                for (id, pkg) in &r2_out { r2_map.insert(hex_encode(&id.serialize()), pkg.to_json_value()); }
                self.r2_secret = Some(r2_secret);
                protocol::Response::DkgRound2 { round2_packages: r2_map }
            }
            Err(e) => protocol::Response::Error { error: format!("dkg_round2 failed: {}", e) },
        }
    }

    fn handle_dkg_round3(&mut self, round1_packages: BTreeMap<String, serde_json::Value>, round2_packages: BTreeMap<String, serde_json::Value>, receiver_identifier_hexes: Vec<String>) -> protocol::Response {
        let r1_secret = match &self.r1_secret { Some(s) => s, None => return protocol::Response::Error { error: "no round 1 secret package".into() } };
        let r2_secret = match &self.r2_secret { Some(s) => s, None => return protocol::Response::Error { error: "no round 2 secret package".into() } };
        let mut r1_pkgs: BTreeMap<Identifier, Round1Package> = BTreeMap::new();
        for (id_hex, pkg_json) in &round1_packages {
            let id = match parse_identifier(id_hex) { Ok(id) => id, Err(e) => return protocol::Response::Error { error: e } };
            let pkg = match Round1Package::from_json_value(pkg_json) { Ok(p) => p, Err(e) => return protocol::Response::Error { error: format!("failed to parse Round1Package: {}", e) } };
            r1_pkgs.insert(id, pkg);
        }
        let mut r2_pkgs: BTreeMap<Identifier, Round2Package> = BTreeMap::new();
        for (id_hex, pkg_json) in &round2_packages {
            let id = match parse_identifier(id_hex) { Ok(id) => id, Err(e) => return protocol::Response::Error { error: e } };
            let pkg = match Round2Package::from_json_value(pkg_json) { Ok(p) => p, Err(e) => return protocol::Response::Error { error: format!("failed to parse Round2Package: {}", e) } };
            r2_pkgs.insert(id, pkg);
        }
        let mut receiver_ids = Vec::new();
        for hex_str in &receiver_identifier_hexes { match parse_identifier(hex_str) { Ok(id) => receiver_ids.push(id), Err(e) => return protocol::Response::Error { error: e } } }
        match dkg::dkg_part3(r1_secret, r2_secret, &r1_pkgs, &r2_pkgs, &receiver_ids) {
            Ok((kp, pkp)) => {
                let id_hex = hex_encode(&kp.identifier.serialize());
                let pk_hex = hex_encode(&pkp.verifying_key.serialize());
                self.key_package = Some(kp);
                self.public_key_package = Some(pkp);
                self.r1_secret = None;
                self.r2_secret = None;
                protocol::Response::DkgRound3 { ok: true, identifier_hex: id_hex, public_key_hex: pk_hex }
            }
            Err(e) => protocol::Response::Error { error: format!("dkg_round3 failed: {}", e) },
        }
    }

    fn handle_generate_nonce(&mut self) -> protocol::Response {
        let kp = match &self.key_package { Some(kp) => kp, None => return protocol::Response::Error { error: "no key package".into() } };
        let signing_nonce = nonce::new_nonce(&mut self.rng, &kp.secret_share);
        let hiding_hex = hex_encode(&point::serialize_compressed(&signing_nonce.commitments.hiding));
        let binding_hex = hex_encode(&point::serialize_compressed(&signing_nonce.commitments.binding));
        self.pending_nonce = Some(signing_nonce);
        protocol::Response::GenerateNonce { hiding_hex, binding_hex }
    }

    fn handle_sign(&mut self, message_hex: String, commitments: BTreeMap<String, serde_json::Value>, apply_tweak: bool, merkle_root_hex: Option<String>) -> protocol::Response {
        let kp = match &self.key_package { Some(kp) => kp.clone(), None => return protocol::Response::Error { error: "no key package".into() } };
        let pkp = match &self.public_key_package { Some(pkp) => pkp.clone(), None => return protocol::Response::Error { error: "no public key package".into() } };
        let signing_nonce = match self.pending_nonce.take() { Some(n) => n, None => return protocol::Response::Error { error: "no pending nonce".into() } };
        let message = match hex_decode(&message_hex) { Ok(m) => m, Err(e) => return protocol::Response::Error { error: e } };
        let mut signing_commitments = BTreeMap::new();
        for (id_hex, comm_json) in &commitments {
            let id = match parse_identifier(id_hex) { Ok(id) => id, Err(e) => return protocol::Response::Error { error: e } };
            let hiding_hex = match comm_json["hiding"].as_str() { Some(h) => h, None => return protocol::Response::Error { error: "missing hiding commitment".into() } };
            let binding_hex = match comm_json["binding"].as_str() { Some(b) => b, None => return protocol::Response::Error { error: "missing binding commitment".into() } };
            let hiding = match parse_point(hiding_hex) { Ok(p) => p, Err(e) => return protocol::Response::Error { error: e } };
            let binding = match parse_point(binding_hex) { Ok(p) => p, Err(e) => return protocol::Response::Error { error: e } };
            signing_commitments.insert(id, threshold::nonce::SigningCommitments { binding, hiding });
        }
        let (final_kp, _final_pkp) = if apply_tweak {
            let merkle_root = merkle_root_hex.as_ref().and_then(|h| hex_decode(h).ok());
            let mr_ref = merkle_root.as_deref();
            (kp.tweak(mr_ref), pkp.tweak(mr_ref))
        } else { (kp, pkp) };
        let signing_package = threshold::commitment::SigningPackage::new(signing_commitments, message);
        match threshold::signing::sign(&signing_package, &signing_nonce, &final_kp) {
            Ok(share) => protocol::Response::Sign { share_hex: hex_encode(&scalar_to_bytes(&share.s)) },
            Err(e) => protocol::Response::Error { error: format!("sign failed: {}", e) },
        }
    }

    fn handle_get_info(&self) -> protocol::Response {
        let identifier_hex = self.key_package.as_ref().map(|kp| hex_encode(&kp.identifier.serialize()));
        protocol::Response::Info { has_key_package: self.key_package.is_some(), has_pending_nonce: self.pending_nonce.is_some(), identifier_hex }
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn scalar_from_bytes(bytes: &[u8; 32]) -> Result<Scalar, String> {
    use k256::elliptic_curve::scalar::FromUintUnchecked;
    use k256::U256;
    let uint = U256::from_be_slice(bytes);
    let s = Scalar::from_uint_unchecked(uint);
    if bool::from(s.is_zero()) { return Err("stored DKG secret is zero".into()); }
    Ok(s)
}

fn random_scalar(rng: &mut impl rand_core::RngCore) -> Scalar {
    use k256::elliptic_curve::ops::Reduce;
    use k256::U256;
    loop {
        let mut bytes = [0u8; 32];
        rng.fill_bytes(&mut bytes);
        let wide = U256::from_be_slice(&bytes);
        let s = <Scalar as Reduce<U256>>::reduce(wide);
        if !bool::from(s.is_zero()) { return s; }
    }
}

fn hex_encode(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{:02x}", b)).collect()
}

fn hex_decode(s: &str) -> Result<Vec<u8>, String> {
    if s.len() % 2 != 0 { return Err("odd-length hex string".into()); }
    let mut out = Vec::with_capacity(s.len() / 2);
    for i in (0..s.len()).step_by(2) {
        let byte = u8::from_str_radix(&s[i..i + 2], 16).map_err(|_| format!("invalid hex at position {}", i))?;
        out.push(byte);
    }
    Ok(out)
}

fn parse_identifier(hex_str: &str) -> Result<Identifier, String> {
    let bytes = hex_decode(hex_str)?;
    if bytes.len() != 32 { return Err(format!("identifier must be 32 bytes, got {}", bytes.len())); }
    let mut arr = [0u8; 32];
    arr.copy_from_slice(&bytes);
    Identifier::deserialize(&arr).map_err(|e| format!("invalid identifier: {}", e))
}

fn parse_point(hex_str: &str) -> Result<k256::ProjectivePoint, String> {
    let bytes = hex_decode(hex_str)?;
    if bytes.len() != 33 { return Err(format!("point must be 33 bytes, got {}", bytes.len())); }
    let mut arr = [0u8; 33];
    arr.copy_from_slice(&bytes);
    point::deserialize_compressed(&arr).map_err(|e| format!("invalid point: {}", e))
}

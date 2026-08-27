//! The service's identity: `service_id`.
//!
//! A secp256k1 keypair whose public half names the service. It has two jobs, both of which happen
//! BEFORE the service holds a share:
//!
//! 1. **It receives the halves.** Both dealers ECIES-seal their half to `service_id`, so only the
//!    holder of the matching secret can open them.
//! 2. **It names the point on the polynomial.** The FROST identifier is `H(service_id) mod n`, and
//!    all three parties derive it the same way — which is how they agree which share is the
//!    service's before that share exists.
//!
//! It is deliberately NOT called a verifying key: it never signs anything. The service's signing
//! credential appears only after enrolment — its FROST **verifying share**, proved by signing with
//! the matching secret share (see [`crate::share::ServiceShare::auth_signer`]). Two identities,
//! two eras: `service_id` before the share exists, the verifying share after.

use crate::error::{Error, Result};
use k256::Scalar;
use threshold::auth::AuthSigner;
use threshold::identifier::Identifier;
use threshold::scalar::scalar_from_bytes;

/// A service's identity keypair.
pub struct ServiceIdentity {
    secret: Scalar,
    id: [u8; 33],
    identifier: Identifier,
}

impl ServiceIdentity {
    /// Build an identity from 32 secret bytes.
    pub fn from_secret_bytes(bytes: &[u8; 32]) -> Result<Self> {
        let secret = scalar_from_bytes(bytes)?;
        // `AuthSigner` is used only to derive the public point; nothing here ever signs.
        let id = AuthSigner::from_secret_bytes(bytes)?.public_key_compressed();
        let identifier = Identifier::derive(&id)?;
        Ok(Self {
            secret,
            id,
            identifier,
        })
    }

    /// Build an identity from a hex-encoded 32-byte secret.
    pub fn from_secret_hex(hex_str: &str) -> Result<Self> {
        let raw = hex::decode(hex_str.trim())
            .map_err(|e| Error::Config(format!("service secret is not hex: {e}")))?;
        let bytes: [u8; 32] = raw
            .try_into()
            .map_err(|_| Error::Config("service secret must be 32 bytes".into()))?;
        Self::from_secret_bytes(&bytes)
    }

    /// Generate a fresh identity.
    pub fn generate() -> Result<Self> {
        let s = threshold::random::mod_n_random(&mut rand::rngs::OsRng);
        Self::from_secret_bytes(&threshold::scalar::scalar_to_bytes(&s))
    }

    /// The compressed public id the dealers seal their halves to, and derive the identifier from.
    pub fn id(&self) -> &[u8; 33] {
        &self.id
    }

    pub fn id_hex(&self) -> String {
        hex::encode(self.id)
    }

    /// The FROST identifier this service occupies on every pairing polynomial dealt to it.
    pub fn identifier(&self) -> &Identifier {
        &self.identifier
    }

    /// The decryption key for the sealed halves. Crate-internal: nothing outside enrolment has a
    /// reason to touch the raw scalar.
    pub(crate) fn secret(&self) -> &Scalar {
        &self.secret
    }
}

impl core::fmt::Debug for ServiceIdentity {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        write!(f, "ServiceIdentity({})", self.id_hex())
    }
}

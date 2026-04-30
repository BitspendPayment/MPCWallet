use thiserror::Error;

#[derive(Error, Debug)]
pub enum Error {
    #[error("ExpectedPCR0 is required")]
    MissingPCR0,

    #[error("attestation verification failed: {0}")]
    AttestationVerification(String),

    #[error("PCR{index} mismatch: expected {expected}, got {actual}")]
    PcrMismatch {
        index: u32,
        expected: String,
        actual: String,
    },

    #[error("PCR{0} not found in attestation document")]
    PcrNotFound(u32),

    #[error("attestation nonce mismatch")]
    NonceMismatch,

    #[error("attestation missing nonce")]
    MissingNonce,

    #[error("attestation missing PCR0")]
    MissingPCR0InDocument,

    #[error("key binding verification failed: {0}")]
    KeyBinding(String),

    #[error("signature verification failed")]
    SignatureVerification,

    #[error("manifest error: {0}")]
    Manifest(String),

    #[error("provenance verification failed: {0}")]
    Provenance(String),

    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("CBOR error: {0}")]
    Cbor(String),

    #[error("COSE error: {0}")]
    Cose(String),

    #[error("base64 decode error: {0}")]
    Base64(#[from] base64::DecodeError),

    #[error("hex decode error: {0}")]
    Hex(#[from] hex::FromHexError),

    #[error("certificate error: {0}")]
    Certificate(String),

    #[error("{0}")]
    Other(String),
}

pub type Result<T> = std::result::Result<T, Error>;

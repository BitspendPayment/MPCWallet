use thiserror::Error;

/// Everything the SDK can refuse to do.
#[derive(Debug, Error)]
pub enum Error {
    #[error("crypto: {0}")]
    Crypto(String),

    /// The invariant that keeps two services from reconstructing the group key.
    #[error("service-share invariant: {0}")]
    Invariant(String),

    #[error("the cosigner rejected the request: {0}")]
    Cosigner(String),

    #[error("transport: {0}")]
    Transport(String),

    #[error("share store: {0}")]
    Store(String),

    #[error("{0}")]
    Config(String),
}

impl From<threshold::error::Error> for Error {
    fn from(e: threshold::error::Error) -> Self {
        Error::Crypto(format!("{e:?}"))
    }
}

pub type Result<T> = core::result::Result<T, Error>;

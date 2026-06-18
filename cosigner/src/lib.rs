wit_bindgen::generate!({
    world: "threshold-world",
    path: "wit",
});

mod auth_ops;
mod convert;
mod signing_ops;
mod key_ops;
mod util_ops;
mod session_state;

use std::cell::RefCell;

use crate::exports::component::threshold::types::*;

struct Component;

// ---------------------------------------------------------------------------
// Resource implementations
// ---------------------------------------------------------------------------

pub struct AuthSignerState {
    inner: RefCell<threshold::auth::AuthSigner>,
}

impl GuestAuthSigner for AuthSignerState {
    fn new(secret_hex: String) -> Self {
        let bytes =
            convert::hex_decode_32(&secret_hex).expect("invalid secret hex for AuthSigner");
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

// The signing `session` resource (state + ops + nonce) is implemented in
// `session_state` as `GuestSession for SessionState`.
impl Guest for Component {
    type AuthSigner = AuthSignerState;
    type Session = session_state::SessionState;
}

export!(Component);

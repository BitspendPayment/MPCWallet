//! The endpoint a service exposes so the two dealers can push it their halves.
//!
//! Mount [`enrollment_router`] into whatever the service already serves. It is deliberately the
//! only route this crate provides: everything else a service does, it initiates.

use std::sync::Arc;

use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::post;
use axum::{Json, Router};
use serde_json::{json, Value};

use crate::identity::ServiceIdentity;
use crate::intake::{EnrollmentHalf, EnrollmentInbox, Intake};
use crate::share::ShareStore;

/// What the enrolment route needs.
#[derive(Clone)]
pub struct EnrollmentState {
    pub identity: Arc<ServiceIdentity>,
    pub store: Arc<dyn ShareStore>,
    pub inbox: Arc<EnrollmentInbox>,
}

/// `POST /enroll/half` — one dealer delivering its half.
///
/// Unauthenticated by design. A half is believed because the pair sums to the verifying share the
/// pairing package publishes, not because of who sent it, so a signature here would add no
/// correctness. What keeps a stranger from planting a pairing is the inbox's wallet allowlist.
/// Put this behind whatever transport controls the deployment already has; do not mistake it for
/// an open door.
pub fn enrollment_router(state: EnrollmentState) -> Router {
    Router::new()
        .route("/enroll/half", post(receive_half))
        .with_state(state)
}

async fn receive_half(
    State(state): State<EnrollmentState>,
    Json(half): Json<EnrollmentHalf>,
) -> (StatusCode, Json<Value>) {
    match state
        .inbox
        .accept(state.identity.as_ref(), state.store.as_ref(), &half)
    {
        Ok(Intake::AwaitingOther(role)) => (
            StatusCode::ACCEPTED,
            Json(json!({ "status": "awaiting", "waiting_on": role })),
        ),
        Ok(Intake::Enrolled(share)) => {
            tracing::info!(
                verifying_share = %share.verifying_share_hex,
                "enrolled: both halves verified against the pairing package"
            );
            (
                StatusCode::OK,
                Json(json!({
                    "status": "enrolled",
                    "verifying_share": share.verifying_share_hex,
                })),
            )
        }
        Ok(Intake::AlreadyEnrolled) => (
            StatusCode::OK,
            Json(json!({ "status": "already_enrolled" })),
        ),
        Err(e) => {
            // Loud on purpose: a rejected half means an enrolment is silently not going to work,
            // and the dealer that sent it is the only party positioned to notice.
            tracing::warn!(error = %e, "rejected an enrolment half");
            (
                StatusCode::BAD_REQUEST,
                Json(json!({ "status": "rejected", "error": e.to_string() })),
            )
        }
    }
}

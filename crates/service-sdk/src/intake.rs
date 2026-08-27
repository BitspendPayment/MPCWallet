//! Receiving enrolment halves.
//!
//! The service EXPOSES an endpoint and the two dealers push to it independently over TLS: the
//! wallet sends the half it dealt (`a@service`), the cosigner sends the half it dealt
//! (`b@service`). Because the service is the SERVER for this hop, it never has to authenticate
//! itself before it owns a share — that bootstrap problem simply does not arise.
//!
//! Each half stays ECIES-sealed to `service_id` even though delivery is point-to-point. Not for
//! opacity to a courier — there is none — but so that a half is bound to the identity that will
//! hold the share rather than to the URL it was sent to.
//!
//! # Why sender authentication is not the security boundary
//!
//! A half is not believed because of who sent it. It is believed because the two halves sum to the
//! verifying share the pairing package publishes ([`crate::enrollment::verify`]), and a forged
//! half fails that check. Rejecting unknown senders is therefore about **noise and abuse**, not
//! correctness — which is why the one check that IS load-bearing here is the wallet allowlist:
//! without it a stranger could push a self-consistent pairing for a key of their choosing and the
//! service would happily hold a share of it.
//!
//! # Ordering
//!
//! The two pushes race, and either may arrive first, twice, or never. Halves stage by the
//! service's verifying share — which both dealers know, because the cosigner returns it to the
//! wallet at enrolment — and the share is assembled the moment the pair is complete.

use crate::enrollment::{self, EnrollmentBundle};
use crate::error::{Error, Result};
use crate::identity::ServiceIdentity;
use crate::share::{ServiceShare, ShareStore};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Mutex;
use threshold::keys::PublicKeyPackage;

/// Which dealer a half came from.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum HalfRole {
    /// `a@service` — dealt by the wallet.
    User,
    /// `b@service` — dealt by the cosigner.
    Cosigner,
}

/// One dealer's contribution, as it arrives on the wire.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnrollmentHalf {
    pub role: HalfRole,
    /// The wallet's group key — the actor this pairing signs under.
    pub pairing_group_key: String,
    /// The service's verifying share hex. Both dealers know it, and it is what the two halves are
    /// matched on.
    pub service_verifying_share: String,
    /// The pairing's public key package, JSON. Sent by BOTH dealers on purpose: it is what the
    /// halves are checked against, so requiring the two copies to agree means the service does not
    /// depend on a single channel for it.
    pub pairing_public_key_package_json: String,
    /// This dealer's ECIES-sealed half, hex.
    pub ecies_half: String,
}

/// What happened to a delivered half.
#[derive(Debug, Clone)]
pub enum Intake {
    /// Staged; the other dealer has not delivered yet.
    AwaitingOther(HalfRole),
    /// Both halves present, verified, and stored.
    Enrolled(Box<ServiceShare>),
    /// Both halves were already present and the share is already held.
    AlreadyEnrolled,
}

impl Intake {
    /// The share, if this delivery completed the pairing.
    pub fn share(&self) -> Option<&ServiceShare> {
        match self {
            Intake::Enrolled(s) => Some(s),
            _ => None,
        }
    }

    pub fn is_enrolled(&self) -> bool {
        matches!(self, Intake::Enrolled(_))
    }
}

#[derive(Default)]
struct Pending {
    user: Option<String>,
    cosigner: Option<String>,
    pkp_json: Option<String>,
    group_key: Option<String>,
}

/// Stages arriving halves until a pair is complete.
///
/// In memory on purpose: a half is worthless alone and cheap to resend, so losing staged halves on
/// restart costs a re-push, not a re-enrolment. Persisting them would mean holding one half of a
/// share at rest for no gain.
pub struct EnrollmentInbox {
    pending: Mutex<HashMap<String, Pending>>,
    /// Wallet group keys this service will enrol under. EMPTY MEANS ACCEPT NONE — a service that
    /// has not been told whose shares it holds should not be guessing.
    allowed_wallets: Vec<String>,
}

impl EnrollmentInbox {
    /// Build an inbox that will enrol under exactly these wallet group keys.
    pub fn new(allowed_wallets: impl IntoIterator<Item = String>) -> Self {
        Self {
            pending: Mutex::new(HashMap::new()),
            allowed_wallets: allowed_wallets
                .into_iter()
                .map(|w| w.to_ascii_lowercase())
                .collect(),
        }
    }

    /// Accept one delivered half.
    ///
    /// Returns [`Intake::Enrolled`] exactly once per pairing — on the delivery that completes the
    /// pair. Redelivery of an already-enrolled pairing is reported, not re-verified.
    pub fn accept(
        &self,
        identity: &ServiceIdentity,
        store: &dyn ShareStore,
        half: &EnrollmentHalf,
    ) -> Result<Intake> {
        let vs = half.service_verifying_share.to_ascii_lowercase();
        let group_key = half.pairing_group_key.to_ascii_lowercase();

        if !self.allowed_wallets.contains(&group_key) {
            return Err(Error::Config(format!(
                "refusing an enrolment for wallet {group_key}: not in this service's allowlist"
            )));
        }

        // The verifying share must actually be in the package the halves will be checked against,
        // or the two dealers are describing different pairings.
        let pkp = PublicKeyPackage::from_json(&half.pairing_public_key_package_json)?;
        let published = pkp
            .verifying_shares
            .get(identity.identifier())
            .ok_or_else(|| Error::Crypto("pairing package has no share for this service".into()))?;
        if hex::encode(threshold::point::serialize_compressed(published)) != vs {
            return Err(Error::Crypto(
                "the named verifying share is not this service's share of that pairing".into(),
            ));
        }

        if store.get(&vs)?.is_some() {
            return Ok(Intake::AlreadyEnrolled);
        }

        let mut pending = self
            .pending
            .lock()
            .map_err(|_| Error::Store("enrolment inbox poisoned".into()))?;
        let slot = pending.entry(vs.clone()).or_default();

        // Both dealers send the package; disagreement means one of them is lying or stale, and
        // there is no way to tell which — so refuse rather than pick.
        if let Some(existing) = &slot.pkp_json {
            if existing != &half.pairing_public_key_package_json {
                pending.remove(&vs);
                return Err(Error::Invariant(
                    "the wallet and the cosigner sent different pairing packages for one \
                     enrolment — refusing both"
                        .into(),
                ));
            }
        } else {
            slot.pkp_json = Some(half.pairing_public_key_package_json.clone());
            slot.group_key = Some(group_key);
        }

        match half.role {
            HalfRole::User => slot.user = Some(half.ecies_half.clone()),
            HalfRole::Cosigner => slot.cosigner = Some(half.ecies_half.clone()),
        }

        let (Some(a), Some(b)) = (slot.user.clone(), slot.cosigner.clone()) else {
            let waiting_on = match half.role {
                HalfRole::User => HalfRole::Cosigner,
                HalfRole::Cosigner => HalfRole::User,
            };
            return Ok(Intake::AwaitingOther(waiting_on));
        };
        let bundle = EnrollmentBundle {
            pairing_group_key: slot.group_key.clone().unwrap_or_default(),
            pairing_public_key_package_json: slot.pkp_json.clone().unwrap_or_default(),
            ecies_a_at_service: a,
            ecies_b_at_service: b,
        };
        drop(pending);

        // The real check: the halves must sum to the share the package publishes. A forged half
        // dies here regardless of who sent it.
        let share = enrollment::accept(identity, store, &bundle)?;
        self.pending
            .lock()
            .map_err(|_| Error::Store("enrolment inbox poisoned".into()))?
            .remove(&vs);
        Ok(Intake::Enrolled(Box::new(share)))
    }

    /// How many pairings are half-delivered. Useful as a health signal: a number that does not
    /// fall means one dealer keeps failing to reach this service.
    pub fn pending_count(&self) -> usize {
        self.pending.lock().map(|p| p.len()).unwrap_or(0)
    }
}

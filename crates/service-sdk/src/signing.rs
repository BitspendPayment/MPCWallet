//! Co-signing under an enrolled share.

use crate::client::CosignerClient;
use crate::error::{Error, Result};
use crate::share::ServiceShare;
use std::collections::BTreeMap;
use threshold::commitment::SigningPackage;
use threshold::identifier::Identifier;
use threshold::nonce::{new_nonce, SigningCommitments};

fn parse_commitment(hiding: &str, binding: &str) -> Result<SigningCommitments> {
    let h: [u8; 33] = hex::decode(hiding)
        .map_err(|e| Error::Transport(format!("bad hiding commitment: {e}")))?
        .try_into()
        .map_err(|_| Error::Transport("hiding commitment must be 33 bytes".into()))?;
    let b: [u8; 33] = hex::decode(binding)
        .map_err(|e| Error::Transport(format!("bad binding commitment: {e}")))?
        .try_into()
        .map_err(|_| Error::Transport("binding commitment must be 33 bytes".into()))?;
    Ok(SigningCommitments {
        hiding: threshold::point::deserialize_compressed(&h)?,
        binding: threshold::point::deserialize_compressed(&b)?,
    })
}

/// Drive a full two-round FROST co-sign under `share`, returning the aggregated 64-byte signature.
///
/// The service plays the "user" role: it commits first, the cosigner replies with the full
/// commitment set and the message it will sign, and the service produces its share against that.
///
/// Two things are deliberately checked rather than assumed:
///
/// - **The polynomial.** A share is only valid on its own polynomial. The share carries the
///   wallet group key it belongs to, and identifies itself by its verifying share — the cosigner
///   resolves that to the matching counter-share, so a share can only ever join its own pairing's
///   ceremony.
/// - **The message.** A conditioned pairing OVERRIDES what it signs — the cosigner is
///   authoritative, not the caller. So the message signed is the one the cosigner returned, and if
///   that differs from what was requested the caller is told rather than silently signing
///   something else.
pub async fn cosign(
    client: &CosignerClient,
    share: &ServiceShare,
    message_to_sign: &[u8],
    full_transaction: &[u8],
    script_path_spend: bool,
) -> Result<[u8; 64]> {
    let key_package = share.key_package()?;

    // Single-use nonce, mixed with the secret share (never reused across ceremonies).
    let nonce = new_nonce(&mut rand::rngs::OsRng, &key_package.secret_share);

    let step1 = client
        .sign_step1(
            share,
            &share.pairing_group_key,
            &threshold::point::serialize_compressed(&nonce.commitments.hiding),
            &threshold::point::serialize_compressed(&nonce.commitments.binding),
            message_to_sign,
            full_transaction,
            script_path_spend,
        )
        .await?;

    let agreed = hex::decode(&step1.message_to_sign)
        .map_err(|e| Error::Transport(format!("bad message_to_sign: {e}")))?;
    if agreed != message_to_sign {
        return Err(Error::Cosigner(format!(
            "the cosigner will sign a different message than requested ({} vs {}) — a conditioned \
             pairing rebuilds what it signs, so resubmit against the message it named",
            step1.message_to_sign,
            hex::encode(message_to_sign)
        )));
    }

    let mut commitments: BTreeMap<Identifier, SigningCommitments> = BTreeMap::new();
    for (id_hex, (hiding, binding)) in &step1.commitments {
        let raw: [u8; 32] = hex::decode(id_hex)
            .map_err(|e| Error::Transport(format!("bad identifier in commitments: {e}")))?
            .try_into()
            .map_err(|_| Error::Transport("identifier must be 32 bytes".into()))?;
        commitments.insert(
            Identifier::deserialize(&raw)?,
            parse_commitment(hiding, binding)?,
        );
    }
    if !commitments.contains_key(&key_package.identifier) {
        return Err(Error::Cosigner(
            "the ceremony does not include this service's commitments".into(),
        ));
    }

    let package = SigningPackage::new(commitments, agreed);
    let share_out = threshold::signing::sign(&package, &nonce, &key_package)?;

    client
        .sign_step2(
            share,
            &share.pairing_group_key,
            &threshold::scalar::scalar_to_bytes(&share_out.s),
        )
        .await
}

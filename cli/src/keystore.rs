//! Local keystore for the regtest REPL.
//!
//! Holds each wallet's FROST key package — i.e. REAL SIGNING SECRETS — in plaintext under
//! `~/.merlin-cli/wallets.json`. This is a regtest/dev driver only. Never point it at a wallet
//! holding real funds.

use std::collections::BTreeMap;
use std::path::PathBuf;

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Wallet {
    /// Group verifying key (hex) — the actor id, and the `{group_key}` segment in every URL.
    pub group_key: String,
    /// This client's auth identity: the compressed pubkey (hex) derived from its FROST secret
    /// share. It's what the cosigner's `verify_auth` checks signatures against, and what a payer
    /// allowlists to let this wallet bill them.
    pub user_id_hex: String,
    /// The client's FROST key package. Contains the secret share.
    pub key_package_json: String,
    pub public_key_package_json: String,
}

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct Keystore {
    #[serde(default)]
    pub wallets: BTreeMap<String, Wallet>,
    #[serde(default)]
    pub active: Option<String>,
}

impl Keystore {
    pub fn path() -> Result<PathBuf> {
        let dir = dirs::home_dir()
            .context("no home directory")?
            .join(".merlin-cli");
        Ok(dir.join("wallets.json"))
    }

    pub fn load() -> Result<Self> {
        let path = Self::path()?;
        if !path.exists() {
            return Ok(Self::default());
        }
        let raw = std::fs::read_to_string(&path)
            .with_context(|| format!("read {}", path.display()))?;
        serde_json::from_str(&raw).with_context(|| format!("parse {}", path.display()))
    }

    pub fn save(&self) -> Result<()> {
        let path = Self::path()?;
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)
                .with_context(|| format!("create {}", parent.display()))?;
        }
        let json = serde_json::to_string_pretty(self)?;
        std::fs::write(&path, json).with_context(|| format!("write {}", path.display()))?;
        Ok(())
    }

    /// The currently selected wallet, if any.
    pub fn active(&self) -> Option<(&str, &Wallet)> {
        let name = self.active.as_deref()?;
        self.wallets.get(name).map(|w| (name, w))
    }

    /// Resolve a name that may be a wallet alias, else treat it as a raw hex key. Lets commands
    /// take either `bob` or `03a1b2…` wherever a counterparty is named.
    pub fn resolve_group_key(&self, name_or_hex: &str) -> String {
        self.wallets
            .get(name_or_hex)
            .map(|w| w.group_key.clone())
            .unwrap_or_else(|| name_or_hex.to_string())
    }

}

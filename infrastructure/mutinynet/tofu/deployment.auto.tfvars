# mutinynet deployment configuration — the host-mode counterpart to ../../mutiny/enclave.yaml.
#
# Auto-loaded by tofu (any *.auto.tfvars is), so there is no -var-file to remember. Committed on
# purpose: everything here is public infrastructure config. Secrets are NOT here — they live in
# secrets.auto.tfvars.json, which .gitignore excludes. See the README's "Secrets" section.
#
# Values are stated explicitly even where they match a variable default, so the whole deployment
# is readable in one place rather than reconstructed from defaults scattered across main.tf.

# ── AWS ───────────────────────────────────────────────────────────────────────
# `account` is the one variable with no default: without it here, tofu prompts on every apply.
account = "639920118099"

# The machine's DEFAULT profile is a different account (071680046198), so pin the profile rather
# than rely on the ambient environment. The provider's allowed_account_ids = [account] enforces the
# match, and the module passes this to the redeploy's local-exec, which does not inherit provider
# credentials. Set to "" to use ambient credentials instead (CI, instance role).
aws_profile = "mpc-deployer"

region     = "us-east-1"
deployment = "mutinynet"
app_name   = "cosigner"

# ── Instance + storage ────────────────────────────────────────────────────────
# 2 GiB fits the workload: a Rust binary (no VM/JVM) whose KV is SQLite on disk, whose idle actors
# evict, and which never compiles here — the release binary is built locally and pushed via S3+SSM.
instance_type = "t3.small"

# Holds state.db and Caddy's ACME certs, nothing else.
data_volume_size = 4

# 8 is the FLOOR. EBS refuses a root smaller than the AMI snapshot and AL2023 ships an 8 GiB one,
# so 4 fails the apply with InvalidBlockDeviceMapping. Nothing persistent lives on root.
root_volume_size = 8

# ── DNS + TLS ─────────────────────────────────────────────────────────────────
# The app waives attestation for exactly this hostname (see requiresAttestation() in
# app/lib/services/server_host.dart). Mainnet must never be served from this stack — the sealed
# FROST shares are plaintext on the data volume.
fqdn            = "mutiny.vtxos.network"
acme_email      = "joshua@vtxos.app"
route53_zone_id = "Z0182614JSFDPB9F5ALY"

# ── Upstreams ─────────────────────────────────────────────────────────────────
# BITCOIN_NETWORK is only a display hint; the authoritative network comes from the ASP's GetArkInfo.
asp_url     = "https://mutinynet.arkade.sh"
esplora_url = "https://mutinynet.com/api"

# ── WebAuthn ──────────────────────────────────────────────────────────────────
# The RP ID is deliberately NOT this deployment's hostname. A passkey is scoped to its RP ID, so
# pointing it at mutiny.vtxos.network would orphan every credential already registered under
# vtxos.com. It also need not match the API host: the cosigner is its own Relying Party, and
# Android verifies the association by fetching https://<rp_id>/.well-known/assetlinks.json.
webauthn_rp_id     = "vtxos.com"
webauthn_rp_origin = "https://vtxos.com"
webauthn_rp_name   = "Merlin"

# Both signing-cert fingerprints, comma-separated — webauthn_server.rs splits on ',', so debug and
# release builds validate against one server. Recompute with the python one-liner in the README.
webauthn_android_origin = "android:apk-key-hash:u1pNepeObJUpSkSqH964HvFRqbhC_ejQP3GHA3-lreI,android:apk-key-hash:Lf1QIwQnlPBYPwDFhloUkYC-0tYAKSpKCQbEiyz118s"

# ── Runtime environment ───────────────────────────────────────────────────────
# Non-secret env for the runtime, merged over the module's base_env and written to SSM as String.
# No pre-declaration needed: the runtime overlays every key under its SSM prefix onto its process
# env, so adding a line here is enough. Re-read on restart — an SSM write, never a rebuild.
#
# Do NOT set ASP_URL / ESPLORA_URL / WEBAUTH_* here; they have typed variables above and are
# already folded into base_env.
env_overrides = {
  # AUTO_SETTLE_SAFETY_MARGIN_SECS = "3600"
  # ACTOR_IDLE_THRESHOLD_SECS      = "1800"
  # BOARDING_WATCH_INTERVAL_SECS   = "30"
}

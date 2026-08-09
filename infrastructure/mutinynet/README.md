# mutinynet — host-mode deployment

Runs `cosigner-runtime` as a plain systemd service on one EC2 instance, with its
SQLite KV on a dedicated EBS volume and Caddy terminating TLS in front.

> **Testnet only.** There is no Nitro enclave here. The actor's sealed state —
> which holds each wallet's server-side FROST share and its Ark cosigner secret —
> is plaintext JSON in `state.db` on an EBS volume. Anyone with host or volume
> access can read it. That share is one half of a 2-of-2, so it cannot spend on
> its own, and these are signet coins, but **mainnet must never be served this
> way.** Mainnet belongs on the enclave stack in [`../mutiny/`](../mutiny/).
>
> The app enforces the split: `requiresAttestation()` in
> [`app/lib/services/server_host.dart`](../../app/lib/services/server_host.dart)
> waives attestation for `mutiny.vtxos.network` and demands it everywhere else,
> including `mainnet.vtxos.network` and any host nobody has classified.

Kept separate from `../mutiny/` on purpose: that stack is generated and managed
by the external `enclave` CLI. Moving to the enclave later means applying that
stack instead of this one, not unpicking toggles inside one shared tree.

## What gets created

| | |
|---|---|
| VPC + public subnet + IGW | `10.20.0.0/16`, single AZ |
| Security group | inbound 80 (ACME + redirect) and 443 only; runtime's 7074 stays on loopback |
| EC2 instance | `t3.medium` Amazon Linux 2023, no SSH — shell is SSM Session Manager |
| EBS data volume | 20 GiB gp3, encrypted, `prevent_destroy` |
| Elastic IP + Route53 A record | `mutiny.vtxos.network` |
| S3 assets bucket | holds the deployed runtime binary |
| SSM parameters | `/mutinynet/cosigner/env/*` — the runtime's environment |

Everything that must survive an instance replacement lives on the data volume:

```
/mnt/data/cosigner/state.db   SQLite KV (sealed shares, VTXOs, contacts, history)
/mnt/data/caddy/              ACME certs + account key
```

Caddy's storage is there deliberately. Let's Encrypt rate-limits duplicate
certificates to 5/week, which a handful of instance replacements would exhaust.

## Prerequisites

- OpenTofu ≥ 1.6, AWS credentials for account `639920118099`
- `aws` CLI on PATH (the in-place redeploy shells out to `aws ssm send-command`)
- A release build of the runtime:

```bash
cd cosigner-runtime && cargo build --release
```

## Secrets

Create `tofu/secrets.auto.tfvars.json` — gitignored, never commit it:

```bash
cd infrastructure/mutinynet/tofu

jq -n \
  --arg tok "$(openssl rand -hex 32)" \
  --arg fcm "$(jq -c . ~/secrets/vtxos-fcm.json)" \
  '{secret_env: {WEBAUTH_TOKEN_SECRET: $tok, FCM_SERVICE_ACCOUNT_JSON: $fcm}}' \
  > secrets.auto.tfvars.json
```

Both land in SSM as `SecureString`. Notes:

- **`WEBAUTH_TOKEN_SECRET`** must be exactly 32 bytes of hex. Without it the
  runtime logs `Session-token auth DISABLED` and **every request from a
  passkey-gated wallet is rejected** — the wallet authenticates by session token
  alone, with an empty Schnorr signature. Rotating it invalidates live sessions.
- **`FCM_SERVICE_ACCOUNT_JSON`** is optional but gates more than push: with it
  unset the runtime also disables the **boarding watcher**, even though
  `ESPLORA_URL` is configured. Verified in a live boot:
  `ESPLORA_URL set but FCM unconfigured; boarding watcher disabled`.

## Android passkeys — nothing to deploy here

**This host does not serve `assetlinks.json`, and should not.**

The WebAuthn RP ID is `vtxos.com`, *not* this deployment's hostname. Those are
independent: the cosigner is its own Relying Party and simply declares an RP ID,
while Android's Credential Manager verifies the app↔RP association by fetching
`https://<rp_id>/.well-known/assetlinks.json`. There is no same-origin check
tying the RP ID to the REST endpoint. Regtest already proves it — the `software`
target in the [Makefile](../../Makefile) runs the server on `127.0.0.1` with
`WEBAUTH_RP_ID=vtxos.com`.

`https://vtxos.com/.well-known/assetlinks.json` is already live and already
lists `com.vtxos.app` with both signing-cert fingerprints and the
`delegate_permission/common.get_login_creds` relation. Nothing more is needed.

Keeping the RP ID at `vtxos.com` also means **existing passkeys keep working**.
Credentials are bound to the RP ID, so moving it to `mutiny.vtxos.network` would
orphan every one already registered.

`webauthn_android_origin` defaults to both fingerprints, comma-separated —
`webauthn_server.rs` splits on `,`, so debug and release builds both validate
against one server. To recompute after a signing-key change:

```bash
python3 -c "import base64,sys; print('android:apk-key-hash:'+base64.urlsafe_b64encode(bytes.fromhex(sys.argv[1].replace(':',''))).decode().rstrip('='))" \
  "BB:5A:4D:..."
```

Update [`app/assetlinks.json`](../../app/assetlinks.json), redeploy it to
vtxos.com, and set the new value here — in that order.

## Deploy

```bash
cd infrastructure/mutinynet/tofu
tofu init
tofu plan
tofu apply
```

DNS must resolve to the EIP before Caddy can complete its ACME challenge. The
Route53 record is created from the EIP in the same apply, so the usual first-boot
sequence is: instance boots → Caddy retries ACME → certificate issues within a
minute or two of the record propagating.

Verify:

```bash
curl -s https://mutiny.vtxos.network/api/server-info -X POST \
  -H 'Content-Type: application/json' -d '{}'
# {"bitcoin_network":"mutinynet"}
```

Then in the app: **Choose a Server → Mutiny**.

## Redeploy just the binary

Rebuild and apply. A changed binary does **not** replace the instance — the
`terraform_data.redeploy` trigger pushes it via SSM and restarts the unit, so no
new ACME issuance and no downtime beyond the restart:

```bash
(cd ../../../cosigner-runtime && cargo build --release)
tofu apply
```

Changing `user_data` inputs (mount layout, Caddy version, unit files) *does*
replace the instance. The data volume detaches and reattaches; the certs and the
KV survive because they are on it.

## Reconfigure without a rebuild

Environment lives in SSM and is re-read on every restart:

```bash
aws ssm put-parameter --overwrite --region us-east-1 \
  --name /mutinynet/cosigner/env/AUTO_SETTLE_SAFETY_MARGIN_SECS \
  --type String --value 3600

aws ssm send-command --region us-east-1 \
  --instance-ids "$(tofu output -raw instance_id)" \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["/usr/local/sbin/cosigner-deploy.sh"]'
```

Prefer adding the key to `env_overrides` in tfvars so the change is in version
control rather than only in SSM.

## Operations

```bash
# Shell (no SSH, no key pair)
aws ssm start-session --target "$(tofu output -raw instance_id)"

# Logs
sudo journalctl -u cosigner-runtime -f
sudo journalctl -u caddy -f
sudo cat /var/log/user-data.log      # bootstrap

# State
sudo sqlite3 /mnt/data/cosigner/state.db "SELECT tree, count(*) FROM kv GROUP BY tree;"
```

## Teardown

`tofu destroy` will **fail** on the data volume — `prevent_destroy` is set,
because destroying it makes every wallet on this deployment permanently
unspendable (2-of-2 needs both halves, and the server's half is only there).

To tear down deliberately:

```bash
# 1. Back up first if the shares still matter.
aws ec2 create-snapshot --region us-east-1 \
  --volume-id "$(tofu output -raw data_volume_id)" \
  --description "mutinynet cosigner state before teardown"

# 2. Remove the lifecycle block from modules/host/main.tf, then:
tofu destroy
```

## Follow-ups not covered here

- **No remote state backend.** State is local; `.gitignore` keeps it out of git.
  Add an S3 + DynamoDB backend before more than one person applies this.
- **Single instance, single AZ.** No redundancy. An instance failure is downtime
  until it is replaced; the data volume is AZ-pinned.
- **No backups of the data volume.** Nothing schedules snapshots. For signet that
  is a deliberate omission; revisit before this pattern goes anywhere real.
- **`../mutiny/enclave.yaml` is still stale** — it carries dead env vars
  (`PERSISTENCE_BACKEND`, `ELECTRUM_URL`, `ELECTRUM_PORT`, `COSIGNER_WASM_PATH`),
  is missing `ESPLORA_URL` and `WEBAUTH_TOKEN_SECRET`, and has no `SQLITE_PATH`.
  It needs fixing before the enclave stack is deployable, independently of this.

# Enclave env-value overrides (FCM and friends)

How to inject deploy-time values into the enclave's environment via SSM,
without baking them into the public EIF or committing them to git.

The plumbing lives in [tofu/modules/enclave/main.tf](tofu/modules/enclave/main.tf)
(`env_values` map → per-key `aws_ssm_parameter.env_override`). The enclave
runtime overlays SSM values on top of `enclave.yaml`'s `app.env` defaults at
boot, for every key listed in `ENCLAVE_APP_ENV_KEYS` (which the EIF baker
populates from `app.env`).

## One-time setup

Keep the source key file **outside** the repo. Default convention:

```
~/secrets/vtxos-fcm.json
```

The corresponding key in [enclave.yaml](enclave.yaml) `app.env:` must already
exist as an empty placeholder (so it's in `ENCLAVE_APP_ENV_KEYS`):

```yaml
app:
  env:
    FCM_SERVICE_ACCOUNT_JSON: ""
```

[tofu/env_values.auto.tfvars.json](tofu/.gitignore) is gitignored — it never
gets committed.

## Generate the tfvars

From the repo root:

```bash
jq -n --arg fcm "$(cat ~/secrets/vtxos-fcm.json)" \
  '{env_values: {FCM_SERVICE_ACCOUNT_JSON: $fcm}}' \
  > infrastructure/mutiny/tofu/env_values.auto.tfvars.json
```

The `*.auto.tfvars.json` suffix makes OpenTofu auto-load it; no `-var-file`
flag needed. The `jq -n --arg` form handles the double-escaping of inner
quotes and PEM newlines correctly.

To add a second value, extend the inner object:

```bash
jq -n \
  --arg fcm "$(cat ~/secrets/vtxos-fcm.json)" \
  --arg foo "$(cat ~/secrets/other.txt)" \
  '{env_values: {FCM_SERVICE_ACCOUNT_JSON: $fcm, OTHER_KEY: $foo}}' \
  > infrastructure/mutiny/tofu/env_values.auto.tfvars.json
```

Every key here must also be declared as an empty placeholder in
`enclave.yaml`'s `app.env`, otherwise the SSM param gets written but the
runtime ignores it.

## Deploy

```bash
cd infrastructure/mutiny/tofu
tofu apply
```

Writes `/<deployment>/<app_name>/env/<KEY>` per entry, e.g.
`/dev/bitspend-server/env/FCM_SERVICE_ACCOUNT_JSON`.

## Make the enclave pick it up

Restart the enclave (SSM overrides are read at boot). EIF rebuild is **not**
required for value changes — only for adding new keys (because the new key
needs to join `ENCLAVE_APP_ENV_KEYS`, which is baked into the EIF).

## Verify

On a host with AWS creds for the same account:

```bash
aws ssm get-parameter \
  --name /dev/bitspend-server/env/FCM_SERVICE_ACCOUNT_JSON \
  --region us-east-1 \
  --query 'Parameter.Value' --output text | head -c 80
```

Should print the opening of the JSON, confirming the value is there.

## Rotation

```bash
# Refresh the source file from GCP, then:
jq -n --arg fcm "$(cat ~/secrets/vtxos-fcm.json)" \
  '{env_values: {FCM_SERVICE_ACCOUNT_JSON: $fcm}}' \
  > infrastructure/mutiny/tofu/env_values.auto.tfvars.json
cd infrastructure/mutiny/tofu && tofu apply
# Then restart the enclave.
```

## Notes

- The SSM parameter is `type = "String"`, not `SecureString`. Anyone in AWS
  account `639920118099` with `ssm:GetParameter` on that path can read the
  plaintext. That's a big upgrade from "in public git" or "in public EIF",
  but a step below the PCR0-locked KMS-ciphertext path (`enclave.yaml`'s
  `secrets:` mechanism). For a Firebase-Messaging-only service account it's
  acceptable; revisit before any value with custody blast radius lands here.
- `terraform.tfvars.json` and `env_values.auto.tfvars.json` are both
  gitignored. Both contain account-specific values; neither should ever be
  committed.

# Enclave env-value overrides (FCM and friends)

How to inject deploy-time values into the enclave's environment via SSM,
without baking them into the public EIF or committing them to git.

The plumbing lives in [tofu/modules/enclave/main.tf](tofu/modules/enclave/main.tf)
(`env_values` map → per-key `aws_ssm_parameter.env_override`). At boot the
runtime scans every key under `/<deployment>/<app>/env/` and overlays it onto
the process env on top of `enclave.yaml`'s `app.env` defaults — no
pre-declaration required.

## One-time setup

Keep the source key file **outside** the repo. Default convention:

```
~/secrets/vtxos-fcm.json
```

[tofu/env_values.auto.tfvars.json](tofu/.gitignore) is gitignored — it never
gets committed.

## Set the value (preferred: enclave CLI)

```bash
enclave tofu env \
  --key FCM_SERVICE_ACCOUNT_JSON \
  --value "$(cat ~/secrets/vtxos-fcm.json)"
```

The CLI merges into `tofu/env_values.auto.tfvars.json`, preserves any
existing entries, and handles JSON-escaping (inner `"`, PEM newlines)
internally. Add more keys in the same invocation by repeating the pair:

```bash
enclave tofu env \
  --key FCM_SERVICE_ACCOUNT_JSON --value "$(cat ~/secrets/vtxos-fcm.json)" \
  --key OTHER_KEY                --value "$(cat ~/secrets/other.txt)"
```

## Set the value (fallback: jq when the CLI isn't around)

```bash
jq -n --arg fcm "$(cat ~/secrets/vtxos-fcm.json)" \
  '{env_values: {FCM_SERVICE_ACCOUNT_JSON: $fcm}}' \
  > infrastructure/mutiny/tofu/env_values.auto.tfvars.json
```

The `*.auto.tfvars.json` suffix makes OpenTofu auto-load it; no `-var-file`
flag needed. **Overwrites** the whole file, so use the CLI form above when
you have other keys to preserve.

## Deploy

```bash
cd infrastructure/mutiny/tofu
tofu apply
```

Writes `/<deployment>/<app_name>/env/<KEY>` per entry, e.g.
`/dev/bitspend-server/env/FCM_SERVICE_ACCOUNT_JSON`.

## Make the enclave pick it up

Restart the enclave — SSM overrides are read at boot. **EIF rebuild is never
required for env_values changes**, neither for new keys nor value updates.

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
enclave tofu env --key FCM_SERVICE_ACCOUNT_JSON \
                 --value "$(cat ~/secrets/vtxos-fcm.json)"
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

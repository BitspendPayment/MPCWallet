terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

locals {
  prefix = "${var.deployment}-${var.app_name}"

  # Availability zones for VPC subnets.
  az_a = "${var.region}a"
  az_b = "${var.region}b"
}

# =============================================================================
# Variables
# =============================================================================

variable "region" {
  description = "AWS region for all resources."
  type        = string
}

variable "account" {
  description = "AWS account ID (12 digits)."
  type        = string
}

variable "deployment" {
  description = "Deployment prefix (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "app_name" {
  description = "Application name from enclave.yaml."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the Nitro Enclave host."
  type        = string
  default     = "m6i.xlarge"
}

variable "local" {
  description = "When true, skip VPC/EC2 resources (localstack mode)."
  type        = bool
  default     = false
}

variable "secrets" {
  description = "List of secrets managed by KMS inside the enclave."
  type = list(object({
    name    = string
    env_var = string
  }))
  default = []
}

variable "migration_cooldown" {
  description = "Migration cooldown duration string."
  type        = string
  default     = "0s"
}

variable "expected_pcr0" {
  description = "Expected PCR0 of the current EIF (from pcr.json). Used to trigger migrations."
  type        = string
  default     = ""
}

variable "supervisor_url" {
  description = "Supervisor server URL for local mode migrations (e.g. http://localhost:8444)."
  type        = string
  default     = "http://localhost:8444"
}

# --- GitHub Release artifacts ---
# Build artifacts (EIF, supervisor) are fetched from a GitHub Release
# at apply time using null_resource + curl — unless local path overrides are set.

variable "github_owner" {
  description = "GitHub repository owner."
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
  default     = ""
}

variable "release_tag" {
  description = "GitHub Release tag to fetch artifacts from."
  type        = string
  default     = "eif-latest"
}

variable "github_token" {
  description = "GitHub token for private repo access (optional for public repos)."
  type        = string
  default     = ""
  sensitive   = true
}

# --- Local artifact overrides ---
# When set, these skip the GitHub Release download and use local files directly.

variable "eif_path" {
  description = "Local path to image.eif. Overrides GitHub Release download."
  type        = string
  default     = ""
}

variable "supervisor_binary_path" {
  description = "Local path to supervisor binary. Overrides GitHub Release download."
  type        = string
  default     = ""
}

variable "env_values" {
  description = "Deploy-time overrides for keys declared in app.env (enclave.yaml). Each key/value here is written to SSM at /<deployment>/<app>/env/<key>; the runtime overlays them on top of the EIF's baked defaults at boot. Keys not present in app.env are still written but never read."
  type        = map(string)
  default     = {}
}

variable "tls" {
  description = "TLS settings for the enclave's public HTTPS listener, published to SSM as /<deployment>/<app>/env/ENCLAVE_NITRIDING_* and read by the runtime at boot to select the cert source (self-signed or ACME). route53_zone_id, when set, opts into automatic A-record management in that zone for fqdn."
  type = object({
    fqdn            = string
    provider        = string
    email           = string
    route53_zone_id = string
  })
  default = {
    fqdn            = ""
    provider        = "self-signed"
    email           = ""
    route53_zone_id = ""
  }
}


# =============================================================================
# KMS
# =============================================================================

# KMSKeyID placeholder. The enclave creates the KMS key with a PCR0-locked
# policy at first boot (runtime EnsureKeyID) and writes the real ID here.
# ignore_changes keeps tofu apply from fighting that runtime write. On destroy
# the EC2 destroy provisioner shells out to the supervisor to schedule key
# deletion before the role is torn down.
resource "aws_ssm_parameter" "kms_key_id" {
  name      = "/${var.deployment}/${var.app_name}/KMSKeyID"
  type      = "String"
  value     = "UNSET"
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }
}

# PCR0 signing key. Deleting it makes every past signature un-verifiable —
# the 30-day deletion window is the only safety net.
resource "aws_kms_key" "pcr0_signing" {
  description              = "${local.prefix} PCR0 signing key (ECC_NIST_P384)"
  customer_master_key_spec = "ECC_NIST_P384"
  key_usage                = "SIGN_VERIFY"
  enable_key_rotation      = false
  deletion_window_in_days  = 30

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_kms_alias" "pcr0_signing" {
  name          = "alias/${local.prefix}-pcr0-signing"
  target_key_id = aws_kms_key.pcr0_signing.key_id
}

resource "terraform_data" "sign_pcr0" {
  triggers_replace = [local.effective_pcr0, aws_kms_key.pcr0_signing.key_id]

  provisioner "local-exec" {
    # bash for pipefail; default /bin/sh is dash on slim images.
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      mkdir -p ${local.signing_dir}
      # hex → bytes without xxd (not in slim images)
      printf '%b' "$(printf '%s' "${local.effective_pcr0}" | sed 's/../\\x&/g')" \
        > ${local.signing_dir}/pcr0.bin
      aws kms get-public-key \
        --key-id ${aws_kms_key.pcr0_signing.arn} \
        --query PublicKey --output text \
        | base64 -d > ${local.signing_dir}/pubkey.der
      openssl ec -pubin -inform DER -outform PEM \
        < ${local.signing_dir}/pubkey.der \
        > ${local.signing_dir}/pubkey.pem
      aws kms sign \
        --key-id ${aws_kms_key.pcr0_signing.arn} \
        --message fileb://${local.signing_dir}/pcr0.bin \
        --message-type DIGEST \
        --signing-algorithm ECDSA_SHA_384 \
        --query Signature --output text \
        > ${local.signing_dir}/signature.b64
    EOT
  }
}

data "local_file" "pcr0_pubkey_pem" {
  filename   = "${local.signing_dir}/pubkey.pem"
  depends_on = [terraform_data.sign_pcr0]
}

data "local_file" "pcr0_signature_b64" {
  filename   = "${local.signing_dir}/signature.b64"
  depends_on = [terraform_data.sign_pcr0]
}

resource "aws_ssm_parameter" "pcr0_pubkey" {
  name      = "/${var.deployment}/${var.app_name}/Signing/PubkeyPEM"
  type      = "String"
  value     = data.local_file.pcr0_pubkey_pem.content
  overwrite = true
}

resource "aws_ssm_parameter" "pcr0_value" {
  name      = "/${var.deployment}/${var.app_name}/Signing/PCR0"
  type      = "String"
  value     = local.effective_pcr0
  overwrite = true
}

resource "aws_ssm_parameter" "pcr0_signature" {
  name      = "/${var.deployment}/${var.app_name}/Signing/Signature"
  type      = "String"
  value     = trimspace(data.local_file.pcr0_signature_b64.content)
  overwrite = true
}

# =============================================================================
# IAM
# =============================================================================

# IAM role for the EC2 Nitro Enclave host instance.

resource "aws_iam_role" "instance" {
  name_prefix = "${local.prefix}-enclave-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "instance" {
  name_prefix = "${local.prefix}-enclave-"
  role        = aws_iam_role.instance.name
}

# SSM managed instance core (remote only — enables SSM Session Manager).
resource "aws_iam_role_policy_attachment" "ssm_core" {
  count      = var.local ? 0 : 1
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Inline policy granting access to all enclave resources.
resource "aws_iam_role_policy" "enclave" {
  name   = "enclave-access"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.enclave.json
}

data "aws_iam_policy_document" "enclave" {
  # S3: read all uploaded assets (including new EIFs uploaded during migration).
  statement {
    sid = "S3AssetRead"
    actions = [
      "s3:GetObject",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.assets.arn,
      "${aws_s3_bucket.assets.arn}/*",
    ]
  }

  # S3: read/write on persistent storage bucket.
  statement {
    sid = "S3StorageReadWrite"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.storage.arn,
      "${aws_s3_bucket.storage.arn}/*",
    ]
  }

  # SSM: read/write on secret + DEK ciphertext parameters. Paths are key-scoped
  # (/.../{secret}/Ciphertext/{kmsKeyId}) and created by the runtime at boot /
  # migration, so the wildcard covers every KMS key generation.
  statement {
    sid = "SSMSecretParams"
    actions = [
      "ssm:GetParameter",
      "ssm:PutParameter",
    ]
    resources = concat(
      [for s in var.secrets : "arn:aws:ssm:${var.region}:${var.account}:parameter/${var.deployment}/${var.app_name}/${s.name}/Ciphertext/*"],
      [
        "arn:aws:ssm:${var.region}:${var.account}:parameter/${var.deployment}/${var.app_name}/StorageDEK/Ciphertext/*",
        aws_ssm_parameter.migration_previous_pcr0.arn,
        aws_ssm_parameter.migration_previous_pcr0_attestation.arn,
        aws_ssm_parameter.migration_requested_at.arn,
      ],
    )
  }

  # SSM: read-only known one-off parameters.
  statement {
    sid     = "SSMReadKnownParams"
    actions = ["ssm:GetParameter"]
    resources = [
      aws_ssm_parameter.storage_bucket_name.arn,
      aws_ssm_parameter.pcr0_pubkey.arn,
      aws_ssm_parameter.pcr0_value.arn,
      aws_ssm_parameter.pcr0_signature.arn,
    ]
  }

  # SSM: prefix-scoped env overrides. The runtime calls GetParametersByPath
  # to fetch the whole map at boot — no need to enumerate keys in the EIF.
  statement {
    sid     = "SSMReadEnvOverridesPrefix"
    actions = ["ssm:GetParameter", "ssm:GetParametersByPath"]
    resources = [
      "arn:aws:ssm:${var.region}:${var.account}:parameter/${var.deployment}/${var.app_name}/env/*",
    ]
  }

  # SSM: KMSKeyID needs read+write (supervisor updates it during migration).
  statement {
    sid     = "SSMKMSKeyID"
    actions = ["ssm:GetParameter", "ssm:PutParameter"]
    resources = [
      "arn:aws:ssm:${var.region}:${var.account}:parameter/${var.deployment}/${var.app_name}/KMSKeyID",
    ]
  }

  # KMS access. PutKeyPolicy is not granted — keys are policy-locked at CreateKey time.
  statement {
    sid = "KMSAccess"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:CreateKey",
      "kms:TagResource",
    ]
    resources = ["*"]
  }

  # STS: get caller identity for role ARN / account ID.
  statement {
    sid       = "STSAccess"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  # CloudWatch Logs: create log groups/streams and write trace entries.
  statement {
    sid = "CloudWatchLogsAccess"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutRetentionPolicy",
      "logs:FilterLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = [
      "arn:aws:logs:${var.region}:${var.account}:log-group:/enclave/*",
    ]
  }
}

# =============================================================================
# S3
# =============================================================================

locals {
  # When local paths are set, use them directly. Otherwise download from GitHub Release.
  use_local      = var.eif_path != ""
  artifacts_dir  = "${path.module}/.artifacts"
  signing_dir    = "${path.module}/.signing"
  release_base   = "https://github.com/${var.github_owner}/${var.github_repo}/releases/download/${var.release_tag}"

  eif_source        = local.use_local ? var.eif_path : "${local.artifacts_dir}/image.eif"
  supervisor_source = local.use_local ? var.supervisor_binary_path : "${local.artifacts_dir}/supervisor"
  pcr_source        = "${dirname(local.eif_source)}/pcr.json"
}

# Download build artifacts from GitHub Release (skipped when local paths are set).
# Re-runs on every apply because release_tag is typically a moving pointer
# (e.g. "eif-latest"). The downstream S3 etag (filemd5 over the downloaded
# file) is what actually decides whether anything propagates.
resource "null_resource" "download_artifacts" {
  count = local.use_local ? 0 : 1

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      AUTH=""
      [ -n "$GITHUB_TOKEN" ] && AUTH="-H \"Authorization: Bearer $GITHUB_TOKEN\""
      mkdir -p ${local.artifacts_dir}
      eval curl -sfL $AUTH -o ${local.artifacts_dir}/image.eif  ${local.release_base}/image.eif
      eval curl -sfL $AUTH -o ${local.artifacts_dir}/supervisor ${local.release_base}/supervisor
      eval curl -sfL $AUTH -o ${local.artifacts_dir}/pcr.json   ${local.release_base}/pcr.json
    EOT
    environment = {
      GITHUB_TOKEN = var.github_token
    }
  }
}

# pcr.json is produced by the EIF builder (monzo/aws-nitro-util) alongside
# image.eif and contains the precomputed PCR0/PCR1/PCR2. Reading it here lets
# tofu auto-derive expected_pcr0 instead of asking operators to maintain it.
data "local_file" "pcr" {
  filename   = local.pcr_source
  depends_on = [null_resource.download_artifacts]
}

# Also read the EIF and supervisor through data.local_file so their
# content_md5 (used as the S3 etag) is computed at apply time AFTER any
# download — otherwise a moving release_tag causes one-apply-late drift
# (planned filemd5 from yesterday's file, then download replaces it).
data "local_file" "eif" {
  filename   = local.eif_source
  depends_on = [null_resource.download_artifacts]
}

data "local_file" "supervisor" {
  filename   = local.supervisor_source
  depends_on = [null_resource.download_artifacts]
}

locals {
  # Auto-derived from the build's pcr.json. Falls back to var.expected_pcr0 if
  # pcr.json is missing or malformed (e.g. partial local artifact set).
  effective_pcr0 = try(jsondecode(data.local_file.pcr.content).PCR0, var.expected_pcr0)
}

# S3 bucket for enclave deployment assets (EIF, scripts, systemd units, binaries).
# This bucket is ephemeral — force_destroy is always true since assets can be re-uploaded.

resource "aws_s3_bucket" "assets" {
  bucket_prefix = "${local.prefix}-assets-"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "enclave_eif" {
  depends_on = [null_resource.download_artifacts]
  bucket     = aws_s3_bucket.assets.id
  key        = "image.eif"
  source     = local.eif_source
  etag       = data.local_file.eif.content_md5
}

resource "aws_s3_object" "supervisor_binary" {
  depends_on = [null_resource.download_artifacts]
  bucket     = aws_s3_bucket.assets.id
  key        = "supervisor"
  source     = local.supervisor_source
  etag       = data.local_file.supervisor.content_md5
}

# Staging copy used for in-place supervisor migration. Each tofu apply overwrites
# this object with the freshly-built binary; the migration null_resource
# points the running supervisor at this key. On migration success the
# promote_supervisor_binary null_resource copies it onto the canonical key above,
# so instance reboots come up on the new version. If migration fails the
# canonical key stays on the last-known-good binary.
#
# Recovery: if a newly deployed supervisor binary crash-loops under systemd,
# SSM into the host and run
#   aws s3 cp s3://<assets>/supervisor /home/ec2-user/app/supervisor
#   systemctl restart supervisor
# to roll back to the canonical (last-known-good) binary.
resource "aws_s3_object" "supervisor_binary_staging" {
  depends_on = [null_resource.download_artifacts]
  bucket     = aws_s3_bucket.assets.id
  key        = "supervisor-staging"
  source     = local.supervisor_source
  etag       = data.local_file.supervisor.content_md5
}

# The enclave-supervisor.service systemd unit is inlined in user_data.sh.tftpl
# via a heredoc — no separate S3 object. Keeps deployment concerns colocated
# with the tofu module that owns them.

# Persistent storage bucket for enclave data (Store/Load API).

resource "aws_s3_bucket" "storage" {
  bucket_prefix = "${local.prefix}-storage-"
  force_destroy = var.local
}

resource "aws_s3_bucket_public_access_block" "storage" {
  bucket = aws_s3_bucket.storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "storage_ssl" {
  count  = var.local ? 0 : 1
  bucket = aws_s3_bucket.storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnforceSSL"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.storage.arn,
        "${aws_s3_bucket.storage.arn}/*",
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })
}

# =============================================================================
# SSM
# =============================================================================

# SSM parameters for migration state. Per-secret + DEK ciphertexts are key-scoped
# (/.../{secret}/Ciphertext/{kmsKeyId}) and created by the runtime, not here.

resource "aws_ssm_parameter" "migration_previous_pcr0" {
  name      = "/${var.deployment}/${var.app_name}/MigrationPreviousPCR0"
  type      = "String"
  value     = "UNSET"
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "migration_previous_pcr0_attestation" {
  name      = "/${var.deployment}/${var.app_name}/MigrationPreviousPCR0Attestation"
  type      = "String"
  tier      = "Advanced"
  value     = "UNSET"
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "migration_requested_at" {
  name      = "/${var.deployment}/${var.app_name}/MigrationRequestedAt"
  type      = "String"
  value     = "UNSET"
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }
}

# Deletes the runtime-created key-scoped ciphertext params on tofu destroy
# (tofu doesn't track them). A var.secrets change replaces only this no-op
# resource.
resource "null_resource" "ciphertext_cleanup" {
  triggers = {
    region       = var.region
    deployment   = var.deployment
    app_name     = var.app_name
    secret_names = jsonencode([for s in var.secrets : s.name])
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      REGION="${self.triggers.region}"; DEP="${self.triggers.deployment}"; APP="${self.triggers.app_name}"
      for S in $(echo '${self.triggers.secret_names}' | jq -r '.[]' 2>/dev/null); do
        aws ssm delete-parameters-by-path --path "/$DEP/$APP/$S/Ciphertext" --recursive --region "$REGION" 2>/dev/null || true
      done
      aws ssm delete-parameters-by-path --path "/$DEP/$APP/StorageDEK/Ciphertext" --recursive --region "$REGION" 2>/dev/null || true
    EOT
  }
}

# Storage bucket name.
resource "aws_ssm_parameter" "storage_bucket_name" {
  name      = "/${var.deployment}/${var.app_name}/StorageBucketName"
  type      = "String"
  value     = aws_s3_bucket.storage.id
  overwrite = true
}

# Deploy-time env overrides, published to SSM at /<deployment>/<app>/env/<key>.
# Merges two sources:
#   - var.env_values: overrides for keys declared in app.env (enclave.yaml);
#     the runtime overlays them on the EIF's baked defaults at boot.
#   - local.tls_params: the ENCLAVE_NITRIDING_* TLS settings from var.tls,
#     read by the runtime at boot to select the cert source.
locals {
  # SSM rejects empty values, so each key is published only when it has one.
  tls_params = merge(
    var.tls.fqdn != "" ? { ENCLAVE_NITRIDING_FQDN = var.tls.fqdn } : {},
    var.tls.provider != "self-signed" ? {
      ENCLAVE_NITRIDING_USE_ACME       = "true"
      ENCLAVE_NITRIDING_ACME_DIRECTORY = var.tls.provider
    } : {},
    var.tls.provider != "self-signed" && var.tls.email != "" ? { ENCLAVE_NITRIDING_ACME_EMAIL = var.tls.email } : {}
  )
}

resource "aws_ssm_parameter" "env_override" {
  for_each = merge(var.env_values, local.tls_params)

  name      = "/${var.deployment}/${var.app_name}/env/${each.key}"
  type      = "String"
  value     = each.value
  overwrite = true
}

# =============================================================================
# VPC
# =============================================================================

# VPC + networking (remote only — skipped for localstack).

resource "aws_vpc" "main" {
  count = var.local ? 0 : 1

  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.prefix}-vpc" }
}

# Public subnet (for EC2 instance with EIP).
resource "aws_subnet" "public" {
  count = var.local ? 0 : 1

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.1.0/24"
  availability_zone = local.az_a

  tags = { Name = "${local.prefix}-public" }
}

# Private subnet (for VPC endpoints and NAT egress).
resource "aws_subnet" "private" {
  count = var.local ? 0 : 1

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.2.0/24"
  availability_zone = local.az_a

  tags = { Name = "${local.prefix}-private" }
}

# Second private subnet in AZ-b (some services require multi-AZ).
resource "aws_subnet" "private_b" {
  count = var.local ? 0 : 1

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.3.0/24"
  availability_zone = local.az_b

  tags = { Name = "${local.prefix}-private-b" }
}

# Internet gateway for public subnet.
resource "aws_internet_gateway" "main" {
  count  = var.local ? 0 : 1
  vpc_id = aws_vpc.main[0].id

  tags = { Name = "${local.prefix}-igw" }
}

# NAT gateway for private subnet egress.
resource "aws_eip" "nat" {
  count  = var.local ? 0 : 1
  domain = "vpc"

  tags = { Name = "${local.prefix}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  count = var.local ? 0 : 1

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = { Name = "${local.prefix}-nat" }

  depends_on = [aws_internet_gateway.main]
}

# Route tables.
resource "aws_route_table" "public" {
  count  = var.local ? 0 : 1
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = { Name = "${local.prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = var.local ? 0 : 1
  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table" "private" {
  count  = var.local ? 0 : 1
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }

  tags = { Name = "${local.prefix}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = var.local ? 0 : 1
  subnet_id      = aws_subnet.private[0].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_route_table_association" "private_b" {
  count          = var.local ? 0 : 1
  subnet_id      = aws_subnet.private_b[0].id
  route_table_id = aws_route_table.private[0].id
}

# VPC endpoints — keep traffic to AWS services inside the VPC.
#
# Single-AZ on purpose: the Nitro parent instance is placed in public[0] /
# private[0] (AZ-a only), so adding an endpoint ENI in AZ-b would be paid-for
# capacity no traffic can reach. private_b exists only so resources that
# require a multi-AZ subnet group (future RDS, ALB, etc.) can be added without
# an apply-time VPC redesign. If the parent instance ever becomes multi-AZ,
# add aws_subnet.private_b[0].id back to subnet_ids below.
resource "aws_vpc_endpoint" "kms" {
  count = var.local ? 0 : 1

  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private[0].id]
  security_group_ids  = [aws_security_group.nitro[0].id]
  private_dns_enabled = true

  tags = { Name = "${local.prefix}-kms-endpoint" }
}

resource "aws_vpc_endpoint" "ssm" {
  count = var.local ? 0 : 1

  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private[0].id]
  security_group_ids  = [aws_security_group.nitro[0].id]
  private_dns_enabled = true

  tags = { Name = "${local.prefix}-ssm-endpoint" }
}

resource "aws_vpc_endpoint" "s3" {
  count = var.local ? 0 : 1

  vpc_id            = aws_vpc.main[0].id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public[0].id, aws_route_table.private[0].id]

  tags = { Name = "${local.prefix}-s3-endpoint" }
}

# =============================================================================
# EC2
# =============================================================================

# EC2 Nitro Enclave instance (remote only — skipped for localstack).

data "aws_ami" "al2023" {
  count       = var.local ? 0 : 1
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security group for the Nitro Enclave instance.
resource "aws_security_group" "nitro" {
  count = var.local ? 0 : 1

  name_prefix = "${local.prefix}-nitro-"
  description = "Private SG for Nitro Enclave EC2 instance"
  vpc_id      = aws_vpc.main[0].id

  tags = { Name = "${local.prefix}-nitro-sg" }
}

# Allow HTTPS from internet.
resource "aws_security_group_rule" "https_ingress" {
  count = var.local ? 0 : 1

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nitro[0].id
}

# Self-referencing TCP 443.
resource "aws_security_group_rule" "self_tcp" {
  count = var.local ? 0 : 1

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nitro[0].id
  security_group_id        = aws_security_group.nitro[0].id
}

# Self-referencing ICMP.
resource "aws_security_group_rule" "self_icmp" {
  count = var.local ? 0 : 1

  type                     = "ingress"
  from_port                = -1
  to_port                  = -1
  protocol                 = "icmp"
  source_security_group_id = aws_security_group.nitro[0].id
  security_group_id        = aws_security_group.nitro[0].id
}

# All outbound.
resource "aws_security_group_rule" "all_egress" {
  count = var.local ? 0 : 1

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nitro[0].id
}

# Nitro Enclave EC2 instance.
resource "aws_instance" "nitro" {
  count = var.local ? 0 : 1

  # Wait for IAM policy before booting — user_data downloads from S3 immediately.
  depends_on = [aws_iam_role_policy.enclave]

  ami                  = data.aws_ami.al2023[0].id
  instance_type        = var.instance_type
  subnet_id            = aws_subnet.public[0].id
  iam_instance_profile = aws_iam_instance_profile.instance.name
  vpc_security_group_ids = [aws_security_group.nitro[0].id]

  enclave_options {
    enabled = true
  }

  root_block_device {
    volume_size           = 32
    volume_type           = "gp2"
    encrypted             = true
    delete_on_termination = var.deployment == "dev"
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    region                   = var.region
    dev_mode                 = var.deployment
    app_name                 = var.app_name
    eif_s3_url               = "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.enclave_eif.key}"
    supervisor_binary_s3_url = "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.supervisor_binary.key}"
    migration_cooldown       = var.migration_cooldown
  })

  tags = {
    Name   = "${local.prefix}-nitro-enclave"
    Region = var.region
  }

  # Wait for instance to pass status checks before proceeding.
  provisioner "local-exec" {
    command = "aws ec2 wait instance-status-ok --instance-ids ${self.id} --region ${var.region}"
  }

  # On destroy: stop enclave + schedule KMS key deletion via supervisor.
  # Must run while the instance is still alive (before EC2 termination).
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws ssm send-command \
        --instance-ids ${self.id} \
        --document-name AWS-RunShellScript \
        --parameters '{"commands":["curl -sf -X POST http://localhost:8443/stop || true","curl -sf -X POST http://localhost:8443/schedule-key-deletion || true"]}' \
        --region ${self.tags["Region"]} \
        --output text || true
    EOT
    on_failure = continue
  }

  # AL2023 publishes new AMIs constantly; data.aws_ami.al2023.most_recent re-resolves
  # on every plan and would otherwise force-replace the host (and break migration
  # because the old supervisor is gone before /migrate can be called). Bump the host
  # OS deliberately with: tofu apply -replace=module.enclave.aws_instance.nitro[0]
  lifecycle {
    ignore_changes = [ami]
  }
}

# SSM parameters for instance metadata (used by upgrade detection + destroy).
resource "aws_ssm_parameter" "instance_id" {
  count     = var.local ? 0 : 1
  name      = "/${var.deployment}/${var.app_name}/InstanceID"
  type      = "String"
  value     = aws_instance.nitro[0].id
  overwrite = true
}

resource "aws_ssm_parameter" "elastic_ip" {
  count     = var.local ? 0 : 1
  name      = "/${var.deployment}/${var.app_name}/ElasticIP"
  type      = "String"
  value     = aws_eip.instance[0].public_ip
  overwrite = true
}

# Elastic IP for stable public address across reboots.
resource "aws_eip" "instance" {
  count  = var.local ? 0 : 1
  domain = "vpc"

  tags = { Name = "${local.prefix}-enclave-eip" }
}

resource "aws_eip_association" "instance" {
  count = var.local ? 0 : 1

  allocation_id = aws_eip.instance[0].id
  instance_id   = aws_instance.nitro[0].id
}

# Optional Route53 A record. Skipped in local mode or when route53_zone_id is
# unset; operator-managed DNS providers (Cloudflare, registrar, etc.) keep
# pointing at the elastic_ip output manually.
resource "aws_route53_record" "enclave" {
  count = var.local || var.tls.route53_zone_id == "" ? 0 : 1

  zone_id = var.tls.route53_zone_id
  name    = var.tls.fqdn
  type    = "A"
  ttl     = 60
  records = [aws_eip.instance[0].public_ip]
}

# Automatic migration — triggers when the EIF changes (new PCR0).
# On first apply this is a no-op (no running enclave to migrate).
# On subsequent applies with a new EIF, it calls the supervisor to
# perform a live migration (export keys, swap EIF, restart enclave).
# Automatic migration (production) — triggers when EIF changes.
# Uses SSM to call the supervisor on the EC2 instance.
resource "null_resource" "enclave_migration" {
  count = var.local ? 0 : 1

  triggers = {
    eif_etag      = data.local_file.eif.content_md5
    expected_pcr0 = local.effective_pcr0
  }

  provisioner "local-exec" {
    command = <<-EOT
      INSTANCE_ID="${aws_instance.nitro[0].id}"
      REGION="${var.region}"
      BUCKET="${aws_s3_bucket.assets.id}"
      EIF_KEY="${aws_s3_object.enclave_eif.key}"
      PCR0="${local.effective_pcr0}"
      SECRETS='${jsonencode([for s in var.secrets : s.name])}'

      # Skip on first deploy (no running enclave).
      STATUS=$(aws ssm send-command \
        --instance-ids "$INSTANCE_ID" \
        --document-name AWS-RunShellScript \
        --parameters '{"commands":["curl -sf http://localhost:8443/health || echo NOT_RUNNING"]}' \
        --region "$REGION" \
        --query 'Command.CommandId' --output text 2>/dev/null) || exit 0
      sleep 5
      RESULT=$(aws ssm get-command-invocation \
        --command-id "$STATUS" --instance-id "$INSTANCE_ID" --region "$REGION" \
        --query 'StandardOutputContent' --output text 2>/dev/null) || exit 0
      if echo "$RESULT" | grep -q "NOT_RUNNING"; then
        echo "No running enclave, skipping migration."
        exit 0
      fi

      echo "Triggering migration..."
      SUPERVISOR_BUCKET="${aws_s3_bucket.assets.id}"
      SUPERVISOR_KEY="${aws_s3_object.supervisor_binary_staging.key}"
      MIGRATE_BODY=$(jq -nc \
        --arg b "$BUCKET" --arg k "$EIF_KEY" --arg p "$PCR0" --argjson s "$SECRETS" \
        --arg mb "$SUPERVISOR_BUCKET" --arg mk "$SUPERVISOR_KEY" \
        '{eif_bucket:$b, eif_key:$k, pcr0:$p, secret_names:$s, supervisor_binary_bucket:$mb, supervisor_binary_key:$mk}')
      MIGRATE_CMD="curl -sf -X POST http://localhost:8443/migrate -H Content-Type:application/json -d '$MIGRATE_BODY'"
      TMPFILE=$(mktemp)
      jq -nc --arg cmd "$MIGRATE_CMD" '{"commands":[$cmd]}' > "$TMPFILE"
      aws ssm send-command \
        --instance-ids "$INSTANCE_ID" \
        --document-name AWS-RunShellScript \
        --parameters "file://$TMPFILE" \
        --region "$REGION" --output text
      rm -f "$TMPFILE"
    EOT
  }

  depends_on = [aws_instance.nitro, aws_s3_object.enclave_eif]
}

# Promote the staging supervisor binary onto the canonical key after a successful
# enclave migration. Runs only when enclave_migration fires and succeeds, so
# the canonical key (used by cloud-init on future instance launches) stays
# pinned to the last-known-good binary until the live migration proves the
# new one boots.
resource "null_resource" "promote_supervisor_binary" {
  count = var.local ? 0 : 1

  triggers = {
    eif_etag      = data.local_file.eif.content_md5
    expected_pcr0 = local.effective_pcr0
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws s3 cp \
        "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.supervisor_binary_staging.key}" \
        "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.supervisor_binary.key}" \
        --region "${var.region}"
    EOT
  }

  depends_on = [null_resource.enclave_migration]
}

# Automatic migration (local mode) — triggers when EIF content changes.
# Calls the supervisor directly via HTTP (no EC2/SSM in local mode).
# Skips at runtime if expected_pcr0 is unset or no supervisor is running.
resource "null_resource" "enclave_migration_local" {
  count = var.local ? 1 : 0

  triggers = {
    eif_etag      = data.local_file.eif.content_md5
    expected_pcr0 = local.effective_pcr0
  }

  provisioner "local-exec" {
    command = <<-EOT
      SUPERVISOR_URL="${var.supervisor_url}"
      BUCKET="${aws_s3_bucket.assets.id}"
      PCR0="${local.effective_pcr0}"
      SECRETS='${jsonencode([for s in var.secrets : s.name])}'

      # Skip if PCR0 couldn't be derived — nothing meaningful to verify against.
      [ -z "$${PCR0}" ] && { echo "PCR0 not derivable (missing pcr.json + var.expected_pcr0), skipping migration."; exit 0; }

      # Skip on first deploy (supervisor not running yet).
      curl -sf "$${SUPERVISOR_URL}/health" >/dev/null 2>&1 || { echo "No supervisor, skipping migration."; exit 0; }

      echo "Triggering local migration..."
      SUPERVISOR_KEY="${aws_s3_object.supervisor_binary_staging.key}"
      curl -sf -X POST "$${SUPERVISOR_URL}/migrate" \
        -H 'Content-Type: application/json' \
        -d "{\"eif_bucket\":\"$${BUCKET}\",\"eif_key\":\"image.eif\",\"pcr0\":\"$${PCR0}\",\"secret_names\":$${SECRETS},\"supervisor_binary_bucket\":\"$${BUCKET}\",\"supervisor_binary_key\":\"$${SUPERVISOR_KEY}\"}"
    EOT
  }
}

# Promote the staging supervisor binary onto the canonical key after a successful
# local-mode migration. Mirrors null_resource.promote_supervisor_binary for non-local.
resource "null_resource" "promote_supervisor_binary_local" {
  count = var.local ? 1 : 0

  triggers = {
    eif_etag      = data.local_file.eif.content_md5
    expected_pcr0 = local.effective_pcr0
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws s3 cp \
        "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.supervisor_binary_staging.key}" \
        "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.supervisor_binary.key}" \
        --region "${var.region}"
    EOT
  }

  depends_on = [null_resource.enclave_migration_local]
}

# =============================================================================
# Outputs
# =============================================================================

output "ec2_role_arn" {
  description = "EC2 instance role ARN."
  value       = aws_iam_role.instance.arn
}

output "instance_id" {
  description = "EC2 instance ID (empty in local mode)."
  value       = var.local ? "" : aws_instance.nitro[0].id
}

output "elastic_ip" {
  description = "Static public IP for the enclave instance (empty in local mode)."
  value       = var.local ? "" : aws_eip.instance[0].public_ip
}

output "storage_bucket" {
  description = "S3 storage bucket name."
  value       = aws_s3_bucket.storage.id
}

output "pcr0_signing_key_arn" {
  description = "ARN of the KMS key used by Tofu to sign each build's PCR0."
  value       = aws_kms_key.pcr0_signing.arn
}

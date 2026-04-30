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

variable "previous_pcr0" {
  description = "Previous PCR0 hash for migration chain validation."
  type        = string
  default     = "genesis"
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


# =============================================================================
# KMS
# =============================================================================

# KMS encryption key for enclave secrets.
#
# Created via AWS CLI (null_resource) instead of a native tofu resource
# because the enclave locks the key policy to PCR0 at first boot, and the
# supervisor replaces the key entirely during migration. Tofu cannot
# refresh a locked key (DescribeKey/GetKeyPolicy/GetKeyRotationStatus all
# fail with AccessDenied), so the key must not exist as a tofu resource.
#
# The key ID is stored in SSM and read back via a data source. All other
# resources reference locals.kms_key_id / locals.kms_key_arn.
# Key deletion is handled by the supervisor's destroy provisioner.

resource "null_resource" "kms_key" {
  # Only runs once per deployment. The supervisor handles key rotation
  # during migration (creates new keys, updates SSM).
  triggers = {
    deployment = var.deployment
    app_name   = var.app_name
    region     = var.region
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      # Check if a key already exists in SSM (idempotent).
      EXISTING=$(aws ssm get-parameter \
        --name "/${var.deployment}/${var.app_name}/KMSKeyID" \
        --region ${var.region} --query 'Parameter.Value' --output text 2>/dev/null || echo "UNSET")
      if [ "$EXISTING" != "UNSET" ] && [ -n "$EXISTING" ]; then
        echo "KMS key already exists in SSM: $EXISTING"
        exit 0
      fi

      # Create the key.
      KEY_ID=$(aws kms create-key \
        --description "${local.prefix} enclave encryption key" \
        --region ${var.region} \
        --tags TagKey=AppName,TagValue=${var.app_name} TagKey=Deployment,TagValue=${var.deployment} TagKey=ManagedBy,TagValue=opentofu \
        --query 'KeyMetadata.KeyId' --output text)
      echo "Created KMS key: $KEY_ID"

      # Apply initial key policy.
      POLICY='${jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid       = "AllowRootAccount"
            Effect    = "Allow"
            Principal = { AWS = "arn:aws:iam::${var.account}:root" }
            Action    = "kms:*"
            Resource  = "*"
          },
          {
            Sid       = "AllowInstanceRole"
            Effect    = "Allow"
            Principal = { AWS = aws_iam_role.instance.arn }
            Action = [
              "kms:Encrypt",
              "kms:Decrypt",
              "kms:GenerateDataKey",
              "kms:DescribeKey",
              "kms:PutKeyPolicy",
              "kms:GetKeyPolicy",
            ]
            Resource = "*"
          },
        ]
      })}'

      aws kms put-key-policy --key-id "$KEY_ID" --policy-name default \
        --policy "$POLICY" --region ${var.region}

      # Store in SSM.
      aws ssm put-parameter \
        --name "/${var.deployment}/${var.app_name}/KMSKeyID" \
        --value "$KEY_ID" --type String --overwrite \
        --region ${var.region} --no-cli-pager

      echo "KMS key $KEY_ID stored in SSM"
    EOT
  }

  # On destroy: schedule the KMS key for deletion and remove the SSM pointer
  # so that a subsequent apply creates a fresh key.
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      REGION="${lookup(self.triggers, "region", "us-east-1")}"
      DEPLOYMENT="${self.triggers.deployment}"
      APP_NAME="${self.triggers.app_name}"

      KEY_ID=$(aws ssm get-parameter \
        --name "/$DEPLOYMENT/$APP_NAME/KMSKeyID" \
        --region "$REGION" --query 'Parameter.Value' --output text 2>/dev/null || echo "UNSET")

      if [ "$KEY_ID" != "UNSET" ] && [ -n "$KEY_ID" ]; then
        echo "Scheduling KMS key $KEY_ID for deletion (7-day window)..."
        aws kms schedule-key-deletion \
          --key-id "$KEY_ID" \
          --pending-window-in-days 7 \
          --region "$REGION" 2>/dev/null || echo "Key already pending deletion or not found"

        echo "Removing KMSKeyID SSM parameter..."
        aws ssm delete-parameter \
          --name "/$DEPLOYMENT/$APP_NAME/KMSKeyID" \
          --region "$REGION" 2>/dev/null || echo "SSM parameter already removed"
      else
        echo "No KMS key found in SSM — nothing to clean up"
      fi
    EOT
  }
}

# Read the KMS key ID from SSM (written by null_resource.kms_key or supervisor).
data "aws_ssm_parameter" "kms_key_id_lookup" {
  name       = "/${var.deployment}/${var.app_name}/KMSKeyID"
  depends_on = [null_resource.kms_key]
}

locals {
  kms_key_id  = data.aws_ssm_parameter.kms_key_id_lookup.value
  kms_key_arn = "arn:aws:kms:${var.region}:${var.account}:key/${local.kms_key_id}"
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

  # SSM: read/write on secret ciphertext parameters.
  statement {
    sid = "SSMSecretParams"
    actions = [
      "ssm:GetParameter",
      "ssm:PutParameter",
    ]
    resources = concat(
      [for p in aws_ssm_parameter.secret_ciphertext : p.arn],
      [for p in aws_ssm_parameter.secret_migration : p.arn],
      [
        aws_ssm_parameter.migration_kms_key_id.arn,
        aws_ssm_parameter.migration_previous_pcr0.arn,
        aws_ssm_parameter.migration_previous_pcr0_attestation.arn,
        aws_ssm_parameter.migration_old_kms_key_id.arn,
        aws_ssm_parameter.migration_target_pcr0.arn,
        aws_ssm_parameter.migration_requested_at.arn,
        aws_ssm_parameter.storage_dek.arn,
        aws_ssm_parameter.migration_storage_dek.arn,
      ],
    )
  }

  # SSM: read-only parameters.
  statement {
    sid     = "SSMReadOnly"
    actions = ["ssm:GetParameter"]
    resources = concat(
      [aws_ssm_parameter.storage_bucket_name.arn],
      [for p in aws_ssm_parameter.env_override : p.arn],
    )
  }

  # SSM: KMSKeyID needs read+write (supervisor updates it during migration).
  statement {
    sid     = "SSMKMSKeyID"
    actions = ["ssm:GetParameter", "ssm:PutParameter"]
    resources = [
      "arn:aws:ssm:${var.region}:${var.account}:parameter/${var.deployment}/${var.app_name}/KMSKeyID",
    ]
  }

  # KMS: encrypt/decrypt + policy management.
  statement {
    sid = "KMSAccess"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
      "kms:PutKeyPolicy",
      "kms:GetKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:CreateKey",
      "kms:TagResource",
    ]
    resources = ["*"]
  }

  # STS: get caller identity for building transitional KMS policies.
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
  release_base   = "https://github.com/${var.github_owner}/${var.github_repo}/releases/download/${var.release_tag}"

  eif_source        = local.use_local ? var.eif_path : "${local.artifacts_dir}/image.eif"
  supervisor_source = local.use_local ? var.supervisor_binary_path : "${local.artifacts_dir}/supervisor"
}

# Download build artifacts from GitHub Release (skipped when local paths are set).
resource "null_resource" "download_artifacts" {
  count = local.use_local ? 0 : 1

  triggers = {
    release_tag = var.release_tag
  }

  provisioner "local-exec" {
    command = <<-EOT
      AUTH=""
      [ -n "$GITHUB_TOKEN" ] && AUTH="-H \"Authorization: Bearer $GITHUB_TOKEN\""
      mkdir -p ${local.artifacts_dir}
      eval curl -sfL $AUTH -o ${local.artifacts_dir}/image.eif ${local.release_base}/image.eif
      eval curl -sfL $AUTH -o ${local.artifacts_dir}/supervisor ${local.release_base}/supervisor
    EOT
    environment = {
      GITHUB_TOKEN = var.github_token
    }
  }
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
  etag       = local.use_local ? filemd5(local.eif_source) : null
}

resource "aws_s3_object" "supervisor_binary" {
  depends_on = [null_resource.download_artifacts]
  bucket     = aws_s3_bucket.assets.id
  key        = "supervisor"
  source     = local.supervisor_source
  etag       = local.use_local ? filemd5(local.supervisor_source) : null
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
  etag       = local.use_local ? filemd5(local.supervisor_source) : null
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

# SSM parameters for enclave secrets and migration state.

locals {
  secrets_map = { for s in var.secrets : s.name => s }
}

# Per-secret ciphertext parameters.
resource "aws_ssm_parameter" "secret_ciphertext" {
  for_each = local.secrets_map

  name      = "/${var.deployment}/${var.app_name}/${each.key}/Ciphertext"
  type      = "String"
  value     = "UNSET"
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }
}

# Per-secret migration ciphertext parameters.
resource "aws_ssm_parameter" "secret_migration" {
  for_each = local.secrets_map

  name      = "/${var.deployment}/${var.app_name}/Migration/${each.key}/Ciphertext"
  type      = "String"
  value     = "UNSET"
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }
}

# Shared migration parameters (one per deployment, not per secret).

resource "aws_ssm_parameter" "migration_kms_key_id" {
  name      = "/${var.deployment}/${var.app_name}/MigrationKMSKeyID"
  type      = "String"
  value     = "UNSET"
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }
}

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

resource "aws_ssm_parameter" "migration_old_kms_key_id" {
  name      = "/${var.deployment}/${var.app_name}/MigrationOldKMSKeyID"
  type      = "String"
  value     = "UNSET"
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "migration_target_pcr0" {
  name      = "/${var.deployment}/${var.app_name}/MigrationTargetPCR0"
  type      = "String"
  value     = "UNSET"
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }
}

# KMS key ID — managed by null_resource.kms_key (kms.tf) and the supervisor
# during migration. Not a tofu resource because the value changes outside tofu.

# Storage bucket name.
resource "aws_ssm_parameter" "storage_bucket_name" {
  name      = "/${var.deployment}/${var.app_name}/StorageBucketName"
  type      = "String"
  value     = aws_s3_bucket.storage.id
  overwrite = true
}

# Storage data encryption key (DEK).
resource "aws_ssm_parameter" "storage_dek" {
  name      = "/${var.deployment}/${var.app_name}/StorageDEK/Ciphertext"
  type      = "String"
  value     = "UNSET"
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }
}

# Migration storage DEK.
resource "aws_ssm_parameter" "migration_storage_dek" {
  name      = "/${var.deployment}/${var.app_name}/Migration/StorageDEK/Ciphertext"
  type      = "String"
  value     = "UNSET"
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }
}

# Deploy-time app.env overrides. The runtime reads each key listed in
# ENCLAVE_APP_ENV_KEYS (baked into the EIF) and overlays the SSM value
# on top of the baked default. Missing keys leave the default in place.
resource "aws_ssm_parameter" "env_override" {
  for_each = var.env_values

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
    region                    = var.region
    dev_mode                  = var.deployment
    app_name                  = var.app_name
    kms_key_id                = local.kms_key_id
    eif_s3_url                = "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.enclave_eif.key}"
    supervisor_binary_s3_url  = "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.supervisor_binary.key}"
    migration_cooldown        = var.migration_cooldown
    previous_pcr0             = var.previous_pcr0
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

# Automatic migration — triggers when the EIF changes (new PCR0).
# On first apply this is a no-op (no running enclave to migrate).
# On subsequent applies with a new EIF, it calls the supervisor to
# perform a live migration (export keys, swap EIF, restart enclave).
# Automatic migration (production) — triggers when EIF changes.
# Uses SSM to call the supervisor on the EC2 instance.
resource "null_resource" "enclave_migration" {
  count = var.local ? 0 : 1

  triggers = {
    eif_key       = aws_s3_object.enclave_eif.key
    expected_pcr0 = var.expected_pcr0
  }

  provisioner "local-exec" {
    command = <<-EOT
      INSTANCE_ID="${aws_instance.nitro[0].id}"
      REGION="${var.region}"
      BUCKET="${aws_s3_bucket.assets.id}"
      EIF_KEY="${aws_s3_object.enclave_eif.key}"
      PCR0="${var.expected_pcr0}"
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
    eif_key       = aws_s3_object.enclave_eif.key
    expected_pcr0 = var.expected_pcr0
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

# Automatic migration (local mode) — triggers when expected_pcr0 changes.
# Calls the supervisor directly via HTTP (no EC2/SSM in local mode).
resource "null_resource" "enclave_migration_local" {
  count = var.local && var.expected_pcr0 != "" ? 1 : 0

  triggers = {
    expected_pcr0 = var.expected_pcr0
  }

  provisioner "local-exec" {
    command = <<-EOT
      SUPERVISOR_URL="${var.supervisor_url}"
      BUCKET="${aws_s3_bucket.assets.id}"
      PCR0="${var.expected_pcr0}"
      SECRETS='${jsonencode([for s in var.secrets : s.name])}'

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
  count = var.local && var.expected_pcr0 != "" ? 1 : 0

  triggers = {
    expected_pcr0 = var.expected_pcr0
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

output "kms_key_id" {
  description = "KMS encryption key ID."
  value       = local.kms_key_id
  sensitive   = true
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

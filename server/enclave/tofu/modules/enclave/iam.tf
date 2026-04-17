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
    resources = [
      aws_ssm_parameter.storage_bucket_name.arn,
    ]
  }

  # SSM: KMSKeyID needs read+write (mgmt server updates it during migration).
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

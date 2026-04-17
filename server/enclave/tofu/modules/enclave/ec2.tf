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
    region                       = var.region
    dev_mode                     = var.deployment
    app_name                     = var.app_name
    kms_key_id                   = local.kms_key_id
    eif_s3_url                   = "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.enclave_eif.key}"
    enclave_init_s3_url          = "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.enclave_init.key}"
    enclave_init_systemd_s3_url  = "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.watchdog_systemd.key}"
    imds_systemd_s3_url          = "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.imds_systemd.key}"
    gvproxy_systemd_s3_url       = "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.gvproxy_systemd.key}"
    mgmt_binary_s3_url           = "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.mgmt_binary.key}"
    mgmt_systemd_s3_url          = "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.mgmt_systemd.key}"
    gvproxy_binary_s3_url        = "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.gvproxy_binary.key}"
    gvproxy_start_script_s3_url  = "s3://${aws_s3_bucket.assets.id}/${aws_s3_object.gvproxy_start_script.key}"
    migration_cooldown           = var.migration_cooldown
    previous_pcr0                = var.previous_pcr0
  })

  tags = {
    Name   = "${local.prefix}-nitro-enclave"
    Region = var.region
  }

  # Wait for instance to pass status checks before proceeding.
  provisioner "local-exec" {
    command = "aws ec2 wait instance-status-ok --instance-ids ${self.id} --region ${var.region}"
  }

  # On destroy: stop enclave + schedule KMS key deletion via mgmt server.
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
# On subsequent applies with a new EIF, it calls the mgmt server to
# perform a live migration (export keys, swap EIF, restart enclave).
# Automatic migration (production) — triggers when EIF changes.
# Uses SSM to call the mgmt server on the EC2 instance.
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
      MIGRATE_BODY=$(jq -nc --arg b "$BUCKET" --arg k "$EIF_KEY" --arg p "$PCR0" --argjson s "$SECRETS" \
        '{eif_bucket:$b, eif_key:$k, pcr0:$p, secret_names:$s}')
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

# Automatic migration (local mode) — triggers when expected_pcr0 changes.
# Calls the mgmt server directly via HTTP (no EC2/SSM in local mode).
resource "null_resource" "enclave_migration_local" {
  count = var.local && var.expected_pcr0 != "" ? 1 : 0

  triggers = {
    expected_pcr0 = var.expected_pcr0
  }

  provisioner "local-exec" {
    command = <<-EOT
      MGMT_URL="${var.mgmt_url}"
      BUCKET="${aws_s3_bucket.assets.id}"
      PCR0="${var.expected_pcr0}"
      SECRETS='${jsonencode([for s in var.secrets : s.name])}'

      # Skip on first deploy (mgmt server not running yet).
      curl -sf "$${MGMT_URL}/health" >/dev/null 2>&1 || { echo "No mgmt server, skipping migration."; exit 0; }

      echo "Triggering local migration..."
      curl -sf -X POST "$${MGMT_URL}/migrate" \
        -H 'Content-Type: application/json' \
        -d "{\"eif_bucket\":\"$${BUCKET}\",\"eif_key\":\"image.eif\",\"pcr0\":\"$${PCR0}\",\"secret_names\":$${SECRETS}}"
    EOT
  }
}

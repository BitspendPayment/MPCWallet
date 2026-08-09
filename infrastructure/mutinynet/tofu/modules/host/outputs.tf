output "instance_id" {
  description = "EC2 instance ID. Use with `aws ssm start-session` for a shell."
  value       = aws_instance.host.id
}

output "elastic_ip" {
  description = "Public IP. The A record must point here before Caddy can complete an ACME challenge."
  value       = aws_eip.host.public_ip
}

output "url" {
  description = "Public base URL the app connects to."
  value       = "https://${var.fqdn}"
}

output "assets_bucket" {
  description = "S3 bucket holding the deployed runtime binary."
  value       = aws_s3_bucket.assets.id
}

output "data_volume_id" {
  description = "EBS volume holding the SQLite KV and Caddy's certs. Protected by prevent_destroy."
  value       = aws_ebs_volume.data.id
}

output "ssm_env_path" {
  description = "SSM path holding the runtime's environment. Edit + restart to reconfigure."
  value       = "${local.ssm_prefix}/env"
}

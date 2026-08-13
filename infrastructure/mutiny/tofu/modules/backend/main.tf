# Bootstrap module for the OpenTofu state backend.
# Creates an S3 bucket for state storage and a DynamoDB table for locking.
# This module uses local state (the backend can't store its own state).
#
# Usage:
#   cd modules/backend
#   tofu init
#   tofu apply -var="bucket_name=myapp-tfstate" -var="table_name=myapp-tfstate-lock" -var="region=us-east-1"

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "state" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "lock" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# =============================================================================
# Variables
# =============================================================================

variable "bucket_name" {
  description = "S3 bucket name for OpenTofu state storage."
  type        = string
}

variable "table_name" {
  description = "DynamoDB table name for state locking."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
}

# =============================================================================
# Outputs
# =============================================================================

output "bucket_name" {
  description = "S3 bucket name for state storage."
  value       = aws_s3_bucket.state.id
}

output "table_name" {
  description = "DynamoDB table name for state locking."
  value       = aws_dynamodb_table.lock.name
}

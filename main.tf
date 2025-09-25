provider "aws" {
  region = var.region

  # Optional account allowlist. Leave empty list to disable.
  dynamic "assume_role" {
    for_each = var.assume_role_arn == "" ? [] : [1]
    content {
      role_arn = var.assume_role_arn
    }
  }
}

# Optional guard if you want to restrict to certain accounts.
data "aws_caller_identity" "current" {}

locals {
  account_allowed = length(var.allowed_account_ids) == 0 || contains(var.allowed_account_ids, data.aws_caller_identity.current.account_id)

  common_tags = merge({
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.additional_tags)
}

# Fail early if account is not allowed
resource "null_resource" "account_guard" {
  count = local.account_allowed ? 0 : 1
  provisioner "local-exec" {
    command = "echo 'Error: Current account is not in allowed_account_ids' && exit 1"
  }
}

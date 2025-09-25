terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.36"
    }
  }

  # --- Remote state (optional). Pick ONE and uncomment/configure. ---

  # backend "s3" {
  #   bucket = "my-terraform-state-bucket"
  #   key    = "myservices/terraform.tfstate"
  #   region = "ap-southeast-2"
  #   dynamodb_table = "terraform-state-locks"
  #   encrypt = true
  # }

  # backend "http" {
  #   address        = "https://example.com/terraform/state/terraform"
  #   lock_address   = "https://example.com/terraform/state/terraform/lock"
  #   unlock_address = "https://example.com/terraform/state/terraform/lock"
  #   lock_method    = "POST"
  #   unlock_method  = "DELETE"
  #   retry_wait_min = 5
  # }
}

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-2"
}

variable "project" {
  description = "Project tag"
  type        = string
  default     = "myservices"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "prod"
}

variable "additional_tags" {
  description = "Optional extra tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "allowed_account_ids" {
  description = "Optional list of AWS account IDs allowed to run this stack"
  type        = list(string)
  default     = []
}

variable "assume_role_arn" {
  description = "Optional role ARN to assume for deployment"
  type        = string
  default     = ""
}

# --- EC2 / Networking ---

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3a.medium"
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 60
}

variable "availability_zone" {
  description = "Optional AZ override (e.g., ap-southeast-2a). Leave empty for AWS to choose."
  type        = string
  default     = ""
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH to the instance"
  type        = list(string)
  default     = []
}

variable "http_allowed_cidrs" {
  description = "CIDRs allowed for HTTP(S)/app ports"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_ports" {
  description = "List of TCP ports to expose (e.g., [80,443,8080])"
  type        = list(number)
  default     = [80, 443, 8080]
}

variable "use_eip" {
  description = "Whether to allocate and attach an Elastic IP"
  type        = bool
  default     = true
}

variable "key_name" {
  description = "Optional EC2 key pair name (use SSM by default)"
  type        = string
  default     = ""
}

# --- S3 Backups ---

variable "create_backup_bucket" {
  description = "Create an S3 bucket for backups and attach IAM policy to instance"
  type        = bool
  default     = true
}

variable "backup_bucket_prefix" {
  description = "Prefix for the backup bucket name; a random suffix will be added"
  type        = string
  default     = "myservices-backup"
}

variable "backup_bucket_force_destroy" {
  description = "Allow force_destroy on the backup bucket"
  type        = bool
  default     = false
}

# --- Route53 / DNS ---

variable "manage_zone" {
  description = "Create and manage a public hosted zone (if false, set hosted_zone_id)"
  type        = bool
  default     = false
}

variable "root_domain" {
  description = "Root domain to create (if manage_zone == true), e.g., example.com"
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Existing hosted zone ID to place records in (if manage_zone == false)"
  type        = string
  default     = ""
}

variable "subdomains" {
  description = "Subdomains to point at the instance EIP (if DNS is enabled)"
  type        = list(string)
  default     = ["n8n", "mautic", "traefik"]
}

variable "create_dns_records" {
  description = "Whether to create DNS records at all"
  type        = bool
  default     = false
}

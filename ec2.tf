
# EC2 host + IAM + security + cloud-init

# Ubuntu 22.04 (Jammy) minimal HVM AMI (latest)
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu-minimal/images/*ubuntu-jammy-22.04-amd64-minimal*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# Security group for the Docker host
resource "aws_security_group" "docker_host" {
  vpc_id = data.aws_vpc.default.id
  name   = "sg-docker-host"

  # SSH (optional—only if user supplied CIDRs)
  dynamic "ingress" {
    for_each = length(var.ssh_allowed_cidrs) > 0 ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidrs
    }
  }

  # App ports (e.g., 80/443/8080)
  dynamic "ingress" {
    for_each = toset(var.app_ports)
    content {
      description = "App port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.http_allowed_cidrs
    }
  }

  egress {
    description = "Allow outbound internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "sg-docker-host" })
}

# Cloud-init user data (installs Docker, compose plugin, restic, etc.)
data "cloudinit_config" "docker_host" {
  gzip          = false
  base64_encode = false

  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content      = file("${path.module}/cloud-config.yaml")
  }
}


# IAM for the instance

data "aws_iam_policy_document" "ec2_instance_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_instance_role" {
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ec2_instance_assume_role.json
  tags               = local.common_tags
}

# Attach SSM (Session Manager) core permissions
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach S3 backup policy if bucket is created
resource "aws_iam_role_policy_attachment" "backup_policy" {
  count      = var.create_backup_bucket ? 1 : 0
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.backup_put_objects[0].arn
}

resource "aws_iam_instance_profile" "profile" {
  role = aws_iam_role.ec2_instance_role.name
}


# EC2 instance (Docker host)

resource "aws_instance" "docker_host" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  # Optional SSH key (null omits the attribute)
  key_name = var.key_name != "" ? var.key_name : null

  # Optional AZ override (null lets AWS choose)
  availability_zone = var.availability_zone != "" ? var.availability_zone : null

  root_block_device {
    encrypted   = true
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
  }

  monitoring            = true
  user_data             = data.cloudinit_config.docker_host.rendered
  iam_instance_profile  = aws_iam_instance_profile.profile.name
  vpc_security_group_ids = [aws_security_group.docker_host.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # Don't churn when the AMI revs; upgrade intentionally
  lifecycle {
    ignore_changes = [ami]
  }

  tags = merge(local.common_tags, { Name = "docker-host" })
}


# Optional Elastic IP for the instance

resource "aws_eip" "docker_host" {
  count    = var.use_eip ? 1 : 0
  instance = aws_instance.docker_host.id
  domain   = "vpc"

  tags = merge(local.common_tags, { Name = "docker-host-eip" })
}

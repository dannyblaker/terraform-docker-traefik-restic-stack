resource "random_string" "suffix" {
  count   = var.create_backup_bucket ? 1 : 0
  length  = 6
  upper   = false
  numeric = true
  special = false
}

resource "aws_s3_bucket" "backups" {
  count  = var.create_backup_bucket ? 1 : 0
  bucket = "${var.backup_bucket_prefix}-${random_string.suffix[0].result}"
  force_destroy = var.backup_bucket_force_destroy

  tags = merge(local.common_tags, { Name = "${var.backup_bucket_prefix}" })
}

resource "aws_s3_bucket_public_access_block" "backups" {
  count  = var.create_backup_bucket ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "backups" {
  count  = var.create_backup_bucket ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  count  = var.create_backup_bucket ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  count  = var.create_backup_bucket ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }

  rule {
    id     = "retention"
    status = "Enabled"
    expiration { days = 120 }
    noncurrent_version_expiration { noncurrent_days = 90 }
  }
}

# IAM policy allowing the instance to read/write to the backup bucket
data "aws_iam_policy_document" "backup_put_objects" {
  count = var.create_backup_bucket ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.backups[0].arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:DeleteObject", "s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.backups[0].arn}/*"]
  }
}

resource "aws_iam_policy" "backup_put_objects" {
  count  = var.create_backup_bucket ? 1 : 0
  path   = "/"
  policy = data.aws_iam_policy_document.backup_put_objects[0].json
  tags   = local.common_tags
}

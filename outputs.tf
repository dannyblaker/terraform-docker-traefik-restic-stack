output "instance_id" {
  value = aws_instance.docker_host.id
}

output "public_ip" {
  value       = try(aws_eip.docker_host[0].public_ip, aws_instance.docker_host.public_ip)
  description = "Public IP (EIP if enabled, otherwise the instance's public IP)"
}

output "security_group_id" {
  value = aws_security_group.docker_host.id
}

output "backup_bucket_name" {
  value       = try(aws_s3_bucket.backups[0].bucket, null)
  description = "Name of the created backup bucket (if any)"
}

output "hosted_zone_id" {
  value       = var.manage_zone ? try(aws_route53_zone.zone[0].zone_id, null) : (var.hosted_zone_id != "" ? var.hosted_zone_id : null)
  description = "Hosted Zone ID used for records (if any)"
}

output "record_names" {
  value = try([for r in aws_route53_record.subdomain_a : r.name], [])
}

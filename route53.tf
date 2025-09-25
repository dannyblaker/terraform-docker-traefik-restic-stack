# Only create a zone if manage_zone = true
resource "aws_route53_zone" "zone" {
  count = var.manage_zone ? 1 : 0
  name  = var.root_domain

  tags = merge(local.common_tags, {
    Name = "zone-${var.root_domain}"
  })
}

# We can create records if create_dns_records = true and we can resolve a zone_id (either created or provided)
locals {
  effective_zone_id = var.manage_zone ? (length(aws_route53_zone.zone) > 0 ? aws_route53_zone.zone[0].zone_id : "") : var.hosted_zone_id
  have_zone         = local.effective_zone_id != ""
}

# Root A -> instance/EIP
resource "aws_route53_record" "root_a" {
  count   = var.create_dns_records && local.have_zone ? 1 : 0
  zone_id = local.effective_zone_id
  name    = var.manage_zone ? var.root_domain : trimsuffix(var.root_domain, ".") # Accept both with/without trailing dot
  type    = "A"
  ttl     = 60

  records = [
    # Prefer EIP if present, fallback to instance public IP (works if instance has public IP)
    try(aws_eip.docker_host[0].public_ip, aws_instance.docker_host.public_ip)
  ]

  allow_overwrite = true
}

# Subdomain A records -> instance/EIP
resource "aws_route53_record" "subdomain_a" {
  for_each = var.create_dns_records && local.have_zone ? toset(var.subdomains) : []

  zone_id = local.effective_zone_id
  name    = "${each.value}.${(var.manage_zone ? var.root_domain : trimsuffix(var.root_domain, "."))}"
  type    = "A"
  ttl     = 60
  records = [try(aws_eip.docker_host[0].public_ip, aws_instance.docker_host.public_ip)]
  allow_overwrite = true
}

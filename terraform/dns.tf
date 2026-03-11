# =============================================================================
# Route 53 & ExternalDNS
# IAM roles/policies are in iam.tf
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Route 53 Hosted Zone
# -----------------------------------------------------------------------------

resource "aws_route53_zone" "main" {
  name = "statuspage-aa.click"

  tags = {
    Name = "statuspage-aa.click"
  }
}

output "route53_name_servers" {
  description = "NS records to configure at your domain registrar"
  value       = aws_route53_zone.main.name_servers
}

# -----------------------------------------------------------------------------
# 2. ACM Certificate (HTTPS)
# -----------------------------------------------------------------------------

resource "aws_acm_certificate" "main" {
  domain_name               = "statuspage-aa.click"
  subject_alternative_names = ["*.statuspage-aa.click"]
  validation_method         = "DNS"

  tags = {
    Name = "statuspage-aa.click"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the ALB"
  value       = aws_acm_certificate.main.arn
}

# -----------------------------------------------------------------------------
# 2. Deploy ExternalDNS via Helm
# -----------------------------------------------------------------------------

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.14.5"

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "aws.region"
    value = "us-east-1"
  }

  set {
    name  = "aws.zoneType"
    value = "public"
  }

  set {
    name  = "domainFilters[0]"
    value = "statuspage-aa.click"
  }

  set {
    name  = "policy"
    value = "sync"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_dns.arn
  }

  depends_on = [
    aws_eks_node_group.nodes,
    aws_iam_role_policy_attachment.external_dns,
    aws_route53_zone.main,
    helm_release.aws_load_balancer_controller
  ]
}

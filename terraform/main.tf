# -----------------------------------------------------------------------------------------
# ACM Certificate
# -----------------------------------------------------------------------------------------
resource "aws_acm_certificate" "this" {
  domain_name               = "*.${var.website_domain}"
  subject_alternative_names = [var.website_domain]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  provider = aws.us_east_1
}

resource "aws_route53_record" "acm_certificate_validation_records" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 300
  type            = each.value.type
  zone_id         = data.aws_route53_zone.current.zone_id

  provider = aws.us_east_1
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_certificate_validation_records : record.fqdn]

  provider = aws.us_east_1

  depends_on = [
    aws_acm_certificate.this,
    aws_route53_record.acm_certificate_validation_records,
  ]
}

# -----------------------------------------------------------------------------------------
# Cloudfront
# -----------------------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_identity" "this" {
  comment = "OAI to restrict access to AWS S3 content"
}

resource "aws_cloudfront_distribution" "this" {
  aliases = [
    var.website_domain,
    "www.${var.website_domain}"
  ]
  enabled      = true
  price_class  = "PriceClass_100"
  http_version = "http2"

  default_cache_behavior {
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.cors_s3_origin.id
    allowed_methods          = var.cloudfront_allowed_methods
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = var.website_domain
    viewer_protocol_policy   = "redirect-to-https"
    compress                 = false
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.logging.bucket_domain_name
    prefix          = "cloudfront-website"
  }

  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
    origin_id   = var.website_domain

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  viewer_certificate {
    acm_certificate_arn            = aws_acm_certificate_validation.cert_validation.certificate_arn
    cloudfront_default_certificate = false
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  depends_on = [
    aws_s3_bucket_ownership_controls.logging,
    aws_s3_bucket_policy.logging
  ]
}

# -----------------------------------------------------------------------------------------
# Route53 for Cloudfront
# -----------------------------------------------------------------------------------------
resource "aws_route53_record" "website_A" {
  zone_id = data.aws_route53_zone.current.zone_id
  name    = var.website_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "website_AAAA" {
  zone_id = data.aws_route53_zone.current.zone_id
  name    = var.website_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_website_A" {
  zone_id = data.aws_route53_zone.current.zone_id
  name    = "www.${var.website_domain}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_website_AAAA" {
  zone_id = data.aws_route53_zone.current.zone_id
  name    = "www.${var.website_domain}"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

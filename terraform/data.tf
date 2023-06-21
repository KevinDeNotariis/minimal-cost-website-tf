data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}
data "aws_cloudfront_origin_request_policy" "cors_s3_origin" {
  name = "Managed-CORS-S3Origin"
}
data "aws_route53_zone" "current" {
  name = var.root_domain_name
}

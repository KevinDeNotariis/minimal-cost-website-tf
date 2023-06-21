locals {
  identifier                 = "minimal-cost-website"
  suffix                     = "production"
  website_domain             = "kevin.quantumchromod.com"
  cloudfront_allowed_methods = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
  bucket_allowed_methods     = ["POST", "GET"]
  source_provider            = "GitHub"
  source_repo_id             = "KevinDeNotariis/cv-react"
  source_branch_name         = "main"

  logs_retention      = 30
  build_timeout       = 60
  build_queue_timeout = 480
  build_image_type    = "BUILD_GENERAL1_SMALL"
  build_image         = "aws/codebuild/standard:6.0"

  sns_email_subscriptions = ["kevin.denotariis@gmail.com"]
}

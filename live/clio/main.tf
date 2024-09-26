module "clio_website" {
  source = "../../terraform"

  identifier                 = "mcw-clio"
  suffix                     = "production"
  root_domain_name           = "quantumchromod.com" # Public Hosted Zone in your AWS account
  website_domain             = "clio.quantumchromod.com"
  cloudfront_allowed_methods = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
  bucket_allowed_methods     = ["POST", "GET"]
  source_provider            = "GitHub"
  source_repo_id             = "KevinDeNotariis/clio-website" # Repo containing the code of the Website
  source_branch_name         = "main"

  logs_retention      = 30
  build_timeout       = 60
  build_queue_timeout = 480
  build_image_type    = "BUILD_GENERAL1_SMALL"
  build_image         = "aws/codebuild/standard:6.0"

  sns_email_subscriptions = ["kevin.denotariis@gmail.com"]

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

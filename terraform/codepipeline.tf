
# ---------------------------------------------------------------
# Create the codestar connection with github
# ---------------------------------------------------------------
resource "aws_codestarconnections_connection" "pipeline" {
  name          = "${var.identifier}-${var.suffix}"
  provider_type = var.source_provider
}

# ---------------------------------------------------------------
# Create the S3 Bucket to Hold the CodePipeline Artifacts
# ---------------------------------------------------------------
#tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "pipeline" {
  bucket = "${var.identifier}-codepipeline-artifacts-${var.suffix}"

  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "pipeline" {
  bucket = aws_s3_bucket.pipeline.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "pipeline" {
  bucket = aws_s3_bucket.pipeline.id
  acl    = "private"

  depends_on = [
    aws_s3_bucket_ownership_controls.pipeline
  ]
}

resource "aws_s3_bucket_public_access_block" "pipeline" {
  bucket = aws_s3_bucket.pipeline.id

  ignore_public_acls      = true
  block_public_acls       = true
  restrict_public_buckets = true
  block_public_policy     = true
}

resource "aws_s3_bucket_versioning" "pipeline" {
  bucket = aws_s3_bucket.pipeline.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "pipeline" {
  bucket = aws_s3_bucket.pipeline.id
  name   = "EntireBucket"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
}

#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline" {
  bucket = aws_s3_bucket.pipeline.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------
# Create the IAM Role for CodePipeline
# ---------------------------------------------------------------
resource "aws_iam_role" "codepipeline" {
  name = "${var.identifier}-codepipeline-${var.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

data "aws_iam_policy_document" "codepipeline" {
  #tfsec:ignore:aws-iam-no-policy-wildcards
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.pipeline.arn}",
      "${aws_s3_bucket.pipeline.arn}/*"
    ]
  }

  statement {
    actions   = ["codestar-connections:UseConnection"]
    resources = ["${aws_codestarconnections_connection.pipeline.arn}"]
  }

  statement {
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
    resources = [
      "arn:aws:codebuild:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:project/${aws_codebuild_project.pipeline.name}"
    ]
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline.json
}

# ---------------------------------------------------------------
# Create the IAM Role for CodeBuild Container
# ---------------------------------------------------------------
resource "aws_iam_role" "codebuild" {
  name = "${var.identifier}-codebuild-${var.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [aws_cloudwatch_log_group.pipeline.arn, "${aws_cloudwatch_log_group.pipeline.arn}:*"]
  }

  #tfsec:ignore:aws-iam-no-policy-wildcards
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.pipeline.arn}",
      "${aws_s3_bucket.pipeline.arn}/*"
    ]
  }

  statement {
    actions = [
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases",
      "codebuild:BatchPutCodeCoverages",
    ]
    resources = [format("arn:aws:codebuild:%s:%s:report-group/*",
      data.aws_region.current.name,
      data.aws_caller_identity.current.account_id,
    )]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:AbortMultipartUpload",
      "s3:ListBucket",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
      "s3:ListMultipartUploadParts"
    ]
    resources = [
      "${aws_s3_bucket.website.arn}",
      "${aws_s3_bucket.website.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
}

# ---------------------------------------------------------------
# Create the CloudWatch log group for CodeBuild outputs
# ---------------------------------------------------------------
#tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "pipeline" {
  name = format("%s-%s-%s/%s",
    var.identifier,
    "codepipeline",
    var.suffix,
    "build-logs"
  )
  retention_in_days = var.logs_retention
}

# ---------------------------------------------------------------
# Create the CodeBuild Project
# ---------------------------------------------------------------
resource "aws_codebuild_project" "pipeline" {
  name               = "${var.identifier}-${var.suffix}"
  description        = "Build Stage for ${var.identifier}"
  build_timeout      = var.build_timeout
  service_role       = aws_iam_role.codebuild.arn
  queued_timeout     = var.build_queue_timeout
  project_visibility = "PRIVATE"

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type = "NO_CACHE"
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.pipeline.name
    }

    s3_logs {
      status   = "ENABLED"
      location = format("%s/%s", aws_s3_bucket.pipeline.id, "build-logs")
    }
  }

  environment {
    compute_type                = var.build_image_type
    image                       = var.build_image
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
    type                        = "LINUX_CONTAINER"
  }

  source {
    type = "CODEPIPELINE"
  }
}

# ---------------------------------------------------------------
# Create the CodePipeline Pipeline
# ---------------------------------------------------------------
resource "aws_codepipeline" "pipeline" {
  name     = "${var.identifier}-${var.suffix}"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.pipeline.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.pipeline.arn
        FullRepositoryId = var.source_repo_id
        BranchName       = var.source_branch_name
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.pipeline.name
      }
    }
  }
}

# ---------------------------------------------------------------
# Create CodeStar Notification Rule for CodePipeline Events
# ---------------------------------------------------------------
resource "aws_codestarnotifications_notification_rule" "pipeline" {
  name        = "${var.identifier}-${var.suffix}"
  detail_type = "FULL"
  event_type_ids = [
    "codepipeline-pipeline-pipeline-execution-failed",
    "codepipeline-pipeline-pipeline-execution-canceled",
    "codepipeline-pipeline-pipeline-execution-started",
    "codepipeline-pipeline-pipeline-execution-resumed",
    "codepipeline-pipeline-pipeline-execution-succeeded",
    "codepipeline-pipeline-pipeline-execution-superseded"
  ]
  resource = aws_codepipeline.pipeline.arn

  target {
    type    = "SNS"
    address = aws_sns_topic.this.arn
  }
}

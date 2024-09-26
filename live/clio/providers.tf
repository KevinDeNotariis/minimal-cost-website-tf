terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4"
    }
  }

  required_version = "~> 1"
}

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      owner       = "kevin de notariis"
      repo        = "github.com/KevinDeNotariis/minimal-cost-website/live/clio"
      path        = "terraform"
      environment = "production"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      owner       = "kevin de notariis"
      repo        = "github.com/KevinDeNotariis/minimal-cost-website/live/clio"
      path        = "terraform"
      environment = "production"
    }
  }
}

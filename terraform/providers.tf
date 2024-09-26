terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 4"
      configuration_aliases = [aws, aws.us_east_1]
    }
  }
}

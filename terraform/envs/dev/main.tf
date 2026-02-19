terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket       = "qfeed-infra-s3-tfstate"
    key          = "envs/dev/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Environment = "dev"
    Project     = "qfeed"
    ManagedBy   = "terraform"
  }
}

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.16.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "quicksight_redirects" {
  # For local development, use a relative path:
  #   source = "../../"
  # For external usage, reference the GitHub repository:
  source = "github.com/mcgarrah/terraform-aws-quicksight-redirect"

  name_prefix         = "quicksight"
  r53_hosted_zone_id  = var.r53_hosted_zone_id
  acm_certificate_arn = var.acm_certificate_arn

  redirects = {
    "analytics.example.com" = {
      aws_region      = "us-east-1"
      directory_alias = "analytics"
    }
    "reporting.example.com" = {
      aws_region      = "us-west-2"
      directory_alias = "reporting"
    }
  }
}

output "cloudfront_distribution_id" {
  value = module.quicksight_redirects.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  value = module.quicksight_redirects.cloudfront_domain_name
}

output "redirect_domains" {
  value = module.quicksight_redirects.redirect_domains
}

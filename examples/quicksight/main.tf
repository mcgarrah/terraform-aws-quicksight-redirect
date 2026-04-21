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

module "quicksight_redirect" {
  # For local development, use a relative path:
  #   source = "../../"
  # For external usage, reference the GitHub repository:
  source = "github.com/mcgarrah/aws_cloudfront_url_redirector"

  name_prefix         = "analytics-bi"
  domain_name         = "analytics-bi.example.com"
  r53_hosted_zone_id  = var.r53_hosted_zone_id
  acm_certificate_arn = var.acm_certificate_arn
  aws_region          = "us-east-1"
  directory_alias     = "analytics-bi"
}

output "cloudfront_distribution_id" {
  value = module.quicksight_redirect.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  value = module.quicksight_redirect.cloudfront_domain_name
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "url_redirector" {
  source = "./modules/cf-url-redirector"
  
  domain_name           = "analytics-bi.mcgarrah.org"
  r53_hosted_zone_id    = var.r53_hosted_zone_id
  acm_certificate_arn   = var.acm_certificate_arn
  aws_region           = "us-east-1"
  directory_alias      = "analytics-bi"
}
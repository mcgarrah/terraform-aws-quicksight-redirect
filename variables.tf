variable "name_prefix" {
  description = "Prefix for resource names to avoid collisions when using multiple instances of this module"
  type        = string
  default     = "url-redirect"
}

variable "domain_name" {
  description = "Custom domain name to redirect from (e.g. analytics-bi.example.com)"
  type        = string
}

variable "r53_hosted_zone_id" {
  description = "Route 53 hosted zone ID for the domain"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN covering the domain name (must be in us-east-1)"
  type        = string
}

variable "aws_region" {
  description = "AWS region passed as the region parameter in the QuickSight redirect URL"
  type        = string
  default     = "us-east-1"
}

variable "directory_alias" {
  description = "QuickSight directory alias passed as the directory_alias parameter in the redirect URL"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the redirect"
  type        = string
}

variable "r53_hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

variable "aws_region" {
  description = "AWS region for QuickSight"
  type        = string
}

variable "directory_alias" {
  description = "QuickSight directory alias"
  type        = string
}
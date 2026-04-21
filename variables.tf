variable "r53_hosted_zone_id" {
  description = "Route 53 hosted zone ID for mcgarrah.org"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for *.mcgarrah.org"
  type        = string
}
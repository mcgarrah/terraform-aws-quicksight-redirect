variable "name_prefix" {
  description = "Prefix for resource names to avoid collisions when using multiple instances of this module"
  type        = string
  default     = "url-redirect"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.name_prefix))
    error_message = "name_prefix must contain only alphanumeric characters and hyphens."
  }
}

variable "r53_hosted_zone_id" {
  description = "Route 53 hosted zone ID for the domain"
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.r53_hosted_zone_id))
    error_message = "r53_hosted_zone_id must be a valid Route 53 hosted zone ID (starts with Z)."
  }
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN covering all domain names in redirects (must be in us-east-1)"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:acm:us-east-1:[0-9]{12}:certificate/", var.acm_certificate_arn))
    error_message = "acm_certificate_arn must be a valid ACM certificate ARN in us-east-1."
  }
}

variable "redirects" {
  description = "Map of domain names to QuickSight redirect parameters. Each key is a domain name, and the value specifies the aws_region and directory_alias for the redirect URL."
  type = map(object({
    aws_region      = string
    directory_alias = string
  }))

  validation {
    condition     = length(var.redirects) > 0
    error_message = "At least one redirect must be defined."
  }

  validation {
    condition     = alltrue([for k, v in var.redirects : can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", k))])
    error_message = "Redirect domain names must be valid hostnames (e.g. analytics.example.com)."
  }

  validation {
    condition     = alltrue([for k, v in var.redirects : can(regex("^[a-z0-9-]+$", v.aws_region))])
    error_message = "aws_region values must contain only lowercase alphanumeric characters and hyphens."
  }

  validation {
    condition     = alltrue([for k, v in var.redirects : can(regex("^[a-zA-Z0-9-]+$", v.directory_alias))])
    error_message = "directory_alias values must contain only alphanumeric characters and hyphens."
  }
}

variable "enable_access_logging" {
  description = "Enable CloudFront standard access logging to an S3 bucket. Creates and manages the logging bucket automatically."
  type        = bool
  default     = false
}

variable "access_log_prefix" {
  description = "Optional prefix for CloudFront access log file names in the S3 bucket."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Map of tags to apply to all taggable resources"
  type        = map(string)
  default     = {}
}

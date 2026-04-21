output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.redirect.id
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.redirect.domain_name
}

output "redirect_domains" {
  description = "List of domain names configured for redirection"
  value       = keys(var.redirects)
}

output "access_log_bucket_name" {
  description = "Name of the S3 bucket for CloudFront access logs (null if logging is disabled)"
  value       = var.enable_access_logging ? aws_s3_bucket.access_logs[0].id : null
}

output "access_log_bucket_arn" {
  description = "ARN of the S3 bucket for CloudFront access logs (null if logging is disabled)"
  value       = var.enable_access_logging ? aws_s3_bucket.access_logs[0].arn : null
}

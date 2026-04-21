
output "aws_cloudfront_cache_policy_cf_cache_policy_url_redirect_id" {
  value = "${aws_cloudfront_cache_policy.cf_cache_policy_url_redirect.id}"
}

output "aws_cloudfront_distribution_cf_deployment_url_redirect_id" {
  value = "${aws_cloudfront_distribution.cf_deployment_url_redirect.id}"
}

output "aws_cloudwatch_log_group_cw_log_group_url_redirect_id" {
  value = "${aws_cloudwatch_log_group.cw_log_group_url_redirect.id}"
}

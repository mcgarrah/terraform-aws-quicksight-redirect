locals {
  domain_names = keys(var.redirects)

  # Build the redirect map as a JSON object for safe injection into JavaScript
  redirect_map = { for domain, config in var.redirects :
    domain => "https://quicksight.aws.amazon.com/?region=${config.aws_region}&directory_alias=${config.directory_alias}"
  }
}

# --- Route 53 ---

resource "aws_route53_record" "redirect" {
  for_each = var.redirects

  name    = each.key
  type    = "A"
  zone_id = var.r53_hosted_zone_id

  alias {
    name                   = aws_cloudfront_distribution.redirect.domain_name
    zone_id                = aws_cloudfront_distribution.redirect.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "redirect_ipv6" {
  for_each = var.redirects

  name    = each.key
  type    = "AAAA"
  zone_id = var.r53_hosted_zone_id

  alias {
    name                   = aws_cloudfront_distribution.redirect.domain_name
    zone_id                = aws_cloudfront_distribution.redirect.hosted_zone_id
    evaluate_target_health = false
  }
}

# --- CloudFront Distribution ---

resource "aws_cloudfront_distribution" "redirect" {
  aliases = local.domain_names
  comment = "${var.name_prefix} CloudFront URL redirect"

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cache_policy_id = aws_cloudfront_cache_policy.redirect.id
    cached_methods  = ["GET", "HEAD"]

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirect.arn
    }

    # AWS managed origin request policy: AllViewerExceptHostHeader
    # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
    target_origin_id         = "none.none"
    viewer_protocol_policy   = "redirect-to-https"
  }

  enabled         = true
  http_version    = "http2"
  is_ipv6_enabled = true

  dynamic "logging_config" {
    for_each = var.enable_access_logging ? [1] : []
    content {
      bucket          = aws_s3_bucket.access_logs[0].bucket_regional_domain_name
      include_cookies = false
      prefix          = var.access_log_prefix
    }
  }

  # Dummy origin — the CloudFront Function intercepts all requests before
  # traffic ever reaches this origin, so it is never contacted.
  origin {
    domain_name = "none.none"
    origin_id   = "none.none"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = var.tags

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}

# --- Access Logging S3 Bucket ---

resource "aws_s3_bucket" "access_logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket_prefix = "${var.name_prefix}-cf-logs-"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_ownership_controls" "access_logs" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "access_logs" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  depends_on = [aws_s3_bucket_ownership_controls.access_logs]
  acl        = "log-delivery-write"
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

# --- CloudFront Cache Policy ---

resource "aws_cloudfront_cache_policy" "redirect" {
  name        = "${var.name_prefix}-cache-policy"
  comment     = "Cache policy for ${var.name_prefix} URL redirects"
  default_ttl = 0
  max_ttl     = 31536000
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["host"]
      }
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

# --- CloudFront Function ---

resource "aws_cloudfront_function" "redirect" {
  name    = "${var.name_prefix}-function"
  runtime = "cloudfront-js-2.0"
  comment = "301 redirect for ${var.name_prefix}"
  publish = true

  code = <<-JS
    function handler(event) {
        var redirects = ${jsonencode(local.redirect_map)};
        var host = event.request.headers.host.value;
        var newurl = redirects[host] || "https://quicksight.aws.amazon.com";

        return {
            statusCode: 301,
            statusDescription: "Moved Permanently",
            headers: { location: { value: newurl } }
        };
    }
  JS
}

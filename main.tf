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

# --- CloudFront Distribution ---

resource "aws_cloudfront_distribution" "redirect" {
  aliases = local.domain_names
  comment = "${var.name_prefix} CloudFront URL redirect"

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cache_policy_id = aws_cloudfront_cache_policy.redirect.id
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    default_ttl     = 0
    max_ttl         = 0
    min_ttl         = 0

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

    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

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

# --- CloudWatch Log Group ---

resource "aws_cloudwatch_log_group" "redirect" {
  name              = "/aws/cloudfront/${var.name_prefix}"
  retention_in_days = 1
  kms_key_id        = var.cloudwatch_kms_key_id
  tags              = var.tags
}

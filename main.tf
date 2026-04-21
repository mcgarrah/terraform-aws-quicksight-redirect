resource "aws_route53_record" "redirect" {
  name    = var.domain_name
  type    = "A"
  zone_id = var.r53_hosted_zone_id

  alias {
    name                   = aws_cloudfront_distribution.redirect.domain_name
    zone_id                = aws_cloudfront_distribution.redirect.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_cloudfront_distribution" "redirect" {
  aliases = [var.domain_name]
  comment = "CloudFront URL redirect for ${var.domain_name}"

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

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}

resource "aws_cloudfront_cache_policy" "redirect" {
  name        = "${var.name_prefix}-cache-policy"
  comment     = "Cache policy for ${var.domain_name} URL redirect"
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

resource "aws_cloudfront_function" "redirect" {
  name    = "${var.name_prefix}-function"
  runtime = "cloudfront-js-2.0"
  comment = "301 redirect for ${var.domain_name}"
  publish = true

  code = <<-JS
    function handler(event) {
        var host = event.request.headers.host.value;
        var newurl = "https://quicksight.aws.amazon.com";

        if (host === "${var.domain_name}") {
            newurl = "https://quicksight.aws.amazon.com/?region=${var.aws_region}&directory_alias=${var.directory_alias}";
        }

        return {
            statusCode: 301,
            statusDescription: "Moved Permanently",
            headers: { location: { value: newurl } }
        };
    }
  JS
}

resource "aws_cloudwatch_log_group" "redirect" {
  name              = "/aws/cloudfront/${var.name_prefix}"
  retention_in_days = 1
}

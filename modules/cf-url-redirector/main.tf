# Provision an example CloudFront URL Redirector
# TODO: Add support for multiple redirect

resource "aws_route53_record" "r53_record_analytics-bi" {
  name    = var.domain_name
  type    = "A"
  zone_id = var.r53_hosted_zone_id

  alias {
    name                   = aws_cloudfront_distribution.cf_deployment_url_redirect.domain_name
    zone_id                = aws_cloudfront_distribution.cf_deployment_url_redirect.hosted_zone_id
    evaluate_target_health = false
  }
}


resource "aws_cloudfront_distribution" "cf_deployment_url_redirect" {
  aliases = [var.domain_name]
  comment = "AWS CloudFront URL Redirection Deployment"

  default_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    #cache_policy_id = "${aws_cloudfront_cache_policy.cf_cache_policy_url_redirect.id}"
    cache_policy_id = aws_cloudfront_cache_policy.cf_cache_policy_url_redirect
    cached_methods  = ["GET", "HEAD"]
    compress        = "true"
    default_ttl     = "0"

    function_association {
      event_type   = "viewer-request"
      #function_arn = "arn:aws:cloudfront::590722206016:function/url_redirection"
      function_arn = aws_cloudfront_function.url_redirect.arn
    }

    grpc_config {
      enabled = "false"
    }

    max_ttl                  = "0"
    min_ttl                  = "0"
    # TODO IDENTIFY THIS VALUE
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
    smooth_streaming         = "false"
    target_origin_id         = "none.none"
    viewer_protocol_policy   = "redirect-to-https"
  }

  enabled         = "true"
  http_version    = "http2"
  is_ipv6_enabled = "true"

  origin {
    connection_attempts = "3"
    connection_timeout  = "10"

    custom_origin_config {
      http_port                = "80"
      https_port               = "443"
      origin_keepalive_timeout = "5"
      origin_protocol_policy   = "match-viewer"
      origin_read_timeout      = "30"
      origin_ssl_protocols     = ["TLSv1.2"]
    }

    domain_name = "none.none"
    origin_id   = "none.none"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  retain_on_delete = "false"
  staging          = "false"

  viewer_certificate {
    acm_certificate_arn            = var.acm_certificate_arn
    cloudfront_default_certificate = "false"
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }
}

resource "aws_cloudfront_cache_policy" "cf_cache_policy_url_redirect" {
  comment     = "Policy for origins that return Cache-Control headers. Query strings are not included in the cache key."
  default_ttl = "0"
  max_ttl     = "31536000"
  min_ttl     = "0"
  name        = "UseOriginCacheControlHeaders"

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "all"
    }

    enable_accept_encoding_brotli = "true"
    enable_accept_encoding_gzip   = "true"

    headers_config {
      header_behavior = "whitelist"

      headers {
        items = ["host", "origin", "x-http-method", "x-http-method-override", "x-method-override"]
      }
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}


resource "local_file" "url_redirect_js_file" {
  content = <<JSCODE
function handler(event) {
    var request = event.request;
    var headers = request.headers;
    var host = request.headers.host[0].value; // Access host header correctly
    var newurl = `https://quicksight.aws.amazon.com`

    switch(host) {
        case "${var.domain_name}": {
            newurl = `https://quicksight.aws.amazon.com/?region=${var.aws_region}&directory_alias=${var.directory_alias}`
            break;
        }
        default: {
            break;
        }
    }

    var response = {
        statusCode: 301,
        statusDescription: 'Moved Permanently',
        headers:
            { "location": [{ "key": "Location", "value": newurl }] } // Correct header format
    }

    return response;
}
JSCODE
  filename = "${path.root}/url_redirect.js"
}

resource "aws_cloudfront_function" "url_redirect" {
  name    = "url_redirect"
  runtime = "cloudfront-js-2.0"
  comment = "CloudFront Function for doing URL redirection"
  publish = true
  code    = file("${path.root}/url_redirect.js")
}

resource "aws_cloudwatch_log_group" "cw_log_group_url_redirect" {
  log_group_class   = "STANDARD"
  name              = "/aws/cloudfront/url_redirect"
  retention_in_days = "1"
  skip_destroy      = "false"
}


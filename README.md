# AWS CloudFront URL Redirector

A Terraform module that creates a friendly vanity URL for AWS QuickSight using CloudFront, ACM, and Route 53. A CloudFront Function evaluates incoming requests by hostname and returns an HTTP 301 permanent redirect to your QuickSight instance — no origin server required.

## Architecture

```
Browser -> Route 53 (A record alias) -> CloudFront Distribution -> CloudFront Function (301 redirect)
```

1. A Route 53 A record aliases your custom domain to a CloudFront distribution.
2. An ACM certificate provides HTTPS for the custom domain.
3. A CloudFront Function intercepts every viewer request and returns a 301 redirect before the request ever reaches an origin.
4. The origin is set to a dummy value (`none.none`) — this is intentional. The CloudFront Function handles all requests so no origin is ever contacted.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5
- AWS provider >= 5.16.0
- An AWS account with permissions to manage Route 53, CloudFront, ACM, and CloudWatch
- An existing Route 53 hosted zone for your domain
- An ACM certificate **in `us-east-1`** covering the domain name you want to redirect (CloudFront is a global service and requires certificates in us-east-1)

## Usage

### As a GitHub-sourced module

```hcl
module "quicksight_redirect" {
  source = "github.com/mcgarrah/aws_cloudfront_url_redirector"

  name_prefix         = "analytics-bi"
  domain_name         = "analytics-bi.example.com"
  r53_hosted_zone_id  = "Z1234567890ABC"
  acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
  aws_region          = "us-east-1"
  directory_alias     = "analytics-bi"
}
```

After deployment, visiting `https://analytics-bi.example.com` returns a 301 redirect to:

```
https://quicksight.aws.amazon.com/?region=us-east-1&directory_alias=analytics-bi
```

### Pinning to a version

```hcl
source = "github.com/mcgarrah/aws_cloudfront_url_redirector?ref=v1.0.0"
```

### Multiple redirects

Each module instance creates its own CloudFront distribution. Use `name_prefix` to avoid resource name collisions:

```hcl
module "analytics_redirect" {
  source = "github.com/mcgarrah/aws_cloudfront_url_redirector"

  name_prefix         = "analytics"
  domain_name         = "analytics.example.com"
  r53_hosted_zone_id  = var.r53_hosted_zone_id
  acm_certificate_arn = var.acm_certificate_arn
  aws_region          = "us-east-1"
  directory_alias     = "analytics"
}

module "reporting_redirect" {
  source = "github.com/mcgarrah/aws_cloudfront_url_redirector"

  name_prefix         = "reporting"
  domain_name         = "reporting.example.com"
  r53_hosted_zone_id  = var.r53_hosted_zone_id
  acm_certificate_arn = var.acm_certificate_arn
  aws_region          = "us-west-2"
  directory_alias     = "reporting"
}
```

## Module Inputs

| Variable | Description | Default | Required |
|---|---|---|---|
| `name_prefix` | Prefix for resource names to avoid collisions | `"url-redirect"` | no |
| `domain_name` | Custom domain to redirect from | — | yes |
| `r53_hosted_zone_id` | Route 53 hosted zone ID | — | yes |
| `acm_certificate_arn` | ACM certificate ARN (must be in us-east-1) | — | yes |
| `aws_region` | AWS region parameter in the QuickSight redirect URL | `"us-east-1"` | no |
| `directory_alias` | QuickSight directory alias parameter in the redirect URL | — | yes |

## Module Outputs

| Output | Description |
|---|---|
| `cloudfront_distribution_id` | The ID of the CloudFront distribution |
| `cloudfront_domain_name` | The domain name of the CloudFront distribution (e.g. `d111111abcdef8.cloudfront.net`) |

## How the CloudFront Function Works

The CloudFront Function is written in JavaScript (`cloudfront-js-2.0` runtime) and runs on every viewer request. It inspects the `Host` header and returns a 301 redirect response directly to the client without ever forwarding traffic to the origin.

```javascript
function handler(event) {
    var host = event.request.headers.host.value;
    var newurl = "https://quicksight.aws.amazon.com";

    if (host === "analytics-bi.example.com") {
        newurl = "https://quicksight.aws.amazon.com/?region=us-east-1&directory_alias=analytics-bi";
    }

    return {
        statusCode: 301,
        statusDescription: "Moved Permanently",
        headers: { location: { value: newurl } }
    };
}
```

The `domain_name`, `aws_region`, and `directory_alias` values shown above are injected by Terraform variables at deploy time. If the `Host` header matches the configured domain, the function builds the redirect URL with the configured region and directory alias. Unmatched hosts fall through to the default which redirects to the base QuickSight URL.

## AWS Resources Created

- **Route 53 A Record** — Aliases the custom domain to the CloudFront distribution
- **CloudFront Distribution** — Hosts the CloudFront Function with a dummy origin (`none.none`)
- **CloudFront Cache Policy** — Forwards the `host` header to enable hostname-based routing in the function
- **CloudFront Function** — JavaScript function that returns 301 redirects
- **CloudWatch Log Group** — Logs for the CloudFront function (1-day retention)

## Notes

- The ACM certificate must be in `us-east-1` regardless of your deployment region, as CloudFront is a global service.
- The dummy origin `none.none` is intentional — the CloudFront Function intercepts all requests before they reach the origin. No traffic is ever sent to this origin.
- The `PriceClass_100` setting limits CloudFront edge locations to North America and Europe to reduce costs.
- This module does **not** declare a provider or backend — the caller is responsible for configuring those.

## Examples

See the [examples/quicksight](examples/quicksight) directory for a complete working example.

## License

MIT

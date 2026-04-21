# AWS CloudFront URL Redirector

A simple URL redirector using AWS CloudFront, ACM, and Route 53 provisioned with Terraform. It uses a CloudFront Function to evaluate incoming requests by hostname and return an HTTP 301 permanent redirect to a target URL.

## Architecture

```
Browser -> Route 53 (A record alias) -> CloudFront Distribution -> CloudFront Function (301 redirect)
```

1. A Route 53 A record aliases your custom domain to a CloudFront distribution.
2. An ACM certificate provides HTTPS for the custom domain.
3. A CloudFront Function intercepts every viewer request and returns a 301 redirect before the request ever reaches an origin.
4. The origin is set to a dummy value (`none.none`) since the CloudFront Function handles all requests — no origin is ever contacted.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5
- An AWS account with permissions to manage Route 53, CloudFront, ACM, and CloudWatch
- An existing Route 53 hosted zone for your domain
- An ACM certificate (in `us-east-1`) covering the domain name you want to redirect

## Module Inputs

| Variable | Description | Example |
|---|---|---|
| `domain_name` | Custom domain to redirect from | `analytics-bi.mcgarrah.org` |
| `r53_hosted_zone_id` | Route 53 hosted zone ID | `Z1234567890ABC` |
| `acm_certificate_arn` | ACM certificate ARN (must be in us-east-1) | `arn:aws:acm:us-east-1:123456789012:certificate/...` |
| `aws_region` | AWS region parameter passed to the redirect target URL | `us-east-1` |
| `directory_alias` | QuickSight directory alias parameter passed to the redirect target URL | `analytics-bi` |

## Module Outputs

| Output | Description |
|---|---|
| `cloudfront_distribution_id` | The ID of the CloudFront distribution |
| `cloudfront_domain_name` | The domain name of the CloudFront distribution (e.g. `d111111abcdef8.cloudfront.net`) |

## Usage

### 1. Configure variables

Copy the example tfvars file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
r53_hosted_zone_id  = "Z1234567890ABC"
acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

### 2. Call the module

```hcl
module "url_redirector" {
  source = "./modules/cf-url-redirector"

  domain_name        = "analytics-bi.mcgarrah.org"
  r53_hosted_zone_id = var.r53_hosted_zone_id
  acm_certificate_arn = var.acm_certificate_arn
  aws_region         = "us-east-1"
  directory_alias    = "analytics-bi"
}
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

After deployment, visiting `https://analytics-bi.mcgarrah.org` will return a 301 redirect to:

```
https://quicksight.aws.amazon.com/?region=us-east-1&directory_alias=analytics-bi
```

## How the CloudFront Function Works

The CloudFront Function is written in JavaScript (`cloudfront-js-2.0` runtime) and runs on every viewer request. It never forwards traffic to the origin — instead it inspects the `Host` header and returns a 301 redirect response directly to the client.

```javascript
function handler(event) {
    var request = event.request;
    var host = request.headers.host.value;
    var newurl = `https://quicksight.aws.amazon.com`

    switch(host) {
        case "analytics-bi.mcgarrah.org": {
            newurl = `https://quicksight.aws.amazon.com/?region=us-east-1&directory_alias=analytics-bi`
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
            { "location": { "value": newurl } }
    }

    return response;
}
```

The `domain_name`, `aws_region`, and `directory_alias` values in the JavaScript above are injected by Terraform variables at deploy time. The `switch` statement matches the incoming `Host` header against the configured domain name. If matched, it builds the redirect URL with the configured region and directory alias. Unmatched hosts fall through to the default case which redirects to the base QuickSight URL.

## AWS Resources Created

- **Route 53 A Record** — Aliases the custom domain to the CloudFront distribution
- **CloudFront Distribution** — Hosts the CloudFront Function with a dummy origin (`none.none`)
- **CloudFront Cache Policy** — Forwards host headers to enable hostname-based routing in the function
- **CloudFront Function** — JavaScript function that returns 301 redirects
- **CloudWatch Log Group** — Logs for the CloudFront function (1-day retention)

## Notes

- The ACM certificate must be in `us-east-1` regardless of your deployment region, as CloudFront is a global service.
- The dummy origin `none.none` is intentional — the CloudFront Function intercepts all requests before they reach the origin.
- The `PriceClass_100` setting limits CloudFront edge locations to North America and Europe to reduce costs.

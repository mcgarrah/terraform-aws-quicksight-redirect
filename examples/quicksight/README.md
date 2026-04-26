# QuickSight Redirect Example

Deploys two vanity URL redirects for AWS QuickSight through a single CloudFront distribution.

| Vanity Domain | Redirects To |
|---------------|-------------|
| `analytics.example.com` | QuickSight `us-east-1` / `analytics` |
| `reporting.example.com` | QuickSight `us-west-2` / `reporting` |

## Prerequisites

- An existing Route 53 hosted zone for your domain
- An ACM certificate in `us-east-1` covering both domain names (wildcard or SANs)

## Usage

> **Note:** The `main.tf` in this directory uses `source = "../../"` so the example can be tested against local module changes. When using this example as a starting point for your own deployment, replace the source with the Terraform Registry reference:
>
> ```hcl
> source  = "mcgarrah/quicksight-redirect/aws"
> version = "~> 1.0"
> ```

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Route 53 hosted zone ID and ACM certificate ARN

terraform init
terraform plan
terraform apply
```

## After Deployment

Verify the redirects:

```bash
curl -sI https://analytics.example.com | grep -i location
# Location: https://quicksight.aws.amazon.com/?region=us-east-1&directory_alias=analytics
```

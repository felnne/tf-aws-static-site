# AWS Static Website Module

## Overview

Creates opinionated infrastructure to host a static website in AWS using:

- an S3 bucket with static website hosting enabled (for index documents, redirects, etc.)
- a CloudFront distribution (for custom domains, caching, etc.)
- a Route53 record and ACM certificate (to underpin using a custom domain with auto-renewing HTTPS)

## Usage

See `examples/default/`.

### Content permissions

> [!NOTE]
> This module does not manage IAM permissions to manage content within the hosting S3 bucket. 

Assign these separately via a suitable policy, such as:

```hcl
module "example" {
  source = "git::https://github.com/felnne/tf-aws-static-site.git?ref=v0.2.0"
  # ...
}

resource "aws_iam_user_policy" "example" {
  name = "example"
  user = "example"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MinimalManagementPermissions"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectAcl",
          "s3:PutObjectAcl"
        ]
        Resource = [
          module.example.s3_bucket_name,
          "${module.example.s3_bucket_name}/*"
        ]
      }
    ]
  })
}
```

## Requirements

In addition to Terraform and provider requirements in `versions.tf`, you will need suitable permissions within an AWS
account to create and configure resources in S3, Route53 and CloudFront.

## Implementation

### S3 origin access

A [referrer based secret](https://repost.aws/knowledge-center/cloudfront-serve-static-website#:~:text=values.-,Use%20a%20website%20endpoint%20as%20the%20origin%2C%20and%20restrict%20access%20with%20a%20Referer%20header,-Important) is used to prevent direct access to S3 content via the S3 website endpoint.

### HTTP protocol

Supports HTTP/1/2/3.

### Security headers

Adds:

- `Strict-Transport-Security` (without pre-loading or sub-domain scope)
- `Content-Security-Policy` (configured by the `cloudfront_csp` module variable)
- `X-Content-Type-Options` (set as enabled)
- `X-Frame-Options` (set as disabled)
- `Referrer-Policy` (configured as 'no-referrer-when-downgrade')

Removes:

- `Server` origin header

> [!NOTE]
> As of December 2025:
> - this configuration scores an 'A' rating on the [Security Headers](https://securityheaders.com) website
> - the *Permissions Policy* header is not set, as there isn't a straightforward 'deny all' option

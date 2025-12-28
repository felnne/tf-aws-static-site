terraform {
  required_version = "~> 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.27"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# Alias for use with resources or data-sources that require the 'us-east-1' region,
# which is used as a control region by AWS for some services.
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

module "example" {
  source = "./modules/static-site"

  providers = {
    aws.us-east-1 = aws.us-east-1
  }

  bucket_name        = "example.com"
  route53_zone_id    = "..."
  cloudfront_comment = "Example.com"

  tags = {
    Name         = "example"
    X-Project    = "Example Service"
    X-Managed-By = "Terraform"
  }
}

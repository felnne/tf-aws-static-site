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

# Alias for resources that require the 'us-east-1' region, which is used as a control region by AWS for some services.
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

data "terraform_remote_state" "BAS-CORE-DOMAINS" {
  # https://gitlab.data.bas.ac.uk/WSF/bas-core-domains
  backend = "s3"

  config = {
    bucket = "bas-terraform-remote-state-prod"
    key    = "v2/BAS-CORE-DOMAINS/terraform.tfstate"
    region = "eu-west-1"
  }
}

module "example" {
  source = "git::https://github.com/felnne/tf-aws-static-site.git?ref=v0.5.0"

  providers = {
    aws.us-east-1 = aws.us-east-1
  }

  site_name                    = "example.web.bas.ac.uk"
  route53_zone_id              = data.terraform_remote_state.BAS-CORE-DOMAINS.outputs.WEB-BAS-AC-UK-ID
  cloudfront_min_proto_version = "TLSv1.2_2025"
  cloudfront_comment           = "Example (Production)"

  tags = {
    Name         = "example"
    X-Project    = "Example Service"
    X-Managed-By = "Terraform"
  }
}

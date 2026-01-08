resource "random_password" "referer_secret" {
  length  = 64
  special = false
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.bucket

  depends_on = [
    aws_s3_bucket_public_access_block.this
  ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.this.arn}/*"
        Condition = {
          StringEquals = {
            "aws:Referer" = random_password.referer_secret.result
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_website_configuration" "this" {
  bucket = aws_s3_bucket.this.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_acm_certificate" "this" {
  provider          = aws.us-east-1
  domain_name       = var.bucket_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_route53_record" "acm" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "this" {
  provider = aws.us-east-1

  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.acm : record.fqdn]
}

resource "aws_cloudfront_response_headers_policy" "this" {
  name = "${replace(var.bucket_name, ".", "_")}_headers"

  security_headers_config {
    strict_transport_security {
      override                   = true
      access_control_max_age_sec = 63072000
      include_subdomains         = false
      preload                    = false
    }

    content_security_policy {
      override                = true
      content_security_policy = var.cloudfront_csp
    }

    content_type_options {
      override = true
    }

    frame_options {
      override     = true
      frame_option = "DENY"
    }

    referrer_policy {
      override        = true
      referrer_policy = "no-referrer-when-downgrade"
    }
  }

  dynamic "cors_config" {
    for_each = var.cloudfront_enable_cors ? [1] : []
    content {
      access_control_allow_credentials = false
      access_control_allow_headers {
        items = ["*"]
      }
      access_control_allow_methods {
        items = ["GET", "HEAD", "OPTIONS"]
      }
      access_control_allow_origins {
        items = ["*"]
      }
      access_control_max_age_sec = 86400
      origin_override            = true
    }
  }

  remove_headers_config {
    items {
      header = "Server"
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = var.cloudfront_comment
  http_version        = "http2and3"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  aliases             = [var.bucket_name]

  origin {
    domain_name = aws_s3_bucket_website_configuration.this.website_endpoint
    origin_id   = "S3_${var.bucket_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443 # required though not used due to origin_protocol_policy
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"] # required though not used due to origin_protocol_policy
    }

    custom_header {
      name  = "Referer"
      value = random_password.referer_secret.result
    }
  }

  default_cache_behavior {
    target_origin_id           = "S3_${var.bucket_name}"
    cache_policy_id            = var.cloudfront_enable_default_caching ? "658327ea-f89d-4fab-a63d-7e88639e58f6" : "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingOptimized or CachingDisabled
    origin_request_policy_id   = "acba4595-bd28-49b8-b9fe-13317c0390fa"                                                                                  # UserAgentRefererHeaders
    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.3_2025"
    acm_certificate_arn      = aws_acm_certificate_validation.this.certificate_arn
  }
}

resource "aws_route53_record" "this" {
  zone_id = var.route53_zone_id
  name    = split(".", var.bucket_name)[0]
  type    = "CNAME"
  ttl     = 300
  records = [aws_cloudfront_distribution.this.domain_name]
}

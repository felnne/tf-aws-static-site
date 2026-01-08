variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "bucket_name" {
  description = "Name of the S3 bucket in the form of a domain name"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 zone ID corresponding to the domain in bucket_name"
  type        = string
}

variable "cloudfront_comment" {
  description = "Comment for the CloudFront distribution"
  type        = string
}

variable "cloudfront_csp" {
  description = "Content Security Policy for CloudFront distribution"
  type        = string
  default     = "default-src 'self';"
}

variable "cloudfront_enable_cors" {
  description = "Enable CORS headers for CloudFront distribution"
  type        = bool
  default     = true
}

variable "cloudfront_enable_default_caching" {
  description = "Enable S3 optimised caching for CloudFront distribution content"
  type        = bool
  default     = false
}

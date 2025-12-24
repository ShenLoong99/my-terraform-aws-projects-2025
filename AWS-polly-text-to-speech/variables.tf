variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "AWS-Polly-TTS"
    Environment = "Demo"
    Owner       = "ShenLoong"
  }
}

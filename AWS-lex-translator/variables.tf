variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "The name of the project for resource naming"
  type        = string
  default     = "lex-translator-bot"
}
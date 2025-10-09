variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "aws_profile" {
  type    = string
  default = null
}

variable "project_name" {
  type    = string
  default = "ts-api-sfn"
}

variable "lambda_build_dir" {
  type    = string
  default = "../build/lambda"
  # relative to ./terraform
}

variable "lambda_memory_mb" {
  type    = number
  default = 256
}

variable "lambda_timeout_s" {
  type    = number
  default = 10
}

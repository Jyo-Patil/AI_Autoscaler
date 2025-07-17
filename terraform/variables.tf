

variable "az" {
  type    = string
  default = "us-east-1a"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

# Tag (image tag in ECR) to deploy in Lambda
variable "lambda_image_tag" {
  type    = string
  default = "latest"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "az" {
  type    = string
  default = "us-east-1a"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

# Tag used in your CI/CD workflow when you push Docker image.
variable "lambda_image_tag" {
  type    = string
  default = "latest"
}

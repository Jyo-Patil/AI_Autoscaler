variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for Auto Scaling Group"
  default     = "t2.micro"
}

variable "lambda_image_uri" {
  description = "ECR image URI for Lambda"
  type        = string
}

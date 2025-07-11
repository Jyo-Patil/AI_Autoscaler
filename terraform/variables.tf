variable "aws_region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "subnet_ids" {
  type = list(string)
  description = "List of subnet IDs where to launch instances"
}

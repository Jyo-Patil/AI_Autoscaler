############################################
# TERRAFORM + PROVIDER
############################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}


############################################
# NETWORKING (VPC + PUBLIC SUBNET)
############################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = { Name = "predictive-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "predictive-igw" }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.az # make configurable
  map_public_ip_on_launch = true

  tags = { Name = "predictive-public-subnet" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "predictive-public-rt" }
}

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


############################################
# EC2 LAUNCH TEMPLATE + ASG
############################################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_launch_template" "webapp_lt" {
  name_prefix   = "webapp-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd stress
    systemctl start httpd
    systemctl enable httpd
    echo "Hello from Predictive Auto-Scaler" > /var/www/html/index.html
  EOF
  )
}

resource "aws_autoscaling_group" "webapp_asg" {
  name                      = "predictive-asg"
  desired_capacity          = 1
  max_size                  = 3
  min_size                  = 1
  vpc_zone_identifier       = [aws_subnet.public_subnet.id]
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.webapp_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "predictive-asg-instance"
    propagate_at_launch = true
  }
}


############################################
# IAM FOR LAMBDA
############################################

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "predictive-scaler-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

# Logging to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow scaling ASG
resource "aws_iam_role_policy_attachment" "lambda_asg" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
}

# Read metrics from CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_cloudwatch" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}


############################################
# ECR REPOSITORY FOR LAMBDA IMAGE
############################################

resource "aws_ecr_repository" "predictive_repo" {
  name = "predictive-autoscaler"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "predictive-autoscaler-repo" }
}


############################################
# LAMBDA (CONTAINER IMAGE)
############################################

# NOTE: You must push an image (tag: latest by default) before apply succeeds,
# or apply once to create infra, push the image, then 'terraform apply' again.

resource "aws_lambda_function" "predictive_scaler" {
  function_name = "predictive_scaler"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"

  # default to latest tag; override via var if needed
  image_uri = "${aws_ecr_repository.predictive_repo.repository_url}:${var.lambda_image_tag}"

  timeout = 60

  environment {
    variables = {
      ASG_NAME = aws_autoscaling_group.webapp_asg.name
      AWS_REGION = var.aws_region
    }
  }
}


############################################
# EVENTBRIDGE SCHEDULE → LAMBDA
############################################

resource "aws_cloudwatch_event_rule" "ten_minute_schedule" {
  name                = "predictive-scaler-schedule"
  schedule_expression = "rate(10 minutes)"
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.predictive_scaler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ten_minute_schedule.arn
}

resource "aws_cloudwatch_event_target" "target" {
  rule      = aws_cloudwatch_event_rule.ten_minute_schedule.name
  target_id = "predictive-scaler-lambda"
  arn       = aws_lambda_function.predictive_scaler.arn
}

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

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "predictive-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "predictive-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "predictive-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "predictive-public-rt"
  }
}

# Associate Subnet with Route Table
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Launch Template
resource "aws_launch_template" "webapp_lt" {
  name_prefix   = "webapp-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  user_data = base64encode(<<EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "Hello from Predictive Auto-Scaler" > /var/www/html/index.html
  EOF
  )
}

# Auto Scaling Group
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

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "predictive-scaler-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_asg" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

# EventBridge Rule
resource "aws_cloudwatch_event_rule" "ten_minute_schedule" {
  name                = "predictive-scaler-schedule"
  schedule_expression = "rate(10 minutes)"
}

# Lambda Function
resource "aws_lambda_function" "predictive_scaler" {
  function_name    = "predictive_scaler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "predictive_scaler.lambda_handler"
  runtime          = "python3.10"
  timeout          = 60
  source_code_hash = filebase64sha256("${path.module}/../lambda.zip")
  filename         = "${path.module}/../lambda.zip"
  environment {
    variables = {
      ASG_NAME = aws_autoscaling_group.webapp_asg.name
    }
  }
}

# Lambda Permissions
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.predictive_scaler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ten_minute_schedule.arn
}

# EventBridge → Lambda target
resource "aws_cloudwatch_event_target" "target" {
  rule      = aws_cloudwatch_event_rule.ten_minute_schedule.name
  target_id = "predictive-scaler-lambda"
  arn       = aws_lambda_function.predictive_scaler.arn
}


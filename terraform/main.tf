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

# Launch template for EC2 instances
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

# Find Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "webapp_asg" {
  name                      = "predictive-asg"
  desired_capacity          = 1
  max_size                  = 3
  min_size                  = 1
  vpc_zone_identifier       = var.subnet_ids
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

# IAM role for Lambda
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

# EventBridge rule to run every 10 minutes
resource "aws_cloudwatch_event_rule" "ten_minute_schedule" {
  name                = "predictive-scaler-schedule"
  schedule_expression = "rate(10 minutes)"
}

# Permission for EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.predictive_scaler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ten_minute_schedule.arn
}

# Connect EventBridge to Lambda
resource "aws_cloudwatch_event_target" "target" {
  rule      = aws_cloudwatch_event_rule.ten_minute_schedule.name
  target_id = "predictive-scaler-lambda"
  arn       = aws_lambda_function.predictive_scaler.arn
}

# Lambda function
resource "aws_lambda_function" "predictive_scaler" {
  filename         = "../lambda/lambda.zip"
  function_name    = "predictive_scaler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "predictive_scaler.lambda_handler"
  runtime          = "python3.10"
  timeout          = 60
  source_code_hash = filebase64sha256("../lambda/lambda.zip")

  environment {
    variables = {
      ASG_NAME = aws_autoscaling_group.webapp_asg.name
    }
  }
}

output "asg_name" {
  value = aws_autoscaling_group.webapp_asg.name
}

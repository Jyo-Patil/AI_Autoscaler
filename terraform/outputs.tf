output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public_subnet.id
}

output "asg_name" {
  value = aws_autoscaling_group.webapp_asg.name
}

output "lambda_function_name" {
  value = aws_lambda_function.predictive_scaler.function_name
}

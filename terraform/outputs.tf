output "lambda_function_name" {
  value = aws_lambda_function.predictive_scaler.function_name
}

output "predictive_repo_url" {
  description = "The URI of the ECR repository for the Lambda image"
  value       = aws_ecr_repository.predictive_repo.repository_url
}
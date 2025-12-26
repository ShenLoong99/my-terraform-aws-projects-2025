output "lambda_function_arn" {
  description = "The ARN of the Lambda function to be used in Lex fulfillment"
  value       = aws_lambda_function.translator_lambda.arn
}

output "iam_role_arn" {
  description = "The ARN of the IAM role used by the Lambda"
  value       = aws_iam_role.lambda_exec_role.arn
}
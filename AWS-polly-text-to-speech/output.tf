output "input_bucket_name" {
  description = "S3 bucket for uploading text files"
  value       = aws_s3_bucket.input_bucket.bucket
}

output "output_bucket_name" {
  description = "S3 bucket where MP3 files are stored"
  value       = aws_s3_bucket.output_bucket.bucket
}

output "lambda_function_name" {
  description = "Text-to-Speech Lambda function"
  value       = aws_lambda_function.polly_lambda.function_name
}

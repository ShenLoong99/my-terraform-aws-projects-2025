provider "aws" {
  region = var.aws_region

  # BEST PRACTICE: Default tags automatically apply to all supported resources.
  # This follows the DRY (Don't Repeat Yourself) principle.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "Dev"
      ManagedBy   = "Terraform"
      Owner       = "Sky"
    }
  }
}

# This archives the Python file into a ZIP before deployment
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda_function.py"
  output_path = "${path.module}/lambda/lambda_function.zip"
}

# --- IAM Role for Lambda ---
resource "aws_iam_role" "lambda_exec_role" {
  name = "lex_translator_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# --- Permissions: CloudWatch Logs & Amazon Translate ---
resource "aws_iam_policy" "lambda_logging_translate" {
  name        = "${var.project_name}-policy" # Use variable for naming consistency [cite: 9]
  description = "Allows Lambda to log, translate text, and detect languages"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        # BEST PRACTICE: Restrict logs to the specific ARN of your managed Log Group
        Resource = "${aws_cloudwatch_log_group.lambda_logs.arn}:*"
      },
      {
        Effect = "Allow",
        Action = [
          "translate:TranslateText",
          "comprehend:DetectDominantLanguage"
        ],
        Resource = "*" # Translate is a global service and often requires "*"
      }
    ]
  })
}

# --- Attach IAM Policy to Role ---
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_logging_translate.arn
}

# --- Lambda Function ---
resource "aws_lambda_function" "translator_lambda" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "LexTranslationHandler"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  # 1. TIMEOUT (Best Practice: Short as possible)
  # Default is 3s. Translate API usually takes < 1s. 
  # Set to 10s to allow for network jitter without wasting money on hang-ups.
  timeout = 10

  # 2. MEMORY (Best Practice: Right-size for the task)
  # Default is 128MB. Since we only use boto3 and small JSON strings, 
  # 128MB is sufficient. Increasing this also increases CPU power.
  memory_size = 128

  # Explicit dependency ensures the log group exists before the Lambda tries to log
  depends_on = [aws_cloudwatch_log_group.lambda_logs]

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tags = {
    Name = "LexTranslatorBackend"
  }
}

# --- Lex Permission to Invoke Lambda ---
resource "aws_lambda_permission" "allow_lex" {
  statement_id  = "AllowExecutionFromLex"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.translator_lambda.function_name
  principal     = "lex.amazonaws.com"
}

# BEST PRACTICE: Explicitly define the Log Group. 
# If you don't, Lambda creates one automatically that Terraform won't "own," 
# meaning it stays in your account after 'terraform destroy'.
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/LexTranslationHandler"
  retention_in_days = 7 # Automatically deletes individual log streams after 7 days

  # Since skip_destroy defaults to false, this resource (and all logs inside)
  # will be PERMANENTLY DELETED when you run 'terraform destroy'.
  skip_destroy = false

  # You can add resource-specific tags that merge with default tags
  tags = {
    Component = "Logging"
  }
}
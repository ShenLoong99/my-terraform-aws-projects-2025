# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

// S3 Bucket (Image Storage)
resource "aws_s3_bucket" "images_bucket" {
  bucket = "${var.project_name}-images-bucket-${random_id.bucket_id.hex}"
  // empty bucket and destroy even if it has objects
  force_destroy = true

  tags = {
    Name    = "${var.project_name}-bucket"
    Project = var.project_name
  }
}

resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket_lifecycle_configuration" "images_bucket_lifecycle" {
  bucket = aws_s3_bucket.images_bucket.id

  rule {
    id     = "cleanup-old-files"
    status = "Enabled"

    # This empty filter tells AWS the rule applies to the WHOLE bucket
    filter {}

    # Example 1: Permanently delete objects after 30 days
    expiration {
      days = 30
    }

    # Example 2: If you enabled versioning, delete non-current versions after 7 days
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}
///////////////////////////////////////////////////////////////////////////////

// Public access blocked
resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.images_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

// IAM User + Rekognition Permissions
// IAM Policy (Least Privilege)
resource "aws_iam_policy" "rekognition_policy" {
  name        = "${var.project_name}-policy"
  description = "Allow Rekognition label detection and S3 read access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rekognition:DetectLabels"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.images_bucket.arn,
          "${aws_s3_bucket.images_bucket.arn}/*"
        ]
      }
    ]
  })

  # Added tags for IAM Policy
  tags = {
    Name    = "${var.project_name}-policy"
    Project = var.project_name
  }
}

// IAM User
resource "aws_iam_user" "rekognition_user" {
  name = "${var.project_name}-user"

  tags = {
    Name    = "${var.project_name}-user"
    Project = var.project_name
  }
}

// Attach Policy to User
resource "aws_iam_user_policy_attachment" "attach_policy" {
  user       = aws_iam_user.rekognition_user.name
  policy_arn = aws_iam_policy.rekognition_policy.arn
}

// Access Keys (For AWS CLI & Python)
resource "aws_iam_access_key" "rekognition_access_key" {
  user = aws_iam_user.rekognition_user.name
}
///////////////////////////////////////////////////////////////////////////////
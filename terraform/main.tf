locals {
  company = "swisscom"
}

locals {
  bucket_name = "${local.company}-bucket-1"
  region      = "eu-central-1"
}

resource "aws_kms_key" "s3_kms" {
  description             = "KMS key is used to encrypt bucket objects"
  deletion_window_in_days = 7
}

module "s3_bucket" {
  source                                   = "terraform-aws-modules/s3-bucket/aws"
  bucket                                   = local.bucket_name
  force_destroy                            = true
  acl                                      = "private"
  control_object_ownership                 = true
  object_ownership                         = "BucketOwnerEnforced"

  # Bucket policies
  attach_policy                            = true
  attach_deny_insecure_transport_policy    = true
  attach_require_latest_tls_policy         = true
  attach_deny_incorrect_encryption_headers = true
  attach_deny_incorrect_kms_key_sse        = true
  allowed_kms_key_arn                      = aws_kms_key.s3_kms.arn
  attach_deny_unencrypted_object_uploads   = true

  # S3 bucket-level Public Access Block configuration (by default now AWS has made this default as true for S3 bucket-level block public access)
  block_public_acls                        = true
  block_public_policy                      = true
  ignore_public_acls                       = true
  restrict_public_buckets                  = true

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.s3_kms.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = {
    Environment = "dev"
  }
}

module "lambda_function1" {
  source        = "terraform-aws-modules/lambda/aws"
  version       = "~> 3.0"

  function_name = "${local.company}-lambda1"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  source_path   = "./lambda"

  tags = {
    Environment = "dev"
  }
}

module "step_function" {
  source = "terraform-aws-modules/step-functions/aws"

  name       = "${local.company}-sfn"
  definition = <<EOF
{
  "Comment":"Put s3 object metadata into DDB",
  "StartAt":"Put Message Into DynamoDB",
  "States":{
    "Put Message Into DynamoDB":{
      "End": true,
      "Type":"Task",
      "Resource":"arn:aws:states:::dynamodb:putItem",
      "Parameters":{
        "TableName":"swisscom-ddb-1",
        "Item":{
          "FileName":{
            "S.$":"$.FileName"
          }
        }
      }
    }
  }
}
EOF

  service_integrations = {
    dynamodb = {
      dynamodb = ["arn:aws:dynamodb:eu-central-1:000000000000:table/swisscom-ddb-1"]
    }
  }
  type = "STANDARD"

  attach_policy_statements = true
  policy_statements = {
    dynamodb = {
      effect    = "Allow",
      actions   = ["dynamodb:BatchWriteItem"],
      resources = ["arn:aws:dynamodb:eu-central-1:000000000000:table/swisscom-ddb-1"]
    }
  }
  tags = {
    Environment = "dev"
  }
}

module "dynamodb_table" {
  source = "terraform-aws-modules/dynamodb-table/aws"

  name                        = "${local.company}-ddb-1"
  hash_key                    = "FileName"
  table_class                 = "STANDARD"
  deletion_protection_enabled = false

  attributes = [
    {
      name = "FileName"
      type = "S"
    }
  ]
}

module "all_notifications" {
  source = "./.terraform/modules/s3_bucket/modules/notification"

  bucket = module.s3_bucket.s3_bucket_id


  lambda_notifications = {
    lambda1 = {
      function_arn  = module.lambda_function1.lambda_function_arn
      function_name = module.lambda_function1.lambda_function_name
      events        = ["s3:ObjectCreated:Put"]
    }
  }
}
locals {
  company = "swisscom"
}

locals {
  bucket_name = "${local.company}-bucket-1"
  region      = "eu-central-1"
}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket        = local.bucket_name
  force_destroy = true
  acl    = "private"
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  versioning = {
    enabled = true
  }
}

module "lambda_function1" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 3.0"

  function_name = "${local.company}-lambda1"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  source_path = "./lambda"
}

module "step_function" {
  source = "terraform-aws-modules/step-functions/aws"

  name       = "${local.company}-sfn"
  definition = <<EOF
{
  "Comment":"A Hello World example of the Amazon States Language using Pass states",
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
    Module = "my"
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
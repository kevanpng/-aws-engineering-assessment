locals {
  company = "swisscom"
}

locals {
  bucket_name = "${local.company}-bucket-1"
  region      = "eu-central-1"
}

#resource "random_pet" "this" {
#  length = 2
#}

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

#############################################
# Using packaged function from Lambda module
#############################################

locals {
  package_url = "https://raw.githubusercontent.com/terraform-aws-modules/terraform-aws-lambda/master/examples/fixtures/python3.8-zip/existing_package.zip"
  downloaded  = "downloaded_package_${md5(local.package_url)}.zip"
}

#resource "null_resource" "download_package" {
#  triggers = {
#    downloaded = local.downloaded
#  }
#
#  provisioner "local-exec" {
#    command = "curl -L -o ${local.downloaded} ${local.package_url}"
#  }
#}

module "lambda_function1" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 3.0"

  function_name = "${local.company}-lambda1"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  source_path = "./lambda"

#  create_package         = false
#  local_existing_package = local.downloaded
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
#  range_key                   = "title"
  table_class                 = "STANDARD"
  deletion_protection_enabled = false

  attributes = [
    {
      name = "FileName"
      type = "S"
    }
  ]
}


#
#module "lambda_function2" {
#  source  = "terraform-aws-modules/lambda/aws"
#  version = "~> 3.0"
#
#  function_name = "${local.company}-lambda2"
#  handler       = "index.lambda_handler"
#  runtime       = "python3.8"
#
#  create_package         = false
#  local_existing_package = local.downloaded
#}
#
#module "sns_topic1" {
#  source  = "terraform-aws-modules/sns/aws"
#  version = "~> 3.0"
#
#  name_prefix = "${local.company}-2"
#}
#
#module "sns_topic2" {
#  source  = "terraform-aws-modules/sns/aws"
#  version = "~> 3.0"
#
#  name_prefix = "${local.company}-2"
#}
#
#resource "aws_sqs_queue" "this" {
#  count = 2
#  name  = "${local.company}-${count.index}"
#}
#
## SQS policy created outside of the module
#data "aws_iam_policy_document" "sqs_external" {
#  statement {
#    effect  = "Allow"
#    actions = ["sqs:SendMessage"]
#
#    principals {
#      type        = "Service"
#      identifiers = ["s3.amazonaws.com"]
#    }
#
#    resources = [aws_sqs_queue.this[0].arn]
#  }
#}
#
#resource "aws_sqs_queue_policy" "allow_external" {
#  queue_url = aws_sqs_queue.this[0].id
#  policy    = data.aws_iam_policy_document.sqs_external.json
#}
#
module "all_notifications" {
#  source = "../terraform-aws-modules/s3-bucket/aws/modules/notification"
  source = "./.terraform/modules/s3_bucket/modules/notification"

  bucket = module.s3_bucket.s3_bucket_id

#  eventbridge = true

  # Common error - Error putting S3 notification configuration: InvalidArgument: Configuration is ambiguously defined. Cannot have overlapping suffixes in two rules if the prefixes are overlapping for the same event type.

  lambda_notifications = {
    lambda1 = {
      function_arn  = module.lambda_function1.lambda_function_arn
      function_name = module.lambda_function1.lambda_function_name
      events        = ["s3:ObjectCreated:Put"]
#      filter_prefix = "prefix/"
#      filter_suffix = ".json"
    }
  }

#  policy = false
}
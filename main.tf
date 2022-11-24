terraform {
  cloud {
    organization = "nazo6"

    workspaces {
      name = "axum-lambda-test"
    }
  }
}

locals {
  lambda_local_path     = "${path.root}/"
  lambda_bin_name       = "bootstrap"
  lambda_bin_local_path = "${local.lambda_local_path}/target/lambda/lambda/${local.lambda_bin_name}"
  lambda_zip_local_path = "${local.lambda_bin_local_path}.zip"
}

provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_iam_role" "iam_axum_lambda_test" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "this" {
  function_name = "axum_lambda_test"
  description   = "Rust lambda sample."
  role          = aws_iam_role.iam_axum_lambda_test.arn

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  runtime       = "provided.al2"
  architectures = "arm64"
}

resource "null_resource" "rust_build" {
  triggers = {
    code_diff = join("", [
      for file in fileset(local.lambda_local_path, "**.rs")
      : filebase64("${local.lambda_local_path}/${file}")
    ])
  }

  provisioner "local-exec" {
    working_dir = local.lambda_local_path
    command     = "cargo lambda build --release --arm64"
  }
}

data "archive_file" "zip" {
  type        = "zip"
  source_file = local.lambda_bin_local_path
  output_path = local.lambda_zip_local_path

  depends_on = [
    null_resource.rust_build
  ]
}

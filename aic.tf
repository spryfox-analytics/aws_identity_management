data "aws_ssoadmin_instances" "identity_stores" {}

locals {
  group_name_prefix = "${var.customer_name}${var.project_name == "" ? "" : " "}${var.project_name}"
}

resource "aws_ssoadmin_permission_set" "view" {
  count            = var.project_name == "" ? 1 : 0
  name             = "view"
  description      = "Viewer access to AWS account"
  instance_arn     = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  relay_state      = "https://s3.console.aws.amazon.com/s3/home?region=${var.aws_region}#"
  session_duration = "PT2H"
}

resource "aws_ssoadmin_managed_policy_attachment" "view" {
  count              = var.project_name == "" ? 1 : 0
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.view[0].arn
}

data "aws_iam_policy_document" "athena_querying" {
  count = var.project_name == "" ? 1 : 0
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["athena:*"]
  }
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:CreateTable",
      "glue:GetTable",
      "glue:GetTables",
      "glue:BatchCreatePartition",
      "glue:CreatePartition",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:BatchGetPartition",
    ]
  }
  statement {
    effect    = "Allow"
    resources = [
      "arn:aws:s3:::luscii-athena-query-*",
      "arn:aws:s3:::rh-athena-query-*"
    ]
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:AbortMultipartUpload",
      "s3:PutObject",
      "s3:ListMultipartUploadParts"
    ]
  }
  statement {
    effect  = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "view_athena_extension" {
  count              = var.project_name == "" ? 1 : 0
  inline_policy      = data.aws_iam_policy_document.athena_querying[0].json
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.view[0].arn
}

data "external" "view_permission_set_arn" {
  program = ["bash", "${path.module}/permission_set_arn_retriever.sh", "view", var.aws_region]
}

resource "aws_ssoadmin_permission_set" "development" {
  count            = var.project_name == "" ? 1 : 0
  name             = "dev"
  description      = "Development access to AWS account"
  instance_arn     = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  relay_state      = "https://s3.console.aws.amazon.com/s3/home?region=${var.aws_region}#"
  session_duration = "PT1H"
}

resource "aws_ssoadmin_managed_policy_attachment" "development" {
  count              = var.project_name == "" ? 1 : 0
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.development[0].arn
}

data "external" "development_permission_set_arn" {
  program = ["bash", "${path.module}/permission_set_arn_retriever.sh", "dev", var.aws_region]
}

resource "aws_ssoadmin_permission_set" "administration" {
  count            = var.project_name == "" ? 1 : 0
  name             = "admin"
  description      = "Administration access to AWS account"
  instance_arn     = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  relay_state      = "https://s3.console.aws.amazon.com/s3/home?region=${var.aws_region}#"
  session_duration = "PT1H"
}

resource "aws_ssoadmin_managed_policy_attachment" "administration" {
  count              = var.project_name == "" ? 1 : 0
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.administration[0].arn
}

data "external" "administration_permission_set_arn" {
  program = ["bash", "${path.module}/permission_set_arn_retriever.sh", "admin", var.aws_region]
}

resource "aws_ssoadmin_permission_set" "support" {
  count            = var.project_name == "" ? 1 : 0
  name             = "support"
  description      = "Support access to AWS account"
  instance_arn     = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  relay_state      = "https://s3.console.aws.amazon.com/s3/home?region=${var.aws_region}#"
  session_duration = "PT1H"
}

resource "aws_ssoadmin_managed_policy_attachment" "support" {
  count              = var.project_name == "" ? 1 : 0
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/AWSSupportAccess"
  permission_set_arn = aws_ssoadmin_permission_set.support[0].arn
}

data "external" "support_permission_set_arn" {
  program = ["bash", "${path.module}/permission_set_arn_retriever.sh", "support", var.aws_region]
}

# Operational read: what is needed to follow and debug a running system (logs, metrics, traces, pipelines,
# builds, executions and the configuration of the services), on top of ViewOnlyAccess. No reading of
# object contents, table items, secrets or parameters.
locals {
  operational_read_actions = {
    CloudWatchLogsRead = [
      "logs:Describe*",
      "logs:FilterLogEvents",
      "logs:Get*",
      "logs:GetQueryResults",
      "logs:List*",
      "logs:StartLiveTail",
      "logs:StartQuery",
      "logs:StopQuery",
    ]
    CostAndBudgetsRead = [
      "budgets:Describe*",
      "budgets:View*",
      "ce:Describe*",
      "ce:Get*",
      "ce:List*",
      "cost-optimization-hub:Get*",
      "cost-optimization-hub:List*",
      "billing:Get*",
      "billing:List*",
      "freetier:Get*",
    ]
    CloudWatchMetricsAndAlarmsRead = [
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
    ]
    PipelinesAndBuildsRead = [
      "codebuild:BatchGet*",
      "codebuild:List*",
      "codepipeline:Get*",
      "codepipeline:List*",
      "codeconnections:GetConnection",
      "codeconnections:ListConnections",
      "codestar-connections:GetConnection",
      "codestar-connections:ListConnections",
    ]
    CloudTrailEventHistoryRead = [
      "cloudtrail:LookupEvents",
    ]
    XRayRead = [
      "xray:BatchGet*",
      "xray:Get*",
      "xray:List*",
    ]
    CloudFrontRead = [
      "cloudfront:Get*",
      "cloudfront:List*",
    ]
    # No lambda:GetFunction and no lambda:GetLayerVersion, they return download links for the code.
    LambdaConfigurationRead = [
      "lambda:GetAccountSettings",
      "lambda:GetAlias",
      "lambda:GetEventSourceMapping",
      "lambda:GetFunctionConcurrency",
      "lambda:GetFunctionConfiguration",
      "lambda:GetFunctionEventInvokeConfig",
      "lambda:GetFunctionUrlConfig",
      "lambda:GetPolicy",
      "lambda:GetProvisionedConcurrencyConfig",
      "lambda:List*",
    ]
    DynamoDbConfigurationRead = [
      "dynamodb:Describe*",
      "dynamodb:List*",
    ]
    S3BucketConfigurationAndListingRead = [
      "s3:GetBucket*",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:ListAllMyBuckets",
      "s3:ListBucket",
    ]
    StepFunctionsRead = [
      "states:Describe*",
      "states:GetExecutionHistory",
      "states:List*",
    ]
    EcsRead = [
      "ecs:Describe*",
      "ecs:List*",
    ]
    EventBridgeAndSchedulerRead = [
      "events:Describe*",
      "events:List*",
      "scheduler:Get*",
      "scheduler:List*",
    ]
  }

  pipeline_run_actions = [
    "codepipeline:RetryStageExecution",
    "codepipeline:StartPipelineExecution",
    "codepipeline:StopPipelineExecution",
  ]
}

data "aws_iam_policy_document" "operational_read" {
  dynamic "statement" {
    for_each = local.operational_read_actions
    content {
      sid       = statement.key
      effect    = "Allow"
      actions   = statement.value
      resources = ["*"]
    }
  }

  # API keys are secrets: GET on /apikeys can return their values.
  statement {
    sid     = "ApiGatewayReadWithoutApiKeys"
    effect  = "Allow"
    actions = ["apigateway:GET"]
    not_resources = [
      "arn:aws:apigateway:*::/apikeys",
      "arn:aws:apigateway:*::/apikeys/*",
    ]
  }
}

data "aws_iam_policy_document" "developer" {
  source_policy_documents = [data.aws_iam_policy_document.operational_read.json]

  dynamic "statement" {
    for_each = length(var.development_account_numbers) > 0 ? [1] : []
    content {
      sid       = "EverythingInTheDevelopmentAccounts"
      effect    = "Allow"
      actions   = ["*"]
      resources = ["*"]
      condition {
        test     = "StringEquals"
        variable = "aws:PrincipalAccount"
        values   = var.development_account_numbers
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.pipeline_account_numbers) > 0 ? [1] : []
    content {
      sid       = "RunAndApproveThePipelinesInThePipelineAccounts"
      effect    = "Allow"
      actions   = concat(local.pipeline_run_actions, ["codepipeline:PutApprovalResult"])
      resources = ["*"]
      condition {
        test     = "StringEquals"
        variable = "aws:PrincipalAccount"
        values   = var.pipeline_account_numbers
      }
    }
  }
}

data "aws_iam_policy_document" "agent_developer" {
  source_policy_documents = [data.aws_iam_policy_document.operational_read.json]

  dynamic "statement" {
    for_each = length(local.agent_development_account_numbers) > 0 ? [1] : []
    content {
      sid       = "EverythingInTheAgentDevelopmentAccounts"
      effect    = "Allow"
      actions   = ["*"]
      resources = ["*"]
      condition {
        test     = "StringEquals"
        variable = "aws:PrincipalAccount"
        values   = local.agent_development_account_numbers
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.pipeline_account_numbers) > 0 ? [1] : []
    content {
      sid       = "RunThePipelinesInThePipelineAccounts"
      effect    = "Allow"
      actions   = local.pipeline_run_actions
      resources = ["*"]
      condition {
        test     = "StringEquals"
        variable = "aws:PrincipalAccount"
        values   = var.pipeline_account_numbers
      }
    }
  }

  # Approvals are for humans only.
  statement {
    sid       = "NoPipelineApprovals"
    effect    = "Deny"
    actions   = ["codepipeline:PutApprovalResult"]
    resources = ["*"]
  }

  # Long-lived credentials would let an agent act outside its role and hide its activity in CloudTrail.
  statement {
    sid    = "NoLongLivedCredentials"
    effect = "Deny"
    actions = [
      "iam:CreateAccessKey",
      "iam:CreateLoginProfile",
      "iam:CreateServiceSpecificCredential",
      "iam:CreateUser",
      "iam:UpdateLoginProfile",
      "iam:UploadSSHPublicKey",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "NoIdentityOrganisationOrAccountChanges"
    effect = "Deny"
    actions = [
      "sso:*",
      "sso-directory:*",
      "identitystore:Create*",
      "identitystore:Delete*",
      "identitystore:Update*",
      "organizations:Accept*",
      "organizations:Attach*",
      "organizations:Cancel*",
      "organizations:Close*",
      "organizations:Create*",
      "organizations:Decline*",
      "organizations:Delete*",
      "organizations:Deregister*",
      "organizations:Detach*",
      "organizations:Disable*",
      "organizations:Enable*",
      "organizations:Invite*",
      "organizations:Leave*",
      "organizations:Move*",
      "organizations:Put*",
      "organizations:Register*",
      "organizations:Remove*",
      "organizations:Tag*",
      "organizations:Untag*",
      "organizations:Update*",
      "account:Accept*",
      "account:Close*",
      "account:Delete*",
      "account:Disable*",
      "account:Enable*",
      "account:Put*",
      "account:Start*",
    ]
    resources = ["*"]
  }
}

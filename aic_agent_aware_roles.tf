# Role model for humans and AI agents (agent_aware_roles). Four permission sets next to view, dev, admin
# and support: Viewer and Developer for humans, AgentViewer and AgentDeveloper for AI agents. The agent
# roles appear in CloudTrail as AWSReservedSSO_Agent*, so every action of an agent can be told apart from
# the actions of a human. Agents may not approve pipelines, may not create long-lived credentials and get
# short sessions. The roles are created at customer level only, projects find them by name.

locals {
  agent_aware_roles_enabled         = var.project_name == "" && var.agent_aware_roles
  agent_development_account_numbers = var.agent_development_account_numbers != null ? var.agent_development_account_numbers : var.development_account_numbers

  agent_aware_permission_sets = {
    Viewer = {
      description      = "Viewer access for humans: configuration and operational read, no data or secrets"
      session_duration = "PT12H"
      inline_policy    = one(data.aws_iam_policy_document.operational_read[*].json)
    }
    AgentViewer = {
      description      = "Viewer access for AI agents: configuration and operational read, no data or secrets"
      session_duration = "PT1H"
      inline_policy    = one(data.aws_iam_policy_document.operational_read[*].json)
    }
    Developer = {
      description      = "Development access for humans: everything in the development accounts, running and approving pipelines"
      session_duration = "PT12H"
      inline_policy    = one(data.aws_iam_policy_document.developer[*].json)
    }
    AgentDeveloper = {
      description      = "Development access for AI agents: everything in the agent development accounts, running pipelines, no approvals"
      session_duration = "PT1H"
      inline_policy    = one(data.aws_iam_policy_document.agent_developer[*].json)
    }
  }

  # Projects look the permission sets up by name, but only when they assign them.
  agent_aware_permission_set_lookup = var.project_name != "" && length(var.role_viewers_account_numbers) + length(var.role_developers_account_numbers) > 0

  agent_aware_permission_set_arns = {
    for name in keys(local.agent_aware_permission_sets) : name => (
      var.project_name == ""
      ? try(aws_ssoadmin_permission_set.agent_aware[name].arn, null)
      : try(data.external.agent_aware_permission_set_arns[name].result.arn, null)
    )
  }
}

# Operational read: what is needed to follow and debug a running system (logs, metrics, traces, pipelines,
# builds, executions and the configuration of the services), on top of ViewOnlyAccess. No reading of
# object contents, table items, secrets or parameters.
data "aws_iam_policy_document" "operational_read" {
  count = local.agent_aware_roles_enabled ? 1 : 0

  statement {
    sid    = "CloudWatchLogsRead"
    effect = "Allow"
    actions = [
      "logs:Describe*",
      "logs:FilterLogEvents",
      "logs:Get*",
      "logs:GetQueryResults",
      "logs:List*",
      "logs:StartLiveTail",
      "logs:StartQuery",
      "logs:StopQuery",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchMetricsAndAlarmsRead"
    effect = "Allow"
    actions = [
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "PipelinesAndBuildsRead"
    effect = "Allow"
    actions = [
      "codebuild:BatchGet*",
      "codebuild:List*",
      "codepipeline:Get*",
      "codepipeline:List*",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "CloudTrailEventHistoryRead"
    effect    = "Allow"
    actions   = ["cloudtrail:LookupEvents"]
    resources = ["*"]
  }

  statement {
    sid    = "XRayRead"
    effect = "Allow"
    actions = [
      "xray:BatchGet*",
      "xray:Get*",
      "xray:List*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudFrontRead"
    effect = "Allow"
    actions = [
      "cloudfront:Get*",
      "cloudfront:List*",
    ]
    resources = ["*"]
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

  # No lambda:GetFunction and no lambda:GetLayerVersion, they return download links for the code.
  statement {
    sid    = "LambdaConfigurationRead"
    effect = "Allow"
    actions = [
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
    resources = ["*"]
  }

  statement {
    sid    = "DynamoDbConfigurationRead"
    effect = "Allow"
    actions = [
      "dynamodb:Describe*",
      "dynamodb:List*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3BucketConfigurationAndListingRead"
    effect = "Allow"
    actions = [
      "s3:GetBucket*",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:ListAllMyBuckets",
      "s3:ListBucket",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "StepFunctionsRead"
    effect = "Allow"
    actions = [
      "states:Describe*",
      "states:GetExecutionHistory",
      "states:List*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EcsRead"
    effect = "Allow"
    actions = [
      "ecs:Describe*",
      "ecs:List*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EventBridgeAndSchedulerRead"
    effect = "Allow"
    actions = [
      "events:Describe*",
      "events:List*",
      "scheduler:Get*",
      "scheduler:List*",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "developer" {
  count                   = local.agent_aware_roles_enabled ? 1 : 0
  source_policy_documents = [data.aws_iam_policy_document.operational_read[0].json]

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
      sid    = "RunAndApproveThePipelinesInThePipelineAccounts"
      effect = "Allow"
      actions = [
        "codepipeline:PutApprovalResult",
        "codepipeline:RetryStageExecution",
        "codepipeline:StartPipelineExecution",
        "codepipeline:StopPipelineExecution",
      ]
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
  count                   = local.agent_aware_roles_enabled ? 1 : 0
  source_policy_documents = [data.aws_iam_policy_document.operational_read[0].json]

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
      sid    = "RunThePipelinesInThePipelineAccounts"
      effect = "Allow"
      actions = [
        "codepipeline:RetryStageExecution",
        "codepipeline:StartPipelineExecution",
        "codepipeline:StopPipelineExecution",
      ]
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

resource "aws_ssoadmin_permission_set" "agent_aware" {
  for_each         = { for name, permission_set in local.agent_aware_permission_sets : name => permission_set if local.agent_aware_roles_enabled }
  name             = each.key
  description      = each.value.description
  instance_arn     = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  relay_state      = "https://s3.console.aws.amazon.com/s3/home?region=${var.aws_region}#"
  session_duration = each.value.session_duration
}

resource "aws_ssoadmin_managed_policy_attachment" "agent_aware" {
  for_each           = aws_ssoadmin_permission_set.agent_aware
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
  permission_set_arn = each.value.arn
}

resource "aws_ssoadmin_permission_set_inline_policy" "agent_aware" {
  for_each           = aws_ssoadmin_permission_set.agent_aware
  inline_policy      = local.agent_aware_permission_sets[each.key].inline_policy
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  permission_set_arn = each.value.arn
}

data "external" "agent_aware_permission_set_arns" {
  for_each = local.agent_aware_permission_set_lookup ? toset(keys(local.agent_aware_permission_sets)) : toset([])
  program  = ["bash", "${path.module}/permission_set_arn_retriever.sh", each.key, var.aws_region]
}

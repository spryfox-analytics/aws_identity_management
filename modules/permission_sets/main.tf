# The permission sets of the role model, created once per IAM Identity Center instance. Viewer and
# Developer are for humans, AgentViewer and AgentDeveloper for AI agents. Agent sessions appear in
# CloudTrail as AWSReservedSSO_Agent*, may not approve pipelines, may not create long-lived credentials
# and are short. Administrator is for humans only, for the exceptions that need full access (first
# setup, console-only tasks such as activating connections); it has no agent counterpart.

data "aws_ssoadmin_instances" "this" {}

locals {
  instance_arn                      = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  agent_development_account_numbers = var.agent_development_account_numbers != null ? var.agent_development_account_numbers : var.development_account_numbers

  permission_sets = {
    Viewer = {
      description      = "Viewer access for humans: configuration and operational read, no data or secrets"
      session_duration = var.session_duration_humans
      inline_policy    = data.aws_iam_policy_document.operational_read.json
    }
    AgentViewer = {
      description      = "Viewer access for AI agents: configuration and operational read, no data or secrets"
      session_duration = var.session_duration_agents
      inline_policy    = data.aws_iam_policy_document.operational_read.json
    }
    Developer = {
      description      = "Development access for humans: everything in the development accounts, running and approving pipelines"
      session_duration = var.session_duration_humans
      inline_policy    = data.aws_iam_policy_document.developer.json
    }
    AgentDeveloper = {
      description      = "Development access for AI agents: everything in the agent development accounts, running pipelines, no approvals"
      session_duration = var.session_duration_agents
      inline_policy    = data.aws_iam_policy_document.agent_developer.json
    }
  }

  administrator = {
    description      = "Administration access for humans, for the exceptions: AdministratorAccess, short sessions"
    session_duration = var.session_duration_administrators
  }
}

resource "aws_ssoadmin_permission_set" "this" {
  for_each = local.permission_sets

  name             = "${var.name_prefix}${each.key}"
  description      = each.value.description
  instance_arn     = local.instance_arn
  relay_state      = var.relay_state
  session_duration = each.value.session_duration
  tags             = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "view_only_access" {
  for_each = aws_ssoadmin_permission_set.this

  instance_arn       = local.instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
  permission_set_arn = each.value.arn
}

resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  for_each = aws_ssoadmin_permission_set.this

  instance_arn       = local.instance_arn
  inline_policy      = local.permission_sets[each.key].inline_policy
  permission_set_arn = each.value.arn
}

resource "aws_ssoadmin_permission_set" "administrator" {
  name             = "${var.name_prefix}Administrator"
  description      = local.administrator.description
  instance_arn     = local.instance_arn
  relay_state      = var.relay_state
  session_duration = local.administrator.session_duration
  tags             = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "administrator_access" {
  instance_arn       = local.instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn
}

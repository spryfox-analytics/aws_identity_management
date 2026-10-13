# Assigns the permission sets of the role model to the groups of a customer or project. The permission sets
# must exist (module permission_sets), the groups must exist in the identity store; both are only looked up.

data "aws_ssoadmin_instances" "this" {}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  roles_by_group = {
    Viewers        = ["Viewer", "AgentViewer"]
    Developers     = ["Viewer", "AgentViewer", "Developer", "AgentDeveloper"]
    Administrators = ["Administrator"]
  }

  account_numbers_by_group = {
    Viewers        = distinct(var.viewers_account_numbers)
    Developers     = distinct(var.developers_account_numbers)
    Administrators = distinct(var.administrators_account_numbers)
  }

  # Keys are "<group>/<account>/<role>".
  assignments = merge([
    for group, account_numbers in local.account_numbers_by_group : {
      for pair in setproduct(account_numbers, local.roles_by_group[group]) :
      "${group}/${pair[0]}/${pair[1]}" => { group = group, account_number = pair[0], role = pair[1] }
    }
  ]...)

  # Only what the assignments need is looked up.
  groups = toset([for assignment in values(local.assignments) : assignment.group])
  roles  = toset([for assignment in values(local.assignments) : assignment.role])
}

data "aws_ssoadmin_permission_set" "this" {
  for_each = local.roles

  instance_arn = local.instance_arn
  name         = var.permission_set_names[each.key]
}

data "aws_identitystore_group" "this" {
  for_each = local.groups

  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "${var.group_prefix} ${each.key}"
    }
  }
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = local.assignments

  instance_arn       = local.instance_arn
  permission_set_arn = data.aws_ssoadmin_permission_set.this[each.value.role].arn
  principal_id       = data.aws_identitystore_group.this[each.value.group].group_id
  principal_type     = "GROUP"
  target_id          = each.value.account_number
  target_type        = "AWS_ACCOUNT"
}

data "aws_identitystore_group" "role_viewers" {
  count             = length(var.role_viewers_account_numbers) == 0 ? 0 : 1
  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_stores.identity_store_ids)[0]
  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "${local.group_name_prefix} Viewers"
    }
  }
}

# Keys are "<account>/<permission set>", so they never clash with the assignments of the same group to
# the permission sets view and dev.
resource "aws_ssoadmin_account_assignment" "role_viewers" {
  for_each = {
    for pair in setproduct(distinct(var.role_viewers_account_numbers), ["Viewer", "AgentViewer"]) :
    "${pair[0]}/${pair[1]}" => { account_number = pair[0], permission_set = pair[1] }
  }
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  permission_set_arn = local.agent_aware_permission_set_arns[each.value.permission_set]
  principal_id       = data.aws_identitystore_group.role_viewers[0].group_id
  principal_type     = "GROUP"
  target_id          = each.value.account_number
  target_type        = "AWS_ACCOUNT"

  lifecycle {
    precondition {
      condition     = try(length(local.agent_aware_permission_set_arns[each.value.permission_set]) > 0, false)
      error_message = "Permission set ${each.value.permission_set} not found. Set agent_aware_roles = true at customer level and apply it before assigning the roles."
    }
  }
}

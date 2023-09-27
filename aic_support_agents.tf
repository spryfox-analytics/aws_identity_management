data "aws_identitystore_group" "support_agents" {
  count = length(var.support_agents_account_numbers) == 0 ? 0 : 1
  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_stores.identity_store_ids)[0]
  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "${local.group_name_prefix} Support Agents"
    }
  }
}

resource "aws_ssoadmin_account_assignment" "support_agents_support" {
  for_each = toset(var.support_agents_account_numbers)
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  permission_set_arn = var.project_name == "" ? aws_ssoadmin_permission_set.support[0].arn : data.external.support_permission_set_arn.result.arn
  principal_id   = data.aws_identitystore_group.support_agents[0].group_id
  principal_type = "GROUP"
  target_id   = each.key
  target_type = "AWS_ACCOUNT"
}

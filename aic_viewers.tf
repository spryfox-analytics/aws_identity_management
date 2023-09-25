data "aws_identitystore_group" "viewers" {
  count = length(var.viewers_account_numbers) == 0 ? 0 : 1
  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_stores.identity_store_ids)[0]
  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "${local.group_name_prefix} Viewers"
    }
  }
}

resource "aws_ssoadmin_account_assignment" "viewers_view" {
  for_each = toset(var.viewers_account_numbers)
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  permission_set_arn = var.project_name == "" ? aws_ssoadmin_permission_set.view[0].arn : data.external.view_permission_set_arn.result.arn
  principal_id   = data.aws_identitystore_group.viewers[0].group_id
  principal_type = "GROUP"
  target_id   = each.key
  target_type = "AWS_ACCOUNT"
}

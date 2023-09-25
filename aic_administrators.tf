data "aws_identitystore_group" "administrators" {
  count = length(var.administrators_account_numbers) == 0 ? 0 : 1
  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_stores.identity_store_ids)[0]
  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "${local.group_name_prefix} Administrators"
    }
  }
}

resource "aws_ssoadmin_account_assignment" "administrators_view" {
  for_each = toset(var.administrators_account_numbers)
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  permission_set_arn = var.project_name == "" ? aws_ssoadmin_permission_set.view[0].arn : data.external.view_permission_set_arn.result.arn
  principal_id   = data.aws_identitystore_group.administrators[0].group_id
  principal_type = "GROUP"
  target_id   = each.key
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "administrators_administration" {
  for_each = toset(var.administrators_account_numbers)
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_stores.arns)[0]
  permission_set_arn = var.project_name == "" ? aws_ssoadmin_permission_set.administration[0].arn : data.external.administration_permission_set_arn.result.arn
  principal_id   = data.aws_identitystore_group.administrators[0].group_id
  principal_type = "GROUP"
  target_id   = each.key
  target_type = "AWS_ACCOUNT"
}

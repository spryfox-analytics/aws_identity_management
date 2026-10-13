output "group_ids" {
  description = "Identity store ids of the groups that were looked up, keyed by Viewers and Developers."
  value       = { for group, data in data.aws_identitystore_group.this : group => data.group_id }
}

output "permission_set_arns" {
  description = "ARNs of the permission sets that were looked up, keyed by role."
  value       = { for role, data in data.aws_ssoadmin_permission_set.this : role => data.arn }
}

output "assignments" {
  description = "The account assignments, keyed by \"<group>/<account>/<role>\"."
  value = {
    for key, assignment in local.assignments : key => {
      group          = "${var.group_prefix} ${assignment.group}"
      account_number = assignment.account_number
      permission_set = var.permission_set_names[assignment.role]
    }
  }
}

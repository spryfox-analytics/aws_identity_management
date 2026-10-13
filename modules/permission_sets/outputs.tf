output "permission_set_arns" {
  description = "ARNs of the permission sets, keyed by role (Viewer, AgentViewer, Developer, AgentDeveloper, Administrator)."
  value       = merge({ for role, permission_set in aws_ssoadmin_permission_set.this : role => permission_set.arn }, { Administrator = aws_ssoadmin_permission_set.administrator.arn })
}

output "permission_set_names" {
  description = "Names of the permission sets, keyed by role. Can be passed to the assignments module as permission_set_names."
  value       = merge({ for role, permission_set in aws_ssoadmin_permission_set.this : role => permission_set.name }, { Administrator = aws_ssoadmin_permission_set.administrator.name })
}

output "viewer_arn" {
  value = aws_ssoadmin_permission_set.this["Viewer"].arn
}

output "agent_viewer_arn" {
  value = aws_ssoadmin_permission_set.this["AgentViewer"].arn
}

output "developer_arn" {
  value = aws_ssoadmin_permission_set.this["Developer"].arn
}

output "agent_developer_arn" {
  value = aws_ssoadmin_permission_set.this["AgentDeveloper"].arn
}

output "administrator_arn" {
  value = aws_ssoadmin_permission_set.administrator.arn
}

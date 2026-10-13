output "permission_set_view_arn" {
  value = var.project_name == "" ? aws_ssoadmin_permission_set.view[0].arn : data.external.view_permission_set_arn.result.arn
}

output "permission_set_development_arn" {
  value = var.project_name == "" ? aws_ssoadmin_permission_set.development[0].arn : data.external.development_permission_set_arn.result.arn
}

output "permission_set_administration_arn" {
  value = var.project_name == "" ? aws_ssoadmin_permission_set.administration[0].arn : data.external.administration_permission_set_arn.result.arn
}

output "permission_set_support_arn" {
  value = var.project_name == "" ? aws_ssoadmin_permission_set.support[0].arn : data.external.support_permission_set_arn.result.arn
}

output "permission_set_viewer_arn" {
  description = "Null unless agent_aware_roles is set (customer level) or role lists are given (project level)."
  value       = local.agent_aware_permission_set_arns["Viewer"]
}

output "permission_set_agent_viewer_arn" {
  description = "Null unless agent_aware_roles is set (customer level) or role lists are given (project level)."
  value       = local.agent_aware_permission_set_arns["AgentViewer"]
}

output "permission_set_developer_arn" {
  description = "Null unless agent_aware_roles is set (customer level) or role lists are given (project level)."
  value       = local.agent_aware_permission_set_arns["Developer"]
}

output "permission_set_agent_developer_arn" {
  description = "Null unless agent_aware_roles is set (customer level) or role lists are given (project level)."
  value       = local.agent_aware_permission_set_arns["AgentDeveloper"]
}

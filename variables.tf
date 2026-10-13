variable "aws_region" {
  type = string
}

variable "administrators_account_numbers" {
  type    = list(string)
  default = []
}

variable "developers_account_numbers" {
  type    = list(string)
  default = []
}

variable "viewers_account_numbers" {
  type    = list(string)
  default = []
}

variable "support_agents_account_numbers" {
  type    = list(string)
  default = []
}

variable "customer_name" {
  type = string
}

variable "development_account_numbers" {
  description = "Customer level only: accounts in which the permission set dev may do everything, as admin."
  type        = list(string)
  default     = []
}

variable "pipeline_account_numbers" {
  description = "Customer level only: accounts in which the permission set dev may approve, retry, start and stop CodePipeline pipelines, usually the tools accounts."
  type        = list(string)
  default     = []
}

variable "development_inline_policy_json" {
  description = "Customer level only: inline policy of the permission set dev instead of the default one, for a customer whose developers need other rights."
  type        = string
  default     = null
}

variable "project_name" {
  type    = string
  default = ""
}

variable "agent_aware_roles" {
  description = "Customer level only: create the permission sets Viewer, AgentViewer, Developer and AgentDeveloper of the role model for humans and AI agents."
  type        = bool
  default     = false
}

variable "agent_development_account_numbers" {
  description = "Customer level only: accounts in which the permission set AgentDeveloper may do everything. Null means development_account_numbers."
  type        = list(string)
  default     = null
}

variable "role_viewers_account_numbers" {
  description = "Accounts to which the group '<customer> [<project>] Viewers' gets the permission sets Viewer and AgentViewer."
  type        = list(string)
  default     = []
}

variable "role_developers_account_numbers" {
  description = "Accounts to which the group '<customer> [<project>] Developers' gets the permission sets Developer, AgentDeveloper, Viewer and AgentViewer."
  type        = list(string)
  default     = []
}

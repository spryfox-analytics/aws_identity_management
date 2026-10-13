variable "group_prefix" {
  description = "Prefix of the identity store groups, e.g. \"Spryfox Skillmoor\" for the groups \"Spryfox Skillmoor Viewers\" and \"Spryfox Skillmoor Developers\"."
  type        = string
}

variable "viewers_account_numbers" {
  description = "Accounts to which the group '<group_prefix> Viewers' gets Viewer and AgentViewer."
  type        = list(string)
  default     = []
}

variable "developers_account_numbers" {
  description = "Accounts to which the group '<group_prefix> Developers' gets Viewer, AgentViewer, Developer and AgentDeveloper."
  type        = list(string)
  default     = []
}

variable "administrators_account_numbers" {
  description = "Accounts to which the group '<group_prefix> Administrators' gets Administrator. Keep the group small; its members are usually also in Developers."
  type        = list(string)
  default     = []
}

variable "permission_set_names" {
  description = "Names of the permission sets by role, if they differ from the role names (e.g. with a name_prefix in the permission_sets module). Missing roles keep their default name."
  type = object({
    Viewer         = optional(string, "Viewer")
    AgentViewer    = optional(string, "AgentViewer")
    Developer      = optional(string, "Developer")
    AgentDeveloper = optional(string, "AgentDeveloper")
    Administrator  = optional(string, "Administrator")
  })
  default  = {}
  nullable = false
}

variable "development_account_numbers" {
  description = "Accounts in which Developer may do everything."
  type        = list(string)
  default     = []
}

variable "agent_development_account_numbers" {
  description = "Accounts in which AgentDeveloper may do everything. Null means development_account_numbers."
  type        = list(string)
  default     = null
}

variable "pipeline_account_numbers" {
  description = "Accounts in which Developer may start, retry, stop and approve CodePipeline pipelines and AgentDeveloper may start, retry and stop them, usually the tools accounts."
  type        = list(string)
  default     = []
}

variable "session_duration_humans" {
  description = "Session duration of Viewer and Developer (ISO 8601)."
  type        = string
  default     = "PT12H"
}

variable "session_duration_agents" {
  description = "Session duration of AgentViewer and AgentDeveloper (ISO 8601)."
  type        = string
  default     = "PT1H"
}

variable "name_prefix" {
  description = "Prefix of the permission set names. Empty means the names are exactly Viewer, AgentViewer, Developer and AgentDeveloper."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[\\w+=,.@-]*$", var.name_prefix)) && length(var.name_prefix) <= 18
    error_message = "name_prefix may only contain letters, digits and +=,.@_- and at most 18 characters (permission set names have at most 32)."
  }
}

variable "relay_state" {
  description = "URL the console opens after sign-in. Null means the console home page."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags of the permission sets."
  type        = map(string)
  default     = {}
}

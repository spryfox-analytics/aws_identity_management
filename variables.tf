variable "aws_region" {
  type = string
}

variable "administrators_account_numbers" {
  type = list(string)
  default = []
}

variable "developers_account_numbers" {
  type = list(string)
  default = []
}

variable "viewers_account_numbers" {
  type = list(string)
  default = []
}

variable "support_agents_account_numbers" {
  type = list(string)
  default = []
}

variable "customer_name" {
  type = string
}

variable "project_name" {
  type = string
  default = ""
}

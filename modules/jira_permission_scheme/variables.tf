variable "name" { type = string }
variable "description" { type = string }
variable "audience_groups" { type = list(string) }
variable "admin_groups" { type = list(string) }
variable "audience_permissions" {
  type    = list(string)
  default = ["BROWSE_PROJECTS", "CREATE_ISSUES", "EDIT_ISSUES", "ADD_COMMENTS", "CREATE_ATTACHMENTS", "ASSIGNABLE_USER"]
}
variable "admin_permissions" {
  type    = list(string)
  default = ["ADMINISTER_PROJECTS"]
}

variable "foundation_ready" {
  type        = bool
  default     = true
  description = "Set from the foundation stage outputs; false refuses to plan this resource."
}
variable "foundation_why" {
  type    = string
  default = ""
}

variable "name" { type = string }
variable "description" { type = string }
variable "role_permissions" {
  type        = map(list(string))
  description = "role key => Jira permissions, from the standard. No default: modules carry no policy."
}
variable "role_ids" {
  type        = map(string)
  description = "role key => site-wide project role id, from the foundation."
}

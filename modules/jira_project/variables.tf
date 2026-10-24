variable "key" { type = string }
variable "name" { type = string }
variable "description" { type = string }
variable "project_type_key" { type = string }
variable "project_template_key" { type = string }
variable "lead_account_id" { type = string }
variable "assignee_type" {
  type        = string
  description = "From the selected standard (policy/standards)."
}
variable "permission_scheme_id" { type = string }
variable "site_url" { type = string }
variable "authorization_header" {
  type      = string
  sensitive = true
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

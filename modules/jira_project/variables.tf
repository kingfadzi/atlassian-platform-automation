variable "key" { type = string }
variable "name" { type = string }
variable "description" { type = string }
variable "project_type_key" { type = string }
variable "project_template_key" { type = string }
variable "lead_account_id" { type = string }
variable "assignee_type" {
  type    = string
  default = "UNASSIGNED"
}
variable "permission_scheme_id" { type = string }
variable "site_url" { type = string }
variable "authorization_header" {
  type      = string
  sensitive = true
}

# Credentials only ever arrive through TF_VAR_* environment variables (GitLab protected,
# masked variables). They are never written to tfvars and never appear in plan output.

variable "atlassian_org_api_key" {
  type      = string
  sensitive = true
}
variable "atlassian_email" {
  type      = string
  sensitive = true
}
variable "atlassian_api_token" {
  type      = string
  sensitive = true
}
variable "admin_api_url" {
  type    = string
  default = "https://api.atlassian.com/admin"
}

locals {
  site_basic_auth = "Basic ${base64encode("${var.atlassian_email}:${var.atlassian_api_token}")}"
}

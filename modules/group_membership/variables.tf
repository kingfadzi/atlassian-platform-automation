variable "group_id" {
  type        = string
  description = "Atlassian group id, from the directory_group module output."
}
variable "group_name" { type = string }
variable "account_id" {
  type        = string
  description = "Atlassian accountId of the member."
}
variable "site_url" { type = string }
variable "authorization_header" {
  type      = string
  sensitive = true
}

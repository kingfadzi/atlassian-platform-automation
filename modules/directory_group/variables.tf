variable "org_id" { type = string }
variable "directory_id" { type = string }
variable "name" { type = string }
variable "description" {
  type    = string
  default = "managed by platform automation"
}
variable "scope_regex" {
  type        = string
  description = "Names must match this pattern; enforced before any create."
}
variable "ignore_server_additions" {
  type    = bool
  default = true
}

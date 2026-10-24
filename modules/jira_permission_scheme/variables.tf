variable "name" { type = string }
variable "description" { type = string }
variable "audience_groups" { type = list(string) }
variable "admin_groups" { type = list(string) }
variable "audience_permissions" {
  type        = list(string)
  description = "From the selected standard (policy/standards). No default: modules carry no policy."
}
variable "admin_permissions" {
  type        = list(string)
  description = "From the selected standard (policy/standards). No default: modules carry no policy."
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

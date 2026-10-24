variable "space_key" { type = string }
variable "space_id" { type = string }
variable "groups" { type = list(string) }
variable "operations" {
  type        = list(string)
  description = "From the selected standard (policy/standards). No default: modules carry no policy."
}

variable "space_key" { type = string }
variable "space_id" { type = string }
variable "groups" { type = list(string) }
variable "operations" {
  type    = list(string)
  default = ["read"]
}

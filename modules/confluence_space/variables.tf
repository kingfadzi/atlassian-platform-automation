variable "key" { type = string }
variable "name" { type = string }

variable "foundation_ready" {
  type        = bool
  default     = true
  description = "Set from the foundation stage outputs; false refuses to plan this resource."
}
variable "foundation_why" {
  type    = string
  default = ""
}

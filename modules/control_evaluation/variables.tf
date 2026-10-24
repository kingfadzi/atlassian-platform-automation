variable "catalogue" {
  description = "Decoded policy catalogue: { version, controls = [{ id, mandatory, depends, fact, require = { op, value | value_from }, lab? }] }."
  type        = any
}
variable "facts" {
  description = "Observed facts by name, each { known = bool, value = any }."
  type        = any
}
variable "intent" {
  description = "Values a requirement may reference through value_from, keyed by path (e.g. foundation.domains). Mixed types allowed."
  type        = any
  default     = {}
}
variable "products" {
  type    = list(string)
  default = ["jira", "confluence"]
}
variable "now" {
  description = "RFC 3339 evaluation time (plantimestamp() in real use, fixed in tests)."
  type        = string
}

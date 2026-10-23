# Probe identities for the release stage: an allowed member of the audience and a denied
# outsider. Tokens arrive as TF_VAR_* like all other credentials.
variable "probe_allowed_email" {
  type      = string
  sensitive = true
}
variable "probe_allowed_token" {
  type      = string
  sensitive = true
}
variable "probe_denied_email" {
  type      = string
  sensitive = true
}
variable "probe_denied_token" {
  type      = string
  sensitive = true
}

locals {
  allowed_auth = "Basic ${base64encode("${var.probe_allowed_email}:${var.probe_allowed_token}")}"
  denied_auth  = "Basic ${base64encode("${var.probe_denied_email}:${var.probe_denied_token}")}"
}

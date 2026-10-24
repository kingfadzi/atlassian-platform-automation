# Inputs of every stage: where the tenant is and what the engine should expect of it. There is
# no instance here: no project, space, group or person. Templates are policy/standards; instances
# are created by JSM and judged by stages/conform. Rules the inputs must satisfy are data
# (policy/intent_rules.yaml); the validations only apply them.

locals {
  rules = yamldecode(file("${path.module}/../../policy/intent_rules.yaml"))
}

variable "tenant" {
  type = object({
    org_id        = string
    directory_id  = string
    site_url      = string
    group_pattern = string # AD-managed groups that may be bound to a role; anything else is a finding
  })
  validation {
    condition     = can(regex("^https://", var.tenant.site_url)) || can(regex("^http://127.0.0.1", var.tenant.site_url))
    error_message = "site_url must be https (or the local stub)."
  }
  validation {
    condition     = can(regexall(var.tenant.group_pattern, ""))
    error_message = "group_pattern must be a valid regular expression."
  }
}

variable "foundation" {
  type = object({
    domains               = optional(list(string), [])   # verified domains expected on the organisation
    product_access_groups = optional(list(string), [])   # groups allowed as default product access; empty = not checked
    banner_contains       = optional(string, "governed") # text the announcement banner must carry
  })
  description = "Tenant specifics for the non-mandatory foundation controls (see policy/foundation.yaml)."
  default     = {}
}

variable "runtime_dir" {
  type        = string
  description = "Directory holding attestations.yaml, authority.yaml and exceptions.yaml (outside Git in anything but the lab)."
  default     = "../../runtime/lab"
}

# Inputs of every stage: where the tenant is and what the engine should expect of it. There is
# no instance here: no project, space, group or person. Templates are policy/standards; instances
# are created by JSM and judged by stages/estate. Rules the inputs must satisfy are data
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
    domains                        = optional(list(string), [])   # verified domains expected on the organisation
    product_access_groups          = optional(list(string), [])   # groups allowed as default product access; empty = not checked
    banner_contains                = optional(string, "governed") # text the announcement banner must carry
    confluence_free_seats_plus_one = optional(number, 11)         # Free tier is 10 seats; capacity above it implies a paid plan
    approved_realms                = optional(list(string), [])   # residency realms this tenant is expected to be in; empty = not checked
    accounts = optional(list(object({                             # accounts with admin, automation or emergency access
      id    = string                                              # Atlassian account id
      kind  = string                                              # a kind declared in policy/identities.yaml
      owner = optional(string)                                    # documentation: who answers for it
      scope = optional(string)                                    # documentation: why it exists
    })), [])
  })
  description = "Tenant specifics for the non-mandatory foundation controls (see policy/foundation.yaml)."
  default     = {}
}

# The environment this plan is for. Policy keys its per-environment requirements on this, so the
# environment declares which it is and policy decides what it may do.
variable "env" {
  type    = string
  default = "lab"
}

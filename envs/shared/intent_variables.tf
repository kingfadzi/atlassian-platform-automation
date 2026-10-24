# Shape and rules of the intent. Symlinked into every stage root so one definition serves all.
# Structural rules live here and fail at `terraform validate`, before any API call.

variable "tenant" {
  type = object({
    org_id       = string
    directory_id = string
    site_url     = string
    scope_regex  = string
  })
  validation {
    condition     = can(regex("^https://", var.tenant.site_url)) || can(regex("^http://127.0.0.1", var.tenant.site_url))
    error_message = "site_url must be https (or the local stub)."
  }
}

variable "groups" {
  type        = map(string)
  description = "Managed directory groups: name => description."
  validation {
    condition     = alltrue([for name in keys(var.groups) : can(regex(var.tenant.scope_regex, name))])
    error_message = "Every group name must match tenant.scope_regex."
  }
}

variable "jira" {
  type = object({
    scheme = object({
      name            = string
      audience_groups = list(string)
      admin_groups    = list(string)
    })
    project = object({
      key             = string
      name            = string
      type            = string
      template        = string
      lead_account_id = string
    })
  })
  validation {
    condition     = length(setsubtract(var.jira.scheme.admin_groups, var.jira.scheme.audience_groups)) == 0
    error_message = "jira.scheme.admin_groups must be a subset of audience_groups."
  }
  validation {
    condition     = length(setsubtract(var.jira.scheme.audience_groups, keys(var.groups))) == 0
    error_message = "jira.scheme.audience_groups must all be declared in groups."
  }
  validation {
    condition     = contains(["software", "business", "service_desk"], var.jira.project.type)
    error_message = "jira.project.type must be software, business or service_desk."
  }
}

variable "confluence" {
  type = object({
    space = object({
      key             = string
      name            = string
      audience_groups = list(string)
    })
  })
  validation {
    condition     = length(setsubtract(var.confluence.space.audience_groups, keys(var.groups))) == 0
    error_message = "confluence.space.audience_groups must all be declared in groups."
  }
}

variable "governance" {
  type = object({
    business_authority = string
    classification     = string
    standard           = string
    authority_records  = list(string)
  })
  validation {
    condition     = var.governance.classification == "Internal"
    error_message = "Only Internal classification is admitted in the lab (P-22)."
  }
  validation {
    condition     = can(regex("-v[0-9]+$", var.governance.standard))
    error_message = "governance.standard must be versioned, e.g. restricted-collab-v1."
  }
}

variable "identities" {
  type = object({
    admin    = string
    reviewer = string
    allowed  = string
    denied   = string
  })
  validation {
    condition     = length(distinct(values(var.identities))) == 4
    error_message = "admin, reviewer, allowed and denied identities must be distinct."
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

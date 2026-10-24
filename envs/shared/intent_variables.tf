# Shape of the intent and the structural rules it must satisfy. The rules are data
# (policy/intent_rules.yaml and the selected standard); the validations only apply them.
# Terraform >= 1.9 lets a validation read locals and other variables.

locals {
  rules    = yamldecode(file("${path.module}/../../policy/intent_rules.yaml"))
  standard = yamldecode(file("${path.module}/../../policy/standards/${var.governance.standard}.yaml"))
}

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
    project = object({
      key             = string
      name            = string
      type            = string
      template        = string
      lead_account_id = string
      roles           = map(list(string)) # role key (from the standard) => groups bound to it
    })
  })
  validation {
    condition     = length(setsubtract(keys(var.jira.project.roles), local.standard.roles)) == 0
    error_message = "jira.project.roles keys must be roles of the selected standard: ${join(", ", local.standard.roles)}."
  }
  validation {
    condition     = !local.rules.admin_role_required || try(length(var.jira.project.roles["admin"]), 0) > 0
    error_message = "jira.project.roles.admin must bind at least one group (policy/intent_rules.yaml)."
  }
  validation {
    condition     = !local.rules.role_groups_must_be_declared || length(setsubtract(flatten(values(var.jira.project.roles)), keys(var.groups))) == 0
    error_message = "Every group bound to a role must be declared in groups (policy/intent_rules.yaml)."
  }
  validation {
    condition     = contains(local.standard.jira.project_types, var.jira.project.type)
    error_message = "jira.project.type must be one of the selected standard's project_types: ${join(", ", local.standard.jira.project_types)}."
  }
  validation {
    condition     = can(regex(local.rules.project_key_pattern, var.jira.project.key))
    error_message = "jira.project.key must match ${local.rules.project_key_pattern} (policy/intent_rules.yaml)."
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
    condition     = !local.rules.role_groups_must_be_declared || length(setsubtract(var.confluence.space.audience_groups, keys(var.groups))) == 0
    error_message = "confluence.space.audience_groups must all be declared in groups (policy/intent_rules.yaml)."
  }
  validation {
    condition     = can(regex(local.rules.space_key_pattern, var.confluence.space.key))
    error_message = "confluence.space.key must match ${local.rules.space_key_pattern} (policy/intent_rules.yaml)."
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
    condition     = contains(local.rules.admitted_classifications, var.governance.classification)
    error_message = "governance.classification must be one of ${join(", ", local.rules.admitted_classifications)} (policy/intent_rules.yaml)."
  }
  validation {
    condition     = can(regex(local.rules.standard_id_pattern, var.governance.standard))
    error_message = "governance.standard must match ${local.rules.standard_id_pattern} (policy/intent_rules.yaml)."
  }
  validation {
    condition     = fileexists("${path.module}/../../policy/standards/${var.governance.standard}.yaml")
    error_message = "No standard file policy/standards/${var.governance.standard}.yaml."
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
    condition     = length(distinct([for k in local.rules.distinct_identities : var.identities[k]])) == length(local.rules.distinct_identities)
    error_message = "Identities ${join(", ", local.rules.distinct_identities)} must be distinct (policy/intent_rules.yaml)."
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
  description = "Directory holding attestations.yaml, authority.yaml and exceptions.yaml (outside Git in anything but the lab). Read by the foundation stage."
  default     = "../../runtime/lab"
}

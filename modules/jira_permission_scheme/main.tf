# A Jira permission scheme granting to project roles. One per standard, created by the
# foundation; every asset of the standard uses it. Each grant is its own resource, so the order
# Jira returns permissions never matters and a missing grant is planned as a single create.
# Nothing here is deleted or updated by Terraform; drift is reported by checks.
#
# Known provider limit (Mastercard/restapi 3.0.0, issue #377): an object deleted outside Terraform
# is NOT dropped from state on refresh, so a removed grant is not re-planned here. The foundation
# detects it from the tenant instead (control scheme_grants_match_standards) and the recovery is
# `terraform state rm <grant address>` followed by apply; see docs/runbook-foundation.md.

terraform {
  required_providers {
    restapi = { source = "Mastercard/restapi", version = "3.0.0" }
  }
}

locals {
  # "PERMISSION:role" keys are stable across runs and readable in plans.
  grants = merge([for role, perms in var.role_permissions :
    { for p in perms : "${p}:${role}" => { permission = p, role = role, role_id = var.role_ids[role] } }
  ]...)
}

resource "restapi_object" "scheme" {
  path         = "/rest/api/3/permissionscheme"
  id_attribute = "id"
  data = jsonencode({
    name        = var.name
    description = var.description
  })
  ignore_server_additions = true

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = length(setsubtract(keys(var.role_permissions), keys(var.role_ids))) == 0
      error_message = "Standard '${var.name}' grants to roles that are not provisioned: ${join(", ", setsubtract(keys(var.role_permissions), keys(var.role_ids)))}."
    }
  }
}

resource "restapi_object" "grant" {
  for_each     = local.grants
  path         = "/rest/api/3/permissionscheme/${restapi_object.scheme.id}/permission"
  id_attribute = "id"
  data = jsonencode({
    permission = each.value.permission
    holder     = { type = "projectRole", parameter = tostring(each.value.role_id) }
  })
  ignore_server_additions = true

  lifecycle { prevent_destroy = true }
}

check "scheme_matches_policy" {
  assert {
    condition     = restapi_object.scheme.api_data["name"] == var.name
    error_message = "Drift: scheme ${restapi_object.scheme.id} is named '${restapi_object.scheme.api_data["name"]}', policy says '${var.name}'."
  }
}

check "grants_match_policy" {
  # A grant that is about to be created has no API data yet; the plan itself reports it.
  assert {
    condition = alltrue([
      for key, g in restapi_object.grant : try(
        g.api_data["permission"] == local.grants[key].permission
        && tostring(jsondecode(g.api_response).holder.parameter) == tostring(local.grants[key].role_id),
      true)
    ])
    error_message = "Drift: one or more grants in scheme '${var.name}' no longer match the standard."
  }
}

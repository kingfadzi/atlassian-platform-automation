# A Jira permission scheme and its grants. Each grant is its own resource, so the order in
# which Jira returns permissions never matters and a missing grant is planned as a single
# create. Nothing here is ever deleted or updated by Terraform; drift is reported by checks.

terraform {
  required_providers {
    restapi = { source = "Mastercard/restapi", version = "3.0.0" }
  }
}

locals {
  # "PERMISSION:group" keys are stable across runs and readable in plans.
  grants = merge(
    { for pair in setproduct(var.audience_permissions, var.audience_groups) : "${pair[0]}:${pair[1]}" => { permission = pair[0], group = pair[1] } },
    { for pair in setproduct(var.admin_permissions, var.admin_groups) : "${pair[0]}:${pair[1]}" => { permission = pair[0], group = pair[1] } },
  )
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
      condition     = var.foundation_ready
      error_message = "Shared foundation is not ready for Jira: ${var.foundation_why}. Fix the foundation stage first."
    }
    precondition {
      condition     = length(setsubtract(var.admin_groups, var.audience_groups)) == 0
      error_message = "Admin groups must be a subset of audience groups (${var.name})."
    }
  }
}

resource "restapi_object" "grant" {
  for_each     = local.grants
  path         = "/rest/api/3/permissionscheme/${restapi_object.scheme.id}/permission"
  id_attribute = "id"
  data = jsonencode({
    permission = each.value.permission
    holder     = { type = "group", parameter = each.value.group }
  })
  ignore_server_additions = true

  lifecycle { prevent_destroy = true }
}

check "scheme_matches_intent" {
  assert {
    condition     = restapi_object.scheme.api_data["name"] == var.name
    error_message = "Drift: scheme ${restapi_object.scheme.id} is named '${restapi_object.scheme.api_data["name"]}', intent is '${var.name}'."
  }
}

check "grants_match_intent" {
  assert {
    condition = alltrue([
      for key, g in restapi_object.grant :
      g.api_data["permission"] == local.grants[key].permission
      && jsondecode(g.api_response).holder.parameter == local.grants[key].group
    ])
    error_message = "Drift: one or more grants in scheme '${var.name}' no longer match the intent."
  }
}

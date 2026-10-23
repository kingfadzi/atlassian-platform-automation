# One Atlassian directory group. Never deleted or renamed by Terraform.
#
# The Admin API answers a create with 201 and no body, so the provider cannot learn the
# new id from the response. object_id seeds the id with the group name so the create is
# allowed; read_search then looks the group up by exact name on every read and records the
# real Atlassian group id (id_attribute) as the resource id.

terraform {
  required_providers {
    restapi = { source = "Mastercard/restapi", version = "3.0.0" }
  }
}

resource "restapi_object" "group" {
  path         = "/v2/orgs/${var.org_id}/directories/${var.directory_id}/groups"
  object_id    = var.name
  id_attribute = "id"
  data = jsonencode({
    name        = var.name
    description = var.description
  })

  read_search = {
    search_key   = "name"
    search_value = var.name
    results_key  = "data"
    query_string = "searchTerm=${urlencode(var.name)}&limit=50"
  }

  ignore_server_additions = var.ignore_server_additions

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = can(regex(var.scope_regex, var.name))
      error_message = "Group name '${var.name}' does not match the scope guard '${var.scope_regex}'."
    }
  }
}

# Drift is reported here, not repaired. The provider refreshes api_data on every plan;
# these checks compare it with the intent and surface as `checks` in the plan JSON.
check "group_matches_intent" {
  assert {
    condition     = restapi_object.group.api_data["name"] == var.name
    error_message = "Drift: group ${restapi_object.group.id} is named '${restapi_object.group.api_data["name"]}', intent is '${var.name}'."
  }
  assert {
    condition     = restapi_object.group.api_data["description"] == var.description
    error_message = "Drift: group ${var.name} description is '${restapi_object.group.api_data["description"]}', intent is '${var.description}'."
  }
}

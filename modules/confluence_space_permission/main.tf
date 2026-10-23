# Space permission grants for groups. Created through the v1 endpoint (the v2 API has no
# create); read back by id from the v2 permissions list, which has a different shape, so
# the drift check compares the v2 principal/operation with the intent.
# The provider always searches on `path`, so `path` is the v2 list and `create_path` is v1.

terraform {
  required_providers {
    restapi = { source = "Mastercard/restapi", version = "3.0.0" }
  }
}

locals {
  grants = { for pair in setproduct(var.operations, var.groups) : "${pair[0]}:${pair[1]}" => { operation = pair[0], group = pair[1] } }
}

resource "restapi_object" "grant" {
  for_each     = local.grants
  path         = "/wiki/api/v2/spaces/${var.space_id}/permissions"
  create_path  = "/wiki/rest/api/space/${var.space_key}/permission"
  id_attribute = "id"
  data = jsonencode({
    subject   = { type = "group", identifier = each.value.group }
    operation = { key = each.value.operation, target = "space" }
  })
  read_search = {
    search_key   = "id"
    search_value = "{id}"
    results_key  = "results"
    query_string = "limit=250"
  }
  ignore_server_additions = true

  lifecycle { prevent_destroy = true }
}

# The create response is v1-shaped (subject), every later read is v2-shaped (principal).
check "grants_match_intent" {
  assert {
    condition = alltrue([
      for key, g in restapi_object.grant :
      jsondecode(g.api_response).operation.key == local.grants[key].operation
      && try(jsondecode(g.api_response).principal.type, jsondecode(g.api_response).subject.type) == "group"
    ])
    error_message = "Drift: one or more space permissions on ${var.space_key} no longer match the intent."
  }
}

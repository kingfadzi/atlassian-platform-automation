# A Confluence space created private to the automation identity, then opened to the
# audience groups by confluence_space_permission. Created through the v1 endpoint (the only
# one that creates private spaces) and read back through v2.

terraform {
  required_providers {
    restapi = { source = "Mastercard/restapi", version = "3.0.0" }
  }
}

resource "restapi_object" "space" {
  path         = "/wiki/rest/api/space"
  create_path  = "/wiki/rest/api/space/_private"
  read_path    = "/wiki/api/v2/spaces/{id}"
  id_attribute = "id"
  data = jsonencode({
    key  = var.key
    name = var.name
  })
  ignore_server_additions = true

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = var.foundation_ready
      error_message = "Shared foundation is not ready for Confluence: ${var.foundation_why}. Fix the foundation stage first."
    }
  }
}

check "space_matches_intent" {
  assert {
    condition     = lookup(restapi_object.space.api_data, "key", var.key) == var.key && lookup(restapi_object.space.api_data, "name", var.name) == var.name
    error_message = "Drift: space ${restapi_object.space.id} key/name differ from intent (${var.key} / ${var.name})."
  }
}

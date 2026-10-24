# A site-wide Jira custom field. No GET by id exists, so it is read back by searching the full
# field list (GET /rest/api/3/field returns every field, unpaginated). Never deleted by Terraform.

terraform {
  required_providers {
    restapi = { source = "Mastercard/restapi", version = "3.0.0" }
  }
}

resource "restapi_object" "field" {
  path         = "/rest/api/3/field"
  id_attribute = "id"
  data = jsonencode({
    name        = var.name
    description = var.description
    type        = var.type
    searcherKey = var.searcher
  })
  read_search = {
    search_key   = "id"
    search_value = "{id}"
  }
  ignore_server_additions = true

  lifecycle { prevent_destroy = true }
}

check "field_matches_policy" {
  assert {
    condition     = lookup(restapi_object.field.api_data, "name", var.name) == var.name
    error_message = "Drift: field ${restapi_object.field.id} is named '${lookup(restapi_object.field.api_data, "name", "?")}', policy says '${var.name}'."
  }
}

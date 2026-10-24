# Adds an issue type to an issue type scheme (PUT, no body returned). The object's id is the
# issue type id; it is read back by searching the scheme's mappings (the provider searches on
# `path` with `query_string`, so the create goes to its own path). Never removed by Terraform.

terraform {
  required_providers {
    restapi = { source = "Mastercard/restapi", version = "3.0.0" }
  }
}

resource "restapi_object" "mapping" {
  path          = "/rest/api/3/issuetypescheme/mapping"
  create_path   = "/rest/api/3/issuetypescheme/${var.scheme_id}/issuetype"
  create_method = "PUT"
  object_id     = var.issue_type_id
  id_attribute  = "issueTypeId"
  data          = jsonencode({ issueTypeIds = [var.issue_type_id] })
  read_search = {
    search_key   = "issueTypeId"
    search_value = var.issue_type_id
    results_key  = "values"
    query_string = "issueTypeSchemeId=${var.scheme_id}&maxResults=100"
  }
  ignore_server_additions = true

  lifecycle { prevent_destroy = true }
}

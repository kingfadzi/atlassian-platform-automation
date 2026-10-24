# A site-wide Jira issue type. Never deleted or renamed by Terraform.

terraform {
  required_providers {
    restapi = { source = "Mastercard/restapi", version = "3.0.0" }
  }
}

resource "restapi_object" "issue_type" {
  path         = "/rest/api/3/issuetype"
  id_attribute = "id"
  data = jsonencode({
    name        = var.name
    description = var.description
    type        = "standard"
  })
  ignore_server_additions = true

  lifecycle { prevent_destroy = true }
}

check "issue_type_matches_policy" {
  assert {
    condition     = restapi_object.issue_type.api_data["name"] == var.name
    error_message = "Drift: issue type ${restapi_object.issue_type.id} is named '${restapi_object.issue_type.api_data["name"]}', policy says '${var.name}'."
  }
}

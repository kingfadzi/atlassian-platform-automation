# A JSM request type in a service desk (the service desk id may be the project key). Portal
# field layout is console work (runbook). Never deleted by Terraform.

terraform {
  required_providers {
    restapi = { source = "Mastercard/restapi", version = "3.0.0" }
  }
}

resource "restapi_object" "request_type" {
  path         = "/rest/servicedeskapi/servicedesk/${var.service_desk}/requesttype"
  id_attribute = "id"
  data = jsonencode({
    name        = var.name
    description = var.description
    issueTypeId = var.issue_type_id
    helpText    = var.description
  })
  ignore_server_additions = true

  lifecycle { prevent_destroy = true }
}

check "request_type_matches_policy" {
  assert {
    condition     = restapi_object.request_type.api_data["name"] == var.name
    error_message = "Drift: request type ${restapi_object.request_type.id} is named '${restapi_object.request_type.api_data["name"]}', policy says '${var.name}'."
  }
}

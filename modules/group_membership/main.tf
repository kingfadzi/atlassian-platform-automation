# One group membership: an Atlassian account placed in a managed group. Created once and
# never removed by automation, like every other resource here.
#
# Jira answers the create with the *group* object, not a membership object, so the provider
# cannot learn an id from the response. object_id seeds the id with the accountId; read_search
# then lists the group's members on every read and finds this account.

terraform {
  required_providers {
    restapi = { source = "Mastercard/restapi", version = "3.0.0" }
    http    = { source = "hashicorp/http", version = "~> 3.5" }
  }
}

resource "restapi_object" "membership" {
  path         = "/rest/api/3/group/member"
  create_path  = "/rest/api/3/group/user?groupId=${var.group_id}"
  object_id    = var.account_id
  id_attribute = "accountId"
  data         = jsonencode({ accountId = var.account_id })

  read_search = {
    search_key   = "accountId"
    search_value = var.account_id
    results_key  = "values"
    query_string = "groupId=${var.group_id}&maxResults=200"
  }

  ignore_server_additions = true

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = length(var.account_id) > 0
      error_message = "account_id must not be empty (group ${var.group_name})."
    }
  }
}

# Membership is verified by reading the group back, not from api_data: when the account is
# removed out of band the provider's read_search simply finds nothing and a lookup() default
# would silently pass. depends_on defers this read until after the create, so the first plan
# does not assert against a membership that does not exist yet.
data "http" "members" {
  url             = "${var.site_url}/rest/api/3/group/member?groupId=${var.group_id}&maxResults=200"
  request_headers = { Authorization = var.authorization_header, Accept = "application/json" }

  depends_on = [restapi_object.membership]
}

# Drift is reported here, not repaired: a removed member fails this check, which the
# governance gate reads from the plan JSON and treats as blocking.
check "membership_present" {
  assert {
    condition = data.http.members.status_code == 200 && contains(
      [for m in try(jsondecode(data.http.members.response_body).values, []) : m.accountId],
      var.account_id
    )
    error_message = "Drift: ${var.account_id} is not a member of group ${var.group_name} (HTTP ${data.http.members.status_code})."
  }
}

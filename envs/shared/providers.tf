# Three views of the same provider: the organisation Admin API (bearer org key, create
# returns no body) and the site REST APIs for Jira and Confluence (basic auth with an API
# token, writes return the object). Symlinked into every stage root.

terraform {
  required_version = ">= 1.9"
  required_providers {
    restapi = { source = "Mastercard/restapi", version = "3.0.0" }
    http    = { source = "hashicorp/http", version = "~> 3.5" }
  }
}

provider "restapi" {
  alias                = "admin"
  uri                  = var.admin_api_url
  bearer_token         = var.atlassian_org_api_key
  write_returns_object = false
  id_attribute         = "id"
  headers              = { Accept = "application/json" }
  rate_limit           = 5
  timeout              = 60
  retries {
    max_retries = 3
    min_wait    = 2
    max_wait    = 30
  }
}

provider "restapi" {
  alias                = "jira"
  uri                  = var.tenant.site_url
  username             = var.atlassian_email
  password             = var.atlassian_api_token
  write_returns_object = true
  id_attribute         = "id"
  headers              = { Accept = "application/json" }
  rate_limit           = 5
  timeout              = 60
  retries {
    max_retries = 3
    min_wait    = 2
    max_wait    = 30
  }
}

provider "restapi" {
  alias                = "confluence"
  uri                  = var.tenant.site_url
  username             = var.atlassian_email
  password             = var.atlassian_api_token
  write_returns_object = true
  id_attribute         = "id"
  headers              = { Accept = "application/json" }
  rate_limit           = 5
  timeout              = 60
  retries {
    max_retries = 3
    min_wait    = 2
    max_wait    = 30
  }
}

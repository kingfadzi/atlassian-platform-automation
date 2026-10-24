# The shared foundation gate. admit reads the foundation stage's state and refuses to plan
# Jira or Confluence assets unless that product is ready and the evaluation is recent.
# In the pipeline the state is the GitLab http backend (TF_VAR_foundation_state); the spike
# overrides this data source with a local path.

variable "foundation_state" {
  type        = map(string)
  description = "http backend config of the foundation stage state: address, username, password."
  default     = {}
  sensitive   = true
}

variable "foundation_window_days" {
  type    = number
  default = 7
}

data "terraform_remote_state" "foundation" {
  backend = "http"
  config  = var.foundation_state
}

locals {
  foundation       = data.terraform_remote_state.foundation.outputs
  foundation_fresh = timecmp(timeadd("${local.foundation.evaluated_on}T00:00:00Z", "${var.foundation_window_days * 24}h"), plantimestamp()) >= 0
  jira_ready       = local.foundation_fresh && local.foundation.ready.jira
  confluence_ready = local.foundation_fresh && local.foundation.ready.confluence
  foundation_why   = local.foundation_fresh ? "blocked by ${join(", ", keys(local.foundation.blocking))}" : "evaluation from ${local.foundation.evaluated_on} is older than ${var.foundation_window_days} days"
}

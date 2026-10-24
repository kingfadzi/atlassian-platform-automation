# Stage: conform reads the foundation stage's state for the template ids (roles, schemes) and
# refuses to judge the estate against a stale foundation evaluation. In the pipeline the state is
# the GitLab http backend (TF_VAR_foundation_state); the spike overrides this with a local path.

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
  contract         = local.foundation.contract
  foundation_fresh = timecmp(timeadd("${local.foundation.evaluated_on}T00:00:00Z", "${var.foundation_window_days * 24}h"), plantimestamp()) >= 0
}

resource "terraform_data" "foundation_is_current" {
  lifecycle {
    precondition {
      condition     = local.foundation_fresh
      error_message = "Foundation evaluation from ${local.foundation.evaluated_on} is older than ${var.foundation_window_days} days; run the foundation stage first."
    }
  }
}

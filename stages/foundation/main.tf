# Stage: foundation, part 3. Readiness is dependency-specific: a failing mandatory control
# blocks the products that depend on it and nothing else. stages/admit reads these outputs
# through terraform_remote_state and refuses to plan Jira or Confluence assets that are not ready.

variable "runtime_dir" {
  type        = string
  description = "Directory holding attestations.yaml (outside Git in anything but the lab)."
  default     = "../../runtime/lab"
}

check "mandatory_controls" {
  assert {
    condition     = length(local.blocking) == 0
    error_message = "Mandatory foundation controls not satisfied: ${join(", ", [for id, dep in local.blocking : "${id} (${local.controls[id]}; blocks ${join("+", dep)})"])}."
  }
}

check "report_controls" {
  assert {
    condition     = length(local.findings) == 0
    error_message = "Foundation findings (reported, not blocking): ${join(", ", [for id, s in local.findings : "${id}=${s}"])}."
  }
}

output "ready" {
  description = "Per-product readiness consumed by stages/admit."
  value       = local.ready
}
output "controls" { value = local.controls }
output "blocking" { value = local.blocking }
output "findings" { value = local.findings }
# Outputs must be stable between plans; volatile observations (event timestamps) stay out.
output "details" {
  value = {
    public_grants        = local.public_grants
    sitewide_browse      = local.sitewide
    domains              = local.domains_seen
    confluence_retention = local.retention
    entitlements         = local.entitlements
  }
}
output "evaluated_on" {
  description = "Day of this evaluation; admit treats evaluations older than the policy window as stale."
  value       = formatdate("YYYY-MM-DD", local.now)
}

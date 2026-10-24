# Stage: conform, part 4. Outputs the estate's state and reports findings. Owns no instance;
# the check is report-only so a non-conforming instance never blocks the run that found it.

check "report_estate" {
  assert {
    condition     = length(local.findings) == 0
    error_message = "Estate findings (reported): ${join("; ", local.findings)}."
  }
}

output "evaluated_on" { value = formatdate("YYYY-MM-DD", local.now) }
output "instances" { value = local.verdicts }
output "findings" { value = local.findings }
output "summary" {
  value = {
    projects       = length(local.projects)
    spaces         = length(local.spaces)
    non_conforming = length([for id, f in local.failing : id if length(f) > 0])
    by_standard    = { for std in keys(local.standards) : std => length([for id, i in local.instances : id if i.standard == std]) }
    unstamped      = length([for id, i in local.instances : id if !i.facts.stamp.value])
  }
}

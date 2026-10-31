# Generic control evaluation. Compares each control's fact with its requirement using one of
# eight comparisons and derives per-product readiness. Contains no control id, threshold,
# permission name or product rule: those are the catalogue (data) and the facts (observations).

locals {
  operators = ["equals", "empty", "at_least", "within_days", "manually_confirmed_within_days", "superset_of", "subset_of", "contains"]
  by_id     = { for c in var.catalogue.controls : c.id => c }

  # Required value: a literal, or looked up by path in the intent values supplied by the caller.
  required = { for id, c in local.by_id : id =>
    try(c.require.value_from, null) != null ? lookup(var.intent, c.require.value_from, null) : try(c.require.value, null)
  }
  fact = { for id, c in local.by_id : id => lookup(var.facts, c.fact, { known = false, value = null }) }

  verdict = { for id, c in local.by_id : id => (
    try(c.lab, "") == "not_applicable" ? "not_applicable" :
    try(c.require.value_from, null) != null && (local.required[id] == null || try(length(local.required[id]), 1) == 0) ? "not_applicable" :
    !local.fact[id].known ? "unknown" :
    c.require.op == "equals" ? (local.fact[id].value == local.required[id] ? "pass" : "fail") :
    c.require.op == "empty" ? (length(local.fact[id].value) == 0 ? "pass" : "fail") :
    c.require.op == "at_least" ? (local.fact[id].value >= local.required[id] ? "pass" : "fail") :
    c.require.op == "within_days" ? (local.fact[id].value != null && timecmp(local.fact[id].value, timeadd(var.now, "-${local.required[id] * 24}h")) >= 0 ? "pass" : "fail") :
    c.require.op == "manually_confirmed_within_days" ? (can(local.fact[id].value[id]) && timecmp(timeadd(local.fact[id].value[id], "${local.required[id] * 24}h"), var.now) >= 0 ? "manually_confirmed" : "fail") :
    c.require.op == "superset_of" ? (length(setsubtract(local.required[id], local.fact[id].value)) == 0 ? "pass" : "fail") :
    c.require.op == "subset_of" ? (length(setsubtract(local.fact[id].value, local.required[id])) == 0 ? "pass" : "fail") :
    c.require.op == "contains" ? (strcontains(local.fact[id].value, local.required[id]) ? "pass" : "fail") :
    "unknown"
  ) }

  ok_states = ["pass", "manually_confirmed", "not_applicable"]
  blocking  = { for id, c in local.by_id : id => c.depends if c.mandatory && !contains(local.ok_states, local.verdict[id]) }
  findings  = { for id, c in local.by_id : id => local.verdict[id] if !c.mandatory && !contains(local.ok_states, local.verdict[id]) }
  ready     = { for product in var.products : product => length([for id, dep in local.blocking : id if contains(dep, product)]) == 0 }
}

# A catalogue naming a fact the caller cannot observe, or an operator outside the eight, is a
# configuration error at plan time, never an "unknown" verdict.
resource "terraform_data" "catalogue_is_consistent" {
  lifecycle {
    precondition {
      condition     = alltrue([for id, c in local.by_id : contains(keys(var.facts), c.fact)])
      error_message = "Catalogue names facts that are not observed: ${join(", ", [for id, c in local.by_id : "${id} -> ${c.fact}" if !contains(keys(var.facts), c.fact)])}."
    }
    precondition {
      condition     = alltrue([for id, c in local.by_id : contains(local.operators, c.require.op)])
      error_message = "Catalogue uses an operator outside ${join("/", local.operators)}."
    }
  }
}

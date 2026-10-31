# One run per operator, plus unknown, not_applicable, value_from and the consistency
# preconditions. No provider, no tenant. Run: terraform -chdir=modules/control_evaluation test

variables {
  now    = "2026-10-24T12:00:00Z"
  intent = { "foundation.domains" = ["lab.example"], "foundation.none" = [], "standard.days" = 7 }
  facts = {
    count_zero          = { known = true, value = 0 }
    count_two           = { known = true, value = 2 }
    empty_list          = { known = true, value = [] }
    some_list           = { known = true, value = ["a", "b"] }
    fresh_time          = { known = true, value = "2026-10-23T12:00:00Z" }
    stale_time          = { known = true, value = "2026-01-01T00:00:00Z" }
    text                = { known = true, value = "Lab tenant: governed estate" }
    unreadable          = { known = false, value = null }
    manual_confirmation = { known = true, value = { fresh = "2026-10-01T00:00:00Z", old = "2025-01-01T00:00:00Z" } }
  }
  catalogue = {
    version = "test"
    controls = [
      { id = "eq_pass", mandatory = true, depends = ["jira"], fact = "count_zero", require = { op = "equals", value = 0 } },
      { id = "eq_fail", mandatory = false, depends = ["jira"], fact = "count_two", require = { op = "equals", value = 0 } },
      { id = "empty_pass", mandatory = true, depends = ["confluence"], fact = "empty_list", require = { op = "empty" } },
      { id = "empty_fail", mandatory = false, depends = ["confluence"], fact = "some_list", require = { op = "empty" } },
      { id = "at_least_pass", mandatory = false, depends = ["jira"], fact = "count_two", require = { op = "at_least", value = 2 } },
      { id = "within_pass", mandatory = true, depends = ["jira", "confluence"], fact = "fresh_time", require = { op = "within_days", value = 7 } },
      { id = "within_fail", mandatory = false, depends = ["jira"], fact = "stale_time", require = { op = "within_days", value = 7 } },
      { id = "fresh", mandatory = true, depends = ["confluence"], fact = "manual_confirmation", require = { op = "manually_confirmed_within_days", value = 90 } },
      { id = "old", mandatory = false, depends = ["confluence"], fact = "manual_confirmation", require = { op = "manually_confirmed_within_days", value = 90 } },
      { id = "superset_pass", mandatory = false, depends = ["jira"], fact = "some_list", require = { op = "superset_of", value = ["a"] } },
      { id = "subset_fail", mandatory = false, depends = ["jira"], fact = "some_list", require = { op = "subset_of", value = ["a"] } },
      { id = "contains_pass", mandatory = false, depends = ["jira"], fact = "text", require = { op = "contains", value = "governed" } },
      { id = "from_intent", mandatory = false, depends = ["jira"], fact = "some_list", require = { op = "superset_of", value_from = "foundation.domains" } },
      { id = "from_empty_intent", mandatory = true, depends = ["jira"], fact = "some_list", require = { op = "subset_of", value_from = "foundation.none" } },
      { id = "from_number_intent", mandatory = false, depends = ["jira"], fact = "stale_time", require = { op = "within_days", value_from = "standard.days" } },
      { id = "from_missing_intent", mandatory = false, depends = ["jira"], fact = "stale_time", require = { op = "within_days", value_from = "standard.absent" } },
      { id = "unknown_fact", mandatory = false, depends = ["jira"], fact = "unreadable", require = { op = "equals", value = 0 } },
      { id = "na", mandatory = true, depends = ["jira"], fact = "count_two", require = { op = "equals", value = 0 }, lab = "not_applicable" },
    ]
  }
}

run "verdicts" {
  command = plan
  assert {
    condition = output.verdict == {
      eq_pass       = "pass", eq_fail = "fail", empty_pass = "pass", empty_fail = "fail", at_least_pass = "pass",
      within_pass   = "pass", within_fail = "fail", fresh = "manually_confirmed", old = "fail",
      superset_pass = "pass", subset_fail = "fail", contains_pass = "pass",
      from_intent   = "fail", from_empty_intent = "not_applicable", from_number_intent = "fail", from_missing_intent = "not_applicable",
      unknown_fact  = "unknown", na = "not_applicable",
    }
    error_message = "Unexpected verdicts: ${jsonencode(output.verdict)}"
  }
  assert {
    condition     = output.ready == { jira = true, confluence = true } && length(output.blocking) == 0
    error_message = "All mandatory controls pass here, so both products must be ready."
  }
  assert {
    condition     = length(output.findings) == 8
    error_message = "Eight non-mandatory controls fail or are unknown here: ${jsonencode(output.findings)}"
  }
}

run "unknown_mandatory_blocks_only_its_dependents" {
  command = plan
  variables {
    catalogue = {
      version = "test"
      controls = [
        { id = "blocked", mandatory = true, depends = ["jira"], fact = "unreadable", require = { op = "equals", value = 0 } },
        { id = "fine", mandatory = true, depends = ["confluence"], fact = "empty_list", require = { op = "empty" } },
      ]
    }
  }
  assert {
    condition     = output.ready == { jira = false, confluence = true } && output.blocking == { blocked = ["jira"] }
    error_message = "An unknown mandatory control must block exactly its dependents."
  }
}

run "catalogue_naming_an_unobserved_fact_is_rejected" {
  command = plan
  variables {
    catalogue = { version = "test", controls = [{ id = "typo", mandatory = true, depends = ["jira"], fact = "no_such_fact", require = { op = "empty" } }] }
  }
  expect_failures = [terraform_data.catalogue_is_consistent]
}

run "unsupported_operator_is_rejected" {
  command = plan
  variables {
    catalogue = { version = "test", controls = [{ id = "clever", mandatory = true, depends = ["jira"], fact = "text", require = { op = "matches_regex", value = ".*" } }] }
  }
  expect_failures = [terraform_data.catalogue_is_consistent]
}

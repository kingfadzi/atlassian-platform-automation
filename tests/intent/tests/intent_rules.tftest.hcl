# Structural rules of the intent, proven without any tenant or provider.
# Run with: terraform -chdir=tests/intent test

variables {
  tenant = { org_id = "o", directory_id = "d", site_url = "https://lab.atlassian.net", scope_regex = "^lab-" }
  groups = { lab-admins = "a", lab-team = "t", lab-outsiders = "o" }
  jira = {
    scheme  = { name = "LAB Restricted", audience_groups = ["lab-admins", "lab-team"], admin_groups = ["lab-admins"] }
    project = { key = "LABR", name = "LAB Restricted", type = "software", template = "x", lead_account_id = "u" }
  }
  confluence = { space = { key = "LABP", name = "LAB Private", audience_groups = ["lab-admins", "lab-team"] } }
  governance = { business_authority = "BA-LAB-001", classification = "Internal", standard = "restricted-collab-v1", authority_records = ["AUTH-APP-01"] }
  identities = { admin = "a", reviewer = "r", allowed = "x", denied = "y" }
}

run "valid_intent_plans" {
  command = plan
}

run "group_outside_scope_is_rejected" {
  command = plan
  variables {
    groups = { lab-admins = "a", lab-team = "t", prod-team = "no" }
  }
  expect_failures = [var.groups]
}

run "admin_not_in_audience_is_rejected" {
  command = plan
  variables {
    jira = {
      scheme  = { name = "LAB Restricted", audience_groups = ["lab-team"], admin_groups = ["lab-admins"] }
      project = { key = "LABR", name = "LAB Restricted", type = "software", template = "x", lead_account_id = "u" }
    }
  }
  expect_failures = [var.jira]
}

run "undeclared_group_in_space_audience_is_rejected" {
  command = plan
  variables {
    confluence = { space = { key = "LABP", name = "LAB Private", audience_groups = ["lab-team", "finance-all"] } }
  }
  expect_failures = [var.confluence]
}

run "non_internal_classification_is_rejected" {
  command = plan
  variables {
    governance = { business_authority = "BA-LAB-001", classification = "Confidential", standard = "restricted-collab-v1", authority_records = [] }
  }
  expect_failures = [var.governance]
}

run "unversioned_standard_is_rejected" {
  command = plan
  variables {
    governance = { business_authority = "BA-LAB-001", classification = "Internal", standard = "restricted-collab", authority_records = [] }
  }
  expect_failures = [var.governance]
}

run "same_person_as_admin_and_reviewer_is_rejected" {
  command = plan
  variables {
    identities = { admin = "a", reviewer = "a", allowed = "x", denied = "y" }
  }
  expect_failures = [var.identities]
}

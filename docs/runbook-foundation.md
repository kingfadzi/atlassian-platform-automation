# Foundation runbook

Every control in `policy/foundation.yaml` carries `provision: engine | runbook | external`. That
says who makes the setting true, not whether the engine can read it.

- `engine` — created by `stages/foundation/provision.tf` from policy, then read back as a fact.
- `runbook` — no public write API; a person does it once in the admin console.
- `external` — owned by another system, verified only.

Every control, whatever its `provision`, compares something declared against what the tenant
reports. A requirement the engine cannot read is not a control: it lives in `policy/unchecked.yaml`
and `make <phase>` lists it as a step, with the probe that settled it.

## Doing a console step

- `make <phase>` prints the `where` and `todo` of anything outstanding, from the catalogue itself.
- Do the step in the console. There is nothing to record afterwards: the engine reads the tenant on
  the next plan and the control clears on its own.
- Nothing is attested. A date in a file proves nothing and cannot detect the setting being changed
  back, which is what this repository exists to catch.

## What the plan allows

- Read the foundation output `entitlement`, and the reported controls `jira_plan_paid` and
  `confluence_plan_above_free`.
- On a Free plan several console steps cannot be done at all. Confluence Free has no global or space
  permission settings, so "Create space" cannot be held to the engine group.
- A step the plan does not allow stays outstanding. That is the honest state; there is no way to
  mark it done.
- Decision for the lab: validate on a Confluence Standard trial so space creation can be performed.
- A firm tenant flips both entitlement controls to mandatory.

## When a control reports unknown

- `unknown` means the engine could not read the tenant, and counts as unsatisfied for a mandatory
  control. It never passes by default.
- A group named in `policy/identities.yaml` `admin_groups` that does not exist on the site leaves
  `site_admin_accounts` unknown and `admins_are_listed` blocks. Deliberate: a wrong policy must not
  let readiness pass. Fix the list; the engine never guesses a group.
- An account in `foundation.accounts` that Jira does not know returns 404, leaving
  `accounts_holding_disallowed_permissions` unknown. Fix the list rather than the control.

## Global permissions

- Jira has no API listing who holds a global permission, but `POST /rest/api/3/permissions/check`
  answers for any `accountId`. `account_global_permissions` asks per declared account and reports
  anything outside what its `kind` allows in `policy/identities.yaml`.
- This covers declared accounts only. A group granted a permission, holding accounts nobody
  declared, is caught by neither this nor `admins_are_listed`.
- Confluence has no equivalent read. Space creation is a documented step, not a control.

## Asset-treatment service (policy/treatment.yaml)

The engine provisions the `ATS` service project, the `Asset` issue type (and adds it to the
project's issue type scheme), the five Asset fields and the four request types. Three things remain
console work:

| | Where | What to do |
|---|---|---|
| portal layout (no control) | ATS > Project settings > Request types | Put the Asset fields (Platform standard, Instance key, Owner authority, Classification, Review date) on each request form and on the Asset issue screens. |
| `asset_workflow_built` (control) | ATS > Project settings > Workflows | Build the Asset workflow exactly as `jsm/asset-workflow.yaml` declares and assign it to the Asset issue type. |
| `automation_rules_imported` (step) | ATS > Project settings > Automation > Import | Fill the `{{ }}` placeholders from `contracts/<env>.json`, import `jsm/automation-rules.json`, enable the rules. |

- The workflow is a control: Jira reports its statuses and transitions, so `asset_workflow_gaps`
  names anything declared that the tenant does not have. The spike proves it (`[workflow]`).
- The automation rules are a step: Jira exposes no read for them, so editing the file changes what
  an operator must import and nothing can confirm they did.
- Readiness dimension `treatment` reports the service; nothing depends on it yet.

## Recovering a provisioned setting removed out of band

The REST provider in use (Mastercard/restapi 3.0.0) does not drop an object from state when the
tenant answers 404 on refresh ([issue 377](https://github.com/Mastercard/terraform-provider-restapi/issues/377)).
A grant, role or scheme deleted by an administrator is therefore detected from the tenant read
(`scheme_grants_match_standards`, `roles_match_standards`, `scheme_per_standard_present`), not from
the plan. Recovery:

```
terraform -chdir=stages/foundation state rm 'module.scheme["restricted-collab-v1"].restapi_object.grant["ADD_COMMENTS:member"]'
terraform -chdir=stages/foundation plan     # exactly one create
```

Then let the pipeline apply it. The spike proves this path (`tests/spike.sh`, "[provision]").
The `state rm` is the operator's investigation step the gate's `drift.delete_blocks` rule asks for;
nothing else is touched, and `prevent_destroy` and the gate still refuse every delete, update and
replace. An `import` is refused outright (`gate.yaml` `refuse_import`): the platform creates its own
objects and never adopts an existing one.

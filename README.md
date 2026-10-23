# Atlassian platform automation

Terraform owns state, diff, plan files, import and drift; the generic REST provider owns HTTP;
GitLab owns approvals and scheduling. The only Python is `govern/`, which gates plan JSON on the
rules in `policy/gate.yaml`. Nothing is ever deleted or updated by automation: `prevent_destroy`
on every resource, blocked actions in the gate, and no destroy job in the pipeline.

| You want to | Edit |
|---|---|
| Add or rename a group, asset or audience | `envs/lab/lab.tfvars` |
| Change a structural rule (scope, subsets, classification) | `envs/shared/intent_variables.tf` |
| Change what the gate blocks or reports | `policy/gate.yaml` |
| Add a resource kind | a new folder under `modules/` with one `restapi_object`, a `check`, and a stage wiring |
| Add an observation or probe | a `data "http"` plus a `check` in `stages/bootstrap` or `stages/release` |

## Layout

```
envs/lab/lab.tfvars            intent (operator surface, no secrets)
envs/shared/*.tf               intent rules, provider aliases, credentials, backend; symlinked into stages
stages/{bootstrap,identity,admit,release}   one root module and one GitLab state each
modules/*                      directory_group, jira_permission_scheme, jira_project, confluence_space, confluence_space_permission
policy/gate.yaml               gate rules
govern/                        gate, currency, review, cli (about 200 lines)
tests/intent                   terraform test for the intent rules (no tenant needed)
tests/govern                   gate unit tests on recorded plan JSON
tests/stub, tests/spike.sh     stateful stub of the Atlassian endpoints and the end-to-end spike
```

## Local

```
make check                     fmt, validate, terraform test, gate tests
make spike                     every stage against the stub: create, three clean re-plans, drift, destroy refusal
```

## Lab tenant

What you need from the tenant, once:

- Organisation id and an organisation API key: admin.atlassian.com > Settings > API keys (the org id is in the URL).
- Directory id: run the bootstrap stage; its `directory_ids` output lists them.
- An API token for the automation identity (id.atlassian.com > Security > API tokens) and one each for the allowed and denied probe identities.
- The automation identity's `accountId` for `lead_account_id`: bootstrap output `automation_account_id`.


Set `tenant` in `envs/lab/lab.tfvars` from the bootstrap output, export the credentials as
`TF_VAR_*`, then run the pipeline. Locally: `terraform -chdir=stages/bootstrap plan -var-file=../../envs/lab/lab.tfvars`
with a `backend_override.tf` for local state.

## Requirements and controls

Requirements, the control register and the FS-COLLAB-01 profile live in `kingfadzi/atlassian-cloud`.
The embedded-Python MVP that preceded this implementation is in this repository's history up to
commit 5318656.

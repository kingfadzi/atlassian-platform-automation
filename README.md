# Atlassian platform automation

Terraform owns state, diff, plan files, import and drift; the generic REST provider owns HTTP;
GitLab owns approvals and scheduling. The only Python is `govern/`, which gates plan JSON on the
rules in `policy/gate.yaml`. Nothing is ever deleted or updated by automation: `prevent_destroy`
on every resource, blocked actions in the gate, and no destroy job in the pipeline.

| You want to | Edit |
|---|---|
| Add or rename a group, asset or audience | `envs/lab/lab.tfvars` |
| Change a structural rule (classification, patterns, subsets) | `policy/intent_rules.yaml` |
| Change what an asset standard grants or expects | `policy/standards/<id>.yaml` (a changed standard is a new file with `supersedes`) |
| Change what the gate blocks or reports | `policy/gate.yaml` |
| Add, retire, tighten or re-scope a shared foundation control | `policy/foundation.yaml` (`fact` + `require` + `provision`) |
| Change the role set or what each role may do | `policy/standards/<id>.yaml` (`roles`, `jira.role_permissions`, `confluence.space_roles`) |
| Add or review an admin, engine or emergency account | `policy/identities.yaml` |
| Do a console-only foundation step and record it | `docs/runbook-foundation.md`, then `runtime/<env>/attestations.yaml` |
| Read a new property of the tenant | one fact block in `stages/foundation/facts.tf` (plus its `data "http"` in `observe.tf`) |
| Record a manual foundation setting | `runtime/<env>/attestations.yaml` |
| Add a resource kind | a new folder under `modules/` with one `restapi_object`, a `check`, and a stage wiring |
| Add an observation or probe | a `data "http"` plus a `check` in `stages/bootstrap` or `stages/release` |

## Layout

```
envs/lab/lab.tfvars            intent (operator surface, no secrets)
envs/shared/*.tf               intent shape and validations (rules read from policy/), providers, credentials, backend; symlinked into stages
stages/{bootstrap,identity,foundation,admit,release}   one root module and one GitLab state each
stages/foundation/provision.tf what the engine provisions from policy: site-wide roles, one scheme per standard
stages/foundation/facts.tf     how each tenant property is read; the fact vocabulary the catalogue may use
modules/*                      directory_group, jira_project_role, jira_permission_scheme, jira_project, jira_project_role_actors, confluence_space, confluence_space_permission
modules/control_evaluation     generic fact-versus-requirement evaluation (no control ids inside; own terraform tests)
policy/gate.yaml               gate rules, currency windows, policy files hashed into the ledger
policy/foundation.yaml         shared foundation catalogue: per control a fact, a requirement and who provisions it
policy/standards/<id>.yaml     asset standards (roles, role grants, operations, templates, probe expectations)
policy/identities.yaml         exceptional identities: admin, engine and emergency accounts with owner and review date
policy/intent_rules.yaml       structural rules the intent must satisfy
govern/                        gate, currency, review, provenance, cli (about 240 lines)
docs/policy-as-data.md         the three-layer rule: requirements, facts, evaluation
docs/runbook-foundation.md     console-only steps, how to attest them, recovery of provisioned settings
tests/intent                   terraform test for the intent rules (no tenant needed)
tests/govern                   gate unit tests on recorded plan JSON
tests/stub, tests/spike.sh     stateful stub of the Atlassian endpoints and the end-to-end spike
```

## Lifecycle

bootstrap (observe tenancy) → identity (groups) → foundation (provision roles and schemes, then probe,
observe, attest) → admit (project on the standard's scheme, groups bound to roles, space) → release
(allowed/denied/anonymous probes) → operate (scheduled drift).
Foundation publishes `ready = { jira, confluence }`; admit reads it through `terraform_remote_state`
and refuses to plan a product's assets unless that product is ready and the evaluation is newer than
`windows_days.foundation`. A failing mandatory control blocks only the products that depend on it.
Lab mandatory core: anonymous Jira closed, anonymous Confluence closed, no public scheme grants,
audit collection live, public links attested off, plus the provisioned foundation (roles, scheme per
standard and its grants, Confluence space roles), native project and space creation closed, and
exceptional identities listed and reviewed. The other ten controls are reported, not blocking.
Each control says who makes it true (`provision: engine | runbook | external`); the engine never
takes its own apply as proof and reads everything back from the tenant.

Requirements are data and will change; see `docs/policy-as-data.md`. A control is a fact plus a
requirement in `policy/foundation.yaml`; an asset standard is a file in `policy/standards/`; the
HCL that evaluates them knows no control by name. Every gate decision records the hashes of the
policy files it was made under.

## Local

```
make check                     fmt, validate, terraform test (intent rules, evaluation operators), gate tests
make spike                     every stage against the stub: create, three clean re-plans, drift, out-of-band removal detected and recovered, foundation block, YAML-only policy change, destroy refusal
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

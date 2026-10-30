# Atlassian platform automation

A desired-state controller for an Atlassian Cloud estate. GRC policy becomes YAML rules here; the
engine provisions and converges the platform (foundation settings, site-wide roles, one permission
scheme per standard) and judges every instance JSM creates from those templates. Terraform owns
state, diff, plan files and drift; the generic REST provider owns HTTP; GitLab owns approvals and
scheduling. The only Python is `govern/`, which gates plan JSON on `policy/gate.yaml`. Nothing is
ever deleted or updated by automation: `prevent_destroy` on every resource, blocked actions in the
gate, no destroy job. The repo holds no instance: no project, space, group or person.

| You want to | Edit |
|---|---|
| Change what the foundation must look like | `policy/foundation.yaml` (`fact`, `require`, `provision`, `mandatory`) |
| Change a template: roles, grants, project types, lifecycle windows | `policy/standards/<id>.yaml` (a changed standard is a new file with `supersedes`) |
| Change what an instance must satisfy, or what happens when it does not | `policy/conformance.yaml` (`controls`, `action`, `enabled_actions`) |
| Change the asset-treatment service: request types, Asset fields, project | `policy/treatment.yaml`; workflow and automation in `jsm/` (imported by hand, attested by hash) |
| Change who may hold admin, engine or emergency access | `policy/identities.yaml` |
| Change what the gate blocks or reports | `policy/gate.yaml` |
| Do a console-only foundation step and record it | `make <phase>` prints where and what; record it in `records/<env>/attestations.yaml` |
| Point at a tenant | `envs/<env>/<env>.tfvars`: organisation, directory, site URL, AD group pattern |
| Read a new property of the tenant or of an instance | one fact block in `stages/foundation/facts.tf` or `stages/estate/facts.tf` (plus its `data "http"`) |
| Add a provisioned resource kind | a new folder under `modules/` with one `restapi_object` and a `check`, wired in `stages/foundation/provision.tf` |

## Boundaries

What the engine does.

- Provisions everything above the tenancy as code.
- Proves the tenancy itself was established correctly and has not drifted.
- Judges every instance against the standard it names.

What the engine never does. No API exists for any of it; these are signup, console or procurement acts.

- Create an organisation, a site or a product.
- Choose data residency. It is selected when a site is created and is not reversible afterwards.
- Verify a domain, buy a subscription, or configure SAML.
- Create an account, a group, or a group membership.

Identity boundary.

- The identity provider owns principals: accounts, group existence, group membership.
- The engine owns containers and grants: project roles, permission schemes, issue security, space permissions.
- Groups are referenced by name, never created.
- `tenant.group_pattern` asserts which group names the identity provider owns.
- `groups_match_ad_pattern` catches a locally created group bound to a role.
- An earlier `directory_group` module created groups. Removed deliberately; it must not return.

## Layout

What you edit.

```
envs/<env>/<env>.tfvars        tenant coordinates: organisation, directory, site URL, AD group pattern
policy/phases.yaml             the stand-up sequence: what each phase covers and who acts
policy/foundation.yaml         shared controls: a fact, a requirement, who provisions it, and the console step
policy/standards/<id>.yaml     templates: roles, per-role grants, space roles, project types, lifecycle windows
policy/conformance.yaml        instance controls, the action rung per control, stamp and public-access definitions
policy/treatment.yaml          the asset-treatment service: JSM project, Asset issue type and fields, request types, imports
policy/identities.yaml         exceptional identities: admin, engine and emergency accounts, with owner and review date
policy/intent_rules.yaml       naming rules, and the realms each environment may place data in
policy/gate.yaml               what the gate blocks or reports, currency windows, policy files hashed into the ledger
jsm/                           declared workflow and automation rules for the service, attested by file hash
records/<env>/                 attestations, authority and exceptions you record after a console step
```

What you read.

```
make, make <phase>             where the platform stands and what is outstanding
docs/policy-as-data.md         the three layers: requirements, facts, evaluation
docs/runbook-foundation.md     recording an attestation, what a plan allows before you attest, recovery
docs/conformance.md            how an instance is classified and judged, and the rung a deviation earns
contracts/<env>.json           written after the foundation apply; what JSM reads to create instances
```

Machinery. An operator never opens these.

```
stages/tenancy                 observe the organisation, its products and the engine identity
stages/foundation              provision roles and a scheme per standard, stand up the service, then observe and judge
stages/estate                  discover every project and space, then judge each against the standard it claims
envs/shared/*.tf               input shape and validations, providers, credentials, backend; symlinked into stages
modules/                       one restapi_object per resource kind, plus control_evaluation (generic, own tests)
govern/                        the gate, currency, review, provenance, the status view, cli
tests/                         input rules, gate units, the stub tenant and the end-to-end spike
```

## Lifecycle

tenancy (observe tenancy) → foundation (provision templates and the asset-treatment service, then
probe, observe, attest; publish `ready = { jira, confluence, treatment }` and `contract`) → estate (discover instances, classify by stamp or scheme, evaluate, act by
rule) → operate (scheduled: foundation drift and estate conformance, gate writes the ledger).

Every foundation control says who makes it true: `engine` (provisioned here from policy), `runbook`
(console only, done once by a named operator and attested, see `docs/runbook-foundation.md`) or
`external` (identity provider, AD, Atlassian rollout; verified only). An apply is never proof: what the
engine creates is read back from the tenant and judged like any other fact. Lab mandatory core:
anonymous Jira and Confluence closed, no public scheme grants, audit collection live, public links
attested off, the provisioned templates present and complete, Confluence space roles available, native
project and space creation closed, exceptional identities listed and reviewed. Twelve further
controls are reported, not blocking.

Instances are created through the asset-treatment service (`ATS`, a JSM project the foundation
provisions with an `Asset` issue type, its fields and onboard, change, review and retire request
types): the request creates the project on the standard's
scheme, binds each platform role to an AD group and stamps the standard id (`platform.standard`
project property, `platform-standard-<id>` space label). `estate` finds every instance, judges it
against `policy/conformance.yaml` and the values of its standard, and assigns the failing controls a
rung: `report`, `flag`, `restrict` or `archive`. Delete is not a rung. Every instance is also
linked to its `Asset` record in the service (`asset_record_present`), which is where `flag` will
land. Only `report` has an executor so far; the others appear as planned actions.

Requirements are data and will change; see `docs/policy-as-data.md` and `docs/conformance.md`. The
HCL that evaluates them knows no control, standard or instance by name. Every gate decision records
the hashes of the policy files it was made under.

## Local

```
make                           the stand-up sequence and where you are in it
make <phase>                   one phase: what is required, what is outstanding, and who owes it
make status                    every phase at once
make try                       tenancy, foundation and estate against the stub: create, three clean re-plans, drift reported,
                               removed grant detected and recovered, ten seeded instances judged against their Asset records,
                               stale foundation refused, YAML-only changes flip readiness and a verdict, an edited jsm/ file
                               invalidates its attestation, removal from policy refused
make check                     fmt, validate, terraform test (input rules, evaluation operators), gate tests
make deps                      the local Python environment
```

## Lab tenant

What you need from the tenant, once:

- Organisation id and an organisation API key: admin.atlassian.com > Settings > API keys (the org id is in the URL).
- Directory id: run the tenancy stage; its `directory_ids` output lists them.
- An API token for the engine identity (id.atlassian.com > Security > API tokens).
- The console-only steps in `docs/runbook-foundation.md`, recorded in `records/lab/attestations.yaml`.

Set `tenant` in `envs/lab/lab.tfvars` from the tenancy output, export the credentials as
`TF_VAR_*`, then run the pipeline. Locally: `terraform -chdir=stages/tenancy plan -var-file=../../envs/lab/lab.tfvars`
with a `backend_override.tf` for local state.

## Known limit

Mastercard/restapi 3.0.0 does not drop an object from state when the tenant answers 404 on refresh
([issue 377](https://github.com/Mastercard/terraform-provider-restapi/issues/377)). Deletions of
provisioned objects are therefore detected from the tenant read (`scheme_grants_match_standards`,
`roles_match_standards`, `scheme_per_standard_present`) and recovered as described in the runbook.

## Requirements and controls

Requirements, the control register and the FS-COLLAB-01 profile live in `kingfadzi/atlassian-cloud`.
The embedded-Python MVP that preceded this implementation is in this repository's history up to
commit 5318656; the per-asset admit and release stages up to commit 94fad8b.

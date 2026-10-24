# Estate conformance

The engine holds no list of instances. `stages/conform` discovers every Jira project and Confluence
space in the tenant, works out which template each belongs to, judges it against
`policy/conformance.yaml` with the values of its standard, and assigns each failing control a rung.
It runs after the foundation and refuses a foundation evaluation older than `windows_days.foundation`.

## Classification

An instance names its template with a stamp set by JSM at creation: the project property
`platform.standard` (value: standard id) or the space label `platform-standard-<id>`. Without a
stamp a project is classified by its permission scheme (the foundation's contract maps scheme id to
standard); anything else is judged against `fallback_standard`. A missing stamp is itself a finding
(`stamped_with_standard`), so an instance created outside JSM shows up on the first run.

## Facts, controls, rungs

Per-instance facts are listed at the top of `stages/conform/facts.tf`. A control is a fact, a
requirement (same eight operators as the foundation) and an `action`:

| Rung | Meaning | Executor |
|---|---|---|
| `report` | finding in the conform output and the gate ledger | now |
| `flag` | comment and status on the instance's `Asset` record in JSM | phase 3 |
| `restrict` | remove or re-attach an engine-owned setting (for example put a project back on its standard's scheme) as a gated apply | phase 4 |
| `archive` | archive the instance after its window, as a gated apply | phase 4 |

Delete is not a rung and the policy file is validated against it. `enabled_actions` lists the
rungs the engine may perform in the environment; a failing control whose rung is not enabled is
reported with `performed: report` and the intended rung, so the policy can be written ahead of
the executor and the output shows what would happen.

## What conform never does

Create a project or space; create or change a group; remove a group from a role (offboarding is a
JSM request); delete anything. Its only resources are `terraform_data` preconditions, so a plan
with any create, update or delete here is a defect the gate will block.

## Outputs

`instances` (per `kind:key`: standard, verdict per control, actions), `findings` (one line per
failing control), `summary` (counts by standard, non-conforming, unstamped). The check
`report_estate` is report-only: a non-conforming estate never blocks the run that found it.

## Scale note

The lab reads one request per project for its scheme and one per (project, platform role) for the
actors, and four per space. Before an estate of hundreds, paginate `project/search` and `spaces`
and consider a nightly schedule split by product.

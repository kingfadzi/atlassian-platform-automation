# Policy as data

The standards and controls in this repository are a starting point. They will change, partly or
completely, when the real environment is known, and they will keep changing after that. No
requirement is therefore allowed to live in logic as if it were true. This page is the rule that
keeps it that way and the shape the implementation follows.

## The three layers

| Layer | Holds | Form | Changes when |
|---|---|---|---|
| Requirements | what is required, of whom, since when, how strictly | versioned YAML under `policy/` | the firm's rules or the control register change |
| Facts | how a property of the tenant is read: endpoint, parsing, shape | one HCL block per fact in `stages/foundation/facts.tf` | Atlassian changes an API, or a genuinely new property is needed |
| Evaluation | compare each fact with its requirement using a declared comparison; derive readiness | `modules/control_evaluation`, generic | rarely, and never for a single control |

Routine change is confined to the first layer. The evaluation contains no control id, threshold,
permission name, status code, classification or pattern; `terraform test` enforces the shape and
the stub spike proves that a requirement edited in YAML alone changes readiness.

## Requirement or fact?

Ask one question before any change: can it be expressed as a different value, scope, threshold,
window, date or mandatory flag? If yes it is a requirements change and touches YAML only. If it
needs a new way of reading the tenant, it is a new fact: one block in `facts.tf`, documented in the
vocabulary at the top of that file, and then usable from YAML. Nothing else moves.

## The requirement files

- `policy/foundation.yaml`: the shared foundation catalogue. Each control names a `fact` and a
  `require` (`op` plus `value` or `value_from`), with `mandatory`, `depends`, `register`,
  `effective_from` and an optional `lab: not_applicable`.
- `policy/standards/<id>.yaml`: a template. Roles, per-role grants, space roles, project types,
  lifecycle windows and the description template live here. The foundation provisions one scheme
  per standard from it; `estate` judges instances against it. Modules carry no policy defaults.
- `policy/conformance.yaml`: what every instance must satisfy, the rung (`report`, `flag`,
  `restrict`, `archive`) for each failing control, how instances name their template (`stamp`) and
  what counts as public access.
- `policy/identities.yaml`: the exceptional identities (admin, engine, emergency) with owner, scope
  and review date; `admins_are_listed` and `exceptional_identities_reviewed` read it.
- `policy/intent_rules.yaml`: naming rules for what the engine provisions (standard ids, role names).
- `policy/gate.yaml`: what the gate blocks or reports, the currency windows, and `policy_files`.

Every file has a `version` or `effective_from` and a `register` reference where one exists, so a
change can be traced to the register entry that caused it.

## Comparison operators

Eight, and the set is a ceiling: `equals`, `empty`, `at_least`, `within_days`,
`attested_within_days`, `superset_of`, `subset_of`, `contains`. `value_from` takes the required
value from the stage's intent map instead of a literal (`foundation.*` from tfvars, `policy.*`
derived from the policy files, `standard.*` and `tenant.*` per instance in `estate`); when it
resolves to null or an empty collection the control is `not_applicable` because there is nothing
to require. A number is always applicable. A fact that could
not be read gives `unknown`, which counts as unsatisfied for a mandatory control. When a requirement
cannot be stated with these operators the review question is "which fact is missing", not "which
operator should we add". A catalogue naming a fact that is not observed, or an operator outside the
eight, fails at plan time.

## Provenance

Every ledger entry written by `govern gate` records the sha256 of each file listed in
`policy_files` (the standards directory contributes every file in it) and the policy versions the
plan published (`policy_version` from foundation). A later change to any
requirement shows as a different hash; review records stay bound to the rules of the day.

## Lifecycle of a requirement

- New control on an existing fact: add an entry to `policy/foundation.yaml`.
- New control on a new property: one fact block, then the entry.
- Tightened or relaxed requirement: edit `value`, `mandatory` or the window; the catalogue `version`
  (a date, `YYYY-MM`) moves with it.
- New or changed standard: a new file with `supersedes`; the old file stays in `policy/standards/`
  so instances created under it remain explainable; `estate` reports them as `standard_current` findings.
- `effective_from` annotates when a requirement took effect; it does not schedule or hide a control.

## What is deliberately not here

Facts are still code and product specific. That is correct: reading an Atlassian endpoint is an
engineering concern, and hiding it behind generated YAML would make it harder to maintain, not
easier. The validations read small files on every plan; keep the rules files short.

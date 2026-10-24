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
- `policy/standards/<id>.yaml`: an asset standard, selected by `governance.standard` in the
  intent. Permission sets, operations, assignee type, project types, the description template and
  the release probe expectations live here. Modules carry no policy defaults.
- `policy/intent_rules.yaml`: structural rules the intent must satisfy, read by the variable
  validations (admitted classifications, patterns, subset and declaration rules, distinct identities).
- `policy/gate.yaml`: what the gate blocks or reports, the currency windows, and `policy_files`.

Every file has a `version` or `effective_from` and a `register` reference where one exists, so a
change can be traced to the register entry that caused it.

## Comparison operators

Eight, and the set is a ceiling: `equals`, `empty`, `at_least`, `within_days`,
`attested_within_days`, `superset_of`, `subset_of`, `contains`. `value_from` takes the required
value from the intent's `foundation` object instead of a literal; when it resolves to an empty
list the control is `not_applicable` because the intent has nothing to require. A fact that could
not be read gives `unknown`, which counts as unsatisfied for a mandatory control. When a requirement
cannot be stated with these operators the review question is "which fact is missing", not "which
operator should we add". A catalogue naming a fact that is not observed, or an operator outside the
eight, fails at plan time.

## Provenance

Every ledger entry written by `govern gate` records the sha256 of each file listed in
`policy_files` (the standards directory contributes every file in it) and the policy versions the
plan published (`policy_version` from foundation, `standard` from admit). A later change to any
requirement shows as a different hash; review records stay bound to the rules of the day.

## Lifecycle of a requirement

- New control on an existing fact: add an entry to `policy/foundation.yaml`.
- New control on a new property: one fact block, then the entry.
- Tightened or relaxed requirement: edit `value`, `mandatory` or the window; the catalogue `version`
  (a date, `YYYY-MM`) moves with it.
- New or changed standard: a new file with `supersedes`; the old file stays in `policy/standards/`
  so assets admitted under it remain explainable.
- `effective_from` annotates when a requirement took effect; it does not schedule or hide a control.

## What is deliberately not here

Facts are still code and product specific. That is correct: reading an Atlassian endpoint is an
engineering concern, and hiding it behind generated YAML would make it harder to maintain, not
easier. The validations read small files on every plan; keep the rules files short.

# Atlassian Platform Automation

Initial scaffold | 22 October 2026

**Version intent, apply only authorised changes, verify the result and retain evidence.** This repository is the implementation starting point for the governed Atlassian platform, not another strategy pack or an implemented control plane.

## Current state

| Area | Status |
| :--- | :--- |
| **Governance** | Source revisions pinned; all 52 CCM entries indexed; 22 `FS-COLLAB-01 v0.1` parameter groups encoded as **assumed**. |
| **Local checks** | YAML/JSON parsing, JSON Schema validation, cross-reference checks and scaffold tests. No policy decision or live access test is implemented. |
| **Examples** | Draft Jira/Confluence patterns, unbound lab configuration and explicitly synthetic fixtures. |
| **Execution** | No policy engine, CI platform, configuration engine or live adapter selected. `plan`, `apply`, `verify` and `observe` deliberately exit nonzero. |
| **Git** | Private repository: [kingfadzi/atlassian-platform-automation](https://github.com/kingfadzi/atlassian-platform-automation). No tenant connection is configured. |

## Quick start

Requires Python 3.11+ and Make for local development checks. Python is a scaffold-validation tool here, not a selection of the eventual execution runtime.

```sh
git clone https://github.com/kingfadzi/atlassian-platform-automation.git
cd atlassian-platform-automation
make bootstrap
make validate
make test
make check
make status
```

`bootstrap` installs development dependencies into `.venv`; it needs package-index access. Validation and tests run offline after installation, and do not read tenant credentials.

```sh
make plan       # BLOCKED; intentionally nonzero
make apply      # BLOCKED; intentionally nonzero
make verify     # BLOCKED; intentionally nonzero
make observe    # BLOCKED; intentionally nonzero
```

No confirmation flag, environment variable or fixture approval enables live execution. Implement and review the missing contracts before replacing these guards.

To check the source pins against a local strategy clone without network access:

```sh
make check-sources STRATEGY_REPO=/path/to/atlassian-cloud
```

This verifies source bytes and the extracted control/parameter bindings at the pinned commit. It does not prove that prose-to-configuration interpretation is complete or that the profile is firm-approved.

## Layout

```text
governance/       Source pins, provisional parameters, control bindings
contracts/       Input, pattern, profile and evidence JSON Schemas
policy/          Policy requirements; executable engine not selected
patterns/        Draft foundation, Jira and Confluence intent
environments/    Unbound lab bindings, capability prerequisites, asset examples
execution/       Adapter contracts; no remote implementation
pipelines/       CI-neutral change/observation contract
tests/           Offline scaffold tests and synthetic fixtures
tools/           Local validation and explicit blocked-command guards
operations/      Bootstrap, drift, monitoring, partial failure and recovery
```

## Operating rules

- **Authority is external:** consume current application, owner, classification, approval and exception records. An editable file or merged change does not replace those decisions.
- **Fixtures are not decisions:** `synthetic: true` data models inputs for tests only. Schema-valid or fixture-approved does not mean release-approved.
- **Manage explicit scope:** adopt resources/properties deliberately; an omitted declaration never authorises deletion.
- **Foundation precedes release:** verify identity, sharing, execution and audit prerequisites before a dependent asset can be released.
- **Keep runtime data outside Git:** secrets, authoritative records, observed state, generated native IDs, plans, checkpoints, cursors and retained evidence belong in protected runtime services.
- **Evidence remains categorical:** operational logs and material decision records have different schedules. CI artifacts do not automatically meet protected or long-term retention requirements.
- **Do not manufacture API coverage:** unsupported, deprecated, experimental and untested paths remain explicit limitations.

## First implementation

Choose one Jira or Confluence path after establishing foundation prerequisites. Prove current synthetic inputs, policy denial/permission, bounded application, real allowed/denied access, evidence output, repeat-run safety, drift detection and partial-failure recovery.

No migration factory, production-copy service, archive service or Rovo rollout is implemented. Existing strategy and requirements remain in the [strategy repository](https://github.com/kingfadzi/atlassian-cloud); this project pins them rather than copying the documents.

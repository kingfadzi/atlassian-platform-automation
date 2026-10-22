# Atlassian Platform Automation

**Declare intent, apply authorised changes, verify the outcome, retain evidence.** Start with ordinary configuration and small scripts; add abstractions only when working implementations need them.

## What is here

```text
controls.yaml           Pinned requirements, 52 control mappings and review cadences
config/profile.yaml     All 22 provisional FS-COLLAB-01 parameter groups
config/lab.yaml         Foundation scope and two synthetic asset declarations
config/schema.yaml      One standard JSON Schema for lab input validation
scripts/check.py        Offline validation and optional source verification
tests/test_check.py     Tests for those checks, not control acceptance
```

**This is an input scaffold, not a working control plane.** It has no tenant connection, executable policy, API adapter, state service or deployment pipeline.

## Run

Requires Python 3.11+ and Make. Python is used for these checks; the execution runtime, policy engine and CI platform remain undecided.

```sh
make bootstrap
make check
# Optional: verify register/assessment bytes and control mappings against a local clone.
make check-sources STRATEGY_REPO=/path/to/atlassian-cloud
```

Dependency installation needs package-index access; subsequent checks run offline. There are no pretend `plan`, `apply`, `verify` or `observe` commands.

## Configuration and authority

- **Requirements:** `controls.yaml` pins the [strategy repository](https://github.com/kingfadzi/atlassian-cloud), register and coverage assessment. All controls remain unimplemented and untested.
- **Policy inputs:** `config/profile.yaml` preserves `FS-COLLAB-01 v0.1` as **assumed, not firm-approved**. Its snapshot hash detects unintended changes; an intentional revision must update both the profile and its pin.
- **Managed scope:** `config/lab.yaml` identifies foundation properties and example Jira/Confluence assets. Profile parameters supply required outcomes; the YAML is not a new policy language or provider configuration.
- **Product standards:** Jira starts with a company-managed project; Confluence starts with a private space. Business ownership does not imply native administration; confirm the tenant's Confluence access model before choosing APIs.
- **External authority:** business application, ownership, classification, approval and exception decisions must come from designated sources at execution time. `fixture:` references are unresolved synthetic placeholders, not approval records.
- **Platform prerequisites:** prove identity, sharing, integration/egress, supported data placement and audit controls before releasing an asset. A SaaS perimeter does not imply that all traffic passes through the firm's network.
- **Honest coverage:** unsupported, deprecated, manual and untested capabilities remain explicit gaps. Input validation does not prove API support, policy correctness or compliance.

## First working path

Implement one bounded path after its foundation prerequisites. Keep product-specific code in a plain script initially; choose an established policy/configuration tool where it demonstrably helps.

| Step | Required outcome |
| :--- | :--- |
| **Check authority** | Resolve current application, owner, classification and scoped approval; reject missing, stale, conflicting or revoked inputs. P-13 source freshness limits remain unresolved. |
| **Observe and plan** | Read real state; limit changes to declared properties; bind the plan to the candidate, target and authority. Omission never authorises deletion. |
| **Approve and apply** | Keep technical review separate from business authority. Recheck both state and authority before writes; account for shared-scheme impact and overlapping changes. |
| **Verify and record** | Read back and test actual permitted/denied access. Mark partial application incomplete; keep the asset restricted until verification and registration succeed. |
| **Operate** | Repeat without unnecessary writes; detect drift independently of merges. Never restore withdrawn access; unreadable state is unknown. |

Prove **repeat-run safety, denied access, drift, stale authority and partial-failure recovery** with synthetic data. Do not count scaffold tests as acceptance of any of the 52 controls.

## Operating boundaries

- **Git holds intent:** keep secrets, authoritative records, native IDs, observed state, plans, checkpoints, event cursors and retained evidence in protected runtime services, not this repository.
- **Recovery is explicit:** preserve progress, reread uncertain results and revalidate authority before retrying. A Git revert does not reverse SaaS effects.
- **Observation has deadlines:** P-12 sets critical/other observation limits; P-18 requires independent collection-health detection and notification. Event silence is not proof of health.
- **Evidence has categories:** P-16 covers operational logs; P-17 covers material decisions. CI artifacts alone do not provide protected retention, integrity or independent retrieval.
- **Lab isolation:** synthetic data and isolated lab credentials only. No production-copy, migration, archive or Rovo service is enabled.

The full control detail stays in the pinned register and profile. Add policy modules, adapters, scheduled jobs and evidence integration when implementing them, not as empty folders in advance.

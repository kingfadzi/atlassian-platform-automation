# Atlassian Platform Automation

Declare intended state, evaluate policy, apply authorised changes,
verify the outcome and retain evidence.

## Structure

| Area | Owns | Extension point |
|---|---|---|
| policy/ | Control mappings, parameter profiles and embedded decisions | Add a profile or ordinary decision functions with tests. |
| config/ | Environment declarations, reusable standards and schemas | Add an environment, asset declaration or supported standard. |
| automation/ | Platform operations and external integrations | Add an operation or source/destination integration. |
| tests/ | Evidence of implementation behaviour | Add decision, operation and authorised acceptance tests. |
| pipelines/ | Execution order, gates and schedules | Add a change, observation or recovery workflow. |

Create subdirectories when they contain a real implementation.
Do not populate the repository with placeholder adapters or workflows.

## Current capability

- Validate the synthetic lab configuration and its managed scope.
- Check all 52 control mappings and 22 provisional parameter groups.
- Detect unintended changes to the pinned profile.
- Optionally verify requirements against a local strategy checkout.
- Evaluate scoped synthetic authority and bootstrap prerequisites.
- Plan, create and verify one restricted Jira project and Confluence space.
- Prepare and verify a dedicated Jira permission scheme before project creation.
- Repeat verified runs without unnecessary writes or duplicate resources.
- Recover positively identified committed writes after lost responses.
- Block unresolved outcomes, drift, expired authority and implicit adoption.
- Retain plans, actions, checkpoints and reports outside Git.
- Run mandatory offline acceptance tests against a stateful API double.

**Offline acceptance is implemented; live tenant acceptance is not established.**
API contracts and subscription capabilities must be qualified in the selected
lab before treating this implementation as tenant-proven. Neither mocked tests
nor a successful creation response establishes firm compliance.

Read [Live Atlassian Cloud Acceptance](LIVE-ACCEPTANCE.md) before connecting a
real site. It separates lab prerequisites, unresolved integration work and the
required live acceptance tests; `--live` is not a claim that these gaps are closed.

## Run

Requires Python 3.11+, Make and a POSIX host (private file modes and `flock`).

    make bootstrap
    make check

Optional verification against a local strategy checkout:

    make check-sources STRATEGY_REPO=/path/to/atlassian-cloud

Dependency installation requires package-index access.
Validation and tests subsequently run offline.

The MVP uses Python, embedded decisions, the standard-library HTTPS client
and the existing YAML/JSON Schema dependencies. No policy server or new
service is required. Production execution and CI hosting are not selected.

## Lab MVP

The scope spans bootstrap, required foundation checks and the first two
synthetic, Internal-classification qualification assets. It does not provision the organisation,
site, subscriptions, identities or groups, and does not implement all
foundation settings or release workloads for firm use.

| File | Responsibility |
|---|---|
| `config/environments/lab.yaml` | Logical tenancy and asset intent. |
| `config/schemas/lab.yaml` | Bounded lab declaration schema. |
| `policy/lab.py` | Pure embedded decisions; no IO or implicit clock. |
| `automation/lab.py` | Private runtime, allowed APIs, plan/apply/verify. |
| `tests/test_lab.py` | Stateful offline acceptance and failure injection. |

The lifecycle remains in the
[strategy repository](https://github.com/kingfadzi/atlassian-cloud/blob/main/docs/strategy/LIFECYCLE.md).

### Prepare the private runtime

Run this from the repository root. Choose a new private path outside **every**
Git worktree; paths inside Git, symlinks and unsafe permissions are rejected.

```sh
.venv/bin/python -m automation.lab init \
  --runtime "$HOME/.local/share/atlassian-lab"
```

`init` is local-only. It creates pending templates, not credentials,
approvals or Atlassian resources; it never overwrites an existing runtime.

| Private input | Populate before a live plan |
|---|---|
| `bindings.json` | Actual organisation/site/product IDs, observed workspace type keys, site origin, native group IDs/names, lead ID and the three product identities. |
| `authority.json` | Synthetic application, ownership, classification and approval fixtures, scoped to the actual target and asset keys. |
| `prerequisites.json` | Scoped, current custody, product/capability, creation-constraint and identity/sharing evidence. Preserve manual versus automated versus simulated methods. |
| `reviews/<id>.json` | Technical review of one specific plan; created only after reviewing that plan. |

All authority/prerequisite records require `actor`, `evidence_ref`, `issued_at`,
`expires_at` and exact `scope`. Authority additionally requires `status: active`,
matching `asset_keys`, `application_ref`, `purpose` and the approved classification.
Ownership must resolve an `accountable_owner_id`. Approval must name the
implemented standard (`jira-restricted-v1` / `confluence-private-v1`) in
`approved_standards`, and bind `audiences[asset_key]` and
`administrators[asset_key]` to the exact native group IDs.
Prerequisites require `status: verified` and a verification method.
Replace the template's target scope after resolving actual bindings:

```json
{
  "organization_id": "<actual-org-id>",
  "site_origin": "https://<lab>.atlassian.net",
  "products": {
    "jira": "<actual-jira-workspace-id>",
    "confluence": "<actual-confluence-workspace-id>"
  }
}
```

This lab format is **supplied synthetic authority**, not a signed or trusted
firm approval integration. Changing a local status to `active` or `approved`
does not demonstrate real approval. Explicit fixture validity is not an
invented production freshness policy; P-13 remains unresolved.

### Tenant prerequisites and credentials

- Use an isolated existing organisation/site with Jira and Confluence.
  Supply an organisation API credential able to list its workspaces, and
  qualified product-account credentials. No purchase or plan upgrade occurs.
- Only direct `https://<lab>.atlassian.net` product origins are implemented.
  This MVP uses referenced environment-backed basic account/API-token
  credentials for products and a bearer credential for organisation reads.
  Scoped-token gateway routes, OAuth apps and custom domains need separate
  implementation/qualification; there is no broader-credential fallback.
- Each product requires distinct `admin`, `allowed` and `denied` account IDs
  and credential references. Resolve the environment-variable names generated
  by `init` through a local secret manager; never put values in Git, chat,
  command arguments or evidence.
- Establish the declared administrator/audience groups and project lead.
  A group reference must resolve to a unique native group ID and name.
- Both test users must be able to read a separate existing product baseline
  resource. Set their `baseline_path` to that resource; it cannot be the
  target asset. An unlicensed user or bad token is not evidence of isolation.
- Verify required sharing restrictions, administrative custody, alternate
  access, entitlements, residency/encryption creation constraints and group
  membership externally where the selected API cannot prove them.
- A caller-visible empty Confluence inventory is not proof of absence.
  The current `fixture:bootstrap-products` proof must explicitly list the
  inspected unused key in `unused_confluence_keys`, for example `["LABSPACE"]`.
  This remains controlled manual evidence; server key-conflict behaviour
  still needs live qualification. No hidden resource is implicitly adopted.

The implemented Confluence write path is the legacy private-space and
explicit group-permission API. `permission_model: legacy` must be supported
by actual prerequisite evidence, not guessed. RBAC tenants are blocked;
there is no fallback to a broadly accessible space.

Jira must support the declared company-managed template and dedicated
permission scheme. The caller's administration and returned project model
are checked. Unsupported capability or unexpected API shape stops execution.

### Plan, review, apply and verify

These commands access the lab only when explicitly given `--live`.
`make check` never calls them or requires credentials.

```sh
.venv/bin/python -m automation.lab plan \
  --runtime "$HOME/.local/share/atlassian-lab" --live
```

The result supplies an evidence directory and `plan_digest`. Inspect its
`plan.json`, `observations.json` and `report.md`. Writes are explicit actions:
the private space, its bounded grants, the dedicated scheme and the project.
Create a mode-0600 review file under the runtime's mode-0700 `reviews/`:

```json
{
  "status": "approved",
  "actor": "<independent-lab-reviewer-account-id>",
  "evidence_ref": "fixture:<review-record>",
  "lab_only": true,
  "plan_digest": "<printed-plan-digest>",
  "issued_at": "<timezone-aware-ISO-8601>",
  "expires_at": "<timezone-aware-ISO-8601>"
}
```

The reviewer must differ from both execution identities. This is lab review
simulation, not reviewer authentication. Business authority is checked
separately; a digest is not approval.

```sh
.venv/bin/python -m automation.lab apply \
  --runtime "$HOME/.local/share/atlassian-lab" \
  --plan "$HOME/.local/share/atlassian-lab/runs/<run-id>/plan.json" \
  --review "$HOME/.local/share/atlassian-lab/reviews/<id>.json" --live

.venv/bin/python -m automation.lab verify \
  --runtime "$HOME/.local/share/atlassian-lab" --live
```

Plans have a **15-minute lab lease**, not a new firm policy value. Mutations
require unchanged inputs, matching observed preconditions, current review
and current authority; checks repeat before each write. A complete unchanged
rerun can verify without writing. An expired review/plan or partial progress
requires a new plan and review before additional mutations.

Exit `0` means the requested command succeeded; it never means production
acceptance. Exit `1` means blocked/incomplete and must not trigger a blind retry.
Argument errors use the standard CLI exit `2`.

### Idempotency and recovery

| Condition | Behaviour |
|---|---|
| Verified resources still match | No remote writes; produce a new evidence run. |
| Existing key/name without a mapping | Block; no implicit adoption. |
| Known resource disappears | Block; no automatic recreation. |
| Completed resource drifts | Block; no automatic repair or deletion. |
| New space is not private | Stop before additional grants. |
| Scheme has unexpected grants | Stop before project creation. |
| Known API rejection | Record it, stop, then permit a newly reviewed plan. |
| Lost successful response | Re-read; recover only the exact marked resource or expected grant. |
| Outcome cannot be positively resolved | Keep the pending attempt and block every further mutation. |
| Evidence storage fails | Stop; retain uncertainty rather than claim success. |

Never clear `checkpoint.json` to make a run pass. An unresolved pending write
needs controlled investigation and documented reconciliation; this MVP has
no force/retry switch. Local locking covers one shared runtime only, not
other runtime directories, hosts or out-of-band administrators. Use one
designated runtime per lab and do not run concurrent independent writers.

Explicit adoption uses `bindings.json:adoptions[asset_key]` with `id`,
`scheme_id` for Jira, and `authority_ref`. Its current authority must bind
the exact `native_ids`, target and asset, with `purpose: adoption`.
Only already matching adopted
resources qualify; adoption does not authorise changes to a shared scheme.

### Evidence and acceptance

Each private run has JSON observations/actions and machine/human reports.
Apply runs also retain the reviewed plan, review record and pre-state.
Checkpoint updates and evidence files use private modes, atomic replacement
and `fsync`; a local filesystem is not immutable production evidence.

Mandatory offline tests cover:

- Creation followed by an identical **zero-write** application.
- Lost responses at **every mutation boundary**, without duplicate resources.
- Disk failure before a call and after remote success.
- Partial progress requiring a new reviewed plan.
- Expired/revoked authority, review and source changes during application.
- Collision/adoption, disappeared resources, drift and unsafe defaults.
- Allowed/denied/anonymous probes, independent product access and identity.
- Pagination, local locking, private paths, secret suppression and no
  network access from the test pipeline.

The stateful API double enforces key uniqueness and rejects duplicate grants.
It tests our behaviour, not Atlassian's implementation. A live acceptance run
must independently establish the same outcomes on the chosen tenant.
Permission probes do not create issues/pages or prove every workflow,
public-link, export or app-mediated path. Those remain explicit limits;
classification metadata and manual prerequisite fixtures are not enforcement.

Vendor contracts used by the bounded implementation:

- [Organisation workspace inventory](https://developer.atlassian.com/cloud/admin/organization/rest/api-group-workspaces/).
- [Jira project creation](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-projects/),
  [permission schemes](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-permission-schemes/)
  and [key validation](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-key-and-name-validation/).
- [Confluence private-space creation](https://developer.atlassian.com/cloud/confluence/rest/v1/api-group-space/),
  [permission writes](https://developer.atlassian.com/cloud/confluence/rest/v1/api-group-space-permissions/),
  [permission reads](https://developer.atlassian.com/cloud/confluence/rest/v2/api-group-space-permissions/)
  and [operation checks](https://developer.atlassian.com/cloud/confluence/rest/v2/api-group-operation/).

## Extension boundaries

- Policy defines permitted outcomes; configuration declares intended state.
- Configuration references authority; it does not manufacture approval.
- Automation obtains current authoritative inputs and performs operations.
- Pipelines invoke policy and automation; they do not duplicate their logic.
- Tests distinguish mocked behaviour, live acceptance and supplier assurance.
- Reusable standards use the selected configuration tool's native format
  where possible; do not introduce a bespoke policy or template language.

## Adding a capability

1. Declare its required outcome and map it to existing control IDs.
2. Define its configuration and explicitly managed properties.
3. Implement the supported operation and required source integrations.
4. Test rejection, repeat-run safety, drift and partial failure.
5. Wire the operation into the appropriate execution workflow.

A change workflow must resolve current authority, evaluate policy,
observe and plan, obtain review, revalidate, apply, verify and record.
Observation must also run independently of changes.

## Safety boundaries

- FS-COLLAB-01 remains assumed, not firm-approved.
- Lab declarations and authority references are synthetic.
- Missing or stale authority cannot authorise execution.
- Omission never authorises deletion.
- Partial application remains incomplete until verified.
- A Git revert does not reverse SaaS effects.
- Secrets, authoritative records, native IDs, observed state, plans,
  checkpoints, cursors and retained evidence stay outside Git.
- Evidence must identify the candidate, target, policy/profile,
  authority, observations, decision, actions and verified result.
- Operational logs and material decisions retain separate schedules.

Live commands exist but are opt-in. No tenant operation is authorised merely
by installing this repository or passing its offline tests.

# Live Atlassian Cloud Acceptance

Status: offline implementation accepted; live integration and tenant acceptance pending.

**Objective:** prove the MVP against an isolated Atlassian Cloud site, not only the stateful simulator. Establish working authentication and supported capabilities, then create the first restricted Jira project and Confluence space, verify access, and demonstrate safe reruns.

## Current position

| Area | Implemented | Remaining |
|---|---|---|
| Execution | Real HTTPS transport, embedded policy, `init`, `plan`, `apply`, `verify`. | Qualify authentication and responses against the selected site. |
| Provisioning | Dedicated Jira permission scheme and company-managed project; private Confluence space and explicit group grants. | Prove that the tenant's subscription and permission model support each operation. |
| Reruns and recovery | Zero-mutation rerun, journalled writes and positive readback reconciliation tested against a stateful API double. | Repeat the acceptance cases against real resources. |
| Evidence | Private local inputs, checkpoints, observations, reviewed plans and JSON/Markdown reports. | Retain actual tenant evidence; do not relabel simulator evidence as live proof. |
| Control position | Bounded lab decisions reference the existing baseline. | No full-foundation, whole-control or production acceptance claim. |

The mandatory offline suite has **54 test methods**, including lost-response cases at all eight mutation boundaries. Passing it does not establish compatibility with a particular Atlassian site.

## Required lab

| Requirement | Required outcome |
|---|---|
| **Isolated tenancy** | Existing organisation/site with Jira and Confluence. No firm data; no subscription purchase, site provisioning or production change is part of this MVP. |
| **Product capabilities** | Recommend Standard or higher for both products, subject to actual capability verification. Jira Free cannot restrict access through configurable permission schemes, and Confluence Free does not provide the required configurable permissions/restrictions ([Jira limitations](https://support.atlassian.com/jira-cloud-administration/docs/permissions-and-issue-level-security-in-free-plans/), [Confluence limitations](https://support.atlassian.com/confluence-cloud/docs/manage-permissions-in-the-free-edition-of-confluence-cloud/)). |
| **Three identities** | Administrator, allowed user and denied user. The same three accounts may serve both products; the implementation requires them to be distinct within each product. |
| **Valid test access** | Both test users have working product access and can read a separate baseline resource. Invalid credentials or an unlicensed account do not demonstrate asset isolation. |
| **Bound groups** | Administrator and audience groups have distinct native IDs, known membership and scoped approval. Resolve the project lead and accountable owner. |
| **Scoped proof** | Current custody, product capability, creation-constraint and identity/sharing prerequisite evidence. Preserve automated, controlled-manual and simulated methods separately. |
| **Private runner** | POSIX host, Python 3.11+, Make, required dependencies, approved HTTPS egress and one designated private runtime outside Git. |

**Do not apply on Free plans or an unqualified permission model.** The current implementation validates supplied prerequisite records; it does not yet independently determine subscription capabilities before every mutation.

## Authentication and target binding

- **Organisation inventory:** use a separate organisation credential with `read:workspaces:admin`; the documented inventory operation uses bearer authentication ([Workspace API](https://developer.atlassian.com/cloud/admin/organization/rest/api-group-workspaces/)).
- **Key administration:** organisation admins can create organisation API keys and select scopes where supported ([Admin API setup](https://support.atlassian.com/organization-administration/docs/manage-an-organization-with-the-admin-apis/)).
- **Product operations:** the current code uses account/API-token authentication against direct site origins. Validate the acting account's product permissions; an authentication success alone does not prove permission to create a project, scheme, space or grant.
- **Recommended integration:** add scoped product-token gateway support before relying on it. Atlassian requires scoped Jira and Confluence token calls to use the corresponding `api.atlassian.com/ex/.../{cloudId}` routes ([API-token guidance](https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/)).
- **Least privilege:** derive product scopes from the exact endpoints used. Do not resolve a failed call by silently switching to a broader credential or app identity.
- **Secret handling:** supply credentials securely outside Git. Keep only references in bindings; never place values in command arguments, evidence, issues or chat.

Keep site identity separate from the proposed gateway API bases:

```text
Site identity:   https://<lab>.atlassian.net
Jira API base:   https://api.atlassian.com/ex/jira/<cloudId>
Confluence API: https://api.atlassian.com/ex/confluence/<cloudId>
```

These gateway bases are **not implemented yet**. Organisation ID, site cloud ID, product-workspace ID, account ID and group ID are different identifiers; obtain and verify each rather than substituting one for another.

The [README](README.md#prepare-the-private-runtime) defines private input files, generated credential references, authority/review formats and current commands.

## Code gaps to close

| Gap | Required implementation or qualification |
|---|---|
| **Capability gate** | Add a read-only preflight within the planning path. Establish product availability, target relationships, identities, entitlement evidence and mandatory prerequisites before authorising writes; keep unobservable facts explicitly unverified or controlled-manual. |
| **Scoped-token routing** | Separate site identity from API origin/base path, bind the cloud ID, and preserve operation/origin allowlists, pagination checks and credential isolation. Add negative tests for mismatched targets and cross-origin forwarding. |
| **Confluence permission model** | Determine the actual model. The current code accepts only its legacy path and blocks RBAC. Atlassian documents v2 space creation with role assignments for RBAC-enabled tenants; implement and test that path if the lab requires it ([Confluence v2 spaces](https://developer.atlassian.com/cloud/confluence/rest/v2/api-group-space/)). |
| **Write authentication** | Prove the selected credential method on the exact permission endpoint. The legacy space-permission resource documents app-access restrictions; do not assume a token, OAuth app and impersonating app are interchangeable ([Space permissions](https://developer.atlassian.com/cloud/confluence/rest/v1/api-group-space-permissions/)). |
| **Response contracts** | Validate real group identifiers, grants, project management model, descriptions, operation checks, status values and complete pagination. Unexpected or incomplete responses must block, not become defaults. |
| **Regression evidence** | Convert observed API shapes into sanitised fixtures. Keep captured identities, credentials and retained run evidence outside Git. |

These are tracked integration tasks, not functionality implied by the existence of `--live`. A standalone `preflight` command and RBAC implementation do not currently exist.

## Live acceptance sequence

### Prepare and inspect

- **Establish authority:** approve only the isolated site, synthetic asset keys, named groups, intended operations and bounded execution window.
- **Resolve bindings:** populate actual IDs and credential references outside Git. Preserve the profile's assumed status; local lab records do not become firm approval.
- **Validate prerequisites:** confirm supported plans, permission model, recovery access and sharing restrictions. For an unseen Confluence space, retain the current scoped unused-key proof required by the implementation.
- **Run read-only checks:** validate each acting identity, organisation/product relationship, baseline access and complete observations. Do not treat an empty caller-visible list as tenant-wide absence.
- **Review the plan:** inspect the exact resource creations and grants. Reject broad default access, unresolved capabilities and unreviewed changes.

### Apply and verify

| Test | Required evidence |
|---|---|
| **First apply** | One project, dedicated scheme and space; recorded native IDs and post-state. Verify the scheme before project creation and private-space state before audience grants. |
| **Allowed access** | The authenticated audience identity can read each asset and has the declared work permissions. |
| **Denied access** | A different authenticated, product-capable identity cannot read either asset. Its independent baseline read must succeed. |
| **Anonymous access** | Anonymous target probes fail; alternative sharing paths remain separately assessed. |
| **Unchanged rerun** | Zero unnecessary remote mutations, no duplicate resources/grants and a new evidence run. |
| **Controlled interruption** | One bounded failure scenario shows partial progress, recorded uncertainty, positive readback and no blind mutation retry. |
| **Negative change** | Revoked authority, stale review or drift blocks further changes; no silent repair, deletion or access restoration. |

Use an explicitly approved, reversible interruption method; do not disrupt the SaaS service or other users. Start with a bounded client-side interruption and inspect actual state before any retry.

Permission/operation probes do not prove issue/page creation. If working-content behaviour is included in acceptance, separately approve one synthetic issue and page test, retain their IDs and verify that the denied identity cannot read that content.

### Record the result

- **Pass:** the selected live tenant passes the applicable cases and evidence identifies targets, candidate/policy/profile versions, current authority, reviewed plan, actual actions and verified outcomes.
- **Blocked:** unsupported capability, unresolved permission model, incomplete visibility, invalid authority or uncertain execution remains a named blocker.
- **Limited acceptance:** record exactly which paths were tested; do not infer workflow, export, public-link, Marketplace, Rovo or whole-foundation coverage.

Live lab acceptance remains distinct from production readiness. Firm-approved authority integration, protected retention, operational monitoring and broader control qualification are separate work.

## Scope and source links

This guide belongs to the operating repository; it does not replace the
[canonical lifecycle](https://github.com/kingfadzi/atlassian-cloud/blob/main/docs/strategy/LIFECYCLE.md)
or change the main strategy. Implementation and offline testing do not authorise
tenant writes; each live operation still needs approval for its target and scope.

# Open Items and Decision Register

Review draft | 17 November 2026

- What the [platform lifecycle](strategy/LIFECYCLE.md) needs but does not yet define.
- One item per line: what is open, and where it bites.

## Decisions owed

- **Owners:** no named accountable owners; the lifecycle uses roles only (register: owners unappointed).
- **Profile authority:** `FS-COLLAB-01 v0.1` is authorised for design and synthetic tests only; production approval outstanding.
- **Customer-managed keys:** adoption undecided; blocks the Declared check on creation-time constraints (`CEK-08`).
- **Evidence store:** not selected; independent custody undecided. Blocks Established logging checks (`LOG-02`, `LOG-04`, `LOG-10`).
- **Dormancy period:** not set. Needed for asset Dormant.
- **Nonconformance due dates:** no due date per severity. Needed for asset Nonconformant → Restricted.
- **Unregistered deadline:** no registration deadline before Unclassified-Restricted handling.
- **Containment rules:** what a Degraded platform does to existing assets; what Restricted removes, and who authorises it.
- **SLOs and error budgets:** no values agreed.

## Inputs owed

- **ServiceNow:** exact Business Application, owner and lifecycle fields; maximum age per source.
- **Identity:** real group and role bindings; emergency accounts; MFA and device enforcement paths.
- **Flows:** approved tenants, endpoints, recipients and destinations for the flow record.
- **Logs:** required event coverage; retention category mapping.
- **Recovery:** achievable recovery scope and plan entitlement for restore tests.
- **Plan tiers:** which checks each subscription tier allows; e.g. Confluence Free cannot restrict space creation.

## Vendor gaps

From the [automation coverage assessment](strategy/automation-coverage-assessment.md).

- **G-01 Shared policies:** Control policy API marked deprecated and disabled; authentication and data-security policies cannot be read or written as code.
- **G-02 Revocation:** role removal, account disable, external deactivation and token revoke have different scopes; latency unverified (`IAM-10`, P-04).
- **G-03 Audit events:** default exclusions drop events; retention pages conflict (180 vs 365 days).
- **G-04 Recovery:** backups exclude app access, audit logs and public-link configuration; restore needs a clean target.
- **G-05 Perimeter and data loss:** IP allowlists omit admin and some app paths; export and redaction controls are bounded.
- **G-06 Creation bypass:** native project and space creation exists outside intake; owners keep privilege after transfer.
- **G-07 Roadmap APIs:** Jira classification experimental; Guard redaction opt-in; Confluence space roles depend on rollout.

## Strategy placeholders

- `03` migration delivery: how migrated assets enter Unregistered or Requested.
- `04` sandbox data copying: sandbox eligibility is decided at Approved; the copy process is undefined.
- `05` retention and archive: retention schedules and the archive solution behind asset Disposal.
- `06` Rovo enablement: Rovo admission is decided at Approved; activation is undefined.
- `07` continuous governance: detection rules and response routing behind Operating and Degraded.
- `08` decisions and dependencies: to absorb this register once approved.

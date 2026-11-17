# Atlassian Platform Lifecycle

Review draft | 17 November 2026 | Register v0.2 | Profile `FS-COLLAB-01 v0.1`

- Defines the platform journey before any automation is laid over it.
- Implementation-neutral: names no tool, runtime or repository.
- Does not replace the [platform strategy](00-platform_strategy.md), the [control register](control-requirements-register.md) or [asset treatment](02-asset_ownership_treatment.md).

## Phases

- Five phases: **Initiation, Acquisition, Implementation, Operations, Disposal**.
- Short forms of the NIST system development life cycle phases (SP 800-37 Rev 2).
- Each phase also names the Risk Management Framework (RMF) steps it carries, as defined in SP 800-37.
- Two lifecycles use the same five phases:
  - **Platform lifecycle:** once per tenant. Organisation, sites, Jira, Confluence, shared controls, standards.
  - **Asset lifecycle:** once per Jira project or Confluence space. Runs only while the platform is in Operations.
- A product (Jira, Confluence) moves through Implementation separately; one product's readiness never passes the other.

| Phase | RMF steps | Platform | Asset |
|---|---|---|---|
| Initiation | Prepare, Categorize | Intent, scope, applicable controls | Request, facts, classification, treatment decisions |
| Acquisition | Select, Implement | Tenancy obtained; identity, foundation and standards established | Standard selected; project or space provisioned, restricted |
| Implementation | Assess, Authorize | Each product assessed and authorised | Asset verified and released |
| Operations | Monitor | Drift, change, review, response, recovery | Conformance, reassessment, change, restriction |
| Disposal | — | Product, site or tenant exit | Retire, archive, retain, dispose |

## How each phase is defined

- **Outcome:** what is true when the phase is done.
- **Entry:** what must already hold.
- **Controls:** register IDs whose acceptance the phase depends on.
- **Evidence:** what is recorded; follows the [evidence model](#evidence-model).
- **Automation:** what must be automated, and how each part is met.
- **Exit gate:** the decision that ends the phase.
- **Owner:** proposed accountable role; named owners are not yet appointed (register).
- **Open:** what the strategy does not yet define.

How a part is met, from the register:

- **Supported automation:** read, write and verify through a supported interface.
- **Partial automation:** some of it automated; the rest controlled manual.
- **Controlled manual:** a person acts in a console; automation reads the result back.
- **Inherited:** supplier-operated; needs supplier evidence, never assumed.
- **Gap:** no supported route; needs restriction, exception or vendor change.

## Platform lifecycle

### Platform Initiation

- **Outcome:** the platform's scope, applicable controls and creation-time constraints are explicit and versioned.
- **Entry:** strategy sections 4.1–4.2 in scope; register and profile versions pinned.
- **Controls:**
  - Applicability recorded for all 52 register controls.
  - Decided before anything is created: `DSP-19` (placement), `CEK-03` (cryptographic profile), `CEK-08` (customer-managed key capability), `I&S-05` (production and non-production separation), `DSP-15` (synthetic-only non-production), `AIS-02` (baseline referenced).
- **Evidence:**
  - Versioned platform intent: organisation, environments, sites, products, placement realm.
  - Control applicability per control, with parameter bindings (`P-01`–`P-22`).
  - Unresolved parameters and missing authoritative inputs (register, "Inputs still required").
  - Creation-time constraints and their resolution, e.g. customer-managed keys need enrolment before site creation.
- **Automation:**
  - Validate the intent declaration for completeness and contradiction: supported automation.
  - Applicability and parameter decisions: controlled manual (control owners).
- **Exit gate:** every control has an applicability decision; no unresolved creation-time constraint.
- **Owner:** platform owner; Security/GRC for applicability.
- **Open:** production policy authority for the profile; customer-managed key adoption decision.

### Platform Acquisition

- **Outcome:** the tenancy exists under recoverable custody; identity, shared foundation and product standards are established.
- **Entry:** Initiation exit gate passed.
- **Areas of work**, grouped by register domain:

| Area | What is established | Controls |
|---|---|---|
| Tenancy | Organisation, sites, Jira and Confluence, subscriptions, placement, administrative custody | `DSP-19`, `CEK-03`, `I&S-05` |
| Identity and administration | Federation, provisioning, MFA, separate admin identities, timed elevation, emergency and service identities, separation of duties | `IAM-04`, `IAM-05`, `IAM-09`, `IAM-10` |
| Exposure and flows | Anonymous access and public links closed, sharing defaults, network origins, permitted ingress and egress flows | `I&S-03`, `I&S-06`, `DSP-05`, `DSP-07`, `DSP-08`, `DSP-10` |
| Logging and evidence | Audit collection, event coverage, retention, access, tamper resistance, log scrubbing, correlation, alert routing | `LOG-02`, `LOG-03`, `LOG-04`, `LOG-05`, `LOG-07`, `LOG-08`, `LOG-10`, `DSP-16` |
| Apps and integrations | Approved apps, scopes, destinations, install restricted to platform admins | `STA-08`, `AIS-08`, `IPY-03` |
| Product standards | Versioned Jira and Confluence patterns: roles, permission schemes, workflows, fields, space permissions, sharing | `AIS-02`, `CCC-06`, `DSP-07`, `DSP-08` |
| Change and automation | Reviewed changes, authorised execution path, scoped writes, automation identity, vulnerability scanning of firm-managed automation | `CCC-02`, `CCC-04`, `AIS-06`, `TVM-03` |
| Recovery | Protected recovery points, export route | `BCR-08`, `IPY-02` |

- **Tenancy sequence** (bootstrap; read before create, stop on ambiguity):
  - Confirm the target organisation against intent.
  - Establish administrative custody; verify an alternate administrative path.
  - Confirm creation prerequisites; hold provisioning while any is unresolved.
  - Establish or adopt the Jira and Confluence instances.
  - Bind automation identities per API family; read-only first; no universal admin credential.
  - Capture the initial baseline: admins, groups, app access, existing configuration, what is not observable.
  - Repeat the observation to prove reruns change nothing.
- **Evidence:**
  - Inventory with typed identifiers: organisation, site, cloud id, product instance.
  - Custody and recovery verification; credential references only, never secrets.
  - Capability record per property: entitlement, API and version, read/write/test support, limits, review date.
  - Required-versus-actual settings per area, with the standard and baseline versions applied.
  - Initial exposure, visibility limits ("not visible" kept distinct from "not present") and unknowns.
- **Automation:**
  - Observe tenancy, identity, exposure and audit settings: supported automation where readable.
  - Create organisation, site, product; verify domains; configure SAML; buy subscriptions: controlled manual (no API).
  - Accounts, groups and memberships: inherited from the identity provider; referenced, never created.
  - Provision standards (roles, schemes, workflows, space permissions): supported automation where APIs exist.
  - Shared Control policies (authentication, data security): gap while Atlassian marks the API disabled (G-01).
  - Perimeter and data-loss controls: partial automation (G-05).
- **Exit gate:** the bootstrap exit conditions hold, and every Acquisition control is in place, read back, or carries a recorded gap.
  - Tenancy matches intent; custody is recoverable; automation identities proved per API family.
  - Initial state recorded; reruns are safe; handoff to identity and foundation work has named prerequisites.
- **Owner:** platform owner; IAM for identity; Security for exposure and logging; Procurement for subscriptions.
- **Open:** G-01 shared-policy API; G-03 audit retention conflict (180 vs 365 days); G-05 perimeter scope; G-07 Confluence space-role API rollout; where evidence is stored and who holds it independently.

### Platform Implementation

- **Outcome:** a separate authorisation decision for Jira and for Confluence, stating what is supported and proved.
- **Entry:** Acquisition exit gate passed for that product.
- **Controls:** assessed by exercise, not by reading configuration.
  - `AIS-05` security acceptance before release.
  - `IAM-10` timed elevation expires; `IAM-05` denied paths fail.
  - `I&S-03` permitted and denied browser, API and app paths.
  - `CCC-07` drift detected; `CCC-09` return to known-good state.
  - `LOG-03`, `LOG-14` alerts fire; collection failure detected within five minutes.
  - `SEF-06`, `SEF-07` triage and response routes exercised.
  - `BCR-08` restore into a clean target; `IPY-02` data retrievable.
- **Evidence:**
  - Scenario results on synthetic projects and spaces: provision, permitted and denied access, repeat run, stale authority, drift, interruption, recovery, evidence retrieval.
  - Coverage limits and plan-blocked tests, recorded as untested, not passed.
  - Authorisation decision per product: conformant within tested scope, approved exception, nonconformant, or unknown.
- **Automation:**
  - Repeatable qualification scenarios: supported automation.
  - Restore tests and response exercises: controlled manual where the plan or supplier allows.
- **Exit gate:** product authorised for named uses; exceptions have owner, scope and expiry.
- **Owner:** platform owner coordinates; Security/GRC authorises.
- **Open:** G-02 revocation latency; G-04 configuration excluded from backup; recovery entitlement on the chosen plan.

### Platform Operations

- **Outcome:** continued use stays backed by current authority and evidence.
- **Entry:** at least one product authorised.
- **Controls:**
  - Drift and change: `CCC-02`, `CCC-04`, `CCC-06`, `CCC-07` (critical settings every 15 minutes, others daily), `CCC-09`, `AIS-05`, `AIS-06`.
  - Exceptions: `CCC-08` (30 days; seven for high risk).
  - Access: `IAM-08` reviews (quarterly privileged/external/Restricted; six-monthly standard), `IAM-10`.
  - Logging and response: `LOG-02`, `LOG-05`, `LOG-07`, `LOG-10`, `LOG-14`, `SEF-06`, `SEF-07`, `SEF-09`.
  - Vulnerabilities: `AIS-07`, `TVM-03`, `TVM-06`, `TVM-08`.
  - Dependencies: `STA-08`.
  - Recovery: `BCR-08` quarterly restore tests.
  - Non-production: `DSP-15`.
- **Evidence:**
  - Current posture per control; drift findings with detection time and resolution.
  - Change records bound to reviewed revision and current authority.
  - Exception register with expiry; access-review decisions and their enforcement.
  - Alert, incident and response records; restore-test results.
- **Automation:**
  - Scheduled observation independent of merges: supported automation.
  - Automatic correction only where explicitly authorised, tested and reversible.
  - Expiry and review triggers: supported automation.
  - Advisory checks for firm-managed automation: supported automation.
- **Exit gate:** none; a material change (control, profile, supplier capability, standard) returns the affected product to Implementation.
- **Owner:** platform owner; Security for response; IAM for reviews.
- **Open:** detection rules and response routing (strategy 07 placeholder); SLO and error-budget values.

### Platform Disposal

- **Outcome:** a product, site or tenant is withdrawn with data retrieved, evidence retained and access removed.
- **Entry:** an authorised decision to withdraw.
- **Controls:**
  - `IPY-02`, `IPY-03` data exported through supported, secure routes.
  - `DSP-16`, `LOG-02`, `LOG-10`, `SEF-09` evidence and logs kept for their retention period (decision records seven years).
  - `CCC-04` explicit authority for every removal.
  - `STA-08` apps and integrations offboarded.
- **Evidence:** export completeness, retained evidence location, revoked identities and credentials, removal authority.
- **Automation:** export and identity revocation: partial automation; deletion: controlled manual.
- **Exit gate:** nothing retained without a schedule; nothing deleted without authority.
- **Owner:** platform owner; Records/Legal.
- **Open:** not defined in the strategy; derived from register controls only.

## Asset lifecycle

- Applies to every Jira project and Confluence space.
- Enters by request, or by migration wave.
- One maintained control record per asset across all phases.

### Asset Initiation

- **Outcome:** validated facts, approvals and four treatment decisions are recorded for the asset.
- **Entry:** a request to create, migrate, change or reuse; platform product authorised for the use.
- **Controls:** `DSP-03` inventory, `DSP-04` classification, `DSP-05` flows, `DSP-06` ownership and stewardship, `DSP-12` purpose, `CCC-04` authority, `CCC-08` exceptions.
- **Evidence:**
  - Request linked to the asset record.
  - Business Application and owner from ServiceNow; technical admins and secondary custodian.
  - Classification, intended audience, purpose, content role.
  - Approvals by classification: Internal (owner); Confidential (owner plus GRC/Security); Restricted (GRC/Security accountable); Public (blocked by default).
  - Four decisions: migration disposition, Rovo admission, sandbox eligibility, retention disposition.
- **Automation:**
  - Intake request and routing: supported automation (Jira Service Management).
  - Business Application and owner lookup: supported automation against ServiceNow.
  - Treatment rule evaluation: supported automation; approvals stay human.
- **Exit gate:** facts validated and approved; missing, disputed or expired information blocks admission.
- **Owner:** business application owner for facts; platform owner for the mechanism.
- **Open:** exact ServiceNow fields and freshness limits; migration intake (strategy 03 placeholder).

### Asset Acquisition

- **Outcome:** the project or space exists on an approved standard with restrictive handling, not yet released.
- **Entry:** Asset Initiation exit gate passed.
- **Controls:** `AIS-02`, `AIS-06`, `CCC-04`, `CCC-06`, `DSP-07` security defaults, `DSP-08` privacy defaults, `IAM-04`, `IAM-05`, `STA-08` dependencies within scope.
- **Evidence:** standard and version selected; plan, approvals and actual actions; resource identifiers; role-to-group bindings.
- **Automation:**
  - Create the project or space on the standard, bind roles to identity-provider groups, mark the standard: supported automation.
  - Block direct creation outside the governed path: partial automation (G-06).
- **Exit gate:** the asset exists with verified restrictive handling.
- **Owner:** platform owner.
- **Open:** G-06 ordinary-user creation bypass; Confluence space creation restricted only on paid plans.

### Asset Implementation

- **Outcome:** the asset is authorised for its declared use and audience.
- **Entry:** Asset Acquisition exit gate passed.
- **Controls:** `DSP-04`, `DSP-07`, `DSP-10` transfers, `IAM-05`, `IAM-15` authorisation in context, `I&S-06` separation of audiences, `AIS-05`.
- **Evidence:** release record linking authority, versions, read-back configuration, effective-access tests and registration.
- **Automation:**
  - Read back configuration against the standard: supported automation.
  - Effective-access tests (permitted and denied identities): supported automation.
  - Release decision: controlled manual where approvals require it.
- **Exit gate:** released; or held, with remediation assigned.
- **Owner:** platform owner; approver by classification.
- **Open:** Jira classification API experimental (G-07).

### Asset Operations

- **Outcome:** the asset stays conformant to its standard and its treatment stays current.
- **Entry:** asset released.
- **Controls:** `CCC-07` conformance, `CCC-08` exceptions, `IAM-08` access reviews, `IAM-15`, `DSP-03`, `DSP-05`, `DSP-06` reviews, `DSP-12`, `DSP-17`, `STA-08`.
- **Evidence:** conformance results per asset; reassessment triggers and outcomes; exceptions with expiry; restricted-handling records.
- **Automation:**
  - Discover every project and space, including ones created outside intake: supported automation.
  - Judge each against its standard and treatment: supported automation.
  - Reassess on trigger (ownership, classification, standard revision, dependency change, expiry): supported automation.
  - Contain, assign, remediate, verify: reporting is supported automation; containment requires explicit, approved rules.
  - Unattested assets at a migration cutoff get **Unclassified-Restricted** handling.
- **Exit gate:** none; a material change returns the asset to Initiation.
- **Owner:** business application owner for facts; platform owner for enforcement.
- **Open:** containment rules per rung and who authorises them.

### Asset Disposal

- **Outcome:** the asset is retired according to its retention disposition: standard lifecycle, compliant archive, legal hold, or deletion where permitted.
- **Entry:** retirement request, application lifecycle end, or retention trigger.
- **Controls:** `DSP-16` retention, `DSP-17` sensitive-data disposal, `IPY-02` retrieval, `CCC-04` explicit destructive authority.
- **Evidence:** disposition decision, archive or export location, access removed, record kept open while preservation applies.
- **Automation:** restrict and archive: partial automation; deletion: controlled manual with explicit authority.
- **Exit gate:** disposition complete; a decision not to migrate does not close the record.
- **Owner:** business application owner; Records/Legal.
- **Open:** archive solution and retention schedules (strategy 05 placeholder).

## Readiness boundaries

- **Foundation readiness:** shared controls meet the prerequisites of the next intended use.
- **Product readiness:** Jira or Confluence has passed Platform Implementation.
- **Asset readiness:** a specific project or space has passed Asset Implementation.
- Provisioned is not released; an approved asset never compensates for a missing shared control.
- An unknown mandatory control blocks the uses that depend on it; it never becomes a pass.

## Execution model

- Sequence for every managed change: validate inputs → observe → evaluate and plan → review → revalidate → apply → verify → register and record.
- Authority comes from designated systems; a merge never replaces a business or control approval.
- Only declared resources and properties are managed; omission never authorises deletion.
- A material change to inputs or target invalidates the plan.
- Unreadable state is unknown, not conformant.
- Drift observation runs independently of merges; old desired state never restores withdrawn access.

## Evidence model

| Element | Content |
|---|---|
| Scope | Organisation, site, product, environment, resource, managed properties |
| Authority and versions | Control IDs, register and profile versions, standard version, revision, input and approval references |
| Execution | Run identity and time, execution identity, proposed and attempted actions, failures |
| Verification | Observations, behavioural tests, identities and paths tested, coverage not tested |
| Decision | Outcome, reasons, exceptions, owner, observation time, expiry |

- Record how a control is met separately from its result.
- Results: conformant within tested scope, nonconformant, unknown or stale, under approved exception.
- Git holds intent and definitions; secrets, plans, sensitive observations and retained evidence stay outside it.
- Operational logs: 90 days searchable, 365 days total. Decision records: seven years after closure.

## Open across the lifecycle

- Strategy sections 03–08 are placeholders: migration, sandbox copying, retention and archive, Rovo, continuous governance, decisions.
- Vendor gaps G-01 to G-07 (automation coverage assessment) have no agreed treatment.
- Named owners are not appointed.
- Evidence store and its independent custody are not selected.

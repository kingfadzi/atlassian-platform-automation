# Atlassian Platform Lifecycle

Review draft | 17 November 2026 | Register v0.2 | Profile `FS-COLLAB-01 v0.1`

- The states the platform and each asset can be in, how to tell which one holds, and how each moves to the next.
- Phases: Initiation, Acquisition, Implementation, Operations, Disposal (NIST system development life cycle).
- Gaps and open decisions are in [open items](../open-items.md), not here.

## Conventions

- **State:** a named condition. It holds only when every check listed under it passes.
- **Check:** one condition with its source: `tenant` (API read), `record` (the control record), `ServiceNow`, `identity provider`, or `test` (an exercised behaviour).
- **Unknown:** a check that cannot be read is unknown. Unknown never satisfies a check.
- **Transition:** trigger → numbered steps (actor: action) → resulting state → evidence written.
- **Actors:**
  - Requester; business application owner; approver (set by classification).
  - Platform operator; Security; identity provider.
  - Automation: scheduled or triggered runs, with no human in the step.
- **Exception:** an attribute of a state, not a state. It carries scope, owner, compensating control and expiry: 30 days, or seven for high risk. When it expires, the check counts as failing again.

## Platform lifecycle

- The tenancy is shared. Jira and Confluence each hold their own state from Established onwards.

| Phase | States |
|---|---|
| Initiation | Declared |
| Acquisition | Provisioned, Established |
| Implementation | Authorised |
| Operations | Operating, Degraded |
| Disposal | Withdrawing, Withdrawn |

### Declared

| Check | Source | Controls |
|---|---|---|
| Intent exists and is versioned: organisation, environments, sites, products, placement realm | record | `AIS-02` |
| Every register control has an applicability decision | record | all |
| Every creation-time constraint has a resolution (placement, customer-managed keys) | record | `DSP-19`, `CEK-03`, `CEK-08` |
| Production and non-production are separate declarations; non-production is synthetic-only | record | `I&S-05`, `DSP-15` |

**Declared → Provisioned.** Trigger: intent approved.

1. Platform operator: create or adopt the organisation, site and products in the admin console.
2. Automation: read the workspace inventory and compare it with intent. Stop on any mismatch.
3. Platform operator: set up two verified administrative paths.
4. Automation: authenticate as each automation identity against the organisation, Jira and Confluence APIs. Read only.
5. Automation: record the baseline (admins, groups, apps, settings), then run it again. The second run must change nothing.

- Evidence: inventory with typed identifiers, custody verification, capability record per API, baseline.

### Provisioned

| Check | Source | Controls |
|---|---|---|
| Organisation, site and product instances match intent | tenant | `DSP-19` |
| Products sit in the declared placement realm | tenant | `DSP-19` |
| Two administrative paths verified | test | `IAM-09` |
| Each automation identity authenticates with read access | test | `AIS-06`, `IPY-03` |
| Baseline recorded; a repeat read changes nothing | record | `CCC-06` |

**Provisioned → Established.** Trigger: Provisioned holds.

1. Platform operator: verify domains, configure SSO and user provisioning, and close anonymous access and public links (console).
2. Platform operator: route audit logs to the evidence store; restrict app installation to platform admins.
3. Automation: create each standard's roles and permission schemes, and Confluence space roles.
4. Automation: read back every check below. Anything unmet stays outstanding, with the console step that resolves it.

- Evidence: required-versus-actual value for each check, standard versions applied.

### Established (per product)

| Check | Source | Controls |
|---|---|---|
| Declared domains verified; the verification record is present | tenant | `IAM-09` |
| Managed accounts authenticate through the identity provider with MFA; admins use phishing-resistant MFA | tenant | `IAM-09` |
| Every admin and privileged account is declared; each holds only what its kind allows | tenant | `IAM-04`, `IAM-05` |
| Privileged elevation is time-bound | tenant | `IAM-10` |
| Anonymous access off | tenant | `I&S-06`, `DSP-07` |
| Public links off; no public or site-wide permission grants | tenant | `DSP-07`, `DSP-08` |
| Ingress restricted to approved origins and clients | tenant | `I&S-03` |
| Every permitted flow is recorded with owner and destination | record | `DSP-05`, `DSP-10` |
| Every installed app and integration is approved, within its approved scopes | tenant, record | `STA-08`, `AIS-08` |
| Audit events arrive in the evidence store, covering required event types | tenant, test | `LOG-03`, `LOG-05`, `LOG-07` |
| Evidence store: access restricted, tamper-resistant, retention configured, sensitive fields scrubbed | test | `LOG-02`, `LOG-04`, `LOG-08`, `LOG-10`, `DSP-16` |
| Each standard's roles, scheme and grants are present and match its declaration | tenant | `AIS-02`, `CCC-06` |
| Changes pass the required reviewers; writes use the authorised path only | record | `CCC-02`, `CCC-04`, `AIS-06` |
| Recovery points exist; an export route exists | tenant | `BCR-08`, `IPY-02` |
| Firm-managed automation is scanned for vulnerabilities | record | `TVM-03` |

**Established → Authorised.** Trigger: platform operator requests qualification for the product.

1. Automation: run the qualification scenarios on synthetic projects or spaces:
   - provision; permitted and denied access; repeat run
   - stale authority; injected drift; interrupted run; evidence retrieval
2. Automation: confirm an elevated grant expires on time.
3. Platform operator: restore a synthetic dataset into a clean target; time the restore against the recovery-time and data-loss targets.
4. Security: raise a test alert; confirm triage and the response route.
5. Security/GRC: record the authorisation decision, permitted uses and any exceptions.

- Evidence: scenario results; untested items marked untested; the authorisation record.

### Authorised (per product)

| Check | Source | Controls |
|---|---|---|
| A current authorisation record names the permitted uses | record | `AIS-05` |
| Every qualification scenario passed or has an unexpired exception | record, test | `CCC-07`, `CCC-09`, `IAM-05`, `IAM-10`, `I&S-03` |
| Restore result within target | test | `BCR-08`, `IPY-02` |
| Alerting, collection-failure detection and response route proved | test | `LOG-03`, `LOG-14`, `SEF-06`, `SEF-07` |

**Authorised → Operating.** Trigger: authorisation recorded.

1. Automation: start scheduled observation: critical settings every 15 minutes, others daily.

### Operating (per product)

| Check | Source | Controls |
|---|---|---|
| All Established checks pass at the last observation | tenant | as above |
| The last observation is within its interval | record | `CCC-07` |
| Collection is healthy; failure is detected within five minutes | tenant | `LOG-14` |
| No exception has expired | record | `CCC-08` |
| No access review is overdue | record | `IAM-08` |
| No vulnerability finding past its deadline; advisories checked daily | record | `AIS-07`, `TVM-03`, `TVM-06`, `TVM-08` |
| Quarterly restore test within date | record | `BCR-08` |
| Incident records are linked to evidence and protected | record | `SEF-09` |

- **Operating → Degraded.** Trigger: any check fails or is unknown.
  1. Automation: record the finding and notify the owner of the failing check.
  2. Automation: block new admissions and releases that depend on that check.
- **Material change → Established.** Trigger: profile, standard, supplier capability or control change. The product needs authorising again.

### Degraded

- Holds when: Authorised holds, and at least one Operating check fails or is unknown.
- Existing assets follow their containment rule. Nothing is shut down wholesale.
- **Degraded → Operating.** Trigger: the next observation passes, or an exception is approved.

### Withdrawing

| Check | Source | Controls |
|---|---|---|
| An authorised withdrawal decision exists | record | `CCC-04` |
| New admissions blocked | record | — |

1. Automation: export the required data; verify it is complete.
2. Platform operator: offboard apps; revoke automation identities and credentials.
3. Automation: confirm evidence and logs are kept under their retention schedules.

### Withdrawn

| Check | Source | Controls |
|---|---|---|
| Export verified complete | test | `IPY-02`, `IPY-03` |
| No active automation identity or app | tenant | `STA-08` |
| Evidence kept: logs 365 days, decisions seven years | record | `DSP-16`, `LOG-02`, `LOG-10`, `SEF-09` |

## Asset lifecycle

- Applies to every Jira project and Confluence space.
- Each asset has one control record that holds its state.

| Phase | States |
|---|---|
| Initiation | Unregistered, Requested, Pending information, Approved |
| Acquisition | Provisioned |
| Implementation | Held, Released |
| Operations | Nonconformant, Restricted, Dormant |
| Disposal | Retiring, Archived, On hold, Disposed |

### Unregistered

- Holds when: the project or space exists in the tenant (`tenant`) with no control record (`record`).
- Covers assets created outside intake, and assets that arrived by migration.

1. Automation: record it, identify likely owners from its admins, and notify them.
2. **→ Requested:** an owner registers it through intake.
3. **→ Restricted (Unclassified-Restricted):** no registration by the deadline.

### Requested

| Check | Source | Controls |
|---|---|---|
| An intake request (create, migrate, change, reuse) is linked to a control record | record | `CCC-04` |

**Requested → Approved.**

1. Automation: look up the Business Application in ServiceNow; check it is active and has an owner.
2. Requester: supply classification, audience, purpose and custodians.
3. Automation: compare the declarations with ServiceNow and tenant evidence; list any discrepancies.
4. Automation: evaluate the treatment rules, producing four decisions (migration, Rovo, sandbox, retention) and a standard.
5. Approvers, set by classification:
   - Internal: business application owner.
   - Confidential: owner, plus GRC/Security.
   - Restricted: GRC/Security accountable.
   - Public: blocked by default.

- Failure leads to Pending information (missing, stale or disputed facts) or rejected.

### Pending information

- Holds when: Requested holds, and at least one Approved check fails or is unknown.
- The missing, stale or disputed facts and who owes them are recorded (`record`).
- Exits:
  - **→ Requested:** the facts are supplied; the Requested → Approved steps run again.
  - **→ rejected:** no response by the due date, or the request is withdrawn.

### Approved

| Check | Source | Controls |
|---|---|---|
| Business Application active; owner current | ServiceNow | `DSP-06` |
| Custodians resolve to active identities | identity provider | `DSP-06` |
| Classification, audience and purpose recorded | record | `DSP-04`, `DSP-12` |
| Data inventory and flows recorded | record | `DSP-03`, `DSP-05` |
| Four decisions, plus standard id and version | record | `DSP-12` |
| Approvals match classification; none expired | record | `CCC-04`, `CCC-08` |

**Approved → Provisioned.**

1. Automation: revalidate owner, Business Application and approvals. Stop if any is stale.
2. Automation: create the project or space on the standard.
3. Automation: bind each role to its identity-provider group, and stamp the standard id.
4. Automation: read back and mark the record "not released".

### Provisioned

| Check | Source | Controls |
|---|---|---|
| Exists with the standard id stamped | tenant | `AIS-02`, `CCC-06` |
| Scheme is the standard's; only declared role bindings; groups follow the identity-provider pattern | tenant | `IAM-04`, `IAM-05` |
| No anonymous or public grants; privacy defaults applied | tenant | `DSP-07`, `DSP-08` |
| Dependencies within approved scope | tenant, record | `STA-08` |
| Record says "not released" and holds resource ids | record | `AIS-06` |

**Provisioned → Released.**

1. Automation: read back configuration against the standard.
2. Automation: run access tests. A permitted identity succeeds; an unrelated identity is denied.
3. Automation: verify flows and dependencies are within approved scope.
4. Approver: confirm, where the classification requires it.
5. Automation: write the release record.

- Failure leads to Held, with remediation owner and due date.

### Held

- Holds when: Provisioned holds; release is blocked; a remediation owner and due date are recorded.
- Exits:
  - **→ Released:** reverification passes.
  - **→ Retiring:** the request is abandoned.

### Released

| Check | Source | Controls |
|---|---|---|
| All Provisioned checks pass at the last observation, apart from the "not released" marker | tenant | as above |
| Release record current | record | `AIS-05` |
| Effective access within audience | test | `IAM-15`, `I&S-06` |
| Transfers match approved flows | tenant, record | `DSP-10` |
| Business Application still active | ServiceNow | `DSP-06` |
| Access review and stewardship review not overdue | record | `IAM-08`, `DSP-06` |
| No expired exception | record | `CCC-08` |
| Sensitive-data handling applied as declared | record | `DSP-17` |

- **→ Nonconformant:** any check fails or is unknown.
- **→ Requested (reassessment):** owner, classification, Business Application lifecycle or standard version changes. Access stays unchanged until a decision; an overdue reassessment makes the asset Nonconformant.
- **→ Dormant:** no activity within the dormancy period.
- **→ Retiring:** a retirement request, or the Business Application is retired.

### Nonconformant

1. Automation: record the finding, notify the owner, and set the due date by severity.

- Exits:
  - **→ Released:** the next observation passes, or an exception is approved.
  - **→ Restricted:** the due date is missed, or the finding is high risk.

### Restricted

| Check | Source | Controls |
|---|---|---|
| Access limited to the owner, remediation personnel and platform admins | tenant | `IAM-05`, `IAM-15` |
| External access and Rovo off | tenant | `DSP-07`, `DSP-12` |
| Scope, remediation owner and expiry recorded | record | `CCC-08` |

- Exits:
  - **→ Released:** remediation is verified.
  - **→ Retiring:** the expiry passes unresolved.

### Dormant

- Holds when: Released checks hold, and there has been no activity within the dormancy period (`tenant`).
- Exits:
  - **→ Released:** the owner confirms it is still in use; reassessment follows.
  - **→ Retiring:** the owner declines, or doesn't respond by the due date.

### Retiring

1. Automation: read the retention disposition from the record.
2. Automation: export where required; verify it is complete.
3. Automation: remove all access except custodians.
4. Records/Legal: confirm the disposition.

- Exits: **→ Archived**, **→ On hold**, or **→ Disposed**.

### Archived

| Check | Source | Controls |
|---|---|---|
| Read-only; access limited to custodians | tenant | `DSP-17` |
| Retention end date recorded | record | `DSP-16` |
| Retrievable | test | `IPY-02` |

### On hold

- Holds when: a legal hold is recorded (`record`) and no deletion is possible (`tenant`).

### Disposed

| Check | Source | Controls |
|---|---|---|
| Asset absent from the tenant | tenant | `DSP-17` |
| Explicit deletion authority recorded | record | `CCC-04` |
| Control record kept with disposal evidence for seven years | record | `DSP-16` |

## Every automated change

- Validate inputs → observe → evaluate and plan → review → revalidate → apply → verify → record.
- Applies only to declared resources and properties. Omission never authorises deletion.
- Unreadable state is unknown. Old desired state never restores withdrawn access.

## Evidence written by every transition

- Scope, authority and versions (control IDs, register, profile, standard), actor and time.
- Actions attempted, values read back, tests run, result, exceptions, expiry.

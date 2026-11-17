# Asset Ownership and Treatment

Supports [strategy action 4.2: Establish asset ownership and treatment](00-platform_strategy.md#42-establish-asset-ownership-and-treatment).

Alignment review draft | 20 October 2026.

## 1. Business context and problem

**Establish reliable asset information and convert it into approved, enforceable treatment that remains current throughout the asset lifecycle.**

- **GRC-led treatment:** Applicable obligations, approved policies, and validated business facts determine permitted use. Approval becomes effective only when required controls are applied and verified.
- **Control gap:** Incomplete ownership, application association, classification, and configuration records prevent reliable decisions about access, dependency use, change, reuse, and preservation.

| Aspect | Boundary |
| :--- | :--- |
| **Immediate scope** | Establish maintained asset records, validated treatment, application of approved project/space patterns, permitted dependency use, verified enforcement, exceptions, reassessment, and evidence. |
| **Platform product management** | Name the treatment-mechanism owner, supported operations, support boundaries, capacity/cost baseline, stakeholder feedback route, and prioritized improvements. |
| **Assets** | Jira projects and Confluence spaces, including their ownership, application context, classification, intended audience, and handling obligations. |
| **Foundation dependency** | [Cloud Foundation](01-cloud_foundation.md) maintains shared controls, SaaS ingress/egress patterns, project/space standards, and approved dependencies. Asset treatment verifies their application to each asset; firm-hosted network controls are not assumed to cover SaaS. |
| **Later delivery** | Record future-use and preservation decisions now; migration execution, sandbox-copy services, an archive solution, and Rovo rollout remain outside immediate delivery. Later workstreams consume current decisions and return findings for reassessment. |
| **Accountability** | Business owners validate business facts and intended use. Platform teams implement controls; enterprise functions retain their requirements, approvals, and oversight mandates. |

Immediate delivery includes initial **golden paths**, governed operational self-service for platform operators, and self-service evidence access for authorized oversight functions. Strategy section 4.3 expands their coverage and automation.

**Required outcome:** One maintained control record per asset, linking validated facts, policy and pattern versions, dependency use, approvals, independent decisions, exceptions, and enforcement evidence.

## 2. Required asset information

**Jira Service Management manages intake and attestation. ServiceNow supplies the Business Application association, accountable business owner, and application lifecycle.**

Normal active Cloud use requires a valid active Business Application association. Missing or invalid mappings require remediation or approved exception handling.

| Information | Required content and validation |
| :--- | :--- |
| **Asset identity** | Project or space key, product, and environment. Preserve source-to-target associations through migration. |
| **Accountability** | Business App Owner from ServiceNow, technical administrators, and secondary custodian. Validate custodian identities against corporate identity information. |
| **Application context** | Business Application ID and lifecycle from ServiceNow. Distinguish application lifecycle from the asset’s own active, dormant, or retired status. |
| **Purpose and content role** | Business justification and whether content supports working collaboration, operational procedures, authoritative knowledge, or retained records. |
| **Classification and overlays** | Restricted, Confidential, Internal, or Public, with applicable regulatory obligations. Reconcile declarations with application attributes and available content evidence. |
| **Intended audience** | Specific team, department, or all employees. Default to the specific team; broader access requires justification and approval. |
| **Applied standard** | Approved project/space type, pattern identifier and version, required settings, selected variant, and any authorised exception with owner and expiry. |
| **Dependency use** | Referenced add-ons, Marketplace apps, integrations, and automations, linked to the foundation's approved dependency register. Record purpose, owner, data scope, permissions, destinations, configuration/version, and applicable restrictions. |
| **Permitted data flows** | Link approved flow records for uploads, API reads, exports/downloads, notifications, callbacks, and app transfers. Record asset data/classification, recipients, purpose, source/destination tenant, connection/data direction, route, identity, enforcement, approvals, and any coverage exception. |
| **Sandbox testing need** | None, development, user acceptance testing, or both, with a defined purpose. A stated need does not authorize copying. |
| **Retention relevance** | Record types, preservation requirements, potential holds, and matters requiring Legal/Records assessment. |
| **Decision evidence** | Attestation, validation, approvers, policy versions, decision dates, review requirements, conditions, exceptions, and expiry. |
| **Migration readiness** | For migration candidates: complexity, dependencies, tool eligibility, remediation, and assigned validation requirements. |

Available validation evidence includes actual configuration, permissions, dependency settings, activity, lifecycle information, and supported detection or approved scanning findings. Compare it with the selected pattern, approved dependency scope, and declared handling.

**Owner attestation is an input to validation.** Material discrepancies require documented review and resolution; changing a declaration does not resolve contradictory evidence.

## 3. Four independent treatment decisions

**Record each treatment decision separately, with its purpose, conditions, evidence, and applicable approvals.**

- **Current release:** Normal active use requires validated facts, an approved configuration pattern, permitted dependencies/data flows, and verified enforcement.
- **Future-use decisions:** The four outcomes below record permitted handling, not authorisation to deliver or activate later services. Their implementation remains subject to separate readiness checks.

| Decision | Recorded outcome | Boundary |
| :--- | :--- | :--- |
| **Migration disposition** | Migrate, remediate, split, start fresh, defer, archive, delete where permitted, exception, or block. Record reasons and required actions. | Determines proposed transition or alternative disposition; it does not authorise migration execution or replace the current release checks. |
| **Rovo admission** | Eligible, restricted, quarantined, pilot-only, or not admitted, with permitted purpose and source scope. | Source admission does not approve every use case or agent action. |
| **Sandbox eligibility** | Eligible, excluded, or exception-only, with classification conditions and justified testing purpose. | Eligibility does not authorize a specific copy, destination, audience, or access duration. |
| **Retention disposition** | Standard lifecycle, compliant archive required, legal hold, or deletion where permitted. | Preservation obligations remain independent of migration and operational usefulness. |

Rovo admission requires assessment of source authority, currency, permissions, and enforceable scope. Sandbox copying requires separate event authorization.

**A decision not to migrate does not close the record.** Retention remains explicit. Content retained in Cloud also requires recorded Rovo and sandbox treatment.

## 4. Intake, validation, and approval

**Each asset has a traceable request linked to its maintained control record.** Route business decisions to the owner identified through ServiceNow.

| Stage | Required result |
| :--- | :--- |
| **Establish ownership and intent** | Identify the business owner, technical administrators, and secondary custodian. Record the proposed creation, migration, change, or reuse. |
| **Validate application association** | Confirm the Business Application and lifecycle. Route missing or inaccurate information to the enterprise asset data owner. |
| **Assess and reconcile** | Compare required declarations with system evidence. Record discrepancies, investigation, and agreed treatment. |
| **Apply approval** | Obtain technical-administrator attestation and applicable business and control-function decisions. |
| **Derive treatment** | Evaluate applicable rules and record all four outcomes, conditions, evidence, and exceptions. Requesters do not independently select eligibility. |
| **Select standard, dependencies, and flows** | Match handling to an approved pattern/version. Confirm dependency use and inbound/outbound data flows are within approved scope; route unsupported requirements for extension or exception review. |
| **Enforce, verify, and register** | Apply the selected pattern and handling. Verify settings, dependency scope, permitted data flows, and coverage gaps; update the asset record and retain evidence before release. |

**Standards support approved use cases, not one configuration for every team.** Record variants and exceptions explicitly; an approved template or platform-wide app approval does not establish asset conformance.

**Policy as code** will express suitable treatment rules as versioned, tested evaluations where supported. Automated evaluations support accountable decisions and retain the applicable approval requirements.

**Configuration as code** will version, review, and test supported request-workflow, validation, permission-pattern, and enforcement configurations. Link executed configuration and rule versions to the maintained asset record and release evidence.

| Classification | Approval requirement |
| :--- | :--- |
| **Internal** | Business App Owner approval after validation. |
| **Confidential** | Business App Owner approval with Governance, Risk and Compliance/Security review. |
| **Restricted** | Governance, Risk and Compliance/Security accountable approval, with Business App Owner and Data Governance consultation. |
| **Public** | Activation blocked by default. Require Business App Owner exception approval and Governance, Risk and Compliance/Security, Data Governance, and Communications/Legal consultation. |

These approvals establish asset treatment. Additional conditions apply to particular Rovo uses, sandbox-copy events, and preservation or disposal decisions.

### Golden paths and governed operational self-service

**Platform operators will execute supported asset-lifecycle paths using approved tooling and permissions.** Each path defines supported inputs, prerequisites, steps, approvals, exceptions, failure escalation, operating owner, and completion evidence.

| Golden path | Supported execution | Completion evidence |
| :--- | :--- | :--- |
| **Onboarding and controlled release** | Complete intake, validation, approvals, treatment decisions, pattern selection, dependency checks, enforcement, and registration before business release. | Validated facts, pattern/configuration/rule versions, dependency scope, decisions, conformance checks, and registration trace to the request. |
| **Material change and reassessment** | Revalidate changed facts, patterns, or dependencies; reassess affected decisions and verify resulting settings, restrictions, and records. | Changed inputs and versions trace to approvals, conformance results, updated treatment, and affected downstream uses. |
| **Exception and restricted handling** | Route missing, disputed, or expired information to approved treatment; apply restrictions, assign remediation, and track expiry. | Required approvals, verified restrictions, accountable ownership, expiry, and disposition are recorded; unresolved cases remain blocked or restricted. |

Operators can execute supported routines without bespoke specialist fulfilment. Business and control-function approvals remain required; cases outside supported boundaries route to accountable review.

## 5. Enforcement and unresolved assets

**Classification labels inform policy; product permissions enforce access.** Treatment is effective only when the required controls have been applied and verified.

| Enforcement area | Required behavior |
| :--- | :--- |
| **Jira** | Verify the selected pattern's naming, types, workflows, fields/screens, roles, permission/notification schemes, security defaults, and permitted automation/add-on use against approved handling. |
| **Confluence** | Verify the selected pattern's naming, templates/content conventions, ownership/classification records, permissions/restrictions, sharing defaults, and review/lifecycle settings. |
| **Add-ons and dependencies** | Verify app, integration, and automation configuration, execution identity, permissions, affected assets, and data destinations against approved use. Block unapproved use or scope expansion. |
| **Ingress and egress** | Apply the [foundation boundary rules](01-cloud_foundation.md#c-saas-ingress-egress-exposure-and-response) to each permitted flow. Verify allowed sources, recipients, payloads, and destinations at named enforcement points; block unsupported use unless permissible exception treatment is approved. A permitted connection does not approve every data transfer. |
| **Rovo** | Keep unapproved use blocked. Before later activation, verify source scope, permissions, connectors, and capability configuration against current admission decisions; labels alone are insufficient. |
| **Inventory and evidence** | Register asset facts, lifecycle, four outcomes, policy/pattern versions, dependency and flow approvals, conformance/enforcement results, and exceptions. |
| **Failed enforcement** | Withhold normal release when facts, pattern conformance, dependency/flow approvals, restrictions, or registration are incomplete. Assign remediation and verify recovery; only permissible approved exception handling may proceed. |

Where automated enforcement is unsupported, define controlled manual steps, accountable operators, and retained verification evidence.

Missing, disputed, or expired information blocks normal admission. At a later migration cutoff, unattested assets receive **Unclassified-Restricted** handling, a system-assigned posture, not a selectable classification.

| Restricted-landing requirement | Required treatment |
| :--- | :--- |
| **Accountable exception** | Approved scope, expiry, remediation owner, and resolution date. |
| **Verified restrictions** | Rovo exclusion and external access disabled before landing. |
| **Limited access** | Authorized remediation personnel, platform administrators, and the mapped owner where applicable. |
| **Defined disposition** | Complete attestation, archive, or delete where permitted. |
| **Sandbox exclusion** | No routine copying. Urgent copies require the Restricted exception process. |

**Defer landing where required restrictions cannot be enforced. Missing the cutoff does not authorize migration.**

Governance readiness does not establish technical readiness. Migration also requires a supported path, completed remediation, and assigned validation.

## 6. Maintaining and demonstrating treatment

**The platform team will maintain the control mechanism and evidence. Asset owners remain accountable for business facts, and control functions retain their review and approval responsibilities.**

Reuse the maintained record for downstream requests. Each consuming workstream must check that its required decisions and evidence remain current.

| Operating requirement | Required approach |
| :--- | :--- |
| **Reassessment triggers** | Reassess changed ownership, lifecycle, content, permissions, purpose, patterns, dependencies, recipients, endpoints, or routes; approval withdrawal; findings; or expiry. Include assets affected by shared-component changes. |
| **Policy as code maintenance** | Version rules and automate supported tests for permitted, denied, invalid, stale, and expired inputs. Retain evaluations, approvals, and affected-record assessments. |
| **Automated testing and progressive delivery** | Review and test versioned workflow/enforcement configurations, validate outside production, limit initial rollout where supported, and define stop conditions and rollback or recovery. |
| **Drift detection and exceptions** | Compare actual settings, dependency scope, permissions, and records with approved pattern/version and treatment. Detect unapproved customisation; contain, assign, remediate, and verify findings using supported automation or defined manual checks. |
| **Pattern and dependency lifecycle** | Revalidate affected assets when standards are revised/deprecated or dependency approvals change. Apply verified upgrades, approved variants, or permissible exceptions before required transition dates. |
| **Self-service evidence access** | Provide authorized governance, risk, and assurance functions reusable views or queries of current records, policy results, approvals, exceptions, and enforcement evidence. |
| **Operating ownership** | Name an owner for each golden path, including workflow, integration, validation, provisioning, tests, alerts, failure recovery, evidence, review, and exceptions. |

A sandbox refresh checks current classification, eligibility, findings, and exceptions. The operator does not invent a new classification or copy permission.

### Service reliability and learning

**Measure and operate the shared treatment mechanism within agreed team capacity.** Its platform operating owner maintains service measures and runbooks; business and control functions retain their approval responsibilities.

| Practice | Required approach |
| :--- | :--- |
| **SLIs and SLOs** | Agree service-level indicators and objectives for workflow success, integration freshness, and enforcement completion within platform ownership. Separate human approval waiting time from execution. |
| **Error budgets** | Define permitted unreliability over agreed SLO windows and actions on budget depletion. Use results to prioritize change and remediation; approvals and mandatory controls remain binding. |
| **Observability and actionable alerting** | Monitor failed/stalled workflows, stale integrations, incomplete enforcement, and missed reviews. Route actionable alerts to accountable responders with escalation and runbooks. |
| **Recovery testing** | Exercise retry, reconciliation, and rollback or recovery for partial workflow/provisioning failure. Verify approved treatment and record consistency while retaining decision and audit history. |
| **Toil reduction** | Baseline repeated intake, manual fulfilment, evidence collection, and specialist dependencies. Prioritize initial improvements and verify their effect on recurring effort. |
| **Blameless postmortems** | Review significant workflow, control, or change failures. Identify contributing conditions, assign corrective actions, and verify effectiveness before closure. |

Agree numerical targets, measurement windows, error-budget decision rules, and response ownership before dependent operation. Record unsupported automation and measurement limits with accountable procedures and verification evidence.

| Acceptance criterion | Required evidence |
| :--- | :--- |
| **Accountable assets** | Normal active assets have validated owners, active Business Application associations, and current classification. |
| **Pattern conformance** | Each released asset has an applied pattern/version, required settings, and conformance evidence. Tests cover approved variants, denied unapproved changes, shared-component impact, and expired exceptions. |
| **Permitted dependencies** | Asset dependency use traces to current platform approvals and verified scope. Tests cover unauthorised use, increased permissions, new destinations, and approval withdrawal. |
| **Authorised data movement** | Flow approvals and tests distinguish network connectivity from permitted data handling. Verify allowed/denied uploads, API responses, exports/downloads, callbacks, and app transfers within documented control coverage; record gap treatment and revoke changed or expired permissions. |
| **Independent decisions** | All four outcomes have reasons, applicable approvals, conditions, and evidence. Completing intake alone does not authorise later-service activation. |
| **Repeatable evaluation** | Versioned rules and automated tests where supported demonstrate expected decisions, invalid/stale input handling, expired-exception blocking, and required human review. |
| **Enforced release** | Tests demonstrate correct permissions, restrictions, registration, release blocking, and controlled failure recovery. |
| **Golden paths and operator permissions** | Authorized operators complete supported lifecycle routines; unauthorized execution and unsupported requests are denied or routed to accountable review. |
| **Safe change and drift correction** | Regression tests, staged validation, bounded rollout, stop conditions, recovery, and verified correction of treatment drift produce retained evidence. |
| **Service reliability and recovery** | Agreed SLIs/SLOs, error-budget rules, tested alert routing, and partial-failure recovery demonstrate measurable, supported operation. |
| **Maintained treatment** | Changes and findings reach accountable owners, trigger reassessment, and update affected decisions and controls. |
| **Traceable exceptions** | Restricted assets have valid approvals, verified restrictions, remediation ownership, expiry, and defined disposition. |
| **Reusable evidence** | Authorized oversight functions retrieve current facts, policy/configuration versions, approvals, and enforcement results directly; unauthorized evidence access is denied. |
| **Sustainable operation and learning** | Named owner, supported scope, cost/capacity and toil baselines, stakeholder feedback, and blameless postmortem actions support tracked, verified improvements. |

**Immediate delivery establishes these golden paths, engineering and reliability controls, evidence access, and operating ownership.** Strategy section 4.3 extends their coverage and automation; later workstreams consume them within their approved scope.

## Later delivery interfaces

| Supporting problem statement | Use of the maintained record |
| :--- | :--- |
| [Migration Delivery](03-migration_delivery.md) | Consume disposition and readiness information; return validation findings and acceptance evidence. |
| [Sandbox Data Copying](04-sandbox_data_copying.md) | Check classification and eligibility; record event authorization, verification, expiry, and cleanup. |
| [Retention and Archive Controls](05-retention_and_archive.md) | Apply preservation, hold, archive, and disposal decisions; retain completion evidence. |
| [Governed Rovo Enablement](06-rovo_enablement.md) | Check source admission and conditions; return evaluation findings and changed suitability. |
| [Continuous Governance](07-continuous_governance.md) | Extend reassessment, detection, exception handling, and evidence across subsequent capabilities. |

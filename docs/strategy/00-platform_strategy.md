# Atlassian Cloud Platform Strategy

Alignment review draft | 20 October 2026.

The strategy takes a **governance, risk and compliance approach to building Atlassian Cloud**. Applicable obligations, approved policies, and risk decisions drive architecture, asset treatment, engineering, and operation.

**Immediate delivery is Cloud Foundation and Asset Ownership and Treatment.** The [README](README.md) provides the entry point; this strategy records the reasoning, governing choices, actions, measures, and dependencies.

## 1. Purpose and scope

**Establish the shared control baseline and data-governance mechanism together.** Platform configuration implements approved requirements; maintained asset records and verified enforcement determine permitted use. Installation alone does not establish readiness.

| Aspect | Boundary |
| :--- | :--- |
| **Services** | Jira, Jira Service Management, and Confluence, classified as Tier 2/3 Internal Collaboration Tools. |
| **Estate** | Projects, spaces, their approved configuration standards, content, attachments, users, groups, add-ons and Marketplace apps, integrations, automations, and service accounts. |
| **Lifecycle** | Immediate establishment, controlled asset creation, operation, and change. Subsequent work extends the controls to migration, reuse, archive, and retirement. |
| **Stakeholders** | Platform and service teams, application and asset owners, enterprise governance and control functions, executive oversight, and independent assurance. |
| **Immediate delivery** | Cloud Foundation and Asset Ownership and Treatment, as defined in sections 4.1–4.2. |
| **Subsequent delivery** | Sections 4.3–4.8 record future direction, not current delivery authorization. Scope, capacity, dependencies, and readiness require separate agreement. |
| **Target architecture** | One Atlassian Organization, one production Jira site, and one production Confluence site. |
| **Data placement** | Supported product data in Germany or the EU, subject to product and regulatory assessment. Processing outside that boundary requires separate assessment. |
| **Exclusions** | Core banking systems of record and synthetic test-data generation. Business-process redesign remains an asset-owner responsibility. |

The [previous strategic overview](../README.md) is preserved for reference. Current immediate scope is defined here and in the revised [README](README.md).

## 2. Diagnosis

**The central challenge is translating enterprise requirements into controls and accountable data handling that remain effective through operation and change.** A new Cloud environment does not resolve ownership, permitted use, control coverage, or supplier limitations by itself.

The reported maturity starting point is **Operationalized**, with **Scalable** as the target. This describes the engineering direction, not verified readiness of the new Cloud platform; control coverage, reliability, evidence, and operating capacity require their own baselines.

| Condition | Consequence |
| :--- | :--- |
| **Incomplete asset accountability** | Gaps in ownership, Business Application association, and classification prevent reliable decisions about admission, access, reuse, retention, and retirement. |
| **Configuration and dependency variation** | Different configurations, apps, and integrations increase preparation, testing, support, and control-verification effort. |
| **Limited central capacity** | Central investigation, bespoke engineering, and repeated evidence collection compete with roadmap delivery and ongoing operation. |
| **Decisions lose currency** | Ownership, purpose, permissions, and dependencies change. Initial approval alone cannot demonstrate continued suitability or control effectiveness. |
| **Supplier-dependent capabilities** | Protection, monitoring, configuration, and recovery depend partly on supplier capabilities. Requirements must be assessed against demonstrated coverage and explicit responsibility boundaries. |
| **Future transition and source retirement** | Preservation and transition requirements must inform initial design without treating later migration execution as immediate delivery. |

Provisioning establishes product instances. It does not determine acceptable handling, demonstrate effective controls, or establish the operating capability needed to sustain them.

**Cloud Foundation establishes shared guardrails; Asset Ownership and Treatment applies policy to individual projects and spaces.** Neither is complete without the required approvals, enforcement, evidence, and response to change.

Baseline measures of **control coverage, reliability, operational toil, and team capacity** are needed to quantify the maturity gap and set achievable improvement targets.

## 3. Guiding policy

**Derive the Cloud baseline and asset treatment from applicable governance, risk, and compliance requirements. Verify enforcement before approved use, maintain accountable decisions, and use repeatable engineering and current evidence to sustain control effectiveness.**

| Policy | Required approach |
| :--- | :--- |
| **Translate requirements into shared controls** | Link applicable requirements to the Cloud baseline, operating responsibilities, verification, and treatment of gaps before dependent use. |
| **Maintain accountable asset treatment** | Require validated ownership, a valid active ServiceNow Business Application association, and validated classification for normal active use. Reassess treatment after material changes and expiry. |
| **Standardise projects and spaces** | Use approved, versioned patterns for supported Jira project and Confluence space types. Record the selected pattern, verify conformance, and govern variation through approved extensions or exceptions. |
| **Keep treatment decisions independent** | Maintain separate migration, Rovo, sandbox, and retention outcomes. Recording them establishes the governance model; it does not authorize delivery or activation of those later services. |
| **Apply policy and configuration as code** | Version, review, and test supported policy rules and configurations. Detect drift and resolve deviations through remediation or authorized, time-bound exceptions. |
| **Establish initial golden paths** | Deliver supported paths and governed operational self-service for platform teams in sections 4.1–4.2. Extend coverage and automation under section 4.3. |
| **Engineer reliable, sustainable operation** | Establish initial service indicators, objectives, and error-budget decision rules. Use observability, recovery testing, toil reduction, and blameless postmortems to guide improvements. |
| **Produce evidence through operation** | Capture control evaluations, changes, tests, and exceptions as work occurs. Provide self-service evidence access for authorized governance, risk, and assurance functions. |
| **Respect demonstrated capability boundaries** | Verify supplier and platform coverage before relying on a control. Unsupported requirements require remediation, exclusion, or a permissible approved exception. |

Unsupported automation requires documented coverage limits, controlled procedures, accountable operators, and retained verification evidence. Numerical service targets and detailed tool choices require agreement before dependent use.

**Risk acceptance cannot waive a legal obligation or legal hold.**

## 4. Coherent actions

**Immediate delivery establishes platform and data-governance controls through sections 4.1–4.2. Sections 4.3–4.8 retain future direction and dependencies; they are not a current execution plan.**

| Delivery horizon | Scope | Required outcome |
| :--- | :--- | :--- |
| **Immediate: sections 4.1–4.2** | Establish the shared baseline and asset treatment through initial golden paths, policy and configuration as code, operator routines, reliability controls, and evidence. | Demonstrate controlled operation, verified treatment, recovery, and evidence retrieval within agreed permissions and capacity. |
| **Future: sections 4.3–4.8** | Extend platform capabilities and deliver migration, controlled sandbox copying, retention and archive, governed Rovo, and broader continuous governance. | Build on verified foundations, with scope, capacity, dependencies, and acceptance criteria agreed before execution. |

### 4.1 Establish the Cloud foundation

**The platform team, working with enterprise architecture and control functions, will translate applicable requirements into a verified shared Cloud baseline.** Control effectiveness and accountable treatment of gaps, not completion of configuration, determine readiness.

Manage the foundation as a platform product: name its owner, supported scope, operating capacity, cost baseline, feedback route, and prioritized improvements.

Project and space standards support approved variants rather than one configuration for every team. Relevant architecture and control authorities approve patterns and extensions.

| Action | Required completion evidence |
| :--- | :--- |
| **Establish architecture and processing boundaries** | Agreed Organization and site configuration, assessed data placement and processing, and documented supplier responsibilities and limitations. |
| **Establish identity and access controls** | Tested federation, provisioning, group reconciliation, access removal, and session revocation, with approved treatment for exceptional accounts. |
| **Constrain exposure** | Verified controls for anonymous access, public links, external sharing, and supported network restrictions, with explicit treatment of uncovered surfaces. |
| **Establish detection and response** | Demonstrated detection coverage, tested response actions, named response owners, and recorded gaps and exceptions. |
| **Assess apps and integrations** | Approved dependencies with assessed permissions, processing, supplier assurance, support, and offboarding arrangements. |
| **Standardise Jira projects** | Approved, versioned patterns define project types/templates, naming, workflows/statuses, issue types, fields/screens, roles, permission/notification schemes, security defaults, and permitted automation/add-on use. |
| **Standardise Confluence spaces** | Approved, versioned patterns define space types/templates, naming, page/content conventions, permissions/restrictions, sharing defaults, ownership/classification records, and review/lifecycle rules. |
| **Establish service and recovery readiness** | Named owners, initial SLIs/SLOs, error-budget rules, actionable alerts, exercised support escalation, and tested recovery distinguish internal and supplier responsibilities. |
| **Publish foundation golden paths** | Supported identity/access and configuration-change paths, with operator permissions, approvals, automated tests where supported, bounded rollout, stop conditions, and recovery evidence. |
| **Apply policy and configuration as code** | Reviewed baseline and rule versions, permitted/denied test results, drift checks, and approved treatment of unsupported automation. |

**Dependency gate:** Applicable shared controls have passed verification. Gaps have agreed treatment, accountable owners, and any required exception approval before dependent use.

Supporting problem statement: [Cloud Foundation](01-cloud_foundation.md).

### 4.2 Establish asset ownership and treatment

**The platform team will establish data governance through a maintained control record for each Jira project and Confluence space.** Validated facts, applicable policies, accountable approvals, and verified enforcement determine permitted handling. Jira Service Management will manage intake and attestation, linked to the ServiceNow Business Application and accountable business owner.

Manage the treatment mechanism as a platform product: name its owner, supported operations, capacity, cost baseline, feedback route, and improvement priorities.

| Action | Required completion evidence |
| :--- | :--- |
| **Establish the asset record** | Recorded identity, ownership, administrators, Business Application association, purpose, lifecycle, classification, intended audience, and applicable handling obligations. |
| **Validate declarations** | Owner attestations checked against ServiceNow and available lifecycle, activity, permission, and detection evidence. Material discrepancies are resolved or receive approved treatment. |
| **Determine independent treatment outcomes** | Separate decisions for **migration disposition, Rovo admission, sandbox eligibility, and retention disposition**, with supporting approvals and exceptions. |
| **Apply the approved asset standard** | Select the project/space pattern appropriate to the validated use and treatment. Record its version and any approved variation, apply required settings, and verify conformance before release. |
| **Apply and verify treatment** | Required metadata, permissions, and capability restrictions are implemented and tested before the approved use begins. |
| **Publish asset-lifecycle golden paths** | Tested onboarding/release, reassessment, and exception-handling paths that platform operators execute within approved permissions and required human approvals. |
| **Apply policy and configuration as code** | Versioned treatment rules and supported workflow/enforcement configurations, with automated tests, staged validation, bounded rollout, and failure-recovery evidence. |
| **Control unresolved assets** | Missing, disputed, or expired information blocks normal admission. Restricted handling has approved scope, an accountable remediation owner, and an expiry date. |
| **Maintain decisions and evidence** | Changes, findings, drift, and review dates trigger reassessment. Authorized oversight retrieves current evidence directly; workflow measures, failure reviews, and toil guide improvements. |

**Dependency gate:** Each asset entering normal active use has validated ownership, a valid active ServiceNow Business Application association, validated classification, an applied and verified project/space standard or approved variation, and verified treatment for its intended use.

A decision not to migrate does not close the record. Preservation and disposal still require explicit treatment.

Supporting problem statement: [Asset Ownership and Treatment](02-asset_ownership_treatment.md).

## Future direction: sections 4.3–4.8

The following actions preserve the wider strategy without expanding immediate delivery. Each workstream requires separate scoping against stakeholder priorities, capacity, and demonstrated readiness; preparations that affect initial requirements may proceed without authorizing dependent use.

### 4.3 Establish scalable platform capabilities

**We will expand the five platform capabilities first applied in sections 4.1–4.2 across the estate.** Initial golden paths, operator self-service, reliability controls, and evidence access are delivered with the foundations; this section extends their coverage and automation.

| Capability | Work to deliver | Completion evidence |
| :--- | :--- | :--- |
| **Platform product management** | Extend foundation ownership and priorities into a capability catalogue and roadmap, informed by adoption, lifecycle, cost, capacity, and stakeholder feedback. | Offerings have owners and support boundaries. Investment and retirement decisions trace to outcomes, feedback, and operating capacity. |
| **Governance and control integration** | Expand policy as code, automated control checks, drift reporting, and exception integration. | Extended rules pass policy tests. Results identify affected assets, requirements, deviations, and approved exceptions. |
| **Reusable platform engineering** | Extend golden paths, configuration as code, operational self-service, automated regression tests, and progressive delivery to additional supported operations. | New paths pass permission, rollout, stop-condition, and recovery checks; operators can use them within defined boundaries. |
| **Reliable operations and safe change** | Expand service-objective coverage, error-budget management, observability, and recovery exercises from the initial baselines. | Performance, alerts, and recovery results support change and reliability decisions across additional capabilities. |
| **Evidence, measurement, and learning** | Aggregate self-service evidence and extend toil reduction and learning from blameless postmortems across capabilities. | Oversight functions assess current coverage directly. Corrective actions and reductions in recurring effort have verified results. |

**Delivery dependency:** Each capability builds on the applicable shared controls and asset records established in sections 4.1–4.2. Its supported scope, operating ownership, and acceptance checks must be agreed before release.

Detailed requirements and acceptance checks will be developed in supporting problem statements.

### 4.4 Prepare and migrate through product-specific waves

**Migration will use the verified Cloud foundation and validated asset-treatment decisions to move eligible assets through controlled, product-specific waves.** Delivery will be planned against available capacity, dependencies, and the source-retirement window.

Migration and required preservation must complete with contingency before the affected Data Center products reach end of life on **28 March 2029** ([Atlassian lifecycle guidance](https://www.atlassian.com/licensing/data-center-end-of-life)).

Migration tooling addresses content transfer and supported configuration changes. It does not establish accountable ownership, determine acceptable treatment, or provide the operating capability required to sustain the platform.

The central migration factory will operate the **Jira Cloud Migration Assistant (JCMA)** and **Confluence Cloud Migration Assistant (CCMA)**. Business owners and administrators complete asset-specific preparation; specialists resolve complex dependencies.

| Handling pattern | Jira focus | Confluence focus |
| :--- | :--- | :--- |
| **Wave 0: Trial** | Prove tooling, identity, permissions, migration, and validation. | Prove user, page, attachment, permission, and rendering behavior. |
| **Waves 1–2: Factory** | Supported native configurations, common workflows and fields, and supported apps. | Supported editors, macros, templates, and standard page structures. |
| **Wave 3: Owner-prepared** | Owner/admin remediation before scheduled factory execution. | Macro, editor, attachment-link, and content remediation before execution. |
| **Wave 4: Specialist** | ScriptRunner, app-owned fields, JSM/Assets, and complex integrations. | Heavy app dependence, custom macros, calendars, and large spaces. |
| **Wave 5: Exception or restricted** | Dependencies or handling requirements needing an individually justified path. | Unsupported capabilities, regulated knowledge, or content requiring re-platforming. |
| **Cutoff/default** | Unattested, unmapped, or unresolved projects. | Unattested, orphaned, inactive, or unresolved personal spaces. |

Wave numbers describe handling patterns, not a rigid sequence. Specialist preparation starts early. Jira and Confluence maintain separate plans with explicit cross-product dependencies.

**Customization alone does not block migration. Unacceptable loss, exposure, outage, or unresolved regulatory risk does.**

Every wave follows readiness, rehearsal, cutover, validation, and acceptance. Before upload, remediate exposed credentials. Before cutover, establish the authoritative system, stop criteria, rollback and reconciliation arrangements, communications, and support.

Validate content reconciliation, attachments, permissions, required functionality, integrations, and Rovo treatment. Record business and technical acceptance.

Restricted landing requires an approved, expiring exception, a named remediation owner, verified access restrictions and Rovo exclusion, disabled external access, and a defined resolution path. Routine sandbox copying remains excluded.

| Phase | Exit evidence |
| :--- | :--- |
| **0. Establish the platform and delivery baseline** | Verified foundation, trial capability, sandbox allocation, dated wave plan, capacity, internal completion target, contingency, and named archive destination and owners. |
| **1. Prepare assets** | Validated asset treatment, dependency disposition, remediation, tool eligibility, preservation routing, and assigned validation packs. |
| **2. Execute waves** | Successful rehearsal, controlled cutover, completed validation, accepted differences, and business/technical sign-off. |
| **3. Retire and hand over** | Data Center read-only after final waves and before end of life; required preservation and retrieval accepted before decommissioning; ongoing controls transferred to named owners. |

**Tool completion is not migration completion. Readiness evidence determines entry; validation evidence determines acceptance.**

**Migration readiness:** Applicable foundation controls, asset treatment, dependency preparation, rehearsal, validation, and rollback arrangements are verified before cutover.

Supporting problem statement: [Migration Delivery Model](03-migration_delivery.md).

### 4.5 Control production data copying to sandboxes

**Sandbox copying will extend the shared asset-treatment controls to a specific testing purpose, destination, and access window.** Approved eligibility must be verified for each copy.

The Dev Platform team will control **eligibility, copy scope, destination protection, access duration, and cleanup**.

| Control | Required treatment |
| :--- | :--- |
| **Authorize the copy** | Confirm owner, Business Application association, validated classification, documented test need, current eligibility, and applicable approvals. |
| **Minimize data** | Development sandboxes use a minimized eligible Internal subset. UAT sandboxes receive only the eligible projects, spaces, and attachments needed for their tests. |
| **Protect and verify** | Verify destination users, permissions, external sharing, monitoring, actual copied content, identities, and relevant app data before tester access. |
| **Close the event** | Record the copy owner, access window, expiry, cleanup obligation, and verified disposition. Access removal alone does not prove deletion. |

The initial approach uses Atlassian-native controls and treats copied data as **unmasked production data**. Selective copying reduces scope; it does not sanitize retained content. [Atlassian sandbox-copy capability](https://support.atlassian.com/organization-administration/docs/copy-production-data-to-sandbox/).

Restricted and Confidential data are excluded from routine copies. Restricted exceptions require GRC/Security approval; Confidential exceptions require Business App Owner approval and Security/Data Governance review. Exceptions must address unmasked exposure, effective controls, expiry, and cleanup. Public data requires exception approval.

Unclassified-Restricted data remains excluded unless classification is completed or an urgent request follows the Restricted exception process.

**Decline the copy where adequate protection cannot be demonstrated.** Use an eligible Internal subset only where it meets the test objective; record unmet testing needs.

Development and UAT copies originate from Cloud Production. Migration rehearsals use a separately governed temporary validation process. Synthetic generation is excluded; third-party tooling requires a separate decision.

**Copy readiness:** Eligibility, authorization, destination protection, and cleanup obligations are established before copying; copied content and access are verified before tester access.

Supporting problem statement: [Sandbox Data Copying](04-sandbox_data_copying.md).

### 4.6 Enforce retention and archive controls

**Retention and archive capabilities will preserve required records throughout platform change and source retirement.** Preservation obligations remain independent of migration disposition and operational use.

Legal/Records will establish obligations; the migration programme coordinates preservation; a named archive owner operates the retained service.

| Control | Required treatment |
| :--- | :--- |
| **Establish requirements** | Identify covered records, retention basis, period, starting event, holds, ownership, and disposal authority. Confirm the scope of any ten-year requirement. |
| **Prepare preservation** | Determine required content, attachments, context, metadata, relationships, and history. Name the archive destination and owner at Phase 0 exit. |
| **Verify and accept** | Reconcile transferred records, verify integrity, demonstrate authorized retrieval, and obtain Records/Legal acceptance. |
| **Operate and dispose** | Maintain access, retrieval, and hold controls. Authorize and evidence disposal only when all applicable requirements permit it. |

Inactivity, migration exclusion, retirement, or an expired testing purpose does not authorize deletion. Unresolved obligations require preservation and escalation. A backup or product archive flag does not by itself establish compliance.

**Preservation readiness:** Archive readiness is resolved before Data Center becomes read-only. Required preservation and retrieval are operational and accepted before source deletion or decommissioning.

Supporting problem statement: [Retention and Archive Controls](05-retention_and_archive.md).

### 4.7 Enable governed Rovo capabilities

**Rovo capabilities will be introduced through bounded, evaluated pilots using approved sources and explicit action permissions.** Expansion will depend on demonstrated usefulness and effective controls.

AI governance and knowledge owners are accountable for this work.

| Control | Required treatment |
| :--- | :--- |
| **Establish source trust** | Identify ownership, classification, authority, currency, approved purposes, and source precedence. Working material does not become authoritative automatically. |
| **Enforce permitted scope** | Verify source permissions, Teamwork Graph connector scope, and agent configuration. Labels and instructions alone do not establish enforceable boundaries. |
| **Bound agent authority** | Define execution identity, tools, read/write access, external actions, human approval, and accountability. Govern agent creation and configuration changes. |
| **Evaluate usefulness and protection** | Test task outcomes, accuracy, attribution, permitted/denied access, malicious source instructions, unauthorized actions, and failures. |
| **Maintain suitability** | Reassess changed sources and capabilities, withdraw unsuitable use, and review AI write-back before it becomes trusted knowledge. |

**Source admission does not authorize every use case or agent action.**

Confirm vendor processing, residency, contractual terms, data contribution, and required audit coverage before pilot entry. Regulated decisions, credit, insurance, HR, customer-impacting triage, and external actions require applicable risk classification and governance approval.

Expand only where usefulness and control evidence support the new scope. Defer affected source landing or Rovo enablement where required boundaries cannot be enforced.

**Pilot readiness:** Source suitability, access and action boundaries, vendor processing, applicable approvals, and evaluation criteria are established before pilot entry.

Supporting problem statement: [Governed Rovo Enablement](06-rovo_enablement.md).

### 4.8 Extend continuous governance across the estate

**Continuous governance will extend the ownership, treatment, and evidence controls established in sections 4.1–4.2 across subsequent platform capabilities and delivery workstreams.** Reviews and event-driven checks will maintain their effectiveness as the estate changes.

Named operating owners will maintain the shared asset record and apply controls to creation, material change, copying, recertification, and retirement.

| Trigger | Required response |
| :--- | :--- |
| **Scheduled review or expired attestation** | Revalidate ownership, classification, four treatment outcomes, and exceptions. Apply restrictive handling where required information is missing or expired. |
| **Owner or Business Application change** | Use corporate identity and ServiceNow information to trigger reassignment and lifecycle review. |
| **Permission or sensitive-data finding** | Contain exposure, reassess classification, suspend affected reuse, and retain remediation evidence. |
| **Sandbox or Rovo incident** | Stop affected use, review the source decision, and verify remediation before resumption. |
| **Configuration change** | Use controlled change records, sandbox testing, required approval, and post-release validation for workflows, permissions, automations, and integrations. |

GRC will establish recertification cadence, response windows, non-response consequences, and campaign ownership. Platform, Security, and AI/Data Governance functions will define detection coverage, response ownership, and integration requirements before handover.

**Operating readiness:** Detection coverage, review cadence, response ownership, exception handling, and evidence access are established before each dependent capability enters ongoing operation.

Supporting problem statement: [Continuous Governance](07-continuous_governance.md).

## 5. Accountability and measures

**The platform team will own delivery and operation of approved controls. Business owners, enterprise control functions, executive oversight, and independent assurance retain their respective mandates.** The [README](README.md#accountability) provides the stakeholder overview; the accountabilities below govern execution of this strategy.

| Function | Primary accountability |
| :--- | :--- |
| **Platform operations and engineering** | Deliver and maintain the foundation, asset-control mechanisms, supported patterns, automation, reliability, and operational evidence. |
| **Business application and asset ownership** | Validate asset facts, purpose, classification, and intended use; complete owned preparation, remediation, and acceptance. |
| **Enterprise governance and control functions** | Define applicable security, data, architecture, service, resilience, risk, and compliance requirements; exercise oversight and exception authority within their mandates. |
| **Executive sponsorship and oversight** | Set direction, agree priorities and capacity, review outcomes and constraints, and resolve escalated dependencies and risks. |
| **Independent assurance** | Independently assess control design and effectiveness using current platform evidence; retain independent judgment over findings and closure. |
| **Enterprise asset data management** | Maintain authoritative Business Application ownership and lifecycle information used to validate platform asset records. |
| **Legal, records, and procurement functions** | Establish applicable obligations, preservation requirements, supplier assessments, and contractual treatment within their respective mandates. |

Platform operations and engineering will name operating owners for each golden path and service mechanism, including its tests, alerts, drift response, recovery, and evidence. Significant failures receive blameless postmortems; owners verify corrective actions and reductions in recurring toil.

**Establish baselines, targets, and review cadence during immediate delivery.** Add workstream-specific measures when later delivery is scoped.

| Horizon | Measure | Evidence to review |
| :--- | :--- | :--- |
| **Now** | **Foundation readiness** | Applicable control coverage, verification results, supplier limitations, unresolved gaps, and approved exceptions. |
| **Now** | **Accountable asset treatment** | Validated ownership, Business Application association, classification, independent treatment decisions, and implemented restrictions. |
| **Now** | **Project and space conformance** | Applied pattern/version, required settings, approved variants/exceptions, unapproved customisation, and configuration drift. |
| **Now and later** | **Delivery and operating capacity** | Roadmap progress, dependency blockers, operational toil, available capacity, and cost against agreed commitments. |
| **Now and later** | **Platform scalability** | Initial and expanded golden-path use, operator self-service, bespoke configurations, drift, and repeated specialist intervention. |
| **Now and later** | **Service reliability** | Agreed foundation and treatment-mechanism SLO performance, error-budget consumption, incidents, change failures, and recovery tests. |
| **Now and later** | **Assurance effectiveness** | Direct evidence retrieval, completeness and currency, collection effort, unresolved findings, and verified postmortem and assurance actions. |
| **Later** | **Workstream outcomes** | Migration acceptance and contingency; sandbox protection and cleanup; preservation and retrieval; Rovo usefulness and control effectiveness. |

For each measure, define its owner, source, collection method, review frequency or trigger, threshold, and resulting action.

## 6. Delivery dependencies

**Resolve immediate dependencies before dependent platform use. Identify later dependencies early and resolve them before the activity they affect.** Record accountable owners, required decisions, and resolution dates.

| Horizon | Dependency | Required resolution point |
| :--- | :--- | :--- |
| **Now** | **Shared platform baseline** | Architecture, licensing, identity, processing boundaries, supplier responsibilities, and applicable controls verified before dependent use. |
| **Now** | **Accountable asset treatment** | Ownership, authoritative application records, classification, permissions, and required treatment decisions validated before normal active use. |
| **Now** | **Project and space standards** | Supported patterns, approved versions, variation authority, and conformance checks established before dependent asset creation or release. |
| **Now** | **Operating ownership and evidence** | Initial golden paths, operator permissions, service measures, response and recovery procedures, capacity, and evidence access verified before operation. |
| **Later** | **Expanded platform capabilities** | Additional supported scope, dependencies, capacity, operating ownership, and acceptance checks agreed before expansion. |
| **Later** | **Migration readiness** | Product dependencies, preparation, rehearsals, validation, rollback, dated delivery plans, and contingency established before dependent cutovers. |
| **Later** | **Preservation and source retirement** | Archive destination and owner identified during migration planning; readiness resolved before read-only operation and preservation accepted before decommissioning. |
| **Later** | **Sandbox and Rovo readiness** | Eligibility, destination or source boundaries, approvals, protection, and evaluation arrangements established before copying or pilot entry. |
| **Later** | **Expanded continuous governance** | Review triggers, detection coverage, response ownership, integrations, and evidence access established before dependent capabilities enter ongoing operation. |

The [decision register](08-decisions_and_dependencies.md) must hold unresolved choices, accountable functions, and required dates. Its current placeholder is not evidence that those choices have been recorded or resolved.

**Schedule pressure does not authorize bypassing entry controls, preservation obligations, or legal holds.**

# Cloud Foundation

Supports [strategy action 4.1: Establish the Cloud foundation](00-platform_strategy.md#41-establish-the-cloud-foundation).

Alignment review draft | 20 October 2026.

## 1. Business context and problem

**Establish and demonstrate a governed, reliable shared Cloud foundation before dependent workloads enter service.**

- **GRC-led design:** Applicable obligations, approved policies, and risk decisions determine the foundation, its operating boundaries, and required evidence. Configuration implements these requirements; installation alone does not establish readiness.
- **Service scope:** Jira, Jira Service Management, and Confluence are **Tier 2/3 Internal Collaboration Tools**. Their foundation must support onboarding, operation, and change within approved security, processing, and recovery boundaries.

| Aspect | Boundary |
| :--- | :--- |
| **Immediate scope** | Establish shared controls, standardised project/space patterns, approved add-ons, Marketplace apps, integrations, and automations, with verified configuration and operating evidence. |
| **Platform product management** | Name the foundation owner, supported scope, support boundaries, cost and capacity baseline, stakeholder feedback route, and prioritized improvements. |
| **Target architecture** | Atlassian-operated Cloud Enterprise, outside the firm's public-cloud tenancy: one Atlassian Organization, one production Jira site, and one production Confluence site. |
| **Asset accountability** | Business owners establish asset facts and intended use. [Asset Ownership and Treatment](02-asset_ownership_treatment.md) selects approved patterns, validates dependency use, and verifies asset-level enforcement. The foundation maintains shared standards and capabilities. |
| **Dependent delivery** | Migration execution, sandbox-copy services, an archive solution, and Rovo rollout are outside immediate delivery. Their requirements inform the foundation; later use requires separate readiness checks. |
| **Later expansion** | Strategy section 4.3 extends the golden paths, operational self-service, reliability practices, and evidence access first established here to additional operations and capabilities. |

## 2. Required foundation

### A. Tenant architecture and data sovereignty

**Establish the approved architecture and demonstrate where information is stored and processed.**

| Requirement | Required approach |
| :--- | :--- |
| **Organization and sites** | Establish the target Organization and production sites, with documented administrative ownership, subscriptions, and capacity. |
| **Product residency** | Pin supported product data to Germany or the EU following regulatory and capability assessment. |
| **Processing boundary** | Identify account metadata, telemetry, administration data, and third-party processing outside the selected product-residency boundary. |
| **Cross-border assessment** | Assess processing and transfers for London HQ and regional operations, including Singapore and Australia. Record conditions, supplier commitments, and exclusions. |
| **Workload eligibility** | Exclude workloads whose mandatory placement or processing requirements cannot be met by the shared architecture. |

Residency covers supported in-scope data; it does not establish total-tenant residency or independent placement by project, space, or user. [Atlassian residency scope](https://support.atlassian.com/security-and-access-policies/docs/understand-data-residency/).

### B. Identity federation and access lifecycle

**Make access follow corporate identity decisions, with explicit controls for exceptional accounts.**

| Requirement | Required approach |
| :--- | :--- |
| **Managed authentication** | Federate managed users through Atlassian Guard and corporate identity-provider SAML single sign-on. Apply verified-domain controls and authentication policies. |
| **Provisioning** | Use SCIM lifecycle synchronization. Reconcile duplicate accounts, conflicting groups, unsupported nesting, and applicable group limits before dependent onboarding. |
| **Exceptional identities** | Define ownership, authentication, scope, review, and revocation for external, unmanaged, privileged, service, and emergency-access accounts. |
| **Authorization patterns** | Establish supported Jira role, permission-scheme, and issue-security patterns, and Confluence space-permission and page-restriction patterns. |
| **Revocation** | Verify access removal following identity-provider deactivation. Test session revocation separately, including exceptional accounts. |
| **Inactivity** | Run automated quarterly checks for accounts inactive over 30 days. Deactivate or suspend accounts subject to documented preservation, service, emergency-access, and regulatory-evidence exceptions. |

**Authentication does not establish authorization.** Access must remain within the approved role and asset audience.

### C. SaaS ingress, egress, exposure, and response

**Apply enterprise ingress and egress policy across the SaaS boundary; do not assume the firm's public-cloud network controls extend into Atlassian's environment.**

- **Connection perspective:** Atlassian defines ingress/egress by the initiating side; firm-to-SaaS connections are firm egress/SaaS ingress, and callbacks reverse that perspective ([Atlassian network definitions](https://support.atlassian.com/organization-administration/docs/ip-addresses-and-domains-for-atlassian-cloud-products/)).
- **Connection direction is not data direction:** Assess uploads, read responses, exports, and onward copies separately; a client-initiated connection must not imply unrestricted data return.

| Requirement | Required approach |
| :--- | :--- |
| **Policy mapping and ownership** | Map firm network, access, and data-transfer requirements to actual SaaS and firm enforcement points. Security, Network, and Data Governance approve within their mandates; platform and integration owners implement, monitor, and retain evidence. |
| **Firm egress / SaaS ingress** | Approve service domains, routes, protocols, and public source addresses seen by Atlassian. Use approved corporate access paths and supported product IP allowlists alongside identity and permissions; verify browser, API, and attachment access. Domain access alone does not approve another tenant or a data transfer. |
| **SaaS egress / firm ingress** | Use an approved authenticated integration gateway or equivalent boundary pattern for callbacks and webhooks. Permit only required endpoints and operations; validate identity, payloads, rate limits, and failure handling. IP ranges alone must not authenticate a tenant or justify direct access to internal services. |
| **Cloud-to-cloud flows** | Approve app, integration, automation, and webhook destinations and permitted payloads. Verify controls at the SaaS configuration, app, or receiver; do not assume these paths traverse a firm proxy or firewall. |
| **Data entering and leaving SaaS** | Approve source data, classification, purpose, recipients, and onward use. Minimise and screen uploads as required; constrain exports, downloads, notifications, API reads, and app transfers through supported controls. Residency selection does not replace transfer approval. |
| **Public and external exposure** | Disable or constrain anonymous access, public links, and external sharing by default. Exceptions require approved scope, expiry, and monitoring. |
| **Administrative access** | Assess administration, organization APIs, provisioning, service accounts, and emergency access separately. Apply privileged-access controls, applicable identity policies, approved execution paths, and monitoring; test coverage rather than inheriting product assumptions. |
| **Network change** | Maintain approved domains and direction-specific address ranges from vendor publications, with change monitoring and regression tests. Security review must approve any proxy or TLS-inspection exception and its compensating controls. |
| **Sensitive-content detection** | Configure supported Guard Premium detections for credentials, financial identifiers, regulated personal information, and approved policy-sensitive terms. Record content coverage and scanning triggers. |
| **Response and evidence** | Route supported alerts and audit events to the corporate SIEM and accountable responders. Define investigation, restriction, ticketing, and supported redaction actions. |
| **Coverage gaps** | Record unsupported enforcement, inspection, and logging, including unscanned content. Restrict affected flows, apply approved compensating controls, obtain a permissible time-bound exception, or exclude the workload. |

- **Allowlist coverage:** Product IP allowlists exclude organization administration and organization-level APIs ([Atlassian allowlist scope](https://support.atlassian.com/atlassian-cloud/kb/what-is-the-scope-of-ip-allowlists-in-atlassian-cloud/)). Documented exceptions also include Connect, Forge, and OAuth 3LO apps; assess each path independently ([Atlassian allowlist exceptions](https://support.atlassian.com/security-and-access-policies/docs/specify-ip-addresses-for-product-access/)).
- **Data-control coverage:** Native export blocking does not prevent Marketplace/custom-app export or browser print/save actions ([Atlassian export limitations](https://support.atlassian.com/security-and-access-policies/docs/prevent-data-export/)). App-access controls have exclusions and do not remove data already stored externally ([app-access coverage](https://support.atlassian.com/security-and-access-policies/docs/app-access-rule-coverage-summary/) and [previously stored app data](https://support.atlassian.com/security-and-access-policies/docs/block-app-access/)).
- **Published endpoints:** Atlassian uses shared ranges rather than a fixed IP per site; maintain approved rules against current vendor publications ([Atlassian domains and address ranges](https://support.atlassian.com/organization-administration/docs/ip-addresses-and-domains-for-atlassian-cloud-products/)).
- **Detection limits:** Detection is not universal prevention or automatic sanitization; record supported content and scanning triggers ([Atlassian detection coverage](https://support.atlassian.com/security-and-access-policies/docs/what-sensitive-data-is-detected/)).

**Production protection does not establish sandbox protection.** Verify applicable sandbox controls before copied data is released for testing.

### D. Add-ons, apps, integrations, and automations

**Support extensions and connections without bypassing platform controls.**

| Requirement | Required approach |
| :--- | :--- |
| **App and add-on approval** | Govern installation and user consent. Assess permissions, processing, residency, supplier assurance, support, Cloud availability, and offboarding for proposed Marketplace, custom, and user-consented apps. |
| **Approved dependency register** | Record each dependency and permitted flow: owner, purpose, source/destination system and tenant, connection initiator, data direction/classification, endpoint, identity, route, enforcement point, logging, approvals, configuration/version, and review conditions. Link asset use to this record. |
| **Supported interfaces** | Identify replacements or remediation for direct database access, local scripts, and custom endpoints that cannot continue in Cloud. |
| **Connection controls** | Implement the section C boundary pattern. Define authentication, permitted operations/payloads, access scope, credential lifecycle, monitoring, and revocation; minimise supplier-held copies and record retention/offboarding obligations. |
| **Automation controls** | Approve triggers, execution identity, affected assets, actions, recipients, and data destinations. Verify effective permissions, failures, and containment; automation must not bypass approved handling. |
| **Compatibility** | Assess account identifiers, payloads, webhooks, pagination, and rate handling. Assign dependency owners before dependent onboarding or migration rehearsals. |
| **Change and withdrawal** | Reassess changed permissions, processing, destinations, or supplier terms. Identify affected assets and verify restriction, replacement, or offboarding when approval expires or is withdrawn. |

**Platform approval is not blanket permission to use a dependency.** Each project or space must validate its intended use, data scope, and configuration through asset treatment.

### E. Reliability, recovery, and service operation

**Establish measurable service expectations and demonstrate how the platform will be supported and recovered.**

| Requirement | Required approach |
| :--- | :--- |
| **Supplier availability** | Assess the Enterprise **99.95% monthly availability commitment**, including eligible services, covered experiences, exclusions, and service-credit terms. [Enterprise SLA](https://www.atlassian.com/legal/sla). |
| **SLIs and SLOs** | Measure foundation routine success and completion time. Agree service-level indicators and objectives, measurement sources, windows, and response thresholds within the team’s control. |
| **Error budgets** | Define permitted unreliability against each SLO and actions on budget depletion. Use results to prioritize change and reliability work; mandatory controls remain binding. |
| **Recovery objectives and testing** | Agree recovery-time and recovery-point objectives, restore scope, and acceptable data loss. Exercise internal procedures and verify supplier capability against those requirements. |
| **Supplementary procedures** | Establish justified export, archive, or reporting procedures where native recovery is insufficient. Assign access, retention, and operating responsibility for retained copies. |
| **Observability and actionable alerting** | Monitor foundation routines, identity/integration failures, and service degradation. Define alert thresholds, accountable responders, escalation, runbooks, and supplier visibility limitations. |
| **Supplier assurance** | Obtain relevant SOC 2 Type II, ISO 27001, contractual, subprocessor, residency, support, offboarding, and applicable DORA evidence. |

**Supplier availability, internal service objectives, recovery, and preservation are assessed separately.** Certification informs assurance; backups do not replace the required retention archive.

Agree numerical objectives, measurement windows, error-budget decision rules, and response ownership before dependent use. Record measurement and supplier capability gaps with accountable treatment.

### F. Project and space standards, configuration, and evidence

**Deliver a maintained foundation baseline whose configuration and control effectiveness can be assessed without reconstructing its history.**

| Asset | Required configuration standard |
| :--- | :--- |
| **Jira projects** | Approved project types/templates, naming, issue types, workflows/statuses, fields/screens, roles, permission and notification schemes, security defaults, and permitted automation/add-on use. |
| **Confluence spaces** | Approved space types/templates, naming, page structures and content conventions, ownership/classification records, space permissions, page restrictions, sharing defaults, and review/lifecycle rules. |

- **Versioned patterns:** Publish each supported pattern with an identifier, version, owner, applicable use cases, required settings, approved dependencies, and conformance checks.
- **Controlled variation:** Support approved variants rather than one configuration for every team. Relevant architecture and control authorities approve extensions; deviations require accountable, time-bound exception treatment.
- **Verified conformance:** A template alone does not establish compliance. Asset treatment records the applied pattern/version and verifies actual settings before release and after change.

| Requirement | Required approach |
| :--- | :--- |
| **Configuration as code** | Version, review, and test supported foundation configurations. Record approved ownership and dependencies; link deployed state to its configuration version. |
| **Policy as code** | Version and test supported foundation rules against permitted, denied, invalid, and stale inputs. Retain rule versions, inputs, evaluations, and applicable approvals. |
| **Automated testing and progressive delivery** | Automate supported checks; validate changes outside production, limit initial rollout where supported, and define stop conditions, rollback or recovery, and post-change verification. |
| **Pattern lifecycle and shared components** | Assess affected assets before changing shared workflows, fields, schemes, templates, or approved dependencies. Publish supported/deprecated versions and required transition dates; verify affected assets after change. |
| **Drift detection and exceptions** | Compare actual configuration with the approved baseline using supported automation or defined manual checks. Assign deviations, treatment, owners, expiry, and verified resolution. |
| **Self-service evidence access** | Provide authorized governance, risk, and assurance functions reusable views or queries linking current requirements, configuration/rule versions, tests, findings, and exceptions. |
| **Toil reduction** | Baseline recurring checks, manual fulfilment, evidence collection, and specialist dependencies. Prioritize initial improvements and verify changes in recurring effort. |
| **Blameless postmortems** | Review significant foundation, control, or change failures. Identify contributing conditions, assign corrective actions, and verify their effectiveness. |

Unsupported automation requires a documented operating procedure, accountable ownership, and retained verification evidence.

### G. Golden paths and governed operational self-service

**Platform operators will execute the first foundation golden paths through supported tooling and procedures, within approved permissions and required approvals.** The foundation operating owner maintains each path, its tests, response procedures, and evidence.

| Golden path | Supported execution | Completion evidence |
| :--- | :--- | :--- |
| **Identity and access lifecycle** | Validate identities, approved scope, and permissions; apply onboarding, access change, or revocation; reconcile state and verify the result. | Correct allowed/denied access, lifecycle reconciliation, and access/session revocation results are recorded. |
| **Foundation configuration change** | Assess a proposed baseline or pattern change and affected assets, test it, apply a bounded rollout where supported, and verify or recover the approved state. | Reviewed baseline/pattern and rule versions, affected assets, test results, rollout scope, stop decisions, and rollback or recovery checks are traceable. |

Each path defines supported inputs, prerequisites, execution steps, operator permissions, approvals, exceptions, failure escalation, owner, and completion evidence. Operators can execute supported routines without bespoke specialist fulfilment; cases outside the path route to accountable review.

Retain controlled manual steps where automation is unsupported. Numerical service targets and implementation/tool choices are agreed through the foundation design and readiness process.

## 3. Readiness evidence

**The platform team will maintain the configuration, verification, limitation, and operating evidence required before dependent use.**

| Area | Required evidence |
| :--- | :--- |
| **Architecture and processing** | Organization, sites, subscriptions, residency settings, processing assessments, and workload exclusions match the approved target. |
| **Identity and permissions** | Allowed and denied access, provisioning, deactivation, session revocation, group handling, and exceptional identities have representative test results. |
| **Exposure and detection** | Public-access defaults, permitted and denied network origins, supported detections, alert routing, response, and audit retrieval are verified. |
| **SaaS ingress and egress** | Approved flows map to policy, owners, enforcement points, and logs. Tests cover permitted/denied browser and API access, uploads/downloads, callbacks, app transfers, and unauthorised destinations; unsupported controls and visibility have approved treatment. |
| **Add-ons and dependencies** | Registered apps, integrations, and automations have approved scope, processing, permissions, owners, lifecycle conditions, and representative functional and denied-access tests. |
| **Project and space standards** | Supported patterns and variants have approved versions, owners, settings, dependencies, and conformance checks. Representative tests cover compliant settings, unapproved variation, drift, and changes to shared components. |
| **Service and recovery** | Agreed SLIs/SLOs, error-budget rules, actionable alert routing, exercised escalation, and applicable recovery-test results distinguish internal and supplier responsibilities. |
| **Configuration and policy** | Versions of configuration as code and policy as code, automated test results, drift findings, exceptions, and verified corrections trace to the approved baseline. |
| **Golden paths and operator permissions** | Authorized operators complete supported routines; unauthorized execution, invalid/stale inputs, partial failure, staged change, stop conditions, and recovery have verified outcomes. |
| **Self-service evidence access** | Authorized oversight functions retrieve current baseline, policy, test, and exception evidence directly; unauthorized access is denied. |
| **Sustainable operation and learning** | Named owner, support scope, capacity/cost and toil baselines, feedback priorities, and a blameless postmortem process support tracked, verified improvements. |
| **Exceptions** | Unresolved gaps have accountable owners, permitted treatment, compensating controls, expiry, and affected scope. Expiry tests demonstrate required reassessment and restrictions. |

**A dependent workload enters only when its required foundation controls are demonstrated or a permissible exception is recorded.** Risk acceptance cannot waive a legal obligation.

## 4. Delivery and ongoing ownership

**Immediate delivery includes establishing the foundation and making its controls sustainable in operation.**

| Stage | Required result |
| :--- | :--- |
| **Confirm requirements** | Consolidate workload needs, supported project/space types, identity/dependency/data-flow inventories, ingress/egress policy, processing obligations, licensing, capacity, and service and recovery requirements. |
| **Design and configure** | Publish approved pattern versions and dependencies. Establish initial golden paths, policy and configuration as code where supported, service objectives, error-budget rules, and operating responsibilities. |
| **Verify** | Produce section 3 evidence. Remediate failed controls or establish permissible approved treatment before dependent use. |
| **Establish operation** | Enable governed operational self-service and evidence access. Assign path, configuration, monitoring, exception, and recovery owners within agreed capacity and support boundaries. |
| **Maintain and improve** | Revalidate changes, pattern conformance, dependency approvals, and drift corrections. Use feedback, SLO/error-budget results, toil measures, and blameless postmortem actions to prioritize and verify improvements. |

Resolve SaaS policy mapping, permitted flows, residency, service ownership, recovery objectives, and uncovered controls before dependent activities. Do not approve a required flow solely because network connectivity succeeds.

**Later expansion:** Strategy section 4.3 broadens the capability catalogue, golden paths, operational self-service, automated test coverage, SLO/error-budget management, and recovery exercises from this verified baseline.

# Atlassian Cloud Strategy

The strategy takes a **governance, risk and compliance approach to building Atlassian Cloud**. Enterprise objectives, applicable obligations, and approved policies determine what is built, how it operates, and the evidence required to demonstrate control effectiveness.

**Immediate delivery is Cloud Foundation and Asset Ownership and Treatment.** These establish shared guardrails and apply approved handling to projects and spaces; platform configuration and data governance are developed together.

Review draft | 20 October 2026.

## Immediate scope and outcomes

**Scope:** Establish and verify controls, accountable decisions, standard project/space patterns, and operating practices for Jira, Jira Service Management, Confluence, and approved add-ons, Marketplace apps, integrations, and automations. Configuration is an implementation mechanism, not the measure of completion.

- **Verified control coverage:** Identity, permissions, protection, processing boundaries, integrations, and recovery meet applicable requirements or have explicit gap treatment.
- **Standardised projects and spaces:** Assets use approved, versioned configuration patterns; business-specific variation follows approved variants or controlled exceptions.
- **Accountable information:** Each project or space has validated ownership, an active ServiceNow Business Application association, classification, intended audience, and handling obligations.
- **Enforced governance:** Approved decisions produce verified permissions, restrictions, and registration; missing information or failed enforcement blocks normal release.
- **Controlled operation:** Named owners, support boundaries, runbooks, monitoring, recovery, and service measures sustain controls through routine operation and change.
- **Reusable evidence:** Authorised functions can assess control design, operation, findings, and risk treatment using current evidence rather than repeated reconstruction.

**Outside immediate delivery:** Migration execution, Rovo rollout, sandbox-copy services, and an archive solution. The initial data model must record relevant use and preservation decisions without implying those services are available.

## Requirements drive controls and asset treatment

| Immediate workstream | Role |
| :--- | :--- |
| **[Cloud Foundation](01-cloud_foundation.md)** | Translate enterprise requirements into shared guardrails and approved project/space configuration patterns. Establish ownership and evidence for their continued operation. |
| **[Asset Ownership and Treatment](02-asset_ownership_treatment.md)** | Validate asset facts, obtain accountable decisions, select the applicable standard, enforce handling, maintain records, and reassess changes. |

The [52-control requirements register](control-requirements-register.md) defines the selected CCM requirements, provisional financial-services parameters, acceptance evidence and failure treatment for these workstreams. Its values are working assumptions for design and synthetic validation, not approved firm policy or verified operating controls.

The [automation coverage assessment](automation-coverage-assessment.md) maps the register to documented Atlassian interfaces, firm-side automation and supplier assurance, with gaps and a proposed validation sequence. It is documentation-based; tenant capabilities and control effectiveness remain untested.

The [Platform Lifecycle](LIFECYCLE.md) review draft defines the platform and asset lifecycles in five phases: Initiation, Acquisition, Implementation, Operations, Disposal. Each state lists the observable checks that make it hold; each transition lists its trigger, steps and evidence.

- **Policy determines treatment:** Validated asset facts and applicable rules establish required handling, subject to accountable approvals; requesters do not select their own permissions.
- **Enforcement makes decisions effective:** Apply and verify approved controls before release. A classification label or completed approval is not proof of access restriction.
- **Gaps require accountable treatment:** Remediate or restrict unsupported scope, or obtain an authorised exception with compensating controls and expiry. An exception cannot waive legal obligations.
- **Change preserves the control position:** Reassess material changes, detect drift, and retain decision and enforcement history; initial approval is not permanent permission.

## Standardised projects and spaces

| Asset | Required standard |
| :--- | :--- |
| **Jira projects** | Approved project types/templates, naming, issue types, workflows/statuses, fields/screens, roles, permission and notification schemes, security defaults, and permitted automation/add-on use. |
| **Confluence spaces** | Approved space types/templates, naming, page structures and content conventions, ownership/classification records, space permissions, page restrictions, sharing defaults, and review/lifecycle rules. |

- **Controlled variation:** Standards support approved use cases, not one configuration for every team. Extensions require review through the relevant architecture and control authorities.
- **Verified conformance:** Record the applied pattern/version and exceptions; check required settings before release and after change. A template alone does not establish compliance.

## Capabilities and operating approach

Use the [CNCF Platform Engineering Maturity Model](https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/) to guide the **Scalable** target and selected **Optimizing** practices. Maturity labels guide engineering improvement; they do not establish control effectiveness or readiness of the new Cloud platform.

| Capability | Required approach |
| :--- | :--- |
| **Platform product management** | Name owners, supported operations, cost/capacity boundaries, and feedback routes. Prioritise enterprise objectives, control requirements, and risk treatment within agreed delivery capacity. |
| **Governance and control integration** | Express suitable approved policies as versioned, tested code. Retain evaluations, detect drift, and track exceptions through remediation or expiry. |
| **Reusable platform engineering** | Publish versioned project/space patterns and **golden paths**: supported, tested operating routines. Use configuration as code, automated tests, progressive delivery, and governed operator self-service where supported. |
| **Reliable operations and safe change** | Define service-level indicators (SLIs), objectives (SLOs), and error budgets against service requirements. Use observability, actionable alerts, and recovery tests to verify continued operation. |
| **Evidence, measurement, and learning** | Provide direct, authorised evidence access; measure recurring manual work (operational toil); use blameless postmortems and verify corrective actions. |

Apply these practices in both immediate workstreams, including their first operating paths and evidence access. Engineering makes approved controls repeatable; it does not replace business or control-function decisions.

## Accountability

Enterprise functions determine applicable requirements and retain their mandates. Platform teams implement approved treatment, demonstrate effectiveness, and remediate the weaknesses they own.

| Accountable function | Responsibility |
| :--- | :--- |
| **Platform and service management** | Maintain approved project/space patterns, engineering, operations, supported automation, and operator self-service within capacity and supplier boundaries. |
| **Business application and asset owners** | Own business facts, purpose, and business decisions; the platform provides validated records and enforcement. |
| **Security governance** | Set security requirements and retain oversight; the platform implements and evaluates applicable controls. |
| **Data and information governance** | Determine classification, access, and lifecycle requirements; the platform applies approved handling and records preservation obligations. |
| **Architecture governance** | Retain enterprise standards and governance; the platform maintains aligned architecture, reusable patterns, and integration boundaries. |
| **Service governance and resilience** | Retain service-management and resilience mandates; the platform supplies objectives, observability, and recovery evidence; suppliers retain contracted responsibilities. |
| **Risk and compliance** | Monitor and challenge risk; the platform supplies assessments, exceptions, and evidence, and remediates owned weaknesses. |
| **Executive sponsorship and oversight** | Set direction and decisions within authority; review commitments, risk, performance, cost, and capacity. |
| **Independent assurance** | Retain independent judgement over control design and effectiveness, using authorised access to current evidence. |

## Immediate acceptance and review

Acceptance must show that applicable requirements produce operating controls, accountable decisions, and current evidence. A configured site or completed deployment is insufficient.

- **Requirement traceability:** Link applicable requirements and rules to configured controls, verification results, accountable owners, and any residual-risk treatment.
- **Control effectiveness:** Demonstrate permitted/denied access, identity lifecycle, protection and audit coverage, integration failure handling, and achievable recovery; record limitations and approved treatments.
- **Data-governance effectiveness:** Demonstrate validated inputs, required approvals, applied project/space standards, traceable decisions, enforced permissions, complete registration, reassessment, and recovery from partial failure.
- **Operational readiness:** Verify ownership, runbooks, alert response, evidence access, and supported routines. Agree service-level targets and response thresholds from the initial baseline.
- **Continuing review:** Track control coverage, project/space conformance, drift, expiring exceptions, workflow performance, recovery tests, toil, and capacity; reviews must produce verified resolution.

The [platform strategy](00-platform_strategy.md) records the strategic reasoning, governing choices, actions, and dependencies. Immediate readiness depends on demonstrated control effectiveness and approved treatment of gaps, not installation completion.

The [previous strategic overview](../README.md) is retained for reference; this README is the current entry point.

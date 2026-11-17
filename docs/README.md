# Atlassian Cloud Strategy -DRAFT

- The strategy takes a **governance, risk and compliance** approach to building Atlassian Cloud.
- **Enterprise objectives drive the work:** platform adoption and committed roadmaps, stronger risk and controls, reliable and efficient service delivery, responsible AI adoption, and improved change outcomes.

## Strategic Direction

The five choices below capture the agreed direction.

### 1. Target Outcomes

**Build and sustain an Atlassian Cloud platform that the bank can adopt and evolve with confidence: dependable in operation, efficient to run, and governed through controls embedded in its architecture and lifecycle. Enable the platform team to deliver committed roadmaps, demonstrate effective risk management, and support secure, compliant, resilient service delivery and change.**

| Target outcome | Success criteria |
| :--- | :--- |
| **Accountable, sustainable operation** | Active assets have validated ownership, CMDB application association, and classification. Operational toil reduces, and operational and change commitments remain within agreed team capacity. |
| **Effective enterprise controls** | Applicable controls have current verification evidence. Configuration drift, control gaps, and exceptions have accountable owners, agreed treatment, and tracked resolution or expiry dates. |
| **Reliable service and recovery** | Service performance meets agreed service-level objectives. Recovery tests demonstrate achievement of agreed recovery objectives. |
| **Delivery against enterprise commitments** | Agreed roadmap commitments are delivered, with evidence of platform adoption, risk reduction, and operational-efficiency improvements. |
| **Independent assurance** | Platform control coverage and asset treatment can be independently assessed using current, reusable evidence, with less manual collection and reconstruction. |

Together, these outcomes enable end-user value to be delivered securely, compliantly, and efficiently.

### 2. Scope and Accountability

**We will focus on the governance and operation of the bank's enterprise Atlassian estate, establishing the controls, operating capabilities, and evidence needed by those accountable for its use, management, oversight, and assurance.** This covers Jira, Jira Service Management, Confluence, and approved dependencies across production and supporting environments—from migration and onboarding through operation, change, reuse, retention, and retirement.

| Stakeholder group | Value provided | Platform contribution and accountability |
| :--- | :--- | :--- |
| **Platform and service management** | **Reliable operations**, reduced toil, and capacity for committed roadmaps. | Own platform engineering and operations, including supported automation and governed operational self-service, within agreed capacity and supplier boundaries. |
| **Business application and asset ownership** | **Clear ownership and approved treatment**, with less repeated information gathering. | Provide asset records, validation, and permission enforcement; business owners retain accountability for asset facts, purpose, and business decisions. |
| **Security governance** | **Verified security controls**, current policy results, and visible exceptions. | Implement and evaluate applicable controls, using policy as code where supported; security authorities retain requirements and oversight mandates. |
| **Data and information governance** | **Accountable information handling** and traceable access, reuse, retention, and disposal decisions. | Implement approved handling and provide direct access to treatment evidence; enterprise functions determine applicable information-governance requirements. |
| **Architecture governance** | **Enterprise-aligned architecture**, reusable patterns, and reduced fragmentation and technical debt. | Maintain platform architecture, golden paths, and integration boundaries within enterprise standards and architecture governance. |
| **Service governance and resilience** | **Measurable service performance**, actionable operational information, and demonstrated recovery. | Establish observability, service objectives, and tested recovery; enterprise functions retain service-management and resilience mandates, and suppliers retain contracted responsibilities. |
| **Risk and compliance** | **Better-supported risk assessments**, visible residual risk, and traceable exceptions and remediation. | Provide direct access to assessments and control evidence, and remediate owned weaknesses; risk and compliance functions retain monitoring and challenge responsibilities. |
| **Executive sponsorship and oversight** | **Evidence of progress against commitments**, with visibility of risk, performance, cost, and capacity. | Report platform outcomes, constraints, and dependencies; sponsors and governing bodies retain direction and decisions within their authority. |
| **Independent assurance** | **Current, reusable control evidence**, with less manual collection and reconstruction. | Provide self-service access to policy results, control coverage, and supporting evidence; assurance functions retain independent judgment over control design and effectiveness. |

**Initial focus:** [Cloud Foundation](strategy/01-cloud_foundation.md) and [Asset Ownership and Treatment](strategy/02-asset_ownership_treatment.md) establish the shared platform baseline and accountable asset decisions required for subsequent delivery.

These deliver the first **golden paths**, governed operational self-service for platform teams, and self-service evidence access for governance, risk, and assurance functions. Later delivery extends their coverage and automation.

### 3. Target Maturity and Strategic Approach

**We will use the creation of Atlassian Cloud to establish a Scalable¹ enterprise platform, managed as a product and designed around stakeholder value. Governance, security, resilience, and efficient operation will be integral to its capabilities and lifecycle. We will selectively adopt Optimizing¹ characteristics where integration, collaboration, and continuous improvement can deliver additional value sustainably.**<br>
¹ *We are at Operationalized and aim to reach Scalable in the [CNCF Platform Engineering Maturity Model](https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/).*

| Strategic choice | Approach | Why it creates value |
| :--- | :--- | :--- |
| **Product-managed platform** | Prioritize a shared roadmap against stakeholder needs and enterprise commitments. | Coordinates demand and dependencies, reducing fragmented investment and competing commitments. |
| **Reusable, governed patterns** | Embed enterprise specialist requirements in **golden paths**—supported, tested patterns for platform configuration and operation. | Reduces repeated design, policy interpretation, and bespoke engineering. |
| **Policy and configuration as code** | Manage applicable policy rules and supported configurations as **versioned, tested code**. | Makes change repeatable and produces traceable control evaluation results. |
| **Governed operational self-service** | Enable platform teams to execute approved operations through supported automation within defined permissions and controls. | Reduces manual fulfilment and dependence on individual specialists as the estate grows. |
| **Self-service evidence access** | Give governance, risk, and assurance functions direct access to current policy results, control coverage, exceptions, and evidence. | Reduces bespoke reporting, evidence collection, and reconstruction. |
| **Engineering-led reliability and improvement** | Use measurable service objectives, incident learning, and recurring manual work to prioritize engineering improvements. | Targets reliability weaknesses and operational toil, preserving capacity for committed delivery. |
| **Selective optimization** | Adopt Optimizing characteristics where stakeholder benefit and operating capacity justify them. | Captures worthwhile integration and collaboration benefits while keeping operating demands sustainable. |

### 4. Required Platform Capabilities

**We will apply five capabilities first through [Cloud Foundation](strategy/01-cloud_foundation.md) and [Asset Ownership and Treatment](strategy/02-asset_ownership_treatment.md), then expand them across the estate. Supporting deliverables and acceptance checks define our platform-specific baseline for Scalable maturity.**

| Capability | Required practices |
| :--- | :--- |
| **Platform product management** | Maintain a prioritized roadmap, supported capability catalogue, and lifecycle decisions informed by stakeholder feedback, adoption, cost, and team capacity. |
| **Governance and control integration** | Author, version, and test **policy as code**. Evaluate control coverage, detect configuration drift, and track exceptions through expiry or remediation. |
| **Reusable platform engineering** | Maintain **golden paths**, configuration as code, and governed operational self-service. Use **automated testing and progressive delivery** for supported changes. |
| **Reliable operations and safe change** | Define **service-level indicators and objectives (SLIs/SLOs)** and error budgets. Establish observability, actionable alerts, and recovery tested against agreed objectives. |
| **Evidence, measurement, and learning** | Provide **self-service evidence access**, measure operational toil, and use **blameless postmortems** to identify improvements and verify corrective actions. |

Detailed deliverables and acceptance checks will be defined in the supporting problem statements.

### 5. Management Information and Assurance

**We will use platform measures and evidence to guide decisions, verify capability effectiveness, and track improvement against enterprise commitments and the Scalable maturity target. Regular and event-driven reviews will produce prioritized actions, tracked through to verified resolution.**

| Capability | Information to collect and review | Decisions it supports |
| :--- | :--- | :--- |
| **Evidence, measurement, and learning** | Evidence completeness and currency, unresolved findings, blameless postmortem actions, capability acceptance results, and maturity gaps. | Resolve evidence gaps, verify corrective actions, and prioritize maturity improvements. |
| **Governance and control integration** | Policy evaluation results, control coverage, configuration drift, and exceptions approaching expiry. | Remediate deviations, reassess exceptions, and prioritize control improvements. |
| **Reliable operations and safe change** | Initial and expanded SLO performance, error-budget consumption, recovery tests, supported-path use, incidents, change failures, toil, and available capacity. | Adjust change pace, address reliability weaknesses, and target automation to release capacity. |

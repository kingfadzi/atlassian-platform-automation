# Atlassian Platform Automation

Declare intended state, evaluate policy, apply authorised changes,
verify the outcome and retain evidence.

## Structure

| Area | Owns | Extension point |
|---|---|---|
| policy/ | Control mappings, parameter profiles and executable policy | Add a profile or engine-native rule with tests. |
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
- Run offline input-validation tests.

These checks do not evaluate business authority, implement policy,
connect to Atlassian or demonstrate control effectiveness.

## Run

Requires Python 3.11+ and Make.

    make bootstrap
    make check

Optional verification against a local strategy checkout:

    make check-sources STRATEGY_REPO=/path/to/atlassian-cloud

Dependency installation requires package-index access.
Validation and tests subsequently run offline.

Python is used for these checks; the execution runtime, policy engine
and CI platform remain undecided.

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

There are no live operations or deployment commands in this initial set.

import json
from pathlib import Path

import yaml

from govern import status

ROOT = Path(__file__).resolve().parents[2]
PHASES = status.load_phases(ROOT / "policy" / "phases.yaml")
CONTROLS = status.load_controls([ROOT / "policy" / "foundation.yaml", ROOT / "policy" / "conformance.yaml"])
STEPS = status.load_steps(ROOT / "policy" / "unchecked.yaml")


def out(**kwargs):
    """One stage's `terraform output -json`."""
    return {k: {"value": v} for k, v in kwargs.items()}


def stages(**kwargs):
    """render() takes a map of stage name to that stage's outputs."""
    return {name: out(**vals) for name, vals in kwargs.items()}


def test_every_control_and_step_belongs_to_a_declared_phase():
    declared = {p["id"] for p in PHASES}
    assert {c["phase"] for c in CONTROLS} <= declared
    assert {s["phase"] for s in STEPS} <= declared


def test_no_control_and_no_step_share_an_id():
    """A step is not a control; the same id in both would make one of them invisible."""
    assert not ({c["id"] for c in CONTROLS} & {s["id"] for s in STEPS})


def test_every_control_reads_the_tenant():
    """The catalogue is only for comparisons against the running system. Anything the engine
    cannot read belongs in policy/unchecked.yaml."""
    assert [c["id"] for c in CONTROLS if not c.get("fact") and "action" not in c] == []


def test_no_outputs_renders_a_checklist_and_no_readiness():
    text = status.render(PHASES, CONTROLS, {})
    assert "readiness: unknown, no phase has been applied" in text
    judged = {c["phase"] for c in CONTROLS}
    assert text.count("not run") == len(judged)
    assert "[ ] anonymous_jira_closed  (console)" in text


def test_verdicts_name_who_owes_an_unsatisfied_control():
    verdicts = {c["id"]: "pass" for c in CONTROLS}
    verdicts["anonymous_jira_closed"] = "fail"          # provision: runbook
    verdicts["roles_match_standards"] = "fail"          # provision: engine
    text = status.render(PHASES, CONTROLS, stages(foundation=dict(controls=verdicts, ready={"jira": False})))
    assert "fail               anonymous_jira_closed  owed by console" in text
    assert "fail               roles_match_standards  owed by engine" in text
    assert "jira=blocked" in text


def test_a_phase_whose_controls_all_pass_says_so():
    verdicts = {c["id"]: "pass" for c in CONTROLS}
    text = status.render(PHASES, CONTROLS, stages(foundation=dict(controls=verdicts)))
    assert "4 controls, all satisfied" in text


def test_not_applicable_is_not_reported_as_satisfied():
    mine = [c for c in CONTROLS if c["phase"] == "standards"]
    verdicts = {c["id"]: "pass" for c in CONTROLS} | {c["id"]: "not_applicable" for c in mine}
    text = status.render(PHASES, CONTROLS, stages(foundation=dict(controls=verdicts)))
    assert f"{len(mine)} controls, none applicable here" in text


def test_mandatory_failure_blocks_the_phase_and_a_reported_one_does_not():
    mandatory = next(c for c in CONTROLS if c.get("mandatory") and c["phase"] == "guardrails")
    reported = next(c for c in CONTROLS if not c.get("mandatory") and c["phase"] == "guardrails")
    mine = [c for c in CONTROLS if c["phase"] == "guardrails"]
    base = {c["id"]: "pass" for c in mine}
    assert status.phase_state(mine, {**base, mandatory["id"]: "fail"}) == "blocked"
    assert status.phase_state(mine, {**base, reported["id"]: "fail"}) == "findings"
    assert status.phase_state(mine, base) == "ok"


def test_estate_uses_the_instance_summary_not_per_control_verdicts():
    summary = {"projects": 7, "spaces": 3, "non_conforming": 8, "unstamped": 3}
    text = status.render(PHASES, CONTROLS,
                         {"estate": out(summary=summary, findings=["a", "b"])})
    assert "7 projects, 3 spaces, 8 non-conforming, 3 unstamped" in text
    assert "2 findings across the estate" in text


def test_estate_findings_are_not_mixed_with_foundation_findings():
    text = status.render(PHASES, CONTROLS, {
        "foundation": out(controls={}, findings=["x", "y", "z"]),
        "estate": out(summary={"non_conforming": 1}, findings=["only-one"]),
    })
    assert "1 findings across the estate" in text


def test_instance_controls_are_owed_by_the_engine():
    instance = next(c for c in CONTROLS if "action" in c)
    assert status.owed_by(instance) == "engine"
    assert status.owed_by({"provision": "runbook"}) == "console"
    assert status.owed_by({"provision": "engine"}) == "engine"
    assert status.owed_by({}) == "unspecified"


def test_every_console_control_says_where_and_what():
    """The view renders these, so a missing one would print a blank instruction."""
    bare = [c["id"] for c in CONTROLS
            if c.get("provision") == "runbook" and not (c.get("where") and c.get("todo"))]
    assert bare == []


def test_an_outstanding_console_control_prints_its_instructions():
    verdicts = {c["id"]: "pass" for c in CONTROLS}
    verdicts["account_global_permissions"] = "fail"
    text = status.render(PHASES, CONTROLS, stages(foundation=dict(controls=verdicts)))
    assert "where: Jira > Settings > System > Global permissions" in text
    assert "todo:  Remove the reported account" in text


def test_only_manually_confirmed_controls_name_the_record_file():
    observed = next(c for c in CONTROLS
                    if c.get("provision") == "runbook" and c.get("fact") != "manual_confirmation")
    verdicts = {c["id"]: "pass" for c in CONTROLS}
    verdicts[observed["id"]] = "fail"
    text = status.render(PHASES, CONTROLS, stages(foundation=dict(controls=verdicts)))
    assert observed["id"] in text
    assert "record it in" not in text


def test_unchecked_steps_are_shown_with_their_reason():
    """Surfaced so the work does not look like a gap, and marked so it cannot read as a verdict."""
    text = status.render(PHASES, CONTROLS, {}, steps=STEPS)
    step = next(s for s in STEPS if s["phase"] == "guardrails")
    assert "not checked by the engine:" in text
    assert f"( ) {step['id']}" in text
    assert f"why:   {step['why']}" in text
    assert f"{len(CONTROLS)} controls read from the tenant" in text
    assert f"{len(STEPS)} steps the engine cannot check" in text


def test_a_step_is_never_given_a_verdict():
    verdicts = {c["id"]: "pass" for c in CONTROLS} | {s["id"]: "fail" for s in STEPS}
    text = status.render(PHASES, CONTROLS, stages(foundation=dict(controls=verdicts)), steps=STEPS)
    for s in STEPS:
        assert f"fail               {s['id']}" not in text


def test_a_phase_with_nothing_to_judge_says_so_rather_than_not_run():
    judged = {c["phase"] for c in CONTROLS}
    empty = [p for p in PHASES if p["id"] not in judged]
    text = status.render(PHASES, CONTROLS, stages(foundation=dict(controls={})), steps=STEPS)
    for p in empty:
        assert "nothing the engine judges here" in text

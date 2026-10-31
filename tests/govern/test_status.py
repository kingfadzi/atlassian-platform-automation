import json
from pathlib import Path

import yaml

from govern import status

ROOT = Path(__file__).resolve().parents[2]
PHASES = status.load_phases(ROOT / "policy" / "phases.yaml")
CONTROLS = status.load_controls([ROOT / "policy" / "foundation.yaml", ROOT / "policy" / "conformance.yaml"])


def out(**kwargs):
    """One stage's `terraform output -json`."""
    return {k: {"value": v} for k, v in kwargs.items()}


def stages(**kwargs):
    """render() takes a map of stage name to that stage's outputs."""
    return {name: out(**vals) for name, vals in kwargs.items()}


def test_every_control_belongs_to_a_declared_phase():
    declared = {p["id"] for p in PHASES}
    assert {c["phase"] for c in CONTROLS} <= declared


def test_no_outputs_renders_a_checklist_and_no_readiness():
    text = status.render(PHASES, CONTROLS, {})
    assert "readiness: unknown, no phase has been applied" in text
    assert text.count("not run") == len(PHASES)
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
    verdicts = {c["id"]: "pass" for c in CONTROLS}
    verdicts["evidence_retrieval"] = "not_applicable"   # the only readiness control
    text = status.render(PHASES, CONTROLS, stages(foundation=dict(controls=verdicts)))
    assert "1 control, none applicable here" in text


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
    verdicts["native_space_creation_closed"] = "fail"
    text = status.render(PHASES, CONTROLS, stages(foundation=dict(controls=verdicts)),
                         records="records/lab")
    assert "where: Confluence > Settings > Global permissions" in text
    assert "todo:  Grant Create space" in text
    assert "then:  record it in records/lab/attestations.yaml" in text


def test_only_manually_confirmed_controls_name_the_record_file():
    observed = next(c for c in CONTROLS
                    if c.get("provision") == "runbook" and c.get("fact") != "manual_confirmation")
    verdicts = {c["id"]: "pass" for c in CONTROLS}
    verdicts[observed["id"]] = "fail"
    text = status.render(PHASES, CONTROLS, stages(foundation=dict(controls=verdicts)))
    assert observed["id"] in text
    assert "record it in" not in text


def test_the_records_path_follows_the_environment():
    verdicts = {c["id"]: "pass" for c in CONTROLS}
    verdicts["native_project_creation_closed"] = "fail"
    text = status.render(PHASES, CONTROLS, stages(foundation=dict(controls=verdicts)),
                         records="records/prod")
    assert "records/prod/attestations.yaml" in text

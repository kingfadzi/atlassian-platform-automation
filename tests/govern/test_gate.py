import json
from datetime import date
from pathlib import Path

import yaml

from govern import cli, currency, gate, provenance

ROOT = Path(__file__).resolve().parents[2]
RULES = yaml.safe_load((ROOT / "policy" / "gate.yaml").read_text())
FIXTURE = json.loads((ROOT / "tests" / "govern" / "fixtures" / "plan_drift_reported.json").read_text())


def change(address, actions, importing=False):
    return {"address": address, "change": {"actions": actions, "importing": {"id": "x"} if importing else None}}


def test_recorded_drift_plan_blocks_on_failed_check_only():
    verdict = gate.evaluate(FIXTURE, RULES)
    assert not verdict.ok
    assert all("check" in b for b in verdict.blocked)
    assert verdict.creates == [] and verdict.reported == []


def test_updates_and_deletes_block():
    plan = {"resource_changes": [change("a", ["update"]), change("b", ["delete"]), change("c", ["delete", "create"])]}
    verdict = gate.evaluate(plan, RULES)
    assert len(verdict.blocked) == 3


def test_create_allowed_import_needs_authority():
    plan = {"resource_changes": [change("new", ["create"]), change("old", ["no-op"], importing=True)]}
    assert gate.evaluate(plan, RULES).blocked == ["old: import without an adoption authority record"]
    assert gate.evaluate(plan, RULES, {"adoptions": {"old": "AUTH-ADOPT-01"}}).ok


def test_vanished_object_blocks_recreate():
    plan = {"resource_drift": [{"address": "g", "change": {"actions": ["delete"], "before": {}, "after": None}}]}
    assert "investigate" in gate.evaluate(plan, RULES).blocked[0]


def test_currency_windows():
    records = {"attestations": {"records": [{"id": "custody", "kind": "attestation", "recorded": date(2026, 1, 1)}]}}
    assert currency.currency_findings(records, RULES["windows_days"], today=date(2026, 10, 23))
    assert not currency.currency_findings(records, RULES["windows_days"], today=date(2026, 1, 20))


def test_foundation_fixture_blocks_mandatory_and_reports_findings():
    plan = json.loads((ROOT / "tests" / "govern" / "fixtures" / "plan_foundation_blocked.json").read_text())
    verdict = gate.evaluate(plan, RULES)
    assert any("mandatory_controls" in b and "anonymous_jira_closed" in b for b in verdict.blocked)
    assert any("report_controls" in r for r in verdict.reported)
    assert not any("report_controls" in b for b in verdict.blocked)


def test_policy_digests_cover_files_and_standards_directory(tmp_path):
    digests = provenance.policy_digests(ROOT, RULES["policy_files"])
    assert {"policy/gate.yaml", "policy/foundation.yaml", "policy/intent_rules.yaml",
            "policy/standards/restricted-collab-v1.yaml"} <= set(digests)
    changed = tmp_path / "policy"
    changed.mkdir()
    (changed / "foundation.yaml").write_text((ROOT / "policy" / "foundation.yaml").read_text() + "# one more byte\n")
    assert provenance.policy_digests(tmp_path, ["policy/foundation.yaml"])["policy/foundation.yaml"] != digests["policy/foundation.yaml"]


def test_plan_policy_versions_read_from_outputs():
    plan = {"planned_values": {"outputs": {"policy_version": {"value": "2026-10"}, "standard": {"value": {"id": "restricted-collab-v1"}}}}}
    assert provenance.plan_policy_versions(plan) == {"foundation_catalogue": "2026-10", "standard": "restricted-collab-v1"}


def test_gate_creates_the_ledger_directory(tmp_path):
    ledger = tmp_path / "ledger" / "lab.jsonl"
    rc = cli.main(["gate", "--plan-json",
                   str(ROOT / "tests" / "govern" / "fixtures" / "plan_foundation_blocked.json"),
                   "--stage", "foundation", "--records", str(ROOT / "records" / "lab"),
                   "--ledger", str(ledger)])
    assert rc == 3                                  # the fixture blocks; the write must still happen
    assert json.loads(ledger.read_text().splitlines()[-1])["stage"] == "foundation"

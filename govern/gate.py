"""Classify a Terraform plan (terraform show -json) against policy/gate.yaml."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Verdict:
    blocked: list[str] = field(default_factory=list)
    reported: list[str] = field(default_factory=list)
    creates: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.blocked


def evaluate(plan: dict, rules: dict, authority: dict | None = None) -> Verdict:
    """Return the gate verdict for one plan. Pure function; no I/O."""
    verdict = Verdict()
    _classify_actions(plan, rules["actions"], authority or {}, verdict)
    _classify_drift(plan, rules["drift"], verdict)
    _classify_checks(plan, rules["checks"], verdict)
    return verdict


def _classify_actions(plan: dict, rules: dict, authority: dict, verdict: Verdict) -> None:
    for change in plan.get("resource_changes", []):
        address, actions = change["address"], change["change"]["actions"]
        label = "replace" if actions in (["delete", "create"], ["create", "delete"]) else actions[0]
        if change["change"].get("importing"):
            if rules["import_requires_authority"] and address not in authority.get("adoptions", {}):
                verdict.blocked.append(f"{address}: import without an adoption authority record")
            else:
                verdict.reported.append(f"{address}: import under {authority['adoptions'][address]}")
            continue
        if label in rules["blocked"]:
            verdict.blocked.append(f"{address}: planned action '{label}' is not permitted")
        elif label == "create":
            verdict.creates.append(address)
        elif label not in rules["allowed"]:
            verdict.blocked.append(f"{address}: unknown action '{label}'")


def _classify_drift(plan: dict, rules: dict, verdict: Verdict) -> None:
    for drift in plan.get("resource_drift", []):
        address, change = drift["address"], drift["change"]
        if "delete" in change["actions"]:
            if rules["delete_blocks"]:
                verdict.blocked.append(f"{address}: no longer readable in the tenant; investigate before any recreate")
            continue
        before, after = change.get("before") or {}, change.get("after") or {}
        changed = sorted(k for k in after if before.get(k) != after.get(k))
        if set(changed) - set(rules["report_fields"]):
            verdict.reported.append(f"{address}: refreshed fields {changed}")


def _classify_checks(plan: dict, rules: dict, verdict: Verdict) -> None:
    for check in plan.get("checks", []):
        if check["status"] != "fail":
            continue
        problems = [p["message"] for inst in check.get("instances", []) for p in inst.get("problems", [])]
        line = f"{check['address']['to_display']}: " + " | ".join(problems)
        (verdict.blocked if rules["failures_block"] else verdict.reported).append(line)

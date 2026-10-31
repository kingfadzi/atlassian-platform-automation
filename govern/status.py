"""The stand-up sequence and where the platform stands in it.

Reads the phase order from policy, the controls from the catalogues, and each stage's outputs
where a stage has run. A phase with no outputs is shown as a checklist, so the view works from a
clean clone with no state and no credentials.
"""

from __future__ import annotations

from pathlib import Path

import yaml

OK = ("pass", "manually_confirmed", "not_applicable")
# Who has to act when a control is unsatisfied. The catalogue's `provision` says who creates the
# thing; an unsatisfied control is owed by that same party.
OWNER = {"engine": "engine", "runbook": "console", "external": "supplier or console"}


def load_phases(path: Path) -> list[dict]:
    return yaml.safe_load(path.read_text())["phases"]


def load_controls(paths: list[Path]) -> list[dict]:
    out = []
    for p in paths:
        out.extend(yaml.safe_load(p.read_text())["controls"])
    return out


def phase_state(controls: list[dict], verdicts: dict) -> str:
    """blocked if a mandatory control is unsatisfied, findings if only reported ones are, else ok."""
    if not verdicts:
        return "not run"
    states = {c["id"]: verdicts.get(c["id"]) for c in controls}
    if any(s not in OK for c in controls if c.get("mandatory") for s in [states[c["id"]]]):
        return "blocked"
    if any(s not in OK for s in states.values() if s is not None):
        return "findings"
    return "ok"


def owed_by(control: dict) -> str:
    """Who has to act. Instance controls carry a rung instead of `provision`; the engine judges
    those and, where the rung is enabled, acts on them."""
    if "provision" in control:
        return OWNER.get(control["provision"], "unspecified")
    return "engine" if "action" in control else "unspecified"


def outstanding(controls: list[dict], verdicts: dict) -> list[tuple[str, str, str]]:
    """(control id, verdict, who owes it) for every control not yet satisfied."""
    rows = []
    for c in controls:
        v = verdicts.get(c["id"]) if verdicts else None
        if v in OK:
            continue
        rows.append((c["id"], v or "unknown", owed_by(c)))
    return rows


def instance_scoped(controls: list[dict]) -> bool:
    """Instance controls are judged once per project or space, so a per-control verdict for the
    whole platform does not exist; the estate summary stands in for it."""
    return any("action" in c for c in controls)


def render(phases: list[dict], controls: list[dict], outputs: dict, only: str | None = None,
           records: str = "records/lab") -> str:
    """outputs maps a stage name to its terraform outputs; a phase with none has not run.
    `only` narrows the view to one phase."""
    if only:
        phases = [p for p in phases if p["id"] == only]
        if not phases:
            raise ValueError(f"no such phase: {only}")
    verdicts, ready, summary, estate_findings = {}, {}, None, []
    for out in outputs.values():
        verdicts.update(out.get("controls", {}).get("value", {}) or {})
        ready.update(out.get("ready", {}).get("value", {}) or {})
        if "summary" in out:                       # the estate stage; its findings are per instance
            summary = out["summary"].get("value")
            estate_findings = out.get("findings", {}).get("value") or []

    lines = []
    for p in phases:
        mine = [c for c in controls if c.get("phase") == p["id"]]
        if instance_scoped(mine):
            if summary is None:
                lines += _phase_header(p, "not run", mine, None, records)
                continue
            state = "findings" if summary.get("non_conforming") else "ok"
            lines += _phase_header(p, state, mine, None, records)
            lines.append(f"{'':<21} {summary.get('projects', 0)} projects, {summary.get('spaces', 0)} spaces, "
                         f"{summary.get('non_conforming', 0)} non-conforming, {summary.get('unstamped', 0)} unstamped")
            lines.append(f"{'':<21} {len(estate_findings)} findings across the estate")
            lines.append("")
            continue

        seen = {k: v for k, v in verdicts.items() if k in {c["id"] for c in mine}}
        state = phase_state(mine, seen)
        lines += _phase_header(p, state, mine, seen, records)
        lines.append("")

    lines.append("readiness: " + (", ".join(f"{k}={'ready' if v else 'blocked'}" for k, v in sorted(ready.items()))
                                  if ready else "unknown, no phase has been applied"))
    return "\n".join(lines)


def _phase_header(p: dict, state: str, mine: list[dict], seen: dict | None,
                  records: str = "records/lab") -> list[str]:
    by_id = {c['id']: c for c in mine}
    lines = [f"{p['id']:<11} {state:<9} {p['title']}",
             f"{'':<21} covers: {p['covers']}"]
    if state == "not run":
        lines.append(f"{'':<21} {_count(len(mine))}, none evaluated yet. acts: {p['acts']}")
        for cid, _, who in outstanding(mine, seen or {}):
            lines.append(f"{'':<21}   [ ] {cid}  ({who})")
            lines += _instructions(by_id[cid], records)
        return lines
    if seen is None:
        return lines
    rows = outstanding(mine, seen)
    if rows:
        for cid, verdict, who in rows:
            lines.append(f"{'':<21}   {verdict:<18} {cid}  owed by {who}")
            lines += _instructions(by_id[cid], records)
    elif all(seen.get(c["id"]) == "not_applicable" for c in mine):
        lines.append(f"{'':<21} {_count(len(mine))}, none applicable here")
    else:
        lines.append(f"{'':<21} {_count(len(mine))}, all satisfied")
    return lines


def _count(n: int) -> str:
    return f"{n} control" if n == 1 else f"{n} controls"


def _instructions(control: dict, records: str) -> list[str]:
    """Where to go and what to do, from the control itself. A manually confirmed control also needs the
    step recorded, so name the file."""
    if "where" not in control:
        return []
    lines = [f"{'':<21}     where: {control['where']}",
             f"{'':<21}     todo:  {control['todo']}"]
    if control.get("fact") == "manual_confirmation":
        lines.append(f"{'':<21}     then:  record it in {records}/attestations.yaml")
    return lines

"""Currency of attestations, authority and exceptions, read from the records directory."""

from __future__ import annotations

from datetime import date, datetime, timedelta
from pathlib import Path

import yaml


def load_records(records_dir: Path) -> dict:
    """Load every YAML file in the records directory keyed by stem (attestations, authority, ...)."""
    return {p.stem: yaml.safe_load(p.read_text()) or {} for p in sorted(records_dir.glob("*.yaml"))}


def expired(records: list[dict], days: int, today: date) -> list[str]:
    """Names of records whose `recorded` date is older than the window or missing."""
    stale = []
    for record in records:
        recorded = record.get("recorded")
        if isinstance(recorded, datetime):
            recorded = recorded.date()
        if recorded is None or recorded + timedelta(days=days) < today:
            stale.append(f"{record.get('id', '?')} ({record.get('kind', 'record')})")
    return stale


def currency_findings(records: dict, windows: dict, today: date | None = None) -> list[str]:
    """Blocking findings for records past the window their kind declares. Each record names its own
    kind, so a file is never located by guessing its name from a kind. A kind with no window is
    skipped deliberately: nothing that does not decay needs one."""
    today = today or date.today()
    findings = []
    for doc in records.values():
        by_kind: dict[str, list[dict]] = {}
        for record in (doc or {}).get("records", []) or []:
            by_kind.setdefault(record.get("kind", "record"), []).append(record)
        for kind, entries in sorted(by_kind.items()):
            if kind not in windows:
                continue
            for name in expired(entries, windows[kind], today):
                findings.append(f"{kind} {name} is older than {windows[kind]} days or undated")
    return findings

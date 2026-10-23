"""Currency of attestations, authority and exceptions, read from the runtime directory."""

from __future__ import annotations

from datetime import date, datetime, timedelta
from pathlib import Path

import yaml


def load_runtime(runtime_dir: Path) -> dict:
    """Load every YAML file in the runtime directory keyed by stem (attestations, authority, ...)."""
    return {p.stem: yaml.safe_load(p.read_text()) or {} for p in sorted(runtime_dir.glob("*.yaml"))}


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


def currency_findings(runtime: dict, windows: dict, today: date | None = None) -> list[str]:
    """Blocking findings for stale attestations, authority or exceptions."""
    today = today or date.today()
    findings = []
    for kind in ("attestation", "authority", "exception"):
        records = runtime.get(kind + "s", {}).get("records", [])
        for name in expired(records, windows[kind], today):
            findings.append(f"{kind} {name} is older than {windows[kind]} days or undated")
    return findings

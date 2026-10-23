"""Review records bound to the exact plan file that will be applied."""

from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


def plan_digest(plan_file: Path) -> str:
    return hashlib.sha256(plan_file.read_bytes()).hexdigest()


def write_review(plan_file: Path, reviewer: str, admin: str, out: Path) -> Path:
    """Record that `reviewer` approved this plan file. Refuses the admin identity."""
    if reviewer == admin:
        raise ValueError(f"reviewer '{reviewer}' is the admin identity; business authority is not merge approval")
    record = {"plan_sha256": plan_digest(plan_file), "reviewer": reviewer, "at": datetime.now(timezone.utc).isoformat()}
    out.write_text(json.dumps(record, indent=2) + "\n")
    return out


def review_matches(plan_file: Path, review_file: Path) -> bool:
    """True when the stored review covers exactly this plan file."""
    if not review_file.exists():
        return False
    return json.loads(review_file.read_text()).get("plan_sha256") == plan_digest(plan_file)

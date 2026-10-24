"""Provenance: which policy the gate decided under, as content hashes."""

from __future__ import annotations

import hashlib
from pathlib import Path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def policy_digests(root: Path, policy_files: list[str]) -> dict[str, str]:
    """sha256 of every listed policy file; a listed directory contributes each file inside it."""
    digests: dict[str, str] = {}
    for entry in policy_files:
        path = root / entry
        files = sorted(path.glob("*.yaml")) if path.is_dir() else [path]
        for f in files:
            if f.exists():
                digests[str(f.relative_to(root))] = sha256(f)
    return digests


def plan_policy_versions(plan: dict) -> dict[str, str]:
    """Policy versions a stage published through its outputs (foundation: policy_version; admit: standard)."""
    outputs = plan.get("planned_values", {}).get("outputs", {})
    versions = {}
    if "policy_version" in outputs:
        versions["foundation_catalogue"] = str(outputs["policy_version"].get("value"))
    if "standard" in outputs and isinstance(outputs["standard"].get("value"), dict):
        versions["standard"] = str(outputs["standard"]["value"].get("id"))
    return versions

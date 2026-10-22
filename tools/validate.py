"""Offline structure, reference and optional local-source checks only.

No policy evaluation, desired-state reconciliation, credential loading or HTTP.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

from jsonschema import Draft202012Validator, FormatChecker
import yaml


ROOT = Path(__file__).resolve().parents[1]


class ScaffoldError(ValueError):
    """An invalid or inconsistent scaffold input."""


def require(condition, message):
    if not condition:
        raise ScaffoldError(message)


def unique_mapping(pairs):
    result = {}
    for key, value in pairs:
        require(isinstance(key, str), "Document mapping keys must be strings")
        require(key not in result, f"Duplicate mapping key: {key}")
        result[key] = value
    return result


class UniqueSafeLoader(yaml.SafeLoader):
    pass


def yaml_mapping(loader, node):
    loader.flatten_mapping(node)
    return unique_mapping(
        (loader.construct_object(key), loader.construct_object(value))
        for key, value in node.value
    )


UniqueSafeLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, yaml_mapping
)


def load_document(path):
    path = Path(path)
    text = path.read_text(encoding="utf-8")
    try:
        if path.suffix == ".json":
            return json.loads(text, object_pairs_hook=unique_mapping)
        return yaml.load(text, Loader=UniqueSafeLoader)
    except (json.JSONDecodeError, yaml.YAMLError) as exc:
        raise ScaffoldError(f"Invalid document syntax: {path.name}") from exc


def validate_document(path, schema_name, root=ROOT):
    document = load_document(path)
    schema = load_document(root / "contracts" / schema_name)
    Draft202012Validator.check_schema(schema)
    checker = FormatChecker()
    require("date-time" in checker.checkers, "RFC3339 format dependency is missing; run bootstrap")
    errors = list(Draft202012Validator(schema, format_checker=checker).iter_errors(document))
    if errors:
        error = errors[0]
        location = "/".join(map(str, error.absolute_path)) or "<root>"
        # Do not print source values: validation logs must not disclose payloads.
        raise ScaffoldError(f"{Path(path).name}: schema rule {error.validator} failed at {location}")
    return document


def check_local_sources(strategy_repo, references, bindings):
    commit = references["commit"]
    source_text = {}
    for name, source in references["sources"].items():
        try:
            result = subprocess.run(
                ["git", "-C", str(strategy_repo), "show", f"{commit}:{source['path']}"],
                capture_output=True, check=True, timeout=15,
            )
        except (OSError, subprocess.SubprocessError) as exc:
            raise ScaffoldError(f"Cannot read pinned local source: {name}") from exc
        digest = hashlib.sha256(result.stdout).hexdigest()
        require(digest == source["sha256"], f"Pinned source digest mismatch: {name}")
        source_text[name] = result.stdout.decode("utf-8")
    source_bindings = {}
    for line in source_text["register"].splitlines():
        control = re.match(r"^\| \[([A-Z&]+-\d{2})\]", line)
        if control:
            require(control[1] not in source_bindings, "Duplicate source control")
            source_bindings[control[1]] = re.findall(r"`(P-\d{2})`", line.split("|")[3])
    actual = {entry["control_id"]: entry["parameters"] for entry in bindings["controls"]}
    require(source_bindings == actual, "Bindings differ from the pinned source register")
    return "verified"


def validate_repository(root=ROOT, strategy_repo=None):
    root = Path(root)
    for path in sorted((root / "contracts").glob("*.schema.json")):
        Draft202012Validator.check_schema(load_document(path))

    references = load_document(root / "governance/source-references.yaml")
    profile = validate_document(
        root / "governance/profiles/fs-collab-01.yaml", "profile.schema.json", root
    )
    bindings = load_document(root / "governance/control-bindings.yaml")
    expected_profile = references["profile"]
    require(
        {key: profile[key] for key in ["id", "version", "status"]} == expected_profile,
        "Profile identity/status differs from the source pin",
    )
    require(bindings["register_revision"] == references["sources"]["register"]["revision"],
            "Register revisions differ")
    require(bindings["profile"] == {"id": profile["id"], "version": profile["version"]},
            "Control profile binding differs")
    require(re.fullmatch(r"[0-9a-f]{40}", references["commit"]) is not None,
            "Source commit must be a full Git commit ID")
    parameter_ids = set(profile["parameters"])
    require(parameter_ids == {f"P-{i:02d}" for i in range(1, references["expected_parameters"] + 1)},
            "Parameter groups differ from the source profile")

    controls = bindings["controls"]
    ids = [entry["control_id"] for entry in controls]
    require(len(ids) == references["expected_controls"]["count"], "Control count differs")
    require(len(set(ids)) == len(ids), "Duplicate control IDs")
    digest = hashlib.sha256(("\n".join(sorted(ids)) + "\n").encode()).hexdigest()
    require(digest == references["expected_controls"]["sorted_ids_sha256"],
            "Control IDs differ from the pinned set")
    for entry in controls:
        require(set(entry["parameters"]) <= parameter_ids, "Unknown parameter reference")
        require(len(entry["parameters"]) == len(set(entry["parameters"])), "Duplicate parameter binding")
        require(entry["implementation"] == "not_started" and entry["acceptance"] == "untested",
                "Scaffold must not claim control implementation or acceptance")
        require(entry["tests"] == [], "Scaffold unit tests must not be bound as control acceptance")
    used_parameters = {ref for entry in controls for ref in entry["parameters"]}
    require(used_parameters == parameter_ids, "Unbound parameter group")
    for constraint_controls in bindings["source_cadence_constraints"].values():
        require(set(constraint_controls) <= set(ids), "Unknown source-cadence control")

    environment = validate_document(
        root / "environments/lab/bindings.yaml", "environment-bindings.schema.json", root
    )
    require(environment["profile"] == profile["id"], "Environment profile differs")
    capabilities = load_document(root / "environments/lab/capabilities.yaml")
    require(capabilities["environment"] == "lab"
            and capabilities["live_verification"] == "untested"
            and capabilities["execution_authorized"] is False,
            "Capabilities must remain untested and unauthorised")
    require(all(row["live_verification"] == "untested" for row in capabilities["checks"]),
            "Scaffold cannot claim a live capability test")

    patterns = {}
    for path in sorted((root / "patterns").rglob("pattern.yaml")):
        pattern = validate_document(path, "pattern.schema.json", root)
        key = (pattern["id"], pattern["version"])
        require(key not in patterns, "Duplicate pattern ID/version")
        require(pattern["profile"] == profile["id"], "Unknown pattern profile")
        require(set(pattern["parameters"]) <= parameter_ids, "Unknown pattern parameter")
        patterns[key] = pattern
    require(bool(patterns), "No draft patterns found")

    fixture_records = {}
    for path in sorted((root / "tests/fixtures/authority").glob("*.json")):
        record = validate_document(path, "authoritative-input.schema.json", root)
        require(record["synthetic"] is True, "Only synthetic authority fixtures are permitted")
        require(record["record_id"] not in fixture_records, "Duplicate fixture record")
        fixture_records[record["record_id"]] = record
    assets = []
    for path in sorted((root / "environments/lab/assets").glob("*.yaml")):
        asset = validate_document(path, "asset-intent.schema.json", root)
        pattern_key = (asset["pattern"]["id"], asset["pattern"]["version"])
        require(pattern_key in patterns, "Unknown asset pattern/version")
        pattern = patterns[pattern_key]
        require(asset["kind"] == pattern["kind"], "Asset/pattern kind mismatch")
        require(set(asset["managed_properties"]) <= set(pattern["managed_properties"]),
                "Asset declares unmanaged pattern properties")
        require(asset["requested_classification"] == pattern["desired_outcomes"]["classification"],
                "Example classification differs from its pattern")
        for name, ref in asset["authority_refs"].items():
            require(ref in fixture_records, "Unresolved synthetic authority reference")
            require(fixture_records[ref]["record_type"] == name, "Fixture record-type mismatch")
            require(fixture_records[ref]["subject_ref"] == asset["business_application_ref"],
                    "Fixture/asset application mismatch")
        assets.append(asset)
    require(bool(assets), "No synthetic asset examples found")
    require(len({asset["asset_key"] for asset in assets}) == len(assets), "Duplicate asset key")

    for path in sorted((root / "tests/fixtures/evidence").glob("*.json")):
        record = validate_document(path, "evidence-record.schema.json", root)
        require(record["synthetic"] is True and record["result"] == "untested"
                and record["evidence_type"] == "schema_fixture",
                "Evidence examples must be synthetic untested schema fixtures")
        require(set(record["control_ids"]) <= set(ids), "Unknown evidence control")
        require(record["profile"] == expected_profile, "Evidence profile differs")
        require(record["register_revision"] == bindings["register_revision"], "Evidence register differs")

    source_status = check_local_sources(strategy_repo, references, bindings) if strategy_repo else "not_checked"
    return {
        "result": "scaffold_valid",
        "control_entries": len(controls),
        "parameter_groups": len(parameter_ids),
        "draft_patterns": len(patterns),
        "synthetic_asset_examples": len(assets),
        "source_pins": source_status,
        "policy_decisions_evaluated": 0,
        "live_control_tests": 0,
        "tenant_api_calls": 0,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path, help="Optional local strategy clone; never fetched")
    args = parser.parse_args()
    try:
        print(json.dumps(validate_repository(strategy_repo=args.sources), indent=2))
        return 0
    except (ScaffoldError, OSError, KeyError, TypeError, ValueError) as exc:
        print(f"Scaffold validation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

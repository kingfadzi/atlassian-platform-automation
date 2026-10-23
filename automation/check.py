"""Offline input checks: no policy decisions, credentials or tenant calls."""

import argparse
import hashlib
from pathlib import Path
import re
import subprocess
import sys

from jsonschema import Draft202012Validator
import yaml

ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise ValueError(message)


class UniqueLoader(yaml.SafeLoader):
    pass


def unique_mapping(loader, node):
    loader.flatten_mapping(node)
    result = {}

    for key, value in node.value:
        key = loader.construct_object(key)
        require(
            isinstance(key, str) and key not in result,
            "Duplicate or non-string mapping key",
        )
        result[key] = loader.construct_object(value)

    return result


UniqueLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
    unique_mapping,
)


def load(path):
    return yaml.load(
        Path(path).read_text(encoding="utf-8"),
        Loader=UniqueLoader,
    )


def check_config(config, root=ROOT):
    schema = load(root / "config/schemas/lab.yaml")
    Draft202012Validator.check_schema(schema)

    error = next(
        Draft202012Validator(schema).iter_errors(config),
        None,
    )
    if error:
        location = "/".join(map(str, error.absolute_path)) or "<root>"
        raise ValueError(
            f"Configuration rule {error.validator} failed at {location}"
        )

    keys = [asset["asset_key"] for asset in config["assets"]]
    require(len(keys) == len(set(keys)), "Duplicate asset key")
    require(
        {asset["kind"] for asset in config["assets"]}
        == {"jira_project", "confluence_space"},
        "The MVP requires one project and one space",
    )
    targets = [
        (asset["target_ref"], asset["configuration"]["key"])
        for asset in config["assets"]
    ]
    require(len(targets) == len(set(targets)), "Duplicate native key declaration")


def check_sources(directory, register):
    text = {}

    for name, source in register["sources"].items():
        result = subprocess.run(
            [
                "git", "-C", str(directory), "show",
                f"{register['commit']}:{source['path']}",
            ],
            capture_output=True,
            check=True,
            timeout=15,
        )
        require(
            hashlib.sha256(result.stdout).hexdigest() == source["sha256"],
            f"Pinned source digest differs: {name}",
        )
        text[name] = result.stdout.decode("utf-8")

    bindings = {}

    for line in text["register"].splitlines():
        control = re.match(r"^\| \[([A-Z&]+-\d{2})\]", line)
        if control:
            require(control[1] not in bindings, "Duplicate source control")
            bindings[control[1]] = re.findall(
                r"`(P-\d{2})`",
                line.split("|")[3],
            )

    require(
        bindings == register["controls"],
        "Control mappings differ from the pinned register",
    )


def check(root=ROOT, sources=None):
    root = Path(root)
    register = load(root / "policy/controls.yaml")
    profile_path = root / "policy/profiles/fs-collab-01.yaml"
    profile = load(profile_path)
    config = load(root / "config/environments/lab.yaml")

    require(
        hashlib.sha256(profile_path.read_bytes()).hexdigest()
        == register["profile_snapshot_sha256"],
        "Profile snapshot differs; review and repin intentional changes",
    )
    require(
        {key: profile[key] for key in ("id", "version", "status")}
        == register["profile"],
        "Profile identity or status differs",
    )
    require(
        profile["status"] == "assumed"
        and profile["production_approved"] is False,
        "This profile is provisional, not firm-approved",
    )
    require(
        profile["source_register_revision"]
        == register["sources"]["register"]["revision"],
        "Profile and register revisions differ",
    )
    require(
        re.fullmatch(r"[0-9a-f]{40}", register["commit"]),
        "Source commit is not pinned",
    )

    parameters = set(profile["parameters"])
    require(
        parameters == {
            f"P-{i:02d}"
            for i in range(1, register["expected_parameters"] + 1)
        },
        "Profile parameter set differs",
    )

    controls = register["controls"]
    require(
        len(controls) == register["expected_controls"]["count"],
        "Control count differs",
    )

    digest = hashlib.sha256(
        ("\n".join(sorted(controls)) + "\n").encode()
    ).hexdigest()
    require(
        digest == register["expected_controls"]["sorted_ids_sha256"],
        "Control set differs",
    )
    require(
        register["implementation"] == "not_started"
        and register["acceptance"] == "untested",
        "Input checks cannot claim control implementation or acceptance",
    )

    for refs in controls.values():
        require(
            set(refs) <= parameters and len(refs) == len(set(refs)),
            "Invalid parameter binding",
        )

    require(
        {ref for refs in controls.values() for ref in refs} == parameters,
        "Unbound parameter",
    )

    for refs in register["source_cadence_constraints"].values():
        require(set(refs) <= set(controls), "Unknown cadence control")

    check_config(config, root)
    require(config["profile"] == profile["id"], "Lab profile differs")
    require(
        set(config["foundation"]["parameters"]) <= parameters,
        "Unknown foundation parameter",
    )

    if sources:
        check_sources(sources, register)

    return {
        "result": "valid_inputs",
        "controls": len(controls),
        "parameter_groups": len(parameters),
        "assets": len(config["assets"]),
        "source_pins": "verified" if sources else "not_checked",
        "scope": "offline_structure_only",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--sources",
        type=Path,
        help="Local strategy clone; never fetched",
    )
    args = parser.parse_args()

    try:
        for key, value in check(sources=args.sources).items():
            print(f"{key}: {value}")
        return 0
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
        yaml.YAMLError,
        subprocess.SubprocessError,
    ):
        # Do not disclose input values or captured subprocess output.
        print(
            "Input check failed; inspect configuration, schema and source pins.",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

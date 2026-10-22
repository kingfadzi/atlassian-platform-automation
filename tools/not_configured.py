"""Fail explicitly rather than pretend that a live operation succeeded."""

import argparse
import json


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["status", "plan", "apply", "verify", "observe"])
    command = parser.parse_args().command
    print(json.dumps({
        "command": command,
        "result": "unconfigured" if command == "status" else "blocked",
        "reason": "No policy engine, execution adapter, tenant binding or remote authority configured.",
        "policy_decisions_evaluated": 0,
        "tenant_api_calls": 0,
        "control_acceptance": "untested",
    }, indent=2))
    return 0 if command == "status" else 2


if __name__ == "__main__":
    raise SystemExit(main())

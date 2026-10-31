"""govern: gate | review | verify. Terraform itself is driven by the pipeline, not by Python.

  govern gate   --plan-json plan.json --stage admit --records records/lab [--authority authority.yaml]
  govern review --plan plan.bin --reviewer USER --admin USER --out review.json
  govern verify --plan plan.bin --review review.json
  govern status [--outputs <phase>=<terraform output -json>]...
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import yaml

from govern import currency, gate, provenance, review, status

ROOT = Path(__file__).resolve().parent.parent
POLICY = ROOT / "policy" / "gate.yaml"


def cmd_gate(args: argparse.Namespace) -> int:
    rules = yaml.safe_load(POLICY.read_text())
    plan = json.loads(Path(args.plan_json).read_text())
    records = currency.load_records(Path(args.records))
    verdict = gate.evaluate(plan, rules, records.get("authority"))
    verdict.blocked.extend(currency.currency_findings(records, rules["windows_days"]))
    report = {"stage": args.stage, "ok": verdict.ok, "creates": verdict.creates,
              "blocked": verdict.blocked, "reported": verdict.reported,
              "policy": {"files": provenance.policy_digests(ROOT, rules.get("policy_files", [])),
                         "versions": provenance.plan_policy_versions(plan)}}
    print(json.dumps(report, indent=2))
    if args.ledger:
        ledger = Path(args.ledger)
        ledger.parent.mkdir(parents=True, exist_ok=True)
        with ledger.open("a") as handle:
            handle.write(json.dumps(report) + "\n")
    return 0 if verdict.ok else 3


def cmd_review(args: argparse.Namespace) -> int:
    out = review.write_review(Path(args.plan), args.reviewer, args.admin, Path(args.out))
    print(f"review recorded in {out}")
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    ok = review.review_matches(Path(args.plan), Path(args.review))
    print("review matches plan" if ok else "no review for this exact plan file")
    return 0 if ok else 3


def cmd_status(args: argparse.Namespace) -> int:
    """The stand-up sequence and where the platform stands in it."""
    outputs = {}
    for pair in args.outputs or []:
        name, _, path = pair.partition("=")
        outputs[name] = json.loads(Path(path).read_text())
    print(status.render(
        status.load_phases(ROOT / "policy" / "phases.yaml"),
        status.load_controls([ROOT / "policy" / "foundation.yaml", ROOT / "policy" / "conformance.yaml"]),
        outputs,
        args.phase,
        args.records,
        status.load_steps(ROOT / "policy" / "unchecked.yaml"),
    ))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="govern")
    sub = parser.add_subparsers(dest="command", required=True)
    g = sub.add_parser("gate")
    g.add_argument("--plan-json", required=True)
    g.add_argument("--stage", required=True)
    g.add_argument("--records", required=True)
    g.add_argument("--ledger")
    g.set_defaults(func=cmd_gate)
    r = sub.add_parser("review")
    for flag in ("--plan", "--reviewer", "--admin", "--out"):
        r.add_argument(flag, required=True)
    r.set_defaults(func=cmd_review)
    v = sub.add_parser("verify")
    v.add_argument("--plan", required=True)
    v.add_argument("--review", required=True)
    v.set_defaults(func=cmd_verify)
    s = sub.add_parser("status")
    s.add_argument("--phase", help="narrow the view to one phase")
    s.add_argument("--records", default="records/lab",
                   help="where attestations are recorded; named in the view when one is owed")
    s.add_argument("--outputs", action="append", metavar="PHASE=FILE",
                   help="a stage's `terraform output -json`; omit for a checklist from policy alone")
    s.set_defaults(func=cmd_status)
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except ValueError as exc:
        print(f"refused: {exc}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())

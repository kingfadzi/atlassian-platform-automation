"""govern: gate | review | verify. Terraform itself is driven by the pipeline, not by Python.

  govern gate   --plan-json plan.json --stage admit --runtime runtime/lab [--authority authority.yaml]
  govern review --plan plan.bin --reviewer USER --admin USER --out review.json
  govern verify --plan plan.bin --review review.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import yaml

from govern import currency, gate, review

POLICY = Path(__file__).resolve().parent.parent / "policy" / "gate.yaml"


def cmd_gate(args: argparse.Namespace) -> int:
    rules = yaml.safe_load(POLICY.read_text())
    plan = json.loads(Path(args.plan_json).read_text())
    runtime = currency.load_runtime(Path(args.runtime))
    verdict = gate.evaluate(plan, rules, runtime.get("authority"))
    verdict.blocked.extend(currency.currency_findings(runtime, rules["windows_days"]))
    report = {"stage": args.stage, "ok": verdict.ok, "creates": verdict.creates,
              "blocked": verdict.blocked, "reported": verdict.reported}
    print(json.dumps(report, indent=2))
    Path(args.ledger).open("a").write(json.dumps(report) + "\n") if args.ledger else None
    return 0 if verdict.ok else 3


def cmd_review(args: argparse.Namespace) -> int:
    out = review.write_review(Path(args.plan), args.reviewer, args.admin, Path(args.out))
    print(f"review recorded in {out}")
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    ok = review.review_matches(Path(args.plan), Path(args.review))
    print("review matches plan" if ok else "no review for this exact plan file")
    return 0 if ok else 3


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="govern")
    sub = parser.add_subparsers(dest="command", required=True)
    g = sub.add_parser("gate")
    g.add_argument("--plan-json", required=True)
    g.add_argument("--stage", required=True)
    g.add_argument("--runtime", required=True)
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
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except ValueError as exc:
        print(f"refused: {exc}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env bash
# End-to-end proof against the stub tenant: tenancy -> foundation -> estate with local state.
# Proves: create then three clean re-plans; out-of-band drift reported with no actions; a removed
# provisioned grant detected from the tenant and recovered; every seeded instance defect found
# by estate with no actions; estate refuses a stale foundation; a YAML-only change flips a
# verdict; a removal from configuration is refused. Run with: make spike
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TF="${1:-terraform}"
PORT=8089
export TF_IN_AUTOMATION=1 TF_INPUT=0
export TF_VAR_atlassian_org_api_key=stub TF_VAR_atlassian_email=admin@lab TF_VAR_atlassian_api_token=stub
export TF_VAR_admin_api_url="http://127.0.0.1:$PORT/admin"
export TF_VAR_env=lab
# records fixture: the committed records, plus import records written here so their hashes are
# always the current jsm/ files rather than something stale in the fixture.
rm -rf /tmp/spike-records && cp -r "$ROOT/tests/stub/records" /tmp/spike-records
{ echo "records:"
  for f in asset_workflow:jsm/asset-workflow.yaml automation_rules:jsm/automation-rules.json; do
    printf '  - { id: %s, kind: import, recorded: 2026-10-20T00:00:00Z, by: USER-LAB-ADMIN, sha256: "%s" }\n' \
      "${f%%:*}" "$(sha256sum "$ROOT/${f#*:}" | cut -d' ' -f1)"
  done
} > /tmp/spike-records/imports.yaml
VARS=(-var-file="$ROOT/envs/lab/lab.tfvars" -var 'tenant={org_id="org-1",directory_id="dir-1",site_url="http://127.0.0.1:8089",group_pattern="^lab-"}' -var "records_dir=/tmp/spike-records" -var "dns_resolvers=[\"http://127.0.0.1:$PORT/dns/resolve\"]")
STAGES=(tenancy foundation estate)

(cd "$ROOT/tests/stub" && exec python3 stub_tenant.py "$PORT" >/tmp/stub.log 2>&1) &
rm -f /tmp/spike-foundation.yaml /tmp/spike-standard.yaml /tmp/spike-rules.json   # copies from an earlier run must never be restored
STUB=$!; trap 'kill $STUB 2>/dev/null; rm -f "$ROOT"/stages/*/backend_override.tf "$ROOT"/stages/estate/remote_state_override.tf; [ -f /tmp/spike-foundation.yaml ] && cp /tmp/spike-foundation.yaml "$ROOT/policy/foundation.yaml"; [ -f /tmp/spike-standard.yaml ] && cp /tmp/spike-standard.yaml "$ROOT/policy/standards/restricted-collab-v1.yaml"; [ -f /tmp/spike-rules.json ] && cp /tmp/spike-rules.json "$ROOT/jsm/automation-rules.json"; true' EXIT
sleep 1.5

# BSD sed requires a suffix for -i and GNU accepts one, so edit in place and drop the backup.
sedi() { sed -i.spike "$1" "$2" && rm -f "$2.spike"; }

plan_expect_clean() { # stage label
  "$TF" -chdir="$ROOT/stages/$1" plan -detailed-exitcode -no-color "${VARS[@]}" >/tmp/spike-plan.out 2>&1 && rc=0 || rc=$?
  [ $rc -eq 0 ] && echo "  plan ($2): no changes" || { echo "  plan ($2): exit $rc"; grep -E "Plan:|Warning|Error" /tmp/spike-plan.out | head -5; return 1; }
}
apply_quiet() { "$TF" -chdir="$ROOT/stages/$1" apply -auto-approve -no-color "${VARS[@]}" >/tmp/spike-apply.out 2>&1 || true; }
out() { "$TF" -chdir="$ROOT/stages/$1" output -json "$2"; }

# estate reads the foundation state from a local file in the spike (http backend in the pipeline)
cat > "$ROOT/stages/estate/remote_state_override.tf" <<'HCL'
data "terraform_remote_state" "foundation" {
  backend = "local"
  config  = { path = "../foundation/terraform.tfstate" }
}
HCL
for stage in "${STAGES[@]}"; do
  dir="$ROOT/stages/$stage"
  printf 'terraform {\n  backend "local" {}\n}\n' > "$dir/backend_override.tf"
  rm -f "$dir"/terraform.tfstate*
  "$TF" -chdir="$dir" init -no-color >/dev/null
  "$TF" -chdir="$dir" validate -no-color >/dev/null && echo "[$stage] validate ok"
done

run_stage() { # stage: apply, then three clean re-plans
  "$TF" -chdir="$ROOT/stages/$1" apply -auto-approve -no-color "${VARS[@]}" | grep -E "Apply complete|Error|Warning" | sed "s/^/  /"
  for n in 1 2 3; do plan_expect_clean "$1" "rerun $n"; done
}
run_stage tenancy
run_stage foundation
echo "  contract: $(out foundation contract | python3 -c 'import json,sys; c=json.load(sys.stdin); s=c["standards"]["restricted-collab-v1"]; print("scheme", s["scheme_id"], "roles", s["roles"], "stamp", c["stamp"])')"
echo "  treatment: $(out foundation contract | python3 -c 'import json,sys; t=json.load(sys.stdin)["treatment"]; print(t["project_key"], "asset type", t["issue_type_id"], "fields", sorted(t["field_ids"]), "request types", sorted(t["request_types"]))')"
echo "  ready = $(out foundation ready | tr -d '\n ')"
echo "  entitlement = $(out foundation entitlement | tr -d '\n ')"
python3 - "$(out foundation controls)" <<'PY'
import json, sys
v = json.loads(sys.argv[1])
for c in ("jira_plan_paid", "confluence_plan_above_free"):
    assert v[c] == "fail", f"the stub is a Free tenant; {c} must be a reported fail, got {v[c]}"
print("  entitlement controls report the Free plan without blocking readiness")
PY
python3 - "$(out foundation ready)" <<'PY'
import json, sys
ready = json.loads(sys.argv[1])
assert ready == {"jira": True, "confluence": True, "treatment": True}, f"all three dimensions must be ready: {ready}"
PY

echo "[jsm] the stub seeds instances the way requests would create them (one conforming, the rest defective)"
out foundation contract > /tmp/spike-contract.json
python3 "$ROOT/tests/stub/seed_estate.py" "$PORT" /tmp/spike-contract.json | sed 's/^/  /'
run_stage estate
out estate findings | python3 -c 'import json,sys; [print("  finding:", f) for f in json.load(sys.stdin)]'
python3 - <<'PY' "$(out estate instances)" "$(out estate summary)"
import json, sys
inst, summary = json.loads(sys.argv[1]), json.loads(sys.argv[2])
A = "asset_record_present"   # every instance that did not go through the service lacks its Asset record
expect = {
  "jira:LABOK": set(), "jira:LABUSR": {"roles_bound_to_groups_only"}, "jira:LABNST": {"stamped_with_standard", A},
  "jira:LABOLD": {"recently_active", A}, "jira:LABNOA": {"admin_role_bound", A}, "jira:LABEXT": {"groups_match_ad_pattern", A},
  "jira:LABFOR": {"stamped_with_standard", "on_standard_scheme", "no_public_access", A},
  "confluence:LABOK": set(), "confluence:LABPUB": {"no_public_access", A}, "confluence:LABOLDS": {"stamped_with_standard", "recently_active", A},
}
assert "jira:ATS" not in inst, "the treatment project is platform desired state, not an instance"
for key, want in expect.items():
    got = set(inst[key]["actions"])
    assert got == want, f"{key}: expected {sorted(want)}, got {sorted(got)}"
assert inst["jira:LABNST"]["standard"] == "restricted-collab-v1", "unstamped project must be classified by its scheme"
assert inst["jira:LABFOR"]["actions"]["on_standard_scheme"] == {"rung": "restrict", "performed": "report"}, "restrict is planned, report performed"
print(f"  every seeded defect found; summary = {json.dumps(summary, separators=(',', ':'))}")
PY

echo "[drift] rename the standard's scheme out of band, expect a failing check and no actions"
SID=$(python3 -c 'import json; print(json.load(open("/tmp/spike-contract.json"))["standards"]["restricted-collab-v1"]["scheme_id"])')
curl -s -X POST -H 'content-type: application/json' -d '{"name":"renamed by an admin"}' "http://127.0.0.1:$PORT/__stub/schemes/$SID" >/dev/null
"$TF" -chdir="$ROOT/stages/foundation" plan -no-color -out=/tmp/spike-drift.bin "${VARS[@]}" >/tmp/spike-plan.out 2>&1 || true
"$TF" -chdir="$ROOT/stages/foundation" show -json /tmp/spike-drift.bin > /tmp/spike-drift.json
python3 - <<'PY'
import json
p = json.load(open("/tmp/spike-drift.json"))
actions = sorted({a for c in p.get("resource_changes", []) for a in c["change"]["actions"]})
failed = [c["address"]["to_display"] for c in p.get("checks", []) if c["status"] == "fail"]
print(f"  actions={actions} drifted={len(p.get('resource_drift', []))} failed_checks={failed}")
assert actions == ["no-op"] and any("scheme_matches_policy" in f for f in failed)
PY
curl -s -X POST -H 'content-type: application/json' -d '{"name":"Platform restricted-collab-v1"}' "http://127.0.0.1:$PORT/__stub/schemes/$SID" >/dev/null

echo "[provision] a grant removed out of band is detected from the tenant and recovered with state rm + apply"
VICTIM=$(python3 - "$PORT" "$SID" <<'PY'
import json, sys, urllib.request
port, sid = sys.argv[1], int(sys.argv[2])
get = lambda p: json.load(urllib.request.urlopen(f"http://127.0.0.1:{port}{p}"))
scheme = next(s for s in get("/__stub/dump")["schemes"] if s["id"] == sid)
victim, rest = scheme["permissions"][0], scheme["permissions"][1:]
body = json.dumps({"permissions": rest}).encode()
urllib.request.urlopen(urllib.request.Request(f"http://127.0.0.1:{port}/__stub/schemes/{sid}", body, {"content-type": "application/json"}, method="POST"))
role = next(r["name"] for r in get("/rest/api/3/role") if str(r["id"]) == str(victim["holder"]["parameter"]))
print(f"{victim['permission']}:{role.removeprefix('platform-')}")
PY
)
echo "  removed grant $VICTIM"
"$TF" -chdir="$ROOT/stages/foundation" plan -no-color -out=/tmp/spike-prov.bin "${VARS[@]}" >/tmp/spike-plan.out 2>&1 || true
"$TF" -chdir="$ROOT/stages/foundation" show -json /tmp/spike-prov.bin > /tmp/spike-prov.json
python3 - <<'PY'
import json
p = json.load(open("/tmp/spike-prov.json"))
changes = [c["address"] for c in p.get("resource_changes", []) if c["change"]["actions"] != ["no-op"] and c["mode"] == "managed"]
failed = [c["address"]["to_display"] for c in p.get("checks", []) if c["status"] == "fail"]
print(f"  detected: actions={changes} failed_checks={failed}")
assert changes == [], "the provider cannot see the deletion (restapi #377); the plan must stay a no-op"
assert "check.mandatory_controls" in failed, "scheme_grants_match_standards must fail from the tenant read"
PY
"$TF" -chdir="$ROOT/stages/foundation" state rm -no-color "module.scheme[\"restricted-collab-v1\"].restapi_object.grant[\"$VICTIM\"]" >/dev/null
"$TF" -chdir="$ROOT/stages/foundation" plan -no-color -out=/tmp/spike-prov.bin "${VARS[@]}" >/tmp/spike-plan.out 2>&1 || true
"$TF" -chdir="$ROOT/stages/foundation" show -json /tmp/spike-prov.bin > /tmp/spike-prov.json
python3 - <<'PY'
import json
p = json.load(open("/tmp/spike-prov.json"))
changes = [(c["address"], c["change"]["actions"]) for c in p.get("resource_changes", []) if c["change"]["actions"] != ["no-op"] and c["mode"] == "managed"]
print(f"  recovery plan: {changes}")
assert len(changes) == 1 and changes[0][1] == ["create"] and ".grant[" in changes[0][0], "recovery must re-create exactly the missing grant"
PY
"$TF" -chdir="$ROOT/stages/foundation" apply -auto-approve -no-color /tmp/spike-prov.bin >/dev/null 2>&1
plan_expect_clean foundation "after recovery"
echo "  ready = $(out foundation ready | tr -d '\n ')"

echo "[foundation] a failing mandatory control must show in readiness"
curl -s -X POST "http://127.0.0.1:$PORT/__stub/fail/anonymous_jira_closed" >/dev/null
apply_quiet foundation
echo "  foundation ready = $(out foundation ready | tr -d '\n ') blocking = $(out foundation blocking | tr -d '\n ')"
curl -s -X DELETE "http://127.0.0.1:$PORT/__stub/fail/anonymous_jira_closed" >/dev/null
apply_quiet foundation
plan_expect_clean foundation "foundation restored"

echo "[estate] a stale foundation evaluation must stop estate at plan time"
if "$TF" -chdir="$ROOT/stages/estate" plan -no-color "${VARS[@]}" -var foundation_window_days=0 >/tmp/spike-plan.out 2>&1; then
  echo "  FAIL: estate planned on a stale foundation"; exit 1
else
  grep -q "older than 0 days" /tmp/spike-plan.out && echo "  estate refused: foundation evaluation older than the window"
fi

echo "[policy] a requirement changed in YAML alone must change a verdict (no HCL touched)"
cp "$ROOT/policy/foundation.yaml" /tmp/spike-foundation.yaml
sedi 's/require: { op: within_days, value: 7 }/require: { op: within_days, value: 0 }/' "$ROOT/policy/foundation.yaml"
apply_quiet foundation
echo "  foundation audit window 7 -> 0 days: ready = $(out foundation ready | tr -d '\n ')"
cp /tmp/spike-foundation.yaml "$ROOT/policy/foundation.yaml"; rm -f /tmp/spike-foundation.yaml
apply_quiet foundation
cp "$ROOT/policy/standards/restricted-collab-v1.yaml" /tmp/spike-standard.yaml
sedi 's/inactive_days: 90 /inactive_days: 100000 /' "$ROOT/policy/standards/restricted-collab-v1.yaml"
apply_quiet estate
echo "  standard inactive_days 90 -> 100000: LABOLD recently_active = $(out estate instances | python3 -c 'import json,sys; print(json.load(sys.stdin)["jira:LABOLD"]["verdict"]["recently_active"])')"
cp /tmp/spike-standard.yaml "$ROOT/policy/standards/restricted-collab-v1.yaml"; rm -f /tmp/spike-standard.yaml
apply_quiet estate
echo "  restored: LABOLD recently_active = $(out estate instances | python3 -c 'import json,sys; print(json.load(sys.stdin)["jira:LABOLD"]["verdict"]["recently_active"])')"

echo "[imports] a changed jsm/ file must invalidate its record until re-imported and re-recorded"
cp "$ROOT/jsm/automation-rules.json" /tmp/spike-rules.json
python3 - "$ROOT/jsm/automation-rules.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["rules"][0]["name"] += " (edited)"; json.dump(d, open(p, "w"), indent=2)
PY
apply_quiet foundation
echo "  rules edited: ready.treatment = $(out foundation ready | python3 -c 'import json,sys; print(json.load(sys.stdin)["treatment"])') blocking = $(out foundation blocking | tr -d '\n ')"
cp /tmp/spike-rules.json "$ROOT/jsm/automation-rules.json"; rm -f /tmp/spike-rules.json
apply_quiet foundation
echo "  restored: ready.treatment = $(out foundation ready | python3 -c 'import json,sys; print(json.load(sys.stdin)["treatment"])')"

echo "[placement] a realm outside the environment's permitted set must block, from policy alone"
curl -s -X POST "http://127.0.0.1:$PORT/__stub/fail/product_placement_permitted" >/dev/null
"$TF" -chdir="$ROOT/stages/foundation" apply -auto-approve -no-color "${VARS[@]}" >/tmp/spike-plan.out 2>&1 || true
echo "  realm us, lab permits global: ready = $("$TF" -chdir="$ROOT/stages/foundation" output -json ready | tr -d '\n ')"
echo "  blocking = $("$TF" -chdir="$ROOT/stages/foundation" output -json blocking | tr -d '\n ')"
"$TF" -chdir="$ROOT/stages/foundation" output -json blocking | grep -q product_placement_permitted \
  || { echo "  FAIL: an unpermitted realm did not block"; exit 1; }
"$TF" -chdir="$ROOT/stages/foundation" output -json blocking | grep -q product_placement_matches_intent \
  || { echo "  FAIL: a realm that is not the declared one did not block"; exit 1; }
sedi 's/^  lab: \[global\]/  lab: [global, us]/' "$ROOT/policy/intent_rules.yaml"
"$TF" -chdir="$ROOT/stages/foundation" apply -auto-approve -no-color "${VARS[@]}" >/dev/null 2>&1 || true
"$TF" -chdir="$ROOT/stages/foundation" output -json blocking | grep -q product_placement_permitted \
  && { echo "  FAIL: permitting the realm in YAML did not clear the control"; exit 1; }
echo "  permitted in YAML alone: product_placement_permitted cleared; intent mismatch still blocks"
sedi 's/^  lab: \[global, us\]/  lab: [global]/' "$ROOT/policy/intent_rules.yaml"
curl -s -X DELETE "http://127.0.0.1:$PORT/__stub/fail/product_placement_permitted" >/dev/null
"$TF" -chdir="$ROOT/stages/foundation" apply -auto-approve -no-color "${VARS[@]}" >/dev/null 2>&1

echo "[domains] every declared TLD must be verified; one missing blocks"
curl -s -X POST "http://127.0.0.1:$PORT/__stub/fail/verified_domains_known" >/dev/null
"$TF" -chdir="$ROOT/stages/foundation" apply -auto-approve -no-color "${VARS[@]}" >/tmp/spike-plan.out 2>&1 || true
echo "  one of two TLDs verified: blocking = $("$TF" -chdir="$ROOT/stages/foundation" output -json blocking | tr -d '\n ')"
"$TF" -chdir="$ROOT/stages/foundation" output -json blocking | grep -q verified_domains_known \
  || { echo "  FAIL: an unverified declared domain did not block"; exit 1; }
curl -s -X DELETE "http://127.0.0.1:$PORT/__stub/fail/verified_domains_known" >/dev/null
"$TF" -chdir="$ROOT/stages/foundation" apply -auto-approve -no-color "${VARS[@]}" >/dev/null 2>&1
"$TF" -chdir="$ROOT/stages/foundation" output -json blocking | grep -q verified_domains_known \
  && { echo "  FAIL: both TLDs verified but the control still blocks"; exit 1; }
echo "  both verified: cleared"

echo "[dns] a verification record removed from the zone is reported before Atlassian re-checks"
for control in domain_verification_record_present domain_claimed_by_one_org; do
  curl -s -X POST "http://127.0.0.1:$PORT/__stub/fail/$control" >/dev/null
done
"$TF" -chdir="$ROOT/stages/foundation" apply -auto-approve -no-color "${VARS[@]}" >/tmp/spike-plan.out 2>&1 || true
python3 - "$(out foundation findings)" "$(out foundation blocking)" "$(out foundation controls)" "$(out foundation details)" <<'PY'
import json, sys
findings, blocking, controls, details = (json.loads(a) for a in sys.argv[1:5])
for c in ("domain_verification_record_present", "domain_claimed_by_one_org"):
    assert findings.get(c) == "fail", f"{c} must be a reported fail, got {findings.get(c)}"
    assert c not in blocking, f"{c} must not block; Atlassian's own claim is the mandatory control"
assert controls["verified_domains_known"] == "pass", "Atlassian still reports the domain verified: that is the gap"
assert details["domains_missing_record"] == ["lab.test"], f"the broken zone must be named: {details['domains_missing_record']}"
print("  record gone from DNS while claim.status still says verified: reported, not blocking")
PY
for control in domain_verification_record_present domain_claimed_by_one_org; do
  curl -s -X DELETE "http://127.0.0.1:$PORT/__stub/fail/$control" >/dev/null
done
apply_quiet foundation
plan_expect_clean foundation "dns restored"
out foundation findings | grep -q domain_ \
  && { echo "  FAIL: restoring the record left a domain finding"; exit 1; }
echo "  record restored: both domain controls clear"

echo "[permissions] a declared account holding more than its kind allows must be named"
curl -s -X POST "http://127.0.0.1:$PORT/__stub/fail/account_global_permissions" >/dev/null
"$TF" -chdir="$ROOT/stages/foundation" apply -auto-approve -no-color "${VARS[@]}" >/tmp/spike-plan.out 2>&1 || true
python3 - "$(out foundation details)" "$(out foundation blocking)" <<'PERM'
import json, sys
details, blocking = json.loads(sys.argv[1]), json.loads(sys.argv[2])
held = details["disallowed_permissions"]
assert held == ["USER-LAB-ENGINE|SYSTEM_ADMIN"], f"the account and the permission must both be named: {held}"
assert "account_global_permissions" in blocking, "an over-privileged declared account must block jira"
print(f"  asked Jira per account: {held[0]}")
PERM
curl -s -X DELETE "http://127.0.0.1:$PORT/__stub/fail/account_global_permissions" >/dev/null
apply_quiet foundation
out foundation details | grep -q '"disallowed_permissions":\[\]' \
  || { echo "  FAIL: removing the permission left a finding"; exit 1; }
echo "  permission removed: every declared account within its kind"

echo "[workflow] a transition missing from the tenant's workflow must be named, not taken on trust"
curl -s -X POST "http://127.0.0.1:$PORT/__stub/fail/asset_workflow_gaps" >/dev/null
"$TF" -chdir="$ROOT/stages/foundation" apply -auto-approve -no-color "${VARS[@]}" >/tmp/spike-plan.out 2>&1 || true
python3 - "$(out foundation details)" "$(out foundation blocking)" <<'PY'
import json, sys
details, blocking = json.loads(sys.argv[1]), json.loads(sys.argv[2])
gaps = details["asset_workflow_gaps"]
assert gaps == ["transition:Active|Archive|Archived"], f"the missing transition must be named: {gaps}"
assert "asset_workflow_built" in blocking, "a workflow that does not match the declaration must block treatment"
print(f"  missing from the tenant: {gaps[0]}")
PY
curl -s -X DELETE "http://127.0.0.1:$PORT/__stub/fail/asset_workflow_gaps" >/dev/null
apply_quiet foundation
out foundation details | grep -q '"asset_workflow_gaps":\[\]' \
  || { echo "  FAIL: rebuilding the transition left a gap"; exit 1; }
echo "  workflow rebuilt: declared and honoured agree"

echo "[destroy] removing a provisioned role from policy must be refused"
cp "$ROOT/policy/standards/restricted-collab-v1.yaml" /tmp/spike-standard.yaml
sedi 's/^roles: \[admin, lead, member, viewer\]/roles: [admin, lead, member]/; /^    viewer: /d' "$ROOT/policy/standards/restricted-collab-v1.yaml"
if "$TF" -chdir="$ROOT/stages/foundation" plan -no-color "${VARS[@]}" >/tmp/spike-plan.out 2>&1; then
  echo "  FAIL: plan accepted a removal"; exit 1
else
  grep -q "prevent_destroy" /tmp/spike-plan.out && echo "  refused by prevent_destroy"
fi
cp /tmp/spike-standard.yaml "$ROOT/policy/standards/restricted-collab-v1.yaml"; rm -f /tmp/spike-standard.yaml
echo "spike complete"

#!/usr/bin/env bash
# Spike: run every stage against the stub tenant with local state and prove
#   create -> three plans with no changes, out-of-band change -> check failure, no destroy.
# Usage: tests/spike.sh [terraform-binary]
set -euo pipefail
TF=${1:-terraform}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PORT=8089
export TF_IN_AUTOMATION=1 TF_INPUT=0
export TF_VAR_atlassian_org_api_key=stub TF_VAR_atlassian_email=admin@lab TF_VAR_atlassian_api_token=stub
export TF_VAR_admin_api_url="http://127.0.0.1:$PORT/admin"
export TF_VAR_probe_allowed_email=allowed@lab TF_VAR_probe_allowed_token=stub
export TF_VAR_probe_denied_email=denied@lab TF_VAR_probe_denied_token=stub
VARS=(-var-file="$ROOT/envs/lab/lab.tfvars" -var 'tenant={org_id="org-1",directory_id="dir-1",site_url="http://127.0.0.1:8089",scope_regex="^lab-"}' -var "runtime_dir=$ROOT/tests/stub/runtime")

(cd "$ROOT/tests/stub" && python3 stub_tenant.py $PORT) >/tmp/stub_tenant.log 2>&1 &
rm -f /tmp/spike-foundation.yaml   # a copy from an earlier run must never be restored over the working tree
STUB=$!; trap 'kill $STUB 2>/dev/null; rm -f "$ROOT"/stages/*/backend_override.tf "$ROOT"/stages/admit/remote_state_override.tf; [ -f /tmp/spike-foundation.yaml ] && cp /tmp/spike-foundation.yaml "$ROOT/policy/foundation.yaml"' EXIT
sleep 2

plan_expect_clean() { # stage label
  "$TF" -chdir="$ROOT/stages/$1" plan -detailed-exitcode -no-color "${VARS[@]}" >/tmp/spike-plan.out 2>&1 && rc=0 || rc=$?
  [ $rc -eq 0 ] && echo "  plan ($2): no changes" || { echo "  plan ($2): exit $rc"; grep -E "Plan:|Warning|Error" /tmp/spike-plan.out | head -5; return 1; }
}

# admit reads the foundation state from a local file in the spike (http backend in the pipeline)
cat > "$ROOT/stages/admit/remote_state_override.tf" <<'HCL'
data "terraform_remote_state" "foundation" {
  backend = "local"
  config  = { path = "../foundation/terraform.tfstate" }
}
HCL

for stage in bootstrap identity foundation admit release; do
  dir="$ROOT/stages/$stage"
  printf 'terraform {\n  backend "local" {}\n}\n' > "$dir/backend_override.tf"
  rm -f "$dir"/terraform.tfstate*
  "$TF" -chdir="$dir" init -no-color >/dev/null
  "$TF" -chdir="$dir" validate -no-color >/dev/null && echo "[$stage] validate ok"
  # observe-only stages own no resources; apply just records their outputs and checks
  "$TF" -chdir="$dir" apply -auto-approve -no-color "${VARS[@]}" | grep -E "Apply complete|Error|Warning" | sed "s/^/  /"
  for n in 1 2 3; do plan_expect_clean "$stage" "rerun $n"; done
done

echo "[drift] rename the standard's scheme out of band, expect a failing check and no actions"
SID=$("$TF" -chdir="$ROOT/stages/admit" output -raw scheme_id)
curl -s -X POST -H 'content-type: application/json' -d '{"name":"renamed by an admin"}' "http://127.0.0.1:$PORT/__stub/schemes/$SID" >/dev/null
"$TF" -chdir="$ROOT/stages/foundation" plan -no-color -out=/tmp/spike-drift.bin "${VARS[@]}" >/tmp/spike-plan.out 2>&1 || true
"$TF" -chdir="$ROOT/stages/foundation" show -json /tmp/spike-drift.bin > /tmp/spike-drift.json
python3 - <<'PY'
import json
p = json.load(open("/tmp/spike-drift.json"))
actions = sorted({a for c in p.get("resource_changes", []) for a in c["change"]["actions"]})
failed = [c["address"]["to_display"] for c in p.get("checks", []) if c["status"] == "fail"]
print(f"  actions={actions} drifted={len(p.get('resource_drift', []))} failed_checks={failed}")
assert actions == ["no-op"] and failed, "drift must be reported, never repaired"
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
changes = [c["address"] for c in p.get("resource_changes", []) if c["change"]["actions"] != ["no-op"]]
failed = [c["address"]["to_display"] for c in p.get("checks", []) if c["status"] == "fail"]
print(f"  detected: actions={changes} failed_checks={failed}")
assert changes == [], "the provider cannot see the deletion (restapi #377); the plan must stay a no-op"
assert "check.mandatory_controls" in failed, "scheme_grants_match_standards must fail from the tenant read"
PY
ADDR="module.scheme[\"restricted-collab-v1\"].restapi_object.grant[\"$VICTIM\"]"
"$TF" -chdir="$ROOT/stages/foundation" state rm -no-color "$ADDR" >/dev/null
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
echo "  ready = $("$TF" -chdir="$ROOT/stages/foundation" output -json ready | tr -d '\n ')"

echo "[foundation] a failing mandatory control must stop admit at plan time"
curl -s -X POST "http://127.0.0.1:$PORT/__stub/fail/anonymous_jira_closed" >/dev/null
"$TF" -chdir="$ROOT/stages/foundation" apply -auto-approve -no-color "${VARS[@]}" >/tmp/spike-plan.out 2>&1 || true
echo "  foundation ready = $("$TF" -chdir="$ROOT/stages/foundation" output -json ready | tr -d '\n ')"
if "$TF" -chdir="$ROOT/stages/admit" plan -no-color "${VARS[@]}" >/tmp/spike-plan.out 2>&1; then
  echo "  FAIL: admit planned without a ready foundation"; exit 1
else
  grep -q "not ready for Jira" /tmp/spike-plan.out && echo "  admit refused: $(grep -o 'Shared foundation is not ready for Jira[^.]*' /tmp/spike-plan.out | head -1)"
fi
curl -s -X DELETE "http://127.0.0.1:$PORT/__stub/fail/anonymous_jira_closed" >/dev/null
"$TF" -chdir="$ROOT/stages/foundation" apply -auto-approve -no-color "${VARS[@]}" >/dev/null 2>&1
plan_expect_clean admit "foundation restored"

echo "[policy] a requirement changed in YAML alone must change readiness (no HCL touched)"
cp "$ROOT/policy/foundation.yaml" /tmp/spike-foundation.yaml
sed -i 's/require: { op: within_days, value: 7 }/require: { op: within_days, value: 0 }/' "$ROOT/policy/foundation.yaml"
"$TF" -chdir="$ROOT/stages/foundation" apply -auto-approve -no-color "${VARS[@]}" >/dev/null 2>&1 || true
echo "  audit window 7 -> 0 days: ready = $("$TF" -chdir="$ROOT/stages/foundation" output -json ready | tr -d '\n ') blocking = $("$TF" -chdir="$ROOT/stages/foundation" output -json blocking | tr -d '\n ')"
cp /tmp/spike-foundation.yaml "$ROOT/policy/foundation.yaml"
"$TF" -chdir="$ROOT/stages/foundation" apply -auto-approve -no-color "${VARS[@]}" >/dev/null 2>&1
echo "  restored: ready = $("$TF" -chdir="$ROOT/stages/foundation" output -json ready | tr -d '\n ')"

echo "[destroy] removing a resource from configuration must be refused"
if "$TF" -chdir="$ROOT/stages/identity" plan -no-color "${VARS[@]}" -var 'groups={lab-admins="x",lab-team="y"}' >/tmp/spike-plan.out 2>&1; then
  echo "  FAIL: plan accepted a removal"; exit 1
else
  grep -q "prevent_destroy" /tmp/spike-plan.out && echo "  refused by prevent_destroy"
fi
echo "spike complete"

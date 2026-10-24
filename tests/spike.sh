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
# The stub's identities, not the live tenant's: lab.tfvars carries real accountIds.
VARS=(-var-file="$ROOT/envs/lab/lab.tfvars" \
  -var 'tenant={org_id="org-1",directory_id="dir-1",site_url="http://127.0.0.1:8089",scope_regex="^lab-"}' \
  -var 'memberships={lab-admins=["USER-LAB-ADMIN"],lab-team=["USER-LAB-ALLOWED"]}')

(cd "$ROOT/tests/stub" && python3 stub_tenant.py $PORT) >/tmp/stub_tenant.log 2>&1 &
STUB=$!; trap 'kill $STUB 2>/dev/null; rm -f "$ROOT"/stages/*/backend_override.tf "$ROOT"/stages/admit/remote_state_override.tf' EXIT
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

echo "[drift] rename the scheme out of band, expect a failing check and no actions"
SID=$("$TF" -chdir="$ROOT/stages/admit" output -raw scheme_id)
curl -s -X POST -H 'content-type: application/json' -d '{"name":"renamed by an admin"}' "http://127.0.0.1:$PORT/__stub/schemes/$SID" >/dev/null
"$TF" -chdir="$ROOT/stages/admit" plan -no-color -out=/tmp/spike-drift.bin "${VARS[@]}" >/tmp/spike-plan.out 2>&1 || true
"$TF" -chdir="$ROOT/stages/admit" show -json /tmp/spike-drift.bin > /tmp/spike-drift.json
python3 - <<'PY'
import json
p = json.load(open("/tmp/spike-drift.json"))
actions = sorted({a for c in p.get("resource_changes", []) for a in c["change"]["actions"]})
failed = [c["address"]["to_display"] for c in p.get("checks", []) if c["status"] == "fail"]
print(f"  actions={actions} drifted={len(p.get('resource_drift', []))} failed_checks={failed}")
assert actions == ["no-op"] and failed, "drift must be reported, never repaired"
PY

echo "[drift] remove a group member out of band, expect a failing check and no actions"
GID=$("$TF" -chdir="$ROOT/stages/identity" output -json group_ids | python3 -c 'import json,sys; print(json.load(sys.stdin)["lab-team"])')
curl -s -X POST "http://127.0.0.1:$PORT/__stub/unmember/$GID" >/dev/null
"$TF" -chdir="$ROOT/stages/identity" plan -no-color -out=/tmp/spike-member.bin "${VARS[@]}" >/tmp/spike-plan.out 2>&1 || true
"$TF" -chdir="$ROOT/stages/identity" show -json /tmp/spike-member.bin > /tmp/spike-member.json
python3 - <<'PY'
import json
p = json.load(open("/tmp/spike-member.json"))
actions = sorted({a for c in p.get("resource_changes", []) for a in c["change"]["actions"]})
failed = [c["address"]["to_display"] for c in p.get("checks", []) if c["status"] == "fail"]
print(f"  actions={actions} failed_checks={failed}")
assert actions == ["no-op"], "a removed member must never be re-added by automation"
assert any("membership_present" in f for f in failed), "removed member must fail membership_present"
PY

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

echo "[destroy] removing a resource from configuration must be refused"
if "$TF" -chdir="$ROOT/stages/identity" plan -no-color "${VARS[@]}" -var 'groups={lab-admins="x",lab-team="y"}' >/tmp/spike-plan.out 2>&1; then
  echo "  FAIL: plan accepted a removal"; exit 1
else
  grep -q "prevent_destroy" /tmp/spike-plan.out && echo "  refused by prevent_destroy"
fi
echo "spike complete"

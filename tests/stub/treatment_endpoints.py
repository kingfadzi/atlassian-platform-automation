"""Jira and JSM endpoints behind the asset-treatment service: project, issue types and schemes,
custom fields, request types, issue search, the Asset workflow. Shapes follow the OpenAPI
documents. Test double only."""

from pathlib import Path

import yaml
from flask import Blueprint, jsonify, request

from state import db, failing, ids

treatment = Blueprint("treatment", __name__)
ROOT = Path(__file__).resolve().parents[2]
for k in ("issue_types", "scheme_types", "fields", "request_types", "issues"):
    db.setdefault(k, {})
db["issue_types"].setdefault(10001, {"id": "10001", "name": "Task", "description": "", "subtask": False})
SCHEME = 10100          # the one issue type scheme every stub project gets


@treatment.get("/rest/api/3/workflow/search")
def workflow_search():
    """Built from jsm/asset-workflow.yaml so the stub cannot drift from the declaration it serves.
    Forcing asset_workflow_gaps drops one transition, as an operator who stopped halfway would."""
    declared = yaml.safe_load((ROOT / "jsm" / "asset-workflow.yaml").read_text())
    sid = {s["name"]: str(i) for i, s in enumerate(declared["statuses"], 1)}
    live = [t for t in declared["transitions"]
            if not ("asset_workflow_gaps" in failing and (t["from"], t["name"]) == ("Active", "Archive"))]
    return jsonify({"values": [{
        "id": {"name": declared["name"]},
        "statuses": [{"id": i, "name": n} for n, i in sid.items()],
        "transitions": [{"id": str(j), "name": t["name"], "type": "directed",
                         "from": [sid[t["from"]]], "to": sid[t["to"]]}
                        for j, t in enumerate(live, 1)],
    }]})


@treatment.post("/rest/api/3/project")
def create_project():
    body = request.get_json()
    project = {"id": next(ids), "key": body["key"], "name": body["name"], "projectTypeKey": body["projectTypeKey"],
               "style": "classic", "lead": {"accountId": body["leadAccountId"]}, "self": "x", "_scheme": body.get("permissionScheme", 0)}
    db["projects"][project["key"]] = project
    db["scheme_types"].setdefault(SCHEME, ["10001"])
    return jsonify({"id": project["id"], "key": project["key"], "self": "x"}), 201


@treatment.get("/rest/api/3/project/<key>")
def get_project(key):
    project = next((p for p in db["projects"].values() if key in (p["key"], str(p["id"]))), None)
    return (jsonify({k: v for k, v in project.items() if k != "_scheme"}), 200) if project else ("", 404)


@treatment.get("/rest/api/3/issuetype")
def list_issue_types():
    return jsonify(list(db["issue_types"].values()))


@treatment.post("/rest/api/3/issuetype")
def create_issue_type():
    body = request.get_json()
    t = {"id": str(next(ids)), "name": body["name"], "description": body.get("description", ""), "subtask": False, "self": "x"}
    db["issue_types"][int(t["id"])] = t
    return jsonify(t), 201


@treatment.get("/rest/api/3/issuetype/<int:tid>")
def get_issue_type(tid):
    t = db["issue_types"].get(tid)
    return (jsonify(t), 200) if t else ("", 404)


@treatment.get("/rest/api/3/issuetypescheme/project")
def scheme_for_project():
    return jsonify({"values": [{"issueTypeScheme": {"id": str(SCHEME), "name": "ATS: Scheme"}, "projectIds": [request.args.get("projectId")]}], "isLast": True})


@treatment.put("/rest/api/3/issuetypescheme/<int:sid>/issuetype")
def add_to_scheme(sid):
    types = db["scheme_types"].setdefault(sid, [])
    types.extend(t for t in request.get_json()["issueTypeIds"] if t not in types)
    return ("", 204)


@treatment.get("/rest/api/3/issuetypescheme/mapping")
def scheme_mapping():
    sid = int(request.args.get("issueTypeSchemeId"))
    return jsonify({"values": [{"issueTypeSchemeId": str(sid), "issueTypeId": t} for t in db["scheme_types"].get(sid, [])], "isLast": True})


@treatment.get("/rest/api/3/field")
def list_fields():
    system = [{"id": "summary", "name": "Summary", "custom": False}]
    return jsonify(system + list(db["fields"].values()))


@treatment.post("/rest/api/3/field")
def create_field():
    body = request.get_json()
    f = {"id": f"customfield_{next(ids)}", "name": body["name"], "description": body.get("description", ""), "custom": True,
         "schema": {"type": "string", "custom": body["type"]}, "searcherKey": body.get("searcherKey")}
    db["fields"][f["id"]] = f
    return jsonify(f), 201


@treatment.get("/rest/api/3/field/search")
def search_fields():
    wanted = request.args.get("id")
    values = [f for f in db["fields"].values() if not wanted or f["id"] == wanted]
    return jsonify({"values": values, "total": len(values), "isLast": True})


@treatment.get("/rest/servicedeskapi/servicedesk/<desk>/requesttype")
def list_request_types(desk):
    values = [r for r in db["request_types"].values() if r["_desk"] == desk]
    return jsonify({"values": [{k: v for k, v in r.items() if k != "_desk"} for r in values], "size": len(values), "isLastPage": True})


@treatment.post("/rest/servicedeskapi/servicedesk/<desk>/requesttype")
def create_request_type(desk):
    body = request.get_json()
    r = {"id": str(next(ids)), "name": body["name"], "description": body.get("description", ""), "helpText": body.get("helpText", ""),
         "issueTypeId": body["issueTypeId"], "serviceDeskId": desk, "_desk": desk}
    db["request_types"][r["id"]] = r
    return jsonify({k: v for k, v in r.items() if k != "_desk"}), 201


@treatment.get("/rest/servicedeskapi/servicedesk/<desk>/requesttype/<rid>")
def get_request_type(desk, rid):
    r = db["request_types"].get(rid)
    return (jsonify({k: v for k, v in r.items() if k != "_desk"}), 200) if r and r["_desk"] == desk else ("", 404)


@treatment.get("/rest/api/3/search/jql")
def search_issues():
    fields = request.args.get("fields", "").split(",")
    issues = [{"id": i["id"], "key": i["key"], "fields": {f: i["fields"].get(f) for f in fields}} for i in db["issues"].values()]
    return jsonify({"issues": issues, "isLast": True})


# Test control: an Asset record as the onboarding request would leave it.
@treatment.post("/__stub/seed/asset")
def seed_asset():
    body = request.get_json()
    issue = {"id": str(next(ids)), "key": f"ATS-{len(db['issues']) + 1}", "fields": body["fields"]}
    db["issues"][issue["key"]] = issue
    return jsonify({"key": issue["key"]})

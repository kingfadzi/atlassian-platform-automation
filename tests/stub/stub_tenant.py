"""Stateful stub of the Atlassian endpoints the modules use, with the real response shapes.
Test double only. Run: python tests/stub/stub_tenant.py 8089  (STUB_SHUFFLE=1 reverses grant order)."""

import os
import sys

from flask import Flask, jsonify, request

from foundation_endpoints import foundation
from state import DIRECTORY, caller, caller_account, caller_groups, db, failing, ids

app = Flask(__name__)
# Admin API
@app.get("/admin/v1/orgs/<org>")
def get_org(org):
    return jsonify({"data": {"id": org, "type": "orgs", "attributes": {"name": "Lab Org"}}})


@app.get("/admin/v2/orgs/<org>/directories")
def directories(org):
    return jsonify({"data": [{"directoryId": DIRECTORY, "name": "Default"}], "links": {}})


@app.post("/admin/v2/orgs/<org>/workspaces")
def workspaces(org):
    host = request.host_url.rstrip("/")
    return jsonify({"data": [{"id": "ws-1", "attributes": {"typeKey": "jira-software", "hostUrl": host}},
                             {"id": "ws-2", "attributes": {"typeKey": "confluence", "hostUrl": host}}], "links": {}})


@app.get("/admin/v2/orgs/<org>/directories/<directory>/groups")
def search_groups(org, directory):
    term = request.args.get("searchTerm", "")
    found = [g for g in db["groups"].values() if term.lower() in g["name"].lower()]
    return jsonify({"data": found, "links": {"self": "x"}})


@app.post("/admin/v2/orgs/<org>/directories/<directory>/groups")
def create_group(org, directory):
    body = request.get_json()
    group = {"id": f"g-{next(ids)}", "name": body["name"], "description": body.get("description", ""),
             "directoryId": directory, "managementAccess": {"deletable": True, "modifiable": True, "readable": True},
             "externalSynced": False, "managedBy": "atlassian", "counts": {"users": 0, "resources": 0}}
    db["groups"][group["id"]] = group
    return ("", 201)                                  # real API documents 201 "Success" with no body


@app.get("/admin/v2/orgs/<org>/directories/<directory>/groups/<gid>")
def get_group(org, directory, gid):
    group = db["groups"].get(gid)
    return (jsonify({"data": group}), 200) if group else ("", 404)

# Jira
@app.get("/rest/api/3/myself")
def myself():
    return jsonify({"accountId": "acc-admin", "active": True, "displayName": "Lab Admin"})


def grant(body):
    holder = {**body["holder"], "value": "gid-" + body["holder"]["parameter"], "expand": "group"}
    return {"id": next(ids), "self": "x", "permission": body["permission"], "holder": holder}


@app.post("/rest/api/3/permissionscheme")
def create_scheme():
    body = request.get_json()
    scheme = {"id": next(ids), "name": body["name"], "description": body.get("description", ""), "self": "x",
              "permissions": [grant(p) for p in body.get("permissions", [])]}
    db["schemes"][scheme["id"]] = scheme
    return jsonify(scheme), 201


@app.get("/rest/api/3/permissionscheme/<int:sid>")
def get_scheme(sid):
    scheme = db["schemes"].get(sid)
    if not scheme:
        return ("", 404)
    perms = list(reversed(scheme["permissions"])) if os.environ.get("STUB_SHUFFLE") else scheme["permissions"]
    return jsonify({**scheme, "permissions": perms})


@app.post("/rest/api/3/permissionscheme/<int:sid>/permission")
def create_grant(sid):
    new = grant(request.get_json())
    db["schemes"][sid]["permissions"].append(new)
    return jsonify(new), 201


@app.get("/rest/api/3/permissionscheme/<int:sid>/permission/<int:pid>")
def get_grant(sid, pid):
    found = next((p for p in db["schemes"][sid]["permissions"] if p["id"] == pid), None)
    return (jsonify(found), 200) if found else ("", 404)


@app.post("/rest/api/3/group/user")
def add_group_member():
    gid = request.args.get("groupId", "")
    if gid not in db["groups"]:
        return ("", 404)
    members = db["group_members"].setdefault(gid, [])
    account = request.get_json()["accountId"]
    if account not in members:
        members.append(account)
    return jsonify(db["groups"][gid])                 # real API answers with the group, not the membership


@app.get("/rest/api/3/group/member")
def list_group_members():
    members = db["group_members"].get(request.args.get("groupId", ""), [])
    return jsonify({"values": [{"accountId": a, "active": True, "accountType": "atlassian"} for a in members],
                    "startAt": 0, "maxResults": 200, "total": len(members), "isLast": True})


@app.post("/rest/api/3/project")
def create_project():
    body = request.get_json()
    project = {"id": next(ids), "key": body["key"], "name": body["name"], "projectTypeKey": body["projectTypeKey"],
               "assigneeType": body.get("assigneeType"), "description": body.get("description", ""),
               "lead": {"accountId": body["leadAccountId"]}, "self": "x", "simplified": False, "style": "classic"}
    db["projects"][project["key"]] = {**project, "_scheme": body["permissionScheme"]}
    return jsonify({"id": project["id"], "key": project["key"], "self": "x"}), 201


@app.get("/rest/api/3/project/<key>")
def get_project(key):
    if caller_account() is None:
        return ("", 401)
    project = next((p for p in db["projects"].values() if key in (p["key"], str(p["id"]))), None)
    if not project:
        return ("", 404)
    scheme = db["schemes"].get(project["_scheme"], {})
    audience = {g["holder"].get("parameter") for g in scheme.get("permissions", [])}
    if not caller_groups() & audience:
        return ("", 404)                              # Jira hides projects the caller cannot browse
    return jsonify({k: v for k, v in project.items() if k != "_scheme"})


@app.get("/rest/api/3/project/<key>/permissionscheme")
def project_scheme(key):
    project = next((p for p in db["projects"].values() if key in (p["key"], str(p["id"]))), None)
    return jsonify(db["schemes"][project["_scheme"]]) if project else ("", 404)

# Confluence
@app.get("/wiki/rest/api/user/current")
def current_user():
    return jsonify({"accountId": "acc-admin", "type": "known"})


@app.post("/wiki/rest/api/space/_private")
def create_space():
    body = request.get_json()
    space = {"id": next(ids), "key": body["key"], "name": body["name"], "type": "global", "status": "current"}
    db["spaces"][space["id"]] = space
    return jsonify(space)


@app.get("/wiki/api/v2/spaces/<int:sid>")
def get_space(sid):
    space = db["spaces"].get(sid)
    return (jsonify({**space, "homepageId": "1", "authorId": "acc-admin"}), 200) if space else ("", 404)


@app.get("/wiki/api/v2/spaces")
def list_spaces():
    keys = request.args.get("keys", "").split(",")
    if caller() == "anonymous" and "anonymous_confluence_closed" in failing:
        return jsonify({"results": [{"id": "9", "key": "PUB", "name": "Public"}], "_links": {}})
    groups = caller_groups()
    visible = [s for s in db["spaces"].values() if (s["key"] in keys or not keys[0])
               and groups & {p["subject"]["identifier"] for p in db["space_perms"].get(s["key"], [])}]
    return jsonify({"results": visible, "_links": {}})


@app.post("/wiki/rest/api/space/<key>/permission")
def add_permission(key):
    body = request.get_json()
    perm = {"id": next(ids), "subject": body["subject"], "operation": body["operation"]}
    db["space_perms"].setdefault(key, []).append(perm)
    return jsonify(perm)


@app.get("/wiki/api/v2/spaces/<int:sid>/permissions")
def space_permissions(sid):
    space = db["spaces"].get(sid)
    perms = db["space_perms"].get(space["key"], []) if space else []
    return jsonify({"results": [{"id": str(p["id"]), "principal": {"type": p["subject"]["type"], "id": p["subject"]["identifier"]},
                                 "operation": {"key": p["operation"]["key"], "targetType": p["operation"]["target"]}} for p in perms],
                    "_links": {}})


# Test control (not an Atlassian endpoint): mutate stored objects to simulate out-of-band drift.
@app.post("/__stub/<collection>/<key>")
def mutate(collection, key):
    key = int(key) if key.isdigit() else key
    db[collection][key].update(request.get_json())
    return jsonify(db[collection][key])


@app.post("/__stub/unmember/<gid>")
def unmember(gid):
    """Test control: empty a group's membership to simulate an out-of-band removal."""
    db["group_members"][gid] = []
    return jsonify(db["group_members"])


@app.get("/__stub/dump")
def dump():
    return jsonify({k: list(v.values()) if isinstance(v, dict) else v for k, v in db.items()})


app.register_blueprint(foundation)

if __name__ == "__main__":
    app.run(port=int(sys.argv[1]) if len(sys.argv) > 1 else 8089)

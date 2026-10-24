"""Stateful stub of the Atlassian endpoints the modules use, with the real response shapes.
Test double only. Run: python tests/stub/stub_tenant.py 8089  (STUB_SHUFFLE=1 reverses grant order)."""

import os
import sys

from flask import Flask, jsonify, request

from foundation_endpoints import default_scheme, foundation
from provision_endpoints import provision
from estate_endpoints import estate
from state import DIRECTORY, caller, db, failing, ids

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


# Jira
@app.get("/rest/api/3/myself")
def myself():
    return jsonify({"accountId": "acc-admin", "active": True, "displayName": "Lab Admin"})


def grant(body):
    kind = body["holder"]["type"]
    holder = {**body["holder"], "value": f"{kind}-" + str(body["holder"]["parameter"]), "expand": "group" if kind == "group" else "projectRole"}
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


@app.get("/rest/api/3/project/<key>/permissionscheme")
def project_scheme(key):
    project = next((p for p in db["projects"].values() if key in (p["key"], str(p["id"]))), None)
    if not project:
        return ("", 404)
    return jsonify(db["schemes"].get(project["_scheme"]) or default_scheme())

# Confluence
@app.get("/wiki/rest/api/user/current")
def current_user():
    return jsonify({"accountId": "acc-admin", "type": "known"})


@app.get("/wiki/api/v2/spaces")
def list_spaces():
    keys = request.args.get("keys", "").split(",")
    if caller() == "anonymous" and "anonymous_confluence_closed" in failing:
        return jsonify({"results": [{"id": "9", "key": "PUB", "name": "Public"}], "_links": {}})
    visible = [] if caller() in ("anonymous", "denied") else [s for s in db["spaces"].values() if s["key"] in keys or not keys[0]]
    return jsonify({"results": visible, "_links": {}})


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


@app.get("/__stub/dump")
def dump():
    return jsonify({k: list(v.values()) if isinstance(v, dict) else v for k, v in db.items()})


app.register_blueprint(foundation)
app.register_blueprint(provision)
app.register_blueprint(estate)

if __name__ == "__main__":
    app.run(port=int(sys.argv[1]) if len(sys.argv) > 1 else 8089)

"""Endpoints behind the provisioned foundation (roles, role actors, admin groups, space roles).
Shapes follow the Jira and Confluence OpenAPI documents. Test double only."""

from flask import Blueprint, jsonify, request

from state import db, failing, ids

provision = Blueprint("provision", __name__)
db.setdefault("roles", {})
db.setdefault("role_actors", {})       # (project key, role id) -> [group names]
ADMIN_GROUPS = {"site-admins": ["USER-LAB-ADMIN", "USER-LAB-ENGINE"], "org-admins": ["USER-LAB-ADMIN"]}


@provision.get("/rest/api/3/role")
def list_roles():
    builtin = [{"id": 2, "name": "Administrators", "self": "x"}, {"id": 3, "name": "atlassian-addons-project-access", "self": "x"}]
    return jsonify(builtin + list(db["roles"].values()))


@provision.post("/rest/api/3/role")
def create_role():
    body = request.get_json()
    role = {"id": next(ids), "name": body["name"], "description": body.get("description", ""), "self": "x", "actors": []}
    db["roles"][role["id"]] = role
    return jsonify(role), 200


@provision.get("/rest/api/3/role/<int:rid>")
def get_role(rid):
    role = db["roles"].get(rid)
    return (jsonify(role), 200) if role else ("", 404)


@provision.get("/rest/api/3/project/<key>/role/<int:rid>")
def get_project_role(key, rid):
    if rid not in db["roles"]:
        return ("", 404)
    return jsonify(project_role(key, rid))


def project_role(key, rid):
    role = db["roles"][rid]
    actors = [{"id": i, "displayName": g.removeprefix("user:"), "name": g, "type": "atlassian-user-role-actor" if g.startswith("user:") else "atlassian-group-role-actor"}
              for i, g in enumerate(db["role_actors"].get((key, rid), []))]
    return {"id": rid, "name": role["name"], "description": role["description"], "self": "x", "actors": actors}


@provision.get("/rest/api/3/group/member")
def group_members():
    name = request.args.get("groupname", "")
    members = list(ADMIN_GROUPS.get(name, []))
    if "admins_are_listed" in failing:
        members.append("USER-UNLISTED")
    return jsonify({"values": [{"accountId": m, "active": True} for m in members], "total": len(members), "isLast": True})


@provision.get("/wiki/api/v2/space-roles")
def space_roles():
    names = [] if "confluence_space_roles_present" in failing else ["Admin", "Manager", "Collaborator", "Viewer"]
    return jsonify({"results": [{"id": str(i), "name": n, "type": "system"} for i, n in enumerate(names)], "_links": {}})

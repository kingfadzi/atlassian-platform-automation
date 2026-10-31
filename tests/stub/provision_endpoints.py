"""Endpoints behind the provisioned foundation (roles, role actors, admin groups, space roles).
Shapes follow the Jira and Confluence OpenAPI documents. Test double only."""

from flask import Blueprint, jsonify, request

from state import db, failing, ids

provision = Blueprint("provision", __name__)
db.setdefault("roles", {})
db.setdefault("role_actors", {})       # (project key, role id) -> [group names]
ADMIN_GROUPS = {"site-admins": ["USER-LAB-ADMIN", "USER-LAB-ENGINE"], "org-admins": ["USER-LAB-ADMIN"]}
# Global permissions each declared account holds, within what policy/identities.yaml allows its kind.
HELD = {"USER-LAB-ADMIN": ["ADMINISTER", "CREATE_PROJECT", "CREATE_SHARED_OBJECTS", "BULK_CHANGE", "USER_PICKER"],
        "USER-LAB-ENGINE": ["ADMINISTER", "CREATE_PROJECT"],
        "USER-LAB-BREAKGLASS": ["ADMINISTER"]}


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


@provision.post("/rest/api/3/permissions/check")
def permissions_check():
    """Bulk permission check. Honours accountId, so an admin can ask what any account holds;
    404 for an account Jira does not know. Forcing the control gives the engine SYSTEM_ADMIN."""
    body = request.get_json(silent=True) or {}
    account = body.get("accountId")
    if account not in HELD:
        return jsonify({"errorMessages": ["The specified user does not exist."], "errors": {}}), 404
    held = list(HELD[account])
    if "account_global_permissions" in failing and account == "USER-LAB-ENGINE":
        held.append("SYSTEM_ADMIN")
    asked = set(body.get("globalPermissions") or [])
    return jsonify({"projectPermissions": [], "globalPermissions": [p for p in held if p in asked]})


@provision.get("/wiki/api/v2/space-roles")
def space_roles():
    names = [] if "confluence_space_roles_present" in failing else ["Admin", "Manager", "Collaborator", "Viewer"]
    return jsonify({"results": [{"id": str(i), "name": n, "type": "system"} for i, n in enumerate(names)], "_links": {}})

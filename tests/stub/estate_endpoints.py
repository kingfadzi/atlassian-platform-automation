"""Instances as stages/conform sees them, and a seed endpoint that plays JSM: it creates a project
or space the way a request would, with deliberate defects for the spike. Test double only."""

from flask import Blueprint, jsonify, request

from state import caller, db, failing, ids

estate = Blueprint("estate", __name__)
for k in ("project_props", "project_meta", "space_labels", "space_roles", "space_pages"):
    db.setdefault(k, {})


@estate.get("/rest/api/3/project/search")
def search_projects():
    if caller() == "anonymous":   # the foundation's anonymous probe
        public = [{"id": "1", "key": "PUB", "name": "Public"}] if "anonymous_jira_closed" in failing else []
        return jsonify({"values": public, "total": len(public), "isLast": True})
    values = []
    for p in db["projects"].values():
        meta = db["project_meta"].get(p["key"], {})
        # Forcing the control reassigns the treatment desk's lead, as a console change would.
        lead = p["lead"]["accountId"]
        if "treatment_lead_is_service_account" in failing and p["key"] == "ATS":
            lead = "USER-LAB-ADMIN"
        values.append({**{k: v for k, v in p.items() if k != "_scheme"},
                       "lead": {"accountId": lead, "active": meta.get("lead_active", True)},
                       "insight": {"totalIssueCount": 1, "lastIssueUpdateTime": meta.get("last_activity", "2026-10-20T00:00:00.000+0000")},
                       "properties": db["project_props"].get(p["key"], {})})
    return jsonify({"values": values, "total": len(values), "isLast": True})


@estate.get("/rest/api/3/project/<key>/properties/<prop>")
def project_property(key, prop):
    props = db["project_props"].get(key, {})
    return (jsonify({"key": prop, "value": props[prop]}), 200) if prop in props else ("", 404)


@estate.get("/wiki/api/v2/spaces/<int:sid>/labels")
def space_labels(sid):
    space = db["spaces"].get(sid)
    names = db["space_labels"].get(space["key"], []) if space else []
    return jsonify({"results": [{"id": str(i), "name": n, "prefix": "global"} for i, n in enumerate(names)], "_links": {}})


@estate.get("/wiki/api/v2/spaces/<int:sid>/role-assignments")
def space_role_assignments(sid):
    space = db["spaces"].get(sid)
    rows = db["space_roles"].get(space["key"], []) if space else []
    return jsonify({"results": [{"principal": {"type": "group", "id": g}, "roleId": rid} for rid, g in rows], "_links": {}})


@estate.get("/wiki/api/v2/spaces/<int:sid>/pages")
def space_pages(sid):
    space = db["spaces"].get(sid)
    when = db["space_pages"].get(space["key"]) if space else None
    results = [{"id": "1", "title": "Home", "version": {"number": 1, "createdAt": when}}] if when else []
    return jsonify({"results": results, "_links": {}})


# Test control (not an Atlassian endpoint): seed an instance as JSM would create it.
@estate.post("/__stub/seed/instance")
def seed_instance():
    body = request.get_json()
    return jsonify(seed_project(body) if body["kind"] == "jira" else seed_space(body))


def seed_project(b):
    key = b["key"]
    db["projects"][key] = {"id": next(ids), "key": key, "name": b.get("name", key), "projectTypeKey": "software", "style": "classic",
                           "lead": {"accountId": b.get("lead", "USER-LAB-OWNER")}, "self": "x", "simplified": False, "_scheme": int(b["scheme_id"])}
    if b.get("stamp"):
        db["project_props"][key] = {"platform.standard": b["stamp"]}
    db["project_meta"][key] = {"lead_active": b.get("lead_active", True), "last_activity": b.get("last_activity", "2026-10-20T00:00:00.000+0000")}
    for role_id, groups in b.get("roles", {}).items():
        db["role_actors"][(key, int(role_id))] = list(groups)
    for role_id, users in b.get("user_actors", {}).items():
        db["role_actors"].setdefault((key, int(role_id)), []).extend(f"user:{u}" for u in users)
    return {"key": key}


def seed_space(b):
    key = b["key"]
    space = {"id": next(ids), "key": key, "name": b.get("name", key), "type": "global", "status": "current"}
    db["spaces"][space["id"]] = space
    db["space_labels"][key] = [f"platform-standard-{b['stamp']}"] if b.get("stamp") else []
    db["space_roles"][key] = [(rid, g) for rid, g in b.get("roles", [])]
    db["space_pages"][key] = b.get("last_activity", "2026-10-20T00:00:00Z")
    db["space_perms"][key] = [{"id": next(ids), "subject": {"type": t, "identifier": i}, "operation": {"key": "read", "target": "space"}}
                              for t, i in b.get("principals", [])]
    return {"key": key}

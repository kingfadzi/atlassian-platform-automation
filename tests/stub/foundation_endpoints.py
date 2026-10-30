"""Foundation observation endpoints for the stub tenant (shapes from the OpenAPI documents).

Any control can be forced to fail: POST /__stub/fail/<control_id>; DELETE to restore.
"""

from datetime import datetime, timedelta, timezone

from flask import Blueprint, jsonify

from state import caller, db, failing

foundation = Blueprint("foundation", __name__)


def default_scheme():
    """Jira's built-in scheme: browse for every licensed user. Projects JSM did not create sit on it."""
    default = {"id": 0, "name": "Default Permission Scheme", "permissions": [
        {"id": 1, "permission": "BROWSE_PROJECTS", "holder": {"type": "applicationRole"}}]}
    if "no_public_scheme_grants" in failing:
        default["permissions"].append({"id": 2, "permission": "BROWSE_PROJECTS", "holder": {"type": "anyone"}})
    return default


@foundation.get("/rest/api/3/permissionscheme")
def list_schemes():
    return jsonify({"permissionSchemes": [default_scheme()] + list(db["schemes"].values())})


@foundation.get("/admin/v1/orgs/<org>/events")
def org_events(org):
    age = timedelta(days=30) if "audit_collection_live" in failing else timedelta(hours=1)
    when = (datetime.now(timezone.utc) - age).strftime("%Y-%m-%dT%H:%M:%S.000Z")
    return jsonify({"data": [{"id": "e1", "type": "events", "attributes": {"time": when, "action": "user_login"}}], "meta": {}, "links": {}})


@foundation.get("/rest/api/3/applicationrole")
def application_roles():
    return jsonify([{"key": "jira-software", "defaultGroups": ["jira-software-users"]}])


@foundation.get("/admin/v1/orgs/<org>/domains")
def domains(org):
    """Every TLD an organisation has claimed. Guard manages only accounts whose address sits in
    one of these, so an estate spanning several TLDs has to verify each."""
    names = ["lab.example"] if "verified_domains_known" in failing else ["lab.example", "lab.test"]
    return jsonify({"data": [{"id": f"d{i}", "type": "domains",
                              "attributes": {"name": n, "claim": {"status": "verified"}}}
                             for i, n in enumerate(names, 1)]})


@foundation.get("/admin/v1/orgs/<org>/policies")
def policies(org):
    enabled = "disabled" if "org_policies_enabled" in failing else "enabled"
    return jsonify({"data": [{"id": "p1", "type": "policy", "attributes": {"type": "data-residency", "name": "EU", "status": enabled}}]})


@foundation.get("/wiki/rest/api/audit/retention")
def audit_retention():
    return jsonify({"number": 30 if "confluence_audit_retention" in failing else 1, "units": "DAYS" if "confluence_audit_retention" in failing else "YEARS"})


@foundation.get("/rest/api/3/announcementBanner")
def banner():
    return jsonify({"hashId": "x", "isDismissible": False, "isEnabled": True, "message": "Lab tenant: governed estate", "visibility": "private"})


@foundation.post("/__stub/fail/<control>")
def fail_control(control):
    failing.add(control)
    return jsonify(sorted(failing))


@foundation.delete("/__stub/fail/<control>")
def unfail_control(control):
    failing.discard(control)
    return jsonify(sorted(failing))

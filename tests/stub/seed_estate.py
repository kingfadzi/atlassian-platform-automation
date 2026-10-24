"""Plays JSM for the spike: seeds instances into the stub from the foundation's contract.
Usage: seed_estate.py <port> <contract.json>. One conforming project and space; the rest carry
one defect each so every conformance control is exercised."""

import json
import sys
import urllib.request

port, contract = sys.argv[1], json.load(open(sys.argv[2]))
std = contract["standards"]["restricted-collab-v1"]
roles, scheme = std["roles"], std["scheme_id"]
STAMP, OLD = "restricted-collab-v1", "2025-01-01T00:00:00.000+0000"
ok_roles = {roles["admin"]: ["lab-admins"], roles["member"]: ["lab-team"]}

instances = [
    {"kind": "jira", "key": "LABOK", "stamp": STAMP, "scheme_id": scheme, "roles": ok_roles},
    {"kind": "jira", "key": "LABUSR", "stamp": STAMP, "scheme_id": scheme, "roles": ok_roles, "user_actors": {roles["member"]: ["Some Person"]}},
    {"kind": "jira", "key": "LABNST", "scheme_id": scheme, "roles": ok_roles},
    {"kind": "jira", "key": "LABOLD", "stamp": STAMP, "scheme_id": scheme, "roles": ok_roles, "last_activity": OLD},
    {"kind": "jira", "key": "LABNOA", "stamp": STAMP, "scheme_id": scheme, "roles": {roles["member"]: ["lab-team"]}},
    {"kind": "jira", "key": "LABEXT", "stamp": STAMP, "scheme_id": scheme, "roles": {roles["admin"]: ["lab-admins"], roles["member"]: ["finance-all"]}},
    {"kind": "jira", "key": "LABFOR", "scheme_id": 0, "roles": ok_roles},                      # default scheme: public browse, not the standard's
    {"kind": "confluence", "key": "LABOK", "stamp": STAMP, "roles": [["0", "lab-admins"], ["2", "lab-team"]]},
    {"kind": "confluence", "key": "LABPUB", "stamp": STAMP, "roles": [["0", "lab-admins"]], "principals": [["anonymous", ""]]},
    {"kind": "confluence", "key": "LABOLDS", "roles": [["0", "lab-admins"]], "last_activity": "2025-01-01T00:00:00Z"},
]
for i in instances:
    body = json.dumps(i).encode()
    urllib.request.urlopen(urllib.request.Request(f"http://127.0.0.1:{port}/__stub/seed/instance", body, {"content-type": "application/json"}))
    print(f"seeded {i['kind']}:{i['key']}")

# Asset records exist for what went through the service: the conforming pair and one flagged project.
key_field = contract["treatment"]["field_ids"]["instance_key"]
for ref in ["jira:LABOK", "confluence:LABOK", "jira:LABUSR"]:
    body = json.dumps({"fields": {key_field: ref, "summary": ref}}).encode()
    urllib.request.urlopen(urllib.request.Request(f"http://127.0.0.1:{port}/__stub/seed/asset", body, {"content-type": "application/json"}))
    print(f"asset record {ref}")

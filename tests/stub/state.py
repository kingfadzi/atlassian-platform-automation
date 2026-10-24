"""Shared in-memory state for the stub tenant (used by stub_tenant and foundation_endpoints)."""

import base64
import itertools

from flask import request

ids = itertools.count(10000)
db = {"groups": {}, "schemes": {}, "projects": {}, "spaces": {}, "space_perms": {}}
failing = set()   # foundation control ids forced to fail via POST /__stub/fail/<id>
ORG, DIRECTORY = "org-1", "dir-1"


def caller():
    """'anonymous', 'denied' or 'member' from the Authorization header (test identities)."""
    auth = request.headers.get("Authorization", "")
    if not auth:
        return "anonymous"
    if auth.startswith("Basic "):
        email = base64.b64decode(auth[6:]).decode().split(":")[0]
        return "denied" if "denied" in email else "member"
    return "member"

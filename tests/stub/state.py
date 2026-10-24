"""Shared in-memory state for the stub tenant (used by stub_tenant and foundation_endpoints)."""

import base64
import itertools

from flask import request

ids = itertools.count(10000)
db = {"groups": {}, "group_members": {}, "schemes": {}, "projects": {}, "spaces": {}, "space_perms": {}}
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


# Test identities: Basic-auth email -> accountId, mirroring the placeholders in envs/lab/lab.tfvars.
ACCOUNTS = {"admin@lab": "USER-LAB-ADMIN", "allowed@lab": "USER-LAB-ALLOWED", "denied@lab": "USER-LAB-DENIED"}


def caller_account():
    """accountId of the authenticated caller, or None when anonymous."""
    auth = request.headers.get("Authorization", "")
    if auth.startswith("Basic "):
        email = base64.b64decode(auth[6:]).decode().split(":")[0]
        return ACCOUNTS.get(email, "USER-UNKNOWN")
    if auth.startswith("Bearer "):
        return ACCOUNTS["admin@lab"]
    return None


def caller_groups():
    """Names of the managed groups the caller is actually a member of.

    Authorisation in this stub follows real membership, so the release probes only pass when
    the identity stage has placed the account in a group that holds a grant.
    """
    account = caller_account()
    if account is None:
        return set()
    return {db["groups"][gid]["name"] for gid, members in db["group_members"].items()
            if account in members and gid in db["groups"]}

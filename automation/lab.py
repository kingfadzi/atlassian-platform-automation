"""Bounded lab provisioning. No network without --live; no automatic deletion."""

import argparse
import base64
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
import fcntl
import json
import os
from pathlib import Path
import re
import tempfile
import uuid
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, quote, urlencode, urljoin, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

from automation.check import ROOT, check, check_config, load
from policy.lab import (
    Blocked, CONTROL_REFERENCES, STANDARD_REFS, assess_inputs, assess_review, digest, require, scope, timestamp,
)


def utcnow():
    return datetime.now(timezone.utc)


class ApiError(RuntimeError):
    def __init__(self, status):
        self.status = status
        super().__init__(f"API operation failed ({status}); response body withheld")


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, *args, **kwargs):
        return None


class Http:
    """Small allowlisted HTTPS transport, not a generic connector."""

    evidence_kind = "atlassian_https"
    READ = {
        "jira": [
            r"/rest/api/3/myself", r"/rest/api/3/mypermissions",
            r"/rest/api/3/project/[A-Za-z0-9_-]+",
            r"/rest/api/3/project/[A-Za-z0-9_-]+/permissionscheme",
            r"/rest/api/3/projectvalidate/key",
            r"/rest/api/3/permissionscheme",
            r"/rest/api/3/permissionscheme/[0-9]+/permission",
        ],
        "confluence": [
            r"/wiki/rest/api/user/current", r"/wiki/api/v2/spaces",
            r"/wiki/api/v2/spaces/[0-9]+",
            r"/wiki/api/v2/spaces/[0-9]+/permissions",
            r"/wiki/api/v2/spaces/[0-9]+/operations",
        ],
    }
    WRITE = {
        "jira": [r"/rest/api/3/permissionscheme", r"/rest/api/3/project"],
        "confluence": [
            r"/wiki/rest/api/space/_private",
            r"/wiki/rest/api/space/[A-Za-z0-9]+/permission",
        ],
    }

    def __init__(self, bindings, live=False):
        require(live, "Live transport requires explicit --live")
        self.bindings = bindings
        self.opener = build_opener(NoRedirect())

    def request(self, product, role, method, path, body=None):
        if product == "organization":
            origin = "https://api.atlassian.com"
            expected = "/admin/v2/orgs/" + quote(self.bindings["organization"]["id"], safe="") + "/workspaces"
            require(method == "POST" and path == expected, "Organisation operation not allowed")
            credential = self.bindings["organization"]["credential"]
        else:
            target = self.bindings["products"][product]
            origin = target["origin"]
            require(
                re.fullmatch(r"https://[a-z0-9-]+\.atlassian\.net", origin) is not None,
                "Only declared Atlassian site origins are supported",
            )
            parsed = urlsplit(path)
            require(not parsed.scheme and not parsed.netloc and not parsed.fragment, "Unsafe API path")
            patterns = self.READ[product] if method == "GET" else self.WRITE[product]
            require(
                method in {"GET", "POST"}
                and any(re.fullmatch(pattern, parsed.path) for pattern in patterns),
                "API operation not allowed",
            )
            require(method == "GET" or role == "admin", "Only admin can mutate")
            credential = None if role == "anonymous" else target[role]["credential"]
        headers = {"Accept": "application/json"}
        if credential:
            token = os.environ.get(credential["token_env"])
            require(bool(token), "Referenced lab credential is unavailable")
            if credential["mode"] == "basic":
                email = os.environ.get(credential["email_env"])
                require(bool(email), "Referenced lab account is unavailable")
                headers["Authorization"] = "Basic " + base64.b64encode(
                    f"{email}:{token}".encode()
                ).decode()
            else:
                require(credential["mode"] == "bearer", "Unsupported credential mode")
                headers["Authorization"] = "Bearer " + token
        if body is not None:
            headers["Content-Type"] = "application/json"
        request = Request(
            origin + path,
            data=None if body is None else json.dumps(body).encode(),
            headers=headers, method=method,
        )
        try:
            with self.opener.open(request, timeout=30) as response:
                raw = response.read(5_000_001)
                require(len(raw) <= 5_000_000, "Response too large; observation incomplete")
                data = json.loads(raw) if raw else {}
                require(isinstance(data, dict), "Unexpected API response shape")
                return data, dict(response.headers.items())
        except HTTPError as error:
            status = error.code
            error.close()
            raise ApiError(status) from None
        except (URLError, TimeoutError, OSError, json.JSONDecodeError):
            raise ApiError("transport-or-contract") from None


class Store:
    """Private local lab evidence; not immutable production storage."""

    def __init__(self, directory, create=False):
        self.root = Path(directory).absolute()
        require(self.root == self.root.resolve(), "Runtime symlinks are not supported")
        require(
            not any((parent / ".git").exists() for parent in (self.root, *self.root.parents)),
            "Runtime must be outside Git",
        )
        if create:
            self.root.mkdir(mode=0o700, parents=True, exist_ok=False)
        require(self.root.is_dir(), "Private runtime directory does not exist")
        require(self.root.stat().st_uid == os.getuid(), "Runtime owner differs")
        require(self.root.stat().st_mode & 0o077 == 0, "Runtime must have mode 0700")

    def path(self, name):
        path = self.root / name
        require(
            path.absolute() == path.resolve() and path.resolve().is_relative_to(self.root),
            "Unsafe private runtime path",
        )
        for parent in [path, *path.parents]:
            if parent == self.root.parent:
                break
            if parent.exists():
                require(not (parent / ".git").exists(), "Evidence path is inside nested Git")
                require(parent.stat().st_mode & 0o077 == 0, "Private path permissions are unsafe")
                require(parent.stat().st_uid == os.getuid(), "Private path owner differs")
        return path

    def read(self, name):
        return load(self.path(name))

    def write(self, name, value):
        path = self.path(name)
        for parent in reversed([path.parent, *path.parent.parents]):
            if parent != self.root and parent.is_relative_to(self.root):
                parent.mkdir(mode=0o700, exist_ok=True)
        self.path(name)
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w", encoding="utf-8", dir=path.parent, delete=False,
            ) as handle:
                temporary = Path(handle.name)
                if isinstance(value, str):
                    handle.write(value)
                else:
                    json.dump(value, handle, indent=2, sort_keys=True)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, path)
            fd = os.open(path.parent, os.O_RDONLY)
            try:
                os.fsync(fd)
            finally:
                os.close(fd)
        finally:
            if temporary and temporary.exists():
                temporary.unlink()

    @contextmanager
    def locked(self):
        path = self.path(".lock")
        fd = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        try:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise Blocked("Another local run holds the runtime lock") from None
            yield
        finally:
            os.close(fd)


class Lab:
    def __init__(self, intent, store, api, now=None, intent_path=None):
        check()
        check_config(intent)
        self.intent, self.store, self.api, self.now = intent, store, api, now or utcnow
        self.state = store.read("checkpoint.json")
        self.bindings = store.read("bindings.json")
        self.authority = store.read("authority.json")
        self.prerequisites = store.read("prerequisites.json")
        self.run = "runs/" + self.now().strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:8]
        self.events = []
        self.observations = {}
        self.intent_path = intent_path
        require(
            intent_path is None or digest(load(intent_path)) == digest(intent),
            "Candidate changed while loading",
        )
        self.inputs = self.fingerprints()

    def fingerprints(self):
        return {
            "candidate": digest(load(self.intent_path) if self.intent_path else self.intent),
            "bindings": digest(self.store.read("bindings.json")),
            "authority": digest(self.store.read("authority.json")),
            "prerequisites": digest(self.store.read("prerequisites.json")),
            "implementation": digest({
                path: (ROOT / path).read_text(encoding="utf-8")
                for path in (
                    "automation/lab.py", "automation/check.py", "policy/lab.py",
                    "config/schemas/lab.yaml", "policy/controls.yaml",
                    "policy/profiles/fs-collab-01.yaml", "requirements.txt",
                )
            }),
            "custody": self.state["owner_token"],
            "transport": getattr(self.api, "evidence_kind", "injected_simulation"),
        }

    def request(self, product, path, method="GET", body=None, role="admin"):
        return self.api.request(product, role, method, path, body)[0]

    def pages(self, product, path, field="results"):
        result, seen = [], set()
        while path:
            require(path not in seen and len(seen) < 100, "Pagination loop/limit; incomplete")
            seen.add(path)
            data, headers = self.api.request(product, "admin", "GET", path, None)
            require(isinstance(data.get(field), list), "Incomplete collection response")
            result.extend(data[field])
            next_url = data.get("_links", {}).get("next")
            match = re.search(r'<([^>]+)>;\s*rel="?next"?', headers.get("Link", headers.get("link", "")))
            if not next_url and match:
                next_url = match[1]
            if next_url:
                origin = self.bindings["products"][product]["origin"]
                parsed = urlsplit(urljoin(origin + path, next_url))
                original = urlsplit(origin + path)
                require(
                    (parsed.scheme, parsed.netloc, parsed.path)
                    == (original.scheme, original.netloc, original.path),
                    "Unsafe pagination destination",
                )
                path = parsed.path + ("?" + parsed.query if parsed.query else "")
            else:
                require(
                    data.get("isLast", True) is not False
                    and data.get("meta", {}).get("hasMore", False) is False
                    and len(result) >= data.get("total", len(result)),
                    "Collection ended before completion",
                )
                path = None
        return result

    def marker(self, asset):
        return f"atlassian-platform-automation:{self.state['owner_token']}:{asset['asset_key']}"

    def expected_grants(self, asset):
        config = asset["configuration"]
        result = set()
        for ref in asset["audience_group_refs"] + config["admin_group_refs"]:
            group_id = self.bindings["groups"][ref]["id"]
            admin = ref in config["admin_group_refs"]
            if asset["kind"] == "jira_project":
                permissions = config["audience_permissions"] + (["ADMINISTER_PROJECTS"] if admin else [])
                result.update((group_id, permission, "") for permission in permissions)
            else:
                permissions = config["audience_permissions"] + (
                    [{"key": "administer", "target": "space"}] if admin else []
                )
                result.update((group_id, item["key"], item["target"]) for item in permissions)
        return result

    def bootstrap(self):
        assess_inputs(
            self.intent, self.bindings, self.authority, self.prerequisites, self.now(),
        )
        organization = self.bindings["organization"]
        path = "/admin/v2/orgs/" + quote(organization["id"], safe="") + "/workspaces"
        workspaces, cursor, seen = [], None, set()
        for _ in range(100):
            data = self.request(
                "organization", path, "POST", {} if cursor is None else {"cursor": cursor},
            )
            require(isinstance(data.get("data"), list), "Workspace inventory incomplete")
            workspaces.extend(data["data"])
            next_url = data.get("links", {}).get("next")
            if not next_url:
                require(len(workspaces) >= data.get("meta", {}).get("total", len(workspaces)),
                        "Workspace inventory truncated")
                break
            parsed = urlsplit(next_url)
            require(
                not parsed.netloc or (parsed.scheme, parsed.netloc) == ("https", "api.atlassian.com"),
                "Unsafe organization pagination",
            )
            require(parsed.path == path, "Unexpected organization pagination route")
            cursor = parse_qs(parsed.query).get("cursor", [None])[0]
            require(bool(cursor) and cursor not in seen, "Workspace cursor incomplete")
            seen.add(cursor)
        else:
            raise Blocked("Workspace inventory pagination limit")
        for product, target in self.bindings["products"].items():
            matches = [item for item in workspaces if item["id"] == target["workspace_id"]]
            require(len(matches) == 1, "Product workspace not uniquely observed")
            attributes = matches[0]["attributes"]
            require(
                attributes["hostUrl"].rstrip("/") == target["origin"]
                and attributes["typeKey"] == target["type_key"]
                and attributes["status"] == "online",
                "Observed workspace differs from target",
            )
            current_path = "/rest/api/3/myself" if product == "jira" else "/wiki/rest/api/user/current"
            actor = self.request(product, current_path)
            require(actor.get("accountId") == target["admin"]["account_id"], "Execution identity differs")
        permissions = self.request("jira", "/rest/api/3/mypermissions?permissions=ADMINISTER")
        require(
            permissions.get("permissions", {}).get("ADMINISTER", {}).get("havePermission") is True,
            "Jira administration not established",
        )
        return {
            "organization_id": organization["id"],
            "products": {
                key: {"workspace_id": value["workspace_id"], "origin": value["origin"],
                      "actor": value["admin"]["account_id"]}
                for key, value in self.bindings["products"].items()
            },
            "prerequisite_methods": {
                ref: value["method"] for ref, value in self.prerequisites.items()
            },
        }

    def observe(self, asset):
        config, product = asset["configuration"], self.product(asset)
        key = config["key"]
        if product == "jira":
            schemes = self.request("jira", "/rest/api/3/permissionscheme").get("permissionSchemes")
            require(isinstance(schemes, list), "Scheme inventory incomplete")
            matches = [item for item in schemes if item["name"] == config["permission_scheme_name"]]
            require(len(matches) <= 1, "Ambiguous permission scheme")
            scheme = None
            if matches:
                item = matches[0]
                grants = self.request("jira", f"/rest/api/3/permissionscheme/{item['id']}/permission")
                require(isinstance(grants.get("permissions"), list), "Scheme grants incomplete")
                normalized = []
                for grant in grants["permissions"]:
                    holder = grant["holder"]
                    require(holder["type"] == "group" and bool(holder.get("value")), "Undeclared grant holder")
                    normalized.append([holder["value"], grant["permission"], ""])
                require(len(normalized) == len({tuple(row) for row in normalized}), "Duplicate grants")
                scheme = {
                    "id": str(item["id"]), "name": item["name"],
                    "description": item.get("description", ""), "grants": sorted(normalized),
                }
            try:
                project = self.request("jira", "/rest/api/3/project/" + key)
                assigned = self.request("jira", f"/rest/api/3/project/{key}/permissionscheme")
                project = {
                    "id": str(project["id"]), "key": project["key"], "name": project["name"],
                    "lead": project.get("lead", {}).get("accountId"),
                    "company_managed": project.get("simplified") is False and project.get("style") == "classic",
                    "description": project.get("description", ""), "scheme_id": str(assigned["id"]),
                }
            except ApiError as error:
                if error.status != 404:
                    raise
                validation = self.request("jira", "/rest/api/3/projectvalidate/key?" + urlencode({"key": key}))
                require(
                    validation.get("errors") == {} and validation.get("errorMessages") == [],
                    "Project hidden, key unavailable or validation incomplete",
                )
                project = None
            return {"resource": project, "scheme": scheme}
        spaces = self.pages("confluence", "/wiki/api/v2/spaces?" + urlencode({"keys": key}))
        require(len(spaces) <= 1 and all(item["key"] == key for item in spaces), "Ambiguous space")
        if not spaces:
            # Caller-visible emptiness is not proof of tenant-wide absence.
            proof = self.prerequisites["fixture:bootstrap-products"]
            require(key in proof.get("unused_confluence_keys", []), "Space absence needs scoped manual proof")
            return {"resource": None, "absence_method": "controlled_manual"}
        space = self.request(
            "confluence", "/wiki/api/v2/spaces/" + str(spaces[0]["id"]) + "?description-format=plain",
        )
        require(
            str(space["id"]) == str(spaces[0]["id"])
            and space["key"] == key and space.get("status") == "current",
            "Space identity or lifecycle differs",
        )
        permissions = self.pages("confluence", f"/wiki/api/v2/spaces/{space['id']}/permissions")
        groups, creator = [], []
        admin_id = self.bindings["products"]["confluence"]["admin"]["account_id"]
        for permission in permissions:
            principal, operation = permission["principal"], permission["operation"]
            if principal["type"] == "user" and principal["id"] == admin_id:
                creator.append([operation["key"], operation["targetType"]])
            else:
                require(
                    principal["type"] == "group" and bool(principal.get("id")),
                    "Unexpected user, anonymous or unlicensed space grant",
                )
                groups.append([principal["id"], operation["key"], operation["targetType"]])
        require(["administer", "space"] in creator and ["read", "space"] in creator,
                "Original administrative recovery access is not established")
        require(len(groups) == len({tuple(row) for row in groups}), "Duplicate space grants")
        return {"resource": {
            "id": str(space["id"]), "key": space["key"], "name": space["name"],
            "description": space.get("description", {}).get("plain", {}).get("value", ""),
            "grants": sorted(groups), "creator_grants": sorted(creator),
        }}

    @staticmethod
    def product(asset):
        return "jira" if asset["kind"] == "jira_project" else "confluence"

    def authorized_resource(self, asset, item, field):
        saved = self.state["resources"].get(asset["asset_key"], {})
        adoption = self.bindings.get("adoptions", {}).get(asset["asset_key"], {})
        if str(saved.get(field)) == item["id"]:
            require(item["description"] == self.marker(asset), "Created-resource marker differs")
            return
        require(
            str(adoption.get(field)) == item["id"] and bool(adoption.get("authority_ref")),
            "Existing resource has no explicit adoption authority",
        )
        record = self.authority.get(adoption["authority_ref"], {})
        from policy.lab import current
        current(record, self.now(), "active")
        require(
            record.get("scope") == scope(self.bindings)
            and record.get("purpose") == "adoption"
            and asset["asset_key"] in record.get("asset_keys", [])
            and record.get("native_ids", {}).get(field) == item["id"],
            "Adoption authority differs from native resource",
        )

    def reconcile(self, observations):
        pending = self.state.get("pending")
        if not pending:
            return
        asset = next(item for item in self.intent["assets"] if item["asset_key"] == pending["asset"])
        observed = observations[asset["asset_key"]]
        action = pending["action"]
        field = "scheme_id" if action["op"] == "scheme" else "id"
        item = observed["scheme"] if action["op"] == "scheme" else observed["resource"]
        if action["op"] in {"scheme", "project", "space"}:
            require(
                item is not None and item["description"] == self.marker(asset)
                and item["name"] == action["payload"]["name"],
                "Uncertain creation unresolved; inspect before any retry",
            )
            if action["op"] == "scheme":
                require(item["grants"] == sorted(map(list, self.expected_grants(asset))), "Uncertain scheme differs")
            else:
                require(item["key"] == action["payload"]["key"], "Uncertain resource differs")
                if action["op"] == "space":
                    require(item["grants"] == [], "Uncertain private creation has group grants")
            self.state["resources"].setdefault(asset["asset_key"], {})[field] = item["id"]
            if action["op"] == "space":
                self.state["resources"][asset["asset_key"]]["building"] = True
        else:
            require(
                item is not None and item["id"] == action["resource_id"]
                and action["grant"] in item["grants"],
                "Uncertain permission grant unresolved; no automatic retry",
            )
        self.events.append({
            "status": "reconciled_by_readback", "asset": asset["asset_key"],
            "action": action, "original_run": pending["run"],
        })
        self.store.write(self.run + "/actions.json", self.events)
        self.state["pending"] = None
        self.store.write("checkpoint.json", self.state)

    def actions(self, asset, observed):
        config, product = asset["configuration"], self.product(asset)
        expected = sorted(map(list, self.expected_grants(asset)))
        resource = observed["resource"]
        saved = self.state["resources"].get(asset["asset_key"], {})
        adopted = self.bindings.get("adoptions", {}).get(asset["asset_key"], {})
        require(
            resource is not None or not (saved.get("id") or adopted.get("id")),
            "Known resource is missing or hidden; recreation is not authorised",
        )
        actions = []
        if product == "jira":
            scheme = observed["scheme"]
            require(
                scheme is not None or not (saved.get("scheme_id") or adopted.get("scheme_id")),
                "Known permission scheme is missing; recreation is not authorised",
            )
            if scheme:
                self.authorized_resource(asset, scheme, "scheme_id")
                require(scheme["grants"] == expected, "Permission scheme drift; repair not authorised")
            else:
                holders = {value["id"]: value for value in self.bindings["groups"].values()}
                actions.append({"op": "scheme", "payload": {
                    "name": config["permission_scheme_name"], "description": self.marker(asset),
                    "permissions": [
                        {"holder": {"type": "group", "value": group, "parameter": holders[group]["name"]},
                         "permission": permission}
                        for group, permission, _ in expected
                    ],
                }})
            if resource:
                self.authorized_resource(asset, resource, "id")
                require(
                    scheme is not None and resource["scheme_id"] == scheme["id"]
                    and resource["key"] == config["key"]
                    and resource["company_managed"] is True
                    and resource["name"] == config["name"]
                    and resource["lead"] == self.bindings["users"][config["lead_ref"]],
                    "Project drift; repair not authorised",
                )
            else:
                actions.append({"op": "project", "payload": {
                    "key": config["key"], "name": config["name"],
                    "description": self.marker(asset), "projectTypeKey": config["project_type"],
                    "projectTemplateKey": config["template_key"],
                    "leadAccountId": self.bindings["users"][config["lead_ref"]],
                    "permissionScheme": scheme["id"] if scheme else "$created_scheme",
                }})
        else:
            if resource:
                self.authorized_resource(asset, resource, "id")
                require(resource["name"] == config["name"], "Space name drift")
                require(
                    {tuple(row) for row in resource["grants"]} <= {tuple(row) for row in expected},
                    "Space access drift; no broad repair",
                )
                missing = [row for row in expected if row not in resource["grants"]]
                require(
                    not missing or self.state["resources"].get(asset["asset_key"], {}).get("building") is True,
                    "Existing space drift; expansion requires a new authorised change",
                )
            else:
                missing = expected
                actions.append({"op": "space", "payload": {
                    "key": config["key"], "name": config["name"],
                    "description": {"plain": {"value": self.marker(asset), "representation": "plain"}},
                }})
            audience_ids = {self.bindings["groups"][ref]["id"] for ref in asset["audience_group_refs"]}
            for group, operation, target in sorted(
                missing, key=lambda row: (row[0] in audience_ids and row[1] == "read", row),
            ):
                actions.append({"op": "grant", "grant": [group, operation, target], "payload": {
                    "subject": {"type": "group", "identifier": group},
                    "operation": {"key": operation, "target": target},
                }})
        return [dict(item, asset=asset["asset_key"], product=product) for item in actions]

    def snapshot(self):
        baseline = self.bootstrap()
        self.observations = {"bootstrap": baseline, "assets": {}}
        observations = self.observations["assets"]
        for asset in self.intent["assets"]:
            observations[asset["asset_key"]] = self.observe(asset)
        self.reconcile(observations)
        actions = [
            action for asset in self.intent["assets"]
            for action in self.actions(asset, observations[asset["asset_key"]])
        ]
        return actions

    def plan(self):
        actions = self.snapshot()
        return {
            "version": 1, "inputs": self.inputs, "scope": scope(self.bindings),
            "preconditions": digest(self.observations), "actions": actions,
            "issued_at": self.now().isoformat(),
            "expires_at": (self.now() + timedelta(minutes=15)).isoformat(),
        }

    def mutate(self, asset, action):
        product, op = action["product"], action["op"]
        payload = json.loads(json.dumps(action["payload"]))
        if op == "project":
            observed = self.observe(asset)
            require(observed["scheme"] is not None, "Scheme not established")
            self.authorized_resource(asset, observed["scheme"], "scheme_id")
            require(observed["scheme"]["grants"] == sorted(map(list, self.expected_grants(asset))),
                    "Scheme changed before project creation")
            payload["permissionScheme"] = int(observed["scheme"]["id"])
        paths = {
            "scheme": "/rest/api/3/permissionscheme", "project": "/rest/api/3/project",
            "space": "/wiki/rest/api/space/_private",
            "grant": "/wiki/rest/api/space/" + asset["configuration"]["key"] + "/permission",
        }
        if op == "grant":
            observed = self.observe(asset)["resource"]
            require(observed is not None, "Private space not established")
            self.authorized_resource(asset, observed, "id")
            require(
                {tuple(row) for row in observed["grants"]} <= self.expected_grants(asset),
                "Space acquired undeclared grants during application",
            )
            action = dict(action, resource_id=observed["id"])
        self.state["pending"] = {"asset": asset["asset_key"], "action": action, "run": self.run}
        self.store.write("checkpoint.json", self.state)
        self.events.append({
            "action": action, "status": "attempting", "at": self.now().isoformat(),
        })
        self.store.write(self.run + "/actions.json", self.events)
        try:
            result = self.request(product, paths[op], "POST", payload)
        except ApiError as error:
            # An explicit rejection is not an uncertain successful creation.
            if error.status in {400, 401, 403, 404, 409, 422}:
                self.events.append({"action": action, "status": "rejected", "http_status": error.status})
                self.store.write(self.run + "/actions.json", self.events)
                self.state["pending"] = None
                self.store.write("checkpoint.json", self.state)
            raise
        saved = self.state["resources"].setdefault(asset["asset_key"], {})
        if op in {"scheme", "project", "space"}:
            require(bool(result.get("id")), "Creation response lacks an identifier; outcome uncertain")
            saved["scheme_id" if op == "scheme" else "id"] = str(result["id"])
            if op == "space":
                saved["building"] = True
        self.state["pending"] = None
        self.store.write("checkpoint.json", self.state)
        self.events.append({
            "action": action, "status": "response-recorded",
            "returned_id": str(result.get("id", "")), "at": self.now().isoformat(),
        })
        self.store.write(self.run + "/actions.json", self.events)
        # No further write is allowed before the new state has been read.
        observed = self.observe(asset)
        if op == "space":
            require(observed["resource"]["grants"] == [], "New space was not private to creator")
        self.actions(asset, observed)

    def apply(self, plan, review, review_path=None):
        assess_review(
            plan, review, self.inputs,
            {value["admin"]["account_id"] for value in self.bindings["products"].values()},
            self.now(),
        )
        require(timestamp(plan["issued_at"]) <= self.now() < timestamp(plan["expires_at"]),
                "Plan lease expired; replan and review")
        actions = self.snapshot()
        self.store.write(self.run + "/before.json", self.observations)
        self.store.write(self.run + "/plan.json", plan)
        self.store.write(self.run + "/review.json", review)
        if actions:
            require(
                plan["preconditions"] == digest(self.observations) and plan["actions"] == actions,
                "Material target state changed; replan and review",
            )
        for action in actions:
            # Authority is checked again before each individual write.
            require(self.fingerprints() == self.inputs, "Candidate, policy or runtime inputs changed")
            require(self.now() < timestamp(plan["expires_at"]), "Plan expired during application")
            if review_path:
                review = self.store.read(review_path)
            assess_inputs(self.intent, self.bindings, self.authority, self.prerequisites, self.now())
            assess_review(plan, review, self.inputs,
                          {value["admin"]["account_id"] for value in self.bindings["products"].values()},
                          self.now())
            asset = next(item for item in self.intent["assets"] if item["asset_key"] == action["asset"])
            self.mutate(asset, action)
        require(self.fingerprints() == self.inputs, "Inputs changed before qualification")
        if review_path:
            review = self.store.read(review_path)
        assess_review(plan, review, self.inputs,
                      {value["admin"]["account_id"] for value in self.bindings["products"].values()},
                      self.now())
        return self.verify()

    def verify(self):
        require(not self.snapshot(), "Provisioning/configuration is incomplete")
        results = []
        for asset in self.intent["assets"]:
            product, key = self.product(asset), asset["configuration"]["key"]
            target = self.bindings["products"][product]
            resource = self.observations["assets"][asset["asset_key"]]["resource"]
            resource_path = (
                "/rest/api/3/project/" + key if product == "jira"
                else "/wiki/api/v2/spaces/" + resource["id"]
            )
            for role in ("allowed", "denied"):
                current_path = "/rest/api/3/myself" if product == "jira" else "/wiki/rest/api/user/current"
                actor = self.request(product, current_path, role=role)
                require(actor.get("accountId") == target[role]["account_id"], "Test identity differs")
                baseline = target[role]["baseline_path"]
                require(baseline != resource_path, "Access baseline must be independent")
                self.request(product, baseline, role=role)
                try:
                    self.request(product, resource_path, role=role)
                    accessible = True
                except ApiError as error:
                    require(error.status in {403, 404}, "Access probe inconclusive")
                    accessible = False
                require(accessible == (role == "allowed"), "Asset isolation test failed")
            try:
                self.request(product, resource_path, role="anonymous")
            except ApiError as error:
                require(error.status in {401, 403, 404}, "Anonymous probe inconclusive")
            else:
                raise Blocked("Anonymous target access is enabled")
            if product == "jira":
                permissions = ",".join(asset["configuration"]["audience_permissions"])
                response = self.request("jira", "/rest/api/3/mypermissions?" + urlencode({
                    "projectKey": key, "permissions": permissions,
                }), role="allowed")
                require(all(
                    response.get("permissions", {}).get(permission, {}).get("havePermission") is True
                    for permission in asset["configuration"]["audience_permissions"]
                ), "Declared Jira work permissions not established")
            else:
                operations = self.request(
                    "confluence", f"/wiki/api/v2/spaces/{resource['id']}/operations", role="allowed",
                )
                require(
                    {"operation": "create", "targetType": "page"} in operations.get("operations", []),
                    "Declared page-creation permission not established",
                )
            results.append({"asset": asset["asset_key"], "configuration": "verified",
                            "access": "passed_declared_probes", "id": resource["id"]})
        for saved in self.state["resources"].values():
            saved["building"] = False
        self.store.write("checkpoint.json", self.state)
        return {
            "result": "verified_lab_qualification", "assets": results,
            "execution_mode": self.inputs["transport"],
            "production_accepted": False, "profile_status": "assumed",
            "control_references": CONTROL_REFERENCES,
            "control_claim": "bounded implementation tests, not whole-control acceptance",
            "limits": [
                "API-contract acceptance requires a live tenant run",
                "Permission probes do not exercise issue/page writes",
                "Alternative sharing/app-mediated routes are not exercised",
                "Foundation prerequisites may include manual or simulated evidence",
                "Private local evidence is not protected production retention",
            ],
        }

    def finish(self, result):
        self.store.write(self.run + "/observations.json", self.observations)
        self.store.write(self.run + "/actions.json", self.events)
        self.store.write(self.run + "/report.json", dict(
            result, inputs=self.inputs, execution_mode=self.inputs["transport"],
            observed_at=self.now().isoformat(),
        ))
        lines = [
            "# Atlassian Lab Run", "",
            f"Result: **{result['result']}**. This is a synthetic lab result, not production acceptance.",
            "", "## Scope", "",
            "- Tenant: existing organisation and Jira/Confluence instances.",
            "- Assets: one project, its dedicated scheme and one restricted space.",
            "- Evidence: private local files, not immutable production retention.",
            "- Execution transport: " + self.inputs["transport"] + ".",
            "",
        ]
        if result.get("reason"):
            lines.extend(["## Blocker", "", result["reason"], ""])
        if result.get("assets"):
            lines.extend(["## Verification", "", "| Asset | Configuration | Access |",
                          "|---|---|---|"])
            for asset in result["assets"]:
                lines.append(f"| {asset['asset']} | {asset['configuration']} | {asset['access']} |")
        lines.extend(["", "## Limits", ""])
        lines.extend("- " + item for item in result.get("limits", [
            "Plan/response success alone is not access qualification.",
            "Manual and simulated prerequisites remain distinct from live proof.",
        ]))
        self.store.write(self.run + "/report.md", "\n".join(lines))


def initialize(directory, intent):
    store = Store(directory, create=True)
    credential = lambda name: {"mode": "basic", "email_env": name + "_EMAIL", "token_env": name + "_TOKEN"}
    bindings = {
        "lab_credentials_only": True,
        "organization": {"ref": intent["bootstrap"]["organization_ref"], "id": "REPLACE",
                         "credential": {"mode": "bearer", "token_env": "ATLASSIAN_LAB_ORG_TOKEN"}},
        "site": {"ref": intent["bootstrap"]["site_ref"], "origin": "https://replace.atlassian.net"},
        "products": {},
        "groups": {"GROUP-LAB-TEAM": {"id": "REPLACE", "name": "lab-team"},
                   "GROUP-LAB-ADMINS": {"id": "REPLACE", "name": "lab-admins"}},
        "users": {"USER-LAB-OWNER": "REPLACE"}, "adoptions": {},
    }
    for product, ref in (("jira", "LAB-JIRA"), ("confluence", "LAB-CONFLUENCE")):
        bindings["products"][product] = {
            "ref": ref, "workspace_id": "REPLACE", "type_key": "REPLACE",
            "origin": "https://replace.atlassian.net", "permission_model": "legacy",
            **{
                role: {"account_id": "REPLACE-" + role,
                       "credential": credential("ATLASSIAN_LAB_" + product.upper() + "_" + role.upper()),
                       **({"baseline_path": "/rest/api/3/project/BASELINE" if product == "jira"
                           else "/wiki/api/v2/spaces/REPLACE"} if role != "admin" else {})}
                for role in ("admin", "allowed", "denied")
            },
        }
    now = utcnow().isoformat()
    base = {"status": "pending", "actor": None, "evidence_ref": None,
            "issued_at": now, "expires_at": None, "scope": scope(bindings)}
    authority = {}
    for asset in intent["assets"]:
        for purpose, ref in asset["authority_refs"].items():
            authority[ref] = dict(
                base, purpose=purpose,
                asset_keys=[item["asset_key"] for item in intent["assets"]],
                application_ref="BA-LAB-001", classification="Internal",
                accountable_owner_id=bindings["users"]["USER-LAB-OWNER"],
                approved_standards=list(STANDARD_REFS.values()),
                audiences={
                    item["asset_key"]: [bindings["groups"][key]["id"] for key in item["audience_group_refs"]]
                    for item in intent["assets"]
                },
                administrators={
                    item["asset_key"]: [bindings["groups"][key]["id"] for key in item["configuration"]["admin_group_refs"]]
                    for item in intent["assets"]
                },
            )
    prerequisites = {
        ref: dict(base, method="controlled_manual") for ref in intent["bootstrap"]["prerequisite_refs"]
    }
    prerequisites["fixture:bootstrap-products"]["unused_confluence_keys"] = []
    store.write("bindings.json", bindings)
    store.write("authority.json", authority)
    store.write("prerequisites.json", prerequisites)
    store.write("checkpoint.json", {"owner_token": uuid.uuid4().hex, "resources": {}, "pending": None})
    return store


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["init", "plan", "apply", "verify"])
    parser.add_argument("--intent", type=Path, default=ROOT / "config/environments/lab.yaml")
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--review", type=Path)
    parser.add_argument("--live", action="store_true")
    args = parser.parse_args(argv)
    runner = None
    try:
        intent = load(args.intent)
        check_config(intent)
        if args.command == "init":
            initialize(args.runtime, intent)
            print("Private pending templates created. No approval or tenant change.")
            return 0
        require(args.live, "Use --live explicitly; offline acceptance is make check")
        store = Store(args.runtime)
        with store.locked():
            runner = Lab(
                intent, store, Http(store.read("bindings.json"), live=True), intent_path=args.intent,
            )
            if args.command == "plan":
                plan = runner.plan()
                store.write(runner.run + "/plan.json", plan)
                result = {"result": "planned", "actions": len(plan["actions"]),
                          "plan_digest": digest(plan), "production_accepted": False}
            elif args.command == "apply":
                require(args.plan is not None and args.review is not None, "Plan and review required")
                plan = store.read(str(args.plan.absolute().relative_to(store.root)))
                review_path = str(args.review.absolute().relative_to(store.root))
                review = store.read(review_path)
                result = runner.apply(plan, review, review_path=review_path)
            else:
                result = runner.verify()
            runner.finish(result)
            print(json.dumps(dict(result, evidence=str(store.root / runner.run)), indent=2))
            return 0
    except (Blocked, ApiError, OSError, ValueError, KeyError, TypeError, AttributeError, IndexError) as error:
        reason = str(error) if isinstance(error, (Blocked, ApiError)) else type(error).__name__
        if runner:
            try:
                runner.finish({"result": "blocked_or_incomplete", "reason": reason,
                               "production_accepted": False})
            except (OSError, Blocked):
                pass
        print(f"Blocked or incomplete: {reason}. No automatic retry.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

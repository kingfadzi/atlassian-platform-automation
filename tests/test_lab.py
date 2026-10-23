"""Mandatory offline acceptance: stateful API double, real runner and storage."""

from copy import deepcopy
from contextlib import redirect_stdout
from datetime import datetime, timedelta, timezone
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.parse import parse_qs, urlsplit

from automation.check import ROOT, check_config, load
from automation.lab import ApiError, Http, Lab, Store, initialize, main
from policy.lab import Blocked, digest, scope


NOW = datetime(2026, 10, 22, 22, 0, tzinfo=timezone.utc)


class Tenant:
    """Enforces unique keys and rejects duplicate grants to detect unsafe reruns."""

    evidence_kind = "stateful_api_double"
    def __init__(self, bindings):
        self.bindings = bindings
        self.schemes, self.projects, self.spaces = {}, {}, {}
        self.calls, self.writes = [], []
        self.fail_after = None
        self.reject_next = False
        self.bad_identity = False
        self.allow_denied = False
        self.baseline_denied = False
        self.anonymous_enabled = False
        self.workspace_pages = False
        self.pagination = None
        self.sequence = 100

    def identifier(self):
        self.sequence += 1
        return str(self.sequence)

    def request(self, product, role, method, path, body=None):
        self.calls.append((product, role, method, path))
        parsed, query = urlsplit(path), parse_qs(urlsplit(path).query)
        route = parsed.path
        if product == "organization":
            items = [
                {"id": item["workspace_id"], "attributes": {
                    "hostUrl": item["origin"], "typeKey": item["type_key"], "status": "online",
                }} for item in self.bindings["products"].values()
            ]
            if self.workspace_pages and not body.get("cursor"):
                return {"data": items[:1], "links": {
                    "next": "https://api.atlassian.com" + route + "?cursor=second",
                }, "meta": {"total": 2}}, {}
            return {"data": items[1:] if self.workspace_pages else items,
                    "links": {}, "meta": {"total": 2}}, {}
        target = self.bindings["products"][product]
        if method == "GET":
            if route in {"/rest/api/3/myself", "/wiki/rest/api/user/current"}:
                return {"accountId": "unexpected" if self.bad_identity else target[role]["account_id"]}, {}
            if route in {"/rest/api/3/project/BASELINE", "/wiki/api/v2/spaces/10"}:
                if self.baseline_denied:
                    raise ApiError(403)
                return {"id": "10"}, {}
            if route == "/rest/api/3/mypermissions":
                names = query["permissions"][0].split(",")
                return {"permissions": {
                    name: {"havePermission": role in {"admin", "allowed"}} for name in names
                }}, {}
            if route == "/rest/api/3/projectvalidate/key":
                used = query["key"][0] in self.projects
                return {"errors": {"projectKey": "exists"} if used else {}, "errorMessages": []}, {}
            if route == "/rest/api/3/permissionscheme":
                return {"permissionSchemes": [
                    {key: value for key, value in item.items() if key != "permissions"}
                    for item in self.schemes.values()
                ]}, {}
            if route.startswith("/rest/api/3/permissionscheme/"):
                return {"permissions": deepcopy(self.schemes[route.split("/")[-2]]["permissions"])}, {}
            if route.startswith("/rest/api/3/project/"):
                key = route.split("/")[5]
                project = self.projects.get(key)
                if not project or (role == "anonymous" and not self.anonymous_enabled) or (role == "denied" and not self.allow_denied):
                    raise ApiError(404)
                if route.endswith("/permissionscheme"):
                    return {"id": project["permissionScheme"]}, {}
                return deepcopy(project), {}
            if route == "/wiki/api/v2/spaces":
                values = list(self.spaces.values())
                return {"results": [
                    {"id": item["id"], "key": item["key"]} for item in values
                    if item["key"] in query.get("keys", [])
                ], "_links": {"next": self.pagination} if self.pagination else {}}, {}
            if route.startswith("/wiki/api/v2/spaces/"):
                identifier = route.split("/")[5]
                space = next((item for item in self.spaces.values() if item["id"] == identifier), None)
                if not space or (role == "anonymous" and not self.anonymous_enabled) or (role == "denied" and not self.allow_denied):
                    raise ApiError(404)
                if route.endswith("/permissions"):
                    return {"results": deepcopy(space["permissions"]), "_links": {}}, {}
                if route.endswith("/operations"):
                    return {"operations": [{"operation": "create", "targetType": "page"}]}, {}
                return {key: deepcopy(value) for key, value in space.items() if key != "permissions"}, {}
            raise AssertionError("Unexpected read: " + route)
        if self.reject_next:
            self.reject_next = False
            raise ApiError(403)
        if route == "/rest/api/3/permissionscheme":
            if any(item["name"] == body["name"] for item in self.schemes.values()):
                raise ApiError(409)
            identifier = self.identifier()
            self.schemes[identifier] = dict(deepcopy(body), id=identifier)
        elif route == "/rest/api/3/project":
            if body["key"] in self.projects:
                raise ApiError(409)
            identifier = self.identifier()
            self.projects[body["key"]] = dict(
                deepcopy(body), id=identifier, simplified=False, style="classic",
                lead={"accountId": body["leadAccountId"]},
            )
        elif route == "/wiki/rest/api/space/_private":
            if body["key"] in self.spaces:
                raise ApiError(400)
            identifier = self.identifier()
            self.spaces[body["key"]] = dict(deepcopy(body), id=identifier, status="current", permissions=[
                {"principal": {"type": "user", "id": target["admin"]["account_id"]},
                 "operation": {"key": key, "targetType": "space"}}
                for key in ("read", "administer")
            ])
        elif route.endswith("/permission"):
            key = route.split("/")[5]
            space = self.spaces[key]
            grant = {
                "principal": {"type": body["subject"]["type"], "id": body["subject"]["identifier"]},
                "operation": {"key": body["operation"]["key"], "targetType": body["operation"]["target"]},
            }
            if grant in space["permissions"]:
                raise AssertionError("Duplicate grant attempted")
            space["permissions"].append(grant)
            identifier = self.identifier()
        else:
            raise AssertionError("Unexpected mutation: " + route)
        self.writes.append((product, route, deepcopy(body)))
        if self.fail_after == len(self.writes):
            self.fail_after = None
            raise ApiError("timeout-after-commit")
        return {"id": identifier}, {}


class LabAcceptance(unittest.TestCase):
    def setUp(self):
        self.network = patch("socket.create_connection", side_effect=AssertionError("Offline tests must not use network"))
        self.network.start()
        self.addCleanup(self.network.stop)
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name) / "private"
        self.intent = load(ROOT / "config/environments/lab.yaml")
        self.store = initialize(self.directory, self.intent)
        self.bindings = self.store.read("bindings.json")
        self.bindings["organization"]["id"] = "org-lab"
        self.bindings["groups"] = {
            "GROUP-LAB-TEAM": {"id": "g-team", "name": "lab-team"},
            "GROUP-LAB-ADMINS": {"id": "g-admin", "name": "lab-admins"},
        }
        self.bindings["users"]["USER-LAB-OWNER"] = "jira-admin"
        for product, target in self.bindings["products"].items():
            target["workspace_id"] = product + "-workspace"
            target["type_key"] = product
            for role in ("admin", "allowed", "denied"):
                target[role]["account_id"] = product + "-" + role
                if role != "admin":
                    target[role]["baseline_path"] = (
                        "/rest/api/3/project/BASELINE" if product == "jira"
                        else "/wiki/api/v2/spaces/10"
                    )
        self.store.write("bindings.json", self.bindings)
        for filename, status in (("authority.json", "active"), ("prerequisites.json", "verified")):
            records = self.store.read(filename)
            for record in records.values():
                record.update(
                    status=status, actor="fixture-verifier", evidence_ref="fixture:proof",
                    issued_at=NOW.isoformat(), expires_at=(NOW + timedelta(days=1)).isoformat(),
                    scope=scope(self.bindings),
                )
                if filename == "authority.json":
                    record["accountable_owner_id"] = "jira-admin"
                    record["audiences"] = {
                        item["asset_key"]: ["g-team"] for item in self.intent["assets"]
                    }
                    record["administrators"] = {
                        item["asset_key"]: ["g-admin"] for item in self.intent["assets"]
                    }
            if filename == "prerequisites.json":
                records["fixture:bootstrap-products"]["unused_confluence_keys"] = ["LABSPACE"]
            self.store.write(filename, records)
        self.api = Tenant(self.bindings)

    def runner(self):
        return Lab(self.intent, self.store, self.api, now=lambda: NOW)

    def review(self, plan):
        return {
            "status": "approved", "actor": "independent-lab-reviewer",
            "evidence_ref": "fixture:technical-review", "lab_only": True,
            "plan_digest": digest(plan), "issued_at": NOW.isoformat(),
            "expires_at": (NOW + timedelta(hours=1)).isoformat(),
        }

    def apply(self):
        plan = self.runner().plan()
        runner = self.runner()
        result = runner.apply(plan, self.review(plan))
        runner.finish(result)
        return plan, result

    def test_create_then_repeat_apply_is_zero_write(self):
        plan, result = self.apply()
        self.assertEqual(result["result"], "verified_lab_qualification")
        self.assertEqual(result["execution_mode"], "stateful_api_double")
        self.assertEqual(len(self.api.writes), 8)
        before = deepcopy((self.api.schemes, self.api.projects, self.api.spaces))
        self.runner().apply(plan, self.review(plan))
        self.assertEqual(len(self.api.writes), 8)
        self.assertEqual(before, (self.api.schemes, self.api.projects, self.api.spaces))
        self.assertEqual(self.runner().plan()["actions"], [])

    def test_every_write_lost_response_reconciles_without_duplicate(self):
        for step in range(1, 9):
            with self.subTest(step=step):
                self.store.write("checkpoint.json", {
                    "owner_token": "fixture-owner-" + str(step),
                    "resources": {}, "pending": None,
                })
                self.api = Tenant(self.bindings)
                plan = self.runner().plan()
                self.api.fail_after = step
                with self.assertRaises(ApiError):
                    self.runner().apply(plan, self.review(plan))
                self.assertIsNotNone(self.store.read("checkpoint.json")["pending"])
                self.apply()
                self.assertEqual(len(self.api.writes), 8)
                self.assertEqual(len(self.api.schemes), 1)
                self.assertEqual(len(self.api.projects), 1)
                self.assertEqual(len(self.api.spaces), 1)
                self.assertIsNone(self.store.read("checkpoint.json")["pending"])

    def test_known_rejection_then_new_plan_resumes(self):
        plan = self.runner().plan()
        self.api.reject_next = True
        with self.assertRaises(ApiError):
            self.runner().apply(plan, self.review(plan))
        self.assertEqual(self.api.writes, [])
        self.assertIsNone(self.store.read("checkpoint.json")["pending"])
        self.apply()

    def test_unknown_not_committed_is_not_blindly_retried(self):
        runner = self.runner()
        plan = runner.plan()
        original = self.api.request
        def timeout(product, role, method, path, body=None):
            if method == "POST" and product != "organization":
                raise ApiError("timeout-before-unknown-commit")
            return original(product, role, method, path, body)
        with patch.object(self.api, "request", side_effect=timeout):
            with self.assertRaises(ApiError):
                runner.apply(plan, self.review(plan))
        with self.assertRaises(Blocked):
            self.runner().plan()
        self.assertEqual(self.api.writes, [])

    def test_checkpoint_failure_after_remote_success_is_recoverable(self):
        runner, original = self.runner(), self.store.write
        plan = runner.plan()
        failed = False
        def fail_once(name, value):
            nonlocal failed
            if name == "checkpoint.json" and value.get("pending") is None and not failed:
                failed = True
                raise OSError("Injected disk failure")
            return original(name, value)
        with patch.object(self.store, "write", side_effect=fail_once):
            with self.assertRaises(OSError):
                runner.apply(plan, self.review(plan))
        self.assertIsNotNone(self.store.read("checkpoint.json")["pending"])
        self.apply()
        self.assertEqual(len(self.api.writes), 8)

    def test_checkpoint_failure_before_remote_call_prevents_write(self):
        runner = self.runner()
        plan = runner.plan()
        with patch.object(self.store, "write", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                runner.apply(plan, self.review(plan))
        self.assertEqual(self.api.writes, [])

    def test_drift_never_causes_unreviewed_repair(self):
        self.apply()
        scheme = next(iter(self.api.schemes.values()))
        scheme["permissions"].pop()
        with self.assertRaises(Blocked):
            self.runner().plan()
        self.assertEqual(len(self.api.writes), 8)

    def test_completed_space_missing_grant_is_drift_not_resume(self):
        self.apply()
        space = next(iter(self.api.spaces.values()))
        space["permissions"].pop()
        with self.assertRaises(Blocked):
            self.runner().plan()
        self.assertEqual(len(self.api.writes), 8)

    def test_disappeared_resources_are_not_recreated(self):
        self.apply()
        self.api.projects.clear()
        with self.assertRaises(Blocked):
            self.runner().plan()
        self.assertEqual(len(self.api.writes), 8)

    def test_project_key_and_space_lifecycle_drift_block(self):
        self.apply()
        self.api.projects["LABJIRA"]["key"] = "RENAMED"
        with self.assertRaises(Blocked):
            self.runner().plan()
        self.api.projects["LABJIRA"]["key"] = "LABJIRA"
        self.api.spaces["LABSPACE"]["status"] = "archived"
        with self.assertRaises(Blocked):
            self.runner().plan()
        self.assertEqual(len(self.api.writes), 8)

    def test_collision_does_not_authorise_adoption(self):
        self.apply()
        state = self.store.read("checkpoint.json")
        state["resources"] = {}
        self.store.write("checkpoint.json", state)
        with self.assertRaises(Blocked):
            self.runner().plan()
        self.assertEqual(len(self.api.writes), 8)

    def test_explicit_native_adoption_requires_current_scoped_authority(self):
        self.apply()
        state = self.store.read("checkpoint.json")
        authority = self.store.read("authority.json")
        adoptions = {}
        for asset, native in state["resources"].items():
            ref = "fixture:adopt-" + asset
            authority[ref] = dict(
                next(iter(authority.values())), purpose="adoption", asset_keys=[asset], native_ids={
                    key: value for key, value in native.items() if key in {"id", "scheme_id"}
                },
            )
            adoptions[asset] = dict(authority[ref]["native_ids"], authority_ref=ref)
        bindings = self.store.read("bindings.json")
        bindings["adoptions"] = adoptions
        self.store.write("bindings.json", bindings)
        self.store.write("authority.json", authority)
        state["resources"] = {}
        self.store.write("checkpoint.json", state)
        self.assertEqual(self.runner().plan()["actions"], [])

    def test_expired_revoked_missing_and_wrong_scope_authority_block(self):
        original = self.store.read("authority.json")
        ref = next(iter(original))
        for change in (
            {"expires_at": (NOW - timedelta(seconds=1)).isoformat()},
            {"status": "revoked"}, {"scope": {}}, {"asset_keys": []},
        ):
            with self.subTest(change=change):
                records = deepcopy(original)
                records[ref].update(change)
                self.store.write("authority.json", records)
                with self.assertRaises(Blocked):
                    self.runner().plan()
        self.assertEqual(self.api.writes, [])

    def test_group_rebinding_does_not_inherit_old_approval(self):
        bindings = self.store.read("bindings.json")
        bindings["groups"]["GROUP-LAB-TEAM"]["id"] = "another-team"
        self.store.write("bindings.json", bindings)
        with self.assertRaises(Blocked):
            self.runner().plan()
        self.assertEqual(self.api.writes, [])

    def test_missing_owner_or_standard_approval_blocks(self):
        original = self.store.read("authority.json")
        for purpose, field in (
            ("ownership", "accountable_owner_id"), ("approval", "approved_standards"),
        ):
            records = deepcopy(original)
            record = next(item for item in records.values() if item["purpose"] == purpose)
            record.pop(field)
            self.store.write("authority.json", records)
            with self.assertRaises(Blocked):
                self.runner().plan()
        self.assertEqual(self.api.writes, [])

    def test_review_for_other_plan_or_executor_is_rejected(self):
        plan = self.runner().plan()
        for change in ({"plan_digest": "bad"}, {"actor": "jira-admin"}, {"status": "pending"}):
            with self.subTest(change=change):
                with self.assertRaises(Blocked):
                    self.runner().apply(plan, dict(self.review(plan), **change))
        self.assertEqual(self.api.writes, [])

    def test_changed_inputs_or_material_target_invalidates_plan(self):
        plan = self.runner().plan()
        prerequisite = self.store.read("prerequisites.json")
        prerequisite[next(iter(prerequisite))]["evidence_ref"] = "fixture:new-proof"
        self.store.write("prerequisites.json", prerequisite)
        with self.assertRaises(Blocked):
            self.runner().apply(plan, self.review(plan))
        self.assertEqual(self.api.writes, [])

    def test_partial_progress_invalidates_old_mutating_plan(self):
        runner = self.runner()
        plan = runner.plan()
        runner.mutate(self.intent["assets"][0], plan["actions"][0])
        with self.assertRaises(Blocked):
            self.runner().apply(plan, self.review(plan))
        self.assertEqual(len(self.api.writes), 1)
        self.apply()  # New plan/review covers only the remaining operations.
        self.assertEqual(len(self.api.writes), 8)

    def test_expired_plan_is_blocked_before_any_write(self):
        plan = self.runner().plan()
        plan["expires_at"] = (NOW - timedelta(seconds=1)).isoformat()
        with self.assertRaises(Blocked):
            self.runner().apply(plan, self.review(plan))
        self.assertEqual(self.api.writes, [])

    def test_source_change_during_apply_stops_next_write(self):
        runner = self.runner()
        plan = runner.plan()
        original = self.api.request
        def change_source(product, role, method, path, body=None):
            result = original(product, role, method, path, body)
            if method == "POST" and product != "organization":
                runner.fingerprints = lambda: dict(runner.inputs, implementation="changed")
            return result
        with patch.object(self.api, "request", side_effect=change_source):
            with self.assertRaises(Blocked):
                runner.apply(plan, self.review(plan))
        self.assertEqual(len(self.api.writes), 1)

    def test_review_revocation_during_apply_stops_next_write(self):
        runner = self.runner()
        plan = runner.plan()
        review = self.review(plan)
        self.store.write("reviews/one.json", review)
        original = self.api.request
        def revoke_review(product, role, method, path, body=None):
            result = original(product, role, method, path, body)
            if method == "POST" and product != "organization":
                self.store.write("reviews/one.json", dict(review, status="revoked"))
            return result
        with patch.object(self.api, "request", side_effect=revoke_review):
            with self.assertRaises(Blocked):
                runner.apply(plan, review, review_path="reviews/one.json")
        self.assertEqual(len(self.api.writes), 1)

    def test_changed_runtime_during_apply_stops_next_write(self):
        plan = self.runner().plan()
        original = self.api.request
        def revoke(product, role, method, path, body=None):
            result = original(product, role, method, path, body)
            if method == "POST" and product != "organization":
                records = self.store.read("authority.json")
                records[next(iter(records))]["status"] = "revoked"
                self.store.write("authority.json", records)
            return result
        with patch.object(self.api, "request", side_effect=revoke):
            with self.assertRaises(Blocked):
                self.runner().apply(plan, self.review(plan))
        self.assertEqual(len(self.api.writes), 1)

    def test_wrong_identity_or_product_binding_blocks(self):
        self.api.bad_identity = True
        with self.assertRaises(Blocked):
            self.runner().plan()
        self.assertEqual(self.api.writes, [])

    def test_missing_product_workspace_blocks_all_mutations(self):
        original = self.api.request
        def missing(product, role, method, path, body=None):
            data, headers = original(product, role, method, path, body)
            if product == "organization":
                data["data"] = data["data"][:1]
                data["meta"]["total"] = 1
            return data, headers
        with patch.object(self.api, "request", side_effect=missing):
            with self.assertRaises(Blocked):
                self.runner().plan()
        self.assertEqual(self.api.writes, [])

    def test_incomplete_permission_collection_never_passes(self):
        self.apply()
        original = self.api.request
        def incomplete(product, role, method, path, body=None):
            data, headers = original(product, role, method, path, body)
            if path.endswith("/permissions"):
                data["meta"] = {"hasMore": True}
            return data, headers
        with patch.object(self.api, "request", side_effect=incomplete):
            with self.assertRaises(Blocked):
                self.runner().plan()
        self.assertEqual(len(self.api.writes), 8)

    def test_native_group_alias_is_rejected(self):
        bindings = self.store.read("bindings.json")
        bindings["groups"]["GROUP-LAB-ADMINS"]["id"] = "g-team"
        self.store.write("bindings.json", bindings)
        with self.assertRaises(Blocked):
            self.runner().plan()
        self.assertEqual(self.api.writes, [])

    def test_incomplete_visibility_and_hostile_pagination_block(self):
        for next_url in (
            "https://attacker.invalid/collect",
            "/wiki/api/v2/spaces?cursor=repeated",
        ):
            with self.subTest(next_url=next_url):
                self.api.pagination = next_url
                with self.assertRaises(Blocked):
                    self.runner().plan()
        self.assertEqual(self.api.writes, [])

    def test_workspace_inventory_is_paginated_read_not_mutation(self):
        self.api.workspace_pages = True
        self.runner().plan()
        self.assertEqual(self.api.writes, [])
        self.assertEqual(sum(call[0] == "organization" for call in self.api.calls), 2)

    def test_invalid_credential_baseline_is_not_denial_proof(self):
        self.apply()
        self.api.baseline_denied = True
        with self.assertRaises(ApiError):
            self.runner().verify()

    def test_denied_user_who_can_read_fails_qualification(self):
        self.apply()
        self.api.allow_denied = True
        with self.assertRaises(Blocked):
            self.runner().verify()

    def test_anonymous_access_fails_qualification(self):
        self.apply()
        self.api.anonymous_enabled = True
        with self.assertRaises(Blocked):
            self.runner().verify()

    def test_new_space_with_group_grant_blocks_before_access_expansion(self):
        plan = self.runner().plan()
        original = self.api.request
        def unsafe_default(product, role, method, path, body=None):
            result = original(product, role, method, path, body)
            if path == "/wiki/rest/api/space/_private" and method == "POST":
                self.api.spaces["LABSPACE"]["permissions"].append({
                    "principal": {"type": "group", "id": "g-team"},
                    "operation": {"key": "read", "targetType": "space"},
                })
            return result
        with patch.object(self.api, "request", side_effect=unsafe_default):
            with self.assertRaises(Blocked):
                self.runner().apply(plan, self.review(plan))
        self.assertEqual(len(self.api.writes), 1)

    def test_scheme_readback_blocks_project_on_undeclared_grant(self):
        plan = self.runner().plan()
        original = self.api.request
        def unsafe_default(product, role, method, path, body=None):
            result = original(product, role, method, path, body)
            if path == "/rest/api/3/permissionscheme" and method == "POST":
                next(iter(self.api.schemes.values()))["permissions"].append({
                    "holder": {"type": "anyone"}, "permission": "BROWSE_PROJECTS",
                })
            return result
        with patch.object(self.api, "request", side_effect=unsafe_default):
            with self.assertRaises(Blocked):
                self.runner().apply(plan, self.review(plan))
        self.assertEqual(len(self.api.projects), 0)

    def test_empty_visible_space_list_without_absence_proof_blocks(self):
        prerequisites = self.store.read("prerequisites.json")
        prerequisites["fixture:bootstrap-products"]["unused_confluence_keys"] = []
        self.store.write("prerequisites.json", prerequisites)
        with self.assertRaises(Blocked):
            self.runner().plan()
        self.assertEqual(self.api.writes, [])

    def test_unsupported_confluence_permission_model_blocks(self):
        bindings = self.store.read("bindings.json")
        bindings["products"]["confluence"]["permission_model"] = "rbac"
        self.store.write("bindings.json", bindings)
        with self.assertRaises(Blocked):
            self.runner().plan()

    def test_duplicate_schema_input_and_unsupported_scope_rejected(self):
        for modify in (
            lambda value: value.update(environment="production"),
            lambda value: value["assets"][0]["configuration"].update(unknown=True),
            lambda value: value["assets"][0].update(managed_properties=["classification_default"]),
            lambda value: value["assets"][1].update(kind="confluence_space"),
        ):
            config = deepcopy(self.intent)
            modify(config)
            with self.assertRaises((ValueError, Blocked)):
                check_config(config)

    def test_evidence_is_private_separate_and_has_no_credential_values(self):
        with patch.dict(os.environ, {"ATLASSIAN_LAB_JIRA_ADMIN_TOKEN": "TOP-SECRET"}):
            self.apply()
        runs = list((self.directory / "runs").iterdir())
        self.assertEqual(len(runs), 1)
        for path in self.directory.rglob("*"):
            self.assertEqual(path.stat().st_mode & 0o077, 0)
            if path.is_file():
                self.assertNotIn("TOP-SECRET", path.read_text())
        self.apply()
        self.assertEqual(len(list((self.directory / "runs").iterdir())), 2)

    def test_runtime_inside_git_symlink_and_unsafe_permissions_rejected(self):
        with self.assertRaises(Blocked):
            Store(ROOT / "runtime", create=True)
        link = Path(self.temporary.name) / "linked"
        link.symlink_to(self.directory)
        with self.assertRaises(Blocked):
            Store(link)
        (self.directory / "bad.json").symlink_to(Path(self.temporary.name) / "outside")
        with self.assertRaises(Blocked):
            self.store.write("bad.json", {})
        self.directory.chmod(0o755)
        with self.assertRaises(Blocked):
            Store(self.directory)
        self.directory.chmod(0o700)

    def test_concurrent_local_execution_is_blocked(self):
        with self.store.locked():
            with self.assertRaises(Blocked):
                with Store(self.directory).locked():
                    self.fail("Second lock acquired")

    def test_no_live_opt_in_and_unsafe_http_destination_are_blocked(self):
        with self.assertRaises(Blocked):
            Http(self.bindings)
        self.assertEqual(main(["plan", "--runtime", str(self.directory)]), 1)
        http = Http(self.bindings, live=True)
        for path in ("https://attacker.invalid", "//attacker.invalid", "/unreviewed"):
            with self.assertRaises(Blocked):
                http.request("jira", "admin", "GET", path)
        with self.assertRaises(Blocked):
            http.request("jira", "allowed", "POST", "/rest/api/3/project", {})

    def test_http_errors_hide_secret_response_and_do_not_retry(self):
        http = Http(self.bindings, live=True)
        header_secret = "SYNTHETIC-SECRET"
        error = HTTPError(
            "https://replace.atlassian.net/rest/api/3/myself", 401,
            "hidden", {}, io.BytesIO(header_secret.encode()),
        )
        with patch.dict(os.environ, {
            "ATLASSIAN_LAB_JIRA_ADMIN_EMAIL": "synthetic@example.invalid",
            "ATLASSIAN_LAB_JIRA_ADMIN_TOKEN": header_secret,
        }), patch.object(http.opener, "open", side_effect=error) as opener:
            with self.assertRaises(ApiError) as failure:
                http.request("jira", "admin", "GET", "/rest/api/3/myself")
            self.assertNotIn(header_secret, str(failure.exception))
            self.assertEqual(opener.call_count, 1)

    def test_all_cli_stages_and_rerun_work_with_fake_transport(self):
        args = ["--runtime", str(self.directory), "--live"]
        with patch("automation.lab.Http", return_value=self.api), \
             patch("automation.lab.utcnow", return_value=NOW), \
             redirect_stdout(io.StringIO()) as output:
            self.assertEqual(main(["plan", *args]), 0)
            planned = json.loads(output.getvalue())
            plan_path = Path(planned["evidence"]) / "plan.json"
            plan = self.store.read(str(plan_path.relative_to(self.directory)))
            self.store.write("reviews/cli.json", self.review(plan))
            apply_args = [
                "apply", *args, "--plan", str(plan_path),
                "--review", str(self.directory / "reviews/cli.json"),
            ]
            self.assertEqual(main(apply_args), 0)
            self.assertEqual(main(["verify", *args]), 0)
            self.assertEqual(main(apply_args), 0)
        self.assertEqual(len(self.api.writes), 8)
        for path in (self.directory / "runs").iterdir():
            self.assertTrue((path / "report.json").exists())
            self.assertTrue((path / "report.md").exists())


if __name__ == "__main__":
    unittest.main()

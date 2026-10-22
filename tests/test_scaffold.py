"""These tests validate the scaffold, not policy decisions or tenant controls."""

import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tools.validate import ROOT, ScaffoldError, load_document, validate_document, validate_repository


class ScaffoldTests(unittest.TestCase):
    def setUp(self):
        self.asset = load_document(ROOT / "environments/lab/assets/example-confluence-space.yaml")

    def validate_value(self, value, schema):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.json"
            path.write_text(json.dumps(value), encoding="utf-8")
            return validate_document(path, schema)

    def test_repository_is_structurally_valid(self):
        result = validate_repository()
        self.assertEqual(result["control_entries"], 52)
        self.assertEqual(result["parameter_groups"], 22)
        self.assertEqual(result["live_control_tests"], 0)
        self.assertEqual(result["policy_decisions_evaluated"], 0)

    def test_missing_application_reference_rejected_by_schema(self):
        del self.asset["business_application_ref"]
        with self.assertRaises(ScaffoldError):
            self.validate_value(self.asset, "asset-intent.schema.json")

    def test_approval_boolean_shortcut_rejected_by_schema(self):
        self.asset["approved"] = True
        with self.assertRaises(ScaffoldError):
            self.validate_value(self.asset, "asset-intent.schema.json")

    def test_missing_approval_reference_rejected_by_schema(self):
        del self.asset["authority_refs"]["approval"]
        with self.assertRaises(ScaffoldError):
            self.validate_value(self.asset, "asset-intent.schema.json")

    def test_real_data_example_rejected_by_scaffold_contract(self):
        self.asset["synthetic"] = False
        with self.assertRaises(ScaffoldError):
            self.validate_value(self.asset, "asset-intent.schema.json")

    def test_production_environment_rejected_by_scaffold_contract(self):
        self.asset["environment"] = "production"
        with self.assertRaises(ScaffoldError):
            self.validate_value(self.asset, "asset-intent.schema.json")

    def test_deletion_authority_rejected_in_scaffold(self):
        self.asset["deletion_authorized"] = True
        with self.assertRaises(ScaffoldError):
            self.validate_value(self.asset, "asset-intent.schema.json")

    def test_environment_cannot_be_enabled_by_changing_a_flag(self):
        binding = load_document(ROOT / "environments/lab/bindings.yaml")
        binding["remote_operations_authorized"] = True
        with self.assertRaises(ScaffoldError):
            self.validate_value(binding, "environment-bindings.schema.json")

    def test_arbitrary_credentials_rejected_in_asset(self):
        self.asset["api_token"] = "synthetic-not-a-real-token"
        with self.assertRaises(ScaffoldError):
            self.validate_value(self.asset, "asset-intent.schema.json")

    def test_source_record_requires_provenance(self):
        record = load_document(ROOT / "tests/fixtures/authority/approval.json")
        del record["source"]
        with self.assertRaises(ScaffoldError):
            self.validate_value(record, "authoritative-input.schema.json")

    def test_invalid_datetime_rejected(self):
        record = load_document(ROOT / "tests/fixtures/authority/approval.json")
        record["observed_at"] = "not-a-time"
        with self.assertRaises(ScaffoldError):
            self.validate_value(record, "authoritative-input.schema.json")

    def test_profile_preserves_core_values(self):
        profile = load_document(ROOT / "governance/profiles/fs-collab-01.yaml")
        p = profile["parameters"]
        self.assertEqual(profile["status"], "assumed")
        self.assertFalse(profile["production_approved"])
        self.assertEqual(p["P-02"]["human_elevation_max"], {"value": 1, "unit": "hours"})
        self.assertEqual(p["P-03"]["sensitive_review_interval"]["value"], 3)
        self.assertEqual(p["P-03"]["standard_internal_review_interval"]["value"], 6)
        self.assertEqual(p["P-04"]["compromised_or_urgent_leaver_revocation"]["value"], 15)
        self.assertEqual(p["P-04"]["routine_revocation"], {"value": 4, "unit": "hours"})
        self.assertEqual(p["P-06"]["external_access_max"], {"value": 30, "unit": "days"})
        self.assertEqual(p["P-08"]["supported_product_data_region"], "EU")
        self.assertEqual(p["P-10"]["sensitive_independent_technical_reviewers"], 2)
        self.assertEqual(p["P-12"]["critical_security_observation_max"]["value"], 15)
        self.assertIsNone(p["P-13"]["per_source_maximum_age"])
        self.assertEqual(p["P-14"]["high_risk_exception_max"]["value"], 7)
        self.assertEqual(p["P-16"]["operational_logs_searchable"]["value"], 90)
        self.assertEqual(p["P-16"]["operational_logs_total_protected"]["value"], 365)
        self.assertEqual(p["P-17"]["decision_evidence_retention"]["value"], 7)
        self.assertEqual(p["P-18"]["collection_failure_detection_max"]["value"], 5)
        self.assertEqual(p["P-18"]["notify_after_known_failure"], "immediate")
        self.assertEqual(p["P-19"]["rto"]["value"], 24)
        self.assertEqual(p["P-19"]["rpo"]["value"], 24)
        self.assertEqual(p["P-20"]["critical_triage_max"]["value"], 15)
        self.assertEqual(p["P-20"]["critical_containment_target"]["value"], 1)
        self.assertEqual(p["P-21"]["remediation_days"], {"critical": 7, "high": 14, "medium": 30, "low": 90})
        self.assertEqual(p["P-22"]["non_production_data"], "synthetic_only")

    def test_profile_cannot_be_relabelled_approved(self):
        profile = copy.deepcopy(load_document(ROOT / "governance/profiles/fs-collab-01.yaml"))
        profile["status"] = "approved"
        with self.assertRaises(ScaffoldError):
            self.validate_value(profile, "profile.schema.json")

    def test_duplicate_yaml_keys_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "duplicate.yaml"
            path.write_text("status: assumed\nstatus: approved\n", encoding="utf-8")
            with self.assertRaises(ScaffoldError):
                load_document(path)

    def test_duplicate_json_keys_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "duplicate.json"
            path.write_text('{"status":"assumed","status":"approved"}', encoding="utf-8")
            with self.assertRaises(ScaffoldError):
                load_document(path)

    def test_remote_commands_are_blocked_even_with_enable_environment(self):
        import os
        environment = dict(os.environ, ENABLE_LIVE="true", CONFIRM="true")
        for command in ["plan", "apply", "verify", "observe"]:
            with self.subTest(command=command):
                result = subprocess.run(
                    [sys.executable, str(ROOT / "tools/not_configured.py"), command],
                    capture_output=True, text=True, check=False, env=environment,
                )
                self.assertEqual(result.returncode, 2)
                payload = json.loads(result.stdout)
                self.assertEqual(payload["result"], "blocked")
                self.assertEqual(payload["tenant_api_calls"], 0)

    def test_status_reports_unconfigured(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / "tools/not_configured.py"), "status"],
            capture_output=True, text=True, check=True,
        )
        self.assertEqual(json.loads(result.stdout)["result"], "unconfigured")

    def test_evidence_fixture_does_not_claim_a_live_pass(self):
        record = load_document(ROOT / "tests/fixtures/evidence/untested.json")
        self.assertEqual(record["evidence_type"], "schema_fixture")
        self.assertTrue(record["synthetic"])
        self.assertEqual(record["result"], "untested")
        self.assertEqual(record["observations"], [])


if __name__ == "__main__":
    unittest.main()

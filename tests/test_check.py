"""Input-validation tests only, not executable policy or live control acceptance."""

import copy
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from scripts.check import ROOT, check, check_config, load


class InputTests(unittest.TestCase):
    def setUp(self):
        self.config = load(ROOT / "config/lab.yaml")

    def test_current_inputs(self):
        result = check()
        self.assertEqual((result["controls"], result["parameter_groups"], result["assets"]), (52, 22, 2))
        self.assertEqual(result["scope"], "offline_structure_only")

    def test_missing_asset_authority_and_scope(self):
        for field in ["business_application_ref", "requested_classification",
                      "audience_group_refs", "authority_refs", "managed_properties"]:
            with self.subTest(field=field):
                config = copy.deepcopy(self.config)
                del config["assets"][0][field]
                with self.assertRaises(ValueError):
                    check_config(config)
        for field in ["application", "ownership", "classification", "approval"]:
            with self.subTest(authority=field):
                config = copy.deepcopy(self.config)
                del config["assets"][0]["authority_refs"][field]
                with self.assertRaises(ValueError):
                    check_config(config)

    def test_no_production_real_data_or_deletion(self):
        for field, value in [("environment", "production"), ("synthetic", False),
                             ("deletion_authorized", True)]:
            with self.subTest(field=field):
                config = copy.deepcopy(self.config)
                config[field] = value
                with self.assertRaises(ValueError):
                    check_config(config)

    def test_no_approval_shortcuts_or_credentials(self):
        for field, value in [("approved", True), ("api_token", "not-a-real-token")]:
            with self.subTest(field=field):
                config = copy.deepcopy(self.config)
                config["assets"][0][field] = value
                with self.assertRaises(ValueError):
                    check_config(config)

    def test_authority_refs_are_only_synthetic_placeholders(self):
        self.config["assets"][0]["authority_refs"]["approval"] = "production:approval-001"
        with self.assertRaises(ValueError):
            check_config(self.config)

    def test_wrong_product_property_rejected(self):
        self.config["assets"][0]["managed_properties"].append("permission_scheme")
        with self.assertRaises(ValueError):
            check_config(self.config)

    def test_product_standards_rejected_when_weakened(self):
        for index, field, value in [(0, "initial_visibility", "public"),
                                     (1, "management_type", "team_managed")]:
            with self.subTest(field=field):
                config = copy.deepcopy(self.config)
                config["assets"][index][field] = value
                with self.assertRaises(ValueError):
                    check_config(config)

    def test_profile_and_control_tampering_rejected(self):
        for target, old, new in [
            ("config/profile.yaml", "status: assumed", "status: approved"),
            ("config/profile.yaml", "human_mfa_required: true", "human_mfa_required: false"),
            ("controls.yaml", "  AIS-07: [P-21]\n", ""),
            ("controls.yaml", "  AIS-07: [P-21]", "  AIS-07: [P-99]"),
            ("controls.yaml", "acceptance: untested", "acceptance: passed"),
        ]:
            with self.subTest(target=target, change=new), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                shutil.copytree(ROOT / "config", root / "config")
                shutil.copyfile(ROOT / "controls.yaml", root / "controls.yaml")
                path = root / target
                path.write_text(path.read_text(encoding="utf-8").replace(old, new), encoding="utf-8")
                with self.assertRaises(ValueError):
                    check(root)

    def test_unknown_foundation_property_rejected(self):
        self.config["foundation"]["managed_properties"].append("unsupported_private_api")
        with self.assertRaises(ValueError):
            check_config(self.config)

    def test_duplicate_asset_rejected(self):
        self.config["assets"].append(copy.deepcopy(self.config["assets"][0]))
        with self.assertRaises(ValueError):
            check_config(self.config)

    def test_duplicate_mapping_keys_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            for contents in ['status: assumed\nstatus: approved\n',
                             '{"status":"assumed","status":"approved"}']:
                path = Path(directory) / "duplicate.yaml"
                path.write_text(contents, encoding="utf-8")
                with self.assertRaises(ValueError):
                    load(path)

    def test_no_fake_execution_commands(self):
        for command in ["plan", "apply", "verify", "observe"]:
            with self.subTest(command=command):
                result = subprocess.run(
                    [sys.executable, str(ROOT / "scripts/check.py"), command],
                    capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()

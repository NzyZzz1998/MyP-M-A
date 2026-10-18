"""Synthetic targeted installer tests; never touch real host skills or the network."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import provider_dependencies as deps


class DependencyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / "mypm"
        self.skills = self.base / "host-skills"
        for folder in (self.root / "capabilities", self.root / "scripts", self.skills):
            folder.mkdir(parents=True)
        (self.root / "SKILL.md").write_text("version-one", encoding="utf-8")
        (self.root / "scripts/provider_dependencies.py").write_text("synthetic-runtime", encoding="utf-8")
        self.raw = {"SKILL.md": b"old-header\n# Body\nSample\n", "LICENSE": b"synthetic MIT fixture"}
        self.final = b"new-header\n# Body\nSample\n"
        self.item = {"id": "domain-fixture", "folder": "domain-fixture", "repo": "mattpocock/skills",
                     "commit": "a" * 40, "license": "MIT", "agent_policy": "policy:\n  allow_implicit_invocation: false\n",
                     "files": {name: {"source": name, "download_sha256": deps.sha(raw),
                                      "installed_sha256": deps.sha(self.final if name == "SKILL.md" else raw)}
                               for name, raw in self.raw.items()}}
        self.item["files"]["SKILL.md"]["adaptation"] = {"body_marker": "# Body\n", "prefix": "new-header\n"}
        self.data = {"schema_version": 1, "dependencies": [self.item], "manual_only": ["ocr"], "bundled": ["matt"]}
        self.registry = {"providers": [{"id": "domain-fixture", "folder": "domain-fixture", "kind": "installed-file-adapter",
                                         "upstream_commit": "a" * 40, "required_files": ["SKILL.md"],
                                         "entry_sha256": deps.sha(self.final)}]}
        self.write_data()
        self.calls = []

    def write_data(self):
        (self.root / "capabilities/dependency-lock.json").write_text(json.dumps(self.data), encoding="utf-8")
        (self.root / "capabilities/provider-registry.json").write_text(json.dumps(self.registry), encoding="utf-8")

    def enable(self):
        return deps.enable(self.root, self.skills, [self.item["id"]], True)

    def fetch(self, url):
        self.calls.append(url)
        self.assertTrue(url.startswith("https://raw.githubusercontent.com/mattpocock/skills/" + "a" * 40 + "/"))
        return self.raw[url.rsplit("/", 1)[-1]]

    def sync(self, **kwargs):
        return deps.sync(self.root, fetch=self.fetch, **kwargs)

    def test_default_off_no_storage_or_download(self):
        self.assertEqual(self.sync()["status"], "disabled")
        self.assertEqual(self.calls, [])
        self.assertFalse((self.root / deps.STATE).exists())

    def test_enable_requires_explicit_consent(self):
        for consent in (False, "true", 1):
            with self.subTest(consent=consent), self.assertRaises(ValueError):
                deps.enable(self.root, self.skills, [self.item["id"]], consent)

    def test_unknown_cli_cannot_be_auto_installed(self):
        with self.assertRaises(ValueError):
            deps.enable(self.root, self.skills, ["ocr"], True)

    def test_inventory_never_downloads(self):
        self.assertEqual(deps.inventory(self.data, self.skills)[0]["status"], "missing")
        self.assertEqual(self.calls, [])

    def test_real_files_installed_with_policy_and_license(self):
        self.enable()
        self.assertEqual(self.sync()["status"], "complete")
        target = self.skills / self.item["folder"]
        self.assertEqual((target / "SKILL.md").read_bytes(), self.final)
        self.assertEqual((target / "LICENSE").read_bytes(), self.raw["LICENSE"])
        self.assertIn("allow_implicit_invocation: false", (target / "agents/openai.yaml").read_text())
        self.assertEqual(len(self.calls), 2)

    def test_same_version_has_no_repeated_network(self):
        self.enable()
        self.sync()
        self.calls.clear()
        self.assertEqual(self.sync()["status"], "already_checked")
        self.assertEqual(self.calls, [])

    def test_update_checks_missing_but_preserves_existing(self):
        self.enable()
        self.sync()
        (self.root / "SKILL.md").write_text("version-two")
        self.calls.clear()
        self.assertEqual(self.sync()["status"], "complete")
        self.assertEqual(self.calls, [])

    def test_existing_directory_even_empty_is_not_overwritten(self):
        self.enable()
        target = self.skills / self.item["folder"]
        target.mkdir()
        result = self.sync()
        self.assertEqual(result["dependencies"][0]["status"], "existing_conflict")
        self.assertEqual(list(target.iterdir()), [])
        self.assertEqual(self.calls, [])

    def test_hash_mismatch_publishes_nothing(self):
        self.enable()
        result = deps.sync(self.root, fetch=lambda _: b"wrong")
        self.assertEqual(result["status"], "partial")
        self.assertEqual(result["dependencies"][0]["failure_phase"], "download_and_verify")
        self.assertEqual(result["dependencies"][0]["error_code"], "download_hash_mismatch")
        self.assertFalse((self.skills / self.item["folder"]).exists())

    def test_failed_attempt_requires_explicit_retry(self):
        self.enable()
        deps.sync(self.root, fetch=lambda _: b"wrong")
        self.assertEqual(self.sync()["status"], "already_checked")
        self.assertEqual(self.calls, [])
        self.assertEqual(self.sync(retry=True)["status"], "complete")

    def test_changed_catalog_requires_reauthorization(self):
        self.enable()
        self.item["agent_policy"] += "# New package\n"
        self.write_data()
        self.assertEqual(self.sync()["dependencies"][0]["status"], "consent_required")
        self.assertEqual(self.calls, [])

    def test_configuration_not_portable_authorization(self):
        self.enable()
        cfg = deps.read(self.root / deps.CONFIG)
        cfg["skill_root"] = str(self.base)
        (self.root / deps.CONFIG).write_text(json.dumps(cfg))
        with self.assertRaises(ValueError):
            self.sync()

    def test_revocation_during_download_publishes_nothing(self):
        self.enable()
        def revoke(url):
            cfg = deps.read(self.root / deps.CONFIG)
            cfg["enabled"] = False
            (self.root / deps.CONFIG).write_text(json.dumps(cfg))
            return self.fetch(url)
        result = deps.sync(self.root, fetch=revoke)
        self.assertEqual(result["status"], "partial")
        self.assertFalse((self.skills / self.item["folder"]).exists())

    def test_concurrent_owner_lock_does_not_install(self):
        self.enable()
        (self.root / deps.LOCK).write_text("other owner")
        self.assertEqual(self.sync()["status"], "busy")
        self.assertEqual(self.calls, [])
        self.assertTrue((self.root / deps.LOCK).exists())

    def test_path_escape_and_floating_commit_rejected(self):
        for key, value in (("folder", "../escape"), ("commit", "main"), ("repo", "other/repo")):
            original = self.item[key]
            self.item[key] = value
            self.write_data()
            with self.subTest(key=key), self.assertRaises(ValueError):
                deps.catalog(self.root)
            self.item[key] = original
        self.write_data()

    def test_source_escape_rejected(self):
        self.item["files"]["SKILL.md"]["source"] = "../outside"
        self.write_data()
        with self.assertRaises(ValueError):
            deps.catalog(self.root)

    def test_destination_must_not_be_inside_skill(self):
        with self.assertRaises(ValueError):
            deps.enable(self.root, self.root, [self.item["id"]], True)

    def test_corrupt_existing_file_is_preserved(self):
        self.enable()
        self.sync()
        target = self.skills / self.item["folder"] / "SKILL.md"
        target.write_text("user modification")
        result = self.sync(retry=True)
        self.assertEqual(result["dependencies"][0]["status"], "existing_conflict")
        self.assertEqual(target.read_text(), "user modification")

    def test_write_failure_leaves_explicit_partial_not_success(self):
        self.enable()
        original = Path.open
        def failing(path, *args, **kwargs):
            if path == self.skills / self.item["folder"] / "SKILL.md":
                raise OSError("synthetic disk failure")
            return original(path, *args, **kwargs)
        with patch.object(Path, "open", failing):
            result = self.sync()
        self.assertEqual(result["dependencies"][0]["status"], "failed")
        self.assertEqual(result["dependencies"][0]["failure_phase"], "publish_new_directory")
        self.assertFalse((self.skills / self.item["folder"] / "SKILL.md").exists())

    def test_local_switch_does_not_enable_memory(self):
        self.enable()
        self.sync()
        self.assertFalse((self.root / ".mypm.local.json").exists())

    def test_invalid_config_is_rejected_without_network(self):
        for value in ([], None, True):
            (self.root / deps.CONFIG).write_text(json.dumps(value))
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.sync()
        self.assertEqual(self.calls, [])

    def test_large_existing_file_is_not_loaded_or_overwritten(self):
        self.enable()
        self.sync()
        target = self.skills / self.item["folder"] / "SKILL.md"
        target.write_bytes(b"x" * (deps.MAX_BYTES + 1))
        original = Path.read_bytes
        def guarded(path):
            if path == target:
                raise AssertionError("unbounded file read")
            return original(path)
        with patch.object(Path, "read_bytes", guarded):
            result = self.sync(retry=True)
        self.assertEqual(result["dependencies"][0]["status"], "existing_conflict")

    def test_invocation_policy_is_required(self):
        self.item["agent_policy"] = "policy:\n  allow_implicit_invocation: true\n"
        self.write_data()
        with self.assertRaises(ValueError):
            deps.catalog(self.root)


if __name__ == "__main__":
    unittest.main(verbosity=2)

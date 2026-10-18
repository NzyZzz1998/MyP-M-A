"""Real disposable Git repositories; no production source or model calls."""

import io
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import review_snapshot as snapshot


class SnapshotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.clean)
        self.folder = Path(self.temp.name)
        self.repo = self.folder / "repo"
        self.repo.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Synthetic Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "core.autocrlf", "false")
        self.write("main.py", "value = 1\n")
        self.git("add", ".")
        self.git("-c", "core.hooksPath=", "commit", "-qm", "fixture baseline")
        self.base = self.git("rev-parse", "HEAD").strip()

    def clean(self):
        def writable(func, path, error):
            os.chmod(path, stat.S_IWRITE)
            func(path)
        root = Path(self.temp.name).resolve()
        if root.parent != Path(tempfile.gettempdir()).resolve() or not root.name.startswith("tmp"):
            raise AssertionError("unsafe_fixture_cleanup")
        shutil.rmtree(root, onerror=writable)
        self.temp.cleanup()

    def git(self, *args):
        result = subprocess.run(["git", "-C", str(self.repo), *args], capture_output=True,
                                text=True, encoding="utf-8", timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def write(self, name, text):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="")

    def freeze(self, target="working", excludes=()):
        output = self.folder / "evidence"
        manifest = snapshot.freeze(self.repo, self.base, target, output, excludes)
        return manifest, output / "manifest.json"

    def test_four_layers_without_source_mutation(self):
        self.write("main.py", "value = 2\n")
        self.git("add", ".")
        self.git("-c", "core.hooksPath=", "commit", "-qm", "fixture committed change")
        self.write("main.py", "value = 3\n")
        self.git("add", ".")
        self.write("main.py", "value = 4\n")
        self.write("new file.py", "new = True\n")
        before = self.git("status", "--porcelain=v1")
        head = self.git("rev-parse", "HEAD")
        index = (self.repo / ".git/index").read_bytes()
        manifest, path = self.freeze()
        self.assertEqual({u["layer"] for u in manifest["units"]}, {"committed", "staged", "unstaged", "untracked"})
        self.assertEqual(self.git("status", "--porcelain=v1"), before)
        self.assertEqual(self.git("rev-parse", "HEAD"), head)
        self.assertEqual((self.repo / ".git/index").read_bytes(), index)
        self.assertTrue(snapshot.freshness(path)["fresh"])

    def test_dirty_only_is_not_empty(self):
        self.write("main.py", "value = 2\n")
        manifest, _ = self.freeze()
        self.assertEqual(len(manifest["units"]), 1)
        self.assertEqual(manifest["units"][0]["layer"], "unstaged")

    def test_empty_scope_valid_no_fabricated_findings(self):
        manifest, path = self.freeze()
        self.assertEqual(manifest["units"], [])
        self.assertTrue(snapshot.freshness(path)["fresh"])

    def test_staged_target_excludes_worktree(self):
        self.write("main.py", "value = 2\n")
        self.git("add", "main.py")
        self.write("main.py", "value = 3\n")
        self.write("new.py", "outside_selected_target = True\n")
        manifest, path = self.freeze("index")
        self.assertEqual([u["layer"] for u in manifest["units"]], ["staged"])
        unit = manifest["units"][0]
        self.assertEqual((path.parent / "units" / unit["id"] / "after.txt").read_text(), "value = 2\n")
        self.write("main.py", "value = 4\n")
        self.assertTrue(snapshot.freshness(path)["fresh"])

    def test_head_target_ignores_dirty(self):
        self.write("main.py", "value = 3\n")
        manifest, _ = self.freeze("head")
        self.assertEqual(manifest["units"], [])

    def test_staged_deletion_untracked_recreation_kept_separate(self):
        self.git("rm", "main.py")
        self.write("main.py", "replacement = True\n")
        manifest, _ = self.freeze()
        self.assertEqual({(u["layer"], u["status"]) for u in manifest["units"]}, {("staged", "D"), ("untracked", "A")})
        self.assertEqual(len({u["id"] for u in manifest["units"]}), 2)

    def test_cancelling_layers_are_preserved(self):
        self.write("main.py", "value = 2\n")
        self.git("add", "main.py")
        self.write("main.py", "value = 1\n")
        manifest, _ = self.freeze()
        self.assertEqual(len(manifest["units"]), 2)

    def test_rename_both_ends(self):
        self.git("mv", "main.py", "renamed.py")
        manifest, _ = self.freeze()
        self.assertEqual({(u["path"], u["status"]) for u in manifest["units"]}, {("main.py", "D"), ("renamed.py", "A")})

    def test_unicode_and_space_paths(self):
        name = "folder/\u95ee\u5377 sample.py"
        self.write(name, "answer = None\n")
        manifest, path = self.freeze()
        self.assertEqual(manifest["units"][0]["path"], name)
        self.assertEqual(snapshot.load_manifest(path)["snapshot_sha256"], manifest["snapshot_sha256"])

    def test_sensitive_binary_large_and_explicit_excludes(self):
        self.write(".env", "DO_NOT_COPY=private\n")
        self.write("secret.py", "api_key = 'sk-" + "z" * 24 + "'\n")
        (self.repo / "binary.dat").write_bytes(b"\0\1\2")
        self.write("big.txt", "a" * (snapshot.MAX_BYTES + 1))
        self.write("generated/file.py", "code = 1\n")
        manifest, path = self.freeze(excludes=["generated/*"])
        reasons = {u["path"]: u["skip_reason"] for u in manifest["units"]}
        self.assertEqual(reasons, {".env": "sensitive_path", "secret.py": "sensitive_content",
                                  "binary.dat": "binary", "big.txt": "file_too_large",
                                  "generated/file.py": "excluded_pattern"})
        self.assertFalse((path.parent / "units").exists())

    def test_ignored_file_not_read_or_exported(self):
        self.write(".gitignore", "ignored.txt\n")
        self.write("ignored.txt", "private ignored content\n")
        manifest, _ = self.freeze()
        self.assertNotIn("ignored.txt", [u["path"] for u in manifest["units"]])

    def test_relevant_change_invalidates_only_changed_units(self):
        self.write("main.py", "value = 2\n")
        self.write("other.py", "other = True\n")
        manifest, path = self.freeze()
        self.write("main.py", "value = 3\n")
        result = snapshot.freshness(path)
        self.assertFalse(result["fresh"])
        self.assertEqual(len(result["changed_or_removed_units"]), 1)
        self.assertEqual(len(result["unchanged_units"]), 1)

    def test_new_scope_cannot_inherit_old_coverage(self):
        self.write("main.py", "value = 2\n")
        _, path = self.freeze()
        self.write("later.py", "new = True\n")
        result = snapshot.freshness(path)
        self.assertFalse(result["fresh"])
        self.assertEqual(len(result["new_units"]), 1)

    def test_snapshot_blob_tampering(self):
        self.write("main.py", "value = 2\n")
        manifest, path = self.freeze()
        (path.parent / "units" / manifest["units"][0]["id"] / "after.txt").write_text("different")
        with self.assertRaisesRegex(ValueError, "snapshot_blob_changed"):
            snapshot.load_manifest(path)

    def test_diff_tampering(self):
        self.write("main.py", "value = 2\n")
        manifest, path = self.freeze()
        (path.parent / "units" / manifest["units"][0]["id"] / "change.diff").write_text("fake diff")
        with self.assertRaisesRegex(ValueError, "snapshot_diff_changed"):
            snapshot.load_manifest(path)

    def test_mode_only_change_has_identity(self):
        self.git("update-index", "--chmod=+x", "main.py")
        manifest, _ = self.freeze("index")
        unit = manifest["units"][0]
        self.assertEqual(unit["before_mode"], "100644")
        self.assertEqual(unit["after_mode"], "100755")

    def test_worktree_respects_git_filemode_false(self):
        self.git("config", "core.filemode", "false")
        self.git("update-index", "--chmod=+x", "main.py")
        self.write("main.py", "value = 2\n")
        manifest, _ = self.freeze()
        unit = next(u for u in manifest["units"] if u["layer"] == "unstaged")
        self.assertEqual(unit["before_mode"], "100755")
        self.assertEqual(unit["after_mode"], "100755")

    def test_json_credential_is_not_exported(self):
        self.write("config.json", '{"password": "synthetic-only-password"}')
        manifest, path = self.freeze()
        self.assertEqual(manifest["units"][0]["skip_reason"], "sensitive_content")
        self.assertFalse((path.parent / "units").exists())

    def test_unset_filemode_uses_git_default(self):
        self.git("config", "--unset-all", "core.filemode")
        self.write("main.py", "value = 2\n")
        manifest, _ = self.freeze()
        mode = "100755" if (self.repo / "main.py").stat().st_mode & stat.S_IXUSR else "100644"
        self.assertEqual(manifest["units"][0]["after_mode"], mode)

    def test_filemode_true_uses_filesystem_mode(self):
        self.git("config", "core.filemode", "true")
        self.write("main.py", "value = 2\n")
        data, reason, mode = snapshot.file_bytes(self.repo, "worktree", "main.py")
        self.assertIsNone(reason)
        self.assertEqual(data, b"value = 2\n")
        self.assertEqual(mode, "100755" if (self.repo / "main.py").stat().st_mode & stat.S_IXUSR else "100644")

    def test_invalid_filemode_is_not_silently_defaulted(self):
        self.git("config", "core.filemode", "invalid-boolean")
        with self.assertRaisesRegex(ValueError, "git_failed"):
            snapshot.file_bytes(self.repo, "worktree", "main.py")

    def test_no_newline_diff_is_unambiguous(self):
        self.assertIn(b"\\ No newline at end of file", snapshot.difference("f", b"old", b"new"))

    def test_manifest_tampering(self):
        manifest, path = self.freeze()
        manifest["target"] = "index"
        path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, "manifest_tampered"):
            snapshot.load_manifest(path)

    def test_output_inside_source_rejected(self):
        with self.assertRaisesRegex(ValueError, "outside_repository"):
            snapshot.freeze(self.repo, self.base, "working", self.repo / "evidence")

    def test_existing_output_not_overwritten(self):
        self.freeze()
        with self.assertRaisesRegex(ValueError, "outside_repository"):
            self.freeze()

    def test_invalid_ref_and_path_rejected(self):
        for ref in ("--help", "does-not-exist"):
            with self.subTest(ref=ref), self.assertRaises(ValueError):
                snapshot.collect(self.repo, ref)
        for name in ("../outside", "/outside", "C:/outside", "..\\outside"):
            with self.subTest(path=name), self.assertRaises(ValueError):
                snapshot.safe_relative(name)

    def report(self, manifest):
        return {"snapshot_sha256": manifest["snapshot_sha256"], "provider": "matt-code-review-adapter",
                "identity": "current-agent/non-independent",
                "coverage": [{"id": u["id"], "state": "skipped" if u["skip_reason"] else "reviewed",
                              "reason": u["skip_reason"] or ""} for u in manifest["units"]]}

    def test_coverage_preserves_skipped_and_is_not_acceptance(self):
        self.write("main.py", "value = 2\n")
        self.write(".env", "private")
        manifest, _ = self.freeze()
        result = snapshot.coverage(manifest, self.report(manifest))
        self.assertEqual(result["counts"], {"reviewed": 1, "skipped": 1, "failed": 0})
        self.assertIn("not-semantic", result["evidence_level"])

    def test_coverage_missing_duplicate_and_unknown_ids(self):
        self.write("main.py", "value = 2\n")
        self.write("other.py", "other = True\n")
        manifest, _ = self.freeze()
        report = self.report(manifest)
        first = report["coverage"][0]
        for items in ([], [first, first], [dict(first, id="unknown"), report["coverage"][1]]):
            with self.subTest(items=items), self.assertRaises(ValueError):
                snapshot.coverage(manifest, dict(report, coverage=items))

    def test_skip_requires_reason(self):
        self.write("main.py", "value = 2\n")
        manifest, _ = self.freeze()
        report = self.report(manifest)
        report["coverage"][0]["state"] = "skipped"
        with self.assertRaises(ValueError):
            snapshot.coverage(manifest, report)

    def test_excluded_file_cannot_be_reviewed(self):
        self.write(".env", "private")
        manifest, _ = self.freeze()
        report = self.report(manifest)
        report["coverage"][0]["state"] = "reviewed"
        with self.assertRaises(ValueError):
            snapshot.coverage(manifest, report)

    def rule_response(self, files):
        return {"schema_version": "1", "groups": [{"group_id": 1, "source": "system",
                "pattern": "**/*.py", "files": files, "rule": "fixture-only rule"}]}

    def fake_ocr(self, rule_error=None, mutate=False, response=None):
        calls = []
        def runner(command, repo):
            calls.append(command)
            if "--version" in command:
                return subprocess.CompletedProcess(command, 0, "ocr fixture 1.9\n", "")
            if rule_error and "--format" in command:
                return subprocess.CompletedProcess(command, 1, "", rule_error)
            if mutate:
                self.write("main.py", "changed_during_ocr = True\n")
            body = self.rule_response(command[command.index("--") + 1:]) if response is None else response
            output = json.dumps(body) if "--format" in command else "fixture rule"
            return subprocess.CompletedProcess(command, 0, output, "")
        return runner, calls

    def test_ocr_missing_is_local_block_not_auto_install(self):
        self.write("main.py", "value = 2\n")
        _, path = self.freeze()
        with patch.object(snapshot.shutil, "which", return_value=None):
            result = snapshot.ocr_rules(path)
        self.assertEqual(result["reason"], "ocr_cli_missing")
        self.assertEqual(result["invocation"], "not_attempted")

    def test_ocr_adapter_only_delegates_rules_and_excludes_secrets(self):
        self.write("main.py", "value = 2\n")
        self.write(".env", "private")
        _, path = self.freeze()
        runner, calls = self.fake_ocr()
        result = snapshot.ocr_rules(path, "fixture-ocr", runner)
        self.assertEqual(result["status"], "rules_loaded")
        self.assertFalse(result["review_performed"])
        self.assertFalse(result["independent"])
        self.assertEqual(calls[1], ["fixture-ocr", "delegate", "rule", "--format", "json", "--", "main.py"])
        self.assertNotIn(".env", calls[1])

    def test_ocr_legacy_format_fallback_only_for_supported_error(self):
        self.write("main.py", "value = 2\n")
        _, path = self.freeze()
        runner, calls = self.fake_ocr("unknown flag: --format")
        result = snapshot.ocr_rules(path, "fixture-ocr", runner)
        self.assertEqual(len(calls), 3)
        self.assertEqual(result["outputs"][0]["format"], "text-legacy")
        self.assertEqual(result["status"], "rules_unverified")
        self.assertEqual(result["uncovered_paths"], ["main.py"])

    def test_ocr_invalid_schema_and_empty_rules_do_not_load(self):
        self.write("main.py", "value = 2\n")
        _, path = self.freeze()
        bodies = [{}, [], {"schema_version": "9", "groups": []},
                  dict(self.rule_response(["main.py"]), schema_version=1),
                  {"schema_version": "1", "groups": []},
                  {"schema_version": "1", "groups": [{"files": ["main.py"], "rule": ""}]},
                  self.rule_response(["other.py"]), self.rule_response(["main.py", "main.py"])]
        for body in bodies:
            with self.subTest(body=body):
                runner, calls = self.fake_ocr(response=body)
                with self.assertRaises(ValueError):
                    snapshot.ocr_rules(path, "fixture-ocr", runner)
                self.assertEqual(len(calls), 2)

    def test_ocr_partial_coverage_is_explicit(self):
        self.write("main.py", "value = 2\n")
        self.write("other.py", "other = True\n")
        _, path = self.freeze()
        runner, _ = self.fake_ocr(response=self.rule_response(["main.py"]))
        result = snapshot.ocr_rules(path, "fixture-ocr", runner)
        self.assertEqual(result["status"], "rules_partial")
        self.assertEqual(result["covered_paths"], ["main.py"])
        self.assertEqual(result["uncovered_paths"], ["other.py"])

    def test_ocr_permission_failure_is_not_format_fallback(self):
        self.write("main.py", "value = 2\n")
        _, path = self.freeze()
        runner, calls = self.fake_ocr("permission denied")
        with self.assertRaisesRegex(ValueError, "ocr_rule_failed"):
            snapshot.ocr_rules(path, "fixture-ocr", runner)
        self.assertEqual(len(calls), 2)

    def test_ocr_source_change_invalidates_result(self):
        self.write("main.py", "value = 2\n")
        _, path = self.freeze()
        runner, _ = self.fake_ocr(mutate=True)
        with self.assertRaisesRegex(ValueError, "source_changed_during_ocr"):
            snapshot.ocr_rules(path, "fixture-ocr", runner)


class OutputTests(unittest.TestCase):
    def test_cli_json_is_lossless_under_non_utf8_stdout(self):
        payload = {"status": "rules_loaded", "rule": "\u4e2d\u6587 \u2014 rule"}
        buffer = io.BytesIO()
        stream = io.TextIOWrapper(buffer, encoding="gbk")
        with patch.object(snapshot.sys, "argv", ["review_snapshot.py", "ocr-rules", "--manifest", "fixture.json"]), \
                patch.object(snapshot.sys, "stdout", stream), \
                patch.object(snapshot, "ocr_rules", return_value=payload):
            result = snapshot.main()
            stream.flush()
        self.assertEqual(result, 0)
        self.assertEqual(json.loads(buffer.getvalue().decode("ascii")), payload)


if __name__ == "__main__":
    unittest.main()

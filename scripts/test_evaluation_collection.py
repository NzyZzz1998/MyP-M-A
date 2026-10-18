import json
from pathlib import Path
import tempfile
import unittest

import evaluation_collection as collection


class CollectionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.root = self.base / "repo"
        (self.root / "evals").mkdir(parents=True)
        self.config = {
            "schema_version": 1,
            "sources": [{"key": "unit", "path": "evals/unit-evals.json", "shape": "evals",
                         "tier": "supplement", "default_kind": "decision", "overrides": {}}],
            "kinds": ["decision", "multi_turn", "trigger_probe", "file_task", "integration"],
            "excluded_sources": [], "integration_evidence": {},
            "evidence_contract": {k: k for k in ["decision", "multi_turn", "trigger_probe", "file_task"]}}
        self.case = {"id": 1, "prompt": "Do the task", "expectations": ["Hidden check"], "files": []}
        self.flush()

    def flush(self, cases=None):
        collection.write_json(self.root / collection.CONFIG, self.config)
        collection.write_json(self.root / "evals/unit-evals.json", {"evals": cases or [self.case]})

    def test_ids_namespaced(self):
        self.config["sources"].append({**self.config["sources"][0], "key": "other", "path": "evals/other-evals.json"})
        collection.write_json(self.root / "evals/other-evals.json", {"evals": [self.case]})
        self.flush()
        ledger = collection.normalize(self.root)
        self.assertEqual([c["uid"] for c in ledger["cases"]], ["unit:1", "other:1"])
        self.assertEqual(ledger["duplicate_inputs"], [["unit:1", "other:1"]])

    def test_duplicate_id_rejected(self):
        self.flush([self.case, self.case])
        with self.assertRaisesRegex(ValueError, "case id"):
            collection.normalize(self.root)

    def test_orphan_override_rejected(self):
        self.config["sources"][0]["overrides"] = {"9": "decision"}
        self.flush()
        with self.assertRaisesRegex(ValueError, "missing case"):
            collection.normalize(self.root)

    def test_unregistered_source_rejected(self):
        collection.write_json(self.root / "evals/lost-evals.json", {"evals": [self.case]})
        with self.assertRaisesRegex(ValueError, "Unregistered"):
            collection.normalize(self.root)

    def test_exclusion_requires_reason(self):
        collection.write_json(self.root / "evals/old-evals.json", {"evals": [self.case]})
        self.config["excluded_sources"] = [{"path": "evals/old-evals.json", "reason": "historical"}]
        self.flush()
        self.assertEqual(collection.normalize(self.root)["summary"]["cases"], 1)

    def test_source_cannot_have_two_owners(self):
        self.config["sources"].append({**self.config["sources"][0], "key": "other"})
        self.flush()
        with self.assertRaisesRegex(ValueError, "ownership"):
            collection.normalize(self.root)

    def test_fixture_preserves_relative_names(self):
        self.case.update(files=["current/report.sql", "archive/report.sql"],
                         fixture_files={"current/report.sql": "new\n", "archive/report.sql": "old\n"})
        self.flush()
        dest = self.base / "run"
        collection.prepare(self.root, "unit:1", dest)
        self.assertEqual((dest / "project/current/report.sql").read_text(), "new\n")
        self.assertEqual((dest / "project/archive/report.sql").read_text(), "old\n")

    def test_fixture_drift_changes_input_identity(self):
        self.case.update(files=["docs/a.md"], fixture_files={"docs/a.md": "first"})
        self.flush()
        first = collection.normalize(self.root)["cases"][0]["input_sha256"]
        self.case["fixture_files"]["docs/a.md"] = "second"
        self.flush()
        self.assertNotEqual(first, collection.normalize(self.root)["cases"][0]["input_sha256"])

    def test_future_turns_and_checks_not_exposed(self):
        self.case["turns"] = ["SECRET next turn", "SECRET last turn"]
        self.config["sources"][0]["overrides"] = {"1": "multi_turn"}
        self.flush()
        dest = self.base / "run"
        task = collection.prepare(self.root, "unit:1", dest)
        self.assertNotIn("SECRET", json.dumps(task))
        self.assertNotIn("Hidden check", (dest / "task.json").read_text())
        self.assertEqual(len(collection.read_json(dest / "_controller/turns.json")), 2)
        self.assertEqual(collection.normalize(self.root)["cases"][0]["turn_count"], 3)

    def test_unclassified_turns_rejected(self):
        self.case["turns"] = ["next"]
        self.flush()
        with self.assertRaisesRegex(ValueError, "Multi-turn"):
            collection.normalize(self.root)

    def test_paths_rejected(self):
        for name in ["../outside", "/abs", "C:/file", "a\\b", "a/../b", "./a"]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                collection.relative(name)

    def test_undeclared_fixture_rejected(self):
        self.case["fixture_files"] = {"unexpected.md": "text"}
        self.flush()
        with self.assertRaisesRegex(ValueError, "inventory"):
            collection.normalize(self.root)

    def test_repository_output_rejected(self):
        with self.assertRaisesRegex(ValueError, "separate"):
            collection.prepare(self.root, "unit:1", self.root / "run")

    def test_existing_workspace_not_overwritten(self):
        dest = self.base / "run"
        collection.prepare(self.root, "unit:1", dest)
        with self.assertRaisesRegex(ValueError, "overwrite"):
            collection.prepare(self.root, "unit:1", dest)

    def test_trigger_labels_hidden(self):
        self.config["sources"][0].update(shape="array", default_kind="trigger_probe")
        collection.write_json(self.root / collection.CONFIG, self.config)
        collection.write_json(self.root / "evals/unit-evals.json", [{"query": "Question", "should_trigger": False}])
        task = collection.prepare(self.root, "unit:1", self.base / "run")
        self.assertNotIn("should_trigger", task)

    def test_integration_cannot_be_prose_execution(self):
        self.config["sources"][0]["default_kind"] = "integration"
        self.config["integration_evidence"] = {"unit:1": "tests.py"}
        (self.root / "tests.py").write_text("# test source\n")
        self.flush()
        with self.assertRaisesRegex(ValueError, "own executor"):
            collection.prepare(self.root, "unit:1", self.base / "run")

    def test_missing_attachment_rejected(self):
        self.case["files"] = ["missing.md"]
        self.flush()
        with self.assertRaises(FileNotFoundError):
            collection.normalize(self.root)

    def test_current_repository_complete(self):
        root = Path(__file__).resolve().parent.parent
        ledger = collection.normalize(root)
        self.assertEqual(ledger["summary"]["cases"], 252)
        self.assertEqual(ledger["summary"]["kinds"]["multi_turn"], 1)
        self.assertEqual(ledger["summary"]["kinds"]["integration"], 7)

    def test_checkpoint_keeps_actual_bytes_and_old_turn(self):
        self.case.update(files=["a.md"], fixture_files={"a.md": "before"})
        self.flush()
        dest = self.base / "run"
        collection.prepare(self.root, "unit:1", dest)
        first = collection.checkpoint(dest, 1)
        (dest / "project/a.md").write_text("after")
        second = collection.checkpoint(dest, 2)
        self.assertNotEqual(first["files"], second["files"])
        self.assertEqual((dest / "evidence/turn-1/project/a.md").read_text(), "before")
        with self.assertRaisesRegex(ValueError, "already"):
            collection.checkpoint(dest, 1)
        self.assertEqual(first["tool_trace"], "not_captured_by_file_checkpoint")

    def test_timing_requires_response_and_retains_original(self):
        dest = self.base / "run"
        collection.prepare(self.root, "unit:1", dest)
        collection.time_event(dest, "start")
        with self.assertRaisesRegex(ValueError, "already"):
            collection.time_event(dest, "start")
        with self.assertRaises(FileNotFoundError):
            collection.time_event(dest, "finish")
        (dest / "response.md").write_text("A meaningful final answer for this scenario.")
        receipt = collection.time_event(dest, "finish")
        self.assertTrue(receipt["structurally_valid"])
        self.assertEqual(receipt["semantic_validity"], "requires_independent_grading")
        self.assertGreaterEqual(receipt["duration_ms"], 0)

    def test_checkpoint_rejects_wrong_project(self):
        dest = self.base / "run"
        task = collection.prepare(self.root, "unit:1", dest)
        task["project"] = str(self.root)
        collection.write_json(dest / "task.json", task)
        with self.assertRaisesRegex(ValueError, "identity"):
            collection.checkpoint(dest, 1)

    def test_before_body_survives_edit_and_delete(self):
        self.case.update(files=["a.md"], fixture_files={"a.md": "original\n"})
        self.flush()
        dest = self.base / "run"
        collection.prepare(self.root, "unit:1", dest)
        (dest / "project/a.md").unlink()
        collection.checkpoint(dest, 1)
        self.assertTrue((dest / "_controller/before/project/a.md").is_file())
        self.assertEqual((dest / "_controller/before/project/a.md").read_bytes(), b"original\n")

    def trace_fixture(self):
        dest = self.base / "run"
        task = collection.prepare(self.root, "unit:1", dest)
        collection.checkpoint(dest, 1)
        trace = {"schema_version": 1, "uid": "unit:1", "input_sha256": task["input_sha256"],
                 "run_id": task.get("run_id"),
                 "turn": 1, "scope": "controller-observed subset; synthetic fixture",
                 "calls": [{"call_id": "c1", "name": "exec_command", "arguments": {"cmd": "read file"}}],
                 "results": [{"call_id": "c1", "payload": {"exit_code": 0, "output": "hello"},
                              "truncated": False}]}
        export = self.base / "export.json"
        collection.write_json(export, trace)
        return dest, trace, export

    def test_receipt_import_preserves_payload_without_claiming_business_success(self):
        self.assertTrue(callable(getattr(collection, "capture_receipts", None)), "No receipt collector")
        dest, trace, export = self.trace_fixture()
        result = collection.capture_receipts(dest, 1, export)
        self.assertEqual(result["calls"][0]["result"], {"exit_code": 0, "output": "hello"})
        self.assertEqual(result["calls"][0]["evidence_state"], "result_available")
        self.assertEqual(result["semantic_validity"], "requires_independent_grading")
        self.assertFalse(result["proves_no_other_operations"])
        self.assertEqual((dest / "evidence/turn-1/tool-receipts/source.json").read_bytes(), export.read_bytes())
        with self.assertRaisesRegex(ValueError, "already"):
            collection.capture_receipts(dest, 1, export)

    def test_missing_truncated_and_error_results_are_distinct(self):
        self.assertTrue(callable(getattr(collection, "capture_receipts", None)), "No receipt collector")
        dest, trace, export = self.trace_fixture()
        trace["calls"].extend([{"call_id": "c2", "name": "apply_patch", "arguments": "patch"},
                               {"call_id": "c3", "name": "read", "arguments": {}}])
        trace["results"][0]["payload"] = {"isError": True, "output": "denied"}
        trace["results"].append({"call_id": "c3", "payload": "partial", "truncated": True})
        collection.write_json(export, trace)
        result = collection.capture_receipts(dest, 1, export)
        self.assertEqual([c["evidence_state"] for c in result["calls"]],
                         ["result_available", "missing_result", "truncated_result"])
        self.assertTrue(result["calls"][0]["result"]["isError"])
        self.assertFalse(result["all_results_present_and_untruncated"])

    def test_receipts_reject_wrong_case_turn_or_hash_and_orphan_result(self):
        self.assertTrue(callable(getattr(collection, "capture_receipts", None)), "No receipt collector")
        dest, trace, export = self.trace_fixture()
        for key, value in [("uid", "unit:2"), ("turn", 2), ("input_sha256", "0" * 64)]:
            with self.subTest(key=key):
                collection.write_json(export, {**trace, key: value})
                with self.assertRaisesRegex(ValueError, "identity"):
                    collection.capture_receipts(dest, 1, export)
        trace["results"][0]["call_id"] = "other"
        collection.write_json(export, trace)
        with self.assertRaisesRegex(ValueError, "orphan"):
            collection.capture_receipts(dest, 1, export)

    def test_duplicate_receipts_and_missing_payload_rejected(self):
        self.assertTrue(callable(getattr(collection, "capture_receipts", None)), "No receipt collector")
        dest, trace, export = self.trace_fixture()
        trace["results"].append(trace["results"][0])
        collection.write_json(export, trace)
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            collection.capture_receipts(dest, 1, export)
        trace["results"] = [{"call_id": "c1", "truncated": False}]
        collection.write_json(export, trace)
        with self.assertRaisesRegex(ValueError, "result"):
            collection.capture_receipts(dest, 1, export)

    def test_receipts_cannot_certify_tampered_checkpoint(self):
        self.assertTrue(callable(getattr(collection, "capture_receipts", None)), "No receipt collector")
        dest, trace, export = self.trace_fixture()
        cp = dest / "evidence/turn-1/checkpoint.json"
        body = collection.read_json(cp)
        body["uid"] = "other:1"
        collection.write_json(cp, body)
        with self.assertRaisesRegex(ValueError, "identity"):
            collection.capture_receipts(dest, 1, export)

    def test_missing_legacy_before_is_not_backfilled_from_after(self):
        self.assertTrue(callable(getattr(collection, "capture_receipts", None)), "No receipt collector")
        self.case.update(files=["a.md"], fixture_files={"a.md": "before"})
        self.flush()
        dest, trace, export = self.trace_fixture()
        (dest / "_controller/before/project/a.md").unlink()
        result = collection.capture_receipts(dest, 1, export)
        self.assertEqual(result["before_contents"], "missing_legacy_body")
        self.assertFalse((dest / "_controller/before/project/a.md").exists())

    def test_checkpoint_bytes_and_path_must_still_match(self):
        self.assertTrue(callable(getattr(collection, "capture_receipts", None)), "No receipt collector")
        self.case.update(files=["a.md"], fixture_files={"a.md": "before"})
        self.flush()
        dest, trace, export = self.trace_fixture()
        (dest / "evidence/turn-1/project/a.md").write_text("tampered")
        with self.assertRaisesRegex(ValueError, "artifact changed"):
            collection.capture_receipts(dest, 1, export)
        cp = dest / "evidence/turn-1/checkpoint.json"
        body = collection.read_json(cp)
        body["files"][0]["path"] = "../escape"
        collection.write_json(cp, body)
        with self.assertRaisesRegex(ValueError, "Unsafe"):
            collection.capture_receipts(dest, 1, export)

    def test_empty_trace_does_not_prove_absence(self):
        self.assertTrue(callable(getattr(collection, "capture_receipts", None)), "No receipt collector")
        dest, trace, export = self.trace_fixture()
        trace.update(calls=[], results=[])
        collection.write_json(export, trace)
        result = collection.capture_receipts(dest, 1, export)
        self.assertFalse(result["proves_no_other_operations"])
        self.assertEqual(result["coverage"], "imported_subset")

    def test_receipts_cannot_mix_two_attempts_of_same_case(self):
        dest, trace, export = self.trace_fixture()
        second = collection.prepare(self.root, "unit:1", self.base / "second")
        self.assertNotEqual(collection.read_json(dest / "task.json").get("run_id"), second.get("run_id"))
        trace["run_id"] = second["run_id"]
        collection.write_json(export, trace)
        with self.assertRaisesRegex(ValueError, "identity"):
            collection.capture_receipts(dest, 1, export)


if __name__ == "__main__":
    unittest.main()

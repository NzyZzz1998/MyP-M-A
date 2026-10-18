"""Targeted policy tests. No model, plugin installation, or external service."""

import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import provider_routing as routing


class ProviderTests(unittest.TestCase):
    def setUp(self):
        self.rows = routing.registry()
        self.observed = {p["id"]: {"adapter_ready": True} for p in self.rows}
        self.request = {"capability": "questionnaire", "entry": "/idea", "delivery_mode": "team_pm",
                        "selected_provider": "matt-to-questionnaire-pilot", "explicit_selection": True}

    def decide(self, **kwargs):
        return routing.plan(dict(self.request, **kwargs), self.rows, self.observed)

    def test_explicit_pilot(self):
        result = self.decide()
        self.assertEqual(result["state"], "ready")
        self.assertFalse(result["execute"])
        self.assertEqual(result["delivery_mode"], "team_pm")

    def test_implicit_only_suggests(self):
        self.assertEqual(self.decide(explicit_selection=False)["state"], "suggested")

    def test_unselected_only_suggests(self):
        self.assertEqual(self.decide(selected_provider=None)["state"], "suggested")

    def test_prompt_never_dispatches(self):
        self.assertEqual(self.decide(entry="/prompt")["reason"], "handoff-only")

    def test_wrong_entry(self):
        self.assertEqual(self.decide(entry="/acceptance")["reason"], "entry_not_supported")

    def test_missing_pilot_degrades(self):
        self.observed.clear()
        self.assertEqual(self.decide()["state"], "degraded")

    def test_cross_capability_rejected(self):
        self.assertEqual(self.decide(selected_provider="ocr-delegate")["state"], "blocked")

    def test_all_side_effects_require_specific_authorization(self):
        for effect in sorted(routing.EFFECTS):
            with self.subTest(effect=effect):
                self.assertEqual(self.decide(requested_effects=[effect])["state"], "blocked")

    def test_existing_write_consent_does_not_authorize_remote_write(self):
        result = self.decide(requested_effects=["write_existing", "remote_write"],
                             authorized_effects=["write_existing"])
        self.assertEqual(result["reason"], "unauthorized_effects:remote_write")

    def test_authorized_local_write_is_not_executed_by_plan(self):
        result = self.decide(requested_effects=["write_new"], authorized_effects=["write_new"])
        self.assertEqual(result["state"], "ready")
        self.assertFalse(result["execute"])

    def test_nested_cycle(self):
        result = self.decide(call_stack=["matt-to-questionnaire-pilot"])
        self.assertEqual(result["reason"], "nested_provider_cycle")

    def context(self, **changes):
        return dict(question_sha256="a" * 64, object_sha256="b" * 64, **changes)

    def receipt(self, provider="matt-to-questionnaire-pilot", capability="questionnaire"):
        return {"provider": provider, "capability": capability, **self.context()}

    def test_legacy_names_do_not_prove_reusable_evidence(self):
        result = self.decide(completed_providers=["matt-to-questionnaire-pilot"])
        self.assertEqual(result["state"], "ready")
        self.assertEqual(result["reuse_providers"], [])

    def test_deduplication(self):
        result = self.decide(evidence_context=self.context(), completion_receipts=[self.receipt()])
        self.assertEqual(result["state"], "reuse")

    def test_different_question_snapshot_capability_or_provider_is_not_reused(self):
        for field, value in (("question_sha256", "c" * 64), ("object_sha256", "d" * 64),
                             ("capability", "domain_modeling"), ("provider", "matt-domain-modeling-pilot")):
            with self.subTest(field=field):
                result = self.decide(evidence_context=self.context(),
                                     completion_receipts=[dict(self.receipt(), **{field: value})])
                self.assertEqual(result["reuse_providers"], [])
                self.assertEqual(result["state"], "ready")

    def test_receipt_without_current_context_is_not_reused(self):
        self.assertEqual(self.decide(completion_receipts=[self.receipt()])["state"], "ready")

    def test_malformed_receipt_rejected(self):
        for value in ({}, {"provider": "matt-to-questionnaire-pilot"},
                      dict(self.receipt(), object_sha256="bad"),
                      dict(self.receipt(), question_sha256=None)):
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.decide(evidence_context=self.context(), completion_receipts=[value])

    def test_identity_drift_prevents_old_success_reuse(self):
        self.observed["matt-to-questionnaire-pilot"]["adapter_ready"] = False
        result = self.decide(evidence_context=self.context(), completion_receipts=[self.receipt()])
        self.assertEqual(result["state"], "degraded")
        self.assertEqual(result["reuse_providers"], [])

    def test_agent_authorization_does_not_imply_budget(self):
        result = self.decide(requested_effects=["agent_spawn"], authorized_effects=["agent_spawn"])
        self.assertEqual(result["reason"], "agent_budget_not_authorized")

    def code_request(self, **kwargs):
        return self.decide(capability="code_review", entry="/review", selected_provider=None,
                           code_review_requested=True, **kwargs)

    def test_default_code_provider_one_only(self):
        result = self.code_request()
        self.assertEqual(result["providers"], ["ocr-delegate"])

    def test_no_code_intent_does_not_review(self):
        result = self.decide(capability="code_review", code_review_requested=False)
        self.assertEqual(result["state"], "native")

    def test_dual_method_is_not_independent(self):
        result = self.code_request(review_mode="dual-method")
        self.assertEqual(result["state"], "ready")
        self.assertEqual(result["independence"], "not-independent")
        self.assertEqual(len(result["providers"]), 2)

    def test_dual_isolated_zero_budget_stops(self):
        result = self.code_request(review_mode="dual-isolated")
        self.assertEqual(result["state"], "blocked")

    def test_dual_isolated_requires_each_condition(self):
        values = dict(review_mode="dual-isolated", agent_budget=2, resource_authorized=True, isolated_contexts=True)
        self.assertEqual(self.code_request(**values)["state"], "ready")
        for key, bad in (("agent_budget", 1), ("resource_authorized", False), ("isolated_contexts", False)):
            with self.subTest(key=key):
                self.assertEqual(self.code_request(**dict(values, **{key: bad}))["state"], "blocked")

    def test_partial_dual_not_claimed_complete(self):
        self.observed["ocr-delegate"]["adapter_ready"] = False
        result = self.code_request(review_mode="dual-method")
        self.assertEqual(result["state"], "partial")
        self.assertEqual(result["ready"], ["matt-code-review-adapter"])

    def test_dual_reuses_only_completed_provider(self):
        result = self.code_request(review_mode="dual-method", evidence_context=self.context(),
                                   completion_receipts=[self.receipt("matt-code-review-adapter", "code_review")])
        self.assertEqual(result["state"], "ready")
        self.assertEqual(result["reuse_providers"], ["matt-code-review-adapter"])
        self.assertEqual(result["ready"], ["ocr-delegate"])

    def test_unknown_fields_and_invalid_types(self):
        for mutation in ({"surprise": True}, {"explicit_selection": "true"},
                         {"agent_budget": True}, {"call_stack": "provider"},
                         {"requested_effects": ["unknown"]}):
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                self.decide(**mutation)

    def test_probe_missing_root_is_not_install(self):
        with tempfile.TemporaryDirectory() as temp:
            result = routing.probe(self.rows, Path(temp), which=lambda _: None)
        self.assertFalse(result["matt-domain-modeling-pilot"]["installed"])
        self.assertIsNone(result["matt-domain-modeling-pilot"]["host_exposed"])
        self.assertTrue(result["matt-code-review-adapter"]["adapter_ready"])
        self.assertFalse(result["ocr-delegate"]["installed"])

    def test_hash_drift_blocks_file_adapter(self):
        row = next(p for p in self.rows if p["capability"] == "questionnaire")
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp) / row["folder"]
            folder.mkdir()
            (folder / "SKILL.md").write_text("changed upstream", encoding="utf-8")
            result = routing.probe([row], Path(temp))
        self.assertTrue(result[row["id"]]["installed"])
        self.assertFalse(result[row["id"]]["adapter_ready"])

    def test_path_hit_without_successful_help_is_not_ready(self):
        result = routing.probe(self.rows, Path("missing-fixture-root"), which=lambda _: "fixture-ocr",
                               help_probe=lambda _: False)
        self.assertTrue(result["ocr-delegate"]["installed"])
        self.assertFalse(result["ocr-delegate"]["adapter_ready"])

    def test_help_success_is_not_review_success(self):
        result = routing.probe(self.rows, Path("missing-fixture-root"), which=lambda _: "fixture-ocr",
                               help_probe=lambda _: True)
        self.assertTrue(result["ocr-delegate"]["adapter_ready"])
        self.assertEqual(result["ocr-delegate"]["invocation"], "not_attempted")

    def test_cli_json_is_lossless_under_non_utf8_stdout(self):
        payload = {"entry": "C:/\u4e2d\u6587/\u2014/SKILL.md"}
        buffer = io.BytesIO()
        stream = io.TextIOWrapper(buffer, encoding="gbk")
        with patch.object(routing.sys, "argv", ["provider_routing.py", "probe"]), \
                patch.object(routing.sys, "stdout", stream), \
                patch.object(routing, "probe", return_value=payload):
            result = routing.main()
            stream.flush()
        self.assertEqual(result, 0)
        self.assertEqual(json.loads(buffer.getvalue().decode("ascii")), payload)


if __name__ == "__main__":
    unittest.main()

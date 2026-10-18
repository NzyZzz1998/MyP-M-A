"""Read-only provider identity probe and routing preflight; never dispatches tools."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
EFFECTS = {"write_new", "write_existing", "install", "global_update", "credentials",
           "external_model", "remote_write", "commit", "push", "release", "agent_spawn"}
CAPABILITIES = {"domain_modeling", "questionnaire", "code_review"}
FIELDS = {"capability", "entry", "delivery_mode", "selected_provider", "explicit_selection",
          "code_review_requested", "review_mode", "agent_budget", "resource_authorized",
          "isolated_contexts", "requested_effects", "authorized_effects", "call_stack",
          "completed_providers", "evidence_context", "completion_receipts"}


def reusable_receipts(request):
    keys = {"question_sha256", "object_sha256"}
    context = request.get("evidence_context")
    def valid_hashes(value):
        return all(isinstance(value.get(key), str) and re.fullmatch(r"[0-9a-f]{64}", value[key])
                   for key in keys)
    if context is not None and (not isinstance(context, dict) or set(context) != keys or not valid_hashes(context)):
        raise ValueError("invalid_evidence_context")
    receipts = request.get("completion_receipts", [])
    if not isinstance(receipts, list):
        raise ValueError("invalid_completion_receipts")
    reusable = set()
    for receipt in receipts:
        if (not isinstance(receipt, dict) or set(receipt) != keys | {"provider", "capability"}
                or not isinstance(receipt["provider"], str)
                or receipt["capability"] not in CAPABILITIES or not valid_hashes(receipt)):
            raise ValueError("invalid_completion_receipt")
        if (context is not None and receipt["capability"] == request.get("capability")
                and all(receipt[key] == context[key] for key in keys)):
            reusable.add(receipt["provider"])
    return reusable


def registry(root=ROOT):
    data = json.loads((root / "capabilities/provider-registry.json").read_text(encoding="utf-8"))
    rows = data["providers"]
    if data.get("schema_version") != 1 or data.get("default_agent_budget") != 0:
        raise ValueError("invalid_registry_policy")
    if len({p["id"] for p in rows}) != len(rows):
        raise ValueError("duplicate_provider")
    for row in rows:
        if row["capability"] not in CAPABILITIES or row["effects_default"]:
            raise ValueError("invalid_provider_scope")
        if "entry_sha256" in row and not re.fullmatch(r"[0-9a-f]{64}", row["entry_sha256"]):
            raise ValueError("invalid_provider_hash")
        if "folder" in row and not re.fullmatch(r"[a-z0-9-]+", row["folder"]):
            raise ValueError("invalid_provider_folder")
        for name in row.get("required_files", []):
            if not re.fullmatch(r"[A-Za-z0-9_.-]+", name) or name in {".", ".."}:
                raise ValueError("invalid_provider_file")
        for name, value in row.get("support_sha256", {}).items():
            if name not in row["required_files"] or not re.fullmatch(r"[0-9a-f]{64}", value):
                raise ValueError("invalid_support_identity")
        adapter = (root / row["adapter"]).resolve()
        if not adapter.is_relative_to(root.resolve()) or not adapter.is_file():
            raise ValueError("invalid_adapter_path")
    return rows


def cli_help(executable):
    try:
        result = subprocess.run([executable, "delegate", "rule", "--help"],
                                capture_output=True, text=True, timeout=10,
                                encoding="utf-8", errors="replace")
        return result.returncode == 0 and "rule" in (result.stdout + result.stderr).lower()
    except (OSError, subprocess.TimeoutExpired):
        return False


def probe(rows, skills_root, root=ROOT, which=shutil.which, help_probe=cli_help):
    result = {}
    for row in rows:
        record = {"registered": True, "installed": None, "host_exposed": None,
                  "adapter_ready": False, "invocation": "not_attempted",
                  "verification": "identity-only", "provider": row["id"]}
        if row["kind"] == "installed-file-adapter":
            folder = Path(skills_root) / row["folder"]
            present = all((folder / name).is_file() for name in row["required_files"])
            entry = folder / "SKILL.md"
            actual = hashlib.sha256(entry.read_bytes()).hexdigest() if entry.is_file() else None
            support_ok = all((folder / name).is_file() and hashlib.sha256((folder / name).read_bytes()).hexdigest() == expected
                             for name, expected in row.get("support_sha256", {}).items())
            record.update(installed=present, entry=str(entry), actual_sha256=actual,
                          identity_matches=actual == row["entry_sha256"],
                          support_identity_matches=support_ok,
                          adapter_ready=present and support_ok and actual == row["entry_sha256"])
        elif row["kind"] == "bundled-method-adapter":
            record.update(adapter_ready=True, adapter=str(root / row["adapter"]),
                          native_skill_installed=False)
        elif row["kind"] == "local-cli":
            found = next((path for name in row["commands"] if (path := which(name))), None)
            record.update(installed=bool(found), executable=found,
                          verification="cli-help-and-real-call-pending")
            record["adapter_ready"] = bool(found) and help_probe(found)
            record["verification"] = "help-only-real-call-pending" if record["adapter_ready"] else record["verification"]
        else:
            raise ValueError("unknown_provider_kind")
        result[row["id"]] = record
    return result


def plan(request, rows, observations):
    if not isinstance(request, dict) or set(request) - FIELDS:
        raise ValueError("unknown_request_fields")
    capability = request.get("capability")
    if capability not in CAPABILITIES:
        raise ValueError("unknown_capability")
    completed = reusable_receipts(request)
    if request.get("delivery_mode") not in {"team_pm", "vibe_coding"}:
        raise ValueError("delivery_mode_required")
    if request.get("entry") not in {"/review", "/idea", "/prd", "/acceptance", "/prompt"}:
        raise ValueError("unknown_entry")
    if request.get("selected_provider") is not None and not isinstance(request["selected_provider"], str):
        raise ValueError("invalid_selected_provider")
    for key in ("explicit_selection", "code_review_requested", "resource_authorized", "isolated_contexts"):
        if key in request and type(request[key]) is not bool:
            raise ValueError("invalid_boolean")
    budget = request.get("agent_budget", 0)
    if type(budget) is not int or budget < 0:
        raise ValueError("invalid_budget")
    for key in ("requested_effects", "authorized_effects", "call_stack", "completed_providers"):
        value = request.get(key, [])
        if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
            raise ValueError("invalid_list")
    requested = set(request.get("requested_effects", []))
    authorized = set(request.get("authorized_effects", []))
    if (requested | authorized) - EFFECTS:
        raise ValueError("unknown_effect")
    result = {"delivery_mode": request["delivery_mode"], "execute": False,
              "providers": [], "agent_budget": budget, "effects": sorted(requested),
              "note": "preflight-only-not-authorization-or-invocation"}

    def stop(state, reason):
        return dict(result, state=state, reason=reason)

    if request.get("entry") == "/prompt":
        return stop("native", "handoff-only")
    if requested - authorized:
        return stop("blocked", "unauthorized_effects:" + ",".join(sorted(requested - authorized)))
    if "agent_spawn" in requested and (budget == 0 or not request.get("resource_authorized")):
        return stop("blocked", "agent_budget_not_authorized")
    candidates = [p for p in rows if p["capability"] == capability]
    selected = request.get("selected_provider")
    mode = request.get("review_mode", "single")
    if mode not in {"single", "dual-method", "dual-isolated"}:
        raise ValueError("invalid_review_mode")
    if capability != "code_review" and mode != "single":
        return stop("blocked", "dual_review_only_for_code")
    if capability == "code_review" and not request.get("code_review_requested"):
        return stop("native", "no_code_review_intent")
    if mode != "single":
        if not request.get("explicit_selection"):
            return stop("suggested", "dual_review_needs_selection")
        selected_rows = candidates
        if mode == "dual-isolated" and (budget < 2 or not request.get("resource_authorized")
                                        or not request.get("isolated_contexts")):
            return stop("blocked", "isolated_review_needs_two_authorized_reviewers")
    elif selected:
        selected_rows = [p for p in candidates if p["id"] == selected]
        if not selected_rows:
            return stop("blocked", "provider_not_in_capability")
    elif capability == "code_review":
        selected_rows = [p for p in candidates if p["id"] == "ocr-delegate"]
    else:
        return stop("suggested", "explicit_pilot_selection_required")
    ids = [p["id"] for p in selected_rows]
    result["providers"] = ids
    if set(ids) & set(request.get("call_stack", [])):
        return stop("blocked", "nested_provider_cycle")
    if any(request.get("entry") not in p["entries"] for p in selected_rows):
        return stop("blocked", "entry_not_supported")
    if any(p["explicit_selection"] for p in selected_rows) and not request.get("explicit_selection"):
        return stop("suggested", "explicit_pilot_selection_required")
    # Legacy provider names are accepted for compatibility, never as completion evidence.
    reused = sorted(pid for pid in set(ids) & completed
                    if observations.get(pid, {}).get("adapter_ready") is True)
    result["reuse_providers"] = reused
    remaining = [pid for pid in ids if pid not in reused]
    if not remaining:
        return stop("reuse", "reuse_same_question_snapshot_evidence")
    ready = [pid for pid in remaining if observations.get(pid, {}).get("adapter_ready") is True]
    missing = sorted(set(remaining) - set(ready))
    result.update(ready=ready, unavailable=missing, review_mode=mode,
                  independence="requires-host-evidence" if mode == "dual-isolated" else "not-independent")
    return stop("partial" if (ready or reused) and missing else "degraded" if missing else "ready",
                "missing_provider_use_labeled_fallback" if missing else "adapter_ready_not_executed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("probe", "plan"))
    parser.add_argument("--skills-root", type=Path, default=ROOT.parent)
    args = parser.parse_args()
    try:
        rows = registry()
        observations = probe(rows, args.skills_root)
        output = observations if args.action == "probe" else plan(json.load(sys.stdin), rows, observations)
        print(json.dumps(output, ensure_ascii=True, indent=2))
    except (ValueError, OSError, KeyError, TypeError) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

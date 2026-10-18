"""Normalize evaluation sources and prepare isolated cases, without calling models."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import uuid


CONFIG = "evals/evaluation-collection.json"


def sha(value):
    return hashlib.sha256(value).hexdigest()


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def relative(name):
    if not isinstance(name, str) or not name or "\\" in name or ":" in name:
        raise ValueError("Invalid relative path")
    path = PurePosixPath(name)
    if path.is_absolute() or any(x in {"", ".", ".."} for x in name.split("/")):
        raise ValueError("Unsafe relative path")
    return path


def source_path(root, name):
    path = root.joinpath(*relative(name).parts)
    if not path.resolve().is_relative_to(root.resolve()) or path.is_symlink():
        raise ValueError("Source escapes root")
    return path


def normalize(root):
    config = read_json(root / CONFIG)
    if config.get("schema_version") != 1:
        raise ValueError("Unsupported collection schema")
    declared_sources = {s["path"] for s in config["sources"]}
    excluded = {s["path"] for s in config["excluded_sources"] if s.get("reason")}
    discovered = {p.relative_to(root).as_posix() for pattern in ("*evals.json", "*cases.json")
                  for p in (root / "evals").glob(pattern)}
    if discovered - declared_sources - excluded:
        raise ValueError("Unregistered evaluation source")
    if len(declared_sources) != len(config["sources"]) or declared_sources & excluded:
        raise ValueError("Source ownership collision")
    cases, sources, keys = [], [], set()
    for source in config["sources"]:
        key = source["key"]
        if not re.fullmatch(r"[a-z][a-z0-9-]*", key) or key in keys:
            raise ValueError("Duplicate or invalid source key")
        keys.add(key)
        path = source_path(root, source["path"])
        raw = path.read_bytes()
        data = json.loads(raw.decode("utf-8-sig"))
        items = data if source["shape"] == "array" else data[source["shape"]]
        if not isinstance(items, list) or not items:
            raise ValueError("Empty or malformed source")
        ids = set()
        for index, item in enumerate(items, 1):
            case_id = str(item.get("id", index))
            if not re.fullmatch(r"[A-Za-z0-9_-]+", case_id) or case_id in ids:
                raise ValueError("Duplicate or invalid case id")
            ids.add(case_id)
            prompt = item.get("prompt", item.get("query"))
            if not isinstance(prompt, str) or not prompt.strip():
                raise ValueError("Missing prompt")
            checks = item.get("expectations", item.get("expected", []))
            if not isinstance(checks, list) or any(not isinstance(x, str) or not x.strip() for x in checks):
                raise ValueError("Malformed checks")
            kind = source["overrides"].get(case_id, source["default_kind"])
            if kind not in config["kinds"]:
                raise ValueError("Unknown evidence kind")
            turns = item.get("turns", [])
            if not isinstance(turns, list) or any(not isinstance(x, str) or not x.strip() for x in turns):
                raise ValueError("Invalid follow-up turns")
            if bool(turns) != (kind == "multi_turn"):
                raise ValueError("Multi-turn classification mismatch")
            fixture = item.get("fixture_files", {})
            declared = item.get("files", [])
            if not isinstance(fixture, dict) or len(set(declared)) != len(declared) or not set(fixture).issubset(declared):
                raise ValueError("Fixture inventory mismatch")
            assets = []
            for name in declared:
                relative(name)
                if name in fixture:
                    if not isinstance(fixture[name], str):
                        raise ValueError("Fixture must be text")
                    content = fixture[name].encode("utf-8")
                else:
                    content = source_path(root, name).read_bytes()
                assets.append({"path": name, "sha256": sha(content), "bytes": len(content)})
            body = {"prompt": prompt, "turns": turns, "files": assets}
            case = {"uid": key + ":" + case_id, "suite": key, "id": case_id,
                    "tier": source["tier"], "kind": kind, "name": item.get("name", case_id),
                    "input_sha256": sha(canonical(body)), "checks_sha256": sha(canonical(checks)),
                    "checks_count": len(checks), "turn_count": 1 + len(turns), "files": assets,
                    "source_path": source["path"], "source_index": index - 1}
            if kind == "trigger_probe":
                if type(item.get("should_trigger")) is not bool:
                    raise ValueError("Missing trigger label")
            if kind == "integration" and case["uid"] not in config["integration_evidence"]:
                raise ValueError("Integration lacks executable evidence mapping")
            cases.append(case)
        if set(source["overrides"]) - ids:
            raise ValueError("Override points to missing case")
        sources.append({"path": source["path"], "sha256": sha(raw), "count": len(items)})
    for uid, name in config["integration_evidence"].items():
        if not any(c["uid"] == uid and c["kind"] == "integration" for c in cases):
            raise ValueError("Orphan integration mapping")
        if not source_path(root, name).is_file():
            raise ValueError("Missing integration evidence source")
    groups = {}
    for case in cases:
        groups.setdefault(case["input_sha256"], []).append(case["uid"])
    counts = {k: sum(c["kind"] == k for c in cases) for k in config["kinds"]}
    return {"schema_version": 1, "config_sha256": sha((root / CONFIG).read_bytes()), "sources": sources,
            "summary": {"cases": len(cases), "kinds": counts,
                        "checks": sum(c["checks_count"] for c in cases),
                        "model_cases_per_configuration": sum(c["kind"] != "integration" for c in cases)},
            "duplicate_inputs": [v for v in groups.values() if len(v) > 1], "cases": cases}


def prepare(root, uid, destination):
    root, destination = root.resolve(), destination.resolve()
    if destination.is_relative_to(root) or root.is_relative_to(destination):
        raise ValueError("Case workspace must be separate from repository")
    if destination.exists():
        raise ValueError("Refusing to overwrite case workspace")
    ledger = normalize(root)
    case = next((c for c in ledger["cases"] if c["uid"] == uid), None)
    if case is None or case["kind"] == "integration":
        raise ValueError("Unknown case or integration requires its own executor")
    config = read_json(root / CONFIG)
    source = next(s for s in config["sources"] if s["key"] == case["suite"])
    data = read_json(root / case["source_path"])
    items = data if source["shape"] == "array" else data[source["shape"]]
    item = items[case["source_index"]]
    destination.mkdir(parents=True)
    project = destination / "project"
    project.mkdir()
    for asset in case["files"]:
        name = asset["path"]
        content = (item["fixture_files"][name].encode("utf-8") if name in item.get("fixture_files", {})
                   else source_path(root, name).read_bytes())
        if sha(content) != asset["sha256"]:
            raise ValueError("Fixture changed during preparation")
        target = project.joinpath(*relative(name).parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
    task = {"uid": uid, "run_id": uuid.uuid4().hex, "kind": case["kind"], "prompt": item.get("prompt", item.get("query")),
            "files": item.get("files", []), "project": str(project), "input_sha256": case["input_sha256"]}
    write_json(destination / "task.json", task)
    private = destination / "_controller"
    private.mkdir()
    for asset in case["files"]:
        original = source_path(project, asset["path"])
        saved = private / "before/project" / asset["path"]
        saved.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, saved)
        if sha(saved.read_bytes()) != asset["sha256"]:
            raise ValueError("Fixture changed before baseline capture")
    write_json(private / "grading.json", {"uid": uid, "checks": item.get("expectations", item.get("expected", [])),
               "should_trigger": item.get("should_trigger"), "input_sha256": case["input_sha256"],
               "evidence_kind": case["kind"], "evidence_required": config["evidence_contract"][case["kind"]]})
    write_json(private / "turns.json", item.get("turns", []))
    write_json(private / "before.json", case["files"])
    return task


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def checkpoint(directory, turn):
    directory = directory.resolve()
    task = read_json(directory / "task.json")
    project = directory / "project"
    if Path(task["project"]).resolve() != project.resolve():
        raise ValueError("Project identity mismatch")
    if type(turn) is not int or turn < 1:
        raise ValueError("Invalid turn")
    target = directory / "evidence" / ("turn-" + str(turn))
    if target.exists():
        raise ValueError("Checkpoint already exists")
    files = []
    for path in sorted(project.rglob("*")):
        if path.is_symlink() or not path.resolve().is_relative_to(project.resolve()):
            raise ValueError("Artifact escapes project")
        if not path.is_file():
            continue
        if path.stat().st_size > 50 * 1024 * 1024:
            raise ValueError("Artifact too large for local evidence capture")
        files.append((path, path.relative_to(project).as_posix(), sha(path.read_bytes())))
    target.mkdir(parents=True)
    for path, name, digest in files:
        output = target / "project" / name
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, output)
        if sha(output.read_bytes()) != digest or sha(path.read_bytes()) != digest:
            raise ValueError("Artifact changed during capture")
    record = {"uid": task["uid"], "run_id": task.get("run_id"), "turn": turn, "captured_at_utc": datetime.now(timezone.utc).isoformat(),
              "files": [{"path": n, "sha256": d} for _, n, d in files],
              "tool_trace": "not_captured_by_file_checkpoint"}
    write_json(target / "checkpoint.json", record)
    return record


def capture_receipts(directory, turn, source):
    """Import explicit controller exports, never scan private host transcripts."""
    directory = directory.resolve()
    task = read_json(directory / "task.json")
    if not isinstance(task.get("run_id"), str) or not re.fullmatch(r"[a-f0-9]{32}", task["run_id"]):
        raise ValueError("Run identity missing; do not attach new receipts to legacy attempts")
    if Path(task["project"]).resolve() != (directory / "project").resolve():
        raise ValueError("Project identity mismatch")
    if type(turn) is not int or turn < 1:
        raise ValueError("Invalid turn")
    checkpoint_root = source_path(directory, "evidence/turn-" + str(turn))
    target = checkpoint_root / "tool-receipts"
    if target.exists():
        raise ValueError("Tool receipts already exist; preserve original attempts")
    cp = read_json(checkpoint_root / "checkpoint.json")
    if cp.get("uid") != task["uid"] or cp.get("turn") != turn or cp.get("run_id") != task["run_id"]:
        raise ValueError("Checkpoint identity mismatch")
    for asset in cp["files"]:
        if sha(source_path(checkpoint_root / "project", asset["path"]).read_bytes()) != asset["sha256"]:
            raise ValueError("Checkpoint artifact changed")
    if source.stat().st_size > 10 * 1024 * 1024:
        raise ValueError("Trace export too large; supply a scoped export")
    raw = source.read_bytes()
    trace = json.loads(raw.decode("utf-8-sig"))
    if (not isinstance(trace, dict) or type(trace.get("turn")) is not int or
            trace.get("schema_version") != 1 or trace.get("run_id") != task["run_id"] or trace.get("uid") != task["uid"] or
            trace.get("input_sha256") != task["input_sha256"] or trace.get("turn") != turn):
        raise ValueError("Trace identity mismatch")
    if not isinstance(trace.get("scope"), str) or not trace["scope"].strip():
        raise ValueError("Trace needs an explicit capture scope")
    calls, results = trace.get("calls"), trace.get("results")
    if not isinstance(calls, list) or not isinstance(results, list) or max(len(calls), len(results)) > 10000:
        raise ValueError("Invalid trace records")
    call_ids, indexed_results = set(), {}
    for call in calls:
        if (not isinstance(call, dict) or not isinstance(call.get("call_id"), str) or
                not call["call_id"] or not isinstance(call.get("name"), str) or
                not call["name"] or "arguments" not in call):
            raise ValueError("Invalid call record")
        if call["call_id"] in call_ids:
            raise ValueError("Duplicate call id")
        call_ids.add(call["call_id"])
    for result in results:
        if (not isinstance(result, dict) or not isinstance(result.get("call_id"), str) or
                "payload" not in result or type(result.get("truncated")) is not bool):
            raise ValueError("Invalid result record")
        identifier = result["call_id"]
        if identifier not in call_ids:
            raise ValueError("Trace has orphan result")
        if identifier in indexed_results:
            raise ValueError("Duplicate result id")
        indexed_results[identifier] = result
    paired = []
    for call in calls:
        result = indexed_results.get(call["call_id"])
        state = ("missing_result" if result is None else "truncated_result" if result["truncated"]
                 else "result_available")
        paired.append({**call, "evidence_state": state,
                       "result": result["payload"] if result is not None else None})
    before = read_json(directory / "_controller/before.json")
    before_status = "available"
    for asset in before:
        path = source_path(directory / "_controller/before/project", asset["path"])
        if not path.is_file():
            before_status = "missing_legacy_body"
        elif sha(path.read_bytes()) != asset["sha256"]:
            raise ValueError("Before artifact changed")
    record = {"schema_version": 1, "uid": task["uid"], "run_id": task["run_id"], "turn": turn,
              "input_sha256": task["input_sha256"], "source_sha256": sha(raw),
              "checkpoint_sha256": sha((checkpoint_root / "checkpoint.json").read_bytes()),
              "source_scope": trace["scope"], "coverage": "imported_subset",
              "provenance": "controller_supplied_export_not_independently_authenticated",
              "proves_no_other_operations": False, "before_contents": before_status,
              "all_results_present_and_untruncated": all(x["evidence_state"] == "result_available" for x in paired),
              "semantic_validity": "requires_independent_grading", "calls": paired}
    target.mkdir()
    (target / "source.json").write_bytes(raw)
    write_json(target / "index.json", record)
    return record


def time_event(directory, action):
    directory = directory.resolve()
    task = read_json(directory / "task.json")
    path = directory / ("start.json" if action == "start" else "execution.json")
    if path.exists():
        raise ValueError("Timing receipt already exists; preserve attempts")
    now = datetime.now(timezone.utc)
    result = {"uid": task["uid"], "at_utc": now.isoformat()}
    if action == "finish":
        start = read_json(directory / "start.json")
        if start["uid"] != task["uid"]:
            raise ValueError("Timing identity mismatch")
        response = (directory / "response.md").read_text(encoding="utf-8-sig")
        if task["kind"] == "trigger_probe":
            answer = json.loads(response)
            if type(answer.get("should_trigger")) is not bool or not str(answer.get("reason", "")).strip():
                raise ValueError("Invalid trigger prediction")
        elif len(response.strip()) < 20:
            raise ValueError("Empty or placeholder response")
        started = datetime.fromisoformat(start["at_utc"])
        if started.tzinfo is None or started > now:
            raise ValueError("Invalid start time")
        result.update(duration_ms=round((now - started).total_seconds() * 1000, 1),
                      duration_basis="per-case-wall-clock", response_sha256=sha(response.encode("utf-8")),
                      structurally_valid=True, semantic_validity="requires_independent_grading")
    # A case owns its directory; exclusive creation avoids overwriting a receipt.
    with path.open("x", encoding="utf-8") as output:
        json.dump(result, output, ensure_ascii=False, indent=2)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["build", "check", "prepare", "start", "finish", "checkpoint", "receipts"])
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--case")
    parser.add_argument("--turn", type=int, default=1)
    parser.add_argument("--trace", type=Path)
    args = parser.parse_args()
    if args.action == "prepare":
        if not args.output or not args.case:
            parser.error("prepare requires --output and --case")
        print(json.dumps(prepare(args.root, args.case, args.output), ensure_ascii=False))
    elif args.action == "receipts":
        if not args.output or not args.trace:
            parser.error("receipts requires --output and --trace")
        result = capture_receipts(args.output, args.turn, args.trace)
        print(json.dumps({k: v for k, v in result.items() if k != "calls"}, ensure_ascii=False))
    elif args.action in {"start", "finish", "checkpoint"}:
        if not args.output:
            parser.error("receipt actions require --output")
        result = checkpoint(args.output, args.turn) if args.action == "checkpoint" else time_event(args.output, args.action)
        print(json.dumps(result, ensure_ascii=False))
    else:
        ledger = normalize(args.root)
        output = args.output or args.root / "evals/evaluation-collection-index.json"
        if args.action == "build":
            write_json(output, ledger)
        elif read_json(output) != ledger:
            raise ValueError("Collection index is stale")
        print(json.dumps(ledger["summary"], ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)

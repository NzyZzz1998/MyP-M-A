"""Freeze local Git review layers without staging, committing, or invoking a model."""

import argparse
import difflib
import fnmatch
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys


MAX_BYTES = 1024 * 1024
SECRET = re.compile(rb"(?i)(-----BEGIN [^\r\n]*PRIVATE KEY|sk-[a-z0-9_-]{20,}|"
                    rb"(?:password|api[_-]?key|access[_-]?token|secret)['\"]?\s*[:=]\s*['\"]?[^\s'\"]{8,})")
SENSITIVE = (".env", ".env.*", "*.pem", "*.key", "id_rsa*", "id_ed25519*",
             "credentials*", "*.p12", "*.pfx")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def git(repo, *args):
    result = subprocess.run(["git", "--literal-pathspecs", "-C", str(repo), *args],
                            capture_output=True, timeout=30,
                            env=dict(os.environ, GIT_OPTIONAL_LOCKS="0", GIT_TERMINAL_PROMPT="0"))
    if result.returncode:
        raise ValueError("git_failed:" + args[0] + ":" + result.stderr.decode("utf-8", "replace")[:300])
    return result.stdout


def resolve(repo, ref):
    if not ref or ref.startswith("-"):
        raise ValueError("invalid_ref")
    return git(repo, "rev-parse", "--verify", ref + "^{commit}").decode().strip()


def safe_relative(name):
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or ":" in name or "\\" in name:
        raise ValueError("unsafe_git_path")
    return path


def changes(repo, *refs):
    fields = git(repo, "diff", "--no-ext-diff", "--no-textconv", "--no-renames",
                 "--name-status", "-z", *refs, "--").split(b"\0")
    if fields[-1] == b"":
        fields.pop()
    if len(fields) % 2:
        raise ValueError("invalid_git_diff")
    return [(fields[i].decode("ascii"), fields[i + 1].decode("utf-8"))
            for i in range(0, len(fields), 2)]


def file_bytes(repo, source, path):
    if source == "worktree":
        full = repo / path
        # Do not follow a file or directory symlink outside the requested tree.
        for parent in [full, *full.parents]:
            if parent == repo:
                break
            if parent.is_symlink():
                return None, "symlink", "120000"
        if not full.exists():
            return None, None, None
        info = full.stat()
        if not stat.S_ISREG(info.st_mode):
            return None, "non_regular_file", None
        if info.st_size > MAX_BYTES:
            return None, "file_too_large", None
        mode = "100755" if info.st_mode & stat.S_IXUSR else "100644"
        if git(repo, "config", "--default", "true", "--bool", "--get", "core.filemode").strip() == b"false":
            tracked = [r for r in git(repo, "ls-files", "--stage", "-z", "--", path).split(b"\0") if r]
            if tracked:
                mode = tracked[0].split(b" ", 1)[0].decode()
        return full.read_bytes(), None, mode
    if source == "index":
        records = git(repo, "ls-files", "--stage", "-z", "--", path).split(b"\0")
        records = [r for r in records if r]
        if not records:
            return None, None, None
        if len(records) != 1:
            return None, "unmerged", None
        meta, actual = records[0].split(b"\t", 1)
        mode, oid, stage = meta.split()
        if stage != b"0":
            return None, "unmerged", None
    else:
        records = [r for r in git(repo, "ls-tree", "-z", source, "--", path).split(b"\0") if r]
        if not records:
            return None, None, None
        meta, actual = records[0].split(b"\t", 1)
        mode, _, oid = meta.split()
    if actual.decode("utf-8") != path:
        raise ValueError("git_path_mismatch")
    if mode not in {b"100644", b"100755"}:
        return None, "symlink_or_submodule", mode.decode()
    if int(git(repo, "cat-file", "-s", oid.decode()).strip()) > MAX_BYTES:
        return None, "file_too_large", mode.decode()
    return git(repo, "cat-file", "blob", oid.decode()), None, mode.decode()


def difference(path, before, after):
    lines = difflib.unified_diff(
        (before or b"").decode("utf-8").splitlines(keepends=True),
        (after or b"").decode("utf-8").splitlines(keepends=True),
        fromfile="before/" + path, tofile="after/" + path)
    return "".join(line if line.endswith("\n") else line + "\n\\ No newline at end of file\n"
                   for line in lines).encode("utf-8")


def collect(repo, base, target="working", excludes=()):
    repo = Path(repo).resolve()
    top = Path(git(repo, "rev-parse", "--show-toplevel").decode("utf-8").strip()).resolve()
    if top != repo:
        raise ValueError("repository_root_required")
    if target not in {"working", "index", "head"}:
        raise ValueError("invalid_target")
    if git(repo, "ls-files", "--unmerged", "-z"):
        raise ValueError("unmerged_index")
    head = resolve(repo, "HEAD")
    base_sha = resolve(repo, base)
    layers = [("committed", base_sha, head, changes(repo, base_sha, head))]
    if target != "head":
        layers.append(("staged", head, "index", changes(repo, "--cached", head)))
    if target == "working":
        layers.append(("unstaged", "index", "worktree", changes(repo)))
        names = git(repo, "ls-files", "--others", "--exclude-standard", "-z")
        layers.append(("untracked", None, "worktree", [("A", p.decode("utf-8")) for p in names.split(b"\0") if p]))
    units, blobs = [], {}
    for layer, before_source, after_source, paths in layers:
        for status, path in paths:
            safe_relative(path)
            reason = None
            if any(fnmatch.fnmatchcase(path, pattern) for pattern in excludes):
                reason = "excluded_pattern"
            if any(fnmatch.fnmatchcase(PurePosixPath(path).name.lower(), pattern) for pattern in SENSITIVE):
                reason = "sensitive_path"
            before = after = None
            before_mode = after_mode = None
            if not reason:
                before, old_reason, before_mode = file_bytes(repo, before_source, path) if before_source else (None, None, None)
                after, new_reason, after_mode = file_bytes(repo, after_source, path)
                reason = old_reason or new_reason
                for data in (before, after):
                    if data is not None:
                        if SECRET.search(data):
                            reason = "sensitive_content"
                        elif b"\0" in data and reason != "sensitive_content":
                            reason = "binary"
                        else:
                            try:
                                data.decode("utf-8")
                            except UnicodeDecodeError:
                                reason = reason or "non_utf8"
            identity = {"layer": layer, "path": path, "status": status}
            unit_id = sha(encoded(identity))[:24]
            unit = dict(identity, id=unit_id, eligibility="skipped" if reason else "reviewable",
                        skip_reason=reason, before_sha256=sha(before) if before is not None else None,
                        after_sha256=sha(after) if after is not None else None,
                        before_mode=before_mode, after_mode=after_mode,
                        diff_sha256=None if reason else sha(difference(path, before, after)))
            units.append(unit)
            if not reason:
                blobs[unit_id] = (before, after)
    manifest = {"schema_version": 1, "repository": str(repo), "base": base_sha, "head": head,
                "branch": git(repo, "branch", "--show-current").decode("utf-8").strip(),
                "target": target, "excludes": list(excludes), "units": units,
                "rename_policy": "delete-and-add-both-covered",
                "ignored_policy": "excluded-by-git-no-content-read",
                "privacy": "local-only; heuristic-screen-not-complete-secret-audit"}
    manifest["snapshot_sha256"] = sha(encoded(manifest))
    return manifest, blobs


def freeze(repo, base, target, output, excludes=()):
    output = Path(output).resolve()
    repo = Path(repo).resolve()
    if output.is_relative_to(repo) or repo.is_relative_to(output) or output.exists():
        raise ValueError("new_output_outside_repository_required")
    manifest, blobs = collect(repo, base, target, excludes)
    # A second read detects ordinary concurrent edits; this is not a Git lock.
    again, _ = collect(repo, base, target, excludes)
    if manifest["snapshot_sha256"] != again["snapshot_sha256"]:
        raise ValueError("source_changed_during_freeze")
    output.mkdir(parents=True, exist_ok=False)
    for unit in manifest["units"]:
        if unit["id"] not in blobs:
            continue
        before, after = blobs[unit["id"]]
        folder = output / "units" / unit["id"]
        folder.mkdir(parents=True)
        for name, data in (("before", before), ("after", after)):
            if data is not None:
                (folder / (name + ".txt")).write_bytes(data)
        (folder / "change.diff").write_bytes(difference(unit["path"], before, after))
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    return manifest


def load_manifest(path):
    path = Path(path).resolve()
    manifest = json.loads(path.read_text(encoding="utf-8"))
    expected = manifest["snapshot_sha256"]
    if sha(encoded({k: v for k, v in manifest.items() if k != "snapshot_sha256"})) != expected:
        raise ValueError("manifest_tampered")
    ids = set()
    for unit in manifest["units"]:
        safe_relative(unit["path"])
        identity = {k: unit[k] for k in ("layer", "path", "status")}
        if unit["id"] != sha(encoded(identity))[:24] or unit["id"] in ids:
            raise ValueError("invalid_unit_id")
        ids.add(unit["id"])
        if unit["eligibility"] != "reviewable":
            continue
        diff = path.parent / "units" / unit["id"] / "change.diff"
        if not diff.is_file() or sha(diff.read_bytes()) != unit["diff_sha256"]:
            raise ValueError("snapshot_diff_changed")
        for side in ("before", "after"):
            file = path.parent / "units" / unit["id"] / (side + ".txt")
            expected_hash = unit[side + "_sha256"]
            if expected_hash is None:
                if file.exists():
                    raise ValueError("unexpected_snapshot_blob")
            elif not file.is_file() or sha(file.read_bytes()) != expected_hash:
                raise ValueError("snapshot_blob_changed")
    return manifest


def freshness(path):
    old = load_manifest(path)
    current, _ = collect(old["repository"], old["base"], old["target"], old["excludes"])
    previous = {u["id"]: u for u in old["units"]}
    now = {u["id"]: u for u in current["units"]}
    changed = sorted(uid for uid in previous if previous[uid] != now.get(uid))
    added = sorted(set(now) - set(previous))
    identity_changed = any(old[k] != current[k] for k in ("head", "branch"))
    return {"fresh": not changed and not added and not identity_changed,
            "changed_or_removed_units": changed, "new_units": added,
            "identity_changed": identity_changed,
            "unchanged_units": sorted(set(previous) - set(changed))}


def coverage(manifest, report):
    if report.get("snapshot_sha256") != manifest["snapshot_sha256"]:
        raise ValueError("report_snapshot_mismatch")
    if report.get("provider") not in {"matt-code-review-adapter", "ocr-delegate", "mypm-native"}:
        raise ValueError("unknown_review_provider")
    if report.get("identity") not in {"current-agent/non-independent", "isolated/host-evidence-required"}:
        raise ValueError("invalid_review_identity")
    expected = {u["id"]: u for u in manifest["units"]}
    actual = report.get("coverage", [])
    if len(actual) != len(expected) or {u["id"] for u in actual} != set(expected):
        raise ValueError("incomplete_or_duplicate_coverage")
    counts = {"reviewed": 0, "skipped": 0, "failed": 0}
    for item in actual:
        state = item.get("state")
        if state not in counts or (state != "reviewed" and not item.get("reason", "").strip()):
            raise ValueError("invalid_coverage_state_or_reason")
        if expected[item["id"]]["eligibility"] == "skipped" and state == "reviewed":
            raise ValueError("excluded_file_not_reviewed")
        counts[state] += 1
    return {"coverage_complete": True, "counts": counts,
            "evidence_level": "report-structure-not-semantic-review-or-acceptance"}


def run_ocr(command, repo):
    return subprocess.run(command, cwd=repo, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=30)


def rule_coverage(body, paths):
    if (not isinstance(body, dict) or body.get("schema_version") != "1"
            or not isinstance(body.get("groups"), list) or not body["groups"]):
        raise ValueError("ocr_invalid_rule_schema")
    covered, ids = set(), set()
    for group in body["groups"]:
        if (not isinstance(group, dict) or type(group.get("group_id")) is not int
                or group["group_id"] in ids
                or any(not isinstance(group.get(key), str) or not group[key].strip()
                       for key in ("source", "pattern", "rule"))):
            raise ValueError("ocr_invalid_rule_group")
        files = group.get("files")
        if (not isinstance(files, list) or not files or any(not isinstance(name, str) for name in files)
                or len(set(files)) != len(files) or set(files) - set(paths)):
            raise ValueError("ocr_invalid_rule_files")
        ids.add(group["group_id"])
        covered.update(files)
    return covered


def ocr_rules(path, executable=None, runner=run_ocr):
    manifest = load_manifest(path)
    if not freshness(path)["fresh"]:
        raise ValueError("stale_snapshot")
    executable = executable or shutil.which("ocr") or shutil.which("opencodereview")
    if not executable:
        return {"status": "blocked", "reason": "ocr_cli_missing", "invocation": "not_attempted"}
    repo = manifest["repository"]
    version = runner([str(executable), "--version"], repo)
    if version.returncode:
        raise ValueError("ocr_version_probe_failed")
    paths = sorted({u["path"] for u in manifest["units"] if u["eligibility"] == "reviewable"})
    if not paths:
        return {"status": "skipped", "reason": "no_reviewable_files", "invocation": "not_attempted"}
    outputs, covered = [], set()
    # Small bounded batches avoid platform argument limits; no agents or model calls.
    for offset in range(0, len(paths), 20):
        batch = paths[offset:offset + 20]
        command = [str(executable), "delegate", "rule", "--format", "json", "--", *batch]
        result = runner(command, repo)
        format_used = "json"
        if result.returncode:
            error = result.stderr.lower()
            unsupported = "unknown flag: --format" in error or "flag provided but not defined: -format" in error
            if not unsupported:
                raise ValueError("ocr_rule_failed")
            command = [str(executable), "delegate", "rule", "--", *batch]
            result = runner(command, repo)
            format_used = "text-legacy"
        if result.returncode or not result.stdout.strip():
            raise ValueError("ocr_rule_failed_or_empty")
        if format_used == "json":
            covered.update(rule_coverage(json.loads(result.stdout), batch))
        outputs.append({"paths": batch, "command": command, "format": format_used,
                        "stdout": result.stdout, "stdout_sha256": sha(result.stdout.encode("utf-8"))})
    if not freshness(path)["fresh"]:
        raise ValueError("source_changed_during_ocr")
    uncovered = sorted(set(paths) - covered)
    status = "rules_loaded" if not uncovered else "rules_partial" if covered else "rules_unverified"
    return {"status": status, "provider": "ocr-delegate", "invocation": "succeeded",
            "covered_paths": sorted(covered), "uncovered_paths": uncovered,
            "snapshot_sha256": manifest["snapshot_sha256"], "version": version.stdout.strip(),
            "outputs": outputs, "review_performed": False, "independent": False,
            "coverage_source": "frozen-manifest-not-live-ocr-preview"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    snap = commands.add_parser("freeze")
    snap.add_argument("--repo", required=True, type=Path)
    snap.add_argument("--base", required=True)
    snap.add_argument("--target", required=True, choices=("working", "index", "head"))
    snap.add_argument("--output", required=True, type=Path)
    snap.add_argument("--exclude", action="append", default=[])
    for name in ("verify", "coverage", "ocr-rules"):
        command = commands.add_parser(name)
        command.add_argument("--manifest", required=True, type=Path)
        if name == "coverage":
            command.add_argument("--report", required=True, type=Path)
        if name == "ocr-rules":
            command.add_argument("--executable", type=Path)
    args = parser.parse_args()
    try:
        if args.action == "freeze":
            result = freeze(args.repo, args.base, args.target, args.output, args.exclude)
        elif args.action == "verify":
            result = freshness(args.manifest)
        elif args.action == "ocr-rules":
            result = ocr_rules(args.manifest, args.executable)
        else:
            result = coverage(load_manifest(args.manifest), json.loads(args.report.read_text(encoding="utf-8")))
        print(json.dumps(result, ensure_ascii=True, indent=2))
        if result.get("status") == "blocked":
            return 2
        return 2 if args.action == "verify" and not result["fresh"] else 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    sys.exit(main())

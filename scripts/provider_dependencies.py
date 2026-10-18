"""Opt-in, missing-only installation of pinned Markdown skill dependencies."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ".mypm-dependencies.local.json"
STATE = ".mypm-dependencies.state.json"
LOCK = ".mypm-dependencies.lock"
MAX_BYTES = 128 * 1024


def sha(data):
    return hashlib.sha256(data).hexdigest()


def identity(value):
    return sha(json.dumps(value, sort_keys=True, separators=(",", ":")).encode())


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def catalog(root=ROOT):
    data = read(root / "capabilities/dependency-lock.json")
    providers = {p["id"]: p for p in read(root / "capabilities/provider-registry.json")["providers"]}
    if data.get("schema_version") != 1 or not isinstance(data.get("dependencies"), list):
        raise ValueError("invalid_dependency_catalog")
    seen = set()
    for item in data["dependencies"]:
        pid = item["id"]
        provider = providers.get(pid, {})
        if pid in seen or provider.get("kind") != "installed-file-adapter":
            raise ValueError("unregistered_dependency")
        seen.add(pid)
        if (item["repo"] != "mattpocock/skills" or item["commit"] != provider["upstream_commit"]
                or not re.fullmatch(r"[0-9a-f]{40}", item["commit"])
                or item["folder"] != provider["folder"] or not re.fullmatch(r"[a-z0-9-]+", item["folder"])):
            raise ValueError("unpinned_dependency")
        files = item["files"]
        if set(files) != set(provider["required_files"]) | {"LICENSE"}:
            raise ValueError("dependency_file_scope_mismatch")
        for name, spec in files.items():
            if not re.fullmatch(r"[A-Za-z0-9_-]+(?:\.md)?", name):
                raise ValueError("unsafe_destination")
            source = spec["source"]
            if not re.fullmatch(r"[A-Za-z0-9_./-]+", source) or PurePosixPath(source).is_absolute() or ".." in PurePosixPath(source).parts:
                raise ValueError("unsafe_source")
            if any(not re.fullmatch(r"[0-9a-f]{64}", spec[key]) for key in ("download_sha256", "installed_sha256")):
                raise ValueError("invalid_dependency_hash")
            expected = provider["entry_sha256"] if name == "SKILL.md" else provider.get("support_sha256", {}).get(name)
            if expected and spec["installed_sha256"] != expected:
                raise ValueError("dependency_provider_identity_mismatch")
            if "adaptation" in spec:
                adaptation = spec["adaptation"]
                if name != "SKILL.md" or not adaptation["body_marker"] or not isinstance(adaptation["prefix"], str):
                    raise ValueError("invalid_adaptation")
        if item["license"] != "MIT" or "allow_implicit_invocation: false" not in item["agent_policy"]:
            raise ValueError("missing_license_or_invocation_policy")
    return data


def config(root=ROOT):
    path = root / CONFIG
    if not path.exists():
        return None
    value = read(path)
    if not isinstance(value, dict):
        raise ValueError("invalid_dependency_consent")
    if value.get("enabled") is not True:
        return None
    if (value.get("consent") is not True or value.get("schema_version") != 1
            or value.get("skill_root") != str(root.resolve())
            or not Path(value.get("skills_root", "")).is_absolute()
            or not isinstance(value.get("approved"), dict)):
        raise ValueError("invalid_dependency_consent")
    destination = Path(value["skills_root"])
    if str(destination.resolve()) != value["skills_root"] or destination.resolve().is_relative_to(root.resolve()):
        raise ValueError("invalid_skills_root")
    return value


def inventory(data, skills_root):
    rows = []
    for item in data["dependencies"]:
        target = skills_root / item["folder"]
        status = "missing"
        if os.path.lexists(target):
            expected = {name: spec["installed_sha256"] for name, spec in item["files"].items()}
            expected["agents/openai.yaml"] = sha(item["agent_policy"].encode())
            valid = not target.is_symlink() and target.resolve() == target.absolute()
            try:
                for name, checksum in expected.items():
                    path = target / name
                    valid = (valid and path.is_file() and path.resolve().is_relative_to(target)
                             and path.stat().st_size <= MAX_BYTES and sha(path.read_bytes()) == checksum)
            except OSError:
                valid = False
            status = "installed" if valid else "existing_conflict"
        rows.append({"id": item["id"], "status": status})
    return rows


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("download_redirect_rejected")


def download(url):
    opener = urllib.request.build_opener(NoRedirect())
    with opener.open(url, timeout=20) as response:
        if response.status != 200:
            raise ValueError("download_failed")
        data = response.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        raise ValueError("download_too_large")
    return data


def bundle(item, fetch=download):
    result = {}
    for name, spec in item["files"].items():
        url = f'https://raw.githubusercontent.com/{item["repo"]}/{item["commit"]}/{spec["source"]}'
        raw = fetch(url)
        if len(raw) > MAX_BYTES or sha(raw) != spec["download_sha256"]:
            raise ValueError("download_hash_mismatch")
        text = raw.decode("utf-8")
        if "adaptation" in spec:
            adaptation = spec["adaptation"]
            marker = adaptation["body_marker"]
            if text.count(marker) != 1:
                raise ValueError("adaptation_anchor_mismatch")
            raw = (adaptation["prefix"] + marker + text.split(marker, 1)[1]).encode("utf-8")
        if sha(raw) != spec["installed_sha256"]:
            raise ValueError("installed_hash_mismatch")
        result[name] = raw
    result["agents/openai.yaml"] = item["agent_policy"].encode("utf-8")
    return result


def enable(root, skills_root, selected, consent=False):
    if consent is not True:
        raise ValueError("explicit_consent_required")
    data = catalog(root)
    rows = {item["id"]: item for item in data["dependencies"]}
    if not selected or set(selected) - set(rows):
        raise ValueError("select_registered_dependencies")
    destination = skills_root.resolve()
    if destination.is_relative_to(root.resolve()) or not destination.is_dir():
        raise ValueError("existing_external_skills_root_required")
    value = {"schema_version": 1, "enabled": True, "consent": True, "skill_root": str(root.resolve()),
             "skills_root": str(destination), "approved": {pid: identity(rows[pid]) for pid in selected}}
    (root / CONFIG).write_text(json.dumps(value, indent=2), encoding="utf-8")
    return {"status": "enabled", "approved": sorted(selected), "installed": False}


def sync(root=ROOT, retry=False, fetch=download):
    cfg = config(root)
    if cfg is None:
        return {"status": "disabled", "network_requests": 0}
    data = catalog(root)
    fingerprint = identity({"skill": sha((root / "SKILL.md").read_bytes()), "catalog": data,
                            "installer": sha((root / "scripts/provider_dependencies.py").read_bytes()), "consent": cfg})
    previous = read(root / STATE) if (root / STATE).is_file() else {}
    if not retry and previous.get("fingerprint") == fingerprint:
        return {"status": "already_checked", "previous": previous["result"], "network_requests": 0}
    lock = root / LOCK
    try:
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        return {"status": "busy", "reason": "existing_lock_requires_owner_or_manual_check"}
    try:
        os.close(fd)
        destination = Path(cfg["skills_root"])
        if not destination.is_dir():
            raise ValueError("skills_root_missing")
        rows = inventory(data, destination)
        index = {item["id"]: item for item in data["dependencies"]}
        for row in rows:
            item = index[row["id"]]
            if row["status"] != "missing":
                continue
            if cfg["approved"].get(row["id"]) != identity(item):
                row["status"] = "consent_required"
                continue
            phase = "download_and_verify"
            try:
                def authorized_fetch(url):
                    if config(root) != cfg:
                        raise ValueError("consent_changed")
                    return fetch(url)
                files = bundle(item, authorized_fetch)
                if config(root) != cfg:
                    raise ValueError("consent_changed")
                phase = "publish_new_directory"
                target = destination / item["folder"]
                # Claim a new directory; never rename over or modify an existing skill.
                target.mkdir(exist_ok=False)
                (target / "agents").mkdir()
                for name in sorted(files, key=lambda name: name == "SKILL.md"):
                    if config(root) != cfg:
                        raise ValueError("consent_changed")
                    with (target / name).open("xb") as stream:
                        stream.write(files[name])
                row["status"] = "installed"
            except (OSError, ValueError) as exc:
                row["status"] = "failed"
                row["reason"] = "download_identity_consent_or_write_failed_no_overwrite"
                row["failure_phase"] = phase
                row["error_type"] = type(exc).__name__
                if isinstance(exc, ValueError) and str(exc) in {
                        "download_hash_mismatch", "installed_hash_mismatch", "adaptation_anchor_mismatch",
                        "download_redirect_rejected", "download_failed", "download_too_large", "consent_changed"}:
                    row["error_code"] = str(exc)
                row["recovery"] = "inspect_partial_directory_then_explicit_retry"
        result = {"status": "complete" if all(row["status"] == "installed" for row in rows) else "partial",
                  "dependencies": rows, "manual_only": data["manual_only"], "bundled": data["bundled"],
                  "host_exposed": None, "invocation": "not_attempted"}
        (root / STATE).write_text(json.dumps({"fingerprint": fingerprint, "result": result}, indent=2), encoding="utf-8")
        return result
    finally:
        lock.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("check", "enable", "disable", "startup", "retry"))
    parser.add_argument("--skills-root", type=Path)
    parser.add_argument("--provider", action="append", default=[])
    parser.add_argument("--consent", action="store_true")
    args = parser.parse_args()
    try:
        if args.action == "enable":
            if args.skills_root is None:
                raise ValueError("explicit_skills_root_required")
            result = enable(ROOT, args.skills_root, args.provider, args.consent)
        elif args.action == "check":
            result = {"dependencies": inventory(catalog(), (args.skills_root or ROOT.parent).resolve()), "network_requests": 0}
        elif args.action == "disable":
            if (ROOT / CONFIG).exists():
                value = read(ROOT / CONFIG)
                value.update(enabled=False, consent=False)
                (ROOT / CONFIG).write_text(json.dumps(value, indent=2), encoding="utf-8")
            result = {"status": "disabled"}
        else:
            result = sync(retry=args.action == "retry")
        print(json.dumps(result, ensure_ascii=True, indent=2))
        return 0 if result.get("status") not in {"partial", "busy"} else 2
    except (OSError, ValueError, KeyError, TypeError):
        print(json.dumps({"status": "failed", "reason": "invalid_or_unavailable_dependency_state"}))
        return 1


if __name__ == "__main__":
    sys.exit(main())

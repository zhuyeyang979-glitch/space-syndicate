#!/usr/bin/env python3
"""Static asset/license gate for the single commercial reference registry."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "docs/product/SPACE_SYNDICATE_ASSET_REFERENCE_REGISTRY.json"
NOTICES = ROOT / "THIRD_PARTY_NOTICES.generated.md"
THIRD_PARTY_ROOT = ROOT / "assets/third_party/commercial"
REQUIRED_FIELDS = {
    "asset_id", "title", "asset_kind", "source_kind", "source_name", "source_url",
    "source_repository", "source_commit_or_version", "source_file_or_page", "discovered_from",
    "original_user_request_id", "license_name", "license_file_sha256", "license_verified",
    "commercial_compatibility", "attribution_required", "redistribution_allowed",
    "modification_allowed", "direct_code_use_allowed", "direct_asset_use_allowed", "reference_only",
    "local_paths", "local_blob_sha256", "imported_resource_paths", "style_tags", "feature_tags",
    "target_components", "target_versions", "visual_notes", "technical_notes", "prohibited_uses",
    "current_status", "used_in_production_paths", "used_in_test_paths", "rejected_reason",
    "deferred_reason", "reviewed_at", "reviewed_by",
}
SAFE = {"DIRECT_COMMERCIAL_USE_VERIFIED", "COMMERCIAL_USE_WITH_ATTRIBUTION", "CODE_ADAPTATION_ALLOWED"}
LICENSE_FILE_NAMES = {
    "license", "license.txt", "license.md", "license-cc0.txt",
    "license_cc0.txt", "license-cc-by-3.0.txt", "ofl-1.1.txt",
}


def path_from_res(value: str, root: Path | None = None) -> Path:
    resolved_root = ROOT if root is None else root
    return resolved_root / value.removeprefix("res://").replace("/", "\\")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def exact_source_identity_is_sealed(value: Any) -> bool:
    identity = str(value or "").strip()
    if not identity or identity.upper().startswith("UNVERIFIED"):
        return False
    if re.fullmatch(r"[0-9a-fA-F]{40}|[0-9a-fA-F]{64}", identity):
        return True
    if re.fullmatch(r"sha256:[0-9a-fA-F]{64}", identity):
        return True
    commit = re.fullmatch(r"commit:([0-9a-fA-F]{7,64})", identity)
    if commit is not None:
        return True
    tagged = re.fullmatch(r"(?:version|tag|revision):(.+)", identity)
    return tagged is not None and bool(tagged.group(1).strip())


def declared_local_blob_hash_failures(
    row: dict[str, Any],
    root: Path | None = None,
) -> list[dict[str, str]]:
    asset_id = str(row.get("asset_id", ""))
    local_paths = [str(value) for value in row.get("local_paths", [])]
    expected_hashes = [str(value).lower() for value in row.get("local_blob_sha256", [])]
    if len(expected_hashes) != len(local_paths):
        return [{
            "code": "LOCAL_BLOB_HASH_CARDINALITY_MISMATCH",
            "asset_id": asset_id,
        }]

    failures: list[dict[str, str]] = []
    for value, expected_hash in zip(local_paths, expected_hashes):
        local = path_from_res(value, root)
        if local.is_file() and sha256_file(local) != expected_hash:
            failures.append({
                "code": "LOCAL_BLOB_HASH_MISMATCH",
                "asset_id": asset_id,
                "path": value,
            })
    return failures


def license_candidates(row: dict[str, Any]) -> list[Path]:
    candidates: set[Path] = set()
    for value in row.get("local_paths", []):
        path = path_from_res(str(value))
        for parent in [path.parent, *path.parents]:
            if parent == ROOT.parent:
                break
            if parent.is_dir():
                for child in parent.iterdir():
                    if child.is_file() and child.name.lower() in LICENSE_FILE_NAMES:
                        candidates.add(child)
            if parent == ROOT:
                break
    if str(row.get("license_name", "")).upper().startswith("CC0"):
        candidates.add(ROOT / "docs/licenses/third_party_art/CC0-1.0-legalcode.txt")
    return sorted(path for path in candidates if path.is_file())


def registered_external_scopes(assets: list[dict[str, Any]]) -> set[Path]:
    """Return the smallest on-disk source-package roots sealed by the registry.

    A model/audio pack has dependency textures, buffers, and its license beside
    the explicitly consumed files.  Registering that exact licensed package
    root covers those dependencies without pretending every file is a separate
    product asset.  A new sibling package remains unregistered and fails.
    """
    scopes: set[Path] = set()
    for row in assets:
        if row.get("source_kind") == "INTERNAL_PROJECT":
            continue
        external_paths = [
            path_from_res(str(value)).resolve()
            for value in row.get("local_paths", [])
            if str(value).startswith("res://assets/third_party/commercial/")
        ]
        if not external_paths:
            continue
        package_licenses = [
            path for path in license_candidates(row)
            if path.resolve().is_relative_to(THIRD_PARTY_ROOT.resolve())
        ]
        if package_licenses:
            for license_path in package_licenses:
                scopes.add(license_path.parent.resolve())
        else:
            for path in external_paths:
                scopes.add(path.parent.resolve())
    return scopes


def unregistered_external_files(assets: list[dict[str, Any]]) -> list[Path]:
    if not THIRD_PARTY_ROOT.is_dir():
        return []
    scopes = registered_external_scopes(assets)
    exact_registered_paths = {
        path_from_res(str(value)).resolve()
        for row in assets
        for value in row.get("local_paths", [])
    }
    unregistered: list[Path] = []
    for path in THIRD_PARTY_ROOT.rglob("*"):
        if not path.is_file() or path.name.endswith((".import", ".uid")):
            continue
        resolved = path.resolve()
        if resolved in exact_registered_paths:
            continue
        if not any(resolved.is_relative_to(scope) for scope in scopes):
            unregistered.append(path)
    return sorted(unregistered)


def validate(registry: dict[str, Any]) -> dict[str, Any]:
    failures: list[dict[str, str]] = []
    assets = registry.get("assets", [])
    notices_text = NOTICES.read_text(encoding="utf-8") if NOTICES.is_file() else ""
    ids = [str(row.get("asset_id", "")) for row in assets]
    for duplicate in sorted({value for value in ids if ids.count(value) > 1}):
        failures.append({"code": "DUPLICATE_ASSET_ID", "asset_id": duplicate})
    for row in assets:
        asset_id = str(row.get("asset_id", ""))
        missing = sorted(REQUIRED_FIELDS - set(row))
        if missing:
            failures.append({"code": "MISSING_REQUIRED_FIELD", "asset_id": asset_id, "fields": ",".join(missing)})
        if row.get("current_status") not in registry.get("allowed_status", []):
            failures.append({"code": "UNKNOWN_STATUS", "asset_id": asset_id})
        if row.get("commercial_compatibility") not in registry.get("allowed_commercial_compatibility", []):
            failures.append({"code": "UNKNOWN_COMPATIBILITY", "asset_id": asset_id})
        if row.get("asset_kind") not in registry.get("allowed_asset_kinds", []):
            failures.append({"code": "UNKNOWN_ASSET_KIND", "asset_id": asset_id})
        for path in row.get("local_paths", []):
            if not path_from_res(str(path)).exists():
                failures.append({"code": "MISSING_LOCAL_ASSET", "asset_id": asset_id, "path": str(path)})
        for path in row.get("imported_resource_paths", []):
            if not path_from_res(str(path)).exists():
                failures.append({"code": "MISSING_IMPORTED_RESOURCE", "asset_id": asset_id, "path": str(path)})
        failures.extend(declared_local_blob_hash_failures(row))
        if row.get("used_in_production_paths"):
            if row.get("reference_only"):
                failures.append({"code": "REFERENCE_ONLY_ASSET_IMPORTED_TO_PRODUCTION", "asset_id": asset_id})
            if not row.get("license_verified") or row.get("commercial_compatibility") not in SAFE:
                failures.append({"code": "UNKNOWN_LICENSE_PRODUCTION_USE", "asset_id": asset_id})
            if not exact_source_identity_is_sealed(row.get("source_commit_or_version")):
                failures.append({"code": "EXACT_SOURCE_VERSION_MISSING", "asset_id": asset_id})
            if row.get("source_kind") != "INTERNAL_PROJECT":
                if not str(row.get("source_url", "")).startswith(("https://", "http://")):
                    failures.append({"code": "SOURCE_URL_MISSING_OR_INVALID", "asset_id": asset_id})
                declared_license_hash = str(row.get("license_file_sha256", ""))
                sealed_hashes = {sha256_file(path) for path in license_candidates(row)}
                if len(declared_license_hash) != 64 or declared_license_hash not in sealed_hashes:
                    failures.append({"code": "LICENSE_FILE_HASH_NOT_SEALED", "asset_id": asset_id})
                license_name = str(row.get("license_name", "")).upper()
                if license_name.startswith(("GPL", "AGPL")):
                    failures.append({"code": "PROHIBITED_LICENSE_PRODUCTION_DEPENDENCY", "asset_id": asset_id})
        if row.get("attribution_required") and not row.get("source_url"):
            failures.append({"code": "ATTRIBUTION_REQUIRED_BUT_MISSING_SOURCE", "asset_id": asset_id})
        if row.get("attribution_required") and f"## {asset_id}" not in notices_text:
            failures.append({"code": "ATTRIBUTION_REQUIRED_BUT_MISSING_NOTICE", "asset_id": asset_id})
    if not NOTICES.is_file():
        failures.append({"code": "MISSING_GENERATED_NOTICES", "asset_id": ""})
    unregistered = unregistered_external_files(assets)
    for path in unregistered:
        failures.append({
            "code": "UNREGISTERED_EXTERNAL_ASSET",
            "asset_id": "",
            "path": path.relative_to(ROOT).as_posix(),
        })
    return {
        "status": "PASS" if not failures else "FAIL",
        "implementation_count": registry.get("implementation_count", 0),
        "entry_count": len(assets),
        "production_entry_count": sum(1 for row in assets if row.get("used_in_production_paths")),
        "reference_only_entry_count": sum(1 for row in assets if row.get("reference_only")),
        "unregistered_production_asset_count": len(unregistered),
        "unknown_license_production_use_count": sum(1 for item in failures if item["code"] == "UNKNOWN_LICENSE_PRODUCTION_USE"),
        "reference_only_production_import_count": sum(1 for item in failures if item["code"] == "REFERENCE_ONLY_ASSET_IMPORTED_TO_PRODUCTION"),
        "attribution_required_but_missing_count": sum(1 for item in failures if item["code"].startswith("ATTRIBUTION_REQUIRED")),
        "failures": failures,
    }


def main() -> int:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    result = validate(registry)
    print("ASSET_LICENSE_GATE|" + json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

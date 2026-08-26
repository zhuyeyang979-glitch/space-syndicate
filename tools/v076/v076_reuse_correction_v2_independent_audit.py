#!/usr/bin/env python3
"""Independent read-only Audit A/B for the V076 correction V2 contract.

This module intentionally does not import or execute the correction resolver or
its self-test.  It reads the frozen report, inventory, immutable records and
the authorised Git tree, then emits two append-only audit projections.  The
script is safe to rerun after a record regeneration; it never writes source
files or records and only replaces the two explicitly requested audit outputs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any


AUTHORIZED_HEAD = "1e24cea73fc23e69e575fcea09df57238156af67"
AUTHORIZED_BASELINE_SHA = "b1097750f23007ba75d83f646fefe70a3bb5012540d38475a536fc5eee81e435"
AUTHORIZED_SCANNER_SHA = "d76cef3b028bd602d14250011e72484704f09f906da008da43890c7ac344ca65"
AUTHORIZED_V1_SHA = "5a3cd6ce9e218792b008cd22d120e80c2baa586ae2a53e52ce4b784c2c95909d"
AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_CORRECTION_V2_20260826"
RECORD_DIR = Path("docs/architecture/reuse_corrections/v2/records")
OUT_DIR = Path("reports/reuse/correction_v2")
SCANNER_PATHS = {
    "tools/v076/v076_reuse_point_inertia_gate.py",
    "tools/v076/v076_reuse_point_inertia_gate_selftest.py",
    "tools/rules/check_v06_mechanic_authority.py",
}
HISTORY_PREFIX = "HISTORY_"

FULL_CONVERGENCE_AUTHORIZATION_ID = (
    "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
)
FULL_CONVERGENCE_BASE_HEAD = "d701a81dce693b584d52fbfca3e0e78b521ad775"
FULL_CONVERGENCE_BASELINE_SHA = "cfb84c08abacb294ea54ffc975f691869b33ac47a5d6a9f28377c54534f19166"
FULL_CONVERGENCE_FAILURE_SET_SHA = "dd3b9f88319ba008dafa0de8be14d4e7427a3cb02d7b3e11ed6d50e2c80893ef"
FULL_CONVERGENCE_SCHEMA_SHA = "12578feb719858f84283ecb06dd31735df2f8656c1c11202c9f7d8478867af14"
FULL_CONVERGENCE_SCHEMA = Path(
    "docs/architecture/reuse_corrections/v2/schema_full_convergence_20260827.json"
)
FULL_CONVERGENCE_BASELINE_REPORT = Path(
    "reports/reuse/correction_v2/baseline_raw_failure_report.json"
)
FULL_CONVERGENCE_RECORD_ROOT = (
    "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/"
)
LEGACY_CHAIN_TERMINAL_SHA = "99f051cd23c250e0282db1708e49e2625d0e82279753a846a00a713614fed67d"
LEGACY_SEAL_PATH = Path(
    "reports/reuse/correction_v2/seals/ci_portability_v2/correction_authorization_manifest.json"
)
LEGACY_SEAL_SHA = "0731778c0b62f19bd15f7b6629ff82a67c11ec8ff9e6ca2923f4374eb170f948"
LEGACY_RECORD_SHA_BY_PATH = {
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_affected_domain_debt.json": "5d9ec47eed02e21cd19e36f9df2f402367e9498a717da07e2e2b1e1fe68aad6d",
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_affected_owner_debt.json": "78160390f497b1d1b05078667c67dfafd928047e2118ef5f9cf98c518331fa33",
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_change_class_debt.json": "144ad88f1b1f65ea973d8dbab4fb744a4eb71c4c8fde51bc7f50550aeae9c469",
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_dynamic_reference_debt.json": "d66d75d42761fd1f6274ca9ea61b1af703d68816738f1d485ab50afacf4bb2db",
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_focused_test_scope_debt.json": "654f021e14be59b690033d7667f9c3bd6324b85f8a3c3ba824785d18361ef042",
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_reuse_scan_debt.json": "2e1c7ee76aff7dec57f1634be3a1913334ee282e2019ba09e97ae2b0396cac20",
}


def _sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha_file(path: Path) -> str:
    return _sha_bytes(path.read_bytes())


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _json(path: Path) -> Any:
    return json.loads(
        path.read_text(encoding="utf-8-sig"),
        object_pairs_hook=_strict_object,
    )


def _git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def _git_bytes(root: Path, commit: str, relative: str) -> bytes | None:
    result = subprocess.run(
        ["git", "-C", str(root), "show", f"{commit}:{relative}"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return bytes(result.stdout) if result.returncode == 0 else None


def _walk_dicts(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _walk_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_dicts(child)


def _subject_projection(root: Path, commit: str, selector: dict[str, Any]) -> dict[str, Any] | None:
    registry_bytes = _git_bytes(
        root, commit, "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
    )
    supersession_bytes = _git_bytes(
        root, commit, "docs/architecture/V076_SUPERSESSION_MAP.json"
    )
    owner_bytes = _git_bytes(
        root, commit, "docs/architecture/V076_OWNER_REUSE_MAP.md"
    )
    if registry_bytes is None or supersession_bytes is None or owner_bytes is None:
        return None
    try:
        registry = json.loads(
            registry_bytes.decode("utf-8-sig"), object_pairs_hook=_strict_object
        )
        supersession = json.loads(
            supersession_bytes.decode("utf-8-sig"), object_pairs_hook=_strict_object
        )
    except (UnicodeDecodeError, ValueError):
        return None
    component_ids = {str(value) for value in selector.get("component_ids", [])}
    paths = {str(value).removeprefix("res://").replace("\\", "/") for value in selector.get("paths", [])}
    record_ids = {
        str(value)
        for key in ("supersession_ids", "retirement_ids")
        for value in selector.get(key, [])
    }

    def matches(row: dict[str, Any]) -> bool:
        components = {
            str(row.get(key, ""))
            for key in (
                "component_id", "historical_component_id", "current_component_id",
                "owner_component_id", "old_component_id", "new_component_id",
            )
        }
        row_paths = {
            str(row.get(key, "")).removeprefix("res://").replace("\\", "/")
            for key in (
                "path", "historical_path", "current_path", "owner_path",
                "old_owner_path", "new_owner_path",
            )
        }
        ids = {
            str(row.get(key, ""))
            for key in ("supersession_id", "retirement_id", "record_id")
        }
        return bool(component_ids & components or paths & row_paths or record_ids & ids)

    registry_rows = sorted(
        [row for row in _walk_dicts(registry) if matches(row)],
        key=_canonical,
    )
    supersession_rows = sorted(
        [row for row in _walk_dicts(supersession) if matches(row)],
        key=_canonical,
    )
    needles = sorted(component_ids | paths | record_ids)
    owner_lines = sorted({
        line.rstrip()
        for line in owner_bytes.decode("utf-8-sig", errors="replace").splitlines()
        if any(needle in line for needle in needles)
    })
    return {
        "owner_map_lines": owner_lines,
        "registry_rows": registry_rows,
        "supersession_rows": supersession_rows,
    }


def _canonical(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def _line_set_sha(values: list[str]) -> str:
    return _sha_bytes(("\n".join(sorted(values)) + "\n").encode("utf-8"))


def _authorized_failure_fingerprint_sets(report: dict[str, Any]) -> dict[str, set[str]]:
    result = {"historical": set(), "current": set()}
    if not isinstance(report, dict):
        return result
    values = report.get("failures")
    if not isinstance(values, list):
        return result
    for value in values:
        raw = str(value)
        rule_id = raw.split(":", 1)[0]
        historical = rule_id.startswith(HISTORY_PREFIX)
        bucket = "HISTORICAL" if historical else "CURRENT_DELTA_FAILURE"
        payload = f"V076_RAW_FAILURE_V2\n{bucket}\n{rule_id}\n{raw}\n".encode("utf-8")
        result["historical" if historical else "current"].add(
            "V2F-" + _sha_bytes(payload)
        )
    return result


def _selector_is_exact(selector: Any) -> bool:
    expected_fields = {
        "component_ids", "paths", "retirement_ids", "supersession_ids",
    }
    if not isinstance(selector, dict) or set(selector) != expected_fields:
        return False
    total = 0
    disallowed = {
        "glob", "regex", "prefix", "directory", "legacy", "misc", "other",
        "unknown", "ignore", "waive", "grandfather",
    }
    for field in sorted(expected_fields):
        values = selector.get(field)
        if not isinstance(values, list):
            return False
        rendered = [str(value) for value in values]
        total += len(rendered)
        if rendered != sorted(rendered) or len(rendered) != len(set(rendered)):
            return False
        for value in rendered:
            tokens = set(re.findall(r"[a-z0-9_]+", value.casefold()))
            if not value or any(char in value for char in "*?[]") or tokens & disallowed:
                return False
            if field == "paths":
                normalized = value.removeprefix("res://").replace("\\", "/")
                if (
                    normalized != value
                    or value.startswith(("/", "../"))
                    or value.endswith("/")
                    or "/../" in value
                ):
                    return False
    return total > 0


def _record_payload(record: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in record.items() if k != "record_payload_sha256"}


def _sidecar(path: Path) -> tuple[str, str | None]:
    sidecar = path.with_suffix(".sha256")
    if not path.is_file() or not sidecar.is_file():
        return "", "missing artifact or sidecar"
    parts = sidecar.read_text(encoding="ascii").splitlines()[0].split(maxsplit=1)
    if len(parts) != 2 or not re.fullmatch(r"[0-9a-f]{64}", parts[0]):
        return "", "invalid sidecar"
    actual = _sha_file(path)
    if actual != parts[0]:
        return actual, "sidecar digest mismatch"
    return actual, None


def _read_registry(root: Path) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    path = root / "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
    try:
        payload = _json(path)
    except (OSError, ValueError):
        return {}, {}
    by_path: dict[str, dict[str, Any]] = {}
    by_id: dict[str, dict[str, Any]] = {}
    for row in payload.get("component_inventory", []):
        if not isinstance(row, dict):
            continue
        component_id = str(row.get("component_id", ""))
        path_value = str(row.get("path", "")).removeprefix("res://").replace("\\", "/")
        if component_id:
            by_id[component_id] = row
        if path_value:
            by_path[path_value] = row
    return by_path, by_id


def _tree_blob_map(root: Path) -> dict[str, str]:
    """Return path -> Git blob id from the authorised committed tree."""
    output = _git(root, "ls-tree", "-r", AUTHORIZED_HEAD)
    result: dict[str, str] = {}
    for line in output.splitlines():
        fields = line.split("\t", 1)
        if len(fields) != 2:
            continue
        identity, path = fields
        id_fields = identity.split()
        if len(id_fields) >= 3:
            result[path.replace("\\", "/")] = id_fields[2]
    return result


def _git_blob_sha256(root: Path, blob_id: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), "cat-file", "blob", blob_id],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    return _sha_bytes(result.stdout) if result.returncode == 0 else "MISSING"


def _record_paths(root: Path) -> list[Path]:
    directory = root / RECORD_DIR
    return sorted(path for path in directory.glob("*.json") if path.is_file())


def _finding(code: str, severity: str, message: str, **evidence: Any) -> dict[str, Any]:
    return {"code": code, "severity": severity, "message": message, "evidence": evidence}


def _common_context(root: Path) -> dict[str, Any]:
    base = root / OUT_DIR
    baseline = base / "baseline_raw_failure_report.json"
    scanner = base / "baseline_scanner_file_manifest.json"
    v1 = base / "baseline_existing_corrections_manifest.json"
    raw_sha, raw_error = _sidecar(baseline)
    scanner_sha, scanner_error = _sidecar(scanner)
    v1_sha, v1_error = _sidecar(v1)
    return {
        "auditor_script_sha256": _sha_file(Path(__file__)),
        "evaluated_authorized_head_sha": AUTHORIZED_HEAD,
        "evaluated_authorized_tree_sha": _git(
            root, "rev-parse", f"{AUTHORIZED_HEAD}^{{tree}}"
        ),
        "authorization_id": AUTHORIZATION_ID,
        "authorized_head_sha": AUTHORIZED_HEAD,
        "baseline_report_sha256": raw_sha,
        "baseline_report_error": raw_error,
        "scanner_manifest_sha256": scanner_sha,
        "scanner_manifest_error": scanner_error,
        "existing_corrections_manifest_sha256": v1_sha,
        "existing_corrections_manifest_error": v1_error,
        "authorized_baseline_sha256_match": raw_sha == AUTHORIZED_BASELINE_SHA,
        "authorized_scanner_sha256_match": scanner_sha == AUTHORIZED_SCANNER_SHA,
        "authorized_v1_sha256_match": v1_sha == AUTHORIZED_V1_SHA,
    }


def audit_a(root: Path) -> dict[str, Any]:
    base = root / OUT_DIR
    findings: list[dict[str, Any]] = []
    context = _common_context(root)
    baseline = _json(base / "baseline_raw_failure_report.json")
    failure_inventory = _json(base / "exact_failure_inventory.json")
    scanner = _json(base / "baseline_scanner_file_manifest.json")
    records = []
    for path in _record_paths(root):
        try:
            records.append((path, _json(path)))
        except (OSError, ValueError):
            findings.append(_finding("CORRECTION_RECORD_UNREADABLE", "P0", "record is not valid JSON", path=str(path)))

    if not context["authorized_baseline_sha256_match"]:
        findings.append(_finding("BASELINE_HASH_NOT_AUTHORIZED", "P0", "frozen raw report hash differs from authorization", actual=context["baseline_report_sha256"], expected=AUTHORIZED_BASELINE_SHA))
    if not context["authorized_scanner_sha256_match"]:
        findings.append(_finding("SCANNER_MANIFEST_HASH_NOT_AUTHORIZED", "P0", "scanner manifest hash differs from authorization", actual=context["scanner_manifest_sha256"], expected=AUTHORIZED_SCANNER_SHA))
    if not context["authorized_v1_sha256_match"]:
        findings.append(_finding("V1_MANIFEST_HASH_NOT_AUTHORIZED", "P0", "V1 manifest hash differs from authorization", actual=context["existing_corrections_manifest_sha256"], expected=AUTHORIZED_V1_SHA))

    if scanner.get("scanner_rule_removal_count", 0) != 0 or scanner.get("scanner_scope_reduction_count", 0) != 0 or scanner.get("scanner_severity_downgrade_count", 0) != 0 or scanner.get("scanner_history_depth_reduction_count", 0) != 0:
        findings.append(_finding("SCANNER_WEAKENING", "P0", "scanner manifest attests a weakening", scanner= scanner))
    listed_scanner = {str(row.get("path", "")) for row in scanner.get("files", []) if isinstance(row, dict)}
    if listed_scanner != SCANNER_PATHS:
        findings.append(_finding("SCANNER_CORE_FILE_SET_DRIFT", "P0", "scanner core file set differs from frozen allowlist", actual=sorted(listed_scanner), expected=sorted(SCANNER_PATHS)))

    inventory_path = base / "correction_record_inventory.json"
    try:
        inventory = _json(inventory_path)
    except (OSError, ValueError):
        inventory = {}
        findings.append(_finding("RECORD_INVENTORY_UNREADABLE", "P0", "record inventory is missing or invalid"))
    expected_paths = {str(row.get("path", "")).replace("\\", "/") for row in inventory.get("records", []) if isinstance(row, dict)}
    actual_paths = {path.relative_to(root).as_posix() for path, _ in records}
    if expected_paths != actual_paths:
        findings.append(_finding("RECORD_INVENTORY_SET_DRIFT", "P0", "record inventory does not exactly enumerate records", missing=sorted(expected_paths - actual_paths), extra=sorted(actual_paths - expected_paths)))
    all_fingerprints: list[str] = []
    previous_chain = ""
    for path, record in records:
        name = path.name
        fingerprints = record.get("failure_fingerprints", [])
        all_fingerprints.extend(str(x) for x in fingerprints if isinstance(x, str))
        if not isinstance(fingerprints, list) or not fingerprints:
            findings.append(_finding("EXPLICIT_FINGERPRINT_MISSING", "P0", "record has no explicit fingerprint list", path=name))
        if any(not isinstance(x, str) or not re.fullmatch(r"V2F-[0-9a-f]{64}", x) for x in fingerprints):
            findings.append(_finding("FINGERPRINT_FORMAT_INVALID", "P0", "record contains a non-exact V2 fingerprint", path=name))
        if record.get("previous_correction_chain_sha256", "") != previous_chain:
            findings.append(_finding("CORRECTION_CHAIN_BREAK", "P0", "record predecessor hash does not match prior record", path=name))
        previous_chain = str(record.get("record_payload_sha256", ""))
        if record.get("record_payload_sha256") != _sha_bytes(_canonical(_record_payload(record))):
            findings.append(_finding("RECORD_PAYLOAD_HASH_MISMATCH", "P0", "record payload hash is not immutable", path=name))
        for key in ("paths", "current_blob_sha256_by_path", "rule_ids", "failure_classes", "transition_class_id", "backlog_item_ids", "future_failure_policy", "touch_invalidation_policy", "revocation_policy", "raw_failures", "failure_bindings"):
            if key not in record:
                findings.append(_finding("RECORD_CONTRACT_FIELD_MISSING", "P0", "record lacks mandatory contract field", path=name, field=key))
        blob_map = record.get("current_blob_sha256_by_path")
        if not isinstance(blob_map, dict):
            findings.append(_finding("CURRENT_BLOB_BINDING_MISSING", "P0", "record has no current blob map", path=name))
        else:
            for key, value in blob_map.items():
                if value != "MISSING" and (not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{64}", value)):
                    findings.append(_finding("CURRENT_BLOB_BINDING_INVALID", "P0", "current blob binding is not SHA-256", path=name, subject=key, value=value))
        if record.get("future_failure_policy", {}).get("NEW_FAILURE_REQUIRES_NEW_RECORD") is not True:
            findings.append(_finding("FUTURE_AUTO_CORRECTION", "P0", "future failures could be auto-corrected", path=name))
        # Inspect only selector/class fields and use lexical tokens.  Concrete
        # paths such as ``global_supply_demand_*`` and prose/evidence are not
        # selectors and must not create a false P0.
        selector_values = []
        for key in ("scope", "path_scope", "component_scope", "domain_scope", "selector", "selectors", "pattern", "patterns", "match", "matches", "filter", "filters", "wildcard", "wildcards", "regex", "regular_expression", "rule_ids", "failure_classes", "transition_class_id"):
            value = record.get(key)
            selector_values.extend(value if isinstance(value, list) else [value])
        selector_text = " ".join(str(value).casefold() for value in selector_values)
        selector_tokens = set(re.findall(r"[a-z0-9_]+", selector_text))
        if any(token in selector_tokens for token in ("regex", "glob", "prefix", "directory", "legacy", "unknown", "unknown_accepted", "misc", "other")) or any(char in selector_text for char in ("*", "?", "[", "]")):
            findings.append(_finding("BROAD_CORRECTION_SELECTOR", "P0", "record contains a broad selector or waiver token", path=name))
        attestation = record.get("production_reachability_attestation", {})
        if any(attestation.get(key, 0) != 0 for key in ("active_owner_violation_count", "parallel_owner_count", "dual_write_count", "fallback_count")):
            findings.append(_finding("ACTIVE_OWNER_CORRECTION", "P0", "record attests an active owner, parallel owner, dual-write or fallback", path=name, attestation=attestation))
    duplicates = len(all_fingerprints) - len(set(all_fingerprints))
    if duplicates:
        findings.append(_finding("DUPLICATE_CORRECTION_FINGERPRINT", "P0", "same failure fingerprint is corrected more than once", duplicate_count=duplicates))
    historical = {str(x) for x in baseline.get("failures", []) if str(x).startswith(HISTORY_PREFIX)}
    current = {str(x) for x in baseline.get("failures", []) if not str(x).startswith(HISTORY_PREFIX)}
    current_fingerprints = {
        str(row.get("failure_fingerprint", ""))
        for row in failure_inventory.get("rows", [])
        if isinstance(row, dict) and not str(row.get("rule_id", "")).startswith(HISTORY_PREFIX)
    }
    corrected = set(all_fingerprints)
    inventory_by_fp = {
        str(row.get("failure_fingerprint", "")): row
        for row in failure_inventory.get("rows", [])
        if isinstance(row, dict)
    }
    v1_overlap = sorted(
        fingerprint
        for fingerprint in corrected
        if inventory_by_fp.get(fingerprint, {}).get("existing_correction_id")
    )
    if v1_overlap:
        findings.append(_finding("V1_V2_DUPLICATE_CORRECTION_AUTHORITY", "P0", "a V2 correction fingerprint is already owned by the read-only V1 authority", overlap=v1_overlap))
    if corrected & current_fingerprints:
        findings.append(_finding("CURRENT_FAILURE_CORRECTION_OVERLAP", "P0", "a current baseline failure fingerprint is corrected", overlap=sorted(corrected & current_fingerprints)))
    if inventory.get("corrected_failure_fingerprint_count") != len(all_fingerprints):
        findings.append(_finding("RECORD_INVENTORY_CARDINALITY_DRIFT", "P1", "record inventory fingerprint count is inaccurate", listed=inventory.get("corrected_failure_fingerprint_count"), actual=len(all_fingerprints)))
    return {
        "schema_version": "space_syndicate.v076.reuse_correction_v2.audit_a.v2",
        **context,
        "raw_failure_count": len(baseline.get("failures", [])),
        "raw_historical_failure_count": len(historical),
        "raw_current_delta_failure_count": len(current),
        "record_count": len(records),
        "corrected_fingerprint_count": len(all_fingerprints),
        "p0": [x for x in findings if x["severity"] == "P0"],
        "p1": [x for x in findings if x["severity"] == "P1"],
        "status": "GO" if not any(x["severity"] in {"P0", "P1"} for x in findings) else "NO_GO",
    }


def audit_b(root: Path) -> dict[str, Any]:
    base = root / OUT_DIR
    findings: list[dict[str, Any]] = []
    context = _common_context(root)
    baseline = _json(base / "baseline_raw_failure_report.json")
    inventory = _json(base / "exact_failure_inventory.json")
    rows = [row for row in inventory.get("rows", []) if isinstance(row, dict)]
    by_fp = {str(row.get("failure_fingerprint")): row for row in rows}
    by_raw = {str(row.get("raw_failure")): row for row in rows}
    registry_path, registry_id = _read_registry(root)
    tree_blobs = _tree_blob_map(root)
    records = []
    for path in _record_paths(root):
        try:
            records.append((path, _json(path)))
        except (OSError, ValueError):
            continue
    corrected: set[str] = set()
    for path, record in records:
        rule_ids = {str(x) for x in record.get("rule_ids", [])}
        classes = {str(x) for x in record.get("failure_classes", [])}
        for fingerprint in record.get("failure_fingerprints", []):
            fingerprint = str(fingerprint)
            corrected.add(fingerprint)
            row = by_fp.get(fingerprint)
            if row is None:
                findings.append(_finding("FINGERPRINT_NOT_IN_BASELINE", "P0", "correction fingerprint is absent from frozen inventory", path=path.name, fingerprint=fingerprint))
                continue
            eligibility = row.get("transition_eligibility")
            if not isinstance(eligibility, dict) or eligibility.get("eligible_for_correction") is not True:
                findings.append(_finding("TRANSITION_CLASS_NOT_ELIGIBLE", "P0", "record covers a row without independently verified historical transition eligibility", path=path.name, fingerprint=fingerprint, reasons=(eligibility or {}).get("ineligibility_reasons", [])))
            if not str(record.get("transition_class_id", "")):
                findings.append(_finding("TRANSITION_CLASS_MISSING", "P0", "record has no explicit transition class", path=path.name, fingerprint=fingerprint))
            if str(row.get("raw_failure")) not in by_raw:
                findings.append(_finding("RAW_FAILURE_IDENTITY_MISSING", "P0", "inventory row cannot be tied to raw failure", fingerprint=fingerprint))
            row_rule = str(row.get("rule_id", ""))
            if row_rule not in rule_ids or row_rule not in classes:
                findings.append(_finding("RULE_CLASS_MISMATCH", "P0", "record class does not match exact inventory row", path=path.name, fingerprint=fingerprint, row_rule=row_rule, record_rules=sorted(rule_ids), record_classes=sorted(classes)))
            if not row_rule.startswith(HISTORY_PREFIX):
                findings.append(_finding("CURRENT_DELTA_CORRECTION", "P0", "record covers a current-delta fingerprint", path=path.name, fingerprint=fingerprint, rule=row_rule))
            row_path = str(row.get("path", "")).replace("\\", "/")
            blob_map = record.get("current_blob_sha256_by_path", {})
            if row_path:
                expected = str(row.get("current_blob_sha256", ""))
                declared = blob_map.get(row_path) if isinstance(blob_map, dict) else None
                if declared != expected:
                    findings.append(_finding("CURRENT_BLOB_BINDING_MISMATCH", "P0", "record blob map differs from inventory", path=path.name, fingerprint=fingerprint, expected=expected, declared=declared))
                git_blob = tree_blobs.get(row_path)
                live_sha = _git_blob_sha256(root, git_blob) if git_blob else "MISSING"
                if live_sha != expected:
                    findings.append(_finding("CURRENT_BLOB_NOT_LIVE", "P0", "record blob binding does not match authorized tree", path=path.name, fingerprint=fingerprint, subject=row_path, expected=expected, actual=live_sha))
            else:
                findings.append(_finding("NO_CONCRETE_BLOB_SUBJECT", "P1", "corrected row has no concrete path and therefore no verifiable current blob binding", path=path.name, fingerprint=fingerprint, component_id=row.get("component_id", ""), domain_id=row.get("domain_id", "")))
            component_id = str(row.get("component_id", ""))
            subject = registry_path.get(row_path) if row_path else registry_id.get(component_id)
            if subject is None:
                findings.append(_finding("REACHABILITY_UNRESOLVED", "P1", "component/path is absent from authoritative registry; non-production reachability is unproven", path=path.name, fingerprint=fingerprint, subject=row_path or component_id))
            elif subject.get("production_reachable") is True and record.get("production_reachability_attestation", {}).get("states") == ["non_production_or_unresolved"]:
                findings.append(_finding("REACHABILITY_ATTESTATION_MISMATCH", "P0", "record says non-production/unresolved but registry says production reachable", path=path.name, fingerprint=fingerprint, subject=row_path or component_id))
    raw_values = {str(value) for value in baseline.get("failures", [])}
    if len(rows) != len(raw_values):
        findings.append(_finding("INVENTORY_COVERAGE_OR_DUPLICATE", "P0", "inventory does not cover each unique raw failure exactly once", raw_count=len(raw_values), inventory_count=len(rows)))
    if set(str(row.get("raw_failure")) for row in rows) != raw_values:
        findings.append(_finding("INVENTORY_RAW_SET_MISMATCH", "P0", "inventory raw failure set differs from frozen report"))
    current_rows = [row for row in rows if not str(row.get("rule_id", "")).startswith(HISTORY_PREFIX)]
    if not current_rows:
        findings.append(_finding("CURRENT_DELTA_NOT_RETAINED", "P0", "inventory has no independently classified current-delta failures"))
    historical_rows = [row for row in rows if str(row.get("rule_id", "")).startswith(HISTORY_PREFIX)]
    if len(corrected & {str(row.get("failure_fingerprint")) for row in current_rows}):
        findings.append(_finding("CURRENT_FINGERPRINT_CORRECTED", "P0", "at least one current-delta inventory fingerprint is corrected"))
    # Missing registry identities are retained as explicit P1 findings above;
    # this aggregate makes the audit decision easy to consume.
    unresolved_rows = [row for row in historical_rows if not ((str(row.get("path", "")) and str(row.get("path", "")).replace("\\", "/") in registry_path) or (str(row.get("component_id", "")) and str(row.get("component_id", "")) in registry_id))]
    unresolved = len(unresolved_rows)
    no_blob_rows = [row for row in historical_rows if not row.get("path")]
    no_blob = len(no_blob_rows)
    return {
        "schema_version": "space_syndicate.v076.reuse_correction_v2.audit_b.v2",
        **context,
        "raw_failure_count": len(raw_values),
        "raw_historical_failure_count": len(historical_rows),
        "raw_current_delta_failure_count": len(current_rows),
        "corrected_fingerprint_count": len(corrected),
        "registry_unresolved_historical_row_count": unresolved,
        "registry_unresolved_historical_fingerprints": sorted(str(row.get("failure_fingerprint", "")) for row in unresolved_rows),
        "historical_rows_without_concrete_path_count": no_blob,
        "historical_rows_without_concrete_path_fingerprints": sorted(str(row.get("failure_fingerprint", "")) for row in no_blob_rows),
        "p0": [x for x in findings if x["severity"] == "P0"],
        "p1": [x for x in findings if x["severity"] == "P1"],
        "status": "GO" if not any(x["severity"] in {"P0", "P1"} for x in findings) else "NO_GO",
    }


def audit_full_convergence_batch(
    root: Path,
    manifest_path: Path,
    *,
    evaluated_head: str,
    baseline_report_path: Path | None = None,
    previous_batch_manifest_path: Path | None = None,
) -> dict[str, Any]:
    """Independently verify one explicit new-epoch batch and its legacy anchor.

    This intentionally duplicates the security-critical checks instead of
    importing the resolver extension.  Directory discovery is not authority:
    only record paths enumerated by ``manifest_path`` are evaluated.
    """
    findings: list[dict[str, Any]] = []
    baseline_fingerprints = {"historical": set(), "current": set()}
    if baseline_report_path is None:
        findings.append(_finding(
            "FULL_CONVERGENCE_BASELINE_REQUIRED",
            "P0",
            "the full-convergence batch audit requires the explicit authorized raw report",
        ))
    elif not baseline_report_path.is_file() or _sha_file(baseline_report_path) != FULL_CONVERGENCE_BASELINE_SHA:
        findings.append(_finding(
            "FULL_CONVERGENCE_BASELINE_DRIFT",
            "P0",
            "the d701 raw failure report differs from the authorized digest",
        ))
    else:
        try:
            baseline_report = _json(baseline_report_path)
        except (OSError, ValueError):
            baseline_report = {}
            findings.append(_finding(
                "FULL_CONVERGENCE_BASELINE_UNREADABLE",
                "P0",
                "the authorized raw failure report is not valid JSON",
            ))
        baseline_fingerprints = _authorized_failure_fingerprint_sets(baseline_report)
        if (
            len(baseline_fingerprints["historical"]) != 510
            or len(baseline_fingerprints["current"]) != 56
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_BASELINE_FINGERPRINT_SET_INVALID",
                "P0",
                "the frozen report does not derive the exact 510 historical and 56 current fingerprints",
            ))
    schema_path = root / FULL_CONVERGENCE_SCHEMA
    if not schema_path.is_file() or _sha_file(schema_path) != FULL_CONVERGENCE_SCHEMA_SHA:
        findings.append(_finding(
            "FULL_CONVERGENCE_SCHEMA_DRIFT",
            "P0",
            "full-convergence schema bytes differ from the authorized digest",
        ))
    seal_path = root / LEGACY_SEAL_PATH
    if not seal_path.is_file() or _sha_file(seal_path) != LEGACY_SEAL_SHA:
        findings.append(_finding(
            "LEGACY_SEAL_BYTE_DRIFT",
            "P0",
            "the CI_PORTABILITY_V2 predecessor seal changed",
        ))
    legacy_fingerprints: set[str] = set()
    for relative, expected in LEGACY_RECORD_SHA_BY_PATH.items():
        path = root / relative
        if not path.is_file() or _sha_file(path) != expected:
            findings.append(_finding(
                "LEGACY_RECORD_BYTE_DRIFT",
                "P0",
                "one of the exact six legacy records changed",
                path=relative,
            ))
            continue
        try:
            legacy_record = _json(path)
        except (OSError, ValueError):
            findings.append(_finding(
                "LEGACY_RECORD_UNREADABLE",
                "P0",
                "one of the byte-locked legacy records is not valid JSON",
                path=relative,
            ))
            continue
        values = legacy_record.get("failure_fingerprints")
        if not isinstance(values, list):
            findings.append(_finding(
                "LEGACY_RECORD_FINGERPRINT_SET_INVALID",
                "P0",
                "one of the byte-locked legacy records lacks its fingerprint set",
                path=relative,
            ))
            continue
        for value in values:
            rendered = str(value)
            if rendered in legacy_fingerprints:
                findings.append(_finding(
                    "LEGACY_RECORD_FINGERPRINT_DUPLICATE",
                    "P0",
                    "legacy records contain a duplicate corrected fingerprint",
                    path=relative,
                    fingerprint=rendered,
                ))
            legacy_fingerprints.add(rendered)
    try:
        manifest = _json(manifest_path)
    except (OSError, ValueError):
        manifest = {}
        findings.append(_finding(
            "FULL_CONVERGENCE_BATCH_MANIFEST_UNREADABLE",
            "P0",
            "the explicit batch manifest is missing or invalid JSON",
        ))
    if not isinstance(manifest, dict):
        findings.append(_finding(
            "FULL_CONVERGENCE_BATCH_MANIFEST_NOT_OBJECT",
            "P0",
            "the explicit batch manifest must be a JSON object",
        ))
        manifest = {}
    manifest_fingerprints = [
        str(value) for value in manifest.get("failure_fingerprints", [])
    ]
    if (
        manifest_fingerprints != sorted(manifest_fingerprints)
        or len(manifest_fingerprints) != len(set(manifest_fingerprints))
        or any(not re.fullmatch(r"V2F-[0-9a-f]{64}", value) for value in manifest_fingerprints)
    ):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_SET_INVALID",
            "P0",
            "manifest fingerprints must be unique sorted exact V2 identities",
        ))
    if manifest.get("failure_count") != len(manifest_fingerprints):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_COUNT_MISMATCH",
            "P0",
            "manifest failure_count differs from its explicit fingerprint list",
        ))
    if manifest.get("failure_fingerprint_set_sha256") != _line_set_sha(manifest_fingerprints):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_HASH_MISMATCH",
            "P0",
            "manifest fingerprint set digest is not canonical",
        ))
    if not 1 <= len(manifest_fingerprints) <= 50:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_BATCH_SIZE_INVALID",
            "P0",
            "a batch must contain between one and fifty exact fingerprints",
        ))
    if len(manifest_fingerprints) < 25 and manifest.get("terminal_remainder_batch") is not True:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_NONTERMINAL_BELOW_TARGET",
            "P0",
            "a nonterminal batch cannot contain fewer than twenty-five fingerprints",
        ))
    manifest_binding_head = str(manifest.get("binding_head_sha", ""))
    manifest_binding_tree = _git(root, "rev-parse", f"{manifest_binding_head}^{{tree}}")
    if not re.fullmatch(r"[0-9a-f]{40}", manifest_binding_head) or not manifest_binding_tree:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_BINDING_HEAD_UNRESOLVED",
            "P0",
            "manifest binding Head is not a resolvable commit",
        ))
    elif manifest.get("binding_tree_sha") != manifest_binding_tree:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_BINDING_TREE_MISMATCH",
            "P0",
            "manifest binding tree differs from its exact Git Head",
        ))
    for field, expected in (
        ("authorization_id", FULL_CONVERGENCE_AUTHORIZATION_ID),
        ("authorization_base_head_sha", FULL_CONVERGENCE_BASE_HEAD),
        ("baseline_report_sha256", FULL_CONVERGENCE_BASELINE_SHA),
        ("baseline_failure_set_sha256", FULL_CONVERGENCE_FAILURE_SET_SHA),
        ("batch_review_a_status", "GO"),
        ("batch_review_b_status", "GO"),
        ("identity_coverage_percent", 100),
        ("batch_unknown_count", 0),
        ("batch_wildcard_count", 0),
        ("current_failure_false_accept_count", 0),
    ):
        if manifest.get(field) != expected:
            findings.append(_finding(
                "FULL_CONVERGENCE_BATCH_AUTHORITY_MISMATCH",
                "P0",
                "batch authority or review assertion differs from the closed contract",
                field=field,
                expected=expected,
                actual=manifest.get(field),
            ))
    previous_append_sha = manifest.get("previous_batch_append_sha256")
    if previous_append_sha:
        if previous_batch_manifest_path is None:
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_REQUIRED",
                "P0",
                "a non-initial batch did not supply its explicit immediate predecessor manifest",
            ))
        else:
            try:
                previous_manifest = _json(previous_batch_manifest_path)
            except (OSError, ValueError):
                previous_manifest = {}
                findings.append(_finding(
                    "FULL_CONVERGENCE_PREVIOUS_MANIFEST_UNREADABLE",
                    "P0",
                    "the explicit predecessor manifest is missing or invalid JSON",
                ))
            if not isinstance(previous_manifest, dict):
                findings.append(_finding(
                    "FULL_CONVERGENCE_PREVIOUS_MANIFEST_NOT_OBJECT",
                    "P0",
                    "the explicit predecessor manifest must be a JSON object",
                ))
                previous_manifest = {}
            if previous_manifest:
                if _sha_file(previous_batch_manifest_path) != previous_append_sha:
                    findings.append(_finding(
                        "FULL_CONVERGENCE_PREVIOUS_MANIFEST_SHA_MISMATCH",
                        "P0",
                        "the predecessor manifest bytes do not match previous_batch_append_sha256",
                    ))
                for field, expected in (
                    ("authorization_id", FULL_CONVERGENCE_AUTHORIZATION_ID),
                    ("authorization_base_head_sha", FULL_CONVERGENCE_BASE_HEAD),
                    ("baseline_report_sha256", FULL_CONVERGENCE_BASELINE_SHA),
                    ("baseline_failure_set_sha256", FULL_CONVERGENCE_FAILURE_SET_SHA),
                ):
                    if previous_manifest.get(field) != expected:
                        findings.append(_finding(
                            "FULL_CONVERGENCE_PREVIOUS_MANIFEST_AUTHORITY_MISMATCH",
                            "P0",
                            "the predecessor manifest belongs to a different authority epoch",
                            field=field,
                        ))
                if manifest.get("record_chain_start_sha256") != previous_manifest.get("record_chain_terminal_sha256"):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_PREVIOUS_MANIFEST_TERMINAL_MISMATCH",
                        "P0",
                        "the current batch does not continue the predecessor record terminal",
                    ))
                current_id = re.fullmatch(r"batch-([0-9]{3})", str(manifest.get("batch_id", "")))
                previous_id = re.fullmatch(r"batch-([0-9]{3})", str(previous_manifest.get("batch_id", "")))
                if (
                    current_id is None
                    or previous_id is None
                    or int(current_id.group(1)) != int(previous_id.group(1)) + 1
                ):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_PREVIOUS_MANIFEST_SEQUENCE_MISMATCH",
                        "P0",
                        "batch id does not immediately follow the explicit predecessor",
                    ))
                if previous_manifest.get("terminal_remainder_batch") is True:
                    findings.append(_finding(
                        "FULL_CONVERGENCE_PREVIOUS_MANIFEST_ALREADY_TERMINAL",
                        "P0",
                        "a batch cannot follow a declared terminal remainder",
                    ))
                predecessor_chain = str(previous_manifest.get("record_chain_start_sha256", ""))
                predecessor_covered: list[str] = []
                predecessor_bindings = previous_manifest.get("record_bindings")
                if not isinstance(predecessor_bindings, list) or not predecessor_bindings:
                    findings.append(_finding(
                        "FULL_CONVERGENCE_PREVIOUS_MANIFEST_BINDINGS_INVALID",
                        "P0",
                        "the predecessor manifest has no explicit record bindings",
                    ))
                    predecessor_bindings = []
                for index, binding in enumerate(predecessor_bindings):
                    if not isinstance(binding, dict):
                        findings.append(_finding(
                            "FULL_CONVERGENCE_PREVIOUS_MANIFEST_BINDING_INVALID",
                            "P0",
                            "a predecessor record binding is not an object",
                            index=index,
                        ))
                        continue
                    if binding.get("previous_correction_chain_sha256") != predecessor_chain:
                        findings.append(_finding(
                            "FULL_CONVERGENCE_PREVIOUS_MANIFEST_CHAIN_BREAK",
                            "P0",
                            "the predecessor manifest record chain is discontinuous",
                            index=index,
                        ))
                    predecessor_chain = str(binding.get("record_payload_sha256", ""))
                    values = binding.get("failure_fingerprints")
                    if isinstance(values, list):
                        predecessor_covered.extend(str(value) for value in values)
                if predecessor_chain != previous_manifest.get("record_chain_terminal_sha256"):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_PREVIOUS_MANIFEST_CHAIN_TERMINAL_MISMATCH",
                        "P0",
                        "the predecessor manifest terminal differs from its final record payload",
                    ))
                predecessor_fingerprints = [
                    str(value) for value in previous_manifest.get("failure_fingerprints", [])
                ]
                if (
                    sorted(predecessor_covered) != predecessor_fingerprints
                    or len(predecessor_covered) != len(set(predecessor_covered))
                ):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_PREVIOUS_MANIFEST_COVERAGE_MISMATCH",
                        "P0",
                        "the predecessor manifest does not cover each fingerprint exactly once",
                    ))
                current_fingerprints = {
                    str(value) for value in manifest.get("failure_fingerprints", [])
                }
                for fingerprint in sorted(current_fingerprints & set(predecessor_fingerprints)):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_PREVIOUS_MANIFEST_FINGERPRINT_REUSE",
                        "P0",
                        "the current batch repeats a predecessor fingerprint",
                        fingerprint=fingerprint,
                    ))
    elif previous_batch_manifest_path is not None:
        findings.append(_finding(
            "FULL_CONVERGENCE_PREVIOUS_MANIFEST_UNEXPECTED",
            "P0",
            "an initial batch supplied a predecessor manifest despite an empty predecessor hash",
        ))
    bindings = manifest.get("record_bindings")
    if not isinstance(bindings, list) or not bindings:
        findings.append(_finding(
            "FULL_CONVERGENCE_RECORD_BINDINGS_MISSING",
            "P0",
            "the batch does not enumerate an explicit record set",
        ))
        bindings = []
    previous = str(manifest.get("record_chain_start_sha256", ""))
    if not manifest.get("previous_batch_append_sha256") and previous != LEGACY_CHAIN_TERMINAL_SHA:
        findings.append(_finding(
            "FULL_CONVERGENCE_LEGACY_CHAIN_NOT_CONTINUED",
            "P0",
            "the first full-convergence batch does not continue the six-record terminal",
            expected=LEGACY_CHAIN_TERMINAL_SHA,
            actual=previous,
        ))
    all_fingerprints: list[str] = []
    for index, binding in enumerate(bindings):
        if not isinstance(binding, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BINDING_INVALID",
                "P0",
                "record binding is not an object",
                index=index,
            ))
            continue
        relative = str(binding.get("path", "")).replace("\\", "/")
        if (
            not relative.startswith(FULL_CONVERGENCE_RECORD_ROOT)
            or any(char in relative for char in "*?[]")
            or relative.endswith("/")
            or "/../" in relative
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PATH_NOT_EXACT",
                "P0",
                "record path is outside the explicit epoch root or contains selector syntax",
                path=relative,
            ))
            continue
        if binding.get("previous_correction_chain_sha256") != previous:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_CHAIN_BREAK",
                "P0",
                "record predecessor does not match the prior payload",
                path=relative,
            ))
        previous = str(binding.get("record_payload_sha256", ""))
        path = root / relative
        if not path.is_file() or _sha_file(path) != binding.get("record_sha256"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BYTE_DRIFT",
                "P0",
                "record bytes do not match the explicit binding",
                path=relative,
            ))
            continue
        try:
            record = _json(path)
        except (OSError, ValueError):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_UNREADABLE",
                "P0",
                "record is not valid JSON",
                path=relative,
            ))
            continue
        if not isinstance(record, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_NOT_OBJECT",
                "P0",
                "a new record must be a JSON object",
                path=relative,
            ))
            continue
        if record.get("authorization_id") != FULL_CONVERGENCE_AUTHORIZATION_ID:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_AUTHORIZATION_MISMATCH",
                "P0",
                "a new record does not use the new epoch authorization",
                path=relative,
            ))
        if record.get("authorization_base_head_sha") != FULL_CONVERGENCE_BASE_HEAD:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BASE_HEAD_MISMATCH",
                "P0",
                "a new record is not rooted at d701",
                path=relative,
            ))
        if record.get("baseline_report_sha256") != FULL_CONVERGENCE_BASELINE_SHA:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BASELINE_MISMATCH",
                "P0",
                "a new record is not bound to the d701 raw report",
                path=relative,
            ))
        if record.get("binding_head_sha") != manifest.get("binding_head_sha"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BINDING_HEAD_MISMATCH",
                "P0",
                "record and batch manifest bind different Heads",
                path=relative,
            ))
        if record.get("binding_tree_sha") != manifest.get("binding_tree_sha"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BINDING_TREE_MISMATCH",
                "P0",
                "record and batch manifest bind different trees",
                path=relative,
            ))
        expected_payload_sha = _sha_bytes(_canonical(_record_payload(record)))
        if record.get("record_payload_sha256") != expected_payload_sha:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PAYLOAD_HASH_MISMATCH",
                "P0",
                "record payload digest does not bind its canonical content",
                path=relative,
            ))
        if record.get("record_payload_sha256") != binding.get("record_payload_sha256"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PAYLOAD_BINDING_MISMATCH",
                "P0",
                "record payload digest differs from the explicit manifest binding",
                path=relative,
            ))
        if record.get("previous_correction_chain_sha256") != binding.get("previous_correction_chain_sha256"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PREDECESSOR_BINDING_MISMATCH",
                "P0",
                "record predecessor differs from the explicit manifest chain",
                path=relative,
            ))
        if record.get("correction_id") != binding.get("correction_id"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_ID_BINDING_MISMATCH",
                "P0",
                "record correction id differs from the explicit manifest binding",
                path=relative,
            ))
        if record.get("future_failure_policy") != {
            "FUTURE_FAILURE_AUTO_CORRECTION_COUNT": 0,
            "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
        }:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_FUTURE_AUTO_CORRECTION_ENABLED",
                "P0",
                "record future-failure policy is not exact and fail-closed",
                path=relative,
            ))
        rules = record.get("rule_ids", [])
        if not isinstance(rules, list) or len(rules) != 1 or not str(rules[0]).startswith(HISTORY_PREFIX):
            findings.append(_finding(
                "FULL_CONVERGENCE_CURRENT_FAILURE_CORRECTION",
                "P0",
                "a new record is not restricted to one historical rule",
                path=relative,
            ))
        subjects = record.get("identity_binding_by_failure")
        if not isinstance(subjects, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_SUBJECT_PROJECTION_MISSING",
                "P0",
                "record lacks per-fingerprint subject projections",
                path=relative,
            ))
        else:
            for fingerprint, subject in subjects.items():
                if not isinstance(subject, dict):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_SUBJECT_PROJECTION_INVALID",
                        "P0",
                        "subject projection is not an object",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
                    continue
                projection = subject.get("subject_projection")
                if (
                    not isinstance(projection, dict)
                    or subject.get("subject_projection_sha256") != _sha_bytes(_canonical(projection))
                ):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_SUBJECT_PROJECTION_HASH_MISMATCH",
                        "P0",
                        "subject projection is not bound by its canonical digest",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
                    continue
                selector = subject.get("authority_selectors")
                binding_head = str(record.get("binding_head_sha", ""))
                if not _selector_is_exact(selector):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_SUBJECT_SELECTOR_NOT_EXACT",
                        "P0",
                        "subject projection lacks an exact wildcard-free selector",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
                    continue
                binding_projection = _subject_projection(root, binding_head, selector)
                current_projection = _subject_projection(root, evaluated_head, selector)
                if binding_projection != projection:
                    findings.append(_finding(
                        "FULL_CONVERGENCE_SUBJECT_BINDING_MISMATCH",
                        "P0",
                        "subject projection differs from its binding Head",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
                if current_projection != projection:
                    findings.append(_finding(
                        "FULL_CONVERGENCE_SUBJECT_PROJECTION_CHANGED",
                        "P0",
                        "subject projection changed at the evaluated Head",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
        record_fingerprints = [str(value) for value in record.get("failure_fingerprints", [])]
        if record_fingerprints != list(binding.get("failure_fingerprints", [])):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_FINGERPRINT_BINDING_MISMATCH",
                "P0",
                "record fingerprint set differs from the batch manifest",
                path=relative,
            ))
        if not isinstance(subjects, dict) or set(subjects) != set(record_fingerprints):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_IDENTITY_BINDING_SET_MISMATCH",
                "P0",
                "record must bind one exact identity projection per fingerprint",
                path=relative,
            ))
        all_fingerprints.extend(record_fingerprints)
    if previous != manifest.get("record_chain_terminal_sha256"):
        findings.append(_finding(
            "FULL_CONVERGENCE_CHAIN_TERMINAL_MISMATCH",
            "P0",
            "batch terminal does not equal the final record payload",
        ))
    if sorted(all_fingerprints) != manifest_fingerprints or len(all_fingerprints) != len(set(all_fingerprints)):
        findings.append(_finding(
            "FULL_CONVERGENCE_BATCH_COVERAGE_MISMATCH",
            "P0",
            "record bindings do not cover each manifest fingerprint exactly once",
        ))
    for fingerprint in sorted(set(manifest_fingerprints)):
        if fingerprint in baseline_fingerprints["current"]:
            findings.append(_finding(
                "FULL_CONVERGENCE_CURRENT_FAILURE_CORRECTION",
                "P0",
                "a manifest fingerprint belongs to the frozen current-failure set",
                fingerprint=fingerprint,
            ))
        elif fingerprint not in baseline_fingerprints["historical"]:
            findings.append(_finding(
                "FULL_CONVERGENCE_FINGERPRINT_NOT_AUTHORIZED_HISTORICAL",
                "P0",
                "a manifest fingerprint is absent from the frozen historical-failure set",
                fingerprint=fingerprint,
            ))
    for fingerprint in sorted(set(manifest_fingerprints) & legacy_fingerprints):
        findings.append(_finding(
            "FULL_CONVERGENCE_LEGACY_FINGERPRINT_REUSE",
            "P0",
            "a new-epoch batch repeats a fingerprint already corrected by the frozen legacy epoch",
            fingerprint=fingerprint,
        ))
    for fingerprint in sorted(set(all_fingerprints)):
        if fingerprint in baseline_fingerprints["current"]:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_CURRENT_FAILURE_CORRECTION",
                "P0",
                "a record fingerprint belongs to the frozen current-failure set",
                fingerprint=fingerprint,
            ))
        elif fingerprint not in baseline_fingerprints["historical"]:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_FINGERPRINT_NOT_AUTHORIZED_HISTORICAL",
                "P0",
                "a record fingerprint is absent from the frozen historical-failure set",
                fingerprint=fingerprint,
            ))
    return {
        "schema_version": "space_syndicate.v076.reuse_correction_v2.full_convergence_independent_audit.v1",
        "authorization_id": FULL_CONVERGENCE_AUTHORIZATION_ID,
        "authorization_base_head_sha": FULL_CONVERGENCE_BASE_HEAD,
        "authorized_head_sha": FULL_CONVERGENCE_BASE_HEAD,
        "evaluated_head_sha": evaluated_head,
        "raw_failure_count": 566,
        "raw_historical_failure_count": 510,
        "raw_current_delta_failure_count": 56,
        "manifest_path": str(manifest_path),
        "legacy_record_count": len(LEGACY_RECORD_SHA_BY_PATH),
        "new_record_count": len(bindings),
        "new_fingerprint_count": len(all_fingerprints),
        "p0": [item for item in findings if item["severity"] == "P0"],
        "p1": [item for item in findings if item["severity"] == "P1"],
        "status": "GO" if not findings else "NO_GO",
    }


def _markdown(title: str, report: dict[str, Any]) -> str:
    lines = [f"# {title}", "", f"- Status: `{report['status']}`", f"- P0: `{len(report['p0'])}`", f"- P1: `{len(report['p1'])}`", f"- Authorized head: `{report['authorized_head_sha']}`", f"- Raw failures: `{report['raw_failure_count']}`", f"- Raw historical: `{report['raw_historical_failure_count']}`", f"- Raw current delta: `{report['raw_current_delta_failure_count']}`", ""]
    if "registry_unresolved_historical_row_count" in report:
        lines.extend([
            f"- Registry-unresolved historical rows retained as blocking: `{report['registry_unresolved_historical_row_count']}`",
            f"- Historical rows without concrete path/blob subject: `{report.get('historical_rows_without_concrete_path_count', 0)}`",
            "",
            "Unresolved fingerprints are retained in `registry_unresolved_historical_fingerprints` in the JSON report; none are treated as corrected.",
            "",
        ])
    for label in ("P0", "P1"):
        entries = report[label.casefold()]
        lines.extend([f"## {label}", ""])
        if not entries:
            lines.append("None.")
        else:
            for item in entries:
                evidence = ", ".join(f"{k}={v}" for k, v in item.get("evidence", {}).items())
                lines.append(f"- `{item['code']}` — {item['message']} ({evidence})")
        lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument(
        "--output-root",
        type=Path,
        default=None,
        help="write audit reports beneath this root while reading only --project inputs",
    )
    parser.add_argument(
        "--full-convergence-batch-manifest",
        type=Path,
        default=None,
        help="independently audit only the explicitly enumerated new-epoch batch",
    )
    parser.add_argument(
        "--previous-batch-manifest",
        type=Path,
        default=None,
        help="explicit immediate predecessor manifest for a non-initial full-convergence batch",
    )
    parser.add_argument(
        "--full-convergence-baseline-report",
        type=Path,
        default=None,
        help="explicit d701 raw report bound by the full-convergence authorization",
    )
    parser.add_argument(
        "--evaluated-head-ref",
        default="HEAD",
        help="Head used for subject-projection invalidation in full-convergence mode",
    )
    args = parser.parse_args(argv)
    root = args.project.resolve()
    output_root = (args.output_root or root).resolve()
    out = output_root / OUT_DIR
    out.mkdir(parents=True, exist_ok=True)
    if args.full_convergence_batch_manifest is not None:
        if args.full_convergence_baseline_report is None:
            raise SystemExit(
                "--full-convergence-batch-manifest requires "
                "--full-convergence-baseline-report"
            )
        report = audit_full_convergence_batch(
            root,
            args.full_convergence_batch_manifest.resolve(),
            evaluated_head=_git(root, "rev-parse", f"{args.evaluated_head_ref}^{{commit}}"),
            baseline_report_path=args.full_convergence_baseline_report.resolve(),
            previous_batch_manifest_path=(
                args.previous_batch_manifest.resolve()
                if args.previous_batch_manifest is not None
                else None
            ),
        )
        (out / "audit_full_convergence_batch.json").write_bytes(_canonical(report))
        (out / "audit_full_convergence_batch.md").write_text(
            _markdown("Independent Audit — Full-convergence V2 batch", report),
            encoding="utf-8",
        )
        print(json.dumps({"full_convergence_batch": report}, ensure_ascii=False, indent=2))
        return 0 if report["status"] == "GO" else 1
    report_a = audit_a(root)
    report_b = audit_b(root)
    (out / "audit_a_mechanism_safety.json").write_bytes(_canonical(report_a))
    (out / "audit_a_mechanism_safety.md").write_text(_markdown("Audit A — Correction mechanism safety", report_a), encoding="utf-8")
    (out / "audit_b_failure_classification.json").write_bytes(_canonical(report_b))
    (out / "audit_b_failure_classification.md").write_text(_markdown("Audit B — Failure classification accuracy", report_b), encoding="utf-8")
    print(json.dumps({"audit_a": report_a, "audit_b": report_b}, ensure_ascii=False, indent=2))
    return 0 if report_a["status"] == "GO" and report_b["status"] == "GO" else 1


if __name__ == "__main__":
    raise SystemExit(main())

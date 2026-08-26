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


def _sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha_file(path: Path) -> str:
    return _sha_bytes(path.read_bytes())


def _json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


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


def _canonical(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


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
    args = parser.parse_args(argv)
    root = args.project.resolve()
    output_root = (args.output_root or root).resolve()
    out = output_root / OUT_DIR
    out.mkdir(parents=True, exist_ok=True)
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

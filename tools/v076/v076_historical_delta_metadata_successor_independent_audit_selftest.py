#!/usr/bin/env python3
"""Focused self-test for HDM successor independent audit invariants."""

from __future__ import annotations

import json

try:
    from . import v076_historical_delta_metadata_successor_independent_audit as audit
except ImportError:  # pragma: no cover
    import v076_historical_delta_metadata_successor_independent_audit as audit


def main() -> int:
    checks = []
    valid = {"path": "reports/raw.json", "sha256": "a" * 64, "head_sha": "b" * 40, "tree_sha": "c" * 40}
    checks.append(audit.tuple_ok(valid))
    checks.append(not audit.tuple_ok({**valid, "sha256": "*"}))
    checks.append(not audit.tuple_ok({**valid, "tree_sha": "future"}))
    checks.append(audit.SELECTOR["future_failure_auto_match"] is False)
    checks.append(audit.FUTURE["new_failure_requires_new_record"] is True)
    result = {"status": "PASS" if all(checks) else "FAIL", "checks": sum(bool(value) for value in checks), "check_count": len(checks), "failures": [] if all(checks) else ["HDMS_INDEPENDENT_AUDIT_INVARIANT_FAILED"], "imports_primary_validator": False}
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

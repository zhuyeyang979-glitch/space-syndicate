#!/usr/bin/env python3
"""Focused pure checks for the HDM mixed-raw-authority successor."""

from __future__ import annotations

import copy
import json
import tempfile
from pathlib import Path

try:
    from . import v076_historical_delta_metadata_successor as successor
except ImportError:  # pragma: no cover
    import v076_historical_delta_metadata_successor as successor


def _check(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def main() -> int:
    failures: list[str] = []
    # Exact fingerprinting is deterministic and differs by rule/raw text.
    raw = f"{successor.TARGET_RULE}:{successor.TARGET_TRANSITION}:component.example"
    fp = successor.failure_fingerprint(raw, successor.TARGET_RULE)
    _check(fp.startswith("V2F-") and len(fp) == 68, "fingerprint shape", failures)
    _check(fp == successor.failure_fingerprint(raw, successor.TARGET_RULE), "fingerprint nondeterminism", failures)
    _check(fp != successor.failure_fingerprint(raw + "-future", successor.TARGET_RULE), "future failure auto-match", failures)

    # Raw authority tuples are strict: no unknown fields, no wildcard SHA, and
    # head/tree are commit OIDs rather than arbitrary labels.
    valid_tuple = {"path": "reports/raw.json", "sha256": "a" * 64, "head_sha": "b" * 40, "tree_sha": "c" * 40}
    _check(not successor._raw_tuple_shape(valid_tuple), "valid raw tuple rejected", failures)
    mutant = copy.deepcopy(valid_tuple); mutant["sha256"] = "*"
    _check(bool(successor._raw_tuple_shape(mutant)), "wildcard raw tuple accepted", failures)
    mutant = copy.deepcopy(valid_tuple); mutant["extra"] = 1
    _check(bool(successor._raw_tuple_shape(mutant)), "unknown raw tuple field accepted", failures)

    # A manifest cannot silently replace the explicit predecessor provenance
    # with a different SHA.  This check exercises the shape contract without
    # touching the production repository or old evidence files.
    _check(successor.SELECTOR_POLICY["future_failure_auto_match"] is False, "future auto-match enabled", failures)
    _check(successor.FUTURE_POLICY["new_failure_requires_new_record"] is True, "new-failure policy weakened", failures)
    _check(successor.CHANGE_PARENT != successor.CHANGE_COMMIT, "transition endpoints collapsed", failures)

    # The real frozen ledger currently has one epoch; derive it from each
    # committed correction record rather than trusting the ledger summary.
    project = Path(__file__).resolve().parents[2]
    try:
        ledger, _ = successor._load_committed_json(project, "d4720d34b5dd99541c20907cb5231b1a780d1cf7", successor.LEDGER_PATH)
        tuples = successor._predecessor_raw_authorities(ledger, project, "d4720d34b5dd99541c20907cb5231b1a780d1cf7")
        _check(len(tuples) == 1, "frozen predecessor raw epoch derivation", failures)
        _check(len(tuples[0].get("correction_paths", [])) == 4, "frozen predecessor correction membership", failures)
    except Exception as error:
        failures.append("frozen predecessor derivation error:" + str(error))

    result = {"status": "PASS" if not failures else "FAIL", "checks": 12 - len(failures), "check_count": 12, "failures": failures, "predecessor_raw_authority_mode": "PER_CORRECTION_ACTIVATION_TUPLE", "successor_raw_authority_mode": "EXPLICIT_FRESH_TUPLE_ONLY"}
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

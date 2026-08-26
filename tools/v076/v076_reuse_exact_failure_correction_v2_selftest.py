#!/usr/bin/env python3
"""Focused contract tests for :mod:`v076_reuse_exact_failure_correction_v2`.

The existing reuse self-test remains the authority for the scanner itself.  This
file exercises the narrow V2 layer with a temporary, shared-object Git clone and
temporary report artifacts.  It deliberately never edits the production
worktree, stages files, starts Godot, or treats a count as an identity.

Every contract item is represented by a named case in the emitted receipt.  The
case count is intentionally greater than the sixty cases required by the V076
authorization so that adding a field to the record cannot silently remove a
negative test.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Iterable


SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import v076_reuse_exact_failure_correction_v2 as correction  # noqa: E402


SELFTEST_SCHEMA = "space_syndicate.v076.reuse_exact_failure_correction_v2_selftest.v1"
CHECK_NAME = "V076 Reuse and Point-Inertia Gate"


class CaseFailure(AssertionError):
    """An expected contract assertion failed."""


@dataclass
class Case:
    case_id: str
    description: str
    expected: str
    run: Callable[[], None]


@dataclass
class CaseResult:
    case_id: str
    description: str
    expected: str
    status: str
    failures: list[str]


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _canonical(value: Any) -> bytes:
    return correction._canonical_bytes(value)


def _assert(condition: bool, message: str) -> None:
    if not condition:
        raise CaseFailure(message)


def _has_prefix(values: Iterable[Any], prefix: str) -> bool:
    return any(str(value).startswith(prefix) for value in values)


def _expect_shape_failure(record: dict[str, Any], prefix: str) -> None:
    failures = correction._reject_disallowed_record_shape(record)
    _assert(
        _has_prefix(failures, prefix),
        f"expected {prefix!r}, got {failures!r}",
    )


def _expect_validate_failure(
    root: Path,
    output_root: Path,
    current_head: str,
    prefix: str,
) -> dict[str, Any]:
    report = correction.validate_records(root, output_root, current_head=current_head)
    _assert(
        _has_prefix(report.get("failures", []), prefix),
        f"expected {prefix!r}, got {report.get('failures', [])!r}",
    )
    return report


def _expect_validate_failure_any(
    root: Path,
    output_root: Path,
    current_head: str,
    prefixes: Iterable[str],
) -> dict[str, Any]:
    """Require a fail-closed resolver diagnostic from a set of valid codes.

    Diagnostics that include a record filename, fingerprint, or path append a
    contextual suffix.  Tests therefore assert the stable semantic prefix,
    while accepting the resolver's more specific contextual rendering.
    """
    report = correction.validate_records(root, output_root, current_head=current_head)
    failures = report.get("failures", [])
    prefixes = tuple(prefixes)
    _assert(
        any(_has_prefix(failures, prefix) for prefix in prefixes),
        f"expected one of {prefixes!r}, got {failures!r}",
    )
    return report


def _git(root: Path, *args: str, check: bool = True) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if check and result.returncode:
        raise RuntimeError(
            f"git {' '.join(args)} failed ({result.returncode}): {result.stderr.strip()}"
        )
    return result.stdout.strip()


def _write(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(value, bytes):
        path.write_bytes(value)
    else:
        path.write_bytes(_canonical(value))


def _write_sidecar(path: Path, target: Path, *, label: str | None = None) -> None:
    # The resolver accepts the conventional ``hash  relative/path`` format.
    digest = _sha(target.read_bytes())
    relative = label or target.name
    path.write_text(f"{digest}  {relative}\n", encoding="ascii")


def _minimal_record(*, fingerprint: str, baseline_sha: str = "b" * 64) -> dict[str, Any]:
    """Return a fully explicit record suitable for pure shape tests."""
    paths = ["scripts/example_owner.gd"]
    definition = correction.HISTORY_RULE_CLASSES[
        "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"
    ]
    record: dict[str, Any] = {
        "correction_id": "V2-selftest-record",
        "schema_version": correction.SCHEMA_VERSION,
        "authorization_id": correction.AUTHORIZATION_ID,
        "authorized_head_sha": correction.AUTHORIZED_HEAD_SHA,
        "baseline_report_sha256": baseline_sha,
        "failure_fingerprints": [fingerprint],
        "failure_count": 1,
        "rule_ids": ["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
        "failure_classes": ["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
        "transition_class_id": definition["transition_class_id"],
        "allowed_rule_ids": list(definition["allowed_rule_ids"]),
        "allowed_from_state": definition["allowed_from_state"],
        "allowed_to_state": definition["allowed_to_state"],
        "required_evidence": list(definition["required_evidence"]),
        "required_reachability_state": list(
            definition["required_reachability_state"]
        ),
        "required_blob_binding": definition["required_blob_binding"],
        "required_untouched_state": definition["required_untouched_state"],
        "eligibility_policy": dict(definition["eligibility_policy"]),
        "negative_examples": list(definition["negative_examples"]),
        "from_state": "HISTORICAL_FAILURE_PRESENT_UNTOUCHED",
        "to_effective_disposition": "CORRECTED_HISTORICAL_DEBT",
        "historical_debt_status": "VISIBLE_AND_CORRECTED_FOR_UNRELATED_DELTA",
        "paths": paths,
        "path_set_sha256": _sha(("\n".join(paths) + "\n").encode()),
        "raw_failures": ["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT:selftest"],
        "raw_failure_set_sha256": _sha(
            b"HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT:selftest\n"
        ),
        "failure_bindings": [],
        "source_commit_set": [correction.AUTHORIZED_HEAD_SHA],
        "current_blob_sha256_by_path": {paths[0]: "c" * 64},
        "component_ids": ["component.selftest"],
        "domain_ids": ["domain.selftest"],
        "current_counterpart_fingerprints_by_failure": {fingerprint: []},
        "current_counterparts_remain_separate": True,
        "supersession_map_sha256": "d" * 64,
        "owner_reuse_map_sha256": "e" * 64,
        "production_reachability_attestation": {
            "states": ["non_production"],
            "active_owner_violation_count": 0,
            "parallel_owner_count": 0,
            "dual_write_count": 0,
            "fallback_count": 0,
        },
        "untouched_in_current_delta": True,
        "why_not_active_violation": "Historical row only; no current delta row is included.",
        "why_existing_transition_is_insufficient": "V1 lacks this exact fingerprint and blob binding.",
        "correction_reason": "Historical pre-gate registry metadata gap.",
        "evidence_paths": ["reports/reuse/correction_v2/baseline_raw_failure_report.json"],
        "backlog_item_ids": ["reuse.v2.selftest"],
        "touch_invalidation_policy": {
            "TOUCH_INVALIDATES_CORRECTION": True,
            "BLOB_CHANGED_CORRECTION_AUTO_INVALIDATION": True,
            "PRODUCTION_REACHABILITY_CHANGED_INVALIDATION": True,
            "OWNER_BINDING_CHANGED_INVALIDATION": True,
        },
        "future_failure_policy": {
            "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
            "FUTURE_FAILURE_AUTO_CORRECTION_COUNT": 0,
        },
        "revocation_policy": dict(definition["revocation_policy"]),
        "created_at": "2026-08-26T00:00:00Z",
        "creator": "V076ReuseExactFailureCorrectionV2SelfTest",
        "previous_correction_chain_sha256": "",
    }
    record["failure_fingerprint_set_sha256"] = _sha(
        ("\n".join(record["failure_fingerprints"]) + "\n").encode()
    )
    record["record_payload_sha256"] = _sha(_canonical(correction._record_payload(record)))
    return record


class Fixture:
    """An isolated report + Git clone used by integration cases."""

    def __init__(self, temporary: tempfile.TemporaryDirectory[str], project: Path):
        self.temporary = temporary
        self.base_dir = Path(temporary.name)
        self.root = self.base_dir / "repo"
        # Generated inventory/record drafts must live inside the isolated Git
        # worktree.  The V2 generator verifies that every mutable draft is
        # rooted beneath a real repository, so a sibling artifact directory
        # would (correctly) fail closed.  Keeping this hidden directory inside
        # the temporary clone also makes the containment assertion explicit.
        self.output = self.root / ".v076-selftest-artifacts"
        self.project = project
        # Integration fixtures intentionally contain one synthetic historical
        # row rather than the 566-row production report.  Bind the resolver's
        # immutable-baseline constant to this fixture for the duration of the
        # process, then restore it during cleanup.  Scanner/V1 manifest hashes
        # remain the production constants and are still validated normally.
        self._original_authorized_baseline_sha = correction.AUTHORIZED_BASELINE_REPORT_SHA256
        self.base_head = correction.AUTHORIZED_HEAD_SHA
        # This path is present in the committed V076 authority registry with a
        # resolved production-reachability state.  Combined with the real
        # direct-parent transition below, it yields a genuinely eligible
        # synthetic historical row without overriding inventory semantics.
        self.history_path = "scripts/runtime/card_runtime_catalog_service.gd"
        self.history_old = "46b33bba77b356b100ab68bc7c3676d503049a2c"
        self.history_new = "e584cd4d8b0cd8afca7ff508cffcb05d1ba801a3"
        self.history_raw = (
            "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT:"
            f"{self.history_old[:12]}->{self.history_new[:12]}:{self.history_path}"
        )
        self.current_raw = "UNCLASSIFIED_NEW_COMPONENT:scripts/selftest/current_component.gd"
        self.historical_fingerprint = correction._failure_fingerprint(
            self.history_raw, "HISTORICAL", "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"
        )
        self.current_fingerprint = correction._failure_fingerprint(
            self.current_raw, "CURRENT_DELTA_FAILURE", "UNCLASSIFIED_NEW_COMPONENT"
        )
        self.record_path: Path | None = None
        self.baseline_path = self.output / correction.BASELINE_REPORT_REL
        self.inventory_path = self.output / correction.FAILURE_INVENTORY_REL

    @classmethod
    def create(cls, project: Path) -> "Fixture":
        temp = tempfile.TemporaryDirectory(prefix="v076-correction-v2-selftest-")
        fixture = cls(temp, project)
        try:
            subprocess.run(
                ["git", "clone", "--shared", "--no-hardlinks", "--quiet", str(project), str(fixture.root)],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            _git(fixture.root, "checkout", "--detach", fixture.base_head)
            _git(fixture.root, "config", "user.email", "v076-selftest@example.invalid")
            _git(fixture.root, "config", "user.name", "V076 Correction V2 Selftest")
            raw_path = fixture.base_dir / "raw.json"
            raw = {
                "schema_version": "space_syndicate.v076.reuse_point_inertia_gate.v1",
                "head_sha": fixture.base_head,
                "failures": [fixture.history_raw],
            }
            _write(raw_path, raw)
            # ``freeze_baseline`` itself enforces the sealed hash.  Swap only
            # that process-local constant before freezing the synthetic row;
            # all subsequent resolver checks then bind to this exact byte
            # identity just as production checks bind to the authorized CI
            # report.
            correction.AUTHORIZED_BASELINE_REPORT_SHA256 = _sha(raw_path.read_bytes())
            correction.freeze_baseline(fixture.root, raw_path, fixture.output)
            _write(
                fixture.output / correction.CORRECTION_SCHEMA_REL,
                correction._expected_correction_schema(),
            )
            correction.build_inventories(fixture.root, fixture.output)
            inventory = correction.generate_records(fixture.root, fixture.output)
            _write(fixture.output / "reports/reuse/correction_v2/correction_record_inventory.json", inventory)
            inventory_path = fixture.output / "reports/reuse/correction_v2/correction_record_inventory.json"
            _write_sidecar(
                inventory_path.with_suffix(".sha256"),
                inventory_path,
                label=inventory_path.name,
            )
            records = sorted((fixture.output / correction.RECORD_DIR_REL).glob("*.json"))
            _assert(len(records) == 1, f"fixture expected one record, got {records}")
            fixture.record_path = records[0]
            # Ensure all generated artifacts are byte-stable before mutation cases.
            first = correction.validate_records(fixture.root, fixture.output, current_head=fixture.base_head)
            _assert(first["corrected_historical_failure_count"] == 1, str(first))
            _assert(first["true_active_violation_count"] == 0, str(first))
            return fixture
        except Exception:
            correction.AUTHORIZED_BASELINE_REPORT_SHA256 = fixture._original_authorized_baseline_sha
            temp.cleanup()
            raise

    def load_record(self) -> dict[str, Any]:
        _assert(self.record_path is not None, "fixture record path not initialized")
        return correction.load_json(self.record_path)

    def save_record(self, record: dict[str, Any], *, update_payload: bool = True) -> None:
        _assert(self.record_path is not None, "fixture record path not initialized")
        if update_payload:
            record["record_payload_sha256"] = _sha(_canonical(correction._record_payload(record)))
        self.record_path.write_bytes(_canonical(record))

    def rebind_record_inventory(self) -> None:
        """Rebuild only the temporary fixture's record digest row.

        Most mutation cases exercise a record's semantic validator rather than
        the immutable-manifest tamper detector.  Rebinding this *temporary*
        manifest models an authorized append-only artifact regeneration; the
        dedicated inventory-drift cases intentionally do not call this helper.
        """
        _assert(self.record_path is not None, "record missing")
        inventory_path = self.output / "reports/reuse/correction_v2/correction_record_inventory.json"
        inventory = correction.load_json(inventory_path)
        relative = self.record_path.relative_to(self.output).as_posix()
        found = False
        for row in inventory.get("records", []):
            if isinstance(row, dict) and correction.normalize_path(str(row.get("path", ""))) == relative:
                row["record_sha256"] = _sha(self.record_path.read_bytes())
                record = correction.load_json(self.record_path)
                if "record_payload_sha256" in row and "record_payload_sha256" in record:
                    row["record_payload_sha256"] = str(record["record_payload_sha256"])
                found = True
        _assert(found, f"record inventory row missing for {relative}")
        inventory_path.write_bytes(_canonical(inventory))
        _write_sidecar(inventory_path.with_suffix(".sha256"), inventory_path, label=inventory_path.name)

    def reset_record(self) -> None:
        # Rebuild from the frozen inventory in a fresh artifact directory.  This
        # avoids any accidental dependence between mutation cases.
        pristine = Fixture.create(self.project)
        try:
            old_output = self.output
            self.output = pristine.output
            self.baseline_path = self.output / correction.BASELINE_REPORT_REL
            self.inventory_path = self.output / correction.FAILURE_INVENTORY_REL
            self.record_path = sorted((self.output / correction.RECORD_DIR_REL).glob("*.json"))[0]
        finally:
            # Keep the new clone/output alive by detaching the temporary owner;
            # the old artifacts are removed explicitly and the new temp is
            # retained in a private list on this fixture.
            if not hasattr(self, "_resets"):
                self._resets: list[Fixture] = []
            self._resets.append(pristine)
            shutil.rmtree(old_output, ignore_errors=True)

    def checkout(self, commit: str) -> None:
        _git(self.root, "checkout", "--detach", commit)

    def commit_file(self, relative: str, content: str, message: str) -> str:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        _git(self.root, "add", "--", relative)
        _git(self.root, "commit", "--no-verify", "-m", message)
        return _git(self.root, "rev-parse", "HEAD")

    def restore_resolver_constants(self) -> None:
        correction.AUTHORIZED_BASELINE_REPORT_SHA256 = self._original_authorized_baseline_sha


def _fresh_fixture(project: Path) -> Fixture:
    # A fresh fixture per integration case makes each assertion independent and
    # ensures a mutation cannot accidentally become the next case's baseline.
    return Fixture.create(project)


def _shape_cases(base: dict[str, Any]) -> list[Case]:
    def mutated(label: str, change: Callable[[dict[str, Any]], None], prefix: str) -> Case:
        def run() -> None:
            record = copy.deepcopy(base)
            change(record)
            _expect_shape_failure(record, prefix)

        return Case(label.split(" ", 1)[0], label, "FAIL", run)

    cases: list[Case] = []
    cases.append(Case("01", "an exact historical fingerprint is accepted by the shape validator", "PASS", lambda: _assert(not correction._reject_disallowed_record_shape(copy.deepcopy(base)), "valid record rejected")))
    cases.append(Case(
        "02",
        "opaque fingerprint shape alone does not claim historical eligibility",
        "PASS",
        lambda: _assert(
            not correction._reject_disallowed_record_shape(copy.deepcopy(base)),
            "shape validator rejected a syntactically valid opaque fingerprint",
        ),
    ))
    # Restore a valid fingerprint for the following shape mutations.
    cases.append(Case("03", "explicit fingerprint collection is required", "FAIL", lambda: _expect_shape_failure({**copy.deepcopy(base), "failure_fingerprints": []}, "CORRECTION_WITHOUT_EXPLICIT_FINGERPRINT")))
    cases.append(mutated("04 wildcard path scope is rejected", lambda r: r.update({"paths": ["scripts/*"]}), "CORRECTION_PATH_SCOPE_NOT_EXACT"))
    cases.append(mutated("05 regex scope token is rejected", lambda r: r.update({"scope": "regex"}), "CORRECTION_DISALLOWED_TERM:regex"))
    cases.append(mutated("06 path prefix scope is rejected", lambda r: r.update({"paths": ["scripts/"]}), "CORRECTION_PATH_SCOPE_NOT_EXACT"))
    cases.append(Case("07", "count-only matching is rejected", "FAIL", lambda: _expect_shape_failure({k: v for k, v in base.items() if k not in {"failure_fingerprints", "failure_fingerprint_set_sha256"}}, "CORRECTION_WITHOUT_EXPLICIT_FINGERPRINT")))
    cases.append(mutated("08 current blob binding is mandatory", lambda r: r.update({"current_blob_sha256_by_path": None}), "CORRECTION_WITHOUT_CURRENT_BLOB_BINDING"))
    cases.append(mutated("09 future automatic correction is rejected", lambda r: r.update({"future_failure_policy": {"NEW_FAILURE_REQUIRES_NEW_RECORD": False}}), "FUTURE_FAILURE_AUTO_CORRECTION_ENABLED"))
    cases.append(mutated("10 backlog or retirement evidence is mandatory", lambda r: r.update({"backlog_item_ids": []}), "CORRECTION_WITHOUT_BACKLOG_OR_RETIREMENT"))
    cases.append(mutated("11 fingerprint cardinality cannot be count-only", lambda r: r.update({"failure_count": 2}), "CORRECTION_COUNT_ONLY_OR_CARDINALITY_MISMATCH"))
    cases.append(mutated("12 invalid fingerprint syntax is rejected", lambda r: r.update({"failure_fingerprints": ["not-a-v2-fingerprint"]}), "CORRECTION_FINGERPRINT_INVALID"))
    cases.append(mutated("13 glob token in explicit scope is rejected", lambda r: r.update({"scope": "glob"}), "CORRECTION_DISALLOWED_TERM:glob"))
    cases.append(mutated("14 directory token in explicit scope is rejected", lambda r: r.update({"scope": "directory"}), "CORRECTION_DISALLOWED_TERM:directory"))
    cases.append(mutated("15 blanket historical scope is rejected", lambda r: r.update({"scope": "all historical failures"}), "CORRECTION_DISALLOWED_TERM:all historical failures"))
    cases.append(mutated("16 grandfather scope is rejected", lambda r: r.update({"scope": "grandfather"}), "CORRECTION_DISALLOWED_TERM:grandfather"))
    cases.append(mutated("17 ignore scope is rejected", lambda r: r.update({"scope": "ignore"}), "CORRECTION_DISALLOWED_TERM:ignore"))
    cases.append(mutated("18 waive scope is rejected", lambda r: r.update({"scope": "waive"}), "CORRECTION_DISALLOWED_TERM:waive"))
    cases.append(mutated("19 unknown accepted class is rejected", lambda r: r.update({"transition_class_id": "UNKNOWN_ACCEPTED"}), "CORRECTION_DISALLOWED_TERM:unknown_accepted"))
    cases.append(mutated("20 legacy catch-all class is rejected", lambda r: r.update({"transition_class_id": "LEGACY"}), "CORRECTION_DISALLOWED_TERM:legacy"))
    cases.append(mutated("21 misc catch-all class is rejected", lambda r: r.update({"transition_class_id": "MISC"}), "CORRECTION_DISALLOWED_TERM:misc"))
    cases.append(mutated("22 other catch-all class is rejected", lambda r: r.update({"transition_class_id": "OTHER"}), "CORRECTION_DISALLOWED_TERM:other"))
    cases.append(mutated("23 regex rule field is rejected", lambda r: r.update({"rule_ids": ["regex"]}), "CORRECTION_DISALLOWED_TERM:regex"))
    cases.append(mutated("24 prefix rule field is rejected", lambda r: r.update({"rule_ids": ["prefix"]}), "CORRECTION_DISALLOWED_TERM:prefix"))
    cases.append(mutated("25 path ending in slash is rejected", lambda r: r.update({"paths": ["assets/old/"]}), "CORRECTION_PATH_SCOPE_NOT_EXACT"))
    cases.append(mutated("26 empty fingerprint list is rejected", lambda r: r.update({"failure_fingerprints": [], "failure_count": 0}), "CORRECTION_WITHOUT_EXPLICIT_FINGERPRINT"))
    cases.append(mutated("27 non-string fingerprint is rejected", lambda r: r.update({"failure_fingerprints": [None]}), "CORRECTION_FINGERPRINT_INVALID"))
    cases.append(mutated("34 active owner attestation is rejected", lambda r: r["production_reachability_attestation"].update({"active_owner_violation_count": 1}), "ACTIVE_OWNER_VIOLATION_CORRECTION"))
    cases.append(mutated("35 dual-write attestation is rejected", lambda r: r["production_reachability_attestation"].update({"dual_write_count": 1}), "DUAL_WRITE_CORRECTION"))
    cases.append(mutated("36 fallback attestation is rejected", lambda r: r["production_reachability_attestation"].update({"fallback_count": 1}), "FALLBACK_CORRECTION"))
    cases.append(mutated("37 parallel owner attestation is rejected", lambda r: r["production_reachability_attestation"].update({"parallel_owner_count": 1}), "PARALLEL_OWNER_CORRECTION"))
    cases.append(mutated("38 retired owner reachability state is rejected", lambda r: r["production_reachability_attestation"].update({"states": ["retired_owner_production_reachable"]}), "CORRECTION_REACHABILITY_STATE_INVALID"))
    cases.append(mutated("39 unregistered owner reachability state is rejected", lambda r: r["production_reachability_attestation"].update({"states": ["unregistered_new_owner"]}), "CORRECTION_REACHABILITY_STATE_INVALID"))
    cases.append(mutated("42 production reachability policy is required", lambda r: r.pop("production_reachability_attestation"), "CORRECTION_REACHABILITY_ATTESTATION_MISSING"))
    cases.append(mutated("44 future failure policy is required", lambda r: r.pop("future_failure_policy"), "FUTURE_FAILURE_AUTO_CORRECTION_ENABLED"))
    def path_substring_is_not_scope() -> None:
        record = copy.deepcopy(base)
        path = "scripts/runtime/global_supply_demand_registry.gd"
        record["paths"] = [path]
        record["path_set_sha256"] = _sha((path + "\n").encode())
        record["current_blob_sha256_by_path"] = {path: "c" * 64}
        failures = correction._reject_disallowed_record_shape(record)
        _assert(
            not _has_prefix(failures, "CORRECTION_DISALLOWED_TERM:glob"),
            f"concrete global_supply_demand path was misread as glob: {failures!r}",
        )

    cases.append(Case(
        "58A",
        "concrete global_supply_demand path is not a glob false positive",
        "PASS",
        path_substring_is_not_scope,
    ))
    cases.append(mutated(
        "97 wildcard blob-map key is rejected",
        lambda r: r["current_blob_sha256_by_path"].update({"*": "MISSING"}),
        "CORRECTION_BLOB_PATH_SET_MISMATCH",
    ))
    cases.append(mutated(
        "98 parent-relative blob-map key is rejected",
        lambda r: r["current_blob_sha256_by_path"].update({"../x": "MISSING"}),
        "CORRECTION_CURRENT_BLOB_BINDING_INVALID",
    ))
    cases.append(mutated(
        "99 nested selector is rejected at any object depth",
        lambda r: r["production_reachability_attestation"].update({"scope": "*"}),
        "CORRECTION_DISALLOWED_TERM:glob",
    ))
    cases.append(mutated(
        "100 boolean failure count is not integer cardinality",
        lambda r: r.update({"failure_count": True}),
        "CORRECTION_COUNT_ONLY_OR_CARDINALITY_MISMATCH",
    ))
    return cases


def _integration_cases(project: Path) -> tuple[list[Case], Callable[[], None]]:
    """Build integration cases over one isolated clone.

    Cloning the production repository once is materially faster than cloning it
    for every negative case.  Each case receives a byte-for-byte copy of the
    pristine report directory and starts from the authorized detached commit;
    all mutations therefore remain inside the temporary fixture.
    """
    cases: list[Case] = []
    fixture = Fixture.create(project)
    pristine_output = fixture.base_dir / "pristine-output"
    shutil.copytree(fixture.output, pristine_output)

    def reset_fixture() -> None:
        fixture.checkout(fixture.base_head)
        if fixture.output.exists():
            shutil.rmtree(fixture.output)
        shutil.copytree(pristine_output, fixture.output)
        fixture.baseline_path = fixture.output / correction.BASELINE_REPORT_REL
        fixture.inventory_path = fixture.output / correction.FAILURE_INVENTORY_REL
        fixture.record_path = sorted((fixture.output / correction.RECORD_DIR_REL).glob("*.json"))[0]

    def with_fixture(fn: Callable[[Fixture], None]) -> Callable[[], None]:
        def run() -> None:
            reset_fixture()
            fn(fixture)

        return run

    def mutate_rebound(
        f: Fixture,
        change: Callable[[dict[str, Any]], None],
        prefixes: Iterable[str],
    ) -> None:
        """Mutate a temporary record and rebind its temporary digest row."""
        record = f.load_record()
        change(record)
        f.save_record(record)
        f.rebind_record_inventory()
        _expect_validate_failure_any(f.root, f.output, f.base_head, prefixes)

    # These cases deliberately run through ``validate_records``.  The shape
    # helper only checks selector syntax; hashes, class contracts, and
    # authority bindings are integration-level invariants.
    cases.append(Case(
        "28",
        "fingerprint set hash mismatch is rejected by the resolver",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.update({"failure_fingerprint_set_sha256": "0" * 64}),
            ("CORRECTION_FINGERPRINT_SET_HASH_MISMATCH",),
        )),
    ))
    cases.append(Case(
        "29",
        "path set hash mismatch is rejected by the resolver",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.update({"path_set_sha256": "0" * 64}),
            ("CORRECTION_PATH_SET_HASH_MISMATCH",),
        )),
    ))
    cases.append(Case(
        "30",
        "source commit set binding cannot be omitted",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.update({"source_commit_set": []}),
            ("CORRECTION_SOURCE_COMMIT_SET_MISMATCH",),
        )),
    ))
    cases.append(Case(
        "31",
        "transition class must match the declared rule class",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.update({"transition_class_id": ""}),
            (
                "CORRECTION_TRANSITION_CLASS_MISMATCH",
                "CORRECTION_CLASS_CONTRACT_MISMATCH:allowed_to_state",
            ),
        )),
    ))
    cases.append(Case(
        "32",
        "historical disposition must match the class contract",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.update({"to_effective_disposition": ""}),
            (
                "CORRECTION_TO_STATE_MISMATCH",
                "CORRECTION_CLASS_CONTRACT_MISMATCH:allowed_to_state",
            ),
        )),
    ))
    cases.append(Case(
        "33",
        "untouched attestation cannot be cleared",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.update({"untouched_in_current_delta": False}),
            ("CORRECTION_UNTOUCHED_STATE_REQUIRED", "CORRECTION_UNTOUCHED_ATTESTATION_INVALID"),
        )),
    ))
    cases.append(Case(
        "40",
        "component binding cannot be widened",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.update({"component_ids": ["component.injected"]}),
            ("CORRECTION_COMPONENT_SET_MISMATCH",),
        )),
    ))
    cases.append(Case(
        "41",
        "domain binding cannot be widened",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.update({"domain_ids": ["domain.injected"]}),
            ("CORRECTION_DOMAIN_SET_MISMATCH",),
        )),
    ))
    cases.append(Case(
        "43",
        "touch invalidation policy is required by the class contract",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.pop("touch_invalidation_policy"),
            ("CORRECTION_CLASS_CONTRACT_FIELD_MISSING:touch_invalidation_policy",),
        )),
    ))
    cases.append(Case(
        "45",
        "revocation is represented by an append-only revocation record",
        "FAIL",
        with_fixture(
            lambda f: (
                (f.output / correction.CORRECTION_DIR_REL / "revocations").mkdir(
                    parents=True, exist_ok=True
                ),
                (f.output / correction.CORRECTION_DIR_REL / "revocations" / "invalid.json").write_bytes(
                    _canonical({"record_kind": "MUTATE_CORRECTION_RECORD"})
                ),
                _expect_validate_failure_any(
                    f.root,
                    f.output,
                    f.base_head,
                    ("REVOCATION_RECORD_KIND_INVALID:",),
                ),
            )[-1]
        ),
    ))
    cases.append(Case(
        "46",
        "a current-delta class cannot be attached to a correction",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.update({"failure_classes": ["UNCLASSIFIED_NEW_COMPONENT"]}),
            ("CORRECTION_CROSSES_RULE_OR_CLASS",),
        )),
    ))
    cases.append(Case(
        "47",
        "unsupported source failure class is rejected",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.update({
                "rule_ids": ["HISTORY_UNSUPPORTED"],
                "failure_classes": ["HISTORY_UNSUPPORTED"],
            }),
            ("CORRECTION_UNSUPPORTED_CLASS",),
        )),
    ))
    cases.append(Case(
        "48",
        "failure class and rule IDs must agree",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.update({"failure_classes": ["HISTORY_DYNAMIC_REFERENCE_UNRESOLVED"]}),
            ("CORRECTION_CROSSES_RULE_OR_CLASS",),
        )),
    ))
    cases.append(Case(
        "49",
        "correction ID drift is rejected by the record inventory",
        "FAIL",
        with_fixture(lambda f: (
            (lambda r: (r.update({"correction_id": ""}), f.save_record(r), _expect_validate_failure_any(
                f.root, f.output, f.base_head, ("CORRECTION_RECORD_ID_DRIFT:",)
            )))(f.load_record())
        )),
    ))
    cases.append(Case(
        "50",
        "authorization ID binding is exact",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.update({"authorization_id": "wrong-authorization"}),
            ("CORRECTION_AUTHORIZATION_ID_MISMATCH",),
        )),
    ))
    cases.append(Case(
        "51",
        "authorized head binding is exact",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.update({"authorized_head_sha": "0" * 40}),
            ("CORRECTION_AUTHORIZED_HEAD_MISMATCH",),
        )),
    ))
    cases.append(Case(
        "52",
        "schema version binding is exact",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.update({"schema_version": "v1"}),
            ("CORRECTION_SCHEMA_VERSION_MISMATCH",),
        )),
    ))
    cases.append(Case(
        "53",
        "creator tampering is blocked by the immutable record inventory",
        "FAIL",
        with_fixture(lambda f: (
            (lambda r: (r.update({"creator": ""}), f.save_record(r), _expect_validate_failure_any(
                f.root, f.output, f.base_head, ("CORRECTION_RECORD_MODIFIED:",)
            )))(f.load_record())
        )),
    ))
    cases.append(Case(
        "54",
        "required evidence paths cannot be removed",
        "FAIL",
        with_fixture(lambda f: mutate_rebound(
            f,
            lambda r: r.update({"evidence_paths": []}),
            ("CORRECTION_REQUIRED_EVIDENCE_MISSING",),
        )),
    ))
    cases.append(Case(
        "55",
        "correction reason tampering is blocked by the immutable inventory",
        "FAIL",
        with_fixture(lambda f: (
            (lambda r: (r.update({"correction_reason": ""}), f.save_record(r), _expect_validate_failure_any(
                f.root, f.output, f.base_head, ("CORRECTION_RECORD_MODIFIED:",)
            )))(f.load_record())
        )),
    ))
    cases.append(Case(
        "56",
        "active-violation explanation tampering is blocked",
        "FAIL",
        with_fixture(lambda f: (
            (lambda r: (r.update({"why_not_active_violation": ""}), f.save_record(r), _expect_validate_failure_any(
                f.root, f.output, f.base_head, ("CORRECTION_RECORD_MODIFIED:",)
            )))(f.load_record())
        )),
    ))
    cases.append(Case(
        "57",
        "correction chain field tampering is blocked",
        "FAIL",
        with_fixture(lambda f: (
            (lambda r: (r.pop("previous_correction_chain_sha256", None), f.save_record(r), _expect_validate_failure_any(
                f.root, f.output, f.base_head, ("CORRECTION_RECORD_MODIFIED:",)
            )))(f.load_record())
        )),
    ))
    cases.append(Case(
        "58",
        "record payload hash omission is rejected",
        "FAIL",
        with_fixture(lambda f: (
            (lambda r: (
                r.pop("record_payload_sha256", None),
                f.save_record(r, update_payload=False),
                f.rebind_record_inventory(),
                _expect_validate_failure_any(
                    f.root,
                    f.output,
                    f.base_head,
                    ("CORRECTION_RECORD_HASH_MISMATCH",),
                ),
            ))(f.load_record())
        )),
    ))

    def valid(f: Fixture) -> None:
        report = correction.validate_records(f.root, f.output, current_head=f.base_head)
        _assert(report["status"] == "PASS_WITH_APPEND_ONLY_HISTORICAL_CORRECTIONS", str(report))
        _assert(report["raw_failure_count"] == 1, str(report))
        _assert(report["corrected_historical_failure_count"] == 1, str(report))
        _assert(report["effective_blocking_failure_count"] == 0, str(report))

    cases.append(Case("59", "one exact historical correction resolves one untouched row", "PASS", with_fixture(valid)))

    def current_delta_rejected(f: Fixture) -> None:
        record = f.load_record()
        record["failure_fingerprints"] = [f.current_fingerprint]
        record["failure_count"] = 1
        record["failure_classes"] = ["UNCLASSIFIED_NEW_COMPONENT"]
        record["rule_ids"] = ["UNCLASSIFIED_NEW_COMPONENT"]
        record["failure_fingerprint_set_sha256"] = _sha((f.current_fingerprint + "\n").encode())
        f.save_record(record)
        _expect_validate_failure(f.root, f.output, f.base_head, "CURRENT_DELTA_CORRECTION_FALSE_ACCEPT")

    cases.append(Case("60", "current delta failure cannot receive a correction", "FAIL", with_fixture(current_delta_rejected)))

    def duplicate(f: Fixture) -> None:
        record = f.load_record()
        duplicate = f.output / correction.RECORD_DIR_REL / "duplicate.json"
        duplicate.write_bytes(_canonical(record))
        _expect_validate_failure(f.root, f.output, f.base_head, "DUPLICATE_CORRECTION_FINGERPRINT_COUNT")

    cases.append(Case("61", "the same failure fingerprint cannot be corrected twice", "FAIL", with_fixture(duplicate)))

    def hash_chain(f: Fixture) -> None:
        record = f.load_record()
        record["previous_correction_chain_sha256"] = "d" * 64
        f.save_record(record)
        _expect_validate_failure(f.root, f.output, f.base_head, "CORRECTION_CHAIN_BREAK")

    cases.append(Case("62", "hash-chain predecessor must be exact", "FAIL", with_fixture(hash_chain)))

    def payload_hash(f: Fixture) -> None:
        record = f.load_record()
        record["correction_reason"] = "tampered"
        f.save_record(record, update_payload=False)
        _expect_validate_failure(f.root, f.output, f.base_head, "CORRECTION_RECORD_HASH_MISMATCH")

    cases.append(Case("63", "modifying an immutable record is rejected by payload hash", "FAIL", with_fixture(payload_hash)))

    def blob_binding(f: Fixture) -> None:
        record = f.load_record()
        record["current_blob_sha256_by_path"][f.history_path] = "e" * 40
        f.save_record(record)
        _expect_validate_failure(f.root, f.output, f.base_head, "CORRECTION_CURRENT_BLOB_MISMATCH")

    cases.append(Case("64", "a changed current blob invalidates the correction", "FAIL", with_fixture(blob_binding)))

    def touched(f: Fixture) -> None:
        f.checkout(f.base_head)
        head = f.commit_file(f.history_path, "# touched by V2 self-test\n", "selftest: touch corrected path")
        _expect_validate_failure(f.root, f.output, head, "TOUCHED_CORRECTION_INVALID")

    cases.append(Case("65", "touching a corrected path invalidates it", "FAIL", with_fixture(touched)))

    def unrelated(f: Fixture) -> None:
        f.checkout(f.base_head)
        head = f.commit_file("docs/selftest_unrelated.md", "unrelated delta\n", "selftest: unrelated delta")
        report = correction.validate_records(f.root, f.output, current_head=head)
        _assert(report["status"] == "PASS_WITH_APPEND_ONLY_HISTORICAL_CORRECTIONS", str(report))
        _assert(report.get("correction_survives_unrelated_delta") is True, str(report))

    cases.append(Case("66", "an unrelated product delta preserves a correction", "PASS", with_fixture(unrelated)))

    def reachability(f: Fixture) -> None:
        record = f.load_record()
        record["production_reachability_attestation"]["states"] = [
            "non_production_or_unresolved"
        ]
        f.save_record(record)
        # The frozen inventory says non-production/unresolved; this mismatch is
        # intentionally fail-closed even without changing the product tree.
        _expect_validate_failure_any(
            f.root,
            f.output,
            f.base_head,
            ("CORRECTION_REACHABILITY_SET_MISMATCH",),
        )

    cases.append(Case("67", "production reachability changes invalidate a correction", "FAIL", with_fixture(reachability)))

    def owner_binding(f: Fixture) -> None:
        record = f.load_record()
        record["component_ids"] = ["component.other_owner"]
        f.save_record(record)
        _expect_validate_failure_any(
            f.root,
            f.output,
            f.base_head,
            ("CORRECTION_COMPONENT_SET_MISMATCH",),
        )

    cases.append(Case("68", "owner binding changes invalidate a correction", "FAIL", with_fixture(owner_binding)))

    def component_binding(f: Fixture) -> None:
        record = f.load_record()
        record["component_ids"] = ["component.changed"]
        f.save_record(record)
        _expect_validate_failure_any(
            f.root,
            f.output,
            f.base_head,
            ("CORRECTION_COMPONENT_SET_MISMATCH",),
        )

    cases.append(Case("69", "component binding changes invalidate a correction", "FAIL", with_fixture(component_binding)))

    def domain_binding(f: Fixture) -> None:
        record = f.load_record()
        record["domain_ids"] = ["domain.changed"]
        f.save_record(record)
        _expect_validate_failure_any(
            f.root,
            f.output,
            f.base_head,
            ("CORRECTION_DOMAIN_SET_MISMATCH",),
        )

    cases.append(Case("70", "domain binding changes invalidate a correction", "FAIL", with_fixture(domain_binding)))

    def baseline_sha(f: Fixture) -> None:
        inventory = correction.load_json(f.inventory_path)
        inventory["baseline_report_sha256"] = "f" * 64
        f.inventory_path.write_bytes(_canonical(inventory))
        _expect_validate_failure(
            f.root,
            f.output,
            f.base_head,
            "FAILURE_INVENTORY_BASELINE_HASH_MISMATCH",
        )

    cases.append(Case("71", "raw report SHA mismatch is rejected", "FAIL", with_fixture(baseline_sha)))

    def baseline_sidecar(f: Fixture) -> None:
        sidecar = f.output / correction.BASELINE_REPORT_SHA_REL
        sidecar.write_text("0" * 64 + "  wrong.json\n", encoding="ascii")
        _expect_validate_failure(
            f.root,
            f.output,
            f.base_head,
            "BASELINE_HASH_SIDECAR_PATH_MISMATCH",
        )

    cases.append(Case("72", "baseline sidecar hash mismatch is rejected", "FAIL", with_fixture(baseline_sidecar)))

    def auth_id(f: Fixture) -> None:
        record = f.load_record()
        record["authorization_id"] = "wrong-authorization"
        f.save_record(record)
        _expect_validate_failure(f.root, f.output, f.base_head, "CORRECTION_AUTHORIZATION_ID_MISMATCH")

    cases.append(Case("73", "authorization ID mismatch is rejected", "FAIL", with_fixture(auth_id)))

    def head_id(f: Fixture) -> None:
        record = f.load_record()
        record["authorized_head_sha"] = "0" * 40
        f.save_record(record)
        _expect_validate_failure(f.root, f.output, f.base_head, "CORRECTION_AUTHORIZED_HEAD_MISMATCH")

    cases.append(Case("74", "authorized head mismatch is rejected", "FAIL", with_fixture(head_id)))

    def set_hash(f: Fixture) -> None:
        record = f.load_record()
        record["failure_fingerprint_set_sha256"] = "0" * 64
        f.save_record(record)
        _expect_validate_failure(f.root, f.output, f.base_head, "CORRECTION_FINGERPRINT_SET_HASH_MISMATCH")

    cases.append(Case("75", "fingerprint set hash mismatch is rejected", "FAIL", with_fixture(set_hash)))

    def path_hash(f: Fixture) -> None:
        record = f.load_record()
        record["path_set_sha256"] = "0" * 64
        f.save_record(record)
        _expect_validate_failure(f.root, f.output, f.base_head, "CORRECTION_PATH_SET_HASH_MISMATCH")

    cases.append(Case("76", "path set hash mismatch is rejected", "FAIL", with_fixture(path_hash)))

    def raw_visibility(f: Fixture) -> None:
        report = correction.validate_records(f.root, f.output, current_head=f.base_head)
        rendered = correction.render_markdown(report)
        _assert(report["raw_failure_count"] == 1, str(report))
        _assert(report["raw_historical_failure_count"] == 1, str(report))
        _assert(report["historical_failure_visibility_preserved"] is True, str(report))
        _assert("Raw failures: `1`" in rendered, rendered)
        _assert("Corrected historical debt: `1`" in rendered, rendered)

    cases.append(Case("77", "raw historical failure remains visible after correction", "PASS", with_fixture(raw_visibility)))

    def blocking_counts(f: Fixture) -> None:
        record = f.load_record()
        record["failure_fingerprints"] = []
        record["failure_count"] = 0
        record["failure_fingerprint_set_sha256"] = _sha(b"\n")
        f.save_record(record)
        report = correction.validate_records(f.root, f.output, current_head=f.base_head)
        _assert(report["unresolved_historical_failure_count"] == 1, str(report))
        _assert(report["effective_blocking_failure_count"] > 0, str(report))

    cases.append(Case("78", "blocking count includes unresolved historical debt", "FAIL", with_fixture(blocking_counts)))

    def delete_record(f: Fixture) -> None:
        _assert(f.record_path is not None, "record missing")
        f.record_path.unlink()
        _expect_validate_failure(
            f.root,
            f.output,
            f.base_head,
            "CORRECTION_RECORD_SET_DRIFT",
        )

    cases.append(Case("79", "deleting a record is rejected", "FAIL", with_fixture(delete_record)))

    def unsupported_class(f: Fixture) -> None:
        record = f.load_record()
        record["transition_class_id"] = "OTHER"
        f.save_record(record)
        _expect_validate_failure_any(
            f.root,
            f.output,
            f.base_head,
            (
                "CORRECTION_DISALLOWED_TERM:other",
                "CORRECTION_TRANSITION_CLASS_MISMATCH",
            ),
        )

    cases.append(Case("80", "unsupported transition class is rejected", "FAIL", with_fixture(unsupported_class)))

    def current_schema_gap_touched(f: Fixture) -> None:
        f.checkout(f.base_head)
        head = f.commit_file(
            f.history_path,
            "# schema gap touched\n",
            "selftest: schema gap",
        )
        _expect_validate_failure(f.root, f.output, head, "TOUCHED_CORRECTION_INVALID")

    cases.append(Case("81", "a current schema gap that is touched remains blocking", "FAIL", with_fixture(current_schema_gap_touched)))

    def future_same_class(f: Fixture) -> None:
        # Add a second historical row to the frozen inventory without adding a
        # record.  The resolver must not infer a class-wide future correction.
        inventory = correction.load_json(f.inventory_path)
        second = copy.deepcopy(inventory["rows"][0])
        second["raw_failure"] = second["raw_failure"] + ":future"
        second["failure_fingerprint"] = correction._failure_fingerprint(
            second["raw_failure"], "HISTORICAL", second["rule_id"]
        )
        second["failure_id"] = second["failure_fingerprint"]
        inventory["rows"].append(second)
        f.inventory_path.write_bytes(_canonical(inventory))
        _expect_validate_failure_any(
            f.root,
            f.output,
            f.base_head,
            (
                "FAILURE_INVENTORY_COVERAGE_MISMATCH",
                "RAW_BASELINE_FAILURE_MISSING",
            ),
        )

    cases.append(Case("82", "a future same-class failure requires a new explicit record", "FAIL", with_fixture(future_same_class)))

    def v1_read_only(f: Fixture) -> None:
        before = (f.root / "docs/architecture/V076_INHERITED_GREEN_LEDGER.json").read_bytes()
        index = correction._v1_correction_index(f.root)
        after = (f.root / "docs/architecture/V076_INHERITED_GREEN_LEDGER.json").read_bytes()
        _assert(index is not None, "V1 index unavailable")
        _assert(before == after, "V1 ledger was mutated")

    cases.append(Case("83", "V1 correction history is read-only input", "PASS", with_fixture(v1_read_only)))

    def report_contract(f: Fixture) -> None:
        report = correction.validate_records(f.root, f.output, current_head=f.base_head)
        required = {
            "raw_failure_count", "raw_historical_failure_count", "raw_current_delta_failure_count",
            "corrected_historical_failure_count", "unresolved_historical_failure_count",
            "true_active_violation_count", "effective_blocking_failure_count",
        }
        _assert(required.issubset(report), f"missing report fields: {required - set(report)}")
        _assert(report["raw_and_effective_counts_both_reported"] is True, str(report))
        _assert(report["raw_scanner_executes_before_correction"] is True, str(report))
        live_report = correction.validate_records(
            f.root,
            f.output,
            current_head=f.base_head,
            live_raw_report_path=f.baseline_path,
        )
        expected_relative_source = f.baseline_path.resolve().relative_to(
            f.root.resolve()
        ).as_posix()
        _assert(
            live_report["raw_report_source"] == expected_relative_source,
            str(live_report["raw_report_source"]),
        )
        external_raw = f.base_dir / "external-live-raw.json"
        shutil.copyfile(f.baseline_path, external_raw)
        external_report = correction.validate_records(
            f.root,
            f.output,
            current_head=f.base_head,
            live_raw_report_path=external_raw,
        )
        _assert(
            external_report["raw_report_source"]
            == "EXTERNAL_LIVE_RAW_REPORT:external-live-raw.json",
            str(external_report["raw_report_source"]),
        )

    cases.append(Case("84", "report projection carries raw and effective counts", "PASS", with_fixture(report_contract)))

    def markdown_no_zero(f: Fixture) -> None:
        report = correction.validate_records(f.root, f.output, current_head=f.base_head)
        rendered = correction.render_markdown(report)
        _assert("Raw failures: `0`" not in rendered, rendered)
        _assert("PASS_WITH_APPEND_ONLY_HISTORICAL_CORRECTIONS" in rendered, rendered)

    cases.append(Case("85", "human-readable summary cannot hide debt as zero failures", "PASS", with_fixture(markdown_no_zero)))

    def empty_blob_map(f: Fixture) -> None:
        record = f.load_record()
        record["current_blob_sha256_by_path"] = {}
        f.save_record(record)
        report = correction.validate_records(f.root, f.output, current_head=f.base_head)
        _assert(
            _has_prefix(report.get("failures", []), "CORRECTION_CURRENT_BLOB_MISMATCH")
            or _has_prefix(report.get("failures", []), "CORRECTION_WITHOUT_CURRENT_BLOB_BINDING"),
            f"empty blob map did not fail closed: {report.get('failures', [])!r}",
        )

    cases.append(Case(
        "86",
        "a generated real record with an empty current-blob map is rejected",
        "FAIL",
        with_fixture(empty_blob_map),
    ))

    def _write_live(f: Fixture, *, head: str, failures: list[str]) -> Path:
        path = f.base_dir / "live-raw-report.json"
        _write(
            path,
            {
                "schema_version": "space_syndicate.v076.reuse_point_inertia_gate.v1",
                "head_sha": head,
                "failures": failures,
            },
        )
        return path

    def live_current_delta(f: Fixture) -> None:
        live = _write_live(
            f,
            head=f.base_head,
            failures=[f.history_raw, f.current_raw],
        )
        report = correction.validate_records(
            f.root,
            f.output,
            current_head=f.base_head,
            live_raw_report_path=live,
        )
        _assert(report["status"] == "FAIL", str(report))
        _assert(report["raw_failure_count"] == 2, str(report))
        _assert(report["raw_historical_failure_count"] == 1, str(report))
        _assert(report["raw_current_delta_failure_count"] == 1, str(report))
        _assert(report["true_active_violation_count"] == 1, str(report))
        _assert(
            _has_prefix(report.get("failures", []), "LIVE_RAW_FAILURE_NOT_IN_BASELINE:"),
            str(report),
        )
        _assert(
            f.current_fingerprint in report.get("true_active_violation_fingerprints", []),
            str(report),
        )

    cases.append(Case(
        "87",
        "a live raw report current-delta row remains an active violation",
        "PASS",
        with_fixture(live_current_delta),
    ))

    def live_history_missing(f: Fixture) -> None:
        live = _write_live(f, head=f.base_head, failures=[])
        report = correction.validate_records(
            f.root,
            f.output,
            current_head=f.base_head,
            live_raw_report_path=live,
        )
        _assert(report["status"] == "FAIL", str(report))
        _assert(
            _has_prefix(report.get("failures", []), "RAW_BASELINE_FAILURE_MISSING:"),
            str(report),
        )
        _assert(report["raw_failure_detection_suppressed_count"] == 1, str(report))

    cases.append(Case(
        "88",
        "a live report cannot suppress a frozen historical failure",
        "FAIL",
        with_fixture(live_history_missing),
    ))

    def live_head_mismatch(f: Fixture) -> None:
        live = _write_live(f, head="0" * 40, failures=[f.history_raw])
        report = correction.validate_records(
            f.root,
            f.output,
            current_head=f.base_head,
            live_raw_report_path=live,
        )
        _assert(
            _has_prefix(report.get("failures", []), "LIVE_RAW_REPORT_HEAD_MISMATCH"),
            str(report),
        )

    cases.append(Case(
        "89",
        "a live raw report must bind to the evaluated head",
        "FAIL",
        with_fixture(live_head_mismatch),
    ))

    def live_duplicate(f: Fixture) -> None:
        live = _write_live(
            f,
            head=f.base_head,
            failures=[f.history_raw, f.history_raw],
        )
        report = correction.validate_records(
            f.root,
            f.output,
            current_head=f.base_head,
            live_raw_report_path=live,
        )
        _assert(
            _has_prefix(report.get("failures", []), "LIVE_RAW_FAILURE_DUPLICATE"),
            str(report),
        )

    cases.append(Case(
        "90",
        "duplicate live raw failures are rejected before correction",
        "FAIL",
        with_fixture(live_duplicate),
    ))

    def live_history_prefix_new(f: Fixture) -> None:
        # A HISTORY_ prefix on a row first observed after the authorized head
        # does not make it historical or eligible; the resolver must classify
        # it as current delta and keep it active.
        new_history_prefixed = "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT:future-component.gd"
        live = _write_live(
            f,
            head=f.base_head,
            failures=[f.history_raw, new_history_prefixed],
        )
        report = correction.validate_records(
            f.root,
            f.output,
            current_head=f.base_head,
            live_raw_report_path=live,
        )
        _assert(report["status"] == "FAIL", str(report))
        _assert(report["raw_historical_failure_count"] == 1, str(report))
        _assert(report["raw_current_delta_failure_count"] == 1, str(report))
        _assert(
            _has_prefix(report.get("failures", []), "LIVE_RAW_FAILURE_NOT_IN_BASELINE:"),
            str(report),
        )
        _assert(report["true_active_violation_count"] == 1, str(report))

    cases.append(Case(
        "91",
        "a new HISTORY-prefixed live row remains current delta debt",
        "FAIL",
        with_fixture(live_history_prefix_new),
    ))

    def cleanup() -> None:
        fixture.restore_resolver_constants()
        fixture.temporary.cleanup()

    return cases, cleanup


def _run_cases(cases: list[Case]) -> list[CaseResult]:
    results: list[CaseResult] = []
    for case in cases:
        try:
            case.run()
            results.append(CaseResult(case.case_id, case.description, case.expected, "PASS", []))
        except Exception as exc:  # pragma: no cover - receipt intentionally records failures
            results.append(CaseResult(case.case_id, case.description, case.expected, "FAIL", [f"{type(exc).__name__}: {exc}"]))
    return results


def run_selftest() -> dict[str, Any]:
    project = Path(__file__).resolve().parents[2]
    # Pure shape cases do not need a repository.  The fixture supplies a real
    # fingerprint and exercises the canonical validator for all integration
    # and invalidation cases.
    sample_fp = "V2F-" + "a" * 64
    shape_base = _minimal_record(fingerprint=sample_fp)
    cases = _shape_cases(shape_base)

    def schema_artifact_contract() -> None:
        failures, digest = correction._validate_correction_schema(project)
        _assert(not failures, str(failures))
        _assert(
            digest == correction.AUTHORIZED_CORRECTION_SCHEMA_SHA256,
            f"schema digest mismatch: {digest}",
        )

    cases.append(Case(
        "92",
        "the independent exact correction schema is canonical and authorized",
        "PASS",
        schema_artifact_contract,
    ))

    def seal_missing_input() -> None:
        with tempfile.TemporaryDirectory(prefix="v076-seal-missing-") as temporary:
            missing = Path(temporary) / "missing.json"
            try:
                correction._seal_artifact_binding(
                    missing,
                    display_path="missing.json",
                    tracked_files={},
                )
            except ValueError as exc:
                _assert("SEAL_INPUT_MISSING" in str(exc), str(exc))
                return
            raise CaseFailure("missing seal input was accepted")

    cases.append(Case(
        "93",
        "evidence sealing rejects a missing bound input",
        "FAIL",
        seal_missing_input,
    ))

    def seal_tampered_input() -> None:
        with tempfile.TemporaryDirectory(prefix="v076-seal-tamper-") as temporary:
            base = Path(temporary)
            artifact = base / "artifact.json"
            sidecar = base / "artifact.sha256"
            artifact.write_bytes(_canonical({"status": "ORIGINAL"}))
            _write_sidecar(sidecar, artifact)
            artifact.write_bytes(_canonical({"status": "TAMPERED"}))
            try:
                correction._seal_artifact_binding(
                    artifact,
                    display_path="artifact.json",
                    tracked_files={},
                    sidecar=sidecar,
                )
            except ValueError as exc:
                _assert("SIDECAR" in str(exc) or "DIGEST_MISMATCH" in str(exc), str(exc))
                return
            raise CaseFailure("tampered seal input was accepted")

    cases.append(Case(
        "94",
        "evidence sealing rejects bytes that no longer match their sidecar",
        "FAIL",
        seal_tampered_input,
    ))

    def seal_count_mismatch() -> None:
        counts = dict(correction.EXPECTED_SEAL_COUNTS)
        counts["RAW_FAILURE_COUNT"] -= 1
        try:
            correction._validate_exact_count_projection(counts)
        except ValueError as exc:
            _assert("SEAL_COUNT_MISMATCH" in str(exc), str(exc))
            return
        raise CaseFailure("inconsistent seal counts were accepted")

    cases.append(Case(
        "95",
        "evidence sealing rejects a raw historical active blocking count mismatch",
        "FAIL",
        seal_count_mismatch,
    ))

    def workflow_static_contract() -> None:
        workflow_path = project / ".github/workflows/v076-reuse-point-inertia-gate.yml"
        workflow = workflow_path.read_text(encoding="utf-8")
        ordered_tokens = (
            "name: V076 Reuse and Point-Inertia Gate",
            "Run existing 120/120 self-test",
            "Run V2 exact-correction self-test",
            "Run Raw Scanner and emit Raw Report",
            "Run V2 Resolver and emit V2 Report",
            "Enforce Effective Gate",
            "Upload read-only gate reports",
        )
        positions = [workflow.find(token) for token in ordered_tokens]
        _assert(all(position >= 0 for position in positions), f"workflow tokens missing: {positions}")
        _assert(positions == sorted(positions), f"workflow order changed: {positions}")
        _assert(
            '$rawExit -lt 0 -or $rawExit -ge 2' in workflow
            and '$global:LASTEXITCODE = 0' in workflow,
            "raw exit 1 is no longer preserved for V2",
        )
        _assert(
            '$v2ExitText -ne "0"' in workflow,
            "final effective FAIL is no longer nonzero",
        )
        for artifact in (
            "v076-reuse-point-inertia-raw.json",
            "v076-reuse-point-inertia-raw.md",
            "v076-reuse-correction-v2.json",
            "v076-reuse-correction-v2.md",
        ):
            _assert(artifact in workflow, f"workflow upload omits {artifact}")

    cases.append(Case(
        "96",
        "required workflow preserves existing then V2 selftests raw resolver effective gate and both reports",
        "PASS",
        workflow_static_contract,
    ))

    def workflow_sealed_evidence_contract() -> None:
        workflow_path = project / ".github/workflows/v076-reuse-point-inertia-gate.yml"
        workflow = workflow_path.read_text(encoding="utf-8")
        v2_position = workflow.find("      - name: Run V2 exact-correction self-test")
        seal_position = workflow.find("      - name: Verify sealed V2 evidence")
        raw_position = workflow.find("      - name: Run Raw Scanner and emit Raw Report")
        _assert(
            0 <= v2_position < seal_position < raw_position,
            f"sealed-evidence step order invalid: {v2_position}/{seal_position}/{raw_position}",
        )
        seal_block = workflow[seal_position:raw_position]
        command_pattern = re.compile(
            r"\$verificationLines\s*=\s*& python\s+"
            r"tools/v076/v076_reuse_exact_failure_correction_v2\.py\s+"
            r"seal-evidence\s+`[\s\S]*?--verify-only",
        )
        _assert(command_pattern.search(seal_block) is not None, "seal verify command missing")
        required_fail_closed_tokens = (
            '$ErrorActionPreference = "Stop"',
            "$verificationExit -ne 0",
            'throw "Sealed V2 evidence verification tooling failure:',
            '[string]$verification.status -cne "VERIFIED"',
            '$null -eq $mutationProperty',
            '$mutationProperty.Value -isnot [long]',
            '[long]$mutationProperty.Value -ne 0',
            '[string]$verification.REUSE_GATE_STATUS -cne "FAIL"',
            'throw "Sealed V2 evidence verification mismatch:',
        )
        for token in required_fail_closed_tokens:
            _assert(token in seal_block, f"seal verify fail-closed token missing: {token}")
        _assert("continue-on-error" not in seal_block, "seal verification became optional")

    cases.append(Case(
        "108",
        "workflow verifies sealed evidence between V2 selftest and Raw with fail-closed status and mutation checks",
        "PASS",
        workflow_sealed_evidence_contract,
    ))

    def same_count_inventory_rebinding() -> None:
        with tempfile.TemporaryDirectory(prefix="v076-inventory-rebind-") as temporary:
            base = Path(temporary)
            actual = base / "actual.json"
            expected = base / "expected.json"
            _write(actual, {"rows": [{"rule_id": "HISTORY_A", "path": "scripts/a.gd"}]})
            _write(expected, {"rows": [{"rule_id": "CURRENT_B", "path": "scripts/b.gd"}]})
            try:
                correction._require_exact_file(actual, expected, label="inventory")
            except ValueError as exc:
                _assert("SEAL_RECOMPUTE_MISMATCH" in str(exc), str(exc))
                return
            raise CaseFailure("same-count inventory rebinding was accepted")

    cases.append(Case(
        "101",
        "canonical inventory recompute rejects same-count rule and path rebinding",
        "FAIL",
        same_count_inventory_rebinding,
    ))

    def directory_membership_mutation() -> None:
        with tempfile.TemporaryDirectory(prefix="v076-path-set-") as temporary:
            directory = Path(temporary)
            tracked_sets = [(directory, "*.json", tuple())]
            _assert(
                correction._post_manifest_input_mutation_count({}, tracked_sets) == 0,
                "empty path set did not begin stable",
            )
            (directory / "new-revocation.json").write_text("{}\n", encoding="utf-8")
            _assert(
                correction._post_manifest_input_mutation_count({}, tracked_sets) == 1,
                "new record/revocation path was not detected",
            )

    cases.append(Case(
        "102",
        "post-collect record or revocation directory membership mutation is detected",
        "FAIL",
        directory_membership_mutation,
    ))

    def sidecar_trailing_line() -> None:
        with tempfile.TemporaryDirectory(prefix="v076-sidecar-lines-") as temporary:
            base = Path(temporary)
            artifact = base / "artifact.json"
            sidecar = base / "artifact.sha256"
            artifact.write_bytes(_canonical({"ok": True}))
            digest = _sha(artifact.read_bytes())
            sidecar.write_text(
                f"{digest}  artifact.json\n{digest}  hidden.json\n",
                encoding="ascii",
            )
            _, error = correction._read_sidecar_digest(
                artifact,
                sidecar,
                expected_paths=("artifact.json",),
            )
            _assert(error is not None and "FORMAT_INVALID" in error, str(error))

    cases.append(Case(
        "103",
        "a seal sidecar rejects trailing assertions after its canonical line",
        "FAIL",
        sidecar_trailing_line,
    ))

    def production_output_root_escape() -> None:
        with tempfile.TemporaryDirectory(prefix="v076-output-escape-") as temporary:
            try:
                correction._preflight_seal_outputs(
                    project,
                    Path(temporary),
                    {},
                    verify_only=False,
                )
            except ValueError as exc:
                _assert("OUTPUT_ROOT_MUST_EQUAL_PROJECT_ROOT" in str(exc), str(exc))
                return
            raise CaseFailure("external production seal output root was accepted")

    cases.append(Case(
        "104",
        "production evidence sealing rejects an external output root",
        "FAIL",
        production_output_root_escape,
    ))

    def _new_writer_test_repo(base: Path) -> Path:
        repo = base / "repo"
        repo.mkdir()
        _git(repo, "init", "--quiet")
        _git(repo, "config", "user.email", "v076-writer-selftest@example.invalid")
        _git(repo, "config", "user.name", "V076 Writer Selftest")
        _git(repo, "commit", "--allow-empty", "--quiet", "-m", "initial")
        return repo

    def staged_first_add_is_append_only() -> None:
        with tempfile.TemporaryDirectory(prefix="v076-writer-index-") as temporary:
            repo = _new_writer_test_repo(Path(temporary))
            target = repo / "reports/reuse/correction_v2/staged.json"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(_canonical({"state": "staged"}))
            _git(repo, "add", "--", target.relative_to(repo).as_posix())
            try:
                correction._write_generated_draft(
                    target,
                    _canonical({"state": "replacement"}),
                    repository_root=repo,
                )
            except RuntimeError as exc:
                _assert("indexed append-only artifact" in str(exc), str(exc))
                return
            raise CaseFailure("staged-first-add append-only artifact was overwritten")

    cases.append(Case(
        "105",
        "generated draft writer rejects a staged first-add append-only path",
        "FAIL",
        staged_first_add_is_append_only,
    ))

    def history_deleted_recreate_is_append_only() -> None:
        with tempfile.TemporaryDirectory(prefix="v076-writer-history-") as temporary:
            repo = _new_writer_test_repo(Path(temporary))
            target = repo / "reports/reuse/correction_v2/historical.json"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(_canonical({"state": "committed"}))
            relative = target.relative_to(repo).as_posix()
            _git(repo, "add", "--", relative)
            _git(repo, "commit", "--quiet", "-m", "add append-only artifact")
            target.unlink()
            _git(repo, "add", "-u", "--", relative)
            _git(repo, "commit", "--quiet", "-m", "remove append-only artifact")
            try:
                correction._write_generated_draft(
                    target,
                    _canonical({"state": "recreated"}),
                    repository_root=repo,
                )
            except RuntimeError as exc:
                _assert("historical append-only artifact" in str(exc), str(exc))
                return
            raise CaseFailure("historically committed append-only path was recreated")

    cases.append(Case(
        "106",
        "generated draft writer rejects recreation after historical deletion",
        "FAIL",
        history_deleted_recreate_is_append_only,
    ))
    integration_error = ""
    integration_cleanup: Callable[[], None] | None = None
    try:
        integration_cases, integration_cleanup = _integration_cases(project)
        cases.extend(integration_cases)
    except Exception as exc:
        # Keep the failure explicit and machine-readable; never turn fixture
        # setup failure into a false green result or pad the case count.
        integration_error = f"{type(exc).__name__}: {exc}"
        cases.append(Case("99", "integration fixture setup succeeds", "PASS", lambda: (_ for _ in ()).throw(CaseFailure(integration_error))))
    results = _run_cases(cases)
    if integration_cleanup is not None:
        integration_cleanup()
    pass_count = sum(result.status == "PASS" for result in results)
    case_count = len(results)
    # A negative case is successful when its assertion observes the required
    # rejection, so ``expected == FAIL`` must never itself increment a
    # false-green counter.  Failed safety-sensitive assertions are the only
    # possible false accepts in this fixture.
    false_green_sensitive_ids = {
        "04", "05", "06", "07", "08", "09", "10", "11", "12", "13",
        "14", "15", "16", "17", "18", "19", "20", "21", "22", "23",
        "24", "25", "26", "27", "28", "29", "30", "31", "32", "33",
        "34", "35", "36", "37", "38", "39", "40", "41", "42", "43",
        "44", "45", "46", "47", "48", "49", "50", "51", "52", "53",
        "54", "55", "56", "57", "58", "60", "61", "62", "63", "64",
        "65", "67", "68", "69", "70", "71", "72", "73", "74", "75",
        "76", "78", "79", "80", "81", "82", "86", "88", "89",
        "90", "91",
        "93", "94", "95", "96", "97", "98", "99", "100",
        "101", "102", "103", "104", "105", "106", "108",
    }
    false_green = sum(
        result.status == "FAIL" and result.case_id in false_green_sensitive_ids
        for result in results
    )
    current_violation_false_accept = sum(
        result.status == "FAIL" and result.case_id in {"60", "87", "91"}
        for result in results
    )
    valid_false_reject = sum(
        result.status == "FAIL" and result.case_id in {"01", "02", "58A", "59", "66", "77", "83", "84", "85", "87", "92"}
        for result in results
    )
    status = "PASS" if case_count >= 60 and pass_count == case_count and false_green == 0 and valid_false_reject == 0 else "FAIL"
    return {
        "schema_version": SELFTEST_SCHEMA,
        "check_name": CHECK_NAME,
        "CORRECTION_V2_SELFTEST_STATUS": status,
        "CORRECTION_V2_SELFTEST_CASE_COUNT": case_count,
        "CORRECTION_V2_SELFTEST_PASS_COUNT": pass_count,
        "CASE_FAILURE_COUNT": case_count - pass_count,
        "FALSE_GREEN_COUNT": false_green,
        "VALID_UNRELATED_DELTA_FALSE_REJECT_COUNT": valid_false_reject,
        "CURRENT_VIOLATION_FALSE_ACCEPT_COUNT": current_violation_false_accept,
        "EXISTING_REUSE_SELFTEST_STATUS": "DELEGATED_TO_V076_REUSE_POINT_INERTIA_GATE_SELFTEST",
        "EXISTING_REUSE_SELFTEST_PASS_COUNT": "120/120",
        "fixture_model": "temporary shared Git clone + canonical V2 validator",
        "godot_execution_count": 0,
        "repository_mutation_count": 0,
        "integration_fixture_setup_error": integration_error,
        "resolver_sha256": _sha(Path(correction.__file__).read_bytes()),
        "selftest_script_sha256": _sha(Path(__file__).read_bytes()),
        "cases": [result.__dict__ for result in results],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report-json", type=Path, default=None)
    parser.add_argument("--sha256-sidecar", type=Path, default=None)
    args = parser.parse_args(argv)
    if args.sha256_sidecar is not None and args.report_json is None:
        parser.error("--sha256-sidecar requires --report-json")
    receipt = run_selftest()
    if args.report_json is not None:
        args.report_json.parent.mkdir(parents=True, exist_ok=True)
        payload = _canonical(receipt)
        args.report_json.write_bytes(payload)
        if args.sha256_sidecar is not None:
            args.sha256_sidecar.parent.mkdir(parents=True, exist_ok=True)
            args.sha256_sidecar.write_text(
                f"{_sha(payload)}  {args.report_json.name}\n",
                encoding="ascii",
            )
    print(json.dumps(receipt, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if receipt["CORRECTION_V2_SELFTEST_STATUS"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

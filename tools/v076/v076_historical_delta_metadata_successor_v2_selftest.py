#!/usr/bin/env python3
"""Focused self-test for the HDM successor v2 artifact contract."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    from . import v076_historical_delta_metadata_successor_v2 as primary
    from . import v076_historical_delta_metadata_successor_v2_builder as builder
    from . import v076_historical_delta_metadata_successor_v2_independent_audit as independent
except ImportError:  # pragma: no cover
    import v076_historical_delta_metadata_successor_v2 as primary
    import v076_historical_delta_metadata_successor_v2_builder as builder
    import v076_historical_delta_metadata_successor_v2_independent_audit as independent


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--manifest", type=Path, default=None)
    args = parser.parse_args(argv)
    root = args.project.resolve()
    manifest = args.manifest.resolve() if args.manifest else root / builder.SUCCESSOR_ROOT / "manifest.json"
    checks: list[tuple[str, bool]] = [
        ("selector exact-only", builder.SELECTOR_POLICY["match_mode"] == "EXACT_FAILURE_FINGERPRINTS_ONLY"),
        ("selector no wildcard", builder.SELECTOR_POLICY["wildcard_allowed"] is False),
        ("future auto-match disabled", builder.FUTURE_POLICY["automatic_match"] is False),
        ("new failure requires record", builder.FUTURE_POLICY["new_failure_requires_new_record"] is True),
        ("expected identity cardinality", builder.EXPECTED_TOTAL == 86),
        ("expected rebound cardinality", builder.EXPECTED_REBOUND == 52),
        ("expected preserved cardinality", builder.EXPECTED_PRESERVED == 34),
        ("predecessor is immutable head", builder.PREDECESSOR_HEAD == "d4720d34b5dd99541c20907cb5231b1a780d1cf7"),
    ]
    epoch_head = "196cf386bccf6ba93a66b2257fe95e990a0b5d78"
    epoch_root = builder.SUCCESSOR_ROOT + "epochs/" + epoch_head + "/"
    epoch_id = "V076-HDM-SUCCESSOR-V2-CHEAD-" + epoch_head.upper()
    checks.extend([
        ("legacy artifact identity byte-stable", builder.artifact_identity(builder.CURRENT_BINDING_HEAD) == (builder.SUCCESSOR_ROOT, "V076-HDM-SUCCESSOR-V2-20260830-CHEAD-38E3776")),
        ("explicit epoch artifact identity", builder.artifact_identity(epoch_head, epoch_root, epoch_id) == (epoch_root, epoch_id)),
    ])
    invalid_artifact_identities = [
        ("new binding cannot reuse old implicit identity", (epoch_head, None, None)),
        ("explicit root requires manifest id", (epoch_head, epoch_root, None)),
        ("explicit id requires repository root", (epoch_head, None, epoch_id)),
        ("legacy root cannot receive new epoch", (epoch_head, builder.SUCCESSOR_ROOT, epoch_id)),
        ("old manifest id cannot label new epoch", (epoch_head, epoch_root, builder.LEGACY_MANIFEST_ID)),
        ("other head root rejected", (epoch_head, builder.SUCCESSOR_ROOT + "epochs/" + builder.CURRENT_BINDING_HEAD + "/", epoch_id)),
        ("other head id rejected", (epoch_head, epoch_root, "V076-HDM-SUCCESSOR-V2-CHEAD-" + builder.CURRENT_BINDING_HEAD.upper())),
        ("parent traversal rejected", (epoch_head, epoch_root + "../", epoch_id)),
        ("absolute destination rejected", (epoch_head, "/" + epoch_root, epoch_id)),
        ("backslash destination rejected", (epoch_head, epoch_root.replace("/", "\\"), epoch_id)),
        ("wildcard destination rejected", (epoch_head, builder.SUCCESSOR_ROOT + "epochs/*/", epoch_id)),
        ("empty explicit identity rejected", (epoch_head, "", "")),
        ("invalid binding head rejected", ("HEAD", epoch_root, epoch_id)),
    ]
    for name, values in invalid_artifact_identities:
        try:
            builder.artifact_identity(*values)
        except ValueError:
            checks.append((name, True))
        else:
            checks.append((name, False))
    if manifest.is_file():
        document = builder.strict_json(manifest.read_bytes())
        checks.extend([
            ("manifest identity count", document.get("identity_count") == 86),
            ("manifest rebound count", document.get("rebound_count") == 52),
            ("manifest preserved count", document.get("preserved_count") == 34),
            ("manifest exact-only policy", document.get("selector_policy") == builder.SELECTOR_POLICY),
            ("manifest future policy", document.get("future_failure_policy") == builder.FUTURE_POLICY),
            ("manifest record count", document.get("record_count") == 4 and len(document.get("record_bindings", [])) == 4),
            ("manifest wildcard count", document.get("wildcard_count") == 0),
        ])
        primary_result = primary.validate_manifest(
            root, manifest, evaluated_head=builder.CURRENT_BINDING_HEAD
        )
        independent_result = independent.audit(root, manifest)
        checks.extend([
            ("primary validator pass", primary_result.get("status") == "PASS"),
            ("independent validator pass", independent_result.get("status") == "PASS"),
            (
                "primary independent projection digest parity",
                bool(primary_result.get("authority_projection_sha256"))
                and primary_result.get("authority_projection_sha256")
                == independent_result.get("authority_projection_sha256"),
            ),
        ])
    else:
        checks.append(("canonical manifest exists", False))
    failed = [name for name, ok in checks if not ok]
    result = {"status": "PASS" if not failed else "FAIL", "checks": len(checks) - len(failed), "check_count": len(checks), "failures": failed, "manifest": str(manifest)}
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

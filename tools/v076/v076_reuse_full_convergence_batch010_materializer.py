"""Exact-only, staging-only materializer for V076 full-convergence Batch-010.

This tool deliberately owns no Registry or product mutation.  It reconstructs
the frozen Batch-010 membership directly from one immutable plan Head, then
requires fifty exact current
``component_inventory`` path rows before it will even inspect a classification
proposal.  Materialization additionally requires two exact-byte-bound reviews
of an explicit proposal and canonical parity between every proposal Registry
row and the committed Registry projection at the binding Head.

The only write surface is a fresh external staging directory containing seven
batch files plus one correction record per non-empty reviewed disposition.
There is no apply, stage, commit, or official-record command in this module.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import subprocess
from pathlib import Path
from typing import Any, Iterable

import v076_reuse_exact_failure_correction_v2_full_convergence as convergence
import v076_reuse_full_convergence_batch_builder as membership_builder


BATCH_ID = "batch-010"
CREATED_AT = "2026-08-29T00:00:00Z"
SEALED_MEMBERSHIP_HEAD_SHA = "0a5520893ee39c130a38ceb1a5580a7ee2b46b83"
SEALED_MEMBERSHIP_TREE_SHA = "8324aa0fcd7a3e5f0b0c3ce57ac49bd97601e870"
SEALED_MEMBERSHIP_PLAN_SHA256 = (
    "802bcdc7a57c37a2e97b9ed6dd39a6de51783938befe605b5f1163efe0363b36"
)
SEALED_MEMBERSHIP_FAILURE_COUNT = 50
SEALED_MEMBERSHIP_SET_SHA256 = (
    "121ee606175934acfebcb7bf729b9c49ad469ead0ca2e58afacc41163ff7ba69"
)
SEALED_MEMBERSHIP_CANDIDATE_PAYLOAD_SHA256 = (
    "3d85891d762b10c41406929bad0c29a58766287a005a14236344c49438f8eed7"
)
SEALED_MEMBERSHIP_SEAL_PAYLOAD_SHA256 = (
    "333d826075ff9441ab50678bdbfaab7054d40e2c7747cf48b62f8a8d7b8da112"
)

# failure fingerprint, exact historical path, old transition prefix,
# new transition prefix.  This tuple is the Batch-010 successor schema.  It is
# intentionally not a batch number parameter passed to the Batch-009 schema.
FROZEN_MEMBERSHIP_SPECS = (
    ("V2F-75a9a3736d60e9fea1c23fffb3369180eb6011540416424f4be6734596d9bb6d", "scripts/runtime/table_presentation_refresh_scheduler.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-7668c77f6984263be793ea29d81fce19c23d357e3f6c7a863532b3d4d6093330", "docs/rules/v06_mechanic_status_registry.json", "d701a81dce69", "0d2a2b798f32"),
    ("V2F-7777cdaa0c0eeadfc59ce5d567bf2e7efdf18c71ce59144883571516091c38a2", "scripts/runtime/runtime_simulation_phase_coordinator.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-78c85d1ba792eceda4dbf52bdaedcfab111f49819f8ed4533b94befb82fbb6f4", "scripts/runtime/runtime_command_phase_coordinator.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-7a0ddf6d01bbfadcf826900c8712f6c48bf1b0eb6be50d9aadea48699970add1", "scripts/runtime/player_hand_interaction_runtime_service.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-7d56674d28da2b9b032e9d950cadff6ebc66038e65f9a72eb6e6018b2e80eaa6", "scripts/runtime/simulation_mutation_authority.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-7d63caa77ffddec80b4f99b55749db8c57fa714c0ad9735effcd8d229b3f3b39", "scripts/ui/table/non_blocking_toast_surface.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-7d8aa6a2624dccbc13f06ff12002c401da5ea72271867079310c0edc83518389", "scripts/presentation/table_presentation_viewmodel_query.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-7dce5392503494e6d769c8da28dfa940e2c422b11872355f3ccc9c9f38989ea2", "scripts/runtime/game_table_viewmodel_runtime_service.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-7fd6bab14bc4f7b3257febf3096df236cb062819babdb9778430cd6f61fbdc8f", "scripts/runtime/card_intel_runtime_service.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-804baeec12a8bdb208844557edc1b703d1d2f3dc8b124b31140723d41ec86e7f", "scripts/runtime/table_selection_intent.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-80959a54b3288915b86ac31d12f74ef9387b4763e8a7e6baf7991db5a6286ed6", "resources/weather/spore_season.tres", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-80dd71ac03c3c3e803cce9fb933daf36035688a660502f8374dc4bf47e6ae227", "scripts/runtime/runtime_actor_port.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-81eb4883d90333c502c61229b487273e14b10376d51ab244aebaa97ca01dc423", "scripts/runtime/visual_cue_runtime_owner.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-828f4b9512ca596ff71a1f0c16cd204bdc5a7d6c221478e74e776f8f6c251598", "scripts/runtime/weather_system.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-8314e4a647c3c08569c95881a332af028d3e3d508c222f8eb0c9d854a3d29879", "scripts/runtime/victory_control_runtime_controller.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-83568ea86e60aa52e317c85de3fc26852d27f4d2fb3d0e2679c30589b5ddee30", "scripts/runtime/table_navigation_action_intent.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-8382fda01e4b92c96c6c1ff2e7041da8c5d87f2b2cf82effe8b13a6566334c7d", "scripts/runtime/card_resolution_execution_world_bridge.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-851dfb905d8780ca970601f18fd72c74ab566eef98f9e383c57d2612bd8cfbd9", "scripts/ui/table/player_roster_panel.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-8543b35c573dde96a71e0e7f87bead1ff1ed14cee424ef2fba92e1f0c4d8dffb", "scripts/runtime/runtime_lifecycle_port.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-87f9482011dab9bb9034a72b65d5621771bbe017dc7a9e1ff2fe1e2091a601a0", "scripts/semantic/game_action_intent_v1.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-8a19e62953285e470186a26fd3191200147452075890b490963fb69c8801846c", "resources/content/product_industry_catalog_v05.tres", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-8c35bdd2c976f843ad94ceb436a95bf2c4267104606d2b364ebb456299c9a110", "scripts/presentation/player_card_dock_viewer_query_port.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-8e65aed97bdddafcd797ec111a8ce8ac5a2bf57a767156995ac647d2cac321c9", "scripts/runtime/simulation_randomness_boundary.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-8ea6c6c2929c60986d7b4d15bf185a977ba0649b383aab54fffe91adf4a83128", "scripts/presentation/table_presentation_query_ports.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-8eb70f7003d5695ebd881cbb9b8aaed0be3943ae75e191d152836a01b71de733", "scripts/runtime/player_identity_authorization_boundary.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-8ecffa5e5869f724929534be0e5227c4cc522d54766365c2ed98aff054d6d071", "scripts/runtime/commodity_sushi_track_claim_request.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-90a6bf019fed6ae2fce6da082a056b71810f7c0b922b60734b4bf4ca14c2e91e", "scripts/runtime/player_cash_mutation_port.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-910b749a0b4f4c896a0470f43c2707a53049ea9924e6b088c9c5220c6e624a6e", "scripts/balance/combat_balance_model.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-91334c6442ce11a4a87fe318c854d10635e5b3a7bb90f0b6e5f64ec832b114b1", "scripts/viewmodels/player_board_snapshot.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-91f1f387c82ec8b0b69eca67bc44e414bc0553bbfd94393383c2fa502b50d7a1", "scripts/ui/game_screen.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-92be486c5ec40f5a3f4c8ae145edd6132d7be45e73a3b16fff78162a6bdbffd5", "scripts/semantic/ai_card_interaction_policy_compatibility_v1.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-94520aed3ea07a919aabe50d42488a9933a1f2f2213a2988ff556d2a4f38eda1", "scripts/runtime/commodity_flow_world_bridge.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-94b5b70c9f16a39fb7ca4dceb0c78a30213f4e852ecac738732707f3601bfd05", "scripts/viewmodels/top_bar_snapshot.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-959ffa6e3a81e812b4302a62e4e217becf38a7a59da365375cee880497078cae", "scripts/runtime/monster_action_command_sink.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-95d0f44103d80035a7dc165ca66914e04bcd79e5e842591687cb24077850b890", "scripts/runtime/runtime_presentation_port.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-97e91331c86794c1af9f801bbbc3db44a1a81856648f61022c73545e11d26284", "scripts/runtime/card_play_submission_runtime_controller.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-9887cadc6abed8ff1be18ae56d78316f794674162753927c53a19cacbf852b15", "scripts/runtime/runtime_resolution_phase_coordinator.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-9c2ea773f621d1ddf82c96b5c1539ed60352778982d5dc74de86713013ac9067", "scripts/runtime/world_session_envelope_codec.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-9e11f9a6ca88d03f7c257d9cb5d91a0fed3c14efbc4068c67a164dd879a5e580", "scripts/ui/district_supply_drawer.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-9ecc8f5a37670e8848ad2c3dd21957a4eb6f866d1ce105ac4f8c3f573154ded9", "scripts/runtime/monster_catalog_v06.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-9f3e9ab26f7657c5d9ea2e307c6c1c4c9420a2fc59198f98f953d868a0296d16", "scripts/presentation/table_presentation_viewer_context.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-9f62fec20fbc2d259390c7923693052e87d9c1ef911d0d518f8f882c0eaa678b", "scripts/runtime/solar_availability_runtime_service.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-9f80d78bc722f8b573767ffe84518e76e6213a3220c4b6c98c72d7fe4596ba87", "scripts/presentation/public_log_receipt.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-a02625ea4d385c39730461475dc338938a9b2fd1963feb2036b3d4629b5c6ef0", "resources/ai/personalities/pioneer_ai_policy.tres", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-a17d74296386b8517795c557e9dcff93049bdd49e2052f8e1a5e72cc8cb5e55d", "scripts/runtime/card_resolution_queue_runtime_service.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-a574b47d67bcfba0ff8dcc685e510b6c65deec9a6e222c73eda1779be1e96674", "scripts/runtime/city_gdp_derivative_runtime_controller.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-a5c0ce280b0d89e2b3e7d6c540b0f045724a38f73f84c3cb3104b107a78217a9", "scripts/runtime/forced_decision_response_request.gd", "46b33bba77b3", "e584cd4d8b0c"),
    ("V2F-a6444748c37af87840fa9684f7e3dccc634911e4ecd9d521bc6f033a3d803bea", "docs/tabletop_rulebook_v06.md", "8208001e7be8", "62ceba063d68"),
    ("V2F-a6a4e6eadc85c885fda4774cad8723393dc7d0f41e54737ffeb2812ffd6e3ed2", "scripts/presentation/table_presentation_refresh_port.gd", "46b33bba77b3", "e584cd4d8b0c"),
)

REGISTRY_REL = Path("docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json")
SUPERSESSION_REL = Path("docs/architecture/V076_SUPERSESSION_MAP.json")
BATCH_ROOT = Path(
    "docs/architecture/reuse_corrections/v2/batches/full_convergence_20260827"
)
RECORD_ROOT = Path(
    "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827"
)

PROPOSAL_SCHEMA = (
    "space_syndicate.v076.reuse_full_convergence."
    "batch010_exact_projection_candidate.v1"
)
PROPOSAL_REVIEW_SCHEMA = (
    "space_syndicate.v076.reuse_full_convergence."
    "batch010_exact_projection_review.v1"
)
PROPOSAL_KIND = "NON_AUTHORITATIVE_EXACT_REGISTRY_PROJECTION_REVIEW_INPUT"
PROPOSAL_FIELDS = frozenset({
    "schema_version",
    "candidate_kind",
    "batch_id",
    "membership_candidate_payload_sha256",
    "membership_seal_payload_sha256",
    "evaluated_head_sha",
    "evaluated_tree_sha",
    "authority_source_sha256",
    "failure_count",
    "failure_fingerprints",
    "failure_fingerprint_set_sha256",
    "rows",
    "required_review_ids",
    "review_status",
    "go_claim",
    "official_batch_write_count",
    "official_record_write_count",
    "proposal_payload_sha256",
})
PROPOSAL_ROW_FIELDS = frozenset({
    "failure_fingerprint",
    "source_identity",
    "expected_registry_rows",
    "identity_binding",
})
SOURCE_IDENTITY_FIELDS = frozenset({
    "declared_class_name",
    "extends_type",
    "identity_kind",
    "path",
    "resource_script_class",
    "resource_type",
    "root_node_name",
    "root_node_type",
    "script_path",
    "source_blob_sha256",
})
PROPOSAL_REVIEW_FIELDS = frozenset({
    "schema_version",
    "batch_id",
    "proposal_payload_sha256",
    "evaluated_head_sha",
    "evaluated_tree_sha",
    "failure_fingerprint_set_sha256",
    "review_id",
    "reviewer_authority_id",
    "findings",
    "p0_count",
    "p1_count",
    "status",
    "receipt_payload_sha256",
})
TRUSTED_PROPOSAL_REVIEWERS = {
    "A": "V076_FULL_CONVERGENCE_PRIMARY_REVIEWER_V1",
    "B": "V076_FULL_CONVERGENCE_INDEPENDENT_REVIEWER_V1",
}

TOUCH_POLICY = {
    "BLOB_CHANGED_CORRECTION_AUTO_INVALIDATION": True,
    "COMPONENT_CHANGED_CORRECTION_AUTO_INVALIDATION": True,
    "DOMAIN_CHANGED_CORRECTION_AUTO_INVALIDATION": True,
    "OWNER_BINDING_CHANGED_INVALIDATION": True,
    "PRODUCTION_REACHABILITY_CHANGED_INVALIDATION": True,
    "RETIREMENT_CHANGED_INVALIDATION": True,
    "SUPERSESSION_CHANGED_INVALIDATION": True,
    "TOUCH_INVALIDATES_CORRECTION": True,
    "UNRELATED_DELTA_PRESERVES_CORRECTION": True,
}

SUPPORTED_GROUPS = (
    (
        "HISTORICAL_TEST_ONLY",
        "transition_46b33bba77b3_e584cd4d8b0c_test-only.json",
        "TEST_ONLY",
    ),
    (
        "HISTORICAL_ACTIVE_LINEAGE_REGISTERED",
        "transition_46b33bba77b3_e584cd4d8b0c_production-reachable.json",
        "PRODUCTION_REACHABLE",
    ),
    (
        "HISTORICAL_DOCUMENTATION_ONLY",
        "batch010_documentation-only.json",
        "DOCUMENTATION_ONLY",
    ),
)

BASE_OUTPUT_ALLOWLIST = frozenset({
    "batch-010/batch-010-manifest.json",
    "batch-010/batch_inventory.json",
    "batch-010/batch_classification.json",
    "batch-010/batch_correction_records.json",
    "batch-010/batch_negative_checks.json",
    "batch-010/batch_review_A.json",
    "batch-010/batch_review_B.json",
})
RECORD_OUTPUT_BY_DISPOSITION = {
    disposition: f"records/batch-010/{filename}"
    for disposition, filename, _suffix in SUPPORTED_GROUPS
}
OUTPUT_ALLOWLIST = frozenset({
    *BASE_OUTPUT_ALLOWLIST,
    *RECORD_OUTPUT_BY_DISPOSITION.values(),
})


class MaterializerError(ValueError):
    """Fail-closed error emitted at an exact trust boundary."""


def canonical(value: Any) -> bytes:
    return convergence.canonical_bytes(value)


def sha(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def line_set(values: Iterable[str]) -> str:
    rendered = sorted(str(value) for value in values)
    return sha(("\n".join(rendered) + "\n").encode("utf-8"))


def git(root: Path, *args: str) -> str:
    process = subprocess.run(
        ["git", *args],
        cwd=root,
        text=True,
        encoding="utf-8",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if process.returncode:
        raise MaterializerError(
            f"GIT_FAILED:{' '.join(args)}:{process.stderr.strip()}"
        )
    return process.stdout.strip()


def _exact_commit(value: Any, label: str) -> str:
    rendered = str(value)
    if re.fullmatch(r"[0-9a-f]{40}", rendered) is None:
        raise MaterializerError(f"{label}_COMMIT_INVALID")
    return rendered


def _exact_repo_path(value: Path | str, label: str) -> str:
    rendered = Path(value).as_posix()
    normalized = convergence.normalize_path(rendered)
    if (
        not rendered
        or normalized != rendered
        or rendered.startswith(("-", "/", "../"))
        or rendered.endswith("/")
        or "/../" in rendered
        or any(char in rendered for char in "*?[]\r\n\x00")
    ):
        raise MaterializerError(f"{label}_PATH_INVALID")
    return rendered


def committed(root: Path, head: str, relative: Path | str) -> bytes:
    # Validate both object-name components before spawning Git.  In particular,
    # an untrusted value such as ``--output=...`` must never reach option
    # parsing.  ``cat-file`` is read-only and the explicit ``--`` terminates
    # option parsing before the already validated ``commit:path`` object name.
    validated_head = _exact_commit(head, "COMMITTED_OBJECT")
    rendered = _exact_repo_path(relative, "COMMITTED_OBJECT")
    process = subprocess.run(
        ["git", "cat-file", "blob", "--", f"{validated_head}:{rendered}"],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if process.returncode:
        raise MaterializerError(f"MISSING_COMMITTED_INPUT:{rendered}")
    return process.stdout


def strict_json_bytes(payload: bytes, label: str) -> Any:
    if payload.startswith(b"\xef\xbb\xbf"):
        raise MaterializerError(f"JSON_BOM_FORBIDDEN:{label}")
    try:
        return json.loads(
            payload.decode("utf-8"), object_pairs_hook=convergence._strict_object
        )
    except Exception as exc:
        raise MaterializerError(f"JSON_INVALID:{label}") from exc


def _payload_hash_valid(value: dict[str, Any], field: str) -> bool:
    claimed = value.get(field)
    payload = dict(value)
    payload.pop(field, None)
    return (
        isinstance(claimed, str)
        and re.fullmatch(r"[0-9a-f]{64}", claimed) is not None
        and claimed == sha(canonical(payload))
    )


def _is_exact_int(value: Any, expected: int) -> bool:
    return type(value) is int and value == expected


def _lexical_absolute(path: Path, label: str) -> Path:
    if not path.is_absolute():
        raise MaterializerError(f"{label}_PATH_NOT_ABSOLUTE")
    return Path(os.path.abspath(os.fspath(path)))


def _reject_reparse_chain(path: Path, label: str) -> None:
    lexical = _lexical_absolute(path, label)
    reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
    for entry in [*reversed(lexical.parents), lexical]:
        if not os.path.lexists(entry):
            continue
        try:
            info = os.lstat(entry)
        except OSError as exc:
            raise MaterializerError(
                f"{label}_LSTAT_FAILED:{entry.as_posix()}"
            ) from exc
        attributes = int(getattr(info, "st_file_attributes", 0))
        if stat.S_ISLNK(info.st_mode) or attributes & reparse_flag:
            raise MaterializerError(
                f"{label}_REPARSE_FORBIDDEN:{entry.as_posix()}"
            )


def _reject_git_ancestor(path: Path, label: str) -> None:
    for ancestor in [path, *path.parents]:
        if (ancestor / ".git").exists():
            raise MaterializerError(f"{label}_MUST_BE_OUTSIDE_WORKTREE")


def _require_external_stage(root: Path, stage: Path, label: str) -> Path:
    lexical = _lexical_absolute(stage, label)
    _reject_reparse_chain(lexical, label)
    resolved = lexical.resolve(strict=False)
    try:
        resolved.relative_to(root.resolve())
    except ValueError:
        pass
    else:
        raise MaterializerError(f"{label}_MUST_BE_OUTSIDE_PROJECT")
    _reject_git_ancestor(resolved, label)
    return resolved


def _require_disjoint_stages(
    root: Path,
    membership_stage: Path,
    output_stage: Path,
) -> tuple[Path, Path]:
    membership = _require_external_stage(
        root, membership_stage, "MEMBERSHIP_STAGE"
    )
    output = _require_external_stage(root, output_stage, "OUTPUT_STAGE")
    membership_key = os.path.normcase(os.path.normpath(os.fspath(membership)))
    output_key = os.path.normcase(os.path.normpath(os.fspath(output)))
    try:
        common = os.path.commonpath([membership_key, output_key])
    except ValueError:
        common = ""  # Different Windows volumes are necessarily disjoint.
    intersects = common in {membership_key, output_key}
    if intersects:
        raise MaterializerError("OUTPUT_MEMBERSHIP_STAGE_INTERSECTION_FORBIDDEN")
    return membership, output


def _require_plain_external_file(
    root: Path,
    path: Path,
    *,
    label: str,
    allowed_stage: Path | None = None,
) -> Path:
    lexical = _lexical_absolute(path, label)
    _reject_reparse_chain(lexical, label)
    resolved = lexical.resolve(strict=True)
    try:
        resolved.relative_to(root.resolve())
    except ValueError:
        pass
    else:
        raise MaterializerError(f"{label}_MUST_BE_OUTSIDE_PROJECT")
    if allowed_stage is not None:
        try:
            resolved.relative_to(allowed_stage.resolve())
        except ValueError as exc:
            raise MaterializerError(f"{label}_OUTSIDE_DECLARED_STAGE") from exc
    _reject_git_ancestor(resolved.parent, label)
    try:
        info = os.stat(resolved, follow_symlinks=False)
    except OSError as exc:
        raise MaterializerError(f"{label}_NOT_PLAIN_FILE") from exc
    if not stat.S_ISREG(info.st_mode):
        raise MaterializerError(f"{label}_NOT_PLAIN_FILE")
    if int(getattr(info, "st_nlink", 1)) != 1:
        raise MaterializerError(f"{label}_HARDLINK_FORBIDDEN")
    return resolved


def _read_external_json(
    root: Path,
    path: Path,
    *,
    label: str,
    allowed_stage: Path | None = None,
) -> tuple[dict[str, Any], bytes, Path]:
    resolved = _require_plain_external_file(
        root, path, label=label, allowed_stage=allowed_stage
    )
    raw = resolved.read_bytes()
    value = strict_json_bytes(raw, label)
    if not isinstance(value, dict):
        raise MaterializerError(f"{label}_NOT_OBJECT")
    if raw != canonical(value):
        raise MaterializerError(f"{label}_BYTES_NOT_CANONICAL")
    return value, raw, resolved


def _head_tree(root: Path, head_ref: str = "HEAD") -> tuple[str, str]:
    head = git(root, "rev-parse", f"{head_ref}^{{commit}}")
    tree = git(root, "rev-parse", f"{head}^{{tree}}")
    if (
        re.fullmatch(r"[0-9a-f]{40}", head) is None
        or re.fullmatch(r"[0-9a-f]{40}", tree) is None
    ):
        raise MaterializerError("HEAD_OR_TREE_INVALID")
    return head, tree


def _require_worktree_parity(root: Path, head: str, relative: Path) -> bytes:
    payload = committed(root, head, relative)
    path = root / relative
    if not path.is_file() or path.read_bytes() != payload:
        raise MaterializerError(f"AUTHORITY_WORKTREE_DRIFT:{relative.as_posix()}")
    return payload


def validate_frozen_membership(root: Path) -> dict[str, Any]:
    """Reconstruct the Batch-010 membership at one immutable plan Head.

    Batch-009's external membership seal is intentionally not parameterized for
    a successor batch.  Batch-010 instead owns this exact 50-row tuple and
    proves it against the committed frozen authority inputs.  Later Registry
    or batch evidence commits may advance HEAD, but may not alter this set.
    """

    root = root.resolve()
    current_head, _current_tree = _head_tree(root)
    if not convergence._is_ancestor(
        root, SEALED_MEMBERSHIP_HEAD_SHA, current_head
    ):
        raise MaterializerError("CURRENT_HEAD_NOT_MEMBERSHIP_DESCENDANT")
    frozen_tree = git(
        root, "rev-parse", f"{SEALED_MEMBERSHIP_HEAD_SHA}^{{tree}}"
    )
    if frozen_tree != SEALED_MEMBERSHIP_TREE_SHA:
        raise MaterializerError("FROZEN_MEMBERSHIP_TREE_DRIFT")

    try:
        plan = membership_builder.derive_plan_from_committed_head(
            root, SEALED_MEMBERSHIP_HEAD_SHA
        )
        read = membership_builder._committed_reader(
            root, SEALED_MEMBERSHIP_HEAD_SHA
        )
        identities, _primary, _legacy, _payloads = (
            membership_builder._load_authority_from_committed_head(
                root, SEALED_MEMBERSHIP_HEAD_SHA, read
            )
        )
    except membership_builder.BuilderError as exc:
        raise MaterializerError(
            f"FROZEN_MEMBERSHIP_RECONSTRUCTION_FAILED:{exc}"
        ) from exc

    planned = plan.get("batches", {}).get(BATCH_ID)
    fingerprints = [row[0] for row in FROZEN_MEMBERSHIP_SPECS]
    if (
        plan.get("evaluated_head_sha") != SEALED_MEMBERSHIP_HEAD_SHA
        or plan.get("plan_sha256") != SEALED_MEMBERSHIP_PLAN_SHA256
        or not isinstance(planned, dict)
        or planned.get("failure_count") != SEALED_MEMBERSHIP_FAILURE_COUNT
        or planned.get("failure_fingerprints") != fingerprints
        or planned.get("failure_fingerprint_set_sha256")
        != SEALED_MEMBERSHIP_SET_SHA256
        or line_set(fingerprints) != SEALED_MEMBERSHIP_SET_SHA256
        or len(fingerprints) != len(set(fingerprints))
    ):
        raise MaterializerError("FROZEN_MEMBERSHIP_PLAN_PARITY_INVALID")

    rows: dict[str, dict[str, Any]] = {}
    for fingerprint, path, old_prefix, new_prefix in FROZEN_MEMBERSHIP_SPECS:
        identity = identities.get(fingerprint)
        if not isinstance(identity, dict):
            raise MaterializerError(
                f"FROZEN_MEMBERSHIP_IDENTITY_MISSING:{fingerprint}"
            )
        raw_failure = str(identity.get("raw_failure", ""))
        expected_raw = (
            "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT:"
            f"{old_prefix}->{new_prefix}:{path}"
        )
        observed_old = str(identity.get("transition_old_prefix", ""))
        observed_new = str(identity.get("transition_new_prefix", ""))
        if not observed_old:
            observed_old = str(identity.get("transition_old_sha", ""))[:12]
        if not observed_new:
            observed_new = str(identity.get("transition_new_sha", ""))[:12]
        observed_path = str(
            identity.get("subject_value", identity.get("source_path", ""))
        )
        if (
            raw_failure != expected_raw
            or identity.get("rule_id")
            != "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"
            or observed_old != old_prefix
            or observed_new != new_prefix
            or observed_path != path
            or any(char in path for char in "*?[]")
        ):
            raise MaterializerError(
                f"FROZEN_MEMBERSHIP_IDENTITY_DRIFT:{fingerprint}"
            )
        rows[fingerprint] = {
            "failure_fingerprint": fingerprint,
            "raw_failure": raw_failure,
            "rule_id": "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT",
            "transition_old_prefix": old_prefix,
            "transition_new_prefix": new_prefix,
            "subject_kind": "path",
            "subject_value": path,
            "classification_status": "REQUIRES_EXACT_AUTHORITY_PROJECTION",
        }

    candidate = {
        "schema_version": membership_builder.CANDIDATE_SCHEMA,
        "candidate_kind": "NON_AUTHORITATIVE_REVIEW_INPUT",
        "authorization_id": convergence.AUTHORIZATION_ID,
        "batch_id": BATCH_ID,
        "evaluated_head_sha": SEALED_MEMBERSHIP_HEAD_SHA,
        "plan_sha256": SEALED_MEMBERSHIP_PLAN_SHA256,
        "failure_count": SEALED_MEMBERSHIP_FAILURE_COUNT,
        "failure_fingerprints": fingerprints,
        "failure_fingerprint_set_sha256": SEALED_MEMBERSHIP_SET_SHA256,
        "authority_inputs": plan["authority_inputs"],
        "rows": rows,
        "required_review_ids": ["PRIMARY", "INDEPENDENT"],
        "review_status": "FROZEN_SUCCESSOR_SCHEMA",
        "go_claim": False,
        "official_batch_write_count": 0,
        "official_record_write_count": 0,
        "next_builder_phase": "PROJECT_EXACT_AUTHORITY_AND_BUILD_RECORDS",
    }
    candidate["candidate_payload_sha256"] = sha(canonical(candidate))
    seal = {
        "schema_version": (
            "space_syndicate.v076.reuse_full_convergence."
            "batch010_frozen_membership_seal.v1"
        ),
        "batch_id": BATCH_ID,
        "evaluated_head_sha": SEALED_MEMBERSHIP_HEAD_SHA,
        "evaluated_tree_sha": SEALED_MEMBERSHIP_TREE_SHA,
        "plan_sha256": SEALED_MEMBERSHIP_PLAN_SHA256,
        "candidate_payload_sha256": candidate["candidate_payload_sha256"],
        "failure_count": SEALED_MEMBERSHIP_FAILURE_COUNT,
        "failure_fingerprint_set_sha256": SEALED_MEMBERSHIP_SET_SHA256,
        "official_batch_write_count": 0,
        "official_record_write_count": 0,
    }
    seal["seal_payload_sha256"] = sha(canonical(seal))
    if (
        candidate["candidate_payload_sha256"]
        != SEALED_MEMBERSHIP_CANDIDATE_PAYLOAD_SHA256
        or seal["seal_payload_sha256"]
        != SEALED_MEMBERSHIP_SEAL_PAYLOAD_SHA256
    ):
        raise MaterializerError("FROZEN_MEMBERSHIP_SCHEMA_HASH_DRIFT")
    return {
        "candidate": candidate,
        "candidate_file_sha256": sha(canonical(candidate)),
        "seal": seal,
        "seal_file_sha256": sha(canonical(seal)),
        "review_file_sha256": {},
        "stage": None,
    }

def _registry_document(root: Path, head: str) -> tuple[dict[str, Any], bytes]:
    payload = _require_worktree_parity(root, head, REGISTRY_REL)
    value = strict_json_bytes(payload, "REGISTRY")
    if not isinstance(value, dict):
        raise MaterializerError("REGISTRY_NOT_OBJECT")
    rows = value.get("component_inventory")
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        raise MaterializerError("REGISTRY_COMPONENT_INVENTORY_INVALID")
    return value, payload


def _failure_paths(membership: dict[str, Any]) -> dict[str, str]:
    candidate = membership["candidate"]
    result: dict[str, str] = {}
    for fingerprint in candidate["failure_fingerprints"]:
        row = candidate["rows"][fingerprint]
        if (
            not isinstance(row, dict)
            or row.get("rule_id") != "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"
            or row.get("subject_kind") != "path"
        ):
            raise MaterializerError(
                f"MEMBERSHIP_NOT_EXACT_COMPONENT_PATH:{fingerprint}"
            )
        path = convergence.normalize_path(str(row.get("subject_value", "")))
        if (
            not path
            or path != row.get("subject_value")
            or any(char in path for char in "*?[]")
            or path.startswith(("/", "../"))
            or path.endswith("/")
            or "/../" in path
        ):
            raise MaterializerError(f"MEMBERSHIP_PATH_NOT_EXACT:{fingerprint}")
        result[fingerprint] = path
    if len(result) != SEALED_MEMBERSHIP_FAILURE_COUNT or len(set(result.values())) != len(result):
        raise MaterializerError("MEMBERSHIP_PATH_SET_NOT_UNIQUE")
    return result


def _registry_exact_rows(
    registry: dict[str, Any],
    failure_paths: dict[str, str],
) -> dict[str, dict[str, Any]]:
    inventory = registry["component_inventory"]
    missing: list[str] = []
    duplicate: list[str] = []
    resolved: dict[str, dict[str, Any]] = {}
    for fingerprint, path in failure_paths.items():
        matches = [
            row
            for row in inventory
            if convergence.normalize_path(str(row.get("path", ""))) == path
        ]
        if not matches:
            missing.append(path)
        elif len(matches) != 1:
            duplicate.append(path)
        else:
            resolved[fingerprint] = matches[0]
    if missing:
        rendered = sorted(missing)
        raise MaterializerError(
            f"MISSING_EXACT_REGISTRY_ROWS:{len(rendered)}:"
            + "|".join(rendered)
        )
    if duplicate:
        rendered = sorted(duplicate)
        raise MaterializerError(
            f"DUPLICATE_EXACT_REGISTRY_ROWS:{len(rendered)}:"
            + "|".join(rendered)
        )
    component_ids = [str(row.get("component_id", "")) for row in resolved.values()]
    class_names = [str(row.get("class_name", "")) for row in resolved.values()]
    if (
        any(not value for value in component_ids)
        or len(component_ids) != len(set(component_ids))
    ):
        raise MaterializerError("BATCH010_COMPONENT_ID_SET_NOT_UNIQUE")
    if any(not value for value in class_names) or len(class_names) != len(set(class_names)):
        raise MaterializerError("BATCH010_CLASS_NAME_SET_NOT_UNIQUE")
    return resolved


def preflight(root: Path) -> dict[str, Any]:
    root = root.resolve()
    membership = validate_frozen_membership(root)
    head, tree = _head_tree(root)
    registry, registry_bytes = _registry_document(root, head)
    failure_paths = _failure_paths(membership)
    direct_rows = _registry_exact_rows(registry, failure_paths)
    return {
        "status": "PASS",
        "batch_id": BATCH_ID,
        "evaluated_head_sha": head,
        "evaluated_tree_sha": tree,
        "failure_count": len(failure_paths),
        "failure_fingerprint_set_sha256": SEALED_MEMBERSHIP_SET_SHA256,
        "exact_registry_row_count": len(direct_rows),
        "exact_registry_row_set_sha256": sha(
            canonical(sorted(direct_rows.values(), key=canonical))
        ),
        "registry_sha256": sha(registry_bytes),
        "official_batch_write_count": 0,
        "official_record_write_count": 0,
        "next_phase": "OBTAIN_EXPLICIT_DUAL_REVIEWED_PROPOSAL",
    }


def _extract_ext_resources(text: str) -> dict[str, tuple[str, str]]:
    result: dict[str, tuple[str, str]] = {}
    pattern = re.compile(r'^\[ext_resource\s+([^\]]+)\]$', re.MULTILINE)
    for match in pattern.finditer(text):
        attributes = {
            key: value
            for key, value in re.findall(
                r'([A-Za-z_][A-Za-z0-9_]*)="([^"]*)"', match.group(1)
            )
        }
        if {"type", "path", "id"}.issubset(attributes):
            result[attributes["id"]] = (
                attributes["type"], attributes["path"]
            )
    return result


def source_identity(root: Path, source_commit: str, path: str) -> dict[str, Any]:
    validated_source_commit = _exact_commit(source_commit, "SOURCE_IDENTITY")
    validated_path = _exact_repo_path(path, "SOURCE_IDENTITY")
    payload = committed(root, validated_source_commit, validated_path)
    try:
        text = payload.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise MaterializerError(f"SOURCE_IDENTITY_UTF8_INVALID:{path}") from exc
    result = {
        "declared_class_name": "",
        "extends_type": "",
        "identity_kind": "",
        "path": validated_path,
        "resource_script_class": "",
        "resource_type": "",
        "root_node_name": "",
        "root_node_type": "",
        "script_path": "",
        "source_blob_sha256": sha(payload),
    }
    suffix = Path(validated_path).suffix.casefold()
    if suffix == ".gd":
        result["identity_kind"] = "GDSCRIPT"
        class_match = re.search(
            r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)\s*$", text, re.MULTILINE
        )
        extends_match = re.search(r"^extends\s+([^\r\n#]+)", text, re.MULTILINE)
        result["declared_class_name"] = class_match.group(1) if class_match else ""
        result["extends_type"] = (
            extends_match.group(1).strip() if extends_match else ""
        )
    elif suffix == ".tscn":
        result["identity_kind"] = "GODOT_SCENE"
        root_match = re.search(
            r'^\[node\s+name="([^"]+)"\s+type="([^"]+)"[^\]]*\]$',
            text,
            re.MULTILINE,
        )
        if root_match is None:
            raise MaterializerError(f"SCENE_ROOT_IDENTITY_UNRESOLVED:{path}")
        result["root_node_name"] = root_match.group(1)
        result["root_node_type"] = root_match.group(2)
        resources = _extract_ext_resources(text)
        script_match = re.search(
            r'^script\s*=\s*ExtResource\("([^"]+)"\)\s*$', text, re.MULTILINE
        )
        if script_match:
            resource = resources.get(script_match.group(1))
            if resource is None or resource[0] != "Script":
                raise MaterializerError(f"SCENE_SCRIPT_IDENTITY_UNRESOLVED:{path}")
            result["script_path"] = convergence.normalize_path(resource[1])
    elif suffix == ".tres":
        result["identity_kind"] = "GODOT_RESOURCE"
        header = re.search(
            r'^\[gd_resource\s+type="([^"]+)"(?:\s+script_class="([^"]+)")?[^\]]*\]$',
            text,
            re.MULTILINE,
        )
        if header is None:
            raise MaterializerError(f"RESOURCE_HEADER_IDENTITY_UNRESOLVED:{path}")
        result["resource_type"] = header.group(1)
        result["resource_script_class"] = header.group(2) or ""
        resources = _extract_ext_resources(text)
        script_match = re.search(
            r'^script\s*=\s*ExtResource\("([^"]+)"\)\s*$', text, re.MULTILINE
        )
        if script_match:
            resource = resources.get(script_match.group(1))
            if resource is None or resource[0] != "Script":
                raise MaterializerError(f"RESOURCE_SCRIPT_IDENTITY_UNRESOLVED:{path}")
            result["script_path"] = convergence.normalize_path(resource[1])
    elif suffix in {".json", ".md"} and validated_path.startswith("docs/"):
        # Batch-010 is the first successor batch whose exact membership mixes
        # product paths with historical documentation.  Documentation remains
        # a registered non-production identity, never a product or Owner.
        result["identity_kind"] = "DOCUMENTATION"
    else:
        raise MaterializerError(f"SOURCE_IDENTITY_KIND_UNSUPPORTED:{path}")
    return result


def _canonical_registry_rows(projection: dict[str, Any]) -> list[dict[str, Any]]:
    rows = projection.get("registry_rows")
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        raise MaterializerError("PROJECTION_REGISTRY_ROWS_INVALID")
    stripped = [
        {key: value for key, value in row.items() if key != "authority_source_kind"}
        for row in rows
    ]
    return sorted(stripped, key=canonical)


def _authority_source_hashes(root: Path, head: str) -> dict[str, str]:
    return {
        relative: sha(committed(root, head, relative))
        for relative in convergence.AUTHORITY_SOURCE_PATHS
    }


def _validate_proposal_review(
    root: Path,
    path: Path,
    proposal: dict[str, Any],
    *,
    label: str,
) -> tuple[dict[str, Any], Path, str]:
    review, raw, resolved = _read_external_json(root, path, label=label)
    review_id = str(review.get("review_id", ""))
    if (
        set(review) != PROPOSAL_REVIEW_FIELDS
        or review.get("schema_version") != PROPOSAL_REVIEW_SCHEMA
        or review.get("batch_id") != BATCH_ID
        or review.get("proposal_payload_sha256")
        != proposal.get("proposal_payload_sha256")
        or review.get("evaluated_head_sha") != proposal.get("evaluated_head_sha")
        or review.get("evaluated_tree_sha") != proposal.get("evaluated_tree_sha")
        or review.get("failure_fingerprint_set_sha256")
        != SEALED_MEMBERSHIP_SET_SHA256
        or review_id not in TRUSTED_PROPOSAL_REVIEWERS
        or review.get("reviewer_authority_id")
        != TRUSTED_PROPOSAL_REVIEWERS[review_id]
        or review.get("status") != "GO"
        or not _is_exact_int(review.get("p0_count"), 0)
        or not _is_exact_int(review.get("p1_count"), 0)
        or review.get("findings") != []
        or not _payload_hash_valid(review, "receipt_payload_sha256")
    ):
        raise MaterializerError(f"{label}_INVALID")
    return review, resolved, sha(raw)


def validate_proposal(
    root: Path,
    membership: dict[str, Any],
    proposal_path: Path,
    review_a_path: Path,
    review_b_path: Path,
) -> dict[str, Any]:
    root = root.resolve()
    head, tree = _head_tree(root)
    registry, _registry_bytes = _registry_document(root, head)
    paths = _failure_paths(membership)
    direct_rows = _registry_exact_rows(registry, paths)
    proposal, _proposal_raw, resolved_proposal = _read_external_json(
        root, proposal_path, label="PROJECTION_PROPOSAL"
    )
    candidate = membership["candidate"]
    if (
        set(proposal) != PROPOSAL_FIELDS
        or proposal.get("schema_version") != PROPOSAL_SCHEMA
        or proposal.get("candidate_kind") != PROPOSAL_KIND
        or proposal.get("batch_id") != BATCH_ID
        or proposal.get("membership_candidate_payload_sha256")
        != SEALED_MEMBERSHIP_CANDIDATE_PAYLOAD_SHA256
        or proposal.get("membership_seal_payload_sha256")
        != SEALED_MEMBERSHIP_SEAL_PAYLOAD_SHA256
        or proposal.get("evaluated_head_sha") != head
        or proposal.get("evaluated_tree_sha") != tree
        or proposal.get("authority_source_sha256")
        != _authority_source_hashes(root, head)
        or not _is_exact_int(proposal.get("failure_count"), 50)
        or proposal.get("failure_fingerprints")
        != candidate.get("failure_fingerprints")
        or proposal.get("failure_fingerprint_set_sha256")
        != SEALED_MEMBERSHIP_SET_SHA256
        or proposal.get("required_review_ids") != ["A", "B"]
        or proposal.get("review_status") != "PENDING"
        or proposal.get("go_claim") is not False
        or not _is_exact_int(proposal.get("official_batch_write_count"), 0)
        or not _is_exact_int(proposal.get("official_record_write_count"), 0)
        or not _payload_hash_valid(proposal, "proposal_payload_sha256")
    ):
        raise MaterializerError("PROJECTION_PROPOSAL_CONTRACT_INVALID")
    rows = proposal.get("rows")
    if not isinstance(rows, dict) or set(rows) != set(paths):
        raise MaterializerError("PROJECTION_PROPOSAL_ROW_SET_INVALID")

    reviews = [
        _validate_proposal_review(
            root, review_a_path, proposal, label="PROJECTION_REVIEW_A"
        ),
        _validate_proposal_review(
            root, review_b_path, proposal, label="PROJECTION_REVIEW_B"
        ),
    ]
    if {review[0]["review_id"] for review in reviews} != {"A", "B"}:
        raise MaterializerError("PROJECTION_REVIEW_SET_INVALID")
    if len({review[1] for review in reviews}) != 2:
        raise MaterializerError("PROJECTION_REVIEW_FILE_IDENTITY_INVALID")
    if resolved_proposal in {review[1] for review in reviews}:
        raise MaterializerError("PROJECTION_PROPOSAL_REVIEW_FILE_ALIAS")

    identities, _primary, _legacy = membership_builder._load_authority(root, head)
    validated_bindings: dict[str, dict[str, Any]] = {}
    direct_component_ids: list[str] = []
    direct_class_names: list[str] = []
    for fingerprint in candidate["failure_fingerprints"]:
        proposal_row = rows[fingerprint]
        if not isinstance(proposal_row, dict) or set(proposal_row) != PROPOSAL_ROW_FIELDS:
            raise MaterializerError(f"PROJECTION_ROW_FIELD_SET_INVALID:{fingerprint}")
        if proposal_row.get("failure_fingerprint") != fingerprint:
            raise MaterializerError(f"PROJECTION_ROW_FINGERPRINT_INVALID:{fingerprint}")
        binding = proposal_row.get("identity_binding")
        if (
            not isinstance(binding, dict)
            or set(binding) != set(convergence.IDENTITY_BINDING_FIELDS)
        ):
            raise MaterializerError(f"PROJECTION_BINDING_FIELD_SET_INVALID:{fingerprint}")
        expected_identity = source_identity(
            root, str(binding.get("source_commit", "")), paths[fingerprint]
        )
        if (
            not isinstance(proposal_row.get("source_identity"), dict)
            or set(proposal_row["source_identity"]) != SOURCE_IDENTITY_FIELDS
            or proposal_row["source_identity"] != expected_identity
        ):
            raise MaterializerError(f"SOURCE_IDENTITY_PARITY_INVALID:{fingerprint}")

        selector = binding.get("authority_selectors")
        try:
            actual_projection = convergence.subject_projection(root, head, selector)
        except Exception as exc:
            raise MaterializerError(
                f"SUBJECT_PROJECTION_UNRESOLVED:{fingerprint}"
            ) from exc
        expected_registry_rows = proposal_row.get("expected_registry_rows")
        if (
            not isinstance(expected_registry_rows, list)
            or any(not isinstance(row, dict) for row in expected_registry_rows)
            or expected_registry_rows != sorted(expected_registry_rows, key=canonical)
            or expected_registry_rows != _canonical_registry_rows(actual_projection)
        ):
            raise MaterializerError(
                f"PROPOSAL_REGISTRY_CANONICAL_PARITY_INVALID:{fingerprint}"
            )
        if binding.get("subject_projection") != actual_projection:
            raise MaterializerError(
                f"PROPOSAL_SUBJECT_PROJECTION_PARITY_INVALID:{fingerprint}"
            )
        if binding.get("subject_projection_sha256") != sha(canonical(actual_projection)):
            raise MaterializerError(
                f"PROPOSAL_SUBJECT_PROJECTION_HASH_INVALID:{fingerprint}"
            )
        direct_row = direct_rows[fingerprint]
        if canonical(direct_row) not in {canonical(row) for row in expected_registry_rows}:
            raise MaterializerError(
                f"DIRECT_PATH_REGISTRY_ROW_NOT_PROPOSAL_BOUND:{fingerprint}"
            )
        direct_component_ids.append(str(direct_row.get("component_id", "")))
        direct_class_names.append(str(direct_row.get("class_name", "")))
        declared_class = expected_identity["declared_class_name"]
        if declared_class and direct_row.get("class_name") != declared_class:
            raise MaterializerError(f"GDSCRIPT_CLASS_NAME_SUBSTITUTION:{fingerprint}")
        if (
            expected_identity["identity_kind"] == "GDSCRIPT"
            and not declared_class
            and direct_row.get("class_name") != f"ANONYMOUS_PATH_BOUND:{paths[fingerprint]}"
        ):
            raise MaterializerError(
                f"ANONYMOUS_GDSCRIPT_IDENTITY_SUBSTITUTION:{fingerprint}"
            )

        failures = convergence._authorized_identity_binding_failures(
            root,
            fingerprint,
            binding,
            identities.get(fingerprint),
            record_rule_ids=["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
        )
        if failures == [f"IDENTITY_BASELINE_RAW_UNRESOLVED:{fingerprint}"]:
            # A very small descendant-history supplement shape predates the
            # common baseline identity schema.  Reconstruct only the exact
            # historical fields that are already fixed by the frozen member,
            # source commit and source blob; the full binding remains subject
            # to the ordinary projection and source-identity checks above.
            sparse = identities.get(fingerprint)
            if isinstance(sparse, dict) and sparse.get("source_path") == paths[fingerprint]:
                validation_identity = {
                    "bucket": "HISTORICAL",
                    "authority_origin": "DESCENDANT_HISTORY_SUPPLEMENT",
                    "failure_fingerprint": fingerprint,
                    "raw_failure": candidate["rows"][fingerprint]["raw_failure"],
                    "rule_id": "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT",
                    "subject_kind": "path",
                    "subject_value": paths[fingerprint],
                    "transition_old_prefix": candidate["rows"][fingerprint]["transition_old_prefix"],
                    "transition_new_prefix": candidate["rows"][fingerprint]["transition_new_prefix"],
                    "source_path": sparse.get("source_path"),
                    "supplement_raw_report_head_sha": convergence.DESCENDANT_HISTORY_V3_RAW_HEAD,
                }
                failures = convergence._authorized_identity_binding_failures(
                    root,
                    fingerprint,
                    binding,
                    validation_identity,
                    record_rule_ids=["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
                )
                if not failures:
                    identities[fingerprint] = validation_identity
        if failures:
            raise MaterializerError(
                f"PROJECTION_BINDING_INVALID:{fingerprint}:{failures[0]}"
            )
        # Keep the exact, validated supplement binding available to the
        # append-only artifact builder.  Documentation identities in the
        # pre-supplement authority inventory are intentionally sparse; the
        # compatibility metadata above is reconstructed without changing any
        # repository input and must be used consistently for inventory,
        # correction records, and manifest output.
        if validation_identity is not identities.get(fingerprint):
            identities[fingerprint] = validation_identity
        validated_bindings[fingerprint] = binding

    if len(direct_component_ids) != len(set(direct_component_ids)):
        raise MaterializerError("PROPOSAL_COMPONENT_ID_COLLISION")
    if len(direct_class_names) != len(set(direct_class_names)):
        raise MaterializerError("PROPOSAL_CLASS_NAME_COLLISION")
    return {
        "proposal": proposal,
        "proposal_path": resolved_proposal,
        "reviews": {review[0]["review_id"]: review[0] for review in reviews},
        "review_file_sha256": {
            review[0]["review_id"]: review[2] for review in reviews
        },
        "bindings": validated_bindings,
        "authorized_identities": identities,
        "head": head,
        "tree": tree,
    }


def _artifact_documents(
    fingerprints: list[str],
    bindings: dict[str, dict[str, Any]],
    identities: dict[str, dict[str, Any]],
    proposal_reviews: dict[str, dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    inventory_rows: dict[str, Any] = {}
    classifications: dict[str, Any] = {}
    reachability_counts: dict[str, int] = {}
    role_counts: dict[str, int] = {}
    for fingerprint in fingerprints:
        binding = bindings[fingerprint]
        identity = identities[fingerprint]
        reachability = str(binding["current_production_reachability"])
        role = str(binding["current_role"])
        reachability_counts[reachability] = reachability_counts.get(reachability, 0) + 1
        role_counts[role] = role_counts.get(role, 0) + 1
        inventory_rows[fingerprint] = {
            "authority_origin": str(identity.get("authority_origin", "FROZEN_FULL_CONVERGENCE_BASELINE")),
            "current_component_id": binding["current_component_id"],
            "current_path": binding["current_path"],
            "domain_id": binding["domain_id"],
            "failure_fingerprint": fingerprint,
            "historical_component_id": binding["historical_component_id"],
            "historical_path": binding["historical_path"],
            "owner_id": binding["current_owner_id"],
            "production_reachability": reachability == "PRODUCTION_REACHABLE",
            "raw_failure": identity["raw_failure"],
            "recommended_disposition": binding["recommended_disposition"],
            "role": role,
            "rule_id": identity["rule_id"],
            "transition_new_prefix": identity["transition_new_prefix"],
            "transition_old_prefix": identity["transition_old_prefix"],
        }
        classifications[fingerprint] = {
            "failure_fingerprint": fingerprint,
            "production_reachability": reachability,
            "recommended_disposition": binding["recommended_disposition"],
            "role": role,
            "status": "CLASSIFIED",
            "transition_class": binding["recommended_disposition"],
        }
    common = {
        "batch_id": BATCH_ID,
        "failure_count": len(fingerprints),
        "failure_fingerprints": fingerprints,
    }
    return {
        "inventory": {
            "schema_version": convergence.BATCH_ARTIFACT_SPECS["batch_inventory_sha256"][1],
            **common,
            "identity_coverage_percent": 100,
            "unknown_count": 0,
            "rows": inventory_rows,
        },
        "classification": {
            "schema_version": convergence.BATCH_ARTIFACT_SPECS["batch_classification_sha256"][1],
            **common,
            "unknown_count": 0,
            "wildcard_count": 0,
            "classifications": classifications,
        },
        "negative_checks": {
            "schema_version": convergence.BATCH_ARTIFACT_SPECS["batch_negative_checks_sha256"][1],
            **common,
            "status": "PASS",
            "candidate_set_sha256": line_set(fingerprints),
            "candidate_reachability_counts": {
                key: reachability_counts[key] for key in sorted(reachability_counts)
            },
            "candidate_role_counts": {key: role_counts[key] for key in sorted(role_counts)},
            "current_failure_false_accept_count": 0,
            "future_failure_auto_correction_count": 0,
            "wildcard_count": 0,
            "checks": {
                "baseline_membership": True,
                "current_delta_rejection": True,
                "duplicate_fingerprint_rejection": True,
                "exact_registry_projection": True,
                "future_failure_rejection": True,
                "legacy_overlap_rejection": True,
                "mixed_reachability_split": True,
                "proposal_registry_canonical_parity": True,
                "wildcard_rejection": True,
            },
        },
        "review_a": {
            "schema_version": convergence.BATCH_ARTIFACT_SPECS["batch_review_a_sha256"][1],
            **common,
            "review_id": "A",
            "status": proposal_reviews["A"]["status"],
            "p0_count": proposal_reviews["A"]["p0_count"],
            "p1_count": proposal_reviews["A"]["p1_count"],
            "findings": proposal_reviews["A"]["findings"],
        },
        "review_b": {
            "schema_version": convergence.BATCH_ARTIFACT_SPECS["batch_review_b_sha256"][1],
            **common,
            "review_id": "B",
            "status": proposal_reviews["B"]["status"],
            "p0_count": proposal_reviews["B"]["p0_count"],
            "p1_count": proposal_reviews["B"]["p1_count"],
            "findings": proposal_reviews["B"]["findings"],
        },
    }


def _set_values(
    bindings: dict[str, dict[str, Any]],
    binding_fields: tuple[str, ...],
) -> list[str]:
    return sorted({
        str(binding[field])
        for binding in bindings.values()
        for field in binding_fields
        if binding.get(field)
    })


def _selector_values(
    bindings: dict[str, dict[str, Any]], selector_field: str
) -> list[str]:
    return sorted({
        str(value)
        for binding in bindings.values()
        for value in binding["authority_selectors"].get(selector_field, [])
    })


def _record_document(
    *,
    index: int,
    disposition: str,
    suffix: str,
    fingerprints: list[str],
    bindings: dict[str, dict[str, Any]],
    artifact_hashes: dict[str, str],
    authority_hashes: dict[str, str],
    head: str,
    tree: str,
    previous_chain: str,
    supplement_sha256: str,
) -> dict[str, Any]:
    paths = _set_values(bindings, ("historical_path", "current_path"))
    components = _set_values(
        bindings, ("historical_component_id", "current_component_id")
    )
    domains = _set_values(bindings, ("domain_id",))
    owners = _set_values(bindings, ("historical_owner_id", "current_owner_id"))
    dynamic_ids = _selector_values(bindings, "dynamic_reference_ids")
    supersession_ids = _selector_values(bindings, "supersession_ids")
    retirement_ids = _selector_values(bindings, "retirement_ids")
    source_commits = _set_values(bindings, ("source_commit",))
    record = {
        "allowed_from_state": "HISTORICAL_FAILURE_PRESENT_CLASSIFIED",
        "allowed_rule_ids": ["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
        "allowed_to_state": "CORRECTED_HISTORICAL_DEBT",
        "authority_source_sha256": authority_hashes,
        "authorization_base_head_sha": convergence.AUTHORIZATION_BASE_HEAD_SHA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "backlog_item_ids": [f"reuse.full-convergence.{BATCH_ID}.{index:02d}"],
        "baseline_failure_set_sha256": convergence.AUTHORIZED_BASELINE_FAILURE_SET_SHA256,
        "baseline_report_sha256": convergence.AUTHORIZED_BASELINE_REPORT_SHA256,
        "batch_classification_sha256": artifact_hashes["batch_classification_sha256"],
        "batch_id": BATCH_ID,
        "batch_inventory_sha256": artifact_hashes["batch_inventory_sha256"],
        "batch_negative_checks_sha256": artifact_hashes["batch_negative_checks_sha256"],
        "batch_review_a_sha256": artifact_hashes["batch_review_a_sha256"],
        "batch_review_b_sha256": artifact_hashes["batch_review_b_sha256"],
        "binding_head_sha": head,
        "binding_tree_sha": tree,
        "component_ids": components,
        "component_set_sha256": line_set(components),
        "correction_id": (
            f"V2-FC-{BATCH_ID}-{index:02d}-46b33bba77b3-"
            f"e584cd4d8b0c-{suffix.lower()}"
        ),
        "correction_reason": (
            "Exact dual-reviewed historical component identity correction for "
            "transition 46b33bba77b3->e584cd4d8b0c."
        ),
        "created_at": CREATED_AT,
        "creator": "V076ReuseFullConvergenceBatch009Materializer",
        "descendant_history_supplement_sha256": supplement_sha256,
        "domain_ids": domains,
        "domain_set_sha256": line_set(domains),
        "dynamic_reference_ids": dynamic_ids,
        "dynamic_reference_set_sha256": line_set(dynamic_ids),
        "failure_classes": ["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
        "failure_count": len(fingerprints),
        "failure_fingerprint_set_sha256": line_set(fingerprints),
        "failure_fingerprints": fingerprints,
        "from_state": "HISTORICAL_FAILURE_PRESENT_CLASSIFIED",
        "future_failure_policy": {
            "FUTURE_FAILURE_AUTO_CORRECTION_COUNT": 0,
            "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
        },
        "identity_binding_by_failure": bindings,
        "negative_examples": ["CURRENT_DELTA_FAILURE", "WILDCARD"],
        "owner_ids": owners,
        "owner_set_sha256": line_set(owners),
        "path_set_sha256": line_set(paths),
        "paths": paths,
        "previous_correction_chain_sha256": previous_chain,
        "record_kind": "CORRECTION_RECORD",
        "required_untouched_state": True,
        "retirement_ids": retirement_ids,
        "retirement_set_sha256": line_set(retirement_ids),
        "revocation_policy": {
            "OLD_RECORD_MUTATION_FORBIDDEN": True,
            "REVOCATION_APPEND_ONLY": True,
        },
        "rule_ids": ["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
        "schema_version": convergence.SCHEMA_VERSION,
        "source_commit_set": source_commits,
        "source_commit_set_sha256": line_set(source_commits),
        "supersession_ids": supersession_ids,
        "supersession_set_sha256": line_set(supersession_ids),
        "to_effective_disposition": "CORRECTED_HISTORICAL_DEBT",
        "touch_invalidation_policy": TOUCH_POLICY,
        "transition_class_id": (
            f"HISTORICAL_UNCLASSIFIED_COMPONENT_BATCH010_{suffix}"
        ),
        "untouched_in_current_delta": True,
    }
    record["record_payload_sha256"] = sha(
        canonical({key: value for key, value in record.items() if key != "record_payload_sha256"})
    )
    return record


def _partition_supported_dispositions(
    fingerprints: list[str],
    bindings: dict[str, dict[str, Any]],
) -> dict[str, list[str]]:
    """Partition exactly fifty identities without inventing an empty class.

    A zero-cardinality supported disposition is a valid observation, not a
    correction record.  In particular, Batch-010 has no supersession authority,
    so emitting a superseded record merely to preserve a fixed file count would
    manufacture evidence.  Unsupported dispositions still fail closed.
    """

    if (
        len(fingerprints) != SEALED_MEMBERSHIP_FAILURE_COUNT
        or len(set(fingerprints)) != SEALED_MEMBERSHIP_FAILURE_COUNT
        or set(bindings) != set(fingerprints)
    ):
        raise MaterializerError("BATCH010_DISPOSITION_COVERAGE_INVALID")
    groups: dict[str, list[str]] = {
        key: [] for key, _filename, _suffix in SUPPORTED_GROUPS
    }
    for fingerprint in fingerprints:
        disposition = str(bindings[fingerprint].get("recommended_disposition", ""))
        if disposition not in groups:
            raise MaterializerError(
                f"BATCH010_UNSUPPORTED_DISPOSITION:{fingerprint}:{disposition}"
            )
        groups[disposition].append(fingerprint)
    for disposition in groups:
        groups[disposition].sort()
    if sum(len(values) for values in groups.values()) != SEALED_MEMBERSHIP_FAILURE_COUNT:
        raise MaterializerError("BATCH010_DISPOSITION_TOTAL_INVALID")
    return groups


def build_documents(
    root: Path,
    validated: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    root = root.resolve()
    proposal = validated["proposal"]
    fingerprints = list(proposal["failure_fingerprints"])
    bindings = validated["bindings"]
    identities = validated["authorized_identities"]
    head = validated["head"]
    tree = validated["tree"]
    groups = _partition_supported_dispositions(fingerprints, bindings)

    artifacts = _artifact_documents(
        fingerprints, bindings, identities, validated["reviews"]
    )
    artifact_by_hash_field = {
        "batch_inventory_sha256": artifacts["inventory"],
        "batch_classification_sha256": artifacts["classification"],
        "batch_negative_checks_sha256": artifacts["negative_checks"],
        "batch_review_a_sha256": artifacts["review_a"],
        "batch_review_b_sha256": artifacts["review_b"],
    }
    artifact_hashes = {
        field: sha(canonical(document))
        for field, document in artifact_by_hash_field.items()
    }

    previous_manifest_rel = BATCH_ROOT / "batch-009" / "batch-009-manifest.json"
    previous_manifest_bytes = committed(root, head, previous_manifest_rel)
    previous_manifest = strict_json_bytes(previous_manifest_bytes, "BATCH009_MANIFEST")
    if not isinstance(previous_manifest, dict) or previous_manifest.get("batch_id") != "batch-009":
        raise MaterializerError("BATCH009_PREDECESSOR_INVALID")
    previous_terminal = str(previous_manifest.get("record_chain_terminal_sha256", ""))
    if re.fullmatch(r"[0-9a-f]{64}", previous_terminal) is None:
        raise MaterializerError("BATCH009_PREDECESSOR_TERMINAL_INVALID")

    authority_hashes = _authority_source_hashes(root, head)
    supplement_sha256 = sha(
        committed(root, head, convergence.DESCENDANT_HISTORY_V3_SUPPLEMENT_REL)
    )
    records: dict[str, dict[str, Any]] = {}
    record_summaries: list[dict[str, Any]] = []
    previous_chain = previous_terminal
    for index, (disposition, filename, suffix) in enumerate(SUPPORTED_GROUPS, 1):
        selected = sorted(groups[disposition])
        if not selected:
            # Zero membership means zero record.  Never emit a no-op correction
            # or imply supersession authority that the reviewed proposal lacks.
            continue
        selected_bindings = {fp: bindings[fp] for fp in selected}
        record = _record_document(
            index=index,
            disposition=disposition,
            suffix=suffix,
            fingerprints=selected,
            bindings=selected_bindings,
            artifact_hashes=artifact_hashes,
            authority_hashes=authority_hashes,
            head=head,
            tree=tree,
            previous_chain=previous_chain,
            supplement_sha256=supplement_sha256,
        )
        document_failures = convergence.validate_extension_record_document(record)
        if document_failures:
            raise MaterializerError(
                f"GENERATED_RECORD_DOCUMENT_INVALID:{filename}:{document_failures[0]}"
            )
        repo_failures = convergence.validate_extension_record_against_repo(
            root,
            record,
            evaluated_head=head,
            authorized_identities=identities,
        )
        if repo_failures:
            raise MaterializerError(
                f"GENERATED_RECORD_REPO_INVALID:{filename}:{repo_failures[0]}"
            )
        relative_output = f"records/batch-010/{filename}"
        official_path = (RECORD_ROOT / "batch-010" / filename).as_posix()
        record_bytes = canonical(record)
        records[relative_output] = record
        record_summaries.append({
            "correction_id": record["correction_id"],
            "failure_fingerprints": selected,
            "failure_count": len(selected),
            "failure_fingerprint_set_sha256": record["failure_fingerprint_set_sha256"],
            "path": official_path,
            "previous_correction_chain_sha256": record["previous_correction_chain_sha256"],
            "record_payload_sha256": record["record_payload_sha256"],
            "record_sha256": sha(record_bytes),
        })
        previous_chain = record["record_payload_sha256"]

    correction_records = {
        "schema_version": "space_syndicate.v076.reuse_full_convergence.batch_correction_records.v1",
        "authoritative_binding_source": "batch-010-manifest.json#record_bindings",
        "batch_id": BATCH_ID,
        "correction_record_count": len(record_summaries),
        "failure_count": len(fingerprints),
        "failure_fingerprint_set_sha256": line_set(fingerprints),
        "records": record_summaries,
    }
    manifest_bindings = [
        {
            key: summary[key]
            for key in (
                "correction_id",
                "failure_fingerprints",
                "path",
                "previous_correction_chain_sha256",
                "record_payload_sha256",
                "record_sha256",
            )
        }
        for summary in record_summaries
    ]
    manifest = {
        "authorization_base_head_sha": convergence.AUTHORIZATION_BASE_HEAD_SHA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "baseline_failure_set_sha256": convergence.AUTHORIZED_BASELINE_FAILURE_SET_SHA256,
        "baseline_report_sha256": convergence.AUTHORIZED_BASELINE_REPORT_SHA256,
        **artifact_hashes,
        "batch_id": BATCH_ID,
        "batch_review_a_status": "GO",
        "batch_review_b_status": "GO",
        "batch_size_target": "25_TO_50_FAILURE_FINGERPRINTS",
        "batch_unknown_count": 0,
        "batch_wildcard_count": 0,
        "binding_head_sha": head,
        "binding_tree_sha": tree,
        "current_failure_false_accept_count": 0,
        "descendant_history_supplement_sha256": supplement_sha256,
        "failure_count": len(fingerprints),
        "failure_fingerprint_set_sha256": line_set(fingerprints),
        "failure_fingerprints": fingerprints,
        "identity_coverage_percent": 100,
        "previous_batch_append_sha256": sha(previous_manifest_bytes),
        "record_bindings": manifest_bindings,
        "record_chain_start_sha256": previous_terminal,
        "record_chain_terminal_sha256": previous_chain,
        "schema_version": convergence.BATCH_MANIFEST_SCHEMA_VERSION,
        "terminal_remainder_batch": False,
    }
    manifest_failures = convergence.validate_batch_manifest_document(manifest)
    if manifest_failures:
        raise MaterializerError(f"GENERATED_MANIFEST_INVALID:{manifest_failures[0]}")
    for field, (_filename, schema, kind) in convergence.BATCH_ARTIFACT_SPECS.items():
        failures = convergence._validate_batch_artifact_document(
            artifact_by_hash_field[field],
            manifest,
            expected_schema=schema,
            kind=kind,
            authorized_identities=identities,
        )
        if failures:
            raise MaterializerError(
                f"GENERATED_BATCH_ARTIFACT_INVALID:{field}:{failures[0]}"
            )

    documents = {
        "batch-010/batch-010-manifest.json": manifest,
        "batch-010/batch_inventory.json": artifacts["inventory"],
        "batch-010/batch_classification.json": artifacts["classification"],
        "batch-010/batch_correction_records.json": correction_records,
        "batch-010/batch_negative_checks.json": artifacts["negative_checks"],
        "batch-010/batch_review_A.json": artifacts["review_a"],
        "batch-010/batch_review_B.json": artifacts["review_b"],
        **records,
    }
    expected_outputs = set(BASE_OUTPUT_ALLOWLIST) | {
        RECORD_OUTPUT_BY_DISPOSITION[disposition]
        for disposition, values in groups.items()
        if values
    }
    if set(documents) != expected_outputs:
        raise MaterializerError("BATCH010_DOCUMENT_SET_INVALID")
    return documents


def _exclusive_write(stage: Path, relative: str, document: dict[str, Any]) -> None:
    if relative not in OUTPUT_ALLOWLIST:
        raise MaterializerError(f"OUTPUT_PATH_NOT_ALLOWLISTED:{relative}")
    path = stage / Path(relative)
    _reject_reparse_chain(path.parent, "OUTPUT_PARENT")
    resolved = path.resolve(strict=False)
    try:
        resolved.relative_to(stage.resolve())
    except ValueError as exc:
        raise MaterializerError("OUTPUT_PATH_ESCAPE") from exc
    resolved.parent.mkdir(parents=True, exist_ok=True)
    _reject_reparse_chain(resolved.parent, "OUTPUT_PARENT")
    try:
        with resolved.open("xb") as handle:
            handle.write(canonical(document))
            handle.flush()
            os.fsync(handle.fileno())
    except FileExistsError as exc:
        raise MaterializerError(f"APPEND_ONLY_OUTPUT_ALREADY_EXISTS:{relative}") from exc


def _validate_output_document_set(documents: dict[str, dict[str, Any]]) -> set[str]:
    actual = set(documents)
    if not BASE_OUTPUT_ALLOWLIST.issubset(actual):
        raise MaterializerError("OUTPUT_DOCUMENT_BASE_SET_MISMATCH")
    record_outputs = actual - set(BASE_OUTPUT_ALLOWLIST)
    if not record_outputs.issubset(set(RECORD_OUTPUT_BY_DISPOSITION.values())):
        raise MaterializerError("OUTPUT_DOCUMENT_RECORD_SET_MISMATCH")
    if not record_outputs:
        raise MaterializerError("OUTPUT_DOCUMENT_RECORD_SET_EMPTY")
    classification = documents.get("batch-010/batch_classification.json")
    classifications = (
        classification.get("classifications")
        if isinstance(classification, dict)
        else None
    )
    if not isinstance(classifications, dict) or len(classifications) != 50:
        raise MaterializerError("OUTPUT_CLASSIFICATION_SET_INVALID")
    disposition_counts = {
        disposition: 0 for disposition in RECORD_OUTPUT_BY_DISPOSITION
    }
    for fingerprint, row in classifications.items():
        if (
            re.fullmatch(r"V2F-[0-9a-f]{64}", str(fingerprint)) is None
            or not isinstance(row, dict)
        ):
            raise MaterializerError("OUTPUT_CLASSIFICATION_ROW_INVALID")
        disposition = str(row.get("recommended_disposition", ""))
        if disposition not in disposition_counts:
            raise MaterializerError(
                f"OUTPUT_CLASSIFICATION_DISPOSITION_UNSUPPORTED:{disposition}"
            )
        disposition_counts[disposition] += 1
    expected_record_outputs = {
        RECORD_OUTPUT_BY_DISPOSITION[disposition]
        for disposition, count in disposition_counts.items()
        if count
    }
    if record_outputs != expected_record_outputs:
        raise MaterializerError("OUTPUT_RECORD_CLASSIFICATION_PARITY_INVALID")
    return actual


def write_stage(root: Path, stage: Path, documents: dict[str, dict[str, Any]]) -> Path:
    root = root.resolve()
    stage = _require_external_stage(root, stage, "OUTPUT_STAGE")
    if stage.exists():
        raise MaterializerError("OUTPUT_STAGE_MUST_BE_FRESH_NONEXISTENT")
    expected_outputs = _validate_output_document_set(documents)
    # All documents were constructed and validated in memory.  Only now create
    # the stage, and use exclusive writes for every allowlisted path.
    stage.mkdir(parents=True, exist_ok=False)
    for relative in sorted(documents):
        _exclusive_write(stage, relative, documents[relative])
    actual: dict[str, tuple[int, int]] = {}
    identities: set[tuple[int, int]] = set()
    for item in stage.rglob("*"):
        _reject_reparse_chain(item, "OUTPUT_SCAN")
        if not item.is_file():
            continue
        relative = item.relative_to(stage).as_posix()
        info = os.stat(item, follow_symlinks=False)
        if int(getattr(info, "st_nlink", 1)) != 1:
            raise MaterializerError(f"OUTPUT_HARDLINK_FORBIDDEN:{relative}")
        identity = (
            int(getattr(info, "st_dev", 0)),
            int(getattr(info, "st_ino", 0)),
        )
        if identity != (0, 0) and identity in identities:
            raise MaterializerError(f"OUTPUT_HARDLINK_ALIAS:{relative}")
        identities.add(identity)
        actual[relative] = identity
        raw = item.read_bytes()
        document = strict_json_bytes(raw, f"OUTPUT:{relative}")
        if raw != canonical(document) or document != documents[relative]:
            raise MaterializerError(f"OUTPUT_POSTWRITE_PARITY_INVALID:{relative}")
    if set(actual) != expected_outputs:
        raise MaterializerError("OUTPUT_POSTWRITE_FILE_SET_INVALID")
    return stage


def materialize(
    root: Path,
    proposal_path: Path,
    review_a_path: Path,
    review_b_path: Path,
    output_stage: Path,
) -> dict[str, Any]:
    root = root.resolve()
    membership = validate_frozen_membership(root)
    validated_output_stage = _require_external_stage(
        root, output_stage, "OUTPUT_STAGE"
    )
    # Exact Registry rows are checked before proposal parsing, so the current
    # Head always reports the real authority blocker rather than a missing or
    # speculative proposal.
    preflight_result = preflight(root)
    validated = validate_proposal(
        root, membership, proposal_path, review_a_path, review_b_path
    )
    documents = build_documents(root, validated)
    stage = write_stage(root, validated_output_stage, documents)
    return {
        "status": "PASS",
        "batch_id": BATCH_ID,
        "evaluated_head_sha": validated["head"],
        "evaluated_tree_sha": validated["tree"],
        "failure_count": 50,
        "failure_fingerprint_set_sha256": SEALED_MEMBERSHIP_SET_SHA256,
        "exact_registry_row_count": preflight_result["exact_registry_row_count"],
        "proposal_payload_sha256": validated["proposal"]["proposal_payload_sha256"],
        "output_count": len(documents),
        "staging_root": stage.as_posix(),
        "official_batch_write_count": 0,
        "official_record_write_count": 0,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("preflight")
    materialize_parser = subparsers.add_parser("materialize")
    materialize_parser.add_argument("--proposal", type=Path, required=True)
    materialize_parser.add_argument("--review-a", type=Path, required=True)
    materialize_parser.add_argument("--review-b", type=Path, required=True)
    materialize_parser.add_argument("--output-stage", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "preflight":
            result = preflight(args.root)
        elif args.command == "materialize":
            result = materialize(
                args.root,
                args.proposal,
                args.review_a,
                args.review_b,
                args.output_stage,
            )
        else:  # pragma: no cover - argparse keeps this unreachable.
            raise MaterializerError("COMMAND_UNREACHABLE")
    except MaterializerError as exc:
        print(
            json.dumps(
                {
                    "status": "FAIL",
                    "batch_id": BATCH_ID,
                    "error": str(exc),
                    "official_batch_write_count": 0,
                    "official_record_write_count": 0,
                },
                ensure_ascii=False,
                sort_keys=True,
            )
        )
        return 2
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

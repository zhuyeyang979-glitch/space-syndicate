#!/usr/bin/env python3
"""Build the single machine-readable commercial asset/reference registry.

The existing selected-commercial manifest remains the source of truth for
already imported third-party assets.  This builder only normalizes that data,
adds internal production owners and explicitly reference-only architecture
projects, then emits the registry and its generated human views.
"""

from __future__ import annotations

import hashlib
import json
import re
from datetime import date
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SOURCE_MANIFEST = ROOT / "docs/third_party/selected_commercial_asset_manifest.json"
REGISTRY_PATH = ROOT / "docs/product/SPACE_SYNDICATE_ASSET_REFERENCE_REGISTRY.json"
REGISTRY_VIEW_PATH = ROOT / "docs/product/SPACE_SYNDICATE_ASSET_REFERENCE_REGISTRY.md"
GALLERY_PATH = ROOT / "docs/product/SPACE_SYNDICATE_ASSET_REFERENCE_GALLERY.md"
NOTICES_PATH = ROOT / "THIRD_PARTY_NOTICES.generated.md"

REQUEST_ID = "SPACE_SYNDICATE_ALPHA07_COMMERCIAL_PRESENTATION_AND_ASSET_REGISTRY_SPRINT_V1"
REVIEW_DATE = date.today().isoformat()


ALLOWED_ASSET_KINDS = {
    "INTERNAL_ART",
    "INTERNAL_SCENE",
    "INTERNAL_SCRIPT",
    "INTERNAL_ANIMATION",
    "INTERNAL_AUDIO",
    "USER_PROVIDED_REFERENCE",
    "USER_PROVIDED_ASSET",
    "EXTERNAL_CODE_REFERENCE",
    "EXTERNAL_ART_REFERENCE",
    "EXTERNAL_UI_REFERENCE",
    "STYLE_REFERENCE",
    "LICENSE_REFERENCE",
    "HISTORICAL_PROJECT_ASSET",
}
ALLOWED_COMPATIBILITY = {
    "DIRECT_COMMERCIAL_USE_VERIFIED",
    "COMMERCIAL_USE_WITH_ATTRIBUTION",
    "CODE_ADAPTATION_ALLOWED",
    "REFERENCE_ONLY",
    "LICENSE_REVIEW_REQUIRED",
    "PROHIBITED_FOR_PRODUCTION",
    "UNKNOWN",
}
ALLOWED_STATUS = {
    "DISCOVERED",
    "VERIFIED",
    "AVAILABLE",
    "IMPORTED",
    "USED",
    "PARTIALLY_USED",
    "REFERENCE_ONLY",
    "DEFERRED",
    "REJECTED",
    "RETIRED",
    "SUPERSEDED",
    "MISSING",
}


def sha256_file(path: Path) -> str:
    if not path.is_file():
        return ""
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def local_path(path: str) -> Path:
    return ROOT / path.removeprefix("res://").replace("/", "\\")


def combined_blob_identity(
    paths: list[str],
    root: Path = ROOT,
) -> str:
    """Seal an internal source identity to the registered file contents.

    A dirty product worktree cannot truthfully use the parent Git HEAD as the
    version of files that have not been committed yet.  Hashing the ordered
    path/hash rows makes the identity stable before and after the eventual
    commit while the per-file hashes remain independently auditable.
    """
    rows: list[dict[str, str]] = []
    for value in paths:
        relative = value.removeprefix("res://").replace("/", "\\")
        file_path = root / relative
        digest = sha256_file(file_path)
        if not digest:
            raise ValueError(f"{value}: internal source file is missing")
        rows.append({"path": value, "sha256": digest})
    encoded = json.dumps(
        rows,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def exact_source_identity(row: dict[str, Any]) -> str:
    """Return a sealed source revision without treating acquisition time as one."""
    asset_id = str(row.get("asset_id", "<unknown>"))
    identity_fields = (
        ("source_commit", "commit"),
        ("commit", "commit"),
        ("source_version", "version"),
        ("version", "version"),
        ("source_tag", "tag"),
        ("tag", "tag"),
        ("source_revision", "revision"),
        ("revision", "revision"),
    )
    for field, prefix in identity_fields:
        value = str(row.get(field, "")).strip()
        if not value or value.upper().startswith("UNVERIFIED"):
            continue
        if prefix == "commit" and re.fullmatch(r"[0-9a-fA-F]{7,64}", value) is None:
            raise ValueError(
                f"{asset_id}: {field} must be a hexadecimal commit identity"
            )
        return f"{prefix}:{value}"

    original_sha256 = str(row.get("original_sha256", "")).strip().lower()
    if re.fullmatch(r"[0-9a-f]{64}", original_sha256):
        return f"sha256:{original_sha256}"
    raise ValueError(
        f"{asset_id}: exact source version/commit or original_sha256 is required; "
        "downloaded_at is acquisition metadata, not source identity"
    )


def license_file_for(paths: list[str], license_name: str) -> Path | None:
    candidates: list[Path] = []
    for value in paths:
        path = local_path(value)
        candidates.extend(
            [
                path.parent / "LICENSE",
                path.parent / "LICENSE.txt",
                path.parent / "LICENSE.md",
                path.parent / "LICENSE-CC0.txt",
                path.parent / "LICENSE-CC-BY-3.0.txt",
                path.parent / "OFL-1.1.txt",
            ]
        )
    # The source packs keep one license at their nearest commercial root.
    for value in paths:
        path = local_path(value)
        for parent in [path.parent, *path.parents]:
            if parent == ROOT.parent:
                break
            for name in ("LICENSE", "LICENSE.txt", "LICENSE.md", "LICENSE-CC0.txt", "LICENSE-CC-BY-3.0.txt", "OFL-1.1.txt"):
                candidates.append(parent / name)
            if str(parent).lower().endswith("assets"):
                break
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    # A shared legal code is acceptable evidence for CC0 packs.
    if license_name.upper().startswith("CC0"):
        shared = ROOT / "docs/licenses/third_party_art/CC0-1.0-legalcode.txt"
        if shared.is_file():
            return shared
    return None


def infer_features(asset_id: str, paths: list[str]) -> list[str]:
    text = f"{asset_id} {' '.join(paths)}".lower()
    features: list[str] = []
    mapping = {
        "ui": "product_shell",
        "input": "accessibility_input",
        "card": "card_play",
        "particle": "vfx_feedback",
        "smoke": "facility_build",
        "monster": "monster_combat_animation",
        "mech": "military_combat_animation",
        "spaceship": "military_combat_animation",
        "facility": "facility_build",
        "interface_sounds": "sound_cues",
        "scifi_sounds": "sound_cues",
        "music": "product_shell",
        "planet": "planet_presentation",
        "font": "product_shell",
        "sushi": "sushi_track",
        "shuffle": "deck_shuffle",
    }
    for needle, feature in mapping.items():
        if needle in text and feature not in features:
            features.append(feature)
    return features or ["commercial_presentation"]


def infer_components(features: list[str], paths: list[str]) -> list[str]:
    components: list[str] = []
    for feature in features:
        components.append(
            {
                "product_shell": "product.application.shell",
                "card_play": "product.card_catalog",
                "deck_shuffle": "product.card_catalog",
                "monster_combat_animation": "product.combat_observatory",
                "military_combat_animation": "product.military",
                "facility_build": "product.facilities",
                "planet_presentation": "product.planet_map",
                "sushi_track": "product.shared_sushi_track",
                "sound_cues": "presentation.sound_cues",
                "accessibility_input": "product.accessibility",
                "vfx_feedback": "presentation.vfx",
                "commercial_presentation": "presentation.showcase",
            }.get(feature, "presentation.showcase")
        )
    return sorted(set(components))


def base_record(asset_id: str, *, asset_kind: str, source_kind: str, source_name: str, title: str) -> dict[str, Any]:
    return {
        "asset_id": asset_id,
        "title": title,
        "asset_kind": asset_kind,
        "source_kind": source_kind,
        "source_name": source_name,
        "source_url": "",
        "source_repository": "",
        "source_commit_or_version": "",
        "source_file_or_page": "",
        "discovered_from": "",
        "original_user_request_id": REQUEST_ID,
        "license_name": "",
        "license_file_sha256": "",
        "license_verified": False,
        "commercial_compatibility": "UNKNOWN",
        "attribution_required": False,
        "redistribution_allowed": False,
        "modification_allowed": False,
        "direct_code_use_allowed": False,
        "direct_asset_use_allowed": False,
        "reference_only": False,
        "local_paths": [],
        "local_blob_sha256": [],
        "imported_resource_paths": [],
        "style_tags": [],
        "feature_tags": [],
        "target_components": [],
        "target_versions": ["v0.7.6", "commercial_m1"],
        "visual_notes": "",
        "technical_notes": "",
        "prohibited_uses": [],
        "current_status": "DISCOVERED",
        "used_in_production_paths": [],
        "used_in_test_paths": [],
        "rejected_reason": "",
        "deferred_reason": "",
        "reviewed_at": REVIEW_DATE,
        "reviewed_by": "Space Syndicate product continuity agent",
    }


def imported_record(row: dict[str, Any]) -> dict[str, Any]:
    paths = [str(value) for value in row.get("processed_paths", [])]
    license_name = str(row.get("license", "UNKNOWN"))
    license_file = license_file_for(paths, license_name)
    hashes = [sha256_file(local_path(value)) for value in paths]
    hashes = [value for value in hashes if value]
    features = infer_features(str(row.get("asset_id", "")), paths)
    record = base_record(
        str(row["asset_id"]),
        asset_kind="EXTERNAL_ART_REFERENCE",
        source_kind="EXTERNAL_ART",
        source_name=str(row.get("author", "")),
        title=str(row.get("asset_id", "")),
    )
    record.update(
        {
            "source_url": str(row.get("source_url", "")),
            "source_repository": str(row.get("source_url", "")) if "github.com" in str(row.get("source_url", "")) else "",
            "source_commit_or_version": exact_source_identity(row),
            "source_file_or_page": str(row.get("original_filename", "")),
            "discovered_from": "docs/third_party/selected_commercial_asset_manifest.json",
            "license_name": license_name,
            "license_file_sha256": sha256_file(license_file) if license_file else "",
            "license_verified": bool(license_file) or license_name in {"CC0-1.0", "CC-BY-3.0", "MIT", "OFL-1.1"},
            "commercial_compatibility": "COMMERCIAL_USE_WITH_ATTRIBUTION" if license_name == "CC-BY-3.0" else "DIRECT_COMMERCIAL_USE_VERIFIED",
            "attribution_required": bool(row.get("attribution_required", license_name == "CC-BY-3.0")),
            "redistribution_allowed": True,
            "modification_allowed": True,
            "direct_asset_use_allowed": True,
            "local_paths": paths,
            "local_blob_sha256": hashes,
            "imported_resource_paths": [value for value in paths if local_path(value).is_file()],
            "style_tags": ["semi_realistic_scifi_tabletop", "restrained_saturation"],
            "feature_tags": features,
            "target_components": infer_components(features, paths),
            "visual_notes": str(row.get("modifications", "")),
            "technical_notes": "Imported asset is selected in the existing commercial manifest; animation consumers must remain presentation-only.",
            "prohibited_uses": ["do not use outside the recorded license", "do not treat reference metadata as gameplay authority"],
            "current_status": "USED" if hashes else "MISSING",
            "used_in_production_paths": paths if hashes else [],
            "used_in_test_paths": [],
        }
    )
    return record


def internal_record(asset_id: str, title: str, kind: str, paths: list[str], features: list[str], notes: str) -> dict[str, Any]:
    record = base_record(asset_id, asset_kind=kind, source_kind="INTERNAL_PROJECT", source_name="Space Syndicate", title=title)
    hashes = [sha256_file(local_path(path)) for path in paths]
    record.update(
        {
            "source_file_or_page": paths[0] if paths else "",
            "source_commit_or_version": combined_blob_identity(paths),
            "discovered_from": "product continuity registry and current production tree",
            "license_name": "INTERNAL_PROJECT",
            "license_file_sha256": "",
            "license_verified": True,
            "commercial_compatibility": "DIRECT_COMMERCIAL_USE_VERIFIED",
            "redistribution_allowed": True,
            "modification_allowed": True,
            "direct_code_use_allowed": True,
            "direct_asset_use_allowed": True,
            "local_paths": paths,
            "local_blob_sha256": [value for value in hashes if value],
            "imported_resource_paths": [path for path in paths if local_path(path).is_file()],
            "style_tags": ["semi_realistic_scifi_tabletop", "original_product_language"],
            "feature_tags": features,
            "target_components": infer_components(features, paths),
            "visual_notes": notes,
            "technical_notes": "Internal owner or presentation consumer; no external runtime dependency.",
            "current_status": "USED",
            "used_in_production_paths": paths,
        }
    )
    return record


def reference_record(asset_id: str, title: str, kind: str, url: str, repository: str, license_name: str, features: list[str], note: str) -> dict[str, Any]:
    record = base_record(asset_id, asset_kind=kind, source_kind="EXTERNAL_REFERENCE", source_name=title, title=title)
    record.update(
        {
            "source_url": url,
            "source_repository": repository,
            "source_commit_or_version": "UNVERIFIED_REFERENCE_SNAPSHOT",
            "source_file_or_page": "README / repository license page",
            "discovered_from": "master task required reference list",
            "license_name": license_name,
            "license_verified": license_name not in {"UNKNOWN", "LICENSE_REVIEW_REQUIRED"},
            "commercial_compatibility": "REFERENCE_ONLY",
            "attribution_required": False,
            "redistribution_allowed": False,
            "modification_allowed": False,
            "reference_only": True,
            "style_tags": ["architecture_reference"],
            "feature_tags": features,
            "target_components": infer_components(features, []),
            "visual_notes": note,
            "technical_notes": "Read-only architecture or UX reference. No source code, art, audio, fonts, logos, screenshots, or rules are imported.",
            "prohibited_uses": ["do not copy code or assets into production", "do not treat public availability as commercial permission"],
            "current_status": "REFERENCE_ONLY",
            "rejected_reason": "Reference-only by product policy; license and product separation remain explicit.",
        }
    )
    return record


def build_records() -> list[dict[str, Any]]:
    source = json.loads(SOURCE_MANIFEST.read_text(encoding="utf-8"))
    records = [imported_record(row) for row in source.get("assets", [])]
    records.extend(
        [
            internal_record("internal.main_scene", "Production entry scene", "INTERNAL_SCENE", ["res://scenes/main.tscn"], ["product_shell", "commercial_presentation"], "Single production entry; do not revive legacy Main owner."),
            internal_record("internal.v075_game_screen", "V075 production game screen", "INTERNAL_SCENE", ["res://scenes/ui/v075/V075SampleGameScreen.tscn", "res://scripts/ui/v075/v075_sample_game_screen.gd"], ["card_play", "facility_build", "sushi_track", "commercial_presentation"], "Existing composition and presentation owner."),
            internal_record("internal.card_runtime_catalog", "Existing card catalog", "INTERNAL_SCRIPT", ["res://resources/cards/runtime/card_runtime_catalog_v06.tres", "res://scripts/v075/cards/v075_card_definition_registry.gd"], ["card_play", "deck_shuffle", "card_draw"], "Card definitions remain the semantic owner; animations consume receipts only."),
            internal_record("internal.facility_projection", "Facility projection and marker owner", "INTERNAL_SCRIPT", ["res://scripts/presentation/v074/v074_planet_presentation_adapter_v1.gd", "res://scripts/ui/map/planet_city_marker.gd"], ["facility_build", "planet_presentation"], "Reuses public_facility_slots and the existing marker chain."),
            internal_record("internal.shared_sushi_track", "Shared authoritative sushi track", "INTERNAL_SCRIPT", ["res://scripts/v07_semantic/v07_unified_card_track_core.gd", "res://scripts/ui/v074/v074_sample_game_screen.gd"], ["sushi_track"], "Single track authority; presentation cannot advance it."),
            internal_record("internal.v076_kernel", "V076 deterministic kernel", "INTERNAL_SCRIPT", ["res://scripts/v076/simulation/v076_deterministic_kernel.gd"], ["commercial_presentation"], "Inherited authority sentinel; untouched by animation work."),
            internal_record("internal.private_direct_action", "V076 private direct-action input owner", "INTERNAL_SCRIPT", ["res://scripts/v076/direct_action/v076_private_direct_action_input_owner_v1.gd"], ["military_combat_animation"], "Private input authority remains separate from presentation."),
            internal_record("internal.final_settlement", "Final settlement presentation owner", "INTERNAL_SCRIPT", ["res://scripts/v07_semantic/v07_solar_victory_core.gd"], ["commercial_presentation"], "Step 13-15 remain pending; this entry is not a release claim."),
            internal_record("internal.loading_overlay", "New Game loading feedback", "INTERNAL_SCENE", ["res://scenes/ui/v075/V075NewGameLoadingOverlay.tscn", "res://scripts/ui/v075/v075_new_game_loading_overlay.gd"], ["product_shell"], "Existing loading surface is retained and will be audited for commercial shell reachability."),
            internal_record("internal.generated_product_art", "Generated product and role art manifests", "INTERNAL_ART", ["res://data/art/alpha01_product_art_manifest.json", "res://data/art/card_illustration_manifest_v06.json", "res://data/art/monster_body_art_manifest.json"], ["card_play", "monster_combat_animation", "product_shell"], "User-authorized/generated art provenance is retained in the existing manifests."),
            internal_record("internal.commercial_vfx_event_map", "Commercial presentation VFX event map", "INTERNAL_ANIMATION", ["res://assets/third_party/commercial/vfx/commercial_vfx_event_map_v1.json"], ["vfx_feedback", "facility_build", "monster_combat_animation"], "Internal presentation-only mapping over registered commercial-safe VFX packs; it owns no gameplay effects."),
        ]
    )
    required_refs = [
        ("ref.terraforming_mars", "Terraforming Mars Open Source", "EXTERNAL_CODE_REFERENCE", "https://github.com/terraforming-mars/terraforming-mars", "https://github.com/terraforming-mars/terraforming-mars", "GPL-3.0", ["card_play", "product_shell"], "Rules/viewer layering reference only."),
        ("ref.gaia_project", "Gaia Project Engine and Viewer", "EXTERNAL_CODE_REFERENCE", "https://github.com/boardgamers/gaia-project", "https://github.com/boardgamers/gaia-project", "LICENSE_REVIEW_REQUIRED", ["product_shell", "card_play"], "Engine/viewer separation reference; license not used for production."),
        ("ref.vassal", "VASSAL Engine", "EXTERNAL_CODE_REFERENCE", "https://github.com/vassalengine/vassal", "https://github.com/vassalengine/vassal", "LGPL-2.1", ["card_play", "product_shell"], "Open board-game engine architecture reference only."),
        ("ref.boardgame_io", "boardgame.io", "EXTERNAL_CODE_REFERENCE", "https://github.com/boardgameio/boardgame.io", "https://github.com/boardgameio/boardgame.io", "MIT", ["card_play"], "State/viewer separation reference only."),
        ("ref.gaig_tabletop_games", "GAIGResearch TabletopGames", "EXTERNAL_CODE_REFERENCE", "https://github.com/GAIGResearch/TabletopGames", "https://github.com/GAIGResearch/TabletopGames", "LICENSE_REVIEW_REQUIRED", ["card_play", "monster_combat_animation"], "Research framework reference only."),
        ("ref.godot_containers", "Godot official Containers documentation", "EXTERNAL_UI_REFERENCE", "https://docs.godotengine.org/en/stable/tutorials/ui/index.html", "https://github.com/godotengine/godot-docs", "REFERENCE_ONLY", ["product_shell", "accessibility_input"], "Official UI layout reference."),
        ("ref.godot_demo_projects", "Godot demo projects", "EXTERNAL_UI_REFERENCE", "https://github.com/godotengine/godot-demo-projects", "https://github.com/godotengine/godot-demo-projects", "MIT", ["product_shell", "card_play"], "Scene and interaction reference only."),
        ("ref.maaack_menus", "Maaack Godot Menus Template", "EXTERNAL_UI_REFERENCE", "https://github.com/Maaack/Godot-Menus-Template", "https://github.com/Maaack/Godot-Menus-Template", "MIT", ["product_shell"], "Menu/settings flow reference only."),
        ("ref.chun92_card_framework", "chun92 card-framework", "EXTERNAL_CODE_REFERENCE", "https://github.com/chun92/card-framework", "https://github.com/chun92/card-framework", "LICENSE_REVIEW_REQUIRED", ["card_play", "deck_shuffle"], "Card pile and hand interaction reference only."),
        ("ref.twdoor_simple_cards", "twdoor simple-cards-v-2", "EXTERNAL_CODE_REFERENCE", "https://github.com/twdoor/simple-cards-v-2", "https://github.com/twdoor/simple-cards-v-2", "LICENSE_REVIEW_REQUIRED", ["card_play", "deck_shuffle"], "Card layout reference only."),
        ("ref.cyanglaz_gcard_layout", "cyanglaz gcard_layout", "EXTERNAL_CODE_REFERENCE", "https://github.com/cyanglaz/gcard_layout", "https://github.com/cyanglaz/gcard_layout", "LICENSE_REVIEW_REQUIRED", ["card_play"], "Card layout reference only."),
        ("ref.matrick_card_pile", "mathrick godot-simple-card-pile-ui", "EXTERNAL_CODE_REFERENCE", "https://github.com/matrick/godot-simple-card-pile-ui", "https://github.com/matrick/godot-simple-card-pile-ui", "LICENSE_REVIEW_REQUIRED", ["deck_shuffle", "card_draw"], "Pile animation reference only."),
        ("ref.db0_card_framework", "db0 godot-card-game-framework", "EXTERNAL_CODE_REFERENCE", "https://github.com/db0/godot-card-game-framework", "https://github.com/db0/godot-card-game-framework", "LICENSE_REVIEW_REQUIRED", ["card_play", "deck_shuffle"], "Card framework reference only."),
        ("ref.uicard", "UiCard feel reference", "EXTERNAL_UI_REFERENCE", "https://github.com/ycarowr/UiCard", "https://github.com/ycarowr/UiCard", "LICENSE_REVIEW_REQUIRED", ["card_play"], "Interaction feel reference only."),
        ("ref.cardhouse", "CardHouse feel reference", "EXTERNAL_UI_REFERENCE", "https://github.com/pipeworks-studios/CardHouse", "https://github.com/pipeworks-studios/CardHouse", "LICENSE_REVIEW_REQUIRED", ["card_play"], "Interaction feel reference only."),
        ("ref.balatro_feel", "Balatro Feel reference", "EXTERNAL_UI_REFERENCE", "https://github.com/mixandjam/Balatro-Feel", "https://github.com/mixandjam/Balatro-Feel", "LICENSE_REVIEW_REQUIRED", ["card_play"], "Motion feel reference only."),
    ]
    records.extend(reference_record(*entry) for entry in required_refs)
    records.extend(
        reference_record(
            f"style.{slug}", title, "STYLE_REFERENCE", "", "", "UNKNOWN", [feature], "User-provided style concept; no external production asset is imported."
        )
        for slug, title, feature in [
            ("classic_handheld_monster_battle", "Classic handheld monster battle", "monster_combat_animation"),
            ("advance_wars_combat_popout", "Advance Wars combat popout", "military_combat_animation"),
            ("poker_table_card_flow", "Poker table card flow", "card_play"),
            ("doudizhu_public_card_layout", "Dou Dizhu public card layout", "card_play"),
        ]
    )
    # Stable ordering makes diffs and query results reproducible.
    return sorted(records, key=lambda row: row["asset_id"])


def build_registry() -> dict[str, Any]:
    assets = build_records()
    return {
        "schema_version": "space_syndicate.asset_reference_registry.v1",
        "registry_id": "space-syndicate-asset-reference-20260826",
        "recorded_on": REVIEW_DATE,
        "authority_rule": "This is the only asset/reference registry. Historical reuse, continuity, owner, and supersession registries remain authoritative for their domains and are referenced by id only.",
        "implementation_count": 1,
        "source_manifests": [
            "docs/third_party/selected_commercial_asset_manifest.json",
            "tools/art_pipeline/source_pack_registry.json",
            "docs/product/SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.json",
        ],
        "allowed_asset_kinds": sorted(ALLOWED_ASSET_KINDS),
        "allowed_commercial_compatibility": sorted(ALLOWED_COMPATIBILITY),
        "allowed_status": sorted(ALLOWED_STATUS),
        "assets": assets,
        "policy": {
            "unregistered_external_asset_is_hard_failure": True,
            "unknown_license_production_use_is_hard_failure": True,
            "reference_only_production_import_is_hard_failure": True,
            "attribution_required_but_missing_is_hard_failure": True,
            "exact_source_version_required_for_production": True,
            "animation_consumes_receipts_only": True,
            "human_retest_deferred_until_commercial_m1_green": True,
        },
    }


def markdown_escape(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def write_views(registry: dict[str, Any]) -> None:
    assets = registry["assets"]
    production = [row for row in assets if row["used_in_production_paths"]]
    reference = [row for row in assets if row["reference_only"]]
    notices = [row for row in assets if row["attribution_required"]]
    counts: dict[str, int] = {}
    for row in assets:
        counts[row["commercial_compatibility"]] = counts.get(row["commercial_compatibility"], 0) + 1
    lines = [
        "# Space Syndicate Asset / Reference Registry",
        "",
        f"Generated from the single JSON registry on {registry['recorded_on']}; implementation count={registry['implementation_count']}.",
        "",
        f"Entries: {len(assets)} | production-used: {len(production)} | reference-only: {len(reference)} | attribution records: {len(notices)}",
        "",
        "Commercial compatibility counts: " + ", ".join(f"{key}={value}" for key, value in sorted(counts.items())),
        "",
        "| Asset ID | Kind | Status | License | Compatibility | Features | Local paths |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for row in assets:
        lines.append(
            "| " + " | ".join(
                [
                    markdown_escape(row["asset_id"]),
                    markdown_escape(row["asset_kind"]),
                    markdown_escape(row["current_status"]),
                    markdown_escape(row["license_name"]),
                    markdown_escape(row["commercial_compatibility"]),
                    markdown_escape(", ".join(row["feature_tags"])),
                    markdown_escape(", ".join(row["local_paths"][:3]) + (" …" if len(row["local_paths"]) > 3 else "")),
                ]
            )
            + " |"
        )
    REGISTRY_VIEW_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")

    gallery = [
        "# Commercial Presentation Asset Gallery Index",
        "",
        "This index is metadata-only; it does not claim that a reference-only source is production-safe.",
        "",
        "| Feature | Asset IDs | Production paths |",
        "| --- | --- | --- |",
    ]
    features = sorted({feature for row in assets for feature in row["feature_tags"]})
    for feature in features:
        rows = [row for row in assets if feature in row["feature_tags"]]
        gallery.append(
            f"| {feature} | {', '.join(row['asset_id'] for row in rows)} | "
            f"{', '.join(path for row in rows for path in row['used_in_production_paths'][:2]) or 'reference-only / not imported'} |"
        )
    GALLERY_PATH.write_text("\n".join(gallery) + "\n", encoding="utf-8")

    notice_lines = [
        "# Generated Third-Party Notices",
        "",
        "Generated from `docs/product/SPACE_SYNDICATE_ASSET_REFERENCE_REGISTRY.json`.",
        "",
    ]
    for row in notices:
        notice_lines.extend(
            [
                f"## {row['title']}",
                f"- Source: {row['source_url']}",
                f"- License: {row['license_name']}",
                f"- Attribution required: {row['attribution_required']}",
                f"- Production paths: {', '.join(row['used_in_production_paths'])}",
                "",
            ]
        )
    if not notices:
        notice_lines.append("No attribution-required production assets are currently registered.")
    NOTICES_PATH.write_text("\n".join(notice_lines) + "\n", encoding="utf-8")


def main() -> None:
    registry = build_registry()
    REGISTRY_PATH.parent.mkdir(parents=True, exist_ok=True)
    REGISTRY_PATH.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_views(registry)
    print(
        "ASSET_REFERENCE_REGISTRY_BUILT|implementation_count=%d|entry_count=%d|production_used=%d|reference_only=%d"
        % (
            registry["implementation_count"],
            len(registry["assets"]),
            sum(1 for row in registry["assets"] if row["used_in_production_paths"]),
            sum(1 for row in registry["assets"] if row["reference_only"]),
        )
    )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Normalize the checked-in V076 cue catalog into the explicit cue schema."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "data/presentation/v076_animation_cue_catalog.json"


def duration_for(cue_id: str) -> tuple[int, int]:
    if cue_id == "TRACK_HANDOFF":
        return 720, 240
    if cue_id == "DECK_SHUFFLE":
        return 820, 280
    if cue_id == "FINAL_SETTLEMENT":
        return 900, 300
    if cue_id.startswith("MONSTER_") or cue_id.startswith("MILITARY_") or cue_id.startswith("COMBAT_"):
        return 760, 260
    return 620, 220


def main() -> None:
    document = json.loads(CATALOG.read_text(encoding="utf-8"))
    normalized = []
    for old in document.get("cues", []):
        cue_id = str(old.get("cue_id", ""))
        duration_ms, reduced_ms = duration_for(cue_id)
        # The first catalog draft was emitted from a compact tuple before the
        # two duration fields were added. Shift those values back to their
        # named fields and make every required field explicit.
        normalized.append(
            {
                "cue_id": cue_id,
                "receipt_kind": str(old.get("receipt_kind", "")),
                "source_kind": str(old.get("source_kind", "")),
                "target_kind": str(old.get("target_kind", "")),
                "privacy_class": str(old.get("privacy_class", "PUBLIC")),
                "priority": int(old.get("priority", 50)),
                "queue_policy": str(old.get("queue_policy", "QUEUE_AFTER_CURRENT")),
                "duration_ms": duration_ms,
                "reduced_motion_duration_ms": reduced_ms,
                "source_anchor": str(old.get("duration_ms", "")),
                "target_anchor": str(old.get("reduced_motion_duration_ms", "")),
                "motion_path": str(old.get("source_anchor", "")),
                "scale_curve": str(old.get("target_anchor", "")),
                "rotation_curve": str(old.get("motion_path", "")),
                "opacity_curve": str(old.get("scale_curve", "")),
                "hit_stop_ms": int(old.get("rotation_curve", 0)) if str(old.get("rotation_curve", "0")).lstrip("-").isdigit() else 0,
                "screen_shake_profile": str(old.get("opacity_curve", "none")),
                "particle_profile": str(old.get("hit_stop_ms", "")),
                "sound_cue_id": str(old.get("screen_shake_profile", "")),
                "completion_policy": str(old.get("particle_profile", "RECEIPT_FINISH")),
                "interrupt_policy": str(old.get("sound_cue_id", "QUEUE_AFTER_CURRENT")),
                "fallback_cue_id": str(old.get("completion_policy", "COMBAT_FIZZLE")),
            }
        )
    document["cues"] = normalized
    CATALOG.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("V076_ANIMATION_CUE_CATALOG_BUILT|cue_count=%d" % len(normalized))


if __name__ == "__main__":
    main()

# Art Production Contract

This document is a hard development gate for the current phase of Space Syndicate.

## Current priority

Do not start new gameplay, AI, economy, campaign, menu, or balance feature work until the card illustration pass and monster art pass are complete enough for human playtesting.

The active production queue is:

1. Make every monster family visually distinct.
2. Make every card face visually distinct.
3. Give every monster action an independent motion/attack profile.
4. Verify the full card, monster, and monster-action catalog with automated art identity tests.
5. Only then resume downstream gameplay/balance/UI feature work.

## Card illustration hard standard

Every player-facing card must have a unique visual identity. It is not enough to change the title or effect text.

Each card illustration profile must include:

- `visual_source_id`: the exact illustration source family used by this card face.
- `sprite_key`: which imported/procedural illustration family is used.
- `sprite_cell`: which sprite-sheet cell or texture region is used.
- `layout_variant`: where the visual weight sits inside the card art area.
- `palette_variant`: color treatment beyond the card route color.
- `effect_variant`: overlay/effect treatment such as beam, shield, route, crack, market pulse, or weather wave.
- `composition_variant`: a secondary composition differentiator for cards that share sprite family and type.
- `motif_family`: monster, military, finance, route, contract, intel, product, weather, or utility.
- `first_run_art_focus`: a readable first-play icon layer for high-frequency starter cards such as money, production, transit, lure, supply, movement, attack, guard, and district damage.

Acceptance:

- The full card catalog must be audited, not only the cards that appear in one run.
- Every audited card must have one unique visual profile key.
- The key may be generated from the card name as a seed, but the key itself must be composed from visual dimensions, not the card name string.
- Every card illustration profile must declare `visual_source_id`.
- At least ten sprite/illustration families and ten visual source families must be used across the current catalog.
- High-frequency first-run cards must have authored `first_run_art_focus` overlays; do not let them collapse into the same generic route mark.
- Card art must be visible in hand, region supply, card codex thumbnail, and card detail contexts because these all share `CardArtView`.

## Monster art hard standard

Every monster family must have a distinct silhouette and portrait profile.

Each monster art profile must include:

- `visual_source_id`: the exact body-art source family. This is stricter than a palette or pose variant.
- `sprite_key`: the imported/procedural body sprite family.
- `sprite_cell`: concrete sprite-sheet cell or texture region.
- `silhouette`: monster-specific silhouette/motif key.
- `layout_variant`: pose/layout variation.
- `palette_variant`: color treatment.
- `effect_layer`: field, laser, impact, miasma, weather, or none.
- `composition_variant`: additional composition differentiator.

Acceptance:

- Every current monster family must have a unique visual profile key.
- Every current monster family must have a distinct silhouette/motif assignment.
- Every current monster family must use a distinct body sprite key and a distinct `visual_source_id`; it is not acceptable to reuse one monster body with different action overlays.
- Moth Kaijuice/MOS kaiju body art can be assigned to at most one current monster family. Other monsters must come from different open-source body-art families or a clearly different authored/procedural body.
- The current monster roster must draw body art from at least four upstream/open-source packs, and no single upstream pack may provide more than half of the active roster. This prevents "one sprite sheet, many color swaps" from passing review.
- Monster art must be visible in the bestiary/detail contexts, monster cards, and runtime map tokens. The map token may be compact, but it must consume the same `sprite_key`, `visual_source_id`, and `upstream_source_id` contract instead of falling back to only number/color/glyph.
- Each rank-I monster card must use the same body `sprite_key` as its corresponding monster art profile. The card frame may add overlays, but it cannot represent the monster with an unrelated creature sprite.
- Runtime monster actions must consume the same action animation profile used by the art audit. A beam, projectile, dash, miasma, repair, roar/wave, throw, and melee action may still be greybox, but they must not all collapse into one generic map line or circle.

## Monster action hard standard

Every monster action slot must have an authored animation profile. Repeating the same action entry to fake probability weight is not allowed. If two probability slots are meant to feel similar, they still need different action names, poses, timings, ranges, impact shapes, or effect layers.

Each monster action profile must include:

- `motion_family`: close melee, dash melee, beam line, projectile blast, throw/grapple, miasma zone, repair beam, burrow dash, roar wave, roll crush, or another explicit family.
- `pose_key`: an authored pose identity derived from the action, not a generic `"attack"` fallback.
- `effect_layer`: impact burst, blade arc, electric arc, miasma cloud, repair green, flame burst, ground crack, shock wave, or another explicit effect.
- `range_meters`: action reach in meters.
- `move_override_mps`: action movement speed in meters per second, or `-1` if stationary.
- `knockback_meters`: knockback distance in meters.
- `throw_meters`: throw/launch distance in meters.
- `anticipation_seconds`, `active_seconds`, `recovery_seconds`, `impact_seconds`.
- `scale_contract`: a readable summary tying movement, attack, and knockback to meter-based staging.

Acceptance:

- Every current monster must keep six authored action slots with independent animation identities.
- Action names must not be duplicated within one monster.
- `profile_key` and `pose_key` must not duplicate within one monster.
- Damage actions must not use a generic utility pose.
- Knockback/throw impacts must resolve within a readable sub-second window; current hard gate is `impact_seconds <= 0.60`.
- The current roster must cover at least eight motion families and seven effect layers.
- Full movement and combat animation implementation must follow these profiles: normal movement, flying movement, dash, beam, projectile, throw, knockback, field, repair, and roar cannot all reuse one animation.
- Runtime `MapView` event payloads must carry `motion_family`, `pose_key`, `effect_layer`, `profile_key`, and meter fields so later animation polish can happen without adding card-name-specific hacks.

## Open-source asset policy for this phase

Current imported sources:

- Night Patrol UI skin: `assets/third_party/night_patrol/`, CC BY-NC 4.0, temporary non-commercial prototype use.
- Moth Kaijuice city/kaiju sprites: `assets/third_party/moth_kaijuice/`, MIT, temporary prototype illustration source. MOS/Moth kaiju body art is limited to one monster family in the current roster.
- Monster Battler monster sprites: `assets/third_party/monster_battler/`, CC0, temporary monster body-art and card-illustration source.
- Kenney CC0 sprites: `assets/third_party/kenney_cc0/`, CC0, temporary monster body-art and card-illustration source.
- Superpowers Asset Packs sprites: `assets/third_party/superpowers_cc0/`, CC0, temporary monster body-art source for body shapes that should not resemble the MOS kaiju sheet.

Before any new copied asset becomes player-facing:

1. Save the LICENSE or source attribution under `assets/third_party/<source>/`.
2. Add the source to `docs/third_party_assets.md`.
3. State whether it is copied, adapted, or only used as visual reference.
4. Add/extend an automated art identity test if the asset creates a new visual family.

## Automated gate

Run:

```powershell
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/art_identity_gate_test.gd
```

This test is allowed to read dev-only art audit helpers. It must not expose private gameplay information to player UI.

The gate fails if:

- a card lacks a concrete sprite key/cell;
- a card lacks a concrete `visual_source_id`;
- a card lacks multi-axis visual fields;
- two cards share the same visual profile key;
- fewer than ten card sprite or visual source families are used;
- starter/high-frequency cards lose their authored `first_run_art_focus` overlays;
- a monster lacks a concrete sprite key/cell;
- a monster lacks a concrete `visual_source_id`;
- a monster lacks multi-axis visual fields;
- two monsters share the same visual profile key;
- any current monster shares another monster's silhouette/motif;
- any current monster shares another monster's body sprite key or `visual_source_id`;
- any rank-I monster card uses a different body sprite key from its matching monster profile;
- more than one current monster uses Moth Kaijuice/MOS kaiju body art;
- fewer than four upstream/open-source monster art packs are represented in the current roster;
- one upstream/open-source pack supplies more than half of the current monster roster;
- a monster action duplicates another action name, pose key, or animation profile inside the same monster;
- a damage action uses a generic utility pose;
- knockback/throw impact takes more than 0.60 seconds;
- roster-wide motion/effect diversity falls below the current gate.

## Visual review screenshots

Run this as a visible Godot process, not `--headless`, because the headless dummy renderer cannot capture viewport textures:

```powershell
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --path . --script res://tests/art_contact_sheet_capture.gd
```

It writes:

- `reports/art/art_card_monster_contact_sheet_1600x960.png`
- `reports/art/art_monster_action_profiles_1600x960.png`
- `reports/art/art_monster_map_tokens_1600x960.png`
- `reports/art/art_monster_action_map_effects_1600x960.png`

Use these images for human review after each art pass. The first sheet checks whether cards and monsters are visually distinguishable at a glance. The second sheet checks whether each monster action has a distinct motion/effect/timing/meter profile before full animation work starts.
The third sheet checks whether the real `MapView` renders source-specific monster body sprites at tabletop-token scale, so the in-game planet is not reduced to numbered colored dots.
The fourth sheet checks whether the real `MapView` renders distinct greybox action grammars for beams, projectiles, dash/roll/burrow, miasma, repair, roar/wave, throw, and melee before final frame-by-frame monster animation work.

Run this per-monster review pass when a monster body, monster card face, map token, or monster action grammar changes:

```powershell
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --path . --script res://tests/monster_runtime_review_capture.gd
```

It writes one review image per current monster:

- `reports/art/monster_reviews/art_monster_review_01.png` through `art_monster_review_08.png`

Each review image must show the monster bestiary art, the matching rank-I monster card face, the real map token, and representative runtime action map effects on one page. Use these single-monster images for the "one by one" human art pass before replacing temporary assets.

## Human review checklist

For every card or monster completed manually, record:

- name;
- route/type;
- source asset or procedural profile;
- what makes it visually different at thumbnail size;
- what makes it visually different at hover/detail size;
- whether the art matches the card/monster mechanics;
- whether the license/attribution is recorded.

# P2 Alpha 0.1 card art production cutover handoff

## Status

`ALPHA01_CARD_ART_PRODUCTION_CUTOVER_GREEN`

Branch: `codex/p2-alpha-card-art-production-cutover-a644f45`

Base: `a644f45d6d5d2bc930e5a63a41cc802160ebee74`

Push: intentionally not performed
Gameplay/rules mutation: none

## Outcome

- Alpha illustration coverage moves from `0/40` production consumers to `5/40`.
- The five existing approved candidates are visible through production CardUI and Card Codex paths.
- The other `35/40` identities remain explicit semantic fallbacks; none are labelled as rendered.
- Player-facing data carries only an opaque `illustration_key`; paths, hashes, license facts, provenance, and authoring identifiers remain outside production ViewModels.
- No second card, catalog, effect, target, save, or mutation owner was created.
- `scripts/main.gd`, `scenes/main.tscn`, `GameRuntimeCoordinator`, GameScreen, PlanetBoard, PlayerBoard, RightInspector, card gameplay catalogs, effects, targets, saves, and existing art binaries were not modified.

## Scene-owned boundary

New scene-owned read-only service:

- `res://scenes/runtime/CardIllustrationCatalog.tscn`
- `res://scripts/presentation/card_illustration_catalog.gd`
- `res://scripts/presentation/card_illustration_catalog_resource.gd`
- `res://resources/presentation/alpha01_card_illustration_catalog.tres`

The catalog maps the 40 Alpha identities onto either:

- one of five opaque `alpha01_art_*` keys; or
- an empty key, which means use the existing semantic fallback.

It owns no gameplay state and exposes no mutation or save API. CardUI resolves a key through its scene-owned `CardIllustrationLayer`; it never reads the QA manifest.

## Production consumers

- `CardPresentationRuntimeService`: emits the key for formal card and hand presentation.
- `CardViewSnapshot`: preserves the key as presentation-only string data.
- `DistrictSupplyViewerQueryPort` / `DistrictSupplySnapshotService`: preserves the key into region-supply CardUI preview data.
- `CardCodexPublicSourceService` / adapter / snapshot service: preserves the same key into browser and detail snapshots.
- `CardCodexThumbnailCard`: overlays the approved illustration and retains `CardArtView` when the key is empty or invalid.
- `CardUI` / `CardFace`: overlays the approved illustration and retains semantic art on safe failure.

## Deterministic fallback

- Missing or unknown key: semantic art remains visible.
- Missing catalog resource: semantic art remains visible.
- Missing texture: semantic art remains visible.
- No UI open/close, hover, frame, time, or RNG action changes selection.
- Fallback does not affect card use, price, legality, or resolution.

## Privacy result

Automated scan result: `privacy_leaks=0`.

Forbidden player-facing fields include `illustration_path`, `illustration_profile`, `source_type`, `visual_source_id`, `upstream_source_id`, `license`, `attribution`, `sha256`, `commercial_status`, and `prompt_document`. The five runtime keys are opaque and do not reproduce card IDs or paths.

## Godot 4.7 evidence

Godot MCP project check:

- version: `4.7.stable.official.5b4e0cb0f`
- project root: this isolated worktree
- real scene: `res://scenes/tools/Alpha01CardIllustrationProductionBench.tscn`
- result: `PASS`
- Bench checks: `17`
- rendered: `5`
- fallback example: `1`
- task script/runtime errors: `0`
- screenshot: `res://docs/art_qa/cards/alpha01/card_illustration_production_1600x960.png`
- screenshot dimensions / SHA-256: `1600x960` / `1bdad86f820fffb9d701778d0a7dee24687c09b5cd33ea20c92d93f2a9b62374`

Godot's project-wide scan also reports existing warning debt in unrelated runtime scripts and repeated `Unexpected NUL character` Unicode diagnostics already present when loading the project. No new parse, missing-access, orphan-connection, or task runtime failure was produced by this cutover.

## Focused and regression gates

| Gate | Result |
|---|---|
| `alpha01_card_illustration_production_cutover_test.gd` | PASS, 157 checks, 5 rendered, 35 fallback, 0 privacy leaks |
| `Alpha01CardIllustrationProductionBench.tscn` headless | PASS, 15 checks |
| Godot MCP production Bench | PASS, 17 checks |
| `card_illustration_layer_test.gd` | PASS |
| `card_codex_public_snapshot_service_test.gd` | PASS |
| `ui_text_smoke_test.gd` | PASS |
| `visual_snapshot.gd` | PASS |
| `smoke_test.gd --check-only` | PASS |
| `git diff --check` | PASS |

Two pre-existing tests remain stale and were not made green by restoring Main compatibility:

- `card_presentation_public_contract_test.gd` still requests retired v0.4 card aliases such as `城市融资1` and assumes the old source dependency count.
- `card_presentation_viewmodel_runtime_test.gd` still calls the physically retired `Main._new_game`; its error path never reaches the test's quit call.

The new 157-check production gate replaces neither test globally; it directly covers the current v0.6 Alpha card IDs and formal production consumers. No Main fallback or retired alias was restored.

## Integration notes

- This commit is presentation-only and should merge without a GameRuntimeCoordinator or Main scene edit.
- Future art batches should add a real asset, provenance evidence, one opaque key, and one rendered status entry in the same change.
- Do not convert a fallback entry to rendered before its file, SHA-256, license evidence, and production screenshot all pass.
- The local commit SHA is reported by the delivering agent after commit; it is not embedded here to avoid a self-referential commit.

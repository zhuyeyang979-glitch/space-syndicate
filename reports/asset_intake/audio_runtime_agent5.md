# Commercial Audio Runtime - Agent 5

## Result

The commercial audio contracts now have presentation-only runtime consumers without direct vendor paths or a second asset catalog.

- Commercial canonical events: 17
- Preserved legacy underscore aliases: 16
- SFX players: 1
- Music players: 2
- Music crossfade: 1.5 seconds
- Public event resource-path exposure: 0
- Rules RNG draws: 0

## Event Routing

`AudioEventRegistry` loads the existing event router and merges only the safe fields from `commercial_audio_event_map.json`: `asset_key`, `volume_db`, and `loop`. The registry never copies `stream_path` into its state or public definitions.

All original underscore hooks remain aliases. Where the selected commercial set has no semantically correct sound, the dot-form canonical event remains silent. For example, `monster_spawn` resolves to `monster.spawn` without pretending that `monster.attack` is a spawn sound.

`AudioEventBus` preserves the requested legacy ID, adds the canonical ID, and emits the three safe presentation fields. Caller payload path keys and resource-path values are recursively removed or redacted. Unknown events remain silent and empty-keyed.

## SFX Service

`CommercialAudioPresentationService` owns one editable `AudioStreamPlayer`. It consumes only canonical event metadata and resolves the stream through `CardIllustrationCatalogResource.resource_for_asset_key()` plus `asset_kind_for_key()`.

There is no vendor path list in the service. A missing Catalog, missing key, wrong resource kind, or loop mismatch returns `false` with a typed rejection reason and no script error. Each event has one fixed file and no RNG selection.

## Music Controller

`CommercialMusicPresentationController` owns two editable `AudioStreamPlayer` nodes and performs a 1.5-second equal-power cosine/sine gain transition between them. It accepts only four public presentation states or their four stable music keys.

The controller has no Dictionary snapshot input and therefore cannot inspect arbitrary hidden gameplay payloads. Music state is not saved and has no gameplay or RNG effect. Repeated requests for the active key do not restart or randomize playback.

## Verification

| Gate | Result |
| --- | --- |
| Commercial audio runtime service | 232/232 PASS, clean verbose exit |
| Commercial audio asset contract | 361/361 PASS |
| Vertical Slice showcase | PASS |
| Focused visual-event smoke | 38/38 PASS |
| Commercial art architecture preflight | 286/287; sole failure is the concurrently changed Planet ring/translucency characterization |

The architecture preflight's single failure does not touch audio. This lane did not edit Planet files or broaden its write scope.

No full Smoke or Formal run was started.

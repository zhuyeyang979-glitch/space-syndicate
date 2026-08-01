# Presentation Catalog And Runtime Boundary Audit

## Result

This audit is complete and implementation has not started. It used no network access, performed no asset search, downloaded no files, and edited no production or catalog files.

The current production ruleset is **V0.6**. The V0.7 semantic kernel is present on `main`, but no V0.7 Player presentation or runtime is connected to production. `FULL_V0_7_RUNTIME_CUTOVER=false`.

## Canonical Owner Decision

The existing `CardIllustrationCatalogResource` is the only suitable cross-domain presentation asset Owner. It already maps semantic card IDs to opaque presentation keys and maps those keys to local Godot Resources. It is read-only, presentation-only, and already consumed by `CardPresentationRuntimeService`, `CardCodexPublicSourceService`, and `CardIllustrationLayer`.

Second-phase implementation must extend this resource and its `CardIllustrationCatalog` service **in place**. It must not create `PresentationAssetCatalog.gd`, a second catalog scene, or an autoload.

The existing card API remains compatible:

- `presentation_key_for_card`
- `presentation_key_for_commodity_id`
- `presentation_key_for_commodity_family`
- `texture_for_key`
- `presentation_profile_for_key`
- `is_authored_key`
- `validation_report`

The same resource should add generic, typed access such as `resource_for_asset_key`, `asset_kind_for_key`, `asset_scope_for_key`, `has_asset_key`, and `all_asset_keys`. Existing `texture_for_key` should delegate to that resolver for texture rows.

## Other Existing Owners

`Alpha01ContentManifestResource` owns gameplay content selection. It must not gain third-party textures, models, audio, fonts, paths, or license metadata.

`AudioEventRegistry` owns event routing. It may map event IDs to stable catalog keys, but it must not become a second resource-path catalog. Its current map is silent and contains legacy underscore event IDs, so compatibility aliases must remain while canonical dot event IDs are added.

`RolePortraitCatalog` is a temporary, path-based, role-only resolver. The task explicitly preserves existing portraits, so this resolver remains scoped and unchanged.

`GameTheme` is a consumer, not an asset Owner. It is already referenced by 105 scenes and is the production-safe target for the selected fonts and common UI skin.

The selected commercial asset manifest is license/provenance evidence only. Runtime code must never load it as gameplay or presentation authority.

## Stable Key Routing

The machine-readable report contains 54 primary stable keys and four supporting key groups. Every row resolves through `CardIllustrationCatalogResource`.

| Namespace | Routing owner | Production boundary |
| --- | --- | --- |
| `ui.*` | `GameTheme` | Production-safe global presentation |
| `icon.asset.*` | typed color presenter | Numeric six-color state remains Review/Reference-only until a V0.7 projection exists |
| `card.frame.*` | `CardFace` | Production-safe for existing normal, commodity, and bound-action typed pools |
| `card.back.normal` | Review card pile presenter | Reference-only until the V0.7 DBG projection exists |
| `model.facility.*` | Planet visual proxy | Production-safe from existing public facility facts only |
| `model.monster.*` | Planet visual proxy | Production-safe from existing public monster facts only |
| `model.military.*` | Planet visual proxy | Production-safe from existing public military facts only |
| `model.shipping.*` | Planet visual proxy | Decorative only; never a route Owner |
| `audio.*` | `AudioEventRegistry` | UI, public event, or committed receipt driven; V0.7 lock/merge/asset refresh remain Reference-only |
| `music.*` | presentation music controller | Public phase/state only; no hidden information |
| `font.*` | theme locale resolver | SC default, JP for Japanese locale, Oxanium for Latin titles and numbers only |

Supporting namespaces are `icon.board.*`, `icon.input.*`, `vfx.*`, `shader.planet.*`, `material.*`, and `environment.*`. Third-party filenames remain confined to the canonical `.tres` and license evidence; Core, AI, Player DTOs, Save, and RNG use stable keys or no resource identity at all.

## Production-Safe Connections

The following may connect to current production after focused visual and architecture tests:

1. Common panels, buttons, popup skin, locale fonts, and Credits presentation.
2. Normal, commodity, and bound-action card frames using existing typed pool facts.
3. Hover, keyboard/gamepad focus, click selection, and visual-only drag inside the current `PlayerCardDock`.
4. Opaque planet, day/night material, background, camera zoom, backside presentation culling, and orbit-decoration removal.
5. Facility, monster, and military visual proxies driven only by existing public entity snapshots.
6. Decorative shipping models that never become route authority.
7. UI sound, committed/public event sound, and music switched only from public state.

The production card interaction implementation must stay in `PlayerCardDock`. The retired `HandRack` already has drag code, but reconnecting it would violate the accepted Alpha 0.4 single-surface boundary. Drag may animate and emit presentation feedback; it must not submit a card, mutate a queue, consume RNG, or bypass `game_action_offer_requested` and the Action Spine.

## Review Or Reference Only

These surfaces cannot connect to production in this task:

- Six-color current/6, reserved values, authored costs, shortage messages, ratios, and settlement values.
- Unified card track.
- Normal DBG draw and discard piles.
- Five-action local queue ordering.
- Asset reservation and lock state.
- Anonymous resolution queue.

The repository has a non-visual V0.7 reference semantics bench at `res://scenes/tools/SharedCommodityTrackThreeLayerSemanticsBench.tscn`. It imports `tests/support` reference code and is not a production projection. The new `CommercialArtIntegrationReview` scene is therefore the correct home for these visuals. It must use detached Review fixtures, create no Session or Save, and perform no RNG draw.

## Planet Findings

The production composition is `GameScreen -> PlanetBoard -> PlanetMapView`. `PlanetMapView` is a sceneized 2D `Control` layer stack and consumes public map and solar presentation data.

The current `PlanetGlobeBackdrop` is visibly translucent because its ocean alpha is below 1. It also calls `_draw_table_ring`, and `PlanetMapView.tscn` instantiates `OrbitLayer/PlanetOrbitGuide`. Those are the exact presentation elements that must be replaced or removed for `PLANET_OPAQUE=true` and `OUTER_ORBIT_DECORATION_COUNT=0`.

Backside marker hiding is not currently a 3D occlusion feature. A presentation proxy must classify camera-facing versus backside hemisphere and hide backside facilities/models without changing region IDs, targets, facilities, routes, or Save state. The existing `PlanetSolarCameraController` already documents `owns_save_state=false` and consumes a strict public snapshot, so zoom/rotation remains in this presentation boundary.

## Credits And Audio Findings

No player-facing Credits, Third-Party Assets, Licenses, Music, or Fonts surface currently exists in `MenuRootLobby` or `MenuOverlay`. A read-only menu route can be added through the existing menu lifecycle controller without editing `main.gd`.

`AudioEventRegistry` currently maps legacy events to `mode` and `category` only. Second phase should add `asset_key`, volume, and loop policy while keeping the actual `AudioStream` in the canonical catalog. Event aliases must preserve existing tests such as `monster_attack`, while canonical prompt events use dot IDs such as `monster.attack`.

## Second-Phase File Ownership

Hot files must remain single-writer groups:

- Canonical catalog: `card_illustration_catalog_resource.gd`, `card_illustration_catalog.gd`, the existing catalog `.tres`, and its scene.
- Card presentation: `CardFace`, `CardIllustrationLayer`, and `PlayerCardDock` files.
- Planet presentation: `PlanetBoard`, `PlanetMapView`, globe backdrop, orbit guide, and solar camera files.
- Theme/menu: `GameTheme`, `MenuRootLobby`, `MenuOverlay`, and the menu lifecycle controller.
- Audio: the event map, registry, and bus.
- Review: the new Commercial Art Review scene and its tool script.

Do not modify `scripts/main.gd`, `scenes/main.tscn`, Alpha content manifests, V0.7 semantic kernel files, the frozen constitution, or the Player Card Dock projection schema for this art integration.

## Required Regression Set

Run the new architecture preflight plus the existing card illustration, illustration layer, Player Card Dock, planet solar/map identity, visual event, menu lifecycle, main composition, and V0.7 aggregate tests listed in the JSON report. Finish with the correctly separated engine `--check-only` invocation. Do not run a Formal or full Smoke.

# Commercial Art Real Capture and First Visual QA

## Status

`BLOCKED_BY_FIRST_ROUND_VISUAL_QA`

The canonical lightweight, Catalog, and real Review-scene preflights are GREEN. A real Windows Vulkan/Forward+ run produced all 15 requested PNG files from the Godot SubViewport, and the capture driver validated dimensions, nonempty pixels, color/luminance variance, PNG reload, bytes, and SHA-256 for every file.

The captures are real and retained, but first-round human visual QA is not GREEN. Four captures pass their visual purpose; eleven expose presentation defects that must be repaired before these images can be accepted as final commercial evidence.

## Preflight And Capture

- Godot: `4.7.stable.official.5b4e0cb0f`
- Catalog contract: `988/988`, `97/97` stable keys
- Lightweight capture plan: `15/15`
- Screenshot Catalog binding: `42/42`, missing `0`
- Credits sections: `4/4`, canonical entries `15`, Game-icons attribution ready
- Review preflight: GREEN, Credits placeholders `0`
- Real renderer: Windows, Vulkan 1.4.349, Forward+, AMD Radeon(TM) 890M Graphics
- Automated PNG validation: `15/15`
- Total screenshot bytes: `6,200,277`
- Duplicate SHA-256 count: `0`
- Generated placeholder image count: `0`
- Godot process count after cleanup: `0`

The initial `--headless` characterization selected Godot's dummy renderer, so all SubViewport readbacks were empty. It wrote zero PNG files. The same unmodified driver was then run through the real Windows display backend and completed with exit code `0`.

## Visual Findings

1. **Card-back placeholder copy:** six captures visibly include `ART / PATTERN PLACEHOLDER`. The screenshot files themselves are not placeholders, but the presented card-back copy is unfinished and cannot be accepted as final commercial art.
2. **Hover/drag overlap:** the transformed preview tile covers the `Interaction states` heading in both interaction captures. The states are visibly distinct, but their layout is not coherent.
3. **Model framing:** all 17 Catalog-bound model previews instantiate, yet the facilities, monsters, military tiers, and ships occupy only a few pixels in their tiles. The three model-group captures cannot support silhouette, material, tier, or mapping review.
4. **Full-table composition:** both nominal full-table captures show only the upper scroll fold, not a deliberate overview of the complete review surface.

Planet day, planet night, planet zoom, and Credits pass first-round visual inspection. The planet is opaque, the day/night states are distinct, close zoom is readable, and no outer orbit or visible backside entity appears. Credits visibly expose all four canonical sections and the mandatory Game-icons attribution identities.

## Capture Ledger

| Capture | Size | Bytes | SHA-256 | Visual |
|---|---:|---:|---|---|
| `commercial_art_full_table_1920.png` | 1920x1080 | 392461 | `50b5fd4b573388e68b04b1ae42e3ffdf249c15f2bf2435b5e39a09c6be1f36b2` | FAIL |
| `commercial_art_full_table_1366.png` | 1366x768 | 195001 | `edd2680aa846272cd8a21416b0f03e0a4280792e166253f020283234a06c6267` | FAIL |
| `commercial_art_six_color_assets.png` | 1920x1080 | 392382 | `77542e346b38ff77347183dba016c1786c620e6a7eb5eba0e3ecc53d01376aa0` | FAIL |
| `commercial_art_normal_cards.png` | 1920x1080 | 617711 | `4fa555adadc81c5af24052d963bf73ede3075fb6ce9cc8da967d30954abb9a6b` | FAIL |
| `commercial_art_commodity_cards.png` | 1920x1080 | 611969 | `9543c9cf9f179483988926f3ee32d90eeefd84a2bb79e0c39426b9c89ba2e0de` | FAIL |
| `commercial_art_bound_actions.png` | 1920x1080 | 622300 | `3c69a755763ef83d11ad14f68fad4051ffd6c385b21961affcdb1d547fccbefe` | FAIL |
| `commercial_art_hand_hover.png` | 1920x1080 | 585043 | `e5e49d2c83f29b10e8049f51246ff14207c489346b0d38b121bb4d8ef13b43d1` | FAIL |
| `commercial_art_hand_drag.png` | 1920x1080 | 589516 | `6a47739b8e034c2ce0cce4cc99ea44c727057bf094f54d41ec7cf645321ee333` | FAIL |
| `commercial_art_planet_day.png` | 1920x1080 | 563391 | `3beec7b9d37a5b9fc57c65151f5fe59c53c4e3e5de67c928489be0c0c93cc029` | PASS |
| `commercial_art_planet_night.png` | 1920x1080 | 559309 | `c015bc0dbe0d9b14541d7c71f0dd8baa7e6289b14371dfcc1155896afde6a1f0` | PASS |
| `commercial_art_planet_zoom.png` | 1920x1080 | 491390 | `5957c9cef42ef50134cc365040ca14929034b0f499137e2ca4b930d39b86b43a` | PASS |
| `commercial_art_facilities.png` | 1920x1080 | 120977 | `f57490735bcc0397377f23a55d9f36e14506fe0999ec80369ac3d74931812e54` | FAIL |
| `commercial_art_monsters.png` | 1920x1080 | 137782 | `45ef73889b60b06b2c585b9385e400165cd410e07e950343273caae2a53d9566` | FAIL |
| `commercial_art_military.png` | 1920x1080 | 160354 | `14e1ecf34af314c21b9d408041df4c06bb8a194590c7d528388a8e7bba7c3d8b` | FAIL |
| `commercial_art_credits.png` | 1920x1080 | 160691 | `2515963a7bee50d5eb3b632c6989384db515245cb9aa92a8f85665036bc8f5a9` | PASS |

Machine-readable per-capture findings are in `reports/asset_intake/presentation_capture_final_agent.json`.

## Boundary

This capture lane edited only `docs/art_qa/commercial_art/**` and the two final capture reports. It did not edit the Review scene, driver, Catalog, production files, manifest, notices, or Credits data. It did not run Smoke or Formal.

The Review/capture owner must repair the high-severity findings and rerun all 15 captures. Until that rerun passes human QA, the current PNGs are truthful diagnostic evidence, not final commercial approval images.

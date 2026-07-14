# Organization Catalog Compatibility Gate Handoff

## Status

Complete and frozen at focused-test scope.

- Godot: `4.7.stable.official.5b4e0cb0f`
- `tests/asset_terminology_v06_test.gd`: `PASS | checks=1054 | failures=0`
- `git diff --check`: pass
- Test environment: isolated temporary `APPDATA` and `LOCALAPPDATA`

## Change

The asset-terminology gate no longer assumes the retired 328-card seed. It reads the authoritative metadata from `data/cards/card_runtime_catalog_v06.json`, verifies that the manifest declares 348 ranked cards, 87 named families, and 20 organization ranks, then checks that the actual records match all three values.

The existing per-card `asset_cost`/no-`mana_cost` check, player-facing legacy-term scan, Skin Lab scan, rulebook scan, and right-inspector scan remain intact. Each card now also contributes a non-empty family identity to the manifest compatibility check.

## Files

- `tests/asset_terminology_v06_test.gd`
- this handoff

No production, catalog, rulebook, historical report, development log, UI, runtime owner, or save file was changed.

## Command

```powershell
godot --headless --path . --script res://tests/asset_terminology_v06_test.gd
```

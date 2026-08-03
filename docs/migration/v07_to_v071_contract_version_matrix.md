# V0.7 to V0.7.1 Contract Versions

```text
SOURCE_RULESET_ID=v0.7
TARGET_RULESET_ID=v0.7.1
V07_SAVE_TO_V071_DIRECT_RESUME=false
V06_SAVE_TO_V071_DIRECT_RESUME=false
PRODUCTION_RUNTIME_CONNECTED=false
```

| Domain | V0.7 | V0.7.1 | State | Shape | Save | AI | Player | Migration |
| --- | --- | --- | ---: | --- | --- | --- | --- | --- |
| Unified track Core | `v07.unified_track.core_authority.v1` | `v071.unified_track.core_authority.v2` | 3 -> 4 | changed | changed | changed | changed | forbidden |
| Market color cycle | `V07MarketColorCycleState@3` | `V071MarketColorCycleState@4` | 3 -> 4 | changed | changed | changed | changed | forbidden |
| Hidden lead cycle | `V07HiddenLeadCycleState@3` | `V071HiddenLeadCycleState@4` | 3 -> 4 | changed | changed | changed | changed | forbidden |
| Personal DBG | `v07.personal_dbg.core_authority.v1` | `v071.personal_dbg.core_authority.v2` | 1 -> 2 | changed | changed | changed | changed | forbidden |
| Commodity inventory | `V07CommodityInventoryState@1` | `V071CommodityInventoryState@2` | 1 -> 2 | changed | changed | changed | changed | forbidden |
| Six-color assets | `v07.six_color_assets.core_authority.v1` | `v071.six_color_assets.core_authority.v2` | 1 -> 2 | changed | changed | changed | changed | forbidden |
| Asset cycle snapshot | `V07AssetCycleSnapshot@1` | `V071AssetCycleSnapshot@2` | 1 -> 2 | changed | changed | changed | changed | forbidden |
| Card batch | `v07.card_batch.core_authority.v1` | `v071.card_batch.core_authority.v2` | 1 -> 2 | changed | changed | changed | changed | forbidden |
| Anonymous resolution | `V07AnonymousResolutionState@1` | `V071AnonymousResolutionState@2` | 1 -> 2 | changed | changed | changed | changed | forbidden |
| AI adapter | `space_syndicate.v07...v1` | `space_syndicate.v071...v2` | 1 -> 2 | changed | n/a | changed | no | forbidden |
| Player adapter | `space_syndicate.v07...v1` | `space_syndicate.v071...v2` | 1 -> 2 | changed | n/a | no | changed | forbidden |
| Save adapter | `space_syndicate.v07.semantic_save.v1` | `space_syndicate.v071.semantic_save.v1` | 1 -> 2 | changed | changed | no | no | forbidden |
| RNG adapter | `space_syndicate.v07...v1` | `space_syndicate.v071...v1` | 1 -> 1 | changed | changed | no | no | forbidden |
| Cutover manifest | `space_syndicate.v07.atomic_cutover_manifest` | `space_syndicate.v071.atomic_cutover_manifest` | 1 -> 2 | changed | changed | changed | changed | forbidden |

No row authorizes production. Old detached V0.7 saves fail closed because the
new fields have gameplay meaning and cannot be reconstructed honestly. A future
test-only migration would require its own explicit contract; none is supplied
here.

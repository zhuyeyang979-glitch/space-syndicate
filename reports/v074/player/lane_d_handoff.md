# V0.7.4 Lane D handoff

Status: GREEN

Lane D delivers the read-only dynamic player map projection, privacy-safe Region Popup DTO, exact typed map target binding, and a searchable/collapsible/keyboard-accessible TargetRail with a fixed ten-row virtual pool.

## Integration API

- `adapt(viewer_id, map_receipt, public_facilities, legal_actions) -> Dictionary`
- `region_popup(region_id) -> Dictionary`
- `resolve_target(card_instance_id, region_id, facility_type, industry_id, mode) -> typed result`

The adapter accepts dynamic region IDs and was validated at 6, 16, and 30 regions. It projects 18 potential slots per region for factory, market, and warehouse. Target identity always includes region, facility type, industry, and BUILD_NEW / UPGRADE_OWN / REPAIR_OWN mode.

## Privacy

Warehouse capacity, ingress throughput, egress throughput, rank, public owner identity, damage, sunlight state, and occupancy are allowlisted. Stock contents, inventory by commodity, private logistics, future transport, AI plans, and rival hidden state are discarded even when supplied in source fixtures.

## Validation

- Player map projection: 22/22
- Region Popup privacy: 12/12
- Typed map target binding: 27/27
- TargetRail virtualization: 9/9
- Total focused checks: 70/70
- MCP changed scripts: 9/9
- MCP changed scenes: 2/2
- MCP Bench: 30 regions, 540 slots, `exercise_complete=true`
- MCP runtime errors: 0
- Play mode stopped cleanly on Role A endpoint 9024

Fresh import generated unrelated baseline UID/import churn and encountered the parent-lineage Godot 4.7 signal-11 import fault. None of that churn is staged. Validation resumed with an ignored stable import cache, and every owned script and scene was then loaded through the role-local MCP.

## Integration gaps

The coordinator still owns production wiring into the V0.7.4 screen and globe. This lane intentionally did not touch `V073SampleGameScreen`, `PlanetBoard`, map implementation, or runtime owners. Lane A/B final receipt field names may require a narrow integration mapping if they differ from the requested API.

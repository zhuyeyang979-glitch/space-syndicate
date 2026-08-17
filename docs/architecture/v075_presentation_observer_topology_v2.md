# V0.7.5 Presentation Observer Topology V2

`PresentationObserverTopologyV2` defines the Runtime Owner's composition-owned Presentation and telemetry observer edges for the V0.7.5 Presentation path. The authoritative signature is the source role, source signal, target role, target method, and connection flags. Godot instance IDs are used only to compare object identity inside one fixture and are not durable cross-run identity.

| Edge | Source | Target | Required | Legacy | Count |
| --- | --- | --- | --- | --- | ---: |
| EDGE_A | `V075RuntimeOwner.resolution_presented` | `CombatTelemetryBridge.consume_public_receipt` | yes | no | 1 |
| EDGE_B | `V075RuntimeOwner.combat_presentation_receipt_ready` | `V075CombatPresentationConsumer.consume_receipt` | yes | no | 1 |
| EDGE_C | `V075CombatPresentationConsumer.presentation_cue_ready` | `CombatTelemetryBridge.consume_public_cue` | yes | no | 1 |
| Retired legacy edge | `V075RuntimeOwner.resolution_presented` | `V075CombatPresentationConsumer.consume_receipt` | no | yes | 0 |

The production `V075RuntimeComposition` also connects `resolution_presented` to `V075ApplicationFlow._on_public_resolution_presented`. That classified application receipt-forwarding listener is outside the Presentation Observer scope; it is not a Presentation Consumer edge and is never used to satisfy the required count of three.

The failed-initialization characterization at head `60e7757bb52e487ad40abc5210349cd9930195f5` and tree `11ce5fdde15e1fbca9d7aea16ffd855bc859f606` proved that all three required signature sets, the Combat Owner, the Presentation Consumer, and the Telemetry Bridge are identical before and after cleanup. A separate production Composition fixture proves the real telemetry service binding and classifies the Application Flow listener. Rebinding observers is idempotent, creates no duplicate edge, and routes a repeated V2 receipt to one Presentation cue. Gate 78 therefore failed because its old oracle required two listeners on `resolution_presented`; the product cleanup did not damage the dedicated bus.

The retired edge must stay absent. Reconnecting the Presentation Consumer to `resolution_presented` would bypass `PresentationReceiptIdentityV2`, mix application and Presentation receipt schemas again, and risk duplicate Presentation effects and receipt identity collisions.

Machine-readable authority: `docs/architecture/v075_presentation_observer_topology_v2.json`.

# V0.6 To V0.7 Rule Delta

```text
MATRIX_ID=space_syndicate.v06_to_v07.rule_delta.v1
SOURCE_RULESET=v0.6
TARGET_CONSTITUTION=space_syndicate.v07.complete
STATUS=frozen_design_delta_not_runtime_cutover
```

This ledger maps current-production V0.6 and pre-constitution planning to the
frozen V0.7 target. It does not claim that a migration has run. The complete
machine-readable ownership, Save, RNG, test, cutover, and deletion fields are in
[`v06_to_v07_rule_delta.json`](v06_to_v07_rule_delta.json).

Classifications mean:

- `unchanged`: inherited semantic meaning, not inherited implementation.
- `modified`: an existing domain changes behavior.
- `retired`: the V0.6 or historical target rule has no V0.7 authority.
- `new`: V0.7 adds a semantic owner/state transition.
- `balance_rebased`: the shape remains but initial values change materially.

## Acquisition And Track

| Rule ID | V0.6 / historical rule | Frozen V0.7 rule | Class |
| --- | --- | --- | --- |
| `v07.delta.region_racks_to_unified_track` | Normal cards come from region racks. | Normal and commodity cards share one partially visible track. | `retired` |
| `v07.delta.dual_tracks_to_single_track` | Commodity and ordinary-card supply are separate. | One sequence carries both closed card kinds. | `retired` |
| `v07.delta.monster_card_price_modifier_retired` | Nearby monsters raise ordinary-card price. | Monster position/range has no automatic card-price effect. | `retired` |
| `v07.delta.sunlight_purchase_to_facility_efficiency` | Sunlight gates ordinary-card purchase. | Sunlight affects declared facility work rates only. | `modified` |
| `v07.delta.gdp_supply_to_uniform_color_cycle` | Historical planning lets GDP drive supply/visibility. | Every color cycle resets uniformly and GDP never drives track supply. | `retired` |
| `v07.delta.public_stances_hidden_weights` | No complete V0.7 stance cycle exists. | UP/DOWN directions reveal together while lead weight and identity remain hidden. | `new` |
| `v07.delta.no_hidden_lead_cycle_to_fixed_reverse_macro_rounds` | No frozen hidden reverse-round cycle exists. | One hidden order alternates exact forward/reverse macro rounds. | `new` |
| `v07.delta.region_popup_purchase_to_information_only` | Region popup is a purchase entry point. | Region popup is informational; the unified track owns acquisition. | `modified` |

## Decks And Inventory

| Rule ID | V0.6 / historical rule | Frozen V0.7 rule | Class |
| --- | --- | --- | --- |
| `v07.delta.purchase_to_hand_to_discard` | Purchased normal card enters hand. | Purchase enters personal discard, not immediate play. | `modified` |
| `v07.delta.consumed_cards_to_personal_dbg` | No complete personal DBG lifecycle. | Draw, hand, escrow, resolution, discard, and reshuffle are authoritative. | `new` |
| `v07.delta.starter_pool_to_fixed_twelve_card_deck` | No constitutional 12-card starter DBG. | Six L1 factories plus six L1 markets; shuffle and draw five. | `new` |
| `v07.delta.auto_merge_to_optional_normal_merge` | Some full-hand paths auto-merge. | Same-family equal-level normal merge is optional. | `modified` |
| `v07.delta.commodity_merge_to_manual_level_three` | Commodity merge can auto-run and retain L4. | Manual `L1+L1=L2`, `L2+L1=L3`; L3 maximum. | `modified` |
| `v07.delta.shared_hand_to_separate_inventory_limits` | Normal and commodity cards share capacity five. | Normal hand and commodity inventory each have independent limit five. | `modified` |
| `v07.delta.mid_batch_refill_to_maintenance_only` | Current flow lacks the V0.7 refill boundary. | Draw and reshuffle occur only during ordered between-batch maintenance. | `new` |
| `v07.delta.variable_normal_hand_capacity_to_fixed_five` | Organization effects can raise normal-hand capacity. | Normal hand is always fixed at five. | `retired` |
| `v07.delta.variable_submission_capacity_to_fixed_five` | Organization effects can raise submitted action capacity. | Every player has at most five active actions per batch. | `retired` |

## Assets And Batch Submission

| Rule ID | V0.6 / historical rule | Frozen V0.7 rule | Class |
| --- | --- | --- | --- |
| `v07.delta.continuous_mana_to_cycle_assets` | Asset/mana recovery follows continuous time. | Lock-time own-GDP snapshot tops up after the batch. | `modified` |
| `v07.delta.asset_cap_100_to_six` | Legacy ceiling reaches 100. | Each color is independently capped at 6. | `balance_rebased` |
| `v07.delta.mana_term_to_six_color_assets` | Player and historical text uses mana. | Player term is six-color assets. | `modified` |
| `v07.delta.resolution_targeting_to_prebound_targets` | Some targets are chosen during resolution. | Every complete target is bound before lock. | `modified` |
| `v07.delta.partial_cost_to_full_asset_reservation` | No complete V0.7 queue reservation contract. | Every action is fully reserved before atomic queue lock. | `new` |

## Resolution, Time, And Victory

| Rule ID | V0.6 / historical rule | Frozen V0.7 rule | Class |
| --- | --- | --- | --- |
| `v07.delta.counter_window_retired` | Resolution opens counter input. | No interactive counters or new resolution input. | `retired` |
| `v07.delta.contiguous_player_queue_to_anonymous_round_robin` | A player's group may resolve contiguously. | Rotate by local index through hidden order; owner remains anonymous. | `modified` |
| `v07.delta.world_ticks_to_resolution_pause` | Realtime timing is not the V0.7 batch pause contract. | Submission advances world; resolution pauses it with no inter-card tick. | `modified` |
| `v07.delta.immediate_end_to_macro_round_gate` | An existing end condition can settle without a lead-round boundary. | Every pending end waits for batch, maintenance, full macro round, and revalidation. | `modified` |

## Save, Replay, And RNG

| Rule ID | V0.6 / historical rule | Frozen V0.7 rule | Class |
| --- | --- | --- | --- |
| `v07.delta.v06_save_direct_resume_to_versioned_v07` | V0.6 Save covers current owners only. | V0.7 has a versioned schema; V0.6 cannot directly resume and requires backup. | `new` |
| `v07.delta.shared_rng_to_dedicated_v07_streams` | Current RNG does not contain every V0.7 stream. | Seven deck, track, and hidden-order streams are separately saved and replayed. | `new` |

## Cutover Rule

Each JSON entry names the affected Core owner, AI domain, player surface, Save
section, RNG stream, and tests. Its `cutover_gate` must pass before the target
writer becomes production authority. Its `legacy_deletion_gate` must pass in the
same atomic domain cutover.

The following are forbidden:

- long-lived V0.6/V0.7 dual writes;
- using an old test to veto the target constitution;
- treating inherited semantics as inherited architecture;
- direct V0.6 Save resume into V0.7;
- UI or AI consumption of authority-secret state;
- UI, hover, drag, animation, or AI observation consuming rule RNG.

The old shared-commodity-track planning files are retained only as historical
evidence. Their GDP supply baseline, commodity-only track, level-IV commodity,
and open authority questions are not V0.7 target rules.

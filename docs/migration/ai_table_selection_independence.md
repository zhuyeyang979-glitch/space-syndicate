# AI Table Selection Independence

Parent program: `P0-AI-WORLD-TYPED-PORTS-CUTOVER`

This atomic cutover removes AI card play and counter submission from the human
`TableSelectionState`. It does not claim that the parent AI typed-port program,
the generic world bridge retirement, or full-run resume is complete.

## Production Boundary

`AiRuntimeController` no longer exposes `selected_district` or
`selected_trade_product` proxy properties and does not call
`table_selection_state()`. Card play candidates now carry an explicit district,
product, card-resolution ID, actor index, and session source revision into
`CardPlaySubmissionRuntimeController`.

The submission controller accepts the explicit snapshot only for the allowlisted
`ai` and `ai_counter_conversion` sources. Missing or mistyped fields fail closed;
there is no fallback to the current human table focus. The existing stable-target
envelope binds the public region and product IDs, catalog ordering revisions and
fingerprints, session identity, and selected public resolution ID before queueing.

AI product fallback now reads the actor's own economy projection and then the
public market catalog. It never borrows the product currently selected by the
human viewer.

## Authority

- Human table focus owner: `TableSelectionState`, unchanged.
- Card submission owner: `CardPlaySubmissionRuntimeController`, unchanged.
- Card queue owner: `CardResolutionQueueRuntimeService`, unchanged.
- AI own economy facts: `AiActorEconomyQueryPort`.
- Public product fallback: `AiMarketPublicQueryPort`.
- Session source revision: `AiSessionPublicQueryPort`.

No save section, gameplay state owner, queue owner, or parallel selection owner
is added by this change.

## Verification

- `ai_card_phase_counter_owner_test.gd`: 25/25.
- `card_resolution_stable_target_envelope_test.gd`: 39/39.
- `public_card_track_focus_selection_cutover_test.gd`: 72/72.
- `district_product_hand_selection_cutover_test.gd`: 64/64.
- `selected_player_actor_authority_split_test.gd`: 78/78.
- Godot MCP production script compile: 718 checked, 0 errors.
- Godot MCP formal `main.tscn` play mode: runtime bridge ready, clean stop.

The public-card-track test also replaces three stale source oracles: public
history focus now follows its stored public district, Compendium detail uses the
typed navigation intent, and AI history targeting is checked against the current
stable resolution-ID path.

## Remaining Parent Scope

The AI controller still has generic card, monster, military, weather, victory,
log, and presentation helpers. `_call_world`, `_call_monster`, the generic world
bridge, and the remaining Main method-name routes must still be removed before
the parent P0 can be green.

`FULL_RUN_RESUME_CLAIM=false` remains unchanged.

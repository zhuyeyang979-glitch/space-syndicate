# Card Resolution Stable Target Envelope

## Boundary

Card submission now freezes the public table focus at the first play intent.
The frozen data travels with the private resolution entry and is resolved from
stable IDs immediately before delayed execution. Changing the map region,
product focus, or public card-history focus while choosing a target can no
longer retarget the queued card.

This boundary covers card resolution only. It does not migrate ProductMarket,
Military, Monster, or AI target selection and it does not change
`TableSelectionState`.

## Contract

`CardResolutionStableTargetEnvelope` is a detached, pure-data value containing:

- active session identity;
- table-selection revision at capture;
- stable `region_id` plus public index and region catalog fingerprints;
- stable `product_id` plus public index and product catalog fingerprints;
- selected public card-resolution ID;
- explicit monster or player target when required;
- stable contract and requirement region bindings;
- a canonical SHA-256 envelope fingerprint.

`TableSelectionCatalogQueryPort` supplies the two independent public catalogs.
The envelope does not own either catalog and does not contain a Node, Object,
Callable, private player state, hidden actor, cash, hand, or AI data.

## Lifecycle

1. `CardPlaySubmissionRuntimeController` captures the envelope before opening a
   target-choice window.
2. `CardTargetChoiceRuntimeController` keeps the envelope and source-card
   fingerprint only in its viewer-private in-memory continuation.
3. The selected target is bound to the original envelope. The current UI focus
   is not sampled again.
4. `CardResolutionQueueRuntimeService` validates the envelope and its legacy
   compatibility mirrors before accepting the entry.
5. `CardResolutionTransitionSink` resolves stable region IDs against the live
   `WorldSessionState` ordering immediately before execution.
6. Eligibility and commitment-cost revalidation consume the resolved frozen
   context.
7. `CardResolutionExecutionWorldBridge` removes the envelope before appending
   public card history.

## Compatibility

The target-choice save schema remains version 1 and its serialized shape is
unchanged. An in-progress legacy choice restored without an envelope fails
closed at final submission rather than reading the current UI selection.
Legacy queue fixtures without an envelope remain accepted using their already
captured numeric context; they receive no live-selection fallback.

The v0.6 save registry, section order, and section schemas are unchanged. Card
resolution queue cold restore remains outside this boundary and is not claimed
as supported.

## Gate

`tests/card_resolution_stable_target_envelope_test.gd` covers first-intent
capture, target continuation under focus drift, stable-ID resolution after a
region reorder, fingerprint tamper rejection, queue mirror validation,
schema-v1 fail-closed restore, public projection privacy, and source-negative
Main/focus checks.

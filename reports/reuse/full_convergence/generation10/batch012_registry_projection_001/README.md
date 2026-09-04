# Batch012 exact Registry append

The exact candidate bound to committed Head
`a3ea0a03362c5e4cfc44043b2b875d609d70b72e` appended 39 inventory rows to
`V076_HISTORICAL_REUSE_REGISTRY.json`. All 523 prior rows are unchanged. The
result contains 562 rows and has SHA-256
`7bf5d500028f99b745e106c9a87e57e7cf4aa8540bb9c334cbd8c64bac8b2a67`.

All 39 members are unchanged historical components of the retired
`GameRuntimeCoordinator` or `SpaceSyndicateGameScreen` dependency graph. The
current executable root instantiates `V075RuntimeComposition` and
`V075SampleGameScreen`; it does not instantiate either retired scene. A type
annotation, preload, compatibility lookup, or default NodePath is not treated
as an execution edge.

The primary exact-rebuild review and independent target-delta reconstruction
both passed. The single-purpose writer then re-ran both algorithms immediately
before performing one Registry write. It made no Supersession Map or product
write, created no Owner, changed no older row, did not rerun formal STEP11, and
did not claim Required Gate, human, or production green.

The post-write exact audit passed: 523 old rows, 39 appended rows, 562 total,
and zero old-row mutations. The existing Reuse Point Inertia Gate self-test
passed 163/163 with zero false green and zero valid-delta false rejection.
The full-convergence correction self-test also passed 130/130 with zero legacy
record or seal mutation.

## Remaining work

This append is Registry classification only; it is not correction-batch
authority. Batch012 still requires an exact current-Head proposal, A/B review,
seven batch documents and its nonempty historical-test correction record.
Batch013 dynamic references remain separate. After both batches, refresh the
current-subject, SPR, HDM and post-touch successors before the actual Required
Gate. Generation 9 formal failure and Generation 10 formal PASS remain frozen;
human and production green remain false and STEP13-15 remain pending.

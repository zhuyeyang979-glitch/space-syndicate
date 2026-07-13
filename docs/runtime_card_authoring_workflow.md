# Runtime Card Authoring Workflow - Sprint 59

## Goal

Runtime cards are authored as Godot Resources, validated in the Inspector, and
reviewed through deterministic pure-data reports. `CardRuntimeCatalogService`
remains the only runtime catalog owner. The authoring tools are editor-only and
never become gameplay dependencies.

## Editor workflow

1. Open `RuntimeCardAuthoringWorkspace.tscn` from the Space QA dock.
2. Filter by pack and family, then open the selected family `.tres`.
3. Edit the embedded `CardRuntimeRankResource` in the Godot Inspector.
4. Use the custom Runtime Card Authoring Inspector panel to validate the
   selected Catalog, Pack, Family, or Rank Resource.
5. Capture a working baseline before a coordinated content pass.
6. Build the JSON and Markdown change review after editing.
7. Review affected families, field-level diffs, derived-rank impacts, ordered
   catalog/pool changes, and the downstream-consumer checklist.
8. Run `RuntimeCardAuthoringWorkflowBench.tscn` and
   `RuntimeCardCatalogResourceBench.tscn` before accepting the content change.

## Validation boundary

`CardRuntimeAuthoringValidator` blocks:

- missing or inconsistent card, family, pack, and rank identity;
- duplicate rank, family, pack, authored-card, pool, or ordering entries;
- rank order outside I-IV or family/card id mismatches;
- missing base fields and kind-specific required fields;
- unknown kinds and fields outside the authored kind schema;
- runtime state, private data, Node, Object, Callable, or Resource values;
- Product Futures and City GDP financial terms copied into card definitions;
- inconsistent public-pool and upgradeable-family declarations.

Warnings remain visible without hiding errors. Validation does not mutate an
asset or silently repair content.

## Change review

The approved Sprint 58 integrity fixture remains the tracked canonical hash
baseline. An optional full working baseline is written to `user://` so the
review can include field-level before/after values without creating a second
tracked catalog.

Outputs:

- `user://space_syndicate_design_qa/runtime_card_authoring/working_baseline.json`
- `user://space_syndicate_design_qa/runtime_card_authoring/change_review.json`
- `user://space_syndicate_design_qa/runtime_card_authoring/change_review.md`
- `user://space_syndicate_design_qa/runtime_card_authoring/manifest.json`
- `user://space_syndicate_design_qa/runtime_card_authoring/report.md`

The review identifies added, removed, and modified cards; affected families;
possible derived-rank impacts; authored order, public-pool order, and
upgradeable-family order changes; and consumers that require focused review.

## Ownership and privacy

The Inspector plugin, Workspace, Validator, Authoring Service, Change Review
Service, and QA Bench do not appear in `main.tscn` or
`GameRuntimeCoordinator.tscn`. They own no gameplay state, card effects,
eligibility, queue, execution, AI, economy, save, or presentation algorithms.

Every validation, index, baseline, review, manifest, and debug payload contains
only Dictionary, Array, String, Number, Bool, and null values. Runtime/private
owner data, private targets, private discards, opponent hands, and AI plans are
not accepted as authored fields.

## Acceptance gate

`RuntimeCardAuthoringWorkflowBench` runs 36 checks across Resource loading,
catalog counts, positive and negative validation, canonical integrity,
added/removed/modified detection, field diffs, derived impacts, Inspector and
Workspace composition, user-scoped outputs, pure data, and runtime ownership.

Required result: 36/36, followed by the Sprint 58 catalog gate at 80/80.

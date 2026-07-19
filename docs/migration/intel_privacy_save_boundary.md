# Intel Privacy And Save Boundary Audit

Status: `BOUNDARY_FROZEN_WITH_CUTOVER_BLOCKERS`

Audit base: `657f5172e7afa8c31658f90af5f81d076430bf5c`

Scope: analysis only. This audit does not change production code, tests, scenes,
the 19-section save registry, or the session-envelope-v2 schema.

`FULL_RUN_RESUME_CLAIM=false`

## Findings First

### P1 - Opening Intel currently mutates the route owner

`Main._intel_dossier_public_source_snapshot()` calls `_refresh_route_network()`
before composing the page (`scripts/main.gd:2629-2633`). The refresh reaches
`RouteNetworkRuntimeController.refresh_routes()`, which updates refresh and
possibly rebuild counters (`scripts/runtime/route_network_runtime_controller.gd:76-95`,
`:136-143`). A viewer query therefore is not currently zero-mutation. The new
query port must consume an already-owned public route projection and fail closed
when it is unavailable.

### P1 - The current Intel source crosses raw world and private-data boundaries

The source reads the mutable `WorldSessionState.players` and `districts`
collections directly (`scripts/main.gd:2629-2660`). It then:

- reads true city owner values while constructing viewer entries and result text
  (`scripts/main.gd:2773-2801`, `:3205-3241`, `:3257-3283`);
- reads private warehouse products, counts, units, expiry and exact income from
  raw city dictionaries (`scripts/main.gd:2725-2752`);
- reads raw monster actors, owner state and exact loss/cash-pool values rather
  than a typed public projection (`scripts/main.gd:3097-3127`);
- derives city clues from true owner and exact income (`scripts/main.gd:3050-3086`);
- formats exact GDP, monster cash-like values and warehouse internals into visible
  text (`scripts/runtime/intel_dossier_public_snapshot_service.gd:271-320`).

These reads are not made safe merely because the final formatter selects a few
keys. Public facts must originate from owner-provided public projections. Private
warehouse inventory, hidden ownership and exact opponent resources remain
forbidden.

### P1 - City inference commands bypass a typed owner boundary

The Intel action dispatcher parses string-encoded payloads and calls Main
wrappers (`scripts/main.gd:2526-2614`). Main then mutates the nested
`city_guesses`, `city_guess_confidence` and `city_guess_reasons` dictionaries
directly (`scripts/main.gd:6532-6631`). These paths have no typed command ID,
expected session revision, authorized-local-viewer check or replay protection.

Two additional production paths bypass the same future command boundary:

- `CardIntelRuntimeService._reveal_city_owners()` writes the three dictionaries
  directly (`scripts/runtime/card_intel_runtime_service.gd:96-128`);
- AI calls the Main mutation helper through `_call_world()`
  (`scripts/runtime/ai_runtime_controller.gd:1011-1012`, `:8190`).

`WorldSessionState` remains the only state and save owner. The cutover must add a
narrow typed mutation API or port over that owner, then migrate all three caller
families. It must not create an Intel state mirror.

### P1 - Authorized reveal semantics are split and currently lossy in the UI

There is no dedicated persisted `authorized_reveal` boolean. The canonical save
codec recognizes an authorized reveal by `confidence=100`; it emits
`reason_kind="public_reveal"` and accepts a non-empty reason up to 96 characters
(`scripts/runtime/world_session_envelope_codec.gd:4-8`, `:383-460`). Normal
player inference uses confidence `1`, `2` or `3` and one of six reason IDs.

`CardIntelRuntimeService` follows this convention (`scripts/runtime/card_intel_runtime_service.gd:120-126`),
but the legacy Main reveal path writes confidence `3` and reason `card`
(`scripts/main.gd:6634-6648`). The Intel page also normalizes all confidence to
`1..3` and all reasons to the six ordinary reason IDs (`scripts/main.gd:2799-2800`,
`:2860-2904`). A restored confidence-100 reveal can therefore be displayed as an
ordinary guess and overwritten.

The role catalog exposes `intel_city_reveal_charges`, but no independent runtime
usage owner for those charges was found. The cutover must not invent charge state
or claim exact-once charge persistence until the authoritative gameplay path is
identified. Card-history role usage is a separate, already persisted owner and
must not be reused as city-reveal usage.

### P2 - Formatter and UI trust accepted strings; current privacy gates are key-only

`IntelDossierPublicSnapshotService` copies accepted dictionaries and formats
their strings without a strict root schema or recursive value-taint policy
(`scripts/runtime/intel_dossier_public_snapshot_service.gd:19-33`, `:373-380`).
`IntelDossierBoard` forwards snapshot text into labels, buttons and tooltips
(`scripts/ui/intel_dossier_board.gd:24-43`, `:139-149`, `:159-185`, `:196-240`,
`:289-348`). There are no Intel-specific accessibility overrides; platform
accessibility can therefore inherit visible text or tooltip text.

Existing tests inject a few forbidden top-level keys and scan key names, but do
not prove nested accepted strings are free of opponent notes, owner truth, AI
sentinels or object paths (`tests/intel_dossier_public_snapshot_service_test.gd:31-39`,
`scripts/tools/intel_dossier_public_snapshot_cutover_bench.gd:238-247`, `:367-374`).
A recursive key, value and runtime-type gate is required at both query output and
surface input.

### P2 - Intel navigation still changes table selection and has a Main fallback

The `track_select` action clears `selected_hand_slot`, changes the focused card
resolution and closes the menu (`scripts/main.gd:2562-2567`). Read-only Intel
navigation may not modify `TableSelectionState`. The snapshot route also falls
back from Coordinator composition to a Main-discovered formatter
(`scripts/main.gd:2617-2626`). Both paths must be absent after cutover.

### P2 - Existing projections are safe building blocks only when narrowed

`WorldSessionPresentationQuery.public_projection()` allowlists public player and
district data (`scripts/presentation/world_session_presentation_query.gd:20-48`,
`:114-143`). Its private projection correctly requires viewer authorization and
viewer equals subject, but deliberately includes cash, hand and discard
(`scripts/presentation/world_session_presentation_query.gd:51-73`). The Intel
query must not pass that broad private projection through. It needs a narrower
viewer-only projection containing only the three city inference maps and
authorized capability state.

## Authority Map

| Domain | Sole state owner | Current read/write boundary | Save owner |
| --- | --- | --- | --- |
| Player and district session state | `WorldSessionState` | Direct arrays are currently exposed; new Intel code must use narrow projections and typed mutations | Session envelope v2 |
| City owner inference | `WorldSessionState.players[viewer]` | Three dictionaries keyed by district index | Session envelope v2 through `SessionEnvelopeSaveOwner` |
| Private card-history annotations and role usage | `CardHistoryPrivateAnnotationService` | Viewer-scoped API, but caller authorization must be enforced by the new command/query ports | Session envelope v2 through `SessionEnvelopeSaveOwner` |
| Public card-resolution history | `CardResolutionHistoryRuntimeService` | `CardHistoryPublicQueryPort` | `card_resolution_history` section |
| Intel page | No state ownership permitted | Presentation snapshot in, typed actions out | None |

No second WorldSession owner, Intel state owner, Intel save owner or annotation
section is permitted.

## WorldSessionState Contract

### Runtime city inference shape

The player dictionaries contain exactly these current inference fields
(`scripts/runtime/world_session_envelope_codec.gd:19-53`):

- `city_guesses: Dictionary` maps `district_index -> suspected_player_index`;
- `city_guess_confidence: Dictionary` maps the same `district_index -> int`;
- `city_guess_reasons: Dictionary` maps the same `district_index -> String`;
- `role_index: int` identifies the ordered role catalog entry;
- `role_card: Dictionary`, whose `name` must match the role at `role_index`.

There is no separate facility-guess field or facility stable-ID contract in the
current save schema. The current subject is an active city addressed by district
index. A future facility inference feature requires a separately authorized
schema decision; the Intel cutover must not reinterpret district indices as
facility IDs.

Ordinary private inference requires:

- valid district index and suspected player index;
- suspected player differs from viewer;
- confidence is exactly `1`, `2` or `3`;
- reason is one of `product`, `route`, `card`, `monster`, `role`, `intuition`.

Authorized public-reveal knowledge uses the existing sentinel convention:

- confidence is exactly `100`;
- reason is non-empty and at most 96 characters;
- the envelope record derives `reason_kind="public_reveal"`.

The envelope canonicalizes the three dictionaries into sorted
`city_intel_records` containing `district_index`, `suspected_player_index`,
`confidence`, `reason` and `reason_kind`
(`scripts/runtime/world_session_envelope_codec.gd:109-123`, `:261-317`,
`:383-460`). It recreates the runtime dictionaries on restore. True owner remains
authoritative district state and must never be copied into the Intel viewer
snapshot merely to validate a guess.

### Persistence and restore signals

`WorldSessionState` owns players, districts, game time and geometry
(`scripts/runtime/world_session_state.gd:18-35`). Its envelope capture,
preflight, apply and rollback checkpoint APIs are at
`scripts/runtime/world_session_state.gd:166-200`.

Restore emits in this deterministic order
(`scripts/runtime/world_session_state.gd:132-147`):

1. `players_replaced`;
2. `districts_replaced`;
3. `game_time_changed`;
4. `world_geometry_changed`;
5. `session_restored`.

Intel refresh must subscribe to the final restored state and must not settle a
guess, consume a charge, append a log or mark save dirty during restore.

## Card-History Private Annotation Contract

`CardHistoryPrivateAnnotationService` is the sole owner of viewer annotations,
role usage, subscription fingerprints and its revision
(`scripts/runtime/card_history_private_annotation_service.gd:44-49`).

### Persisted fields

The session checkpoint root contains only:

- `schema_version`;
- `revision`;
- `annotations_by_viewer`;
- `role_usage_by_viewer`.

Each annotation persists exactly
(`scripts/runtime/card_history_private_annotation_service.gd:5-21`, `:411-435`):

- `note_text`;
- `private_tags`;
- `suspected_player_indices`;
- `private_confidence`;
- `excluded_player_indices`;
- `subscribed`.

`role_usage_by_viewer` currently permits only `residual_catalog` and
`public_exclusion`, with limits frozen by the service
(`scripts/runtime/card_history_private_annotation_service.gd:16-18`, `:260-279`).

### Derived and non-persisted fields

The runtime viewer row can additionally include `viewer_index`,
`history_entry_id`, `public_evidence_summary`,
`verified_by_public_reveal` and `updated_at_public_revision`
(`scripts/runtime/card_history_private_annotation_service.gd:30-42`).
Subscription fingerprints and notification count are runtime-only and are not
gameplay authority (`:184-210`, `:341-380`).

`annotation_for_viewer()` and `viewer_snapshot()` isolate buckets by viewer
(`scripts/runtime/card_history_private_annotation_service.gd:64-86`). The
service itself accepts any nonnegative viewer index at its mutation boundary;
the new command port must additionally prove that the caller is the currently
authorized local viewer before delegating.

### Cold restore order

The registry restores `card_resolution_history` before `session`
(`scripts/runtime/v06_save_owner_registry.gd:27-47`). Session annotation
preflight is structural and does not read live history. Apply then resolves every
saved `history_entry_id` against the already restored public query; a missing ID
fails closed with `card_annotation_public_history_missing`
(`scripts/runtime/card_history_private_annotation_service.gd:224-329`).

On success, derived public evidence and subscription fingerprints are rebuilt
silently, saved revision is restored exactly, and notification count does not
increase. Existing cold-runtime evidence verifies history `0 -> 3`, annotations
`0 -> 4`, viewer isolation, no restore notification, and city inference plus
role-usage roundtrip
(`scripts/tools/session_envelope_save_owner_bench.gd:94-135`, `:414-435`,
`:568-571`). The focused annotation test also proves viewer 1 cannot read viewer
0 and apply-before-history fails closed
(`tests/card_history_public_annotation_test.gd:43-46`, `:61-70`).

## Public Card-History Contract

`CardResolutionHistoryRuntimeService` is the sole public history owner. Append
and patch paths remove private and retired card-owner fields before storing or
projecting entries (`scripts/runtime/card_resolution_history_runtime_service.gd:9-31`,
`:60-108`, `:231-269`). Its `private_viewer_snapshot()` intentionally equals the
public snapshot (`:161-170`).

`CardHistoryPublicQueryPort` exposes exactly
(`scripts/presentation/card_history_public_query_port.gd:6-19`, `:74-112`):

- `history_entry_id`;
- `public_sequence`;
- `public_time`;
- `public_card_id`;
- `public_card_name`;
- `public_target`;
- `public_result`;
- `public_reveal_state`;
- `publicly_revealed_actor`;
- `action_phase`;
- `card_category`;
- `public_revision`.

At this base, `publicly_revealed_actor` is always the empty string
(`scripts/presentation/card_history_public_query_port.gd:93-96`). Intel must not
reconstruct an actor from resolution IDs, owner truth, target player, private
annotations or retired card-owner fields. The history sanitizer is key-based, so
accepted public strings still require recursive sentinel tests against upstream
taint.

## Frozen Intel Projection Policy

### Public allowlist

Only owner-provided, pure-data facts in these categories may be shared with every
viewer:

- public player index and public player name;
- public district/region stable ID, name, status and geometry needed for links;
- public facility facts and publicly revealed facility ownership only;
- public aggregate commodity/GDP, route, monster and warehouse-pressure clues
  from their typed public projections, never raw inventories or actors;
- the exact `CardHistoryPublicQueryPort` fields listed above;
- public reveal events and public logs already authorized by their owners;
- public rule parameters for city inference reward and penalty;
- typed navigation link IDs.

### Viewer-private allowlist

After local-viewer authorization, the snapshot may include only the current
viewer's:

- viewer index and public name;
- `city_guesses`, `city_guess_confidence`, `city_guess_reasons`, projected as
  canonical rows rather than mutable dictionaries;
- confidence-100 authorized-reveal sentinel and its saved reason;
- card annotation fields listed in the persisted annotation contract;
- derived annotation evidence fields recomputed from public history;
- `residual_catalog` and `public_exclusion` usage/remaining counts;
- any city-reveal capability state only after a real authoritative usage owner is
  identified.

The viewer-private projection must be detached pure data. It must not expose the
broader `WorldSessionPrivateProjection` cash, hand or discard fields.

### Forbidden at query, debug and UI boundaries

- another viewer's guesses, confidence, reasons, notes, tags, suspects,
  exclusions, subscriptions or role usage;
- hidden or true city/facility/monster/card owner;
- hidden card actor or unpublished reveal;
- exact opponent cash, cash cents, hand, discard or card slots;
- private warehouse inventory, units, products, expiry, futures or orders;
- AI plan, score, reason, pressure, memory or learning state;
- internal resolution fingerprints, command IDs, save paths or node paths;
- raw mutable player, district, city, monster or annotation dictionaries;
- `Node`, `Object`, `Callable`, `RID`, `Resource`, `Signal` or runtime references;
- current scene, `/root/Main`, method-name strings or fallback service discovery.

The same policy applies recursively to snapshot serialization, debug snapshots,
visible labels, rich text, buttons, tooltips, accessibility text and empty-state
reasons. `session_finished` may add only FinalSettlement-authorized public facts;
it may not reveal opponent reasoning or notes.

## Current Command Bypasses And Required Ownership

| Current action | Current path | Required boundary |
| --- | --- | --- |
| Set or clear city guess | Raw string action -> Main nested dictionary mutation (`scripts/main.gd:2573-2580`, `:6532-6589`) | Typed command -> authorized `WorldSessionState` mutation |
| Set confidence or reason | Raw string action -> Main nested dictionary mutation (`scripts/main.gd:2581-2591`, `:6592-6631`) | Typed command with strict allowlist, revision and replay protection |
| Card city-owner reveal | `CardIntelRuntimeService` writes dictionaries directly (`scripts/runtime/card_intel_runtime_service.gd:96-128`) | Existing card execution remains authoritative, but writes through the same typed WorldSession mutation contract |
| Legacy Main city reveal | Main writes confidence 3 and logs true owner (`scripts/main.gd:6634-6675`) | Retire or migrate; preserve confidence-100 reveal semantics and viewer-private receipt |
| AI city inference | AI dynamically calls Main helper (`scripts/runtime/ai_runtime_controller.gd:1011-1012`, `:8190`) | Explicit non-UI command port with AI authorization, no Main call |
| Apply/clear/subscribe card annotation | Main calls Coordinator/service with selected player (`scripts/main.gd:2531-2561`) | Authorized viewer command delegates to `CardHistoryPrivateAnnotationService`; no duplicate annotation state |
| Residual catalog/public exclusion | Annotation service role-usage APIs (`scripts/runtime/card_history_private_annotation_service.gd:143-181`) | Keep the same owner; typed port validates viewer, public evidence and exact-once command ID |
| Select history track entry | Main changes `TableSelectionState` (`scripts/main.gd:2562-2567`) | Presentation-only Intel focus or typed Compendium link; zero table-selection mutation |

No query may trigger save dirty. A successful private command may advance only
the authoritative owner revision and the existing session dirty contract. A
failed, stale, duplicate or unauthorized command must change neither state nor
dirty revision.

## Required Negative Privacy And Mutation Tests

1. Compose the real Intel query for viewer A and viewer B with distinct guesses,
   confidence, reasons, notes, tags, subscriptions and role usage. Each output
   must contain only its authorized bucket.
2. Mutate opponent cash/cash-cents, hand/discard/slots, private warehouse,
   futures, AI plan/score/reason/memory and hidden owner/actor sentinels. The
   authorized viewer snapshot, serialized snapshot and full UI text tree must be
   byte-invariant and contain no sentinel.
3. Inject sentinels into nested accepted-looking strings such as public clue,
   aftermath result, empty-state reason, tooltip and action label. Query or
   surface must fail closed; key-only scans are insufficient.
4. Inject `Node`, `Object`, `Callable`, `RID`, `Resource`, nested mutable arrays
   and dictionaries. Query and surface must reject before applying a page.
5. Open, refresh, paginate and deep-link Intel while fingerprinting WorldSession,
   route refresh/rebuild counters, RNG, market/commodity/weather/monster
   revisions, cash/GDP, inference dictionaries, annotation revision,
   TableSelectionState, public log, command count and save dirty revision. All
   gameplay values must remain unchanged.
6. Verify the query never calls `_refresh_route_network`, Main, current scene,
   dynamic `call` or a private whole-player projection.
7. Submit city commands with wrong viewer, invalid district, own city, invalid
   suspected player, confidence `0/4/99`, invalid reason, stale revision, unknown
   payload field and duplicate command ID. Every case must fail closed with zero
   mutation and zero dirty delta.
8. Restore a confidence-100 reveal and verify query/UI preserve its authorized
   reveal semantics; ordinary edit commands may not silently downgrade or
   overwrite it.
9. Apply annotation commands for another viewer, unknown history ID, third
   subscription, overlapping suspect/exclusion, invalid tag/note, stale revision
   and duplicate command ID. The command port must reject before service mutation.
10. Cold restore public history before session annotations. Missing history ID,
    invalid viewer index, invalid role usage or fingerprint mismatch must leave
    history, WorldSession, annotations and GameSession unchanged.
11. Recursively scan `Label.text`, `RichTextLabel.text`, `Button.text`,
    `tooltip_text`, accessibility-derived strings, debug snapshots and JSON for
    all forbidden keys and values.
12. Finish the session and confirm only settlement-authorized public result fields
    expand. Opponent notes, reasons, confidence and card annotations remain
    private.

## Save And Restore Boundary Is Frozen

The registry remains at 19 sections. `card_resolution_history` precedes
`session`, and both are transactional
(`scenes/runtime/V06SaveOwnerRegistry.tscn:132-142`, `:172-183`;
`scripts/runtime/v06_save_owner_registry.gd:27-47`). The session owner is the
stateless `SessionEnvelopeSaveOwner`, which composes:

1. `WorldSessionState`;
2. `CardHistoryPrivateAnnotationService`;
3. `GameSessionRuntimeController` last.

That apply order and rollback checkpoints are implemented at
`scripts/runtime/session_envelope_save_owner.gd:31-162`. Its debug contract
explicitly says it is not a gameplay state owner and does not claim full-run
resume (`:176-190`).

Seven sections remain unsupported at this base: `ruleset`, `routes`,
`commodity_belt_visibility`, `card_inventory`, `military`,
`card_resolution_queue`, and `ai`. Therefore:

- `REGISTRY_SECTION_COUNT=19`;
- `NEW_INTEL_SAVE_SECTION_COUNT=0`;
- `SECOND_INTEL_STATE_OWNER_COUNT=0`;
- `SECOND_INTEL_SAVE_OWNER_COUNT=0`;
- `FULL_RUN_RESUME_CLAIM=false`.

The Intel cutover may consume these existing contracts. It may not modify the
registry, session-envelope-v2 root shape, cold-restore order, annotation persisted
fields, WorldSession DTO schema or unsupported-section claims.

## Cutover Acceptance

The privacy/save boundary is ready for implementation only when all P1 paths are
removed or routed through the frozen owners. Green requires:

- no Intel query-to-Main route or Main fallback;
- no query route refresh, RNG, selection or save-dirty mutation;
- no direct mutable `players`/`districts` read in Intel presentation code;
- one authorized viewer-private city-inference projection;
- one typed WorldSession mutation boundary used by UI, card and AI callers;
- annotation commands delegated to the existing annotation owner;
- confidence-100 reveal preserved end to end;
- recursive pure-data and taint gates across snapshot, debug and UI;
- cold-restore ordering and 19-section registry unchanged;
- `FULL_RUN_RESUME_CLAIM=false` retained.

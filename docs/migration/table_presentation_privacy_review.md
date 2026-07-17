# Table Presentation Source/Target Cutover — Privacy Review

Status: **FINAL CUTOVER REVIEW — GREEN, PRIVACY VIOLATION COUNT 0**
Reviewed query-ports commit: `5b5b11e`
Reviewed source/target worktree state: uncommitted production cutover after
`5b5b11e`
Scope: table live/full presentation, map presentation, developer diagnostics,
victory state-change presentation and public log presentation.
This review is analysis-only. It does not authorize a production cutover by
itself.

## 1. Decision

### 1.0 Final source/target cutover verdict

The latest production cutover is **GO** from the privacy boundary and may be
reported as `TABLE_PRESENTATION_SOURCE_TARGET_CUTOVER_GREEN` when the parent
acceptance gates are also green.

The implementation closes four important parts of the previous review:

- `TablePresentationPureDataPolicy` recursively rejects runtime object types
  at emitted snapshot boundaries and produces detached copies;
- `TableActionPresentationProjection` now carries `authorized` and
  `authorization_revision`, and unauthorized projections serialize as
  `denied`;
- `VictoryPresentationStateChangeReceipt` now projects an explicit field
  allowlist and keeps exact cash only for a revealed seat under
  `public_audit` visibility;
- public-log tombstones no longer disappear when the visible 90-row window
  evicts a row; retired receipt revisions are retained by event kind.
- card-resolution visual events now expose only a closed `event_kind`, a
  derived `localization_key`, and allowlisted `public_values`. Arbitrary
  `summary`/`aftermath_clue` text is discarded before the public event exists;
  owner and target labels require their independent authoritative reveal
  flags.

The three final blockers were closed as follows:

1. **Private feedback is no longer a public-log channel.** All 99 former Main
   legacy-log calls now use `record_legacy_viewer_feedback()`. Query Ports
   authorizes the current viewer before writing or reading
   `ViewerPrivateFeedbackOwner`; the messages appear only in the full snapshot
   for that same viewer. `PublicLogReceipt` has no free-text field, the legacy
   public producer/import path is deleted, and domain public events use typed,
   allowlisted values. The 16 previously failing sensitive examples are
   covered and produce zero additions to `PublicLogPresentationOwner`.
2. **Developer diagnostics fail closed in release.** The developer target
   requires all of: target enabled, `OS.is_debug_build()`, and explicit
   `SPACE_SYNDICATE_DEVELOPER_PRESENTATION=1`. Coordinator binds diagnostics
   into the source only when that target is available, so release composition
   cannot build or apply developer data.
3. **Viewer binding is enforced at source, port and targets.** Live/full/map
   snapshots carry `viewer_index` and `authorization_revision`; the refresh
   port re-reads the current viewer context before applying, and both
   `GameScreen` and `PlanetBoard` reject mismatches before UI mutation.

Confirmed privacy violation count: **0**

Evidence reviewed:

- Query Ports/localization focused test: `65/65`;
- source/target static gate: `20/20`;
- production viewmodel/privacy parity: `106/106`;
- Godot MCP production bench: `45/45`;
- script scan: `306` scripts, `0` errors;
- source scan: no `record_legacy_public_log_message`, no legacy public
  free-text producer/import, and no Main presentation fallback.

Commit `5b5b11e` establishes the correct composition boundary:
`TablePresentationQueryPorts` is scene-owned, provides distinct public and
viewer-private typed projections, and no longer requires a new Main snapshot
provider. The source/target cutover may use **only** these typed ports; it may
not bind `WorldSessionState`, controller snapshots, debug snapshots, Main,
legacy log arrays, or raw mutable player/district collections.

The final disposition of the five original blockers is:

| ID | Final status | Evidence / remaining condition |
| --- | --- | --- |
| `PURE-DATA-01` | Closed | `TablePresentationPureDataPolicy` recursively validates and detaches public/private/action/map/snapshot payloads. |
| `VIEWER-01` | Closed | Action/private projections and live/full/map snapshots carry authorization revision; port and targets reject stale/mismatched viewers. |
| `VICTORY-01` | Closed for the production owner path | The receipt service projects exact allowlists and cash requires top-level public audit, a revealed seat, row-level public-audit visibility and integer ledger cash. Residual hardening: narrow the currently empty `key_city` subobject before future use. |
| `LOG-01` | Closed | Public log accepts typed event/localization receipts only. All former legacy messages are authorized viewer-private feedback and the 16 sensitive fixtures add zero public entries. |
| `LOG-02` | Closed | Receipt tombstones are independent of the visible 90-row window and use retired revision floors. |

Query Ports already resolve the earlier blockers for explicit local-viewer
authorization, basic public map owner redaction, public/private world
projection separation, and typed public-log ownership. Those improvements must
be preserved; they do not make the five gaps above safe by themselves.

Two conditions are mandatory before the cutover can be declared green:

1. The source owner must consume explicit, typed, read-only public and
   viewer-private projections. It must not receive
   `WorldSessionState.players`, `WorldSessionState.districts`, controller
   internals, or an equivalent complete mutable world dictionary.
2. Public log production must be separated from private player feedback. The
   existing `Main._log()` buffer contains both kinds and therefore cannot be
   used as a public snapshot source, even if cash-looking strings are filtered.

If any condition cannot be met without a new Main callback or a second world
owner, the production cutover must fail closed.

### 1.1 Sole legal source dependencies after hardening

`TablePresentationSourceOwner` may consume only these
`TablePresentationQueryPorts` results (or their exact typed descendants):

- `WorldSessionPublicProjection` for universal table/world facts;
- an authorized `WorldSessionPrivateProjection` for the one locally bound
  viewer and the same subject;
- an authorized `TableActionPresentationProjection` for that viewer's forced
  decision, purchase and target-choice surfaces;
- `TablePublicMapProjection`, cached separately per authorized viewer and
  selected commodity;
- the already-public card-track projection;
- typed `PublicLogReceipt`/public log entries after `LOG-01/02` are closed;
- a strict allowlisted `VictoryPresentationStateChangeReceipt` after
  `VICTORY-01` is closed.

It must not consume `TablePresentationQueryPorts.debug_snapshot()`, a domain
controller `debug_snapshot()`, the legacy public-log importer, raw roster or
flow snapshots, `WorldSessionState`, Main, or any UI node. Developer diagnostics
must arrive through a separate optional developer-only query/target guarded by
a debug-build capability and local opt-in; it must never be merged into the
live/full/map source.

## 2. Authority and visibility scopes

Every presentation request must declare one of these scopes before a snapshot
is built:

| Scope | Legal consumer | Legal content |
| --- | --- | --- |
| `public` | every seat and public log | facts explicitly published by a domain owner |
| `viewer_private` | one locally authorized viewer target | public facts plus that viewer's own private facts |
| `developer_only` | debug-build developer target only | diagnostic projection produced by the diagnostics owner |

`viewer_private` is not equivalent to “human”, “not AI”, selected seat, hovered
seat, inspected seat, or the first non-AI seat. It requires all of:

- a valid `viewer_player_index`;
- a valid `subject_player_index`;
- `viewer_player_index == subject_player_index` for hand, cash, discard,
  purchase state and private decisions;
- an explicit local-viewer authorization supplied by the session/composition
  boundary;
- a target bound to that same viewer.

The viewer identity is routing metadata. It must not be copied into public
snapshot payloads or public logs.

## 3. Existing positive foundations

The repository already contains useful narrow owners that should be reused:

- `DistrictSupplySnapshotService` distinguishes `public` and
  `viewer_private`, requires viewer/subject equality, rejects forbidden source
  keys and enforces pure-data output.
- `OptionalRoutePresentationRuntimeService` exposes a strict public route
  allowlist and removes supplier, facility, inventory and AI identity.
- `VictoryControlRuntimeController.public_snapshot()` and the final-settlement
  source/snapshot services already distinguish public from viewer-private
  state and conditionally disclose exact cash only under an authoritative
  public-audit allowlist.
- `FinalSettlementPublicSourceAdapter` strips controller-private ranking
  fields and emits a visibility-tagged public outcome.
- `GameScreen` has a defensive public-track sanitizer.

These are defenses to preserve, not permission to pass raw controller or Main
state into a presentation source.

## 4. Existing risks that the cutover must remove

### 4.1 Main is currently the privacy decision point

`Main._runtime_table_viewmodel_source()` assembles public table state,
current-player state, card surfaces, temporary decisions, map facts and logs in
one broad dictionary.

`Main._can_view_player_private_hand()` currently returns true for any non-AI
seat. That is not a sufficient viewer authorization contract. It happens to be
less visible in the current one-human PVE shape, but it would authorize the
wrong subject in a multi-human, replay, spectator, test fixture or future local
hot-seat context.

`Main._runtime_snapshot_player_index()` also falls back through local player,
selected player, inspected player and seat zero. Selection and inspection are
presentation choices, not proof that private facts may be read.

Required correction: private projection must be requested with an explicit
viewer/subject pair and must fail closed when it is absent or mismatched.

### 4.2 Raw card-resolution entries cross the source boundary

`Main._runtime_enriched_card_track_entry()` duplicates the complete queue
entry, including its internal `player_index`, into an intermediate `entry`
field. Later viewmodel/UI layers redact or ignore many fields, and
`GameScreen` removes private track keys. This is too late for the new
architecture.

The typed public card-track source must construct an allowlisted entry from
the card-resolution viewer/public projection. It must never hand the true
actor index, private target binding, private discard, internal card instance,
transaction lineage or complete skill object to `GameScreen`.

`is_viewer_card` is allowed only in a viewer-private card-track projection and
must be derived by a typed viewer service. It is forbidden in the public
track.

### 4.3 Public log buffer contains private feedback

`Main._runtime_public_log_snapshot()` reads the last lines from the single
`log_lines` buffer and only applies the final-settlement cash-text sanitizer.
The same buffer receives private events, including private city guesses,
confidence/reason notes, private intel acquisition, private discard/purchase
feedback and other viewer-scoped messages.

Text filtering cannot make this buffer public. In particular, a private log
line may leak useful facts without containing `cash`, `private_` or another
known token.

Required correction:

- public logs must enter a typed public-log owner through an allowlisted event
  receipt;
- current-player feedback must enter a separate viewer-private target;
- arbitrary free text from Main or a domain controller must not be promoted to
  public log state;
- the public-log target must apply each receipt exactly once by public receipt
  sequence/revision;
- private log receipt IDs and internal source receipt IDs must not be shown.

### 4.4 Broad world state is not an acceptable source dependency

At review time, `WorldSessionState` exposes complete mutable player and
district arrays. A new source owner may not bind those arrays and then recreate
Main's filtering locally. Doing so would make presentation code an accidental
owner of every hidden field.

The minimum safe seam is a scene-composed, typed read-only query/projection
owner that offers separate methods for:

- public table facts;
- public map facts;
- viewer-private current-player facts;
- viewer-private map annotations;
- public victory facts;
- public card-track facts.

Each method must return a new pure-data value and validate its own scope. The
presentation source may combine these values but may not deepen their
visibility.

### 4.5 Developer panel can be enabled by environment alone

The current developer greybox gate checks an environment variable. A release
process with that variable set could instantiate the panel. The new developer
target must require an explicit debug/developer build capability in addition
to any local opt-in, and it must not be a required dependency of the production
refresh port.

Developer snapshots must never be stored inside live/full/map snapshots,
public logs, save data, replay receipts or ordinary target state.

### 4.6 Map presentation is built from mutable domain state

`Main._set_map_view_data()` currently assembles map arguments from full
districts plus controller-specific marker helpers. Several helpers are already
careful—for example, city markers output “own/guess/unknown” instead of the
hidden owner, monster markers omit monster ownership, and route presentation
omits suppliers. The architectural boundary is nevertheless unsafe because
the builder can read all private fields.

The new map source must consume only:

- a public map projection;
- a viewer-private annotation projection bound to the viewer;
- the public visual-cue projection;
- the public optional-route projection;
- the public weather/solar projections.

It must not receive city owner truth merely to decide what to hide.

## 5. Forbidden keys and values

All public snapshots, victory presentation receipts and public-log receipts
must reject a key recursively when the normalized key equals or begins/ends
with a private pattern.

Minimum forbidden key families:

- rival economy: `cash`, `cash_cents`, `cash_ledger_cents`, `available_cash`,
  `escrow_cash`, private income/spend ledgers;
- hands/discards: `hand`, `hand_cards`, `hand_count`, `hand_size`,
  `ordinary_hand_count`, `discard`, `discard_choice`, `discard_card`;
- ownership truth: `hidden_owner`, `hidden_owner_id`, `true_owner`,
  `owner_truth`, `private_owner`, `owner_actor_id`, unrevealed
  `owner_player_index`;
- anonymous actor truth: `actor_player_index`, `source_player_index`,
  `submitted_by`, `played_by`, unrevealed queue `player_index`;
- private targeting: `private_target`, `target_player_binding`,
  `target_player_index` before public reveal, private target options/selection;
- AI and learning: `ai_plan`, `ai_reason`, `ai_utility_score`,
  `route_plan_score`, `pressure_bucket`, `decision_samples`,
  `learning_bonus`, candidate weights and score decomposition;
- internal lineage: transaction fingerprints, inventory instance IDs, private
  receipt IDs, hidden source installation/factory/facility IDs, save owner
  keys and replay lineage not explicitly public;
- obscured commodity identity: `card_id`, `commodity_id`, exact commodity/name
  key, rank, art key, effect fields, tooltip, accessibility text, focus/action
  identifiers capable of reconstructing the obscured card.

Text values must also reject or replace private sentinels. Key filtering alone
is insufficient because free text can include a player name, exact card name,
exact cash or owner truth.

## 6. Typed snapshot allowlists

The exact class names may follow repository conventions, but each output must
validate exact or explicitly extensible fields. A universal
`apply_anything(kind, Dictionary)` is not acceptable.

### 6.1 Public live fragment

Allowed:

- `schema_version`, `visibility_scope = public`, public `source_revision`;
- public table phase/state and public clock/countdown values;
- public weather summary;
- public selected-region label and public region status;
- sanitized public card-track entries;
- public forced-decision summary for non-deciding seats;
- public action availability that reveals no private cause;
- allowlisted public log entries.

Forbidden:

- any exact player cash or hand fact;
- private purchase eligibility;
- private target/discard actions;
- `is_viewer_card`;
- raw queue entries or raw skills;
- developer diagnostics.

### 6.2 Viewer-private live fragment

Allowed only after viewer/subject authorization:

- routing envelope: `visibility_scope = viewer_private`,
  `viewer_player_index`, `subject_player_index`, `viewer_revision`;
- that player's exact cash/GDP/goal progress;
- that player's hand card viewmodels and legal action state;
- that player's discard/target/contract response surface;
- that player's purchase quote/status;
- that player's private map guesses and selected-card state.

The target must validate the same viewer binding before applying. A
viewer-private fragment must never be embedded in a public fragment, public
log, map-public cache or developer cache.

### 6.3 Public/full table fragment

Allowed:

- public live fields;
- public right-inspector context;
- public facility type/rank/ownership where the v0.6 rule declares facility
  state public;
- public economic aggregates and public victory progress;
- public card/rack facts already released by their domain owners.

Private current-player detail must remain a separately tagged
viewer-private fragment even if the UI applies public and private fragments in
one frame.

### 6.4 Map snapshot

Allowed public fields:

- public region ID/index, geometry/center, terrain, integrity/ruin state;
- public facility facts authorized by the region-infrastructure projection;
- public weather and solar facts;
- public monster/military position, appearance, state and revealed identity;
- public visual cues/callouts;
- public selected product and actual/recent route summaries from
  `OptionalRoutePresentationRuntimeService`;
- public selection/focus state.

Allowed viewer-private fields:

- only the viewer's own city/ownership marker;
- only the viewer's private city guesses/notes in a separately scoped layer.

Forbidden:

- hidden city/monster/unit owner truth;
- supplier/player identity on commodity routes;
- route candidates and future plans;
- private economic attribution;
- AI targets, scores or path plans.

### 6.5 Developer snapshot

Allowed only for a debug-gated target:

- aggregate balance metrics from
  `GameplayBalanceDiagnosticsRuntimeService` or an equivalent typed service;
- source revision and diagnostic version;
- test/dev health counters.

Forbidden even in developer presentation unless the diagnostics contract
explicitly authorizes and sanitizes it:

- rival raw hand/card objects;
- private player cash ledgers;
- private owner truth;
- AI decision samples and exact score decomposition.

The developer snapshot may be richer than player presentation, but it is not a
back door around domain privacy ownership.

## 7. Victory presentation receipt allowlist

The new `VictoryPresentationStateChangeReceipt` should contain exactly:

- `schema_version`;
- a public receipt/event ID that cannot be correlated to private transaction
  lineage;
- monotonic `revision` and `sequence`;
- `visibility_scope = public`;
- `change_kind` from a closed enum;
- public state (`idle`, `qualification`, `audit`, `cooldown`, `resolved`);
- public player indices/names only when that identity is already public for the
  change;
- public region identifiers only when already public;
- qualification/audit/cooldown remaining time;
- public result/reason code;
- localization key;
- a closed, typed dictionary/record of formatting values;
- an `immediate_refresh_mask` enum/bitmask.

It must not contain controller internals, private assets, full candidates,
private qualification detail, hidden owner truth, anonymous card actor truth,
AI state, or complete outcome internals.

Exact cash is allowed only in the existing authoritative public-audit path
when all three facts agree:

1. `cash_visibility == public_audit`;
2. the player is in `audit_revealed_player_indices`;
3. the exact value comes from the Victory public projection.

No presentation code may infer cash visibility from `game_over`, winner status,
rank position, the existence of a cash field or session finish.

## 8. Public log receipt allowlist

A public log receipt should contain exactly:

- `schema_version`;
- public `event_id`, sequence and world-effective/public timestamp;
- `visibility_scope = public`;
- closed `event_kind`;
- localization key;
- closed formatting values validated for that event kind;
- optional public region/player/card identifiers only when the corresponding
  domain receipt explicitly reveals them.

It must not accept arbitrary message text from a domain controller. If legacy
text must be displayed during migration, it must be produced after a typed
event has passed its event-specific validator, not used as the authority.

Private feedback must use a separate viewer-private receipt and target. It is
not part of the public log exact-once count.

## 9. Obscured commodity rule

For an obscured commodity-belt entry the complete presentation allowlist is:

- public belt position/order;
- motion/progress needed to draw the belt;
- commodity color only;
- generic label such as `模糊的蓝色商品牌，尚不可领取`.

Forbidden recursively and in accessible text:

- card/commodity ID;
- exact commodity name or localization key;
- rank;
- art/sprite key;
- effect or price/quantity fields;
- tooltip revealing identity;
- accessibility text revealing identity;
- action/focus ID that encodes identity;
- stable internal instance ID;
- future belt sequence.

Blur, clipping or a face-down texture is not a privacy boundary. The hidden
fields must be absent from the snapshot before it reaches the target.

## 10. Serialization and cache rules

All snapshots and receipts must be detached values. Legal values are scalar
Godot variants required by the target (including `Color`/`Vector2` where
needed), arrays and dictionaries containing only legal values.

Forbidden anywhere in a snapshot/receipt:

- `Node`, `Object`, `Resource`, `RID` or `Callable` references;
- mutable world arrays/dictionaries shared by reference;
- scene paths used as service locators;
- function/method names used for dynamic dispatch;
- save-owner objects or controller references.

Every nested array/dictionary must be copied or newly constructed. Cache keys
may use public/source/viewer revisions, but not private transaction
fingerprints. Public and viewer-private caches must be separate and include the
viewer revision in the private cache key. Cache contents are presentation-only
and never saved or consumed by AI/gameplay.

## 11. Required automated privacy gates

The cutover test suite must include at least these cases:

1. public live source containing rival exact cash fails closed;
2. public live source containing rival hand cards fails closed;
3. public live source containing `hand_count`/`hand_size` fails closed;
4. public/full source containing rival discard selection fails closed;
5. map source containing `hidden_owner`, `true_owner` or `owner_truth` fails
   closed;
6. public card-track source containing the true anonymous actor fails closed;
7. public card-track source cannot reveal `is_viewer_card`;
8. private target-player binding cannot enter public snapshot/log;
9. AI plan, route score, pressure bucket, decision samples and learning bonus
   are rejected recursively;
10. obscured commodity entries contain only position/motion/color/generic copy;
11. obscured tooltip, accessible text, action ID and art key cannot reconstruct
    identity/rank;
12. viewer A private source applied to viewer B is rejected before target
    mutation;
13. viewer A cache is not reused for viewer B;
14. selection/inspection of rival B does not authorize B's private source;
15. public map exposes own/guess/unknown markers without hidden owner truth;
16. public optional routes expose no supplier, facility or inventory owner;
17. developer snapshot is not built/applied in a release/disabled target;
18. developer data never appears in live/full/map/public-log serialization;
19. victory state-change receipt contains only the exact allowlist;
20. unauthorized cash is absent even at game over/resolved state;
21. authorized public-audit cash requires visibility flag plus revealed roster;
22. public log rejects arbitrary Main/private text;
23. one public victory receipt produces exactly one public log entry batch;
24. duplicate/stale public log receipts do not append;
25. snapshots contain no Object/Node/Resource/Callable/RID;
26. snapshots are detached: mutating source state after compose does not mutate
    the target snapshot;
27. public track target defense-in-depth sanitizer remains green, but source
    tests prove forbidden keys were already absent;
28. negative source scans find no Main/current-scene/root service lookup.

The following Query-Ports-specific assertions are mandatory before the source
owner is allowed to bind a production target:

29. inject `Node`, plain `Object`, `Resource`, `Callable` and `RID` sentinels at
    every nested public/private district, card, intel, action and map boundary;
    the projection must reject or omit each sentinel recursively;
30. an unauthorized action query returns `authorized == false`, scope
    `denied`, the current authorization revision, and empty private payloads;
31. an authorized action projection carries the same authorization revision
    as the viewer context; changing that revision makes the old projection and
    its cache entry stale;
32. a projection built for viewer A cannot be applied to viewer B, even if A
    and B are both human seats or share the same selected district;
33. a public map snapshot built with A's private city guesses is never reused
    for B or for an unauthorized viewer;
34. `VictoryPresentationStateChangeReceipt` rejects direct and nested
    `cash`, `cash_cents`, `cash_ledger_cents`, `hand_count`, `hand_size`,
    `discard`, `private_target`, `target_player_index`, owner-truth and stable
    internal-ID sentinels;
35. exact victory cash is absent unless all three predicates hold: public-audit
    visibility, seat present in the revealed roster, and value originating in
    the authoritative Victory public projection;
36. public-log production rejects free-form private sentinels embedded in a
    `message` value, not merely forbidden dictionary keys;
37. private guess/intel/purchase/target feedback produces zero public-log
    entries and exactly one viewer-private feedback application;
38. production code has zero calls to `import_legacy_public_log`; a legacy
    saved message containing a private sentinel cannot enter the public log;
39. a duplicate public-log receipt remains rejected after more than
    `MAX_ENTRIES` newer rows have evicted its visible row;
40. public-log exact-once lineage remains effective after save/restore, if log
    receipts are part of the persisted presentation state;
41. obscured commodity fixtures prove that ID, name, rank, art key, tooltip,
    accessibility copy, action ID and stable instance ID are absent from both
    live and full target serialization;
42. developer diagnostics are not constructed when the debug-build capability
    is false, are not applied when the target is absent/disabled, and never
    appear in live/full/map/log payload hashes;
43. every snapshot serialized by the refresh port is detached; mutating a
    query-owner fixture after construction does not mutate an already-applied
    target snapshot;
44. `TablePresentationSourceOwner` and `TablePresentationRefreshPort` have no
    typed or dynamic dependency on `WorldSessionState`, domain controllers,
    Main, `current_scene`, `/root/Main`, debug snapshots or legacy log import.

Tests should use unique numeric/string sentinels for every forbidden field and
recursively search both keys and values. Merely searching source code for field
names is not sufficient.

## 12. Acceptance verdict

Privacy review can become **GREEN** only when all of the following are proven:

- no presentation source has direct access to complete mutable player or
  district state;
- public and viewer-private projections are separate typed contracts;
- viewer/subject/target equality is enforced twice (source and target/port);
- public card track is allowlisted before reaching `GameScreen`;
- public log no longer reads Main's mixed `log_lines` buffer;
- private feedback has a separate viewer-private path;
- developer target requires a non-release capability and remains optional;
- victory cash disclosure uses only the authoritative public-audit allowlist;
- obscured commodity snapshots are color-only;
- all outputs are detached pure presentation data;
- automated privacy violation count is zero.

Final source/target worktree verdict: **GREEN — PRIVACY VIOLATION COUNT 0**.
The five original blockers and the three final integration blockers are closed
without a Main fallback or a second public/private filtering path.

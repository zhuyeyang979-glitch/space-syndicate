# Intel private command contract

Audit baseline: `657f5172e7afa8c31658f90af5f81d076430bf5c`
Scope: analysis only; no production, scene, registry, save-schema, or test changes.

## Findings First

### [P1] The current Intel UI authorizes with table selection, not the local viewer

`scripts/main.gd` opens and mutates Intel data with
`TableSelectionState.selected_player` (`2500-2503`, `2531-2557`,
`2682-2698`). That value is presentation selection, while the existing
authorization owner is `LocalViewerAuthorization` through
`GameRuntimeCoordinator.presentation_authorized_viewer_index()`.
`CardHistoryPrivateAnnotationService.viewer_snapshot()` and
`apply_annotation()` accept any non-negative viewer index and do not perform
local-viewer authorization. The cutover must require:

`command.viewer_index == LocalViewerAuthorization.authorized_viewer_index()`.

Changing the inspected/selected seat must never grant access to that seat's
city guesses, card annotations, confidence, reasons, notes, tags, subscriptions,
or role-usage state.

### [P1] City inference has no command identity, stale-write guard, or exact receipt

`_mark_city_guess_for_player`, `_set_city_guess_confidence_for_player`, and
`_set_city_guess_reason_for_player` directly edit three dictionaries inside
`WorldSessionState.players`. They have no `command_id`, expected revision,
replay binding, typed receipt, or single save-dirty transition. Invalid
confidence and reason values are normalized instead of rejected; some invalid
targets clear existing state, violating failure-zero-mutation semantics.

`WorldSessionState` must remain the sole owner. Add a narrow owner API and an
owner-issued, viewer-private revision token derived from the canonical city
Intel records. Do not reuse `world_geometry_revision` as an Intel revision and
do not add a second Intel state store.

### [P1] The generic annotation patch can bypass role-evidence authority

`GameRuntimeCoordinator.apply_card_history_private_annotation(..., patch)`
forwards an arbitrary `Dictionary` to
`CardHistoryPrivateAnnotationService.apply_annotation()`. The service permits
caller-supplied `excluded_player_indices` and normalizes/truncates malformed
notes, tags, indices, and confidence. A caller can therefore manufacture the
result of public-evidence exclusion without consuming the role charge or
proving public evidence.

The new port must expose separate typed commands. Direct editing of
`excluded_player_indices` is forbidden; only `use_public_evidence_exclusion`
may change it, and the authoritative owner must derive the exclusion from the
public history snapshot. Likewise, `use_residual_frame_catalog` accepts no
caller-supplied suspect list.

### [P1] Two advertised role abilities have no durable usage authority

`RoleCatalogRuntimeService` advertises `intel_city_reveal_charges` and
`intel_contract_trace_charges`, but the only persisted Intel role usage in
`CardHistoryPrivateAnnotationService` is `residual_catalog` and
`public_exclusion`. No production UI consumer decrements or restores city
reveal or contract-trace role charges.

There are real *card effect* consumers named `intel_city_reveal` and
`intel_contract_trace` through
`CardEffectRuntimeRouter -> CardIntelRuntimeService`; these are authorized by a
committed card resolution and are not the advertised role-charge actions.
Do not expose either role action from `IntelDossier` until an existing
authoritative, recoverable usage owner is identified. Do not add usage fields
to the annotation save schema in this cutover.

### [P2] Facility-owner guessing is not a current rule or state

The v0.6 rulebook makes facility ownership public. The current private save
shape contains district-city records only:
`city_guesses`, `city_guess_confidence`, and `city_guess_reasons`, serialized as
`city_intel_records`. There is no facility-guess owner, field, UI caller, or
settlement consumer. `set_facility_guess` and `clear_facility_guess` must be
rejected as unsupported; this task must not invent them.

### [P2] A stale fixture still names retired card-owner wagering

Production has no card-owner stake, reward, penalty, payout, settlement, or AI
candidate path. `tests/smoke_test.gd:6708-6760` still fabricates
`card_owner_guess`, `guessers`, and `_ai_card_guess_candidate_for_owner` as an
old learning fixture. It is `LEGACY_FIXTURE`, not a production contract and not
a reason to restore any Main wrapper. The focused retirement gate remains
`tests/card_owner_guess_economy_retirement_test.gd`.

## Authority Map

| State or operation | Authoritative owner | Command boundary |
|---|---|---|
| City/district owner guess, confidence, reason | `WorldSessionState.players` | New narrow typed API called by `IntelPrivateCommandPort` |
| Public card history | `CardResolutionHistoryRuntimeService` through `CardHistoryPublicQueryPort` | Query only |
| Card note, tags, suspects, private confidence, exclusions, subscription | `CardHistoryPrivateAnnotationService` | Typed commands delegated by the port |
| Residual-frame/public-exclusion usage | `CardHistoryPrivateAnnotationService.role_usage_by_viewer` | Typed role commands; owner derives evidence |
| Local viewer identity | `LocalViewerAuthorization` | Required authorization for every dossier command |
| City-guess cash and role-bonus formula | Orphaned Main `_player_intel_stats`/summary chain; no production consumer or payout authority discovered | Retained only; never paid by the command port; settlement parity unresolved outside this page/action cutover |
| Intel card effects | `CardEffectRuntimeRouter -> CardIntelRuntimeService` and domain owners | Card-resolution producer only; not dossier UI commands |
| Contract party trace result | `WorldSessionState.players.known_contract_parties` via `ContractRuntimeController` | Existing committed card-effect path only |
| Save ownership | Session envelope v2 composite, with existing owners above | No new section or save owner |

## Current Untyped Surfaces

| Surface | Current shape | Required disposition |
|---|---|---|
| `IntelDossierBoard.action_requested` | `String action_id` | Replace with narrow typed UI intents |
| `IntelDossierPublicSnapshotService` | Builds prefixed IDs such as `intel_city_mark_*` | Return typed intent metadata, not encoded payload strings |
| `Main._on_intel_dossier_board_action_requested` | Prefix parser and arbitrary routing | Physically delete after cutover |
| `GameRuntimeCoordinator.apply_card_history_private_annotation` | Arbitrary patch dictionary | Remove from Intel UI route; delegate exact typed commands |
| `CardHistoryPrivateAnnotationService.apply_annotation` | Generic patch and normalization | Keep as owner-internal compatibility only or replace with exact methods |
| Main city helpers | Raw mutation of player dictionaries | Replace with `WorldSessionState` typed API; delete Main methods |
| `AIRuntimeController._mark_city_guess_for_player` | Dynamic `_call_world` to Main | Inject the same domain mutation owner for AI; do not route AI through local-viewer UI authorization |
| `CardIntelRuntimeService.apply_intel_effect` | `skill` and `context` dictionaries | Existing card-effect boundary; outside dossier cutover |

## Classification

### QUERY

- Open/refresh the dossier for the one authorized local viewer.
- Read public district/city evidence and own city inference records.
- Read `CardHistoryPublicQueryPort` and the authorized viewer's annotation
  projection.
- Read remaining residual-catalog and public-exclusion usage.
- Read public role definitions and public navigation links.
- Read the authorized viewer's saved contract trace results, if currently
  displayed.

All queries are data-only and must have zero world, RNG, save-dirty, selection,
public-log, role-charge, and annotation-revision deltas.

### PRIVATE_COMMAND

The commands accepted from `IntelDossier` are exactly:

1. `set_city_owner_guess`
2. `clear_city_owner_guess`
3. `set_city_guess_confidence`
4. `set_city_guess_reason`
5. `set_card_history_note`
6. `set_card_history_tags`
7. `set_card_history_suspects`
8. `set_card_history_private_confidence`
9. `set_card_history_subscription`
10. `clear_card_history_annotation`
11. `use_residual_frame_catalog`
12. `use_public_evidence_exclusion`

`intel_city_reveal`, `card_history_public_review`,
`card_history_subscription`, and `intel_contract_trace` also mutate private
Intel state, but their current production producer is committed card
resolution. They are not accepted from the dossier command port.

### APPLICATION_NAVIGATION

- `open_intel`, `close_intel`, and `return_to_intel`.
- Typed Compendium links for card, monster, product, and region.
- `ApplicationFlowPort.submit_action("economy")`.
- A card-track deep link may carry `focused_history_entry_id`; it must not
  change `TableSelectionState` merely to focus the dossier.

`history_return_<id>`, `intel_open_*`, `track_open_*`, and `track_intel_*` are
current action-string encodings, not command kinds.

### RETIRED

The following must remain physically absent from production command enums,
ports, UI actions, receipts, AI policies, and settlement:

- `track_guess_*`
- `card_owner_guess`
- `CARD_OWNER_GUESS_STAKE`
- `_card_owner_guess_stake_for_player`
- `_card_owner_guess_payout_for_player`
- `_guess_card_resolution_owner_for_player`
- `_ai_card_guess_candidates`
- `_ai_card_guess_candidate_for_owner`
- card-owner guess reward, penalty, stake, payout, GDP, or settlement
- `card_owner_guess_discount`, `card_owner_guess_bonus`,
  `intel_card_trace_charges`
- new runtime `guessers` ownership; legacy restore may only discard it
- `known_card_owners` as a production state path

Private card-history suspects and subscriptions are annotations, not wagers,
and never create cash, GDP, public broadcast, or final-settlement rows.

### LEGACY_FIXTURE

- The `tests/smoke_test.gd:6708-6760` card-owner learning block.
- Old source-negative strings that quote retired Main methods.
- Migration resources that describe pre-v0.6 Intel effect ownership.

These may be migrated or retired by focused test work; none are production
authority.

## Typed Request and Receipt

Create `IntelPrivateCommand` as a `RefCounted` value with exact root fields:

```text
schema_version: int = 1
command_id: String
command_kind: StringName
viewer_index: int
subject_id: String
expected_owner_revision: String
payload: typed value object for command_kind
```

Rules:

- `command_id` is non-empty, canonical, and bound to the complete request
  fingerprint.
- `subject_id` is `region:<region_id>` for city inference and
  `card-history:<resolution_id>` for history annotations.
- Array indices are not stable UI subject IDs. The owner may translate a
  region ID to the existing saved district index without changing the save
  schema.
- `expected_owner_revision` is an opaque token emitted by the viewer query.
  For city Intel it is derived from canonical viewer city records; for card
  annotations it binds the annotation revision and viewer projection. No new
  persistent revision owner is required.
- Payload objects have exact fields. Extra keys, dictionaries where typed
  values are expected, `Object`, `Node`, `Callable`, or non-data values fail
  closed.

Create `IntelPrivateCommandReceipt` with exact fields:

```text
schema_version, command_id, command_kind, viewer_index, subject_id,
accepted, applied, changed, idempotent_replay, reason_code,
owner_revision_before, owner_revision_after,
save_dirty_delta, role_usage_delta, notification_delta, public_log_delta
```

A success may include a viewer-private projection for the affected subject.
It must never include an opponent projection, hidden card actor, AI plan, or
raw owner object. A failed, stale, unauthorized, or binding-mismatch receipt
has every mutation delta equal to zero.

Replaying the same `command_id` with the same fingerprint returns the original
terminal receipt with `idempotent_replay=true`. Reusing the ID with different
content returns `command_binding_mismatch`. The port may keep a bounded runtime
receipt cache; owner revision tokens ensure a replay after restore is stale or
an unchanged no-op, without adding a second save owner.

## Command Contracts

### City inference

| Kind | Exact payload | Authorization and owner result |
|---|---|---|
| `set_city_owner_guess` | `suspected_player_index:int`, `confidence:int`, `reason_id:StringName` | Authorized local viewer; active foreign city; suspect valid and not viewer; confidence `1/2/3`; reason in `product/route/card/monster/role/intuition`; `WorldSessionState` writes all three existing fields atomically |
| `clear_city_owner_guess` | empty | Existing own record is removed from all three dictionaries atomically; missing record is unchanged success |
| `set_city_guess_confidence` | `confidence:int` | Existing guess required; exact allowlist `1/2/3`; no clamping |
| `set_city_guess_reason` | `reason_id:StringName` | Existing guess required; exact six-value allowlist; no fallback to `intuition` |

The manual commands never accept confidence `100`. That sentinel is reserved
for an authorized card-resolution reveal. Commands are rejected while the
session is finished. A changed success marks the existing session dirty once;
unchanged, replay, stale, and failure mark it zero times. No command pays the
city-guess reward. No production final-settlement payout owner or path was
discovered. The orphaned Main `_player_intel_stats`/summary formula is retained,
but settlement parity remains an unresolved authority gap outside this
page/action cutover.

There is no facility-guess command.

### Card-history annotation

| Kind | Exact payload | Owner validation |
|---|---|---|
| `set_card_history_note` | `note_text:String` | At most 240 characters; reject overflow instead of truncating |
| `set_card_history_tags` | `private_tags:Array[String]` | At most 8 unique canonical tags, each 1-32 characters |
| `set_card_history_suspects` | `suspected_player_indices:Array[int]` | Canonical, unique, in player range, no overlap with owner-derived exclusions |
| `set_card_history_private_confidence` | `private_confidence:int` | Exact `0/1/2/3` |
| `set_card_history_subscription` | `subscribed:bool` | Maximum 2 subscribed entries per viewer; `false` is unsubscribe |
| `clear_card_history_annotation` | empty | Clears the six durable fields together; public history is unchanged |

Every subject must exist in `CardHistoryPublicQueryPort`. Only the current
viewer bucket may be read or changed. These commands update only
`CardHistoryPrivateAnnotationService`, increment its revision once when
changed, and mark the session dirty once. They never update public history or
produce reward, penalty, payout, GDP, notification, or public-log entries.

### Evidence-limited role commands

| Kind | Exact payload | Authority |
|---|---|---|
| `use_residual_frame_catalog` | empty | Viewer must have `card_history_residual_catalog_charges`; owner derives a private suspect set from the public history entry; charge changes only when annotation changes; persisted usage key `residual_catalog`, max 2 |
| `use_public_evidence_exclusion` | empty | Viewer must have `card_history_public_exclusion_charges`; owner derives publicly impossible players and removes one deterministic existing suspect; charge changes only on a real exclusion; persisted usage key `public_exclusion`, max 3 |

The UI may provide only `history_entry_id`; it may not provide candidate,
impossible, excluded, or authoritative-owner arrays. No meaningful evidence,
already-revealed history, exhausted charge, missing suspect, or invalid role
returns failure with charge delta zero.

### Existing card-resolution Intel effects

These remain outside `IntelPrivateCommandPort` for this cutover:

| Effect kind | Current producer/owner | Private result |
|---|---|---|
| `intel_city_reveal` | `CardEffectRuntimeRouter -> CardIntelRuntimeService -> WorldSessionState` | Writes owner as confidence `100`; viewer-private only |
| `card_history_public_review` | Card effect -> annotation owner | Creates private review from public history |
| `card_history_subscription` | Card effect -> annotation owner | Subscribes up to the card-defined count and owner limit |
| `intel_contract_trace` | Card effect -> `ContractRuntimeController` / `WorldSessionState.known_contract_parties` | Viewer-private contract parties |

They must not become dossier buttons merely because their strings contain
`intel`. The identically described role-charge variants for city reveal and
contract trace are blocked until a durable usage owner exists.

## Required Main Deletions

After typed production consumers are connected, physically delete these Intel
routes from `scripts/main.gd` rather than retaining fallback branches:

- `IntelDossierBoardScene` preload
- `_open_intel_dossier_menu`
- `_populate_intel_dossier_snapshot`
- `_add_intel_dossier_board_panel`
- `_on_intel_dossier_board_action_requested`
- `_intel_dossier_public_snapshot`
- `_intel_dossier_public_source_snapshot`
- `_mark_city_guess_from_intel`
- `_set_city_guess_confidence_from_intel`
- `_set_city_guess_reason_from_intel`
- `_intel_city_guess_entries` and Intel-only sort/priority/label wrappers after
  real consumers move
- `_intel_card_guess_entries` and `_sort_intel_card_guess_entry`
- `_mark_city_guess_for_player`, `_set_city_guess_confidence_for_player`, and
  `_set_city_guess_reason_for_player` after human and AI consumers use the
  owner API
- dead `_reveal_city_owner_by_intel_card` and `_apply_intel_city_reveal`
- `codex_intel`, quick-nav `intel`, `track_intel_*`, and Intel board prefix
  routing in Main
- `selected_guess_player` and Intel-only constants/preload when all remaining
  consumers are migrated

Do not delete the orphaned Main city-guess formula in this page/action cutover.
No production consumer or payout authority was discovered; retaining the
formula does not establish settlement parity. That authority gap remains
unresolved and outside this cutover. Also retain the existing save fields,
public clue helpers, economy evidence helpers, CardIntelRuntimeService, and AI
decision algorithms. AI's dynamic Main mutation adapter must be rewired to the
same domain owner without changing AI scoring.

## Focused Negative Tests

Every rejection below must assert city records, annotations, role usage,
owner revision, session dirty state, notification count, public log, cash, GDP,
and RNG are unchanged:

1. Invalid viewer: negative, out of range, AI/opponent seat submitted through
   local UI, or selected-seat spoof.
2. Invalid subject: malformed stable ID, missing region/history ID, ruined or
   inactive city, own city, public facility subject, or mismatched subject kind.
3. Invalid payload: missing/extra keys, wrong types, nested private owner,
   `Object`, `Node`, `Callable`, oversized note/tag, duplicate/noncanonical
   arrays, and suspect/exclusion overlap.
4. Invalid city suspect: out of range or equal to viewer.
5. Invalid manual confidence: `0`, `4`, `100`, float, or string.
6. Invalid reason: empty, unknown, wrong case, or padded value; no automatic
   fallback.
7. Stale `expected_owner_revision`: fail closed before owner mutation.
8. Replayed command ID: same fingerprint returns idempotent receipt; different
   fingerprint returns binding mismatch.
9. Session finished: every dossier private command is rejected; settlement is
   not recalculated and private notes remain private.
10. Unauthorized role ability: wrong role, exhausted charge, missing public
    evidence, already-revealed entry, or no eligible suspect preserves charge.
11. Third subscription: `subscription_limit_reached`, mutation zero.
12. Public-evidence exclusion with caller-supplied impossible/excluded indices:
    payload rejected.
13. Residual catalog with caller-supplied candidate list: payload rejected.
14. Viewer isolation: A's success is absent from B's query, tooltip,
    accessibility text, debug snapshot, and serialized UI snapshot.
15. Exact-once success: one owner mutation, one private receipt, one refresh,
    one UI apply, and one save-dirty mark.
16. Queries and application navigation: zero gameplay and selection mutation.
17. Retirement scan: all card-owner guess/reward/penalty/stake/payout/settlement
    tokens remain absent from production, while the orphaned city-guess formula
    remains retained and settlement parity stays explicitly unresolved.

## Cutover Decision

The typed command split is implementable without a new state or save owner for
the 12 dossier commands listed above. It is **not** safe to expose city-reveal
or contract-trace *role-charge* buttons in this atomic cutover because no
durable usage authority currently exists. Existing committed card effects may
continue through their current owners.

Required target counts:

- `INTEL_TO_MAIN_ROUTE_COUNT=0`
- `GENERIC_INTEL_APPLICATION_ROUTE_COUNT=0`
- `MAIN_INTEL_FALLBACK_COUNT=0`
- `SECOND_INTEL_STATE_OWNER_COUNT=0`
- `SECOND_INTEL_SAVE_OWNER_COUNT=0`
- `CARD_OWNER_GUESS_PATH_COUNT=0`
- failure mutation/dirty/charge/public-log deltas all `0`

# AI Raw-Read Ratchet Batch 1

## Delivery Status

- Status: `AI_VIEWER_PRIVACY_AND_RAW_READ_RATCHET_BATCH1_GREEN`
- Production scope: R03/R04 direct player-interaction scoring only.
- Production AI semantic cutover: `BATCH1_INTERACTION_OBSERVATION_ONLY`.
- Production UI semantic cutover remains `CODEX_ONLY`.
- RulesProjection and full-game semantic cutover remain false.
- Next atomic boundary: `SAMPLE_FULL_RUN_VERTICAL_SLICE_TO_SETTLEMENT`.

## Scope

- Program: `AI_VIEWER_PRIVACY_AND_RAW_READ_RATCHET_BATCH1`
- Integration baseline: `56b572ac8b1d52ae71a43c53dfc7a4d875d7282b`
- Historical origin: `reports/cards/ai_direct_field_read_migration.json`
- Historical report policy: immutable; it remains the original `225/5/33/71` inventory.
- Batch boundary: report rows `R03` and `R04` only.

This report is the current monotonic lock. It does not rewrite the historical audit and does not claim a full parser or taint-analysis gate. The `219/5/31/69` lock applies specifically to direct reads in `AiRuntimeController`; it is not a claim that the six legacy reads vanished from production.

## Exact Ratchet

| AI consumer metric | Historical origin | Batch 1 lock | Delta |
| --- | ---: | ---: | ---: |
| Raw value reads | 225 | 219 | -6 |
| Presence checks | 5 | 5 | 0 |
| Functions containing raw reads | 33 | 31 | -2 |
| Distinct raw keys | 71 | 69 | -2 |
| Static semantic/identity reads | 214 | 208 | -6 |
| Live instance or evaluation reads | 11 | 11 | 0 |

The scanner constructs the current expected AI-consumer signature map from the historical allowlist and then removes the six signatures below. It requires exact equality. A removed AI signature cannot return, an unlisted signature cannot appear, and the AI debt cannot grow back to the historical ceiling.

The behavior-preserving bridge intentionally retains six reads at the attested source owner:

| Scope | Value reads | Presence | Functions | Keys |
| --- | ---: | ---: | ---: | ---: |
| `AiRuntimeController` consumer | 219 | 5 | 31 | 69 |
| Source-owner compatibility bridge | 6 | 0 | 1 | 6 |
| Combined historical AI-policy read ledger | 225 | 5 | 32 | 71 |

This batch therefore classifies R03/R04 as `MOVED_FROM_AI_TO_ATTESTED_OWNER_BRIDGE`. The production value-read total has a net delta of zero. The architectural gain is that AI no longer receives or interprets the raw card carrier; the six temporary reads are capability-bound, slot-attested, fingerprinted, and isolated in one reviewed owner function.

The combined ledger is scoped to the historical AI-policy audit. It is not an exhaustive count of the adapter's dynamic exact-definition attestation reads.

## Removed Reads

| Origin | AI function | Removed AI raw field | Authorized policy field |
| --- | --- | --- | --- |
| R03 | `_ai_actor_private_receive_pressure` | `steal_fail_cash` | `policy_steal_failure_cash` |
| R04 | `_ai_direct_player_interaction_plan` | `kind` | `policy_interaction_kind_id` |
| R04 | `_ai_direct_player_interaction_plan` | `hand_discard_count` | `policy_discard_count` |
| R04 | `_ai_direct_player_interaction_plan` | `hand_steal_count` | `policy_steal_count` |
| R04 | `_ai_direct_player_interaction_plan` | `hand_lock_seconds` | `policy_lock_duration_microseconds` |
| R04 | `_ai_direct_player_interaction_plan` | `target_cash_penalty` | `policy_cash_penalty` |

`steal_fail_cash` and `target_cash_penalty` disappear from the AI consumer key set, but no key is globally retired in this batch. All six source keys remain in the single `_legacy_interaction_policy_facts` compatibility function. The other four also remain historical AI debt in unrelated functions.

## Semantic And Policy Split

The observation carries two explicitly different channels:

- `semantic_*` fields are derived from the catalog-owned `CardSemanticSpec.effect_ops`; their values do not affect Batch 1 numeric scoring.
- `policy_*` fields are derived from the exact current authoritative slot shape under compatibility ID `legacy_ai_card_interaction_flat_fields_v1`.
- Batch 1 scoring reads only `policy_*`, preserving the old absent-field defaults and existing scores.
- A valid interaction semantic operation shape is still required to issue the observation. Runtime readiness metadata does not gate scoring, and `projection_only` readiness is not promoted.
- Activating semantic values for scoring is an intentional later behavior-versioning task, not part of this migration.

The bridge may be removed only after its call count reaches zero and a separately approved scoring migration proves candidate, score, ordering, selection, RNG, Save, and actor-memory parity, or explicitly versions the intended behavior change.

The genuine v0.4 compatibility route is observation-only. Generic `authorize_own_hand_card()` continues to reject flat v0.4 records. The specialized route attests all current authoritative definition fields except the documented obsolete `play_flow_required` gate, permits only 14 reviewed runtime-only keys, resolves one of eight frozen SHA-256 identity references, and requests a closed interaction-effect witness from the sealed semantic catalog. Unknown `future_private_value` and case-variant `Effect_Payload` additions fail closed. It does not return a complete v0.6 `CardSemanticSpec`, claim v0.4/v0.6 cost equivalence, promote readiness, create a RulesProjection, or alter execution. The eight hashed localized identities remain explicit temporary debt even though no name or rank parser is used.

## Architecture Lock

- Exactly one `AiCardInteractionObservationService` is composed in `GameRuntimeCoordinator.tscn`.
- The Coordinator prebinds the service and one opaque consumer capability per actor in parent `_enter_tree()` before child lifecycle callbacks.
- `AiRuntimeController` may consume that service.
- Only `ai_card_interaction_observation_service.gd` may call the own-hand source authorization API.
- `AiRuntimeController` may not reference or call `CardSemanticSourceAuthorizationPort` directly.
- Production code may not call `AiCardSemanticProjectionService`, `project_authorized_source`, or `project_candidates`.
- The new interaction observation production files may not contain raw skill/card/payload carriers, catalog lookup, Save, RNG, Main, RulesProjection, or handler-registration tokens.
- The six compatibility reads are allowed only on receiver `card` inside `_legacy_interaction_policy_facts`; a multiline-aware scanner locks each key to exactly one read, zero presence checks, and zero dynamic-key access.
- The service has two reviewed CardSemanticSpec adapter reads: `op.get("target_cash_penalty")` and `op.get("steal_fail_cash")`. They are accepted only on a schema-validated semantic operation and are immediately renamed to canonical observation fields. Every other historical raw-key literal is forbidden in the new production files.
- Observation creation and current-source revalidation both require the opaque consumer capability. Rejected null/forged validation performs zero source queries and does not mutate the issued-observation journal.

Each consumer capability is actor-scoped, and aliased token identities are rejected. A token issued for one actor cannot observe or revalidate another actor's slot, while every returned observation remains actor/session/slot-attested and viewer-labeled. The Coordinator and singleton `AiRuntimeController` intentionally hold the complete actor-to-token map, so this is a call-boundary guarantee, not seat isolation inside that trusted multi-seat consumer or against arbitrary hostile in-process reflection.

## Unresolved Debt

The post-batch AI-consumer ledger remains **219 value reads, 5 presence checks, 31 functions, and 69 keys**. Of the value reads, 208 are static semantic or identity debt and 11 are live instance/evaluation reads. The isolated source-owner policy bridge accounts for another six reads in one function. Thirty-one historical migration rows remain.

Market, weather, city-control, futures, generic-effect, instance-state, and role reads still require their own authorized typed contracts and parity evidence. This batch does not broaden into those domains.

## Scanner Boundary

The semantic debt scanner remains the source of the exact `219/5/31/69` AI
consumer metric. A second receiver-independent token scanner now protects that
ledger against structural bypass: it scans all 561 project production
GDScripts under `res://`, excluding `tests`, `tools`, `addons`, `reports`, and
`scripts/tools`. Every direct literal `.get`, `.has`, and bracket access enters
the lock, including unknown future keys, raw strings, StringName literals, and
multiline forms. Its stable signature includes path, function, key, access
form, normalized receiver, and normalized access expression.

The closed structural lock contains 30,076 occurrences, 25,992 distinct
signatures, 4,567 distinct literal keys, 454 files, and all 71 historical keys.
Its `bracket/get/has` counts are `3502/26179/395`, key-set fingerprint is
`c0273aa2997564ed18f232b18fcd60204f625948aa09797f26abe0c049a41617`,
and structure fingerprint is
`343d3d8b7ae56a8049c4937f1efbca7744d0fafc5d03419350737fc41ba07927`.
Receiver renaming, resource/helper relocation, unknown keys such as
`future_private_value`, multiline access, `payload["kind"]`, `r"kind"`, and
`&"kind"` all change the lock and fail the scanner. This project-production
inventory is a structural guard, not a claim that all 30,076 sites are AI raw
reads.

The scanner still does not claim arbitrary data-flow or reflection analysis.
Computed keys and runtime-generated payload provenance require a future parser
or taint-analysis boundary; current AI dynamic-key access remains separately
locked to its one audited four-field loop.

## Production Data Flow

```text
AiRuntimeController._ai_card_play_candidates
  -> AiCardInteractionObservationService
  -> AiActorHandInventoryQueryPort capability-bound slot attestation
     -> v0.6: CardSemanticSourceAuthorizationPort
        -> catalog-owned complete CardSemanticSpec
     -> v0.4: specialized observation-only source authorization
        -> exact v0.4 Owner definition + one of eight hashed references
        -> CardSemanticCatalogService closed interaction-effect witness
  -> owner-attested policy compatibility profile
  -> AiCardInteractionObservationV1
  -> unchanged legacy scoring arithmetic
```

Exactly one observation service is scene-composed. It holds the Coordinator-bound
actor capability map; `AiRuntimeController` holds the actor-scoped consumer capability map but
neither actor source capabilities nor a reference to `CardSemanticSourceAuthorizationPort`. No second hand, instance,
RNG, Save, or world-state owner was added.

Generated source requests are bounded by actor and slot. A changed hand-source
revision retires the previous generated binding before registering the next one.
The generated request-ID namespace is reserved from explicit callers, so a
retired generated ID cannot be rebound with different content. Explicit caller
IDs retain their original collision semantics.

## Behavior Parity

The real production `_ai_card_play_candidates()` path is frozen for four
authoritative carrier shapes:

| Carrier | Candidates | Scores | Ranked slots | Observation attempts |
| --- | ---: | --- | --- | ---: |
| exact raw v0.6 record | 2 | `103, 103` | `0, 1` | 0 |
| production adapter output | 2 | `103, 103` | `0, 1` | 0 |
| owner-attested legacy flat carrier | 2 | `512, 998` | `1, 0` | 2 |
| genuine v0.4 Owner restore carrier (`星链拆解1`, `影仓牵引4`) | 2 | `536, 1106` | `1, 0` | 2 |

Each case compares full candidate dictionaries and frozen fingerprints against a
pre-Batch-1 oracle. Forced and normal production selection are unchanged. Normal
selection consumes the same one RNG draw on both sides; candidate generation
consumes zero draws. World Save data, AI Save data, and actor memory remain
unchanged.

For the genuine v0.4 carrier, normal and forced selection choose slot 1, observation attempts/success/rejection are `2/2/0`, compile delta is 0, and normal selection terminates at `{schema_version: 1, draw_count: 1, rng_state: 4331395523003180704}`. All eight references have source/observation compatibility coverage, while the full production scoring golden deliberately covers two representatives; no 8/8 scoring claim is made.

`WorldSessionState.restore()` is used to establish the genuine flat Owner carrier. That proves current-owner compatibility, not old Save-envelope migration. Current Save handshake behavior still rejects old v0.4 envelopes; no Save migration is implemented.

The raw v0.6 and current production-adapter carriers intentionally bypass the new
interaction branch because the existing production eligibility shape does not
classify them as direct player-target carriers. Batch 1 does not change that
legacy behavior. The owner-attested legacy carrier proves the new production
observation path is live.

## Validation Evidence

| Gate | Result | Focused duration |
| --- | --- | ---: |
| observation adversarial schema/privacy | PASS, `432/432` | 1.415 s |
| genuine v0.4 compatibility | PASS, `84/84` | 1.152 s |
| real candidate/scoring parity | PASS, `331/331` | 13.907 s |
| source authorization and generated-ID collision | PASS, `198/198` | 3.093 s |
| architecture and raw-read scanner | PASS, `271/271` | 7.858 s |
| Codex/global ratchet invariant | PASS, `59/59` | 9.119 s |
| actor hand typed port | PASS, `93/93` | runner 6.864 s |
| public player facts typed port | PASS, `128/128` | runner 6.512 s |
| authorized projection integration | PASS, `14/14` | 5.521 s |
| source authorization Bench | PASS, `39/39` | 4.833 s |
| interaction observation Bench | PASS, `31/31` | 9.611 s |
| Main runtime composition | PASS | runner 12.542 s |
| Godot 4.7 MCP observation Bench | PASS, `31/31`; final compile recheck `486/486` with 0 script errors | 10.684 s |

The first authorized-projection integration invocation hit its existing
100-versus-400 timing-ratio assertion once. The immediately following direct
Bench and integration rerun passed without changing code or timeout. This is
recorded as timing variance, not hidden by a larger timeout.

The scanner process emits seven pre-existing `Unexpected NUL character` diagnostics;
the final scoring run emits four.
The public-player facts test also retains its pre-existing ObjectDB/resource exit
warnings. Focused runner audits report zero script/runtime errors, and scoped
runtime processes are cleaned after each run.

## Performance And State

- Source authorization Bench, 400 cached bundle builds: `2438.881 ms`.
- Source authorization Bench, 400 authorized projections: `1799.355 ms`.
- Authorized/direct fixture ratio: `6.449x`, below the frozen `10x` gate.
- Interaction observation Bench manual/raw policy slice, 400 iterations: `1.170 ms`.
- Interaction observation Bench authorized path, 800 observations: `9065.118 ms`,
  `11.331 ms` average per observation.
- The micro ratio is `7747.964x` because its unsafe baseline performs only six
  dictionary reads; it is disclosed, not used as the end-to-end regression gate.
- The end-to-end gate alternates frozen legacy and authorized candidate loops on
  the same genuine v0.4 two-card fixture for 20 iterations. Legacy took
  `124.662 ms` (`6.233 ms/iteration`), authorized took `388.157 ms`
  (`19.408 ms/iteration`), and the unrounded ratio passed the strict `<10x`
  guard at a reported `3.114x`; candidate parity was `20/20`.
- Complete production two-card carrier checks ran in `1002.044-1656.607 ms`.
- Bench counters: 803 observations, 805 source authorizations/cache hits, 1610
  source revalidations, and 2415 hand queries.
- Candidate-loop semantic compile delta: `0`.
- Semantic catalog remains 348 compiled entries; no catalog reload occurs in the
  candidate path.
- Save Registry remains 19 sections with zero semantic section.
- Save migration implemented: false; old v0.4 Save envelope supported: false.
- Main responsibility delta: zero.
- Godot MCP used `4.7-stable (official)` at the exact worktree, compile-checked
  486 GDScript files with zero errors, observed exactly one production
  observation service, and returned a live `PASS` result snapshot. The Bench
  run's error log was empty. The final post-scanner compile recheck logged seven
  environment diagnostics: three shader-cache directory errors and four
  pre-existing Unicode NUL diagnostics; task script/runtime errors remained zero.
  The final scene stopped with `is_playing_scene=false` and left zero project
  Godot processes.

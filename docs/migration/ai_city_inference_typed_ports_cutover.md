# AI City Inference Typed Ports Cutover

## Status

`STATUS=AI_ACTOR_SCOPED_REGION_QUERY_ATOMIC_CUTOVER_VALIDATED`

This is one completed atomic domain inside the still-active
`P0-AI-WORLD-TYPED-PORTS-CUTOVER`. It does not claim that all AI world access,
Alpha 0.1, full-run resume, or Alpha 0.3 is complete.

## Rule Authority Gate

- `RULE_AUTHORITY_GATE=GREEN`
- `MECHANIC_ID=ai_city_inference_typed_port_migration`
- `MECHANIC_STATUS=MIGRATION_ONLY`
- Authoritative rule files: `AGENTS.md`, `docs/ai_runtime_ownership_contract.md`,
  `docs/migration/intel_private_command_contract.md`, and
  `docs/migration/intel_privacy_save_boundary.md`
- Player-facing meaning: an AI may inspect public city evidence and its own
  private owner guesses, then update only its own guess, confidence, and reason.
- Authoritative owner: `WorldSessionState`
- Persistence: the existing session envelope v2; no new section or schema.

No rule, payout, role passive, city ownership rule, or inference value was
added. This PR only replaces a generic Main/world route with typed ports.

## Production Path

`GameRuntimeCoordinator` composes one `AiActorStatePort`, one
`AiRegionKnowledgeQueryPort`, and one `AiCityInferenceCommandPort`. It creates
one opaque capability per current AI seat and injects the actor-indexed map into
`AiRuntimeController`. Roster replacement, World restore, and GameSession
identity changes revoke the old map and issue fresh tokens.

The migrated path is:

1. `AiRuntimeController` requests an actor-scoped intelligence snapshot.
2. `AiRegionKnowledgeQueryPort` returns detached pure data.
3. Existing candidate scoring and ordering run without Main or whole-world
   reads in the five city-inference production functions.
4. `AiCityInferenceCommandPort` validates capability, command identity,
   actor, region, revision, and payload.
5. `WorldSessionState.set_city_owner_guess` performs the authoritative change.

`AiRuntimeWorldBridge.apply_city_owner_guess` and the eleven city-inference
constants in `main.gd` were deleted. There is no fallback or dual path.

## Query And Privacy Contract

The query may expose only:

- public region identity, geometry, terrain, damage, panic, products, demands,
  transport facts, public city activity, public clues, and public GDP;
- the requesting actor's own warehouse count, units, and product names;
- the actor's own city ownership inference, confidence, reason, and authorized
  reveal sentinel;
- the actor's own city as `actor_own`.

Public and rival city rows contain no warehouse count, units, or product names.
The actor's own city may contain those three fields, while warehouse owner,
bucket identity, source installation, transaction identity, debt, remainder,
liability, and expiry remain excluded everywhere.

The query never exposes authoritative hidden owner truth, another actor's
guess, exact rival cash, rival hand/discard, private warehouse ownership, AI
memory, or plan. Every returned collection is detached pure data. Queries
consume no RNG and perform no world mutation.

Public clue dictionaries are rebuilt from the explicit `text`, `time`,
`cycle`, `kind`, and string-only `products` allowlist. Arbitrary pure-data keys
are not copied, and `last_public_clue` is reduced to its sanitized text.

## Whole-Region Consumer Completion

All AI production consumers now iterate the detached region projection instead
of reading the live `WorldSessionState.districts` collection. City lookup is
actor-scoped: the result carries the authoritative owner only for the actor's
own city, otherwise it carries that actor's saved inference or `public_unknown`.

Public route evidence is reduced to route count plus active/disrupted product
names. Raw route rows, facility identity, hidden owner, capacity resources,
rent recipients, and topology fingerprints do not enter candidate scoring.
Per-city warehouse fields are actor-private. Removing their former rival-city
contribution is the explicit `PRIVACY_CORRECTION` in this follow-up.

The futures characterization now starts through
`ProductionSessionStartDriver` and the formal session-start transaction. It no
longer calls retired `Main._new_game` or mutates `TableSelectionState`. The
fixture also freezes the current catalog rule: futures cards may be fixture-owned
and played, but they are not legal RegionSupply acquisition cards.

## Command Contract

Each command binds:

- stable command ID and SHA-256 payload fingerprint;
- an opaque capability issued only for the command's AI actor;
- AI actor index;
- stable region ID;
- suspected player index, confidence, and reason allowlists;
- expected `WorldSessionState` owner revision.

The bounded journal retains 128 receipts. Same ID and same fingerprint returns
the original receipt with `idempotent_replay=true`; same ID with a different
fingerprint fails closed. Stale revisions, forged capabilities, human actors,
eliminated actors, non-running sessions, missing regions, and invalid values
produce zero mutation.

The journal is scoped to the existing `GameSessionRuntimeController` session
identity. It is cleared when the session changes, the WorldSession emits a
restore/reset boundary, or actor capabilities are rebound. A token issued for
AI A cannot query or command AI B, and a restored world cannot receive an old
success receipt without the mutation being applied to the current owner state.

## Behavior Parity

- Six personality resources and candidate selection remain unchanged.
- Query and command code draw no RNG, so RNG order is unchanged.
- City candidate iteration and score comparison retain their algorithms.
- Warehouse scoring values `34`, `8`, and `10` moved from Main constants to the
  existing AI policy Resource without changing values; they now consume only
  the actor's own warehouse facts.
- The representative rival-city priority changes from `84` to `54` solely
  because the forbidden warehouse input is absent. This is a
  `PRIVACY_CORRECTION`, not a balance change.
- Guess, confidence, and reason continue to cold-roundtrip through the existing
  `WorldSessionState` session-envelope payload.

## Evidence

- Focused SceneTree test: 57/57.
- Commodity futures production fixture: 39/39.
- Market/route public query ports: 15/15.
- Card phase/counter owner regression: 22/22.
- AI business transaction regression: 68/68.
- Production scene Bench: 14/14, privacy leaks 0, duplicate mutations 0.
- Godot MCP script scan: 206 GDScript files, 0 parser errors.
- `main_runtime_composition_test.gd`: pass.
- `world_session_state_cutover_test.gd`: pass.
- `ai_business_cost_architecture_gate_test.gd`: pass.
- `git diff --check`: pass.

The original cutover moved Main from 6481 physical / 5456 nonblank / 473
methods / 58 constants to 6461 / 5436 / 473 / 47. At this privacy follow-up,
Main is 6373 physical / 5356 nonblank / 468 methods / 47 constants, with 102
external caller files and no new caller.

## Remaining P0 Scope

This atomic cutover does not satisfy the parent hard gate. Whole-player and
whole-district collection access are both zero, but the controller still has 15
`_call_world` call sites and 33 `_call_monster` call sites for other domains.
The generic
bridge and human `TableSelectionState` coupling therefore remain active parent
work. The next atomic boundary is card query/target submission and selection
retirement, followed by monster, military, weather, victory, and presentation
ports until every parent count reaches zero.

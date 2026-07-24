# AI Actor City Authorization Typed-Port Migration

## Status

`STATUS=AI_ACTOR_CITY_AUTHORIZATION_TYPED_PORT_MIGRATION_VALIDATED_CANDIDATE`

This is one narrow atomic domain inside the active
`P0-AI-WORLD-TYPED-PORTS-CUTOVER`. It does not claim the parent P0, a complete
match, Alpha 0.3 completion, or full-run resume.

## Production Cutover

The existing `AiRegionKnowledgeQueryPort` now publishes a strict actor-private
city-authorization row for every district. `AiRuntimeController` consumes one
bulk authorization snapshot together with the already-typed public district
snapshot in eight safe leaf consumers.

No new port, capability, owner, query cache, save field, or save section was
created. `V06SaveOwnerRegistry` remains at 19 sections. `WorldSessionState`
continues to own city truth and private inference state.

The cutover distinguishes `public_unknown`, `actor_own`, `actor_guess`, and
`authorized_reveal`. A guess is a private belief and is never used as proof of
ownership. Only `actor_own` can classify a city as owned by the requesting AI.

## Privacy And Failure Policy

- Hidden foreign owner changes leave an unknown row byte-equivalent.
- The same hidden truth change leaves all eight migrated outputs unchanged.
- Another actor's guesses, confidence, reason, AI memory, and plan are absent.
- Human, eliminated, forged, null, and invalid actors fail closed.
- Missing typed dependencies produce empty or zero results; there is no Main or
  raw-city fallback.
- Query calls mutate no WorldSession state and consume zero RNG.

## Scope Limit

Mixed route, market, supply, monster, weather, military, Victory, and card
consumers remain deferred. Their ownership contracts are not widened by this
change, and no full AI-world isolation claim is made.

## Main Budget

`scripts/main.gd` is unchanged.

| Metric | Before | After | Delta |
| --- | ---: | ---: | ---: |
| Physical lines | 6433 | 6433 | 0 |
| Nonblank lines | 5415 | 5415 | 0 |
| Methods | 469 | 469 | 0 |
| Fields | 46 | 46 | 0 |
| Constants | 45 | 45 | 0 |
| Preloads | 7 | 7 | 0 |
| External caller files | 103 | 103 | 0 |

The budget tool's historical absolute threshold remains `103 > 102` on both
clean `ad3b318` and this candidate. This task adds no Main caller or reference.

## Verification

- Focused: `128/128 PASS`, run
  `20260724-191654-216-ai_actor_city_authorization_typed_port_migration_test-59993dc4`.
- Godot MCP production scene Bench: `24/24 PASS`; live
  `validation_snapshot.status=PASS`, privacy leaks 0, hidden-owner output deltas
  0, migrated consumers 8, console errors 0.
- City inference `48/48`, public district `104/104`, actor state `93/93`, public
  player `128/128`, actor economy `81/81`, and actor hand `92/92` pass.
- Main architecture `217/217` and Main runtime composition pass.
- Smoke `--check-only` passes with ExitCode 0 and no completion marker, run
  `20260724-191928-815-smoke_test-0fc0d229`.
- `git diff --check` passes before documentation; final check follows docs.

## Test Policy Correction

An unauthorized full smoke was started after check-only. It made no stage
progress beyond `player table ui checks` for over 30 seconds and was stopped by
exact PID. Run `20260724-191934-280-smoke_test-43026c7b` is retained only as an
optional diagnostic; it reached the known stale fixture that calls retired
`Main._new_game`. No product failure is claimed and full smoke is not a gate for
this atomic migration.

`FULL_RUN_RESUME_CLAIM=false`

The next boundary is a read-only authority decomposition:
`AI_REMAINING_MIXED_CITY_OWNER_CONSUMER_PREFLIGHT`.

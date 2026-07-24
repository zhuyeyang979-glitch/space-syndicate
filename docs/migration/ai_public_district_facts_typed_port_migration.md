# AI Public District Facts Typed-Port Migration

## Status

`STATUS=AI_PUBLIC_DISTRICT_FACTS_TYPED_PORT_MIGRATION_VALIDATED_CANDIDATE`

This is one atomic domain inside the active `P0-AI-WORLD-TYPED-PORTS-CUTOVER`.
It does not claim complete AI world isolation, a complete match, Alpha 0.3 completion,
or full-run resume.

## Rule Authority

- `RULE_AUTHORITY_GATE=GREEN` for the migrated public fields.
- Public base authority remains `WorldSessionState`.
- AI semantics remain `AiRuntimeController`.
- The existing `AiRegionKnowledgeQueryPort` is reused and stores no gameplay state.
- `panic` is retired by the v0.6 region contract and is not projected.
- infrastructure damage belongs to `RegionInfrastructureRuntimeController` and is deferred.
- city owner truth, actor guesses, confidence, and reason do not enter this public schema.

## Production Cutover

`AiRegionKnowledgeQueryPort.public_district_facts_snapshot()` returns schema-1 detached
rows with deterministic source and row fingerprints. The query performs literal zero
port mutation and consumes zero RNG. The AI takes one bulk snapshot inside each migrated
leaf consumer and has no Main or raw-city fallback when the port is missing.

Seven consumers are migrated. `Main._alive_district_indices()` is deleted because its
only production consumer was the AI wrapper. The existing region port scene and production
composition are unchanged, so there is still exactly one port and no new capability.

## Privacy And Failure Policy

The public row recursively excludes owner truth, guesses, private player facts, damage,
panic, route/warehouse/GDP/market state, supply-bag future order, monster/military state,
and AI plans. Source dictionaries may contain these values without changing the projected
snapshot or source revision.

Malformed non-Dictionary district rows fail the complete snapshot closed. Missing ports,
invalid indices, destroyed regions, absent cities, and inactive cities return empty or
negative results without falling back to `WorldSessionState.districts` through Main.

## Behavior Preservation

- Source row order is preserved; no sorting or filtering is added.
- First-match district behavior is unchanged.
- Missing terrain keeps the legacy `land` fallback.
- Missing region ID keeps the legacy `region.%03d` fallback.
- Candidate scoring, tie behavior, and RNG calls are unchanged.
- Market, route, supply, monster, weather, military, Victory, and mutation owners are unchanged.

## Main Budget

| Metric | Before | After | Delta |
| --- | ---: | ---: | ---: |
| Physical lines | 6440 | 6433 | -7 |
| Nonblank lines | 5421 | 5415 | -6 |
| Methods | 470 | 469 | -1 |
| Fields | 46 | 46 | 0 |
| Constants | 45 | 45 | 0 |
| Preloads | 7 | 7 | 0 |
| External caller files | 103 | 103 | 0 |
| Production Main reference files | 3 | 3 | 0 |

The budget tool still reports the inherited absolute threshold `103 > 102`. This task adds
no caller or production Main reference.

## Verification

- Focused: `104/104 PASS`
  - Run ID: `20260724-183457-829-ai_public_district_facts_typed_port_migration_test-890a97dd`
- Production scene Bench: `22/22 PASS`
  - Run ID: `20260724-183535-588-AiPublicDistrictFactsTypedPortMigrationBench-8719f1ee`
- Real Godot MCP:
  - scripts validated with zero diagnostics;
  - Bench scene cold-loaded in the editor;
  - live play-mode Bench passed;
  - formal `main.tscn` exposed Main, the runtime coordinator, configured AI, and the
    unique production region port successfully.
- Parent regressions: actor hand `92/92`, public player `128/128`, city inference `48/48`,
  typed world `83/83`, actor economy `81/81 + 19/19`, business transaction `68/68`,
  weather AI `49/49`, and formal four-player `28/28` all pass.
- Main architecture `217/217`, Main composition, smoke `--check-only`, and
  `git diff --check` pass.

## Remaining Boundary

The AI controller still has 80 `districts` tokens and a broad raw-city route. Public market,
routes, supply, monsters, weather, military, Victory, and all mutations remain separate.
The next recommended audit is:

`AI_ACTOR_CITY_AUTHORIZATION_TYPED_PORT_MIGRATION_PREFLIGHT`

It must replace hidden owner reads with actor-own, actor-guess, or authorized-reveal facts
without treating a guess as authoritative ownership.

`FULL_RUN_RESUME_CLAIM=false`

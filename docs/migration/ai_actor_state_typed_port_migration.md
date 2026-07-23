# AI Actor State Typed-Port Migration

## Status

`STATUS=AI_ACTOR_STATE_TYPED_PORT_MIGRATION_VALIDATED`

This is one completed atomic domain inside the still-active
`P0-AI-WORLD-TYPED-PORTS-CUTOVER`. It does not claim that the parent P0,
complete-match playability, full-run resume, or Alpha 0.3 is complete.

## Rule Authority Gate

- `RULE_AUTHORITY_GATE=GREEN`
- Parent mechanic: `MECHANIC_ID=ai_runtime_world_interaction`,
  `MECHANIC_STATUS=ACTIVE`.
- `MECHANIC_ID=ai_actor_private_state_typed_port_migration`
- `MECHANIC_STATUS=MIGRATION_ONLY`
- Authoritative rule files: `AGENTS.md`,
  `docs/ai_runtime_ownership_contract.md`, and the existing v0.6 save and
  privacy contracts.
- Player-facing meaning: none. This cutover preserves existing AI personality,
  learning, and public seat identity while removing generic access to their
  storage records.
- Semantic owner: `AiRuntimeController`
- Record and persistence owner: `WorldSessionState`
- Persistence: the existing player record and existing AI checkpoint shape; no
  new section or schema.

No gameplay rule, personality value, score, candidate order, action frequency,
RNG draw, or save field was added.

## Atomic Scope

This slice migrates only:

- public AI seat identity and eliminated-state queries;
- `ai_profile` and `ai_memory` actor-private snapshots;
- revision-bound profile/memory mutation;
- AI checkpoint capture and apply as one preflighted batch.

Cash, hand, slots, discard, action cooldown, products, markets, routes, cards,
monsters, military, weather, victory posture, and city inference remain outside
this atomic boundary. Those domains must receive their own typed ports. The
remaining generic world bridge is not considered green.

## Production Contract

`GameRuntimeCoordinator` composes one `AiActorStatePort` and issues one opaque
`AiActorStateCapability` for each current AI seat. Human seats receive no
token, different AI seats never share one, and every external player-roster
replacement revokes the old set before the composition root issues the next
set. A valid zero-AI roster binds an empty set. The port is stateless apart
from counters, capability identities, and restore epoch; it does not own
player records.

The public query exposes only public seat identity, role identity, and
elimination facts. The actor-private query exposes that same public context plus
only the requested AI's `ai_profile` and `ai_memory`. It deliberately excludes
cash, hand/slots/discard, cooldown, city inference, rival AI state, Nodes,
Objects, Callables, and mutable world collections. Every result is detached
pure data. Queries mutate no state and consume no RNG.

AI state mutation requires:

- the exact opaque capability instance issued for that actor in the current
  roster generation;
- an AI actor index;
- the exact `ai_profile` and `ai_memory` patch allowlist;
- a non-empty expected revision;
- finite pure data accepted by the retired-contract payload guard.

The revision binds schema marker, actor index, restore epoch, profile, and
memory. A stale or pre-restore revision fails closed. Same-state replay is
accepted without another mutation.

Controller retry is narrower than Port authorization. It may rebase once only
inside the same players-generation and only when the desired and latest memory
changed different top-level keys. A players replacement, a same-key nested
conflict, or either direction of update-versus-delete conflict fails closed.
Every caller checks the final receipt; reward and episode counters advance only
for an accepted, changed commit.

## Batch And Checkpoint Contract

`capture_ai_state_batch_receipt` distinguishes a complete zero-AI capture from
an unauthorized, unsafe, or incomplete capture. It returns every AI actor,
including eliminated actors, as detached profile/memory rows. A malformed
profile or memory fails the whole capture instead of silently omitting one
field or actor. `apply_ai_state_batch` validates every row, the complete
actor-scoped capability set, actor,
shape, serializability, uniqueness, expected revision, and exact current AI
roster before constructing a replacement players array. It assigns that array
once; an invalid later row therefore cannot leave an earlier actor applied.
Even an empty apply requires the exact current empty capability set and is
accepted only when the current authoritative roster contains zero AI actors.
Controller save capture
and apply roundtrip that zero-actor state without inventing player rows.

`AiRuntimeController.to_save_data` and `apply_save_data` keep their existing
`player_states` shape and route profile/memory through this batch port. Timer
fields are committed only after the actor batch succeeds. Truncated or extra
actor rows fail closed. The new-session rollback checkpoint contains only
controller-local timers and receipts; the transaction's subsequent
`WorldSessionState` rollback restores profile and memory, so replacing an
eight-seat table with a smaller roster cannot block rollback. The formal v0.6
Registry remains 19 sections, adds no actor-state section, and still marks the
existing `ai` section unsupported with `strict_preflight_missing`. This PR does
not claim formal AI resume or full-run resume.

## Behavior Parity

- Six personality definitions and seat wrap order are unchanged.
- Candidate generation, sorting, scoring, and action frequency are unchanged.
- Actor-state query and mutation consume zero RNG.
- Strategy and route-plan writes re-read actor memory after nested phase or
  strategy refreshes, preventing a stale CAS from silently dropping the first
  update while preserving the original computation order.
- Public debug snapshots expose no profile, memory, rival plan, or private
  marker.

## Evidence

- Focused SceneTree test: 95/95.
- Production scene Bench: 39/39, privacy leaks 0, partial batch mutations 0.
- Setup session-start transaction: 133/133, including eight-seat active-table
  failure rollback.
- City inference: 48/48; TypedWorldPorts: 83/83; AI business architecture: 37/37.
- AI typed-cash: 72/72; formal four-player real `main.tscn` path: 28/28.
- Main composition: pass; Main architecture: 217/217.
- WorldSession: 44/44; Registry: 12/12; retired contract: 114/114.
- v0.6 envelope runtime: 60/60; smoke check-only: exit 0.
- Godot 4.7 wrapper runs: parser/script errors 0 and no residual process.
- Final wrapper runs report script errors 0 and residual Godot processes 0.
- `session_envelope_save_owner_test.gd` is 92/93 because its inherited stale
  fixture still requires removed Main strings `inspect_run_save` and
  `request_run_load`. Candidate `scripts/main.gd` is byte-identical to
  `origin/main`, where the same Oracle is false. No Main wrapper was restored.
- `AiPolicyResourceBench.tscn` remains at its documented baseline 38/41; its
  three historical source-string records `ai_state_save_load`,
  `city_strategy_parity`, and `candidate_legality_preserved` still expect
  retired Main/helper ownership.
- `git diff --check`: pass.

`scripts/main.gd` is unchanged at 6461 physical lines, 5436 nonblank lines,
473 methods, 47 constants, 46 top-level variables, 7 preloads, and 103 external
caller files. The inherited absolute caller threshold remains 102; this slice
adds no caller and does not claim that debt is green.

## Remaining P0 Scope

After this slice, `AiRuntimeController` still contains 43 `_call_world`
references, 46 `players` tokens, and 95 `districts` tokens. These are deferred
public-player, cash/hand, product/market, route, card, supply, monster,
military, weather, victory, and presentation domains. The next atomic boundary
is `AI_PUBLIC_PLAYER_FACTS_TYPED_PORT_MIGRATION`.

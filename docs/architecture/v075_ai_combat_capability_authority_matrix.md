# V0.7.5 AI combat capability authority matrix

Contract: `space_syndicate.v075.ai_combat_capability_authority_matrix.v1`
Base product: `c1903227beee1c335991ad8751eddd1cc71e0fbe` / tree `726e8ed903241b973c17b00288b4ba5e7f35efc1`

## Decision

Final disposition: **REPAIR_VERIFIED_GO**.

The repaired Gate 60 is `77/77 PASS`. Six fixtures now traverse the real production chain—`V075RuntimeComposition -> AI Observation -> V075AICombatActionCandidateV1 -> production AI policy -> queue -> lock -> runtime -> receipt`—and pass `6/6`. The separate Core contract lineage is also `6/6`; the final focused regression set is `19/19`, natural acquisition is `56/56`, combat-card DBG lifecycle integration is `99/99`, and the real personal DBG lifecycle is `41/41`.

Gate 60 has a `MULTIPLE` task-wide root cause. Its two immediate assertions are a stale Oracle: the test reads the current legal candidate set and treats it as the closed capability catalog. The fixture also uses retired summary-only fields and even names a deploy region absent from its public world. That precisely explains the frozen `9/11` result.

The test is not the only defect. The pre-repair product duplicated the two closed catalogs, exposed them only through a debug snapshot, discarded a complete monster prebind before queueing, and delayed the military target lock until the submission boundary. A test-only change would therefore leave real generation/revision drift possible. The repair establishes `V075CombatCapabilityCatalog` as the single owner for both closed catalogs; domain cores and adapters only reference it.

The repaired contract keeps two concepts separate:

- `SUPPORTED_CAPABILITY_CATALOG` is closed and independent of the current world. Monster modes are exactly `DEPLOY_NEW`, `REFRESH_EXISTING`, `UPGRADE_EXISTING`, and `REPLACE_EXISTING`. Military missions are exactly `assault_region` and `assault_monster`.
- `CURRENT_LEGAL_ACTION_CANDIDATES` is an actor-private, world-dependent subset. It may contain one capability or be empty. Every member must already bind its card identity, mode or mission, target identity, generation and applicable revision.

No fixture is allowed to manufacture four monster candidates or two military candidates merely to demonstrate catalog coverage.

## Authority chain

| Layer | Owner | Catalog source | Legal/target source | Required output |
| --- | --- | --- | --- | --- |
| Monster definition | `V075CardDefinitionRegistry` | Not applicable; definitions do not enumerate action capabilities | none | Detached card definition; `V075CombatCatalog` adds the compatibility view; no target choice |
| Military definition | `V075CardDefinitionRegistry` | Not applicable; definitions do not enumerate action capabilities | none | Detached card definition; `V075CombatCatalog` adds the compatibility view; no target choice |
| AI observation | `V075RuntimeOwner` | Domain catalogs projected separately | Owner-private DBG plus public combat facts | Privacy-scoped facts, catalogs and current candidates |
| Capability projection | `V075CombatAIAdapter` | References domain cores; owns no list | none | Two explicit capability arrays in every candidate-set result |
| Monster legal option builder | `V075RuntimeOwner._monster_card_options` | Typed capability catalog | `preview_monster_card_action` | Detailed option with complete prebound action and target binding |
| Military legal option builder | `V075RuntimeOwner._military_card_options` | Typed capability catalog | Pure military lock preview | Detailed option with locked target generations/revision |
| Candidate normalizer | `V075AICombatActionCandidateV1` at `legal_card_actions` | Typed tagged-union schema | Detailed legal options | Closed `MonsterCardCandidate` / `MilitaryMissionCandidate` shared by player and AI consumers |
| AI policy | Existing V0.7.5 policy | Candidate tags only | Current candidates | Selects one candidate without changing weights or drawing RNG |
| Queue / intent | `V075RuntimeOwner.queue_card_action` | none | Exact selected candidate | Requires candidate fingerprint, target binding and authoritative card binding equality; stores immutable candidate lineage |
| Runtime validation | Runtime owner plus domain cores | none | Exact carried binding | Accepts unchanged binding or rejects/fizzles; never retargets |
| Receipt | Monster/Military domain cores | none | Prebound execution object | Typed commit/fizzle receipt preserving mode, mission and target |

The machine-readable companion records each layer's files, types, target and generation sources, legal-filter owner, catalog owner, string-inference count and pre-repair duplicate-owner count.

## Pre-repair evidence

`V075MonsterSourceCore.prebind_card_mode` already returns an action containing `target_source_generation`, `bound_state_revision`, `prebound=true`, and `mode_auto_conversion_allowed=false`. `V075RuntimeOwner._monster_card_options` only retained `accepted` and rebuilt a thinner option. At submission lock it called prebind again, so the candidate did not preserve the originally observed generation.

Military monster options retained a target generation, but region options retained only a region ID. Locked facility IDs/generations and the target region revision were first chosen later by `build_military_lock`. The queue likewise omitted the complete target lock. V0.7.5 has no owner launch-facility prerequisite; the repair does not introduce one.

The old Gate 60 fixture supplies `legal_modes`, `prebound_target_by_mode`, and `legal_task_kinds`; the current adapter intentionally consumes only detailed `options[]` carrying an authoritative card binding. The test then collects modes and tasks from those absent candidates and asserts catalog coverage. Its `DEPLOY_NEW` target is `region.03` while public regions are only `region.01` and `region.02`.

## Repair boundary

The repair may:

- project the two catalogs from their existing domain authorities;
- establish `V075AICombatActionCandidateV1` as a tagged-union contract;
- preserve the complete monster prebind and the pure military target lock from candidate through queue and runtime validation;
- reject or fizzle stale generation/revision bindings;
- migrate Gate 60 to assert catalog coverage separately from legal candidate subsets;
- add six dynamic fixtures and negative stale/legacy/privacy/determinism cases.

The repair may not change AI preference values, game balance, card values, RNG draw points, military timing, V0.7.6 Direct Action, monster skills, damage, victory, save, map, warehouse, track or presentation ownership.

## Required post-repair proof

Each of Deploy, Refresh, Upgrade, Replace, Assault Region and Assault Monster must traverse:

`Candidate -> AI plan -> queued intent -> runtime accept or typed fizzle -> receipt`

Mode/mission, card identity and generation, target identity and generation/revision must remain unchanged. A target that becomes stale must not select another target or convert to another mode/mission. Repeated enumeration from the same public and authorized private snapshots must produce byte-equivalent candidate order without a new RNG draw.

## Verified fail-closed boundaries

- Refresh binds `expected_hp_revision`; same-generation HP changes produce `monster_refresh_hp_revision_changed` and never heal a different state.
- Region assault fizzles the whole mission when any locked facility identity, generation, owner, type, status or region changes; damage is never redistributed.
- Monster assault requires exact generation, revision, owner, status and public region; movement or damage revision drift produces `locked_monster_target_invalid`.
- Empty target arguments are not wildcards, and an empty production AI option set returns no plan without indexing a nonexistent row.
- `legal_card_actions` publishes typed candidates to player and AI callers. The queue never upgrades a partial request to a current candidate; missing, forged or stale card bindings are rejected.
- Monster and military receipts preserve the complete tested target, generation and revision lineage for all six production fixtures; mode conversion and retarget counts remain zero.
- Active product and test code contain zero `launch_region_id` references.
- Capability arrays exist only in `V075CombatCapabilityCatalog`; active JSON, Runtime and UI consume or derive them and own no duplicate 4/2 allowlist.

# AI Actor City Authorization Consumer Inventory

## Status

- Task: `AI_ACTOR_CITY_AUTHORIZATION_TYPED_PORT_MIGRATION`.
- Parent: `P0-AI-WORLD-TYPED-PORTS-CUTOVER` remains `ACTIVE`.
- Rule authority: `GREEN_WITH_SCOPE_LIMIT`.
- Existing query boundary: `AiRegionKnowledgeQueryPort`.
- New port, capability, state owner, or save section: none.

## Authority

`WorldSessionState` remains the only owner of district city truth and each
player's private city guesses, confidence, and reason. The existing
`AiRegionKnowledgeQueryPort` projects that authority for one authorized AI
actor. `AiRuntimeController` remains the policy and scoring owner.

The projection has four states:

| State | Meaning | Ownership use |
| --- | --- | --- |
| `public_unknown` | A city exists, but this actor has no authorized owner fact | Never identifies a rival |
| `actor_own` | The authoritative owner is the requesting actor | May enumerate the actor's own city |
| `actor_guess` | The actor's private, possibly wrong belief with confidence 1-3 | Belief only; never authoritative gameplay ownership |
| `authorized_reveal` | A previously authorized exact reveal with confidence 100 | Read-only revealed fact; gameplay owners still revalidate mutations |

Guesses do not become city truth. Market, route, monster, weather, military,
Victory, and other gameplay owners continue to validate their own live state.

## Schema 1

Every actor-city row contains exactly:

`schema_version`, `visibility_scope`, `actor_index`, `district_index`,
`region_id`, `present`, `active`, `perceived_owner_index`, `owner_knowledge`,
`confidence`, `reason_id`, `reason_kind`, `authorized_reveal`, `owner_revision`,
and `fingerprint`.

Rows are detached pure data. The schema excludes raw districts, raw cities,
actual or hidden owner fields, another player's guesses, player collections,
AI memory, AI plans, Nodes, Objects, and Callables. Human, eliminated, forged,
null, and out-of-range actors fail closed.

## Migrated Consumers

| Consumer | Typed decision | Preserved behavior |
| --- | --- | --- |
| `_district_product_overlap_with_rival_cities` | Skip only `actor_own`; combine with public product facts | Unknown foreign cities still contribute without revealing who owns them |
| `_active_city_indices_for_player` | Include only `actor_own` | Stable active-city order |
| `_competing_city_indices_for_product` | Exclude `actor_own`; use public city products | No rival identity inference |
| `_ai_product_rival_city_count` | Exclude `actor_own`; use public products and demands | Existing count formula |
| `_ai_owned_city_product_count` | Enumerate `actor_own`; use public products or demands | Existing supply/demand count |
| `_ai_district_focus_score` | Use public district and city product facts | Existing score constants and price term |
| `_ai_preferred_product` | Partition own versus non-own candidates through authorization | Existing focus, score, and tie behavior |
| `_ai_city_product_overlap_score` | Enumerate own cities through authorization | Existing overlap score |

Each migrated body has zero raw `_district_city`, whole `districts` indexing,
hidden owner read, or `_call_world` fallback. A missing typed port fails closed.

## Deferred Scope

This cutover intentionally leaves mixed-domain consumers in place. Route
ownership and income, markets, District Supply, monsters, weather, military,
Victory, and mixed card-effect targeting require separate authority audits.
No result in this inventory claims those consumers migrated.

Source movement inside `AiRuntimeController`:

- raw `_district_city(` tokens: 60 to 51, including the function declaration;
- raw calls: 59 to 50;
- `districts` tokens: 80 to 75;
- `_call_world` tokens: 39 to 39;
- `.get("owner"` tokens: 54 to 49.

## Evidence

- Focused gate: `128/128 PASS`, run
  `20260724-191654-216-ai_actor_city_authorization_typed_port_migration_test-59993dc4`.
- Real Godot MCP production Bench: `24/24 PASS`, privacy leaks 0, hidden-owner
  output deltas 0, migrated consumers 8, console errors 0.
- City inference: `48/48 PASS`; public district: `104/104 PASS`.
- Actor state: `93/93 PASS`; public player: `128/128 PASS`.
- Actor economy: `81/81 PASS`; actor hand: `92/92 PASS`.
- Main architecture: `217/217 PASS`; Main composition: `PASS`.
- Smoke check-only: `PASS`, run
  `20260724-191928-815-smoke_test-0fc0d229`.
- Full smoke is not an atomic-task gate. The accidentally started run was
  stopped by policy after reaching the known stale `Main._new_game` fixture.

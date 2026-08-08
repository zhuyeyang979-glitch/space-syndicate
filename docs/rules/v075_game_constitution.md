# Space Syndicate V0.7.5 Complete Combat Constitution

```text
CONSTITUTION_ID=space_syndicate.v075.complete
RULESET_ID=v0.7.5
STATUS=approved_and_frozen_for_atomic_production_cutover
```

V0.7.5 inherits the complete V0.7.4 constitution outside the combat amendment
domains. The dynamic 6-30 region planet, land/ocean identity, factory/market/
warehouse registry, 18 facility slots per region, warehouse privacy, ten-place
shared sushi vacancy track, six-color asset pips, and deletion of
`scripts/main.gd` are unchanged.

The JSON companion is the closed machine authority. Unknown combat rule IDs,
enum values, required fields, or localized identity inference fail before
mutation. Numeric combat tuning lives only in
`v075_combat_balance_defaults.json`; this constitution freezes structure and
ownership.

## Active Combat Catalog

The first candidate contains six active monster families and covers each
industry color exactly once:

| Family | Preferred color | Movement profile | Commercial model key |
|---|---|---|---|
| `spore_tide_emperor` | `life` | `ground_trample` | `model.monster.life` |
| `meteor_sentinel` | `energy` | `flying_no_trample` | `model.monster.energy` |
| `sand_armor_rover` | `industry` | `ground_trample` | `model.monster.industry` |
| `blue_edge_knight` | `technology` | `ground_trample` | `model.monster.technology` |
| `prism_blade_colossus` | `commerce` | `ground_trample` | `model.monster.commerce` |
| `mirror_hunter` | `shipping` | `teleport_no_trample` | `model.monster.shipping` |

Each family has exactly four private active skill definitions. Rank I unlocks
skill one, rank II unlocks skills one and two, rank III unlocks one through
three, and rank IV unlocks all four. Skill four is the only ultimate. Preferred
color, autonomy, movement, trample, arrival attack, and passive traits are not
skill cards.

Preferred color is used only by monster autonomous facility targeting. It does
not recolor a normal card and does not select that card's action-cost asset.
The existing unified-track Authority independently selects `primary_color` for
each spawned monster or military card instance. Family, definition, and catalog
authoring cannot constrain or override that choice, so two instances of one
definition may have different colors. Any catalog `track_primary_color` member
is ignored as non-authoritative migration metadata. Card action cost is
`primary_asset_cost` paid from that instance's Authority-selected color.

The active military catalog contains at most four existing authored families.
Every active military family uses the same two mission interfaces; differences
are limited to asset cost, region damage budget, monster damage, public
presentation, and card rank/merge identity.

## Monster Source And Cards

`V075CombatRuntimeOwner` owns persistent monster source state. A normal player
has a base active-monster capacity of one. A typed Character Semantic port may
add a modifier; neither player index, display name, nor UI may provide an
exception. If capacity falls below the current active count, no monster is
destroyed. New deployments remain illegal until the count is within capacity.

Every monster card is a normal DBG card. Purchase sends it to personal discard,
then normal reshuffle and draw can bring it to hand. Before batch lock the
player binds one mode and its exact target:

- `DEPLOY_NEW`: deploy a family not already active while under capacity.
- `REFRESH_EXISTING`: same family, card rank no higher than source rank, and
  less than full HP. Rank I-IV restores 25%, 50%, 75%, or 100% of maximum HP.
- `UPGRADE_EXISTING`: same family and higher card rank. Rank, maximum HP, and
  unlocked skills advance; HP becomes the new maximum. Existing cooldowns stay
  unchanged and newly unlocked skills start `READY`.
- `REPLACE_EXISTING`: at capacity, withdraw one exact different-family source
  and deploy the new family. Withdrawal is not a kill and grants no reward.

Resolution cannot convert modes or pick another target. The card returns to
personal discard after success or the applicable inherited Fizzle lifecycle.

## Preferred-Color Autonomy

Every active family authors one preferred color directly. Legacy
`resource_focus`, localized names, card color, and model color are migration
evidence only and are never runtime inference inputs.

At maintenance, autonomy reads a frozen public snapshot containing dynamic
region adjacency and public enemy facilities. It never reads any player's
six-color asset pool, warehouse stock, private logistics plan, future action,
or AI plan. A legal candidate is an undestroyed enemy `factory`, `market`, or
`warehouse` with a matching public `industry_id` and a public `region_id`.

Distance is the shortest-hop path on the V0.7.4 dynamic adjacency graph. Equal
distance is resolved by the monster's authored facility-type preference,
authored target priority, public damage state, then stable `facility_id`
lexicographic order. Camera position, screen pixels, array-index difference,
polygon vertices, and microcells are absent from the decision.

If no matching facility is in range, the source waits for the batch and expands
its detection radius by one hop next batch. At whole-map range with no matching
enemy facility it becomes `hungry` and chooses the nearest enemy public
facility of any color. When a matching color reappears, color priority and the
base detection radius return. No source can stall permanently.

## Movement And Trample

All monster targets and paths are computed from one frozen maintenance
snapshot. Plans are frozen before presentation starts, so an earlier animation
cannot alter a later monster's target. Authority updates stable `region_id`
through receipts; animation never writes position per frame.

Movement profiles are closed to:

- `ground_trample`
- `flying_no_trample`
- `teleport_no_trample`

Ground means contact with the spherical surface, not land-only travel. V0.7.5
adds no land/ocean passability or combat modifier. Forced movement does not
trample unless a future authored skill explicitly opts in; every first-catalog
skill keeps that opt-in false.

A movement receipt records an ordered region path and integer
`distance_milli_arc` segments. Multiple segments in one region are summed
before one damage calculation. Positive distance provides at least one step;
damage then scales in fixed steps and is capped per region. Step size, damage
per rank, and caps come from the balance defaults.

Only enemy factories, markets, and warehouses can receive trample damage.
Preferred-color facilities are allocated first, then other enemy facilities,
then stable facility ID. Trample never directly damages monsters, military,
players, goods, or region HP. Destination trample and arrival basic attack use
different receipt IDs.

Because the formula consumes only fixed-point spherical arc distance, a
COMPLEX boundary with more vertices or microcells cannot increase damage.

## Private Instant Monster Skills

Monster skills remain source-bound, but V0.7.5 replaces the inherited public
batch behavior. They exist only in the owner's private skill dock and are not
members of the public queue, normal five-action rotation, normal hand, deck,
discard, commodity inventory, or merge system.

The owner may request a legal skill during `batch_active`, between public
receipts, or before autonomy maintenance. With no atomic transaction in flight,
the authority resolves it immediately. Otherwise it enters the owner's private
instant sequence and resolves at the first safe receipt boundary. A skill never
interrupts a commit, rolls back an action, restores a Counter window, or reads
future public targets.

Requests order internally by authority receive sequence, then stable player ID,
then request ID. That order is never public. Each monster may use at most one
active skill per batch.

Skills reserve only `available_unreserved_assets`. Assets already reserved for
public batch actions cannot be consumed. A request rejected before authority
acceptance spends nothing and does not consume the batch use. If an accepted
request loses its source or target at the safe boundary, it Fizzles: all skill
assets are released, no cooldown begins, no effect occurs, and the monster's
one use for that batch is consumed.

Successful skills enter batch cooldown and later return to `READY`. Downed
sources temporarily disable skills. Recovery restores prior ready/cooldown
state. Destroyed, withdrawn, and replaced sources revoke their skills. Upgrades
preserve old cooldowns and unlock new skills as ready.

Public viewers can see monster identity, rank, HP, armor, preferred color,
region, tracked facility/path, unlocked-skill count, and whether the batch use
is spent. Only the owner receives skill cards, names, costs, target contracts,
cooldown details, and pending target. Rivals see committed effects and public
results, never skill card faces or future requests.

## One-Shot Military Missions

Military cards remain normal DBG cards and ordinary anonymous public batch
actions. They create no persistent military source, source-bound action,
private skill dock, cooldown, follow-up command, or separate control cap.

The only mission choices are:

- `assault_region`: the player chooses one region. At lock, authority freezes
  its revision and exact enemy factory/market/warehouse IDs and generations.
  One total damage budget is distributed one point at a time over that stable
  facility order. Full damage is never copied to every facility. Invalidated
  locked targets are skipped and no new facility is added. If all targets are
  invalid, the mission Fizzles without reselection.
- `assault_monster`: the player locks one monster source instance, generation,
  revision, and public region. If the same source moves before resolution, it
  is attacked once at its current public region. Destruction, withdrawal,
  replacement, generation change, or other illegality causes Fizzle without
  another target.

After either mission, including Fizzle, the force withdraws and the card enters
personal discard. It can reshuffle and be drawn again. Military cannot attack
military. `guard_region`, `protect_region`, `defend_region`, and
`intercept_region` are invalid everywhere, including Core, AI, UI, checkpoint,
and telemetry.

## Authority And Typed Ports

One `V075CombatRuntimeOwner` owns monster sources, skill states, the private
instant sequence, military mission transactions, the Combat Receipt Journal,
and combat exact-once state. Pure Cores calculate source transitions,
autonomy, trample, private-skill transactions, military missions, and combat
damage plans.

Combat does not own map topology, facility state, player assets, DBG piles,
Victory, or production Save slots. It communicates through typed ports.
Facility damage always becomes `FacilityCombatDamageIntentV1`; the Region
Infrastructure Owner validates generation, applies or rejects damage, and
returns a receipt. Warehouse capacity or throughput may react to public damage,
but private stock and private logistics never enter combat projections.

The old `MonsterRuntimeController` and `MilitaryRuntimeController` are semantic
and pure-algorithm references only. They are production-unreachable under
V0.7.5. No replacement monolith, copied Controller, `combat_main.gd`, or legacy
Main fallback is permitted.

## AI, Presentation, Telemetry, And Terminal

AI sees its own monster sources, skills, cooldowns, and available assets plus
public facilities, public monsters, legal targets, and dynamic adjacency. It
cannot read rival skills, rival pending targets, warehouse stock, future
military targets, or complete hidden order.

Presentation consumes frozen plans and committed receipts. It may show full
deploy, movement, trample, attack, damage, cooldown, military strike, and
withdrawal animation, but owns no path, damage, state, RNG, or authority time.
Reduced-motion rendering must preserve the same public information.

Telemetry is read-only. It omits rival skill definitions, targets, cooldowns,
the complete private instant sequence, warehouse stock, and AI plans.

Detached combat checkpoints support rollback and exact-once tests only. The
candidate remains new-game-only and writes no production Save slot. Once
Victory is pending, no new private skill request is accepted. Previously
accepted requests complete or Fizzle before the single FinalSettlement. No
combat movement, trample, mission, or cooldown recovery occurs afterward.

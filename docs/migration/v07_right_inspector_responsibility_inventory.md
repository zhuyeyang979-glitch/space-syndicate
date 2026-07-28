# V0.7 fixed RightInspector responsibility inventory

Status: `AUDIT_GREEN_PRODUCTION_CUTOVER_NOT_EXECUTED`

PR #69 is green on its remote sibling branch at
`b5d5682072fd9ff02be700ce9d5503d1df996641`, so the logical terminal
prerequisite no longer blocks a production presentation-shell preflight. That
commit is not a Git ancestor of this Lane B stack; both lines share
`f377746584ac70d706418d399b813f3ad456763e` and must retain their explicit
stacking/merge order. The external prerequisite does not make deleting the
fixed production inspector safe by itself. The current `GameScreen` still
sends ten live responsibility classes to a permanent 292-pixel
`RightInspector`.

## Current ownership map

```text
GameTableViewModelRuntimeService / TableSnapshot
                    |
                    v
       GameScreen (48 matching source lines)
                    |
                    v
       fixed RightInspector (292 px)
       | region summary
       | action reason / requirements / dispatch
       | public event feedback
       | deep navigation and Intel intent
       | private hand-card detail
       | public track detail
       | public commodity detail and claim feedback
       ` public-player inspection
```

The machine inventory records ten rows because table-context assembly is a
real ownership responsibility in addition to the nine rendered/interactive
surfaces. Removing the scene node today would either lose features or require
a generic forwarding facade, both forbidden by the task.

The source metric is deliberately named precisely: `game_screen.gd` contains
48 matching lines and 59 `right_inspector` symbol occurrences, including 13
dynamic `.call(...)` sites and two signal connections. These are audit metrics,
not 48 direct calls.

## Required target split

| Current responsibility | Final target | Current gate |
| --- | --- | --- |
| Region summary and rack context | `RegionSupplyPopup` plus district drawer | Rack query exists; typed region-context target parity is missing. |
| Action reason, cost, conditions and actions | `CompactCurrentActionSurface` / `ActionContextChipRow` and existing PlayerBoard `ActionDock` | Action intents exist; typed context target and parity are missing. |
| Short public event feedback | Typed non-blocking Toast plus expandable history | No production typed feedback target exists. |
| Deep navigation and Intel | Context buttons/top navigation using existing typed intents | Intents exist; contextual target is missing. |
| Hand card detail | PlayerCardDock hover plus contextual detail drawer | Preview exists; full typed drawer parity is missing. |
| Public track detail | Transient detail drawer/focus ribbon | Selection intent exists; typed detail target is missing. |
| Commodity focus and claim result | Commodity contextual surface near PlayerCardDock | Claim request exists; typed detail target is missing. |
| Player inspection | Single-side roster plus typed `PlayerInspectionPopup` | V0.7 reference is green; production typed roster/popup do not exist. |

## Why production deletion remains blocked

The V0.7 reference table now has one left-side roster, zero orbit player
markers, zero radial seat spokes and a non-mutating region popup. It is still a
detached reference. Production continues to consume `PublicPlayerSeatSnapshot`
position fields, `RoleSeatLayerHost`, both seat layers and the fixed inspector.

The safe production direction is:

```text
typed public roster projection -> single-side production roster
typed player inspection        -> PlayerInspectionPopup
typed region projection         -> RegionSupplyPopup
typed action context            -> CompactCurrentActionSurface
typed event receipt             -> Toast / event history
typed contextual detail         -> transient drawer
```

No new gameplay authority, Save owner, RNG source, Main responsibility or
V0.6/V0.7 dual writer is needed. Until every typed target and parity gate
exists, production `RightInspector`, `RoleSeatLayerHost`, seat enums and
positional underlays are explicitly preserved rather than hidden or falsely
reported retired.

The machine inventory gate passes 80/80. It verifies all ten responsibilities,
the exact 48 matching lines / 59 occurrences / 13 dynamic calls / two signal
connections, the external sibling-branch nature of PR #69, and the continued
physical presence of the production 292-pixel inspector until typed parity
exists.

## Exact next task

`V07_PRODUCTION_TABLE_SHELL_TYPED_PRESENTATION_PORTS_PREFLIGHT`

That preflight should define the split typed snapshots/targets, enumerate all
48 `GameScreen` call sites and every test consumer, and produce an atomic
cutover plan with zero forwarding wrappers. Only the following production atom
may remove the permanent 292-pixel inspector and old seat composition.

# Standings application-flow privacy review

Status: **BLOCKED — PRIVACY VIOLATION COUNT 1**

Reviewed cutover commit: `e72d0a9f6c26f36646e91ce357339218d6f615af`

Required base fix: `50e424578afe50fd32953f5b727520df84f5cdf7`

Scope: the new standings query port, application-flow controller, snapshot
service, scoreboard renderer, final-settlement summary handoff and explicit
production composition in `scenes/main.tscn`.

This review is analysis-only. It changes no production code or tests and does
not authorize integration.

## Decision

The scene-first extraction is structurally sound, but it is **not privacy
green**. One high-severity violation remains at the exact-cash disclosure
boundary.

`StandingsPublicSnapshotService` treats any non-empty `audit_entries` row as a
publicly audited row. It then prints `cash_ledger_cents`, defaulting a missing
value to zero, without requiring the three authoritative facts that the
Victory owner publishes:

1. top-level `cash_visibility == "public_audit"`;
2. the row's integer `player_index` is present in
   `audit_revealed_player_indices`;
3. the row itself carries `cash_visibility == "public_audit"` and an integer
   `cash_ledger_cents`.

Therefore a markerless, stale or forged audit entry can produce an exact rival
cash chip. A markerless row with no cash field still produces `账本¥0.00`,
which is an unauthorized exact-cash assertion rather than a fail-closed hidden
state. The formatter also accepts `economic_assets` from that same unvalidated
row and publishes project/contract/warehouse/financial-position counts, even
though those collections are not part of VictoryControl's public candidate
projection and are not required by the final comparison rule.

Confirmed privacy violation count: **1**

Verdict: `STANDINGS_APPLICATION_FLOW_PRIVACY_BLOCKED`

## Blocking violation

### `STANDINGS-AUDIT-CASH-01` — audit row presence is used as disclosure authority

Severity: **high**

Evidence:

- `scripts/runtime/standings_public_snapshot_service.gd:122-124` obtains an
  audit row and defines `publicly_audited := not audit.is_empty()`.
- `scripts/runtime/standings_public_snapshot_service.gd:131-135` exposes exact
  ledger cash and economic-asset counts solely from that boolean.
- `_audit_entry()` matches only `player_index`; it does not validate top-level
  visibility, the revealed-index allowlist, row visibility or integer cash.
- `tests/standings_public_snapshot_service_test.gd:60` supplies a markerless
  audit entry with `cash_ledger_cents` and `economic_assets`. The test therefore
  normalizes the unsafe input shape instead of proving fail-closed behavior.
- The cutover query forwards `victory_public.duplicate(true)` wholesale at
  `scripts/runtime/standings_public_query_port.gd:114`, leaving the formatter
  as the last disclosure gate. That gate currently trusts row presence.

Impact:

- exact opponent cash may be displayed without authoritative public-audit
  authorization if the public snapshot is incomplete, stale or malformed;
- a missing cash value is rendered as an exact zero rather than hidden;
- unallowlisted economic-asset counts can enter player-facing chips through
  the same row.

Required closure:

- derive an `authorized_public_audit_cash_by_player` map only when all three
  Victory markers agree;
- render exact cash only from that map and otherwise omit the cash chip or show
  a non-numeric privacy label;
- do not read `economic_assets` in standings unless VictoryControl adds a
  separately documented public allowlist and explicit visibility marker;
- add rival-sentinel negative tests for missing top-level visibility, missing
  roster, missing row marker, wrong player index, non-integer cash, conflicting
  duplicate rows, `game_over=true`, winner status and markerless
  `economic_assets`;
- recursively assert that visible text, tooltip text and serialized scoreboard
  data contain none of the rejected sentinels.

## Viewer-isolation review

The viewer route is otherwise correct:

- `StandingsPublicQueryPort` obtains identity from
  `TablePresentationQueryPorts.viewer_context()` and requires `authorized`;
- the private query is self-only:
  `private_world_projection(viewer_index, viewer_index)`;
- opponent rows are built only from `WorldSessionPublicProjection.players`;
- exact local cash comes only from the authorized private player projection;
- local Top-N GDP and controlled-region progress come only from
  `VictoryControlRuntimeController.private_snapshot(viewer_index)` after
  viewer authorization;
- table selection, hovered/inspected seat and session finish are not used as
  authorization;
- opening standings does not refresh routes or mutate world state.

No viewer-isolation violation was found in this path.

## Forbidden information review

The source adapter does not copy any opponent:

- cash outside the defective audit-row path;
- hand cards, hand count or hand size;
- discard cards or discard choice;
- private intelligence or inference state;
- hidden owner or owner truth;
- anonymous card actor truth;
- AI plan, pressure bucket, route plan, score, utility or learning metadata.

The only private projection requested is the authorized local player's own
projection, and the composed source extracts only own cash and own victory
progress. Public-log content is reduced to an entry count; no event payload or
actor identity reaches the standings source.

## Tooltip and accessibility review

The scoreboard consumes only the already formatted scoreboard dictionary and
does not query runtime state. Its shell, overview cards, KPI cards, seat cards,
rank labels, score labels and chips use static or already-authorized tooltip
copy. No hidden owner, anonymous actor, opponent hand/discard/intel or AI
metadata is interpolated into visible or tooltip text.

The blocking exact-cash chip is also copied into tooltip-adjacent rendered UI,
so closing `STANDINGS-AUDIT-CASH-01` must include a recursive rendered-tree
sentinel check. No separate tooltip/accessibility violation was found.

## Final-settlement visibility review

The standings query requests `latest_public_summary()` only after the Victory
public snapshot contains an outcome receipt. The final-settlement composition
builds that summary from its public source adapter, whose cash path requires
top-level public-audit visibility plus the revealed-player allowlist. It does
not read raw players, private hands or AI plans.

No additional final-settlement privacy violation was found. As a correctness
hardening item, the summary should eventually be coupled to the current
`outcome_id` (or reset between sessions) so a stale public summary cannot be
shown for a different resolved run; the reviewed path does not turn session
finish itself into a new disclosure grant.

## Pure-data and composition review

- The composed standings source is checked by
  `TablePresentationPureDataPolicy.is_pure_data()` before formatting.
- Its legal values are detached dictionaries/arrays and scalar Godot variants;
  no `Object`, `Node`, `Resource`, `RID` or `Callable` reaches the source or
  scoreboard snapshot.
- The renderer receives a dictionary and creates presentation nodes locally;
  it does not retain a world/controller object in the data contract.
- `scenes/main.tscn` explicitly composes one query port and one application
  controller and connects the dedicated `standings_requested` signal.
- `ApplicationFlowPort.submit_action("standings")` does not also emit the
  generic action signal, so there is no standings fallback through `Main`.
- The removed standings-specific `Main` methods and preload remain absent.

No pure-data or production-composition violation was found.

## Verification evidence

- Godot MCP project inspection: Godot `4.7.stable` and the specified isolated
  worktree.
- Godot MCP runtime:
  `res://scenes/tools/StandingsPublicSnapshotCutoverBench.tscn` passed `20/20`;
  real scene-owned open was `28ms`; the project was stopped cleanly. The debug
  stream contained existing project-wide script warnings and no standings
  runtime error.
- Source inspection covered the query port, controller, snapshot service,
  scoreboard, production scene, Victory public markers, final-settlement
  adapter/composition and the two focused standings tests.
- The existing bench and tests do not exercise the missing-marker rival-cash
  cases above; their green result does not close this review.

## Integration gate

Do not integrate `e72d0a9` as privacy-green until
`STANDINGS-AUDIT-CASH-01` is fixed and the negative marker/sentinel matrix is
green. After that change, rerun the standings focused tests, the real MCP bench,
the Victory public-projection privacy tests, final-settlement privacy tests and
a rendered-tree tooltip/text scan.

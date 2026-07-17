# Standings application-flow privacy review

Status: **FINAL REVIEW — GREEN, PRIVACY VIOLATION COUNT 0**

Reviewed cutover commit: `e72d0a9f6c26f36646e91ce357339218d6f615af`

Reviewed privacy fix commit: `b8ff349ca0b489ea3cfd7aa179a542aff9a31713`

Required base fix: `50e424578afe50fd32953f5b727520df84f5cdf7`

Scope: the standings query port, application-flow controller, snapshot service,
scoreboard renderer, final-settlement summary handoff, focused privacy gates and
explicit production composition in `scenes/main.tscn`.

This review is analysis-only. It changes no production code or tests and does
not authorize unrelated integration work.

## Decision

The standings scene-first extraction is **GREEN** from the reviewed privacy
boundary. Commit `b8ff349` closes `STANDINGS-AUDIT-CASH-01`; no remaining
privacy violation was found.

Exact audit cash now appears only when all four authorization gates agree:

1. the Victory public envelope has `cash_visibility == "public_audit"`;
2. the seat's integer `player_index` is present as an integer in
   `audit_revealed_player_indices`;
3. the matched audit row has the same integer `player_index` and row-level
   `cash_visibility == "public_audit"`;
4. the matched row has an integer `cash_ledger_cents`.

Missing, mismatched or non-integer gates fail closed. `game_over`, resolved
state, winner status and mere cash-field presence do not authorize disclosure.
Conflicting duplicate rows fail closed, identical duplicates collapse to one
matched row and each seat produces at most one cash chip. A missing authorized
cash value no longer renders the fabricated exact value `账本¥0.00`.

Confirmed privacy violation count: **0**

Verdict: `STANDINGS_APPLICATION_FLOW_PRIVACY_GREEN`

## Closure of `STANDINGS-AUDIT-CASH-01`

The prior high-severity violation is closed by the following production
behavior:

- `_authorized_audit_cash_cents()` enforces the four gates above and returns
  `null` on any failure;
- `_seat_snapshots()` adds an exact ledger chip only when the returned value is
  non-null;
- an authorized local player still receives their own private cash when public
  audit authorization is absent;
- `_audit_entry()` requires an integer matching player index and rejects
  conflicting duplicate rows;
- all `economic_assets` reads and project/contract/warehouse/financial-count
  chips were removed from production standings formatting;
- player-facing copy now distinguishes public audit progress from separately
  authorized public cash.

The focused service test independently covers:

- a fully authorized rival cash row;
- missing top-level cash visibility;
- missing revealed-player allowlist;
- wrong player allowlist;
- missing row cash visibility;
- non-integer audit cash;
- conflicting duplicate audit rows;
- `game_over` and winner status without authorization;
- markerless and otherwise injected `economic_assets`;
- absence of the rival cash sentinel, raw-cent sentinel, `账本¥0.00` and asset
  sentinel in serialized snapshots;
- absence of the same sentinels in recursively collected visible text and every
  `Control.tooltip_text` in the instantiated scoreboard.

No production `economic_assets` consumer remains in the standings query,
formatter, controller or renderer.

## Viewer isolation

The original viewer boundary remains intact:

- viewer identity comes from
  `TablePresentationQueryPorts.viewer_context()` and must be authorized;
- the only private request is
  `private_world_projection(viewer_index, viewer_index)`;
- opponent rows come only from `WorldSessionPublicProjection.players`;
- local exact cash comes only from the authorized self projection;
- local Top-N GDP and controlled-region progress come from VictoryControl's
  private self projection after authorization;
- table selection, hover/inspection state, AI/human seat labels, game end and
  winner status do not grant private access;
- opening standings remains read-only and does not refresh routes, mutate the
  world, advance RNG or write a public/private log.

No viewer-isolation violation was found.

## Forbidden information

Opponent hand contents, hand count/size, discard contents/choice, private
intelligence, hidden owner, anonymous actor truth and AI plan/score/pressure/
route/learning metadata do not enter the standings source, serialized snapshot,
visible labels or tooltips. Public-log data is reduced to an entry count; no
event payload or actor identity is forwarded.

The injected hidden-owner/private-plan and economic-asset fixtures are omitted
from output. The renderer consumes only the already sanitized scoreboard
dictionary and performs no runtime query.

## Tooltip and accessibility text

The scoreboard test instantiates the real `StandingsScoreboard.tscn`, applies
every negative cash case and recursively collects:

- `Label.text`;
- `RichTextLabel.text`;
- `Button.text`;
- every `Control.tooltip_text`;
- all descendant nodes.

Rival cash, raw cents, fabricated zero-ledger copy and asset sentinels are absent
from the rendered text/tooltip surface. Static tooltips contain no opponent
hand/discard/intel, hidden owner, anonymous actor or AI metadata.

No tooltip/accessibility-text violation was found.

## Final-settlement visibility

The standings query reads `latest_public_summary()` only after the Victory
public snapshot contains an outcome receipt. Final-settlement exact cash is
already constrained by its own top-level public-audit visibility and
revealed-player allowlist, while raw players, private hands and AI plans are
forbidden from its composition context.

The standings fix does not infer new visibility from outcome presence and does
not weaken the final-settlement sanitizer. The earlier non-blocking correctness
hardening remains: couple a cached final summary to its current `outcome_id` or
reset it between sessions to prevent stale public copy from being shown for a
different run.

No final-settlement privacy violation was found.

## Pure data and production composition

- `StandingsPublicQueryPort` validates the composed source with
  `TablePresentationPureDataPolicy.is_pure_data()` before formatting.
- Source and result contain only detached arrays/dictionaries and allowed
  scalar Godot variants; no `Object`, `Node`, `Resource`, `RID` or `Callable`
  enters the presentation data contract.
- The scoreboard creates local UI nodes from the sanitized dictionary and does
  not store a runtime/controller object in the snapshot.
- `scenes/main.tscn` composes one `StandingsPublicQueryPort` and one
  `StandingsApplicationFlowController` and connects the dedicated
  `standings_requested` signal.
- `ApplicationFlowPort.submit_action("standings")` does not emit the generic
  action signal, so no standings request falls back through `Main`.
- The removed standings-specific `Main` methods and preload remain absent.

No pure-data or production-composition violation was found.

## Verification evidence

Independent focused runs on Godot `4.7.stable.official.5b4e0cb0f`:

- `standings_public_snapshot_service_test.gd`: PASS;
- `standings_application_flow_cutover_test.gd`: PASS `17/17`;
- `main_application_flow_handler_extraction_test.gd`: PASS `27/27`;
- `victory_control_public_projection_privacy_v06_test.gd`: PASS `47/47`;
- `final_settlement_public_privacy_v06_test.gd`: PASS `31/31`;
- `final_settlement_public_snapshot_service_test.gd`: PASS.

Godot MCP runtime:

- scene: `res://scenes/tools/StandingsPublicSnapshotCutoverBench.tscn`;
- result: PASS `20/20`;
- real scene-owned open: `27ms`;
- standings runtime errors: `0`;
- stop result: clean;
- debug stream: existing project-wide script warnings only.

## Integration gate

`b8ff349` is privacy-green for the reviewed standings application flow.
Integration still depends on the coordinator's non-privacy regression and
branch-management gates; this review does not waive unrelated existing debt.

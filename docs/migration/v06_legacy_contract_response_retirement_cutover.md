# V0.6 legacy contract response retirement cutover

Status: `V06_LEGACY_CONTRACT_RESPONSE_RETIREMENT_CUTOVER_GREEN`

Base commit: `19f20309316edf907ae9aa25ea09487cbf284213`

## Product ruling

V0.6 does not contain a target-player contract accept, reject, penalty, or timeout decision. Conditional orders and supply cards validate and settle automatically through the existing card-resolution and economy owners. This cutover does not add a replacement consent mechanic.

The following boundaries remain active and independent:

- one-layer card counter response;
- monster wager response and battle lifecycle;
- card target choice;
- other registered forced decisions.

## Rule authority

The root `AGENTS.md` now requires a mechanic ID, active rule source, owner, privacy boundary, and persistence boundary before a gameplay owner, port, sink, receipt, decision surface, AI policy, save field, or effect kind may be added.

Machine-readable statuses live in:

- `docs/rules/v06_mechanic_status_registry.json`
- `docs/rules/v06_mechanic_status_registry.md`

The permanent checker is `tools/rules/check_v06_mechanic_authority.py`; its Godot gate is `tests/v06_mechanic_authority_gate_test.gd`.

Final checker result:

```text
retired_production_identifier_count=0
source_splitting_evasion_count=0
rule_authority_unreferenced_mechanic_count=0
registry_errors=[]
self_test_cases=11/11
```

## Runtime retirement

The production tree contains no dedicated contract-response owner, port, sink, request, receipt, panel, timer, responder policy, AI decision, save section, or Main fallback. Dead pair-contract target mirrors and retired signing/refusal presentation aliases were removed rather than hidden behind compatibility wrappers.

Legacy save payloads are inspected only by `LegacyContractPayloadGuardV06`. A payload containing retired response state is rejected without opening a response window, applying a penalty or reward, or mutating the active session.

## Automatic order and supply settlement

Conditional order and supply cards now remain inside the formal card execution lineage:

```text
CardPlaySubmissionRuntimeController
  -> CardResolution queue/execution
  -> GameRuntimeCoordinator typed economy entry
  -> CoreEconomicCardRuntimeAdapterV06
  -> existing ProductMarket / CommodityFlow / infrastructure owners
```

The submission path preflights before committing the card. Resolution revalidates authoritative facts. Successful effects finalize once; replay returns the prior authoritative result; a failed condition produces no partial mutation. Public queue and history records use public group aliases and do not reveal the submitting seat.

No new effect kind, economy owner, save section, target-player consent, penalty, or replacement reward was introduced.

## Retired card content

The six `area_trade_contract` families (seven cards) remain only as migration evidence. They are absent from the active catalog, random supply, AI candidates, and player Codex. There are seven migration aliases and no active duplicate replacements. Together with the two `密约回溯` ranks, the integrity catalog changes from 239 to 230 active IDs.

The two `密约回溯` cards and the `intel_contract_trace` effect were also retired because their only purpose was the removed consent flow. Their family resource was deleted, and active pack, catalog, AI, presentation, balance, and Codex fields were removed. The Inspector-authored Resource graph therefore changes from 232 to 230 cards and from 114 to 113 families. No substitute effect was invented.

Final active catalog baseline:

| Metric | Value |
| --- | ---: |
| Authored cards | 230 |
| Families | 113 |
| Public pool entries | 116 |
| Upgradeable families | 70 |
| Packs | 10 |
| Effect kinds | 48 |

Integrity hashes:

- catalog data: `0492531b53d13b47d9354b71dce2eebaa26784ac218dd294cf1f4d5e7a1c0ae5`
- catalog order: `54aa7929922580235034a53d1fbf940c97bf6b64d3ebec610e2cd89a422350ae`
- public pool order: `3059a90e42c676a5bb469d836813b1b45d6b02693464f654e4309e0e225cd33b`
- upgradeable order (unchanged): `feec0fbc3de8ee8bb312fc626ea233db625cc29fa21619b196680d5c640f3d14`

## Main budget

This cutover did not add a Main compatibility path.

| Metric | Before | After | Delta |
| --- | ---: | ---: | ---: |
| Physical lines | 6747 | 6741 | -6 |
| Nonblank lines | 5696 | 5690 | -6 |
| Methods | 486 | 486 | 0 |
| Top-level variables | 47 | 47 | 0 |
| Constants | 64 | 64 | 0 |
| Top-level preloads | 7 | 7 | 0 |
| External caller files | 106 | 102 | -4 |

`tools/architecture/check_main_gd_budget.py --json` passes.

## Verification evidence

Focused Godot 4.7 tests passed for:

- authority registry and source scan;
- retirement and legacy-save isolation;
- automatic order/supply exact-once settlement and rollback;
- card queue, execution, history, stable targets, transition lineage, persistence, and fault injection;
- card counter, forced-decision boundary, monster wager, monster battle, and card target choice;
- card catalog, authoring workflow, Codex semantics, roles, UI text, visual snapshot, Main architecture, and Main composition;
- `smoke_test.gd --check-only`.

Godot MCP loaded the formal `res://scenes/main.tscn` under Godot 4.7 without a contract-response parse or runtime error. Existing warnings were unchanged.

Two broad fixtures remain inherited debt and were not repaired by restoring retired Main APIs:

- `layout_scene_smoke_test.gd` has the same 60 unique errors on the base commit and this branch; the task-only error set is empty.
- full `smoke_test.gd` reaches the existing retired `_new_game` fixture and times out; `--check-only` passes. The old `_new_game` wrapper was intentionally not restored.

`CardPlayEligibilityRuntimeBench` likewise retains the same three baseline failures; its two retired contract cases were physically removed.

## Post-merge dead-residue verification

A follow-up source and runtime audit removed the last production readers that
could still imply a dedicated contract-response lifecycle:

- the unused `contract_window_seconds` field was removed from the active
  Ruleset profile and Inspector resource while the five-second card-counter
  window remains unchanged;
- the production save-handshake scene no longer loads or exposes the unused
  v0.5 controller registry. The v0.5 registry file itself remains unchanged as
  historical version evidence, including its old `contract_runtime` /
  `contracts` entry; v0.6 validation, save composition and cold restore use
  only the v0.6 registry and never resume that entry;
- VictoryControl no longer copies an always-empty legacy contract array into
  viewer-private audit assets. Forged legacy input is discarded;
- Main, AI and balance diagnostics no longer read the retired
  `contract_products` field. The uncalled Main product-card counter was
  deleted as a whole; active product requirements continue to use the formal
  `supply_product` / `play_product` fields;
- the AI route score no longer carries a constant-zero `decline_pressure`
  term. The arithmetic result is unchanged.

The focused retirement gate now permanently rejects those three retired field
names from the affected production sources. The broader authority checker
continues to reject the registered retired mechanic identifiers. No owner,
port, sink, receipt, UI, save section, effect kind or replacement mechanic was added. Main changed from
6,617 to 6,599 physical lines, 5,576 to 5,560 nonblank lines and 481 to 480
methods; fields, constants, preloads and the task-start external caller set are
unchanged. The global budget tool still reports the inherited one-file caller
baseline drift introduced before this follow-up (`103` current versus `102`
recorded baseline); this change adds no Main caller and does not update that
unrelated baseline.

## Preserved evidence and next boundary

The dirty experimental contract-response worktree was preserved without commit, reset, stash, or merge. Its patch was copied outside the repository for audit. Only retirement-aligned behavior was reimplemented against the current production tree.

Next boundary: `PLAYTEST_ALPHA_0_1_RELEASE_CANDIDATE_PROGRAM`. The retirement cutover does not declare the broader alpha release complete.

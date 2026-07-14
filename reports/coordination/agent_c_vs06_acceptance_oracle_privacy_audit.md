# VS06-C5 Acceptance Oracle Hygiene + Privacy Source Audit

状态：完成。仅修改 TomorrowVerticalSlice 验收台、自检入口与本报告；未修改生产代码，未运行完整 slice、MCP 或有头场景。

## Stage 3 oracle 修正

普通 `setup_start` 不会启动 scenario/campaign，因此 `completed_signals.monster_summoned` 不再参与 Stage 3 成败。该信号仍以诊断字段记录，但 `scenario_signal_gated=false`，也不据此宣称 campaign objective 已推进。

Stage 3 现在只在以下权威 owner 事实全部成立时 PASS：

- 首召已提交，CardResolutionQueue 已 drained；
- `monster_count == before_count + 1`；
- 本次仅新增一个 terminal，且该 terminal 的 stage 与 receipt 均为 `finalized`；
- `inflight_count == 0`；
- `checkpoint_open == true`，其含义明确记录为“finalize 后权威 reservation 集为空，可以 checkpoint”。

Evidence 新增 `terminal_evidence`、`new_terminal_count`、`finalized_count`、`inflight_count`、`checkpoint_semantics`、scenario 非门控诊断。这样不会把 `checkpoint_open=true` 误判为未关闭事务。

新增纯 oracle self-check：两个 scenario signal 取值都接受；submitted、queue、count delta、terminal 数量、finalized 状态、terminal receipt、inflight、checkpoint 八种弱化证据全部拒绝。

## 未完成的 campaign 缺口

本修正只证明普通新局首召完成 Monster owner 的 exact-once lifecycle。它不证明 active campaign 的首召 objective、scenario revision 或 completed signal 推进。

建议另建 focused gate：先经权威 campaign/scenario start 入口建立 active objective，再执行一次真实首召，断言 objective revision 精确 +1、`monster_summoned` signal 出现一次、相关 campaign receipt terminal finalized，重放不二次推进。不要把该 gate 合并回普通 `setup_start` Stage 3。

## Stage 9 四项泄漏来源

权威 manifest：`reports/playability/tomorrow_vertical_slice/coordinator_runtime_manifest.json`。Harness 未增加过滤或白名单，四项生产缺口继续保持 FAIL。

### 1–2. `setup.seats[1/2].monster_label`

分类：AI starter 的公共 schema 通道泄漏。当前实现已把 AI 值替换成“匿名起始怪兽”，但仍向公开 seat snapshot 暴露被策略禁止的 `monster_label` 字段，因此两个 AI seat 各报一项。

调用链：

`main.gd::_new_game_setup_page_snapshot` → `_new_game_setup_seat_card_snapshot`（产生 `monster_label`）→ `NewGameSetupPage.set_page/_render_seats` → `new_game_setup_seat_card.gd::set_seat`（读取该字段并渲染）。

最小 owner：NewGameSetup 公共 presentation schema，当前生产点在 `scripts/main.gd::_new_game_setup_seat_card_snapshot`，消费点在 `scripts/ui/new_game_setup_seat_card.gd::set_seat`。应为 AI 输出不含 starter-specific key 的公开 allowlist（UI 使用固定匿名文案或明确的非敏感 visibility 字段）；不能由 Monster owner、catalog 或验收台猜测/擦除。

### 3. `district_supply.ai_view.player_cash` sentinel

分类：viewer/subject 混同造成的对手精确现金泄漏。

调用链：

`main.gd::_district_supply_snapshot_source(district, player_index)` 直接从 `players[player_index].cash` 产生 `player_cash` → 正常渲染路径为 `_refresh_district_supply_overlay` → `GameRuntimeCoordinator.compose_district_supply_snapshot` → `DistrictSupplySnapshotService.compose/_header_chips` → drawer `set_supply`。Stage 9 使用 AI subject 调用同一生产 source，sentinel 原样出现。

最小 owner：`scripts/main.gd::_district_supply_snapshot_source`，因为它同时拥有本地 viewer 身份与玩家私有状态。对非本地真人 subject 必须 fail-closed 或输出不含 viewer-private 字段的公共 schema；不能依赖 UI 当前把 AI seat 重定向到真人来充当 API 权限检查。若未来支持 spectator，`DistrictSupplySnapshotService` contract 还应显式区分 viewer 与 subject。

### 4. `district_supply.ai_view.counted_hand_size`

分类：与现金相同的 viewer/subject 混同；泄漏对手精确手牌数量，而且字段名本身在公共递归禁表中。

调用链：

`main.gd::_district_supply_snapshot_source` → `_player_counted_hand_size(player)` → `counted_hand_size` → `GameRuntimeCoordinator.compose_district_supply_snapshot` → `DistrictSupplySnapshotService._header_chips` 渲染“手牌 n/limit”。

最小 owner：同上，由 `main.gd` 的 source 权限边界只为权威本地 viewer 提供精确手牌数。`DistrictSupplySnapshotService` 当前把该字段列为 REQUIRED，适用于 viewer-private drawer，不等于它可接受任意 AI subject；需要公开视图时应拆分 schema，不得在 harness 白名单该字段。

## 修改与最小验证

- `scripts/tools/tomorrow_playable_vertical_slice_bench.gd`
- `tests/tomorrow_playable_vertical_slice_test.gd`
- `reports/coordination/agent_c_vs06_acceptance_oracle_privacy_audit.md`

Godot 4.7 stable，隔离 APPDATA：

- parse-only：PASS，failures=0；
- `--stage3-oracle-self-check`：PASS，10 probes（2 个 scenario-independent controls + 8 个拒绝 mutation），failures=0。

未访问默认玩家存档，未执行统一完整 slice。Stage 9 只有生产 owner 修复并由协调线程重跑后才能转绿。

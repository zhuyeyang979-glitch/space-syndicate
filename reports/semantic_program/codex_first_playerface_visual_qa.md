# Codex First PlayerFace Visual QA

## Verdict

`STATUS=CODEX_FIRST_PLAYERFACE_VISUAL_QA_GREEN`

Final headed production acceptance passed on Godot `4.7-stable (official)`.
The real main scene reached Card Codex browser, hover, and detail through user
input at exact `1280x720` and `1920x1080` framebuffers. No gameplay, production,
scene, or test file was changed by this QA pass.

## Candidate

- Worktree: `C:/Users/zhuye/Documents/New project/space-syndicate-codex-first-playerface-46b356f`
- HEAD reference: `46b356f99da5b536f877d96a946ceddd1720fef4`
- Final localization owner SHA-256: `a6f6399d0d4d740cf098c280e5f7f1bc2819a94d802a1778ed1f2be6320bf7de`
- Public token manifest SHA-256: `fb7a900be8a60868806c92be25db60158b907ab79d7d3a8e45822937d7d55513`
- Renderer: compatibility, headed standalone game window
- MCP endpoint: `http://127.0.0.1:7465/`

The final session was started after the presentation-only stable-value fix.
Earlier helper parse errors and pre-fix screenshots were excluded by fully
restarting the editor before this acceptance run.

### Final Code Fingerprints

| Production artifact | SHA-256 |
| --- | --- |
| `scripts/runtime/card_player_face_public_localization_source_service.gd` | `a6f6399d0d4d740cf098c280e5f7f1bc2819a94d802a1778ed1f2be6320bf7de` |
| `scripts/presentation/card_player_face_public_token_manifest_v1.gd` | `fb7a900be8a60868806c92be25db60158b907ab79d7d3a8e45822937d7d55513` |
| `scripts/presentation/player_card_codex_dto_v1.gd` | `9bfce72773cfd1ff0242f82c8a119e49f2d44e0eb42920a6077530d61efd477e` |
| `scripts/runtime/card_player_face_projection_service.gd` | `0629c04f7bfeb418fc60a75f3dc4daccea455c0c793df4dfd2b05df70a1441a0` |
| `scripts/runtime/card_codex_public_source_service.gd` | `135f3676c7cba05b83e0a2b85956520819e8ffb4e2b608cb8a73332a4971a6a8` |
| `scripts/runtime/card_codex_public_source_adapter.gd` | `db93a206196f11c3868a53d2ee6d121cea5c9670296d66fe7e020becefdeb90a` |
| `scripts/runtime/card_codex_public_snapshot_service.gd` | `246f5be2335866e0f630b3ee4c0f00bc2afe62aa286b22e970a21c3e703d8111` |
| `scripts/tools/card_codex_playerface_production_bench.gd` | `296a7efcd3e54a3e491bf4d489d71fdf435e5ac76a41a2af1d9d09735d038329` |
| `scenes/runtime/GameRuntimeCoordinator.tscn` | `ced56c2b26a7813563989e4baf3732d3cc9d9df2d32615a719f542a481dfde80` |
| `scenes/tools/CardCodexPlayerFaceProductionBench.tscn` | `d520007479b9430d7748feecd3168d5e230798f1d17b3a4a7fe6892f8587e312` |

## Final Read-Only MCP Recheck

The final uncommitted candidate was rechecked through the real Godot MCP on
Godot `4.7-stable (official)`. This pass did not modify production or test code
and did not rerun a long smoke test.

| Gate | Final recheck evidence |
| --- | --- |
| Production composition | Exactly one `CardSemanticCatalogService`, `CardPlayerFacePublicLocalizationSourceService`, `CardPlayerFaceProjectionService`, `CardCodexPublicSnapshotService`, and `CardCodexPublicSourceService`. |
| Production bench | `PASS`; failure IDs `[]`, failure count `0`. |
| Catalog coverage | `348` cards, `87` families, `7` categories; browser page contained `40` cards. |
| Browser/detail | `browser_compose_count=2`; `detail_compose_count=1`. |
| Authorization/cache | `catalog_record_authorization_count=348`; catalog snapshots `1`; reloads `0`; semantic compile delta `0`. |
| Rank samples | `星露莓 I` and `星露莓 IV`, each projected as `card_codex.public`; semantic and localization bindings matched per card. |
| Costs | Separate acquisition and activation fields rendered as `免费领取` and `打出免费`. |
| Structured rules | Timing, target, conditions, ordered effect steps, duration, counterability, and information scope were all present. |
| Internal IDs | Focused player-visible scan across the I/IV samples returned `0` hits. |
| Fresh errors | Console errors `0`; seven final-chain scripts validated with diagnostics `0`; runtime failed events `0`. |
| Stop and cleanup | MCP stop succeeded; `is_playing_scene=false`; final Godot process count `0`. |

The two sample DTOs retained closed `PlayerCardCodexDTOv1` data and exact
owner-attested bindings. Rank I exposed rate `10`; rank IV exposed rate `80`.
Both used the localized player-facing condition, target, duration, and facility
labels without leaking stable internal IDs into the checked visible fields.

## Results

| Gate | Result | Final evidence |
| --- | --- | --- |
| Coordinator composition | PASS | Exactly one semantic catalog, public localization owner, PlayerFace projection service, Codex snapshot service, and Codex source service in `GameRuntimeCoordinator.tscn`. |
| Lazy production binding | PASS | Before Codex: bound dependencies, projection cache false, DTO count 0. After open: cache true, 348 DTO projections, one catalog snapshot, 348 authorizations. |
| Main production path | PASS | Main scene -> 资料库 -> 卡牌图鉴 through real runtime input. |
| Browser | PASS | 348 cards, 35 pages, stable page navigation, no contract errors. |
| Hover | PASS | Real pointer hover showed separated costs, timing, target, conditions, effect, and I-IV summary. |
| Double-click detail | PASS | 1280 used verified OS down/up double-click on the card parent; 1920 used Computer Use `click_count=2` on the live Godot window. Both produced `_view=detail` and incremented `detail_compose_count`. |
| Seven categories | PASS | Interactive counts: commodity 184, facility 64, supply/demand 8, monster 32, military 28, interaction 12, organization 20. |
| Ranks I and IV | PASS | Rank I and IV were visible together in the first browser family and present in the four-rank detail ladder. |
| Cost separation | PASS | `免费领取｜打出免费`; acquisition and activation remain separate fields/labels. |
| Structured semantics | PASS | Timing, target, conditions, ordered effects, duration, counterability, and information scope rendered as distinct sections. |
| Internal semantic values | PASS | Focused runtime text scan found 0 occurrences of `_id`, `_ids`, `until_`, `rate_axis`, `rate_subject`, `facility_kind`, `card_family`, or `production_or_demand`. No `按卡牌定义` placeholder appeared. |
| Unknown values | PASS | No raw unknown stable value or empty collection member was visible; unknown values were omitted without layout residue. |
| Fallback illustration | PASS | `孢子丝绸 II`: procedural `ArtView.visible=true`, `IllustrationLayer.visible=false`, source texture null. |
| Real illustration | PASS | `环晶电池 I`: `ArtView.visible=false`, illustration layer and source texture visible; texture `res://assets/art/cards/v06/style_keys/commodity/ring_crystal_battery_v01.png`. |
| Long text and overlap | PASS | Browser, hover, structured detail, scrolled fact grid, I-IV ladder, and resolution panel were visually inspected. No incoherent overlap at either resolution. |
| Console | PASS | Final 1280 and 1920 fresh game error queries returned 0 lines; final editor log contained 0 script/parse/error lines; runtime failed events 0. |
| Stop and cleanup | PASS | `exit_play_mode`, `is_playing_scene=false`, editor exit, final project Godot process count 0. |

## Structured Detail

The inspected production detail exposed player-facing content only:

```text
出牌时机: 普通出牌窗口
目标: 同产业设施；玩家选择；恰好一个
条件: 设施为工厂或市场；产业与卡牌一致
费用: 免费领取｜打出免费
按序效果: 安装生产或需求速率（产业=生命；持续策略=设施被摧毁时结束；
          每分钟速率=20；适用设施=[工厂、市场]）
持续与反制: 持续策略=设施被摧毁时结束｜不可反制
信息范围: 仅向获授权的当前界面公开
```

The I-IV ladder independently showed rates `10 / 20 / 40 / 80` with localized
duration, target, condition, and facility labels. The focused projection text
scan returned `raw_internal_hit_count=0`.

## Viewports

### 1280x720

- Standalone client and MCP capture both reported exactly `1280x720`.
- Browser showed all category chips and ranks I-IV without clipping.
- Hover preview was scrolled into view and remained legible.
- Detail top and scrolled long-content views showed no raw IDs or overlap.
- Fallback and real illustration states were both inspected.

### 1920x1080

- Windows initially constrained the restored client to `1920x1044`; a scoped
  `SetWindowPos` corrected the client to exactly `1920x1080` before evidence.
- MCP then captured exact `1920x1080` browser, hover, and detail framebuffers.
- Browser density, long hover copy, tactical cards, and ordered-effect copy did
  not overlap. Detail was opened by a real system double-click, not a test hook.

## Screenshot Evidence

All files are role-local MCP evidence outside tracked repository content under
`user://funplay_mcp_runtime_screenshots/`.

| View | Size | File | SHA-256 |
| --- | --- | --- | --- |
| 1280 browser | 1280x720 | `runtime_50065678.png` | `1b9781f7bab14eae68829204c958255a576661afbe3a7a1a40da52a83f292280` |
| 1280 hover | 1280x720 | `runtime_102358408.png` | `a88e25ad01f5f7f966e1fea10582812e9f205adad54376a3ba84b8075611db0d` |
| 1280 detail top | 1280x720 | `runtime_160159769.png` | `cdfb2754d4ed1313049c266326273c5c8d596f68cedb801edf01184ed1919ca6` |
| 1280 detail long | 1280x720 | `runtime_233061704.png` | `9fe240f51d62e0b496ba4b81210672818043a7fc58a5c72930471da7099ff457` |
| 1280 real art | 1280x720 | `runtime_269662893.png` | `026a4d99a94e397ee779d7d11798cb92a783fe9e99abebd98358581e79575742` |
| 1920 browser | 1920x1080 | `final_codex_1920_browser.png` | `7097c94eed00e5122e585cc51c1d053ba812ce8ab35c3fd754855e3af2793dff` |
| 1920 hover | 1920x1080 | `final_codex_1920_hover.png` | `9d2557555f026e6e78b965b2d23b46156ed8235b1fd69c3942ba2e68d96d3e1b` |
| 1920 detail | 1920x1080 | `final_codex_1920_detail.png` | `8e7eda0efca1e8361ce4c27732facbe185e549261b7075ad5e1a787a36dac97f` |

## Runtime And Cleanup

```text
1280 console error lines: 0
1280 failed runtime events: 0
1920 console error lines: 0
1920 failed runtime events: 0
fresh editor script/parse/error lines: 0
final recheck validated scripts: 7
final recheck script diagnostics: 0
final recheck visible internal ID hits: 0
semantic compile delta: 0
contract errors: []
is_playing_scene after stop: false
Godot processes after editor exit: 0
```

Only this Markdown report and its JSON companion were updated by the visual QA
agent. The shared candidate worktree remains intentionally dirty with the main
Agent's production and test changes.

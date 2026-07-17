# 太空辛迪加｜角色围桌美术与 Seat Skin 交付报告

## 结论

- 美术管线与纯视觉 Skin：完成独立交付。
- 正式八席原位接入：延期。
- 产品结论：`SKIN_READY_INTEGRATION_DEFERRED`。
- 并发结论：`PARTIAL_ONLY_CONFLICTS_DETECTED`。

延期不是因为另造了一套牌桌，而是只读审计发现当前生产代码只有八个固定装饰光圈，没有玩家绑定的席位节点；同时另一 Codex 正在改动 PlanetMapView、GameScreen、PlayerBoard、table viewmodel 和布局测试。自动接入会猜测不存在的玩家映射并覆盖并行工作，因此本批保持 fail-closed。

## 工作区与并发

- 独立 worktree：`C:/Users/Administrator/Documents/New project/space-syndicate-role-table-art-20260717-012745`
- 分支：`codex/temporary-role-table-art-20260717-012745`
- 基线 HEAD：`fa7ca46ede14c9149ca4d94827b4003134bd98fe`
- 原工作区：`C:/Users/Administrator/Documents/New project/space-syndicate-sync`
- 原工作区分支：`integration/v06-playable`
- 观察到 A、B、C 及本任务的独立 worktree；B 干净，C 的最新提交涉及生产 UI，A 有导入 sidecar，原工作区有大量未提交开发内容。
- 另一 Codex 可能正在处理：GameScreen/PlanetMapView 场景化、PlayerBoard、table snapshot/viewmodel、布局验收。

本任务没有向原工作区、A/B/C worktree 写入文件；没有 reset、stash、merge、rebase、commit 或 push。

## sub-agent 与所有权

| agent | 职责 | 写权限/结果 |
|---|---|---|
| coordination_sentinel | 多阶段并发巡检 | 只读；给出生产接入 RED、独立 Skin GREEN |
| repository_mapper | 项目、角色目录、Planet/GameScreen 扩展点 | 只读 |
| asset_curator | 官方包、CC0、候选模型与 24 角色绑定 | 只读策展 |
| art_pipeline_builder | 下载/索引/渲染管线 | `tools/art_pipeline/**`、`art_sources/**`、许可证、临时 PNG |
| table_ui_builder | QA 场景和视觉组件 | 独立 UI/preview 文件；未触碰生产场景 |
| qa_conflict_reviewer | 图片、隐私、方向、sidecar 与冲突 QA | 只读；发现并修正左右翻转问题 |
| current_seat_system_auditor | 当前八席逆向审计 | 只读；确认只有八个装饰光圈 |

主 agent 只在独立 worktree 合并这些结果并实现正式 Skin、Bench、测试和报告。

## 阶段判定

| 阶段 | 判定 | 说明 |
|---|---|---|
| 原工作区启动检查 | YELLOW | 原工作区脏，全部未提交文件视为另一进程所有 |
| 独立 worktree 创建 | GREEN | 唯一分支/路径，无共享写入 |
| 官方素材与许可证管线 | GREEN | 只触碰独立新目录 |
| QA 围桌预览 | YELLOW | 邻近生产 UI，但没有相同文件；明确 QA-only |
| 当前八席生产审计 | RED | 宿主缺失且并发 UI 路径热修改 |
| 纯视觉 Skin | GREEN | 新文件，不拥有布局/输入/玩家映射 |
| focused tests / Godot MCP Bench | GREEN | 独立项目、真实场景、errors=[]、finalErrors=[] |
| 最终自动集成 | RED | 不修改共享生产场景，交付最小接线说明 |

## 当前抽象八席审计

生产场景链：

`GameScreen → PlanetBoard/PlanetStageViewport/MapHost → PlanetMapView/BackdropLayer/PlanetGlobeBackdrop`

`PlanetGlobeBackdrop._draw_table_ring()` 固定 `range(8)` 绘制装饰圆弧。它们没有节点、玩家映射、3–8 人显隐、本地玩家锚点、状态、tooltip 或输入。旧 `MapView._draw_betting_table_edge_chips()` 也是同类 fallback。

- 布局逻辑：只有 `angle=-PI/2+TAU*(i+0.5)/8` 的装饰公式，不是玩家座位布局。
- 状态逻辑：不存在。
- 待淘汰视觉：八个金色装饰弧。
- 保留节点：GameScreen、PlanetBoard、PlanetStageViewport、MapHost、PlanetMapView、PlanetGlobeBackdrop 全部未改。
- 旧视觉隐藏/legacy：尚未改生产；只有未来宿主接入后才能逐席单显示切换。
- 新 Skin 正式路径：`scenes/ui/player_seat/PlayerSeatPortraitSkin.tscn`；目前仅在独立 Bench 宿主中验证，未挂入生产。
- 原八席坐标、3–8 映射：生产没有可验证的玩家映射，因此未伪造“保持”。
- 中央星球尺寸：未修改，变化 0%。
- 地图输入：生产代码未修改；Skin 全部装饰 Control 为 `MOUSE_FILTER_IGNORE`。
- 重复席位：生产没有新增席位，重复数 0。

完整机器合同见 `docs/art_qa/current_seat_audit/current_seat_contract.json`，人工审计见 `current_seat_system.md`。

## 官方素材与许可证

仅允许以下 Quaternius 包：Universal Base Characters Standard、Ultimate Monsters、Ultimate Space Kit、Sci-Fi Essentials Kit Standard、Animated Fish Pack。

本批实际取得并索引的是官方 Animated Fish Pack，共 7 个 FBX。其他四包没有使用非官方镜像；官方交互下载要求写在 `art_sources/inbox/README.md`，放入后管线可继续。

许可证证据：

- `docs/licenses/third_party_art/quaternius_animated_fish_CC0.txt`
- `docs/licenses/third_party_art/quaternius_ultimate_monsters_CC0.txt`
- `docs/licenses/third_party_art/quaternius_ultimate_space_kit_CC0.txt`
- `docs/licenses/third_party_art/CC0-1.0-legalcode.txt`
- `docs/licenses/third_party_art/README.md`

实际已用素材的 manifest、source index、模型 SHA-256、许可证 SHA-256 和衍生 PNG SHA-256 已形成闭环。完整第三方模型缓存和压缩包未作为交付内容。

## 24 角色绑定

| 角色 | 最终状态 | 实际/计划底材 | 处理 |
|---|---|---|---|
| 环港走私议会 | pending | Ultimate Monsters Armabee | 短触角、收翼、黑蓝、电池核心 |
| 深海菌毯使团 | pending | MushroomKing/Mushnub + Fish fin | 深青菌绿、雾鳃 |
| 重力矿联董事会 | pending | Ultimate Space 最厚机甲 | 隐武器、玄武岩、紫核心 |
| 离子军购局 | pending | Sci-Fi Essentials robot | 深蓝黑、蓝面、高领 |
| 光合修复会 | pending | Cactoro | 弱尖刺、叶冠、凝胶核 |
| 虹膜数据券商 | pending | single-eye monster | 棱镜面罩、青紫眼 |
| 星鲸餐饮垄断 | rendered | `Whale.fbx` | 直立头颈、藏下身、餐饮徽章 |
| 静电蜂巢银行 | pending | Armabee_Evolved | 金翼、琥珀六边核 |
| 星图审计庭 | pending | Ultimate Space astronaut | 银环、单镜片、冷白 |
| 幽幕播报社 | pending | Sci-Fi screen robot | 黑屏、扫描线、紫高领 |
| 双边密约公证团 | pending | Squidle | 收触手、镜银、双扣 |
| 碎光私探行会 | pending | Universal Teen | 全遮脸、非对称晶盔 |
| 星门补给商会 | pending | Ultimate Space astronaut | 折跃框、仓储肩件 |
| 赤环航运托拉斯 | rendered | `Dolphin.fbx` | 头颈裁切、开口红环、珍珠 |
| 霓虹需求剧院 | pending | Ghost | 半透明剧幕、小面积霓虹 |
| 极昼农业云 | pending | Tribal | 隐武器、太阳叶冠 |
| 黑潮风险基金 | rendered | `Shark.fbx` | 墨黑哑光、行情线、弱牙齿 |
| 白噪安保公司 | pending | Birb/Pigeon/Chicken | 白灰、信号面罩、隐武器 |
| 钛壳互助清算所 | pending | shell-like monster | 钛银、绿色修复核 |
| 暗礁公证黑市 | rendered | `Fish2.fbx` | 藏下身、暗珊瑚冠、旧金印 |
| 太阳鳞片王朝 | pending | Dragon/Dragon_Evolved | 收翼、哑金、绯红披肩 |
| 孪星兽栏同盟 | pending | dual-shoulder mech | 隐武器、双核 |
| 蜂巢防务议会 | pending | square heavy mech | 隐武器、六节点 |
| 悖论兽契社 | pending | Universal Regular/Superhero | 全遮脸、相位壳、沙漏核 |

已渲染四个角色的真实模型路径和 SHA-256 记录在 `assets/art/role_portraits/temporary/manifest.json`，没有根据预期名称伪造路径。

## PNG 与场景资产

- 运行时 PNG：8 张（4 角色 × front/side_inward）。
- 每张：512×768 RGBA，透明背景。
- 总大小：775,658 bytes。
- 运行时策略：`pre_rendered_png_only`，正式游戏不加载第三方 3D 模型。
- 候选联系表：`docs/art_qa/source_candidates/contact_sheet.png`。
- 角色联系表：`docs/art_qa/role_portraits/contact_sheet.png`。
- Godot 美工板块：`scenes/tools/RolePortraitRenderRig.tscn`，含透明 SubViewport、前/侧相机、三点灯光、环境、统一领圈和附件根。
- Seat Skin：`scenes/ui/player_seat/PlayerSeatPortraitSkin.tscn`。
- Skin Bench：`scenes/tools/PlayerSeatPortraitSkinBench.tscn`。

## 截图与 QA

- 真实 Skin Bench：`docs/art_qa/current_seat_audit/player_seat_portrait_skin_bench.png`。
- QA-only 3/4/6/8 围桌研究：`docs/art_qa/table_layout/planet_table_{3,4,6,8}_players.png`。
- 渲染装置运行截图：`docs/art_qa/role_portraits/role_portrait_render_rig_runtime.png`。

3/4/6/8 图不是正式接入证据。`before_3/4/6/8`、`after_3/4/6/8`、before/after board 和 seat anchor overlay 没有伪造：当前生产没有功能席位映射，且共享接入链 RED。`before_layout_metrics.json` 明确记录了哪些度量不存在。

## 隐私与回退

Skin 只接受 seat index、公开玩家名、公开角色名、玩家色、公开状态、方向与深度等字段。它不接受或输出现金、手牌、隐藏 owner、匿名真实出牌者或 AI 计划。

匿名行动期间即使 host 误传 `is_publicly_active`，Skin 也不显示行动者高亮。有真实 PNG 时 Skin 单独显示；没有 PNG 时 Skin 隐藏，未来宿主保留旧抽象视觉。QA catalog 的程序渐变仅用于独立预览，不是正式 Skin 的“成功资源”。

## Godot MCP 与测试

Godot MCP：

- `get_godot_version`：4.7 stable。
- `get_project_info`：确认独立 worktree。
- `run_project res://scenes/tools/PlayerSeatPortraitSkinBench.tscn`：真实 Forward+ 场景运行。
- debug：`errors=[]`；真实 PNG 可用、缺图 legacy fallback、单双显示互斥、Skin 无 layout/mapping/input 权。
- `stop_project`：`finalErrors=[]`。

Focused 结果：

- `validate_role_portraits.py`：24 unique，rendered=4，pending=20；模型/许可证/PNG hash 闭环。
- `art_pipeline_scene_test.gd`：166/166 PASS。
- `player_seat_portrait_component_test.gd`：150/150 PASS（QA-only）。
- `player_seat_portrait_skin_test.gd`：17/17 PASS。
- 合计：333/333 PASS。

## 自动集成与待应用补丁

自动修改的共享生产文件：无。

因冲突未集成：GameScreen、PlanetBoard、PlanetMapView、PlanetGlobeBackdrop、PlayerBoard、table viewmodel、layout tests。

未来最小接线说明：`docs/art_qa/current_seat_audit/production_integration_patch.md`。在 authoritative host 出现前，不得从装饰弧猜测 player mapping，也不得采用 QA `PlanetSeatLayout`。

## 明确确认

- 没有重置、stash、删除或覆盖另一进程修改。
- 没有向另一 worktree 写文件。
- 没有自动 merge/rebase。
- 没有 commit/push。
- 没有覆盖冲突文件。
- 没有提交压缩包、完整第三方模型缓存或外部 `.git`。
- 没有把 QA 独立人物环报告为正式实现。

最终状态：`PARTIAL_ONLY_CONFLICTS_DETECTED`；正式产品结论：`SKIN_READY_INTEGRATION_DEFERRED`。

# 下一步任务 Prompt：开源卡牌插画占位与统一化实验室 v0.6

## 给 Codex 的执行指令

在 `space-syndicate-sync` 中完成“六张代表牌的开源插画占位与统一化”下一步。此阶段的目标不是继续批量生成插画，而是证明现有已授权素材经过统一的 Godot 场景化处理后，能够支撑可玩原型并准确暴露真正的美术缺口。

本任务的图像生成预算为 **0 张**。不要调用图像生成工具；只有在完成真实 Godot 对比、形成缺口报告并获得用户下一次明确批准后，才允许为缺口单独生成新风格钥匙。

## 开始前读取

- `AGENTS.md`
- `docs/art_production_contract.md`
- `docs/art_direction.md`
- `docs/third_party_assets.md`
- `docs/card_frame_spec.md`
- `docs/card_visual_theme_contract.md`
- `docs/player_facing_text_and_rules_presentation_contract.md`
- `docs/next_task_prompt_card_art_style_key_v06.md`
- `reports/art/card_style_keys/ring_crystal_battery_style_key_v01_validation.md`
- `data/art/card_illustration_manifest_v06.json`
- `data/art/monster_body_art_manifest.json`
- `data/ui/card_ui_skin_lab_cards_v06.json`

同时检查当前工作区和其他 agent 的最近修改。只处理卡牌美术清单、通用插画呈现层、专用验证场景与报告；不要修改规则、经济数值、存档协议、卡牌结算、AI 或运行时所有权。

## 本次候选素材与许可边界

优先使用项目中已经导入、已经记录许可、可被 Godot 直接加载的素材。不要从 `reference/` 目录直接复制图片；Terraforming Mars、Gaia Project、Hypnagonia、UiCard 和 Night Patrol 在本任务中只可继续作为布局或交互参考，除非某个文件的独立许可、作者、署名和衍生边界已经逐项确认。

不得扩大 Night Patrol 的新依赖。它目前是 CC BY-NC 4.0 的非商业原型层，已有引用可以保留，但本任务不能把它当作新卡牌插画来源。

本次六张牌的首选占位来源：

| 卡牌 | 首选素材 | 许可与用途 |
|---|---|---|
| 环晶电池 I | `res://assets/art/cards/v06/style_keys/commodity/ring_crystal_battery_v01.png` | 项目内生成的风格钥匙候选；保持不变 |
| 轨道仓库 I | `res://assets/third_party/game_icons_ccby/warehouse.svg` | CC BY 3.0；语义占位；必须保留作者署名链 |
| 远洋采购令 I | `res://assets/third_party/game_icons_ccby/contract.svg` | CC BY 3.0；订单/采购语义占位 |
| 近地供货潮 I | `res://assets/third_party/game_icons_ccby/profit.svg` | CC BY 3.0；产出增长语义占位；用程序货流纹样补足“供货”含义 |
| 孢雾海皇 I | `res://assets/third_party/superpowers_cc0/medieval-fantasy/monsters/dragon.png` | CC0；必须与 `monster_body_art_manifest.json` 当前唯一身体映射一致 |
| 相位否决 I | `res://assets/third_party/game_icons_ccby/cancel.svg` | CC BY 3.0；反制/无效化语义占位 |

可以评估下列已导入素材作为第二层装饰或明确回退，但不能因此让两张牌的第一视觉锚点相同：

- `shaking_hands.svg`：撮合或履约；
- `breaking_chain.svg`：中断或拆解；
- `coins_pile.svg`：收益或成交；
- `mothkaiju_bldg_m.png` / `mothkaiju_bldg_s.png`：MIT 建筑轮廓，仅作为非怪兽设施辅助层；
- 现有 `CardArtView` 程序纹样：任何资源缺失时的最终回退。

## 实现目标

### 1. 扩展开发插画清单

扩展 `data/art/card_illustration_manifest_v06.json`，为六张代表牌逐张声明：

- `illustration_path`
- `source_type`：`authored` / `open_source_placeholder` / `procedural_fallback`
- `upstream_source_id`
- `visual_source_id`
- `license`
- `attribution`
- `commercial_status`
- `sprite_key` / `sprite_cell`
- `layout_variant`
- `palette_variant`
- `effect_variant`
- `composition_variant`
- `motif_family`
- `first_run_art_focus`
- `illustration_anchor`
- `fit_mode`
- `tint_mode`
- `status`

这些都是机器或开发字段，禁止进入玩家名称、效果、按钮、tooltip、状态和禁用原因。

### 2. 建立统一的插画处理层

不要直接修改第三方图片。通过 Godot 场景节点、材质或轻量 shader 建立一个可复用的 `CardIllustrationLayer`，由共享 `CardUI` 消费清单中的呈现参数。

它至少支持：

- `cover` 与 `contain` 两种裁切；
- 产业色背板；
- 单色 SVG 的可控染色；
- 原色怪兽/自有插画的保色模式；
- 统一暗角、局部能源光、细颗粒或印刷网点；
- 一个程序化第二语义纹样，例如仓储格栅、远洋弧线、供货流、孢雾场、相位取消环；
- 手掌小卡、结算卡与详情卡共享同一视觉来源；
- 缺失、越界或错误资源自动回退 `CardArtView`，不能显示内部路径或英文错误。

异质素材经过处理后应像同一套高端科幻桌游卡，而不是把几个 SVG 和像素怪兽直接贴在矩形里。不得用大量平铺开发面板掩盖实际卡面问题。

### 3. 保持玩家文本与机器字段分离

- 玩家只看到本地化后的卡名、等级、类型、产业、费用、关键词、短效果、状态和原因。
- `card_id`、资源路径、许可证、作者、shader 参数、source id、raw error 只存在于开发清单、日志或验证报告。
- 玩家文本扫描必须把 `res://`、`CC0`、`CC BY`、`visual_source_id`、`sprite_key`、`raw error` 视为泄漏词。
- 署名放入未来 Credits 数据或开发清单，不塞进卡面。

### 4. 在真实 Skin Lab 中验证

必须使用项目安装的 Godot add-on MCP：

1. 识别 `space-syndicate-sync` 与 Godot 版本；
2. 用 MCP 打开项目并触发新增/变更资源导入；
3. 用 MCP 保存或确认真实验证场景；
4. 运行真实 `CardUISkinLab` 派生场景，而不是静态图片或离线 mockup；
5. 读取 debug output；
6. 在 1280×720、1600×960、1920×1080 下保存截图；
7. 检查六张牌的正常、悬停、选中、不可用、可投放、结算中状态；
8. 检查手牌、公共结算卡和右侧详情卡；
9. 验证每张牌的实际来源、fallback 和玩家文本泄漏；
10. 完成后用 MCP 停止项目。

## 硬验收门

- 本任务新增图像生成调用数必须为 0。
- 六张代表牌全部有明确插画来源；同一第一视觉锚点不得重复。
- 《环晶电池》继续使用项目自有 PNG，不能退回通用图标。
- 《孢雾海皇》必须沿用身体清单指定的 Superpowers dragon，不能换成无关怪兽。
- CC BY 素材的作者与许可在开发清单和 Credits 待办中可追溯。
- Night Patrol 不增加新的路径引用。
- 原始第三方文件保持不变；所有统一化都发生在 Godot 呈现层。
- 96 px 级别仍能区分六张牌的第一视觉锚点。
- 玩家文本泄漏为 0。
- Godot runtime errors 为 0；MCP 停止时 `finalErrors` 为空。
- `ui_text_smoke_test.gd`、`visual_snapshot.gd`、`smoke_test.gd --check-only` 通过。

## 输出

- 更新后的插画清单；
- 可复用 `CardIllustrationLayer` 场景/脚本/shader；
- 六张牌的来源与许可矩阵；
- 三种分辨率截图；
- 六张牌在手牌与详情尺寸的对比图；
- 缺失资源与越界路径 fallback 证据；
- 玩家、机器、开发字段清单；
- Godot MCP 调用记录与 debug output；
- “哪些占位已经足够、哪些类别确实值得下一轮生成”的缺口报告；
- 尚未达到最终商业美术标准的问题。

不要在本任务结束时自动开始下一批生图。先把缺口报告交给用户拍板。

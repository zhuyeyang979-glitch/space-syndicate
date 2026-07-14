# 下一步任务 Prompt：三张卡牌自有插画风格锁定批次 v0.6

## 给 Codex 的执行指令

在 `space-syndicate-sync` 中执行《太空辛迪加》v0.6 的第一组“三张自有插画风格锁定批次”。先完成本文件，再立即执行；不要扩展成整套卡池，也不要修改规则、经济数值、结算、AI、存档协议或运行时所有权。

本批次只处理上一轮真实 Godot 缺口审计认定的三张最高优先级卡牌：

1. `unit.monster.spore_tide_emperor.rank_1`／孢雾海皇 I；
2. `supply_demand.remote_sea_order.rank_1`／远洋采购令 I；
3. `supply_demand.near_land_supply.rank_1`／近地供货潮 I。

使用 built-in `imagegen`，每张牌单独生成一次，共 `3` 次。不得用一张三联画代替三个可独立导入的游戏资产。以现有《环晶电池 I》插画作为共享风格参考；孢雾海皇还要以当前 Superpowers dragon 作为身体/剪影身份参考，但不得复制像素画风。

## 读取基线

- `AGENTS.md`
- `docs/art_direction.md`
- `docs/art_production_contract.md`
- `docs/card_visual_theme_contract.md`
- `docs/card_frame_spec.md`
- `docs/player_facing_text_and_rules_presentation_contract.md`
- `reports/art/card_placeholder_lab/card_placeholder_gap_report_v06.md`
- `reports/art/card_placeholder_lab/card_placeholder_lab_v06_validation.md`
- `data/art/card_illustration_manifest_v06.json`
- `data/art/monster_body_art_manifest.json`
- `data/ui/card_ui_skin_lab_cards_v06.json`

共享风格参考：

- `assets/art/cards/v06/style_keys/commodity/ring_crystal_battery_v01.png`

孢雾海皇身体身份参考：

- `assets/third_party/superpowers_cc0/medieval-fantasy/monsters/dragon.png`

## 统一美术语言

风格名称：**星港工业版画**。

- 高端商业科幻桌游插画；图形化 2.5D 厚涂，硬边大剪影，适度写实材质。
- 深海军蓝和炭黑环境约占 65%，产业色约占 25%，冷白或金属暖光约占 10%。
- 有细微水粉、磨砂、丝网印刷颗粒；不要照片写实，也不要像素、Q 版、霓虹赛博酒吧或泛用 AI 亮面概念图。
- 单一大型主锚点占画面 55%–70%，背景只解释尺度、物流方向和世界观。
- 源图使用 3:2 横向构图；主体同时落在中央 68% 安全区和中央浅横带内，允许当前约 4:1 的 CardUI 插画窗口裁切。
- 在 96 px 级小卡中仅看剪影仍应能区分三张牌。
- 图片只包含插画：不得烘焙名称、等级、费用、关键词、卡框、UI、图标、Logo、水印、字母或数字。
- 不模仿具名艺术家，不使用现有影视或游戏系列的角色、怪兽、载具或品牌视觉。

## 图像生成 Prompt A：孢雾海皇 I

```text
Use case: stylized-concept
Asset type: landscape card illustration for an original premium sci-fi board game
Input images: Image 1 is the approved Space Syndicate style reference for materials, tonal range, lighting discipline, and graphic-painterly finish; Image 2 is only a tiny silhouette/body-identity reference for a winged serpentine dragon family, not a pixel-art style target
Primary request: an original colossal alien spore-tide emperor rising through a poisoned ocean beside a distant orbital port, a broad left-facing winged serpentine body with a long neck, angular head, heavy hooked tail, coral-like biomechanical growth and crown-like spore fins, unmistakably large enough to threaten an entire region
Scene/backdrop: dark alien sea under an orbital night sky, restrained port and coastline silhouettes for scale, rolling bioluminescent spore fog rather than fantasy clouds
Subject: one dominant monster silhouette, broad wings and curved neck kept readable, head and chest crossing the central shallow horizontal safe strip, no humanoid rider and no fantasy armor
Style/medium: premium graphic-painterly 2.5D board-game illustration, crisp hard-edge silhouette, practical biological surface detail, subtle gouache and screen-print grain, consistent with the supplied industrial sci-fi style reference
Composition/framing: 3:2 landscape; central 68 percent crop-safe; monster occupies about 65 percent; wings spread laterally so the silhouette survives an extreme 4:1 center crop; ocean and port remain secondary
Lighting/mood: cold cyan rim light from orbital infrastructure, toxic life-green spore glow, very restrained threat-magenta accents, ominous but not gory
Color palette: deep navy and charcoal, oxidized teal body armor, life green and cyan, sparse magenta warning accents
Constraints: original creature; preserve only the broad winged-serpentine body identity from Image 2; no text, letters, numbers, UI, card frame, logo, watermark, franchise imagery, named-artist imitation, blood, gore, medieval castle, rider, sword, or generic fantasy dragon illustration
Avoid: pixel art, cute mascot, photographic creature render, neon cyberpunk clutter, multiple monsters, tiny subject, details only at the top or bottom of frame
```

目标文件：

`assets/art/cards/v06/style_lock/monster/spore_tide_emperor_v01.png`

## 图像生成 Prompt B：远洋采购令 I

```text
Use case: stylized-concept
Asset type: landscape card illustration for an original premium sci-fi board game
Input images: Image 1 is the approved Space Syndicate style reference for materials, tonal range, industrial scale, and graphic-painterly finish
Primary request: a long-distance ocean procurement operation on an alien planet, with one remote production port sending valuable sealed cargo across a vast curved sea route toward a luminous demand market
Scene/backdrop: dark planetary ocean, two clearly separated orbital-industrial coast nodes, a single shallow elegant arc of cargo beacons and restrained container skiffs crossing the sea
Subject: one dominant inbound procurement arc visibly converging on the demand-side market receiver; cargo containers and receiver gate are physical sci-fi objects, not a contract document or finance symbol
Style/medium: premium graphic-painterly 2.5D board-game illustration, crisp silhouettes, rugged orbital-industry materials, subtle gouache and screen-print grain, consistent with the supplied style reference
Composition/framing: 3:2 landscape; diagonal left-to-right inward flow; both endpoint silhouettes and the bright converging arc remain inside the central shallow 4:1 crop-safe band; one readable focal route, no diagram labels
Lighting/mood: distant cool cyan navigation lights, commerce-violet receiver glow, sparse warm cargo lights, calm high-value logistical tension
Color palette: deep navy and charcoal, shipping cyan, commerce violet, small warm metallic highlights
Constraints: communicate long distance, sea transport, and demand-side consumption through the scene alone; no text, letters, numbers, UI, card frame, icons, logo, watermark, maps with labels, coins, handshake, paper contract, franchise imagery, or named-artist imitation
Avoid: generic spaceship battle, fantasy harbor, stock-market graphic, flat infographic, multiple competing routes, tiny endpoints, glossy cyberpunk city clutter
```

目标文件：

`assets/art/cards/v06/style_lock/supply_demand/remote_sea_order_v01.png`

## 图像生成 Prompt C：近地供货潮 I

```text
Use case: stylized-concept
Asset type: landscape card illustration for an original premium sci-fi board game
Input images: Image 1 is the approved Space Syndicate style reference for materials, tonal range, industrial scale, and graphic-painterly finish
Primary request: a near-distance land supply surge on an alien planet, with one compact factory core releasing newly produced sealed cargo outward along several short ground freight lanes to nearby districts
Scene/backdrop: dark rugged alien terrain, low industrial ridges and nearby market lights, practical rail and road infrastructure rather than abstract arrows
Subject: one dominant factory-supply core with three clearly readable outward cargo streams; physical convoy modules and short terrestrial lanes show production spreading outward, not financial profit
Style/medium: premium graphic-painterly 2.5D board-game illustration, crisp hard-edged machinery silhouettes, subtle gouache and screen-print grain, consistent with the supplied style reference
Composition/framing: 3:2 landscape; factory core slightly left of center and outward streams fanning through the central shallow 4:1 crop-safe band; visually opposite to the converging procurement composition; one compact local system, not a global network
Lighting/mood: life-green production glow, industrial steel, restrained warm loading lights, energetic but practical
Color palette: deep navy and charcoal, life green, industrial steel gray, sparse warm cargo highlights
Constraints: communicate nearby land transport and supply creation through the scene alone; no text, letters, numbers, UI, card frame, icons, logo, watermark, coins, profit chart, ocean route, aircraft, franchise imagery, or named-artist imitation
Avoid: generic factory portrait with no flow, financial growth symbol, flat infographic, distant intercontinental route, military convoy, glossy cyberpunk clutter, multiple focal factories
```

目标文件：

`assets/art/cards/v06/style_lock/supply_demand/near_land_supply_v01.png`

## 接入要求

1. 不覆盖现有占位素材；把三张输出保存为新的版本化 PNG。
2. 在 `card_illustration_manifest_v06.json` 中把三张牌切换为 `authored` 候选，并记录：`source_dimensions`、SHA-256、生成 prompt、稳定 `visual_source_id`、`status=style_lock_candidate_v01`。
3. 每张记录保留 `superseded_placeholder`，包含旧路径、旧来源、旧 visual source、旧许可和作者，保证来源链没有被抹掉。
4. 孢雾海皇的卡牌插画可以成为自有画面，但 `monster_body_art_manifest.json` 的地图身体源暂不改。卡牌 manifest 需要记录 `body_reference_asset_path` 和 `body_reference_visual_source_id`，证明它仍遵循该怪兽的身体身份。
5. `CardIllustrationLayer` 继续统一呈现；三张新图使用 `cover + preserve + linear`，程序纹样降低强度但保留方向/身份提示。
6. 玩家文本、卡牌规则、费用和数值完全不变；只把 fixture 的 `art_status` 改为自有风格锁定候选。

## 真实 Godot 验证

必须使用项目 Godot add-on MCP：

1. 识别 Godot 版本与项目；
2. 打开项目并导入三张 PNG；
3. 用 MCP 保存或确认新的风格锁定验证场景；
4. 运行真实 Skin Lab 派生场景；
5. 在 1280×720、1600×960、1920×1080 保存截图；
6. 分别验证孢雾海皇可投放、远洋采购令悬停、近地供货潮不可用；
7. 验证手牌、右侧详情和公共结算区共享来源；
8. 复测缺失、越界和 `..` 路径回退；
9. 读取 debug output，确保玩家文本泄漏为 0；
10. 用 MCP 停止项目，最终 `finalErrors` 为空。

## 输出

- 三张独立 PNG；
- 更新后的 manifest 与 fixture art status；
- 新的真实 Godot 验证场景、三种分辨率截图与三张重点状态截图；
- 每张最终 prompt、文件尺寸、SHA-256、视觉锚点和旧占位来源链；
- 玩家文本泄漏、fallback、测试与 Godot MCP 调用记录；
- 视觉 QA 报告，明确候选是否足以取代占位，以及仍需迭代的问题。

不得在本任务末尾自动扩展到第四张插画或整套卡池。

# 《环晶电池 I》卡牌插画风格钥匙 v01 验证

## 结论

《环晶电池 I》已经从程序占位图切换为一张项目自有的原创候选插画，并在真实 Godot 4.7 Skin Lab 中同时通过手牌、公共结算卡和右侧详情卡验证。三种分辨率截图均成功，玩家文本泄漏为 0，运行时 debug error 为 0，项目已通过 Godot MCP 停止。

这张图可以作为能源商品第一张风格钥匙继续迭代；它通过了“主体辨识与真实接入”门，但尚不建议立刻据此批量生成整套卡牌，见文末的待改进项。

## 本次自用 Prompt

完整任务边界、准确图像生成 Prompt 和验收门保存在：

- `res://docs/next_task_prompt_card_art_style_key_v06.md`

执行边界是单张风格钥匙、可选插画入口、真实 Godot 验证；没有修改游戏规则、经济数值、存档协议或运行时所有权。

## 资产与机器清单

- 卡牌：`commodity.ring_crystal_battery.rank_1`
- 玩家名称：环晶电池 I
- PNG：`res://assets/art/cards/v06/style_keys/commodity/ring_crystal_battery_v01.png`
- 尺寸：1536 × 1024
- SHA-256：`f980c9afabc85a5334f36bbf3fc2308e5754dae20351d318ea23ee91ec40a288`
- 插画清单：`res://data/art/card_illustration_manifest_v06.json`
- `visual_source_id`：`space_syndicate_authored_imagegen_v01`
- `illustration_anchor`：`ring_crystal_battery`
- 构图：中心裁切安全的环形晶体电池 + 轨道货运底座

## 接入方式

共享 `CardUI` 的 `ArtLayer` 新增了一个默认隐藏的 `TextureRect`。它只接受 `res://assets/art/cards/` 下的机器路径：

1. 有合法 PNG 时，显示正式插画并隐藏程序占位图。
2. 路径缺失、越界或资源无效时，自动恢复既有 `CardArtView`。
3. 路径只从开发插画清单按稳定 `card_id` 注入，不进入名称、效果、按钮、tooltip 或禁用原因。
4. 隐藏商品状态继续使用独立隐藏预览，不会泄露插画。

因此，同一张 PNG 会自然进入所有复用 `CardUI` 的上下文，而不是为每个页面维护一张替身。

## 三种卡牌上下文

| 上下文 | Godot 实测尺寸 | authored PNG | 视觉判断 |
|---|---:|---:|---|
| 手牌 | 123 × 142 | active | 超窄插图区仍可读出橙色环形核心 |
| 公共结算卡 | 82 × 116 | active | 只保留核心轮廓，但没有退化成无意义光团 |
| 详情检查器 | 116 × 164 | active | 能看到晶体切面、货架夹具和冷暖材质对比 |

## 分辨率截图

- [1280×720](ring_crystal_battery_style_key_1280x720.png)
- [1600×960](ring_crystal_battery_style_key_1600x960.png)
- [1920×1080](ring_crystal_battery_style_key_1920x1080.png)

三张图均来自 `res://scenes/tools/CardArtStyleKeyCapture.tscn` 的真实 Forward+ 运行，不是离线 mockup。截图保存尺寸分别精确为 1280×720、1600×960、1920×1080。

## Godot MCP 验证

使用顺序：识别 Godot 版本与项目 → 启动编辑器触发导入 → 查询 UID/导入产物 → MCP 保存验证场景 → 运行真实捕获场景 → 读取 debug output → MCP 停止项目。

最终结果：

- Godot：`4.7.stable.official.5b4e0cb0f`
- Renderer：Vulkan Forward+ / RTX 4080 SUPER
- `captures=3`
- `failures=0`
- `player_text leaks=0`
- `get_debug_output.errors=[]`
- `stop_project.finalErrors=[]`

完整调用记录和输出见 `godot_mcp_debug.log`。

## 自动检查

- `tests/ui_text_smoke_test.gd`：通过
- `tests/visual_snapshot.gd`：通过
- `tests/smoke_test.gd --check-only`：通过

## 玩家、机器与开发字段

玩家可见：名称、等级、类型、产业、费用、关键词、短效果、状态、禁用原因和下一步。

机器字段：`card_id`、`effect_kind`、`visibility_scope`、`source_rule`、`reason_code`。

开发字段：`illustration_path`、`illustration_visual_source_id`、`visual_source_id`、`sprite_key`、`sprite_cell`、构图/调色/效果 variant、SHA-256、Prompt 文档路径与 raw error。

运行时玩家文本扫描把 `res://` 列为禁词，本次结果为 0 泄漏。

## 尚未达到最终锁版的部分

1. 图像的材质表现略偏写实 CG，距离目标“轨道工业版画 / 克制丝网印刷与水粉质感”仍有一步；下一轮应降低镜面写实感和橙色 bloom。
2. 正式 PNG 当前覆盖 `CardArtView` 的中央程序纹样。后续可在 PNG 上方加一层统一、轻量的印刷颗粒与能源色校准，使不同来源插画更像同一套牌。
3. 手牌插图区只有约 30 px 高，细小夹具必然丢失；正式风格钥匙应继续把核心轮廓集中在中央 55–65%，不要用叙事性远景构图。
4. 顶部商品履带目前只显示色别、名称与简图，没有消费插画清单。是否让“清晰区”商品缩略卡显示同源裁切图，应作为下一项 UI 决策，而不是在本次单牌任务中扩大范围。
5. 本次只验证一张能源商品。批量生产前仍需要用户确认：写实度、晶体裂面密度、橙光强度、背景机械复杂度是否就是六色商品的共同基准。

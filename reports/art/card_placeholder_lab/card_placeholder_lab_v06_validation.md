# 开源卡牌插画占位实验室 v0.6 验证报告

日期：2026-07-14  
项目：`space-syndicate-sync`  
Godot：`4.7.stable.official.5b4e0cb0f`  
真实场景：`res://scenes/tools/CardIllustrationPlaceholderLabCapture.tscn`

## 验收结果

- 图像生成调用：`0`。
- 六张代表牌：`6/6` 外部插画激活。
- 来源构成：`1` 张项目自有候选，`5` 张开源占位。
- `visual_source_id`：`6/6` 唯一。
- `illustration_anchor`：`6/6` 唯一。
- 孢雾海皇路径与 `monster_body_art_manifest.json`：一致。
- 公共结算区来源：相位否决命中 `game_icons_cancel_sbed`。
- 越界路径回退：通过，原因码 `path_not_allowed`，`CardArtView` 可见；白名单同时显式拒绝反斜杠和 `.`/`..` 路径段。
- 缺失资源回退：通过，原因码 `missing_texture`，`CardArtView` 可见。
- 玩家文本泄漏：`0`。
- 最终 Godot debug `errors`：空数组。
- MCP 停止项目 `finalErrors`：空数组。
- Night Patrol 新路径：`0`。
- 规则、经济、存档、AI 与运行时所有权改动：`0`。

## 实现范围

- `data/art/card_illustration_manifest_v06.json`：六张逐牌来源、许可、视觉身份与呈现参数。
- `scenes/ui/CardIllustrationLayer.tscn`：共享场景化插画层。
- `scripts/ui/card_illustration_layer.gd`：cover/contain、过滤方式、色彩模式和 debug snapshot。
- `scripts/ui/card_illustration_overlay.gd`：仓储格栅、远洋弧线、供货流、孢雾场、能源轨道与相位取消环。
- `shaders/card_illustration_treatment.gdshader`：单色 SVG 产业色染色与原色素材保色。
- `scenes/CardUI.tscn` / `scripts/CardUI.gd`：共享消费、路径白名单和程序化回退。
- `scripts/tools/card_ui_skin_lab.gd`：只注入经过筛选的运行时呈现 profile；许可与作者不进入视图模型。
- `tests/card_illustration_layer_test.gd`：清单、素材、怪兽身份、共享层和回退测试。

## 三种分辨率

- `card_placeholder_lab_1280x720.png`
- `card_placeholder_lab_1600x960.png`
- `card_placeholder_lab_1920x1080.png`

三张均由运行中的 Godot viewport 直接保存，实际 PNG 尺寸与文件名一致。

## 六张状态/手牌与详情对比

| 状态 | 代表牌 | 截图 |
|---|---|---|
| 正常 | 环晶电池 I | `card_placeholder_state_normal_1600x960.png` |
| 悬停 | 远洋采购令 I | `card_placeholder_state_hovered_1600x960.png` |
| 选中 | 轨道仓库 I | `card_placeholder_state_selected_1600x960.png` |
| 不可用 | 近地供货潮 I | `card_placeholder_state_disabled_1600x960.png` |
| 可投放 | 孢雾海皇 I | `card_placeholder_state_drop_valid_1600x960.png` |
| 结算中 | 相位否决 I | `card_placeholder_state_resolving_1600x960.png` |

每张状态图同时保留底部扇形手牌和右侧详情卡；结算中还验证了公共结算区使用同一来源。运行时记录的手牌插画窗口为 `109–113 × 28 px`，详情卡为 `98–102 × 40 px`。

## 玩家文本与内部字段

玩家可见字段：

- 名称、等级、类型、产业归属；
- 费用/门槛、关键词 chip、2–3 行短效果；
- 使用时机、目标、完整效果、持续/终止、公开范围、关键词解释；
- 本地化按钮、状态、禁用原因和下一步。

机器字段：

- `card_id`、`action_id`、`reason_code`、`effect_kind`、`visibility_scope`、`source_rule`。

开发字段：

- `resource_path`、`illustration_path`、`illustration_profile`、`illustration_visual_source_id`；
- `source_type`、`upstream_source_id`、`visual_source_id`、`sprite_key`、`sprite_cell`；
- `license`、`attribution`、shader 参数、`raw_error`、`art_status`、`fixture_state`。

泄漏扫描把 `res://`、`CC0`、`CC BY`、`CC-BY`、`visual_source_id`、`sprite_key`、`license`、`attribution`、`upstream_source_id` 和 `raw error` 都视为禁止玩家文本；本次结果为 `0`。

## Godot MCP 记录

1. `get_godot_version`：识别为 Godot 4.7 stable。
2. `list_projects`：确认 `space-syndicate-sync` 项目。
3. `get_project_info`：读取真实项目结构。
4. `launch_editor`：打开项目并触发新场景、脚本、shader 与素材导入。
5. `get_uid`：检查共享层场景、脚本、shader 与验证场景的导入状态。
6. `save_scene`：由 MCP 加载、实例化并保存验证场景。
7. `run_project`：运行专用真实场景；首轮发现一条局部变量遮蔽 warning 并修正，最终轮重新运行。
8. `get_debug_output`：最终 `errors=[]`，全部 9 张截图和所有来源/回退/泄漏断言为 `OK`。
9. `stop_project`：最终 `finalErrors=[]`，项目已停止。

`save_scene` 的独立 dummy-renderer helper 在退出时曾报告 RID 清理消息；它不来自运行中的验证场景。最终真实项目运行及 MCP 停止输出均无错误。

## 回归测试

- `godot --headless --path . --script tests/card_illustration_layer_test.gd`：通过。
- `godot --headless --path . --script tests/ui_text_smoke_test.gd`：通过。
- `godot --headless --path . --script tests/visual_snapshot.gd`：通过。
- `godot --headless --path . --check-only --script tests/smoke_test.gd`：通过。

新增测试同时覆盖“以允许前缀开头、但包含 `..` 的路径”必须返回 `path_not_allowed`。

## 尚未达最终商业标准

详见 `card_placeholder_gap_report_v06.md`。核心问题是：像素怪兽、通用语义 SVG 与自有绘画的密度仍不同，远洋采购/近地供货仍依赖程序纹样补义，详情卡插画面积偏浅，CC BY 素材还需要最终 Credits 或替换。

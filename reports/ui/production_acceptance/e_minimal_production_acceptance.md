# Codex E｜真实 main.tscn 最小生产视觉验收

日期：2026-07-15

场景：`res://scenes/main.tscn`

结论：本次最小展示回归块通过；完整天气生命周期矩阵尚未完成，不能据此宣称 queued / forecast / active / fading / 双事件全部通过。

## Findings first

1. **P1｜星球地图信息拥挤。** 1280×720、1600×960、1920×1080 的 globe/local 视图中，区域牌、路径节点、怪兽 token 与黄色天气覆盖明显重叠；天气覆盖进一步降低底层文字对比度。此项按任务边界留到下一视觉块，不在本提交重排地图。
2. **P2｜顶栏首屏信息仍会省略。** “下一步 / 天气 / 预报”在三档分辨率均出现省略号，1280×720 最明显；当前没有边缘裁切或控件越界，但第一眼信息密度偏高。
3. **P2｜经济总览仍是长文本墙。** 三档分辨率均依赖滚动，层级主要靠居中文字而非分组；内容没有被容器硬裁掉，但底部首屏不可见。
4. **P2｜1280×720 可读性偏弱。** 主桌、右侧详情与手牌都能完整进入画面，但字号和卡面详情偏小，地图供应抽屉会遮住左上区域。

## 本块已修复并由 production runtime 证明

- 手牌卡名优先消费公开 `display_name`，不再把 `unit.*` 机器 ID 作为卡名显示；门禁没有锁死 Main helper 的具体实现。
- 地图怪兽 token 不再显示 `motif`（例如 `prism_armor` / `mud` / `ocean`），统一显示玩家文案“场上单位”。
- 区域地形、设施 chip、详情正文、选中焦点与 chip hover tooltip 均使用玩家可见中文映射。
- 经济总览默认返回按钮由 `Back` 改为“返回”。
- production capture 递归扫描所有可见 `Label.text`、`Button.text` 与 `Control.tooltip_text`；三档结果均为 `visible_machine_id_candidates=[]`、`failures=[]`。
- capture 在 `main.tscn` 入树前把 `GameSaveRuntimeCoordinator` 限定到 `user://test_runs/e_production_ui_minimal_capture.save`，运行前后清理 QA 文件；三份 JSON 均记录玩家默认存档 before/after 的存在性、字节数、mtime 与 SHA-256 完全不变。

## 最小生产截图矩阵

| 分辨率 | globe | local / 地图交互 | 经济总览 | scene tree | headed console |
| --- | --- | --- | --- | --- | --- |
| 1280×720 | [globe](e_minimal_clear_globe_1280x720.png) | [local](e_minimal_clear_local_1280x720.png) | [economy](e_minimal_economy_overview_1280x720.png) | [JSON](e_minimal_clear_1280x720_scene_tree.json) | [log](e_minimal_after_1280x720_console.log) |
| 1600×960 | [globe](e_minimal_clear_globe_1600x960.png) | [local](e_minimal_clear_local_1600x960.png) | [economy](e_minimal_economy_overview_1600x960.png) | [JSON](e_minimal_clear_1600x960_scene_tree.json) | [log](e_minimal_after_1600x960_console.log) |
| 1920×1080 | [globe](e_minimal_clear_globe_1920x1080.png) | [local](e_minimal_clear_local_1920x1080.png) | [economy](e_minimal_economy_overview_1920x1080.png) | [JSON](e_minimal_clear_1920x1080_scene_tree.json) | [log](e_minimal_after_1920x1080_console.log) |

PNG 文件像素尺寸已逐个读取核对，均与文件名和目标分辨率完全一致。三份 headed console 中 `ERROR / SCRIPT ERROR / WARNING` 命中均为 0。

## Scene tree 与公开信息边界

三份 JSON 均确认以下真实生产节点存在：

- `/root/Main/RuntimeGameScreen`
- `PlanetBoard / PlanetMapView / WeatherLayer`
- `WeatherForecastStrip`
- `RightInspector / DistrictInfoPanel`
- `PlayerBoard / HandRack`
- `MenuModalOverlay / EconomyDashboardPanel / MenuBackButton`

1600×960 代表性布局：`RuntimeGameScreen=1600×960`、`PlanetBoard=1256×613`、`PlanetMapView=560×471`、`WeatherLayer=560×471`、`RightInspector=304×613`、`HandRack=970×162`。所有值来自真实生产 scene tree JSON，不是组件 bench。

## 自动门禁

- Godot 4.7 MCP：本块修改脚本均为 0 diagnostics；真实 `main.tscn` 可打开、运行并查询运行态节点，console error 0。
- `tests/ui_text_smoke_test.gd`：PASS。
- `tests/visual_snapshot.gd`：PASS。
- `tests/smoke_test.gd --check-only`：PASS。
- `tests/layout_scene_smoke_test.gd`：完整套件仍因现存 v0.4/v0.5 owner/save/economy 与已退役 Main adapter 断言失败；本块没有为这些旧 oracle 恢复兼容层，也没有把它标为通过。

## 尚未覆盖

本轮只完成 clear 状态下的 globe、local projection/map interaction 与经济总览三档最小矩阵。queued、独立 forecast、active、fading、双事件、显式区域跳转，以及这些状态下的 RightInspector 一致性，应作为下一块真实 production lifecycle matrix；不得从本报告外推为已验收。

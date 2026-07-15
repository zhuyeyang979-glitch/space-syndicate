# Codex E｜真实 main.tscn 天气生命周期视觉验收

日期：2026-07-15

场景：`res://scenes/main.tscn`

分辨率：1600×960

结论：**部分红灯。** forecast、active、fading、同屏双区域 active 的天气状态、完整主桌帧、公开详情、经济原因、机器标识/QA 残留、存档隔离与 console 均通过；但当前生产 Coordinator 不再提供测试 helper 所需的 `execute_city_development`，本次真实新局无法生成实际城市 marker，因此“天气不遮挡城市”只有静态层级证据，没有真实城市像素证据，不能标绿。

> 2026-07-15 follow-up：A 复核首版 `dual_active` PNG 时看到大面积黑屏/主桌缺失，因此首版双事件视觉结论作废。本目录现有 8 张 PNG 与 JSON 已由同一 capture 脚本完整重跑替换；新脚本必须先取得 8 个连续 post-draw 稳定帧并再等待 3 帧，随后同时通过 scene-tree 完整性和真实 PNG 像素覆盖门，才允许保存为有效主桌证据。

## Findings first

1. **P0 / RED｜真实城市遮挡验收缺证据。** `tests/helpers/city_world_fixture_factory.gd` 通过 Coordinator 查询正式城市发展结算入口，但本基线返回 `coordinator_unavailable`，四态 scene tree 的 `city_marker_count=0`。WeatherLayer 确实位于 DistrictLayer（区域与城市）、RouteLayer、MonsterLayer 之下，但没有实际城市 marker，不能从层级推断替代真实像素验收。本块按边界不改 production，也不手工伪造城市数据。
2. **P1｜地图拥挤仍然明显。** 四张主桌均能看到区域边界、28 条路线、39 个路线节点和 3 个怪兽 token 在天气圈上方，但区域牌、路线牌、怪兽 token、太阳/天气色块互相重叠；双事件状态最拥挤。本块只记录，不改 UI。
3. **P2｜经济总览再次打开会间歇保留较深滚动位置。** 首轮 active / dual_active 的真实第二次、第四次打开直接落在正文中部，虽然天气原因仍可见，但首屏缺少标题与导航语境。follow-up 完整重跑没有再次复现，现有最终 PNG 从标题开始；由于本块没有修改 production/UI，这项只能记为间歇 finding，不能宣称已修复。
4. **P2｜经济信息仍是文本墙。** 四态都能说明“经济天气”及具体天气名称，但商品、商路与隐私说明连续铺开，天气原因不易扫读。

## 截图矩阵

| 状态 | 主桌 | 经济总览 | scene tree / gate | 天气状态 | 城市像素证据 |
| --- | --- | --- | --- | --- | --- |
| forecast | [table](e_weather_forecast_table_1600x960.png) | [economy](e_weather_forecast_economy_1600x960.png) | [JSON](e_weather_forecast_1600x960_scene_tree.json) | GREEN：1 event，forecast，剩余 30 秒 | RED：0 city marker |
| active | [table](e_weather_active_table_1600x960.png) | [economy](e_weather_active_economy_1600x960.png) | [JSON](e_weather_active_1600x960_scene_tree.json) | GREEN：1 event，active，剩余 70 秒 | RED：0 city marker |
| fading | [table](e_weather_fading_table_1600x960.png) | [economy](e_weather_fading_economy_1600x960.png) | [JSON](e_weather_fading_1600x960_scene_tree.json) | GREEN：1 event，fading，剩余 10 秒 | RED：0 city marker |
| dual active | [table](e_weather_dual_active_table_1600x960.png) | [economy](e_weather_dual_active_economy_1600x960.png) | [JSON](e_weather_dual_active_1600x960_scene_tree.json) | GREEN：2 events，active + active，2 overlay regions | RED：0 city marker |

八张 PNG 均逐文件读取为 1600×960。它们由 GUI Godot 4.7 前台阻塞运行真实生产场景直接保存，不是组件 bench 或合成图。

## 完整帧与像素覆盖 follow-up 门

四态每次主桌截图前都确认以下真实生产控件 `visible_in_tree=true`、矩形完整位于 1600×960 viewport 内，并在相同矩形内抽样实际 PNG 像素，防止“节点存在但帧未绘制”的假绿：

- `TopBar`：1568×62。
- 左侧牌架 `PlanetLeftSpaceRail`：216×240。
- `RightInspector`：304×613。
- `PlayerBoard`：1568×219。
- `HandRack`：970×162。
- `PlayerBidBoard`：280×99。

四态均为 `stable_frame_count=11`、`table_scene_integrity_gate.passed=true`、`table_pixel_integrity_gate.passed=true`。整图抽样结果均约为：非黑覆盖 100%、亮像素覆盖 28%、有效内容覆盖 39%、平均亮度 0.14。

双事件截图还与 forecast / active 中逐项较强的基线比较整图及 top / left / right / bottom 四区的亮像素、有效内容和平均亮度；最低比值约 0.98，高于 0.85 门槛。最终 [dual active 主桌](e_weather_dual_active_table_1600x960.png) 已目视确认顶栏、左右主面板、底栏、手牌和竞价板完整，不再使用首版坏帧。

## 公开展示门禁

四态逐一通过：

- Weather owner 的公开 forecast state 与区域详情 phase 一致。
- 区域详情包含正数剩余时间、恰好三项公开效果、利用文本和反制文本；真实 `DistrictInfoPanel` 可见正文包含同一阶段、效果和值。
- 经济总览公开摘要与可见仪表板都包含 `经济天气:` 和主天气中文名。
- production 主桌与经济总览递归扫描所有可见 `Label.text`、`Button.text`、`Control.tooltip_text`，机器标识候选和 QA 残留候选均为 0。
- 双事件公开 forecast 有 2 个 active event，地图 overlay 有 2 个受影响区域；compact strip 的 public debug snapshot 保留第二事件计数。

场景层级为 `WeatherLayer=2 < DistrictLayer=3 < RouteLayer=4 < MonsterLayer=5`，且 WeatherLayer 为 `MOUSE_FILTER_IGNORE`。每态真实对象计数均为 6 个区域多边形、28 条路线、39 个路线节点和 3 个怪兽 token；这些对象在截图中保持可见。唯一红灯是城市 marker 为 0。

## Save isolation

capture 在 Main 入树前将 `GameSaveRuntimeCoordinator` 指向 `user://test_runs/e_weather_lifecycle_production_capture.save`，并确认 override active。运行前后均清理该前缀的文件；最终 `qa_artifacts_after_cleanup=[]`。

玩家默认 `user://space_syndicate_current_run.save` 在本环境运行前后均不存在；before/after 的存在性、字节数、mtime、SHA-256 字典完全相等，`player_default_unchanged=true`。完整记录见 [总 gate JSON](e_weather_lifecycle_1600x960_gate.json)。

## Console 与退出

[headed console log](e_weather_lifecycle_console.log) 的 `ERROR=0`、`SCRIPT ERROR=0`、`WARNING=0`。日志包含 6 条显式 `WEATHER_LIFECYCLE_GATE_FAIL`：2 条说明城市结算 API 缺失，另 4 条是每个天气状态的真实城市遮挡门禁红灯；这些不是引擎错误，也没有被隐藏。

补充门禁：`weather_presentation_runtime_service_test.gd` 为 PASS 10/10，`weather_presentation_scene_integration_test.gd` 为 PASS 14/14，`smoke_test.gd --check-only` 为 exit 0，`git diff --check` 为 exit 0。

运行结束后 capture 进程退出；本工作树不保留 game/headless 进程。测试入口为 `res://tests/weather_lifecycle_production_capture.gd`。

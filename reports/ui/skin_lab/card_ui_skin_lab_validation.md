# Card UI Skin Lab｜Godot 运行验收

日期：2026-07-14  
项目：`space-syndicate-sync`  
Godot：`4.7.stable.official.5b4e0cb0f`  
结论：Skin Lab 是真实 `.tscn` 场景组合，已由 Godot add-on MCP 导入、运行、读取 debug output 并停止；最终截图套件 `10/10` 成功，运行错误 `0`，玩家文本泄漏 `0`。

## 场景实现边界

- 主入口：`res://scenes/tools/CardUISkinLab.tscn`
- 验收入口：`res://scenes/tools/CardUISkinLabCapture.tscn`
- 复用真实组件：`CardFace`、`HandRack`、`PlanetMapView`、`RightInspector`、`TargetingOverlay`。
- 新增场景组件：`CommodityBelt`、`CommodityBeltSlot`、`ObscuredCommodityBeltSlot`、`CardSettlementStage`、`OrbitalTableOverlay`。
- 布局由 `.tscn` 场景树定义；脚本只加载 ViewModel、切换状态、驱动 Tween 和连接信号，没有用脚本批量搭建整个界面。
- 本轮只做 v0.6 呈现 fixture，不改游戏规则、GDP、价格、法力、容量或战斗数值。
- 本地参考只用于信息结构与交互：Hypnagonia 的手牌状态与邻牌让位、Gaia Project 的合法目标上下文、Night Patrol 的前中后景层次、Terraforming Mars 的卡面语义分区、UiCard 的扇形参数化。没有复制品牌视觉、专有文本或受限制素材。

## 六张 v0.6 代表牌

| 代表牌 | 类别 | Skin Lab 主状态 | 主要验收点 |
|---|---|---|---|
| 环晶电池 I | 商品牌 | 正常 | 免费领取/打出、永久安装、能源产业 |
| 轨道仓库 I | 公共设施牌 | 选中 | 设施、收租、修复、公开所有权 |
| 远洋采购令 I | 条件式供需牌 | 悬停 | 远程、经海运、全局订单 |
| 近地供货潮 I | 条件式供需牌 | 不可用 | 本地化禁用原因与可执行下一步 |
| 孢雾海皇 I | 怪兽与军队单位牌 | 可投放 | 合法部署槽、曲线目标连线、自动开战 |
| 相位否决 I | 玩家互动与反制牌 | 结算中 | 一层响应、离开手牌、手牌收拢、公共结算 |

数据源为 `data/ui/card_ui_skin_lab_cards_v06.json`，记录显式分成 `machine / developer / player` 三层。

## 三种分辨率

| 分辨率 | 运行截图 | 结果 |
|---|---|---|
| 1280×720 | [card_ui_skin_lab_1280x720.png](card_ui_skin_lab_1280x720.png) | 通过；全部核心区域可见，详情采用滚动 |
| 1600×960 | [card_ui_skin_lab_1600x960.png](card_ui_skin_lab_1600x960.png) | 通过；主验收尺寸 |
| 1920×1080 | [card_ui_skin_lab_1920x1080.png](card_ui_skin_lab_1920x1080.png) | 通过；星球、手牌与检查器层次稳定 |

## 七种状态对比

| 状态 | 截图 | 玩家反馈 |
|---|---|---|
| 正常 | [normal](card_ui_skin_lab_state_normal_1600x960.png) | 实体阴影、稳定层级 |
| 悬停 | [hovered](card_ui_skin_lab_state_hovered_1600x960.png) | 卡牌抬起放大，左右邻牌平滑让位 |
| 选中 | [selected](card_ui_skin_lab_state_selected_1600x960.png) | 持续选中光与右侧同步详情 |
| 不可用 | [disabled](card_ui_skin_lab_state_disabled_1600x960.png) | 降低明度；同时说明原因与下一步 |
| 可投放 | [drop_valid](card_ui_skin_lab_state_drop_valid_1600x960.png) | 场景槽发光、曲线连线、目标名称与合法性同步 |
| 结算中 | [resolving](card_ui_skin_lab_state_resolving_1600x960.png) | 相位否决离开手牌，剩余五张收拢；公共结算区显示结算牌 |
| 隐藏商品 | [hidden](card_ui_skin_lab_state_hidden_1600x960.png) | 只显示产业颜色和移动方向；没有真实卡面、名称或效果数据 |

## 卡牌文本区隔示例

以“环晶电池 I”为例：

1. 名称与等级：`环晶电池` / `I`
2. 类型与产业：`商品` / `能源`
3. 费用或门槛：`免费`
4. 关键词 chip：`能源`、`免费`、`永久安装`
5. 2–3 行短效果：`永久增加 10 单位/分钟的生产或需求。`
6. 状态与下一步：`可以打出` / `选择同色工厂或市场`

以“相位否决 I”为例，右侧完整详情严格按下列顺序显示：

1. `使用时机｜合法响应窗口`
2. `目标｜一张直接针对你的玩家互动牌`
3. `完整效果｜反制目标玩家互动牌……`
4. `持续/终止｜立即结算`
5. `公开范围｜响应牌和结果公开；受保护的秘密内容仍隐藏`
6. `关键词解释｜响应 / 反制 / 一层响应`

## 玩家文本、机器字段与开发字段

| 层 | 字段 | 呈现规则 |
|---|---|---|
| 玩家文本 | `name`、`rank`、`type`、`industry`、`cost`、`timing`、`target`、`short_effect`、`effect`、`duration`、`visibility`、`keywords`、`play_state`、`disabled_reason`、`next_step` | 可以进入 Label、Button、tooltip 和无障碍名称；必须是本地化后的完整文案 |
| 机器字段 | `card_id`、`action_id`、`effect_kind`、`visibility_scope`、`source_rule`、`reason_code` | 只用于稳定身份、信号和规则桥；禁止作为玩家文案 fallback |
| 开发字段 | `fixture_state`、`art_status`、`note`、资源路径、raw error | 只进入开发日志或 debug；不得进入卡面、按钮、tooltip |

缺少本地化 action/deep-link label 时，界面显示安全文案“执行操作/查看详情”，并只在开发输出中 `push_warning`；不会把内部 ID 显示给玩家。隐藏商品槽只接收 `industry_color / direction / position_hint`，没有可泄漏的真实卡牌字段。

## Godot MCP 调用记录

| 阶段 | MCP 操作 | 结果 |
|---|---|---|
| 识别 | `get_godot_version` | `4.7.stable.official.5b4e0cb0f` |
| 识别 | `get_project_info` | 正确识别 `space-syndicate-sync`，包含现有 scenes/scripts/assets |
| 打开 | `launch_editor` | Godot 编辑器成功打开项目 |
| 创建/导入 | `create_scene` | 创建 `CardUISkinLab.tscn` 的 Godot 场景入口 |
| 基线 | `run_project(CardFace.tscn)` → `get_debug_output` → `stop_project` | 现有卡面基线无错误 |
| 场景保存 | `get_uid`、`save_scene(CardUISkinLab.tscn)` | 场景由 Godot 成功加载、实例化、打包并保存 |
| 迭代运行 | `run_project(CardUISkinLab.tscn)` → `get_debug_output` → `stop_project` | 发现并修复两个中间问题：类型推断与过高 z-index |
| 最终验收 | `run_project(CardUISkinLabCapture.tscn)` | 真实运行三种分辨率与七种状态 |
| 最终读取 | `get_debug_output` | `captures=10`、`failures=0`、`leaks=0`、`errors=[]` |
| 最终停止 | `stop_project` | `finalErrors=[]`，项目已停止 |

`save_scene` 的独立 headless helper 退出时曾打印 dummy renderer RID 清理诊断；它不在最终运行态 debug 中。最终 Skin Lab 与 Capture 运行均为 `errors=[]`。

## 最终 debug 摘要

完整结构化摘录见 [godot_mcp_final_debug.log](godot_mcp_final_debug.log)。关键行：

```text
SKIN_LAB|event=ready|cards=6|sceneized=true|rules_unchanged=true
SKIN_LAB_CAPTURE|event=player_text_scan|code=OK|clean=true|leaks=0
SKIN_LAB_CAPTURE|event=runtime_snapshot|code=OK|cards=6|sceneized=true|state=hidden
SKIN_LAB_CAPTURE|event=suite_complete|code=OK|captures=10|failures=0
get_debug_output.errors=[]
stop_project.finalErrors=[]
```

## 尚未达到最终商业发行标准的问题

1. 插画仍是统一低精度程序化占位层；下一步应先做“环晶电池 I”风格钥匙，而不是批量精绘全卡池。
2. 1280×720 下，区域标签和手牌短效果必须使用截断；信息完整性依赖右侧滚动详情。
3. 当前只完成简体中文 Skin Lab 文案；正式本地化资源、字体回退与长德文/英文压力测试尚未接入。
4. 商品履带的排名可见范围与移动是展示 fixture，尚未连接权威经济快照、抢牌竞争和网络同步。
5. 投放合法性与结算飞行动画是真实 Godot 交互状态，但仍是 Skin Lab ViewModel；尚未接入正式 v0.6 action resolver。
6. 截图覆盖结算前后状态，没有单独保存 38% 进度的“飞行中”帧；运行时 Tween 已实际执行。
7. 键鼠交互已可用；完整手柄焦点顺序、屏幕阅读器朗读和 reduced-motion 设置仍需专项 QA。

以上问题不影响本次 Skin Lab 的运行验收，但在把皮肤并入正式游戏场景前必须继续处理。

# Playtest Skeleton Contract

本契约把“真人能简单参与测试”拆成可维护的骨架，而不是零散 UI 修补。后续新增功能时，优先把信息放进对应骨架层，不要把主桌重新变成规则说明书或 debug 面板。

## 1. 途径 / Runtime Path Skeleton

- 主菜单进入新局、战役、教程/规则、图鉴，必须走 scene-owned 页面。
- Campaign / Scenario 必须能进入真实 `main.tscn` RuntimeGameScreen，不停留在 demo 外壳。
- 每条试玩路径至少有：briefing、当前目标、一个主 CTA、奖励/复盘出口。
- 主桌玩家板必须有一条短“途径条”，用 chip 显示首召、建城、买牌、出牌、终局等当前路径；不要只给玩家一句长提示。
- 自动测试要覆盖 path fixture、privacy、runtime screenshot。

## 2. 卡面 / Card Skeleton

- 手牌卡是 MiniHandCard：名称、费用、等级、类型色、插图区、关键词、2-3 行效果。
- Hover 是读牌状态；完整规则进入右侧详情、抽屉或图鉴，不常驻主桌。
- 图鉴详情是 CodexDetailCard：左侧大卡面，右侧用途、关键词、I-IV 梯度和公共结算说明。

## 3. UI / Table Skeleton

- 主桌只保留 TopBar、薄牌轨、中央星球、左右侧栏、右侧详情、底部玩家板、Overlay。
- 临时决策、竞价、结算、合约、赌局都必须停靠桌边或 OverlayLayer，不压中央星球。
- 如果同侧 UI 冲突，低优先级侧栏要临时让位。

## 4. 游戏画面 / Planet Skeleton

- 中央星球是主视觉，默认 globe，局部投影通过缩放进入。
- 地图层以 chip/rail 切换，不把长解释铺在星球上。
- 怪兽、军队、天气、路线、城市和牌轨事件必须有可读的公共视觉锚点。

## 5. 主菜单 / Main Menu Skeleton

- 主菜单是星球赌桌主题大厅，不是按钮列表。
- 命令卡应有稳定顺序：继续/新局/战役或剧本/图鉴/规则/设置。
- 不展示开发历史、废弃规则或 AI 内部说明。

## 6. 子菜单 / Submenu Skeleton

- 子页面只显示本页需要的控制。
- 图鉴使用缩略图网格、hover 预览、双击详情、本页返回。
- 规则页解释当前规则；经济、情报、卡牌、怪兽、商品各自分层。

## 7. 自动门槛

运行：

```powershell
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/playtest_skeleton_gate_test.gd
```

该测试不是最终商业化验收，但它保护“能立骨架的地方都要有骨架”。

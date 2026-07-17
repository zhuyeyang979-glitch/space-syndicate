# 当前八席系统只读审计

## 结论

共享工作区当前没有可继承的“八个功能席位节点”。现役画面中的八席视觉事实，是 `PlanetGlobeBackdrop` 在星球桌环上固定绘制的八个金色圆弧标记。它们没有玩家映射、3–8 人显隐、本地玩家锚点、公开状态、tooltip 或输入区域。

因此，本批不能诚实地完成 `FULL_IN_PLACE_UPGRADE`。正式结论是 `SKIN_READY_INTEGRATION_DEFERRED`，并发结论是 `PARTIAL_ONLY_CONFLICTS_DETECTED`。本批只交付无布局权的 `PlayerSeatPortraitSkin`；独立 `PlayerSeatPortrait` 和 `PlanetSeatLayout` 明确属于 QA 预览，不得接入生产或被描述为正式八席系统。

## 实际场景链

- `GameScreen/SafeArea/MainRows/TableArea/PlanetBoard`
- `PlanetBoard/PlanetRows/PlanetStageViewport/MapHost/PlanetMapView`
- `PlanetMapView/BackdropLayer/PlanetGlobeBackdrop`
- `PlanetGlobeBackdrop._draw_table_ring()` 固定循环 `range(8)`，用公式绘制 8 个半径 8 像素的金色弧标记。

相关证据：

- `scripts/ui/map/planet_globe_backdrop.gd:64-82`：场景化现役桌环与八个装饰弧。
- `scripts/map_view.gd:36`、`888-918`：遗留 custom draw 仍有同类 `BETTING_TABLE_SEAT_COUNT=8` 装饰弧，但没有席位对象。
- `scenes/ui/PlanetMapView.tscn:38`：`PlanetGlobeBackdrop` 位于 `BackdropLayer`。
- `scripts/ui/planet_map_view.gd:26`：只持有 backdrop 引用；没有 seat root、seat view model 或 player binding。
- `scenes/ui/PlanetBoard.tscn:44-59`：中央星球宿主、MapHost 和 PlanetMapView。

## 哪些是布局、状态与视觉

- 现有“八席”的位置来源只是装饰公式，不是 3–8 人布局逻辑。
- 未找到现有席位状态逻辑或席位数据控制器。
- 未找到 seat index → player index 绑定。
- 未找到本地玩家固定底部的运行时合同。
- 未找到席位点击、hover、tooltip 或公开行动高亮。
- 可淘汰视觉只有八个装饰弧；它们目前与 PlanetGlobeBackdrop 的桌环绘制耦合。
- 不可破坏的功能逻辑是 PlanetMapView 的点击、拖动、缩放、区域映射和 PlanetStageViewport/MapHost 空间合同。Skin 不得接管这些职责。

## 为什么没有生成 before_3/4/6/8

所要求的 3、4、6、8 人席位基线不存在：当前八个弧在所有玩家人数下固定绘制，而且没有玩家身份。共享根及 C worktree 同时修改 PlanetMapView、PlayerBoard、GameScreen、viewmodel 和布局测试；在共享根启动 Godot 还会写入导入缓存，违反只读并发边界。故本批没有伪造四张“不同人数”截图。

现有共享运行截图可作为装饰桌环参考，但不能证明席位映射：

- `reports/ui/production_acceptance/e_minimal_clear_globe_1600x960.png`
- `reports/ui/production_acceptance/01_first_run_core_table_1280x720.png`

## 安全扩展点

`PlayerSeatPortraitSkin` 是纯视觉子组件，只接收公开字段。它不拥有：

- 玩家到席位的分配；
- 3–8 人布局；
- 位置、缩放、旋转或 z_index；
- 本地玩家决定；
- 点击、hover 或 tooltip；
- 手牌、现金、匿名真实出牌者或 AI 计划。

Skin 只在 manifest 存在真实预渲染 PNG 时显示。缺图时它隐藏自己，让未来宿主继续显示唯一的 legacy fallback，避免双重座位。

## 正式接入前置条件

未来宿主 owner 必须先提供稳定的八席根节点或同等 authoritative host、3–8 显隐、玩家映射、本地席位、公开 view model 和已有输入区域。届时最小接线应当是：

1. 在每个既有席位根内添加 `PortraitSkinHost`；
2. 实例化 `PlayerSeatPortraitSkin`；
3. 只传公开 view model；
4. Skin 可用时隐藏装饰 fallback，Skin 不可用时反向切换；
5. 保持 MapHost、PlanetMapView、中央星球直径和输入坐标不变。

不得把 `scripts/ui/planet_seat_layout.gd` 的 QA 算法接入生产，也不得围绕 PlanetBoard 创建第二圈席位。

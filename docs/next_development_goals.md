# 太空辛迪加后续开发目标

这份目标用于本次 UI 分层合入之后的下一阶段开发。核心原则：先让真人能舒服地玩完整局，再继续扩张玩法。不要把新功能继续堆进 `scripts/main.gd`；新玩家界面优先走 `scenes/ui/*`、`scripts/ui/*`、`scripts/viewmodels/*`。

## 总目标

把《太空辛迪加》从“功能已经很多的原型”推进到“人类测试者愿意连续试玩、能看懂局势、能和 AI 完整打一局”的商业化前桌游电子版原型。

主屏应该像赌桌：

- 中央是星球。
- 上方是短牌轨和公开时间线。
- 右侧是当前解释和操作原因。
- 底部是当前玩家资源与手牌。
- 复杂规则进入 Codex、规则页、经济总览和情报档案。
- AI 内部评分、压力桶、真实手牌、隐藏现金、私有弃牌不进玩家 UI。

## 下一阶段复制策略

下一阶段的开发方法改成“先抄标杆结构，再做本项目小修小改”。抄袭优先级按许可证和风险分三档：

1. `A 级｜可直接移植模式`
   - 参考：`pipeworks-studios/CardHouse`（CC0）、`mixandjam/Balatro-Feel`（MIT）、`ycarowr/UiCard`（MIT）、`chun92/card-framework`（MIT）、`twdoor/simple-cards-v-2`（MIT）、`cyanglaz/gcard_layout`（MIT）、`boardgameio/boardgame.io`（MIT）、`godotengine/godot-demo-projects`（MIT）、`Maaack/Godot-Menus-Template`（MIT）。
   - 可抄范围：组件边界、状态机形状、layout 参数、hover/drag/seeker 手感、菜单页拆分、加载/设置页组织。
   - 落地规则：必须改写成当前 Godot/GDScript 风格，不能直接混入 Unity/C#/JS 文件；引用来源写进 `docs/open_source_reference_notes.md` 或当前文件。

2. `B 级｜只抄产品结构`
   - 参考：`terraforming-mars/terraforming-mars`（GPL-3.0）、`vassalengine/vassal`（LGPL-2.1）、`db0/godot-card-game-framework`（AGPL-3.0）。
   - 可抄范围：主桌信息层级、玩家 tableau、牌轨/日志/地图/菜单分区、模块化桌面思想。
   - 禁止范围：不复制源码、素材、CSS、场景文件、具体文本和图标资源，除非项目明确接受对应许可证义务。

3. `C 级｜先确认再抄`
   - 参考：`boardgamers/gaia-project`、`GAIGResearch/TabletopGames`、本地/线上其它 deckbuilder、星球、巨兽、survivor 项目。
   - 可抄范围：在许可证确认前只做产品读法、流程拆解和截图对标；代码/资产不得粘贴进仓库。

## 下一阶段五个开发目标

### 目标 1｜主桌商业化读序二次收紧

参考标杆：

- `terraforming-mars/terraforming-mars`：中央地图 + 玩家资源 + 行动区 + 日志分离。
- `boardgamers/gaia-project`：资源/行动图标化和密集桌游 UI 的扫读。
- `VASSAL`：棋盘、token、日志、模块面板分层。

落地文件：

- `scenes/ui/GameScreen.tscn`
- `scenes/ui/TopBar.tscn`
- `scenes/ui/PlanetBoard.tscn`
- `scenes/ui/RightInspector.tscn`
- `scenes/ui/PlayerBoard.tscn`
- `scripts/viewmodels/table_snapshot.gd`

验收：

- 1280x720、1600x960、1920x1080 的 `play_table_*` 截图里，中央星球仍是最大视觉块。
- 主屏第一眼只出现：身份、现金/GDP/目标、选区、手牌、建城/牌架/买牌/出牌、短日志。
- `RightInspector` 不出现长规则段落；详情入口打开分节 Drawer。

### 目标 2｜手牌架照着成熟卡牌 UI 重做一轮手感

当前状态：

- 基础二版已落地：`HandLayout` 已按 `single_focus / comfortable / compressed / pressure` 分档处理 1 张、2-5 张、6-10 张、11+ 张手牌。
- 已有 hover 抬升/放大/置顶、邻牌让位、UI-only drop zone 元数据、拖拽预览元数据、MiniCard 速读和 RightInspector 详情路由。
- 后续继续用截图微调卡面尺寸、拥挤手牌的重叠节奏和 hover 动画曲线，不新增玩法。

参考标杆：

- `CardHouse`：card groups、drag gate、position/rotation/scale seeker。
- `Balatro-Feel`：hover 弹性、选择反馈、轻量结算手感。
- `UiCard`：hand pivot、hover lift、drop zone、卡牌间距参数。
- `card-framework`、`simple-cards-v-2`、`gcard_layout`：Godot Control 型卡牌/手牌组件边界。

落地文件：

- `scripts/HandLayout.gd`
- `scripts/ui/hand_rack.gd`
- `scripts/CardUI.gd`
- `scenes/ui/HandRack.tscn`
- `scenes/CardUI.tscn`

验收：

- 1-5 张手牌居中且可读，6-10 张压缩但不变成按钮列表。
- hover 放大/抬起/置顶不被 live refresh 打断。
- 拖拽预览只走 UI signal，不调用规则。
- MiniCard 只显示短读信息，完整规则仍在 Inspector/Drawer/Codex。

### 目标 3｜菜单/Codex 按 Godot 商业模板拆页面

参考标杆：

- `Maaack/Godot-Menus-Template`：主菜单、选项、暂停、credits、loading/scene flow。
- `godotengine/godot-demo-projects`：Godot 官方 scene 组织和 demo 项目结构。
- `boardgame.io`：规则/阶段/log/replay 与 view 层解耦。

落地文件：

- `scenes/ui/MenuOverlay.tscn`
- `scenes/ui/MenuRootLobby.tscn`
- `scenes/ui/CardCodexBrowser.tscn`
- `scenes/ui/CardCodexDetail.tscn`
- `scenes/ui/CompendiumHubBoard.tscn`
- `scripts/main.gd` 中残留菜单/Codex controller 桥接函数

验收：

- 根菜单只显示开局、继续、资料库、规则、读档/设置/退出等入口，不显示开发说明。
- Codex 缩略图页只负责浏览，详情页才负责完整读法。
- 子页面不继承无关全局导航，返回/上一页/下一页是本地控件。

### 目标 4｜把 Theme/样式从脚本里继续抽出来

参考标杆：

- Godot 官方 Theme / GUI Skinning / Container 文档。
- `Maaack` 模板的菜单和按钮层级。
- `godot-demo-projects` 的项目组织。

落地文件：

- `themes/` 或现有主题资源。
- `scenes/ui/*.tscn`
- `scripts/ui/*` 中重复出现的颜色、边框、字号、margin。

验收：

- 新增 UI 不再在 `scripts/main.gd` 里散落大量 `Color("#...")`、font size、margin 常量。
- 常见按钮、chip、panel、card frame 至少有一套可复用样式入口。
- 1280x720 下按钮文字不溢出，卡片/抽屉/菜单不出现嵌套卡片堆叠感。

### 目标 5｜把“参考标杆 → 截图验收”固定进测试

参考标杆：

- Godot 官方多分辨率 UI/container 约束。
- 当前 `tests/ui_snapshot_capture.gd`、`tests/layout_scene_smoke_test.gd`、`tests/visual_snapshot.gd`。

落地文件：

- `tests/ui_snapshot_capture.gd`
- `tests/layout_scene_smoke_test.gd`
- `tests/visual_snapshot.gd`
- `docs/open_source_reference_notes.md`

验收：

- 每次 UI 大改都生成 `main_menu_*`、`play_table_*`、`play_table_drawer_*` 三档以上截图。
- 测试明确卡住“主屏没有长规则说明 / 复杂信息只能进 Inspector、Drawer、Codex / hand hover 不被刷新打断”。
- 新增复制来源时必须写清许可证档位和可抄范围。

## 阶段 1：真实运行 UI 迁移

目标：让正在运行的 `scenes/main.tscn` 不再主要依赖 `scripts/main.gd` 动态生成 UI。

优先级：

1. 把运行时底部玩家板迁入 `scenes/ui/PlayerBoard.tscn`。
   - `main.gd` 只生成 `PlayerBoardSnapshot`。
   - `PlayerBoard.gd` 只负责渲染现金、GDP、目标、手牌、主行动。
   - 手牌 hover、抬起、选中、双击详情都由 `HandRack.gd` 和 `CardFace.gd` 处理。

2. 把右侧详情迁入 `scenes/ui/RightInspector.tscn`。
   - 选区、卡牌、怪兽、军队、合约、赌局都走同一个右侧解释入口。
   - 主屏只放一句原因；更详细的解释放 tooltip/detail。

3. 把匿名牌轨迁入 `scenes/ui/CardTrack.tscn`。
   - 默认保持 Through the Ages 式薄轨。
   - hover 预览卡牌。
   - 双击打开详情/竞猜。
   - 公共事件和匿名卡牌在同一时间轴，但用光晕区分能否竞猜。

4. 把全屏/侧边 Overlay 统一迁入 `scenes/ui/OverlayLayer.tscn`。
   - 弃牌、怪兽赌局、目标选择、相位否决窗口都复用一个临时决策底座；条件订单不创建回应窗口。
   - 不再让多个弹窗遮住地图主体。

验收：

- `main.gd` 不再新增大型 UI 构造函数。
- 新 UI 组件可以在 Godot Editor 中单独打开、调整、预览。
- 1280×720、1600×960、1920×1080 主桌截图中核心按钮不出屏。
- hover 手牌不会被周期刷新打断。

## 阶段 2：卡牌阅读体验

目标：让玩家像读 TCG 卡一样扫读，而不是读长规则报告。

优先级：

1. 定义三种卡牌视觉规格：
   - `MiniCard`：手牌/牌轨，显示名称、等级、类型、费用、状态灯、一句效果。
   - `FullCard`：右侧详情，显示卡面、目标、费用、门槛、效果和主操作。
   - `CodexCard`：图鉴详情，显示 I-IV 梯度、策略用途、反制线索、关联商品/区域。

2. 简化卡牌文本。
   - 玩家卡面只写“这张牌做什么”。
   - 不写开发原则、不写废弃规则、不写内部预算。
   - 复杂门槛用芯片表达，例如“目标玩家”“需选区”“需商品流动”“一次性”“固定技能”。

3. 强化手牌手感。
   - 1 张居中，2-5 张横向居中，6-10 张轻微扇形压缩。
   - hover 抬起 50-70px，放大约 1.15，置顶。
   - 双击卡牌打开详情或进入目标选择。

4. 改进区域牌架。
   - 双击任意区域都能看该区牌池。
   - 可买/仅看/需弃牌清楚区分。
   - 打开牌架瞬间锁定购买资格和价格。
   - 同时只允许一个区域牌架窗口。

验收：

- 新玩家能在 10 秒内看懂手牌里哪张能打、为什么不能打。
- 卡牌图鉴缩略图页不再像文字列表。
- 卡牌详情页常驻文字减少，规则解释转入 hover/detail。

## 阶段 3：主菜单与 Codex 产品化

目标：主菜单像桌游电子版入口，不像功能清单。

优先级：

1. 主菜单只保留：
   - 开始新局。
   - 继续游戏。
   - 图鉴/Codex。
   - 规则。
   - 设置。

2. 新局设置页独立处理：
   - 玩家数 3-8。
   - AI 数 2-7。
   - 玩家角色选择。
   - AI 随机角色。
   - 起始怪兽选择。
   - 保证一局内角色不重复。

3. Codex 分层：
   - 卡牌图鉴：所有卡牌，包括怪兽牌。
   - 怪兽生态：怪兽作为场上单位的行动概率、资源偏好、移动生态。
   - 商品图鉴：商品特点、地形来源、策略用途、相关卡。
   - 区域图鉴：区域生产/需求/商路/牌架。
   - 角色图鉴：公开角色能力和策略路线。

4. 翻页/hover/详情稳定。
   - 缩略图页保留滚动位置。
   - hover 不导致页面跳到底部。
   - 详情页才显示上一页/下一页。

验收：

- 主菜单不出现开发历史和冗余说明。
- 子页面只出现该页面需要的导航。
- Codex 页面能帮助玩家建立策略认知，而不是展示数据库。

## 阶段 4：完整试玩节奏

目标：真人玩家可以不读长规则，完成开局到终局。

优先级：

1. 开局 1 分钟轻引导：
   - 先召怪兽。
   - 选区。
   - 建城。
   - 看牌架。
   - 买牌。
   - 打牌。

2. 主屏提示只保留下一步。
   - “先召唤怪兽，才能买牌。”
   - “建城市赚钱，摧毁别人城市让他们少赚钱。”
   - “打牌匿名，但条件和结果会暴露线索。”
   - “最后按钱最多获胜。”

3. 终局总结：
   - 谁赢了。
   - 钱主要从哪里来。
   - 哪些城市贡献最大。
   - 哪些卡牌/怪兽/赌局影响最大。
   - AI 大致路线只展示公开可推断信息，不展示内部评分。

验收：

- 测试者可以完成一局而不问“下一步去哪点”。
- 结束后能看懂为什么赢/输。
- AI 对手能稳定完成首召、建城、买牌、出牌、干扰和防守。

## 阶段 5：表现与性能

目标：让星球缩放、卡牌 hover、怪兽移动、城市破坏不再卡顿。

优先级：

1. 用 Profiler 找 UI/地图/VFX 卡顿源。
2. 高频临时对象池化：
   - 伤害数字。
   - 城市破坏特效。
   - 卡牌飞行动画。
   - 筹码转移。
   - 怪兽行动 callout。
3. 星球缩放做平滑过渡。
   - 近景是局部平面投影。
   - 远景逐步过渡为球体。
   - 不要瞬间切换。
4. 预热常见卡牌/怪兽/天气特效。
5. 多分辨率有头截图保留为常规验收。

验收：

- 1280×720 到 2560×1440 都能稳定看清主桌。
- 星球缩放没有明显首次卡顿。
- 卡牌 hover 不掉帧、不跳位。
- 怪兽移动按米/秒线性演出，不退回格子跳跃。

## 阶段 6：策略深度与平衡

目标：在 UI 可玩之后，再继续扩展策略，而不是反过来。

优先级：

1. 保证 AI 至少有 4-5 条可追胜路线：
   - 城市 GDP 增长。
   - 商品/商路经营。
   - 金融做多/做空。
   - 怪兽破坏与诱导。
   - 情报推理与归属竞猜。
   - 合约博弈。
   - 军队防守/打击。

2. 卡牌强度梯度：
   - I：启动和基础工具。
   - II：效率提升或范围扩大。
   - III：路线核心。
   - IV：终端，但必须有线索和反制。

3. 商品池深度：
   - 商品来自当前星球地形。
   - 有商品才生成相关卡。
   - 海洋也能生产商品，例如海雾果、潮汐电、深海油、藻晶。
   - 商品价格由供需、运输速度、路线损伤、合约和天气影响。

4. 怪兽差异：
   - 飞行怪兽移动快、不践踏普通路径。
   - 水栖怪兽海域快、陆地慢。
   - 资源吸取型怪兽会被特定商品吸引。
   - 战斗型怪兽更容易参与怪兽赌局。

5. 怪兽赌局：
   - 底注按玩家现金百分比。
   - 金额公开，身份公开下注。
   - 赢家平分赌池，作为逆风翻盘点。
   - 时间冻结，30 秒内决策，可提前结束。

验收：

- 每条路线都有赚钱方式、风险、线索和反制。
- AI 不会只走单一路线。
- 人类能从地图和牌轨读出“谁可能在做什么”。

## 阶段 7：发布前整理

目标：让项目更容易交给下一位 Codex 或人类开发者。

优先级：

1. 保持 `AGENTS.md` 是最高协作入口。
2. 保持 `REFERENCE_LINKS.md` 和 `docs/reference_ui_notes.md` 更新。
3. 每次大改都更新开发日志。
4. 新规则必须有玩家文本、数据字段、AI 可读字段和测试。
5. 不把 debug/AI 内部解释塞进主 UI。
6. 每次合入 main 前至少跑：
   - `tests/layout_scene_smoke_test.gd`
   - `tests/ui_text_smoke_test.gd`
   - `tests/visual_snapshot.gd`
   - `tests/smoke_test.gd --check-only`
   - 关键玩法改动时跑完整 `tests/smoke_test.gd`

## 下一次最推荐的具体任务

下一个 Codex 任务建议只做一件事：

> 以 `CardHouse + Balatro-Feel + UiCard + simple-cards-v-2` 为标杆，把当前 `HandRack` 做成第二版商业卡牌手感：稳定压缩布局、hover 抬升/弹性、拖拽预览、MiniCard 扫读、右侧详情联动，保持不新增玩法。

验收方式：

- 跑 `tests/layout_scene_smoke_test.gd`，确认同 ID 手牌刷新不重建、不打断 hover。
- 跑 `tests/visual_snapshot.gd`，确认 MiniCard/HandRack/Drawer 合同仍然存在。
- 用可见渲染器跑 `tests/ui_snapshot_capture.gd`，目检 `play_table_1280x720.png`、`play_table_1600x960.png`、`play_table_1920x1080.png`。
- 更新 `docs/open_source_reference_notes.md`，记录这轮实际抄了哪些 MIT/CC0 模式。

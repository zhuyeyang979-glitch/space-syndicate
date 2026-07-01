# 太空辛迪加开发日志

> 本日志用于保存当前原型的规则决策、实现状态、验证方式和下一步开发方向。
> 最新记录日期：2026-07-01。

## 2026-07-01｜起始怪兽手牌改成首召专用文案

### 本轮实现

- 起始怪兽牌不再在手牌区显示普通“可打出/打出”读法。
- `starter_play_free` 牌现在有专用手牌状态：
  - 未选落点：`选落点`
  - 落点不可用：`换落点`
  - 落点可用：`首召就绪`
- 起始怪兽牌按钮改为 `首召`，状态筹码显示 `免流动` 和当前 `落点`。
- 手牌架左侧操作提示从 `点打出` 改成 `首召/出牌`，明确首召牌和普通牌属于同一手牌架但不同开局动作。
- 更新测试护栏：
  - smoke test 接受开局手牌状态 `首召就绪`；
  - UI 文本测试检查 `首召就绪`、`首召/出牌`、`免流动` 等玩家可读锚点。

### 设计意图

- 新手第一分钟只需要理解一件事：先选区域，再把起始怪兽首召到那里。
- 如果起始怪兽牌仍写成普通“打出”，会和右侧 `在选区首召` 按钮形成两个心理入口。
- 这次把它改成桌游式“开局部署牌”读法，减少误操作感。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - 有头 UI 快照采集 `tests/ui_snapshot_capture.gd`
- 有头复查快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜顶部数字时间改成牌桌沙漏条

### 本轮实现

- 将主牌桌顶栏原来的 `◷ 00:00` 数字时间筹码替换为 `HeaderStatusMeterChip`：
  - 左侧显示短状态，例如 `⌛ 天气…`、`⌛ 展示`、`⌛ 竞价`；
  - 右侧显示小型 `HeaderStatusMeterBar`；
  - 不再在顶栏常驻显示具体秒数。
- 顶部节奏条现在复用底部全桌窗口状态：
  - 怪兽赌局、匿名竞价、同时出牌、相位响应、公开展示、合约回应、终局沙漏、天气预报/影响都会显示对应条；
  - 没有全桌窗口时，只显示低调脉冲条，不制造额外数字负担。
- 更新 UI 护栏：
  - `tests/visual_snapshot.gd` 检查顶栏使用 `HeaderStatusMeterBar`，且不再回到 `◷ 00:00`；
  - `tests/ui_text_smoke_test.gd` 同步检查沙漏条契约。

### 设计意图

- 试玩桌面应像赌桌/电子桌游：重要倒计时用条状沙漏表达，玩家不用反复读数字时间。
- 顶栏只负责提示“现在桌面是什么状态”；真正的全桌倒计时继续交给屏幕底部 `BottomCountdownPanel`。
- 这一步继续减少主游戏画面的常驻文字，让中央星球、手牌和行动托盘更突出。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - 有头 UI 快照采集 `tests/ui_snapshot_capture.gd`
- 有头复查快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜卡牌详情页压缩重复文案并修正梯度卡排版

### 本轮实现

- 卡牌详情页顶部改成短速读：
  - `卡牌详情｜第N/M张｜牌名`
  - `类型｜路线｜价格｜是否指定怪兽`
  - 最后一行优先显示关键事实，例如怪兽牌的生命、在场时间、召唤区域。
- 详情页右侧仍保留桌游/TCG式四块结构，但每块减少重复：
  - `牌面定位` 只讲这张牌适合做什么；
  - `费用与门槛` 只放购买价、打出条件和目标；
  - `核心效果` 只出现一次简短效果；
  - `关键数值` 改成一行筹码式事实。
- 卡面正文同步收短：
  - 普通卡面优先展示关键数值/路线；
  - 长规则留给 hover、图鉴详情和后续完整规则页。
- `I→IV 强化` 梯度卡修复了窄列换行问题：
  - 罗马等级不再被拆成竖排；
  - 价格不再被挤成竖排；
  - 四张等级卡第一屏可读。
- 顺手修正情报档案的私密标注摘要：
  - `置信分布`、`理由分布` 自身带可扫读标签；
  - 不再依赖某座城市是否挤进前四个调查优先级列表。

### 设计意图

- 玩家读卡时先看“这张牌怎么用”，不要在多个位置反复读同一段效果文字。
- 参考 Terraforming Mars / 电子桌游的读法：短卡面负责识别和操作，详细规则通过 hover、详情页和规则页承接。
- 图鉴详情页应像 TCG 卡牌说明板，而不是开发规则备忘录。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - 有头 UI 快照采集 `tests/ui_snapshot_capture.gd`
- 有头复查快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/03_card_codex_detail.png`
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜地图区域牌架从长列表改成主板短徽章

### 本轮实现

- 将选中区域地图上的 `区域可提供卡片` 黑色长列表移除。
- 地图主板现在只显示短徽章：
  - `牌架 N`
  - `双击区域看牌`
- 完整区域卡名、价格、购买资格和预览继续放在右侧 `区域牌架` 抽屉里。
- 补充视觉护栏：
  - `tests/visual_snapshot.gd` 检查地图源码不再包含 `区域可提供卡片`；
  - 选中区域必须保留短 `牌架 %d` 与 `双击区域看牌` 提示。

### 设计意图

- 参考 Terraforming Mars 的主板读法：地图格子只放图标/短标签，详细牌面和操作进侧栏或卡牌区。
- 中央星球是主视野，不能被区域卡名列表遮住；玩家只需要知道“这里有牌架，可以双击查看”。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - 有头 UI 快照采集 `tests/ui_snapshot_capture.gd`
- 有头复查快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜手牌架改成首屏完整 mini-card

### 本轮实现

- 参考 Terraforming Mars 电子桌游的手牌读法，把底部手牌从“标题在上、卡牌在下”改成：
  - 左侧 `PlayerHandRackInfoRail`：手牌数、整体状态、悬停详情、点打出；
  - 右侧横向 mini-card 架：卡牌从手牌框顶部开始排，首屏能看到完整卡体。
- 普通手牌 mini-card 压缩：
  - 卡体从 `160×168` 改成 `148×148`；
  - 卡面小图从 `42px` 改成 `34px`；
  - 常驻只保留标题、类型、少量筹码、状态灯和出牌按钮；
  - 长效果和详细打出条件继续放进 hover / 图鉴详情。
- 空手牌槽同步改成 `148×148`，保证真实手牌和空槽像同一排桌游卡架。

### 设计意图

- 真人初测最重要的是“我有哪些牌、哪张能打、按钮在哪里”一眼可见。
- 规则文字不应挤占手牌卡体；电子桌游中小卡先用于识别与操作，详情通过 hover/放大/图鉴进入。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - 有头 UI 快照采集 `tests/ui_snapshot_capture.gd`
- 有头复查快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜底部玩家板改成资源筹码 + 手牌 + 行动托盘首屏

### 本轮实现

- 主牌桌底部从单纯“桌边牌架”调整为 `玩家板｜桌边牌架`：
  - 首屏顶部是 `PlayerDashboardTopRail`，只放薄资源筹码条和公开席位条；
  - 手牌和行动托盘继续左右并排，手牌保持在行动托盘之前；
  - 完整身份玩家板下沉到滚动区后面，避免一进局就把手牌挤出屏幕。
- 资源筹码条前置：
  - 资金、GDP、城市、手牌、终局目标等用 Terraforming-Mars 式短筹码呈现；
  - 对手资金、手牌和真实资产仍保持隐私，只显示可推理线索。
- 右侧行动托盘收窄收矮：
  - `目标提示｜下一步` 放到行动托盘顶部；
  - 首召、选区、开局引导、竞价、竞猜、合约等仍收在同一托盘里；
  - 托盘内部滚动，不遮中央星球和手牌。
- 有头快照复查后修正了一次错误方向：
  - 完整身份玩家板放在顶部时太高，导致手牌首屏不可见；
  - 改为顶部只保留薄资源/席位条，完整身份板下沉。

### 设计意图

- 参考 Terraforming Mars 的“玩家资源板 + 手牌架”读法：玩家第一眼先扫钱、产能/现金流、目标进度和手牌，不读长规则。
- 中央星球继续作为赌桌主体；底部只是桌边玩家板，复杂信息通过滚动、hover 和详情进入。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - 有头 UI 快照采集 `tests/ui_snapshot_capture.gd`
- 有头复查快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜顶部牌轨压薄与手牌小卡面收口

### 本轮实现

- 顶部匿名出牌轨道进一步压成桌边公共牌列：
  - 牌轨面板高度从大面板降到 `36px`，单槽高度降到 `22px`；
  - 左侧只保留 `牌轨 / 拖看｜悬停`，把说明放入 hover；
  - 小牌按钮直接显示状态、牌类、报价和公开归属短标签，例如 `¥200/玩家3`；
  - 完整归属、竞价、小费线索、打出条件和双击图鉴入口继续保留在 tooltip。
- 修复压缩牌轨后的公开归属可见性：
  - `归属：玩家X` 在小牌上先去掉前缀再缩写，避免被压成 `归属…`；
  - 猜中牌主后，顶部轨道仍能常驻看到 `玩家X`。
- 手牌紧凑卡面增加 42px 小画布专用绘制：
  - 小画布只画标题和类型短标签；
  - HP、持续时间、路线等长属性不再硬塞进小卡图；
  - 完整规则继续走 hover、按钮 tooltip 和图鉴详情。

### 设计意图

- 主牌桌继续朝“中央星球 + 赌桌边缘信息”的方向收口：顶部牌轨是公共记忆，不应抢走地图；底部手牌是玩家操作入口，不应变成文字墙。
- 电子桌游里玩家先扫卡位、颜色、短标签和状态，再决定是否打开详情；这轮把牌轨和手牌小卡都往这个读法靠拢。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - Godot 有头启动 `--quit-after 180`
  - 有头 UI 快照采集 `tests/ui_snapshot_capture.gd`
- 有头复查快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`
- 最新完整 smoke 已跑到结束并通过；旧条目中提到的临时 smoke 失败不再代表当前状态。

## 2026-07-01｜菜单、经济与图鉴补成玩家可扫读桌游面板

### 本轮实现

- 主菜单增加三张前置短卡：
  - `主菜单速览`：说明开局、继续、规则、经济、情报和图鉴入口；
  - `牌桌布局`：强调中央星球、顶部匿名牌轨、底部手牌架；
  - `终局复盘`：说明现金目标、倒计时和赛后看钱从哪里来。
- 主菜单交互提示统一为“缩略图 / 悬停预览 / 双击详情”，让菜单、图鉴和牌轨读法一致。
- 局势排名正文和速览卡补齐：
  - `预估结算资金`；
  - `公开异动`；
  - 对手现金、手牌和私密推理隐藏；
  - 情报待结算；
  - 当前玩家存活城市清算。
- 经济总览从概念说明补成可用证据板：
  - 商品热榜、低价/供给压制、商路收入前景；
  - 经济天气、最近卡牌余波、城市公开线索、怪兽资金线索；
  - 当前玩家推理板：城市私标、公开卡牌归属、卡牌条件反推、公开怪兽归属；
  - 直接列出最近余波/竞价小费/条件门槛，帮助玩家从匿名牌反推身份。
- 情报档案正文补齐：
  - 情报换钱、城市业主情报、卡牌归属档案、怪兽资金档案；
  - 调查优先级；
  - 置信分布、理由分布和当前标注明细。
- 图鉴文字进一步桌游化：
  - 图鉴入口明确 `角色图鉴｜怪兽生态档案｜卡牌图鉴｜商品图鉴｜区域图鉴`；
  - 角色页改成 `角色卡 / 特征 / 被动 / 首召怪兽独立选择`；
  - 怪兽页增加正面经济天气与 IV 级权重修正；
  - 商品页分成 `商品卡 / 市场面板 / 策略面板 / 金融与天气 / 生态与卡牌`；
  - 区域页补区域可提供卡牌、隐藏业主、流通加速、收入拆解、生产明细和 GDP 趋势。
- 牌轨小回归修复：
  - 猜中牌主后，顶部牌轨常驻短筹码直接显示 `玩家X`，完整公开归属标签仍保留在 hover；
  - 卡牌图鉴 hover 中的路线改为 `路线：城市成长` 这种无图标直读格式。

### 验证

- 通过：
  - Godot `--check-only`
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `git diff --check`（仅已有 LF/CRLF 提醒）
- 完整 `tests/smoke_test.gd` 已重新跑到结束，菜单/图鉴/牌轨/经济证据相关检查已转绿。
- 仍剩 10 个左右完整 smoke 失败，下一轮优先排查：
  - 现金目标触发终局倒计时保存；
  - 仓储期货随存储城市毁灭清除；
  - 8席7AI完整局 `missing final summary` 与恢复状态；
  - 主桌在该恢复状态后的少量可见标签；
  - 区域市场卡行购买状态；
  - 合约牌展示后独立5秒签约窗口；
  - 情报置信/理由补丁后需要完整 smoke 复验。

## 2026-07-01｜出牌轨道补齐《历史巨轮》式可扫读牌列状态

### 本轮实现

- 顶部出牌轨道继续按电子桌游公共牌列处理：
  - 每张小牌直接显示轨道状态，例如 `竞拍1`、`锁定1`、`当前展示`、`下批等待1`；
  - 轨道牌常驻只保留报价、匿名/公开归属和 1-2 个关键短筹码；
  - 出牌条件、演出风格、地图播报、余波线索和完整标记统一收进 hover，避免顶部牌轨变成文字墙；
  - hover 文案明确区分“单击竞猜归属”和“双击打开卡牌图鉴”。
- 牌轨宽度同步现在在每次刷新后执行；当历史/候补牌超过 12 格固定视野时，横向拖拽与滚轮回看有稳定滚动范围。
- 猜中卡牌归属后，牌轨会用公开归属筹码持续标出玩家名，完整归属标签保留在 hover 中。
- 修复 Godot 4 严格解析问题：
  - 避免用 `signal` 作为局部变量名；
  - 为地图投影与菜单状态中的 Variant 推断补显式类型；
  - 增加 `_format_seconds()` 用于终局倒计时短显示。

### 设计意图

- 《历史巨轮》式牌列的重点是“每张牌先读位置和状态，再决定是否看详情”，所以出牌轨道不再只是一串历史记录，而是实时牌桌信息层。
- 玩家应能从顶部一眼判断：哪张牌在展示、哪张在竞价、哪张已锁定、哪张进入下批，以及哪张已经被公开归属。
- 轨道保持低高度，复杂解释继续收进 hover 与双击详情，避免抢走中央星球和手牌区域的视觉重心。

### 验证

- `tests/smoke_test.gd` 中所有出牌轨道相关检查已通过，包括：
  - 当前玩家候补牌与最高公开报价；
  - compact hover/detail；
  - 当前展示与锁定下一张；
  - 下批等待牌；
  - 横向拖拽/滚轮滚动；
  - 猜中归属后的公开标签。
- 轻量验证通过：Godot `--check-only`、`tests/ui_text_smoke_test.gd`、`tests/visual_snapshot.gd`。
- 完整 smoke 已能跑完，但仍有菜单、经济总览、图鉴文本与少量经济结算失败，留给下一轮集中处理。

## 2026-07-01｜合约回应改成桌边合同条款卡

### 本轮实现

- 合约签/拒窗口继续使用统一 `TemporaryDecisionCard`，但新增合约专属的 `ContractOfferTermsBoard`：
  - `ContractOfferDecisionTimerBar` 显示独立签约窗口剩余时间；
  - `ContractOfferTermRail` 用短灯条展示供给区、需求区、商品、签约收益、拒签代价和匿名身份；
  - 每个条款使用 `ContractOfferTermLamp`、`ContractOfferTermSignal` 和 `ContractOfferTermLabel`，玩家不用先读长段文字。
- `_add_pending_contract_offer_panel()` 现在把原始合约 offer 传入临时决策面板，合约 UI 从同一份数据生成条款。
- 原有规则不变：公开展示结束后，目标城市真实业主获得独立 5 秒签/拒窗口；倒计时结束按拒签；窗口不阻塞其他玩家出牌。

### 设计意图

- 合约是桌游感很强的交互，不应该表现成普通弹窗说明，而应该像桌边翻出的短合同卡。
- 目标玩家扫一眼就应知道：这份合约连接哪里、影响哪个商品、签了赚什么、不签亏什么。
- 这一步继续把主游戏界面从“读说明”推向“看牌面、看筹码、看条款、做决定”。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的临时决策护栏，覆盖合同条款板、签约倒计时条和条款灯。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜出牌轨道继续参考《历史巨轮》式公共牌列

### 本轮实现

- 顶部 `CardResolutionTtaMarketPanel` 从 54px 继续压到 48px，减少对中央星球和底部手牌架的挤压。
- 固定牌槽从 10 格扩到 12 格，同时把单格宽度、高度收窄：
  - 历史/当前/竞价/候补仍用颜色与符号分区；
  - 真牌只保留图标、短牌名、罗马等级、小费/归属筹码；
  - 详细效果改到 hover tooltip，双击打开卡牌详情。
- 新增 `CardResolutionTtaScrollShell` 与左右 `CardResolutionTtaScrollCue`，让牌轨读起来更像电子桌游里可以横向拖看的公共牌列。
- 新增 `CARD_TRACK_MANUAL_SCROLL_HOLD_MSEC`、`_mark_card_resolution_track_manual_scroll()` 与 `_maybe_follow_card_resolution_track()`：
  - 玩家拖动/滚轮回看时，短时间内不自动抢回焦点；
  - 玩家不操作时，牌轨会跟随最新的当前/候补牌。

### 设计意图

- 出牌轨道不是聊天记录，也不是战斗日志，而是桌面上所有人共同看的公共牌列。
- 参考《历史巨轮》电子版的核心不是照搬外观，而是学习它的扫视逻辑：先看位置、颜色、费用/报价和归属标记，再决定是否 hover 或打开详情。
- 这一步继续保护主画面重心：星球在中央，牌轨在桌边，手牌在底部。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的牌轨护栏，覆盖 12 格固定牌槽、拖看外壳、手动回看保护和自动跟随最新牌。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜区域牌架预览增加购买判定灯条

### 本轮实现

- `DistrictSupplySelectedPreview` 新增 `DistrictSupplyPurchaseVerdictRail`：
  - 显示当前卡牌购买状态；
  - 显示锁定价格；
  - 显示当前玩家普通手牌数量；
  - 满手换购时显示 `私密弃牌`；
  - 显示购买范围来源，例如怪兽脚下、相邻、远程补给或全局采购；
  - 显示 `资格锁定`，提醒购买资格按打开窗口瞬间判定。
- 每个判定灯使用 `DistrictSupplyPurchaseVerdictSignal` 和 `DistrictSupplyPurchaseVerdictLabel`，避免把购买结论藏在按钮 tooltip 里。
- 原有市场格、右侧卡面预览和购买按钮保留。

### 设计意图

- 区域牌架是玩家从地图进入构筑的高频入口，购买结论必须比规则说明更先被看见。
- 玩家应该一眼知道“可买/仅浏览/需弃牌/价格/手牌压力/范围来源”，再决定是否点击购买。
- 这一步不改变购牌规则，只把查看、资格锁定、手牌上限和私密弃牌做成桌游市场板的可扫读信息。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的区域牌架购买判定灯护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜顶部状态条增加桌面节奏筹码

### 本轮实现

- `HeaderStatusChipRail` 新增 `tempo` 筹码，默认显示 `◆ 空闲`。
- 新增 `_table_tempo_status()`，按优先级显示当前最需要注意的全桌状态：
  - 怪兽赌局冻结；
  - 匿名牌竞价；
  - 相位响应；
  - 匿名牌展示；
  - 终局倒计时；
  - 候补队列；
  - 天气预报或活跃天气；
  - 空闲。
- `_refresh_status()` 每次刷新顶部状态时同步更新桌面节奏文字和 tooltip。

### 设计意图

- 电子桌游的顶部状态栏应该告诉玩家“现在桌面处于什么节奏”，而不是让玩家分别去找牌轨、赌局、天气和终局信息。
- 桌面节奏筹码只汇总已有公开状态，不暴露隐藏经济、AI路线或匿名出牌者。
- 这一步让测试者更容易判断什么时候能自由操作、什么时候要看竞价/下注/响应窗口。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的顶部节奏筹码护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜选区地块板增加行动状态灯

### 本轮实现

- `SelectedDistrictBoard` 新增 `SelectedDistrictActionLampRail`：
  - `建城` 显示可建/不可；
  - `牌架` 显示可买/可看/空；
  - `首召` 显示可落/已召/待选；
  - `商路` 显示当前商路商品或未开；
  - 陌生城市额外显示 `标注:可猜`。
- 每个状态灯使用 `SelectedDistrictActionLampSignal` 和 `SelectedDistrictActionLampLabel`，把可执行性压成短状态，而不是塞进按钮 tooltip。
- 原有 `SelectedDistrictActionGrid` 按钮不变，仍负责城市化、打开牌架、标注、商路和全屏地图。

### 设计意图

- 玩家点选中央星球上的区域后，应该先扫“这个地块能做什么”，再决定按哪个按钮。
- 状态灯把选区读法做成桌游地块板：地形/城市/商品筹码 → 行动灯 → 动作按钮。
- 这一步不改变规则，只减少试玩时对 tooltip 和长说明的依赖。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的选区行动灯护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜紧凑手牌卡面压缩状态文字

### 本轮实现

- 紧凑手牌中的 `HandCardPlayStatePanel` 只保留最多 2 个状态筹码：
  - 可打/需目标/缺商品等第一眼状态交给 `HandCardPlayLamp`；
  - 商品门槛等补充条件保留在筹码；
  - 详细原因不再常驻显示，改放在 tooltip。
- 紧凑手牌美术高度从 62px 收到 50px，按钮高度从 26px 收到 24px。
- 非紧凑卡面仍保留 `HandCardPlayReason`，用于图鉴/预览等空间更大的页面。

### 设计意图

- 手牌牌架是主桌高频区域，不能因为状态灯和旧说明区叠加而重新变成密集文字块。
- 玩家常态读法应是：卡名/等级 → 状态灯 → 成本/门槛筹码 → 按钮；完整解释只在 hover 或详情页出现。
- 这一步继续把主画面向电子桌游桌边牌架收口，保护中央星球和手牌可见性。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的紧凑手牌护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜开局轻引导下一步卡增加主行动按钮

### 本轮实现

- `OpeningGuideNextStepCard` 新增 `OpeningGuidePrimaryActionRail` 与 `OpeningGuidePrimaryActionButton`：
  - 首召阶段直接显示“在选区首召”；
  - 建城阶段显示“城市化”；
  - 买牌阶段显示“打开牌架”；
  - 出牌阶段显示“打出手牌/打出某牌”；
  - 经济阶段显示“经济总览”。
- 新增 `_opening_guide_primary_action()`，只复用已有动作入口：
  - `_use_skill()`；
  - `_build_city_in_selected_district()`；
  - `_open_district_supply_from_map()`；
  - `_open_economy_overview_menu()`。
- 下一步卡继续保留入口筹码，并新增“按钮:xxx”筹码，让玩家能扫读当前建议动作。

### 设计意图

- 轻引导不应只是文字提示；电子桌游的新手前几步应该像任务卡，告诉玩家下一步并给一个可按按钮。
- 这一步让测试者更容易从开局进入首召、城市化、购牌、匿名出牌和经济阅读的闭环。
- 规则没有改变：按钮只是已有操作入口，不能绕过区域、现金、商品流动、目标选择或队列限制。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的开局轻引导主行动按钮护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜手牌卡面增加可打状态灯

### 本轮实现

- 手牌卡面新增 `HandCardPlayLamp`：
  - `HandCardPlayLampSignal` 用色条显示当前状态；
  - `HandCardPlayLampStatus` 显示可打、需目标、缺商品、冷却、排队等短状态；
  - `HandCardPlayLampAction` 显示按钮会执行的动作，例如打出、释放、选目标或相位否决。
- 原有 `CardFaceChipRail` 与 `HandCardPlayStateRail` 保留：
  - 费用、等级、商品门槛、目标类型、一次/固定仍用筹码扫读；
  - 详细原因仍放在状态区 tooltip 与短原因行里。

### 设计意图

- 手牌是玩家最常看的区域，测试者不应该先读一段效果文字才能知道“这张牌现在能不能用”。
- 状态灯把出牌可用性提到卡面中层：先看灯，再看筹码，最后才看效果说明。
- 这一步不改变规则，只让人类玩家更容易完成首召、购牌、出牌、目标选择和相位响应。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的手牌状态灯护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜怪兽赌局增加公开下注板

### 本轮实现

- `TemporaryDecisionCard` 内的怪兽赌局模块新增 `MonsterWagerPublicBetBoard`：
  - 每个玩家显示一个 `MonsterWagerPublicBetCard`；
  - 已下注玩家显示玩家筹码、支持对象和下注金额；
  - 未下注玩家显示待押底注；
  - 强制下注会标记为底注；
  - 顶部显示已下注人数 / 总人数。
- 原有奖池、底注、剩余时间、全场冻结、各怪兽伤害与押注总额继续保留。

### 设计意图

- 怪兽赌局是本游戏最有赌博桌氛围的公开时刻，玩家应该一眼看到“谁押了谁、押了多少、还有谁没押”。
- 下注公开本身也是推理线索，但 UI 不能泄露 AI 内部路线或隐藏策略，只展示规则上已经公开的身份、方向和金额。
- 这一步把怪兽赌局从说明文字推进成桌面筹码区，后续可继续加入赔率、全场动画和多方混战的下注构图。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的怪兽赌局公开下注板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜匿名出牌轨道改成更像电子桌游牌列

### 本轮实现

- 顶部 `CardResolutionTtaMarketPanel` 从 62px 压到 54px：
  - 可见槽位从 9 个扩到 10 个；
  - 单个槽位更窄更矮，减少对中央星球和底部手牌的挤压；
  - 左侧图例改成短标题，右侧主体保持横向拖动/滚轮回看。
- 新增 `CardResolutionTtaCostBandRail`：
  - `✓` 表示历史牌；
  - `0` 表示当前展示牌；
  - `+` 表示本批竞价/候补；
  - `N` 表示下一批等待。
- 牌槽新增 hover 轻微放大反馈：
  - 常态只显示图标、短牌名、罗马等级、小费和匿名/公开归属；
  - 详细效果仍放在悬停提示和双击详情中；
  - 不把长规则塞回主牌桌。

### 设计意图

- 出牌轨道应像电子桌游的公共牌列：玩家扫位置、颜色、费用/报价和归属线索，而不是阅读整段牌文。
- 顶部轨道只承担“全桌节奏”和“匿名线索”的职责；真正的牌面详情交给 hover 与图鉴。
- 后续继续沿这个方向做：更清楚的当前牌高亮、更稳定的横向回看、更像赌桌边缘的牌槽质感。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的牌轨护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜全桌卡牌展示横幅增加倒计时条

### 本轮实现

- `CardResolutionTableBanner` 新增 `CardResolutionRevealTimerPanel`：
  - `CardResolutionRevealTimerLabel` 显示当前阶段与剩余秒数；
  - `CardResolutionRevealTimerBar` 显示公开展示、竞价、同时窗或响应窗口的剩余比例；
  - `_update_card_resolution_timer_bar()` 统一更新展示、竞价、同时判定和相位响应窗口；
  - 倒计时条颜色随阶段变化：展示、竞价、同时窗、响应分别用不同强调色。
- 规则不变：
  - 公开展示仍是固定 5 秒；
  - 多人同时出牌竞价仍是 5 秒；
  - 0.5 秒同时判定窗仍保留；
  - 相位否决响应窗口仍是 5 秒。

### 设计意图

- 卡牌展示是全桌节奏的中心，玩家应该一眼看到“现在处于什么阶段，还剩几秒”。
- 这一步让卡牌结算更像电子桌游的公共翻牌/结算条，而不是普通弹窗文字。
- 横幅仍保持顶部非阻塞，不遮挡右侧牌架和底部手牌。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的卡牌展示横幅护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜区域牌架市场格改成桌游市场卡

### 本轮实现

- 右侧区域牌架的左栏从多行按钮升级为 `DistrictSupplyMarketCardPanel`：
  - `DistrictSupplyMarketCardTitle` 显示卡牌图标、短卡名和选中箭头；
  - `DistrictSupplyMarketCardRank` 显示罗马等级；
  - `DistrictSupplyMarketCardChipRail` 显示价格和购买状态；
  - `DistrictSupplyMarketCardRoute` 显示策略路线；
  - `DistrictSupplyMarketCardFactLine` 显示最短关键效果；
  - `DistrictSupplyMarketCardColorTick` 用底部色条标记可买、仅浏览、需弃牌或资金不足。
- 单击/悬停仍然预览，双击仍然尝试购买；右侧 `DistrictSupplySelectedPreview` 继续负责完整卡面和购买按钮。

### 设计意图

- 区域牌架是“地图区域 → 看牌 → 购牌 → 构筑路线”的高频入口，左侧市场不能像纯文本列表。
- 这一步更接近电子桌游市场牌列：玩家先扫价格、状态、路线和等级，再决定是否看右侧卡面或购买。
- 规则不变：查看始终允许；购买资格和价格仍按打开区域牌架的一刻锁定；同一时间只保留一个牌架窗口。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的区域牌架市场卡护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜玩家板增加终局目标进度条

### 本轮实现

- 底部 `PlayerTableauBoard` 新增 `PlayerTableauGoalMeter`：
  - `PlayerTableauGoalLabel` 显示当前玩家的终局目标状态；
  - `PlayerTableauGoalMeta` 显示差额、倒计时或隐私提示；
  - `PlayerTableauGoalProgressBar` 用进度条表示可见结算估值距离目标现金线的比例。
- 当前真人玩家可见自己的 `¥当前/目标`、差额与达标状态。
- 查看 AI/对手席位时仍显示“对手资金隐私”，不会泄露现金、手牌或真实资产。
- 若终局倒计时已触发，进度条标题切换为倒计时状态，提示玩家保钱、护城或反扑。

### 设计意图

- 电子桌游的个人板应该第一眼告诉玩家“我离胜利还差多少”，不应该要求玩家每次打开局势排名。
- 目标进度条和资源筹码共同构成底部玩家板：左侧公开角色，右侧终局目标、资金、GDP、城市、手牌、怪兽、军队。
- 这一步继续保留信息隐私边界：对手资金仍靠城市、牌轨、怪兽和商品线索推理。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的玩家板目标进度条护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜局内目标提示增加推荐动作按钮

### 本轮实现

- 底部 `TableGoalPrompt` 从纯提示卡升级为“提示 + 推荐动作”：
  - 新增 `TableGoalPrimaryActionRail`，把下一步文字和按钮放在同一行；
  - 新增 `TableGoalPrimaryActionButton`，根据当前局势给出一个最常用动作；
  - 新增 `_first_actionable_hand_slot()`，用于从当前手牌中找第一张可打牌；
  - 新增 `_table_goal_primary_action()`，按当前状态选择推荐动作。
- 推荐动作覆盖试玩最常见路径：
  - 有起始怪兽可部署时显示“在选区首召”；
  - 当前区域可城市化时显示“城市化”；
  - 需要补牌或没有手牌时显示“打开牌架”；
  - 手牌中有可打牌时显示“打出某牌”；
  - 有私密弃牌、目标选择等临时窗口时显示对应提示，但不绕过原来的窗口。

### 设计意图

- 目标提示不能只告诉玩家“你应该做什么”，还要在牌桌上提供一个能直接点的入口。
- 这一轮不改变规则，只把已有动作变成更像电子桌游的主行动按钮：少读字，先按当前最合理的一步推进。
- 复杂目标选择、私密弃牌和合约回应仍保留在右侧行动托盘，推荐按钮只做入口，不偷跑结算。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的底部目标提示护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜主菜单顶部改成星球牌桌开桌大厅

### 本轮实现

- 主菜单首屏新增 `MainMenuPlanetLobbyPanel`：
  - 左侧 `MainMenuPlanetMedallion` 用“中央星球”作为视觉锚点，压住游戏是围绕星球下注、建城和推理的核心印象；
  - `MainMenuLobbyChipRail` 用短筹码显示 3-8 席、起始怪兽、匿名牌轨和按秒结算；
  - 右侧 `MainMenuLobbyKpiGrid` 用四张短卡说明先开一桌、看中央星球、读公共牌轨、钱最多获胜；
  - `MainMenuLobbyActionGrid` 给出开新一桌、继续本局、查资料三张大入口卡。
- 原有主菜单分支列表仍保留在下方，玩家想深入规则、图鉴、经济、情报或存档时继续往下看。
- 若没有当前局面，“继续本局”会显示为“暂无本局”，减少第一次进入时的误点。

### 设计意图

- 主菜单要像进入一张电子桌游牌桌，而不是先看到一串功能表。
- 第一屏只回答三件事：这是什么游戏、现在该从哪里开始、去哪里查资料。
- 结构继续参考《Terraforming Mars》这类桌游电子版的入口节奏：中央主题板先建立空间感，规则和复杂系统收进分支。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的主菜单大厅护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜匿名出牌轨道改成固定九槽公共牌列

### 本轮实现

- 继续按《历史巨轮》电子版的公共牌轨思路收口顶部出牌轨道：
  - 新增 `CARD_TRACK_VISIBLE_SLOT_COUNT := 9`，让顶部始终保留九个可扫读的公共牌槽；
  - 牌槽宽度从 `78px` 收到 `72px`，当前展示槽从 `98px` 收到 `92px`；
  - 新增 `CardResolutionTtaSlotGrooveRail` / `CardResolutionTtaSlotGroove`，在真牌上方保留固定槽线；
  - 新增 `CardResolutionTtaGhostSlot`，没有牌时也显示空槽，不再让顶部轨道退化成一条文字提示；
  - 真牌仍只显示阶段、等级、短牌名、小费和归属筹码，详情交给 hover 与双击图鉴。

### 设计意图

- 出牌轨道要像电子桌游的公共牌市场，而不是战斗日志。
- 玩家常态只扫：历史、当前、竞价、候补、报价、匿名归属；想看卡牌效果再 hover 或双击。
- 固定槽位能让玩家形成空间记忆：牌是“进入牌列并排队结算”，不是突然弹出大窗口打断牌桌。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的牌轨护栏，覆盖固定九槽、槽线、空槽和紧凑卡槽。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜开局座位卡隐藏 AI 内部路线并增加公开信息板

### 本轮实现

- 开局准备页的 AI 席位不再显示 AI 性格名：
  - 原先座位标签会显示类似 `AI·拓荒型AI`；
  - 现在统一显示 `电脑对手`，避免把 AI 的路线倾向当作公开信息泄露给测试者。
- 每张座位卡新增 `NewGameSetupSeatIdentityBoard`：
  - `NewGameSetupSeatPublicChipRail` 显示公开角色、首召怪兽、怪兽归属匿名和 `AI策略隐藏` / `本地玩家`；
  - `NewGameSetupSeatInfoGrid` 用四张 `NewGameSetupSeatInfoCard` 显示公开身份、首召怪兽、第一步、信息边界；
  - 随机 AI 角色会显示“开局随机分配，结果公开且不重复”，不展示 AI 内部路线。

### 设计意图

- 开局准备要像电子桌游开桌大厅：测试者能快速看懂席位、公开角色和首召怪兽，但不应该提前知道 AI 的隐藏发展路线。
- 角色是公开信息；AI 计划、路线权重、压力桶和出牌思路仍属于内部对手逻辑，只通过场上公开动作留下线索。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的开局座位卡护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜区域牌架顶部改成桌游式市场牌板

### 本轮实现

- 右侧区域牌架抽屉新增 `DistrictSupplyShelfBoard`：
  - 顶部标题、关闭按钮、短规则条和状态筹码收进同一张市场牌板；
  - `DistrictSupplyRuleStrip` 改成“侧边牌架｜市场格｜悬停预览｜双击购买”；
  - `DistrictSupplyShelfChipRail` 继续显示牌架数量、可购买/仅浏览、范围来源、价格已锁和单窗口；
  - 新增当前玩家自己的 `¥现金` 与 `手牌 X/5` 筹码；
  - 满手时显示 `弃牌私密`，提醒买牌会进入私下弃牌确认，但不公开手牌数量给其他玩家。
- 左右两栏标题更接近桌游电子版市场读法：
  - 左侧 `DistrictSupplyMarketColumnTitle`：`市场格｜价格/状态/路线`；
  - 右侧 `DistrictSupplyPreviewColumnTitle`：`牌面预览｜效果/购买结论`。

### 设计意图

- 区域牌架是“地图区域 → 购牌 → 构筑路线”的核心入口，玩家应该先扫状态筹码，再看市场格和右侧卡面预览。
- 购买资格、价格锁定、单窗口和手牌上限是容易误解的地方，本轮把它们放到牌架顶部的桌游式市场板里。
- 规则没有改变：查看始终允许，购买资格和价格仍按打开区域牌架的一刻锁定。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的区域牌架市场板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜怪兽生态详情改成怪兽单位档案板

### 本轮实现

- 怪兽生态详情页新增 `BestiaryMonsterBoardPanel`：
  - 左侧保留怪兽临时美术，作为单位画像；
  - `BestiaryMonsterHeader` 显示怪兽名、风格短句和核心筹码；
  - `BestiaryMonsterChipRail` 用筹码显示 HP、护甲、速度、移动生态、商品偏好和相遇距离；
  - `BestiaryMonsterKpiGrid` 把生态位、资源与经济、行动定位、固定技能成长拆成四张短卡；
  - `BestiaryMonsterActionGrid` / `BestiaryMonsterActionCard` 把自动行动概率做成行动牌：显示 I级/IV级在开局与破坏后的概率、招式标签和关键数值。
- `_bestiary_text()` 从长概率表压缩成三行：
  - 当前第几只怪兽；
  - 提示下方怪兽档案板负责画像、速度、偏好、破坏和行动概率；
  - 保留怪兽牌属于卡牌图鉴的跳转关系。

### 设计意图

- 怪兽是桌面上的核心压力源，测试者需要先看懂“它会去哪、会打什么、概率多高”，而不是阅读整页规则文本。
- 怪兽详情页现在更像电子桌游里的单位牌板：左边是单位画像，右边是属性筹码，下面是行动牌。
- 概率、伤害、击退和资源偏好继续来自同一套怪兽规则数据，避免图鉴、AI 与实际行动脱节。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的怪兽单位档案板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜匿名出牌轨道继续向《历史巨轮》式牌槽收口

### 本轮实现

- 顶部匿名出牌轨道继续压成电子桌游的“公共牌槽”：
  - `CardResolutionTtaMarketPanel` 从 `66px` 收到 `62px`，减少对中央星球和底部手牌的挤压；
  - 左侧 `CardResolutionTtaOfferRailLegend` 只保留“匿名牌轨”和“公共牌槽｜拖动/滚轮回看”；
  - `CardResolutionTtaMarketHeader` 改成 `✓ / 0 / + / N` 四个极短槽位标记；
  - 新增 `CardResolutionTtaSlotMarketMat` 作为整条牌列的桌面底板；
  - 新增 `CardResolutionTtaAgeMarketRuler` 作为历史、当前、竞价、候补的扫视标尺。
- 牌槽本体继续保持“默认只扫读，hover 看详情，双击进图鉴”：
  - 轨道槽位宽度进一步收窄；
  - 当前展示牌略宽、金色边框；
  - 历史牌变暗；
  - 候补牌用 `+1/+2` 和位置点表示顺序；
  - 小费与归属线索保留在筹码里。

### 设计意图

- 这个轨道的目标不是日志栏，而是像《历史巨轮》电子版那样的公共卡牌市场：玩家先扫槽位和筹码，再决定是否 hover、竞猜或双击查看。
- 玩家主注意力应留给中央星球、手牌和下注/出牌动作，顶部牌轨只承担“公共记忆 + 即将结算队列”的桌边功能。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的牌轨护栏，防止后续回退成大段文字或大面板。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜角色图鉴改成公开身份牌与路线面板

### 本轮实现

- 角色图鉴详情页新增 `RoleCodexIdentityBoardPanel`：
  - 左侧保留角色卡面/临时美术；
  - `RoleCodexIdentityHeader` 显示角色名、序号、种族和牌路定位；
  - `RoleCodexIdentityChipRail` 用筹码显示公开角色、首召独立、商品经营、情报推理、合约商路、怪兽路线等标签；
  - `RoleCodexAbilityKpiGrid` 把经济、情报、控制、开局拆成四张短卡；
  - `RoleCodexRouteCardGrid` 把被动能力、角色特征、信息边界、开局打法、选择提醒和风味拆成短卡。
- `_role_codex_text()` 从“特征/被动/背景”段落压缩成短摘要：
  - 当前第几张角色；
  - 提示下方公开身份牌负责扫读；
  - 强调角色公开、首召怪兽独立、怪兽归属仍靠线索推理。

### 设计意图

- 角色是开局第一批决策之一，玩家需要一眼知道“这个角色会带我走哪条路线”，而不是先读设定清单。
- 公开角色不能暴露首召怪兽归属，所以 UI 必须把“公开身份”和“匿名怪兽/城市/手牌”边界说清楚。
- 这一步让角色图鉴、商品图鉴和区域图鉴统一为桌游式短卡阅读：先扫筹码和路线，再用 hover 看完整文本。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的角色身份牌护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜商品详情页改成桌游式商品市场板

### 本轮实现

- 商品图鉴详情页新增 `ProductCodexMarketBoardPanel`：
  - 左侧保留商品徽章/临时美术，作为资源牌视觉锚点；
  - `ProductCodexMarketHeader` 显示商品名、商业线、品类、地形和用途；
  - `ProductCodexMarketChipRail` 用筹码显示当前价、基准价、趋势、供给、需求、断路和波动；
  - `ProductCodexMarketKpiGrid` 把价格、主策略、天气、牌路拆成四张 KPI 卡；
  - `ProductCodexStrategyGrid` 把策略用途、期货/仓储、怪兽偏好、地图供给、地图需求、城市线索拆成短卡。
- `_product_codex_text()` 从长分区报告压缩成短摘要：
  - 第几种商品、价格、商业线、符号；
  - 提示下方商品市场板负责主要信息；
  - 保留身份、现金和手牌仍靠推理的提醒。

### 设计意图

- 商品是经济、卡牌门槛、期货仓储、商路和怪兽偏好的共同语言，玩家需要像读电子桌游资源面板一样快速理解它。
- 详情页不应先展示长报告；第一眼应看到价格/供需/趋势/策略/地图入口。
- 这一步让商品图鉴和区域图鉴形成同一套“扫读短卡 + hover 详情”的桌游式信息层级。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的商品市场板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜区域图鉴改成桌游式地块情报板

### 本轮实现

- 区域图鉴详情页新增 `RegionCodexTileBoardPanel`：
  - `RegionCodexTileHeader` 显示区域名、序号、地形图标和城市状态；
  - `RegionCodexTileChipRail` 用筹码显示 HP、热度、交通、商路、牌架和当前选中；
  - `RegionCodexTileKpiGrid` 把城市/GDP、供给、需求、天气拆成四张短 KPI 卡；
  - `RegionCodexActionClueGrid` 把商路、区域牌架、怪兽吸引、公开线索、邻接和读法拆成短卡；
  - `RegionCodexClueCard` 的完整解释放进 hover，常驻文本只保留可决策摘要。
- `_region_codex_text()` 从长报告压缩为三行：
  - 区域编号、名称、地形、状态；
  - 提示下方地块板负责可扫读信息；
  - 提醒真实业主、现金和手牌仍靠线索推理。

### 设计意图

- 区域是玩家建城、买牌、标注、商路、怪兽诱导和军事行动的共同入口，必须像桌游地图板块一样先给可扫读信息。
- 玩家不应该进入区域图鉴后先读一整段 GDP、天气、商路和线索报告；第一眼应看到地块牌、筹码和短卡。
- 这一步让“中央星球选区板”和“图鉴区域详情”使用同一套桌游语言，方便测试者在地图和资料页之间来回确认。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的区域地块板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜匿名出牌轨道二次收口为《历史巨轮》式连续牌列

### 本轮实现

- 顶部出牌轨道不再使用通用大面板，而是独立成固定高度的公共牌列：
  - `CardResolutionTtaMarketPanel` 高度收口到 `66px`；
  - `CardResolutionTtaOfferRailFrame` 把左侧图例和右侧横向卡槽放在同一条桌边轨道；
  - `CardResolutionTtaOfferRailLegend` 只显示“匿名牌轨｜公共牌槽”和“拖动/滚轮回看”；
  - `CardResolutionTtaMarketHeader` 压成 `✓史 / 0今 / +竞 / N候` 四个短标记；
  - 牌槽继续保留 `CardResolutionTtaSlotIndex`、罗马等级、卡牌图标、报价点和归属筹码。
- 每张轨道牌进一步压成固定小卡：
  - 当前展示牌稍宽；
  - 历史牌变暗；
  - 候补牌显示位置点；
  - 详细效果、目标、打出条件和竞价说明仍放在 hover；
  - 双击继续进入卡牌图鉴详情。

### 设计意图

- 参考《历史巨轮》电子版的公共牌列读法：桌面中央只需要一排可扫读卡槽，完整文本在 hover/详情层。
- 匿名出牌轨道是公共桌面信息，不应该抢走中央星球和手牌空间。
- 这一步把“历史、当前、竞价、候补”变成视觉槽位，而不是长说明区，后续竞猜、竞价和历史回看都围绕这条牌列继续扩展。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的牌轨护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜新手引导改成试玩速成任务板

### 本轮实现

- 新手引导页新增 `TutorialQuickStartPanel`：
  - 顶部显示第一局、目标钱最多、细则进规则；
  - `TutorialQuickStartStepGrid` 用步骤卡展示首召怪兽、建第一城、看区域牌架、买第一张牌、打匿名牌、读公共牌轨、看经济/情报、终局冲刺；
  - `TutorialQuickStartTrapGrid` 用常见卡点卡片说明买不了牌、牌打不出、看不懂谁领先、不知道查哪里。
- `_open_tutorial_menu()` 正文从九段长说明压缩成一句试玩目标和入口提示。
- 复杂细则仍保留在游戏规则页；本页只负责让测试者开始第一局。

### 设计意图

- 新玩家第一次测试不应该先读规则书，而应该像电子桌游一样看到“下一步任务板”。
- 试玩速成板把“首召 → 建城 → 买牌 → 匿名出牌 → 读牌轨/经济/情报 → 终局”压成可扫读步骤。
- 这一步补齐主菜单中的轻教程入口，让桌边轻引导和菜单教程保持同一套信息层级。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的试玩速成板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜情报档案改成桌游式侦探板

### 本轮实现

- 情报档案页新增 `IntelDossierBoardPanel`：
  - 顶部强调终局揭晓、卡牌归属即时竞猜和不扫描对手现金/手牌；
  - `IntelDossierKpiGrid` 显示城市标注进度、待查城市、匿名牌、公开资金线索；
  - `IntelDossierClueGrid` 把城市嫌疑、匿名牌轨、怪兽资金、仓储/做空靶标、城市公开线索和下一步查证拆成短卡。
- `_intel_dossier_text()` 从长证据报告压成短说明：
  - 说明城市标注如何终局结算；
  - 说明卡牌归属竞猜如何即时押注；
  - 提示下方侦探板负责可扫读证据。
- 原有线索跳转、城市标注、置信度和标注理由按钮继续保留在侦探板下方。

### 设计意图

- 匿名出牌和隐藏城市业主是核心玩法，玩家需要一个像桌游侦探板的地方整理证据，而不是读长清单。
- 情报页必须明确“这是概率证据，不是公开真相”，并继续保护对手现金、手牌和真实资产归属。
- 这一步让测试者更容易从“看到线索”进入“标注城市 / 猜牌主 / 跳图鉴查证”的行动闭环。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的情报侦探板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜局势排名改成桌游式记分板

### 本轮实现

- 局势排名页新增 `StandingsScoreboardPanel`：
  - 顶部显示现金目标、终局倒计时、城市清算值和对手隐私；
  - `StandingsRaceKpiGrid` 显示当前玩家终局距离、城市现金流、公开异动和反超方向；
  - `StandingsPlayerScoreGrid` 用每席一张 `StandingsPlayerScoreCard` 展示玩家牌。
- 进行中仍保护隐私：
  - 当前玩家显示精确可见估值、现金、城市、GDP/min 和情报摘要；
  - 对手牌只显示“现金隐藏、手牌隐藏、资产靠推理”；
  - 玩家仍需通过牌轨、地图、怪兽受伤、商品价格和公开异动推理。
- `_standings_text()` 从长排行报表压缩成短说明，让首屏先看到记分板。

### 设计意图

- “谁快赢了”是每局测试最常看的信息，必须像电子桌游记分板一样可扫读。
- 玩家不应该先读一整段排名公式和长排行；应先看目标、倒计时、自己的距离和对手隐私牌。
- 这一步让局势页更接近《Terraforming Mars》这类桌游电子版的玩家板/分数板阅读节奏。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的局势记分板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜开局准备增加电子桌游式开桌流程板

### 本轮实现

- 开局准备页新增 `NewGameSetupLobbyPanel`：
  - 顶部显示 PVE 席位数、AI 数量和现金目标；
  - `NewGameSetupFlowTrack` 把开局流程拆成五张步骤卡；
  - `NewGameSetupFlowStepCard` 依次提示：席位、挑战、角色、首召、开局；
  - `NewGameSetupReadinessRail` 显示角色不重复、首召独立、进桌先首召、AI可随机角色、最后钱最多。
- 原有席位按钮、AI按钮、挑战层级、座位卡、角色选择、起始怪兽选择继续保留。
- 页面入口文案改成“开桌前确认”，减少像设置表单的感觉。

### 设计意图

- 开局准备是测试者进入一局的第一道门，应该像电子桌游的开桌大厅，而不是一堆裸设置控件。
- 玩家先看五步流程，知道“角色公开但首召怪兽独立匿名”，再去调整座位卡。
- 这一步让真人玩家更容易开始 PVE 测试局，尤其是第一次进入项目时。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的开局 lobby 护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜卡牌详情页增加TCG式扫牌顺序与升级阶梯

### 本轮实现

- 卡牌图鉴详情页新增 `CardCodexTcgSummaryPanel`：
  - 顶部先显示卡牌类型、策略路线和子类型；
  - `CardCodexTcgSummaryChipRail` 用筹码显示购买价、罗马等级、商品门槛、目标类型和一次性/固定去向；
  - 增加固定读法：费用 → 门槛 → 目标 → 去向 → 效果 → I-IV升级。
- 详情页布局拆成更明确的 TCG 阅读结构：
  - `CardCodexTcgDetailLayout`；
  - `CardCodexTcgFaceColumn`；
  - `CardCodexTcgReadColumn`；
  - `CardCodexTcgFactGrid`。
- I-IV 强化展示从普通信息卡改成 `CardCodexUpgradeLadder`：
  - 每级为 `CardCodexUpgradeStepCard`；
  - 显示罗马等级、价格、强度带和一句关键效果；
  - 悬停保留完整效果文本。

### 设计意图

- 玩家看卡牌时应该先像读桌游/TCG卡面一样扫关键词，而不是先读整段说明。
- 卡牌等级是核心构筑机制，必须以阶梯呈现，让玩家一眼看到“这张牌升级后强在哪里”。
- 这一步继续减少常驻长文字，把完整解释放到 hover 和详情层。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的卡牌详情护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜经济总览改成桌游式经济仪表板

### 本轮实现

- 经济总览正文从长报表压缩成短说明：
  - 看钱从哪座城来；
  - 看哪个商品在变贵；
  - 看哪些公开动作留下线索。
- 首屏新增 `EconomyDashboardPanel`：
  - `EconomyDashboardKpiGrid`：显示 GDP/min、商品热度、城市前景、公开线索；
  - `EconomyDashboardChip`：显示全局刷新、场上怪兽、天气；
  - `EconomyDashboardListCard`：把商品热榜、低价机会、城市现金流、匿名余波、怪兽/仓储风险和下一步读法拆成榜单卡。
- 详细证据不再常驻挤满正文：
  - 每条榜单短行可悬停看完整说明；
  - 对手现金、手牌和私密推理仍不展示；
  - 经济页只呈现公开结果和当前玩家可见信息。

### 设计意图

- 经济总览是玩家理解“为什么赚钱/输钱”的核心页面，必须像电子桌游的资源板和市场板，而不是调试报表。
- 玩家第一眼先扫 KPI 和榜单，再决定去看商品、商路、牌轨或情报档案。
- 这一步继续贯彻《Terraforming Mars》式的信息层级：桌面先给数字和图标化短标签，细则通过 hover/详情展开。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的经济仪表板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜匿名牌轨改成《历史巨轮》式公共牌槽

### 本轮实现

- 出牌轨道从“匿名出牌列 + 说明句”改成更接近电子桌游公共牌列的“公共牌槽”：
  - `CardResolutionTtaMarketPanel`：顶部公共牌槽面板；
  - `CardResolutionTtaMarketHeader`：只保留历史、当前、竞价、候补四个小筹码；
  - `CardResolutionTtaMiniCard`：轨道中的小卡牌面；
  - `CardResolutionTtaSlotIndex`：用 `0`、`+1`、`+2`、`✓` 表示当前/候补/历史位置；
  - `CardResolutionCostPipRail`：保留牌位亮点，形成类似桌游电子版卡槽市场的扫视节奏。
- 主界面不再常驻“悬停、单击、双击”的长说明；交互说明移到牌面 tooltip。
- 竞价金额和归属仍作为牌槽底部小筹码显示，继续服务匿名推理。

### 设计意图

- 出牌轨道应该像桌面公共信息，而不是日志栏。
- 玩家第一眼只需要知道“有哪些牌、哪张当前、接下来几张是什么、报价/归属有没有线索”。
- 详细效果留给 hover/双击，让中央星球、手牌和牌桌节奏保持清爽。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的 UI 护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜首召怪兽提示改成桌边首召卡

### 本轮实现

- 首召提示从一行长说明改成桌边起始怪兽卡：
  - `FirstSummonCard`：首召主卡；
  - `FirstSummonChipRail`：显示首召关键信息；
  - `FirstSummonCardArt`：起始怪兽小卡面；
  - `FirstSummonDropZone`：显示当前落点是否可用；
  - `FirstSummonDeployButton`：执行“在选区首召”。
- 首召筹码显示：
  - `免门槛`；
  - 当前落点；
  - 固定技能数量；
  - 首召后开启区域牌架。
- 规则不变：
  - 起始怪兽仍可任选未毁区域；
  - 首召不需要商品流动；
  - 首召后才开启怪兽落地区/邻区购牌；
  - 召唤者获得固定技能牌，仍不公开归属。

### 设计意图

- 首召是玩家第一步操作，不能藏在长提示句里。
- 这一步让测试者看到“选区 → 首召 → 开牌架”的桌边起始项目牌，第一局更容易开始。
- 起始怪兽小卡面和筹码能把“这是我的第一张可执行牌”这件事表达得更像电子桌游。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜手牌卡面增加可打状态轨：不点按钮也能看懂为什么不能出牌

### 本轮实现

- 手牌卡面新增可打状态组件：
  - `HandCardPlayStatePanel`：手牌状态小面板；
  - `HandCardPlayStateRail`：状态筹码轨；
  - `HandCardPlayStateChip`：显示 `可打 / 需商品 / 需目标 / 排队中 / 冷却中 / 赌局暂停` 等短状态；
  - `HandCardPlayReason`：一行短原因，完整解释放在 tooltip。
- 状态轨会读取现有出牌判断，不新造规则：
  - 商品流动门槛；
  - 目标怪兽/目标玩家；
  - 合约两端；
  - 现金额外费用；
  - 行动冷却、卡牌冷却、封锁、排队、怪兽赌局冻结。
- 手牌按钮仍保留：
  - 可打就显示 `打出` 或 `释放`；
  - 需要目标则显示 `选目标`；
  - 不能打时按钮文字仍显示原因。

### 设计意图

- 测试者看手牌时，必须一眼知道“这张能不能打”和“卡在哪里”，不能靠点按钮试错。
- 这一步让手牌更像桌游电子版卡面：价格/等级/门槛是一组筹码，可打状态是另一组筹码。
- 复杂解释仍进 tooltip，主卡面只保留短状态，避免文字密度继续上升。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜开局轻引导改成行动轨：五步试玩路径更像桌游教程条

### 本轮实现

- 开局轻引导从普通提示卡升级为桌游式行动轨：
  - `OpeningGuideCard`：轻引导主卡；
  - `OpeningGuideTimeline`：五步开局行动轨；
  - `OpeningGuideProgressTrack`：进度条；
  - `OpeningGuideStepToken`：每一步以完成/未完成筹码显示；
  - `OpeningGuideNextStepCard`：当前下一步行动卡；
  - `OpeningGuideNextStepChipRail`：下一步入口与状态筹码。
- 五步路径保持为：
  - 首召怪兽；
  - 建第一城；
  - 买第一牌；
  - 匿名出牌；
  - 看经济总览。
- 保留已有按钮：
  - `经济总览`；
  - `新手引导`；
  - `游戏规则`；
  - `关闭`。

### 设计意图

- 人类测试者第一局最容易卡在“我现在应该干什么”，所以开局提示必须像电子桌游教程条一样给出行动轨。
- 常态只显示步骤筹码和下一步短句；原因、入口和完整解释放进 tooltip 或规则页。
- 这一步把“首召 → 建城 → 买牌 → 出牌 → 看经济”的试玩闭环压成一个清楚的桌边组件。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜中央星球操作栏筹码化：地图提示不再是一整句说明

### 本轮实现

- 中央星球上方的地图工具栏改成桌游筹码结构：
  - `MapControlBar`：地图控制栏容器；
  - `MapControlChipRail`：星球操作筹码轨；
  - `MapControlChip`：短筹码显示“星球主视野 / 滚轮缩放 / 拖拽地图 / 双击看牌 / 当前选区 / 商路 / 合约”。
- 原有功能继续保留：
  - 商品商路下拉仍可选择具体商品；
  - 合约供给端/需求端按钮仍在地图栏；
  - 当前选区、商路条数和合约端点会更新到筹码文字与 tooltip。
- 玩家可见文案进一步压短：
  - 常态不再显示“滚轮缩放 · 拖拽地图 · 双击区域看牌”的长句；
  - 关键操作改成短筹码，详细解释进入 tooltip。

### 设计意图

- 中央星球必须保持视觉主角，地图上方只应该像桌游控制条一样提示动作。
- 玩家初次测试时，看到“滚轮缩放 / 拖拽地图 / 双击看牌”三个筹码就能立刻操作，不需要读长句。
- 地图栏与顶部状态筹码、出牌轨道、玩家板、区域牌架形成同一套桌游 UI 语言。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜选区行动升级为地块板：点地图后先看地块，再做动作

### 本轮实现

- 选中区域的行动面板改成更像桌游地块信息板：
  - `SelectedDistrictBoard`：选区主面板；
  - `SelectedDistrictTilePlate`：当前地块牌，显示区域名、地块定位和短状态；
  - `SelectedDistrictTileIcon`：用 `⬡ / ≈ / ▣ / ✕` 区分陆地、海域、城市和废墟；
  - `SelectedDistrictChipRail`：继续显示地形、HP、城市/GDP、牌架、商品供需、天气；
  - `SelectedDistrictActionGrid`：把城市化、牌架、标注、商路、全屏收成一排短按钮。
- 行动文案从长解释进一步压短：
  - `🏙城市化`
  - `＋牌架`
  - `◇标注`
  - `⇄商路`
  - `⛶全屏`
- 规则不变：
  - 双击区域仍可打开区域牌架；
  - 海洋不能城市化但可作为运输/商品区域；
  - 陌生城市可进入情报标注；
  - 商路显示仍按当前商品/选区切换。

### 设计意图

- 玩家点中央星球后，应该立刻得到一个“这块地是什么、这里能做什么”的桌游地块板。
- 地块板比纯状态行更符合电子桌游阅读路径：先看地块牌，再扫筹码，再点行动按钮。
- 这一步减少选区区域的解释性文本，让地图与桌边行动托盘之间的连接更清楚。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜区域牌架改成右侧卡牌市场：小卡格 + 选中预览

### 本轮实现

- 区域牌架继续保持右侧抽屉，但改为更像桌游电子版的市场结构：
  - `DistrictSupplyMarketPanel`：左侧市场区；
  - `DistrictSupplyMarketGrid`：区域提供卡牌以小卡格呈现；
  - `DistrictSupplyMarketCard`：每张候选卡只显示短名、价格、购买状态和一句路线摘要；
  - `DistrictSupplyPreviewPanel`：右侧选中卡预览；
  - `DistrictSupplySelectedPreview`：显示选中卡牌面、状态筹码和购买按钮。
- 抽屉宽度从右侧窄列表调整为更适合“市场格 + 预览板”的桌面侧栏：
  - 仍不改成中央弹窗；
  - 仍保留中央星球主视野；
  - 让玩家双击区域后能像浏览项目牌市场一样扫牌。
- 规则保持不变：
  - 查看区域牌架不受购买资格限制；
  - 购买资格和价格按打开窗口瞬间锁定；
  - 同一时间只保留一个区域牌架；
  - 手牌超限仍进入私密弃牌。

### 设计意图

- 区域牌架是“地图 → 卡牌经济”的核心入口，必须像一个可扫读的桌游市场，而不是按钮列表。
- 玩家先看左侧市场格，悬停/单击看右侧详情，再决定是否购买。
- 列表常态减少长文本，把解释放到 tooltip 和右侧预览，避免玩家一边看地图一边读墙文。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜底部玩家板重构：公开身份 + 资源筹码 + 手牌架

### 本轮实现

- 底部牌桌区新增更明确的电子桌游玩家板结构：
  - `PlayerSeatSelectorRail`：席位选择仍在顶部，避免和手牌/行动混在一起；
  - `PlayerTableauBoard`：玩家板外框；
  - `PlayerIdentityMiniCard`：显示当前席位、公开角色、种族和公开身份提示；
  - `PlayerTableauChipGrid`：集中显示资金、GDP、城市、手牌、怪兽、军队和终局筹码。
- 手牌区改为独立牌架：
  - `PlayerHandRackPanel`：手牌外框；
  - `PlayerHandRackChipRail`：显示手牌上限、悬停详情、点牌打出等短筹码；
  - `PlayerHandEmptySlot`：普通手牌空槽也有牌槽感，玩家能直观看到5张上限。
- 仍保持隐私规则：
  - 自己能看到资金和手牌；
  - 对手的资金、手牌数量、卡面和弃牌仍显示为隐私；
  - 角色卡作为公开信息显示，不绑定首召怪兽身份。

### 设计意图

- 主牌桌应该像电子桌游：玩家先扫自己的玩家板，再看手牌，再决定行动。
- 资源筹码比一行状态文字更容易读，也更符合《Terraforming Mars》一类桌游电子化的节奏。
- 手牌架必须是底部最容易识别的区域之一，不能被临时窗口、竞价按钮或说明文字抢走注意力。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜匿名出牌列改成电子桌游式横向牌轨

### 本轮实现

- 匿名出牌列改为更接近电子桌游牌行的结构：
  - 常态高度压低，减少对中央星球地图的遮挡；
  - 按 `历史 / 当前 / 候补 / 下批` 分段；
  - 每张轨道牌只显示短牌名、等级、报价和匿名/公开归属；
  - 完整效果继续放在悬停 tooltip，双击进入卡牌详情。
- 新增 `CardResolutionAgeTrackDivider` 分段牌槽和 `CardResolutionCostPipRail` 位置亮点：
  - 当前展示牌会更醒目；
  - 候补牌用亮点表达队列位置；
  - 玩家扫一眼即可知道“哪些牌已经打过、哪张正在展示、哪些牌排队”。
- 同步 UI 测试护栏：
  - `tests/visual_snapshot.gd` 检查牌轨分段、紧凑牌槽和位置亮点；
  - `tests/ui_text_smoke_test.gd` 检查出牌列不退回长文字描述。

### 设计意图

- 出牌轨道是玩家推理、竞价和猜归属的核心公共信息，应当像桌面中间的一排小卡，而不是日志列表。
- 常态只保留可扫读信息；玩家需要细节时再悬停或双击。
- 这条牌轨后续可以继续扩展为“历史回看、归属标签、竞猜入口、竞价队列”的统一公共桌面组件。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜归属竞猜牌槽：匿名牌推理变成桌边押注卡

### 本轮实现

- 选中匿名出牌列上的卡牌后，桌边行动托盘现在显示 `OwnerGuessCard`：
  - 标题为 `归属竞猜`；
  - 展示当前选中卡的短牌名和一句效果；
  - `OwnerGuessChipRail` 显示轨道编号、押注金额、猜牌主、已竞猜或公开归属；
  - `OwnerGuessAvatarRow` 放置可点击的玩家头像按钮。
- 保留原押注规则：
  - 每名玩家每张匿名牌只可竞猜一次；
  - 猜中公开贴牌主标签并转账；
  - 猜错只私下转账，不揭示真实牌主。
- 测试护栏同步：
  - `tests/visual_snapshot.gd` 检查 `OwnerGuessCard` / `OwnerGuessChipRail` / `OwnerGuessAvatarRow`；
  - `tests/ui_text_smoke_test.gd` 检查归属竞猜以桌边押注卡呈现。

### 设计意图

- 归属竞猜是匿名出牌玩法的核心推理与赌桌动作，不能只是散在托盘里的一排按钮。
- 玩家需要先扫：选中了哪张轨道牌、押多少钱、是否已竞猜、是否已公开；再点头像下注。
- 这一步把“看牌轨 → 猜牌主 → 公开/私下结算”的链路做得更像电子桌游的桌边互动卡。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜公开报价牌槽：竞价区从散按钮改成桌边赌注卡

### 本轮实现

- 桌边行动托盘里的竞价控件新增 `BidControlCard`：
  - 顶部标题为 `公开报价`；
  - `BidControlChipRail` 显示当前报价、最高报价、参拍/下批/预设、可调/锁定；
  - `BidControlButtonRow` 继续放 `+10/+20/.../清零` 等快速加价按钮；
  - `BidControlStatusLine` 保留原“报价状态：...”短行，方便玩家理解当前能否继续加价。
- 原来散落在行动托盘里的 `tip_row` 改为报价牌槽内部结构：
  - 金额公开；
  - 出牌者仍匿名；
  - 队列和封盘状态继续通过 tooltip/状态线解释。
- 测试护栏同步：
  - `tests/visual_snapshot.gd` 检查 `BidControlCard` / `BidControlChipRail`；
  - `tests/ui_text_smoke_test.gd` 检查竞价控件必须以公开报价牌槽呈现。

### 设计意图

- 竞价是游戏赌桌氛围的核心，不能只是 UI 按钮堆。
- 玩家第一眼应该看到“我现在报价多少、最高多少、是否参拍、还能不能调”，再决定点哪个筹码按钮。
- 这一步把匿名出牌列和小费竞价连接成更像桌游电子版的桌边赌注区。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜桌边操作模块筹码：先扫模块，再看细节

### 本轮实现

- 桌边行动托盘新增 `ActionTrayModuleChipRail`：
  - `⌖选区`：当前是否已选地图区域；
  - `＋竞价`：当前报价是预设、参拍还是下批等待；
  - `◇竞猜`：是否已选中匿名出牌列中的卡；
  - `⇄合约`：合约两端是否已设，或是否有合约待回应；
  - `◎目标`：是否有怪兽/玩家目标待指定；
  - `✦临时`：是否存在弃牌、合约、目标或怪兽赌局等临时决策。
- 保留原来的具体按钮和滚动托盘：
  - 选区、开局引导、弃牌、怪兽赌局、竞价、竞猜、合约和目标选择仍在下方细节区；
  - 新筹码层只负责让玩家先扫“哪些模块有事”。
- 标题旁短文案改为 `模块筹码先扫，细节下拉`，避免继续用一串模块名堆在标题行。
- 测试护栏同步：
  - `tests/visual_snapshot.gd` 检查 `ActionTrayModuleChipRail` / `ActionTrayModuleChip`；
  - `tests/ui_text_smoke_test.gd` 检查竞价、竞猜、目标等模块筹码存在。

### 设计意图

- 桌边行动托盘承载太多二级操作，玩家需要一个“桌游玩家板式总览”先判断当前该看哪里。
- 这一步不是新增规则，而是把已有操作分层：模块状态在上，细节按钮在下。
- 后续可以继续把竞价、竞猜、合约、目标选择做成更独立的桌边卡槽，但本轮先建立统一的模块扫描层。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜顶部状态筹码：隐藏长状态行，改成牌桌信息条

### 本轮实现

- 主界面顶部新增 `HeaderStatusChipRail`：
  - 时间 `◷`；
  - 当前席位 `◎`；
  - 现金目标 `♛`；
  - 匿名出牌列状态 `▤`；
  - 天气 `☄`；
  - 当前选区 `⌖`。
- 原 `status_label` 保留为隐藏状态快照：
  - 旧逻辑仍能读到完整时间、玩家、目标、队列、天气和选区；
  - 玩家不再在顶部看到一条挤满竖线的长调试文本。
- 顶部筹码会随 `_refresh_status()` 同步刷新：
  - 目标筹码显示当前可见结算估计 / 本层现金目标；
  - 队列筹码显示匿名出牌列当前阶段；
  - 天气筹码压缩为短预报，完整天气仍看中央星球上方天气筹码栏。
- 测试护栏同步：
  - `tests/visual_snapshot.gd` 检查顶部必须有 `HeaderStatusChipRail` / `HeaderStatusChip`；
  - `tests/ui_text_smoke_test.gd` 检查顶部状态拆成玩家可读筹码。

### 设计意图

- 顶部状态栏是玩家每秒都会扫的区域，不能像调试日志。
- 参考电子桌游的状态条：重要信息以短标签/图标/筹码呈现，细节靠 hover、经济总览和规则页展开。
- 这让主桌更接近“中央星球 + 牌列 + 玩家资源条”的桌游电子化结构。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜天气预报筹码栏：主桌只看现在、预报、影响

### 本轮实现

- 主地图上方天气条从裸文字状态栏改成桌游式筹码栏：
  - 外层命名为 `WeatherForecastBar`；
  - 内部使用 `WeatherForecastChipRail`；
  - 三个常驻筹码分别显示 `现在：...`、`预报：...`、`影响：...`。
- 文案压短：
  - 空状态从“现在：无活跃天气”改成 `现在：无天气`；
  - 默认影响从长解释改成 `影响：产/交/消`；
  - 活跃/预报天气继续显示类型、区域、倒计时和来源，但不再把长规则放在主桌。
- 保留原逻辑：
  - `weather_active_label`、`weather_forecast_label`、`weather_impact_label` 仍是可刷新 Label；
  - 现有天气系统、预报提前量、天气卡牌和 smoke 检查不需要重写。
- 测试护栏同步：
  - `tests/visual_snapshot.gd` 检查天气条必须使用 `WeatherForecastBar` / `WeatherForecastChipRail`；
  - `tests/ui_text_smoke_test.gd` 检查天气条使用短筹码文本。

### 设计意图

- 天气是玩家要提前规划的公开信息，不应该像日志一样长驻占屏。
- 主桌只给“现在有没有、下一条何时来、会改什么数值”三类决策信息；完整解释进入经济总览和规则页。
- 这延续中央星球 + 桌边筹码的电子桌游方向，减少测试者在主界面反复读长句的负担。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- 完整 `tests/smoke_test.gd` 上一轮 360 秒超时；本轮未重新声明完整通过。

## 2026-07-01｜匿名出牌列：改成横向小卡位牌轨

### 本轮实现

- 顶部匿名牌记录从“说明型轨道”改成“横向出牌列”：
  - 标题改为「匿名出牌列」；
  - 提示改为 `出牌列：历史←当前→候补｜悬停详情｜单击猜归属｜双击看卡`；
  - 牌列容器命名为 `CardResolutionAgeTrack`，每张牌是 `CardResolutionAgeTrackSlot`。
- 每个牌槽现在更像桌游电子版的横向卡位：
  - 顶部状态色带 `CardResolutionAgeTrackStateStrip`；
  - 主按钮显示状态 + 短牌名；
  - `CardResolutionAgeTrackChipRail` 用筹码显示「历史/当前/竞价/候补」、公开小费、牌主未知或公开归属；
  - 当前展示牌用更亮边框和更宽卡位突出。
- 保留原有交互：
  - 悬停看卡牌效果、条件、目标、演出和竞价线索；
  - 单击选择轨道卡用于猜归属；
  - 双击打开卡牌图鉴详情；
  - 横向拖拽/滚轮浏览历史与候补。

### 设计意图

- 参考电子桌游的“牌列”阅读方式：玩家先看位置、状态、牌名和筹码，不在顶部读长段文字。
- 当前牌、历史牌、候补牌要一眼分层；详细信息只在 hover 或详情页展开。
- 这一步继续减少主界面文字密度，让星球保持中央，牌轨成为桌边信息而不是第二张规则页。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- 完整 `tests/smoke_test.gd` 本轮曾以 360 秒运行，仍超时；未标记为完整通过。

## 2026-07-01｜牌桌语言：下一步提示改成任务卡与筹码

### 本轮实现

- 底部玩家区新增 `TableGoalPrompt`：
  - 常驻只显示“目标提示｜下一步｜一句行动”；
  - 用 `TableGoalPromptChipRail` 展示 `◎下一步`、`◆首召`、`▣建城`、`＋买牌`、`◇线索` 等短筹码；
  - 不再把“为什么/入口”这种开发说明作为玩家标签。
- 开局轻引导继续压缩：
  - 清单改成 `◆ 首召怪兽｜开牌架`、`▣ 建第一城｜现金增长`、`＋ 买第一牌｜重复升级` 等桌游式短句；
  - 进度条文案从说明型长句改成“开局进度 n/5｜随时关闭”。
- 玩家文本方向明确为：
  - 常驻界面只给行动和状态；
  - 细规则进入「游戏规则」「经济总览」；
  - UI 文案像桌游牌面和筹码，而不是开发备忘录。
- 测试护栏同步：
  - `tests/ui_text_smoke_test.gd` 检查 `TableGoalPrompt` / `TableGoalPromptChipRail`；
  - `tests/visual_snapshot.gd` 检查底部桌边牌架保留任务卡；
  - `tests/smoke_test.gd` 检查实际玩家面板存在任务卡、筹码轨和 `◎下一步`。

### 设计意图

- 用户提出的开发原则不能原样暴露给玩家；玩家只需要知道“现在可以做什么、点哪里、大概为什么有利”。
- 这一步把主界面进一步推向《殖民火星》电子版那类“中央板面 + 桌边卡牌 + 图标筹码”的信息层级。
- 后续卡牌详情、商品目录、角色页也应继续沿用这个方向：短标题、少量图标、分区清晰，长规则收纳。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。

## 2026-07-01｜卡面扫读：费用、门槛、目标做成筹码条

### 本轮实现

- 在 `scripts/main.gd` 中新增卡面筹码层：
  - `_card_face_chip_entries()` 从卡牌数据生成牌面筹码；
  - `_add_card_face_chip_rail()` 把筹码渲染到卡面上，并打上 `CardFaceChipRail` / `card_face_chip_rail` 护栏标记。
- 每张卡面现在能直接扫到：
  - 购买价 `¥N`；
  - 等级 `I/II/III/IV`；
  - 商品流动门槛，如 `◇轨迹墨水 2`；
  - 无门槛牌显示 `免门槛`；
  - 目标类型，如 `◆目标`、`◎玩家`、`⇄两区`、`按选区`；
  - `一次` 或 `固定`。
- 卡牌正文继续压短：
  - compact / 手牌卡只保留一句核心效果；
  - 非 compact 卡只保留核心效果 + 少量关键数值；
  - 费用、门槛、目标、一次/固定不再主要依赖正文解释。
- 测试护栏同步：
  - `tests/ui_text_smoke_test.gd` 要求源码保留卡面筹码条入口和“免门槛 / 按选区”等玩家词；
  - `tests/visual_snapshot.gd` 要求卡面继续使用 `CardFaceChipRail`，防止手牌退回纯文本说明。

### 设计意图

- 玩家看手牌时应该像看桌游卡：先扫成本、等级、目标和门槛，再读一句效果。
- 这一步不是最终美术，但确立了卡面信息层级：图标/筹码 > 一句效果 > hover/详情页。
- 后续可以继续把筹码换成更精美图标，但数据入口和 UI 位置已经固定。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。

## 2026-07-01｜中央星球缩放：从局部地表平滑卷成星球

### 本轮实现

- 在 `scripts/map_view.gd` 中明确建立 `PlanetProjectionBlend` 视觉合同：
  - `_planet_projection_blend()` 负责局部地表到中央星球的连续混合；
  - `_projection_smoothstep()` 负责平滑曲线，避免缩放时突然跳变；
  - `betting_table_theme_report()` 暴露 `projection_contract` 和 `projection_policy`，方便后续测试和接手开发。
- 继续强化“星球在赌桌中央”的表现：
  - 拉远时仍沿用绿色赌桌底纹、圆形金色桌边、桌边筹码和座位光点；
  - 投影背景会随着拉远逐渐出现星球暗面与蓝色边缘；
  - 背面区域和区域标签在过渡后段逐步淡出，减少球体边缘文字拥挤。
- 玩家提示改为短句：
  - `局部地表｜滚轮拉远看星球｜拖拽平移｜双击区域看牌`
  - `拉远中｜地表牌板正在卷成星球`
  - `星球全景｜滚轮贴近｜拖拽旋转｜圆点=在场单位`
- `tests/visual_snapshot.gd` 扩展为同时读取 `scripts/map_view.gd`：
  - 检查 `PlanetProjectionBlend`、平滑函数、远侧淡出函数；
  - 检查玩家提示不回退到“真实球面投影 / XY坐标”等技术说明；
  - 检查赌桌报告暴露中央星球投影策略。

### 设计意图

- 玩家不需要理解投影数学，只需要感觉地图像一张铺在赌桌上的星球牌板：贴近时能操作区域，拉远时自然成为中央星球。
- 拉远过程应该服务桌游感和可读性，而不是暴露技术切换。
- 这为后续有头视觉测试、星球动画和更精致的 Terraforming Mars 式中央板面继续铺路。

### 验证

- `tests/visual_snapshot.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。

## 2026-07-01｜玩家文案重设计：开发语言退场，牌桌语言上桌

### 本轮实现

- 继续按“电子桌游 / Terraforming Mars 式信息分层”收口玩家可见文本：
  - 规则页改成 `牌桌规则`，每条用图标开头：`◆ 首召怪兽`、`▣ 建城赚钱`、`◇ 商品商路`、`＋ 区域牌架`、`◎ 匿名出牌`、`♠ 怪兽赌局` 等；
  - 去掉规则页中的说明书式长句，保留玩家马上能决策的动作、成本、匿名信息和终局目标；
  - 商品图鉴开头从长段说明改成 `商品目录｜第X/Y页｜本页A×B`，直接看价格、供需、趋势和主打法；
  - 怪兽生态开头改成 `怪兽生态｜第X/Y页｜本页A×B`，直接看画像、速度、偏好、行动概率和招式；
  - 卡牌路线页从“路线总览/对策/样例”等开发味较重的表述，收成“牌路总览 / 打法 / 防法 / 牌例”。
- 清除主脚本里的明显开发口吻：
  - 不再把“临时美工”显示给玩家，怪兽画像副标题改成有风格的档案名，如“瘴气古龙｜海雾巢”“高速机兵｜轨道坠星”；
  - 商品页不再写“机制钩子”，改为“牌路连接”；
  - 经济总览中的“操作提示”改为更轻的“快捷”短句；
  - 怪兽内部审计文本也同步改成“画像档案 / 经济牌路”，避免未来误露到玩家页面。
- `tests/ui_text_smoke_test.gd` 增加文本护栏：
  - 要求规则页出现图标化规则短句；
  - 要求商品/怪兽图鉴使用“商品目录 / 画像 / 牌路连接”等玩家词；
  - 禁止主脚本重新出现“临时美工 / 机制钩子 / 当前缩略图布局 / 操作提示”等开发式常驻文案。
- `tests/smoke_test.gd` 同步新文案期望：
  - 怪兽生态、商品图鉴、卡牌牌路总览不再依赖旧长说明；
  - 保留分页、悬停预览、双击详情和本地图鉴导航的行为断言。

### 设计意图

- 开发面向的字段、平衡原则和测试审计可以存在，但不能直接出现在玩家桌面。
- 玩家第一眼应该读到“这张牌/这个商品/这个怪兽现在对我有什么用”，而不是读到开发历史和系统架构。
- 图标不是装饰：它们要成为未来卡牌成本、类型、目标、收益、风险的视觉语言基础。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- 完整 `tests/smoke_test.gd` 已尝试运行，但 180 秒超时，未计为通过；本轮只声明轻量文本/视觉/加载检查绿色。

## 2026-07-01｜视觉回归护栏：截图脚本改为快速布局合同

### 本轮实现

- 重建 `tests/visual_snapshot.gd`：
  - 不再在 headless 环境里实例化完整主场景并截图；
  - 改为快速读取 `scripts/main.gd`，检查主桌视觉布局合同；
  - 避免旧截图脚本被 `_new_game`、真实 `_process`、headless 渲染或强制绘制拖到超时。
- 新视觉合同覆盖：
  - 主标题与地图面板保留“星球赌桌”主题；
  - 地图提示保留“星球保持主视野”；
  - 主地图最小高度保持 `560×430`；
  - 匿名卡牌轨道保持紧凑高度 `66px`，详情走 hover/单击/双击；
  - 玩家区保持“桌边牌架”；
  - compact 手牌卡保持 `170×198`；
  - 手牌横向牌架保留 `206px` 高度；
  - 手牌必须在桌边行动托盘之前；
  - 选区动作与报价控件必须在行动托盘中；
  - 玩家文案继续使用“资料大厅 / 价格带”，不回退到“价格梯度”。

### 设计意图

- 当前最重要的是稳定保护“电子桌游桌面结构”，而不是让不稳定的 headless 截图工具拖慢开发。
- 视觉合同不是最终美术验收；它是防止 UI 架构回退的快速护栏。
- 后续如果需要真实截图，应单独做一个有头/浏览器式视觉回归脚本，不让它承担 smoke gate。

### 验证

- `tests/visual_snapshot.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。

## 2026-07-01｜区域牌架筹码化：先扫资格，再看卡面

### 本轮实现

- 区域补给窗口继续改名和收口为“区域牌架”：
  - 标题使用 `区域牌架｜区域名`；
  - 顶部说明压成 `hover预览｜双击/按钮购买｜单窗口锁定`；
  - 详细规则移到 tooltip，保留“打开时锁定价格和购买资格”的关键信息。
- 新增 `district_supply_chip_row`，在区域牌架顶部显示桌游式状态筹码：
  - `牌架 N`
  - `可购买 / 仅浏览`
  - `怪兽脚下 8折 / 相邻 原价 / 远程补给 / 全局采购 / 无怪兽范围`
  - `价格已锁`
  - `单窗口`
  - 本区商品短码。
- 区域牌列表行加入卡牌类别图标：
  - 例如 `◆ 怪兽牌`、`▣ 经营牌`、`◇ 商品牌` 等语义继续沿用统一卡牌图标层。
- 测试同步：
  - smoke 不再要求旧的“区域市场/锁定查看”长文本；
  - 改为验证区域牌架短提示、筹码行、价格锁定、可购买/仅浏览状态；
  - `ui_text_smoke_test.gd` 与 `visual_snapshot.gd` 都增加区域牌架筹码护栏。

### 设计意图

- 双击区域看牌是测试者最常用的动作之一，它应该像打开一排桌游卡槽，而不是打开后台列表。
- 玩家需要第一眼知道：
  - 这区有几张牌；
  - 我现在能不能买；
  - 为什么能/不能买；
  - 价格是否已经锁住；
  - 这里有什么本地商品。
- 长解释依然保留，但放进 tooltip，不常驻占据主视野。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。

## 2026-07-01｜子页面导航收口：每页只显示相关操作

### 本轮实现

- `_show_menu()` 不再无条件显示“继续游戏”：
  - 只有根菜单/暂停菜单这类主入口页面会显示全局继续；
  - 普通子页面默认只显示返回路径和本页操作。
- 主菜单只有已经存在进行中对局时才显示“继续游戏”，避免初始空局出现无意义按钮。
- 新增 `_hide_global_menu_navigation_for_catalog()`：
  - 图鉴类页面隐藏全局“继续游戏”和“返回主菜单”；
  - 只保留图鉴本地的“返回图鉴 / 返回缩略图 / 上一个 / 下一个”。
- 覆盖到：
  - 图鉴总入口；
  - 角色图鉴；
  - 怪兽生态档案；
  - 卡牌图鉴；
  - 商品图鉴；
  - 区域图鉴；
  - 空图鉴页。
- smoke 测试同步：
  - 新手引导/规则页不再要求显示全局继续按钮；
  - 卡牌图鉴缩略图和详情页明确要求隐藏全局继续/返回，只保留图鉴本地导航。

### 设计意图

- 子页面不能像主菜单一样把所有入口都摆在顶部；玩家进入图鉴或规则页时，只应该看到这个页面能用的操作。
- 这直接回应“图鉴页不该出现开局、继续游戏等无关按钮”的 UI 问题。
- 参考电子桌游：主菜单负责分支入口，子页面负责当前资料阅读和局部返回，不混用。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。

## 2026-07-01｜玩家文本二次收口：开发口吻留在文档，桌面只留可决策信息

### 本轮实现

- 继续清理玩家可见文本：
  - “统一资料库”改为“资料大厅”；
  - “价格梯度”改为更玩家化的“价格带”；
  - “AI对手/AI数量/测试阶段重测”等菜单口吻改为“电脑对手/对手数量/再开一桌”；
  - “统一决策面板/可复用UI”改为“桌边决策”；
  - 终局速览不再写“对手内部计划”，改为“隐藏身份与私密手牌仍靠推理”。
- 角色图鉴进一步压缩成卡面式文本：
  - `特征`
  - `被动`
  - `背景`
  - `开局`
  - 明确角色公开、首召怪兽独立选择，避免给玩家暗示角色绑定怪兽。
- 开局准备页重写为短段落：
  - 设置席位、电脑对手和挑战层级；
  - 选择公开角色；
  - 独立选择 I 级首召怪兽；
  - 进桌后先召怪兽才能从附近买牌。
- `tests/ui_text_smoke_test.gd` 改成真正轻量的玩家文本护栏：
  - 不再实例化完整主场景，避免 UI 文案测试拖入整局启动循环；
  - 直接检查 `scripts/main.gd` 中的关键玩家文案、图标化区块和禁止回归的开发口吻。

### 设计意图

- 游戏内文本必须默认面向玩家，不复述开发过程、规则废案或 AI 内部实现。
- 信息分层继续参考《Terraforming Mars》电子版：
  - 第一眼：中央星球、图标、短标签、筹码化资源；
  - hover/缩略图：短预览；
  - 双击详情：卡面式分区；
  - 长规则：收进规则/图鉴/经济总览。
- 后续新增功能时，先写“玩家看到的一句话”，再写开发字段和测试断言。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。

## 2026-07-01｜主桌信息层级：手牌前置，操作提示后置

### 本轮实现

- 调整主游戏面板顺序：
  - 顶部仍是席位/玩家状态；
  - 其后立即显示“玩家板｜资源筹码”；
  - 再显示“我的手牌”横向牌架；
  - 选区动作、开局提示、私密弃牌、怪兽赌局、竞价、竞猜、合约回应和目标选择全部放到手牌之后。
- 新增 `_add_player_hand_rack()`，把手牌牌架从 `_refresh_player_panel()` 中抽成独立层，后续可以继续改成更像电子桌游底部手牌栏。
- 压缩 compact 卡面：
  - compact 卡尺寸从 178×220 调整为 170×198；
  - compact 卡美术区变矮；
  - 手牌状态不再额外占一整行，改进入卡牌 tooltip 与行动按钮；
  - 手牌横向滚动区提高到 206px，减少底部行动按钮被裁掉的风险。
- `tests/ui_text_smoke_test.gd` 新增源码顺序护栏：
  - 手札牌架必须出现在选区动作面板之前，防止后续 UI 迭代又把手牌挤到一堆提示后面。

### 设计意图

- 主桌要优先像电子桌游，而不是后台面板：
  - 玩家第一眼看星球和手牌；
  - 第二眼看资源筹码和匿名牌轨；
  - 具体操作、竞猜、竞价、合约和弃牌作为“桌边决策”出现在手牌后面。
- 这比单纯缩小文字更重要：信息顺序本身就是 UI 设计。手牌如果被动作提示挤到后面，人类测试者会自然觉得“我根本看不到自己在玩什么牌”。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。

## 2026-07-01｜桌边行动托盘：复杂操作收纳，不抢星球和手牌

### 本轮实现

- 新增 `_add_player_action_tray()`：
  - 固定高度的“桌边行动托盘”；
  - 内部使用垂直滚动；
  - 收纳选区动作、开局提示、私密弃牌、怪兽赌局、出牌报价、牌主竞猜、目标选择和合约回应。
- `_refresh_player_panel()` 的信息层级现在是：
  1. 席位与玩家状态；
  2. 资源筹码；
  3. 快速目标提示；
  4. 我的手牌；
  5. 桌边行动托盘。
- 托盘 header 用短标签提示：“选区｜竞价｜竞猜｜合约｜目标”，避免把完整规则常驻在主桌上。
- `tests/ui_text_smoke_test.gd` 新增护栏：
  - 手牌必须在行动托盘之前；
  - 二级操作必须进入 `action_tray`；
  - 源码必须保留“避免遮住星球与手牌”的托盘意图。

### 设计意图

- 这个游戏的规则很复杂，但主桌不应该像调试面板。
- 玩家第一眼必须看到：
  - 中央星球；
  - 匿名牌轨；
  - 自己的资源；
  - 自己的手牌。
- 竞价、竞猜、合约、弃牌、目标选择都很重要，但它们是“当前动作”，不是常驻主信息。把它们收进托盘，更接近电子桌游的底部操作栏/侧边托盘。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。

## 2026-07-01｜卡牌图标语义层：先扫符号，再读详情

### 本轮实现

- 新增统一卡牌图标语义：
  - `◆` 怪兽；
  - `✦` 兽技；
  - `⚔` 军队；
  - `◎` 玩家互动；
  - `▣` 城市；
  - `◇` 商品；
  - `△` 期货；
  - `¥` 金融；
  - `⇄` 合约；
  - `◉` 情报；
  - `◌` 新闻；
  - `☄` 天气；
  - `＋` 补给。
- 将图标接入主要玩家可见位置：
  - 卡牌图鉴筛选按钮；
  - 卡牌图鉴图标说明行；
  - 卡牌缩略图标题；
  - 卡牌详情页的牌型/路线行；
  - 手牌卡面标题与类型行；
  - 卡牌 tooltip。
- 卡牌详情页标题也改成更像 TCG/电子桌游的短区块：
  - `◎ 牌面定位`
  - `¥ 费用与门槛`
  - `✦ 核心效果`
  - `◈ 关键数值`
  - `＋ 本局投放`
  - `◇ 结算演出`
- 扩展程序卡面的大字 glyph 和基础图案：
  - 军队、军令、相位响应、拆/牵牌、GDP衍生品、商品期货、合约、新闻、天气、情报等不再都落到默认“卡”；
  - 金融/期货更像走势图，合约更像路线，新闻/情报更像信号，天气更像波纹。

### 设计意图

- 这一步是向《Terraforming Mars》电子版学习信息层级：玩家先看图标和短码，再看卡名、数值，最后才读详情。
- 现在仍是临时符号，不是最终 UI 美术；但它先建立稳定语义，后续换正式 icon 时不会重新设计规则结构。
- 对测试者来说，牌多起来以后“能不能一眼区分牌型”比长文案更重要。

### 验证

- `tests/ui_text_smoke_test.gd` 通过，覆盖：
  - 卡牌图鉴存在稳定图标说明；
  - 卡牌详情页使用图标化区块标题；
  - 玩家界面继续避免“关键字段”等开发术语。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。

## 2026-07-01｜玩家文案重构：开发说明不进游戏界面

### 本轮实现

- 建立“玩家版卡牌效果”展示层：
  - 底层卡牌仍保留 AI、字段、强度预算和测试所需数据；
  - 玩家看到的是短效果、关键数值、费用/门槛和目标信息；
  - 合约、怪兽、军队、期货、天气、相位响应、直接互动等牌型优先走专门短文案。
- 重写规则页和新手引导：
  - 不再写“当前原型规则”“AI训练骨架”“新规则下不再……”等开发历史；
  - 改成玩家手册式条目：目标、首召、建城、商品、买牌、手牌、匿名出牌、竞价、怪兽、赌局、合约、天气、终局；
  - 常用操作只保留玩家能马上用到的入口。
- 清理图鉴和菜单文案：
  - “关键字段”改成“关键数值”；
  - “图鉴全集/三层牌池”等偏开发表达改为“全部卡牌/牌库来源”；
  - 主菜单、暂停菜单、存档、复盘文本去掉“调试、原型、内部决策、对手计划”等不该给玩家看的词。
- 终局复盘改为“公开线索”：
  - 只显示已经发生的卡牌、城市GDP、商路、怪兽和情报结果；
  - AI路线、压力桶、候选评分和内部计划继续作为隐藏开发数据，不进入玩家界面。

### 设计意图

- 玩家界面要像电子桌游：先用卡面、短标签、数值块和 hover 组织信息；长说明收进资料页。
- 你给我的很多内容是开发方向，不等于玩家文案。后续新增规则时，必须先判断它属于“玩家要知道”还是“开发/AI要知道”。
- 参考《Terraforming Mars》电子版的思路：地图和卡面承担第一层信息，详情页和 tooltip 承担第二层信息，开发理由不直接出现。

### 验证

- Godot `--check-only` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- smoke test 断言已同步：
  - 规则页不能出现开发历史/AI训练语气；
  - 卡牌详情使用“关键数值”而非“关键字段”；
  - 经济/局势/终局复盘隐藏 AI 内部计划，只展示公开线索。

## 2026-07-01｜星球赌桌地图美术：桌毡、金边与筹码环

### 本轮实现

- 将赌桌氛围从外层面板推进到地图绘制层：
  - 地图背景改成深绿色桌毡；
  - 中央星球周围增加金色桌边/下注环；
  - 地图边缘增加小筹码与席位光圈；
  - 平面视图、投影过渡和球面视图都共用同一套赌桌底层视觉。
- 保持“星球在中央”的核心约束：
  - 赌桌视觉以 `_globe_center()` 为中心；
  - 筹码和席位只在边缘做小图标，不抢地图和手牌视线；
  - 详情仍通过 hover/双击/托盘展开，而不是常驻在地图上。
- 新增 `betting_table_theme_report()`，让烟测能保护这个视觉方向：
  - 桌毡颜色；
  - 金色边框；
  - 筹码数量；
  - 席位数量；
  - 中央星球策略；
  - 小图标按需展开策略。

### 设计意图

- 这局游戏应该像“围着星球下注”的电子桌游，而不是普通后台面板。
- 参考《Terraforming Mars》电子版的强中心构图：中间的星球/地图承担主要视觉叙事，牌、筹码、市场和历史轨道都应该围绕它服务。
- 赌桌元素只做气氛和空间暗示，不把规则文字重新堆回主画面。

### 验证

- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- Godot `--check-only` 通过。
- 完整 Godot headless smoke test 新增覆盖：
  - 地图脚本暴露赌桌主题报告；
  - 主题报告包含桌毡、金边、筹码环、席位环和中央星球策略。

## 2026-07-01｜星球赌桌主画面：中央大星球，周边小控件

### 本轮实现

- 根据“赌博游戏氛围”和《Terraforming Mars》式中央星球布局，调整局内主画面视觉重心：
  - 主标题改为“太空辛迪加｜星球赌桌”；
  - 地图面板改为“星球赌桌｜中央星球”；
  - 地图最小高度提高，让星球/地图成为画面主角；
  - 地图提示改为“赌桌中央：星球保持主视野｜滚轮缩放 · 拖拽地图 · 双击区域看牌”；
  - 地图面板使用更偏赌桌的深绿色底与金色边框；
  - 手牌面板改名为“桌边牌架”，并压缩高度，强调它只是桌边信息架。
- 继续压缩周边 UI：
  - 手牌滚动区高度下调；
  - 临时决策卡统一增加短标签：`私密/公开身份`、`阻塞出牌/不阻塞`；
  - 临时决策卡正文自动短化，长说明进入 tooltip；
  - 临时决策按钮改成小型网格，避免一行按钮挤占主画面。
- 修复市场锁定后的内部快照同步：
  - 当区域市场仍然打开时，内部重新打开购牌快照会同步锁定区域和玩家；
  - 避免测试或内部逻辑出现“UI显示一个区域、快照记录另一个区域”的状态残留。

### 设计意图

- 这个游戏的桌面气质应该像“围着一颗星球下注、操控、推理”的赌桌，而不是普通策略游戏的管理后台。
- 中央星球要一直是视觉中心；手牌、牌轨、市场、决策都应成为桌边筹码/卡托盘，只有点击详情时才展开。
- 临时窗口不能像弹窗一样压住星球，而应该像桌边短决策卡：一眼看见要做什么，长规则按需 hover。

### 验证

- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- 完整 Godot headless smoke test 通过，并新增覆盖：
  - 主画面保持“星球赌桌/赌桌中央”的大地图焦点；
  - 手牌区域作为“桌边牌架”；
  - 临时决策 blueprint 暴露隐私/阻塞短标签和网格按钮列数；
  - 私密弃牌面板实际渲染“决策｜私密弃牌确认”“私密”“不阻塞”。

## 2026-07-01｜区域市场锁定托盘：浏览地图时不丢购牌窗口

### 本轮实现

- 将区域市场窗口进一步改成右侧锁定托盘：
  - 标题显示“锁定查看｜区域名”；
  - 顶部说明“区域市场 N 张｜可购买/仅浏览｜资格来源”；
  - 明确提示“单击地图不会关闭；双击其他区域可切换市场”；
  - 遮罩和窗口高度略收敛，减少对地图的压迫感。
- 修复市场打开后的区域上下文：
  - 单击其他地图区域不再自动关闭市场；
  - hover 预览按“市场锁定区域”判断卡牌是否合法；
  - 双击市场卡牌/点击购买时，也从“市场锁定区域”购买，而不是误用玩家后来单击到的 `selected_district`。
- 保留原有规则：
  - 查看总是允许；
  - 购买资格仍按打开市场的一刻锁定；
  - 同时只能有一个区域市场窗口；
  - 手牌满时仍进入私密弃牌流程。

### 设计意图

- 玩家打开市场后，经常会顺手点地图看怪兽、城市和商路。如果窗口因为普通单击直接消失，会很像 UI bug。
- 参考桌游电子版的“右侧市场/项目托盘”：打开后保持稳定，玩家主动关闭或切换目标时才变化。
- 这一步提升的是操作信任感：玩家知道自己正在看哪一个区域的牌，也知道购买按钮不会因为地图选区变化而买错地方。

### 验证

- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- 完整 Godot headless smoke test 通过，并新增覆盖：
  - 区域市场解释锁定托盘、hover 和购买方式；
  - 打开市场后单击其他区域，市场仍锁定在原区域；
  - 双击市场卡牌仍能从锁定区域购买/升级并记录支出。

## 2026-07-01｜匿名牌轨与结算公告压缩：地图回到主视野

### 本轮实现

- 将顶部匿名卡牌轨道进一步压缩成电子桌游式时间轴：
  - 每张轨道牌只常驻显示两行：状态/卡名 + 匿名/小费/公开归属；
  - 详细效果、目标、条件、演出和竞价线索移入 hover tooltip；
  - 保留单击竞猜归属、双击打开卡牌图鉴详情的交互。
- 将右上角公开结算公告从“大卡片弹窗”压成短公告卡：
  - 降低遮罩透明度和占屏高度；
  - 缩小卡面展示高度；
  - 正文限制为一到两行短摘要；
  - 长效果、合约、条件、目标和竞价说明转入 hover 详情。
- 阶段状态文案同步压缩：
  - 保留“匿名竞价 / 同时判定 / 公开展示 / 相位响应”等核心阶段；
  - 保留“最高公开报价、可加价、新牌进入下一批等待”等关键决策信号；
  - 删除常驻重复信息，避免公告像规则说明书一样铺开。

### 设计意图

- 局内主角应该是地图、手牌和玩家当前决策，而不是一直压在右上角的长公告。
- 参考《Terraforming Mars》等桌游电子版的常驻信息层级：时间线短、当前动作短、详情按需 hover 或点开。
- 匿名牌轨仍然承担推理功能，但玩家不用在战斗/购牌/建城时被长文本打断。

### 验证

- 完整 Godot headless smoke test 通过，并新增覆盖：
  - 匿名牌轨保持紧凑，同时 hover 保留详情和双击图鉴入口；
  - 公开结算公告保持短正文，长详情进入 hover；
  - 原有匿名竞价、相位响应、归属竞猜、线索保留等流程继续通过。

## 2026-07-01｜手牌可打出状态：减少试错和弹窗依赖

### 本轮实现

- 将局内手牌卡面接入统一的可打出状态判断：
  - `可打出`：满足当前商品流动、资金和窗口条件；
  - `需商品 / 资金不足 / 部署限制 / 无目标 / 需合约`：直接说明卡住原因；
  - `需怪兽目标 / 需玩家目标`：明确点击后进入目标选择；
  - `排队中 / 冷却中 / 赌局暂停 / 先选目标`：解释当前全局或临时窗口限制。
- 手牌按钮不再只是“打出/不可点”，而是跟随状态显示“打出、释放、选目标、相位否决、排队中”等短文本。
- 手牌按钮 tooltip 显示简短状态说明和“打出条件”，玩家不用反复点错或去长规则里找条件。
- 状态颜色接入现有按钮样式：
  - 绿色代表可立即执行；
  - 黄色代表等待、冷却或缺条件；
  - 红色代表明显资源不足或封锁；
  - 蓝色代表下一步要选择目标；
  - 紫色代表相位否决响应。

### 设计意图

- 参考电子桌游和卡牌游戏的手牌区设计：玩家扫一眼手牌，就应该知道“哪张能打、为什么打不了、打了以后要做什么”。
- 把解释放在卡面状态和 hover tooltip 中，减少常驻长文，也减少无效弹窗。
- 这一步对测试者上手非常关键：同一张卡可能因为商品流动、资金、目标、赌局冻结、相位响应窗口而状态不同，UI 必须替规则承担解释工作。

### 验证

- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- 完整 Godot headless smoke test 通过，并新增覆盖：
  - 手牌卡面显示“状态：...”；
  - 手牌按钮 tooltip 暴露“打出条件”。

## 2026-07-01｜区域市场牌列：让买牌窗口更像电子桌游市场

### 本轮实现

- 将区域补给窗口从普通列表进一步改成“区域市场”牌列：
  - 标题显示“区域市场”；
  - 顶部说明市场牌列数量、当前窗口是“可购买”还是“仅浏览”、锁定的怪兽范围资格；
  - 每张区域牌以两行小卡条展示：卡名/价格/购买状态 + 路线/关键效果。
- 新增统一状态判断 `_district_supply_purchase_state()`：
  - `可购买`：资金、范围、手牌接收条件都满足；
  - `仅浏览`：不在怪兽落地/相邻/扩展补给范围内；
  - `资金不足`：范围满足但钱不够；
  - `需弃牌`：手牌已满但可进入私密弃牌流程；
  - `无法接收`：可能已到IV级或没有可弃掉的普通手牌；
  - `区域无效 / 未投放 / 已结束` 等边界状态。
- 预览区同步显示选中牌的购买结论、价格和原因；购买按钮在“需弃牌”时仍可点击，并会进入私密弃牌确认。
- 区域市场继续保持“查看总是允许”：不可购买时仍可 hover、点选、看卡面和效果，只有购买行为受锁定资格影响。
- smoke test 增加区域市场 UI 覆盖：
  - 打开区域市场 overlay；
  - 检查市场牌列说明；
  - 检查牌行显示价格和购买状态；
  - 检查预览区有购买结论和“查看总是允许”的提示。

### 设计意图

- 真人测试者不应该靠读长规则判断能不能买牌；窗口本身要一眼告诉他“能买/只能看/差钱/要弃牌”。
- 这一步继续参考电子桌游的市场牌列：卡牌可以被查看，购买条件用短标签和颜色表达，详细规则留到 tooltip 和图鉴。
- 后续可以把每张市场牌条替换成更完整的小卡面缩略图，但当前先保证信息层级和操作语义正确。

### 验证

- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜公开席位条：增强桌游对手存在感

### 本轮实现

- 将局内玩家选择从纯名字按钮升级为“公开席位”横向条，更接近电子桌游桌面上的玩家席位区：
  - 每个席位显示 P 编号、人类/AI、公开外星身份名；
  - 显示当前视角可知的城市/怪兽/军队概况；
  - 点击席位仍可切换当前查看玩家。
- 隐私规则在 UI 上做了保守处理：
  - 当前视角玩家显示“己城N”；
  - 其他玩家不直接显示真实城市数量，只显示玩家自己私人标注出的“疑城N”，否则显示“城?”；
  - 怪兽只统计已公开归属的怪兽，或当前视角玩家自己的怪兽；
  - 军队只统计已公开归属的军队，或当前视角玩家自己的军队；
  - tooltip 只提醒“现金、手牌和弃牌不公开”，不展示 AI 路线、压力桶或训练数据。
- smoke test 新增“公开席位”覆盖，防止后续 UI 回退成缺少对手存在感的纯手牌面板。

### 设计意图

- 真人试玩时必须感觉自己不是在看一张孤立地图，而是在和多个席位共同打一局桌游。
- 席位条要提供“桌面感”和快速方位感，但不能破坏城市业主、怪兽归属、现金和手牌隐私。
- 后续可以继续把席位条做得更精美：头像、公开身份卡小图标、近期公开动作徽章、竞猜标记，但仍要保持隐私边界。

### 验证

- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜Terraforming Mars 式当前区域操作卡

### 本轮实现

- 明确把《Terraforming Mars》这类电子桌游作为主菜单、局内 UI、卡牌浏览和游戏流程的核心参考方向，但玩家文案仍保持《太空辛迪加》自己的科幻世界观。
- 局内“手牌与行动”面板新增“当前区域”操作卡：
  - 显示选区地形、城市状态、GDP/min、当前天气、生产/需求商品和区域补给资格；
  - 提供高频动作按钮：城市化、查看牌、标注、商路、全屏；
  - “查看牌”明确支持不可购买时也能浏览，购买资格仍按打开区域牌窗的一刻锁定。
- 地图顶部工具栏进一步压缩：
  - 旧的城市化、标注、身份侦测、商路开关按钮移出顶部工具栏；
  - 顶部只保留地图操作提示、选区摘要、双击区域看牌提示、商路商品选择、合约供需端和全屏入口；
  - 让主要地图动作集中到当前区域操作卡，避免按钮横排堆积。
- smoke test 新增断言，确保玩家面板始终暴露桌游式“当前区域”操作卡。
- 加强购牌折扣 smoke 的状态隔离：测试怪兽落地区八折/相邻区原价前，会清理 game_over、弃牌购买、区域补给窗口和购买快照，避免前置竞价/赌局/菜单测试污染规则验证。

### 设计意图

- 玩家应该像玩电子化桌游一样：先看地图，点一个区域，再在一个稳定的小面板里决定“这里能做什么”。
- 常驻 UI 只放行动入口和短状态；规则解释、图鉴、经济拆解、情报整理继续收纳到菜单分支。
- 后续 UI 优化继续沿这个方向：卡牌像 TCG 牌面，区域像桌面板块，菜单像桌游大厅，临时决策窗口像统一弹出的桌游交互模块。

### 验证

- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜电子桌游式人类试玩 UI 收敛

### 本轮实现

- 以《Terraforming Mars》这类电子桌游的信息层级为参考，重新收紧局内画面：
  - 地图继续占据主视觉；
  - 顶部匿名卡牌轨道改成更矮的时间轴，hover 看详情，单击用于猜归属，双击跳到卡牌图鉴详情；
  - 出牌公开展示从居中大遮罩改成右上紧凑公告卡，仍保留公开卡面、匿名归属、小费/队列和条件线索；
  - 底部玩家区改成“手牌与行动”，显示“我的手牌 x/5”和五格手牌架感，固定技能/弃牌隐私放进 tooltip。
- 区域补给交互统一成“信息可看，购买看资格”：
  - 双击地图区域打开区域补给面板；
  - 即使当前没有怪兽范围资格，也能浏览该区域卡牌；
  - 购买资格和价格只按打开窗口瞬间锁定；
  - 同一玩家仍只保留一个区域补给窗口，避免沿路囤多个购买机会。
- 卡牌图鉴进一步 TCG 化：
  - 缩略图页只显示本局牌池、区域补给数量和 hover/双击操作；
  - 路线总览改成玩家能理解的“打法/对策”，不再把强度预算、支点、AI 覆盖等内部审计词铺在玩家页面；
  - 详情页保留卡面、费用门槛、核心效果、关键字段、I-IV 梯度和结算演出。
- 主菜单正文压缩为一句玩法、一句胜利目标和入口提示；规则细节继续收纳到“游戏规则”分支。子页面隐藏全局快捷导航，只保留该页面需要的返回/继续/翻页。
- 军队和怪兽诱导 smoke 调整到线性移动语义：命令发出后按米/秒推进，到达后再验证 GDP 压力、诱导效果和不造成怪兽式碾压。

### 设计意图

- 当前目标不是继续堆系统，而是让真人测试者第一眼能玩：像桌游桌面一样先看地图、手牌、牌轨和当前区域，再用 hover/详情页读复杂规则。
- 玩家界面不展示 AI 压力桶、路线审计、强度预算分和开发历史；这些继续留在文档、测试和内部函数里。
- 区域牌表是公开信息，购买才是经济动作；这能减少“怪兽刚离开窗口就失效”的反直觉体验。

### 验证

- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 路线可达性审计

### 本轮实现

- 新增 `_ai_route_viability_report()` 和 `_ai_route_viability_summary()`，把已有的三类 AI 路线审计串起来：
  - 静态路线压力：卡池是否有钱、压制、防御、情报、门槛和公开线索；
  - 实战路线样本：AI 是否在八席模拟里真的产生路线行动；
  - 性格偏好：是否有 AI profile 把该路线当作主路线或可偏好路线。
- 新增 `_ai_sample_viability_entry()`，把真实 AI 决策样本转成路线可达性字段，统计：
  - money / disruption / protection / intel-supply 压力；
  - gate / public clue 可读性；
  - 真实样本分数、路线压力和涉及 AI 数量。
- 八席 smoke 现在要求至少 5 条核心路线在当前模拟和卡牌结构里是“可追目标”，并报告缺失路线。

### 设计意图

- 这一步不是另起一个新目标，而是继续推进十小时目标中的“AI 至少能有四五种发展策略，都能够追逐最高目标”。
- 审计不要求每局所有路线都同样强；roguelike 地图、商品和怪兽不同，本来就应该让路线强弱变化。
- 但它要求开发侧能证明：AI 不会只剩单一最优路线，至少多条路线具备收益或破坏路径、可读门槛、公开反推线索和 AI 偏好支撑。
- 该报告仍是内部平衡工具，不进入玩家 UI；玩家只看到公开结果，不看到 AI 的路线桶和评分。

### 新增验证

- `_verify_max_ai_seat_complete_smoke()` 新增 AI 路线可达性检查：
  - `viable_required_route_count` 必须达到最低要求；
  - 不应存在缺失的核心路线；
  - 失败时输出 `_ai_route_viability_summary()`，方便继续平衡卡牌和 AI 评分。

## 2026-07-01｜卡牌图鉴牌池层级标识

### 本轮实现

- 新增卡牌层级辅助函数，按当前对局状态为每张卡标出：
  - `图鉴全集`：能查看规则/卡面，但本局未必出现；
  - `本局星球牌池`：符合当前星球商品、地形或怪兽生态，可能被投放；
  - `区域补给`：已经进入地图区域候选，玩家打开符合怪兽范围的购买窗口后可购买。
- 卡牌图鉴正文、TCG详情面板和 hover tooltip 都显示“牌池层”，并给出投放说明。
- 怪兽牌继续作为卡牌图鉴内的一个分类存在；怪兽生态档案只负责生态、行动概率、资源偏好和关联怪兽牌跳转。

### 设计意图

- 玩家不需要理解开发侧变量名，例如 `skill_market`；界面只使用“图鉴全集 / 本局星球牌池 / 区域补给”三层表达。
- 区域补给仍然是实际购买入口；图鉴全集不是商店，本局星球牌池也不是随时可买清单。
- II-IV 牌详情会沿用同系列 I 级基础牌的区域投放逻辑，符合“重复获得自动升级”的规则。

### 新增验证

- 卡牌图鉴统一分类 smoke 现在额外验证：
  - 卡牌详情文本含有牌池层；
  - 任意区域候选卡会被识别为 `区域补给`；
  - 区域卡 hover tooltip 会显示 `牌池层：区域补给`。

## 2026-07-01｜AI 终局竞速评分层

### 本轮实现

- 新增 `_ai_victory_race_bonus_for_candidate()`，让 AI 在现金目标、终局倒计时和领先/落后局势下更像是在争胜，而不是继续按中局节奏经营。
- 终局竞速会给候选动作标记内部角色：
  - `break_countdown`：别人触发倒计时或明显领先时，优先破坏领先者城市、GDP、商路或做空；
  - `protect_lead`：自己领先或接近目标时，优先保护城市、修复/保险、锁定现金；
  - `last_push`：自己落后但仍有机会时，更愿意用金融、做空、破坏和现金补口追分；
  - `race_to_goal`：多人接近目标但未定胜负时，兼顾护住收益和压制领先线。
- 这层评分已接入四个真实 AI 入口：
  - 自动城市化；
  - 匿名商业行动；
  - 区域购牌；
  - 匿名出牌。
- 决策样本新增隐藏字段：
  - `victory_race_bonus`
  - `victory_race_role`
  - `victory_race_reason`

### 平衡与 AI 决策

- 终局竞速不是独立脚本，也不强制 AI 做固定动作；它只是在商品路线、阶段策略、性格签名、学习层和卡牌字段评分之上叠加“争胜压力”。
- 加成会 clamp 到中等偏高范围，目的是让终局更有攻击性和保护意识，但不让 AI 无视商品流动、费用、目标归属或卡牌可打出条件。
- 这些字段只用于开发侧训练、烟测和平衡审计；玩家仍然只能通过公开结果、匿名卡牌轨道、经济变化、下注/合约等线索推理 AI 行为。

### 新增验证

- AI 阶段策略 smoke 现在额外验证：
  - 倒计时中落后 AI 会进入 `break_countdown`，并把商路破坏/做空类动作推高；
  - 领先 AI 会进入 `protect_lead`，并把灾害保单/保护类动作推高；
  - `victory_race_*` 字段会进入 AI 决策样本，继续保持内部隐藏。

## 2026-07-01｜AI 性格签名行动偏置

### 本轮实现

- 新增 AI 性格签名评分层，让 AI 差异化进入真实决策，而不只是事后审计：
  - `_ai_development_route_for_kind()`：把建城、合约、金融、怪兽、情报、直接互动、军队等行动映射到 development-route；
  - `_ai_policy_family_for_kind()`：把候选动作归入行动族；
  - `_ai_profile_signature_bonus_for_candidate()`：根据 AI 的 `route_preferences`、行动族、签名行动族、商品焦点和目标归属给出中等强度偏置。
- 签名偏置已接入四类真实 AI 决策入口：
  - 自动城市化；
  - 匿名商业行动；
  - 匿名出牌；
  - 区域购牌。
- 训练样本和候选视图新增内部字段：
  - `profile_signature_bonus`
  - `profile_signature_family`
  - `profile_signature_route`
  - `profile_signature_reason`

### 平衡与 AI 决策

- 这层偏置不是强制脚本，而是局势评分、商品路线、阶段策略、卡牌字段、学习层之外的“性格倾向”：
  - 拓荒型更愿意吃城市成长和城市化；
  - 套利型更容易靠近金融投机/商品经营；
  - 破坏型更容易选择怪兽压制、直接互动、商路破坏；
  - 驯怪型更容易补怪兽压力相关牌和动作；
  - 合约型更容易靠近合约供需；
  - 情报型更容易靠近情报/补给。
- 偏置被 clamp 到中等区间，避免 AI 无视局势；它应该强化“像某种对手”，不是替代策略判断。
- 所有签名偏置字段仍是内部训练/测试数据，玩家界面不显示 AI 的路线桶或评分。

### 新增验证

- 八席 smoke 的 AI 性格身份审计现在额外要求：
  - 至少 6 类 AI 性格都出现真实签名加权样本；
  - 签名加权随真实建城/购牌/出牌/商业样本进入决策记录；
  - 原有 8 席完整流程、终局、UI 隐私和 AI 隐藏数据检查继续通过。

## 2026-07-01｜AI 性格身份审计

### 本轮实现

- 新增 `_ai_profile_strategy_identity_report()`，把 6 类 AI 性格的实战样本整理成内部差异化审计：
  - 每类被实际分配到座位的 AI 是否产生决策样本；
  - 是否命中自己的主 development-route；
  - 是否出现符合路线偏好的行动族；
  - 是否有商品样本，避免路线计划和商品经济脱节；
  - 是否出现更有辨识度的签名行动族，例如城市化、合约、期货、怪兽诱导、情报、直接互动。
- 新增 `_ai_profile_strategy_identity_summary()`，用于测试失败时快速看出哪类 AI 没有体现差异。
- 审计从 `route_preferences`、`decision_samples`、`development_route`、`policy_kind` 和商品/焦点/路线字段推断，不绑定具体卡名。

### 平衡与 AI 决策

- 目标是防止 6 类 AI 最后都玩成同一种“随便买牌/随便出牌”的对手。
- 当前阶段不要求每类 AI 在一次短 smoke 中完成整套最优策略，但必须能证明：
  - 拓荒/套利/破坏/驯怪/合约/情报这几类性格都有实战身份；
  - 它们的主路线和行动族有可观察差异；
  - AI 差异化仍停留在开发侧，玩家只看到公开结果和推理线索。

### 新增验证

- 八席 smoke 新增 AI 性格身份检查：
  - 至少覆盖 6 类 AI 性格；
  - 6 类都必须具备身份样本；
  - 至少覆盖 5 类主路线；
  - 至少覆盖 4 类预期行动族；
  - 至少覆盖 3 类签名行动族。

## 2026-07-01｜AI 商品路线桥接审计

### 本轮实现

- 新增 `_ai_product_route_bridge_report()`，把 AI 的隐藏决策样本整理成内部审计报告：
  - 每个 AI 是否产生商品相关样本；
  - 样本是否带有经济焦点商品、路线计划商品和可识别的主商品；
  - AI 行动是否覆盖城市化、购牌、出牌、匿名商业、合约、期货、天气、直接互动、怪兽诱导、军队、情报等策略族；
  - 样本是否连接到 development-route 路线标签，而不是只凭卡名临时判断；
  - 明确统计商品/焦点/路线对齐样本，防止 AI 买牌、打牌和经济计划互相脱节。
- 新增 `_ai_product_route_bridge_summary()`，用于 smoke test 和开发日志快速读取，不进入玩家界面。
- 八席 smoke 在 AI 首召、建城、购牌、出牌、匿名商业、收入结算和主路线演练之后，强制调用该审计。

### 平衡与 AI 决策

- 这次审计强化的是“AI 是否真的围绕商品路线玩游戏”，而不是把更多 AI 内部信息展示给玩家。
- 审计目标是让新增卡牌继续通过字段被 AI 理解：`product`、`focus_product`、`route_plan_product`、`route_plan_stage`、`development_route`、`policy_kind`、`futures_*`、`weather_*`、`direct_*`、`contract_*` 等字段都可以进入策略判断。
- 玩家 UI 仍只展示公共结果：地图变化、商品价格、GDP 走势、匿名卡牌结果、合约结果、天气、怪兽线索、公开下注等；AI 压力桶、路线评分和训练样本保持隐藏。

### 新增验证

- smoke 新增 AI 商品路线桥接检查：
  - 所有 AI 都必须有商品样本；
  - 至少覆盖 4 种商品；
  - 至少覆盖 2 个路线阶段；
  - 至少覆盖 3 条 development-route；
  - 至少覆盖 3 类策略族；
  - 必须出现商品/焦点/路线对齐样本。

## 2026-07-01｜商品生态总览与本局商品策略入口

### 本轮实现

- 新增 `_product_ecosystem_report()`，把商品目录和本局星球商品状态整理成可审计报告：
  - 图鉴商品总数、海洋商品总数；
  - 本局出现商品数、海洋/陆地商品分布；
  - 区域生产槽、区域需求槽、城市生产槽、城市需求槽；
  - 商品路线分布、品类分布、当前主策略分布；
  - 当前策略热点商品；
  - 有固定相关卡牌的商品数量；
  - 有怪兽资源偏好的商品数量；
  - 临时美工/商品档案字段完整度。
- 商品图鉴缩略图页新增四张总览卡：
  - 本局商品生态；
  - 策略机会；
  - 商品路线分布；
  - 机制钩子。
- 商品图鉴标题区现在直接说明：本局星球出现多少商品，其中海洋/陆地商品各多少。

### 平衡与 UI 决策

- 商品不是装饰名词，而是连接 GDP、卡牌门槛、区域补给、期货、仓储、商路、怪兽目标和推理线索的核心层。
- 商品图鉴缩略图页承担“先扫本局经济格局”的任务；商品详情页继续承担单个商品的价格、供需、期货/仓储、怪兽偏好、相关卡牌和城市线索解释。
- 海洋商品必须继续保留足够存在感，让海域不只是运输地形，也能成为商品生产和金融/怪兽策略来源。

### 新增验证

- smoke 新增商品生态报告检查：
  - 商品目录不少于 40 种，海洋商品不少于 12 种；
  - 所有商品都有完整临时美工/档案字段；
  - 本局商品包含海洋与陆地分布、生产/需求槽、策略机会。
- 商品图鉴 smoke 现在检查缩略图页展示：
  - 本局商品生态；
  - 策略机会；
  - 商品路线分布；
  - 机制钩子。

## 2026-07-01｜卡牌三层牌池口径与区域补给可读性

### 本轮实现

- 新增 `_card_supply_layer_report()`，把卡牌供应拆成三个可审计层级：
  - 图鉴全集：用于学习规则和查看全部卡牌；
  - 本局星球牌池：按当前星球商品、地形和怪兽生态筛选后的本局候选；
  - 区域补给：实际投放到地图区域、玩家可通过怪兽落地/相邻/补给范围购买的候选。
- 卡牌图鉴缩略图页现在直接显示三层数量：图鉴全集、本局星球牌池、区域补给总数。
- 卡牌图鉴分类区新增玩家可读说明卡：
  - 三层牌池：展示本局商品数量、星球牌池数量、区域补给数量、已过滤不适配固定商品牌/怪兽牌数量；
  - 购买窗口锁定规则：解释点开区域补给窗口时会锁定当时的怪兽位置、补给范围和价格倍率。
- 清理玩家 UI 中“旧的普通牌池”这类开发历史口吻，改为图鉴全集/本局星球牌池/区域补给三层语言。

### 平衡与规则决策

- 玩家需要理解的是“为什么这局能买这些牌、为什么这个区域提供这些牌”，而不是理解内部常量或历史命名。
- 本局星球牌池必须继续由地图商品、地形和怪兽生态驱动；地图没有的固定商品不应把对应卡牌带入可购买区域。
- 区域补给是最终购买事实来源；图鉴只负责解释规则，不代表本局一定买得到。

### 新增验证

- smoke 新增三层牌池报告检查：
  - 图鉴全集数量不少于本局星球牌池；
  - 本局星球牌池、区域补给、区域去重补给都非空；
  - 商品/怪兽过滤没有违规项。
- 卡牌图鉴 smoke 现在检查：
  - 缩略图页显示“三层牌池 / 图鉴全集 / 本局星球牌池 / 区域补给”；
  - 分类区显示“购买窗口锁定规则”；
  - 玩家界面不再出现“旧的普通牌池”。

## 2026-07-01｜怪兽生态档案可读性与 TCG 式摘要

### 本轮实现

- 怪兽生态档案的缩略图页新增“生态速览”，把当前怪兽池的移动生态、商品偏好覆盖和行动定位数量先展示给玩家。
- 怪兽缩略图现在直接显示移动生态位和行动标签，避免玩家只能看到 HP/速度而看不出差异。
- 悬停预览新增“生态位 / 行动定位 / 固定技能成长”摘要，让玩家不用点进详情也能快速比较怪兽。
- 怪兽详情页新增四张玩家可读信息卡：
  - 生态位：移动方式、召唤限制、移动速度和地形适配；
  - 资源与经济：商品偏好、资源吸取和经济钩子；
  - 行动定位：伤害、射程、位移和功能标签；
  - 固定技能成长：I-IV 级绑定技能数量和 IV 级概率倾向。
- 继续保持怪兽牌归入卡牌图鉴；怪兽生态档案只讲怪兽行为和生态身份，不重复做怪兽牌图鉴。

### 平衡与 UI 决策

- 玩家应该能从图鉴里理解“这只怪兽为什么会去某些区域、会怎样破坏、升级后会怎么变危险”，但不应该看到 AI 路线桶、AI 评分或隐藏决策压力。
- 怪兽详情采用 TCG 式摘要卡，而不是长段落说明，后续卡牌、商品、角色详情页也应继续向这种结构靠拢。
- 图鉴缩略图页先解决“扫一眼可分辨”，详情页再解决“深入理解”；不要把所有文本挤进主游戏画面。

### 新增验证

- 完整 smoke 现在会检查：
  - 怪兽缩略图页包含生态速览、飞行/水栖/陆行覆盖和悬停预览；
  - 悬停预览展示 HP、生态位、行动定位和行动摘要；
  - 怪兽详情页展示生态位、资源与经济、行动定位和固定技能成长信息卡。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜怪兽生态差异与固定技能梯度审计

### 本轮实现

- 新增怪兽生态审计：
  - `_monster_ecology_identity_entry(index)`
  - `_monster_ecology_balance_report()`
  - `_monster_ecology_balance_summary()`
- 审计会为每只怪兽读取并汇总：
  - 移动生态位：飞行、水栖/海域、陆行或通用；
  - 商品资源偏好；
  - 经济钩子；
  - 临时美工档案；
  - 自动行动数量、早期可用行动、升级/破坏后行动；
  - 行动角色标签，例如机动、远程、伤害、高伤、控制、修复、续航、路径/场地、位移/击退、热度、自损爆发；
  - I-IV 升级后后段危险行动概率倾斜；
  - 绑定固定技能梯度是否完整。
- 新增 smoke 验证 `monster ecology balance audit preserves movement, resources, actions, bound skills, and art identities`。

### 平衡与规则决策

- 当前不急着继续堆怪兽数量；先保证每只已有怪兽都有清楚生态位，防止后续变成“只是数值不同的自动单位”。
- 后续新增怪兽时，必须同时满足：
  - 有商品偏好，并能影响地图商品/城市决策；
  - 有自动行动概率表，并且 I-IV 升级会把概率推向更危险或更核心的行动；
  - 有可重复使用的绑定固定技能梯度；
  - 有临时美工档案和图鉴可读身份；
  - 至少在移动、行动标签、经济钩子或地形适配中形成差异。
- 怪兽审计仍是开发内部数据；玩家图鉴看到的是生态、行动概率、商品偏好和卡牌效果，不看到隐藏 AI 压力桶。

### 新增验证

- 完整 smoke 现在会检查：
  - 怪兽数量不少于 8；
  - 目录中同时存在飞行、海域/水栖、陆行生态位；
  - 商品偏好池不少于 12 种商品；
  - 行动签名和行动标签数量足够，避免同质化；
  - 每只怪兽都有资源偏好、经济钩子、临时美工、升级概率倾斜和完整固定技能梯度。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 实战路线审计与多策略推进护栏

### 本轮实现

- 新增 `_ai_live_route_balance_report()` 和 `_ai_live_route_balance_summary()`，把一局实际运行后的 AI 决策样本转成内部平衡报告。
- 报告会统计：
  - 有多少 AI 产生了可识别发展路线样本；
  - 有多少 AI 在局中完成了经济推进；
  - 实战样本覆盖了多少条核心路线；
  - 有多少 AI 命中了自己的主路线偏好；
  - 本局出现了多少类行动；
  - 哪条路线在样本分数上最强；
  - 每个 AI 的主偏好、最高样本路线、路线样本数、经济推进、当前结算估值和行动类型。
- 八席 AI smoke 局现在会调用这份实战报告，要求：
  - 7 个 AI 都有路线样本；
  - 至少 6 个 AI 有经济推进；
  - 至少 4 条核心路线在实战中出现；
  - 至少 4 个 AI 命中自己的主路线偏好；
  - 至少 3 类行动进入样本。

### 平衡与规则决策

- 静态字段审计证明“卡牌能被 AI 理解”；实战路线审计证明“AI 真的在一局中把这些卡用成多种玩法”。
- 这份报告仍然是隐藏开发数据，不能进入玩家 UI。玩家只应该看到公开卡牌、地图结果、经济变化、合约/赌局/竞价等可推理线索。
- 后续新增卡牌或路线时，除了补卡牌字段，还要观察它是否能在 `_ai_live_route_balance_report()` 中形成实际样本；否则它只是图鉴内容，不算真的进入玩法。

### 新增验证

- `tests/smoke_test.gd` 的八席完整 smoke 现在额外验证 AI 实战路线审计：
  - 防止所有 AI 退化成同一种成长路线；
  - 防止只有静态路线标签、但局内没有经济推进；
  - 防止主偏好路线完全不起作用；
  - 防止 AI 行动样本过于单调。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜核心发展路线压力审计与 AI 策略场景稳定

### 本轮实现

- 新增核心发展路线压力审计，覆盖目前要求 AI 能实际追逐的六条基础路线：
  - 城市成长；
  - 合约商路；
  - 金融投机；
  - 怪兽压力；
  - 情报/补给；
  - 直接互动。
- 审计不按卡名硬编码，而是从卡牌字段推导：
  - `money_score`：现金、GDP、收入、生产/消费/运输、商品/城市衍生品等赚钱压力；
  - `disruption_score`：城市、商路、怪兽、玩家手牌或产权等破坏压力；
  - `protection_score`：修复、防御、保险、稳定市场、商路保护；
  - `intel_supply_score`：情报、购牌范围、追溯、补给能力；
  - `gate_score`：价格、商品流动、目标限制、持续时间、仓库/城市/区域等门槛；
  - `public_clue_score`：公开目标、商品流动、GDP 变化、城市线索、轨道记录等推理线索。
- 新增路线汇总文案 `_development_route_pressure_summary()`，后续可以给开发菜单或调试面板使用，但玩家界面仍不暴露 AI 内部路线桶。
- 强化 AI 策略意图 smoke 场景：
  - 成长场景保留开局 `grow_focus`；
  - 防守场景明确模拟“领先 AI 的高价值受损商路”，要求 AI 选择 `defend_routes` 并给供应链保险候选附加策略元数据；
  - 压制场景明确模拟“落后 AI 面对高收入竞品城”，要求 AI 选择 `disrupt_competitors` 并把商路黑客指向竞品城市。

### 平衡与规则决策

- 之后新增卡牌时，不能只看“这张牌好不好玩”，还要看它是否补强某条路线的赚钱点、门槛、公开线索和反制空间。
- 核心路线不要求任何时刻等强，但至少要保证每条路线都有：
  - 足够卡牌数量；
  - 至少一条完整 I-IV 梯度；
  - 能落到钱上的收益或压制结果；
  - 可被对手观察和推理的公开痕迹；
  - AI profile 能读懂并实际选择。
- AI 的路线、压力桶和策略评分继续作为隐藏开发数据；玩家只看到地图结果、卡牌轨道、公开线索和经济变化。

### 新增验证

- `tests/smoke_test.gd` 新增 `development route pressure audit proves core strategies have money pressure, gates, clues, and AI coverage`：
  - 验证六条核心路线都有至少 8 张相关卡；
  - 验证每条路线至少有一条完整 I-IV 梯度；
  - 验证路线总压力、门槛、公开线索、反制分和 AI profile 覆盖达到最低标准；
  - 验证城市成长/合约/金融必须能产生金钱压力，怪兽/直接互动必须有破坏压力，情报/补给必须有情报或补给压力。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜商品期货与港仓囤货平衡审计

### 本轮实现

- 新增商品期货平衡审计函数，覆盖 `商品看涨`、`商品看跌`、`港仓囤货` 三个 I-IV 家族。
- 审计从卡牌字段推导三类分数：
  - `effect_score`：期货倍率、持仓秒数、供需压力、囤货单位和仓储杠杆；
  - `gate_score`：购牌价格、商品流动门槛、持仓窗口、仓库城市要求和供需影响；
  - `public_clue_score`：公开方向、真实秒数窗口、商品流动线索、供需压力、仓库位置和囤货单位。
- 审计会计算“30点商品价格变化下的预期兑现”，并和普通城市基础 GDP/min 参考值比较，防止普通期货或港仓囤货在没有足够风险时变成无限印钱。

### 平衡与规则决策

- 普通商品看涨/看跌必须吃真实商品价格变化，不能从抽象经济周期中凭空结算；它们的强度由价格波动、商品流动要求和公开商品线索共同限制。
- 港仓囤货可以比普通期货有更高收益，因为它额外暴露匿名仓储线索，并把收益绑定到一座可被怪兽、军队或破坏牌攻击的城市仓库。
- 玩家看到的是商品价格、匿名期货/仓储线索和地图结果；`effect_score`、`gate_score`、`exposure_to_city_income_x100` 等审计字段只用于开发与自动测试，不暴露 AI 内部判断。

### 新增验证

- `tests/smoke_test.gd` 新增 `commodity futures balance audit gates long, short, and warehouse stockpile leverage with flow, public clues, and warehouse risk`：
  - 验证看涨、看跌、港仓三条路线都有完整 I-IV 梯度；
  - 验证强期货效果必须有商品流动门槛、真实秒数窗口、供需影响和公开线索；
  - 验证普通期货不偷偷叠加囤货单位；
  - 验证港仓囤货必须有仓库城市、囤货单位、较高公开线索和可控的收益上限。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜直接互动牌强度与反制护栏

### 本轮实现

- 新增直接互动牌平衡审计函数，覆盖 `星链拆解`、`影仓牵引`、`产权冻结`、`轨道齐射` 四个 I-IV 家族。
- 审计从卡牌字段推导三类分数：
  - `effect_score`：拆牌、牵牌、封锁、罚款、产权 GDP 惩罚、齐射目标数、齐射伤害和断路压力；
  - `gate_score`：费用、商品流动门槛、指定目标/公开城市目标、一次性结算等门槛；
  - `public_clue_score`：目标玩家、公开城市、商品流动、齐射目标数和公开 GDP/伤害结果带来的推理线索。
- 审计要求强效果必须同时满足：
  - 有商品流动门槛；
  - 有公开目标或公开城市结果；
  - 有相位否决作为可用反制家族；
  - I-IV 效果压力和门槛不能倒退。

### 平衡与规则决策

- 直接互动牌可以强，但不能便宜、无门槛、无公开线索地删除对手资源；它们应该制造“我被谁盯上了”的推理素材。
- 玩家看见的是目标玩家/目标城市/公开结果，不会看见 AI 的 `direct_*` 压力字段；审计分数只给开发和自动测试使用。
- `轨道齐射` 这种全场牌不要求指定某个玩家，但必须公开多个目标城市，让其他玩家可以从收益方向和商品/GDP压力反推。

### 新增验证

- `tests/smoke_test.gd` 新增 `direct-interaction balance audit gates strong pressure with flow, public clues, and counter windows`：
  - 验证四个直接互动家族都完整 I-IV；
  - 验证 IV 级强效果同时具备足够门槛和公开线索；
  - 验证拆牌/牵牌/产权冻结/轨道齐射的关键字段随等级增长；
  - 验证相位否决作为反制窗口支撑存在。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜军队牌身份与 GDP 压力平衡审计

### 本轮实现

- 新增军队牌平衡审计函数，读取所有 `military_force` 卡牌并按军种聚合：
  - HP、伤害、机动、射程、在场时间；
  - GDP 压力、压力持续秒数、显式断路伤害；
  - 陆地/海洋移动倍率和军种定位文字。
- 审计会检查每个军种是否维持设计身份：
  - 战斗机应是高机动截击/补位单位，不能偷走最高 GDP 压城定位；
  - 轰炸机应是主要城市 GDP 压制单位，并带显式商路压力；
  - 坦克应是陆地耐久防守/推进单位，跨海能力必须很弱；
  - 导弹阵地应是最高射程、低机动、位置可读的远程威慑；
  - 潜艇和战舰应更适合海域行动，并承担海路压力。
- I-IV 梯度现在自动检查 HP、伤害、在场时间、GDP/断路压力不得倒退。后续新增或改军队牌时，如果把军种身份调歪，烟测会直接暴露。

### 平衡与规则决策

- 这不是玩家可见的 UI 信息，而是开发护栏：玩家看到的是军队卡面、地图行动和 GDP/断路线索；AI 和测试用审计负责防止数值路线混乱。
- 军队和怪兽继续分工：军队不自主行动、不移动踩城，主要通过可回收军令制造保卫、压城、猎兽或商路控制；怪兽才是随机生态灾害和资源掠夺核心。
- GDP 压力的强弱不只看单次伤害，也看持续秒数和断路附带效果，避免高机动单位因为便宜/快而取代真正的压城军种。

### 新增验证

- `tests/smoke_test.gd` 新增 `military balance audit preserves fighter, bomber, tank, missile, submarine, and warship identities`：
  - 验证七类军队牌都至少有 I-IV 四张；
  - 验证战斗机机动高于轰炸机/导弹；
  - 验证轰炸机 GDP 压力高于战斗机/战舰；
  - 验证导弹射程高于轰炸机/战舰；
  - 验证坦克耐久和跨海弱点、海军海域适配、断路专长边界。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 合约回应字段化与结果线索回写

### 本轮实现

- 合约签/拒结果现在会回写到匿名卡牌轨道和经济总览余波线索：
  - 记录 `contract_result_clue`、`contract_accept_summary`、`contract_decline_summary`；
  - 线索明确显示供给区→需求区、商品、已签约/拒签/超时拒签、奖励或惩罚；
  - 仍然只公开结果，不公开合约发起者和真实回应者。
- AI 合约回应新增字段化评分，不再只输出“签约/拒签”：
  - 记录 `contract_response_role`、`contract_route_match`、`contract_accept_value`、`contract_reject_value`、`contract_response_margin`、`contract_decline_risk`；
  - 同步记录合约两端区域、来源城市业主、目标城市 GDP、目标断路压力、签约经济增量和拒签经济代价；
  - 惩罚型合约会被标记为 `accept_avoid_punishment`，路线吻合型合约会被标记为 `accept_route_plan`。
- 如果未来某些特殊合约不是从标准匿名轨道进入，结算结果也会作为卡牌余波进入历史，避免“结算了但玩家看不到公开证据”的断层。

### 平衡与规则决策

- 合约回应是公开结果、隐藏动机：玩家可以从商品、区域、奖惩和后续 GDP 变化推理身份；AI 的风险/路线评分仍是训练数据，不出现在玩家 UI。
- 拒签不是默认正确或错误：AI 会把“帮对手扩张供给”“拒签惩罚”“是否补齐自己的商品路线”“目标城市受损/缺需求”等因素一起评分。
- 合约结果线索会成为经济推理链的一环，后续可以继续接入卡牌归属竞猜、合约追溯卡和商品目录的相关城市线索。

### 新增验证

- `tests/smoke_test.gd` 扩展合约烟测：
  - 验证签约后轨道条目写入具体 `contract_result_clue` 和奖励摘要；
  - 验证 AI 对惩罚性拒签条款会签约，并写入 `contract_response_role=accept_avoid_punishment`；
  - 验证路线计划中的合约候选带有 `contract_route_match`、签/拒价值、回应边际和经济字段。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 直接互动目标规划字段化

### 本轮实现

- AI 直接互动牌新增专门计划器，不再只按“领先者/高估值”粗暴选目标：
  - `星链拆解`、`影仓牵引` 会按可见结算估值差、城市/怪兽经营压力、已公开或私下追踪到的卡牌归属线索、终局落后压力和卡牌自身拆牌/牵牌/封锁/罚款强度选择目标玩家；
  - `产权冻结` 会选择高 GDP、仓储压力、商路负载、领先者所属或更适合被压制的竞争城市；
  - `轨道齐射` 的实际目标排序也接入同一套城市压力评分，优先命中高价值、仓储/商路压力更高的非己方城市群。
- 新增隐藏训练字段：`direct_interaction_role`、`direct_interaction_score`、`direct_target_settlement`、`direct_target_gap`、`direct_target_city_pressure`、`direct_target_monster_pressure`、`direct_target_public_card_signal`、`direct_effect_pressure`、`direct_city_pressure`、`direct_city_gdp`、`direct_city_warehouse_pressure`、`direct_city_route_damage`、`direct_city_damage`、`direct_barrage_target_count`、`direct_barrage_expected_damage`。
- 这些字段写入 AI 候选视图和匿名出牌决策元数据，只用于内部训练/调试；玩家仍只看到公开目标、公开结果、卡牌轨道和经济变化，不会看到 AI 压力桶。

### 平衡与规则决策

- AI 选择拆牌/牵牌目标时不把对手真实手牌数量作为公开信息来展示；目标价值主要来自可见估值、已公开卡牌归属、城市/怪兽/金融压力和终局局势。
- 直接互动路线现在有更明确的策略位置：落后 AI 会更愿意用它压领先者或破坏高价值经营路线，领先 AI 则更谨慎，把它当作防止追赶和清理威胁的工具。
- `轨道齐射` 不再被测试假设为“打当前选区”，而是全场匿名压制牌：选区只是出牌上下文，实际命中由非己方城市压力排序决定。

### 新增验证

- `tests/smoke_test.gd` 扩展 `direct player-interaction cards cover 拆牌、牵牌、产权冻结、全场齐射...`：
  - 验证 AI 拆牌计划会选高估值/领先目标玩家，并写入直接互动隐藏元数据；
  - 验证 AI 产权冻结会选择带仓储压力的高价值竞争城市；
  - 验证轨道齐射目标排序优先命中高价值仓储城市；
  - 验证训练视图保留 direct 字段，但玩家可见逻辑仍只展示匿名结果。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 怪兽赌局下注策略

### 本轮实现

- AI 怪兽赌局新增下注计划层，不再只是“谁血多押谁”或“有钱就大注”，而是为每个参战怪兽计算内部评分：
  - 已造成伤害：当前赌局已经打出的伤害会提高该怪兽胜面；
  - 预期战斗力：读取怪兽行动表、行动权重、伤害、轻量击退价值、HP、护甲和等级；
  - 归属利益：AI 会更重视自己拥有的怪兽，但隐藏归属时不会无限放大，避免过度暴露；
  - 城市风险：靠近己方高价值城市会降低支持倾向，靠近竞争城市或商业靶点会提高支持倾向；
  - 资源吻合：怪兽在当前位置能吸取的商品资源会进入风险/强度判断。
- AI 下注金额从固定规则改成基于信心差距：
  - 默认公开底注 ¥100；
  - 如果最佳下注目标和第二候选分差足够大，并且现金足够，AI 会公开下 ¥500 大注；
  - 金额、下注玩家身份和下注目标仍然公开，作为玩家推理线索。
- `bets` 内部记录新增隐藏评分字段：`ai_wager_score`、`ai_wager_confidence`、`ai_wager_reason_key`、`ai_wager_owner_bias`、`ai_wager_city_bias`、`ai_wager_expected_damage`。这些字段用于测试和后续训练，不显示在公开下注摘要里。
- 修正怪兽战斗力估值：击退距离不再被当作直接伤害；它只作为轻量战术价值进入预期战斗力，避免远距离击退/光线类怪兽被 AI 夸大成压倒性伤害。

### 平衡与规则决策

- 怪兽赌局的公开信息保持简单：玩家只看到谁押了哪只怪兽、押了多少钱；AI 的评分理由是隐藏开发/训练数据。
- AI 可以因为强度、归属或城市利益做出不同选择，因此公开下注本身会成为推理线索，但不会机械等同于“谁押谁就是谁拥有”。
- 大注不应只由现金决定，而要由局势信心决定；这让玩家看到大注时能推测“这个 AI 可能掌握了某种利益或胜率判断”。

### 新增验证

- `tests/smoke_test.gd` 新增 `AI monster-wager bets use strength, ownership, city-risk, public stake, and hidden scoring metadata`：
  - 验证 AI 会在强势己方怪兽明显占优时押对应怪兽；
  - 验证高信心会触发 ¥500 公开大注；
  - 验证下注后现金正确扣除；
  - 验证公开下注摘要只显示玩家身份、目标和金额，不泄露 `ai_wager_*` 内部评分；
  - 验证内部下注记录保留评分、信心、归属偏好等训练字段。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 军队部署路线字段化

### 本轮实现

- AI 军队牌新增部署计划层，不再只返回“部署到哪个区域”，而是生成可训练的路线字段：
  - `military_deploy_role`：护航己方城市、压制竞争城市、截击怪兽、控制商路或占据适配地形；
  - `military_deploy_score`：当前部署路线的局势评分；
  - `military_deploy_terrain`、`military_deploy_route_load`、`military_deploy_monster_risk`：记录地形、商路和怪兽压力；
  - `military_deploy_district`：购牌候选中单独记录未来部署点，避免和“在哪里买到这张牌”的区域混在一起。
- 部署评分会读取军队字段与地图状态：
  - 防卫军更偏向守住己方高 GDP、受损、断路、仓储或怪兽威胁城市；
  - 轰炸机、导弹、潜航舰队更偏向压制竞争城市、仓储金融靶点和高商路价值节点；
  - 战斗机和导弹会更重视怪兽截击；
  - 潜航舰队和星海战舰会更重视海域商路控制；
  - 坦克在陆地城市防守和近线推进上获得更高权重。
- AI 出牌、购牌、匿名出牌记忆和训练样本都能保留这些部署字段，后续新增军队牌时能先靠字段形成基础路线判断。

### 平衡与规则决策

- 军队路线被明确拆成“部署资产”和“可回收军令”两层：部署决定这支短时战斗力量放在哪里，军令决定它之后做什么。
- 防卫军的攻击倾向被压低，避免它被高价值竞品城市过度诱惑；进攻压城路线主要交给轰炸机、导弹、潜航舰队等更符合直觉的军种。
- 购买军事牌时，AI 会评估未来部署价值，但购买区域仍由怪兽补给规则决定；这个分离能避免“从哪里买牌”和“之后部署到哪里”在训练数据里混淆。

### 新增验证

- `tests/smoke_test.gd` 新增 `AI deploys military-force cards with field-driven guard, strike, and purchase metadata`：
  - 验证 AI 会用防卫军守己方受损高价值城市；
  - 验证 AI 会用轰炸机压制竞争/仓储城市；
  - 验证匿名出牌记忆保存 `military_force_strike_rival_city` 和部署路线字段；
  - 验证购牌候选把购买区域和未来部署区域分开记录。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 军队可回收指令目标规划

### 本轮实现

- AI 新增军队指令规划器，不再只把绑定军令当作普通卡牌评分，而是读取 `military_command`、绑定军队 UID、军队类型、射程、火力、地形适配和当前地图状态来选择目标。
- 可回收军令现在按用途分流：
  - `guard` 优先保护己方高 GDP、受损、断路、恐慌、仓储压力或怪兽威胁较高的城市；
  - `strike_district` 优先打击竞争城市、仓储城市、高商路负载城市和与己方商品路线冲突的城市；
  - `attack_monster` 优先猎杀靠近己方城市、资源吻合度高、生命/等级威胁高的怪兽；
  - `move` 会按军队类型、地形倍率、己方防守价值、敌方进攻价值和商路负载选择重新部署点。
- AI 出牌候选、匿名出牌记忆和训练样本新增军令元数据：`military_command`、`military_command_role`、`military_command_score`、`military_command_distance_m`、`military_unit_uid`、`military_unit_type`。
- 调整 AI 出牌上下文的分支顺序，让“攻击怪兽”军令优先走军令规划器，而不是被通用怪兽目标逻辑提前截走。

### 平衡与规则决策

- 军队继续与怪兽区分：军队完全靠玩家/AI 的可回收指令行动，不产生怪兽式自主行为，也不会因为受伤让操控者承担怪兽伤害资金损失。
- 军队路线现在能形成四种清晰策略：护航己方 GDP、打击竞品城市、清理怪兽威胁、抢占地形/商路节点。
- 这些评分、压力桶和路线偏好仍是隐藏 AI 工具；玩家只会看到公开军队行动、地图结果、GDP 压力和匿名卡牌线索。

### 新增验证

- `tests/smoke_test.gd` 新增 `AI uses reusable military commands to guard cities, strike rivals, attack monsters, and record command metadata`：
  - 验证 AI 能为防守军令选择己方城市；
  - 验证 AI 能为轰击军令选择竞争城市；
  - 验证 AI 能为猎兽军令选择威胁怪兽，并记录资源匹配；
  - 验证匿名出牌训练记忆会保存军令类型、角色和绑定军队 UID。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜商品期货 AI 字段化决策

### 本轮实现

- AI 新增商品期货评估器，不再只把 `商品看涨 / 商品看跌 / 港仓囤货` 当作普通经济牌加一点市场压力分，而是读取卡牌字段判断策略：
  - `product_bet_direction` 区分看涨/看跌；
  - `product_bet_multiplier`、`product_bet_seconds` 和 `stockpile_units` 进入收益/风险评分；
  - `requires_warehouse_city` 会迫使 AI 选择一座己方存活城市作为仓库，并评估该城市的商品匹配、交通、GDP、路线压力、损伤和怪兽风险。
- AI 出牌上下文新增商品期货元数据：`futures_direction`、`futures_signal`、`futures_market_score`、`futures_stockpile_score`、`futures_stockpile_units`、`futures_duration_seconds`、`futures_multiplier_x100`、`futures_warehouse_city`、`futures_warehouse_required`、`futures_product_flow`。
- AI 购牌候选同样保留期货元数据，并额外记录 `futures_play_district`，避免“在哪里买到牌”和“这张牌打出时应该选哪个仓库/商品”混在一起。
- 训练样本和实际匿名出牌记录加入上述字段，后续新增商品期货、仓储、囤积、看涨/看跌类卡牌时，AI 可以先靠字段形成基础判断，再由学习层微调。

### 平衡与规则决策

- 商品金融路线现在更像一条真正的 AI 可走路线：AI 会根据公开供需、商品流动、焦点商品、路线商品、竞争城市和仓库风险来决定看涨、看跌或囤货，而不是随机买金融牌。
- 港仓囤货仍是高收益高暴露路线：仓库城市会成为公开金融靶标，吸引怪兽、做空、轨道齐射、军队压力和情报推理；AI 也会把这种风险当作攻击/防守目标。
- 这些判断仍然是 AI 内部工具，玩家界面只显示公开结果和线索，不显示 AI 的评分、压力桶或路线计划。

### 新增验证

- `tests/smoke_test.gd` 新增 `AI evaluates commodity futures from fields for long, short, stockpile, buy, and training metadata`：
  - 验证 AI 能为商品看涨生成 `product_futures_up` 出牌上下文；
  - 验证 AI 能为商品看跌生成 `product_futures_down` 出牌上下文；
  - 验证港仓囤货会选择己方仓库城市并写入仓库元数据；
  - 验证购牌候选也携带期货信号和实际打出目标；
  - 验证匿名出牌训练记忆会保存商品期货策略字段。
- 加固旧仓储风险测试：对照城收入降低，仓储城收入提高，让测试稳定验证“仓储风险会吸引做空、齐射和军队压制”，而不是被随机地图上的高收入对照城干扰。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜卡牌图鉴严格分类与局部 hover 刷新

### 本轮实现

- 卡牌图鉴筛选从旧的粗分组细化为：怪兽牌、怪兽技能、军队/军令、相位反制、玩家互动、城市经营、商品经营、商品期货、金融/GDP、合约、情报、补给/采购、怪兽诱导、新闻事件、天气干预和其他。
- 旧筛选 ID `economy`、`business`、`combat` 继续作为内部兼容聚合保留，避免旧入口和测试断裂；玩家界面优先展示新的严格分类。
- 卡牌图鉴新增“统一卡池 / 区域补给 / 市场牌池”解释：图鉴展示完整卡池；本局区域补给才是实际可购买候选；怪兽生态档案只解释自动怪兽行为，怪兽牌仍在卡牌图鉴里查看。
- 卡牌图鉴和怪兽生态档案的 hover/单击预览改为只刷新下方预览面板，不再重建整页，减少图鉴滚动跳动和翻页疲劳。
- `商品看涨`、`商品看跌`、`港仓囤货` 登记为正式 I-IV 升级家族，和“重复获得同系列牌自动合成升级到 IV”的规则保持一致。

### 体验与规则决策

- “普通牌池”以后只作为开发语境里的候选牌库；玩家应理解为：图鉴看全卡，地图区域看本局当前可买牌。
- 严格分类是后续卡牌平衡的基础：金融/GDP、商品期货、商品经营、城市经营和合约不再挤在同一个“经济”抽屉里，方便玩家按路线找牌，也方便 Codex 后续按字段审计强度。
- hover 预览应该像 TCG 图鉴里的快速扫读，不应该因为鼠标滑过就重排整页。

### 新增验证

- `tests/smoke_test.gd` 扩展卡牌图鉴烟测：
  - 检查严格分类标签和统一卡池解释会出现在图鉴缩略图页。
  - 验证怪兽牌、怪兽技能、军队/军令、相位反制、城市经营、商品经营、商品期货、金融/GDP、合约等分类能各自找到代表卡。
  - 保留旧 `economy` / `business` 兼容聚合验证。
- 怪兽落地区折扣测试改为构造单个受控怪兽落点，避免多个怪兽相邻落地时把“相邻区”随机判成“落地区”的旧 flake。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 怪兽诱导更重视商品竞品压力

### 本轮实现

- 怪兽诱导 AI 评分新增 `product_overlap`：当目标城市与 AI 自己城市的生产/需求商品重叠时，会显著提高诱导怪兽压向该城市的倾向。
- 怪兽诱导候选、匿名出牌记录和训练样本会保留 `product_overlap` 字段，方便后续学习层判断“打竞品城市”是否真的转化成更多最终金钱。
- 怪兽诱导理由文本新增“竞品压力”片段，让开发调试时能看出 AI 为什么认为某座城市值得引怪。

### 平衡决策

- 怪兽不应该只被“距离近、资源吻合”吸引；从商业玩法看，摧毁生产/需求相似的竞争城市才是更稳定的策略。
- 这个评分仍是 AI 内部工具，不向玩家展示。玩家只会看到怪兽移动、卡牌轨道、城市受损和公开线索，再自行推理是谁可能受益。

### 新增验证

- `tests/smoke_test.gd` 的 AI 怪兽诱导测试现在要求目标城市具有正的 `product_overlap`，并继续验证目标城市、目标怪兽、资源吻合、攻击价值和匿名出牌训练元数据。

## 2026-07-01｜商品缩略图显示主策略标签

### 本轮实现

- 商品图鉴缩略图新增 `主策略` 行，直接显示该商品当前最突出的公开路线及分数，例如看涨、看跌、囤货、商路或怪兽风险。
- 新增可复用的商品策略排序/主策略标签函数，后续经济总览或地图商品筛选也可以复用同一套公开策略判断。
- 商品图鉴说明文案同步改为：缩略图负责快速扫读价格、供需和主策略，hover/详情再展开期货仓储、怪兽偏好、天气和城市线索。

### 体验决策

- 玩家打开商品图鉴时，第一眼应该能看出“这页有哪些商品现在值得做事”，而不是必须逐个 hover 或点详情。
- 主策略只来自公开市场数据、公开仓储/期货、天气、供需、断路和怪兽偏好，不泄露玩家身份、现金、手牌、弃牌或 AI 内部路线。

### 新增验证

- `tests/smoke_test.gd` 新增商品缩略图主策略验证：商品图鉴缩略图页和缩略图容器都必须出现 `主策略` 标签。

## 2026-07-01｜商品详情页 TCG 化分区

### 本轮实现

- 商品 hover 预览从单行密集字段改为多行短摘要，保留价格梯度、供需断波、策略、期货仓储、怪兽、相关卡、天气、供需区域和城市线索。
- 商品详情页改成 TCG 式分区：商品卡、市场面板、策略面板、金融与天气、生态与卡牌、地图入口、商品相关城市线索、规则提示。
- 详情页继续只显示公开信息，不展示真实业主、对手现金、手牌、弃牌或 AI 内部路线。

### 体验决策

- 商品是卡牌经济的核心对象，阅读方式要接近卡牌详情页，而不是规则书段落。玩家应该先扫到“这东西现在适合看涨、做空、囤货、跑商路还是引怪”，再决定是否继续看城市线索。
- hover 负责快速判断，详情页负责完整解释；上一页/下一页仍只在详情页出现，避免缩略图页变成翻页泥潭。

### 新增验证

- `tests/smoke_test.gd` 新增商品详情分区验证，要求详情页出现商品卡、市场面板、策略面板、金融与天气、生态与卡牌等关键分区。

## 2026-07-01｜商品图鉴升级为商品策略面板

### 本轮实现

- 商品图鉴 hover/单击预览新增公开策略摘要，把每个商品按看涨、看跌、囤货、商路、怪兽风险五条路线给出短判断。
- 商品详情页新增四个可读面板：策略摘要、期货/仓储、怪兽偏好、相关卡牌。
- 期货/仓储面板会把匿名商品期货、港仓囤货城市、仓储单位、风险压力和到期时间合并展示；没有公开仓储时会提示可通过看涨、看跌或港仓囤货制造价格窗口。
- 怪兽偏好面板会列出偏好该商品的怪兽，并说明这些商品产区、需求城或仓库更容易把怪兽吸引过来。
- 相关卡牌面板从同一套卡牌数据中生成，帮助玩家从商品直接跳回“哪些牌能围绕这个商品做事”的思路。

### 体验与隐私决策

- 商品不再只是打牌门槛或地图风味，而是玩家可以围绕它做金融、仓储、商路、怪兽诱导和城市竞争的策略入口。
- 图鉴只整理公开证据：供需、断路、天气、匿名期货、公开仓储、怪兽偏好和卡牌字段。它不会显示真实业主、对手现金、手牌数量、弃牌内容或 AI 内部路线。
- 策略分数是为了帮助测试者理解方向，不是绝对推荐；真正收益仍取决于之后的价格、GDP、怪兽移动、军队打击和玩家推理。

### 新增验证

- `tests/smoke_test.gd` 扩展商品图鉴验证：
  - hover 预览必须显示商品策略信息。
  - 商品详情页必须显示策略摘要、期货/仓储、怪兽偏好和相关卡牌面板。
  - 港仓囤货测试会验证商品详情页能看到匿名期货、仓库和策略摘要。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜图鉴缩略图预览保持滚动位置

### 本轮实现

- 卡牌图鉴、怪兽生态档案、商品图鉴的缩略图 hover/单击预览统一走滚动位置保护：刷新预览前记录菜单滚动条，刷新后立即与布局帧后各恢复一次。
- 怪兽和商品图鉴补齐与卡牌图鉴一致的滚动恢复逻辑，避免玩家浏览缩略图时因为 hover 预览导致页面跳回顶部或底部。
- 这次改动只影响缩略图预览刷新；详情页进入、上一页/下一页切换、返回缩略图的路径保持原有逻辑。

### 体验决策

- 图鉴是玩家理解卡牌、怪兽、商品和策略路线的主要入口，浏览时最重要的是“位置感”不能丢。hover 可以更新预览，但不应该夺走玩家正在看的缩略图位置。
- 修复采用统一队列恢复函数，而不是给每个图鉴写不同逻辑，方便以后区域图鉴、角色图鉴或新资料页复用。

### 新增验证

- `tests/smoke_test.gd` 新增图鉴滚动保护验证：
  - 怪兽生态缩略图 hover 预览在页面可滚动时保持滚动位置。
  - 卡牌缩略图 hover 预览在页面可滚动时保持滚动位置。
  - 商品缩略图 hover 预览在页面可滚动时保持滚动位置。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜经济口径统一为按秒现金流与 GDP/min 快照

### 本轮实现

- 新增 `_player_gdp_per_minute()`、`_city_gdp_per_minute()` 和 `_city_gdp_per_minute_breakdown()` 作为新的内部经济接口；旧 `cycle` 函数只保留为存档/测试兼容壳。
- 玩家可见 UI 把“本刷新现金流”改为“实时现金流”，避免让测试者误解为按周期发钱。
- GDP 趋势文案从“本期/上期”改为“当前快照/上次快照”，明确全局市场刷新只是公开经济快照，不是收入结算周期。
- 卡牌文本兜底清洗把残留“经营周期”转为“实时窗口”，只有供需、价格、商路、GDP 趋势记录继续使用“全局市场刷新”概念。
- README、规则摘要和原型范围文档将 `current-refresh cashflow` 统一改为 `realtime cashflow`。

### 平衡决策

- 城市收入的真实规则保持线性：当前 GDP/min 按秒折算进玩家现金，余数保存在城市现金流尾差里。
- 全局市场刷新是公开信息刷新：重估供需、价格、商路、GDP 快照和部分 AI 匿名商业动作；它不再承担“发钱周期”的概念。
- 金融牌继续按真实秒数持仓，到期读取即时 GDP/价格变化，避免和刷新次数绑定。

### 新增验证

- 当前规则文档、README、原型范围和主 UI 不再使用 `current-refresh cashflow`、`本期/上期` 或玩家可见的周期发钱口径。
- 旧测试仍可通过兼容壳调用 `_city_cycle_income*`，后续可以在更大重构时逐步迁移测试命名。

## 2026-07-01｜仓储风险进入经济总览与情报档案

### 本轮实现

- 经济总览新增“仓储风险”摘要卡和“仓储靶标”列表，把公开匿名仓储城市按压力、单位、GDP/min 和到期时间排序。
- 情报档案新增“仓储风险线索”段落，让玩家能把港仓囤货、做空、齐射、军队、引怪和城市归属推理放在同一个页面判断。
- 城市调查优先级现在会把仓储压力计入排序；同等 GDP 下，有匿名仓储的城市更值得玩家标注、追查和反制。
- 城市线索行会显示仓储风险状态，但仍只使用“匿名仓储”公开信息，不显示仓储玩家、现金、手牌、弃牌或 AI 内部路线。
- 公开局势摘要会把匿名仓储城市计入场面异动，方便玩家知道当前地图上已经出现了可争夺的金融靶标。

### 平衡决策

- 仓储风险被设计成玩家可见、身份隐藏的“战略压力”：它不直接揭示谁在赚钱，但告诉所有人哪里可能值得做空、齐射、派军、引怪或保护。
- 经济总览展示的是场面证据，不是结论。玩家仍需要结合商品、卡牌轨道、打牌条件、合约、怪兽损伤和公开下注来推理真实归属。
- 这让商品期货/囤货路线有更清晰的反制窗口：收益潜力更大，但仓库城市也会更像一座明晃晃的金融弹药库。

### 新增验证

- `tests/smoke_test.gd` 扩展港仓囤货烟测：
  - 验证经济总览显示“仓储靶标”“匿名仓储”和隐私边界提示。
  - 验证情报档案显示“仓储风险线索”。
  - 验证仓储城市会进入城市调查优先级字段。
  - 验证仓储风险行包含商品、到期、反制方向，并且不泄露玩家名。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜仓储金融风险接入做空、齐射与军事目标选择

### 本轮实现

- AI 城市目标评分继续字段化：`warehouse_stockpile_*` 现在不只影响怪兽和事件，还会影响领先者城市选择、竞争城市压力、GDP 衍生品目标、军事部署和泛用卡牌效果评分。
- `城市做空` 目标选择会更偏向对手的匿名仓储城市；如果己方城市有仓储，AI 会降低拿它做空的倾向，并提高灾害保单/防守价值。
- `轨道齐射` 的实际命中列表会把仓储压力计入排序。也就是说，一座 GDP 略低但有公开仓储囤货的城市，可能比普通高 GDP 城市更容易被齐射打中。
- 军队部署评分接入仓储压力：进攻型军队更愿意部署到能威胁对手仓储城市的位置；防守型/己方部署会更看重保护自己的仓储城市。
- 泛用 AI 卡牌评分接入仓储压力：军令保卫、军令摧毁、区域伤害、商路破坏、GDP 做空、灾害保单和齐射都会按目标仓储状态获得额外评分。

### 平衡决策

- 仓储本身不直接造成额外伤害或额外收益；它只提高“被选择为目标/被保护”的概率。收益仍来自商品期货结算，损失仍来自仓库被毁、GDP 下跌、商路破坏等正常机制。
- 对玩家来说，这让港仓囤货成为清晰的金融博弈：囤得越多，越容易被识别成值得轰炸、做空、齐射或防守的城市；但仓储玩家身份仍不公开。
- 对 AI 来说，这给金融路线和军事路线之间建立了桥：AI 可以先发现公开仓储，再用做空、军队、怪兽或齐射去压仓。

### 新增验证

- `tests/smoke_test.gd` 扩展港仓囤货烟测，新增一座普通对照城：
  - 验证带仓储但 GDP 略低的城市会被 AI 城市做空优先选中。
  - 验证领先者/压力目标选择会优先识别仓储城市。
  - 验证 `轨道齐射` 一目标命中列表优先选择仓储城市。
  - 验证进攻型军队部署评分优先选择仓储城市。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜港仓囤货接入城市压力、怪兽吸引与 AI 目标评分

### 本轮实现

- `港仓囤货` 不再只是商品图鉴里的匿名期货文字：开仓后会在仓库城市写入结构化公开状态，包括匿名仓储笔数、囤货单位、关联商品和最近到期时间。
- 区域图鉴的城市公开状态会显示这条仓储线索，但仍不显示仓储玩家、真实业主、现金或手牌信息。
- 事件/新闻灾害目标权重新增 `warehouse` 分量，城市里有匿名仓储时更容易成为高价值公开目标。
- 怪兽自动目标权重新增 `warehouse` 分量；区域详情页的“怪兽吸引”现在能把匿名仓储作为目标主因显示出来。
- 怪兽资源偏好会读取城市里的仓储商品。如果某只怪兽偏好被囤积的商品，它会更容易被这座城市吸引；仓储单位越多，资源吻合越明显。
- AI 的隐藏评分接入仓储压力：对手城市有仓储时更适合作为怪兽诱导/压制目标；己方城市有仓储时会提高护路防守需求。这个评分仍是内部 AI 工具，不会展示给玩家。
- 新增统一刷新函数，从当前商品期货头寸反推城市仓储标记，确保开仓、到期、仓库被毁或状态恢复后不会留下过期仓库标签。
- 修复城市被摧毁时旧局部城市字典可能把已清除仓储字段写回废墟的问题。

### 平衡决策

- 仓储压力被设计成“收益越高、越能被反制”的金融路线风险：它能扩大商品看涨收益，但会把所在城市变成怪兽、事件、军队和做空路线都容易关注的靶子。
- 仓储公开信息只公开商品、单位和时间，不公开玩家身份；其他玩家需要结合商品流动条件、卡牌轨道、怪兽下注、城市归属标注等线索推理是谁在囤货。
- 当前仓储压力权重与城市经营、资源偏好、距离、热度处在同一目标系统内，后续数值平衡可以直接调仓储笔数/单位压力常量，而不必改 UI 或 AI 逻辑。

### 新增验证

- `tests/smoke_test.gd` 扩展港仓囤货烟测：
  - 验证城市公开状态显示匿名仓储、商品和单位，且不泄露玩家名。
  - 验证事件目标权重出现 `warehouse` 压力。
  - 验证怪兽自动目标权重出现 `warehouse` 压力，并且偏好该商品的怪兽会获得资源吻合分。
  - 验证怪兽目标原因文本能显示“匿名仓储”。
  - 验证仓库城市被摧毁后仓储压力清零，仓储期货作废，普通非仓储期货继续保留。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜怪兽赌局实装：全场冻结、强制底注与多方奖池

### 本轮实现

- 怪兽遭遇不再只是“赌局蓝图”：当自动怪兽即将用招式命中另一只怪兽时，会先开启怪兽赌局并冻结整局游戏时间。
- 赌局窗口最长 30 秒；`game_time`、城市现金流、天气、卡牌队列、怪兽移动/在场时间等对局系统暂停，但 UI、倒计时、地图动画和下注按钮继续更新。
- 所有玩家必须下注，不能观望；底注暂定 `¥100`，可在 UI 中选择更高额下注。身份、押注方向和金额全部公开，作为怪兽归属和玩家策略倾向的推理线索。
- 如果 30 秒内仍有玩家未下注，系统会按公开可见战况为其强制押底注，防止全场冻结被拖死。
- 赌局支持多方怪兽混战：触发怪兽及同区其他存活怪兽会作为同一奖池的多个押注对象，不再硬编码为 A/B 双方。
- 结算改为奖池制：总奖池来自所有公开下注；造成伤害最高的怪兽一侧为中奖侧，押中玩家按自己的中奖下注额占比分走总奖池。冷门怪兽押中时赔率会自然变高。
- 怪兽攻击会被延后到全员下注或超时强制下注之后再播放/结算，避免玩家在结果已经发生后下注。
- 地图新增 `wager` 事件动画：大范围橙色冲击环、扫描线和筹码光点，配合“全场冻结”临时决策面板，让玩家明显感到特殊公开事件发生。

### 平衡决策

- 怪兽赌局被定义为“少数公开亮身份操作”：平时卡牌和经济仍匿名，但赌局下注的玩家、金额和目标全部公开，给其他玩家制造强推理线索。
- 当前奖池按中奖下注额比例分配，而不是固定 ×2 返还。这样多人押热门怪兽会摊薄收益，少数人押中冷门怪兽会得到更高回报。
- 强制底注会把“必须行动”的规则落到钱上；后续可继续平衡底注、可选下注档位、AI 风险偏好和怪兽战斗伤害窗口。

### 新增验证

- `tests/smoke_test.gd` 新增 `_verify_monster_wager_system()`：
  - 验证怪兽遭遇会打开强制公开赌局并进入阻塞决策状态。
  - 验证身份、押注方向和金额会进入公开摘要与日志。
  - 验证玩家下注后不能换边，活跃赌局会进入 run save。
  - 验证所有玩家下注后可提前结束，并按奖池结算给押中方。
- 旧的怪兽碰撞烟测已改为先结束赌局窗口再检查伤害，符合“下注前冻结、下注后开战”的新规则。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜直接玩家互动牌、统一临时决策UI与海洋商品闭环

### 本轮实现

- 新增四组直接玩家互动卡牌家族，均有 I-IV 罗马等级、I级基准价格、字段驱动强度预算、图鉴分类和匿名结算演出：
  - `星链拆解 I-IV`：指定一名玩家，匿名拆掉其可弃普通手牌；高阶会追加短时手牌封锁和小额重组成本。目标玩家公开，具体牌名和手牌数量仍是私人信息。
  - `影仓牵引 I-IV`：指定一名玩家，匿名牵取其可弃普通手牌；无法接收时转化为拆牌/补偿，避免突破手牌上限规则。
  - `产权冻结 I-IV`：选中公开存活城市，制造临时产权争议，把 `control_gdp_penalty` 写入实时 GDP/min 拆解；不永久夺城，避免一张牌直接改变胜负归属。
  - `轨道齐射 I-IV`：匿名轨道齐射，优先打击非己方高价值城市；目标公开、出牌者匿名，适合终局压制领先者并制造推理线索。
- 新增“直接互动”卡牌路线和卡牌图鉴筛选；卡牌路线总览从五条核心路线扩到六条：城市成长、合约供需、金融投机、怪兽压制、情报补给、直接互动。
- AI 性格和评分接入直接互动路线：破坏型 AI 以直接互动为主偏好，驯怪型 AI 把直接互动作为副偏好；AI 候选、训练样本和匿名出牌 metadata 新增 `target_player`。
- 玩家打出直接互动牌时会先打开“玩家目标”选择面板，再进入匿名卡牌轨道；目标公开但出牌者仍匿名。
- 抽出统一临时决策 UI 基底，当前覆盖：私密弃牌、合约回应、怪兽目标选择、玩家目标选择、怪兽赌局。后续合约、临时投票、反应牌可以复用同一套 panel/style/action 描述。
- GDP 拆解加入 `control_penalty`，区域图鉴和经济文本会显示产权争议造成的 GDP 压力。
- 海洋区域改为能生产海域商品，新增/接入星鳍鱼群、巨藻纤维、海底黑油、潮汐电浆等海洋商品；地图生成按地形给陆地/海洋分配一项初始供给和一项需求。
- 本局卡牌池继续按本局存在的商品过滤：如果星球上没有某种固定商品，该商品绑定牌不会强行进入本局供给。
- 怪兽生态档案文案改成正面说明“看生态、行动、移动、伤害；怪兽牌在卡牌图鉴”，减少开发历史式说明。

### 平衡决策

- 直接夺取城市所有权暂不实现为常规牌。当前用“产权冻结”表达三国杀式拆归属/拆节奏：它能压低 GDP、制造公开线索、配合做空和怪兽破坏，但不会永久偷走城市，降低一张牌直接改胜负的风险。
- `星链拆解/影仓牵引` 只影响“可弃普通手牌”，不影响绑定怪兽固定技能，也不公开具体牌名，保证它们能互动但不摧毁隐私推理结构。
- `轨道齐射` 自动挑非己方高价值城市，不需要玩家逐个点目标；它强在广域压制，弱点是目标很多、意图很容易被其他玩家反推。
- AI `create_demand` 阶段的路线缺口惩罚再次加硬：缺需求时，纯生产扩张会被明确视为阶段错配，避免 AI 被大数值生产牌带偏。

### 新增验证

- `tests/smoke_test.gd` 新增 `_verify_direct_player_interaction_cards()`：
  - 验证四组互动牌均有 I-IV、价格不漂移、强度预算不倒退、图鉴分类为直接互动。
  - 验证玩家目标选择会打开 pending player-target 决策。
  - 验证拆牌、牵牌、产权冻结、全场齐射的核心结算能实际改变手牌/城市/GDP/区域伤害状态。
- `tests/smoke_test.gd` 新增 `_verify_temporary_decision_blueprints()`，验证弃牌、合约、怪兽目标、玩家目标、怪兽赌局都能从统一临时决策蓝图生成。
- 原海洋“无商品”烟测改为 `_regions_start_with_terrain_goods()`，验证陆地和海洋都从对应商品池生成初始供给/需求。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI路线分化与情报字段评分

### 本轮实现

- AI 通用字段评分新增情报字段识别：`trace_card_count`、`reveal_city_count`、`trace_contract_count` 现在会进入 `generic_effect_bonus`，后续新增情报牌只要补齐字段，AI 就能初步理解它的价值。
- 护路/修复类 `route_insurance` 出牌候选现在写入 `target_city` 和 `target_owner`，让训练样本能区分“保护己方城市”和“误帮别人城市”。
- AI 商品路线缺口评分修正：在 `create_demand` 阶段，如果一张牌只是补供给、没有补需求或接通商路，会受到“暂缓补供给”的阶段错配惩罚，避免 AI 一边说要补需求、一边被高数值生产牌带偏。
- 新增 `_verify_ai_strategy_route_diversification_policy()`：用受控沙盒分别验证 AI 能为防御修复、竞争压制、金融做空、情报追踪生成字段驱动候选，并且这些候选进入匿名出牌训练样本。

### 新增验证

- `tests/smoke_test.gd` 新增断言：`AI opponents generate field-driven defense, suppression, finance, and intel route candidates`。
- 完整 Godot headless smoke test 通过。

## 2026-07-01｜实时GDP方向性沙盒验证

### 本轮实现

- `tests/smoke_test.gd` 新增 `_verify_realtime_gdp_directionality_pack()`，用受控城市、受控产区和受控商品市场直接验证 GDP/min 拆解方向，而不是只通过卡牌结果间接推断。
- 新测试会临时构造一座生产/需求/运输都可控的城市，并在结束后完整恢复地图、市场、选区和日志，避免污染后续长 smoke。
- 方向性断言覆盖：
  - 提高生产等级会提高 `product` 生产 GDP。
  - 提高交通等级会提高基于运输速度的生产收益。
  - 提高消费等级会提高 `route` 消费/商路 GDP。
  - 提高城市 `route_flow_multiplier` 会继续放大商路 GDP。
  - 商路损伤会增加 `route_penalty` 并降低净 GDP。
  - 区域伤害会增加 `damage_penalty` 并继续压低净 GDP。
  - GDP 拆解摘要必须保留生产、消费、断路、损伤等玩家可解释字段。

### 新增验证

- 完整 Godot headless smoke test 通过，新增断言名称：`realtime GDP breakdown responds to production, consumption, transport, route-flow, route damage, and region damage`。

## 2026-07-01｜十小时路线补强包与AI字段验证

### 本轮实现

- 新增四组完整 I-IV 卡牌家族，补强“护路、防守、压制、情报、天气”之间的策略链，而不是只新增孤立单卡：
  - `应急修复 I-IV`：防御型商路牌，修复己方城市断路并提供短时 route-flow 保护/加速窗口，让领先玩家有合理护城手段。
  - `竞争封锁 I-IV`：城市压制牌，降低目标区生产、交通和消费，并制造商路伤害/供给压力，服务落后方或同商品竞争者的破坏路线。
  - `线索悬赏 I-IV`：情报推理牌，按等级私下追溯匿名卡、城市业主和合约参与方，所有线索仍然只给出牌者，不直接公开隐藏信息。
  - `航线预报 I-IV`：天气/商路博弈牌，围绕目标区域改写下一段公开天气预报，为建城、护路、做空、怪兽诱导和城市压制制造提前量。
- 这些新牌只把 I 级基牌加入本局公共可购牌池；重复获得后仍按统一手牌合成规则升到 II-IV，价格继续沿用 I 级基准价。
- `route_insurance` 结算从“只修断路”扩展为“修断路 + 写入城市短时商路流速倍率”，让卡牌效果能在线性实时 GDP 中持续一段秒数，而不是依赖旧的经济周期口径。
- `intel_card_trace` 现在能按字段组合追溯匿名出牌、揭示城市业主、回溯合约参与方；AI 和图鉴仍通过字段理解它，不需要硬编码卡名。
- AI 的商路防御/区域压制候选更稳：护路牌不再只在城市已经断路时才有价值，会优先保护己方路线城市；压制牌会记录目标城市和目标业主，方便训练样本判断“是否真的攻击到竞争者”。
- 卡牌路线分类顺序修正：带有负向生产/交通/消费和商路伤害的牌优先归入“城市压制”，不会因为同时带有市场压力字段而误显示成“金融投机”。

### 新增验证

- `tests/smoke_test.gd` 新增 `_verify_ten_hour_route_pack()`：
  - 验证四组新牌都有 I-IV 梯度、罗马等级、I级价格稳定、强度预算不倒退。
  - 验证只有 I 级基牌进入本局卡池，升级仍由重复获得触发。
  - 验证图鉴/路线标签能把 `应急修复`、`竞争封锁`、`线索悬赏`、`航线预报` 分别显示为城市成长/城市压制/情报推理/天气博弈，并带出对应平衡支点。
  - 验证 `应急修复 III` 能实际修复路线伤害并写入城市 route-flow multiplier。
  - 验证 AI 能把护路、压制、天气卡纳入候选上下文，而不是只认识旧卡名。
- 完整 Godot headless smoke test 通过。

## 2026-07-01｜卡牌路线平衡支点审计

### 本轮实现

- 卡牌路线审计新增“平衡支点”统计：每张卡会按字段归入收益、压制、防御、信息、补给、怪兽、合约、市场、GDP金融、公开门槛等支点；路线审计再聚合这些支点，帮助判断一条路线是不是只有高数值、缺少反制窗口或缺少收益兑现。
- 卡牌图鉴路线总览现在显示 `平衡` 状态、`支点` 分布和 `检查` 结论；它继续不暴露 AI 内部偏好，只把卡池本身是否偏科展示给测试者和开发者。
- 新增路线健康检查规则：核心路线会提示牌量偏少、缺 I-IV 梯度、缺低门槛 I 级、缺核心/终端牌、缺关键支点或终端跳跃过大等问题。该检查不会代替人工调平衡，但能让后续新增卡时先看到结构性缺口。

### 新增验证

- `tests/smoke_test.gd` 扩展路线平衡烟测：每条核心路线必须有结构化支点统计、合法平衡状态、可读平衡摘要，并且城市成长/合约供需/金融投机/怪兽压制/情报补给分别保留自己的关键支点。
- 完整 Godot headless smoke test 通过。

## 2026-07-01｜灾害保单、防御金融与图鉴语义整理

### 本轮实现

- 新增 `灾害保单 I-IV`：它们属于 GDP 金融牌的防御分支，只能匿名投保自己的城市；若持仓时间内即时 GDP 下跌或城市被毁，会把部分损失转成现金赔付。它与 `城市做空` 分离，避免“防守牌”和“攻击别人城市的做空牌”在 AI 与图鉴里混成同一类。
- AI 现在能把灾害保单识别为防御金融工具：在己方城市受损、商路断裂、怪兽逼近或路线威胁较高时，会把它作为护城/护路候选，而不是把它当成对敌方城市施压。
- 卡面、卡牌图鉴、关键字段和公开线索会把灾害保单显示为“保单/投保”，不再笼统显示成做空；结算仍保持匿名，只公开城市被挂上了保单或 GDP 金融合约。
- 清理未使用的 `MARKET_SKILLS` 历史常量：当前本局卡牌供应统一由 `COMMON_CARD_POOL + I级怪兽牌` 生成，区域再从这套牌池抽取可购买牌，避免继续出现“普通牌池/市场牌池”两套口径。
- 图鉴入口从“怪兽图鉴”调整为“怪兽生态档案”：怪兽牌统一归入卡牌图鉴的“怪兽牌”分类；生态档案只展示场上怪兽单位的自动行动概率、资源偏好、移动生态、伤害和击退数据，并提供对应召唤牌跳转。
- 修复区域购牌窗口快照语义：只锁定有效的落地区/相邻区/远程/全局补给窗口，`none` 无效窗口不再保存为锁价快照，避免旧的不可购买状态挡住后续实时怪兽落地判断；读档/烟测恢复时也会保留有效窗口资格。

### 新增验证

- `tests/smoke_test.gd` 扩展灾害保单断言：不能投保别人的城市，能记录为防御型 GDP hedge，并在己方城市 GDP 下跌时赔付。
- AI 阶段策略烟测新增灾害保单场景：己方受损城市应被选为投保目标，AI 候选上下文必须记录 `city_gdp_derivative_insurance`。
- 图鉴烟测改为保护“怪兽生态档案”语义：它不能表现成另一套怪兽牌图鉴，怪兽牌仍必须能跳到卡牌图鉴查看。

## 2026-07-01｜AI商品路线缺口评分

### 本轮实现

- 新增 `_ai_route_gap_adjustment()`：AI 购牌和出牌不再只看“当前能不能打”，还会按当前商品路线阶段识别缺口：补供给、补需求、放大 GDP、修复/保险、压制竞品。
- 缺口评分完全由卡牌字段推断，包括 `production_delta`、`consumption_delta`、`transport_delta`、`repair_routes`、`route_damage`、`route_flow_multiplier`、`gdp_bet_*`、合约增删供需字段等；新增卡只要补齐字段，AI 就能初步理解它服务哪条赚钱/压制链。
- AI 候选样本新增内部字段 `route_gap_bonus`、`route_gap_penalty`、`route_gap_reason`、`route_gap_field_match`，用于训练和 smoke test 观察；这些字段不进入玩家 UI，继续保持 AI 计划、手牌压力和路线桶隐藏。
- 修正区域经济牌目标判断的字段错位：`region_economy_shift` 现在使用 `consumption_delta` 判断消费刺激/消费冷却的正负，而不是旧的 `demand_delta`。

### 新增验证

- `tests/smoke_test.gd` 扩展 AI 商品路线测试：当 AI 处在“制造需求”阶段时，消费刺激类字段会比生产扩张更高分；购牌候选、出牌候选和训练元数据都必须记录路线缺口评分。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜公开角色、TCG图鉴与临时图标美术整理

### 本轮实现

- 角色卡重新固定为公开身份：角色池扩展到 21 张，开局准备可让 AI 席位选择“随机角色”，开局时从未占用角色中抽取，保证同局不重复。
- 角色卡与起始怪兽彻底解耦：角色不再写入首召怪兽 HP、速度、在场时间或固定技能数量；首召怪兽属性只来自独立选择的怪兽牌，避免公开角色暴露怪兽归属。
- 玩家可见 UI 移除 AI 压力桶/主路线/推荐路线等内部推理数据。经济总览和局势排名只显示公开异动、匿名卡牌余波、城市线索、天气、怪兽资金线索和已揭示归属。
- 卡牌图鉴详情页改成 TCG 式结构：卡面、牌面定位、费用与门槛、核心效果、关键字段、I-IV 升级梯度、匿名结算演出分区显示；缩略图 hover 预览不再把滚动条自动拉回底部。
- 程序临时美术增强：角色卡按名称种子绘制不同身份徽章纹样；怪兽牌根据飞行、水栖/瘴气、重甲/机械、火焰、潜地等特征使用不同卡面 motif；项目图标更新为星球、匿名卡牌和怪兽爪痕构图，并生成 `assets/icon.ico`。
- 已把桌面上的 `Space Syndicate Prototype.lnk` 与 `Space Syndicate Prototype - old local.lnk` 图标指向新的 `assets/icon.ico`。

### 新增验证

- `tests/smoke_test.gd` 新增/调整断言：随机 AI 角色必须解析为非重复公开角色；角色不能携带任何首召怪兽字段；角色被动仍能结算现金、购牌奖励和怪兽升级奖励；开局页和卡牌图鉴不得泄露 AI 内部路线；卡牌详情必须展示 TCG 式分区。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜AI压力推荐卡牌路线

### 本轮实现

- AI 对局压力摘要新增“推荐卡牌路线”：每个压力桶除了反制建议，也会提示玩家应优先找哪类卡牌路线，例如城市压制/金融做空、修路保险/情报追溯、怪兽诱导/天气干预、市场稳定/需求扩张等。
- 推荐路线由 `_ai_public_pressure_card_route_text()` 根据同一套 AI 压力条目生成，仍然不显示对手现金、手牌或弃牌；它只把公开路线压力翻译成可购牌/查图鉴的方向。
- 经济总览和局势排名现在把“AI在干嘛 → 怎么反制 → 找哪类牌”连成一条短链，帮助测试者从信息阅读转向实际决策。

### 新增验证

- `tests/smoke_test.gd` 扩展断言：局势排名和经济总览必须显示 AI 对局压力、反制建议和推荐卡牌路线，同时保持现金/手牌隐私。

## 2026-06-30｜AI压力反制建议

### 本轮实现

- AI 对局压力摘要新增“反制建议”：根据扩张GDP、护路防守、压制竞品、怪兽压制、金融投机、合约供需、情报补给和终局冲刺等压力桶，给出一条可执行应对方向。
- 经济总览和局势排名继续不显示对手现金/手牌，但现在会把“AI 在做什么”进一步翻译成“玩家可以怎么反制”，例如保护高GDP/同商品城市、修路/保险、观察怪兽偏好、稳价或制造伪线索。
- 反制建议由 `_ai_public_pressure_counterplay_text()` 从同一套 AI 压力条目生成，避免 UI 说明和 AI 实际路线数据脱节。

### 新增验证

- `tests/smoke_test.gd` 扩展断言：局势排名和经济总览必须同时显示 AI 对局压力、不泄露现金/手牌，并显示反制建议。

## 2026-06-30｜AI对局压力公开摘要

### 本轮实现

- 新增 AI 对局压力摘要：把 AI 的发展路线、阶段、商品路线和策略意图归纳为扩张GDP、护路防守、压制竞品、怪兽压制、金融投机、合约供需、情报补给或终局冲刺等公开压力桶。
- 经济总览和局势排名现在都会显示“AI对局压力”，并明确“不显示现金/手牌”；它帮助测试者看懂 AI 当前大致在扩张、守路还是攻击，但不泄露对手私密经济或手牌数量。
- 经济总览速览卡新增“AI压力”卡，与 GDP/min、商品热榜、商路/城市、匿名线索并列，方便玩家先看短信息，再读下方证据。

### 新增验证

- `tests/smoke_test.gd` 新增断言：局势排名和经济总览必须显示 AI 对局压力，并说明不显示现金/手牌；经济总览摘要卡必须包含 AI压力。

## 2026-06-30｜开局下一步结构化提示

### 本轮实现

- 主 HUD 的开局轻引导把“下一步卡片”从单句提示升级为三段式短卡：`行动`、`为什么`、`入口`。玩家能马上知道下一步做什么、为什么这一步会帮助赚钱/购牌/推进，以及该点哪里或按什么入口。
- 新增 `_opening_guide_next_step_card()`，保留 `_opening_guide_next_step_text()` 作为兼容文字输出；下一步提示现在是结构化数据，后续可以更容易接入图标、美术、按钮或教程高亮。
- 首召、建城、购牌、匿名出牌、经济总览与后续自由经营都会给出不同的行动理由和入口提示，继续保持主画面只给短信息。

### 新增验证

- `tests/smoke_test.gd` 扩展主 HUD 断言：开局轻引导必须显示开局进度、下一步卡片、`行动/为什么/入口` 三段和任务卡。

## 2026-06-30｜根菜单响应式卡片网格

### 本轮实现

- 根菜单入口从顺序长列表进一步升级为“分区标题 + 响应式卡片网格”：开局、局势、资料、存档、系统各自成组，组内入口会按可用宽度自动排成 1-3 列。
- 新增 `_add_main_menu_action_grid()` 与 `_main_menu_action_grid_columns()`，保留原有按钮、tooltip、hover/pressed 样式和回调，但把布局容器抽象出来，方便之后改成左侧栏、双栏卡片或更精美的首页。
- 主菜单交互提示同步改成“分区卡片网格自动重排”，让测试者知道入口层不是死板按钮堆，而是可以随屏幕与后续美术方案调整。

### 新增验证

- `tests/smoke_test.gd` 新增断言：根菜单必须存在带 meta 的响应式 action grid 与 grid card，并且交互提示要包含“分区卡片网格”和“自动重排”。

## 2026-06-30｜菜单交互提示与可重排UI原则

### 本轮实现

- 主菜单覆盖层新增统一的交互提示胶囊：根菜单提示“响应式主菜单、快捷 chips、卡片入口可重排、hover 用途”，子页面按自身类型提示缩略图、hover/单击预览、双击详情、上一页/下一页、返回缩略图等操作。
- 新增 `_menu_interaction_hint_text()` 与 `_menu_interaction_hint_style()`，把页面交互说明集中生成；后续如果把主菜单改成左侧栏、双栏卡片、瀑布流或全屏图鉴，不需要逐页重写提示逻辑。
- 卡牌/怪兽/商品图鉴会根据“缩略图页”和“详情页”展示不同交互提示，明确 hover、详情页切换和返回路径，避免玩家进入子页面后迷路。

### 新增验证

- `tests/smoke_test.gd` 新增断言：主菜单必须显示响应式/hover/可重排交互提示；卡牌图鉴缩略图页必须提示 hover 和双击详情；卡牌详情页必须提示上一页/下一页和返回缩略图。

## 2026-06-30｜AI发展路线多样性可视化

### 本轮实现

- 新增 AI 发展路线多样性审计：统计 AI 性格数量、核心路线覆盖、每条路线的主偏好 AI 数量，以及每个 AI 性格的主路线/副路线。
- 开局准备页的每个 AI 席位现在显示“主路线”，测试者在开始一局前就能看出对手大致会走城市成长、合约供需、金融投机、怪兽压制或情报补给哪条路线。
- 卡牌图鉴的路线总览新增“AI发展路线覆盖”卡，说明 6 类 AI 性格目前覆盖 5/5 条核心可追钱路线，并把这些路线如何落到最终钱上说清楚。

### 新增验证

- `tests/smoke_test.gd` 扩展路线平衡烟测：AI 主偏好必须覆盖五条核心路线，路线多样性摘要必须包含 5/5 覆盖和关键路线名。
- `tests/smoke_test.gd` 扩展 UI 断言：开局准备显示 AI 主路线，卡牌图鉴显示 AI发展路线覆盖。

## 2026-06-30｜菜单快捷导航底座

### 本轮实现

- 主菜单覆盖层新增常驻快捷导航 chips：开局、局势、经济、情报、规则、图鉴。玩家进入任何子页面后，可以直接跳到其他核心分支，不必先退回主菜单。
- 快捷导航与上一轮页面位置/帮助提示栏共用同一个菜单 shell；当前所在分支的快捷按钮会禁用，形成“当前位置”反馈，其他分支继续可点。
- `_add_menu_quick_nav_button()`、`_menu_quick_nav_active_key()`、`_refresh_menu_quick_nav()` 把导航逻辑集中起来，后续大范围调整菜单布局、美术、hover、详情切换时可以复用这一层。

### 新增验证

- `tests/smoke_test.gd` 新增断言：根菜单必须显示主要分支快捷入口；规则页必须把“规则”标成当前页，同时仍允许通过顶部“经济”快捷按钮跳到经济总览。

## 2026-06-30｜菜单导航提示与AI终局紧迫度

### 本轮实现

- 主菜单覆盖层新增统一的页面位置/帮助提示栏，显示“当前位置”、返回关系、hover/缩略图/详情页切换方式；根菜单、暂停菜单、开局准备、规则、经济、情报和各类图鉴都通过同一函数生成提示，方便之后大范围调整 UI 排版而不逐页硬改。
- AI 新增 `endgame_urgency` 评分：由距离现金目标、落后领先者的差距、终局倒计时剩余时间共同决定。
- 终局阶段的 AI 评分会使用该紧迫度：落后 AI 更愿意破坏领先城市、做空高风险 GDP、冲刺现金；领先 AI 更偏向修复、稳定市场和保护己方经济路线。
- `endgame_urgency` 写入观察向量、候选视图、实际决策样本和购牌/出牌元数据，后续训练与复盘能解释“为什么此时 AI 更急”。

### 新增验证

- `tests/smoke_test.gd` 新增主菜单/开局准备的页面位置提示断言，防止后续 UI 回退成无上下文子页面。
- `tests/smoke_test.gd` 扩展 AI 阶段烟测：终局倒计时压近时，落后 AI 的商路破坏评分必须高于无倒计时状态，并且出牌候选/训练样本必须携带 `endgame_urgency` 字段。

## 2026-06-30｜AI 购牌路线库存健康

### 本轮实现

- AI 区域购牌评分新增“路线库存健康”层：会统计当前手牌中同一发展路线的普通牌总数、可立即打出数、被商品流动卡住数和缺口。
- 如果 AI 已经囤了多张同路线但都因为商品流动不满足而暂时打不出，继续购买同类不可打牌会被扣分；如果新候选牌能立刻打出并缓解同路线无可用牌的问题，会获得加分。
- 这些字段会写入候选与实际购牌训练样本：`route_inventory_bonus`、`route_inventory_penalty`、`route_hand_total`、`route_hand_playable`、`route_hand_blocked`，方便后续训练和复盘解释 AI 为什么买或不买某条路线的牌。

### 新增验证

- `tests/smoke_test.gd` 扩展 AI 路线规划烟测：验证同路线手牌被流动卡住时，可打出的路线候选会获得库存加分，而继续购买同样被流动卡住的补给/情报牌会受到库存惩罚。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜卡牌图鉴路线总览

### 本轮实现

- 「卡牌图鉴」缩略图页新增数据驱动的卡牌路线总览，玩家打开图鉴时先看到城市成长、合约供需、金融投机、怪兽压制、情报补给五条核心路线。
- 每条路线卡显示卡牌数量、平均强度预算、完整 I-IV 梯度组数、路线目标、AI 偏好覆盖数量和代表样例牌。
- 该总览直接复用 `_development_route_audit()` 与 `_ai_development_route_preference_audit()`，和 AI 评分/平衡审计使用同一套路线定义，避免 UI 说明和实际 AI 理解脱节。
- 路线审计继续扩展为平衡视图：每条路线现在会统计强度预算最低/最高/均值、预算分布、打法说明、反制窗口和 AI 调权提示；卡牌图鉴总览直接展示「强度区间」「打法」「反制」和预算分布，方便后续调平衡时判断某条路线是否只有堆数值、是否缺少反制。

### 新增验证

- `tests/smoke_test.gd` 新增断言：卡牌图鉴首页必须显示「卡牌路线总览」、城市成长路线、金融投机路线和 AI 偏好信息。
- `tests/smoke_test.gd` 扩展路线平衡审计：五条核心路线必须有有效预算区间、预算分布，并能生成包含强度区间、打法和反制窗口的平衡摘要。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜开局轻引导任务面板

### 本轮实现

- 主画面的「开局轻引导」从纯文本 checklist 升级为任务面板：显示开局进度、下一步卡片、五个任务小卡和可关闭状态。
- 五个任务对应 72 小时目标里的轻量提示：首召怪兽、建第一城、买第一牌、匿名出牌、看经济总览。每张任务卡都有完成状态、短标题和一句行动说明。
- 面板顶部保留「经济总览」快捷入口，底部新增「新手引导」和「游戏规则」快捷按钮；测试者不读长规则，也能按当前下一步推进。
- 旧的完成状态、经济总览已读状态和关闭状态继续保存到 run state，避免 UI 美化破坏存档行为。

### 新增验证

- `tests/smoke_test.gd` 新增断言：开局轻引导必须展示开局进度、下一步卡片、任务卡，以及新手引导/游戏规则快捷入口。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜终局结算速览卡片

### 本轮实现

- 「终局结算」页在详细复盘文本和赛后入口按钮上方新增终局速览卡：胜者、钱从哪里来、关键地图、关键影响。
- 胜者卡显示最终赢家与结算资金；钱源卡拆出城市经营、卡牌/情报收益、角色收益的领先玩家；关键地图卡展示关键城市或地图破坏/怪兽数量；关键影响卡汇总关键卡牌、怪兽影响和 AI 路线。
- 终局速览复用现有 `_final_run_summary_text()` 相关统计函数，不引入第二套结算口径；短卡片负责第一眼解释，长文本负责完整复盘。

### 新增验证

- `tests/smoke_test.gd` 扩展终局烟测：终局菜单必须显示「终局速览」「胜者」「钱从哪里来」「关键影响」，同时仍保留局势排名、经济总览、开局准备三个赛后入口。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜长文本菜单卡片摘要层

### 本轮实现

- 新增通用菜单摘要卡组件：`_show_menu_summary_cards()` 与 `_add_menu_info_card()`，可按屏幕宽度自动排成 1-3 列，用统一面板、标题、正文、脚注和主题色呈现短信息。
- 「游戏规则」页新增规则速览卡：先召怪兽、建城赚钱、匿名出牌、手牌隐私。玩家不用先读整段规则，也能抓住一局开始和胜利目标。
- 「局势排名」页新增局势速览卡：终局条件、当前玩家可见资金、城市现金流、反超方向。长文本仍保留完整结算解释，卡片层先给决策方向。
- 「经济总览」页新增经济速览卡：当前 GDP/min、商品热榜、商路/城市前景、匿名线索数量。这样经济页既能保留详细证据，也更像商业化前的可读仪表盘。

### 新增验证

- `tests/smoke_test.gd` 新增断言：规则页、局势排名和经济总览都必须有卡片化摘要层，防止这些关键入口退回纯长文本。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜菜单 UI 组件化与滚动面板骨架

### 本轮实现

- 主菜单覆盖层从单一居中面板升级为响应式菜单面板：标题与导航固定在上方，正文、图鉴预览、开局准备和各类子菜单内容进入统一滚动列，避免长规则/长图鉴把页面撑爆。
- 新增 `menu_surface_panel`、`menu_content_scroll`、`menu_content_box`、`menu_nav_row`、`menu_catalog_nav_row` 等可测试容器；后续大范围调整主菜单、子菜单、hover 和详情切换布局时，可以围绕这些组件改，而不必逐页拆 UI。
- 抽出 `_menu_surface_style()`、`_style_menu_button()`、`_menu_section_style()`，统一菜单面板、胶囊按钮、hover/pressed/focus/disabled 状态和 section 卡片视觉。
- 主菜单入口、图鉴入口、卡牌筛选、缩略图翻页、角色/怪兽详情跳转、开局准备的席位/AI/深度/角色/起始怪兽按钮都接入同一套样式，先把“默认控件感”压下去，后续美术可以继续替换配色和卡面。

### 新增验证

- `tests/smoke_test.gd` 新增 UI 骨架断言：主菜单必须有可复用响应式面板，正文和预览必须位于可滚动内容列中，按钮必须暴露 hover/pressed 样式状态。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜AI 发展路线偏好与卡牌平衡审计

### 本轮实现

- 把卡牌策略归并成 AI 可读的五条核心发展路线：城市成长、合约供需、金融投机、怪兽压制、情报补给；天气、新闻和破坏牌会并入怪兽压制/干扰路线，补牌和购牌范围会并入情报补给路线。
- 新增路线审计函数，能从同一套卡牌数据统计每条路线的卡牌数量、强度预算、I-IV 梯度样本和代表卡，方便后续调平衡时先看路线覆盖，而不是只看单张卡名。
- 扩展 AI 性格池：除拓荒、套利、破坏、驯怪外，新增合约型和情报型 AI；每个 AI 都有 `route_preferences`，购牌和匿名出牌评分会按路线偏好加权。
- AI 训练样本新增 `development_route`、路线标签、偏好倍率和路线加分；结算后的学习标签也会记录路线，使后续新增卡牌可以通过字段和路线被 AI 理解，而不是依赖硬编码卡名。

### 新增验证

- `tests/smoke_test.gd` 新增发展路线验收：五条核心路线都必须有卡牌覆盖、强度预算、完整 I-IV 梯度样本，并且至少有一个 AI 性格偏好该路线。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜菜单卡片化与可持续 UI 调整基础

### 本轮实现

- 主菜单入口从一串裸按钮改成卡片式操作入口：每个入口都有标题、简短用途说明、统一边框/底色/圆角和 tooltip，方便玩家理解“开局准备、局势排名、经济总览、情报档案、规则、图鉴”等分支分别做什么。
- 抽出 `_menu_card_style()`、`_add_menu_action_card()`、`_add_main_menu_action()` 等复用函数；主菜单、图鉴入口和终局复盘入口都开始使用同一套菜单卡片组件，后续要整体调整排版、颜色、hover 说明或按钮样式时可以集中修改。
- 图鉴入口继续保留缩略图、hover 预览、双击详情、详情页前后切换和返回缩略图的交互；本轮把“入口层”的视觉语言先统一，为后续继续美化各图鉴详情页打底。

### 新增验证

- `tests/smoke_test.gd` 新增主菜单布局断言：根菜单不仅要保留开局准备、情报档案和图鉴等按钮，还必须显示描述型卡片文案，防止 UI 回退成无说明的裸按钮列表。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜新闻卡牌化与星球天气预报

### 本轮实现

- 移除旧的被动新闻事件计时器：新闻不再由世界随机触发，只能由玩家匿名打出的新闻类卡牌制造。
- 新增新闻类卡牌路线：舆论操控、热搜推送、危机快讯、金融传闻、监管风暴会通过字段驱动改变区域热度、区域生产/交通/消费、商品供需压力、市场波动或商路断损，并在城市公共线索中留下可推理痕迹。
- 新增星球天气系统：顶部状态栏显示“活跃天气 + 下一条预报”，星球地图面板上方也有紧凑天气预报条，分别显示当前天气、下一条预报和生产/交通/消费倍率影响；预报通常提前 60-180 秒公开，每次天气影响 1-5 个区域，生效后按秒进入 GDP/min 和金融买涨/做空结果。
- 新增天气干预牌：太阳风暴预报、酸雨云团播种、引力潮汐播报、电磁雾干涉。玩家可以匿名改写下一条天气预报，但所有玩家都会看到天气类型、倒计时和影响区域，方便提前建城、保护商路、做空目标或引怪兽。
- 卡牌图鉴新增“新闻事件”和“天气干预”子分类；卡面/详情页会显示新闻信息战、天气博弈、预告时间、影响区域数、持续时间、强度预算和反制/门槛信息。AI 也会把这些字段纳入通用评分，而不是只识别固定卡名。

### 新增验证

- `tests/smoke_test.gd` 验证 `main.gd` 中没有被动新闻计时器/旧世界新闻入口。
- 验证地图面板天气条可见，并且天气预报提前 60-180 秒、影响 1-5 个区域，在生效后改变 GDP 相关倍率与 UI 文案。
- 验证新闻牌和天气干预牌能通过结算器执行；同时验证所有图鉴可见卡牌和生成怪兽固定技能都有结算处理器。

## 2026-06-30｜AI 竞品压制执行与弹性出牌门槛

### 本轮实现

- AI 的 `disrupt_competitors` 意图现在会在中局/后期已有己方城市、且同商品竞品压力较高时获得额外权重；同时对“继续扩张焦点”加入竞品牵制扣分，避免 AI 只会闷头长经济。
- 匿名出牌上下文为新闻、天气干预、商路黑客/舆论转移等压力牌补充 `target_city`、`target_owner` 元数据，训练样本能明确记录“打的是哪个城市/谁的城市”，后续新增卡牌也能通过字段进入学习。
- AI 对没有固定 `play_product` 的卡牌新增弹性商品门槛选择：优先使用目标/路线/焦点商品；若该商品流动不够，会自动改用自己当前满足门槛的商品流动打牌。这样商路黑客、新闻、天气等“效果目标”和“支付门槛”不会被错误绑定成同一个商品。

### 新增验证

- `tests/smoke_test.gd` 扩展 AI 策略意图烟测：不只验证候选评分，还验证 AI 能把防守路线牌和压制竞品牌真正排入匿名出牌队列，并把策略意图写入训练记忆。
- 商品路线计划烟测现在也验证 `attack_rival` 阶段会实际打出商路黑客，目标为竞争城市，且出牌记录携带路线阶段与目标城市元数据。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜实时现金流、全局市场刷新与单购牌窗口

### 本轮实现

- 取消“经营周期发钱”的当前规则口径：城市收入现在由即时 `GDP/min` 线性按秒流入玩家现金，内部每秒结算一次并保留小数尾差，避免周期跳变。
- `_market_tick()` 改为“全局市场刷新”：每 30-60 秒公开重估供需、价格、商路网络、城市 GDP 快照和 AI 商业动作；它不再直接支付城市收入。
- 临时经济效果统一支持秒数字段：`contract_seconds`、`route_flow_seconds`、`growth_seconds`、`market_contract_seconds`；旧 `*_turns` 字段只作为兼容换算，UI 显示为剩余秒数/分钟。
- GDP 买涨/做空保持真实时间持仓，到期按即时 GDP 涨跌结算；城市受损、商路断裂、供需变化都会先反映到 GDP/min，再影响现金流和金融牌收益。
- 区域购牌窗口加入“单窗口”限制：同一玩家打开新区域补给时，会关闭旧区域补给/弃牌购买机会，防止沿怪兽路径囤多个窗口；读档恢复窗口时会保留保存中的私密弃牌选择。
- 主菜单、规则、轻教程、局势排名、经济总览、卡面和图鉴文案改为 `GDP/min`、实时现金流、全局市场刷新口径。

### 新增验证

- `tests/smoke_test.gd` 的 AI 完整局、八席 AI 局、存档恢复、经济卡、GDP 趋势、临时经济效果倒计时和卡牌梯度烟测已迁移到实时现金流/全局刷新语义。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜金融牌按时间持仓与购牌窗口快照

### 本轮实现

- `城市买涨I-IV` 与 `城市做空I-IV` 从“持续若干经营周期”改为真实时间持仓：I/II/III/IV 分别持仓 60/75/90/120 秒。
- GDP 金融牌开仓时记录 `created_time`、`expires_at`、`duration_seconds` 和开仓即时 GDP；正常游戏在持仓到期时按即时 GDP 涨跌和倍率结算，城市被摧毁时仍会触发做空/破产清算。
- 卡面、卡牌图鉴、强度预算、AI 候选理由和结算演出文案都改为显示“持仓 X 秒/分钟”，不再把金融投资描述成周期牌。
- 区域购牌窗口改为按打开瞬间锁定资格和价格：点开某区域时若怪兽在该区或相邻区，玩家可以继续选牌并购买，即使怪兽随后离开；远程/全局补给也锁定当时倍率。
- 购牌改为随时场上动作，不再被普通行动冷却阻挡，也不会给玩家追加购牌冷却；满手买新牌仍进入私密弃牌流程，手牌数量和弃牌内容不公开。

### 新增验证

- `tests/smoke_test.gd` 验证 GDP 买涨/做空会记录真实秒数持仓窗口，并通过强制到期结算验证上涨/下跌兑现。
- 区域购牌烟测新增“窗口快照”场景：打开怪兽落地区补给后让怪兽离开，实时资格变为不可买，但当前窗口仍保持落地区八折并能完成购牌；同时验证购牌不受行动冷却阻挡。

## 2026-06-30｜城市 GDP 趋势与破坏可见性

### 本轮实现

- 城市经营周期现在会记录公开 GDP 历史：本期 GDP、较上期变化、最近路径、结算周期来源和简短原因摘要。
- GDP 原因摘要继续从同一份收入拆解生成，覆盖生产、消费、过境、永久加成、临时合约、同业竞争、断路和区域/城市损伤；不额外硬编码卡名。
- 经济总览的商路收入前景、区域图鉴的城市公开信息和城市收入明细都会显示 `GDP趋势`，让玩家能看到怪兽破坏、商路受损、供需变化最终如何落回城市 GDP。
- 该趋势属于城市公开经营表现；玩家手牌数量、弃牌内容和购牌换购压力仍为私密信息，不进入公开经济轨道。

### 新增验证

- `tests/smoke_test.gd` 新增 GDP 历史烟测：先记录受损前 GDP，再增加区域损伤并记录受损后 GDP，验证城市会保留至少两期历史、`last_gdp_delta` 为负、经济总览和区域图鉴都能看到 `GDP趋势`。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜卡牌强度预算说明层

### 本轮实现

- 卡牌新增字段驱动的“强度预算”说明：从 `cost`、现金/GDP、产交消、商路、伤害、防护、抽牌、补给范围、合约、GDP 买涨/做空、怪兽 HP/移动/在场时间等字段推导预算分与档位。
- 预算档位显示为“基础频用 / 效率扩张 / 路线核心 / 终端压力”，并结合 I-IV 等级解释该等级在路线中的定位：I 级开路线、II 级提效率、III 级成核心、IV 级终端但需保留反制空间。
- 手牌卡面、卡牌图鉴悬停预览、卡牌详情页和 tooltip 现在都能看到强度预算、主强度来源和制衡点；升级预览每一级也显示对应预算档。
- 预算说明不引入新的卡牌硬编码表，继续从同一套卡牌数据字段生成，方便后续新增卡牌直接获得 UI 解释。

### 新增验证

- `tests/smoke_test.gd` 新增强度预算烟测：验证经济牌和怪兽牌都能生成“强度预算 / 主强度 / 制衡”文本。
- 卡牌图鉴悬停预览和详情页测试新增预算可见性断言。
- 卡牌梯度烟测新增预算分不倒退检查，防止 I-IV 效果增强但预算说明反向变弱。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜私密弃牌与手牌隐私闭环

### 本轮实现

- 购牌流程接入普通手牌上限处理：购买新普通牌会超出 5 张上限时，不再直接拒绝，而是在当前玩家自己的手牌面板弹出“私密弃牌确认”，选择一张旧普通牌弃掉后完成换购。
- 重复获得同系列卡仍优先自动合成升级到 II/III/IV，不触发弃牌；绑定固定怪兽技能继续不计入普通手牌上限。
- 手牌数量、弃牌选择、弃掉了哪张牌都只进入本人私密经济流水；公共日志只保留模糊的匿名购牌完成线索，不写买家、具体卡牌、手牌数量或弃牌状态。
- 主玩家面板在查看 AI / 对手席位时不再展示其现金、手牌数量或卡面，只提示“对手手牌为私人信息”，避免主界面泄露推理对象的手牌压力。
- 角色额外拿牌与区域补给抽牌的公共提示改为模糊描述，避免通过“成功拿到几张/没拿到”间接暴露手牌是否满。
- AI 购牌评分新增手牌压力处理：满手可换购，但会按被弃旧牌的保留价值扣分；暂时打不出的牌在手牌接近上限时会额外降分。训练样本新增 `playability_bonus`、`hand_pressure_penalty`、`requires_discard`、`discard_keep_value`、`counted_hand` 等字段。
- 游戏规则与轻教程文案补充“满手买新普通牌需私下弃旧牌，手牌数量与弃牌记录不公开”。

### 新增验证

- `tests/smoke_test.gd` 新增满手换购烟测：验证满手购买新牌会打开私密弃牌面板，确认后普通手牌仍为 5 张、旧牌被替换、新牌进入手牌、本人流水记录“弃牌换购”，公共日志不泄露新牌/旧牌/弃牌内容。
- 同一烟测验证满手重复购入同系列牌会直接升级，不触发弃牌。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜72小时目标第一轮落地：AI阶段策略、轻提示与终局复盘

### 本轮实现

- 卡牌说明新增字段推导的“策略路线/用途”层：城市成长、城市压制、金融投机、合约博弈、情报推理、怪兽路线、补给构筑等路线会从 `kind` 和效果字段推导，显示在手牌卡面规则、卡牌图鉴悬停预览和卡牌详情页。
- AI 现在会为每个席位记录并使用 `opening / midgame / endgame` 局势阶段，以及 `leader / contesting / trailing` 竞争态势。
- AI 的建城、购牌、出牌、匿名商业行动、策略意图和训练样本都接入阶段字段：开局优先首召、建城和基础经济；中局围绕商品路线扩 GDP；后期领先者偏防守/现金，落后者更偏向做空、商路破坏和压制领先城市。
- AI 决策样本新增阶段元数据：`game_phase`、`competitive_posture`、`score_gap_to_leader`、`leader_index`、`phase_bonus`，后续新增卡牌仍优先通过字段进入评分，而不是只靠卡名硬编码。
- 主游戏玩家面板新增一行短“目标提示”，只提示当前最可能的下一步：首召怪兽、城市化、购牌、回应合约、指定目标、终局倒计时或匿名出牌。
- 主游戏玩家面板新增“开局轻引导（可关闭）”：前 1-2 分钟用短清单提醒首召怪兽、建城、从怪兽补给范围购牌、匿名出牌、查看经济总览；面板会显示当前下一步，经济总览步骤只有在玩家实际打开过后才打勾，关闭状态和经济总览查看进度都会随本局存档保存。
- 终局结算新增自动弹出的“终局结算”复盘页，并把“终局总结”和“玩家概览”同时写入日志和局势排名页，解释赢家、钱从哪里来、每个席位的最终资金/城收/卡牌收入/终局情报现金/角色收入/城市数、关键卡牌、怪兽影响、AI 主要路线、关键城市、存活城市/毁坏区域；复盘页提供局势排名、经济总览和开局准备入口。

### 新增验证

- `tests/smoke_test.gd` 新增 AI 阶段策略烟测：验证开局/中局/后期、领先/落后态势、阶段加权和训练样本字段。
- 新增卡牌策略说明烟测：验证经济、GDP投机、情报、怪兽路线都能生成字段化策略摘要；卡面 stats 和卡牌图鉴预览/详情会展示策略路线。
- 新增 AI 推进烟测：加速跑过 AI 首召怪兽、自动建城、区域购牌、匿名出牌、匿名商业压制、经营收入，并把领先 AI 推入终局倒计时，防止“能开局但后面停摆”。
- 新增最大席位完整局烟测：临时开启 8 席 / 7 AI / 深度V 星球，验证 7 个 AI 都能获得角色与起始怪兽牌、首召怪兽、自动建城、购牌、至少产生后续出牌/匿名商业/经营收入/决策样本，并进一步触发现金目标、保存/恢复终局倒计时、完成最终结算、显示终局总结与 AI 路线、写入 7 个 AI 的 episode reward 学习结果，最后恢复原局面。
- 终局倒计时测试现在也验证终局总结会出现在日志、自动终局复盘页和排名文本中，并覆盖关键卡牌、怪兽影响、AI 路线、玩家概览、城收字段和赛后入口按钮。
- 主面板测试验证短目标提示、当前下一步、可关闭开局清单、经济总览真实查看进度、经济总览快捷入口和存档恢复，同时复杂经济/角色细节仍不回流到主面板。

## 2026-06-30｜规则重构与可玩原型同步点

### 当前版本定位

《太空辛迪加》已经从早期“守护者 vs 怪兽 / 区域押注”的原型，推进为一个实时匿名商业战争原型：

- 玩家是外星辛迪加经营者，目标不是直接操控怪兽，而是通过城市化、商品流通、匿名卡牌、合约与怪兽灾害，把最终资金做大。
- 当前方向转为 PVE roguelike：每局 3-8 个总席位，其中 2-7 个为 AI 对手，至少保留 1 个真人/本地玩家席位。
- 胜利最终统一落到“钱”上：现金、幸存城市价值、商业收入、情报猜测奖惩都会折算到结算资金。
- 怪兽全部自动行动，没有玩家长期可控单位；玩家只能通过卡牌产生一次性的诱导、技能释放、夺取归属或召唤/升级效果。
- 主画面保持简洁：地图、匿名卡牌轨道、当前玩家手牌；规则、图鉴、经济详情和区域详情收纳到菜单分支。

### 已落实的核心系统

#### 菜单与图鉴

- 主菜单逻辑已整理为清晰分支：开局准备、继续/保存、局势排名、经济总览、情报档案、新手引导、游戏规则、统一图鉴。
- “选择怪兽”不再是主菜单分支；新游戏开始前进入开局准备，可设置 3-8 个总席位与 2-7 个 AI 对手，并为每名玩家选择外星角色卡。
- 图鉴统一包含：
  - 角色图鉴
  - 怪兽图鉴
  - 卡牌图鉴
  - 商品图鉴
  - 区域图鉴
- 卡牌图鉴不再单独拆“怪兽卡牌”主分支；怪兽卡属于统一卡牌池中的一个子分类。
- 怪兽图鉴默认进入响应式缩略图册：每页显示的怪兽缩略图行列会按屏幕空间估算；悬停/单击怪兽可在图册下方查看 HP、速度、资源偏好、行动摘要和对应怪兽卡；双击缩略图进入怪兽详情；详情页才显示上一只/下一只，并可返回缩略图册。
- 卡牌图鉴默认进入响应式缩略图册：每页显示的缩略图行列会按屏幕空间估算；悬停/单击卡牌可在图册下方查看详情预览；双击缩略图进入卡牌详情；详情页才显示上一张/下一张，并可返回缩略图册。
- 商品图鉴也默认进入响应式缩略图册：每页显示的商品缩略图行列会按屏幕空间估算；悬停/单击商品可在图册下方查看价格、供需、经济天气和城市线索预览；双击缩略图进入商品详情；详情页才显示上一个/下一个，并可返回缩略图册。
- 卡牌与怪兽都已接入临时程序美工，后续可替换为正式卡面和怪兽立绘。

#### 外星角色卡

- 环港走私议会：开局资金 `+¥80`、起始怪兽移动 `+15%`；在含“环晶电池”的区域购牌时免费额外获得 1 张同区候选牌。
- 深海菌毯使团：起始怪兽生命 `+8`、在场时间 `+12秒`；己方含“深海菌毯”的城市每个经营周期额外 `+¥55`。
- 重力矿联董事会：起始怪兽生命 `+12`；己方含“重力陶瓷”的城市每个经营周期额外 `+¥45`。
- 离子军购局：起始怪兽额外获得 1 张绑定技能；己方怪兽升级时 `+¥120`。
- 光合修复会：开局资金 `+¥120`、起始怪兽在场时间 `+20秒`；己方含“光合凝胶”的城市每个经营周期额外 `+¥40`。
- 虹膜数据券商：开局资金 `+¥60`；在含“活体芯片”的区域购牌时免费额外获得 1 张同区候选牌。
- 星鲸餐饮垄断：己方含“星鲸罐头”的城市每个经营周期额外 `+¥50`；己方怪兽升级时 `+¥60`。
- 静电蜂巢银行：起始怪兽移动 `+8%`；在含“静电蜂蜜”的区域购牌时免费额外获得 1 张同区候选牌。
- 星图审计庭：每局 2 次身份侦测，可私下查明当前陌生城市真实业主；城市归属终局命中奖励 `+¥40`。
- 幽幕播报社：每局 1 次出牌追帧，可私下追溯一张匿名轨道牌的真实出牌者；卡牌归属竞猜押注成本 `-¥40`。
- 双边密约公证团：每局 2 次合约回溯，可私下查明匿名合约出牌方与目标业主；合约类卡牌商品流动门槛 `-1`。
- 碎光私探行会：卡牌归属竞猜押注成本 `-¥30`，猜中额外 `+¥30`；起始怪兽在场时间 `+8秒`。
- 星门补给商会：可从怪兽所在区相邻区域的相邻区域购买卡牌；二跳购牌价格 `×1.10`；开局资金 `+¥40`。
- 资源收益、购牌赠牌、怪兽升级返现、情报侦测/追溯、押注修正、合约门槛折扣和远程补给已经接入实际结算、经济流水、地图提示与烟测，不是仅写在卡面上的占位描述。

#### 地图与城市

- 地图采用球面世界模型：
  - 拉远时看到宇宙中的球形星球。
  - 贴近时看到局部被投影成平面 XY 坐标视图。
  - 左右、上下边界在球面意义上连续。
- 每局按 Roguelike 挑战深度 I-VI 随机生成星球：浅层星球较小，约 6-9 个区域，甚至可以低于 10 区；深层星球逐步扩大到几十个区域，目前 VI 层约 40-54 区，同时提高通关现金目标。
- Roguelike 目标继续统一落到“钱”上：玩家要尽量保护自己的城市收入、破坏对手的收入来源，并赚到足够结算资金，才能挑战更大的星球。
- 结束条件已改为现金线触发：任一玩家的可见预估结算资金达到本层目标现金后，会启动保存进局面的匿名 60 秒终局倒计时；倒计时期间所有玩家仍可行动且不知道是谁触发，倒计时结束后按最终结算资金最高者获胜。若所有区域提前毁灭，则立即终局。
- 陆地区域可城市化，初始拥有 1 种生产商品与 1 种需求商品。
- 海洋也会生产海域商品，并继续主要承担运输/商路区域职责。
- 城市归属默认隐藏；玩家可对城市做私人归属标注。
- 城市会保存结构化的最近公开线索历史，记录时间、线索类型、商品关键词和文本，用来回看匿名商业动作、合约签拒和经营改造留下的推理证据；商品图鉴会优先打开当前选中的商路商品，并按该商品过滤这些城市线索。
- 区域有 HP / damage 轨道，怪兽移动、资源吸取、战斗、击退都会破坏区域和城市。

#### 商品、GDP 与商路

- 商品池已扩展为多种外星商品。
- 商品流动拆成两个大块：
  - 流动量：由生产与需求关系决定。
  - 流动速度：由公共交通/运输水平决定。
- 城市收入统一看 GDP：
  - 生产区看可流通出去的生产量。
  - 交通区看经过该区的商品流通。
  - 消费区看需求被满足的消费量。
- 商品价格由供需、商路破坏、持续合约与经济天气影响，不允许玩家直接手动设置市场价格。
- 地图可按商品显示商路；商路途经区域被破坏会影响相关城市收入。

#### 怪兽

- 守护者概念已并入怪兽体系，不再保留旧的守护者/怪兽分裂函数。
- 怪兽通过怪兽卡召唤；基础规则下每名玩家同时最多归属1只在场怪兽，同名怪兽牌会优先升级/刷新该怪兽。`孪星兽栏同盟` 可把自己的怪兽归属上限提高到2。
- 玩家开局通过角色卡获得起始怪兽卡；一级起始怪兽可无区域限制首召。
- 后续怪兽卡可有区域/地形/怪兽邻接限制。
- 怪兽卡在场期间再次打出同名怪兽卡，可升级场上怪兽并刷新 HP 与在场持续时间。
- 所有卡牌重复获得都会自动合成升级，最高 IV 级，等级使用罗马数字显示。
- 怪兽有：
  - HP
  - 移动速度
  - 在场持续时间
  - 资源偏好
  - 自动行动概率表
  - 移动踩踏伤害
  - 资源吸取伤害
  - 战斗/击退伤害
- 怪兽相遇会根据行动表使用招式，造成伤害、击退和区域破坏。
- 怪兽受到伤害时，其隐藏归属玩家按最大生命等比例损失金钱；这会成为推理线索。

#### 卡牌

- 卡牌不再充能。
- 一次性卡牌打出后立即离手，进入匿名卡牌轨道，公开展示后结算。
- 固定技能牌不计入手牌上限。
- 普通手牌上限暂定为 5 张。
- 获取卡牌要花钱；默认只能从怪兽所在区域或相邻区域购买：
  - 怪兽所在区域八折。
  - 相邻区域原价。
  - 角色能力或补给牌可扩张到二跳或全局购牌，但会按远程/全局倍率加价；该范围只影响购牌，不改变后续怪兽牌的召唤区域限制。
- 购买重复卡牌自动升级，最高 IV。
- 卡牌购买价格按 I 级基准价；升级后效果增强但价格沿用 I 级价格。
- 打出卡牌通常不消耗商品，但必须满足玩家城市提供的商品流动条件。
- 部分卡牌会有额外现金打出费用，例如场上怪兽越多，召唤怪兽卡越贵。
- 需要指定怪兽目标的卡牌，打出时会先询问目标怪兽。

#### 匿名卡牌轨道、竞价与归属猜测

- 所有卡牌打出都会匿名公开展示，不显示出牌玩家。
- 空轨道第一张牌进入 0.5 秒同时出牌判定。
- 若同时窗口内只有一张牌，则直接进入 5 秒公开展示。
- 若有多张牌，则进入一次 5 秒匿名竞价。
- 竞价按钮支持快速加价：10、20、50、100、200、500、1000。
- 一个批次只竞价一次；锁定后按报价与顺时针顺序逐张展示/结算。
- 批次展示或相位响应期间新打出的牌进入下一批等待区，不重开竞价。

### 本轮增量：固定相位窗口、分型军队、军队/怪兽上限角色、原创命名清理

- 相位否决不再做“瞬时检查”。每张可被反制的匿名牌会先公开展示5秒，展示结束后统一进入固定5秒相位响应窗口；无论是否有人实际持有相位否决，玩家都会看到这个询问窗口。没人反制时原牌才结算。
- 新增 `相位否决 I-IV` 作为科幻版反制牌，并新增公开角色 `悖论兽契社`：它可以在相位响应窗口把手中任意怪兽牌临时改写成相位否决，消耗原怪兽牌但不暴露该怪兽牌原本归属。
- 新增军队牌体系并归入统一卡牌池：`行星防卫军 I-IV`、`制空战斗机 I-IV`、`轨道轰炸机 I-IV`、`重装坦克 I-IV`、`导弹阵地 I-IV`、`潜航舰队 I-IV`、`星海战舰 I-IV`。军队不会自主行动，只通过私有可回收军令牌执行前进、保卫区域、摧毁区域、攻击怪兽；军队受伤不会让操控者损失怪兽式资金，也不会公开下令者。
- 军队移动规则改成地形适配：空中单位可广域部署且移动快，地面单位偏陆地，海上单位偏海洋；坦克/导弹阵地、潜艇/战舰等会按 `terrain_move_multiplier` 与 `military_deploy_terrain` 字段限制部署和移动效率。军队移动本身不会造成怪兽式建筑踩踏，但军事打击或武装压力可以产生短时 GDP 压力和商路压力，并进入城市收入拆解。
- 军队卡面、图鉴事实、AI 泛字段评分和地图 token 临时美工已区分战斗机、轰炸机、坦克、导弹、潜艇、战舰等形态，避免测试时全部像同一张占位卡。
- 控制上限改为字段驱动：普通角色默认同时最多归属1只怪兽、1支军队；新角色 `孪星兽栏同盟` 可同时归属2只怪兽，`蜂巢防务议会` 可同时维持2支防卫军。角色卡面会公开显示“怪兽上限:2”或“军队上限:2”。
- 怪兽达到IV后，同名怪兽牌不会因上限被误挡，而是刷新HP、在场时间和绑定技能；夺取怪兽也会遵守当前角色的怪兽归属上限。
- 清理版权/旧桌游占位命名：直接互动牌改为 `星链拆解`、`影仓牵引`、`轨道齐射`；怪兽和技能使用 `流星哨兵`、`棱刃重甲`、`焰环幼星`、`蓝锋骑士` 等原创名；测试和程序 motif 字段也改成原创语义。
- 角色牌平衡仍是后续专项：本轮先保证上限型角色可运行、可显示、可测试；之后需要为角色被动建立类似卡牌强度预算的角色预算，并用模拟局看胜率/路线偏差。
- 新增 `docs/balance_audit.md` 作为开发用平衡审计快照：记录当前 24 张角色、46 种商品、239 个静态卡牌/技能条目、22 个完整 I-IV 梯度家族，以及城市、合约、金融、怪兽、军队、情报、直接互动、天气/新闻、商品经济等路线的收益/风险/反制缺口。
- 当前批次结束后，下一批等待牌统一进入一次新竞价；若只有一张则直接展示。
- 小费支付给上一张结算卡牌的真实出牌者，但付款者与收款者身份仍不公开。
- 顶部轨道显示历史、当前、候补、下一批等待卡牌；玩家可横向拖动查看。
- 玩家可随时猜轨道上某张牌属于哪个玩家：
  - 猜对：真实出牌者付钱给猜测者，并公开贴上归属标签。
  - 猜错：猜测者付钱给真实出牌者，但不公开真实归属。
- 主菜单新增“情报档案”分支，用来集中查看当前玩家的城市业主私标、标注置信度、标注理由、城市调查优先级、卡牌归属押注状态、怪兽受伤资金线索、城市公开线索，以及这些情报如何在终局或即时竞猜中折算为钱；该页面只整理可见证据，不提前揭示真实业主或对手现金。情报档案现在也会生成线索跳转按钮，可直接打开相关区域、卡牌、怪兽、商品或经济总览，并从图鉴页返回情报档案继续推理；玩家也可以在情报档案中直接设置或清除城市业主私人标注，并把每条标注调成低/中/高置信度、记录为商品竞争/商路线索/卡牌条件/怪兽资金/直觉等理由。城市调查优先级由潜在GDP、竞争、断路、公开线索、未标注状态和低置信标注综合得出；置信度、理由和优先级只用于推理管理，不改变终局奖惩。

#### 合约牌

- 区域供需合约牌已成为商业/合约卡分类的一部分。
- 打出前必须先在地图点选两个区域：
  - 供给区
  - 需求/签约区
- 前 5 秒公开展示阶段只展示：
  - 两个已选区域
  - 商品
  - 合约奖励
  - 拒签惩罚
  - 出牌条件
- 公开展示结束后，目标城市真实业主再获得独立 5 秒签约决定窗口。
- 这个签约窗口只留在目标玩家窗口中，不阻塞其他玩家继续打牌。
- 超时视为拒签。
- 合约可设计为添加、替换、删除生产/需求商品，并可附带现金奖励、罚款、生产/交通/消费增减、商路速度加成或断路压力。
- 当前合约牌池已扩展为多个家族：选中商品供需合约、自动撮合合约、固定环晶电池专供、双商品对冲/替换合约、惩罚性拒签条款。

#### AI 牌局智能与训练样本

- AI 现在会在实时局内自动评估普通手牌：
  - 优先打出起始怪兽牌，保证 PVE 对手也能打开购牌区域。
  - 按卡牌类型、等级、目标价值、商品流动条件、现金费用和 AI 性格权重给候选动作评分。
  - 可匿名打出卡牌；如果多名玩家进入同一批次，AI 会按预算参与公开小费竞价。
  - AI 也会从可达怪兽补给区域匿名购牌，并按手牌升级、商品流动满足度、角色卡被动收益和价格折扣评分；远程补给会加价但不放宽怪兽召唤限制。
- AI 现在会自动回应合约牌的独立 5 秒签约窗口：
  - 签约奖励、拒签惩罚、商品接入、商路加速、是否帮助对手供给区都会进入评分。
  - 签/拒结果对全体公开，但回应玩家身份仍按规则隐藏。
- AI 现在会自动做基础情报推理：
  - 根据私人城市标注、公开商品线索、城市产品/需求、匿名卡牌商品流动条件和历史公开归属，给城市业主和卡牌归属候选评分。
  - 可把城市业主标注写入自己的私人情报，也可对匿名卡牌归属下注；命中会公开该牌归属标签并结算资金。
  - 情报行动也写入 AI 训练样本，方便后续把“最后谁的钱最多”作为 reward 继续调参。
- AI 现在会为怪兽诱导牌生成更明确的策略候选：
  - 按竞争城市潜在收入、商品重叠、商路负载、怪兽等级/生命、怪兽资源偏好与目标距离给“怪兽→城市”组合评分。
  - 更倾向把资源偏好吻合的怪兽引向高价值竞品城市，而不是随机挑怪兽或随机点区域。
  - 训练样本会记录 `target_city`、`target_owner`、`attack_value`、`resource_match`、`distance_m` 和 `strategic_role`，方便之后学习哪些诱导真正提高最终结算钱。
- AI 现在有第一层跨周期经济焦点：
  - 每个 AI 会按己方商品流、角色被动、市场价格/供需压力、竞争城市和 Roguelike 现金目标缺口，选出一个 `economic_focus_product`。
  - 城市化评分、匿名商业行动、经济卡目标商品和购牌评分都会受到焦点商品影响，让 AI 更倾向围绕同一条赚钱路线连续决策。
  - 训练样本会记录 `focus_product`、`focus_score`、`focus_bonus` 和 `focus_reason`，方便之后把“最终钱最多”作为 reward 反推策略质量。
- AI 现在有第一层多周期策略意图：
  - 每个 AI 会在 `grow_focus`（扩张焦点商品）、`defend_routes`（保卫己方商路/城市）和 `disrupt_competitors`（压制竞品城市）之间切换。
  - 策略意图会给城市化、匿名商业行动、购牌与出牌候选加分；例如己方商路受损时更偏向保险/延缓威胁，竞品城市高收益时更偏向断路、舆论引导和怪兽诱导。
  - 严重商路损伤的防守权重已提高，避免随机地图上的一般扩张收益压过“先止血”。
  - 训练样本会记录 `strategy_intent`、`strategy_score`、`strategy_bonus` 和 `strategy_reason`，方便后续学习不同策略在不同星球深度里的收益。
- AI 现在有商品路线计划层：
  - 每个 AI 会选择一个计划商品，并在 `build_supply`（补供给城）、`create_demand`（制造需求）、`strengthen_route`（强化商路）、`defend_route`（保护路线）和 `attack_rival`（打击竞品）五个阶段之间推进。
  - 路线计划同时影响城市化选区、经济卡目标、区域购牌、合约签拒和匿名商业行动，避免这些系统各自只看当前一拍。
  - 如果既有路线新增了供给城、需求城或商品流量，AI 会确认这是计划进展并继续推进；已有经济基础的路线也带切换门槛，只有明显更强的候选才会使 AI 改换商品。
  - 训练状态、候选和实际选择会记录 `route_plan_product`、`route_plan_stage`、`route_plan_score`、`route_plan_reason` 和 `route_plan_bonus`，后续可用最终金钱 reward 比较不同路线阶段的收益。
- AI 现在有局内在线学习层：
  - 经营周期回填现金收益与估算结算收益后，会把 reward 转成每个 AI 自己的 `learned_policy_values`，不会在席位之间共享。
  - 学习标签按 `action`、`policy`、`strategy`、`route`、`product` 拆开，例如匿名商业涨价、需求改造、签约、卡牌押注、`grow_focus`、`create_demand` 和“环晶电池”会分别积累经验。
  - 学到的加成会反过来影响商业行动、出牌、购牌、合约签拒、匿名竞价、城市/卡牌归属推理、战略意图候选和商品路线候选；浅层小星球适合快速积累短局样本，深层大星球适合观察长线路线规划是否真的多赚钱。
- AI 现在也会做终局 Roguelike reward 回写：
  - `_finish_game()` 结算胜者、玩家是否达到本层现金目标后，会把每个 AI 的最终资金、排名、是否达标/胜利转成 episode reward。
  - 终局 reward 会按决策样本的新旧程度衰减后回写到同一套 `learned_policy_values`，让 AI 不只学习“下一周期赚没赚钱”，也学习“这局最后钱多不多”。
  - 已做防重复：同一条样本只会应用一次终局 reward，保存/读取局面后仍保留终局学习结果。
- AI 出牌/购牌评分新增通用字段层：
  - 除了识别固定 `kind`，AI 现在会读取卡牌上的 `cash`、`gdp_bet_*`、生产/交通/消费、商路损伤/修复、抽牌、购牌范围、伤害、市场供需压力等字段，给未来新增卡一个基础经济/破坏/补给评分。
  - 城市买涨/城市做空会按目标城市业主、当前 GDP、区域损伤、断路压力、城市风险和倍率选择目标，并把 `generic_effect_bonus` 写入训练候选/实际选择元数据。
- 新增城市 GDP 衍生合约卡：
  - `城市买涨I-IV`：匿名买入指定城市 GDP 上涨，记录滚动基准，后续经营周期按 GDP 增量和倍率兑现。
  - `城市做空I-IV`：匿名买入指定城市 GDP 下跌，后续经营周期按 GDP 跌幅兑现；城市被摧毁时清算做空/破产奖励。
  - 这些卡牌进统一卡牌池、图鉴卡面、规则事实、五秒展示演出和区域候选卡池。
- 怪兽破坏更明确地落回经济：
  - 城市收入拆解新增“区域损伤”扣减，区域累计伤害会直接压低幸存城市 GDP。
  - 飞行型怪兽/飞行移动不再造成路径碾压；水栖怪兽有海洋/陆地移动倍率。
  - 孢雾海皇暂定为水栖型，流星哨兵暂定为高速飞行型；后续新怪兽只要填 `movement_traits` 和 `terrain_move_multiplier` 字段即可复用这套逻辑。
- AI 记忆中的训练样本从简单记录扩展为可训练结构：
  - 记录状态向量：现金、估算结算钱、手牌数、城市数、己方怪兽数、场上怪兽数、商品流动、经济焦点商品、策略意图、路线计划商品/阶段/评分、焦点商品流动、卡牌队列状态和经营周期。
  - 记录本次候选动作及评分，保留前若干个最高分候选。
  - 记录实际选择、目标、理由、卡牌名、竞价预算/出价等元数据。
  - 下一次经营周期结算后回填现金收益和估算结算收益，终局时再回填最终资金/排名/现金目标结果，形成短周期 + 长周期两层 reward。
- UI 与复盘信息继续向“可大范围重排”的方向整理：
  - 菜单面板新增响应式布局刷新：根据可用窗口尺寸调整面板锚点、留白、标题字号、导航按钮尺寸，以及图鉴/速览卡片的网格列数。
  - 主菜单和暂停菜单新增紧凑速览卡片，把“开局准备、主画面原则、图鉴/详情、终局复盘”等入口先用短卡片说明，再把长规则和操作细则放在下方分支里。
  - 怪兽、卡牌、商品图鉴的缩略图行列数统一参考菜单内容宽高，不再各自直接按整屏尺寸硬算，后续换菜单壳或重排页面时更容易维护。
  - 终局 AI 路线复盘新增“发展路线”摘要，会优先从 AI 决策样本的 `development_route` 字段统计；若本局样本不足，则回退到角色/性格的路线偏好。终局玩家概览和 AI 路线摘要都会显示这条路线，方便后续平衡四五种 AI 发展策略。
- AI 相位反制从“可用卡牌”升级为独立策略：
  - 每次固定 5 秒相位响应窗口内，AI 会单独扫描手中的 `card_counter`，以及“悖论兽契社”这类可把怪兽牌临时改写成相位否决的角色能力。
  - 反制评分不硬编码单张被反制牌，而是读取公开结算牌的目标和字段：直接玩家压制、己方城市/商路伤害、GDP 做空、怪兽召唤/诱导、全场齐射、天气改写、惩罚性合约，以及领先者受益等都会形成威胁分。
  - AI 会扣除机会成本：普通相位否决按等级/强度/返还/线索折算成本；怪兽牌改写会额外考虑怪兽牌等级、HP 和固定技能价值，避免 AI 轻易烧掉高价值怪兽牌。
  - 训练样本新增隐藏 `counter_*` 元数据，包括目标结算 ID、目标牌、威胁分、机会成本、反制强度、是否由怪兽牌改写、阶段/姿态和原因键。玩家界面仍只看到匿名反制结果，不会看到 AI 的压力桶或评分逻辑。
- AI 天气干预从“按天气类型粗选目标”升级为字段驱动规划：
  - 新增无随机天气覆盖预览，AI 在出牌前会预估天气锚点周边会覆盖哪些区域，而不会为了评分提前消耗真实天气随机数。
  - AI 会读取天气的生产/交通/消费倍率、海洋交通倍率、覆盖区城市 GDP、商路负载、城市商品/需求是否匹配焦点商品、仓储/怪兽压力、地形和终局姿态。
  - 引力潮汐/航线预报会优先寻找能放大己方商路、海洋/交通窗口或焦点商品路线的位置；酸雨、电磁雾、太阳风暴等会在收益更高时压制竞品城市或竞品商路。
  - 训练样本新增隐藏 `weather_*` 元数据，包括天气类型、计划角色、覆盖城市数、商路负载、己方价值、竞品压制价值、地形加成和商品加成；玩家仍只看到匿名改写后的公开天气预报。
- 玩家可见文本开始按电子桌游标准重写：
  - 明确区分开发文本与游戏内文本：设计原则、历史变更、兼容字段、AI 压力桶和实现说明留在文档/测试里，游戏内只保留玩家能立刻操作和判断的信息。
  - 主菜单与暂停菜单改用“牌桌布局、悬停预览、缩略图、双击详情、返回牌桌”这类桌游电子版语言，移除 `hover`、响应式网格、测试、原型、开发等玩家不需要看到的词。
  - 开局准备页改成座位卡结构：顶部筹码显示席位、真人、电脑对手、挑战层级、现金目标、角色不重复、首召独立；每个席位用卡片展示公开角色和匿名首召怪兽。
  - 卡牌/怪兽/商品图鉴的悬停预览压缩为对象名、路线/定位、关键效果和 I→IV 强化；翻页/详情操作只在页面提示中出现，不再反复塞进每张预览卡。
  - 区域牌架、手牌和顶部匿名牌轨统一使用“悬停详情/预览”的中文标签，并保留单窗口锁定、价格锁定、双击区域查看牌架等关键桌面交互。
  - 牌桌进行中 UI 继续向“中央星球 + 桌边玩家板”靠拢：顶部匿名牌轨从高轨道压成小型牌轨，只保留状态、牌名、报价/归属短信息，完整效果留给悬停和双击详情。
  - 底部桌边牌架改为横向桌栏：左侧固定显示我的手牌，右侧收纳选区、竞价、竞猜、合约和目标选择。这样临时行动窗口不会再把手牌挤到下方，测试者能持续看到自己的牌。
  - 空手牌槽、手牌提示和开局日志进一步压缩成玩家语言，例如“空槽”“区域牌架”“电脑对手”“星球牌局开始”，避免把原型/开发阶段信息带进游戏内。
  - 区域牌架从右侧大窗口改成侧边抽屉，后续已升级为“左侧市场格 + 右侧预览板”：背景不拦截地图，玩家可以继续看中央星球。浏览始终允许，购买资格和价格仍按打开窗口瞬间锁定。
  - 区域牌架守卫现在会检查 `DistrictSupplySideDrawer`、右侧锚点、`DistrictSupplyMarketGrid` 和 `DistrictSupplyPreviewPanel`，防止回退成居中模态弹窗或长按钮列表。
  - 当前选区信息改成 `SelectedDistrictChipRail`：地形、HP、城市/GDP、牌架数量、商品供需和天气都以筹码显示，按钮保留“城市化/查看牌/标注/商路/全屏”一排，降低玩家读长句的频率。
  - 开局轻引导改成 `OpeningGuideChipRail`：五个步骤用筹码显示完成状态，只保留一个“下一步｜……”短条；“为什么”和“入口”改为 tooltip，不再常驻挤占行动托盘。
  - 匿名卡牌结算层从右上角小窗改成顶部中央 `CardResolutionTableBanner`：它像电子桌游的全桌事件横幅，公开卡面、结算状态和关键效果，同时避开右侧区域牌架与底部手牌。长效果仍放在 tooltip/牌轨详情里。
  - 结算横幅守卫会检查顶部中央锚点、`CardResolutionTableBanner` 命名，以及“不遮住右侧牌架或底部手牌”的玩家提示，防止之后回退成挡地图/挡手牌的模态窗。
  - 临时决策统一成 `TemporaryDecisionCard` + `TemporaryDecisionChipRail`：私密弃牌、合约签拒、怪兽/玩家目标选择、怪兽赌局下注都使用同一张桌边决策卡。标题统一为“桌边决策｜…”，隐私、是否阻塞出牌、剩余时间和特殊状态改成筹码，降低临时窗口的阅读压力。
  - 弃牌换购 smoke 现在检查桌边决策卡和筹码轨，避免以后又出现散落按钮或长文本弹窗。
  - 新增/更新守卫：`tests/ui_text_smoke_test.gd` 检查玩家文本不退回明显开发词；`tests/visual_snapshot.gd` 检查牌桌紧凑布局、区域牌架筹码和开局座位卡结构。
- Night-Patrol 作为非商业原型素材标杆接入：
  - 已核对上游 `op7418/Night-Patrol` 的 `LICENSE` 与 `NOTICE.md`：整体按 CC BY-NC 4.0 / 非商业 demo 边界处理，商业化前必须替换为自有资产或补充书面授权。
  - 轻量资产隔离放入 `assets/third_party/night_patrol/`，并保留上游 `LICENSE`、`NOTICE.md` 和 vendor README，避免以后误认成自有商用素材。
  - 卡牌程序美术叠加 Night-Patrol 风格的纹章/边框参考层；如果第三方资源被移除，会自动回退到程序卡面。
  - 桌面音频接入低音量 BGM 与卡牌/攻击/天气/赌局短音效；音频资源按可选加载处理，缺失时不会阻塞 smoke 或启动。
  - 新增 `docs/third_party_assets.md` 记录来源、署名和商业化替换要求。
- Terraforming Mars 开源电子桌游作为 UI 结构标杆：
  - 已核对 `terraforming-mars/terraforming-mars` 仓库为 GPL-3.0；本项目只参考公开的信息层级和交互结构，不直接复制 GPL 代码/样式/素材。
  - 重点参考其 `Board.vue`、`PlayerHome.vue`、`PlayerResources.vue`、`Card.vue` 等组件分层：中央棋盘、玩家资源板、手牌/已打牌区域、当前行动/等待窗口分别承担不同信息密度。
  - 主牌桌地图标题统一为“星球赌桌｜中央星球”，强调地图/星球是桌面中心。
  - 底部玩家区新增 `TerraformingMarsLikeResourceBoard` / `PlayerResourceCubeRail`：把资金、GDP、城市、手牌、终局目标做成一排小资源方块，避免玩家在长文本里找状态；对手资源仍按隐私规则隐藏。
- Gaia Project 开源实现作为地图/行动板结构参考：
  - 已查看 `boardgamers/gaia-project` 的 `master` 分支结构；GitHub API 未检测到明确 license 文件，因此当前只作为开发期信息架构参考，不把代码/素材并入项目。
  - 参考方向是 `SpaceMap`、`SpaceHex`、`PlayerBoard/Info`、`Commands`、`ResearchBoard` 一类“地图中心 + 玩家板 + 命令区”的分区思想，帮助本项目继续把复杂信息拆成可扫读模块。
- 本轮 UI/规则闭环继续收敛：
  - 顶部牌结算状态不再暴露“0.5秒”等内部参数，改成“同时判定/匿名竞价/公开展示/封盘/下一批”等桌游式状态词；具体剩余时间由底部沙漏条表现。
  - 地图控制筹码改为“◎ 赌桌中央”，让玩家更明确星球是牌桌核心；底部手牌架新增“状态：…”总状态条，空手牌/固定技能/需商品/需目标都能一眼看见。
  - 选区按钮改成“查看牌架”，区域牌架市场格的价格与购买状态允许用卡片面板标签表达，不再要求传统按钮长文本。
  - 合约签署窗口文案改为“不会阻塞其他玩家继续出牌”，和展示后独立签/拒窗口的真实规则一致。
  - 区域受伤/摧毁后显式写回 district 状态，仓储期货城市被毁时普通期货保留、仓储头寸清除；商品图鉴的紧凑“期货/仓储”文本现在也保留“仓库:”前缀，方便玩家识别可被攻击的仓储城市。

#### 文档与测试

- `README.md`、`docs/prototype_scope.md`、`docs/rules_summary.md` 已同步为当前规则说明。
- 本轮验证：
  - `tests/ui_text_smoke_test.gd` 通过。
  - `tests/visual_snapshot.gd` 通过。
  - `tests/smoke_test.gd --check-only` 通过。
  - `tests/smoke_test.gd` 完整通过。
  - Godot 有头启动通过：正常开窗口使用 Vulkan / NVIDIA GeForce RTX 4080 SUPER 渲染 180 帧后自动退出。
  - `git diff --check` 此轮未作为最终门禁重跑；后续提交前仍建议执行一次。
- 已建立 Godot headless 烟测：
  - 加载主场景
  - 新建 4 席、3 AI 的 PVE 运行，并验证 3-8 总席位、2-7 AI 设置、Roguelike 深度星球规模/现金目标，以及现金线触发的终局倒计时可保存恢复
  - 验证角色卡、起始怪兽卡、资源/赠牌/升兽收益、情报能力与远程补给范围
  - 验证公开角色选择不会重复：显式重复配置会自动避让，AI 随机角色在开局结算为本局未占用角色；每张真实角色卡都带隐藏 `balance_budget`、`balance_band`、`balance_tags` 和 `balance_drivers`，方便后续平衡审计
  - 验证怪兽召唤、升级、持续时间、自动行动
  - 验证球面地图、城市、商品、商路、区域伤害
  - 验证卡牌购买、升级、打出、竞价、匿名归属猜测
  - 验证 AI 会评分手牌、匿名出牌、参与同时批次竞价、自动回应合约、做城市业主推理/卡牌归属押注、规划怪兽诱导目标、维护经济焦点商品、切换 grow/defend/disrupt 策略意图、跨建城/卡牌/合约/商业动作推进商品路线计划，按经营周期 reward 与终局 Roguelike reward 进行席位隔离的在线学习，并记录候选与收益样本；同时验证通用卡牌字段评分元数据
  - 验证 8 席长 smoke 会按 AI 性格生成路线行动报告：6 类 profile 都必须产生 route-tagged 决策样本，并覆盖多条核心发展路线与至少 4 类主偏好路线
  - 验证城市买涨/做空挂单、GDP 涨跌兑现、区域伤害 GDP 扣减、飞行免路径碾压与水栖地形移动倍率
  - 验证合约牌展示后独立签约窗口、固定相位响应窗口、相位否决、军队控制上限与军令技能
  - 验证分型军队牌使用字段驱动的部署地形、移动倍率、临时卡面/地图标记、短时 GDP 压力和商路压力
  - 验证军队运行时边界：军队前进不会造成怪兽式建筑踩踏/区域伤害，但会把短时军事 GDP 压力写入城市收入拆解
  - 验证军队摧毁边界：前进和猎兽军令不会写入区域/商路破坏，只有显式“摧毁区域”军令会造成区域伤害、商路压力和军事 GDP 压力
  - 验证 AI 相位反制策略：AI 能在相位窗口内识别威胁己方城市的匿名牌，排入相位否决，写入隐藏反制元数据，并让原牌被取消
  - 验证 AI 天气干预策略：AI 会用引力潮汐强化己方商路窗口，用酸雨压制竞品城市，并在匿名出牌样本中记录隐藏天气计划元数据
  - 验证港仓囤货的仓储风险和公开线索：商品状态/商品图鉴会显示匿名期货方向、最近到期和仓储笔数；仓库城市线索显示商品与单位但不显示玩家；仓库城市被摧毁时，仓储商品期货头寸作废，普通非仓储期货仍保留到自身到期窗口
  - 验证普通商品期货按秒结算：到期前不支付，到期后只按真实商品价格变化兑现，并清空对应头寸
  - 验证临时经济持续时间以真实秒数为源字段：城市临时合约、商品合约、商品增速、商路流通、GDP 衍生品和商品期货都必须暴露 `*_seconds`；`*_turns` 只作为旧存档/镜像兼容，烟测按 30 秒真实流逝检查倒计时
  - 验证本局商品驱动牌池：固定商品牌只在本局星球存在所需商品时进入卡池；怪兽牌按资源偏好匹配本局商品，极端地图有安全回退；区域补给还会检查本地供需，避免这颗星球不存在的商品牌出现在可购买列表里
  - 验证菜单、图鉴缩略图册、临时卡面/怪兽美术
- 完整烟测命令（耗时较长；本轮已通过）：

```powershell
& 'C:\Users\Administrator\Documents\New project\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke_test.gd
```

### 最近清理的旧规则遗留

- 移除了旧的四怪兽开局阵容/守护者兼容状态。
- 移除了卡牌充能字段与运行时遗留。
- 移除了持续控制怪兽的 runtime 字段；保留的是一次性诱导/指令类效果。
- 卡牌分类文案从旧的 `supply/control` 调整为 `supply/lure`。

### 下一步建议

1. 做一轮专门的数值和平衡审计：检查卡牌 I-IV 强度、价格、商品流动门槛、GDP/min、怪兽伤害、天气/新闻影响、合约奖惩和终局现金目标是否处在同一套可解释预算内。
2. 至少打磨出 4-5 条 AI 可用发展路线，并用批量模拟验证每条路线在合适局势下都能追逐最高现金目标：例如城市成长/GDP、商品供需与合约、交通商路、金融买涨/做空、怪兽/新闻/天气压制，情报竞猜可作为辅线或混合路线。
3. 为长局经济波动增加专门测试，验证商品供需、城市竞争、商路破坏、卡牌强度和最终金钱结算的平衡；目标不是所有路线平均胜率，而是每条路线都有清晰优势、弱点和反制窗口。
4. 在已有短周期/终局 reward 学习之上继续加入连续诱导/合约组合，并观察不同 Roguelike 星球尺寸下的稳定表现。
5. 拆分 `scripts/main.gd`，把规则模型、卡牌数据、UI、地图投影、经济系统与 AI 决策分模块维护。
6. 等核心玩法继续稳定后，再做一版真正的新手引导，把“游戏规则”菜单内容改造成逐步教程。
7. 继续把合约牌和城市经营卡做成更强的推理线索，例如按商品品类、城市规模、海洋商路或怪兽资源偏好触发不同签约奖惩。
8. 继续调怪兽行动概率与资源偏好，让怪兽争夺商品资源的路线更容易被玩家推理。
9. 为角色卡、卡牌与怪兽替换正式美术，保留当前程序美术作为占位 fallback。

## 2026-07-01｜入口命名、桌面快捷方式与图鉴第一屏重排

- 启动入口改为更面向玩家的名称：
  - `project.godot` 的窗口/项目名改为 `太空辛迪加`。
  - 新增 `Launch Space Syndicate.cmd`，旧 `Launch Space Syndicate Prototype.cmd` 保留为兼容入口。
  - 桌面快捷方式更新为 `太空辛迪加.lnk`，并移除旧的 `Space Syndicate Prototype.lnk`，图标继续指向当前临时游戏 icon。
- 继续清理主界面的程序化时间文案：
  - 匿名卡牌多人提交窗口改为“同时短窗 / 报价沙漏”语言。
  - 顶部牌桌状态不再显示具体内部秒数；具体等待感由底部沙漏条和状态筹码承担。
  - 需要展示真实持续时间的卡牌效果仍保留秒数，例如期货、天气、合约、临时经济效果。
- 卡牌图鉴改为“卡片优先”的 TCG/电子桌游浏览顺序：
  - 缩略图页第一屏先显示卡牌矩阵，筛选、牌库来源、区域买牌说明和牌路总览下移。
  - 详情页第一屏先显示卡面、扫牌顺序、费用/门槛、核心效果、关键数值和本局投放，再接 I-IV 强化梯度。
  - 修复详情页“扫牌顺序”标题被右侧标签挤成竖排的问题。
- 新增 `tests/ui_snapshot_capture.gd`：
  - 有头启动 Godot 后自动截取主菜单、卡牌图鉴缩略图、卡牌详情和开局牌桌四张 PNG。
  - 输出位置：`user://space_syndicate_ui_snapshots/`，当前 Windows 路径为 `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/`。
  - 这不是替代 smoke 的断言测试，而是用于每次大改 UI 后快速肉眼复查“中央星球、顶部牌轨、底部手牌、图鉴第一屏”的比例。

### 本轮验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。
- `tests/ui_snapshot_capture.gd` 有头通过，并生成 4 张 UI 快照。
- Godot 普通有头启动通过：Vulkan / NVIDIA GeForce RTX 4080 SUPER，自动退出无报错。
- `git diff --check` 通过；仅有 Git 提示 LF 将在下次触碰时转为 CRLF。

## 2026-07-01｜主牌桌底部玩家板改成手牌优先

- 继续按“中央星球 + 桌边玩家板”的电子桌游结构收敛主界面：
  - `TableEdgeHandViewport` 高度提高，并把底部左列调整为“手牌优先，资源筹码和目标提示在下方”。
  - 这样 1600×1000 的测试窗口里，玩家进入一局后第一眼能看到自己的手牌，而不是只看到资源条和长提示。
- 手牌卡改成更紧凑的桌边小卡：
  - 手牌卡最小尺寸改为 `160×168`，空槽同尺寸。
  - 手牌卡正面只保留卡名、路线/类型、短状态、关键筹码和按钮；长效果和状态原因放进 hover/tooltip。
  - `HandCardPlayStateRail` 在紧凑模式下只显示前两个状态筹码，不再额外塞一行理由文字，减少主桌文本密度。
- 右侧行动托盘继续承担“可操作但不抢地图”的角色：
  - 托盘宽度从 390 缩到 340，给手牌区更多横向空间。
  - 首召怪兽提示前置到托盘顶部，开局玩家更容易找到“在选区首召”。
  - 首召卡改成窄栏友好布局：卡面、落点、固定技/开牌架筹码和首召按钮可见；长解释放 tooltip。
  - 修复行动托盘提示文字在窄栏里被挤成竖排的问题。
- 守卫同步：
  - `tests/visual_snapshot.gd` 增加底部牌架高度、手牌优先、资源条后移、首召前置和小手牌卡尺寸合同。
  - `tests/ui_text_smoke_test.gd` 更新紧凑手牌卡的 42px 美术高度合同。
  - `tests/smoke_test.gd` 更新首召提示断言，从旧“首召引导”改为当前玩家词“首召怪兽”。

### 本轮验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/ui_snapshot_capture.gd` 有头通过，并重新生成主菜单、卡牌图鉴缩略图、卡牌详情和主牌桌快照。
- `tests/smoke_test.gd` 完整通过。
- Godot 普通有头启动通过：Vulkan / NVIDIA GeForce RTX 4080 SUPER，自动退出无报错。
- `git diff --check` 通过；仅有 LF/CRLF 提示。

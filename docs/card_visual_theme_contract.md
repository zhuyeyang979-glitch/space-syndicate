# Card Visual Theme Contract

这份契约保护“卡牌看起来像可玩的桌游卡，而不是开发说明块”。它服务于当前试玩原型，不替代最终美术规范。

## 1. 同源卡面

- 手牌、区域牌架、结算展示、图鉴缩略图、图鉴详情必须共享同一套卡面视觉语言。
- `CardUI` / `CardFace` 负责卡牌框架：费用、名称、等级、插图区、关键词、效果和类型。
- `CardUI` 必须有可见的类型符号锚点；玩家不能只靠读文字判断这张牌属于怪兽、军队、金融、商品或情报路线。
- `CardArtView` 负责共享卡面美术：星空底、多来源中央 sprite 插画、类型纹样、等级标记、Night Patrol backplate/frame/strip/sigil 参考层。
- Night Patrol 参考层必须肉眼可见：内板、边框、上下饰条和中心纹章共同形成临时卡面，而不是只留一层低透明度装饰。
- 区域牌架左栏是 market-cell 小卡，必须用 `CardArtView` 做视觉锚；右栏购买预览再用 `CardFace` 展示更完整的读牌状态。

## 2. 缩略图硬指标

- 图鉴缩略图不能退回纯文字列表或单色标签。
- 区域牌架市场卡也不能退回纯文字按钮。
- 每张缩略图必须有：
  - 可见卡面美术区。
  - 类型/路线色。
  - I-IV 等级。
  - 2-4 个速读 chip。
  - 一条路线/牌路文字。
  - 一条短效果。
- 长规则只放在 hover preview、右侧详情或卡牌详情页。

## 3. 视觉差异硬指标

- 怪兽、军队、金融、商品、合约、情报、天气、商路、直接互动等牌型要有不同 sprite family / sprite cell / glyph / motif。
- 不允许只靠文字区分卡牌类别。
- 同一类别的不同路线至少要通过 sprite cell、构图、颜色、纹样、关键词或统计行形成第二层差异。
- 高频首局牌必须有 `first_run_art_focus` 图形焦点；路线 glyph 只作为小徽章，不能压住卡牌插画主体。
- 高频审片牌必须有 `illustration_anchor`，明确玩家第一眼应该看到的是金融塔、工厂核心、交通网、广播阵列、市场涨跌、仓储、相位否决、空军或舰队等哪一种画面重心。
- 高频审片牌还必须有显式 `sprite_key` 分布约束：首批 24 张不能继续大面积共用同一 Moth building/mech/kaijuice sprite；至少 12 个 sprite family，单一 sprite family 最多出现 3 次。
- 金融、GDP 买涨/做空、合约、仓储、直接互动和相位否决牌优先使用 `game_icon_*` 语义图标；这些图标比临时建筑 sprite 更接近桌游卡牌的读牌方式。
- 怪兽牌可以使用对应怪兽的 body sprite，但 MOS/Moth kaiju body 只允许出现在 `焰环幼星` 对应怪兽牌/怪兽本体/地图 token 上；其它怪兽牌必须使用自己的来源。
- 每张卡必须能生成唯一 visual profile；详见 `docs/art_production_contract.md` 和 `tests/art_identity_gate_test.gd`。

## 4. 开源素材边界

- 当前原型可使用 `assets/third_party/night_patrol/ui/` 下的 frame、sigil、panel、button strip 作为非商业参考素材。
- 当前原型可使用 `assets/third_party/moth_kaijuice/` 下的 MIT sprite，以及 `assets/third_party/monster_battler/`、`assets/third_party/kenney_cc0/`、`assets/third_party/pixelmob_cc0/`、`assets/third_party/superpowers_cc0/` 下的 CC0 sprite，作为卡牌插画/怪兽造型临时素材。
- 当前原型可使用 `assets/third_party/game_icons_ccby/` 下的少量 Game-icons SVG 作为卡牌语义图标；这套素材需要 CC BY 署名，商业化前必须保留 credits 或替换。
- 代码必须把这些素材当作 optional reference layer：缺失时回退程序美术，不让游戏崩溃。
- 商业发布前必须替换为自有素材或获得明确授权；详见 `docs/third_party_assets.md`。

## 5. 玩家阅读顺序

卡牌第一眼阅读顺序固定为：

1. 类型色 / 图标。
2. 名称与等级。
3. 费用或价格。
4. 关键词 chip。
5. 短效果。
6. hover / 详情中的完整条件、目标和结算说明。

这个顺序优先服务真人测试者，不展示 AI 分数、开发原则或历史规则。

## 5.1 一眼读懂硬指标

每张进入手牌、区域牌架、公开牌轨或图鉴的卡，必须尽量满足这六项；缺一项就只能算“能读”，不能算“一眼懂”：

1. **用途**：卡面必须有 `use_case` / `table_use` / `purpose`，或能从类型自动推导出“赚钱、压制、合约、情报、怪兽、军队、天气、商品、商路、互动”等短用途。
2. **视觉锚点**：必须有插图/类型 glyph/路线色，不能只靠文字。
3. **费用与门槛**：费用、商品流动门槛或“免门槛”必须作为 chip 出现。
4. **目标**：怪兽、玩家、区域、城市、商品或按牌面目标必须可扫读。
5. **短效果**：手牌小卡只显示 2-3 行短效果；完整规则放进 hover / 详情。
6. **等级**：I-IV 级必须在卡面可见，并在详情页显示梯度。

运行时 `CardFace` 必须把用途放进手牌小卡的短效果前缀和关键词 chip；大预览必须显示“用途｜…”。这样玩家先知道“这张牌拿来干嘛”，再读细节。

数据侧也必须过关：`main.gd` 的 `_card_use_case_text_for_skill()` 是统一用途派生骨架，手牌、区域牌架、卡牌图鉴缩略图和详情卡面都必须把 `use_case / table_use` 传给 `CardFace`。`_card_one_glance_audit_report()` 是开发者验收入口，要求每张卡都有用途、短效果、路线、视觉/数值锚点、价格、等级、门槛和目标/结算 chip；不得退回“临场改局势”这类泛化用途。

右侧详情面板也必须遵守同一读序。`RightInspector.show_card()` 的卡牌详情第一屏必须先显示用途、费用、目标、当前状态、等级和类型；长规则只作为完整详情补充。hover 手牌、选中手牌、区域牌架预览和图鉴跳转都不能把右栏退回“长段说明书”。对应验收由 `tests/layout_scene_smoke_test.gd` 和 `tests/visual_snapshot.gd` 保护。

## 6. 购买路径一致性

区域牌架的阅读路径固定为：

1. 左栏 market-cell：短名、等级、价格、状态、共享美术锚。
2. Hover / 单击：右栏购买预览更新。
3. 右栏预览：更大 `CardFace`、决策条、购买判定灯、短效果、关键事实、购买按钮。
4. 买入后：手牌架仍显示同一张卡的 mini-hand 卡面。

玩家应能从颜色、glyph 和关键词判断“这是同一路线的同一张牌”，而不是在不同页面看到三种无关 UI。

右栏决策条必须先显示：

- 用途：这张牌属于哪条路线。
- 买入：当前是可买、仅浏览、需弃牌还是受阻。
- 打出：是否需要商品流动门槛。
- 目标：怪兽、玩家、两区或按牌面。

长效果和规则解释必须限制行数，放进 tooltip / 详情页，不在牌架预览里铺满整栏。

### 运行截图守门

- `tests/ui_snapshot_capture.gd` 必须保留真实主桌区域牌架截图：`play_table_supply_drawer_<分辨率>.png`。
- 该截图必须通过 `_open_district_supply_from_map()` 打开真实运行时牌架，而不是摆拍一个假抽屉。
- 抽屉默认文案应为中文短标签：区域牌架、区域供牌、卡牌预览、关闭。

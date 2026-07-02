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
- 每张卡必须能生成唯一 visual profile；详见 `docs/art_production_contract.md` 和 `tests/art_identity_gate_test.gd`。

## 4. 开源素材边界

- 当前原型可使用 `assets/third_party/night_patrol/ui/` 下的 frame、sigil、panel、button strip 作为非商业参考素材。
- 当前原型可使用 `assets/third_party/moth_kaijuice/` 下的 MIT sprite，以及 `assets/third_party/monster_battler/`、`assets/third_party/kenney_cc0/`、`assets/third_party/superpowers_cc0/` 下的 CC0 sprite，作为卡牌插画/怪兽造型临时素材。
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

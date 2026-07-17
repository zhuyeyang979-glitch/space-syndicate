# v0.6 旧城市／项目份额语义移除

## 结论

v0.6 不存在可投资、可转让或可分割的城市／项目产权份额。公共设施由一个明确玩家拥有；区域控制来自最近商品成交形成的商品 GDP，而不是设施产权。

正式数据流固定为：

`Sale Receipt → CommodityFlow 区域商品 GDP → VictoryControl 区域控制快照 → 玩家可见展示或规则消费者`

## 区域控制

- 分子：某玩家在该区域最近观察窗内的商品 GDP。
- 分母：该区域最近观察窗内的全部商品 GDP。
- 控制门槛：30%。
- 控制者必须是唯一最高者。
- 并列最高时无人控制。
- 商品 GDP 比例不可交易、转让或投资，也不作为独立可写状态保存。

正式快照使用：

- `snapshot_kind = commodity_gdp_region_control`
- `commodity_gdp_share_basis_points`
- `controller_player_index`
- `revision`

## 公共设施

- 每座设施只有一个 `owner_player_index`。
- 设施不保存份额数组。
- 工厂、市场、仓库和交通设施的结算结果统一使用 `public_facility_committed`。
- 首局教学只要求玩家从当前随机牌架建立一座真实公共设施；怪兽召唤不是购牌或设施建设前置。

## 旧数据处理

- 旧 CityDevelopment controller、bridge、project state 与 project migration 已隔离到 `tests/legacy_v05/`。
- v0.6 正式场景不得 preload 或实例化这些历史 fixture。
- 旧存档不能被转换成虚构的设施产权或商品 GDP。
- 含旧项目 authority 的合约存档必须明确拒绝，不做字段级兼容。

## 隐私

- 区域控制快照只包含公开商品 GDP 控制事实。
- 不公开对手现金、手牌、弃牌、AI 计划或隐藏归属。
- 公开审计只有在 VictoryControl 明确授权时才显示准确现金。

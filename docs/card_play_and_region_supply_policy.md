# 卡牌出牌与区域固定牌架策略

本文是开发者约束，玩家短文案应从同一字段生成，不应直接展示内部评分或对手真实 GDP 份额。

## 出牌资格

- 默认门槛字段为 `play_requirement_kind = region_gdp_share`。
- 地区范围由 `play_region_scope` 指定：`target_region`、`contract_source_region` 或 `own_best_region`。
- 百分比由 `play_region_gdp_share_required` 指定。
- 普通 I-IV 梯度为 `0 / 15 / 25 / 35`。
- 高影响 I-IV 梯度为 `10 / 20 / 30 / 40`。
- `city_development`、`monster_bound_action`、`military_command` 始终免 GDP 门槛；它们分别受目标合法性、冷却或单位状态约束。
- `play_product` 只作为旧数据兼容来源，运行时复制为 `supply_product`，不再构成默认出牌门槛。
- 现金费用与 GDP 资格相互独立。

GDP 份额按“该玩家在区域内获得的项目 GDP / 区域总 GDP”计算，并以 basis points 比较，避免临界百分比浮点误差。公开 UI 只显示牌面阈值，不显示对手当前真实份额。

## 区域牌架骨架

每个区域维持 4-5 张牌，并保留两个稳定槽位：

1. 本地商品城市发展槽：恰好一张，`product_id` 必须属于区域本地商品。陆地按区域经济重点排序；海洋优先通商项目。
2. 固定怪兽槽：恰好一张，按地形、怪兽资源偏好与召唤生态评分，并在怪兽家族容量允许时跨区域不重复。
3. 其余槽位：从本局商品过滤后的普通牌池补齐，不能再塞入城市发展牌或怪兽牌。

固定槽位保存在区域数据的 `city_development_guarantee_card` 与 `monster_guarantee_card` 中。重新整理牌架或读取存档时必须恢复固定槽位，不能重新随机改变区域身份。

当前怪兽家族数量可能少于高深度星球区域数。分配器会先把全部怪兽各用一次，只有容量耗尽后才允许重复，并在 `_district_reserved_supply_audit()` 的 `monster_unique_capacity_shortfall` 中报告缺口。扩充怪兽家族是消除该缺口的唯一正确方式，不能通过改名制造伪唯一怪兽。

## 验收不变量

- 每个区域恰好一张本地商品城市发展牌。
- 每个区域恰好一张固定怪兽牌。
- 怪兽牌数量足够时，区域之间不出现同名固定怪兽牌。
- 每区总牌数为 4-5。
- 大多数 I 级牌免门槛；城市发展牌全部免门槛。
- 旧商品流动门槛默认返回 0。
- 玩家文本不出现对手真实 GDP 份额或 AI 私有评分。

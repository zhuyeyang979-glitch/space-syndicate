# Balance Report v1

This report is advisory for the Hearthstone-grade vertical slice. It does not modify global card data.

## 价格过低 Top 20

The analyzer generates this table from `data/balance/vertical_slice_card_set.json` and `data/balance/price_curve_v1.json`. Cards in this group are likely underpriced for the showcase curve and should be considered for `card_balance_overrides.json` before any real data edit.

| Card ID | 名称 | 类型 | Rank | 当前 | 建议 | 差值 |
| --- | --- | --- | --- | ---: | ---: | ---: |
| public_tip_ii | 公开悬赏 II | 情报 | II | 60 | 180 | +120 |
| missile_cover_ii | 导弹掩护 II | 军队 | II | 90 | 205 | +115 |
| beast_lure_ii | 怪兽诱导 II | 怪兽 | II | 120 | 230 | +110 |
| orbital_finance_iii | 轨道融资 III | 经济 | III | 160 | 260 | +100 |
| route_spark_iii | 商路点火 III | 商路 | III | 140 | 240 | +100 |
| city_repair_iv | 城市抢修 IV | 经济 | IV | 210 | 305 | +95 |
| public_tip_iii | 公开悬赏 III | 情报 | III | 150 | 240 | +90 |
| cold_crown_contract_i | 寒冠合约 | 合约 | I | 40 | 125 | +85 |
| missile_cover_i | 导弹掩护 | 军队 | I | 45 | 130 | +85 |
| final_countdown_i | 终局倒计时 | 互动 | I | 75 | 145 | +70 |
| orbital_finance_ii | 轨道融资 II | 经济 | II | 85 | 155 | +70 |
| public_tip_i | 公开悬赏 | 情报 | I | 35 | 100 | +65 |
| fog_harbor_beast_i | 怪兽-抱雾海皇 | 怪兽 | I | 95 | 150 | +55 |
| weather_lane_ii | 低轨气象窗 II | 天气 | II | 100 | 155 | +55 |
| orbital_finance_i | 轨道融资 | 经济 | I | 55 | 105 | +50 |
| city_repair_i | 城市抢修 | 经济 | I | 70 | 115 | +45 |
| weather_lane_i | 低轨气象窗 | 天气 | I | 80 | 120 | +40 |
| route_spark_i | 商路点火 | 商路 | I | 90 | 125 | +35 |
| route_spark_ii | 商路点火 II | 商路 | II | 155 | 190 | +35 |
| city_repair_ii | 城市抢修 II | 经济 | II | 180 | 205 | +25 |

## 价格过高 Top 20

| Card ID | 名称 | 类型 | Rank | 当前 | 建议 | 差值 |
| --- | --- | --- | --- | ---: | ---: | ---: |
| bid_pressure_ii | 竞价施压 II | 互动 | II | 215 | 190 | -25 |
| owner_mark_i | 归属标记 | 情报 | I | 120 | 105 | -15 |
| bid_pressure_iv | 竞价施压 IV | 互动 | IV | 390 | 380 | -10 |
| bid_pressure_i | 竞价施压 | 互动 | I | 110 | 105 | -5 |

## Rank I-IV 梯度异常

- `city_repair_iv`: Rank IV current price is too close to Rank II for its impact score.
- `public_tip_ii`: Rank II undercuts its hidden-info premium and should not be cheaper than most simple economy cards.

## 同类型卡牌价格异常

- 情报 cards show the largest spread: `public_tip_ii` looks too cheap while `owner_mark_i` is expensive for a hard first-table read.
- 军队 cards are underpriced in monster-pressure frames because they are easy to understand and high-impact.
- 互动 cards are safest as later tutorial cards; they are more complex than their visible price suggests.

## 首局剧本推荐卡

- `orbital_finance_i` / 轨道融资: clear cashflow read, easy card play frame.
- `city_repair_i` / 城市抢修: connects monster damage to recovery.
- `route_spark_i` / 商路点火: explains route/value feedback.
- `weather_lane_i` / 低轨气象窗: introduces public forecast without hidden-info load.
- `missile_cover_i` / 导弹掩护: simple response to monster pressure.

## 不适合首局剧本的复杂卡

- `owner_mark_i`: hidden ownership inference is too hard before public-track basics.
- `public_tip_ii` and `public_tip_iii`: good for public_track_intro, not first_table.
- `bid_pressure_ii` and `bid_pressure_iv`: save for bid_practice.
- `beast_lure_ii` and `beast_lure_iii`: strong but should follow the monster-pressure intro.

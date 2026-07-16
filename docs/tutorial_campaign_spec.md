# Tutorial Campaign Spec

> Historical / legacy / removed. This document is not runtime authority.

## 战役：辛迪加入桌

| 顺序 | 关卡 ID | 训练内容 | 对应剧本 |
| --- | --- | --- | --- |
| 0 | `00_tavern_entry` | 进入星球赌桌、理解目标 | `first_table` |
| 1 | `01_first_table` | 点区、首召、建城 | `first_table` |
| 2 | `02_market_hand` | 牌架、买牌、换购/弃牌压力 | `market_hand` |
| 3 | `03_public_track` | 匿名出牌、公开牌轨、右侧详情 | `public_track_intro` |
| 4 | `04_bid_practice` | 最高价、追平、压过、清零 | `bid_practice` |
| 5 | `05_monster_pressure` | 怪兽移动、攻击城市、GDP 变化 | `monster_pressure` |
| 6 | `06_contract_goods` | 商品供需、合约、商路收益 | `contract_goods` |
| 7 | `07_intel_guess` | 从牌轨进线索档案、做归属猜测 | `intel_guess` |
| 8 | `08_final_countdown` | 目标进度、倒计时、结算排名 | `final_countdown` |
| 9 | `09_graduation_match` | 4 人 PVE 小局，综合运用 | `first_table` |

每关必须包含：

- Briefing：关卡开场说明。
- Objective：当前目标列表。
- Allowed Actions：玩家应该尝试的动作。
- Coach：一步一目标。
- Hint：卡住时提示。
- Success：成功反馈。
- Failure/Blocked：失败或卡住反馈。
- Reward：奖励/解锁。
- Replay：复盘节点。
- Next：下一关。

## 关卡节奏

前 3 关只教基础操作；中间 4 关教匿名/竞价/怪兽/经济；最后 3 关教推理、终局和综合局。每关都应该能在 2-8 分钟内完成，毕业挑战允许 8-12 分钟。

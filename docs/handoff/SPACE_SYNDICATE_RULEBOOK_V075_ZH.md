# 《太空辛迪加》V0.7.5 规则手册（交接版）

权威优先级：`docs/rules/v075_game_constitution.json` → V0.7.5 Amendment/Balance → 继承的 V0.7.4 Constitution → Owner 代码 → 测试。冲突不得靠 UI 文案或旧对话解决。

## 核心循环

- 【LIVE】动态 6—30 地区球面地图，稳定 Region ID、陆海身份与动态邻接。
- 【LIVE】三类设施：Factory、Market、Warehouse；设施 Owner 唯一写状态。
- 【LIVE】十格共享寿司轨；购买形成 vacancy，不在同一动作中立即补牌或额外抽供应 RNG。
- 【LIVE】六色资产 Pip，区分 Available、Reserved、Empty、Projected Refresh。
- 【LIVE】个人 DBG：购买→弃牌→洗回→抽牌→手牌→行动→规定目的区。
- 【LIVE】固定隐藏批次轮转，不存在顺位竞拍；目标预绑定，失效后 typed Fizzle，不自动换目标。

## 怪兽

- 【LIVE】每位普通玩家 base 容量 1；typed Character port 可修正。
- 【LIVE】四模式：DEPLOY_NEW、REFRESH_EXISTING、UPGRADE_EXISTING、REPLACE_EXISTING。
- 【LIVE】Rank I—IV Refresh 为最大 HP 的 25/50/75/100%；Upgrade 满血、保留旧 cooldown、新技能 READY。
- 【LIVE】自治只读公开设施/邻接；preferred color 仅用于目标，不决定卡牌 primary color。
- 【LIVE】ground_trample 按整数 milli-arc 伤害设施；flying/teleport 不践踏。
- 【LIVE】私密技能不进入公共队列，在安全 Receipt 边界结算；每怪兽每批最多一次。

## 军队

- 【LIVE】只有 assault_region 与 assault_monster。
- 【LIVE】地区攻击使用一个总 damage budget；怪兽攻击锁定 exact source/generation/revision。
- 【LIVE】结束后撤离并回个人 discard；不创建 persistent military source。
- 【RETIRED】Guard/Protect/Defend/Intercept、军队攻击军队、自动 retarget。

## 权威与隐私

- 【LIVE】V075CombatRuntimeOwner 是唯一 Combat Writer；地图、设施、资产、DBG、Victory、Save 各自保持 Owner。
- 【LIVE】AI 使用与玩家相同 typed candidate/validator/runtime，不得读取 rival skill、future target、warehouse stock。
- 【LIVE】Presentation 只消费 Receipt，不写 HP、位置、目标或规则 RNG。
- 【TEST_ONLY】Detached checkpoint/rollback 用于测试，不是生产 Save。
- 【PLANNED】Direct Action、物理 ETA、L1 定向移动、Combat Observatory、20Hz deterministic tick。

# 卡牌开源插画占位来源与许可矩阵 v0.6

日期：2026-07-14  
用途：开发、原型与 Credits 追踪。此文件及插画清单中的路径、作者、许可和 source id 都是开发字段，不得进入玩家卡面、按钮、tooltip、状态或禁用原因。

| 卡牌 | 运行时素材 | 来源/作者 | 许可 | 原型阶段 | 商业发布处理 |
|---|---|---|---|---|---|
| 环晶电池 I | `assets/art/cards/v06/style_keys/commodity/ring_crystal_battery_v01.png` | Space Syndicate 项目生成候选；SHA-256 已写入 manifest | `project_generated_candidate` | 可继续作为自有风格钥匙 | 发布前复核生成记录、权利链与最终采用状态 |
| 轨道仓库 I | `assets/third_party/game_icons_ccby/warehouse.svg` | `delapouite/warehouse.svg`，Delapouite，Game-icons | CC BY 3.0 | 可作为清楚的仓储语义占位 | Credits 完整署名，或以自有轨道仓库插画替换 |
| 远洋采购令 I | `assets/third_party/game_icons_ccby/contract.svg` | `delapouite/contract.svg`，Delapouite，Game-icons | CC BY 3.0 | 可验证订单/采购交互，不是最终插画 | Credits 完整署名，或以自有远洋采购插画替换 |
| 近地供货潮 I | `assets/third_party/game_icons_ccby/profit.svg` | `lorc/profit.svg`，Lorc，Game-icons | CC BY 3.0 | 可验证供货增长语义，不是最终插画 | Credits 完整署名，或以自有近地供货插画替换 |
| 孢雾海皇 I | `assets/third_party/superpowers_cc0/medieval-fantasy/monsters/dragon.png` | Superpowers Asset Packs | CC0 1.0 Universal | 路径与怪兽身体清单保持一致，可作身份占位 | 法律上可继续使用；视觉上仍建议替换为自有科幻巨兽插画 |
| 相位否决 I | `assets/third_party/game_icons_ccby/cancel.svg` | `sbed/cancel.svg`，Sbed，Game-icons | CC BY 3.0 | 反制/无效化语义清楚，可较长期占位 | Credits 完整署名，或以后统一为自有反制插画 |

## 上游与本地许可证据

- Game-icons 上游：<https://github.com/game-icons/icons>
- Game-icons 本地许可：`assets/third_party/game_icons_ccby/license.txt`
- Game-icons 本地映射：`assets/third_party/game_icons_ccby/README.md`
- Superpowers 上游：<https://github.com/sparklinlabs/superpowers-asset-packs>
- Superpowers 本地许可：`assets/third_party/superpowers_cc0/LICENSE.txt`
- 项目汇总：`docs/third_party_assets.md`
- 运行时逐牌映射：`data/art/card_illustration_manifest_v06.json`

## 建议的未来 Credits 文案

- “Warehouse” and “Contract” icons by Delapouite, licensed under CC BY 3.0, via Game-icons.net.
- “Profit” icon by Lorc, licensed under CC BY 3.0, via Game-icons.net.
- “Cancel” icon by Sbed, licensed under CC BY 3.0, via Game-icons.net.
- Superpowers Asset Packs monster sprite, dedicated to the public domain under CC0 1.0.

最终 Credits 应同时保留上游链接、作者、许可名称与许可链接，并与发布版本实际仍在使用的文件重新核对。

## 边界审计

- 本任务没有复制 `reference/` 中的图片。
- 本任务没有新增 Night Patrol 路径或 CC BY-NC 4.0 依赖。
- 原始第三方文件未修改；裁切、染色、暗角、印刷点和语义纹样全部由 Godot 呈现层完成。
- 图像生成调用数：`0`。

# 三张卡牌自有插画候选：来源与生成记录

## 生成范围

本批次严格限定为三张独立位图资产，没有生成三联画，也没有扩展到第四张或整套卡池。

- 成功产出：3 张；
- 无产出的超时请求：2 次，均已取消；
- 最终纳入项目的资产：仅下表三张；
- 项目副本与 Codex 生成目录中的原始输出同时保留，没有覆盖或删除生成源文件。

完整生成提示词与禁止项见：`res://docs/next_task_prompt_three_card_style_lock_batch_v06.md`。

## 资产清单

| 卡牌 | 项目路径 | 尺寸 | SHA-256 | 生成源文件 |
|---|---|---:|---|---|
| 孢雾海皇 I | `res://assets/art/cards/v06/style_lock/monster/spore_tide_emperor_v01.png` | 1536×1024 | `f8290b8f3b951916f0e67d577084f65359a4b2c2cc23b6cce4c747783d78c760` | `exec-d8d5f281-cbbb-4121-b154-b8c76fd78332.png` |
| 远洋采购令 I | `res://assets/art/cards/v06/style_lock/supply_demand/remote_sea_order_v01.png` | 1536×1024 | `51f138408e5238f44ddcb82e12cb614ae4d7958508daa1eeb7dcce437ea3b89c` | `exec-c1d13d5c-17be-46ce-915f-7f73e6253d07.png` |
| 近地供货潮 I | `res://assets/art/cards/v06/style_lock/supply_demand/near_land_supply_v01.png` | 1536×1024 | `41eeeeecb8c0052377f7bc45326c2e387661b3cd204c7114cc7eeb7915d9b2aa` | `exec-cf29fe6e-5c54-4b0b-ae99-6fbacf24af2f.png` |

生成源目录：

`C:\Users\Administrator\.codex\generated_images\019f5c09-6563-7e90-a075-259de93d04e9\`

## 参考输入边界

三张图均参考项目自有候选《环晶电池 I》：

`res://assets/art/cards/v06/style_keys/commodity/ring_crystal_battery_v01.png`

只参考深色值域、工业材质、克制光照和图形化厚涂完成度，不复制能量环、橙色核心或产品居中构图。

孢雾海皇还参考：

`res://assets/third_party/superpowers_cc0/medieval-fantasy/monsters/dragon.png`

该输入只用于左向翼龙/蛇形身体身份。最终图没有沿用像素画表现；地图单位身体资产及其许可仍由 `monster_body_art_manifest.json` 管理。

## 稳定视觉身份

| 卡牌 | `visual_source_id` | 主视觉锚点 | 构图方向 |
|---|---|---|---|
| 孢雾海皇 I | `space_syndicate_authored_spore_tide_emperor_v01` | 左向龙形头颈、冠状孢鳍、港口尺度 | 左重右延伸 |
| 远洋采购令 I | `space_syndicate_authored_remote_sea_order_v01` | 紫色接收门、青色海运实体货链 | 远端向需求端汇聚 |
| 近地供货潮 I | `space_syndicate_authored_near_land_supply_v01` | 绿色工厂枢纽、三股近距实体货流 | 生产端向外分流 |

## 被替代占位来源链

| 卡牌 | 旧资产 | 许可/归属 | 保留位置 |
|---|---|---|---|
| 孢雾海皇 I | Superpowers dragon | CC0-1.0 / Superpowers Asset Packs | `superseded_placeholder` + `body_reference_*` |
| 远洋采购令 I | Game-icons contract | CC-BY-3.0 / Delapouite | `superseded_placeholder` |
| 近地供货潮 I | Game-icons profit | CC-BY-3.0 / Lorc | `superseded_placeholder` |

旧文件没有删除。它们不再作为这三张卡的主插画，但仍可用于来源审计、回归比较和怪兽地图身体身份。

## 商用状态

Manifest 中三张图均标记为：

- `license=project_generated_candidate`；
- `commercial_status=review_before_release`；
- `status=style_lock_candidate_v01`。

该状态表示项目开发中可使用、可运行、可比较，但在完成伪字形清理、统一风格审查和最终人工批准前，不应被宣称为发行版正式美术。

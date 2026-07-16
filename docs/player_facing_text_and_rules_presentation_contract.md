# 玩家文字、卡牌与规则呈现合同

状态：2026-07-14 研究与只读审计基线。本文规定《太空辛迪加》所有文字“由谁消费、能否显示、在哪里显示、如何翻译、如何验证”。它是文案和呈现合同，不替代 `tabletop_rulebook_v05.md` 的玩法语义，也不把任何文字变成第二套规则引擎。

## 1. 核心决定

项目必须把文字分成机器标识、开发诊断、译者元数据、玩家可见文字、玩家辅助文字和玩家生成内容六类。正式玩家界面只允许消费经过可见范围过滤和本地化解析的玩家文字；`card_id`、`action_id`、`reason_code`、原始错误、调试字段、资源路径和译者注释都不得作为 fallback 直接显示。

效果数据、Ruleset 数值和结算 receipt 是规则真相。卡牌文字、规则页、按钮、tooltip 和日志只解释这些结构化事实，游戏逻辑不得反过来解析可见文字。

## 2. 当前项目审计结论

当前已经具备可继续推进的基础：卡牌 Eligibility 会输出 `reason_code + reason_args`，`CardPresentationRuntimeService` 会把部分原因转换为玩家说明，公开快照与私人快照已有边界，`ScenarioActionLog` 也已经区分 `public_text`、`private_text` 和 `developer_text`。

但文字系统尚未形成统一合同，当前有三个互相冲突的玩家规则来源：

1. `docs/tabletop_rulebook_v05.md` 是已确认的 v0.5 玩家规则目标。
2. `scripts/main.gd::_rules_quick_reference_snapshot()` 仍包含“最后钱最多”“城市业主”“猜城市和牌主”等 v0.4 说明。
3. `resources/cards/runtime/families/*.tres` 的 239 条等级卡牌文字中仍有 v0.4 条款、城市业主、猜卡牌归属、供给区/需求区等旧语义。

这不是单纯的润色问题。若只迁移运行时而不清理这三套文本，程序、卡面和规则页会向玩家描述不同的游戏。

| 优先级 | 审计事实 | 风险 | 合同决定 |
| --- | --- | --- | --- |
| P0 | v0.5 规则书、v0.4 局内速查和旧卡牌文字并存 | 玩家按错误规则决策 | 局内规则与全部卡牌必须经过 v0.5 语义审定；旧术语进入泄漏测试 |
| P0 | 没有找到 `tr()`、`tr_n()`、`TranslationServer`、PO/POT 或 Translation 资源 | 中文硬编码、英文占位、未来改语言时大规模返工 | 先建立稳定 key 和简体中文默认目录，再逐面迁移 |
| P0 | 多处 label 缺失时以 action id、card id 或底层 error 兜底 | 玩家看到 `track_select_*`、错误码或内部字段 | 删除 raw-id/raw-error 玩家 fallback；缺 key 时记录开发错误并显示本地化安全提示 |
| P0 | `card_id` 由中文显示名加等级组成，catalog 又把它当 `name` | 改名、本地化、存档和遥测耦合 | 稳定 ASCII ID 与 `name_key` 分离；迁移旧存档 ID |
| P0 | `TopBar` 使用 `GDP /s`，v0.5 规则和卡牌使用 `GDP/min` | 同一数值被理解为不同量纲 | v0.5 玩家显示统一为 `GDP/min`；如内部按秒更新，只在格式化层换算 |
| P1 | 场景默认值混有中文与 `Continue`、`Back`、`History`、`Monster` 等英文 | 数据未及时覆盖时直接泄漏 | 场景默认值也必须是可发布的本地化文字或稳定 key，不能是开发占位 |
| P1 | tooltip 中出现“避免遮挡中央星球”“在 Inspector 中调整”等设计理由 | 开发说明被当作玩家帮助 | 开发理由移入注释/合同；玩家 tooltip 只解释用途、条件或结果 |
| P1 | `scenario_action_log.gd` 的 tooltip 会显示 `snapshot_key`、`focus_target` | 开发字段进入玩家日志 | 玩家日志改为事件名和可见目标；原字段只留开发日志 |
| P1 | 卡牌展示服务、`CardUI.gd`、`right_inspector.gd` 都会推断用途 | 同一卡牌出现三种说法 | `CardPresentationRuntimeService` 保持卡牌语义呈现唯一入口，组件只渲染 ViewModel |
| P1 | 公开、私人、终局揭示和开发输出有多个命名方式 | 隐藏资产可能经日志/tooltip 泄漏 | 所有文本 payload 强制带 `visibility_scope`，先过滤后本地化 |

## 3. 开源与开放规范参考

### 3.1 可优先采用的文案原则

| 资料 | 许可/边界 | 本项目采用内容 |
| --- | --- | --- |
| [18F Technical and interface writing](https://guides.18f.org/content-guide/our-style/technical-and-interface-writing/) / [License](https://guides.18f.org/content-guide/license/) | 美国公有领域并以 CC0 全球放弃权利 | 短句、日常词、主动动词、正向措辞；教程逐字使用真实按钮和菜单名 |
| [USWDS Button](https://designsystem.digital.gov/components/button/) / [Tooltip](https://designsystem.digital.gov/components/tooltip/) | 主体 CC0，第三方素材另核 | 按钮写清结果；按钮是动作、链接是导航；tooltip 只承载非关键补充信息 |
| [OpenDuelyst card factory](https://github.com/open-duelyst/duelyst/tree/main/app/sdk/cards/factory) / [locales](https://github.com/open-duelyst/duelyst/tree/main/app/localization/locales) / [License](https://github.com/open-duelyst/duelyst/blob/main/LICENSE) | CC0-1.0 | 卡牌数值、效果对象与本地化名称/描述分离；不复制品牌和视觉身份 |

### 3.2 可研究实现结构、不得顺手复制世界观文本

| 资料 | 许可/边界 | 本项目采用内容 |
| --- | --- | --- |
| [GitLab UI text](https://design.gitlab.com/content/ui-text/) / [Button](https://design.gitlab.com/components/button/) / [Destructive actions](https://design.gitlab.com/patterns/destructive-actions/) | MIT；实质复制保留 notice | 扫读优先、按钮写结果、破坏操作点名对象、错误写明下一步 |
| [PatternFly error messages](https://www.patternfly.org/ux-writing/error-messages/) / [Button](https://www.patternfly.org/components/button/design-guidelines/) | MIT | “发生了什么—原因—解决办法”的错误结构，按钮脱离上下文仍可理解 |
| [OpenTTD English string table](https://github.com/OpenTTD/OpenTTD/blob/master/src/lang/english.txt) / [License](https://github.com/OpenTTD/OpenTTD/blob/master/COPYING.md) | GPL-2.0 | 按 BUTTON、TOOLTIP、标题、排序项分区；单位、复数和占位符体系；不复制现成字符串 |
| [FreeOrion string tables](https://github.com/freeorion/freeorion/tree/master/default/stringtables) / [License](https://github.com/freeorion/freeorion#license) | 代码 GPLv2；资产 CC-BY-SA-3.0；脚本双许可 | 稳定 key 与显示 value 分离，英文参考表 fallback，注释解释占位符，“短标签—提示—百科”分层 |
| [Unciv translation template](https://github.com/yairm210/Unciv/blob/master/android/assets/jsons/translations/template.properties) / [License](https://github.com/yairm210/Unciv/blob/master/LICENSE) | MPL-2.0 | 命名占位符、菜单/按钮/消息分区、长度与译者警告；不复制文明系列文本 |
| [Battle for Wesnoth translation domains](https://github.com/wesnoth/wesnoth/tree/master/po) / [InterfaceActionsWML](https://wiki.wesnoth.org/InterfaceActionsWML) | GPLv2+；部分新资产 CC-BY-SA-4.0 | 核心、帮助、教程、单位、战役分域；玩家消息、等待消息、调试和弃用警告分离 |
| [0 A.D. localization](https://github.com/0ad/0ad/tree/master/binaries/data/mods/public/l10n) / [License](https://github.com/0ad/0ad/blob/master/LICENSE.txt) | GPLv2+、CC-BY-SA-3.0 和第三方例外 | 设置、局内、大厅、手册、科技、单位、教程拆分；不复制历史说明与素材 |
| [Cataclysm: DDA translation guide](https://docs.cataclysmdda.org/TRANSLATING.html) / [JSON text rules](https://docs.cataclysmdda.org/JSON/JSON_INFO.html) | CC-BY-SA-3.0，含第三方例外 | `NO_I18N`/`I18N`、上下文、复数和译者注释；不复制物品、怪物和剧情描述 |

`Card-Forge/forge` 可用于观察复杂效果系统，但其仓库承载大量《万智牌》卡牌文字与第三方 IP；不得把它当作可复用卡牌文案库。

### 3.3 引擎、本地化与无障碍基准

| 资料 | 本项目采用内容 |
| --- | --- |
| [Godot Internationalizing games](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html) / [gettext](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_gettext.html) / [Pseudolocalization](https://docs.godotengine.org/en/4.7/tutorials/i18n/pseudolocalization.html) | `tr()`、`tr_n()`、上下文、译者注释、动态切语言、伪本地化、RTL、数字与资源本地化；文档为 CC BY 3.0，改编需署名 |
| [KDE Text and labels](https://develop.kde.org/hig/text_and_labels/) | 最重要信息前置、祈使动词、图标按钮仍有完整文字、为翻译膨胀留空间；页面标示 CC-BY-SA-4.0，只吸收原则不复制段落 |
| [GNOME Writing Style](https://developer.gnome.org/hig/guidelines/writing-style.html) / [Tooltips](https://developer.gnome.org/hig/patterns/feedback/tooltips.html) | 短而不失义、使用玩家任务术语；tooltip 不承载关键内容、不依赖 hover |
| [W3C Accessible names and descriptions](https://www.w3.org/WAI/ARIA/apg/practices/names-and-descriptions/) / [WCAG 2.2](https://www.w3.org/TR/WCAG22/) | 所有可聚焦交互元素有可访问名称；优先使用可见标签，重要和可区分词前置；作为合规规范引用，不整段复制 |
| [Unicode CLDR plural rules](https://cldr.unicode.org/index/cldr-spec/plural-rules) / [MessageFormat](https://messageformat.unicode.org/) | 复数、选择和类型化占位符按 locale 处理；不硬编码英文单复数或拼接半句话 |

许可处理顺序：CC0 原则可以直接改写；MIT 实现或大段材料若被复制需保留 notice；Godot 文档改编需 CC BY 署名；GPL、MPL、CC-BY-SA 项目默认只做结构研究，除非逐文件核验并明确接受义务；W3C 与 Unicode 技术报告作为规范链接引用。

## 4. 六类文字受众

| 分类 | 典型内容 | 翻译 | 正式 UI 可见 | 存储规则 |
| --- | --- | --- | --- | --- |
| `MACHINE_IDENTIFIER` | `card.city_financing.rank_1`、`play_card`、`insufficient_cash`、枚举、save key、资源路径、公式字段 | 否 | 永不直接显示 | 稳定 ASCII `snake_case` 或点分 key；改 key 必须有存档/遥测迁移 |
| `DEVELOPER_DIAGNOSTIC` | assert、validator、debug overlay、trace、性能指标、原始错误、测试编号、`editor_description` | 通常否 | 仅开发构建/QA 面板 | 可含内部 ID 和路径；不得被玩家 fallback 消费 |
| `TRANSLATOR_METADATA` | context、译者注释、变量类型、字符预算、专名表、截图链接、复数说明 | 否 | 永不显示 | 与 key 同版本；构建和翻译工具可读 |
| `PLAYER_VISIBLE` | 菜单、按钮、卡名、规则、教程、状态、错误、确认框、公开/私人日志、胜负说明 | 必须 | 是 | 只能通过本地化目录与受控格式化输出 |
| `PLAYER_ASSISTIVE` | accessible name/description、图标替代文本、完整计数语义、非颜色状态说明 | 必须 | 由屏幕阅读器或辅助呈现消费 | 这是最终玩家文案，不得误归为“机器文字” |
| `PLAYER_GENERATED` | 玩家名、公司名、牌组名、存档名、聊天 | 不自动翻译 | 按权限显示 | 必须转义、过滤、限长并遵守隐私；不得当翻译 key |

### 4.1 “谁看”与“谁有权看”是两条轴

玩家文字还必须标记可见范围：

- `public`：所有玩家与允许的旁观者可见。
- `viewer_private`：只允许指定 `viewer_index`。
- `revealed_at_endgame`：平时隐藏，仅在规则许可的终局审计/结算阶段公开。
- `spectator_sanitized`：旁观者只看到已净化的公开信息。
- `developer_only`：即使内容写得像自然语言，也不能进入正式 UI。

必须先执行可见范围过滤，再把 facts 交给文本解析器。先格式化完整私密句子再“删几个字段”仍可能从句式、数字或 tooltip 泄漏信息。

## 5. 运行时文字数据合同

领域 owner 输出结构化事实，不输出最终句子；现有 presentation/public snapshot owner 把事实映射为文本 key；共享本地化解析器只负责 key、参数和 locale，不拥有游戏规则。

```text
Ruleset / Effect / Receipt
          │
          ├── reason_code / event_code + typed args ──> developer log
          │
          └── visibility filter ──> PlayerTextSpec ──> locale resolver
                                                   ├── visible text
                                                   └── accessible text
```

推荐的运行时 `PlayerTextSpec`：

```gdscript
{
    "message_key": &"ui.card.play.blocked.industry_capacity",
    "args": {
        "industry_name_key": &"term.industry.industrial",
        "required_capacity": 3,
        "current_capacity": 1,
    },
    "audience": &"player_visible",
    "visibility_scope": &"viewer_private",
    "viewer_index": 0,
    "surface": &"disabled_reason",
    "severity": &"blocking",
}
```

对应的内容目录记录：

```yaml
id: ui.card.play.blocked.industry_capacity
zh_Hans: "无法打出这张牌。{industry_name}产能需达到 {required_capacity}，当前为 {current_capacity}。"
context: "手牌禁用原因；玩家自己的信息"
variables:
  industry_name: localized_term
  required_capacity: integer
  current_capacity: integer
character_budget: 48
accessible_name_id: ui.card.play.blocked.industry_capacity.a11y
translator_note: "不要省略当前值；两个数字均由规则数据提供"
developer_event_code: CARD_INDUSTRY_CAPACITY_INSUFFICIENT
status: approved
```

硬规则：

- 保存、回放和网络消息保存 `event_code + typed args`，不保存已翻译句子；这样改语言后仍可重放。
- UI 不得根据中文/英文字符串判断逻辑、状态或目标。
- 不允许 `"现金 " + amount + " 不足"` 这类句子拼接；使用完整模板与命名参数。
- `args.error`、异常 message、文件路径和堆栈只能进开发日志。玩家失败原因必须经过 allowlist 映射。
- key 缺失时，测试应失败；发行运行时显示已本地化的通用安全提示，同时将缺失 key 写入开发日志，绝不显示 raw key。
- 切换 locale 时重新解析当前快照或重新请求 presentation snapshot，不能把旧语言缓存成存档事实。

## 6. 全局玩家文字规则

### 6.1 用词与句法

- 一个规则概念只使用一个正式词。近义词不能为了“写得丰富”而替换关键词。
- 使用玩家任务语言，不使用实现术语：写“自动行动”，不写“概率行动 tick”；写“范围内”，不写 `AOE`。
- 最重要的信息放在开头。先写动作/结果，再写原因和背景。
- 短而完整优先。不能为了省一两个字把“确认加注”缩成含义不明的“确定”。
- 危险、失败、淘汰和资产损失使用中性、克制语气，不责怪玩家，不卖萌。
- 中文按钮和短标签通常不加句号；两句以上解释按正常中文标点书写。
- 只有动作必然还需要输入、选择或确认时才用真正的 `…`；打开普通页面不加省略号，也不用三个句点 `...`。
- 使用真正的 `×`、`−`、`–`、`…` 等 Unicode 符号；机器 ID 始终保持 ASCII。

### 6.2 数字、单位与占位符

- 金额、GDP、百分比、距离、时间、等级、玩家和区域必须是有类型参数，不是文本片段。
- v0.5 玩家界面的 GDP 流量统一显示为 `GDP/min`。内部实时更新频率不是玩家单位。
- 百分比必须说明基数、必要的取整规则和判定边界；不能只写“提高很多”或“约 30%”。
- 金额统一使用规则资源定义的货币格式；同一界面不得混用“钱”“资金”“现金”和硬编码 `¥` 表示同一数值。
- 复数、数字分隔、货币和日期按 locale 格式化。不能使用 `card(s)` 一类英文拼接。
- 动态专名使用 `{player_name}`、`{region_name}` 等命名参数，并做转义与长度限制。

## 7. 卡牌文字合同

### 7.1 数据字段必须分离

| 字段 | 受众 | 用途 |
| --- | --- | --- |
| `card_id` | 机器 | 稳定身份、存档、网络、遥测；不再由中文名称组成 |
| `name_key` | 玩家 | 卡牌正式名称 |
| `type_key` / `industry_keys` | 玩家 | 卡牌类型与一种/两种产业归属 |
| `rules_key` | 玩家 | 完整规则文字模板 |
| `short_effect_key` | 玩家 | 手牌/缩略卡的短效果，不能成为独立规则真相 |
| `reminder_keys` | 玩家 | 关键词提示，完整定义进入规则百科 |
| `flavor_key` | 玩家 | 风味文字；视觉上与规则分开，不承载关键规则 |
| `effect_parameters` / requirements / targets | 机器 | 权威数值、条件、目标与结算行为 |
| `use_case_key` | 玩家 | 图鉴策略建议；不得混入规则正文 |
| `designer_note` | 开发者 | 平衡理由、测试意图和迁移说明；正式 UI 禁止显示 |

### 7.2 卡牌阅读顺序

卡面和详情按同一顺序：

1. 名称与等级。
2. 类型、商品色/产业类别；颜色必须同时有图标或文字。
3. 费用与产业要求。
4. 使用时机。
5. 目标。
6. 按真实结算顺序写效果。
7. 持续时间或终止条件。
8. 例外、公开/私人结果。
9. 关键词提示；风味和策略建议另区显示。

规则句优先使用“条件/费用 → 选择目标 → 执行效果 → 持续/终止 → 公开范围”的顺序。必须明确“最多、至少、恰好、每个、任意一个、其他”等量词。

示例：当前“450米AOE内硬直其他怪兽，延后下一次其他怪兽概率行动”应改成可核对数据的形式：

> 使 450 米内的其他怪兽硬直，并将它们的下一次自动行动各延后 1.5 秒。

其中 `450` 和 `1.5` 来自结构化 effect 数据。若数值变化，卡牌 QA 必须检测 rules 参数是否同步；不能只改句子或只改数值。

### 7.3 卡牌禁止项

- 不使用“强力”“大幅”“高收益”“适合终结”等模糊策略判断代替数值。
- 不把“正式条款见另一资产”作为卡面唯一规则；详情必须能展示持续时间、保证金、上下限等真实 terms。
- 不把 v0.4、owner 回退、猜出牌者等迁移说明写给玩家。
- 不复制《万智牌》、Forge 或其他商业/强许可项目的卡牌原文；只参考结构与语法纪律。
- 不只靠颜色表达六类产业，不把图标本身当作唯一可访问名称。

## 8. 游戏规则说明合同

规则说明采用四层渐进披露，但四层必须来自同一版本语义：

| 阅读层 | 目标时间 | 内容 | 当前落点 |
| --- | --- | --- | --- |
| 行动微文案 | 3–10 秒 | 当前能做什么、费用、禁用原因、结果 | 卡面、按钮、状态条 |
| 情境说明 | 约 30 秒 | 当前对象的完整条件、结算顺序和例外 | 右侧检查器、详情抽屉 |
| 规则速读 | 约 3 分钟 | 胜利、循环、核心资源、怪兽赌局、首局五件事 | `rules_summary_v05.md` / 局内速查 |
| 完整玩家规则 | 争议裁决 | 设置、时序、全部系统、终局、平局、例子、术语 | `tabletop_rulebook_v05.md` |

`rules_v05_runtime_migration.md`、开发计划、测试编号、owner、精度实现和迁移状态属于开发者层，不进入正式玩家规则正文。玩家规则可以明确判定边界，但不应说“实现以万分比计算”或要求玩家读取开发文件。

完整规则的推荐顺序固定为：游戏目标 → 开局设置 → 一局循环/时间窗口 → 可做行动 → 资源与控制 → 例外与冲突 → 结束与平局 → 完整例子 → 术语速查。每条可争议规则尽量回答：触发、行动者、条件、费用、目标、效果、持续、可见范围、冲突/平局。

发布的规则书可以陈述确切数值，但运行时不能从 Markdown 读取参数。v0.5 实装后，CI 应比较 Ruleset Resource、卡牌 effect、规则速读和完整规则中的关键数值，防止四处漂移。

## 9. 各界面文字规则

### 9.1 主菜单与页面标题

建议的主菜单语法为：`继续游戏 / 新游戏 / 教学 / 规则手册 / 设置 / 制作人员 / 退出游戏`。

- 目的地用名词，如“规则手册”“设置”；立即动作使用动词，如“继续游戏”“退出游戏”。
- 无存档时“继续游戏”保持原位置并禁用；可访问说明写明“没有可继续的存档”，不要突然隐藏核心菜单项。
- 主菜单副标题必须描述标准胜利目标，不能继续使用“最后钱最多”；现金最多只是特定星球毁灭结束条件。
- 同层按钮保持同一语法和稳定顺序，不混入 `Continue`、`Back` 等英文开发默认值。

### 9.2 按钮与返回

- 中文动作按钮优先使用“动词 + 对象”，通常 2–6 个汉字：`开始游戏`、`确认加注`、`查看合约`、`摧毁项目`。
- 避免 `确定 / 是 / 否 / 处理 / 提交` 这类脱离上下文就不清楚结果的词。
- “返回”只回到导航栈上一层；“返回主菜单”“返回牌桌”明确目的地。离开会丢失进度时，先说明具体损失。
- 同一操作共享稳定 `action_id`；键鼠、手柄和触控可以有不同快捷键提示，但不能改变动作语义。
- 暂不可用的核心动作应禁用并展示原因和解锁办法；不能等玩家点击后才抛错。

### 9.3 Tooltip

- tooltip 是正式玩家文字，必须本地化；它不是开发注释区。
- 只补充非关键帮助、快捷键或额外解释，不重复可见标签，不承载费用、限制或胜负所必需的信息。
- 不能只支持鼠标 hover；键盘/手柄焦点和触控也应能获得等价信息，并允许关闭。
- 同一控件组若使用 tooltip，应保持覆盖规则一致。
- 被截断的长文本可在 tooltip/详情中显示全文，但必须另有可访问描述。

### 9.4 错误、禁用原因与确认框

错误固定写成：发生了什么 → 玩家需要知道的原因 → 下一步。

> 无法打出这张牌。工业产能需达到 3，当前为 1。

开发日志可同时记录 `CARD_INDUSTRY_CAPACITY_INSUFFICIENT`，但玩家看不到代码。禁止以“未知错误”“失败”“不可用”结束而不给恢复路径。

只有不可逆、高代价、公开秘密信息、覆盖存档或离开未保存进度等操作需要确认。确认框标题点名动作和对象，正文说明具体后果，按钮再次写清结果与退路：

> 摧毁“曙光港”的生产项目？
>
> 该项目的份额和旧合约将永久失效。
>
> `摧毁项目`　`保留项目`

### 9.5 状态、倒计时、事件日志与空状态

- 能通过数值、牌面或地图状态变化表达成功时，不再弹“操作成功”。
- 长操作显示对象、当前状态和进度；倒计时说明“什么窗口还剩多少时间”及锁定后的后果。
- 公共事件日志只使用 public facts；私人日志必须验证 viewer；开发日志另走 developer channel。
- 事件句写行动者（若规则允许公开）、动作、目标、数值结果和持续时间，不暴露隐藏出牌者或完整资产。
- 空状态说明当前为什么为空以及下一步，例如“暂无手牌。购买区域牌或等待补给。”不写 `null`、`empty` 或内部状态名。

### 9.6 无障碍文字

- 每个可聚焦控件都有简短、唯一、可本地化的 accessible name。
- 有可见标签时，accessible name 以相同文字开头；图标按钮也必须提供完整名称。
- accessible description 补充状态、金额、倒计时或后果，不重复整段可见文字。
- 动态数值必须带对象语义，例如朗读“15 点工业产能”，不能只朗读“15”。
- 颜色之外再使用文字、形状或图标；六类产业、合法/非法目标和危险状态不能只靠色相区分。

## 10. 当前文字的删除、替换与推进清单

| 位置/示例 | 当前类型 | 动作 | 目标状态 |
| --- | --- | --- | --- |
| `scripts/main.gd:4984-5036` v0.4 局内速查 | 玩家文字但规则过期 | 替换并从 `main.gd` 删除正文 owner | 读取版本化 v0.5 规则展示资源 |
| `scenes/ui/MenuRootLobby.tscn:53` “最后钱最多” | 玩家文字但目标错误 | 替换 | 描述区域控制与 GDP 审计；特殊毁灭胜利只在完整规则中说明 |
| `MenuOverlay.tscn` 的 `Continue/Back/Previous/Next` | 英文玩家占位 | 删除/替换 | 全部来自本地化 key，默认中文可发布 |
| `BottomCountdownBar.tscn` 的英文沙漏 tooltip | 玩家 tooltip | 替换 | 动态说明当前窗口、剩余时间和结束后果 |
| `planet_district_node.gd` 的 `selected/map node` | 机器状态泄漏 | 替换 | 状态码保持机器层，玩家 label 使用本地化状态名 |
| `scenario_action_log.gd` 的 `snapshot_key/focus_target` tooltip | 开发信息 | 从玩家 UI 删除 | 玩家事件名/可见目标；原字段保留开发日志 |
| `presentation_settings_panel.gd` 的 “Inspector/设置快照” | 开发说明 | 从玩家 UI 删除 | 改为玩家能完成的设置动作说明 |
| `CardResolutionBanner.tscn` 的“避免遮挡中央星球” | 设计理由 | 替换 | 说明当前结算、公开范围和下一步 |
| `card_runtime_catalog_resource.gd` 以 `card_id` 作为 `name` | 机器/玩家耦合 | 替换 | `card_id` + `name_key`，旧 ID 有迁移表 |
| `card_presentation_runtime_service.gd` 显示 `args.error` | 原始开发错误 | 删除 raw fallback | reason allowlist → 玩家 key；原错误仅开发日志 |
| 239 条 `rules_text` | 玩家卡牌规则 | 逐条 v0.5 重审 | effect/text parity、统一术语、真实数值、无旧机制 |
| `TopBar.tscn` 的 `GDP +18/s` | 玩家单位冲突 | 替换 | `GDP/min`，由统一格式化器输出 |
| 英文 pack `display_name` | 当前主要是开发字段 | 明确分类 | 若进入图鉴则加 `display_name_key`；否则只留开发工具 |

## 11. v0.5 初始术语锁

| 正式玩家术语 | 含义 | 避免用法 |
| --- | --- | --- |
| 区域 | 星球上的规则地块 | 不与城市混用 |
| 城市 | 区域中的共享建设空间 | 不写“城市业主/城市所有者” |
| 项目 | 生产、需求、通商等具体 GDP 归因对象 | 不笼统写“我的城市” |
| 个人归属 GDP | 按项目份额归属于某玩家的 GDP | 不简写为含义不明的“我的 GDP” |
| 区域总 GDP | 区域内有效项目 GDP 总和 | 不与个人归属 GDP 混算 |
| 产业产能 | 六类商品 GDP 生成的批次出牌门槛 | 不写“地牌能量”作为正式术语 |
| 共享出牌窗 | 30 秒共享窗口：规划、牌序竞价、锁定及其结算批次 | 非真实回合不要写“本回合” |
| 终局审计 | 120 秒公开验资倒计时 | 不只写“终局倒计时”而省略目的 |
| 怪兽赌局 | 对整场怪兽战斗下注 | 不写“每回合下注” |
| 底注 / 加注 | 首次按现金比例、之后按绝对金额增加 | 不混写“追加底注” |
| 合约 | 同一具体商品的项目对项目关系 | 不写“城市对城市合约” |
| 商品项目竞猜 | 猜特定区域中特定商品项目的控制者 | 不写“猜卡牌归属/猜城市主人” |
| 区域复兴 | GDP 归零后恢复建设资格的规则过程 | 不承诺旧项目/份额自动复活 |

新增或修改玩家术语时，必须同时更新术语目录、卡牌校验、规则速读和 translator note。策略文案可以有风格，规则关键词不能随意换同义词。

## 12. 本地化与 QA 门禁

### 12.1 内容完整性

- 所有 `PLAYER_VISIBLE` 和 `PLAYER_ASSISTIVE` key 有默认简体中文、surface、context、字符预算和 owner。
- 所有命名参数在模板与 schema 中一一对应，类型、单位、复数和可空性可验证。
- 不存在 raw `card_id`、`action_id`、`reason_code`、`null`、资源路径、堆栈、未替换 `{placeholder}` 出现在发行界面。
- 禁止词扫描覆盖 v0.4 旧胜利、城市业主、猜牌归属、旧下注和旧时间窗口术语。

### 12.2 规则一致性

- 239 条等级卡牌逐条比较 effect/requirements/terms 与短效果、完整规则、tooltip。
- Ruleset 的胜利阈值、时间、GDP 单位、底注和加注规则与速读/完整规则一致。
- UI 只渲染 presentation snapshot，不从 `kind`、卡名或文本再推断用途与合法性。

### 12.3 隐私与无障碍

- public snapshot 不能包含 private/revealed-later/developer 文本或可推导参数。
- `viewer_private` 必须验证 viewer；终局揭示由规则状态切换 scope，而不是 UI 自行决定。
- 每个可聚焦控件有可访问名称；可见标签包含在名称中；icon-only、计数器、倒计时和状态变化有等价语义。
- tooltip 不能是完成任务的唯一信息来源，键盘、手柄和触控能取得等价说明。

### 12.4 布局与国际化

- Godot 提取器覆盖所有玩家字符串；机器/玩家生成文字明确排除自动翻译。
- 运行伪本地化，至少覆盖 50% 文本膨胀、重音字符和 placeholder 保留。
- 验证简体中文、英文长文本、CJK 字体回退、RTL 镜像、200% UI 缩放、窄屏、键盘/手柄焦点。
- 截图门检查截断、孤行、省略号、按钮宽度、tooltip 遮挡和详情层可读性。

建议新增门禁：`text_catalog_integrity_test.gd`、`player_text_leak_test.gd`、`card_text_semantics_test.gd`、`privacy_text_scope_test.gd` 和 `localization_layout_test.gd`。这些名称是计划，不表示本轮已经实现。

## 13. 实施顺序

### P0：停止规则与内部字段泄漏

1. 冻结 v0.5 玩家术语和关键数值清单。
2. 建立 `PlayerTextSpec`、audience/scope 协议和“先可见性过滤、后本地化”的所有权边界。
3. 建立稳定 ASCII `card_id` 迁移表和独立 `name_key/rules_key/assistive_name_key`。
4. 为 239 条等级卡牌建立逐条迁移 registry；只有 effect、requirements 和 terms 已经完成 v0.5 hard cutover 的条目才改写玩家文字，其余保持 blocked，不把旧规则文案提前本地化。
5. 将局内速查从 `main.gd` 迁到版本化规则展示资源，删除对应版本的正文 owner；生产仍为 v0.4 时不得提前显示 v0.5 速查。
6. 删除 raw id/raw error fallback，所有 failure reason 走 allowlist 映射。
7. 先建立 `GDP/min` 单位 key 与格式化合同；实际玩家表面在结构化 GDP hard cutover 时统一切换，不在 v0.4 生产界面制造混合单位。
8. 在各 UI surface 迁移时清除主菜单错误胜利描述、明显中英文占位和开发者设计理由。

### P1：建立中央内容目录

1. 建立默认 `zh_Hans` 目录、术语表、translator metadata 和 typed placeholder schema。
2. 让现有 presentation/public snapshot owner 输出 `message_key + args + visibility_scope`。
3. 将菜单、按钮、tooltip、错误、确认框、状态、日志和空状态逐面迁移。
4. `CardPresentationRuntimeService` 接管卡牌所有语义文字；删除 UI 组件中的重复用途推断。

### P2：完成本地化与无障碍质量门

1. 接入 `tr()`/`tr_n()`、context、locale 切换和伪本地化。
2. 增加完整 accessible name/description 与非颜色状态表达。
3. 运行隐私、文本泄漏、长文本、RTL、缩放、焦点和截图门。
4. 最后再增加第二语言；不要在 key、scope 和术语未稳定前批量翻译旧文本。

## 14. 开发者使用检查表

提交任何玩家可见功能前逐项确认：

- 这段文字的 audience 与 visibility scope 是什么？
- 它的稳定 key、默认中文、context、参数类型和字符预算在哪里？
- 数值是否来自 Ruleset/effect/receipt，而不是在句子里另写一份？
- 禁用和失败时，玩家能否知道原因与下一步？
- 是否有 raw id、raw error、开发理由或隐藏信息 fallback？
- 是否需要 accessible name/description，且与可见标签一致？
- 是否通过卡牌/规则语义一致性、隐私、伪本地化和截图检查？
- 若参考外部资料，是否记录 URL、许可和“只学结构还是实际复制”的边界？

未回答这些问题的字符串，不得以“临时文案”为理由进入正式玩家表面。

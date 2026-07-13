# 太空辛迪加开源参考链接索引

> 这个文件集中保存聊天记录中提到的开源/公开参考链接，放在仓库根目录，方便后续 Codex 和人类开发者直接查找。
> 参考原则：可以学习信息结构、交互模式、性能管线、临时美术方向和系统设计；商业发布前必须重新确认 LICENSE、素材授权和可复用范围。

## 桌游电子版 / 星球赌桌 UI 标杆

- [terraforming-mars/terraforming-mars](https://github.com/terraforming-mars/terraforming-mars) — 主标杆。参考中央星球/地图、资源板、玩家区、手牌/已打出卡牌组织、游戏流程和菜单结构。
- [boardgamers/gaia-project](https://github.com/boardgamers/gaia-project) — 参考星图、行动按钮、资源图标化、规则/定义页和桌游电子版信息层级。

## 临时美术 / UI / 音效氛围

- [op7418/Night-Patrol](https://github.com/op7418/Night-Patrol) — 参考临时美术、UI 氛围、按钮、卡框和音效反馈。
- [Night-Patrol releases](https://github.com/op7418/Night-Patrol/releases) — 参考可运行版本、素材打包和发布物结构。

## 卡牌 UI / 手牌手感 / Deckbuilder 标杆

- [twdoor/simple-cards-v-2](https://github.com/twdoor/simple-cards-v-2) — MIT，Godot 4.5.1+。优先研究卡牌 Resource 与外观布局分离、编辑器实时预览、弧形/网格/堆叠手牌、拖放区、牌堆和 Layout 管理面板；不得在现有 `CardRuntimeCatalogService` 旁建立第二套卡牌数据所有权。
- [phase-rs/phase](https://github.com/phase-rs/phase) — MIT / Apache-2.0。参考 battlefield、hand、stack、targeting overlay、payment、动画和隐藏信息；其 Scryfall 卡图及 MTG 内容不属于代码许可，不得导入。
- [ycarowr/UiCard](https://github.com/ycarowr/UiCard) — MIT 代码。优先参考抽卡、拖拽、悬停放大、手牌弧形排布、邻卡让位、打出区和敌方手牌表达；仓库插画另有来源，不随 MIT 代码自动授权。
- [mixandjam/Balatro-Feel](https://github.com/mixandjam/Balatro-Feel) — MIT。参考悬停弹性、选择反馈、邻卡位移、回弹和结算节奏；不复制 Balatro 的视觉资产、商标或界面身份。
- [EnginKARATAS/hearthstone-clone-game](https://github.com/EnginKARATAS/hearthstone-clone-game) — 参考炉石式卡面、角色选择、响应式 UI、战斗界面和动效。
- [pipeworks-studios/CardHouse](https://github.com/pipeworks-studios/CardHouse) — CC0。参考 deck、hand、card grid、发牌、阶段和 position/rotation/scale seeker；Unity 结构要重写成项目本地 GDScript，不直接引入 C# 依赖。
- [Arefnue/NueDeck](https://github.com/Arefnue/NueDeck) — MIT。参考 roguelike deckbuilder 的卡牌编辑器、Scriptable Object 数据结构、奖励选择和内容生产流程；当前项目已有 Resource Catalog，只用于工作流对照。
- [db0/hypnagonia](https://github.com/db0/hypnagonia) — AGPL-3.0。研究 Godot 牌组、状态、图鉴和主题化桌面，只做行为/产品结构观察，不复制代码或素材。
- [db0/godot-card-game-framework](https://github.com/db0/godot-card-game-framework) — AGPL-3.0。研究卡牌场景、拖放、手牌/牌库和规则脚本边界；除非项目明确接受 AGPL 义务，否则不复制实现。
- [Cyanilux/Cards](https://github.com/Cyanilux/Cards) — 由聊天中仓库名补全链接。参考小型 Unity 手牌交互、card model 和 Shader Graph 卡牌显示。
- [GBALATRO/balatro-gba](https://github.com/GBALATRO/balatro-gba) — 参考像素风小丑牌式布局和小屏幕信息压缩；不要直接使用同人视觉素材。
- [GitHub topics: slaythespire](https://github.com/topics/slaythespire) — 作为 Slay the Spire-like / roguelike deckbuilder 的项目发现入口。

## 游戏文字 / 卡牌规则 / 本地化 / 无障碍

### 可直接改写的开放文案原则

- [18F Technical and interface writing](https://guides.18f.org/content-guide/our-style/technical-and-interface-writing/) / [License](https://guides.18f.org/content-guide/license/) — 美国公有领域并以 CC0 全球放弃权利。优先采用短句、主动动词、正向措辞，以及教程必须逐字匹配真实按钮/菜单名的原则。
- [USWDS Button](https://designsystem.digital.gov/components/button/) / [Tooltip](https://designsystem.digital.gov/components/tooltip/) — 主体 CC0，第三方素材另核。参考“按钮说明动作结果、链接负责导航”和“tooltip 不承载关键内容”的规则。
- [OpenDuelyst card factory](https://github.com/open-duelyst/duelyst/tree/main/app/sdk/cards/factory) / [locales](https://github.com/open-duelyst/duelyst/tree/main/app/localization/locales) / [License](https://github.com/open-duelyst/duelyst/blob/main/LICENSE) — CC0-1.0。重点研究卡牌数值/效果对象与名称/描述本地化分离；不复制品牌、角色或整体视觉身份。

### 开源游戏文字结构参考

- [OpenTTD English string table](https://github.com/OpenTTD/OpenTTD/blob/master/src/lang/english.txt) / [License](https://github.com/OpenTTD/OpenTTD/blob/master/COPYING.md) — GPL-2.0。研究 BUTTON、TOOLTIP、标题、单位、复数和占位符分区；不复制现成字符串。
- [FreeOrion string tables](https://github.com/freeorion/freeorion/tree/master/default/stringtables) / [License](https://github.com/freeorion/freeorion#license) — 代码 GPLv2、资产 CC-BY-SA-3.0、脚本双许可。研究稳定 key、英文 fallback、占位符注释和“短标签—提示—百科”分层。
- [Unciv translation template](https://github.com/yairm210/Unciv/blob/master/android/assets/jsons/translations/template.properties) / [License](https://github.com/yairm210/Unciv/blob/master/LICENSE) — MPL-2.0。研究命名占位符、菜单/按钮/消息分区和译者警告；不复制文明系列文本。
- [Battle for Wesnoth translation domains](https://github.com/wesnoth/wesnoth/tree/master/po) / [InterfaceActionsWML](https://wiki.wesnoth.org/InterfaceActionsWML) — GPLv2+，部分新资产 CC-BY-SA-4.0。研究核心、帮助、教程、单位、战役文本域，以及玩家/等待/调试信息分离。
- [0 A.D. localization](https://github.com/0ad/0ad/tree/master/binaries/data/mods/public/l10n) / [License](https://github.com/0ad/0ad/blob/master/LICENSE.txt) — GPLv2+、CC-BY-SA-3.0 和第三方例外。研究大厅、设置、局内、手册、教程分目录；逐目录核验许可。
- [Cataclysm: DDA translation guide](https://docs.cataclysmdda.org/TRANSLATING.html) / [JSON text rules](https://docs.cataclysmdda.org/JSON/JSON_INFO.html) — CC-BY-SA-3.0，含第三方例外。研究 `NO_I18N`/`I18N`、上下文、复数和译者注释；不复制内容文本。

### 写作、本地化与无障碍规范

- [GitLab UI text](https://design.gitlab.com/content/ui-text/) / [Destructive actions](https://design.gitlab.com/patterns/destructive-actions/) — MIT。参考扫读优先、破坏操作点名对象、错误说明下一步；实质复制保留 notice。
- [PatternFly Error messages](https://www.patternfly.org/ux-writing/error-messages/) — MIT。采用“发生了什么—原因—解决办法”结构。
- [Godot Internationalizing games](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html) / [gettext](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_gettext.html) / [Pseudolocalization](https://docs.godotengine.org/en/4.7/tutorials/i18n/pseudolocalization.html) — 参考 `tr()`、`tr_n()`、context、译者注释、伪本地化、RTL 和动态切语言；文档改编需遵守 CC BY 3.0。
- [KDE Text and labels](https://develop.kde.org/hig/text_and_labels/) / [GNOME Writing Style](https://developer.gnome.org/hig/guidelines/writing-style.html) / [GNOME Tooltips](https://developer.gnome.org/hig/patterns/feedback/tooltips.html) — 只吸收短而精确、祈使动词、图标按钮文字、tooltip 非关键等原则，不复制 ShareAlike 文段。
- [W3C Accessible names and descriptions](https://www.w3.org/WAI/ARIA/apg/practices/names-and-descriptions/) / [WCAG 2.2](https://www.w3.org/TR/WCAG22/) — 作为合规规范引用：所有可聚焦元素有可访问名称，可见标签优先且重要词前置。
- [Unicode CLDR Plural Rules](https://cldr.unicode.org/index/cldr-spec/plural-rules) / [MessageFormat](https://messageformat.unicode.org/) — 复数、选择、数字和命名占位符按 locale 处理，不拼接半句话。

完整的受众分层、卡牌语法、菜单/按钮/tooltip/错误规则、当前泄漏清单与迁移门见 `docs/player_facing_text_and_rules_presentation_contract.md`。

## 经济、卡牌规则与离线仿真参考

### 经济运行与 GDP

- [schombert/Project-Alice](https://github.com/schombert/Project-Alice) — GPL-3.0。研究大型商品、人口、工厂和国家经济模块边界；只做结构/公式观察，不复制代码或依赖其原版游戏资产。
- [unknown-horizons/unknown-horizons](https://github.com/unknown-horizons/unknown-horizons) — GPL-2.0。研究较易理解的居民需求、商品供应、税收、贸易和城镇升级循环；不复制 GPL 实现。
- [freeorion/freeorion](https://github.com/freeorion/freeorion) — GPL 系列许可且素材需逐项核验。研究星球人口、工业、科研、资源分配、威胁和脚本规则分层；不导入其代码或资产。
- [OpenVicProject/OpenVic-Simulation](https://github.com/OpenVicProject/OpenVic-Simulation) — MIT。优先参考经济数据对象、人口群体和日/月模拟更新的模块组织；在采用任何实现前仍需核对具体文件和依赖许可。
- [BEA: Value added](https://www.bea.gov/help/glossary/value-added) — 官方经济口径参考：行业增加值是总产出减去中间投入。用于离线 GDP 诊断和重复计算检查，不自动替换当前 v0.4 游戏公式。

### 卡牌状态、行动队列与平衡

- [finkmoritz/csbcgf](https://github.com/finkmoritz/csbcgf) — MIT。优先研究只通过 Action 修改状态、执行前重新检查合法性、反应链和 simultaneous action 语义；对照现有 Eligibility / Queue / Execution，不建立第二套规则引擎。
- [boardgameio/boardgame.io](https://github.com/boardgameio/boardgame.io) — MIT。研究阶段行动权限、状态/视图分离、日志、回放和 AI 测试；项目是实时 30/25/5 窗口，不能直接照搬传统回合循环。
- [google-deepmind/open_spiel](https://github.com/google-deepmind/open_spiel) — Apache-2.0。用于离线卡组、AI、同时行动和不完全信息实验；不作为 Godot 玩家运行时依赖。
- [Card-Forge/forge](https://github.com/Card-Forge/forge) — GPL-3.0。观察复杂触发、替代/持续效果、优先权和卡牌 AI；不复制代码、卡牌数据、规则文本或 MTG 内容。

### 怪兽行动与战斗规则

- [statico/godot-roguelike-example](https://github.com/statico/godot-roguelike-example) — MIT 代码，素材许可分开。研究 Godot 4 行动系统、行为树、阵营、伤害/抗性、状态和数据驱动怪兽定义；不把实时怪兽改成玩家直接控制或照搬回合循环。
- [OpenXcom/OpenXcom](https://github.com/OpenXcom/OpenXcom) — GPL-3.0，且原版游戏资源不开放。研究敌人 AI、命中、护甲、朝向、士气、恐慌和战术任务；只做行为观察。
- [CleverRaven/Cataclysm-DDA](https://github.com/CleverRaven/Cataclysm-DDA) — 代码与数据包含强 copyleft/署名共享条款，必须逐文件核验。研究怪物特殊攻击、抗性、状态和数据结构；巨兽保持单个逻辑实体，不用多格身体参与路径规则。

这些规则参考的采用门、v0.4 保留项、可删除旧路径和离线实验路线见 `docs/runtime_rule_reference_adoption_plan.md`。

## 游戏菜单 / 整体平面界面

- [Maaack/Godot-Game-Template](https://github.com/Maaack/Godot-Game-Template) — MIT，当前面向 Godot 4.7（兼容 4.3+）。优先参考主菜单、暂停、设置、辅助功能、加载、教程、UI 音效、键鼠/手柄导航和场景切换边界。
- [Maaack/Godot-Menus-Template](https://github.com/Maaack/Godot-Menus-Template) — MIT，当前面向 Godot 4.7（兼容 4.3+）。参考轻量菜单壳、设置/制作人员子页、返回栈和 Scene Loader；不在现有 `MenuOverlay` 旁建立并行菜单系统。
- [chickensoft-games/GameDemo](https://github.com/chickensoft-games/GameDemo) — MIT。参考主菜单、游戏、暂停、存档/读档的可测试状态机和页面生命周期；项目为 Godot C#，只吸收状态边界，不引入第二套 C# 运行框架。
- [freeorion/freeorion](https://github.com/freeorion/freeorion) — GPL 系列代码且素材许可需逐目录核验。重点研究中央星图、顶部资源、侧边情报、生产/科研窗口和回合提示的信息层级；不复制代码、素材或 FreeOrion 视觉身份。
- [yairm210/Unciv](https://github.com/yairm210/Unciv) — MPL-2.0。参考高信息密度策略界面、地图与弹窗并存、桌面/移动响应式布局；若未来复制源文件必须逐文件遵守 MPL，本项目当前只做产品结构研究。
- [OpenRA/OpenRA](https://github.com/OpenRA/OpenRA) — GPL-3.0。参考大厅、战役选择、设置和游戏内侧栏的一致视觉语言；不复制 GPL 代码或原游戏 IP 素材。
- [popcar2/GodotOS](https://github.com/popcar2/GodotOS) — AGPL-3.0，且仓库还引用第三方壁纸和图标。只研究窗口层级、侧边栏、统一图标和深色界面组织，不复制代码或素材。

## 页面返回 / 焦点 / 导航栈

- [levinzonr/godot-ui-navigation-system](https://github.com/levinzonr/godot-ui-navigation-system) — MIT，早期项目。参考 `push()` / `pop()`、NavigationGraph、转场和返回后焦点恢复；拆解思路后接入现有 `MenuOverlay` 与 `CodexNavigationRuntimeController`，不直接安装为第二套导航权威。
- [AppNavigation](https://godotengine.org/asset-library/asset/4813) — AGPL-3.0，Godot 4.5 路由/页面栈资产。只研究 app-like 路由、栈和页面生命周期，除非项目明确接受 AGPL 义务，否则不复制代码。
- [supertuxkart/stk-code](https://github.com/supertuxkart/stk-code) — GPL。参考成熟多层菜单、手柄焦点、Esc 返回、确认窗口和大厅流程；只做行为研究。

## 卡牌 / 牌桌 / 科幻 HUD 平面素材

- [Mechanized Magic: Ultimate UI Pack](https://opengameart.org/content/mechanized-magic-2d-vector-cards-pack-0) — CC0。免费包含 60 个图标、75 个 HUD 元素及多种样式；作为卡框、机械边饰和策略 HUD 的第一视觉候选。
- [Kenney UI Pack - Sci-Fi](https://kenney.nl/assets/ui-pack-sci-fi) — CC0，130 个文件。作为按钮、面板、滑块、状态条和弹窗的首选控件素材基线。
- [Kenney UI Pack](https://kenney.nl/assets/ui-pack) — CC0，430 个文件。只补齐 Sci-Fi Pack 缺少的通用控件状态，不与主视觉无选择混用。
- [Kenney Board Game Icons](https://kenney.nl/assets/board-game-icons) — CC0，250 个文件。用于现金、资源、牌堆、竞价、回合状态和桌面操作图标。
- [Kenney Board Game Info](https://kenney.nl/assets/board-game-info) — CC0，280 个文件。用于规则、教程、关键词、状态和信息提示图标。
- [Kenney Board Game Pack](https://kenney.nl/assets/boardgame-pack) — CC0，490 个文件。用于牌堆、弃牌堆、筹码、骰子和桌面占位原型；不直接决定最终卡面风格。
- [Kenney Playing Cards Pack](https://kenney.nl/assets/playing-cards-pack) — CC0，270 个文件。主要研究卡面比例、角标重复、花色识别和牌背结构。
- [SCIFI UI](https://opengameart.org/content/scifi-ui) — CC0，含按钮、面板、进度条、输入框和 PSD。只作为深色 HUD 灰盒/切片参考，避免与 Kenney/Mechanized Magic 同屏拼贴。
- [UI Minimalism SciFi](https://opengameart.org/content/assets-ui-minimalism-scifi) — CC0，提供简洁科幻 UI 元素和源文件。与 Kenney Sci-Fi 二选一或作为缺失状态补充，不再把管线贴图/模型列为核心视觉依赖。
- [Wenrexa White UI Kit](https://opengameart.org/content/assets-wenrexa-free-ui-kit-white-interface-5-panels-buttons) — CC0，五色 PNG 面板/按钮。优先用于高对比开发者、QA 和经济报表界面，不作为主桌默认视觉。
- [Game-icons.net](https://game-icons.net/about.html) — CC BY 3.0。仅选择 CC0 图标库缺少的语义图标；必须按每个图标的原作者登记并在 Credits 中署名。

这批卡牌、牌桌、菜单与 HUD 参考的采用顺序、旧资产退役门和 QA 路线见 `docs/card_table_menu_reference_adoption_plan.md`。

## 商路 / 逻辑管线 / 图结构交互

### Godot 官方能力边界

- [Godot Line2D](https://docs.godotengine.org/en/stable/classes/class_line2d.html) — 只负责曲线/线段显示；不得在节点中保存商品库存、容量、费用、所有权或结算状态。
- [Godot AStar2D](https://docs.godotengine.org/en/stable/classes/class_astar2d.html) — 只负责图上的路径搜索；是否可连、边成本、方向、容量和阻塞仍由游戏规则所有者决定。
- [Godot GraphEdit](https://docs.godotengine.org/en/stable/classes/class_graphedit.html) — 提供节点连接编辑交互；连接是否合法以及连接后发生什么必须由项目代码实现。优先用于编辑器/QA 工具，不直接成为主桌规则引擎。

### 网络与铺设产品参考

- [Anuken/Mindustry](https://github.com/Anuken/Mindustry) — GPL-3.0。研究合法预览、自动朝向/转角、拖拽连续铺设、桥接和按段撤销；只观察交互，不复制代码或素材。
- [tobspr-games/shapez.io](https://github.com/tobspr-games/shapez.io) — GPL-3.0。研究生产节点、方向、分流/合流、吞吐量、蓝图和大规模网络更新；不复制 GPL 实现。
- [OpenLoco/OpenLoco](https://github.com/OpenLoco/OpenLoco) — MIT。优先研究拖拽施工标记、曲线/坡度、非法地形提示、拆除和蓝图旋转；运行原项目仍依赖原版游戏资产，因此不得把原资产带入本项目。
- [widelands/widelands](https://github.com/widelands/widelands) — GPL-2.0+，素材许可需逐项核验。研究“节点/旗帜作为端点、道路作为边”的网络模型；只做结构观察。

商路显示、返回栈、未来铺设交互、旧路径退役和“不得建立第二个路线引擎”的详细计划见 `docs/navigation_trade_network_reference_adoption_plan.md`。

## 巨兽 / 城市破坏 / 灾害感参考

### 许可明确、可进入原型验证的素材与 Godot 模块

- [Quaternius Ultimate Monsters](https://quaternius.com/packs/ultimatemonsters.html) — CC0。50 个带动画怪兽，提供 FBX、OBJ、Blend、glTF；优先用于怪兽轮廓、动作词汇、体型分级和临时动画验证，不直接照搬为最终角色设计。
- [Quaternius Animated Mech Pack](https://quaternius.com/packs/animatedmech.html) — CC0。4 个带动画机甲；用于军队/巨型机甲与生物怪兽的轮廓对比、机械动作节奏和图鉴姿态参考。
- [Quaternius Animated Monster Pack](https://quaternius.com/packs/animatedmonster.html) — CC0。4 个带攻击、移动、跳跃或飞行动画的怪物；用于快速验证不同运动方式和动作可读性。
- [Kenney City Kit (Commercial)](https://kenney.nl/assets/city-kit-commercial) — CC0。50 个商业建筑模型；用于城市密度、天际线、建筑尺寸层级和完整/受损/摧毁状态原型。
- [Kenney City Kit (Suburban)](https://kenney.nl/assets/city-kit-suburban) — CC0。40 个郊区建筑模型；用于低密度城区、住宅区和商业区的视觉区分。
- [Jummit/godot-destruction-plugin](https://github.com/Jummit/godot-destruction-plugin) — 代码 MIT，其余项目文件 CC0。重点参考 Blender Cell Fracture 预切割、完整模型到碎块场景的替换和 `destroy()` 事件边界；不要未经性能验证直接接入主桌。
- [ape1121/Godot4-3D-Smooth-Destructible-Terrain](https://github.com/ape1121/Godot4-3D-Smooth-Destructible-Terrain) — MIT。参考分块、脏区重建和局部地形修改；不用于替换现有球形 `MapView`。
- [KenneyNL/Starter-Kit-3D-Platformer](https://github.com/KenneyNL/Starter-Kit-3D-Platformer) — 代码 MIT，内含素材 CC0。仅参考第三人称相机、控制器、手柄输入和代码/素材分层；Space Syndicate 怪兽仍保持自动行动。
- [godotengine/godot-demo-projects](https://github.com/godotengine/godot-demo-projects) — MIT。用于核对 Godot 场景组织、动画、物理、输入和官方实现习惯。
- [Kenney Particle Pack](https://kenney.nl/assets/particle-pack) — CC0。80 个粒子/VFX 文件；用于攻击落点、冲击波、建筑受损和怪兽技能的临时反馈。
- [CC0 Deep Monster Roar](https://opengameart.org/content/cc0-deep-monster-roar) — CC0。低沉怪兽吼叫；可用于召唤、登场或高威胁动作的临时音频验证。

详细的使用边界、落地位置和验收门禁见 `docs/open_source_reference_notes.md` 的“Giant Monster Combat Reference Pack / 巨兽战斗参考包”。

### 结构与题材研究入口

- [binary-machinery/DisasterCity](https://github.com/binary-machinery/DisasterCity) — 优先参考。Kaiju-like 巨兽攻击城市的 RTS 原型，参考城市被怪兽压迫时的全局态势表达。
- [Moth-Fried-Games/moth-kaijuice](https://github.com/Moth-Fried-Games/moth-kaijuice) — Godot / MIT game jam 原型，参考怪兽成长、实验室/怪兽题材 UI 和 Godot 项目组织。
- [PolyBrew-Studios/GMTK2024-CARJU](https://github.com/PolyBrew-Studios/GMTK2024-CARJU) — 参考“破坏/吸收碎片/变大”的循环。
- [GitHub topics: carju](https://github.com/topics/carju) — CARJU / Godzilla-Katamari-Car 类项目发现入口。
- [Amnexistence/Destroyable_Buildings_Generation](https://github.com/Amnexistence/Destroyable_Buildings_Generation) — 优先参考。可破坏建筑生成，适合巨兽撞楼、建筑碎裂和破坏状态生成。
- [ALEX-WHISPER/ARDestructibleScene](https://github.com/ALEX-WHISPER/ARDestructibleScene) — 参考爆炸、弹坑、建筑碎裂和粒子反馈。
- [RobDiggle/kaiju_battle](https://github.com/RobDiggle/kaiju_battle) — Kaiju battle 公开仓库，参考前需确认 LICENSE。
- [phoenixgoldz/KaijuUprising-UE5](https://github.com/phoenixgoldz/KaijuUprising-UE5) — UE5 Kaiju 公开仓库，适合看 Unreal 项目结构。
- [N64brew-Game-Jam-2025/kaiju-response-team](https://github.com/N64brew-Game-Jam-2025/kaiju-response-team) — 参考“城市受损 → 抢救/修复 → 小地图提示”的循环。
- [doctor-g/KaijuHomecoming](https://github.com/doctor-g/KaijuHomecoming) — 参考怪兽主题、城市玩具感比例和原型资产组织。
- [mattbucci/destruct-o](https://github.com/mattbucci/destruct-o) — 参考体素破坏、碎裂对象和破坏后状态保存。
- [KaijuEngine/kaiju](https://github.com/KaijuEngine/kaiju) — 不是巨兽游戏；可作为 2D/3D 原型工程结构参考。

## 行星 / 球面 / 科幻空间参考

- [Zylann/solar_system_demo](https://github.com/Zylann/solar_system_demo) — Godot 4 + Voxel Tools 太空 demo，参考地表到太空、程序星球、简单大气和飞行尺度感。
- [pioneerspacesim/pioneer](https://github.com/pioneerspacesim/pioneer) — 参考星系探索、登陆行星、飞船 HUD 和太空经济氛围。
- [marceld23/BlocksBeyondTheStars](https://github.com/marceld23/BlocksBeyondTheStars) — 优先参考。太空建造沙盒，参考程序恒星系、行星登陆、基地/空间站和太空沙盒背景。
- [TheOpenSpaceProgram/osp-magnum](https://github.com/TheOpenSpaceProgram/osp-magnum) — 参考飞行器、刚体物理、轨道和行星地形组件。
- [OoliteProject/oolite](https://github.com/OoliteProject/oolite) — 参考 Elite 风格科幻 HUD、飞船战斗、星系交易和扩展包结构。
- [vegastrike/Vega-Strike-Engine-Source](https://github.com/vegastrike/Vega-Strike-Engine-Source) — 参考探索、贸易、战斗、多星系、HUD、爆炸和动态宇宙。
- [cuberact/godot-cuberact-planet-chunked-lod](https://github.com/cuberact/godot-cuberact-planet-chunked-lod) — Godot 4.6 程序星球，参考动态 LOD、地形和大气。
- [athillion/ProceduralPlanetGodot](https://github.com/athillion/ProceduralPlanetGodot) — 参考球形星球生成和 Sebastian Lague 式星球构造。
- [Hoimar/Planet-Generator](https://github.com/Hoimar/Planet-Generator) — 参考 Godot 程序星球 addon、噪声地形和可配置生成。
- [Stevepetoskey/TinyPixelPlanetsPublic](https://github.com/Stevepetoskey/TinyPixelPlanetsPublic) — 参考像素化星球、探索、建造和小屏幕宇宙 UI。
- [CaveJohnson376/godot-3dplanets](https://github.com/CaveJohnson376/godot-3dplanets) — 参考球面角色/相机方向处理和方块放置。
- [Bauxitedev/stylized-planet-generator](https://github.com/Bauxitedev/stylized-planet-generator) — 参考简洁可读的风格化程序星球临时美术。

## Brotato / Vampire Survivors-like / Roguelike 随机性与碰撞参考

- [Roo-Roo-Roo/survivors-roguelike-kit](https://github.com/Roo-Roo-Roo/survivors-roguelike-kit) — 最优先参考。完整 Unity 2D survivors-like 模板，参考 playable loop、角色/关卡、技能、敌人、buff、loot、程序化刷怪、进化武器和伤害飘字。
- [matthiasbroske/VampireSurvivorsClone](https://github.com/matthiasbroske/VampireSurvivorsClone) — 参考武器冷却、自动发射、碰撞、伤害、掉落、宝箱和刷怪概率/速率 keyframe。
- [yagizkoryurek/Vampire_Survivors-clone](https://github.com/yagizkoryurek/Vampire_Survivors-clone) — Python/Pygame，参考最小化攻击结算、XP/升级、武器进化、Boss、宝箱、金币和 meta progression。
- [kairess/Vampire-Survivors-Python](https://github.com/kairess/Vampire-Survivors-Python) — 参考玩家移动、敌人追踪、碰撞、攻击判定和经验掉落。
- [Quillraven/slime-survivor](https://github.com/Quillraven/slime-survivor) — 参考 rectangle overlapping、vector-based movement、attack animations、player movement 和 audio。
- [jody3t/brotato-clone](https://github.com/jody3t/brotato-clone) — Brotato-style arena survivor，参考控制器支持和网页端小型结构。
- [newbdez33/minecraft-survivors](https://github.com/newbdez33/minecraft-survivors) — Godot 4.5 + GDScript，参考自动攻击、XP/升级、附魔式升级、武器进化、昼夜刷怪修正、Boss 和测试脚本；不要使用主题 IP 素材。
- [imitatehappiness/GDLastOfTheSurvivors](https://github.com/imitatehappiness/GDLastOfTheSurvivors) — Godot top-down survival，参考波次推进和升级后选择新武器/被动物品。
- [BLXCKBXXST/brotato-mini](https://github.com/BLXCKBXXST/brotato-mini) — Godot 4.4 / Brotato inspired，参考 Brotato 风格 Godot 入口。
- [giovanneluna/poke-survivors](https://github.com/giovanneluna/poke-survivors) — Phaser 3 + TypeScript，参考 attacks/entities/systems/Collision/Spawn/SpatialHashGrid 等系统分层；不要使用 fan-made IP 素材。
- [KeJunMao/emoji-survival-game](https://github.com/KeJunMao/emoji-survival-game) — 参考前端 survivors-like 的碰撞事件、NPC 和道具购买结构。
- [larkan28/monster-waves](https://github.com/larkan28/monster-waves) — Unity 小型 Vampire Survivors-like，适合看最小波次/生存实现。
- [BrotatoMods/Brotato-ContentLoader](https://github.com/BrotatoMods/Brotato-ContentLoader) — 参考 Brotato mod 内容扩展。
- [otDan/Brotato-WeaponExplorer](https://github.com/otDan/Brotato-WeaponExplorer) — 参考武器数据显示和数据浏览。
- [BrotatoMods/Brotato-Attack-Speed-Calculator](https://github.com/BrotatoMods/Brotato-Attack-Speed-Calculator) — 参考冷却/攻速面板和数值说明。
- [GitHub topics: brotato](https://github.com/topics/brotato) — Brotato-like 项目发现入口。

## Godot 性能管线 / 防卡顿 / 批量演出

- [Godot Background loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html) — 后台加载；大型资源切换优先使用 `ResourceLoader.load_threaded_request()`。
- [Reducing stutter from shader/pipeline compilations](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html) — 防首次特效/材质/怪物出现时的 shader/pipeline 编译卡顿。
- [Godot Profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html) — 定位脚本、物理、渲染、粒子、UI 或资源加载瓶颈。
- [General optimization](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html) — 官方通用优化流程，先 profile 再优化。
- [Using MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html) — 参考大量同类视觉对象批量渲染。
- [Optimization using Servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html) — 参考 RenderingServer / PhysicsServer 低层批量控制。
- [Project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html) — Godot 项目组织。
- [Import process](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/import_process.html) — Godot 资源导入流程。
- [When and how to avoid using nodes for everything](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html) — 高频对象避免过量 SceneTree 节点。
- [Logic preferences](https://docs.godotengine.org/en/stable/tutorials/best_practices/logic_preferences.html) — Godot 逻辑组织偏好。
- [godotengine/godot-demo-projects](https://github.com/godotengine/godot-demo-projects) — 官方 demo 总仓库。
- [Godot threaded loading demo](https://github.com/godotengine/godot-demo-projects/blob/939ca55eaad4b3fa156a88289deef2e3e9479679/loading/load_threaded/load_threaded.gd) — 官方 MIT 异步加载最小实现参考。
- [Maaack/Godot-Scene-Loader](https://github.com/Maaack/Godot-Scene-Loader) — 场景加载、进度条、错误处理和 autoload 式切换。
- [Maaack/Godot-Game-Template](https://github.com/Maaack/Godot-Game-Template) — 正式项目菜单、暂停、设置、scene loader 和 global state 结构。
- [anasrar/godot-object-pooling](https://github.com/anasrar/godot-object-pooling) — Godot 4 对象池示例。
- [Minoqi/minos-damage-numbers-for-godot](https://github.com/Minoqi/minos-damage-numbers-for-godot) — Godot 4 伤害数字插件，含对象池。
- [sempitern0/Fast-Pool](https://github.com/sempitern0/Fast-Pool) — 轻量对象池参考。

## Codex / 项目协作参考

- [Custom instructions with AGENTS.md](https://developers.openai.com/codex/guides/agents-md?utm_source=chatgpt.com) — 参考 `AGENTS.md` 作为项目级稳定指令的用途。

## 当前落地优先级

1. 卡牌组件与编辑器工作流：优先参考 Simple Cards v2；只吸收编辑器预览、布局和动画 Resource 思路，不替换现有 Runtime Catalog。
2. 牌桌信息结构：优先参考 Phase 的战场/结算栈/目标/支付/隐藏信息边界，并保留 Space Syndicate 的中央星球、匿名牌轨和右侧检查器。
3. 手牌手感：优先参考 CardHouse、UiCard 和 Balatro-Feel，以本地 GDScript/Resource 重写，不导入 Unity 运行时。
4. 卡框、HUD 和图标：Mechanized Magic + Kenney Sci-Fi + Kenney Board Game Icons/Info 为主；Game-icons 只补语义缺口并保留逐作者署名。
5. 菜单和辅助功能：用 Maaack/Chickensoft 的生命周期模式强化现有 Menu 场景，并按统一返回优先级收束 `main.gd` 的 Esc/back 分支；不建立第二套菜单壳。
6. 商路交互：先把现有自动派生商路做成可检查、可聚焦、可读流向的场景表现。规则书未授权手动铺设时，不新增管线建造规则；`CityTradeNetworkRuntimeController` 继续是唯一网络 owner。
7. 未来铺设原型：只有规则变更获批后，才借鉴 Mindustry/OpenLoco/Widelands 的预览、吸附、成本和撤销；`Line2D` 只显示，`AStar2D` 只寻路，`GraphEdit` 只服务编辑器工具。
8. 巨兽演出：继续按巨兽参考包推进短时演出、城市破坏和 VFX，不改变自动行动规则。
9. 性能：持续使用 Godot Background loading、pipeline compilation、Profiler 和 object pooling 作为验收基线。

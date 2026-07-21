# 太空辛迪加参考标杆笔记

> 目的：把开源标杆项目的界面经验转成可执行的开发规则，避免只停留在“看过参考”。
> 本地参考目录位于 `C:/Users/Administrator/Documents/New project/reference/`。

## 已下载参考

- `terraforming-mars`：重点参考主游戏页、顶栏、玩家信息、手牌/已打出卡牌的折叠组织。
- `gaia-project`：重点参考星图 SVG、行动按钮、资源表格、规则/定义页的图标化结构。
- `Night-Patrol`：重点参考临时美术、卡框、按钮、音效和启动图氛围。其仓库声明为 CC BY-NC 4.0，开发期可借鉴，商业发行前应替换或重新确认授权。
- `hypnagonia`：来自 GitHub `topics/slaythespire`，Godot/GDScript 的 spire-like deckbuilder。重点参考卡牌数据组织、卡牌 hover 解释、商店/奖励选择和可完整跑通的 deckbuilder 流程；其仓库为 AGPL-3.0，当前仅做结构和交互参考。
- `UiCard`：重点参考手牌弧形、hover 放大、拖拽、弃牌/出牌区和运动参数；MIT license，当前只抽取交互原则。

## 在线参考清单

### 卡牌 UI / game feel 标杆

- [ycarowr/UiCard](https://github.com/ycarowr/UiCard)：优先级最高。专门做 Hearthstone / Magic Arena / Slay the Spire 型卡牌 UI，重点参考抽卡、拖拽、悬停放大、手牌弧形排布、弃牌区域和敌方卡牌查看。
- [mixandjam/balatro-feel](https://github.com/mixandjam/balatro-feel)：参考 Balatro 式卡牌反馈、抖动、弹性、拖拽、选择和结算手感。
- [EnginKARATAS/hearthstone-clone-game](https://github.com/EnginKARATAS/hearthstone-clone-game)：参考网页端炉石式卡面、角色选择、响应式 UI、战斗界面和动效节奏。
- [Arefnue/NueDeck](https://github.com/Arefnue/NueDeck)：参考 Slay the Spire / Roguebook 式 roguelike deckbuilder 模板、卡牌编辑器和数据架构。
- [phase-rs/phase](https://github.com/phase-rs/phase)：参考 MTG Arena 类 battlefield / hand / stack / targeting overlay / payment / animation 分区。
- [pipeworks-studios/CardHouse](https://github.com/pipeworks-studios/CardHouse)：参考 deck、hand、card grid、拖拽、资源 UI、position/rotation/scale seeker 组件。
- [Cyanilux/Cards](https://github.com/Cyanilux/Cards)：参考小型 Unity 手牌交互、card model 和 Shader Graph 卡牌显示。
- [GBALATRO/balatro-gba](https://github.com/GBALATRO/balatro-gba)：参考像素风小丑牌式布局和极小屏幕信息压缩；视觉素材偏同人性质，后续不能直接商用照搬。

### 巨兽 / 城市破坏 / 灾害感参考

- [binary-machinery/DisasterCity](https://github.com/binary-machinery/DisasterCity)：优先参考。Unity RTS 原型，主题就是巨型 kaiju-like 怪兽攻击城市；重点参考城市被怪兽压迫时的全局态势表达。
- [Moth-Fried-Games/moth-kaijuice](https://github.com/Moth-Fried-Games/moth-kaijuice)：Godot / MIT game jam 原型，参考怪兽成长、实验室/怪兽题材 UI 和 Godot 项目组织。
- [PolyBrew-Studios/GMTK2024-CARJU](https://github.com/PolyBrew-Studios/GMTK2024-CARJU)：Unity “godzilla-katamari-car” 方向，参考破坏、吸收碎片、变大的循环。
- [Amnexistence/Destroyable_Buildings_Generation](https://github.com/Amnexistence/Destroyable_Buildings_Generation)：优先参考。Unity C# / CC0-1.0，可破坏建筑生成；重点参考巨兽撞楼、建筑碎裂和破坏状态生成。
- [ALEX-WHISPER/ARDestructibleScene](https://github.com/ALEX-WHISPER/ARDestructibleScene)：Unity AR 破坏 demo，参考炸弹爆炸、弹坑、建筑碎裂和粒子反馈。
- [N64brew-Game-Jam-2025/kaiju-response-team](https://github.com/N64brew-Game-Jam-2025/kaiju-response-team)：N64 homebrew，玩家开车在城市中修复怪兽造成的损害；重点参考“城市受损→抢救/修复→小地图提示”的循环。
- [doctor-g/KaijuHomecoming](https://github.com/doctor-g/KaijuHomecoming)：Unreal / Global Game Jam kaiju 项目；参考怪兽主题、城市玩具感比例和原型资产组织。
- [mattbucci/destruct-o](https://github.com/mattbucci/destruct-o)：体素破坏项目，参考破坏反馈、碎裂对象和破坏后状态保存思路。
- [RobDiggle/kaiju_battle](https://github.com/RobDiggle/kaiju_battle)：公开 Kaiju battle 仓库；后续若参考需先确认 LICENSE。
- [phoenixgoldz/KaijuUprising-UE5](https://github.com/phoenixgoldz/KaijuUprising-UE5)：UE5 Kaiju 题材公开仓库；适合看 Unreal 项目结构，后续若参考需先确认 LICENSE。
- [KaijuEngine/kaiju](https://github.com/KaijuEngine/kaiju)：不是巨兽游戏而是 Go/Vulkan 引擎，但命名和项目结构可作为 2D/3D 原型工程参考，不作为玩法标杆。

### 行星 / 球面 / 科幻空间参考

- [Zylann/solar_system_demo](https://github.com/Zylann/solar_system_demo)：Godot 4 + Voxel Tools 的 3D space game demo，含程序生成星球、可编辑体素地形、地表到太空飞行、菜单和音效；重点参考“从地表拉远到太空”的尺度感。
- [pioneerspacesim/pioneer](https://github.com/pioneerspacesim/pioneer)：GPLv3 太空冒险/交易/战斗模拟器，参考星系探索、登陆行星、飞船 HUD 和太空经济氛围。
- [marceld23/BlocksBeyondTheStars](https://github.com/marceld23/BlocksBeyondTheStars)：优先参考。Unity + .NET / AGPL-3.0 太空建造沙盒，参考程序恒星系、行星登陆、挖掘、基地/空间站和太空沙盒背景。
- [TheOpenSpaceProgram/osp-magnum](https://github.com/TheOpenSpaceProgram/osp-magnum)：MIT 航天器建造框架，参考飞行器、刚体物理、轨道、行星地形组件和 Kerbal-like 系统层级。
- [OoliteProject/oolite](https://github.com/OoliteProject/oolite)：Elite 风格开源太空交易/战斗游戏，参考科幻 HUD、飞船战斗、星系交易和扩展包结构。
- [vegastrike/Vega-Strike-Engine-Source](https://github.com/vegastrike/Vega-Strike-Engine-Source)：Vega Strike 太空飞行模拟引擎，参考探索、贸易、战斗、多星系、HUD、爆炸和动态宇宙系统。
- [cuberact/godot-cuberact-planet-chunked-lod](https://github.com/cuberact/godot-cuberact-planet-chunked-lod)：Godot 4.6 / GDScript 程序星球，动态 LOD、地形和大气；重点参考球面地图从远近距离切换细节。
- [athillion/ProceduralPlanetGodot](https://github.com/athillion/ProceduralPlanetGodot)：Godot 程序星球，参考球形星球生成和 Sebastian Lague 式星球构造。
- [Hoimar/Planet-Generator](https://github.com/Hoimar/Planet-Generator)：Godot procedural planet addon，参考噪声地形、LOD chunks 和可配置星球生成。
- [Stevepetoskey/TinyPixelPlanetsPublic](https://github.com/Stevepetoskey/TinyPixelPlanetsPublic)：Godot 2D space exploration sandbox，参考像素化星球、探索、建造和小屏幕宇宙 UI。
- [CaveJohnson376/godot-3dplanets](https://github.com/CaveJohnson376/godot-3dplanets)：Godot 3D spherical planet 实验，参考角色/相机在球面上的方向处理和方块放置。
- [Bauxitedev/stylized-planet-generator](https://github.com/Bauxitedev/stylized-planet-generator)：Godot 风格化程序星球，参考简洁、可读的星球临时美术。

### Brotato / Survivor Roguelike / 怪兽攻击碰撞参考

- [Roo-Roo-Roo/survivors-roguelike-kit](https://github.com/Roo-Roo-Roo/survivors-roguelike-kit)：最优先参考。Unity 2D survivors-like roguelike 模板；重点看 playable loop、角色/关卡选择、技能、敌人、buff、loot、程序化刷怪、进化武器和伤害飘字，用于后续怪兽攻击碰撞、自动行动演出和 roguelike 奖励梯度。
- [matthiasbroske/VampireSurvivorsClone](https://github.com/matthiasbroske/VampireSurvivorsClone)：参考武器冷却、自动发射、碰撞、伤害、掉落、宝箱和刷怪概率/速率 keyframe；适合借鉴“地图演出 + 自动攻击结算 + 升级选择”的完整节奏。
- [yagizkoryurek/Vampire_Survivors-clone](https://github.com/yagizkoryurek/Vampire_Survivors-clone)：Python/Pygame，代码短；重点参考最小化攻击结算、XP/升级、武器进化、Boss、宝箱、金币和 meta progression。
- [kairess/Vampire-Survivors-Python](https://github.com/kairess/Vampire-Survivors-Python)：Python/Pygame 原型；参考玩家移动、敌人追踪、碰撞、攻击判定和经验掉落的基础结构。
- [Quillraven/slime-survivor](https://github.com/Quillraven/slime-survivor)：Java/LibGDX 教程项目；重点参考 rectangle overlapping、vector-based movement、attack animations、player movement 和 audio，适合本项目简化怪兽命中/击退判定。
- [jody3t/brotato-clone](https://github.com/jody3t/brotato-clone)：Brotato-style arena survivor；参考 Brotato 式竞技场生存、控制器支持和网页端小型结构。
- [newbdez33/minecraft-survivors](https://github.com/newbdez33/minecraft-survivors)：Godot 4.5 + GDScript；参考自动攻击、XP/升级、附魔式升级、武器进化、昼夜刷怪修正、Boss 和测试脚本。主题素材/IP 不直接使用。
- [imitatehappiness/GDLastOfTheSurvivors](https://github.com/imitatehappiness/GDLastOfTheSurvivors)：Godot top-down survival；参考波次推进、击杀得经验、升级后选择新武器/被动物品或强化现有装备。
- [BLXCKBXXST/brotato-mini](https://github.com/BLXCKBXXST/brotato-mini)：Godot 4.4 / Brotato inspired；作为 Brotato 风格 Godot 入口，后续参考前先确认仓库内容和 LICENSE。
- [giovanneluna/poke-survivors](https://github.com/giovanneluna/poke-survivors)：Phaser 3 + TypeScript；参考 attacks/entities/systems/Collision/systems/Spawn/SpatialHashGrid 等系统分层。Fan-made 题材，不能使用素材/IP。
- [KeJunMao/emoji-survival-game](https://github.com/KeJunMao/emoji-survival-game)：Phaser 3 + TypeScript，中文 README；参考前端 survivors-like 的碰撞事件、NPC 和道具购买结构。
- [larkan28/monster-waves](https://github.com/larkan28/monster-waves)：Unity 小型 Vampire Survivors-like；适合看最小波次/生存实现。
- [BrotatoMods/Brotato-ContentLoader](https://github.com/BrotatoMods/Brotato-ContentLoader)、[otDan/Brotato-WeaponExplorer](https://github.com/otDan/Brotato-WeaponExplorer)、[BrotatoMods/Brotato-Attack-Speed-Calculator](https://github.com/BrotatoMods/Brotato-Attack-Speed-Calculator)：参考 Brotato mod 内容扩展、武器数据显示、冷却/攻速面板，不作为完整攻击结算源码。

太空辛迪加落地规则：

- 怪兽攻击演出按“自动索敌/动作选择 → hitbox 或路径碰撞 → 伤害/击退 → 地图特效 → GDP/区域损伤”的短链条设计。
- 怪兽技能、道具/卡牌和 roguelike 奖励要做梯度：I 级启动，II 级效率，III 级路线核心，IV 级终端但可被推理/反制。
- 地图演出优先做清楚的命中反馈：攻击范围、路径线、击退方向、伤害数字、区域裂纹/城市摇晃、短音效。
- 随机性要服务构筑：怪兽行动概率、区域牌池、商品池、奖励选择和 AI 路线都要能被玩家读出倾向，而不是纯随机噪声。

### Godot 性能管线 / 防卡顿 / 批量演出参考

- [Godot Background loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html)：官方后台加载。后续切换主菜单、进入局、加载星球/怪兽/大型 VFX 时优先用 `ResourceLoader.load_threaded_request()`，先查询状态和进度，再取资源，避免战斗中阻塞。
- [Reducing stutter from shader/pipeline compilations](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html)：官方 shader / pipeline 编译防卡顿。后续怪兽技能、城市破坏、天气和卡牌结算特效要在 loading/warmup 阶段预实例化或预热，避免首次出现时卡顿。
- [Godot Profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html)：用于定位卡顿到底来自脚本、物理、渲染、UI、粒子还是加载；每次大规模怪兽/特效/牌轨改动后应优先 profile 再优化。
- [General optimization](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html)：官方通用优化流程。后续高频单位、伤害数字、商品路径和区域状态更新要先看瓶颈，再做数据布局/预处理/线性访问优化。
- [Using MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)：大量同类视觉对象参考，例如城市碎片、海浪/运输线装饰、怪兽脚印、导弹残影和区域裂纹；需要按区域拆分，避免整体裁剪粒度太粗。
- [Optimization using Servers](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html)：当未来出现成千上万个投射物、特效、筹码或模拟单位时，参考 RenderingServer / PhysicsServer 低层批量控制，避免 SceneTree 节点过多。
- [Project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)、[Import process](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/import_process.html)：第三方插件放 `addons/`，项目文件夹保持清楚；提交 `.import` 元数据，不提交 `.godot/imported` 缓存；大型原始素材可用 `.gdignore` 隔离。
- [Godot demo projects threaded loading](https://github.com/godotengine/godot-demo-projects/blob/939ca55eaad4b3fa156a88289deef2e3e9479679/loading/load_threaded/load_threaded.gd)：官方 MIT 示例，作为异步加载最小实现参考。
- [Maaack/Godot-Scene-Loader](https://github.com/Maaack/Godot-Scene-Loader)：Godot 4 场景加载插件，参考 loading screen、进度条、错误处理和 autoload 式场景切换。
- [Maaack/Godot-Game-Template](https://github.com/Maaack/Godot-Game-Template)：参考正式项目的主菜单、暂停菜单、设置、scene loader、global state、关卡加载和发布脚本结构。
- [anasrar/godot-object-pooling](https://github.com/anasrar/godot-object-pooling)：Godot 4 对象池示例，后续怪兽 hitbox、伤害数字、爆炸、筹码飞行动画、掉落物和临时文字优先参考。
- [Minoqi/minos-damage-numbers-for-godot](https://github.com/Minoqi/minos-damage-numbers-for-godot)：Godot 4 伤害数字插件，含对象池；重点参考高频反馈 UI 的复用方式。
- [sempitern0/Fast-Pool](https://github.com/sempitern0/Fast-Pool)：轻量对象池参考；使用前先确认 Godot 版本和 LICENSE。

太空辛迪加落地规则：

- 新局流程逐步演进为 `Boot → Warmup/Loading → MainMenu → GameLoading → GameScene`；加载星球、卡牌美术、怪兽美术、天气/VFX 和音效时尽量提前异步加载。
- 所有高频临时对象优先池化：`MonsterHitbox`、`DamageNumber`、`CardFlyFX`、`ExplosionVFX`、`CityCrackFX`、`RouteSparkFX`、`ChipTransferFX`、`FloatingText`、`AudioOneShotPlayer`。
- 大量程序化生成时先设置属性再加入 SceneTree；怪兽、军队、城市碎片和商品运输线都要避免边 add_child 边反复改 transform/材质/脚本状态。
- 小型常驻数据和通用 UI 可 `preload`；大型场景、怪兽/VFX 包、星球地图包和音频包进入异步加载或 warmup。
- 每次加入大规模怪兽碰撞、城市破坏、伤害飘字、卡牌飞行动画或批量区域特效后，必须至少跑一次 Profiler / 有头测试，确认没有首次播放卡顿。

## 可直接落到本项目的 UI 原则

### 1. 主界面只保留桌面必需层

Terraforming Mars 的 `PlayerHome.vue` 把主区域拆成固定顺序：顶栏、主地图、玩家总览、日志、行动区、手牌、已打出卡牌。它不是把所有解释塞到主桌面，而是让“地图和当前行动”先出现，手牌/历史/规则按需展开。

太空辛迪加落地规则：

- 中央始终是星球赌桌。
- 底部是当前玩家资源筹码和手牌架。
- 右侧只放当前可执行行动和临时决策。
- 复杂规则进规则页、图鉴、经济总览、情报档案。

### 2. 顶栏可以折叠，状态用少量筹码表达

Terraforming Mars 的 `TopBar.vue` 支持折叠玩家信息，避免顶栏长期抢空间。太空辛迪加已经把数字倒计时改成沙漏条，下一步可以继续压缩顶栏：只显示当前桌面状态、天气预报、目标进度，细节进入 hover 或经济总览。

### 3. 卡牌区要像“可折叠牌架”，不是长报告

Terraforming Mars 把手牌、已打出牌、事件牌分组并可隐藏；这适合太空辛迪加后续处理：

- 手牌默认显示小卡面和关键筹码。
- 悬停看详情预览。
- 双击打开详情或执行主要动作。
- 已打出匿名牌轨默认很薄，只在 hover/双击时展开。

### 4. 星图/地图适合图标化叠层

Gaia Project 的 `SpaceMap.vue` 用 SVG 图层叠加星区、阵营盘、图例和高亮。太空辛迪加的球形星球可以继续采用同样思路：

- 地形、商品、城市、怪兽、商路、天气都作为可开关图层。
- 默认只显示地形、城市、怪兽和当前选区。
- 商品/商路/情报/天气作为地图模式按钮切换。
- 图例放成小筹码，不写长句。

### 5. 临时美术要强化“赌桌 + 科幻怪兽”记忆点

Night Patrol 的价值不是直接照搬题材，而是它的卡框、按钮、音效和敌人轮廓区分度。太空辛迪加应沿用这种原则：

- 每类卡有不同框色和图标语言。
- 怪兽卡要有明显轮廓差异：飞行、水栖、陆行、装甲、资源吸取等。
- 全场动画要有赌桌感：下注、亮牌、翻牌、沙漏、筹码移动。
- 音效先服务反馈：出牌、竞价、怪兽碰撞、建城、收入、下注结算。

### 6. Slay the Spire 型 deckbuilder 参考“手感”，不照搬回合结构

GitHub `topics/slaythespire` 下的资源说明这一类游戏最强的不是长规则文本，而是三件事：卡牌一眼能读、路线构筑很快能成型、每次获得新牌都像一次小赌局。太空辛迪加是实时桌游，不应照搬“每回合抽弃”，但可以吸收这些 UI/流程经验：

- 手牌默认像牌架：小卡面 + 费用/类型/等级/一句效果，hover 才展开完整说明。
- 获得卡牌窗口像奖励/商店选择：先展示卡面差异，再显示价格、区域来源、是否可升级。
- 卡牌详情页把“关键词解释”和“开发规则”收纳起来，只保留玩家决策需要的字段。
- 构筑路线要在图鉴和商店中可见：经济、商品、金融、怪兽、军队、情报、合约、玩家互动。
- 每张牌需要有明确角色：启动牌、增幅牌、防御牌、爆发牌、反制牌、线索牌，避免大量“只是加数字”的牌。
- 结算反馈要短而鲜明：亮牌、目标、高亮受影响区域、筹码变化、GDP 变化，减少长段日志。

### 7. 卡牌手感要进入“动态牌桌”，不是静态按钮

UiCard / Balatro / Hearthstone / MTG Arena 这一组参考的共同点：卡牌不是普通按钮，而是有位置、层级、拖拽、悬停、放大、可投放区域和结算反馈的“物件”。太空辛迪加后续落地规则：

- 手牌要逐步从静态横排变成轻微弧形牌架，鼠标经过时抬起并放大。
- 区域牌架、弃牌选择、目标选择、怪兽赌局都复用同一套“卡牌物件 + 决策槽”交互；条件式订单只显示自动检查与结算结果。
- 打出卡牌时应该有从手牌到全桌结算轨道的飞行动画，再进入五秒公开亮牌窗口。
- 弃牌区、已打出匿名牌轨、目标区域高亮要形成一条连续的视觉路径。
- 每张卡只在卡面展示最短决策信息；完整规则由 hover / 双击详情承接。

### 8. 巨兽和星球要成为主视觉，而不是规则文本背景

巨兽破坏参考强调“城市正在承受压力”的视觉反馈，行星参考强调“星球是一个真实空间”。太空辛迪加后续落地规则：

- 怪兽移动、击退、城市损害、修复、军队防守都要有地图动画和临时图标，不只写日志。
- 区域 HP、城市 GDP、商路损伤、仓库囤货要在地图上变成小筹码/裂纹/烟雾/运输线变化。
- 地图拉远时保持星球中心感，局部贴近时再展开区域牌板和城市细节。
- 星球气候、海陆地形、商品生态和怪兽偏好要在视觉上彼此呼应。

## 下一批可执行 UI 改动

1. 把右侧行动托盘进一步改成“当前行动槽”：同一时间只突出一个主按钮，其它模块折叠成小筹码。
2. 把匿名牌轨 hover 预览再缩小，默认只像 Through the Ages 市场轨道一样显示小卡槽。
3. 给地图加图层按钮：商品、商路、情报、天气、怪兽。
4. 给卡牌图鉴详情页继续减少常驻文字，把 I-IV 梯度改成更像 TCG 的图标阶梯。
5. 设计统一临时决策面板底座，用于弃牌、怪兽赌局、相位否决、玩家或怪兽目标选择；条件式订单不创建回应面板。
6. 继续把购牌窗口推向 deckbuilder 商店/奖励式布局：区域牌池缩略卡网格、可买/仅看/需弃牌分层、升级预览、弃牌选择同一套卡面。
7. 参考 UiCard 做手牌 hover 抬起、拖拽预备、卡牌飞向结算轨道的第一版动效。
8. 参考 Kaiju Response Team / DisasterCity，把城市受损、修复和怪兽接近做成更明显的地图筹码动画。

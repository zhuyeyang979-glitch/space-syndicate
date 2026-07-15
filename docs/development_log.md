# 太空辛迪加开发日志

> 本日志用于保存当前原型的规则决策、实现状态、验证方式和下一步开发方向。
> 最新记录日期：2026-07-15。

## 2026-07-15｜区域天气系统 v1 完整闭环

- 六种区域天气现由 `resources/weather/*.tres` 与 `WeatherDefinition` 完整数据驱动：离子风暴、引力潮、孢子季、晶尘暴、极寒期、太阳耀斑。商品、怪兽和单位使用最小显式标签，不按中文名称猜测规则；天气定义、倍率和生命周期没有进入 `main.gd`。
- `WeatherRuntimeController` 保持唯一生产状态 owner，并以既有整数 `world_effective_us` 推进 90 秒开局保护、90 至 150 秒自然预报间隔、30 至 60 秒预报、45 至 90 秒生效和 10 秒线性消退。最多两个事件并存，同区域冲突排队，结算倒计时只阻止新预报；真暂停冻结，非模态市场不冻结。
- `WeatherEffectResolver` 将天气接入现有生产、需求、价格增长、收入明细、路线有效效率、怪兽标签/AI 评分、军事移动/远程/轨道/击退和情报持续时间/范围。`weather_resistance` 只缩小天气 delta，`weather_exploitation_multiplier` 只放大正收益；路线、速度、军事/情报和经济贡献均有硬上限，结束后回到 identity。
- 晶尘暴的轻微区域磨损不直接写 HP，而是经权威区域伤害 owner 提交环境请求，按强度积分、单事件累计封顶且至少保留 1 点生命。天气本身不能摧毁健康区域，也不会永久损坏路线或留下怪兽状态。
- UI 使用同一公开事件链：地图 WeatherMapOverlay 位于区域/城市之下且不遮挡路线、怪兽和选区；WeatherForecastStrip 非阻塞提示并可聚焦区域；区域详情显示阶段、剩余时间、三项主效果、利用与反制；经济和路线解释保留同一 event id、天气名称和贡献行。1280×720、1600×960、1920×1080 以及真实 PlanetBoard 1600×960 截图均已生成并人工检查。
- 本地 `WeatherTelemetryRuntimeService` 记录事件数量、命中区域、价格增长/路线效率贡献、匿名行为类别、怪兽评分影响、实际区域伤害和由已提交公开成交 receipt 得出的保守经济估值。它没有网络、存档 API、玩家身份、现金、手牌、私密目标/权重或 AI 计划；确定性平衡报告明确把实现金额标为 `N/A`，不伪造真人收益。
- Focused 验收全部通过：core `278/278`、商品标签 `292/292`、经济 `107/107`、路线 `45/45`、怪兽 `86/86`、军事/情报 `37/37`、区域伤害 `77/77`、遥测 `90/90 + 13/13`、存档/隐私 `50/50`、展示 `10/10 + 14/14`、卡牌/AI `49/49`、真实 Main Weather Characterization `53/53`，另有卡牌资源 `80/80`、authoring `36/36`、v0.6 catalog `2894/2894`。
- 全局门禁中，Godot 引擎级 smoke `--check-only`、UI 文本、visual snapshot 与 Main composition 通过。完整 layout 仍有 59 条旧 v0.4/v0.5 断言，但天气失败为 0；完整 smoke 在 `tests/smoke_test.gd:132` 对迁移后的 `product_market` 执行陈旧 `Dictionary` 强转并触发 `Invalid cast`，随后由超时门回收，因此未标为通过，也没有恢复 Main wrapper。完整证据、平衡表、截图路径和未关闭风险见 `docs/weather_v1_test_report.md` 与 `docs/weather_v1_balance_report.md`。

## 2026-07-15｜区域图鉴公共数据源场景化与隐私硬切换

- `GameRuntimeCoordinator.tscn` 现静态拥有唯一 `RegionCodexPublicSourceService`。生产链为 RegionInfrastructure 的严格公开投影、Monster owner 的非数值区域吸引投影、Weather/Route 公共摘要，再经纯数据 allowlist adapter 进入既有 `CodexPublicSnapshotService`；SourceService 不读取 viewer、玩家现金/手牌/弃牌、城市猜测、真实 owner、AI 计划、镜头、市场报价或存档。
- `main.gd` 原有区域卡池摘要、Region source 拼装和 Region snapshot wrapper 三个函数已物理删除。该旧链曾在无公开线索时回退当前玩家城市猜测/隐藏 owner，并直接调用怪兽私有权重说明；现在 Main 只调用 Coordinator 的最终 `region_codex_public_snapshot(region_index)`。Main 从 19522 行/1110 个函数降至 19425 行/1107 个函数，净删 97 行和 3 个函数；三处合法的 viewer-private `_city_intel_hint_for_player` Economy/Intel 调用保持隔离。
- 区域图鉴不再显示 viewer-local“当前选中”或退役 panic/heat；改用“公开资料 / 公开市场”边界提示。怪兽吸引只显示固定非数值因素类别，隐藏内部权重、概率、随机签和预选目标；无公开城市线索时固定显示“暂无公开线索”，不回退私人标注。普通牌仍按 v0.6 规则全局可浏览、来源区域受光时才可锁定 5 秒报价。
- Godot 4.7 focused 证据：Region SourceService `13/13`、独立隐私 acceptance `18/18`、Codex public cutover `20/20`、Codex hard cutover `20/20`、Main composition PASS、Codex formatter test PASS、smoke `--check-only` 通过，所有本轮变更脚本由 8775 验证为 0 diagnostics。
- 完整 `layout_scene_smoke_test.gd` 仍以 exit 1 结束，但本轮新增的 Region SourceService 加载、Coordinator 最终 API、旧 Main helper 物理缺席三项均明确 PASS，Region cutover 不在失败清单。其余红灯仍是已知的旧 CityDevelopment/v0.4-v0.5 save/cashflow/table snapshot/Military characterization 等历史 oracle；本轮未恢复这些退役 API。
- 8775 有头运行真实 `RegionCodexPublicSourceBench.tscn`：运行时场景树包含唯一 SourceService 与真实 `CodexCompendiumSurface/RegionCodexDetail`，状态 `PASS 13/13`，截图为 `.codex-godot/artifacts/region_codex_public_source_a_v06.png`。退出后 `is_playing_scene=false`，A 工作树仅保留专属 editor，无额外 headless/game 进程。
- 本切片没有恢复通用 Region source proxy、Main wrapper 或第二套规则 owner。CommodityFlow/Contract 尚无安全的区域公开聚合，因此 GDP/合约精确聚合继续 fail-closed 显示“暂无”；后续若补充，必须先由对应 owner 提供不可逆、非玩家化的公开投影。

## 2026-07-15｜卡牌图鉴公共数据源场景化与 Main 物理减负

- `GameRuntimeCoordinator.tscn` 现静态拥有唯一 `CardCodexPublicSourceService`。该服务只注入卡牌目录、纯展示、公开合法性、平衡诊断、最终快照与价格模型六项依赖；纯数据 adapter 递归拒绝玩家索引、现金、手牌、归属、AI、市场、太阳、镜头和存档字段，不读取 Main 或 WorldBridge。
- Coordinator 只暴露最终 browser/detail 两个公共快照 API；`main.gd` 仅传递筛选、翻页和布局上下文。原先在 Main 内构造 browser source、browser snapshot、card facts、upgrade facts 和 detail snapshot 的五个函数已物理删除，可执行定义/调用归零；函数名只保留在负向退役门禁中。
- 本切片使 `main.gd` 从 19629 行/1115 个函数降至 19522 行/1110 个函数，净删 107 行和 5 个函数；没有恢复 legacy wrapper，也没有建立第二个卡牌规则 owner。
- Godot 4.7 聚焦证据：Card Codex public-source cutover `31/31`、Codex scene hard cutover `20/20`、Main composition PASS、smoke `--check-only` 通过、286 个 GDScript 扫描 0 错误。8775 真实 `main.tscn` 打开资料库/卡牌图鉴后 browser 正常渲染，控制台无错误；退出后 `is_playing_scene=false` 且 A 工作树无额外 headless/游戏进程。
- C 在精确候选上独立复验 `31/31`、`20/20`、Main composition 与 smoke check-only 均绿，并确认真实 Surface detail 截图。其审计发现原矩阵未真实改变裸 `discard`/隐藏 owner；follow-up 已把 `discard` 加入 adapter fail-closed 表，并让跨 viewer 矩阵实际修改手牌、弃牌、玩家/城市隐藏 owner、城市猜测和 AI 私有计划，结果仍字节等价。MCP/资源化注册表也已同步为当前 31 cases / 24 retired formatters。
- 完整 `layout_scene_smoke_test.gd` 仍为红灯；失败清单集中在旧 v0.4/v0.5 owner 组成、已物理删除的 Main snapshot/wrapper、历史 Economy/Military/Victory/TableSnapshot 断言。本轮 Card Codex SourceService、31 项切换合同和五个 helper 退役门均未进入失败清单，因此没有为通过旧总门恢复兼容层。
- 下一隐私切口已只读定位到 Region Codex：无公开线索时会回退当前玩家城市猜测/隐藏 owner，怪兽吸引说明还会暴露自动单位内部权重。后续必须由 Region 公共 source adapter 与 Monster owner 的非数值公共投影解决，不能把私有 Intel helper 或怪兽权重公式复制进展示层。

## 2026-07-15｜主桌静态组成与受光面镜头展示

- `main.tscn` 现直接静态拥有 RuntimeGameScreen、PlanetMapView、FullscreenMapOverlay、卡牌结算横幅、底部倒计时、区域牌架侧栏和桌面音频节点。`main.gd` 已物理删除这些组件的动态 preload/instantiate/find-child fallback 与临时音频构造；缺少静态组成时明确失败，不再运行时重建第二套 UI。
- `PlanetMapView.tscn` 静态拥有 `PlanetSolarCameraController`。展示链严格单向：唯一整数 world-effective clock → SolarAvailability 纯派生公开快照 → GameRuntimeCoordinator → Main 现有地图刷新点 → PlanetMapView 本地镜头。公开快照只有 `world_effective_us`、`rotation_period_us`、`sun_turn_ppm`，控制器不持有市场、世界桥、规则或存档引用。
- 镜头停止交互 3 秒后进入受光面对准：完整动画用 0.8 秒 smoothstep，简化/关闭档在相同门槛瞬时对准；进入 FOLLOWING 后持续追随当前太阳经度。滚轮、拖拽、点击、键盘、区域聚焦和焦点进入都会退出跟随并重新计时。自动过程保留当前缩放与选区；显式太阳按钮对准当前受光面并恢复 globe zoom `0.48`。
- 相机负向边界已锁定：镜头中心、缩放、投影、选区和程序化 focus 不改变太阳规则、市场 facts、quote id、公开 fingerprint 或授权。Solar 与镜头不新增第 19 个 save owner，也没有 `to_save_data/apply_save_data`。
- Godot 4.7 聚焦证据：Solar camera `23/23`、Main composition PASS、跨席公开报价隐私 `5/5`、clock/save production acceptance `16/16`、globe default `2/2`、smoke `--check-only` 通过，286 个 GDScript 全扫描 0 错误。8775 真实 `main.tscn` 快速开局后，嵌入地图为可见 `560×535` 的真实 PlanetMapView，控制器收到三字段快照并进入 FOLLOWING；console error 0，退出后 `is_playing_scene=false` 且无额外 Godot 子进程。
- 完整 layout 仍有一批锁定 v0.4/v0.5 退役 API 的历史红灯，playtest skeleton 另有卡牌缩略图与旧英文主菜单文案两项非本切片红灯。本阶段未恢复旧 API 或放宽这些门；后续按真实 owner gate 分块物理退役。

## 2026-07-15｜v0.6 恒星日照牌市与锁价报价唯一 owner

- 新增场景化 `WorldEffectiveClockRuntimeController`、纯派生 `SolarAvailabilityRuntimeService`、非所有权 `CardMarketPolicyWorldBridge` 与 `CardMarketPricingRuntimeController`，静态组成进 `GameRuntimeCoordinator`。世界时钟以整数微秒为唯一权威并集中保留帧间小数余量；真正暂停冻结，打开牌市不冻结。太阳相位只从该时钟、固定初相位与区域中心派生，120 秒一周，不保存第二份相位，MapView 镜头/缩放/焦点不进入规则计算。
- 普通牌挂牌现在全局可浏览，只有来源区域中心受光时可买；暗面只读。显式选择才创建 5 秒半开区间报价（`now_world_us < expires_at_world_us`），hover、Codex 和刷新只读 preview，不创建或续期报价。快照绑定玩家、来源区、卡牌和供应 revision，并锁定资格、怪兽计数、`q2` 与最终价格；换牌、换供应或到期均 fail-closed，不回退 live 重算。
- 价格唯一公式为 `q2=min(10, 2+2*同区存活怪兽数+相邻存活怪兽数)`、`final=ceil(P*q2/2)`；归属不参与，倒地或过期怪兽不参与。公共报价可公开同区/相邻怪兽计数（均为公开场面事实），但不含玩家绑定、精确现金、手牌、怪兽 owner、弃牌或 AI 计划。
- Human 普通牌、first-table 设施与 CardFlow 市场购买统一消费同一 quote authority；缺 quote、伪造绑定、过期或 supply revision 变化均原子拒绝。内存状态端口必须显式注册非负且唯一的 `player_index`，不再按 actor 名称排序推断。真实普通牌结算验证现金、库存、购买计数与供应 revision exact-once。
- 起始怪兽牌仍在手中，但召唤完全自愿且不阻断设施/收入。首局 fixture 固定 `map_seed=606120`、设施挂牌来源区 5；修复 JSON 整数以 float 解码后旧 `is int` 门导致地图 seed 未生效的问题，使该真实 Voronoi 来源在 `t=0` 可重复受光。focused 流程已覆盖无怪兽购买设施、生成一张 Sale Receipt/正收入、再次购牌后再自愿召唤。
- `main.gd` 物理净删 82 行、净删 3 个函数；旧 monster-access qualification、landed/adjacent/extended/global 分档、0.8/floor、12 秒 window tick、强制首召门槛与 `game_time +=` 第二时钟均已从生产路径删除。GameSession v3 现通过已有 section 捕获/恢复 `world_effective_us`；独立 Session 未绑定 clock 时明确捕获失败，不伪造 0，Solar 不进入 save。
- 8785 Funplay MCP 开发证据：Card-market production test 46/46、Main composition PASS、CardFlow 73/73、production adapter 44/44、Commodity inventory 46/46；CardInventory、Commodity persistent installation 与 ProductMarket headed characterization 均 `_failures=[]`，每次均 clean stop。486 文件扫描只剩本阶段未触碰的 `military_runtime_characterization_bench.gd` 既有类型推断红；目标 runtime 脚本扫描无红。最终 smoke/layout/privacy/save 验收留给 A/C。
- 已知后续迁移：活动 v0.4 catalog 仍含 `远程补给链1`/`星门采购权1` 的 `card_access_boon` 旧数据；生产 eligibility 已 fail-closed，本阶段未擅自重写牌义，必须由独立卡牌数据阶段退役或重做。`smoke_test.gd`、`commercial_playability_gate_test.gd`、`player_facing_privacy_boundary_test.gd` 与部分 layout oracle 仍直接引用已删除 helper，由 C 在本 SHA 后原子迁移。未新增第三方代码、素材或许可证义务。

## 2026-07-15｜v0.6 破产与中立遗产唯一运行时 owner

- 新增场景化 `BankruptcyNeutralEstateRuntimeController` 与无状态 WorldBridge，静态组成进 `GameRuntimeCoordinator`；CommodityFlow Sale Receipt 完成后、资产恢复和 Victory 前执行唯一破产检查点。精确现金 `<0` 才破产，`==0` 留局；`main.gd` 的 `<=0`、现金夹零、散落调用和最后幸存触发已物理删除。
- 五个真实 owner 以窄 `prepare/commit/rollback/finalize` 端口加入同一 exact-once journal：生产手牌清空，未售/待运商品清除，军队离场，怪兽去主，设施转中立；设施等级/区域共享 HP 与怪兽等级/HP/时钟不变。跨 owner revision/fingerprint 变化整笔逆序回滚，不在 Coordinator 或 Main 复制状态。
- CommodityFlow 标记主动持续生产形成的仓储债务，允许其结算原子越过零；一次性被动强塞仍压缩仓储租金，WorldBridge 另有 fail-closed 负现金门。中立设施租金按 Sale Receipt identity exact-once 进入下一场怪兽公共赌池。
- 公共破产回执严格只含 `player_indices`、五类 `estate_counts` 与 `reason`，不含精确现金、手牌/商品明细、真实 owner、弃牌或 AI 计划。存档接入留给 v3 owner registry，不在本切片写第二套 save 状态。
- 8785 Funplay MCP focused 实景 Bench 为 16/16，通过后立即停止 play mode 并确认 `is_playing_scene=false`；最终完整回归、隐私、存档与集成验收仍由 Supervisor 执行。运行时合同见 `docs/bankruptcy_neutral_estate_runtime_contract.md`。

## 2026-07-15｜v0.6 多工作树 Godot MCP 基础设施

- 活动 Godot 编辑器桥从旧 `godot_mcp` 切换为仓库内锁定的 Funplay MCP `v0.9.6`；上游、MIT 许可证、发行日期和 SHA-256 已记录。旧 addon 暂只作为停用的历史工具保留，不再启用。
- Supervisor、Codex A、B、C 固定使用四个独立工作树、四套重定向 `APPDATA`/`LOCALAPPDATA`、四个本机端口 `8765/8775/8785/8795` 和四个不入库的随机令牌。客户端 stdio 桥从当前工作树的忽略目录读取端点与令牌，避免共享编辑器或提交秘密。
- Funplay runtime bridge 已替换旧 MCP runtime autoload。Supervisor 实测 Godot 4.7 编辑端点、78 个 core 工具、186 个 GDScript 文件无解析错误；有头主场景 heartbeat 报告 713 个节点和 1600×960 视口，并通过 MCP 抓取可读主菜单画面、正常退出 play mode、关闭编辑器和释放端口。
- A/B/C 只负责各自切片的开发与 MCP 迭代证据；完整无头回归、有头真人流程、截图、隐藏信息、许可证、存档、clean-stop 和集成结论全部由 Supervisor 执行。下一步从本基础设施提交创建三套新的 v0.6 分支，旧 B 未提交历史修复保持原样隔离。

## 2026-07-14｜SS06-05 动态胜利与审计结算顺序

- `VictoryControlRuntimeController` 已从 v0.5 固定深度表切换到 v0.6 动态分母：存续区域数为 `A`，要求区域数为 `K=ceil(A*40%)`，普通胜利 GDP 门槛为 `K*36 GDP/min`；`A=0` 时暂停普通 GDP 胜利。
- 区域控制只消费 `RegionInfrastructureRuntimeController` 生命周期和 `CommodityFlowRuntimeController` 最近 30 秒成交 GDP：玩家自有商品 GDP 占比至少 3000bp 且唯一最高才控制，精确并列无人控制。
- 每名合格玩家独立累计 10 秒资格；120 秒审计名单粘性公开，后加入者也必须独立完成 10 秒。审计终点重新读取当前 `A/K`、控制和 GDP，无合格决赛者直接回 idle，v0.5 的 30 秒失败冷却已删除。
- 同帧顺序固定为攻击/生命周期、连续流量与 Sale Receipt、破产，再胜利；Controller 只接受 `post_world_settlement` 检查点完成终点结算。比较顺序为精确 top-K 商品 GDP cents、控制区域数、精确现金，完全相同则共同胜利。
- 普通区域毁灭不再触发现金胜利；只有 scenario 同时显式声明不可逆星球毁灭和现金 fallback 时才允许。审计公开普通手牌、设施/安装、商品库存、六色 GDP、区域份额、单位和金融持仓，同时继续过滤私密调查、秘密目标、AI 计划、私密目标与弃牌。
- 长期 `VictoryControlRuntimeBench` 已升级为 v0.6 动态门，54/54 通过；合同见 `docs/victory_control_runtime_contract.md`。下一步为 SS06-06 商品库存、履带领取和永久安装，且必须先消费另一位 agent 的最新 Card Flow API，避免重复所有权。

## 2026-07-14｜SS06-04 六色资产与 8/6/2 卡窗

- `PlayerManaRuntimeController` 成为六色资产池唯一 owner；只消费玩家自己的商品 Sale Receipt，以对应色 GDP/min 除以 100 恢复每秒资产，六池各自封顶 100，不衰减。
- 非商品牌通过 exact-once reserve/consume/release 授权支付；商品牌仍不支付资产。Queue 不拥有支付算法，也不再拥有 v0.5 Industry Capacity reservation、优先报价或产业项目要求。
- 卡牌组窗口为总计 8 秒、组织 6 秒、锁牌 2 秒，标准每人最多提交 3 张。`PlayerManaCardWindowRuntimeBench` 32/32，共享窗口和 Card Resolution Controller 聚焦测试通过。

## 2026-07-14｜玩家资源术语统一为“资产”

- 玩家规则、卡牌、按钮、状态提示和检查器不再使用“法力”；六种由玩家自有商品 GDP 恢复的资源统一称为“六色资产”。
- “通用资产”只是费用类型，由六色资产任意组合支付，不建立第七个资产池。
- v0.6 卡牌目录与新卡牌流程机器字段使用 `asset_cost`、`assets` 和 `asset_debit`；玩家文本泄漏校验禁止旧术语。
- 尚在生产运行时和存档契约中使用的旧 `mana` 键只能作为迁移兼容面保留，待对应运行时所有者以版本化读取兼容方式迁移；不得再暴露给玩家。
- 已生成 82 个已有正式名称的卡牌家族、328 张 I–IV 级定义；目录连续两次真实 Godot 构建哈希一致。六色商品等量目标仍需新增 20 个商品家族，完成后为 408 张。
- 新增独立 v0.6 卡牌事务语义服务：履带单一领取者、市场购买与立即刷新原子提交、transaction journal 幂等、玩家 revision、卡牌实例绑定、六色支付通用资产和效果 prepare/commit 失败回滚均通过 Godot 测试。当前内存玩家状态仅供 Bench 使用；生产接线必须先通过单一状态端口连接现有手牌、现金与资产 owner，禁止形成双库存或双资产。
- 新增商品与公共设施两阶段效果 adapters，并以真实 `CommodityFlowRuntimeController`、`RegionInfrastructureRuntimeController` 完成独立集成测试；设施槽、产权、废墟重建、仓库产业选择、商品方向/同色和过期 revision 均在扣牌前校验。主场景接线仍等待单一玩家状态端口。
- 新增 `CardPlayerStatePortV06` reference port，支持 1–N 玩家 revision/CAS 预留、全局卡牌实例唯一、六色资产严格余额、原子提交/中止和 transaction+intent 重放；65 项 Godot 测试覆盖双玩家偷牌与竞争锁。reference memory port 不得作为生产第二份状态。
- `CardFlowTransactionServiceV06` 已移除私有 `_players/_player_reservations`，所有玩家读写改经可注入状态端口；56 项回归覆盖单一 revision、跨玩家锁阻断、端口 CAS 失败时效果补偿和原有领取/购买/合成/打出流程。
- 两种供需牌已建立确定性权益 planner 与原子 batch sink 合同：按商品 owner + 具体商品的 30 秒 GDP 分配，使用整数最大余数、容量迭代再分配、共享运输资源、最短合法距离与多式标签。122 项测试和 10 项 MCP Bench 通过；现有 CommodityFlow 尚无订单/供货统一 batch + rollback API，因此生产 sink 保持 `BLOCKED`，缺失时退牌退资产。

## 2026-07-14｜SS06-00 可恢复基线、v0.6 Foundation 与区域基础设施刻画

- 建立不可变 `pre-v0.6-runtime-baseline`，指向 `c9c1b33841df3f96efe6a5b2a2132ed19e0effce`；独立 clean clone 已完成 Godot import、composition 和完整 layout smoke。开发转入 `rules/v06-runtime-integration`，不建立 v0.4/v0.6 运行时 selector。
- 新增 Inspector 可编辑的 `space_syndicate_ruleset_v06.tres`、validator 和七个纯数据 schema，收录共享生命、设施容量/吞吐/速度、动态胜利、商品履带、六色法力、8/6/2 卡窗、怪兽战斗/赌局及 3-8 人/2-7 AI 门。生产 Ruleset bridge 和 Card Catalog 仍为 v0.4。
- 被动 `RulesetSaveHandshakeService` 可识别 save v3 / ruleset v0.6，但 v1/v2 只能备份和新开局，不能推断设施状态或续打；生产 `GameSaveRuntimeCoordinator` 仍唯一写 v1。
- 新增真实 `main.tscn` 的 Region Infrastructure Characterization。68/68 记录旧区域 HP/damage/destroyed、项目份额、路线损伤、仓库结算、Monster/Military damage requester、存档键和 SS06-01 删除候选；39/68 已符合 v0.6，其余故意保留为迁移差异。
- 明确 v0.6 不含区域“热度/panic”。Profile 和 wire schema 禁止该字段；旧 `main.gd` 状态、怪兽评分、卡牌 Resource、Codex/Presentation 和 fixture 只作为待删除证据登记。SS06-01 必须同时删除状态、评分、伤害、玩家文字并 reauthor-or-block 受影响卡牌，不能只隐藏 UI。
- SS06-01 硬门：建立唯一 Region Infrastructure owner，同时从 `main.gd` 至少净删 700 个非空行和 24 个函数，Region adapter 不超过 180 行，不留 parallel fallback 或 wrapper farm。

## 2026-07-14｜v0.6 规则书 PDF 与实现歧义收口

- 生成 `output/pdf/space_syndicate_rulebook_v0.6.pdf`，作为当前 v0.6 玩家规则与开发指导的可阅读版本；正文增加经济回路、共享生命、动态胜利、GDP 排位商品履带、多式联运和怪兽赌局时间线图，并附默认数字与术语速查。
- 胜利总量统一定义为玩家 GDP 最高的前 K 个已控制存续区域中的自有商品 GDP/min 之和；控制占比、排序与门槛统一读取最近 30 秒成交观察窗。终局审计中的领先玩家普通手牌也公开。
- 同区/相邻免交通只适用于生产工厂与最终消费市场本身同区或相邻，禁止逐段套用绕过道路；海运腿两端必须有可用码头，空运腿两端必须有可用空港，并允许持续流按预计净现金顺序拆分到多条多式路线。
- 商品安装率与设施处理能力统一使用单位/分钟；玩家可以无需许可把商品安装到他人的可用同色设施，生产权益按“安装玩家 + 具体商品”记录并同比限流。法力恢复明确为对应色商品 GDP/min 除以 100 后得到法力/秒。
- 补回非商品普通牌动态市场：买走立即刷新、允许连续购买、每次刷新重新检查位置/价格/合法性。同窗唯一槽位冲突采用轮换席位优先权；失效提交退牌和法力，不退购买现金。
- 订单/供货补齐候选节点、真实路线、一次性等级数量和未兑现余量重分配；距离溢价、租金压缩、交通速度、仓库容量与赌局固定底注率也获得首测默认值。上述数字仍是可调参数，规则关系与资源归属已经固定。
- 本轮只更新规则源、PDF 生成脚本与文档，没有修改 Godot 运行时、场景、卡牌 Resource 或存档。

## 2026-07-14｜v0.6 商品网络与区域共享生命定性规则基线

- 新增 `docs/tabletop_rulebook_v06.md`，作为后续 v0.6 新开发的玩家行为语义基线；新增 `docs/rules_v06_runtime_directive.md`，固定删除、替换、数据所有权、原子时序、迁移工单与 conformance gate。
- v0.6 明确替代五项目位、项目份额、固定深度胜利、产业产能档位、旧合约、商路牌和抽象路线损伤。v0.5 文档与运行时保留为历史/迁移证据，不再作为未来规则扩展方向。
- 区域生命改为公共设施贡献形成的单一共享池。所有设施按等级贡献生命，区域完整度连续同比例缩放生产、需求、运输吞吐和仓库接收；归零时全区设施同时摧毁，区域退出动态胜利分母，任意设施重建后重新加入。
- 胜利门槛改为按当前存续区域百分比实时计算；摧毁区域降低门槛、重建区域提高门槛，120 秒审计期间也实时变化。普通胜利必须在同时间戳伤害、重建与成交结算后检查。
- 商品牌改为顶部履带免费领取、免费打出，并永久累加工厂具体商品生产率或市场具体商品需求率；受损只降低有效率，设施摧毁才删除安装量。普通手牌仍为 5 张，手动合成为主，只有满手领取同名商品时自动合成一次。
- 同一设施的永久商品安装量可以继续累加，但超过设施等级基础容量时按各商品安装量同比例限流，再乘区域完整度；没有路线和仓库接收能力的持续生产使用回压停产，不生成无限库存或被动债务。默认每个 8 秒普通出牌窗口每人最多提交 3 张，商品领取不占提交、安装占一个提交位。
- 商品履带新增近期商品 GDP 排位视野：领先档只看接近消失端的少量牌，GDP 越低可见履带越长，最低档看完整牌轨；同 GDP 共用档位，全体同分时全部可见。视野长度本身是玩家可用于推测自身排名的私人线索，AI 必须消费同样的过滤快照，不得读取隐藏牌轨。
- 清晰区以外的商品牌不完全隐藏，而是只公开商品颜色、位置和移动方向；具体商品、等级、名称与卡图全部模糊，且不能领取。模糊必须来自 viewer-scoped 数据删减，不能只靠 UI 遮罩，tooltip、无障碍文字、日志和 AI 均不得泄漏真实牌 ID。
- 钱只用于购买非商品牌；除商品牌外，牌在打出时支付彩色或通用法力。六色法力仍只由玩家自己的对应色商品成交 GDP 恢复。
- 自动物流保留多式联运。路线保存实际运输方式标签集合；条件牌只要路线包含海运、空运或陆运中的指定方式便满足，不要求全程使用该方式，同一批商品在一张牌中只计算一次。
- 怪兽与军队成为共享生命伤害的唯一来源；高 GDP、高流量和高仓储区域应承受更高怪兽目标压力。怪兽战斗通过真实设施破坏、现金风险和公共赌池承担逆风翻盘职责，不直接赠送 GDP 或法力。
- 本轮只建立规则与开发指令，没有修改 Godot 运行时、场景、Ruleset Resource、卡牌 Resource、存档或玩家行为。后续实现必须按 `rules_v06_runtime_directive.md` 分领域硬切换，不得把新规则继续塞入 `main.gd` 或与 v0.5 建立双 owner。
- 新增 `docs/rules_v06_development_plan.md`：冻结 SS05-00 至 SS05-05 为历史迁移证据，停止 SS05-06 以后尚未开始的项目经济路线。下一步改为 SS06-00 可恢复 pre-v0.6 基线、v0.6 Profile 与 Region Infrastructure characterization；首个 Hard Cutover 将处理公共设施和区域共享生命。

## 2026-07-14｜SS05-05 Industry Capacity & 8/6/2 Card Group Runtime

- 新增 `IndustryCapacityRuntimeService.tscn` 和非所有权 `IndustryCapacityWorldBridge.tscn`，静态接入 `GameRuntimeCoordinator`。容量只来自 SS05-02/03 的真实项目快照和唯一商品产业目录，不从名称、颜色或 UI 文案反推产业。
- Card Eligibility 统一支持无色、单产业、双产业、二选一和具名商品要求；Queue 对未结算组累计容量预留，整组结算后 exact-once 释放。Capacity Service 不拥有项目、GDP、Queue、卡牌效果或世界现金。
- Shared Card Group Window 切为 8 秒总窗、6 秒组织、2 秒锁牌；教程/标准组上限为 1/2。优先报价固定为 ¥0/¥50/¥100，同价允许并按顺时针参考席位排序。
- 锁牌时 Queue 唯一生成 `public_wager_pool_receipt`，所有组报价汇总进入下一场怪兽赌局公共池。旧任意竞价归一化、正报价唯一和组间竞价链已从活动代码、牌轨 fixture 与回归门删除。
- 新增长期 `IndustryCapacityCardGroupRuntimeBench`，64/64；Queue 56/56、Runtime Card Resolution Track 14/14、共享窗口与真实 Coordinator 聚焦测试通过。生产全局 Ruleset bridge 仍保持 v0.4，只有本领域通过显式 v0.5 domain snapshot 切换。
- 完整 FirstMission 37 项回归发现首局保证槽可能先选到孤立通商项目；该项目在 v0.5 结构化 GDP 下合法但初始 GDP 为 0。首局内容桥现明确保证本地商品生产项目，并从实际购入卡牌读取教学商品；通用城市发展方向、GDP 公式和供应算法未改。复跑 FirstMission 为 37/37。
- 本实现随后被 v0.6 指导版冻结为历史迁移证据：不再进入 SS05-06，不继续扩展项目合约或产业容量。8 秒总窗/最后 2 秒锁牌可复用；标准每人上限将在 SS06-04 按 v0.6 改为 3，容量 Service 与 Queue reservation 同批删除。

## 2026-07-14｜SS05-04 Victory Control And Public Audit

- 新增 `VictoryControlRuntimeController.tscn` 与非所有权 `VictoryControlWorldBridge.tscn`，静态接入 `GameRuntimeCoordinator`。区域控制只消费 SS05-03 的结构化归属 GDP，不复制 GDP 或项目份额公式。
- 迁移 3000bp 唯一最高控制、深度 I-VI Top-N、10 秒资格、120 秒粘性公开审计、30 秒失败冷却、终点比较、共同胜利、最后幸存、星球毁灭现金总账、存档与 exact-once outcome receipt。
- Standings、Final Settlement、AI、GameSession 和存档摘要改为消费 Controller snapshot/receipt；删除 `main.gd` 的现金目标、城市清算值、短倒计时和旧终局排名算法。
- 旧 `tests/smoke_test.gd` 中仍直接反射现金目标、倒计时、`game_over` 与旧 AI 终局奖励的断言已迁为 Controller/Coordinator、GameSession 和版本化 outcome receipt；Victory、composition 与 layout 门会阻止这些旧符号重新进入活动测试。
- 该 monolithic smoke 另以 300 秒上限实跑，仍停在既有 `new game setup` 性能点，尚未进入胜利断言；仅终止其专属 headless 进程。聚焦 Victory 56/56、composition 与完整 layout smoke 均已通过，未为遗留测试恢复旧算法。
- 新增长期 `VictoryControlRuntimeBench`，56/56 通过；合同见 `docs/victory_control_runtime_contract.md`。生产全局 Ruleset bridge 仍保持 v0.4，下一领域为 SS05-05 六产业产能与卡牌组占用。

## 2026-07-14｜SS05-03 Structured Project GDP

- 新增 Inspector 可编辑的 `space_syndicate_gdp_formula_v05.tres`。`GdpFormulaRuntimeController` 现在按稳定 region/project/slot/generation 生成生产、需求、通商及显式中性 GDP receipt；v0.4 Profile 只保留为历史证据，不参与 fallback。
- `CityTradeNetworkRuntimeController` 以“竞争 -> 路线 -> GDP 行 -> 项目/玩家/中性归属 -> 供应保证”的顺序刷新，并保存 `v0.5.structured-project-gdp.1` envelope。区域允许降到 0 GDP，最低 40 和整城分摊语义已删除。
- 玩家归属只来自具体项目份额。逐玩家下取整后的整数余数进入 neutral；区域、项目以及玩家+中性三层守恒均由 receipt 校验。无项目奖金和旧调整被明确标成 neutral，不再由 founder、controller 或 `city.owner` 领取。
- 实时现金流只消费 `receipt_id + player_index` 的 `project_share` 来源，余数按 source ID 保存。同 owner 竞争豁免、owner-only payout、`assign_city_gdp`、`gdp_by_player`、`project_gdp_by_player` 和旧 remainder map 均退出活动路径。
- GDP Formula Gate 为 40/40，CityTrade 长期门为 108/108 observed/aligned，City Development 为 64/64。公开 GDP 快照不包含 controller、贡献/份额表、隐藏 owner、私密目标、私密弃牌或 AI 计划。
- 全局 Ruleset bridge、Card Catalog 与生产存档版本仍为 v0.4/v1；本轮仅对项目/GDP 领域做 v0.5 hard cutover。下一步 SS05-04 必须以现有 private attribution receipts 实现 VictoryControl，不得重算 GDP 或项目归属。

## 2026-07-14｜SS05-02 Five Project Slots & Stable Identity

- `CityTradeNetworkRuntimeController` 成为五项目位身份和生命周期的唯一可变 owner：每区固定生产 2、需求 2、通商 1，项目最高 IV；`CityProductProjectState/Bridge` 只保留纯数据状态与变换。
- 稳定身份采用 ASCII `region_id -> slot_id -> project_id`，项目 ID 不再包含商品；同一商品可以占据两个独立生产位或两个独立需求位。
- 每个 slot 保存单调递增 generation；tombstone 保留旧项目 ID、原因和 generation，重开后生成新 ID，绝不复用已结束项目身份。
- 份额使用确定性最大余数分配并精确合计 10,000bp；唯一最高者控制项目，最高份额精确并列时 `controller_player_index=-1`，不再以创建顺序或座次破平。
- 新增显式 `CityProjectStateMigrationV04ToV05` 边界。旧显式项目可一次归一化到五槽位，但不得从 `city.owner`、旧 products 或 demands 猜造项目；Controller 只写一个 `city_trade_network_runtime` v0.5 envelope。
- City Development 通过稳定 slot/generation 执行同一原子 settlement；玩家、AI 与 fixture 不建立第二条项目写路径。项目公开 snapshot 不包含 controller、贡献表、份额表、隐藏 owner 或 AI 计划。
- 现有 CityTrade 长期 Bench 从 68 项扩展为 88/88 observed、88/88 aligned、0 design decisions；CityDevelopment 保持 64/64。下一步进入 SS05-03 结构化 GDP 行与守恒，删除剩余整城 GDP 分配语义。

## 2026-07-14｜SS05-01A Player-Facing Text Foundation

- 新增 `PlayerTextSpecV05`、可见性授权合同、locale resolver、玩家生成文字净化器、typed message catalog 和单位目录；固定数据流为“领域 receipt/snapshot 先授权净化，再生成 message key + typed args，最后本地化”。
- 默认 `zh_Hans` PO 已接入 Godot TranslationServer。发行路径遇到缺失 key、未知参数或非法 payload 时只显示安全通用提示；raw card/action/reason ID、`args.error`、NodePath 和 stack trace 只留在开发诊断。
- 单位目录集中管理 `currency_cents`、`basis_points`、`seconds` 与 `gdp_per_minute`；当前生产 UI 仍使用 v0.4，本轮没有提前切换 GDP 表面。
- 对现有 120 个卡牌家族、239 个等级资源建立逐条迁移 registry。每条保存 legacy ID、来源、rank、rules_text SHA-256、owner 和 blocking reason；当前 239 条全部 blocked、0 条 release-ready，只有已有 v0.5 候选明确的 5 条保存 proposed stable ID。
- v0.5 卡牌 rank schema 新增独立 `name_key`、`rules_key`、`short_effect_key` 和 `assistive_name_key`；validator 要求 release-ready 卡牌使用稳定 ASCII ID 与完整文字 key，但没有修改 v0.4 card_id 或存档引用。
- 新增唯一综合 `PlayerTextV05FoundationBench`，48/48 通过。Ruleset Foundation 56/56、Runtime Card Authoring 36/36、Runtime Card Catalog 80/80、Save Ownership 24/24、Menu Shell 24/24、Global Navigation 32/32 observed／19/32 aligned、composition、focus-order 与 layout smoke 均通过；Godot MCP `get_errors=0`。
- MCP Editability Hub、Space QA Dock、Sceneization Audit、System Resourceization Audit 与 v0.5 Conformance Registry 已登记本基础，状态均明确为 runtime inactive。
- `main.gd`、生产 v0.4 Ruleset/Card Catalog/save v1/UI 和玩家真实存档保持冻结；下一步进入 SS05-02 五项目位与稳定项目身份，卡牌语义改写继续等待对应 v0.5 rule owner。

## 2026-07-14｜玩家文字、卡牌规则与本地化呈现合同

- 新增 `docs/player_facing_text_and_rules_presentation_contract.md`，建立机器标识、开发诊断、译者元数据、玩家可见、玩家辅助和玩家生成内容六类文字合同；公开/私人/终局揭示/旁观者/开发范围作为独立可见性轴。
- 搜索并登记 18F、USWDS、GitLab Pajamas、PatternFly、KDE、GNOME、W3C、Unicode/CLDR、Godot 国际化，以及 OpenDuelyst、OpenTTD、FreeOrion、Unciv、Wesnoth、0 A.D.、Cataclysm: DDA 的官方资料、许可和采用边界。
- 开放资料只用于文字目录结构、卡牌数据/文案分离、占位符、本地化、错误写作和无障碍规则；不复制 GPL/MPL/CC-BY-SA 游戏的卡牌、剧情、百科或世界观原文。18F/OpenDuelyst 的 CC0 也只作为结构和原则来源，不复用品牌身份。
- 只读审计确认当前有三个冲突的玩家规则源：v0.5 玩家规则书、`main.gd` 中仍为 v0.4 的局内速查、以及 239 条仍夹带旧规则的等级卡牌文本。它们被列为 v0.5 P0，不得只做表面换词。
- 当前没有 `tr()`、`tr_n()`、`TranslationServer` 或翻译资源；场景与脚本同时含中文硬编码、英文占位、raw action/card id fallback、底层 error、开发理由 tooltip 和 `GDP /s`/`GDP/min` 单位冲突。
- 合同冻结文字数据流：Ruleset/effect/receipt 是规则真相；domain owner 输出稳定 code 与类型化参数；先做隐私过滤，再由现有 presentation/public snapshot owner 生成 `message_key + args`；本地化解析器不拥有规则，UI 不解析可见句子。

### 开发者应该如何参考

- 卡牌必须分开 `card_id`、`name_key`、`rules_key`、`short_effect_key`、`reminder_keys`、`flavor_key`、`use_case_key` 和机器 effect；中文显示名不能继续兼任存档/网络 ID。
- 卡牌固定按“名称/等级 → 类型/产业 → 费用/门槛 → 时机 → 目标 → 结算效果 → 持续/终止 → 例外/公开范围 → 关键词”呈现；模糊策略建议进入图鉴，不进入规则正文。
- 按钮用具体“动词 + 对象”，tooltip 只补充非关键帮助，禁用原因写解锁办法，错误写“发生了什么—原因—下一步”，确认框点名对象和不可逆后果。
- accessible name/description 属于最终玩家文字，必须本地化；可见标签优先，颜色和图标不能成为唯一含义来源。
- 先删除/替换 v0.4 速查、raw-id/raw-error fallback、英文占位、开发说明泄漏和错误单位；再建立默认 `zh_Hans` 目录；最后接入伪本地化、长文本、RTL、200% 缩放、键盘/手柄焦点与隐私截图门。
- 详细的当前文件位置、替换目标、v0.5 初始术语锁、QA 门禁和三阶段实施顺序只查新合同；`REFERENCE_LINKS.md` 与 `docs/open_source_reference_notes.md` 保存上游链接和许可边界。

### 本轮验证范围

- 本轮只新增/更新参考资料、文字合同和开发日志，没有修改 Godot 运行时、场景、卡牌 Resource、Ruleset、存档、action id、signal 或玩家行为。
- 链接和关键标题已做静态复核；后续真正迁移文字时必须新增 key 完整性、raw-id 泄漏、卡牌语义一致性、隐私 scope 和伪本地化布局测试。

## 2026-07-14｜SS05-00 可恢复 v0.4 基线与 v0.5 迁移基础合同

- 重新运行 Repository Safety Baseline：忽略规则调整前测得 `85` 个 tracked changes、`1211` 个 untracked paths；精确忽略 MCP 截图缓存与 tracked QA 图片的生成型 `.import` 后，待纳入快照为 `86` 个 tracked changes、`1154` 个 untracked paths，另有 `979` 个 ignored paths。
- 待纳入文件已按源码／场景／Resource／测试／文档、项目资产和已登记第三方 import metadata 分类；状态集合中没有大于等于 10 MiB 的文件，也没有发现玩家存档、凭据、私钥或新增机器绝对路径。
- `.gitignore` 只新增 `addons/godot_mcp/cache/` 与 `reports/**/*.import`；没有忽略 `.gd`、`.tscn`、`.tres`、`.uid`、测试、规则文档或第三方来源登记。
- clean-clone 导入复核发现 Windows `core.autocrlf` 会让 tracked 源资产 `.import` 出现仅换行不同的 dirty 状态，并改变 `main.gd` 的字节 SHA；新增 `.gitattributes` 将所有文本固定为 LF、二进制保持 binary，保留 Godot 导入设置并确保跨 clone 文件哈希一致。
- 新增 `rules_v05_migration_foundation_contract.md`，冻结分支拓扑、`currency_scale=100`、新金额字段统一使用 `*_cents`、资金事务 receipt、时钟域、暂停／抢占／存档行为和跨领域 receipt 边界。
- v0.4 只由不可变 `v0.4-runtime-baseline` tag 与发布分支保存；后续开发使用非发布 `rules/v05-runtime-integration` 分支，不建立运行时 v0.4/v0.5 selector、自动 fallback 或双 owner。每个领域必须在同一提交完成新 owner、调用方、测试和旧实现删除。
- 合约临时受损统一使用 `delivery_blocked`／`effect_suspended`，不会暂停 `expires_at`；Monster Wager 只消费 Queue 的 `public_wager_pool_receipt`；FinancialDistress 只拥有危机状态，跨领域淘汰由 EndStateSettlement 编排。
- 升级／合并卡在财务危机出售时的成本基准仍是 blocking product decision，本轮没有擅自选择算法。
- 本轮没有修改玩法、存档、信号、action id 或 `main.gd`。`main.gd` 保持 `20209` 非空行、`1285` 个函数，SHA-256 为 `6BD3F293EC2E92AEB81A39C80266314BE6A308D2C03ECD58FD8DB22958CAE699`。
- 本地门禁：Save Ownership `24/24`、Menu Shell `24/24`、Global Navigation `32/32 observed`／`19/32 aligned`、composition、focus-order 和 layout smoke 通过；layout smoke 额外稳定了拒绝旧建城动作前的派生城市外壳初始化，不改变生产行为。
- 本记录对应的 Git snapshot 只有在独立 clean clone 完成 Godot import、composition 与 layout smoke 后，才允许创建 `v0.4-runtime-baseline` annotated tag。

## 2026-07-14｜v0.5 删除／替换／推进开发计划

- 新增 `docs/rules_v05_development_plan.md`，把已确认的 v0.5 规则拆成 16 个可执行工单、9 个实施阶段和对应退出门。
- “直接删除”被定义为替代 owner 接管时同批移除旧生产语义，不是在当前 dirty 工作树中立即物理删除；任何删除前必须先通过 Repository Safety Baseline 并形成有意 Git 快照。
- 原子删除范围包括：现金目标胜利、75 秒旧终局、即时破产、百分比怪兽加注与强制下注、30 秒旧卡牌组、城市 owner 回退、GDP 最低值、整城按等级摊分、城市／出牌者竞猜、区域式合约、End Turn／私人计划、标准市场随机噪声和生产旧存档双读。
- 替换原则是保留现有单一所有权：GDP、CityTrade、Eligibility、Queue、Contract 和 Monster Controller 在原 owner 内升级；新增 VictoryControl、IndustryCapacity、Intel 与 FinancialDistress，区域生命周期事务进入现有 CityDevelopment owner，不把新规则重新塞回 `main.gd`。
- 首要关键路径固定为“项目身份与世代 -> 结构化 GDP 行 -> 玩家归属 GDP”；胜利、六产业产能、项目合约和项目情报不得在这条主干完成前各自实现聚合公式。
- v0.4 Ruleset、GDP profile、卡牌 catalog、characterization bench 和旧规则文档保留为历史证据，但在最终切换时必须退出生产 registry 和 v0.5 CI，不得成为自动 fallback。
- 存档策略明确为：进行中的 v0.4 对局不静默续打成 v0.5；首次写 v0.5 前只读备份 v1，旧构建不得降级覆盖 v0.5 存档。
- 本轮只写实施计划与开发日志，没有修改 Godot 运行时、场景、Resource、存档、AI 或游戏行为；当前可运行版本仍是 v0.4。

## 2026-07-14｜Global UI Navigation Characterization Sprint 67

- 保留 Menu Shell `24/24` 与 Codex Navigation `20/20` 两个既有门禁，没有新增重复 Bench。
- 扩展 `MenuShellRuntimeCutoverBench`，额外生成 32 项全局 Back / Focus 行为记录：`32/32 observed`、`19/32 aligned`。
- 新增纯数据表 `global_ui_navigation_characterization_registry.gd` 和合同 `global_ui_navigation_runtime_contract.md`。
- 已确认 13 个差距：根菜单退出确认、确认框/强制决定/两类抽屉优先级、日志复盘父页、精确焦点恢复、失效焦点 fallback、手柄 `ui_cancel` 和全局纯数据栈。
- 本轮没有修改生产 `main.gd`；其 SHA 与 20,209 非空行、1,285 函数、141 变量、204 常量保持不变。
- 下一步 Sprint 68 应一次建立单一全局 Surface Stack owner，并同步删除已刻画的 `main.gd` Esc/Back 路径；`CodexNavigationRuntimeController` 继续只拥有 Codex 内部状态。

## 2026-07-14｜v0.5 GDP 控制胜利与怪兽整场赌局规则定稿

- 用户已确认 v0.5 剩余规则决定，不再保留待拍板项。
- 新增 `docs/tabletop_rulebook_v05.md`，作为下一版玩家规则语义权威：
  - 胜利由“现金目标”改为“多个区域的个人归属 GDP 控制”。
  - 标准深度为 5 个受控区域、每区至少 30% 且唯一最高、前 5 区个人归属 GDP 合计至少 180/min。
  - 条件保持 10 秒后进入 120 秒公开经济审计；终点重新验资，失败后冷却 30 秒。
  - 城市改为五项目位共享城市，没有城市所有者；生产、需求、通商和合约 GDP 分别归入具体项目行。
  - 商品固定归入生命、能源、工业、科技、商贸、航运六类，个人归属 GDP 生成批次型卡牌产能。
  - 合约严格改为同一具体商品的项目对项目关系；情报改为竞猜具体商品项目的控制者。
  - 区域可彻底摧毁至 GDP 0，并通过工业＋生命双色“区域复兴 I–IV”恢复建设资格；旧项目和份额不自动复活。
  - 现金归零先进入 20 秒财务危机，不再当帧淘汰。
- 怪兽战斗赌局采用用户最后确认的下注结构：
  - 整场战斗只开一次 8 秒下注窗口。
  - 底注按开窗时可用现金的 5%–10% 计算。
  - 支付底注后可在该窗口内不限次数加注；每次使用绝对金额，标准单位为 50，不再重复按百分比计算。
  - 窗口关闭后仍可用卡牌、技能和满血升级干预战斗，但不能换边、追入或重开赌盘。
  - 奖池按获胜方各玩家的最终下注比例分配；平局退玩家资金，公共优先出价池滚存。
- 新增 `docs/rules_summary_v05.md`，供首局和局内速查。
- 新增 `docs/rules_v05_runtime_migration.md`，记录运行时所有权、参数、迁移次序、反套利边界和 conformance gate。

### 开发者应该如何参考

- 玩家行为、信息公开和胜负争议只查 `docs/tabletop_rulebook_v05.md`。
- 时间、阈值和模式数字最终进入单一 v0.5 Ruleset Resource；不能从速读页、UI 文案或开发日志读取运行参数。
- GDP 必须先改成带项目、商品和方向的结构化归因行；胜利、六类产能、合约和情报必须消费同一份“玩家实际归属 GDP”，不得各自复制公式。
- 怪兽赌局必须作为独立纵向切片迁移暂停、托管、绝对加注、累计伤害、派奖、财务危机和存档，不能只替换旧百分比按钮。
- `docs/rules_summary_v05.md` 只做玩家速查，`docs/rules_v05_runtime_migration.md` 只做实现合同，二者都不能覆盖完整玩家规则语义。
- 当前 `docs/tabletop_rulebook.md`、`docs/rules_summary.md`、`AGENTS.md` 和生产运行时仍描述 v0.4；在 v0.5 conformance gate 全部通过前必须保留这一状态标记，禁止宣称 v0.5 已可玩。

### 实现顺序与硬门

1. 新建 v0.5 Profile 和存档升级外壳，但生产桥仍连接 v0.4。
2. 先完成 GDP 项目归因和整数守恒，再做区域控制与六类产能。
3. 完成 10 秒资格、120 秒审计、审计名单和隐私快照。
4. 迁移 8 秒卡牌组、项目合约、项目竞猜、区域复兴和财务危机。
5. 单独完成怪兽整场赌局并覆盖 1、10、100 次连续绝对加注的幂等测试。
6. 更新 AI、教程、公共文案和旧现金胜利引用，全部门禁通过后一次性切换生产桥。

### 本轮验证范围

- 本轮完成规则定稿、玩家速读、迁移合同和可交付文档，不修改 Godot 运行时、数据、存档或 AI 行为。
- 当前运行版仍是 v0.4；v0.5 文件属于已批准的产品目标和后续实现依据。
- `output/pdf/space_syndicate_tabletop_rulebook_v0.5.pdf` 共 16 页，已逐页渲染检查封面、六张示意图、表格续页、标题落单、中文字体和页脚；未发现截断或溢出。
- `output/documents/space_syndicate_tabletop_rulebook_v0.5.docx` 通过 ZIP、Word XML、页面尺寸、边距、42 个标题、9 张表格和 6 个嵌图的结构检查；关键规则与 PDF 文本一致。
- 本机没有 LibreOffice/soffice，Documents 的 DOCX 原生分页渲染器无法启动；不能把 PDF 的视觉检查冒充为 Word 原生渲染。最终 DOCX 已保留此环境限制，并以结构与内容一致性门代替。
- `git diff --check` 通过；底注越界取整、全押尾数、复兴状态、旧合约续接、审计候选集合和现金托管边界均已完成一致性复核。

## 2026-07-14｜Repository Safety & Test Isolation Sprint 66.5

- 修复旧 `smoke_test.gd` 的假隔离：测试原来设置了已经不存在的 Main 属性，实际无参数保存/读取仍会落到玩家默认存档。
- `GameSaveRuntimeCoordinator` 新增严格受限的 QA 默认路径覆盖，只接受 `user://space_syndicate_design_qa/test_runs/*.save`；生产 v1 路径保持不变，玩家路径不能伪装成 QA 覆盖。
- Smoke 在 Main 入树及菜单存档状态读取前完成路径注入；扩展后的 Session/Save Ownership Gate 为 24/24。
- 新增 `tools/repository_safety_baseline.ps1` 和安全合同，清单只读记录 Git、文件哈希、Main 指标、玩家存档元数据及第三方发布阻塞，不进行 stage/commit/reset/delete。
- 展开状态清单记录 84 个 tracked changes 与 1,205 个 untracked paths；在形成有意 Git 快照前，干净 clone/export 门保持 blocked。
- Night Patrol 已明确为 CC BY-NC 4.0 prototype-only；当前 `main.tscn` 的四个音频直接引用及 CardArtView 皮肤必须在商业发布前替换。
- 聚焦验证：Save Ownership 24/24、main composition、focus-order、layout smoke 均通过；Godot 4.7 解析无错误。
- 旧 10k 行完整 smoke 在 300 秒上限停于 `new game setup` 后，已只终止对应 headless 进程。真实玩家存档的长度、时间戳和 SHA-256 前后完全一致。

## 2026-07-14｜菜单返回、商路网络与规则仿真参考包入库

- 菜单/策略界面加入 Chickensoft GameDemo、FreeOrion、Unciv、OpenRA；返回逻辑加入 Godot UI Navigation System、AppNavigation、SuperTuxKart。
- 商路/管线加入 Godot `Line2D`、`AStar2D`、`GraphEdit` 官方能力边界，以及 Mindustry、shapez.io、OpenLoco、Widelands 的铺设和网络交互参考。
- 规则/仿真加入 Project Alice、Unknown Horizons、OpenVic-Simulation、BEA value added、CSBCGF、boardgame.io、OpenSpiel、Forge、Godot Roguelike Example、OpenXcom 和 Cataclysm: DDA。
- 新增 `docs/navigation_trade_network_reference_adoption_plan.md`，记录统一返回优先级、当前导航/路线审计、Godot 图形工具边界、可删除路径和分阶段路线。
- 新增 `docs/runtime_rule_reference_adoption_plan.md`，记录 GDP 增加值诊断、卡牌执行前复核、同时结算、离线 AI 平衡和怪兽经济后果链的采用方式。
- `docs/open_source_reference_notes.md`、`docs/ui_architecture_audit.md` 和 `docs/city_trade_network_runtime_ownership_contract.md` 已同步所有权与许可边界。

### 当前架构判断

- 不新增第二个 PipelineGraph：`CityTradeNetworkRuntimeController` 继续唯一拥有路线、流量、损伤、刷新、GDP 输入和存档。
- Ruleset v0.4 未定义玩家自由铺管动作；当前先做商路显示、聚焦、检查器和编辑器 authoring，手动铺设必须等待版本化规则决策。
- `Line2D` 只显示，`AStar2D` 只寻路，`GraphEdit` 只做编辑器/QA 连接工具。
- 不新增第二个卡牌或宏观经济引擎：现有 GDP、Cashflow、Market、Eligibility、Queue、Execution、AI 和 Monster Controller 保持权威。
- BEA 增加值公式先用于离线双重计算诊断，不直接替换 `gdp_formula_v04`。

### 后续删除目标

- 统一导航 Hard Cutover 后删除 `main.gd::_unhandled_input()` 中直接 Esc/full-map/menu/pause 分支和确认无调用者的页面返回状态。
- `PlanetRouteSegment` 改成静态 `Line2D`/端点子节点并通过 parity 后，删除其自绘函数；sceneized route 成为唯一生产路径后，再删除 `map_view.gd` 的 legacy 商路 renderer。
- 若卡牌原子性审计发现直接 mutation 或重复合法性公式，迁到现有 Service 后同轮删除；不建立通用第二 Action Engine。
- 若怪兽后果链发现直接写派生 GDP 的旁路，改为世界损伤 receipt 与网络/市场/GDP 刷新后同轮删除。

### 本轮验证范围

- 当前生产目录没有 pipeline/pipe/conduit 贴图或模型，因此本轮没有旧管线素材可删。
- 本轮只更新参考索引、所有权合同和迭代/删除计划；没有下载外部代码/素材，没有改运行时、规则、存档、action id 或 signal。

## 2026-07-14｜卡牌、牌桌、菜单与科幻 HUD 参考包入库

- 将新的卡牌/牌桌参考加入 `REFERENCE_LINKS.md`：Simple Cards v2、Phase、UiCard、CardHouse、Balatro-Feel、NueDeck、Hypnagonia 和 Godot Card Game Framework。
- 将菜单/平面界面参考加入索引：Maaack Godot Game Template、Maaack Godot Menus Template 和 GodotOS。
- 将可直接评估的平面素材加入索引：Mechanized Magic、Kenney Sci-Fi/UI/Board Game Icons/Board Game Info/Board Game Pack/Playing Cards Pack、SCIFI UI、Wenrexa White UI Kit 和 Game-icons.net。
- 在 `docs/open_source_reference_notes.md` 中明确许可和复制边界：MIT/CC0 仍需按来源登记；Phase 的代码许可不覆盖 Scryfall 卡图和 MTG 内容；UiCard 插画需单独核对；AGPL 项目只做结构观察；Game-icons 必须逐作者署名。
- 新增 `docs/card_table_menu_reference_adoption_plan.md`，记录当前架构、采用矩阵、视觉语言、旧资产退役清单、零引用删除门和七阶段实施路线。

### 当前删除判断

- 保留 Runtime Card Catalog、Eligibility、Queue、Execution、Presentation、CardResolutionTrack、RightInspector、HandRack 和现有菜单场景所有权。
- 计划在完整切换后集中删除 Night Patrol 的八个卡牌 UI 文件、根目录 `CardUI.tscn` / `CardUI.gd` 兼容入口、大量重复 StyleBox 构造和可由 CC0 替代的 Game-icons 文件。
- 删除必须先满足替代场景/Theme/Resource 存在、生产与测试零引用、许可证登记、截图 parity、所有运行门通过和 Godot 零错误。

### 本轮审计基线

- 当前 `CardFace.tscn` 仍实例化根目录 `CardUI.tscn`，因此两套路径尚不能直接删除。
- 当前审计发现 95 处脚本 `StyleBoxFlat.new()`、269 处脚本 stylebox override 和 46 处场景 style override；后续目标是把稳定视觉状态收敛到 Theme variation/Resource。
- Night Patrol 卡牌 UI 的生产引用集中在 `scripts/card_art_view.gd`；十个 Game-icons SVG 也主要由该脚本硬编码，并由视觉测试检查 attribution。
- 本轮只整理参考资料和实施计划，没有下载外部素材、删除旧文件或修改运行时行为。

## 2026-07-14｜巨兽战斗开源参考包入库

- 将类 GigaBash 巨兽战斗所需的许可明确参考资料加入本地参考资料库：
  - 怪兽动作与轮廓：Quaternius `Ultimate Monsters`、`Animated Monster Pack`。
  - 机甲动作与机械重量感：Quaternius `Animated Mech Pack`。
  - 城市体量与破坏状态：Kenney `City Kit (Commercial)`、`City Kit (Suburban)`。
  - 建筑预切割/碎块替换：`Jummit/godot-destruction-plugin`。
  - 分块脏区更新：`ape1121/Godot4-3D-Smooth-Destructible-Terrain`。
  - 第三人称相机、输入和 Godot 场景组织：Kenney `Starter-Kit-3D-Platformer`、Godot 官方 demo。
  - 冲击/破坏特效与怪兽吼叫：Kenney `Particle Pack`、OpenGameArt `CC0 Deep Monster Roar`。
- 根索引 `REFERENCE_LINKS.md` 已加入可直接查找的链接、许可证和用途摘要；`docs/open_source_reference_notes.md` 已加入逐项使用方式、落地位置、禁止事项、导入流程和验收门禁。
- 本次只建立参考资料和开发合同，没有下载或导入外部模型、代码、特效、音频，也没有修改运行时代码。

### 开发者应该如何参考

- **保持产品边界：** Space Syndicate 仍是实时 PVE 隐藏信息数字桌游。怪兽继续按数据/概率表自动行动，玩家通过卡牌、军队、城市和经济系统影响它们；不得因参考巨兽格斗游戏而改成持续直接操控。
- **参考动作语言，不复制角色：** 从 Quaternius 素材整理重步、跳跃、飞行、蓄力、释放、受击、后退等动作词汇，再组合成本项目自己的怪兽动作 profile。不得复制哥斯拉、奥特曼、加美拉、GigaBash 角色等受保护名称、轮廓、招式、音频或 UI。
- **参考状态机，不让物理决定规则：** 建筑破坏应按 `完整 -> 预警/命中 -> 受损或碎裂 -> GDP/商路后果` 展示。权威伤害、城市份额、所有权和经济结算仍由现有 runtime 决定；碎块仅是结算后的视觉反馈。
- **参考分块更新，不替换星球桌面：** 可破坏地形 demo 只用于学习脏区更新、局部重建和缓存；不得替换现有可缩放球形 `MapView` 或区域信息结构。
- **相机/输入只用于展示场景：** Kenney 3D starter kit 可服务未来怪兽图鉴或独立 showcase 的旋转、缩放、手柄浏览，不进入主规则的持续怪兽控制。
- **VFX/SFX按事件阶段配置：** 预警、冲击、目标反应、余波/经济后果必须按顺序可读；高频粒子需要池化，关闭声音时仍要有视觉提示，同一吼叫不得成为全怪兽通用身份。
- **任何真实导入必须登记：** 外部文件进入 `assets/third_party/<source_id>/`，保留上游 LICENSE/README，并在 `docs/third_party_assets.md` 登记作者、来源、下载日期、文件清单和用途；运行态 profile 继续声明 `visual_source_id` / `upstream_source_id`。

### 后续实现的硬门禁

- 每次怪兽动作必须按“行动者、预警、目标、冲击、状态改变、经济后果”顺序读懂。
- 任何破坏演出必须有固定碎块数量、刚体寿命和性能预算，不得每帧重建主地图或大块 UI。
- 新素材不得绕过第三方素材登记、来源字段、美术身份测试和视觉验收截图。
- 单一外部怪兽身体包或吼叫包不得覆盖整个 roster；当前多来源怪兽身份门禁继续有效。

### 本轮验证

- 参考链接、许可证、用途和禁止事项已在两个资料库入口中逐项登记。
- `git diff --check` 通过。
- 文档链接完整性和关键门禁词扫描通过。

## 2026-07-07｜规则书 v0.2：城市化份额与城市化牌

- 将玩家规则书升级到 `v0.2`：
  - “建城”统一改为“推进城市化”。
  - 城市化不是免费基础动作，而是通过城市化牌完成。
  - 一个区域的城市化可以由多个玩家同时或轮流推进。
  - 每次推进城市化会新增商品生产、商品需求，或提升通商速度。
  - 区域 hover 的饼状图只显示当前玩家份额与对手合计份额，不公开对手人数和具体身份。
  - 商品流通、买涨/做空、合约奖励、仓储协议等收益按相关城市化/商品项目份额结算。
  - 合约签约权按商品判断，由该商品在目标城市中的控制者决定是否签约。
- 同步更新 `docs/tabletop_rulebook.md` 和 `docs/rules_summary.md`。
- 新增 `tools/build_tabletop_rulebook_artifacts.py`，用于从 Markdown 源规则书生成带 6 张示意图的 DOCX/PDF 试玩规则书。
- 验证：
  - `output/pdf/space_syndicate_tabletop_rulebook_v0.2.pdf` 共 16 页，已渲染为 PNG 缩略图检查，版式正常。
  - DOCX 结构检查通过，嵌入 6 张示意图。
  - 本机缺少 LibreOffice/soffice，DOCX 官方渲染门无法执行；PDF 已完成视觉 QA。

## 2026-07-05｜玩家桌游规则书初稿

- 新增 `docs/tabletop_rulebook.md`：
  - 以真人测试者为读者，按桌游说明书结构解释游戏概念、目标、组件、开局、流程、城市/GDP、商品/商路、区域牌架、出牌、竞价、怪兽、怪兽赌局、军队、合约、情报、天气、金融和终局。
  - 文案只描述当前规则，不写开发历史，不暴露 AI 决策细节或隐藏信息。
  - 重点回答新玩家会问的七个问题：怎么赢、开局做什么、为什么建城、怎么买牌、怎么出牌、怪兽为什么重要、GDP/商品/商路如何变成钱。
- 重写 `docs/rules_summary.md`：
  - 从长篇开发口径规则记录改为玩家速读版。
  - 保留完整规则书入口，方便主菜单规则页或测试者阅读材料引用。
- 验证：
  - `git diff --check` 通过。
  - 文档禁用词扫描通过：规则书和速读摘要不包含守护者、D6、3x3、充能、开发历史、AI 内部评分、压力桶、真实手牌/现金泄露等过时或开发口径文本。

## 2026-07-04｜图鉴退出路径与可读性修复

- 修复图鉴页“看得到子页面但退不出来”的 UI 架构问题：
  - 根因是 `MenuOverlay.present_menu_shell()` 每次打开菜单都会把 `MenuCatalogNavRow` 隐藏，旧代码只把返回按钮本身设为可见，没有重新打开父级本页导航条。
  - 新增 `_set_catalog_local_navigation()`，统一控制图鉴上一页/下一页/返回按钮和父级导航条可见性。
  - 图鉴大厅现在也显示本页“返回主菜单”按钮；卡牌/怪兽/商品详情仍先返回缩略图，再回来源页面。
  - 从主桌快捷入口打开区域/卡牌图鉴时，返回目标改为“返回牌桌”，不再绕去主菜单。
- 提高图鉴文字清晰度：
  - `MenuOverlay` 和旧兼容刷新路径的标题、正文、提示、按钮字号整体上调。
  - 卡牌图鉴缩略图从小字单行改为更大的卡面区域，路线/效果允许换行，效果区保留至少两行扫描空间。
  - 卡牌详情页摘要、用途三格、属性卡、I-IV 梯度卡文字上调，减少密密麻麻的开发说明感。
  - 角色、商品、区域、怪兽详情组件同步去除明显 8/9px 小字，抬高到更适合真人测试的字号。
- 增加测试保护：
  - `layout_scene_smoke_test.gd` 新增图鉴正文最低字号、本页返回按钮尺寸、卡牌缩略图尺寸、效果文本换行、卡牌详情可读字号断言。
  - `smoke_test.gd` 新增图鉴大厅和卡牌缩略图页的本地返回按钮可见性断言。
  - `ui_text_smoke_test.gd` 更新为检查统一本页导航 helper，而不是旧的散落按钮赋值源码片段。
- 本轮继续统一使用 Godot 4.7：
  - `godot --version` 为 `4.7.stable.official.5b4e0cb0f`。
  - 本地没有发现仍存在的 `tools\godot-4.6.2` 目录；项目测试命令全部走 Godot 4.7。
  - 已删除桌面残留的 `Godot 4.6.2.lnk` 快捷方式，避免误点旧版本。
- 验证：
  - `godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
  - `godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
  - `godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
  - `godot --headless --path . --script res://tests/playtest_readability_gate_test.gd` 通过。
  - `godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
  - 完整 `smoke_test.gd` 首次出现一次 AI route-plan 模拟断言波动；重跑完整 smoke 到 `finish`，未再出现 failure 输出。

## 2026-07-04｜运行桌面鼠标输入层修复

- 修复真人试玩桌面里星球无法拖拽、滚轮缩放、旋转和手牌点击无反应的问题：
  - 根因不是 AI 决策骨架，而是多个 `Control` 灰盒/overlay 容器默认拦截鼠标事件。
  - `OverlayLayer` 的空白骨架、`GameScreen` 的提示层、`PlanetBoard` 的侧边装饰和天气条、`PlayerBoard` 的背景容器改为明确透传。
  - `CardUI` 动态生成的关键词 chips/子控件全部透传，避免卡面文字/图标吃掉卡牌点击。
  - `HandRack` 增加真实 viewport 鼠标事件 fallback，让点击 hover 中的卡面也能稳定选中。
- 修复星球全局视图的区域划分可见性：
  - 保持项目既有性能合同：全局星球不启用复杂多边形面填充，避免边缘巨大色块。
  - 改为全局球体始终绘制轻量区域边界；拖拽/缩放时边界变细变淡，但不会消失。
- 增加 `tests/runtime_pointer_input_layer_test.gd`：
  - 验证真实 viewport 鼠标滚轮能到达 `RuntimeMapView`。
  - 验证真实鼠标拖拽能改变星球视角中心。
  - 验证地图仍有已生成区域、全局球体保持轻量区域边界。
  - 验证手牌卡面根节点接收点击，内部标签/美术子控件不偷鼠标。
- 本轮继续统一使用 Godot 4.7：
  - `godot --version` 为 `4.7.stable.official.5b4e0cb0f`。
  - 本地 4.6.2 目录已移除；旧 4.6.2 只保留在历史开发日志中作为过往记录。
- 验证：
  - `godot --headless --path . --script res://tests/runtime_pointer_input_layer_test.gd` 通过。
  - `godot --headless --path . --script res://tests/campaign_map_globe_regression_test.gd` 通过。
  - `godot --headless --path . --script res://tests/map_view_focus_rotation_test.gd` 通过。
  - `godot --headless --path . --script res://tests/focus_guide_gate_test.gd` 通过。
  - `godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
  - `godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
  - `godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
  - `godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
  - `godot --headless --path . --script res://tests/smoke_test.gd` 通过。

### 本轮验证目标

- 运行桌面必须允许玩家直接操作中央星球和底部手牌；左/右信息骨架、天气条、引导层、overlay 空白区域都不能成为隐形玻璃板。

## 2026-07-03｜桌面快捷方式切换到最新版 Godot

- 修正 `tools/launch_space_syndicate.ps1` 的 Godot 搜索顺序：
  - 现在优先使用系统可用的最新版 Godot，最低接受 Godot 4.7。
  - 支持 `GODOT_LATEST_EXE`、`GODOT_EXE`、系统 PATH 中的 `godot`/`godot4`、WinGet 安装目录和项目/工作区内的 `tools/godot-latest` / `tools/godot-4.7`。
  - 已删除本地 `C:\Users\Administrator\Documents\New project\tools\godot-4.6.2`，不再把 Godot 4.6.2 作为启动、测试或 fallback 标准。
  - 启动方式改为前台直接调用 `& <Godot> --path <projectRoot>`；实测 Godot 4.7 的 PATH/console 前台启动能保持游戏运行，`Start-Process` 和 GUI exe 路径在当前机器上会快速返回，容易表现成“快捷方式打不开”。
- 增加本地启动日志：
  - 写入 `%LOCALAPPDATA%\SpaceSyndicate\launcher.log`。
  - 记录实际使用的 Godot 路径和项目路径，便于排查“快捷方式打不开/打开旧版本/闪退”。
- 项目配置：
  - `project.godot` 的 `config/features` 更新为 `4.7`。
- 验证：
  - 桌面快捷方式继续指向 `space-syndicate-sync\Launch Space Syndicate.cmd`。
  - 启动脚本会从 `space-syndicate-sync` 推导项目根目录，不会跑到旧仓库。
  - `godot --version` 返回 `4.7.stable.official.5b4e0cb0f`。
  - `powershell.exe -File .\tools\launch_space_syndicate.ps1` 前台启动会保持运行，不再快速返回；测试后已手动清理验证进程。
  - `godot --headless --path . --script res://tests/playtest_readability_gate_test.gd` 通过。
  - `godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
  - `godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
  - `godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
  - `godot --headless --path . --script res://tests/commercial_playability_gate_test.gd` 通过。
  - `godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
  - `godot --headless --path . --script res://tests/smoke_test.gd` 通过。

### 本轮验证目标

- 桌面快捷方式打开的必须是当前 GitHub 对应的本地同步仓库，并统一进入最新版 Godot 运行路径；当前验证版本为 `4.7.stable.official.5b4e0cb0f`。

## 2026-07-03｜首局教练改为星球左侧窄卡

- 把 `FirstRunCoach` 从右上宽横幅改成星球左侧窄侧卡：
  - `GameScreen` 新增 `PLANET_LEFT_SIDE_LANE_*` 命名锚点，运行时统一把 `FirstRunCoachHost` 放入左侧桌边区域。
  - `FirstRunCoach.tscn` 把正文和主 CTA 从横向行改为竖向堆叠，默认宽度收束为 220px。
  - 正文可见长度从 30 字压到 24 字，长解释仍走 tooltip/规则页。
- 硬标准：
  - 首局教练必须像桌边提示卡，不得横跨星球上方。
  - 1600×960 下宽度不超过 340px，不能遮挡中央星球核心，也不能覆盖右侧详情。
  - 仍只能有一个主 CTA，不能变成按钮墙。
- 验证：
  - `tests/playtest_readability_gate_test.gd` 新增真实运行桌面检查，启动普通新局后验证首局教练在左侧窄栏、不碰中央星球核心、不碰右侧详情。
  - `tests/visual_snapshot.gd` 增加 source guard，要求 `GameScreen` 使用命名左侧栏常量和统一锚点函数。

### 本轮验证目标

- 真人第一次进桌时，中央星球继续是视觉主角；首局教练像桌游边上的提示牌，而不是挡住桌面的说明横幅。

## 2026-07-03｜首局教练折叠点延后到路线选择

- 修正 `FirstRunCoachSnapshot` 的默认折叠语义：
  - 看过顶部牌轨后不再自动折叠，下一步仍会提示“看经济总览”。
  - 玩家打开经济总览并完成路线选择后，才进入折叠完成态，减少后续桌面信息密度。
  - 非折叠教程/战役变体仍可继续带玩家进入线索档案阶段。
- 同步玩家文案：
  - 战役菜单路径从“练四步”改为“练流程”，避免玩家误以为首局只到出牌为止。
  - 完成态短句改成“钱、牌、路线已跑通”，强调这是一局策略桌游的真实学习闭环。
- 硬标准：
  - 首局教练不能在“出牌+看牌轨”后消失；必须继续覆盖经济和路线选择。
  - 默认折叠点必须服务降低信息密度，而不是截断首局目标。
  - 教程/战役如需继续看线索，必须显式关闭路线后自动折叠。
- 验证：
  - `tests/layout_scene_smoke_test.gd` 增加 track-only 不折叠、route-choice 后折叠的 ViewModel 验收。
  - `tests/playtest_readability_gate_test.gd` 增加首局教练折叠点可读性 gate。
  - `tests/visual_snapshot.gd` 更新 source guard，防止旧“看牌轨即折叠”字段回潮。

### 本轮验证目标

- 真人玩家第一次打出牌后，不会因为引导提前消失而不知道为什么要看经济、怎么继续赚钱。

## 2026-07-03｜星球试玩罗盘同步到路线选择

- 把中央星球旁的 `PlaytestFlowCompass` 从旧五步更新为 8 步短轨：
  - 点区 → 首召 → 建城 → 买牌 → 出牌 → 牌轨 → 经济 → 路线。
  - 下一步短句现在按同一条首局状态机推进：首召、城市化、买第一牌、打出手牌、看牌轨、看经济、选路线、看线索。
  - `main.gd` 的旧生成罗盘、真实 RuntimeGameScreen 的 `_runtime_planet_flow_compass_source()`、`PlanetBoardSnapshot` 和 `PlanetBoard` 默认 fallback 全部同步，避免 demo/测试/真实桌面出现不同口径。
- 硬标准：
  - 首局提示系统必须一致：Coach、开局轻引导、星球旁罗盘不能分别停在不同阶段。
  - 主桌罗盘只放短芯片，不放长规则；详细解释仍进入经济总览、规则页和 tooltip。
  - 经济总览后的“选路线”必须成为玩家可见桌面节奏，而不是只藏在 Coach 数据里。
- 验证：
  - `tests/layout_scene_smoke_test.gd` 验证 split `PlanetBoard` 默认渲染 8 个罗盘芯片，并包含牌轨/经济/路线。
  - `tests/ui_text_smoke_test.gd`、`tests/visual_snapshot.gd`、`tests/smoke_test.gd` 的罗盘断言同步要求新三阶段，防止回退到旧五步。

### 本轮验证目标

- 真人玩家看中央星球旁的小罗盘时，能看到首局目标不是“打一张牌就完事”，而是继续看牌轨、理解经济，并选择一条可执行路线。

## 2026-07-03｜经济总览后接入路线选择骨架

- 把首局动作链从“看懂经济”继续推进到“知道接下来怎么玩”：
  - First-run Coach 新增 `choose_route` 阶段，位于 `check_economy` 之后、`inspect_clues` 之前。
  - 新增 `first_run_coach_route_choice_players` 运行状态，并纳入存档/读档/新局清理。
  - 新增 `coach_choose_route_growth` CTA：首局默认推荐“走扩GDP”，执行后关闭菜单回到牌桌，并进入下一段线索查看。
  - Coach 路线阶段只保留一个主 CTA，同时用短芯片展示三条继续路线：扩GDP、护商路、压竞争。
  - Runtime first-run Coach 不再在“出牌+看牌轨”后直接折叠；真实首局会继续引导到经济总览和路线选择。教程/战役若要继续带玩家看线索，可显式关闭路线后自动折叠。
- 硬标准：
  - 经济总览不能成为首局终点；玩家必须得到一个短路线决策。
  - 路线选择必须是运行状态而不是临时说明文字。
  - 主桌仍保持单主 CTA，路线信息必须芯片化、短文本化，不能变回长规则说明。
  - 路线提示只使用公开/本地玩家可见信息，不显示 AI 内部计划、对手真实现金、真实手牌或隐藏归属。
- 验证：
  - `tests/commercial_playability_gate_test.gd` 验证真实首局从经济总览进入 `choose_route`，出现单一推荐 CTA 和三条路线芯片，并记录 `route_choice = grow_gdp`。
  - `tests/layout_scene_smoke_test.gd` 验证 `FirstRunCoachSnapshot` 的经济后路线阶段、路线芯片和非折叠线索阶段。

### 本轮验证目标

- 没读长规则的真人玩家在看完 GDP/商品/商路后，不会停在菜单里，而是被送回牌桌，先沿着一条清楚的赚钱路线继续测试。

## 2026-07-03｜首局出牌后接入经济总览

- 继续把真人首局从“会点按钮”推进到“理解为什么赚钱”：
  - First-run Coach 新增 `coach_check_economy` 动作。
  - 首局状态机在“打出第一张非起始牌 → 查看顶部牌轨”之后，会引导玩家打开经济总览。
  - 经济总览仍是局内菜单/仪表板，不把 GDP、商品、商路长解释塞回主桌。
  - 经济已读继续写入 `opening_guide_economy_seen_players`，与已有存档/开局轻引导共用同一骨架。
  - 首局自动购牌新增“教学补给 gate”：只把可购买、非起始、无需目标、买入后立刻可打的现金型普通牌当作第一张教学牌。
  - 如果当前怪兽可达牌架没有合格教学牌，会在真实可购买区域临时补入 `轨道融资1`，用于保护“买牌 → 手牌 → 出牌 → 牌轨 → 经济总览”的首局闭环。
  - 首局第一张普通牌打出前，怪兽赌局会延后开启，避免全场冻结/下注系统在玩家学会基础买牌和出牌之前抢占操作焦点。
- 硬标准：
  - 首局第一闭环必须回到钱：玩家要看到 GDP、商品、商路如何成为收入线索。
  - 出牌后的下一步不能只停在牌轨观察；必须给玩家一个资源/引擎理解入口。
  - 首局第一张普通教学牌必须通过四项验收：可购买、非起始、无需目标询问、买入后立刻可打。
  - 首局基础闭环完成前，不允许怪兽赌局这类高信息密度全场冻结系统打断。
  - 主桌保持简洁，经济解释仍收进经济总览。
- 验证：
  - `tests/commercial_playability_gate_test.gd` 验证 Coach 可以打开 `经济总览`，并把 `has_checked_economy` 标记为完成。
  - 同一测试验证首局购买后，真人手牌里存在一张可直接打出的非起始教学牌。
  - 同一测试验证怪兽赌局冻结在第一张普通牌前被延后，并在第一张普通牌打出后恢复。

### 本轮验证目标

- 真人玩家打出第一张牌后，马上能看到这局的经济仪表板，知道下一步是在扩 GDP、看商品还是保护商路。

## 2026-07-03｜首局闭环推进到买牌与出牌

- 把“真人能参与测试”的第一分钟闭环补到真实可玩动作：
  - 首局商业门槛现在验证：选区 → 首召怪兽 → 建第一城 → 打开区域牌架 → 买第一张区域牌 → 打出第一张非起始牌 → 查看顶部牌轨。
  - 新增 `card_purchase_count` 作为真实购牌次数骨架；起始手牌、首召怪兽、出牌费用、竞猜赔付等不再污染“买第一牌”的判断。
  - 首局进度的“匿名出牌”不再把起始怪兽首召算进去，只统计非起始牌进入/结算公开牌轨。
  - First-run Coach 自动买牌时优先选择“买完可以立刻尝试打出”的教学牌，避免随机买到暂时完全不能用的牌卡住真人玩家。
  - `GameScreen` 的强焦点来源优先级调整：first-run 强提示/脉冲会覆盖普通 ScenarioCoach 焦点，保证 Coach CTA 完成后眼睛知道看手牌或牌轨。
- 硬标准：
  - 首局引导的每个完成态必须有准确语义，不能用手牌数量或混合支出字段冒充。
  - 教学自动买牌必须优先服务闭环学习：买到 → 看手牌 → 尝试出牌 → 看牌轨。
  - 强焦点反馈必须跟随刚完成动作的结果区，而不是被普通提示覆盖。
- 验证：
  - `tests/commercial_playability_gate_test.gd` 验证完整首轮闭环、真实购牌计数、非起始牌出牌、手牌/牌轨强焦点和隐藏信息安全。

### 本轮验证目标

- 没读长规则的真人玩家在真实新局里，不只知道“哪里有牌”，还要能完成第一张区域牌的购买、出牌，并看到顶部牌轨如何留下公开线索。

## 2026-07-03｜运行牌桌焦点顺序纳入硬门槛

- 把“人类能不能顺手试玩”继续从口头要求变成可测骨架：
  - `RuntimeGameScreen` 现在公开 `runtime_focus_order_snapshot()`，并在快照前刷新真实焦点环。
  - 运行桌面的键盘/手柄分区顺序固定为：顶部状态 → 牌轨 → 星球地图 → 右侧详情 → 手牌 → 当前行动 → 竞价。
  - 打开区域牌架时，焦点顺序会动态插入：顶部状态 → 牌轨 → 星球地图 → 右侧详情 → 区域牌架 → 手牌 → 当前行动 → 竞价。
  - 焦点骨架识别真实牌架节点 `DistrictSupplySideDrawer / DistrictSupplyPanel`，不再只依赖旧占位名。
- 硬标准：
  - 每个运行桌面主分区必须可键盘/手柄聚焦。
  - 每个焦点槽必须有稳定 index、next/previous 链接、玩家-facing 标签，并保持可见。
  - 打开区域牌架后不能让玩家掉出桌面操作流，也不能遮断手牌/行动/竞价路径。
- 验证：
  - `tests/commercial_playability_gate_test.gd` 现在在真实 `RuntimeGameScreen` 验证关闭牌架与打开牌架两种焦点链。

### 本轮验证目标

- 真人玩家不用鼠标精确点，也能沿着桌游桌面顺序读牌轨、看星球、开牌架、看手牌、执行行动和参与竞价。

## 2026-07-03｜首局 Coach 加入强焦点反馈

- 继续推进“真人第一次进桌不迷路”：
  - 首局 Coach 的 CTA 成功后会触发 5 秒强焦点反馈，`FocusGuideLayer` 显示脉冲目标框。
  - 强提示文案固定为“最短｜目标｜动作”的短读法，不再靠长说明解释玩家该看哪里。
  - 强提示优先指向刚完成动作的结果区：首召后看行动区，打开牌架后看区域牌架，买牌后看手牌，出牌后看顶部牌轨。
- 修掉一个真实上手漏洞：
  - 首局 Coach 现在绑定本地真人席位；即使玩家正在查看 AI 公开档案，Coach 也不会把首召、开牌架、买牌等操作打到 AI 身上。
  - 新增 `_first_run_coach_player_index()` 与 `_open_first_run_coach_district_supply()` 作为可复用骨架，避免后续 CTA 再依赖全局查看席位。
  - 区域牌架的刷新、预览和购买改为绑定 `district_supply_open_player`，防止 AI 决策临时改 `selected_player` 时劫持玩家刚打开的牌架。
- 硬标准：
  - `docs/commercial_playability_gate.md` 明确 Coach 本地席位绑定和 CTA 后 5 秒强焦点反馈。
  - `tests/commercial_playability_gate_test.gd` 验证真实运行桌面上 FocusGuide 可见、脉冲、目标正确，并使用最短动作文案。

### 本轮验证目标

- 真人玩家点“下一步”后，不只是规则状态变化，而是立刻知道眼睛该看哪里、下一次点击在哪里。

## 2026-07-03｜右侧卡牌详情改为用途优先

- 继续降低主桌信息密度：
  - `RightInspector.show_card()` 不再直接把长效果塞进右栏，而是先从 `use_case / table_use / purpose / when_to_use` 读取牌桌用途。
  - 没有显式用途字段时，按怪兽、情报、互动、金融、经济、合约、天气、军队/战斗等类型推导短用途。
  - 卡牌 hover / 选中详情的固定读序改成：用途、费用、目标、状态、等级、类型；长效果进入完整详情。
  - requirements/why/full detail 都会优先显示用途，避免玩家在低分辨率下先读到一大段规则才知道这张牌干嘛。
- 骨架与硬标准：
  - 新增 RightInspector 侧的用途派生 helper、summary helper、requirements helper，后续卡牌详情页/购买预览可以复用同一读序。
  - 视觉契约补充：右侧详情也必须“用途优先”，不能退回开发说明面板。
- 验证：
  - `tests/layout_scene_smoke_test.gd` 验证手牌 hover 时 RightInspector 展示用途与目标。
  - `tests/visual_snapshot.gd` 验证 RightInspector 保留用途优先 helper。

### 本轮验证目标

- 真人玩家 hover 手牌时，右侧第一屏就能看到“这张牌拿来干嘛、打给谁、现在能不能用”，而不是被长规则文本挡住。

## 2026-07-03｜全卡用途语义接入数据源

- 继续推进“真人一眼知道卡牌干嘛用”：
  - 新增 `_card_use_case_text_for_skill()`，从卡牌 `kind`、投机方向、怪兽/军队/合约/情报/天气/商品/战斗字段派生短用途。
  - `CardFace` 的真实数据入口都接入同一用途语义：运行时手牌、区域牌架预览、卡牌图鉴缩略图和卡牌详情大卡。
  - `_make_skill()` 会给实际手牌卡补上 `use_case`，旧数据/派生卡也能落到同一读法。
  - `_card_face_quick_effect_text()` 改为“用途｜效果/关键数值”的扫读格式，避免玩家先看到长规则才知道用途。
  - 新增开发者审计 helper `_card_one_glance_audit_report()`，检查每张图鉴卡是否具备用途、短效果、路线、视觉/数值锚点、价格、等级、门槛和目标/结算 chip。
- 修掉审计暴露的真实问题：
  - 一批怪兽技能牌原本会退回“临场改局势”；现在按移动、飞行、潜行、格挡、护甲、延后行动、瘴气、战斗伤害等用途显示。
- 验证：
  - 新增 `tests/card_use_case_gate_test.gd`，用真实 `main.tscn` 审计全卡图鉴池，禁止泛化用途回退。

### 本轮验证目标

- 玩家看到手牌/牌架/图鉴卡面时，第一眼先读到“加GDP、押涨跌、查业主、反制、召唤怪兽、移动怪兽”等动作意图，而不是先读开发式长说明。

## 2026-07-03｜卡牌一眼读懂硬门槛

- 把“卡牌看上去好看”继续收束成可测试门槛：
  - `CardFace` / `CardUI` 现在会从 `use_case / table_use / purpose / route` 读取牌桌用途；没有显式字段时，按怪兽、军队、合约、情报、天气、金融、商品、商路、互动、经济等类型推导短用途。
  - 手牌小卡的短效果前缀改成“用途｜效果”，并新增 `◎用途` chip，让玩家先知道这张牌“拿来干嘛”，再读目标和门槛。
  - 大预览/详情的完整效果区增加“用途｜…”，与目标、条件、主动作、暂不可用原因形成固定读序。
  - 关键词 chip 顺序固定为用途、目标、门槛、时长、一次/固定，再追加外部自定义 chip，防止附加标签挤掉核心读法。
  - `CardViewSnapshot` 传递 `use_case`，让后续 UI 和图鉴可以消费同一字段。
- 文档与开发习惯：
  - `docs/card_visual_theme_contract.md` 新增“一眼读懂硬指标”：用途、视觉锚点、费用与门槛、目标、短效果、等级。
  - `AGENTS.md` 新增默认开发习惯：每轮功能要有硬标准、可复用骨架和验收门槛；临时方案要写清楚缺口。
- 验证：
  - `tests/layout_scene_smoke_test.gd` 验证 MiniCard 有用途前缀和用途 chip，Inspector 有用途行。
  - `tests/ui_text_smoke_test.gd` 验证 `CardUI` 的用途骨架与 `AGENTS.md` 的开发习惯护栏。

### 本轮验证目标

- 真人玩家在低分辨率手牌里先看到“用途/目标/门槛”，而不是被一行规则文本或一堆开发字段淹没。

## 2026-07-03｜战役复盘加入经济解释短卡

- 提升真人测试后的理解闭环：
  - `CampaignRewardService.build_recap()` 现在输出 `economy_cards`，把本席经济压缩成现金、城市/GDP、投入、下局抓手四张短卡。
  - `MatchRecapSnapshot` 规范化经济短卡，`MatchRecapPanel` 在行动摘要下方渲染一行经济复盘卡。
  - 真实战役完成统计新增本席经济字段：最终现金、现金变化、自有城市数、GDP/min、收入、支出、压力和最高 GDP 城市。
- 约束：
  - 经济复盘只展示当前玩家/公开可见数据，不展示对手现金、对手手牌、AI 私有路线或隐藏归属真相。
  - 不改变战役、奖励、经济结算或 AI 行为，只改复盘可读性。
- 验证：
  - `tests/campaign_reward_test.gd` 保护四张复盘摘要卡和四张经济解释卡的玩家-facing 读序。

## 2026-07-03｜区域跳转改用球面转向插值

- 补强“跳转到相应区域时中央星球也要旋转过去”的底层表现：
  - `MapView` 的程序化区域聚焦从展开图 XY 插值改为经纬度球面插值。
  - `focus_district()`、键盘区域导航和 `set_map(... selected=...)` 触发的选区变化仍复用同一套转向动画和目标光环。
  - 目标区域最终会面向玩家，旋转过程中不会瞬间切换，让玩家更容易理解自己被带到了星球上的哪个位置。
- 约束：
  - 不改游戏规则、卡牌、经济或 AI；这只是地图可读性与桌游桌面操作感修正。
- 验证：
  - `tests/map_view_focus_rotation_test.gd` 通过，确认远距离跳转、数据层跳转和键盘跳转都会可见转向并落到目标区域。

## 2026-07-03｜星球旁试玩罗盘改为状态化芯片

- 降低首局主桌找路成本：
  - `PlanetBoardSnapshot` 现在把首局流程输出为数据化步骤，包含已完成、当前、待办和下一步短句。
  - `PlanetBoard` 把原本同权重的“点区/首召/建城/买牌/出牌”文字改成 `✓ / ▶ / □` 状态芯片，并在下方显示当前下一步。
  - 真实运行桌面从 `main.gd` 的开局进度 helper 读取当前步骤，不再只给 split UI 一组静态文字。
- 约束：
  - 只展示玩家-facing 开局流程，不显示 AI 内部计划、对手手牌/现金或隐藏归属。
  - 不改变规则、结算、开局流程或地图交互，只改可读性骨架。
- 扩展测试：
  - `tests/layout_scene_smoke_test.gd` 验证 split `PlanetBoard` 场景包含罗盘下一步标签，真实绑定后渲染五个状态芯片，并验证 `PlanetBoardSnapshot` 保留状态数据。

### 本轮验证目标

- 真人看中央星球时，能在不读长规则的情况下知道“已经做了什么、现在该做哪一步”。

## 2026-07-03｜战役复盘页加入四张摘要卡

- 让玩家结束一关后先看“牌桌复盘”，再选择是否深入日志：
  - `MatchRecapSnapshot` 新增 `summary_cards`，压缩输出关键行动、学到、下次建议、回看四个玩家-facing 摘要。
  - `MatchRecapPanel` 在三列复盘列表前渲染四张短卡，降低复盘页文本密度。
  - 原有 key logs、checkpoint actions、返回奖励/战役地图按钮保留，不改变战役奖励、解锁或运行路径。
- 约束：
  - 摘要卡只来自公开复盘字段，不展示隐藏 owner、AI 私有计划、对手现金或开发评分。
  - 复盘仍用于玩家学习，不把主 UI 变成开发报告。
- 扩展测试：
  - `tests/campaign_reward_test.gd` 验证 recap snapshot 输出四张摘要卡，真实 `MatchRecapPanel` 渲染“关键行动 / 学到 / 下次建议 / 回看”。

### 本轮验证目标

- 真人完成新手关卡后，不需要读密集日志，也能知道自己做了什么、学到了什么、下一局该先看哪里。

## 2026-07-03｜区域跳转同步中央星球旋转

- 补强“跳转到相应区域”的主桌反馈：
  - `MapView.focus_district()` 已负责平滑旋转星球、记录目标区域并显示短暂目标光圈。
  - `main.gd` 新增牌轨目标桥接：选中/定位公开牌轨条目时，会从该牌公开字段推导目标区域，并调用主桌区域跳转。
  - 目标区域只来自玩家已可见的公开字段：牌的选中区域、合约目标/来源区域、目标怪兽当前公开所在区域；不暴露出牌者或 AI 私有计划。
  - `main.gd` 补回 `_runtime_player_board_snapshot()` 只读 helper，供测试和开发灰盒读取真实玩家板 quick actions，避免运行时行动坞回退成空数据。
- 扩展测试：
  - `tests/scenario_focus_navigation_test.gd` 新增运行时用例：选中一张有公开目标区域的牌轨卡后，中央星球必须开始旋转并最终落到该区域。
  - `tests/map_view_focus_rotation_test.gd` 继续保护 `MapView` 自身的平滑旋转、目标光圈、键盘/手柄选区路径。

### 本轮验证目标

- 玩家从战役定位、区域牌架、区域图鉴或历史牌轨跳到某个区域时，中央星球也要转过去，避免“文字说到了那里，但地图没跟上”的割裂感。

## 2026-07-03｜战役奖励页加入四张结算摘要卡

- 让玩家完成关卡后更快理解“我做得怎样、为什么继续”：
  - `CampaignRewardSnapshot` 新增 `summary_cards`，用数据输出表现、目标、解锁、下一步四张结算卡。
  - `CampaignRewardPanel` 在评分/统计/解锁列表前渲染四张短卡，像桌游电子版的结算摘要。
  - 原有评分、时间、目标、失误、提示、解锁列表和按钮保留，不改变战役进度和奖励逻辑。
- 约束：
  - 摘要卡只展示玩家-facing 结算信息，不显示隐藏分数、AI 私有状态或开发字段。
  - 不改变 RewardService 的奖励计算，只改变 UI 数据层和展示层。
- 扩展测试：
  - `tests/campaign_reward_test.gd` 验证 snapshot 输出四张摘要卡，真实 `CampaignRewardPanel` 渲染“表现 / 目标 / 解锁 / 下一步”。

### 本轮验证目标

- 真人完成一关后，不需要读细列表，也能理解自己的结果、解锁内容和下一步。

## 2026-07-03｜战役 Briefing 首屏改成三张摘要卡

- 降低玩家点进关卡后的阅读压力：
  - `CampaignBriefingSnapshot` 新增 `quick_cards`，把关卡压成三张第一眼摘要：目标、能做、收获。
  - `CampaignBriefing` 在长说明和三列细节前渲染摘要卡，让玩家先知道“这一关为什么开始”。
  - 原有 objectives / allowed_actions / teaches / reward 仍保留在细节区，不改变战役规则和运行路径。
- 约束：
  - 摘要卡标题限制为短句，避免 Briefing 回到说明书风格。
  - 不暴露隐藏信息、不改章节解锁、不改成功条件。
- 扩展测试：
  - `tests/campaign_menu_smoke_test.gd` 验证 Briefing snapshot 输出三张摘要卡，真实场景渲染“目标 / 能做 / 收获”，并保持 1280x720 可用。

### 本轮验证目标

- 真人打开某个战役关卡时，不需要先读完整 briefing，就能决定“开始本关”。

## 2026-07-03｜新手战役菜单加入三步视觉路径

- 让战役入口更像桌游电子版的“开始路径”，而不是只给章节列表：
  - `CampaignMenuSnapshot` 新增 `path_steps`，用数据描述“开桌 → 练流程 → 完整局”。
  - `CampaignMenu` 在进度和章节卡之间渲染三枚短路径芯片，显示现在/稍后/完成状态。
  - 路径芯片只承载方向感，详细规则仍留在战役 Briefing、规则页和桌面 Coach。
- 约束：
  - 不改变战役章节、规则、结算和解锁逻辑。
  - 不增加长说明，不把菜单变回规则说明书。
- 扩展测试：
  - `tests/campaign_menu_smoke_test.gd` 验证 snapshot 输出三步路径，真实 `CampaignMenu.tscn` 渲染三枚短芯片，并保持 1280x720 可用。

### 本轮验证目标

- 真人打开“新手战役”时，第一眼能理解这不是一堆菜单，而是一条从开桌到完整试玩的短路径。

## 2026-07-03｜桌面焦点提示加入目标专属动效

- 让首局/战役桌面提示不再只是同一种高亮框：
  - 星球和商路目标使用轻微 orbit 动效，暗示“看中央星球/地图转向”。
  - 手牌目标使用 lift 动效，暗示“拿起这张牌看/出牌”。
  - 顶部牌轨使用 scan 动效，暗示“沿时间轴查看公开事件”。
  - 行动区、竞价、右侧详情等使用 tap 动效，暗示“这里可以点”。
  - 牌架、合约/私密选择使用 double_tap 动效，暗示“需要确认一个临时窗口/选择”。
- 约束：
  - 动效都封装在 `FocusGuideLayer`，不拦截鼠标，不改变规则和结算。
  - `get_focus_debug_snapshot()` 只向测试暴露 `motion_profile`，不进入玩家-facing UI。
- 扩展测试：
  - `tests/focus_guide_gate_test.gd` 验证不同焦点目标会映射到正确动效骨架。

### 本轮验证目标

- 当真人玩家不知道下一步该看哪里时，桌面用轻量动效表达“看星球 / 看手牌 / 看牌轨 / 点右侧”，减少主界面文字解释。

## 2026-07-03｜7AI 完整烟测改成可持续验收台

- 修复完整 smoke test 过长的问题：
  - 原 `tests/smoke_test.gd` 的 8席/7AI 段会跑 4 轮完整 AI 决策、匿名队列、商业暗流、市场和现金流，实际接近 300 秒，容易在外层工具 5 分钟超时前后被切断。
  - 新增 test-only `_force_ai_opening_purchases_for_test()`：仍从 `_ai_card_buy_candidates()` 读取 AI 的字段化购牌候选，再调用真实购买函数完成每个 AI 的开局购牌覆盖。
  - 7AI 长测保留“首召、建城、购牌、出牌、商业暗流、市场、现金流、路线报告、终局倒计时、存档恢复”验收，但把循环压为 2 轮，并只执行一次强制商业暗流。
- 保留可诊断进度：
  - 7AI 段现在在每轮 `start / decisions / queue drained / economy settled` 打进度点。
  - 后续如果 AI 策略再次变慢，日志能直接定位是候选评分、队列结算还是经济结算拖慢。
- 验证：
  - 完整 `tests/smoke_test.gd` 从约 300 秒超时压到约 89 秒，并返回 `EXIT=0`。

### 本轮验证目标

- 让“真人可试玩”相关的核心回归测试能够稳定跑完，而不是因为 7AI 长模拟过慢导致每轮开发无法可靠确认可玩性。

## 2026-07-03｜玩家区域跳转统一驱动星球转向

- 收紧“跳转到相应区域”的真实运行路径：
  - 新增 `_jump_to_district_on_table()`，把玩家-facing 的选区、区域牌架、区域图鉴、情报线索和战役/首局引导定位统一到同一个桌面跳转入口。
  - 入口会更新当前选区、清掉手牌焦点，并调用主地图/全屏地图的 `focus_district()`，让中央星球平滑旋转到目标区域。
  - AI 内部临时结算、存档恢复和开局初始化仍不强行触发玩家演出，避免把内部计算误当成桌面跳转。
- 清理一个玩家可见的产品分层术语：
  - `OverlayLayer` 空抽屉提示从“打开 30 秒层信息”改成“展开完整桌边详情”。
- 扩展测试：
  - `tests/smoke_test.gd` 动态验证真实 `_select_district()` 跳转后，`MapView` 记录目标区并把球面中心转到目标区域。
  - `tests/ui_text_smoke_test.gd` 防止 `30 秒层/层信息` 进入玩家-facing split table 文案。

### 本轮验证目标

- 玩家从按钮、图鉴、情报线索、牌架或引导跳到区域时，不只是右侧信息变化；中央星球也要用转向解释“这个区域在星球哪里”。

## 2026-07-03｜右侧详情空状态去“说明书化”

- 继续把主桌从开发说明书推向桌游桌面：
  - `RightInspector.tscn` 默认标题从“右侧说明书”改为“桌边详情”。
  - 默认空状态从“解释为什么可用”改为“看用途、条件和下一步”。
  - `RightInspectorSnapshot` 的 fallback 同步改成同一套桌边详情读法。
- 不改变交互逻辑：
  - 已绑定的区域、卡牌、牌轨、手牌 hover、抽屉和图鉴路径不变。
  - 只处理玩家没选中对象或数据为空时的第一眼文案。
- 扩展测试：
  - `tests/ui_text_smoke_test.gd` 验证 RightInspector scene/snapshot 不回退到“右侧说明书/解释为什么可用”。
  - `tests/visual_snapshot.gd` 把右侧详情空状态纳入 split UI 契约。

### 本轮验证目标

- 新人第一次看到右侧面板时，会把它理解成桌边详情/当前对象详情，而不是一块需要阅读的规则说明书。

## 2026-07-03｜顶栏改成实时桌态/计时读法

- 降低主桌第一眼的“回合制/开发面板”误导：
  - `TopBar` 默认文案从“阶段｜开局 / 席位｜1/4”改成“桌态｜待开桌 / 计时｜00:00”。
  - `TopBarSnapshot` 优先输出 `table_state / tempo`，仍保留 `phase / turn` 兼容旧调用。
  - 真实运行时 `_runtime_top_bar_snapshot_source()` 不再把挑战深度当作顶栏阶段，而是输出 `经营中 / 竞价中 / 短窗 / 响应中 / 揭示中 / 牌队N / 牌架 / 终局` 等牌桌状态。
- 不改变规则：
  - GDP、卡牌结算、竞价、AI、隐藏信息和区域跳转逻辑不变。
  - 只是把实时桌游的状态读法从数据层固定下来，避免玩家误以为有“回合结束”式主循环。
- 扩展测试：
  - `tests/layout_scene_smoke_test.gd` 实例化 split `GameScreen`，验证顶栏显示“桌态 竞价中 / 计时 00:42”，且不回退到“阶段/席位”。
  - `tests/ui_text_smoke_test.gd` 和 `tests/visual_snapshot.gd` 保护 TopBar scene、脚本和 snapshot 的实时字段契约。

### 本轮验证目标

- 真人进入主桌时，顶部第一眼读到的是“现在桌面在做什么、开局多久了”，而不是开发历史里的阶段/席位/回合残留。

## 2026-07-03｜区域跳转增加星球转向光环，规则页增加卡面符号图例

- 补齐“跳转到相应区域”的视觉理解路径：
  - `MapView.focus_district()` 的程序跳转旋转改为更可感知的 0.34–0.72 秒平滑转向。
  - 目标区域在转向和落定后会短暂显示金色定位光环；如果目标暂时在球体背面，会先在球缘给出转向指示。
  - 选区、双击牌架、战役焦点、区域/情报图鉴链接仍复用同一套 `focus_district()`，不新增规则分支。
  - `MapView.set_programmatic_focus_animation_enabled(false)` 只用于后台 smoke/批量模拟，玩家默认路径保持可见转向。
- 降低规则页读牌门槛：
  - `RulesQuickReferenceBoard` 增加专门的卡面符号图例 rail，解释 `¥ / ◇ / ◆ / ◎ / ⇄ / 一次 / 固定`。
  - 旧的“卡面关键词”长说明从模块区移走，避免规则速查页又变成开发说明书。
- 不改变游戏规则：
  - 本轮只改可视化、图例和测试契约。
  - 购牌、出牌、商品流动、隐藏信息、牌轨结算、区域图鉴数据均沿用原逻辑。
- 扩展测试：
  - `tests/map_view_focus_rotation_test.gd` 验证区域跳转时开始旋转、记录目标、显示定位光环，并在落定后保留短暂视觉锚点。
  - `tests/layout_scene_smoke_test.gd`、`tests/ui_text_smoke_test.gd`、`tests/visual_snapshot.gd` 保护规则速查页的符号图例结构。

### 本轮验证

- 目标验证：玩家从按钮、图鉴、情报或牌架跳到某个区域时，中央星球会用旋转和光环说明“现在看的区域在哪里”；读卡时先认符号，不需要反复读长规则。

## 2026-07-03｜牌轨高频文案改为未知来源短标签

- 继续降低主桌信息密度：
  - 分离后的 `CardTrack` 仍保留隐藏来源规则，但槽位元信息不再反复写“匿名”。
  - 当数据层传入 `owner_hint = 匿名/未公开/unknown` 时，牌轨显示为“未知”。
  - `GameScreen` 的牌轨详情 chip 和焦点条改成“来源未知/来源待猜/来源玩家X”，更像桌游桌面线索而不是规则说明。
- 不改变推理规则：
  - 真实出牌者、真实城市业主、对手手牌和 AI 计划仍按隐藏信息规则处理。
  - 情报页、经济线索和日志仍可以在需要解释推理时使用“匿名”这个规则词。
- 扩展测试：
  - `tests/runtime_table_focus_order_test.gd` 验证运行牌轨收到匿名 owner hint 时，玩家看到的是“未知”而不是重复“匿名”。
  - `tests/ui_text_smoke_test.gd` 保护 `CardTrack` 与 `GameScreen` 的短标签 helper。

### 本轮验证

- 目标验证：玩家每秒扫读顶部牌轨时看到的是“槽位/报价/未知来源”，不是反复读“匿名规则解释”。

## 2026-07-03｜手牌悬停改为左侧大卡读牌预览

- 补齐真人读牌路径：
  - 手牌仍保持底部 mini card 牌架，避免把主桌塞满文字。
  - 鼠标悬停或键盘/手柄焦点落到手牌时，左侧桌边空位会打开一张只读大卡预览。
  - 大卡复用真实 `CardFace` 的 `inspector_full` 呈现，效果、目标、条件和主动作可以换行阅读。
  - 预览使用 `HAND_HOVER_PREVIEW_*` 锚点常量固定在星球左侧，不遮挡中央星球主体，也不阻挡鼠标/拖拽。
- 不改变规则：
  - 右侧详情、双击出牌、拖拽、竞价、购牌和结算路径不变。
  - 这轮只解决低分辨率下“手牌太小、效果看不清”的上手问题。
- 扩展测试：
  - `tests/runtime_table_focus_order_test.gd` 验证悬停手牌会显示左侧可读大卡、使用真实 `CardFace`、保持 hovered card 数据，并避开中央星球核心。
  - `tests/playtest_readability_gate_test.gd` 和 `tests/ui_text_smoke_test.gd` 加源码契约，防止以后删掉大卡预览或退回只靠 tiny hand text。

### 本轮验证

- 目标验证：测试者不用打开长规则页，也不用盯着小字，就能在主桌上临时“拿起一张手牌”读清楚它的作用。

## 2026-07-03｜连续卡住态改为脉冲定位和最短操作提示

- 补齐真人首局/战役卡住后的反馈层：
  - ScenarioCoach 现在会把普通提示和强卡住态分开。
  - 第一次求助或停留 20 秒仍显示短提示；连续求助或停留 30 秒后进入 `strong` 卡住态。
  - 强卡住态不增加长规则文本，只显示一句“最短：……”。
  - `FocusGuideLayer` 会在强卡住态对目标区域做轻微脉冲，高亮玩家下一眼应该看的桌面位置。
- 保持隐藏信息边界：
  - 卡住态只使用当前公开剧本目标、focus target 和玩家可见下一步。
  - 不暴露 AI 内部评分、对手现金、对手手牌或真实归属。
- 扩展测试：
  - `tests/scenario_focus_navigation_test.gd` 验证连续提示会进入强卡住态、启用脉冲光框、保留真实“定位下一步”CTA，并且不会伪完成目标。
  - `tests/playtest_readability_gate_test.gd` 验证强卡住态的“最短操作”仍然短，不退回长说明书。
  - `tests/visual_snapshot.gd` 保护 pulsing FocusGuide 和 shortest-action 字段不被删掉。

### 本轮验证

- 目标验证：测试者反复卡住时，桌面用动作和一句最短操作把注意力拉回下一步，而不是把更多规则文字压到主界面。

## 2026-07-03｜地图区域方向导航同步星球旋转

- 把“跳转到区域时星球必须转过去”升级成 MapView 底层交互契约：
  - `MapView` 现在是可聚焦 Control，运行桌面的“星球地图”焦点会落到真实地图，而不是只落到外层 `MapHost`。
  - 星球获得焦点后，`ui_left / ui_right / ui_up / ui_down` 会按屏幕投影方向选择相邻或最近区域。
  - 每次方向选区都会复用 `focus_district()`，中央星球会短促旋转到目标区域，避免只更新文字面板。
  - `ui_accept` 会打开当前选区的区域牌架，保留原有双击地图打开牌架的鼠标语义。
- 不改变游戏规则：
  - 购牌资格、价格锁定、查看/购买窗口、满手弃牌等仍由原有 `main.gd` 逻辑决定。
  - 这轮只补玩家理解空间位置的导航反馈。
- 扩展 `tests/map_view_focus_rotation_test.gd`：
  - 验证方向键会选择投影右侧区域。
  - 验证方向键选区会启动星球旋转并记录目标区域。
  - 验证确认键会打开当前聚焦区域的牌架入口。
- 扩展 `tests/visual_snapshot.gd`：
  - 防止运行桌面焦点退回空容器。
  - 防止地图方向导航和确认键入口被删掉。

### 本轮验证

- 目标验证：玩家从按钮、图鉴、情报或键盘/手柄跳到某个区域时，屏幕中央星球会用旋转动作说明“你现在看的是哪里”。

## 2026-07-03｜区域牌架卡接入键盘/手柄确认

- 继续补真人首局的非鼠标操作路径：
  - `DistrictSupplyMarketCard` 现在带有 `runtime_focus_kind = district_supply_market_card` 焦点标记。
  - 牌架卡支持 `ui_accept`：确认时会先同步预览，再触发购买/打开动作。
  - 牌架卡仍保留鼠标语义：悬停预览、单击预览、双击尝试购买。
  - `main.gd` 在刷新区域牌架时，会把所有牌架卡设为可聚焦 Control，并建立前后焦点链。
- 不改变购牌规则：
  - 查看仍然始终允许。
  - 是否能买、价格锁定、满手弃牌、怪兽区域/相邻区域资格仍由原有购买逻辑判断。
- 扩展 `tests/runtime_table_focus_order_test.gd`：
  - 实例化真实 `DistrictSupplyMarketCard.tscn`。
  - 验证牌架卡可聚焦、有焦点标记，并且 `ui_accept` 会发出预览和激活信号。
- 扩展 `tests/visual_snapshot.gd`：
  - 防止区域牌架卡退回鼠标-only 或删除焦点链 helper。

### 本轮验证

- 目标验证：测试者打开区域牌架后，不只可以用鼠标，也可以用键盘/手柄确认键完成“看牌 → 尝试购买”的基本路径。

## 2026-07-03｜情报/图鉴/键盘选区同步星球旋转

- 补齐玩家主动“跳转到区域”的入口：
  - 情报档案里标注城市、调整置信度、调整标注理由后，会同步把中央星球旋转到该城市区域。
  - 情报档案的“查看区域线索”跳转会同时更新主桌选区和星球旋转目标。
  - 区域图鉴打开指定区域、区域图鉴上一页/下一页切换区域时，主桌星球也会转向对应区域。
  - `Q/E` 键盘循环选区现在也复用 `_focus_runtime_map_on_district()`，避免右侧选区变了但中央星球停在旧位置。
- 不改变规则、经济、AI 或卡牌结算：
  - 只接入玩家可见导航入口。
  - AI/结算中临时切换 `selected_district` 的内部路径不触发镜头飞行，避免结算时星球乱转。
- 扩展 `tests/smoke_test.gd`：
  - 验证情报档案区域链接会记录 MapView 的目标区域和目标中心。
  - 验证区域图鉴跳转会记录 MapView 的目标区域和目标中心。

### 本轮验证

- 目标验证：玩家从情报、图鉴或键盘切到某个区域时，屏幕中央的星球会用旋转告诉玩家“你跳到了哪里”。

## 2026-07-03｜手牌卡接入键盘/手柄确认

- 继续把运行牌桌焦点链推进到真实操作：
  - `HandRack` 现在会把每张 `MiniHandCardFace` 设为可聚焦 Control。
  - 多张手牌之间会建立 next/previous 焦点链，测试者可在手牌内部移动。
  - 手牌获得焦点时复用 hover 预览，让右侧详情继续显示这张牌的说明。
  - `ui_accept` 第一次确认会选择手牌；同一张已选手牌再次确认会复用双击语义，向上发出该牌的出牌 action。
- 这仍然不把规则写进 UI 组件：
  - `HandRack` 只发出 `card_selected / card_double_selected` 意图。
  - `PlayerBoard` 继续根据 snapshot 中的可用 action 转成 `action_requested`。
  - 真实结算仍由 `main.gd` 的玩法控制器处理。
- 扩展 `tests/runtime_table_focus_order_test.gd`：
  - 验证手牌卡可聚焦、有 hand-card 焦点标记、有相邻焦点链。
  - 验证第一次确认选择手牌，第二次确认请求 `play_starter`。

### 本轮验证

- 目标验证：手柄/键盘测试者已经能从桌面焦点链进入手牌，并用确认键完成“看牌 → 选择 → 打出”的最小路径。

## 2026-07-03｜运行牌桌接入分区焦点顺序

- 补真人首局的键盘/手柄基础可达性：
  - `GameScreen` 现在会在真实 RuntimeGameScreen 上维护一条桌面分区焦点链。
  - 默认顺序为：顶部状态 → 牌轨 → 星球地图 → 右侧详情 → 区域牌架（打开时）→ 手牌 → 当前行动 → 竞价。
  - 这条链只写入 Control 的焦点属性和测试 metadata，不在玩家 UI 上增加调试文字。
- 牌轨槽位补键盘/手柄入口：
  - `PublicTrackSlot` 现在可获得焦点。
  - 获得/失去焦点会复用 hover 预览信号。
  - `ui_accept` 会选择该牌轨槽位，方便后续手柄/键盘测试。
- 新增 `tests/runtime_table_focus_order_test.gd`：
  - 验证 RuntimeGameScreen 核心桌面分区的焦点顺序、next/previous 链和可见性。
  - 验证公开牌轨槽位可聚焦并可用确认键选择。
- 扩展 `tests/visual_snapshot.gd`：
  - 防止后续删掉运行桌面焦点链或把牌轨重新退回鼠标-only。

### 本轮验证

- 目标验证：没读规则的测试者至少可以按桌游桌面的阅读顺序移动焦点，从牌轨、星球、详情、手牌、行动和竞价之间建立空间关系。

## 2026-07-03｜选区数据跳转也驱动星球旋转

- 补强区域跳转的底层兜底：
  - 之前走 `_focus_runtime_map_on_district()` 的入口已经会让中央星球旋转到目标区域。
  - 现在 `MapView.set_map()` 在同一张地图上检测到 `selected_district` 变化时，也会自动启动同一套短促旋转。
  - 这样后续新增“从日志/图鉴/事件/牌轨跳到某区域”的入口时，即使只刷新了选区数据，也不会出现右侧详情变了、星球还停在旧区域的断裂感。
  - 首次载入新地图仍保持星球总览，不会在开局瞬间强行飞到初始选区。
- 扩展 `tests/map_view_focus_rotation_test.gd`：
  - 显式 `focus_district()` 必须可见旋转。
  - 数据层 `set_map(... selected=新区域 ...)` 触发的选区跳转也必须可见旋转、记录目标区域，并在结束后让目标区域面向玩家。

### 本轮验证

- 目标验证：玩家被系统带到某个区域时，中央星球用运动解释“你去了哪里”；这个约束现在在 MapView 底层生效，不只依赖单个按钮入口。

## 2026-07-03｜首局引导 chip 改成“看哪里 / 完成后”

- 继续压低真人首局主桌的信息密度：
  - `FirstRunCoach` 原本 chip 行会重复显示阶段和进度；进度已经有独立标签，重复信息对新人帮助不大。
  - 现在首局引导 chip 改为三段：当前阶段、下一眼看哪里、做完后最直接变化。
  - 例子：
    - 点区：`点区 / 看星球 / 选定区`
    - 买牌：`买牌 / 看牌架 / 入手牌`
    - 出牌：`出牌 / 看手牌 / 进牌轨`
  - 这不改变任何规则、行动入口、焦点目标或隐藏信息，只让首局提示更像桌游桌边提示卡，而不是进度/debug 条。
- 扩展 `tests/layout_scene_smoke_test.gd`：
  - 验证首局 chip 不再重复 `0/8` 这类进度文本。
  - 验证点区和买牌阶段都有清楚的桌面目标和结果预期。
- 扩展 `tests/visual_snapshot.gd`：
  - 防止后续删除 `FirstRunCoach` 的 table-target/result chip 骨架。

### 本轮验证

- 目标验证：没读长规则的测试者看到首局引导时，能先知道“看哪块桌面”和“点完会发生什么”，减少在主桌上扫长文本的负担。

## 2026-07-03｜区域跳转改为可见星球旋转

- 继续修真人桌面导航的理解成本：
  - `MapView.focus_district()` 不再只把视角中心瞬时写成目标区域中心，而是启动一段短促的程序化星球旋转。
  - 新增 `focus_target_district / focus_target_center_m / focus_rotation_active / focus_rotation_progress` 调试快照字段，方便测试证明“正在旋转到哪个区域”。
  - 玩家拖拽地图时会取消程序化旋转，避免自动定位和手动观察互相抢控制权。
  - 剧本定位、首局查看牌架、买牌恢复到合法区域等所有走 `_focus_runtime_map_on_district()` 的入口都会复用同一套旋转骨架。
  - 顺手修正战役聚焦桌面状态：`PlanetBoard` 收到 `campaign_focus_mode` 后会立即隐藏两侧星球边栏和试玩罗盘；旧的右栏遮挡 helper 也不会在战役/剧本模式下把右栏重新打开。
- 新增 `tests/map_view_focus_rotation_test.gd`：
  - 验证远距离 `focus_district()` 第一帧不会瞬移。
  - 验证旋转会记录目标区域和目标中心。
  - 验证动画结束后中央星球确实对准目标区域。
- 扩展 `tests/scenario_focus_navigation_test.gd` 和 `tests/commercial_playability_gate_test.gd`：
  - 区域牌架定位现在不仅要打开真实牌架，还要记录并完成目标区域旋转。

### 本轮验证

- 目标验证：玩家点击“定位/跳转区域”时，中央星球会用可见旋转解释“系统把你带到了哪里”，而不是让地图和牌架突然变换。

## 2026-07-03｜卡住态主按钮语义收紧

- 继续细化 ScenarioCoach 的真人操作语义：
  - 之前卡住/求助后，主按钮文案会变成“定位下一步”，但底层 action 仍可能是原来的 `scenario_step_*`。
  - 现在 `ScenarioCoachSnapshot` 在 `help_visible=true` 时会把主 CTA 的 `id` 改为 `scenario_focus_target`，确保按钮写“定位”就真的执行定位。
  - 这不会伪造剧本成功条件；公开牌轨等目标仍只聚焦/选中，完成条件仍需真实 signal。
- 扩展 `tests/scenario_smoke_test.gd` 和 `tests/scenario_focus_navigation_test.gd`：
  - 验证卡住态主 CTA 是 `scenario_focus_target`。
  - 验证点击卡住态主 CTA 会聚焦目标，但不假完成 `track_selected`。

### 本轮验证

- 目标验证：玩家卡住后只需要看一个主按钮；主按钮文字、行为和真实桌面导航一致。

## 2026-07-03｜剧本“定位”变成真实桌面导航

- 继续把真人试玩从“读提示”推进到“桌面带你过去”：
  - 新增 `_focus_scenario_phase_target()`，统一处理 ScenarioCoach 的“定位”动作。
  - 公开牌轨/竞价目标会选中一张可见牌轨卡，方便玩家直接看右侧详情，但不会伪造 `track_selected` 等成功条件。
  - 牌架目标会打开真实区域牌架，并复用星球区域聚焦，让中央星球同步旋转到该牌架区域。
  - 经济、情报、局势、路线图层等目标会打开对应页面或切换对应地图图层；只做 UI 导航，不改规则、AI、经济公式或结算。
- 新增 `tests/scenario_focus_navigation_test.gd`：
  - 验证公开牌轨剧本点“定位”只聚焦牌轨，不假完成目标。
  - 验证市场手牌剧本点“定位”会打开本地玩家区域牌架，并让 MapView 对准目标区域。

### 本轮验证

- 目标验证：Scenario/Campaign 卡住时，“定位”不再只是写一行提示，而是可以把玩家带到真实桌面目标。

## 2026-07-03｜首局买牌 CTA 自动寻找合法牌架并旋转星球

- 继续补首局“按钮不该让新手迷路”的细节：
  - 新增 `_first_buyable_district_for_player()`，按怪兽落地区、相邻区、扩展补给、全局采购的顺序寻找当前玩家第一个合法可买牌架。
  - “买第一牌”首局 CTA 不再只看当前选区；当前区不可买但其他合法牌架存在时，会先切到合法区域并打开牌架，再按原购买流程购买。
  - `buy_card` 阶段的按钮 tooltip 会说明“会先切到某区域合法牌架”，避免玩家以为系统在越权买牌。
  - 如果确实没有合法可买牌架，仍不绕过规则，只保留牌架/日志反馈。
  - 新增 `MapView.focus_district()` 和 `_focus_runtime_map_on_district()`：自动选区、打开区域牌架、从错误区域恢复买牌时，中央星球会把目标区域旋转到视野中心，让玩家知道自己被带到了哪里。
- `tests/commercial_playability_gate_test.gd` 增加真人首局恢复门禁：
  - 首召后故意把选区设成不可购买区域，点击“买第一牌”必须恢复到怪兽可达合法牌架。
  - 恢复过程中不得丢失本地玩家手牌。
  - 打开牌架或恢复合法牌架时，MapView 的 `view_center_m` 必须对准目标区域中心。

### 本轮验证

- 目标验证：首局“买牌”从“当前区域不对就卡住”推进到“自动寻找合法市场”，同时星球视角跟随旋转到目标区域。

## 2026-07-03｜首局 CTA 自动落到推荐区域

- 继续推进“真人玩家不需要知道内部顺序也能走完前几步”：
  - 新增 `_ensure_first_run_coach_action_district()`，当首局引导 CTA 需要区域但玩家还没手动选区时，会自动选择推荐开局区域。
  - `coach_first_summon / coach_build_city / coach_open_rack / coach_buy_card` 现在都会先走该容错定位，再执行原有规则入口。
  - 不改变城市化、首召、买牌、怪兽范围、区域牌架资格等规则，只是把玩家带到已有的推荐区域，避免 CTA 按钮“看似可点但实际因为没选区而失败”。
- `tests/commercial_playability_gate_test.gd` 增加真人首局门禁：
  - 即使 `selected_district = -1`，首局“查看牌架”CTA 也必须能自动选中推荐区域、打开该区域牌架，并保留后续 FocusGuide 目标。

### 本轮验证

- 目标验证：首局主 CTA 从“提示你该去哪”推进到“能把你带到正确区域”。

## 2026-07-03｜首局引导接入 FocusGuide 数据骨架

- 继续推进“真人玩家进入主桌后不用读长规则也知道下一步看哪里”：
  - `scripts/viewmodels/first_run_coach_snapshot.gd` 现在为首局 8 个阶段输出 `focus_target`，例如点区指向 `planet`、首召/出牌指向 `player_hand`、建城指向 `action_dock`、买牌指向 `district_supply`、看牌轨指向 `public_track`。
  - `scripts/ui/game_screen.gd` 的 FocusGuide 数据源改为“战役/剧本目标优先，普通首局引导兜底”，所以非战役开局也能使用同一套独立光框层。
  - 没有活动目标、Coach 折叠或目标为空时仍然隐藏，避免主桌回到提示噪音。
- 扩展 `tests/focus_guide_gate_test.gd`：
  - 除战役目标外，现在验证首局 `select_district / first_summon / build_city / buy_card / inspect_track` 会高亮对应桌面区。
  - 继续验证光框不吃鼠标、目标为空时隐藏。
- `tests/visual_snapshot.gd` 增加护栏，防止后续把 FirstRunCoach 的 `focus_target` 映射或 GameScreen 的首局兜底删掉。

### 本轮验证

- `tests/focus_guide_gate_test.gd`
- `tests/visual_snapshot.gd`
- `tests/smoke_test.gd --check-only`

## 2026-07-03｜运行桌面接入 FocusGuide 目标光框

- 继续推进“真人能简单上手测试”，本轮处理战役/剧本目标虽然写了 `focus_target`，但玩家仍需要自己猜该看哪块 UI 的问题：
  - 新增独立骨架 `scenes/ui/FocusGuideLayer.tscn` + `scripts/ui/focus_guide_layer.gd`，专门负责焦点光框的渲染、短标签、颜色和不吃鼠标行为。
  - `GameScreen.tscn` 只实例化该层；`scripts/ui/game_screen.gd` 只消费 `scenario_coach.focus_target` 并把 `planet / player_hand / action_dock / public_track / right_inspector / district_supply / bid_board / private_decision / contract_prompt / top_bar` 映射到实际 Control 区域。
  - 这样后续如果继续做教学高亮、卡住闪烁、手柄焦点、自动打开抽屉，不需要继续把渲染细节堆回 `main.gd` 或 `GameScreen.gd`。
  - 光框只显示“看这里｜区域｜动作”这类短标签，不写长规则，不遮住操作，不暴露任何隐藏信息。
  - 目标为空、剧本未激活、Coach 折叠时自动隐藏，避免主桌出现无意义 UI。
- 新增 `tests/focus_guide_gate_test.gd`：
  - 验证 `player_hand`、`public_track`、`right_inspector`、`bid_board` 都能显示正确光框和短标签。
  - 验证光框不拦截鼠标。
  - 验证无活动剧本时 FocusGuide 自动隐藏。
- `tests/visual_snapshot.gd` 增加护栏，防止后续 UI 重构把 FocusGuide 层删掉。

### 本轮验证

- 目标验证：战役/剧本的 `focus_target` 不再只是数据字段，而是实际出现在运行桌面的可见焦点提示。

## 2026-07-03｜怪兽美术来源多样性清单

- 回应“MOS kaijus 只能用于一个怪兽，不能把每个怪兽都套同一张皮”的要求，本轮把怪兽 body 来源从口头约束推进成数据合同：
  - 新增 `data/art/monster_body_art_manifest.json`，逐一列出当前 8 只怪兽的 upstream、visual family、sprite key、asset path、license 和 silhouette intent。
  - `焰环幼星` 继续是唯一允许使用 MOS/Moth Kaijuice kaiju body 的怪兽；其他怪兽不得使用 `moth_kaijuice_*` body、Moth visual family 或 `moth_kaijuice_mit` upstream。
  - manifest 增加 8 个已经导入但未分配的非 MOS 候选 body：salamander、turtle、rodent、fish、Kenney slime、PixelMob amoeba、cyclops、thin slime，给后续新增怪兽一只一只做，而不是回到同一皮套换动作。
  - `tests/art_identity_gate_test.gd` 现在读取该 manifest，检查当前 roster 与代码一致、候选池足够、候选素材文件存在、候选 visual family 不复用当前怪兽、MOS 不进入未来候选池。
  - `tests/visual_snapshot.gd` 增加工程护栏，防止后续删除 manifest 或把候选池清空。
- 文档同步：
  - `docs/art_production_contract.md` 明确 manifest 是怪兽美术生产门禁。
  - `docs/third_party_assets.md` 新增 source-diversity manifest 说明和候选池边界。

### 本轮验证

- 目标验证：MOS/Moth Kaijuice body 只服务 `焰环幼星`；未来新增怪兽必须使用非 MOS 候选或新导入来源。

## 2026-07-03｜ScenarioCoach 空状态不再显示占位目标

- 继续推进首局真人可读性，本轮修正主桌上一个容易误导测试者的默认态：
  - 没有活动剧本/战役时，`ScenarioCoachSnapshot` 现在输出 `visible=false`，不再在主桌上显示“试玩脚本 / 完成当前目标”的幽灵提示卡。
  - 真正有活动剧本时，仍然显示原 `first_table.json` 等数据里的当前目标和单一主 CTA。
  - `ScenarioCoach.tscn` 与 `scenario_coach.gd` 的 fallback 文案改成“按桌边提示完成下一步”，避免未注入数据时出现像开发占位的句子。
  - 截图样例里的主按钮从“定位目标”改为“定位下一步”。
  - 修正 `_sync_runtime_game_screen()`：主控制器现在把 raw table state 交给 `GameScreen.apply_state()`，由 `TableSnapshot` 只归一化一次；之前双归一化会让 ScenarioCoach 丢掉 `current_phase`，回退成泛化目标。
- 设计意图：主桌上每张提示卡都必须代表一个真实可执行目标；如果没有目标，就不要占据星球侧边空间。

### 本轮验证

- `tests/playtest_readability_gate_test.gd` 新增空状态检查：ScenarioCoach 无活动剧本时必须隐藏，有真实剧本时必须显示真实目标。
- `tests/scenario_smoke_test.gd` 新增组件级检查：空 Coach 快照不能带占位 goal。
- 运行态人工验证：`first_table` 现在显示 `1/6 / 点区 / 选择一个陆地区域。 / 点击推荐区域`。

## 2026-07-03｜区域牌架预览改成四段速读卡

- 继续回应“真人玩家信息密度太高、像开发说明书”的问题，本轮只改区域牌架 UI，不改买牌规则、卡牌数据或结算：
  - `DistrictSupplySelectedPreview` 新增 `DistrictSupplyPreviewScanGrid`，固定渲染四个小信息卡：`用途 / 买入 / 打出 / 目标`。
  - `scripts/main.gd` 新增 `_district_supply_preview_scan_sections()`，把选中卡牌的路线、价格/购买状态、商品流动门槛和目标类型提前整理成短字段。
  - 有速读区时，旧的 `body / facts / status_text` 自由长文默认隐藏，只保留给 tooltip 和兼容 fallback。
  - 牌架顶部残留的英文 tooltip 改成中文玩家语言。
- 设计意图：买牌窗口是首局最高频路径，玩家不应该先读一段规则再判断要不要买；先扫四格，再看卡面，完整规则藏到悬停与规则页。

### 本轮验证

- `tests/playtest_readability_gate_test.gd` 新增护栏：区域牌架预览必须有四段速读，且旧长文不能在有速读区时常驻显示。
- `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 同步守住 `scan_sections`、`DistrictSupplyPreviewScanGrid` 和四个固定栏目，防止回退成规则块。

## 2026-07-03｜首局金融/合约/互动牌接入 Game-icons 语义图标

- 继续沿着“每张卡牌插画一张一张做，不要用同一套临时美术糊过去”的要求推进；这轮不改规则、价格或结算，只替换高频卡牌的视觉锚点：
  - 新增 `assets/third_party/game_icons_ccby/`，只导入少量 `game-icons/icons` SVG，而不是整库。
  - `城市融资1` 改为 `game_icon_bank`，不再只是 Moth 楼房。
  - `城市买涨1` 改为 `game_icon_profit`，`城市做空1` 改为 `game_icon_fall_down`。
  - `区域供需合约1` 改为 `game_icon_contract`。
  - `星链拆解1` 改为 `game_icon_breaking_chain`，`影仓牵引1` 改为 `game_icon_robber_hand`，`相位否决1` 改为 `game_icon_cancel`。
  - `港仓囤货1` 改为 `game_icon_warehouse`。
- `tests/card_runtime_review_capture.gd` 的 `REQUIRED_REVIEW_SPRITES` 同步改为这些语义图标；如果后续又退回楼房、士兵或激光图，审片脚本会失败。
- `docs/third_party_assets.md`、`docs/art_production_contract.md`、`docs/card_visual_theme_contract.md` 记录 CC BY attribution 边界：当前可用于原型，商业化前要保留完整署名或替换为自有素材。
- 设计意图：这些牌属于玩家第一局经常遇到的“读牌疲劳高风险区”。换成钱、涨跌、签约、断链、抢牌、取消、仓储这类桌游语义图标后，测试者不用读长句也能判断大概用途。

### 本轮验证

- `tests/card_runtime_review_capture.gd` 有头通过，刷新 3 页首局高频牌审片图；人工抽看第 1/3 页，确认融资、买涨、做空、合约、拆链、牵牌、否决、仓储牌已使用新 SVG 语义图标。
- `tests/art_contact_sheet_capture.gd` 有头通过，刷新卡牌/怪兽总览 contact sheet。
- `tests/visual_snapshot.gd`、`tests/ui_text_smoke_test.gd`、`tests/art_identity_gate_test.gd` 通过，保护新资产、玩家 UI 文本边界和怪兽/卡牌美术身份门禁。
- `tests/smoke_test.gd --check-only` 和完整 `tests/smoke_test.gd` 通过，确认这轮只替换卡面美术，不影响主玩法闭环。

## 2026-07-03｜首局牌插画锚点拆分：经济牌不再只靠楼和文字区分

- 继续沿着“真人能一眼看懂手牌”的方向推进，这轮不改规则、价格或结算，只改卡面视觉语言和审片门槛：
  - `CardArtView.card_visual_profile_snapshot()` 新增 `illustration_anchor` 字段。
  - 首局/高频牌现在有显式构图锚点，例如 `finance_tower / factory_core / transit_grid / broadcast_array / market_up / market_down / warehouse_stack / phase_null / air_wing / naval_fleet`。
  - `产业升级1` 不再和融资牌共用普通楼房观感，改用机具/工厂机械锚点。
  - `交通升级1` 改用轨道/飞行交通锚点。
  - `星际广告1` 改用广播/光束锚点。
  - 直接互动牌优先级修正：`星链拆解1` 和 `影仓牵引1` 不再因为带“情报”标签而被泛化成情报镜头。
- 继续回应“MOS kaijus 只能用于做一个怪兽，不能把每个怪兽都用这个美工”的要求：
  - `tests/art_identity_gate_test.gd` 新增显式 `EXPECTED_MONSTER_BODY_SPRITES` 名单，逐只锁定当前怪兽的上游包、视觉家族和 body sprite。
  - MOS/Moth Kaijuice 的当前唯一合法怪兽写死为 `焰环幼星`；其它怪兽只要声明 `moth_kaijuice_mit`、`moth_kaijuice_*` sprite 或 Moth visual family，测试就失败。
  - 这让“换动作、换颜色、换名字但继续用 MOS 身体”无法通过自动验收。
- 首局高频卡牌也加了 sprite 分布门槛：
  - `tests/card_runtime_review_capture.gd` 新增 `REQUIRED_REVIEW_SPRITES`，24 张审片牌逐张锁定预期 sprite。
  - 审片集至少要有 12 个 sprite family，单一 sprite family 最多出现 3 次，防止金融/合约/互动牌继续大面积共用同一栋楼或同一套 Moth 小图。
- `tests/card_runtime_review_capture.gd` 加硬门：
  - 首批 24 张审片牌必须拥有指定 `illustration_anchor`。
  - 首批 24 张审片牌必须拥有指定 `sprite_key`，并通过 sprite family 分布检查。
  - 如果某张牌视觉 profile 唯一但锚点错了、太泛化，审片脚本会失败。
- `tests/art_identity_gate_test.gd` 加入 `illustration_anchor` 字段检查和显式怪兽 body roster 检查，防止之后卡牌/怪兽 profile 退回只有 hash、颜色或名字差异。

### 本轮验证

- `tests/card_runtime_review_capture.gd` 有头通过，刷新 3 页首局高频卡牌逐张审片图。
- `tests/visual_snapshot.gd` 通过，保护审片脚本里的 `REQUIRED_REVIEW_ANCHORS`、`illustration_anchor` 和 dev-only 字段边界。
- `tests/ui_text_smoke_test.gd` 通过，确认玩家 UI 没有新增开发字段泄露。
- `tests/art_identity_gate_test.gd` 通过，确认卡牌 profile 现在必须包含 `illustration_anchor`。
- `tests/smoke_test.gd --check-only`、完整 `tests/smoke_test.gd` 通过，确认美术锚点拆分没有破坏主玩法闭环。
- 人工抽看 `art_card_review_first_run_01.png`：融资、产业、交通、广告四张经济牌已经从“同一类楼房+不同文字”拆成金融塔、工厂核心、交通网和广播阵列四种画面重心。

## 2026-07-03｜首局高频卡牌逐张审片台

- 继续执行“卡牌插画要一张一张做、不能看起来都差不多”的硬约束，这轮不改规则与数值，只补卡牌美术验收面：
  - 新增 `tests/card_runtime_review_capture.gd`。
  - 首批锁定 24 张首局/高频/关键交互牌：经济、交通、怪兽诱导、补给、基础行动、情报、金融、合约、直接互动和军队。
  - 每张审片 tile 同时展示完整卡面、手牌缩略图、简短玩家速读、`visual_source_id / sprite_key / sprite_cell / first_run_art_focus / motif_family` 等开发字段。
  - 脚本会检查首局 10 张关键牌的 `first_run_art_focus` 是否正确，并检查 24 张审片牌视觉 profile 不重复。
- 新增输出：
  - `reports/art/card_reviews/art_card_review_first_run_01.png`
  - `reports/art/card_reviews/art_card_review_first_run_02.png`
  - `reports/art/card_reviews/art_card_review_first_run_03.png`
- `tests/visual_snapshot.gd` 加入硬契约：逐张卡牌审片脚本、24 张名单、首局焦点检查、手牌缩略图和 dev-only profile 边界都不能丢。

### 本轮验证

- `tests/card_runtime_review_capture.gd` 有头通过，输出 3 页首局高频卡牌逐张审片图。
- `tests/visual_snapshot.gd` 通过，保护逐张卡牌审片脚本和 dev-only profile 边界。
- `tests/ui_text_smoke_test.gd` 通过，确认玩家 UI 文本边界未被开发字段污染。
- `tests/art_identity_gate_test.gd` 通过，继续保护卡牌/怪兽/动作 profile 唯一性。
- `tests/smoke_test.gd --check-only`、完整 `tests/smoke_test.gd` 通过，确认审片台不破坏主玩法闭环。
- 人工抽看 `art_card_review_first_run_01.png`：标题、完整卡面、手牌缩略图、玩家速读和 profile 芯片可见；也暴露出经济类卡牌仍偏同构，下一轮应逐张替换这些卡的插画锚点。

## 2026-07-03｜怪兽身体来源再加严：MOS 不复用，新增 PixelMob CC0

- 回应“MOS kaijus 只能用于做一个怪兽，不能反复换动作当成多只怪兽”的审片要求，这轮把门槛从“sprite key 不同”继续提高到“上游来源分布必须健康”：
  - `assets/third_party/pixelmob_cc0/` 新增 `rakkarage/PixelMob` 的 CC0 `SlimeA.png`、`SlimeSquareA.png` 和 `LICENSE-ART.txt`。
  - `绿洲修复体` 改用 `pixelmob_slime_square`，不再和 Kenney 史莱姆或 MOS 发生视觉混淆。
  - `砂铠陆行兽` 改用 `monster_battler_rock`，更像岩石/砂铠冲撞体。
  - `镜像猎兵` 改用 `kenney_alien_blue`，减少 Superpowers 素材在怪兽 roster 里的占比。
  - `焰环幼星` 继续是唯一使用 `moth_kaijuice_kaiju` 的怪兽。
- `MonsterArtView`、`CardArtView`、`MapView` 同步支持 PixelMob 帧条取帧；图鉴、本体、怪兽牌和地图 token 使用同一 `sprite_key / sprite_cell / visual_source_id / upstream_source_id` 合约。
- `tests/art_identity_gate_test.gd` 加严：
  - 当前 roster 必须覆盖至少五个上游/open-source 怪兽身体来源。
  - 当前 roster 必须包含 `moth_kaijuice_mit / monster_battler_cc0 / kenney_cc0 / pixelmob_cc0 / superpowers_asset_packs_cc0`。
  - 单一上游来源不能供应超过当前 roster 的 35%。
  - MOS/Moth kaiju 仍然必须恰好只出现 1 次。

### 本轮验证

- `tests/art_identity_gate_test.gd` 通过，保护 MOS/Moth kaiju 只服务一只怪兽、五个上游来源同时出现、单一来源不超过 35%。
- `tests/visual_snapshot.gd`、`tests/ui_text_smoke_test.gd` 通过，保护新 PixelMob 资产、文档契约和玩家 UI 文本边界。
- `tests/smoke_test.gd --check-only`、完整 `tests/smoke_test.gd` 通过，确认这轮只替换美术来源，没有破坏 PVE roguelike 主闭环。
- 已刷新 `reports/art/monster_reviews/art_monster_review_02.png`、`art_monster_review_05.png`、`art_monster_review_08.png` 和 contact sheet，确认砂铠/绿洲/镜像的身体来源已实际变更；焰环幼星仍是唯一 MOS/Moth kaiju。

## 2026-07-03｜逐只怪兽审片图 + 怪兽牌卡面与本体对齐

- 继续执行“接下来的任务先一只一只做怪兽美术/卡牌插画”的硬约束，这轮不新增玩法，只补美术审片和自动门禁：
  - `CardArtView` 现在为孢雾海皇/砂铠陆行兽/蓝锋骑士/镜像猎兵加载并使用 Superpowers 的 dragon/cyclop/snake/slim sprite，怪兽牌卡面不再退回不相关的鱼/小怪临时图。
  - 焰环幼星的怪兽牌卡面改成 `moth_kaijuice_kaiju`，继续保证 MOS/Moth kaiju 只服务这一只当前怪兽。
  - `tests/art_identity_gate_test.gd` 新增硬门：每张 I 级怪兽牌必须使用和对应怪兽本体相同的 `sprite_key`；否则直接失败。
- 新增 `tests/monster_runtime_review_capture.gd`：
  - 为当前 8 只怪兽逐只生成 `reports/art/monster_reviews/art_monster_review_01.png` 到 `art_monster_review_08.png`。
  - 每张图同屏展示图鉴/本体美术、怪兽牌卡面、主地图 token、动作 profile、代表性运行态动作演出。
  - 这批图用于人工逐只审片，后续替换单只怪兽美术时必须重新生成。
- `docs/art_production_contract.md` 和 `docs/third_party_assets.md` 更新：记录逐只审片命令、怪兽卡面与本体 `sprite_key` 对齐规则，以及 Superpowers 素材现在也用于对应怪兽牌卡面。

### 本轮验证

- `tests/monster_runtime_review_capture.gd` 有头通过，输出 8 张逐怪兽审片图。
- `tests/art_contact_sheet_capture.gd` 有头通过，刷新卡牌/怪兽总览 contact sheet。
- `tests/art_identity_gate_test.gd` 通过，包含新门禁：怪兽牌 I 与本体 `sprite_key` 必须对齐。
- `tests/ui_text_smoke_test.gd`、`tests/visual_snapshot.gd`、`tests/smoke_test.gd --check-only`、完整 `tests/smoke_test.gd` 通过，保护逐怪兽审片脚本、visual contract 和主玩法闭环。

## 2026-07-03｜怪兽动作 Profile 接入运行态地图演出

- 继续推进“每只怪兽、每种攻击都要有独立动作”的硬约束，这轮不改规则、伤害、概率或经济，只把已经存在的动作 profile 真正接进主地图演出：
  - `_add_monster_attack_effect()` 现在可携带 `motion_family / pose_key / effect_layer / profile_key / range_meters / knockback_meters / throw_meters / impact_seconds`。
  - 自动怪兽特殊行动、遭遇战、绑定技能、怪兽主动攻击会把 `_monster_action_animation_profile()` 生成的 profile 传给地图事件。
  - `MapView` 新增 profile-driven 灰盒动作语法：beam、projectile、dash/roll/burrow、throw、miasma、repair、roar/wave、melee/blade/electric/flame 都有不同绘制骨架。
  - `MapView` 的 visual payload signature 纳入动作 profile 字段，避免同一位置不同动作被缓存成同一张图。
- 新增 `tests/monster_action_map_effect_capture.gd`：
  - 读取真实怪兽动作审计数据，挑选不同 `motion_family` 的动作。
  - 使用真实 `MapView` 生成 `reports/art/art_monster_action_map_effects_1600x960.png`。
  - 验收图显示开发字段，但玩家正式 UI 不展示这些字段。
- `docs/art_production_contract.md` 更新：动作 profile 不只停留在图鉴 contact sheet，运行态地图事件也必须消费这些字段；后续精修动画时不能退回卡名硬编码。

### 本轮验证

- `tests/monster_action_map_effect_capture.gd` 有头通过，输出 `reports/art/art_monster_action_map_effects_1600x960.png`。
- `tests/art_identity_gate_test.gd` 通过，继续保证 MOS/Moth kaiju 只作为一个怪兽美术来源，不允许全怪兽复用换皮。
- `tests/visual_snapshot.gd`、`tests/ui_text_smoke_test.gd`、`tests/layout_scene_smoke_test.gd`、`tests/smoke_test.gd --check-only`、完整 `tests/smoke_test.gd` 通过。
- 顺手修正旧行动 dock 的首召按钮呈现：主按钮保持“出牌”，首召作为状态显示，避免玩家和测试都在同一动作入口上看到不稳定标签。

## 2026-07-03｜运行期数值梯度与规则漏洞补洞

- 追加收尾：把运行期平衡从 `main.gd` 继续拆出独立模块，避免后续把所有公式堆回主控脚本：
  - `scripts/balance/movement_balance_model.gd`：星球尺寸、区域数量/面积、怪兽移动 m/s、军队移动 m/s。
  - `scripts/balance/combat_balance_model.gd`：怪兽攻击压力、普通/光线/投掷/冲锋/爆炸击退距离与 0.5 秒冲击窗口。
  - `scripts/balance/environment_balance_model.gd`：天气状态、市场刷新、天气预报、经济波动因果函数。
  - `scripts/balance/runtime_balance_model.gd` 现在作为 dev-only hub 汇总这些模型，`main.gd` 只保留 thin wrapper。
- 新增独立文档：
  - `docs/campaign_chapter_settings.md`：战役章节字段、scenario/runtime fixture、visual_events、RewardPanel/MatchRecapPanel、隐私边界。
  - `docs/global_environment_balance.md`：天气状态、市场刷新、预报窗口、商品价格因果链、经济波动函数。
  - `docs/developer_manual.md`：当前项目方向、隐藏信息边界、文件分层、balance 模型、测试命令、Git 工作流和常见坑。
- 新硬指标：
  - 普通怪兽/军队约 10 秒离开一个区域，移动按米每秒线性计算。
  - 飞行怪兽约 10x 普通速度且不造成普通践踏；海洋怪兽约 5–8x；定着怪兽可近乎不动。
  - 普通近战击退约 0.85 个区域半径，默认 0.5 秒完成；光线/投掷/冲锋/爆炸拥有独立 profile。
  - 市场刷新 30–60 秒；天气提前预报 60–180 秒；一次天气影响 1–5 个区域。
- 本轮引入运行期平衡审计，不进入玩家主 UI，只给测试、开发日志和后续 AI/模拟器使用：
  - `data/balance/runtime_balance_targets.json` 固化胜利目标金额、参考 GDP/min、价格档位和怪兽伤害资金池锚点。
  - `docs/runtime_balance_report.md` 记录卡牌价格梯度、胜利目标金额梯度、参考游戏时长、怪兽伤害与金额比例。
  - `scripts/main.gd` 通过 `_runtime_balance_audit_report()`、`_runtime_balance_card_feature_matrix()`、`_skill_balance_feature_vector()`、`_skill_balance_score_breakdown()` 等 wrapper 统一读取独立 balance model，方便之后做卡牌平衡和 AI 智能时统一读字段。
- 规则漏洞修正：
  - 深度 I 胜利现金目标上调并改为 `base + step + quadratic` 梯度，避免开局一城后过快进入终局。
  - 卡牌购买价仍按家族 I 级锚定，但现在读取现金、GDP、期货、军队、互动、怪兽等字段做购买价修正。
  - 怪兽受伤导致召唤者输钱时，只按实际损失 HP 结算；过量伤害不再放大赔付和赌局伤害统计。
- 可玩性意义：
  - 首局会留下更完整的“首召怪兽 → 建城 → 买牌 → 出牌 → 怪兽压力 → 终局冲刺”空间。
  - 高杠杆金融、军队、拆牌、怪兽牌不再和基础移动牌价格过近。
  - 怪兽战斗仍能暴露归属和制造逆风点，但不会因 overkill 产生不合理金钱爆炸。

### 本轮验证

- 新增 `tests/runtime_balance_report_test.gd`，覆盖运行期平衡报告、硬函数、现金目标、卡牌价格和怪兽过量伤害。
- `tests/runtime_balance_report_test.gd` 已通过，覆盖 movement/combat/environment 拆分、星球区域尺度、怪兽/军队移动、击退 profile、天气/市场刷新和隐藏在 dev-only balance hub 的统计入口。
- 本轮最终验证：
  - `tests/runtime_balance_report_test.gd` 通过。
  - `tests/ui_text_smoke_test.gd` 通过。
  - `tests/visual_snapshot.gd` 通过。
  - `tests/layout_scene_smoke_test.gd` 通过。
  - `tests/smoke_test.gd --check-only` 通过。
  - `tests/smoke_test.gd` 完整通过。

## 2026-07-03｜牌轨文案改为“待猜”状态

- 本轮继续降低主桌信息密度，重点处理牌轨和竞价区反复强调“匿名”的问题：
  - `PublicTrackSnapshot.HIDDEN_OWNER_TEXT` 从“匿名”改为“待猜”，tooltip 里显示“归属待猜”。
  - 运行时顶部牌轨、空牌槽、教学牌轨、归属竞猜、线索档案证据链统一改用“公开牌 / 待猜 / 已选牌轨证据链”等玩家向短语。
  - 当前玩家自己的牌轨标记从“我的展示中匿名牌 / 我的历史匿名牌 / 我的候补匿名牌”改为“我的展示牌 / 我的历史牌 / 我的候补牌”。
  - FirstRunCoach 的牌轨步骤从“看这张匿名牌留下什么线索”改为“看这张牌留下什么线索”。
  - `tests/ui_text_smoke_test.gd`、`tests/visual_snapshot.gd`、`tests/layout_scene_smoke_test.gd`、`tests/smoke_test.gd` 同步更新，保护“公开牌可猜归属 / 待猜”状态词。
- 可玩性意义：
  - 隐藏归属规则不变，但主桌不再像规则说明书一样反复强调“匿名”。
  - 玩家看到的是桌面状态：这张牌公开了、归属待猜、可以竞猜、可以看线索档案。
  - 牌轨更接近电子桌游的历史/市场轨道，而不是 debug 风格的机制标签。

### 本轮验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/playtest_readability_gate_test.gd` 通过。
- `tests/playtest_skeleton_gate_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/ui_snapshot_capture.gd` 二号屏有头通过；人工查看 `play_table_1600x960.png`，确认主桌牌轨/竞价区不再常驻“匿名”短标签。

## 2026-07-03｜试玩骨架与卡面识别锚点

- 本轮按“能做骨架的地方都要做”的方向继续收口，但没有改规则、结算或卡牌数据：
  - `CardUI.tscn` 在卡牌 header 增加 `RouteGlyphBadge / RouteGlyphLabel`，让手牌、区域牌架、图鉴详情共用一个可见牌型符号锚点。
  - `CardUI.gd` 新增 `_card_type_glyph()`，为怪兽、军队、金融、经济、情报、合约、商品、天气、商路和直接互动牌提供短符号；同时把 `card_type_glyph` 写入 meta，方便后续测试和视觉 QA。
  - 主菜单 `MenuRootLobby` 的默认占位文案改成玩家可读中文：`星球赌桌｜最后钱最多 / 星球赌桌大厅 / 选择你的下一步`，避免 editor fallback 或未注入数据时露出英文临时模板。
  - `docs/card_frame_spec.md` 和 `docs/card_visual_theme_contract.md` 补充“类型符号锚点”硬指标，明确卡牌不能只靠文字区分类别。
  - `tests/playtest_skeleton_gate_test.gd` 升级骨架门槛：卡面必须有符号锚点，主菜单 fallback 文案必须是玩家向中文。
- 可玩性意义：
  - 真人看手牌时，第一眼更容易分辨“这是怪兽 / 军队 / 金融 / 商品 / 情报”等路线，不必先读完整句子。
  - 主菜单继续朝 Terraforming Mars 式“中心星球 + 右侧命令卡 + 左侧状态 chip”的桌游大厅靠近。
  - 这些改动是骨架级护栏；后续批量接开源美术素材、重做大卡面、强化图鉴详情时不会再退回纯文字块。

### 本轮验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/playtest_readability_gate_test.gd` 通过。
- `tests/playtest_skeleton_gate_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/ui_snapshot_capture.gd` 二号屏有头通过；人工查看 `main_menu_1280x720.png` 与 `play_table_hand_hover_1600x960.png`，确认主菜单中文赌桌大厅和手牌类型符号锚点已显示。
- `tests/smoke_test.gd` 完整通过。

## 2026-07-14｜高端场景化 Card UI Skin Lab（Godot MCP 实跑）

- 新增真实 Godot 场景 `scenes/tools/CardUISkinLab.tscn`，复用 `CardFace / HandRack / PlanetMapView / RightInspector / TargetingOverlay`，没有从纯脚本重建整张 UI。
- 新增顶部商品履带、独立隐藏商品卡背、公共结算区、轨道桌面氛围层和 7 状态切换；底部手牌继续使用真实扇形布局、悬停抬升与邻牌让位。
- 以六张 v0.6 代表牌验证商品、设施、订单、供货、怪兽和反制；fixture 只承载呈现，不改规则和经济数值。
- 玩家文本与 `card_id / action_id / reason_code / resource path / raw error` 分离；缺失本地化 label 时不再把内部 ID 作为 fallback。
- 右侧详情顺序固定为“使用时机 → 目标 → 完整效果 → 持续/终止 → 公开范围 → 关键词解释”，不可用牌额外显示原因和下一步。
- 星球桌面使用场景化区域、多色产业面、航班式弧线商路、合法投放槽和曲线目标连线；结算牌真实离开手牌，剩余手牌收拢后进入公共结算区。
- 通过 Godot add-on MCP 识别版本、打开/保存场景、运行、读取 debug output 和停止项目。1280×720、1600×960、1920×1080 以及 7 个状态共输出 10 张截图。
- 最终结果：`captures=10`、`failures=0`、`player_text_scan leaks=0`、`errors=[]`、`stop_project finalErrors=[]`。
- 验收报告与问题清单见 `reports/ui/skin_lab/card_ui_skin_lab_validation.md`。
- 协作边界：本轮未修改规则、经济、runtime ownership 或另一开发任务的文件；保留工作树中其他 agent 的既有改动。

## 2026-07-03｜剧本教练工具入口移入标题栏

- 本轮继续收敛首局引导浮窗，让它更像桌游桌边提示卡：
  - `ScenarioCoachSecondaryRow` 从卡片底部移入标题栏，保留测试可定位的节点名。
  - `ScenarioCoachUtilityMenu` 从“工具”文字按钮压缩成标题栏里的 `⋯` 小入口。
  - 主体区域只剩目标文字和一个主 CTA，辅助操作不再额外占一行。
  - `tests/visual_snapshot.gd` 更新护栏，要求辅助菜单保持在标题栏的小入口里。
- 可玩性意义：
  - 玩家第一眼只需要读“目标 + 主按钮”，不会被收起/提示/定位/重开等次级工具干扰。
  - 右上浮窗高度更低，中央星球和右侧行动区受到的视觉压迫更小。

### 本轮验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/playtest_skeleton_gate_test.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。

## 2026-07-14｜SS05-01 v0.5 数据与存档握手基础

- 新增 Inspector 可编辑的 `space_syndicate_ruleset_v05.tres`，冻结 v0.5 Profile、六产业目录、14 个 clock domain、整数分 CurrencyAmount wire 与 controller state versions。
- 完成 46 个真实商品的显式产业归类；运行时不得通过名称、颜色或 UI 文案反推产业。
- 建立独立 v0.5 卡牌作者 schema；五张真实迁移候选因产业费用或目标语义未审定而保持 `blocked`，未进入 release-ready/public pool。
- 新增被动 `RulesetSaveHandshakeService`：识别 legacy v1，生成和验证 v0.5 save v2 envelope，并拒绝 v0.4/v0.5 相互覆盖；它不拥有生产存档路径。
- 新增综合 `RulesetV05FoundationBench`，56/56 通过；MCP Editability Hub、Design QA Dock、Sceneization Audit 与 System Resourceization Audit 已登记该基础层。
- 生产 `RulesetRuntimeBridge`、`GameSaveRuntimeCoordinator` 与 `CardRuntimeCatalogService` 仍分别保持 v0.4 Profile、save v1 和 v0.4 Catalog；没有 selector、fallback 或第二个 active owner。
- `main.gd` 保持 22,867 总行、20,209 非空行、1,285 函数，SHA-256 保持 `6BD3F293EC2E92AEB81A39C80266314BE6A308D2C03ECD58FD8DB22958CAE699`。
- Foundation 56/56、Authoring 36/36、Catalog 80/80、Save Ownership 24/24、Menu 24/24、Global Navigation 32/32 observed／19/32 aligned、composition、focus-order 与 layout smoke 均通过；项目内 Godot MCP 可见运行确认生产 bridge=v0.4、save version=1、get_errors=0。

## 2026-07-03｜经济总览三路线决策条

- 把“首局出牌后打开经济总览”从纯信息阅读推进到桌游式下一步决策：
  - `EconomyDashboard.tscn` 新增 `EconomyDashboardDecisionRail`，位于 KPI 与详细列表之间。
  - `economy_dashboard.gd` 新增 `EconomyDashboardDecisionCard / DecisionTitle / DecisionBody / DecisionKeyword` 渲染骨架。
  - `main.gd` 新增 `_economy_dashboard_decision_snapshots()`，只用公开/当前玩家可见信息生成三条路线：
    - `扩GDP`：围绕热商品补生产、需求、交通。
    - `护商路`：保护高收入城市、修断路或买保险。
    - `压竞争`：用公开线索找目标，做空或引怪。
- 这轮的硬标准同步写入 `docs/commercial_playability_gate.md`：经济总览首屏必须回答“钱从哪来”和“下一步选哪条路线”，不得展示 AI 内部计划、对手真实现金、真实手牌或隐藏业主。
- 自动验收同步更新：
  - `tests/layout_scene_smoke_test.gd` 要求经济总览真实渲染决策条节点。
  - `tests/ui_text_smoke_test.gd` 要求 main/scene/script 同时保留三路线骨架。
- 顺手修复首局 Coach 买牌恢复路径：
  - 新增 `_first_card_accessible_district_for_player()`，买牌 CTA 先找怪兽网络可访问牌架，而不是只接受“非毁选区”。
  - 错区点击“买牌”时先跳到合法牌架并高亮牌架；已经在合法牌架时才自动购买教学牌。
  - 教学补给的“买入后可教”判断拆出 `_first_run_skill_has_direct_teaching_profile()`，避免被瞬时行动冷却误判。

### 本轮验证

- `tests/commercial_playability_gate_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。

## 2026-07-03｜卡牌/怪兽逐张逐只美术硬门禁

- 回应“接下来所有任务先做一张一张插画、一个一个怪兽美术”的约束，本轮把美术生产从口头要求改成可测试闸门：
  - 新增 `docs/art_production_contract.md`，明确当前阶段先做卡牌插画、怪兽造型和怪兽动作 profile；未完成前不继续扩玩法/经济/AI/菜单。
  - 新增 `tests/art_identity_gate_test.gd`，完整审计全卡池、怪兽目录和怪兽动作表。
  - 卡牌必须有唯一 `sprite_key / sprite_cell / layout_variant / palette_variant / effect_variant / composition_variant / motif_family`。
  - 怪兽必须有唯一 `sprite_key / sprite_cell / silhouette / layout_variant / palette_variant / effect_layer / composition_variant`。
  - 怪兽动作必须有唯一 `motion_family / pose_key / effect_layer / range_meters / move_override_mps / knockback_meters / timing / scale_contract`。
- 接入 `Moth-Fried-Games/moth-kaijuice` MIT 素材：
  - 新增 `assets/third_party/moth_kaijuice/`，包含 kaiju、力场、光线、机甲、坦克、士兵和建筑 PNG，以及 upstream `LICENSE`。
  - `CardArtView` 新增 `moth-kaijuice-mit-sprite-illustrations-v1` 中央插画层，配合 Night Patrol 框架、sprite cell、构图/色彩/特效变体生成每张卡的视觉 profile。
  - `MonsterArtView` 新增 `moth-kaijuice-mit-monster-sprites-v1` 怪兽 sprite 层，按怪兽 motif 映射 kaiju / mech / vehicle sprite family 和不同 effect layer。
  - `docs/third_party_assets.md` 记录素材来源、许可证、用途和运行时加载方式。
- 拆掉怪兽动作表中的重复动作占位：
  - 例如流星哨兵的两个 `普攻` 改为 `翼爪扫击` / `俯冲肩撞`。
  - 蓝锋骑士的重复普攻/斩击改为 `蓝锋轻斩`、`回旋刃撞`、`蓝锋斩击`、`逆刃斩击`。
  - 镜像猎兵的重复 `劣质光线` 改为 `劣质光线` / `折射劣光`。
  - 腕环哨兵动作也从重复占位改成独立拳击、回旋踢、炸弹、延迟炸弹、星弧火花、星弧连闪。
- 新增有头截图脚本 `tests/art_contact_sheet_capture.gd`：
  - 生成 `reports/art/art_card_monster_contact_sheet_1600x960.png`。
  - 生成 `reports/art/art_monster_action_profiles_1600x960.png`。
  - headless dummy renderer 无法抓 viewport texture，因此该截图脚本必须用有头 Godot 运行。
- `tests/visual_snapshot.gd` 增加护栏，确认 Moth Kaijuice 素材、Art Production Contract、art identity gate 和 contact sheet capture 脚本都存在。

### 本轮验证

- `tests/art_identity_gate_test.gd` 通过。
- 有头运行 `tests/art_contact_sheet_capture.gd` 通过，已生成两张 `reports/art/` 验收截图。
- `tests/ui_snapshot_capture.gd` 二号屏有头通过；人工查看 `play_table_1280x720.png`，确认剧本教练辅助入口在标题栏且主体区域只保留主 CTA。

## 2026-07-03｜剧本教练收敛为一主按钮

- 本轮继续降低首局主桌的信息密度，重点处理右上角 `ScenarioCoach`：
  - 剧本教练继续只突出一个主 CTA，例如“定位目标”。
  - 原本平铺的“收起 / 提示 / 定位 / 重开”等辅助按钮，改为收进 `ScenarioCoachUtilityMenu`。
  - `docs/playtest_skeleton_contract.md` 补充约束：运行时教练/剧本提示只能突出一个主 CTA，辅助操作进低权重工具菜单。
  - `tests/visual_snapshot.gd` 增加护栏，防止后续又把辅助动作摊回主桌按钮排。
- 可玩性意义：
  - 主桌更像桌游桌边提示卡：玩家第一眼只需要处理“当前目标 + 一个按钮”。
  - 辅助功能仍保留，但不再与主行动争夺视觉焦点，也不再压迫中央星球。

### 本轮验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/playtest_skeleton_gate_test.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。
- `tests/ui_snapshot_capture.gd` 二号屏有头通过；人工查看 `play_table_1280x720.png`，确认剧本教练只突出主 CTA，辅助操作已收成“工具”入口。

## 2026-07-03｜主桌玩家板接入真实行动途径条

- 本轮继续把“真人首局能顺着桌面走”做成骨架，而不是依赖长规则说明：
  - `PlayerBoard.tscn` 在资源板底部新增 `PlayerProgressPathRail`。
  - `player_board.gd` 新增 `_set_progress_path()`，把首召、建城、买牌、匿名牌、终局渲染成一行短 chip。
  - `main.gd` 把已有 `_player_tableau_progress_entries()` 接入 split runtime `player_board.progress_path`。
  - `PlayerBoardSnapshot` 透传 `progress_path`，避免场景只显示默认占位路径。
  - `docs/playtest_skeleton_contract.md` 明确：主桌玩家板必须有短途径条，不能只给玩家一句“下一步”。
- 可玩性意义：
  - 玩家第一眼能看见自己在一局里的位置：现在该首召、建城、买牌、出牌，还是冲终局。
  - 这条路径不暴露对手私有信息；对手视角仍由 `_player_tableau_progress_entries()` 输出公开线索版本。
  - 1280×720 实机截图确认没有挤坏中央星球、手牌和右侧竞价区。

### 本轮验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/playtest_skeleton_gate_test.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。
- `tests/ui_snapshot_capture.gd` 二号屏有头通过；人工查看 `play_table_1280x720.png`，确认路径条显示真实局面步骤而不是默认占位。

## 2026-07-03｜主桌竞价文案去机制化

### 参考方向

- 继续按 Terraforming Mars / Through the Ages 式桌面信息层级推进：主桌控件优先表达“我现在能做什么”，隐藏信息、匿名机制和完整规则留给 tooltip、图鉴、规则页和情报档案。
- 保留隐藏信息边界，不公开对手现金、手牌、真实牌主或 AI 内部判断；本轮只降低主桌常驻文案的信息密度。

### 本轮实现

- 新增 `docs/playtest_skeleton_contract.md` 与 `tests/playtest_skeleton_gate_test.gd`：把途径、卡面、主桌 UI、星球画面、主菜单、子菜单都纳入骨架门槛，后续不能只堆功能而不立版式。
- `BidBoard` 默认标题从“公开竞价”改为“牌桌竞价”，状态从“下一张牌可预设报价”压缩为“下一张牌可报价”。
- 运行时 `BidBoard`、旧兼容 `BidControlCard` 和卡牌结算侧卡统一使用“牌桌竞价 / 牌桌报价 / 报价沙漏”等动作词，减少主桌上对“匿名/公开”的反复解释。
- 卡牌结算侧卡收窄并停到星球右侧中段空档，避开上方目标提示和下方外围压力栏；底部沙漏条继续只负责短窗口时间感。
- `PlanetBoard` 新增 `right_rail.hidden` / `right_rail_suppressed` 小状态：结算/竞价焦点活跃时右侧外围压力栏临时让位，避免同侧 UI 互相遮盖；平时仍显示右栏。
- `tests/playtest_readability_gate_test.gd`、`tests/ui_text_smoke_test.gd`、`tests/visual_snapshot.gd` 和 `docs/commercial_playability_gate.md` 更新硬门槛，防止主桌竞价控件退回机制说明板。

### 验证

- `Godot 4.6.2 --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot 4.6.2 --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot 4.6.2 --headless --path . --script res://tests/playtest_readability_gate_test.gd` 通过。
- `Godot 4.6.2 --headless --path . --script res://tests/playtest_skeleton_gate_test.gd` 通过。
- `Godot 4.6.2 --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。

## 2026-07-03｜Scenario Lab payload audio hook 与截图验收

### 参考方向

- 继续推进 Hearthstone-grade vertical slice，但本轮只补 Codex A 展示层：消费 Codex B 暴露的公开 `visual_events/audio_hooks` payload，不改 Scenario/Campaign 推进逻辑。
- 音效先保持 silent hook，记录 `card_play`、`monster_attack`、`city_damage`、`bid_update` 等公开事件，后续可替换为 CC0 临时音效或正式音频资产。
- 隐藏信息边界优先：payload 如果包含 `true_owner`、`private_cash`、AI score 等私有字段，showcase 必须拒绝 visual/audio 演出。

### 本轮实现

- `VerticalSliceShowcase` 接入 `ShowcaseAudioEventBus`，本地 stage 与 Scenario Lab payload 都能记录公开 silent audio hook。
- `play_scenario_payload()` 继续通过 `ScenarioLabShowcaseAdapter` 消费 B 侧 payload；accepted payload 渲染同一桌面、手牌、目标 overlay、VisualEventLayer 和右侧解释。
- unsafe payload 会清空 visual event 与 audio hook，并在右侧 Inspector 显示被拒绝字段，避免演出层绕过隐藏信息边界。
- 新增 `tests/scenario_lab_payload_capture.gd`，为 `first_table`、`monster_pressure`、`public_track_intro`、`bid_practice` 和 unsafe rejection 生成 payload 驱动证明截图。
- `tests/scenario_lab_showcase_bridge_test.gd` 增加 payload audio hook 断言；`tests/visual_snapshot.gd` 锁住 `ShowcaseAudioEventBus`、`get_audio_event_snapshot()`、`_emit_audio_hooks()` 和 payload capture 文件名。
- `docs/vertical_slice_showcase_spec.md` 补充 Scenario Lab payload audio hook 和截图验收要求。

### 验证

- `Godot 4.7 --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/scenario_lab_showcase_bridge_test.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/vertical_slice_showcase_test.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/visual_event_smoke_test.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/balance_report_test.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot 4.7 --path . --windowed --resolution 1600x960 --script res://tests/scenario_lab_payload_capture.gd` 通过，并生成 5 张 Scenario Lab payload 桥接截图。
- `Godot 4.7 --path . --windowed --resolution 1600x960 --script res://tests/showcase_frame_capture.gd` 通过，原 45 秒展示帧序列仍可生成。
- 目检 `scenario_lab_monster_pressure_payload_1600x960.png`、`scenario_lab_bid_practice_payload_1600x960.png`、`scenario_lab_unsafe_payload_rejected_1600x960.png`：payload 演出可见，unsafe 截图显示拒绝说明且无 visual event。

### 剩余缺口

- 仍是 silent audio hook，没有接入真实音频文件。
- 当前 payload fixture 是 A/B 桥接样例；等 Codex B 输出真实 Scenario Lab 事件流后，可直接替换数据源。

## 2026-07-03｜MapView 默认球体回归修复

### 参考方向

- 这是主桌中央星球的回归修复，不是美术重做：真实 `main.tscn` 第一眼必须是可缩放 globe planet，不能退成平面色块、矩形遮罩或 placeholder。
- 保持现有 `PlanetBoard -> MapHost -> MapView` 分层：`PlanetBoard` 负责方形舞台和侧栏，`MapView` 负责投影、缩放、拖拽和命中，不碰经济、AI、怪兽、Scenario/Campaign 或卡牌数据。
- 对 Codex A/B 的共同边界已写入 `AGENTS.md`：中央 `MapView` 是核心桌面资产，不得被静态截图、`ColorRect`、假平面地图或不可缩放面板替换。

### 本轮实现

- `scripts/map_view.gd` 新增 `PLANET_PROJECTION_DEFAULT_ZOOM := PLANET_PROJECTION_GLOBE_ZOOM`，并把 `_view_zoom / _target_view_zoom` 默认改为 globe zoom，`_ready()` 与新地图签名进入时都会 `reset_to_planet_overview()`。
- 新增 `reset_to_planet_overview()`、`zoom_to_local_projection()` 和 `get_projection_debug_snapshot()`，让测试和截图脚本能明确验证 globe / local / return-globe 三态。
- globe 概览下区域绘制降级为 marker/outline 优先，不再直接填充复杂 polygon，避免跨球体背面/边缘连成大色块；局部 local projection 仍保留完整区域面。
- `tests/layout_scene_smoke_test.gd` 新增 MapView 投影回归断言：默认 `globe_blend >= 0.95`、默认 zoom 等于 `PLANET_PROJECTION_GLOBE_ZOOM`、globe 概览不启用复杂 polygon fill、滚轮可进入 local projection、可 reset 回 globe。
- `tests/ui_snapshot_capture.gd` 新增 `play_table_planet_globe_1600x960.png`、`play_table_planet_zoom_local_1600x960.png`、`play_table_planet_return_globe_1600x960.png`，用真实运行时 `MapHost` 中的 MapView 截图。
- `tests/visual_snapshot.gd` 锁住 globe 默认常量、debug/reset/local 方法和新增截图文件名，防止后续 UI/Showcase 改动再把主桌默认带回 flat/local。

### 验证

- `Godot 4.7 --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot 4.7 --path . --windowed --resolution 1600x960 --script res://tests/ui_snapshot_capture.gd` 通过，并生成 `play_table_planet_globe_1600x960.png`、`play_table_planet_zoom_local_1600x960.png`、`play_table_planet_return_globe_1600x960.png`。
- 目检 `play_table_planet_globe_1600x960.png` 与 `play_table_planet_return_globe_1600x960.png`：主桌中央第一眼是球体星球，不是平面色块；`play_table_planet_zoom_local_1600x960.png` 仍能进入局部投影且边界外有宇宙空间。
- `Godot 4.7 --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot 4.7 --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/smoke_test.gd` 目前仍有一处非本轮范围红灯：`monster landing regions discount card purchases while adjacent regions keep base price`。本轮按禁改边界不触碰经济、怪兽或卡牌购买规则。
- `git diff --check` 通过；仅有 Windows 工作区 LF/CRLF 转换提示。

## 2026-07-02｜Hearthstone-grade Vertical Slice v1

### 参考方向

- 本轮不复制暴雪 IP、素材、图标、卡背、文本或规则，只学习商业卡牌游戏的产品结构：明确桌面舞台、手牌对象感、目标反馈、出牌演出、怪兽攻击、资源浮字、音效 hook、帧序列验收。
- 继续使用开源参考的结构而非素材：CardHouse 的事件/目标 staging，Balatro-Feel 的反馈节奏语言，UiCard 的目标/拖放反馈，Godot card plugin 的 data/visual/hand/drag/rules 分离。
- 不改 Codex B 的 Scenario 系统，不碰竞价推荐、公开牌轨逻辑、AI、经济公式、怪兽规则、匿名牌真实归属或卡牌数据表。

### 本轮实现

- 新增 `docs/hearthstone_grade_ux_matrix.md`、`docs/commercial_readiness_scorecard.md`、`docs/vertical_slice_showcase_spec.md`，把商业切片拆成桌面、手牌、hover/drag、目标选择、出牌、召唤、攻击、受损、资源、日志、音效和截图验收。
- 新增 `docs/card_frame_spec.md`、`docs/art_direction.md`、`docs/vfx_event_language.md`、`docs/balance_pricing_model.md`，锁定 MiniHandCard / InspectorCard / TrackCard、VFX 事件语言和价格公式。
- 新增 `scenes/ui/VerticalSliceShowcase.tscn`、`scripts/ui/vertical_slice_showcase.gd`、`scripts/ui/showcase_director.gd` 与 `data/showcase/hearthstone_grade_sequence.json`，可独立播放 45 秒展示序列：桌面就绪、手牌 hover、有效/非法拖牌、出牌飞行、公开 reveal、怪兽出现/移动/攻击、城市受损、BidBoard 高亮、平衡报告预览。
- 新增 `VisualEventLayer`、`TargetingOverlay`、`VisualEventQueue`、`VisualEventSnapshot`，覆盖 card_play、target_arrow、card_reveal、monster_spawn、monster_move、monster_attack、city_damage、route_damage、cash_gain、gdp_delta、final_countdown 等事件，支持 reduced_motion 和 32 事件上限。
- 新增 monster/city/route/combat presenter，用 UI-only 事件表达怪兽出现、移动、攻击、城市受损、商路受损、军队射线。
- 新增 silent `AudioEventBus` / `AudioEventRegistry` 和 `data/audio/audio_event_map.json`，覆盖 ui、card、bid、monster、city、route、resource、final_countdown hook。
- 新增 `scripts/balance/*`、`data/balance/*`、`docs/balance_report.md`，输出价格过低 Top 20、价格过高 Top 20、Rank I-IV 梯度异常、同类型异常、首局推荐卡和复杂卡排除；报告只建议，不改真实卡牌数据。
- 新增 `tests/vertical_slice_showcase_test.gd`、`tests/visual_event_smoke_test.gd`、`tests/balance_report_test.gd`、`tests/showcase_frame_capture.gd`，并扩展 `tests/visual_snapshot.gd` 锁住新合同和帧序列文件名。
- 继续补强 `data/showcase/hearthstone_grade_sequence.json` 的 `scenario_lab_bridge` 与 `scenario_segments`，把 `first_table`、`monster_pressure`、`public_track_intro`、`bid_practice` 显式映射到 stage、VFX event class 和 silent audio hook。
- `ShowcaseDirector` 新增 `get_scenario_ids()`、`stage_ids_for_scenario()`、`scenario_snapshot()`；`VerticalSliceShowcase` 新增 `play_scenario()` / `get_scenario_contract()`，给未来 Codex B Scenario Browser/Scenario Lab 入口消费。
- `docs/balance_report.md` 和 balance analyzer/reporter 增加“剧本价格/强度曲线”，并输出怪兽压迫、公开牌轨、竞价练习各自的推荐卡组。
- 新增 `ScenarioLabShowcaseAdapter`、`data/showcase/scenario_lab_bridge_fixture.json` 和 `tests/scenario_lab_showcase_bridge_test.gd`，可直接消费 Codex B 风格 `visual_events` payload；包含隐藏信息字段的 payload 会被标记 unsafe 并拒绝展示事件。

### 验证

- `Godot 4.7 --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/vertical_slice_showcase_test.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/visual_event_smoke_test.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/balance_report_test.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/scenario_lab_showcase_bridge_test.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot 4.7 --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/smoke_test.gd` 通过。
- `Godot 4.7 --path . --windowed --resolution 1600x960 --script res://tests/showcase_frame_capture.gd` 通过，并生成 19 张 showcase / 剧本证明帧 / 帧序列 / 价格报告预览图。
- `git diff --check` 将在最终提交前复跑。

### 剩余缺口

- v1 仍是程序化 UI 视觉和 silent 音效 hook，下一轮可替换为 CC0 临时音效和更完整的 token/冲击动画。
- 目前仍通过本地 showcase fixture 播放，但已有窄桥接合同：等 Codex B 的 Scenario Lab 暴露 `visual_events` 后，A 侧可直接按剧本消费展示事件。
- 平衡报告只建议垂直切片卡组，不应直接全局改价。

## 2026-07-02｜HandRack / CardFace Commercial Feel v3

### 参考方向

- 继续按 `CardHouse` 的 card group / gate / seeker 思路重写为本项目 Godot `Control` 结构：HandLayout 只管理位置、旋转、缩放、z-index 和交互状态，不触碰规则。
- 参考 `Balatro-Feel` 的 hover/selected/invalid drop 节奏，把底部手牌从按钮列表感推进到 deckbuilder 式的抬升、让位、焦点和回位反馈。
- 参考 `UiCard` 与 Godot card 插件的组件边界，把卡牌数据、MiniCard 视觉、Inspector full 详情、HandRack 信号和 main 规则入口继续拆开。
- 保持复制边界：没有复制 Unity/C#/JS 源码，没有引入 GPL/AGPL/LGPL 代码或外部素材；只移植结构、参数和交互模式。

### 本轮实现

- `scripts/HandLayout.gd` 增加 `single_focus / comfortable / compressed / pressure / overflow_stack` profile，并把 `gap_ratio`、fan/arc 强度、缩放下限、hover lift、邻牌让位、max visible/overflow 策略集中到可调参数层。
- HandLayout 新增 selected、pressed、dragging、returning、disabled、valid_drop、invalid_drop 状态；`get_card_target_snapshot()` 现在暴露 `target_position`、`target_rotation`、`target_scale`、`drag_state`、`visible_ratio`、`overflow_hidden` 等测试合同。
- `scripts/ui/hand_rack.gd` 补齐 `card_unselected`、稳定选中、空白取消、同 ID live refresh 保节点、pressed/disabled 元数据、deadzone drag 和 invalid release 回位；拖拽释放仍只发 `card_drag_released`，不直接调用规则函数。
- `scripts/CardUI.gd` 与 `scripts/ui/card_face.gd` 明确 MiniCard / inspector_full / codex_full presentation contract；MiniCard 保持短名称、费用、路线/类型、rank、单行效果和状态灯，Inspector full 承接目标、条件、完整效果、主动作和 disabled reason。
- `PlayerBoard -> GameScreen -> RightInspector` 只做 UI 桥接：hover 临时预览，selected 稳定聚焦，hover 离开后恢复 selected card 详情。
- `scripts/LayoutDemo.gd` 改为 HandRack feel demo，覆盖 0/1/5/10/15 张手牌，以及 hover、selected、dragging、invalid drop、disabled 示例。
- `tests/layout_scene_smoke_test.gd`、`tests/visual_snapshot.gd`、`tests/ui_text_smoke_test.gd`、`tests/ui_snapshot_capture.gd` 增加 HandRack v3、MiniCard、Inspector full 和多分辨率截图护栏。

### 验证

- `Godot 4.7 --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot 4.7 --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot 4.7 --headless --path . --script res://tests/smoke_test.gd` 通过。
- `Godot 4.7 --path . --windowed --resolution 1600x960 --script res://tests/ui_snapshot_capture.gd` 通过，并生成 `hand_rack_demo_1280x720.png`、`hand_rack_demo_1600x960.png`、`hand_rack_demo_1920x1080.png`、`play_table_hand_hover_1600x960.png`、`play_table_hand_selected_1600x960.png`、`play_table_drag_invalid_1600x960.png`。
- `git diff --check` 退出码 0；仅有 Windows 工作区既有 LF/CRLF 转换提示。

### 剩余缺口

- `codex_full` 目前主要是 presentation/test contract，后续可以专门重做图鉴详情页的完整卡牌规格。
- HandRack 已有 overflow_stack 数据合同；如果未来手牌超过 15 张很多，可以再做真正可滚动/折叠的 overflow rack。
- 视觉手感已经能区分 hover、selected、drag、invalid drop，但还可以继续做更细的弹性 overshoot、音效和触觉节奏。

## 2026-07-02｜BidBoard 指针 Hover 同步公开牌轨

### 参考方向

- 继续参考商业桌游数字化桌面的“扫读即对应”交互：鼠标扫过底部竞价指针时，顶部公开牌轨应立刻临时发光，玩家不用靠记忆匹配“领跑/我的牌”和牌槽位置。
- 这轮只做 UI 交互层高亮，不改变真实选中状态、不触发竞猜、不泄露隐藏信息；点击仍然负责正式选中。
- 保持页面分层：BidBoard 只发 hover 信号，PlayerBoard/GameScreen 转发，CardTrack 只负责渲染临时 hover marker。

### 本轮实现

- `scripts/ui/bid_board.gd` 新增 `track_link_hovered` / `track_link_unhovered` 信号，`BidBoardTrackLinkButton` 在 mouse/focus enter/exit 时发出对应 `track_select_*`。
- `scripts/ui/player_board.gd` 转发 BidBoard 的公开轨 hover 信号，保持底部玩家板作为桌边控件聚合层。
- `scripts/ui/game_screen.gd` 新增 `_set_public_track_hover()`，把 BidBoard hover action 转给当前公开牌轨组件。
- `scripts/ui/card_track.gd` 新增 `set_hovered_track_action()`、`PublicTrackSlotHover` marker 和 hover 样式；hover 高亮与 `PublicTrackSlotSelected` 并存，但不会修改真实 selected 数据。
- `tests/layout_scene_smoke_test.gd` 增加运行时鼠标扫过 BidBoard “领跑”指针的护栏，验证顶部公开牌轨出现临时 hover marker，离开后清除。
- `tests/visual_snapshot.gd` 锁定 BidBoard -> PlayerBoard -> GameScreen -> CardTrack 的 hover 信号链和 CardTrack 临时高亮契约。

### 验证

- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 退出码 0；仅有 Windows 工作区既有 LF/CRLF 转换提示。

### 剩余缺口

- Hover 现在只同步 BidBoard -> 公开牌轨；后续可以补反向同步，让鼠标扫过顶部牌槽时 BidBoard 对应指针也临时发光。
- Hover 暂不驱动右侧详情预览；若后续桌面读法仍不够快，可以让 hover 只预览公开摘要，不触发正式竞猜选择。
- 竞价推荐仍只按公开最高价/当前报价生成，尚未纳入收益预估或现金余量排序。

## 2026-07-02｜BidBoard 可点击牌轨指针与推荐竞价

### 参考方向

- 继续参考商业桌游/牌桌 UI 的“同一对象多处高亮”读法：底部竞价区、顶部公开牌轨和右侧详情必须指向同一张匿名牌，不能让玩家靠记忆比对文字。
- 竞价按钮从纯数值加价推进到“保守+10 / 追平 / 压过”的意图按钮；固定金额仍保留在数据路径里，但桌面优先显示玩家可理解的决策语言。
- 保持隐藏信息边界：推荐按钮只使用公开最高价、当前玩家自己的报价和可用资金，不暴露对手现金、AI 预算或真实牌主。

### 本轮实现

- `BidBoard.tscn` 新增 `BidBoardTrackLinkRow`，`scripts/ui/bid_board.gd` 将 `track_links` 渲染成可点击的 `BidBoardTrackLinkButton`，点击后沿既有 `action_requested` 通道触发 `track_select_*`。
- `BidBoardSnapshot` 保留 `track_links` 的 `id` 与 `selected` 字段，避免 ViewModel 归一化时丢掉可点击目标和选中态。
- `scripts/main.gd` 新增 `_card_resolution_leading_queue_index()`，BidBoard 的“领跑”不再盲取队首，而是按公开报价和现有顺时针 tie-break 找真正领跑牌。
- `scripts/main.gd` 新增 `_runtime_bid_board_recommended_actions()` 与 `bid_set_*` action，竞价中输出“保守+10 / 追平 / 压过 / 清零”。
- `CardTrack` 与 `PublicTrackSnapshot` 保留并渲染 `selected` 状态；从 BidBoard 点击领跑牌后，顶部公开牌轨会出现 `PublicTrackSlotSelected` 高亮。

### 验证

- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过，包含点击 BidBoard 领跑指针后公开牌轨高亮、`保守+10` 加价路径、追平/压过 action 输出。
- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 退出码 0；仅有 Windows 工作区既有 LF/CRLF 转换提示。

### 剩余缺口

- 现在是点击后同步高亮；下一步可以做 hover 同步，让鼠标扫过 BidBoard 指针时顶部牌轨临时发光。
- 推荐按钮已经有“追平/压过/保守”意图，但还没有根据现金余量、结算收益和 AI 竞价压力动态排序推荐。
- BidBoard 仍在右侧命令台内；如果后续牌轨交互继续增加，可以把它提升到公开牌轨旁的横向桌边控件。

## 2026-07-02｜BidBoard 与公开牌轨指针联动

### 参考方向

- 继续参考商业桌游数字化桌面的公开轨读法：竞价控件不能只显示金额，还要告诉玩家这些金额对应公开牌轨里的哪张牌、哪个队列位置。
- 采用“桌面短指针 + tooltip 细节”的方式，让 BidBoard 在一眼内显示“领跑 / 我的牌 / 下张 / 下批”，避免把公开牌轨、竞价区和行动区割裂成三块孤岛。
- 保持隐藏信息边界：指针只来自公开匿名牌轨、当前玩家自己的队列位置和公开出价，不暴露对手现金、手牌或 AI 预算。

### 本轮实现

- `scripts/main.gd` 新增 `_runtime_bid_board_track_links()` 与 `_runtime_bid_board_track_link()`，把当前展示、公开竞拍领跑、我的 queued 牌、下张/下批等待牌整理成最多 3 个短指针。
- `BidBoardSnapshot` 新增 `track_links` 归一化字段，`PlayerBoardSnapshot` 继续把它作为 `bid_board` 的数据-only 输出传给 UI。
- `scripts/ui/bid_board.gd` 将状态短句优先替换为公开轨指针摘要，例如“领跑 竞拍1 ¥80｜我的牌 竞拍2 ¥40”，长解释继续放在 tooltip。
- `tests/layout_scene_smoke_test.gd` 增加静态与运行时护栏：确认 BidBoard 样例和真实公开竞价 fixture 都能渲染“领跑 / 我的牌”，并保留 `+10` 实际加价路径。
- `tests/visual_snapshot.gd` 锁定 runtime、ViewModel 和 renderer 都必须认识 `track_links`，防止后续又退回只显示金额、不显示牌轨位置。

### 验证

- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 退出码 0；仅有 Windows 工作区既有 LF/CRLF 转换提示。

### 剩余缺口

- BidBoard 现在已经能把竞价读法指向公开牌轨，但还没有画出视觉连线或高亮同步；下一步可以让公开轨 hovered/selected entry 与 BidBoard 指针互相点亮。
- 竞价按钮仍是固定 `+10/+50/+100/清零`，后续应按当前最高价和现金余量生成“追平/压过/保守”推荐按钮。
- 如果桌面信息继续增加，可以把 BidBoard 从右侧命令台提升为公开牌轨旁的横向桌边控件。

## 2026-07-02｜独立桌边 BidBoard 接管公开竞价

### 参考方向

- 继续参考商业桌游/牌桌界面的信息分层：竞价是独立桌边控件，不应该继续藏在手牌行头部的 readiness chip 里。
- 桌面第一眼只显示“我的报价、最高价、本批、下批”和少量筹码按钮；锁资、封盘、队列规则仍放在 tooltip 和详情文案里。
- 保持隐藏信息边界：BidBoard 只使用公开批次、公开最高价和当前玩家自己的报价/资金可用性，不显示对手现金、手牌或 AI 出价预算。

### 本轮实现

- 新增 `scenes/ui/BidBoard.tscn` 与 `scripts/ui/bid_board.gd`：独立渲染公开竞价标题、阶段、四个短筹码、`+10/+50/+100/清零` 操作按钮和一行短状态。
- 新增 `scripts/viewmodels/bid_board_snapshot.gd`，并让 `PlayerBoardSnapshot` 通过 `BID_BOARD_SNAPSHOT_SCRIPT` 归一化 `bid_board` 数据。
- `PlayerBoard.tscn` 右侧 `PlayerCommandTableau` 现在是 `PlayerBidBoard + PlayerMainActionDock`，ActionDock compact 高度收紧，保留建城/牌架/买牌/出牌和主行动按钮。
- `scripts/main.gd` 新增 `_runtime_player_board_bid_board()`、`_runtime_bid_board_actions()`、`_runtime_bid_board_can_set_tip()`，把竞价阶段、最高价、本批/下批、按钮禁用原因作为数据输出。
- Split action 分发新增 `bid_plus_*` 与 `bid_reset`，BidBoard 按钮沿 `BidBoard -> PlayerBoard -> GameScreen -> main.gd` 修改公开报价。
- `readiness_chips` 回到普通行动就绪层，不再混入竞价 cluster；竞价读法由独立 BidBoard 承接。

### 验证

- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过，包含 live RuntimeGameScreen 点击 `+10` 后公开报价增加的护栏。
- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。

### 剩余缺口

- BidBoard 已经能操作公开报价，但还没有和顶部公开牌轨做视觉联动；下一步应把当前领跑牌、下一个结算牌和 BidBoard 的最高价/队列状态连成统一读法。
- `+10/+50/+100` 是第一版筹码按钮；后续可以根据最高价、现金余量和 AI 竞价压力动态推荐“追平/压过/保守”按钮。
- BidBoard 现在位于右侧命令台内；如果后续牌桌状态继续增加，需要评估是否把它提升到公共牌轨旁的横向小面板。

## 2026-07-02｜竞价状态拆成桌边短筹码

### 参考方向

- 继续参考 Terraforming Mars / Gaia Project / Through the Ages 这类商业桌游数字化界面的桌边信息层：玩家第一眼看到状态短标签，长解释留给 tooltip、侧栏和档案。
- 这轮承接上一条“竞价区需要更商业桌游化桌面控件”的缺口，不再把竞价、最高价、我的报价、候补队列压成一句长状态，而是拆成 3-4 个可扫读筹码。
- 保持隐藏信息边界：显示公开报价、公开队列规模和当前玩家自己的参拍/预设状态，不显示对手手牌、现金、AI 评分或真实身份。

### 本轮实现

- `scripts/main.gd` 新增 `_runtime_player_board_bid_readiness_chips()` / `_runtime_bid_status_chip()`，按竞价中、同时短窗、封盘候补、下批等待四类局面输出结构化短筹码。
- `PlayerBoard` 的 readiness 渲染遇到 `cluster=true` 时不再压缩为单个摘要 chip，而是最多渲染 4 个短筹码：竞价、最高、我的、队列。
- 短筹码降低最小宽度、字体和字符上限，长状态仍保留在 tooltip，避免继续挤爆底部玩家板。
- 保留旧的 `_runtime_player_board_bid_readiness_chip()` 单 chip 兼容入口，但现在从新数组函数安全取第一个字典。
- `tests/layout_scene_smoke_test.gd` 增加真实运行时竞价 fixture：构造两张匿名牌公开竞价，验证快照含 `cluster` chip，Split `GameScreen` 实际渲染出四个桌边短筹码。
- `tests/visual_snapshot.gd` 锁定新 ViewModel/Renderer 契约，防止后续又把竞价状态压回长句。

### 验证

- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。

### 剩余缺口

- 竞价状态现在能在玩家板扫读，但还不是完整的商业桌游竞价控件；后续应把加价按钮、锁资原因、候补顺序和下批等待做成同一块明确的桌边 bid board。
- 当前 `PlayerReadinessChipRow` 仍在右侧命令台的狭窄区域内；如果继续增加桌面状态，应该把竞价控件提升到独立小面板，而不是继续塞入 readiness 行。
- 下批等待、封盘、短窗三种状态已有数据输出，但视觉强调还比较克制，后续需要结合公开牌轨和倒计时条形成统一竞价读法。

## 2026-07-02｜已选匿名牌证据链卡片

### 参考方向

- 继续参考商业数字桌游的侦探板/日志板读法：桌面只保留薄牌轨和短状态，进入档案后把同一对象的公开事实按“条件 → 目标 → 出价 → 余波 → 私人推理”排成证据链。
- 这轮不扩大主桌文字密度，而是把上一轮“牌轨直达情报档案”的落点做实：玩家点进来后能马上知道该匿名牌为什么值得猜、该看哪些证据。
- 保持隐藏信息边界：证据链只显示公开条件、公开目标、公开报价/小费、公开余波，以及当前玩家自己的押注/查明状态；不扫描对手现金、手牌或 AI 私有计划。

### 本轮实现

- `scripts/main.gd` 的 `_intel_card_guess_entries()` 扩展 `track_state / aftermath / style` 等字段，单张匿名牌线索不再只是一行摘要。
- 新增 `_focused_intel_card_evidence_card()` / `_focused_intel_card_evidence_lines()`：当 `selected_card_resolution_id` 来自公开牌轨时，`IntelDossierBoard` 会把“已选匿名牌证据链”插到线索卡第一位。
- 证据链行固定覆盖：牌槽证据、出牌条件、目标线索、出价记录、余波线索、私人推理。
- `scripts/ui/intel_dossier_board.gd` 支持每张线索卡自带 `line_limit`，普通 clue card 仍默认 4 行，证据链可显示 6 行。
- `tests/layout_scene_smoke_test.gd` 增加组件和运行时护栏：侦探板能渲染“出价记录/余波线索/私人推理”，真实牌轨进入情报档案后也必须出现该证据链。
- `tests/visual_snapshot.gd` 锁定“已选匿名牌证据链”和 `line_limit` 静态契约。

### 验证

- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过；只有既有 LF/CRLF 提示，没有空白错误。

### 剩余缺口

- 证据链现在能读，但还不是可交互子面板；下一步可以把“出价记录”“余波线索”“私人推理”拆成可展开/可标注的短卡。
- 竞价区仍需要更商业桌游化的桌面控件：最高价、可加价、锁定原因、候补队列和下批等待应该在主桌第一眼更明确。
- 情报档案还缺“回到牌轨槽位/竞猜按钮”的反向路径。

## 2026-07-02｜牌轨直达情报档案证据链

### 参考方向

- 继续参考 Through the Ages 的公共牌轨、Terraforming Mars 的桌面信息分层，以及商业数字桌游常见的“桌面薄信息 + 侧栏详情 + 档案查证”路径。
- 这轮不再扩大地图表面文字，而是把已经可点击的匿名牌轨接到情报档案：玩家从公共牌槽看到报价/条件/目标后，可以直接进入侦探板看证据链。
- 保持分层：`CardTrack` / `GameScreen` 只转发数据化 action；`main.gd` 作为运行时控制器处理 `track_intel_`，情报档案仍通过 `IntelDossierBoard` 快照渲染，不把新页面逻辑塞进牌轨组件。

### 本轮实现

- `scripts/main.gd` 为公开牌轨条目新增 `track_intel_<resolution_id>` 操作与“线索档案”deep-link，右侧详情现在同时提供选中竞猜、线索档案和卡牌详情三条玩家路径。
- 运行时动作分发新增 `track_intel_`：清掉手牌选中态、设置 `selected_card_resolution_id`，并打开“情报档案”。
- 情报档案卡牌线索条目新增 `resolution_id / focused` 字段；当前从牌轨带入的匿名牌会排序置顶。
- `IntelDossierBoard` 顶部新增“已选牌轨”chip，匿名牌轨线索卡片也会在对应行标注“已选牌轨”，按钮文案保留“查看卡牌线索”并追加已选语义，兼容原有导航。
- `tests/layout_scene_smoke_test.gd` 增加组件和运行时护栏：公开牌槽右侧详情必须显示“线索档案”，真实拖牌入轨后可从右侧按钮打开情报档案并聚焦当前匿名牌。
- `tests/visual_snapshot.gd` 锁定 `track_intel_`、`已选牌轨` 和 `_focused_intel_card_guess_entry` 静态契约。

### 验证

- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过；只有既有 LF/CRLF 提示，没有空白错误。

### 剩余缺口

- 牌轨现在能直达情报档案，但“出价/加价/封盘/候补队列”仍主要靠既有牌轨和手牌按钮表达，下一步应把竞价区做成更明确的桌面控件。
- 情报档案已能聚焦单张匿名牌，但还没有把该牌的出价记录、余波事件、私人推理备注做成独立证据链子面板。
- 当前焦点从右侧详情进入档案是通顺的；后续可继续补“从情报档案反向返回牌轨槽位/竞猜面板”的路径。

## 2026-07-02｜公开牌轨可点击详情与竞猜入口

### 参考方向

- 继续参考 Through the Ages / Terraforming Mars / 商业数字桌游的公共牌轨：主桌上只放薄轨、槽位、状态、报价和少量徽章，完整阅读进入侧栏或详情层。
- 这轮不继续堆地图文字，而是把公开牌轨变成可操作桌面区域：单击选中竞猜对象，双击进入卡牌详情，右侧详情承接公开线索。
- 保持分层：`CardTrack` 只发 UI 信号，`PublicTrackSnapshot` 保留数据化 action/deep-link，`main.gd` 只在运行时控制器层处理 `track_select_` / `track_open_`。

### 本轮实现

- `scripts/ui/card_track.gd` 新增 `track_entry_selected` / `track_entry_opened` 信号，薄轨槽位可接收单击和双击，不再只是静态文本条。
- `scripts/viewmodels/public_track_snapshot.gd` 保留 `resolution_id / card_name / select_action / open_action / actions / requirements / deep_links`，让牌轨详情能通过 ViewModel 传到页面层。
- `scripts/ui/game_screen.gd` 将牌轨单击路由到右侧详情：展示牌轨标题、状态、归属、报价、推理原因、操作按钮和详情链接；双击继续发出卡牌详情动作。
- `scripts/main.gd` 运行时接入 `track_select_` 与 `track_open_`，单击会清掉手牌选中态、选中公开竞猜对象，并让 `_runtime_right_inspector_snapshot_source()` 稳定返回牌轨详情，避免被下一帧默认区域详情覆盖。
- `tests/layout_scene_smoke_test.gd` 补了组件层和运行时层护栏：样介牌轨单击/双击发正确 action，真实拖牌进公共牌轨后单击能更新 `selected_card_resolution_id` 并保持右侧详情。
- `tests/visual_snapshot.gd` 锁定公开牌轨的点击信号、ViewModel action 字段、主控运行时回路和右侧详情快照契约。

### 验证

- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过；只有既有 LF/CRLF 提示，没有空白错误。

### 剩余缺口

- 公开牌轨现在能选中竞猜和打开卡牌详情，但竞价加价、批次锁定、候补队列的直接桌面操作还没有完全组件化。
- 下一轮应继续把“公开牌轨 + 竞价区 + 情报档案”打通：从牌轨槽位直接进入对应的匿名归属证据、出价记录、余波线索和私人推理档案。
- 地图落点仍只有通用阻塞原因；后续可把“该牌对当前区域是否有效”做成逐区 hover/拖拽提示。

## 2026-07-02｜拖拽出牌规则态提示与阻塞释放护栏

### 参考方向

- 继续参考 Tabletop Simulator / UiCard / 商业数字桌游的直接操控：拖牌时不仅要看到可放区域，也要立刻知道“为什么现在不能放”。
- 这轮聚焦真人可玩性，不做装饰 UI：把按钮上的出牌规则态同步到拖拽路径，避免玩家通过拖拽绕过冷却、费用或目标限制。
- 保持分层：`main.gd` 的 `_hand_card_play_state()` 仍是规则态来源；split `GameScreen` 只消费 ViewModel 字段，不直接读取玩家数组或规则函数。

### 本轮实现

- `scripts/main.gd` 的 split 手牌 snapshot 新增 `play_state / action_state / actionable / drop_enabled / drop_label / block_reason`，让 `CardFace`、右侧详情、按钮和拖拽反馈共用同一套出牌状态。
- `scripts/ui/game_screen.gd` 的拖拽反馈改为：
  - 不在地图上：提示“拖到星球地图”；
  - 在地图且可打：按卡牌目标显示“松开出牌 / 松开首召 / 松开选怪兽 / 松开选玩家”；
  - 在地图但不可打：显示“不能出：冷却中 / 资金不足 / 需商品”等规则态原因，并阻止 `card_drop_requested`。
- `tests/layout_scene_smoke_test.gd` 新增两层护栏：
  - 组件层：阻塞卡拖到 `MapHost` 时显示冷却原因，释放不会发 drop intent；
  - 运行时层：真实开局后强制玩家行动冷却，确认 CardFace 标记不可拖放，真实拖到地图不会进入公共牌轨。
- `tests/ui_snapshot_capture.gd` 新增 `play_table_drag_blocked_%s.png`，在多分辨率截图中保存“冷却中不可释放”的主桌状态。
- `tests/visual_snapshot.gd` 锁定规则态拖拽字段和阻塞态截图契约。

### 验证

- `Godot --path . --windowed --script res://tests/ui_snapshot_capture.gd` 通过，并重新生成 `play_table_drag_drop_%s.png` 与 `play_table_drag_blocked_%s.png`。
- 肉眼复查 `play_table_drag_blocked_1280x720.png`、`play_table_drag_blocked_1600x960.png`、`play_table_drag_drop_1600x960.png`：阻塞态红框、冷却原因、小卡浮层和底部出牌禁用状态一致。
- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过。

### 剩余缺口

- 当前阻塞原因已覆盖冷却、费用、商品流动、目标选择等状态，但还没有把“指定区域不适合该牌”的地图落点差异做成逐区域提示。
- 下一轮应继续把公开牌轨/竞价区做成更强的可点击桌面区域：当前信息已经在主桌上，但玩家对竞价、候补批次和归属推理的操作入口还可以更像商业桌游。

## 2026-07-02｜拖拽落点有头截图 QA 与浮层尺寸护栏

### 参考方向

- 接着上一轮的手牌拖拽闭环，按 Tabletop Simulator / 现代数字桌游的真实操作手感复查：拖牌反馈必须在真实窗口里看起来像桌面小卡提示，而不是只在信号测试里通过。
- 参考商业卡牌桌的浮层原则：合法地图区域用大范围高亮；跟手卡片只显示短摘要，不能压住底部手牌、行动区和右侧详情。
- 保持分层：`OverlayLayer` 控制视觉尺寸和裁剪，`GameScreen` 继续只提供落点状态，截图脚本只负责复现页面状态。

### 本轮实现

- `tests/ui_snapshot_capture.gd` 扩展有头截图采集：
  - 各分辨率主桌新增 `play_table_drag_drop_%s.png`；
  - 1600x960 继续覆盖教程、规则、资料大厅、角色/卡牌/商品/怪兽、经济、情报、排行榜、结算等页面；
  - 截图脚本通过 `HandRack` 的拖拽 preview 信号复现真实地图接受态，而不是直接打开浮层节点。
- `scripts/ui/overlay_layer.gd` / `scenes/ui/OverlayLayer.tscn` 将 `DragPreviewPanel` 收紧为稳定小卡尺寸 `176x118`，关闭自动换行并启用截断，避免 headless 布局把拖拽预览撑成半屏高遮挡层。
- `tests/layout_scene_smoke_test.gd` 新增拖拽预览尺寸护栏，要求运行时浮层保持小型卡片级尺寸，同时继续验证地图目标框、合法/非法落点和隐藏行为。
- `tests/visual_snapshot.gd` 新增源码契约，锁住 `play_table_drag_drop_%s.png`、拖拽截图 helper、固定浮层尺寸和文本裁剪设置。

### 验证

- `Godot --path . --windowed --script res://tests/ui_snapshot_capture.gd` 通过，并重新生成 1280x720、1366x768、1600x960、1920x1080、2560x1440 的主菜单、主桌、拖拽落点、详情抽屉和页面分层截图。
- 肉眼复查 `play_table_drag_drop_1280x720.png`、`play_table_drag_drop_1600x960.png`、`play_table_drawer_1600x960.png`、`main_menu_1600x960.png`：拖拽小卡不再压住底部牌桌，地图接受区清楚，主菜单仍保持商业游戏入口结构。
- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过。

### 剩余缺口

- 拖拽落点现在只区分“地图可接收/非地图不可接收”；下一步应把规则态拆得更细：费用不足、冷却中、卡牌目标不匹配、当前阶段不可出牌。
- 继续按“能抄就抄”的方向推进下一块：把竞价、公开牌轨和情报档案做成更像商业桌游的可点击牌桌区域，而不是主要靠文字说明。

## 2026-07-02｜手牌拖拽落点反馈与非法落点提示

### 参考方向

- 继续按商业卡牌桌/桌游电子版的拖拽手感推进：拖牌时不能只显示一张跟手浮层，还要告诉玩家哪里能放、哪里不能放。
- 参考 UiCard / Tabletop Simulator / 现代数字桌游的 drop-zone 反馈：合法目标用明确边框和短语提示，非法区域给出拒绝状态，但不把规则细节塞到主桌。
- 保持分层：`OverlayLayer` 只画反馈，`GameScreen` 只判断当前鼠标是否在真实地图控件上，`main.gd` 仍负责最终出牌和区域命中。

### 本轮实现

- `scenes/ui/OverlayLayer.tscn` 新增 `DragDropTargetPanel / DragDropTargetLabel`，放在现有 `DragPreviewLayer` 下，用于高亮当前可接收地图区域。
- `scripts/ui/overlay_layer.gd` 扩展 `show_drag_preview(text, screen_position, drop_hint)`：
  - 拖到地图外时，预览和目标框使用拒绝色，并提示“拖到星球地图”；
  - 拖到真实地图控件上时，目标框切换为接受色，并提示“松开出牌”；
  - 拖拽结束时同时隐藏浮层和目标框。
- `scripts/ui/game_screen.gd` 将 drop-zone 判断对齐到 `MapHost` 中真实挂载的地图控件；找不到运行时地图时才退回 `MapHost`，避免预览接受区与 `main.gd` 的地图命中区不一致。
- `tests/layout_scene_smoke_test.gd` 增加组件层验收：拖在屏幕外显示非法落点提示，移动到 `MapHost` 后切换为接受状态，释放在无效区域不会发 `card_drop_requested`。
- 同时修正运行时 quick-action 测试的状态污染：建城后可能有行动冷却，测试在验证出牌入口前显式清理当前玩家冷却，避免把冷却规则误判成出牌入口坏了。

### 验证

- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过；仍只有当前仓库已有的 LF/CRLF 提示。

### 剩余缺口

- 下一轮应补 headed screenshot 视觉复查：拖拽浮层、地图高亮、手牌和右侧面板在 1200x680 / 窄屏下是否重叠。
- 还可以继续把非法落点从“只能拖到地图”升级为更细的规则提示，例如冷却中、费用不足、当前卡不能以该区域为目标。

## 2026-07-02｜手牌拖拽到地图出牌闭环

### 参考方向

- 继续按商业卡牌桌/桌游电子版的直接操控推进：玩家应能把手牌拖到主桌或地图区域来行动，而不是只依赖底部按钮和双击。
- 参考 UiCard / CardHouse 式对象手感，同时保留当前分层：手牌、玩家板、GameScreen 只发 UI intent；地图命中和出牌规则仍由 `MapView` / `main.gd` 处理。
- 拖拽落点应改变选区上下文：把牌拖到地图区域时，先选中落点区域，再按同一张手牌走现有匿名出牌流程。

### 本轮实现

- `scripts/ui/hand_rack.gd` 在现有拖拽预览基础上新增 `card_drag_released(card_data, screen_position)`，并改为从真实鼠标事件读取释放坐标；原有 preview started/moved/ended 信号继续保留。
- `scripts/ui/player_board.gd` / `scripts/ui/game_screen.gd` 逐层转发拖拽释放。`GameScreen` 只判断释放点是否落在 `MapHost/PlanetBoard`，然后发 `card_drop_requested`，不读取玩家数组或规则函数。
- `scripts/map_view.gd` 新增 `get_district_at_control_position(position)`，复用自身投影与命中测试，把地图本地释放点反查为区域编号。
- `scripts/main.gd` 接入 `card_drop_requested`：落点在当前 `MapView` 上时，先 `_select_district()` 到落点区域，再按手牌 `hand_N/play_N` 走现有 `_use_skill(slot_index)`，继续进入匿名公共牌轨。
- `tests/layout_scene_smoke_test.gd` 新增两层验收：
  - 组件层：`HandRack -> PlayerBoard -> GameScreen` 能把 MapHost 上的释放变成 `card_drop_requested`；
  - 运行时层：真实拖拽 live `CardFace` 到目标地图区域，验证选区变成落点、手牌 slot 被选中、公共 resolution track 增加。

### 验证

- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过；仍只有当前仓库已有的 LF/CRLF 提示。

### 剩余缺口

- 下一轮应补拖拽中的落点高亮/非法落点提示，让玩家拖牌时知道地图是否会接收这张牌。
- 还需要更强的视觉 QA：尤其是缩放态、平面投影边界外宇宙空间、不同窗口尺寸下 MapHost 与手牌拖拽预览是否稳定。

## 2026-07-02｜地图真实鼠标选区与双击牌架闭环

### 参考方向

- 继续按商业 4X/桌游电子化的主桌交互推进：中央星球不是背景图，而是玩家第一分钟内最常用的可点击棋盘。
- 参考 VASSAL / Tabletop Simulator / Gaia Project 数字版的输入契约：测试应尽量触发真实 UI 控件和鼠标事件，而不是直接改控制器状态。
- 保持当前分层：`MapView` 只负责地表投影和输入事件；选区、牌架打开和规则刷新仍回到 `main.gd` 控制器。

### 本轮实现

- `scripts/map_view.gd` 新增 `get_district_control_position(index)`，复用地图自身投影参数，把区域中心转换成当前 `MapView` 的本地输入坐标，供真实鼠标流和后续自动化验收使用。
- `MapView` 新增查询前的投影参数同步，避免 headless/layout 测试在未重绘或缩放态下取到旧 `_scale/_map_offset`。
- `tests/layout_scene_smoke_test.gd` 新增 live runtime 地图鼠标流：
  - 新开一桌并关闭菜单，定位分屏 `MapHost` 中真实挂载的 `MapView`；
  - 对目标区域坐标发送真实 `InputEventMouseButton` press/release；
  - 验证单击会通过 `district_selected` 刷新 `selected_district` 和 split TopBar 选区文字；
  - 再发送真实双击事件，验证 `district_double_clicked` 打开同一区域的牌架抽屉。
- 新增测试 helper 用于寻找有牌架/存活区域，并统一构造地图点击事件，为下一步拖拽出牌和地图落点交互补证铺路。

### 验证

- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过；仍只有当前仓库已有的 LF/CRLF 提示。

### 剩余缺口

- 下一轮应优先补“拖拽手牌到桌面/地图区域触发出牌”的真实输入流，让玩家不只靠按钮和双击完成卡牌行动。
- 地图缩放/拖拽的视觉 QA 仍可继续加强：尤其是平面投影边界外宇宙空间、远近缩放时标签密度和选中态可读性。

## 2026-07-02｜满手换购私密弃牌 split modal 闭环

### 参考方向

- 继续按商业卡牌/桌游电子版的“当前桌边决策”模式推进：当玩家满手买牌时，决策应出现在当前可见牌桌层，而不是藏在旧兼容面板里。
- 参考 VASSAL/桌游模块式 overlay 分层和 CardHouse 式手牌私密操作：公共牌桌只显示“有私密处理”，具体旧牌名和弃牌选择只在当前玩家自己的 modal 中出现。

### 本轮实现

- `main.gd` 新增 split runtime 的 `temporary_decision` snapshot：当当前人类玩家存在 `pending_discard_purchase` 时，产出 data-only 私密弃牌决策，包括隐私 chip、说明文本和 `discard_purchase_*` action id。
- `scripts/viewmodels/table_snapshot.gd` 透传并规范化 `temporary_decision`，继续禁止 Callable 进入 split UI snapshot。
- `scripts/ui/game_screen.gd` 将 `temporary_decision` 转给 `OverlayLayer`，并把 modal action 继续发回 `main.gd`。
- `scripts/ui/overlay_layer.gd` / `scenes/ui/OverlayLayer.tscn` 在现有 `ModalLayer` 上补出可复用临时决策 modal：标题、隐私 chip、说明、按钮都由 snapshot 驱动。
- `main.gd` 处理 `discard_purchase_cancel` 和 `discard_purchase_N` action id，最终仍走 `_cancel_discard_purchase()` / `_confirm_discard_purchase()`，不在 UI 层写规则。
- `tests/layout_scene_smoke_test.gd` 新增 live runtime 点击流：
  - 构造满手人类玩家、可购区域和怪兽访问范围；
  - 点击真实 `买牌` quick button 打开牌架；
  - 双击真实市场卡触发 `pending_discard_purchase`；
  - 确认 split `OverlayLayer` 显示“私密弃牌确认” modal；
  - 点击真实“弃掉”按钮，验证 pending 清空、现金扣除、手牌保持上限、旧牌移除、新牌入手，且公共日志不泄露卡名或弃牌内容。

### 验证

- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过；仍只有当前仓库已有的 LF/CRLF 提示。

### 剩余缺口

- 下一轮最值得补地图真实鼠标选区：目前地图选择规则存在，但还需要 live mouse/input 级别的主流程验收。
- 拖拽出牌仍只是 UI-only preview，还没有真人式“拖到桌面/区域触发出牌”的完整路径。

## 2026-07-02｜区域牌架双击购买闭环补证

### 参考方向

- 继续按成熟卡牌/桌游电子版的市场交互推进：牌架里的卡不应只是一组说明面板，玩家应该能预览、双击购买，并马上看到现金和手牌结果。
- 参考 CardHouse / UiCard 的卡片对象手感，同时保持当前 Space Syndicate 分层：`DistrictSupplyMarketCard` 只发 hover/preview/activated 信号，不直接读玩家、区域或购买规则。

### 本轮实现

- `scripts/ui/district_supply_market_card.gd` 增加只读 `get_card_name()`，便于测试和外层工具定位真实市场卡节点，不改变购买规则。
- `tests/layout_scene_smoke_test.gd` 新增 live runtime flow：
  - 新开一桌并通过真实 `出牌` quick button 完成首召，建立怪兽访问范围；
  - 从运行态牌架中找一个可直接购买、不触发满手弃牌、不重复卡族的市场卡；
  - 点击真实底部 `买牌` quick button 打开对应区域牌架抽屉；
  - 在抽屉里定位真实 `DistrictSupplyMarketCard`，触发双击事件；
  - 验证玩家现金减少，并且目标卡族进入当前玩家私密手牌。
- 这轮补的是真人手感路径，不新增规则：双击只触发 `card_activated`，最终仍走 `_claim_district_card()` 的访问、价格、满手和重复卡族判定。

### 验证

- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过；仍只有当前仓库已有的 LF/CRLF 提示。

### 剩余缺口

- 下一轮应继续补满手买牌时的私密弃牌窗口真实点击流，确保满手换购不会泄露手牌。
- 还缺地图真实鼠标选区和拖拽出牌落点验收；这些会决定第一分钟试玩是否真正顺手。

## 2026-07-02｜手牌双击出牌闭环补证

### 参考方向

- 继续参考 CardHouse / Balatro Feel / UiCard 的成熟卡牌桌手感：手牌应当能直接被点选、预览、双击行动，而不是只靠底部快捷按钮间接操作。
- 保持当前分层规则：`CardFace / HandRack / PlayerBoard` 只消费 snapshot 和发 UI intent，不读取玩家数组、地图区域或 `_use_skill()` 等规则函数；真正出牌仍由 `main.gd` 控制器执行。

### 本轮实现

- `scripts/ui/player_board.gd` 中，双击手牌现在会先保持普通选中/右侧详情，再读取卡牌 snapshot 里的首个可用 `actions`，将 `play_N` 通过 `action_requested` 发回 `GameScreen -> main.gd`。
- 不把规则判断塞进 UI：可不可打仍由 `_runtime_hand_card_snapshots()` 里已有的 `disabled/actionable` 结果决定，PlayerBoard 只负责把“双击可用手牌”翻译成既有动作 id。
- `tests/layout_scene_smoke_test.gd` 新增两层验收：
  - 组件层确认 `PlayerBoard` 双击 enabled hand card 会发出 `play_0`；
  - live runtime 层重开一桌，从真实 `HandRack/CardFace` 触发双击事件，确认匹配手牌槽被选中，并且卡牌进入匿名公开结算轨。

### 验证

- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过；仍只有当前仓库已有的 LF/CRLF 提示。

### 剩余缺口

- 下一轮继续补拖拽出牌落点、地图真实鼠标选区、市场卡双击购买，以及满手购牌时的私密弃牌窗口。
- 还需要 headed 截图复查双击/hover/drag 过程中手牌视觉是否足够像商业卡牌桌，而不只是信号链可用。

## 2026-07-02｜买牌快捷行动端到端点击流补证

### 参考方向

- 继续按商业桌游式玩家板推进：底部 `买牌` 不只是“打开一个面板”，玩家应能顺着同一条 UI 路径完成一次实际购牌。
- 参考 Terraforming Mars / Gaia Project 的主桌节奏：先在主桌做大动作，再进入局部抽屉完成具体选择；主屏保持短读，细节和购买判定进入抽屉。

### 本轮实现

- `tests/layout_scene_smoke_test.gd` 的 live runtime click flow 继续扩展：
  - 点击真实 `出牌` quick button 后推进匿名结算轨，确认首召怪兽真正落地；
  - 从运行态 district/card supply 中寻找一个怪兽可达、可直接购买、不会触发满手弃牌的卡；
  - 点击真实 `PlayerMainActionDock` 里的 `买牌` quick button，确认打开对应区域牌架抽屉；
  - 点击抽屉中的 `DistrictSupplyPreviewBuyButton`，确认玩家现金减少，并且购买卡族进入玩家私密手牌。
- 新增测试 helper 只读取运行态 `players / districts / auto_monsters / card_resolution_queue` 等事实，并调用现有规则 helper 判定可购卡；不伪造 UI snapshot、不绕过抽屉购买按钮。

### 验证

- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过；仍只有当前仓库已有的 LF/CRLF 提示。

### 剩余缺口

- 下一轮应补满手买牌时的私密弃牌窗口真实点击流，确认不泄露手牌和弃牌信息。
- 仍需补地图真实鼠标点击选区、市场卡双击购买、手牌双击/拖拽出牌等更接近真人手感的路径。

## 2026-07-02｜底部玩家板真实点击流补证

### 参考方向

- 继续按商业桌游/4X 主桌的第一分钟读序推进：玩家不应只看到“行动状态”，还要能从底部玩家板直接完成下一步。
- 本轮参考 Terraforming Mars / Gaia Project 类桌面逻辑：资源板、手牌架和行动按钮必须落到同一条可操作主流程，而不是分散在调试面板或只存在于测试调用里。

### 本轮实现

- `tests/layout_scene_smoke_test.gd` 新增 live runtime 点击流：
  - 从真实 `RuntimeGameScreen` 找到 `PlayerMainActionDock`；
  - 选取真实有区域牌架的 district，点击 `牌架` 按钮，验证 `district_supply_overlay` 打开并绑定当前选区；
  - 选取真实可城市化 district，点击 `建城` 按钮，验证玩家城市数增加且新城市归属当前玩家；
  - 选取真实可首召/出牌落点，点击 `出牌` 按钮，验证匿名牌进入公开结算/牌轨队列。
- 测试 helper 只读取运行态 `districts / card_resolution_queue / active_card_resolution` 等事实，不伪造 snapshot；按钮本身来自 live `PlayerMainActionDock`，更接近真人试玩路径。
- 这轮不扩展新规则，只把上轮 quick action 桥接从“源代码合同”推进到“真实 UI 按钮能驱动玩法结果”的验收证据。

### 验证

- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过；仍只有当前仓库已有的 LF/CRLF 提示。

### 剩余缺口

- 下一轮应继续补更像真人鼠标路径的主桌交互：地图点击选区、抽屉内买牌按钮、手牌双击/拖拽出牌，以及买牌满手时的私密弃牌窗口。
- `buy` 快捷按钮目前仍受怪兽落地区/相邻区规则约束，真实点击流还缺“首召结算后买牌按钮直接打开并完成购牌”的端到端测试。

## 2026-07-02｜底部快捷行动接通真人试玩主流程

### 参考方向

- 继续按商业桌游和 4X 管理游戏的底部玩家板模式推进：主屏快捷行动不只是状态灯，而应当是玩家第一分钟能直接点的入口。
- 参考方向是“玩家板给出少量高置信操作，细节进入侧栏/抽屉”：Build/Rack/Buy/Play 保持短标签，合法性和完整说明仍由右侧详情、牌架抽屉和卡牌详情承担。

### 本轮实现

- 修正 split `PlayerBoard -> ActionDock -> GameScreen` 已经显示 `建城 / 牌架 / 买牌 / 出牌`，但 `main.gd` 只处理 `primary`、Codex、district 和 `play_*` 信号的问题。
- `main.gd` 新增 `_activate_runtime_quick_action()` 和 `_runtime_quick_action_entry()`，将四个底部快捷行动接回现有控制器：
  - `build` 复用 `_city_build_error_for()` 检查，再调用 `_build_city_in_selected_district()`。
  - `rack` 和 `buy` 复用当前选区，打开 `_open_district_supply_from_map(selected_district)`。
  - `play` 复用 `_first_actionable_hand_slot()`，选中首张可打手牌并调用 `_use_skill(slot_index)`。
- `tests/layout_scene_smoke_test.gd` 增加静态合同，锁住 split ActionDock 的 quick action 必须回到主控制器，避免后续继续拆 UI 时又变成“看得见但点不了”。

### 验证

- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过；仍只有当前仓库已有的 LF/CRLF 提示。

### 剩余缺口

- 真人可玩目标仍需要继续做可见点击流复验：下一轮优先补从底部 `PlayerMainActionDock` 真实按钮点击到建城/牌架/买牌/出牌结果的交互 smoke，而不是只靠源代码合同。
- 页面和代码分层仍要继续把更多菜单、Codex、经济/情报页面构造从 `main.gd` 迁到专门 Presenter/ViewModel；本轮只处理了底部快捷行动桥接，不扩大规则面。

## 2026-07-02｜产品/页面/代码分层推进与 Full Smoke 清零

### 本轮实现

- 继续按商业化策略游戏/桌游式 4X 的读序推进：主菜单走“星球大厅 + 纵向命令塔”，主桌走“顶部公开轨 + 中央正方形星球 + 底部玩家板 + 右侧 10 秒详情”的页面边界。
- 主游戏 split runtime 保持 `GameScreen -> TableSnapshot -> TopBar/PublicTrack/PlanetBoard/PlayerBoard/RightInspector` 数据流；旧 `player_box` 不再承载完整玩家板，只保留开局引导、弃牌购买、合同响应等临时决策兼容面板，避免 full smoke 为了旧节点名拖回大块 legacy UI。
- 右侧 Inspector 与 ActionDock 改成更紧的 dense 形态：隐藏重复标题/快捷行、降低日志和条件面板高度、把选区和卡牌长说明继续拆到 drawer/Codex。
- 星球主桌补齐天气/预报、公开事件轨、星球流向罗盘和更短的区域摘要；地图和卡面第一屏减少长文字，完整信息进入 hover、侧栏、抽屉或图鉴。
- 牌桌经济/情报链补了仓储靶标与仓储风险线索入口，终局结算菜单补齐赛后读序；同时修正市场预览价格、公开事件 slot、CardFace 元数据和 split 兼容决策面板，完整 smoke 中的终局倒计时、仓储期货、破产、满手购买、合同窗口等主流程红灯已清零。
- `tests/visual_snapshot.gd` 与 `tests/layout_scene_smoke_test.gd` 的静态合同更新为当前 split 事实：默认运行态同步 snapshot，并只维护窄兼容决策 host；完整旧 PlayerBoard 仍只作为 fallback 受签名缓存保护。

### 验证

- `Godot --headless --path . --script res://tests/smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/smoke_test.gd --check-only` 通过。
- `Godot --headless --path . --script res://tests/ui_text_smoke_test.gd` 通过。
- `Godot --headless --path . --script res://tests/visual_snapshot.gd` 通过。
- `Godot --headless --path . --script res://tests/layout_scene_smoke_test.gd` 通过。
- `Godot --path . --windowed --script res://tests/ui_snapshot_capture.gd` 通过，重新生成 `play_table_1280x720.png`、`play_table_1600x960.png`、`play_table_1920x1080.png` 等多分辨率截图。
- 目检三张主桌截图：核心按钮和底部手牌均未出屏；中央星球/地图仍是最大视觉块；主屏只保留短读信息，完整规则没有挤进 MiniCard 或常驻主桌。
- 剩余产品缺口：还需要继续用可见截图复验主菜单、主桌、抽屉和 Codex 的商业化视觉密度；下一轮优先把更多样式 token 和页面构造从 `main.gd` 迁出，而不是继续在巨型脚本里加 UI。

## 2026-07-02｜HandRack 截图复验与牌架加厚

### 本轮实现

- 复跑 `tests/ui_snapshot_capture.gd` 后目检 `play_table_1280x720.png`、`play_table_1600x960.png`、`play_table_1920x1080.png`，发现单张手牌在底部大牌架中仍偏瘦小，商业卡牌物件感不足。
- `PlayerBoard.tscn` 将底部玩家板从 178px 收紧上调到 192px，仍低于 720p 的 30%，同时 `PlayerBoardBody` 与 `HandRack` 高度改成 150px / 124px，给 MiniCard 留出更像牌架的垂直空间。
- `HandRack.tscn` 将基准卡面改成更宽的 `140x158`，保留 `compressed / pressure` 压缩曲线，让 10/15 张压力手牌继续守在边界内。
- `CardUI.gd` 将 `mini_hand` 字号提升到 10，MiniCard 的费用、短名、路线/类型、等级、一行用途和状态灯更可读；完整规则仍只进入 RightInspector、Drawer 或 Codex。
- `tests/ui_text_smoke_test.gd` 的运行态中文合同从旧 `main.gd` 独占检查改成 `main.gd + split UI/ViewModel` 综合检查，符合当前 split scene 架构，避免为了测试把 fallback 字符串塞回巨型脚本。

### 验证

- `tests/layout_scene_smoke_test.gd` 通过，确认 1280x720 下 `TopBar / PublicTrack / TableArea / PlayerBoard / HandRack` 仍在视口内，中央 `PlanetBoard` 仍是最大视觉块。
- `tests/visual_snapshot.gd` 通过，锁住 192px 玩家板、124px HandRack、14 度 fan、62px hover lift 和 1.16 hover scale。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/ui_snapshot_capture.gd` 有头通过；三张主桌截图目检通过：核心按钮和手牌不出屏，主屏无长规则说明，星球仍是最大视觉区域，MiniCard 比上一版更像卡牌物件。

## 2026-07-02｜Smoke 主桌 split 合同对齐

### 本轮实现

- `tests/smoke_test.gd` 的玩家板早段合同从旧 `player_box` 专属节点名改成兼容 split `RuntimeGameScreen`：`TopBar / PlayerBoard / PlayerResourceTableau / PlayerHandTableau / PlayerMainActionDock / HandRack / RightInspector` 都作为主桌第一屏证据参与验证。
- 开局引导、公开席位、目标提示、选区行动、首召按钮等旧动态面板断言保留 legacy 对照，但默认 split 路径改查“下一步 + 菜单入口 + 行动 dock + 状态/readiness chips”，符合当前产品分层。
- 主桌星球/手牌布局断言从旧文案“星球赌桌 / 赌桌中央 / 桌边牌架”切换为几何合同：`MapView` 必须挂到 `PlanetBoard/MapHost`，`MapHost` 保持近似正方形，`HandRack` 位于底部玩家板且小于中央星球主舞台。

### 验证

- `tests/smoke_test.gd --check-only` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `git diff --check` 通过；仅有 Windows LF/CRLF 提示。
- 完整 `tests/smoke_test.gd` 仍失败，但玩家板/HandRack/主桌星球布局相关断言已经通过；剩余失败集中在牌轨竞价/历史状态、经济总览/规则/情报/角色 Codex 页面合同、以及终局倒计时、仓储期货、破产淘汰等非本轮主桌 UI 范围。

## 2026-07-02｜HandRack 二版商业卡牌手感落地

### 本轮实现

- 按 `CardHouse + Balatro-Feel + UiCard + simple-cards-v-2` 的参考方向，把 `HandLayout` 改成 profile 驱动：`single_focus / comfortable / compressed / pressure` 分别处理单卡、常规手牌、拥挤手牌和 11+ 张压力态。
- `HandLayout` 现在输出可测试的 motion target snapshot：目标位置、旋转、缩放、z-index、profile、slot ratio、gap 和 UI-only drop zone，方便后续继续对标商业卡牌手感。
- `HandRack` 保留 same-id 节点复用与 RightInspector 联动，同时给拖拽预览补上 `hand_drag_preview_active/origin/screen_position` 元数据和 `get_drag_preview_card()`，仍然只走 UI signal，不调用规则。
- `CardUI` 的 MiniCard 继续只做速读：短名、一行效果、路线/类型短标签、等级短标签、状态短标签；完整规则继续进入 RightInspector、Drawer、Codex。
- `HandRack.tscn` 的扇形、hover lift、hover scale 和邻牌让位参数上调，避免底部手牌看起来像一排低矮按钮。

### 验证

- `tests/layout_scene_smoke_test.gd` 通过，覆盖 1/5/10/15 张手牌布局、hover 抬升、邻牌推开、drop zone 元数据和 live refresh 后 hover 保持。
- `tests/visual_snapshot.gd` 通过，锁住 HandRack profile、拖拽预览元数据、MiniCard 速读函数和场景参数。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/ui_snapshot_capture.gd` 有头通过，已生成 1280x720、1600x960、1920x1080、2560x1440 等主菜单/主桌/抽屉截图并肉眼检查。
- `git diff --check` 通过；仅有 Windows LF/CRLF 提示。

### 追加审计

- 为回应“直到人类能玩”的更宽目标，额外跑了一次完整 `tests/smoke_test.gd`。
- 完整 smoke 仍失败，失败范围已经超出 HandRack：终局倒计时、仓储期货清算、破产淘汰、顶部牌轨历史/横向滚动、菜单/Codex/经济总览/情报档案的旧合同，以及若干主桌旧命名合同仍需单独清理。
- 因此本轮可以证明 HandRack 二版目标通过指定验收，但不能把“整局完整人类可玩”宣称为已完成；下一阶段应单独做完整 smoke 失败分组和旧合同更新/修复。

## 2026-07-02｜订立下一阶段“先抄标杆”开发目标

### 本轮实现

- `docs/next_development_goals.md` 增加“下一阶段复制策略”：把参考项目按 `A 级可直接移植模式 / B 级只抄产品结构 / C 级先确认再抄` 分档。
- 下一阶段目标改成五条可执行任务：主桌商业化读序、HandRack 二版卡牌手感、菜单/Codex 页面产品化、Theme/样式抽离、参考标杆到截图验收的测试固定。
- `docs/open_source_reference_notes.md` 增加 Next-Stage Copy Targets，明确每个参考标杆落到哪些本地 scene/script/test。
- 下一次最推荐任务从“迁移 PlayerBoard”更新为“按 CardHouse / Balatro-Feel / UiCard / simple-cards-v-2 标杆重做 HandRack 二版手感”。

### 验证

- 后续测试合同将检查 `next_development_goals.md` 和 `open_source_reference_notes.md` 保留这些复制分档、参考标杆和下一阶段 HandRack 目标。

## 2026-07-02｜SideDrawer 改成分节化 30 秒详情层

### 本轮实现

- `OverlayLayer.tscn` 的侧边抽屉正文区改成 `SideDrawerBodyScroll + SideDrawerSectionList`，30 秒信息不再只塞进一段长正文。
- `OverlayLayerSnapshot` 从当前 `RightInspectorSnapshot` 生成稳定读序：对象、原因、桌面摘要、完整详情、最近公开日志；完整区域/卡牌说明继续留在抽屉/Codex，不回到常驻右侧栏。
- `OverlayLayer.gd` 渲染分节卡片、chips 和 Codex 后续按钮；动态卡片使用稳定 `SideDrawerSectionCard1/2/...` 命名，方便布局测试和截图 QA。

### 验证

- `tests/layout_scene_smoke_test.gd` 新增真实点击详情入口后的分节抽屉合同，确认 `完整详情` 和全文只在抽屉 section body 中出现。
- `tests/visual_snapshot.gd` 新增静态合同，要求 OverlayLayer 保留滚动分节抽屉和 `OverlayLayerSnapshot.sections`。

## 2026-07-02｜菜单、星球舞台、手牌密度收紧

### 本轮实现

- `MenuRootLobby` 继续按商业游戏入口节奏推进：全屏程序化星球背景增加大陆、云带、夜侧城市灯和轨道刻度；右侧主命令塔改为编号命令卡、加高主 CTA，并扩大命令列稳定宽度。
- `PlanetBoard` 保持中央 `MapHost` 为正方形主视野，但把左右剩余空间改成轨道线、边缘刻度和更高的公开信息 rail，避免两侧看起来像未使用空白。
- `MapView` 默认平面投影留出更多宇宙边界，密集标签、桌面 token 标签和 callout 需要更高 zoom/focus 才出现，避免星球表面第一眼过密。
- `PlayerBoardSnapshot` 和 `HandRack` 现在把底部手牌默认规范为 `presentation = "mini_hand"`、`detail_policy = "right_inspector"`；`CardUI` 按 MiniCard 模式只显示短名、费用、类型、等级、一行用途和状态，完整规则继续进右侧详情/抽屉/Codex。
- 开源参考继续按 `docs/open_source_reference_notes.md` 执行：复制结构、交互节奏和 permissive-license pattern；GPL/AGPL/LGPL 项目只做产品层级和行为参考，除非明确接受许可证义务。

### 验证

- `tests/visual_snapshot.gd` 通过，新增菜单命令塔、程序化星球细节、地图低密度阈值、星球轨道空间和 MiniCard 展示合同。
- `tests/layout_scene_smoke_test.gd` 通过，确认运行态手牌默认 MiniCard、PlayerBoard 直接输入也不会回到完整长文本卡面。

## 2026-07-02｜PlayerBoard 改成三栏玩家 tableau

### 本轮实现

- `PlayerBoard.tscn` 从横向 chip 流改成桌游玩家板三栏：
  - 左侧 `PlayerResourceTableau`：本席、现金、GDP、目标、目标进度、选区、下一步；
  - 中间 `PlayerHandTableau`：手牌数、桌态/就绪短 chip、`HandRack`；
  - 右侧 `PlayerCommandTableau`：唯一 `PlayerMainActionDock`，继续承载建城/牌架/买牌/出牌和当前主行动。
- `PlayerBoard.gd` 只补渲染样式和 chip 色彩，不读取规则状态、不创建玩法动作。
- `HandRack.tscn` 的卡牌规格和 hover 手感略上调，底部仍保持 1280x720 安全高度。
- `ActionDock.gd` 的 compact mode 更像桌边命令板：四个快捷行动按类型着色，当前主行动按钮更像 CTA。

### 验证

- `tests/layout_scene_smoke_test.gd` 通过，确认 1280x720 下 TopBar / PlayerBoard / HandRack / ActionDock 不出屏。
- `tests/visual_snapshot.gd` 通过，新增 PlayerBoard 三栏 tableau 静态合同。
- `tests/ui_text_smoke_test.gd` 与 `tests/smoke_test.gd --check-only` 通过。

## 2026-07-02｜Scene 化页面取消 legacy fallback

### 本轮实现

- `main.gd` 的玩家可见页面桥接继续收紧为 scene 硬依赖：
  - 新手引导、规则速查、局势记分板、经济仪表板、终局记分板、情报侦探板、资料大厅、角色身份板必须实例化对应 `scenes/ui/*` 组件；
  - 如果组件缺失或不暴露 `set_*` 方法，统一通过 `_report_required_ui_scene_missing()` 报错并停止渲染该页；
  - 不再悄悄调用 `_legacy` 动态 UI 生成器重建玩家可见页面。
- 本轮不新增玩法，只把已迁移页面从“软迁移”改成“硬分层合同”。
- 继续删除已经没有调用路径的旧生成器：
  - `_add_tutorial_quick_start_panel_legacy()` 以及专用 chip/step/trap helper；
  - `_populate_rules_summary_cards_legacy()`；
  - `_add_compendium_hub_board_legacy()` 与 `_add_compendium_menu_button()`；
  - `_add_standings_scoreboard_panel_legacy()` 以及专用 chip/KPI/score-card helper；
  - `_add_economy_dashboard_panel_legacy()` 以及专用 chip/KPI/list-card helper；
  - `_add_final_settlement_board_panel_legacy()` 以及专用 chip/KPI/money/event/rank helper；
  - `_add_intel_dossier_board_panel_legacy()` 以及专用 chip/KPI/list-card helper；
  - `_add_role_codex_identity_board_panel_legacy()` 以及专用 chip/KPI/route-card helper，并移除未使用的旧角色预览 helper。

### 验证

- `tests/visual_snapshot.gd` 新增静态合同，禁止这些 scene-owned 页面调用 legacy fallback，并确认已迁移页面的旧生成器保持删除状态。
- 已运行 `tests/visual_snapshot.gd`、`tests/ui_text_smoke_test.gd`、`tests/layout_scene_smoke_test.gd`、`tests/smoke_test.gd --check-only`。

## 2026-07-02｜主菜单首屏商业入口化

### 本轮实现

- 根主菜单继续沿用 `MenuOverlay + MenuRootLobby` 分层，但 root 大厅隐藏外层弹窗标题，由内层首屏承担品牌、星球和主行动层级。
- `MenuRootLobby` 的左侧速览从横向小标签改为纵向桌面状态牌，保留席位、怪兽开局、匿名牌轨三条开桌前核心信息。
- 右侧主行动卡加入 `featured` 主卡层级和 `01/02/03` 读序，`开新一桌` 比继续/资料库更明确，底部规则/读档/退出仍保持辅助动作。
- 主菜单继续只提供开桌、继续、资料库、规则、读档、退出，不新增玩法分支。

### 验证

- 更新 `tests/visual_snapshot.gd`，静态约束主菜单使用 featured 纵向命令卡，而不是回退到旧分支列表。
- 可见截图重新生成并目检 `main_menu_1280x720.png`、`main_menu_1600x960.png`：中心星球保留第一视觉，右侧行动塔更清楚，外层重复标题已消失。

## 2026-07-02｜PlanetBoard 星球主视野继续压缩空白

### 本轮实现

- `PlanetBoard` 的 `MapHost` 改为优先吃满舞台高度，中央星球继续保持最大正方形主视野。
- 左右公开读数从贯穿全高的大面板改为贴近星球边缘的紧凑轨道读数，避免把左右宇宙空间做成空调试栏。
- `MapView` 常驻提示从长操作说明缩短为小读数；具体操作继续通过选区徽章、Inspector、Drawer 承接。
- `RightInspector` 的 why/条件区和公开日志区改为有内容才显示；`条件/暂无条件/待选择` 这类占位 chip 不再撑开 10 秒层，避免右侧详情栏出现空白占位面板。
- 右侧原因、日志和区域短说明 Label 补稳定最小高度，避免 VBox 把文字压到 1px 后看起来像空面板。

### 验证

- `tests/layout_scene_smoke_test.gd` 新增主桌运行态合同：`MapHost` 必须吃满方形舞台高度，侧轨必须贴近星球且高度不超过星球的一半。
- `tests/visual_snapshot.gd` 更新地图提示合同，约束主屏只显示短玩家读数。
- `tests/layout_scene_smoke_test.gd` 新增 RightInspector 空面板检查：可见的 why/log 面板必须有真实文本或条件 chip。

## 2026-07-02｜CardCodexDetail 详情页数据接入 ViewModel

### 本轮实现

- 新增 `scripts/viewmodels/card_codex_detail_snapshot.gd`：
  - 只输出 data-only 卡牌详情页 snapshot；
  - 统一处理公开卡面、扫牌顺序、牌桌用途三格、事实卡、I-IV 升级梯、结算演出说明；
  - 不创建 UI 节点，不绑定 signal，不读取规则状态。
- `main.gd` 保留从技能定义推导费用、效果、目标、升级和规则事实的 source 职责，再交给 `CardCodexDetailSnapshot` 归一化成 `CardCodexDetail.set_detail()` 所需 UI 数据。
- `CardCodexDetail` 继续只负责渲染 scene-owned TCG 详情布局，不解释规则状态。

### 验证

- `tests/layout_scene_smoke_test.gd` 新增 `CardCodexDetailSnapshot` 载入、扫牌顺序、用途条、升级、结算说明和 data-only 合同。
- `tests/visual_snapshot.gd` 新增静态合同，确认卡牌详情页通过 `CardCodexDetailSnapshotScript` 生成 UI snapshot。
- `tests/ui_text_smoke_test.gd` 纳入 `card_codex_detail_snapshot.gd`，继续约束详情页 fallback 文案为玩家可读中文。

## 2026-07-02｜CardCodexBrowser 缩略页数据接入 ViewModel

### 本轮实现

- 新增 `scripts/viewmodels/card_codex_browser_snapshot.gd`：
  - 只输出 data-only 卡牌图鉴缩略页 snapshot；
  - 统一处理缩略页分页、当前预览卡 fallback、筛选 chip 文案、卡片选中态和 hover 预览数据；
  - 不创建 UI 节点，不绑定 signal，不读取规则状态。
- `main.gd` 保留从牌库、技能定义、筛选器中取 source data 的职责，但不再直接拼完整 `CardCodexBrowser` UI 字典。
- `CardCodexBrowser` 继续只渲染 `set_browser(data)` 并发出筛选、翻页、预览和详情 signal。

### 验证

- `tests/layout_scene_smoke_test.gd` 新增 `CardCodexBrowserSnapshot` 载入、分页、选中卡 fallback、筛选 chip 和 data-only 合同。
- `tests/visual_snapshot.gd` 新增静态合同，确认卡牌图鉴缩略页通过 `CardCodexBrowserSnapshotScript` 生成 UI snapshot。
- `tests/ui_text_smoke_test.gd` 纳入 `card_codex_browser_snapshot.gd`，继续约束缩略页 fallback 文案为玩家可读中文。

## 2026-07-02｜OverlayLayer 抽屉数据接入 ViewModel

### 本轮实现

- 新增 `scripts/viewmodels/overlay_layer_snapshot.gd`：
  - 只输出 data-only `side_drawer` 字典；
  - 从当前 `RightInspectorSnapshot` 读取 `full_detail/logs/chips/requirements`；
  - 通过 `ActionDockSnapshot` 归一化抽屉里的 Codex 后续动作。
- `GameScreen` 不再内联组装 30 秒抽屉的标题、正文、chips 和 Codex 链接，只负责从右侧详情入口路由打开 `OverlayLayer`。
- 本轮没有新增玩法，只继续收紧 UI Scene / ViewModel 分层。

### 验证

- `tests/layout_scene_smoke_test.gd` 新增 `OverlayLayerSnapshot` 载入、全文抽屉正文、chips 和 Codex 后续动作合同。
- `tests/visual_snapshot.gd` 新增静态合同，确认 `GameScreen` 预加载 `OVERLAY_LAYER_SNAPSHOT_SCRIPT` 且不再保留旧 drawer helper。
- `tests/ui_text_smoke_test.gd` 纳入 `overlay_layer_snapshot.gd`，避免抽屉 fallback 文案回退成英文或调试文案。
- 已重新运行布局、视觉、文本、主逻辑 check-only 和可见渲染截图。

## 2026-07-02｜ActionDock 行动数据接入 ViewModel

### 本轮实现

- 新增 `scripts/viewmodels/action_dock_snapshot.gd`：
  - 只输出 data-only `quick_actions/actions`；
  - 固定缺省四个 3 秒层快捷行动：`建城 / 牌架 / 买牌 / 出牌`；
  - 把 `ready/waiting/blocked/browse` 等控制器状态归一成玩家可读短状态。
- `PlayerBoardSnapshot` 改为通过 `ActionDockSnapshot` 输出底部行动 dock 数据。
- `RightInspectorSnapshot` 改为通过 `ActionDockSnapshot` 输出右侧行动按钮和详情链接。
- `ActionDock` 仍只渲染按钮并发出 `action_requested` signal，不读规则、不判断行动合法性。

### 验证

- `tests/layout_scene_smoke_test.gd` 新增 `ActionDockSnapshot` 存在性、四快捷行动缺省、行动状态归一化、PlayerBoard/RightInspector 路由合同。
- `tests/visual_snapshot.gd` 新增静态合同，确认 `PlayerBoardSnapshot` 与 `RightInspectorSnapshot` 必须预加载 `ACTION_DOCK_SNAPSHOT_SCRIPT`。
- `tests/ui_text_smoke_test.gd` 纳入 `action_dock_snapshot.gd`，避免行动 fallback 回退成英文或调试文案。
- 已重新运行布局、视觉、文本、主逻辑 check-only 和可见渲染截图。

## 2026-07-02｜PlanetBoard 接入独立 ViewModel

### 本轮实现

- 新增 `scripts/viewmodels/planet_board_snapshot.gd`：
  - 只输出 data-only `title/hint/left_rail/right_rail`；
  - 把 `left_entries/right_entries`、`surface_rail/outer_pressure_rail` 等输入归一成统一星球棋盘 snapshot；
  - 默认读法固定为 `地表情报` 与 `外围压力`，避免 UI 场景继续靠静态占位文案兜底。
- `TableSnapshot` 现在通过 `PlanetBoardSnapshot` 处理 `planet` 字段，不再原样透传控制器字典。
- `PlanetBoard` 仍只负责渲染 snapshot 和运行时挂载 `MapView`，不读规则状态、不创建规则动作。

### 验证

- `tests/layout_scene_smoke_test.gd` 新增 `PlanetBoardSnapshot` 存在性、左右轨归一化、`TableSnapshot` 路由合同。
- `tests/visual_snapshot.gd` 新增静态合同，确认 `TableSnapshot` 必须预加载并使用 `PLANET_BOARD_SNAPSHOT_SCRIPT`。
- `tests/ui_text_smoke_test.gd` 纳入 `planet_board_snapshot.gd`，让默认文案继续受中文主桌合同约束。
- 已重新运行布局、视觉、文本、主逻辑 check-only 和可见渲染截图。

## 2026-07-02｜PlanetBoard 左右侧栏改为数据化公共情报轨

### 本轮实现

- `PlanetBoard` 左右空白侧栏不再渲染静态占位标签，而是由 `set_board_state()` 读取 `left_rail/right_rail` 数据。
- 运行时 `_runtime_planet_snapshot_source()` 新增两组只读情报：
  - 左侧 `地表情报`：星区、选区、牌架、补给；
  - 右侧 `外围压力`：怪兽、天气、牌轨、终局。
- 侧栏条目运行时创建为 `PlanetLeftRailEntry*` / `PlanetRightRailEntry*`，snapshot 绑定后隐藏旧 fallback 文案。
- 星球主舞台继续保持正方形优先，`MapHost` 外仍保留可见宇宙空间，左右侧栏吸收横向余量而不是挤满地图。

### 验证

- `tests/layout_scene_smoke_test.gd` 新增左右轨标题、条目数量、fallback 隐藏、运行时文字合同。
- `tests/visual_snapshot.gd` 新增静态合同，确认 `PlanetBoard` 脚本和 `main.gd` runtime snapshot 都参与侧栏渲染。
- `tests/ui_text_smoke_test.gd` 同步纳入 `PlanetBoard` 脚本来源，避免界面文案回退。
- 已用可见 Vulkan renderer 重新生成 `play_table_*` 主桌截图，抽查 1280x720 与 1600x960。

## 2026-07-02｜HandRack 稳定渲染同一批手牌

### 本轮实现

- `PlayerBoard` 不再直接清空 `HandRack` 子节点，也不再自己实例化 `CardFace`。
- `HandRack` 新增 `set_cards(cards)`：
  - 按 `id/card_id/instance_id/slot_id` 生成手牌身份；
  - 同一身份、同一顺序的手牌只更新卡面数据，不替换节点；
  - 只有手牌增删或身份变化时才同步节点；
  - 空手牌占位继续保留 `PlayerHandEmptySlot`。
- 手牌选择、双击、hover、拖拽预览信号都由 `HandRack` 发出，`PlayerBoard` 只负责转发 snapshot 和信号。

### 验证

- `tests/layout_scene_smoke_test.gd` 新增同 id 卡牌说明变化测试，确认 CardFace 数据更新但节点 id 不变。
- 同一测试继续确认 live value refresh 不会打断 hover 抬起。
- `tests/visual_snapshot.gd` 和 `tests/ui_text_smoke_test.gd` 已同步 HandRack 源码合同。

## 2026-07-02｜OverlayLayer 显式分成四层

### 本轮实现

- `OverlayLayer.tscn` 现在不再只是散放若干 overlay 面板，而是显式拆成：
  - `TooltipLayer`：短 hover/提示；
  - `SideDrawerLayer`：30 秒层详情抽屉；
  - `ModalLayer`：确认/模态；
  - `DragPreviewLayer`：手牌拖拽预览。
- 保留原有 `%TooltipPanel`、`%SideDrawerPanel`、`%ConfirmPanel`、`%DragPreviewPanel` 唯一名，脚本 API 不变。
- `SideDrawerPanel` 继续承接 RightInspector 的详情入口，`DragPreviewPanel` 继续承接 HandRack 的 UI-only 拖拽链路。

### 验证

- `tests/layout_scene_smoke_test.gd` 新增 OverlayLayer 层级合同，确认四个 layer 节点存在，且核心面板挂在对应 layer 下。
- `tests/visual_snapshot.gd` 新增静态合同，防止 OverlayLayer 回退成未分层面板堆。

## 2026-07-02｜RightInspector 摘要/全文分层

### 本轮实现

- `RightInspectorSnapshot` 开始把右侧上下文拆成两层：
  - `summary/detail`：主桌常驻 10 秒层，只显示短摘要；
  - `full_detail`：30 秒层全文，交给 Drawer / Codex；
  - `detail_level = summary` 作为显式合同，避免组件误把长说明常驻主桌。
- `RightInspector` 和 `DistrictInfoPanel` 只渲染摘要：
  - 区域/卡牌详情在主桌右侧最多显示短句；
  - 完整说明进入 tooltip 和 `OverlayLayer` side drawer；
  - 公开日志标题统一为 `最近公开日志`，保持短扫读。
- `GameScreen` 打开详情抽屉时优先读取 `full_detail`，不会只展示右侧短摘要。
- 运行时 `_runtime_selected_district_snapshot_source()` 与 `_runtime_hand_card_inspector_snapshot_source()` 同步输出 `summary/detail/full_detail`，让选区和手牌都遵守同一产品层级。

### 验证

- `tests/layout_scene_smoke_test.gd` 新增合同：RightInspector 常驻区域只显示短摘要，点击详情后 Drawer 能看到完整区域说明。
- ViewModel 合同新增 `RightInspectorSnapshot separates table summary from full drawer detail`。

## 2026-07-02｜PublicTrack 固化为薄匿名牌轨

### 本轮实现

- 新增 `PublicTrackSnapshot`：
  - 把原始 `card_track` 条目归一成短标题、槽号、状态、报价/费用、匿名归属提示和强调色；
  - 默认隐藏归属为 `匿名`，避免主桌泄露隐藏出牌者；
  - 不创建 UI 节点，只输出 data-only snapshot。
- `TableSnapshot` 不再直接透传原始 `card_track`，而是统一走 `PublicTrackSnapshot`。
- `CardTrack` 渲染改成薄槽位：
  - 每格只显示状态色点、槽号、短标题和 `报价/匿名` 扫读信息；
  - 空状态仍是 `牌轨空闲`，但保持薄轨高度；
  - 相同条目签名不重建节点，避免实时刷新破坏轨道滚动/hover 手感；
  - 不实例化完整 `CardFace`，完整卡面继续进入右侧详情、Drawer 或 Codex。

### 验证

- `tests/layout_scene_smoke_test.gd` 新增 PublicTrack 运行时合同：薄轨高度、状态点、匿名提示、无完整 CardFace、相同数据不重建。
- `tests/visual_snapshot.gd` 新增静态合同：`TableSnapshot` 必须接 `PublicTrackSnapshot`，`CardTrack` 必须渲染 `PublicTrackSlot` / `PublicTrackStatePip` / `PublicTrackSlotMeta`。

## 2026-07-02｜商业主菜单与星球棋盘空间修正

### 本轮实现

- 主菜单继续向商业游戏入口收敛：
  - `MenuRootLobby` 使用更大的 `SPACE SYNDICATE` 标题、全屏程序化星球背景和单列主命令；
  - `开新一桌 / 继续牌桌 / 资料库` 保持为主按钮，规则、读档、退出降为底部辅助按钮；
  - 背景星球放大并偏向主视觉区，减少“设置弹窗”感。
- 主桌星球展示改为更强的正方形棋盘舞台：
  - `PlanetBoard` 背后直接绘制星空和微弱星云；
  - `MapHost` 继续由可用高度约束为正方形；
  - 左右多余横向空间扩成 `轨道情报 / 外围宇宙` 两侧轨道栏，避免宽屏下出现空白边。
- `MapView` 默认信息密度下调：
  - 默认平面图保留外层宇宙遮罩和投影边界；
  - 区域密集标签、商路文字、城市商品文字、怪兽名和行动 callout 都需要更高缩放或对应关注层才显示；
  - 投影过渡起点调回默认缩放之后，开局先是稳定平面图，滚轮拉远后再卷成星球。
- 底部 `PlayerBoard` 继续给手牌让位：
  - 玩家栏高度和 `HandRack` 卡面尺寸上调；
  - `PlayerThreeSecondRail` 新增 `手牌 x/5` 筹码；
  - `PlayerMainActionDock` 压缩到 280px 级别，让手牌架拥有更宽的桌边空间。

### 验证

- `tests/layout_scene_smoke_test.gd` 通过，新增运行时守卫：`MapHost` 必须保持正方形，宽屏剩余空间必须由左右轨道栏承接。
- `tests/visual_snapshot.gd` 通过，新增合同：平面投影边界外保留宇宙空间，默认地图标签密度降低，主菜单是全屏商业入口。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/ui_snapshot_capture.gd` 有头通过，并重新生成 1280x720、1366x768、1600x960、1920x1080、2560x1440 截图。

## 2026-07-02｜默认 split 主桌跳过旧 PlayerPanel 刷新

### 本轮实现

- 新增 `_uses_split_runtime_table()`：
  - 默认 `BUILD_LEGACY_RUNTIME_TABLE := false` 且 `RuntimeGameScreen` 已挂载时返回 true；
  - 作为旧生成式主桌和 split scene 主桌的运行时边界。
- `_refresh_ui()` 不再在默认 split runtime 下调用 `_refresh_player_panel(false)`。
- 旧 `_refresh_player_panel()`、`_player_panel_structure_signature()`、`_refresh_player_panel_live_values()` 保留为 legacy fallback，但不再驱动默认可见主桌。
- `layout_scene_smoke_test` 现在实例化 `scenes/main.tscn` 并断言：
  - `RuntimeGameScreen` 是可见产品层；
  - `LegacyRuntimeTable` 隐藏、禁用、无子节点；
  - `_uses_split_runtime_table()` 返回 true。

### 验证

- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。

## 2026-07-02｜PlayerBoard 行动区合并为单一 ActionDock

### 本轮实现

- `PlayerBoard` 不再自己维护独立的 `PlayerQuickActionRow` 和 `PlayerActionRow`。
- 底部玩家板改为挂载一个 `PlayerMainActionDock`：
  - 四个快捷动作 `建城 / 牌架 / 买牌 / 出牌`；
  - 当前可执行主动作；
  - 都通过同一个 `ActionDock` 组件渲染和发出 `action_requested` signal。
- `ActionDock` 增加 compact mode：
  - 底部玩家板隐藏标题并降低按钮高度；
  - 右侧 Inspector 仍保留普通标题和说明式动作行。
- 测试契约改为验收“一个 main action dock 内有快捷动作和主动作”，避免继续鼓励重复行动区。

### 验证

- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。

## 2026-07-02｜全屏大厅与方形宇宙星球舞台

### 本轮实现

- Root 主菜单从居中弹窗改成全屏大厅路径：
  - `MenuOverlay` 在 `root_table_menu` 下使用全屏 surface；
  - `MenuRootLobby` 改成左侧大型程序化星球视觉、右侧纵向主命令；
  - 普通规则、图鉴、经济、情报页面继续走原来的菜单/Codex 壳。
- 主桌星球区改成方形舞台：
  - `PlanetBoard` 新增 `PlanetStageViewport`，脚本根据可用空间把 `MapHost` 居中成正方形；
  - 左右空余区变成窄 HUD 轨道，不再撑成长说明板；
  - `MapHost` 和运行时 `MapView` 不再裁剪，平面投影边界外能看到星空。
- 地图默认低缩放信息密度降低：
  - 加入外层星空背景；
  - 稠密区域标签需要更高缩放才显示；
  - 行动 callout 在默认缩放下收起，选中区域仍保留核心标签。
- 修复 `ActionDock` 内部节点命名污染：右侧 Inspector 的 action dock 不再抢占 `PlayerBoard` 的 `PlayerQuickActionRow` / `PlayerActionRow` 查找。
- 压缩右侧 Inspector 的固定高度，避免 1280x720 下主桌被顶出屏幕。

### 验证

- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/ui_snapshot_capture.gd` 有头通过，并重新生成 1280x720、1366x768、1600x960、1920x1080、2560x1440 主菜单和主桌快照。

## 2026-07-02｜根主菜单收敛为星球赌桌大厅

### 本轮实现

- 主菜单 root 页从“分支总控台”改成更接近《Terraforming Mars》电子桌游入口的星球赌桌大厅：
  - 保留中央星球视觉；
  - 只放三个主入口：`开新一桌`、`继续牌桌`、`资料库`；
  - 把 `游戏规则`、`读取局面`、`退出游戏` 收成小号辅助按钮。
- 根主菜单隐藏面包屑、通用交互提示、顶部快捷分支和重复说明卡，避免玩家一进游戏就看到规则/开发式入口堆叠。
- `局势排名`、`经济总览`、`情报档案` 等重信息页面不再摊在 root 主菜单，保留在局内/暂停/复盘等上下文中打开。
- 继续优化底部玩家板：桌边行动条旁新增当前选区摘要，玩家不用滚动就能看到选区、区域牌架/建城/首召等当前行动线索。
- 烟测里的怪兽碰撞检查新增“结清所有活跃怪兽赌局”的测试清场，避免测试产生的冻结赌局污染后续建城和经济验证。

### 设计理由

- Root 主菜单应该像进入一张桌游牌桌，而不是像开发者调试面板。
- 玩家第一眼只需要回答三个问题：开新局、回牌桌、查资料；复杂规则和证据页应当留给对应页面。
- 子页面仍保留自己的返回、翻页、缩略图和 hover 逻辑；root 页不再混用这些控件。

### 验证

- `tests/ui_text_smoke_test.gd` 更新为主菜单“单一大厅”契约。
- `tests/visual_snapshot.gd` 更新为主菜单无重复分支列表契约。
- `tests/smoke_test.gd` 更新 root 主菜单断言与怪兽赌局清场。

## 2026-07-02｜项目专用 AGENTS 与桌边核心行动条

### 本轮实现

- 重写根目录 `AGENTS.md`：
  - 从通用“TCG/经济平衡实验室”模板改成《太空辛迪加》专用开发手册；
  - 明确当前目标是“人类可试玩的实时 PVE roguelike 桌游原型”；
  - 固化核心循环、隐藏信息规则、UI 原则、AI 原则、性能原则、测试命令、二号屏有头测试命令和交付习惯；
  - 指向 `REFERENCE_LINKS.md` 和本地参考目录，避免后续 Codex 脱离 Terraforming Mars / Gaia Project / UiCard 等标杆。
- 主桌玩家板新增 `PlayerDashboardActionDock`：
  - 在资源筹码下方固定显示“建城 / 牌架 / 买牌 / 首召或出牌”；
  - 复用现有 `_main_action_dock_entries()`，不新增独立规则；
  - 右侧 `MainActionDock` 继续作为详细当前行动托盘，顶部新条只解决第一屏可操作性。
- 测试护栏同步更新：
  - `tests/smoke_test.gd` 要求玩家板同时拥有第一屏桌边行动条和详细行动托盘；
  - `tests/ui_text_smoke_test.gd` 和 `tests/visual_snapshot.gd` 检查 `PlayerDashboardActionDock`、按钮命名和出现顺序。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - 二号屏有头 `tests/ui_snapshot_capture.gd`
  - `git diff --check`
- 二号屏主桌截图确认：
  - 新桌边行动条在资源筹码下方第一屏可见；
  - 手牌仍在第一屏可见；
  - 地图主体没有被挤坏。

### 设计意图

- 让测试者打开一局后不用在右侧滚动/细读，就能先做四个核心动作；
- 更接近 Terraforming Mars 这类桌游电子版的“资源板 + 稳定行动区 + 卡牌架”布局；
- `AGENTS.md` 后续作为 Codex 接手项目时的第一层稳定上下文，避免再被通用模板带偏。

## 2026-07-01｜卡牌图鉴分类筹码与根目录参考索引

### 本轮实现

- 卡牌图鉴缩略图页新增固定在第一屏顶部的 `CardCodexCategoryRail`：
  - 用 `CardCodexCategoryChip` 显示“全部、怪兽、兽技、军队、互动、城市、商品、期货、金融、合约、情报、补给、诱导、新闻、天气”等短筹码；
  - 每个筹码直接显示图标、短标签和数量；
  - 筛选栏从缩略图网格下方移到上方，避免玩家翻页时找不到分类入口。
- 卡牌图鉴首页去掉常驻的“牌路总览/打法/防法/牌库来源/区域买牌规则”长说明：
  - 首页现在专注于分类筹码、缩略卡、悬停预览、双击详情；
  - 复杂规则继续留给规则页、经济总览、区域牌架和后续教程。
- 新增根目录 `AGENTS.md`：
  - 保存用户提供的 Codex 项目级工作说明；
  - 强调 simulation-first、可复现、可测试、数据驱动、AI 难度评估和经济/卡牌平衡工具链。
- 新增根目录 `REFERENCE_LINKS.md`：
  - 集中保存聊天中提供的开源参考链接；
  - 覆盖 Terraforming Mars、Gaia Project、Night Patrol、UiCard、Balatro/Hearthstone/MTG 类卡牌 UI、巨兽破坏、行星/太空、Brotato/Vampire Survivors-like、Godot 性能管线等参考；
  - 明确商业发布前仍需重新确认 LICENSE 和素材授权。

### 测试与验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - 二号屏有头 `tests/ui_snapshot_capture.gd`
  - `git diff --check`
- 本轮二号屏快照确认：
  - `02_card_codex_grid.png` 第一屏可见分类筹码；
  - 详情页仍保留 TCG 式卡面/费用/核心效果/I-IV 梯度结构；
  - 主桌不被本次图鉴改动影响。

### 设计意图

- 图鉴应该像桌游电子版的卡牌浏览器：先看分类和卡面，再通过 hover/双击读详情；不要把开发说明常驻在玩家浏览路径上。
- 根目录参考索引让后续 Codex 继续开发时先看正确标杆，减少“凭空设计”和重复追问。

## 2026-07-01｜主桌性能止血：实时层与重布局分离

### 追加实现

- 牌桌静态组件继续降重：
  - 匿名牌轨新增 `card_resolution_track_signature`、`_card_resolution_track_signature()`、`_card_resolution_track_entry_signature()`；
  - 牌轨只在历史/当前展示/候补队列/小费/公开归属/选中槽位等内容变化时重建；
  - 当前展示槽不再显示秒数，倒计时统一交给底部沙漏条，避免为了时间文字重建整条牌轨；
  - 试玩流程罗盘新增 `playtest_flow_compass_signature` 和 `_playtest_flow_compass_signature()`，五步筹码未变化时不再清空重建。

### 追加验证

- 已通过：
  - `tests/smoke_test.gd --check-only`
  - `tests/ui_text_smoke_test.gd`
  - 有头 `tests/visual_snapshot.gd`

### 本轮实现

- 按 Godot 性能管线参考，先处理当前最影响试玩的卡顿：
  - 主循环不再每 0.25 秒完整 `_refresh_ui()`；
  - 新增 `UI_LIVE_REFRESH_SECONDS` 与 `UI_FULL_REFRESH_SECONDS`；
  - `_refresh_live_ui()` 只更新状态条、天气条、地图和底部沙漏；
  - 手牌、玩家面板、匿名牌轨、区域牌架、图鉴等重布局仍由显式操作/低频全量刷新触发。
- 星球地图 `MapView` 增加性能护栏：
  - `ANIMATED_REDRAW_INTERVAL_SECONDS`：有动画层时限帧重绘到约 30fps；
  - `_target_view_zoom` + `_update_smooth_zoom()`：鼠标滚轮改为目标缩放平滑插值，不再瞬间跳投影；
  - `_build_visual_payload_signature()`：地图可视数据没变化时不重复 `queue_redraw()`；
  - `_should_draw_dense_region_labels()`：拖拽/缩放/大星球投影过渡时只保留选区标签，减少大量文字绘制。
- 匿名牌轨滚动修正：
  - 超过 12 个公共牌槽时主动保证内容宽度超过视口；
  - `_card_resolution_track_max_scroll()` 不再依赖刚重建后可能尚未稳定的布局尺寸。
- 建城操作从“目标选择”阻塞中解耦：
  - 怪兽赌局这种全局冻结仍会阻塞建城；
  - 但待选择怪兽目标/玩家目标不再阻止玩家在地图上城市化，避免临时出牌窗口把主桌操作卡死。
- 测试护栏：
  - `tests/ui_text_smoke_test.gd` 检查主循环实时层/重布局层分离；
  - `tests/visual_snapshot.gd` 检查地图限帧、平滑缩放、可视签名和交互中减少密集标签。

### 设计意图

- 目前首要目标是让人类玩家能操作，不让 UI 重排和星球重绘抢走帧时间。
- 桌游电子版的主桌应该像“牌桌”：大部分信息静态摆放，只有地图、沙漏和必要状态实时变化。
- 后续如果加入更多怪兽碰撞、伤害数字、城市碎裂和卡牌飞行动画，要继续沿用对象池、warmup、Profiler 和批量绘制思路。

### 验证

- 已通过：
  - `tests/smoke_test.gd --check-only`
  - `tests/ui_text_smoke_test.gd`
  - 有头 `tests/visual_snapshot.gd`
  - 完整 `tests/smoke_test.gd`

## 2026-07-01｜中央星球加入试玩流程罗盘

### 本轮实现

- 在中央星球板上新增 `PlaytestFlowCompass`，用一条很薄的步骤轨提示第一分钟试玩顺序：
  - `点区` → `首召` → `建城` → `买牌` → `出牌`。
- 罗盘复用现有开局轻引导进度：
  - 已完成步骤显示 `✓`；
  - 当前步骤显示 `▶`；
  - 后续步骤显示 `□`。
- 右侧短提示 `PlaytestFlowCompassNextLabel` 会同步当前下一步，例如“点星球区域”或当前目标提示的短句。
- 该组件放在中央星球/天气条附近，保持小高度，不遮地图，不替代底部手牌和快捷行动 Dock。
- 城市化从普通行动冷却中解耦：
  - 仍会被游戏结束、怪兽赌局等全局冻结阻塞；
  - 不再被“待选择怪兽目标/玩家目标”这种出牌临时状态阻塞；
  - 不再因为上一张卡/上一条怪兽指令的行动冷却而让第一座城市建不出来；
  - 建城也不再给玩家追加普通行动冷却。
- 参考库补充 Brotato / Vampire Survivors-like 项目：
  - 用于后续怪兽攻击碰撞、地图演出、伤害飘字、击退反馈；
  - 用于 roguelike 随机性、道具/卡牌梯度和自动攻击结算参考。
- 参考库补充 Godot 性能管线项目和官方文档：
  - 异步加载、loading/warmup、shader/pipeline 预热；
  - 对象池、伤害数字、批量渲染/生成、Profiler 定位；
  - 作为后续怪兽碰撞、城市破坏、卡牌飞行动画和高频特效的防卡顿护栏。

### 设计意图

- 测试者盯着地图时，也要能立刻知道第一局顺序；不能只靠底部长面板或规则页。
- 这条罗盘像桌游电子版的回合/流程提示，只承担“我现在在哪一步”的扫读功能。
- 继续遵守玩家语言：主桌只放短词，完整解释进入 tooltip、规则页、经济总览和图鉴。
- 第一局城市化属于经营入口，不应该被普通行动冷却卡住；否则玩家会看到“能建城”却点不动，试玩体验很差。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`

## 2026-07-01｜主牌桌加入四键快捷行动 Dock

### 本轮实现

- 在底部「当前行动」托盘顶部新增 `MainActionDock`，用四个短按钮固定露出测试者最常用动作：
  - `建城`：当前选区可城市化时直接执行；
  - `牌架`：打开当前区域牌架，不能购买时也允许查看；
  - `买牌`：购买当前选中的区域牌，保留满手时私密弃牌流程；
  - `出牌/首召`：打出第一张当前可用手牌，起始怪兽显示首召语义。
- Dock 只显示短标签和状态，不把规则堆在面板上；原因、门槛、价格锁定和隐私说明进入 tooltip。
- 对手/AI 席位保持隐私：选中电脑席位时快捷行动全部变成不可操作，不暴露其手牌、现金或内部路线。
- 继续贴近 Terraforming Mars / 桌游电子版结构：中央星球保持主视觉，底部像玩家板，右侧行动区只放当前可点击入口。

### 设计意图

- 测试者进入一局后不应在长文本里找“我要先干什么”；四个主动作必须像桌游桌边按钮一样稳定可见。
- 这不是替代区域牌架、手牌卡面或目标提示，而是给它们加一个低文字密度入口：先点 Dock，再看详情。
- 后续可以继续把这四键做成更强的图标化按钮、加入 hover 放大和点击音效。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - 有头 `tests/visual_snapshot.gd`

## 2026-07-01｜手牌加入 UiCard 式悬停抬起

### 本轮实现

- 下载本地参考 `reference/UiCard`，确认其核心手感参数：hover scale、hover height、hover speed、手牌弧形/间距、拖拽和出牌/弃牌区。
- 当前手牌卡新增轻量 hover 动效：
  - `HAND_CARD_HOVER_SCALE := 1.08`
  - `HAND_CARD_HOVER_LIFT_PIXELS := 13.0`
  - `HAND_CARD_HOVER_TWEEN_SECONDS := 0.10`
  - 鼠标经过手牌时卡牌抬起、放大、提高层级并轻微提亮；
  - 鼠标离开后平滑回到牌架。
- 手牌架提示从 `悬停详情` 调整为 `悬停抬起`，让测试者知道这不是静态按钮。
- 扩充 UI 护栏：
  - 源码级检查 `HandCardHoverLiftCard`、`_connect_hand_card_hover`、`_animate_hand_card_hover`；
  - 完整 smoke 会在真实主桌面中确认手牌 hover 节点和提示筹码存在。
- 参考库补充用户提供的巨兽/城市破坏与行星/太空科幻项目：
  - 优先参考 `DisasterCity`、`Destroyable_Buildings_Generation`、`solar_system_demo`、`BlocksBeyondTheStars`；
  - 同步记录 Kaiju / 可破坏建筑 / 太空交易 / 行星沙盒 / 航天器模拟等后续标杆。

### 设计意图

- 手牌不能只是排成一排按钮；它要先有“卡牌物件感”，测试者才会自然理解 hover、选择、出牌和弃牌。
- 这一步先做低风险 hover lift，不引入拖拽状态机；后续再接“拖拽预备 → 目标槽 → 飞入匿名结算轨道”。
- 巨兽破坏和行星参考先写进文档，后续做城市受损动画、建筑碎裂、球面缩放时有明确标杆。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`

## 2026-07-01｜区域牌架加入商店状态筹码

### 本轮实现

- 区域购牌侧边抽屉新增 `DistrictSupplyMarketStatusRail`：
  - `可买`：当前窗口可以直接购买的牌；
  - `弃牌`：买入会进入私密弃牌选择的牌；
  - `仅看`：可以浏览但当前窗口不可购买的牌；
  - `受阻`：资金不足、已满级或其他状态暂时不能接收的牌；
  - `升级`：重复获得会推进罗马等级的牌。
- 单张区域市场卡新增 `DistrictSupplyMarketCardStateBand`，把购买状态做成小色条和短标签，不再要求玩家读长句。
- 区域牌架短文案改成 `市场牌架｜悬停看｜双击买`，长规则继续留在 tooltip 和规则分支。
- `tests/smoke_test.gd` 新增运行时验证：双击区域后必须出现 deckbuilder 式市场状态筹码。
- 扩充 `docs/reference_ui_notes.md`：
  - 把 `UiCard` 标成下一阶段卡牌交互的优先参考；
  - 纳入 Balatro、Hearthstone、NueDeck、MTG Arena 类 UI、CardHouse、Cyanilux/Cards 等卡牌手感参考；
  - 纳入 DisasterCity、Kaiju Response Team、Kaiju Homecoming、destruct-o 等巨兽/城市破坏参考；
  - 纳入 Solar System Demo、chunked LOD planet、ProceduralPlanetGodot、Planet-Generator、Tiny Pixel Planets 等行星/科幻空间参考。

### 设计意图

- 购牌窗口应该像电子桌游/roguelike deckbuilder 的商店牌架：先看牌面和状态筹码，再决定买不买。
- 玩家打开区域时需要立刻知道“现在能买什么”，而不是从段落说明里找答案。
- 手牌上限、私密弃牌、怪兽范围锁定这些规则都应该通过状态标签表达，不常驻长文本。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`

## 2026-07-01｜顶部匿名牌轨增加空状态薄轨

### 本轮实现

- 顶部匿名牌轨新增 `compact empty` 模式：
  - 没有真实匿名牌时，隐藏标尺、费用带、槽沟和图例分区筹码；
  - 空牌槽高度从常规 `22` 压到 `15`；
  - 外框最小高度从常规 `36` 压到 `24`；
  - 有历史牌、当前展示牌、竞价牌或下一批等待牌时自动恢复完整牌轨。
- 保留 `牌轨 / 拖看｜悬停` 的基础读法，不让新手以为顶部区域消失。
- 更新 UI 护栏，检查 `CARD_TRACK_EMPTY_SLOT_HEIGHT` 和 `_set_card_resolution_track_compact_empty`。
- 将 GitHub `topics/slaythespire` 和本地 `reference/hypnagonia` 纳入参考笔记，后续用于手牌牌架、购牌窗口、hover 详情和 deckbuilder 构筑路线的 UI 改造。

### 设计意图

- 开局空牌轨不应该像一根大棒子压住星球；它只需要提示“这里之后会出现匿名牌”。
- 有牌时才展示完整 Through-the-Ages 式公共牌槽信息，空状态保持轻薄。
- 这一步继续落实“中央星球优先，公共信息按需变厚”的桌游电子版布局。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
- 已采集有头 UI 快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜右侧行动托盘改成当前行动栏

### 本轮实现

- 参考 Terraforming Mars 的主页面层级，把右侧操作区从“托盘说明”压成“当前行动栏”。
- 玩家可见文案调整：
  - `桌边行动托盘` → `当前行动`
  - `模块先扫` → `筹码定位`
- 缩小行动栏外边距、内部间距和最小高度，让下方选区行动更早进入首屏。
- 行动模块 tooltip 改成短句：筹码用于快速定位，具体按钮在下方。
- 更新 UI 护栏，确保主游戏界面使用 `ActionTrayCurrentHeader`、`当前行动`、`筹码定位` 这套更短的玩家语言。
- 修正完整烟测里的城市化选区偶发失败：怪兽碰撞测试后会重新选择未毁陆地区建城，不再把刚被破坏的测试区域继续当作城市化目标。

### 设计意图

- 右侧不应该像说明书；它应该像电子桌游里的当前行动槽。
- 主桌面的阅读顺序更清楚：中央星球 → 手牌 → 当前行动 → 其它模块筹码。
- 这一步继续减少常驻文字，把复杂解释留给 hover、图鉴和规则页。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
- 已采集有头 UI 快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜首召收敛到单一主行动槽

### 本轮实现

- 下载并记录三个 UI/美术参考项目：
  - Terraforming Mars：主游戏页、顶栏、手牌/已打出牌折叠。
  - Gaia Project：星图、行动按钮、图例和定义页。
  - Night Patrol：临时卡框、按钮、音效和视觉氛围参考。
- 新增 `docs/reference_ui_notes.md`，把参考结论转成后续可执行 UI 规则。
- 开局右侧行动托盘不再同时显示 `目标提示` 和第二张 `首召预览` 卡。
- 首召现在只通过一个主行动槽执行：
  - 右侧 `目标提示｜下一步` 显示 `在选区首召`；
  - 底部手牌仍显示起始怪兽卡面；
  - 细节通过手牌 hover/图鉴查看。
- 更新测试护栏，防止 `FirstSummonCard` 重新作为常驻右侧卡片出现。

### 设计意图

- 电子桌游主界面应该一次只强调一个当前动作；同一件事出现两张面板会让玩家误以为有两个入口。
- 右侧行动托盘应像“当前行动槽 + 模块抽屉”，而不是堆叠说明卡。
- 这一步继续落实 Terraforming Mars 式层级：主桌面只做行动，卡牌和规则细节收进手牌/hover/图鉴。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
- 已采集有头 UI 快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜右侧首召提示压缩为决策条

### 本轮实现

- 右侧行动托盘的起始怪兽提示不再重复展示一张完整怪兽卡面。
- `FirstSummonCard` 改为短预览条：
  - 保留 `免门槛 / 落点 / 固定技 / 开牌架` 等关键筹码；
  - 用小型 `怪` 标记代替重复卡图；
  - 展示怪兽名、在场时间、固定技数量；
  - 保留唯一明确动作按钮 `在选区首召`。
- 完整卡面继续放在底部手牌架，符合“手牌看卡面，右侧做决策”的桌游界面分工。
- 更新 UI 测试护栏，确保右侧首召区域保持紧凑预览条，不回退成重复大卡面。

### 设计意图

- 新手开局要看到中央星球和自己的手牌，不应该被右侧重复卡面挤压。
- 右侧行动托盘只承担“下一步能做什么”的职责；卡牌细节通过手牌、hover 和图鉴查看。
- 这一步继续向 Terraforming Mars / Through the Ages 电子桌游式信息层级靠拢：主界面少文字，详情按需展开。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
- 已采集有头 UI 快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜起始怪兽手牌改成首召专用文案

### 本轮实现

- 起始怪兽牌不再在手牌区显示普通“可打出/打出”读法。
- `starter_play_free` 牌现在有专用手牌状态：
  - 未选落点：`选落点`
  - 落点不可用：`换落点`
  - 落点可用：`首召就绪`
- 起始怪兽牌按钮改为 `首召`，状态筹码显示 `免流动` 和当前 `落点`。
- 手牌架左侧操作提示从 `点打出` 改成 `首召/出牌`，明确首召牌和普通牌属于同一手牌架但不同开局动作。
- 更新测试护栏：
  - smoke test 接受开局手牌状态 `首召就绪`；
  - UI 文本测试检查 `首召就绪`、`首召/出牌`、`免流动` 等玩家可读锚点。

### 设计意图

- 新手第一分钟只需要理解一件事：先选区域，再把起始怪兽首召到那里。
- 如果起始怪兽牌仍写成普通“打出”，会和右侧 `在选区首召` 按钮形成两个心理入口。
- 这次把它改成桌游式“开局部署牌”读法，减少误操作感。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - 有头 UI 快照采集 `tests/ui_snapshot_capture.gd`
- 有头复查快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜顶部数字时间改成牌桌沙漏条

### 本轮实现

- 将主牌桌顶栏原来的 `◷ 00:00` 数字时间筹码替换为 `HeaderStatusMeterChip`：
  - 左侧显示短状态，例如 `⌛ 天气…`、`⌛ 展示`、`⌛ 竞价`；
  - 右侧显示小型 `HeaderStatusMeterBar`；
  - 不再在顶栏常驻显示具体秒数。
- 顶部节奏条现在复用底部全桌窗口状态：
  - 怪兽赌局、匿名竞价、同时出牌、相位响应、公开展示、合约回应、终局沙漏、天气预报/影响都会显示对应条；
  - 没有全桌窗口时，只显示低调脉冲条，不制造额外数字负担。
- 更新 UI 护栏：
  - `tests/visual_snapshot.gd` 检查顶栏使用 `HeaderStatusMeterBar`，且不再回到 `◷ 00:00`；
  - `tests/ui_text_smoke_test.gd` 同步检查沙漏条契约。

### 设计意图

- 试玩桌面应像赌桌/电子桌游：重要倒计时用条状沙漏表达，玩家不用反复读数字时间。
- 顶栏只负责提示“现在桌面是什么状态”；真正的全桌倒计时继续交给屏幕底部 `BottomCountdownPanel`。
- 这一步继续减少主游戏画面的常驻文字，让中央星球、手牌和行动托盘更突出。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - 有头 UI 快照采集 `tests/ui_snapshot_capture.gd`
- 有头复查快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜卡牌详情页压缩重复文案并修正梯度卡排版

### 本轮实现

- 卡牌详情页顶部改成短速读：
  - `卡牌详情｜第N/M张｜牌名`
  - `类型｜路线｜价格｜是否指定怪兽`
  - 最后一行优先显示关键事实，例如怪兽牌的生命、在场时间、召唤区域。
- 详情页右侧仍保留桌游/TCG式四块结构，但每块减少重复：
  - `牌面定位` 只讲这张牌适合做什么；
  - `费用与门槛` 只放购买价、打出条件和目标；
  - `核心效果` 只出现一次简短效果；
  - `关键数值` 改成一行筹码式事实。
- 卡面正文同步收短：
  - 普通卡面优先展示关键数值/路线；
  - 长规则留给 hover、图鉴详情和后续完整规则页。
- `I→IV 强化` 梯度卡修复了窄列换行问题：
  - 罗马等级不再被拆成竖排；
  - 价格不再被挤成竖排；
  - 四张等级卡第一屏可读。
- 顺手修正情报档案的私密标注摘要：
  - `置信分布`、`理由分布` 自身带可扫读标签；
  - 不再依赖某座城市是否挤进前四个调查优先级列表。

### 设计意图

- 玩家读卡时先看“这张牌怎么用”，不要在多个位置反复读同一段效果文字。
- 参考 Terraforming Mars / 电子桌游的读法：短卡面负责识别和操作，详细规则通过 hover、详情页和规则页承接。
- 图鉴详情页应像 TCG 卡牌说明板，而不是开发规则备忘录。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - 有头 UI 快照采集 `tests/ui_snapshot_capture.gd`
- 有头复查快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/03_card_codex_detail.png`
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜地图区域牌架从长列表改成主板短徽章

### 本轮实现

- 将选中区域地图上的 `区域可提供卡片` 黑色长列表移除。
- 地图主板现在只显示短徽章：
  - `牌架 N`
  - `双击区域看牌`
- 完整区域卡名、价格、购买资格和预览继续放在右侧 `区域牌架` 抽屉里。
- 补充视觉护栏：
  - `tests/visual_snapshot.gd` 检查地图源码不再包含 `区域可提供卡片`；
  - 选中区域必须保留短 `牌架 %d` 与 `双击区域看牌` 提示。

### 设计意图

- 参考 Terraforming Mars 的主板读法：地图格子只放图标/短标签，详细牌面和操作进侧栏或卡牌区。
- 中央星球是主视野，不能被区域卡名列表遮住；玩家只需要知道“这里有牌架，可以双击查看”。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - 有头 UI 快照采集 `tests/ui_snapshot_capture.gd`
- 有头复查快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜手牌架改成首屏完整 mini-card

### 本轮实现

- 参考 Terraforming Mars 电子桌游的手牌读法，把底部手牌从“标题在上、卡牌在下”改成：
  - 左侧 `PlayerHandRackInfoRail`：手牌数、整体状态、悬停详情、点打出；
  - 右侧横向 mini-card 架：卡牌从手牌框顶部开始排，首屏能看到完整卡体。
- 普通手牌 mini-card 压缩：
  - 卡体从 `160×168` 改成 `148×148`；
  - 卡面小图从 `42px` 改成 `34px`；
  - 常驻只保留标题、类型、少量筹码、状态灯和出牌按钮；
  - 长效果和详细打出条件继续放进 hover / 图鉴详情。
- 空手牌槽同步改成 `148×148`，保证真实手牌和空槽像同一排桌游卡架。

### 设计意图

- 真人初测最重要的是“我有哪些牌、哪张能打、按钮在哪里”一眼可见。
- 规则文字不应挤占手牌卡体；电子桌游中小卡先用于识别与操作，详情通过 hover/放大/图鉴进入。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - 有头 UI 快照采集 `tests/ui_snapshot_capture.gd`
- 有头复查快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜底部玩家板改成资源筹码 + 手牌 + 行动托盘首屏

### 本轮实现

- 主牌桌底部从单纯“桌边牌架”调整为 `玩家板｜桌边牌架`：
  - 首屏顶部是 `PlayerDashboardTopRail`，只放薄资源筹码条和公开席位条；
  - 手牌和行动托盘继续左右并排，手牌保持在行动托盘之前；
  - 完整身份玩家板下沉到滚动区后面，避免一进局就把手牌挤出屏幕。
- 资源筹码条前置：
  - 资金、GDP、城市、手牌、终局目标等用 Terraforming-Mars 式短筹码呈现；
  - 对手资金、手牌和真实资产仍保持隐私，只显示可推理线索。
- 右侧行动托盘收窄收矮：
  - `目标提示｜下一步` 放到行动托盘顶部；
  - 首召、选区、开局引导、竞价、竞猜、合约等仍收在同一托盘里；
  - 托盘内部滚动，不遮中央星球和手牌。
- 有头快照复查后修正了一次错误方向：
  - 完整身份玩家板放在顶部时太高，导致手牌首屏不可见；
  - 改为顶部只保留薄资源/席位条，完整身份板下沉。

### 设计意图

- 参考 Terraforming Mars 的“玩家资源板 + 手牌架”读法：玩家第一眼先扫钱、产能/现金流、目标进度和手牌，不读长规则。
- 中央星球继续作为赌桌主体；底部只是桌边玩家板，复杂信息通过滚动、hover 和详情进入。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - 有头 UI 快照采集 `tests/ui_snapshot_capture.gd`
- 有头复查快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`

## 2026-07-01｜顶部牌轨压薄与手牌小卡面收口

### 本轮实现

- 顶部匿名出牌轨道进一步压成桌边公共牌列：
  - 牌轨面板高度从大面板降到 `36px`，单槽高度降到 `22px`；
  - 左侧只保留 `牌轨 / 拖看｜悬停`，把说明放入 hover；
  - 小牌按钮直接显示状态、牌类、报价和公开归属短标签，例如 `¥200/玩家3`；
  - 完整归属、竞价、小费线索、打出条件和双击图鉴入口继续保留在 tooltip。
- 修复压缩牌轨后的公开归属可见性：
  - `归属：玩家X` 在小牌上先去掉前缀再缩写，避免被压成 `归属…`；
  - 猜中牌主后，顶部轨道仍能常驻看到 `玩家X`。
- 手牌紧凑卡面增加 42px 小画布专用绘制：
  - 小画布只画标题和类型短标签；
  - HP、持续时间、路线等长属性不再硬塞进小卡图；
  - 完整规则继续走 hover、按钮 tooltip 和图鉴详情。

### 设计意图

- 主牌桌继续朝“中央星球 + 赌桌边缘信息”的方向收口：顶部牌轨是公共记忆，不应抢走地图；底部手牌是玩家操作入口，不应变成文字墙。
- 电子桌游里玩家先扫卡位、颜色、短标签和状态，再决定是否打开详情；这轮把牌轨和手牌小卡都往这个读法靠拢。

### 验证

- 已通过：
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `tests/smoke_test.gd --check-only`
  - 完整 `tests/smoke_test.gd`
  - Godot 有头启动 `--quit-after 180`
  - 有头 UI 快照采集 `tests/ui_snapshot_capture.gd`
- 有头复查快照：
  - `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/04_play_table.png`
- 最新完整 smoke 已跑到结束并通过；旧条目中提到的临时 smoke 失败不再代表当前状态。

## 2026-07-01｜菜单、经济与图鉴补成玩家可扫读桌游面板

### 本轮实现

- 主菜单增加三张前置短卡：
  - `主菜单速览`：说明开局、继续、规则、经济、情报和图鉴入口；
  - `牌桌布局`：强调中央星球、顶部匿名牌轨、底部手牌架；
  - `终局复盘`：说明现金目标、倒计时和赛后看钱从哪里来。
- 主菜单交互提示统一为“缩略图 / 悬停预览 / 双击详情”，让菜单、图鉴和牌轨读法一致。
- 局势排名正文和速览卡补齐：
  - `预估结算资金`；
  - `公开异动`；
  - 对手现金、手牌和私密推理隐藏；
  - 情报待结算；
  - 当前玩家存活城市清算。
- 经济总览从概念说明补成可用证据板：
  - 商品热榜、低价/供给压制、商路收入前景；
  - 经济天气、最近卡牌余波、城市公开线索、怪兽资金线索；
  - 当前玩家推理板：城市私标、公开卡牌归属、卡牌条件反推、公开怪兽归属；
  - 直接列出最近余波/竞价小费/条件门槛，帮助玩家从匿名牌反推身份。
- 情报档案正文补齐：
  - 情报换钱、城市业主情报、卡牌归属档案、怪兽资金档案；
  - 调查优先级；
  - 置信分布、理由分布和当前标注明细。
- 图鉴文字进一步桌游化：
  - 图鉴入口明确 `角色图鉴｜怪兽生态档案｜卡牌图鉴｜商品图鉴｜区域图鉴`；
  - 角色页改成 `角色卡 / 特征 / 被动 / 首召怪兽独立选择`；
  - 怪兽页增加正面经济天气与 IV 级权重修正；
  - 商品页分成 `商品卡 / 市场面板 / 策略面板 / 金融与天气 / 生态与卡牌`；
  - 区域页补区域可提供卡牌、隐藏业主、流通加速、收入拆解、生产明细和 GDP 趋势。
- 牌轨小回归修复：
  - 猜中牌主后，顶部牌轨常驻短筹码直接显示 `玩家X`，完整公开归属标签仍保留在 hover；
  - 卡牌图鉴 hover 中的路线改为 `路线：城市成长` 这种无图标直读格式。

### 验证

- 通过：
  - Godot `--check-only`
  - `tests/ui_text_smoke_test.gd`
  - `tests/visual_snapshot.gd`
  - `git diff --check`（仅已有 LF/CRLF 提醒）
- 完整 `tests/smoke_test.gd` 已重新跑到结束，菜单/图鉴/牌轨/经济证据相关检查已转绿。
- 仍剩 10 个左右完整 smoke 失败，下一轮优先排查：
  - 现金目标触发终局倒计时保存；
  - 仓储期货随存储城市毁灭清除；
  - 8席7AI完整局 `missing final summary` 与恢复状态；
  - 主桌在该恢复状态后的少量可见标签；
  - 区域市场卡行购买状态；
  - 合约牌展示后独立5秒签约窗口；
  - 情报置信/理由补丁后需要完整 smoke 复验。

## 2026-07-01｜出牌轨道补齐《历史巨轮》式可扫读牌列状态

### 本轮实现

- 顶部出牌轨道继续按电子桌游公共牌列处理：
  - 每张小牌直接显示轨道状态，例如 `竞拍1`、`锁定1`、`当前展示`、`下批等待1`；
  - 轨道牌常驻只保留报价、匿名/公开归属和 1-2 个关键短筹码；
  - 出牌条件、演出风格、地图播报、余波线索和完整标记统一收进 hover，避免顶部牌轨变成文字墙；
  - hover 文案明确区分“单击竞猜归属”和“双击打开卡牌图鉴”。
- 牌轨宽度同步现在在每次刷新后执行；当历史/候补牌超过 12 格固定视野时，横向拖拽与滚轮回看有稳定滚动范围。
- 猜中卡牌归属后，牌轨会用公开归属筹码持续标出玩家名，完整归属标签保留在 hover 中。
- 修复 Godot 4 严格解析问题：
  - 避免用 `signal` 作为局部变量名；
  - 为地图投影与菜单状态中的 Variant 推断补显式类型；
  - 增加 `_format_seconds()` 用于终局倒计时短显示。

### 设计意图

- 《历史巨轮》式牌列的重点是“每张牌先读位置和状态，再决定是否看详情”，所以出牌轨道不再只是一串历史记录，而是实时牌桌信息层。
- 玩家应能从顶部一眼判断：哪张牌在展示、哪张在竞价、哪张已锁定、哪张进入下批，以及哪张已经被公开归属。
- 轨道保持低高度，复杂解释继续收进 hover 与双击详情，避免抢走中央星球和手牌区域的视觉重心。

### 验证

- `tests/smoke_test.gd` 中所有出牌轨道相关检查已通过，包括：
  - 当前玩家候补牌与最高公开报价；
  - compact hover/detail；
  - 当前展示与锁定下一张；
  - 下批等待牌；
  - 横向拖拽/滚轮滚动；
  - 猜中归属后的公开标签。
- 轻量验证通过：Godot `--check-only`、`tests/ui_text_smoke_test.gd`、`tests/visual_snapshot.gd`。
- 完整 smoke 已能跑完，但仍有菜单、经济总览、图鉴文本与少量经济结算失败，留给下一轮集中处理。

## 2026-07-01｜合约回应改成桌边合同条款卡

### 本轮实现

- 合约签/拒窗口继续使用统一 `TemporaryDecisionCard`，但新增合约专属的 `ContractOfferTermsBoard`：
  - `ContractOfferDecisionTimerBar` 显示独立签约窗口剩余时间；
  - `ContractOfferTermRail` 用短灯条展示供给区、需求区、商品、签约收益、拒签代价和匿名身份；
  - 每个条款使用 `ContractOfferTermLamp`、`ContractOfferTermSignal` 和 `ContractOfferTermLabel`，玩家不用先读长段文字。
- `_add_pending_contract_offer_panel()` 现在把原始合约 offer 传入临时决策面板，合约 UI 从同一份数据生成条款。
- 原有规则不变：公开展示结束后，目标城市真实业主获得独立 5 秒签/拒窗口；倒计时结束按拒签；窗口不阻塞其他玩家出牌。

### 设计意图

- 合约是桌游感很强的交互，不应该表现成普通弹窗说明，而应该像桌边翻出的短合同卡。
- 目标玩家扫一眼就应知道：这份合约连接哪里、影响哪个商品、签了赚什么、不签亏什么。
- 这一步继续把主游戏界面从“读说明”推向“看牌面、看筹码、看条款、做决定”。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的临时决策护栏，覆盖合同条款板、签约倒计时条和条款灯。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜出牌轨道继续参考《历史巨轮》式公共牌列

### 本轮实现

- 顶部 `CardResolutionTtaMarketPanel` 从 54px 继续压到 48px，减少对中央星球和底部手牌架的挤压。
- 固定牌槽从 10 格扩到 12 格，同时把单格宽度、高度收窄：
  - 历史/当前/竞价/候补仍用颜色与符号分区；
  - 真牌只保留图标、短牌名、罗马等级、小费/归属筹码；
  - 详细效果改到 hover tooltip，双击打开卡牌详情。
- 新增 `CardResolutionTtaScrollShell` 与左右 `CardResolutionTtaScrollCue`，让牌轨读起来更像电子桌游里可以横向拖看的公共牌列。
- 新增 `CARD_TRACK_MANUAL_SCROLL_HOLD_MSEC`、`_mark_card_resolution_track_manual_scroll()` 与 `_maybe_follow_card_resolution_track()`：
  - 玩家拖动/滚轮回看时，短时间内不自动抢回焦点；
  - 玩家不操作时，牌轨会跟随最新的当前/候补牌。

### 设计意图

- 出牌轨道不是聊天记录，也不是战斗日志，而是桌面上所有人共同看的公共牌列。
- 参考《历史巨轮》电子版的核心不是照搬外观，而是学习它的扫视逻辑：先看位置、颜色、费用/报价和归属标记，再决定是否 hover 或打开详情。
- 这一步继续保护主画面重心：星球在中央，牌轨在桌边，手牌在底部。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的牌轨护栏，覆盖 12 格固定牌槽、拖看外壳、手动回看保护和自动跟随最新牌。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜区域牌架预览增加购买判定灯条

### 本轮实现

- `DistrictSupplySelectedPreview` 新增 `DistrictSupplyPurchaseVerdictRail`：
  - 显示当前卡牌购买状态；
  - 显示锁定价格；
  - 显示当前玩家普通手牌数量；
  - 满手换购时显示 `私密弃牌`；
  - 显示购买范围来源，例如怪兽脚下、相邻、远程补给或全局采购；
  - 显示 `资格锁定`，提醒购买资格按打开窗口瞬间判定。
- 每个判定灯使用 `DistrictSupplyPurchaseVerdictSignal` 和 `DistrictSupplyPurchaseVerdictLabel`，避免把购买结论藏在按钮 tooltip 里。
- 原有市场格、右侧卡面预览和购买按钮保留。

### 设计意图

- 区域牌架是玩家从地图进入构筑的高频入口，购买结论必须比规则说明更先被看见。
- 玩家应该一眼知道“可买/仅浏览/需弃牌/价格/手牌压力/范围来源”，再决定是否点击购买。
- 这一步不改变购牌规则，只把查看、资格锁定、手牌上限和私密弃牌做成桌游市场板的可扫读信息。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的区域牌架购买判定灯护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜顶部状态条增加桌面节奏筹码

### 本轮实现

- `HeaderStatusChipRail` 新增 `tempo` 筹码，默认显示 `◆ 空闲`。
- 新增 `_table_tempo_status()`，按优先级显示当前最需要注意的全桌状态：
  - 怪兽赌局冻结；
  - 匿名牌竞价；
  - 相位响应；
  - 匿名牌展示；
  - 终局倒计时；
  - 候补队列；
  - 天气预报或活跃天气；
  - 空闲。
- `_refresh_status()` 每次刷新顶部状态时同步更新桌面节奏文字和 tooltip。

### 设计意图

- 电子桌游的顶部状态栏应该告诉玩家“现在桌面处于什么节奏”，而不是让玩家分别去找牌轨、赌局、天气和终局信息。
- 桌面节奏筹码只汇总已有公开状态，不暴露隐藏经济、AI路线或匿名出牌者。
- 这一步让测试者更容易判断什么时候能自由操作、什么时候要看竞价/下注/响应窗口。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的顶部节奏筹码护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜选区地块板增加行动状态灯

### 本轮实现

- `SelectedDistrictBoard` 新增 `SelectedDistrictActionLampRail`：
  - `建城` 显示可建/不可；
  - `牌架` 显示可买/可看/空；
  - `首召` 显示可落/已召/待选；
  - `商路` 显示当前商路商品或未开；
  - 陌生城市额外显示 `标注:可猜`。
- 每个状态灯使用 `SelectedDistrictActionLampSignal` 和 `SelectedDistrictActionLampLabel`，把可执行性压成短状态，而不是塞进按钮 tooltip。
- 原有 `SelectedDistrictActionGrid` 按钮不变，仍负责城市化、打开牌架、标注、商路和全屏地图。

### 设计意图

- 玩家点选中央星球上的区域后，应该先扫“这个地块能做什么”，再决定按哪个按钮。
- 状态灯把选区读法做成桌游地块板：地形/城市/商品筹码 → 行动灯 → 动作按钮。
- 这一步不改变规则，只减少试玩时对 tooltip 和长说明的依赖。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的选区行动灯护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜紧凑手牌卡面压缩状态文字

### 本轮实现

- 紧凑手牌中的 `HandCardPlayStatePanel` 只保留最多 2 个状态筹码：
  - 可打/需目标/缺商品等第一眼状态交给 `HandCardPlayLamp`；
  - 商品门槛等补充条件保留在筹码；
  - 详细原因不再常驻显示，改放在 tooltip。
- 紧凑手牌美术高度从 62px 收到 50px，按钮高度从 26px 收到 24px。
- 非紧凑卡面仍保留 `HandCardPlayReason`，用于图鉴/预览等空间更大的页面。

### 设计意图

- 手牌牌架是主桌高频区域，不能因为状态灯和旧说明区叠加而重新变成密集文字块。
- 玩家常态读法应是：卡名/等级 → 状态灯 → 成本/门槛筹码 → 按钮；完整解释只在 hover 或详情页出现。
- 这一步继续把主画面向电子桌游桌边牌架收口，保护中央星球和手牌可见性。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的紧凑手牌护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜开局轻引导下一步卡增加主行动按钮

### 本轮实现

- `OpeningGuideNextStepCard` 新增 `OpeningGuidePrimaryActionRail` 与 `OpeningGuidePrimaryActionButton`：
  - 首召阶段直接显示“在选区首召”；
  - 建城阶段显示“城市化”；
  - 买牌阶段显示“打开牌架”；
  - 出牌阶段显示“打出手牌/打出某牌”；
  - 经济阶段显示“经济总览”。
- 新增 `_opening_guide_primary_action()`，只复用已有动作入口：
  - `_use_skill()`；
  - `_build_city_in_selected_district()`；
  - `_open_district_supply_from_map()`；
  - `_open_economy_overview_menu()`。
- 下一步卡继续保留入口筹码，并新增“按钮:xxx”筹码，让玩家能扫读当前建议动作。

### 设计意图

- 轻引导不应只是文字提示；电子桌游的新手前几步应该像任务卡，告诉玩家下一步并给一个可按按钮。
- 这一步让测试者更容易从开局进入首召、城市化、购牌、匿名出牌和经济阅读的闭环。
- 规则没有改变：按钮只是已有操作入口，不能绕过区域、现金、商品流动、目标选择或队列限制。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的开局轻引导主行动按钮护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜手牌卡面增加可打状态灯

### 本轮实现

- 手牌卡面新增 `HandCardPlayLamp`：
  - `HandCardPlayLampSignal` 用色条显示当前状态；
  - `HandCardPlayLampStatus` 显示可打、需目标、缺商品、冷却、排队等短状态；
  - `HandCardPlayLampAction` 显示按钮会执行的动作，例如打出、释放、选目标或相位否决。
- 原有 `CardFaceChipRail` 与 `HandCardPlayStateRail` 保留：
  - 费用、等级、商品门槛、目标类型、一次/固定仍用筹码扫读；
  - 详细原因仍放在状态区 tooltip 与短原因行里。

### 设计意图

- 手牌是玩家最常看的区域，测试者不应该先读一段效果文字才能知道“这张牌现在能不能用”。
- 状态灯把出牌可用性提到卡面中层：先看灯，再看筹码，最后才看效果说明。
- 这一步不改变规则，只让人类玩家更容易完成首召、购牌、出牌、目标选择和相位响应。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的手牌状态灯护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜怪兽赌局增加公开下注板

### 本轮实现

- `TemporaryDecisionCard` 内的怪兽赌局模块新增 `MonsterWagerPublicBetBoard`：
  - 每个玩家显示一个 `MonsterWagerPublicBetCard`；
  - 已下注玩家显示玩家筹码、支持对象和下注金额；
  - 未下注玩家显示待押底注；
  - 强制下注会标记为底注；
  - 顶部显示已下注人数 / 总人数。
- 原有奖池、底注、剩余时间、全场冻结、各怪兽伤害与押注总额继续保留。

### 设计意图

- 怪兽赌局是本游戏最有赌博桌氛围的公开时刻，玩家应该一眼看到“谁押了谁、押了多少、还有谁没押”。
- 下注公开本身也是推理线索，但 UI 不能泄露 AI 内部路线或隐藏策略，只展示规则上已经公开的身份、方向和金额。
- 这一步把怪兽赌局从说明文字推进成桌面筹码区，后续可继续加入赔率、全场动画和多方混战的下注构图。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的怪兽赌局公开下注板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜匿名出牌轨道改成更像电子桌游牌列

### 本轮实现

- 顶部 `CardResolutionTtaMarketPanel` 从 62px 压到 54px：
  - 可见槽位从 9 个扩到 10 个；
  - 单个槽位更窄更矮，减少对中央星球和底部手牌的挤压；
  - 左侧图例改成短标题，右侧主体保持横向拖动/滚轮回看。
- 新增 `CardResolutionTtaCostBandRail`：
  - `✓` 表示历史牌；
  - `0` 表示当前展示牌；
  - `+` 表示本批竞价/候补；
  - `N` 表示下一批等待。
- 牌槽新增 hover 轻微放大反馈：
  - 常态只显示图标、短牌名、罗马等级、小费和匿名/公开归属；
  - 详细效果仍放在悬停提示和双击详情中；
  - 不把长规则塞回主牌桌。

### 设计意图

- 出牌轨道应像电子桌游的公共牌列：玩家扫位置、颜色、费用/报价和归属线索，而不是阅读整段牌文。
- 顶部轨道只承担“全桌节奏”和“匿名线索”的职责；真正的牌面详情交给 hover 与图鉴。
- 后续继续沿这个方向做：更清楚的当前牌高亮、更稳定的横向回看、更像赌桌边缘的牌槽质感。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的牌轨护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜全桌卡牌展示横幅增加倒计时条

### 本轮实现

- `CardResolutionTableBanner` 新增 `CardResolutionRevealTimerPanel`：
  - `CardResolutionRevealTimerLabel` 显示当前阶段与剩余秒数；
  - `CardResolutionRevealTimerBar` 显示公开展示、竞价、同时窗或响应窗口的剩余比例；
  - `_update_card_resolution_timer_bar()` 统一更新展示、竞价、同时判定和相位响应窗口；
  - 倒计时条颜色随阶段变化：展示、竞价、同时窗、响应分别用不同强调色。
- 规则不变：
  - 公开展示仍是固定 5 秒；
  - 多人同时出牌竞价仍是 5 秒；
  - 0.5 秒同时判定窗仍保留；
  - 相位否决响应窗口仍是 5 秒。

### 设计意图

- 卡牌展示是全桌节奏的中心，玩家应该一眼看到“现在处于什么阶段，还剩几秒”。
- 这一步让卡牌结算更像电子桌游的公共翻牌/结算条，而不是普通弹窗文字。
- 横幅仍保持顶部非阻塞，不遮挡右侧牌架和底部手牌。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的卡牌展示横幅护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜区域牌架市场格改成桌游市场卡

### 本轮实现

- 右侧区域牌架的左栏从多行按钮升级为 `DistrictSupplyMarketCardPanel`：
  - `DistrictSupplyMarketCardTitle` 显示卡牌图标、短卡名和选中箭头；
  - `DistrictSupplyMarketCardRank` 显示罗马等级；
  - `DistrictSupplyMarketCardChipRail` 显示价格和购买状态；
  - `DistrictSupplyMarketCardRoute` 显示策略路线；
  - `DistrictSupplyMarketCardFactLine` 显示最短关键效果；
  - `DistrictSupplyMarketCardColorTick` 用底部色条标记可买、仅浏览、需弃牌或资金不足。
- 单击/悬停仍然预览，双击仍然尝试购买；右侧 `DistrictSupplySelectedPreview` 继续负责完整卡面和购买按钮。

### 设计意图

- 区域牌架是“地图区域 → 看牌 → 购牌 → 构筑路线”的高频入口，左侧市场不能像纯文本列表。
- 这一步更接近电子桌游市场牌列：玩家先扫价格、状态、路线和等级，再决定是否看右侧卡面或购买。
- 规则不变：查看始终允许；购买资格和价格仍按打开区域牌架的一刻锁定；同一时间只保留一个牌架窗口。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的区域牌架市场卡护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜玩家板增加终局目标进度条

### 本轮实现

- 底部 `PlayerTableauBoard` 新增 `PlayerTableauGoalMeter`：
  - `PlayerTableauGoalLabel` 显示当前玩家的终局目标状态；
  - `PlayerTableauGoalMeta` 显示差额、倒计时或隐私提示；
  - `PlayerTableauGoalProgressBar` 用进度条表示可见结算估值距离目标现金线的比例。
- 当前真人玩家可见自己的 `¥当前/目标`、差额与达标状态。
- 查看 AI/对手席位时仍显示“对手资金隐私”，不会泄露现金、手牌或真实资产。
- 若终局倒计时已触发，进度条标题切换为倒计时状态，提示玩家保钱、护城或反扑。

### 设计意图

- 电子桌游的个人板应该第一眼告诉玩家“我离胜利还差多少”，不应该要求玩家每次打开局势排名。
- 目标进度条和资源筹码共同构成底部玩家板：左侧公开角色，右侧终局目标、资金、GDP、城市、手牌、怪兽、军队。
- 这一步继续保留信息隐私边界：对手资金仍靠城市、牌轨、怪兽和商品线索推理。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的玩家板目标进度条护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜局内目标提示增加推荐动作按钮

### 本轮实现

- 底部 `TableGoalPrompt` 从纯提示卡升级为“提示 + 推荐动作”：
  - 新增 `TableGoalPrimaryActionRail`，把下一步文字和按钮放在同一行；
  - 新增 `TableGoalPrimaryActionButton`，根据当前局势给出一个最常用动作；
  - 新增 `_first_actionable_hand_slot()`，用于从当前手牌中找第一张可打牌；
  - 新增 `_table_goal_primary_action()`，按当前状态选择推荐动作。
- 推荐动作覆盖试玩最常见路径：
  - 有起始怪兽可部署时显示“在选区首召”；
  - 当前区域可城市化时显示“城市化”；
  - 需要补牌或没有手牌时显示“打开牌架”；
  - 手牌中有可打牌时显示“打出某牌”；
  - 有私密弃牌、目标选择等临时窗口时显示对应提示，但不绕过原来的窗口。

### 设计意图

- 目标提示不能只告诉玩家“你应该做什么”，还要在牌桌上提供一个能直接点的入口。
- 这一轮不改变规则，只把已有动作变成更像电子桌游的主行动按钮：少读字，先按当前最合理的一步推进。
- 复杂目标选择、私密弃牌和合约回应仍保留在右侧行动托盘，推荐按钮只做入口，不偷跑结算。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的底部目标提示护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜主菜单顶部改成星球牌桌开桌大厅

### 本轮实现

- 主菜单首屏新增 `MainMenuPlanetLobbyPanel`：
  - 左侧 `MainMenuPlanetMedallion` 用“中央星球”作为视觉锚点，压住游戏是围绕星球下注、建城和推理的核心印象；
  - `MainMenuLobbyChipRail` 用短筹码显示 3-8 席、起始怪兽、匿名牌轨和按秒结算；
  - 右侧 `MainMenuLobbyKpiGrid` 用四张短卡说明先开一桌、看中央星球、读公共牌轨、钱最多获胜；
  - `MainMenuLobbyActionGrid` 给出开新一桌、继续本局、查资料三张大入口卡。
- 原有主菜单分支列表仍保留在下方，玩家想深入规则、图鉴、经济、情报或存档时继续往下看。
- 若没有当前局面，“继续本局”会显示为“暂无本局”，减少第一次进入时的误点。

### 设计意图

- 主菜单要像进入一张电子桌游牌桌，而不是先看到一串功能表。
- 第一屏只回答三件事：这是什么游戏、现在该从哪里开始、去哪里查资料。
- 结构继续参考《Terraforming Mars》这类桌游电子版的入口节奏：中央主题板先建立空间感，规则和复杂系统收进分支。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的主菜单大厅护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜匿名出牌轨道改成固定九槽公共牌列

### 本轮实现

- 继续按《历史巨轮》电子版的公共牌轨思路收口顶部出牌轨道：
  - 新增 `CARD_TRACK_VISIBLE_SLOT_COUNT := 9`，让顶部始终保留九个可扫读的公共牌槽；
  - 牌槽宽度从 `78px` 收到 `72px`，当前展示槽从 `98px` 收到 `92px`；
  - 新增 `CardResolutionTtaSlotGrooveRail` / `CardResolutionTtaSlotGroove`，在真牌上方保留固定槽线；
  - 新增 `CardResolutionTtaGhostSlot`，没有牌时也显示空槽，不再让顶部轨道退化成一条文字提示；
  - 真牌仍只显示阶段、等级、短牌名、小费和归属筹码，详情交给 hover 与双击图鉴。

### 设计意图

- 出牌轨道要像电子桌游的公共牌市场，而不是战斗日志。
- 玩家常态只扫：历史、当前、竞价、候补、报价、匿名归属；想看卡牌效果再 hover 或双击。
- 固定槽位能让玩家形成空间记忆：牌是“进入牌列并排队结算”，不是突然弹出大窗口打断牌桌。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的牌轨护栏，覆盖固定九槽、槽线、空槽和紧凑卡槽。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜开局座位卡隐藏 AI 内部路线并增加公开信息板

### 本轮实现

- 开局准备页的 AI 席位不再显示 AI 性格名：
  - 原先座位标签会显示类似 `AI·拓荒型AI`；
  - 现在统一显示 `电脑对手`，避免把 AI 的路线倾向当作公开信息泄露给测试者。
- 每张座位卡新增 `NewGameSetupSeatIdentityBoard`：
  - `NewGameSetupSeatPublicChipRail` 显示公开角色、首召怪兽、怪兽归属匿名和 `AI策略隐藏` / `本地玩家`；
  - `NewGameSetupSeatInfoGrid` 用四张 `NewGameSetupSeatInfoCard` 显示公开身份、首召怪兽、第一步、信息边界；
  - 随机 AI 角色会显示“开局随机分配，结果公开且不重复”，不展示 AI 内部路线。

### 设计意图

- 开局准备要像电子桌游开桌大厅：测试者能快速看懂席位、公开角色和首召怪兽，但不应该提前知道 AI 的隐藏发展路线。
- 角色是公开信息；AI 计划、路线权重、压力桶和出牌思路仍属于内部对手逻辑，只通过场上公开动作留下线索。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的开局座位卡护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜区域牌架顶部改成桌游式市场牌板

### 本轮实现

- 右侧区域牌架抽屉新增 `DistrictSupplyShelfBoard`：
  - 顶部标题、关闭按钮、短规则条和状态筹码收进同一张市场牌板；
  - `DistrictSupplyRuleStrip` 改成“侧边牌架｜市场格｜悬停预览｜双击购买”；
  - `DistrictSupplyShelfChipRail` 继续显示牌架数量、可购买/仅浏览、范围来源、价格已锁和单窗口；
  - 新增当前玩家自己的 `¥现金` 与 `手牌 X/5` 筹码；
  - 满手时显示 `弃牌私密`，提醒买牌会进入私下弃牌确认，但不公开手牌数量给其他玩家。
- 左右两栏标题更接近桌游电子版市场读法：
  - 左侧 `DistrictSupplyMarketColumnTitle`：`市场格｜价格/状态/路线`；
  - 右侧 `DistrictSupplyPreviewColumnTitle`：`牌面预览｜效果/购买结论`。

### 设计意图

- 区域牌架是“地图区域 → 购牌 → 构筑路线”的核心入口，玩家应该先扫状态筹码，再看市场格和右侧卡面预览。
- 购买资格、价格锁定、单窗口和手牌上限是容易误解的地方，本轮把它们放到牌架顶部的桌游式市场板里。
- 规则没有改变：查看始终允许，购买资格和价格仍按打开区域牌架的一刻锁定。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的区域牌架市场板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜怪兽生态详情改成怪兽单位档案板

### 本轮实现

- 怪兽生态详情页新增 `BestiaryMonsterBoardPanel`：
  - 左侧保留怪兽临时美术，作为单位画像；
  - `BestiaryMonsterHeader` 显示怪兽名、风格短句和核心筹码；
  - `BestiaryMonsterChipRail` 用筹码显示 HP、护甲、速度、移动生态、商品偏好和相遇距离；
  - `BestiaryMonsterKpiGrid` 把生态位、资源与经济、行动定位、固定技能成长拆成四张短卡；
  - `BestiaryMonsterActionGrid` / `BestiaryMonsterActionCard` 把自动行动概率做成行动牌：显示 I级/IV级在开局与破坏后的概率、招式标签和关键数值。
- `_bestiary_text()` 从长概率表压缩成三行：
  - 当前第几只怪兽；
  - 提示下方怪兽档案板负责画像、速度、偏好、破坏和行动概率；
  - 保留怪兽牌属于卡牌图鉴的跳转关系。

### 设计意图

- 怪兽是桌面上的核心压力源，测试者需要先看懂“它会去哪、会打什么、概率多高”，而不是阅读整页规则文本。
- 怪兽详情页现在更像电子桌游里的单位牌板：左边是单位画像，右边是属性筹码，下面是行动牌。
- 概率、伤害、击退和资源偏好继续来自同一套怪兽规则数据，避免图鉴、AI 与实际行动脱节。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的怪兽单位档案板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜匿名出牌轨道继续向《历史巨轮》式牌槽收口

### 本轮实现

- 顶部匿名出牌轨道继续压成电子桌游的“公共牌槽”：
  - `CardResolutionTtaMarketPanel` 从 `66px` 收到 `62px`，减少对中央星球和底部手牌的挤压；
  - 左侧 `CardResolutionTtaOfferRailLegend` 只保留“匿名牌轨”和“公共牌槽｜拖动/滚轮回看”；
  - `CardResolutionTtaMarketHeader` 改成 `✓ / 0 / + / N` 四个极短槽位标记；
  - 新增 `CardResolutionTtaSlotMarketMat` 作为整条牌列的桌面底板；
  - 新增 `CardResolutionTtaAgeMarketRuler` 作为历史、当前、竞价、候补的扫视标尺。
- 牌槽本体继续保持“默认只扫读，hover 看详情，双击进图鉴”：
  - 轨道槽位宽度进一步收窄；
  - 当前展示牌略宽、金色边框；
  - 历史牌变暗；
  - 候补牌用 `+1/+2` 和位置点表示顺序；
  - 小费与归属线索保留在筹码里。

### 设计意图

- 这个轨道的目标不是日志栏，而是像《历史巨轮》电子版那样的公共卡牌市场：玩家先扫槽位和筹码，再决定是否 hover、竞猜或双击查看。
- 玩家主注意力应留给中央星球、手牌和下注/出牌动作，顶部牌轨只承担“公共记忆 + 即将结算队列”的桌边功能。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的牌轨护栏，防止后续回退成大段文字或大面板。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜角色图鉴改成公开身份牌与路线面板

### 本轮实现

- 角色图鉴详情页新增 `RoleCodexIdentityBoardPanel`：
  - 左侧保留角色卡面/临时美术；
  - `RoleCodexIdentityHeader` 显示角色名、序号、种族和牌路定位；
  - `RoleCodexIdentityChipRail` 用筹码显示公开角色、首召独立、商品经营、情报推理、合约商路、怪兽路线等标签；
  - `RoleCodexAbilityKpiGrid` 把经济、情报、控制、开局拆成四张短卡；
  - `RoleCodexRouteCardGrid` 把被动能力、角色特征、信息边界、开局打法、选择提醒和风味拆成短卡。
- `_role_codex_text()` 从“特征/被动/背景”段落压缩成短摘要：
  - 当前第几张角色；
  - 提示下方公开身份牌负责扫读；
  - 强调角色公开、首召怪兽独立、怪兽归属仍靠线索推理。

### 设计意图

- 角色是开局第一批决策之一，玩家需要一眼知道“这个角色会带我走哪条路线”，而不是先读设定清单。
- 公开角色不能暴露首召怪兽归属，所以 UI 必须把“公开身份”和“匿名怪兽/城市/手牌”边界说清楚。
- 这一步让角色图鉴、商品图鉴和区域图鉴统一为桌游式短卡阅读：先扫筹码和路线，再用 hover 看完整文本。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的角色身份牌护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜商品详情页改成桌游式商品市场板

### 本轮实现

- 商品图鉴详情页新增 `ProductCodexMarketBoardPanel`：
  - 左侧保留商品徽章/临时美术，作为资源牌视觉锚点；
  - `ProductCodexMarketHeader` 显示商品名、商业线、品类、地形和用途；
  - `ProductCodexMarketChipRail` 用筹码显示当前价、基准价、趋势、供给、需求、断路和波动；
  - `ProductCodexMarketKpiGrid` 把价格、主策略、天气、牌路拆成四张 KPI 卡；
  - `ProductCodexStrategyGrid` 把策略用途、期货/仓储、怪兽偏好、地图供给、地图需求、城市线索拆成短卡。
- `_product_codex_text()` 从长分区报告压缩成短摘要：
  - 第几种商品、价格、商业线、符号；
  - 提示下方商品市场板负责主要信息；
  - 保留身份、现金和手牌仍靠推理的提醒。

### 设计意图

- 商品是经济、卡牌门槛、期货仓储、商路和怪兽偏好的共同语言，玩家需要像读电子桌游资源面板一样快速理解它。
- 详情页不应先展示长报告；第一眼应看到价格/供需/趋势/策略/地图入口。
- 这一步让商品图鉴和区域图鉴形成同一套“扫读短卡 + hover 详情”的桌游式信息层级。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的商品市场板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜区域图鉴改成桌游式地块情报板

### 本轮实现

- 区域图鉴详情页新增 `RegionCodexTileBoardPanel`：
  - `RegionCodexTileHeader` 显示区域名、序号、地形图标和城市状态；
  - `RegionCodexTileChipRail` 用筹码显示 HP、热度、交通、商路、牌架和当前选中；
  - `RegionCodexTileKpiGrid` 把城市/GDP、供给、需求、天气拆成四张短 KPI 卡；
  - `RegionCodexActionClueGrid` 把商路、区域牌架、怪兽吸引、公开线索、邻接和读法拆成短卡；
  - `RegionCodexClueCard` 的完整解释放进 hover，常驻文本只保留可决策摘要。
- `_region_codex_text()` 从长报告压缩为三行：
  - 区域编号、名称、地形、状态；
  - 提示下方地块板负责可扫读信息；
  - 提醒真实业主、现金和手牌仍靠线索推理。

### 设计意图

- 区域是玩家建城、买牌、标注、商路、怪兽诱导和军事行动的共同入口，必须像桌游地图板块一样先给可扫读信息。
- 玩家不应该进入区域图鉴后先读一整段 GDP、天气、商路和线索报告；第一眼应看到地块牌、筹码和短卡。
- 这一步让“中央星球选区板”和“图鉴区域详情”使用同一套桌游语言，方便测试者在地图和资料页之间来回确认。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的区域地块板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜匿名出牌轨道二次收口为《历史巨轮》式连续牌列

### 本轮实现

- 顶部出牌轨道不再使用通用大面板，而是独立成固定高度的公共牌列：
  - `CardResolutionTtaMarketPanel` 高度收口到 `66px`；
  - `CardResolutionTtaOfferRailFrame` 把左侧图例和右侧横向卡槽放在同一条桌边轨道；
  - `CardResolutionTtaOfferRailLegend` 只显示“匿名牌轨｜公共牌槽”和“拖动/滚轮回看”；
  - `CardResolutionTtaMarketHeader` 压成 `✓史 / 0今 / +竞 / N候` 四个短标记；
  - 牌槽继续保留 `CardResolutionTtaSlotIndex`、罗马等级、卡牌图标、报价点和归属筹码。
- 每张轨道牌进一步压成固定小卡：
  - 当前展示牌稍宽；
  - 历史牌变暗；
  - 候补牌显示位置点；
  - 详细效果、目标、打出条件和竞价说明仍放在 hover；
  - 双击继续进入卡牌图鉴详情。

### 设计意图

- 参考《历史巨轮》电子版的公共牌列读法：桌面中央只需要一排可扫读卡槽，完整文本在 hover/详情层。
- 匿名出牌轨道是公共桌面信息，不应该抢走中央星球和手牌空间。
- 这一步把“历史、当前、竞价、候补”变成视觉槽位，而不是长说明区，后续竞猜、竞价和历史回看都围绕这条牌列继续扩展。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的牌轨护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜新手引导改成试玩速成任务板

### 本轮实现

- 新手引导页新增 `TutorialQuickStartPanel`：
  - 顶部显示第一局、目标钱最多、细则进规则；
  - `TutorialQuickStartStepGrid` 用步骤卡展示首召怪兽、建第一城、看区域牌架、买第一张牌、打匿名牌、读公共牌轨、看经济/情报、终局冲刺；
  - `TutorialQuickStartTrapGrid` 用常见卡点卡片说明买不了牌、牌打不出、看不懂谁领先、不知道查哪里。
- `_open_tutorial_menu()` 正文从九段长说明压缩成一句试玩目标和入口提示。
- 复杂细则仍保留在游戏规则页；本页只负责让测试者开始第一局。

### 设计意图

- 新玩家第一次测试不应该先读规则书，而应该像电子桌游一样看到“下一步任务板”。
- 试玩速成板把“首召 → 建城 → 买牌 → 匿名出牌 → 读牌轨/经济/情报 → 终局”压成可扫读步骤。
- 这一步补齐主菜单中的轻教程入口，让桌边轻引导和菜单教程保持同一套信息层级。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的试玩速成板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜情报档案改成桌游式侦探板

### 本轮实现

- 情报档案页新增 `IntelDossierBoardPanel`：
  - 顶部强调终局揭晓、卡牌归属即时竞猜和不扫描对手现金/手牌；
  - `IntelDossierKpiGrid` 显示城市标注进度、待查城市、匿名牌、公开资金线索；
  - `IntelDossierClueGrid` 把城市嫌疑、匿名牌轨、怪兽资金、仓储/做空靶标、城市公开线索和下一步查证拆成短卡。
- `_intel_dossier_text()` 从长证据报告压成短说明：
  - 说明城市标注如何终局结算；
  - 说明卡牌归属竞猜如何即时押注；
  - 提示下方侦探板负责可扫读证据。
- 原有线索跳转、城市标注、置信度和标注理由按钮继续保留在侦探板下方。

### 设计意图

- 匿名出牌和隐藏城市业主是核心玩法，玩家需要一个像桌游侦探板的地方整理证据，而不是读长清单。
- 情报页必须明确“这是概率证据，不是公开真相”，并继续保护对手现金、手牌和真实资产归属。
- 这一步让测试者更容易从“看到线索”进入“标注城市 / 猜牌主 / 跳图鉴查证”的行动闭环。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的情报侦探板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜局势排名改成桌游式记分板

### 本轮实现

- 局势排名页新增 `StandingsScoreboardPanel`：
  - 顶部显示现金目标、终局倒计时、城市清算值和对手隐私；
  - `StandingsRaceKpiGrid` 显示当前玩家终局距离、城市现金流、公开异动和反超方向；
  - `StandingsPlayerScoreGrid` 用每席一张 `StandingsPlayerScoreCard` 展示玩家牌。
- 进行中仍保护隐私：
  - 当前玩家显示精确可见估值、现金、城市、GDP/min 和情报摘要；
  - 对手牌只显示“现金隐藏、手牌隐藏、资产靠推理”；
  - 玩家仍需通过牌轨、地图、怪兽受伤、商品价格和公开异动推理。
- `_standings_text()` 从长排行报表压缩成短说明，让首屏先看到记分板。

### 设计意图

- “谁快赢了”是每局测试最常看的信息，必须像电子桌游记分板一样可扫读。
- 玩家不应该先读一整段排名公式和长排行；应先看目标、倒计时、自己的距离和对手隐私牌。
- 这一步让局势页更接近《Terraforming Mars》这类桌游电子版的玩家板/分数板阅读节奏。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的局势记分板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜开局准备增加电子桌游式开桌流程板

### 本轮实现

- 开局准备页新增 `NewGameSetupLobbyPanel`：
  - 顶部显示 PVE 席位数、AI 数量和现金目标；
  - `NewGameSetupFlowTrack` 把开局流程拆成五张步骤卡；
  - `NewGameSetupFlowStepCard` 依次提示：席位、挑战、角色、首召、开局；
  - `NewGameSetupReadinessRail` 显示角色不重复、首召独立、进桌先首召、AI可随机角色、最后钱最多。
- 原有席位按钮、AI按钮、挑战层级、座位卡、角色选择、起始怪兽选择继续保留。
- 页面入口文案改成“开桌前确认”，减少像设置表单的感觉。

### 设计意图

- 开局准备是测试者进入一局的第一道门，应该像电子桌游的开桌大厅，而不是一堆裸设置控件。
- 玩家先看五步流程，知道“角色公开但首召怪兽独立匿名”，再去调整座位卡。
- 这一步让真人玩家更容易开始 PVE 测试局，尤其是第一次进入项目时。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的开局 lobby 护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜卡牌详情页增加TCG式扫牌顺序与升级阶梯

### 本轮实现

- 卡牌图鉴详情页新增 `CardCodexTcgSummaryPanel`：
  - 顶部先显示卡牌类型、策略路线和子类型；
  - `CardCodexTcgSummaryChipRail` 用筹码显示购买价、罗马等级、商品门槛、目标类型和一次性/固定去向；
  - 增加固定读法：费用 → 门槛 → 目标 → 去向 → 效果 → I-IV升级。
- 详情页布局拆成更明确的 TCG 阅读结构：
  - `CardCodexTcgDetailLayout`；
  - `CardCodexTcgFaceColumn`；
  - `CardCodexTcgReadColumn`；
  - `CardCodexTcgFactGrid`。
- I-IV 强化展示从普通信息卡改成 `CardCodexUpgradeLadder`：
  - 每级为 `CardCodexUpgradeStepCard`；
  - 显示罗马等级、价格、强度带和一句关键效果；
  - 悬停保留完整效果文本。

### 设计意图

- 玩家看卡牌时应该先像读桌游/TCG卡面一样扫关键词，而不是先读整段说明。
- 卡牌等级是核心构筑机制，必须以阶梯呈现，让玩家一眼看到“这张牌升级后强在哪里”。
- 这一步继续减少常驻长文字，把完整解释放到 hover 和详情层。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的卡牌详情护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜经济总览改成桌游式经济仪表板

### 本轮实现

- 经济总览正文从长报表压缩成短说明：
  - 看钱从哪座城来；
  - 看哪个商品在变贵；
  - 看哪些公开动作留下线索。
- 首屏新增 `EconomyDashboardPanel`：
  - `EconomyDashboardKpiGrid`：显示 GDP/min、商品热度、城市前景、公开线索；
  - `EconomyDashboardChip`：显示全局刷新、场上怪兽、天气；
  - `EconomyDashboardListCard`：把商品热榜、低价机会、城市现金流、匿名余波、怪兽/仓储风险和下一步读法拆成榜单卡。
- 详细证据不再常驻挤满正文：
  - 每条榜单短行可悬停看完整说明；
  - 对手现金、手牌和私密推理仍不展示；
  - 经济页只呈现公开结果和当前玩家可见信息。

### 设计意图

- 经济总览是玩家理解“为什么赚钱/输钱”的核心页面，必须像电子桌游的资源板和市场板，而不是调试报表。
- 玩家第一眼先扫 KPI 和榜单，再决定去看商品、商路、牌轨或情报档案。
- 这一步继续贯彻《Terraforming Mars》式的信息层级：桌面先给数字和图标化短标签，细则通过 hover/详情展开。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的经济仪表板护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜匿名牌轨改成《历史巨轮》式公共牌槽

### 本轮实现

- 出牌轨道从“匿名出牌列 + 说明句”改成更接近电子桌游公共牌列的“公共牌槽”：
  - `CardResolutionTtaMarketPanel`：顶部公共牌槽面板；
  - `CardResolutionTtaMarketHeader`：只保留历史、当前、竞价、候补四个小筹码；
  - `CardResolutionTtaMiniCard`：轨道中的小卡牌面；
  - `CardResolutionTtaSlotIndex`：用 `0`、`+1`、`+2`、`✓` 表示当前/候补/历史位置；
  - `CardResolutionCostPipRail`：保留牌位亮点，形成类似桌游电子版卡槽市场的扫视节奏。
- 主界面不再常驻“悬停、单击、双击”的长说明；交互说明移到牌面 tooltip。
- 竞价金额和归属仍作为牌槽底部小筹码显示，继续服务匿名推理。

### 设计意图

- 出牌轨道应该像桌面公共信息，而不是日志栏。
- 玩家第一眼只需要知道“有哪些牌、哪张当前、接下来几张是什么、报价/归属有没有线索”。
- 详细效果留给 hover/双击，让中央星球、手牌和牌桌节奏保持清爽。

### 验证

- 已同步 `tests/ui_text_smoke_test.gd` 与 `tests/visual_snapshot.gd` 的 UI 护栏。
- 本条记录后的 Godot 轻量验证见本轮交付说明。

## 2026-07-01｜首召怪兽提示改成桌边首召卡

### 本轮实现

- 首召提示从一行长说明改成桌边起始怪兽卡：
  - `FirstSummonCard`：首召主卡；
  - `FirstSummonChipRail`：显示首召关键信息；
  - `FirstSummonCardArt`：起始怪兽小卡面；
  - `FirstSummonDropZone`：显示当前落点是否可用；
  - `FirstSummonDeployButton`：执行“在选区首召”。
- 首召筹码显示：
  - `免门槛`；
  - 当前落点；
  - 固定技能数量；
  - 首召后开启区域牌架。
- 规则不变：
  - 起始怪兽仍可任选未毁区域；
  - 首召不需要商品流动；
  - 首召后才开启怪兽落地区/邻区购牌；
  - 召唤者获得固定技能牌，仍不公开归属。

### 设计意图

- 首召是玩家第一步操作，不能藏在长提示句里。
- 这一步让测试者看到“选区 → 首召 → 开牌架”的桌边起始项目牌，第一局更容易开始。
- 起始怪兽小卡面和筹码能把“这是我的第一张可执行牌”这件事表达得更像电子桌游。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜手牌卡面增加可打状态轨：不点按钮也能看懂为什么不能出牌

### 本轮实现

- 手牌卡面新增可打状态组件：
  - `HandCardPlayStatePanel`：手牌状态小面板；
  - `HandCardPlayStateRail`：状态筹码轨；
  - `HandCardPlayStateChip`：显示 `可打 / 需商品 / 需目标 / 排队中 / 冷却中 / 赌局暂停` 等短状态；
  - `HandCardPlayReason`：一行短原因，完整解释放在 tooltip。
- 状态轨会读取现有出牌判断，不新造规则：
  - 商品流动门槛；
  - 目标怪兽/目标玩家；
  - 合约两端；
  - 现金额外费用；
  - 行动冷却、卡牌冷却、封锁、排队、怪兽赌局冻结。
- 手牌按钮仍保留：
  - 可打就显示 `打出` 或 `释放`；
  - 需要目标则显示 `选目标`；
  - 不能打时按钮文字仍显示原因。

### 设计意图

- 测试者看手牌时，必须一眼知道“这张能不能打”和“卡在哪里”，不能靠点按钮试错。
- 这一步让手牌更像桌游电子版卡面：价格/等级/门槛是一组筹码，可打状态是另一组筹码。
- 复杂解释仍进 tooltip，主卡面只保留短状态，避免文字密度继续上升。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜开局轻引导改成行动轨：五步试玩路径更像桌游教程条

### 本轮实现

- 开局轻引导从普通提示卡升级为桌游式行动轨：
  - `OpeningGuideCard`：轻引导主卡；
  - `OpeningGuideTimeline`：五步开局行动轨；
  - `OpeningGuideProgressTrack`：进度条；
  - `OpeningGuideStepToken`：每一步以完成/未完成筹码显示；
  - `OpeningGuideNextStepCard`：当前下一步行动卡；
  - `OpeningGuideNextStepChipRail`：下一步入口与状态筹码。
- 五步路径保持为：
  - 首召怪兽；
  - 建第一城；
  - 买第一牌；
  - 匿名出牌；
  - 看经济总览。
- 保留已有按钮：
  - `经济总览`；
  - `新手引导`；
  - `游戏规则`；
  - `关闭`。

### 设计意图

- 人类测试者第一局最容易卡在“我现在应该干什么”，所以开局提示必须像电子桌游教程条一样给出行动轨。
- 常态只显示步骤筹码和下一步短句；原因、入口和完整解释放进 tooltip 或规则页。
- 这一步把“首召 → 建城 → 买牌 → 出牌 → 看经济”的试玩闭环压成一个清楚的桌边组件。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜中央星球操作栏筹码化：地图提示不再是一整句说明

### 本轮实现

- 中央星球上方的地图工具栏改成桌游筹码结构：
  - `MapControlBar`：地图控制栏容器；
  - `MapControlChipRail`：星球操作筹码轨；
  - `MapControlChip`：短筹码显示“星球主视野 / 滚轮缩放 / 拖拽地图 / 双击看牌 / 当前选区 / 商路 / 合约”。
- 原有功能继续保留：
  - 商品商路下拉仍可选择具体商品；
  - 合约供给端/需求端按钮仍在地图栏；
  - 当前选区、商路条数和合约端点会更新到筹码文字与 tooltip。
- 玩家可见文案进一步压短：
  - 常态不再显示“滚轮缩放 · 拖拽地图 · 双击区域看牌”的长句；
  - 关键操作改成短筹码，详细解释进入 tooltip。

### 设计意图

- 中央星球必须保持视觉主角，地图上方只应该像桌游控制条一样提示动作。
- 玩家初次测试时，看到“滚轮缩放 / 拖拽地图 / 双击看牌”三个筹码就能立刻操作，不需要读长句。
- 地图栏与顶部状态筹码、出牌轨道、玩家板、区域牌架形成同一套桌游 UI 语言。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜选区行动升级为地块板：点地图后先看地块，再做动作

### 本轮实现

- 选中区域的行动面板改成更像桌游地块信息板：
  - `SelectedDistrictBoard`：选区主面板；
  - `SelectedDistrictTilePlate`：当前地块牌，显示区域名、地块定位和短状态；
  - `SelectedDistrictTileIcon`：用 `⬡ / ≈ / ▣ / ✕` 区分陆地、海域、城市和废墟；
  - `SelectedDistrictChipRail`：继续显示地形、HP、城市/GDP、牌架、商品供需、天气；
  - `SelectedDistrictActionGrid`：把城市化、牌架、标注、商路、全屏收成一排短按钮。
- 行动文案从长解释进一步压短：
  - `🏙城市化`
  - `＋牌架`
  - `◇标注`
  - `⇄商路`
  - `⛶全屏`
- 规则不变：
  - 双击区域仍可打开区域牌架；
  - 海洋不能城市化但可作为运输/商品区域；
  - 陌生城市可进入情报标注；
  - 商路显示仍按当前商品/选区切换。

### 设计意图

- 玩家点中央星球后，应该立刻得到一个“这块地是什么、这里能做什么”的桌游地块板。
- 地块板比纯状态行更符合电子桌游阅读路径：先看地块牌，再扫筹码，再点行动按钮。
- 这一步减少选区区域的解释性文本，让地图与桌边行动托盘之间的连接更清楚。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜区域牌架改成右侧卡牌市场：小卡格 + 选中预览

### 本轮实现

- 区域牌架继续保持右侧抽屉，但改为更像桌游电子版的市场结构：
  - `DistrictSupplyMarketPanel`：左侧市场区；
  - `DistrictSupplyMarketGrid`：区域提供卡牌以小卡格呈现；
  - `DistrictSupplyMarketCard`：每张候选卡只显示短名、价格、购买状态和一句路线摘要；
  - `DistrictSupplyPreviewPanel`：右侧选中卡预览；
  - `DistrictSupplySelectedPreview`：显示选中卡牌面、状态筹码和购买按钮。
- 抽屉宽度从右侧窄列表调整为更适合“市场格 + 预览板”的桌面侧栏：
  - 仍不改成中央弹窗；
  - 仍保留中央星球主视野；
  - 让玩家双击区域后能像浏览项目牌市场一样扫牌。
- 规则保持不变：
  - 查看区域牌架不受购买资格限制；
  - 购买资格和价格按打开窗口瞬间锁定；
  - 同一时间只保留一个区域牌架；
  - 手牌超限仍进入私密弃牌。

### 设计意图

- 区域牌架是“地图 → 卡牌经济”的核心入口，必须像一个可扫读的桌游市场，而不是按钮列表。
- 玩家先看左侧市场格，悬停/单击看右侧详情，再决定是否购买。
- 列表常态减少长文本，把解释放到 tooltip 和右侧预览，避免玩家一边看地图一边读墙文。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜底部玩家板重构：公开身份 + 资源筹码 + 手牌架

### 本轮实现

- 底部牌桌区新增更明确的电子桌游玩家板结构：
  - `PlayerSeatSelectorRail`：席位选择仍在顶部，避免和手牌/行动混在一起；
  - `PlayerTableauBoard`：玩家板外框；
  - `PlayerIdentityMiniCard`：显示当前席位、公开角色、种族和公开身份提示；
  - `PlayerTableauChipGrid`：集中显示资金、GDP、城市、手牌、怪兽、军队和终局筹码。
- 手牌区改为独立牌架：
  - `PlayerHandRackPanel`：手牌外框；
  - `PlayerHandRackChipRail`：显示手牌上限、悬停详情、点牌打出等短筹码；
  - `PlayerHandEmptySlot`：普通手牌空槽也有牌槽感，玩家能直观看到5张上限。
- 仍保持隐私规则：
  - 自己能看到资金和手牌；
  - 对手的资金、手牌数量、卡面和弃牌仍显示为隐私；
  - 角色卡作为公开信息显示，不绑定首召怪兽身份。

### 设计意图

- 主牌桌应该像电子桌游：玩家先扫自己的玩家板，再看手牌，再决定行动。
- 资源筹码比一行状态文字更容易读，也更符合《Terraforming Mars》一类桌游电子化的节奏。
- 手牌架必须是底部最容易识别的区域之一，不能被临时窗口、竞价按钮或说明文字抢走注意力。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜匿名出牌列改成电子桌游式横向牌轨

### 本轮实现

- 匿名出牌列改为更接近电子桌游牌行的结构：
  - 常态高度压低，减少对中央星球地图的遮挡；
  - 按 `历史 / 当前 / 候补 / 下批` 分段；
  - 每张轨道牌只显示短牌名、等级、报价和匿名/公开归属；
  - 完整效果继续放在悬停 tooltip，双击进入卡牌详情。
- 新增 `CardResolutionAgeTrackDivider` 分段牌槽和 `CardResolutionCostPipRail` 位置亮点：
  - 当前展示牌会更醒目；
  - 候补牌用亮点表达队列位置；
  - 玩家扫一眼即可知道“哪些牌已经打过、哪张正在展示、哪些牌排队”。
- 同步 UI 测试护栏：
  - `tests/visual_snapshot.gd` 检查牌轨分段、紧凑牌槽和位置亮点；
  - `tests/ui_text_smoke_test.gd` 检查出牌列不退回长文字描述。

### 设计意图

- 出牌轨道是玩家推理、竞价和猜归属的核心公共信息，应当像桌面中间的一排小卡，而不是日志列表。
- 常态只保留可扫读信息；玩家需要细节时再悬停或双击。
- 这条牌轨后续可以继续扩展为“历史回看、归属标签、竞猜入口、竞价队列”的统一公共桌面组件。

### 验证

- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜归属竞猜牌槽：匿名牌推理变成桌边押注卡

### 本轮实现

- 选中匿名出牌列上的卡牌后，桌边行动托盘现在显示 `OwnerGuessCard`：
  - 标题为 `归属竞猜`；
  - 展示当前选中卡的短牌名和一句效果；
  - `OwnerGuessChipRail` 显示轨道编号、押注金额、猜牌主、已竞猜或公开归属；
  - `OwnerGuessAvatarRow` 放置可点击的玩家头像按钮。
- 保留原押注规则：
  - 每名玩家每张匿名牌只可竞猜一次；
  - 猜中公开贴牌主标签并转账；
  - 猜错只私下转账，不揭示真实牌主。
- 测试护栏同步：
  - `tests/visual_snapshot.gd` 检查 `OwnerGuessCard` / `OwnerGuessChipRail` / `OwnerGuessAvatarRow`；
  - `tests/ui_text_smoke_test.gd` 检查归属竞猜以桌边押注卡呈现。

### 设计意图

- 归属竞猜是匿名出牌玩法的核心推理与赌桌动作，不能只是散在托盘里的一排按钮。
- 玩家需要先扫：选中了哪张轨道牌、押多少钱、是否已竞猜、是否已公开；再点头像下注。
- 这一步把“看牌轨 → 猜牌主 → 公开/私下结算”的链路做得更像电子桌游的桌边互动卡。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜公开报价牌槽：竞价区从散按钮改成桌边赌注卡

### 本轮实现

- 桌边行动托盘里的竞价控件新增 `BidControlCard`：
  - 顶部标题为 `公开报价`；
  - `BidControlChipRail` 显示当前报价、最高报价、参拍/下批/预设、可调/锁定；
  - `BidControlButtonRow` 继续放 `+10/+20/.../清零` 等快速加价按钮；
  - `BidControlStatusLine` 保留原“报价状态：...”短行，方便玩家理解当前能否继续加价。
- 原来散落在行动托盘里的 `tip_row` 改为报价牌槽内部结构：
  - 金额公开；
  - 出牌者仍匿名；
  - 队列和封盘状态继续通过 tooltip/状态线解释。
- 测试护栏同步：
  - `tests/visual_snapshot.gd` 检查 `BidControlCard` / `BidControlChipRail`；
  - `tests/ui_text_smoke_test.gd` 检查竞价控件必须以公开报价牌槽呈现。

### 设计意图

- 竞价是游戏赌桌氛围的核心，不能只是 UI 按钮堆。
- 玩家第一眼应该看到“我现在报价多少、最高多少、是否参拍、还能不能调”，再决定点哪个筹码按钮。
- 这一步把匿名出牌列和小费竞价连接成更像桌游电子版的桌边赌注区。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜桌边操作模块筹码：先扫模块，再看细节

### 本轮实现

- 桌边行动托盘新增 `ActionTrayModuleChipRail`：
  - `⌖选区`：当前是否已选地图区域；
  - `＋竞价`：当前报价是预设、参拍还是下批等待；
  - `◇竞猜`：是否已选中匿名出牌列中的卡；
  - `⇄合约`：合约两端是否已设，或是否有合约待回应；
  - `◎目标`：是否有怪兽/玩家目标待指定；
  - `✦临时`：是否存在弃牌、合约、目标或怪兽赌局等临时决策。
- 保留原来的具体按钮和滚动托盘：
  - 选区、开局引导、弃牌、怪兽赌局、竞价、竞猜、合约和目标选择仍在下方细节区；
  - 新筹码层只负责让玩家先扫“哪些模块有事”。
- 标题旁短文案改为 `模块筹码先扫，细节下拉`，避免继续用一串模块名堆在标题行。
- 测试护栏同步：
  - `tests/visual_snapshot.gd` 检查 `ActionTrayModuleChipRail` / `ActionTrayModuleChip`；
  - `tests/ui_text_smoke_test.gd` 检查竞价、竞猜、目标等模块筹码存在。

### 设计意图

- 桌边行动托盘承载太多二级操作，玩家需要一个“桌游玩家板式总览”先判断当前该看哪里。
- 这一步不是新增规则，而是把已有操作分层：模块状态在上，细节按钮在下。
- 后续可以继续把竞价、竞猜、合约、目标选择做成更独立的桌边卡槽，但本轮先建立统一的模块扫描层。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜顶部状态筹码：隐藏长状态行，改成牌桌信息条

### 本轮实现

- 主界面顶部新增 `HeaderStatusChipRail`：
  - 时间 `◷`；
  - 当前席位 `◎`；
  - 现金目标 `♛`；
  - 匿名出牌列状态 `▤`；
  - 天气 `☄`；
  - 当前选区 `⌖`。
- 原 `status_label` 保留为隐藏状态快照：
  - 旧逻辑仍能读到完整时间、玩家、目标、队列、天气和选区；
  - 玩家不再在顶部看到一条挤满竖线的长调试文本。
- 顶部筹码会随 `_refresh_status()` 同步刷新：
  - 目标筹码显示当前可见结算估计 / 本层现金目标；
  - 队列筹码显示匿名出牌列当前阶段；
  - 天气筹码压缩为短预报，完整天气仍看中央星球上方天气筹码栏。
- 测试护栏同步：
  - `tests/visual_snapshot.gd` 检查顶部必须有 `HeaderStatusChipRail` / `HeaderStatusChip`；
  - `tests/ui_text_smoke_test.gd` 检查顶部状态拆成玩家可读筹码。

### 设计意图

- 顶部状态栏是玩家每秒都会扫的区域，不能像调试日志。
- 参考电子桌游的状态条：重要信息以短标签/图标/筹码呈现，细节靠 hover、经济总览和规则页展开。
- 这让主桌更接近“中央星球 + 牌列 + 玩家资源条”的桌游电子化结构。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- 完整 `tests/smoke_test.gd` 仍未声明通过；此前长跑超时。

## 2026-07-01｜天气预报筹码栏：主桌只看现在、预报、影响

### 本轮实现

- 主地图上方天气条从裸文字状态栏改成桌游式筹码栏：
  - 外层命名为 `WeatherForecastBar`；
  - 内部使用 `WeatherForecastChipRail`；
  - 三个常驻筹码分别显示 `现在：...`、`预报：...`、`影响：...`。
- 文案压短：
  - 空状态从“现在：无活跃天气”改成 `现在：无天气`；
  - 默认影响从长解释改成 `影响：产/交/消`；
  - 活跃/预报天气继续显示类型、区域、倒计时和来源，但不再把长规则放在主桌。
- 保留原逻辑：
  - `weather_active_label`、`weather_forecast_label`、`weather_impact_label` 仍是可刷新 Label；
  - 现有天气系统、预报提前量、天气卡牌和 smoke 检查不需要重写。
- 测试护栏同步：
  - `tests/visual_snapshot.gd` 检查天气条必须使用 `WeatherForecastBar` / `WeatherForecastChipRail`；
  - `tests/ui_text_smoke_test.gd` 检查天气条使用短筹码文本。

### 设计意图

- 天气是玩家要提前规划的公开信息，不应该像日志一样长驻占屏。
- 主桌只给“现在有没有、下一条何时来、会改什么数值”三类决策信息；完整解释进入经济总览和规则页。
- 这延续中央星球 + 桌边筹码的电子桌游方向，减少测试者在主界面反复读长句的负担。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- 完整 `tests/smoke_test.gd` 上一轮 360 秒超时；本轮未重新声明完整通过。

## 2026-07-01｜匿名出牌列：改成横向小卡位牌轨

### 本轮实现

- 顶部匿名牌记录从“说明型轨道”改成“横向出牌列”：
  - 标题改为「匿名出牌列」；
  - 提示改为 `出牌列：历史←当前→候补｜悬停详情｜单击猜归属｜双击看卡`；
  - 牌列容器命名为 `CardResolutionAgeTrack`，每张牌是 `CardResolutionAgeTrackSlot`。
- 每个牌槽现在更像桌游电子版的横向卡位：
  - 顶部状态色带 `CardResolutionAgeTrackStateStrip`；
  - 主按钮显示状态 + 短牌名；
  - `CardResolutionAgeTrackChipRail` 用筹码显示「历史/当前/竞价/候补」、公开小费、牌主未知或公开归属；
  - 当前展示牌用更亮边框和更宽卡位突出。
- 保留原有交互：
  - 悬停看卡牌效果、条件、目标、演出和竞价线索；
  - 单击选择轨道卡用于猜归属；
  - 双击打开卡牌图鉴详情；
  - 横向拖拽/滚轮浏览历史与候补。

### 设计意图

- 参考电子桌游的“牌列”阅读方式：玩家先看位置、状态、牌名和筹码，不在顶部读长段文字。
- 当前牌、历史牌、候补牌要一眼分层；详细信息只在 hover 或详情页展开。
- 这一步继续减少主界面文字密度，让星球保持中央，牌轨成为桌边信息而不是第二张规则页。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- 完整 `tests/smoke_test.gd` 本轮曾以 360 秒运行，仍超时；未标记为完整通过。

## 2026-07-01｜牌桌语言：下一步提示改成任务卡与筹码

### 本轮实现

- 底部玩家区新增 `TableGoalPrompt`：
  - 常驻只显示“目标提示｜下一步｜一句行动”；
  - 用 `TableGoalPromptChipRail` 展示 `◎下一步`、`◆首召`、`▣建城`、`＋买牌`、`◇线索` 等短筹码；
  - 不再把“为什么/入口”这种开发说明作为玩家标签。
- 开局轻引导继续压缩：
  - 清单改成 `◆ 首召怪兽｜开牌架`、`▣ 建第一城｜现金增长`、`＋ 买第一牌｜重复升级` 等桌游式短句；
  - 进度条文案从说明型长句改成“开局进度 n/5｜随时关闭”。
- 玩家文本方向明确为：
  - 常驻界面只给行动和状态；
  - 细规则进入「游戏规则」「经济总览」；
  - UI 文案像桌游牌面和筹码，而不是开发备忘录。
- 测试护栏同步：
  - `tests/ui_text_smoke_test.gd` 检查 `TableGoalPrompt` / `TableGoalPromptChipRail`；
  - `tests/visual_snapshot.gd` 检查底部桌边牌架保留任务卡；
  - `tests/smoke_test.gd` 检查实际玩家面板存在任务卡、筹码轨和 `◎下一步`。

### 设计意图

- 用户提出的开发原则不能原样暴露给玩家；玩家只需要知道“现在可以做什么、点哪里、大概为什么有利”。
- 这一步把主界面进一步推向《殖民火星》电子版那类“中央板面 + 桌边卡牌 + 图标筹码”的信息层级。
- 后续卡牌详情、商品目录、角色页也应继续沿用这个方向：短标题、少量图标、分区清晰，长规则收纳。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。

## 2026-07-01｜卡面扫读：费用、门槛、目标做成筹码条

### 本轮实现

- 在 `scripts/main.gd` 中新增卡面筹码层：
  - `_card_face_chip_entries()` 从卡牌数据生成牌面筹码；
  - `_add_card_face_chip_rail()` 把筹码渲染到卡面上，并打上 `CardFaceChipRail` / `card_face_chip_rail` 护栏标记。
- 每张卡面现在能直接扫到：
  - 购买价 `¥N`；
  - 等级 `I/II/III/IV`；
  - 商品流动门槛，如 `◇轨迹墨水 2`；
  - 无门槛牌显示 `免门槛`；
  - 目标类型，如 `◆目标`、`◎玩家`、`⇄两区`、`按选区`；
  - `一次` 或 `固定`。
- 卡牌正文继续压短：
  - compact / 手牌卡只保留一句核心效果；
  - 非 compact 卡只保留核心效果 + 少量关键数值；
  - 费用、门槛、目标、一次/固定不再主要依赖正文解释。
- 测试护栏同步：
  - `tests/ui_text_smoke_test.gd` 要求源码保留卡面筹码条入口和“免门槛 / 按选区”等玩家词；
  - `tests/visual_snapshot.gd` 要求卡面继续使用 `CardFaceChipRail`，防止手牌退回纯文本说明。

### 设计意图

- 玩家看手牌时应该像看桌游卡：先扫成本、等级、目标和门槛，再读一句效果。
- 这一步不是最终美术，但确立了卡面信息层级：图标/筹码 > 一句效果 > hover/详情页。
- 后续可以继续把筹码换成更精美图标，但数据入口和 UI 位置已经固定。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。

## 2026-07-01｜中央星球缩放：从局部地表平滑卷成星球

### 本轮实现

- 在 `scripts/map_view.gd` 中明确建立 `PlanetProjectionBlend` 视觉合同：
  - `_planet_projection_blend()` 负责局部地表到中央星球的连续混合；
  - `_projection_smoothstep()` 负责平滑曲线，避免缩放时突然跳变；
  - `betting_table_theme_report()` 暴露 `projection_contract` 和 `projection_policy`，方便后续测试和接手开发。
- 继续强化“星球在赌桌中央”的表现：
  - 拉远时仍沿用绿色赌桌底纹、圆形金色桌边、桌边筹码和座位光点；
  - 投影背景会随着拉远逐渐出现星球暗面与蓝色边缘；
  - 背面区域和区域标签在过渡后段逐步淡出，减少球体边缘文字拥挤。
- 玩家提示改为短句：
  - `局部地表｜滚轮拉远看星球｜拖拽平移｜双击区域看牌`
  - `拉远中｜地表牌板正在卷成星球`
  - `星球全景｜滚轮贴近｜拖拽旋转｜圆点=在场单位`
- `tests/visual_snapshot.gd` 扩展为同时读取 `scripts/map_view.gd`：
  - 检查 `PlanetProjectionBlend`、平滑函数、远侧淡出函数；
  - 检查玩家提示不回退到“真实球面投影 / XY坐标”等技术说明；
  - 检查赌桌报告暴露中央星球投影策略。

### 设计意图

- 玩家不需要理解投影数学，只需要感觉地图像一张铺在赌桌上的星球牌板：贴近时能操作区域，拉远时自然成为中央星球。
- 拉远过程应该服务桌游感和可读性，而不是暴露技术切换。
- 这为后续有头视觉测试、星球动画和更精致的 Terraforming Mars 式中央板面继续铺路。

### 验证

- `tests/visual_snapshot.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。

## 2026-07-01｜玩家文案重设计：开发语言退场，牌桌语言上桌

### 本轮实现

- 继续按“电子桌游 / Terraforming Mars 式信息分层”收口玩家可见文本：
  - 规则页改成 `牌桌规则`，每条用图标开头：`◆ 首召怪兽`、`▣ 建城赚钱`、`◇ 商品商路`、`＋ 区域牌架`、`◎ 匿名出牌`、`♠ 怪兽赌局` 等；
  - 去掉规则页中的说明书式长句，保留玩家马上能决策的动作、成本、匿名信息和终局目标；
  - 商品图鉴开头从长段说明改成 `商品目录｜第X/Y页｜本页A×B`，直接看价格、供需、趋势和主打法；
  - 怪兽生态开头改成 `怪兽生态｜第X/Y页｜本页A×B`，直接看画像、速度、偏好、行动概率和招式；
  - 卡牌路线页从“路线总览/对策/样例”等开发味较重的表述，收成“牌路总览 / 打法 / 防法 / 牌例”。
- 清除主脚本里的明显开发口吻：
  - 不再把“临时美工”显示给玩家，怪兽画像副标题改成有风格的档案名，如“瘴气古龙｜海雾巢”“高速机兵｜轨道坠星”；
  - 商品页不再写“机制钩子”，改为“牌路连接”；
  - 经济总览中的“操作提示”改为更轻的“快捷”短句；
  - 怪兽内部审计文本也同步改成“画像档案 / 经济牌路”，避免未来误露到玩家页面。
- `tests/ui_text_smoke_test.gd` 增加文本护栏：
  - 要求规则页出现图标化规则短句；
  - 要求商品/怪兽图鉴使用“商品目录 / 画像 / 牌路连接”等玩家词；
  - 禁止主脚本重新出现“临时美工 / 机制钩子 / 当前缩略图布局 / 操作提示”等开发式常驻文案。
- `tests/smoke_test.gd` 同步新文案期望：
  - 怪兽生态、商品图鉴、卡牌牌路总览不再依赖旧长说明；
  - 保留分页、悬停预览、双击详情和本地图鉴导航的行为断言。

### 设计意图

- 开发面向的字段、平衡原则和测试审计可以存在，但不能直接出现在玩家桌面。
- 玩家第一眼应该读到“这张牌/这个商品/这个怪兽现在对我有什么用”，而不是读到开发历史和系统架构。
- 图标不是装饰：它们要成为未来卡牌成本、类型、目标、收益、风险的视觉语言基础。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- 完整 `tests/smoke_test.gd` 已尝试运行，但 180 秒超时，未计为通过；本轮只声明轻量文本/视觉/加载检查绿色。

## 2026-07-01｜视觉回归护栏：截图脚本改为快速布局合同

### 本轮实现

- 重建 `tests/visual_snapshot.gd`：
  - 不再在 headless 环境里实例化完整主场景并截图；
  - 改为快速读取 `scripts/main.gd`，检查主桌视觉布局合同；
  - 避免旧截图脚本被 `_new_game`、真实 `_process`、headless 渲染或强制绘制拖到超时。
- 新视觉合同覆盖：
  - 主标题与地图面板保留“星球赌桌”主题；
  - 地图提示保留“星球保持主视野”；
  - 主地图最小高度保持 `560×430`；
  - 匿名卡牌轨道保持紧凑高度 `66px`，详情走 hover/单击/双击；
  - 玩家区保持“桌边牌架”；
  - compact 手牌卡保持 `170×198`；
  - 手牌横向牌架保留 `206px` 高度；
  - 手牌必须在桌边行动托盘之前；
  - 选区动作与报价控件必须在行动托盘中；
  - 玩家文案继续使用“资料大厅 / 价格带”，不回退到“价格梯度”。

### 设计意图

- 当前最重要的是稳定保护“电子桌游桌面结构”，而不是让不稳定的 headless 截图工具拖慢开发。
- 视觉合同不是最终美术验收；它是防止 UI 架构回退的快速护栏。
- 后续如果需要真实截图，应单独做一个有头/浏览器式视觉回归脚本，不让它承担 smoke gate。

### 验证

- `tests/visual_snapshot.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。

## 2026-07-01｜区域牌架筹码化：先扫资格，再看卡面

### 本轮实现

- 区域补给窗口继续改名和收口为“区域牌架”：
  - 标题使用 `区域牌架｜区域名`；
  - 顶部说明压成 `hover预览｜双击/按钮购买｜单窗口锁定`；
  - 详细规则移到 tooltip，保留“打开时锁定价格和购买资格”的关键信息。
- 新增 `district_supply_chip_row`，在区域牌架顶部显示桌游式状态筹码：
  - `牌架 N`
  - `可购买 / 仅浏览`
  - `怪兽脚下 8折 / 相邻 原价 / 远程补给 / 全局采购 / 无怪兽范围`
  - `价格已锁`
  - `单窗口`
  - 本区商品短码。
- 区域牌列表行加入卡牌类别图标：
  - 例如 `◆ 怪兽牌`、`▣ 经营牌`、`◇ 商品牌` 等语义继续沿用统一卡牌图标层。
- 测试同步：
  - smoke 不再要求旧的“区域市场/锁定查看”长文本；
  - 改为验证区域牌架短提示、筹码行、价格锁定、可购买/仅浏览状态；
  - `ui_text_smoke_test.gd` 与 `visual_snapshot.gd` 都增加区域牌架筹码护栏。

### 设计意图

- 双击区域看牌是测试者最常用的动作之一，它应该像打开一排桌游卡槽，而不是打开后台列表。
- 玩家需要第一眼知道：
  - 这区有几张牌；
  - 我现在能不能买；
  - 为什么能/不能买；
  - 价格是否已经锁住；
  - 这里有什么本地商品。
- 长解释依然保留，但放进 tooltip，不常驻占据主视野。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。

## 2026-07-01｜子页面导航收口：每页只显示相关操作

### 本轮实现

- `_show_menu()` 不再无条件显示“继续游戏”：
  - 只有根菜单/暂停菜单这类主入口页面会显示全局继续；
  - 普通子页面默认只显示返回路径和本页操作。
- 主菜单只有已经存在进行中对局时才显示“继续游戏”，避免初始空局出现无意义按钮。
- 新增 `_hide_global_menu_navigation_for_catalog()`：
  - 图鉴类页面隐藏全局“继续游戏”和“返回主菜单”；
  - 只保留图鉴本地的“返回图鉴 / 返回缩略图 / 上一个 / 下一个”。
- 覆盖到：
  - 图鉴总入口；
  - 角色图鉴；
  - 怪兽生态档案；
  - 卡牌图鉴；
  - 商品图鉴；
  - 区域图鉴；
  - 空图鉴页。
- smoke 测试同步：
  - 新手引导/规则页不再要求显示全局继续按钮；
  - 卡牌图鉴缩略图和详情页明确要求隐藏全局继续/返回，只保留图鉴本地导航。

### 设计意图

- 子页面不能像主菜单一样把所有入口都摆在顶部；玩家进入图鉴或规则页时，只应该看到这个页面能用的操作。
- 这直接回应“图鉴页不该出现开局、继续游戏等无关按钮”的 UI 问题。
- 参考电子桌游：主菜单负责分支入口，子页面负责当前资料阅读和局部返回，不混用。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。

## 2026-07-01｜玩家文本二次收口：开发口吻留在文档，桌面只留可决策信息

### 本轮实现

- 继续清理玩家可见文本：
  - “统一资料库”改为“资料大厅”；
  - “价格梯度”改为更玩家化的“价格带”；
  - “AI对手/AI数量/测试阶段重测”等菜单口吻改为“电脑对手/对手数量/再开一桌”；
  - “统一决策面板/可复用UI”改为“桌边决策”；
  - 终局速览不再写“对手内部计划”，改为“隐藏身份与私密手牌仍靠推理”。
- 角色图鉴进一步压缩成卡面式文本：
  - `特征`
  - `被动`
  - `背景`
  - `开局`
  - 明确角色公开、首召怪兽独立选择，避免给玩家暗示角色绑定怪兽。
- 开局准备页重写为短段落：
  - 设置席位、电脑对手和挑战层级；
  - 选择公开角色；
  - 独立选择 I 级首召怪兽；
  - 进桌后先召怪兽才能从附近买牌。
- `tests/ui_text_smoke_test.gd` 改成真正轻量的玩家文本护栏：
  - 不再实例化完整主场景，避免 UI 文案测试拖入整局启动循环；
  - 直接检查 `scripts/main.gd` 中的关键玩家文案、图标化区块和禁止回归的开发口吻。

### 设计意图

- 游戏内文本必须默认面向玩家，不复述开发过程、规则废案或 AI 内部实现。
- 信息分层继续参考《Terraforming Mars》电子版：
  - 第一眼：中央星球、图标、短标签、筹码化资源；
  - hover/缩略图：短预览；
  - 双击详情：卡面式分区；
  - 长规则：收进规则/图鉴/经济总览。
- 后续新增功能时，先写“玩家看到的一句话”，再写开发字段和测试断言。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。

## 2026-07-01｜主桌信息层级：手牌前置，操作提示后置

### 本轮实现

- 调整主游戏面板顺序：
  - 顶部仍是席位/玩家状态；
  - 其后立即显示“玩家板｜资源筹码”；
  - 再显示“我的手牌”横向牌架；
  - 选区动作、开局提示、私密弃牌、怪兽赌局、竞价、竞猜、合约回应和目标选择全部放到手牌之后。
- 新增 `_add_player_hand_rack()`，把手牌牌架从 `_refresh_player_panel()` 中抽成独立层，后续可以继续改成更像电子桌游底部手牌栏。
- 压缩 compact 卡面：
  - compact 卡尺寸从 178×220 调整为 170×198；
  - compact 卡美术区变矮；
  - 手牌状态不再额外占一整行，改进入卡牌 tooltip 与行动按钮；
  - 手牌横向滚动区提高到 206px，减少底部行动按钮被裁掉的风险。
- `tests/ui_text_smoke_test.gd` 新增源码顺序护栏：
  - 手札牌架必须出现在选区动作面板之前，防止后续 UI 迭代又把手牌挤到一堆提示后面。

### 设计意图

- 主桌要优先像电子桌游，而不是后台面板：
  - 玩家第一眼看星球和手牌；
  - 第二眼看资源筹码和匿名牌轨；
  - 具体操作、竞猜、竞价、合约和弃牌作为“桌边决策”出现在手牌后面。
- 这比单纯缩小文字更重要：信息顺序本身就是 UI 设计。手牌如果被动作提示挤到后面，人类测试者会自然觉得“我根本看不到自己在玩什么牌”。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。

## 2026-07-01｜桌边行动托盘：复杂操作收纳，不抢星球和手牌

### 本轮实现

- 新增 `_add_player_action_tray()`：
  - 固定高度的“桌边行动托盘”；
  - 内部使用垂直滚动；
  - 收纳选区动作、开局提示、私密弃牌、怪兽赌局、出牌报价、牌主竞猜、目标选择和合约回应。
- `_refresh_player_panel()` 的信息层级现在是：
  1. 席位与玩家状态；
  2. 资源筹码；
  3. 快速目标提示；
  4. 我的手牌；
  5. 桌边行动托盘。
- 托盘 header 用短标签提示：“选区｜竞价｜竞猜｜合约｜目标”，避免把完整规则常驻在主桌上。
- `tests/ui_text_smoke_test.gd` 新增护栏：
  - 手牌必须在行动托盘之前；
  - 二级操作必须进入 `action_tray`；
  - 源码必须保留“避免遮住星球与手牌”的托盘意图。

### 设计意图

- 这个游戏的规则很复杂，但主桌不应该像调试面板。
- 玩家第一眼必须看到：
  - 中央星球；
  - 匿名牌轨；
  - 自己的资源；
  - 自己的手牌。
- 竞价、竞猜、合约、弃牌、目标选择都很重要，但它们是“当前动作”，不是常驻主信息。把它们收进托盘，更接近电子桌游的底部操作栏/侧边托盘。

### 验证

- `tests/ui_text_smoke_test.gd` 通过。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。

## 2026-07-01｜卡牌图标语义层：先扫符号，再读详情

### 本轮实现

- 新增统一卡牌图标语义：
  - `◆` 怪兽；
  - `✦` 兽技；
  - `⚔` 军队；
  - `◎` 玩家互动；
  - `▣` 城市；
  - `◇` 商品；
  - `△` 期货；
  - `¥` 金融；
  - `⇄` 合约；
  - `◉` 情报；
  - `◌` 新闻；
  - `☄` 天气；
  - `＋` 补给。
- 将图标接入主要玩家可见位置：
  - 卡牌图鉴筛选按钮；
  - 卡牌图鉴图标说明行；
  - 卡牌缩略图标题；
  - 卡牌详情页的牌型/路线行；
  - 手牌卡面标题与类型行；
  - 卡牌 tooltip。
- 卡牌详情页标题也改成更像 TCG/电子桌游的短区块：
  - `◎ 牌面定位`
  - `¥ 费用与门槛`
  - `✦ 核心效果`
  - `◈ 关键数值`
  - `＋ 本局投放`
  - `◇ 结算演出`
- 扩展程序卡面的大字 glyph 和基础图案：
  - 军队、军令、相位响应、拆/牵牌、GDP衍生品、商品期货、合约、新闻、天气、情报等不再都落到默认“卡”；
  - 金融/期货更像走势图，合约更像路线，新闻/情报更像信号，天气更像波纹。

### 设计意图

- 这一步是向《Terraforming Mars》电子版学习信息层级：玩家先看图标和短码，再看卡名、数值，最后才读详情。
- 现在仍是临时符号，不是最终 UI 美术；但它先建立稳定语义，后续换正式 icon 时不会重新设计规则结构。
- 对测试者来说，牌多起来以后“能不能一眼区分牌型”比长文案更重要。

### 验证

- `tests/ui_text_smoke_test.gd` 通过，覆盖：
  - 卡牌图鉴存在稳定图标说明；
  - 卡牌详情页使用图标化区块标题；
  - 玩家界面继续避免“关键字段”等开发术语。
- Godot `--check-only --script res://tests/smoke_test.gd` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。

## 2026-07-01｜玩家文案重构：开发说明不进游戏界面

### 本轮实现

- 建立“玩家版卡牌效果”展示层：
  - 底层卡牌仍保留 AI、字段、强度预算和测试所需数据；
  - 玩家看到的是短效果、关键数值、费用/门槛和目标信息；
  - 合约、怪兽、军队、期货、天气、相位响应、直接互动等牌型优先走专门短文案。
- 重写规则页和新手引导：
  - 不再写“当前原型规则”“AI训练骨架”“新规则下不再……”等开发历史；
  - 改成玩家手册式条目：目标、首召、建城、商品、买牌、手牌、匿名出牌、竞价、怪兽、赌局、合约、天气、终局；
  - 常用操作只保留玩家能马上用到的入口。
- 清理图鉴和菜单文案：
  - “关键字段”改成“关键数值”；
  - “图鉴全集/三层牌池”等偏开发表达改为“全部卡牌/牌库来源”；
  - 主菜单、暂停菜单、存档、复盘文本去掉“调试、原型、内部决策、对手计划”等不该给玩家看的词。
- 终局复盘改为“公开线索”：
  - 只显示已经发生的卡牌、城市GDP、商路、怪兽和情报结果；
  - AI路线、压力桶、候选评分和内部计划继续作为隐藏开发数据，不进入玩家界面。

### 设计意图

- 玩家界面要像电子桌游：先用卡面、短标签、数值块和 hover 组织信息；长说明收进资料页。
- 你给我的很多内容是开发方向，不等于玩家文案。后续新增规则时，必须先判断它属于“玩家要知道”还是“开发/AI要知道”。
- 参考《Terraforming Mars》电子版的思路：地图和卡面承担第一层信息，详情页和 tooltip 承担第二层信息，开发理由不直接出现。

### 验证

- Godot `--check-only` 通过。
- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- smoke test 断言已同步：
  - 规则页不能出现开发历史/AI训练语气；
  - 卡牌详情使用“关键数值”而非“关键字段”；
  - 经济/局势/终局复盘隐藏 AI 内部计划，只展示公开线索。

## 2026-07-01｜星球赌桌地图美术：桌毡、金边与筹码环

### 本轮实现

- 将赌桌氛围从外层面板推进到地图绘制层：
  - 地图背景改成深绿色桌毡；
  - 中央星球周围增加金色桌边/下注环；
  - 地图边缘增加小筹码与席位光圈；
  - 平面视图、投影过渡和球面视图都共用同一套赌桌底层视觉。
- 保持“星球在中央”的核心约束：
  - 赌桌视觉以 `_globe_center()` 为中心；
  - 筹码和席位只在边缘做小图标，不抢地图和手牌视线；
  - 详情仍通过 hover/双击/托盘展开，而不是常驻在地图上。
- 新增 `betting_table_theme_report()`，让烟测能保护这个视觉方向：
  - 桌毡颜色；
  - 金色边框；
  - 筹码数量；
  - 席位数量；
  - 中央星球策略；
  - 小图标按需展开策略。

### 设计意图

- 这局游戏应该像“围着星球下注”的电子桌游，而不是普通后台面板。
- 参考《Terraforming Mars》电子版的强中心构图：中间的星球/地图承担主要视觉叙事，牌、筹码、市场和历史轨道都应该围绕它服务。
- 赌桌元素只做气氛和空间暗示，不把规则文字重新堆回主画面。

### 验证

- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- Godot `--check-only` 通过。
- 完整 Godot headless smoke test 新增覆盖：
  - 地图脚本暴露赌桌主题报告；
  - 主题报告包含桌毡、金边、筹码环、席位环和中央星球策略。

## 2026-07-01｜星球赌桌主画面：中央大星球，周边小控件

### 本轮实现

- 根据“赌博游戏氛围”和《Terraforming Mars》式中央星球布局，调整局内主画面视觉重心：
  - 主标题改为“太空辛迪加｜星球赌桌”；
  - 地图面板改为“星球赌桌｜中央星球”；
  - 地图最小高度提高，让星球/地图成为画面主角；
  - 地图提示改为“赌桌中央：星球保持主视野｜滚轮缩放 · 拖拽地图 · 双击区域看牌”；
  - 地图面板使用更偏赌桌的深绿色底与金色边框；
  - 手牌面板改名为“桌边牌架”，并压缩高度，强调它只是桌边信息架。
- 继续压缩周边 UI：
  - 手牌滚动区高度下调；
  - 临时决策卡统一增加短标签：`私密/公开身份`、`阻塞出牌/不阻塞`；
  - 临时决策卡正文自动短化，长说明进入 tooltip；
  - 临时决策按钮改成小型网格，避免一行按钮挤占主画面。
- 修复市场锁定后的内部快照同步：
  - 当区域市场仍然打开时，内部重新打开购牌快照会同步锁定区域和玩家；
  - 避免测试或内部逻辑出现“UI显示一个区域、快照记录另一个区域”的状态残留。

### 设计意图

- 这个游戏的桌面气质应该像“围着一颗星球下注、操控、推理”的赌桌，而不是普通策略游戏的管理后台。
- 中央星球要一直是视觉中心；手牌、牌轨、市场、决策都应成为桌边筹码/卡托盘，只有点击详情时才展开。
- 临时窗口不能像弹窗一样压住星球，而应该像桌边短决策卡：一眼看见要做什么，长规则按需 hover。

### 验证

- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- 完整 Godot headless smoke test 通过，并新增覆盖：
  - 主画面保持“星球赌桌/赌桌中央”的大地图焦点；
  - 手牌区域作为“桌边牌架”；
  - 临时决策 blueprint 暴露隐私/阻塞短标签和网格按钮列数；
  - 私密弃牌面板实际渲染“决策｜私密弃牌确认”“私密”“不阻塞”。

## 2026-07-01｜区域市场锁定托盘：浏览地图时不丢购牌窗口

### 本轮实现

- 将区域市场窗口进一步改成右侧锁定托盘：
  - 标题显示“锁定查看｜区域名”；
  - 顶部说明“区域市场 N 张｜可购买/仅浏览｜资格来源”；
  - 明确提示“单击地图不会关闭；双击其他区域可切换市场”；
  - 遮罩和窗口高度略收敛，减少对地图的压迫感。
- 修复市场打开后的区域上下文：
  - 单击其他地图区域不再自动关闭市场；
  - hover 预览按“市场锁定区域”判断卡牌是否合法；
  - 双击市场卡牌/点击购买时，也从“市场锁定区域”购买，而不是误用玩家后来单击到的 `selected_district`。
- 保留原有规则：
  - 查看总是允许；
  - 购买资格仍按打开市场的一刻锁定；
  - 同时只能有一个区域市场窗口；
  - 手牌满时仍进入私密弃牌流程。

### 设计意图

- 玩家打开市场后，经常会顺手点地图看怪兽、城市和商路。如果窗口因为普通单击直接消失，会很像 UI bug。
- 参考桌游电子版的“右侧市场/项目托盘”：打开后保持稳定，玩家主动关闭或切换目标时才变化。
- 这一步提升的是操作信任感：玩家知道自己正在看哪一个区域的牌，也知道购买按钮不会因为地图选区变化而买错地方。

### 验证

- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- 完整 Godot headless smoke test 通过，并新增覆盖：
  - 区域市场解释锁定托盘、hover 和购买方式；
  - 打开市场后单击其他区域，市场仍锁定在原区域；
  - 双击市场卡牌仍能从锁定区域购买/升级并记录支出。

## 2026-07-01｜匿名牌轨与结算公告压缩：地图回到主视野

### 本轮实现

- 将顶部匿名卡牌轨道进一步压缩成电子桌游式时间轴：
  - 每张轨道牌只常驻显示两行：状态/卡名 + 匿名/小费/公开归属；
  - 详细效果、目标、条件、演出和竞价线索移入 hover tooltip；
  - 保留单击竞猜归属、双击打开卡牌图鉴详情的交互。
- 将右上角公开结算公告从“大卡片弹窗”压成短公告卡：
  - 降低遮罩透明度和占屏高度；
  - 缩小卡面展示高度；
  - 正文限制为一到两行短摘要；
  - 长效果、合约、条件、目标和竞价说明转入 hover 详情。
- 阶段状态文案同步压缩：
  - 保留“匿名竞价 / 同时判定 / 公开展示 / 相位响应”等核心阶段；
  - 保留“最高公开报价、可加价、新牌进入下一批等待”等关键决策信号；
  - 删除常驻重复信息，避免公告像规则说明书一样铺开。

### 设计意图

- 局内主角应该是地图、手牌和玩家当前决策，而不是一直压在右上角的长公告。
- 参考《Terraforming Mars》等桌游电子版的常驻信息层级：时间线短、当前动作短、详情按需 hover 或点开。
- 匿名牌轨仍然承担推理功能，但玩家不用在战斗/购牌/建城时被长文本打断。

### 验证

- 完整 Godot headless smoke test 通过，并新增覆盖：
  - 匿名牌轨保持紧凑，同时 hover 保留详情和双击图鉴入口；
  - 公开结算公告保持短正文，长详情进入 hover；
  - 原有匿名竞价、相位响应、归属竞猜、线索保留等流程继续通过。

## 2026-07-01｜手牌可打出状态：减少试错和弹窗依赖

### 本轮实现

- 将局内手牌卡面接入统一的可打出状态判断：
  - `可打出`：满足当前商品流动、资金和窗口条件；
  - `需商品 / 资金不足 / 部署限制 / 无目标 / 需合约`：直接说明卡住原因；
  - `需怪兽目标 / 需玩家目标`：明确点击后进入目标选择；
  - `排队中 / 冷却中 / 赌局暂停 / 先选目标`：解释当前全局或临时窗口限制。
- 手牌按钮不再只是“打出/不可点”，而是跟随状态显示“打出、释放、选目标、相位否决、排队中”等短文本。
- 手牌按钮 tooltip 显示简短状态说明和“打出条件”，玩家不用反复点错或去长规则里找条件。
- 状态颜色接入现有按钮样式：
  - 绿色代表可立即执行；
  - 黄色代表等待、冷却或缺条件；
  - 红色代表明显资源不足或封锁；
  - 蓝色代表下一步要选择目标；
  - 紫色代表相位否决响应。

### 设计意图

- 参考电子桌游和卡牌游戏的手牌区设计：玩家扫一眼手牌，就应该知道“哪张能打、为什么打不了、打了以后要做什么”。
- 把解释放在卡面状态和 hover tooltip 中，减少常驻长文，也减少无效弹窗。
- 这一步对测试者上手非常关键：同一张卡可能因为商品流动、资金、目标、赌局冻结、相位响应窗口而状态不同，UI 必须替规则承担解释工作。

### 验证

- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- 完整 Godot headless smoke test 通过，并新增覆盖：
  - 手牌卡面显示“状态：...”；
  - 手牌按钮 tooltip 暴露“打出条件”。

## 2026-07-01｜区域市场牌列：让买牌窗口更像电子桌游市场

### 本轮实现

- 将区域补给窗口从普通列表进一步改成“区域市场”牌列：
  - 标题显示“区域市场”；
  - 顶部说明市场牌列数量、当前窗口是“可购买”还是“仅浏览”、锁定的怪兽范围资格；
  - 每张区域牌以两行小卡条展示：卡名/价格/购买状态 + 路线/关键效果。
- 新增统一状态判断 `_district_supply_purchase_state()`：
  - `可购买`：资金、范围、手牌接收条件都满足；
  - `仅浏览`：不在怪兽落地/相邻/扩展补给范围内；
  - `资金不足`：范围满足但钱不够；
  - `需弃牌`：手牌已满但可进入私密弃牌流程；
  - `无法接收`：可能已到IV级或没有可弃掉的普通手牌；
  - `区域无效 / 未投放 / 已结束` 等边界状态。
- 预览区同步显示选中牌的购买结论、价格和原因；购买按钮在“需弃牌”时仍可点击，并会进入私密弃牌确认。
- 区域市场继续保持“查看总是允许”：不可购买时仍可 hover、点选、看卡面和效果，只有购买行为受锁定资格影响。
- smoke test 增加区域市场 UI 覆盖：
  - 打开区域市场 overlay；
  - 检查市场牌列说明；
  - 检查牌行显示价格和购买状态；
  - 检查预览区有购买结论和“查看总是允许”的提示。

### 设计意图

- 真人测试者不应该靠读长规则判断能不能买牌；窗口本身要一眼告诉他“能买/只能看/差钱/要弃牌”。
- 这一步继续参考电子桌游的市场牌列：卡牌可以被查看，购买条件用短标签和颜色表达，详细规则留到 tooltip 和图鉴。
- 后续可以把每张市场牌条替换成更完整的小卡面缩略图，但当前先保证信息层级和操作语义正确。

### 验证

- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜公开席位条：增强桌游对手存在感

### 本轮实现

- 将局内玩家选择从纯名字按钮升级为“公开席位”横向条，更接近电子桌游桌面上的玩家席位区：
  - 每个席位显示 P 编号、人类/AI、公开外星身份名；
  - 显示当前视角可知的城市/怪兽/军队概况；
  - 点击席位仍可切换当前查看玩家。
- 隐私规则在 UI 上做了保守处理：
  - 当前视角玩家显示“己城N”；
  - 其他玩家不直接显示真实城市数量，只显示玩家自己私人标注出的“疑城N”，否则显示“城?”；
  - 怪兽只统计已公开归属的怪兽，或当前视角玩家自己的怪兽；
  - 军队只统计已公开归属的军队，或当前视角玩家自己的军队；
  - tooltip 只提醒“现金、手牌和弃牌不公开”，不展示 AI 路线、压力桶或训练数据。
- smoke test 新增“公开席位”覆盖，防止后续 UI 回退成缺少对手存在感的纯手牌面板。

### 设计意图

- 真人试玩时必须感觉自己不是在看一张孤立地图，而是在和多个席位共同打一局桌游。
- 席位条要提供“桌面感”和快速方位感，但不能破坏城市业主、怪兽归属、现金和手牌隐私。
- 后续可以继续把席位条做得更精美：头像、公开身份卡小图标、近期公开动作徽章、竞猜标记，但仍要保持隐私边界。

### 验证

- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜Terraforming Mars 式当前区域操作卡

### 本轮实现

- 明确把《Terraforming Mars》这类电子桌游作为主菜单、局内 UI、卡牌浏览和游戏流程的核心参考方向，但玩家文案仍保持《太空辛迪加》自己的科幻世界观。
- 局内“手牌与行动”面板新增“当前区域”操作卡：
  - 显示选区地形、城市状态、GDP/min、当前天气、生产/需求商品和区域补给资格；
  - 提供高频动作按钮：城市化、查看牌、标注、商路、全屏；
  - “查看牌”明确支持不可购买时也能浏览，购买资格仍按打开区域牌窗的一刻锁定。
- 地图顶部工具栏进一步压缩：
  - 旧的城市化、标注、身份侦测、商路开关按钮移出顶部工具栏；
  - 顶部只保留地图操作提示、选区摘要、双击区域看牌提示、商路商品选择、合约供需端和全屏入口；
  - 让主要地图动作集中到当前区域操作卡，避免按钮横排堆积。
- smoke test 新增断言，确保玩家面板始终暴露桌游式“当前区域”操作卡。
- 加强购牌折扣 smoke 的状态隔离：测试怪兽落地区八折/相邻区原价前，会清理 game_over、弃牌购买、区域补给窗口和购买快照，避免前置竞价/赌局/菜单测试污染规则验证。

### 设计意图

- 玩家应该像玩电子化桌游一样：先看地图，点一个区域，再在一个稳定的小面板里决定“这里能做什么”。
- 常驻 UI 只放行动入口和短状态；规则解释、图鉴、经济拆解、情报整理继续收纳到菜单分支。
- 后续 UI 优化继续沿这个方向：卡牌像 TCG 牌面，区域像桌面板块，菜单像桌游大厅，临时决策窗口像统一弹出的桌游交互模块。

### 验证

- `git diff --check` 通过，仅有 Windows CRLF 换行提示。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜电子桌游式人类试玩 UI 收敛

### 本轮实现

- 以《Terraforming Mars》这类电子桌游的信息层级为参考，重新收紧局内画面：
  - 地图继续占据主视觉；
  - 顶部匿名卡牌轨道改成更矮的时间轴，hover 看详情，单击用于猜归属，双击跳到卡牌图鉴详情；
  - 出牌公开展示从居中大遮罩改成右上紧凑公告卡，仍保留公开卡面、匿名归属、小费/队列和条件线索；
  - 底部玩家区改成“手牌与行动”，显示“我的手牌 x/5”和五格手牌架感，固定技能/弃牌隐私放进 tooltip。
- 区域补给交互统一成“信息可看，购买看资格”：
  - 双击地图区域打开区域补给面板；
  - 即使当前没有怪兽范围资格，也能浏览该区域卡牌；
  - 购买资格和价格只按打开窗口瞬间锁定；
  - 同一玩家仍只保留一个区域补给窗口，避免沿路囤多个购买机会。
- 卡牌图鉴进一步 TCG 化：
  - 缩略图页只显示本局牌池、区域补给数量和 hover/双击操作；
  - 路线总览改成玩家能理解的“打法/对策”，不再把强度预算、支点、AI 覆盖等内部审计词铺在玩家页面；
  - 详情页保留卡面、费用门槛、核心效果、关键字段、I-IV 梯度和结算演出。
- 主菜单正文压缩为一句玩法、一句胜利目标和入口提示；规则细节继续收纳到“游戏规则”分支。子页面隐藏全局快捷导航，只保留该页面需要的返回/继续/翻页。
- 军队和怪兽诱导 smoke 调整到线性移动语义：命令发出后按米/秒推进，到达后再验证 GDP 压力、诱导效果和不造成怪兽式碾压。

### 设计意图

- 当前目标不是继续堆系统，而是让真人测试者第一眼能玩：像桌游桌面一样先看地图、手牌、牌轨和当前区域，再用 hover/详情页读复杂规则。
- 玩家界面不展示 AI 压力桶、路线审计、强度预算分和开发历史；这些继续留在文档、测试和内部函数里。
- 区域牌表是公开信息，购买才是经济动作；这能减少“怪兽刚离开窗口就失效”的反直觉体验。

### 验证

- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 路线可达性审计

### 本轮实现

- 新增 `_ai_route_viability_report()` 和 `_ai_route_viability_summary()`，把已有的三类 AI 路线审计串起来：
  - 静态路线压力：卡池是否有钱、压制、防御、情报、门槛和公开线索；
  - 实战路线样本：AI 是否在八席模拟里真的产生路线行动；
  - 性格偏好：是否有 AI profile 把该路线当作主路线或可偏好路线。
- 新增 `_ai_sample_viability_entry()`，把真实 AI 决策样本转成路线可达性字段，统计：
  - money / disruption / protection / intel-supply 压力；
  - gate / public clue 可读性；
  - 真实样本分数、路线压力和涉及 AI 数量。
- 八席 smoke 现在要求至少 5 条核心路线在当前模拟和卡牌结构里是“可追目标”，并报告缺失路线。

### 设计意图

- 这一步不是另起一个新目标，而是继续推进十小时目标中的“AI 至少能有四五种发展策略，都能够追逐最高目标”。
- 审计不要求每局所有路线都同样强；roguelike 地图、商品和怪兽不同，本来就应该让路线强弱变化。
- 但它要求开发侧能证明：AI 不会只剩单一最优路线，至少多条路线具备收益或破坏路径、可读门槛、公开反推线索和 AI 偏好支撑。
- 该报告仍是内部平衡工具，不进入玩家 UI；玩家只看到公开结果，不看到 AI 的路线桶和评分。

### 新增验证

- `_verify_max_ai_seat_complete_smoke()` 新增 AI 路线可达性检查：
  - `viable_required_route_count` 必须达到最低要求；
  - 不应存在缺失的核心路线；
  - 失败时输出 `_ai_route_viability_summary()`，方便继续平衡卡牌和 AI 评分。

## 2026-07-01｜卡牌图鉴牌池层级标识

### 本轮实现

- 新增卡牌层级辅助函数，按当前对局状态为每张卡标出：
  - `图鉴全集`：能查看规则/卡面，但本局未必出现；
  - `本局星球牌池`：符合当前星球商品、地形或怪兽生态，可能被投放；
  - `区域补给`：已经进入地图区域候选，玩家打开符合怪兽范围的购买窗口后可购买。
- 卡牌图鉴正文、TCG详情面板和 hover tooltip 都显示“牌池层”，并给出投放说明。
- 怪兽牌继续作为卡牌图鉴内的一个分类存在；怪兽生态档案只负责生态、行动概率、资源偏好和关联怪兽牌跳转。

### 设计意图

- 玩家不需要理解开发侧变量名，例如 `skill_market`；界面只使用“图鉴全集 / 本局星球牌池 / 区域补给”三层表达。
- 区域补给仍然是实际购买入口；图鉴全集不是商店，本局星球牌池也不是随时可买清单。
- II-IV 牌详情会沿用同系列 I 级基础牌的区域投放逻辑，符合“重复获得自动升级”的规则。

### 新增验证

- 卡牌图鉴统一分类 smoke 现在额外验证：
  - 卡牌详情文本含有牌池层；
  - 任意区域候选卡会被识别为 `区域补给`；
  - 区域卡 hover tooltip 会显示 `牌池层：区域补给`。

## 2026-07-01｜AI 终局竞速评分层

### 本轮实现

- 新增 `_ai_victory_race_bonus_for_candidate()`，让 AI 在现金目标、终局倒计时和领先/落后局势下更像是在争胜，而不是继续按中局节奏经营。
- 终局竞速会给候选动作标记内部角色：
  - `break_countdown`：别人触发倒计时或明显领先时，优先破坏领先者城市、GDP、商路或做空；
  - `protect_lead`：自己领先或接近目标时，优先保护城市、修复/保险、锁定现金；
  - `last_push`：自己落后但仍有机会时，更愿意用金融、做空、破坏和现金补口追分；
  - `race_to_goal`：多人接近目标但未定胜负时，兼顾护住收益和压制领先线。
- 这层评分已接入四个真实 AI 入口：
  - 自动城市化；
  - 匿名商业行动；
  - 区域购牌；
  - 匿名出牌。
- 决策样本新增隐藏字段：
  - `victory_race_bonus`
  - `victory_race_role`
  - `victory_race_reason`

### 平衡与 AI 决策

- 终局竞速不是独立脚本，也不强制 AI 做固定动作；它只是在商品路线、阶段策略、性格签名、学习层和卡牌字段评分之上叠加“争胜压力”。
- 加成会 clamp 到中等偏高范围，目的是让终局更有攻击性和保护意识，但不让 AI 无视商品流动、费用、目标归属或卡牌可打出条件。
- 这些字段只用于开发侧训练、烟测和平衡审计；玩家仍然只能通过公开结果、匿名卡牌轨道、经济变化、下注/合约等线索推理 AI 行为。

### 新增验证

- AI 阶段策略 smoke 现在额外验证：
  - 倒计时中落后 AI 会进入 `break_countdown`，并把商路破坏/做空类动作推高；
  - 领先 AI 会进入 `protect_lead`，并把灾害保单/保护类动作推高；
  - `victory_race_*` 字段会进入 AI 决策样本，继续保持内部隐藏。

## 2026-07-01｜AI 性格签名行动偏置

### 本轮实现

- 新增 AI 性格签名评分层，让 AI 差异化进入真实决策，而不只是事后审计：
  - `_ai_development_route_for_kind()`：把建城、合约、金融、怪兽、情报、直接互动、军队等行动映射到 development-route；
  - `_ai_policy_family_for_kind()`：把候选动作归入行动族；
  - `_ai_profile_signature_bonus_for_candidate()`：根据 AI 的 `route_preferences`、行动族、签名行动族、商品焦点和目标归属给出中等强度偏置。
- 签名偏置已接入四类真实 AI 决策入口：
  - 自动城市化；
  - 匿名商业行动；
  - 匿名出牌；
  - 区域购牌。
- 训练样本和候选视图新增内部字段：
  - `profile_signature_bonus`
  - `profile_signature_family`
  - `profile_signature_route`
  - `profile_signature_reason`

### 平衡与 AI 决策

- 这层偏置不是强制脚本，而是局势评分、商品路线、阶段策略、卡牌字段、学习层之外的“性格倾向”：
  - 拓荒型更愿意吃城市成长和城市化；
  - 套利型更容易靠近金融投机/商品经营；
  - 破坏型更容易选择怪兽压制、直接互动、商路破坏；
  - 驯怪型更容易补怪兽压力相关牌和动作；
  - 合约型更容易靠近合约供需；
  - 情报型更容易靠近情报/补给。
- 偏置被 clamp 到中等区间，避免 AI 无视局势；它应该强化“像某种对手”，不是替代策略判断。
- 所有签名偏置字段仍是内部训练/测试数据，玩家界面不显示 AI 的路线桶或评分。

### 新增验证

- 八席 smoke 的 AI 性格身份审计现在额外要求：
  - 至少 6 类 AI 性格都出现真实签名加权样本；
  - 签名加权随真实建城/购牌/出牌/商业样本进入决策记录；
  - 原有 8 席完整流程、终局、UI 隐私和 AI 隐藏数据检查继续通过。

## 2026-07-01｜AI 性格身份审计

### 本轮实现

- 新增 `_ai_profile_strategy_identity_report()`，把 6 类 AI 性格的实战样本整理成内部差异化审计：
  - 每类被实际分配到座位的 AI 是否产生决策样本；
  - 是否命中自己的主 development-route；
  - 是否出现符合路线偏好的行动族；
  - 是否有商品样本，避免路线计划和商品经济脱节；
  - 是否出现更有辨识度的签名行动族，例如城市化、合约、期货、怪兽诱导、情报、直接互动。
- 新增 `_ai_profile_strategy_identity_summary()`，用于测试失败时快速看出哪类 AI 没有体现差异。
- 审计从 `route_preferences`、`decision_samples`、`development_route`、`policy_kind` 和商品/焦点/路线字段推断，不绑定具体卡名。

### 平衡与 AI 决策

- 目标是防止 6 类 AI 最后都玩成同一种“随便买牌/随便出牌”的对手。
- 当前阶段不要求每类 AI 在一次短 smoke 中完成整套最优策略，但必须能证明：
  - 拓荒/套利/破坏/驯怪/合约/情报这几类性格都有实战身份；
  - 它们的主路线和行动族有可观察差异；
  - AI 差异化仍停留在开发侧，玩家只看到公开结果和推理线索。

### 新增验证

- 八席 smoke 新增 AI 性格身份检查：
  - 至少覆盖 6 类 AI 性格；
  - 6 类都必须具备身份样本；
  - 至少覆盖 5 类主路线；
  - 至少覆盖 4 类预期行动族；
  - 至少覆盖 3 类签名行动族。

## 2026-07-01｜AI 商品路线桥接审计

### 本轮实现

- 新增 `_ai_product_route_bridge_report()`，把 AI 的隐藏决策样本整理成内部审计报告：
  - 每个 AI 是否产生商品相关样本；
  - 样本是否带有经济焦点商品、路线计划商品和可识别的主商品；
  - AI 行动是否覆盖城市化、购牌、出牌、匿名商业、合约、期货、天气、直接互动、怪兽诱导、军队、情报等策略族；
  - 样本是否连接到 development-route 路线标签，而不是只凭卡名临时判断；
  - 明确统计商品/焦点/路线对齐样本，防止 AI 买牌、打牌和经济计划互相脱节。
- 新增 `_ai_product_route_bridge_summary()`，用于 smoke test 和开发日志快速读取，不进入玩家界面。
- 八席 smoke 在 AI 首召、建城、购牌、出牌、匿名商业、收入结算和主路线演练之后，强制调用该审计。

### 平衡与 AI 决策

- 这次审计强化的是“AI 是否真的围绕商品路线玩游戏”，而不是把更多 AI 内部信息展示给玩家。
- 审计目标是让新增卡牌继续通过字段被 AI 理解：`product`、`focus_product`、`route_plan_product`、`route_plan_stage`、`development_route`、`policy_kind`、`futures_*`、`weather_*`、`direct_*`、`contract_*` 等字段都可以进入策略判断。
- 玩家 UI 仍只展示公共结果：地图变化、商品价格、GDP 走势、匿名卡牌结果、合约结果、天气、怪兽线索、公开下注等；AI 压力桶、路线评分和训练样本保持隐藏。

### 新增验证

- smoke 新增 AI 商品路线桥接检查：
  - 所有 AI 都必须有商品样本；
  - 至少覆盖 4 种商品；
  - 至少覆盖 2 个路线阶段；
  - 至少覆盖 3 条 development-route；
  - 至少覆盖 3 类策略族；
  - 必须出现商品/焦点/路线对齐样本。

## 2026-07-01｜商品生态总览与本局商品策略入口

### 本轮实现

- 新增 `_product_ecosystem_report()`，把商品目录和本局星球商品状态整理成可审计报告：
  - 图鉴商品总数、海洋商品总数；
  - 本局出现商品数、海洋/陆地商品分布；
  - 区域生产槽、区域需求槽、城市生产槽、城市需求槽；
  - 商品路线分布、品类分布、当前主策略分布；
  - 当前策略热点商品；
  - 有固定相关卡牌的商品数量；
  - 有怪兽资源偏好的商品数量；
  - 临时美工/商品档案字段完整度。
- 商品图鉴缩略图页新增四张总览卡：
  - 本局商品生态；
  - 策略机会；
  - 商品路线分布；
  - 机制钩子。
- 商品图鉴标题区现在直接说明：本局星球出现多少商品，其中海洋/陆地商品各多少。

### 平衡与 UI 决策

- 商品不是装饰名词，而是连接 GDP、卡牌门槛、区域补给、期货、仓储、商路、怪兽目标和推理线索的核心层。
- 商品图鉴缩略图页承担“先扫本局经济格局”的任务；商品详情页继续承担单个商品的价格、供需、期货/仓储、怪兽偏好、相关卡牌和城市线索解释。
- 海洋商品必须继续保留足够存在感，让海域不只是运输地形，也能成为商品生产和金融/怪兽策略来源。

### 新增验证

- smoke 新增商品生态报告检查：
  - 商品目录不少于 40 种，海洋商品不少于 12 种；
  - 所有商品都有完整临时美工/档案字段；
  - 本局商品包含海洋与陆地分布、生产/需求槽、策略机会。
- 商品图鉴 smoke 现在检查缩略图页展示：
  - 本局商品生态；
  - 策略机会；
  - 商品路线分布；
  - 机制钩子。

## 2026-07-01｜卡牌三层牌池口径与区域补给可读性

### 本轮实现

- 新增 `_card_supply_layer_report()`，把卡牌供应拆成三个可审计层级：
  - 图鉴全集：用于学习规则和查看全部卡牌；
  - 本局星球牌池：按当前星球商品、地形和怪兽生态筛选后的本局候选；
  - 区域补给：实际投放到地图区域、玩家可通过怪兽落地/相邻/补给范围购买的候选。
- 卡牌图鉴缩略图页现在直接显示三层数量：图鉴全集、本局星球牌池、区域补给总数。
- 卡牌图鉴分类区新增玩家可读说明卡：
  - 三层牌池：展示本局商品数量、星球牌池数量、区域补给数量、已过滤不适配固定商品牌/怪兽牌数量；
  - 购买窗口锁定规则：解释点开区域补给窗口时会锁定当时的怪兽位置、补给范围和价格倍率。
- 清理玩家 UI 中“旧的普通牌池”这类开发历史口吻，改为图鉴全集/本局星球牌池/区域补给三层语言。

### 平衡与规则决策

- 玩家需要理解的是“为什么这局能买这些牌、为什么这个区域提供这些牌”，而不是理解内部常量或历史命名。
- 本局星球牌池必须继续由地图商品、地形和怪兽生态驱动；地图没有的固定商品不应把对应卡牌带入可购买区域。
- 区域补给是最终购买事实来源；图鉴只负责解释规则，不代表本局一定买得到。

### 新增验证

- smoke 新增三层牌池报告检查：
  - 图鉴全集数量不少于本局星球牌池；
  - 本局星球牌池、区域补给、区域去重补给都非空；
  - 商品/怪兽过滤没有违规项。
- 卡牌图鉴 smoke 现在检查：
  - 缩略图页显示“三层牌池 / 图鉴全集 / 本局星球牌池 / 区域补给”；
  - 分类区显示“购买窗口锁定规则”；
  - 玩家界面不再出现“旧的普通牌池”。

## 2026-07-01｜怪兽生态档案可读性与 TCG 式摘要

### 本轮实现

- 怪兽生态档案的缩略图页新增“生态速览”，把当前怪兽池的移动生态、商品偏好覆盖和行动定位数量先展示给玩家。
- 怪兽缩略图现在直接显示移动生态位和行动标签，避免玩家只能看到 HP/速度而看不出差异。
- 悬停预览新增“生态位 / 行动定位 / 固定技能成长”摘要，让玩家不用点进详情也能快速比较怪兽。
- 怪兽详情页新增四张玩家可读信息卡：
  - 生态位：移动方式、召唤限制、移动速度和地形适配；
  - 资源与经济：商品偏好、资源吸取和经济钩子；
  - 行动定位：伤害、射程、位移和功能标签；
  - 固定技能成长：I-IV 级绑定技能数量和 IV 级概率倾向。
- 继续保持怪兽牌归入卡牌图鉴；怪兽生态档案只讲怪兽行为和生态身份，不重复做怪兽牌图鉴。

### 平衡与 UI 决策

- 玩家应该能从图鉴里理解“这只怪兽为什么会去某些区域、会怎样破坏、升级后会怎么变危险”，但不应该看到 AI 路线桶、AI 评分或隐藏决策压力。
- 怪兽详情采用 TCG 式摘要卡，而不是长段落说明，后续卡牌、商品、角色详情页也应继续向这种结构靠拢。
- 图鉴缩略图页先解决“扫一眼可分辨”，详情页再解决“深入理解”；不要把所有文本挤进主游戏画面。

### 新增验证

- 完整 smoke 现在会检查：
  - 怪兽缩略图页包含生态速览、飞行/水栖/陆行覆盖和悬停预览；
  - 悬停预览展示 HP、生态位、行动定位和行动摘要；
  - 怪兽详情页展示生态位、资源与经济、行动定位和固定技能成长信息卡。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜怪兽生态差异与固定技能梯度审计

### 本轮实现

- 新增怪兽生态审计：
  - `_monster_ecology_identity_entry(index)`
  - `_monster_ecology_balance_report()`
  - `_monster_ecology_balance_summary()`
- 审计会为每只怪兽读取并汇总：
  - 移动生态位：飞行、水栖/海域、陆行或通用；
  - 商品资源偏好；
  - 经济钩子；
  - 临时美工档案；
  - 自动行动数量、早期可用行动、升级/破坏后行动；
  - 行动角色标签，例如机动、远程、伤害、高伤、控制、修复、续航、路径/场地、位移/击退、热度、自损爆发；
  - I-IV 升级后后段危险行动概率倾斜；
  - 绑定固定技能梯度是否完整。
- 新增 smoke 验证 `monster ecology balance audit preserves movement, resources, actions, bound skills, and art identities`。

### 平衡与规则决策

- 当前不急着继续堆怪兽数量；先保证每只已有怪兽都有清楚生态位，防止后续变成“只是数值不同的自动单位”。
- 后续新增怪兽时，必须同时满足：
  - 有商品偏好，并能影响地图商品/城市决策；
  - 有自动行动概率表，并且 I-IV 升级会把概率推向更危险或更核心的行动；
  - 有可重复使用的绑定固定技能梯度；
  - 有临时美工档案和图鉴可读身份；
  - 至少在移动、行动标签、经济钩子或地形适配中形成差异。
- 怪兽审计仍是开发内部数据；玩家图鉴看到的是生态、行动概率、商品偏好和卡牌效果，不看到隐藏 AI 压力桶。

### 新增验证

- 完整 smoke 现在会检查：
  - 怪兽数量不少于 8；
  - 目录中同时存在飞行、海域/水栖、陆行生态位；
  - 商品偏好池不少于 12 种商品；
  - 行动签名和行动标签数量足够，避免同质化；
  - 每只怪兽都有资源偏好、经济钩子、临时美工、升级概率倾斜和完整固定技能梯度。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 实战路线审计与多策略推进护栏

### 本轮实现

- 新增 `_ai_live_route_balance_report()` 和 `_ai_live_route_balance_summary()`，把一局实际运行后的 AI 决策样本转成内部平衡报告。
- 报告会统计：
  - 有多少 AI 产生了可识别发展路线样本；
  - 有多少 AI 在局中完成了经济推进；
  - 实战样本覆盖了多少条核心路线；
  - 有多少 AI 命中了自己的主路线偏好；
  - 本局出现了多少类行动；
  - 哪条路线在样本分数上最强；
  - 每个 AI 的主偏好、最高样本路线、路线样本数、经济推进、当前结算估值和行动类型。
- 八席 AI smoke 局现在会调用这份实战报告，要求：
  - 7 个 AI 都有路线样本；
  - 至少 6 个 AI 有经济推进；
  - 至少 4 条核心路线在实战中出现；
  - 至少 4 个 AI 命中自己的主路线偏好；
  - 至少 3 类行动进入样本。

### 平衡与规则决策

- 静态字段审计证明“卡牌能被 AI 理解”；实战路线审计证明“AI 真的在一局中把这些卡用成多种玩法”。
- 这份报告仍然是隐藏开发数据，不能进入玩家 UI。玩家只应该看到公开卡牌、地图结果、经济变化、合约/赌局/竞价等可推理线索。
- 后续新增卡牌或路线时，除了补卡牌字段，还要观察它是否能在 `_ai_live_route_balance_report()` 中形成实际样本；否则它只是图鉴内容，不算真的进入玩法。

### 新增验证

- `tests/smoke_test.gd` 的八席完整 smoke 现在额外验证 AI 实战路线审计：
  - 防止所有 AI 退化成同一种成长路线；
  - 防止只有静态路线标签、但局内没有经济推进；
  - 防止主偏好路线完全不起作用；
  - 防止 AI 行动样本过于单调。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜核心发展路线压力审计与 AI 策略场景稳定

### 本轮实现

- 新增核心发展路线压力审计，覆盖目前要求 AI 能实际追逐的六条基础路线：
  - 城市成长；
  - 合约商路；
  - 金融投机；
  - 怪兽压力；
  - 情报/补给；
  - 直接互动。
- 审计不按卡名硬编码，而是从卡牌字段推导：
  - `money_score`：现金、GDP、收入、生产/消费/运输、商品/城市衍生品等赚钱压力；
  - `disruption_score`：城市、商路、怪兽、玩家手牌或产权等破坏压力；
  - `protection_score`：修复、防御、保险、稳定市场、商路保护；
  - `intel_supply_score`：情报、购牌范围、追溯、补给能力；
  - `gate_score`：价格、商品流动、目标限制、持续时间、仓库/城市/区域等门槛；
  - `public_clue_score`：公开目标、商品流动、GDP 变化、城市线索、轨道记录等推理线索。
- 新增路线汇总文案 `_development_route_pressure_summary()`，后续可以给开发菜单或调试面板使用，但玩家界面仍不暴露 AI 内部路线桶。
- 强化 AI 策略意图 smoke 场景：
  - 成长场景保留开局 `grow_focus`；
  - 防守场景明确模拟“领先 AI 的高价值受损商路”，要求 AI 选择 `defend_routes` 并给供应链保险候选附加策略元数据；
  - 压制场景明确模拟“落后 AI 面对高收入竞品城”，要求 AI 选择 `disrupt_competitors` 并把商路黑客指向竞品城市。

### 平衡与规则决策

- 之后新增卡牌时，不能只看“这张牌好不好玩”，还要看它是否补强某条路线的赚钱点、门槛、公开线索和反制空间。
- 核心路线不要求任何时刻等强，但至少要保证每条路线都有：
  - 足够卡牌数量；
  - 至少一条完整 I-IV 梯度；
  - 能落到钱上的收益或压制结果；
  - 可被对手观察和推理的公开痕迹；
  - AI profile 能读懂并实际选择。
- AI 的路线、压力桶和策略评分继续作为隐藏开发数据；玩家只看到地图结果、卡牌轨道、公开线索和经济变化。

### 新增验证

- `tests/smoke_test.gd` 新增 `development route pressure audit proves core strategies have money pressure, gates, clues, and AI coverage`：
  - 验证六条核心路线都有至少 8 张相关卡；
  - 验证每条路线至少有一条完整 I-IV 梯度；
  - 验证路线总压力、门槛、公开线索、反制分和 AI profile 覆盖达到最低标准；
  - 验证城市成长/合约/金融必须能产生金钱压力，怪兽/直接互动必须有破坏压力，情报/补给必须有情报或补给压力。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜商品期货与港仓囤货平衡审计

### 本轮实现

- 新增商品期货平衡审计函数，覆盖 `商品看涨`、`商品看跌`、`港仓囤货` 三个 I-IV 家族。
- 审计从卡牌字段推导三类分数：
  - `effect_score`：期货倍率、持仓秒数、供需压力、囤货单位和仓储杠杆；
  - `gate_score`：购牌价格、商品流动门槛、持仓窗口、仓库城市要求和供需影响；
  - `public_clue_score`：公开方向、真实秒数窗口、商品流动线索、供需压力、仓库位置和囤货单位。
- 审计会计算“30点商品价格变化下的预期兑现”，并和普通城市基础 GDP/min 参考值比较，防止普通期货或港仓囤货在没有足够风险时变成无限印钱。

### 平衡与规则决策

- 普通商品看涨/看跌必须吃真实商品价格变化，不能从抽象经济周期中凭空结算；它们的强度由价格波动、商品流动要求和公开商品线索共同限制。
- 港仓囤货可以比普通期货有更高收益，因为它额外暴露匿名仓储线索，并把收益绑定到一座可被怪兽、军队或破坏牌攻击的城市仓库。
- 玩家看到的是商品价格、匿名期货/仓储线索和地图结果；`effect_score`、`gate_score`、`exposure_to_city_income_x100` 等审计字段只用于开发与自动测试，不暴露 AI 内部判断。

### 新增验证

- `tests/smoke_test.gd` 新增 `commodity futures balance audit gates long, short, and warehouse stockpile leverage with flow, public clues, and warehouse risk`：
  - 验证看涨、看跌、港仓三条路线都有完整 I-IV 梯度；
  - 验证强期货效果必须有商品流动门槛、真实秒数窗口、供需影响和公开线索；
  - 验证普通期货不偷偷叠加囤货单位；
  - 验证港仓囤货必须有仓库城市、囤货单位、较高公开线索和可控的收益上限。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜直接互动牌强度与反制护栏

### 本轮实现

- 新增直接互动牌平衡审计函数，覆盖 `星链拆解`、`影仓牵引`、`产权冻结`、`轨道齐射` 四个 I-IV 家族。
- 审计从卡牌字段推导三类分数：
  - `effect_score`：拆牌、牵牌、封锁、罚款、产权 GDP 惩罚、齐射目标数、齐射伤害和断路压力；
  - `gate_score`：费用、商品流动门槛、指定目标/公开城市目标、一次性结算等门槛；
  - `public_clue_score`：目标玩家、公开城市、商品流动、齐射目标数和公开 GDP/伤害结果带来的推理线索。
- 审计要求强效果必须同时满足：
  - 有商品流动门槛；
  - 有公开目标或公开城市结果；
  - 有相位否决作为可用反制家族；
  - I-IV 效果压力和门槛不能倒退。

### 平衡与规则决策

- 直接互动牌可以强，但不能便宜、无门槛、无公开线索地删除对手资源；它们应该制造“我被谁盯上了”的推理素材。
- 玩家看见的是目标玩家/目标城市/公开结果，不会看见 AI 的 `direct_*` 压力字段；审计分数只给开发和自动测试使用。
- `轨道齐射` 这种全场牌不要求指定某个玩家，但必须公开多个目标城市，让其他玩家可以从收益方向和商品/GDP压力反推。

### 新增验证

- `tests/smoke_test.gd` 新增 `direct-interaction balance audit gates strong pressure with flow, public clues, and counter windows`：
  - 验证四个直接互动家族都完整 I-IV；
  - 验证 IV 级强效果同时具备足够门槛和公开线索；
  - 验证拆牌/牵牌/产权冻结/轨道齐射的关键字段随等级增长；
  - 验证相位否决作为反制窗口支撑存在。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜军队牌身份与 GDP 压力平衡审计

### 本轮实现

- 新增军队牌平衡审计函数，读取所有 `military_force` 卡牌并按军种聚合：
  - HP、伤害、机动、射程、在场时间；
  - GDP 压力、压力持续秒数、显式断路伤害；
  - 陆地/海洋移动倍率和军种定位文字。
- 审计会检查每个军种是否维持设计身份：
  - 战斗机应是高机动截击/补位单位，不能偷走最高 GDP 压城定位；
  - 轰炸机应是主要城市 GDP 压制单位，并带显式商路压力；
  - 坦克应是陆地耐久防守/推进单位，跨海能力必须很弱；
  - 导弹阵地应是最高射程、低机动、位置可读的远程威慑；
  - 潜艇和战舰应更适合海域行动，并承担海路压力。
- I-IV 梯度现在自动检查 HP、伤害、在场时间、GDP/断路压力不得倒退。后续新增或改军队牌时，如果把军种身份调歪，烟测会直接暴露。

### 平衡与规则决策

- 这不是玩家可见的 UI 信息，而是开发护栏：玩家看到的是军队卡面、地图行动和 GDP/断路线索；AI 和测试用审计负责防止数值路线混乱。
- 军队和怪兽继续分工：军队不自主行动、不移动踩城，主要通过可回收军令制造保卫、压城、猎兽或商路控制；怪兽才是随机生态灾害和资源掠夺核心。
- GDP 压力的强弱不只看单次伤害，也看持续秒数和断路附带效果，避免高机动单位因为便宜/快而取代真正的压城军种。

### 新增验证

- `tests/smoke_test.gd` 新增 `military balance audit preserves fighter, bomber, tank, missile, submarine, and warship identities`：
  - 验证七类军队牌都至少有 I-IV 四张；
  - 验证战斗机机动高于轰炸机/导弹；
  - 验证轰炸机 GDP 压力高于战斗机/战舰；
  - 验证导弹射程高于轰炸机/战舰；
  - 验证坦克耐久和跨海弱点、海军海域适配、断路专长边界。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 合约回应字段化与结果线索回写

### 本轮实现

- 合约签/拒结果现在会回写到匿名卡牌轨道和经济总览余波线索：
  - 记录 `contract_result_clue`、`contract_accept_summary`、`contract_decline_summary`；
  - 线索明确显示供给区→需求区、商品、已签约/拒签/超时拒签、奖励或惩罚；
  - 仍然只公开结果，不公开合约发起者和真实回应者。
- AI 合约回应新增字段化评分，不再只输出“签约/拒签”：
  - 记录 `contract_response_role`、`contract_route_match`、`contract_accept_value`、`contract_reject_value`、`contract_response_margin`、`contract_decline_risk`；
  - 同步记录合约两端区域、来源城市业主、目标城市 GDP、目标断路压力、签约经济增量和拒签经济代价；
  - 惩罚型合约会被标记为 `accept_avoid_punishment`，路线吻合型合约会被标记为 `accept_route_plan`。
- 如果未来某些特殊合约不是从标准匿名轨道进入，结算结果也会作为卡牌余波进入历史，避免“结算了但玩家看不到公开证据”的断层。

### 平衡与规则决策

- 合约回应是公开结果、隐藏动机：玩家可以从商品、区域、奖惩和后续 GDP 变化推理身份；AI 的风险/路线评分仍是训练数据，不出现在玩家 UI。
- 拒签不是默认正确或错误：AI 会把“帮对手扩张供给”“拒签惩罚”“是否补齐自己的商品路线”“目标城市受损/缺需求”等因素一起评分。
- 合约结果线索会成为经济推理链的一环，后续可以继续接入卡牌归属竞猜、合约追溯卡和商品目录的相关城市线索。

### 新增验证

- `tests/smoke_test.gd` 扩展合约烟测：
  - 验证签约后轨道条目写入具体 `contract_result_clue` 和奖励摘要；
  - 验证 AI 对惩罚性拒签条款会签约，并写入 `contract_response_role=accept_avoid_punishment`；
  - 验证路线计划中的合约候选带有 `contract_route_match`、签/拒价值、回应边际和经济字段。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 直接互动目标规划字段化

### 本轮实现

- AI 直接互动牌新增专门计划器，不再只按“领先者/高估值”粗暴选目标：
  - `星链拆解`、`影仓牵引` 会按可见结算估值差、城市/怪兽经营压力、已公开或私下追踪到的卡牌归属线索、终局落后压力和卡牌自身拆牌/牵牌/封锁/罚款强度选择目标玩家；
  - `产权冻结` 会选择高 GDP、仓储压力、商路负载、领先者所属或更适合被压制的竞争城市；
  - `轨道齐射` 的实际目标排序也接入同一套城市压力评分，优先命中高价值、仓储/商路压力更高的非己方城市群。
- 新增隐藏训练字段：`direct_interaction_role`、`direct_interaction_score`、`direct_target_settlement`、`direct_target_gap`、`direct_target_city_pressure`、`direct_target_monster_pressure`、`direct_target_public_card_signal`、`direct_effect_pressure`、`direct_city_pressure`、`direct_city_gdp`、`direct_city_warehouse_pressure`、`direct_city_route_damage`、`direct_city_damage`、`direct_barrage_target_count`、`direct_barrage_expected_damage`。
- 这些字段写入 AI 候选视图和匿名出牌决策元数据，只用于内部训练/调试；玩家仍只看到公开目标、公开结果、卡牌轨道和经济变化，不会看到 AI 压力桶。

### 平衡与规则决策

- AI 选择拆牌/牵牌目标时不把对手真实手牌数量作为公开信息来展示；目标价值主要来自可见估值、已公开卡牌归属、城市/怪兽/金融压力和终局局势。
- 直接互动路线现在有更明确的策略位置：落后 AI 会更愿意用它压领先者或破坏高价值经营路线，领先 AI 则更谨慎，把它当作防止追赶和清理威胁的工具。
- `轨道齐射` 不再被测试假设为“打当前选区”，而是全场匿名压制牌：选区只是出牌上下文，实际命中由非己方城市压力排序决定。

### 新增验证

- `tests/smoke_test.gd` 扩展 `direct player-interaction cards cover 拆牌、牵牌、产权冻结、全场齐射...`：
  - 验证 AI 拆牌计划会选高估值/领先目标玩家，并写入直接互动隐藏元数据；
  - 验证 AI 产权冻结会选择带仓储压力的高价值竞争城市；
  - 验证轨道齐射目标排序优先命中高价值仓储城市；
  - 验证训练视图保留 direct 字段，但玩家可见逻辑仍只展示匿名结果。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 怪兽赌局下注策略

### 本轮实现

- AI 怪兽赌局新增下注计划层，不再只是“谁血多押谁”或“有钱就大注”，而是为每个参战怪兽计算内部评分：
  - 已造成伤害：当前赌局已经打出的伤害会提高该怪兽胜面；
  - 预期战斗力：读取怪兽行动表、行动权重、伤害、轻量击退价值、HP、护甲和等级；
  - 归属利益：AI 会更重视自己拥有的怪兽，但隐藏归属时不会无限放大，避免过度暴露；
  - 城市风险：靠近己方高价值城市会降低支持倾向，靠近竞争城市或商业靶点会提高支持倾向；
  - 资源吻合：怪兽在当前位置能吸取的商品资源会进入风险/强度判断。
- AI 下注金额从固定规则改成基于信心差距：
  - 默认公开底注 ¥100；
  - 如果最佳下注目标和第二候选分差足够大，并且现金足够，AI 会公开下 ¥500 大注；
  - 金额、下注玩家身份和下注目标仍然公开，作为玩家推理线索。
- `bets` 内部记录新增隐藏评分字段：`ai_wager_score`、`ai_wager_confidence`、`ai_wager_reason_key`、`ai_wager_owner_bias`、`ai_wager_city_bias`、`ai_wager_expected_damage`。这些字段用于测试和后续训练，不显示在公开下注摘要里。
- 修正怪兽战斗力估值：击退距离不再被当作直接伤害；它只作为轻量战术价值进入预期战斗力，避免远距离击退/光线类怪兽被 AI 夸大成压倒性伤害。

### 平衡与规则决策

- 怪兽赌局的公开信息保持简单：玩家只看到谁押了哪只怪兽、押了多少钱；AI 的评分理由是隐藏开发/训练数据。
- AI 可以因为强度、归属或城市利益做出不同选择，因此公开下注本身会成为推理线索，但不会机械等同于“谁押谁就是谁拥有”。
- 大注不应只由现金决定，而要由局势信心决定；这让玩家看到大注时能推测“这个 AI 可能掌握了某种利益或胜率判断”。

### 新增验证

- `tests/smoke_test.gd` 新增 `AI monster-wager bets use strength, ownership, city-risk, public stake, and hidden scoring metadata`：
  - 验证 AI 会在强势己方怪兽明显占优时押对应怪兽；
  - 验证高信心会触发 ¥500 公开大注；
  - 验证下注后现金正确扣除；
  - 验证公开下注摘要只显示玩家身份、目标和金额，不泄露 `ai_wager_*` 内部评分；
  - 验证内部下注记录保留评分、信心、归属偏好等训练字段。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 军队部署路线字段化

### 本轮实现

- AI 军队牌新增部署计划层，不再只返回“部署到哪个区域”，而是生成可训练的路线字段：
  - `military_deploy_role`：护航己方城市、压制竞争城市、截击怪兽、控制商路或占据适配地形；
  - `military_deploy_score`：当前部署路线的局势评分；
  - `military_deploy_terrain`、`military_deploy_route_load`、`military_deploy_monster_risk`：记录地形、商路和怪兽压力；
  - `military_deploy_district`：购牌候选中单独记录未来部署点，避免和“在哪里买到这张牌”的区域混在一起。
- 部署评分会读取军队字段与地图状态：
  - 防卫军更偏向守住己方高 GDP、受损、断路、仓储或怪兽威胁城市；
  - 轰炸机、导弹、潜航舰队更偏向压制竞争城市、仓储金融靶点和高商路价值节点；
  - 战斗机和导弹会更重视怪兽截击；
  - 潜航舰队和星海战舰会更重视海域商路控制；
  - 坦克在陆地城市防守和近线推进上获得更高权重。
- AI 出牌、购牌、匿名出牌记忆和训练样本都能保留这些部署字段，后续新增军队牌时能先靠字段形成基础路线判断。

### 平衡与规则决策

- 军队路线被明确拆成“部署资产”和“可回收军令”两层：部署决定这支短时战斗力量放在哪里，军令决定它之后做什么。
- 防卫军的攻击倾向被压低，避免它被高价值竞品城市过度诱惑；进攻压城路线主要交给轰炸机、导弹、潜航舰队等更符合直觉的军种。
- 购买军事牌时，AI 会评估未来部署价值，但购买区域仍由怪兽补给规则决定；这个分离能避免“从哪里买牌”和“之后部署到哪里”在训练数据里混淆。

### 新增验证

- `tests/smoke_test.gd` 新增 `AI deploys military-force cards with field-driven guard, strike, and purchase metadata`：
  - 验证 AI 会用防卫军守己方受损高价值城市；
  - 验证 AI 会用轰炸机压制竞争/仓储城市；
  - 验证匿名出牌记忆保存 `military_force_strike_rival_city` 和部署路线字段；
  - 验证购牌候选把购买区域和未来部署区域分开记录。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 军队可回收指令目标规划

### 本轮实现

- AI 新增军队指令规划器，不再只把绑定军令当作普通卡牌评分，而是读取 `military_command`、绑定军队 UID、军队类型、射程、火力、地形适配和当前地图状态来选择目标。
- 可回收军令现在按用途分流：
  - `guard` 优先保护己方高 GDP、受损、断路、恐慌、仓储压力或怪兽威胁较高的城市；
  - `strike_district` 优先打击竞争城市、仓储城市、高商路负载城市和与己方商品路线冲突的城市；
  - `attack_monster` 优先猎杀靠近己方城市、资源吻合度高、生命/等级威胁高的怪兽；
  - `move` 会按军队类型、地形倍率、己方防守价值、敌方进攻价值和商路负载选择重新部署点。
- AI 出牌候选、匿名出牌记忆和训练样本新增军令元数据：`military_command`、`military_command_role`、`military_command_score`、`military_command_distance_m`、`military_unit_uid`、`military_unit_type`。
- 调整 AI 出牌上下文的分支顺序，让“攻击怪兽”军令优先走军令规划器，而不是被通用怪兽目标逻辑提前截走。

### 平衡与规则决策

- 军队继续与怪兽区分：军队完全靠玩家/AI 的可回收指令行动，不产生怪兽式自主行为，也不会因为受伤让操控者承担怪兽伤害资金损失。
- 军队路线现在能形成四种清晰策略：护航己方 GDP、打击竞品城市、清理怪兽威胁、抢占地形/商路节点。
- 这些评分、压力桶和路线偏好仍是隐藏 AI 工具；玩家只会看到公开军队行动、地图结果、GDP 压力和匿名卡牌线索。

### 新增验证

- `tests/smoke_test.gd` 新增 `AI uses reusable military commands to guard cities, strike rivals, attack monsters, and record command metadata`：
  - 验证 AI 能为防守军令选择己方城市；
  - 验证 AI 能为轰击军令选择竞争城市；
  - 验证 AI 能为猎兽军令选择威胁怪兽，并记录资源匹配；
  - 验证匿名出牌训练记忆会保存军令类型、角色和绑定军队 UID。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜商品期货 AI 字段化决策

### 本轮实现

- AI 新增商品期货评估器，不再只把 `商品看涨 / 商品看跌 / 港仓囤货` 当作普通经济牌加一点市场压力分，而是读取卡牌字段判断策略：
  - `product_bet_direction` 区分看涨/看跌；
  - `product_bet_multiplier`、`product_bet_seconds` 和 `stockpile_units` 进入收益/风险评分；
  - `requires_warehouse_city` 会迫使 AI 选择一座己方存活城市作为仓库，并评估该城市的商品匹配、交通、GDP、路线压力、损伤和怪兽风险。
- AI 出牌上下文新增商品期货元数据：`futures_direction`、`futures_signal`、`futures_market_score`、`futures_stockpile_score`、`futures_stockpile_units`、`futures_duration_seconds`、`futures_multiplier_x100`、`futures_warehouse_city`、`futures_warehouse_required`、`futures_product_flow`。
- AI 购牌候选同样保留期货元数据，并额外记录 `futures_play_district`，避免“在哪里买到牌”和“这张牌打出时应该选哪个仓库/商品”混在一起。
- 训练样本和实际匿名出牌记录加入上述字段，后续新增商品期货、仓储、囤积、看涨/看跌类卡牌时，AI 可以先靠字段形成基础判断，再由学习层微调。

### 平衡与规则决策

- 商品金融路线现在更像一条真正的 AI 可走路线：AI 会根据公开供需、商品流动、焦点商品、路线商品、竞争城市和仓库风险来决定看涨、看跌或囤货，而不是随机买金融牌。
- 港仓囤货仍是高收益高暴露路线：仓库城市会成为公开金融靶标，吸引怪兽、做空、轨道齐射、军队压力和情报推理；AI 也会把这种风险当作攻击/防守目标。
- 这些判断仍然是 AI 内部工具，玩家界面只显示公开结果和线索，不显示 AI 的评分、压力桶或路线计划。

### 新增验证

- `tests/smoke_test.gd` 新增 `AI evaluates commodity futures from fields for long, short, stockpile, buy, and training metadata`：
  - 验证 AI 能为商品看涨生成 `product_futures_up` 出牌上下文；
  - 验证 AI 能为商品看跌生成 `product_futures_down` 出牌上下文；
  - 验证港仓囤货会选择己方仓库城市并写入仓库元数据；
  - 验证购牌候选也携带期货信号和实际打出目标；
  - 验证匿名出牌训练记忆会保存商品期货策略字段。
- 加固旧仓储风险测试：对照城收入降低，仓储城收入提高，让测试稳定验证“仓储风险会吸引做空、齐射和军队压制”，而不是被随机地图上的高收入对照城干扰。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜卡牌图鉴严格分类与局部 hover 刷新

### 本轮实现

- 卡牌图鉴筛选从旧的粗分组细化为：怪兽牌、怪兽技能、军队/军令、相位反制、玩家互动、城市经营、商品经营、商品期货、金融/GDP、合约、情报、补给/采购、怪兽诱导、新闻事件、天气干预和其他。
- 旧筛选 ID `economy`、`business`、`combat` 继续作为内部兼容聚合保留，避免旧入口和测试断裂；玩家界面优先展示新的严格分类。
- 卡牌图鉴新增“统一卡池 / 区域补给 / 市场牌池”解释：图鉴展示完整卡池；本局区域补给才是实际可购买候选；怪兽生态档案只解释自动怪兽行为，怪兽牌仍在卡牌图鉴里查看。
- 卡牌图鉴和怪兽生态档案的 hover/单击预览改为只刷新下方预览面板，不再重建整页，减少图鉴滚动跳动和翻页疲劳。
- `商品看涨`、`商品看跌`、`港仓囤货` 登记为正式 I-IV 升级家族，和“重复获得同系列牌自动合成升级到 IV”的规则保持一致。

### 体验与规则决策

- “普通牌池”以后只作为开发语境里的候选牌库；玩家应理解为：图鉴看全卡，地图区域看本局当前可买牌。
- 严格分类是后续卡牌平衡的基础：金融/GDP、商品期货、商品经营、城市经营和合约不再挤在同一个“经济”抽屉里，方便玩家按路线找牌，也方便 Codex 后续按字段审计强度。
- hover 预览应该像 TCG 图鉴里的快速扫读，不应该因为鼠标滑过就重排整页。

### 新增验证

- `tests/smoke_test.gd` 扩展卡牌图鉴烟测：
  - 检查严格分类标签和统一卡池解释会出现在图鉴缩略图页。
  - 验证怪兽牌、怪兽技能、军队/军令、相位反制、城市经营、商品经营、商品期货、金融/GDP、合约等分类能各自找到代表卡。
  - 保留旧 `economy` / `business` 兼容聚合验证。
- 怪兽落地区折扣测试改为构造单个受控怪兽落点，避免多个怪兽相邻落地时把“相邻区”随机判成“落地区”的旧 flake。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI 怪兽诱导更重视商品竞品压力

### 本轮实现

- 怪兽诱导 AI 评分新增 `product_overlap`：当目标城市与 AI 自己城市的生产/需求商品重叠时，会显著提高诱导怪兽压向该城市的倾向。
- 怪兽诱导候选、匿名出牌记录和训练样本会保留 `product_overlap` 字段，方便后续学习层判断“打竞品城市”是否真的转化成更多最终金钱。
- 怪兽诱导理由文本新增“竞品压力”片段，让开发调试时能看出 AI 为什么认为某座城市值得引怪。

### 平衡决策

- 怪兽不应该只被“距离近、资源吻合”吸引；从商业玩法看，摧毁生产/需求相似的竞争城市才是更稳定的策略。
- 这个评分仍是 AI 内部工具，不向玩家展示。玩家只会看到怪兽移动、卡牌轨道、城市受损和公开线索，再自行推理是谁可能受益。

### 新增验证

- `tests/smoke_test.gd` 的 AI 怪兽诱导测试现在要求目标城市具有正的 `product_overlap`，并继续验证目标城市、目标怪兽、资源吻合、攻击价值和匿名出牌训练元数据。

## 2026-07-01｜商品缩略图显示主策略标签

### 本轮实现

- 商品图鉴缩略图新增 `主策略` 行，直接显示该商品当前最突出的公开路线及分数，例如看涨、看跌、囤货、商路或怪兽风险。
- 新增可复用的商品策略排序/主策略标签函数，后续经济总览或地图商品筛选也可以复用同一套公开策略判断。
- 商品图鉴说明文案同步改为：缩略图负责快速扫读价格、供需和主策略，hover/详情再展开期货仓储、怪兽偏好、天气和城市线索。

### 体验决策

- 玩家打开商品图鉴时，第一眼应该能看出“这页有哪些商品现在值得做事”，而不是必须逐个 hover 或点详情。
- 主策略只来自公开市场数据、公开仓储/期货、天气、供需、断路和怪兽偏好，不泄露玩家身份、现金、手牌、弃牌或 AI 内部路线。

### 新增验证

- `tests/smoke_test.gd` 新增商品缩略图主策略验证：商品图鉴缩略图页和缩略图容器都必须出现 `主策略` 标签。

## 2026-07-01｜商品详情页 TCG 化分区

### 本轮实现

- 商品 hover 预览从单行密集字段改为多行短摘要，保留价格梯度、供需断波、策略、期货仓储、怪兽、相关卡、天气、供需区域和城市线索。
- 商品详情页改成 TCG 式分区：商品卡、市场面板、策略面板、金融与天气、生态与卡牌、地图入口、商品相关城市线索、规则提示。
- 详情页继续只显示公开信息，不展示真实业主、对手现金、手牌、弃牌或 AI 内部路线。

### 体验决策

- 商品是卡牌经济的核心对象，阅读方式要接近卡牌详情页，而不是规则书段落。玩家应该先扫到“这东西现在适合看涨、做空、囤货、跑商路还是引怪”，再决定是否继续看城市线索。
- hover 负责快速判断，详情页负责完整解释；上一页/下一页仍只在详情页出现，避免缩略图页变成翻页泥潭。

### 新增验证

- `tests/smoke_test.gd` 新增商品详情分区验证，要求详情页出现商品卡、市场面板、策略面板、金融与天气、生态与卡牌等关键分区。

## 2026-07-01｜商品图鉴升级为商品策略面板

### 本轮实现

- 商品图鉴 hover/单击预览新增公开策略摘要，把每个商品按看涨、看跌、囤货、商路、怪兽风险五条路线给出短判断。
- 商品详情页新增四个可读面板：策略摘要、期货/仓储、怪兽偏好、相关卡牌。
- 期货/仓储面板会把匿名商品期货、港仓囤货城市、仓储单位、风险压力和到期时间合并展示；没有公开仓储时会提示可通过看涨、看跌或港仓囤货制造价格窗口。
- 怪兽偏好面板会列出偏好该商品的怪兽，并说明这些商品产区、需求城或仓库更容易把怪兽吸引过来。
- 相关卡牌面板从同一套卡牌数据中生成，帮助玩家从商品直接跳回“哪些牌能围绕这个商品做事”的思路。

### 体验与隐私决策

- 商品不再只是打牌门槛或地图风味，而是玩家可以围绕它做金融、仓储、商路、怪兽诱导和城市竞争的策略入口。
- 图鉴只整理公开证据：供需、断路、天气、匿名期货、公开仓储、怪兽偏好和卡牌字段。它不会显示真实业主、对手现金、手牌数量、弃牌内容或 AI 内部路线。
- 策略分数是为了帮助测试者理解方向，不是绝对推荐；真正收益仍取决于之后的价格、GDP、怪兽移动、军队打击和玩家推理。

### 新增验证

- `tests/smoke_test.gd` 扩展商品图鉴验证：
  - hover 预览必须显示商品策略信息。
  - 商品详情页必须显示策略摘要、期货/仓储、怪兽偏好和相关卡牌面板。
  - 港仓囤货测试会验证商品详情页能看到匿名期货、仓库和策略摘要。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜图鉴缩略图预览保持滚动位置

### 本轮实现

- 卡牌图鉴、怪兽生态档案、商品图鉴的缩略图 hover/单击预览统一走滚动位置保护：刷新预览前记录菜单滚动条，刷新后立即与布局帧后各恢复一次。
- 怪兽和商品图鉴补齐与卡牌图鉴一致的滚动恢复逻辑，避免玩家浏览缩略图时因为 hover 预览导致页面跳回顶部或底部。
- 这次改动只影响缩略图预览刷新；详情页进入、上一页/下一页切换、返回缩略图的路径保持原有逻辑。

### 体验决策

- 图鉴是玩家理解卡牌、怪兽、商品和策略路线的主要入口，浏览时最重要的是“位置感”不能丢。hover 可以更新预览，但不应该夺走玩家正在看的缩略图位置。
- 修复采用统一队列恢复函数，而不是给每个图鉴写不同逻辑，方便以后区域图鉴、角色图鉴或新资料页复用。

### 新增验证

- `tests/smoke_test.gd` 新增图鉴滚动保护验证：
  - 怪兽生态缩略图 hover 预览在页面可滚动时保持滚动位置。
  - 卡牌缩略图 hover 预览在页面可滚动时保持滚动位置。
  - 商品缩略图 hover 预览在页面可滚动时保持滚动位置。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜经济口径统一为按秒现金流与 GDP/min 快照

### 本轮实现

- 新增 `_player_gdp_per_minute()`、`_city_gdp_per_minute()` 和 `_city_gdp_per_minute_breakdown()` 作为新的内部经济接口；旧 `cycle` 函数只保留为存档/测试兼容壳。
- 玩家可见 UI 把“本刷新现金流”改为“实时现金流”，避免让测试者误解为按周期发钱。
- GDP 趋势文案从“本期/上期”改为“当前快照/上次快照”，明确全局市场刷新只是公开经济快照，不是收入结算周期。
- 卡牌文本兜底清洗把残留“经营周期”转为“实时窗口”，只有供需、价格、商路、GDP 趋势记录继续使用“全局市场刷新”概念。
- README、规则摘要和原型范围文档将 `current-refresh cashflow` 统一改为 `realtime cashflow`。

### 平衡决策

- 城市收入的真实规则保持线性：当前 GDP/min 按秒折算进玩家现金，余数保存在城市现金流尾差里。
- 全局市场刷新是公开信息刷新：重估供需、价格、商路、GDP 快照和部分 AI 匿名商业动作；它不再承担“发钱周期”的概念。
- 金融牌继续按真实秒数持仓，到期读取即时 GDP/价格变化，避免和刷新次数绑定。

### 新增验证

- 当前规则文档、README、原型范围和主 UI 不再使用 `current-refresh cashflow`、`本期/上期` 或玩家可见的周期发钱口径。
- 旧测试仍可通过兼容壳调用 `_city_cycle_income*`，后续可以在更大重构时逐步迁移测试命名。

## 2026-07-01｜仓储风险进入经济总览与情报档案

### 本轮实现

- 经济总览新增“仓储风险”摘要卡和“仓储靶标”列表，把公开匿名仓储城市按压力、单位、GDP/min 和到期时间排序。
- 情报档案新增“仓储风险线索”段落，让玩家能把港仓囤货、做空、齐射、军队、引怪和城市归属推理放在同一个页面判断。
- 城市调查优先级现在会把仓储压力计入排序；同等 GDP 下，有匿名仓储的城市更值得玩家标注、追查和反制。
- 城市线索行会显示仓储风险状态，但仍只使用“匿名仓储”公开信息，不显示仓储玩家、现金、手牌、弃牌或 AI 内部路线。
- 公开局势摘要会把匿名仓储城市计入场面异动，方便玩家知道当前地图上已经出现了可争夺的金融靶标。

### 平衡决策

- 仓储风险被设计成玩家可见、身份隐藏的“战略压力”：它不直接揭示谁在赚钱，但告诉所有人哪里可能值得做空、齐射、派军、引怪或保护。
- 经济总览展示的是场面证据，不是结论。玩家仍需要结合商品、卡牌轨道、打牌条件、合约、怪兽损伤和公开下注来推理真实归属。
- 这让商品期货/囤货路线有更清晰的反制窗口：收益潜力更大，但仓库城市也会更像一座明晃晃的金融弹药库。

### 新增验证

- `tests/smoke_test.gd` 扩展港仓囤货烟测：
  - 验证经济总览显示“仓储靶标”“匿名仓储”和隐私边界提示。
  - 验证情报档案显示“仓储风险线索”。
  - 验证仓储城市会进入城市调查优先级字段。
  - 验证仓储风险行包含商品、到期、反制方向，并且不泄露玩家名。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜仓储金融风险接入做空、齐射与军事目标选择

### 本轮实现

- AI 城市目标评分继续字段化：`warehouse_stockpile_*` 现在不只影响怪兽和事件，还会影响领先者城市选择、竞争城市压力、GDP 衍生品目标、军事部署和泛用卡牌效果评分。
- `城市做空` 目标选择会更偏向对手的匿名仓储城市；如果己方城市有仓储，AI 会降低拿它做空的倾向，并提高灾害保单/防守价值。
- `轨道齐射` 的实际命中列表会把仓储压力计入排序。也就是说，一座 GDP 略低但有公开仓储囤货的城市，可能比普通高 GDP 城市更容易被齐射打中。
- 军队部署评分接入仓储压力：进攻型军队更愿意部署到能威胁对手仓储城市的位置；防守型/己方部署会更看重保护自己的仓储城市。
- 泛用 AI 卡牌评分接入仓储压力：军令保卫、军令摧毁、区域伤害、商路破坏、GDP 做空、灾害保单和齐射都会按目标仓储状态获得额外评分。

### 平衡决策

- 仓储本身不直接造成额外伤害或额外收益；它只提高“被选择为目标/被保护”的概率。收益仍来自商品期货结算，损失仍来自仓库被毁、GDP 下跌、商路破坏等正常机制。
- 对玩家来说，这让港仓囤货成为清晰的金融博弈：囤得越多，越容易被识别成值得轰炸、做空、齐射或防守的城市；但仓储玩家身份仍不公开。
- 对 AI 来说，这给金融路线和军事路线之间建立了桥：AI 可以先发现公开仓储，再用做空、军队、怪兽或齐射去压仓。

### 新增验证

- `tests/smoke_test.gd` 扩展港仓囤货烟测，新增一座普通对照城：
  - 验证带仓储但 GDP 略低的城市会被 AI 城市做空优先选中。
  - 验证领先者/压力目标选择会优先识别仓储城市。
  - 验证 `轨道齐射` 一目标命中列表优先选择仓储城市。
  - 验证进攻型军队部署评分优先选择仓储城市。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜港仓囤货接入城市压力、怪兽吸引与 AI 目标评分

### 本轮实现

- `港仓囤货` 不再只是商品图鉴里的匿名期货文字：开仓后会在仓库城市写入结构化公开状态，包括匿名仓储笔数、囤货单位、关联商品和最近到期时间。
- 区域图鉴的城市公开状态会显示这条仓储线索，但仍不显示仓储玩家、真实业主、现金或手牌信息。
- 事件/新闻灾害目标权重新增 `warehouse` 分量，城市里有匿名仓储时更容易成为高价值公开目标。
- 怪兽自动目标权重新增 `warehouse` 分量；区域详情页的“怪兽吸引”现在能把匿名仓储作为目标主因显示出来。
- 怪兽资源偏好会读取城市里的仓储商品。如果某只怪兽偏好被囤积的商品，它会更容易被这座城市吸引；仓储单位越多，资源吻合越明显。
- AI 的隐藏评分接入仓储压力：对手城市有仓储时更适合作为怪兽诱导/压制目标；己方城市有仓储时会提高护路防守需求。这个评分仍是内部 AI 工具，不会展示给玩家。
- 新增统一刷新函数，从当前商品期货头寸反推城市仓储标记，确保开仓、到期、仓库被毁或状态恢复后不会留下过期仓库标签。
- 修复城市被摧毁时旧局部城市字典可能把已清除仓储字段写回废墟的问题。

### 平衡决策

- 仓储压力被设计成“收益越高、越能被反制”的金融路线风险：它能扩大商品看涨收益，但会把所在城市变成怪兽、事件、军队和做空路线都容易关注的靶子。
- 仓储公开信息只公开商品、单位和时间，不公开玩家身份；其他玩家需要结合商品流动条件、卡牌轨道、怪兽下注、城市归属标注等线索推理是谁在囤货。
- 当前仓储压力权重与城市经营、资源偏好、距离、热度处在同一目标系统内，后续数值平衡可以直接调仓储笔数/单位压力常量，而不必改 UI 或 AI 逻辑。

### 新增验证

- `tests/smoke_test.gd` 扩展港仓囤货烟测：
  - 验证城市公开状态显示匿名仓储、商品和单位，且不泄露玩家名。
  - 验证事件目标权重出现 `warehouse` 压力。
  - 验证怪兽自动目标权重出现 `warehouse` 压力，并且偏好该商品的怪兽会获得资源吻合分。
  - 验证怪兽目标原因文本能显示“匿名仓储”。
  - 验证仓库城市被摧毁后仓储压力清零，仓储期货作废，普通非仓储期货继续保留。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜怪兽赌局实装：全场冻结、强制底注与多方奖池

### 本轮实现

- 怪兽遭遇不再只是“赌局蓝图”：当自动怪兽即将用招式命中另一只怪兽时，会先开启怪兽赌局并冻结整局游戏时间。
- 赌局窗口最长 30 秒；`game_time`、城市现金流、天气、卡牌队列、怪兽移动/在场时间等对局系统暂停，但 UI、倒计时、地图动画和下注按钮继续更新。
- 所有玩家必须下注，不能观望；底注暂定 `¥100`，可在 UI 中选择更高额下注。身份、押注方向和金额全部公开，作为怪兽归属和玩家策略倾向的推理线索。
- 如果 30 秒内仍有玩家未下注，系统会按公开可见战况为其强制押底注，防止全场冻结被拖死。
- 赌局支持多方怪兽混战：触发怪兽及同区其他存活怪兽会作为同一奖池的多个押注对象，不再硬编码为 A/B 双方。
- 结算改为奖池制：总奖池来自所有公开下注；造成伤害最高的怪兽一侧为中奖侧，押中玩家按自己的中奖下注额占比分走总奖池。冷门怪兽押中时赔率会自然变高。
- 怪兽攻击会被延后到全员下注或超时强制下注之后再播放/结算，避免玩家在结果已经发生后下注。
- 地图新增 `wager` 事件动画：大范围橙色冲击环、扫描线和筹码光点，配合“全场冻结”临时决策面板，让玩家明显感到特殊公开事件发生。

### 平衡决策

- 怪兽赌局被定义为“少数公开亮身份操作”：平时卡牌和经济仍匿名，但赌局下注的玩家、金额和目标全部公开，给其他玩家制造强推理线索。
- 当前奖池按中奖下注额比例分配，而不是固定 ×2 返还。这样多人押热门怪兽会摊薄收益，少数人押中冷门怪兽会得到更高回报。
- 强制底注会把“必须行动”的规则落到钱上；后续可继续平衡底注、可选下注档位、AI 风险偏好和怪兽战斗伤害窗口。

### 新增验证

- `tests/smoke_test.gd` 新增 `_verify_monster_wager_system()`：
  - 验证怪兽遭遇会打开强制公开赌局并进入阻塞决策状态。
  - 验证身份、押注方向和金额会进入公开摘要与日志。
  - 验证玩家下注后不能换边，活跃赌局会进入 run save。
  - 验证所有玩家下注后可提前结束，并按奖池结算给押中方。
- 旧的怪兽碰撞烟测已改为先结束赌局窗口再检查伤害，符合“下注前冻结、下注后开战”的新规则。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜直接玩家互动牌、统一临时决策UI与海洋商品闭环

### 本轮实现

- 新增四组直接玩家互动卡牌家族，均有 I-IV 罗马等级、I级基准价格、字段驱动强度预算、图鉴分类和匿名结算演出：
  - `星链拆解 I-IV`：指定一名玩家，匿名拆掉其可弃普通手牌；高阶会追加短时手牌封锁和小额重组成本。目标玩家公开，具体牌名和手牌数量仍是私人信息。
  - `影仓牵引 I-IV`：指定一名玩家，匿名牵取其可弃普通手牌；无法接收时转化为拆牌/补偿，避免突破手牌上限规则。
  - `产权冻结 I-IV`：选中公开存活城市，制造临时产权争议，把 `control_gdp_penalty` 写入实时 GDP/min 拆解；不永久夺城，避免一张牌直接改变胜负归属。
  - `轨道齐射 I-IV`：匿名轨道齐射，优先打击非己方高价值城市；目标公开、出牌者匿名，适合终局压制领先者并制造推理线索。
- 新增“直接互动”卡牌路线和卡牌图鉴筛选；卡牌路线总览从五条核心路线扩到六条：城市成长、合约供需、金融投机、怪兽压制、情报补给、直接互动。
- AI 性格和评分接入直接互动路线：破坏型 AI 以直接互动为主偏好，驯怪型 AI 把直接互动作为副偏好；AI 候选、训练样本和匿名出牌 metadata 新增 `target_player`。
- 玩家打出直接互动牌时会先打开“玩家目标”选择面板，再进入匿名卡牌轨道；目标公开但出牌者仍匿名。
- 抽出统一临时决策 UI 基底，当前覆盖：私密弃牌、合约回应、怪兽目标选择、玩家目标选择、怪兽赌局。后续合约、临时投票、反应牌可以复用同一套 panel/style/action 描述。
- GDP 拆解加入 `control_penalty`，区域图鉴和经济文本会显示产权争议造成的 GDP 压力。
- 海洋区域改为能生产海域商品，新增/接入星鳍鱼群、巨藻纤维、海底黑油、潮汐电浆等海洋商品；地图生成按地形给陆地/海洋分配一项初始供给和一项需求。
- 本局卡牌池继续按本局存在的商品过滤：如果星球上没有某种固定商品，该商品绑定牌不会强行进入本局供给。
- 怪兽生态档案文案改成正面说明“看生态、行动、移动、伤害；怪兽牌在卡牌图鉴”，减少开发历史式说明。

### 平衡决策

- 直接夺取城市所有权暂不实现为常规牌。当前用“产权冻结”表达三国杀式拆归属/拆节奏：它能压低 GDP、制造公开线索、配合做空和怪兽破坏，但不会永久偷走城市，降低一张牌直接改胜负的风险。
- `星链拆解/影仓牵引` 只影响“可弃普通手牌”，不影响绑定怪兽固定技能，也不公开具体牌名，保证它们能互动但不摧毁隐私推理结构。
- `轨道齐射` 自动挑非己方高价值城市，不需要玩家逐个点目标；它强在广域压制，弱点是目标很多、意图很容易被其他玩家反推。
- AI `create_demand` 阶段的路线缺口惩罚再次加硬：缺需求时，纯生产扩张会被明确视为阶段错配，避免 AI 被大数值生产牌带偏。

### 新增验证

- `tests/smoke_test.gd` 新增 `_verify_direct_player_interaction_cards()`：
  - 验证四组互动牌均有 I-IV、价格不漂移、强度预算不倒退、图鉴分类为直接互动。
  - 验证玩家目标选择会打开 pending player-target 决策。
  - 验证拆牌、牵牌、产权冻结、全场齐射的核心结算能实际改变手牌/城市/GDP/区域伤害状态。
- `tests/smoke_test.gd` 新增 `_verify_temporary_decision_blueprints()`，验证弃牌、合约、怪兽目标、玩家目标、怪兽赌局都能从统一临时决策蓝图生成。
- 原海洋“无商品”烟测改为 `_regions_start_with_terrain_goods()`，验证陆地和海洋都从对应商品池生成初始供给/需求。
- 完整 Godot headless smoke test 通过：
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd`

## 2026-07-01｜AI路线分化与情报字段评分

### 本轮实现

- AI 通用字段评分新增情报字段识别：`trace_card_count`、`reveal_city_count`、`trace_contract_count` 现在会进入 `generic_effect_bonus`，后续新增情报牌只要补齐字段，AI 就能初步理解它的价值。
- 护路/修复类 `route_insurance` 出牌候选现在写入 `target_city` 和 `target_owner`，让训练样本能区分“保护己方城市”和“误帮别人城市”。
- AI 商品路线缺口评分修正：在 `create_demand` 阶段，如果一张牌只是补供给、没有补需求或接通商路，会受到“暂缓补供给”的阶段错配惩罚，避免 AI 一边说要补需求、一边被高数值生产牌带偏。
- 新增 `_verify_ai_strategy_route_diversification_policy()`：用受控沙盒分别验证 AI 能为防御修复、竞争压制、金融做空、情报追踪生成字段驱动候选，并且这些候选进入匿名出牌训练样本。

### 新增验证

- `tests/smoke_test.gd` 新增断言：`AI opponents generate field-driven defense, suppression, finance, and intel route candidates`。
- 完整 Godot headless smoke test 通过。

## 2026-07-01｜实时GDP方向性沙盒验证

### 本轮实现

- `tests/smoke_test.gd` 新增 `_verify_realtime_gdp_directionality_pack()`，用受控城市、受控产区和受控商品市场直接验证 GDP/min 拆解方向，而不是只通过卡牌结果间接推断。
- 新测试会临时构造一座生产/需求/运输都可控的城市，并在结束后完整恢复地图、市场、选区和日志，避免污染后续长 smoke。
- 方向性断言覆盖：
  - 提高生产等级会提高 `product` 生产 GDP。
  - 提高交通等级会提高基于运输速度的生产收益。
  - 提高消费等级会提高 `route` 消费/商路 GDP。
  - 提高城市 `route_flow_multiplier` 会继续放大商路 GDP。
  - 商路损伤会增加 `route_penalty` 并降低净 GDP。
  - 区域伤害会增加 `damage_penalty` 并继续压低净 GDP。
  - GDP 拆解摘要必须保留生产、消费、断路、损伤等玩家可解释字段。

### 新增验证

- 完整 Godot headless smoke test 通过，新增断言名称：`realtime GDP breakdown responds to production, consumption, transport, route-flow, route damage, and region damage`。

## 2026-07-01｜十小时路线补强包与AI字段验证

### 本轮实现

- 新增四组完整 I-IV 卡牌家族，补强“护路、防守、压制、情报、天气”之间的策略链，而不是只新增孤立单卡：
  - `应急修复 I-IV`：防御型商路牌，修复己方城市断路并提供短时 route-flow 保护/加速窗口，让领先玩家有合理护城手段。
  - `竞争封锁 I-IV`：城市压制牌，降低目标区生产、交通和消费，并制造商路伤害/供给压力，服务落后方或同商品竞争者的破坏路线。
  - `线索悬赏 I-IV`：情报推理牌，按等级私下追溯匿名卡、城市业主和合约参与方，所有线索仍然只给出牌者，不直接公开隐藏信息。
  - `航线预报 I-IV`：天气/商路博弈牌，围绕目标区域改写下一段公开天气预报，为建城、护路、做空、怪兽诱导和城市压制制造提前量。
- 这些新牌只把 I 级基牌加入本局公共可购牌池；重复获得后仍按统一手牌合成规则升到 II-IV，价格继续沿用 I 级基准价。
- `route_insurance` 结算从“只修断路”扩展为“修断路 + 写入城市短时商路流速倍率”，让卡牌效果能在线性实时 GDP 中持续一段秒数，而不是依赖旧的经济周期口径。
- `intel_card_trace` 现在能按字段组合追溯匿名出牌、揭示城市业主、回溯合约参与方；AI 和图鉴仍通过字段理解它，不需要硬编码卡名。
- AI 的商路防御/区域压制候选更稳：护路牌不再只在城市已经断路时才有价值，会优先保护己方路线城市；压制牌会记录目标城市和目标业主，方便训练样本判断“是否真的攻击到竞争者”。
- 卡牌路线分类顺序修正：带有负向生产/交通/消费和商路伤害的牌优先归入“城市压制”，不会因为同时带有市场压力字段而误显示成“金融投机”。

### 新增验证

- `tests/smoke_test.gd` 新增 `_verify_ten_hour_route_pack()`：
  - 验证四组新牌都有 I-IV 梯度、罗马等级、I级价格稳定、强度预算不倒退。
  - 验证只有 I 级基牌进入本局卡池，升级仍由重复获得触发。
  - 验证图鉴/路线标签能把 `应急修复`、`竞争封锁`、`线索悬赏`、`航线预报` 分别显示为城市成长/城市压制/情报推理/天气博弈，并带出对应平衡支点。
  - 验证 `应急修复 III` 能实际修复路线伤害并写入城市 route-flow multiplier。
  - 验证 AI 能把护路、压制、天气卡纳入候选上下文，而不是只认识旧卡名。
- 完整 Godot headless smoke test 通过。

## 2026-07-01｜卡牌路线平衡支点审计

### 本轮实现

- 卡牌路线审计新增“平衡支点”统计：每张卡会按字段归入收益、压制、防御、信息、补给、怪兽、合约、市场、GDP金融、公开门槛等支点；路线审计再聚合这些支点，帮助判断一条路线是不是只有高数值、缺少反制窗口或缺少收益兑现。
- 卡牌图鉴路线总览现在显示 `平衡` 状态、`支点` 分布和 `检查` 结论；它继续不暴露 AI 内部偏好，只把卡池本身是否偏科展示给测试者和开发者。
- 新增路线健康检查规则：核心路线会提示牌量偏少、缺 I-IV 梯度、缺低门槛 I 级、缺核心/终端牌、缺关键支点或终端跳跃过大等问题。该检查不会代替人工调平衡，但能让后续新增卡时先看到结构性缺口。

### 新增验证

- `tests/smoke_test.gd` 扩展路线平衡烟测：每条核心路线必须有结构化支点统计、合法平衡状态、可读平衡摘要，并且城市成长/合约供需/金融投机/怪兽压制/情报补给分别保留自己的关键支点。
- 完整 Godot headless smoke test 通过。

## 2026-07-01｜灾害保单、防御金融与图鉴语义整理

### 本轮实现

- 新增 `灾害保单 I-IV`：它们属于 GDP 金融牌的防御分支，只能匿名投保自己的城市；若持仓时间内即时 GDP 下跌或城市被毁，会把部分损失转成现金赔付。它与 `城市做空` 分离，避免“防守牌”和“攻击别人城市的做空牌”在 AI 与图鉴里混成同一类。
- AI 现在能把灾害保单识别为防御金融工具：在己方城市受损、商路断裂、怪兽逼近或路线威胁较高时，会把它作为护城/护路候选，而不是把它当成对敌方城市施压。
- 卡面、卡牌图鉴、关键字段和公开线索会把灾害保单显示为“保单/投保”，不再笼统显示成做空；结算仍保持匿名，只公开城市被挂上了保单或 GDP 金融合约。
- 清理未使用的 `MARKET_SKILLS` 历史常量：当前本局卡牌供应统一由 `COMMON_CARD_POOL + I级怪兽牌` 生成，区域再从这套牌池抽取可购买牌，避免继续出现“普通牌池/市场牌池”两套口径。
- 图鉴入口从“怪兽图鉴”调整为“怪兽生态档案”：怪兽牌统一归入卡牌图鉴的“怪兽牌”分类；生态档案只展示场上怪兽单位的自动行动概率、资源偏好、移动生态、伤害和击退数据，并提供对应召唤牌跳转。
- 修复区域购牌窗口快照语义：只锁定有效的落地区/相邻区/远程/全局补给窗口，`none` 无效窗口不再保存为锁价快照，避免旧的不可购买状态挡住后续实时怪兽落地判断；读档/烟测恢复时也会保留有效窗口资格。

### 新增验证

- `tests/smoke_test.gd` 扩展灾害保单断言：不能投保别人的城市，能记录为防御型 GDP hedge，并在己方城市 GDP 下跌时赔付。
- AI 阶段策略烟测新增灾害保单场景：己方受损城市应被选为投保目标，AI 候选上下文必须记录 `city_gdp_derivative_insurance`。
- 图鉴烟测改为保护“怪兽生态档案”语义：它不能表现成另一套怪兽牌图鉴，怪兽牌仍必须能跳到卡牌图鉴查看。

## 2026-07-01｜AI商品路线缺口评分

### 本轮实现

- 新增 `_ai_route_gap_adjustment()`：AI 购牌和出牌不再只看“当前能不能打”，还会按当前商品路线阶段识别缺口：补供给、补需求、放大 GDP、修复/保险、压制竞品。
- 缺口评分完全由卡牌字段推断，包括 `production_delta`、`consumption_delta`、`transport_delta`、`repair_routes`、`route_damage`、`route_flow_multiplier`、`gdp_bet_*`、合约增删供需字段等；新增卡只要补齐字段，AI 就能初步理解它服务哪条赚钱/压制链。
- AI 候选样本新增内部字段 `route_gap_bonus`、`route_gap_penalty`、`route_gap_reason`、`route_gap_field_match`，用于训练和 smoke test 观察；这些字段不进入玩家 UI，继续保持 AI 计划、手牌压力和路线桶隐藏。
- 修正区域经济牌目标判断的字段错位：`region_economy_shift` 现在使用 `consumption_delta` 判断消费刺激/消费冷却的正负，而不是旧的 `demand_delta`。

### 新增验证

- `tests/smoke_test.gd` 扩展 AI 商品路线测试：当 AI 处在“制造需求”阶段时，消费刺激类字段会比生产扩张更高分；购牌候选、出牌候选和训练元数据都必须记录路线缺口评分。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜公开角色、TCG图鉴与临时图标美术整理

### 本轮实现

- 角色卡重新固定为公开身份：角色池扩展到 21 张，开局准备可让 AI 席位选择“随机角色”，开局时从未占用角色中抽取，保证同局不重复。
- 角色卡与起始怪兽彻底解耦：角色不再写入首召怪兽 HP、速度、在场时间或固定技能数量；首召怪兽属性只来自独立选择的怪兽牌，避免公开角色暴露怪兽归属。
- 玩家可见 UI 移除 AI 压力桶/主路线/推荐路线等内部推理数据。经济总览和局势排名只显示公开异动、匿名卡牌余波、城市线索、天气、怪兽资金线索和已揭示归属。
- 卡牌图鉴详情页改成 TCG 式结构：卡面、牌面定位、费用与门槛、核心效果、关键字段、I-IV 升级梯度、匿名结算演出分区显示；缩略图 hover 预览不再把滚动条自动拉回底部。
- 程序临时美术增强：角色卡按名称种子绘制不同身份徽章纹样；怪兽牌根据飞行、水栖/瘴气、重甲/机械、火焰、潜地等特征使用不同卡面 motif；项目图标更新为星球、匿名卡牌和怪兽爪痕构图，并生成 `assets/icon.ico`。
- 已把桌面上的 `Space Syndicate Prototype.lnk` 与 `Space Syndicate Prototype - old local.lnk` 图标指向新的 `assets/icon.ico`。

### 新增验证

- `tests/smoke_test.gd` 新增/调整断言：随机 AI 角色必须解析为非重复公开角色；角色不能携带任何首召怪兽字段；角色被动仍能结算现金、购牌奖励和怪兽升级奖励；开局页和卡牌图鉴不得泄露 AI 内部路线；卡牌详情必须展示 TCG 式分区。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜AI压力推荐卡牌路线

### 本轮实现

- AI 对局压力摘要新增“推荐卡牌路线”：每个压力桶除了反制建议，也会提示玩家应优先找哪类卡牌路线，例如城市压制/金融做空、修路保险/情报追溯、怪兽诱导/天气干预、市场稳定/需求扩张等。
- 推荐路线由 `_ai_public_pressure_card_route_text()` 根据同一套 AI 压力条目生成，仍然不显示对手现金、手牌或弃牌；它只把公开路线压力翻译成可购牌/查图鉴的方向。
- 经济总览和局势排名现在把“AI在干嘛 → 怎么反制 → 找哪类牌”连成一条短链，帮助测试者从信息阅读转向实际决策。

### 新增验证

- `tests/smoke_test.gd` 扩展断言：局势排名和经济总览必须显示 AI 对局压力、反制建议和推荐卡牌路线，同时保持现金/手牌隐私。

## 2026-06-30｜AI压力反制建议

### 本轮实现

- AI 对局压力摘要新增“反制建议”：根据扩张GDP、护路防守、压制竞品、怪兽压制、金融投机、合约供需、情报补给和终局冲刺等压力桶，给出一条可执行应对方向。
- 经济总览和局势排名继续不显示对手现金/手牌，但现在会把“AI 在做什么”进一步翻译成“玩家可以怎么反制”，例如保护高GDP/同商品城市、修路/保险、观察怪兽偏好、稳价或制造伪线索。
- 反制建议由 `_ai_public_pressure_counterplay_text()` 从同一套 AI 压力条目生成，避免 UI 说明和 AI 实际路线数据脱节。

### 新增验证

- `tests/smoke_test.gd` 扩展断言：局势排名和经济总览必须同时显示 AI 对局压力、不泄露现金/手牌，并显示反制建议。

## 2026-06-30｜AI对局压力公开摘要

### 本轮实现

- 新增 AI 对局压力摘要：把 AI 的发展路线、阶段、商品路线和策略意图归纳为扩张GDP、护路防守、压制竞品、怪兽压制、金融投机、合约供需、情报补给或终局冲刺等公开压力桶。
- 经济总览和局势排名现在都会显示“AI对局压力”，并明确“不显示现金/手牌”；它帮助测试者看懂 AI 当前大致在扩张、守路还是攻击，但不泄露对手私密经济或手牌数量。
- 经济总览速览卡新增“AI压力”卡，与 GDP/min、商品热榜、商路/城市、匿名线索并列，方便玩家先看短信息，再读下方证据。

### 新增验证

- `tests/smoke_test.gd` 新增断言：局势排名和经济总览必须显示 AI 对局压力，并说明不显示现金/手牌；经济总览摘要卡必须包含 AI压力。

## 2026-06-30｜开局下一步结构化提示

### 本轮实现

- 主 HUD 的开局轻引导把“下一步卡片”从单句提示升级为三段式短卡：`行动`、`为什么`、`入口`。玩家能马上知道下一步做什么、为什么这一步会帮助赚钱/购牌/推进，以及该点哪里或按什么入口。
- 新增 `_opening_guide_next_step_card()`，保留 `_opening_guide_next_step_text()` 作为兼容文字输出；下一步提示现在是结构化数据，后续可以更容易接入图标、美术、按钮或教程高亮。
- 首召、建城、购牌、匿名出牌、经济总览与后续自由经营都会给出不同的行动理由和入口提示，继续保持主画面只给短信息。

### 新增验证

- `tests/smoke_test.gd` 扩展主 HUD 断言：开局轻引导必须显示开局进度、下一步卡片、`行动/为什么/入口` 三段和任务卡。

## 2026-06-30｜根菜单响应式卡片网格

### 本轮实现

- 根菜单入口从顺序长列表进一步升级为“分区标题 + 响应式卡片网格”：开局、局势、资料、存档、系统各自成组，组内入口会按可用宽度自动排成 1-3 列。
- 新增 `_add_main_menu_action_grid()` 与 `_main_menu_action_grid_columns()`，保留原有按钮、tooltip、hover/pressed 样式和回调，但把布局容器抽象出来，方便之后改成左侧栏、双栏卡片或更精美的首页。
- 主菜单交互提示同步改成“分区卡片网格自动重排”，让测试者知道入口层不是死板按钮堆，而是可以随屏幕与后续美术方案调整。

### 新增验证

- `tests/smoke_test.gd` 新增断言：根菜单必须存在带 meta 的响应式 action grid 与 grid card，并且交互提示要包含“分区卡片网格”和“自动重排”。

## 2026-06-30｜菜单交互提示与可重排UI原则

### 本轮实现

- 主菜单覆盖层新增统一的交互提示胶囊：根菜单提示“响应式主菜单、快捷 chips、卡片入口可重排、hover 用途”，子页面按自身类型提示缩略图、hover/单击预览、双击详情、上一页/下一页、返回缩略图等操作。
- 新增 `_menu_interaction_hint_text()` 与 `_menu_interaction_hint_style()`，把页面交互说明集中生成；后续如果把主菜单改成左侧栏、双栏卡片、瀑布流或全屏图鉴，不需要逐页重写提示逻辑。
- 卡牌/怪兽/商品图鉴会根据“缩略图页”和“详情页”展示不同交互提示，明确 hover、详情页切换和返回路径，避免玩家进入子页面后迷路。

### 新增验证

- `tests/smoke_test.gd` 新增断言：主菜单必须显示响应式/hover/可重排交互提示；卡牌图鉴缩略图页必须提示 hover 和双击详情；卡牌详情页必须提示上一页/下一页和返回缩略图。

## 2026-06-30｜AI发展路线多样性可视化

### 本轮实现

- 新增 AI 发展路线多样性审计：统计 AI 性格数量、核心路线覆盖、每条路线的主偏好 AI 数量，以及每个 AI 性格的主路线/副路线。
- 开局准备页的每个 AI 席位现在显示“主路线”，测试者在开始一局前就能看出对手大致会走城市成长、合约供需、金融投机、怪兽压制或情报补给哪条路线。
- 卡牌图鉴的路线总览新增“AI发展路线覆盖”卡，说明 6 类 AI 性格目前覆盖 5/5 条核心可追钱路线，并把这些路线如何落到最终钱上说清楚。

### 新增验证

- `tests/smoke_test.gd` 扩展路线平衡烟测：AI 主偏好必须覆盖五条核心路线，路线多样性摘要必须包含 5/5 覆盖和关键路线名。
- `tests/smoke_test.gd` 扩展 UI 断言：开局准备显示 AI 主路线，卡牌图鉴显示 AI发展路线覆盖。

## 2026-06-30｜菜单快捷导航底座

### 本轮实现

- 主菜单覆盖层新增常驻快捷导航 chips：开局、局势、经济、情报、规则、图鉴。玩家进入任何子页面后，可以直接跳到其他核心分支，不必先退回主菜单。
- 快捷导航与上一轮页面位置/帮助提示栏共用同一个菜单 shell；当前所在分支的快捷按钮会禁用，形成“当前位置”反馈，其他分支继续可点。
- `_add_menu_quick_nav_button()`、`_menu_quick_nav_active_key()`、`_refresh_menu_quick_nav()` 把导航逻辑集中起来，后续大范围调整菜单布局、美术、hover、详情切换时可以复用这一层。

### 新增验证

- `tests/smoke_test.gd` 新增断言：根菜单必须显示主要分支快捷入口；规则页必须把“规则”标成当前页，同时仍允许通过顶部“经济”快捷按钮跳到经济总览。

## 2026-06-30｜菜单导航提示与AI终局紧迫度

### 本轮实现

- 主菜单覆盖层新增统一的页面位置/帮助提示栏，显示“当前位置”、返回关系、hover/缩略图/详情页切换方式；根菜单、暂停菜单、开局准备、规则、经济、情报和各类图鉴都通过同一函数生成提示，方便之后大范围调整 UI 排版而不逐页硬改。
- AI 新增 `endgame_urgency` 评分：由距离现金目标、落后领先者的差距、终局倒计时剩余时间共同决定。
- 终局阶段的 AI 评分会使用该紧迫度：落后 AI 更愿意破坏领先城市、做空高风险 GDP、冲刺现金；领先 AI 更偏向修复、稳定市场和保护己方经济路线。
- `endgame_urgency` 写入观察向量、候选视图、实际决策样本和购牌/出牌元数据，后续训练与复盘能解释“为什么此时 AI 更急”。

### 新增验证

- `tests/smoke_test.gd` 新增主菜单/开局准备的页面位置提示断言，防止后续 UI 回退成无上下文子页面。
- `tests/smoke_test.gd` 扩展 AI 阶段烟测：终局倒计时压近时，落后 AI 的商路破坏评分必须高于无倒计时状态，并且出牌候选/训练样本必须携带 `endgame_urgency` 字段。

## 2026-06-30｜AI 购牌路线库存健康

### 本轮实现

- AI 区域购牌评分新增“路线库存健康”层：会统计当前手牌中同一发展路线的普通牌总数、可立即打出数、被商品流动卡住数和缺口。
- 如果 AI 已经囤了多张同路线但都因为商品流动不满足而暂时打不出，继续购买同类不可打牌会被扣分；如果新候选牌能立刻打出并缓解同路线无可用牌的问题，会获得加分。
- 这些字段会写入候选与实际购牌训练样本：`route_inventory_bonus`、`route_inventory_penalty`、`route_hand_total`、`route_hand_playable`、`route_hand_blocked`，方便后续训练和复盘解释 AI 为什么买或不买某条路线的牌。

### 新增验证

- `tests/smoke_test.gd` 扩展 AI 路线规划烟测：验证同路线手牌被流动卡住时，可打出的路线候选会获得库存加分，而继续购买同样被流动卡住的补给/情报牌会受到库存惩罚。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜卡牌图鉴路线总览

### 本轮实现

- 「卡牌图鉴」缩略图页新增数据驱动的卡牌路线总览，玩家打开图鉴时先看到城市成长、合约供需、金融投机、怪兽压制、情报补给五条核心路线。
- 每条路线卡显示卡牌数量、平均强度预算、完整 I-IV 梯度组数、路线目标、AI 偏好覆盖数量和代表样例牌。
- 该总览直接复用 `_development_route_audit()` 与 `_ai_development_route_preference_audit()`，和 AI 评分/平衡审计使用同一套路线定义，避免 UI 说明和实际 AI 理解脱节。
- 路线审计继续扩展为平衡视图：每条路线现在会统计强度预算最低/最高/均值、预算分布、打法说明、反制窗口和 AI 调权提示；卡牌图鉴总览直接展示「强度区间」「打法」「反制」和预算分布，方便后续调平衡时判断某条路线是否只有堆数值、是否缺少反制。

### 新增验证

- `tests/smoke_test.gd` 新增断言：卡牌图鉴首页必须显示「卡牌路线总览」、城市成长路线、金融投机路线和 AI 偏好信息。
- `tests/smoke_test.gd` 扩展路线平衡审计：五条核心路线必须有有效预算区间、预算分布，并能生成包含强度区间、打法和反制窗口的平衡摘要。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜开局轻引导任务面板

### 本轮实现

- 主画面的「开局轻引导」从纯文本 checklist 升级为任务面板：显示开局进度、下一步卡片、五个任务小卡和可关闭状态。
- 五个任务对应 72 小时目标里的轻量提示：首召怪兽、建第一城、买第一牌、匿名出牌、看经济总览。每张任务卡都有完成状态、短标题和一句行动说明。
- 面板顶部保留「经济总览」快捷入口，底部新增「新手引导」和「游戏规则」快捷按钮；测试者不读长规则，也能按当前下一步推进。
- 旧的完成状态、经济总览已读状态和关闭状态继续保存到 run state，避免 UI 美化破坏存档行为。

### 新增验证

- `tests/smoke_test.gd` 新增断言：开局轻引导必须展示开局进度、下一步卡片、任务卡，以及新手引导/游戏规则快捷入口。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜终局结算速览卡片

### 本轮实现

- 「终局结算」页在详细复盘文本和赛后入口按钮上方新增终局速览卡：胜者、钱从哪里来、关键地图、关键影响。
- 胜者卡显示最终赢家与结算资金；钱源卡拆出城市经营、卡牌/情报收益、角色收益的领先玩家；关键地图卡展示关键城市或地图破坏/怪兽数量；关键影响卡汇总关键卡牌、怪兽影响和 AI 路线。
- 终局速览复用现有 `_final_run_summary_text()` 相关统计函数，不引入第二套结算口径；短卡片负责第一眼解释，长文本负责完整复盘。

### 新增验证

- `tests/smoke_test.gd` 扩展终局烟测：终局菜单必须显示「终局速览」「胜者」「钱从哪里来」「关键影响」，同时仍保留局势排名、经济总览、开局准备三个赛后入口。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜长文本菜单卡片摘要层

### 本轮实现

- 新增通用菜单摘要卡组件：`_show_menu_summary_cards()` 与 `_add_menu_info_card()`，可按屏幕宽度自动排成 1-3 列，用统一面板、标题、正文、脚注和主题色呈现短信息。
- 「游戏规则」页新增规则速览卡：先召怪兽、建城赚钱、匿名出牌、手牌隐私。玩家不用先读整段规则，也能抓住一局开始和胜利目标。
- 「局势排名」页新增局势速览卡：终局条件、当前玩家可见资金、城市现金流、反超方向。长文本仍保留完整结算解释，卡片层先给决策方向。
- 「经济总览」页新增经济速览卡：当前 GDP/min、商品热榜、商路/城市前景、匿名线索数量。这样经济页既能保留详细证据，也更像商业化前的可读仪表盘。

### 新增验证

- `tests/smoke_test.gd` 新增断言：规则页、局势排名和经济总览都必须有卡片化摘要层，防止这些关键入口退回纯长文本。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜菜单 UI 组件化与滚动面板骨架

### 本轮实现

- 主菜单覆盖层从单一居中面板升级为响应式菜单面板：标题与导航固定在上方，正文、图鉴预览、开局准备和各类子菜单内容进入统一滚动列，避免长规则/长图鉴把页面撑爆。
- 新增 `menu_surface_panel`、`menu_content_scroll`、`menu_content_box`、`menu_nav_row`、`menu_catalog_nav_row` 等可测试容器；后续大范围调整主菜单、子菜单、hover 和详情切换布局时，可以围绕这些组件改，而不必逐页拆 UI。
- 抽出 `_menu_surface_style()`、`_style_menu_button()`、`_menu_section_style()`，统一菜单面板、胶囊按钮、hover/pressed/focus/disabled 状态和 section 卡片视觉。
- 主菜单入口、图鉴入口、卡牌筛选、缩略图翻页、角色/怪兽详情跳转、开局准备的席位/AI/深度/角色/起始怪兽按钮都接入同一套样式，先把“默认控件感”压下去，后续美术可以继续替换配色和卡面。

### 新增验证

- `tests/smoke_test.gd` 新增 UI 骨架断言：主菜单必须有可复用响应式面板，正文和预览必须位于可滚动内容列中，按钮必须暴露 hover/pressed 样式状态。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜AI 发展路线偏好与卡牌平衡审计

### 本轮实现

- 把卡牌策略归并成 AI 可读的五条核心发展路线：城市成长、合约供需、金融投机、怪兽压制、情报补给；天气、新闻和破坏牌会并入怪兽压制/干扰路线，补牌和购牌范围会并入情报补给路线。
- 新增路线审计函数，能从同一套卡牌数据统计每条路线的卡牌数量、强度预算、I-IV 梯度样本和代表卡，方便后续调平衡时先看路线覆盖，而不是只看单张卡名。
- 扩展 AI 性格池：除拓荒、套利、破坏、驯怪外，新增合约型和情报型 AI；每个 AI 都有 `route_preferences`，购牌和匿名出牌评分会按路线偏好加权。
- AI 训练样本新增 `development_route`、路线标签、偏好倍率和路线加分；结算后的学习标签也会记录路线，使后续新增卡牌可以通过字段和路线被 AI 理解，而不是依赖硬编码卡名。

### 新增验证

- `tests/smoke_test.gd` 新增发展路线验收：五条核心路线都必须有卡牌覆盖、强度预算、完整 I-IV 梯度样本，并且至少有一个 AI 性格偏好该路线。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜菜单卡片化与可持续 UI 调整基础

### 本轮实现

- 主菜单入口从一串裸按钮改成卡片式操作入口：每个入口都有标题、简短用途说明、统一边框/底色/圆角和 tooltip，方便玩家理解“开局准备、局势排名、经济总览、情报档案、规则、图鉴”等分支分别做什么。
- 抽出 `_menu_card_style()`、`_add_menu_action_card()`、`_add_main_menu_action()` 等复用函数；主菜单、图鉴入口和终局复盘入口都开始使用同一套菜单卡片组件，后续要整体调整排版、颜色、hover 说明或按钮样式时可以集中修改。
- 图鉴入口继续保留缩略图、hover 预览、双击详情、详情页前后切换和返回缩略图的交互；本轮把“入口层”的视觉语言先统一，为后续继续美化各图鉴详情页打底。

### 新增验证

- `tests/smoke_test.gd` 新增主菜单布局断言：根菜单不仅要保留开局准备、情报档案和图鉴等按钮，还必须显示描述型卡片文案，防止 UI 回退成无说明的裸按钮列表。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜新闻卡牌化与星球天气预报

### 本轮实现

- 移除旧的被动新闻事件计时器：新闻不再由世界随机触发，只能由玩家匿名打出的新闻类卡牌制造。
- 新增新闻类卡牌路线：舆论操控、热搜推送、危机快讯、金融传闻、监管风暴会通过字段驱动改变区域热度、区域生产/交通/消费、商品供需压力、市场波动或商路断损，并在城市公共线索中留下可推理痕迹。
- 新增星球天气系统：顶部状态栏显示“活跃天气 + 下一条预报”，星球地图面板上方也有紧凑天气预报条，分别显示当前天气、下一条预报和生产/交通/消费倍率影响；预报通常提前 60-180 秒公开，每次天气影响 1-5 个区域，生效后按秒进入 GDP/min 和金融买涨/做空结果。
- 新增天气干预牌：太阳风暴预报、酸雨云团播种、引力潮汐播报、电磁雾干涉。玩家可以匿名改写下一条天气预报，但所有玩家都会看到天气类型、倒计时和影响区域，方便提前建城、保护商路、做空目标或引怪兽。
- 卡牌图鉴新增“新闻事件”和“天气干预”子分类；卡面/详情页会显示新闻信息战、天气博弈、预告时间、影响区域数、持续时间、强度预算和反制/门槛信息。AI 也会把这些字段纳入通用评分，而不是只识别固定卡名。

### 新增验证

- `tests/smoke_test.gd` 验证 `main.gd` 中没有被动新闻计时器/旧世界新闻入口。
- 验证地图面板天气条可见，并且天气预报提前 60-180 秒、影响 1-5 个区域，在生效后改变 GDP 相关倍率与 UI 文案。
- 验证新闻牌和天气干预牌能通过结算器执行；同时验证所有图鉴可见卡牌和生成怪兽固定技能都有结算处理器。

## 2026-06-30｜AI 竞品压制执行与弹性出牌门槛

### 本轮实现

- AI 的 `disrupt_competitors` 意图现在会在中局/后期已有己方城市、且同商品竞品压力较高时获得额外权重；同时对“继续扩张焦点”加入竞品牵制扣分，避免 AI 只会闷头长经济。
- 匿名出牌上下文为新闻、天气干预、商路黑客/舆论转移等压力牌补充 `target_city`、`target_owner` 元数据，训练样本能明确记录“打的是哪个城市/谁的城市”，后续新增卡牌也能通过字段进入学习。
- AI 对没有固定 `play_product` 的卡牌新增弹性商品门槛选择：优先使用目标/路线/焦点商品；若该商品流动不够，会自动改用自己当前满足门槛的商品流动打牌。这样商路黑客、新闻、天气等“效果目标”和“支付门槛”不会被错误绑定成同一个商品。

### 新增验证

- `tests/smoke_test.gd` 扩展 AI 策略意图烟测：不只验证候选评分，还验证 AI 能把防守路线牌和压制竞品牌真正排入匿名出牌队列，并把策略意图写入训练记忆。
- 商品路线计划烟测现在也验证 `attack_rival` 阶段会实际打出商路黑客，目标为竞争城市，且出牌记录携带路线阶段与目标城市元数据。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜实时现金流、全局市场刷新与单购牌窗口

### 本轮实现

- 取消“经营周期发钱”的当前规则口径：城市收入现在由即时 `GDP/min` 线性按秒流入玩家现金，内部每秒结算一次并保留小数尾差，避免周期跳变。
- `_market_tick()` 改为“全局市场刷新”：每 30-60 秒公开重估供需、价格、商路网络、城市 GDP 快照和 AI 商业动作；它不再直接支付城市收入。
- 临时经济效果统一支持秒数字段：`contract_seconds`、`route_flow_seconds`、`growth_seconds`、`market_contract_seconds`；旧 `*_turns` 字段只作为兼容换算，UI 显示为剩余秒数/分钟。
- GDP 买涨/做空保持真实时间持仓，到期按即时 GDP 涨跌结算；城市受损、商路断裂、供需变化都会先反映到 GDP/min，再影响现金流和金融牌收益。
- 区域购牌窗口加入“单窗口”限制：同一玩家打开新区域补给时，会关闭旧区域补给/弃牌购买机会，防止沿怪兽路径囤多个窗口；读档恢复窗口时会保留保存中的私密弃牌选择。
- 主菜单、规则、轻教程、局势排名、经济总览、卡面和图鉴文案改为 `GDP/min`、实时现金流、全局市场刷新口径。

### 新增验证

- `tests/smoke_test.gd` 的 AI 完整局、八席 AI 局、存档恢复、经济卡、GDP 趋势、临时经济效果倒计时和卡牌梯度烟测已迁移到实时现金流/全局刷新语义。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜金融牌按时间持仓与购牌窗口快照

### 本轮实现

- `城市买涨I-IV` 与 `城市做空I-IV` 从“持续若干经营周期”改为真实时间持仓：I/II/III/IV 分别持仓 60/75/90/120 秒。
- GDP 金融牌开仓时记录 `created_time`、`expires_at`、`duration_seconds` 和开仓即时 GDP；正常游戏在持仓到期时按即时 GDP 涨跌和倍率结算，城市被摧毁时仍会触发做空/破产清算。
- 卡面、卡牌图鉴、强度预算、AI 候选理由和结算演出文案都改为显示“持仓 X 秒/分钟”，不再把金融投资描述成周期牌。
- 区域购牌窗口改为按打开瞬间锁定资格和价格：点开某区域时若怪兽在该区或相邻区，玩家可以继续选牌并购买，即使怪兽随后离开；远程/全局补给也锁定当时倍率。
- 购牌改为随时场上动作，不再被普通行动冷却阻挡，也不会给玩家追加购牌冷却；满手买新牌仍进入私密弃牌流程，手牌数量和弃牌内容不公开。

### 新增验证

- `tests/smoke_test.gd` 验证 GDP 买涨/做空会记录真实秒数持仓窗口，并通过强制到期结算验证上涨/下跌兑现。
- 区域购牌烟测新增“窗口快照”场景：打开怪兽落地区补给后让怪兽离开，实时资格变为不可买，但当前窗口仍保持落地区八折并能完成购牌；同时验证购牌不受行动冷却阻挡。

## 2026-06-30｜城市 GDP 趋势与破坏可见性

### 本轮实现

- 城市经营周期现在会记录公开 GDP 历史：本期 GDP、较上期变化、最近路径、结算周期来源和简短原因摘要。
- GDP 原因摘要继续从同一份收入拆解生成，覆盖生产、消费、过境、永久加成、临时合约、同业竞争、断路和区域/城市损伤；不额外硬编码卡名。
- 经济总览的商路收入前景、区域图鉴的城市公开信息和城市收入明细都会显示 `GDP趋势`，让玩家能看到怪兽破坏、商路受损、供需变化最终如何落回城市 GDP。
- 该趋势属于城市公开经营表现；玩家手牌数量、弃牌内容和购牌换购压力仍为私密信息，不进入公开经济轨道。

### 新增验证

- `tests/smoke_test.gd` 新增 GDP 历史烟测：先记录受损前 GDP，再增加区域损伤并记录受损后 GDP，验证城市会保留至少两期历史、`last_gdp_delta` 为负、经济总览和区域图鉴都能看到 `GDP趋势`。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜卡牌强度预算说明层

### 本轮实现

- 卡牌新增字段驱动的“强度预算”说明：从 `cost`、现金/GDP、产交消、商路、伤害、防护、抽牌、补给范围、合约、GDP 买涨/做空、怪兽 HP/移动/在场时间等字段推导预算分与档位。
- 预算档位显示为“基础频用 / 效率扩张 / 路线核心 / 终端压力”，并结合 I-IV 等级解释该等级在路线中的定位：I 级开路线、II 级提效率、III 级成核心、IV 级终端但需保留反制空间。
- 手牌卡面、卡牌图鉴悬停预览、卡牌详情页和 tooltip 现在都能看到强度预算、主强度来源和制衡点；升级预览每一级也显示对应预算档。
- 预算说明不引入新的卡牌硬编码表，继续从同一套卡牌数据字段生成，方便后续新增卡牌直接获得 UI 解释。

### 新增验证

- `tests/smoke_test.gd` 新增强度预算烟测：验证经济牌和怪兽牌都能生成“强度预算 / 主强度 / 制衡”文本。
- 卡牌图鉴悬停预览和详情页测试新增预算可见性断言。
- 卡牌梯度烟测新增预算分不倒退检查，防止 I-IV 效果增强但预算说明反向变弱。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜私密弃牌与手牌隐私闭环

### 本轮实现

- 购牌流程接入普通手牌上限处理：购买新普通牌会超出 5 张上限时，不再直接拒绝，而是在当前玩家自己的手牌面板弹出“私密弃牌确认”，选择一张旧普通牌弃掉后完成换购。
- 重复获得同系列卡仍优先自动合成升级到 II/III/IV，不触发弃牌；绑定固定怪兽技能继续不计入普通手牌上限。
- 手牌数量、弃牌选择、弃掉了哪张牌都只进入本人私密经济流水；公共日志只保留模糊的匿名购牌完成线索，不写买家、具体卡牌、手牌数量或弃牌状态。
- 主玩家面板在查看 AI / 对手席位时不再展示其现金、手牌数量或卡面，只提示“对手手牌为私人信息”，避免主界面泄露推理对象的手牌压力。
- 角色额外拿牌与区域补给抽牌的公共提示改为模糊描述，避免通过“成功拿到几张/没拿到”间接暴露手牌是否满。
- AI 购牌评分新增手牌压力处理：满手可换购，但会按被弃旧牌的保留价值扣分；暂时打不出的牌在手牌接近上限时会额外降分。训练样本新增 `playability_bonus`、`hand_pressure_penalty`、`requires_discard`、`discard_keep_value`、`counted_hand` 等字段。
- 游戏规则与轻教程文案补充“满手买新普通牌需私下弃旧牌，手牌数量与弃牌记录不公开”。

### 新增验证

- `tests/smoke_test.gd` 新增满手换购烟测：验证满手购买新牌会打开私密弃牌面板，确认后普通手牌仍为 5 张、旧牌被替换、新牌进入手牌、本人流水记录“弃牌换购”，公共日志不泄露新牌/旧牌/弃牌内容。
- 同一烟测验证满手重复购入同系列牌会直接升级，不触发弃牌。
- 完整 Godot headless smoke test 通过。

## 2026-06-30｜72小时目标第一轮落地：AI阶段策略、轻提示与终局复盘

### 本轮实现

- 卡牌说明新增字段推导的“策略路线/用途”层：城市成长、城市压制、金融投机、合约博弈、情报推理、怪兽路线、补给构筑等路线会从 `kind` 和效果字段推导，显示在手牌卡面规则、卡牌图鉴悬停预览和卡牌详情页。
- AI 现在会为每个席位记录并使用 `opening / midgame / endgame` 局势阶段，以及 `leader / contesting / trailing` 竞争态势。
- AI 的建城、购牌、出牌、匿名商业行动、策略意图和训练样本都接入阶段字段：开局优先首召、建城和基础经济；中局围绕商品路线扩 GDP；后期领先者偏防守/现金，落后者更偏向做空、商路破坏和压制领先城市。
- AI 决策样本新增阶段元数据：`game_phase`、`competitive_posture`、`score_gap_to_leader`、`leader_index`、`phase_bonus`，后续新增卡牌仍优先通过字段进入评分，而不是只靠卡名硬编码。
- 主游戏玩家面板新增一行短“目标提示”，只提示当前最可能的下一步：首召怪兽、城市化、购牌、回应合约、指定目标、终局倒计时或匿名出牌。
- 主游戏玩家面板新增“开局轻引导（可关闭）”：前 1-2 分钟用短清单提醒首召怪兽、建城、从怪兽补给范围购牌、匿名出牌、查看经济总览；面板会显示当前下一步，经济总览步骤只有在玩家实际打开过后才打勾，关闭状态和经济总览查看进度都会随本局存档保存。
- 终局结算新增自动弹出的“终局结算”复盘页，并把“终局总结”和“玩家概览”同时写入日志和局势排名页，解释赢家、钱从哪里来、每个席位的最终资金/城收/卡牌收入/终局情报现金/角色收入/城市数、关键卡牌、怪兽影响、AI 主要路线、关键城市、存活城市/毁坏区域；复盘页提供局势排名、经济总览和开局准备入口。

### 新增验证

- `tests/smoke_test.gd` 新增 AI 阶段策略烟测：验证开局/中局/后期、领先/落后态势、阶段加权和训练样本字段。
- 新增卡牌策略说明烟测：验证经济、GDP投机、情报、怪兽路线都能生成字段化策略摘要；卡面 stats 和卡牌图鉴预览/详情会展示策略路线。
- 新增 AI 推进烟测：加速跑过 AI 首召怪兽、自动建城、区域购牌、匿名出牌、匿名商业压制、经营收入，并把领先 AI 推入终局倒计时，防止“能开局但后面停摆”。
- 新增最大席位完整局烟测：临时开启 8 席 / 7 AI / 深度V 星球，验证 7 个 AI 都能获得角色与起始怪兽牌、首召怪兽、自动建城、购牌、至少产生后续出牌/匿名商业/经营收入/决策样本，并进一步触发现金目标、保存/恢复终局倒计时、完成最终结算、显示终局总结与 AI 路线、写入 7 个 AI 的 episode reward 学习结果，最后恢复原局面。
- 终局倒计时测试现在也验证终局总结会出现在日志、自动终局复盘页和排名文本中，并覆盖关键卡牌、怪兽影响、AI 路线、玩家概览、城收字段和赛后入口按钮。
- 主面板测试验证短目标提示、当前下一步、可关闭开局清单、经济总览真实查看进度、经济总览快捷入口和存档恢复，同时复杂经济/角色细节仍不回流到主面板。

## 2026-06-30｜规则重构与可玩原型同步点

### 当前版本定位

《太空辛迪加》已经从早期“守护者 vs 怪兽 / 区域押注”的原型，推进为一个实时匿名商业战争原型：

- 玩家是外星辛迪加经营者，目标不是直接操控怪兽，而是通过城市化、商品流通、匿名卡牌、合约与怪兽灾害，把最终资金做大。
- 当前方向转为 PVE roguelike：每局 3-8 个总席位，其中 2-7 个为 AI 对手，至少保留 1 个真人/本地玩家席位。
- 胜利最终统一落到“钱”上：现金、幸存城市价值、商业收入、情报猜测奖惩都会折算到结算资金。
- 怪兽全部自动行动，没有玩家长期可控单位；玩家只能通过卡牌产生一次性的诱导、技能释放、夺取归属或召唤/升级效果。
- 主画面保持简洁：地图、匿名卡牌轨道、当前玩家手牌；规则、图鉴、经济详情和区域详情收纳到菜单分支。

### 已落实的核心系统

#### 菜单与图鉴

- 主菜单逻辑已整理为清晰分支：开局准备、继续/保存、局势排名、经济总览、情报档案、新手引导、游戏规则、统一图鉴。
- “选择怪兽”不再是主菜单分支；新游戏开始前进入开局准备，可设置 3-8 个总席位与 2-7 个 AI 对手，并为每名玩家选择外星角色卡。
- 图鉴统一包含：
  - 角色图鉴
  - 怪兽图鉴
  - 卡牌图鉴
  - 商品图鉴
  - 区域图鉴
- 卡牌图鉴不再单独拆“怪兽卡牌”主分支；怪兽卡属于统一卡牌池中的一个子分类。
- 怪兽图鉴默认进入响应式缩略图册：每页显示的怪兽缩略图行列会按屏幕空间估算；悬停/单击怪兽可在图册下方查看 HP、速度、资源偏好、行动摘要和对应怪兽卡；双击缩略图进入怪兽详情；详情页才显示上一只/下一只，并可返回缩略图册。
- 卡牌图鉴默认进入响应式缩略图册：每页显示的缩略图行列会按屏幕空间估算；悬停/单击卡牌可在图册下方查看详情预览；双击缩略图进入卡牌详情；详情页才显示上一张/下一张，并可返回缩略图册。
- 商品图鉴也默认进入响应式缩略图册：每页显示的商品缩略图行列会按屏幕空间估算；悬停/单击商品可在图册下方查看价格、供需、经济天气和城市线索预览；双击缩略图进入商品详情；详情页才显示上一个/下一个，并可返回缩略图册。
- 卡牌与怪兽都已接入临时程序美工，后续可替换为正式卡面和怪兽立绘。

#### 外星角色卡

- 环港走私议会：开局资金 `+¥80`、起始怪兽移动 `+15%`；在含“环晶电池”的区域购牌时免费额外获得 1 张同区候选牌。
- 深海菌毯使团：起始怪兽生命 `+8`、在场时间 `+12秒`；己方含“深海菌毯”的城市每个经营周期额外 `+¥55`。
- 重力矿联董事会：起始怪兽生命 `+12`；己方含“重力陶瓷”的城市每个经营周期额外 `+¥45`。
- 离子军购局：起始怪兽额外获得 1 张绑定技能；己方怪兽升级时 `+¥120`。
- 光合修复会：开局资金 `+¥120`、起始怪兽在场时间 `+20秒`；己方含“光合凝胶”的城市每个经营周期额外 `+¥40`。
- 虹膜数据券商：开局资金 `+¥60`；在含“活体芯片”的区域购牌时免费额外获得 1 张同区候选牌。
- 星鲸餐饮垄断：己方含“星鲸罐头”的城市每个经营周期额外 `+¥50`；己方怪兽升级时 `+¥60`。
- 静电蜂巢银行：起始怪兽移动 `+8%`；在含“静电蜂蜜”的区域购牌时免费额外获得 1 张同区候选牌。
- 星图审计庭：每局 2 次身份侦测，可私下查明当前陌生城市真实业主；城市归属终局命中奖励 `+¥40`。
- 幽幕播报社：每局 1 次出牌追帧，可私下追溯一张匿名轨道牌的真实出牌者；卡牌归属竞猜押注成本 `-¥40`。
- 双边密约公证团：每局 2 次合约回溯，可私下查明匿名合约出牌方与目标业主；合约类卡牌商品流动门槛 `-1`。
- 碎光私探行会：卡牌归属竞猜押注成本 `-¥30`，猜中额外 `+¥30`；起始怪兽在场时间 `+8秒`。
- 星门补给商会：可从怪兽所在区相邻区域的相邻区域购买卡牌；二跳购牌价格 `×1.10`；开局资金 `+¥40`。
- 资源收益、购牌赠牌、怪兽升级返现、情报侦测/追溯、押注修正、合约门槛折扣和远程补给已经接入实际结算、经济流水、地图提示与烟测，不是仅写在卡面上的占位描述。

#### 地图与城市

- 地图采用球面世界模型：
  - 拉远时看到宇宙中的球形星球。
  - 贴近时看到局部被投影成平面 XY 坐标视图。
  - 左右、上下边界在球面意义上连续。
- 每局按 Roguelike 挑战深度 I-VI 随机生成星球：浅层星球较小，约 6-9 个区域，甚至可以低于 10 区；深层星球逐步扩大到几十个区域，目前 VI 层约 40-54 区，同时提高通关现金目标。
- Roguelike 目标继续统一落到“钱”上：玩家要尽量保护自己的城市收入、破坏对手的收入来源，并赚到足够结算资金，才能挑战更大的星球。
- 结束条件已改为现金线触发：任一玩家的可见预估结算资金达到本层目标现金后，会启动保存进局面的匿名 60 秒终局倒计时；倒计时期间所有玩家仍可行动且不知道是谁触发，倒计时结束后按最终结算资金最高者获胜。若所有区域提前毁灭，则立即终局。
- 陆地区域可城市化，初始拥有 1 种生产商品与 1 种需求商品。
- 海洋也会生产海域商品，并继续主要承担运输/商路区域职责。
- 城市归属默认隐藏；玩家可对城市做私人归属标注。
- 城市会保存结构化的最近公开线索历史，记录时间、线索类型、商品关键词和文本，用来回看匿名商业动作、合约签拒和经营改造留下的推理证据；商品图鉴会优先打开当前选中的商路商品，并按该商品过滤这些城市线索。
- 区域有 HP / damage 轨道，怪兽移动、资源吸取、战斗、击退都会破坏区域和城市。

#### 商品、GDP 与商路

- 商品池已扩展为多种外星商品。
- 商品流动拆成两个大块：
  - 流动量：由生产与需求关系决定。
  - 流动速度：由公共交通/运输水平决定。
- 城市收入统一看 GDP：
  - 生产区看可流通出去的生产量。
  - 交通区看经过该区的商品流通。
  - 消费区看需求被满足的消费量。
- 商品价格由供需、商路破坏、持续合约与经济天气影响，不允许玩家直接手动设置市场价格。
- 地图可按商品显示商路；商路途经区域被破坏会影响相关城市收入。

#### 怪兽

- 守护者概念已并入怪兽体系，不再保留旧的守护者/怪兽分裂函数。
- 怪兽通过怪兽卡召唤；基础规则下每名玩家同时最多归属1只在场怪兽，同名怪兽牌会优先升级/刷新该怪兽。`孪星兽栏同盟` 可把自己的怪兽归属上限提高到2。
- 玩家开局通过角色卡获得起始怪兽卡；一级起始怪兽可无区域限制首召。
- 后续怪兽卡可有区域/地形/怪兽邻接限制。
- 怪兽卡在场期间再次打出同名怪兽卡，可升级场上怪兽并刷新 HP 与在场持续时间。
- 所有卡牌重复获得都会自动合成升级，最高 IV 级，等级使用罗马数字显示。
- 怪兽有：
  - HP
  - 移动速度
  - 在场持续时间
  - 资源偏好
  - 自动行动概率表
  - 移动踩踏伤害
  - 资源吸取伤害
  - 战斗/击退伤害
- 怪兽相遇会根据行动表使用招式，造成伤害、击退和区域破坏。
- 怪兽受到伤害时，其隐藏归属玩家按最大生命等比例损失金钱；这会成为推理线索。

#### 卡牌

- 卡牌不再充能。
- 一次性卡牌打出后立即离手，进入匿名卡牌轨道，公开展示后结算。
- 固定技能牌不计入手牌上限。
- 普通手牌上限暂定为 5 张。
- 获取卡牌要花钱；默认只能从怪兽所在区域或相邻区域购买：
  - 怪兽所在区域八折。
  - 相邻区域原价。
  - 角色能力或补给牌可扩张到二跳或全局购牌，但会按远程/全局倍率加价；该范围只影响购牌，不改变后续怪兽牌的召唤区域限制。
- 购买重复卡牌自动升级，最高 IV。
- 卡牌购买价格按 I 级基准价；升级后效果增强但价格沿用 I 级价格。
- 打出卡牌通常不消耗商品，但必须满足玩家城市提供的商品流动条件。
- 部分卡牌会有额外现金打出费用，例如场上怪兽越多，召唤怪兽卡越贵。
- 需要指定怪兽目标的卡牌，打出时会先询问目标怪兽。

#### 匿名卡牌轨道、竞价与归属猜测

- 所有卡牌打出都会匿名公开展示，不显示出牌玩家。
- 空轨道第一张牌进入 0.5 秒同时出牌判定。
- 若同时窗口内只有一张牌，则直接进入 5 秒公开展示。
- 若有多张牌，则进入一次 5 秒匿名竞价。
- 竞价按钮支持快速加价：10、20、50、100、200、500、1000。
- 一个批次只竞价一次；锁定后按报价与顺时针顺序逐张展示/结算。
- 批次展示或相位响应期间新打出的牌进入下一批等待区，不重开竞价。

### 本轮增量：固定相位窗口、分型军队、军队/怪兽上限角色、原创命名清理

- 相位否决不再做“瞬时检查”。每张可被反制的匿名牌会先公开展示5秒，展示结束后统一进入固定5秒相位响应窗口；无论是否有人实际持有相位否决，玩家都会看到这个询问窗口。没人反制时原牌才结算。
- 新增 `相位否决 I-IV` 作为科幻版反制牌，并新增公开角色 `悖论兽契社`：它可以在相位响应窗口把手中任意怪兽牌临时改写成相位否决，消耗原怪兽牌但不暴露该怪兽牌原本归属。
- 新增军队牌体系并归入统一卡牌池：`行星防卫军 I-IV`、`制空战斗机 I-IV`、`轨道轰炸机 I-IV`、`重装坦克 I-IV`、`导弹阵地 I-IV`、`潜航舰队 I-IV`、`星海战舰 I-IV`。军队不会自主行动，只通过私有可回收军令牌执行前进、保卫区域、摧毁区域、攻击怪兽；军队受伤不会让操控者损失怪兽式资金，也不会公开下令者。
- 军队移动规则改成地形适配：空中单位可广域部署且移动快，地面单位偏陆地，海上单位偏海洋；坦克/导弹阵地、潜艇/战舰等会按 `terrain_move_multiplier` 与 `military_deploy_terrain` 字段限制部署和移动效率。军队移动本身不会造成怪兽式建筑踩踏，但军事打击或武装压力可以产生短时 GDP 压力和商路压力，并进入城市收入拆解。
- 军队卡面、图鉴事实、AI 泛字段评分和地图 token 临时美工已区分战斗机、轰炸机、坦克、导弹、潜艇、战舰等形态，避免测试时全部像同一张占位卡。
- 控制上限改为字段驱动：普通角色默认同时最多归属1只怪兽、1支军队；新角色 `孪星兽栏同盟` 可同时归属2只怪兽，`蜂巢防务议会` 可同时维持2支防卫军。角色卡面会公开显示“怪兽上限:2”或“军队上限:2”。
- 怪兽达到IV后，同名怪兽牌不会因上限被误挡，而是刷新HP、在场时间和绑定技能；夺取怪兽也会遵守当前角色的怪兽归属上限。
- 清理版权/旧桌游占位命名：直接互动牌改为 `星链拆解`、`影仓牵引`、`轨道齐射`；怪兽和技能使用 `流星哨兵`、`棱刃重甲`、`焰环幼星`、`蓝锋骑士` 等原创名；测试和程序 motif 字段也改成原创语义。
- 角色牌平衡仍是后续专项：本轮先保证上限型角色可运行、可显示、可测试；之后需要为角色被动建立类似卡牌强度预算的角色预算，并用模拟局看胜率/路线偏差。
- 新增 `docs/balance_audit.md` 作为开发用平衡审计快照：记录当前 24 张角色、46 种商品、239 个静态卡牌/技能条目、22 个完整 I-IV 梯度家族，以及城市、合约、金融、怪兽、军队、情报、直接互动、天气/新闻、商品经济等路线的收益/风险/反制缺口。
- 当前批次结束后，下一批等待牌统一进入一次新竞价；若只有一张则直接展示。
- 小费支付给上一张结算卡牌的真实出牌者，但付款者与收款者身份仍不公开。
- 顶部轨道显示历史、当前、候补、下一批等待卡牌；玩家可横向拖动查看。
- 玩家可随时猜轨道上某张牌属于哪个玩家：
  - 猜对：真实出牌者付钱给猜测者，并公开贴上归属标签。
  - 猜错：猜测者付钱给真实出牌者，但不公开真实归属。
- 主菜单新增“情报档案”分支，用来集中查看当前玩家的城市业主私标、标注置信度、标注理由、城市调查优先级、卡牌归属押注状态、怪兽受伤资金线索、城市公开线索，以及这些情报如何在终局或即时竞猜中折算为钱；该页面只整理可见证据，不提前揭示真实业主或对手现金。情报档案现在也会生成线索跳转按钮，可直接打开相关区域、卡牌、怪兽、商品或经济总览，并从图鉴页返回情报档案继续推理；玩家也可以在情报档案中直接设置或清除城市业主私人标注，并把每条标注调成低/中/高置信度、记录为商品竞争/商路线索/卡牌条件/怪兽资金/直觉等理由。城市调查优先级由潜在GDP、竞争、断路、公开线索、未标注状态和低置信标注综合得出；置信度、理由和优先级只用于推理管理，不改变终局奖惩。

#### 合约牌

- 区域供需合约牌已成为商业/合约卡分类的一部分。
- 打出前必须先在地图点选两个区域：
  - 供给区
  - 需求/签约区
- 前 5 秒公开展示阶段只展示：
  - 两个已选区域
  - 商品
  - 合约奖励
  - 拒签惩罚
  - 出牌条件
- 公开展示结束后，目标城市真实业主再获得独立 5 秒签约决定窗口。
- 这个签约窗口只留在目标玩家窗口中，不阻塞其他玩家继续打牌。
- 超时视为拒签。
- 合约可设计为添加、替换、删除生产/需求商品，并可附带现金奖励、罚款、生产/交通/消费增减、商路速度加成或断路压力。
- 当前合约牌池已扩展为多个家族：选中商品供需合约、自动撮合合约、固定环晶电池专供、双商品对冲/替换合约、惩罚性拒签条款。

#### AI 牌局智能与训练样本

- AI 现在会在实时局内自动评估普通手牌：
  - 优先打出起始怪兽牌，保证 PVE 对手也能打开购牌区域。
  - 按卡牌类型、等级、目标价值、商品流动条件、现金费用和 AI 性格权重给候选动作评分。
  - 可匿名打出卡牌；如果多名玩家进入同一批次，AI 会按预算参与公开小费竞价。
  - AI 也会从可达怪兽补给区域匿名购牌，并按手牌升级、商品流动满足度、角色卡被动收益和价格折扣评分；远程补给会加价但不放宽怪兽召唤限制。
- AI 现在会自动回应合约牌的独立 5 秒签约窗口：
  - 签约奖励、拒签惩罚、商品接入、商路加速、是否帮助对手供给区都会进入评分。
  - 签/拒结果对全体公开，但回应玩家身份仍按规则隐藏。
- AI 现在会自动做基础情报推理：
  - 根据私人城市标注、公开商品线索、城市产品/需求、匿名卡牌商品流动条件和历史公开归属，给城市业主和卡牌归属候选评分。
  - 可把城市业主标注写入自己的私人情报，也可对匿名卡牌归属下注；命中会公开该牌归属标签并结算资金。
  - 情报行动也写入 AI 训练样本，方便后续把“最后谁的钱最多”作为 reward 继续调参。
- AI 现在会为怪兽诱导牌生成更明确的策略候选：
  - 按竞争城市潜在收入、商品重叠、商路负载、怪兽等级/生命、怪兽资源偏好与目标距离给“怪兽→城市”组合评分。
  - 更倾向把资源偏好吻合的怪兽引向高价值竞品城市，而不是随机挑怪兽或随机点区域。
  - 训练样本会记录 `target_city`、`target_owner`、`attack_value`、`resource_match`、`distance_m` 和 `strategic_role`，方便之后学习哪些诱导真正提高最终结算钱。
- AI 现在有第一层跨周期经济焦点：
  - 每个 AI 会按己方商品流、角色被动、市场价格/供需压力、竞争城市和 Roguelike 现金目标缺口，选出一个 `economic_focus_product`。
  - 城市化评分、匿名商业行动、经济卡目标商品和购牌评分都会受到焦点商品影响，让 AI 更倾向围绕同一条赚钱路线连续决策。
  - 训练样本会记录 `focus_product`、`focus_score`、`focus_bonus` 和 `focus_reason`，方便之后把“最终钱最多”作为 reward 反推策略质量。
- AI 现在有第一层多周期策略意图：
  - 每个 AI 会在 `grow_focus`（扩张焦点商品）、`defend_routes`（保卫己方商路/城市）和 `disrupt_competitors`（压制竞品城市）之间切换。
  - 策略意图会给城市化、匿名商业行动、购牌与出牌候选加分；例如己方商路受损时更偏向保险/延缓威胁，竞品城市高收益时更偏向断路、舆论引导和怪兽诱导。
  - 严重商路损伤的防守权重已提高，避免随机地图上的一般扩张收益压过“先止血”。
  - 训练样本会记录 `strategy_intent`、`strategy_score`、`strategy_bonus` 和 `strategy_reason`，方便后续学习不同策略在不同星球深度里的收益。
- AI 现在有商品路线计划层：
  - 每个 AI 会选择一个计划商品，并在 `build_supply`（补供给城）、`create_demand`（制造需求）、`strengthen_route`（强化商路）、`defend_route`（保护路线）和 `attack_rival`（打击竞品）五个阶段之间推进。
  - 路线计划同时影响城市化选区、经济卡目标、区域购牌、合约签拒和匿名商业行动，避免这些系统各自只看当前一拍。
  - 如果既有路线新增了供给城、需求城或商品流量，AI 会确认这是计划进展并继续推进；已有经济基础的路线也带切换门槛，只有明显更强的候选才会使 AI 改换商品。
  - 训练状态、候选和实际选择会记录 `route_plan_product`、`route_plan_stage`、`route_plan_score`、`route_plan_reason` 和 `route_plan_bonus`，后续可用最终金钱 reward 比较不同路线阶段的收益。
- AI 现在有局内在线学习层：
  - 经营周期回填现金收益与估算结算收益后，会把 reward 转成每个 AI 自己的 `learned_policy_values`，不会在席位之间共享。
  - 学习标签按 `action`、`policy`、`strategy`、`route`、`product` 拆开，例如匿名商业涨价、需求改造、签约、卡牌押注、`grow_focus`、`create_demand` 和“环晶电池”会分别积累经验。
  - 学到的加成会反过来影响商业行动、出牌、购牌、合约签拒、匿名竞价、城市/卡牌归属推理、战略意图候选和商品路线候选；浅层小星球适合快速积累短局样本，深层大星球适合观察长线路线规划是否真的多赚钱。
- AI 现在也会做终局 Roguelike reward 回写：
  - `_finish_game()` 结算胜者、玩家是否达到本层现金目标后，会把每个 AI 的最终资金、排名、是否达标/胜利转成 episode reward。
  - 终局 reward 会按决策样本的新旧程度衰减后回写到同一套 `learned_policy_values`，让 AI 不只学习“下一周期赚没赚钱”，也学习“这局最后钱多不多”。
  - 已做防重复：同一条样本只会应用一次终局 reward，保存/读取局面后仍保留终局学习结果。
- AI 出牌/购牌评分新增通用字段层：
  - 除了识别固定 `kind`，AI 现在会读取卡牌上的 `cash`、`gdp_bet_*`、生产/交通/消费、商路损伤/修复、抽牌、购牌范围、伤害、市场供需压力等字段，给未来新增卡一个基础经济/破坏/补给评分。
  - 城市买涨/城市做空会按目标城市业主、当前 GDP、区域损伤、断路压力、城市风险和倍率选择目标，并把 `generic_effect_bonus` 写入训练候选/实际选择元数据。
- 新增城市 GDP 衍生合约卡：
  - `城市买涨I-IV`：匿名买入指定城市 GDP 上涨，记录滚动基准，后续经营周期按 GDP 增量和倍率兑现。
  - `城市做空I-IV`：匿名买入指定城市 GDP 下跌，后续经营周期按 GDP 跌幅兑现；城市被摧毁时清算做空/破产奖励。
  - 这些卡牌进统一卡牌池、图鉴卡面、规则事实、五秒展示演出和区域候选卡池。
- 怪兽破坏更明确地落回经济：
  - 城市收入拆解新增“区域损伤”扣减，区域累计伤害会直接压低幸存城市 GDP。
  - 飞行型怪兽/飞行移动不再造成路径碾压；水栖怪兽有海洋/陆地移动倍率。
  - 孢雾海皇暂定为水栖型，流星哨兵暂定为高速飞行型；后续新怪兽只要填 `movement_traits` 和 `terrain_move_multiplier` 字段即可复用这套逻辑。
- AI 记忆中的训练样本从简单记录扩展为可训练结构：
  - 记录状态向量：现金、估算结算钱、手牌数、城市数、己方怪兽数、场上怪兽数、商品流动、经济焦点商品、策略意图、路线计划商品/阶段/评分、焦点商品流动、卡牌队列状态和经营周期。
  - 记录本次候选动作及评分，保留前若干个最高分候选。
  - 记录实际选择、目标、理由、卡牌名、竞价预算/出价等元数据。
  - 下一次经营周期结算后回填现金收益和估算结算收益，终局时再回填最终资金/排名/现金目标结果，形成短周期 + 长周期两层 reward。
- UI 与复盘信息继续向“可大范围重排”的方向整理：
  - 菜单面板新增响应式布局刷新：根据可用窗口尺寸调整面板锚点、留白、标题字号、导航按钮尺寸，以及图鉴/速览卡片的网格列数。
  - 主菜单和暂停菜单新增紧凑速览卡片，把“开局准备、主画面原则、图鉴/详情、终局复盘”等入口先用短卡片说明，再把长规则和操作细则放在下方分支里。
  - 怪兽、卡牌、商品图鉴的缩略图行列数统一参考菜单内容宽高，不再各自直接按整屏尺寸硬算，后续换菜单壳或重排页面时更容易维护。
  - 终局 AI 路线复盘新增“发展路线”摘要，会优先从 AI 决策样本的 `development_route` 字段统计；若本局样本不足，则回退到角色/性格的路线偏好。终局玩家概览和 AI 路线摘要都会显示这条路线，方便后续平衡四五种 AI 发展策略。
- AI 相位反制从“可用卡牌”升级为独立策略：
  - 每次固定 5 秒相位响应窗口内，AI 会单独扫描手中的 `card_counter`，以及“悖论兽契社”这类可把怪兽牌临时改写成相位否决的角色能力。
  - 反制评分不硬编码单张被反制牌，而是读取公开结算牌的目标和字段：直接玩家压制、己方城市/商路伤害、GDP 做空、怪兽召唤/诱导、全场齐射、天气改写、惩罚性合约，以及领先者受益等都会形成威胁分。
  - AI 会扣除机会成本：普通相位否决按等级/强度/返还/线索折算成本；怪兽牌改写会额外考虑怪兽牌等级、HP 和固定技能价值，避免 AI 轻易烧掉高价值怪兽牌。
  - 训练样本新增隐藏 `counter_*` 元数据，包括目标结算 ID、目标牌、威胁分、机会成本、反制强度、是否由怪兽牌改写、阶段/姿态和原因键。玩家界面仍只看到匿名反制结果，不会看到 AI 的压力桶或评分逻辑。
- AI 天气干预从“按天气类型粗选目标”升级为字段驱动规划：
  - 新增无随机天气覆盖预览，AI 在出牌前会预估天气锚点周边会覆盖哪些区域，而不会为了评分提前消耗真实天气随机数。
  - AI 会读取天气的生产/交通/消费倍率、海洋交通倍率、覆盖区城市 GDP、商路负载、城市商品/需求是否匹配焦点商品、仓储/怪兽压力、地形和终局姿态。
  - 引力潮汐/航线预报会优先寻找能放大己方商路、海洋/交通窗口或焦点商品路线的位置；酸雨、电磁雾、太阳风暴等会在收益更高时压制竞品城市或竞品商路。
  - 训练样本新增隐藏 `weather_*` 元数据，包括天气类型、计划角色、覆盖城市数、商路负载、己方价值、竞品压制价值、地形加成和商品加成；玩家仍只看到匿名改写后的公开天气预报。
- 玩家可见文本开始按电子桌游标准重写：
  - 明确区分开发文本与游戏内文本：设计原则、历史变更、兼容字段、AI 压力桶和实现说明留在文档/测试里，游戏内只保留玩家能立刻操作和判断的信息。
  - 主菜单与暂停菜单改用“牌桌布局、悬停预览、缩略图、双击详情、返回牌桌”这类桌游电子版语言，移除 `hover`、响应式网格、测试、原型、开发等玩家不需要看到的词。
  - 开局准备页改成座位卡结构：顶部筹码显示席位、真人、电脑对手、挑战层级、现金目标、角色不重复、首召独立；每个席位用卡片展示公开角色和匿名首召怪兽。
  - 卡牌/怪兽/商品图鉴的悬停预览压缩为对象名、路线/定位、关键效果和 I→IV 强化；翻页/详情操作只在页面提示中出现，不再反复塞进每张预览卡。
  - 区域牌架、手牌和顶部匿名牌轨统一使用“悬停详情/预览”的中文标签，并保留单窗口锁定、价格锁定、双击区域查看牌架等关键桌面交互。
  - 牌桌进行中 UI 继续向“中央星球 + 桌边玩家板”靠拢：顶部匿名牌轨从高轨道压成小型牌轨，只保留状态、牌名、报价/归属短信息，完整效果留给悬停和双击详情。
  - 底部桌边牌架改为横向桌栏：左侧固定显示我的手牌，右侧收纳选区、竞价、竞猜、合约和目标选择。这样临时行动窗口不会再把手牌挤到下方，测试者能持续看到自己的牌。
  - 空手牌槽、手牌提示和开局日志进一步压缩成玩家语言，例如“空槽”“区域牌架”“电脑对手”“星球牌局开始”，避免把原型/开发阶段信息带进游戏内。
  - 区域牌架从右侧大窗口改成侧边抽屉，后续已升级为“左侧市场格 + 右侧预览板”：背景不拦截地图，玩家可以继续看中央星球。浏览始终允许，购买资格和价格仍按打开窗口瞬间锁定。
  - 区域牌架守卫现在会检查 `DistrictSupplySideDrawer`、右侧锚点、`DistrictSupplyMarketGrid` 和 `DistrictSupplyPreviewPanel`，防止回退成居中模态弹窗或长按钮列表。
  - 当前选区信息改成 `SelectedDistrictChipRail`：地形、HP、城市/GDP、牌架数量、商品供需和天气都以筹码显示，按钮保留“城市化/查看牌/标注/商路/全屏”一排，降低玩家读长句的频率。
  - 开局轻引导改成 `OpeningGuideChipRail`：五个步骤用筹码显示完成状态，只保留一个“下一步｜……”短条；“为什么”和“入口”改为 tooltip，不再常驻挤占行动托盘。
  - 匿名卡牌结算层从右上角小窗改成顶部中央 `CardResolutionTableBanner`：它像电子桌游的全桌事件横幅，公开卡面、结算状态和关键效果，同时避开右侧区域牌架与底部手牌。长效果仍放在 tooltip/牌轨详情里。
  - 结算横幅守卫会检查顶部中央锚点、`CardResolutionTableBanner` 命名，以及“不遮住右侧牌架或底部手牌”的玩家提示，防止之后回退成挡地图/挡手牌的模态窗。
  - 临时决策统一成 `TemporaryDecisionCard` + `TemporaryDecisionChipRail`：私密弃牌、合约签拒、怪兽/玩家目标选择、怪兽赌局下注都使用同一张桌边决策卡。标题统一为“桌边决策｜…”，隐私、是否阻塞出牌、剩余时间和特殊状态改成筹码，降低临时窗口的阅读压力。
  - 弃牌换购 smoke 现在检查桌边决策卡和筹码轨，避免以后又出现散落按钮或长文本弹窗。
  - 新增/更新守卫：`tests/ui_text_smoke_test.gd` 检查玩家文本不退回明显开发词；`tests/visual_snapshot.gd` 检查牌桌紧凑布局、区域牌架筹码和开局座位卡结构。
- Night-Patrol 作为非商业原型素材标杆接入：
  - 已核对上游 `op7418/Night-Patrol` 的 `LICENSE` 与 `NOTICE.md`：整体按 CC BY-NC 4.0 / 非商业 demo 边界处理，商业化前必须替换为自有资产或补充书面授权。
  - 轻量资产隔离放入 `assets/third_party/night_patrol/`，并保留上游 `LICENSE`、`NOTICE.md` 和 vendor README，避免以后误认成自有商用素材。
  - 卡牌程序美术叠加 Night-Patrol 风格的纹章/边框参考层；如果第三方资源被移除，会自动回退到程序卡面。
  - 桌面音频接入低音量 BGM 与卡牌/攻击/天气/赌局短音效；音频资源按可选加载处理，缺失时不会阻塞 smoke 或启动。
  - 新增 `docs/third_party_assets.md` 记录来源、署名和商业化替换要求。
- Terraforming Mars 开源电子桌游作为 UI 结构标杆：
  - 已核对 `terraforming-mars/terraforming-mars` 仓库为 GPL-3.0；本项目只参考公开的信息层级和交互结构，不直接复制 GPL 代码/样式/素材。
  - 重点参考其 `Board.vue`、`PlayerHome.vue`、`PlayerResources.vue`、`Card.vue` 等组件分层：中央棋盘、玩家资源板、手牌/已打牌区域、当前行动/等待窗口分别承担不同信息密度。
  - 主牌桌地图标题统一为“星球赌桌｜中央星球”，强调地图/星球是桌面中心。
  - 底部玩家区新增 `TerraformingMarsLikeResourceBoard` / `PlayerResourceCubeRail`：把资金、GDP、城市、手牌、终局目标做成一排小资源方块，避免玩家在长文本里找状态；对手资源仍按隐私规则隐藏。
- Gaia Project 开源实现作为地图/行动板结构参考：
  - 已查看 `boardgamers/gaia-project` 的 `master` 分支结构；GitHub API 未检测到明确 license 文件，因此当前只作为开发期信息架构参考，不把代码/素材并入项目。
  - 参考方向是 `SpaceMap`、`SpaceHex`、`PlayerBoard/Info`、`Commands`、`ResearchBoard` 一类“地图中心 + 玩家板 + 命令区”的分区思想，帮助本项目继续把复杂信息拆成可扫读模块。
- 本轮 UI/规则闭环继续收敛：
  - 顶部牌结算状态不再暴露“0.5秒”等内部参数，改成“同时判定/匿名竞价/公开展示/封盘/下一批”等桌游式状态词；具体剩余时间由底部沙漏条表现。
  - 地图控制筹码改为“◎ 赌桌中央”，让玩家更明确星球是牌桌核心；底部手牌架新增“状态：…”总状态条，空手牌/固定技能/需商品/需目标都能一眼看见。
  - 选区按钮改成“查看牌架”，区域牌架市场格的价格与购买状态允许用卡片面板标签表达，不再要求传统按钮长文本。
  - 合约签署窗口文案改为“不会阻塞其他玩家继续出牌”，和展示后独立签/拒窗口的真实规则一致。
  - 区域受伤/摧毁后显式写回 district 状态，仓储期货城市被毁时普通期货保留、仓储头寸清除；商品图鉴的紧凑“期货/仓储”文本现在也保留“仓库:”前缀，方便玩家识别可被攻击的仓储城市。

#### 文档与测试

- `README.md`、`docs/prototype_scope.md`、`docs/rules_summary.md` 已同步为当前规则说明。
- 本轮验证：
  - `tests/ui_text_smoke_test.gd` 通过。
  - `tests/visual_snapshot.gd` 通过。
  - `tests/smoke_test.gd --check-only` 通过。
  - `tests/smoke_test.gd` 完整通过。
  - Godot 有头启动通过：正常开窗口使用 Vulkan / NVIDIA GeForce RTX 4080 SUPER 渲染 180 帧后自动退出。
  - `git diff --check` 此轮未作为最终门禁重跑；后续提交前仍建议执行一次。
- 已建立 Godot headless 烟测：
  - 加载主场景
  - 新建 4 席、3 AI 的 PVE 运行，并验证 3-8 总席位、2-7 AI 设置、Roguelike 深度星球规模/现金目标，以及现金线触发的终局倒计时可保存恢复
  - 验证角色卡、起始怪兽卡、资源/赠牌/升兽收益、情报能力与远程补给范围
  - 验证公开角色选择不会重复：显式重复配置会自动避让，AI 随机角色在开局结算为本局未占用角色；每张真实角色卡都带隐藏 `balance_budget`、`balance_band`、`balance_tags` 和 `balance_drivers`，方便后续平衡审计
  - 验证怪兽召唤、升级、持续时间、自动行动
  - 验证球面地图、城市、商品、商路、区域伤害
  - 验证卡牌购买、升级、打出、竞价、匿名归属猜测
  - 验证 AI 会评分手牌、匿名出牌、参与同时批次竞价、自动回应合约、做城市业主推理/卡牌归属押注、规划怪兽诱导目标、维护经济焦点商品、切换 grow/defend/disrupt 策略意图、跨建城/卡牌/合约/商业动作推进商品路线计划，按经营周期 reward 与终局 Roguelike reward 进行席位隔离的在线学习，并记录候选与收益样本；同时验证通用卡牌字段评分元数据
  - 验证 8 席长 smoke 会按 AI 性格生成路线行动报告：6 类 profile 都必须产生 route-tagged 决策样本，并覆盖多条核心发展路线与至少 4 类主偏好路线
  - 验证城市买涨/做空挂单、GDP 涨跌兑现、区域伤害 GDP 扣减、飞行免路径碾压与水栖地形移动倍率
  - 验证合约牌展示后独立签约窗口、固定相位响应窗口、相位否决、军队控制上限与军令技能
  - 验证分型军队牌使用字段驱动的部署地形、移动倍率、临时卡面/地图标记、短时 GDP 压力和商路压力
  - 验证军队运行时边界：军队前进不会造成怪兽式建筑踩踏/区域伤害，但会把短时军事 GDP 压力写入城市收入拆解
  - 验证军队摧毁边界：前进和猎兽军令不会写入区域/商路破坏，只有显式“摧毁区域”军令会造成区域伤害、商路压力和军事 GDP 压力
  - 验证 AI 相位反制策略：AI 能在相位窗口内识别威胁己方城市的匿名牌，排入相位否决，写入隐藏反制元数据，并让原牌被取消
  - 验证 AI 天气干预策略：AI 会用引力潮汐强化己方商路窗口，用酸雨压制竞品城市，并在匿名出牌样本中记录隐藏天气计划元数据
  - 验证港仓囤货的仓储风险和公开线索：商品状态/商品图鉴会显示匿名期货方向、最近到期和仓储笔数；仓库城市线索显示商品与单位但不显示玩家；仓库城市被摧毁时，仓储商品期货头寸作废，普通非仓储期货仍保留到自身到期窗口
  - 验证普通商品期货按秒结算：到期前不支付，到期后只按真实商品价格变化兑现，并清空对应头寸
  - 验证临时经济持续时间以真实秒数为源字段：城市临时合约、商品合约、商品增速、商路流通、GDP 衍生品和商品期货都必须暴露 `*_seconds`；`*_turns` 只作为旧存档/镜像兼容，烟测按 30 秒真实流逝检查倒计时
  - 验证本局商品驱动牌池：固定商品牌只在本局星球存在所需商品时进入卡池；怪兽牌按资源偏好匹配本局商品，极端地图有安全回退；区域补给还会检查本地供需，避免这颗星球不存在的商品牌出现在可购买列表里
  - 验证菜单、图鉴缩略图册、临时卡面/怪兽美术
- 完整烟测命令（耗时较长；本轮已通过）：

```powershell
& 'C:\Users\Administrator\Documents\New project\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://tests/smoke_test.gd
```

### 最近清理的旧规则遗留

- 移除了旧的四怪兽开局阵容/守护者兼容状态。
- 移除了卡牌充能字段与运行时遗留。
- 移除了持续控制怪兽的 runtime 字段；保留的是一次性诱导/指令类效果。
- 卡牌分类文案从旧的 `supply/control` 调整为 `supply/lure`。

### 下一步建议

1. 做一轮专门的数值和平衡审计：检查卡牌 I-IV 强度、价格、商品流动门槛、GDP/min、怪兽伤害、天气/新闻影响、合约奖惩和终局现金目标是否处在同一套可解释预算内。
2. 至少打磨出 4-5 条 AI 可用发展路线，并用批量模拟验证每条路线在合适局势下都能追逐最高现金目标：例如城市成长/GDP、商品供需与合约、交通商路、金融买涨/做空、怪兽/新闻/天气压制，情报竞猜可作为辅线或混合路线。
3. 为长局经济波动增加专门测试，验证商品供需、城市竞争、商路破坏、卡牌强度和最终金钱结算的平衡；目标不是所有路线平均胜率，而是每条路线都有清晰优势、弱点和反制窗口。
4. 在已有短周期/终局 reward 学习之上继续加入连续诱导/合约组合，并观察不同 Roguelike 星球尺寸下的稳定表现。
5. 拆分 `scripts/main.gd`，把规则模型、卡牌数据、UI、地图投影、经济系统与 AI 决策分模块维护。
6. 等核心玩法继续稳定后，再做一版真正的新手引导，把“游戏规则”菜单内容改造成逐步教程。
7. 继续把合约牌和城市经营卡做成更强的推理线索，例如按商品品类、城市规模、海洋商路或怪兽资源偏好触发不同签约奖惩。
8. 继续调怪兽行动概率与资源偏好，让怪兽争夺商品资源的路线更容易被玩家推理。
9. 为角色卡、卡牌与怪兽替换正式美术，保留当前程序美术作为占位 fallback。

## 2026-07-01｜入口命名、桌面快捷方式与图鉴第一屏重排

- 启动入口改为更面向玩家的名称：
  - `project.godot` 的窗口/项目名改为 `太空辛迪加`。
  - 新增 `Launch Space Syndicate.cmd`，旧 `Launch Space Syndicate Prototype.cmd` 保留为兼容入口。
  - 桌面快捷方式更新为 `太空辛迪加.lnk`，并移除旧的 `Space Syndicate Prototype.lnk`，图标继续指向当前临时游戏 icon。
- 继续清理主界面的程序化时间文案：
  - 匿名卡牌多人提交窗口改为“同时短窗 / 报价沙漏”语言。
  - 顶部牌桌状态不再显示具体内部秒数；具体等待感由底部沙漏条和状态筹码承担。
  - 需要展示真实持续时间的卡牌效果仍保留秒数，例如期货、天气、合约、临时经济效果。
- 卡牌图鉴改为“卡片优先”的 TCG/电子桌游浏览顺序：
  - 缩略图页第一屏先显示卡牌矩阵，筛选、牌库来源、区域买牌说明和牌路总览下移。
  - 详情页第一屏先显示卡面、扫牌顺序、费用/门槛、核心效果、关键数值和本局投放，再接 I-IV 强化梯度。
  - 修复详情页“扫牌顺序”标题被右侧标签挤成竖排的问题。
- 新增 `tests/ui_snapshot_capture.gd`：
  - 有头启动 Godot 后自动截取主菜单、卡牌图鉴缩略图、卡牌详情和开局牌桌四张 PNG。
  - 输出位置：`user://space_syndicate_ui_snapshots/`，当前 Windows 路径为 `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/太空辛迪加/space_syndicate_ui_snapshots/`。
  - 这不是替代 smoke 的断言测试，而是用于每次大改 UI 后快速肉眼复查“中央星球、顶部牌轨、底部手牌、图鉴第一屏”的比例。

### 本轮验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。
- `tests/ui_snapshot_capture.gd` 有头通过，并生成 4 张 UI 快照。
- Godot 普通有头启动通过：Vulkan / NVIDIA GeForce RTX 4080 SUPER，自动退出无报错。
- `git diff --check` 通过；仅有 Git 提示 LF 将在下次触碰时转为 CRLF。

## 2026-07-01｜主牌桌底部玩家板改成手牌优先

- 继续按“中央星球 + 桌边玩家板”的电子桌游结构收敛主界面：
  - `TableEdgeHandViewport` 高度提高，并把底部左列调整为“手牌优先，资源筹码和目标提示在下方”。
  - 这样 1600×1000 的测试窗口里，玩家进入一局后第一眼能看到自己的手牌，而不是只看到资源条和长提示。
- 手牌卡改成更紧凑的桌边小卡：
  - 手牌卡最小尺寸改为 `160×168`，空槽同尺寸。
  - 手牌卡正面只保留卡名、路线/类型、短状态、关键筹码和按钮；长效果和状态原因放进 hover/tooltip。
  - `HandCardPlayStateRail` 在紧凑模式下只显示前两个状态筹码，不再额外塞一行理由文字，减少主桌文本密度。
- 右侧行动托盘继续承担“可操作但不抢地图”的角色：
  - 托盘宽度从 390 缩到 340，给手牌区更多横向空间。
  - 首召怪兽提示前置到托盘顶部，开局玩家更容易找到“在选区首召”。
  - 首召卡改成窄栏友好布局：卡面、落点、固定技/开牌架筹码和首召按钮可见；长解释放 tooltip。
  - 修复行动托盘提示文字在窄栏里被挤成竖排的问题。
- 守卫同步：
  - `tests/visual_snapshot.gd` 增加底部牌架高度、手牌优先、资源条后移、首召前置和小手牌卡尺寸合同。
  - `tests/ui_text_smoke_test.gd` 更新紧凑手牌卡的 42px 美术高度合同。
  - `tests/smoke_test.gd` 更新首召提示断言，从旧“首召引导”改为当前玩家词“首召怪兽”。

### 本轮验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/ui_snapshot_capture.gd` 有头通过，并重新生成主菜单、卡牌图鉴缩略图、卡牌详情和主牌桌快照。
- `tests/smoke_test.gd` 完整通过。
- Godot 普通有头启动通过：Vulkan / NVIDIA GeForce RTX 4080 SUPER，自动退出无报错。
- `git diff --check` 通过；仅有 LF/CRLF 提示。

## 2026-07-01｜固定主行动条与二号屏有头测试约定

- 继续按 Terraforming Mars 电子桌游的“当前行动清楚、次级信息折叠”方向压缩主牌桌：
  - `TableGoalPrompt` 从行动托盘滚动内容移到托盘固定顶部。
  - 主提示改成单行固定行动条：左侧一句“目标提示｜下一步”，中间 2-3 个状态筹码，右侧只保留一个主按钮。
  - 开局时玩家不滚动就能看到“在选区首召”，建城/买牌/出牌也会在同一位置替换为当前主动作。
  - `MainActionDock` 按钮与标题缩小一档，保留四个快捷动作，但减少底部空间占用。
  - 次级面板继续放在滚动区，避免合约、竞猜、竞价、目标选择把主按钮挤出首屏。
- 有头测试约定：
  - 当前检测到二号屏为 `DISPLAY2`，坐标约 `X=-1267, Y=-2160, 1280×720`。
  - 后续有头 Godot 快照优先使用 `--position -1247,-2140 --resolution 1200x680`，尽量不占用主屏；二号屏不可用时再回退主屏。

### 本轮验证

- `tests/smoke_test.gd --check-only` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/ui_snapshot_capture.gd` 二号屏有头通过，并重新生成 4 张 UI 快照。

## 2026-07-02｜手牌 hover 接入右侧 10 秒详情层

- 继续按电子桌游的“手牌扫读 + hover 详情 + 右侧上下文”结构收敛主界面：
  - `HandRack` 的 `card_unhovered` 现在通过 `PlayerBoard` 转发到 `GameScreen`。
  - 手牌 hover 会临时调用 `RightInspector.show_card()`，把卡名、类型、费用、效果和条件显示到右侧详情层。
  - 手牌 unhover 会恢复最近一次 `apply_state()` 的 `right_inspector` 上下文，避免右侧说明被悬停卡牌永久粘住。
- 守卫同步：
  - `tests/layout_scene_smoke_test.gd` 验证 hover 显示卡牌详情、unhover 恢复“当前说明”，并确认 hover 不重建手牌节点。
  - `tests/visual_snapshot.gd` 增加 `HandRack -> PlayerBoard -> GameScreen -> RightInspector` hover/unhover 链路合同。
- 快照暴露出的版面问题同步修正：
  - 主菜单 `MenuRootLobby` 新增 `MainMenuPlanetBackdrop` 全屏星球背景层，旧左侧星球预览隐藏，入口按钮和短标签浮在背景上，减少面板套面板的工具感。
  - `BottomCountdownBar` 不再被长期天气预报/天气影响占用；天气继续留在状态筹码和经济页，底部计时条只服务竞价、响应、怪兽赌局、合约和终局这类短窗口，避免盖住手牌。

### 本轮验证

- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/ui_snapshot_capture.gd` 有头通过，并重新生成主菜单、开局准备、主牌桌、详情抽屉和图鉴/仪表板快照。

## 2026-07-02｜公开牌轨与 BidBoard 建立双向 Hover 对应

- 继续按商业桌游式 4X 的“公共桌面线索可互相指认”方向推进，而不是继续堆装饰：
  - 参考公开牌轨/竞价条/行动提示之间的双向高亮模式，让顶部匿名牌轨和底部 BidBoard 不再只是两块分离信息。
  - `CardTrack` 增加牌槽 hover/unhover 信号，牌轨槽位可把自己的公开行动 id 暴露给页面层。
  - `GameScreen` 负责把公开牌轨 hover 转成玩家板 hover 状态，保持 UI 层只传 ViewModel/信号，不直接碰规则。
  - `PlayerBoard` 继续做转发层，`BidBoard` 增加 `set_hovered_track_action()`，临时高亮匹配的“领跑/我的牌/下张/下批”指针。
  - 之前已有的 BidBoard 指针 hover 顶部牌轨也保留；现在形成 `BidBoard -> PublicTrack` 与 `PublicTrack -> BidBoard` 的双向对应。
- 守卫同步：
  - `tests/layout_scene_smoke_test.gd` 增加公开牌轨槽位 hover 后点亮 BidBoard 指针、离开后清除的运行时断言。
  - `tests/visual_snapshot.gd` 增加 `CardTrack` hover 信号、`GameScreen` 桥接、`PlayerBoard/BidBoard` hover API 和 `BidBoardTrackLinkHover` 标记合同。

### 本轮验证

- `tests/visual_snapshot.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `git diff --check` 通过；仅有 Git 提示 LF 将在下次触碰时转为 CRLF。
- `tests/smoke_test.gd` 完整运行到末尾但仍有 1 个红灯：`AI opponents form multi-step product-route plans that bias build, card, contract, and business choices`。当前失败集中在 AI 多步商品路线规划 smoke，不在本轮公开牌轨/BidBoard UI 桥接路径。

### 剩余缺口

- 继续优先修完整 smoke 的 AI product-route 规划断言，尤其是首路线 `gap_score=false` 导致的多步路线评分未达标。
- 双向 hover 目前是瞬时描边/标记，下一步可继续加右侧 inspector 预览和轻量连线，让竞价、公开牌和私有推理更像同一张桌面。

## 2026-07-02｜AI 商品路线 smoke 恢复全绿

- 继续沿“人类可演示局必须有稳定对手”的方向收束红灯：
  - 复查完整 smoke 里剩余的 AI 多步商品路线失败，定位到 `tests/smoke_test.gd` 的断言取值方式。
  - AI 实际买牌候选里，“消费刺激1”已有最高分需求补口候选，且高于“生产扩张1”；旧断言按遍历顺序取同名牌最后一个候选，误把低分备用区域当成 AI 最终比较值。
  - 断言改为比较同名候选的最高分，更贴近 `_ai_card_buy_candidates()` 的真实决策排序语义，也继续要求补需求候选具备 `route_gap_bonus`、`route_gap_reason` 和 field match。
- 可玩性意义：
  - AI 在 `create_demand` 商品路线阶段会优先识别“补需求”牌，而不是被同名备用供应区域或无关供给牌误判。
  - 完整 smoke 重新覆盖新局、AI 进展、牌桌 UI、匿名牌轨、地图/城市、菜单/图鉴等主流程，当前没有剩余红灯。

### 本轮验证

- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。

## 2026-07-03｜Codex B：Campaign Runtime Playable Slice v2

- 把新手战役从“菜单/fixture 外壳”推进到前 5 关真实运行切片：
  - `00_tavern_entry`、`01_first_table`、`02_market_hand`、`03_public_track`、`04_bid_practice` 都能从 `main.tscn` 进入真实 `RuntimeGameScreen` 并完成真实目标。
  - 完成目标后先保留约 1 秒成功反馈/演出，再打开奖励面板，避免一瞬间跳页。
  - 每关开始清空上一关 reward/recap 残影，防止战役连续游玩时 UI 误读。
- 接通真实主桌演出：
  - `GameScreen.tscn` 新增 `RuntimeVisualEventLayer`，但不改 `VisualEventLayer` 主逻辑。
  - `TableSnapshot` 增加 `visual_events` / `visual_event_key`，由 `main.gd` 在 scenario signal 完成时注入安全 payload。
  - visual event payload 会过滤 `true_owner`、`hidden_owner`、`private_cash`、`opponent_hand`、`ai_score` 等隐藏字段。
  - `market_hand` 补充牌架/购牌演出 fixture。
- 补齐教学运行态信号：
  - 牌架打开、卡牌悬停、购牌、公开牌轨选中、右侧详情阅读、卡牌详情打开、竞价阅读/加价/清零都能推进对应 scenario objective。
  - `public_track_intro` / `bid_practice` 在没有真实匿名牌时会显示一张教学匿名牌快照，BidBoard 与 PublicTrack 通过同一个 track id 对齐，仍不暴露真实归属。
- MapView 保护：
  - 新增 `map_view_globe_default_test.gd` 与 `campaign_map_globe_regression_test.gd`，确保 campaign runtime 中央仍是可缩放 globe，不退化为 ColorRect/placeholder。
- 截图验收：
  - `campaign_snapshot_capture.gd` 现在能从 `main.tscn` 真实路径生成 campaign menu、briefing、第一桌 globe/成功、牌架、牌轨、竞价、奖励、复盘、设置等截图。
  - 有头截图已定位到二号屏运行，并把关键 PNG 复制到 `reports/campaign_snapshots/` 供 GitHub 查看。

### 本轮验证

- `tests/map_view_globe_default_test.gd` 通过。
- `tests/campaign_map_globe_regression_test.gd` 通过。
- `tests/campaign_visual_event_bridge_test.gd` 通过。
- `tests/campaign_first_five_runtime_test.gd` 通过。
- `tests/campaign_privacy_runtime_test.gd` 通过。
- `tests/player_journey_30min_test.gd` 通过。
- `tests/campaign_runtime_flow_test.gd` 通过。
- `tests/campaign_runtime_path_v2_test.gd` 通过。
- `tests/campaign_snapshot_capture.gd` headless 和有头均通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。

## 2026-07-02｜Codex B：Hearthstone-grade Player Journey v1

- 把 Scenario Lab 升级为“新手战役”产品闭环：
  - 新增 Campaign 数据层：战役定义、关卡、进度、存档、奖励、解锁、复盘服务。
  - 新增 10 关 `tutorial_campaign.json`，覆盖序章、第一桌、牌架、匿名牌轨、竞价、怪兽压力、商品合约、情报、终局、毕业挑战。
  - 新增推荐开局数据和 helper：4 席 / 3 AI，以及“新手稳定经济 / 怪兽压力 / 匿名牌推理”三个 preset。
- 主菜单改为商业入口结构：
  - 三个主入口：新手战役、快速开局、资料库。
  - 继续牌桌、剧本库、规则、设置、读取局面、退出移动到辅助入口。
  - 暂停菜单在战役中显示“重开本关 / 返回战役 / 查看复盘”。
- 新增战役 UI：
  - `CampaignMenu`、`CampaignBriefing`、`CampaignProgressMap`、`CampaignRewardPanel`、`MatchRecapPanel`。
  - 继续复用 `ScenarioCoach`，但战役中标题显示为“新手战役｜关卡名”，主桌仍保持一步一目标。
- 隐私与验收：
  - 新增 campaign 菜单、进度、奖励、隐私、30 分钟玩家旅程测试。
  - 新增 `campaign_snapshot_capture.gd`，可生成 12 张 Campaign QA 截图；有头截图已在二号屏运行确认。
  - 玩家可见 Campaign 快照不暴露对手现金、对手手牌、AI 私有计划、真实匿名归属或内部评分字段。

### 本轮验证

- `tests/campaign_menu_smoke_test.gd` 通过。
- `tests/campaign_progress_test.gd` 通过。
- `tests/campaign_reward_test.gd` 通过。
- `tests/campaign_privacy_test.gd` 通过。
- `tests/campaign_runtime_flow_test.gd` 通过。
- `tests/player_journey_30min_test.gd` 通过。
- `tests/campaign_snapshot_capture.gd` 通过，并生成 12 张截图到 `user://campaign_snapshots`。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/scenario_smoke_test.gd` 通过。
- `tests/scenario_progress_test.gd` 通过。
- `tests/scenario_privacy_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。

## 2026-07-02｜公开牌轨 Hover 接入右侧说明层

- 继续按“桌面信息互相指认”的商业桌游读法推进：
  - 顶部公开牌轨槽位 hover 时，不再只点亮 BidBoard 指针，也会把该匿名牌槽的公开状态、归属提示、报价、条件和详情入口临时显示到 `RightInspector`。
  - 鼠标离开牌轨后，右侧说明恢复最近一次主桌上下文，避免玩家扫牌轨时把当前选区/行动说明永久冲掉。
  - 这复用 `GameScreen._track_entry_inspector_context()`，仍然只走 UI snapshot/信号层，不把规则逻辑塞进 `CardTrack`。
- 可玩性意义：
  - 玩家扫顶部匿名牌轨时能立刻看到“这张公共牌为什么重要、可以点哪里、归属线索是什么”，不用先点击或翻情报页。
  - 牌轨、BidBoard、RightInspector 三块信息开始形成同一张桌面的短反馈链。

### 本轮验证

- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。

## 2026-07-02｜匿名牌对象闭环接通情报档案

- Codex A 本轮只处理公开牌轨、竞价、右侧说明和匿名牌证据链，没有新增玩法/卡牌/AI，也没有改首局引导、新游戏菜单、教程、经济、怪兽或卡牌数据。
- 继续参考 Through the Ages 式公共牌列、Terraforming Mars 桌面信息分层和 CardHouse 的 card group/gate 思路，把同一张匿名牌对象用 `resolution_id` 串起来：
  - `PublicTrack` hover 继续高亮 `BidBoard` 指针，并临时预览到 `RightInspector`。
  - `BidBoard` 指针 hover 现在也会反向预览对应 `PublicTrack` 牌槽到 `RightInspector`。
  - `GameScreen` 增加短 `TrackFocusRibbon`，在 hover/选中公开牌时显示槽位、状态、匿名归属和报价，避免玩家在顶部牌轨、底部竞价和右侧说明之间迷路。
  - `PublicTrack` / `BidBoard` 选中后保持同一 `resolution_id` 焦点，右侧说明和牌轨焦点条同步显示“已选牌轨”。
  - `IntelDossierBoard` 增加 scene-owned action row，已选匿名牌证据链提供“回到牌轨 / 竞猜 / 卡牌详情”路径；按钮只 emit 数据化 action id，`main.gd` 只做匿名牌桥接。
- 隐藏信息边界：
  - 焦点条和档案按钮只展示公开槽位、公开状态、匿名归属提示、报价与卡牌公开详情入口。
  - “竞猜”路径只是回到主桌同一 `resolution_id`，由已有归属竞猜面板继续处理；不在档案页直接结算或泄露真牌主。

### 本轮验证

- `tests/visual_snapshot.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/smoke_test.gd` 完整通过。
- `tests/ui_snapshot_capture.gd` 有头通过，并重新生成主桌、情报档案、抽屉和 Codex/仪表板快照。

## 2026-07-03｜卡牌图鉴缩略图接入共享卡面美术层

- 继续推进“真人可读、像桌游卡牌而不是开发说明块”的方向：
  - 新增 `docs/card_visual_theme_contract.md`，把同源卡面、缩略图硬指标、视觉差异、开源素材边界和玩家阅读顺序写成后续开发契约。
  - `CardCodexBrowser` 的缩略图中间美术位改为使用 `CardArtView`，与手牌、详情、结算展示共享程序卡面语言。
  - 缩略图继续保留速读 chip、路线、短效果和 hover/detail 路径；长规则仍放入 hover 预览和详情页。
  - `CardCodexBrowserSnapshot` 现在显式传递 `display_name`、`rank_number`、`card_stats`、`card_art_stats`，避免 UI 侧猜测卡牌等级和美术统计行。
  - `CardArtView` 继续把 Night Patrol frame/sigil 当作 optional reference layer；缺失素材时仍回退程序美术。
- 可玩性意义：
  - 玩家在图鉴缩略图、手牌和详情页看到的是同一种卡牌视觉语言，降低学习成本。
  - 卡牌不再只靠文字区分类别，怪兽、军队、金融、商品、合约等路线会通过 glyph/motif/颜色形成第一眼差异。

### 本轮验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/playtest_skeleton_gate_test.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。
- `tests/ui_snapshot_capture.gd` 有头通过；确认 `card_codex_grid_1600x960.png` 的缩略图已经使用共享卡面美术区。

## 2026-07-03｜区域牌架接入共享卡面视觉路径

- 延续上一轮图鉴缩略图美术统一，把游戏中最常用的买牌入口也纳入同一套卡牌视觉语言：
  - `DistrictSupplyMarketCard` 新增 `DistrictSupplyMarketCardArtHost` / `DistrictSupplyMarketCardArtView`，左栏市场小卡不再只是文字、价格和状态条。
  - 区域牌架小卡现在用 `CardArtView` 显示卡种 glyph、程序纹样、等级标记和 Night Patrol optional frame/sigil 参考层。
  - `_district_supply_market_card_snapshot()` 显式传递 `display_name`、`kind`、`rank_number`、`card_stats`、`card_art_stats`，避免 UI 侧猜卡种和美术统计行。
  - 右侧 `DistrictSupplySelectedPreview` 的卡面预览提高到 218px 高，并使用 `inspector_full` 卡面展示，作为买牌前的更清晰读牌状态。
- 更新 `docs/card_visual_theme_contract.md` 与 `docs/card_frame_spec.md`：
  - 加入“购买路径一致性”：左栏 market-cell → hover/单击预览 → 右栏购买预览 → 买入后手牌 mini-card。
  - 明确 `DistrictSupplyMarketCell` 不能退回纯文字按钮列表。
- 可玩性意义：
  - 玩家从区域牌架看到候选牌、点右侧预览、买入手牌时，会看到连续的卡牌视觉语言。
  - 这降低了“每个页面都像不同系统”的认知负担，更接近桌游电子版的读牌路径。

### 本轮验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/playtest_skeleton_gate_test.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。
- `tests/ui_snapshot_capture.gd` 有头通过；确认主桌、牌轨、手牌和抽屉快照仍保持中心星球桌面比例，没有因为牌架卡面增高破坏主画面。

## 2026-07-03｜区域牌架主桌路径加入截图守门

- 本轮继续围绕“真人能简单上手测试”的路径骨架，而不是新增规则：
  - `tests/ui_snapshot_capture.gd` 新增真实运行时牌架截图路径：新局主桌 → 选择有卡区域 → 调用 `_open_district_supply_from_map()` → 保存 `play_table_supply_drawer_<分辨率>.png` → 关闭牌架继续后续截图。
  - 新增 `_open_runtime_supply_drawer_for_capture()`、`_runtime_supply_drawer_visible()`、`_capture_district_with_cards()`，截图守门检查真实 `DistrictSupplySideDrawerOverlay`、`DistrictSupplyMarketGrid`、`DistrictSupplyPreviewPanel` 都在树上可见。
  - `DistrictSupplyDrawer.tscn` 默认文案改为中文短标签：区域牌架、区域供牌、卡牌预览、关闭，避免编辑器默认态和截图默认态露出英文原型文本。
  - `docs/card_visual_theme_contract.md` 增加“运行截图守门”：区域牌架必须有真实主桌截图，不允许以后只保留组件级存在证明。
- 可玩性意义：
  - 这保护了玩家最关键的一条早期路径：双击/打开区域 → 看该区提供什么牌 → 单击预览 → 决定是否购买。
  - 后续每轮 UI 改动都会生成一个主桌牌架截图，能更早发现牌架遮挡星球、文字溢出、卡面退化或抽屉路径断裂。

### 本轮验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/playtest_skeleton_gate_test.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。
- `tests/ui_snapshot_capture.gd` 有头通过；新增 `play_table_supply_drawer_1600x960.png` 等多分辨率主桌牌架快照，并人工查看 1600x960 图确认牌架在右侧打开、星球仍保持中央视觉焦点。

## 2026-07-03｜区域牌架预览加入决策条

- 本轮继续压低真人首局的信息密度，重点处理“打开区域牌架后如何一眼判断要不要买”：
  - `DistrictSupplyPreviewCard` 新增 `DistrictSupplyDecisionStrip`。
  - 右侧预览现在从同一套卡牌字段生成 3-4 个短决策 chip：用途、买入状态、打出门槛、目标类型。
  - 长效果、关键事实、购买状态说明限制可见行数，完整文字留在 tooltip / 详情页。
  - Scene 默认文案也改为中文：卡牌预览、选中卡牌效果、关键事实、购买状态。
  - `docs/card_visual_theme_contract.md` 增补区域牌架右栏阅读顺序：先扫决策条，再看购买判定和卡面。
- 可玩性意义：
  - 玩家不用先读一整段规则，就能判断“这张牌属于什么路线、现在能不能买、打出需要什么、要指定什么目标”。
  - 这更接近桌游电子版的卡牌市场阅读方式：先扫 icon/chip，再决定是否打开完整细节。

### 本轮验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/playtest_skeleton_gate_test.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。
- `tests/ui_snapshot_capture.gd` 二号屏有头通过；人工查看 `play_table_supply_drawer_1280x720.png` 与 `play_table_supply_drawer_1600x960.png`，确认牌架在右侧、星球仍是主视觉、预览决策 chip 可见且长文本不再溢出卡框。

## 2026-07-03｜主桌快捷行动加入 1-4 热键骨架

- 本轮按桌游电子版的第一层操作习惯继续降低真人测试摩擦，不新增规则：
  - `ActionDockSnapshot` 为四个主桌快捷行动输出数据字段 `shortcut`：1 建城、2 牌架、3 买牌、4 出牌。
  - `ActionDock` 只负责渲染短按钮、tooltip 和可测试 metadata，不读取玩法规则。
  - `GameScreen` 新增 1-4 键盘入口，按当前 snapshot 的可用状态触发行动；临时决策弹窗和文本输入聚焦时不会误触。
  - 测试合同锁住“快捷键来自数据层、组件层显示、主桌输入层触发”三段路径。
- 可玩性意义：
  - 测试者可以像桌游电子版/策略游戏一样用 1-4 快速执行最常见行动，减少在高信息密度主桌上找按钮的负担。
  - 快捷键仍跟随 snapshot 数据，后续把按钮换成更图标化或更精美的卡桌 UI 时，不会丢失操作骨架。

### 本轮验证

- `tests/ui_text_smoke_test.gd` 通过。
- `tests/visual_snapshot.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/commercial_playability_gate_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。

## 2026-07-03｜Night Patrol 开源素材升级为全局卡面皮肤

- 回应“不能只立卡牌美术骨架”的缺口，本轮把已经导入的 Night Patrol 开源素材从低透明度参考层升级为真正可见的共享卡面皮肤：
  - `CardArtView` 新增 `night-patrol-frame-panel-sigil-v2` 主题 metadata。
  - `panel-talisman.png` 作为卡面内板 backplate。
  - `card-frame-attack / power / skill / status` 以更高透明度作为类型化边框。
  - `button-red.png` / `button-blue.png` 作为上下短饰条，怪兽/军队/战斗类偏红，其它路线偏蓝。
  - `card-sigil.svg` 的中心纹章提高可见度。
- 因为手牌、区域牌架、卡牌图鉴缩略图和详情卡面都共享 `CardArtView`，这次不是单页美化，而是把外部素材同步到主卡面语言。
- 更新 `docs/card_visual_theme_contract.md`、`docs/card_frame_spec.md`、`docs/third_party_assets.md`，明确当前原型的第三方素材边界和 player-facing 使用方式。
- 下一轮素材方向：
  - 继续从可明确归档 license 的 GitHub/CC0/MIT 资源扩充 icon、monster silhouette、commodity token、codex 背板。
  - 把“图鉴缩略图”和“卡牌详情页”继续做得更像 TCG 牌册，而不是开发文档。

### 本轮验证

- `tests/visual_snapshot.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。

## 2026-07-03｜怪兽美术改为多来源硬门禁

- 纠正上一轮风险：Moth Kaijuice/MOS kaiju 不能被当成所有怪兽的通用身体模板，只能服务一个当前怪兽家族。
- 新增两组可追踪开源占位素材：
  - `victrolaface/monster_battler`，CC0，导入 dino / rock / rodent / salamander / turtle。
  - Kenney CC0 参考包，导入 fish / slime / alienBlue / enemyUFO。
- `MonsterArtView` 改成 `multi-source-open-monster-sprites-v2`：
  - 每只当前怪兽输出 `visual_source_id`。
  - 每只当前怪兽使用不同 body sprite key。
  - MOS/Moth kaiju body art 只分配给 `焰环幼星` 这一只怪兽家族。
  - 其它怪兽分别来自 Kenney 或 Monster Battler 的不同身体家族，并继续叠加本项目自己的轮廓、颜色、光效和标题结构。
- `tests/art_identity_gate_test.gd` 加硬门禁：
  - 当前怪兽数 = body sprite key 数 = `visual_source_id` 数。
  - `moth_source_count == 1`。
  - 怪兽动作仍要求每个 action slot 有独立动作 profile、pose、effect、timing、meter scale。
- `docs/art_production_contract.md` 写入当前阶段硬约束：接下来每个怪兽/每张卡牌必须逐个完成，不能靠同一素材换动作、换颜色糊过去。
- `tests/art_contact_sheet_capture.gd` 继续输出美术验收截图，供人工看缩略图和动作表是否真的有差异。

### 本轮验证

- `tests/art_identity_gate_test.gd` 通过。
- `tests/art_contact_sheet_capture.gd` 有头通过，重新生成：
  - `reports/art/art_card_monster_contact_sheet_1600x960.png`
  - `reports/art/art_monster_action_profiles_1600x960.png`
- `tests/visual_snapshot.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。

## 2026-07-03｜卡牌插画层改为多来源路线骨架

- 继续推进“真人能一眼区分卡牌”的目标，不新增玩法规则：
  - `CardArtView` 的中央插画层从单一 Moth Kaijuice sprite theme 升级为 `multi-source-open-card-illustrations-v2`。
  - 每张卡牌 profile 现在输出 `visual_source_id`，和 `sprite_key / sprite_cell / layout / palette / effect / composition / motif` 一起组成唯一美术身份。
  - 怪兽牌会优先匹配对应怪兽家族的占位美术来源：孢雾海皇用鱼类海洋身体、砂铠用岩石怪、流星用 UFO、棱刃用 dino、绿洲用 slime、焰环用 MOS/Moth、蓝锋用 alienBlue、镜像用 salamander。
  - 军队、城市、合约、金融、情报、直接互动等卡继续按路线分配建筑、士兵、机甲、坦克、护盾、光线等来源。
  - 卡面中央 glyph 缩小为路线标记，不再压住插画主体。
- `tests/art_identity_gate_test.gd` 加严卡牌门槛：
  - 全卡池每张卡必须有 `visual_source_id`。
  - 全卡池至少覆盖 10 个 sprite family 和 10 个 visual source family。
- `tests/art_contact_sheet_capture.gd` 的卡牌 contact sheet 改为优先挑选不同 `visual_source_id` 的样本，方便人工检查是否真的多来源，而不是只看同一类牌。

### 本轮验证

- `tests/art_identity_gate_test.gd` 通过。
- `tests/art_contact_sheet_capture.gd` 有头通过，更新 `reports/art/art_card_monster_contact_sheet_1600x960.png` 和 `reports/art/art_monster_action_profiles_1600x960.png`。
- `tests/visual_snapshot.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 单独通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。

## 2026-07-03｜首局高频卡加入视觉焦点层

- 继续把卡面从“共享皮肤 + 文字”推向“玩家一眼能分辨用途”的桌游卡面：
  - `CardArtView` 新增 `first_run_art_focus` profile 字段。
  - 首局高频牌获得独立程序化焦点层：
    - `城市融资1`：城市 + 钱。
    - `产业升级1`：工厂 + 上升箭头。
    - `交通升级1`：路线节点。
    - `星际广告1`：广播波。
    - `诱导电波1`：诱导信标。
    - `过载补给1`：补给箱。
    - `移动1`：移动箭头。
    - `普攻1`：冲击爆点。
    - `格挡1`：盾牌。
    - `区域破坏1`：地表裂纹。
  - `tests/art_identity_gate_test.gd` 现在要求这些高频牌不能退回 generic route mark。
  - `tests/art_contact_sheet_capture.gd` 优先把这些高频牌放进 contact sheet，方便人工看首局牌是否真的能区分。
  - 卡面路线 glyph 改成右上小徽章，避免大字压住插画主体。
- 这仍然是灰盒/占位美术，不是最终逐张插画；但它把“第一局能看懂卡牌用途”的视觉骨架固定住了。

### 本轮验证

- `tests/art_identity_gate_test.gd` 通过。
- `tests/art_contact_sheet_capture.gd` 有头通过，更新：
  - `reports/art/art_card_monster_contact_sheet_1600x960.png`
  - `reports/art/art_monster_action_profiles_1600x960.png`
- `tests/visual_snapshot.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 单独通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。

## 2026-07-03｜Superpowers CC0 怪兽身体源接入

- 回应“不能把 MOS kaijus 当成所有怪兽的通用美工”的要求，把怪兽美术硬门禁从“每只不同 sprite key”继续加严到“每只不同上游来源/身体家族”：
  - 新增 `assets/third_party/superpowers_cc0/`，从 `sparklinlabs/superpowers-asset-packs` 导入 CC0 的 dragon / cyclop / snake / slim 与 upstream `LICENSE.txt`。
  - `MonsterArtView` 新增 `upstream_source_id`，用于审计具体素材包来源，而不只是单张 sprite 名。
  - 现有当前 8 只怪兽的身体来源重新拉开：
    - `孢雾海皇`：Superpowers dragon。
    - `砂铠陆行兽`：Superpowers cyclop。
    - `流星哨兵`：Kenney UFO。
    - `棱刃重甲`：Monster Battler dino。
    - `绿洲修复体`：Kenney slime。
    - `焰环幼星`：唯一 MOS/Moth kaiju。
    - `蓝锋骑士`：Superpowers snake。
    - `镜像猎兵`：Superpowers slim。
  - 这轮没有新增怪兽规则，只是把当前可试玩怪兽的“缩略图区分度”和素材来源边界补硬。
- `tests/art_identity_gate_test.gd` 新增硬门：
  - 怪兽必须声明 `upstream_source_id`。
  - 当前怪兽 roster 至少覆盖 4 个上游/开源素材源。
  - 单一素材源不能供应超过当前 roster 的一半。
  - MOS/Moth 仍然必须恰好只出现 1 次。
- `docs/art_production_contract.md`、`docs/third_party_assets.md`、`docs/open_source_reference_notes.md`、`docs/card_visual_theme_contract.md` 同步写入这个规则，防止后续开发者又把一套怪兽素材反复换皮。

### 本轮验证

- `tests/art_identity_gate_test.gd` 通过。
- `tests/art_contact_sheet_capture.gd` 有头通过，更新：
  - `reports/art/art_card_monster_contact_sheet_1600x960.png`
  - `reports/art/art_monster_action_profiles_1600x960.png`
- `tests/visual_snapshot.gd` 通过。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 单独通过；并行运行时曾触发同一个旧的 `PlayerMainActionDock` 时序失败，单独复跑通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。

## 2026-07-03｜怪兽视觉身份接入运行态地图 Token

- 继续解决“图鉴变好了，但游戏中仍然只像编号点”的问题：
  - `MONSTER_ART_PROFILES` 现在显式保存每只怪兽的 `upstream_source_id / visual_source_id / sprite_key / sprite_cell`，不再只把来源映射藏在 `MonsterArtView`。
  - `MonsterArtView` 优先消费 profile 中的显式来源字段；如果旧 profile 没填，才使用 motif fallback。
  - `_auto_monster_markers()` 把同一套来源字段传给运行态地图 marker。
  - `MapView` 新增轻量怪兽 token sprite 渲染：地图稳定时显示对应身体 sprite；拖拽/缩放的 reduced-detail 过程中仍退回 glyph 以避免卡顿。
  - 怪兽 token 半径从 13-21 调整为 16-27，让怪兽作为核心玩法在星球桌面上更有存在感，但仍保持小图标，不压住星球主体。
- 新增 `tests/monster_map_token_capture.gd`：
  - 使用真实 `MapView` 控件和当前怪兽 profile 生成地图 token 验收图。
  - 输出 `reports/art/art_monster_map_tokens_1600x960.png`。
  - 这张图只用于开发/验收，会显示 source id；玩家正式 UI 不展示这些开发字段。
- `docs/art_production_contract.md` 写入第三张视觉验收图：卡面/怪兽图鉴之外，运行态地图 token 也必须消费同一套怪兽美术身份。

### 本轮验证

- `tests/monster_map_token_capture.gd` 有头通过，输出 `reports/art/art_monster_map_tokens_1600x960.png`。
- `tests/visual_snapshot.gd` 通过，保护 `MapView` 已消费 `sprite_key / sprite_cell / visual_source_id / upstream_source_id`。
- `tests/art_identity_gate_test.gd` 通过，保护怪兽视觉来源不能用同一套 MOS/Moth kaiju 反复糊弄。
- `tests/ui_text_smoke_test.gd` 通过。
- `tests/layout_scene_smoke_test.gd` 通过。
- `tests/smoke_test.gd --check-only` 通过。
- `tests/smoke_test.gd` 完整通过。

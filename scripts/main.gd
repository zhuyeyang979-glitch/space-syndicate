extends Control

const MonsterArtViewScript := preload("res://scripts/monster_art_view.gd")
const RuntimeBalanceModelScript := preload("res://scripts/balance/runtime_balance_model.gd")
const CardPlayRequirementPolicyScript := preload("res://scripts/cards/card_play_requirement_policy.gd")
const SharedCardGroupWindowScript := preload("res://scripts/cards/shared_card_group_window.gd")
const RoguelikeEconomicViabilityPolicyScript := preload("res://scripts/runtime/roguelike_economic_viability_policy.gd")
const MenuRootLobbyScene := preload("res://scenes/ui/MenuRootLobby.tscn")
const TutorialQuickStartBoardScene := preload("res://scenes/ui/TutorialQuickStartBoard.tscn")
const RulesQuickReferenceBoardScene := preload("res://scenes/ui/RulesQuickReferenceBoard.tscn")
const RulesQuickReferenceSnapshotV06Script := preload("res://scripts/viewmodels/rules_quick_reference_snapshot_v06.gd")
const CompendiumHubSnapshotScript := preload("res://scripts/viewmodels/compendium_hub_snapshot.gd")
const EconomyDashboardScene := preload("res://scenes/ui/EconomyDashboard.tscn")
const IntelDossierBoardScene := preload("res://scenes/ui/IntelDossierBoard.tscn")
const StandingsScoreboardScene := preload("res://scenes/ui/StandingsScoreboard.tscn")
const NewGameSetupPageScene := preload("res://scenes/ui/NewGameSetupPage.tscn")
const PresentationSettingsPanelScene := preload("res://scenes/ui/PresentationSettingsPanel.tscn")
const ScenarioPauseActionsPanelScene := preload("res://scenes/ui/ScenarioPauseActionsPanel.tscn")
const ScenarioFixtureFactoryScript := preload("res://scripts/scenarios/scenario_fixture_factory.gd")
const ScenarioBrowserScene := preload("res://scenes/ui/ScenarioBrowser.tscn")
const ScenarioActionLogScene := preload("res://scenes/ui/ScenarioActionLog.tscn")
const ScenarioReplayPanelScene := preload("res://scenes/ui/ScenarioReplayPanel.tscn")
const ScenarioBrowserSnapshotScript := preload("res://scripts/viewmodels/scenario_browser_snapshot.gd")
const ScenarioActionLogSnapshotScript := preload("res://scripts/viewmodels/scenario_action_log_snapshot.gd")
const ScenarioReplayPanelSnapshotScript := preload("res://scripts/viewmodels/scenario_replay_panel_snapshot.gd")
const CampaignDefinitionScript := preload("res://scripts/campaign/campaign_definition.gd")
const CampaignProgressScript := preload("res://scripts/campaign/campaign_progress.gd")
const CampaignSaveScript := preload("res://scripts/campaign/campaign_save.gd")
const CampaignRewardServiceScript := preload("res://scripts/campaign/campaign_reward_service.gd")
const RecommendedStartServiceScript := preload("res://scripts/recommendations/recommended_start_service.gd")
const CampaignMenuScene := preload("res://scenes/ui/CampaignMenu.tscn")
const CampaignBriefingScene := preload("res://scenes/ui/CampaignBriefing.tscn")
const CampaignProgressMapScene := preload("res://scenes/ui/CampaignProgressMap.tscn")
const CampaignRewardPanelScene := preload("res://scenes/ui/CampaignRewardPanel.tscn")
const MatchRecapPanelScene := preload("res://scenes/ui/MatchRecapPanel.tscn")
const CampaignMenuSnapshotScript := preload("res://scripts/viewmodels/campaign_menu_snapshot.gd")
const CampaignBriefingSnapshotScript := preload("res://scripts/viewmodels/campaign_briefing_snapshot.gd")
const CampaignProgressMapSnapshotScript := preload("res://scripts/viewmodels/campaign_progress_map_snapshot.gd")
const CampaignRewardSnapshotScript := preload("res://scripts/viewmodels/campaign_reward_snapshot.gd")
const MatchRecapSnapshotScript := preload("res://scripts/viewmodels/match_recap_snapshot.gd")
const TABLE_SFX_KEYS := ["card", "impact", "storm"]
const CAMPAIGN_SUCCESS_FEEDBACK_SECONDS := 1.0
const MIN_PLAYER_COUNT := 3
const MAX_PLAYER_COUNT := 8
const DEFAULT_PLAYER_COUNT := 4
const MIN_AI_PLAYER_COUNT := 2
const MAX_AI_PLAYER_COUNT := 7
const DEFAULT_AI_PLAYER_COUNT := 3
const FIRST_RUN_RECOMMENDED_PLAYER_COUNT := 4
const FIRST_RUN_RECOMMENDED_AI_COUNT := 3
const FIRST_RUN_RECOMMENDED_ROLE_INDICES := [0, 1, 2, 3]
const FIRST_RUN_RECOMMENDED_STARTER_MONSTER_INDICES := [7, 6, 2, 4]
const FIRST_RUN_TEACHING_CARD_NAME := "轨道融资1"
const FIRST_RUN_TEACHING_CARD_SOURCE := "首局教学补给"
const FIRST_TABLE_FOLLOWUP_CARD_SOURCE := "首局任务第二张经营牌"
const ROLE_RANDOM_INDEX := -1
const ROGUELIKE_DEPTH_MIN := 1
const ROGUELIKE_DEPTH_MAX := 6
const DEFAULT_ROGUELIKE_DEPTH := 1
const TARGET_GAME_LENGTH_MIN_SECONDS := 1800.0
const TARGET_GAME_LENGTH_MAX_SECONDS := 3600.0
const TARGET_GAME_LENGTH_BASE_SECONDS := 1800.0
const TARGET_GAME_LENGTH_DEPTH_STEP_SECONDS := 360.0
const BALANCE_EXPECTED_CITY_COUNT_MAX := 6
const MAP_WIDTH_METERS := 1400.0
const MAP_HEIGHT_METERS := 950.0
const MAP_SITE_MARGIN_METERS := 70.0
const MAP_REGION_COUNT_MIN := 6
const MAP_REGION_COUNT_MAX := 54
const MONSTER_COMMAND_MOVE_METERS := 220.0
const MELEE_RANGE_METERS := 110.0
const NEARBY_RADIUS_METERS := 240.0
const DEFAULT_AOE_RADIUS_METERS := 180.0
const VISUAL_TRAIL_DURATION := 1.8
const DISTRICT_PULSE_DURATION := 1.2
const MAX_VISUAL_TRAILS := 18
const ACTION_CALLOUT_DURATION := 4.5
const MAX_ACTION_CALLOUTS := 8
const MAP_EVENT_EFFECT_DURATION := 1.35
const MAX_MAP_EVENT_EFFECTS := 32
const CITY_PUBLIC_CLUE_HISTORY_LIMIT := 6
const DISTRICT_CARD_CHOICE_MIN := 4
const DISTRICT_CARD_CHOICE_MAX := 5
const CARD_INGRESS_CALLOUT_DURATION := 6.5
const UI_LIVE_REFRESH_SECONDS := 0.18
const UI_MAP_REFRESH_SECONDS := 0.16
const UI_FULL_REFRESH_SECONDS := 1.80
const AUTO_MONSTER_MOVE_RATIO := 0.72
const EMBER_RING_BOMB_SELF_DAMAGE := 3
const STARTING_CASH := 2000
const CITY_PRODUCT_LEVEL_MAX := 5
const CITY_GDP_HISTORY_LIMIT := 8
const ECONOMY_LEGACY_TURN_SECONDS := 30.0
const INTEL_CORRECT_GUESS_CASH := 120
const INTEL_WRONG_GUESS_COST := 60
const CITY_GUESS_CONFIDENCE_LOW := 1
const CITY_GUESS_CONFIDENCE_MEDIUM := 2
const CITY_GUESS_CONFIDENCE_HIGH := 3
const CITY_GUESS_CONFIDENCE_DEFAULT := CITY_GUESS_CONFIDENCE_MEDIUM
const CITY_GUESS_REASON_PRODUCT := "product"
const CITY_GUESS_REASON_ROUTE := "route"
const CITY_GUESS_REASON_CARD := "card"
const CITY_GUESS_REASON_MONSTER := "monster"
const CITY_GUESS_REASON_ROLE := "role"
const CITY_GUESS_REASON_INTUITION := "intuition"
const CITY_GUESS_REASON_DEFAULT := CITY_GUESS_REASON_INTUITION
const RIVAL_AUTO_BUILD_CHANCE_PERCENT := 72
const RIVAL_AUTO_BUILD_MAX_PER_CYCLE := 2
const RIVAL_AUTO_BUILD_BASE_CITY_CAP := 2
const RIVAL_AUTO_BUILD_MAX_CITY_CAP := 5
const RIVAL_AUTO_BUILD_MIN_CASH_RESERVE := 180
const RIVAL_BUSINESS_ACTION_CHANCE_PERCENT := 76
const RIVAL_BUSINESS_ACTION_MAX_PER_CYCLE := 2
const RIVAL_BUSINESS_ACTION_COST := 90
const RIVAL_BUSINESS_PRICE_DELTA_MIN := 8
const RIVAL_BUSINESS_PRICE_DELTA_MAX := 18
const ECONOMY_HISTORY_LIMIT := 24
const ECONOMY_LEDGER_LIMIT := 14
const PLAYER_HAND_LIMIT := 5
const CARD_RESOLUTION_DISPLAY_SECONDS := 5.0
const CARD_RESOLUTION_AFTERMATH_SECONDS := 8.0
const CARD_RESOLUTION_HISTORY_LIMIT := 24
const CARD_OWNER_GUESS_STAKE := 100
const TEMP_DECISION_DISCARD := "discard_purchase"
const TEMP_DECISION_MONSTER_TARGET := "monster_target_choice"
const TEMP_DECISION_PLAYER_TARGET := "player_target_choice"
const TEMP_DECISION_MONSTER_WAGER := "monster_wager"
const MONSTER_CARD_PLAY_CASH_PER_EXISTING := 100
const MONSTER_OWNER_DAMAGE_CASH_RANK_STEP := 170
const REGION_ECONOMY_LEVEL_MIN := 1
const REGION_ECONOMY_LEVEL_MAX := 5
const REGION_TRANSPORT_SCORE_MIN := 0.55
const REGION_TRANSPORT_SCORE_MAX := 2.4
const DISTRICT_PRODUCT_COUNT_MIN := 1
const DISTRICT_PRODUCT_COUNT_MAX := 1
const DISTRICT_DEMAND_COUNT_MIN := 1
const DISTRICT_DEMAND_COUNT_MAX := 1
const DISTRICT_NEIGHBOR_COUNT := 4
const OCEAN_REGION_RATIO_MIN := 0.26
const OCEAN_REGION_RATIO_MAX := 0.40
const COMMAND_COOLDOWN := 1.0
const DEFAULT_SKILL_COOLDOWN := 3.0
const SETTINGS_PATH := "user://space_syndicate_settings.cfg"

const AUTO_MONSTER_COLORS := [
	Color("#ef4444"),
	Color("#38bdf8"),
	Color("#f59e0b"),
	Color("#a855f7"),
]

const PLAYER_COLORS := [
	Color("#38bdf8"),
	Color("#f472b6"),
	Color("#facc15"),
	Color("#4ade80"),
	Color("#c084fc"),
	Color("#fb7185"),
	Color("#2dd4bf"),
	Color("#fb923c"),
]

const PLAYER_ROLE_CATALOG := [
	{
		"name": "环港走私议会",
		"species": "蜂冠商族",
		"trait": "高速物流与电池黑市专家；喜欢把怪兽登陆伪装成货运事故。",
		"passive": "开局资金+¥80；在含环晶电池的区域购牌时，免费额外获得1张同区候选牌。",
		"starting_cash_bonus": 80,
		"bonus_card_product": "环晶电池",
		"flavor": "他们总能把第一只怪兽包装成一次普通货运事故。",
	},
	{
		"name": "深海菌毯使团",
		"species": "雾鳃孢子人",
		"trait": "擅长把资源偏好伪装成生态灾害；靠菌毯副产物结算现金。",
		"passive": "开局资金+¥80；己方含深海菌毯的城市每分钟现金流额外+¥55。",
		"starting_cash_bonus": 80,
		"resource_cash_product": "深海菌毯",
		"resource_cash_amount": 55,
		"flavor": "他们的合同像潮湿的孢子一样扩散，没人知道真正的客户是谁。",
	},
	{
		"name": "重力矿联董事会",
		"species": "岩壳重核族",
		"trait": "矿业城市与重物流保护伞；用重力陶瓷抵押城市现金流。",
		"passive": "开局资金+¥90；己方含重力陶瓷的城市每分钟现金流额外+¥45。",
		"starting_cash_bonus": 90,
		"resource_cash_product": "重力陶瓷",
		"resource_cash_amount": 45,
		"flavor": "他们称一切破坏为地质调整，并且会给调整开票。",
	},
	{
		"name": "离子军购局",
		"species": "蓝焰档案体",
		"trait": "军需订单与能量食品投标人；怪兽升级会变成采购预算。",
		"passive": "己方怪兽升级时获得¥160。",
		"monster_upgrade_cash": 160,
		"flavor": "他们从不发动战争，只是提前出售战争会需要的东西。",
	},
	{
		"name": "光合修复会",
		"species": "藤冠共生体",
		"trait": "避难产业和修复商品联盟；把光合凝胶做成灾后保险。",
		"passive": "开局资金+¥120；己方含光合凝胶的城市每分钟现金流额外+¥40。",
		"starting_cash_bonus": 120,
		"resource_cash_product": "光合凝胶",
		"resource_cash_amount": 40,
		"flavor": "他们的城市总在灾后重建合同签好之后才被灾难发现。",
	},
	{
		"name": "虹膜数据券商",
		"species": "棱眼账本体",
		"trait": "把活体芯片写进每笔交易的影子账本；擅长从情报商品区顺手拿牌。",
		"passive": "开局资金+¥60；在含活体芯片的区域购牌时，免费额外获得1张同区候选牌。",
		"starting_cash_bonus": 60,
		"bonus_card_product": "活体芯片",
		"flavor": "他们不偷情报，他们只是提前拥有账本的下一页。",
	},
	{
		"name": "星鲸餐饮垄断",
		"species": "鲸胃星民",
		"trait": "星鲸罐头连锁供应商；怪兽每次变强都会顺便带火一次联名营销。",
		"passive": "己方含星鲸罐头的城市每分钟现金流额外+¥50；己方怪兽升级时获得¥60。",
		"resource_cash_product": "星鲸罐头",
		"resource_cash_amount": 50,
		"monster_upgrade_cash": 60,
		"flavor": "他们坚称每一次怪兽袭击都只是一次过于成功的试吃会。",
	},
	{
		"name": "静电蜂巢银行",
		"species": "金翼蜂群意志",
		"trait": "用静电蜂蜜给黑市信用背书；越靠近甜味商路，越容易多拿一张牌。",
		"passive": "在含静电蜂蜜的区域购牌时，免费额外获得1张同区候选牌；卡牌归属竞猜押注成本-¥20。",
		"bonus_card_product": "静电蜂蜜",
		"card_owner_guess_discount": 20,
		"flavor": "他们发出的不是贷款通知，是一整座蜂巢的低频催收。",
	},
	{
		"name": "星图审计庭",
		"species": "银环观测官",
		"trait": "把每一座城市的施工轨迹写进星图账本；擅长直接锁定陌生区域业主。",
		"passive": "每局可用2次身份侦测：直接查明当前选中陌生城市的真实业主，并以高置信写入私人标注；城市归属终局命中奖励+¥40。",
		"intel_city_reveal_charges": 2,
		"city_guess_reward_bonus": 40,
		"flavor": "他们从不问“是谁造的”，只问“为什么发票没有经过审计庭”。",
	},
	{
		"name": "幽幕播报社",
		"species": "暗频主持群",
		"trait": "专门购买匿名出牌瞬间的影像残帧；可以追溯卡牌轨道上的历史归属。",
		"passive": "每局可用1次身份追帧：私下查明一张轨道匿名牌是谁打出的；卡牌归属竞猜押注成本-¥40。",
		"intel_card_trace_charges": 1,
		"card_owner_guess_discount": 40,
		"flavor": "所有画面都是雪花屏，只有他们听得见雪花里谁在结账。",
	},
	{
		"name": "双边密约公证团",
		"species": "镜面章鱼律师",
		"trait": "从合约墨迹里读出双方的影子；知道更多，但不能免费公开证明。",
		"passive": "每局可用2次合约回溯：私下查明最近一份合约的出牌方与目标业主；合约牌GDP份额门槛-5个百分点。",
		"intel_contract_trace_charges": 2,
		"contract_flow_discount": 1,
		"flavor": "他们盖章时会伸出第三只触手，专门握住真正签字的人。",
	},
	{
		"name": "碎光私探行会",
		"species": "棱镜游民",
		"trait": "靠半真半假的线索套利；不一定知道答案，但下注成本更低。",
		"passive": "卡牌归属竞猜押注成本-¥30，猜中额外获得¥30。",
		"card_owner_guess_discount": 30,
		"card_owner_guess_bonus": 30,
		"flavor": "他们卖出的每条线索都闪闪发光，尤其是错的那条。",
	},
	{
		"name": "星门补给商会",
		"species": "折跃仓储人",
		"trait": "把恒星晨昏线当作移动仓储时刻表；总能提前准备下一次采购。",
		"passive": "开局资金+¥40。普通牌市场的日照资格与怪兽压力报价对所有玩家一致。",
		"starting_cash_bonus": 40,
		"flavor": "他们的仓库门永远开在晨昏线到来前一秒。",
	},
	{
		"name": "赤环航运托拉斯",
		"species": "红环渡航民",
		"trait": "经营海洋保险、航道租赁和绕行合同；最擅长从运输瓶颈里抽佣。",
		"passive": "己方含风暴珍珠的城市每分钟现金流额外+¥35；合约牌GDP份额门槛-5个百分点；开局资金+¥50。",
		"starting_cash_bonus": 50,
		"resource_cash_product": "风暴珍珠",
		"resource_cash_amount": 35,
		"contract_flow_discount": 1,
		"flavor": "他们不拥有海洋，只拥有所有必须穿过海洋的发票。",
	},
	{
		"name": "霓虹需求剧院",
		"species": "幕光拟态族",
		"trait": "把消费欲望包装成演出；适合做需求城市、会展和短期订单。",
		"passive": "己方含梦境香氛的城市每分钟现金流额外+¥45；在含梦境香氛的区域购牌时，免费额外获得1张同区候选牌。",
		"resource_cash_product": "梦境香氛",
		"resource_cash_amount": 45,
		"bonus_card_product": "梦境香氛",
		"flavor": "他们出售的不是商品，是观众相信自己需要商品的那一秒。",
	},
	{
		"name": "极昼农业云",
		"species": "日冕叶群",
		"trait": "喜欢低价稳定商品和长线现金流；抗压但爆发较慢。",
		"passive": "开局资金+¥110；己方含星露莓的城市每分钟现金流额外+¥35；城市归属终局命中奖励+¥20。",
		"starting_cash_bonus": 110,
		"resource_cash_product": "星露莓",
		"resource_cash_amount": 35,
		"city_guess_reward_bonus": 20,
		"flavor": "极昼温室从不休息，账本也不休息。",
	},
	{
		"name": "黑潮风险基金",
		"species": "墨鳍量化体",
		"trait": "以灾害波动和匿名押注为食；适合金融买涨/做空与情报竞猜混合路线。",
		"passive": "开局资金+¥70；卡牌归属竞猜押注成本-¥20；猜中额外获得¥40。",
		"starting_cash_bonus": 70,
		"card_owner_guess_discount": 20,
		"card_owner_guess_bonus": 40,
		"flavor": "他们看见怪兽时先问：这次波动能不能加杠杆？",
	},
	{
		"name": "白噪安保公司",
		"species": "噪羽守密者",
		"trait": "保护运输、擦除痕迹、低调收钱；适合领先后的防守与保险路线。",
		"passive": "己方含轨迹墨水的城市每分钟现金流额外+¥40；卡牌归属竞猜押注成本-¥25；开局资金+¥40。",
		"starting_cash_bonus": 40,
		"resource_cash_product": "轨迹墨水",
		"resource_cash_amount": 40,
		"card_owner_guess_discount": 25,
		"flavor": "白噪声里什么都能消失，包括一张过于关键的发票。",
	},
	{
		"name": "钛壳互助清算所",
		"species": "钛壳贝群",
		"trait": "把城市修复、保险和低风险商品做成互助池；收益稳但依赖城市存活。",
		"passive": "开局资金+¥60；己方含钛壳贝的城市每分钟现金流额外+¥55。",
		"starting_cash_bonus": 60,
		"resource_cash_product": "钛壳贝",
		"resource_cash_amount": 55,
		"flavor": "他们愿意赔付一切损失，只要损失发生前你已经买了他们的下一份合约。",
	},
	{
		"name": "暗礁公证黑市",
		"species": "珊瑚印章群",
		"trait": "专门处理不该被看见的合约副本；擅长追溯签约关系。",
		"passive": "每局可用1次合约回溯：私下查明最近一份合约的出牌方与目标业主；合约牌GDP份额门槛-5个百分点；开局资金+¥30。",
		"starting_cash_bonus": 30,
		"intel_contract_trace_charges": 1,
		"contract_flow_discount": 1,
		"flavor": "他们的印章长在暗礁上，只有退潮时才露出真正的名字。",
	},
	{
		"name": "太阳鳞片王朝",
		"species": "金鳞恒温族",
		"trait": "偏好高价值奢侈品、公开市场动向和终局现金冲刺；很容易成为被盯上的富目标。",
		"passive": "开局资金+¥150；己方含太阳鳞片的城市每分钟现金流额外+¥30。",
		"starting_cash_bonus": 150,
		"resource_cash_product": "太阳鳞片",
		"resource_cash_amount": 30,
		"flavor": "他们从不隐藏财富，只隐藏财富旁边的怪兽脚印。",
	},
	{
		"name": "孪星兽栏同盟",
		"species": "双核驯灾族",
		"trait": "把灾害承包给成对的轨道兽栏；适合同时铺两条怪兽压力线，但资金线索也会翻倍暴露。",
		"passive": "怪兽归属上限+1：可同时拥有2只在场怪兽。第二只怪兽仍自动行动，受伤时照常让归属者按生命比例失去资金并公开线索；同名怪兽牌仍优先升级/刷新场上同名怪兽。",
		"monster_control_limit_bonus": 1,
		"starting_cash_bonus": 30,
		"flavor": "他们从不问哪只怪兽更忠诚，只问哪只怪兽离竞品城市更近。",
	},
	{
		"name": "蜂巢防务议会",
		"species": "群巢参谋体",
		"trait": "把军队拆成多个匿名战术节点；适合一支保卫收益线，一支压制竞争区。",
		"passive": "军队归属上限+1：可同时维持2支短时防卫军。每支军队各自绑定私有军令牌；军队仍不会自主行动，且军令执行不公开下令者。",
		"military_control_limit_bonus": 1,
		"starting_cash_bonus": 30,
		"flavor": "蜂巢的命令从不来自一个脑袋，所以也没人知道该追查哪一个脑袋。",
	},
	{
		"name": "悖论兽契社",
		"species": "逆相契约体",
		"trait": "把怪兽召唤契约改写成相位保险；擅长用怪兽牌抵消关键匿名行动。",
		"passive": "直接玩家互动牌展示后会出现相位响应沙漏；窗口内可把任意手中怪兽牌当作相位否决打出。会消耗该怪兽牌，但不暴露原本归属。",
		"monster_cards_as_counter": true,
		"starting_cash_bonus": 40,
		"flavor": "他们相信怪兽不是武器，而是一份足够荒谬的撤销条款。",
	},
]

const OCEAN_PRODUCT_CATALOG := [
	"星鲸罐头", "星鳍鱼群", "蓝潮藻", "巨藻纤维", "风暴珍珠", "深海菌毯",
	"海底黑油", "钛壳贝", "夜航香蕉", "暗礁珊瑚", "离岸水晶", "潮汐电浆",
]

const OCEAN_DISTRICT_NAME_POOL := [
	"蓝潮海", "静默洋", "环流海峡", "极光湾", "赤道航道", "深星海盆",
	"群岛外海", "寒冠洋", "珊瑚环礁", "远洋航门", "月影海", "磁暴海峡",
]

const SPECIAL_MONSTER_EARLY_ACTION_WEIGHTS := [2, 2, 2, 0, 0, 0]
const SPECIAL_MONSTER_ESCALATED_ACTION_WEIGHTS := [1, 1, 1, 1, 1, 1]

const WAREHOUSE_STOCKPILE_COUNT_PRESSURE := 34
const WAREHOUSE_STOCKPILE_UNIT_PRESSURE := 8
const WAREHOUSE_STOCKPILE_PRODUCT_PRESSURE := 10


const DISTRICT_NAME_POOL := [
	"东京湾", "能源塔", "旧城区", "港口", "地球总部", "商业区", "地下基地", "电视台",
	"轨道电梯", "月台仓库", "风暴街", "第七码头", "废弃工厂", "研究院", "环城高速", "巨蛋球场",
	"磁悬浮站", "海滨公园", "地下商场", "天文台", "避难中心", "中央医院", "卫星阵列", "纪念广场",
	"冷却塔", "军港", "货运枢纽", "水族馆", "数据塔", "旧神社", "工业岛", "玻璃城区",
]

const DISTRICT_PALETTE := [
	Color("#1e3a8a"),
	Color("#166534"),
	Color("#7c2d12"),
	Color("#581c87"),
	Color("#0f766e"),
	Color("#9f1239"),
	Color("#854d0e"),
	Color("#1d4ed8"),
	Color("#047857"),
	Color("#7e22ce"),
	Color("#be123c"),
	Color("#0369a1"),
]

const REALTIME_BALANCE := {
	"monster_min": 3.5,
	"monster_max": 5.5,
	"special_monster_min": 4.5,
	"special_monster_max": 7.0,
	"market_min": 30.0,
	"market_max": 60.0,
	"monster_damage": 1,
	"special_monster_damage_bonus": 0,
	"special_monster_move_bonus": 0,
}

const MONSTER_ROSTER := [
	{
		"name": "孢雾海皇",
		"hp": 50,
		"armor": 0,
		"move": 190.0,
		"move_damage": 1,
		"collision_damage": 1,
		"resource_drain": 2,
		"movement_traits": ["aquatic"],
		"terrain_move_multiplier": {"ocean": 1.35, "land": 0.72},
		"style": "瘴气水栖型：生命高，海洋移动更快、陆地迟钝，会用瘴气炮和持续区域压力污染城区。",
		"resource_focus": ["深海菌毯", "梦境香氛", "孢子丝绸"],
		"summon_access": "ocean_monster_zone",
		"economy_boon": {"label": "瘴气菌毯红利", "growth_multiplier": 1.35, "route_flow_multiplier": 1.1, "text": "偏好商品会形成黑市药材需求：正向价格增速×1.35，相关商路流通×1.1。"},
		"market_skills": ["城市融资1", "城市融资2", "城市融资3", "星际广告1", "星际广告2", "星际广告3", "轨道融资1", "舆论操控1", "诱导电波1", "过载补给1", "移动2", "移动3", "普攻2", "普攻3", "格挡1", "格挡2", "区域破坏1", "区域破坏2", "区域破坏3", "飞行1", "飞行2", "重壳冲锋1", "重壳冲锋2", "甩尾1", "甩尾2", "装甲再生1", "瘴气炮1", "瘴气炮2", "瘴气结界1", "瘴气结界2", "瘴气爆发1", "瘴气爆发2", "瘴气回收1", "瘴气回收2", "瘴气回收3", "腐蚀吐息1"],
	},
	{
		"name": "砂铠陆行兽",
		"hp": 40,
		"armor": 2,
		"move": 220.0,
		"move_damage": 2,
		"collision_damage": 2,
		"resource_drain": 1,
		"style": "冲撞护甲型：初始护甲更高，会用重壳冲锋、潜行和泥石流冲散城区。",
		"resource_focus": ["重力陶瓷", "钛壳贝", "虹膜矿粉"],
		"summon_access": "land_monster_zone",
		"economy_boon": {"label": "地壳矿带开采潮", "growth_multiplier": 1.45, "route_flow_multiplier": 1.15, "text": "偏好矿物商品获得开采热潮：正向价格增速×1.45，相关商路流通×1.15。"},
		"market_skills": ["城市融资1", "城市融资2", "城市融资3", "星际广告1", "星际广告2", "星际广告3", "轨道融资1", "舆论操控1", "诱导电波1", "过载补给1", "移动2", "移动3", "普攻2", "普攻3", "格挡1", "格挡2", "格挡3", "区域破坏1", "区域破坏2", "区域破坏3", "重壳冲锋1", "重壳冲锋2", "重壳冲锋3", "甩尾1", "甩尾2", "装甲再生1", "咆哮1", "咆哮2", "地底潜行1", "地底潜行2", "地底潜行3", "打滚1", "打滚2", "狂奔2", "泥甲1", "泥石流1"],
	},
	{
		"name": "流星哨兵",
		"hp": 30,
		"move": 360.0,
		"move_damage": 1,
		"collision_damage": 1,
		"resource_drain": 1,
		"movement_traits": ["flying"],
		"terrain_move_multiplier": {"land": 1.18, "ocean": 1.18},
		"style": "高速飞行型：移动速度高，飞行移动不会碾压路径区域，适合标准压力局。",
		"resource_focus": ["环晶电池", "活体芯片", "轨迹墨水"],
		"summon_access": "monster_zone",
		"economy_boon": {"label": "高速航线窗口", "growth_multiplier": 1.3, "route_flow_multiplier": 1.35, "text": "偏好科技商品借高速巡航扩散：正向价格增速×1.3，相关商路流通×1.35。"},
		"special_cards": ["火花反制1", "白谱锁定1", "轨降擒投诱导1", "流星航线加速1"],
	},
	{
		"name": "棱刃重甲",
		"hp": 45,
		"move": 280.0,
		"move_damage": 1,
		"collision_damage": 2,
		"resource_drain": 1,
		"style": "重装火力型：生命更高，但追击速度较慢。",
		"resource_focus": ["离子香料", "静电蜂蜜", "等离子米"],
		"summon_access": "land_monster_zone",
		"economy_boon": {"label": "军需采购波", "growth_multiplier": 1.55, "route_flow_multiplier": 1.1, "text": "偏好能量食品被军需采购推高：正向价格增速×1.55，相关商路流通×1.1。"},
		"special_cards": ["裂刃预判1", "电击踢破绽1", "垂直裂刃窗口1"],
	},
	{
		"name": "绿洲修复体",
		"hp": 30,
		"move": 300.0,
		"move_damage": 1,
		"collision_damage": 1,
		"resource_drain": 0,
		"style": "防守救援型：低生命、慢追击，适合教学或低压局。",
		"resource_focus": ["光合凝胶", "轨道盆栽", "北极薄荷"],
		"summon_access": "land_monster_zone",
		"economy_boon": {"label": "修复光线招商", "growth_multiplier": 1.2, "route_flow_multiplier": 1.6, "text": "偏好修复商品成为避难刚需：正向价格增速×1.2，相关商路流通×1.6。"},
		"special_cards": ["修复光线干扰1", "定身闪光余波1", "修正铁拳读秒1", "修复光线招商1"],
	},
	{
		"name": "焰环幼星",
		"hp": 45,
		"move": 300.0,
		"move_damage": 1,
		"collision_damage": 2,
		"resource_drain": 1,
		"style": "近战爆发型：HP降至15或以下后启动星焰能量，移动更快且近战互伤会追加火焰。",
		"resource_focus": ["太阳鳞片", "火山番茄", "彗尾柑"],
		"summon_access": "land_monster_zone",
		"economy_boon": {"label": "星焰能源热潮", "growth_multiplier": 2.0, "route_flow_multiplier": 1.15, "text": "偏好高能商品被战场能源需求点燃：正向价格增速×2，相关商路流通×1.15。"},
		"special_cards": ["星焰能量诱导1", "飞踢落点预判1", "星焰火焰护甲1", "星焰能源热潮1"],
	},
	{
		"name": "蓝锋骑士",
		"hp": 50,
		"move": 360.0,
		"move_damage": 1,
		"collision_damage": 2,
		"resource_drain": 1,
		"style": "复仇装甲型：HP降至20或以下后穿上复仇之铠，减伤、增伤，并在移动时破坏城区。",
		"resource_focus": ["极光盐", "离岸水晶", "晨昏奶酪"],
		"summon_access": "monster_zone",
		"economy_boon": {"label": "蓝锋专利授权", "growth_multiplier": 1.65, "route_flow_multiplier": 1.35, "text": "偏好晶体/精密商品获得科技授权：正向价格增速×1.65，相关商路流通×1.35。"},
		"special_cards": ["复仇之铠过载1", "热负荷射线诱导1", "蓝锋光刃窗口1", "蓝锋专利授权1"],
	},
	{
		"name": "镜像猎兵",
		"hp": 45,
		"move": 220.0,
		"move_damage": 1,
		"collision_damage": 1,
		"resource_drain": 0,
		"style": "远程迂回型：保持中距离发射光线，近战受击时可能完美格挡并反击后撤。",
		"resource_focus": ["活体芯片", "等离子米", "轨迹墨水"],
		"summon_access": "ocean_monster_zone",
		"economy_boon": {"label": "复制兵器订单", "growth_multiplier": 1.5, "route_flow_multiplier": 1.25, "text": "偏好科技军工商品出现复制订单：正向价格增速×1.5，相关商路流通×1.25。"},
		"special_cards": ["完美格挡破绽1", "混乱光线诱导1", "迂回路线封锁1"],
	},
]

const MONSTER_ART_PROFILES := {
	"孢雾海皇": {
		"accent": Color("#a855f7"),
		"secondary": Color("#4ade80"),
		"glyph": "瘴",
		"motif": "miasma",
		"subtitle": "瘴气古龙｜海雾巢",
		"upstream_source_id": "superpowers_asset_packs_cc0",
		"visual_source_id": "superpowers_cc0_dragon_family",
		"sprite_key": "superpowers_dragon",
		"sprite_cell": "full",
	},
	"砂铠陆行兽": {
		"accent": Color("#d97706"),
		"secondary": Color("#facc15"),
		"glyph": "砂",
		"motif": "mud",
		"subtitle": "冲撞泥甲｜荒漠线",
		"upstream_source_id": "monster_battler_cc0",
		"visual_source_id": "monster_battler_cc0_rock_family",
		"sprite_key": "monster_battler_rock",
		"sprite_cell": "full",
	},
	"流星哨兵": {
		"accent": Color("#38bdf8"),
		"secondary": Color("#f87171"),
		"glyph": "杰",
		"motif": "meteor_sentinel",
		"subtitle": "高速机兵｜轨道坠星",
		"upstream_source_id": "kenney_cc0",
		"visual_source_id": "kenney_cc0_enemy_ufo_family",
		"sprite_key": "kenney_enemy_ufo",
		"sprite_cell": "full",
	},
	"棱刃重甲": {
		"accent": Color("#60a5fa"),
		"secondary": Color("#f472b6"),
		"glyph": "断",
		"motif": "prism_armor",
		"subtitle": "重装裂刃｜晶体壳",
		"upstream_source_id": "monster_battler_cc0",
		"visual_source_id": "monster_battler_cc0_dino_family",
		"sprite_key": "monster_battler_dino",
		"sprite_cell": "full",
	},
	"绿洲修复体": {
		"accent": Color("#22c55e"),
		"secondary": Color("#93c5fd"),
		"glyph": "修",
		"motif": "oasis_support",
		"subtitle": "防守救援｜绿洲核",
		"upstream_source_id": "pixelmob_cc0",
		"visual_source_id": "pixelmob_cc0_slime_square_family",
		"sprite_key": "pixelmob_slime_square",
		"sprite_cell": "0",
	},
	"焰环幼星": {
		"accent": Color("#fb7185"),
		"secondary": Color("#f97316"),
		"glyph": "炎",
		"motif": "ember_ring",
		"subtitle": "星焰幼体｜熔环",
		"upstream_source_id": "moth_kaijuice_mit",
		"visual_source_id": "moth_kaijuice_mit_kaiju_family",
		"sprite_key": "moth_kaijuice_kaiju",
		"sprite_cell": "0,0",
	},
	"蓝锋骑士": {
		"accent": Color("#06b6d4"),
		"secondary": Color("#818cf8"),
		"glyph": "刃",
		"motif": "blue_lancer",
		"subtitle": "蓝锋光刃｜复仇铠",
		"upstream_source_id": "superpowers_asset_packs_cc0",
		"visual_source_id": "superpowers_cc0_snake_family",
		"sprite_key": "superpowers_snake",
		"sprite_cell": "full",
	},
	"镜像猎兵": {
		"accent": Color("#ef4444"),
		"secondary": Color("#a3e635"),
		"glyph": "杀",
		"motif": "mirror_hunter",
		"subtitle": "远程猎兵｜镜像眼",
		"upstream_source_id": "kenney_cc0",
		"visual_source_id": "kenney_cc0_alien_blue_family",
		"sprite_key": "kenney_alien_blue",
		"sprite_cell": "full",
	},
}

const MONSTER_ACTION_TABLES := {
	"孢雾海皇": [
		{"name": "瘴气漫步", "range": 0.0, "damage": 1, "move_override": 190.0, "miasma_count": 1, "text": "自动向高热城区移动约190米，落点造成1点区域伤害并尝试留下瘴气。"},
		{"name": "腐蚀吐息", "range": 420.0, "damage": 2, "move_override": -1.0, "miasma_count": 2, "text": "420米腐蚀吐息，对目标城区造成2点压力，并在周边留下瘴气。"},
		{"name": "瘴气炮", "range": 520.0, "damage": 2, "move_override": -1.0, "miasma_count": 3, "text": "520米远程瘴气炮，沿路径污染城区并造成2点区域伤害。"},
		{"name": "瘴气结界", "range": 260.0, "damage": 1, "move_override": -1.0, "miasma_count": 4, "text": "260米范围内散布瘴气，制造持续目标偏移和区域压力。"},
		{"name": "瘴气回收", "range": 240.0, "damage": 1, "move_override": -1.0, "self_heal": 2, "text": "回收周边瘴气回复自身，并让附近城区承受1点腐蚀压力。"},
		{"name": "灾厄压迫", "range": 180.0, "damage": 3, "move_override": 160.0, "text": "向最近高价值城区压迫推进，180米内造成3点区域伤害。"},
	],
	"砂铠陆行兽": [
		{"name": "重壳冲锋", "range": 130.0, "damage": 3, "move_override": 320.0, "knockback": 260.0, "text": "自动冲向高权重城区约320米，落点和近身目标承受强力冲撞。"},
		{"name": "甩尾", "range": 160.0, "damage": 2, "move_override": -1.0, "knockback": 220.0, "text": "160米范围尾击，造成2点区域/近身伤害并击退附近怪兽。"},
		{"name": "咆哮", "range": 450.0, "damage": 1, "move_override": -1.0, "delay": 1.5, "text": "450米咆哮造成区域共享生命伤害，并拖慢下一次特殊行动节奏。"},
		{"name": "地底潜行", "range": 0.0, "damage": 1, "move_override": 340.0, "armor": 2, "text": "潜入地下移动约340米，获得2点护甲并在落点造成1点区域破坏。"},
		{"name": "打滚", "range": 140.0, "damage": 2, "move_override": 260.0, "knockback": 180.0, "text": "翻滚推进约260米，落点区域和140米内目标承受2点伤害。"},
		{"name": "泥石流", "range": 220.0, "damage": 2, "move_override": -1.0, "text": "220米范围泥石流，对区域共享生命造成2点伤害。"},
	],
	"流星哨兵": [
		{"name": "翼爪扫击", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米翼爪横扫，2伤害，并击退怪兽约120米。"},
		{"name": "俯冲肩撞", "range": 125.0, "damage": 2, "move_override": 260.0, "knockback": 150.0, "text": "短距俯冲约260米后肩撞，2伤害，并击退怪兽约150米。"},
		{"name": "火花电击", "range": 420.0, "damage": 2, "move_override": -1.0, "paralyze": 1, "text": "420米射程，2伤害，并封锁一张怪兽技能卡。"},
		{"name": "高空气旋", "range": 120.0, "damage": 2, "move_override": -1.0, "throw_radius": 420.0, "text": "120米近战投掷，2坠落伤害，并把怪兽投向420米内区域。"},
		{"name": "白谱光线", "range": 600.0, "damage": 3, "move_override": -1.0, "knockback": 320.0, "text": "600米光线，3伤害，并直线击退怪兽约320米。"},
		{"name": "轨降擒投", "range": 120.0, "damage": 4, "move_override": -1.0, "throw_radius": 320.0, "stun": 1, "text": "120米近战空投，4伤害，把怪兽摔向320米内区域并使其补给受挫。"},
	],
	"棱刃重甲": [
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米近战AOE，2伤害，并击退怪兽约120米。"},
		{"name": "电击踢", "range": 120.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "paralyze": 1, "text": "120米近战AOE，2伤害，击退怪兽并封锁一张技能卡。"},
		{"name": "闪光手刀", "range": 120.0, "damage": 3, "move_override": 420.0, "paralyze": 1, "text": "高速追近420米后近战3伤害，并封锁一张技能卡。"},
		{"name": "水平裂刃", "range": 240.0, "damage": 3, "move_override": -1.0, "cripple": 1, "text": "240米射程，3伤害，并致残1张技能卡。"},
		{"name": "十字裂刃", "range": 320.0, "damage": 2, "move_override": -1.0, "cripple": 1, "stun": 1, "text": "320米射程，2伤害，并致残1张技能卡、削减技能补给。"},
		{"name": "垂直裂刃", "range": 260.0, "damage": 4, "move_override": -1.0, "cripple": 2, "text": "260米射程，4伤害，并致残2张技能卡。"},
	],
	"绿洲修复体": [
		{"name": "藤蔓掌击", "range": 110.0, "damage": 2, "move_override": -1.0, "tether": 1, "text": "110米藤蔓掌击，2伤害，并牵制怪兽下次移动。"},
		{"name": "绿洲钩拳", "range": 125.0, "damage": 2, "move_override": -1.0, "tether": 2, "text": "125米绿洲钩拳，2伤害，并施加2层牵制。"},
		{"name": "束缚光线", "range": 420.0, "damage": 2, "move_override": -1.0, "tether": 2, "text": "420米束缚光线，2伤害，并施加2层牵制。"},
		{"name": "修复光线", "range": 420.0, "damage": 3, "move_override": -1.0, "repair": 1, "text": "420米修复光线，3伤害，并修复所在区域。"},
		{"name": "定身闪光", "range": 160.0, "damage": 2, "move_override": -1.0, "repair_radius": 220.0, "tether": 4, "text": "220米修复AOE，并对160米近身目标2伤害，施加4层牵制。"},
		{"name": "修正铁拳", "range": 130.0, "damage": 5, "move_override": 560.0, "repair_path": 1, "stun_if_tethered": 3, "text": "追近560米，沿追击路径修复受损区域，对130米内目标5伤害；若怪兽被牵制则追加强眩晕。"},
	],
	"焰环幼星": [
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米近战AOE，2伤害，并击退怪兽约120米。"},
		{"name": "重拳", "range": 120.0, "damage": 3, "move_override": -1.0, "knockback": 320.0, "text": "120米重拳，3伤害，并击退怪兽约320米。"},
		{"name": "飞踢", "range": 140.0, "damage": 3, "move_override": 420.0, "stun": 1, "text": "向前飞踢追近420米，对140米内目标造成3近战伤害并眩晕1。"},
		{"name": "星焰斩击", "range": 240.0, "damage": 2, "close_range": 120.0, "close_damage": 3, "move_override": -1.0, "cripple": 1, "text": "120米内近战3伤害；否则240米远程2伤害，并致残1张技能牌。"},
		{"name": "星焰爆裂", "range": 320.0, "damage": 4, "move_override": -1.0, "stun": 1, "text": "320米远程爆裂，4伤害，并眩晕1。"},
		{"name": "星焰炸弹", "range": 120.0, "damage": 8, "move_override": -1.0, "stun": 2, "self_damage": EMBER_RING_BOMB_SELF_DAMAGE, "text": "120米近战爆弹，8伤害并眩晕2；之后焰环幼星承受3点反冲。"},
	],
	"蓝锋骑士": [
		{"name": "蓝锋轻斩", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米轻斩AOE，2伤害，并击退怪兽约120米。"},
		{"name": "回旋刃撞", "range": 125.0, "damage": 2, "move_override": 220.0, "knockback": 160.0, "text": "回旋突进约220米，125米内造成2伤害，并击退怪兽约160米。"},
		{"name": "蓝锋斩击", "range": 240.0, "damage": 2, "close_range": 120.0, "close_damage": 3, "move_override": -1.0, "cripple": 1, "text": "120米内近战3伤害；否则240米蓝锋远斩2伤害，并致残1张技能牌。"},
		{"name": "逆刃斩击", "range": 260.0, "damage": 2, "close_range": 120.0, "close_damage": 3, "move_override": -1.0, "cripple": 1, "knockback": 140.0, "text": "260米逆刃斩击；近身3伤害，远程2伤害，并致残1张技能牌、击退约140米。"},
		{"name": "热负荷射线", "range": 420.0, "damage": 3, "move_override": -1.0, "knockback": 320.0, "stun": 1, "text": "420米热负荷射线，3伤害，直线击退怪兽约320米并眩晕1。"},
		{"name": "热负荷闪光", "range": 600.0, "damage": 1, "move_override": -1.0, "self_heal": 4, "paralyze": 2, "stun": 2, "text": "自身回复4HP；600米闪光造成1伤害，并麻痹2、眩晕2。"},
	],
	"镜像猎兵": [
		{"name": "劣质光线", "range": 420.0, "damage": 2, "move_override": -1.0, "knockback": 220.0, "chaos_ray": true, "text": "420米劣质光线，2伤害，直线击退怪兽约220米，并破坏光线路径。"},
		{"name": "折射劣光", "range": 460.0, "damage": 2, "move_override": -1.0, "knockback": 180.0, "chaos_ray": true, "text": "460米折射劣光，2伤害，斜向击退怪兽约180米，并破坏光线路径。"},
		{"name": "劣质炸弹", "range": 420.0, "damage": 3, "move_override": -1.0, "stun": 1, "text": "420米劣质炸弹，3伤害，并眩晕1。"},
		{"name": "改良光线", "range": 520.0, "damage": 3, "move_override": -1.0, "knockback": 320.0, "chaos_ray": true, "text": "520米改良光线，3伤害，直线击退怪兽约320米，并破坏光线路径。"},
		{"name": "改良炸弹", "range": 520.0, "damage": 4, "move_override": -1.0, "stun": 2, "text": "520米改良炸弹，4伤害，并眩晕2。"},
		{"name": "优质光线", "range": 600.0, "damage": 5, "move_override": -1.0, "knockback": 600.0, "chaos_ray": true, "text": "600米优质光线，5伤害，直线击退怪兽约600米，并破坏光线路径。"},
	],
}

var rng := RandomNumberGenerator.new()
var players := []
var districts := []
var _roguelike_economic_viability_dev_audit: Dictionary = {}
var skill_market := []
var log_lines := []
var movement_trails := []
var action_callouts := []
var map_event_effects := []

var game_time := 0.0
var time_scale := 1.0
var selected_player := 0
var inspected_player := 0
var selected_district := 0
var selected_market_skill := "城市融资1"
var previewed_district_card := ""
var pending_discard_purchase := {}
var selected_guess_player := -1
var selected_trade_product := ""
var selected_map_layer_focus := "all"
var configured_player_count := DEFAULT_PLAYER_COUNT
var configured_ai_player_count := DEFAULT_AI_PLAYER_COUNT
var configured_roguelike_depth := DEFAULT_ROGUELIKE_DEPTH
var configured_role_indices := []
var configured_starter_monster_indices := []
var map_width_m := MAP_WIDTH_METERS
var map_height_m := MAP_HEIGHT_METERS
var district_lookup := {}

var ui_timer := 0.0
var ui_map_refresh_timer := 0.0
var ui_full_refresh_timer := 0.0

var pending_target_player_index := -1
var pending_target_slot_index := -1
var pending_target_paused_time := false
var pending_player_target_player_index := -1
var pending_player_target_slot_index := -1
var speed_before_target_choice := 1.0

var runtime_game_screen: Control
var ruleset_runtime_bridge: Node
var ruleset_runtime_bridge_bound := false
var ruleset_runtime_bridge_missing := false
var ruleset_runtime_bridge_missing_reported := false
var game_runtime_coordinator: Node
var game_runtime_coordinator_bound := false
var game_runtime_coordinator_missing := false
var game_runtime_coordinator_missing_reported := false
var monster_runtime_controller: MonsterRuntimeController
var military_runtime_controller: MilitaryRuntimeController
var weather_runtime_controller: WeatherRuntimeController
var card_resolution_runtime_controller: Node
var card_resolution_runtime_controller_bound := false
var card_resolution_controller_missing := false
var card_resolution_controller_missing_context := ""
var card_resolution_controller_missing_reported := false
var runtime_game_screen_snapshot_signature := ""
var selected_runtime_card_slot := -1
var map_view: Control
var menu_overlay: Control
var menu_preview_box: VBoxContainer
var menu_regular_buttons := []
var menu_load_run_button: Button
var district_supply_overlay: Control
var district_supply_open_district := -1
var district_supply_open_player := -1
var speed_before_menu := 1.0
var full_map_overlay: Control
var full_map_view: Control
var fullscreen_map_hud_labels := {}
var card_resolution_timer: float:
	get:
		return float(_card_resolution_controller_value(&"active_display_timer", 0.0))
	set(value):
		_set_card_resolution_controller_value(&"active_display_timer", maxf(0.0, float(value)))
var card_resolution_counter_window_active: bool:
	get:
		return bool(_card_resolution_controller_value(&"counter_window_active", false))
	set(value):
		_set_card_resolution_controller_value(&"counter_window_active", bool(value))
var card_resolution_counter_timer: float:
	get:
		return float(_card_resolution_controller_value(&"counter_timer", 0.0))
	set(value):
		_set_card_resolution_controller_value(&"counter_timer", maxf(0.0, float(value)))
var card_resolution_force_duration := -1.0
var card_resolution_simultaneous_timer: float:
	get:
		return float(_card_resolution_controller_value(&"simultaneous_timer", 0.0))
	set(value):
		_set_card_resolution_controller_value(&"simultaneous_timer", maxf(0.0, float(value)))
var card_resolution_auction_timer: float:
	get:
		return float(_card_resolution_controller_value(&"auction_timer", 0.0))
	set(value):
		_set_card_resolution_controller_value(&"auction_timer", maxf(0.0, float(value)))
var card_resolution_force_simultaneous_window := -1.0
var card_resolution_auction_open: bool:
	get:
		return bool(_card_resolution_controller_value(&"auction_open", false))
	set(value):
		_set_card_resolution_controller_value(&"auction_open", bool(value))
var card_resolution_batch_locked: bool:
	get:
		return bool(_card_resolution_controller_value(&"batch_locked", false))
	set(value):
		_set_card_resolution_controller_value(&"batch_locked", bool(value))
var card_resolution_batch_reference_player: int:
	get:
		return int(_card_resolution_controller_value(&"batch_reference_player", -1))
	set(value):
		_set_card_resolution_controller_value(&"batch_reference_player", int(value))
var card_group_window_sequence: int:
	get:
		return int(_card_resolution_controller_value(&"window_sequence", 0))
	set(value):
		_set_card_resolution_controller_value(&"window_sequence", int(value))
var last_card_resolution_player_index: int:
	get:
		return int(_card_resolution_controller_value(&"last_resolution_player_index", -1))
	set(value):
		_set_card_resolution_controller_value(&"last_resolution_player_index", int(value))
var card_resolution_visual_id := -1
var card_resolution_visual_stage := -1
var resolved_card_history := []
var selected_card_resolution_id := -1
var card_resolution_overlay: Control
var card_resolution_title_label: Label
var card_resolution_body_label: Label
var card_resolution_status_label: Label
var card_resolution_badge_box: HBoxContainer
var card_resolution_art: Control
var card_resolution_timer_bar: ProgressBar
var card_resolution_timer_label: Label
var bottom_countdown_overlay: Control
var bottom_countdown_panel: PanelContainer
var developer_balance_panel: Control
var developer_balance_refresh_timer := 0.0
var table_bgm_player: AudioStreamPlayer
var table_sfx_players := {}
var table_sfx_last_time := {}
var opening_guide_dismissed := false
var opening_guide_economy_seen_players := {}
var first_run_coach_district_seen_players := {}
var first_run_coach_supply_seen_players := {}
var first_run_coach_public_track_seen_players := {}
var first_run_coach_ai_public_action_seen_players := {}
var first_run_coach_monster_pressure_seen_players := {}
var first_run_coach_route_choice_players := {}
var first_run_coach_clues_seen_players := {}
var first_run_coach_strong_focus_until_seconds := 0.0
var first_run_coach_strong_focus_player_index := -1
var first_run_coach_strong_focus_action_id := ""
var selected_scenario_id := "first_table"
var scenario_teaching_hints_enabled := true
var scenario_auto_pause_prompts_enabled := true
var scenario_font_scale_percent := 100
var active_campaign_id := "tutorial_campaign"
var selected_campaign_chapter_id := ""
var active_campaign_chapter_id := ""
var campaign_completed_chapter_ids: Array = []
var campaign_last_reward: Dictionary = {}
var campaign_last_recap: Dictionary = {}
var campaign_completion_pending_chapter_id := ""
var runtime_visual_events: Array = []
var runtime_visual_event_key := ""
var runtime_visual_event_counter := 0
var campaign_animation_intensity := "完整"
var campaign_font_scale_label := "中"
var campaign_colorblind_assist_enabled := false
var campaign_ui_volume := 80
var campaign_bgm_volume := 60


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	rng.randomize()
	_load_settings()
	_load_campaign_progress_state()
	_build_layout()
	_build_developer_balance_greybox()
	_build_table_audio()
	_log("点击开局准备后确认玩家角色与起始怪兽牌；怪兽由怪兽卡匿名召唤，场上数量没有硬上限。")
	_open_main_menu()
	_start_table_bgm()


func _build_table_audio() -> void:
	_bind_runtime_audio_nodes()
	table_sfx_last_time = {}
	if table_bgm_player == null:
		push_error("Static TableAudioHost must provide NightPatrolTableBgm.")
	for key_variant in TABLE_SFX_KEYS:
		var key := String(key_variant)
		if not table_sfx_players.has(key) or not is_instance_valid(table_sfx_players[key]):
			push_error("Static TableAudioHost must provide NightPatrolSfx_%s." % key)


func _runtime_audio_host() -> Node:
	return get_node_or_null("RuntimeServices/TableAudioHost")


func _bind_runtime_audio_nodes() -> void:
	var host := _runtime_audio_host()
	if host == null:
		table_bgm_player = null
		table_sfx_players = {}
		push_error("Static RuntimeServices/TableAudioHost is required.")
		return
	table_bgm_player = host.get_node_or_null("NightPatrolTableBgm") as AudioStreamPlayer
	table_sfx_players = {}
	for key_variant in TABLE_SFX_KEYS:
		var key := String(key_variant)
		var player := host.get_node_or_null("NightPatrolSfx_%s" % key) as AudioStreamPlayer
		if player != null:
			table_sfx_players[key] = player
	if table_bgm_player != null and table_bgm_player.stream != null and table_bgm_player.stream.get("loop") != null:
		table_bgm_player.stream.set("loop", true)


func _start_table_bgm() -> void:
	if DisplayServer.get_name() == "headless" or table_bgm_player == null or table_bgm_player.stream == null or table_bgm_player.playing:
		return
	table_bgm_player.play()


func _play_table_sfx(key: String, min_gap_seconds: float = 0.18) -> void:
	var player := table_sfx_players.get(key, null) as AudioStreamPlayer
	if player == null or player.stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var last := float(table_sfx_last_time.get(key, -999.0))
	if now - last < min_gap_seconds:
		return
	table_sfx_last_time[key] = now
	player.stop()
	player.play()


func _sfx_key_for_action_callout(actor: String, action: String, detail: String) -> String:
	var text := "%s %s %s" % [actor, action, detail]
	if text.contains("赌局") or text.contains("下注") or text.contains("奖池"):
		return "impact"
	if text.contains("天气") or text.contains("警报") or text.contains("闪电") or text.contains("风暴") or text.contains("电磁"):
		return "storm"
	if text.contains("攻击") or text.contains("伤害") or text.contains("摧毁") or text.contains("轰击") or text.contains("击退"):
		return "impact"
	if text.contains("卡牌") or text.contains("合约") or text.contains("竞价") or text.contains("公开") or text.contains("签约"):
		return "card"
	if text.contains("建造") or text.contains("城市") or text.contains("购买"):
		return "card"
	return ""


func _process(delta: float) -> void:
	if _runtime_session_finished():
		return
	_sync_forced_decision_runtime()
	var coordinator := _game_runtime_coordinator_node()
	if coordinator != null and coordinator.has_method("blocks_global_time") and bool(coordinator.call("blocks_global_time")):
		if coordinator.has_method("tick_monster_wagers"):
			coordinator.call("tick_monster_wagers", delta)
		_update_visual_cues(delta)
		_update_process_ui_refresh(delta)
		return
	if time_scale <= 0.0:
		return

	var scaled_delta := delta * time_scale
	if coordinator != null and coordinator.has_method("advance_world_effective_clock"):
		var clock_variant: Variant = coordinator.call("advance_world_effective_clock", scaled_delta)
		var clock_snapshot: Dictionary = clock_variant if clock_variant is Dictionary else {}
		game_time = float(clock_snapshot.get("world_effective_seconds", game_time))
	if coordinator == null or not coordinator.has_method("allows_card_resolution_progress") or bool(coordinator.call("allows_card_resolution_progress")):
		_update_card_resolution_queue(scaled_delta)
	if coordinator != null and coordinator.has_method("tick_contract_runtime"):
		coordinator.call("tick_contract_runtime", scaled_delta)
	_update_realtime_cooldowns(scaled_delta)
	_city_gdp_derivative_runtime_call("update_timers")
	_product_market_runtime_call("update_futures_timers")
	if coordinator != null and coordinator.has_method("tick_weather"):
		coordinator.call("tick_weather", scaled_delta)
	_product_market_runtime_call("age_economic_boons", [scaled_delta])
	if coordinator != null and coordinator.has_method("tick_monster_wagers"):
		coordinator.call("tick_monster_wagers", scaled_delta)
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator != null and runtime_coordinator.has_method("tick_ai"):
		runtime_coordinator.call("tick_ai", scaled_delta)
	if coordinator != null and coordinator.has_method("tick_monster_motion"):
		coordinator.call("tick_monster_motion", scaled_delta)
	if coordinator != null and coordinator.has_method("tick_military"):
		coordinator.call("tick_military", scaled_delta)
	if coordinator != null and coordinator.has_method("tick_monster_actions"):
		coordinator.call("tick_monster_actions", scaled_delta)
	if coordinator != null and coordinator.has_method("tick_monster_durations"):
		coordinator.call("tick_monster_durations", scaled_delta)
	_update_visual_cues(scaled_delta)
	if coordinator != null and coordinator.has_method("tick_monster_revivals"):
		coordinator.call("tick_monster_revivals", scaled_delta)
	if not _advance_continuous_commodity_flow(scaled_delta):
		return
	if _runtime_session_finished():
		return
	if runtime_coordinator != null and runtime_coordinator.has_method("tick_product_market_cycle"):
		runtime_coordinator.call("tick_product_market_cycle", scaled_delta)
	_update_victory_control(scaled_delta)
	if _runtime_session_finished():
		return

	_update_process_ui_refresh(delta)


func _update_process_ui_refresh(delta: float) -> void:
	ui_timer -= delta
	ui_map_refresh_timer -= delta
	ui_full_refresh_timer -= delta
	if ui_timer <= 0.0:
		_refresh_live_ui()
		ui_timer = UI_LIVE_REFRESH_SECONDS
	if ui_map_refresh_timer <= 0.0:
		_refresh_board()
		ui_map_refresh_timer = UI_MAP_REFRESH_SECONDS
	if ui_full_refresh_timer <= 0.0:
		_refresh_ui()
		ui_full_refresh_timer = UI_FULL_REFRESH_SECONDS
	if developer_balance_panel != null and developer_balance_panel.visible:
		developer_balance_refresh_timer -= delta
		if developer_balance_refresh_timer <= 0.0:
			_refresh_developer_balance_greybox()
			developer_balance_refresh_timer = UI_FULL_REFRESH_SECONDS


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_ESCAPE:
		if full_map_overlay != null and full_map_overlay.visible:
			_close_fullscreen_map()
			return
		if menu_overlay != null and menu_overlay.visible:
			_close_menu()
		else:
			_open_pause_menu()
		return
	if menu_overlay != null and menu_overlay.visible:
		if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE:
			_close_menu()
		return

	match key_event.keycode:
		KEY_SPACE:
			_toggle_pause()
		KEY_1:
			_select_player(0)
		KEY_2:
			_select_player(1)
		KEY_3:
			_select_player(2)
		KEY_4:
			_select_player(3)
		KEY_5:
			_select_player(4)
		KEY_6:
			_select_player(5)
		KEY_7:
			_select_player(6)
		KEY_8:
			_select_player(7)
		KEY_Q:
			_cycle_district(-1)
		KEY_E:
			_cycle_district(1)
		KEY_G:
			_cycle_guess_player(1)
		KEY_M:
			_mark_selected_city_guess()
		KEY_C:
			_cycle_selected_district_card()
		KEY_X:
			_buy_selected_skill()
		KEY_R:
			_toggle_selected_trade_route()
		KEY_T:
			_cycle_trade_product(1)


func _build_runtime_game_screen() -> void:
	if runtime_game_screen == null:
		runtime_game_screen = get_node_or_null("RuntimeGameScreen") as Control
	if runtime_game_screen == null:
		push_error("Static RuntimeGameScreen scene is required.")
		return
	_bind_runtime_game_screen(runtime_game_screen)


func _bind_sceneized_runtime_composition() -> void:
	_bind_ruleset_runtime_bridge()
	_bind_game_runtime_coordinator()
	_bind_card_resolution_runtime_controller()
	if runtime_game_screen == null:
		runtime_game_screen = get_node_or_null("RuntimeGameScreen") as Control
	if runtime_game_screen != null:
		_bind_runtime_game_screen(runtime_game_screen)


func _ruleset_runtime_bridge_node() -> Node:
	if ruleset_runtime_bridge != null and is_instance_valid(ruleset_runtime_bridge):
		return ruleset_runtime_bridge
	ruleset_runtime_bridge = get_node_or_null("RuntimeServices/RulesetRuntimeBridge")
	ruleset_runtime_bridge_bound = false
	return ruleset_runtime_bridge


func _mark_ruleset_runtime_bridge_missing(report_error: bool = false) -> void:
	ruleset_runtime_bridge_missing = true
	if report_error and not ruleset_runtime_bridge_missing_reported:
		ruleset_runtime_bridge_missing_reported = true
		push_error("RulesetRuntimeBridge is required; no duplicate v0.3/v0.4 timing fallback is available.")


func _bind_ruleset_runtime_bridge() -> void:
	var bridge := _ruleset_runtime_bridge_node()
	if bridge == null or not bridge.has_method("debug_snapshot"):
		_mark_ruleset_runtime_bridge_missing(true)
		return
	var snapshot_variant: Variant = bridge.call("debug_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	if str(snapshot.get("ruleset_id", "")) != "v0.4" or not bool(snapshot.get("bridge_ready", false)):
		_mark_ruleset_runtime_bridge_missing(true)
		return
	ruleset_runtime_bridge_bound = true
	ruleset_runtime_bridge_missing = false
	ruleset_runtime_bridge_missing_reported = false


func _ruleset_timing_rules() -> Dictionary:
	var bridge := _ruleset_runtime_bridge_node()
	if bridge == null or not bridge.has_method("timing_rules"):
		_mark_ruleset_runtime_bridge_missing(true)
		return {}
	var timing_variant: Variant = bridge.call("timing_rules")
	return (timing_variant as Dictionary).duplicate(true) if timing_variant is Dictionary else {}


func _ruleset_timing_seconds(rule_id: StringName) -> float:
	return maxf(0.0, float(_ruleset_timing_rules().get(String(rule_id), 0.0)))


func _ruleset_runtime_debug_snapshot() -> Dictionary:
	var bridge := _ruleset_runtime_bridge_node()
	if bridge != null and bridge.has_method("debug_snapshot"):
		var snapshot_variant: Variant = bridge.call("debug_snapshot")
		if snapshot_variant is Dictionary:
			var snapshot := (snapshot_variant as Dictionary).duplicate(true)
			snapshot["bridge_bound"] = ruleset_runtime_bridge_bound
			snapshot["bridge_missing"] = ruleset_runtime_bridge_missing
			return snapshot
	return {
		"ruleset_id": "",
		"bridge_ready": false,
		"bridge_bound": false,
		"bridge_missing": true,
		"timing": {},
		"card_group": {},
		"forced_decision_priority": [],
		"capabilities": {},
	}


func _game_runtime_coordinator_node() -> GameRuntimeCoordinator:
	if game_runtime_coordinator != null and is_instance_valid(game_runtime_coordinator):
		return game_runtime_coordinator as GameRuntimeCoordinator
	game_runtime_coordinator = get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	game_runtime_coordinator_bound = false
	return game_runtime_coordinator as GameRuntimeCoordinator


func _ai_runtime_controller_node() -> Node:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.get_node_or_null("AiRuntimeController") if coordinator != null else null


func _contract_runtime_controller_node() -> ContractRuntimeController:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.call("contract_runtime_controller") as ContractRuntimeController if coordinator != null and coordinator.has_method("contract_runtime_controller") else null


func _product_market_runtime_controller_node() -> ProductMarketRuntimeController:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.call("product_market_runtime_controller") as ProductMarketRuntimeController if coordinator != null and coordinator.has_method("product_market_runtime_controller") else null


func _product_market_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("product_market_runtime_call"):
		_mark_game_runtime_coordinator_missing(true)
		return null
	return coordinator.call("product_market_runtime_call", method_name, arguments)


func _city_gdp_derivative_runtime_controller_node() -> CityGdpDerivativeRuntimeController:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.call("city_gdp_derivative_runtime_controller") as CityGdpDerivativeRuntimeController if coordinator != null and coordinator.has_method("city_gdp_derivative_runtime_controller") else null


func _city_gdp_derivative_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("city_gdp_derivative_runtime_call"):
		_mark_game_runtime_coordinator_missing(true)
		return null
	return coordinator.call("city_gdp_derivative_runtime_call", method_name, arguments)


func _route_network_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("route_network_runtime_call"):
		_mark_game_runtime_coordinator_missing(true)
		return null
	return coordinator.call("route_network_runtime_call", method_name, arguments)


func _commodity_flow_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("commodity_flow_runtime_call"):
		_mark_game_runtime_coordinator_missing(true)
		return null
	return coordinator.call("commodity_flow_runtime_call", method_name, arguments)


func _region_infrastructure_runtime_controller_node() -> Node:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.call("region_infrastructure_runtime_controller") as Node if coordinator != null and coordinator.has_method("region_infrastructure_runtime_controller") else null


func _region_infrastructure_world_bridge_node() -> Node:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.call("region_infrastructure_world_bridge") as Node if coordinator != null and coordinator.has_method("region_infrastructure_world_bridge") else null


func _region_infrastructure_snapshot_for_district(district_index: int) -> Dictionary:
	var bridge := _region_infrastructure_world_bridge_node()
	if bridge == null or district_index < 0 or district_index >= districts.size():
		return {}
	var value: Variant = bridge.call("region_snapshot_for_legacy_index", district_index)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _region_infrastructure_owned_facilities(district_index: int, player_index: int) -> Array:
	var result: Array = []
	for facility_variant in _region_infrastructure_snapshot_for_district(district_index).get("facilities", []):
		if facility_variant is Dictionary and str((facility_variant as Dictionary).get("owner_kind", "")) == "player" and int((facility_variant as Dictionary).get("owner_player_index", -1)) == player_index:
			result.append((facility_variant as Dictionary).duplicate(true))
	return result


func _initialize_region_infrastructure_runtime() -> Dictionary:
	var bridge := _region_infrastructure_world_bridge_node()
	if bridge == null:
		return {"initialized": false, "reason": "region_infrastructure_bridge_missing"}
	var definitions: Array = []
	for district_index in range(districts.size()):
		var district: Dictionary = districts[district_index]
		var neighbor_ids: Array = []
		for neighbor_variant in district.get("neighbors", []):
			var neighbor_index := int(neighbor_variant)
			if neighbor_index >= 0 and neighbor_index < districts.size():
				neighbor_ids.append(str((districts[neighbor_index] as Dictionary).get("region_id", "region.%03d" % neighbor_index)))
		definitions.append({
			"region_id": str(district.get("region_id", "region.%03d" % district_index)),
			"terrain_id": str(district.get("terrain", "unknown")),
			"neighbor_region_ids": neighbor_ids,
			"legacy_index": district_index,
		})
	var result_variant: Variant = bridge.call("initialize_from_legacy_map", definitions)
	var result: Dictionary = result_variant if result_variant is Dictionary else {"initialized": false, "reason": "region_infrastructure_result_invalid"}
	_sync_region_infrastructure_view_cache()
	return result


func _sync_region_infrastructure_view_cache(region_index: int = -1) -> void:
	var bridge := _region_infrastructure_world_bridge_node()
	if bridge == null:
		return
	var indices: Array = [region_index] if region_index >= 0 else range(districts.size())
	for index_variant in indices:
		var index := int(index_variant)
		if index < 0 or index >= districts.size():
			continue
		var snapshot_variant: Variant = bridge.call("region_snapshot_for_legacy_index", index)
		var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
		if snapshot.is_empty():
			continue
		var district: Dictionary = districts[index]
		# Temporary read projection for scene/UI consumers. Mutation belongs only to the controller.
		district["hp"] = int(snapshot.get("derived_max_hp", 0))
		district["damage"] = maxi(0, int(snapshot.get("derived_max_hp", 0)) - int(snapshot.get("derived_current_hp", 0)))
		district["destroyed"] = str(snapshot.get("lifecycle_state", "")) == "ruined"
		districts[index] = district


func _on_region_infrastructure_receipt(receipt: Dictionary) -> void:
	var controller := _region_infrastructure_runtime_controller_node()
	if controller == null:
		return
	var region_id := str(receipt.get("region_id", ""))
	var region_variant: Variant = controller.call("region_snapshot", region_id)
	var region_snapshot: Dictionary = region_variant if region_variant is Dictionary else {}
	var district_index := int(region_snapshot.get("legacy_index", -1))
	_sync_region_infrastructure_view_cache(district_index)
	if not bool(receipt.get("committed", false)) or district_index < 0 or district_index >= districts.size():
		return
	if bool(receipt.get("region_ruined", false)):
		_product_market_settle_destroyed_warehouse(district_index, str(receipt.get("source_entity_id", "unit")), receipt)
		_add_district_damage_effect(district_index, str(receipt.get("source_entity_id", "unit")), Color("#ef4444"))
		_log("%s的公共设施共享生命归零，区域进入废墟。" % str((districts[district_index] as Dictionary).get("name", "区域")))
	elif str(receipt.get("receipt_kind", "")) == "unit_damage":
		_add_district_damage_effect(district_index, str(receipt.get("source_entity_id", "unit")), Color("#fb7185"))
		_log("%s的共享生命-%d。" % [str((districts[district_index] as Dictionary).get("name", "区域")), int(receipt.get("applied_damage", 0))])
	elif str(receipt.get("receipt_kind", "")) == "region_repair":
		_pulse_district(district_index, Color("#22c55e"))
		_log("%s的共享生命修复%d。" % [str((districts[district_index] as Dictionary).get("name", "区域")), int(receipt.get("applied_repair", 0))])
	elif str(receipt.get("receipt_kind", "")) == "facility_action":
		_pulse_district(district_index, Color("#38bdf8"))
		_complete_scenario_signal("public_facility_committed", "公共设施已进入区域设施槽。", "after_facility", "planet")


func monster_deploy_cross_owner_capabilities_v06() -> Dictionary:
	var noop_participant := {
		"owner_id": "vs06.p0.no_side_effects",
		"reason_code": "p0_profile_has_no_cross_owner_patch",
		"prepare": true,
		"commit": true,
		"rollback": true,
		"finalize": true,
		"exact_once": true,
		"checkpoint": true,
		"save_load": true,
	}
	return {
		"contract_version": "v0.6",
		"region_facts": {"revisioned_snapshot": true, "owner_id": "RegionInfrastructureRuntimeController"},
		"monster_profile": {"revisioned_snapshot": true, "owner_id": "CardRuntimeCatalogV06+MonsterRosterProfile"},
		"binding_rule": {"revisioned_snapshot": true, "owner_id": "CardPlayerStateProductionAdapterV06"},
		"bound_skill_inventory": noop_participant.duplicate(true),
		"product_market_rng": noop_participant.duplicate(true),
		"role_cash_ledger": noop_participant.duplicate(true),
	}


func monster_deploy_rule_snapshot_v06(actor_id: String) -> Dictionary:
	var player_index := -1
	for candidate_index in range(players.size()):
		if _v06_actor_id(candidate_index) == actor_id:
			player_index = candidate_index
			break
	if player_index < 0:
		return {"available": false, "authoritative": false, "reason_code": "monster_binding_actor_missing"}
	var player: Dictionary = players[player_index]
	var starter_card_id := ""
	var starter_card_instance_id := ""
	for slot_variant in player.get("slots", []) as Array:
		if not (slot_variant is Dictionary):
			continue
		var card: Dictionary = slot_variant
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		if str(machine.get("effect_kind", "")) != "deploy_or_upgrade_monster" or int(machine.get("rank", 0)) != 1:
			continue
		starter_card_id = str(machine.get("card_id", ""))
		starter_card_instance_id = str(card.get("runtime_instance_id", ""))
		break
	var monster_owner := _monster_runtime_controller_node()
	if monster_owner == null or not monster_owner.has_method(&"monster_starter_state_snapshot_v06"):
		return {
			"available": false,
			"authoritative": false,
			"reason_code": "monster_starter_state_owner_unavailable",
			"revision": maxi(0, int(player.get("card_player_state_v06_revision", 0))),
			"player_index": player_index,
		}
	var starter_variant: Variant = monster_owner.call(&"monster_starter_state_snapshot_v06", actor_id)
	if not (starter_variant is Dictionary):
		return {
			"available": false,
			"authoritative": false,
			"reason_code": "monster_starter_state_snapshot_invalid",
			"revision": maxi(0, int(player.get("card_player_state_v06_revision", 0))),
			"player_index": player_index,
		}
	var starter_snapshot := starter_variant as Dictionary
	var starter_state := str(starter_snapshot.get("state", "legacy_unknown"))
	if not bool(starter_snapshot.get("available", false)) or starter_state == "legacy_unknown":
		return {
			"available": false,
			"authoritative": false,
			"reason_code": str(starter_snapshot.get("reason_code", "monster_starter_state_unavailable")),
			"revision": maxi(0, int(player.get("card_player_state_v06_revision", 0))),
			"player_index": player_index,
		}
	if not ["not_summoned", "summoned"].has(starter_state):
		return {
			"available": false,
			"authoritative": false,
			"reason_code": "monster_starter_state_snapshot_invalid",
			"revision": maxi(0, int(player.get("card_player_state_v06_revision", 0))),
			"player_index": player_index,
		}
	return {
		"available": true,
		"authoritative": true,
		"revision": maxi(0, int(player.get("card_player_state_v06_revision", 0))),
		"player_index": player_index,
		"monster_binding_limit": 1,
		"starter_entitled": not starter_card_id.is_empty(),
		"starter_consumed": starter_state == "summoned",
		"starter_card_id": starter_card_id,
		"starter_card_instance_id": starter_card_instance_id,
	}


func monster_deploy_region_snapshot_v06(region_id: String) -> Dictionary:
	var infrastructure := _region_infrastructure_runtime_controller_node()
	if infrastructure == null or not infrastructure.has_method("region_snapshot"):
		return {"available": false, "authoritative": false, "reason_code": "monster_region_owner_unavailable", "region_id": region_id}
	var region_variant: Variant = infrastructure.call("region_snapshot", region_id)
	var region: Dictionary = region_variant if region_variant is Dictionary else {}
	var district_index := int(region.get("legacy_index", -1))
	if district_index < 0 or district_index >= districts.size():
		return {"available": false, "authoritative": false, "reason_code": "monster_region_missing", "region_id": region_id}
	var district: Dictionary = districts[district_index]
	var center := _district_center(district_index)
	var destroyed := bool(district.get("destroyed", false)) or str(region.get("lifecycle_state", "")) == "ruined"
	return {
		"available": true,
		"authoritative": true,
		"revision": maxi(0, int(region.get("revision", 0))),
		"region_id": region_id,
		"region_index": district_index,
		"destroyed": destroyed,
		"starter_summon_allowed": not destroyed,
		"world_position": {"x": center.x, "y": center.y},
		"display_name": str(district.get("name", "区域")),
	}


func monster_deploy_profile_snapshot_v06(family_id: String, rank: int) -> Dictionary:
	if rank != 1:
		return {"available": false, "authoritative": false, "reason_code": "monster_non_starter_deploy_deferred", "family_id": family_id, "rank": rank}
	var coordinator := _game_runtime_coordinator_node()
	var card_id := "unit.monster.%s.rank_%d" % [family_id, rank]
	var card_variant: Variant = coordinator.call("v06_card_definition", card_id) if coordinator != null and coordinator.has_method("v06_card_definition") else {}
	var card: Dictionary = card_variant if card_variant is Dictionary else {}
	var player_text: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
	var monster_name := str(player_text.get("name", ""))
	var catalog_index := _monster_catalog_index_by_name(monster_name)
	if card.is_empty() or catalog_index < 0:
		return {"available": false, "authoritative": false, "reason_code": "monster_profile_missing", "family_id": family_id, "rank": rank}
	var roster: Dictionary = _catalog_entry(catalog_index)
	return {
		"available": true,
		"authoritative": true,
		"revision": 1,
		"family_id": family_id,
		"rank": rank,
		"name": monster_name,
		"catalog_index": catalog_index,
		"hp": int(roster.get("hp", 1)),
		"armor": int(roster.get("armor", 0)),
		"move_mps": float(roster.get("move", 0.0)),
		"move_damage": int(roster.get("move_damage", 0)),
		"collision_damage": int(roster.get("collision_damage", 0)),
		"resource_drain": int(roster.get("resource_drain", 0)),
		"movement_traits": (roster.get("movement_traits", []) as Array).duplicate(true) if roster.get("movement_traits", []) is Array else [],
		"terrain_move_multiplier": (roster.get("terrain_move_multiplier", {}) as Dictionary).duplicate(true) if roster.get("terrain_move_multiplier", {}) is Dictionary else {},
		"initial_duration_seconds": MonsterRuntimeController.MONSTER_CARD_DURATION_BASE_SECONDS,
		"bound_skill_patch": {},
		"economic_patch": {},
		"role_cash_patch": {},
	}


func prepare_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
	return _monster_deploy_no_patch_stage_v06("prepare", "prepared", request)


func commit_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
	return _monster_deploy_no_patch_stage_v06("commit", "committed", request)


func rollback_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
	return _monster_deploy_no_patch_stage_v06("rollback", "rolled_back", request)


func finalize_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
	return _monster_deploy_no_patch_stage_v06("finalize", "finalized", request)


func _monster_deploy_no_patch_stage_v06(stage: String, success_key: String, request: Dictionary) -> Dictionary:
	var required: Array = request.get("required_participants", []) if request.get("required_participants", []) is Array else []
	if not required.is_empty() \
		or not (request.get("bound_skill_patch", {}) as Dictionary).is_empty() \
		or not (request.get("economic_patch", {}) as Dictionary).is_empty() \
		or not (request.get("role_cash_patch", {}) as Dictionary).is_empty():
		return {success_key: false, "stage": stage, "reason_code": "monster_cross_owner_atomicity_unavailable"}
	return {
		success_key: true,
		"stage": stage,
		"reason_code": "p0_profile_has_no_cross_owner_patch",
		"transaction_id": str(request.get("transaction_id", "")),
		"participant_binding_fingerprint": str(request.get("participant_binding_fingerprint", "")),
	}


func _city_gdp_derivative_terms(skill: Dictionary) -> Dictionary:
	var value: Variant = _city_gdp_derivative_runtime_call("derivative_terms", [skill])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _city_gdp_derivative_duration_seconds(skill: Dictionary) -> float:
	return float(_city_gdp_derivative_runtime_call("duration_seconds", [skill]))


func _product_market_runtime_state() -> Dictionary:
	var value: Variant = _product_market_runtime_call("runtime_state_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _product_market_cycle() -> int:
	return int(_product_market_runtime_state().get("business_cycle_count", 0))


func _product_market_price(product_name: String) -> int:
	return int(_product_market_runtime_call("product_price", [product_name]))


func _product_market_tier(product_name: String) -> String:
	return str(_product_market_runtime_call("product_tier", [product_name]))


func _product_market_entry_snapshot(product_name: String) -> Dictionary:
	var value: Variant = _product_market_runtime_call("market_entry", [product_name])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _product_market_futures_public_counts(product_name: String) -> Dictionary:
	var value: Variant = _product_market_runtime_call("futures_public_counts", [product_name])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _product_market_futures_public_text(product_name: String, compact := false) -> String:
	return str(_product_market_runtime_call("futures_public_text", [product_name, compact]))


func _product_market_futures_duration_seconds(skill: Dictionary) -> float:
	return float(_product_market_runtime_call("futures_duration_seconds", [skill]))


func _product_market_route_flow_multiplier(product_name: String) -> float:
	return float(_product_market_runtime_call("product_route_flow_multiplier", [product_name]))


func _product_market_settle_destroyed_warehouse(district_index: int, source: String, damage_receipt: Dictionary) -> Dictionary:
	var value: Variant = _product_market_runtime_call("settle_futures_for_destroyed_warehouse", [district_index, source, damage_receipt.duplicate(true)])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {
		"committed": false,
		"reason": "product_market_runtime_missing",
		"settled_count": 0,
	}


func _monster_runtime_controller_node() -> MonsterRuntimeController:
	if monster_runtime_controller != null and is_instance_valid(monster_runtime_controller):
		return monster_runtime_controller
	var coordinator := _game_runtime_coordinator_node()
	monster_runtime_controller = coordinator.call("monster_runtime_controller") as MonsterRuntimeController if coordinator != null and coordinator.has_method("monster_runtime_controller") else null
	return monster_runtime_controller


func _military_runtime_controller_node() -> MilitaryRuntimeController:
	if military_runtime_controller != null and is_instance_valid(military_runtime_controller):
		return military_runtime_controller
	var coordinator := _game_runtime_coordinator_node()
	military_runtime_controller = coordinator.call("military_runtime_controller") as MilitaryRuntimeController if coordinator != null and coordinator.has_method("military_runtime_controller") else null
	return military_runtime_controller


func _on_military_runtime_event(event: Dictionary) -> void:
	if bool(event.get("public", false)) and str(event.get("summary", "")) != "":
		_log(str(event.get("summary", "")))


func _on_monster_runtime_event(event: Dictionary) -> void:
	if bool(event.get("public", false)) and str(event.get("summary", "")) != "":
		_log(str(event.get("summary", "")))


func _on_product_market_runtime_event(event: Dictionary) -> void:
	if bool(event.get("public", false)) and str(event.get("summary", "")) != "":
		_log(str(event.get("summary", "")))


func _commit_product_market_cash_delta(player_index: int, cash_delta: int, source: String, product_name: String, reason_code: String, income_amount: int = 0) -> Dictionary:
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return {"committed": false, "reason": "player_invalid"}
	var player: Dictionary = players[player_index]
	var cash_before := int(player.get("cash", 0))
	var cash_after := cash_before + cash_delta
	if cash_after < 0:
		return {
			"committed": false,
			"reason": "cash_insufficient",
			"cash_before": cash_before,
			"cash_required": -cash_delta,
		}
	player = player.duplicate(true)
	player["cash"] = cash_after
	players[player_index] = player
	var safe_income := clampi(income_amount, 0, maxi(0, cash_delta))
	if safe_income > 0:
		_record_player_card_income(player_index, safe_income, source, "%s期货收益" % product_name)
	var non_income_delta := cash_delta - safe_income
	if non_income_delta != 0:
		_record_player_economic_event(
			player_index,
			"期货保证金",
			source,
			non_income_delta,
			"%s｜%s" % [product_name, reason_code]
		)
		_record_player_cash_snapshot(player_index)
	return {
		"committed": true,
		"reason": "",
		"player_index": player_index,
		"cash_before": cash_before,
		"cash_after": cash_after,
		"cash_delta": cash_delta,
		"income_amount": safe_income,
		"reason_code": reason_code,
	}


func _commit_city_gdp_derivative_cash_delta(player_index: int, cash_delta: int, card_id: String, district_index: int, reason_code: String, income_amount: int = 0) -> Dictionary:
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return {"committed": false, "reason": "player_invalid"}
	var player: Dictionary = players[player_index]
	var cash_before := int(player.get("cash", 0))
	var cash_after := cash_before + cash_delta
	if cash_after < 0:
		return {"committed": false, "reason": "cash_insufficient", "cash_before": cash_before, "cash_required": -cash_delta}
	player = player.duplicate(true)
	player["cash"] = cash_after
	players[player_index] = player
	var safe_income := clampi(income_amount, 0, maxi(0, cash_delta))
	var district_label := str(districts[district_index].get("name", "城市")) if district_index >= 0 and district_index < districts.size() else "城市"
	if safe_income > 0:
		_record_player_card_income(player_index, safe_income, card_id, "%s GDP衍生品收益" % district_label)
	var non_income_delta := cash_delta - safe_income
	if non_income_delta != 0:
		_record_player_economic_event(player_index, "GDP衍生品保证金", card_id, non_income_delta, "%s｜%s" % [district_label, reason_code])
	_record_player_cash_snapshot(player_index)
	return {
		"committed": true,
		"reason": "",
		"player_index": player_index,
		"cash_before": cash_before,
		"cash_after": cash_after,
		"cash_delta": cash_delta,
		"income_amount": safe_income,
		"reason_code": reason_code,
	}


func _append_city_gdp_derivative_public_clue(district_index: int, clue: String) -> bool:
	var city := _district_city(district_index)
	if not _city_is_active(city):
		return false
	city = _append_city_public_clue(city, clue)
	districts[district_index]["city"] = city
	return true


func _present_city_gdp_derivative_opened(derivative_position: Dictionary) -> void:
	var district_index := int(derivative_position.get("district_index", -1))
	var district_label := str(districts[district_index].get("name", "城市")) if district_index >= 0 and district_index < districts.size() else "城市"
	var direction_label := "保单" if bool(derivative_position.get("insurance", false)) else ("买涨" if str(derivative_position.get("direction", "up")) == "up" else "做空")
	var detail := "%s｜%s｜基准GDP %d｜%s｜收益≤¥%d｜损失≤¥%d" % [
		district_label,
		direction_label,
		int(derivative_position.get("baseline_gdp", 0)),
		_duration_short_text(float(derivative_position.get("duration_seconds", 0.0))),
		int(derivative_position.get("maximum_gain", 0)),
		int(derivative_position.get("maximum_loss", 0)),
	]
	_add_action_callout("匿名GDP衍生品", str(derivative_position.get("card_id", "城市GDP衍生品")), detail, Color("#38bdf8"), _district_center(district_index) if district_index >= 0 else _economy_effect_callout_position())
	_log("匿名GDP衍生品建仓：%s；出资方保持私密。" % detail)


func _present_city_gdp_derivative_settlement(district_index: int, reason: String, public_receipts: Array) -> void:
	if public_receipts.is_empty():
		return
	var district_label := str(districts[district_index].get("name", "城市")) if district_index >= 0 and district_index < districts.size() else "城市"
	var gain_total := 0
	var loss_total := 0
	for receipt_variant in public_receipts:
		if receipt_variant is Dictionary:
			gain_total += maxi(0, int((receipt_variant as Dictionary).get("gain", 0)))
			loss_total += maxi(0, int((receipt_variant as Dictionary).get("loss", 0)))
	var summary := "%s｜结算%d笔｜公开收益¥%d｜公开损失¥%d｜持有人不公开" % [district_label, public_receipts.size(), gain_total, loss_total]
	_add_action_callout("GDP衍生品结算", reason, summary, Color("#22d3ee"), _district_center(district_index) if district_index >= 0 else _economy_effect_callout_position())
	_log("%s：%s。" % [reason, summary])


func _append_product_futures_warehouse_clue(district_index: int, source: String, direction: String, product_name: String, units: int, duration_seconds: float) -> bool:
	var city := _district_city(district_index)
	if not _city_is_active(city):
		return false
	city = _append_city_public_clue(city, "%s在本城建立%s匿名仓储：%s%d单位，%s后结算；仓储方不公开，仓库毁灭时按城市剩余生命比例结算保证金损失。" % [
		source, "看涨" if direction == "up" else "看跌", product_name, units, _duration_short_text(duration_seconds),
	])
	districts[district_index]["city"] = city
	return true


func _present_product_futures_opened(source: String, product_name: String, direction: String, before_price: int, duration_seconds: float, warehouse_district: int) -> void:
	var terms := _product_market_runtime_controller_node().terms_for_card_id(source) if _product_market_runtime_controller_node() != null else {}
	var warehouse_text := "｜仓库:%s" % str(districts[warehouse_district].get("name", "城市")) if warehouse_district >= 0 and warehouse_district < districts.size() else ""
	var risk_text := "保证金¥%d｜收益≤¥%d｜损失≤¥%d" % [
		int(terms.get("margin_cash", 0)),
		int(terms.get("maximum_gain", 0)),
		int(terms.get("maximum_loss", 0)),
	]
	_add_action_callout("匿名商品期货", source, "%s%s｜%s｜基准¥%d｜%s｜%s" % [product_name, warehouse_text, "看涨" if direction == "up" else "看跌", before_price, _duration_short_text(duration_seconds), risk_text], Color("#22d3ee"), _district_center(selected_district))
	_log("匿名商品期货建仓：%s围绕%s%s建立%s头寸，基准价¥%d，持仓%s，%s；价格仍由供需、商路、天气和合约决定。" % [source, product_name, warehouse_text, "看涨" if direction == "up" else "看跌", before_price, _duration_short_text(duration_seconds), risk_text])


func _present_product_growth_boon(source: String, product_name: String) -> void:
	if selected_district >= 0 and selected_district < districts.size():
		_pulse_district(selected_district, Color("#f59e0b"))
	_add_action_callout("商品经济", source, "%s：%s" % [product_name, _product_market_boon_text(product_name)], Color("#f59e0b"), _economy_effect_callout_position())
	_log("%s催化%s：%s。" % [source, product_name, _product_market_boon_text(product_name)])


func _present_product_contract_boon(source: String, product_name: String, before_price: int, after_price: int, before_volatility: int, after_volatility: int, cash_gain: int) -> void:
	if selected_district >= 0 and selected_district < districts.size():
		_pulse_district(selected_district, Color("#f59e0b"))
	_add_action_callout("商品合约", source, "%s：%s，¥%d→¥%d。" % [product_name, _product_market_boon_text(product_name), before_price, after_price], Color("#f59e0b"), _economy_effect_callout_position())
	_log("%s签下%s商品合约：%s，价格¥%d→¥%d，波动%d→%d，获得¥%d。" % [source, product_name, _product_market_boon_text(product_name), before_price, after_price, before_volatility, after_volatility, maxi(0, cash_gain)])


func _age_product_market_world_boons(delta_seconds: float) -> bool:
	var changed := false
	for index_variant in _active_city_district_indices():
		var district_index := int(index_variant)
		var city := _district_city(district_index).duplicate(true)
		if _age_remaining_effect_seconds(city, "route_flow_seconds", "route_flow_turns", delta_seconds):
			city["route_flow_multiplier"] = 1.0
			city["route_flow_source"] = ""
			changed = true
		if _age_remaining_effect_seconds(city, "contract_seconds", "contract_turns", delta_seconds):
			city["contract_income_bonus"] = 0
			city["contract_source"] = ""
			changed = true
		if int(city.get("military_gdp_penalty", 0)) > 0 and float(city.get("military_pressure_until", 0.0)) <= game_time:
			city["military_gdp_penalty"] = 0
			city["military_pressure_source"] = ""
			changed = true
		districts[district_index]["city"] = city
	if changed:
		_refresh_route_network()
	return changed


func _on_product_market_cycle_completed(cycle_count: int) -> void:
	_log("全局市场刷新%d：商品公开基础价格已更新；现金与GDP只由实际成交回执产生。" % cycle_count)
	_ai_runtime_call("_auto_rival_business_actions", [false])
	_ai_runtime_call("_finalize_ai_decision_rewards")
	for player_index in range(players.size()):
		_record_player_cash_snapshot(player_index)


func _ai_runtime_call(method_name: StringName, arguments: Array = []) -> Variant:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("ai_runtime_call"):
		_mark_game_runtime_coordinator_missing(true)
		return null
	return coordinator.call("ai_runtime_call", method_name, arguments)


func _ai_runtime_world_snapshot(player_index: int) -> Dictionary:
	return {
		"context_revision": int(game_time * 1000.0),
		"player_index": player_index,
		"player_count": players.size(),
		"district_count": districts.size(),
		"business_cycle_count": _product_market_cycle(),
		"session_finished": _runtime_session_finished(),
		"victory_control": _victory_control_private_snapshot(player_index),
		"active_resolution_present": not _card_resolution_active_entry().is_empty(),
	}


func _apply_ai_runtime_intent(intent: Dictionary) -> Dictionary:
	var intent_id := str(intent.get("intent_id", ""))
	var action_id := str(intent.get("action_id", ""))
	if action_id == "ai_runtime_noop":
		return {"applied": true, "reason": "noop", "intent_id": intent_id, "action_id": action_id}
	return {"applied": false, "reason": "unsupported_intent", "intent_id": intent_id, "action_id": action_id}


func _on_ai_runtime_event(event: Dictionary) -> void:
	if bool(event.get("public", false)) and str(event.get("summary", "")) != "":
		_log(str(event.get("summary", "")))


func _ai_runtime_rng_gateway(operation: StringName, arguments: Array = []) -> Variant:
	match operation:
		&"randi_range":
			return rng.randi_range(int(arguments[0]), int(arguments[1])) if arguments.size() >= 2 else 0
		&"randf_range":
			return rng.randf_range(float(arguments[0]), float(arguments[1])) if arguments.size() >= 2 else 0.0
		&"randf":
			return rng.randf()
		&"state":
			return rng.state
	return null


func _ai_runtime_world_constant_snapshot() -> Dictionary:
	return {
		"ACTION_CALLOUT_DURATION": ACTION_CALLOUT_DURATION,
		"AUTO_MONSTER_ENCOUNTER_RANGE_METERS": MonsterRuntimeController.AUTO_MONSTER_ENCOUNTER_RANGE_METERS,
		"CITY_GUESS_CONFIDENCE_DEFAULT": CITY_GUESS_CONFIDENCE_DEFAULT,
		"CITY_GUESS_CONFIDENCE_HIGH": CITY_GUESS_CONFIDENCE_HIGH,
		"CITY_GUESS_CONFIDENCE_LOW": CITY_GUESS_CONFIDENCE_LOW,
		"CITY_GUESS_CONFIDENCE_MEDIUM": CITY_GUESS_CONFIDENCE_MEDIUM,
		"CITY_GUESS_REASON_CARD": CITY_GUESS_REASON_CARD,
		"CITY_GUESS_REASON_DEFAULT": CITY_GUESS_REASON_DEFAULT,
		"CITY_GUESS_REASON_INTUITION": CITY_GUESS_REASON_INTUITION,
		"CITY_GUESS_REASON_PRODUCT": CITY_GUESS_REASON_PRODUCT,
		"CITY_GUESS_REASON_ROUTE": CITY_GUESS_REASON_ROUTE,
		"DEFAULT_AOE_RADIUS_METERS": DEFAULT_AOE_RADIUS_METERS,
		"ECONOMY_LEGACY_TURN_SECONDS": ECONOMY_LEGACY_TURN_SECONDS,
		"MAX_PLAYER_COUNT": MAX_PLAYER_COUNT,
		"MIN_PLAYER_COUNT": MIN_PLAYER_COUNT,
		"NEARBY_RADIUS_METERS": NEARBY_RADIUS_METERS,
		"PLAYER_HAND_LIMIT": PLAYER_HAND_LIMIT,
		"ProductMarketRuntimeController.PRODUCT_CATALOG": ProductMarketRuntimeController.PRODUCT_CATALOG,
		"RIVAL_AUTO_BUILD_BASE_CITY_CAP": RIVAL_AUTO_BUILD_BASE_CITY_CAP,
		"RIVAL_AUTO_BUILD_CHANCE_PERCENT": RIVAL_AUTO_BUILD_CHANCE_PERCENT,
		"RIVAL_AUTO_BUILD_MAX_CITY_CAP": RIVAL_AUTO_BUILD_MAX_CITY_CAP,
		"RIVAL_AUTO_BUILD_MAX_PER_CYCLE": RIVAL_AUTO_BUILD_MAX_PER_CYCLE,
		"RIVAL_AUTO_BUILD_MIN_CASH_RESERVE": RIVAL_AUTO_BUILD_MIN_CASH_RESERVE,
		"RIVAL_BUSINESS_ACTION_CHANCE_PERCENT": RIVAL_BUSINESS_ACTION_CHANCE_PERCENT,
		"RIVAL_BUSINESS_ACTION_COST": RIVAL_BUSINESS_ACTION_COST,
		"RIVAL_BUSINESS_ACTION_MAX_PER_CYCLE": RIVAL_BUSINESS_ACTION_MAX_PER_CYCLE,
	}


func _card_resolution_queue_service_node() -> Node:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.get_node_or_null("CardResolutionQueueRuntimeService") if coordinator != null else null


func _card_resolution_execution_world_bridge_node() -> Node:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.get_node_or_null("CardResolutionExecutionWorldBridge") if coordinator != null else null


func _card_economy_product_route_effect_world_bridge_node() -> Node:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.get_node_or_null("CardEconomyProductRouteEffectWorldBridge") if coordinator != null else null


func _card_economy_product_route_formula_result(formula_id: String, input_snapshot: Dictionary) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("calculate_card_economy_product_route_formula"):
		_mark_game_runtime_coordinator_missing(true)
		return {}
	var value: Variant = coordinator.call("calculate_card_economy_product_route_formula", formula_id, input_snapshot)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_resolution_current_queue() -> Array:
	var service := _card_resolution_queue_service_node()
	var value: Variant = service.call("current_queue") if service != null and service.has_method("current_queue") else []
	return (value as Array).duplicate(true) if value is Array else []


func _card_resolution_next_queue() -> Array:
	var service := _card_resolution_queue_service_node()
	var value: Variant = service.call("next_queue") if service != null and service.has_method("next_queue") else []
	return (value as Array).duplicate(true) if value is Array else []


func _card_resolution_active_entry() -> Dictionary:
	var service := _card_resolution_queue_service_node()
	var value: Variant = service.call("active_entry") if service != null and service.has_method("active_entry") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_resolution_sequence_value() -> int:
	var service := _card_resolution_queue_service_node()
	return int(service.call("resolution_sequence")) if service != null and service.has_method("resolution_sequence") else 0


func _get(property: StringName) -> Variant:
	var monster_controller := _monster_runtime_controller_node()
	var military_controller := _military_runtime_controller_node()
	match property:
		&"military_units":
			return military_controller.roster_snapshot(true) if military_controller != null else []
		&"next_military_unit_uid":
			return military_controller.next_military_unit_uid if military_controller != null else 1
		&"auto_monsters":
			return monster_controller.roster_snapshot(true) if monster_controller != null else []
		&"next_auto_monster_uid":
			return monster_controller.next_auto_monster_uid if monster_controller != null else 1
		&"next_special_monster_slot":
			return monster_controller.next_special_monster_slot if monster_controller != null else 0
		&"selected_auto_monster_slot":
			return monster_controller.selected_auto_monster_slot if monster_controller != null else 0
		&"active_monster_wagers":
			return monster_controller.active_wagers_snapshot() if monster_controller != null else []
		&"resolved_monster_wager_history":
			return monster_controller.resolved_wagers_snapshot() if monster_controller != null else []
		&"monster_wager_sequence":
			return monster_controller.monster_wager_sequence if monster_controller != null else 0
		&"public_card_bid_monster_wager_pool":
			return monster_controller.public_card_bid_monster_wager_pool if monster_controller != null else 0
		&"monster_timer":
			return monster_controller.monster_timer if monster_controller != null else 4.0
		&"special_monster_timer":
			return monster_controller.special_monster_timer if monster_controller != null else 5.0
		&"card_resolution_queue":
			return _card_resolution_current_queue()
		&"next_card_resolution_queue":
			return _card_resolution_next_queue()
		&"active_card_resolution":
			return _card_resolution_active_entry()
		&"card_resolution_sequence":
			return _card_resolution_sequence_value()
	return null


func _set(property: StringName, value: Variant) -> bool:
	var service := _card_resolution_queue_service_node()
	var monster_controller := _monster_runtime_controller_node()
	var military_controller := _military_runtime_controller_node()
	match property:
		&"military_units":
			if value is Array and military_controller != null:
				military_controller.military_units = (value as Array).duplicate(true)
				return true
		&"next_military_unit_uid":
			if (value is int or value is float) and military_controller != null:
				military_controller.next_military_unit_uid = maxi(1, int(value))
				return true
		&"auto_monsters":
			if value is Array and monster_controller != null:
				monster_controller.auto_monsters = (value as Array).duplicate(true)
				for index in range(monster_controller.auto_monsters.size()):
					if monster_controller.auto_monsters[index] is Dictionary:
						(monster_controller.auto_monsters[index] as Dictionary)["slot"] = index
				return true
		&"next_auto_monster_uid":
			if (value is int or value is float) and monster_controller != null:
				monster_controller.next_auto_monster_uid = maxi(1, int(value))
				return true
		&"next_special_monster_slot":
			if (value is int or value is float) and monster_controller != null:
				monster_controller.next_special_monster_slot = int(value)
				return true
		&"selected_auto_monster_slot":
			if (value is int or value is float) and monster_controller != null:
				monster_controller.selected_auto_monster_slot = int(value)
				return true
		&"active_monster_wagers":
			if value is Array and monster_controller != null:
				monster_controller.active_monster_wagers = (value as Array).duplicate(true)
				return true
		&"resolved_monster_wager_history":
			if value is Array and monster_controller != null:
				monster_controller.resolved_monster_wager_history = (value as Array).duplicate(true)
				return true
		&"monster_wager_sequence":
			if (value is int or value is float) and monster_controller != null:
				monster_controller.monster_wager_sequence = maxi(0, int(value))
				return true
		&"public_card_bid_monster_wager_pool":
			if (value is int or value is float) and monster_controller != null:
				monster_controller.public_card_bid_monster_wager_pool = maxi(0, int(value))
				return true
		&"monster_timer":
			if (value is int or value is float) and monster_controller != null:
				monster_controller.monster_timer = maxf(0.0, float(value))
				return true
		&"special_monster_timer":
			if (value is int or value is float) and monster_controller != null:
				monster_controller.special_monster_timer = maxf(0.0, float(value))
				return true
		&"card_resolution_queue":
			if value is Array and service != null and service.has_method("replace_current_queue"):
				service.call("replace_current_queue", (value as Array).duplicate(true))
				return true
		&"next_card_resolution_queue":
			if value is Array and service != null and service.has_method("replace_next_queue"):
				service.call("replace_next_queue", (value as Array).duplicate(true))
				return true
		&"active_card_resolution":
			if value is Dictionary and service != null and service.has_method("replace_active_entry"):
				service.call("replace_active_entry", (value as Dictionary).duplicate(true))
				return true
		&"card_resolution_sequence":
			if (value is int or value is float) and service != null and service.has_method("replace_resolution_sequence"):
				service.call("replace_resolution_sequence", int(value))
				return true
	return false


func _codex_navigation_controller_node() -> Node:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.get_node_or_null("CodexNavigationRuntimeController") if coordinator != null else null


func _intel_dossier_public_snapshot_service_node() -> Node:
	var coordinator := _game_runtime_coordinator_node()
	return coordinator.get_node_or_null("IntelDossierPublicSnapshotService") if coordinator != null else null


func _codex_page_count(total_count: int, entries_per_page: int) -> int:
	var controller := _codex_navigation_controller_node()
	return int(controller.call("page_count", total_count, entries_per_page)) if controller != null else 1


func _codex_page_for_index(index: int, total_count: int, entries_per_page: int) -> int:
	var controller := _codex_navigation_controller_node()
	return int(controller.call("page_for_index", index, total_count, entries_per_page)) if controller != null else 0


func _codex_first_index_on_page(page_index: int, total_count: int, entries_per_page: int) -> int:
	var controller := _codex_navigation_controller_node()
	return int(controller.call("first_index_on_page", page_index, total_count, entries_per_page)) if controller != null else 0


func _mark_game_runtime_coordinator_missing(report_error: bool = false) -> void:
	game_runtime_coordinator_missing = true
	if report_error and not game_runtime_coordinator_missing_reported:
		game_runtime_coordinator_missing_reported = true
		push_error("GameRuntimeCoordinator is required; forced-decision priority has no legacy fallback.")


func _bind_game_runtime_coordinator() -> void:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("configure") or not coordinator.has_method("debug_snapshot"):
		_mark_game_runtime_coordinator_missing(true)
		return
	if coordinator.has_method("bind_ai_world"):
		coordinator.call("bind_ai_world", self)
	coordinator.call("configure", _ruleset_runtime_debug_snapshot())
	monster_runtime_controller = coordinator.call("monster_runtime_controller") as MonsterRuntimeController if coordinator.has_method("monster_runtime_controller") else null
	military_runtime_controller = coordinator.call("military_runtime_controller") as MilitaryRuntimeController if coordinator.has_method("military_runtime_controller") else null
	weather_runtime_controller = coordinator.call("weather_runtime_controller") as WeatherRuntimeController if coordinator.has_method("weather_runtime_controller") else null
	if monster_runtime_controller == null or military_runtime_controller == null or weather_runtime_controller == null:
		_mark_game_runtime_coordinator_missing(true)
		return
	var snapshot_variant: Variant = coordinator.call("debug_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var required_ready := bool(snapshot.get("coordinator_ready", false)) if not players.is_empty() else bool(snapshot.get("coordinator_composition_ready", false))
	if not required_ready:
		_mark_game_runtime_coordinator_missing(true)
		return
	game_runtime_coordinator_bound = true
	game_runtime_coordinator_missing = false
	game_runtime_coordinator_missing_reported = false


func _active_runtime_scenario_id() -> String:
	var coordinator := _game_runtime_coordinator_node()
	return str(coordinator.call("active_runtime_scenario_id")) if coordinator != null and coordinator.has_method("active_runtime_scenario_id") else ""


func _runtime_scenario_state() -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator != null and coordinator.has_method("runtime_scenario_state"):
		var value: Variant = coordinator.call("runtime_scenario_state", game_time)
		return (value as Dictionary).duplicate(true) if value is Dictionary else {}
	return {}


func _card_resolution_controller_node() -> Node:
	if card_resolution_runtime_controller != null and is_instance_valid(card_resolution_runtime_controller):
		return card_resolution_runtime_controller
	card_resolution_runtime_controller = null
	card_resolution_runtime_controller_bound = false
	var found := get_node_or_null("RuntimeServices/RuntimeControllerHost/CardResolutionRuntimeController")
	if found != null:
		card_resolution_runtime_controller = found
	return card_resolution_runtime_controller


func _mark_card_resolution_controller_missing(context: String, report_error: bool = false) -> void:
	card_resolution_controller_missing = true
	card_resolution_controller_missing_context = context
	if report_error and not card_resolution_controller_missing_reported:
		card_resolution_controller_missing_reported = true
		push_error("CardResolutionRuntimeController is required for %s; no legacy timing fallback is available." % context)


func _card_resolution_controller_value(property_name: StringName, default_value: Variant) -> Variant:
	var controller := _card_resolution_controller_node()
	if controller == null:
		_mark_card_resolution_controller_missing("read %s" % property_name)
		return default_value
	return controller.get(property_name)


func _set_card_resolution_controller_value(property_name: StringName, value: Variant) -> void:
	var controller := _card_resolution_controller_node()
	if controller == null:
		_mark_card_resolution_controller_missing("write %s" % property_name, true)
		return
	controller.set(property_name, value)


func _bind_card_resolution_runtime_controller() -> void:
	var controller := _card_resolution_controller_node()
	if controller == null:
		_mark_card_resolution_controller_missing("runtime binding", true)
		return
	var card_group_rules := _card_group_runtime_rules()
	if card_group_rules.is_empty():
		_mark_game_runtime_coordinator_missing(true)
		return
	if controller.has_method("configure"):
		controller.call("configure", {
			"total_window_seconds": float(card_group_rules.get("group_seconds", controller.get("total_window_seconds"))),
			"planning_seconds": float(card_group_rules.get("planning_seconds", card_group_rules.get("organize_seconds", controller.get("planning_seconds")))),
			"public_bid_seconds": float(card_group_rules.get("public_bid_seconds", controller.get("public_bid_seconds"))),
			"lock_seconds": float(card_group_rules.get("lock_seconds", controller.get("lock_seconds"))),
			"opening_extended_windows": int(card_group_rules.get("opening_extended_windows", controller.get("opening_extended_windows"))),
			"opening_total_window_seconds": float(card_group_rules.get("opening_group_seconds", controller.get("opening_total_window_seconds"))),
			"opening_planning_seconds": float(card_group_rules.get("opening_planning_seconds", controller.get("opening_planning_seconds"))),
			"display_seconds": CARD_RESOLUTION_DISPLAY_SECONDS,
			"counter_seconds": _card_counter_response_duration(),
		})
	card_resolution_runtime_controller_bound = true
	card_resolution_controller_missing = false
	card_resolution_controller_missing_context = ""
	card_resolution_controller_missing_reported = false


func _card_resolution_controller_facts() -> Dictionary:
	var active_player_indices: Array = []
	for player_index in range(players.size()):
		if not _player_is_eliminated(player_index):
			active_player_indices.append(player_index)
	return {
		"queue_empty": _card_resolution_current_queue().is_empty(),
		"active_present": not _card_resolution_active_entry().is_empty(),
		"active_counterable": _card_can_open_counter_window(_card_resolution_active_entry()),
		"active_id": str(_card_resolution_active_entry().get("resolution_id", _card_resolution_active_entry().get("queued_order", ""))),
		"lock_duration": _card_group_lock_duration(),
		"public_bid_duration": _card_group_public_bid_duration(),
		"counter_duration": _card_counter_response_duration(),
		"active_player_indices": active_player_indices,
	}


func _bind_runtime_game_screen(screen: Control) -> void:
	if screen == null:
		return
	runtime_game_screen = screen
	runtime_game_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	runtime_game_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	runtime_game_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var signal_bindings := {
		"action_requested": Callable(self, "_on_runtime_game_screen_action_requested"),
		"end_turn_requested": Callable(self, "_on_runtime_game_screen_end_turn_requested"),
		"card_selected": Callable(self, "_on_runtime_game_screen_card_selected"),
		"card_drop_requested": Callable(self, "_on_runtime_game_screen_card_drop_requested"),
	}
	for signal_name_variant in signal_bindings.keys():
		var signal_name := StringName(signal_name_variant)
		var callback: Callable = signal_bindings[signal_name_variant]
		if runtime_game_screen.has_signal(signal_name) and not runtime_game_screen.is_connected(signal_name, callback):
			runtime_game_screen.connect(signal_name, callback)


func _runtime_overlay_parent() -> Node:
	if runtime_game_screen != null and runtime_game_screen.has_method("get_overlay_host"):
		var host: Variant = runtime_game_screen.call("get_overlay_host")
		if host is Node:
			var runtime_surface := (host as Node).get_node_or_null("RuntimeSurfaceLayer")
			return runtime_surface if runtime_surface != null else host
	return self


func _runtime_composition_control(node_name: String) -> Control:
	if runtime_game_screen != null:
		var screen_match := runtime_game_screen.find_child(node_name, true, false) as Control
		if screen_match != null:
			return screen_match
	return find_child(node_name, true, false) as Control


func _developer_balance_greybox_enabled() -> bool:
	var value := OS.get_environment("SPACE_SYNDICATE_DEV_BALANCE").strip_edges().to_lower()
	return ["1", "true", "yes", "on", "dev"].has(value)


func _build_developer_balance_greybox() -> void:
	if not _developer_balance_greybox_enabled() or developer_balance_panel != null:
		return
	var panel_scene := load("res://scenes/ui/DeveloperBalancePanel.tscn") as PackedScene
	if panel_scene == null:
		return
	var panel := panel_scene.instantiate() as Control
	if panel == null:
		return
	panel.name = "DeveloperBalancePanel"
	panel.visible = true
	developer_balance_panel = panel
	_runtime_overlay_parent().add_child(panel)
	_refresh_developer_balance_greybox()


func _refresh_developer_balance_greybox() -> void:
	if developer_balance_panel == null or not developer_balance_panel.visible:
		return
	var diagnostics := _game_runtime_coordinator_node().gameplay_balance_diagnostics_service()
	if developer_balance_panel.has_method("set_diagnostics_service"):
		developer_balance_panel.call("set_diagnostics_service", diagnostics)
	if developer_balance_panel.has_method("refresh_report"):
		developer_balance_panel.call("refresh_report", true)


func _sync_runtime_game_screen(force: bool = false) -> void:
	if runtime_game_screen == null or not runtime_game_screen.has_method("apply_state"):
		return
	var coordinator := _game_runtime_coordinator_node()
	if coordinator != null and runtime_game_screen.has_method("set_weather_presentation"):
		var weather_motion_mode := "reduced" if campaign_animation_intensity == "简化" else ("off" if campaign_animation_intensity == "关闭" else "full")
		runtime_game_screen.call(
			"set_weather_presentation",
			coordinator.weather_forecast_view_model(),
			coordinator.weather_map_overlay_view_model(),
			weather_motion_mode
		)
	var table_state := _runtime_table_snapshot_source()
	var signature := var_to_str(table_state)
	if not force and signature == runtime_game_screen_snapshot_signature:
		return
	runtime_game_screen_snapshot_signature = signature
	runtime_game_screen.call("apply_state", table_state)


func _on_runtime_game_screen_action_requested(action_id: String) -> void:
	var handled := false
	match action_id:
		"primary":
			handled = _activate_runtime_snapshot_action(_runtime_primary_action_entry(_runtime_snapshot_player_index()))
		"codex_region":
			_codex_navigation_controller_node().return_target = "game"
			_open_region_codex_menu(selected_district)
			handled = true
		"codex_cards":
			_codex_navigation_controller_node().return_target = "game"
			_open_card_codex_menu()
			handled = true
		"codex_intel":
			_open_intel_dossier_menu()
			handled = true
		"inspect":
			_open_compendium_menu()
			handled = true
		"menu":
			_open_pause_menu()
			handled = true
		"discard_purchase_cancel":
			_cancel_discard_purchase()
			handled = true
		"card_group_ready":
			handled = _set_selected_player_card_group_ready()
		"coach_select_district", "coach_open_rack", "coach_buy_card", "coach_play_card", "coach_buy_followup_card", "coach_play_followup_card", "coach_inspect_track", "coach_check_economy", "coach_observe_ai_public_action", "coach_inspect_clues", "coach_inspect_monster_pressure", "coach_choose_route_growth":
			handled = _activate_first_run_coach_action(action_id)
		"rack", "buy", "play":
			handled = _activate_runtime_quick_action(action_id)
		_:
			if _activate_runtime_temporary_decision_action(action_id):
				handled = true
			elif action_id.begins_with("scenario_"):
				handled = _activate_scenario_action(action_id)
			elif action_id.begins_with("bid_set_"):
				var target_bid := int(action_id.substr("bid_set_".length()))
				_set_selected_card_priority_bid(target_bid)
				handled = true
			elif action_id.begins_with("group_order_up_"):
				var group_up_resolution_id := int(action_id.substr("group_order_up_".length()))
				handled = _move_card_within_group(group_up_resolution_id, -1)
			elif action_id.begins_with("group_order_down_"):
				var group_down_resolution_id := int(action_id.substr("group_order_down_".length()))
				handled = _move_card_within_group(group_down_resolution_id, 1)
			elif action_id.begins_with("district_"):
				handled = _activate_runtime_district_action(action_id)
			elif action_id.begins_with("play_"):
				var slot_index := int(action_id.substr("play_".length()))
				selected_runtime_card_slot = slot_index
				_use_skill(slot_index)
				handled = true
			elif action_id.begins_with("discard_purchase_"):
				var discard_slot := int(action_id.substr("discard_purchase_".length()))
				_confirm_discard_purchase(discard_slot)
				handled = true
			elif action_id.begins_with("track_return_"):
				var return_resolution_id := int(action_id.substr("track_return_".length()))
				selected_runtime_card_slot = -1
				_focus_card_resolution_track_entry(return_resolution_id)
				_close_menu()
				handled = true
			elif action_id.begins_with("track_guess_"):
				var guess_resolution_id := int(action_id.substr("track_guess_".length()))
				selected_runtime_card_slot = -1
				_focus_card_resolution_track_entry(guess_resolution_id)
				_close_menu()
				handled = true
			elif action_id.begins_with("track_select_"):
				var resolution_id := int(action_id.substr("track_select_".length()))
				selected_runtime_card_slot = -1
				_select_card_resolution_track_entry(resolution_id)
				_mark_first_run_coach_public_track_seen(_runtime_snapshot_player_index())
				handled = true
			elif action_id.begins_with("track_intel_"):
				var intel_resolution_id := int(action_id.substr("track_intel_".length()))
				selected_runtime_card_slot = -1
				selected_card_resolution_id = intel_resolution_id
				_mark_first_run_coach_public_track_seen(_runtime_snapshot_player_index())
				_mark_first_run_coach_clues_seen(_runtime_snapshot_player_index())
				_open_intel_dossier_menu()
				handled = true
			elif action_id.begins_with("track_open_"):
				var card_name := action_id.substr("track_open_".length()).strip_edges()
				if card_name != "":
					selected_runtime_card_slot = -1
					_open_card_codex_by_name(card_name)
					handled = true
	if handled:
		_sync_runtime_game_screen(true)


func _activate_runtime_temporary_decision_action(action_id: String) -> bool:
	if action_id == "target_monster_cancel":
		_cancel_pending_target_choice()
		return true
	if action_id.begins_with("target_monster_"):
		var slot_text := action_id.substr("target_monster_".length()).strip_edges()
		if slot_text.is_valid_int():
			_choose_pending_target_monster(int(slot_text))
			return true
	if action_id == "target_player_cancel":
		_cancel_pending_player_target_choice()
		return true
	if action_id.begins_with("target_player_"):
		var player_text := action_id.substr("target_player_".length()).strip_edges()
		if player_text.is_valid_int():
			_choose_pending_target_player(int(player_text))
			return true
	if action_id.begins_with("contract_accept_"):
		var contract_id_text := action_id.substr("contract_accept_".length()).strip_edges()
		if contract_id_text.is_valid_int():
			var contract_controller := _contract_runtime_controller_node()
			if contract_controller != null:
				contract_controller.respond_to_offer(_runtime_snapshot_player_index(), int(contract_id_text), true)
			return true
	if action_id.begins_with("contract_reject_"):
		var contract_id_text := action_id.substr("contract_reject_".length()).strip_edges()
		if contract_id_text.is_valid_int():
			var contract_controller := _contract_runtime_controller_node()
			if contract_controller != null:
				contract_controller.respond_to_offer(_runtime_snapshot_player_index(), int(contract_id_text), false)
			return true
	if action_id.begins_with("monster_wager:"):
		var parts := action_id.split(":", false)
		if parts.size() >= 4 and String(parts[1]).is_valid_int() and String(parts[3]).is_valid_int():
			monster_runtime_controller._place_monster_wager_percent(int(parts[1]), String(parts[2]), int(parts[3]), _runtime_snapshot_player_index())
			return true
	return false


func _on_runtime_game_screen_end_turn_requested() -> void:
	_sync_runtime_game_screen(true)


func _on_runtime_game_screen_card_selected(card_data: Dictionary) -> void:
	selected_runtime_card_slot = -1
	var card_id := String(card_data.get("id", ""))
	if card_id.begins_with("hand_"):
		selected_runtime_card_slot = int(card_id.substr("hand_".length()))
	_sync_runtime_game_screen(true)


func _on_runtime_game_screen_card_drop_requested(card_data: Dictionary, screen_position: Vector2) -> void:
	var slot_index := _runtime_hand_slot_from_card_data(card_data)
	if slot_index < 0:
		return
	if not _runtime_drop_position_targets_map(screen_position):
		return
	selected_runtime_card_slot = slot_index
	_use_skill(slot_index)
	_sync_runtime_game_screen(true)


func _runtime_hand_slot_from_card_data(card_data: Dictionary) -> int:
	var card_id := String(card_data.get("id", ""))
	if card_id.begins_with("hand_"):
		return int(card_id.substr("hand_".length()))
	var actions: Array = card_data.get("actions", []) if card_data.get("actions", []) is Array else []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		var action_id := String(action.get("id", ""))
		if action_id.begins_with("play_") and not bool(action.get("disabled", false)):
			return int(action_id.substr("play_".length()))
	return -1


func _runtime_drop_position_targets_map(screen_position: Vector2) -> bool:
	if map_view == null or not (map_view is Control):
		return false
	var map_rect := map_view.get_global_rect()
	if not map_rect.has_point(screen_position):
		return false
	var local_position := screen_position - map_rect.position
	if map_view.has_method("get_district_at_control_position"):
		var district_index := int(map_view.call("get_district_at_control_position", local_position))
		if district_index < 0:
			return false
		_select_district(district_index)
	return true


func _activate_runtime_district_action(action_id: String) -> bool:
	var player_index := _runtime_snapshot_player_index()
	if player_index < 0:
		return false
	var action_index := int(action_id.substr("district_".length()))
	var entries := _selected_district_action_entries(player_index)
	if action_index < 0 or action_index >= entries.size():
		return false
	var entry: Dictionary = entries[action_index] if entries[action_index] is Dictionary else {}
	return _activate_runtime_snapshot_action(entry)


func _activate_runtime_quick_action(action_id: String) -> bool:
	var player_index := _runtime_snapshot_player_index()
	if player_index < 0:
		return false
	var entry := _runtime_quick_action_entry(player_index, action_id)
	if entry.is_empty() or not bool(entry.get("active", false)):
		return false
	match action_id:
		"rack", "buy":
			if selected_district < 0 or selected_district >= districts.size():
				return false
			_open_district_supply_from_map(selected_district)
			return true
		"play":
			var slot_index := _first_actionable_hand_slot(player_index)
			if slot_index < 0:
				return false
			selected_runtime_card_slot = slot_index
			_use_skill(slot_index)
			return true
	return false


func _runtime_quick_action_entry(player_index: int, action_id: String) -> Dictionary:
	for entry_variant in _runtime_player_board_quick_actions(player_index):
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if String(entry.get("id", "")) == action_id:
			return entry
	return {}


func _activate_runtime_snapshot_action(entry: Dictionary) -> bool:
	if entry.is_empty() or bool(entry.get("disabled", false)):
		return false
	var target: Callable = entry.get("target", Callable()) as Callable
	if not target.is_valid():
		return false
	target.call()
	return true


func _build_runtime_map_view() -> void:
	if map_view == null:
		map_view = _embedded_runtime_planet_map_view()
	if map_view == null:
		_report_required_ui_scene_missing("PlanetMapView", "district_selected/district_double_clicked")
		return
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var select_callback := Callable(self, "_select_district")
	if not map_view.district_selected.is_connected(select_callback):
		map_view.district_selected.connect(select_callback)
	var double_callback := Callable(self, "_open_district_supply_from_map")
	if not map_view.district_double_clicked.is_connected(double_callback):
		map_view.district_double_clicked.connect(double_callback)
	if runtime_game_screen != null and runtime_game_screen.has_method("attach_runtime_map"):
		runtime_game_screen.call("attach_runtime_map", map_view)
	else:
		_report_required_ui_scene_missing("RuntimeGameScreen", "attach_runtime_map")
	map_view.custom_minimum_size = Vector2(560, 430)


func _embedded_runtime_planet_map_view() -> Control:
	if runtime_game_screen != null and runtime_game_screen.has_method("get_embedded_map_view"):
		var embedded_variant: Variant = runtime_game_screen.call("get_embedded_map_view")
		if embedded_variant is Control:
			return embedded_variant as Control
	if runtime_game_screen != null:
		var found := runtime_game_screen.find_child("PlanetMapView", true, false) as Control
		if found != null:
			return found
	return null


func _build_layout() -> void:
	_bind_sceneized_runtime_composition()
	_build_runtime_game_screen()
	if runtime_game_screen == null:
		push_error("RuntimeGameScreen scene is required; legacy runtime table construction has been retired.")
		return
	_build_runtime_map_view()
	_bind_runtime_overlay_surfaces()
	_sync_runtime_game_screen(true)

func _bind_runtime_overlay_surfaces() -> void:
	_build_full_map_overlay()
	_build_card_resolution_overlay()
	_build_bottom_countdown_bar()
	_build_district_supply_overlay()
	_bind_menu_overlay_scene()


func _playtest_flow_compass_entries(player_index: int) -> Array:
	var has_selection := selected_district >= 0 and selected_district < districts.size()
	var progress := _first_run_coach_progress(player_index)
	if progress.is_empty():
		progress = _opening_guide_progress(player_index)
	var steps := [
		{"label": "点区", "done": has_selection, "accent": Color("#38bdf8"), "tip": "在中央星球点一个区域；双击可查看区域牌架。"},
		{"label": "建城", "done": bool(progress.get("has_city", false)), "accent": Color("#4ade80"), "tip": "在陆地城市化，开始获得实时GDP现金流。"},
		{"label": "买牌", "done": bool(progress.get("has_bought_card", false)), "accent": Color("#facc15"), "tip": "查看全局挂牌；来源区受光时锁定5秒报价。"},
		{"label": "出牌", "done": bool(progress.get("has_played_card", false)), "accent": Color("#c084fc"), "tip": "满足卡面GDP份额后出牌；需要目标的牌会先询问。"},
		{"label": "牌轨", "done": bool(progress.get("has_seen_public_track", false)), "accent": Color("#f59e0b"), "tip": "看顶部公共时间线，确认已打出的牌留下什么线索。"},
		{"label": "经济", "done": bool(progress.get("has_checked_economy", false)), "accent": Color("#38bdf8"), "tip": "打开经济总览，看GDP、商品和商路如何变成钱。"},
		{"label": "路线", "done": bool(progress.get("has_chosen_route", false)), "accent": Color("#22c55e"), "tip": "首局先选一条继续路线：扩GDP、护商路或压竞争。"},
	]
	var current_index := -1
	for i in range(steps.size()):
		var entry: Dictionary = steps[i]
		if not bool(entry.get("done", false)):
			current_index = i
			break
	if current_index < 0:
		current_index = steps.size() - 1
	for i in range(steps.size()):
		var entry: Dictionary = steps[i]
		entry["current"] = i == current_index and not bool(entry.get("done", false))
		steps[i] = entry
	return steps


func _playtest_flow_next_text(player_index: int) -> String:
	if players.is_empty():
		return "下一步：开局准备"
	if selected_district < 0 or selected_district >= districts.size():
		return "下一步：点星球区域"
	var progress := _first_run_coach_progress(player_index)
	if progress.is_empty():
		progress = _opening_guide_progress(player_index)
	if not bool(progress.get("has_city", false)):
		return "下一步：城市化"
	if not bool(progress.get("has_bought_card", false)):
		return "下一步：买第一牌"
	if not bool(progress.get("has_played_card", false)):
		return "下一步：打出手牌"
	if not bool(progress.get("has_seen_public_track", false)):
		return "下一步：看牌轨"
	if not bool(progress.get("has_checked_economy", false)):
		return "下一步：看经济"
	if not bool(progress.get("has_chosen_route", false)):
		return "下一步：选路线"
	return "下一步：看线索"


func _recent_table_event_clean_text(line: String) -> String:
	var text := line.strip_edges()
	if text.begins_with("["):
		var close_index := text.find("] ")
		if close_index >= 0:
			text = text.substr(close_index + 2).strip_edges()
	text = text.replace("\n", " ").replace("\t", " ")
	return text


func _recent_table_event_accent(text: String) -> Color:
	if text.contains("怪兽") or text.contains("伤害") or text.contains("赌局") or text.contains("摧毁"):
		return Color("#fb7185")
	if text.contains("城市") or text.contains("建城") or text.contains("城市化") or text.contains("GDP"):
		return Color("#4ade80")
	if text.contains("卡牌") or text.contains("匿名") or text.contains("出牌") or text.contains("牌"):
		return Color("#c084fc")
	if text.contains("现金") or text.contains("收入") or text.contains("¥"):
		return Color("#facc15")
	if text.contains("天气") or text.contains("预报") or text.contains("合约"):
		return Color("#38bdf8")
	return Color("#bfdbfe")


func _recent_table_event_entries() -> Array:
	var entries := []
	for i in range(log_lines.size() - 1, -1, -1):
		var raw := String(log_lines[i])
		var text := _recent_table_event_clean_text(raw)
		if text == "":
			continue
		var accent := _recent_table_event_accent(text)
		entries.append({
			"text": _short_card_text(text, 46),
			"accent": accent,
			"tooltip": raw,
		})
		if entries.size() >= 3:
			break
	if entries.is_empty():
		entries.append({
			"text": "等待开桌事件",
			"accent": Color("#94a3b8"),
			"tooltip": "建城、买牌、匿名出牌、怪兽行动和天气变化会在这里留下短提示。",
		})
	return entries


func _refresh_card_resolution_overlay_badges(entry: Dictionary) -> void:
	if card_resolution_badge_box == null:
		return
	_clear_children(card_resolution_badge_box)
	if entry.is_empty():
		card_resolution_badge_box.visible = false
		return
	card_resolution_badge_box.visible = true
	var coordinator := _game_runtime_coordinator_node()
	var badges: Array = coordinator.call("compose_game_resolution_overlay_badges", _runtime_card_resolution_overlay_badge_source(entry)) if coordinator != null and coordinator.has_method("compose_game_resolution_overlay_badges") else []
	for badge_variant in badges:
		var badge: Dictionary = badge_variant if badge_variant is Dictionary else {}
		card_resolution_badge_box.add_child(_track_status_badge(str(badge.get("text", "")), badge.get("text_color", Color("#c4b5fd")) as Color, badge.get("background_color", Color("#1e1b4b")) as Color))


func _runtime_card_resolution_overlay_badge_source(entry: Dictionary) -> Dictionary:
	var skill: Dictionary = entry.get("skill", {}) if entry.get("skill", {}) is Dictionary else {}
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	var active_entry := _card_resolution_active_entry()
	var active_id := int(active_entry.get("resolution_id", active_entry.get("queued_order", -1))) if not active_entry.is_empty() else -1
	var contract_controller := _contract_runtime_controller_node()
	var pending_contract := contract_controller.offer_by_id(int(entry.get("contract_offer_id", resolution_id))) if contract_controller != null else {}
	var public_entry := {
		"public_owner_revealed": bool(entry.get("public_owner_revealed", false)),
		"public_owner_label": str(entry.get("public_owner_label", "归属：已公开")),
		"is_viewer_card": selected_player >= 0 and selected_player < players.size() and int(entry.get("player_index", -1)) == selected_player,
		"priority_bid": int(float(int(entry.get("winning_priority_bid_cents", entry.get("priority_bid_cents", 0)))) / 100.0),
		"priority_bid_committed": int(entry.get("priority_bid_cents", 0)) > 0,
	}
	return {
		"entry": public_entry,
		"requirement_text": _card_resolution_play_requirement_text(entry),
		"is_contract": str(skill.get("kind", "")) == "area_trade_contract",
		"contract_state": "active" if active_id == resolution_id else ("pending" if not pending_contract.is_empty() else "result"),
		"contract_response_label": contract_controller.response_public_label(entry) if contract_controller != null else "无签约窗口",
		"tip_clue": _card_resolution_tip_clue_text(entry),
		"current_queue_count": _card_resolution_current_queue().size(),
		"next_queue_count": _card_resolution_next_queue().size(),
	}


func _card_resolution_play_requirement_text(entry: Dictionary) -> String:
	var stored_text := String(entry.get("play_requirement_text", ""))
	if stored_text != "":
		return stored_text
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	if skill.is_empty():
		return "条件：未知"
	var requirement := _card_play_requirement_snapshot(int(entry.get("player_index", -1)), skill)
	var required_percent := int(entry.get("play_requirement_gdp_share_percent", requirement.get("required_share_percent", 0)))
	var scope := String(entry.get("play_requirement_scope", requirement.get("scope", CardPlayRequirementPolicyScript.SCOPE_OWN_BEST_REGION)))
	var cash_cost := int(entry.get("play_cash_cost", requirement.get("cash_cost", 0)))
	var text := "条件：无"
	if required_percent > 0:
		text = "条件：%sGDP份额≥%d%%" % [CardPlayRequirementPolicyScript.scope_label(scope), required_percent]
	if cash_cost > 0:
		text += "｜费用¥%d" % cash_cost
	return text


func _track_status_badge(text: String, text_color: Color, bg_color: Color) -> PanelContainer:
	var badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = bg_color
	badge_style.border_color = text_color.lerp(bg_color, 0.35)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(6)
	badge.add_theme_stylebox_override("panel", badge_style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 2)
	badge.add_child(margin)
	var label := _plain_label(text, 10, text_color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	margin.add_child(label)
	return badge


func _select_card_resolution_track_entry(resolution_id: int) -> void:
	selected_card_resolution_id = -1 if selected_card_resolution_id == resolution_id else resolution_id
	if selected_card_resolution_id >= 0:
		_focus_card_resolution_target_region(selected_card_resolution_id)
		_complete_scenario_signal("track_selected", "选中公开牌轨上的匿名牌。", "after_track", "public_track")
	_sync_runtime_game_screen(true)


func _focus_card_resolution_track_entry(resolution_id: int) -> void:
	selected_card_resolution_id = resolution_id
	_focus_card_resolution_target_region(resolution_id)
	_sync_runtime_game_screen(true)


func _focus_card_resolution_target_region(resolution_id: int) -> bool:
	var entry := _card_resolution_entry_by_id(resolution_id)
	var district_index := _card_resolution_public_target_district(entry)
	if district_index < 0:
		return false
	return _jump_to_district_on_table(district_index, false)


func _card_resolution_public_target_district(entry: Dictionary) -> int:
	if entry.is_empty():
		return -1
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	if String(skill.get("kind", "")) == "area_trade_contract":
		var contract_target := int(entry.get("contract_target_district", -1))
		if contract_target >= 0 and contract_target < districts.size():
			return contract_target
		var contract_source := int(entry.get("contract_source_district", -1))
		if contract_source >= 0 and contract_source < districts.size():
			return contract_source
	var selected_index := int(entry.get("selected_district", -1))
	if selected_index >= 0 and selected_index < districts.size():
		return selected_index
	var target_slot := int(entry.get("target_slot", -1))
	if target_slot >= 0 and target_slot < monster_runtime_controller.auto_monsters.size():
		var actor: Dictionary = monster_runtime_controller.auto_monsters[target_slot]
		var actor_district := int(actor.get("position", -1))
		if actor_district >= 0 and actor_district < districts.size():
			return actor_district
		var world_position: Variant = actor.get("world_position", Vector2.ZERO)
		if world_position is Vector2:
			var nearest := _nearest_district_to(world_position)
			if nearest >= 0 and nearest < districts.size():
				return nearest
	var fallback_contract_target := int(entry.get("contract_target_district", -1))
	if fallback_contract_target >= 0 and fallback_contract_target < districts.size():
		return fallback_contract_target
	var fallback_contract_source := int(entry.get("contract_source_district", -1))
	if fallback_contract_source >= 0 and fallback_contract_source < districts.size():
		return fallback_contract_source
	return -1


func _card_resolution_entry_by_id(resolution_id: int) -> Dictionary:
	var service := _card_resolution_queue_service_node()
	if service != null and service.has_method("entry_by_id"):
		var queued_variant: Variant = service.call("entry_by_id", resolution_id)
		if queued_variant is Dictionary and not (queued_variant as Dictionary).is_empty():
			return (queued_variant as Dictionary).duplicate(true)
	for entry_variant in resolved_card_history:
		if entry_variant is Dictionary:
			var resolved_entry := entry_variant as Dictionary
			if int(resolved_entry.get("resolution_id", resolved_entry.get("queued_order", -1))) == resolution_id:
				return resolved_entry.duplicate(true)
	return {}


func _store_card_resolution_entry(entry: Dictionary) -> bool:
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	if resolution_id < 0:
		return false
	var service := _card_resolution_queue_service_node()
	if service != null and service.has_method("store_entry") and bool(service.call("store_entry", entry.duplicate(true))):
		return true
	for i in range(resolved_card_history.size()):
		var resolved: Dictionary = resolved_card_history[i]
		if int(resolved.get("resolution_id", resolved.get("queued_order", -1))) == resolution_id:
			resolved_card_history[i] = entry.duplicate(true)
			return true
	return false


func _card_owner_guess_stake_for_player(viewer_index: int) -> int:
	if viewer_index < 0 or viewer_index >= players.size():
		return CARD_OWNER_GUESS_STAKE
	var role := _player_role_card_for_index(viewer_index)
	var discount := maxi(0, int(role.get("card_owner_guess_discount", 0)))
	return maxi(20, CARD_OWNER_GUESS_STAKE - discount)


func _card_owner_guess_payout_for_player(viewer_index: int) -> int:
	if viewer_index < 0 or viewer_index >= players.size():
		return CARD_OWNER_GUESS_STAKE
	var role := _player_role_card_for_index(viewer_index)
	return CARD_OWNER_GUESS_STAKE + maxi(0, int(role.get("card_owner_guess_bonus", 0)))


func _guess_card_resolution_owner_for_player(viewer_index: int, resolution_id: int, guessed_player: int, announce: bool = true) -> bool:
	if _runtime_session_finished() or viewer_index < 0 or viewer_index >= players.size() or guessed_player < 0 or guessed_player >= players.size():
		return false
	var entry := _card_resolution_entry_by_id(resolution_id)
	if entry.is_empty() or bool(entry.get("public_owner_revealed", false)):
		return false
	var actual_owner := int(entry.get("player_index", -1))
	if actual_owner < 0 or actual_owner >= players.size():
		return false
	if viewer_index == actual_owner:
		if announce:
			_log("你不能竞猜自己打出的匿名卡牌。")
		return false
	var guessers: Array = (entry.get("guessers", []) as Array).duplicate()
	if guessers.has(viewer_index):
		if announce:
			_log("当前玩家已经竞猜过这张牌；每人每张牌只有一次机会。")
		return false
	var stake := _card_owner_guess_stake_for_player(viewer_index)
	if int((players[viewer_index] as Dictionary).get("cash", 0)) < stake:
		if announce:
			_log("当前视角至少需要¥%d才能进行卡牌归属竞猜。" % stake)
		return false
	guessers.append(viewer_index)
	entry["guessers"] = guessers
	if guessed_player == actual_owner:
		var payout := _card_owner_guess_payout_for_player(viewer_index)
		players[actual_owner]["cash"] = int(players[actual_owner].get("cash", 0)) - payout
		players[viewer_index]["cash"] = int(players[viewer_index].get("cash", 0)) + payout
		players[actual_owner]["total_card_spend"] = int(players[actual_owner].get("total_card_spend", 0)) + payout
		players[viewer_index]["total_card_income"] = int(players[viewer_index].get("total_card_income", 0)) + payout
		_record_player_economic_event(actual_owner, "归属竞猜", "身份被识破", -payout, "一张匿名卡牌的归属被猜中。")
		_record_player_economic_event(viewer_index, "归属竞猜", "命中归属", payout, "正确猜中玩家%d打出的卡牌。" % (actual_owner + 1))
		_record_player_cash_snapshot(actual_owner)
		_record_player_cash_snapshot(viewer_index)
		entry["public_owner_revealed"] = true
		entry["public_owner_label"] = "归属：玩家%d" % (actual_owner + 1)
		entry["owner_revealed_time"] = game_time
		if announce:
			_log("归属竞猜命中：这张牌公开贴上“玩家%d”标签；竞猜者获得¥%d，双方当前资金仍不公开。" % [actual_owner + 1, payout])
	else:
		players[viewer_index]["cash"] = int(players[viewer_index].get("cash", 0)) - stake
		players[actual_owner]["cash"] = int(players[actual_owner].get("cash", 0)) + stake
		players[viewer_index]["total_card_spend"] = int(players[viewer_index].get("total_card_spend", 0)) + stake
		players[actual_owner]["total_card_income"] = int(players[actual_owner].get("total_card_income", 0)) + stake
		_record_player_economic_event(viewer_index, "归属竞猜", "猜错归属", -stake, "错误竞猜被私下结算；真实归属仍隐藏。")
		_record_player_economic_event(actual_owner, "归属竞猜", "匿名竞猜收入", stake, "有人猜错了你打出的卡牌；竞猜者不公开。")
		_record_player_cash_snapshot(viewer_index)
		_record_player_cash_snapshot(actual_owner)
		if announce:
			_log("一次匿名归属竞猜失败并私下结算¥%d；真实出牌者仍未揭晓。" % stake)
	_store_card_resolution_entry(entry)
	if not _card_resolution_active_entry().is_empty():
		_show_card_resolution_overlay(_card_resolution_active_entry(), card_resolution_timer)
	_refresh_ui()
	return true


func _build_full_map_overlay() -> void:
	if full_map_overlay != null and is_instance_valid(full_map_overlay):
		return
	var overlay := _runtime_composition_control("FullscreenMapOverlay")
	if overlay == null:
		_report_required_ui_scene_missing("FullscreenMapOverlay", "static OverlayLayer composition")
		return
	full_map_overlay = overlay

	var map_control_toolbar := overlay.find_child("PlanetMapControlToolbar", true, false) as Control
	if map_control_toolbar == null or not map_control_toolbar.has_method("set_controls"):
		_report_required_ui_scene_missing("PlanetMapControlToolbar", "set_controls")
	else:
		var control_callback := Callable(self, "_on_map_control_toolbar_action_requested")
		if map_control_toolbar.has_signal("control_action_requested") and not map_control_toolbar.is_connected("control_action_requested", control_callback):
			map_control_toolbar.connect("control_action_requested", control_callback)
	var close_button := overlay.find_child("FullscreenMapCloseButton", true, false) as Button
	var close_callable := Callable(self, "_close_fullscreen_map")
	if close_button != null and not close_button.pressed.is_connected(close_callable):
		close_button.pressed.connect(close_callable)

	fullscreen_map_hud_labels = {
		"layer": overlay.find_child("FullscreenMapLayerHudLabel", true, false) as Label,
		"product": overlay.find_child("FullscreenMapProductHudLabel", true, false) as Label,
		"district": overlay.find_child("FullscreenMapDistrictHudLabel", true, false) as Label,
		"hint": overlay.find_child("FullscreenMapHintHudLabel", true, false) as Label,
	}

	full_map_view = overlay.find_child("FullscreenPlanetMapView", true, false) as Control
	if full_map_view == null:
		_report_required_ui_scene_missing("FullscreenPlanetMapView", "district_selected/district_double_clicked")
		return
	full_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	full_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var select_callback := Callable(self, "_select_district")
	if full_map_view.has_signal("district_selected") and not full_map_view.is_connected("district_selected", select_callback):
		full_map_view.connect("district_selected", select_callback)
	var double_callback := Callable(self, "_open_district_supply_from_map")
	if full_map_view.has_signal("district_double_clicked") and not full_map_view.is_connected("district_double_clicked", double_callback):
		full_map_view.connect("district_double_clicked", double_callback)
func _build_card_resolution_overlay() -> void:
	if card_resolution_overlay != null and is_instance_valid(card_resolution_overlay):
		return
	var overlay := _runtime_composition_control("CardResolutionTableBannerOverlay")
	if overlay == null:
		_report_required_ui_scene_missing("CardResolutionTableBannerOverlay", "static OverlayLayer composition")
		return
	card_resolution_overlay = overlay
	card_resolution_title_label = overlay.find_child("CardResolutionTitleLabel", true, false) as Label
	card_resolution_status_label = overlay.find_child("CardResolutionStatusLabel", true, false) as Label
	card_resolution_badge_box = overlay.find_child("CardResolutionBadgeBox", true, false) as HBoxContainer
	card_resolution_art = overlay.find_child("CardResolutionArt", true, false) as Control
	card_resolution_body_label = overlay.find_child("CardResolutionBodyLabel", true, false) as Label


func _build_bottom_countdown_bar() -> void:
	if bottom_countdown_overlay != null and is_instance_valid(bottom_countdown_overlay):
		return
	var overlay := _runtime_composition_control("BottomCountdownOverlay")
	if overlay == null:
		_report_required_ui_scene_missing("BottomCountdownOverlay", "static OverlayLayer composition")
		return
	bottom_countdown_overlay = overlay
	bottom_countdown_panel = overlay.find_child("BottomCountdownPanel", true, false) as PanelContainer
	card_resolution_timer_label = overlay.find_child("CardResolutionRevealTimerLabel", true, false) as Label
	card_resolution_timer_bar = overlay.find_child("CardResolutionRevealTimerBar", true, false) as ProgressBar


func _build_district_supply_overlay() -> void:
	if district_supply_overlay != null and is_instance_valid(district_supply_overlay):
		return
	var overlay := _runtime_composition_control("DistrictSupplySideDrawerOverlay")
	if overlay == null:
		_report_required_ui_scene_missing("DistrictSupplySideDrawerOverlay", "static OverlayLayer composition")
		return
	district_supply_overlay = overlay
	if not overlay.has_method("set_supply") or not overlay.has_method("clear_supply") or not overlay.has_method("debug_snapshot") or not overlay.has_signal("supply_action_requested"):
		push_error("DistrictSupplyDrawer must expose its scene-owned snapshot and action API.")
		return
	var action_callable := Callable(self, "_on_district_supply_action_requested")
	if not overlay.is_connected("supply_action_requested", action_callable):
		overlay.connect("supply_action_requested", action_callable)


func _map_layer_focus_entries() -> Array:
	return [
		{"id": "all", "label": "全", "text": "全图", "accent": "#fef3c7", "tip": "显示全部公开地图信息。"},
		{"id": "product", "label": "◇", "text": "商品", "accent": "#4ade80", "tip": "商品/供需读图：看区域产需、牌架和当前商品线索。"},
		{"id": "route", "label": "⇄", "text": "商路", "accent": "#f59e0b", "tip": "商路读图：突出当前商品的运输路径和路线节点。"},
		{"id": "intel", "label": "?", "text": "情报", "accent": "#60a5fa", "tip": "情报读图：突出城市归属猜测和公开线索，不显示隐藏真相。"},
		{"id": "weather", "label": "☄", "text": "天气", "accent": "#38bdf8", "tip": "天气读图：突出预报/天气/区域效果，便于提前决策。"},
		{"id": "monster", "label": "◆", "text": "怪兽", "accent": "#fb7185", "tip": "怪兽读图：突出怪兽、移动轨迹、战斗和破坏演出。"},
		{"id": "city", "label": "▣", "text": "城市", "accent": "#c084fc", "tip": "城市读图：突出城市、GDP风险和建设/破坏状态。"},
	]


func _map_layer_entry(layer_id: String) -> Dictionary:
	for entry_variant in _map_layer_focus_entries():
		var entry := entry_variant as Dictionary
		if String(entry.get("id", "")) == layer_id:
			return entry
	return (_map_layer_focus_entries()[0] as Dictionary).duplicate(true)


func _map_layer_focus_label(layer_id: String) -> String:
	return String(_map_layer_entry(layer_id).get("text", "全图"))


func _set_map_layer_focus(layer_id: String) -> void:
	selected_map_layer_focus = String(_map_layer_entry(layer_id).get("id", "all"))
	if selected_map_layer_focus == "route" and selected_trade_product == "":
		selected_trade_product = _default_trade_product_for_selected_district()
		if selected_trade_product == "" and not ProductMarketRuntimeController.PRODUCT_CATALOG.is_empty():
			selected_trade_product = String(ProductMarketRuntimeController.PRODUCT_CATALOG[0])
	_log("地图图层切换：%s。" % _map_layer_focus_label(selected_map_layer_focus))
	_refresh_map_controls()
	_refresh_board()


func _map_control_toolbar_snapshot() -> Dictionary:
	var contract_controller := _contract_runtime_controller_node()
	var contract_selection := contract_controller.selection_snapshot() if contract_controller != null else {"source_district": -1, "target_district": -1}
	var contract_source := int(contract_selection.get("source_district", -1))
	var contract_target := int(contract_selection.get("target_district", -1))
	var district_status := _selected_district_status_text(selected_player) if selected_district >= 0 and selected_district < districts.size() else "当前未选择区域。"
	var product_options: Array = [{"id": "", "label": "商路关闭", "disabled": false}]
	for product_variant: Variant in ProductMarketRuntimeController.PRODUCT_CATALOG:
		var product_id := str(product_variant)
		product_options.append({"id": product_id, "label": product_id, "disabled": false})
	var trade_text := "⇄ 商路关"
	var trade_tooltip := "当前地图不显示商品运输路径。"
	if selected_trade_product != "":
		var route_count := _route_network_routes_for_product(selected_trade_product).size()
		trade_text = "⇄ %s｜%d" % [_short_card_text(selected_trade_product, 6), route_count]
		trade_tooltip = "当前显示%s的运输路径，共%d条。" % [selected_trade_product, route_count]
	var selected_layer := _map_layer_entry(selected_map_layer_focus)
	var can_set_contract_source := contract_controller != null and contract_controller.valid_source_district(selected_district)
	var can_set_contract_target := contract_controller != null and contract_controller.valid_target_district(selected_district)
	var contract_summary := contract_controller.selection_summary(selected_trade_product, _default_trade_product_for_selected_district()) if contract_controller != null else "合约运行时不可用"
	return {
		"reading_hints": [
			{"text": "◎ 赌桌中央", "tooltip": "星球保持主视野；信息尽量收进筹码、牌架和侧栏。"},
			{"text": "滚轮缩放", "tooltip": "滚轮拉近看局部地表，拉远看星球。"},
			{"text": "拖拽地图", "tooltip": "拖拽平移地表或调整星球视角。"},
			{"text": "双击看牌", "tooltip": "双击区域打开牌架；查看始终允许，显式选择后才锁定5秒日照资格与价格。"},
		],
		"district_status": {"text": "⌖ %s" % _short_card_text(district_status, 18), "tooltip": district_status},
		"layers": _map_layer_focus_entries(),
		"selected_layer_id": selected_map_layer_focus,
		"layer_status": {"text": "图层:%s" % _map_layer_focus_label(selected_map_layer_focus), "tooltip": str(selected_layer.get("tip", "当前地图图层焦点。"))},
		"trade": {
			"options": product_options,
			"selected_product_id": selected_trade_product,
			"disabled": false,
			"tooltip": "选择要在地图上显示运输路径的商品。",
			"status": {"text": trade_text, "tooltip": trade_tooltip},
		},
		"contract_source": {
			"text": "供给:%s" % ("选区" if contract_source != selected_district else "已设"),
			"disabled": not can_set_contract_source,
			"tooltip": "打出合约牌前必须先点：把当前选中陆地区域设为下一张合约的供给区。" if can_set_contract_source else "供给区必须是未毁陆地区域；合约牌打出前需要先点供给区。",
		},
		"contract_target": {
			"text": "需求:%s" % ("选区" if contract_target != selected_district else "已设"),
			"disabled": not can_set_contract_target,
			"tooltip": "打出合约牌前必须先点：把当前存活城市群设为下一张合约的需求/签约区。" if can_set_contract_target else "需求区必须有存活城市群；合约牌打出前需要先点需求区。",
		},
		"contract_status": {"text": "⇄ %s" % _short_card_text(contract_summary.replace("合约:", "").replace("合约：", ""), 12), "tooltip": contract_summary},
	}


func _on_map_control_toolbar_action_requested(action_id: String, payload: Dictionary) -> void:
	match action_id:
		"map_layer_focus":
			_set_map_layer_focus(str(payload.get("layer_id", "all")))
		"map_trade_product_select":
			var product_id := str(payload.get("product_id", ""))
			if product_id != "" and not ProductMarketRuntimeController.PRODUCT_CATALOG.has(product_id):
				return
			selected_trade_product = product_id
			_refresh_board()
			_refresh_map_controls()
		"map_contract_source_select":
			var contract_controller := _contract_runtime_controller_node()
			if contract_controller != null:
				var result := contract_controller.select_source_district(selected_district, selected_trade_product)
				if bool(result.get("accepted", false)):
					selected_trade_product = str(result.get("selected_product", selected_trade_product))
				_log(str(result.get("message", "供给区选择失败。")))
				_refresh_ui()
		"map_contract_target_select":
			var contract_controller := _contract_runtime_controller_node()
			if contract_controller != null:
				var result := contract_controller.select_target_district(selected_district, selected_trade_product)
				if bool(result.get("accepted", false)):
					selected_trade_product = str(result.get("selected_product", selected_trade_product))
				_log(str(result.get("message", "需求区选择失败。")))
				_refresh_ui()


func _bind_menu_overlay_scene() -> void:
	if menu_overlay != null and is_instance_valid(menu_overlay):
		return
	var overlay := _runtime_composition_control("MenuModalOverlay")
	if overlay == null:
		push_error("MenuModalOverlay is required in OverlayLayer; runtime menu construction has been retired.")
		return
	for method_name in ["present_menu_shell", "present_codex_page", "clear_preview", "get_preview_host", "get_codex_surface", "set_global_navigation", "refresh_current_layout"]:
		if not overlay.has_method(method_name):
			push_error("MenuModalOverlay must expose %s; refusing to rebuild the menu shell in main.gd." % method_name)
			return
	menu_overlay = overlay
	menu_preview_box = menu_overlay.call("get_preview_host") as VBoxContainer
	if menu_preview_box == null:
		push_error("MenuModalOverlay must expose its scene-owned preview host.")
		menu_overlay = null
		return
	var signal_routes := {
		"continue_requested": Callable(self, "_close_menu"),
		"main_menu_requested": Callable(self, "_open_main_menu"),
		"catalog_step_requested": Callable(self, "_cycle_menu_catalog"),
		"catalog_back_requested": Callable(self, "_back_from_catalog_menu"),
		"quick_nav_action_requested": Callable(self, "_on_menu_quick_nav_action_requested"),
		"codex_action_requested": Callable(self, "_on_codex_surface_action_requested"),
	}
	for signal_name_variant: Variant in signal_routes:
		var signal_name := str(signal_name_variant)
		var callback := signal_routes[signal_name] as Callable
		if not menu_overlay.has_signal(signal_name):
			push_error("MenuModalOverlay is missing required signal %s." % signal_name)
			continue
		if not menu_overlay.is_connected(signal_name, callback):
			menu_overlay.connect(signal_name, callback)
	menu_regular_buttons = []
	_refresh_menu_layout()

func _menu_card_style(accent: Color, fill: Color = Color("#0b1220"), border_width: int = 1, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _menu_viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(960, 640)


func _menu_available_content_width() -> float:
	if menu_overlay != null and menu_overlay.has_method("available_content_width"):
		return float(menu_overlay.call("available_content_width", _menu_viewport_size()))
	return 260.0


func _menu_available_content_height() -> float:
	if menu_overlay != null and menu_overlay.has_method("available_content_height"):
		return float(menu_overlay.call("available_content_height", _menu_viewport_size()))
	return 260.0


func _refresh_menu_layout() -> void:
	if menu_overlay != null and menu_overlay.has_method("refresh_current_layout"):
		menu_overlay.call("refresh_current_layout", _menu_viewport_size())


func _menu_quick_nav_entries() -> Array:
	return [
		{"id": "setup", "label": "开局", "tooltip": "进入开局配置：设置席位、电脑对手、角色和起始怪兽。", "accent": "#38bdf8"},
		{"id": "scenario", "label": "剧本", "tooltip": "进入固定试玩剧本：练核心系统、看日志、做复盘。", "accent": "#facc15"},
		{"id": "standings", "label": "局势", "tooltip": "查看动态区域控制、前K区商品GDP、资格进度和公开审计。", "accent": "#facc15"},
		{"id": "economy", "label": "经济", "tooltip": "查看GDP、商品、商路、天气和收入拆解。", "accent": "#4ade80"},
		{"id": "intel", "label": "情报", "tooltip": "整理城市归属推理、卡牌竞猜和怪兽资金线索。", "accent": "#c084fc"},
		{"id": "rules", "label": "规则", "tooltip": "查看购牌、出牌、竞价、合约、怪兽赌局、天气和终局规则。", "accent": "#93c5fd"},
		{"id": "compendium", "label": "图鉴", "tooltip": "进入角色、怪兽、卡牌、商品和区域图鉴。", "accent": "#f472b6"},
	]


func _menu_quick_nav_active_key(title_text: String) -> String:
	match title_text:
		"开局准备":
			return "setup"
		"试玩剧本", "试玩剧本辅助", "剧本行动日志", "剧本复盘":
			return "scenario"
		"局势排名", "终局结算":
			return "standings"
		"经济总览":
			return "economy"
		"情报档案":
			return "intel"
		"游戏规则", "新手引导":
			return "rules"
		"图鉴", "角色图鉴", "怪兽生态档案", "卡牌图鉴", "商品图鉴", "区域图鉴":
			return "compendium"
	return ""


func _menu_quick_nav_visible(title_text: String, _show_main_actions: bool, compact_page: bool = false) -> bool:
	return not compact_page and title_text not in ["太空辛迪加｜星球赌桌", "暂停菜单"]


func _on_menu_quick_nav_action_requested(action_id: String) -> void:
	match action_id:
		"setup":
			_start_new_run_from_menu()
		"scenario":
			_open_scenario_browser_menu()
		"standings":
			_open_standings_menu()
		"economy":
			_open_economy_overview_menu()
		"intel":
			_open_intel_dossier_menu()
		"rules":
			_open_rules_menu()
		"compendium":
			_open_compendium_menu()


func _menu_summary_grid_columns() -> int:
	return clampi(int(floor(_menu_available_content_width() / 280.0)), 1, 4)


func _show_menu_summary_cards(cards: Array, heading: String = "页面速览") -> void:
	if menu_preview_box == null:
		return
	menu_overlay.call("clear_preview")
	menu_preview_box.visible = true
	var heading_label := _plain_label(heading, 13, Color("#dbeafe"))
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_preview_box.add_child(heading_label)
	var grid := GridContainer.new()
	grid.columns = _menu_summary_grid_columns()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	menu_preview_box.add_child(grid)
	for card_variant in cards:
		if card_variant is Dictionary:
			var card: Dictionary = card_variant
			_add_menu_info_card(
				grid,
				String(card.get("title", "提示")),
				String(card.get("body", "")),
				card.get("accent", Color("#38bdf8")) as Color,
				String(card.get("meta", ""))
			)


func _report_required_ui_scene_missing(component_name: String, required_method: String) -> void:
	push_error("%s is a required scenes/ui component and must expose %s; refusing to rebuild this player-facing page through legacy main.gd controls." % [component_name, required_method])


func _add_menu_info_card(parent: Container, title_text: String, body_text: String, accent: Color = Color("#38bdf8"), meta_text: String = "") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 112)
	panel.tooltip_text = body_text
	panel.add_theme_stylebox_override("panel", _menu_card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 14))
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	var title := _plain_label(title_text, 12, Color("#f8fafc"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var body := _plain_label(body_text, 10, Color("#cbd5e1"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	if meta_text != "":
		var meta := _plain_label(meta_text, 9, accent.lightened(0.18))
		meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(meta)
	return panel


func _open_main_menu() -> void:
	_show_menu(
		"太空辛迪加｜星球赌桌",
		"秘密建城 · 匿名出牌 · 怪兽赌局\n控制区域，推进GDP，接受公开审计。",
		not players.is_empty() and not _runtime_session_finished(),
		true
	)
	_populate_main_menu_summary_cards()


func _open_pause_menu() -> void:
	_show_menu(
		"暂停菜单",
		"游戏已暂停。继续游戏，或查看局势、经济、情报、图鉴和规则。",
		not _runtime_session_finished(),
		true
	)
	_populate_pause_menu_summary_cards()


func _populate_main_menu_summary_cards() -> void:
	if menu_preview_box == null:
		return
	menu_overlay.call("clear_preview")
	menu_preview_box.visible = true
	_add_main_menu_planet_lobby_panel(menu_preview_box)
	_refresh_run_save_menu_state()


func _main_menu_root_lobby_snapshot() -> Dictionary:
	var can_continue := not players.is_empty() and not _runtime_session_finished()
	return {
		"accent": Color("#f59e0b"),
		"tooltip": "星球赌桌大厅：保存、开局、继续和资料库入口。",
		"title": "SPACE SYNDICATE",
		"title_tooltip": "主菜单保留战役、快速开局和资料库三个主方向。",
		"status": "星球赌桌｜控区、GDP与公开审计",
		"status_tooltip": "终局按现金排名。",
		"planet_mark": "◎",
		"planet_title": "星球赌桌大厅",
		"planet_hint": "建城｜怪兽｜下注｜推理",
		"chip_rail_tooltip": "首屏只保留开桌前必须知道的桌面身份。",
		"table_line": "选择你的下一步",
		"table_tooltip": "主菜单只负责新手战役、快速开局、资料库和少量辅助入口。",
		"columns": 1,
		"chips": [
			{"text": "席位 3-8｜真人对 AI", "accent": Color("#bfdbfe"), "tooltip": "真人玩家对2-7个电脑对手。"},
			{"text": "开局 怪兽｜先压上桌", "accent": Color("#fda4af"), "tooltip": "新局在开局准备里选择起始怪兽。"},
			{"text": "牌轨 匿名｜亮牌不亮人", "accent": Color("#c084fc"), "tooltip": "出牌公开，牌主隐藏。"},
		],
		"actions": [
			{
				"id": "new_run",
				"kicker": "01｜开桌",
				"label": "开始新局",
				"detail": "先设置席位、AI、角色与起始怪兽牌",
				"accent": Color("#22c55e"),
				"featured": true,
			},
			{
				"id": "campaign",
				"kicker": "02｜战役",
				"label": "新手战役",
				"detail": "目标、奖励、复盘、下一关",
				"accent": Color("#facc15"),
			},
			{
				"id": "quick_start",
				"kicker": "03｜快局",
				"label": "快速开局",
				"detail": "推荐配置直接开桌",
				"accent": Color("#38bdf8"),
			},
			{
				"id": "compendium",
				"kicker": "04｜资料",
				"label": "资料库",
				"detail": "图鉴、卡牌、商品、区域",
				"accent": Color("#f472b6"),
			},
		],
		"utilities": [
			{
				"id": "continue",
				"label": "继续牌桌" if can_continue else "暂无牌桌",
				"tooltip": "回到当前星球" if can_continue else "先开新一桌。",
				"accent": Color("#22c55e"),
				"disabled": not can_continue,
			},
			{"id": "first_mission", "label": "开始首局任务", "accent": Color("#38bdf8"), "tooltip": "使用推荐首局设置并进入 first_table 教学任务。"},
			{"id": "scenario_lab", "label": "剧本库", "accent": Color("#facc15")},
			{"id": "rules", "label": "游戏规则", "accent": Color("#93c5fd")},
			{"id": "campaign_settings", "label": "设置", "accent": Color("#a78bfa")},
			{"id": "load_run", "label": "读取局面", "accent": Color("#94a3b8")},
			{"id": "quit", "label": "退出游戏", "accent": Color("#fb7185")},
		],
	}


func _on_menu_root_lobby_action_requested(action_id: String) -> void:
	match action_id:
		"campaign":
			_open_campaign_menu()
		"quick_start":
			_start_recommended_quick_run("stable_economy")
		"first_mission":
			start_first_mission_runtime()
		"new_run":
			_start_new_run_from_menu()
		"scenario_lab":
			_open_scenario_browser_menu()
		"continue":
			_close_menu()
		"compendium":
			_open_compendium_menu()
		"rules":
			_open_rules_menu()
		"campaign_settings":
			_open_campaign_settings_menu()
		"load_run":
			_load_run_from_menu()
		"quit":
			_quit_game()


func _add_main_menu_planet_lobby_panel(parent: Container) -> void:
	var lobby := MenuRootLobbyScene.instantiate() as Control
	if lobby == null:
		return
	if lobby.has_signal("action_requested"):
		lobby.connect("action_requested", Callable(self, "_on_menu_root_lobby_action_requested"))
	parent.add_child(lobby)
	if lobby.has_method("set_lobby"):
		lobby.call("set_lobby", _main_menu_root_lobby_snapshot())
	if lobby.has_method("get_load_run_button"):
		var load_button_variant: Variant = lobby.call("get_load_run_button")
		if load_button_variant is Button:
			menu_load_run_button = load_button_variant as Button


func _campaign_definition() -> Dictionary:
	var campaign: Dictionary = CampaignDefinitionScript.new().load_by_id(active_campaign_id)
	return campaign


func _campaign_chapter_by_id(chapter_id: String) -> Dictionary:
	var campaign := _campaign_definition()
	var chapters: Array = campaign.get("chapters", []) if campaign.get("chapters", []) is Array else []
	for chapter_variant in chapters:
		if chapter_variant is Dictionary and str((chapter_variant as Dictionary).get("id", "")) == chapter_id:
			return (chapter_variant as Dictionary).duplicate(true)
	return {}


func _campaign_progress_dictionary(selected_id: String = "") -> Dictionary:
	var campaign := _campaign_definition()
	return CampaignProgressScript.new().apply_state(campaign, campaign_completed_chapter_ids, selected_id if selected_id != "" else selected_campaign_chapter_id).to_dictionary()


func _load_campaign_progress_state() -> void:
	var saved: Dictionary = CampaignSaveScript.new().load_progress()
	if saved.is_empty():
		campaign_completed_chapter_ids = []
		selected_campaign_chapter_id = ""
		return
	active_campaign_id = str(saved.get("campaign_id", "tutorial_campaign"))
	campaign_completed_chapter_ids = (saved.get("completed_chapter_ids", []) as Array).duplicate(true) if saved.get("completed_chapter_ids", []) is Array else []
	selected_campaign_chapter_id = str(saved.get("selected_chapter_id", ""))


func _save_campaign_progress_state() -> void:
	var progress := _campaign_progress_dictionary(selected_campaign_chapter_id)
	CampaignSaveScript.new().save_progress({
		"campaign_id": active_campaign_id,
		"completed_chapter_ids": campaign_completed_chapter_ids.duplicate(true),
		"unlocked_chapter_ids": (progress.get("unlocked_chapter_ids", []) as Array).duplicate(true) if progress.get("unlocked_chapter_ids", []) is Array else [],
		"selected_chapter_id": selected_campaign_chapter_id,
		"last_completed_chapter_id": active_campaign_chapter_id,
	})


func _open_campaign_menu() -> void:
	_show_menu("新手战役", "先打一桌：点区、看受光牌架、用发展牌建立商品项目；召唤怪兽可随时进行。", not _runtime_session_finished(), false, true)
	if menu_preview_box == null:
		return
	menu_overlay.call("clear_preview")
	menu_preview_box.visible = true
	_add_campaign_menu_panel(menu_preview_box)


func _add_campaign_menu_panel(parent: Container) -> void:
	var panel := CampaignMenuScene.instantiate() as Control
	if panel == null:
		return
	if panel.has_signal("action_requested"):
		panel.connect("action_requested", Callable(self, "_on_campaign_action_requested"))
	parent.add_child(panel)
	if panel.has_method("set_campaign_menu"):
		panel.call("set_campaign_menu", _campaign_menu_snapshot())


func _campaign_menu_snapshot() -> Dictionary:
	var campaign := _campaign_definition()
	var progress := _campaign_progress_dictionary()
	var recommendations: Dictionary = RecommendedStartServiceScript.new().load_recommendations()
	return CampaignMenuSnapshotScript.new().apply_dictionary({
		"campaign": campaign,
		"progress": progress,
		"recommendations": recommendations,
	}).to_ui_dictionary()


func _open_campaign_briefing_menu(chapter_id: String = "") -> void:
	var progress := _campaign_progress_dictionary(chapter_id)
	var resolved_id := chapter_id.strip_edges()
	if resolved_id == "":
		resolved_id = str(progress.get("current_chapter_id", progress.get("next_chapter_id", "")))
	var unlocked: Array = progress.get("unlocked_chapter_ids", []) if progress.get("unlocked_chapter_ids", []) is Array else []
	if resolved_id == "" or not unlocked.has(resolved_id):
		_log("战役关卡尚未解锁：%s。" % resolved_id)
		_open_campaign_menu()
		return
	selected_campaign_chapter_id = resolved_id
	_save_campaign_progress_state()
	_show_menu("关卡说明", "读完目标后开始。本页只显示本关需要的信息。", not _runtime_session_finished(), false)
	if menu_preview_box == null:
		return
	menu_overlay.call("clear_preview")
	menu_preview_box.visible = true
	var map_panel := CampaignProgressMapScene.instantiate() as Control
	if map_panel != null:
		if map_panel.has_signal("action_requested"):
			map_panel.connect("action_requested", Callable(self, "_on_campaign_action_requested"))
		menu_preview_box.add_child(map_panel)
		if map_panel.has_method("set_progress_map"):
			map_panel.call("set_progress_map", CampaignProgressMapSnapshotScript.new().apply_dictionary({"progress": progress}).to_ui_dictionary())
	var briefing := CampaignBriefingScene.instantiate() as Control
	if briefing == null:
		return
	if briefing.has_signal("action_requested"):
		briefing.connect("action_requested", Callable(self, "_on_campaign_action_requested"))
	menu_preview_box.add_child(briefing)
	if briefing.has_method("set_briefing"):
		briefing.call("set_briefing", _campaign_briefing_snapshot(resolved_id))


func _campaign_briefing_snapshot(chapter_id: String) -> Dictionary:
	return CampaignBriefingSnapshotScript.new().apply_dictionary({
		"campaign": _campaign_definition(),
		"chapter": _campaign_chapter_by_id(chapter_id),
	}).to_ui_dictionary()


func _on_campaign_action_requested(action_id: String) -> void:
	if action_id.begins_with("campaign_continue_"):
		_open_campaign_briefing_menu(action_id.substr("campaign_continue_".length()).strip_edges())
	elif action_id.begins_with("campaign_chapter_"):
		_open_campaign_briefing_menu(action_id.substr("campaign_chapter_".length()).strip_edges())
	elif action_id.begins_with("campaign_start_"):
		_start_campaign_chapter(action_id.substr("campaign_start_".length()).strip_edges())
	elif action_id.begins_with("campaign_next_"):
		var next_id := action_id.substr("campaign_next_".length()).strip_edges()
		if next_id == "":
			_open_campaign_menu()
		else:
			_open_campaign_briefing_menu(next_id)
	elif action_id.begins_with("quick_preset_"):
		_start_recommended_quick_run(action_id.substr("quick_preset_".length()).strip_edges())
	elif action_id == "campaign_quick_start":
		_start_recommended_quick_run("stable_economy")
	elif action_id == "campaign_settings":
		_open_campaign_settings_menu()
	elif action_id == "campaign_reset_progress":
		_reset_campaign_progress()
	elif action_id == "campaign_recap":
		_open_campaign_recap_menu()
	elif action_id == "campaign_reward":
		_open_campaign_reward_menu()
	elif action_id == "campaign_menu":
		_open_campaign_menu()
	elif action_id == "campaign_back":
		_open_main_menu()


func _start_campaign_chapter(chapter_id: String) -> void:
	var chapter := _campaign_chapter_by_id(chapter_id)
	if chapter.is_empty():
		_log("战役关卡无法加载：%s。" % chapter_id)
		return
	_apply_recommended_start("stable_economy")
	selected_campaign_chapter_id = chapter_id
	active_campaign_chapter_id = chapter_id
	campaign_last_reward = {}
	campaign_last_recap = {}
	_save_campaign_progress_state()
	_start_scenario_from_menu(str(chapter.get("scenario_id", "first_table")))
	active_campaign_chapter_id = chapter_id
	_record_scenario_action("campaign", "开始战役关卡：%s" % str(chapter.get("title", chapter_id)), "", "campaign:%s" % chapter_id, "start", "scenario_coach")
	_sync_runtime_game_screen(true)


func _start_recommended_quick_run(preset_id: String) -> void:
	active_campaign_chapter_id = ""
	var coordinator := _game_runtime_coordinator_node()
	if coordinator != null and coordinator.has_method("clear_runtime_scenario"):
		coordinator.call("clear_runtime_scenario")
	_apply_recommended_start(preset_id)
	_new_game()
	_log("快速开局：已应用推荐配置「%s」。" % preset_id)
	_close_menu()
	_sync_runtime_game_screen(true)


func _apply_recommended_start(preset_id: String = "") -> void:
	var service: Variant = RecommendedStartServiceScript.new()
	var data: Dictionary = service.load_recommendations()
	var preset: Dictionary = service.preset_by_id(preset_id) if preset_id != "" else {}
	configured_player_count = clampi(int(preset.get("player_count", data.get("player_count", 4))), 3, 8)
	configured_ai_player_count = clampi(int(preset.get("ai_count", data.get("ai_count", 3))), 2, 7)
	configured_roguelike_depth = clampi(int(preset.get("roguelike_depth", data.get("roguelike_depth", 1))), ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX)
	var role_value: Variant = preset.get("role_indices", data.get("role_indices", FIRST_RUN_RECOMMENDED_ROLE_INDICES))
	configured_role_indices = (role_value as Array).duplicate(true) if role_value is Array else FIRST_RUN_RECOMMENDED_ROLE_INDICES.duplicate(true)
	var starter_value: Variant = preset.get("starter_monster_indices", data.get("starter_monster_indices", FIRST_RUN_RECOMMENDED_STARTER_MONSTER_INDICES))
	configured_starter_monster_indices = (starter_value as Array).duplicate(true) if starter_value is Array else FIRST_RUN_RECOMMENDED_STARTER_MONSTER_INDICES.duplicate(true)
	_ensure_configured_ai_player_count()
	_ensure_configured_roguelike_depth()
	_ensure_configured_role_indices()
	_ensure_configured_starter_monster_indices()


func _maybe_finish_campaign_chapter_from_signals() -> void:
	if active_campaign_chapter_id == "":
		return
	if campaign_completion_pending_chapter_id != "":
		return
	var chapter := _campaign_chapter_by_id(active_campaign_chapter_id)
	if chapter.is_empty():
		return
	var conditions: Array = chapter.get("success_conditions", []) if chapter.get("success_conditions", []) is Array else []
	if conditions.is_empty():
		return
	var completed_signals: Dictionary = _runtime_scenario_state().get("completed_signals", {})
	for condition_variant in conditions:
		if not bool(completed_signals.get(str(condition_variant), false)):
			return
	_schedule_campaign_chapter_completion(chapter)


func _schedule_campaign_chapter_completion(chapter: Dictionary) -> void:
	var chapter_id := str(chapter.get("id", active_campaign_chapter_id)).strip_edges()
	if chapter_id == "":
		return
	campaign_completion_pending_chapter_id = chapter_id
	var scenario_state := _runtime_scenario_state()
	var snapshot_key := str(scenario_state.get("active_snapshot_key", "start"))
	var scenario_id := str(scenario_state.get("active_scenario_id", ""))
	_record_scenario_action("chapter_success", "目标完成：演出结算后进入奖励。", "", "campaign_success_feedback", snapshot_key, "scenario_coach")
	_queue_scenario_visual_events(scenario_id, snapshot_key, "chapter_success")
	_sync_runtime_game_screen(true)
	await get_tree().create_timer(CAMPAIGN_SUCCESS_FEEDBACK_SECONDS).timeout
	if active_campaign_chapter_id == chapter_id and campaign_completion_pending_chapter_id == chapter_id:
		_finish_campaign_chapter(chapter)


func _finish_campaign_chapter(chapter: Dictionary) -> void:
	var chapter_id := str(chapter.get("id", active_campaign_chapter_id)).strip_edges()
	if chapter_id == "":
		return
	campaign_completion_pending_chapter_id = ""
	if not campaign_completed_chapter_ids.has(chapter_id):
		campaign_completed_chapter_ids.append(chapter_id)
	selected_campaign_chapter_id = CampaignProgressScript.new().apply_state(_campaign_definition(), campaign_completed_chapter_ids, chapter_id).next_chapter_id()
	var progress := _campaign_progress_dictionary(selected_campaign_chapter_id)
	var stats := _campaign_completion_stats(chapter)
	campaign_last_reward = CampaignRewardServiceScript.new().build_reward(_campaign_definition(), chapter, progress, stats)
	var action_log_entries: Array = _runtime_scenario_state().get("action_log_entries", [])
	campaign_last_recap = CampaignRewardServiceScript.new().build_recap(_campaign_definition(), chapter, action_log_entries, stats)
	_save_campaign_progress_state()
	active_campaign_chapter_id = ""
	_open_campaign_reward_menu()


func _campaign_completion_stats(chapter: Dictionary) -> Dictionary:
	var conditions: Array = chapter.get("success_conditions", []) if chapter.get("success_conditions", []) is Array else []
	var hint_count := 0
	var action_log_entries: Array = _runtime_scenario_state().get("action_log_entries", [])
	for entry_variant in action_log_entries:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("phase_id", "")) == "hint":
			hint_count += 1
	return {
		"time_text": _format_time(game_time),
		"objectives_completed": conditions.size(),
		"objectives_total": maxi(1, conditions.size()),
		"errors": 0,
		"hints": hint_count,
		"economy": _campaign_recap_economy_stats(0),
	}


func _campaign_recap_economy_stats(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= players.size():
		return {}
	var player: Dictionary = players[player_index]
	var starting_cash := int(player.get("starting_cash_total", player.get("base_starting_cash", STARTING_CASH)))
	var final_cash := int(player.get("cash", starting_cash))
	var city_count := 0
	var gdp_per_min := 0
	var pressure := 0
	var top_city := ""
	var top_city_gdp := -999999
	for district_index in range(districts.size()):
		var city := _district_city(district_index)
		if city.is_empty() or not _city_is_active(city) or int(city.get("owner", -1)) != player_index:
			continue
		city_count += 1
		var city_gdp := _city_gdp_per_minute(district_index, _city_competition_matches(district_index))
		gdp_per_min += city_gdp
		pressure += int(districts[district_index].get("damage", 0))
		pressure += int(city.get("route_damage", 0))
		if city_gdp > top_city_gdp:
			top_city_gdp = city_gdp
			top_city = "%s｜GDP/min %d" % [String(districts[district_index].get("name", "城市")), city_gdp]
	return {
		"starting_cash": starting_cash,
		"final_cash": final_cash,
		"cash_delta": final_cash - starting_cash,
		"city_count": city_count,
		"gdp_per_min": gdp_per_min,
		"total_income": _player_commodity_sale_income(player_index) + int(player.get("total_card_income", 0)) + int(player.get("total_role_income", 0)),
		"total_spend": int(player.get("total_card_spend", 0)) + int(player.get("total_build_spend", 0)) + int(player.get("total_business_spend", 0)),
		"pressure": max(0, pressure),
		"top_city": top_city,
	}


func _open_campaign_reward_menu() -> void:
	if campaign_last_reward.is_empty():
		_open_campaign_menu()
		return
	_show_menu("关卡奖励", "关卡完成。看奖励、复盘，或继续下一关。", not _runtime_session_finished(), false)
	if menu_preview_box == null:
		return
	menu_overlay.call("clear_preview")
	menu_preview_box.visible = true
	var panel := CampaignRewardPanelScene.instantiate() as Control
	if panel == null:
		return
	if panel.has_signal("action_requested"):
		panel.connect("action_requested", Callable(self, "_on_campaign_action_requested"))
	menu_preview_box.add_child(panel)
	if panel.has_method("set_reward"):
		panel.call("set_reward", CampaignRewardSnapshotScript.new().apply_dictionary(campaign_last_reward).to_ui_dictionary())


func _open_campaign_recap_menu() -> void:
	if campaign_last_recap.is_empty():
		_open_scenario_replay_menu()
		return
	_show_menu("战役复盘", "只显示公开行动、你自己的记录和下一步建议。", not _runtime_session_finished(), false)
	if menu_preview_box == null:
		return
	menu_overlay.call("clear_preview")
	menu_preview_box.visible = true
	var panel := MatchRecapPanelScene.instantiate() as Control
	if panel == null:
		return
	if panel.has_signal("action_requested"):
		panel.connect("action_requested", Callable(self, "_on_campaign_action_requested"))
	menu_preview_box.add_child(panel)
	if panel.has_method("set_recap"):
		panel.call("set_recap", MatchRecapSnapshotScript.new().apply_dictionary(campaign_last_recap).to_ui_dictionary())


func _open_campaign_settings_menu() -> void:
	_show_menu("设置", "调整教学、动画、字体和声音。设置只影响呈现，不改变牌局规则。", not _runtime_session_finished(), false)
	if menu_preview_box == null:
		return
	menu_overlay.call("clear_preview")
	menu_preview_box.visible = true
	var panel := PresentationSettingsPanelScene.instantiate() as Control
	if panel == null or not panel.has_method("set_settings"):
		_report_required_ui_scene_missing("PresentationSettingsPanel", "set_settings")
		return
	if panel.has_signal("action_requested"):
		panel.connect("action_requested", Callable(self, "_on_presentation_menu_action_requested"))
	menu_preview_box.add_child(panel)
	panel.call("set_settings", _presentation_settings_snapshot("campaign"))


func _toggle_campaign_teaching_hints() -> void:
	scenario_teaching_hints_enabled = not scenario_teaching_hints_enabled
	if not scenario_teaching_hints_enabled:
		var coordinator := _game_runtime_coordinator_node()
		if coordinator != null and coordinator.has_method("set_runtime_scenario_coach_closed"):
			coordinator.call("set_runtime_scenario_coach_closed", true)
	_save_settings(false)
	_open_campaign_settings_menu()
	_sync_runtime_game_screen(true)


func _cycle_campaign_animation_intensity() -> void:
	var values := ["完整", "简化", "关闭"]
	var idx := values.find(campaign_animation_intensity)
	campaign_animation_intensity = values[(idx + 1) % values.size()] if idx >= 0 else "完整"
	_save_settings(false)
	_open_campaign_settings_menu()


func _cycle_campaign_font_scale() -> void:
	var values := ["小", "中", "大"]
	var idx := values.find(campaign_font_scale_label)
	campaign_font_scale_label = values[(idx + 1) % values.size()] if idx >= 0 else "中"
	_save_settings(false)
	_open_campaign_settings_menu()


func _toggle_campaign_colorblind_assist() -> void:
	campaign_colorblind_assist_enabled = not campaign_colorblind_assist_enabled
	_save_settings(false)
	_open_campaign_settings_menu()


func _cycle_campaign_ui_volume() -> void:
	campaign_ui_volume = (campaign_ui_volume + 20) % 120
	_save_settings(false)
	_open_campaign_settings_menu()


func _cycle_campaign_bgm_volume() -> void:
	campaign_bgm_volume = (campaign_bgm_volume + 20) % 120
	_save_settings(false)
	_open_campaign_settings_menu()


func _reset_campaign_progress() -> void:
	campaign_completed_chapter_ids = []
	selected_campaign_chapter_id = ""
	CampaignSaveScript.new().reset()
	_open_campaign_menu()


func _open_scenario_browser_menu() -> void:
	_show_menu(
		"试玩剧本",
		"选择一个固定局面：练步骤、看日志、复盘关键状态。这里不泄露对手私有信息。",
		not _runtime_session_finished(),
		false
	)
	if menu_preview_box == null:
		return
	menu_overlay.call("clear_preview")
	menu_preview_box.visible = true
	_add_scenario_browser_panel(menu_preview_box)


func _add_scenario_browser_panel(parent: Container) -> void:
	var browser := ScenarioBrowserScene.instantiate() as Control
	if browser == null:
		return
	if browser.has_signal("action_requested"):
		browser.connect("action_requested", Callable(self, "_on_scenario_browser_action_requested"))
	parent.add_child(browser)
	if browser.has_method("set_browser"):
		browser.call("set_browser", _scenario_browser_snapshot())


func _scenario_browser_snapshot() -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	var scenarios: Array = coordinator.call("scenario_catalog") if coordinator != null and coordinator.has_method("scenario_catalog") else []
	return ScenarioBrowserSnapshotScript.new().apply_dictionary({
		"scenarios": scenarios,
		"selected_id": selected_scenario_id,
		"title": "试玩剧本",
		"subtitle": "固定局面像桌游练习包：进入、完成目标、看日志、复盘。"
	}).to_ui_dictionary()


func _on_scenario_browser_action_requested(action_id: String) -> void:
	if action_id.begins_with("scenario_select_"):
		selected_scenario_id = action_id.substr("scenario_select_".length()).strip_edges()
		_open_scenario_browser_menu()
	elif action_id.begins_with("scenario_start_"):
		var scenario_id := action_id.substr("scenario_start_".length()).strip_edges()
		if scenario_id == "":
			scenario_id = selected_scenario_id
		active_campaign_chapter_id = ""
		_start_scenario_from_menu(scenario_id)
	elif action_id == "scenario_restart_last":
		active_campaign_chapter_id = ""
		var active_id := _active_runtime_scenario_id()
		_start_scenario_from_menu(active_id if active_id != "" else selected_scenario_id)
	elif action_id == "scenario_settings":
		_open_scenario_settings_menu()
	elif action_id == "scenario_back":
		_open_main_menu()


func _open_scenario_settings_menu() -> void:
	_show_menu(
		"剧本教学设置",
		"只调整试玩剧本的提示层，不改变牌局规则。",
		not _runtime_session_finished(),
		false
	)
	if menu_preview_box == null:
		return
	menu_overlay.call("clear_preview")
	menu_preview_box.visible = true
	var panel := PresentationSettingsPanelScene.instantiate() as Control
	if panel == null or not panel.has_method("set_settings"):
		_report_required_ui_scene_missing("PresentationSettingsPanel", "set_settings")
		return
	if panel.has_signal("action_requested"):
		panel.connect("action_requested", Callable(self, "_on_presentation_menu_action_requested"))
	menu_preview_box.add_child(panel)
	panel.call("set_settings", _presentation_settings_snapshot("scenario"))


func _presentation_settings_snapshot(mode: String) -> Dictionary:
	if mode == "scenario":
		return {
			"mode": "scenario",
			"mode_label": "剧本辅助",
			"title": "试玩剧本辅助",
			"summary": "当前：教学提示%s｜自动暂停%s｜提示字号%d%%。" % [
				"开启" if scenario_teaching_hints_enabled else "关闭",
				"开启" if scenario_auto_pause_prompts_enabled else "关闭",
				scenario_font_scale_percent,
			],
			"privacy_text": "这里只显示桌面提示，不显示对手私密计划、评分或私有手牌。",
			"actions": [
				{"id": "scenario_toggle_teaching_hints", "label": "教学提示：%s" % ("开" if scenario_teaching_hints_enabled else "关"), "tooltip": "关闭后，牌桌上的剧本目标教练不再自动出现；可以从剧本页重新打开。"},
				{"id": "scenario_toggle_auto_pause", "label": "自动暂停提示：%s" % ("开" if scenario_auto_pause_prompts_enabled else "关"), "tooltip": "打开时，关键教学节点可短暂停住桌面；当前只保存你的偏好。"},
				{"id": "scenario_cycle_font_scale", "label": "提示字号：%d%%" % scenario_font_scale_percent, "tooltip": "循环90%、100%、110%、125%，只放大剧本提示文字。"},
				{"id": "scenario_settings_back", "label": "返回剧本库", "tooltip": "回到固定试玩剧本选择。"},
			],
		}
	return {
		"mode": "campaign",
		"mode_label": "战役呈现",
		"title": "可访问性与教学",
		"summary": "教学提示%s｜动画%s｜字体%s｜色盲辅助%s｜UI音效%d｜BGM%d" % [
			"开" if scenario_teaching_hints_enabled else "关",
			campaign_animation_intensity,
			campaign_font_scale_label,
			"开" if campaign_colorblind_assist_enabled else "关",
			campaign_ui_volume,
			campaign_bgm_volume,
		],
		"privacy_text": "设置只影响呈现，不改变牌局规则、结算、AI或隐私边界。",
		"actions": [
			{"id": "campaign_toggle_teaching_hints", "label": "教学提示：%s" % ("开" if scenario_teaching_hints_enabled else "关"), "tooltip": "开关战役与剧本的桌面教学提示。"},
			{"id": "campaign_cycle_animation_intensity", "label": "动画：%s" % campaign_animation_intensity, "tooltip": "循环完整、简化和关闭三档呈现动画。"},
			{"id": "campaign_cycle_font_scale", "label": "字体：%s" % campaign_font_scale_label, "tooltip": "循环小、中、大三档战役字体。"},
			{"id": "campaign_toggle_colorblind", "label": "色盲辅助：%s" % ("开" if campaign_colorblind_assist_enabled else "关"), "tooltip": "切换额外的非颜色信息提示。"},
			{"id": "campaign_cycle_ui_volume", "label": "UI音效：%d" % campaign_ui_volume, "tooltip": "循环界面音效音量。"},
			{"id": "campaign_cycle_bgm_volume", "label": "BGM：%d" % campaign_bgm_volume, "tooltip": "循环背景音乐音量。"},
			{"id": "campaign_reset_progress", "label": "重置教程进度", "tooltip": "清除战役教程进度并回到战役入口。"},
			{"id": "campaign_settings_back", "label": "返回战役", "tooltip": "返回新手战役地图。"},
		],
	}


func _on_presentation_menu_action_requested(action_id: String) -> void:
	match action_id:
		"campaign_toggle_teaching_hints":
			_toggle_campaign_teaching_hints()
		"campaign_cycle_animation_intensity":
			_cycle_campaign_animation_intensity()
		"campaign_cycle_font_scale":
			_cycle_campaign_font_scale()
		"campaign_toggle_colorblind":
			_toggle_campaign_colorblind_assist()
		"campaign_cycle_ui_volume":
			_cycle_campaign_ui_volume()
		"campaign_cycle_bgm_volume":
			_cycle_campaign_bgm_volume()
		"campaign_reset_progress":
			_reset_campaign_progress()
		"campaign_settings_back":
			_open_campaign_menu()
		"scenario_toggle_teaching_hints":
			_toggle_scenario_teaching_hints()
		"scenario_toggle_auto_pause":
			_toggle_scenario_auto_pause_prompts()
		"scenario_cycle_font_scale":
			_cycle_scenario_font_scale_percent()
		"scenario_settings_back":
			_open_scenario_browser_menu()
		"scenario_pause_restart":
			_restart_active_scenario_from_pause()
		"scenario_pause_choose":
			if active_campaign_chapter_id != "" or not campaign_last_recap.is_empty():
				_open_campaign_menu()
			else:
				_open_scenario_browser_menu()
		"scenario_pause_log":
			_open_scenario_action_log_menu()
		"scenario_pause_replay":
			if active_campaign_chapter_id != "" or not campaign_last_recap.is_empty():
				_open_campaign_recap_menu()
			else:
				_open_scenario_replay_menu()
		"scenario_pause_settings":
			_open_scenario_settings_menu()


func _toggle_scenario_teaching_hints() -> void:
	scenario_teaching_hints_enabled = not scenario_teaching_hints_enabled
	if not scenario_teaching_hints_enabled:
		var coordinator := _game_runtime_coordinator_node()
		if coordinator != null and coordinator.has_method("set_runtime_scenario_coach_closed"):
			coordinator.call("set_runtime_scenario_coach_closed", true)
	_save_settings(false)
	_open_scenario_settings_menu()
	_sync_runtime_game_screen(true)


func _toggle_scenario_auto_pause_prompts() -> void:
	scenario_auto_pause_prompts_enabled = not scenario_auto_pause_prompts_enabled
	_save_settings(false)
	_open_scenario_settings_menu()


func _cycle_scenario_font_scale_percent() -> void:
	var values := [90, 100, 110, 125]
	var current_index := values.find(scenario_font_scale_percent)
	scenario_font_scale_percent = int(values[(current_index + 1) % values.size()]) if current_index >= 0 else 100
	_save_settings(false)
	_open_scenario_settings_menu()
	_sync_runtime_game_screen(true)


func _start_scenario_from_menu(scenario_id: String) -> void:
	var coordinator := _game_runtime_coordinator_node()
	var scenario: Dictionary = coordinator.call("scenario_definition", scenario_id) if coordinator != null and coordinator.has_method("scenario_definition") else {}
	if scenario.is_empty():
		_log("试玩剧本无法加载：%s。" % scenario_id)
		return
	var start_result: Dictionary = coordinator.call("start_runtime_scenario", scenario_id, 0.0) if coordinator.has_method("start_runtime_scenario") else {}
	if not bool(start_result.get("started", false)):
		_log("试玩剧本运行时无法启动：%s。" % scenario_id)
		return
	selected_scenario_id = scenario_id
	campaign_completion_pending_chapter_id = ""
	runtime_visual_events = []
	runtime_visual_event_key = ""
	configured_player_count = clampi(int(scenario.get("player_count", 4)), 3, 8)
	configured_ai_player_count = clampi(int(scenario.get("ai_count", 3)), 2, 7)
	_ensure_configured_ai_player_count()
	_ensure_configured_role_indices()
	_ensure_configured_starter_monster_indices()
	_new_game()
	_record_scenario_action("start", "开始剧本：%s" % str(scenario.get("title", scenario_id)), "", "scenario:%s" % scenario_id, "start", "scenario_coach")
	_close_menu()
	_sync_runtime_game_screen(true)


func start_first_mission_runtime() -> void:
	active_campaign_chapter_id = ""
	_apply_recommended_first_run_setup()
	_start_scenario_from_menu("first_table")


func _record_scenario_action(phase_id: String, public_text: String, private_text: String = "", developer_text: String = "", snapshot_key: String = "", focus_target: String = "") -> void:
	var coordinator := _game_runtime_coordinator_node()
	if _active_runtime_scenario_id() == "" or coordinator == null or not coordinator.has_method("record_runtime_scenario_action"):
		return
	coordinator.call("record_runtime_scenario_action", {
		"time": _format_time(game_time),
		"phase_id": phase_id,
		"public_text": public_text,
		"private_text": private_text,
		"developer_text": developer_text,
		"viewer_index": selected_player,
		"snapshot_key": snapshot_key,
		"focus_target": focus_target,
	})


func _complete_scenario_signal(signal_id: String, public_text: String, snapshot_key: String = "", focus_target: String = "") -> bool:
	signal_id = signal_id.strip_edges()
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("complete_runtime_scenario_signal") or signal_id == "":
		return false
	var result: Dictionary = coordinator.call("complete_runtime_scenario_signal", signal_id, {
		"time": _format_time(game_time),
		"public_text": public_text,
		"private_text": "",
		"developer_text": "signal:%s" % signal_id,
		"viewer_index": selected_player,
		"snapshot_key": snapshot_key,
		"focus_target": focus_target,
	}, game_time)
	if not bool(result.get("accepted", false)):
		return false
	var visual_request: Dictionary = result.get("visual_event_request", {})
	var events: Array = visual_request.get("events", []) if visual_request.get("events", []) is Array else []
	if not events.is_empty():
		runtime_visual_event_counter += 1
		runtime_visual_events = events.duplicate(true)
		runtime_visual_event_key = "%s:%s:%s:%d" % [str(visual_request.get("scenario_id", "")), str(visual_request.get("snapshot_key", "start")), signal_id, runtime_visual_event_counter]
	_sync_runtime_game_screen(true)
	_maybe_finish_campaign_chapter_from_signals()
	return true


func _queue_scenario_visual_events(scenario_id: String, snapshot_key: String, trigger_id: String = "") -> void:
	if scenario_id.strip_edges() == "":
		return
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("build_runtime_scenario_visual_event_request"):
		return
	var request: Dictionary = coordinator.call("build_runtime_scenario_visual_event_request", scenario_id, snapshot_key, trigger_id)
	var events: Array = request.get("events", []) if request.get("events", []) is Array else []
	if events.is_empty():
		return
	runtime_visual_event_counter += 1
	runtime_visual_events = events.duplicate(true)
	runtime_visual_event_key = "%s:%s:%s:%d" % [str(request.get("scenario_id", scenario_id)), str(request.get("snapshot_key", snapshot_key)), trigger_id, runtime_visual_event_counter]


func _runtime_scenario_coach_snapshot_source(player_index: int) -> Dictionary:
	var scenario_id := _active_runtime_scenario_id()
	if scenario_id == "" or player_index < 0 or player_index >= players.size():
		return {}
	var coordinator := _game_runtime_coordinator_node()
	var progress: Dictionary = coordinator.call("runtime_scenario_progress", game_time) if coordinator != null and coordinator.has_method("runtime_scenario_progress") else {}
	if progress.is_empty():
		return {}
	var phase: Dictionary = progress.get("current_phase", {}) if progress.get("current_phase", {}) is Dictionary else {}
	if scenario_id == "first_table":
		var authored_content := _first_table_runtime_content_snapshot(player_index)
		var scenario_state := _runtime_scenario_state()
		progress["authored_content"] = authored_content
		progress["pacing"] = coordinator.call("first_table_evaluate_pacing", scenario_state) if coordinator != null and coordinator.has_method("first_table_evaluate_pacing") else {}
		progress["completion_summary"] = str(coordinator.call("first_table_completion_summary", authored_content)) if coordinator != null and coordinator.has_method("first_table_completion_summary") else ""
		progress["completion_label"] = str(coordinator.call("first_table_completion_label", authored_content)) if coordinator != null and coordinator.has_method("first_table_completion_label") else ""
		if not phase.is_empty():
			var contextual_variant: Variant = coordinator.call("first_table_contextualize_phase", phase, authored_content) if coordinator != null and coordinator.has_method("first_table_contextualize_phase") else {}
			if contextual_variant is Dictionary and not (contextual_variant as Dictionary).is_empty():
				phase = (contextual_variant as Dictionary).duplicate(true)
			progress["current_phase"] = phase
	if active_campaign_chapter_id != "":
		var chapter := _campaign_chapter_by_id(active_campaign_chapter_id)
		progress["campaign_id"] = active_campaign_id
		progress["chapter_id"] = active_campaign_chapter_id
		progress["title"] = "新手战役｜%s" % str(chapter.get("title", progress.get("title", "当前关卡")))
	progress["visible"] = scenario_teaching_hints_enabled
	progress["primary_action_id"] = "scenario_step_%s" % str(phase.get("id", "done"))
	progress["font_scale_percent"] = scenario_font_scale_percent
	progress["campaign_focus_mode"] = _runtime_campaign_focus_mode()
	return progress


func _activate_scenario_action(action_id: String) -> bool:
	var scenario_id := _active_runtime_scenario_id()
	if scenario_id == "":
		return false
	var coordinator := _game_runtime_coordinator_node()
	var progress: Dictionary = coordinator.call("runtime_scenario_progress", game_time) if coordinator != null and coordinator.has_method("runtime_scenario_progress") else {}
	var phase: Dictionary = progress.get("current_phase", {}) if progress.get("current_phase", {}) is Dictionary else {}
	if action_id == "scenario_reopen_coach":
		coordinator.call("set_runtime_scenario_coach_closed", false)
		_sync_runtime_game_screen(true)
		return true
	if action_id == "scenario_close_coach":
		coordinator.call("set_runtime_scenario_coach_closed", true)
		_sync_runtime_game_screen(true)
		return true
	if action_id == "scenario_hint":
		_record_scenario_help_request(phase, "查看剧本提示")
		_sync_runtime_game_screen(true)
		return true
	if action_id == "scenario_restart":
		_start_scenario_from_menu(scenario_id)
		return true
	if action_id == "scenario_focus_target":
		_record_scenario_help_request(phase, "定位剧本目标：%s" % str(phase.get("label", "目标")))
		_focus_scenario_phase_target(phase)
		_sync_runtime_game_screen(true)
		return true
	if action_id.begins_with("scenario_step_"):
		return _activate_scenario_step_action(phase, action_id)
	return false


func _activate_scenario_step_action(phase: Dictionary, action_id: String) -> bool:
	var phase_id := str(phase.get("id", action_id.replace("scenario_step_", ""))).strip_edges()
	match phase_id:
		"buy_development":
			return _activate_first_run_coach_action("coach_buy_card")
		"play_development":
			return _activate_first_run_coach_action("coach_play_card")
		"establish_project":
			return _activate_first_run_coach_action("coach_inspect_track")
		"check_economy":
			return _activate_first_run_coach_action("coach_check_economy")
		"buy_followup":
			return _activate_first_run_coach_action("coach_buy_followup_card")
		"play_followup":
			return _activate_first_run_coach_action("coach_play_followup_card")
		"observe_ai_public_action":
			return _activate_first_run_coach_action("coach_observe_ai_public_action")
		"inspect_clues":
			return _activate_first_run_coach_action("coach_inspect_clues")
		"inspect_monster_pressure":
			return _activate_first_run_coach_action("coach_inspect_monster_pressure")
		"choose_route":
			return _activate_first_run_coach_action("coach_choose_route_growth")
		"open_rack":
			var district_index := selected_district
			if district_index < 0 or district_index >= districts.size():
				district_index = _first_run_recommended_start_district(_runtime_snapshot_player_index())
			if district_index >= 0:
				_open_district_supply_from_map(district_index)
				return true
		"compare_cards":
			if not _district_supply_is_open():
				_activate_scenario_step_action({"id": "open_rack"}, "scenario_step_open_rack")
			var context_district := _active_district_card_context()
			var choices: Array = districts[context_district].get("card_choices", []) if context_district >= 0 and context_district < districts.size() and districts[context_district].get("card_choices", []) is Array else []
			for card_variant in choices:
				var card_name := str(card_variant)
				if _game_runtime_coordinator_node().card_exists(card_name):
					_preview_district_card(card_name, true)
					return true
		"buy_pressure", "buy_card":
			return _activate_first_run_coach_action("coach_buy_card")
		"select_track_card":
			var resolution_id := _first_public_track_resolution_id()
			if resolution_id >= 0:
				_select_card_resolution_track_entry(resolution_id)
				_mark_first_run_coach_public_track_seen(_runtime_snapshot_player_index())
				return true
		"read_inspector":
			if selected_card_resolution_id < 0:
				var track_resolution_id := _first_public_track_resolution_id()
				if track_resolution_id >= 0:
					_select_card_resolution_track_entry(track_resolution_id)
			return _complete_scenario_signal("inspector_read", "查看右侧详情：只读公开条件和线索。", "after_track", "right_inspector")
		"open_card_detail":
			var card_surfaces := _runtime_card_surfaces_snapshot()
			var entries: Array = card_surfaces.get("card_track", []) if card_surfaces.get("card_track", []) is Array else []
			var selected_entry := {}
			for entry_variant in entries:
				if entry_variant is Dictionary and int((entry_variant as Dictionary).get("resolution_id", -1)) == selected_card_resolution_id:
					selected_entry = entry_variant as Dictionary
					break
			var card_name := str(selected_entry.get("card_name", "")).strip_edges()
			if card_name == "":
				for entry_variant in entries:
					if entry_variant is Dictionary:
						card_name = str((entry_variant as Dictionary).get("card_name", "")).strip_edges()
						if card_name != "":
							break
			if card_name != "":
				_open_card_codex_by_name(card_name)
				return true
		"read_bid_board":
			return _complete_scenario_signal("bid_board_read", "查看竞价板：我的报价、最高价、本批和下批都在底部。", "batch_ready", "bid_board")
		"raise_bid":
			return _increase_selected_card_bid(50)
		"reset_bid":
			return _reset_selected_card_bid()
	_record_scenario_help_request(phase, "定位剧本目标：%s" % str(phase.get("label", "目标")))
	_focus_scenario_phase_target(phase)
	_sync_runtime_game_screen(true)
	return true


func _focus_scenario_phase_target(phase: Dictionary) -> bool:
	var focus_target := str(phase.get("focus_target", "scenario_coach")).strip_edges()
	var phase_id := str(phase.get("id", "")).strip_edges()
	var player_index := _runtime_snapshot_player_index()
	var handled := false
	match phase_id:
		"open_rack", "compare_cards", "buy_pressure", "buy_card", "discard_private":
			handled = _focus_scenario_district_supply(player_index)
		"select_track_card", "select_anonymous_card":
			handled = _focus_scenario_public_track()
		"read_inspector", "open_card_detail":
			handled = _focus_scenario_right_inspector(player_index)
		"read_bid_board", "raise_bid", "reset_bid":
			handled = _focus_scenario_bid_board()
		"open_intel", "mark_guess":
			_open_intel_dossier_menu()
			handled = true
		"inspect_city_gdp", "inspect_goods":
			handled = _focus_scenario_right_inspector(player_index)
		"open_economy":
			_open_economy_overview_menu()
			handled = true
		"open_standings":
			_open_standings_menu()
			handled = true
		"route_delta":
			handled = _focus_scenario_map_layer("route", player_index)
		"offer_contract":
			handled = _focus_scenario_map_layer("route", player_index)
	if handled:
		return true
	match focus_target:
		"planet":
			return _focus_scenario_map_layer("monster" if phase_id == "inspect_monster" else "all", player_index)
		"district_supply", "private_decision":
			return _focus_scenario_district_supply(player_index)
		"public_track":
			return _focus_scenario_public_track()
		"right_inspector":
			return _focus_scenario_right_inspector(player_index)
		"bid_board":
			return _focus_scenario_bid_board()
		"intel_dossier":
			_open_intel_dossier_menu()
			return true
		"economy_overview":
			_open_economy_overview_menu()
			return true
		"standings":
			_open_standings_menu()
			return true
		"route_layer":
			return _focus_scenario_map_layer("route", player_index)
		"contract_prompt":
			return _focus_scenario_map_layer("route", player_index)
		"top_bar", "player_hand", "action_dock", "scenario_coach":
			return true
	return false


func _focus_scenario_district_supply(player_index: int) -> bool:
	var district_index := _first_buyable_district_for_player(player_index)
	if district_index < 0 and _district_supply_is_open():
		district_index = district_supply_open_district
	if district_index < 0 and selected_district >= 0 and selected_district < districts.size():
		district_index = selected_district
	if district_index < 0:
		district_index = _first_run_recommended_start_district(player_index)
	if district_index < 0 or district_index >= districts.size():
		return false
	selected_player = player_index
	_open_district_supply_from_map(district_index)
	return true


func _focus_scenario_public_track() -> bool:
	var resolution_id := _first_public_track_resolution_id()
	if resolution_id < 0:
		return false
	_focus_card_resolution_track_entry(resolution_id)
	return true


func _focus_scenario_right_inspector(player_index: int) -> bool:
	var handled := _focus_scenario_public_track()
	if handled:
		return true
	var district_index := selected_district
	if district_index < 0 or district_index >= districts.size():
		district_index = _first_run_recommended_start_district(player_index)
	if district_index >= 0 and district_index < districts.size():
		_jump_to_district_on_table(district_index)
		return true
	return false


func _focus_scenario_bid_board() -> bool:
	_focus_scenario_public_track()
	return true


func _focus_scenario_map_layer(layer_id: String, player_index: int) -> bool:
	var district_index := selected_district
	if district_index < 0 or district_index >= districts.size():
		district_index = _first_run_recommended_start_district(player_index)
	if district_index >= 0 and district_index < districts.size():
		_jump_to_district_on_table(district_index)
	_set_map_layer_focus(layer_id)
	return true


func _record_scenario_help_request(phase: Dictionary, public_text: String) -> void:
	var phase_id := str(phase.get("id", "hint")).strip_edges()
	if phase_id == "":
		phase_id = "hint"
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("record_runtime_scenario_failed_attempt"):
		return
	var snapshot_key := str(phase.get("snapshot_key", _runtime_scenario_state().get("active_snapshot_key", "start")))
	coordinator.call("record_runtime_scenario_failed_attempt", phase_id, {
		"time": _format_time(game_time),
		"public_text": public_text,
		"private_text": str(phase.get("stuck_hint", phase.get("detail", phase.get("goal", "")))),
		"developer_text": "",
		"viewer_index": selected_player,
		"snapshot_key": snapshot_key,
		"focus_target": str(phase.get("focus_target", "scenario_coach")),
	}, game_time)


func _open_scenario_action_log_menu() -> void:
	_show_menu("剧本行动日志", "只显示公开记录和当前玩家自己的私密记录；隐藏资料不会出现在这里。", not _runtime_session_finished(), false)
	if menu_preview_box == null:
		return
	menu_overlay.call("clear_preview")
	menu_preview_box.visible = true
	var panel := ScenarioActionLogScene.instantiate() as Control
	menu_preview_box.add_child(panel)
	if panel.has_method("set_log"):
		var scenario_state := _runtime_scenario_state()
		panel.call("set_log", ScenarioActionLogSnapshotScript.new().apply_dictionary({
			"scenario_id": str(scenario_state.get("active_scenario_id", "")),
			"title": "剧本行动日志",
			"viewer_index": selected_player,
			"entries": scenario_state.get("action_log_entries", []),
			"include_developer": false,
		}).to_ui_dictionary())


func _open_scenario_replay_menu() -> void:
	_show_menu("剧本复盘", "轻量复盘：点击关键节点会重新打开该剧本局面。", not _runtime_session_finished(), false)
	if menu_preview_box == null:
		return
	menu_overlay.call("clear_preview")
	menu_preview_box.visible = true
	var scenario_state := _runtime_scenario_state()
	var fixture: Dictionary = ScenarioFixtureFactoryScript.new().make_fixture(str(scenario_state.get("active_scenario_id", "")), str(scenario_state.get("active_snapshot_key", "start")))
	var panel := ScenarioReplayPanelScene.instantiate() as Control
	if panel.has_signal("action_requested"):
		panel.connect("action_requested", Callable(self, "_on_scenario_replay_action_requested"))
	menu_preview_box.add_child(panel)
	if panel.has_method("set_replay"):
		panel.call("set_replay", ScenarioReplayPanelSnapshotScript.new().apply_dictionary(fixture.get("replay", {}) as Dictionary).to_ui_dictionary())


func _on_scenario_replay_action_requested(action_id: String) -> void:
	if action_id.begins_with("scenario_replay_"):
		var snapshot_key := action_id.substr("scenario_replay_".length()).strip_edges()
		var coordinator := _game_runtime_coordinator_node()
		if coordinator != null and coordinator.has_method("set_runtime_scenario_snapshot_key"):
			coordinator.call("set_runtime_scenario_snapshot_key", snapshot_key)
		_record_scenario_action("replay", "复盘跳到关键节点：%s" % snapshot_key, "", "fixture_reload", snapshot_key, "scenario_replay")
		_open_scenario_replay_menu()

func _populate_pause_menu_summary_cards() -> void:
	_show_menu_summary_cards([
		{
			"title": "继续观察",
			"body": "回到地图后继续看手牌、匿名卡牌轨道、天气预报和当前区域操作。",
			"meta": "暂停只用于读信息，不改变实时规则。",
			"accent": Color("#22c55e"),
		},
		{
			"title": "复查局势",
			"body": "局势排名看终局距离，经济总览看GDP/商品/商路，情报档案整理推理。",
			"meta": "先看短卡片，再读证据文本。",
			"accent": Color("#38bdf8"),
		},
		{
			"title": "查资料",
			"body": "规则、图鉴、经济和情报都在分支里；主桌只留本局要用的信息。",
			"meta": "长说明收进资料页。",
			"accent": Color("#c084fc"),
		},
		{
			"title": "保存/重开",
			"body": "保存设置或当前局面；也可以回到开局准备，调整席位、对手和角色后重开。",
			"meta": "想换一颗星球，就从这里再开一桌。",
			"accent": Color("#94a3b8"),
		},
	], "暂停速览｜先决定继续、复查、查资料还是重开")
	if _active_runtime_scenario_id() != "" and menu_preview_box != null:
		_add_scenario_pause_actions_panel(menu_preview_box)


func _add_scenario_pause_actions_panel(parent: Container) -> void:
	var in_campaign := active_campaign_chapter_id != "" or not campaign_last_recap.is_empty()
	var panel := ScenarioPauseActionsPanelScene.instantiate() as Control
	if panel == null or not panel.has_method("set_pause_actions"):
		_report_required_ui_scene_missing("ScenarioPauseActionsPanel", "set_pause_actions")
		return
	if panel.has_signal("action_requested"):
		panel.connect("action_requested", Callable(self, "_on_presentation_menu_action_requested"))
	parent.add_child(panel)
	menu_regular_buttons.append(panel)
	panel.call("set_pause_actions", {
		"in_campaign": in_campaign,
		"mode_label": "战役关卡" if in_campaign else "试玩剧本",
		"title": "新手战役" if in_campaign else "试玩剧本",
		"detail": "当前关卡可重开、返回战役、查看日志或复盘。" if in_campaign else "当前剧本可重开、返回选择页或查看行动日志。",
		"actions": [
			{"id": "scenario_pause_restart", "label": "重开本关" if in_campaign else "重开本剧本", "tooltip": "重新进入当前剧本的起点局面。"},
			{"id": "scenario_pause_choose", "label": "返回战役" if in_campaign else "返回剧本选择", "tooltip": "回到新手战役地图。" if in_campaign else "回到试玩剧本库。"},
			{"id": "scenario_pause_log", "label": "查看行动日志", "tooltip": "只显示公开记录和当前玩家私密记录。"},
			{"id": "scenario_pause_replay", "label": "查看复盘" if in_campaign else "复盘快照", "tooltip": "打开战役复盘。" if in_campaign else "打开关键节点快照，不做完整时间回滚。"},
			{"id": "scenario_pause_settings", "label": "教学设置", "tooltip": "开关剧本提示、自动暂停偏好和提示字号。"},
		],
	})


func _restart_active_scenario_from_pause() -> void:
	var scenario_id := _active_runtime_scenario_id()
	if scenario_id != "":
		_start_scenario_from_menu(scenario_id)


func _open_rules_menu() -> void:
	var lines := []
	lines.append("读桌顺序：钱 → 城 → 牌 → 怪兽 → 线索。")
	lines.append("开局：公开角色，选起始怪兽，先把怪兽压到星球。")
	lines.append("赚钱：城市化份额吃GDP；商品、商路和破坏会改现金流。")
	lines.append("出牌：买牌花钱；高阶牌检查地区GDP份额，公开牌轨留下线索。")
	_show_menu(
		"游戏规则",
		"\n".join(lines),
		not _runtime_session_finished()
	)
	_populate_rules_summary_cards()


func _open_standings_menu() -> void:
	var snapshot := _standings_public_snapshot()
	_show_menu("局势排名", String(snapshot.get("summary_text", "还没有可用玩家数据。")), not _runtime_session_finished())
	_populate_standings_summary_cards(snapshot)


func _open_economy_overview_menu() -> void:
	_mark_opening_guide_economy_seen(selected_player)
	var snapshot := _economy_dashboard_public_snapshot()
	_show_menu("经济总览", String(snapshot.get("summary_text", "还没有当前局经济数据。")), not _runtime_session_finished())
	_populate_economy_overview_summary_cards(snapshot)


func _populate_rules_summary_cards() -> void:
	if menu_preview_box == null:
		return
	menu_overlay.call("clear_preview")
	menu_preview_box.visible = true
	_add_rules_quick_reference_board(menu_preview_box)


func _add_rules_quick_reference_board(parent: Container) -> void:
	var board := RulesQuickReferenceBoardScene.instantiate() as Control
	if board == null or not board.has_method("set_board"):
		_report_required_ui_scene_missing("RulesQuickReferenceBoard", "set_board")
		return
	parent.add_child(board)
	board.call("set_board", RulesQuickReferenceSnapshotV06Script.compose(_menu_available_content_width()))


func _populate_standings_summary_cards(snapshot: Dictionary = {}) -> void:
	if menu_preview_box == null:
		return
	if snapshot.is_empty():
		snapshot = _standings_public_snapshot()
	menu_overlay.call("clear_preview")
	menu_preview_box.visible = true
	_add_standings_scoreboard_panel(menu_preview_box, snapshot.get("scoreboard", {}) as Dictionary)


func _add_standings_scoreboard_panel(parent: Container, scoreboard_snapshot: Dictionary) -> void:
	var scoreboard := StandingsScoreboardScene.instantiate() as Control
	if scoreboard == null or not scoreboard.has_method("set_scoreboard"):
		_report_required_ui_scene_missing("StandingsScoreboard", "set_scoreboard")
		return
	parent.add_child(scoreboard)
	scoreboard.call("set_scoreboard", scoreboard_snapshot)


func _standings_public_source_snapshot() -> Dictionary:
	if players.is_empty():
		return {"valid": false}
	_refresh_route_network()
	var victory_snapshot := _victory_control_public_snapshot()
	var victory_rule: Dictionary = victory_snapshot.get("victory_rule", {}) if victory_snapshot.get("victory_rule", {}) is Dictionary else _victory_dynamic_rule()
	var selected_candidate := _victory_player_candidate(selected_player)
	var selected_available := selected_player >= 0 and selected_player < players.size()
	var safe_seats: Array = []
	for entry_variant: Variant in _standing_entries():
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var player_index := int(entry.get("player_index", safe_seats.size()))
		var can_view_private := _runtime_session_finished() or player_index == selected_player
		var safe_entry := {
			"player_index": player_index,
			"name": String(entry.get("name", "玩家")),
			"eliminated": bool(entry.get("eliminated", false)),
			"can_view_private": can_view_private,
		}
		if can_view_private:
			var candidate := _victory_player_candidate(player_index)
			safe_entry.merge({
				"cash": int(entry.get("cash", 0)),
				"active_cities": int(entry.get("active_cities", 0)),
				"top_n_gdp_per_minute": int(candidate.get("top_n_gdp_per_minute", entry.get("score", 0))),
				"controlled_region_count": int(candidate.get("controlled_region_count", 0)),
				"intel_summary": String(entry.get("intel_summary", "情报待结算")),
				"gdp_per_minute": int(entry.get("gdp_per_minute", 0)),
			}, true)
		safe_seats.append(safe_entry)
	return {
		"valid": true,
		"game_over": _runtime_session_finished(),
		"selected_available": selected_available,
		"selected_top_n_gdp_per_minute": int(selected_candidate.get("top_n_gdp_per_minute", 0)) if selected_available else 0,
		"selected_controlled_region_count": int(selected_candidate.get("controlled_region_count", 0)) if selected_available else 0,
		"selected_cash": int(players[selected_player].get("cash", 0)) if selected_available else 0,
		"selected_city_count": _player_active_city_count(selected_player) if selected_available else 0,
		"selected_gdp_per_minute": _player_gdp_per_minute(selected_player) if selected_available else 0,
		"selected_intel_summary": _player_intel_display_summary(selected_player) if selected_available else "情报待结算",
		"required_top_n_gdp_per_minute": int(victory_rule.get("required_top_k_gdp_per_minute", 0)),
		"required_controlled_region_count": int(victory_rule.get("required_region_count", 0)),
		"intel_correct_reward": INTEL_CORRECT_GUESS_CASH,
		"intel_wrong_cost": INTEL_WRONG_GUESS_COST,
		"victory_control": victory_snapshot,
		"countdown_text": _victory_control_status_text(),
		"public_shift_count": _economy_card_aftermath_entries(5).size() + _economy_monster_cash_clue_entries(5).size(),
		"overview_columns": clampi(int(floor(_menu_available_content_width() / 280.0)), 1, 3),
		"kpi_columns": clampi(int(floor(_menu_available_content_width() / 230.0)), 1, 4),
		"seat_columns": clampi(int(floor(_menu_available_content_width() / 260.0)), 1, 4),
		"seat_entries": safe_seats,
		"final_summary_text": str(_final_settlement_runtime_composition_node().call("latest_public_summary")) if _runtime_session_finished() and _final_settlement_runtime_composition_node() != null and _final_settlement_runtime_composition_node().has_method("latest_public_summary") else "",
	}


func _standings_public_snapshot() -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	var value: Variant = coordinator.call("compose_standings_snapshot", _standings_public_source_snapshot()) if coordinator != null and coordinator.has_method("compose_standings_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _populate_economy_overview_summary_cards(snapshot: Dictionary = {}) -> void:
	if menu_preview_box == null:
		return
	if snapshot.is_empty():
		snapshot = _economy_dashboard_public_snapshot()
	menu_overlay.call("clear_preview")
	menu_preview_box.visible = true
	_add_economy_dashboard_panel(menu_preview_box, snapshot.get("dashboard", {}) as Dictionary)


func _add_economy_dashboard_panel(parent: Container, dashboard_snapshot: Dictionary) -> void:
	var dashboard := EconomyDashboardScene.instantiate() as Control
	if dashboard == null or not dashboard.has_method("set_dashboard"):
		_report_required_ui_scene_missing("EconomyDashboard", "set_dashboard")
		return
	dashboard.name = "EconomyDashboardPanel"
	dashboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(dashboard)
	dashboard.call("set_dashboard", dashboard_snapshot)


func _economy_dashboard_public_source_snapshot() -> Dictionary:
	if players.is_empty() or districts.is_empty():
		return {"valid": false}
	_product_market_runtime_call("ensure_catalog")
	_refresh_route_network()
	var card_aftermath_entries := _economy_card_aftermath_entries(5)
	var city_clue_entries := _economy_city_public_clue_entries(6)
	var monster_clue_entries := _economy_monster_cash_clue_entries(5)
	var warehouse_entries := _economy_warehouse_risk_entries(5, selected_player)
	var safe_cash_entries: Array = []
	for entry_variant: Variant in _economy_player_cash_entries():
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var is_private := bool(entry.get("private", false))
		var safe_entry := {
			"name": String(entry.get("name", "玩家")),
			"private": is_private,
			"eliminated": bool(entry.get("eliminated", false)),
		}
		if not is_private:
			safe_entry.merge({
				"score_label": String(entry.get("score_label", "可见预估")),
				"visible_score": int(entry.get("score", 0)),
				"visible_cash": int(entry.get("cash", 0)),
				"city_count": int(entry.get("city_count", 0)),
				"intel_summary": String(entry.get("intel_summary", "")),
				"last_cycle": int(entry.get("last_cycle", 0)),
				"role_income": int(entry.get("role_income", 0)),
				"gdp_per_minute": int(entry.get("gdp_per_minute", 0)),
				"recent_delta": int(entry.get("recent_delta", 0)),
				"window_delta": int(entry.get("window_delta", 0)),
				"path": String(entry.get("path", "")),
				"ledger": String(entry.get("ledger", "暂无")),
			}, true)
		safe_cash_entries.append(safe_entry)
	return {
		"valid": true,
		"selected_name": String(players[selected_player].get("name", "玩家")) if selected_player >= 0 and selected_player < players.size() else "当前玩家",
		"selected_gdp_per_minute": _player_gdp_per_minute(selected_player),
		"business_cycle_count": _product_market_cycle(),
		"monster_count": monster_runtime_controller.auto_monsters.size(),
		"weather_text": weather_runtime_controller.status_text(),
		"clue_count": city_clue_entries.size() + card_aftermath_entries.size() + monster_clue_entries.size(),
		"kpi_columns": clampi(int(floor(_menu_available_content_width() / 220.0)), 1, 4),
		"lane_columns": clampi(int(floor(_menu_available_content_width() / 300.0)), 1, 3),
		"overview_columns": clampi(int(floor(_menu_available_content_width() / 280.0)), 1, 4),
		"current_product_names": _current_run_product_names().duplicate(true),
		"product_entries": _economy_product_entries(),
		"city_entries": _economy_city_income_entries(),
		"card_aftermath_entries": card_aftermath_entries,
		"city_clue_entries": city_clue_entries,
		"monster_clue_entries": monster_clue_entries,
		"warehouse_entries": warehouse_entries,
		"player_cash_entries": safe_cash_entries,
		"inference_lines": _first_entries(_economy_inference_board_lines(selected_player), 12),
	}


func _economy_dashboard_public_snapshot() -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	var value: Variant = coordinator.call("compose_economy_dashboard_snapshot", _economy_dashboard_public_source_snapshot()) if coordinator != null and coordinator.has_method("compose_economy_dashboard_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _final_settlement_runtime_composition_node() -> Node:
	return get_node_or_null("RuntimeServices/FinalSettlementRuntimeComposition")


func _open_intel_dossier_menu() -> void:
	var snapshot := _intel_dossier_public_snapshot(selected_player)
	_show_menu("情报档案", str(snapshot.get("summary_text", "暂无当前局情报。")), not _runtime_session_finished())
	_populate_intel_dossier_snapshot(snapshot)


func _populate_intel_dossier_snapshot(snapshot: Dictionary) -> void:
	if menu_preview_box == null:
		return
	menu_overlay.call("clear_preview")
	menu_preview_box.visible = true
	var board_snapshot := snapshot.get("board", {}) as Dictionary if snapshot.get("board", {}) is Dictionary else {}
	_add_intel_dossier_board_panel(menu_preview_box, board_snapshot)


func _add_intel_dossier_board_panel(parent: Container, board_snapshot: Dictionary) -> void:
	var board := IntelDossierBoardScene.instantiate() as Control
	if board == null or not board.has_method("set_dossier"):
		_report_required_ui_scene_missing("IntelDossierBoard", "set_dossier")
		return
	parent.add_child(board)
	if board.has_signal("action_requested"):
		board.connect("action_requested", Callable(self, "_on_intel_dossier_board_action_requested"))
	board.call("set_dossier", board_snapshot)


func _on_intel_dossier_board_action_requested(action_id: String) -> void:
	var handled := false
	if action_id.begins_with("track_return_"):
		var return_resolution_id := int(action_id.substr("track_return_".length()))
		selected_runtime_card_slot = -1
		_focus_card_resolution_track_entry(return_resolution_id)
		_close_menu()
		handled = true
	elif action_id.begins_with("track_guess_"):
		var guess_resolution_id := int(action_id.substr("track_guess_".length()))
		selected_runtime_card_slot = -1
		_focus_card_resolution_track_entry(guess_resolution_id)
		_close_menu()
		handled = true
	elif action_id.begins_with("track_select_"):
		var resolution_id := int(action_id.substr("track_select_".length()))
		selected_runtime_card_slot = -1
		_focus_card_resolution_track_entry(resolution_id)
		_close_menu()
		handled = true
	elif action_id.begins_with("track_open_"):
		var card_name := action_id.substr("track_open_".length()).strip_edges()
		if card_name != "":
			selected_runtime_card_slot = -1
			_open_card_codex_by_name(card_name)
			handled = true
	elif action_id.begins_with("intel_city_mark_"):
		var values := action_id.substr("intel_city_mark_".length()).split("_", false, 1)
		if values.size() == 2:
			_mark_city_guess_from_intel(int(values[0]), int(values[1]))
			handled = true
	elif action_id.begins_with("intel_city_clear_"):
		_mark_city_guess_from_intel(int(action_id.substr("intel_city_clear_".length())), -1)
		handled = true
	elif action_id.begins_with("intel_city_confidence_"):
		var values := action_id.substr("intel_city_confidence_".length()).split("_", false, 1)
		if values.size() == 2:
			_set_city_guess_confidence_from_intel(int(values[0]), int(values[1]))
			handled = true
	elif action_id.begins_with("intel_city_reason_"):
		var payload := action_id.substr("intel_city_reason_".length())
		var separator := payload.find("_")
		if separator > 0:
			_set_city_guess_reason_from_intel(int(payload.substr(0, separator)), payload.substr(separator + 1))
			handled = true
	elif action_id.begins_with("intel_open_region_"):
		_open_intel_region_codex_link(int(action_id.substr("intel_open_region_".length())))
		handled = true
	elif action_id.begins_with("intel_open_card_"):
		_open_intel_card_codex_link(action_id.substr("intel_open_card_".length()))
		handled = true
	elif action_id.begins_with("intel_open_monster_"):
		_open_intel_monster_codex_link(int(action_id.substr("intel_open_monster_".length())))
		handled = true
	elif action_id.begins_with("intel_open_product_"):
		_open_intel_product_codex_link(action_id.substr("intel_open_product_".length()))
		handled = true
	elif action_id == "intel_open_economy":
		_open_economy_overview_menu()
		handled = true
	if handled:
		_sync_runtime_game_screen(true)


func _intel_dossier_public_snapshot(viewer_index: int = -1) -> Dictionary:
	var source := _intel_dossier_public_source_snapshot(viewer_index if viewer_index >= 0 else selected_player)
	var coordinator := _game_runtime_coordinator_node()
	if coordinator != null and coordinator.has_method("compose_intel_dossier_snapshot"):
		var value: Variant = coordinator.call("compose_intel_dossier_snapshot", source)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	var service := _intel_dossier_public_snapshot_service_node()
	var fallback: Variant = service.call("compose", source) if service != null and service.has_method("compose") else {}
	return (fallback as Dictionary).duplicate(true) if fallback is Dictionary else {}


func _intel_dossier_public_source_snapshot(viewer_index: int) -> Dictionary:
	if players.is_empty() or districts.is_empty() or viewer_index < 0 or viewer_index >= players.size():
		return {"valid": false, "reason": "没有当前玩家或地图数据"}
	_refresh_route_network()
	var city_entries := _intel_city_guess_entries(viewer_index, 8)
	for entry_variant in city_entries:
		var entry := entry_variant as Dictionary
		entry["confidence_label"] = _city_guess_confidence_label(int(entry.get("confidence", CITY_GUESS_CONFIDENCE_DEFAULT))) if bool(entry.get("marked", false)) else "无"
		entry["reason_label"] = _city_guess_reason_label(String(entry.get("reason", CITY_GUESS_REASON_DEFAULT))) if bool(entry.get("marked", false)) else "无"
	var monster_entries := _economy_monster_cash_clue_entries(8)
	for entry_variant in monster_entries:
		var entry := entry_variant as Dictionary
		entry["catalog_index"] = _monster_catalog_index_by_name(String(entry.get("name", "")))
	var city_clue_entries := _economy_city_public_clue_entries(8)
	for entry_variant in city_clue_entries:
		var entry := entry_variant as Dictionary
		var clue_products: Array = entry.get("clue_products", []) as Array
		entry["linked_product"] = String(clue_products[0]) if not clue_products.is_empty() and ProductMarketRuntimeController.PRODUCT_CATALOG.has(String(clue_products[0])) else ""
	var player_options := []
	for player_index in range(players.size()):
		if player_index != viewer_index:
			player_options.append({"player_index": player_index, "label": "标玩家%d" % (player_index + 1)})
	var confidence_options := []
	for confidence in [CITY_GUESS_CONFIDENCE_LOW, CITY_GUESS_CONFIDENCE_MEDIUM, CITY_GUESS_CONFIDENCE_HIGH]:
		confidence_options.append({"value": confidence, "label": _city_guess_confidence_label(confidence)})
	var reason_options := []
	for reason in _city_guess_reason_options():
		reason_options.append({"id": reason, "label": _city_guess_reason_label(reason)})
	return {
		"valid": true,
		"viewer_index": viewer_index,
		"viewer_name": String((players[viewer_index] as Dictionary).get("name", "玩家%d" % (viewer_index + 1))),
		"business_cycle_count": _product_market_cycle(),
		"game_over": _runtime_session_finished(),
		"correct_guess_cash": INTEL_CORRECT_GUESS_CASH,
		"wrong_guess_cost": INTEL_WRONG_GUESS_COST,
		"card_guess_stake": CARD_OWNER_GUESS_STAKE,
		"victory_control": _victory_control_public_snapshot(),
		"stats": _player_intel_exposure_stats(viewer_index),
		"city_entries": city_entries,
		"card_entries": _intel_card_guess_entries(viewer_index, 8),
		"monster_entries": monster_entries,
		"warehouse_entries": _economy_warehouse_risk_entries(8, viewer_index),
		"city_clue_entries": city_clue_entries,
		"player_options": player_options,
		"confidence_options": confidence_options,
		"reason_options": reason_options,
		"kpi_columns": clampi(int(floor(_menu_available_content_width() / 220.0)), 1, 4),
		"clue_columns": clampi(int(floor(_menu_available_content_width() / 300.0)), 1, 3),
		"control_columns": clampi(int(floor(_menu_available_content_width() / 520.0)), 1, 2),
		"link_columns": clampi(int(floor(_menu_available_content_width() / 360.0)), 1, 3),
	}


func _mark_city_guess_from_intel(city_index: int, guessed_player: int) -> void:
	if _mark_city_guess_for_player(selected_player, city_index, guessed_player):
		_jump_to_district_on_table(city_index)
		selected_guess_player = guessed_player
		_open_intel_dossier_menu()


func _set_city_guess_confidence_from_intel(city_index: int, confidence: int) -> void:
	if _set_city_guess_confidence_for_player(selected_player, city_index, confidence):
		_jump_to_district_on_table(city_index)
		_open_intel_dossier_menu()


func _set_city_guess_reason_from_intel(city_index: int, reason: String) -> void:
	if _set_city_guess_reason_for_player(selected_player, city_index, reason):
		_jump_to_district_on_table(city_index)
		_open_intel_dossier_menu()


func _open_intel_region_codex_link(index: int) -> void:
	_codex_navigation_controller_node().return_target = "intel"
	if index >= 0 and index < districts.size():
		_codex_navigation_controller_node().region_codex_index = index
		_jump_to_district_on_table(index)
	_update_region_codex_menu()


func _open_intel_card_codex_link(card_name: String) -> void:
	_codex_navigation_controller_node().return_target = "intel"
	_open_card_codex_by_name(card_name)


func _open_intel_monster_codex_link(monster_index: int) -> void:
	_codex_navigation_controller_node().return_target = "intel"
	_open_bestiary_menu(monster_index)


func _open_intel_product_codex_link(product_name: String) -> void:
	_codex_navigation_controller_node().return_target = "intel"
	if ProductMarketRuntimeController.PRODUCT_CATALOG.has(product_name):
		_codex_navigation_controller_node().product_codex_index = ProductMarketRuntimeController.PRODUCT_CATALOG.find(product_name)
		_codex_navigation_controller_node().previewed_product_codex_index = _codex_navigation_controller_node().product_codex_index
		_codex_navigation_controller_node().product_codex_grid_page = _codex_page_for_index(_codex_navigation_controller_node().product_codex_index, ProductMarketRuntimeController.PRODUCT_CATALOG.size(), _product_codex_entries_per_page())
		_codex_navigation_controller_node().product_codex_show_detail = true
	_update_product_codex_menu()


func _first_entries(entries: Array, limit: int) -> Array:
	var result := []
	for i in range(min(limit, entries.size())):
		result.append(entries[i])
	return result


func _economy_product_entries() -> Array:
	var entries := []
	for product_variant in ProductMarketRuntimeController.PRODUCT_CATALOG:
		var product_name := String(product_variant)
		var entry := _product_market_entry_snapshot(product_name)
		if entry.is_empty():
			continue
		var price := int(entry.get("price", entry.get("base_price", 0)))
		var base_price := int(entry.get("base_price", price))
		var gap := price - base_price
		var trend := int(entry.get("trend", 0))
		var supply := int(entry.get("supply", 0))
		var demand := int(entry.get("demand", 0))
		var disrupted := int(entry.get("disrupted", 0))
		var growth_multiplier := float(entry.get("growth_multiplier", 1.0))
		var route_flow_multiplier := float(entry.get("route_flow_multiplier", 1.0))
		var heat_score := int(round(
			float(gap) * 1.25
			+ float(trend) * 1.5
			+ float(demand) * 9.0
			+ float(disrupted) * 14.0
			+ maxf(0.0, growth_multiplier - 1.0) * 28.0
			+ maxf(0.0, route_flow_multiplier - 1.0) * 16.0
			- float(supply) * 4.0
		))
		var cold_score := int(round(
			float(-gap) * 1.2
			+ float(supply) * 7.0
			- float(demand) * 4.0
			- float(disrupted) * 5.0
			- maxf(0.0, growth_multiplier - 1.0) * 12.0
		))
		entries.append({
			"name": product_name,
			"price": price,
			"base_price": base_price,
			"gap": gap,
			"trend": trend,
			"tier": String(entry.get("tier", _product_market_tier(product_name))),
			"supply": supply,
			"demand": demand,
			"disrupted": disrupted,
			"volatility": int(entry.get("volatility", 0)),
			"weather": _product_market_boon_text(product_name),
			"status_tags": _product_public_status_tags(product_name),
			"path": _product_market_price_path_text(entry, 5),
			"heat_score": heat_score,
			"cold_score": cold_score,
		})
	entries.sort_custom(Callable(self, "_sort_economy_product_hot_entry"))
	return entries


func _sort_economy_product_hot_entry(a: Dictionary, b: Dictionary) -> bool:
	var heat_a := int(a.get("heat_score", 0))
	var heat_b := int(b.get("heat_score", 0))
	if heat_a != heat_b:
		return heat_a > heat_b
	var price_a := int(a.get("price", 0))
	var price_b := int(b.get("price", 0))
	if price_a != price_b:
		return price_a > price_b
	return String(a.get("name", "")) < String(b.get("name", ""))


func _economy_city_income_entries() -> Array:
	var entries := []
	var weather_projection_variant: Variant = _commodity_flow_runtime_call("public_weather_contribution_snapshot")
	var weather_projection: Dictionary = weather_projection_variant if weather_projection_variant is Dictionary else {}
	var public_weather_rows: Array = weather_projection.get("contributions", []) if weather_projection.get("contributions", []) is Array else []
	for index_variant in _active_city_district_indices():
		var index := int(index_variant)
		var city := _district_city(index)
		var competition := _city_competition_matches(index)
		var breakdown := _city_cycle_income_breakdown(index, competition)
		var potential_income := int(breakdown.get("net", 0))
		var city_weather_rows: Array = []
		for weather_row_variant in public_weather_rows:
			if weather_row_variant is Dictionary and int((weather_row_variant as Dictionary).get("region_index", -1)) == index:
				city_weather_rows.append((weather_row_variant as Dictionary).duplicate(true))
		entries.append({
			"district_index": index,
			"name": String(districts[index].get("name", "区域%d" % (index + 1))),
			"owner_view": _city_owner_view_text_for_player(index, selected_player),
			"intel_hint": _city_intel_hint_for_player(index, selected_player),
			"income": potential_income,
			"last_income": int(city.get("last_income", 0)),
			"gdp_trend": _city_gdp_trend_text(city),
			"products": _city_product_names(city),
			"demands": _city_demand_names(city),
			"supplied": int(city.get("supplied_demands", 0)),
			"demand_count": (city.get("demands", []) as Array).size(),
			"disrupted": int(city.get("trade_disrupted_routes", 0)),
			"competition": competition,
			"flow": _city_route_flow_status_text(city),
			"contract": _city_contract_status_text(city),
			"status_tags": _city_public_status_tags(city),
			"breakdown": _city_income_breakdown_summary(breakdown),
			"weather_contributions": city_weather_rows,
		})
	entries.sort_custom(Callable(self, "_sort_economy_city_income_entry"))
	return entries


func _sort_economy_city_income_entry(a: Dictionary, b: Dictionary) -> bool:
	var income_a := int(a.get("income", 0))
	var income_b := int(b.get("income", 0))
	if income_a != income_b:
		return income_a > income_b
	var disrupted_a := int(a.get("disrupted", 0))
	var disrupted_b := int(b.get("disrupted", 0))
	if disrupted_a != disrupted_b:
		return disrupted_a < disrupted_b
	return String(a.get("name", "")) < String(b.get("name", ""))


func _city_owner_view_text_for_player(city_index: int, viewer_index: int) -> String:
	if city_index < 0 or city_index >= districts.size():
		return "无城市"
	var city := _district_city(city_index)
	if not _city_is_active(city):
		return "城市废墟"
	var city_owner := int(city.get("owner", -1))
	if viewer_index >= 0 and viewer_index < players.size() and city_owner == viewer_index:
		return "己方"
	if viewer_index >= 0 and viewer_index < players.size():
		var guesses: Dictionary = players[viewer_index].get("city_guesses", {})
		var guess := int(guesses.get(city_index, -1))
		if guess >= 0:
			return "我的推测:玩家%d" % (guess + 1)
	return "未知业主"


func _economy_warehouse_risk_entries(limit: int = 5, viewer_index: int = -1) -> Array:
	var entries := []
	for index_variant in _active_city_district_indices():
		var index := int(index_variant)
		var city := _district_city(index)
		var pressure := _city_warehouse_stockpile_pressure(city)
		if pressure <= 0:
			continue
		var products: Array = city.get("warehouse_stockpile_products", [])
		var count := int(city.get("warehouse_stockpile_count", 0))
		var units := int(city.get("warehouse_stockpile_units", 0))
		var expires_at := float(city.get("warehouse_stockpile_expires_at", -1.0))
		var seconds_left := maxf(0.0, expires_at - game_time) if expires_at >= 0.0 else -1.0
		entries.append({
			"district_index": index,
			"name": String(districts[index].get("name", "城市")),
			"owner_view": _city_owner_view_text_for_player(index, viewer_index),
			"intel_hint": _city_intel_hint_for_player(index, viewer_index),
			"pressure": pressure,
			"count": count,
			"units": units,
			"products": products.duplicate(true),
			"status": _city_warehouse_stockpile_status_text(city),
			"seconds_left": seconds_left,
			"income": int(city.get("last_income", 0)),
			"potential_income": _city_cycle_income(index, _city_competition_matches(index)),
			"latest_clue": _latest_city_public_clue_text(city),
		})
	entries.sort_custom(Callable(self, "_sort_economy_warehouse_risk_entry"))
	return _first_entries(entries, limit)


func _sort_economy_warehouse_risk_entry(a: Dictionary, b: Dictionary) -> bool:
	var pressure_a := int(a.get("pressure", 0))
	var pressure_b := int(b.get("pressure", 0))
	if pressure_a != pressure_b:
		return pressure_a > pressure_b
	var units_a := int(a.get("units", 0))
	var units_b := int(b.get("units", 0))
	if units_a != units_b:
		return units_a > units_b
	var income_a := int(a.get("potential_income", 0))
	var income_b := int(b.get("potential_income", 0))
	if income_a != income_b:
		return income_a > income_b
	return String(a.get("name", "")) < String(b.get("name", ""))


func _intel_city_guess_entries(viewer_index: int, limit: int = 6) -> Array:
	var entries := []
	if viewer_index < 0 or viewer_index >= players.size():
		return entries
	var player: Dictionary = players[viewer_index]
	var guesses: Dictionary = player.get("city_guesses", {})
	var confidences: Dictionary = player.get("city_guess_confidence", {})
	var reasons: Dictionary = player.get("city_guess_reasons", {})
	for index_variant in _active_city_district_indices():
		var city_index := int(index_variant)
		var city := _district_city(city_index)
		var city_owner := int(city.get("owner", -1))
		if city_owner == viewer_index:
			continue
		var guess := int(guesses.get(city_index, -1))
		var marked := guess >= 0 and guess < players.size()
		var competition := _city_competition_matches(city_index)
		var breakdown := _city_cycle_income_breakdown(city_index, competition)
		var result_text := "终局待判"
		if _runtime_session_finished() and guess >= 0:
			result_text = "命中+¥%d" % INTEL_CORRECT_GUESS_CASH if guess == city_owner else "错标-¥%d" % INTEL_WRONG_GUESS_COST
		var entry := {
			"district_index": city_index,
			"name": String(districts[city_index].get("name", "区域%d" % (city_index + 1))),
			"guess": guess,
			"marked": marked,
			"confidence": _normalized_city_guess_confidence(int(confidences.get(city_index, CITY_GUESS_CONFIDENCE_DEFAULT))) if marked else 0,
			"reason": _normalized_city_guess_reason(String(reasons.get(city_index, CITY_GUESS_REASON_DEFAULT))) if marked else "",
			"hint": _city_intel_hint_for_player(city_index, viewer_index),
			"result": result_text,
			"potential_income": int(breakdown.get("net", 0)),
			"last_income": int(city.get("last_income", 0)),
			"products": _city_product_names(city),
			"demands": _city_demand_names(city),
			"competition": competition,
			"disrupted": int(city.get("trade_disrupted_routes", 0)),
			"latest_clue": _latest_city_public_clue_text(city),
			"warehouse_pressure": _city_warehouse_stockpile_pressure(city),
			"warehouse_status": _city_warehouse_stockpile_status_text(city),
		}
		entry["priority"] = _city_intel_priority_score(entry)
		entries.append(entry)
	entries.sort_custom(Callable(self, "_sort_intel_city_guess_entry"))
	return _first_entries(entries, limit)


func _sort_intel_city_guess_entry(a: Dictionary, b: Dictionary) -> bool:
	var a_priority := int(a.get("priority", 0))
	var b_priority := int(b.get("priority", 0))
	if a_priority != b_priority:
		return a_priority > b_priority
	var a_marked := bool(a.get("marked", false))
	var b_marked := bool(b.get("marked", false))
	if a_marked != b_marked:
		return not a_marked
	var a_income := int(a.get("potential_income", 0))
	var b_income := int(b.get("potential_income", 0))
	if a_income != b_income:
		return a_income > b_income
	return String(a.get("name", "")) < String(b.get("name", ""))


func _city_intel_priority_score(entry: Dictionary) -> int:
	var score := 0
	score += clampi(int(float(int(entry.get("potential_income", 0))) / 10.0), 0, 80)
	score += clampi(int(float(int(entry.get("last_income", 0))) / 20.0), 0, 30)
	score += int(entry.get("competition", 0)) * 18
	score += int(entry.get("disrupted", 0)) * 16
	score += clampi(int(float(int(entry.get("warehouse_pressure", 0))) / 2.0), 0, 120)
	score += (entry.get("products", []) as Array).size() * 4
	score += (entry.get("demands", []) as Array).size() * 4
	var latest_clue := String(entry.get("latest_clue", ""))
	if latest_clue != "" and latest_clue != "暂无公开线索":
		score += 20
	if bool(entry.get("marked", false)):
		match _normalized_city_guess_confidence(int(entry.get("confidence", CITY_GUESS_CONFIDENCE_DEFAULT))):
			CITY_GUESS_CONFIDENCE_LOW:
				score += 18
			CITY_GUESS_CONFIDENCE_MEDIUM:
				score += 8
			CITY_GUESS_CONFIDENCE_HIGH:
				score -= 12
	else:
		score += 45
	return maxi(0, score)


func _normalized_city_guess_confidence(confidence: int) -> int:
	return clampi(confidence, CITY_GUESS_CONFIDENCE_LOW, CITY_GUESS_CONFIDENCE_HIGH)


func _city_guess_confidence_label(confidence: int) -> String:
	match _normalized_city_guess_confidence(confidence):
		CITY_GUESS_CONFIDENCE_HIGH:
			return "高"
		CITY_GUESS_CONFIDENCE_MEDIUM:
			return "中"
		_:
			return "低"


func _city_guess_reason_options() -> Array:
	return [
		CITY_GUESS_REASON_PRODUCT,
		CITY_GUESS_REASON_ROUTE,
		CITY_GUESS_REASON_CARD,
		CITY_GUESS_REASON_MONSTER,
		CITY_GUESS_REASON_ROLE,
		CITY_GUESS_REASON_INTUITION,
	]


func _normalized_city_guess_reason(reason: String) -> String:
	if _city_guess_reason_options().has(reason):
		return reason
	return CITY_GUESS_REASON_DEFAULT


func _city_guess_reason_label(reason: String) -> String:
	match _normalized_city_guess_reason(reason):
		CITY_GUESS_REASON_PRODUCT:
			return "商品竞争"
		CITY_GUESS_REASON_ROUTE:
			return "商路线索"
		CITY_GUESS_REASON_CARD:
			return "卡牌条件"
		CITY_GUESS_REASON_MONSTER:
			return "怪兽资金"
		CITY_GUESS_REASON_ROLE:
			return "身份能力"
		_:
			return "直觉"


func _latest_city_public_clue_text(city: Dictionary) -> String:
	var public_clues := city.get("public_clues", []) as Array
	if not public_clues.is_empty():
		for i in range(public_clues.size() - 1, -1, -1):
			var clue_text := _city_public_clue_display_text(public_clues[i])
			if clue_text != "":
				return clue_text
	var last_clue := String(city.get("last_public_clue", ""))
	return last_clue if last_clue != "" else "暂无公开线索"


func _intel_card_guess_entries(viewer_index: int, limit: int = 5) -> Array:
	var entries := []
	var source_entries := _public_card_resolution_owner_entries()
	for i in range(source_entries.size() - 1, -1, -1):
		var entry_variant: Variant = source_entries[i]
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var skill: Dictionary = entry.get("skill", {}) as Dictionary
		if skill.is_empty():
			continue
		var card_name := String(skill.get("name", ""))
		var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
		var owner_index := int(entry.get("player_index", -1))
		var owner_revealed := bool(entry.get("public_owner_revealed", false))
		var guessers: Array = entry.get("guessers", []) as Array
		var known_owner := _private_known_card_owner_for_entry(viewer_index, entry)
		var status := "归属待猜，可押注¥%d" % _card_owner_guess_stake_for_player(viewer_index)
		if owner_revealed:
			status = String(entry.get("public_owner_label", "归属已公开"))
		elif known_owner >= 0 and known_owner < players.size():
			status = "我已查明：玩家%d｜尚未公开" % (known_owner + 1)
		elif viewer_index == owner_index:
			status = "我打出的牌｜仅当前视角可知"
		elif viewer_index >= 0 and guessers.has(viewer_index):
			status = "我已押注｜真实归属待确认"
		var time_value := float(entry.get("resolved_time", entry.get("queued_order", -1.0)))
		var resolution_presentation := _card_resolution_presentation_snapshot(skill, entry)
		entries.append({
			"resolution_id": resolution_id,
			"card": _card_resolution_entry_card_label(entry),
			"card_name": card_name,
			"track_state": _intel_card_guess_track_state(entry, resolution_id),
			"status": status,
			"target": String(resolution_presentation.get("target_text", "目标未知")),
			"requirement": _card_resolution_play_requirement_text(entry).replace("打出条件：", ""),
			"tip": _card_resolution_tip_clue_text(entry),
			"aftermath": String(entry.get("aftermath_clue", "")),
			"style": String(resolution_presentation.get("effect_style_label", "卡牌")),
			"time": time_value,
			"revealed": owner_revealed,
			"focused": resolution_id >= 0 and resolution_id == selected_card_resolution_id,
		})
	entries.sort_custom(Callable(self, "_sort_intel_card_guess_entry"))
	return _first_entries(entries, limit)


func _intel_card_guess_track_state(entry: Dictionary, resolution_id: int) -> String:
	if resolution_id < 0:
		return "牌轨"
	if int(_card_resolution_active_entry().get("resolution_id", _card_resolution_active_entry().get("queued_order", -1))) == resolution_id:
		return "当前展示"
	for i in range(_card_resolution_current_queue().size()):
		var queue_variant: Variant = _card_resolution_current_queue()[i]
		if not (queue_variant is Dictionary):
			continue
		var queue_entry := queue_variant as Dictionary
		if int(queue_entry.get("resolution_id", queue_entry.get("queued_order", -1))) != resolution_id:
			continue
		var group_position := maxi(1, int(queue_entry.get("group_position", i + 1)))
		var group_order := maxi(1, int(queue_entry.get("group_order", 1)))
		var group_size := maxi(1, int(queue_entry.get("group_size", 1)))
		if card_resolution_auction_open:
			return "竞拍组%d·%d/%d" % [group_position, group_order, group_size]
		if card_resolution_batch_locked or not _card_resolution_active_entry().is_empty():
			return "锁定组%d·%d/%d" % [group_position, group_order, group_size]
		return "组织组%d·%d/%d" % [group_position, group_order, group_size]
	for i in range(_card_resolution_next_queue().size()):
		var next_variant: Variant = _card_resolution_next_queue()[i]
		if next_variant is Dictionary:
			var next_entry := next_variant as Dictionary
			if int(next_entry.get("resolution_id", next_entry.get("queued_order", -1))) == resolution_id:
				return "下批等待%d" % (i + 1)
	for history_variant in resolved_card_history:
		if history_variant is Dictionary:
			var history_entry := history_variant as Dictionary
			if int(history_entry.get("resolution_id", history_entry.get("queued_order", -1))) == resolution_id:
				return "已结算"
	return String(entry.get("track_state", "牌轨"))


func _sort_intel_card_guess_entry(a: Dictionary, b: Dictionary) -> bool:
	var a_focused := bool(a.get("focused", false))
	var b_focused := bool(b.get("focused", false))
	if a_focused != b_focused:
		return a_focused
	var a_time := float(a.get("time", -1.0))
	var b_time := float(b.get("time", -1.0))
	if not is_equal_approx(a_time, b_time):
		return a_time > b_time
	return String(a.get("card", "")) < String(b.get("card", ""))


func _product_public_status_tags(product_name: String) -> Array:
	var entry := _product_market_entry_snapshot(product_name)
	if entry.is_empty():
		return []
	var tags := []
	var growth_multiplier := float(entry.get("growth_multiplier", 1.0))
	if growth_multiplier > 1.001:
		tags.append("增速×%.2f/%s" % [
			growth_multiplier,
			_boon_duration_text(_remaining_effect_seconds(entry, "growth_seconds", "growth_turns")),
		])
	var route_multiplier := float(entry.get("route_flow_multiplier", 1.0))
	if route_multiplier > 1.001:
		tags.append("商路×%.2f/%s" % [
			route_multiplier,
			_boon_duration_text(_remaining_effect_seconds(entry, "route_flow_seconds", "route_flow_turns")),
		])
	var contract_seconds := _remaining_effect_seconds(entry, "market_contract_seconds", "market_contract_turns")
	var contract_demand := int(entry.get("market_contract_demand", 0))
	var contract_supply := int(entry.get("market_contract_supply", 0))
	if contract_seconds > 0.0 and (contract_demand > 0 or contract_supply > 0):
		var pressure_parts := []
		if contract_demand > 0:
			pressure_parts.append("需+%d" % contract_demand)
		if contract_supply > 0:
			pressure_parts.append("供+%d" % contract_supply)
		tags.append("商品合约%s/%s" % [
			"/".join(pressure_parts),
			_boon_duration_text(contract_seconds),
		])
	var volatility := int(entry.get("volatility", 0))
	if volatility >= 12:
		tags.append("高波动%d" % volatility)
	var futures_text := _product_market_futures_public_text(product_name, true)
	if futures_text != "":
		tags.append(futures_text)
	return tags


func _city_public_status_tags(city: Dictionary) -> Array:
	var tags := []
	var contract_income := int(city.get("contract_income_bonus", 0))
	if contract_income > 0:
		tags.append("城市合约+%d/%s" % [
			contract_income,
			_boon_duration_text(_remaining_effect_seconds(city, "contract_seconds", "contract_turns")),
		])
	var route_multiplier := float(city.get("route_flow_multiplier", 1.0))
	if route_multiplier > 1.001:
		tags.append("流通×%.2f/%s" % [
			route_multiplier,
			_boon_duration_text(_remaining_effect_seconds(city, "route_flow_seconds", "route_flow_turns")),
		])
	var disrupted := int(city.get("trade_disrupted_routes", 0))
	if disrupted > 0:
		tags.append("断路%d" % disrupted)
	var competition := int(city.get("competition_matches", 0))
	if competition > 0:
		tags.append("竞争%d" % competition)
	var revenue_bonus := int(city.get("revenue_bonus", 0))
	if revenue_bonus > 0:
		tags.append("永久收入+%d" % revenue_bonus)
	var warehouse_text := _city_warehouse_stockpile_status_text(city)
	if warehouse_text != "":
		tags.append(warehouse_text)
	return tags


func _economy_card_aftermath_entries(limit: int = 5) -> Array:
	var entries := []
	for i in range(resolved_card_history.size() - 1, -1, -1):
		if entries.size() >= limit:
			break
		var entry_variant: Variant = resolved_card_history[i]
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var clue := String(entry.get("aftermath_clue", ""))
		if clue == "":
			continue
		var skill: Dictionary = entry.get("skill", {}) as Dictionary
		if skill.is_empty():
			continue
		var card_name := String(skill.get("name", "匿名卡牌"))
		var card_label := _card_display_name(card_name)
		if card_label == "":
			card_label = card_name
		var resolution_presentation := _card_resolution_presentation_snapshot(skill, entry)
		entries.append({
			"card": card_label,
			"style": String(resolution_presentation.get("effect_style_label", "卡牌")),
			"clue": clue,
			"tip_clue": _card_resolution_tip_clue_text(entry),
			"target": String(resolution_presentation.get("target_text", "目标未知")),
			"resolved_time": float(entry.get("resolved_time", -1.0)),
			"owner_known": bool(entry.get("public_owner_revealed", false)),
		})
	return entries


func _economy_city_public_clue_entries(limit: int = 6, product_filter: String = "") -> Array:
	var entries := []
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		if not _city_is_active(city):
			continue
		var city_products := _city_product_names(city)
		var city_demands := _city_demand_names(city)
		var clues := city.get("public_clues", []) as Array
		if clues.is_empty():
			var last_clue := String(city.get("last_public_clue", ""))
			if last_clue != "":
				clues = [last_clue]
		for i in range(clues.size() - 1, -1, -1):
			var clue_entry := _normalize_city_public_clue_entry(clues[i])
			var clue_text := String(clue_entry.get("text", ""))
			if clue_text == "":
				continue
			var clue_products := (clue_entry.get("products", []) as Array).duplicate(true)
			if product_filter != "" and not clue_products.has(product_filter) and not city_products.has(product_filter) and not city_demands.has(product_filter):
				continue
			entries.append({
				"district": String(districts[city_index].get("name", "城市")),
				"city_index": city_index,
				"clue": clue_text,
				"time": float(clue_entry.get("time", -1.0)),
				"cycle": int(clue_entry.get("cycle", 0)),
				"kind": String(clue_entry.get("kind", "公开")),
				"clue_products": clue_products,
				"owner_visible": int(city.get("owner", -1)) == selected_player,
				"income": int(city.get("last_income", 0)),
				"products": city_products,
				"demands": city_demands,
			})
	entries.sort_custom(Callable(self, "_sort_economy_city_public_clue_entry"))
	return _first_entries(entries, limit)


func _sort_economy_city_public_clue_entry(a: Dictionary, b: Dictionary) -> bool:
	var a_time := float(a.get("time", -1.0))
	var b_time := float(b.get("time", -1.0))
	if not is_equal_approx(a_time, b_time):
		return a_time > b_time
	return String(a.get("clue", "")) > String(b.get("clue", ""))


func _economy_city_public_clue_line(entry: Dictionary) -> String:
	var owner_text := "己方城市" if bool(entry.get("owner_visible", false)) else "业主未知"
	var time_text := "T+%.0fs" % float(entry.get("time", 0.0)) if float(entry.get("time", -1.0)) >= 0.0 else "时间未知"
	var clue_products := entry.get("clue_products", []) as Array
	return "%s｜%s｜%s｜类型:%s｜线索商品:%s｜上次收入%d｜生产:%s｜需求:%s｜线索:%s" % [
		time_text,
		String(entry.get("district", "城市")),
		owner_text,
		String(entry.get("kind", "公开")),
		_limited_name_list(clue_products, 3, "无"),
		int(entry.get("income", 0)),
		_limited_name_list(entry.get("products", []) as Array, 3, "无"),
		_limited_name_list(entry.get("demands", []) as Array, 3, "无"),
		String(entry.get("clue", "")),
	]


func _economy_monster_cash_clue_entries(limit: int = 5) -> Array:
	var entries := []
	for slot in range(monster_runtime_controller.auto_monsters.size()):
		var actor: Dictionary = monster_runtime_controller.auto_monsters[slot]
		var clue := String(actor.get("owner_clue", ""))
		var total_lost := int(actor.get("owner_damage_cash_lost", 0))
		if clue == "" and total_lost <= 0:
			continue
		var owner_index := int(actor.get("owner", -1))
		var owner_public := bool(actor.get("owner_revealed", false)) and owner_index >= 0 and owner_index < players.size()
		var owner_text := "归属未公开"
		if owner_public:
			owner_text = "归属已公开：%s" % String(players[owner_index].get("name", "玩家%d" % (owner_index + 1)))
		entries.append({
			"slot": slot,
			"name": String(actor.get("name", "怪兽")),
			"rank": int(actor.get("rank", 1)),
			"owner_text": owner_text,
			"owner_public": owner_public,
			"clue": clue,
			"recent_loss": int(actor.get("last_owner_damage_cash_loss", 0)),
			"recent_damage": int(actor.get("last_owner_damage_amount", 0)),
			"recent_source": String(actor.get("last_owner_damage_source", "")),
			"recent_time": float(actor.get("last_owner_damage_time", -1.0)),
			"total_lost": total_lost,
			"cash_pool": int(actor.get("owner_damage_cash_pool", 0)),
			"cash_total": int(actor.get("owner_damage_cash_total", 0)),
			"down": bool(actor.get("down", false)),
		})
	entries.sort_custom(Callable(self, "_sort_economy_monster_cash_clue_entry"))
	return _first_entries(entries, limit)


func _sort_economy_monster_cash_clue_entry(a: Dictionary, b: Dictionary) -> bool:
	var time_a := float(a.get("recent_time", -1.0))
	var time_b := float(b.get("recent_time", -1.0))
	if not is_equal_approx(time_a, time_b):
		return time_a > time_b
	var lost_a := int(a.get("total_lost", 0))
	var lost_b := int(b.get("total_lost", 0))
	if lost_a != lost_b:
		return lost_a > lost_b
	return int(a.get("slot", 0)) < int(b.get("slot", 0))


func _economy_inference_board_lines(viewer_index: int) -> Array:
	if viewer_index < 0 or viewer_index >= players.size():
		return ["无当前玩家，暂不能生成推理板。"]
	return [
		_economy_inference_city_guess_line(viewer_index),
		_economy_inference_public_card_owner_line(),
		_economy_inference_card_requirement_line(viewer_index),
		_economy_inference_public_monster_owner_line(),
		"交叉提示｜把城市私标、公开卡牌归属、怪兽资金线索、商品/商路变化一起比对；没有一项单独等于真相。",
	]


func _economy_inference_city_guess_line(viewer_index: int) -> String:
	var player: Dictionary = players[viewer_index]
	var guesses: Dictionary = player.get("city_guesses", {})
	var guess_counts := {}
	var own_city_count := 0
	var unmarked_unknown_count := 0
	for index_variant in _active_city_district_indices():
		var index := int(index_variant)
		var city := _district_city(index)
		var city_owner := int(city.get("owner", -1))
		if city_owner == viewer_index:
			own_city_count += 1
			continue
		var guess := int(guesses.get(index, -1))
		if guess >= 0 and guess < players.size():
			guess_counts[guess] = int(guess_counts.get(guess, 0)) + 1
		else:
			unmarked_unknown_count += 1
	var pieces := []
	for player_index in range(players.size()):
		var count := int(guess_counts.get(player_index, 0))
		if count > 0:
			pieces.append("玩家%d×%d" % [player_index + 1, count])
	var guess_text := "暂无标注" if pieces.is_empty() else " / ".join(pieces)
	return "城市私标｜%s｜未标注陌生城市%d｜己方城市%d｜只显示我的私人标注，不验证正误" % [
		guess_text,
		unmarked_unknown_count,
		own_city_count,
	]


func _economy_inference_public_card_owner_line() -> String:
	var counts := {}
	var examples := {}
	for entry_variant in _public_card_resolution_owner_entries():
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if not bool(entry.get("public_owner_revealed", false)):
			continue
		var entry_owner := int(entry.get("player_index", -1))
		if entry_owner < 0 or entry_owner >= players.size():
			continue
		counts[entry_owner] = int(counts.get(entry_owner, 0)) + 1
		if not examples.has(entry_owner):
			examples[entry_owner] = []
		var owner_examples: Array = examples[entry_owner]
		if owner_examples.size() < 2:
			owner_examples.append(_card_resolution_entry_card_label(entry))
			examples[entry_owner] = owner_examples
	var pieces := []
	for player_index in range(players.size()):
		var count := int(counts.get(player_index, 0))
		if count <= 0:
			continue
		var owner_examples: Array = examples.get(player_index, []) as Array
		var example_text := ""
		if not owner_examples.is_empty():
			example_text = "（%s）" % _limited_name_list(owner_examples, 2)
		pieces.append("玩家%d×%d%s" % [player_index + 1, count, example_text])
	if pieces.is_empty():
		return "公开卡牌归属｜暂无被竞猜揭晓的卡牌"
	return "公开卡牌归属｜%s｜只统计已经贴公开归属标签的匿名卡" % " / ".join(pieces)


func _public_card_resolution_owner_entries() -> Array:
	var entries := []
	for entry_variant in resolved_card_history:
		if entry_variant is Dictionary:
			entries.append(entry_variant)
	if not _card_resolution_active_entry().is_empty():
		entries.append(_card_resolution_active_entry())
	for entry_variant in _card_resolution_current_queue():
		if entry_variant is Dictionary:
			entries.append(entry_variant)
	for entry_variant in _card_resolution_next_queue():
		if entry_variant is Dictionary:
			entries.append(entry_variant)
	return entries


func _economy_inference_card_requirement_line(viewer_index: int) -> String:
	var pieces := []
	for entry_variant in _recent_card_requirement_entries(3):
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var text := _card_requirement_inference_text(entry, viewer_index)
		if text != "":
			pieces.append(text)
	if pieces.is_empty():
		return "卡牌条件反推｜暂无公开匿名牌条件"
	return "卡牌条件反推｜%s｜只对照我方GDP份额，不扫描对手经济" % "；".join(pieces)


func _recent_card_requirement_entries(limit: int = 3) -> Array:
	var entries := []
	if not _card_resolution_active_entry().is_empty():
		entries.append(_card_resolution_active_entry())
	for entry_variant in _card_resolution_current_queue():
		if entries.size() >= limit:
			return entries
		if entry_variant is Dictionary:
			entries.append(entry_variant)
	for entry_variant in _card_resolution_next_queue():
		if entries.size() >= limit:
			return entries
		if entry_variant is Dictionary:
			entries.append(entry_variant)
	for i in range(resolved_card_history.size() - 1, -1, -1):
		if entries.size() >= limit:
			break
		var entry_variant: Variant = resolved_card_history[i]
		if entry_variant is Dictionary:
			entries.append(entry_variant)
	return entries


func _card_requirement_inference_text(entry: Dictionary, viewer_index: int) -> String:
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	if skill.is_empty():
		return ""
	var card_label := _card_resolution_entry_card_label(entry)
	var owner_text := "归属待猜"
	if bool(entry.get("public_owner_revealed", false)):
		var owner_index := int(entry.get("player_index", -1))
		if owner_index >= 0 and owner_index < players.size():
			owner_text = "归属玩家%d" % (owner_index + 1)
	var printed_requirement := _card_play_requirement_snapshot(int(entry.get("player_index", -1)), skill)
	var required := int(entry.get("play_requirement_gdp_share_percent", printed_requirement.get("required_share_percent", 0)))
	var scope := String(entry.get("play_requirement_scope", printed_requirement.get("scope", CardPlayRequirementPolicyScript.SCOPE_OWN_BEST_REGION)))
	var cash_cost := int(entry.get("play_cash_cost", printed_requirement.get("cash_cost", 0)))
	var requirement_text := "免GDP门槛"
	if required > 0:
		var viewer_skill := skill.duplicate(true)
		if scope != CardPlayRequirementPolicyScript.SCOPE_OWN_BEST_REGION:
			viewer_skill["play_requirement_district"] = int(entry.get("play_requirement_district", entry.get("selected_district", -1)))
		var viewer_status := _card_play_requirement_snapshot(viewer_index, viewer_skill)
		var availability_text := "我方可满足" if bool(viewer_status.get("requirement_satisfied", false)) else "我方不足"
		requirement_text = "%sGDP≥%d%%｜%s" % [CardPlayRequirementPolicyScript.scope_label(scope), required, availability_text]
	if cash_cost > 0:
		requirement_text += "｜费用¥%d" % cash_cost
	return "%s:%s｜%s" % [
		_short_event_label(card_label, 10),
		requirement_text,
		owner_text,
	]


func _economy_inference_public_monster_owner_line() -> String:
	var counts := {}
	var examples := {}
	for slot in range(monster_runtime_controller.auto_monsters.size()):
		var actor: Dictionary = monster_runtime_controller.auto_monsters[slot]
		var monster_owner := int(actor.get("owner", -1))
		if not bool(actor.get("owner_revealed", false)) or monster_owner < 0 or monster_owner >= players.size():
			continue
		counts[monster_owner] = int(counts.get(monster_owner, 0)) + 1
		if not examples.has(monster_owner):
			examples[monster_owner] = []
		var owner_examples: Array = examples[monster_owner]
		if owner_examples.size() < 2:
			owner_examples.append("%s%s累计¥%d" % [
				String(actor.get("name", "怪兽")),
				_level_text(clampi(int(actor.get("rank", 1)), 1, 4)),
				int(actor.get("owner_damage_cash_lost", 0)),
			])
			examples[monster_owner] = owner_examples
	var pieces := []
	for player_index in range(players.size()):
		var count := int(counts.get(player_index, 0))
		if count <= 0:
			continue
		var owner_examples: Array = examples.get(player_index, []) as Array
		var example_text := ""
		if not owner_examples.is_empty():
			example_text = "（%s）" % _limited_name_list(owner_examples, 2)
		pieces.append("玩家%d×%d%s" % [player_index + 1, count, example_text])
	if pieces.is_empty():
		return "公开怪兽归属｜暂无因受伤资金线索而公开的怪兽"
	return "公开怪兽归属｜%s｜归属来自公开资金损失，不显示无关现金总额" % " / ".join(pieces)


func _economy_player_cash_entries() -> Array:
	var entries := []
	for i in range(players.size()):
		var player: Dictionary = players[i]
		entries.append({
			"player_index": i,
			"name": String(player.get("name", "玩家%d" % (i + 1))),
			"cash": int(player.get("cash", 0)),
			"score": _victory_player_progress_metric(i),
			"score_label": "前K区商品GDP/min",
			"intel_summary": _player_intel_display_summary(i),
			"last_cycle": _player_commodity_sale_income(i),
			"role_income": int(player.get("total_role_income", 0)),
			"gdp_per_minute": _player_gdp_per_minute(i),
			"recent_delta": _player_recent_cash_delta(player),
			"window_delta": _player_cash_window_delta(player),
			"path": _player_cash_path_text(player, 6),
			"ledger": _player_economic_ledger_text(player, 2) if i == selected_player else "私人账本（不公开）",
			"city_count": _player_active_city_count(i),
			"private": not _runtime_session_finished() and i != selected_player,
			"eliminated": _player_is_eliminated(i),
		})
	return _order_entries_by_victory_rank(entries) if _runtime_session_finished() else entries


func _open_compendium_menu() -> void:
	_codex_navigation_controller_node().return_target = "main"
	_present_codex_page(
		"图鉴",
		"资料大厅：角色、卡牌、商品、区域与怪兽生态都在这里查看。怪兽牌属于卡牌图鉴；怪兽生态档案展示场上怪兽的行动、偏好和破坏方式。\n图鉴分支：角色图鉴｜怪兽生态档案｜卡牌图鉴｜商品图鉴｜区域图鉴。",
		{
			"mode": "compendium",
			"view": "hub",
			"hub": CompendiumHubSnapshotScript.compose(_menu_available_content_width()),
			"navigation": _codex_navigation_data(false, false, _catalog_back_button_text()),
		}
	)


func _menu_action_accent_for_text(button_text: String) -> Color:
	if button_text.contains("经济"):
		return Color("#4ade80")
	if button_text.contains("情报") or button_text.contains("角色"):
		return Color("#c084fc")
	if button_text.contains("卡牌"):
		return Color("#f472b6")
	if button_text.contains("怪兽"):
		return Color("#fb7185")
	if button_text.contains("商品"):
		return Color("#facc15")
	if button_text.contains("区域") or button_text.contains("地图"):
		return Color("#38bdf8")
	if button_text.contains("开局"):
		return Color("#67e8f9")
	return Color("#93c5fd")


func _standing_entries() -> Array:
	var entries := []
	for i in range(players.size()):
		var player: Dictionary = players[i]
		var active_city_count := _player_active_city_count(i)
		var gdp_per_minute := _player_gdp_per_minute(i)
		var intel_stats := _player_intel_stats(i)
		var intel_cash := int(intel_stats.get("cash", 0))
		entries.append({
			"player_index": i,
			"name": String(player.get("name", "玩家%d" % (i + 1))),
			"cash": int(player.get("cash", 0)),
			"active_cities": active_city_count,
			"score": _victory_player_progress_metric(i),
			"score_label": "前K区商品GDP/min",
			"intel_cash": intel_cash if _runtime_session_finished() else 0,
			"intel_summary": _player_intel_display_summary(i),
			"gdp_per_minute": gdp_per_minute,
			"total_income": _player_commodity_sale_income(i),
			"cities_built": int(player.get("cities_built", 0)),
			"eliminated": _player_is_eliminated(i),
		})
	return _order_entries_by_victory_rank(entries) if _runtime_session_finished() else entries


func _order_entries_by_victory_rank(entries: Array) -> Array:
	var by_player := {}
	for entry_variant in entries:
		if entry_variant is Dictionary:
			by_player[str(int((entry_variant as Dictionary).get("player_index", -1)))] = (entry_variant as Dictionary).duplicate(true)
	var ordered: Array = []
	for ranking_variant in _victory_control_rankings():
		if not (ranking_variant is Dictionary):
			continue
		var key := str(int((ranking_variant as Dictionary).get("player_index", -1)))
		if by_player.has(key):
			ordered.append(by_player[key])
			by_player.erase(key)
	for entry_variant in entries:
		var key := str(int((entry_variant as Dictionary).get("player_index", -1))) if entry_variant is Dictionary else ""
		if by_player.has(key):
			ordered.append(by_player[key])
			by_player.erase(key)
	return ordered


func _player_gdp_per_minute(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var total := 0
	for district_index in range(districts.size()):
		var region_id := str((districts[district_index] as Dictionary).get("region_id", "region.%03d" % district_index))
		var region_snapshot_variant: Variant = _commodity_flow_runtime_call("region_gdp_snapshot", [region_id])
		if not (region_snapshot_variant is Dictionary):
			continue
		var by_player: Dictionary = (region_snapshot_variant as Dictionary).get("player_gdp_per_minute_cents_by_index", {}) if (region_snapshot_variant as Dictionary).get("player_gdp_per_minute_cents_by_index", {}) is Dictionary else {}
		total += int(round(float(int(by_player.get(str(player_index), 0))) / 100.0))
	return total


func _player_commodity_sale_income(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return 0
	var total_cents := 0
	for row_variant in (players[player_index] as Dictionary).get("v06_transaction_ledger", []):
		if row_variant is Dictionary and str((row_variant as Dictionary).get("category", "")) == "commodity_sale":
			total_cents += maxi(0, int((row_variant as Dictionary).get("ledger_delta_cents", 0)))
	return int(floor(float(total_cents) / 100.0))


func _player_intel_stats(player_index: int) -> Dictionary:
	var stats := {
		"total_foreign": 0,
		"guessed": 0,
		"correct": 0,
		"wrong": 0,
		"unmarked": 0,
		"cash": 0,
	}
	if player_index < 0 or player_index >= players.size():
		return stats
	var player: Dictionary = players[player_index]
	var guesses: Dictionary = player.get("city_guesses", {})
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		var city_owner := int(city.get("owner", -1))
		if city_owner < 0 or city_owner == player_index:
			continue
		stats["total_foreign"] = int(stats["total_foreign"]) + 1
		if not guesses.has(city_index):
			stats["unmarked"] = int(stats["unmarked"]) + 1
			continue
		var guessed_owner := int(guesses.get(city_index, -1))
		if guessed_owner < 0:
			stats["unmarked"] = int(stats["unmarked"]) + 1
			continue
		stats["guessed"] = int(stats["guessed"]) + 1
		if guessed_owner == city_owner:
			stats["correct"] = int(stats["correct"]) + 1
		else:
			stats["wrong"] = int(stats["wrong"]) + 1
	var role := _player_role_card_for_index(player_index)
	var correct_reward := INTEL_CORRECT_GUESS_CASH + maxi(0, int(role.get("city_guess_reward_bonus", 0)))
	stats["correct_reward"] = correct_reward
	stats["cash"] = int(stats["correct"]) * correct_reward - int(stats["wrong"]) * INTEL_WRONG_GUESS_COST
	return stats


func _player_intel_summary(player_index: int) -> String:
	var stats := _player_intel_stats(player_index)
	return "情报现金%s = 猜对%d×¥%d - 猜错%d×¥%d｜已标%d/%d" % [
		_signed_int_text(int(stats.get("cash", 0))),
		int(stats.get("correct", 0)),
		int(stats.get("correct_reward", INTEL_CORRECT_GUESS_CASH)),
		int(stats.get("wrong", 0)),
		INTEL_WRONG_GUESS_COST,
		int(stats.get("guessed", 0)),
		int(stats.get("total_foreign", 0)),
	]


func _player_intel_exposure_stats(player_index: int) -> Dictionary:
	var stats := {
		"total_foreign": 0,
		"guessed": 0,
		"unmarked": 0,
		"best_cash": 0,
		"worst_cash": 0,
	}
	if player_index < 0 or player_index >= players.size():
		return stats
	var player: Dictionary = players[player_index]
	var guesses: Dictionary = player.get("city_guesses", {})
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		var city_owner := int(city.get("owner", -1))
		if city_owner < 0 or city_owner == player_index:
			continue
		stats["total_foreign"] = int(stats["total_foreign"]) + 1
		var guessed_owner := int(guesses.get(city_index, -1))
		if guessed_owner >= 0:
			stats["guessed"] = int(stats["guessed"]) + 1
		else:
			stats["unmarked"] = int(stats["unmarked"]) + 1
	stats["best_cash"] = int(stats["guessed"]) * INTEL_CORRECT_GUESS_CASH
	stats["worst_cash"] = -int(stats["guessed"]) * INTEL_WRONG_GUESS_COST
	return stats


func _player_intel_pending_summary(player_index: int) -> String:
	var stats := _player_intel_exposure_stats(player_index)
	return "情报待结算：已标%d/%d｜全对%s / 全错%s｜终局揭晓" % [
		int(stats.get("guessed", 0)),
		int(stats.get("total_foreign", 0)),
		_signed_int_text(int(stats.get("best_cash", 0))),
		_signed_int_text(int(stats.get("worst_cash", 0))),
	]


func _player_intel_display_summary(player_index: int) -> String:
	return _player_intel_summary(player_index) if _runtime_session_finished() else _player_intel_pending_summary(player_index)


func _city_intel_hint_for_player(city_index: int, viewer_index: int) -> String:
	if city_index < 0 or city_index >= districts.size():
		return "情报：无选区"
	if viewer_index < 0 or viewer_index >= players.size():
		return "情报：无当前玩家"
	var city := _district_city(city_index)
	if city.is_empty():
		return "情报：未城市化"
	if not _city_is_active(city):
		return "情报：废墟不结算"
	var city_owner := int(city.get("owner", -1))
	if city_owner == viewer_index:
		return "情报：己方城市不参与猜业主结算"
	var guesses: Dictionary = players[viewer_index].get("city_guesses", {})
	var guess := int(guesses.get(city_index, -1))
	if guess < 0:
		return "情报：未标注，终局可争取+¥%d，错标-¥%d" % [
			INTEL_CORRECT_GUESS_CASH,
			INTEL_WRONG_GUESS_COST,
		]
	return "情报：已标玩家%d，终局猜对+¥%d / 猜错-¥%d" % [
		guess + 1,
		INTEL_CORRECT_GUESS_CASH,
		INTEL_WRONG_GUESS_COST,
	]


func _player_name(player_index: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return "未知玩家"
	return String((players[player_index] as Dictionary).get("name", "玩家%d" % (player_index + 1)))


func _player_is_eliminated(player_index: int) -> bool:
	if player_index < 0 or player_index >= players.size():
		return true
	return bool((players[player_index] as Dictionary).get("eliminated", false))


func _runtime_session_finished() -> bool:
	var coordinator := _game_runtime_coordinator_node()
	return bool(coordinator.call("session_is_finished")) if coordinator != null and coordinator.has_method("session_is_finished") else false


func _victory_control_public_snapshot() -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	var value: Variant = coordinator.call("victory_control_public_snapshot", selected_player) if coordinator != null and coordinator.has_method("victory_control_public_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _victory_control_private_snapshot(player_index: int) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	var value: Variant = coordinator.call("victory_control_private_snapshot", player_index) if coordinator != null and coordinator.has_method("victory_control_private_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _victory_control_is_active() -> bool:
	return str(_victory_control_public_snapshot().get("state", "idle")) in ["qualification", "audit"]


func _victory_control_timer_visible() -> bool:
	return str(_victory_control_public_snapshot().get("state", "idle")) in ["qualification", "audit"]


func _victory_control_remaining_seconds() -> float:
	var snapshot := _victory_control_public_snapshot()
	match str(snapshot.get("state", "idle")):
		"qualification":
			return maxf(0.0, float(snapshot.get("qualification_remaining_seconds", 0.0)))
		"audit":
			return maxf(0.0, float(snapshot.get("audit_remaining_seconds", 0.0)))
	return 0.0


func _victory_control_total_seconds() -> float:
	var coordinator := _game_runtime_coordinator_node()
	var controller: Node = coordinator.call("victory_control_runtime_controller") if coordinator != null and coordinator.has_method("victory_control_runtime_controller") else null
	if controller == null or not controller.has_method("timer_duration"):
		return 1.0
	var state := str(_victory_control_public_snapshot().get("state", "idle"))
	var timer_id := "public_audit" if state == "audit" else "victory_qualification"
	return maxf(1.0, float(controller.call("timer_duration", timer_id)))


func _victory_dynamic_rule() -> Dictionary:
	var public_rule_variant: Variant = _victory_control_public_snapshot().get("victory_rule", {})
	if public_rule_variant is Dictionary and not (public_rule_variant as Dictionary).is_empty():
		return (public_rule_variant as Dictionary).duplicate(true)
	var coordinator := _game_runtime_coordinator_node()
	var controller: Node = coordinator.call("victory_control_runtime_controller") if coordinator != null and coordinator.has_method("victory_control_runtime_controller") else null
	var world_snapshot: Dictionary = coordinator.call("victory_control_world_snapshot") if coordinator != null and coordinator.has_method("victory_control_world_snapshot") else {}
	var value: Variant = controller.call("victory_rule_for_world", world_snapshot) if controller != null and controller.has_method("victory_rule_for_world") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _victory_required_gdp() -> int:
	return int(_victory_dynamic_rule().get("required_top_k_gdp_per_minute", 0))


func _victory_required_regions() -> int:
	return int(_victory_dynamic_rule().get("required_region_count", 0))


func _victory_player_candidate(player_index: int) -> Dictionary:
	var snapshot := _victory_control_private_snapshot(player_index)
	var candidate_variant: Variant = snapshot.get("own_candidate", {})
	return (candidate_variant as Dictionary).duplicate(true) if candidate_variant is Dictionary else {}


func _victory_player_progress_metric(player_index: int) -> int:
	return int(_victory_player_candidate(player_index).get("top_n_gdp_per_minute", 0))


func _victory_control_escrow_cents(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var escrow_cash := 0
	for wager_variant in monster_runtime_controller.active_monster_wagers:
		if not (wager_variant is Dictionary):
			continue
		var bets: Dictionary = (wager_variant as Dictionary).get("bets", {}) if (wager_variant as Dictionary).get("bets", {}) is Dictionary else {}
		var bet_variant: Variant = bets.get(str(player_index), bets.get(player_index, {}))
		if bet_variant is Dictionary:
			escrow_cash += maxi(0, int((bet_variant as Dictionary).get("stake", 0)))
	return escrow_cash * 100


func _victory_control_rankings() -> Array:
	var coordinator := _game_runtime_coordinator_node()
	var receipt: Dictionary = coordinator.call("victory_control_outcome_receipt") if coordinator != null and coordinator.has_method("victory_control_outcome_receipt") else {}
	if receipt.get("rankings", []) is Array and not (receipt.get("rankings", []) as Array).is_empty():
		return (receipt.get("rankings", []) as Array).duplicate(true)
	var value: Variant = coordinator.call("victory_control_rankings", false) if coordinator != null and coordinator.has_method("victory_control_rankings") else []
	return (value as Array).duplicate(true) if value is Array else []


func _victory_control_status_text() -> String:
	var snapshot := _victory_control_public_snapshot()
	var rule: Dictionary = snapshot.get("victory_rule", {}) if snapshot.get("victory_rule", {}) is Dictionary else _victory_dynamic_rule()
	if bool(rule.get("ordinary_victory_paused", false)):
		return "胜利资格：全部区域为废墟，等待复兴"
	var target := "控制%d区且前K区商品GDP/min达到%d" % [int(rule.get("required_region_count", 0)), int(rule.get("required_top_k_gdp_per_minute", 0))]
	match str(snapshot.get("state", "idle")):
		"qualification":
			return "胜利资格：确认中 %.1fs｜%s" % [_victory_control_remaining_seconds(), target]
		"audit":
			return "公开审计：%.1fs｜经济资产公开核验" % _victory_control_remaining_seconds()
		"resolved":
			return "胜利审计：已完成"
	return "胜利资格：%s" % target


func _update_victory_control(delta: float) -> void:
	if _runtime_session_finished() or players.is_empty():
		return
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("advance_victory_control"):
		return
	var before_state := str(_victory_control_public_snapshot().get("state", "idle"))
	var result_variant: Variant = coordinator.call("advance_victory_control", delta, {})
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	var public_snapshot: Dictionary = result.get("public_snapshot", {}) if result.get("public_snapshot", {}) is Dictionary else {}
	var after_state := str(public_snapshot.get("state", before_state))
	if after_state != before_state:
		_log("胜利控制状态：%s。" % _victory_control_status_text())
		_refresh_ui()


func _open_fullscreen_map() -> void:
	if full_map_overlay == null:
		return
	full_map_overlay.visible = true
	_refresh_map_controls()
	_refresh_board()


func _close_fullscreen_map() -> void:
	if full_map_overlay == null:
		return
	full_map_overlay.visible = false
	_refresh_board()


func _menu_context_text(title_text: String, show_main_actions: bool = false) -> String:
	if show_main_actions and title_text == "太空辛迪加｜星球赌桌":
		return ""
	if show_main_actions and title_text == "暂停菜单":
		return "暂停｜继续、局势、资料、保存"
	match title_text:
		"开局准备":
			return "开局｜席位、AI、角色、起始怪兽"
		"图鉴":
			return "图鉴｜选分类"
		"卡牌图鉴", "怪兽生态档案", "商品图鉴":
			return "%s｜悬停预览，双击详情" % title_text
		"角色图鉴", "区域图鉴":
			return "%s｜按钮切换" % title_text
		"游戏规则":
			return "规则｜先看短卡"
		"经济总览":
			return "经济｜GDP、商品、商路"
		"情报档案":
			return "情报｜整理公开线索"
		"局势排名":
			return "局势｜目标与排名"
		"新手引导":
			return "引导｜首局四步"
	return "%s｜返回回上级" % title_text


func _menu_interaction_hint_text(title_text: String, show_main_actions: bool = false) -> String:
	if show_main_actions and title_text == "太空辛迪加｜星球赌桌":
		return ""
	if show_main_actions and title_text == "暂停菜单":
		return "暂停菜单｜继续、复查局势、查资料或保存。"
	match title_text:
		"开局准备":
			return "选席位、难度、角色、怪兽。"
		"图鉴":
			return "先选资料分类。"
		"卡牌图鉴":
			if _codex_navigation_controller_node().card_codex_show_detail:
				return "卡面、梯度、关键数值。"
			return "悬停预览，双击详情。"
		"怪兽生态档案":
			if _codex_navigation_controller_node().bestiary_show_detail:
				return "画像、行动、速度、偏好。"
			return "悬停预览，双击详情。"
		"商品图鉴":
			if _codex_navigation_controller_node().product_codex_show_detail:
				return "价格、供需、商路。"
			return "悬停预览，双击详情。"
		"角色图鉴":
			return "公开角色卡。"
		"区域图鉴":
			return "地形、HP、城市、商路。"
		"游戏规则":
			return "先看短卡。"
		"经济总览":
			return "看GDP、商品、商路。"
		"情报档案":
			return "只整理公开线索。"
		"局势排名":
			return "看目标和排名。"
		"新手引导":
			return "受光牌架、发展牌、商品项目、出牌；怪兽召唤可选。"
	return "只显示本页操作。"


func _show_menu(title_text: String, body_text: String, can_continue: bool, show_main_actions: bool = false, compact_page: bool = false) -> void:
	if menu_overlay == null or not menu_overlay.has_method("present_menu_shell"):
		return
	if time_scale > 0.0:
		speed_before_menu = time_scale
	time_scale = 0.0
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator != null and runtime_coordinator.has_method("pause_session"):
		runtime_coordinator.call("pause_session")
	_codex_navigation_controller_node().catalog_mode = ""
	menu_load_run_button = null
	var root_table_menu := show_main_actions and title_text == "太空辛迪加｜星球赌桌"
	menu_overlay.call("present_menu_shell", {
		"title": title_text,
		"body": body_text,
		"context": _menu_context_text(title_text, show_main_actions),
		"context_visible": not root_table_menu and not compact_page,
		"hint": _menu_interaction_hint_text(title_text, show_main_actions),
		"hint_visible": not root_table_menu and not compact_page,
		"continue_disabled": not can_continue,
		"continue_visible": can_continue and show_main_actions and not root_table_menu,
		"back_visible": not show_main_actions,
		"nav_visible": not root_table_menu,
		"run_save_visible": show_main_actions,
		"root_table_menu": root_table_menu,
		"compact_page": compact_page,
		"viewport_size": _menu_viewport_size(),
		"quick_nav": _menu_quick_nav_entries(),
		"quick_nav_active_id": _menu_quick_nav_active_key(title_text),
		"quick_nav_visible": _menu_quick_nav_visible(title_text, show_main_actions, compact_page),
	})
	for button_variant: Variant in menu_regular_buttons:
		var button := button_variant as CanvasItem
		if is_instance_valid(button):
			button.visible = show_main_actions
	_refresh_run_save_menu_state()
	_refresh_menu_layout()
	call_deferred("_refresh_menu_layout")


func _present_codex_page(title_text: String, body_text: String, page: Dictionary) -> void:
	_show_menu(title_text, body_text, false)
	var mode := str(page.get("mode", ""))
	_codex_navigation_controller_node().catalog_mode = mode
	if menu_overlay == null or not menu_overlay.has_method("present_codex_page"):
		push_error("MenuOverlay must present the scene-owned CodexCompendiumSurface.")
		return
	menu_overlay.call("present_codex_page", page.duplicate(true))


func _codex_navigation_data(prev_visible: bool, next_visible: bool, back_text: String, back_visible: bool = true) -> Dictionary:
	return {
		"prev_text": "上一个",
		"next_text": "下一个",
		"back_text": back_text,
		"prev_visible": prev_visible,
		"next_visible": next_visible,
		"back_visible": back_visible,
	}


func _on_codex_surface_action_requested(action_id: String, payload: Dictionary) -> void:
	match action_id:
		"hub_action":
			match str(payload.get("action_id", "")):
				"role":
					_open_role_codex_from_compendium()
				"monster":
					_open_bestiary_from_compendium()
				"card":
					_open_card_codex_from_compendium()
				"product":
					_open_product_codex_from_compendium()
				"region":
					_open_region_codex_from_compendium()
				"main":
					_open_main_menu()
		"card_filter":
			_set_card_codex_filter(str(payload.get("filter_id", "all")))
		"card_page_step":
			_turn_card_codex_grid_page(int(payload.get("delta", 0)))
		"card_preview":
			_preview_card_codex_card(str(payload.get("card_name", "")))
		"card_detail":
			_open_card_codex_detail(str(payload.get("card_name", "")))
		"card_deep_link":
			_open_card_codex_by_name(str(payload.get("card_name", "")))
		"monster_page_step":
			_turn_bestiary_grid_page(int(payload.get("delta", 0)))
		"monster_preview":
			_preview_bestiary_entry(int(payload.get("catalog_index", -1)))
		"monster_detail":
			_open_bestiary_detail(int(payload.get("catalog_index", -1)))
		"product_page_step":
			_turn_product_codex_grid_page(int(payload.get("delta", 0)))
		"product_preview":
			_preview_product_codex_entry(int(payload.get("catalog_index", -1)))
		"product_detail":
			_open_product_codex_detail(int(payload.get("catalog_index", -1)))


func _open_bestiary_from_compendium() -> void:
	_codex_navigation_controller_node().return_target = "compendium"
	_codex_navigation_controller_node().bestiary_show_detail = false
	_codex_navigation_controller_node().bestiary_grid_page = 0
	_codex_navigation_controller_node().previewed_bestiary_index = 0
	_open_bestiary_menu()


func _open_card_codex_from_compendium() -> void:
	_codex_navigation_controller_node().return_target = "compendium"
	_codex_navigation_controller_node().card_codex_filter = "all"
	_codex_navigation_controller_node().card_codex_grid_page = 0
	_codex_navigation_controller_node().card_codex_show_detail = false
	_codex_navigation_controller_node().previewed_card_codex_card = ""
	_open_card_codex_menu()


func _open_role_codex_from_compendium() -> void:
	_codex_navigation_controller_node().return_target = "compendium"
	_open_role_codex_menu()


func _open_product_codex_from_compendium() -> void:
	_codex_navigation_controller_node().return_target = "compendium"
	_open_product_codex_menu()


func _open_region_codex_from_compendium() -> void:
	_codex_navigation_controller_node().return_target = "compendium"
	_open_region_codex_menu()


func _back_from_catalog_menu() -> void:
	if _codex_navigation_controller_node().catalog_mode == "card" and _codex_navigation_controller_node().card_codex_show_detail:
		_codex_navigation_controller_node().card_codex_show_detail = false
		_update_card_codex_menu()
		return
	if _codex_navigation_controller_node().catalog_mode == "monster" and _codex_navigation_controller_node().bestiary_show_detail:
		_codex_navigation_controller_node().bestiary_show_detail = false
		_update_bestiary_menu()
		return
	if _codex_navigation_controller_node().catalog_mode == "product" and _codex_navigation_controller_node().product_codex_show_detail:
		_codex_navigation_controller_node().product_codex_show_detail = false
		_update_product_codex_menu()
		return
	match _codex_navigation_controller_node().return_target:
		"compendium":
			_open_compendium_menu()
		"intel":
			_open_intel_dossier_menu()
		"economy":
			_open_economy_overview_menu()
		"standings":
			_open_standings_menu()
		"game":
			_close_menu()
		_:
			_open_main_menu()


func _catalog_back_button_text() -> String:
	match _codex_navigation_controller_node().return_target:
		"compendium":
			return "返回图鉴"
		"intel":
			return "返回情报档案"
		"economy":
			return "返回经济总览"
		"standings":
			return "返回局势排名"
		"game":
			return "返回牌桌"
		_:
			return "返回主菜单"


func _open_bestiary_menu(index: int = -1) -> void:
	_codex_navigation_controller_node().bestiary_show_detail = index >= 0
	if index >= 0:
		_codex_navigation_controller_node().bestiary_index = index
		_codex_navigation_controller_node().previewed_bestiary_index = _valid_bestiary_index(index)
		_codex_navigation_controller_node().bestiary_grid_page = _codex_page_for_index(_codex_navigation_controller_node().bestiary_index, _catalog_size(), _bestiary_entries_per_page())
	_update_bestiary_menu()


func _open_card_codex_menu(index: int = -1) -> void:
	_codex_navigation_controller_node().card_codex_show_detail = index >= 0
	if index >= 0:
		_codex_navigation_controller_node().card_codex_index = index
		_codex_navigation_controller_node().card_codex_grid_page = _codex_page_for_index(_codex_navigation_controller_node().card_codex_index, _card_codex_names().size(), _card_codex_cards_per_page())
		var names := _card_codex_names()
		if _codex_navigation_controller_node().card_codex_index >= 0 and _codex_navigation_controller_node().card_codex_index < names.size():
			_codex_navigation_controller_node().previewed_card_codex_card = String(names[_codex_navigation_controller_node().card_codex_index])
	_update_card_codex_menu()


func _open_card_codex_by_name(card_name: String) -> void:
	_codex_navigation_controller_node().card_codex_show_detail = false
	var direct_skill := _game_runtime_coordinator_node().card_definition(card_name)
	if not direct_skill.is_empty():
		_codex_navigation_controller_node().card_codex_filter = str(_card_presentation_snapshot(card_name, direct_skill).get("category_id", "other"))
	var names := _card_codex_names()
	var index := names.find(card_name)
	if index < 0:
		var family_name := "%s1" % _game_runtime_coordinator_node().card_family_id(card_name)
		index = names.find(family_name)
	if index >= 0:
		_codex_navigation_controller_node().card_codex_index = index
		_codex_navigation_controller_node().card_codex_show_detail = true
		_codex_navigation_controller_node().card_codex_grid_page = _codex_page_for_index(_codex_navigation_controller_node().card_codex_index, _card_codex_names().size(), _card_codex_cards_per_page())
		_codex_navigation_controller_node().previewed_card_codex_card = String(names[_codex_navigation_controller_node().card_codex_index])
	else:
		_codex_navigation_controller_node().card_codex_filter = "all"
		names = _card_codex_names()
		index = names.find(card_name)
		if index < 0:
			index = names.find("%s1" % _game_runtime_coordinator_node().card_family_id(card_name))
	if index >= 0:
		_codex_navigation_controller_node().card_codex_index = index
		_codex_navigation_controller_node().card_codex_show_detail = true
		_codex_navigation_controller_node().card_codex_grid_page = _codex_page_for_index(_codex_navigation_controller_node().card_codex_index, _card_codex_names().size(), _card_codex_cards_per_page())
		_codex_navigation_controller_node().previewed_card_codex_card = String(names[_codex_navigation_controller_node().card_codex_index])
	_update_card_codex_menu()
	if _codex_navigation_controller_node().card_codex_show_detail:
		_complete_scenario_signal("card_detail_opened", "打开卡牌详情：%s。" % _card_display_name(_codex_navigation_controller_node().previewed_card_codex_card), "after_track", "right_inspector")


func _open_role_codex_menu(index: int = -1) -> void:
	if index >= 0:
		_codex_navigation_controller_node().role_codex_index = index
	_update_role_codex_menu()


func _cycle_role_codex(step: int) -> void:
	if PLAYER_ROLE_CATALOG.is_empty():
		return
	_codex_navigation_controller_node().role_codex_index = wrapi(_codex_navigation_controller_node().role_codex_index + step, 0, PLAYER_ROLE_CATALOG.size())
	_update_role_codex_menu()


func _update_role_codex_menu() -> void:
	if PLAYER_ROLE_CATALOG.is_empty():
		_show_catalog_empty_page("角色图鉴", "还没有角色卡资料。")
		return
	_codex_navigation_controller_node().role_codex_index = wrapi(_codex_navigation_controller_node().role_codex_index, 0, PLAYER_ROLE_CATALOG.size())
	var role_index: int = int(_codex_navigation_controller_node().role_codex_index)
	var role_card := _make_player_role_card(role_index)
	var public_snapshot := _role_codex_public_snapshot(role_card, role_index, PLAYER_ROLE_CATALOG.size())
	_present_codex_page("角色图鉴", str(public_snapshot.get("summary_text", "")), {
		"mode": "role",
		"view": "detail",
		"detail": public_snapshot.get("board", {}),
		"navigation": _codex_navigation_data(true, true, _catalog_back_button_text()),
	})


func _cycle_menu_catalog(step: int) -> void:
	match _codex_navigation_controller_node().catalog_mode:
		"card":
			_cycle_card_codex(step)
		"product":
			_cycle_product_codex(step)
		"region":
			_cycle_region_codex(step)
		"role":
			_cycle_role_codex(step)
		_:
			_cycle_bestiary(step)


func _cycle_bestiary(step: int) -> void:
	if _catalog_size() <= 0:
		return
	if _codex_navigation_controller_node().bestiary_show_detail:
		_codex_navigation_controller_node().bestiary_index = wrapi(_codex_navigation_controller_node().bestiary_index + step, 0, _catalog_size())
		_codex_navigation_controller_node().previewed_bestiary_index = _codex_navigation_controller_node().bestiary_index
		_codex_navigation_controller_node().bestiary_grid_page = _codex_page_for_index(_codex_navigation_controller_node().bestiary_index, _catalog_size(), _bestiary_entries_per_page())
	else:
		var page_count := _codex_page_count(_catalog_size(), _bestiary_entries_per_page())
		_codex_navigation_controller_node().bestiary_grid_page = wrapi(_codex_navigation_controller_node().bestiary_grid_page + step, 0, page_count)
		var first_index := _codex_first_index_on_page(_codex_navigation_controller_node().bestiary_grid_page, _catalog_size(), _bestiary_entries_per_page())
		_codex_navigation_controller_node().bestiary_index = first_index
		_codex_navigation_controller_node().previewed_bestiary_index = first_index
	_update_bestiary_menu()


func _update_bestiary_menu() -> void:
	if _catalog_size() <= 0:
		return
	_codex_navigation_controller_node().bestiary_index = wrapi(_codex_navigation_controller_node().bestiary_index, 0, _catalog_size())
	_codex_navigation_controller_node().previewed_bestiary_index = _valid_bestiary_index(_codex_navigation_controller_node().previewed_bestiary_index)
	_codex_navigation_controller_node().bestiary_grid_page = clampi(_codex_navigation_controller_node().bestiary_grid_page, 0, _codex_page_count(_catalog_size(), _bestiary_entries_per_page()) - 1)
	var public_snapshot := _monster_codex_public_snapshot(_codex_navigation_controller_node().bestiary_index, true)
	var body_text := str(public_snapshot.get("summary_text", "")) if _codex_navigation_controller_node().bestiary_show_detail else _bestiary_grid_text()
	var page := {
		"mode": "monster",
		"view": "detail" if _codex_navigation_controller_node().bestiary_show_detail else "browser",
		"navigation": _codex_navigation_data(
			_codex_navigation_controller_node().bestiary_show_detail,
			_codex_navigation_controller_node().bestiary_show_detail,
			"返回缩略图" if _codex_navigation_controller_node().bestiary_show_detail else _catalog_back_button_text()
		),
	}
	if _codex_navigation_controller_node().bestiary_show_detail:
		page["detail"] = public_snapshot.get("detail", {})
		var monster_card_name := _monster_card_name(_codex_navigation_controller_node().bestiary_index, 1)
		var monster_card_skill := _game_runtime_coordinator_node().card_definition(monster_card_name)
		page["monster_card_link"] = {
			"visible": not monster_card_skill.is_empty(),
			"card_name": monster_card_name,
			"label": "对应怪兽牌（属于卡牌图鉴｜悬停看属性｜点击跳转）：",
			"button_text": "%s｜¥%d" % [_card_display_name(monster_card_name), _card_price(monster_card_name)],
			"tooltip": _card_presentation_detail_tooltip(monster_card_name),
		}
	else:
		page["browser"] = _bestiary_codex_browser_snapshot()
	_present_codex_page("怪兽生态档案", body_text, page)


func _valid_bestiary_index(index: int) -> int:
	return clampi(index, 0, max(0, _catalog_size() - 1))


func _bestiary_grid_columns() -> int:
	return clampi(int(floor(_menu_available_content_width() / 180.0)), 2, 5)


func _bestiary_grid_rows() -> int:
	return clampi(int(floor(_menu_available_content_height() / 176.0)), 1, 4)


func _bestiary_entries_per_page() -> int:
	return maxi(1, _bestiary_grid_columns() * _bestiary_grid_rows())


func _bestiary_grid_text() -> String:
	var page_count := _codex_page_count(_catalog_size(), _bestiary_entries_per_page())
	return "怪兽生态｜第%d/%d页｜本页%d×%d\n看画像、速度、偏好、行动概率和招式。悬停预览，双击详情；怪兽牌在卡牌图鉴。" % [
		_codex_navigation_controller_node().bestiary_grid_page + 1,
		page_count,
		_bestiary_grid_columns(),
		_bestiary_grid_rows(),
	]


func _turn_bestiary_grid_page(step: int) -> void:
	if _catalog_size() <= 0:
		return
	var page_count := _codex_page_count(_catalog_size(), _bestiary_entries_per_page())
	_codex_navigation_controller_node().bestiary_grid_page = wrapi(_codex_navigation_controller_node().bestiary_grid_page + step, 0, page_count)
	var first_index := _codex_first_index_on_page(_codex_navigation_controller_node().bestiary_grid_page, _catalog_size(), _bestiary_entries_per_page())
	_codex_navigation_controller_node().bestiary_index = first_index
	_codex_navigation_controller_node().previewed_bestiary_index = first_index
	_codex_navigation_controller_node().bestiary_show_detail = false
	_update_bestiary_menu()


func _bestiary_codex_browser_snapshot() -> Dictionary:
	var total_count := _catalog_size()
	var page_count := _codex_page_count(total_count, _bestiary_entries_per_page())
	_codex_navigation_controller_node().bestiary_grid_page = clampi(_codex_navigation_controller_node().bestiary_grid_page, 0, max(0, page_count - 1))
	var per_page := _bestiary_entries_per_page()
	var start_index: int = int(_codex_navigation_controller_node().bestiary_grid_page) * per_page
	var end_index := mini(total_count, start_index + per_page)
	if start_index >= total_count:
		start_index = _codex_first_index_on_page(_codex_navigation_controller_node().bestiary_grid_page, total_count, _bestiary_entries_per_page())
		end_index = mini(total_count, start_index + per_page)
	if _codex_navigation_controller_node().previewed_bestiary_index < start_index or _codex_navigation_controller_node().previewed_bestiary_index >= end_index:
		_codex_navigation_controller_node().previewed_bestiary_index = start_index
		_codex_navigation_controller_node().bestiary_index = start_index
	var report := _game_runtime_coordinator_node().gameplay_balance_diagnostics_service().monster_ecology_balance_report()
	var movement_pieces: Array[String] = []
	for movement_variant: Variant in (report.get("movement_counts", {}) as Dictionary).keys():
		var movement := str(movement_variant)
		movement_pieces.append("%s×%d" % [movement, int((report.get("movement_counts", {}) as Dictionary).get(movement, 0))])
	var entries: Array = []
	for catalog_index in range(start_index, end_index):
		var entry_snapshot := _monster_codex_public_snapshot(catalog_index, catalog_index == _codex_navigation_controller_node().previewed_bestiary_index)
		entries.append(entry_snapshot.get("browser_entry", {}))
	return {
		"columns": _bestiary_grid_columns(),
		"selected_index": _codex_navigation_controller_node().previewed_bestiary_index,
		"can_page": page_count > 1,
		"page_label": "第%d/%d页｜%d只怪兽｜本页%d-%d" % [_codex_navigation_controller_node().bestiary_grid_page + 1, page_count, total_count, start_index + 1, end_index],
		"summaries": [{
			"title": "生态速览",
			"body": "%d只怪兽｜移动:%s｜偏好%d种商品｜%d种行动风格" % [int(report.get("catalog_count", total_count)), " / ".join(movement_pieces) if not movement_pieces.is_empty() else "暂无", int(report.get("resource_good_count", 0)), int(report.get("role_tag_count", 0))],
			"meta": "飞行 / 水栖海域 / 陆行会改变接近城市和商路的方式。",
			"accent": Color("#fb7185"),
		}],
		"entries": entries,
		"preview": (_monster_codex_public_snapshot(_codex_navigation_controller_node().previewed_bestiary_index, true)).get("detail", {}),
	}


func _monster_codex_public_source_snapshot(catalog_index: int, selected: bool = false) -> Dictionary:
	if catalog_index < 0 or catalog_index >= _catalog_size():
		return {"valid": false, "index": catalog_index, "total": _catalog_size()}
	var entry := _catalog_entry(catalog_index)
	var ecology := _game_runtime_coordinator_node().gameplay_balance_diagnostics_service().monster_ecology_identity_entry(catalog_index)
	var monster_name := str(entry.get("name", "怪兽"))
	var profile := _monster_art_profile(monster_name)
	var actions := []
	var catalog_actions := _catalog_actions(catalog_index)
	for action_index in range(mini(catalog_actions.size(), 6)):
		var action: Dictionary = catalog_actions[action_index] if catalog_actions[action_index] is Dictionary else {}
		var probability_facts := _monster_codex_action_probability_facts(catalog_index, action_index)
		actions.append({
			"name": str(action.get("name", "行动")),
			"text": str(action.get("text", "自动行动。")),
			"tags": monster_runtime_controller._monster_action_role_tags(action),
			"facts": _catalog_action_numeric_facts(action),
			"i_open": str(probability_facts.get("i_open", "0%")),
			"i_destroyed": str(probability_facts.get("i_destroyed", "0%")),
			"iv_open": str(probability_facts.get("iv_open", "0%")),
			"iv_destroyed": str(probability_facts.get("iv_destroyed", "0%")),
			"probability_tooltip": str(probability_facts.get("tooltip", "")),
		})
	var monster_card_name := _monster_card_name(catalog_index, 1)
	var monster_card_skill := _game_runtime_coordinator_node().card_definition(monster_card_name)
	var monster_card := {"valid": not monster_card_skill.is_empty()}
	if not monster_card_skill.is_empty():
		monster_card.merge({
			"display_name": _card_display_name(monster_card_name),
			"price": _card_price(monster_card_name),
			"region_text": _monster_card_region_text(monster_card_skill),
		}, true)
	return {
		"valid": true,
		"index": catalog_index,
		"total": _catalog_size(),
		"selected": selected,
		"entry": entry.duplicate(true),
		"ecology": ecology.duplicate(true),
		"profile": profile.duplicate(true),
		"accent": profile.get("accent", Color("#fb7185")) as Color,
		"move_text": _meters_text(_catalog_move_speed(catalog_index)),
		"art_move_text": _meters_text(float(entry.get("move", MonsterRuntimeController.MONSTER_RAMPAGE_MOVE_METERS))),
		"ecology_move_text": _meters_text(float(ecology.get("move", 0.0))),
		"max_range_text": _meters_text(float(ecology.get("max_range", 0.0))),
		"encounter_range_text": _meters_text(MonsterRuntimeController.AUTO_MONSTER_ENCOUNTER_RANGE_METERS),
		"mobility_summary": _monster_mobility_summary_from_fields(ecology.get("movement_traits", []) as Array, ecology.get("terrain_move_multiplier", {}) as Dictionary),
		"action_summary": _catalog_action_summary(catalog_index),
		"rank_iv_shift_summary": _catalog_rank_iv_shift_summary(catalog_index, false),
		"actions": actions,
		"monster_card": monster_card,
		"level_labels": [_level_text(1), _level_text(2), _level_text(3), _level_text(4)],
	}


func _monster_codex_action_probability_facts(catalog_index: int, action_index: int) -> Dictionary:
	var i_open := _monster_codex_probability_percent(_catalog_ranked_action_weights_for_index(catalog_index, false, 1), action_index)
	var i_destroyed := _monster_codex_probability_percent(_catalog_ranked_action_weights_for_index(catalog_index, true, 1), action_index)
	var iv_open := _monster_codex_probability_percent(_catalog_ranked_action_weights_for_index(catalog_index, false, 4), action_index)
	var iv_destroyed := _monster_codex_probability_percent(_catalog_ranked_action_weights_for_index(catalog_index, true, 4), action_index)
	return {
		"i_open": i_open,
		"i_destroyed": i_destroyed,
		"iv_open": iv_open,
		"iv_destroyed": iv_destroyed,
		"tooltip": "I开局%s / I破坏后%s\nIV开局%s / IV破坏后%s" % [
			i_open,
			i_destroyed,
			_catalog_ranked_probability_line(catalog_index, action_index, false, 4),
			_catalog_ranked_probability_line(catalog_index, action_index, true, 4),
		],
	}


func _monster_codex_probability_percent(weights: Array, action_index: int) -> String:
	var total := _weight_total(weights)
	var weight := int(weights[action_index]) if action_index >= 0 and action_index < weights.size() else 0
	return _probability_text(weight, total)


func _monster_codex_public_snapshot(catalog_index: int, selected: bool = false) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	var source := _monster_codex_public_source_snapshot(catalog_index, selected)
	var value: Variant = coordinator.call("compose_monster_codex_snapshot", source) if coordinator != null and coordinator.has_method("compose_monster_codex_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _preview_bestiary_entry(catalog_index: int, refresh: bool = true) -> void:
	if _catalog_size() <= 0:
		return
	_codex_navigation_controller_node().previewed_bestiary_index = _valid_bestiary_index(catalog_index)
	_codex_navigation_controller_node().bestiary_index = _codex_navigation_controller_node().previewed_bestiary_index
	if refresh:
		var saved_scroll := int(menu_overlay.call("content_scroll_value")) if menu_overlay != null and menu_overlay.has_method("content_scroll_value") else 0
		_update_bestiary_menu()
		_queue_restore_menu_scroll(saved_scroll)


func _open_bestiary_detail(catalog_index: int) -> void:
	_preview_bestiary_entry(catalog_index, false)
	_codex_navigation_controller_node().bestiary_show_detail = true
	_codex_navigation_controller_node().bestiary_grid_page = _codex_page_for_index(_codex_navigation_controller_node().bestiary_index, _catalog_size(), _bestiary_entries_per_page())
	_update_bestiary_menu()


func _cycle_card_codex(step: int) -> void:
	var names := _card_codex_names()
	if names.is_empty():
		return
	if _codex_navigation_controller_node().card_codex_show_detail:
		_codex_navigation_controller_node().card_codex_index = wrapi(_codex_navigation_controller_node().card_codex_index + step, 0, names.size())
		_codex_navigation_controller_node().previewed_card_codex_card = String(names[_codex_navigation_controller_node().card_codex_index])
		_codex_navigation_controller_node().card_codex_grid_page = _codex_page_for_index(_codex_navigation_controller_node().card_codex_index, _card_codex_names().size(), _card_codex_cards_per_page())
	else:
		var page_count := _codex_page_count(names.size(), _card_codex_cards_per_page())
		_codex_navigation_controller_node().card_codex_grid_page = wrapi(_codex_navigation_controller_node().card_codex_grid_page + step, 0, page_count)
		var first_index := _codex_first_index_on_page(_codex_navigation_controller_node().card_codex_grid_page, names.size(), _card_codex_cards_per_page())
		_codex_navigation_controller_node().card_codex_index = first_index
		_codex_navigation_controller_node().previewed_card_codex_card = String(names[first_index])
	_update_card_codex_menu()


func _update_card_codex_menu() -> void:
	var names := _card_codex_names()
	if names.is_empty():
		_show_catalog_empty_page("卡牌图鉴", "当前分类没有卡牌。")
		return
	_codex_navigation_controller_node().card_codex_index = wrapi(_codex_navigation_controller_node().card_codex_index, 0, names.size())
	var page_count := _codex_page_count(names.size(), _card_codex_cards_per_page())
	_codex_navigation_controller_node().card_codex_grid_page = clampi(_codex_navigation_controller_node().card_codex_grid_page, 0, max(0, page_count - 1))
	if _codex_navigation_controller_node().previewed_card_codex_card == "" or not names.has(_codex_navigation_controller_node().previewed_card_codex_card):
		_codex_navigation_controller_node().previewed_card_codex_card = String(names[mini(_codex_navigation_controller_node().card_codex_index, names.size() - 1)])
	var card_name := String(names[_codex_navigation_controller_node().card_codex_index])
	var coordinator := _game_runtime_coordinator_node()
	var public_snapshot: Dictionary
	if _codex_navigation_controller_node().card_codex_show_detail:
		public_snapshot = coordinator.card_codex_public_detail_snapshot(card_name, _codex_navigation_controller_node().card_codex_index, names.size())
	else:
		var filters: Array = []
		for option_variant in _card_codex_filter_options():
			var option: Dictionary = option_variant
			var filter_id := str(option.get("id", "all"))
			var label := str(option.get("label", filter_id))
			filters.append({"id": filter_id, "label": label, "count": _card_codex_names(filter_id).size(), "accent": _menu_action_accent_for_text(label)})
		var layer_report := coordinator.gameplay_balance_diagnostics_service().card_supply_layer_report()
		public_snapshot = coordinator.card_codex_public_browser_snapshot({
			"names": names,
			"columns": _card_codex_grid_columns(),
			"rows": _card_codex_grid_rows(),
			"page_index": _codex_navigation_controller_node().card_codex_grid_page,
			"filter_id": _codex_navigation_controller_node().card_codex_filter,
			"filter_label": _card_codex_filter_label(),
			"selected_card": _codex_navigation_controller_node().previewed_card_codex_card,
			"run_pool_count": int(layer_report.get("run_pool_count", 0)),
			"district_supply_count": int(layer_report.get("district_supply_count", 0)),
			"filters": filters,
		})
		_codex_navigation_controller_node().card_codex_grid_page = int(public_snapshot.get("page_index", _codex_navigation_controller_node().card_codex_grid_page))
		_codex_navigation_controller_node().previewed_card_codex_card = str(public_snapshot.get("selected_card", _codex_navigation_controller_node().previewed_card_codex_card))
		_codex_navigation_controller_node().card_codex_index = int(public_snapshot.get("selected_index", _codex_navigation_controller_node().card_codex_index))
	var body_text := str(public_snapshot.get("summary_text", ""))
	_present_codex_page("卡牌图鉴", body_text, {
		"mode": "card",
		"view": "detail" if _codex_navigation_controller_node().card_codex_show_detail else "browser",
		"detail": public_snapshot.get("detail", {}) if _codex_navigation_controller_node().card_codex_show_detail else {},
		"browser": public_snapshot if not _codex_navigation_controller_node().card_codex_show_detail else {},
		"navigation": _codex_navigation_data(
			_codex_navigation_controller_node().card_codex_show_detail,
			_codex_navigation_controller_node().card_codex_show_detail,
			"返回缩略图" if _codex_navigation_controller_node().card_codex_show_detail else _catalog_back_button_text()
		),
	})


func _card_codex_grid_columns() -> int:
	return clampi(int(floor(_menu_available_content_width() / 185.0)), 2, 5)


func _card_codex_grid_rows() -> int:
	return clampi(int(floor(_menu_available_content_height() / 230.0)), 1, 4)


func _card_codex_cards_per_page() -> int:
	return maxi(1, _card_codex_grid_columns() * _card_codex_grid_rows())


func _turn_card_codex_grid_page(step: int) -> void:
	var names := _card_codex_names()
	if names.is_empty():
		return
	var page_count := _codex_page_count(names.size(), _card_codex_cards_per_page())
	_codex_navigation_controller_node().card_codex_grid_page = wrapi(_codex_navigation_controller_node().card_codex_grid_page + step, 0, page_count)
	var first_index := _codex_first_index_on_page(_codex_navigation_controller_node().card_codex_grid_page, names.size(), _card_codex_cards_per_page())
	_codex_navigation_controller_node().card_codex_index = first_index
	_codex_navigation_controller_node().previewed_card_codex_card = String(names[first_index])
	_codex_navigation_controller_node().card_codex_show_detail = false
	_update_card_codex_menu()


func _preview_card_codex_card(card_name: String, refresh: bool = true) -> void:
	var names := _card_codex_names()
	if card_name == "" or not names.has(card_name):
		return
	_codex_navigation_controller_node().previewed_card_codex_card = card_name
	_codex_navigation_controller_node().card_codex_index = names.find(card_name)
	if refresh:
		var saved_scroll := int(menu_overlay.call("content_scroll_value")) if menu_overlay != null and menu_overlay.has_method("content_scroll_value") else 0
		_update_card_codex_menu()
		_queue_restore_menu_scroll(saved_scroll)


func _queue_restore_menu_scroll(value: int) -> void:
	_restore_menu_scroll(value)
	call_deferred("_restore_menu_scroll", value)
	_queue_restore_menu_scroll_on_next_frame(value, 0)


func _queue_restore_menu_scroll_on_next_frame(value: int, pass_index: int) -> void:
	if get_tree() == null:
		return
	var callback := Callable(self, "_restore_menu_scroll_frame_step").bind(value, pass_index)
	if not get_tree().process_frame.is_connected(callback):
		get_tree().process_frame.connect(callback, CONNECT_ONE_SHOT)


func _restore_menu_scroll_frame_step(value: int, pass_index: int) -> void:
	_restore_menu_scroll(value)
	if pass_index < 4:
		_queue_restore_menu_scroll_on_next_frame(value, pass_index + 1)


func _restore_menu_scroll(value: int) -> void:
	if menu_overlay != null and menu_overlay.has_method("set_content_scroll_value"):
		menu_overlay.call("set_content_scroll_value", value)


func _open_card_codex_detail(card_name: String) -> void:
	_preview_card_codex_card(card_name, false)
	if _codex_navigation_controller_node().card_codex_index < 0:
		return
	_codex_navigation_controller_node().card_codex_show_detail = true
	_codex_navigation_controller_node().card_codex_grid_page = _codex_page_for_index(_codex_navigation_controller_node().card_codex_index, _card_codex_names().size(), _card_codex_cards_per_page())
	_update_card_codex_menu()


func _codex_role_route_label(role_card: Dictionary) -> String:
	var coordinator := _game_runtime_coordinator_node()
	return str(coordinator.call("codex_role_route_label", role_card.duplicate(true), _role_starting_cash_delta(role_card))) if coordinator != null and coordinator.has_method("codex_role_route_label") else "通用经营"


func _role_codex_public_source_snapshot(role_card: Dictionary, index: int, total: int) -> Dictionary:
	var content_width := _menu_available_content_width()
	return {
		"role_card": role_card.duplicate(true),
		"index": index,
		"total": total,
		"passive_text": _role_passive_text(role_card),
		"starting_cash_delta": _role_starting_cash_delta(role_card),
		"accent": _role_card_presentation_color(role_card),
		"kpi_columns": clampi(int(floor(content_width / 210.0)), 1, 4),
		"route_columns": clampi(int(floor(content_width / 300.0)), 1, 3),
		"face": _new_game_setup_role_card_face_snapshot(role_card),
		"face_effect": _role_card_face_text(role_card, false),
	}


func _role_codex_public_snapshot(role_card: Dictionary, index: int, total: int) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	var source := _role_codex_public_source_snapshot(role_card, index, total)
	var value: Variant = coordinator.call("compose_codex_role_snapshot", source) if coordinator != null and coordinator.has_method("compose_codex_role_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _open_product_codex_menu(index: int = -1) -> void:
	if _codex_navigation_controller_node().return_target == "":
		_codex_navigation_controller_node().return_target = "compendium"
	_codex_navigation_controller_node().product_codex_show_detail = index >= 0
	if index >= 0:
		_codex_navigation_controller_node().product_codex_index = index
		_codex_navigation_controller_node().previewed_product_codex_index = _valid_product_codex_index(index)
		_codex_navigation_controller_node().product_codex_grid_page = _codex_page_for_index(_codex_navigation_controller_node().product_codex_index, ProductMarketRuntimeController.PRODUCT_CATALOG.size(), _product_codex_entries_per_page())
	elif selected_trade_product != "" and ProductMarketRuntimeController.PRODUCT_CATALOG.has(selected_trade_product):
		_codex_navigation_controller_node().product_codex_index = ProductMarketRuntimeController.PRODUCT_CATALOG.find(selected_trade_product)
		_codex_navigation_controller_node().previewed_product_codex_index = _codex_navigation_controller_node().product_codex_index
		_codex_navigation_controller_node().product_codex_grid_page = _codex_page_for_index(_codex_navigation_controller_node().product_codex_index, ProductMarketRuntimeController.PRODUCT_CATALOG.size(), _product_codex_entries_per_page())
	_update_product_codex_menu()


func _cycle_product_codex(step: int) -> void:
	if ProductMarketRuntimeController.PRODUCT_CATALOG.is_empty():
		return
	if _codex_navigation_controller_node().product_codex_show_detail:
		_codex_navigation_controller_node().product_codex_index = wrapi(_codex_navigation_controller_node().product_codex_index + step, 0, ProductMarketRuntimeController.PRODUCT_CATALOG.size())
		_codex_navigation_controller_node().previewed_product_codex_index = _codex_navigation_controller_node().product_codex_index
		_codex_navigation_controller_node().product_codex_grid_page = _codex_page_for_index(_codex_navigation_controller_node().product_codex_index, ProductMarketRuntimeController.PRODUCT_CATALOG.size(), _product_codex_entries_per_page())
	else:
		var page_count := _codex_page_count(ProductMarketRuntimeController.PRODUCT_CATALOG.size(), _product_codex_entries_per_page())
		_codex_navigation_controller_node().product_codex_grid_page = wrapi(_codex_navigation_controller_node().product_codex_grid_page + step, 0, page_count)
		var first_index := _codex_first_index_on_page(_codex_navigation_controller_node().product_codex_grid_page, ProductMarketRuntimeController.PRODUCT_CATALOG.size(), _product_codex_entries_per_page())
		_codex_navigation_controller_node().product_codex_index = first_index
		_codex_navigation_controller_node().previewed_product_codex_index = first_index
	_update_product_codex_menu()


func _update_product_codex_menu() -> void:
	if ProductMarketRuntimeController.PRODUCT_CATALOG.is_empty():
		_show_catalog_empty_page("商品图鉴", "当前没有商品资料。")
		return
	_product_market_runtime_call("ensure_catalog")
	_codex_navigation_controller_node().product_codex_index = wrapi(_codex_navigation_controller_node().product_codex_index, 0, ProductMarketRuntimeController.PRODUCT_CATALOG.size())
	_codex_navigation_controller_node().previewed_product_codex_index = _valid_product_codex_index(_codex_navigation_controller_node().previewed_product_codex_index)
	_codex_navigation_controller_node().product_codex_grid_page = clampi(_codex_navigation_controller_node().product_codex_grid_page, 0, _codex_page_count(ProductMarketRuntimeController.PRODUCT_CATALOG.size(), _product_codex_entries_per_page()) - 1)
	var product_name := String(ProductMarketRuntimeController.PRODUCT_CATALOG[_codex_navigation_controller_node().product_codex_index])
	var product_snapshot := _product_codex_public_snapshot(product_name, _codex_navigation_controller_node().product_codex_index, true)
	var body_text := str(product_snapshot.get("summary_text", "")) if _codex_navigation_controller_node().product_codex_show_detail else _product_codex_grid_text()
	_present_codex_page("商品图鉴", body_text, {
		"mode": "product",
		"view": "detail" if _codex_navigation_controller_node().product_codex_show_detail else "browser",
		"detail": product_snapshot.get("detail", {}) if _codex_navigation_controller_node().product_codex_show_detail else {},
		"browser": _product_codex_browser_snapshot() if not _codex_navigation_controller_node().product_codex_show_detail else {},
		"navigation": _codex_navigation_data(
			_codex_navigation_controller_node().product_codex_show_detail,
			_codex_navigation_controller_node().product_codex_show_detail,
			"返回缩略图" if _codex_navigation_controller_node().product_codex_show_detail else _catalog_back_button_text()
		),
	})


func _valid_product_codex_index(index: int) -> int:
	return clampi(index, 0, max(0, ProductMarketRuntimeController.PRODUCT_CATALOG.size() - 1))


func _product_codex_grid_columns() -> int:
	return clampi(int(floor(_menu_available_content_width() / 170.0)), 2, 5)


func _product_codex_grid_rows() -> int:
	return clampi(int(floor(_menu_available_content_height() / 150.0)), 1, 4)


func _product_codex_entries_per_page() -> int:
	return maxi(1, _product_codex_grid_columns() * _product_codex_grid_rows())


func _product_count_summary(counts: Dictionary, limit: int = 4, empty_text: String = "暂无") -> String:
	var entries := []
	for key_variant in counts.keys():
		var key := String(key_variant)
		entries.append({"label": key, "count": int(counts.get(key, 0))})
	entries.sort_custom(Callable(self, "_sort_product_count_entry_desc"))
	var pieces := []
	for i in range(mini(limit, entries.size())):
		var entry := entries[i] as Dictionary
		pieces.append("%s×%d" % [String(entry.get("label", "")), int(entry.get("count", 0))])
	return " / ".join(pieces) if not pieces.is_empty() else empty_text


func _sort_product_count_entry_desc(a: Dictionary, b: Dictionary) -> bool:
	var count_a := int(a.get("count", 0))
	var count_b := int(b.get("count", 0))
	if count_a != count_b:
		return count_a > count_b
	return String(a.get("label", "")) < String(b.get("label", ""))


func _product_codex_grid_text() -> String:
	var page_count := _codex_page_count(ProductMarketRuntimeController.PRODUCT_CATALOG.size(), _product_codex_entries_per_page())
	var report := _game_runtime_coordinator_node().gameplay_balance_diagnostics_service().product_ecosystem_report()
	return "商品目录｜第%d/%d页｜本页%d×%d\n本局出现%d/%d种商品（海%d/陆%d）。看价格、供需、趋势和主打法；悬停预览，双击详情。" % [
		_codex_navigation_controller_node().product_codex_grid_page + 1,
		page_count,
		_product_codex_grid_columns(),
		_product_codex_grid_rows(),
		int(report.get("run_product_count", 0)),
		int(report.get("catalog_count", ProductMarketRuntimeController.PRODUCT_CATALOG.size())),
		int(report.get("run_ocean_count", 0)),
		int(report.get("run_land_count", 0)),
	]


func _turn_product_codex_grid_page(step: int) -> void:
	if ProductMarketRuntimeController.PRODUCT_CATALOG.is_empty():
		return
	var page_count := _codex_page_count(ProductMarketRuntimeController.PRODUCT_CATALOG.size(), _product_codex_entries_per_page())
	_codex_navigation_controller_node().product_codex_grid_page = wrapi(_codex_navigation_controller_node().product_codex_grid_page + step, 0, page_count)
	var first_index := _codex_first_index_on_page(_codex_navigation_controller_node().product_codex_grid_page, ProductMarketRuntimeController.PRODUCT_CATALOG.size(), _product_codex_entries_per_page())
	_codex_navigation_controller_node().product_codex_index = first_index
	_codex_navigation_controller_node().previewed_product_codex_index = first_index
	_codex_navigation_controller_node().product_codex_show_detail = false
	_update_product_codex_menu()


func _product_codex_browser_snapshot() -> Dictionary:
	var total_count := ProductMarketRuntimeController.PRODUCT_CATALOG.size()
	var page_count := _codex_page_count(total_count, _product_codex_entries_per_page())
	_codex_navigation_controller_node().product_codex_grid_page = clampi(_codex_navigation_controller_node().product_codex_grid_page, 0, max(0, page_count - 1))
	var per_page := _product_codex_entries_per_page()
	var start_index: int = int(_codex_navigation_controller_node().product_codex_grid_page) * per_page
	var end_index := mini(total_count, start_index + per_page)
	if start_index >= total_count:
		start_index = _codex_first_index_on_page(_codex_navigation_controller_node().product_codex_grid_page, total_count, _product_codex_entries_per_page())
		end_index = mini(total_count, start_index + per_page)
	if _codex_navigation_controller_node().previewed_product_codex_index < start_index or _codex_navigation_controller_node().previewed_product_codex_index >= end_index:
		_codex_navigation_controller_node().previewed_product_codex_index = start_index
		_codex_navigation_controller_node().product_codex_index = start_index
	var report := _game_runtime_coordinator_node().gameplay_balance_diagnostics_service().product_ecosystem_report()
	var entries: Array = []
	for catalog_index in range(start_index, end_index):
		var product_name := str(ProductMarketRuntimeController.PRODUCT_CATALOG[catalog_index])
		var product_snapshot := _product_codex_public_snapshot(product_name, catalog_index, catalog_index == _codex_navigation_controller_node().previewed_product_codex_index)
		entries.append(product_snapshot.get("browser_entry", {}))
	return {
		"columns": _product_codex_grid_columns(),
		"selected_index": _codex_navigation_controller_node().previewed_product_codex_index,
		"can_page": page_count > 1,
		"page_label": "第%d/%d页｜%d种商品｜本页%d-%d" % [_codex_navigation_controller_node().product_codex_grid_page + 1, page_count, total_count, start_index + 1, end_index],
		"summaries": [
			{"title": "本局商品生态", "body": "图鉴%d种｜本局%d种｜海洋%d/陆地%d｜区域产%d/需%d" % [int(report.get("catalog_count", 0)), int(report.get("run_product_count", 0)), int(report.get("run_ocean_count", 0)), int(report.get("run_land_count", 0)), int(report.get("district_product_slots", 0)), int(report.get("district_demand_slots", 0))], "meta": "城市生产槽%d｜城市需求槽%d｜商品符号%d/%d" % [int(report.get("active_city_product_slots", 0)), int(report.get("active_city_demand_slots", 0)), int(report.get("profile_complete_count", 0)), int(report.get("catalog_count", 0))], "accent": Color("#22c55e")},
			{"title": "策略入口", "body": _product_count_summary(report.get("strategy_counts", {}) as Dictionary, 5), "meta": "热点:%s" % _limited_name_list(report.get("top_hotspots", []) as Array, 5, "暂无"), "accent": Color("#facc15")},
			{"title": "商品路线分布", "body": _product_count_summary(report.get("route_counts", {}) as Dictionary, 5), "meta": "品类:%s" % _product_count_summary(report.get("category_counts", {}) as Dictionary, 4), "accent": Color("#38bdf8")},
			{"title": "牌路连接", "body": "相关卡覆盖%d种｜怪兽偏好覆盖%d种" % [int(report.get("related_card_product_count", 0)), int(report.get("monster_focus_product_count", 0))], "meta": "商品连接GDP、区域补给、期货、仓储、商路和怪兽目标。", "accent": Color("#c084fc")},
		],
		"entries": entries,
		"preview": (_product_codex_public_snapshot(str(ProductMarketRuntimeController.PRODUCT_CATALOG[_codex_navigation_controller_node().previewed_product_codex_index]), _codex_navigation_controller_node().previewed_product_codex_index, true)).get("detail", {}) if not ProductMarketRuntimeController.PRODUCT_CATALOG.is_empty() else {},
	}
func _product_codex_public_source_snapshot(product_name: String, catalog_index: int = -1, selected: bool = false) -> Dictionary:
	if product_name == "" or not ProductMarketRuntimeController.PRODUCT_CATALOG.has(product_name):
		return {"valid": false, "name": product_name, "index": catalog_index, "total": ProductMarketRuntimeController.PRODUCT_CATALOG.size()}
	_product_market_runtime_call("ensure_catalog")
	var safe_index := ProductMarketRuntimeController.PRODUCT_CATALOG.find(product_name) if catalog_index < 0 or catalog_index >= ProductMarketRuntimeController.PRODUCT_CATALOG.size() or str(ProductMarketRuntimeController.PRODUCT_CATALOG[catalog_index]) != product_name else catalog_index
	var market_entry := _product_market_entry_snapshot(product_name)
	var current_price := _product_market_price(product_name)
	var base_price := int(market_entry.get("base_price", current_price))
	var clue_facts := _product_public_clue_facts(product_name, 4)
	return {
		"valid": true,
		"index": safe_index,
		"total": ProductMarketRuntimeController.PRODUCT_CATALOG.size(),
		"selected": selected,
		"name": product_name,
		"profile": _product_profile(product_name).duplicate(true),
		"market": {
			"current_price": current_price,
			"base_price": base_price,
			"tier": str(market_entry.get("tier", _product_market_tier(product_name))),
			"trend_text": _product_trend_text(product_name),
			"price_path_text": _product_market_price_path_text(market_entry),
			"supply": int(market_entry.get("supply", 0)),
			"demand": int(market_entry.get("demand", 0)),
			"disrupted": int(market_entry.get("disrupted", 0)),
			"volatility": int(market_entry.get("volatility", 0)),
			"weather_text": _product_market_boon_text(product_name),
		},
		"strategy_rankings": _product_strategy_rankings(product_name).duplicate(true),
		"futures_public_full": _product_market_futures_public_text(product_name),
		"futures_public_compact": _product_market_futures_public_text(product_name, true),
		"warehouse_public_entries": _product_warehouse_public_facts(product_name, 4),
		"monster_focus_names": _product_monster_focus_name_facts(product_name, 6),
		"related_card_names": _product_related_card_name_facts(product_name, 8),
		"supply_district_names": _product_related_district_name_facts(product_name, "products", 6),
		"demand_district_names": _product_related_district_name_facts(product_name, "demands", 6),
		"public_clue_lines": (clue_facts.get("lines", []) as Array).duplicate(true),
		"public_clue_labels": (clue_facts.get("labels", []) as Array).duplicate(true),
	}


func _product_codex_public_snapshot(product_name: String, catalog_index: int = -1, selected: bool = false) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	var source := _product_codex_public_source_snapshot(product_name, catalog_index, selected)
	var value: Variant = coordinator.call("compose_product_codex_snapshot", source) if coordinator != null and coordinator.has_method("compose_product_codex_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _product_warehouse_public_facts(product_name: String, limit: int = 4) -> Array:
	var entries := []
	for district_index_variant in _active_city_district_indices():
		var district_index := int(district_index_variant)
		var city := _district_city(district_index)
		var products: Array = city.get("warehouse_stockpile_products", [])
		if not products.has(product_name):
			continue
		var expires_at := float(city.get("warehouse_stockpile_expires_at", -1.0))
		entries.append({
			"name": str(districts[district_index].get("name", "城市")),
			"pressure": _city_warehouse_stockpile_pressure(city),
			"units": int(city.get("warehouse_stockpile_units", 0)),
			"count": int(city.get("warehouse_stockpile_count", 0)),
			"duration": _duration_short_text(maxf(1.0, expires_at - game_time)) if expires_at >= 0.0 else "未知",
		})
	entries.sort_custom(Callable(self, "_sort_product_warehouse_entry"))
	return _first_entries(entries, limit)


func _product_related_card_name_facts(product_name: String, limit: int = 8) -> Array:
	var names := []
	for skill_name_variant in _game_runtime_coordinator_node().card_catalog_ordered_ids():
		var skill_name := str(skill_name_variant)
		var skill: Dictionary = _game_runtime_coordinator_node().card_authored_catalog_definition(skill_name)
		var matches := str(skill.get("play_product", "")) == product_name
		var contract_products_variant: Variant = skill.get("contract_products", [])
		if not matches and contract_products_variant is Array:
			matches = (contract_products_variant as Array).has(product_name)
		if matches:
			names.append(skill_name)
	return _first_entries(names, limit)


func _product_monster_focus_name_facts(product_name: String, limit: int = 6) -> Array:
	var names := []
	for monster_variant in MONSTER_ROSTER:
		var monster: Dictionary = monster_variant
		if (monster.get("resource_focus", []) as Array).has(product_name):
			names.append(str(monster.get("name", "怪兽")))
	return _first_entries(names, limit)


func _product_related_district_name_facts(product_name: String, field_name: String, limit: int = 6) -> Array:
	var names := []
	for district_variant in districts:
		var district: Dictionary = district_variant
		if (district.get(field_name, []) as Array).has(product_name):
			names.append(str(district.get("name", "区域")))
	return _first_entries(names, limit)


func _product_public_clue_facts(product_name: String, limit: int = 4) -> Dictionary:
	var lines := []
	var labels := []
	for clue_variant in _economy_city_public_clue_entries(limit, product_name):
		var clue: Dictionary = clue_variant
		lines.append(_economy_city_public_clue_line(clue))
		labels.append("%s/%s" % [str(clue.get("district", "城市")), str(clue.get("kind", "线索"))])
	return {"lines": lines, "labels": labels}


func _product_strategy_scores(product_name: String) -> Dictionary:
	_product_market_runtime_call("ensure_catalog")
	var entry := _product_market_entry_snapshot(product_name)
	var supply := int(entry.get("supply", 0))
	var demand := int(entry.get("demand", 0))
	var disrupted := int(entry.get("disrupted", 0))
	var volatility := int(entry.get("volatility", 0))
	var temporary_demand := int(entry.get("temporary_demand_pressure", 0))
	var temporary_supply := int(entry.get("temporary_supply_pressure", 0))
	var contract_seconds := _remaining_effect_seconds(entry, "market_contract_seconds", "market_contract_turns")
	var contract_demand := int(entry.get("market_contract_demand", 0)) if contract_seconds > 0.0 else 0
	var contract_supply := int(entry.get("market_contract_supply", 0)) if contract_seconds > 0.0 else 0
	var futures := _product_market_futures_public_counts(product_name)
	var warehouse_units := int(futures.get("warehouse_units", 0))
	var monster_focus_count := _product_monster_focus_count(product_name)
	var growth_bonus := int(round(maxf(0.0, float(entry.get("growth_multiplier", 1.0)) - 1.0) * 40.0))
	var route_bonus := int(round(maxf(0.0, float(entry.get("route_flow_multiplier", 1.0)) - 1.0) * 32.0))
	var long_score := maxi(0, demand - supply) * 14 + demand * 3 + disrupted * 10 + temporary_demand * 8 + contract_demand * 9 + growth_bonus + int(futures.get("up", 0)) * 3
	var short_score := maxi(0, supply - demand) * 14 + supply * 3 + temporary_supply * 8 + contract_supply * 9 + volatility * 2 + int(futures.get("down", 0)) * 3
	var stockpile_score := long_score + volatility * 4 + warehouse_units * 5 + route_bonus
	var route_score := (supply + demand) * 6 + route_bonus + disrupted * 4 + contract_demand * 3 + contract_supply * 3
	var monster_risk_score := monster_focus_count * 18 + warehouse_units * 7 + disrupted * 3
	return {
		"long": maxi(0, long_score),
		"short": maxi(0, short_score),
		"stockpile": maxi(0, stockpile_score),
		"route": maxi(0, route_score),
		"monster": maxi(0, monster_risk_score),
		"supply": supply,
		"demand": demand,
		"disrupted": disrupted,
		"volatility": volatility,
	}


func _product_strategy_rankings(product_name: String) -> Array:
	var scores := _product_strategy_scores(product_name)
	var ranked := [
		{"label": "看涨", "score": int(scores.get("long", 0)), "hint": "需求、断路、合约或成长天气正在支撑价格。"},
		{"label": "看跌", "score": int(scores.get("short", 0)), "hint": "供给、套保或供给压力较强，适合压价。"},
		{"label": "囤货", "score": int(scores.get("stockpile", 0)), "hint": "波动和看涨空间适合港仓囤货，但仓库会变成公开靶标。"},
		{"label": "商路", "score": int(scores.get("route", 0)), "hint": "供需两端和流通速度适合合约、交通和城市GDP路线。"},
		{"label": "怪兽风险", "score": int(scores.get("monster", 0)), "hint": "偏好该商品的怪兽或仓储压力会增加被引怪概率。"},
	]
	ranked.sort_custom(Callable(self, "_sort_product_strategy_score_desc"))
	return ranked


func _product_primary_strategy_entry(product_name: String) -> Dictionary:
	var ranked := _product_strategy_rankings(product_name)
	if ranked.is_empty():
		return {"label": "观察", "score": 0, "hint": "观察供需变化。"}
	return ranked[0] as Dictionary


func _sort_product_strategy_score_desc(a: Dictionary, b: Dictionary) -> bool:
	var score_a := int(a.get("score", 0))
	var score_b := int(b.get("score", 0))
	if score_a != score_b:
		return score_a > score_b
	return String(a.get("label", "")) < String(b.get("label", ""))


func _sort_product_warehouse_entry(a: Dictionary, b: Dictionary) -> bool:
	var pressure_a := int(a.get("pressure", 0))
	var pressure_b := int(b.get("pressure", 0))
	if pressure_a != pressure_b:
		return pressure_a > pressure_b
	return int(a.get("units", 0)) > int(b.get("units", 0))


func _product_monster_focus_count(product_name: String) -> int:
	var count := 0
	for monster_variant in MONSTER_ROSTER:
		var monster: Dictionary = monster_variant
		var focus: Array = monster.get("resource_focus", [])
		if focus.has(product_name):
			count += 1
	return count


func _product_profile(product_name: String) -> Dictionary:
	var profile: Dictionary = ProductMarketRuntimeController.PRODUCT_PROFILES.get(product_name, {})
	if not profile.is_empty():
		return profile
	return {
		"category": "未分类商品",
		"route": "通用商业线",
		"terrain": "随机区域",
		"use": "参与供需、商路、GDP和出牌门槛。",
		"hook": "等待后续平衡时补充专属机制。",
		"flavor": "一件还没有被星际商会充分命名的货物。",
		"glyph": "◇",
		"accent": Color("#22c55e"),
		"secondary": Color("#f8fafc"),
	}


func _product_profile_has_required_fields(product_name: String) -> bool:
	var profile := _product_profile(product_name)
	for key in ["category", "route", "terrain", "use", "hook", "flavor", "glyph", "accent", "secondary"]:
		if not profile.has(String(key)):
			return false
		if ["category", "route", "terrain", "use", "hook", "flavor", "glyph"].has(String(key)) and String(profile.get(String(key), "")) == "":
			return false
	return true


func _product_related_card_count(product_name: String) -> int:
	var count := 0
	for skill_name_variant in _game_runtime_coordinator_node().card_catalog_ordered_ids():
		var skill_name := String(skill_name_variant)
		var skill: Dictionary = _game_runtime_coordinator_node().card_authored_catalog_definition(skill_name)
		var matches := String(skill.get("play_product", "")) == product_name
		var contract_products_variant: Variant = skill.get("contract_products", [])
		if not matches and contract_products_variant is Array:
			matches = (contract_products_variant as Array).has(product_name)
		if matches:
			count += 1
	return count


func _preview_product_codex_entry(catalog_index: int, refresh: bool = true) -> void:
	if ProductMarketRuntimeController.PRODUCT_CATALOG.is_empty():
		return
	_codex_navigation_controller_node().previewed_product_codex_index = _valid_product_codex_index(catalog_index)
	_codex_navigation_controller_node().product_codex_index = _codex_navigation_controller_node().previewed_product_codex_index
	if refresh:
		var saved_scroll := int(menu_overlay.call("content_scroll_value")) if menu_overlay != null and menu_overlay.has_method("content_scroll_value") else 0
		_update_product_codex_menu()
		_queue_restore_menu_scroll(saved_scroll)


func _open_product_codex_detail(catalog_index: int) -> void:
	_preview_product_codex_entry(catalog_index, false)
	_codex_navigation_controller_node().product_codex_show_detail = true
	_codex_navigation_controller_node().product_codex_grid_page = _codex_page_for_index(_codex_navigation_controller_node().product_codex_index, ProductMarketRuntimeController.PRODUCT_CATALOG.size(), _product_codex_entries_per_page())
	_update_product_codex_menu()


func _open_region_codex_menu(index: int = -1) -> void:
	if _codex_navigation_controller_node().return_target == "":
		_codex_navigation_controller_node().return_target = "compendium"
	if index >= 0 and index < districts.size():
		_codex_navigation_controller_node().region_codex_index = index
		_jump_to_district_on_table(index)
	_update_region_codex_menu()


func _cycle_region_codex(step: int) -> void:
	if districts.is_empty():
		return
	_codex_navigation_controller_node().region_codex_index = wrapi(_codex_navigation_controller_node().region_codex_index + step, 0, districts.size())
	_jump_to_district_on_table(_codex_navigation_controller_node().region_codex_index)
	_update_region_codex_menu()


func _update_region_codex_menu() -> void:
	if districts.is_empty():
		_show_catalog_empty_page("区域图鉴", "开局后会在这里列出本局随机星球的全部区域：陆地/海洋、公开供需、城市公开状态、区域卡池和邻接关系。")
		return
	_codex_navigation_controller_node().region_codex_index = wrapi(_codex_navigation_controller_node().region_codex_index, 0, districts.size())
	var region_snapshot := _game_runtime_coordinator_node().region_codex_public_snapshot(_codex_navigation_controller_node().region_codex_index)
	_present_codex_page("区域图鉴", str(region_snapshot.get("summary_text", "区域不存在。")), {
		"mode": "region",
		"view": "detail",
		"detail": region_snapshot.get("detail", {}),
		"navigation": _codex_navigation_data(true, true, _catalog_back_button_text()),
	})


func _show_catalog_empty_page(title_text: String, body_text: String) -> void:
	var mode := "product"
	match title_text:
		"区域图鉴":
			mode = "region"
		"角色图鉴":
			mode = "role"
		"卡牌图鉴":
			mode = "card"
		"怪兽生态档案":
			mode = "monster"
	_present_codex_page(title_text, body_text, {
		"mode": mode,
		"view": "empty",
		"empty": {"title": title_text, "body": body_text},
		"navigation": _codex_navigation_data(false, false, _catalog_back_button_text()),
	})


func _card_codex_filter_options() -> Array:
	return [
		{"id": "all", "label": "全部"},
		{"id": "monster", "label": "怪兽牌"},
		{"id": "monster_skill", "label": "怪兽技能"},
		{"id": "military", "label": "军队/军令"},
		{"id": "interaction", "label": "玩家互动"},
		{"id": "city", "label": "城市经营"},
		{"id": "commodity", "label": "商品经营"},
		{"id": "futures", "label": "商品期货"},
		{"id": "finance", "label": "金融/GDP"},
		{"id": "contract", "label": "合约"},
		{"id": "intel", "label": "情报推理"},
		{"id": "supply", "label": "补给/采购"},
		{"id": "tactic", "label": "怪兽诱导"},
		{"id": "news", "label": "新闻事件"},
		{"id": "weather", "label": "天气干预"},
		{"id": "other", "label": "其他"},
	]


func _card_codex_filter_label(filter_id: String = "") -> String:
	if filter_id == "":
		filter_id = _codex_navigation_controller_node().card_codex_filter
	if filter_id.begins_with("route:"):
		return "路线:%s" % _game_runtime_coordinator_node().gameplay_balance_diagnostics_service().route_label(filter_id.trim_prefix("route:"))
	for option_variant in _card_codex_filter_options():
		var option: Dictionary = option_variant
		if String(option.get("id", "")) == filter_id:
			return String(option.get("label", filter_id))
	match filter_id:
		"economy":
			return "经济聚合"
		"business":
			return "经营/合约"
		"combat":
			return "战斗/指令"
	return "全部"






















func _set_card_codex_filter(filter_id: String) -> void:
	_codex_navigation_controller_node().card_codex_filter = filter_id
	_codex_navigation_controller_node().card_codex_index = 0
	_codex_navigation_controller_node().card_codex_grid_page = 0
	_codex_navigation_controller_node().card_codex_show_detail = false
	_codex_navigation_controller_node().previewed_card_codex_card = ""
	_update_card_codex_menu()


func _card_codex_filter_category_ids(filter_id: String) -> Array:
	match filter_id:
		"all":
			return []
		"economy":
			return ["city", "commodity", "futures", "finance", "contract"]
		"business":
			return ["city", "contract"]
		"combat":
			return ["monster_skill", "military", "tactic"]
		_:
			return [filter_id]


func _card_codex_filter_matches(filter_id: String, category_id: String) -> bool:
	if filter_id == "all":
		return true
	return _card_codex_filter_category_ids(filter_id).has(category_id)


func _card_source_type_label(card_name: String, skill: Dictionary) -> String:
	if _is_monster_card_name(card_name) or String(skill.get("kind", "")) == "monster_card":
		return "怪兽牌"
	if _is_monster_technique_card_name(card_name) or String(skill.get("kind", "")) == "monster_bound_action":
		return "怪兽固定技能"
	if bool(skill.get("persistent", false)):
		return "固定技能"
	return "公共卡牌"


func _card_is_in_district_supply(card_name: String) -> bool:
	var canonical_name := _canonical_card_supply_name(card_name)
	if canonical_name == "":
		return false
	for district_variant in districts:
		if not (district_variant is Dictionary):
			continue
		var district: Dictionary = district_variant
		for choice_variant in district.get("card_choices", []):
			if _canonical_card_supply_name(String(choice_variant)) == canonical_name:
				return true
	return false


func _card_supply_layer_for_card(card_name: String) -> String:
	var canonical_name := _canonical_card_supply_name(card_name)
	if canonical_name == "":
		return "全部卡牌"
	if _card_is_in_district_supply(canonical_name):
		return "区域补给"
	if _current_run_card_pool().has(canonical_name):
		return "本局星球牌池"
	return "全部卡牌"


func _card_codex_short_filter_label(filter_id: String) -> String:
	match filter_id:
		"all":
			return "全部"
		"monster":
			return "怪兽"
		"monster_skill":
			return "兽技"
		"military":
			return "军队"
		"interaction":
			return "互动"
		"city":
			return "城市"
		"commodity":
			return "商品"
		"futures":
			return "期货"
		"finance":
			return "金融"
		"contract":
			return "合约"
		"intel":
			return "情报"
		"supply":
			return "补给"
		"tactic":
			return "诱导"
		"news":
			return "新闻"
		"weather":
			return "天气"
		"other":
			return "其他"
	return _card_codex_filter_label(filter_id)


func _card_codex_names(filter_id: String = "") -> Array:
	if filter_id == "":
		filter_id = _codex_navigation_controller_node().card_codex_filter
	var route_filter := ""
	if filter_id.begins_with("route:"):
		route_filter = filter_id.trim_prefix("route:")
	var names := []
	for monster_card_variant in _monster_card_names(1):
		var monster_card_name := String(monster_card_variant)
		var monster_skill := _game_runtime_coordinator_node().card_definition(monster_card_name)
		if _card_codex_filter_matches(filter_id, "monster") or (route_filter != "" and _game_runtime_coordinator_node().gameplay_balance_diagnostics_service().route_id_for_card(monster_skill) == route_filter):
			monster_runtime_controller._append_unique_string(names, monster_card_name)
	for name_variant in _game_runtime_coordinator_node().card_catalog_ordered_ids():
		var card_name := _canonical_card_supply_name(String(name_variant))
		if card_name == "" or names.has(card_name):
			continue
		var skill := _game_runtime_coordinator_node().card_definition(card_name)
		var category := str(_card_presentation_snapshot(card_name, skill).get("category_id", "other"))
		if _card_codex_filter_matches(filter_id, category) or (route_filter != "" and _game_runtime_coordinator_node().gameplay_balance_diagnostics_service().route_id_for_card(skill) == route_filter):
			monster_runtime_controller._append_unique_string(names, card_name)
	names.sort()
	return names


func _card_level_gradient_text(card_name: String) -> String:
	var family := _game_runtime_coordinator_node().card_family_id(card_name)
	var diagnostics := _game_runtime_coordinator_node().gameplay_balance_diagnostics_service()
	var lines := []
	for level in range(1, 5):
		var level_name := "%s%d" % [family, level]
		if not _game_runtime_coordinator_node().card_exists(level_name):
			continue
		var level_skill := _game_runtime_coordinator_node().card_definition(level_name)
		var numeric_facts := _card_presentation_array(level_skill, "key_rule_facts")
		var preview := _join_first_card_facts(numeric_facts, 4)
		if preview == "":
			preview = _short_card_text(_skill_display_text(level_skill), 36)
		lines.append("%s  ¥%d  %s｜%s" % [
			_level_text(level),
			_card_price(level_name),
			diagnostics.card_budget_band_text(diagnostics.card_budget_points_for_id(level_name)),
			preview,
		])
	return "\n".join(lines) if not lines.is_empty() else "该卡暂无I→IV强化。"


func _product_trend_text(product_name: String) -> String:
	var entry := _product_market_entry_snapshot(product_name)
	var trend := int(entry.get("trend", 0))
	if trend > 0:
		return "+%d" % trend
	if trend < 0:
		return "%d" % trend
	return "持平"


func _product_market_price_path_text(entry: Dictionary, limit: int = 7) -> String:
	var history: Array = entry.get("price_history", [])
	if history.is_empty():
		return str(int(entry.get("price", entry.get("base_price", 0))))
	var pieces := []
	var start_index: int = maxi(0, history.size() - maxi(2, limit))
	for i in range(start_index, history.size()):
		pieces.append(str(int(history[i])))
	return "→".join(pieces)


func _limited_name_list(names: Array, limit: int = 6, empty_text: String = "无") -> String:
	if names.is_empty():
		return empty_text
	var pieces := []
	for i in range(min(limit, names.size())):
		pieces.append(String(names[i]))
	if names.size() > limit:
		pieces.append("+%d" % (names.size() - limit))
	return "、".join(pieces)


func _record_player_cash_snapshot(player_index: int) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	var player: Dictionary = players[player_index]
	if not player.has("economic_ledger"):
		player["economic_ledger"] = []
	var history: Array = player.get("cash_history", [])
	var current_cash := int(player.get("cash", 0))
	if history.is_empty() or int(history[history.size() - 1]) != current_cash:
		history.append(current_cash)
	while history.size() > ECONOMY_HISTORY_LIMIT:
		history.pop_front()
	player["cash_history"] = history
	players[player_index] = player


func _record_player_economic_event(player_index: int, kind: String, label: String, amount: int, detail: String = "") -> void:
	if player_index < 0 or player_index >= players.size():
		return
	var player: Dictionary = players[player_index]
	var ledger: Array = player.get("economic_ledger", [])
	ledger.append({
		"cycle": _product_market_cycle(),
		"time": game_time,
		"kind": kind,
		"label": label,
		"amount": amount,
		"cash_after": int(player.get("cash", 0)),
		"detail": detail,
	})
	while ledger.size() > ECONOMY_LEDGER_LIMIT:
		ledger.pop_front()
	player["economic_ledger"] = ledger
	players[player_index] = player


func _record_player_card_spend(player_index: int, amount: int, label: String = "卡牌支出", detail: String = "") -> void:
	if player_index < 0 or player_index >= players.size() or amount <= 0:
		return
	players[player_index]["total_card_spend"] = int(players[player_index].get("total_card_spend", 0)) + amount
	_record_player_economic_event(player_index, "卡牌支出", label, -amount, detail)
	_record_player_cash_snapshot(player_index)


func _record_player_card_income(player_index: int, amount: int, label: String = "卡牌收入", detail: String = "") -> void:
	if player_index < 0 or player_index >= players.size() or amount <= 0:
		return
	players[player_index]["total_card_income"] = int(players[player_index].get("total_card_income", 0)) + amount
	_record_player_economic_event(player_index, "卡牌收入", label, amount, detail)
	_record_player_cash_snapshot(player_index)


func _player_product_flow(player_index: int, product_name: String) -> int:
	if player_index < 0 or player_index >= players.size() or product_name == "":
		return 0
	var flow := 0
	for city_index_variant in _ai_runtime_call("_active_city_indices_for_player", [player_index]):
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		for product_variant in city.get("products", []):
			var product: Dictionary = product_variant
			if String(product.get("name", "")) == product_name:
				flow += maxi(1, int(product.get("level", 1)))
		for route_variant in city.get("trade_routes", []):
			var route: Dictionary = route_variant
			if bool(route.get("disrupted", false)):
				continue
			if String(route.get("product", "")) == product_name:
				flow += 1
		for demand_variant in city.get("demands", []):
			if String(demand_variant) == product_name:
				flow += 1
	return flow


func _first_player_flow_product(player_index: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return ""
	for city_index_variant in _ai_runtime_call("_active_city_indices_for_player", [player_index]):
		var city := _district_city(int(city_index_variant))
		var products := _city_product_names(city)
		if not products.is_empty():
			return String(products[0])
		var demands := _city_demand_names(city)
		if not demands.is_empty():
			return String(demands[0])
	return selected_trade_product if selected_trade_product != "" else (String(ProductMarketRuntimeController.PRODUCT_CATALOG[0]) if not ProductMarketRuntimeController.PRODUCT_CATALOG.is_empty() else "")


func _best_player_flow_product(player_index: int, required: int = 1, preferred_products: Array = []) -> String:
	if player_index < 0 or player_index >= players.size():
		return ""
	var safe_required: int = maxi(1, required)
	var seen := {}
	var preferred := []
	for product_variant in preferred_products:
		var product_name := String(product_variant)
		if product_name == "" or seen.has(product_name):
			continue
		seen[product_name] = true
		preferred.append(product_name)
	for product_variant in preferred:
		if _player_product_flow(player_index, String(product_variant)) >= safe_required:
			return String(product_variant)
	var best_product := ""
	var best_flow := -1
	for city_index_variant in _ai_runtime_call("_active_city_indices_for_player", [player_index]):
		var city := _district_city(int(city_index_variant))
		var products := _city_product_names(city)
		for product_variant in products:
			var product_name := String(product_variant)
			if product_name == "" or seen.has(product_name):
				continue
			seen[product_name] = true
			var flow := _player_product_flow(player_index, product_name)
			if flow >= safe_required and flow > best_flow:
				best_product = product_name
				best_flow = flow
		var demands := _city_demand_names(city)
		for demand_variant in demands:
			var demand_name := String(demand_variant)
			if demand_name == "" or seen.has(demand_name):
				continue
			seen[demand_name] = true
			var demand_flow := _player_product_flow(player_index, demand_name)
			if demand_flow >= safe_required and demand_flow > best_flow:
				best_product = demand_name
				best_flow = demand_flow
		for route_variant in city.get("trade_routes", []):
			var route: Dictionary = route_variant
			if bool(route.get("disrupted", false)):
				continue
			var route_product := String(route.get("product", ""))
			if route_product == "" or seen.has(route_product):
				continue
			seen[route_product] = true
			var route_flow := _player_product_flow(player_index, route_product)
			if route_flow >= safe_required and route_flow > best_flow:
				best_product = route_product
				best_flow = route_flow
	return best_product


func _card_play_eligibility_snapshot(player_index: int, skill: Dictionary, evaluation_mode: String = "rule", context: Dictionary = {}) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("card_play_world_facts") or not coordinator.has_method("evaluate_card_play"):
		_mark_game_runtime_coordinator_missing(true)
		return {"allowed": false, "actionable": false, "reason_code": "service_missing"}
	var facts_variant: Variant = coordinator.call("card_play_world_facts", player_index, skill, context)
	var facts: Dictionary = facts_variant if facts_variant is Dictionary else {}
	var value: Variant = coordinator.call("evaluate_card_play", {"player_index": player_index, "skill": skill, "evaluation_mode": evaluation_mode}, facts)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"allowed": false, "actionable": false, "reason_code": "service_missing"}


func _card_play_requirement_snapshot(player_index: int, skill: Dictionary, context: Dictionary = {}) -> Dictionary:
	var evaluation := _card_play_eligibility_snapshot(player_index, skill, "catalog", context)
	var value: Variant = evaluation.get("requirement_status", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_play_target_snapshot(skill: Dictionary) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("card_play_target_status"):
		return {}
	var value: Variant = coordinator.call("card_play_target_status", {"skill": skill}, {
		"player_count": players.size(),
		"monster_count": monster_runtime_controller.auto_monsters.size(),
	})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_play_presentation_snapshot(eligibility: Dictionary, skill: Dictionary = {}) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("compose_card_play_eligibility"):
		return {}
	var card_name := String(skill.get("name", "卡牌"))
	var value: Variant = coordinator.call("compose_card_play_eligibility", eligibility, {"card_name": card_name, "display_name": _card_display_name(card_name)})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _authorize_card_play(player_index: int, skill: Dictionary, show_log: bool = true, evaluation_mode: String = "rule") -> bool:
	var eligibility := _card_play_eligibility_snapshot(player_index, skill, evaluation_mode)
	if bool(eligibility.get("allowed", false)):
		return true
	if show_log:
		_log_card_play_rejection(eligibility, skill)
	return false


func _log_card_play_rejection(eligibility: Dictionary, skill: Dictionary) -> void:
	var presentation := _card_play_presentation_snapshot(eligibility, skill)
	var log_message := String(presentation.get("log_message", ""))
	if log_message != "":
		_log(log_message)


func _skill_play_product(skill: Dictionary, player_index: int) -> String:
	# Compatibility/content-affinity helper. Products decide which planet/region
	# can offer a card; they are no longer the default cost paid to play it.
	var explicit := String(skill.get("play_product", ""))
	if explicit != "":
		return explicit
	if selected_trade_product != "":
		return selected_trade_product
	return _first_player_flow_product(player_index)


func _skill_play_flow_required(skill: Dictionary, _player_index: int = -1) -> int:
	# Deprecated compatibility hook. The live gate is regional GDP share; an
	# old fixed-product field may still be kept as supply affinity.
	return maxi(0, int(skill.get("play_flow_required", 0))) if bool(skill.get("legacy_flow_gate_enabled", false)) else 0
func _player_region_gdp_share_basis_points(player_index: int, district_index: int) -> int:
	if district_index < 0 or district_index >= districts.size():
		return 0
	var region_id := str((districts[district_index] as Dictionary).get("region_id", "region.%03d" % district_index))
	return int(_commodity_flow_runtime_call("player_region_gdp_share_basis_points", [player_index, region_id]))


func _best_player_gdp_share_district(player_index: int) -> int:
	var best_district := -1
	var best_share := -1
	var best_gdp := -1
	for district_index in range(districts.size()):
		var share := _player_region_gdp_share_basis_points(player_index, district_index)
		if share <= 0:
			continue
		var city := _district_city(district_index)
		var city_gdp := _city_gdp_per_minute(district_index, int(city.get("competition_matches", _city_competition_matches(district_index))))
		if share > best_share or (share == best_share and city_gdp > best_gdp):
			best_district = district_index
			best_share = share
			best_gdp = city_gdp
	return best_district


func _pay_skill_play_cost(player_index: int, skill: Dictionary) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	var requirement := _card_play_requirement_snapshot(player_index, skill)
	var cash_cost := int(requirement.get("cash_cost", 0))
	if cash_cost <= 0:
		return
	players[player_index]["cash"] = max(0, int(players[player_index].get("cash", 0)) - cash_cost)
	var card_label := _card_display_name(String(skill.get("name", "")))
	if card_label == "":
		card_label = "卡牌"
	_record_player_card_spend(player_index, cash_cost, "打出%s" % card_label, String(requirement.get("requirement_text", "条件：无")))


func _signed_int_text(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return "%d" % value


func _player_recent_cash_delta(player: Dictionary) -> int:
	var history: Array = player.get("cash_history", [])
	if history.size() < 2:
		return 0
	return int(history[history.size() - 1]) - int(history[history.size() - 2])


func _player_cash_path_text(player: Dictionary, limit: int = 7) -> String:
	var history: Array = player.get("cash_history", [])
	if history.is_empty():
		return str(int(player.get("cash", 0)))
	var pieces := []
	var start_index: int = maxi(0, history.size() - maxi(2, limit))
	for i in range(start_index, history.size()):
		pieces.append(str(int(history[i])))
	return "→".join(pieces)


func _player_cash_window_delta(player: Dictionary) -> int:
	var history: Array = player.get("cash_history", [])
	if history.size() < 2:
		return 0
	return int(history[history.size() - 1]) - int(history[0])


func _player_economic_ledger_text(player: Dictionary, limit: int = 4) -> String:
	var ledger: Array = player.get("economic_ledger", [])
	if ledger.is_empty():
		return "暂无"
	var pieces := []
	var start_index: int = maxi(0, ledger.size() - maxi(1, limit))
	for i in range(start_index, ledger.size()):
		var entry: Dictionary = ledger[i]
		var detail := String(entry.get("detail", ""))
		var detail_suffix := "｜%s" % detail if detail != "" else ""
		pieces.append("C%d %s%s：%s%s→%d" % [
			int(entry.get("cycle", 0)),
			String(entry.get("kind", "经济")),
			detail_suffix,
			_signed_int_text(int(entry.get("amount", 0))),
			" " + String(entry.get("label", "")) if String(entry.get("label", "")) != "" else "",
			int(entry.get("cash_after", 0)),
		])
	return "；".join(pieces)


func _card_price(skill_name: String, district_index: int = -1, player_index: int = -1) -> int:
	if skill_name.is_empty():
		return 0
	var price_name := "%s1" % _game_runtime_coordinator_node().card_family_id(skill_name)
	if not _game_runtime_coordinator_node().card_exists(price_name):
		price_name = skill_name
	var skill: Dictionary = _game_runtime_coordinator_node().card_definition(price_name)
	var base_price := int(_runtime_balance_model().call("card_price_for_skill", skill))
	if district_index < 0:
		return base_price
	var preview := _card_market_preview(skill_name, district_index)
	return int(preview.get("final_price", base_price))


func _runtime_balance_model() -> RefCounted:
	return RuntimeBalanceModelScript.new()


func _balance_product_price_step_cap(volatility: int, base_price: int = 100) -> int:
	return int(_runtime_balance_model().call("product_price_step_cap", volatility, base_price))


func _balance_product_price_model(base_price: int, supply_score: int, demand_score: int, route_damage_score: int, monster_pressure: int = 0, weather_modifier: int = 0, volatility: int = 4, random_noise: float = 0.0, growth_multiplier: float = 1.0) -> Dictionary:
	return _runtime_balance_model().call("product_price_model", base_price, supply_score, demand_score, route_damage_score, monster_pressure, weather_modifier, volatility, random_noise, growth_multiplier) as Dictionary


func _balance_monster_movement_speed_model(actor: Dictionary, target_index: int = -1, action_speed_mps: float = -1.0) -> Dictionary:
	return _runtime_balance_model().call("monster_movement_speed_model", actor, monster_runtime_controller._monster_terrain_move_multiplier(actor, target_index), action_speed_mps, _current_balance_region_radius_m(), 10.0) as Dictionary


func _current_balance_region_size_model() -> Dictionary:
	var region_count := districts.size()
	if region_count <= 0:
		var depth_range := _balance_region_count_range_for_depth()
		region_count = int(depth_range.get("region_mid", maxi(MAP_REGION_COUNT_MIN, 1)))
	return _runtime_balance_model().call("region_size_model", configured_roguelike_depth, region_count) as Dictionary


func _current_balance_region_radius_m() -> float:
	var model := _current_balance_region_size_model()
	return maxf(1.0, float(model.get("avg_region_radius_m", 180.0)))


func _auto_monster_movement_speed_mps(actor: Dictionary, target_index: int, action_speed_mps: float = -1.0) -> float:
	var model := _balance_monster_movement_speed_model(actor, target_index, action_speed_mps)
	return maxf(1.0, float(model.get("speed_mps", 18.0)))


func _monster_knockback_model(action_or_skill: Dictionary, actor: Dictionary = {}) -> Dictionary:
	return _runtime_balance_model().call("monster_knockback_speed_model", action_or_skill, actor, _current_balance_region_radius_m(), 0.5) as Dictionary


func _balance_region_count_range_for_depth(depth: int = -1) -> Dictionary:
	return _runtime_balance_model().call("region_count_range_for_depth", configured_roguelike_depth if depth < 0 else depth) as Dictionary


func _balance_planet_size_for_depth(depth: int = -1) -> Dictionary:
	return _runtime_balance_model().call("planet_size_for_depth", configured_roguelike_depth if depth < 0 else depth) as Dictionary


func _close_menu() -> void:
	if menu_overlay == null:
		return
	if players.is_empty():
		_open_main_menu()
		return
	menu_overlay.visible = false
	if menu_overlay.has_method("set_body_text"):
		menu_overlay.call("set_body_text", "", false)
	if menu_preview_box != null:
		menu_preview_box.visible = false
	if menu_overlay.has_method("clear_preview"):
		menu_overlay.call("clear_preview")
	if not _runtime_session_finished():
		time_scale = max(1.0, speed_before_menu)
		var runtime_coordinator := _game_runtime_coordinator_node()
		if runtime_coordinator != null and runtime_coordinator.has_method("resume_session"):
			runtime_coordinator.call("resume_session")
	_refresh_ui()


func _start_new_run_from_menu() -> void:
	_open_new_game_setup_menu()


func _open_new_game_setup_menu() -> void:
	_ensure_configured_ai_player_count()
	_show_menu(
		"开局准备",
		"开桌前确认席位、电脑对手、挑战层级、公开角色和起始怪兽牌。起始牌由各席持有，召唤完全自愿，不阻断建城、买牌或经济。",
		not players.is_empty() and not _runtime_session_finished()
	)
	if menu_preview_box != null:
		menu_overlay.call("clear_preview")
		menu_preview_box.visible = true
		_add_new_game_setup_controls(menu_preview_box)


func _add_new_game_setup_controls(parent: Container) -> void:
	_ensure_configured_ai_player_count()
	var page := NewGameSetupPageScene.instantiate() as Control
	if page == null or not page.has_method("set_page"):
		_report_required_ui_scene_missing("NewGameSetupPage", "set_page")
		return
	if page.has_signal("action_requested"):
		page.connect("action_requested", Callable(self, "_on_new_game_setup_action_requested"))
	parent.add_child(page)
	page.call("set_page", _new_game_setup_page_snapshot())


func _new_game_setup_page_snapshot() -> Dictionary:
	var seats := []
	for player_index in range(configured_player_count):
		var role_card := _make_configured_player_role_card(player_index)
		var starter_card := _make_starting_monster_card(player_index)
		var starter_monster_index := _configured_starter_monster_index(player_index)
		var role_selection_label := _configured_role_selection_label(player_index)
		var seat_type := _player_seat_type_for_config_index(player_index)
		var seat_label := "电脑对手" if seat_type == "ai" else "真人/本地"
		seats.append(_new_game_setup_seat_card_snapshot(player_index, seat_label, seat_type, role_card, starter_card, starter_monster_index, role_selection_label))
	return {
		"accent": Color("#38bdf8"),
		"tooltip": "完整场景化开局准备页：流程、参数、席位和开始命令都可在 Godot 编辑器中检查。",
		"summary_chips": _new_game_setup_summary_chip_snapshots(),
		"lobby": _new_game_setup_lobby_snapshot(),
		"options": _new_game_setup_option_board_snapshot(),
		"seat_title": "座位卡｜公开角色 + 起始怪兽牌",
		"seat_columns": clampi(int(floor(_menu_available_content_width() / 520.0)), 1, 2),
		"seat_scroll_height": 360.0,
		"seats": seats,
		"hint": "角色公开；起始怪兽牌由各席持有并可随时自愿召唤。普通牌按来源区日照与怪兽压力报价。",
		"can_return_table": not players.is_empty() and not _runtime_session_finished(),
		"start_disabled": false,
		"start_tooltip": "按当前%d席、AI%d和%s配置开始本局。" % [configured_player_count, configured_ai_player_count, _roguelike_depth_label()],
	}


func _new_game_setup_summary_chip_snapshots() -> Array:
	return [
		{"text": "席位 %d" % configured_player_count, "accent": Color("#bfdbfe"), "fill": Color("#0f172a")},
		{"text": "真人 %d" % _configured_human_player_count(), "accent": Color("#bbf7d0"), "fill": Color("#064e3b")},
		{"text": "电脑对手%d" % configured_ai_player_count, "accent": Color("#d8b4fe"), "fill": Color("#2e1065")},
		{"text": _roguelike_depth_label(), "accent": Color("#fde68a"), "fill": Color("#713f12")},
		{"text": "控%d区 / GDP%d" % [_victory_required_regions(), _victory_required_gdp()], "accent": Color("#fef3c7"), "fill": Color("#422006")},
		{"text": "角色不重复", "accent": Color("#93c5fd"), "fill": Color("#1e3a8a")},
		{"text": "召唤可选", "accent": Color("#fecaca"), "fill": Color("#7f1d1d")},
	]


func _on_new_game_setup_action_requested(action_id: String) -> void:
	if action_id == "setup_recommended":
		_apply_recommended_first_run_setup_from_menu()
	elif action_id == "setup_start":
		_confirm_start_new_run_from_setup()
	elif action_id == "setup_back":
		_open_main_menu()
	elif action_id == "setup_return_table":
		_close_menu()
	elif action_id.begins_with("setup_player_count_"):
		_set_configured_player_count_from_new_game_menu(int(action_id.substr("setup_player_count_".length())))
	elif action_id.begins_with("setup_ai_count_"):
		_set_configured_ai_player_count_from_new_game_menu(int(action_id.substr("setup_ai_count_".length())))
	elif action_id.begins_with("setup_challenge_depth_"):
		_set_configured_roguelike_depth_from_new_game_menu(int(action_id.substr("setup_challenge_depth_".length())))
	elif action_id.begins_with("setup_role_step_"):
		var values := action_id.substr("setup_role_step_".length()).split("_", false, 1)
		if values.size() == 2:
			_cycle_configured_role_for_player_from_new_game_menu(int(values[0]), int(values[1]))
	elif action_id.begins_with("setup_role_random_"):
		_set_configured_role_random_for_player(int(action_id.substr("setup_role_random_".length())))
		_open_new_game_setup_menu()
	elif action_id.begins_with("setup_monster_step_"):
		var values := action_id.substr("setup_monster_step_".length()).split("_", false, 1)
		if values.size() == 2:
			_cycle_configured_starter_monster_for_player_from_new_game_menu(int(values[0]), int(values[1]))


func _apply_recommended_first_run_setup_from_menu() -> void:
	_apply_recommended_first_run_setup()
	_open_new_game_setup_menu()


func _new_game_setup_lobby_snapshot() -> Dictionary:
	return {
		"accent": Color("#38bdf8"),
		"title": "开桌流程",
		"title_tooltip": "从左到右确认；不需要阅读长规则也能开始测试。",
		"tooltip": "开局准备像电子桌游开桌大厅：先确认流程，再调整下方席位卡。",
		"columns": clampi(int(floor(_menu_available_content_width() / 180.0)), 1, 5),
		"chips": [
			{"text": "PVE %d席" % configured_player_count, "accent": Color("#bfdbfe"), "tooltip": "本地真人对电脑对手。"},
			{"text": "AI %d" % configured_ai_player_count, "accent": Color("#d8b4fe"), "tooltip": "电脑对手数量。"},
			{"text": "控%d区 / GDP%d" % [_victory_required_regions(), _victory_required_gdp()], "accent": Color("#fef3c7"), "tooltip": "动态达标并持续10秒后进入120秒公开审计。"},
		],
		"steps": [
			{"title": "1｜席位", "body": "%d席｜真人%d｜AI%d" % [configured_player_count, _configured_human_player_count(), configured_ai_player_count], "accent": Color("#38bdf8"), "tooltip": "用下方席位/电脑按钮调整桌面规模。"},
			{"title": "2｜挑战", "body": "%s｜%s" % [_roguelike_depth_label(), _short_card_text(_roguelike_planet_profile_text(), 30)], "accent": Color("#facc15"), "tooltip": "挑战层级决定星球规模；胜利门槛随当前存续区域实时变化。"},
			{"title": "3｜角色", "body": "公开身份｜同局不重复", "accent": Color("#c084fc"), "tooltip": "角色牌开局公开；AI可随机，但开局时仍保证不重复。"},
			{"title": "4｜怪兽牌", "body": "各席持有｜召唤可选", "accent": Color("#fb7185"), "tooltip": "角色不绑定起始怪兽；起始怪兽牌由玩家持有，可在合法时机自愿打出。"},
			{"title": "5｜开局", "body": "受光牌架 → 发展牌 → 商品项目", "accent": Color("#22c55e"), "tooltip": "开始本局后可直接浏览牌架、购买发展牌、建立商品项目和匿名出牌。"},
		],
		"readiness": [
			{"text": "角色不重复", "accent": Color("#93c5fd"), "fill": Color("#1e3a8a")},
			{"text": "怪兽牌独立", "accent": Color("#fecaca"), "fill": Color("#7f1d1d")},
			{"text": "召唤不阻断经济", "accent": Color("#bbf7d0"), "fill": Color("#14532d")},
			{"text": "AI可随机角色", "accent": Color("#d8b4fe"), "fill": Color("#312e81")},
			{"text": "区域控制审计", "accent": Color("#fef3c7"), "fill": Color("#713f12")},
		],
	}


func _new_game_setup_option_board_snapshot() -> Dictionary:
	var player_entries := []
	for count in range(MIN_PLAYER_COUNT, MAX_PLAYER_COUNT + 1):
		player_entries.append({
			"id": "player_count",
			"value": count,
			"text": "%d席" % count,
			"pressed": count == configured_player_count,
			"tooltip": "%d名玩家席位；至少1名真人，其余可由AI补足。" % count,
		})

	var ai_entries := []
	var max_ai := mini(MAX_AI_PLAYER_COUNT, configured_player_count - 1)
	for count in range(MIN_AI_PLAYER_COUNT, max_ai + 1):
		ai_entries.append({
			"id": "ai_count",
			"value": count,
			"text": "AI%d" % count,
			"pressed": count == configured_ai_player_count,
			"tooltip": "%d个电脑对手；AI内部策略不会显示给玩家。" % count,
		})

	var depth_entries := []
	for depth in range(ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX + 1):
		depth_entries.append({
			"id": "challenge_depth",
			"value": depth,
			"text": _level_text(depth),
			"pressed": depth == configured_roguelike_depth,
			"tooltip": _roguelike_planet_profile_text(depth),
		})
	return {
		"accent": Color("#facc15"),
		"title": "开局参数｜先定桌面规模",
		"title_tooltip": "三个参数决定本局桌面：席位、AI数量、星球挑战。",
		"tooltip": "开局参数板：像桌游开局板一样集中调整席位、电脑对手和挑战层级。",
		"columns": clampi(int(floor(_menu_available_content_width() / 260.0)), 1, 3),
		"cards": [
			{
				"title": "席位",
				"detail": "%d席｜真人%d｜AI%d" % [configured_player_count, _configured_human_player_count(), configured_ai_player_count],
				"accent": Color("#38bdf8"),
				"options": player_entries,
			},
			{
				"title": "电脑对手",
				"detail": "本地PVE｜AI路线隐藏",
				"accent": Color("#c084fc"),
				"options": ai_entries,
			},
			{
				"title": "挑战层级",
				"detail": "%s｜动态控制%d区｜前K区GDP %d/min" % [_roguelike_depth_label(), _victory_required_regions(), _victory_required_gdp()],
				"accent": Color("#facc15"),
				"options": depth_entries,
			},
		],
	}


func _new_game_setup_seat_card_snapshot(player_index: int, seat_label: String, seat_type: String, role_card: Dictionary, starter_card: Dictionary, starter_monster_index: int, role_selection_label: String) -> Dictionary:
	var accent := _player_color(player_index)
	var role_name := String(role_card.get("name", "外星辛迪加"))
	var is_ai_seat := seat_type == "ai"
	var public_starter_text := "随机分配/开局后未知" if is_ai_seat else String(_catalog_entry(starter_monster_index).get("name", String(starter_card.get("monster_name", "怪兽"))))
	var snapshot := {
		"player_index": player_index,
		"seat_type": seat_type,
		"accent": accent,
		"tooltip": "座位卡：公开角色 + 各席持有的起始怪兽牌。",
		"chips": [
			{"text": "P%d" % (player_index + 1), "accent": Color("#f8fafc"), "fill": Color("#0f172a").lerp(accent, 0.28)},
			{"text": seat_label, "accent": Color("#bfdbfe"), "fill": Color("#0f172a")},
			{"text": String(role_card.get("species", "未知外星人")), "accent": Color("#d8b4fe"), "fill": Color("#312e81")},
			{"text": "角色:%s" % _short_card_text(role_name, 14), "accent": Color("#e0f2fe"), "fill": Color("#0c4a6e")},
			{"text": "◆ %s" % _short_card_text(public_starter_text, 14), "accent": Color("#fecaca"), "fill": Color("#7f1d1d")},
		],
		"identity": _new_game_setup_seat_identity_snapshot(player_index, seat_type, role_card, starter_card, starter_monster_index, role_selection_label),
		"passive_text": "角色被动：%s" % _short_card_text(_role_passive_text(role_card), 86),
		"passive_tooltip": _role_passive_text(role_card),
		"role_label": role_selection_label,
		"role_random": _configured_role_index(player_index) == ROLE_RANDOM_INDEX,
		"show_random_role": is_ai_seat,
		"card_faces": [_new_game_setup_role_card_face_snapshot(role_card)],
	}
	if is_ai_seat:
		return snapshot
	snapshot["monster_label"] = public_starter_text
	snapshot["starter_note"] = _starter_monster_setup_summary(starter_card)
	(snapshot["card_faces"] as Array).append(_new_game_setup_starter_card_face_snapshot(starter_card, starter_monster_index))
	return snapshot


func _new_game_setup_role_card_face_snapshot(role_card: Dictionary) -> Dictionary:
	return {
		"name": String(role_card.get("name", "外星辛迪加")),
		"cost": "R",
		"effect": _role_card_face_text(role_card, true),
		"type": _role_card_tag_text(role_card),
		"rank": _short_card_text(String(role_card.get("species", "角色")), 8),
		"card_kind": "player_role",
		"card_stats": "公开身份｜%s" % _short_card_text(_codex_role_route_label(role_card), 18),
		"accent": _role_card_presentation_color(role_card),
		"minimum_width": 142.0,
		"minimum_height": 140.0,
	}


func _new_game_setup_starter_card_face_snapshot(starter_card: Dictionary, starter_monster_index: int) -> Dictionary:
	var starter_name := String(_catalog_entry(starter_monster_index).get("name", String(starter_card.get("name", starter_card.get("monster_name", "怪兽")))))
	return {
		"name": starter_name,
		"cost": "◆",
		"effect": _starter_monster_setup_summary(starter_card),
		"type": "怪兽",
		"rank": _level_text(max(1, _game_runtime_coordinator_node().card_rank(starter_name))),
		"card_kind": "monster_card",
		"card_stats": "不限区｜自愿召唤｜%s" % _short_card_text(_monster_card_region_text(starter_card, true), 16),
		"accent": _card_presentation_color(starter_card),
		"minimum_width": 142.0,
		"minimum_height": 140.0,
	}


func _new_game_setup_seat_identity_snapshot(player_index: int, seat_type: String, role_card: Dictionary, starter_card: Dictionary, starter_monster_index: int, role_selection_label: String) -> Dictionary:
	var accent := _player_color(player_index)
	var role_label := "随机角色" if _configured_role_index(player_index) == ROLE_RANDOM_INDEX else _short_card_text(String(role_card.get("name", role_selection_label)), 12)
	var starter_label := "匿名待公开" if seat_type == "ai" else _short_card_text(String(_catalog_entry(starter_monster_index).get("name", "怪兽")), 12)
	var chips := [
		{"text": "公开角色:%s" % role_label, "accent": Color("#e0f2fe"), "fill": Color("#0c4a6e")},
		{"text": "起始牌:%s" % starter_label, "accent": Color("#fecaca"), "fill": Color("#7f1d1d")},
		{"text": "怪兽归属匿名", "accent": Color("#fde68a"), "fill": Color("#713f12")},
	]
	if seat_type == "ai":
		chips.append({"text": "AI策略隐藏", "accent": Color("#cbd5e1"), "fill": Color("#334155")})
	else:
		chips.append({"text": "本地玩家", "accent": Color("#bbf7d0"), "fill": Color("#14532d")})

	var role_body := "开局公开；%s" % _short_card_text(_codex_role_route_label(role_card), 20)
	if _configured_role_index(player_index) == ROLE_RANDOM_INDEX:
		role_body = "开局随机分配，结果公开且不重复。"
	var privacy_text := "AI路线与出牌思路隐藏；只读公开动作。" if seat_type == "ai" else "现金/手牌只自己看；对手靠线索推理。"
	var starter_body := "自愿召唤后才公开具体怪兽。" if seat_type == "ai" else _short_card_text(_starter_monster_setup_summary(starter_card), 54)
	return {
		"accent": accent,
		"tooltip": "座位公开信息板：只显示公开角色、起始怪兽牌状态和第一步提示；AI内部路线不公开。",
		"columns": 2,
		"chips": chips,
		"cards": [
			{"title": "公开身份", "body": role_body, "accent": Color("#93c5fd"), "tooltip": "角色是公开信息；不会绑定起始怪兽归属。"},
			{"title": "起始怪兽牌", "body": starter_body, "accent": Color("#fb7185"), "tooltip": "该席持有起始怪兽牌；召唤完全自愿，召唤者仍保持匿名。"},
			{"title": "第一步", "body": "选区域 → 看受光牌架 → 建立收入", "accent": Color("#22c55e"), "tooltip": "召唤怪兽不是购牌或经济前置。"},
			{"title": "信息边界", "body": privacy_text, "accent": Color("#c4b5fd"), "tooltip": privacy_text},
		],
	}


func _set_configured_player_count_from_new_game_menu(count: int) -> void:
	_set_configured_player_count(count)
	_open_new_game_setup_menu()


func _set_configured_ai_player_count_from_new_game_menu(count: int) -> void:
	_set_configured_ai_player_count(count)
	_open_new_game_setup_menu()


func _set_configured_roguelike_depth_from_new_game_menu(depth: int) -> void:
	_set_configured_roguelike_depth(depth)
	_open_new_game_setup_menu()


func _cycle_configured_role_for_player_from_new_game_menu(player_index: int, step: int) -> void:
	_cycle_configured_role_for_player(player_index, step)
	_open_new_game_setup_menu()


func _cycle_configured_starter_monster_for_player_from_new_game_menu(player_index: int, step: int) -> void:
	_cycle_configured_starter_monster_for_player(player_index, step)
	_open_new_game_setup_menu()


func _starter_monster_setup_summary(starter_card: Dictionary) -> String:
	var fixed_skill_count := int(starter_card.get("fixed_skill_count", 1))
	var duration_text := _monster_card_duration_text(starter_card, true)
	var region_text := _monster_card_region_text(starter_card, true)
	return "起始牌：%s｜%s｜召唤可选｜固定技%d" % [
		region_text,
		duration_text,
		fixed_skill_count,
	]


func _confirm_start_new_run_from_setup() -> void:
	_log("开始新局：%d席外星辛迪加入局，其中真人/本地%d席，电脑对手%d席；怪兽将通过起始怪兽牌和后续怪兽卡匿名召唤，场上数量没有硬上限。" % [
		configured_player_count,
		_configured_human_player_count(),
		configured_ai_player_count,
	])
	_new_game()
	speed_before_menu = 1.0
	_close_menu()


func _load_run_from_menu() -> void:
	var err := _load_run()
	if err == OK:
		_log("已读取保存局面。")
		_open_main_menu()
	else:
		_log("局面读取失败：%s。" % error_string(err))
		_refresh_ui()


func _load_run(path: String = "") -> int:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("request_run_load"):
		return ERR_UNCONFIGURED
	var result_variant: Variant = coordinator.call("request_run_load", path)
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	var read_error := int(result.get("error_code", ERR_INVALID_DATA))
	if read_error != OK:
		return read_error
	var state_variant: Variant = result.get("payload", {})
	if not (state_variant is Dictionary):
		coordinator.call("complete_run_load", ERR_INVALID_DATA)
		return ERR_INVALID_DATA
	var apply_error := _apply_run_domain_state_compatibility_adapter(state_variant as Dictionary)
	coordinator.call("complete_run_load", apply_error)
	return apply_error


func _refresh_run_save_menu_state() -> void:
	var coordinator := _game_runtime_coordinator_node()
	var has_save := coordinator != null and coordinator.has_method("has_valid_run_save") and bool(coordinator.call("has_valid_run_save", ""))
	if menu_load_run_button != null:
		menu_load_run_button.disabled = not has_save
	if menu_overlay != null and menu_overlay.has_method("set_run_save_summary"):
		menu_overlay.call("set_run_save_summary", _run_save_summary_text())


func _run_save_summary_text(path: String = "") -> String:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("read_run_save"):
		return "存档：运行时存档服务不可用。"
	var result_variant: Variant = coordinator.call("read_run_save", path)
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	var state_variant: Variant = result.get("payload", {})
	var state: Dictionary = state_variant if state_variant is Dictionary else {}
	if not bool(result.get("ok", false)) or state.is_empty():
		if bool(result.get("exists", false)):
			return "存档：存在局面文件，但版本或内容无法读取。请重新保存当前局面。"
		return "存档：暂无已保存局面。保存局面后，可从这里继续。"
	var summary_variant: Variant = coordinator.call("build_run_save_summary", state, {})
	var summary: Dictionary = summary_variant if summary_variant is Dictionary else {}
	return "存档：可读取｜时间%s｜市场刷新%d｜玩家%d｜存活城市%d｜领先 %s" % [
		_format_time(float(summary.get("game_time", 0.0))),
		int(summary.get("business_cycle_count", 0)),
		int(summary.get("player_count", 0)),
		int(summary.get("active_city_total", 0)),
		str(summary.get("leader_text", "暂无")),
	]


func _extract_legacy_city_gdp_derivative_positions() -> Dictionary:
	var legacy_positions := {}
	for district_index in range(districts.size()):
		if not (districts[district_index] is Dictionary):
			continue
		var district := (districts[district_index] as Dictionary).duplicate(true)
		var city_variant: Variant = district.get("city", {})
		if not (city_variant is Dictionary):
			continue
		var city := (city_variant as Dictionary).duplicate(true)
		var positions_variant: Variant = city.get("gdp_derivatives", [])
		if positions_variant is Array and not (positions_variant as Array).is_empty():
			legacy_positions[str(district_index)] = (positions_variant as Array).duplicate(true)
		city.erase("gdp_derivatives")
		district["city"] = city
		districts[district_index] = district
	return legacy_positions


func _apply_run_domain_state_compatibility_adapter(state: Dictionary) -> int:
	var runtime_controller := _card_resolution_controller_node()
	if runtime_controller == null or not runtime_controller.has_method("apply_save_data"):
		_mark_card_resolution_controller_missing("save restore", true)
		return ERR_UNCONFIGURED
	players = (state.get("players", []) as Array).duplicate(true)
	_ensure_player_role_cards()
	districts = (state.get("districts", []) as Array).duplicate(true)
	var legacy_city_gdp_derivative_positions := _extract_legacy_city_gdp_derivative_positions()
	skill_market = (state.get("skill_market", []) as Array).duplicate(true)
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator != null and runtime_coordinator.has_method("apply_product_market_save_data"):
		runtime_coordinator.call("apply_product_market_save_data", {
			"product_market": (state.get("product_market", {}) as Dictionary).duplicate(true),
			"business_cycle_count": int(state.get("business_cycle_count", 0)),
			"market_timer": float(state.get("market_timer", 8.0)),
		})
	log_lines = (state.get("log_lines", []) as Array).duplicate(true)
	movement_trails = (state.get("movement_trails", []) as Array).duplicate(true)
	action_callouts = (state.get("action_callouts", []) as Array).duplicate(true)
	map_event_effects = (state.get("map_event_effects", []) as Array).duplicate(true)
	rng.state = int(state.get("rng_state", rng.state))
	if runtime_coordinator != null and runtime_coordinator.has_method("restore_world_effective_seconds"):
		var migrated_clock_variant: Variant = runtime_coordinator.call("restore_world_effective_seconds", float(state.get("game_time", 0.0)))
		var migrated_clock: Dictionary = migrated_clock_variant if migrated_clock_variant is Dictionary else {}
		game_time = float(migrated_clock.get("world_effective_seconds", 0.0))
	if runtime_coordinator != null and runtime_coordinator.has_method("apply_session_save_data"):
		runtime_coordinator.call("apply_session_save_data", state.get("game_session_runtime", {}) as Dictionary)
		if runtime_coordinator.has_method("world_effective_clock_snapshot"):
			var restored_clock_variant: Variant = runtime_coordinator.call("world_effective_clock_snapshot")
			var restored_clock: Dictionary = restored_clock_variant if restored_clock_variant is Dictionary else {}
			game_time = float(restored_clock.get("world_effective_seconds", game_time))
	var commodity_flow_state_variant: Variant = state.get("commodity_flow_runtime", {})
	if commodity_flow_state_variant is Dictionary and not (commodity_flow_state_variant as Dictionary).is_empty() and runtime_coordinator != null and runtime_coordinator.has_method("apply_commodity_flow_save_data"):
		runtime_coordinator.call("apply_commodity_flow_save_data", (commodity_flow_state_variant as Dictionary).duplicate(true))
	if runtime_coordinator != null and runtime_coordinator.has_method("apply_city_gdp_derivative_save_data"):
		var derivative_state_variant: Variant = state.get("city_gdp_derivative_runtime", {})
		var derivative_state := (derivative_state_variant as Dictionary).duplicate(true) if derivative_state_variant is Dictionary else {}
		runtime_coordinator.call("apply_city_gdp_derivative_save_data", derivative_state, legacy_city_gdp_derivative_positions)
	time_scale = float(state.get("time_scale", 1.0))
	selected_player = clampi(int(state.get("selected_player", 0)), 0, max(0, players.size() - 1))
	inspected_player = clampi(int(state.get("inspected_player", selected_player)), 0, max(0, players.size() - 1))
	selected_district = clampi(int(state.get("selected_district", 0)), 0, max(0, districts.size() - 1))
	selected_market_skill = _canonical_card_supply_name(String(state.get("selected_market_skill", "")))
	previewed_district_card = _canonical_card_supply_name(String(state.get("previewed_district_card", selected_market_skill)))
	pending_discard_purchase = (state.get("pending_discard_purchase", {}) as Dictionary).duplicate(true)
	if runtime_coordinator != null and runtime_coordinator.has_method("restore_district_purchase_legacy_state"):
		runtime_coordinator.call("restore_district_purchase_legacy_state", state.get("district_card_purchase_snapshot", {}) as Dictionary, game_time, pending_discard_purchase)
	selected_guess_player = int(state.get("selected_guess_player", -1))
	selected_trade_product = String(state.get("selected_trade_product", ""))
	selected_map_layer_focus = String(_map_layer_entry(String(state.get("selected_map_layer_focus", "all"))).get("id", "all"))
	if runtime_coordinator != null and runtime_coordinator.has_method("apply_contract_save_data"):
		runtime_coordinator.call("apply_contract_save_data", state)
	if runtime_coordinator != null and runtime_coordinator.has_method("apply_card_resolution_queue_legacy_save_snapshot"):
		runtime_coordinator.call("apply_card_resolution_queue_legacy_save_snapshot", state)
	var controller_state := {
		"card_resolution_timer": maxf(0.0, float(state.get("card_resolution_timer", 0.0))),
		"card_resolution_counter_window_active": bool(state.get("card_resolution_counter_window_active", false)),
		"card_resolution_counter_timer": maxf(0.0, float(state.get("card_resolution_counter_timer", 0.0))),
		"card_resolution_simultaneous_timer": maxf(0.0, float(state.get("card_resolution_simultaneous_timer", 0.0))),
		"card_resolution_auction_timer": maxf(0.0, float(state.get("card_resolution_auction_timer", 0.0))),
		"card_resolution_auction_open": bool(state.get("card_resolution_auction_open", false)),
		"card_resolution_batch_locked": bool(state.get("card_resolution_batch_locked", false)),
		"card_resolution_batch_reference_player": int(state.get("card_resolution_batch_reference_player", -1)),
		"card_group_window_sequence": int(state.get("card_group_window_sequence", 0)),
		"last_card_resolution_player_index": int(state.get("last_card_resolution_player_index", -1)),
	}
	runtime_controller.call("apply_save_data", controller_state)
	resolved_card_history = (state.get("resolved_card_history", []) as Array).duplicate(true)
	selected_card_resolution_id = int(state.get("selected_card_resolution_id", -1))
	opening_guide_dismissed = bool(state.get("opening_guide_dismissed", false))
	opening_guide_economy_seen_players = (state.get("opening_guide_economy_seen_players", {}) as Dictionary).duplicate(true)
	first_run_coach_district_seen_players = (state.get("first_run_coach_district_seen_players", {}) as Dictionary).duplicate(true)
	first_run_coach_supply_seen_players = (state.get("first_run_coach_supply_seen_players", {}) as Dictionary).duplicate(true)
	first_run_coach_public_track_seen_players = (state.get("first_run_coach_public_track_seen_players", {}) as Dictionary).duplicate(true)
	first_run_coach_ai_public_action_seen_players = (state.get("first_run_coach_ai_public_action_seen_players", {}) as Dictionary).duplicate(true)
	first_run_coach_monster_pressure_seen_players = (state.get("first_run_coach_monster_pressure_seen_players", {}) as Dictionary).duplicate(true)
	first_run_coach_route_choice_players = (state.get("first_run_coach_route_choice_players", {}) as Dictionary).duplicate(true)
	first_run_coach_clues_seen_players = (state.get("first_run_coach_clues_seen_players", {}) as Dictionary).duplicate(true)
	configured_player_count = clampi(int(state.get("configured_player_count", DEFAULT_PLAYER_COUNT)), MIN_PLAYER_COUNT, MAX_PLAYER_COUNT)
	configured_ai_player_count = int(state.get("configured_ai_player_count", min(DEFAULT_AI_PLAYER_COUNT, configured_player_count - 1)))
	_ensure_configured_ai_player_count()
	configured_roguelike_depth = clampi(int(state.get("configured_roguelike_depth", DEFAULT_ROGUELIKE_DEPTH)), ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX)
	var saved_role_indices: Variant = state.get("configured_role_indices", [])
	configured_role_indices = (saved_role_indices as Array).duplicate(true) if saved_role_indices is Array else []
	_ensure_configured_role_indices()
	var saved_starter_monster_indices: Variant = state.get("configured_starter_monster_indices", [])
	configured_starter_monster_indices = (saved_starter_monster_indices as Array).duplicate(true) if saved_starter_monster_indices is Array else []
	_ensure_configured_starter_monster_indices()
	_ai_runtime_call("_ensure_player_ai_state")
	if runtime_coordinator != null and runtime_coordinator.has_method("apply_victory_control_save_data"):
		runtime_coordinator.call("apply_victory_control_save_data", state.get("victory_control_runtime", {}) as Dictionary)
	map_width_m = float(state.get("map_width_m", MAP_WIDTH_METERS))
	map_height_m = float(state.get("map_height_m", MAP_HEIGHT_METERS))
	if runtime_coordinator != null and runtime_coordinator.has_method("apply_weather_save_data"):
		runtime_coordinator.call("apply_weather_save_data", {
			"weather_forecast": (state.get("weather_forecast", {}) as Dictionary).duplicate(true),
			"active_weather_zones": (state.get("active_weather_zones", []) as Array).duplicate(true),
			"weather_sequence": int(state.get("weather_sequence", 0)),
		})
	if runtime_coordinator != null and runtime_coordinator.has_method("apply_ai_save_data"):
		var ai_state_variant: Variant = state.get("ai_runtime_state", {})
		var ai_state: Dictionary = (ai_state_variant as Dictionary).duplicate(true) if ai_state_variant is Dictionary else {}
		if ai_state.is_empty():
			ai_state = {
				"ai_card_decision_timer": float(state.get("ai_card_decision_timer", 0.0)),
				"ai_auction_reaction_timer": float(state.get("ai_auction_reaction_timer", 0.0)),
				"ai_intel_decision_timer": float(state.get("ai_intel_decision_timer", 0.0)),
				"ai_card_decision_enabled": true,
			}
		runtime_coordinator.call("apply_ai_save_data", ai_state)
	ui_timer = 0.0
	if runtime_coordinator != null and runtime_coordinator.has_method("apply_monster_save_data"):
		runtime_coordinator.call("apply_monster_save_data", state)
	if runtime_coordinator != null and runtime_coordinator.has_method("apply_military_save_data"):
		runtime_coordinator.call("apply_military_save_data", state)
	pending_target_player_index = int(state.get("pending_target_player_index", -1))
	pending_target_slot_index = int(state.get("pending_target_slot_index", -1))
	pending_target_paused_time = bool(state.get("pending_target_paused_time", false))
	pending_player_target_player_index = int(state.get("pending_player_target_player_index", -1))
	pending_player_target_slot_index = int(state.get("pending_player_target_slot_index", -1))
	speed_before_target_choice = float(state.get("speed_before_target_choice", 1.0))
	if runtime_coordinator != null and runtime_coordinator.has_method("apply_codex_navigation_legacy_save_snapshot"):
		runtime_coordinator.call("apply_codex_navigation_legacy_save_snapshot", state)
	# Supply migration may need shuffled fallback candidates for an old save,
	# but loading must not advance the restored gameplay RNG sequence.
	var restored_rng_state := rng.state
	_normalize_card_supply_state()
	rng.state = restored_rng_state

	if skill_market.is_empty():
		skill_market = _monster_market_skills()
	_product_market_runtime_call("ensure_catalog")
	if selected_market_skill == "" and not skill_market.is_empty():
		var first_market_variant: Variant = skill_market[0]
		selected_market_skill = _canonical_card_supply_name(
			String((first_market_variant as Dictionary).get("name", ""))
			if first_market_variant is Dictionary
			else String(first_market_variant)
		)
	_refresh_route_network()
	if not _card_resolution_active_entry().is_empty():
		_show_card_resolution_overlay(_card_resolution_active_entry(), card_resolution_timer)
	elif not _card_resolution_current_queue().is_empty() and not card_resolution_batch_locked:
		_show_card_batch_lobby_overlay()
	else:
		_hide_card_resolution_overlay()
	_refresh_ui()
	return OK


func _quit_game() -> void:
	get_tree().quit()


func _save_settings(show_log: bool) -> void:
	_ensure_configured_ai_player_count()
	_ensure_configured_roguelike_depth()
	_ensure_configured_role_indices()
	_ensure_configured_starter_monster_indices()
	var config := ConfigFile.new()
	config.set_value("setup", "player_count", configured_player_count)
	config.set_value("setup", "ai_player_count", configured_ai_player_count)
	config.set_value("setup", "roguelike_depth", configured_roguelike_depth)
	config.set_value("setup", "role_indices", configured_role_indices)
	config.set_value("setup", "starter_monster_indices", configured_starter_monster_indices)
	config.set_value("scenario", "teaching_hints_enabled", scenario_teaching_hints_enabled)
	config.set_value("scenario", "auto_pause_prompts_enabled", scenario_auto_pause_prompts_enabled)
	config.set_value("scenario", "font_scale_percent", scenario_font_scale_percent)
	config.set_value("campaign", "animation_intensity", campaign_animation_intensity)
	config.set_value("campaign", "font_scale_label", campaign_font_scale_label)
	config.set_value("campaign", "colorblind_assist_enabled", campaign_colorblind_assist_enabled)
	config.set_value("campaign", "ui_volume", campaign_ui_volume)
	config.set_value("campaign", "bgm_volume", campaign_bgm_volume)
	var err: int = config.save(SETTINGS_PATH)
	if not show_log:
		return
	if err == OK:
		_log("开局设置已保存到本地用户配置。")
	else:
		_log("开局设置保存失败：%s。" % error_string(err))
	_refresh_ui()


func _load_settings() -> void:
	var config := ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK:
		_ensure_configured_ai_player_count()
		_ensure_configured_roguelike_depth()
		_ensure_configured_role_indices()
		_ensure_configured_starter_monster_indices()
		return
	configured_player_count = clampi(int(config.get_value("setup", "player_count", DEFAULT_PLAYER_COUNT)), MIN_PLAYER_COUNT, MAX_PLAYER_COUNT)
	configured_ai_player_count = int(config.get_value("setup", "ai_player_count", min(DEFAULT_AI_PLAYER_COUNT, configured_player_count - 1)))
	_ensure_configured_ai_player_count()
	configured_roguelike_depth = int(config.get_value("setup", "roguelike_depth", DEFAULT_ROGUELIKE_DEPTH))
	_ensure_configured_roguelike_depth()
	var saved_role_indices: Variant = config.get_value("setup", "role_indices", [])
	configured_role_indices = (saved_role_indices as Array).duplicate(true) if saved_role_indices is Array else []
	_ensure_configured_role_indices()
	var saved_starter_monster_indices: Variant = config.get_value("setup", "starter_monster_indices", [])
	configured_starter_monster_indices = (saved_starter_monster_indices as Array).duplicate(true) if saved_starter_monster_indices is Array else []
	_ensure_configured_starter_monster_indices()
	scenario_teaching_hints_enabled = bool(config.get_value("scenario", "teaching_hints_enabled", true))
	scenario_auto_pause_prompts_enabled = bool(config.get_value("scenario", "auto_pause_prompts_enabled", true))
	scenario_font_scale_percent = clampi(int(config.get_value("scenario", "font_scale_percent", 100)), 90, 125)
	campaign_animation_intensity = str(config.get_value("campaign", "animation_intensity", "完整"))
	campaign_font_scale_label = str(config.get_value("campaign", "font_scale_label", "中"))
	campaign_colorblind_assist_enabled = bool(config.get_value("campaign", "colorblind_assist_enabled", false))
	campaign_ui_volume = clampi(int(config.get_value("campaign", "ui_volume", 80)), 0, 100)
	campaign_bgm_volume = clampi(int(config.get_value("campaign", "bgm_volume", 60)), 0, 100)


func _roguelike_depth_label(depth: int = -1) -> String:
	var value := configured_roguelike_depth if depth < 0 else depth
	return "深度%s" % _level_text(clampi(value, ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX))


func _roguelike_planet_profile(depth: int = -1) -> Dictionary:
	var value := clampi(configured_roguelike_depth if depth < 0 else depth, ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX)
	var count_range := _balance_region_count_range_for_depth(value)
	var planet_size := _balance_planet_size_for_depth(value)
	var region_min := int(count_range.get("region_min", 6))
	var region_max := int(count_range.get("region_max", 9))
	return {
		"depth": value,
		"label": _roguelike_depth_label(value),
		"region_min": region_min,
		"region_max": region_max,
		"width": float(planet_size.get("width_m", MAP_WIDTH_METERS)),
		"height": float(planet_size.get("height_m", MAP_HEIGHT_METERS)),
		"victory_rule": _victory_dynamic_rule(),
	}


func _roguelike_planet_profile_text(depth: int = -1) -> String:
	var profile := _roguelike_planet_profile(depth)
	var victory_rule: Dictionary = profile.get("victory_rule", {}) if profile.get("victory_rule", {}) is Dictionary else _victory_dynamic_rule()
	return "%s｜星球%.0fm×%.0fm｜区域%d-%d｜动态控制%d区 / 前K区GDP %d/min" % [
		String(profile.get("label", "深度I")),
		float(profile.get("width", MAP_WIDTH_METERS)),
		float(profile.get("height", MAP_HEIGHT_METERS)),
		int(profile.get("region_min", MAP_REGION_COUNT_MIN)),
		int(profile.get("region_max", MAP_REGION_COUNT_MAX)),
		int(victory_rule.get("required_region_count", 0)),
		int(victory_rule.get("required_top_k_gdp_per_minute", 0)),
	]


func _generate_roguelike_districts() -> void:
	districts = []
	district_lookup = {}
	var profile := _roguelike_planet_profile()
	map_width_m = float(profile.get("width", MAP_WIDTH_METERS))
	map_height_m = float(profile.get("height", MAP_HEIGHT_METERS))
	var target_region_count := rng.randi_range(int(profile.get("region_min", MAP_REGION_COUNT_MIN)), int(profile.get("region_max", MAP_REGION_COUNT_MAX)))
	var sites := _generate_region_sites(target_region_count)

	for i in range(sites.size()):
		var polygon: Array = _voronoi_polygon_for_site(i, sites)
		if polygon.size() < 3:
			continue
		var center: Vector2 = _polygon_centroid(polygon)
		var area_m2: float = max(1.0, abs(_polygon_area(polygon)))
		var district_name: String = String(DISTRICT_NAME_POOL[i]) if i < DISTRICT_NAME_POOL.size() else "第%d区" % (i + 1)
		var district := {
			"region_id": "region.%03d" % i,
			"name": district_name,
			"center": center,
			"polygon": polygon,
			"area_m2": area_m2,
			"radius_m": sqrt(area_m2 / PI),
			"hp": 0,
			"damage": 0,
			"last_damage_source": "",
			"last_damage_amount": 0,
			"last_damage_time": -1.0,
			"destroyed": false,
			"miasma": false,
			"pulse": 0.0,
			"pulse_color": Color("#facc15"),
			"terrain": "land",
			"terrain_label": "陆地",
			"products": [],
			"demands": [],
			"neighbors": [],
			"transport_score": 1.0,
			"city": {},
			"card_choices": [],
			"card_sources": {},
		}
		districts.append(district)
	_assign_district_neighbors()
	_assign_district_terrain_and_goods()


func _generate_region_sites(count: int) -> Array:
	var sites := []
	var attempts := 0
	while sites.size() < count and attempts < count * 80:
		attempts += 1
		var point := Vector2(
			rng.randf_range(MAP_SITE_MARGIN_METERS, map_width_m - MAP_SITE_MARGIN_METERS),
			rng.randf_range(MAP_SITE_MARGIN_METERS, map_height_m - MAP_SITE_MARGIN_METERS)
		)
		var too_close := false
		for existing in sites:
			if point.distance_to(existing) < 130.0:
				too_close = true
				break
		if too_close:
			continue
		sites.append(point)
	while sites.size() < count:
		sites.append(Vector2(
			rng.randf_range(MAP_SITE_MARGIN_METERS, map_width_m - MAP_SITE_MARGIN_METERS),
			rng.randf_range(MAP_SITE_MARGIN_METERS, map_height_m - MAP_SITE_MARGIN_METERS)
		))
	return sites


func _assign_district_neighbors() -> void:
	for i in range(districts.size()):
		var entries := []
		for j in range(districts.size()):
			if i == j:
				continue
			entries.append({"index": j, "distance": _wrapped_distance(_district_center(i), _district_center(j))})
		entries.sort_custom(Callable(self, "_sort_distance_entry"))
		var neighbors := []
		for entry in entries:
			if neighbors.size() >= DISTRICT_NEIGHBOR_COUNT:
				break
			neighbors.append(int(entry["index"]))
		districts[i]["neighbors"] = neighbors
	for i in range(districts.size()):
		var neighbors: Array = districts[i].get("neighbors", [])
		for neighbor_variant in neighbors:
			var neighbor := int(neighbor_variant)
			if neighbor < 0 or neighbor >= districts.size():
				continue
			var reverse: Array = districts[neighbor].get("neighbors", [])
			if not reverse.has(i):
				reverse.append(i)
				districts[neighbor]["neighbors"] = reverse


func _land_economic_focus() -> String:
	var focuses := ["production", "transport", "consumption", "balanced"]
	return String(focuses[rng.randi_range(0, focuses.size() - 1)])


func _district_economy_focus_label(focus: String) -> String:
	match focus:
		"production":
			return "生产区"
		"transport":
			return "交通枢纽"
		"consumption":
			return "消费区"
		"ocean_transport":
			return "海运通道"
	return "均衡区"


func _transport_score_from_level(level: int, is_ocean: bool = false) -> float:
	var base := 1.0 if not is_ocean else 1.25
	return clampf(base + float(clampi(level, REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX) - 1) * 0.18, REGION_TRANSPORT_SCORE_MIN, REGION_TRANSPORT_SCORE_MAX)


func _assign_district_terrain_and_goods() -> void:
	if districts.is_empty():
		return
	var ocean_indices := _roll_ocean_district_indices()
	var ocean_name_offset := rng.randi_range(0, max(0, OCEAN_DISTRICT_NAME_POOL.size() - 1))
	var ocean_name_count := 0
	for i in range(districts.size()):
		var district: Dictionary = districts[i]
		if ocean_indices.has(i):
			var ocean_name := String(OCEAN_DISTRICT_NAME_POOL[(ocean_name_offset + ocean_name_count) % OCEAN_DISTRICT_NAME_POOL.size()])
			ocean_name_count += 1
			district["name"] = ocean_name
			district["terrain"] = "ocean"
			district["terrain_label"] = "海洋"
			district["economic_focus"] = "ocean_transport"
			district["economic_focus_label"] = _district_economy_focus_label("ocean_transport")
			var ocean_products := _random_product_names_for_terrain("ocean", DISTRICT_PRODUCT_COUNT_MIN, DISTRICT_PRODUCT_COUNT_MAX)
			district["products"] = ocean_products
			district["demands"] = _random_product_names(DISTRICT_DEMAND_COUNT_MIN, DISTRICT_DEMAND_COUNT_MAX, ocean_products)
			district["production_level"] = REGION_ECONOMY_LEVEL_MIN
			district["transport_level"] = 4
			district["consumption_level"] = REGION_ECONOMY_LEVEL_MIN
			district["transport_score"] = _transport_score_from_level(int(district["transport_level"]), true)
		else:
			var focus := _land_economic_focus()
			district["terrain"] = "land"
			district["terrain_label"] = "陆地"
			district["economic_focus"] = focus
			district["economic_focus_label"] = _district_economy_focus_label(focus)
			match focus:
				"production":
					district["production_level"] = 3
					district["transport_level"] = 2
					district["consumption_level"] = 1
				"transport":
					district["production_level"] = 1
					district["transport_level"] = 3
					district["consumption_level"] = 2
				"consumption":
					district["production_level"] = 1
					district["transport_level"] = 2
					district["consumption_level"] = 3
				_:
					district["production_level"] = 2
					district["transport_level"] = 2
					district["consumption_level"] = 2
			var products := _random_product_names_for_terrain("land", DISTRICT_PRODUCT_COUNT_MIN, DISTRICT_PRODUCT_COUNT_MAX)
			district["products"] = products
			district["demands"] = _random_product_names(DISTRICT_DEMAND_COUNT_MIN, DISTRICT_DEMAND_COUNT_MAX, products)
			district["transport_score"] = _transport_score_from_level(int(district["transport_level"]), false)
		districts[i] = district
	var economic_districts: Array = []
	for district_index in range(districts.size()):
		var district: Dictionary = districts[district_index]
		economic_districts.append({
			"region_id": str(district.get("region_id", "region.%03d" % district_index)),
			"terrain": str(district.get("terrain", "unknown")),
			"neighbors": (district.get("neighbors", []) as Array).duplicate(),
			"products": (district.get("products", []) as Array).duplicate(),
			"demands": (district.get("demands", []) as Array).duplicate(),
		})
	var viability_result: Dictionary = RoguelikeEconomicViabilityPolicyScript.normalize({
		"districts": economic_districts,
		"catalog_products": _product_catalog_names(),
		"terrain_product_pools": {
			"land": _product_pool_for_terrain("land"),
			"ocean": _product_pool_for_terrain("ocean"),
		},
	})
	_roguelike_economic_viability_dev_audit = (viability_result.get("audit", {}) as Dictionary).duplicate(true)
	_roguelike_economic_viability_dev_audit["ok"] = bool(viability_result.get("ok", false))
	_roguelike_economic_viability_dev_audit["result_reason_code"] = str(viability_result.get("reason_code", "result_missing"))
	if not bool(viability_result.get("ok", false)):
		push_error("Roguelike economic viability policy failed closed: %s" % str(viability_result.get("reason_code", "unknown")))
		return
	if not bool(_roguelike_economic_viability_dev_audit.get("changed", false)):
		return
	var normalized_districts: Array = viability_result.get("districts", []) if viability_result.get("districts", []) is Array else []
	var changed_destination_indices: Array = _roguelike_economic_viability_dev_audit.get("changed_destination_indices", []) if _roguelike_economic_viability_dev_audit.get("changed_destination_indices", []) is Array else []
	if normalized_districts.size() != districts.size() \
		or changed_destination_indices.is_empty() \
		or changed_destination_indices.size() > 1 \
		or changed_destination_indices.size() != int(_roguelike_economic_viability_dev_audit.get("mutation_count", -1)):
		_roguelike_economic_viability_dev_audit["ok"] = false
		_roguelike_economic_viability_dev_audit["result_reason_code"] = "normalized_patch_invalid"
		push_error("Roguelike economic viability policy returned an invalid patch set.")
		return
	var changed_index_set: Dictionary = {}
	for destination_variant: Variant in changed_destination_indices:
		if not (destination_variant is int):
			changed_index_set.clear()
			break
		var destination_index := int(destination_variant)
		if destination_index < 0 or destination_index >= districts.size() or changed_index_set.has(destination_index):
			changed_index_set.clear()
			break
		changed_index_set[destination_index] = true
	var demand_patches: Dictionary = {}
	var normalized_patch_valid := changed_index_set.size() == changed_destination_indices.size()
	for district_index in range(districts.size()):
		if not normalized_patch_valid or not (normalized_districts[district_index] is Dictionary):
			normalized_patch_valid = false
			break
		var before: Dictionary = economic_districts[district_index]
		var normalized: Dictionary = normalized_districts[district_index]
		var normalized_demands: Array = normalized.get("demands", []) if normalized.get("demands", []) is Array else []
		var demand_changed := JSON.stringify(normalized_demands) != JSON.stringify(before.get("demands", []))
		if str(normalized.get("region_id", "")) != str(before.get("region_id", "")) \
			or str(normalized.get("terrain", "")) != str(before.get("terrain", "")) \
			or JSON.stringify(normalized.get("neighbors", [])) != JSON.stringify(before.get("neighbors", [])) \
			or JSON.stringify(normalized.get("products", [])) != JSON.stringify(before.get("products", [])) \
			or normalized_demands.size() != DISTRICT_DEMAND_COUNT_MIN \
			or demand_changed != changed_index_set.has(district_index):
			normalized_patch_valid = false
			break
		if demand_changed:
			demand_patches[district_index] = normalized_demands.duplicate()
	if not normalized_patch_valid or demand_patches.size() != changed_index_set.size():
		_roguelike_economic_viability_dev_audit["ok"] = false
		_roguelike_economic_viability_dev_audit["result_reason_code"] = "normalized_patch_validation_failed"
		push_error("Roguelike economic viability policy patch validation failed closed.")
		return
	# Apply only after the sole optional demand patch validates, so a malformed
	# policy result can never leave a partially rewritten map.
	for destination_variant: Variant in changed_destination_indices:
		var destination_index := int(destination_variant)
		var destination: Dictionary = districts[destination_index]
		destination["demands"] = (demand_patches.get(destination_index, []) as Array).duplicate()
		districts[destination_index] = destination


func _roll_ocean_district_indices() -> Array:
	var result := []
	var count := districts.size()
	if count <= 2:
		return result
	var desired: int = clampi(int(round(float(count) * rng.randf_range(OCEAN_REGION_RATIO_MIN, OCEAN_REGION_RATIO_MAX))), 1, count - 1)
	var seed_count: int = clampi(rng.randi_range(1, 3), 1, desired)
	while result.size() < seed_count:
		var seed_index := rng.randi_range(0, count - 1)
		if not result.has(seed_index):
			result.append(seed_index)
	var guard := 0
	while result.size() < desired and guard < count * 8:
		guard += 1
		var candidates := []
		for index_variant in result:
			var index := int(index_variant)
			for neighbor_variant in districts[index].get("neighbors", []):
				var neighbor := int(neighbor_variant)
				if neighbor >= 0 and neighbor < count and not result.has(neighbor) and not candidates.has(neighbor):
					candidates.append(neighbor)
		if candidates.is_empty():
			for i in range(count):
				if not result.has(i):
					candidates.append(i)
		if candidates.is_empty():
			break
		result.append(int(candidates[rng.randi_range(0, candidates.size() - 1)]))
	return result


func _random_product_names(count_min: int, count_max: int, excluded: Array = []) -> Array:
	return _random_product_names_from_pool(ProductMarketRuntimeController.PRODUCT_CATALOG, count_min, count_max, excluded)


func _random_product_names_for_terrain(terrain: String, count_min: int, count_max: int, excluded: Array = []) -> Array:
	return _random_product_names_from_pool(_product_pool_for_terrain(terrain), count_min, count_max, excluded)


func _product_pool_for_terrain(terrain: String) -> Array:
	if terrain == "ocean":
		return OCEAN_PRODUCT_CATALOG.duplicate()
	var pool := []
	for product_variant in ProductMarketRuntimeController.PRODUCT_CATALOG:
		var product_name := String(product_variant)
		if product_name == "" or OCEAN_PRODUCT_CATALOG.has(product_name):
			continue
		pool.append(product_name)
	return pool


func _product_catalog_names() -> Array:
	return ProductMarketRuntimeController.PRODUCT_CATALOG.duplicate()


func _random_product_names_from_pool(source_pool: Array, count_min: int, count_max: int, excluded: Array = []) -> Array:
	var pool := []
	for product_variant in source_pool:
		var product_name := String(product_variant)
		if product_name == "" or excluded.has(product_name):
			continue
		pool.append(product_name)
	var result := []
	var count: int = min(pool.size(), rng.randi_range(count_min, count_max))
	while result.size() < count and not pool.is_empty():
		var pick := rng.randi_range(0, pool.size() - 1)
		result.append(String(pool[pick]))
		pool.remove_at(pick)
	return result


func _product_market_price_label(product_name: String) -> String:
	if product_name == "":
		return "无商品"
	var entry := _product_market_entry_snapshot(product_name)
	var trend := int(entry.get("trend", 0))
	var trend_text := "持平"
	if trend > 0:
		trend_text = "+%d" % trend
	elif trend < 0:
		trend_text = "%d" % trend
	return "%s ¥%d｜%s｜%s" % [product_name, _product_market_price(product_name), _product_market_tier(product_name), trend_text]


func _product_list_with_prices(names: Array, limit: int = 5) -> String:
	if names.is_empty():
		return "无"
	var pieces := []
	for i in range(min(limit, names.size())):
		pieces.append(_product_market_price_label(String(names[i])))
	if names.size() > limit:
		pieces.append("+%d" % (names.size() - limit))
	return "、".join(pieces)


func _voronoi_polygon_for_site(site_index: int, sites: Array) -> Array:
	var polygon := [
		Vector2(0.0, 0.0),
		Vector2(map_width_m, 0.0),
		Vector2(map_width_m, map_height_m),
		Vector2(0.0, map_height_m),
	]
	var site: Vector2 = sites[site_index]
	for i in range(sites.size()):
		if i == site_index:
			continue
		polygon = _clip_polygon_closer_to_site(polygon, site, sites[i])
		if polygon.size() < 3:
			break
	return polygon


func _clip_polygon_closer_to_site(polygon: Array, site: Vector2, other: Vector2) -> Array:
	var clipped := []
	if polygon.is_empty():
		return clipped
	var normal := other - site
	var midpoint := (site + other) * 0.5
	for i in range(polygon.size()):
		var current: Vector2 = polygon[i]
		var next: Vector2 = polygon[(i + 1) % polygon.size()]
		var current_inside := _is_closer_to_site(current, midpoint, normal)
		var next_inside := _is_closer_to_site(next, midpoint, normal)
		if current_inside and next_inside:
			clipped.append(next)
		elif current_inside and not next_inside:
			clipped.append(_bisector_intersection(current, next, midpoint, normal))
		elif not current_inside and next_inside:
			clipped.append(_bisector_intersection(current, next, midpoint, normal))
			clipped.append(next)
	return clipped


func _is_closer_to_site(point: Vector2, midpoint: Vector2, normal: Vector2) -> bool:
	return (point - midpoint).dot(normal) <= 0.001


func _bisector_intersection(a: Vector2, b: Vector2, midpoint: Vector2, normal: Vector2) -> Vector2:
	var direction := b - a
	var denominator := direction.dot(normal)
	if abs(denominator) <= 0.001:
		return a
	var t := -((a - midpoint).dot(normal)) / denominator
	return a + direction * clamp(t, 0.0, 1.0)


func _polygon_area(polygon: Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var area := 0.0
	for i in range(polygon.size()):
		var current: Vector2 = polygon[i]
		var next: Vector2 = polygon[(i + 1) % polygon.size()]
		area += current.x * next.y - next.x * current.y
	return area * 0.5


func _polygon_centroid(polygon: Array) -> Vector2:
	var signed_area := _polygon_area(polygon)
	if abs(signed_area) <= 0.001:
		var fallback := Vector2.ZERO
		for point in polygon:
			fallback += point as Vector2
		return fallback / max(1.0, float(polygon.size()))
	var cx := 0.0
	var cy := 0.0
	for i in range(polygon.size()):
		var current: Vector2 = polygon[i]
		var next: Vector2 = polygon[(i + 1) % polygon.size()]
		var cross := current.x * next.y - next.x * current.y
		cx += (current.x + next.x) * cross
		cy += (current.y + next.y) * cross
	return Vector2(cx, cy) / (6.0 * signed_area)


func _assign_district_card_choices() -> void:
	skill_market = _current_run_card_pool()
	if skill_market.is_empty():
		for district in districts:
			district["card_choices"] = []
			district["card_sources"] = {}
		return

	var choice_targets := []
	for district in districts:
		district["card_choices"] = []
		district["card_sources"] = {}
		choice_targets.append(rng.randi_range(DISTRICT_CARD_CHOICE_MIN, DISTRICT_CARD_CHOICE_MAX))
	_ensure_fixed_monster_card_supply()

	var featured_cards := _shuffled_card_list(_current_run_featured_cards())
	var featured_sources := _current_run_featured_card_sources()
	var cursor := 0
	for skill_name_variant in featured_cards:
		if districts.is_empty():
			break
		var skill_name := String(skill_name_variant)
		if _is_reserved_district_supply_card(skill_name):
			continue
		var placed := false
		for offset in range(districts.size()):
			var district_index := (cursor + offset) % districts.size()
			if not _district_card_is_valid_for_district(district_index, skill_name):
				continue
			var choices: Array = districts[district_index]["card_choices"]
			if choices.size() >= DISTRICT_CARD_CHOICE_MAX or choices.has(skill_name):
				continue
			choices.append(skill_name)
			districts[district_index]["card_choices"] = choices
			_set_district_card_source(district_index, skill_name, String(featured_sources.get(skill_name, _district_card_supply_source_label(district_index, skill_name))))
			cursor = (district_index + 1) % districts.size()
			placed = true
			break
		if not placed:
			continue

	for i in range(districts.size()):
		var choices: Array = districts[i]["card_choices"]
		var choice_count: int = max(int(choice_targets[i]), choices.size())
		choice_count = min(DISTRICT_CARD_CHOICE_MAX, choice_count)
		var candidate_pool := _district_random_card_candidate_pool(i)
		var attempts := 0
		while choices.size() < choice_count and attempts < max(80, candidate_pool.size() * 2):
			if candidate_pool.is_empty():
				break
			var skill_name := String(candidate_pool[attempts % candidate_pool.size()])
			if not choices.has(skill_name):
				choices.append(skill_name)
				_set_district_card_source(i, skill_name, _district_card_supply_source_label(i, skill_name))
			attempts += 1
		districts[i]["card_choices"] = choices
	_ensure_fixed_monster_card_supply()
	_normalize_reserved_district_supply_slots()


func _normalize_card_supply_state() -> void:
	var normalized_market := []
	_append_unique_cards(normalized_market, skill_market)
	if normalized_market.is_empty():
		normalized_market = _current_run_card_pool()
	skill_market = normalized_market
	for district_index in range(districts.size()):
		var district: Dictionary = districts[district_index]
		district.erase("city_development_guarantee_card")
		var old_choices: Array = district.get("card_choices", [])
		var old_sources: Dictionary = district.get("card_sources", {})
		var choices := []
		var sources := {}
		for old_name_variant in old_choices:
			var old_name := String(old_name_variant)
			var canonical_name := _canonical_card_supply_name(old_name)
			if canonical_name == "" or choices.has(canonical_name) or not _district_card_is_valid_for_district(district_index, canonical_name):
				continue
			choices.append(canonical_name)
			sources[canonical_name] = String(old_sources.get(old_name, old_sources.get(canonical_name, _district_card_supply_source_label(district_index, canonical_name))))
		var candidate_pool := _district_random_card_candidate_pool(district_index)
		for offset in range(candidate_pool.size()):
			if choices.size() >= DISTRICT_CARD_CHOICE_MIN:
				break
			var candidate := String(candidate_pool[(district_index + offset) % candidate_pool.size()])
			if candidate == "" or choices.has(candidate):
				continue
			choices.append(candidate)
			sources[candidate] = _district_card_supply_source_label(district_index, candidate)
		while choices.size() > DISTRICT_CARD_CHOICE_MAX:
			var removed_name := String(choices.pop_back())
			sources.erase(removed_name)
		district["card_choices"] = choices
		district["card_sources"] = sources
		districts[district_index] = district
	_ensure_fixed_monster_card_supply()
	_normalize_reserved_district_supply_slots()


func _is_reserved_district_supply_card(skill_name: String) -> bool:
	var canonical_name := _canonical_card_supply_name(skill_name)
	if canonical_name == "":
		return false
	return _is_monster_card_name(canonical_name)


func _fixed_monster_supply_affinity_score(district_index: int, skill_name: String) -> int:
	var skill := _game_runtime_coordinator_node().card_definition(skill_name)
	if skill.is_empty() or district_index < 0 or district_index >= districts.size():
		return -999999
	var strict_score := _monster_card_district_affinity_score(
		skill,
		district_index,
		_district_local_product_names(district_index),
		String(districts[district_index].get("terrain", "land"))
	)
	if strict_score >= 0:
		return strict_score + 500
	# The fixed slot must exist even when the current planet cannot perfectly
	# match every ecology. Terrain and local products still rank the fallback.
	var score := 10
	var terrain := String(districts[district_index].get("terrain", "land"))
	var summon_access := String(skill.get("summon_access", "monster_zone"))
	if summon_access in ["ocean_monster_zone", "ocean"]:
		score += 90 if terrain == "ocean" else -80
	elif summon_access in ["land_monster_zone", "land"]:
		score += 90 if terrain == "land" else -80
	var monster_index := _monster_catalog_index_by_name(String(skill.get("monster_name", "")))
	if monster_index >= 0:
		var local_products := _district_local_product_names(district_index)
		for product_variant in (_catalog_entry(monster_index).get("resource_focus", []) as Array):
			if local_products.has(String(product_variant)):
				score += 140
	return score


func _best_fixed_monster_supply_card(district_index: int, monster_cards: Array, used_cards: Dictionary, allow_reuse: bool, assignments: Dictionary = {}) -> String:
	var best_name := ""
	var best_score := -999999
	for card_variant in monster_cards:
		var card_name := _canonical_card_supply_name(String(card_variant))
		var occurrence_count := int(used_cards.get(card_name, 0))
		if card_name == "" or (not allow_reuse and occurrence_count > 0):
			continue
		var score := _fixed_monster_supply_affinity_score(district_index, card_name)
		if allow_reuse:
			# Exhaust every family before repeating one, then keep unavoidable
			# repeats evenly distributed instead of collapsing onto one best fit.
			score -= occurrence_count * 2000
			for neighbor_variant in districts[district_index].get("neighbors", []):
				if String(assignments.get(int(neighbor_variant), "")) == card_name:
					score -= 1500
		if score > best_score:
			best_name = card_name
			best_score = score
	return best_name


func _install_fixed_monster_supply_card(district_index: int, skill_name: String, is_unique: bool) -> void:
	if district_index < 0 or district_index >= districts.size() or not _is_monster_card_name(skill_name):
		return
	var district: Dictionary = districts[district_index]
	var choices: Array = district.get("card_choices", [])
	var sources: Dictionary = district.get("card_sources", {})
	for index in range(choices.size() - 1, -1, -1):
		var old_name := _canonical_card_supply_name(String(choices[index]))
		if not _is_monster_card_name(old_name):
			continue
		choices.remove_at(index)
		sources.erase(old_name)
	if choices.size() >= DISTRICT_CARD_CHOICE_MAX:
		var replace_index := _last_non_monster_supply_choice_index(choices)
		if replace_index >= 0:
			var removed_name := String(choices[replace_index])
			choices.remove_at(replace_index)
			sources.erase(removed_name)
	choices.append(skill_name)
	sources[skill_name] = "固定怪兽槽｜%s" % _district_card_supply_source_label(district_index, skill_name)
	district["monster_guarantee_card"] = skill_name
	district["monster_guarantee_unique"] = is_unique
	district["card_choices"] = choices
	district["card_sources"] = sources
	districts[district_index] = district
	_append_unique_cards(skill_market, [skill_name])


func _ensure_fixed_monster_card_supply() -> void:
	if districts.is_empty():
		return
	var monster_cards := _run_allowed_monster_card_names(1)
	if monster_cards.is_empty():
		monster_cards = _monster_card_names(1)
	if monster_cards.is_empty():
		return
	var assignments := {}
	var used_cards := {}
	# Preserve valid saved assignments first, but remove avoidable duplicates.
	for district_index in range(districts.size()):
		var district: Dictionary = districts[district_index]
		var existing_name := _canonical_card_supply_name(String(district.get("monster_guarantee_card", "")))
		if existing_name == "":
			for choice_variant in (district.get("card_choices", []) as Array):
				var choice_name := _canonical_card_supply_name(String(choice_variant))
				if _is_monster_card_name(choice_name):
					existing_name = choice_name
					break
		if existing_name == "" or not monster_cards.has(existing_name):
			continue
		# Repair avoidable duplicates in old saves, but once every family has
		# been used preserve the balanced repeated assignments exactly.
		if int(used_cards.get(existing_name, 0)) > 0 and used_cards.size() < monster_cards.size():
			continue
		assignments[district_index] = existing_name
		used_cards[existing_name] = int(used_cards.get(existing_name, 0)) + 1
	for district_index in range(districts.size()):
		if assignments.has(district_index):
			continue
		var card_name := _best_fixed_monster_supply_card(district_index, monster_cards, used_cards, false, assignments)
		if card_name == "":
			card_name = _best_fixed_monster_supply_card(district_index, monster_cards, used_cards, true, assignments)
		if card_name == "":
			continue
		assignments[district_index] = card_name
		used_cards[card_name] = int(used_cards.get(card_name, 0)) + 1
	var occurrence_counts := {}
	for assigned_variant in assignments.values():
		var assigned_name := String(assigned_variant)
		occurrence_counts[assigned_name] = int(occurrence_counts.get(assigned_name, 0)) + 1
	for district_index_variant in assignments.keys():
		var district_index := int(district_index_variant)
		var card_name := String(assignments[district_index_variant])
		_install_fixed_monster_supply_card(district_index, card_name, int(occurrence_counts.get(card_name, 0)) == 1)


func _normalize_reserved_district_supply_slots() -> void:
	for district_index in range(districts.size()):
		var district: Dictionary = districts[district_index]
		var old_choices: Array = district.get("card_choices", [])
		var old_sources: Dictionary = district.get("card_sources", {})
		var choices := []
		var sources := {}
		var monster_card := _canonical_card_supply_name(String(district.get("monster_guarantee_card", "")))
		if _is_monster_card_name(monster_card):
			choices.append(monster_card)
			sources[monster_card] = String(old_sources.get(monster_card, "固定怪兽槽｜%s" % _district_card_supply_source_label(district_index, monster_card)))
		for old_variant in old_choices:
			var old_name := _canonical_card_supply_name(String(old_variant))
			if old_name == "" or choices.has(old_name) or _is_reserved_district_supply_card(old_name):
				continue
			if not _district_card_is_valid_for_district(district_index, old_name):
				continue
			choices.append(old_name)
			sources[old_name] = String(old_sources.get(old_name, _district_card_supply_source_label(district_index, old_name)))
			if choices.size() >= DISTRICT_CARD_CHOICE_MAX:
				break
		var target_count := clampi(maxi(DISTRICT_CARD_CHOICE_MIN, old_choices.size()), DISTRICT_CARD_CHOICE_MIN, DISTRICT_CARD_CHOICE_MAX)
		for candidate_variant in _district_random_card_candidate_pool(district_index):
			if choices.size() >= target_count:
				break
			var candidate := String(candidate_variant)
			if candidate == "" or choices.has(candidate):
				continue
			choices.append(candidate)
			sources[candidate] = _district_card_supply_source_label(district_index, candidate)
		district["card_choices"] = choices
		district["card_sources"] = sources
		districts[district_index] = district


func _last_non_monster_supply_choice_index(choices: Array) -> int:
	for offset in range(choices.size()):
		var index := choices.size() - 1 - offset
		var skill_name := _canonical_card_supply_name(String(choices[index]))
		if not _is_monster_card_name(skill_name):
			return index
	return -1


func _set_district_card_source(district_index: int, skill_name: String, source: String) -> void:
	if district_index < 0 or district_index >= districts.size() or skill_name == "":
		return
	var sources: Dictionary = districts[district_index].get("card_sources", {})
	sources[skill_name] = source
	districts[district_index]["card_sources"] = sources


func _shuffled_card_list(items: Array) -> Array:
	var pool := items.duplicate()
	var result := []
	while not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		result.append(pool[index])
		pool.remove_at(index)
	return result


func _nearest_district_to(point: Vector2) -> int:
	var best_index := -1
	var best_distance := INF
	point = _wrap_world_position(point)
	for i in range(districts.size()):
		var dist := _wrapped_distance(point, _district_center(i))
		if dist < best_distance:
			best_distance = dist
			best_index = i
	return best_index


func _new_game() -> void:
	var runtime_controller := _card_resolution_controller_node()
	if runtime_controller == null or not runtime_controller.has_method("reset_state"):
		_mark_card_resolution_controller_missing("new game", true)
		return
	runtime_controller.call("reset_state")
	var coordinator := _game_runtime_coordinator_node()
	if coordinator != null and coordinator.has_method("reset_state"):
		coordinator.call("reset_state")
	players = []
	districts = []
	pending_target_player_index = -1
	pending_target_slot_index = -1
	pending_target_paused_time = false
	pending_player_target_player_index = -1
	pending_player_target_slot_index = -1
	card_resolution_timer = 0.0
	card_resolution_counter_window_active = false
	card_resolution_counter_timer = 0.0
	card_resolution_simultaneous_timer = 0.0
	card_resolution_auction_timer = 0.0
	card_resolution_auction_open = false
	card_resolution_batch_locked = false
	card_resolution_batch_reference_player = -1
	card_group_window_sequence = 0
	last_card_resolution_player_index = -1
	card_resolution_visual_id = -1
	card_resolution_visual_stage = -1
	resolved_card_history = []
	selected_card_resolution_id = -1
	opening_guide_dismissed = false
	opening_guide_economy_seen_players = {}
	first_run_coach_district_seen_players = {}
	first_run_coach_supply_seen_players = {}
	first_run_coach_public_track_seen_players = {}
	first_run_coach_ai_public_action_seen_players = {}
	first_run_coach_monster_pressure_seen_players = {}
	first_run_coach_route_choice_players = {}
	first_run_coach_clues_seen_players = {}
	_product_market_runtime_call("reset_state")
	_city_gdp_derivative_runtime_call("reset_state")
	skill_market = _monster_market_skills()
	log_lines = []
	movement_trails = []
	action_callouts = []
	map_event_effects = []
	if coordinator != null and coordinator.has_method("restore_world_effective_seconds"):
		coordinator.call("restore_world_effective_seconds", 0.0)
	game_time = 0.0
	time_scale = 1.0
	selected_player = 0
	inspected_player = 0
	selected_runtime_card_slot = -1
	selected_market_skill = skill_market[0] if not skill_market.is_empty() else ""
	previewed_district_card = selected_market_skill
	pending_discard_purchase = {}
	selected_guess_player = -1
	selected_trade_product = ""
	selected_map_layer_focus = "all"
	if coordinator != null and coordinator.has_method("reset_victory_control_runtime"):
		coordinator.call("reset_victory_control_runtime")
	_prime_timers_for_new_game()

	_ensure_configured_ai_player_count()
	_ensure_configured_roguelike_depth()
	_ensure_configured_role_indices()
	_ensure_configured_starter_monster_indices()
	var configured_human_count := _configured_human_player_count()
	var run_role_indices := _resolve_configured_role_indices_for_run()
	for i in range(configured_player_count):
		var role_card := _make_player_role_card(i, int(run_role_indices[i]) if i < run_role_indices.size() else _player_role_template_index(i))
		var role_starting_cash_delta := _role_starting_cash_delta(role_card)
		var starting_cash := _player_starting_cash_for_role(role_card)
		var is_ai := i >= configured_human_count
		var ai_profile: Dictionary = _ai_runtime_call("_ai_profile_for_config_index", [i]) as Dictionary if is_ai else {}
		var starter_monster_card := _make_starting_monster_card(i)
		if starter_monster_card.is_empty():
			push_error("The v0.6 starter monster card is unavailable for player %d." % i)
			_mark_game_runtime_coordinator_missing(true)
			return
		players.append({
			"id": i,
			"name": "玩家%d" % (i + 1),
			"seat_type": "ai" if is_ai else "human",
			"is_ai": is_ai,
			"ai_profile": ai_profile,
			"ai_memory": _ai_runtime_call("_empty_ai_memory") if is_ai else {},
			"role_index": int(role_card.get("role_index", i)),
			"role_card": role_card,
			"base_starting_cash": STARTING_CASH,
			"role_starting_cash_delta": role_starting_cash_delta,
			"starting_cash_total": starting_cash,
			"cash": starting_cash,
			"cash_cents": starting_cash * 100,
			"cash_history": [starting_cash],
			"v06_transaction_ledger": [],
			"eliminated": false,
			"eliminated_at": -1.0,
			"elimination_reason": "",
			"economic_ledger": [],
			"city_guesses": {},
			"city_guess_confidence": {},
			"city_guess_reasons": {},
			"known_card_owners": {},
			"known_contract_parties": {},
			"cities_built": 0,
			"total_card_spend": 0,
			"card_purchase_count": 0,
			"total_build_spend": 0,
			"total_card_income": 0,
			"total_role_income": 0,
			"total_business_spend": 0,
			"action_cooldown": 0.0,
			"queued_card_tip": 0,
			"slots": [starter_monster_card],
		})
	_ai_runtime_call("_ensure_player_ai_state")

	if _active_runtime_scenario_id() == "first_table" and coordinator != null and coordinator.has_method("first_table_fixture_snapshot"):
		var first_table_fixture_variant: Variant = coordinator.call("first_table_fixture_snapshot")
		var first_table_fixture: Dictionary = first_table_fixture_variant if first_table_fixture_variant is Dictionary else {}
		var authored_map_seed: Variant = first_table_fixture.get("map_seed", -1)
		var authored_map_seed_value := int(authored_map_seed) if authored_map_seed is int or authored_map_seed is float else -1
		if authored_map_seed_value >= 0 and is_equal_approx(float(authored_map_seed), float(authored_map_seed_value)):
			rng.seed = authored_map_seed_value
	_generate_roguelike_districts()
	_initialize_region_infrastructure_runtime()
	if coordinator == null or not coordinator.has_method("refresh_v06_production_player_bindings"):
		_mark_game_runtime_coordinator_missing(true)
		return
	var production_binding_variant: Variant = coordinator.call("refresh_v06_production_player_bindings", self)
	var production_binding: Dictionary = production_binding_variant if production_binding_variant is Dictionary else {}
	if not bool(production_binding.get("ready", false)):
		_mark_game_runtime_coordinator_missing(true)
		return
	game_runtime_coordinator_bound = true
	game_runtime_coordinator_missing = false
	game_runtime_coordinator_missing_reported = false
	_assign_district_card_choices()
	_product_market_runtime_call("refresh_prices")
	var center := Vector2(map_width_m * 0.5, map_height_m * 0.5)
	selected_district = _nearest_district_to(center)
	if selected_district < 0:
		selected_district = 0
	if coordinator != null and coordinator.has_method("weather_runtime_call"):
		coordinator.call("weather_runtime_call", &"schedule_next_forecast", [true])
	district_supply_open_district = -1
	district_supply_open_player = -1
	_sync_selected_district_card()
	_product_market_runtime_call("refresh_prices")
	_start_card_ingress_animation()

	_log("星球牌局开始：%d席玩家，其中真人/本地%d席、电脑对手%d席；本局怪兽由怪兽卡匿名召唤，场上数量没有硬上限。" % [
		configured_player_count,
		_human_player_count(),
		_ai_runtime_call("_ai_player_count"),
	])
	_log("电脑对手已入局：会围绕城市GDP、商品竞争、商路价值、怪兽风险与匿名情报做出行动。")
	_log("星球牌局开始：%s；达到动态区域控制与前K区商品GDP门槛并持续10秒后，进入120秒公开审计。" % _roguelike_planet_profile_text())
	_log("城市化规则启动：玩家在区域秘密建城；建筑公开出现，但对手看不到真实业主，只能保存私人推测。")
	_log("星球随机生成陆地与海洋：陆地和海洋都会出现本地商品；海洋偏向鱼群、巨藻、海底能源和潮汐电力，并继续承担高价值商路运输；合约牌可继续改写供需。")
	_log("每个城市群初始生产1种商品、需求1种商品；后续通过匿名供需合约扩张或替换经营结构。同类商品越多，竞争扣减越高。保护自己的城市，同时借怪兽摧毁竞争城市。")
	_log("本局地图：%.0fm×%.0fm球面投影星球，生成%d个随机陆海区域。" % [map_width_m, map_height_m, districts.size()])
	_log("本局卡池由通用牌与怪兽卡组成；购买花钱，I级牌大多可直接打出，高阶牌检查地区GDP份额。每个区域提供%d-%d张候选卡。" % [DISTRICT_CARD_CHOICE_MIN, DISTRICT_CARD_CHOICE_MAX])
	if coordinator != null and coordinator.has_method("begin_session"):
		var scenario_id := _active_runtime_scenario_id()
		coordinator.call("begin_session", {
			"scenario_id": scenario_id,
			"ruleset_id": "v0.4",
			"seed": rng.state,
			"player_count": players.size(),
			"ai_player_count": _ai_runtime_call("_ai_player_count"),
			"difficulty": _roguelike_depth_label(),
			"mission_title": scenario_id if scenario_id != "" else "自由牌局",
		})
	_save_settings(false)
	_refresh_ui()


func _start_card_ingress_animation() -> void:
	if districts.is_empty():
		return
	var planet_center := Vector2(map_width_m * 0.5, map_height_m * 0.5)
	_add_action_callout(
		"区域补给网",
		"卡池生成",
		"%d个区域各生成%d-%d张候选卡；每个挂牌保留来源区，来源受光时可买，活怪按同区与邻区数量抬高报价。" % [
			districts.size(),
			DISTRICT_CARD_CHOICE_MIN,
			DISTRICT_CARD_CHOICE_MAX,
		],
		Color("#fde68a"),
		planet_center,
		CARD_INGRESS_CALLOUT_DURATION
	)
	_log("区域补给网完成：%d张怪兽牌混入本局区域补给；每个区域生成%d-%d张候选卡。" % [
		_current_run_featured_cards().size(),
		DISTRICT_CARD_CHOICE_MIN,
		DISTRICT_CARD_CHOICE_MAX,
	])


func _owner_damage_cash_total_for_rank(rank: int) -> int:
	return int(_runtime_balance_model().call("owner_damage_cash_total_for_rank", rank))


func _make_skill(skill_name: String) -> Dictionary:
	var base: Dictionary = _game_runtime_coordinator_node().card_definition(skill_name)
	var skill := base.duplicate(true)
	skill["name"] = skill_name
	skill = CardPlayRequirementPolicyScript.apply_to_card(skill_name, skill)
	if String(skill.get("use_case", "")).strip_edges() == "":
		skill["use_case"] = _card_presentation_text(skill, "use_case", skill_name)
	skill["cooldown"] = float(skill.get("cooldown", 0.0))
	skill["cooldown_left"] = 0.0
	skill["lock_left"] = 0.0
	return skill


func _is_v06_runtime_card(card: Dictionary) -> bool:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return not str(machine.get("card_id", "")).is_empty() and not str(machine.get("effect_kind", "")).is_empty()


func _v06_world_card_from_definition(card: Dictionary) -> Dictionary:
	if card.is_empty():
		return {}
	var result := card.duplicate(true)
	var machine: Dictionary = result.get("machine", {}) if result.get("machine", {}) is Dictionary else {}
	var player_text: Dictionary = result.get("player", {}) if result.get("player", {}) is Dictionary else {}
	result["card_id"] = str(machine.get("card_id", ""))
	result["name"] = str(machine.get("card_id", ""))
	result["display_name"] = str(player_text.get("name", result.get("name", "卡牌")))
	result["family_id"] = str(machine.get("family_id", ""))
	result["rank"] = int(machine.get("rank", 1))
	result["kind"] = "monster_card" if str(machine.get("category_id", "")) == "monster" else str(machine.get("category_id", "card_v06"))
	result["counts_toward_hand_limit"] = bool(machine.get("counts_toward_hand_limit", true))
	result["persistent"] = false
	result["queued_for_resolution"] = false
	result["lock_left"] = 0.0
	result["text"] = str(player_text.get("effect", player_text.get("short_effect", "")))
	return result


func _v06_runtime_card_display_name(card: Dictionary) -> String:
	var player_text: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
	var label := str(player_text.get("name", card.get("display_name", ""))).strip_edges()
	return label if not label.is_empty() else str((card.get("machine", {}) as Dictionary).get("card_id", "卡牌"))


func _v06_actor_id(player_index: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return ""
	return str((players[player_index] as Dictionary).get("actor_id", "player.%d" % player_index)).strip_edges()


func _play_v06_runtime_card_for_player(player_index: int, slot_index: int) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var player: Dictionary = players[player_index]
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return false
	var card: Dictionary = slots[slot_index]
	if not _is_v06_runtime_card(card):
		return false
	var actor_id := _v06_actor_id(player_index)
	var region_id := ""
	if selected_district >= 0 and selected_district < districts.size():
		region_id = str((districts[selected_district] as Dictionary).get("region_id", "region.%03d" % selected_district))
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("play_v06_runtime_card"):
		_log("%s尚未接入本局卡牌事务。" % _v06_runtime_card_display_name(card))
		return false
	var authoritative_instance_id := ""
	if coordinator.has_method("v06_card_player_snapshot"):
		var production_player_variant: Variant = coordinator.call("v06_card_player_snapshot", actor_id)
		var production_player: Dictionary = production_player_variant if production_player_variant is Dictionary else {}
		var production_inventory: Dictionary = production_player.get("inventory", {}) if production_player.get("inventory", {}) is Dictionary else {}
		var production_slots: Array = production_inventory.get("slots", []) if production_inventory.get("slots", []) is Array else []
		if slot_index >= 0 and slot_index < production_slots.size() and production_slots[slot_index] is Dictionary:
			authoritative_instance_id = str((production_slots[slot_index] as Dictionary).get("runtime_instance_id", "")).strip_edges()
	var instance_id := authoritative_instance_id if not authoritative_instance_id.is_empty() else str(card.get("runtime_instance_id", "slot:%d" % slot_index))
	var transaction_id := "v06-play:%s:%s" % [actor_id, instance_id]
	var result_variant: Variant = coordinator.call("play_v06_runtime_card", {
		"actor_id": actor_id,
		"slot_index": slot_index,
		"transaction_id": transaction_id,
		"region_id": region_id,
		"game_time": game_time,
	})
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	var feedback: Dictionary = result.get("feedback", {}) if result.get("feedback", {}) is Dictionary else {}
	var label := _v06_runtime_card_display_name(card)
	if bool(result.get("committed", false)):
		_log("%s已通过v0.6卡牌事务完成。" % label)
		_complete_scenario_signal("card_played", "打出卡牌：%s。" % label, "after_play", "public_track")
		return true
	var reason := str(feedback.get("reason", "这张牌当前没有生效。"))
	var next_step := str(feedback.get("next_step", "请检查目标与当前状态后重试。"))
	_log("%s未打出：%s %s" % [label, reason, next_step])
	return false


func _player_role_template_index(player_index: int) -> int:
	if PLAYER_ROLE_CATALOG.is_empty():
		return 0
	return wrapi(player_index, 0, PLAYER_ROLE_CATALOG.size())


func _player_role_catalog_size() -> int:
	return PLAYER_ROLE_CATALOG.size()


func _player_role_template(player_index: int, role_index: int = -1) -> Dictionary:
	if PLAYER_ROLE_CATALOG.is_empty():
		return {}
	var template_index := _player_role_template_index(player_index)
	if role_index >= 0:
		template_index = _clamp_role_index(role_index)
	return (PLAYER_ROLE_CATALOG[template_index] as Dictionary).duplicate(true)


func _role_starting_cash_delta(role_card: Dictionary) -> int:
	# All seats share STARTING_CASH as the general rule; public alien roles may
	# then apply a visible opening-cash modifier. `starting_cash_delta` is kept
	# as the future-proof field for positive or negative role drawbacks, while
	# existing role cards still use `starting_cash_bonus`.
	if role_card.has("starting_cash_delta"):
		return int(role_card.get("starting_cash_delta", 0))
	return int(role_card.get("starting_cash_bonus", 0))


func _player_starting_cash_for_role(role_card: Dictionary) -> int:
	return maxi(1, STARTING_CASH + _role_starting_cash_delta(role_card))


func _strip_role_starter_fields(role: Dictionary) -> Dictionary:
	for key in [
		"starter_monster_index",
		"starter_monster_name",
		"starter_monster_card",
		"starter_hp_bonus",
		"starter_duration_bonus",
		"starter_move_multiplier",
		"starter_fixed_skill_bonus",
	]:
		role.erase(key)
	return role


func _make_player_role_card(player_index: int, role_index: int = -1) -> Dictionary:
	var template_index := _player_role_template_index(player_index)
	if role_index >= 0:
		template_index = _clamp_role_index(role_index)
	var role := _player_role_template(player_index, template_index)
	role["kind"] = "player_role"
	role["role_index"] = template_index
	_strip_role_starter_fields(role)
	role = _game_runtime_coordinator_node().gameplay_balance_diagnostics_service().apply_role_balance_metadata(role)
	role["text"] = "%s｜特征：%s｜被动：%s" % [
		String(role.get("species", "未知外星人")),
		String(role.get("trait", "暂无特征")),
		_role_passive_text(role),
	]
	return role


func _make_configured_player_role_card(player_index: int) -> Dictionary:
	var role_index := _configured_role_index(player_index)
	if role_index == ROLE_RANDOM_INDEX:
		return _random_role_placeholder_card()
	return _make_player_role_card(player_index, role_index)


func _random_role_placeholder_card() -> Dictionary:
	return {
		"name": "随机角色",
		"species": "未揭示外星人",
		"trait": "开局确认时从本局未占用角色中抽取。",
		"passive": "随机获得一个公开角色被动。",
		"flavor": "席位已登记，真正的辛迪加代表将在开局时入场。",
		"kind": "player_role",
		"role_index": ROLE_RANDOM_INDEX,
		"balance_budget": 0,
		"balance_band": "待分配",
		"balance_tags": [],
		"balance_drivers": [],
		"balance_summary": "随机角色｜开局时分配未重复公开角色",
		"text": "随机角色｜开局确认时分配一个未重复公开角色。",
	}


func _normalize_player_role_card(role_card: Dictionary, player_index: int) -> Dictionary:
	var role := role_card.duplicate(true) if not role_card.is_empty() else _make_player_role_card(player_index)
	if not role.has("role_index"):
		role["role_index"] = _player_role_template_index(player_index)
	role["role_index"] = _clamp_role_index(int(role.get("role_index", _player_role_template_index(player_index))))
	var template := _player_role_template(player_index, int(role.get("role_index", _player_role_template_index(player_index))))
	if String(role.get("name", "")) == "":
		role["name"] = String(template.get("name", "外星辛迪加"))
	if String(role.get("species", "")) == "":
		role["species"] = String(template.get("species", "未知外星人"))
	if String(role.get("trait", "")) == "":
		role["trait"] = String(template.get("trait", "起始怪兽牌持有人。"))
	for field_name in _role_runtime_copy_fields():
		if not role.has(field_name) and template.has(field_name):
			role[field_name] = template[field_name]
	role["kind"] = "player_role"
	_strip_role_starter_fields(role)
	role = _game_runtime_coordinator_node().gameplay_balance_diagnostics_service().apply_role_balance_metadata(role)
	return role


func _ensure_player_role_cards() -> void:
	for i in range(players.size()):
		var player: Dictionary = players[i]
		var role_variant: Variant = player.get("role_card", {})
		var role := role_variant as Dictionary if role_variant is Dictionary else {}
		role = _normalize_player_role_card(role, i)
		player["role_card"] = role
		player["role_index"] = int(role.get("role_index", _player_role_template_index(i)))
		players[i] = player
	_ensure_player_private_intel_state()


func _ensure_player_private_intel_state() -> void:
	for i in range(players.size()):
		var player: Dictionary = players[i]
		if not (player.get("known_card_owners", {}) is Dictionary):
			player["known_card_owners"] = {}
		if not (player.get("known_contract_parties", {}) is Dictionary):
			player["known_contract_parties"] = {}
		if not (player.get("city_guesses", {}) is Dictionary):
			player["city_guesses"] = {}
		if not (player.get("city_guess_confidence", {}) is Dictionary):
			player["city_guess_confidence"] = {}
		if not (player.get("city_guess_reasons", {}) is Dictionary):
			player["city_guess_reasons"] = {}
		players[i] = player


func _role_passive_text(role_card: Dictionary) -> String:
	return _realtime_rule_text(String(role_card.get("passive", "暂无被动")))


func _player_role_card_for_index(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= players.size():
		return {}
	var role_variant: Variant = (players[player_index] as Dictionary).get("role_card", {})
	return role_variant as Dictionary if role_variant is Dictionary else {}


func _role_can_use_monster_card_as_counter(player_index: int) -> bool:
	var role := _player_role_card_for_index(player_index)
	return bool(role.get("monster_cards_as_counter", false))


func _role_runtime_copy_fields() -> Array:
	return [
		"passive",
		"starting_cash_delta",
		"starting_cash_bonus",
		"resource_cash_product",
		"resource_cash_amount",
		"bonus_card_product",
		"monster_upgrade_cash",
		"intel_city_reveal_charges",
		"intel_card_trace_charges",
		"intel_contract_trace_charges",
		"city_guess_reward_bonus",
		"card_owner_guess_discount",
		"card_owner_guess_bonus",
		"contract_flow_discount",
		"monster_cards_as_counter",
		"monster_control_limit_bonus",
		"military_control_limit_bonus",
		"flavor",
	]


func _district_or_city_has_product(district_index: int, product_name: String) -> bool:
	if product_name == "" or district_index < 0 or district_index >= districts.size():
		return false
	var district: Dictionary = districts[district_index]
	if (district.get("products", []) as Array).has(product_name):
		return true
	if (district.get("demands", []) as Array).has(product_name):
		return true
	var city := _district_city(district_index)
	if _city_is_active(city):
		if _city_product_names(city).has(product_name) or _city_demand_names(city).has(product_name):
			return true
	return false


func _bonus_card_candidate_for_role(player: Dictionary, district_index: int, bought_skill_name: String) -> String:
	if district_index < 0 or district_index >= districts.size():
		return ""
	var choices := (districts[district_index].get("card_choices", []) as Array).duplicate()
	var fallback := ""
	for choice_variant in choices:
		var candidate := _canonical_card_supply_name(String(choice_variant))
		if candidate == "" or not _game_runtime_coordinator_node().card_exists(candidate):
			continue
		if candidate == bought_skill_name:
			fallback = candidate
			continue
		if _player_can_receive_card(player, candidate):
			return candidate
	if fallback != "" and _player_can_receive_card(player, fallback):
		return fallback
	return ""


func _grant_role_bonus_card_on_purchase(player_index: int, district_index: int, bought_skill_name: String, anonymous: bool = false) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var role := _player_role_card_for_index(player_index)
	var product_name := String(role.get("bonus_card_product", ""))
	if product_name == "" or not _district_or_city_has_product(district_index, product_name):
		return false
	var player: Dictionary = players[player_index]
	var bonus_card := _bonus_card_candidate_for_role(player, district_index, bought_skill_name)
	if bonus_card == "":
		_record_player_economic_event(player_index, "角色收益", "额外拿牌未完成", 0, "%s区域购牌触发%s，但没有可接收的额外候选牌；具体手牌状态不公开。" % [
			product_name,
			String(role.get("name", "角色卡")),
		])
		return false
	if not _acquire_card_for_player(player, bonus_card, district_index, "角色被动:%s" % String(role.get("name", "角色卡")), anonymous):
		return false
	players[player_index] = player
	_record_player_economic_event(player_index, "角色收益", "额外拿牌", 0, "%s区域购牌｜免费获得%s" % [product_name, _card_display_name(bonus_card)])
	_log("一次匿名区域购牌触发%s的额外补给条件；具体买家、卡牌和手牌状态不公开。" % [
		String(role.get("name", "角色卡")),
	])
	return true


func _apply_role_monster_upgrade_cash(player_index: int, monster_name: String, old_rank: int, new_rank: int, world_position: Vector2) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var role := _player_role_card_for_index(player_index)
	var amount := int(role.get("monster_upgrade_cash", 0))
	if amount <= 0:
		return 0
	players[player_index]["cash"] = int(players[player_index].get("cash", 0)) + amount
	players[player_index]["total_card_income"] = int(players[player_index].get("total_card_income", 0)) + amount
	players[player_index]["total_role_income"] = int(players[player_index].get("total_role_income", 0)) + amount
	_record_player_economic_event(player_index, "角色收益", String(role.get("name", "角色卡")), amount, "%s从%s升至%s" % [monster_name, _level_text(old_rank), _level_text(new_rank)])
	_record_player_cash_snapshot(player_index)
	_add_action_callout(
		"角色收益",
		String(role.get("name", "角色卡")),
		"%s升级触发返现：¥+%d。" % [monster_name, amount],
		Color("#fde68a"),
		world_position
	)
	_log("%s触发%s：%s升级，获得¥%d。" % [
		players[player_index]["name"],
		String(role.get("name", "角色卡")),
		monster_name,
		amount,
	])
	return amount


func _make_starting_monster_card(player_index: int, _role_card: Dictionary = {}) -> Dictionary:
	var monster_index := _configured_starter_monster_index(player_index)
	var monster_name := str(_catalog_entry(monster_index).get("name", ""))
	var coordinator := _game_runtime_coordinator_node()
	var definition_variant: Variant = coordinator.call("v06_starter_monster_card_by_name", monster_name) if coordinator != null and coordinator.has_method("v06_starter_monster_card_by_name") else {}
	var definition: Dictionary = definition_variant if definition_variant is Dictionary else {}
	var skill := _v06_world_card_from_definition(definition)
	if skill.is_empty():
		return {}
	var machine: Dictionary = (skill.get("machine", {}) as Dictionary).duplicate(true) if skill.get("machine", {}) is Dictionary else {}
	machine["asset_cost"] = {}
	machine["starter_entitlement"] = true
	skill["machine"] = machine
	skill["starter_play_free"] = true
	skill["summon_access"] = "any"
	skill["text"] = "%s（起始怪兽牌：每席开局持有；召唤完全自愿，不是购牌、设施或经济前置。）" % [
		String(skill.get("text", "")),
	]
	return skill


func _toggle_pause() -> void:
	var coordinator := _game_runtime_coordinator_node()
	if time_scale <= 0.0:
		time_scale = 1.0
		if coordinator != null and coordinator.has_method("resume_session"):
			coordinator.call("resume_session")
	else:
		time_scale = 0.0
		if coordinator != null and coordinator.has_method("pause_session"):
			coordinator.call("pause_session")
	_refresh_ui()


func _refresh_ui() -> void:
	ui_timer = UI_LIVE_REFRESH_SECONDS
	ui_map_refresh_timer = UI_MAP_REFRESH_SECONDS
	ui_full_refresh_timer = UI_FULL_REFRESH_SECONDS
	if menu_overlay != null and menu_overlay.visible:
		_refresh_menu_layout()
	_refresh_board()
	_refresh_map_controls()
	_refresh_district_supply_overlay()
	_refresh_bottom_countdown_bar()
	_sync_runtime_game_screen()


func _refresh_live_ui() -> void:
	if menu_overlay != null and menu_overlay.visible:
		return
	_refresh_bottom_countdown_bar()
	_sync_runtime_game_screen()


func _runtime_table_snapshot_source() -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("compose_game_table_source"):
		return {}
	var value: Variant = coordinator.call("compose_game_table_source", _runtime_table_viewmodel_source())
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _runtime_table_viewmodel_source() -> Dictionary:
	var player_index: int = _runtime_snapshot_player_index()
	var district_snapshot: Dictionary = _runtime_selected_district_snapshot_source(player_index)
	var action_entries: Array = _runtime_snapshot_action_entries(player_index)
	var logs: Array = _runtime_public_log_snapshot()
	var table_source := {
		"campaign_focus_mode": _runtime_campaign_focus_mode(),
		"top_bar": _runtime_top_bar_snapshot_source(player_index),
		"planet": _runtime_planet_snapshot_source(),
		"district": district_snapshot,
		"actions": action_entries,
		"player_board": _runtime_player_board_snapshot_source(player_index, action_entries),
		"first_run_coach": _runtime_first_run_coach_snapshot_source(player_index),
		"scenario_coach": _runtime_scenario_coach_snapshot_source(player_index),
		"temporary_decision": _runtime_temporary_decision_snapshot_source(player_index),
		"visual_events": runtime_visual_events,
		"visual_event_key": runtime_visual_event_key,
		"logs": logs,
	}
	return {
		"table_source": table_source,
		"card_surfaces": _runtime_card_viewmodel_source(player_index, district_snapshot, action_entries, logs),
	}


func _runtime_campaign_focus_mode() -> bool:
	return active_campaign_chapter_id != "" or _active_runtime_scenario_id() != ""


func _runtime_snapshot_player_index() -> int:
	if selected_player >= 0 and selected_player < players.size():
		return selected_player
	if inspected_player >= 0 and inspected_player < players.size():
		return inspected_player
	if not players.is_empty():
		return 0
	return -1


func _runtime_top_bar_snapshot_source(player_index: int) -> Dictionary:
	var progress_gdp := _victory_player_progress_metric(player_index)
	var target_gdp := _victory_required_gdp()
	var table_state := _runtime_top_bar_table_state_text()
	var table_clock := _format_time(game_time) if game_time > 0.0 else "00:00"
	return {
		"table_state": table_state,
		"tempo": table_clock,
		"phase": table_state,
		"turn": table_clock,
		"identity": _player_name(player_index) if _runtime_player_is_valid(player_index) else "未入席",
		"cash_text": _runtime_player_cash_text(player_index),
		"gdp_text": _runtime_player_gdp_text(player_index),
		"goal_text": "Top-N %d/%d" % [progress_gdp, target_gdp],
		"selected_district": _runtime_selected_district_title(),
		"primary_action": _runtime_primary_action_label(player_index),
		"weather_status": weather_runtime_controller.status_text(),
	}


func _runtime_top_bar_table_state_text() -> String:
	if players.is_empty():
		return "主菜单"
	var queue_count := _card_resolution_current_queue().size() + _card_resolution_next_queue().size()
	if card_resolution_auction_open:
		return "竞价中"
	if card_resolution_simultaneous_timer > 0.0:
		return "短窗"
	if card_resolution_counter_window_active:
		return "响应中"
	if not _card_resolution_active_entry().is_empty():
		return "揭示中"
	if queue_count > 0:
		return "牌队%d" % queue_count
	if _victory_control_is_active():
		return "终局"
	if _district_supply_is_open():
		return "牌架"
	return "经营中"


func _runtime_player_board_snapshot_source(player_index: int, action_entries: Array) -> Dictionary:
	var progress_gdp := _victory_player_progress_metric(player_index)
	var target_gdp := _victory_required_gdp()
	var goal_ratio := 0.0
	if target_gdp > 0:
		goal_ratio = clampf(float(progress_gdp) / float(target_gdp), 0.0, 1.0)
	return {
		"title": "玩家板｜手牌",
		"hint": _runtime_player_board_hint(player_index),
		"identity": _player_name(player_index) if _runtime_player_is_valid(player_index) else "未开局",
		"cash_text": _runtime_player_cash_text(player_index),
		"gdp_text": _runtime_player_gdp_text(player_index),
		"goal_text": "Top-N %d/%d" % [progress_gdp, target_gdp],
		"goal_ratio": goal_ratio,
		"selected_district_summary": _runtime_selected_district_summary(player_index),
		"region_infrastructure": _region_infrastructure_snapshot_for_district(selected_district),
		"primary_action": _runtime_primary_action_label(player_index),
		"quick_actions": _runtime_player_board_quick_actions(player_index),
		"table_state_lamps": _runtime_player_board_table_state_lamps(player_index),
		"readiness_chips": _runtime_player_board_readiness_chips(player_index),
		"progress_path": _player_tableau_progress_entries(player_index),
		"bid_board": _runtime_player_board_bid_board(player_index),
		"actions": _runtime_player_board_action_entries(action_entries),
	}


func _forced_decision_candidates() -> Array:
	var candidates: Array = []
	var wager := monster_runtime_controller._latest_active_monster_wager()
	if not wager.is_empty():
		var wager_id := int(wager.get("wager_id", -1))
		candidates.append({
			"id": "monster_wager_%d" % wager_id,
			"kind": TEMP_DECISION_MONSTER_WAGER,
			"priority_group": "monster_wager",
			"owner_player_index": -1,
			"visibility_scope": "public",
			"presentation_surface": "overlay",
			"opened_sequence": float(wager_id),
			"blocks_global_time": true,
			"blocks_player_actions": true,
			"blocks_card_resolution": true,
			"source_ref": "monster_wager",
			"notes": "Public wager freezes the table until every bet or timeout resolves.",
		})
	if card_resolution_counter_window_active and not _card_resolution_active_entry().is_empty():
		var resolution_id := int(_card_resolution_active_entry().get("resolution_id", _card_resolution_active_entry().get("queued_order", -1)))
		candidates.append({
			"id": "counter_response_%d" % resolution_id,
			"kind": "counter_response",
			"priority_group": "counter_response",
			"owner_player_index": -1,
			"visibility_scope": "public",
			"presentation_surface": "card_resolution_track",
			"opened_sequence": float(resolution_id),
			"blocks_global_time": false,
			"blocks_player_actions": false,
			"blocks_card_resolution": false,
			"source_ref": "card_resolution_counter",
			"notes": "The card controller must keep ticking while response cards remain playable.",
		})
	var contract_controller := _contract_runtime_controller_node()
	if contract_controller != null:
		candidates.append_array(contract_controller.forced_decision_candidates())
	if not pending_discard_purchase.is_empty():
		candidates.append({
			"id": "discard_purchase",
			"kind": TEMP_DECISION_DISCARD,
			"priority_group": "other_choice",
			"owner_player_index": int(pending_discard_purchase.get("player_index", -1)),
			"visibility_scope": "private",
			"presentation_surface": "overlay",
			"opened_sequence": float(pending_discard_purchase.get("opened_at", 0.0)),
			"blocks_global_time": false,
			"blocks_player_actions": true,
			"blocks_card_resolution": false,
			"source_ref": "discard_purchase",
			"notes": "Private replacement discard; card identity remains owner-only.",
		})
	if _has_pending_target_choice():
		candidates.append({
			"id": "monster_target_choice",
			"kind": TEMP_DECISION_MONSTER_TARGET,
			"priority_group": "other_choice",
			"owner_player_index": pending_target_player_index,
			"visibility_scope": "private",
			"presentation_surface": "overlay",
			"opened_sequence": float(pending_target_slot_index),
			"blocks_global_time": false,
			"blocks_player_actions": true,
			"blocks_card_resolution": false,
			"source_ref": "monster_target_choice",
			"notes": "Private target selection happens before the card enters the public track.",
		})
	if _has_pending_player_target_choice():
		candidates.append({
			"id": "player_target_choice",
			"kind": TEMP_DECISION_PLAYER_TARGET,
			"priority_group": "other_choice",
			"owner_player_index": pending_player_target_player_index,
			"visibility_scope": "private",
			"presentation_surface": "overlay",
			"opened_sequence": float(pending_player_target_slot_index),
			"blocks_global_time": false,
			"blocks_player_actions": true,
			"blocks_card_resolution": false,
			"source_ref": "player_target_choice",
			"notes": "Private acting-player choice; only the eventual public target is revealed.",
		})
	return candidates


func _sync_forced_decision_runtime() -> void:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("sync_forced_decision_candidates"):
		_mark_game_runtime_coordinator_missing(true)
		return
	coordinator.call("sync_forced_decision_candidates", _forced_decision_candidates())


func _active_forced_decision(player_index: int = -1) -> Dictionary:
	_sync_forced_decision_runtime()
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("active_forced_decision"):
		return {}
	var decision_variant: Variant = coordinator.call("active_forced_decision", player_index)
	return (decision_variant as Dictionary).duplicate(true) if decision_variant is Dictionary else {}


func _runtime_temporary_decision_snapshot_source(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= players.size():
		return {}
	var active := _active_forced_decision(player_index)
	if active.is_empty() or not bool(active.get("visible_to_viewer", false)) or str(active.get("presentation_surface", "")) != "overlay":
		return {}
	match str(active.get("source_ref", "")):
		"monster_wager":
			return _runtime_monster_wager_decision_snapshot_source(player_index)
		"contract_response":
			var contract_controller := _contract_runtime_controller_node()
			return contract_controller.decision_snapshot(player_index) if contract_controller != null else {}
		"discard_purchase":
			return _runtime_discard_purchase_decision_snapshot_source(player_index)
		"monster_target_choice":
			return _runtime_monster_target_decision_snapshot_source(player_index)
		"player_target_choice":
			return _runtime_player_target_decision_snapshot_source(player_index)
	return {}


func _runtime_discard_purchase_decision_snapshot_source(player_index: int) -> Dictionary:
	var pending := _pending_discard_purchase_for_player(player_index)
	if pending.is_empty() or not _can_view_player_private_hand(player_index):
		return {}
	var skill_name := String(pending.get("skill_name", ""))
	var district_index := int(pending.get("district_index", -1))
	var price := int(pending.get("price", _card_price(skill_name, district_index, player_index)))
	var player: Dictionary = players[player_index]
	var actions: Array = []
	for slot_variant in _discardable_hand_slots_for_purchase(player):
		var slot_index := int(slot_variant)
		var skill: Dictionary = player["slots"][slot_index]
		var old_name := String(skill.get("name", "旧牌"))
		actions.append({
			"id": "discard_purchase_%d" % slot_index,
			"label": "弃掉 %s" % _short_card_text(_card_display_name(old_name), 10),
			"tooltip": "私密弃掉这张旧普通牌，然后完成换购。",
		})
	actions.append({
		"id": "discard_purchase_cancel",
		"label": "取消换购",
		"tooltip": "取消本次购牌，不公开弃牌信息。",
	})
	var discard_choice_count := maxi(0, actions.size() - 1)
	return {
		"id": "discard_purchase",
		"kind": TEMP_DECISION_DISCARD,
		"title": "私密弃牌确认",
		"body": "手牌已满。弃1张旧牌，接收%s（约¥%d）。" % [
			_card_display_name(skill_name),
			price,
		],
		"tooltip": "这是购牌窗口锁定后的私密选择，不会进入匿名卡牌轨道。",
		"chips": [
			{"text": "私密", "tooltip": "只有当前玩家可见。", "accent": Color("#bfdbfe")},
			{"text": "不公开", "tooltip": "公开日志不会写手牌或弃牌。", "accent": Color("#facc15")},
			{"text": "换购", "tooltip": "弃旧牌后接收新牌。", "accent": Color("#22c55e")},
		],
		"actions": actions,
		"choice": {
			"mode": "discard",
			"mode_label": "私密换购",
			"card": _card_display_name(skill_name),
			"summary": "手牌已满；从%d张可弃旧普通牌中选1张，再接收新牌。" % discard_choice_count,
			"context": "价格约¥%d｜普通手牌上限%d张" % [price, PLAYER_HAND_LIMIT],
			"privacy": "弃牌选择只在当前玩家私有流水中记录；公开日志不会写手牌或弃掉哪张牌。",
			"public_after": "换购完成后只体现经济结果，不公开弃牌名称。",
			"option_count": discard_choice_count,
		},
		"accent": Color("#facc15"),
	}


func _runtime_monster_target_decision_snapshot_source(player_index: int) -> Dictionary:
	if not _has_pending_target_choice() or pending_target_player_index != player_index or not _can_view_player_private_hand(player_index):
		return {}
	var pending_skill := _pending_target_skill()
	var card_name := _card_display_name(String(pending_skill.get("name", "这张卡")))
	var actions: Array = []
	for i in range(monster_runtime_controller.auto_monsters.size()):
		var actor: Dictionary = monster_runtime_controller.auto_monsters[i]
		var monster_name := String(actor.get("name", "怪兽"))
		actions.append({
			"id": "target_monster_%d" % i,
			"label": "怪%d %s" % [i + 1, _short_card_text(monster_name, 8)],
			"tooltip": "指定%s作为%s的怪兽目标；目标会公开，出牌者仍匿名。" % [monster_name, card_name],
			"disabled": bool(actor.get("down", false)),
		})
	actions.append({
		"id": "target_monster_cancel",
		"label": "取消",
		"tooltip": "取消目标选择，卡牌留在手牌。",
	})
	var available_target_count := 0
	for actor_variant in monster_runtime_controller.auto_monsters:
		if actor_variant is Dictionary and not bool((actor_variant as Dictionary).get("down", false)):
			available_target_count += 1
	return {
		"id": "monster_target_choice",
		"kind": TEMP_DECISION_MONSTER_TARGET,
		"title": "请选择目标怪兽",
		"body": "%s需要先指定目标怪兽；进入公开牌轨后，卡面和目标会向所有人展示。" % card_name,
		"tooltip": "这是入轨道前的私密目标选择。规则书强调：目标与效果公开，出牌者仍匿名，其他玩家需要从线索推理。",
		"chips": [
			{"text": "私密", "tooltip": "只有当前出牌玩家操作。", "accent": Color("#bfdbfe")},
			{"text": "阻塞出牌", "tooltip": "选定目标后才会提交到公开牌轨。", "accent": Color("#fecdd3")},
			{"text": "目标公开", "tooltip": "目标会成为后续推理线索。", "accent": Color("#fda4af")},
		],
		"actions": actions,
		"choice": {
			"mode": "monster_target",
			"mode_label": "怪兽目标",
			"card": card_name,
			"summary": "先选目标怪兽，再把卡牌送入公开牌轨。",
			"context": "可选目标%d/%d只｜倒下目标不可选" % [available_target_count, monster_runtime_controller.auto_monsters.size()],
			"privacy": "选择动作只给当前出牌者；卡牌进入轨道后仍隐藏出牌者。",
			"public_after": "卡面和目标怪兽会公开，成为全场推理线索。",
			"target_count": monster_runtime_controller.auto_monsters.size(),
			"enabled_count": available_target_count,
		},
		"accent": Color("#fb7185"),
	}


func _runtime_player_target_decision_snapshot_source(player_index: int) -> Dictionary:
	if not _has_pending_player_target_choice() or pending_player_target_player_index != player_index or not _can_view_player_private_hand(player_index):
		return {}
	var pending_skill := _pending_player_target_skill()
	var card_name := _card_display_name(String(pending_skill.get("name", "这张卡")))
	var actions: Array = []
	for i in range(players.size()):
		if i == player_index:
			continue
		actions.append({
			"id": "target_player_%d" % i,
			"label": "玩家%d" % (i + 1),
			"tooltip": "把%s作为%s的目标；目标会公开，出牌者仍匿名。" % [_player_name(i), card_name],
		})
	actions.append({
		"id": "target_player_cancel",
		"label": "取消",
		"tooltip": "取消目标玩家选择，卡牌留在手牌。",
	})
	var target_seat_count := maxi(0, players.size() - 1)
	return {
		"id": "player_target_choice",
		"kind": TEMP_DECISION_PLAYER_TARGET,
		"title": "请选择目标玩家",
		"body": "%s会影响一名玩家；结算时目标和影响公开，但出牌者仍保持匿名。" % card_name,
		"tooltip": "直接互动牌先在桌边选目标，再进入公开牌轨；目标玩家、影响类型和时间都会变成推理线索。",
		"chips": [
			{"text": "私密", "tooltip": "只有当前出牌玩家操作。", "accent": Color("#bfdbfe")},
			{"text": "直接互动", "tooltip": "目标玩家会成为公开线索。", "accent": Color("#93c5fd")},
			{"text": "匿名入轨", "tooltip": "卡牌提交后仍隐藏出牌者。", "accent": Color("#60a5fa")},
		],
		"actions": actions,
		"choice": {
			"mode": "player_target",
			"mode_label": "玩家目标",
			"card": card_name,
			"summary": "选择一名其他席位作为直接互动目标。",
			"context": "可选目标%d名｜不能选择自己" % target_seat_count,
			"privacy": "选择动作只给当前出牌者；卡牌提交后仍隐藏出牌者。",
			"public_after": "目标玩家和影响会公开，成为后续收益变化的线索。",
			"target_count": target_seat_count,
		},
		"accent": Color("#60a5fa"),
	}


func _runtime_monster_wager_decision_snapshot_source(player_index: int) -> Dictionary:
	if monster_runtime_controller.active_monster_wagers.is_empty() or player_index < 0 or player_index >= players.size():
		return {}
	var entry := monster_runtime_controller._latest_active_monster_wager()
	if entry.is_empty():
		return {}
	var wager_id := int(entry.get("wager_id", -1))
	var decision := monster_runtime_controller._monster_wager_player_decision(entry, player_index)
	var base_percent := monster_runtime_controller._monster_wager_base_percent(entry)
	var actions: Array = []
	for competitor_variant in monster_runtime_controller._monster_wager_competitors(entry):
		if not (competitor_variant is Dictionary):
			continue
		var competitor := competitor_variant as Dictionary
		var side := String(competitor.get("side", ""))
		if side == "":
			continue
		var label := monster_runtime_controller._monster_wager_side_label(entry, side)
		for percent_variant in monster_runtime_controller._monster_wager_percent_options(entry):
			var percent := int(percent_variant)
			var stake := monster_runtime_controller._monster_wager_amount_for_percent(player_index, percent)
			var raise_text := "底注" if percent == base_percent else "+%d%%" % (percent - base_percent)
			actions.append({
				"id": "monster_wager:%d:%s:%d" % [wager_id, side, percent],
				"label": "押%s %d%%" % [_short_card_text(label, 7), percent],
				"tooltip": "%s：以%s身份公开下注%d%%（约¥%d）支持%s；身份、方向、百分比和金额都会公开。" % [raise_text, _player_name(player_index), percent, stake, label],
				"disabled": decision != "",
			})
	var side_hint := "你尚未下注；本局底注%d%%，可加码；全员决定后提前开战结算。" % base_percent
	if decision != "":
		var bet := monster_runtime_controller._monster_wager_player_bet(entry, player_index)
		side_hint = "你已公开下注%d%%支持%s；本轮决定已锁定。" % [monster_runtime_controller._monster_wager_bet_percent(bet), monster_runtime_controller._monster_wager_side_label(entry, decision)]
	var timer := maxf(0.0, float(entry.get("remaining_seconds", entry.get("seconds_total", _ruleset_timing_seconds(&"monster_wager_default_seconds")))))
	var matchup_text := monster_runtime_controller._monster_wager_matchup_text(entry)
	var damage_text := monster_runtime_controller._monster_wager_damage_score_text(entry)
	var public_decision_summary := monster_runtime_controller._monster_wager_public_decision_summary(entry)
	var context_text := String(entry.get("context", "怪兽遭遇"))
	var pool_total := monster_runtime_controller._monster_wager_total_stake(entry)
	var decision_count := monster_runtime_controller._monster_wager_decision_count(entry)
	return {
		"id": "monster_wager_%d" % wager_id,
		"kind": TEMP_DECISION_MONSTER_WAGER,
		"title": "怪兽赌局 #%d" % wager_id,
		"body": "%s｜伤害%s。全场冻结，底注%d%%；下注身份、方向、百分比和金额公开。%s" % [
			matchup_text,
			damage_text,
			base_percent,
			side_hint,
		],
		"tooltip": "怪兽遭遇触发公开百分比下注。公开决定：%s。触发：%s。" % [
			public_decision_summary,
			context_text,
		],
		"chips": [
			{"text": "全场冻结", "tooltip": "下注结束前暂停常规出牌。", "accent": Color("#fb7185")},
			{"text": "底注%d%%" % base_percent, "tooltip": "底注按当前现金百分比计算。", "accent": Color("#fb923c")},
			{"text": "已押 %d/%d" % [decision_count, players.size()], "tooltip": "全员下注后提前结算。", "accent": Color("#c4b5fd")},
			{"text": "奖池¥%d" % pool_total, "tooltip": "押中最高伤害方的玩家平分奖池。", "accent": Color("#fde68a")},
			{"text": "%.0fs" % timer, "tooltip": "剩余下注时间。", "accent": Color("#fed7aa")},
		],
		"actions": actions,
		"wager": {
			"matchup": matchup_text,
			"damage": damage_text,
			"public_decisions": public_decision_summary,
			"context": context_text,
			"base_percent": base_percent,
			"pool": pool_total,
			"decided": decision_count,
			"seat_count": players.size(),
			"timer": timer,
			"timer_text": "%.0fs" % timer,
			"side_hint": side_hint,
		},
		"accent": Color("#fb923c"),
	}


func _runtime_player_board_action_entries(action_entries: Array) -> Array:
	var compact: Array = []
	for action_variant in action_entries:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		compact.append(action)
		break
	return compact


func _runtime_player_board_quick_actions(player_index: int) -> Array:
	var selected_ok := selected_district >= 0 and selected_district < districts.size()
	var choices_count := 0
	var can_buy := false
	if selected_ok:
		var district: Dictionary = districts[selected_district]
		var choices_variant: Variant = district.get("card_choices", [])
		var choices: Array = choices_variant if choices_variant is Array else []
		choices_count = choices.size()
		can_buy = _district_market_currently_purchasable(selected_district) and choices_count > 0
	var rack_active := selected_ok and choices_count > 0
	var play_slot := _first_actionable_hand_slot(player_index)
	return [
		_runtime_quick_action_snapshot(
			"rack",
			"发展牌架",
			rack_active,
			"%d张" % choices_count if rack_active else ("空" if selected_ok else "未选"),
			"当前选区有 %d 张市场牌；城市发展必须从真实发展牌进入。" % choices_count if rack_active else "先选择有牌架的区域。"
		),
		_runtime_quick_action_snapshot(
			"buy",
			"买牌",
			can_buy,
			"ready" if can_buy else ("browse" if rack_active else "locked"),
			"来源区域受光，当前可购买。" if can_buy else "牌架可浏览；等待来源区域进入日照半球。"
		),
		_runtime_quick_action_snapshot(
			"play",
			"出牌",
			play_slot >= 0,
			"ready" if play_slot >= 0 else "waiting",
			"第 %d 张手牌可打出。" % (play_slot + 1) if play_slot >= 0 else "当前没有可直接打出的手牌。"
		),
	]


func _runtime_quick_action_snapshot(action_id: String, label: String, active: bool, state: String, tooltip: String) -> Dictionary:
	return {
		"id": action_id,
		"label": label,
		"active": active,
		"state": state,
		"tooltip": tooltip,
	}


func _runtime_player_board_table_state_lamps(_player_index: int) -> Array:
	var queue_count := _card_resolution_current_queue().size() + _card_resolution_next_queue().size()
	var table_state := "空闲"
	var table_active := false
	var table_accent := Color("#93c5fd")
	if card_resolution_auction_open:
		table_state = "竞价%d" % queue_count
		table_active = true
		table_accent = Color("#f59e0b")
	elif not _card_resolution_active_entry().is_empty():
		table_state = "揭示"
		table_active = true
		table_accent = Color("#c084fc")
	elif queue_count > 0:
		table_state = "队列%d" % queue_count
		table_active = true
		table_accent = Color("#f59e0b")
	elif _victory_control_timer_visible():
		table_state = "审计"
		table_active = true
		table_accent = Color("#fb923c")
	var selected_ok := selected_district >= 0 and selected_district < districts.size()
	var rack_state := "关闭"
	var rack_active := false
	if _district_supply_is_open():
		rack_state = "打开"
		rack_active = true
	elif selected_ok:
		var choices := _selected_district_card_choices()
		rack_state = "%d张" % choices.size()
		rack_active = not choices.is_empty()
	return [
		{"label": "桌态", "state": table_state, "active": table_active, "accent": table_accent, "tooltip": "公共牌轨和牌桌节奏。"},
		{"label": "选区", "state": _short_card_text(_runtime_selected_district_title(), 9) if selected_ok else "未选", "active": selected_ok, "accent": Color("#38bdf8"), "tooltip": "当前选中的星球区域。"},
		{"label": "牌架", "state": rack_state, "active": rack_active, "accent": Color("#facc15") if rack_active else Color("#94a3b8"), "tooltip": "当前选区的市场牌架状态。"},
	]


func _runtime_player_board_readiness_chips(player_index: int) -> Array:
	if not _runtime_player_is_valid(player_index):
		return [{"label": "本席", "state": "未开局", "active": false, "accent": Color("#94a3b8"), "tooltip": "开新一桌后才能使用牌桌行动。"}]
	var selected_ok := selected_district >= 0 and selected_district < districts.size()
	var hand_count := _player_counted_hand_size(players[player_index] as Dictionary)
	var can_buy := selected_ok and _district_market_currently_purchasable(selected_district)
	var playable_slot := _first_actionable_hand_slot(player_index)
	var chips := [
		{"label": "选区", "state": "就绪" if selected_ok else "未选", "active": selected_ok, "accent": Color("#38bdf8"), "tooltip": "建城、看牌架或买牌前先选区域。"},
		{"label": "手牌", "state": "%d/%d" % [hand_count, PLAYER_HAND_LIMIT], "active": hand_count > 0, "accent": Color("#c084fc"), "tooltip": "当前私密手牌数量。"},
		{"label": "买牌", "state": "就绪" if can_buy else "--", "active": can_buy, "accent": Color("#22c55e") if can_buy else Color("#94a3b8"), "tooltip": "当前选区牌架是否可购买。"},
		{"label": "出牌", "state": "就绪" if playable_slot >= 0 else "--", "active": playable_slot >= 0, "accent": Color("#c084fc") if playable_slot >= 0 else Color("#64748b"), "tooltip": "当前是否有可打出的手牌。"},
	]
	return chips


func _runtime_player_board_bid_board(player_index: int) -> Dictionary:
	if not _runtime_player_is_valid(player_index):
		return {
			"title": "卡牌组竞价",
			"phase": "未开局",
			"status": "开新一桌后才能报价。",
			"active": false,
			"accent": Color("#94a3b8"),
			"chips": [],
			"track_links": [],
			"actions": _runtime_bid_board_actions(player_index, true),
		}
	var active_bid := _selected_card_priority_bid_amount(player_index)
	var queued_index := _queued_card_entry_index_for_player(player_index)
	var next_count := _card_resolution_next_queue().size()
	var status_text := _card_bid_control_status_text(player_index)
	var phase := "预设"
	var accent := Color("#fde68a")
	var active := active_bid > 0
	var window_phase := _card_group_window_phase()
	if ["planning", "public_bid", "lock"].has(window_phase) and not _card_resolution_current_queue().is_empty():
		phase = "%s %ds" % [_card_group_phase_label(window_phase), int(ceil(_card_group_phase_remaining_seconds()))]
		accent = Color("#f59e0b") if window_phase == "public_bid" else (Color("#fb7185") if window_phase == "lock" else Color("#facc15"))
		active = true
	elif card_resolution_batch_locked or not _card_resolution_active_entry().is_empty():
		phase = "封盘"
		accent = Color("#94a3b8")
		active = not _card_resolution_current_queue().is_empty()
	elif next_count > 0:
		phase = "下批等待"
		accent = Color("#38bdf8")
		active = true
	var chips := [
		{"label": "我的组", "state": "%d/%d" % [_card_group_count_for_player(player_index), _card_group_limit_for_player(player_index)], "active": queued_index >= 0, "accent": Color("#c084fc"), "tooltip": status_text, "max_chars": 9},
		{"label": "组报价", "state": "¥%d" % active_bid, "active": active_bid > 0 or queued_index >= 0, "accent": Color("#fde68a"), "tooltip": status_text, "max_chars": 9},
		{"label": "最高", "state": "¥%d" % _highest_card_resolution_bid(), "active": _card_group_bidding_open(), "accent": Color("#f59e0b"), "tooltip": "当前共享窗最高优先报价；同价按轮转顺时针参考席位。", "max_chars": 9},
		{"label": "怪兽池", "state": "¥%d" % monster_runtime_controller.public_card_bid_monster_wager_pool, "active": monster_runtime_controller.public_card_bid_monster_wager_pool > 0, "accent": Color("#fb7185"), "tooltip": "每个组的优先报价都会累积到下一场有效怪兽赌局。", "max_chars": 10},
	]
	return {
		"title": "卡牌组竞价",
		"phase": phase,
		"phase_tooltip": _card_resolution_status_text(),
		"status": _runtime_bid_board_status_line(status_text),
		"status_tooltip": status_text,
		"active": active,
		"accent": accent,
		"chips": chips,
		"track_links": _runtime_bid_board_track_links(player_index),
		"actions": _runtime_bid_board_actions(player_index, false),
	}


func _runtime_bid_board_track_links(player_index: int) -> Array:
	var links: Array = []
	if not _card_resolution_active_entry().is_empty():
		links.append(_runtime_bid_board_track_link("展示", _card_resolution_active_entry(), "当前展示", true))
	var queued_index := _queued_card_entry_index_for_player(player_index)
	if _card_group_bidding_open() and not _card_resolution_current_queue().is_empty():
		var leading_index := _card_resolution_leading_queue_index()
		for i in range(_card_resolution_current_queue().size()):
			var queued_entry: Dictionary = _card_resolution_current_queue()[i]
			var group_position := maxi(1, int(queued_entry.get("group_position", i + 1)))
			var group_order := maxi(1, int(queued_entry.get("group_order", 1)))
			var label := "组%d·%d" % [group_position, group_order]
			if i == leading_index:
				label = "领跑"
			elif i == queued_index:
				label = "我的牌"
			links.append(_runtime_bid_board_track_link(label, queued_entry, "竞拍组%d" % group_position, true))
	elif (card_resolution_batch_locked or not _card_resolution_active_entry().is_empty()) and not _card_resolution_current_queue().is_empty():
		for i in range(_card_resolution_current_queue().size()):
			var locked_entry: Dictionary = _card_resolution_current_queue()[i]
			links.append(_runtime_bid_board_track_link("本批%d" % (i + 1), locked_entry, "锁定%d" % (i + 1), i == 0))
	elif not _card_resolution_current_queue().is_empty():
		for i in range(_card_resolution_current_queue().size()):
			var waiting_entry: Dictionary = _card_resolution_current_queue()[i]
			links.append(_runtime_bid_board_track_link("本批%d" % (i + 1), waiting_entry, "待定%d" % (i + 1), i == 0))
	if links.size() < 3 and not _card_resolution_next_queue().is_empty():
		links.append(_runtime_bid_board_track_link("下批", _card_resolution_next_queue()[0] as Dictionary, "下批等待1", true))
	if links.is_empty() and _active_runtime_scenario_id() == "bid_practice":
		links.append(_runtime_scenario_bid_board_demo_track_link())
	return links


func _runtime_scenario_bid_board_demo_track_link() -> Dictionary:
	var resolution_id := _runtime_scenario_demo_resolution_id()
	var selected := selected_card_resolution_id == resolution_id
	return {
		"id": "track_select_%d" % resolution_id,
			"label": "教学牌",
		"state": "竞拍1 ¥40",
		"active": true,
		"selected": selected,
		"accent": Color("#f59e0b"),
		"tooltip": "对应顶部牌轨的教学牌；金额公开，来源靠线索判断。",
		"max_chars": 13,
	}


func _runtime_bid_board_track_link(label: String, entry: Dictionary, state_text: String, active: bool) -> Dictionary:
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	var selected := resolution_id >= 0 and resolution_id == selected_card_resolution_id
	var bid := int(float(int(entry.get("winning_priority_bid_cents", entry.get("priority_bid_cents", 0)))) / 100.0)
	var card_label := _short_card_text(_card_resolution_entry_card_label(entry), 7)
	var state := state_text
	if bid > 0:
		state = "%s ¥%d" % [state_text, bid]
	elif card_label != "":
		state = "%s %s" % [state_text, card_label]
	return {
		"id": "track_select_%d" % resolution_id if resolution_id >= 0 else "",
		"label": label,
		"state": state,
		"active": active or selected,
		"selected": selected,
		"accent": _card_presentation_color(_queued_skill_from_entry(entry)),
		"tooltip": "对应顶部公开牌轨：%s｜%s｜%s。单击这里或顶部牌槽可选中竞猜/详情。" % [label, state_text, card_label],
		"max_chars": 13,
	}


func _runtime_bid_board_status_line(status_text: String) -> String:
	var text := status_text.replace("报价状态：", "").strip_edges()
	var first_break := text.find("｜")
	if first_break >= 0:
		var second_break := text.find("｜", first_break + 1)
		if second_break >= 0:
			return text.substr(0, second_break)
	return text


func _runtime_bid_board_actions(player_index: int, force_disabled: bool) -> Array:
	var actions: Array = []
	var active_bid := _selected_card_priority_bid_amount(player_index)
	for target_variant in [0, 50, 100]:
		var target_bid := int(target_variant)
		actions.append({
			"id": "bid_set_%d" % target_bid,
			"label": "¥%d" % target_bid,
			"disabled": force_disabled or target_bid == active_bid or not _runtime_bid_board_can_set_tip(player_index, target_bid),
			"active": target_bid == active_bid,
			"accent": Color("#22c55e") if target_bid == 100 else (Color("#f59e0b") if target_bid == 50 else Color("#94a3b8")),
			"tooltip": _card_bid_button_tooltip(player_index, target_bid),
		})
	var window_phase := _card_group_window_phase()
	if _queued_card_entry_index_for_player(player_index) >= 0 and ["planning", "public_bid", "lock"].has(window_phase):
		var ready_label := "完成规划" if window_phase == "planning" else ("完成竞价" if window_phase == "public_bid" else "确认锁牌")
		var ready_tooltip := "本阶段准备后进入公开竞价；不会跳过竞价阶段。" if window_phase == "planning" else ("本阶段准备后进入锁牌；不会立即结算。" if window_phase == "public_bid" else "本阶段准备后封盘并开始结算。")
		actions.append({
			"id": "card_group_ready",
			"label": ready_label,
			"disabled": force_disabled,
			"accent": Color("#38bdf8"),
			"tooltip": ready_tooltip,
		})
	return actions


func _runtime_bid_board_can_set_tip(player_index: int, target_tip: int) -> bool:
	if _runtime_session_finished() or not _runtime_player_is_valid(player_index):
		return false
	var clamped := maxi(0, target_tip)
	if not [0, 50, 100].has(clamped):
		return false
	var queued_index := _queued_card_entry_index_for_player(player_index)
	if queued_index >= 0:
		if not _card_group_bidding_open():
			return false
		var queued_entry: Dictionary = _card_resolution_current_queue()[queued_index]
		var old_bid := int(float(int(queued_entry.get("priority_bid_cents", 0))) / 100.0)
		if clamped <= old_bid:
			return false
		return int((players[player_index] as Dictionary).get("cash", 0)) >= clamped - old_bid
	if _next_batch_card_entry_index_for_player(player_index) >= 0:
		return false
	return int((players[player_index] as Dictionary).get("cash", 0)) >= clamped


func _card_presentation_source(card_name: String, supplied_skill: Dictionary = {}, player_index: int = -1, district_index: int = -1) -> Dictionary:
	var skill := supplied_skill.duplicate(true)
	if skill.is_empty() and card_name != "":
		skill = _game_runtime_coordinator_node().card_definition(card_name)
	if skill.is_empty():
		return {}
	var kind := String(skill.get("kind", ""))
	var requirement := _card_play_requirement_snapshot(player_index, skill, {"selected_district": district_index})
	var target := _card_play_target_snapshot(skill)
	return {
		"card_name": card_name,
		"skill": skill,
		"display_name": _card_display_name(card_name),
		"display_text": _skill_display_text(skill),
		"tag_text": _skill_tag_text(skill),
		"rank": _game_runtime_coordinator_node().card_rank(card_name),
		"price": _card_price(card_name, district_index, player_index),
		"play_requirement_text": String(requirement.get("requirement_text", "条件：无")),
		"required_share_percent": int(requirement.get("required_share_percent", 0)),
		"play_cash_cost": int(requirement.get("cash_cost", 0)),
		"targets_monster": bool(target.get("targets_monster", false)),
		"targets_player": bool(target.get("targets_player", false)),
		"requires_target_monster": bool(target.get("requires_target_monster", false)),
		"requires_target_player": bool(target.get("requires_target_player", false)),
		"is_monster_card": _is_monster_card_name(card_name),
		"is_direct_monster_skill": bool(target.get("targets_monster", false)) and not ["monster_lure", "special_monster_delay", "mudslide", "monster_takeover", "military_command"].has(kind),
		"city_gdp_derivative_duration_seconds": _city_gdp_derivative_duration_seconds(skill) if kind == "city_gdp_derivative" else 0.0,
		"product_futures_duration_seconds": _product_market_futures_duration_seconds(skill) if kind == "product_futures" else 0.0,
		"counter_window_default_seconds": _ruleset_timing_seconds(&"counter_window_seconds"),
		"weather_label": weather_runtime_controller.label(String(skill.get("weather_type", ""))) if String(skill.get("weather_type", "")) != "" else "",
		"weather_forecast_lead_min_seconds": WeatherRuntimeController.FORECAST_LEAD_MIN_SECONDS,
		"economy_legacy_turn_seconds": ECONOMY_LEGACY_TURN_SECONDS,
		"military_type_label": military_runtime_controller.unit_type_label(skill),
		"military_domain_label": military_runtime_controller.domain_label(skill),
		"military_mobility_summary": military_runtime_controller.mobility_summary(skill),
		"military_hp": military_runtime_controller.unit_hp(skill),
		"military_damage": military_runtime_controller.unit_damage(skill),
		"military_duration": military_runtime_controller.unit_duration(skill),
		"military_command_label": military_runtime_controller.command_label(String(skill.get("military_command", ""))),
	}


func _card_resolution_presentation_source(skill: Dictionary, entry: Dictionary = {}, seconds_left: float = -1.0, resolved: bool = true) -> Dictionary:
	var card_name := String(skill.get("name", "匿名卡牌"))
	var display_duration := card_resolution_force_duration if card_resolution_force_duration > 0.0 else CARD_RESOLUTION_DISPLAY_SECONDS
	return {
		"card": _card_presentation_source(card_name, skill, selected_player, selected_district),
		"seconds_left": seconds_left,
		"display_duration": display_duration,
		"resolved": resolved,
		"effect_style": String(entry.get("aftermath_style", "")),
		"targets_monster": bool(_card_play_target_snapshot(skill).get("targets_monster", false)),
		"target_facts": _card_resolution_target_facts(skill, entry),
		"animation_facts": {
			"family": _game_runtime_coordinator_node().card_family_id(card_name),
			"monster_name": String(skill.get("monster_name", _monster_name_from_card_name(card_name))),
			"monster_move_text": _meters_text(float(skill.get("move", 0.0))),
			"monster_duration_text": _monster_card_duration_text(skill, true),
			"military_unit_type_label": military_runtime_controller.unit_type_label(skill),
			"military_hp": military_runtime_controller.unit_hp(skill),
			"military_damage": military_runtime_controller.unit_damage(skill),
			"military_move_text": _meters_text(military_runtime_controller.unit_move(skill)),
			"military_duration_text": _duration_short_text(military_runtime_controller.unit_duration(skill)),
			"military_mobility_summary": military_runtime_controller.mobility_summary(skill),
			"military_command_label": military_runtime_controller.command_label(String(skill.get("military_command", ""))),
			"military_range": military_runtime_controller.unit_range(skill),
		},
	}


func _card_resolution_target_facts(skill: Dictionary, entry: Dictionary = {}) -> Dictionary:
	var target_slot := int(entry.get("target_slot", -1))
	var target_player := int(entry.get("target_player", -1))
	var district_index := int(entry.get("selected_district", -1))
	var monster_name := ""
	if target_slot >= 0 and target_slot < monster_runtime_controller.auto_monsters.size():
		monster_name = String((monster_runtime_controller.auto_monsters[target_slot] as Dictionary).get("name", "怪兽"))
	var contract_controller := _contract_runtime_controller_node()
	return {
		"monster_slot": target_slot if target_slot >= 0 and target_slot < monster_runtime_controller.auto_monsters.size() else -1,
		"monster_name": monster_name,
		"player_index": target_player if target_player >= 0 and target_player < players.size() else -1,
		"is_contract": String(skill.get("kind", "")) == "area_trade_contract",
		"contract_source": contract_controller.district_short_name(int(entry.get("contract_source_district", -1))) if contract_controller != null else "未设",
		"contract_target": contract_controller.district_short_name(int(entry.get("contract_target_district", -1))) if contract_controller != null else "未设",
		"contract_product": contract_controller.entry_product_text(entry) if contract_controller != null else "未指定商品",
		"district_name": String(districts[district_index].get("name", "区域")) if district_index >= 0 and district_index < districts.size() else "",
		"trade_product": String(entry.get("selected_trade_product", "")),
		"requires_monster_target": bool(_card_play_target_snapshot(skill).get("requires_target_monster", false)),
	}


func _card_resolution_presentation_snapshot(skill: Dictionary, entry: Dictionary = {}, seconds_left: float = -1.0, resolved: bool = true) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("compose_card_resolution_presentation"):
		return {}
	var value: Variant = coordinator.call("compose_card_resolution_presentation", _card_resolution_presentation_source(skill, entry, seconds_left, resolved))
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_presentation_snapshot(card_name: String, supplied_skill: Dictionary = {}, player_index: int = -1, district_index: int = -1) -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("compose_card_presentation"):
		return {}
	var value: Variant = coordinator.call("compose_card_presentation", _card_presentation_source(card_name, supplied_skill, player_index, district_index))
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _card_presentation_text(skill: Dictionary, field: String, card_name: String = "", player_index: int = -1, district_index: int = -1) -> String:
	var resolved_name := card_name if card_name != "" else String(skill.get("name", ""))
	return str(_card_presentation_snapshot(resolved_name, skill, player_index, district_index).get(field, ""))


func _card_presentation_color(skill: Dictionary, card_name: String = "") -> Color:
	var resolved_name := card_name if card_name != "" else String(skill.get("name", ""))
	return _card_presentation_snapshot(resolved_name, skill).get("accent", Color("#94a3b8")) as Color


func _card_presentation_array(skill: Dictionary, field: String, card_name: String = "", player_index: int = -1, district_index: int = -1) -> Array:
	var resolved_name := card_name if card_name != "" else String(skill.get("name", ""))
	var value: Variant = _card_presentation_snapshot(resolved_name, skill, player_index, district_index).get(field, [])
	return (value as Array).duplicate(true) if value is Array else []


func _card_presentation_detail_tooltip(card_name: String, district_index: int = -1) -> String:
	if card_name == "" or not _game_runtime_coordinator_node().card_exists(card_name):
		return ""
	return _card_presentation_text(_game_runtime_coordinator_node().card_definition(card_name), "detail_tooltip", card_name, selected_player, district_index)


func _runtime_card_viewmodel_source(player_index: int, district_snapshot: Dictionary, action_entries: Array, logs: Array) -> Dictionary:
	return {
		"hand_cards": _runtime_hand_card_fact_sources(player_index),
		"track": _runtime_card_track_model_source(),
		"selected_hand_slot": selected_runtime_card_slot,
		"selected_resolution_id": selected_card_resolution_id,
		"district": district_snapshot,
		"fallback_why": _runtime_selected_context_why(player_index),
		"fallback_requirements": _runtime_requirement_chip_snapshots(player_index),
		"fallback_actions": action_entries,
		"fallback_deep_links": _runtime_deep_link_snapshots(),
		"logs": logs,
	}


func _runtime_card_surfaces_snapshot(player_index: int = -1) -> Dictionary:
	var resolved_player := player_index if player_index >= 0 else _runtime_snapshot_player_index()
	var district_snapshot := _runtime_selected_district_snapshot_source(resolved_player)
	var actions := _runtime_snapshot_action_entries(resolved_player)
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("compose_game_card_surfaces"):
		return {}
	var value: Variant = coordinator.call("compose_game_card_surfaces", _runtime_card_viewmodel_source(resolved_player, district_snapshot, actions, _runtime_public_log_snapshot()))
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _runtime_hand_card_fact_sources(player_index: int) -> Array:
	var result: Array = []
	if not _runtime_player_is_valid(player_index) or not _can_view_player_private_hand(player_index):
		return result
	var slots: Array = (players[player_index] as Dictionary).get("slots", [])
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var skill := slots[slot_index] as Dictionary
		var card_name := String(skill.get("name", ""))
		result.append({
			"slot": slot_index,
			"card": _card_presentation_source(card_name, skill, player_index, selected_district),
			"eligibility": _card_play_eligibility_snapshot(player_index, skill, "hand"),
		})
	return result


func _runtime_card_track_model_source() -> Dictionary:
	var current_queue := _card_resolution_current_queue()
	var next_queue := _card_resolution_next_queue()
	var active_entry := _card_resolution_active_entry()
	return {
		"history": _runtime_enriched_card_track_entries(resolved_card_history),
		"active": _runtime_enriched_card_track_entry(active_entry),
		"queue": _runtime_enriched_card_track_entries(current_queue),
		"next_queue": _runtime_enriched_card_track_entries(next_queue),
		"events": _recent_table_event_entries(),
		"scenario_demo": _runtime_scenario_demo_card_model_source(),
		"needs_scenario_demo": _scenario_runtime_needs_demo_track(),
		"selected_resolution_id": selected_card_resolution_id,
		"selected_player": selected_player,
		"auction_open": card_resolution_auction_open,
		"batch_locked": card_resolution_batch_locked,
		"counter_window_active": card_resolution_counter_window_active,
		"bidding_open": _card_group_bidding_open(),
		"group_phase": _card_group_window_phase(),
		"group_phase_remaining_seconds": _card_group_phase_remaining_seconds(),
		"group_cadence": _card_group_cadence_snapshot(),
		"group_count": _card_resolution_groups().size(),
		"highest_bid": _highest_card_resolution_bid(),
		"pending_decision": not _runtime_temporary_decision_snapshot_source(_runtime_snapshot_player_index()).is_empty() if _runtime_snapshot_player_index() >= 0 else false,
		"status_text": _card_resolution_status_text(),
		"history_window": 10,
	}


func _runtime_enriched_card_track_entries(entries: Array) -> Array:
	var result: Array = []
	for entry_variant in entries:
		if entry_variant is Dictionary:
			result.append(_runtime_enriched_card_track_entry(entry_variant as Dictionary))
	return result


func _runtime_enriched_card_track_entry(entry: Dictionary) -> Dictionary:
	if entry.is_empty():
		return {}
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	var card_name := String(skill.get("name", _card_resolution_entry_card_label(entry)))
	var owner_index := int(entry.get("player_index", -1))
	var public_entry := entry.duplicate(true)
	public_entry["is_viewer_card"] = owner_index == selected_player
	var resolution_presentation := _card_resolution_presentation_snapshot(skill, entry)
	var facility_label := ""
	if String(skill.get("kind", "")) == "public_facility":
		facility_label = "%s%s" % [String(skill.get("industry_id", "通用")), String(skill.get("facility_type", "设施"))]
	return {
		"entry": public_entry,
		"card": _card_presentation_source(card_name, skill, selected_player, selected_district),
		"card_label": _card_resolution_entry_card_label(entry),
		"effect_text": _skill_display_text(skill),
		"requirement_text": _card_resolution_play_requirement_text(entry),
		"target_text": String(resolution_presentation.get("target_text", "")),
		"animation_text": String(resolution_presentation.get("animation_text", "")),
		"tip_clue": _card_resolution_tip_clue_text(entry),
		"facility_label": facility_label,
		"can_reorder": owner_index == selected_player and _card_group_submissions_open(),
	}


func _runtime_scenario_demo_card_model_source() -> Dictionary:
	if not _scenario_runtime_needs_demo_track():
		return {}
	var card_name := _runtime_scenario_demo_card_name()
	var skill: Dictionary = _make_skill(card_name) if card_name != "" else {}
	var resolution_id := _runtime_scenario_demo_resolution_id()
	var entry := {
		"resolution_id": resolution_id,
		"queued_order": resolution_id,
		"player_index": -1,
		"skill": skill,
		"priority_bid_cents": 5000,
		"public_owner_revealed": false,
		"selected_trade_product": selected_trade_product,
	}
	var result := _runtime_enriched_card_track_entry(entry)
	result["state_text"] = "竞拍1" if _active_runtime_scenario_id() == "bid_practice" else "已公开"
	return result


func _runtime_selected_district_snapshot_source(player_index: int) -> Dictionary:
	if selected_district < 0 or selected_district >= districts.size():
		return {
			"id": "",
			"title": "未选区",
			"summary": "先点星球区域。",
			"detail": "先点星球区域。",
			"full_detail": "点星球区域，查看城市、牌架和行动。",
			"chips": [{"text": "未选择"}],
		}
	var district: Dictionary = districts[selected_district]
	var chips: Array = [{"text": "区域 %d" % (selected_district + 1)}]
	var infrastructure := _region_infrastructure_snapshot_for_district(selected_district)
	for facility_variant in infrastructure.get("facilities", []):
		var facility: Dictionary = facility_variant as Dictionary
		chips.append({
			"text": "%s%s｜%s" % [
				String(facility.get("industry_id", "")).to_upper(),
				String(facility.get("facility_type", "facility")),
				_level_text(int(facility.get("rank", 1))),
			],
			"tooltip": "公共设施类型、等级和产权公开。",
		})
		if chips.size() >= 5:
			break
	for lamp_variant in _selected_district_action_lamp_entries(player_index):
		if not (lamp_variant is Dictionary):
			continue
		var lamp: Dictionary = lamp_variant
		chips.append({"text": "%s:%s" % [String(lamp.get("text", "")), String(lamp.get("state", ""))]})
		if chips.size() >= 8:
			break
	var district_summary := _runtime_selected_district_summary(player_index)
	var supply_summary := _selected_district_supply_text(player_index)
	var infrastructure_lines := ["共享生命：%d/%d｜%s" % [
		int(infrastructure.get("derived_current_hp", 0)),
		int(infrastructure.get("derived_max_hp", 0)),
		String(infrastructure.get("lifecycle_state", "undeveloped")),
	]]
	for facility_variant in infrastructure.get("facilities", []):
		var facility: Dictionary = facility_variant as Dictionary
		infrastructure_lines.append("公共设施：%s %s｜%s｜业主席位%d" % [
			String(facility.get("industry_id", "通用")),
			String(facility.get("facility_type", "facility")),
			_level_text(int(facility.get("rank", 1))),
			int(facility.get("owner_player_index", -1)) + 1,
		])
	var coordinator := _game_runtime_coordinator_node()
	var weather_detail: Dictionary = coordinator.weather_region_detail_snapshot(selected_district) if coordinator != null and coordinator.has_method("weather_region_detail_snapshot") else {}
	if not weather_detail.is_empty() and str(weather_detail.get("phase", "clear")) != "clear":
		var phase_label: String = str({"queued": "等待中", "forecast": "预报中", "active": "生效中", "fading": "正在消退"}.get(str(weather_detail.get("phase", "")), "未知"))
		var remaining_seconds := float(int(weather_detail.get("remaining_us", 0))) / 1_000_000.0
		chips.insert(1, {
			"text": "%s｜%s" % [str(weather_detail.get("display_name", "区域天气")), phase_label],
			"tooltip": str(weather_detail.get("accessible_text", "")),
			"color": Color("#7dd3fc"),
		})
		infrastructure_lines.append("天气：%s｜%s｜剩余%s" % [
			str(weather_detail.get("display_name", "区域天气")),
			phase_label,
			_duration_short_text(remaining_seconds),
		])
		for effect_variant in weather_detail.get("effects", []):
			var effect := effect_variant as Dictionary
			infrastructure_lines.append("天气影响：%s %s" % [str(effect.get("label", "影响")), str(effect.get("value_text", ""))])
		infrastructure_lines.append("利用：%s" % str(weather_detail.get("exploitation_hint", "维持当前计划")))
		infrastructure_lines.append("应对：%s" % str(weather_detail.get("counterplay_hint", "无需额外部署")))
	var full_detail := "%s\n%s%s" % [
		district_summary,
		supply_summary,
		"\n%s" % "\n".join(infrastructure_lines),
	]
	var table_summary := _short_card_text("%s｜%s" % [district_summary, supply_summary], 40)
	return {
		"id": str(selected_district),
		"title": String(district.get("name", "区域")),
		"summary": table_summary,
		"detail": table_summary,
		"full_detail": full_detail,
		"chips": chips,
	}
















func _scenario_runtime_needs_demo_track() -> bool:
	return _active_runtime_scenario_id() in ["public_track_intro", "bid_practice", "intel_guess"]


func _runtime_scenario_demo_resolution_id() -> int:
	match _active_runtime_scenario_id():
		"public_track_intro":
			return 930301
		"bid_practice":
			return 930401
		"intel_guess":
			return 930701
	return 930000


func _runtime_scenario_demo_card_name() -> String:
	for candidate in ["城市融资1", "交通升级1", "区域宣传1", "商路黑客1"]:
		if _game_runtime_coordinator_node().card_exists(candidate):
			return candidate
	for skill_name_variant in _game_runtime_coordinator_node().card_catalog_ordered_ids():
		return str(skill_name_variant)
	return ""










func _runtime_planet_snapshot_source() -> Dictionary:
	var campaign_focus := _runtime_campaign_focus_mode()
	return {
		"title": "星球牌桌",
		"hint": "双击区域看牌架｜滚轮缩放｜拖拽旋转" if campaign_focus else "区域 %d｜怪兽 %d｜军队 %d｜选区 %s" % [
			districts.size(),
			monster_runtime_controller.auto_monsters.size(),
			military_runtime_controller.roster_snapshot(true).size(),
			_runtime_selected_district_title(),
		],
		"campaign_focus_mode": campaign_focus,
		"compact": campaign_focus,
		"left_rail": {
			"title": "地表情报",
			"entries": _runtime_planet_surface_rail_entries(selected_player),
		},
		"right_rail": {
			"title": "外围压力",
			"entries": _runtime_planet_outer_rail_entries(),
			"hidden": _card_resolution_side_lane_focus_active(),
		},
		"weather": {
			"active": weather_runtime_controller.active_ui_text(),
			"forecast": weather_runtime_controller.forecast_ui_text(),
			"impact": weather_runtime_controller.impact_ui_text(),
			"tooltip": weather_runtime_controller.status_text(),
		},
		"flow_compass": _runtime_planet_flow_compass_source(),
	}


func _runtime_planet_flow_compass_source() -> Dictionary:
	var steps: Array = []
	var next_text := "下一步：开局准备"
	if selected_player >= 0 and selected_player < players.size():
		steps = _playtest_flow_compass_entries(selected_player)
		next_text = _playtest_flow_next_text(selected_player)
	else:
		steps = [
			{"label": "开局", "done": false, "current": true, "accent": Color("#fef3c7"), "tip": "先从开局准备进入一桌测试局。"},
			{"label": "点区", "done": false, "current": false, "accent": Color("#38bdf8"), "tip": "进局后先点中央星球区域。"},
			{"label": "牌架", "done": false, "current": false, "accent": Color("#facc15"), "tip": "查看挂牌并选择受光来源。"},
		]
	return {
		"title": "试玩 罗盘",
		"steps": steps,
		"next_text": next_text,
		"tooltip": "第一局只要顺着这条小轨走到“选路线”；具体按钮在底部快捷行动、手牌架和经济总览。",
	}


func _card_resolution_side_lane_focus_active() -> bool:
	if not _card_resolution_active_entry().is_empty() or card_resolution_counter_window_active or card_resolution_auction_open:
		return true
	if not _card_resolution_current_queue().is_empty() and not card_resolution_batch_locked:
		return true
	if card_resolution_simultaneous_timer > 0.0 and not _card_resolution_current_queue().is_empty():
		return true
	return false


func _runtime_planet_surface_rail_entries(player_index: int) -> Array:
	var selected_ok := selected_district >= 0 and selected_district < districts.size()
	var choices_count := 0
	var supply_text := "补给：未选区"
	if selected_ok:
		choices_count = _selected_district_card_choices().size()
		supply_text = _selected_district_supply_text(player_index)
	return [
		{
			"label": "星区",
			"value": "%d区" % districts.size(),
			"active": districts.size() > 0,
			"accent": Color("#38bdf8"),
			"tooltip": "公开星区数量；完整区域事实进入区域图鉴。",
		},
		{
			"label": "选区",
			"value": _short_card_text(_runtime_selected_district_title(), 12),
			"active": selected_ok,
			"accent": Color("#facc15"),
			"tooltip": "当前选中的星球区域。",
		},
		{
			"label": "牌架",
			"value": "%d张" % choices_count if selected_ok else "未选",
			"active": selected_ok and choices_count > 0,
			"accent": Color("#c084fc"),
			"tooltip": "当前选区可查看的公开牌架数量。",
		},
		{
			"label": "补给",
			"value": _short_card_text(supply_text.replace("补给 ", ""), 12),
			"active": selected_ok,
			"accent": Color("#4ade80"),
			"tooltip": supply_text,
		},
	]


func _runtime_planet_outer_rail_entries() -> Array:
	var queue_count := _card_resolution_current_queue().size() + _card_resolution_next_queue().size()
	return [
		{
			"label": "怪兽",
			"value": "%d只" % monster_runtime_controller.auto_monsters.size(),
			"active": monster_runtime_controller.auto_monsters.size() > 0,
			"accent": Color("#fb7185"),
			"tooltip": "公开怪兽数量；完整怪兽档案进入图鉴。",
		},
		{
			"label": "天气",
			"value": weather_runtime_controller.planet_short_text(),
			"active": weather_runtime_controller.active_zone_count() > 0 or weather_runtime_controller.has_forecast(),
			"accent": Color("#38bdf8"),
			"tooltip": weather_runtime_controller.status_text(),
		},
		{
			"label": "牌轨",
			"value": _runtime_planet_card_track_short_text(queue_count),
			"active": queue_count > 0 or card_resolution_auction_open or not _card_resolution_active_entry().is_empty(),
			"accent": Color("#f59e0b"),
			"tooltip": _card_resolution_status_text(),
		},
		{
			"label": "终局",
			"value": str(_victory_control_public_snapshot().get("state", "idle")),
			"active": _victory_control_timer_visible(),
			"accent": Color("#facc15"),
			"tooltip": _victory_control_status_text(),
		},
	]


func _runtime_planet_card_track_short_text(queue_count: int) -> String:
	if card_resolution_auction_open:
		return "竞价%d" % queue_count
	if not _card_resolution_active_entry().is_empty():
		return "展示"
	if queue_count > 0:
		return "队列%d" % queue_count
	return "空闲"


func _runtime_requirement_chip_snapshots(player_index: int) -> Array:
	var chips: Array = []
	for entry_variant in _selected_district_action_lamp_entries(player_index):
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		chips.append({
			"text": "%s:%s" % [String(entry.get("text", "")), String(entry.get("state", ""))],
			"tooltip": String(entry.get("tip", "")),
		})
	if chips.is_empty():
		chips.append({"text": "暂无条件"})
	return chips


func _runtime_snapshot_action_entries(player_index: int) -> Array:
	var actions: Array = []
	var primary: Dictionary = _runtime_primary_action_entry(player_index)
	actions.append({
		"id": "primary",
		"label": String(primary.get("label", "看星球")),
		"disabled": bool(primary.get("disabled", true)),
		"tooltip": String(primary.get("detail", "")),
	})
	if player_index >= 0 and selected_district >= 0 and selected_district < districts.size():
		var district_actions: Array = _selected_district_action_entries(player_index)
		for i in range(district_actions.size()):
			var entry_variant: Variant = district_actions[i]
			if not (entry_variant is Dictionary):
				continue
			var entry: Dictionary = entry_variant
			actions.append({
				"id": "district_%d" % i,
				"label": String(entry.get("label", entry.get("text", "行动"))),
				"disabled": bool(entry.get("disabled", false)),
				"tooltip": String(entry.get("tooltip", "")),
			})
			if actions.size() >= 5:
				break
	if actions.is_empty():
		actions.append({"id": "inspect", "label": "看星球", "disabled": false, "tooltip": "选择区域，或打开图鉴深读。"})
	return actions


func _runtime_primary_action_entry(player_index: int) -> Dictionary:
	var body: String = "%s %s" % [
		_runtime_selected_district_summary(player_index),
		_selected_district_supply_text(player_index) if selected_district >= 0 and selected_district < districts.size() else "",
	]
	var primary: Dictionary = _table_goal_primary_action(player_index, body)
	if primary.is_empty():
		return {"label": "看星球", "detail": "选择区域后显示下一步具体行动。", "disabled": false}
	return primary


func _runtime_primary_action_label(player_index: int) -> String:
	return String(_runtime_primary_action_entry(player_index).get("label", "看星球"))






func _runtime_selected_context_why(player_index: int) -> String:
	if players.is_empty():
		return "开桌后显示下一步。"
	if selected_district < 0 or selected_district >= districts.size():
		return "先点星球区域。"
	var active_labels: Array[String] = []
	for entry_variant in _selected_district_action_lamp_entries(player_index):
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if bool(entry.get("active", false)):
			active_labels.append("%s:%s" % [String(entry.get("text", "")), String(entry.get("state", ""))])
	if not active_labels.is_empty():
		return "现在可做：%s。" % "、".join(active_labels)
	return "选择目标区域，再从真实卡牌目录打出完整定义的公共设施牌。"


func _runtime_deep_link_snapshots() -> Array:
	return [
		{"id": "detail_region", "label": "区域详情"},
		{"id": "detail_cards", "label": "卡牌/牌架"},
		{"id": "detail_intel", "label": "情报详情"},
	]


func _runtime_public_log_snapshot() -> Array:
	var logs: Array = []
	var start_index: int = maxi(0, log_lines.size() - 6)
	for i in range(start_index, log_lines.size()):
		logs.append(String(log_lines[i]))
	var composition := _final_settlement_runtime_composition_node()
	if composition != null and composition.has_method("sanitize_public_log_entries"):
		var sanitized_variant: Variant = composition.call("sanitize_public_log_entries", logs)
		logs = (sanitized_variant as Array).duplicate(true) if sanitized_variant is Array else []
	if logs.is_empty():
		logs.append(_card_resolution_status_text())
	return logs


func _runtime_player_board_hint(player_index: int) -> String:
	if not _runtime_player_is_valid(player_index):
		return "还没有可行动席位。"
	if _can_view_player_private_hand(player_index):
		return "私密手牌和当前行动都固定在底部玩家板。"
	return "只看公开席位：私密现金和手牌保持隐藏。"


func _runtime_selected_district_summary(player_index: int) -> String:
	if selected_district < 0 or selected_district >= districts.size():
		return "未选区"
	var summary := _selected_district_status_text(player_index)
	if not _can_view_player_private_hand(player_index):
		return summary
	var own_facilities := []
	for facility_variant in _region_infrastructure_owned_facilities(selected_district, player_index):
		var facility: Dictionary = facility_variant as Dictionary
		own_facilities.append("%s%s %s" % [
			String(facility.get("industry_id", "通用")),
			String(facility.get("facility_type", "facility")),
			_level_text(int(facility.get("rank", 1))),
		])
	if not own_facilities.is_empty():
		summary += "｜我的公共设施：%s" % "、".join(own_facilities)
	return summary


func _runtime_selected_district_title() -> String:
	if selected_district < 0 or selected_district >= districts.size():
		return "未选区"
	return String(districts[selected_district].get("name", "区域"))


func _runtime_player_cash_text(player_index: int) -> String:
	if not _runtime_player_is_valid(player_index):
		return "--"
	if _can_view_player_private_hand(player_index):
		return "¥ %d" % int((players[player_index] as Dictionary).get("cash", 0))
	return "公开估算 %d" % _victory_player_progress_metric(player_index)


func _runtime_player_gdp_text(player_index: int) -> String:
	if not _runtime_player_is_valid(player_index):
		return "--/min"
	if _can_view_player_private_hand(player_index):
		return "%d/min" % _player_gdp_per_minute(player_index)
	return "公开"


func _runtime_player_is_valid(player_index: int) -> bool:
	return player_index >= 0 and player_index < players.size()


func _active_bottom_countdown_state() -> Dictionary:
	var forced_decision := _active_forced_decision(selected_player)
	match str(forced_decision.get("priority_group", "")):
		"monster_wager":
			var wager := monster_runtime_controller._latest_active_monster_wager()
			return {
				"visible": true,
				"label": "怪兽赌局",
				"remaining": maxf(0.0, float(wager.get("remaining_seconds", _ruleset_timing_seconds(&"monster_wager_default_seconds")))),
				"total": maxf(1.0, float(wager.get("seconds_total", _ruleset_timing_seconds(&"monster_wager_default_seconds")))),
				"accent": Color("#fb7185"),
			}
		"counter_response":
			return {
				"visible": true,
				"label": "相位响应",
				"remaining": maxf(0.0, card_resolution_counter_timer),
				"total": maxf(1.0, _card_resolution_timer_total_for_stage("counter", _card_resolution_active_entry())),
				"accent": Color("#c084fc"),
			}
		"contract_response":
			var contract_controller := _contract_runtime_controller_node()
			var contract_offer := contract_controller.active_offer_for_player(selected_player) if contract_controller != null else {}
			return {
				"visible": true,
				"label": "合约回应" if not contract_offer.is_empty() else "等待合约回应",
				"remaining": maxf(0.0, float(contract_offer.get("contract_decision_timer", 0.0))),
				"total": maxf(1.0, _ruleset_timing_seconds(&"contract_window_seconds")),
				"accent": Color("#fbbf24"),
			}
	if card_resolution_auction_open:
		return {
			"visible": true,
			"label": "锁牌竞价",
			"remaining": maxf(0.0, card_resolution_auction_timer),
			"total": maxf(1.0, _card_resolution_timer_total_for_stage("auction", {})),
			"accent": Color("#f59e0b"),
		}
	if card_resolution_simultaneous_timer > 0.0:
		return {
			"visible": true,
			"label": "卡牌组组织",
			"remaining": maxf(0.0, card_resolution_simultaneous_timer),
			"total": maxf(0.1, _card_resolution_timer_total_for_stage("simultaneous", {})),
			"accent": Color("#93c5fd"),
		}
	if not _card_resolution_active_entry().is_empty():
		return {
			"visible": true,
			"label": "公开展示",
			"remaining": maxf(0.0, card_resolution_timer),
			"total": maxf(1.0, _card_resolution_timer_total_for_stage("reveal", _card_resolution_active_entry())),
			"accent": Color("#fde68a"),
		}
	if _victory_control_timer_visible():
		var victory_state := str(_victory_control_public_snapshot().get("state", "idle"))
		return {
			"visible": true,
			"label": {"qualification": "胜利资格", "audit": "公开审计"}.get(victory_state, "胜利审计"),
			"remaining": maxf(0.0, _victory_control_remaining_seconds()),
			"total": _victory_control_total_seconds(),
			"accent": Color("#f97316"),
		}
	return {"visible": false}


func _refresh_bottom_countdown_bar() -> void:
	if bottom_countdown_overlay == null:
		return
	var state := _active_bottom_countdown_state()
	if bottom_countdown_overlay.has_method("set_state"):
		bottom_countdown_overlay.call("set_state", state)
		return
	if card_resolution_timer_bar == null or card_resolution_timer_label == null:
		return
	if not bool(state.get("visible", false)):
		bottom_countdown_overlay.visible = false
		return
	var accent: Color = state.get("accent", Color("#fde68a")) as Color
	var remaining := maxf(0.0, float(state.get("remaining", 0.0)))
	var total := maxf(0.001, float(state.get("total", 1.0)))
	var ratio := clampf(remaining / total, 0.0, 1.0)
	bottom_countdown_overlay.visible = true
	card_resolution_timer_label.text = String(state.get("label", "牌桌沙漏"))
	card_resolution_timer_label.add_theme_color_override("font_color", accent.lightened(0.16))
	card_resolution_timer_label.tooltip_text = "当前需要全桌注意的窗口。"
	card_resolution_timer_bar.value = ratio * 100.0
	card_resolution_timer_bar.tooltip_text = "条越短，当前窗口越接近结束。"
	card_resolution_timer_bar.add_theme_stylebox_override("fill", _menu_card_style(accent, Color("#020617").lerp(accent, 0.72), 0, 6))
	if bottom_countdown_panel != null:
		bottom_countdown_panel.add_theme_stylebox_override("panel", _menu_card_style(accent, Color("#020617").lerp(accent, 0.16), 1, 12))


func _refresh_board() -> void:
	if map_view == null:
		return
	_set_map_view_data(map_view)
	if full_map_overlay != null and full_map_overlay.visible and full_map_view != null:
		_set_map_view_data(full_map_view)


func _set_map_view_data(target_view: Control) -> void:
	target_view.set_map(
		districts,
		map_width_m,
		map_height_m,
		selected_district,
		DISTRICT_PALETTE,
		movement_trails,
		action_callouts,
		map_event_effects,
		_auto_monster_markers(),
		_city_markers_for_selected_player(),
		_trade_route_markers_for_selected_product(),
		selected_trade_product,
		selected_map_layer_focus
	)
	var coordinator := _game_runtime_coordinator_node()
	if coordinator != null and target_view.has_method("set_solar_presentation_snapshot"):
		target_view.call("set_solar_presentation_snapshot", coordinator.solar_public_presentation_snapshot())
	if coordinator != null and target_view.has_method("set_weather_overlay_view_model"):
		target_view.call("set_weather_overlay_view_model", coordinator.weather_map_overlay_view_model())
	if target_view.has_method("set_solar_camera_motion_mode"):
		var solar_motion_mode := "reduced" if campaign_animation_intensity == "简化" else ("off" if campaign_animation_intensity == "关闭" else "full")
		target_view.call("set_solar_camera_motion_mode", solar_motion_mode)
		if target_view.has_method("set_weather_overlay_motion_mode"):
			target_view.call("set_weather_overlay_motion_mode", solar_motion_mode)


func _focus_runtime_map_on_district(district_index: int) -> void:
	if district_index < 0 or district_index >= districts.size():
		return
	if map_view != null and map_view.has_method("focus_district"):
		_set_map_view_data(map_view)
		map_view.call("focus_district", district_index)
	if full_map_view != null and full_map_view.has_method("focus_district"):
		_set_map_view_data(full_map_view)
		full_map_view.call("focus_district", district_index)


func _jump_to_district_on_table(district_index: int, clear_card_selection: bool = true) -> bool:
	if district_index < 0 or district_index >= districts.size():
		return false
	selected_district = district_index
	if clear_card_selection:
		selected_runtime_card_slot = -1
	_focus_runtime_map_on_district(district_index)
	return true


func _player_color(player_index: int) -> Color:
	if PLAYER_COLORS.is_empty():
		return Color("#38bdf8")
	return PLAYER_COLORS[wrapi(player_index, 0, PLAYER_COLORS.size())] as Color


func _district_city(index: int) -> Dictionary:
	if index < 0 or index >= districts.size():
		return {}
	return districts[index].get("city", {}) as Dictionary


func _city_is_active(city: Dictionary) -> bool:
	return not city.is_empty() and bool(city.get("active", true))


func _city_product_names(city: Dictionary) -> Array:
	var result := []
	for product_variant in city.get("products", []):
		var product: Dictionary = product_variant
		result.append(String(product.get("name", "未知商品")))
	return result


func _city_demand_names(city: Dictionary) -> Array:
	var result := []
	for product_variant in city.get("demands", []):
		result.append(String(product_variant))
	return result


func _district_transport_speed(index: int) -> float:
	if index < 0 or index >= districts.size():
		return 1.0
	var district: Dictionary = districts[index]
	var level := int(district.get("transport_level", 2 if String(district.get("terrain", "land")) == "land" else 4))
	var base_score := _transport_score_from_level(level, String(district.get("terrain", "land")) == "ocean")
	var weather_multiplier := weather_runtime_controller.district_multiplier(index, "transport_multiplier", 1.0)
	return clampf(float(district.get("transport_score", base_score)) * weather_multiplier, REGION_TRANSPORT_SCORE_MIN, REGION_TRANSPORT_SCORE_MAX)


func _city_product_market_price_summary(city: Dictionary) -> String:
	var names := _city_product_names(city)
	return _product_list_with_prices(names, 4)


func _city_demand_price_summary(city: Dictionary) -> String:
	var names := _city_demand_names(city)
	return _product_list_with_prices(names, 4)


func _pay_rival_business_cost(player_index: int) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	var player: Dictionary = players[player_index]
	player["cash"] = max(0, int(player.get("cash", 0)) - RIVAL_BUSINESS_ACTION_COST)
	player["total_business_spend"] = int(player.get("total_business_spend", 0)) + RIVAL_BUSINESS_ACTION_COST
	players[player_index] = player
	_record_player_economic_event(player_index, "商业支出", "匿名商业行动", -RIVAL_BUSINESS_ACTION_COST, "市场刷新%d" % _product_market_cycle())
	_record_player_cash_snapshot(player_index)


func _city_public_clue_products_from_text(clue: String) -> Array:
	var products := []
	for product_variant in ProductMarketRuntimeController.PRODUCT_CATALOG:
		var product_name := String(product_variant)
		if product_name != "" and clue.contains(product_name):
			products.append(product_name)
	return products


func _city_public_clue_kind_from_text(clue: String) -> String:
	if clue.contains("合约") or clue.contains("签约") or clue.contains("拒签"):
		return "合约"
	if clue.contains("商路") or clue.contains("断路") or clue.contains("黑客"):
		return "商路"
	if clue.contains("需求压力") or clue.contains("市场") or clue.contains("价格"):
		return "市场"
	if clue.contains("GDP") or clue.contains("生产") or clue.contains("交通") or clue.contains("消费"):
		return "经营"
	return "公开"


func _normalize_city_public_clue_entry(value: Variant) -> Dictionary:
	if value is Dictionary:
		var entry := (value as Dictionary).duplicate(true)
		var text := String(entry.get("text", entry.get("clue", ""))).strip_edges()
		if text == "":
			return {}
		entry["text"] = text
		if not entry.has("time"):
			entry["time"] = float(entry.get("game_time", -1.0))
		if not entry.has("cycle"):
			entry["cycle"] = 0
		if String(entry.get("kind", "")) == "":
			entry["kind"] = _city_public_clue_kind_from_text(text)
		if not (entry.get("products", []) is Array) or (entry.get("products", []) as Array).is_empty():
			entry["products"] = _city_public_clue_products_from_text(text)
		return entry
	var clue_text := String(value).strip_edges()
	if clue_text == "":
		return {}
	var time_value := -1.0
	var text_value := clue_text
	if clue_text.begins_with("t") and clue_text.contains("s｜"):
		var split_parts := clue_text.split("｜", false, 1)
		if split_parts.size() >= 2:
			var stamp := String(split_parts[0]).trim_prefix("t").trim_suffix("s")
			time_value = stamp.to_float()
			text_value = String(split_parts[1]).strip_edges()
	return {
		"time": time_value,
		"cycle": 0,
		"kind": _city_public_clue_kind_from_text(text_value),
		"products": _city_public_clue_products_from_text(text_value),
		"text": text_value,
	}


func _city_public_clue_display_text(value: Variant) -> String:
	var entry := _normalize_city_public_clue_entry(value)
	if entry.is_empty():
		return ""
	var time_text := "T+%.0fs" % float(entry.get("time", 0.0)) if float(entry.get("time", -1.0)) >= 0.0 else "时间未知"
	return "%s｜%s｜商品:%s｜%s" % [
		time_text,
		String(entry.get("kind", "公开")),
		_limited_name_list(entry.get("products", []) as Array, 3, "无"),
		String(entry.get("text", "")),
	]


func _append_city_public_clue(city: Dictionary, clue: String) -> Dictionary:
	var clean_clue := clue.strip_edges()
	if clean_clue == "":
		return city
	city["last_public_clue"] = clean_clue
	var clues := []
	for clue_variant in city.get("public_clues", []):
		var clue_entry := _normalize_city_public_clue_entry(clue_variant)
		if not clue_entry.is_empty():
			clues.append(clue_entry)
	clues.append({
		"time": game_time,
		"cycle": _product_market_cycle(),
		"kind": _city_public_clue_kind_from_text(clean_clue),
		"products": _city_public_clue_products_from_text(clean_clue),
		"text": clean_clue,
	})
	while clues.size() > CITY_PUBLIC_CLUE_HISTORY_LIMIT:
		clues.pop_front()
	city["public_clues"] = clues
	return city


func _set_city_public_clue(city_index: int, clue: String) -> void:
	if city_index < 0 or city_index >= districts.size():
		return
	var city := _district_city(city_index)
	if city.is_empty():
		return
	city = _append_city_public_clue(city, clue)
	districts[city_index]["city"] = city


func _apply_rival_price_pump(player_index: int, action: Dictionary) -> bool:
	var own_city_index := int(action.get("own_city", -1))
	var product_name := String(action.get("product", ""))
	if own_city_index < 0 or own_city_index >= districts.size() or product_name == "":
		return false
	if not _city_is_active(_district_city(own_city_index)):
		return false
	var entry := _product_market_entry_snapshot(product_name)
	if entry.is_empty():
		return false
	var before_price := _product_market_price(product_name)
	var delta := rng.randi_range(RIVAL_BUSINESS_PRICE_DELTA_MIN, RIVAL_BUSINESS_PRICE_DELTA_MAX)
	_pay_rival_business_cost(player_index)
	var pressure := maxi(1, int(ceil(float(delta) / 10.0)))
	_product_market_runtime_call("apply_external_pressure", [product_name, pressure, 0, 0, true])
	var after_price := _product_market_price(product_name)
	var clue := "刷新%d：匿名财团制造%s需求压力%d，市场按供需重算¥%d→¥%d；疑似有生产该商品的城市受益。" % [
		_product_market_cycle(),
		product_name,
		pressure,
		before_price,
		after_price,
	]
	_set_city_public_clue(own_city_index, clue)
	_add_action_callout(
		"匿名商业",
		"需求造势",
		"%s需求压力+%d，价格由供需重算；可能暴露生产方利益。" % [product_name, pressure],
		Color("#f59e0b"),
		_district_center(own_city_index)
	)
	_log("%s" % clue)
	return true


func _apply_rival_business_action(player_index: int, action: Dictionary) -> bool:
	match String(action.get("kind", "")):
		"price_pump":
			return _apply_rival_price_pump(player_index, action)
	return false


func _cycle_guess_player(step: int) -> void:
	if players.is_empty():
		return
	for _attempt in range(players.size() + 1):
		selected_guess_player = wrapi(selected_guess_player + step + 1, 0, players.size() + 1) - 1
		if selected_guess_player != selected_player:
			break
	_refresh_map_controls()


func _toggle_selected_trade_route() -> void:
	if selected_trade_product != "":
		selected_trade_product = ""
	else:
		selected_trade_product = _default_trade_product_for_selected_district()
		if selected_trade_product == "" and not ProductMarketRuntimeController.PRODUCT_CATALOG.is_empty():
			selected_trade_product = String(ProductMarketRuntimeController.PRODUCT_CATALOG[0])
	_refresh_board()
	_refresh_map_controls()
	if selected_district >= 0:
		_game_runtime_coordinator_node().record_weather_public_response(selected_district, "route_after_forecast")


func _cycle_trade_product(step: int) -> void:
	if ProductMarketRuntimeController.PRODUCT_CATALOG.is_empty():
		return
	if selected_trade_product == "":
		selected_trade_product = _default_trade_product_for_selected_district()
		if selected_trade_product == "":
			selected_trade_product = String(ProductMarketRuntimeController.PRODUCT_CATALOG[0])
	else:
		var index := ProductMarketRuntimeController.PRODUCT_CATALOG.find(selected_trade_product)
		if index < 0:
			index = 0
		index = wrapi(index + step, 0, ProductMarketRuntimeController.PRODUCT_CATALOG.size())
		selected_trade_product = String(ProductMarketRuntimeController.PRODUCT_CATALOG[index])
	_refresh_board()
	_refresh_map_controls()


func _default_trade_product_for_selected_district() -> String:
	if selected_district >= 0 and selected_district < districts.size():
		var city := _district_city(selected_district)
		if _city_is_active(city):
			var demands := _city_demand_names(city)
			if not demands.is_empty():
				return String(demands[0])
			var city_products := _city_product_names(city)
			if not city_products.is_empty():
				return String(city_products[0])
		var products: Array = districts[selected_district].get("products", [])
		if not products.is_empty():
			return String(products[0])
		var district_demands: Array = districts[selected_district].get("demands", [])
		if not district_demands.is_empty():
			return String(district_demands[0])
	for index_variant in _active_city_district_indices():
		var city := _district_city(int(index_variant))
		var demands := _city_demand_names(city)
		if not demands.is_empty():
			return String(demands[0])
	return ""


func _load_selected_district_guess() -> void:
	selected_guess_player = -1
	if selected_player < 0 or selected_player >= players.size():
		return
	var guesses: Dictionary = players[selected_player].get("city_guesses", {})
	selected_guess_player = int(guesses.get(selected_district, -1))


func _mark_selected_city_guess() -> void:
	if _mark_city_guess_for_player(selected_player, selected_district, selected_guess_player):
		_refresh_ui()


func _mark_city_guess_for_player(viewer_index: int, city_index: int, guessed_player: int, confidence: int = CITY_GUESS_CONFIDENCE_DEFAULT, reason: String = CITY_GUESS_REASON_DEFAULT) -> bool:
	if viewer_index < 0 or viewer_index >= players.size():
		return false
	if city_index < 0 or city_index >= districts.size():
		return false
	var city := _district_city(city_index)
	if not _city_is_active(city):
		_log("选中区域没有可标注的存活城市群。")
		return false
	var city_owner := int(city.get("owner", -1))
	var guesses: Dictionary = players[viewer_index].get("city_guesses", {})
	var confidences: Dictionary = players[viewer_index].get("city_guess_confidence", {})
	var reasons: Dictionary = players[viewer_index].get("city_guess_reasons", {})
	if city_owner == viewer_index:
		guesses.erase(city_index)
		confidences.erase(city_index)
		reasons.erase(city_index)
		players[viewer_index]["city_guesses"] = guesses
		players[viewer_index]["city_guess_confidence"] = confidences
		players[viewer_index]["city_guess_reasons"] = reasons
		_log("这是%s自己的城市，不需要推测归属。" % players[viewer_index]["name"])
	elif guessed_player < 0:
		guesses.erase(city_index)
		confidences.erase(city_index)
		reasons.erase(city_index)
		players[viewer_index]["city_guesses"] = guesses
		players[viewer_index]["city_guess_confidence"] = confidences
		players[viewer_index]["city_guess_reasons"] = reasons
		_log("%s清除了对%s城市归属的私人标注。" % [players[viewer_index]["name"], districts[city_index]["name"]])
	elif guessed_player == viewer_index:
		guesses.erase(city_index)
		confidences.erase(city_index)
		reasons.erase(city_index)
		players[viewer_index]["city_guesses"] = guesses
		players[viewer_index]["city_guess_confidence"] = confidences
		players[viewer_index]["city_guess_reasons"] = reasons
		_log("%s不能把陌生城市标成自己；已清除该私人标注。" % players[viewer_index]["name"])
	elif guessed_player >= players.size():
		return false
	else:
		guesses[city_index] = guessed_player
		var normalized_confidence := _normalized_city_guess_confidence(confidence)
		var normalized_reason := _normalized_city_guess_reason(String(reasons.get(city_index, reason)))
		confidences[city_index] = normalized_confidence
		reasons[city_index] = normalized_reason
		players[viewer_index]["city_guesses"] = guesses
		players[viewer_index]["city_guess_confidence"] = confidences
		players[viewer_index]["city_guess_reasons"] = reasons
		_log("%s将%s私人标注为：推测属于玩家%d（置信:%s｜理由:%s）。情报现金终局才揭晓：猜对+¥%d，猜错-¥%d。" % [
			players[viewer_index]["name"],
			districts[city_index]["name"],
			guessed_player + 1,
			_city_guess_confidence_label(normalized_confidence),
			_city_guess_reason_label(normalized_reason),
			INTEL_CORRECT_GUESS_CASH,
			INTEL_WRONG_GUESS_COST,
		])
	return true


func _set_city_guess_confidence_for_player(viewer_index: int, city_index: int, confidence: int) -> bool:
	if viewer_index < 0 or viewer_index >= players.size():
		return false
	if city_index < 0 or city_index >= districts.size():
		return false
	var guesses: Dictionary = players[viewer_index].get("city_guesses", {})
	if int(guesses.get(city_index, -1)) < 0:
		_log("请先给%s设置业主标注，再调整置信度。" % String(districts[city_index].get("name", "城市")))
		return false
	var normalized_confidence := _normalized_city_guess_confidence(confidence)
	var confidences: Dictionary = players[viewer_index].get("city_guess_confidence", {})
	confidences[city_index] = normalized_confidence
	players[viewer_index]["city_guess_confidence"] = confidences
	_log("%s把%s的私人标注置信度调为%s；这只影响推理记录，不改变终局奖惩。" % [
		players[viewer_index]["name"],
		String(districts[city_index].get("name", "城市")),
		_city_guess_confidence_label(normalized_confidence),
	])
	return true


func _set_city_guess_reason_for_player(viewer_index: int, city_index: int, reason: String) -> bool:
	if viewer_index < 0 or viewer_index >= players.size():
		return false
	if city_index < 0 or city_index >= districts.size():
		return false
	var guesses: Dictionary = players[viewer_index].get("city_guesses", {})
	if int(guesses.get(city_index, -1)) < 0:
		_log("请先给%s设置业主标注，再记录标注理由。" % String(districts[city_index].get("name", "城市")))
		return false
	var normalized_reason := _normalized_city_guess_reason(reason)
	var reasons: Dictionary = players[viewer_index].get("city_guess_reasons", {})
	reasons[city_index] = normalized_reason
	players[viewer_index]["city_guess_reasons"] = reasons
	_log("%s把%s的私人标注理由记为%s；这只影响推理备忘，不改变终局奖惩。" % [
		players[viewer_index]["name"],
		String(districts[city_index].get("name", "城市")),
		_city_guess_reason_label(normalized_reason),
	])
	return true


func _private_known_card_owner_for_entry(viewer_index: int, entry: Dictionary) -> int:
	if viewer_index < 0 or viewer_index >= players.size():
		return -1
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	if resolution_id < 0:
		return -1
	var known: Dictionary = (players[viewer_index] as Dictionary).get("known_card_owners", {})
	return int(known.get(str(resolution_id), -1))


func _remember_card_owner_for_player(viewer_index: int, entry: Dictionary, source: String) -> bool:
	if viewer_index < 0 or viewer_index >= players.size():
		return false
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	var card_owner := int(entry.get("player_index", -1))
	if resolution_id < 0 or card_owner < 0 or card_owner >= players.size():
		return false
	var known: Dictionary = (players[viewer_index] as Dictionary).get("known_card_owners", {})
	if int(known.get(str(resolution_id), -1)) == card_owner:
		return false
	known[str(resolution_id)] = card_owner
	players[viewer_index]["known_card_owners"] = known
	_record_player_economic_event(viewer_index, "情报", source, 0, "私下查明轨道#%d《%s》由玩家%d打出。" % [
		resolution_id,
		_card_resolution_entry_card_label(entry),
		card_owner + 1,
	])
	return true


func _traceable_card_entries(preferred_resolution_id: int = -1, limit: int = 1) -> Array:
	var result := []
	if preferred_resolution_id >= 0:
		var preferred := _card_resolution_entry_by_id(preferred_resolution_id)
		if not preferred.is_empty() and not bool(preferred.get("public_owner_revealed", false)):
			result.append(preferred)
	for i in range(resolved_card_history.size() - 1, -1, -1):
		if result.size() >= limit:
			return result
		var entry_variant: Variant = resolved_card_history[i]
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
		if resolution_id < 0 or resolution_id == preferred_resolution_id or bool(entry.get("public_owner_revealed", false)):
			continue
		result.append(entry.duplicate(true))
	return result


func _trace_card_owner_for_player(viewer_index: int, preferred_resolution_id: int = -1, count: int = 1, source: String = "出牌追帧") -> int:
	var traced := 0
	for entry_variant in _traceable_card_entries(preferred_resolution_id, maxi(1, count)):
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if _remember_card_owner_for_player(viewer_index, entry, source):
			traced += 1
			_log("%s获得一条匿名卡牌归属线索：轨道#%d《%s》的真实出牌者已写入私人情报。" % [
				String((players[viewer_index] as Dictionary).get("name", "玩家")),
				int(entry.get("resolution_id", entry.get("queued_order", -1))),
				_card_resolution_entry_card_label(entry),
			])
	return traced


func _reveal_city_owner_by_intel_card(player_index: int, city_index: int, source: String) -> bool:
	if player_index < 0 or player_index >= players.size() or city_index < 0 or city_index >= districts.size():
		return false
	var city := _district_city(city_index)
	if not _city_is_active(city):
		return false
	var city_owner := int(city.get("owner", -1))
	if city_owner < 0 or city_owner >= players.size() or city_owner == player_index:
		return false
	if not _mark_city_guess_for_player(player_index, city_index, city_owner, CITY_GUESS_CONFIDENCE_HIGH, CITY_GUESS_REASON_CARD):
		return false
	_record_player_economic_event(player_index, "情报", source, 0, "线索牌查明%s真实业主为玩家%d；答案只进入私人标注。" % [
		String(districts[city_index].get("name", "区域")),
		city_owner + 1,
	])
	return true


func _apply_intel_city_reveal(_player: Dictionary, skill: Dictionary) -> bool:
	var count := maxi(1, int(skill.get("reveal_city_count", 1)))
	var districts_to_check := []
	if selected_district >= 0 and selected_district < districts.size():
		districts_to_check.append(selected_district)
	for entry_variant in _intel_city_guess_entries(selected_player, 12):
		if districts_to_check.size() >= count * 3:
			break
		if not (entry_variant is Dictionary):
			continue
		var district_index := int((entry_variant as Dictionary).get("district_index", -1))
		if district_index >= 0 and not districts_to_check.has(district_index):
			districts_to_check.append(district_index)
	var revealed := 0
	for district_variant in districts_to_check:
		if revealed >= count:
			break
		if _reveal_city_owner_by_intel_card(selected_player, int(district_variant), String(skill.get("name", "业主透镜"))):
			revealed += 1
			_log("线索牌%s：%s真实业主已写入当前玩家私人地图标注。" % [
				String(skill.get("name", "业主透镜")),
				String(districts[int(district_variant)].get("name", "区域")),
			])
	return revealed > 0


func _apply_intel_card_trace(_player: Dictionary, skill: Dictionary) -> bool:
	var traced := _trace_card_owner_for_player(
		selected_player,
		selected_card_resolution_id,
		maxi(1, int(skill.get("trace_card_count", 1))),
		String(skill.get("name", "出牌追帧"))
	)
	var revealed := 0
	var reveal_count := maxi(0, int(skill.get("reveal_city_count", 0)))
	if reveal_count > 0:
		var districts_to_check := []
		if selected_district >= 0 and selected_district < districts.size():
			districts_to_check.append(selected_district)
		for entry_variant in _intel_city_guess_entries(selected_player, 12):
			if districts_to_check.size() >= reveal_count * 3:
				break
			if not (entry_variant is Dictionary):
				continue
			var district_index := int((entry_variant as Dictionary).get("district_index", -1))
			if district_index >= 0 and not districts_to_check.has(district_index):
				districts_to_check.append(district_index)
		for district_variant in districts_to_check:
			if revealed >= reveal_count:
				break
			if _reveal_city_owner_by_intel_card(selected_player, int(district_variant), String(skill.get("name", "线索悬赏"))):
				revealed += 1
	var contract_traced := 0
	var contract_count := maxi(0, int(skill.get("trace_contract_count", 0)))
	if contract_count > 0:
		var contract_controller := _contract_runtime_controller_node()
		if contract_controller != null:
			contract_traced = contract_controller.trace_contract_parties(selected_player, selected_card_resolution_id, contract_count, String(skill.get("name", "线索悬赏")))
	if revealed > 0 or contract_traced > 0:
		_log("%s追加私有悬赏线索：城市%d条，合约%d条；答案不公开。" % [
			String(skill.get("name", "线索悬赏")),
			revealed,
			contract_traced,
		])
	return traced > 0 or revealed > 0 or contract_traced > 0


func _selected_city_owner_view_text() -> String:
	var city := _district_city(selected_district)
	if city.is_empty():
		return "未城市化"
	if not _city_is_active(city):
		return "城市废墟"
	var city_owner := int(city.get("owner", -1))
	if city_owner == selected_player:
		return "己方城市"
	var guesses: Dictionary = players[selected_player].get("city_guesses", {}) if selected_player >= 0 and selected_player < players.size() else {}
	var guess := int(guesses.get(selected_district, -1))
	return "归属待猜" if guess < 0 else "我的推测：玩家%d" % (guess + 1)


func _refresh_map_controls() -> void:
	var toolbar := full_map_overlay.find_child("PlanetMapControlToolbar", true, false) as Control if full_map_overlay != null and is_instance_valid(full_map_overlay) else null
	if toolbar != null and toolbar.has_method("set_controls"):
		toolbar.call("set_controls", _map_control_toolbar_snapshot())
	_refresh_fullscreen_map_hud()


func _refresh_fullscreen_map_hud() -> void:
	if fullscreen_map_hud_labels.is_empty():
		return
	var layer_label := fullscreen_map_hud_labels.get("layer", null) as Label
	if layer_label != null:
		var entry := _map_layer_entry(selected_map_layer_focus)
		layer_label.text = "图层:%s" % _map_layer_focus_label(selected_map_layer_focus)
		layer_label.tooltip_text = String(entry.get("tip", "当前全屏地图图层。"))
	var product_label := fullscreen_map_hud_labels.get("product", null) as Label
	if product_label != null:
		var product_text := selected_trade_product if selected_trade_product != "" else _default_trade_product_for_selected_district()
		product_label.text = "商品:%s" % (_short_card_text(product_text, 8) if product_text != "" else "未选")
		product_label.tooltip_text = "当前用于商路/商品读图的商品。"
	var district_label := fullscreen_map_hud_labels.get("district", null) as Label
	if district_label != null:
		district_label.text = "选区:%s" % _short_card_text(String(districts[selected_district].get("name", "未选")) if selected_district >= 0 and selected_district < districts.size() else "未选", 10)
		district_label.tooltip_text = _selected_district_status_text(selected_player) if selected_district >= 0 and selected_district < districts.size() else "当前未选择区域。"


func _city_markers_for_selected_player() -> Array:
	var result := []
	var guesses: Dictionary = players[selected_player].get("city_guesses", {}) if selected_player >= 0 and selected_player < players.size() else {}
	for i in range(districts.size()):
		var city := _district_city(i)
		if city.is_empty():
			continue
		var city_owner := int(city.get("owner", -1))
		var is_own := city_owner == selected_player
		var guess := int(guesses.get(i, -1))
		var tag := "己" if is_own else ("?" if guess < 0 else "猜%d" % (guess + 1))
		var tag_color := _player_color(city_owner) if is_own else (Color("#94a3b8") if guess < 0 else _player_color(guess))
		result.append({
			"district": i,
			"position": _district_center(i),
			"level": int(city.get("level", 1)),
			"active": bool(city.get("active", true)),
			"tag": tag,
			"tag_color": tag_color,
			"products": _city_product_names(city),
			"competition": int(city.get("competition_matches", 0)),
			"rise": 1.0,
		})
	return result

func _first_actionable_hand_slot(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return -1
	var player: Dictionary = players[player_index]
	var slots: Array = player.get("slots", [])
	for i in range(slots.size()):
		if not (slots[i] is Dictionary):
			continue
		var skill: Dictionary = slots[i]
		var state := _card_play_eligibility_snapshot(player_index, skill, "hand")
		if bool(state.get("actionable", false)):
			return i
	return -1


func _first_actionable_teachable_hand_slot(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return -1
	var player: Dictionary = players[player_index]
	var slots: Array = player.get("slots", [])
	for i in range(slots.size()):
		if not (slots[i] is Dictionary):
			continue
		var skill: Dictionary = slots[i]
		if not _first_run_skill_is_direct_teachable(player_index, skill):
			continue
		return i
	return -1


func _table_goal_primary_action(player_index: int, body: String) -> Dictionary:
	var empty := {
		"label": "看星球",
		"detail": "先点地图区域。",
		"accent": Color("#94a3b8"),
		"disabled": true,
		"target": Callable(),
	}
	if player_index < 0 or player_index >= players.size() or players.is_empty():
		return empty
	var player: Dictionary = players[player_index]
	if not _pending_discard_purchase_for_player(player_index).is_empty():
		return {
			"label": "处理弃牌",
			"detail": "右侧私密弃牌窗口完成后才能接收新牌。",
			"accent": Color("#f97316"),
			"disabled": true,
			"target": Callable(),
		}
	if _has_pending_target_choice() or _has_pending_player_target_choice():
		return {
			"label": "选目标",
			"detail": "在右侧目标窗口指定怪兽或玩家。",
			"accent": Color("#c084fc"),
			"disabled": true,
			"target": Callable(),
		}
	if selected_district < 0 or selected_district >= districts.size():
		return empty
	var starter_slot := _first_starter_monster_slot(player)
	if starter_slot >= 0:
		var starter_card: Dictionary = player["slots"][starter_slot]
		var can_summon := not _runtime_session_finished() \
			and selected_district >= 0 and selected_district < districts.size() and not bool(districts[selected_district].get("destroyed", false)) \
			and float(player.get("action_cooldown", 0.0)) <= 0.0 \
			and not bool(starter_card.get("queued_for_resolution", false)) \
			and _authorize_card_play(player_index, starter_card, false)
		return {
			"label": "可选：召唤怪兽",
			"detail": "起始怪兽牌已在手中；可随时召唤，不影响购牌、设施或经济行动。",
			"accent": Color("#fb7185"),
			"disabled": not can_summon,
			"target": Callable(self, "_use_skill").bind(starter_slot),
		}
	if _district_city(selected_district).is_empty():
		return {
			"label": "打开发展牌架",
			"detail": "v0.4 城市发展必须购买并打出绑定本地商品的城市发展牌。",
			"accent": Color("#22c55e"),
			"disabled": _runtime_session_finished(),
			"target": Callable(self, "_open_district_supply_from_map").bind(selected_district),
		}
	if body.contains("购牌") or body.contains("买牌") or body.contains("牌架") or _player_counted_hand_size(player) <= 0:
		return {
			"label": "打开牌架",
			"detail": "查看当前区域挂牌；显式选择或确认后锁定5秒资格与价格。",
			"accent": Color("#f59e0b"),
			"disabled": false,
			"target": Callable(self, "_open_district_supply_from_map").bind(selected_district),
		}
	var slot := _first_actionable_hand_slot(player_index)
	if slot >= 0:
		var skill: Dictionary = player.get("slots", [])[slot]
		return {
			"label": "打出%s" % _short_card_text(_card_display_name(String(skill.get("name", "卡牌"))), 6),
			"detail": "使用第一张当前可打手牌；需要目标的牌会先打开目标选择。",
			"accent": _card_presentation_color(skill),
			"disabled": false,
			"target": Callable(self, "_use_skill").bind(slot),
		}
	return {
		"label": "查看牌架",
		"detail": "当前没有可直接打出的牌；先看区域牌架补牌或换路线。",
		"accent": Color("#38bdf8"),
		"disabled": false,
		"target": Callable(self, "_open_district_supply_from_map").bind(selected_district),
	}


func _opening_guide_player_key(player_index: int) -> String:
	return str(player_index)


func _mark_opening_guide_economy_seen(player_index: int) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	opening_guide_economy_seen_players[_opening_guide_player_key(player_index)] = true


func _opening_guide_economy_seen(player_index: int) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	return bool(opening_guide_economy_seen_players.get(_opening_guide_player_key(player_index), false)) \
		or bool(opening_guide_economy_seen_players.get(player_index, false))


func _first_run_coach_player_key(player_index: int) -> String:
	return str(player_index)


func _mark_first_run_coach_district_seen(player_index: int) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	first_run_coach_district_seen_players[_first_run_coach_player_key(player_index)] = true


func _mark_first_run_coach_supply_seen(player_index: int) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	first_run_coach_supply_seen_players[_first_run_coach_player_key(player_index)] = true


func _mark_first_run_coach_public_track_seen(player_index: int) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	first_run_coach_public_track_seen_players[_first_run_coach_player_key(player_index)] = true


func _mark_first_run_coach_ai_public_action_seen(player_index: int) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	first_run_coach_ai_public_action_seen_players[_first_run_coach_player_key(player_index)] = true


func _mark_first_run_coach_monster_pressure_seen(player_index: int) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	first_run_coach_monster_pressure_seen_players[_first_run_coach_player_key(player_index)] = true


func _mark_first_run_coach_route_choice(player_index: int, route_id: String) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	var normalized := str(route_id).strip_edges()
	if normalized == "":
		normalized = "grow_gdp"
	first_run_coach_route_choice_players[_first_run_coach_player_key(player_index)] = normalized


func _first_run_coach_route_choice(player_index: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return ""
	return str(first_run_coach_route_choice_players.get(_first_run_coach_player_key(player_index), first_run_coach_route_choice_players.get(player_index, ""))).strip_edges()


func _mark_first_run_coach_clues_seen(player_index: int) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	first_run_coach_clues_seen_players[_first_run_coach_player_key(player_index)] = true


func _first_run_coach_seen(map: Dictionary, player_index: int) -> bool:
	return bool(map.get(_first_run_coach_player_key(player_index), false)) or bool(map.get(player_index, false))


func _first_run_recommended_setup() -> Dictionary:
	return {
		"player_count": FIRST_RUN_RECOMMENDED_PLAYER_COUNT,
		"ai_count": FIRST_RUN_RECOMMENDED_AI_COUNT,
		"role_indices": FIRST_RUN_RECOMMENDED_ROLE_INDICES.duplicate(true),
		"starter_monster_indices": FIRST_RUN_RECOMMENDED_STARTER_MONSTER_INDICES.duplicate(true),
		"label": "推荐首局：4席 / 3 AI / 简单角色 / 易读怪兽",
	}


func _apply_recommended_first_run_setup() -> void:
	configured_player_count = FIRST_RUN_RECOMMENDED_PLAYER_COUNT
	configured_ai_player_count = FIRST_RUN_RECOMMENDED_AI_COUNT
	configured_roguelike_depth = DEFAULT_ROGUELIKE_DEPTH
	configured_role_indices = FIRST_RUN_RECOMMENDED_ROLE_INDICES.duplicate(true)
	configured_starter_monster_indices = FIRST_RUN_RECOMMENDED_STARTER_MONSTER_INDICES.duplicate(true)
	_ensure_configured_ai_player_count()
	_ensure_configured_role_indices()
	_ensure_configured_starter_monster_indices()
	_log("已套用推荐首局设置：4席、3个AI、推荐角色、推荐起始怪兽。")
	_save_settings(false)
	_refresh_ui()


func _first_table_resolved_content_catalog() -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("first_table_resolve_content_catalog"):
		return {}
	var available_card_ids: Array = []
	var public_facility_cards: Array = []
	for card_name_variant in coordinator.call("card_catalog_ordered_ids"):
		var card_name := str(card_name_variant)
		monster_runtime_controller._append_unique_string(available_card_ids, card_name)
		var skill_variant: Variant = coordinator.call("card_definition", card_name)
		var skill: Dictionary = skill_variant if skill_variant is Dictionary else {}
		if str(skill.get("kind", "")) == "public_facility":
			public_facility_cards.append({
				"card_id": card_name,
				"rank": int(skill.get("rank", 1)),
				"facility_type": str(skill.get("facility_type", "")),
				"industry_id": str(skill.get("industry_id", "")),
			})
	var monster_ids: Array = []
	for roster_variant in MONSTER_ROSTER:
		if roster_variant is Dictionary:
			monster_runtime_controller._append_unique_string(monster_ids, str((roster_variant as Dictionary).get("name", "")))
	var product_ids: Array = []
	for product_variant in ProductMarketRuntimeController.PRODUCT_CATALOG:
		monster_runtime_controller._append_unique_string(product_ids, str(product_variant))
	var value: Variant = coordinator.call("first_table_resolve_content_catalog", {
		"card_ids": available_card_ids,
		"public_facility_cards": public_facility_cards,
		"monster_ids": monster_ids,
		"product_ids": product_ids,
	})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _first_table_followup_card_name() -> String:
	return str(_first_table_resolved_content_catalog().get("followup_card_id", "")).strip_edges()


func _first_table_teaching_product_for_district(district_index: int) -> String:
	if district_index < 0 or district_index >= districts.size():
		return ""
	var district: Dictionary = districts[district_index]
	var city_product_ids: Array = []
	var city := _district_city(district_index)
	if _city_is_active(city):
		for product_variant in _city_product_names(city):
			monster_runtime_controller._append_unique_string(city_product_ids, str(product_variant))
	var remote_demand_product_ids: Array = []
	for other_index in range(districts.size()):
		if other_index == district_index:
			continue
		for demand_variant in districts[other_index].get("demands", []):
			monster_runtime_controller._append_unique_string(remote_demand_product_ids, str(demand_variant))
	var coordinator := _game_runtime_coordinator_node()
	return str(coordinator.call("first_table_select_teaching_product", {
		"city_product_ids": city_product_ids,
		"district_product_ids": (district.get("products", []) as Array).duplicate(true) if district.get("products", []) is Array else [],
		"district_demand_ids": (district.get("demands", []) as Array).duplicate(true) if district.get("demands", []) is Array else [],
		"remote_demand_product_ids": remote_demand_product_ids,
	}, _first_table_resolved_content_catalog())) if coordinator != null and coordinator.has_method("first_table_select_teaching_product") else ""


func _first_table_player_city_district(player_index: int) -> int:
	if selected_district >= 0 and selected_district < districts.size() and not _region_infrastructure_owned_facilities(selected_district, player_index).is_empty():
		return selected_district
	for district_index in range(districts.size()):
		if not _region_infrastructure_owned_facilities(district_index, player_index).is_empty():
			return district_index
	return -1


func _first_table_public_clue_count() -> int:
	return _economy_city_public_clue_entries(32).size() + _economy_card_aftermath_entries(32).size() + _economy_monster_cash_clue_entries(32).size()


func _first_table_starter_monster_name(player_index: int, authored_monster_ids: Array = []) -> String:
	for actor_variant in monster_runtime_controller.auto_monsters:
		if actor_variant is Dictionary:
			var actor: Dictionary = actor_variant
			if int(actor.get("owner", -1)) == player_index and not bool(actor.get("down", false)):
				return str(actor.get("name", "怪兽"))
	var configured_index := int(configured_starter_monster_indices[player_index]) if player_index >= 0 and player_index < configured_starter_monster_indices.size() else -1
	if configured_index >= 0 and configured_index < MONSTER_ROSTER.size() and MONSTER_ROSTER[configured_index] is Dictionary:
		return str((MONSTER_ROSTER[configured_index] as Dictionary).get("name", "起始怪兽"))
	return str(authored_monster_ids[0]) if not authored_monster_ids.is_empty() else "起始怪兽"


func _first_table_visible_monster_name() -> String:
	for actor_variant in monster_runtime_controller.auto_monsters:
		if actor_variant is Dictionary and not bool((actor_variant as Dictionary).get("down", false)):
			return str((actor_variant as Dictionary).get("name", "怪兽"))
	return "怪兽"


func _first_table_runtime_content_snapshot(player_index: int) -> Dictionary:
	var resolved_catalog := _first_table_resolved_content_catalog()
	var district_index := _first_table_player_city_district(player_index)
	if district_index < 0:
		district_index = _first_run_recommended_start_district(player_index)
	var district_name := str(districts[district_index].get("name", "推荐区域")) if district_index >= 0 and district_index < districts.size() else "推荐区域"
	var facility_ids: Array = resolved_catalog.get("public_facility_card_ids", []) if resolved_catalog.get("public_facility_card_ids", []) is Array else []
	var teaching_card_id := str(facility_ids[0]) if not facility_ids.is_empty() else ""
	var teaching_skill: Dictionary = _game_runtime_coordinator_node().card_definition(teaching_card_id) if teaching_card_id != "" else {}
	var teaching_product := String(teaching_skill.get("product_id", ""))
	if teaching_product == "":
		teaching_product = _first_table_teaching_product_for_district(district_index)
	var city: Dictionary = _district_city(district_index) if district_index >= 0 and district_index < districts.size() else {}
	var infrastructure := _region_infrastructure_snapshot_for_district(district_index)
	var public_facilities: Array = infrastructure.get("facilities", []) if infrastructure.get("facilities", []) is Array else []
	var owned_facilities := _region_infrastructure_owned_facilities(district_index, player_index)
	var city_present := not owned_facilities.is_empty()
	var city_products: Array = []
	var city_demands: Array = []
	var gdp_per_minute := 0
	var cashflow_paid_total := 0
	if city_present:
		for product_variant in _city_product_names(city):
			city_products.append(str(product_variant))
		for demand_variant in _city_demand_names(city):
			city_demands.append(str(demand_variant))
		var region_id := str((districts[district_index] as Dictionary).get("region_id", "region.%03d" % district_index))
		var gdp_snapshot_variant: Variant = _commodity_flow_runtime_call("region_gdp_snapshot", [region_id])
		var gdp_snapshot: Dictionary = gdp_snapshot_variant if gdp_snapshot_variant is Dictionary else {}
		var by_player: Dictionary = gdp_snapshot.get("player_gdp_per_minute_cents_by_index", {}) if gdp_snapshot.get("player_gdp_per_minute_cents_by_index", {}) is Dictionary else {}
		gdp_per_minute = int(round(float(int(by_player.get(str(player_index), 0))) / 100.0))
		var player: Dictionary = players[player_index] if player_index >= 0 and player_index < players.size() and players[player_index] is Dictionary else {}
		for ledger_row_variant in player.get("v06_transaction_ledger", []):
			if ledger_row_variant is Dictionary and str((ledger_row_variant as Dictionary).get("category", "")) == "commodity_sale":
				cashflow_paid_total += maxi(0, int((ledger_row_variant as Dictionary).get("ledger_delta_cents", 0)))
	var starter_monster_ids: Array = resolved_catalog.get("starter_monster_ids", []) if resolved_catalog.get("starter_monster_ids", []) is Array else []
	var coordinator := _game_runtime_coordinator_node()
	var value: Variant = coordinator.call("first_table_compose_runtime_content", {
		"district_index": district_index,
		"district_name": district_name,
		"teaching_product_id": teaching_product,
		"teaching_card_id": teaching_card_id,
		"starter_monster_id": _first_table_starter_monster_name(player_index, starter_monster_ids),
		"city_present": city_present,
		"city_product_ids": city_products,
		"city_demand_ids": city_demands,
		"public_facilities": public_facilities,
		"owned_facilities": owned_facilities,
		"gdp_per_minute": gdp_per_minute,
		"cashflow_paid_total": cashflow_paid_total,
		"public_clue_count": _first_table_public_clue_count(),
		"ai_public_action_seen": _first_run_coach_seen(first_run_coach_ai_public_action_seen_players, player_index),
		"monster_pressure_seen": _first_run_coach_seen(first_run_coach_monster_pressure_seen_players, player_index),
		"monster_pressure_visible": not monster_runtime_controller.auto_monsters.is_empty(),
		"visible_monster_name": _first_table_visible_monster_name(),
		"route_choice": _first_run_coach_route_choice(player_index),
	}, resolved_catalog) if coordinator != null and coordinator.has_method("first_table_compose_runtime_content") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _first_table_district_content_score(_player_index: int, district_index: int) -> int:
	if district_index < 0 or district_index >= districts.size():
		return -1000000
	var district: Dictionary = districts[district_index]
	var remote_demand_product_ids: Array = []
	for other_index in range(districts.size()):
		if other_index == district_index:
			continue
		for demand_variant in districts[other_index].get("demands", []):
			monster_runtime_controller._append_unique_string(remote_demand_product_ids, str(demand_variant))
	var coordinator := _game_runtime_coordinator_node()
	return int(coordinator.call("first_table_score_district", {
		"build_allowed": not bool(district.get("destroyed", false)),
		"product_ids": (district.get("products", []) as Array).duplicate(true) if district.get("products", []) is Array else [],
		"demand_ids": (district.get("demands", []) as Array).duplicate(true) if district.get("demands", []) is Array else [],
		"transport_score": float(district.get("transport_score", 1.0)),
		"remote_demand_product_ids": remote_demand_product_ids,
	}, _first_table_resolved_content_catalog())) if coordinator != null and coordinator.has_method("first_table_score_district") else -1000000


func _first_table_has_public_ai_economy_presence() -> bool:
	for district_index in range(districts.size()):
		for facility_variant in _region_infrastructure_snapshot_for_district(district_index).get("facilities", []):
			if facility_variant is Dictionary and str((facility_variant as Dictionary).get("owner_kind", "")) == "player" and _player_is_ai(int((facility_variant as Dictionary).get("owner_player_index", -1))):
				return true
	return false


func _ensure_first_table_public_ai_city_clue() -> bool:
	for district_index in range(districts.size()):
		var ai_presence := false
		var facility_labels: Array = []
		for facility_variant in _region_infrastructure_snapshot_for_district(district_index).get("facilities", []):
			if not (facility_variant is Dictionary):
				continue
			var facility: Dictionary = facility_variant
			facility_labels.append("%s%s" % [str(facility.get("industry_id", "通用")), str(facility.get("facility_type", "设施"))])
			if str(facility.get("owner_kind", "")) == "player" and _player_is_ai(int(facility.get("owner_player_index", -1))):
				ai_presence = true
		if not ai_presence:
			continue
		var district_name := str(districts[district_index].get("name", "区域"))
		var facility_summary := "、".join(facility_labels) if not facility_labels.is_empty() else "公共设施"
		_set_city_public_clue(district_index, "匿名建设：%s出现%s；设施产权按公开状态显示。" % [district_name, facility_summary])
		return true
	return false


func _ensure_first_table_ai_public_action() -> bool:
	if _active_runtime_scenario_id() != "first_table":
		return _first_table_public_clue_count() > 0
	for entry_variant in resolved_card_history:
		if entry_variant is Dictionary:
			var entry: Dictionary = entry_variant
			var player_index := int(entry.get("player_index", -1))
			if player_index >= 0 and player_index < players.size() and _player_is_ai(player_index) and _opening_guide_card_entry_counts(entry):
				return true
	if _first_table_has_public_ai_economy_presence():
		return _ensure_first_table_public_ai_city_clue()
	var clue_count_before := _first_table_public_clue_count()
	var acted := int(_ai_runtime_call("_auto_rival_business_actions", [true]))
	if _first_table_has_public_ai_economy_presence():
		_ensure_first_table_public_ai_city_clue()
	var resolved_ai_card := false
	for entry_variant in resolved_card_history:
		if entry_variant is Dictionary:
			var entry: Dictionary = entry_variant
			var player_index := int(entry.get("player_index", -1))
			if player_index >= 0 and player_index < players.size() and _player_is_ai(player_index) and _opening_guide_card_entry_counts(entry):
				resolved_ai_card = true
				break
	return acted > 0 or resolved_ai_card or _first_table_public_clue_count() > clue_count_before or _first_table_has_public_ai_economy_presence()


func _first_run_recommended_start_district(player_index: int) -> int:
	if districts.is_empty():
		return -1
	if player_index < 0 or player_index >= players.size():
		player_index = 0
	var keep_selected := _active_runtime_scenario_id() != "first_table" or _first_run_coach_seen(first_run_coach_district_seen_players, player_index)
	if keep_selected and selected_district >= 0 \
			and selected_district < districts.size() \
			and not bool(districts[selected_district].get("destroyed", false)):
		return selected_district
	var first_alive := -1
	var best_authored_district := -1
	var best_authored_score := -1000000
	for i in range(districts.size()):
		var district: Dictionary = districts[i]
		if bool(district.get("destroyed", false)):
			continue
		if first_alive < 0:
			first_alive = i
		if _active_runtime_scenario_id() == "first_table":
			var authored_score := _first_table_district_content_score(player_index, i)
			if authored_score > best_authored_score:
				best_authored_score = authored_score
				best_authored_district = i
		else:
			return i
	if best_authored_district >= 0:
		return best_authored_district
	return first_alive


func _first_run_coach_progress(player_index: int) -> Dictionary:
	var progress := _opening_guide_progress(player_index)
	if progress.is_empty():
		return {}
	progress["selected_district"] = _first_run_coach_seen(first_run_coach_district_seen_players, player_index)
	progress["has_opened_supply"] = _first_run_coach_seen(first_run_coach_supply_seen_players, player_index) \
		or (district_supply_open_player == player_index and district_supply_open_district >= 0) \
		or bool(progress.get("has_bought_card", false))
	progress["has_seen_public_track"] = _first_run_coach_seen(first_run_coach_public_track_seen_players, player_index) \
		or selected_card_resolution_id >= 0
	progress["has_seen_ai_public_action"] = _first_run_coach_seen(first_run_coach_ai_public_action_seen_players, player_index)
	progress["has_seen_monster_pressure"] = _first_run_coach_seen(first_run_coach_monster_pressure_seen_players, player_index)
	var route_choice := _first_run_coach_route_choice(player_index)
	progress["has_chosen_route"] = route_choice != ""
	progress["route_choice"] = route_choice
	progress["has_seen_clues"] = _first_run_coach_seen(first_run_coach_clues_seen_players, player_index)
	return progress


func _runtime_first_run_coach_snapshot_source(player_index: int) -> Dictionary:
	if _runtime_campaign_focus_mode():
		return {}
	player_index = _first_run_coach_player_index()
	if player_index < 0 or player_index >= players.size() or _runtime_session_finished():
		return {}
	var progress := _first_run_coach_progress(player_index)
	var stage := _first_run_coach_stage(progress)
	var primary_action := _runtime_first_run_coach_primary_action(player_index, progress)
	var source := {
		"visible": not opening_guide_dismissed,
		"dismissed": opening_guide_dismissed,
		"stage": stage,
		"progress": progress,
		"primary_action": primary_action,
		"recommended_setup": _first_run_recommended_setup(),
		"auto_fold_after_route_choice": false,
	}
	if stage == "choose_route":
		source["chips"] = _first_run_coach_route_choice_chips()
	if _first_run_coach_strong_focus_active(player_index):
		source.merge(_first_run_coach_strong_focus_copy(stage, first_run_coach_strong_focus_action_id), true)
	return source


func _first_run_coach_route_choice_chips() -> Array:
	return [
		{"text": "扩GDP", "tooltip": "优先强化城市收入、商品供需和商路。", "accent": Color("#4ade80")},
		{"text": "护商路", "tooltip": "优先保护高收入城市、修复路线和降低风险。", "accent": Color("#38bdf8")},
		{"text": "压竞争", "tooltip": "优先读公开线索，攻击疑似竞争城市。", "accent": Color("#fb7185")},
	]


func _first_run_coach_player_index() -> int:
	for i in range(players.size()):
		if not _player_is_ai(i) and not _player_is_eliminated(i):
			return i
	if selected_player >= 0 and selected_player < players.size() and not _player_is_eliminated(selected_player):
		return selected_player
	return 0 if not players.is_empty() else -1


func _first_run_coach_strong_focus_active(player_index: int) -> bool:
	if first_run_coach_strong_focus_until_seconds <= 0.0:
		return false
	if first_run_coach_strong_focus_player_index != player_index:
		return false
	return game_time <= first_run_coach_strong_focus_until_seconds


func _arm_first_run_coach_strong_focus(player_index: int, action_id: String) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	first_run_coach_strong_focus_player_index = player_index
	first_run_coach_strong_focus_action_id = action_id
	first_run_coach_strong_focus_until_seconds = game_time + 5.0


func _finish_first_run_coach_action_feedback(player_index: int, action_id: String) -> void:
	_arm_first_run_coach_strong_focus(player_index, action_id)
	_refresh_ui()


func _open_first_run_coach_district_supply(district_index: int, player_index: int) -> void:
	if district_index < 0 or district_index >= districts.size() or player_index < 0 or player_index >= players.size():
		return
	selected_player = player_index
	_open_district_supply_from_map(district_index)
	selected_player = player_index
	district_supply_open_district = district_index
	district_supply_open_player = player_index
	if district_supply_overlay != null:
		district_supply_overlay.visible = true
	_open_district_card_purchase_window(district_index, player_index)


func _first_table_accessible_land_district(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return -1
	if selected_district >= 0 and selected_district < districts.size() \
			and String(districts[selected_district].get("terrain", "land")) == "land" \
			and _district_market_currently_purchasable(selected_district):
		return selected_district
	for district_index in range(districts.size()):
		if bool(districts[district_index].get("destroyed", false)) or String(districts[district_index].get("terrain", "land")) != "land":
			continue
		if _district_market_currently_purchasable(district_index):
			return district_index
	return -1


func _first_table_followup_hand_slot(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return -1
	var followup_card_name := _first_table_followup_card_name()
	if followup_card_name == "":
		return -1
	var slots: Array = (players[player_index] as Dictionary).get("slots", []) as Array
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var skill: Dictionary = slots[slot_index] as Dictionary
		if _game_runtime_coordinator_node().card_family_id(String(skill.get("name", ""))) != _game_runtime_coordinator_node().card_family_id(followup_card_name):
			continue
		if bool(_card_play_eligibility_snapshot(player_index, skill, "hand").get("actionable", false)):
			return slot_index
	return -1


func _inject_first_table_followup_card_supply(district_index: int) -> bool:
	var followup_card_name := _first_table_followup_card_name()
	if district_index < 0 or district_index >= districts.size() or followup_card_name == "" or not _game_runtime_coordinator_node().card_exists(followup_card_name):
		return false
	var choices: Array = districts[district_index].get("card_choices", []) as Array
	if choices.has(followup_card_name):
		_set_district_card_source(district_index, followup_card_name, FIRST_TABLE_FOLLOWUP_CARD_SOURCE)
		return true
	if choices.size() >= DISTRICT_CARD_CHOICE_MAX:
		var replace_index := _last_non_monster_supply_choice_index(choices)
		if replace_index < 0:
			return false
		var removed_name := String(choices[replace_index])
		var sources: Dictionary = districts[district_index].get("card_sources", {}) as Dictionary
		sources.erase(removed_name)
		choices[replace_index] = followup_card_name
		districts[district_index]["card_sources"] = sources
	else:
		choices.append(followup_card_name)
	districts[district_index]["card_choices"] = choices
	_set_district_card_source(district_index, followup_card_name, FIRST_TABLE_FOLLOWUP_CARD_SOURCE)
	return true


func _buy_first_table_followup_card(player_index: int) -> bool:
	var followup_card_name := _first_table_followup_card_name()
	if followup_card_name == "":
		return false
	var district_index := _first_table_player_city_district(player_index)
	if district_index < 0 or not _district_market_currently_purchasable(district_index):
		district_index = _first_table_accessible_land_district(player_index)
	if district_index < 0 or not _inject_first_table_followup_card_supply(district_index):
		return false
	_jump_to_district_on_table(district_index)
	_open_first_run_coach_district_supply(district_index, player_index)
	selected_market_skill = followup_card_name
	previewed_district_card = followup_card_name
	_claim_district_card(followup_card_name)
	if pending_discard_purchase.is_empty() and _district_supply_is_open():
		_close_district_supply_overlay()
	return true


func _first_run_coach_strong_focus_copy(stage: String, action_id: String = "") -> Dictionary:
	var copy := {
		"stuck_state": "strong",
		"pulse_focus": true,
	}
	match action_id:
		"coach_select_district":
			copy["focus_target"] = "planet"
			copy["shortest_action_text"] = "打开区域牌架，查看受光挂牌。"
		"coach_open_rack":
			copy["focus_target"] = "district_supply"
			copy["shortest_action_text"] = "看牌架，读卡或买牌。"
		"coach_buy_card":
			copy["focus_target"] = "player_hand"
			copy["shortest_action_text"] = "看手牌，准备出牌。"
		"coach_play_card":
			copy["focus_target"] = "public_track"
			copy["shortest_action_text"] = "看牌轨，读公开线索。"
		"coach_inspect_track":
			copy["focus_target"] = "public_track"
			copy["shortest_action_text"] = "看牌轨，双击看详情。"
		"coach_check_economy":
			copy["focus_target"] = "economy_overview"
			copy["shortest_action_text"] = "看经济，理解钱从哪里来。"
		"coach_observe_ai_public_action":
			copy["focus_target"] = "public_track"
			copy["shortest_action_text"] = "看公开结果，不猜私有计划。"
		"coach_inspect_monster_pressure":
			copy["focus_target"] = "planet"
			copy["shortest_action_text"] = "看怪兽轨迹和受压目标。"
		"coach_choose_route_growth":
			copy["focus_target"] = "action_dock"
			copy["shortest_action_text"] = "先走扩GDP路线。"
		"coach_inspect_clues":
			copy["focus_target"] = "right_inspector"
			copy["shortest_action_text"] = "看右侧，整理线索。"
	match stage:
		"select_district":
			copy["title"] = "看中央星球"
			copy["body"] = "按确认选区。"
			copy["tooltip"] = "最短操作：看中央星球，确认一个可建城区域。"
		"build_city":
			copy["title"] = "看星球区域"
			copy["body"] = "打开发展牌架。"
			copy["tooltip"] = "v0.4 不允许直接建城；购买并打出绑定商品项目的城市发展牌。"
		"open_rack":
			copy["title"] = "看星球区域"
			copy["body"] = "打开牌架。"
			copy["tooltip"] = "最短操作：打开当前区域牌架；不能买也能先看。"
		"buy_card":
			copy["title"] = "看区域牌架"
			copy["body"] = "买一张可购买牌。"
			copy["tooltip"] = "最短操作：在牌架里买一张可购买牌。"
		"play_card":
			copy["title"] = "看手牌"
			copy["body"] = "打出可用手牌。"
			copy["tooltip"] = "最短操作：选一张可用手牌；需要目标会再询问。"
		"inspect_track":
			copy["title"] = "看顶部牌轨"
			copy["body"] = "读公开线索。"
			copy["tooltip"] = "最短操作：看顶部公共时间线。"
		"check_economy":
			copy["title"] = "看经济总览"
			copy["body"] = "理解钱源。"
			copy["tooltip"] = "最短操作：打开经济总览，看GDP、商品和商路。"
		"observe_ai_public_action":
			copy["title"] = "看AI公开行动"
			copy["body"] = "读目标和结果。"
			copy["tooltip"] = "最短操作：观察公开行动，只读取桌面证据。"
		"inspect_monster_pressure":
			copy["title"] = "看怪兽压力"
			copy["body"] = "读移动和受压目标。"
			copy["tooltip"] = "最短操作：切到地图怪兽层，看轨迹、目标与商路压力。"
		"choose_route":
			copy["title"] = "选继续路线"
			copy["body"] = "扩GDP、护商路、压竞争。"
			copy["tooltip"] = "最短操作：先选一条能理解的路线继续玩。"
		"inspect_clues":
			copy["title"] = "看右侧线索"
			copy["body"] = "打开线索档案。"
			copy["tooltip"] = "最短操作：从右侧详情进入线索档案。"
		_:
			copy["title"] = "继续牌桌"
			copy["body"] = "围绕现金流和线索行动。"
			copy["tooltip"] = "首轮路径已完成，继续做赚钱或压制决策。"
	match action_id:
		"coach_select_district":
			copy["title"] = "看星球区域"
			copy["body"] = "打开真实牌架。"
			copy["tooltip"] = "最短操作：打开区域牌架；挂牌来源受光时可确认购买。"
		"coach_open_rack":
			copy["title"] = "看区域牌架"
			copy["body"] = "读卡或买牌。"
			copy["tooltip"] = "最短操作：牌架已打开，先看用途，再买一张可购买牌。"
		"coach_buy_card":
			copy["title"] = "看手牌"
			copy["body"] = "准备出牌。"
			copy["tooltip"] = "最短操作：新牌已进入手牌，hover 看用途后打出可用牌。"
		"coach_play_card":
			copy["title"] = "看顶部牌轨"
			copy["body"] = "读公开线索。"
			copy["tooltip"] = "最短操作：牌已进公共时间线，看它留下什么线索。"
		"coach_inspect_track":
			copy["title"] = "看顶部牌轨"
			copy["body"] = "双击看详情。"
			copy["tooltip"] = "最短操作：在牌轨上双击卡牌，查看详情和猜测入口。"
		"coach_check_economy":
			copy["title"] = "看经济总览"
			copy["body"] = "看GDP来源。"
			copy["tooltip"] = "最短操作：打开经济总览，确认城市、商品和商路如何变成钱。"
		"coach_observe_ai_public_action":
			copy["title"] = "AI已行动"
			copy["body"] = "读公开结果。"
			copy["tooltip"] = "最短操作：查看公开牌轨、地图 callout 或城市线索，不读取AI策略评分。"
		"coach_inspect_monster_pressure":
			copy["title"] = "怪兽压力"
			copy["body"] = "看它威胁什么。"
			copy["tooltip"] = "最短操作：看地图怪兽层、移动轨迹和受压城市/商路。"
		"coach_choose_route_growth":
			copy["title"] = "路线已选"
			copy["body"] = "先扩GDP。"
			copy["tooltip"] = "最短操作：回到牌桌，围绕城市收入、商品和商路继续行动。"
		"coach_inspect_clues":
			copy["title"] = "看右侧线索"
			copy["body"] = "整理嫌疑。"
			copy["tooltip"] = "最短操作：查看线索档案，只整理公开事实和你的推理。"
	return copy


func _runtime_first_run_coach_primary_action(player_index: int, progress: Dictionary) -> Dictionary:
	if progress.is_empty():
		return {"id": "", "label": "选择席位", "disabled": true, "tooltip": "先选择有效席位。"}
	var stage := _first_run_coach_stage(progress)
	match stage:
		"select_district":
			var recommended_district := _first_run_recommended_start_district(player_index)
			var recommended_name := String(districts[recommended_district].get("name", "区域")) if recommended_district >= 0 and recommended_district < districts.size() else "可用区域"
			return {
				"id": "coach_select_district",
				"label": "确认选区",
				"disabled": recommended_district < 0,
				"tooltip": "把地图焦点放到%s；右侧会显示能否建城、牌架和商品线索。" % recommended_name,
				"accent": Color("#38bdf8"),
			}
		"build_city":
			return {
				"id": "coach_open_rack",
				"label": "打开发展牌架",
				"disabled": selected_district < 0 or selected_district >= districts.size(),
				"tooltip": "v0.4 城市发展必须从真实发展牌进入，并绑定商品项目。",
				"accent": Color("#4ade80"),
			}
		"open_rack":
			return {
				"id": "coach_open_rack",
				"label": "查看牌架",
				"disabled": selected_district < 0 or selected_district >= districts.size(),
				"tooltip": "打开当前区域牌架；不能购买时也能先查看卡牌。",
				"accent": Color("#facc15"),
			}
		"buy_card":
			var buyable_district := _first_teachable_buyable_district_for_player(player_index)
			var buyable_card := _first_teachable_buyable_district_card(buyable_district, player_index)
			var fallback_district := _first_buyable_district_for_player(player_index)
			var fallback_card := _first_run_teaching_card_name()
			var can_prepare_teaching_card := buyable_card != "" or (fallback_district >= 0 and fallback_card != "")
			return {
				"id": "coach_buy_card",
				"label": "买第一牌",
				"disabled": not can_prepare_teaching_card,
				"tooltip": _first_run_buy_card_tooltip(buyable_district if buyable_card != "" else fallback_district, buyable_card if buyable_card != "" else fallback_card),
				"accent": Color("#fde68a"),
			}
		"play_card":
			var slot := _first_actionable_teachable_hand_slot(player_index)
			return {
				"id": "coach_play_card",
				"label": "打出手牌",
				"disabled": slot < 0,
				"tooltip": "打出当前可用手牌；需要目标的牌会先打开目标选择。",
				"accent": Color("#c084fc"),
			}
		"inspect_track":
			var track_id := _first_public_track_resolution_id()
			return {
				"id": "coach_inspect_track",
				"label": "看牌轨",
				"disabled": track_id < 0,
				"tooltip": "聚焦顶部公开牌轨，确认匿名牌如何展示和留下线索。",
				"accent": Color("#f59e0b"),
			}
		"check_economy":
			return {
				"id": "coach_check_economy",
				"label": "看经济",
				"disabled": false,
				"tooltip": "打开经济总览，确认GDP、商品、商路和城市收入如何变成钱。",
				"accent": Color("#4ade80"),
			}
		"observe_ai_public_action":
			return {
				"id": "coach_observe_ai_public_action",
				"label": "观察AI行动",
				"disabled": players.size() <= 1,
				"tooltip": "让现有AI执行一次合法公开经济行动；只展示目标、结果与线索，不展示策略评分或真实操作者。",
				"accent": Color("#f59e0b"),
			}
		"inspect_monster_pressure":
			return {
				"id": "coach_inspect_monster_pressure",
				"label": "看怪兽压力",
				"disabled": monster_runtime_controller.auto_monsters.is_empty(),
				"tooltip": "聚焦地图怪兽层，读取真实自动行动留下的移动、目标、商路或城市压力。",
				"accent": Color("#fb7185"),
			}
		"buy_development":
			var development_district := _first_teachable_buyable_district_for_player(player_index)
			var development_card := _first_teachable_buyable_district_card(development_district, player_index) if development_district >= 0 else ""
			return {
				"id": "coach_buy_card",
				"label": "购买设施牌",
				"disabled": development_card == "",
				"tooltip": "从可达牌架购买一张已迁移的 v0.6 公共设施牌。" if development_card != "" else "当前目录没有可购买的 v0.6 公共设施牌。",
				"accent": Color("#fde68a"),
			}
		"play_development":
			var development_slot := _first_actionable_teachable_hand_slot(player_index)
			return {
				"id": "coach_play_card",
				"label": "打出设施牌",
				"disabled": development_slot < 0,
				"tooltip": "把公共设施牌提交到公开结算轨；设施类型、产业和目标区域公开。",
				"accent": Color("#c084fc"),
			}
		"establish_project":
			return {
				"id": "coach_inspect_track",
				"label": "查看项目结算",
				"disabled": _first_public_track_resolution_id() < 0,
				"tooltip": "查看发展牌的公开展示进度；项目结算后会自动进入下一步。",
				"accent": Color("#f59e0b"),
			}
		"buy_followup":
			return {
				"id": "coach_buy_followup_card",
				"label": "购买经营牌",
				"disabled": _first_table_player_city_district(player_index) < 0,
				"tooltip": "购买%s，用真实项目继续强化城市收入。" % _card_display_name(_first_table_followup_card_name()),
				"accent": Color("#fde68a"),
			}
		"play_followup":
			var followup_slot := _first_table_followup_hand_slot(player_index)
			return {
				"id": "coach_play_followup_card",
				"label": "打出经营牌",
				"disabled": followup_slot < 0,
				"tooltip": "打出%s，让现有项目进入第二次公开卡牌结算。" % _card_display_name(_first_table_followup_card_name()),
				"accent": Color("#c084fc"),
			}
		"choose_route":
			return {
				"id": "coach_choose_route_growth",
				"label": "走扩GDP",
				"disabled": false,
				"tooltip": "首局推荐先围绕城市收入、商品供需和商路扩张；旁边短签给出其他可读路线。",
				"accent": Color("#22c55e"),
			}
		"inspect_clues":
			return {
				"id": "coach_inspect_clues",
				"label": "看线索",
				"disabled": false,
				"tooltip": "打开线索档案，查看公开证据和自己的推测入口。",
				"accent": Color("#93c5fd"),
			}
	return {"id": "", "label": "已完成", "disabled": true, "tooltip": "首轮引导已折叠。", "accent": Color("#22c55e")}


func _first_run_coach_stage(progress: Dictionary) -> String:
	if _active_runtime_scenario_id() == "first_table":
		var completed_signals: Dictionary = _runtime_scenario_state().get("completed_signals", {})
		var signal_order := [
			["district_selected", "select_district"],
			["rack_opened", "open_rack"],
			["card_bought", "buy_development"],
			["card_played", "play_development"],
			["public_facility_committed", "establish_project"],
			["economy_checked", "check_economy"],
			["followup_card_bought", "buy_followup"],
			["followup_card_played", "play_followup"],
			["track_selected", "inspect_track"],
			["ai_public_action_observed", "observe_ai_public_action"],
			["public_clue_read", "inspect_clues"],
			["monster_pressure_observed", "inspect_monster_pressure"],
			["route_chosen", "choose_route"],
		]
		for step_variant in signal_order:
			var step: Array = step_variant as Array
			if not bool(completed_signals.get(String(step[0]), false)):
				return String(step[1])
		return "done"
	if bool(progress.get("has_played_card", false)) \
			and bool(progress.get("has_seen_public_track", false)) \
			and bool(progress.get("has_checked_economy", false)) \
			and bool(progress.get("has_seen_ai_public_action", false)) \
			and bool(progress.get("has_seen_clues", false)) \
			and bool(progress.get("has_seen_monster_pressure", false)) \
			and bool(progress.get("has_chosen_route", false)):
		return "done"
	if not bool(progress.get("selected_district", false)):
		return "select_district"
	if not bool(progress.get("has_opened_supply", false)):
		return "open_rack"
	if not bool(progress.get("has_bought_card", false)):
		return "buy_card"
	if not bool(progress.get("has_played_card", false)):
		return "play_card"
	if not bool(progress.get("has_seen_public_track", false)):
		return "inspect_track"
	if not bool(progress.get("has_checked_economy", false)):
		return "check_economy"
	if not bool(progress.get("has_seen_ai_public_action", false)):
		return "observe_ai_public_action"
	if not bool(progress.get("has_seen_clues", false)):
		return "inspect_clues"
	if not bool(progress.get("has_seen_monster_pressure", false)):
		return "inspect_monster_pressure"
	if not bool(progress.get("has_chosen_route", false)):
		return "choose_route"
	return "done"


func _activate_first_run_coach_action(action_id: String) -> bool:
	var player_index := _first_run_coach_player_index()
	if player_index < 0 or player_index >= players.size():
		return false
	match action_id:
		"coach_select_district":
			var recommended_district := _first_run_recommended_start_district(player_index)
			if recommended_district >= 0:
				_jump_to_district_on_table(recommended_district)
			elif selected_district < 0 or selected_district >= districts.size():
				selected_district = 0 if not districts.is_empty() else -1
				if selected_district >= 0:
					_jump_to_district_on_table(selected_district)
			_mark_first_run_coach_district_seen(player_index)
			_sync_selected_district_card()
			_load_selected_district_guess()
			if selected_district >= 0 and selected_district < districts.size():
				_complete_scenario_signal("district_selected", "选择推荐区域：%s；商品与建城条件来自真实地图数据。" % str(districts[selected_district].get("name", "区域")), "after_select", "planet")
			_finish_first_run_coach_action_feedback(player_index, action_id)
			return true
		"coach_open_rack":
			if not _ensure_first_run_coach_action_district(player_index):
				return false
			if selected_district < 0 or selected_district >= districts.size():
				return false
			_open_first_run_coach_district_supply(selected_district, player_index)
			_finish_first_run_coach_action_feedback(player_index, action_id)
			return true
		"coach_buy_card":
			var starting_district := selected_district
			var accessible_district := _first_card_accessible_district_for_player(player_index)
			if accessible_district < 0:
				if not _ensure_first_run_coach_action_district(player_index):
					return false
				accessible_district = _first_card_accessible_district_for_player(player_index)
			var recovered_to_accessible_rack := accessible_district >= 0 and accessible_district != starting_district
			if accessible_district >= 0 and accessible_district != selected_district:
				_jump_to_district_on_table(accessible_district)
			if accessible_district < 0:
				return false
			var prepared_teaching_district := _ensure_first_run_teaching_card_supply(player_index)
			var target_buy_district := selected_district
			if _first_teachable_buyable_district_card(target_buy_district, player_index) == "":
				target_buy_district = _first_teachable_buyable_district_for_player(player_index)
				if target_buy_district < 0:
					target_buy_district = prepared_teaching_district
				if target_buy_district >= 0:
					_jump_to_district_on_table(target_buy_district)
			if selected_district < 0 or selected_district >= districts.size():
				return false
			selected_player = player_index
			if not _district_supply_is_open() or district_supply_open_district != selected_district:
				_open_first_run_coach_district_supply(selected_district, player_index)
			if recovered_to_accessible_rack:
				_finish_first_run_coach_action_feedback(player_index, "coach_open_rack")
				return true
			var buyable_card := _first_teachable_buyable_district_card(selected_district, player_index)
			if buyable_card == "":
				_log("首局买牌：当前没有受光挂牌；牌架仍可查看，等待自转或选择其他来源区。")
				_finish_first_run_coach_action_feedback(player_index, action_id)
				return true
			selected_market_skill = buyable_card
			previewed_district_card = buyable_card
			_claim_district_card(buyable_card)
			if pending_discard_purchase.is_empty() and _district_supply_is_open():
				_close_district_supply_overlay()
			_finish_first_run_coach_action_feedback(player_index, action_id)
			return true
		"coach_play_card":
			selected_player = player_index
			if pending_discard_purchase.is_empty() and _district_supply_is_open():
				_close_district_supply_overlay()
			if _first_actionable_teachable_hand_slot(player_index) < 0:
				_ensure_first_run_teachable_hand_card(player_index)
			var slot_index := _first_actionable_teachable_hand_slot(player_index)
			if slot_index < 0:
				return false
			selected_runtime_card_slot = slot_index
			_use_skill(slot_index)
			var play_handled := _player_has_committed_or_resolved_card(player_index)
			if play_handled:
				_finish_first_run_coach_action_feedback(player_index, action_id)
			return play_handled
		"coach_buy_followup_card":
			var followup_bought := _buy_first_table_followup_card(player_index)
			if followup_bought:
				_finish_first_run_coach_action_feedback(player_index, action_id)
			return followup_bought
		"coach_play_followup_card":
			selected_player = player_index
			if pending_discard_purchase.is_empty() and _district_supply_is_open():
				_close_district_supply_overlay()
			var project_district := _first_table_player_city_district(player_index)
			if project_district >= 0:
				_jump_to_district_on_table(project_district)
			var followup_slot := _first_table_followup_hand_slot(player_index)
			if followup_slot < 0:
				return false
			selected_runtime_card_slot = followup_slot
			_use_skill(followup_slot)
			var followup_played := _player_has_committed_or_resolved_card(player_index)
			if followup_played:
				_finish_first_run_coach_action_feedback(player_index, action_id)
			return followup_played
		"coach_inspect_track":
			var resolution_id := _first_public_track_resolution_id()
			if resolution_id < 0:
				return false
			selected_runtime_card_slot = -1
			_select_card_resolution_track_entry(resolution_id)
			_mark_first_run_coach_public_track_seen(player_index)
			_finish_first_run_coach_action_feedback(player_index, action_id)
			return true
		"coach_check_economy":
			selected_player = player_index
			_open_economy_overview_menu()
			_complete_scenario_signal("economy_checked", "查看经济总览：确认城市GDP、商品供需、商路与实时现金流。", "after_economy", "economy_overview")
			_finish_first_run_coach_action_feedback(player_index, action_id)
			return true
		"coach_observe_ai_public_action":
			selected_player = player_index
			if not _ensure_first_table_ai_public_action():
				_log("首局任务：AI当前没有合法的公开经济行动；等待城市与商品条件形成。")
				return false
			_mark_first_run_coach_ai_public_action_seen(player_index)
			_complete_scenario_signal("ai_public_action_observed", "观察AI公开行动：目标与结果可见，真实操作者和策略评分保持隐藏。", "after_ai_action", "public_track")
			_finish_first_run_coach_action_feedback(player_index, action_id)
			return true
		"coach_choose_route_growth":
			selected_player = player_index
			_mark_first_run_coach_route_choice(player_index, "grow_gdp")
			_complete_scenario_signal("route_chosen", "选择首局路线：继续扩张GDP，同时保留对怪兽与公开线索的观察。", "complete", "action_dock")
			_close_menu()
			_finish_first_run_coach_action_feedback(player_index, action_id)
			return true
		"coach_inspect_clues":
			if _first_table_public_clue_count() <= 0:
				_ensure_first_table_ai_public_action()
			_mark_first_run_coach_clues_seen(player_index)
			_open_intel_dossier_menu()
			_complete_scenario_signal("public_clue_read", "读取公开线索：商品、目标与结果可见，归属判断保持非强制。", "after_clue", "intel_dossier")
			_finish_first_run_coach_action_feedback(player_index, action_id)
			return true
		"coach_inspect_monster_pressure":
			if monster_runtime_controller.auto_monsters.is_empty():
				return false
			var monster_slot := monster_runtime_controller._valid_auto_monster_slot(monster_runtime_controller.selected_auto_monster_slot)
			if monster_slot >= 0:
				monster_runtime_controller.select_slot(monster_slot)
				var actor: Dictionary = monster_runtime_controller.auto_monsters[monster_slot]
				var district_index := int(actor.get("position", selected_district))
				if district_index >= 0 and district_index < districts.size():
					_jump_to_district_on_table(district_index)
			_set_map_layer_focus("monster")
			_mark_first_run_coach_monster_pressure_seen(player_index)
			_complete_scenario_signal("monster_pressure_observed", "观察怪兽压力：移动、目标和受压结果公开，怪兽归属仍需从线索判断。", "after_monster_pressure", "planet")
			_finish_first_run_coach_action_feedback(player_index, action_id)
			return true
	return false


func _ensure_first_run_coach_action_district(player_index: int) -> bool:
	if selected_district >= 0 and selected_district < districts.size() and not bool(districts[selected_district].get("destroyed", false)):
		return true
	var recommended_district := _first_run_recommended_start_district(player_index)
	if recommended_district < 0 or recommended_district >= districts.size():
		return false
	_jump_to_district_on_table(recommended_district)
	_mark_first_run_coach_district_seen(player_index)
	_sync_selected_district_card()
	_load_selected_district_guess()
	return true


func _first_buyable_district_card(district_index: int, player_index: int) -> String:
	if district_index < 0 or district_index >= districts.size() or player_index < 0 or player_index >= players.size():
		return ""
	var choices: Array = districts[district_index].get("card_choices", [])
	for card_variant in choices:
		var card_name := String(card_variant)
		var state := _district_supply_purchase_state(district_index, card_name, player_index)
		if bool(state.get("actionable", false)):
			return card_name
	return ""


func _first_teachable_buyable_district_card(district_index: int, player_index: int) -> String:
	if district_index < 0 or district_index >= districts.size() or player_index < 0 or player_index >= players.size():
		return ""
	var choices: Array = districts[district_index].get("card_choices", [])
	for card_variant in choices:
		var card_name := String(card_variant)
		var state := _district_supply_purchase_state(district_index, card_name, player_index)
		if not bool(state.get("actionable", false)):
			continue
		if _first_run_card_is_teachable_after_purchase(player_index, card_name):
			return card_name
	return ""


func _first_run_teaching_card_name() -> String:
	if _game_runtime_coordinator_node().card_exists(FIRST_RUN_TEACHING_CARD_NAME):
		return FIRST_RUN_TEACHING_CARD_NAME
	for fallback_name in ["地下融资1"]:
		if _game_runtime_coordinator_node().card_exists(String(fallback_name)):
			return String(fallback_name)
	return ""


func _first_run_teaching_supply_gate(player_index: int, district_index: int, card_name: String) -> Dictionary:
	var state := {
		"ok": false,
		"card_name": card_name,
		"district_index": district_index,
		"purchasable": false,
		"direct_teachable": false,
		"non_starter": false,
		"no_target_prompt": false,
	}
	if player_index < 0 or player_index >= players.size() or district_index < 0 or district_index >= districts.size() or card_name == "" or not _game_runtime_coordinator_node().card_exists(card_name):
		return state
	var purchase_state := _district_supply_purchase_state(district_index, card_name, player_index)
	var skill := _make_skill(card_name)
	state["purchasable"] = bool(purchase_state.get("actionable", false))
	state["non_starter"] = not bool(skill.get("starter_play_free", false))
	var target := _card_play_target_snapshot(skill)
	state["no_target_prompt"] = not bool(target.get("requires_target_monster", false)) and not bool(target.get("requires_target_player", false))
	state["direct_teachable"] = _first_run_card_is_teachable_after_purchase(player_index, card_name)
	state["ok"] = bool(state.get("purchasable", false)) \
		and bool(state.get("direct_teachable", false)) \
		and bool(state.get("non_starter", false)) \
		and bool(state.get("no_target_prompt", false))
	return state


func _first_run_non_teachable_supply_choice_index(choices: Array, player_index: int) -> int:
	for offset in range(choices.size()):
		var index := choices.size() - 1 - offset
		var card_name := _canonical_card_supply_name(String(choices[index]))
		if card_name == "" or _is_monster_card_name(card_name):
			continue
		if not _first_run_card_is_teachable_after_purchase(player_index, card_name):
			return index
	for offset in range(choices.size()):
		var index := choices.size() - 1 - offset
		var card_name := _canonical_card_supply_name(String(choices[index]))
		if card_name == "" or not _first_run_card_is_teachable_after_purchase(player_index, card_name):
			return index
	return -1


func _inject_first_run_teaching_card_supply(district_index: int, player_index: int, card_name: String) -> bool:
	if district_index < 0 or district_index >= districts.size() or player_index < 0 or player_index >= players.size() or card_name == "" or not _game_runtime_coordinator_node().card_exists(card_name):
		return false
	if bool(districts[district_index].get("destroyed", false)):
		return false
	var choices: Array = districts[district_index].get("card_choices", [])
	if choices.has(card_name):
		_set_district_card_source(district_index, card_name, FIRST_RUN_TEACHING_CARD_SOURCE)
		return true
	if choices.size() >= DISTRICT_CARD_CHOICE_MAX:
		var replace_index := _first_run_non_teachable_supply_choice_index(choices, player_index)
		if replace_index < 0:
			replace_index = _last_non_monster_supply_choice_index(choices)
		if replace_index < 0:
			replace_index = max(0, choices.size() - 1)
		var removed_name := String(choices[replace_index])
		var sources: Dictionary = districts[district_index].get("card_sources", {})
		sources.erase(removed_name)
		choices[replace_index] = card_name
		districts[district_index]["card_sources"] = sources
	else:
		choices.append(card_name)
	districts[district_index]["card_choices"] = choices
	_set_district_card_source(district_index, card_name, FIRST_RUN_TEACHING_CARD_SOURCE)
	return true


func _ensure_first_run_teaching_card_supply(player_index: int) -> int:
	var existing_district := _first_teachable_buyable_district_for_player(player_index)
	if existing_district >= 0:
		return existing_district
	var teaching_card := _first_run_teaching_card_name()
	if teaching_card == "":
		return -1
	var target_district := _first_card_accessible_district_for_player(player_index)
	if target_district < 0:
		return -1
	if not _inject_first_run_teaching_card_supply(target_district, player_index, teaching_card):
		return -1
	var gate := _first_run_teaching_supply_gate(player_index, target_district, teaching_card)
	return target_district if bool(gate.get("ok", false)) else -1


func _first_run_card_is_teachable_after_purchase(player_index: int, card_name: String) -> bool:
	if player_index < 0 or player_index >= players.size() or card_name == "" or not _game_runtime_coordinator_node().card_exists(card_name):
		return false
	var skill := _make_skill(card_name)
	return _first_run_skill_has_direct_teaching_profile(player_index, skill)


func _first_run_skill_has_direct_teaching_profile(player_index: int, skill: Dictionary) -> bool:
	if player_index < 0 or player_index >= players.size() or skill.is_empty():
		return false
	if bool(skill.get("starter_play_free", false)):
		return false
	var kind := String(skill.get("kind", ""))
	if kind != "cash_gain":
		return false
	var target := _card_play_target_snapshot(skill)
	if String(skill.get("kind", "")) == "card_counter" or bool(target.get("requires_target_monster", false)) or bool(target.get("requires_target_player", false)):
		return false
	var cash_cost := int(_card_play_requirement_snapshot(player_index, skill).get("cash_cost", 0))
	if not bool(skill.get("_play_cost_paid_on_queue", false)) and cash_cost > 0 and int(players[player_index].get("cash", 0)) < cash_cost:
		return false
	var required := _skill_play_flow_required(skill, player_index)
	if required > 0:
		var product_name := _skill_play_product(skill, player_index)
		if _player_product_flow(player_index, product_name) < required:
			return false
	return true


func _first_run_skill_is_direct_teachable(player_index: int, skill: Dictionary) -> bool:
	if not _first_run_skill_has_direct_teaching_profile(player_index, skill):
		return false
	var state := _card_play_eligibility_snapshot(player_index, skill, "hand")
	return bool(state.get("actionable", false))


func _ensure_first_run_teachable_hand_card(player_index: int) -> bool:
	if _first_actionable_teachable_hand_slot(player_index) >= 0:
		return true
	if player_index < 0 or player_index >= players.size():
		return false
	var previous_selected_player := selected_player
	var previous_selected_district := selected_district
	var previous_market_skill := selected_market_skill
	var previous_previewed_card := previewed_district_card
	for district_index in range(districts.size()):
		if bool(districts[district_index].get("destroyed", false)) or not _district_market_currently_purchasable(district_index):
			continue
		for card_variant in districts[district_index].get("card_choices", []):
			var card_name := String(card_variant)
			if not _first_run_card_is_teachable_after_purchase(player_index, card_name):
				continue
			var state := _district_supply_purchase_state(district_index, card_name, player_index)
			if not bool(state.get("actionable", false)):
				continue
			selected_player = player_index
			_jump_to_district_on_table(district_index)
			_open_first_run_coach_district_supply(district_index, player_index)
			selected_market_skill = card_name
			previewed_district_card = card_name
			_claim_district_card(card_name)
			if _first_actionable_teachable_hand_slot(player_index) >= 0:
				return true
	selected_player = previous_selected_player
	selected_district = previous_selected_district
	selected_market_skill = previous_market_skill
	previewed_district_card = previous_previewed_card
	return _first_actionable_teachable_hand_slot(player_index) >= 0


func _first_card_accessible_district_for_player(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return -1
	if selected_district >= 0 and selected_district < districts.size() and _district_market_currently_purchasable(selected_district):
		return selected_district
	if _district_supply_is_open() and _district_market_currently_purchasable(district_supply_open_district):
		return district_supply_open_district
	for district_index in range(districts.size()):
		if not bool(districts[district_index].get("destroyed", false)) and _district_market_currently_purchasable(district_index):
			return district_index
	return -1


func _first_buyable_district_for_player(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return -1
	if selected_district >= 0 and selected_district < districts.size() and _first_buyable_district_card(selected_district, player_index) != "":
		return selected_district
	if _district_supply_is_open() and _first_buyable_district_card(district_supply_open_district, player_index) != "":
		return district_supply_open_district
	for district_index in range(districts.size()):
		if not bool(districts[district_index].get("destroyed", false)) and _first_buyable_district_card(district_index, player_index) != "":
			return district_index
	return -1


func _first_teachable_buyable_district_for_player(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return -1
	if selected_district >= 0 and selected_district < districts.size() and _first_teachable_buyable_district_card(selected_district, player_index) != "":
		return selected_district
	if _district_supply_is_open() and _first_teachable_buyable_district_card(district_supply_open_district, player_index) != "":
		return district_supply_open_district
	for district_index in range(districts.size()):
		if bool(districts[district_index].get("destroyed", false)):
			continue
		var card_name := _first_teachable_buyable_district_card(district_index, player_index)
		if card_name != "":
			return district_index
	return -1


func _first_run_buy_card_tooltip(buyable_district: int, buyable_card: String) -> String:
	if buyable_district < 0 or buyable_card == "":
		return "当前没有合法可买牌；等待一个来源区域进入日照半球。"
	var district_name := String(districts[buyable_district].get("name", "区域")) if buyable_district >= 0 and buyable_district < districts.size() else "可买区域"
	var card_label := _card_display_name(buyable_card)
	if buyable_district == selected_district:
		return "从当前牌架购买%s；满手时会进入私密弃牌确认。" % card_label
	return "会先切到%s的合法牌架，再购买%s；满手时会进入私密弃牌确认。" % [district_name, card_label]


func _first_public_track_resolution_id() -> int:
	var card_surfaces := _runtime_card_surfaces_snapshot()
	var entries: Array = card_surfaces.get("card_track", []) if card_surfaces.get("card_track", []) is Array else []
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var resolution_id := int(entry.get("resolution_id", -1))
		if resolution_id >= 0 and String(entry.get("kind", "")) != "event":
			return resolution_id
	return -1


func _opening_guide_progress(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= players.size():
		return {}
	var player: Dictionary = players[player_index]
	var has_monster := int(_ai_runtime_call("_ai_owned_active_monster_count", [player_index])) > 0
	var has_city := _player_active_city_count(player_index) > 0
	var has_bought_card := int(player.get("card_purchase_count", 0)) > 0
	var has_played_card := false
	for entry_variant in resolved_card_history:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if int(entry.get("player_index", -1)) == player_index and _opening_guide_card_entry_counts(entry):
			has_played_card = true
			break
	for entry_variant in _card_resolution_current_queue():
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("player_index", -1)) == player_index and _opening_guide_card_entry_counts(entry_variant as Dictionary):
			has_played_card = true
	for entry_variant in _card_resolution_next_queue():
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("player_index", -1)) == player_index and _opening_guide_card_entry_counts(entry_variant as Dictionary):
			has_played_card = true
	if int(_card_resolution_active_entry().get("player_index", -1)) == player_index and _opening_guide_card_entry_counts(_card_resolution_active_entry()):
		has_played_card = true
	var has_checked_economy := _opening_guide_economy_seen(player_index)
	var route_choice := _first_run_coach_route_choice(player_index)
	return {
		"has_monster": has_monster,
		"has_city": has_city,
		"has_bought_card": has_bought_card,
		"has_played_card": has_played_card,
		"has_checked_economy": has_checked_economy,
		"has_chosen_route": route_choice != "",
		"route_choice": route_choice,
	}


func _first_run_should_defer_monster_wager() -> bool:
	if opening_guide_dismissed or _runtime_session_finished():
		return false
	var completed_signals: Dictionary = _runtime_scenario_state().get("completed_signals", {})
	if _active_runtime_scenario_id() == "first_table" and not bool(completed_signals.get("route_chosen", false)):
		return true
	var player_index := _first_run_coach_player_index()
	if player_index < 0 or player_index >= players.size() or _player_is_ai(player_index):
		return false
	var progress := _opening_guide_progress(player_index)
	if progress.is_empty():
		return false
	return not bool(progress.get("has_played_card", false))


func _selected_district_status_text(player_index: int) -> String:
	if selected_district < 0 or selected_district >= districts.size():
		return "未选择区域"
	var district: Dictionary = districts[selected_district]
	var terrain := String(district.get("terrain_label", "海洋" if String(district.get("terrain", "land")) == "ocean" else "陆地"))
	if bool(district.get("destroyed", false)):
		return "%s｜%s｜区域已毁" % [String(district.get("name", "区域")), terrain]
	var city := _district_city(selected_district)
	if _city_is_active(city):
		var gdp := _city_gdp_per_minute(selected_district, int(city.get("competition_matches", 0)))
		var owner_text := _selected_city_owner_view_text()
		if player_index < 0 or player_index >= players.size():
			owner_text = "归属待猜"
		return "%s｜%s｜%s｜GDP %d/min" % [
			String(district.get("name", "区域")),
			terrain,
			owner_text,
			gdp,
		]
	if not city.is_empty():
		return "%s｜%s｜城市废墟" % [String(district.get("name", "区域")), terrain]
	var settle_text := "可城市化" if String(district.get("terrain", "land")) != "ocean" else "运输海域"
	return "%s｜%s｜%s" % [String(district.get("name", "区域")), terrain, settle_text]


func _selected_district_supply_text(player_index: int) -> String:
	if selected_district < 0 or selected_district >= districts.size():
		return "补给：未选区"
	var district: Dictionary = districts[selected_district]
	var choices: Array = district.get("card_choices", [])
	return "补给 %d张｜%s" % [choices.size(), _district_market_availability_text(selected_district)]


func _selected_district_action_lamp_entries(player_index: int) -> Array:
	var entries := []
	var has_selection := selected_district >= 0 and selected_district < districts.size()
	if not has_selection:
		return [{
			"text": "先点地块",
			"state": "未选",
			"accent": Color("#94a3b8"),
			"active": false,
			"tip": "在中央星球上点一个区域后，地块行动灯会显示可做动作。",
		}]
	var district: Dictionary = districts[selected_district]
	var choices: Array = district.get("card_choices", [])
	var can_buy := _district_market_currently_purchasable(selected_district)
	var trade_product := selected_trade_product if selected_trade_product != "" else _default_trade_product_for_selected_district()
	var city := _district_city(selected_district)
	entries.append({
		"text": "牌架",
		"state": "可买" if can_buy else ("可看" if not choices.is_empty() else "空"),
		"accent": Color("#facc15") if can_buy else Color("#38bdf8"),
		"active": not choices.is_empty(),
		"tip": "区域牌架：查看始终允许；来源受光时可报价，显式选择后锁定5秒。",
	})
	entries.append({
		"text": "商路",
		"state": _short_card_text(trade_product if selected_trade_product != "" else "未开", 5),
		"accent": Color("#f59e0b") if selected_trade_product != "" else Color("#64748b"),
		"active": selected_trade_product != "",
		"tip": "商路显示：点击商路按钮会切换当前商品运输路径。",
	})
	if _city_is_active(city) and int(city.get("owner", -1)) != player_index:
		entries.append({
			"text": "标注",
			"state": "可猜",
			"accent": Color("#c084fc"),
			"active": true,
			"tip": "陌生城市可进入情报档案，记录你猜测的业主。",
		})
	return entries


func _selected_district_action_entries(player_index: int) -> Array:
	var has_selection := selected_district >= 0 and selected_district < districts.size()
	var city := _district_city(selected_district)
	var can_mark := _city_is_active(city) and int(city.get("owner", -1)) != player_index
	return [
		{
			"text": "查看牌架",
			"tooltip": "打开当前区域卡牌市场。不能购买时也能查看卡面和效果。",
			"disabled": not has_selection,
			"target": Callable(self, "_open_district_supply_from_map").bind(selected_district),
			"accent": Color("#38bdf8"),
		},
		{
			"text": "◇标注",
			"tooltip": "打开情报档案，为这座陌生城市记录私人归属推测。",
			"disabled": not can_mark,
			"target": Callable(self, "_open_intel_dossier_menu"),
			"accent": Color("#c084fc"),
		},
		{
			"text": "⇄商路",
			"tooltip": "显示或关闭当前选区相关商品的运输路径。",
			"disabled": not has_selection,
			"target": Callable(self, "_toggle_selected_trade_route"),
			"accent": Color("#f59e0b"),
		},
		{
			"text": "⛶全屏",
			"tooltip": "放大星球地图，专心查看地形、城市、怪兽和路线。",
			"disabled": false,
			"target": Callable(self, "_open_fullscreen_map"),
			"accent": Color("#64748b"),
		},
	]


func _player_visible_city_text(player_index: int, viewer_index: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return "城?"
	if player_index == viewer_index:
		return "己城%d" % _player_active_city_count(player_index)
	if viewer_index < 0 or viewer_index >= players.size():
		return "城?"
	var guesses: Dictionary = (players[viewer_index] as Dictionary).get("city_guesses", {})
	var suspected_count := 0
	for key_variant in guesses.keys():
		if int(guesses.get(key_variant, -1)) == player_index:
			suspected_count += 1
	return "疑城%d" % suspected_count if suspected_count > 0 else "城?"


func _player_visible_monster_count(player_index: int, viewer_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var count := 0
	for actor_variant in monster_runtime_controller.auto_monsters:
		if not (actor_variant is Dictionary):
			continue
		var actor := actor_variant as Dictionary
		if bool(actor.get("down", false)) or int(actor.get("owner", -1)) != player_index:
			continue
		if bool(actor.get("owner_revealed", false)) or player_index == viewer_index:
			count += 1
	return count


func _first_starter_monster_slot(player: Dictionary) -> int:
	var slots: Array = player.get("slots", [])
	for i in range(slots.size()):
		var slot_variant: Variant = slots[i]
		if not (slot_variant is Dictionary):
			continue
		var skill := slot_variant as Dictionary
		var machine: Dictionary = skill.get("machine", {}) if skill.get("machine", {}) is Dictionary else {}
		if str(machine.get("effect_kind", "")) == "deploy_or_upgrade_monster" and int(machine.get("rank", 0)) == 1:
			return i
		if String(skill.get("kind", "")) == "monster_card" and bool(skill.get("starter_play_free", false)):
			return i
	return -1


func _role_card_presentation_color(role_card: Dictionary) -> Color:
	if PLAYER_COLORS.is_empty():
		return Color("#38bdf8")
	var index := wrapi(int(role_card.get("role_index", _codex_navigation_controller_node().role_codex_index)), 0, PLAYER_COLORS.size())
	return (PLAYER_COLORS[index] as Color).lerp(Color("#f59e0b"), 0.18)


func _role_card_tag_text(role_card: Dictionary) -> String:
	return "角色卡 / %s" % String(role_card.get("species", "未知外星人"))


func _role_card_face_text(role_card: Dictionary, compact: bool = false) -> String:
	var role_trait := String(role_card.get("trait", "暂无特征"))
	if compact:
		return "特征:%s\n被动:%s\n公开角色" % [
			_short_card_text(role_trait, 34),
			_short_card_text(_role_passive_text(role_card), 26),
		]
	return "特征：%s\n被动：%s\n角色资料：公开身份；开局怪兽独立选择。" % [
		role_trait,
		_role_passive_text(role_card),
	]


func _monster_card_duration_text(skill: Dictionary, compact: bool = false) -> String:
	var duration := float(skill.get("duration", -1.0))
	if duration < 0.0:
		return "常驻" if compact else "不限时（不会自然离场）"
	return "%.0fs" % duration if compact else "%.0f秒后自然离场" % duration


func _duration_short_text(seconds: float) -> String:
	var total := maxi(1, int(round(seconds)))
	if total < 60:
		return "%d秒" % total
	var minutes := int(float(total) / 60.0)
	var rest := total % 60
	if rest == 0:
		return "%d分钟" % minutes
	return "%d分%d秒" % [minutes, rest]


func _legacy_turns_to_seconds(turns: int) -> float:
	return float(maxi(0, turns)) * ECONOMY_LEGACY_TURN_SECONDS


func _skill_duration_seconds(skill: Dictionary, seconds_key: String, turns_key: String, default_turns: int = 0) -> float:
	if skill.has(seconds_key):
		return maxf(0.0, float(skill.get(seconds_key, 0.0)))
	return _legacy_turns_to_seconds(maxi(0, int(skill.get(turns_key, default_turns))))


func _remaining_effect_seconds(source: Dictionary, seconds_key: String, turns_key: String) -> float:
	if source.has(seconds_key):
		return maxf(0.0, float(source.get(seconds_key, 0.0)))
	return _legacy_turns_to_seconds(maxi(0, int(source.get(turns_key, 0))))


func _set_remaining_effect_seconds(source: Dictionary, seconds_key: String, turns_key: String, seconds: float) -> void:
	var safe_seconds := maxf(0.0, seconds)
	source[seconds_key] = safe_seconds
	source[turns_key] = int(ceil(safe_seconds / ECONOMY_LEGACY_TURN_SECONDS)) if safe_seconds > 0.0 else 0


func _age_remaining_effect_seconds(source: Dictionary, seconds_key: String, turns_key: String, delta_seconds: float) -> bool:
	var before := _remaining_effect_seconds(source, seconds_key, turns_key)
	if before <= 0.0:
		_set_remaining_effect_seconds(source, seconds_key, turns_key, 0.0)
		return false
	var after := maxf(0.0, before - maxf(0.0, delta_seconds))
	_set_remaining_effect_seconds(source, seconds_key, turns_key, after)
	return before > 0.0 and after <= 0.0


func _boon_duration_text(seconds: float) -> String:
	if seconds > 0.0:
		return _duration_short_text(seconds)
	return "本局持续"


func _monster_card_region_text(skill: Dictionary, compact: bool = false) -> String:
	if bool(skill.get("starter_play_free", false)):
		return "不限区" if compact else "无（起始怪兽牌）"
	match String(skill.get("summon_access", "any")):
		"monster_zone":
			return "怪区邻接" if compact else "怪兽落地区或相邻区域"
		"land_monster_zone":
			return "陆地怪区" if compact else "陆地区域，且必须是怪兽落地区或相邻区域"
		"ocean_monster_zone":
			return "海洋怪区" if compact else "海洋区域，且必须是怪兽落地区或相邻区域"
		"land":
			return "仅陆地" if compact else "仅限陆地区域"
		"ocean":
			return "仅海洋" if compact else "仅限海洋区域"
		"any", "":
			return "不限区" if compact else "无"
	return String(skill.get("summon_access", "无"))


func _can_summon_monster_card_at_district(skill: Dictionary, district_index: int) -> bool:
	if bool(skill.get("starter_play_free", false)):
		return district_index >= 0 and district_index < districts.size() and not bool(districts[district_index].get("destroyed", false))
	if district_index < 0 or district_index >= districts.size():
		return false
	if bool(districts[district_index].get("destroyed", false)):
		return false
	var terrain := String(districts[district_index].get("terrain", "land"))
	match String(skill.get("summon_access", "any")):
		"monster_zone":
			return monster_runtime_controller.summon_zone_available(district_index)
		"land_monster_zone":
			return monster_runtime_controller.summon_zone_available(district_index, "land")
		"ocean_monster_zone":
			return monster_runtime_controller.summon_zone_available(district_index, "ocean")
		"land":
			return terrain == "land"
		"ocean":
			return terrain == "ocean"
		"any", "":
			return true
	return true






func _sync_card_resolution_stage_visual(entry: Dictionary, skill: Dictionary, seconds_left: float) -> void:
	if entry.is_empty() or skill.is_empty():
		return
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	var presentation := _card_resolution_presentation_snapshot(skill, entry, seconds_left)
	var stage_index := int(presentation.get("stage_index", 0))
	if card_resolution_visual_id == resolution_id and card_resolution_visual_stage >= stage_index:
		return
	card_resolution_visual_id = resolution_id
	card_resolution_visual_stage = stage_index
	_emit_card_resolution_stage_visual(entry, skill, presentation)


func _emit_card_resolution_stage_visual(entry: Dictionary, skill: Dictionary, presentation: Dictionary) -> void:
	var card_name := String(skill.get("name", "卡牌"))
	var card_label := _card_display_name(card_name)
	if card_label == "":
		card_label = card_name
	var stage_index := int(presentation.get("stage_index", 0))
	var stage_label := String(presentation.get("stage_label", "开场"))
	var effect_position := _card_resolution_effect_position(skill, entry)
	var color := _card_presentation_color(skill)
	var style := String(presentation.get("effect_style", "generic"))
	var kind := "card_open"
	var detail := "匿名卡牌进入公开展示，出牌者仍隐藏。"
	match clampi(stage_index, 0, 2):
		0:
			kind = "card_open"
			detail = "%s开场：卡面公开，目标位置被照亮。" % card_label
			var orbit_position := _wrap_world_position(effect_position + Vector2(map_width_m * 0.08, -map_height_m * 0.06))
			_add_visual_trail(orbit_position, effect_position, color, "匿名卡牌", 1.20, "card_ingress")
		1:
			kind = "card_resolve"
			detail = "%s结算：效果正写入地图/经济/怪兽状态。" % card_label
		2:
			kind = "card_afterglow"
			detail = "%s余波：公开结果留下推理线索。" % card_label
	_add_map_event_effect(kind, effect_position, color, String(presentation.get("stage_effect_label", "%s%s" % [String(presentation.get("effect_style_label", "卡牌")), stage_label])), 1.25, float(presentation.get("effect_radius", 75.0)), style)
	_add_action_callout("匿名卡牌", "%s分镜" % stage_label, detail, color, effect_position, 2.25)


func _add_card_resolution_aftermath_clue(entry: Dictionary, skill: Dictionary, resolved: bool) -> void:
	if skill.is_empty():
		return
	var card_name := String(skill.get("name", "卡牌"))
	var card_label := _card_display_name(card_name)
	if card_label == "":
		card_label = card_name
	var presentation := _card_resolution_presentation_snapshot(skill, entry, -1.0, resolved)
	var style := String(presentation.get("effect_style", "generic"))
	var style_label := String(presentation.get("effect_style_label", "卡牌"))
	var clue := String(presentation.get("aftermath_clue", "公开结果留下匿名推理痕迹"))
	entry["aftermath_clue"] = clue
	entry["aftermath_style"] = style
	var effect_position := _card_resolution_effect_position(skill, entry)
	var color := _card_presentation_color(skill)
	if not resolved:
		color = color.darkened(0.28)
	var status := "已结算" if resolved else "未生效"
	var detail := "%s｜%s演出｜%s｜%s；轨道仍可竞猜归属。" % [
		status,
		style_label,
		String(presentation.get("target_text", "目标未知")),
		clue,
	]
	_add_action_callout("卡牌余波", card_label, detail, color, effect_position, CARD_RESOLUTION_AFTERMATH_SECONDS)
	_add_map_event_effect(
		"card_afterglow",
		effect_position,
		color,
		"余波%s" % style_label,
		CARD_RESOLUTION_AFTERMATH_SECONDS,
		float(presentation.get("effect_radius", 75.0)) * 1.12,
		style
	)


func _card_resolution_effect_position(skill: Dictionary, entry: Dictionary = {}) -> Vector2:
	var target_slot := int(entry.get("target_slot", -1))
	if target_slot >= 0 and target_slot < monster_runtime_controller.auto_monsters.size():
		var actor: Dictionary = monster_runtime_controller.auto_monsters[target_slot]
		return _entity_world_position(actor)
	if String(skill.get("kind", "")) == "area_trade_contract":
		var target_index := int(entry.get("contract_target_district", -1))
		if target_index >= 0 and target_index < districts.size():
			return _district_center(target_index)
	if bool(_card_play_target_snapshot(skill).get("targets_player", false)) and selected_district >= 0 and selected_district < districts.size():
		return _district_center(selected_district)
	var district_index := int(entry.get("selected_district", selected_district))
	if district_index >= 0 and district_index < districts.size():
		return _district_center(district_index)
	if not monster_runtime_controller.auto_monsters.is_empty():
		return _entity_world_position(monster_runtime_controller.auto_monsters[0] as Dictionary)
	return Vector2(map_width_m * 0.5, map_height_m * 0.5)


func _join_first_card_facts(facts: Array, max_count: int) -> String:
	var pieces := []
	for i in range(min(max_count, facts.size())):
		pieces.append(String(facts[i]))
	return "｜".join(pieces)


func _short_card_text(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.left(max(1, max_len - 1)) + "…"


func _preview_district_card(card_name: String, refresh: bool = true) -> void:
	if card_name == "" or not _game_runtime_coordinator_node().card_exists(card_name):
		return
	var context_district := _active_district_card_context()
	if context_district >= 0 and context_district < districts.size() and not _district_has_card(context_district, card_name):
		return
	previewed_district_card = card_name
	_complete_scenario_signal("card_previewed", "查看卡牌：%s。" % _card_display_name(card_name), "rack_open", "district_supply")
	if refresh:
		_refresh_ui()


func _select_district_card_for_quote(card_name: String, refresh: bool = true) -> void:
	if card_name == "" or not _game_runtime_coordinator_node().card_exists(card_name):
		return
	var context_district := _active_district_card_context()
	if context_district < 0 or context_district >= districts.size() or not _district_has_card(context_district, card_name):
		return
	selected_market_skill = card_name
	previewed_district_card = card_name
	var purchase_player := district_supply_open_player if _district_supply_is_open() else selected_player
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator != null and runtime_coordinator.has_method("acknowledge_district_purchase_selection"):
		runtime_coordinator.call("acknowledge_district_purchase_selection", purchase_player, context_district, card_name, str(districts[context_district].get("card_choices", [])))
		_request_card_market_quote(card_name, context_district, purchase_player)
	_complete_scenario_signal("card_previewed", "查看卡牌：%s。" % _card_display_name(card_name), "rack_open", "district_supply")
	if refresh:
		_refresh_ui()


func _district_card_source(district_index: int, card_name: String) -> String:
	if district_index < 0 or district_index >= districts.size():
		return "未知来源"
	var sources: Dictionary = districts[district_index].get("card_sources", {})
	return String(sources.get(card_name, "公共补给"))




func _close_district_supply_overlay() -> void:
	var closing_player := district_supply_open_player
	if district_supply_overlay != null:
		if district_supply_overlay.has_method("clear_supply"):
			district_supply_overlay.call("clear_supply")
		district_supply_overlay.visible = false
	var runtime_coordinator := _game_runtime_coordinator_node()
	if closing_player >= 0 and runtime_coordinator != null and runtime_coordinator.has_method("close_district_purchase_window"):
		runtime_coordinator.call("close_district_purchase_window", closing_player, "drawer_closed")
	district_supply_open_district = -1
	district_supply_open_player = -1
	pending_discard_purchase = {}
	_refresh_ui()


func _district_supply_is_open() -> bool:
	return district_supply_overlay != null and district_supply_overlay.visible and district_supply_open_district >= 0 and district_supply_open_district < districts.size()


func _active_district_card_context() -> int:
	if _district_supply_is_open():
		return district_supply_open_district
	return selected_district


func _open_district_supply_from_map(district_index: int) -> void:
	if district_index < 0 or district_index >= districts.size() or selected_player < 0 or selected_player >= players.size():
		return
	_jump_to_district_on_table(district_index)
	district_supply_open_district = district_index
	district_supply_open_player = _local_human_player_index()
	_mark_first_run_coach_supply_seen(district_supply_open_player)
	_open_district_card_purchase_window(district_index, district_supply_open_player)
	_sync_selected_district_card()
	_load_selected_district_guess()
	if district_supply_overlay != null:
		district_supply_overlay.visible = true
	_complete_scenario_signal("rack_opened", "打开区域牌架：%s。" % String(districts[district_index].get("name", "区域")), "after_rack", "district_supply")
	_refresh_ui()


func _refresh_district_supply_overlay() -> void:
	if district_supply_overlay == null or not district_supply_overlay.visible:
		return
	if district_supply_open_district < 0 or district_supply_open_district >= districts.size():
		district_supply_overlay.visible = false
		return
	var supply_player := district_supply_open_player
	if supply_player < 0 or supply_player >= players.size() or _player_is_ai(supply_player):
		supply_player = _local_human_player_index()
	if supply_player < 0 or supply_player >= players.size():
		return
	if district_supply_open_player != supply_player:
		district_supply_open_player = supply_player
		_open_district_card_purchase_window(district_supply_open_district, supply_player)
	var district: Dictionary = districts[district_supply_open_district]
	var supply_revision := str(district.get("card_choices", []))
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator != null and runtime_coordinator.has_method("mark_district_supply_revision"):
		runtime_coordinator.call("mark_district_supply_revision", supply_player, district_supply_open_district, supply_revision)
	if not district_supply_overlay.has_method("set_supply"):
		return
	if runtime_coordinator == null or not runtime_coordinator.has_method("compose_district_supply_snapshot"):
		push_error("District supply rendering requires GameRuntimeCoordinator/DistrictSupplySnapshotService.")
		district_supply_overlay.call("set_supply", {})
		return
	var source := _district_supply_snapshot_source(district_supply_open_district, supply_player, _local_human_player_index())
	var snapshot_variant: Variant = runtime_coordinator.call("compose_district_supply_snapshot", source)
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	district_supply_overlay.call("set_supply", snapshot)


func _district_supply_snapshot_source(district_index: int, subject_player_index: int, viewer_player_index: int = -1) -> Dictionary:
	if district_index < 0 or district_index >= districts.size() or subject_player_index < 0 or subject_player_index >= players.size():
		return {}
	var viewer_authorized := _district_supply_private_viewer_authorized(subject_player_index, viewer_player_index)
	var local_human_player_index := _local_human_player_index()
	var card_context_player_index := subject_player_index if viewer_authorized else local_human_player_index
	if card_context_player_index < 0 or card_context_player_index >= players.size():
		card_context_player_index = subject_player_index
	var district: Dictionary = districts[district_index]
	var choices: Array = district.get("card_choices", []) if district.get("card_choices", []) is Array else []
	var v06_facility_source := _v06_first_table_facility_supply_source(district_index, card_context_player_index, false)
	var v06_facility_card_id := str(v06_facility_source.get("card_name", ""))
	var preview_name := previewed_district_card
	if not choices.has(preview_name) and preview_name != v06_facility_card_id:
		preview_name = str(choices[0]) if not choices.is_empty() else ""
		if preview_name.is_empty():
			preview_name = v06_facility_card_id
		previewed_district_card = preview_name
		selected_market_skill = preview_name
	var card_sources: Array = []
	for card_name_variant: Variant in choices:
		var card_name := str(card_name_variant)
		if not _game_runtime_coordinator_node().card_exists(card_name):
			continue
		var card_source := _district_supply_card_source(district_index, card_name, card_context_player_index, card_name == preview_name)
		if not card_source.is_empty():
			if not viewer_authorized:
				card_source = _district_supply_public_card_source(card_source)
			card_sources.append(card_source)
	if not v06_facility_source.is_empty():
		v06_facility_source["selected"] = v06_facility_card_id == preview_name
		if not viewer_authorized:
			v06_facility_source = _district_supply_public_card_source(v06_facility_source)
		card_sources.append(v06_facility_source)
	var availability_kind := _district_market_availability_kind(district_index)
	var can_buy := _district_market_currently_purchasable(district_index) if viewer_authorized else false
	var purchase_window: Dictionary = {}
	var runtime_coordinator := _game_runtime_coordinator_node()
	if viewer_authorized and runtime_coordinator != null and runtime_coordinator.has_method("district_purchase_private_ui_snapshot"):
		var status_variant: Variant = runtime_coordinator.call("district_purchase_private_ui_snapshot", subject_player_index)
		if status_variant is Dictionary:
			purchase_window = (status_variant as Dictionary).duplicate(true)
	var local_products: Array = []
	for product_variant: Variant in _district_local_product_names(district_index):
		local_products.append(str(product_variant))
	var result := {
		"district_index": district_index,
		"district_name": str(district.get("name", "区域")),
		"player_index": subject_player_index,
		"subject_player_index": subject_player_index,
		"viewer_player_index": viewer_player_index,
		"visibility_scope": "viewer_private" if viewer_authorized else "public",
		"viewer_authorized": viewer_authorized,
		"selected_card_name": preview_name,
		"availability_kind": availability_kind,
		"availability_text": _district_market_availability_text(district_index),
		"local_product_names": local_products,
		"cards": card_sources,
	}
	if viewer_authorized:
		var player: Dictionary = players[subject_player_index]
		result["can_buy"] = can_buy
		result["purchase_window"] = purchase_window
		result["player_cash"] = int(player.get("cash", 0))
		result["counted_hand_size"] = _player_counted_hand_size(player)
		result["hand_limit"] = PLAYER_HAND_LIMIT
	return result


func _district_supply_private_viewer_authorized(subject_player_index: int, viewer_player_index: int) -> bool:
	return subject_player_index >= 0 \
		and subject_player_index < players.size() \
		and viewer_player_index == subject_player_index \
		and viewer_player_index == _local_human_player_index() \
		and not _player_is_ai(viewer_player_index)


func _district_supply_public_card_source(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	var state: Dictionary = source.get("purchase_state", {}) if source.get("purchase_state", {}) is Dictionary else {}
	var price := int(source.get("price", state.get("price", 0)))
	result["purchase_state"] = {
		"label": "仅浏览",
		"detail": "公共牌架预览；购买资格、现金和手牌状态仅对本地真人本人显示。",
		"actionable": false,
		"requires_discard": false,
		"price": price,
		"accent": "#94a3b8ff",
	}
	for private_key in ["player_cash", "counted_hand_size", "hand_limit", "can_buy", "purchase_window", "actionable", "requires_discard", "hand_cards", "player_hand", "discard_card", "discard_card_name", "ai_plan", "ai_score"]:
		result.erase(private_key)
	return result


func _v06_first_table_facility_supply_source(district_index: int, player_index: int, selected: bool) -> Dictionary:
	if district_index < 0 or district_index >= districts.size() or player_index < 0 or player_index >= players.size() or _player_is_ai(player_index):
		return {}
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("v06_first_table_facility_market_snapshot"):
		return {}
	var actor_id := _v06_actor_id(player_index)
	var snapshot_variant: Variant = coordinator.call("v06_first_table_facility_market_snapshot", actor_id)
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	if not bool(snapshot.get("ready", false)):
		return {}
	var listing: Dictionary = snapshot.get("listing", {}) if snapshot.get("listing", {}) is Dictionary else {}
	var card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var player_text: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
	var quote: Dictionary = snapshot.get("quote", {}) if snapshot.get("quote", {}) is Dictionary else {}
	var card_id := str(machine.get("card_id", ""))
	if card_id.is_empty():
		return {}
	var price := int(quote.get("final_price", machine.get("purchase_cash", -1)))
	var can_access := bool(quote.get("purchasable", false))
	var cash_ready := int(players[player_index].get("cash", 0)) >= price
	var actionable := can_access and cash_ready and not _runtime_session_finished()
	var state := {
		"label": "可购买" if actionable else ("资金不足" if can_access and not cash_ready else "仅浏览"),
		"detail": "购买后进入v0.6手牌，由统一卡牌事务结算。" if actionable else ("需要¥%d；当前资金不足。" % price if can_access else "挂牌来源区域当前处于暗面；可以查看，暂不可购买。"),
		"actionable": actionable,
		"requires_discard": false,
		"price": price,
		"accent": "#22c55e" if actionable else ("#fb7185" if can_access else "#94a3b8"),
	}
	var key_rule_facts: Array = []
	for key in ["timing", "target", "duration"]:
		var value := str(player_text.get(key, "")).strip_edges()
		if not value.is_empty():
			key_rule_facts.append(value)
	return {
		"card_name": card_id,
		"display_name": str(player_text.get("name", card_id)),
		"icon": "城",
		"rank": int(machine.get("rank", 1)),
		"rank_label": _roman_level(int(machine.get("rank", 1))),
		"kind": "facility_v06",
		"persistent": false,
		"is_upgrade": false,
		"selected": selected,
		"strategy_route": "城市发展",
		"purchase_state": state,
		"price": price,
		"play_share_required": 0,
		"play_requirement_text": "条件：I级城市发展无产业资产门槛",
		"play_cash_cost": 0,
		"target_kind": "current_district",
		"effect_text": str(player_text.get("effect", player_text.get("short_effect", ""))),
		"key_rule_facts": key_rule_facts,
		"art_stats": "v0.6 城市设施",
		"theme_color": "#38bdf8",
		"detail_tooltip": str(player_text.get("next_step", "购买后从手牌选择并部署到区域。")),
		"primary_type_label": str(player_text.get("type", "城市设施")),
		"card_face_facts": {
			"quick_effect": str(player_text.get("short_effect", "")),
			"use_case": str(player_text.get("next_step", "")),
			"route_text": "v0.6 CardFlow",
			"level_text": _level_text(int(machine.get("rank", 1))),
		},
	}


func _is_v06_facility_card_id(card_id: String) -> bool:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("v06_card_definition"):
		return false
	var value_variant: Variant = coordinator.call("v06_card_definition", card_id)
	if not (value_variant is Dictionary):
		return false
	var machine: Dictionary = (value_variant as Dictionary).get("machine", {}) if (value_variant as Dictionary).get("machine", {}) is Dictionary else {}
	return str(machine.get("category_id", "")) == "facility" and int(machine.get("rank", 0)) == 1


func _preview_v06_facility_card(card_id: String) -> void:
	if not _is_v06_facility_card_id(card_id):
		return
	previewed_district_card = card_id
	_complete_scenario_signal("card_previewed", "查看城市设施牌。", "rack_open", "district_supply")
	_refresh_ui()


func _purchase_v06_first_table_facility_card(card_id: String) -> void:
	var player_index := _local_human_player_index()
	var district_index := district_supply_open_district
	if player_index < 0 or player_index >= players.size() or district_index < 0 or district_index >= districts.size() or not _is_v06_facility_card_id(card_id):
		return
	var coordinator := _game_runtime_coordinator_node()
	var actor_id := _v06_actor_id(player_index)
	var market_variant: Variant = coordinator.call("v06_first_table_facility_market_snapshot", actor_id)
	var market_snapshot: Dictionary = market_variant if market_variant is Dictionary else {}
	var listing: Dictionary = market_snapshot.get("listing", {}) if market_snapshot.get("listing", {}) is Dictionary else {}
	var listed_card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	var listed_machine: Dictionary = listed_card.get("machine", {}) if listed_card.get("machine", {}) is Dictionary else {}
	if not bool(market_snapshot.get("ready", false)) or str(listed_machine.get("card_id", "")) != card_id:
		_log("城市设施牌市场已经刷新，请重新选择。")
		return
	var source_item_id := str(listing.get("item_id", ""))
	var market: Dictionary = market_snapshot.get("market", {}) if market_snapshot.get("market", {}) is Dictionary else {}
	var transaction_id := "vs06-facility-purchase:%s:%s:%d" % [actor_id, source_item_id, int(market.get("revision", 0))]
	var result_variant: Variant = coordinator.call("purchase_v06_first_table_facility_card", actor_id, source_item_id, transaction_id)
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	if bool(result.get("committed", false)):
		var price := int(result.get("canonical_price_cash", 0))
		players[player_index]["card_purchase_count"] = int(players[player_index].get("card_purchase_count", 0)) + 1
		players[player_index]["total_card_spend"] = int(players[player_index].get("total_card_spend", 0)) + price
		_log("已购买一张I级城市设施牌；现金¥-%d。" % price)
		_complete_scenario_signal("card_bought", "购买城市设施牌。", "after_buy", "district_supply")
	else:
		var feedback: Dictionary = result.get("feedback", {}) if result.get("feedback", {}) is Dictionary else {}
		_log("城市设施牌未购买：%s %s" % [str(feedback.get("reason", "操作没有完成。")), str(feedback.get("next_step", "请刷新后重试。"))])
	_refresh_ui()


func _district_supply_card_source(district_index: int, card_name: String, player_index: int, selected: bool) -> Dictionary:
	var skill := _game_runtime_coordinator_node().card_definition(card_name)
	if skill.is_empty():
		return {}
	var state := _district_supply_purchase_state(district_index, card_name, player_index)
	var state_source := state.duplicate(true)
	var state_accent: Color = state.get("accent", Color("#94a3b8")) as Color
	state_source["accent"] = "#%s" % state_accent.to_html(true)
	var price := int(state.get("price", 0))
	var rank := maxi(1, _game_runtime_coordinator_node().card_rank(card_name))
	var key_rule_facts: Array = []
	for fact_variant: Variant in _card_presentation_array(skill, "key_rule_facts"):
		key_rule_facts.append(str(fact_variant))
	var theme_color := _card_presentation_color(skill)
	var requirement := _card_play_requirement_snapshot(player_index, skill, {"selected_district": district_index})
	return {
		"card_name": card_name,
		"display_name": _card_display_name(card_name),
		"icon": _card_presentation_text(skill, "icon", card_name),
		"rank": rank,
		"rank_label": _roman_level(rank),
		"kind": str(skill.get("kind", "")),
		"persistent": bool(skill.get("persistent", false)),
		"is_upgrade": _is_upgrade_card(card_name),
		"selected": selected,
		"strategy_route": _card_presentation_text(skill, "strategy_route_label"),
		"purchase_state": state_source,
		"price": price,
		"play_share_required": int(requirement.get("required_share_percent", 0)),
		"play_requirement_text": String(requirement.get("requirement_text", "条件：无")),
		"play_cash_cost": int(requirement.get("cash_cost", 0)),
		"target_kind": _district_supply_target_kind(skill),
		"effect_text": _skill_display_text(skill),
		"key_rule_facts": key_rule_facts,
		"art_stats": _card_presentation_text(skill, "art_stats"),
		"theme_color": "#%s" % theme_color.to_html(true),
		"detail_tooltip": _card_presentation_detail_tooltip(card_name, district_index),
		"primary_type_label": _card_presentation_text(skill, "type_label"),
		"card_face_facts": {
			"quick_effect": _card_presentation_text(skill, "quick_effect_compact", card_name),
			"use_case": _card_presentation_text(skill, "use_case", card_name),
			"route_text": _card_presentation_text(skill, "face_route_compact", card_name),
			"level_text": _level_text(rank),
		},
	}


func _district_supply_target_kind(skill: Dictionary) -> String:
	var target := _card_play_target_snapshot(skill)
	if bool(target.get("targets_monster", false)):
		return "monster"
	if bool(target.get("targets_player", false)):
		return "player"
	match str(skill.get("kind", "")):
		"area_trade_contract": return "district_pair"
		"monster_card": return "monster_deploy"
		"military_force": return "military_deploy"
	return "current_district"


func _on_district_supply_action_requested(action_id: String, payload: Dictionary) -> void:
	var card_id := str(payload.get("card_name", ""))
	match action_id:
		"district_supply_close":
			_close_district_supply_overlay()
		"district_supply_preview_card":
			if _is_v06_facility_card_id(card_id):
				_preview_v06_facility_card(card_id)
			elif str(payload.get("source", "")) == "hover":
				_preview_district_card(card_id, true)
			else:
				_select_district_card_for_quote(card_id, true)
		"district_supply_purchase_card":
			if _is_v06_facility_card_id(card_id):
				_purchase_v06_first_table_facility_card(card_id)
			else:
				_claim_district_card(card_id)


func _district_supply_purchase_state(district_index: int, card_name: String, player_index: int) -> Dictionary:
	var supply_revision := str(districts[district_index].get("card_choices", [])) if district_index >= 0 and district_index < districts.size() else ""
	var quote := _active_card_market_quote(card_name, district_index, player_index, supply_revision)
	var preview := _card_market_preview(card_name, district_index)
	var price_source := quote if not quote.is_empty() else preview
	var state := {
		"label": "仅浏览",
		"detail": "可以查看卡面；来源区域受光时才可购买。",
		"actionable": false,
		"requires_discard": false,
		"price": int(price_source.get("final_price", _card_price(card_name))),
		"accent": Color("#94a3b8"),
		"quote_id": str(quote.get("quote_id", "")),
		"quote_fingerprint": str(quote.get("quote_fingerprint", "")),
	}
	if _runtime_session_finished():
		state["label"] = "已结束"
		state["detail"] = "本局已结束，不能购买。"
		return state
	if player_index < 0 or player_index >= players.size():
		state["label"] = "不可用"
		state["detail"] = "没有有效玩家。"
		return state
	if district_index < 0 or district_index >= districts.size() or bool(districts[district_index].get("destroyed", false)):
		state["label"] = "区域无效"
		state["detail"] = "目标区域无效或已被破坏。"
		return state
	if card_name == "" or not _game_runtime_coordinator_node().card_exists(card_name) or not _district_has_card(district_index, card_name):
		state["label"] = "未投放"
		state["detail"] = "这张牌不在当前区域市场。"
		return state
	var availability_text := _district_market_availability_text(district_index)
	if quote.is_empty():
		state["label"] = "选择以报价"
		state["detail"] = "%s 选择此牌后锁定资格与价格5个世界秒。" % availability_text
		return state
	if not bool(quote.get("quote_active", false)):
		state["label"] = "报价已过期"
		state["detail"] = "重新选择此牌以获取新报价；界面刷新不会自动续期。"
		return state
	if not bool(quote.get("eligible", false)):
		state["label"] = "仅浏览"
		state["detail"] = availability_text
		return state
	var player: Dictionary = players[player_index]
	var price := int(state.get("price", 0))
	if int(player.get("cash", 0)) < price:
		state["label"] = "资金不足"
		state["detail"] = "需要¥%d；当前资金不足。" % price
		state["accent"] = Color("#fb7185")
		return state
	if not _player_can_receive_card_with_discard(player, card_name):
		state["label"] = "无法接收"
		state["detail"] = "可能已经达到IV级，或没有可私密弃掉的普通手牌。"
		state["accent"] = Color("#fb7185")
		return state
	if _purchase_requires_discard(player, card_name):
		state["label"] = "需弃牌"
		state["detail"] = "手牌已满；购买后会先进入私密弃牌确认。"
		state["actionable"] = true
		state["requires_discard"] = true
		state["accent"] = Color("#facc15")
		return state
	state["label"] = "可购买"
	var pressure_text := "无怪兽影响" if int(quote.get("multiplier_q2", 2)) == 2 else "怪兽压力×%.1f" % (float(quote.get("multiplier_q2", 2)) / 2.0)
	state["detail"] = "%s 当前价¥%d；%s。" % [availability_text, price, pressure_text]
	state["actionable"] = true
	state["accent"] = Color("#22c55e")
	return state


func _resolved_card_market_player_index(player_index: int = -1) -> int:
	if player_index >= 0:
		return player_index
	return selected_player


func _open_district_card_purchase_window(district_index: int, player_index: int = -1, preserve_pending_discard: bool = false) -> void:
	var resolved_player := _resolved_card_market_player_index(player_index)
	if not preserve_pending_discard and not pending_discard_purchase.is_empty():
		var pending_player := int(pending_discard_purchase.get("player_index", -1))
		var pending_district := int(pending_discard_purchase.get("district_index", -1))
		if pending_player != resolved_player or pending_district != district_index:
			pending_discard_purchase = {}
	if district_index < 0 or district_index >= districts.size() or resolved_player < 0 or resolved_player >= players.size():
		return
	if district_supply_overlay != null and district_supply_overlay.visible:
		district_supply_open_district = district_index
		district_supply_open_player = resolved_player
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator == null or not runtime_coordinator.has_method("open_district_purchase_window"):
		return
	runtime_coordinator.call("open_district_purchase_window", resolved_player, district_index, {
		"supply_revision": str(districts[district_index].get("card_choices", [])),
	})
	if preserve_pending_discard and not pending_discard_purchase.is_empty() and runtime_coordinator.has_method("reserve_district_purchase_discard"):
		runtime_coordinator.call("reserve_district_purchase_discard", {
			"player_index": resolved_player,
			"district_index": district_index,
			"card_id": str(pending_discard_purchase.get("skill_name", "")),
		})


func _select_player(index: int) -> void:
	if index < 0 or index >= players.size():
		return
	selected_player = index
	inspected_player = index
	selected_runtime_card_slot = -1
	if district_supply_overlay != null and district_supply_overlay.visible and district_supply_open_district >= 0:
		district_supply_open_player = _local_human_player_index()
		_open_district_card_purchase_window(district_supply_open_district, district_supply_open_player)
	_load_selected_district_guess()
	_refresh_ui()


func _select_district(index: int) -> void:
	if not _jump_to_district_on_table(index):
		return
	_mark_first_run_coach_district_seen(selected_player)
	_sync_selected_district_card()
	_load_selected_district_guess()
	if selected_district >= 0 and selected_district < districts.size():
		_complete_scenario_signal("district_selected", "选择区域：%s。" % String(districts[selected_district].get("name", "区域")), "after_select", "planet")
	_refresh_ui()


func _has_pending_target_choice() -> bool:
	return pending_target_player_index >= 0 and pending_target_slot_index >= 0


func _has_pending_player_target_choice() -> bool:
	return pending_player_target_player_index >= 0 and pending_player_target_slot_index >= 0


func _has_pending_blocking_decision() -> bool:
	_sync_forced_decision_runtime()
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null:
		return false
	var global_blocked := coordinator.has_method("blocks_global_time") and bool(coordinator.call("blocks_global_time"))
	var player_blocked := coordinator.has_method("blocks_player_actions") and bool(coordinator.call("blocks_player_actions", selected_player))
	return global_blocked or player_blocked


func _pending_target_skill() -> Dictionary:
	if pending_target_player_index < 0 or pending_target_player_index >= players.size():
		return {}
	var player: Dictionary = players[pending_target_player_index]
	if pending_target_slot_index < 0 or pending_target_slot_index >= player["slots"].size():
		return {}
	var skill = player["slots"][pending_target_slot_index]
	if skill == null:
		return {}
	return skill as Dictionary


func _pending_player_target_skill() -> Dictionary:
	if pending_player_target_player_index < 0 or pending_player_target_player_index >= players.size():
		return {}
	var player: Dictionary = players[pending_player_target_player_index]
	if pending_player_target_slot_index < 0 or pending_player_target_slot_index >= player["slots"].size():
		return {}
	var skill = player["slots"][pending_player_target_slot_index]
	if skill == null:
		return {}
	return skill as Dictionary


func _begin_target_monster_choice(slot_index: int) -> void:
	if selected_player < 0 or selected_player >= players.size():
		return
	var player: Dictionary = players[selected_player]
	if slot_index < 0 or slot_index >= player["slots"].size():
		return
	var skill = player["slots"][slot_index]
	if skill == null:
		return
	if not _authorize_card_play(selected_player, skill as Dictionary, true):
		return
	pending_target_player_index = selected_player
	pending_target_slot_index = slot_index
	pending_target_paused_time = false
	_log("匿名打出%s：请选择一个目标怪兽；选定后会进入全局卡牌结算队列。" % _card_display_name(String(skill["name"])))
	_refresh_ui()


func _begin_target_player_choice(slot_index: int) -> void:
	if selected_player < 0 or selected_player >= players.size():
		return
	var player: Dictionary = players[selected_player]
	if slot_index < 0 or slot_index >= player["slots"].size():
		return
	var skill = player["slots"][slot_index]
	if skill == null:
		return
	if not _authorize_card_play(selected_player, skill as Dictionary, true):
		return
	pending_player_target_player_index = selected_player
	pending_player_target_slot_index = slot_index
	_log("匿名打出%s：请选择一个目标玩家；目标会公开，出牌者仍匿名。" % _card_display_name(String(skill["name"])))
	_refresh_ui()


func _clear_pending_target_choice(resume_time := true) -> void:
	pending_target_player_index = -1
	pending_target_slot_index = -1
	if resume_time and pending_target_paused_time and not _runtime_session_finished() and (menu_overlay == null or not menu_overlay.visible):
		time_scale = max(1.0, speed_before_target_choice)
	pending_target_paused_time = false


func _clear_pending_player_target_choice() -> void:
	pending_player_target_player_index = -1
	pending_player_target_slot_index = -1


func _cancel_pending_target_choice() -> void:
	if not _has_pending_target_choice():
		return
	var skill := _pending_target_skill()
	var card_label := _card_display_name(String(skill.get("name", "")))
	if card_label == "":
		card_label = "卡牌"
	_log("已取消%s的目标选择，卡牌未消耗。" % card_label)
	_clear_pending_target_choice()
	_refresh_ui()


func _cancel_pending_player_target_choice() -> void:
	if not _has_pending_player_target_choice():
		return
	var skill := _pending_player_target_skill()
	var card_label := _card_display_name(String(skill.get("name", "")))
	if card_label == "":
		card_label = "卡牌"
	_log("已取消%s的目标玩家选择，卡牌未消耗。" % card_label)
	_clear_pending_player_target_choice()
	_refresh_ui()


func _choose_pending_target_monster(slot: int) -> void:
	if not _has_pending_target_choice():
		return
	if pending_target_player_index < 0 or pending_target_player_index >= players.size():
		_clear_pending_target_choice()
		_refresh_ui()
		return
	var player: Dictionary = players[pending_target_player_index]
	if pending_target_slot_index < 0 or pending_target_slot_index >= player["slots"].size():
		_clear_pending_target_choice()
		_refresh_ui()
		return
	var skill = player["slots"][pending_target_slot_index]
	if skill == null:
		_clear_pending_target_choice()
		_refresh_ui()
		return
	if not _authorize_card_play(pending_target_player_index, skill as Dictionary, true):
		_clear_pending_target_choice()
		_refresh_ui()
		return
	if slot < 0 or slot >= monster_runtime_controller.auto_monsters.size() or bool((monster_runtime_controller.auto_monsters[slot] as Dictionary).get("down", false)):
		_log("目标怪兽无效，请重新选择。")
		_refresh_ui()
		return
	if _queue_skill_resolution(pending_target_player_index, pending_target_slot_index, slot):
		_clear_pending_target_choice(true)
	_refresh_ui()


func _choose_pending_target_player(target_player: int) -> void:
	if not _has_pending_player_target_choice():
		return
	if pending_player_target_player_index < 0 or pending_player_target_player_index >= players.size():
		_clear_pending_player_target_choice()
		_refresh_ui()
		return
	var player: Dictionary = players[pending_player_target_player_index]
	if pending_player_target_slot_index < 0 or pending_player_target_slot_index >= player["slots"].size():
		_clear_pending_player_target_choice()
		_refresh_ui()
		return
	var skill = player["slots"][pending_player_target_slot_index]
	if skill == null:
		_clear_pending_player_target_choice()
		_refresh_ui()
		return
	if not _authorize_card_play(pending_player_target_player_index, skill as Dictionary, true):
		_clear_pending_player_target_choice()
		_refresh_ui()
		return
	if target_player < 0 or target_player >= players.size() or target_player == pending_player_target_player_index:
		_log("目标玩家无效，请重新选择。")
		_refresh_ui()
		return
	if _queue_skill_resolution(pending_player_target_player_index, pending_player_target_slot_index, -1, target_player):
		_clear_pending_player_target_choice()
	_refresh_ui()


func _queue_monster_card_as_counter(player_index: int, slot_index: int, source_skill: Dictionary) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var player: Dictionary = players[player_index]
	var slots: Array = player.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return false
	var counter_rank := clampi(_game_runtime_coordinator_node().card_rank(String(source_skill.get("name", ""))), 1, 4)
	var counter_skill := _make_skill("相位否决%d" % counter_rank)
	if counter_skill.is_empty():
		return false
	counter_skill["source_card_name"] = String(source_skill.get("name", "怪兽牌"))
	counter_skill["text"] = "%s（由%s临时改写；会消耗该怪兽牌。）" % [
		String(counter_skill.get("text", "")),
		_card_display_name(String(source_skill.get("name", "怪兽牌"))),
	]
	var original_skill := (slots[slot_index] as Dictionary).duplicate(true)
	slots[slot_index] = counter_skill
	player["slots"] = slots
	players[player_index] = player
	var queued := _queue_skill_resolution(player_index, slot_index, -1)
	if queued:
		_log("%s触发角色被动：一张怪兽牌被临时改写为相位否决并进入匿名反制等待。" % _player_name(player_index))
		return true
	player = players[player_index]
	slots = player.get("slots", [])
	if slot_index >= 0 and slot_index < slots.size():
		slots[slot_index] = original_skill
		player["slots"] = slots
		players[player_index] = player
	return false


func _resolve_targeted_skill(skill: Dictionary, player: Dictionary, target_slot: int, acting_player_index: int = -1) -> bool:
	if String(skill.get("kind", "")) == "military_command":
		return military_runtime_controller.trigger_command(skill, target_slot, acting_player_index)
	return monster_runtime_controller.resolve_targeted_skill(skill, player, target_slot, acting_player_index, selected_district)


func _cycle_district(step: int) -> void:
	if districts.is_empty():
		return
	_jump_to_district_on_table(wrapi(selected_district + step, 0, districts.size()))
	_sync_selected_district_card()
	_load_selected_district_guess()
	_refresh_ui()


func _set_configured_player_count(count: int) -> void:
	configured_player_count = clampi(count, MIN_PLAYER_COUNT, MAX_PLAYER_COUNT)
	_ensure_configured_ai_player_count()
	_ensure_configured_role_indices()
	_ensure_configured_starter_monster_indices()
	_save_settings(false)
	_log("下次开局玩家数设置为：%d席，其中AI %d个。" % [configured_player_count, configured_ai_player_count])
	_refresh_ui()


func _ensure_configured_ai_player_count() -> void:
	configured_player_count = clampi(configured_player_count, MIN_PLAYER_COUNT, MAX_PLAYER_COUNT)
	var max_ai := mini(MAX_AI_PLAYER_COUNT, configured_player_count - 1)
	configured_ai_player_count = clampi(configured_ai_player_count, MIN_AI_PLAYER_COUNT, max_ai)


func _set_configured_ai_player_count(count: int) -> void:
	_ensure_configured_ai_player_count()
	var max_ai := mini(MAX_AI_PLAYER_COUNT, configured_player_count - 1)
	configured_ai_player_count = clampi(count, MIN_AI_PLAYER_COUNT, max_ai)
	_ensure_configured_role_indices()
	_save_settings(false)
	_log("下次开局电脑对手数设置为：%d个；真人/本地玩家席位%d个。" % [configured_ai_player_count, _configured_human_player_count()])
	_refresh_ui()


func _ensure_configured_roguelike_depth() -> void:
	configured_roguelike_depth = clampi(configured_roguelike_depth, ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX)


func _set_configured_roguelike_depth(depth: int) -> void:
	configured_roguelike_depth = clampi(depth, ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX)
	_save_settings(false)
	var profile := _roguelike_planet_profile(configured_roguelike_depth)
	_log("下次开局挑战层级设为%s：约%d-%d区；本局胜利门槛将按当前存续区域动态计算，当前为控制%d区且前K区GDP达到%d/min。" % [
		_roguelike_depth_label(configured_roguelike_depth),
		int(profile.get("region_min", MAP_REGION_COUNT_MIN)),
		int(profile.get("region_max", MAP_REGION_COUNT_MAX)),
		_victory_required_regions(),
		_victory_required_gdp(),
	])
	_refresh_ui()


func _configured_human_player_count() -> int:
	_ensure_configured_ai_player_count()
	return max(1, configured_player_count - configured_ai_player_count)


func _player_seat_type_for_config_index(player_index: int) -> String:
	return "ai" if player_index >= _configured_human_player_count() else "human"


func _player_is_ai(player_index: int) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var player: Dictionary = players[player_index]
	if player.has("is_ai"):
		return bool(player.get("is_ai", false))
	return String(player.get("seat_type", "human")) == "ai"


func _human_player_count() -> int:
	return max(0, players.size() - _ai_runtime_call("_ai_player_count"))


func _player_facing_text_snapshot() -> Array:
	var result := []
	_collect_player_facing_text(self, result)
	return result


func _collect_player_facing_text(node: Node, result: Array) -> void:
	if node == null:
		return
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label:
		result.append(String((node as Label).text))
	elif node is RichTextLabel:
		result.append(String((node as RichTextLabel).text))
	elif node is Button:
		result.append(String((node as Button).text))
	elif node is LineEdit:
		result.append(String((node as LineEdit).text))
	if node is Control:
		var tooltip := String((node as Control).tooltip_text)
		if tooltip != "":
			result.append(tooltip)
	for child in node.get_children():
		_collect_player_facing_text(child, result)


func _ensure_configured_role_indices() -> void:
	var normalized := []
	var used := {}
	for i in range(MAX_PLAYER_COUNT):
		var value := _player_role_template_index(i)
		if i < configured_role_indices.size():
			value = int(configured_role_indices[i])
		if value == ROLE_RANDOM_INDEX and _player_seat_type_for_config_index(i) == "ai":
			normalized.append(ROLE_RANDOM_INDEX)
			continue
		var role_index := _next_available_configured_role_index(value, used if i < configured_player_count else {})
		normalized.append(role_index)
		if i < configured_player_count:
			used[role_index] = true
	configured_role_indices = normalized


func _next_available_configured_role_index(start_index: int, used: Dictionary) -> int:
	if PLAYER_ROLE_CATALOG.is_empty():
		return 0
	var start := _clamp_role_index(start_index)
	for offset in range(PLAYER_ROLE_CATALOG.size()):
		var candidate := wrapi(start + offset, 0, PLAYER_ROLE_CATALOG.size())
		if not used.has(candidate):
			return candidate
	return start


func _configured_role_used_by_other(player_index: int) -> Dictionary:
	_ensure_configured_ai_player_count()
	var used := {}
	for i in range(configured_player_count):
		if i == player_index or i >= configured_role_indices.size():
			continue
		var value := int(configured_role_indices[i])
		if value >= 0:
			used[_clamp_role_index(value)] = true
	return used


func _ensure_configured_starter_monster_indices() -> void:
	var normalized := []
	for i in range(MAX_PLAYER_COUNT):
		var value := wrapi(i, 0, max(1, _catalog_size()))
		if i < configured_starter_monster_indices.size():
			value = int(configured_starter_monster_indices[i])
		normalized.append(clampi(value, 0, max(0, _catalog_size() - 1)))
	configured_starter_monster_indices = normalized


func _clamp_role_index(index: int) -> int:
	if PLAYER_ROLE_CATALOG.is_empty():
		return 0
	return wrapi(index, 0, PLAYER_ROLE_CATALOG.size())


func _configured_role_index(player_index: int) -> int:
	_ensure_configured_role_indices()
	if player_index < 0 or player_index >= configured_role_indices.size():
		return _player_role_template_index(player_index)
	var value := int(configured_role_indices[player_index])
	if value == ROLE_RANDOM_INDEX:
		return ROLE_RANDOM_INDEX
	return _clamp_role_index(value)


func _configured_starter_monster_index(player_index: int) -> int:
	_ensure_configured_starter_monster_indices()
	if player_index < 0 or player_index >= configured_starter_monster_indices.size():
		return wrapi(player_index, 0, max(1, _catalog_size()))
	return clampi(int(configured_starter_monster_indices[player_index]), 0, max(0, _catalog_size() - 1))


func _set_configured_role_for_player(player_index: int, role_index: int) -> void:
	if player_index < 0 or player_index >= MAX_PLAYER_COUNT:
		return
	_ensure_configured_role_indices()
	if role_index == ROLE_RANDOM_INDEX and _player_seat_type_for_config_index(player_index) == "ai":
		configured_role_indices[player_index] = ROLE_RANDOM_INDEX
	else:
		configured_role_indices[player_index] = _next_available_configured_role_index(role_index, _configured_role_used_by_other(player_index))
	_save_settings(false)
	_log("玩家%d下次开局角色设置为：%s。" % [player_index + 1, _configured_role_selection_label(player_index)])
	_refresh_ui()


func _cycle_configured_role_for_player(player_index: int, step: int) -> void:
	var current := _configured_role_index(player_index)
	if current == ROLE_RANDOM_INDEX:
		current = _player_role_template_index(player_index)
	_set_configured_role_for_player(player_index, current + step)


func _set_configured_role_random_for_player(player_index: int) -> void:
	_set_configured_role_for_player(player_index, ROLE_RANDOM_INDEX)


func _configured_role_selection_label(player_index: int) -> String:
	var role_index := _configured_role_index(player_index)
	if role_index == ROLE_RANDOM_INDEX:
		return "随机角色"
	return String(_make_player_role_card(player_index, role_index).get("name", "外星辛迪加"))


func _resolve_configured_role_indices_for_run() -> Array:
	_ensure_configured_role_indices()
	var resolved := []
	var used := {}
	var random_slots := []
	for i in range(configured_player_count):
		var value := _configured_role_index(i)
		if value == ROLE_RANDOM_INDEX:
			resolved.append(ROLE_RANDOM_INDEX)
			random_slots.append(i)
			continue
		var role_index := _next_available_configured_role_index(value, used)
		resolved.append(role_index)
		used[role_index] = true
	var available := []
	for role_index in range(PLAYER_ROLE_CATALOG.size()):
		if not used.has(role_index):
			available.append(role_index)
	for slot_variant in random_slots:
		var slot := int(slot_variant)
		if available.is_empty():
			available = []
			for role_index in range(PLAYER_ROLE_CATALOG.size()):
				if not used.has(role_index):
					available.append(role_index)
			if available.is_empty():
				available.append(_player_role_template_index(slot))
		var pick := rng.randi_range(0, available.size() - 1)
		var role_index := int(available[pick])
		available.remove_at(pick)
		resolved[slot] = role_index
		used[role_index] = true
	return resolved


func _set_configured_starter_monster_for_player(player_index: int, monster_index: int) -> void:
	if player_index < 0 or player_index >= MAX_PLAYER_COUNT:
		return
	_ensure_configured_starter_monster_indices()
	configured_starter_monster_indices[player_index] = wrapi(monster_index, 0, max(1, _catalog_size()))
	_save_settings(false)
	_log("玩家%d下次开局起始怪兽设置为：%s。" % [
		player_index + 1,
		String(_catalog_entry(_configured_starter_monster_index(player_index)).get("name", "怪兽")),
	])
	_refresh_ui()


func _cycle_configured_starter_monster_for_player(player_index: int, step: int) -> void:
	_set_configured_starter_monster_for_player(player_index, _configured_starter_monster_index(player_index) + step)


func _catalog_size() -> int:
	return MONSTER_ROSTER.size()


func _catalog_entry(index: int) -> Dictionary:
	var clamped_index: int = max(0, min(index, _catalog_size() - 1))
	return MONSTER_ROSTER[clamped_index] as Dictionary


func _monster_art_profile(monster_name: String) -> Dictionary:
	if MONSTER_ART_PROFILES.has(monster_name):
		return MONSTER_ART_PROFILES[monster_name] as Dictionary
	return {
		"accent": Color("#94a3b8"),
		"secondary": Color("#e2e8f0"),
		"glyph": "怪",
		"motif": "beast",
		"subtitle": "自动怪兽｜星兽档案",
	}


func _catalog_move_speed(index: int) -> float:
	var entry: Dictionary = _catalog_entry(index)
	return float(entry.get("move", MonsterRuntimeController.MONSTER_RAMPAGE_MOVE_METERS))


func _monster_mobility_summary_from_fields(traits: Array, terrain_multiplier: Dictionary) -> String:
	var pieces := []
	if traits.has("flying"):
		pieces.append("飞行免碾压")
	if traits.has("aquatic"):
		pieces.append("水栖")
	var ocean := float(terrain_multiplier.get("ocean", 1.0))
	var land := float(terrain_multiplier.get("land", 1.0))
	if absf(ocean - 1.0) > 0.01 or absf(land - 1.0) > 0.01:
		pieces.append("海×%.2f/陆×%.2f" % [ocean, land])
	if pieces.is_empty():
		return "普通步行"
	return "、".join(pieces)


func _monster_catalog_index_by_name(monster_name: String) -> int:
	for i in range(MONSTER_ROSTER.size()):
		var entry: Dictionary = MONSTER_ROSTER[i]
		if String(entry.get("name", "")) == monster_name:
			return i
	return -1


func _monster_card_name(index: int, rank: int = 1) -> String:
	var entry := _catalog_entry(index)
	return "怪兽·%s%d" % [String(entry.get("name", "怪兽")), clampi(rank, 1, 4)]


func _monster_card_names(rank: int = 1) -> Array:
	var result := []
	for i in range(_catalog_size()):
		result.append(_monster_card_name(i, rank))
	return result


func _monster_name_from_card_name(card_name: String) -> String:
	var family := _game_runtime_coordinator_node().card_family_id(card_name)
	var prefix := "怪兽·"
	if not family.begins_with(prefix):
		return ""
	return family.substr(prefix.length())


func _is_monster_card_name(card_name: String) -> bool:
	return _monster_catalog_index_by_name(_monster_name_from_card_name(card_name)) >= 0


func _monster_card_definition(card_name: String) -> Dictionary:
	var monster_name := _monster_name_from_card_name(card_name)
	var catalog_index := _monster_catalog_index_by_name(monster_name)
	if catalog_index < 0:
		return {}
	var rank := clampi(_game_runtime_coordinator_node().card_rank(card_name), 1, 4)
	var entry := _catalog_entry(catalog_index)
	var resource_focus: Array = entry.get("resource_focus", [])
	var supply_product := String(resource_focus[0]) if not resource_focus.is_empty() else "活体芯片"
	var hp_bonus := int(round(float(entry.get("hp", 40)) * (1.0 + float(rank - 1) * 0.22)))
	var move_bonus := float(entry.get("move", MonsterRuntimeController.MONSTER_RAMPAGE_MOVE_METERS)) * (1.0 + float(rank - 1) * 0.10)
	var duration := float(entry.get("duration", MonsterRuntimeController.MONSTER_CARD_DURATION_BASE_SECONDS + float(rank - 1) * MonsterRuntimeController.MONSTER_CARD_DURATION_RANK_STEP_SECONDS))
	var duration_text := "不限时" if duration < 0.0 else "%.0fs" % duration
	var summon_access := String(entry.get("summon_access", "monster_zone"))
	var summon_access_text := _monster_card_region_text({"summon_access": summon_access})
	var movement_traits: Array = (entry.get("movement_traits", []) as Array).duplicate(true)
	var terrain_move_multiplier: Dictionary = (entry.get("terrain_move_multiplier", {}) as Dictionary).duplicate(true)
	var mobility_text := _monster_mobility_summary_from_fields(movement_traits, terrain_move_multiplier)
	return {
		"kind": "monster_card",
		"monster_name": monster_name,
		"catalog_index": catalog_index,
		"cost": 5 + rank,
		"rank": rank,
		"supply_product": supply_product,
		"play_cash_per_monster": MONSTER_CARD_PLAY_CASH_PER_EXISTING,
		"summon_access": summon_access,
		"fixed_skill_count": rank,
		"hp": hp_bonus,
		"duration": duration,
		"move": move_bonus,
		"movement_traits": movement_traits,
		"terrain_move_multiplier": terrain_move_multiplier,
		"damage": 0,
		"range": 0.0,
		"tags": ["怪兽卡", "召唤", _level_text(rank)],
		"text": "召唤%s入场，或升级同名己方怪兽并刷新生命/在场时间。生命%d｜在场%s｜移动%s｜机动:%s｜区域:%s。I级免GDP门槛；II/III/IV级要求任一经营区GDP份额达到15%%/25%%/35%%。获得或刷新%d张固定技能；怪兽仍自动行动。场上每只已有怪兽使费用+¥%d。" % [
			monster_name,
			hp_bonus,
			duration_text,
			_meters_text(move_bonus),
			mobility_text,
			summon_access_text,
			rank,
			MONSTER_CARD_PLAY_CASH_PER_EXISTING,
		],
	}


func _monster_technique_card_name(monster_name: String, action_index: int, rank: int = 1) -> String:
	var catalog_index := _monster_catalog_index_by_name(monster_name)
	var actions := _catalog_actions(catalog_index) if catalog_index >= 0 else []
	var action_name := "招式"
	if action_index >= 0 and action_index < actions.size():
		var action: Dictionary = actions[action_index]
		action_name = String(action.get("name", "招式"))
	return "兽技·%s·%02d%s%d" % [monster_name, action_index + 1, action_name, clampi(rank, 1, 4)]


func _is_monster_technique_card_name(card_name: String) -> bool:
	return _game_runtime_coordinator_node().card_family_id(card_name).begins_with("兽技·")


func _monster_technique_definition(card_name: String) -> Dictionary:
	var family := _game_runtime_coordinator_node().card_family_id(card_name)
	var prefix := "兽技·"
	if not family.begins_with(prefix):
		return {}
	var body := family.substr(prefix.length())
	var pieces := body.split("·")
	if pieces.size() < 2:
		return {}
	var monster_name := String(pieces[0])
	var catalog_index := _monster_catalog_index_by_name(monster_name)
	if catalog_index < 0:
		return {}
	var index_text := String(pieces[1]).left(2)
	var action_index := maxi(0, int(index_text) - 1)
	var actions := _catalog_actions(catalog_index)
	if action_index < 0 or action_index >= actions.size():
		return {}
	var rank := clampi(_game_runtime_coordinator_node().card_rank(card_name), 1, 4)
	var action: Dictionary = (actions[action_index] as Dictionary).duplicate(true)
	var resource_focus: Array = _catalog_entry(catalog_index).get("resource_focus", [])
	var supply_product := String(resource_focus[0]) if not resource_focus.is_empty() else "活体芯片"
	var scaled_action := action.duplicate(true)
	if scaled_action.has("damage"):
		scaled_action["damage"] = maxi(1, int(round(float(scaled_action.get("damage", 1)) * (1.0 + float(rank - 1) * 0.20))))
	if scaled_action.has("move_override") and float(scaled_action.get("move_override", -1.0)) > 0.0:
		scaled_action["move_override"] = float(scaled_action.get("move_override", 0.0)) * (1.0 + float(rank - 1) * 0.08)
	return {
		"kind": "monster_bound_action",
		"monster_name": monster_name,
		"catalog_index": catalog_index,
		"action_index": action_index,
		"action": scaled_action,
		"cost": 2 + rank,
		"rank": rank,
		"persistent": true,
		"cooldown": maxf(2.0, DEFAULT_SKILL_COOLDOWN - float(rank - 1) * 0.25),
		"supply_product": supply_product,
		"damage": int(scaled_action.get("damage", 0)),
		"move": float(scaled_action.get("move_override", 0.0)),
		"range": float(scaled_action.get("range", 0.0)),
		"tags": ["固定技能", monster_name],
		"text": "%s的绑定固定技能：%s。使用后不会消失，但会进入冷却；怪兽本身仍会随机自动行动。" % [
			monster_name,
			String(scaled_action.get("text", "释放怪兽招式。")),
		],
	}


func _catalog_actions(index: int) -> Array:
	var entry: Dictionary = _catalog_entry(index)
	var monster_name := String(entry.get("name", ""))
	if MONSTER_ACTION_TABLES.has(monster_name):
		return MONSTER_ACTION_TABLES[monster_name] as Array
	return MONSTER_ACTION_TABLES["孢雾海皇"] as Array


func _catalog_special_cards(index: int) -> Array:
	var entry: Dictionary = _catalog_entry(index)
	if entry.has("market_skills"):
		return entry.get("market_skills", []) as Array
	if entry.has("special_cards"):
		return entry.get("special_cards", []) as Array
	return []


func _catalog_action_summary(index: int) -> String:
	var actions := _catalog_actions(index)
	var weights := _catalog_action_weights_for_index(index, _has_destroyed_district())
	var total := _weight_total(weights)
	var names := []
	for i in range(actions.size()):
		var weight := int(weights[i])
		if weight <= 0:
			continue
		var action: Dictionary = actions[i]
		names.append("%s %s" % [action["name"], _probability_text(weight, total)])
	return " / ".join(names)


func _catalog_action_weights(actions: Array, any_destroyed: bool) -> Array:
	var source_weights: Array = SPECIAL_MONSTER_ESCALATED_ACTION_WEIGHTS if any_destroyed else SPECIAL_MONSTER_EARLY_ACTION_WEIGHTS
	var weights := []
	for i in range(actions.size()):
		weights.append(int(source_weights[i]) if i < source_weights.size() else 0)
	return weights


func _catalog_action_weights_for_index(index: int, any_destroyed: bool) -> Array:
	var actions := _catalog_actions(index)
	var entry := _catalog_entry(index)
	var monster_name := String(entry.get("name", ""))
	var table: Dictionary = MonsterRuntimeController.MONSTER_SKILL_WEIGHT_TABLES.get(monster_name, {})
	var source_weights: Array = table.get("escalated" if any_destroyed else "early", [])
	if source_weights.is_empty():
		return _catalog_action_weights(actions, any_destroyed)
	var weights := []
	for i in range(actions.size()):
		weights.append(int(source_weights[i]) if i < source_weights.size() else 0)
	return weights


func _ranked_action_weights(source_weights: Array, rank: int) -> Array:
	var weights := source_weights.duplicate()
	var bonus_rank: int = clampi(rank, 1, 4) - 1
	if bonus_rank <= 0:
		return weights
	for i in range(weights.size()):
		var weight := int(weights[i])
		if i >= 3:
			weight += bonus_rank * (i - 1)
		elif i >= 1:
			weight += max(0, bonus_rank - 1)
		weights[i] = weight
	return weights


func _catalog_ranked_action_weights_for_index(index: int, any_destroyed: bool, rank: int) -> Array:
	return _ranked_action_weights(_catalog_action_weights_for_index(index, any_destroyed), rank)


func _action_weight_delta_summary(base_weights: Array, ranked_weights: Array) -> String:
	var chunks := []
	for i in range(min(base_weights.size(), ranked_weights.size())):
		var delta := int(ranked_weights[i]) - int(base_weights[i])
		if delta > 0:
			chunks.append("%d号+%d" % [i + 1, delta])
	return " / ".join(chunks) if not chunks.is_empty() else "无变化"


func _ranked_probability_delta_text(base_weight: int, base_total: int, ranked_weight: int, ranked_total: int) -> String:
	var base_probability := 0.0 if base_total <= 0 else float(base_weight) * 100.0 / float(base_total)
	var ranked_probability := 0.0 if ranked_total <= 0 else float(ranked_weight) * 100.0 / float(ranked_total)
	var delta := ranked_probability - base_probability
	if abs(delta) < 0.5:
		return "±0%"
	var rounded_delta := int(round(delta))
	if rounded_delta > 0:
		return "+%d%%" % rounded_delta
	return "%d%%" % rounded_delta


func _catalog_rank_iv_shift_summary(index: int, any_destroyed: bool = false) -> String:
	var base_weights := _catalog_action_weights_for_index(index, any_destroyed)
	var rank_iv_weights := _catalog_ranked_action_weights_for_index(index, any_destroyed, 4)
	return _action_weight_delta_summary(base_weights, rank_iv_weights)


func _auto_monster_action_probability_text(actor: Dictionary, action_index: int, weights: Array, total: int, any_destroyed: bool) -> String:
	var probability := _probability_text(int(weights[action_index]), total)
	var rank := clampi(int(actor.get("rank", 1)), 1, 4)
	if rank <= 1:
		return probability
	var base_weights := _catalog_action_weights_for_index(int(actor.get("catalog_index", 0)), any_destroyed)
	var base_total := _weight_total(base_weights)
	var delta := _ranked_probability_delta_text(
		int(base_weights[action_index]) if action_index < base_weights.size() else 0,
		base_total,
		int(weights[action_index]),
		total
	)
	return "%s，%s修正%s" % [probability, _level_text(rank), delta]


func _catalog_ranked_probability_line(index: int, action_index: int, any_destroyed: bool, rank: int) -> String:
	var base_weights := _catalog_action_weights_for_index(index, any_destroyed)
	var ranked_weights := _catalog_ranked_action_weights_for_index(index, any_destroyed, rank)
	var base_total := _weight_total(base_weights)
	var ranked_total := _weight_total(ranked_weights)
	var base_weight := int(base_weights[action_index]) if action_index < base_weights.size() else 0
	var ranked_weight := int(ranked_weights[action_index]) if action_index < ranked_weights.size() else 0
	var rank_suffix := ""
	if rank > 1:
		rank_suffix = "（%s修正%s）" % [_level_text(rank), _ranked_probability_delta_text(base_weight, base_total, ranked_weight, ranked_total)]
	return "%s%s" % [
		_probability_text(ranked_weight, ranked_total),
		rank_suffix,
	]


func _catalog_action_numeric_facts(action: Dictionary) -> String:
	var facts := []
	var damage := int(action.get("damage", 0))
	var range_m := float(action.get("range", 0.0))
	var move_override := float(action.get("move_override", -1.0))
	var knockback := float(action.get("knockback", 0.0))
	var armor := int(action.get("armor", 0))
	var heal := int(action.get("self_heal", 0))
	var self_damage := int(action.get("self_damage", 0))
	if damage > 0:
		facts.append("招式伤害%d" % damage)
	if range_m > 0.0:
		facts.append("射程%s" % _meters_text(range_m))
	else:
		facts.append("贴近/移动")
	if move_override >= 0.0:
		facts.append("移动%s" % _meters_text(move_override))
	if knockback > 0.5:
		facts.append("击退%s" % _meters_text(knockback))
	if armor > 0:
		facts.append("护甲+%d" % armor)
	if heal > 0:
		facts.append("自愈%d" % heal)
	if self_damage > 0:
		facts.append("反冲%d" % self_damage)
	return "｜".join(facts)

func _compact_card_list(cards: Array, limit: int) -> String:
	if cards.is_empty():
		return "无专属卡"
	var names := []
	for i in range(min(limit, cards.size())):
		names.append(String(cards[i]))
	var suffix := ""
	if cards.size() > names.size():
		suffix = " 等%d张" % cards.size()
	return "%s%s" % [" / ".join(names), suffix]


func _append_unique_cards(result: Array, names: Array) -> void:
	for name_variant in names:
		var skill_name := _canonical_card_supply_name(String(name_variant))
		if skill_name == "" or result.has(skill_name):
			continue
		if not _game_runtime_coordinator_node().card_exists(skill_name):
			push_warning("卡牌目录缺少：%s" % skill_name)
			continue
		result.append(skill_name)


func _canonical_card_supply_name(skill_name: String) -> String:
	if skill_name == "":
		return ""
	var rank := _game_runtime_coordinator_node().card_rank(skill_name)
	if rank <= 0:
		return skill_name if _game_runtime_coordinator_node().card_exists(skill_name) else ""
	var base_name := "%s1" % _game_runtime_coordinator_node().card_family_id(skill_name)
	return base_name if _game_runtime_coordinator_node().card_exists(base_name) else ""


func _current_run_product_names() -> Array:
	var result := []
	for i in range(districts.size()):
		var district_variant: Variant = districts[i]
		if not (district_variant is Dictionary):
			continue
		var district: Dictionary = district_variant
		for product_variant in district.get("products", []):
			monster_runtime_controller._append_unique_string(result, String(product_variant))
		for demand_variant in district.get("demands", []):
			monster_runtime_controller._append_unique_string(result, String(demand_variant))
		var city := _district_city(i)
		if _city_is_active(city):
			for product_name_variant in _city_product_names(city):
				monster_runtime_controller._append_unique_string(result, String(product_name_variant))
			for demand_name_variant in _city_demand_names(city):
				monster_runtime_controller._append_unique_string(result, String(demand_name_variant))
	return result


func _district_local_product_names(district_index: int) -> Array:
	var result := []
	if district_index < 0 or district_index >= districts.size():
		return result
	var district: Dictionary = districts[district_index]
	for product_variant in district.get("products", []):
		monster_runtime_controller._append_unique_string(result, String(product_variant))
	for demand_variant in district.get("demands", []):
		monster_runtime_controller._append_unique_string(result, String(demand_variant))
	var city := _district_city(district_index)
	if _city_is_active(city):
		for product_name_variant in _city_product_names(city):
			monster_runtime_controller._append_unique_string(result, String(product_name_variant))
		for demand_name_variant in _city_demand_names(city):
			monster_runtime_controller._append_unique_string(result, String(demand_name_variant))
	return result


func _skill_fixed_product_requirements(skill: Dictionary) -> Array:
	var result := []
	var supply_product := String(skill.get("supply_product", skill.get("play_product", "")))
	if supply_product != "":
		monster_runtime_controller._append_unique_string(result, supply_product)
	var contract_products_variant: Variant = skill.get("contract_products", [])
	if contract_products_variant is Array:
		for product_variant in contract_products_variant:
			monster_runtime_controller._append_unique_string(result, String(product_variant))
	return result


func _product_requirements_available(required_products: Array, run_products: Array) -> bool:
	if required_products.is_empty():
		return true
	if run_products.is_empty():
		return true
	for product_variant in required_products:
		if not run_products.has(String(product_variant)):
			return false
	return true


func _skill_uses_current_product(skill: Dictionary) -> bool:
	var kind := String(skill.get("kind", ""))
	if ["product_speculation", "product_futures", "product_contract_boon", "product_growth_boon", "market_stabilize", "city_product_shift", "city_demand_shift"].has(kind):
		return true
	if kind == "area_trade_contract" and String(skill.get("contract_product_mode", "selected")) != "fixed":
		return true
	if int(skill.get("market_demand_pressure", 0)) != 0 or int(skill.get("market_supply_pressure", 0)) != 0:
		return true
	return false


func _card_allowed_by_run_products(skill_name: String) -> bool:
	var canonical_name := _canonical_card_supply_name(skill_name)
	if canonical_name == "":
		return false
	var skill := _game_runtime_coordinator_node().card_definition(canonical_name)
	if skill.is_empty():
		return false
	if String(skill.get("kind", "")) == "monster_card":
		return _monster_card_allowed_by_run_products(canonical_name)
	var required_products := _skill_fixed_product_requirements(skill)
	return _product_requirements_available(required_products, _current_run_product_names())


func _monster_card_allowed_by_run_products(skill_name: String) -> bool:
	# Every region reserves a stable monster-card slot. Product and terrain
	# affinity decide *where* each monster is offered, not whether the family is
	# deleted from the run entirely.
	return _is_monster_card_name(skill_name)


func _run_allowed_monster_card_names(rank: int = 1) -> Array:
	var matched := []
	var all_cards := _monster_card_names(rank)
	for card_variant in all_cards:
		var card_name := String(card_variant)
		if _monster_card_allowed_by_run_products(card_name):
			matched.append(card_name)
	if matched.is_empty():
		return all_cards
	return matched


func _district_card_is_valid_for_district(district_index: int, skill_name: String) -> bool:
	return _district_card_affinity_score(district_index, skill_name) >= 0


func _district_card_affinity_score(district_index: int, skill_name: String) -> int:
	var canonical_name := _canonical_card_supply_name(skill_name)
	if canonical_name == "" or district_index < 0 or district_index >= districts.size():
		return -999
	if not _card_allowed_by_run_products(canonical_name):
		return -999
	var skill := _game_runtime_coordinator_node().card_definition(canonical_name)
	if skill.is_empty():
		return -999
	var local_products := _district_local_product_names(district_index)
	var terrain := String(districts[district_index].get("terrain", "land"))
	if String(skill.get("kind", "")) == "monster_card":
		return _monster_card_district_affinity_score(skill, district_index, local_products, terrain)
	var required_products := _skill_fixed_product_requirements(skill)
	if not required_products.is_empty():
		var local_match := false
		for product_variant in required_products:
			if local_products.has(String(product_variant)):
				local_match = true
				break
		return 230 if local_match else -999
	var score := 20
	if _skill_uses_current_product(skill):
		if local_products.is_empty():
			return -999
		score += 90
	var kind := String(skill.get("kind", ""))
	if terrain == "ocean" and ["weather_control", "route_flow_boon", "route_insurance", "product_contract_boon"].has(kind):
		score += 45
	if terrain == "land" and ["city_revenue_boost", "city_product_upgrade", "city_product_shift", "region_economy_shift"].has(kind):
		score += 35
	return score


func _monster_card_district_affinity_score(skill: Dictionary, _district_index: int, local_products: Array, terrain: String) -> int:
	var monster_name := String(skill.get("monster_name", ""))
	var catalog_index := _monster_catalog_index_by_name(monster_name)
	if catalog_index < 0:
		return 20
	var entry := _catalog_entry(catalog_index)
	var score := 35
	var summon_access := String(skill.get("summon_access", entry.get("summon_access", "monster_zone")))
	if summon_access == "ocean_monster_zone" or summon_access == "ocean":
		if terrain != "ocean":
			return -999
		score += 95
	elif summon_access == "land_monster_zone" or summon_access == "land":
		if terrain != "land":
			return -999
		score += 75
	var focus: Array = entry.get("resource_focus", [])
	var matched_focus := false
	for product_variant in focus:
		if local_products.has(String(product_variant)):
			matched_focus = true
			score += 130
	if not focus.is_empty() and not matched_focus:
		return -999
	var traits: Array = entry.get("movement_traits", [])
	if terrain == "ocean" and traits.has("aquatic"):
		score += 70
	if terrain == "land" and not traits.has("aquatic"):
		score += 20
	return score


func _district_card_candidate_pool(district_index: int) -> Array:
	var priority := []
	var secondary := []
	var fallback := []
	for skill_name_variant in _current_run_card_pool():
		var skill_name := String(skill_name_variant)
		var score := _district_card_affinity_score(district_index, skill_name)
		if score < 0:
			continue
		if score >= 150:
			priority.append(skill_name)
		elif score >= 70:
			secondary.append(skill_name)
		else:
			fallback.append(skill_name)
	return _shuffled_card_list(priority) + _shuffled_card_list(secondary) + _shuffled_card_list(fallback)


func _district_random_card_candidate_pool(district_index: int) -> Array:
	var result := []
	for card_variant in _district_card_candidate_pool(district_index):
		var card_name := _canonical_card_supply_name(String(card_variant))
		if card_name == "" or _is_reserved_district_supply_card(card_name):
			continue
		result.append(card_name)
	return result


func _district_card_supply_source_label(district_index: int, skill_name: String) -> String:
	var canonical_name := _canonical_card_supply_name(skill_name)
	if canonical_name == "":
		return "区域补给"
	var skill := _game_runtime_coordinator_node().card_definition(canonical_name)
	if skill.is_empty():
		return "区域补给"
	var local_products := _district_local_product_names(district_index)
	if String(skill.get("kind", "")) == "public_facility":
		return "公共设施｜%s%s" % [String(skill.get("industry_id", "通用")), String(skill.get("facility_type", "设施"))]
	if String(skill.get("kind", "")) == "monster_card":
		var monster_name := String(skill.get("monster_name", ""))
		var catalog_index := _monster_catalog_index_by_name(monster_name)
		var entry := _catalog_entry(catalog_index) if catalog_index >= 0 else {}
		var focus: Array = entry.get("resource_focus", [])
		for product_variant in focus:
			if local_products.has(String(product_variant)):
				return "怪兽偏好:%s" % String(product_variant)
		var summon_access := String(skill.get("summon_access", entry.get("summon_access", "monster_zone")))
		if summon_access == "ocean_monster_zone" or summon_access == "ocean":
			return "海域怪兽"
		if summon_access == "land_monster_zone" or summon_access == "land":
			return "陆域怪兽"
		return "怪兽卡"
	var required_products := _skill_fixed_product_requirements(skill)
	for product_variant in required_products:
		var product_name := String(product_variant)
		if local_products.has(product_name):
			return "本区商品:%s" % product_name
	if _skill_uses_current_product(skill) and not local_products.is_empty():
		return "本区供需:%s" % String(local_products[0])
	var terrain := String(districts[district_index].get("terrain", "land")) if district_index >= 0 and district_index < districts.size() else "land"
	if terrain == "ocean":
		return "海域补给"
	return "公共补给"


func _current_run_card_pool() -> Array:
	var result := []
	for skill_name_variant in _game_runtime_coordinator_node().card_catalog_public_pool():
		var skill_name := String(skill_name_variant)
		if _card_allowed_by_run_products(skill_name):
			_append_unique_cards(result, [skill_name])
	_append_unique_cards(result, _run_allowed_monster_card_names(1))
	return result


func _monster_action_animation_profile(_monster_name: String, action: Dictionary, _action_index: int = -1) -> Dictionary:
	var action_name := String(action.get("name", "行动"))
	var range_meters := float(action.get("range", 0.0))
	var move_override_mps := float(action.get("move_override", -1.0))
	var knockback_meters := float(action.get("knockback", 0.0))
	var throw_meters := float(action.get("throw_radius", 0.0))
	var damage := int(action.get("damage", 0))
	var motion_family := _monster_action_motion_family(action)
	var profile := {
		"motion_family": motion_family,
		"pose_key": _monster_action_pose_key(action_name),
		"effect_layer": _monster_action_effect_layer(action),
		"range_meters": range_meters,
		"move_override_mps": move_override_mps,
		"knockback_meters": knockback_meters,
		"throw_meters": throw_meters,
		"damage": damage,
		"anticipation_seconds": _monster_action_anticipation_seconds(motion_family, range_meters, move_override_mps),
		"active_seconds": _monster_action_active_seconds(motion_family, range_meters, knockback_meters, throw_meters),
		"recovery_seconds": _monster_action_recovery_seconds(motion_family, damage),
		"impact_seconds": 0.45 if knockback_meters > 0.0 or throw_meters > 0.0 else 0.18,
		"scale_contract": _monster_action_scale_contract(action),
	}
	profile["profile_key"] = _monster_action_animation_profile_key(profile)
	return profile


func _monster_action_animation_profile_key(profile: Dictionary) -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(profile.get("motion_family", "")),
		str(profile.get("pose_key", "")),
		str(profile.get("effect_layer", "")),
		str(profile.get("range_meters", "")),
		str(profile.get("move_override_mps", "")),
		str(profile.get("knockback_meters", "")),
		str(profile.get("throw_meters", "")),
		str(profile.get("damage", "")),
	]


func _monster_action_motion_family(action: Dictionary) -> String:
	var action_name := String(action.get("name", ""))
	var range_meters := float(action.get("range", 0.0))
	var move_override_mps := float(action.get("move_override", -1.0))
	if action.has("throw_radius"):
		return "throw_grapple"
	if action.has("miasma_count"):
		return "miasma_zone"
	if action.has("repair") or action.has("repair_radius") or action.has("repair_path"):
		return "repair_beam"
	if action_name.contains("咆哮"):
		return "roar_wave"
	if action_name.contains("潜"):
		return "burrow_dash"
	if action_name.contains("打滚") or action_name.contains("滚"):
		return "roll_crush"
	if action_name.contains("炸弹") or action_name.contains("爆裂") or action_name.contains("爆弹"):
		return "blast_projectile"
	if action_name.contains("光线") or action_name.contains("射线") or action_name.contains("火花") or action_name.contains("连闪") or range_meters >= 420.0:
		return "beam_line"
	if move_override_mps > 0.0 and int(action.get("damage", 0)) > 0:
		return "dash_melee"
	if float(action.get("knockback", 0.0)) > 0.0:
		return "impact_melee"
	if int(action.get("damage", 0)) > 0:
		return "close_melee"
	return "utility_pose"


func _monster_action_effect_layer(action: Dictionary) -> String:
	var action_name := String(action.get("name", ""))
	if action.has("miasma_count") or action_name.contains("瘴"):
		return "miasma_cloud"
	if action.has("repair") or action.has("repair_radius") or action.has("repair_path"):
		return "repair_green"
	if action.has("paralyze") or action_name.contains("电") or action_name.contains("闪"):
		return "electric_arc"
	if action.has("cripple") or action_name.contains("刃") or action_name.contains("斩"):
		return "blade_arc"
	if action.has("stun") or action.has("knockback") or action.has("throw_radius"):
		return "impact_burst"
	if action_name.contains("火") or action_name.contains("焰") or action_name.contains("爆"):
		return "flame_burst"
	if action_name.contains("泥") or action_name.contains("地"):
		return "ground_crack"
	if action_name.contains("咆哮") or action_name.contains("潮") or action_name.contains("波"):
		return "shock_wave"
	return "body_motion"


func _monster_action_pose_key(action_name: String) -> String:
	var pose_seed := _art_identity_text_seed(action_name)
	return "%s_%03d" % [_monster_action_pose_family(action_name), pose_seed % 997]


func _monster_action_pose_family(action_name: String) -> String:
	if action_name.contains("翼") or action_name.contains("俯冲"):
		return "air_sweep"
	if action_name.contains("冲锋") or action_name.contains("肩撞") or action_name.contains("狂奔"):
		return "charge"
	if action_name.contains("光线") or action_name.contains("射线") or action_name.contains("火花") or action_name.contains("连闪"):
		return "beam"
	if action_name.contains("炸弹") or action_name.contains("爆"):
		return "bomb"
	if action_name.contains("修复") or action_name.contains("藤") or action_name.contains("绿洲"):
		return "support"
	if action_name.contains("瘴") or action_name.contains("腐蚀"):
		return "miasma"
	if action_name.contains("斩") or action_name.contains("刃") or action_name.contains("手刀"):
		return "blade"
	if action_name.contains("泥") or action_name.contains("潜") or action_name.contains("滚"):
		return "earth"
	if action_name.contains("咆哮") or action_name.contains("闪光"):
		return "wave"
	if action_name.contains("拳") or action_name.contains("踢") or action_name.contains("尾") or action_name.contains("掌"):
		return "melee"
	return "pose"


func _monster_action_anticipation_seconds(motion_family: String, range_meters: float, move_override_mps: float) -> float:
	if motion_family == "beam_line" or motion_family == "blast_projectile":
		return 0.32
	if motion_family == "dash_melee" or move_override_mps > 0.0:
		return 0.22
	if motion_family == "throw_grapple":
		return 0.28
	if range_meters <= 140.0:
		return 0.18
	return 0.24


func _monster_action_active_seconds(motion_family: String, range_meters: float, knockback_meters: float, throw_meters: float) -> float:
	if motion_family == "beam_line":
		return clampf(0.28 + range_meters / 2000.0, 0.32, 0.62)
	if motion_family == "throw_grapple":
		return 0.46
	if knockback_meters > 0.0 or throw_meters > 0.0:
		return 0.42
	return 0.30


func _monster_action_recovery_seconds(motion_family: String, damage: int) -> float:
	if motion_family == "blast_projectile" or damage >= 5:
		return 0.58
	if motion_family == "beam_line":
		return 0.42
	return 0.30


func _monster_action_scale_contract(action: Dictionary) -> String:
	var range_meters := float(action.get("range", 0.0))
	var move_override_mps := float(action.get("move_override", -1.0))
	var knockback_meters := float(action.get("knockback", 0.0))
	var throw_meters := float(action.get("throw_radius", 0.0))
	return "range:%sm｜move:%sm/s｜knock:%sm｜throw:%sm｜linear-meter-stage" % [
		_meters_number_text(range_meters),
		_meters_number_text(move_override_mps),
		_meters_number_text(knockback_meters),
		_meters_number_text(throw_meters),
	]


func _meters_number_text(value: float) -> String:
	if value < 0.0:
		return "-"
	return str(int(round(value)))


func _art_identity_text_seed(text: String) -> int:
	var text_seed := 193
	for i in range(text.length()):
		text_seed = (text_seed * 37 + text.unicode_at(i)) % 1000003
	return max(1, text_seed)


func _current_run_featured_cards() -> Array:
	return _run_allowed_monster_card_names(1)


func _current_run_featured_card_sources() -> Dictionary:
	var sources := {}
	for monster_card_variant in _run_allowed_monster_card_names(1):
		var skill_name := String(monster_card_variant)
		sources[skill_name] = "怪兽卡"
	return sources


func _monster_market_skills() -> Array:
	return _current_run_card_pool()


func _skill_tag_text(skill: Dictionary) -> String:
	var tags: Array = skill.get("tags", [])
	if tags.is_empty():
		tags = _derived_skill_tags(String(skill.get("kind", "")))
	return " / ".join(tags)


func _skill_display_text(skill: Dictionary) -> String:
	var text := _player_card_effect_text(skill)
	if monster_runtime_controller.auto_monsters.is_empty():
		return text
	text = text.replace("除自身外，所有已装备卡牌立即+1补给。", "从当前区域额外获取1张候选卡。")
	text = text.replace("除自身外，所有已装备卡牌立即+2补给", "从当前区域额外获取2张候选卡")
	text = text.replace("补给连锁", "补给连锁")
	text = text.replace("补给", "补给")
	text = text.replace("其他怪兽概率行动", "怪兽特殊行动")
	text = text.replace("其他怪兽行动", "怪兽特殊行动")
	return text


func _player_card_effect_text(skill: Dictionary) -> String:
	var kind := String(skill.get("kind", ""))
	match kind:
		"monster_card":
			return "召唤%s：HP%d｜在场%s｜移速%s｜%s。升级同名在场怪兽会刷新生命和时间。" % [
				String(skill.get("monster_name", "怪兽")),
				int(skill.get("hp", 0)),
				_monster_card_duration_text(skill, true),
				_meters_text(float(skill.get("move", 0.0))),
				_monster_card_region_text(skill, true),
			]
		"area_trade_contract":
			return _area_contract_player_effect_text(skill)
		"city_gdp_derivative":
			var terms := _city_gdp_derivative_terms(skill)
			var side := "保单" if bool(terms.get("insurance", false)) else ("买涨" if String(terms.get("direction", "up")) == "up" else "做空")
			return "押目标城市%s：%s｜保证金¥%d｜收益≤¥%d｜损失≤¥%d。" % [
				side,
				_duration_short_text(float(terms.get("duration_seconds", _city_gdp_derivative_duration_seconds(skill)))),
				int(terms.get("margin_cash", 0)),
				int(terms.get("maximum_gain", 0)),
				int(terms.get("maximum_loss", 0)),
			]
		"product_futures":
			var futures_terms: Dictionary = skill.get("futures_terms", {}) if skill.get("futures_terms", {}) is Dictionary else {}
			if futures_terms.is_empty():
				var market_controller := _product_market_runtime_controller_node()
				futures_terms = market_controller.terms_for_card_id(String(skill.get("name", ""))) if market_controller != null else {}
			var side := "看涨" if String(futures_terms.get("direction", "up")) == "up" else "看跌"
			var warehouse := "｜需要仓储城市" if bool(futures_terms.get("requires_warehouse", false)) else ""
			return "押当前商品%s：%s｜保证金¥%d｜收益≤¥%d｜损失≤¥%d%s。" % [
				side,
				_duration_short_text(float(futures_terms.get("duration_seconds", _product_market_futures_duration_seconds(skill)))),
				int(futures_terms.get("margin_cash", 0)),
				int(futures_terms.get("maximum_gain", 0)),
				int(futures_terms.get("maximum_loss", 0)),
				warehouse,
			]
		"weather_control":
			return "改写下一条天气预报：%s｜约%s后影响%d区，持续%s。" % [
				weather_runtime_controller.label(String(skill.get("weather_type", "solar_flare"))),
				_duration_short_text(float(skill.get("weather_forecast_lead_seconds", WeatherRuntimeController.FORECAST_LEAD_MIN_SECONDS))),
				maxi(1, int(skill.get("weather_zone_count", 1))),
				_duration_short_text(float(skill.get("weather_duration_seconds", WeatherRuntimeController.DURATION_MIN_SECONDS))),
			]
		"military_force":
			return "部署%s：HP%d｜伤害%d｜移速%s｜存续%s。" % [
				military_runtime_controller.unit_type_label(skill),
				military_runtime_controller.unit_hp(skill),
				military_runtime_controller.unit_damage(skill),
				_meters_text(float(skill.get("military_move", 0.0))),
				_duration_short_text(military_runtime_controller.unit_duration(skill)),
			]
		"military_command":
			return "军令：%s｜范围%s。军队按指令行动，不会像怪兽一样自动踩城。" % [
				military_runtime_controller.command_label(String(skill.get("military_command", ""))),
				_meters_text(float(skill.get("range", 0.0))),
			]
		"player_hand_disrupt":
			return "指定玩家弃%d张普通手牌%s。" % [
				maxi(1, int(skill.get("hand_discard_count", 1))),
				"｜封锁%s" % _duration_short_text(float(skill.get("hand_lock_seconds", 0.0))) if float(skill.get("hand_lock_seconds", 0.0)) > 0.0 else "",
			]
		"player_hand_steal":
			return "从指定玩家处牵走%d张普通手牌%s。" % [
				maxi(1, int(skill.get("hand_steal_count", 1))),
				"｜封锁%s" % _duration_short_text(float(skill.get("hand_lock_seconds", 0.0))) if float(skill.get("hand_lock_seconds", 0.0)) > 0.0 else "",
			]
		"city_control_dispute":
			return "扰乱目标城市归属：冻结%s｜GDP-%d。" % [
				_duration_short_text(float(skill.get("control_block_seconds", 0.0))),
				int(skill.get("control_gdp_penalty", 0)),
			]
		"global_barrage":
			return "全场齐射：选择%d座城市，各受%d区域伤害%s。" % [
				maxi(1, int(skill.get("global_barrage_target_count", 1))),
				maxi(1, int(skill.get("global_barrage_damage", 1))),
				"｜断路+%d" % int(skill.get("global_barrage_route_damage", 0)) if int(skill.get("global_barrage_route_damage", 0)) > 0 else "",
			]
		"card_counter":
			return "相位响应：%s内可取消一张直接互动牌｜强度%d%s。" % [
				_duration_short_text(float(skill.get("counter_window_seconds", _ruleset_timing_seconds(&"counter_window_seconds")))),
				maxi(1, int(skill.get("counter_strength", 1))),
				"｜返还¥%d" % int(skill.get("counter_refund", 0)) if int(skill.get("counter_refund", 0)) > 0 else "",
			]
	var text := _realtime_rule_text(String(skill.get("text", "即时改变局势。")))
	return _player_sanitize_rule_text(text)


func _area_contract_player_effect_text(skill: Dictionary) -> String:
	var add_text := []
	if int(skill.get("contract_add_products", 0)) > 0:
		add_text.append("供给+%d" % int(skill.get("contract_add_products", 0)))
	if int(skill.get("contract_add_demands", 0)) > 0:
		add_text.append("需求+%d" % int(skill.get("contract_add_demands", 0)))
	if int(skill.get("contract_remove_products", 0)) > 0 or int(skill.get("contract_remove_demands", 0)) > 0:
		add_text.append("替换旧供需")
	var accept_text := []
	if int(skill.get("accept_cash", 0)) > 0:
		accept_text.append("签约¥+%d" % int(skill.get("accept_cash", 0)))
	if int(skill.get("accept_production_delta", 0)) != 0:
		accept_text.append("产能%s" % _signed_int_text(int(skill.get("accept_production_delta", 0))))
	if int(skill.get("accept_transport_delta", 0)) != 0:
		accept_text.append("交通%s" % _signed_int_text(int(skill.get("accept_transport_delta", 0))))
	if int(skill.get("accept_consumption_delta", 0)) != 0:
		accept_text.append("需求%s" % _signed_int_text(int(skill.get("accept_consumption_delta", 0))))
	if float(skill.get("accept_route_flow_multiplier", 1.0)) > 1.001:
		accept_text.append("商路×%.2f" % float(skill.get("accept_route_flow_multiplier", 1.0)))
	var decline_text := []
	if int(skill.get("decline_cash_penalty", 0)) > 0:
		decline_text.append("拒签¥-%d" % int(skill.get("decline_cash_penalty", 0)))
	if int(skill.get("decline_route_damage", 0)) > 0:
		decline_text.append("断路+%d" % int(skill.get("decline_route_damage", 0)))
	if int(skill.get("decline_production_delta", 0)) != 0:
		decline_text.append("产能%s" % _signed_int_text(int(skill.get("decline_production_delta", 0))))
	if int(skill.get("decline_transport_delta", 0)) != 0:
		decline_text.append("交通%s" % _signed_int_text(int(skill.get("decline_transport_delta", 0))))
	if int(skill.get("decline_consumption_delta", 0)) != 0:
		decline_text.append("需求%s" % _signed_int_text(int(skill.get("decline_consumption_delta", 0))))
	return "连接供给区与需求区：%s。目标业主稍后签/拒；%s；%s。" % [
		" / ".join(add_text) if not add_text.is_empty() else "添加一条商品关系",
		" / ".join(accept_text) if not accept_text.is_empty() else "签约有收益",
		" / ".join(decline_text) if not decline_text.is_empty() else "拒签有压力",
	]


func _player_sanitize_rule_text(text: String) -> String:
	var result := text
	result = result.replace("打出前必须先", "先")
	result = result.replace("必须先", "先")
	result = result.replace("前5秒只向全员公开", "公开")
	result = result.replace("前5秒向全员公开", "公开")
	result = result.replace("展示结束后，目标城市业主另有5秒签/拒窗口，其他玩家此时仍可继续出牌。", "展示后目标业主签/拒。")
	result = result.replace("展示结束后，目标业主另有5秒签/拒窗口。", "展示后目标业主签/拒。")
	result = result.replace("展示沙漏公开", "公开")
	result = result.replace("展示结束后，目标城市业主获得独立签/拒窗口，其他玩家此时仍可继续出牌。", "展示后目标业主签/拒。")
	result = result.replace("随后目标业主签/拒。", "目标业主签/拒。")
	result = result.replace("出牌者和真实城市业主仍按规则隐藏。", "")
	result = result.replace("按规则隐藏", "保持匿名")
	result = result.replace("新规则下", "")
	result = result.replace("旧", "")
	result = result.replace("不再", "")
	result = result.replace("不能", "不可")
	return result


func _realtime_rule_text(text: String) -> String:
	var result := text
	result = result.replace("每个经营周期收入", "GDP/min")
	result = result.replace("每个经营周期额外", "每分钟现金流额外")
	result = result.replace("每个经营周期", "每分钟")
	result = result.replace("周期收入", "GDP/min")
	result = result.replace("/周期", "/min")
	result = result.replace("下一次市场重算", "下一次全局市场刷新")
	result = result.replace("下一次供需重算", "下一次全局市场刷新")
	result = result.replace("价格由供需重算体现", "价格由全局供需刷新体现")
	result = result.replace("等待下一次市场重算兑现", "等待下一次全局市场刷新兑现")
	result = result.replace("等待下一次供需重算兑现", "等待下一次全局市场刷新兑现")
	for duration_units in range(1, 13):
		var duration_text := _duration_short_text(_legacy_turns_to_seconds(duration_units))
		result = result.replace("持续%d周期" % duration_units, "持续%s" % duration_text)
		result = result.replace("持续%d个经营周期" % duration_units, "持续%s" % duration_text)
		result = result.replace("接下来%d个经营周期" % duration_units, "接下来%s" % duration_text)
		result = result.replace("%d周期" % duration_units, duration_text)
	result = result.replace("经营周期", "实时窗口")
	return result


func _derived_skill_tags(kind: String) -> Array:
	match kind:
		"cash_gain":
			return ["经济"]
		"city_revenue_boost":
			return ["经营"]
		"city_contract_boon":
			return ["经营", "合约"]
		"product_speculation":
			return ["经济", "商品"]
		"product_contract_boon":
			return ["经济", "合约"]
		"area_trade_contract":
			return ["经营", "合约"]
		"player_hand_disrupt":
			return ["互动", "拆牌"]
		"player_hand_steal":
			return ["互动", "牵牌"]
		"city_control_dispute":
			return ["互动", "城市"]
		"global_barrage":
			return ["互动", "齐射"]
		"card_counter":
			return ["互动", "反制"]
		"military_force":
			return ["军队", "短时资产"]
		"military_command":
			return ["军令", "固定技能"]
		"route_insurance":
			return ["经营", "商路"]
		"city_product_upgrade":
			return ["经营", "升级"]
		"city_product_shift":
			return ["经营", "换线"]
		"city_demand_shift":
			return ["经营", "需求"]
		"market_stabilize":
			return ["经济", "稳定"]
		"product_growth_boon":
			return ["经济", "催化"]
		"route_flow_boon":
			return ["经营", "物流"]
		"region_economy_shift":
			return ["区域", "GDP"]
		"intel_city_reveal":
			return ["情报", "区域"]
		"intel_card_trace":
			return ["情报", "卡牌"]
		"intel_contract_trace":
			return ["情报", "合约"]
		"weather_control":
			return ["天气"]
		"monster_lure":
			return ["诱导"]
		"supply_draw":
			return ["构筑"]
		"special_monster_delay":
			return ["控场"]
		"move", "fly", "burrow":
			return ["机动"]
		"attack", "charge_attack", "roll_attack":
			return ["攻击"]
		"area_damage", "mudslide":
			return ["破坏"]
		"miasma_shot", "miasma_bloom", "miasma_reclaim", "corrosive_breath":
			return ["瘴气"]
		"armor_gain":
			return ["防御"]
		"guard":
			return ["防御"]
		"roar":
			return ["控场"]
	return ["即时"]


func _preset_float(key: String) -> float:
	return float(REALTIME_BALANCE.get(key, 0.0))


func _preset_int(key: String) -> int:
	return int(REALTIME_BALANCE.get(key, 0))


func _roll_timer(prefix: String) -> float:
	var low: float = _preset_float("%s_min" % prefix)
	var high: float = _preset_float("%s_max" % prefix)
	return low + rng.randf_range(0.0, max(0.0, high - low))


func _alive_district_indices() -> Array:
	var result := []
	for i in range(districts.size()):
		if not bool(districts[i].get("destroyed", false)):
			result.append(i)
	return result


func _weight_total(weights: Array) -> int:
	var total := 0
	for weight in weights:
		total += max(0, int(weight))
	return total


func _weighted_pick_index(weights: Array) -> int:
	var total := _weight_total(weights)
	if total <= 0:
		return -1
	var ticket := rng.randi_range(1, total)
	var running := 0
	for i in range(weights.size()):
		running += max(0, int(weights[i]))
		if ticket <= running:
			return i
	return weights.size() - 1


func _probability_text(weight: int, total: int) -> String:
	if total <= 0:
		return "0%"
	return "%.0f%%" % (float(weight) * 100.0 / float(total))


func _roman_level(rank: int) -> String:
	match clampi(rank, 1, 10):
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
		5:
			return "V"
		6:
			return "VI"
		7:
			return "VII"
		8:
			return "VIII"
		9:
			return "IX"
		10:
			return "X"
	return "I"


func _level_text(rank: int) -> String:
	return "%s级" % _roman_level(rank)


func _card_display_name(card_name: String) -> String:
	if card_name == "":
		return ""
	var family := _game_runtime_coordinator_node().card_family_id(card_name)
	var rank := maxi(1, _game_runtime_coordinator_node().card_rank(card_name))
	return "%s %s" % [family, _level_text(rank)]


func _has_destroyed_district() -> bool:
	for d in districts:
		if bool(d["destroyed"]):
			return true
	return false


func _weight_part_total(parts: Dictionary) -> int:
	var total := 0
	for key in parts:
		total += max(0, int(parts[key]))
	return total






func _route_network_load_for_legacy_region(index: int) -> int:
	return int(_route_network_runtime_call("route_load_for_legacy_region", [index]))


func _prime_timers_for_new_game() -> void:
	monster_runtime_controller.prime_action_timers(
		max(1.0, _preset_float("special_monster_min") * 0.9),
		max(1.0, _preset_float("monster_min") * 0.8)
	)


func _claim_district_card(skill_name: String) -> void:
	var context_district := _active_district_card_context()
	var purchase_player := district_supply_open_player if _district_supply_is_open() else selected_player
	if purchase_player < 0 or purchase_player >= players.size():
		purchase_player = _first_run_coach_player_index()
	if purchase_player < 0 or purchase_player >= players.size():
		return
	if context_district < 0 or context_district >= districts.size():
		return
	if districts[context_district]["destroyed"]:
		_log("%s已被破坏，不能从这里获取卡牌。" % districts[context_district]["name"])
		_refresh_ui()
		return
	if not _district_has_card(context_district, skill_name):
		_log("%s不是当前区域的候选卡。%s" % [_card_display_name(skill_name), _card_choice_location_summary(skill_name)])
		_refresh_ui()
		return
	selected_market_skill = skill_name
	selected_player = purchase_player
	district_supply_open_player = purchase_player
	_buy_card_for_player_from_district(purchase_player, context_district, selected_market_skill, false, true)
	_refresh_ui()
	_focus_runtime_map_on_district(context_district)


func _selected_district_card_choices() -> Array:
	var result := []
	if selected_district < 0 or selected_district >= districts.size():
		return result
	if bool(districts[selected_district].get("destroyed", false)):
		return result
	for name_variant in districts[selected_district].get("card_choices", []):
		var card_name := String(name_variant)
		if _game_runtime_coordinator_node().card_exists(card_name):
			result.append(card_name)
	return result


func _sync_selected_district_card() -> void:
	var choices := _selected_district_card_choices()
	if choices.is_empty():
		selected_market_skill = ""
		previewed_district_card = ""
		return
	if not choices.has(selected_market_skill):
		selected_market_skill = String(choices[0])
	if not choices.has(previewed_district_card):
		previewed_district_card = selected_market_skill


func _cycle_selected_district_card(step: int = 1) -> void:
	var choices := _selected_district_card_choices()
	if choices.is_empty():
		selected_market_skill = ""
		previewed_district_card = ""
		_log("当前区域暂无可获取卡牌。")
		_refresh_ui()
		return
	var current := choices.find(selected_market_skill)
	current = 0 if current < 0 else wrapi(current + step, 0, choices.size())
	selected_market_skill = String(choices[current])
	previewed_district_card = selected_market_skill
	_refresh_ui()


func _district_has_card(district_index: int, skill_name: String) -> bool:
	if district_index < 0 or district_index >= districts.size() or skill_name == "":
		return false
	var choices: Array = districts[district_index].get("card_choices", [])
	return choices.has(skill_name)


func _card_market_preview(skill_name: String, district_index: int) -> Dictionary:
	if district_index < 0 or district_index >= districts.size() or skill_name.is_empty():
		return {}
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator == null or not runtime_coordinator.has_method("card_market_preview"):
		return {}
	var value: Variant = runtime_coordinator.call("card_market_preview", {
		"district_index": district_index,
		"card_id": skill_name,
		"supply_revision": str(districts[district_index].get("card_choices", [])),
		"base_price": _card_price(skill_name),
	})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _request_card_market_quote(skill_name: String, district_index: int, player_index: int = -1) -> Dictionary:
	var resolved_player := _resolved_card_market_player_index(player_index)
	if resolved_player < 0 or district_index < 0 or district_index >= districts.size() or skill_name.is_empty():
		return {}
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator == null or not runtime_coordinator.has_method("card_market_quote"):
		return {}
	var value: Variant = runtime_coordinator.call("card_market_quote", {
		"actor_id": _v06_actor_id(resolved_player),
		"player_index": resolved_player,
		"district_index": district_index,
		"card_id": skill_name,
		"supply_revision": str(districts[district_index].get("card_choices", [])),
		"base_price": _card_price(skill_name),
	})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _active_card_market_quote(skill_name: String, district_index: int, player_index: int, supply_revision: String) -> Dictionary:
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator == null or not runtime_coordinator.has_method("card_market_active_quote"):
		return {}
	var value: Variant = runtime_coordinator.call("card_market_active_quote", player_index, district_index)
	var quote: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if str(quote.get("card_id", "")) != skill_name or str(quote.get("supply_revision", "")) != supply_revision:
		return {}
	return quote


func _district_market_availability(district_index: int) -> Dictionary:
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator == null or not runtime_coordinator.has_method("card_market_listing_availability"):
		return {}
	var value: Variant = runtime_coordinator.call("card_market_listing_availability", district_index)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _district_market_currently_purchasable(district_index: int) -> bool:
	return bool(_district_market_availability(district_index).get("purchasable", false))


func _district_market_availability_kind(district_index: int) -> String:
	return str(_district_market_availability(district_index).get("availability_kind", "invalid"))


func _district_market_availability_text(district_index: int) -> String:
	match _district_market_availability_kind(district_index):
		"sunlit": return "来源区域处于日照半球：可购买；报价锁定5个世界秒。"
		"dark": return "来源区域处于暗面：可以查看，当前不可购买。"
		"destroyed": return "来源区域已摧毁：挂牌不可购买。"
	return "市场资格暂不可用。"


func _card_choice_location_summary(skill_name: String) -> String:
	var names := []
	var total := 0
	for i in range(districts.size()):
		if not _district_has_card(i, skill_name):
			continue
		total += 1
		if names.size() < 3:
			names.append(String(districts[i]["name"]))
	if total <= 0:
		return "暂未投放到区域"
	var suffix := ""
	if total > names.size():
		suffix = " 等%d个区域可取" % total
	else:
		suffix = "可取"
	return "在%s%s" % [" / ".join(names), suffix]


func _is_upgrade_card(skill_name: String) -> bool:
	if skill_name == "" or not _game_runtime_coordinator_node().card_exists(skill_name):
		return false
	var family := _game_runtime_coordinator_node().card_family_id(skill_name)
	var rank := _game_runtime_coordinator_node().card_rank(skill_name)
	return rank > 1 and _game_runtime_coordinator_node().card_exists("%s%d" % [family, rank - 1])


func _can_selected_player_act() -> bool:
	if _runtime_session_finished():
		return false
	if selected_player < 0 or selected_player >= players.size() or _player_is_eliminated(selected_player):
		_log("当前席位已经破产出局，不能继续操作。")
		return false
	if _has_pending_target_choice():
		_log("请先完成当前卡牌的目标怪兽选择。")
		return false
	if _has_pending_player_target_choice():
		_log("请先完成当前卡牌的目标玩家选择。")
		return false
	var player: Dictionary = players[selected_player]
	if player["action_cooldown"] > 0.0:
		_log("%s操作冷却中，还需%.1fs。" % [player["name"], player["action_cooldown"]])
		return false
	return true


func _card_bid_control_status_text(player_index: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return "报价状态：无当前玩家"
	var active_bid := _selected_card_priority_bid_amount(player_index)
	var queued_index := _queued_card_entry_index_for_player(player_index)
	var next_queued_index := _next_batch_card_entry_index_for_player(player_index)
	var player: Dictionary = players[player_index]
	var cash := int(player.get("cash", 0))
	if queued_index >= 0:
		var group_count := _card_group_count_for_player(player_index)
		var group_limit := _card_group_limit_for_player(player_index)
		var window_phase := _card_group_window_phase()
		if window_phase == "public_bid":
			return "报价状态：公开竞价阶段｜优先报价¥%d｜最高¥%d｜不能加牌｜固定档0/50/100｜可用现金¥%d" % [
				active_bid,
				_highest_card_resolution_bid(),
				cash,
			]
		if window_phase == "planning":
			return "报价状态：规划阶段｜本组%d/%d张｜等待公开竞价｜预设¥%d" % [group_count, group_limit, active_bid]
		if window_phase == "lock":
			return "报价状态：锁牌阶段｜优先报价¥%d｜不能加牌或改价" % active_bid
		var next_suffix := "｜另有响应牌等待" if next_queued_index >= 0 else ""
		return "报价状态：卡牌组已封盘｜优先报价¥%d已进公共奖池｜组内顺序看顶部牌轨%s" % [active_bid, next_suffix]
	if next_queued_index >= 0:
		return "报价状态：相位响应牌已提交｜当前组结算后清理｜不可参与普通组竞价"
	if card_resolution_batch_locked or not _card_resolution_active_entry().is_empty():
		return "报价状态：当前卡牌组连续结算中｜预设¥%d｜普通牌保留到下一共享窗" % active_bid
	if not _card_resolution_current_queue().is_empty():
		var current_phase := _card_group_window_phase()
		if current_phase == "planning":
			return "报价状态：规划阶段｜预设¥%d｜现在打牌会建立自己的卡牌组" % active_bid
		return "报价状态：%s阶段｜预设¥%d｜不能新建组" % [_card_group_phase_label(current_phase), active_bid]
	return "报价状态：预设¥%d｜空闲：下一张牌会开启%s" % [active_bid, _card_group_window_cadence_text(_card_group_next_window_sequence())]


func _card_bid_button_tooltip(player_index: int, target_tip: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return "没有当前玩家，无法设置报价。"
	var active_bid := _selected_card_priority_bid_amount(player_index)
	if _runtime_session_finished():
		return "游戏已经结束，不能修改报价。"
	var queued_index := _queued_card_entry_index_for_player(player_index)
	var next_queued_index := _next_batch_card_entry_index_for_player(player_index)
	if queued_index >= 0:
		if not _card_group_bidding_open():
			return "不能修改：共享窗已封盘或卡牌组正在连续结算，锁定组报价保持¥%d。" % active_bid
		if target_tip <= active_bid:
			return "卡牌组已经公开提交；报价只能提高，不能撤回或降低。"
		if not [0, 50, 100].has(target_tip):
			return "优先报价只能选择¥0、¥50或¥100。"
		var cash_needed := maxi(0, target_tip - active_bid)
		var available_cash := int((players[player_index] as Dictionary).get("cash", 0))
		if available_cash < cash_needed:
			return "资金不足：卡牌行动费已经在提交时支付；当前剩余资金¥%d，无法承诺组报价¥%d。" % [
				available_cash,
				target_tip,
			]
		return "把整组优先报价提高到¥%d；差额立即托管，封盘后进入公共怪兽赌局奖池。" % target_tip
	if next_queued_index >= 0:
		return "相位响应牌不参与普通卡牌组竞价。"
	var cash := int((players[player_index] as Dictionary).get("cash", 0))
	if not [0, 50, 100].has(target_tip):
		return "优先报价只能选择¥0、¥50或¥100。"
	if cash < maxi(0, target_tip):
		return "资金不足：无法把下一张牌预设报价设为¥%d；当前资金¥%d。" % [target_tip, cash]
	if target_tip <= 0:
		return "清空下一组的预设报价；已公开提交的卡牌组不受影响。"
	return "把下一组预设优先报价设为¥%d；第一张卡提交时会开启%s。" % [target_tip, _card_group_window_cadence_text(_card_group_next_window_sequence())]


func _selected_card_priority_bid_amount(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var queued_index := _queued_card_entry_index_for_player(player_index)
	if queued_index >= 0:
		return int(float(int((_card_resolution_current_queue()[queued_index] as Dictionary).get("priority_bid_cents", 0))) / 100.0)
	var next_queued_index := _next_batch_card_entry_index_for_player(player_index)
	if next_queued_index >= 0:
		return int(float(int((_card_resolution_next_queue()[next_queued_index] as Dictionary).get("priority_bid_cents", 0))) / 100.0)
	var amount := int((players[player_index] as Dictionary).get("queued_card_tip", 0))
	return max(0, amount)


func _queued_card_entry_index_for_player(player_index: int) -> int:
	var service := _card_resolution_queue_service_node()
	return int(service.call("entry_index_for_player", player_index, false)) if service != null and service.has_method("entry_index_for_player") else -1


func _next_batch_card_entry_index_for_player(player_index: int) -> int:
	var service := _card_resolution_queue_service_node()
	return int(service.call("entry_index_for_player", player_index, true)) if service != null and service.has_method("entry_index_for_player") else -1


func _move_card_within_group(resolution_id: int, direction: int) -> bool:
	if direction == 0 or not _card_group_submissions_open():
		return false
	var source_entry := _card_resolution_entry_by_id(resolution_id)
	var player_index := int(source_entry.get("player_index", -1))
	if source_entry.is_empty() or player_index != selected_player:
		return false
	var service := _card_resolution_queue_service_node()
	if service == null or not service.has_method("move_within_group"):
		return false
	var result_variant: Variant = service.call("move_within_group", resolution_id, direction, player_index, card_resolution_batch_reference_player, players.size())
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	if not bool(result.get("moved", false)):
		return false
	_log("卡牌组内部顺序已调整；同组牌会按新的1-%d顺序连续结算。" % int(result.get("group_size", 0)))
	_refresh_ui()
	return true


func _set_selected_card_priority_bid(amount: int) -> bool:
	var old_amount := _selected_card_priority_bid_amount(selected_player)
	var changed := _set_selected_card_bid_absolute(max(0, amount))
	if changed and amount > old_amount:
		_complete_scenario_signal("bid_raised", "公开报价提高到¥%d。" % max(0, amount), "after_bid", "bid_board")
	elif changed and amount == 0 and old_amount > 0:
		_complete_scenario_signal("bid_reset", "公开报价已清零。", "after_bid", "bid_board")
	return changed


func _increase_selected_card_bid(increment: int) -> bool:
	if increment <= 0:
		return false
	var old_amount := _selected_card_priority_bid_amount(selected_player)
	var target_amount := 50 if old_amount < 50 else 100
	if target_amount <= old_amount:
		return false
	var changed := _set_selected_card_bid_absolute(target_amount)
	if changed and target_amount > old_amount:
		_complete_scenario_signal("bid_raised", "公开报价提高到¥%d。" % target_amount, "after_bid", "bid_board")
	return changed


func _reset_selected_card_bid() -> bool:
	var old_amount := _selected_card_priority_bid_amount(selected_player)
	var changed := _set_selected_card_bid_absolute(0)
	if changed and old_amount > 0:
		_complete_scenario_signal("bid_reset", "公开报价已清零。", "after_bid", "bid_board")
	return changed


func _set_selected_card_bid_absolute(amount: int) -> bool:
	return _set_card_bid_for_player(selected_player, amount, true)


func _set_card_bid_for_player(player_index: int, amount: int, announce: bool = true) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var clamped: int = maxi(0, amount)
	if not [0, 50, 100].has(clamped):
		if announce:
			_log("优先报价只能选择¥0、¥50或¥100。")
		return false
	var queued_index: int = _queued_card_entry_index_for_player(player_index)
	if queued_index >= 0:
		var entry: Dictionary = _card_resolution_current_queue()[queued_index]
		var old_bid := int(float(int(entry.get("priority_bid_cents", 0))) / 100.0)
		var service := _card_resolution_queue_service_node()
		var result_variant: Variant = service.call("set_group_priority_bid_cents", player_index, clamped * 100, {
			"bidding_open": _card_group_bidding_open(),
			"available_cash_cents": int(players[player_index].get("cash", 0)) * 100,
			"priority_bid_escrow_authorized": true,
			"game_time": game_time,
			"reference_player": card_resolution_batch_reference_player,
			"player_count": players.size(),
		}) if service != null and service.has_method("set_group_priority_bid_cents") else {}
		var result: Dictionary = result_variant if result_variant is Dictionary else {}
		if not bool(result.get("changed", false)):
			if announce:
				var reason := str(result.get("reason", "queue_service_missing"))
				match reason:
					"bidding_closed": _log("共享卡牌窗已经封盘，锁定组报价不能再修改。")
					"bid_not_increased":
						if clamped < old_bid: _log("卡牌组报价只能提高，不能从¥%d降低到¥%d。" % [old_bid, clamped])
					"invalid_priority_bid": _log("优先报价只能选择¥0、¥50或¥100。")
					"insufficient_cash": _log("卡牌行动费已经在提交时支付；当前剩余资金不足以承诺组报价¥%d。" % clamped)
			return false
		var escrow_delta_cash := int(float(int(result.get("priority_bid_escrow_delta_cents", 0))) / 100.0)
		if escrow_delta_cash > 0:
			players[player_index]["cash"] = int(players[player_index].get("cash", 0)) - escrow_delta_cash
			players[player_index]["total_card_spend"] = int(players[player_index].get("total_card_spend", 0)) + escrow_delta_cash
			_record_player_economic_event(player_index, "卡牌组优先报价", "追加托管", -escrow_delta_cash, "锁牌后进入下一场怪兽赌局公共奖池。")
			_record_player_cash_snapshot(player_index)
		if announce:
			_log("公开组报价：一个匿名卡牌组从¥%d提高到¥%d；报价只增不减，来源身份仍隐藏。" % [old_bid, clamped])
		_refresh_ui()
		return true
	if _next_batch_card_entry_index_for_player(player_index) >= 0:
		if announce:
			_log("下一批等待牌已经提交；当前批次清空并进入统一竞价前，报价暂不修改。")
		return false
	if int(players[player_index].get("cash", 0)) < clamped:
		if announce:
			_log("当前视角资金不足，无法预设¥%d匿名报价。" % clamped)
		return false
	players[player_index]["queued_card_tip"] = clamped
	_refresh_ui()
	return true


func _set_selected_player_card_group_ready() -> bool:
	var window_phase := _card_group_window_phase()
	if _queued_card_entry_index_for_player(selected_player) < 0 or not ["planning", "public_bid", "lock"].has(window_phase):
		return false
	var controller := _card_resolution_controller_node()
	if controller == null or not controller.has_method("set_player_ready"):
		return false
	var active_players: Array = _card_resolution_controller_facts().get("active_player_indices", []) as Array
	var result_variant: Variant = controller.call("set_player_ready", selected_player, true, active_players)
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	if not bool(result.get("changed", false)):
		return false
	_log("当前席位已完成%s阶段准备（%d/%d）；全员准备只推进到下一阶段。" % [_card_group_phase_label(window_phase), int(result.get("ready_count", 0)), int(result.get("active_player_count", 0))])
	_refresh_ui()
	return true


func _card_resolution_status_text() -> String:
	var phase_text := _card_resolution_phase_text()
	if phase_text != "":
		return phase_text
	return "阶段：空闲｜无卡牌结算"


func _card_resolution_phase_text(entry: Dictionary = {}, _seconds_left: float = -1.0) -> String:
	var queued := _card_resolution_current_queue().size()
	var window_phase := _card_group_window_phase()
	if window_phase == "public_bid":
		return "阶段：公开竞价｜剩余%d秒｜匿名组%d｜最高优先报价¥%d｜新牌：保留手牌" % [
			int(ceil(_card_group_phase_remaining_seconds())),
			_card_resolution_groups().size(),
			_highest_card_resolution_bid(),
		]
	if window_phase == "planning":
		return "阶段：规划｜剩余%d秒｜匿名组%d｜牌%d｜普通上限%d张｜可调顺序/准备" % [
			int(ceil(_card_group_phase_remaining_seconds())),
			_card_resolution_groups().size(),
			queued,
			_card_group_limit_for_player(selected_player),
		]
	if window_phase == "lock":
		return "阶段：锁牌｜剩余%d秒｜匿名组%d｜牌%d｜不能加牌或改价" % [
			int(ceil(_card_group_phase_remaining_seconds())),
			_card_resolution_groups().size(),
			queued,
		]
	var active_entry := entry
	if active_entry.is_empty() and not _card_resolution_active_entry().is_empty():
		active_entry = _card_resolution_active_entry()
	if not active_entry.is_empty():
		if card_resolution_counter_window_active:
			return "阶段：相位响应｜可打反制｜原牌暂未结算｜出牌者%s" % [
				"已揭晓" if bool(active_entry.get("public_owner_revealed", false)) else "未知",
			]
		return "阶段：组内连续结算｜锁定候补%d｜可加价：否｜普通牌等待下一窗口｜出牌者%s" % [
			queued,
			"已揭晓" if bool(active_entry.get("public_owner_revealed", false)) else "未知",
		]
	if queued > 0:
		return "阶段：卡牌组锁定｜锁定候补%d｜可加价：否｜普通牌等待下一窗口" % queued
	return ""


func _next_upgrade_name(skill_name: String) -> String:
	if skill_name == "" or not _game_runtime_coordinator_node().card_exists(skill_name):
		return ""
	var family := _game_runtime_coordinator_node().card_family_id(skill_name)
	var rank := _game_runtime_coordinator_node().card_rank(skill_name)
	if rank <= 0 or rank >= 4:
		return ""
	var next_name := "%s%d" % [family, rank + 1]
	return next_name if _game_runtime_coordinator_node().card_exists(next_name) else ""


func _find_highest_family_card_slot(player: Dictionary, skill_name: String) -> int:
	var family := _game_runtime_coordinator_node().card_family_id(skill_name)
	var best_slot := -1
	var best_rank := -1
	for i in range(player["slots"].size()):
		var skill = player["slots"][i]
		if skill == null:
			continue
		var current_name := String(skill.get("name", ""))
		if _game_runtime_coordinator_node().card_family_id(current_name) != family:
			continue
		var rank := maxi(1, _game_runtime_coordinator_node().card_rank(current_name))
		if rank > best_rank:
			best_rank = rank
			best_slot = i
	return best_slot


func _first_empty_or_new_slot(player: Dictionary) -> int:
	for i in range(player["slots"].size()):
		if player["slots"][i] == null:
			return i
	player["slots"].append(null)
	return player["slots"].size() - 1


func _is_hand_limit_exempt_skill(skill: Dictionary) -> bool:
	return ["monster_bound_action", "military_command"].has(String(skill.get("kind", ""))) and bool(skill.get("persistent", false))


func _counts_toward_hand_limit(skill: Dictionary) -> bool:
	return not _is_hand_limit_exempt_skill(skill)


func _player_counted_hand_size(player: Dictionary) -> int:
	var count := 0
	for skill_variant in player.get("slots", []):
		if not (skill_variant is Dictionary):
			continue
		if _counts_toward_hand_limit(skill_variant as Dictionary):
			count += 1
	return count


func _card_inventory_snapshot(player: Dictionary, incoming_card: Dictionary = {}, incoming_card_id: String = "", discard_slot: int = -1, allows_family_upgrade: bool = true) -> Dictionary:
	var slot_facts: Array = []
	var player_slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	for slot_index in range(player_slots.size()):
		var skill_variant: Variant = player_slots[slot_index]
		if not (skill_variant is Dictionary):
			slot_facts.append({"slot_index": slot_index, "occupied": false})
			continue
		var current_skill: Dictionary = skill_variant
		var current_card_id := str(current_skill.get("name", ""))
		var next_upgrade_id := _next_upgrade_name(current_card_id)
		var counts_toward_limit := _counts_toward_hand_limit(current_skill)
		slot_facts.append({
			"slot_index": slot_index,
			"occupied": true,
			"card_id": current_card_id,
			"family": _game_runtime_coordinator_node().card_family_id(current_card_id),
			"rank": maxi(1, _game_runtime_coordinator_node().card_rank(current_card_id)),
			"counts_toward_hand_limit": counts_toward_limit,
			"queued_for_resolution": bool(current_skill.get("queued_for_resolution", false)),
			"lock_left": float(current_skill.get("lock_left", 0.0)),
			"next_upgrade_id": next_upgrade_id,
			"next_upgrade_card": _make_skill(next_upgrade_id) if next_upgrade_id != "" else {},
		})
	return {
		"valid": incoming_card_id != "" and not incoming_card.is_empty(),
		"incoming_card_id": incoming_card_id,
		"incoming_card": incoming_card.duplicate(true),
		"incoming_family": _game_runtime_coordinator_node().card_family_id(incoming_card_id),
		"incoming_rank": maxi(1, int(incoming_card.get("rank", _game_runtime_coordinator_node().card_rank(incoming_card_id)))) if not incoming_card.is_empty() else 0,
		"incoming_counts_toward_hand_limit": _counts_toward_hand_limit(incoming_card) if not incoming_card.is_empty() else true,
		"incoming_allows_family_upgrade": allows_family_upgrade,
		"counted_hand_size": _player_counted_hand_size(player),
		"hand_limit": PLAYER_HAND_LIMIT,
		"discard_slot": discard_slot,
		"slots": slot_facts,
	}


func _district_purchase_inventory_snapshot(player: Dictionary, skill_name: String = "", discard_slot: int = -1) -> Dictionary:
	var canonical_card_id := _canonical_card_supply_name(skill_name)
	var incoming_card := _make_skill(canonical_card_id) if canonical_card_id != "" and _game_runtime_coordinator_node().card_exists(canonical_card_id) else {}
	return _card_inventory_snapshot(player, incoming_card, canonical_card_id, discard_slot, true)


func _district_purchase_inventory_plan(player: Dictionary, skill_name: String, discard_slot: int = -1) -> Dictionary:
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator == null or not runtime_coordinator.has_method("plan_card_inventory_receive"):
		_mark_game_runtime_coordinator_missing(true)
		return {"status": "rejected", "ready": false, "reason": "inventory_service_missing"}
	var value: Variant = runtime_coordinator.call("plan_card_inventory_receive", _district_purchase_inventory_snapshot(player, skill_name, discard_slot))
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _player_can_receive_card(player: Dictionary, skill_name: String) -> bool:
	return str(_district_purchase_inventory_plan(player, skill_name).get("status", "")) == "ready"


func _discardable_hand_slots_for_purchase(player: Dictionary) -> Array:
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator == null or not runtime_coordinator.has_method("card_inventory_discardable_slots"):
		_mark_game_runtime_coordinator_missing(true)
		return []
	var value: Variant = runtime_coordinator.call("card_inventory_discardable_slots", _card_inventory_snapshot(player))
	return (value as Array).duplicate() if value is Array else []


func _player_can_receive_card_with_discard(player: Dictionary, skill_name: String) -> bool:
	return ["ready", "requires_discard"].has(str(_district_purchase_inventory_plan(player, skill_name).get("status", "")))


func _purchase_requires_discard(player: Dictionary, skill_name: String) -> bool:
	return str(_district_purchase_inventory_plan(player, skill_name).get("status", "")) == "requires_discard"


func _pending_discard_purchase_for_player(player_index: int) -> Dictionary:
	if int(pending_discard_purchase.get("player_index", -1)) != player_index:
		return {}
	return pending_discard_purchase


func _open_discard_purchase_choice(player_index: int, district_index: int, skill_name: String, price: int, quote_id: String, ignore_cooldown: bool = false) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	var runtime_coordinator := _game_runtime_coordinator_node()
	pending_discard_purchase = {
		"player_index": player_index,
		"district_index": district_index,
		"skill_name": _canonical_card_supply_name(skill_name),
		"price": price,
		"quote_id": quote_id,
		"ignore_cooldown": ignore_cooldown,
		"opened_at": game_time,
	}
	if runtime_coordinator != null and runtime_coordinator.has_method("reserve_district_purchase_discard"):
		runtime_coordinator.call("reserve_district_purchase_discard", {
			"player_index": player_index,
			"district_index": district_index,
			"card_id": str(pending_discard_purchase.get("skill_name", "")),
		})
	_record_player_economic_event(
		player_index,
		"手牌整理",
		"等待私密弃牌",
		0,
		"购买%s会超过普通手牌上限%d张；请先私下选择一张旧普通牌弃掉。" % [
			_card_display_name(skill_name),
			PLAYER_HAND_LIMIT,
		]
	)


func _cancel_discard_purchase() -> void:
	var player_index := int(pending_discard_purchase.get("player_index", -1))
	pending_discard_purchase = {}
	var runtime_coordinator := _game_runtime_coordinator_node()
	if player_index >= 0 and runtime_coordinator != null and runtime_coordinator.has_method("resolve_district_purchase_discard"):
		runtime_coordinator.call("resolve_district_purchase_discard", {"player_index": player_index, "reason": "discard_cancelled"})
	_refresh_ui()


func _confirm_discard_purchase(slot_index: int) -> void:
	var pending := pending_discard_purchase.duplicate(true)
	if pending.is_empty():
		return
	var player_index := int(pending.get("player_index", -1))
	var district_index := int(pending.get("district_index", -1))
	var skill_name := String(pending.get("skill_name", ""))
	var quote_id := String(pending.get("quote_id", ""))
	var ignore_cooldown := bool(pending.get("ignore_cooldown", false))
	pending_discard_purchase = {}
	var bought := _buy_card_for_player_from_district(player_index, district_index, skill_name, false, ignore_cooldown, slot_index, quote_id)
	var runtime_coordinator := _game_runtime_coordinator_node()
	if player_index >= 0 and runtime_coordinator != null and runtime_coordinator.has_method("resolve_district_purchase_discard"):
		runtime_coordinator.call("resolve_district_purchase_discard", {"player_index": player_index, "reason": "discard_confirmed" if bought else "discard_purchase_failed"})
	_refresh_ui()


func _can_view_player_private_hand(player_index: int) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	return not _player_is_ai(player_index)


func _local_human_player_index() -> int:
	for i in range(players.size()):
		if not _player_is_ai(i):
			return i
	return 0


func _player_has_committed_or_resolved_card(player_index: int) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	if int(_card_resolution_active_entry().get("player_index", -1)) == player_index and _opening_guide_card_entry_counts(_card_resolution_active_entry()):
		return true
	for queue_variant in [_card_resolution_current_queue(), _card_resolution_next_queue(), resolved_card_history]:
		for entry_variant in queue_variant:
			if entry_variant is Dictionary and int((entry_variant as Dictionary).get("player_index", -1)) == player_index and _opening_guide_card_entry_counts(entry_variant as Dictionary):
				return true
	return false


func _opening_guide_card_entry_counts(entry: Dictionary) -> bool:
	var skill: Dictionary = entry.get("skill", {}) if entry.get("skill", {}) is Dictionary else {}
	return not bool(skill.get("starter_play_free", false))


func _player_tableau_progress_entries(player_index: int) -> Array:
	if player_index < 0 or player_index >= players.size():
		return []
	var can_view_private := _can_view_player_private_hand(player_index)
	var viewer_index := _local_human_player_index()
	if not can_view_private:
		return [
			{"text": "公开线索", "state": _player_visible_city_text(player_index, viewer_index), "accent": Color("#38bdf8"), "active": true, "tip": "对手城市业主仍靠标注和公开线索推理。"},
			{"text": "明怪", "state": "%d" % _player_visible_monster_count(player_index, viewer_index), "accent": Color("#fb7185"), "active": _player_visible_monster_count(player_index, viewer_index) > 0, "tip": "只统计已公开归属或本席可见的怪兽。"},
			{"text": "明军", "state": "%d" % military_runtime_controller.visible_unit_count(player_index, viewer_index), "accent": Color("#67e8f9"), "active": military_runtime_controller.visible_unit_count(player_index, viewer_index) > 0, "tip": "只显示公开归属的军队线索。"},
			{"text": "牌轨", "state": "看公开", "accent": Color("#c084fc"), "active": not resolved_card_history.is_empty() or not _card_resolution_current_queue().is_empty(), "tip": "只能从匿名牌轨、竞价和结算结果推理。"},
			{"text": "资金/手牌", "state": "隐私", "accent": Color("#94a3b8"), "active": false, "tip": "对手现金、真实手牌数量、弃牌和AI内部计划不显示。"},
		]
	var player: Dictionary = players[player_index]
	var has_monster := int(_ai_runtime_call("_ai_owned_active_monster_count", [player_index])) > 0
	var city_count := _player_active_city_count(player_index)
	var bought_card := int(player.get("card_purchase_count", 0)) > 0
	var committed_card := _player_has_committed_or_resolved_card(player_index)
	var score := _victory_player_progress_metric(player_index)
	var goal := _victory_required_gdp()
	return [
		{"text": "怪兽牌", "state": "已召" if has_monster else "可选", "accent": Color("#fb7185"), "active": has_monster, "tip": "起始怪兽牌已持有；召唤完全自愿，不阻断经济或购牌。"},
		{"text": "建城", "state": "城%d" % city_count if city_count > 0 else "待建", "accent": Color("#22c55e"), "active": city_count > 0, "tip": "项目归属GDP决定收入、区域控制和审计资格。"},
		{"text": "买牌", "state": "已买" if bought_card else "看牌架", "accent": Color("#f59e0b"), "active": bought_card, "tip": "双击区域查看全局挂牌；来源区域受光时可锁定5秒报价。"},
		{"text": "匿名牌", "state": "已入轨" if committed_card else "待出牌", "accent": Color("#c084fc"), "active": committed_card, "tip": "打出的牌进入公开匿名牌轨；条件和结果会给其他玩家推理线索。"},
		{"text": "审计", "state": _victory_control_status_text(), "accent": Color("#f97316"), "active": _victory_control_is_active() or score >= goal, "tip": "控制当前存续区域的40%并达到前K区商品GDP门槛后，先保持10秒，再进入120秒公开审计。"},
	]


func _acquire_inventory_skill_for_player(player: Dictionary, incoming_skill: Dictionary, allows_family_upgrade: bool = true) -> bool:
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator == null or not runtime_coordinator.has_method("plan_card_inventory_receive") or not runtime_coordinator.has_method("commit_card_inventory_receive"):
		_mark_game_runtime_coordinator_missing(true)
		return false
	var incoming_card_id := str(incoming_skill.get("name", ""))
	var inventory_snapshot := _card_inventory_snapshot(player, incoming_skill, incoming_card_id, -1, allows_family_upgrade)
	var plan_variant: Variant = runtime_coordinator.call("plan_card_inventory_receive", inventory_snapshot)
	var plan: Dictionary = plan_variant if plan_variant is Dictionary else {}
	if str(plan.get("status", "")) != "ready":
		return false
	var result_variant: Variant = runtime_coordinator.call("commit_card_inventory_receive", player, inventory_snapshot, plan)
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	return bool(result.get("committed", false))


func _acquire_card_for_player(player: Dictionary, skill_name: String, _district_index: int, _source: String, _anonymous: bool = false) -> bool:
	var canonical_card_id := _canonical_card_supply_name(skill_name)
	if canonical_card_id == "" or not _game_runtime_coordinator_node().card_exists(canonical_card_id):
		return false
	return _acquire_inventory_skill_for_player(player, _make_skill(canonical_card_id), true)






func _default_economy_product() -> String:
	if selected_trade_product != "" and ProductMarketRuntimeController.PRODUCT_CATALOG.has(selected_trade_product):
		return selected_trade_product
	if selected_district >= 0 and selected_district < districts.size():
		var district: Dictionary = districts[selected_district]
		var products: Array = district.get("products", [])
		if not products.is_empty():
			return String(products[0])
		var demands: Array = district.get("demands", [])
		if not demands.is_empty():
			return String(demands[0])
		var city := _district_city(selected_district)
		if _city_is_active(city):
			var city_products := _city_product_names(city)
			if not city_products.is_empty():
				return String(city_products[0])
			var city_demands := _city_demand_names(city)
			if not city_demands.is_empty():
				return String(city_demands[0])
	if ProductMarketRuntimeController.PRODUCT_CATALOG.is_empty():
		return ""
	return String(ProductMarketRuntimeController.PRODUCT_CATALOG[0])


func _merge_boon_source(existing: String, source: String) -> String:
	var result := _card_economy_product_route_formula_result("merge_boon_source", {
		"existing": existing,
		"source": source,
	})
	return str(result.get("value", existing))


func _product_market_boon_text(product_name: String) -> String:
	var entry := _product_market_entry_snapshot(product_name)
	if entry.is_empty():
		return "无"
	var pieces := []
	var weather_driver := String(entry.get("weather_driver_summary", "无天气因素"))
	if weather_driver != "无天气因素":
		pieces.append(weather_driver)
	var growth_multiplier: float = float(entry.get("growth_multiplier", 1.0))
	if growth_multiplier > 1.001:
		var growth_source := String(entry.get("growth_source", entry.get("base_growth_source", "")))
		var growth_source_suffix := "｜%s" % growth_source if growth_source != "" else ""
		pieces.append("增速×%.2f（%s%s）" % [
			growth_multiplier,
			_boon_duration_text(_remaining_effect_seconds(entry, "growth_seconds", "growth_turns")),
			growth_source_suffix,
		])
	var route_multiplier: float = float(entry.get("route_flow_multiplier", 1.0))
	if route_multiplier > 1.001:
		var route_source := String(entry.get("route_flow_source", entry.get("base_route_flow_source", "")))
		var route_source_suffix := "｜%s" % route_source if route_source != "" else ""
		pieces.append("流通×%.2f（%s%s）" % [
			route_multiplier,
			_boon_duration_text(_remaining_effect_seconds(entry, "route_flow_seconds", "route_flow_turns")),
			route_source_suffix,
		])
	var contract_seconds := _remaining_effect_seconds(entry, "market_contract_seconds", "market_contract_turns")
	var _contract_turns := int(entry.get("market_contract_turns", 0))
	var contract_demand := int(entry.get("market_contract_demand", 0))
	var contract_supply := int(entry.get("market_contract_supply", 0))
	if contract_seconds > 0.0 and (contract_demand > 0 or contract_supply > 0):
		var contract_source := String(entry.get("market_contract_source", ""))
		var contract_source_suffix := "｜%s" % contract_source if contract_source != "" else ""
		var pressure_parts := []
		if contract_demand > 0:
			pressure_parts.append("需+%d" % contract_demand)
		if contract_supply > 0:
			pressure_parts.append("供+%d" % contract_supply)
		pieces.append("商品合约%s（%s%s）" % [
			"/".join(pressure_parts),
			_boon_duration_text(contract_seconds),
			contract_source_suffix,
		])
	var futures_text := _product_market_futures_public_text(product_name)
	if futures_text != "":
		pieces.append(futures_text)
	if pieces.is_empty():
		return "无"
	return "；".join(pieces)


func _reset_city_warehouse_stockpile_marker(city: Dictionary) -> Dictionary:
	if city.is_empty():
		return city
	city["warehouse_stockpile_count"] = 0
	city["warehouse_stockpile_units"] = 0
	city["warehouse_stockpile_products"] = []
	city["warehouse_stockpile_expires_at"] = -1.0
	return city


func _normalize_city_warehouse_stockpile_fields(city: Dictionary) -> Dictionary:
	if city.is_empty():
		return city
	if not city.has("warehouse_stockpile_count"):
		city["warehouse_stockpile_count"] = 0
	if not city.has("warehouse_stockpile_units"):
		city["warehouse_stockpile_units"] = 0
	if not city.has("warehouse_stockpile_products"):
		city["warehouse_stockpile_products"] = []
	if not city.has("warehouse_stockpile_expires_at"):
		city["warehouse_stockpile_expires_at"] = -1.0
	return city


func _add_city_warehouse_stockpile_marker(district_index: int, product_name: String, units: int, expires_at: float) -> void:
	if district_index < 0 or district_index >= districts.size():
		return
	var city := _normalize_city_warehouse_stockpile_fields(_district_city(district_index))
	if not _city_is_active(city):
		return
	city["warehouse_stockpile_count"] = int(city.get("warehouse_stockpile_count", 0)) + 1
	city["warehouse_stockpile_units"] = int(city.get("warehouse_stockpile_units", 0)) + maxi(1, units)
	var products: Array = city.get("warehouse_stockpile_products", [])
	monster_runtime_controller._append_unique_string(products, product_name)
	city["warehouse_stockpile_products"] = products
	var current_expires := float(city.get("warehouse_stockpile_expires_at", -1.0))
	if current_expires < 0.0 or expires_at < current_expires:
		city["warehouse_stockpile_expires_at"] = expires_at
	districts[district_index]["city"] = city


func _refresh_warehouse_stockpile_city_markers() -> void:
	for district_index in range(districts.size()):
		var city := _district_city(district_index)
		if city.is_empty():
			continue
		districts[district_index]["city"] = _reset_city_warehouse_stockpile_marker(city)
	var market_snapshot: Dictionary = _product_market_runtime_state().get("product_market", {}) as Dictionary
	for product_variant in market_snapshot.keys():
		var product_name := String(product_variant)
		var entry := _product_market_entry_snapshot(product_name)
		if entry.is_empty():
			continue
		var futures: Array = entry.get("futures_positions", [])
		for futures_variant in futures:
			if not (futures_variant is Dictionary):
				continue
			var futures_position := futures_variant as Dictionary
			var warehouse_district := int(futures_position.get("warehouse_district", -1))
			if warehouse_district < 0:
				continue
			_add_city_warehouse_stockpile_marker(
				warehouse_district,
				product_name,
				maxi(1, int(futures_position.get("units", 1))),
				float(futures_position.get("expires_at", game_time))
			)


func _city_warehouse_stockpile_pressure(city: Dictionary) -> int:
	if not _city_is_active(city):
		return 0
	var count := maxi(0, int(city.get("warehouse_stockpile_count", 0)))
	var units := maxi(0, int(city.get("warehouse_stockpile_units", 0)))
	var products: Array = city.get("warehouse_stockpile_products", [])
	if count <= 0 and units <= 0 and products.is_empty():
		return 0
	return count * WAREHOUSE_STOCKPILE_COUNT_PRESSURE + units * WAREHOUSE_STOCKPILE_UNIT_PRESSURE + products.size() * WAREHOUSE_STOCKPILE_PRODUCT_PRESSURE


func _city_warehouse_stockpile_status_text(city: Dictionary) -> String:
	if not _city_is_active(city):
		return ""
	var count := maxi(0, int(city.get("warehouse_stockpile_count", 0)))
	if count <= 0:
		return ""
	var units := maxi(0, int(city.get("warehouse_stockpile_units", 0)))
	var products: Array = city.get("warehouse_stockpile_products", [])
	var product_text := _limited_name_list(products, 3)
	var expires_at := float(city.get("warehouse_stockpile_expires_at", -1.0))
	var duration_text := _duration_short_text(maxf(1.0, expires_at - game_time)) if expires_at >= 0.0 else "未知"
	return "匿名仓储%d笔/%d单位/%s/%s" % [
		count,
		units,
		product_text if product_text != "" else "未知商品",
		duration_text,
	]


func _city_route_flow_status_text(city: Dictionary) -> String:
	var multiplier: float = float(city.get("route_flow_multiplier", 1.0))
	if multiplier <= 1.001:
		return "无"
	var source := String(city.get("route_flow_source", ""))
	var source_suffix := "｜%s" % source if source != "" else ""
	return "×%.2f（%s%s）" % [multiplier, _boon_duration_text(_remaining_effect_seconds(city, "route_flow_seconds", "route_flow_turns")), source_suffix]


func _city_contract_status_text(city: Dictionary) -> String:
	var contract_income := int(city.get("contract_income_bonus", 0))
	if contract_income <= 0:
		return "无"
	var source := String(city.get("contract_source", ""))
	var source_suffix := "｜%s" % source if source != "" else ""
	return "+%d/min（%s%s）" % [
		contract_income,
		_boon_duration_text(_remaining_effect_seconds(city, "contract_seconds", "contract_turns")),
		source_suffix,
	]




































func _economy_effect_callout_position() -> Vector2:
	if selected_district >= 0 and selected_district < districts.size():
		return _district_center(selected_district)
	return Vector2(map_width_m * 0.5, map_height_m * 0.5)










func _interaction_target_label(player_index: int) -> String:
	return "玩家%d" % (player_index + 1) if player_index >= 0 and player_index < players.size() else "未知玩家"


func _apply_player_hand_disrupt(acting_player_index: int, target_player_index: int, skill: Dictionary) -> bool:
	return _resolve_player_hand_interaction(acting_player_index, target_player_index, skill)


func _apply_player_hand_steal(acting_player_index: int, target_player_index: int, skill: Dictionary) -> bool:
	return _resolve_player_hand_interaction(acting_player_index, target_player_index, skill)


func _resolve_player_hand_interaction(acting_player_index: int, target_player_index: int, skill: Dictionary) -> bool:
	var source := String(skill.get("name", "星链拆解" if str(skill.get("kind", "")) == "player_hand_disrupt" else "影仓牵引"))
	if acting_player_index < 0 or acting_player_index >= players.size() or target_player_index < 0 or target_player_index >= players.size() or target_player_index == acting_player_index:
		_log("%s需要指定一名其他玩家。" % source)
		return false
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator == null or not runtime_coordinator.has_method("plan_player_hand_interaction") or not runtime_coordinator.has_method("commit_player_hand_interaction"):
		_mark_game_runtime_coordinator_missing(true)
		_log("%s结算失败：玩家手牌互动服务不可用。" % source)
		return false
	var acting_player: Dictionary = players[acting_player_index]
	var target_player: Dictionary = players[target_player_index]
	var request := _player_hand_interaction_request(acting_player_index, target_player_index, skill, acting_player, target_player)
	var plan_variant: Variant = runtime_coordinator.call("plan_player_hand_interaction", request)
	var plan: Dictionary = plan_variant if plan_variant is Dictionary else {}
	if str(plan.get("status", "")) != "ready":
		_log("%s结算失败：互动计划被拒绝（%s）。" % [source, str(plan.get("reason", "unknown"))])
		return false
	plan["selected_slots"] = _select_player_hand_interaction_slots(plan)
	var result_variant: Variant = runtime_coordinator.call("commit_player_hand_interaction", acting_player, target_player, request, plan)
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	if not bool(result.get("committed", false)):
		_log("%s结算失败：互动事务未提交（%s）。" % [source, str(result.get("reason", "unknown"))])
		return false
	players[acting_player_index] = acting_player
	players[target_player_index] = target_player
	_forward_player_hand_interaction_private_intents(acting_player_index, target_player_index, result.get("private_event_intents", []))
	_forward_player_hand_interaction_public_intents(skill, result.get("public_event_intents", []), result.get("action_callout_intents", []))
	if not bool(result.get("resolution_success", false)):
		var affected_text := "可牵取" if str(skill.get("kind", "")) == "player_hand_steal" else "可影响"
		_log("%s结算失败：%s没有%s的普通手牌。" % [source, _interaction_target_label(target_player_index), affected_text])
	return bool(result.get("resolution_success", false))


func _player_hand_interaction_request(acting_player_index: int, target_player_index: int, skill: Dictionary, acting_player: Dictionary, target_player: Dictionary) -> Dictionary:
	return {
		"actor_player_index": acting_player_index,
		"target_player_index": target_player_index,
		"skill": skill.duplicate(true),
		"actor_inventory": _card_inventory_snapshot(acting_player),
		"target_inventory": _card_inventory_snapshot(target_player),
		"card_catalog": _player_hand_interaction_card_catalog(acting_player, target_player),
	}


func _player_hand_interaction_card_catalog(acting_player: Dictionary, target_player: Dictionary) -> Dictionary:
	var catalog := {}
	for player_variant in [acting_player, target_player]:
		var player_state: Dictionary = player_variant
		for skill_variant in player_state.get("slots", []):
			if not (skill_variant is Dictionary):
				continue
			var card_id := str((skill_variant as Dictionary).get("name", ""))
			while not card_id.is_empty() and not catalog.has(card_id):
				var card := _make_skill(card_id)
				if card.is_empty():
					break
				var next_upgrade_id := _next_upgrade_name(card_id)
				catalog[card_id] = {
					"family": _game_runtime_coordinator_node().card_family_id(card_id),
					"rank": maxi(1, _game_runtime_coordinator_node().card_rank(card_id)),
					"counts_toward_hand_limit": _counts_toward_hand_limit(card),
					"next_upgrade_id": next_upgrade_id,
					"next_upgrade_card": _make_skill(next_upgrade_id) if not next_upgrade_id.is_empty() else {},
				}
				card_id = next_upgrade_id
	return catalog


func _select_player_hand_interaction_slots(plan: Dictionary) -> Array:
	var remaining: Array = (plan.get("candidate_slots", []) as Array).duplicate() if plan.get("candidate_slots", []) is Array else []
	var selected_slots: Array = []
	for _draw_index in range(int(plan.get("selection_draw_count", 0))):
		if remaining.is_empty():
			break
		var choice_index := rng.randi_range(0, remaining.size() - 1)
		selected_slots.append(int(remaining[choice_index]))
		remaining.remove_at(choice_index)
	return selected_slots


func _forward_player_hand_interaction_private_intents(acting_player_index: int, target_player_index: int, intents_variant: Variant) -> void:
	var intents: Array = intents_variant if intents_variant is Array else []
	for intent_variant in intents:
		if not (intent_variant is Dictionary):
			continue
		var intent: Dictionary = intent_variant
		var source := str(intent.get("source_label", "互动卡牌"))
		var card_id := str(intent.get("card_id", ""))
		match str(intent.get("intent_kind", "")):
			"target_card_lost":
				_record_player_economic_event(target_player_index, "直接互动", "手牌被影响", 0, "%s使你失去%s；这条具体牌名只在你的私人流水中可见。" % [source, _card_display_name(card_id)])
			"target_card_locked":
				_record_player_economic_event(target_player_index, "直接互动", "手牌被封锁", 0, "%s使%s被封锁%s；具体牌名只在你的私人流水中可见。" % [source, _card_display_name(card_id), _duration_short_text(float(intent.get("duration_seconds", 0.0)))])
			"actor_card_received":
				_record_player_economic_event(acting_player_index, "直接互动", "牵取手牌", 0, "%s牵取到%s；来源目标对全员不可见。" % [source, _card_display_name(card_id)])
			"target_card_spend":
				_record_player_card_spend(target_player_index, int(intent.get("amount", 0)), str(intent.get("label", "直接互动重组成本")), source)
			"actor_card_income":
				_record_player_card_income(acting_player_index, int(intent.get("amount", 0)), str(intent.get("label", source)), str(intent.get("detail", "牵取失败补偿")))


func _forward_player_hand_interaction_public_intents(skill: Dictionary, public_variant: Variant, callout_variant: Variant) -> void:
	var public_intents: Array = public_variant if public_variant is Array else []
	for intent_variant in public_intents:
		if not (intent_variant is Dictionary):
			continue
		var intent: Dictionary = intent_variant
		var source := str(intent.get("source_label", skill.get("name", "互动卡牌")))
		var target_label := _interaction_target_label(int(intent.get("target_player_index", -1)))
		if str(intent.get("interaction_kind", "")) == "player_hand_disrupt":
			_log("%s匿名影响%s：拆掉%d张普通手牌%s%s；具体牌名和手牌数量仍为私密。" % [source, target_label, int(intent.get("removed_count", 0)), "，并封锁1张手牌" if int(intent.get("locked_count", 0)) > 0 else "", "，目标支付重组成本¥%d" % int(intent.get("target_cash_penalty", 0)) if int(intent.get("target_cash_penalty", 0)) > 0 else ""])
		else:
			_log("%s匿名影响%s：牵取%d张、拆除转化%d张%s；具体牌名、手牌数量和收牌者仍为私密。" % [source, target_label, int(intent.get("transferred_count", 0)), int(intent.get("converted_count", 0)), "，并封锁1张手牌" if int(intent.get("locked_count", 0)) > 0 else ""])
	var callout_intents: Array = callout_variant if callout_variant is Array else []
	for intent_variant in callout_intents:
		if not (intent_variant is Dictionary):
			continue
		var intent: Dictionary = intent_variant
		var target_label := _interaction_target_label(int(intent.get("target_player_index", -1)))
		var disrupt := str(intent.get("interaction_kind", "")) == "player_hand_disrupt"
		_add_action_callout("直接互动", str(intent.get("source_label", skill.get("name", "互动卡牌"))), "%s被%s；%s" % [target_label, "拆牌" if disrupt else "牵牌", "来源匿名，手牌细节私密。" if disrupt else "目标公开，来源匿名。"], _card_presentation_color(skill), _district_center(selected_district))








func _district_purchase_settlement_request(player_index: int, district_index: int, skill_name: String, price: int, supply_revision: String, authorization: Dictionary, discard_slot: int = -1) -> Dictionary:
	if player_index < 0 or player_index >= players.size() or district_index < 0 or district_index >= districts.size():
		return {}
	var player: Dictionary = players[player_index]
	var discard_ledger_context: Dictionary = {}
	var player_slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	if discard_slot >= 0 and discard_slot < player_slots.size() and player_slots[discard_slot] is Dictionary:
		var discarded_skill: Dictionary = player_slots[discard_slot]
		var discarded_card_id := str(discarded_skill.get("name", "旧牌"))
		discard_ledger_context = {
			"cycle": _product_market_cycle(),
			"time": game_time,
			"kind": "手牌整理",
			"label": "弃牌换购",
			"amount": 0,
			"detail": "以购买%s：弃掉%s；普通手牌上限%d张。此事只写入本玩家私人流水。" % [_card_display_name(skill_name), _card_display_name(discarded_card_id), PLAYER_HAND_LIMIT],
			"ledger_limit": ECONOMY_LEDGER_LIMIT,
		}
	return {
		"player_index": player_index,
		"district_index": district_index,
		"card_id": skill_name,
		"price": price,
		"player_cash": int(player.get("cash", 0)),
		"supply_revision": supply_revision,
		"authorization": authorization.duplicate(true),
		"supply_contains_card": _district_has_card(district_index, skill_name),
		"discard_slot": discard_slot,
		"inventory": _district_purchase_inventory_snapshot(player, skill_name, discard_slot),
		"discard_ledger_context": discard_ledger_context,
		"purchase_ledger_context": {
			"cycle": _product_market_cycle(),
			"time": game_time,
			"kind": "卡牌支出",
			"label": "购买%s" % _card_display_name(skill_name),
			"amount": -price,
			"detail": str(districts[district_index].get("name", "区域")),
			"ledger_limit": ECONOMY_LEDGER_LIMIT,
		},
		"cash_history_limit": ECONOMY_HISTORY_LIMIT,
	}


func _buy_selected_skill() -> void:
	if _runtime_session_finished():
		return
	if _has_pending_target_choice():
		_log("请先完成当前卡牌的目标怪兽选择。")
		return
	if _has_pending_player_target_choice():
		_log("请先完成当前卡牌的目标玩家选择。")
		return
	_sync_selected_district_card()
	_buy_card_for_player_from_district(selected_player, selected_district, selected_market_skill, false, true)
	_refresh_ui()


func _buy_card_for_player_from_district(player_index: int, district_index: int, skill_name: String, anonymous: bool = false, ignore_cooldown: bool = false, discard_slot: int = -1, locked_quote_id: String = "") -> bool:
	if _runtime_session_finished() or player_index < 0 or player_index >= players.size():
		return false
	if _player_is_eliminated(player_index):
		if not anonymous:
			_log("%s已经破产出局，不能继续购买卡牌。" % _player_name(player_index))
		return false
	var player: Dictionary = players[player_index]
	var actor_label := "匿名财团" if anonymous else String(player.get("name", "玩家"))
	skill_name = _canonical_card_supply_name(skill_name)
	if skill_name == "" or not _game_runtime_coordinator_node().card_exists(skill_name):
		if not anonymous:
			_log("没有可获取的选中卡牌。")
		return false
	if district_index < 0 or district_index >= districts.size() or bool(districts[district_index].get("destroyed", false)):
		if not anonymous:
			_log("目标区域无效或已被破坏，不能从这里获取卡牌。")
		return false
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator == null or not runtime_coordinator.has_method("authorize_card_market_purchase") or not runtime_coordinator.has_method("plan_district_purchase_settlement") or not runtime_coordinator.has_method("commit_district_purchase_settlement"):
		if not anonymous:
			_log("购买窗口或结算服务尚未就绪。")
		return false
	if not runtime_coordinator.has_method("district_purchase_window_active") or not bool(runtime_coordinator.call("district_purchase_window_active", player_index, district_index)):
		_open_district_card_purchase_window(district_index, player_index, discard_slot >= 0)
	var supply_revision := str(districts[district_index].get("card_choices", []))
	if runtime_coordinator.has_method("mark_district_supply_revision"):
		runtime_coordinator.call("mark_district_supply_revision", player_index, district_index, supply_revision)
	var quote: Dictionary = {}
	if not locked_quote_id.is_empty() and runtime_coordinator.has_method("card_market_active_quote"):
		var active_quote_variant: Variant = runtime_coordinator.call("card_market_active_quote", player_index, district_index)
		quote = (active_quote_variant as Dictionary).duplicate(true) if active_quote_variant is Dictionary else {}
		if str(quote.get("quote_id", "")) != locked_quote_id:
			quote = {}
	else:
		quote = _request_card_market_quote(skill_name, district_index, player_index)
	var quote_id := str(quote.get("quote_id", ""))
	var authorization_variant: Variant = runtime_coordinator.call("authorize_card_market_purchase", {
		"quote_id": quote_id,
		"quote_fingerprint": str(quote.get("quote_fingerprint", "")),
		"player_index": player_index,
		"district_index": district_index,
		"card_id": skill_name,
		"supply_revision": supply_revision,
	})
	var authorization: Dictionary = authorization_variant if authorization_variant is Dictionary else {}
	if not bool(authorization.get("authorized", false)):
		if not anonymous:
			var failure_reason := str(authorization.get("reason", "quote_unavailable"))
			_log("报价未授权本次操作：%s。" % failure_reason)
		return false
	if not _district_has_card(district_index, skill_name):
		if not anonymous:
			_log("%s不在当前区域候选中；%s。" % [_card_display_name(skill_name), _card_choice_location_summary(skill_name)])
		return false
	var price := int(authorization.get("final_price", -1))
	if price < 0:
		return false
	var settlement_request := _district_purchase_settlement_request(player_index, district_index, skill_name, price, supply_revision, authorization, discard_slot)
	var plan_variant: Variant = runtime_coordinator.call("plan_district_purchase_settlement", settlement_request)
	var settlement_plan: Dictionary = plan_variant if plan_variant is Dictionary else {}
	if str(settlement_plan.get("status", "")) == "requires_discard" and discard_slot < 0 and anonymous:
		discard_slot = _ai_runtime_call("_ai_discard_slot_for_purchase", [player_index, skill_name])
		settlement_request = _district_purchase_settlement_request(player_index, district_index, skill_name, price, supply_revision, authorization, discard_slot)
		plan_variant = runtime_coordinator.call("plan_district_purchase_settlement", settlement_request)
		settlement_plan = plan_variant if plan_variant is Dictionary else {}
	if str(settlement_plan.get("status", "")) == "requires_discard" and discard_slot < 0:
		_open_discard_purchase_choice(player_index, district_index, skill_name, price, quote_id, ignore_cooldown)
		if not anonymous:
			_refresh_ui()
		return false
	if str(settlement_plan.get("status", "")) != "ready":
		if not anonymous:
			var plan_reason := str(settlement_plan.get("reason", "purchase_rejected"))
			if plan_reason == "insufficient_cash":
				_log("%s资金不足，购买%s需要¥%d，当前只有¥%d。" % [actor_label, _card_display_name(skill_name), price, int(player.get("cash", 0))])
			elif plan_reason == "invalid_discard_slot":
				_record_player_economic_event(player_index, "手牌整理", "弃牌选择失效", 0, "私密弃牌选择已经失效，请重新发起购牌。")
				_log("一次购牌未完成：具体玩家手牌状态、牌名和弃牌情况不公开。")
			else:
				_record_player_economic_event(player_index, "卡牌购买", "购买未完成", 0, "%s暂不能接收；可能已达最高级，或没有可私密弃掉的普通手牌。" % _card_display_name(skill_name))
				_log("一次购牌未完成：具体玩家手牌状态、牌名和弃牌情况不公开。")
		return false
	var current_authorization_variant: Variant = runtime_coordinator.call("authorize_card_market_purchase", {
		"quote_id": quote_id,
		"quote_fingerprint": str(quote.get("quote_fingerprint", "")),
		"player_index": player_index,
		"district_index": district_index,
		"card_id": skill_name,
		"supply_revision": supply_revision,
	})
	var current_authorization: Dictionary = current_authorization_variant if current_authorization_variant is Dictionary else {}
	var current_facts := _district_purchase_settlement_request(player_index, district_index, skill_name, price, supply_revision, current_authorization, discard_slot)
	var commit_variant: Variant = runtime_coordinator.call("commit_district_purchase_settlement", player, current_facts, settlement_plan)
	var commit_result: Dictionary = commit_variant if commit_variant is Dictionary else {}
	if not bool(commit_result.get("committed", false)):
		if not anonymous:
			_record_player_economic_event(player_index, "卡牌购买", "购买未完成", 0, "购买提交前状态发生变化，请重新发起购牌。")
			_log("一次购牌未完成：结算前状态已变化，具体玩家手牌、现金和弃牌情况不公开。")
		return false
	players[player_index] = player
	if int(pending_discard_purchase.get("player_index", -1)) == player_index and String(pending_discard_purchase.get("skill_name", "")) == skill_name:
		pending_discard_purchase = {}
	_log("一次匿名购牌在%s完成；买家、具体卡牌、手牌数量和弃牌情况不公开。" % districts[district_index]["name"])
	if not anonymous and player_index == selected_player:
		_complete_scenario_signal("card_bought", "完成购牌：%s的一张牌进入你的手牌。" % String(districts[district_index].get("name", "区域")), "after_buy", "player_hand")
	if _active_runtime_scenario_id() == "first_table" and skill_name == _first_table_followup_card_name() and not anonymous and player_index == selected_player:
		_complete_scenario_signal("followup_card_bought", "购买第二张经营牌：%s进入你的手牌。" % _card_display_name(skill_name), "after_followup_buy", "player_hand")
	_grant_role_bonus_card_on_purchase(player_index, district_index, skill_name, anonymous)
	runtime_coordinator.call("record_weather_public_response", district_index, "buy_after_forecast")
	return true


func _non_target_skill_resolution_kinds() -> Array:
	return [
		"monster_card",
		"monster_bound_action",
		"public_facility",
		"city_revenue_boost",
		"product_speculation",
		"product_futures",
		"city_gdp_derivative",
		"product_contract_boon",
		"area_trade_contract",
		"market_stabilize",
		"product_growth_boon",
		"weather_control",
		"intel_city_reveal",
		"intel_card_trace",
		"intel_contract_trace",
		"supply_draw",
		"card_counter",
		"military_force",
		"military_command",
	]


func _skill_has_resolution_handler(skill: Dictionary) -> bool:
	var kind := String(skill.get("kind", ""))
	if kind == "":
		return false
	var target_status := _card_play_target_snapshot(skill)
	if bool(target_status.get("targets_monster", false)):
		return true
	if bool(target_status.get("targets_player", false)):
		return true
	return _non_target_skill_resolution_kinds().has(kind)


func _finish_played_skill(player_index: int, slot_index: int, skill: Dictionary, cooldown: float = COMMAND_COOLDOWN) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	# Shared-window submission is a commitment: normal queued cards pay on submit.
	# Direct/legacy callers still pay here, while this private marker prevents doubles.
	if not bool(skill.get("_play_cost_paid_on_queue", false)):
		_pay_skill_play_cost(player_index, skill)
	skill.erase("_play_cost_paid_on_queue")
	if slot_index >= 0 and slot_index < (players[player_index].get("slots", []) as Array).size():
		if bool(skill.get("persistent", false)):
			skill["cooldown_left"] = max(float(skill.get("cooldown_left", 0.0)), float(skill.get("cooldown", DEFAULT_SKILL_COOLDOWN)))
			players[player_index]["slots"][slot_index] = skill
		else:
			players[player_index]["slots"][slot_index] = null
	players[player_index]["action_cooldown"] = max(float(players[player_index].get("action_cooldown", 0.0)), cooldown)
	var response_region := int(skill.get("target_district", selected_district))
	if response_region >= 0:
		var response_category := "build_after_forecast" if str(skill.get("kind", "")) in ["public_facility", "city_development", "city_product_upgrade", "city_product_shift"] else "play_after_forecast"
		_game_runtime_coordinator_node().record_weather_public_response(response_region, response_category)


func _card_resolution_duration(_skill: Dictionary) -> float:
	if card_resolution_force_duration >= 0.0:
		return card_resolution_force_duration
	if DisplayServer.get_name().to_lower() == "headless":
		return 0.0
	return CARD_RESOLUTION_DISPLAY_SECONDS


func _card_simultaneous_window_duration(sequence: int = -1) -> float:
	if card_resolution_force_simultaneous_window >= 0.0:
		return card_resolution_force_simultaneous_window
	if DisplayServer.get_name().to_lower() == "headless":
		return 0.0
	return float(_card_group_cadence_snapshot(sequence).get("total_seconds", 0.0))


func _card_group_lock_duration() -> float:
	var lock_seconds := float(_card_group_cadence_snapshot().get("lock_seconds", 0.0))
	if card_resolution_force_simultaneous_window >= lock_seconds:
		return lock_seconds
	if card_resolution_force_simultaneous_window >= 0.0 or DisplayServer.get_name().to_lower() == "headless":
		return 0.0
	return lock_seconds


func _card_group_public_bid_duration() -> float:
	var public_bid_seconds := float(_card_group_cadence_snapshot().get("public_bid_seconds", 0.0))
	if card_resolution_force_simultaneous_window >= 0.0 or DisplayServer.get_name().to_lower() == "headless":
		return 0.0
	return public_bid_seconds


func _card_group_cadence_snapshot(sequence: int = -1) -> Dictionary:
	var controller := _card_resolution_controller_node()
	if controller != null and controller.has_method("cadence_snapshot"):
		var resolved_sequence := card_group_window_sequence if sequence < 0 else sequence
		var value: Variant = controller.call("cadence_snapshot", resolved_sequence)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	_mark_card_resolution_controller_missing("cadence snapshot", true)
	return {}


func _card_group_phase_remaining_seconds() -> float:
	var remaining := maxf(0.0, card_resolution_simultaneous_timer)
	var cadence := _card_group_cadence_snapshot()
	match _card_group_window_phase():
		"planning":
			return maxf(0.0, remaining - float(cadence.get("public_bid_seconds", 0.0)) - float(cadence.get("lock_seconds", 0.0)))
		"public_bid":
			return maxf(0.0, remaining - float(cadence.get("lock_seconds", 0.0)))
		"lock":
			return remaining
	return 0.0


func _card_group_phase_label(phase: String = "") -> String:
	var resolved_phase := _card_group_window_phase() if phase.is_empty() else phase
	match resolved_phase:
		"planning": return "规划"
		"public_bid": return "公开竞价"
		"lock": return "锁牌"
		"resolving": return "结算"
	return "空闲"


func _card_group_window_cadence_text(sequence: int = -1) -> String:
	var cadence := _card_group_cadence_snapshot(sequence)
	return "%d秒共享窗：规划%d秒、公开竞价%d秒、锁牌%d秒" % [
		int(cadence.get("total_seconds", 0)),
		int(cadence.get("planning_seconds", 0)),
		int(cadence.get("public_bid_seconds", 0)),
		int(cadence.get("lock_seconds", 0)),
	]


func _card_group_next_window_sequence() -> int:
	var service := _card_resolution_queue_service_node()
	var snapshot_variant: Variant = service.call("debug_snapshot") if service != null and service.has_method("debug_snapshot") else {}
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	return maxi(0, int(snapshot.get("last_group_window_sequence", -1)) + 1)


func _begin_card_group_window(reference_player: int, sequence: int) -> bool:
	var controller := _card_resolution_controller_node()
	if controller == null or not controller.has_method("begin_group_window"):
		_mark_card_resolution_controller_missing("begin group window", true)
		return false
	controller.call("begin_group_window", _card_simultaneous_window_duration(sequence), reference_player, sequence)
	return true


func _card_group_window_phase() -> String:
	var controller := _card_resolution_controller_node()
	if controller != null and controller.has_method("current_phase"):
		return str(controller.call("current_phase", _card_resolution_controller_facts()))
	_mark_card_resolution_controller_missing("window phase", true)
	return "controller_missing"


func _card_group_submissions_open() -> bool:
	var controller := _card_resolution_controller_node()
	if controller != null and controller.has_method("submissions_open"):
		return bool(controller.call("submissions_open", _card_resolution_controller_facts()))
	_mark_card_resolution_controller_missing("submission gate", true)
	return false


func _card_group_bidding_open() -> bool:
	var controller := _card_resolution_controller_node()
	if controller != null and controller.has_method("bidding_open"):
		return bool(controller.call("bidding_open", _card_resolution_controller_facts()))
	_mark_card_resolution_controller_missing("bidding gate", true)
	return false


func _card_group_limit_for_player(_player_index: int) -> int:
	var rules := _card_group_runtime_rules()
	var tutorial_limit := int(rules.get("tutorial_group_card_limit", SharedCardGroupWindowScript.TUTORIAL_MAX_CARDS))
	var standard_limit := int(rules.get("standard_group_card_limit", SharedCardGroupWindowScript.STANDARD_MAX_CARDS))
	return SharedCardGroupWindowScript.card_limit(tutorial_limit if _active_runtime_scenario_id() == "first_table" else standard_limit)


func _card_group_runtime_rules() -> Dictionary:
	var coordinator := _game_runtime_coordinator_node()
	if coordinator != null and coordinator.has_method("card_group_runtime_rules"):
		var value: Variant = coordinator.call("card_group_runtime_rules")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _card_group_count_for_player(player_index: int) -> int:
	return SharedCardGroupWindowScript.group_card_count(_card_resolution_current_queue(), player_index)


func _card_counter_response_duration() -> float:
	if DisplayServer.get_name().to_lower() == "headless":
		return 0.0
	return _ruleset_timing_seconds(&"counter_window_seconds")


func _card_can_open_counter_window(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	if skill.is_empty():
		return false
	var target_status := _card_play_target_snapshot(skill)
	if bool(target_status.get("is_counter", false)):
		return false
	if not bool(target_status.get("counterable_player_interaction", false)):
		return false
	if bool(entry.get("countered", false)):
		return false
	return true


func _begin_card_counter_response_window() -> void:
	if _card_resolution_active_entry().is_empty():
		return
	if not _card_can_open_counter_window(_card_resolution_active_entry()):
		_complete_active_card_resolution()
		return
	card_resolution_counter_window_active = true
	card_resolution_counter_timer = _card_counter_response_duration()
	_announce_card_counter_response_window()
	if card_resolution_counter_timer <= 0.0:
		_complete_active_card_resolution()


func _announce_card_counter_response_window() -> void:
	if _card_resolution_active_entry().is_empty():
		return
	var skill: Dictionary = _card_resolution_active_entry().get("skill", {}) as Dictionary
	var label := _card_display_name(String(skill.get("name", "匿名牌")))
	_log("%s展示结束，进入%.0f秒玩家互动响应窗口；相位否决只可取消这类直接互动牌。" % [label, _ruleset_timing_seconds(&"counter_window_seconds")])
	_show_card_resolution_overlay(_card_resolution_active_entry(), card_resolution_counter_timer)


func _update_card_resolution_queue(delta: float) -> void:
	var controller := _card_resolution_controller_node()
	if controller == null or not controller.has_method("tick"):
		_mark_card_resolution_controller_missing("runtime tick", true)
		return
	var commands_variant: Variant = controller.call("tick", delta, _card_resolution_controller_facts())
	var commands: Array = commands_variant if commands_variant is Array else []
	for command_variant in commands:
		var command: Dictionary = command_variant if command_variant is Dictionary else {}
		_apply_card_resolution_controller_transition(command)


func _apply_card_resolution_controller_transition(command: Dictionary) -> void:
	match str(command.get("transition", "")):
		"show_active":
			_show_card_resolution_overlay(_card_resolution_active_entry(), maxf(0.0, float(command.get("remaining", 0.0))))
		"begin_counter":
			_announce_card_counter_response_window()
		"complete_active":
			_complete_active_card_resolution()
		"start_next":
			_start_next_card_resolution()
		"show_group_window":
			_show_card_batch_lobby_overlay()
		"enter_public_bid":
			_log("共享卡牌窗进入%d秒公开竞价阶段：不能再提交普通牌，可调整既有组报价。" % int(_card_group_cadence_snapshot().get("public_bid_seconds", 0)))
		"enter_lock":
			_log("共享卡牌窗进入%d秒锁牌阶段：不能再提交新牌或修改报价。" % int(_card_group_cadence_snapshot().get("lock_seconds", 0)))
		"all_ready_public_bid":
			_log("所有仍在局内的席位均已完成规划，窗口推进到公开竞价阶段。")
		"all_ready_lock":
			_log("所有仍在局内的席位均已完成公开竞价，窗口推进到锁牌阶段。")
		"all_ready_lock_batch":
			_log("所有仍在局内的席位均已确认锁牌，卡牌组窗口提前封盘。")
		"lock_batch":
			_lock_card_resolution_batch()
		"hide_overlay":
			_hide_card_resolution_overlay()

func _queued_skill_from_entry(entry: Dictionary) -> Dictionary:
	var player_index := int(entry.get("player_index", -1))
	var slot_index := int(entry.get("slot_index", -1))
	if player_index >= 0 and player_index < players.size():
		var slots: Array = (players[player_index] as Dictionary).get("slots", [])
		if slot_index >= 0 and slot_index < slots.size() and slots[slot_index] is Dictionary:
			return (slots[slot_index] as Dictionary).duplicate(true)
	var snapshot: Variant = entry.get("skill", {})
	return (snapshot as Dictionary).duplicate(true) if snapshot is Dictionary else {}


func _sort_card_resolution_queue() -> void:
	var service := _card_resolution_queue_service_node()
	if service != null and service.has_method("sort_current"):
		service.call("sort_current", card_resolution_batch_reference_player, players.size())


func _highest_card_resolution_bid() -> int:
	var service := _card_resolution_queue_service_node()
	var cents := int(service.call("highest_priority_bid_cents")) if service != null and service.has_method("highest_priority_bid_cents") else 0
	return int(float(cents) / 100.0)


func _card_resolution_leading_queue_index() -> int:
	var service := _card_resolution_queue_service_node()
	return int(service.call("leading_index", card_resolution_batch_reference_player, players.size())) if service != null and service.has_method("leading_index") else -1


func _card_resolution_entry_card_label(entry: Dictionary) -> String:
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	var card_name := String(skill.get("name", "匿名卡牌"))
	var card_label := _card_display_name(card_name)
	return card_name if card_label == "" else card_label


func _card_resolution_tip_clue_text(entry: Dictionary) -> String:
	var explicit_clue := String(entry.get("tip_payment_clue", ""))
	if explicit_clue != "":
		return explicit_clue
	var bid_cents := int(entry.get("winning_priority_bid_cents", entry.get("priority_bid_cents", 0)))
	var bid := int(float(bid_cents) / 100.0)
	if bid_cents <= 0:
		return "本组零报价，按顺位座次结算，不发生资金转移。"
	return "本组优先报价¥%d已进入下一场怪兽赌局公共奖池；同组卡牌连续结算，来源身份待猜。" % bid


func _card_resolution_groups() -> Array:
	var service := _card_resolution_queue_service_node()
	var value: Variant = service.call("groups", card_resolution_batch_reference_player, players.size()) if service != null and service.has_method("groups") else []
	return (value as Array).duplicate(true) if value is Array else []


func _apply_card_group_wager_pool_receipt(receipt: Dictionary) -> Dictionary:
	if str(receipt.get("recipient_kind", "")) != "public_monster_wager_pool" or int(receipt.get("currency_scale", 0)) != 100:
		return {"applied": false, "reason": "invalid_public_wager_pool_receipt"}
	var total_cents := maxi(0, int(receipt.get("total_cents", 0)))
	if total_cents % 100 != 0:
		return {"applied": false, "reason": "wager_pool_receipt_mixed_unit"}
	var total_cash := int(float(total_cents) / 100.0)
	if total_cash > 0:
		monster_runtime_controller.add_public_wager_pool(total_cash)
	for entry_variant in _card_resolution_current_queue():
		if entry_variant is Dictionary:
			var entry := (entry_variant as Dictionary).duplicate(true)
			entry["tip_payment_clue"] = _card_resolution_tip_clue_text(entry)
			_store_card_resolution_entry(entry)
	if total_cash > 0:
		_log("共享卡牌窗封盘：全部优先报价共¥%d进入下一场怪兽赌局公共奖池。" % total_cash)
	return {
		"applied": true,
		"reason": "",
		"receipt_id": str(receipt.get("receipt_id", "")),
		"public_pool_delta": total_cash,
		"public_pool_total": monster_runtime_controller.public_card_bid_monster_wager_pool,
	}


func _queue_skill_resolution(player_index: int, slot_index: int, target_slot: int = -1, target_player: int = -1) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	if _player_is_eliminated(player_index):
		_log("%s已经破产出局，不能继续提交匿名卡牌。" % _player_name(player_index))
		return false
	var player: Dictionary = players[player_index]
	var slots: Array = player.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		return false
	if not (slots[slot_index] is Dictionary):
		return false
	var skill: Dictionary = slots[slot_index]
	if _is_v06_runtime_card(skill):
		return _play_v06_runtime_card_for_player(player_index, slot_index)
	var card_label := _card_display_name(String(skill.get("name", "")))
	if card_label == "":
		card_label = String(skill.get("name", "卡牌"))
	if bool(skill.get("queued_for_resolution", false)):
		_log("%s已经在结算队列中，不能重复提交。" % card_label)
		return false
	var eligibility := _card_play_eligibility_snapshot(player_index, skill, "rule")
	var target_status: Dictionary = eligibility.get("target_status", {}) as Dictionary
	var reactive_counter := bool(target_status.get("is_counter", false)) and card_resolution_counter_window_active and not _card_resolution_active_entry().is_empty()
	if not bool(eligibility.get("allowed", false)):
		_log_card_play_rejection(eligibility, skill)
		return false
	var contract_context := {}
	if String(skill.get("kind", "")) == "area_trade_contract":
		var contract_controller := _contract_runtime_controller_node()
		var contract_selection := contract_controller.selection_snapshot() if contract_controller != null else {"source_district": -1, "target_district": -1}
		contract_context = contract_controller.offer_context(skill, player_index, int(contract_selection.get("source_district", -1)), int(contract_selection.get("target_district", -1)), selected_trade_product) if contract_controller != null else {"error": "合约运行时控制器不可用", "reason": "contract_controller_missing"}
		var contract_error := String(contract_context.get("error", ""))
		if contract_error != "":
			_log(contract_error)
			return false
	var play_cash_cost := int(eligibility.get("cash_cost", 0))
	var requirement_status: Dictionary = eligibility.get("requirement_status", {}) as Dictionary
	var queued_skill := skill.duplicate(true)
	if String(queued_skill.get("kind", "")) == "product_futures":
		var market_controller := _product_market_runtime_controller_node()
		if market_controller == null:
			_log("%s未提交：商品期货条款控制器不可用。" % card_label)
			return false
		queued_skill = market_controller.skill_with_terms(String(queued_skill.get("name", "")), queued_skill)
		if queued_skill.has("futures_terms_error"):
			_log("%s未提交：商品期货条款不可用（%s）。" % [card_label, str(queued_skill.get("futures_terms_error", "terms_missing"))])
			return false
	if String(queued_skill.get("kind", "")) == "city_gdp_derivative":
		var derivative_controller := _city_gdp_derivative_runtime_controller_node()
		if derivative_controller == null:
			_log("%s未提交：城市GDP衍生品条款控制器不可用。" % card_label)
			return false
		queued_skill = derivative_controller.skill_with_terms(String(queued_skill.get("name", "")), queued_skill)
		if queued_skill.has("gdp_derivative_terms_error"):
			_log("%s未提交：城市GDP衍生品条款不可用（%s）。" % [card_label, str(queued_skill.get("gdp_derivative_terms_error", "terms_missing"))])
			return false
	if String(queued_skill.get("kind", "")) == "public_facility":
		queued_skill["target_region_index"] = selected_district
	var entry_context := {
		"target_slot": target_slot,
		"target_player": target_player,
		"selected_district": selected_district,
		"selected_trade_product": selected_trade_product,
		"contract_source_district": int(contract_context.get("source", -1)),
		"contract_target_district": int(contract_context.get("target", -1)),
		"contract_target_owner": int(contract_context.get("target_owner", -1)),
		"contract_target_project_ids": (contract_context.get("target_project_ids", []) as Array).duplicate(true),
		"contract_products": (contract_context.get("products", []) as Array).duplicate(true),
		"contract_response": ContractRuntimeController.RESPONSE_PENDING if String(skill.get("kind", "")) == "area_trade_contract" else "",
		"contract_response_player": -1,
		"contract_response_time": -1.0,
		"queued_time": game_time,
		"play_requirement_kind": String(requirement_status.get("kind", "none")),
		"play_requirement_scope": String(requirement_status.get("scope", "")),
		"play_requirement_gdp_share_percent": int(requirement_status.get("required_share_percent", 0)),
		"play_requirement_district": int(requirement_status.get("qualifying_district", -1)),
		# Legacy save keys remain neutral so old readers never invent a product gate.
		"play_requirement_product": "",
		"play_requirement_flow": 0,
		"play_requirement_text": String(requirement_status.get("requirement_text", "条件：无")),
	}
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("plan_card_resolution_queue_submission") or not coordinator.has_method("commit_card_resolution_queue_submission"):
		_mark_game_runtime_coordinator_missing(true)
		return false
	var queue_plan_variant: Variant = coordinator.call("plan_card_resolution_queue_submission", {
		"player_index": player_index,
		"slot_index": slot_index,
		"already_queued": bool(skill.get("queued_for_resolution", false)),
		"reactive_counter": reactive_counter,
		"group_card_limit": _card_group_limit_for_player(player_index),
		"play_cash_cost_cents": play_cash_cost * 100,
		"financial_margin_cents": int(eligibility.get("financial_margin_cash", 0)) * 100,
		"financial_terms_version": str(eligibility.get("financial_terms_version", "")),
		"available_cash_cents": int(player.get("cash", 0)) * 100,
		"cash_revision": "%d" % int(player.get("cash", 0)),
		"asset_cost": (eligibility.get("asset_cost", queued_skill.get("asset_cost", {})) as Dictionary).duplicate(true) if eligibility.get("asset_cost", queued_skill.get("asset_cost", {})) is Dictionary else {},
		"skill": queued_skill,
		"entry_context": entry_context,
	}, {
		"player_count": players.size(),
		"counter_window_active": card_resolution_counter_window_active,
		"batch_locked": card_resolution_batch_locked,
		"simultaneous_timer": card_resolution_simultaneous_timer,
		"lock_duration": _card_group_lock_duration(),
		"public_bid_duration": _card_group_public_bid_duration(),
		"window_sequence": card_group_window_sequence,
		"reference_player": card_resolution_batch_reference_player,
	})
	var queue_plan: Dictionary = queue_plan_variant if queue_plan_variant is Dictionary else {}
	if not bool(queue_plan.get("accepted", false)):
		var rejection := str(queue_plan.get("reason", "queue_service_missing"))
		match rejection:
			"group_full": _log("%s未提交：本窗口卡牌组已达到%d张上限。" % [card_label, int(queue_plan.get("card_limit", _card_group_limit_for_player(player_index)))])
			"public_bid_phase": _log("%s未提交：共享卡牌窗正在公开竞价，不能再加入普通牌；卡牌保留在手牌。" % card_label)
			"lock_phase", "window_closed": _log("%s未提交：共享卡牌窗已进入锁牌阶段；卡牌保留在手牌。" % card_label)
			"active_resolution": _log("%s未提交：当前卡牌组正在连续结算，下一共享窗尚未开始；卡牌保留在手牌。" % card_label)
			"counter_already_submitted": _log("当前玩家已经提交一张响应牌；同一5秒响应窗不能重复提交。")
			"insufficient_play_cost": _log("%s无法进入共享卡牌窗：当前现金不足以支付打出费用¥%d。" % [card_label, play_cash_cost])
			"insufficient_financial_margin": _log("%s无法进入共享卡牌窗：打出费用与金融保证金合计资金不足。" % card_label)
			"asset_insufficient", "generic_asset_insufficient": _log("%s未提交：当前六色资产不足；卡牌仍保留在手中。" % card_label)
			_: _log("%s未提交：卡牌队列服务拒绝请求（%s）。" % [card_label, rejection])
		return false
	var committed_entry: Dictionary = queue_plan.get("entry", {}) if queue_plan.get("entry", {}) is Dictionary else {}
	var committed_skill: Dictionary = committed_entry.get("skill", {}) if committed_entry.get("skill", {}) is Dictionary else {}
	var inventory_request := {
		"inventory": _card_inventory_snapshot(player),
		"target_slot": slot_index,
		"queued_skill": committed_skill,
		"consumed_on_queue": bool(queue_plan.get("consumed_on_queue", false)),
	}
	var inventory_plan_variant: Variant = coordinator.call("plan_card_inventory_queue_commit", inventory_request) if coordinator.has_method("plan_card_inventory_queue_commit") else {}
	var inventory_plan: Dictionary = inventory_plan_variant if inventory_plan_variant is Dictionary else {}
	if not bool(inventory_plan.get("ready", false)):
		_log("%s未提交：卡槽状态已变化（%s）。" % [card_label, str(inventory_plan.get("reason", "inventory_service_missing"))])
		return false
	var prepared_player := player.duplicate(true)
	var inventory_commit_variant: Variant = coordinator.call("commit_card_inventory_queue_commit", prepared_player, inventory_request, inventory_plan) if coordinator.has_method("commit_card_inventory_queue_commit") else {}
	var inventory_commit: Dictionary = inventory_commit_variant if inventory_commit_variant is Dictionary else {}
	if not bool(inventory_commit.get("committed", false)):
		_log("%s未提交：卡槽提交失败（%s）。" % [card_label, str(inventory_commit.get("reason", "inventory_commit_failed"))])
		return false
	var financial_margin_cents := maxi(0, int(queue_plan.get("financial_margin_cents", 0)))
	var total_cash_authorized_cents := play_cash_cost * 100 + financial_margin_cents
	var queue_commit_variant: Variant = coordinator.call("commit_card_resolution_queue_submission", queue_plan, {
		"authorized": true,
		"inventory_committed": true,
		"play_cost_authorized": int(player.get("cash", 0)) * 100 >= total_cash_authorized_cents,
		"financial_margin_authorized": int(player.get("cash", 0)) * 100 >= total_cash_authorized_cents,
		"asset_authorized": true,
	})
	var queue_commit: Dictionary = queue_commit_variant if queue_commit_variant is Dictionary else {}
	if not bool(queue_commit.get("committed", false)):
		_log("%s未提交：队列提交失败（%s）。" % [card_label, str(queue_commit.get("reason", "queue_commit_failed"))])
		return false
	prepared_player["queued_card_tip"] = 0
	players[player_index] = prepared_player
	_pay_skill_play_cost(player_index, skill)
	var runtime_controller := _card_resolution_controller_node()
	if runtime_controller != null and runtime_controller.has_method("set_player_ready"):
		runtime_controller.call("set_player_ready", player_index, false, (_card_resolution_controller_facts().get("active_player_indices", []) as Array))
	var begins_new_batch := bool(queue_commit.get("begins_new_batch", false))
	if begins_new_batch:
		card_resolution_batch_reference_player = int(queue_commit.get("reference_player", player_index))
		last_card_resolution_player_index = -1
		card_group_window_sequence = int(queue_commit.get("next_window_sequence", card_group_window_sequence + 1))
		_begin_card_group_window(card_resolution_batch_reference_player, card_group_window_sequence)
	var queue_to_next_batch := str(queue_commit.get("route", "current")) == "next"
	if queue_to_next_batch:
		_log("匿名响应牌已承诺：%s进入当前5秒相位响应通道。" % card_label)
		if player_index == selected_player:
			_complete_scenario_signal("card_played", "提交匿名出牌：%s进入等待区。" % card_label, "after_play", "public_track")
			if _active_runtime_scenario_id() == "first_table" and _game_runtime_coordinator_node().card_family_id(String(skill.get("name", ""))) == _game_runtime_coordinator_node().card_family_id(_first_table_followup_card_name()):
				_complete_scenario_signal("followup_card_played", "第二张经营牌已进入等待区：%s。" % card_label, "after_followup_play", "public_track")
		_refresh_ui()
		return true
	var current_group_count := _card_group_count_for_player(player_index)
	if current_group_count > 1:
		_log("匿名组追加第%d张卡：%s；同组会按玩家锁定顺序连续结算。" % [current_group_count, card_label])
	else:
		_log("匿名卡牌进入%s：%s；普通玩家本窗最多%d张牌。" % [_card_group_window_cadence_text(card_group_window_sequence), card_label, _card_group_limit_for_player(player_index)])
		_show_card_batch_lobby_overlay()
	if player_index == selected_player:
		_complete_scenario_signal("card_played", "提交匿名出牌：%s进入公开牌轨。" % card_label, "after_play", "public_track")
		if _active_runtime_scenario_id() == "first_table" and _game_runtime_coordinator_node().card_family_id(String(skill.get("name", ""))) == _game_runtime_coordinator_node().card_family_id(_first_table_followup_card_name()):
			_complete_scenario_signal("followup_card_played", "第二张经营牌已进入公开牌轨：%s。" % card_label, "after_followup_play", "public_track")
	if card_resolution_simultaneous_timer <= 0.0:
		_lock_card_resolution_batch()
	return true


func _lock_card_resolution_batch() -> void:
	if _card_resolution_current_queue().is_empty() or not _card_resolution_active_entry().is_empty():
		return
	var service := _card_resolution_queue_service_node()
	var lock_variant: Variant = service.call("lock_batch", {
		"reference_player": card_resolution_batch_reference_player,
		"player_count": players.size(),
	}) if service != null and service.has_method("lock_batch") else {}
	var lock_result: Dictionary = lock_variant if lock_variant is Dictionary else {}
	if not bool(lock_result.get("locked", false)):
		return
	card_resolution_auction_open = false
	card_resolution_auction_timer = 0.0
	card_resolution_simultaneous_timer = 0.0
	card_resolution_batch_locked = true
	var group_count := int(lock_result.get("group_count", 0))
	_log("共享卡牌窗封盘：%d个匿名组、%d张牌按轮转席位与组内锁定顺序结算。" % [group_count, _card_resolution_current_queue().size()])
	_start_next_card_resolution()


func _start_next_card_resolution() -> void:
	if not _card_resolution_active_entry().is_empty():
		return
	if not card_resolution_batch_locked:
		return
	if _card_resolution_current_queue().is_empty():
		_finish_card_resolution_batch()
		return
	var skill_overrides := {}
	for entry_variant in _card_resolution_current_queue():
		if entry_variant is Dictionary:
			var queued_entry := entry_variant as Dictionary
			var queued_skill := _queued_skill_from_entry(queued_entry)
			if not queued_skill.is_empty():
				skill_overrides[str(int(queued_entry.get("resolution_id", queued_entry.get("queued_order", -1))))] = queued_skill
	var service := _card_resolution_queue_service_node()
	var start_variant: Variant = service.call("start_next", {
		"game_time": game_time,
		"skill_by_resolution_id": skill_overrides,
	}) if service != null and service.has_method("start_next") else {}
	var start_result: Dictionary = start_variant if start_variant is Dictionary else {}
	for skipped_variant in start_result.get("skipped_entries", []):
		if skipped_variant is Dictionary:
			var skipped_entry := skipped_variant as Dictionary
			_clear_queued_card_flag(skipped_entry)
			var coordinator := _game_runtime_coordinator_node()
			if coordinator != null and coordinator.has_method("settle_card_mana_reservation"):
				coordinator.call("settle_card_mana_reservation", skipped_entry, {"resolved": false, "reason": "queue_entry_invalid"})
	if not bool(start_result.get("started", false)):
		if bool(start_result.get("batch_empty", false)):
			_finish_card_resolution_batch()
		return
	var entry: Dictionary = start_result.get("active_entry", {}) if start_result.get("active_entry", {}) is Dictionary else {}
	var skill: Dictionary = entry.get("skill", {}) if entry.get("skill", {}) is Dictionary else {}
	if not entry.has("tip_payment_clue"):
		entry["tip_payment_clue"] = _card_resolution_tip_clue_text(entry)
		_store_card_resolution_entry(entry)
	card_resolution_visual_id = -1
	card_resolution_visual_stage = -1
	card_resolution_auction_open = false
	card_resolution_counter_window_active = false
	card_resolution_counter_timer = 0.0
	card_resolution_timer = _card_resolution_duration(skill)
	_show_card_resolution_overlay(_card_resolution_active_entry(), card_resolution_timer)
	if card_resolution_timer <= 0.0:
		_begin_card_counter_response_window()


func _show_card_batch_lobby_overlay() -> void:
	if card_resolution_overlay == null or _card_resolution_current_queue().is_empty() or card_resolution_batch_locked:
		return
	card_resolution_overlay.visible = true
	_set_planet_right_rail_resolution_suppressed(true)
	_refresh_card_resolution_overlay_badges({})
	if card_resolution_auction_open:
		_sort_card_resolution_queue()
	var leading: Dictionary = _card_resolution_current_queue()[0]
	if card_resolution_title_label != null:
		card_resolution_title_label.text = "共享窗·锁牌" if card_resolution_auction_open else "共享窗·组织"
	if card_resolution_status_label != null:
		card_resolution_status_label.text = _card_resolution_phase_text()
	_update_card_resolution_timer_bar(
		"auction" if card_resolution_auction_open else "simultaneous",
		max(0.0, card_resolution_auction_timer if card_resolution_auction_open else card_resolution_simultaneous_timer),
		leading
	)
	var skill: Dictionary = leading.get("skill", {}) as Dictionary
	var card_name := String(skill.get("name", "卡牌"))
	var card_label := _card_display_name(card_name)
	if card_label == "":
		card_label = "匿名卡牌"
	if card_resolution_art != null and card_resolution_art.has_method("set_card"):
		card_resolution_art.call(
			"set_card",
			card_label,
			String(skill.get("kind", "")),
			_skill_tag_text(skill),
			_card_presentation_color(skill),
			maxi(1, _game_runtime_coordinator_node().card_rank(card_name)),
			false,
			_card_presentation_text(skill, "art_stats")
		)
	if card_resolution_body_label != null:
		var window_phase := _card_group_window_phase()
		var lobby_text := "%s｜剩余%d秒｜普通上限%d张｜%s已入组" % [_card_group_phase_label(window_phase), int(ceil(_card_group_phase_remaining_seconds())), _card_group_limit_for_player(selected_player), card_label]
		if window_phase == "public_bid":
			lobby_text = "公开竞价｜剩余%d秒｜不能加牌｜可调整既有组报价" % int(ceil(_card_group_phase_remaining_seconds()))
		elif window_phase == "lock":
			lobby_text = "锁牌｜剩余%d秒｜不能加牌或改价" % int(ceil(_card_group_phase_remaining_seconds()))
		var roster_text := _card_resolution_batch_roster_text(76)
		if roster_text != "":
			lobby_text += "\n%s" % roster_text
		var lobby_requirement := _card_resolution_play_requirement_text(leading)
		if lobby_requirement != "":
			lobby_text += "\n%s" % _short_card_text(lobby_requirement.replace("打出条件：", "条件："), 54)
		card_resolution_body_label.text = lobby_text
		card_resolution_body_label.tooltip_text = _card_resolution_overlay_detail_text(leading, max(0.0, card_resolution_auction_timer if card_resolution_auction_open else card_resolution_simultaneous_timer))


func _card_resolution_batch_roster_text(max_chars: int = 120) -> String:
	if _card_resolution_current_queue().is_empty():
		return ""
	var pieces: Array[String] = []
	for i in range(_card_resolution_current_queue().size()):
		var entry_variant: Variant = _card_resolution_current_queue()[i]
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var label := _card_resolution_entry_card_label(entry)
		if label.strip_edges() == "":
			label = "牌桌卡牌"
		var bid := int(float(int(entry.get("winning_priority_bid_cents", entry.get("priority_bid_cents", 0)))) / 100.0)
		var group_position := maxi(1, int(entry.get("group_position", i + 1)))
		var group_order := maxi(1, int(entry.get("group_order", 1)))
		var group_size := maxi(1, int(entry.get("group_size", 1)))
		var text := "G%d·%d/%d %s" % [group_position, group_order, group_size, _short_card_text(label, 8)]
		if bid > 0:
			text += "¥%d" % bid
		pieces.append(text)
	if pieces.is_empty():
		return ""
	return _short_card_text("公开组轨：%s" % " / ".join(pieces), max_chars)


func _show_card_resolution_overlay(entry: Dictionary, seconds_left: float) -> void:
	if card_resolution_overlay == null:
		return
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	var card_name := String(skill.get("name", "卡牌"))
	var card_label := _card_display_name(card_name)
	if card_label == "":
		card_label = "牌桌卡牌"
	card_resolution_overlay.visible = not _card_resolution_active_entry().is_empty() and seconds_left > 0.0
	if not card_resolution_overlay.visible:
		_set_planet_right_rail_resolution_suppressed(false)
		_refresh_card_resolution_overlay_badges({})
		return
	_set_planet_right_rail_resolution_suppressed(true)
	if card_resolution_title_label != null:
		card_resolution_title_label.text = card_label
	if card_resolution_status_label != null:
		card_resolution_status_label.text = _card_resolution_phase_text(entry, seconds_left)
	_update_card_resolution_timer_bar("counter" if card_resolution_counter_window_active else "reveal", seconds_left, entry)
	_refresh_card_resolution_overlay_badges(entry)
	_sync_card_resolution_stage_visual(entry, skill, seconds_left)
	if card_resolution_art != null and card_resolution_art.has_method("set_card"):
		card_resolution_art.call(
			"set_card",
			card_label,
			String(skill.get("kind", "")),
			_skill_tag_text(skill),
			_card_presentation_color(skill),
			max(1, _game_runtime_coordinator_node().card_rank(card_name)),
			false,
			_card_presentation_text(skill, "art_stats")
		)
	if card_resolution_body_label != null:
		card_resolution_body_label.text = _card_resolution_overlay_compact_body_text(entry, seconds_left)
		card_resolution_body_label.tooltip_text = _card_resolution_overlay_detail_text(entry, seconds_left)


func _card_resolution_overlay_compact_body_text(entry: Dictionary, seconds_left: float) -> String:
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	if card_resolution_counter_window_active:
		return "响应窗口｜可相位否决\n效果：%s" % [
			_short_card_text(_skill_display_text(skill).replace("\n", " / "), 48),
		]
	var resolution_presentation := _card_resolution_presentation_snapshot(skill, entry, seconds_left)
	var animation_line := _short_card_text(String(resolution_presentation.get("animation_text", "")).replace("\n", " / "), 48)
	if animation_line == "":
		animation_line = "展示中"
	var effect_line := "效果：%s" % _short_card_text(_skill_display_text(skill).replace("\n", " / "), 48)
	if _card_can_open_counter_window(entry):
		effect_line = "%s｜可响应" % _short_card_text(effect_line, 44)
	return "%s\n%s" % [animation_line, effect_line]


func _card_resolution_overlay_detail_text(entry: Dictionary, seconds_left: float) -> String:
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	var card_name := String(skill.get("name", "卡牌"))
	var card_label := _card_display_name(card_name)
	if card_label == "":
		card_label = "牌桌卡牌"
	var lines := [
		"%s｜出牌者%s" % [card_label, "已揭晓" if bool(entry.get("public_owner_revealed", false)) else "未知"],
		_card_resolution_phase_text(entry, seconds_left),
	]
	var resolution_presentation := _card_resolution_presentation_snapshot(skill, entry, seconds_left)
	var animation_text := String(resolution_presentation.get("animation_text", ""))
	if animation_text != "":
		lines.append("演出：%s" % _short_card_text(animation_text, 120))
	lines.append("效果：%s" % _short_card_text(_skill_display_text(skill), 120))
	var contract_controller := _contract_runtime_controller_node()
	var contract_text := contract_controller.card_resolution_public_text(entry) if contract_controller != null else ""
	if contract_text != "":
		lines.append(_short_card_text(contract_text, 120))
	var requirement_text := _card_resolution_play_requirement_text(entry)
	if requirement_text != "":
		lines.append(requirement_text)
	var target_text := String(resolution_presentation.get("target_text", ""))
	if target_text != "":
		lines.append("目标：%s" % _short_card_text(target_text, 100))
	var tip_text := _card_resolution_tip_clue_text(entry)
	if tip_text != "":
		lines.append("竞价：%s" % _short_card_text(tip_text, 110))
	if _card_can_open_counter_window(entry):
		lines.append("提示：展示后进入玩家互动响应窗口。")
	lines.append("更完整的卡面和等级效果可双击顶部牌轨打开图鉴。")
	return "\n".join(lines)


func _card_resolution_timer_total_for_stage(stage: String, entry: Dictionary = {}) -> float:
	match stage:
		"auction":
			return _card_group_lock_duration()
		"simultaneous":
			return _card_simultaneous_window_duration()
		"counter":
			return _card_counter_response_duration()
		"reveal":
			var skill: Dictionary = entry.get("skill", {}) as Dictionary
			return _card_resolution_duration(skill)
	return CARD_RESOLUTION_DISPLAY_SECONDS


func _update_card_resolution_timer_bar(stage: String, seconds_left: float, entry: Dictionary = {}) -> void:
	if card_resolution_timer_bar == null and card_resolution_timer_label == null:
		return
	var total := maxf(0.001, _card_resolution_timer_total_for_stage(stage, entry))
	var remaining := clampf(seconds_left, 0.0, total)
	var ratio := clampf(remaining / total, 0.0, 1.0)
	var label := "展示"
	var accent := Color("#fde68a")
	match stage:
		"auction":
			label = "锁牌"
			accent = Color("#f59e0b")
		"simultaneous":
			label = "组织"
			accent = Color("#93c5fd")
		"counter":
			label = "响应"
			accent = Color("#c084fc")
		"reveal":
			label = "展示"
			accent = Color("#fde68a")
	if bottom_countdown_overlay != null and bottom_countdown_overlay.has_method("set_state") and bottom_countdown_overlay.visible:
		bottom_countdown_overlay.call("set_state", {
			"visible": true,
			"label": label,
			"remaining": remaining,
			"total": total,
			"accent": accent,
			"label_tooltip": "Current timed table stage: %s." % label,
			"bar_tooltip": "Shorter bar means the %s stage is closer to ending." % label,
		})
		return
	if card_resolution_timer_label != null:
		card_resolution_timer_label.text = label
		card_resolution_timer_label.add_theme_color_override("font_color", accent.lightened(0.12))
		card_resolution_timer_label.tooltip_text = "阶段：%s；条越短，窗口越接近结束。" % label
	if card_resolution_timer_bar != null:
		card_resolution_timer_bar.value = ratio * 100.0
		card_resolution_timer_bar.tooltip_text = "阶段：%s；条越短，窗口越接近结束。" % label
		card_resolution_timer_bar.add_theme_stylebox_override("fill", _menu_card_style(accent, Color("#020617").lerp(accent, 0.72), 0, 5))


func _hide_card_resolution_overlay() -> void:
	if card_resolution_overlay != null:
		card_resolution_overlay.visible = false
	_set_planet_right_rail_resolution_suppressed(false)
	_refresh_card_resolution_overlay_badges({})
	card_resolution_visual_id = -1
	card_resolution_visual_stage = -1


func _set_planet_right_rail_resolution_suppressed(enabled: bool) -> void:
	var rail := get_tree().get_root().find_child("PlanetRightSpaceRail", true, false) as Control
	if rail == null:
		return
	if _runtime_campaign_focus_mode():
		rail.visible = false
		rail.set_meta("planet_side_lane_suppressed_for_resolution", true)
		return
	rail.visible = not enabled
	rail.set_meta("planet_side_lane_suppressed_for_resolution", enabled)


func _counter_entry_can_cancel(counter_entry: Dictionary, target_entry: Dictionary) -> bool:
	if counter_entry.is_empty() or target_entry.is_empty():
		return false
	var counter_skill: Dictionary = counter_entry.get("skill", {}) as Dictionary
	var target_skill: Dictionary = target_entry.get("skill", {}) as Dictionary
	if counter_skill.is_empty() or target_skill.is_empty():
		return false
	var counter_target_status := _card_play_target_snapshot(counter_skill)
	var target_status := _card_play_target_snapshot(target_skill)
	if not bool(counter_target_status.get("is_counter", false)):
		return false
	if bool(target_status.get("is_counter", false)):
		return false
	if not bool(target_status.get("counterable_player_interaction", false)):
		return false
	if bool(target_entry.get("countered", false)):
		return false
	var counter_player := int(counter_entry.get("player_index", -1))
	if counter_player < 0 or counter_player >= players.size():
		return false
	return bool(_card_play_eligibility_snapshot(counter_player, counter_skill, "rule").get("allowed", false))


func _pop_counter_entry_from_queue(target_entry: Dictionary) -> Dictionary:
	var service := _card_resolution_queue_service_node()
	if service == null or not service.has_method("remove_entry_by_id"):
		return {}
	for entries in [_card_resolution_next_queue(), _card_resolution_current_queue()]:
		for entry_variant in entries:
			if not (entry_variant is Dictionary):
				continue
			var counter_entry := entry_variant as Dictionary
			if _counter_entry_can_cancel(counter_entry, target_entry):
				var resolution_id := int(counter_entry.get("resolution_id", counter_entry.get("queued_order", -1)))
				var removed_variant: Variant = service.call("remove_entry_by_id", resolution_id)
				return (removed_variant as Dictionary).duplicate(true) if removed_variant is Dictionary else {}
	return {}


func _resolve_reactive_counter_for_entry(target_entry: Dictionary) -> Dictionary:
	var counter_entry := _pop_counter_entry_from_queue(target_entry)
	if counter_entry.is_empty():
		return {}
	var counter_player := int(counter_entry.get("player_index", -1))
	var counter_skill: Dictionary = counter_entry.get("skill", {}) as Dictionary
	var target_skill: Dictionary = target_entry.get("skill", {}) as Dictionary
	var counter_label := _card_display_name(String(counter_skill.get("name", "相位否决")))
	var target_label := _card_display_name(String(target_skill.get("name", "匿名牌")))
	if counter_label == "":
		counter_label = "相位否决"
	if target_label == "":
		target_label = "匿名牌"
	if not bool(counter_entry.get("play_cost_paid_on_queue", false)):
		_pay_skill_play_cost(counter_player, counter_skill)
	players[counter_player]["action_cooldown"] = max(float(players[counter_player].get("action_cooldown", 0.0)), COMMAND_COOLDOWN)
	var refund := maxi(0, int(counter_skill.get("counter_refund", 0)))
	if refund > 0:
		players[counter_player]["cash"] = int(players[counter_player].get("cash", 0)) + refund
		_record_player_card_income(counter_player, refund, String(counter_skill.get("name", "相位否决")), "反制押金回收")
	var source_card := String(counter_skill.get("source_card_name", ""))
	var source_text := "；由%s改写" % _card_display_name(source_card) if source_card != "" else ""
	_log("匿名反制生效：%s取消了%s的结算%s。反制者仍不公开。" % [counter_label, target_label, source_text])
	_add_action_callout(
		"匿名反制",
		counter_label,
		"%s被相位折叠，原牌不产生效果；反制者不公开。" % target_label,
		Color("#a78bfa"),
		_district_center(int(target_entry.get("selected_district", selected_district)))
	)
	counter_entry["resolved_time"] = game_time
	counter_entry["countered_resolution_id"] = int(target_entry.get("resolution_id", -1))
	counter_entry["aftermath_clue"] = "反制成功：%s被取消%s。" % [target_label, source_text]
	resolved_card_history.append(counter_entry)
	while resolved_card_history.size() > CARD_RESOLUTION_HISTORY_LIMIT:
		resolved_card_history.pop_front()
	var coordinator := _game_runtime_coordinator_node()
	if coordinator != null and coordinator.has_method("settle_card_mana_reservation"):
		coordinator.call("settle_card_mana_reservation", counter_entry, {"resolved": true, "reason": "counter_resolved"})
	return counter_entry


func _card_resolution_execution_request(entry: Dictionary) -> Dictionary:
	var skill := _queued_skill_from_entry(entry)
	var target_status := _card_play_target_snapshot(skill) if not skill.is_empty() else {}
	var target_kind := String(target_status.get("target_kind", "none"))
	var contract_controller := _contract_runtime_controller_node()
	var contract_selection := contract_controller.selection_snapshot() if contract_controller != null else {"source_district": -1, "target_district": -1}
	return {
		"active_entry": entry.duplicate(true),
		"skill": skill.duplicate(true),
		"target_kind": target_kind,
		"forced_decision_count_before": monster_runtime_controller.active_monster_wagers.size(),
		"selection_context": {
			"selected_player": selected_player,
			"selected_district": selected_district,
			"selected_trade_product": selected_trade_product,
			"contract_source_district": int(contract_selection.get("source_district", -1)),
			"contract_target_district": int(contract_selection.get("target_district", -1)),
		},
	}


func _apply_card_resolution_execution_intent(transaction: Dictionary) -> Dictionary:
	var bridge := _card_resolution_execution_world_bridge_node()
	var receipt_variant: Variant = bridge.call("apply_intent", self, transaction) if bridge != null and bridge.has_method("apply_intent") else {}
	return (receipt_variant as Dictionary).duplicate(true) if receipt_variant is Dictionary else {"intent_type": "", "reason": "world_bridge_missing"}


func _card_resolution_commitment_receipt(transaction: Dictionary) -> Dictionary:
	var entry: Dictionary = transaction.get("active_entry", {}) as Dictionary
	var skill: Dictionary = transaction.get("skill", {}) as Dictionary
	var player_index := int(entry.get("player_index", -1))
	if player_index < 0 or player_index >= players.size() or skill.is_empty():
		return {"intent_type": "finish_card_commitment", "committed": false, "reason": "commitment_context_missing"}
	var finish_slot_index := -1 if bool(entry.get("consumed_on_queue", false)) else int(entry.get("slot_index", -1))
	_finish_played_skill(player_index, finish_slot_index, skill, COMMAND_COOLDOWN)
	return {"intent_type": "finish_card_commitment", "committed": true}


func _card_resolution_history_receipt(transaction: Dictionary) -> Dictionary:
	var entry: Dictionary = (transaction.get("active_entry", {}) as Dictionary).duplicate(true)
	entry["resolved_time"] = game_time
	resolved_card_history.append(entry)
	while resolved_card_history.size() > CARD_RESOLUTION_HISTORY_LIMIT:
		resolved_card_history.pop_front()
	return {
		"intent_type": "append_history",
		"appended": true,
		"current_queue_count": _card_resolution_current_queue().size(),
	}


func _complete_active_card_resolution() -> void:
	var entry := _card_resolution_active_entry()
	if entry.is_empty():
		return
	var coordinator := _game_runtime_coordinator_node()
	if coordinator == null or not coordinator.has_method("plan_card_resolution_execution"):
		_mark_game_runtime_coordinator_missing(true)
		return
	var transaction_variant: Variant = coordinator.call("plan_card_resolution_execution", _card_resolution_execution_request(entry))
	var transaction: Dictionary = (transaction_variant as Dictionary).duplicate(true) if transaction_variant is Dictionary else {}
	if not bool(transaction.get("ready", false)):
		push_error("CardResolutionExecutionRuntimeService rejected active resolution %d: %s" % [
			int(entry.get("resolution_id", entry.get("queued_order", -1))),
			str(transaction.get("reason", "unknown")),
		])
		return
	var guard := 0
	while not (transaction.get("next_intent", {}) as Dictionary).is_empty() and guard < 20:
		guard += 1
		var receipt := _apply_card_resolution_execution_intent(transaction)
		var advanced_variant: Variant = coordinator.call("advance_card_resolution_execution", transaction, receipt)
		transaction = (advanced_variant as Dictionary).duplicate(true) if advanced_variant is Dictionary else {}
		if str(transaction.get("status", "")) != "ready":
			break
	if guard >= 20 or str(transaction.get("status", "")) != "ready":
		push_error("Card resolution execution aborted: %s" % str(transaction.get("failure_reason", transaction.get("reason", "intent_guard"))))
		_refresh_ui()
		return
	var finalized_variant: Variant = coordinator.call("finalize_card_resolution_execution", transaction)
	var finalized: Dictionary = finalized_variant if finalized_variant is Dictionary else {}
	if not bool(finalized.get("completed", false)):
		push_error("Card resolution execution did not finalize: %s" % str(finalized.get("reason", "unknown")))
	elif coordinator.has_method("settle_card_mana_reservation"):
		coordinator.call("settle_card_mana_reservation", transaction.get("active_entry", {}) as Dictionary, finalized)
	_refresh_ui()


func _finish_card_resolution_batch() -> void:
	var previous_player := last_card_resolution_player_index
	_reset_card_resolution_batch_state()
	if not _card_resolution_next_queue().is_empty():
		_promote_next_card_resolution_batch(previous_player)


func _reset_card_resolution_batch_state() -> void:
	card_resolution_auction_open = false
	card_resolution_batch_locked = false
	card_resolution_simultaneous_timer = 0.0
	card_resolution_auction_timer = 0.0
	card_resolution_batch_reference_player = -1
	last_card_resolution_player_index = -1
	var runtime_controller := _card_resolution_controller_node()
	if runtime_controller != null and runtime_controller.has_method("clear_ready_players"):
		runtime_controller.call("clear_ready_players")
	_hide_card_resolution_overlay()


func _promote_next_card_resolution_batch(previous_player: int) -> void:
	if _card_resolution_next_queue().is_empty() or not _card_resolution_active_entry().is_empty() or not _card_resolution_current_queue().is_empty():
		return
	var service := _card_resolution_queue_service_node()
	var promotion_variant: Variant = service.call("promote_next_batch", {
		"window_sequence": card_group_window_sequence,
		"game_time": game_time,
		"previous_player": previous_player,
		"player_count": players.size(),
	}) if service != null and service.has_method("promote_next_batch") else {}
	var promotion: Dictionary = promotion_variant if promotion_variant is Dictionary else {}
	if not bool(promotion.get("promoted", false)):
		return
	card_group_window_sequence = int(promotion.get("window_sequence", card_group_window_sequence + 1))
	card_resolution_batch_reference_player = int(promotion.get("reference_player", -1))
	last_card_resolution_player_index = int(promotion.get("previous_player", -1))
	card_resolution_batch_locked = false
	_begin_card_group_window(card_resolution_batch_reference_player, card_group_window_sequence)
	_log("上一批已经清空：等待牌进入新的%s。" % _card_group_window_cadence_text(card_group_window_sequence))
	_show_card_batch_lobby_overlay()
	if card_resolution_simultaneous_timer <= 0.0:
		_lock_card_resolution_batch()


func _clear_queued_card_flag(entry: Dictionary) -> void:
	var player_index := int(entry.get("player_index", -1))
	var slot_index := int(entry.get("slot_index", -1))
	if player_index < 0 or player_index >= players.size():
		return
	var player: Dictionary = players[player_index]
	var slots: Array = player.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return
	var skill: Dictionary = slots[slot_index]
	skill.erase("queued_for_resolution")
	slots[slot_index] = skill
	player["slots"] = slots
	players[player_index] = player


func _apply_card_resolution_effect_request(transaction: Dictionary) -> Dictionary:
	var entry: Dictionary = transaction.get("active_entry", {}) as Dictionary
	var skill: Dictionary = transaction.get("skill", {}) as Dictionary
	var player_index := int(entry.get("player_index", -1))
	var card_label := _card_display_name(String(skill.get("name", "")))
	if card_label == "":
		card_label = String(skill.get("name", "卡牌"))
	if player_index < 0 or player_index >= players.size() or skill.is_empty():
		return {"intent_type": "dispatch_effect", "dispatched": false, "resolved": false, "reason": "effect_context_missing", "continuation_kind": "normal"}
	var player: Dictionary = players[player_index]
	var resolved := true
	var handler_id := String(transaction.get("handler_id", String(skill.get("kind", ""))))
	var continuation_kind := "normal"
	if handler_id == "target_monster":
		resolved = _resolve_targeted_skill(skill, player, int(entry.get("target_slot", -1)), player_index)
	elif handler_id == "target_player":
		var target_player := int(entry.get("target_player", -1))
		match String(skill.get("kind", "")):
			"player_hand_disrupt":
				resolved = _apply_player_hand_disrupt(player_index, target_player, skill)
			"player_hand_steal":
				resolved = _apply_player_hand_steal(player_index, target_player, skill)
			_:
				resolved = false
				_log("%s的目标玩家互动结算器尚未接入。" % card_label)
	else:
		var coordinator := _game_runtime_coordinator_node()
		var family_plan_variant: Variant = coordinator.call("plan_card_economy_product_route_effect", {
			"handler_id": handler_id,
			"active_entry": entry.duplicate(true),
			"skill": skill.duplicate(true),
		}) if coordinator != null and coordinator.has_method("plan_card_economy_product_route_effect") else {}
		var family_plan: Dictionary = family_plan_variant if family_plan_variant is Dictionary else {}
		if bool(family_plan.get("supported", false)):
			var bridge := _card_economy_product_route_effect_world_bridge_node()
			var receipt_variant: Variant = bridge.call("apply_effect", self, family_plan) if bridge != null and bridge.has_method("apply_effect") else {"handler_id": handler_id, "dispatched": false, "resolved": false, "reason": "effect_family_world_bridge_missing"}
			var receipt: Dictionary = receipt_variant if receipt_variant is Dictionary else {}
			var family_result_variant: Variant = coordinator.call("finalize_card_economy_product_route_effect", family_plan, receipt) if coordinator != null and coordinator.has_method("finalize_card_economy_product_route_effect") else {}
			var family_result: Dictionary = family_result_variant if family_result_variant is Dictionary else {}
			resolved = bool(family_result.get("resolved", false))
			continuation_kind = str(family_result.get("continuation_kind", "normal"))
		else:
			match handler_id:
				"monster_card":
					resolved = monster_runtime_controller._summon_monster_from_card(player, skill)
				"public_facility":
					var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
					var facility_result_variant: Variant = coordinator.call("submit_public_facility_card", {
						"transaction_id": "card-resolution-%d-public-facility" % resolution_id if resolution_id >= 0 else "",
						"player_index": player_index,
						"target_region_index": int(skill.get("target_region_index", selected_district)),
						"occurred_at": game_time,
						"skill": skill,
					}) if coordinator != null and coordinator.has_method("submit_public_facility_card") else {}
					var facility_result: Dictionary = facility_result_variant if facility_result_variant is Dictionary else {}
					resolved = bool(facility_result.get("committed", false))
					if not resolved:
						_log("公共设施牌结算失败：%s。" % str(facility_result.get("reason", "region_infrastructure_unavailable")))
				"monster_bound_action":
					resolved = monster_runtime_controller._trigger_bound_monster_skill(skill, player)
				"military_force":
					resolved = military_runtime_controller.summon_from_card(player_index, skill)
				"military_command":
					resolved = military_runtime_controller.trigger_command(skill, -1, player_index)
				"card_counter":
					resolved = false
					_log("%s没有处在有效相位响应窗口内，未产生反制效果。" % card_label)
				"weather_control":
					resolved = weather_runtime_controller.apply_weather_control_at(skill, selected_district)
				"intel_city_reveal":
					resolved = _apply_intel_city_reveal(player, skill)
				"intel_card_trace":
					resolved = _apply_intel_card_trace(player, skill)
				"intel_contract_trace":
					var contract_controller := _contract_runtime_controller_node()
					resolved = contract_controller.apply_intel_contract_trace(selected_player, selected_card_resolution_id, skill) if contract_controller != null else false
				"supply_draw":
					_draw_extra_district_cards(player, int(skill.get("draw_amount", 1)), skill["name"])
				_:
					resolved = false
					_log("%s暂未接入结算器，本次公开提交按承诺成本结算但不产生效果。" % card_label)
	if resolved and handler_id == "area_trade_contract":
		continuation_kind = "contract_response"
	elif monster_runtime_controller.active_monster_wagers.size() > int(transaction.get("forced_decision_count_before", monster_runtime_controller.active_monster_wagers.size())):
		continuation_kind = "forced_decision_handoff"
	return {
		"intent_type": "dispatch_effect",
		"dispatched": true,
		"resolved": resolved,
		"reason": "resolved" if resolved else "effect_not_resolved",
		"continuation_kind": continuation_kind,
	}


func _use_skill(slot_index: int) -> void:
	if _has_pending_target_choice():
		_log("请先完成当前卡牌的目标怪兽选择。")
		return
	if _has_pending_player_target_choice():
		_log("请先完成当前卡牌的目标玩家选择。")
		return
	if not _can_selected_player_act():
		return
	if selected_player < 0 or selected_player >= players.size():
		return
	var player: Dictionary = players[selected_player]
	var slots: Array = player.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return
	var skill: Dictionary = slots[slot_index]
	if _is_v06_runtime_card(skill):
		_queue_skill_resolution(selected_player, slot_index, -1)
		_refresh_ui()
		return
	var card_label := _card_display_name(String(skill.get("name", "")))
	if card_label == "":
		card_label = String(skill.get("name", "卡牌"))
	var eligibility := _card_play_eligibility_snapshot(selected_player, skill, "hand")
	if String(eligibility.get("reason_code", "")) == "counter_conversion_ready":
		_queue_monster_card_as_counter(selected_player, slot_index, skill)
		_refresh_ui()
		return
	if not bool(eligibility.get("allowed", false)):
		_log_card_play_rejection(eligibility, skill)
		return
	if bool(eligibility.get("requires_target_monster", false)):
		_begin_target_monster_choice(slot_index)
		return
	if bool(eligibility.get("requires_target_player", false)):
		_begin_target_player_choice(slot_index)
		return
	_queue_skill_resolution(selected_player, slot_index, -1)
	_refresh_ui()




func _draw_extra_district_cards(player: Dictionary, amount: int, source: String) -> void:
	if selected_district < 0 or selected_district >= districts.size() or districts[selected_district]["destroyed"]:
		_log("%s没有可补给的当前区域。" % source)
		return
	var choices: Array = districts[selected_district].get("card_choices", [])
	if choices.is_empty():
		_log("%s没有找到区域候选卡。" % source)
		return
	var pool := choices.duplicate()
	var gained := 0
	while gained < max(1, amount) and not pool.is_empty():
		var picked_index := rng.randi_range(0, pool.size() - 1)
		var skill_name := String(pool[picked_index])
		pool.remove_at(picked_index)
		if _acquire_card_for_player(player, skill_name, selected_district, source, true):
			gained += 1
	_log("%s执行额外区域补给；具体获得、手牌数量和弃牌状态不公开。" % source)




func _active_city_district_indices() -> Array:
	var value: Variant = _route_network_runtime_call("active_region_legacy_indices")
	return (value as Array).duplicate(true) if value is Array else []


func _player_active_city_count(player_index: int) -> int:
	var count := 0
	for index in _active_city_district_indices():
		if int(_district_city(index).get("owner", -1)) == player_index:
			count += 1
	return count


func _city_competition_matches(_district_index: int) -> int:
	return 0


func _city_gdp_per_minute(district_index: int, competition_matches: int) -> int:
	return int(_city_gdp_per_minute_breakdown(district_index, competition_matches).get("net", 0))


func _city_cycle_income(district_index: int, competition_matches: int) -> int:
	# Save/test compatibility wrapper. This value is not a payout cycle; it is current GDP/min.
	return _city_gdp_per_minute(district_index, competition_matches)


func _city_gdp_per_minute_breakdown(district_index: int, competition_matches: int) -> Dictionary:
	if district_index < 0 or district_index >= districts.size():
		return {"net": 0, "receipt_count": 0, "product_lines": [], "route_lines": [], "transit_lines": []}
	var region_id := str((districts[district_index] as Dictionary).get("region_id", "region.%03d" % district_index))
	var snapshot_variant: Variant = _commodity_flow_runtime_call("region_gdp_snapshot", [region_id])
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var receipts_variant: Variant = _commodity_flow_runtime_call("recent_sale_receipts_snapshot", [-1])
	var product_lines: Array = []
	var route_lines: Array = []
	if receipts_variant is Array:
		for receipt_variant in receipts_variant:
			if not (receipt_variant is Dictionary) or str((receipt_variant as Dictionary).get("market_region_id", "")) != region_id:
				continue
			var receipt: Dictionary = receipt_variant
			product_lines.append("%s ×%d" % [str(receipt.get("commodity_id", "")), int(receipt.get("units", 0))])
			route_lines.append("距离%d｜单价%.2f" % [int(receipt.get("shortest_legal_distance", 0)), float(int(receipt.get("unit_price_cents", 0))) / 100.0])
	return {
		"net": int(snapshot.get("region_gdp_per_minute", 0)),
		"net_cents": int(snapshot.get("region_gdp_per_minute_cents", 0)),
		"receipt_count": (snapshot.get("receipt_ids", []) as Array).size() if snapshot.get("receipt_ids", []) is Array else 0,
		"observation_window_seconds": float(snapshot.get("observation_window_seconds", 0.0)),
		"competition_matches": competition_matches,
		"product_lines": product_lines,
		"route_lines": route_lines,
		"transit_lines": route_lines.duplicate(),
	}


func _city_cycle_income_breakdown(district_index: int, competition_matches: int) -> Dictionary:
	# Save/test compatibility wrapper. The authoritative economy breakdown is per-minute GDP.
	return _city_gdp_per_minute_breakdown(district_index, competition_matches)


func _city_income_breakdown_summary(breakdown: Dictionary) -> String:
	return "成交GDP %.2f/min｜最近%d秒 %d笔唯一回执" % [float(int(breakdown.get("net_cents", 0))) / 100.0, int(breakdown.get("observation_window_seconds", 0)), int(breakdown.get("receipt_count", 0))]


func _city_gdp_change_reason_text(breakdown: Dictionary) -> String:
	return "只统计观察窗口内已成交商品；生产、需求和回压本身不直接产生GDP。" if int(breakdown.get("receipt_count", 0)) > 0 else "尚无完成销售的商品回执。"


func _city_gdp_history_path_text(city: Dictionary, limit: int = 5) -> String:
	var history: Array = city.get("gdp_history", [])
	if history.is_empty():
		var fallback := int(city.get("last_gdp", city.get("last_income", 0)))
		return str(fallback) if fallback > 0 else "暂无"
	var start := maxi(0, history.size() - limit)
	var pieces := []
	for i in range(start, history.size()):
		pieces.append(str(int(history[i])))
	return "→".join(pieces)


func _city_gdp_trend_text(city: Dictionary) -> String:
	var history: Array = city.get("gdp_history", [])
	if history.is_empty():
		var fallback := int(city.get("last_gdp", city.get("last_income", 0)))
		if fallback > 0:
			return "GDP趋势：当前快照%d｜上次快照暂无｜路径%s。" % [fallback, _city_gdp_history_path_text(city)]
		return "GDP趋势：暂无历史（下次全局市场刷新开始记录）。"
	var current := int(history[history.size() - 1])
	var delta := int(city.get("last_gdp_delta", 0))
	var source := String(city.get("last_gdp_source", "全局刷新"))
	if source == "":
		source = "全局刷新"
	var reason := String(city.get("last_gdp_reason", ""))
	if reason == "":
		reason = "等待收入拆解"
	var change_text := "持平" if delta == 0 else _signed_int_text(delta)
	return "GDP趋势：%s当前快照%d（较上次%s）｜路径%s｜%s。" % [
		source,
		current,
		change_text,
		_city_gdp_history_path_text(city),
		reason,
	]


func _sync_commodity_gdp_city_presentation(district_index: int, breakdown: Dictionary) -> void:
	if district_index < 0 or district_index >= districts.size():
		return
	var city := _district_city(district_index)
	var income := int(breakdown.get("net", 0))
	var history: Array = city.get("gdp_history", [])
	var previous := income
	if not history.is_empty():
		previous = int(history[history.size() - 1])
	elif int(city.get("last_gdp", 0)) > 0:
		previous = int(city.get("last_gdp", income))
	var delta := income - previous
	history.append(income)
	while history.size() > CITY_GDP_HISTORY_LIMIT:
		history.remove_at(0)
	city["last_income"] = income
	city["last_gdp"] = income
	city["last_gdp_delta"] = delta
	city["last_gdp_source"] = "商品成交回执"
	city["last_gdp_reason"] = _city_gdp_change_reason_text(breakdown)
	city["last_gdp_breakdown"] = breakdown.duplicate(true)
	city["gdp_history"] = history
	districts[district_index]["city"] = city


func _city_income_detail_lines(city_index: int, competition_matches: int) -> Array:
	var breakdown := _city_cycle_income_breakdown(city_index, competition_matches)
	var city := _district_city(city_index)
	var lines := []
	lines.append("收入拆解：%s。" % _city_income_breakdown_summary(breakdown))
	lines.append(_city_gdp_trend_text(city))
	lines.append("合约状态：%s。" % _city_contract_status_text(_district_city(city_index)))
	lines.append("生产明细：%s。" % _limited_name_list(breakdown.get("product_lines", []) as Array, 5))
	lines.append("消费明细：%s。" % _limited_name_list(breakdown.get("route_lines", []) as Array, 5))
	lines.append("过境明细：%s。" % _limited_name_list(breakdown.get("transit_lines", []) as Array, 5))
	return lines


func _refresh_route_network() -> void:
	_route_network_runtime_call("refresh_routes")


func _route_network_routes_for_product(product_name: String) -> Array:
	var value: Variant = _route_network_runtime_call("routes_for_product", [product_name])
	return (value as Array).duplicate(true) if value is Array else []


func _trade_route_markers_for_selected_product() -> Array:
	var result := []
	var district_index_by_region_id: Dictionary = {}
	for district_index in range(districts.size()):
		var district: Dictionary = districts[district_index]
		district_index_by_region_id[str(district.get("region_id", "region.%03d" % district_index))] = district_index
	for route_variant in _route_network_routes_for_product(selected_trade_product):
		var route: Dictionary = route_variant
		var ordered_region_ids: Array = route.get("ordered_region_ids", []) if route.get("ordered_region_ids", []) is Array else []
		if ordered_region_ids.is_empty():
			ordered_region_ids = [str(route.get("source_region_id", "")), str(route.get("market_region_id", ""))]
		var route_points: Array = []
		var legacy_indices: Array = []
		for region_id_variant in ordered_region_ids:
			var region_id := str(region_id_variant)
			if not district_index_by_region_id.has(region_id):
				continue
			var district_index := int(district_index_by_region_id[region_id])
			legacy_indices.append(district_index)
			route_points.append(_district_center(district_index))
		if legacy_indices.is_empty():
			continue
		result.append({
			"product": selected_trade_product,
			"from": int(legacy_indices.front()),
			"to": int(legacy_indices.back()),
			"points": route_points,
			"disrupted": int(route.get("bottleneck_units_per_minute", 0)) <= 0,
			"source_type": "multimodal_route_network",
			"mode_tags": (route.get("mode_tags", []) as Array).duplicate(),
			"flow_multiplier": 1.0,
		})
	return result


func _advance_continuous_commodity_flow(delta_seconds: float) -> bool:
	if _runtime_session_finished() or delta_seconds <= 0.0:
		return true
	var runtime_coordinator := _game_runtime_coordinator_node()
	if runtime_coordinator == null or not runtime_coordinator.has_method("advance_commodity_flow"):
		return false
	var result_variant: Variant = runtime_coordinator.call("advance_commodity_flow", delta_seconds, {
		"game_over": _runtime_session_finished(),
		"time_paused": time_scale <= 0.0,
		"game_time": game_time,
		"player_count": players.size(),
	})
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	var checkpoint: Dictionary = result.get("bankruptcy_checkpoint", {}) if result.get("bankruptcy_checkpoint", {}) is Dictionary else {}
	return bool(result.get("advanced", false)) and bool(checkpoint.get("finalized", false))


func _on_commodity_flow_receipt_batch(batch: Dictionary) -> void:
	var affected_region_ids: Dictionary = {}
	for receipt_variant in batch.get("receipts", []):
		if receipt_variant is Dictionary:
			affected_region_ids[str((receipt_variant as Dictionary).get("market_region_id", ""))] = true
	for district_index in range(districts.size()):
		var region_id := str((districts[district_index] as Dictionary).get("region_id", "region.%03d" % district_index))
		if not affected_region_ids.has(region_id):
			continue
		var breakdown := _city_gdp_per_minute_breakdown(district_index, 0)
		_sync_commodity_gdp_city_presentation(district_index, breakdown)
		_city_gdp_derivative_runtime_call("settle_district", [district_index, int(breakdown.get("net", 0)), "商品成交回执", false])
		_pulse_district(district_index, Color("#2dd4bf"))
	for player_index in range(players.size()):
		_record_player_cash_snapshot(player_index)


func _update_realtime_cooldowns(delta: float) -> void:
	for p in players:
		p["action_cooldown"] = max(0.0, p["action_cooldown"] - delta)
		for skill in p["slots"]:
			if skill == null:
				continue
			skill["cooldown_left"] = max(0.0, float(skill.get("cooldown_left", 0.0)) - delta)
			skill["lock_left"] = max(0.0, float(skill.get("lock_left", 0.0)) - delta)


func _update_visual_cues(delta: float) -> void:
	for i in range(movement_trails.size() - 1, -1, -1):
		var trail: Dictionary = movement_trails[i]
		trail["life"] = float(trail.get("life", 0.0)) - delta
		if float(trail["life"]) <= 0.0:
			movement_trails.remove_at(i)
	for i in range(action_callouts.size() - 1, -1, -1):
		var callout: Dictionary = action_callouts[i]
		callout["life"] = float(callout.get("life", 0.0)) - delta
		if float(callout["life"]) <= 0.0:
			action_callouts.remove_at(i)
	for i in range(map_event_effects.size() - 1, -1, -1):
		var effect: Dictionary = map_event_effects[i]
		effect["life"] = float(effect.get("life", 0.0)) - delta
		if float(effect["life"]) <= 0.0:
			map_event_effects.remove_at(i)
	for district in districts:
		district["pulse"] = max(0.0, float(district.get("pulse", 0.0)) - delta)


func _add_action_callout(actor: String, action: String, detail: String, color: Color, world_position: Vector2, duration: float = ACTION_CALLOUT_DURATION) -> void:
	var resolved_duration: float = max(0.1, duration)
	action_callouts.append({
		"actor": actor,
		"action": action,
		"detail": detail,
		"color": color,
		"world_position": world_position,
		"life": resolved_duration,
		"duration": resolved_duration,
	})
	while action_callouts.size() > MAX_ACTION_CALLOUTS:
		action_callouts.pop_front()
	var sfx_key := _sfx_key_for_action_callout(actor, action, detail)
	if sfx_key != "":
		_play_table_sfx(sfx_key)


func _add_visual_trail(from_position: Vector2, to_position: Vector2, color: Color, label: String, duration: float = VISUAL_TRAIL_DURATION, style: String = "movement") -> void:
	if _wrapped_distance(from_position, to_position) <= 0.5:
		return
	var resolved_duration: float = max(0.1, duration)
	movement_trails.append({
		"from": from_position,
		"to": to_position,
		"color": color,
		"label": label,
		"life": resolved_duration,
		"duration": resolved_duration,
		"style": style,
	})
	while movement_trails.size() > MAX_VISUAL_TRAILS:
		movement_trails.pop_front()


func _add_map_event_effect(kind: String, world_position: Vector2, color: Color, label: String = "", duration: float = MAP_EVENT_EFFECT_DURATION, radius_m: float = 70.0, card_style: String = "") -> void:
	_push_map_event_effect({
		"kind": kind,
		"position": _wrap_world_position(world_position),
		"from": _wrap_world_position(world_position),
		"to": _wrap_world_position(world_position),
		"color": color,
		"label": _short_event_label(label),
		"life": max(0.1, duration),
		"duration": max(0.1, duration),
		"radius_m": max(1.0, radius_m),
		"card_style": card_style,
	})


func _add_map_event_attack_effect(kind: String, from_position: Vector2, to_position: Vector2, color: Color, label: String = "", duration: float = 0.95, radius_m: float = 80.0, action_profile: Dictionary = {}) -> void:
	_push_map_event_effect({
		"kind": kind,
		"position": _wrap_world_position(to_position),
		"from": _wrap_world_position(from_position),
		"to": _wrap_world_position(to_position),
		"color": color,
		"label": _short_event_label(label),
		"life": max(0.1, duration),
		"duration": max(0.1, duration),
		"radius_m": max(1.0, radius_m),
		"motion_family": String(action_profile.get("motion_family", "")),
		"pose_key": String(action_profile.get("pose_key", "")),
		"effect_layer": String(action_profile.get("effect_layer", "")),
		"profile_key": String(action_profile.get("profile_key", "")),
		"range_meters": float(action_profile.get("range_meters", radius_m)),
		"knockback_meters": float(action_profile.get("knockback_meters", 0.0)),
		"throw_meters": float(action_profile.get("throw_meters", 0.0)),
		"impact_seconds": float(action_profile.get("impact_seconds", 0.45)),
	})


func _push_map_event_effect(effect: Dictionary) -> void:
	map_event_effects.append(effect)
	while map_event_effects.size() > MAX_MAP_EVENT_EFFECTS:
		map_event_effects.pop_front()


func _add_monster_attack_effect(from_position: Vector2, to_position: Vector2, source: String, range_limit_m: float, color: Color, is_ranged: bool = false, action_profile: Dictionary = {}) -> void:
	var kind := "laser" if is_ranged or _source_looks_ranged(source, range_limit_m) else "melee"
	_add_map_event_attack_effect(kind, from_position, to_position, color, source, 1.05 if kind == "laser" else 0.82, range_limit_m, action_profile)


func _add_district_damage_effect(index: int, source: String, color: Color = Color("#f97316")) -> void:
	if index < 0 or index >= districts.size():
		return
	var district: Dictionary = districts[index]
	var kind := _district_damage_effect_kind(source)
	_add_map_event_effect(kind, _district_center(index), color, source, 1.05 if kind == "stomp" else 0.90, float(district.get("radius_m", 70.0)))


func _district_damage_effect_kind(source: String) -> String:
	var text := source.to_lower()
	if text.contains("移动") or text.contains("冲撞") or text.contains("碾") or text.contains("践踏") or text.contains("自动破坏") or text.contains("暴走") or text.contains("资源吸取") or text.contains("落点") or text.contains("击退"):
		return "stomp"
	return "impact"


func _source_looks_ranged(source: String, range_limit_m: float) -> bool:
	var text := source.to_lower()
	if range_limit_m > MELEE_RANGE_METERS + 1.0:
		return true
	return text.contains("光线") or text.contains("射线") or text.contains("激光") or text.contains("火花") or text.contains("炮") or text.contains("炸弹") or text.contains("breath") or text.contains("shot") or text.contains("beam")


func _short_event_label(text: String, max_len: int = 9) -> String:
	if text.length() <= max_len:
		return text
	return text.left(max(1, max_len - 1)) + "…"


func _pulse_district(index: int, color: Color) -> void:
	if index < 0 or index >= districts.size():
		return
	districts[index]["pulse"] = DISTRICT_PULSE_DURATION
	districts[index]["pulse_color"] = color


func _append_unique_district_index(result: Array, index: int) -> void:
	if index < 0:
		return
	if not result.has(index):
		result.append(index)






func _on_victory_outcome_applied(receipt: Dictionary) -> void:
	var composition := _final_settlement_runtime_composition_node()
	if receipt.is_empty() or composition == null or not composition.has_method("present"):
		return
	var coordinator := _game_runtime_coordinator_node()
	var victory_public_variant: Variant = coordinator.call("victory_control_public_snapshot", -1) if coordinator != null and coordinator.has_method("victory_control_public_snapshot") else {}
	var victory_public: Dictionary = (victory_public_variant as Dictionary).duplicate(true) if victory_public_variant is Dictionary else {}
	var public_outcome_variant: Variant = victory_public.get("outcome_receipt", {})
	var public_outcome: Dictionary = (public_outcome_variant as Dictionary).duplicate(true) if public_outcome_variant is Dictionary else {}
	if str(receipt.get("outcome_id", "")).strip_edges().is_empty() or str(receipt.get("outcome_id", "")) != str(public_outcome.get("outcome_id", "")):
		return
	var participant_names := {}
	for player_index in range(players.size()):
		participant_names[str(player_index)] = _player_name(player_index)
	var presentation_variant: Variant = composition.call("present", {
		"victory_public_snapshot": victory_public,
		"participant_names": participant_names,
	})
	if not (presentation_variant is Dictionary) or not bool((presentation_variant as Dictionary).get("accepted", false)):
		return
	var learned_samples := int(_ai_runtime_call("finalize_victory_outcome_learning", [receipt]))
	if learned_samples > 0:
		_log("AI终局训练：已使用版本化 outcome receipt 回写%d条决策样本。" % learned_samples)


func _auto_monster_color(slot: int) -> Color:
	if AUTO_MONSTER_COLORS.is_empty():
		return Color("#ef4444")
	return AUTO_MONSTER_COLORS[slot % AUTO_MONSTER_COLORS.size()] as Color


func _auto_monster_markers() -> Array:
	var result := []
	for i in range(monster_runtime_controller.auto_monsters.size()):
		var actor: Dictionary = monster_runtime_controller.auto_monsters[i]
		var monster_name := String(actor.get("name", "怪兽"))
		var profile := _monster_art_profile(monster_name)
		result.append({
			"position": _entity_world_position(actor),
			"label": "%d" % (i + 1),
			"name": monster_name,
			"color": profile.get("accent", _auto_monster_color(i)),
			"slot_color": _auto_monster_color(i),
			"secondary": profile.get("secondary", Color("#e2e8f0")),
			"glyph": String(profile.get("glyph", "怪")),
			"motif": String(profile.get("motif", "beast")),
			"upstream_source_id": String(profile.get("upstream_source_id", "")),
			"visual_source_id": String(profile.get("visual_source_id", "")),
			"sprite_key": String(profile.get("sprite_key", "")),
			"sprite_cell": String(profile.get("sprite_cell", "")),
			"down": bool(actor.get("down", false)),
		})
	var military_roster := military_runtime_controller.roster_snapshot(true)
	for i in range(military_roster.size()):
		var unit: Dictionary = military_roster[i]
		var unit_label := military_runtime_controller.unit_type_label(unit)
		result.append({
			"position": _entity_world_position(unit),
			"label": military_runtime_controller.unit_type_glyph(unit),
			"name": "匿名%s" % unit_label,
			"color": military_runtime_controller.unit_color(unit),
			"slot_color": Color("#facc15"),
			"secondary": Color("#bfdbfe"),
			"glyph": military_runtime_controller.unit_type_glyph(unit),
			"motif": military_runtime_controller.unit_motif(unit),
			"down": false,
		})
	return result


func _district_center(index: int) -> Vector2:
	if index < 0 or index >= districts.size():
		return Vector2.ZERO
	return districts[index].get("center", Vector2.ZERO)


func _entity_world_position(entity: Dictionary) -> Vector2:
	return entity.get("world_position", _district_center(int(entity.get("position", 0))))


func _wrap_world_position(world_position: Vector2) -> Vector2:
	var width: float = max(1.0, map_width_m)
	var height: float = max(1.0, map_height_m)
	var x := world_position.x
	var y := world_position.y
	var guard := 0
	while (y < 0.0 or y > height) and guard < 12:
		if y < 0.0:
			y = -y
			x += width * 0.5
		elif y > height:
			y = height - (y - height)
			x += width * 0.5
		guard += 1
	return Vector2(fposmod(x, width), clamp(y, 0.0, height))


func _wrapped_delta(from_position: Vector2, to_position: Vector2) -> Vector2:
	var delta := _wrap_world_position(to_position) - _wrap_world_position(from_position)
	if abs(delta.x) > map_width_m * 0.5:
		delta.x -= sign(delta.x) * map_width_m
	return delta


func _wrapped_distance(from_position: Vector2, to_position: Vector2) -> float:
	return _spherical_distance(from_position, to_position)


func _world_to_lon_lat(world_position: Vector2) -> Vector2:
	var wrapped := _wrap_world_position(world_position)
	return Vector2(
		fposmod(wrapped.x / max(1.0, map_width_m) * TAU, TAU),
		PI * 0.5 - wrapped.y / max(1.0, map_height_m) * PI
	)


func _lon_lat_to_world(lon: float, lat: float) -> Vector2:
	return _wrap_world_position(Vector2(
		fposmod(lon, TAU) / TAU * max(1.0, map_width_m),
		(PI * 0.5 - clamp(lat, -PI * 0.5, PI * 0.5)) / PI * max(1.0, map_height_m)
	))


func _sphere_unit(world_position: Vector2) -> Vector3:
	var lon_lat := _world_to_lon_lat(world_position)
	var lon := lon_lat.x
	var lat := lon_lat.y
	return Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)).normalized()


func _sphere_radius_m() -> float:
	return max(1.0, map_width_m / TAU)


func _spherical_distance(from_position: Vector2, to_position: Vector2) -> float:
	var a := _sphere_unit(from_position)
	var b := _sphere_unit(to_position)
	var dot_value: float = clamp(a.dot(b), -1.0, 1.0)
	return acos(dot_value) * _sphere_radius_m()


func _sphere_unit_to_world(unit: Vector3) -> Vector2:
	var normalized := unit.normalized()
	var lon := atan2(normalized.z, normalized.x)
	var lat := asin(clamp(normalized.y, -1.0, 1.0))
	return _lon_lat_to_world(lon, lat)


func _spherical_lerp_world(from_position: Vector2, to_position: Vector2, weight: float) -> Vector2:
	var a := _sphere_unit(from_position)
	var b := _sphere_unit(to_position)
	var t: float = clamp(weight, 0.0, 1.0)
	var dot_value: float = clamp(a.dot(b), -1.0, 1.0)
	var angle := acos(dot_value)
	if angle <= 0.0001:
		return _wrap_world_position(to_position)
	var sin_angle := sin(angle)
	if abs(sin_angle) <= 0.0001:
		return _wrap_world_position(from_position + _wrapped_delta(from_position, to_position) * t)
	var blend := (a * (sin((1.0 - t) * angle) / sin_angle)) + (b * (sin(t * angle) / sin_angle))
	return _sphere_unit_to_world(blend)


func _set_entity_world_position(entity: Dictionary, world_position: Vector2) -> void:
	var wrapped_position := _wrap_world_position(world_position)
	entity["world_position"] = wrapped_position
	entity["position"] = _district_at_point(wrapped_position)
	if int(entity["position"]) < 0:
		entity["position"] = _nearest_district_to(wrapped_position)


func _move_entity_toward(entity: Dictionary, target_position: Vector2, max_distance_m: float) -> float:
	var current := _entity_world_position(entity)
	var wrapped_target := _wrap_world_position(target_position)
	var distance := _wrapped_distance(current, wrapped_target)
	if distance <= 0.01:
		_set_entity_world_position(entity, wrapped_target)
		return 0.0
	var moved: float = min(distance, max(0.0, max_distance_m))
	var next_position := _spherical_lerp_world(current, wrapped_target, moved / distance)
	_set_entity_world_position(entity, next_position)
	return moved


func _entity_has_linear_motion(entity: Dictionary) -> bool:
	return entity.has("linear_move_target_position") and float(entity.get("linear_move_speed_mps", 0.0)) > 0.0


func _clear_entity_linear_motion(entity: Dictionary) -> void:
	for key in [
		"linear_move_target_position",
		"linear_move_target_district",
		"linear_move_speed_mps",
		"linear_move_source",
		"linear_move_mode",
		"linear_move_damaged_districts",
		"linear_move_started_at",
		"linear_move_arrival_action",
		"linear_move_unit_label",
		"linear_move_arrival_damage",
		"linear_move_arrival_damage_source",
	]:
		entity.erase(key)


func _start_entity_linear_motion(entity: Dictionary, target_position: Vector2, speed_mps: float, source: String, movement_mode: String = "", max_distance_m: float = -1.0, arrival_action: String = "") -> float:
	var current := _entity_world_position(entity)
	var wrapped_target := _wrap_world_position(target_position)
	var distance := _wrapped_distance(current, wrapped_target)
	if max_distance_m > 0.0 and distance > max_distance_m:
		wrapped_target = _spherical_lerp_world(current, wrapped_target, max_distance_m / distance)
		distance = max_distance_m
	if distance <= 0.5 or speed_mps <= 0.0:
		_clear_entity_linear_motion(entity)
		return 0.0
	entity["linear_move_target_position"] = wrapped_target
	entity["linear_move_target_district"] = _nearest_district_to(wrapped_target)
	entity["linear_move_speed_mps"] = maxf(1.0, speed_mps)
	entity["linear_move_source"] = source
	entity["linear_move_mode"] = movement_mode
	entity["linear_move_damaged_districts"] = []
	entity["linear_move_started_at"] = game_time
	entity["linear_move_arrival_action"] = arrival_action
	return distance


func _advance_entity_linear_motion(entity: Dictionary, delta_seconds: float) -> Dictionary:
	if not _entity_has_linear_motion(entity):
		return {"moved": 0.0, "arrived": false}
	var before := _entity_world_position(entity)
	var target: Vector2 = entity.get("linear_move_target_position", before)
	var target_district := int(entity.get("linear_move_target_district", _nearest_district_to(target)))
	var source := String(entity.get("linear_move_source", "线性移动"))
	var mode := String(entity.get("linear_move_mode", ""))
	var arrival_action := String(entity.get("linear_move_arrival_action", ""))
	var speed := maxf(0.0, float(entity.get("linear_move_speed_mps", 0.0)))
	var moved := _move_entity_toward(entity, target, speed * maxf(0.0, delta_seconds))
	var after := _entity_world_position(entity)
	var arrived := _wrapped_distance(after, target) <= 0.75
	if arrived:
		_set_entity_world_position(entity, target)
	return {
		"moved": moved,
		"arrived": arrived,
		"before": before,
		"after": after,
		"target": target,
		"target_district": target_district,
		"source": source,
		"mode": mode,
		"arrival_action": arrival_action,
	}


func _entity_distance_to_district(entity: Dictionary, district_index: int) -> float:
	return _wrapped_distance(_entity_world_position(entity), _district_center(district_index))


func _district_at_point(point: Vector2) -> int:
	point = _wrap_world_position(point)
	for i in range(districts.size()):
		if _point_in_polygon(point, districts[i].get("polygon", [])):
			return i
	return -1


func _point_in_polygon(point: Vector2, polygon: Array) -> bool:
	if polygon.size() < 3:
		return false
	var inside := false
	var j := polygon.size() - 1
	for i in range(polygon.size()):
		var pi: Vector2 = polygon[i]
		var pj: Vector2 = polygon[j]
		var crosses := (pi.y > point.y) != (pj.y > point.y)
		if crosses:
			var x_at_y: float = (pj.x - pi.x) * (point.y - pi.y) / max(0.001, pj.y - pi.y) + pi.x
			if point.x < x_at_y:
				inside = not inside
		j = i
	return inside


func _districts_in_radius(center: Vector2, radius_m: float, include_destroyed := false) -> Array:
	var entries := []
	for i in range(districts.size()):
		if not include_destroyed and districts[i]["destroyed"]:
			continue
		var dist := _wrapped_distance(center, _district_center(i))
		if dist <= radius_m:
			entries.append({"index": i, "distance": dist})
	entries.sort_custom(Callable(self, "_sort_distance_entry"))
	var result := []
	for entry in entries:
		result.append(int(entry["index"]))
	return result


func _sort_distance_entry(a: Dictionary, b: Dictionary) -> bool:
	return float(a["distance"]) < float(b["distance"])


func _district_connection_summary(index: int) -> String:
	var nearby := _districts_in_radius(_district_center(index), NEARBY_RADIUS_METERS, false)
	var names := []
	for neighbor in nearby:
		if neighbor == index:
			continue
		names.append(districts[neighbor]["name"])
		if names.size() >= 4:
			break
	if names.is_empty():
		return "%s内暂无" % _meters_text(NEARBY_RADIUS_METERS)
	return " / ".join(names)


func _entity_distance_to_district_label(entity: Dictionary, district_index: int) -> String:
	return _meters_text(_entity_distance_to_district(entity, district_index))


func _meters_text(value: float) -> String:
	if value >= 1000.0:
		return "%.1fkm" % (value / 1000.0)
	return "%.0fm" % value


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	var minutes := int(float(total) / 60.0)
	var rest := total % 60
	return "%02d:%02d" % [minutes, rest]


func _plain_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _log(message: String) -> void:
	var line := "[%s] %s" % [_format_time(game_time), message]
	log_lines.append(line)
	while log_lines.size() > 90:
		log_lines.pop_front()

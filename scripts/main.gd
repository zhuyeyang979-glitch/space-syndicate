extends Control

const MapViewScript := preload("res://scripts/map_view.gd")
const CardArtViewScript := preload("res://scripts/card_art_view.gd")
const MonsterArtViewScript := preload("res://scripts/monster_art_view.gd")

const MIN_PLAYER_COUNT := 3
const MAX_PLAYER_COUNT := 8
const DEFAULT_PLAYER_COUNT := 4
const MIN_AI_PLAYER_COUNT := 2
const MAX_AI_PLAYER_COUNT := 7
const DEFAULT_AI_PLAYER_COUNT := 3
const ROGUELIKE_DEPTH_MIN := 1
const ROGUELIKE_DEPTH_MAX := 6
const DEFAULT_ROGUELIKE_DEPTH := 1
const ROGUELIKE_CASH_GOAL_BASE := 2200
const ROGUELIKE_CASH_GOAL_STEP := 1400
const AI_CARD_DECISION_INTERVAL_SECONDS := 2.2
const AI_AUCTION_REACTION_INTERVAL_SECONDS := 0.7
const AI_INTEL_DECISION_INTERVAL_SECONDS := 5.5
const AI_CARD_BUY_MIN_CASH_RESERVE := 260
const AI_DECISION_SAMPLE_LIMIT := 48
const AI_CANDIDATE_SAMPLE_LIMIT := 8
const AI_INTEL_MIN_CITY_SCORE := 78
const AI_INTEL_MIN_CARD_SCORE := 125
const AI_INTEL_ACTIONS_PER_TICK := 2
const AI_ECONOMIC_FOCUS_TOP_LIMIT := 3
const AI_ECONOMIC_FOCUS_MATCH_BONUS := 85
const AI_STRATEGY_MATCH_BONUS := 92
const AI_STRATEGY_TOP_LIMIT := 3
const AI_ROUTE_PLAN_MATCH_BONUS := 78
const AI_ROUTE_PLAN_TOP_LIMIT := 4
const AI_ROUTE_PLAN_SWITCH_MARGIN := 140
const AI_ROUTE_PLAN_ENTRENCHED_SWITCH_MARGIN := 360
const AI_ENDGAME_GOAL_RATIO := 0.72
const AI_ENDGAME_CYCLE := 7
const AI_OPENING_CYCLE_MAX := 1
const AI_LEAD_MARGIN := 280
const AI_TRAILING_MARGIN := 360
const AI_LEARNING_REWARD_CLAMP := 1200
const AI_LEARNING_VALUE_CLAMP := 90.0
const AI_LEARNING_BONUS_CLAMP := 140
const AI_LEARNING_BASE_RATE := 0.22
const AI_EPISODE_REWARD_CLAMP := 1800
const AI_EPISODE_SAMPLE_DECAY := 0.88
const AI_EPISODE_WIN_BONUS := 420
const AI_EPISODE_GOAL_BONUS := 240
const MAP_WIDTH_METERS := 1400.0
const MAP_HEIGHT_METERS := 950.0
const MAP_SITE_MARGIN_METERS := 70.0
const MAP_REGION_COUNT_MIN := 6
const MAP_REGION_COUNT_MAX := 54
const MONSTER_COMMAND_MOVE_METERS := 220.0
const MONSTER_RAMPAGE_MOVE_METERS := 190.0
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
const CARD_INGRESS_TRAIL_DURATION := 5.5
const CARD_INGRESS_CALLOUT_DURATION := 6.5
const CARD_TRACK_DRAG_DEADZONE_PIXELS := 4.0
const CARD_TRACK_WHEEL_STEP_PIXELS := 72
const AUTO_MONSTER_MOVE_RATIO := 0.72
const AUTO_MONSTER_MIN_SPECIAL_DAMAGE := 1
const AUTO_MONSTER_ENCOUNTER_RANGE_METERS := 170.0
const AUTO_MONSTER_PATH_DAMAGE_STEP_METERS := 190.0
const AUTO_MONSTER_PATH_DAMAGE_MAX_REGIONS := 4
const AUTO_MONSTER_KNOCKBACK_DAMAGE_MAX_REGIONS := 3
const AUTO_MONSTER_DEFAULT_MOVE_DAMAGE := 1
const AUTO_MONSTER_DEFAULT_COLLISION_DAMAGE := 1
const STATUS_PARALYSIS_SECONDS := 4.0
const STATUS_STUN_DELAY_SECONDS := 1.4
const STATUS_TETHER_MOVE_PENALTY_METERS := 85.0
const MEBIUS_ENERGY_THRESHOLD := 15
const MEBIUS_ENERGY_MOVE_BONUS_METERS := 180.0
const MEBIUS_ENERGY_FLAME_DAMAGE := 1
const MEBIUS_BOMB_SELF_DAMAGE := 3
const HIKARI_REVENGE_ARMOR_THRESHOLD := 20
const HIKARI_REVENGE_DAMAGE_REDUCTION := 1
const HIKARI_REVENGE_DAMAGE_BONUS := 1
const ACE_KILLER_SKIRMISH_RANGE_METERS := 420.0
const ACE_KILLER_PERFECT_GUARD_REDUCTION := 3
const ACE_KILLER_PERFECT_GUARD_COUNTER_DAMAGE := 2
const ACE_KILLER_EVASIVE_MOVE_METERS := 220.0
const ACE_KILLER_RAY_PATH_WIDTH_METERS := 70.0
const STARTING_CASH := 2000
const CITY_BUILD_COST := 600
const CITY_HP_BONUS := 8
const CITY_PRODUCT_COUNT_MIN := 1
const CITY_PRODUCT_COUNT_MAX := 1
const CITY_DEMAND_COUNT_MIN := 1
const CITY_DEMAND_COUNT_MAX := 1
const CITY_PRODUCT_BASE_REVENUE := 42
const CITY_PRODUCT_LEVEL_REVENUE := 12
const CITY_PRODUCT_LEVEL_MAX := 5
const CITY_DEMAND_SUPPLY_REVENUE := 28
const CITY_PRODUCT_PRICE_REVENUE_DIVISOR := 5
const CITY_DEMAND_PRICE_REVENUE_DIVISOR := 8
const CITY_PRODUCTION_GDP_SCALE := 0.58
const CITY_CONSUMPTION_GDP_SCALE := 0.72
const CITY_TRANSIT_GDP_BASE := 18
const CITY_TRANSIT_PRICE_DIVISOR := 20
const CITY_COMPETITION_PENALTY := 16
const TRADE_DISRUPTION_PENALTY := 55
const CITY_DAMAGE_GDP_PENALTY := 18
const CITY_MINIMUM_INCOME := 40
const CITY_FINAL_VALUE := 700
const CITY_BUILD_ANIMATION_SECONDS := 1.2
const VICTORY_COUNTDOWN_SECONDS := 60.0
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
const RIVAL_BUSINESS_ROUTE_DAMAGE := 1
const ECONOMY_HISTORY_LIMIT := 24
const ECONOMY_LEDGER_LIMIT := 14
const CARD_PRICE_UNIT := 70
const CARD_PRICE_COST_STEP := 45
const CARD_SPECIAL_PRICE_PREMIUM := 90
const CARD_MIN_PRICE := 80
const PLAYER_HAND_LIMIT := 5
const CARD_RESOLUTION_DISPLAY_SECONDS := 5.0
const CARD_RESOLUTION_AFTERMATH_SECONDS := 8.0
const CARD_BID_INCREMENT_OPTIONS := [10, 20, 50, 100, 200, 500, 1000]
const CARD_RESOLUTION_HISTORY_LIMIT := 24
const CARD_OWNER_GUESS_STAKE := 100
const CARD_SIMULTANEOUS_WINDOW_SECONDS := 0.5
const CONTRACT_RESPONSE_PENDING := "pending"
const CONTRACT_RESPONSE_ACCEPTED := "accepted"
const CONTRACT_RESPONSE_REJECTED := "rejected"
const CONTRACT_RESPONSE_TIMEOUT := "timeout"
const CONTRACT_DECISION_SECONDS := 5.0
const MONSTER_CARD_PLAY_CASH_PER_EXISTING := 100
const MONSTER_OWNER_DAMAGE_CASH_POOL := 800
const MONSTER_CARD_DURATION_BASE_SECONDS := 95.0
const MONSTER_CARD_DURATION_RANK_STEP_SECONDS := 28.0
const PRODUCT_PRICE_MIN := 26
const PRODUCT_PRICE_MAX := 280
const PRODUCT_SUPPLY_PRICE_WEIGHT := 5
const PRODUCT_DEMAND_PRICE_WEIGHT := 8
const PRODUCT_ROUTE_DAMAGE_PRICE_WEIGHT := 10
const PRODUCT_VOLATILITY_MIN := 1
const PRODUCT_VOLATILITY_MAX := 30
const PRODUCT_HISTORY_LIMIT := 12
const PRODUCT_GROWTH_MULTIPLIER_MAX := 3.0
const ROUTE_FLOW_MULTIPLIER_MAX := 2.8
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
const ACTION_COOLDOWN := 1.2
const MARKET_COOLDOWN := 1.8
const COMMAND_COOLDOWN := 1.0
const DEFAULT_SKILL_COOLDOWN := 3.0
const SETTINGS_PATH := "user://space_syndicate_settings.cfg"
const RUN_SAVE_PATH := "user://space_syndicate_current_run.save"
const RUN_SAVE_VERSION := 1

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
		"starter_monster_index": 2,
		"trait": "高速物流与电池黑市专家；喜欢把怪兽登陆伪装成货运事故。",
		"passive": "开局资金+¥80；起始怪兽移动+15%；在含环晶电池的区域购牌时，免费额外获得1张同区候选牌。",
		"starting_cash_bonus": 80,
		"starter_move_multiplier": 1.15,
		"bonus_card_product": "环晶电池",
		"flavor": "他们总能把第一只怪兽包装成一次普通货运事故。",
	},
	{
		"name": "深海菌毯使团",
		"species": "雾鳃孢子人",
		"starter_monster_index": 0,
		"trait": "擅长把资源偏好伪装成生态灾害；靠菌毯副产物结算现金。",
		"passive": "起始怪兽生命+8，在场时间+12秒；己方含深海菌毯的城市每个经营周期额外+¥55。",
		"starter_hp_bonus": 8,
		"starter_duration_bonus": 12.0,
		"resource_cash_product": "深海菌毯",
		"resource_cash_amount": 55,
		"flavor": "他们的合同像潮湿的孢子一样扩散，没人知道真正的客户是谁。",
	},
	{
		"name": "重力矿联董事会",
		"species": "岩壳重核族",
		"starter_monster_index": 1,
		"trait": "矿业城市与重物流保护伞；用重力陶瓷抵押城市现金流。",
		"passive": "起始怪兽生命+12；己方含重力陶瓷的城市每个经营周期额外+¥45。",
		"starter_hp_bonus": 12,
		"resource_cash_product": "重力陶瓷",
		"resource_cash_amount": 45,
		"flavor": "他们称一切破坏为地质调整，并且会给调整开票。",
	},
	{
		"name": "离子军购局",
		"species": "蓝焰档案体",
		"starter_monster_index": 3,
		"trait": "军需订单与能量食品投标人；怪兽升级会变成采购预算。",
		"passive": "起始怪兽召唤后额外获得1张绑定固定技能；己方怪兽升级时获得¥120。",
		"starter_fixed_skill_bonus": 1,
		"monster_upgrade_cash": 120,
		"flavor": "他们从不发动战争，只是提前出售战争会需要的东西。",
	},
	{
		"name": "光合修复会",
		"species": "藤冠共生体",
		"starter_monster_index": 4,
		"trait": "避难产业和修复商品联盟；把光合凝胶做成灾后保险。",
		"passive": "开局资金+¥120；起始怪兽在场时间+20秒；己方含光合凝胶的城市每个经营周期额外+¥40。",
		"starting_cash_bonus": 120,
		"starter_duration_bonus": 20.0,
		"resource_cash_product": "光合凝胶",
		"resource_cash_amount": 40,
		"flavor": "他们的城市总在灾后重建合同签好之后才被灾难发现。",
	},
	{
		"name": "虹膜数据券商",
		"species": "棱眼账本体",
		"starter_monster_index": 5,
		"trait": "把活体芯片写进每笔交易的影子账本；擅长从情报商品区顺手拿牌。",
		"passive": "开局资金+¥60；在含活体芯片的区域购牌时，免费额外获得1张同区候选牌。",
		"starting_cash_bonus": 60,
		"bonus_card_product": "活体芯片",
		"flavor": "他们不偷情报，他们只是提前拥有账本的下一页。",
	},
	{
		"name": "星鲸餐饮垄断",
		"species": "鲸胃星民",
		"starter_monster_index": 6,
		"trait": "星鲸罐头连锁供应商；怪兽每次变强都会顺便带火一次联名营销。",
		"passive": "己方含星鲸罐头的城市每个经营周期额外+¥50；己方怪兽升级时获得¥60。",
		"resource_cash_product": "星鲸罐头",
		"resource_cash_amount": 50,
		"monster_upgrade_cash": 60,
		"flavor": "他们坚称每一次怪兽袭击都只是一次过于成功的试吃会。",
	},
	{
		"name": "静电蜂巢银行",
		"species": "金翼蜂群意志",
		"starter_monster_index": 7,
		"trait": "用静电蜂蜜给黑市信用背书；越靠近甜味商路，越容易多拿一张牌。",
		"passive": "起始怪兽移动+8%；在含静电蜂蜜的区域购牌时，免费额外获得1张同区候选牌。",
		"starter_move_multiplier": 1.08,
		"bonus_card_product": "静电蜂蜜",
		"flavor": "他们发出的不是贷款通知，是一整座蜂巢的低频催收。",
	},
	{
		"name": "星图审计庭",
		"species": "银环观测官",
		"starter_monster_index": 1,
		"trait": "把每一座城市的施工轨迹写进星图账本；擅长直接锁定陌生区域业主。",
		"passive": "每局可用2次身份侦测：直接查明当前选中陌生城市的真实业主，并以高置信写入私人标注；城市归属终局命中奖励+¥40。",
		"intel_city_reveal_charges": 2,
		"city_guess_reward_bonus": 40,
		"flavor": "他们从不问“是谁造的”，只问“为什么发票没有经过审计庭”。",
	},
	{
		"name": "幽幕播报社",
		"species": "暗频主持群",
		"starter_monster_index": 5,
		"trait": "专门购买匿名出牌瞬间的影像残帧；可以追溯卡牌轨道上的历史归属。",
		"passive": "每局可用1次身份追帧：私下查明一张轨道匿名牌是谁打出的；卡牌归属竞猜押注成本-¥40。",
		"intel_card_trace_charges": 1,
		"card_owner_guess_discount": 40,
		"flavor": "所有画面都是雪花屏，只有他们听得见雪花里谁在结账。",
	},
	{
		"name": "双边密约公证团",
		"species": "镜面章鱼律师",
		"starter_monster_index": 6,
		"trait": "从合约墨迹里读出双方的影子；知道更多，但不能免费公开证明。",
		"passive": "每局可用2次合约回溯：私下查明最近一份匿名合约的出牌方与目标业主；合约类卡牌流动门槛-1（最低0）。",
		"intel_contract_trace_charges": 2,
		"contract_flow_discount": 1,
		"flavor": "他们盖章时会伸出第三只触手，专门握住真正签字的人。",
	},
	{
		"name": "碎光私探行会",
		"species": "棱镜游民",
		"starter_monster_index": 3,
		"trait": "靠半真半假的线索套利；不一定知道答案，但下注成本更低。",
		"passive": "卡牌归属竞猜押注成本-¥30，猜中额外获得¥30；起始怪兽在场时间+8秒。",
		"card_owner_guess_discount": 30,
		"card_owner_guess_bonus": 30,
		"starter_duration_bonus": 8.0,
		"flavor": "他们卖出的每条线索都闪闪发光，尤其是错的那条。",
	},
	{
		"name": "星门补给商会",
		"species": "折跃仓储人",
		"starter_monster_index": 2,
		"trait": "把怪兽登陆点当作临时仓库坐标；能从二跳邻区远程买牌，但物流费更高。",
		"passive": "可从怪兽所在区相邻区域的相邻区域购买卡牌；二跳购牌价格×1.10；开局资金+¥40。",
		"starting_cash_bonus": 40,
		"card_access_extra_hops": 1,
		"extended_card_price_multiplier": 1.10,
		"flavor": "他们的仓库门永远开在怪兽脚印的下一圈。",
	},
]

const AI_PERSONALITY_CATALOG := [
	{
		"name": "拓荒型AI",
		"style": "优先抢高GDP陆地与海洋邻接位，尽快形成城市收入。",
		"build_bias": 1.2,
		"business_bias": 0.9,
		"monster_bias": 0.8,
		"economy_bias": 1.05,
		"bid_aggression": 0.75,
		"exploration": 0.18,
	},
	{
		"name": "套利型AI",
		"style": "追逐高价商品、供需缺口和可持续涨价窗口。",
		"build_bias": 1.0,
		"business_bias": 1.25,
		"monster_bias": 0.75,
		"economy_bias": 1.35,
		"bid_aggression": 1.05,
		"exploration": 0.12,
	},
	{
		"name": "破坏型AI",
		"style": "偏好商路黑客和竞争城市压制，让怪兽战争服务于破坏收益。",
		"build_bias": 0.9,
		"business_bias": 1.15,
		"monster_bias": 1.15,
		"economy_bias": 0.85,
		"bid_aggression": 1.25,
		"exploration": 0.22,
	},
	{
		"name": "驯怪型AI",
		"style": "更重视怪兽落点、资源偏好和购牌半径，适合后续训练召唤/诱导策略。",
		"build_bias": 0.95,
		"business_bias": 1.0,
		"monster_bias": 1.35,
		"economy_bias": 0.9,
		"bid_aggression": 0.95,
		"exploration": 0.16,
	},
]

const PRODUCT_CATALOG := [
	"星露莓", "磁核榴莲", "月壤葡萄", "量子蜜瓜", "彗尾柑", "脉冲咖啡",
	"真空可可", "离子香料", "孢子丝绸", "环晶电池", "重力陶瓷", "梦境香氛",
	"零点饮料", "活体芯片", "星鲸罐头", "云母玩具", "光合凝胶", "轨道盆栽",
	"极光盐", "蓝潮藻", "风暴珍珠", "赤道香草", "寒冠冰糖", "太阳鳞片",
	"深海菌毯", "反物质茶", "虹膜矿粉", "引力棉", "钛壳贝", "夜航香蕉",
	"陨铁酱料", "静电蜂蜜", "星尘面包", "暗礁珊瑚", "离岸水晶", "晨昏奶酪",
	"轨迹墨水", "等离子米", "北极薄荷", "火山番茄", "卫星坚果", "梦游蘑菇",
]

const OCEAN_DISTRICT_NAME_POOL := [
	"蓝潮海", "静默洋", "环流海峡", "极光湾", "赤道航道", "深星海盆",
	"群岛外海", "寒冠洋", "珊瑚环礁", "远洋航门", "月影海", "磁暴海峡",
]

const PRODUCT_PRICE_TIERS := [
	{"label": "基础消费", "weight": 36, "min": 30, "max": 58, "volatility": 4},
	{"label": "成长商品", "weight": 32, "min": 62, "max": 104, "volatility": 7},
	{"label": "奢侈品", "weight": 22, "min": 112, "max": 174, "volatility": 11},
	{"label": "战略稀缺", "weight": 10, "min": 184, "max": 260, "volatility": 16},
]

const SPECIAL_MONSTER_EARLY_ACTION_WEIGHTS := [2, 2, 2, 0, 0, 0]
const SPECIAL_MONSTER_ESCALATED_ACTION_WEIGHTS := [1, 1, 1, 1, 1, 1]

const MONSTER_TARGET_BASE_WEIGHT := 10
const MONSTER_TARGET_PANIC_WEIGHT := 1
const MONSTER_TARGET_DISTANCE_BASE := 48.0
const MONSTER_TARGET_DISTANCE_STEP := 0.045
const MONSTER_TARGET_MIASMA_BONUS := 18
const MONSTER_TARGET_RIVAL_BONUS := 10
const MONSTER_TARGET_CITY_BONUS := 38
const MONSTER_TARGET_PRODUCT_WEIGHT := 3
const MONSTER_TARGET_COMPETITION_WEIGHT := 5
const MONSTER_TARGET_RESOURCE_WEIGHT := 12

const EVENT_TARGET_BASE_WEIGHT := 8
const EVENT_TARGET_PANIC_WEIGHT := 1
const EVENT_TARGET_MIASMA_BONUS := 14
const EVENT_TARGET_MONSTER_BONUS := 10
const EVENT_TARGET_CITY_BONUS := 24
const EVENT_TARGET_COMPETITION_WEIGHT := 3
const EVENT_TARGET_TRADE_WEIGHT := 4

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
	"event_min": 5.0,
	"event_max": 8.0,
	"monster_min": 3.5,
	"monster_max": 5.5,
	"special_monster_min": 4.5,
	"special_monster_max": 7.0,
	"market_min": 7.0,
	"market_max": 11.0,
	"event_heat_min": 10,
	"event_heat_max": 24,
	"monster_damage": 1,
	"special_monster_damage_bonus": 0,
	"special_monster_move_bonus": 0,
}

const SKILL_CATALOG := {
	"城市融资1": {"cost": 3, "kind": "city_revenue_boost", "revenue_amount": 60, "damage": 0, "move": 0, "range": 0, "tags": ["经营", "收入"], "text": "选中己方城市的每个经营周期收入+60。"},
	"城市融资2": {"cost": 5, "kind": "city_revenue_boost", "revenue_amount": 100, "damage": 0, "move": 0, "range": 0, "tags": ["经营", "升级"], "text": "选中己方城市的每个经营周期收入+100。"},
	"城市融资3": {"cost": 7, "kind": "city_revenue_boost", "revenue_amount": 160, "damage": 0, "move": 0, "range": 0, "tags": ["经营", "终端"], "text": "选中己方城市的每个经营周期收入+160。"},
	"星际广告1": {"cost": 2, "kind": "city_revenue_boost", "revenue_amount": 45, "panic": 12, "damage": 0, "move": 0, "range": 0, "tags": ["经营", "曝光"], "text": "选中己方城市周期收入+45，同时提高当地曝光与怪兽关注。"},
	"星际广告2": {"cost": 4, "kind": "city_revenue_boost", "revenue_amount": 80, "panic": 18, "damage": 0, "move": 0, "range": 0, "tags": ["经营", "升级"], "text": "选中己方城市周期收入+80、区域热度+18。"},
	"星际广告3": {"cost": 6, "kind": "city_revenue_boost", "revenue_amount": 130, "panic": 28, "damage": 0, "move": 0, "range": 0, "tags": ["经营", "终端"], "text": "选中己方城市周期收入+130、区域热度+28。"},
	"轨道融资1": {"cost": 3, "kind": "cash_gain", "cash": 300, "damage": 0, "move": 0, "range": 0, "tags": ["经济", "续航"], "text": "立即获得300资金，用于城市化或补给。"},
	"轨道融资2": {"cost": 5, "kind": "cash_gain", "cash": 700, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "升级"], "text": "立即获得700资金，支撑扩张或高费构筑。"},
	"舆论操控1": {"cost": 3, "kind": "panic_shift", "panic": 30, "damage": 0, "move": 0, "range": 0, "tags": ["热度", "引导"], "text": "选中区域热度+30，立刻提高怪兽和新闻事件对该区的关注。"},
	"舆论操控2": {"cost": 6, "kind": "panic_shift", "panic": 65, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["热度", "升级"], "text": "选中区域热度+65，强行把概率目标推向该区域。"},
	"诱导电波1": {"cost": 3, "kind": "monster_lure", "lure_speedup": 3.0, "damage": 0, "move": 0, "range": 0, "tags": ["诱导", "节奏"], "text": "指定一只怪兽：它下一次自动移动优先朝当前选区推进，并提前最多3秒触发；怪兽之后仍按自身概率行动。"},
	"诱导电波2": {"cost": 5, "kind": "monster_lure", "lure_speedup": 5.5, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["诱导", "升级"], "text": "指定一只怪兽：它下一次自动移动优先朝当前选区推进，并提前最多5.5秒触发；这是一次性诱导，结算后失效。"},
	"夺取怪兽1": {"cost": 5, "kind": "monster_takeover", "play_product": "活体芯片", "play_flow_required": 2, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["怪兽", "归属"], "text": "指定一只场上怪兽，匿名夺取其归属权；不会公开是谁打出的，之后该怪兽受伤会暴露新的资金线索。"},
	"过载补给1": {"cost": 4, "kind": "supply_draw", "draw_amount": 1, "damage": 0, "move": 0, "range": 0, "tags": ["构筑", "补给"], "text": "从当前区域额外获取1张候选卡。"},
	"过载补给2": {"cost": 6, "kind": "supply_draw", "draw_amount": 2, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["构筑", "升级"], "text": "从当前区域额外获取2张候选卡，是补给连锁的升级核心。"},
	"业主透镜1": {"cost": 3, "kind": "intel_city_reveal", "play_product": "轨迹墨水", "play_flow_required": 1, "reveal_city_count": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["情报", "区域"], "text": "私下查明当前选中陌生城市的真实业主，并以高置信写入自己的地图标注；只公开有人打出了这张线索牌，不公开查到的答案。"},
	"业主透镜2": {"cost": 5, "kind": "intel_city_reveal", "play_product": "轨迹墨水", "play_flow_required": 2, "reveal_city_count": 2, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["情报", "升级"], "text": "私下查明当前选中陌生城市及一个高价值陌生城市的真实业主，各写入高置信私人标注；答案不公开。"},
	"出牌追帧1": {"cost": 4, "kind": "intel_card_trace", "play_product": "活体芯片", "play_flow_required": 1, "trace_card_count": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["情报", "卡牌"], "text": "私下追溯卡牌轨道上一张匿名牌的出牌者：优先查当前选中的轨道卡，未选则查最近未公开的历史牌。"},
	"出牌追帧2": {"cost": 6, "kind": "intel_card_trace", "play_product": "活体芯片", "play_flow_required": 2, "trace_card_count": 2, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["情报", "升级"], "text": "私下追溯最多两张匿名牌的出牌者：优先当前选中卡，再追最近未公开历史牌。"},
	"密约回溯1": {"cost": 4, "kind": "intel_contract_trace", "play_product": "轨迹墨水", "play_flow_required": 1, "trace_contract_count": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["情报", "合约"], "text": "私下查明最近一份匿名合约的出牌方与目标城市业主；若当前轨道选中合约，则优先追溯该合约。"},
	"密约回溯2": {"cost": 7, "kind": "intel_contract_trace", "play_product": "轨迹墨水", "play_flow_required": 2, "trace_contract_count": 2, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["情报", "升级"], "text": "私下查明最多两份匿名合约的出牌方与目标城市业主；适合在多合约轨道里拆穿双边结构。"},
	"远程补给链1": {"cost": 3, "kind": "card_access_boon", "play_product": "轨道盆栽", "play_flow_required": 1, "card_access_extra_hops": 1, "extended_card_price_multiplier": 1.10, "card_access_seconds": 45.0, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["补给", "范围"], "text": "接下来45秒，你可以从怪兽落地区二跳内的区域购买卡牌；二跳购牌价格×1.10。"},
	"星门采购权1": {"cost": 6, "kind": "card_access_boon", "play_product": "离岸水晶", "play_flow_required": 2, "card_access_global": true, "global_card_price_multiplier": 1.35, "card_access_seconds": 25.0, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["补给", "全局"], "text": "接下来25秒，你可以从任意未毁区域购买候选卡；全局购牌价格×1.35。"},
	"地下融资1": {"cost": 3, "kind": "cash_gain", "cash": 450, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "续航"], "text": "立即获得450资金，适合扩张或高费卡组提前转动。"},
	"热搜推送1": {"cost": 4, "kind": "panic_shift", "panic": 45, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["热度", "引导"], "text": "选中区域热度+45，把怪兽概率目标和新闻事件都往这里拽。"},
	"商业诱饵1": {"cost": 4, "kind": "city_revenue_boost", "revenue_amount": 70, "panic": 8, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "诱饵"], "text": "选中己方城市周期收入+70、热度+8，以商业曝光吸引怪兽路线。"},
	"商业诱饵2": {"cost": 7, "kind": "city_revenue_boost", "revenue_amount": 125, "panic": 14, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "升级"], "text": "选中己方城市周期收入+125、热度+14。"},
	"价格套利1": {"cost": 3, "kind": "product_speculation", "cash": 220, "price_delta": 18, "panic": 4, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "商品"], "text": "围绕当前商品做短线套利：获得220资金，并制造临时需求压力；价格由下一次供需重算体现。"},
	"价格套利2": {"cost": 5, "kind": "product_speculation", "cash": 480, "price_delta": 34, "panic": 8, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "升级"], "text": "高阶套利：获得480资金，并制造更强临时需求压力；价格仍由供需关系结算。"},
	"供应链保险1": {"cost": 3, "kind": "route_insurance", "repair_routes": 1, "revenue_amount": 30, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "商路"], "text": "选中己方城市：清除1条受损商路压力，并使周期收入+30。"},
	"供应链保险2": {"cost": 5, "kind": "route_insurance", "repair_routes": 2, "revenue_amount": 55, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "升级"], "text": "选中己方城市：清除2条受损商路压力，并使周期收入+55。"},
	"垄断协议1": {"cost": 5, "kind": "city_revenue_boost", "revenue_amount": 115, "panic": 22, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "垄断"], "text": "选中己方城市周期收入+115、区域热度+22；高收益也会明显吸怪。"},
	"需求创造1": {"cost": 4, "kind": "city_revenue_boost", "revenue_amount": 85, "panic": 6, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "需求"], "text": "选中己方城市周期收入+85、热度+6，用营销制造稳定需求。"},
	"短期订单1": {"cost": 4, "kind": "city_contract_boon", "contract_income": 95, "contract_turns": 3, "panic": 4, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "合约"], "text": "选中己方城市获得临时订单：每个经营周期额外+95，持续3周期。"},
	"短期订单2": {"cost": 6, "kind": "city_contract_boon", "contract_income": 155, "contract_turns": 4, "panic": 7, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "升级"], "text": "选中己方城市获得大额临时订单：每个经营周期额外+155，持续4周期。"},
	"军需临单1": {"cost": 5, "kind": "city_contract_boon", "contract_income": 130, "contract_turns": 2, "panic": 16, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "军需"], "text": "选中己方城市接军需临单：每个经营周期额外+130，持续2周期；区域热度+16。"},
	"军需临单2": {"cost": 7, "kind": "city_contract_boon", "contract_income": 210, "contract_turns": 3, "panic": 24, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "升级"], "text": "选中己方城市接高价军需临单：每个经营周期额外+210，持续3周期；区域热度+24。"},
	"星际会展1": {"cost": 5, "kind": "city_contract_boon", "contract_income": 80, "contract_turns": 3, "route_flow_multiplier": 1.25, "route_flow_turns": 3, "panic": 12, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "会展"], "text": "选中己方城市举办会展：临时合约收入+80/周期，并使商路流通收入×1.25，持续3周期；区域热度+12。"},
	"星际会展2": {"cost": 7, "kind": "city_contract_boon", "contract_income": 135, "contract_turns": 4, "route_flow_multiplier": 1.45, "route_flow_turns": 4, "panic": 20, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "升级"], "text": "选中己方城市举办大型星际会展：临时合约收入+135/周期，并使商路流通收入×1.45，持续4周期；区域热度+20。"},
	"商品做空1": {"cost": 4, "kind": "product_speculation", "cash": 260, "price_delta": -24, "panic": 10, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "做空"], "text": "围绕当前商品做空：获得260资金，并制造临时供给压力；价格由供需重算体现。"},
	"商品做空2": {"cost": 6, "kind": "product_speculation", "cash": 560, "price_delta": -42, "panic": 18, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "升级"], "text": "高阶做空：获得560资金，并制造更强临时供给压力；价格仍由供需关系结算。"},
	"城市买涨1": {"cost": 4, "kind": "city_gdp_derivative", "gdp_bet_direction": "up", "gdp_bet_multiplier": 1.0, "gdp_bet_turns": 2, "gdp_bet_destroy_bonus": 0, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "GDP", "买涨"], "text": "匿名买入选中城市GDP上涨：接下来2个经营周期，若该城市周期GDP高于买入基准，则按增量×1.0获得资金。"},
	"城市买涨2": {"cost": 6, "kind": "city_gdp_derivative", "gdp_bet_direction": "up", "gdp_bet_multiplier": 1.6, "gdp_bet_turns": 3, "gdp_bet_destroy_bonus": 0, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "GDP", "升级"], "text": "匿名买入选中城市GDP上涨：持续3个经营周期，收益为GDP增量×1.6。"},
	"城市买涨3": {"cost": 8, "kind": "city_gdp_derivative", "gdp_bet_direction": "up", "gdp_bet_multiplier": 2.3, "gdp_bet_turns": 3, "gdp_bet_destroy_bonus": 0, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "GDP", "终端"], "text": "高阶买涨城市GDP：持续3周期，若城市扩张、合约或商路使GDP上升，按增量×2.3兑现。"},
	"城市买涨4": {"cost": 10, "kind": "city_gdp_derivative", "gdp_bet_direction": "up", "gdp_bet_multiplier": 3.2, "gdp_bet_turns": 4, "gdp_bet_destroy_bonus": 0, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "GDP", "IV"], "text": "终端买涨城市GDP：持续4周期，收益为GDP增量×3.2；价格仍按I级购入价体系升级而来。"},
	"城市做空1": {"cost": 4, "kind": "city_gdp_derivative", "gdp_bet_direction": "down", "gdp_bet_multiplier": 1.0, "gdp_bet_turns": 2, "gdp_bet_destroy_bonus": 180, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "GDP", "做空"], "text": "匿名买入选中城市GDP下跌：接下来2个经营周期，若该城市GDP低于买入基准，则按跌幅×1.0获得资金；城市被毁会额外兑现破产奖励。"},
	"城市做空2": {"cost": 6, "kind": "city_gdp_derivative", "gdp_bet_direction": "down", "gdp_bet_multiplier": 1.7, "gdp_bet_turns": 3, "gdp_bet_destroy_bonus": 320, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "GDP", "升级"], "text": "高阶城市做空：持续3周期，收益为GDP跌幅×1.7；城市破产/摧毁额外兑现¥320。"},
	"城市做空3": {"cost": 8, "kind": "city_gdp_derivative", "gdp_bet_direction": "down", "gdp_bet_multiplier": 2.5, "gdp_bet_turns": 3, "gdp_bet_destroy_bonus": 520, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "GDP", "终端"], "text": "终端城市做空：持续3周期，怪兽破坏、商路断裂或区域经济衰退造成的GDP跌幅会按×2.5兑现。"},
	"城市做空4": {"cost": 10, "kind": "city_gdp_derivative", "gdp_bet_direction": "down", "gdp_bet_multiplier": 3.4, "gdp_bet_turns": 4, "gdp_bet_destroy_bonus": 760, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "GDP", "IV"], "text": "终端城市做空IV：持续4周期，GDP跌幅×3.4；城市摧毁时额外兑现¥760。"},
	"远期采购1": {"cost": 4, "kind": "product_contract_boon", "market_demand_pressure": 3, "market_contract_turns": 3, "cash": 120, "volatility_delta": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "合约"], "text": "围绕当前商品签远期采购：获得120资金，并为该商品追加持续3周期的需求压力+3；波动+1。"},
	"远期采购2": {"cost": 6, "kind": "product_contract_boon", "market_demand_pressure": 5, "market_contract_turns": 4, "cash": 260, "volatility_delta": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "升级"], "text": "签更大远期采购：获得260资金，并为当前商品追加持续4周期的需求压力+5；波动+1。"},
	"期货套保1": {"cost": 3, "kind": "product_contract_boon", "market_supply_pressure": 3, "market_contract_turns": 3, "cash": 90, "volatility_delta": -1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "套保"], "text": "围绕当前商品做期货套保：获得90资金，追加持续3周期的供给压力+3，并降低波动1。"},
	"期货套保2": {"cost": 5, "kind": "product_contract_boon", "market_supply_pressure": 5, "market_contract_turns": 4, "cash": 180, "volatility_delta": -2, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "升级"], "text": "高阶套保：获得180资金，追加持续4周期的供给压力+5，并降低波动2。"},
	"包销协议1": {"cost": 5, "kind": "product_contract_boon", "market_demand_pressure": 4, "market_contract_turns": 3, "route_flow_multiplier": 1.2, "route_flow_turns": 3, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "包销"], "text": "为当前商品签包销协议：持续3周期需求压力+4，并使该商品相关商路流通×1.20。"},
	"包销协议2": {"cost": 7, "kind": "product_contract_boon", "market_demand_pressure": 6, "market_contract_turns": 4, "route_flow_multiplier": 1.35, "route_flow_turns": 4, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "升级"], "text": "大型包销：持续4周期需求压力+6，并使该商品相关商路流通×1.35。"},
	"区域供需合约1": {"cost": 4, "kind": "area_trade_contract", "contract_product_mode": "selected", "contract_add_products": 1, "contract_add_demands": 1, "accept_cash": 90, "accept_transport_delta": 1, "accept_route_flow_multiplier": 1.18, "route_flow_turns": 3, "decline_cash_penalty": 70, "decline_consumption_delta": -1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["合约", "匿名"], "text": "打出前必须先在地图点选供给区与需求区。前5秒只向全员公开两端与条款；展示结束后，目标城市业主另有5秒签/拒窗口，其他玩家此时仍可继续出牌。签约会添加供给/需求并获得现金与物流改善，拒绝会承受罚款和消费降级。"},
	"区域供需合约2": {"cost": 6, "kind": "area_trade_contract", "contract_product_mode": "selected", "contract_add_products": 1, "contract_add_demands": 1, "contract_remove_products": 1, "contract_remove_demands": 1, "accept_cash": 160, "accept_transport_delta": 1, "accept_route_flow_multiplier": 1.32, "route_flow_turns": 4, "decline_cash_penalty": 120, "decline_transport_delta": -1, "decline_route_damage": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["合约", "换线"], "text": "打出前必须先点选供给区与需求区。前5秒只公开换线两端和条款；展示结束后，目标业主另有5秒签/拒窗口。签约时供给区/需求区各删除一项旧商品并接入当前商品；拒绝会带来罚款、交通降级和断路压力。"},
	"组合供需合约1": {"cost": 7, "kind": "area_trade_contract", "contract_product_mode": "multi", "contract_add_products": 2, "contract_add_demands": 2, "accept_cash": 210, "accept_production_delta": 1, "accept_transport_delta": 1, "accept_route_flow_multiplier": 1.45, "route_flow_turns": 4, "decline_cash_penalty": 160, "decline_production_delta": -1, "decline_consumption_delta": -1, "decline_route_damage": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["合约", "多商品"], "text": "打出前必须先点选供给区与需求区。前5秒向全员公开要接通的两端、多商品条款和奖惩；展示结束后，目标业主另有5秒签/拒窗口。签约奖励现金、生产和商路速度，拒签会拖慢生产/需求并追加商路压力。"},
	"自动撮合合约1": {"cost": 5, "kind": "area_trade_contract", "contract_product_mode": "auto", "contract_add_products": 1, "contract_add_demands": 1, "accept_cash": 110, "accept_transport_delta": 1, "accept_consumption_delta": 1, "accept_route_flow_multiplier": 1.22, "route_flow_turns": 3, "decline_cash_penalty": 80, "decline_route_damage": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["合约", "自动"], "text": "匿名平台自动撮合供给区与需求区：不锁定当前选中商品，而是从两端现有供需中自动挑选可接通商品。签约奖励现金、交通与消费；拒签会留下断路压力。"},
	"环晶电池专供1": {"cost": 5, "kind": "area_trade_contract", "contract_product_mode": "fixed", "contract_products": ["环晶电池"], "contract_add_products": 1, "contract_add_demands": 1, "accept_cash": 130, "accept_production_delta": 1, "accept_route_flow_multiplier": 1.20, "route_flow_turns": 3, "decline_cash_penalty": 95, "decline_consumption_delta": -1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["合约", "指定商品"], "text": "指定环晶电池专供条款：供给区和需求区围绕环晶电池接入生产/需求。签约提高生产和相关流通，拒签会削弱消费并支付罚款。"},
	"双边对冲合约1": {"cost": 6, "kind": "area_trade_contract", "contract_product_mode": "multi", "contract_add_products": 2, "contract_add_demands": 2, "contract_remove_products": 1, "contract_remove_demands": 1, "accept_cash": 150, "accept_transport_delta": 1, "accept_route_flow_multiplier": 1.30, "route_flow_turns": 4, "decline_cash_penalty": 130, "decline_production_delta": -1, "decline_route_damage": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["合约", "对冲"], "text": "双商品对冲合约：签约时两端各接入两项商品，并替换一项旧供需以重排经营结构；拒签会压低生产并追加商路压力。"},
	"惩罚性拒签条款1": {"cost": 6, "kind": "area_trade_contract", "contract_product_mode": "auto", "contract_add_products": 1, "contract_add_demands": 1, "accept_cash": 70, "accept_transport_delta": 1, "accept_route_flow_multiplier": 1.16, "route_flow_turns": 2, "decline_cash_penalty": 180, "decline_production_delta": -1, "decline_transport_delta": -1, "decline_consumption_delta": -1, "decline_route_damage": 2, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["合约", "惩罚"], "text": "强压式匿名条款：签约收益较低但可接通自动撮合商品；拒签会触发高额罚款，并同时拖慢生产、交通、消费和商路。"},
	"商品换线1": {"cost": 4, "kind": "city_product_shift", "product_shift": 1, "revenue_amount": 18, "panic": 6, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "换线"], "text": "选中己方城市：将1项主营商品换成当前商路商品或未经营商品，并使周期收入+18。"},
	"商品换线2": {"cost": 6, "kind": "city_product_shift", "product_shift": 2, "revenue_amount": 32, "panic": 10, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "升级"], "text": "选中己方城市：将2项主营商品换成新的商品线，并使周期收入+32。"},
	"需求改造1": {"cost": 3, "kind": "city_demand_shift", "demand_shift": 1, "repair_routes": 1, "revenue_amount": 10, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "需求"], "text": "选中己方城市：改造1项需求商品，优先对接当前商路商品，并清除1条断路压力。"},
	"需求改造2": {"cost": 5, "kind": "city_demand_shift", "demand_shift": 2, "repair_routes": 1, "revenue_amount": 22, "panic": 4, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "升级"], "text": "选中己方城市：改造2项需求商品，刷新商路并清除1条断路压力，周期收入+22。"},
	"产业升级1": {"cost": 4, "kind": "city_product_upgrade", "product_level": 1, "revenue_amount": 25, "panic": 4, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "升级"], "text": "选中己方城市：最低等级商品+1级，并使周期收入+25。"},
	"产业升级2": {"cost": 7, "kind": "city_product_upgrade", "product_level": 2, "revenue_amount": 45, "panic": 8, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "终端"], "text": "选中己方城市：最低等级商品+2级，并使周期收入+45。"},
	"市场稳定1": {"cost": 3, "kind": "market_stabilize", "stabilize_amount": 24, "volatility_delta": -2, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "稳定"], "text": "削减当前商品的临时供需压力，并降低后续波动；价格仍由供需重算。"},
	"商路黑客1": {"cost": 4, "kind": "route_sabotage", "route_damage": 1, "panic": 16, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "破坏"], "text": "选中任意公开城市群：追加1条商路损伤压力；真实业主仍不公开。"},
	"商路黑客2": {"cost": 7, "kind": "route_sabotage", "route_damage": 2, "panic": 26, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "升级"], "text": "选中任意公开城市群：追加2条商路损伤压力，并显著升高当地热度。"},
	"商品催化1": {"cost": 4, "kind": "product_growth_boon", "growth_multiplier": 2.0, "growth_turns": 3, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "催化"], "text": "当前商品接下来3个经营周期的正向价格增速×2。"},
	"商品催化2": {"cost": 6, "kind": "product_growth_boon", "growth_multiplier": 2.5, "growth_turns": 4, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经济", "升级"], "text": "当前商品接下来4个经营周期的正向价格增速×2.5。"},
	"星港快线1": {"cost": 4, "kind": "route_flow_boon", "route_flow_multiplier": 1.45, "route_flow_turns": 3, "repair_routes": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "物流"], "text": "选中己方城市：清除1条断路压力，并使已满足需求商路流通收入×1.45，持续3周期。"},
	"星港快线2": {"cost": 6, "kind": "route_flow_boon", "route_flow_multiplier": 1.8, "route_flow_turns": 4, "repair_routes": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["经营", "升级"], "text": "选中己方城市：清除1条断路压力，并使已满足需求商路流通收入×1.8，持续4周期。"},
	"生产扩张1": {"cost": 4, "kind": "region_economy_shift", "production_delta": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["区域", "生产"], "text": "选中区域商品生产水平+1。生产型GDP会按可外运商品流动量提高。"},
	"产能封锁1": {"cost": 4, "kind": "region_economy_shift", "production_delta": -1, "panic": 10, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["区域", "破坏"], "text": "选中区域商品生产水平-1，并提高当地热度。用于压低对手生产型GDP。"},
	"交通升级1": {"cost": 4, "kind": "region_economy_shift", "transport_delta": 1, "repair_routes": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["区域", "交通"], "text": "选中区域公共交通水平+1，并尝试修复1点商路压力。商品流动速度与过境GDP会提高。"},
	"交通瘫痪1": {"cost": 4, "kind": "region_economy_shift", "transport_delta": -1, "route_damage": 1, "panic": 12, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["区域", "破坏"], "text": "选中区域公共交通水平-1，并追加1点商路压力。商品流动速度与过境GDP会下降。"},
	"消费刺激1": {"cost": 4, "kind": "region_economy_shift", "consumption_delta": 1, "market_demand_pressure": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["区域", "消费"], "text": "选中区域商品消费水平+1，并为当前商品制造少量需求压力。消费型GDP会提高。"},
	"消费冷却1": {"cost": 4, "kind": "region_economy_shift", "consumption_delta": -1, "market_supply_pressure": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["区域", "压制"], "text": "选中区域商品消费水平-1，并制造少量供给侧压力。用于压低消费型GDP。"},
	"共生红利1": {"cost": 5, "kind": "product_growth_boon", "growth_multiplier": 1.7, "route_flow_multiplier": 1.3, "growth_turns": 3, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["怪兽", "经济"], "text": "利用怪兽带来的异星需求：当前商品正向增速×1.7，相关商品商路流通×1.3，持续3周期。"},
	"共生红利2": {"cost": 7, "kind": "product_growth_boon", "growth_multiplier": 2.2, "route_flow_multiplier": 1.55, "growth_turns": 4, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["怪兽", "升级"], "text": "高阶共生经济：当前商品正向增速×2.2，相关商品商路流通×1.55，持续4周期。"},
	"远程挑衅1": {"cost": 2, "kind": "monster_lure", "lure_speedup": 2.0, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["诱导", "低费"], "text": "指定一只怪兽：它下一次自动移动优先朝当前选区推进，并提前最多2秒触发。"},
	"连锁过载1": {"cost": 6, "kind": "supply_draw", "draw_amount": 2, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["构筑", "爆发"], "text": "从当前区域额外获取2张候选卡，用于一轮内连锁补给。"},
	"移动1": {"cost": 2, "kind": "move", "damage": 0, "move": 180.0, "range": 0.0, "text": "指挥怪兽移动约180米，进入区域造成1点区域伤害。"},
	"移动2": {"cost": 4, "kind": "move", "damage": 0, "move": 280.0, "range": 0.0, "text": "指挥怪兽最多移动约280米。"},
	"移动3": {"cost": 6, "kind": "move", "damage": 0, "move": 380.0, "range": 0.0, "tags": ["机动", "终端"], "text": "高阶移动，指挥怪兽最多移动约380米。"},
	"普攻1": {"cost": 2, "kind": "attack", "damage": 1, "move": 0.0, "range": 110.0, "knockback": 120.0, "tags": ["攻击", "击退"], "text": "近战AOE约110米，对其他怪兽造成1点伤害并击退约120米。"},
	"普攻2": {"cost": 4, "kind": "attack", "damage": 2, "move": 0.0, "range": 110.0, "knockback": 120.0, "tags": ["攻击", "击退"], "text": "近战AOE约110米，对其他怪兽造成2点伤害并击退约120米。"},
	"普攻3": {"cost": 6, "kind": "attack", "damage": 3, "move": 0.0, "range": 110.0, "knockback": 220.0, "tags": ["攻击", "终端", "击退"], "text": "近战AOE约110米，对其他怪兽造成3点伤害并击退约220米。"},
	"格挡1": {"cost": 2, "kind": "guard", "guard": 2, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["防御", "反应"], "text": "进入格挡姿态，下一次其他怪兽伤害-2。"},
	"格挡2": {"cost": 4, "kind": "guard", "guard": 3, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["防御", "升级"], "text": "强化格挡，下一次其他怪兽伤害-3。"},
	"格挡3": {"cost": 6, "kind": "guard", "guard": 4, "ranged_guard": 2, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["防御", "终端"], "text": "终端格挡，下一次其他怪兽伤害-4，并额外形成远程抗性。"},
	"区域破坏1": {"cost": 2, "kind": "area_damage", "damage": 1, "move": 0.0, "range": 180.0, "text": "对180米内区域造成1点区域伤害。"},
	"区域破坏2": {"cost": 5, "kind": "area_damage", "damage": 2, "move": 0.0, "range": 180.0, "tags": ["破坏", "升级"], "text": "对180米内区域造成2点伤害，作为区域破坏升级牌。"},
	"区域破坏3": {"cost": 8, "kind": "area_damage", "damage": 3, "move": 0.0, "range": 300.0, "tags": ["破坏", "终端"], "text": "对300米内区域造成3点伤害，适合终结高价值区域。"},
	"破碎地脉1": {"cost": 4, "kind": "area_damage", "damage": 1, "move": 0.0, "range": 260.0, "tags": ["破坏", "AOE"], "text": "对260米内区域造成1点伤害，兼顾范围与费用。"},
	"破碎地脉2": {"cost": 7, "kind": "area_damage", "damage": 2, "move": 0.0, "range": 280.0, "tags": ["破坏", "升级"], "text": "对280米内区域造成2点伤害，形成中距离破坏升级路线。"},
	"远距破坏1": {"cost": 5, "kind": "area_damage", "damage": 1, "move": 0.0, "range": 420.0, "tags": ["破坏", "远程"], "text": "对420米内区域造成1点伤害，适合不想贴近目标的路线。"},
	"飞行1": {"cost": 3, "kind": "fly", "damage": 0, "move": 650.0, "range": 0.0, "text": "飞行突进最多650米。"},
	"飞行2": {"cost": 6, "kind": "fly", "damage": 0, "move": 760.0, "range": 0.0, "text": "飞行突进最多760米，冷却更长但更适合后期牌池。"},
	"龙车1": {"cost": 3, "kind": "charge_attack", "damage": 3, "move": 320.0, "range": 110.0, "knockback": 320.0, "tags": ["冲撞", "击退"], "text": "向其他怪兽冲刺320米，并在110米近战圈造成3点伤害，命中后直线击退约320米。"},
	"龙车2": {"cost": 6, "kind": "charge_attack", "damage": 3, "move": 380.0, "range": 110.0, "knockback": 320.0, "tags": ["冲撞", "升级", "击退"], "text": "向其他怪兽冲刺380米并造成3点近战伤害，命中后直线击退约320米。"},
	"龙车3": {"cost": 8, "kind": "charge_attack", "damage": 5, "move": 440.0, "range": 120.0, "knockback": 420.0, "delay": 1.0, "tags": ["冲撞", "终端", "击退"], "text": "强力龙车，冲刺440米并在120米近战圈造成5点伤害；命中后击退约420米并短暂硬直其他怪兽。"},
	"甩尾1": {"cost": 2, "kind": "attack", "damage": 2, "move": 0.0, "range": 130.0, "knockback": 320.0, "tags": ["攻击", "击退"], "text": "130米尾击AOE造成2点伤害，并把其他怪兽击退约320米。"},
	"甩尾2": {"cost": 4, "kind": "attack", "damage": 2, "move": 0.0, "range": 160.0, "knockback": 320.0, "tags": ["攻击", "升级", "击退"], "text": "160米尾击AOE造成2点伤害，并把其他怪兽击退约320米。"},
	"装甲再生1": {"cost": 3, "kind": "armor_gain", "armor": 3, "damage": 0, "move": 0, "range": 0, "tags": ["防御", "续航"], "text": "怪兽立即获得3点护甲，抵消后续其他怪兽伤害。"},
	"装甲再生2": {"cost": 6, "kind": "armor_gain", "armor": 7, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["防御", "升级"], "text": "怪兽立即获得7点护甲，支撑高压路线继续推进。"},
	"瘴气炮1": {"cost": 4, "kind": "miasma_shot", "damage": 1, "move": 0.0, "range": 420.0, "miasma_count": 2, "text": "420米远程瘴气炮造成1点伤害，并沿路径留下瘴气。"},
	"瘴气炮2": {"cost": 6, "kind": "miasma_shot", "damage": 3, "move": 0.0, "range": 520.0, "miasma_count": 3, "tags": ["瘴气", "升级"], "text": "520米高阶瘴气炮造成3点伤害，并沿路径留下更多瘴气。"},
	"瘴气结界1": {"cost": 3, "kind": "miasma_bloom", "damage": 0, "move": 0.0, "range": 220.0, "miasma_count": 4, "tags": ["瘴气", "区域"], "text": "在怪兽周边或选中区域220米AOE内布置至多4枚瘴气。"},
	"瘴气结界2": {"cost": 6, "kind": "miasma_bloom", "damage": 0, "move": 0.0, "range": 260.0, "miasma_count": 4, "tags": ["瘴气", "升级"], "text": "高阶瘴气结界，在260米AOE内布置至多4枚瘴气。"},
	"瘴气爆发1": {"cost": 4, "kind": "miasma_bloom", "damage": 0, "move": 0.0, "range": 220.0, "miasma_count": 3, "text": "在选中区域220米AOE内散布至多3枚瘴气。"},
	"瘴气爆发2": {"cost": 6, "kind": "miasma_bloom", "damage": 0, "move": 0.0, "range": 260.0, "miasma_count": 5, "tags": ["瘴气", "升级"], "text": "在选中区域260米AOE内散布至多5枚瘴气，作为瘴气爆发升级牌。"},
	"瘴气回收1": {"cost": 2, "kind": "miasma_reclaim", "damage": 1, "move": 0.0, "range": 180.0, "reclaim_count": 1, "text": "回收怪兽180米内1枚瘴气并回复1HP；若其他怪兽靠近则追加伤害。"},
	"瘴气回收2": {"cost": 4, "kind": "miasma_reclaim", "damage": 1, "move": 0.0, "range": 240.0, "reclaim_count": 2, "tags": ["瘴气", "续航"], "text": "回收怪兽240米内最多2枚瘴气，每枚回复1HP；其他怪兽靠近则追加伤害。"},
	"瘴气回收3": {"cost": 6, "kind": "miasma_reclaim", "damage": 1, "move": 0.0, "range": 320.0, "reclaim_count": 8, "tags": ["瘴气", "终端"], "text": "终端回收，移除320米内至多8枚瘴气，每枚回复1HP；其他怪兽靠近时按回收量追加伤害。"},
	"腐蚀吐息1": {"cost": 5, "kind": "corrosive_breath", "damage": 2, "move": 0.0, "range": 420.0, "miasma_count": 2, "tags": ["瘴气", "远程"], "text": "420米内对其他怪兽造成2点伤害，并在选中区域周围留下2枚瘴气。"},
	"咆哮1": {"cost": 3, "kind": "roar", "damage": 0, "move": 0.0, "range": 450.0, "delay": 1.5, "text": "450米AOE内硬直其他怪兽，延后下一次其他怪兽概率行动。"},
	"咆哮2": {"cost": 6, "kind": "roar", "damage": 0, "move": 0.0, "range": 520.0, "delay": 3.0, "text": "520米AOE内强力硬直其他怪兽，大幅延后下一次其他怪兽概率行动。"},
	"地底潜行1": {"cost": 3, "kind": "burrow", "damage": 0, "move": 340.0, "range": 0.0, "armor": 2, "text": "潜行移动340米，怪兽获得2点护甲。"},
	"地底潜行2": {"cost": 6, "kind": "burrow", "damage": 0, "move": 420.0, "range": 0.0, "armor": 2, "text": "潜行移动420米，怪兽获得2点护甲，作为升级潜行牌。"},
	"地底潜行3": {"cost": 9, "kind": "burrow", "damage": 0, "move": 520.0, "range": 0.0, "armor": 3, "text": "潜行移动520米，怪兽获得3点护甲。"},
	"打滚1": {"cost": 3, "kind": "roll_attack", "damage": 2, "move": 260.0, "range": 120.0, "text": "向选中区域翻滚260米，落点造成区域伤害；若120米内贴近其他怪兽则造成2点伤害。"},
	"打滚2": {"cost": 6, "kind": "roll_attack", "damage": 3, "move": 380.0, "range": 130.0, "tags": ["冲撞", "升级"], "text": "高阶打滚，向选中区域翻滚380米；落点造成区域伤害，130米内命中其他怪兽造成3点伤害。"},
	"狂奔1": {"cost": 3, "kind": "roll_attack", "damage": 2, "move": 340.0, "range": 120.0, "tags": ["冲撞", "机动"], "text": "向选中区域高速狂奔340米；120米内贴近其他怪兽则造成2点伤害。"},
	"狂奔2": {"cost": 6, "kind": "roll_attack", "damage": 3, "move": 460.0, "range": 130.0, "tags": ["冲撞", "升级"], "text": "向选中区域高速狂奔460米；130米内贴近其他怪兽则造成3点伤害。"},
	"泥甲1": {"cost": 3, "kind": "armor_gain", "armor": 4, "damage": 0, "move": 0, "range": 0, "tags": ["护甲", "土砂龙"], "text": "怪兽立即获得4点护甲，适合冲撞构筑续航。"},
	"泥石流1": {"cost": 4, "kind": "mudslide", "damage": 1, "panic": 24, "delay": 1.2, "move": 0.0, "range": 220.0, "tags": ["破坏", "控场"], "text": "220米AOE内区域受到1点伤害并热度+24；若其他怪兽在AOE内，延后其行动。"},
	"火花反制1": {"cost": 4, "kind": "special_monster_delay", "delay": 2.0, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["机械杰克", "控场"], "text": "抓住火花电击前摇，指定怪兽的特殊行动节奏延后2秒。"},
	"斯派修姆锁定1": {"cost": 4, "kind": "panic_shift", "panic": 22, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["机械杰克", "引导"], "text": "把斯派修姆交火引向选中区域，热度+22，提高怪兽关注。"},
	"奥特空投诱导1": {"cost": 5, "kind": "mudslide", "damage": 1, "panic": 18, "delay": 2.0, "move": 0.0, "range": 180.0, "tags": ["机械杰克", "破坏"], "text": "诱导奥特空投落点，180米AOE内区域受1点伤害；若其他怪兽靠近则延后行动。"},
	"流星航线加速1": {"cost": 5, "kind": "route_flow_boon", "route_flow_multiplier": 1.65, "route_flow_turns": 3, "repair_routes": 1, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["机械杰克", "物流"], "text": "借机械杰克高速巡航开通流星航线：选中己方城市商路流通收入×1.65，持续3周期，并修复1条断路压力。"},
	"断头刀预判1": {"cost": 4, "kind": "special_monster_delay", "delay": 2.5, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["机械艾斯", "控场"], "text": "读出断头刀轨迹，指定怪兽的特殊行动节奏延后2.5秒。"},
	"电击踢破绽1": {"cost": 4, "kind": "supply_draw", "draw_amount": 2, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["机械艾斯", "补给"], "text": "利用电击踢收招破绽，从当前区域额外获取2张候选卡。"},
	"垂直断头刀窗口1": {"cost": 4, "kind": "armor_gain", "armor": 5, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["机械艾斯", "防御"], "text": "在垂直断头刀命中窗口前缩身防御，怪兽立即获得5点护甲。"},
	"修复光线干扰1": {"cost": 4, "kind": "mudslide", "damage": 1, "panic": 18, "delay": 1.5, "move": 0.0, "range": 260.0, "tags": ["纳伊斯", "破坏"], "text": "污染修复光线的落点，260米AOE内区域受1点伤害并升温；其他怪兽靠近时被延后。"},
	"定身闪光余波1": {"cost": 3, "kind": "special_monster_delay", "delay": 3.0, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["纳伊斯", "控场"], "text": "借定身闪光余波制造短暂空档，其他怪兽概率行动延后3秒。"},
	"修正铁拳读秒1": {"cost": 4, "kind": "monster_lure", "lure_speedup": 4.0, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["纳伊斯", "诱导"], "text": "读出修正铁拳冲线时间，指定怪兽下一次自动移动优先朝当前选区推进，并提前最多4秒触发。"},
	"修复光线招商1": {"cost": 5, "kind": "route_flow_boon", "route_flow_multiplier": 1.75, "route_flow_turns": 3, "repair_routes": 2, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["纳伊斯", "招商"], "text": "把纳伊斯修复光线包装成招商窗口：选中己方城市商路流通收入×1.75，持续3周期，并修复2条断路压力。"},
	"梦比姆能量诱导1": {"cost": 4, "kind": "special_monster_delay", "delay": 1.8, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["梦比优斯", "控场"], "text": "诱导梦比姆能量过早爆发，指定怪兽的特殊行动节奏延后1.8秒。"},
	"飞踢落点预判1": {"cost": 4, "kind": "mudslide", "damage": 1, "panic": 20, "delay": 1.2, "move": 0.0, "range": 220.0, "tags": ["梦比优斯", "破坏"], "text": "预判飞踢落点，220米AOE内区域受1点伤害并升温；其他怪兽靠近时被延后。"},
	"梦比姆火焰护甲1": {"cost": 4, "kind": "armor_gain", "armor": 5, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["梦比优斯", "防御"], "text": "利用梦比姆火焰前摇缩身防御，怪兽立即获得5点护甲。"},
	"梦比姆能源热潮1": {"cost": 5, "kind": "product_growth_boon", "growth_multiplier": 2.3, "route_flow_multiplier": 1.2, "growth_turns": 3, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["梦比优斯", "能源"], "text": "把梦比姆能量转成商品热潮：当前商品正向价格增速×2.3、相关商路流通×1.2，持续3周期。"},
	"复仇之铠过载1": {"cost": 4, "kind": "special_monster_delay", "delay": 2.0, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["希卡利", "控场"], "text": "扰乱复仇之铠的能量回路，指定怪兽的特殊行动节奏延后2秒。"},
	"热负荷射线诱导1": {"cost": 4, "kind": "mudslide", "damage": 1, "panic": 24, "delay": 1.5, "move": 0.0, "range": 260.0, "tags": ["希卡利", "破坏"], "text": "诱导热负荷射线扫过城区，260米AOE内区域受1点伤害并升温；其他怪兽靠近时被延后。"},
	"骑士光刃窗口1": {"cost": 4, "kind": "armor_gain", "armor": 6, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["希卡利", "防御"], "text": "利用骑士光刃收招窗口缩身防御，怪兽立即获得6点护甲。"},
	"骑士专利授权1": {"cost": 5, "kind": "product_growth_boon", "growth_multiplier": 2.0, "route_flow_multiplier": 1.35, "growth_turns": 4, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["希卡利", "专利"], "text": "开放希卡利科技专利：当前商品正向价格增速×2、相关商路流通×1.35，持续4周期。"},
	"完美格挡破绽1": {"cost": 4, "kind": "special_monster_delay", "delay": 2.0, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["艾斯杀手", "控场"], "text": "骗出完美格挡的空档，指定怪兽的特殊行动节奏延后2秒。"},
	"混乱光线诱导1": {"cost": 5, "kind": "mudslide", "damage": 1, "panic": 28, "delay": 1.4, "move": 0.0, "range": 300.0, "tags": ["艾斯杀手", "破坏"], "text": "诱导混乱光线扫过城区，300米AOE内区域受1点伤害并升温；其他怪兽靠近时被延后。"},
	"迂回路线封锁1": {"cost": 4, "kind": "monster_lure", "lure_speedup": 4.5, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["艾斯杀手", "诱导"], "text": "封锁艾斯杀手的迂回路线，指定怪兽下一次自动移动优先朝当前选区推进，并提前最多4.5秒触发。"},
}

const UPGRADEABLE_SKILL_FAMILIES := [
	"城市融资",
	"星际广告",
	"轨道融资",
	"舆论操控",
	"诱导电波",
	"过载补给",
	"商业诱饵",
	"价格套利",
	"商品做空",
	"城市买涨",
	"城市做空",
	"商品换线",
	"需求改造",
	"供应链保险",
	"产业升级",
	"商路黑客",
	"短期订单",
	"军需临单",
	"星际会展",
	"远期采购",
	"期货套保",
	"包销协议",
	"区域供需合约",
	"组合供需合约",
	"自动撮合合约",
	"环晶电池专供",
	"双边对冲合约",
	"惩罚性拒签条款",
	"商品催化",
	"星港快线",
	"共生红利",
	"移动",
	"普攻",
	"格挡",
	"区域破坏",
	"破碎地脉",
	"飞行",
	"龙车",
	"甩尾",
	"装甲再生",
	"瘴气炮",
	"瘴气结界",
	"瘴气爆发",
	"瘴气回收",
	"咆哮",
	"地底潜行",
	"打滚",
	"狂奔",
]

const COMMON_CARD_POOL := [
	"城市融资1",
	"城市融资2",
	"城市融资3",
	"星际广告1",
	"星际广告2",
	"星际广告3",
	"轨道融资1",
	"轨道融资2",
	"地下融资1",
	"舆论操控1",
	"舆论操控2",
	"热搜推送1",
	"诱导电波1",
	"诱导电波2",
	"远程挑衅1",
	"夺取怪兽1",
	"过载补给1",
	"过载补给2",
	"连锁过载1",
	"业主透镜1",
	"业主透镜2",
	"出牌追帧1",
	"出牌追帧2",
	"密约回溯1",
	"密约回溯2",
	"远程补给链1",
	"星门采购权1",
	"商业诱饵1",
	"商业诱饵2",
	"价格套利1",
	"价格套利2",
	"供应链保险1",
	"供应链保险2",
	"垄断协议1",
	"需求创造1",
	"短期订单1",
	"短期订单2",
	"军需临单1",
	"军需临单2",
	"星际会展1",
	"星际会展2",
	"商品做空1",
	"商品做空2",
	"城市买涨1",
	"城市买涨2",
	"城市做空1",
	"城市做空2",
	"远期采购1",
	"远期采购2",
	"期货套保1",
	"期货套保2",
	"包销协议1",
	"包销协议2",
	"区域供需合约1",
	"区域供需合约2",
	"组合供需合约1",
	"自动撮合合约1",
	"环晶电池专供1",
	"双边对冲合约1",
	"惩罚性拒签条款1",
	"商品换线1",
	"商品换线2",
	"需求改造1",
	"需求改造2",
	"产业升级1",
	"产业升级2",
	"市场稳定1",
	"商路黑客1",
	"商路黑客2",
	"商品催化1",
	"商品催化2",
	"星港快线1",
	"星港快线2",
	"生产扩张1",
	"产能封锁1",
	"交通升级1",
	"交通瘫痪1",
	"消费刺激1",
	"消费冷却1",
	"共生红利1",
	"共生红利2",
	"移动2",
	"移动3",
	"普攻2",
	"普攻3",
	"格挡1",
	"格挡2",
	"格挡3",
	"区域破坏1",
	"区域破坏2",
	"区域破坏3",
	"破碎地脉1",
	"破碎地脉2",
	"远距破坏1",
	"飞行1",
	"装甲再生1",
	"装甲再生2",
]

const MARKET_SKILLS := [
	"城市融资1",
	"星际广告1",
	"轨道融资1",
	"轨道融资2",
	"地下融资1",
	"舆论操控1",
	"舆论操控2",
	"热搜推送1",
	"诱导电波1",
	"诱导电波2",
	"远程挑衅1",
	"夺取怪兽1",
	"过载补给1",
	"过载补给2",
	"连锁过载1",
	"商业诱饵1",
	"商业诱饵2",
	"价格套利1",
	"价格套利2",
	"供应链保险1",
	"供应链保险2",
	"垄断协议1",
	"需求创造1",
	"短期订单1",
	"短期订单2",
	"军需临单1",
	"军需临单2",
	"星际会展1",
	"星际会展2",
	"商品做空1",
	"商品做空2",
	"城市买涨1",
	"城市买涨2",
	"城市做空1",
	"城市做空2",
	"远期采购1",
	"远期采购2",
	"期货套保1",
	"期货套保2",
	"包销协议1",
	"包销协议2",
	"区域供需合约1",
	"区域供需合约2",
	"组合供需合约1",
	"自动撮合合约1",
	"环晶电池专供1",
	"双边对冲合约1",
	"惩罚性拒签条款1",
	"商品换线1",
	"商品换线2",
	"需求改造1",
	"需求改造2",
	"产业升级1",
	"产业升级2",
	"市场稳定1",
	"商路黑客1",
	"商路黑客2",
	"商品催化1",
	"商品催化2",
	"星港快线1",
	"星港快线2",
	"生产扩张1",
	"产能封锁1",
	"交通升级1",
	"交通瘫痪1",
	"消费刺激1",
	"消费冷却1",
	"共生红利1",
	"共生红利2",
	"移动2",
	"移动3",
	"普攻2",
	"普攻3",
	"格挡1",
	"格挡2",
	"区域破坏1",
	"区域破坏2",
	"破碎地脉1",
	"破碎地脉2",
	"远距破坏1",
	"飞行1",
	"龙车1",
	"甩尾1",
	"装甲再生1",
	"装甲再生2",
	"瘴气炮1",
	"地底潜行1",
]

const MONSTER_ROSTER := [
	{
		"name": "尸套龙",
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
		"market_skills": ["城市融资1", "城市融资2", "城市融资3", "星际广告1", "星际广告2", "星际广告3", "轨道融资1", "舆论操控1", "诱导电波1", "过载补给1", "移动2", "移动3", "普攻2", "普攻3", "格挡1", "格挡2", "区域破坏1", "区域破坏2", "区域破坏3", "飞行1", "飞行2", "龙车1", "龙车2", "甩尾1", "甩尾2", "装甲再生1", "瘴气炮1", "瘴气炮2", "瘴气结界1", "瘴气结界2", "瘴气爆发1", "瘴气爆发2", "瘴气回收1", "瘴气回收2", "瘴气回收3", "腐蚀吐息1"],
	},
	{
		"name": "土砂龙",
		"hp": 40,
		"armor": 2,
		"move": 220.0,
		"move_damage": 2,
		"collision_damage": 2,
		"resource_drain": 1,
		"style": "冲撞护甲型：初始护甲更高，会用龙车、潜行和泥石流冲散城区。",
		"resource_focus": ["重力陶瓷", "钛壳贝", "虹膜矿粉"],
		"summon_access": "land_monster_zone",
		"economy_boon": {"label": "地壳矿带开采潮", "growth_multiplier": 1.45, "route_flow_multiplier": 1.15, "text": "偏好矿物商品获得开采热潮：正向价格增速×1.45，相关商路流通×1.15。"},
		"market_skills": ["城市融资1", "城市融资2", "城市融资3", "星际广告1", "星际广告2", "星际广告3", "轨道融资1", "舆论操控1", "诱导电波1", "过载补给1", "移动2", "移动3", "普攻2", "普攻3", "格挡1", "格挡2", "格挡3", "区域破坏1", "区域破坏2", "区域破坏3", "龙车1", "龙车2", "龙车3", "甩尾1", "甩尾2", "装甲再生1", "咆哮1", "咆哮2", "地底潜行1", "地底潜行2", "地底潜行3", "打滚1", "打滚2", "狂奔2", "泥甲1", "泥石流1"],
	},
	{
		"name": "机械杰克",
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
		"special_cards": ["火花反制1", "斯派修姆锁定1", "奥特空投诱导1", "流星航线加速1"],
	},
	{
		"name": "机械艾斯",
		"hp": 45,
		"move": 280.0,
		"move_damage": 1,
		"collision_damage": 2,
		"resource_drain": 1,
		"style": "重装火力型：生命更高，但追击速度较慢。",
		"resource_focus": ["离子香料", "静电蜂蜜", "等离子米"],
		"summon_access": "land_monster_zone",
		"economy_boon": {"label": "军需采购波", "growth_multiplier": 1.55, "route_flow_multiplier": 1.1, "text": "偏好能量食品被军需采购推高：正向价格增速×1.55，相关商路流通×1.1。"},
		"special_cards": ["断头刀预判1", "电击踢破绽1", "垂直断头刀窗口1"],
	},
	{
		"name": "纳伊斯",
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
		"name": "梦比优斯",
		"hp": 45,
		"move": 300.0,
		"move_damage": 1,
		"collision_damage": 2,
		"resource_drain": 1,
		"style": "近战爆发型：HP降至15或以下后启动梦比姆能量，移动更快且近战互伤会追加火焰。",
		"resource_focus": ["太阳鳞片", "火山番茄", "彗尾柑"],
		"summon_access": "land_monster_zone",
		"economy_boon": {"label": "梦比姆能源热潮", "growth_multiplier": 2.0, "route_flow_multiplier": 1.15, "text": "偏好高能商品被战场能源需求点燃：正向价格增速×2，相关商路流通×1.15。"},
		"special_cards": ["梦比姆能量诱导1", "飞踢落点预判1", "梦比姆火焰护甲1", "梦比姆能源热潮1"],
	},
	{
		"name": "希卡利",
		"hp": 50,
		"move": 360.0,
		"move_damage": 1,
		"collision_damage": 2,
		"resource_drain": 1,
		"style": "复仇装甲型：HP降至20或以下后穿上复仇之铠，减伤、增伤，并在移动时破坏城区。",
		"resource_focus": ["极光盐", "离岸水晶", "晨昏奶酪"],
		"summon_access": "monster_zone",
		"economy_boon": {"label": "骑士专利授权", "growth_multiplier": 1.65, "route_flow_multiplier": 1.35, "text": "偏好晶体/精密商品获得科技授权：正向价格增速×1.65，相关商路流通×1.35。"},
		"special_cards": ["复仇之铠过载1", "热负荷射线诱导1", "骑士光刃窗口1", "骑士专利授权1"],
	},
	{
		"name": "艾斯杀手",
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
	"尸套龙": {
		"accent": Color("#a855f7"),
		"secondary": Color("#4ade80"),
		"glyph": "瘴",
		"motif": "miasma",
		"subtitle": "瘴气古龙｜临时美工",
	},
	"土砂龙": {
		"accent": Color("#d97706"),
		"secondary": Color("#facc15"),
		"glyph": "砂",
		"motif": "mud",
		"subtitle": "冲撞泥甲｜临时美工",
	},
	"机械杰克": {
		"accent": Color("#38bdf8"),
		"secondary": Color("#f87171"),
		"glyph": "杰",
		"motif": "jack",
		"subtitle": "高速机械战士｜临时美工",
	},
	"机械艾斯": {
		"accent": Color("#60a5fa"),
		"secondary": Color("#f472b6"),
		"glyph": "断",
		"motif": "ace",
		"subtitle": "重装断头刀｜临时美工",
	},
	"纳伊斯": {
		"accent": Color("#22c55e"),
		"secondary": Color("#93c5fd"),
		"glyph": "修",
		"motif": "nice",
		"subtitle": "防守救援型｜临时美工",
	},
	"梦比优斯": {
		"accent": Color("#fb7185"),
		"secondary": Color("#f97316"),
		"glyph": "炎",
		"motif": "mebius",
		"subtitle": "梦比姆火焰｜临时美工",
	},
	"希卡利": {
		"accent": Color("#06b6d4"),
		"secondary": Color("#818cf8"),
		"glyph": "刃",
		"motif": "hikari",
		"subtitle": "复仇光刃｜临时美工",
	},
	"艾斯杀手": {
		"accent": Color("#ef4444"),
		"secondary": Color("#a3e635"),
		"glyph": "杀",
		"motif": "killer",
		"subtitle": "远程猎杀者｜临时美工",
	},
}

const MONSTER_ACTION_TABLES := {
	"尸套龙": [
		{"name": "瘴气漫步", "range": 0.0, "damage": 1, "move_override": 190.0, "miasma_count": 1, "text": "自动向高热城区移动约190米，落点造成1点区域伤害并尝试留下瘴气。"},
		{"name": "腐蚀吐息", "range": 420.0, "damage": 2, "move_override": -1.0, "miasma_count": 2, "text": "420米腐蚀吐息，对目标城区造成2点压力，并在周边留下瘴气。"},
		{"name": "瘴气炮", "range": 520.0, "damage": 2, "move_override": -1.0, "miasma_count": 3, "text": "520米远程瘴气炮，沿路径污染城区并造成2点区域伤害。"},
		{"name": "瘴气结界", "range": 260.0, "damage": 1, "move_override": -1.0, "miasma_count": 4, "text": "260米范围内散布瘴气，制造持续目标偏移和区域压力。"},
		{"name": "瘴气回收", "range": 240.0, "damage": 1, "move_override": -1.0, "self_heal": 2, "text": "回收周边瘴气回复自身，并让附近城区承受1点腐蚀压力。"},
		{"name": "灾厄压迫", "range": 180.0, "damage": 3, "move_override": 160.0, "text": "向最近高价值城区压迫推进，180米内造成3点区域伤害。"},
	],
	"土砂龙": [
		{"name": "龙车", "range": 130.0, "damage": 3, "move_override": 320.0, "knockback": 260.0, "text": "自动冲向高权重城区约320米，落点和近身目标承受强力冲撞。"},
		{"name": "甩尾", "range": 160.0, "damage": 2, "move_override": -1.0, "knockback": 220.0, "text": "160米范围尾击，造成2点区域/近身伤害并击退附近怪兽。"},
		{"name": "咆哮", "range": 450.0, "damage": 1, "move_override": -1.0, "delay": 1.5, "text": "450米咆哮提高城区热度，并拖慢下一次特殊行动节奏。"},
		{"name": "地底潜行", "range": 0.0, "damage": 1, "move_override": 340.0, "armor": 2, "text": "潜入地下移动约340米，获得2点护甲并在落点造成1点区域破坏。"},
		{"name": "打滚", "range": 140.0, "damage": 2, "move_override": 260.0, "knockback": 180.0, "text": "翻滚推进约260米，落点区域和140米内目标承受2点伤害。"},
		{"name": "泥石流", "range": 220.0, "damage": 2, "move_override": -1.0, "panic": 24, "text": "220米范围泥石流，造成2点区域伤害并显著提高当地热度。"},
	],
	"机械杰克": [
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米近战AOE，2伤害，并击退怪兽约120米。"},
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米近战AOE，2伤害，并击退怪兽约120米。"},
		{"name": "火花电击", "range": 420.0, "damage": 2, "move_override": -1.0, "paralyze": 1, "text": "420米射程，2伤害，并封锁一张怪兽技能卡。"},
		{"name": "奥特飓风", "range": 120.0, "damage": 2, "move_override": -1.0, "throw_radius": 420.0, "text": "120米近战投掷，2坠落伤害，并把怪兽投向420米内区域。"},
		{"name": "斯派修姆光线", "range": 600.0, "damage": 3, "move_override": -1.0, "knockback": 320.0, "text": "600米光线，3伤害，并直线击退怪兽约320米。"},
		{"name": "奥特空投", "range": 120.0, "damage": 4, "move_override": -1.0, "throw_radius": 320.0, "stun": 1, "text": "120米近战空投，4伤害，把怪兽摔向320米内区域并使其补给受挫。"},
	],
	"机械艾斯": [
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米近战AOE，2伤害，并击退怪兽约120米。"},
		{"name": "电击踢", "range": 120.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "paralyze": 1, "text": "120米近战AOE，2伤害，击退怪兽并封锁一张技能卡。"},
		{"name": "闪光手刀", "range": 120.0, "damage": 3, "move_override": 420.0, "paralyze": 1, "text": "高速追近420米后近战3伤害，并封锁一张技能卡。"},
		{"name": "水平断头刀", "range": 240.0, "damage": 3, "move_override": -1.0, "cripple": 1, "text": "240米射程，3伤害，并致残1张技能卡。"},
		{"name": "十字断头刀", "range": 320.0, "damage": 2, "move_override": -1.0, "cripple": 1, "stun": 1, "text": "320米射程，2伤害，并致残1张技能卡、削减技能补给。"},
		{"name": "垂直断头刀", "range": 260.0, "damage": 4, "move_override": -1.0, "cripple": 2, "text": "260米射程，4伤害，并致残2张技能卡。"},
	],
	"纳伊斯": [
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "tether": 1, "text": "110米近战AOE，2伤害，并牵制怪兽下次移动。"},
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "tether": 1, "text": "110米近战AOE，2伤害，并牵制怪兽下次移动。"},
		{"name": "束缚光线", "range": 420.0, "damage": 2, "move_override": -1.0, "tether": 2, "text": "420米束缚光线，2伤害，并施加2层牵制。"},
		{"name": "修复光线", "range": 420.0, "damage": 3, "move_override": -1.0, "repair": 1, "text": "420米修复光线，3伤害，并修复所在区域。"},
		{"name": "定身闪光", "range": 160.0, "damage": 2, "move_override": -1.0, "repair_radius": 220.0, "tether": 4, "text": "220米修复AOE，并对160米近身目标2伤害，施加4层牵制。"},
		{"name": "修正铁拳", "range": 130.0, "damage": 5, "move_override": 560.0, "repair_path": 1, "stun_if_tethered": 3, "text": "追近560米，沿追击路径修复受损区域，对130米内目标5伤害；若怪兽被牵制则追加强眩晕。"},
	],
	"梦比优斯": [
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米近战AOE，2伤害，并击退怪兽约120米。"},
		{"name": "重拳", "range": 120.0, "damage": 3, "move_override": -1.0, "knockback": 320.0, "text": "120米重拳，3伤害，并击退怪兽约320米。"},
		{"name": "飞踢", "range": 140.0, "damage": 3, "move_override": 420.0, "stun": 1, "text": "向前飞踢追近420米，对140米内目标造成3近战伤害并眩晕1。"},
		{"name": "梦比姆斩击", "range": 240.0, "damage": 2, "close_range": 120.0, "close_damage": 3, "move_override": -1.0, "cripple": 1, "text": "120米内近战3伤害；否则240米远程2伤害，并致残1张技能牌。"},
		{"name": "梦比姆爆裂", "range": 320.0, "damage": 4, "move_override": -1.0, "stun": 1, "text": "320米远程爆裂，4伤害，并眩晕1。"},
		{"name": "梦比姆炸弹", "range": 120.0, "damage": 8, "move_override": -1.0, "stun": 2, "self_damage": MEBIUS_BOMB_SELF_DAMAGE, "text": "120米近战爆弹，8伤害并眩晕2；之后梦比优斯承受3点反冲。"},
	],
	"希卡利": [
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米近战AOE，2伤害，并击退怪兽约120米。"},
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米近战AOE，2伤害，并击退怪兽约120米。"},
		{"name": "斩击", "range": 240.0, "damage": 2, "close_range": 120.0, "close_damage": 3, "move_override": -1.0, "cripple": 1, "text": "120米内近战3伤害；否则240米远程2伤害，并致残1张技能牌。"},
		{"name": "斩击", "range": 240.0, "damage": 2, "close_range": 120.0, "close_damage": 3, "move_override": -1.0, "cripple": 1, "text": "120米内近战3伤害；否则240米远程2伤害，并致残1张技能牌。"},
		{"name": "热负荷射线", "range": 420.0, "damage": 3, "move_override": -1.0, "knockback": 320.0, "stun": 1, "text": "420米热负荷射线，3伤害，直线击退怪兽约320米并眩晕1。"},
		{"name": "热负荷闪光", "range": 600.0, "damage": 1, "move_override": -1.0, "self_heal": 4, "paralyze": 2, "stun": 2, "text": "自身回复4HP；600米闪光造成1伤害，并麻痹2、眩晕2。"},
	],
	"艾斯杀手": [
		{"name": "劣质光线", "range": 420.0, "damage": 2, "move_override": -1.0, "knockback": 220.0, "chaos_ray": true, "text": "420米劣质光线，2伤害，直线击退怪兽约220米，并破坏光线路径。"},
		{"name": "劣质光线", "range": 420.0, "damage": 2, "move_override": -1.0, "knockback": 220.0, "chaos_ray": true, "text": "420米劣质光线，2伤害，直线击退怪兽约220米，并破坏光线路径。"},
		{"name": "劣质炸弹", "range": 420.0, "damage": 3, "move_override": -1.0, "stun": 1, "text": "420米劣质炸弹，3伤害，并眩晕1。"},
		{"name": "改良光线", "range": 520.0, "damage": 3, "move_override": -1.0, "knockback": 320.0, "chaos_ray": true, "text": "520米改良光线，3伤害，直线击退怪兽约320米，并破坏光线路径。"},
		{"name": "改良炸弹", "range": 520.0, "damage": 4, "move_override": -1.0, "stun": 2, "text": "520米改良炸弹，4伤害，并眩晕2。"},
		{"name": "优质光线", "range": 600.0, "damage": 5, "move_override": -1.0, "knockback": 600.0, "chaos_ray": true, "text": "600米优质光线，5伤害，直线击退怪兽约600米，并破坏光线路径。"},
	],
}

const JACK_BRACELET_ACTION_TABLE := [
	{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米近战AOE，2伤害，并击退怪兽约120米。"},
	{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米近战AOE，2伤害，并击退怪兽约120米。"},
	{"name": "手镯炸弹", "range": 420.0, "damage": 3, "move_override": -1.0, "knockback": 320.0, "text": "420米手镯炸弹，3伤害，并直线击退怪兽约320米。"},
	{"name": "手镯炸弹", "range": 420.0, "damage": 3, "move_override": -1.0, "knockback": 320.0, "text": "420米手镯炸弹，3伤害，并直线击退怪兽约320米。"},
	{"name": "奥特火花", "range": 520.0, "damage": 4, "move_override": -1.0, "text": "520米奥特火花，4伤害。"},
	{"name": "奥特火花", "range": 520.0, "damage": 4, "move_override": -1.0, "text": "520米奥特火花，4伤害。"},
]

const MONSTER_SKILL_WEIGHT_TABLES := {
	"尸套龙": {"early": [3, 2, 1, 0, 0, 0], "escalated": [2, 2, 2, 1, 2, 1]},
	"土砂龙": {"early": [3, 2, 1, 0, 0, 0], "escalated": [3, 2, 1, 2, 2, 1]},
	"机械杰克": {"early": [3, 2, 1, 0, 0, 0], "escalated": [2, 2, 2, 1, 2, 1]},
	"机械艾斯": {"early": [2, 2, 2, 0, 0, 0], "escalated": [2, 2, 2, 2, 1, 1]},
	"纳伊斯": {"early": [3, 2, 1, 0, 0, 0], "escalated": [2, 2, 2, 2, 1, 1]},
	"梦比优斯": {"early": [2, 2, 2, 0, 0, 0], "escalated": [2, 2, 2, 1, 2, 1]},
	"希卡利": {"early": [3, 2, 1, 0, 0, 0], "escalated": [2, 2, 2, 1, 2, 1]},
	"艾斯杀手": {"early": [3, 2, 1, 0, 0, 0], "escalated": [2, 2, 2, 2, 1, 1]},
	"手镯杰克": {"early": [2, 2, 1, 1, 0, 0], "escalated": [2, 2, 2, 2, 1, 1]},
}

var rng := RandomNumberGenerator.new()
var players := []
var districts := []
var skill_market := []
var product_market := {}
var log_lines := []
var movement_trails := []
var action_callouts := []
var map_event_effects := []

var game_time := 0.0
var time_scale := 1.0
var selected_player := 0
var selected_district := 0
var selected_market_skill := "城市融资1"
var previewed_district_card := ""
var selected_guess_player := -1
var selected_trade_product := ""
var selected_contract_source_district := -1
var selected_contract_target_district := -1
var business_cycle_count := 0
var configured_player_count := DEFAULT_PLAYER_COUNT
var configured_ai_player_count := DEFAULT_AI_PLAYER_COUNT
var configured_roguelike_depth := DEFAULT_ROGUELIKE_DEPTH
var configured_role_indices := []
var configured_starter_monster_indices := []
var game_over := false
var victory_countdown_active := false
var victory_countdown_timer := 0.0
var victory_countdown_trigger_player := -1
var victory_countdown_trigger_score := 0
var map_width_m := MAP_WIDTH_METERS
var map_height_m := MAP_HEIGHT_METERS
var district_lookup := {}

var event_timer := 6.0
var special_monster_timer := 5.0
var monster_timer := 4.0
var market_timer := 8.0
var ui_timer := 0.0
var ai_card_decision_timer := AI_CARD_DECISION_INTERVAL_SECONDS
var ai_auction_reaction_timer := AI_AUCTION_REACTION_INTERVAL_SECONDS
var ai_intel_decision_timer := AI_INTEL_DECISION_INTERVAL_SECONDS
var ai_card_decision_enabled := true

var auto_monsters := []
var next_auto_monster_uid := 1
var next_special_monster_slot := 0
var selected_auto_monster_slot := 0
var pending_target_player_index := -1
var pending_target_slot_index := -1
var pending_target_paused_time := false
var speed_before_target_choice := 1.0
var run_save_path := RUN_SAVE_PATH

var status_label: Label
var map_view: Control
var player_box: VBoxContainer
var menu_overlay: Control
var menu_title_label: Label
var menu_body_label: Label
var menu_preview_box: VBoxContainer
var menu_continue_button: Button
var menu_back_button: Button
var menu_regular_buttons := []
var menu_load_run_button: Button
var menu_run_save_label: Label
var menu_bestiary_prev_button: Button
var menu_bestiary_next_button: Button
var menu_bestiary_back_button: Button
var menu_catalog_mode := ""
var catalog_return_menu := "main"
var bestiary_index := 0
var bestiary_grid_page := 0
var bestiary_show_detail := false
var previewed_bestiary_index := 0
var card_codex_index := 0
var card_codex_filter := "all"
var card_codex_grid_page := 0
var card_codex_show_detail := false
var previewed_card_codex_card := ""
var product_codex_index := 0
var product_codex_grid_page := 0
var product_codex_show_detail := false
var previewed_product_codex_index := 0
var region_codex_index := 0
var role_codex_index := 0
var speed_before_menu := 1.0
var full_map_overlay: Control
var full_map_view: Control
var map_build_buttons := []
var map_guess_options := []
var map_guess_buttons := []
var map_role_intel_buttons := []
var map_city_info_labels := []
var map_trade_options := []
var map_trade_buttons := []
var map_trade_info_labels := []
var map_contract_source_buttons := []
var map_contract_target_buttons := []
var map_contract_info_labels := []
var card_resolution_queue := []
var next_card_resolution_queue := []
var active_card_resolution := {}
var pending_contract_offers := []
var card_resolution_timer := 0.0
var card_resolution_force_duration := -1.0
var card_resolution_simultaneous_timer := 0.0
var card_resolution_auction_timer := 0.0
var card_resolution_force_simultaneous_window := -1.0
var card_resolution_auction_open := false
var card_resolution_batch_locked := false
var card_resolution_batch_reference_player := -1
var card_resolution_sequence := 0
var last_card_resolution_player_index := -1
var card_resolution_priority_reference_player := -1
var card_resolution_visual_id := -1
var card_resolution_visual_stage := -1
var resolved_card_history := []
var selected_card_resolution_id := -1
var card_resolution_track_scroll: ScrollContainer
var card_resolution_track: HBoxContainer
var card_resolution_track_dragging := false
var card_resolution_track_drag_start_x := 0.0
var card_resolution_track_drag_start_scroll := 0
var card_resolution_overlay: Control
var card_resolution_title_label: Label
var card_resolution_body_label: Label
var card_resolution_status_label: Label
var card_resolution_badge_box: HBoxContainer
var card_resolution_art: Control
var opening_guide_dismissed := false
var opening_guide_economy_seen_players := {}


func _ready() -> void:
	rng.randomize()
	_load_settings()
	_build_layout()
	_log("点击开局准备后确认玩家角色与起始怪兽牌；怪兽由怪兽卡匿名召唤，场上数量没有硬上限。")
	_open_main_menu()


func _process(delta: float) -> void:
	if game_over or time_scale <= 0.0:
		return

	var scaled_delta := delta * time_scale
	game_time += scaled_delta
	_update_card_resolution_queue(scaled_delta)
	_update_pending_contract_offers(scaled_delta)
	_update_realtime_cooldowns(scaled_delta)
	_update_ai_decisions(scaled_delta)
	_update_auto_monster_durations(scaled_delta)
	_update_visual_cues(scaled_delta)
	_update_auto_monster_revivals(scaled_delta)
	_update_victory_countdown(scaled_delta)
	if game_over:
		return

	event_timer -= scaled_delta
	if _active_auto_monster_count() > 0:
		special_monster_timer -= scaled_delta
	monster_timer -= scaled_delta
	market_timer -= scaled_delta

	if event_timer <= 0.0:
		_world_event()
		event_timer = _roll_timer("event")
	if monster_timer <= 0.0:
		_monster_tick()
		monster_timer = _roll_timer("monster")
	if _active_auto_monster_count() > 0 and special_monster_timer <= 0.0:
		_special_monster_tick()
		special_monster_timer = _roll_timer("special_monster")
	if market_timer <= 0.0:
		_market_tick()
		market_timer = _roll_timer("market")

	ui_timer -= delta
	if ui_timer <= 0.0:
		_refresh_ui()
		ui_timer = 0.25


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
		KEY_B:
			_build_city_in_selected_district()
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


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#090d18")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	page.add_child(header)

	var title := Label.new()
	title.text = "太空辛迪加 / Space Syndicate  即时原型"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#f8fafc"))
	header.add_child(title)

	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	header.add_child(status_label)

	var reset_button := Button.new()
	reset_button.text = "开局准备"
	reset_button.pressed.connect(Callable(self, "_start_new_run_from_menu"))
	header.add_child(reset_button)

	var menu_button := Button.new()
	menu_button.text = "菜单"
	menu_button.pressed.connect(Callable(self, "_open_pause_menu"))
	header.add_child(menu_button)

	_build_card_resolution_track(page)

	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	page.add_child(body)

	var board_panel := _add_panel(body, "星球地图")
	_panel_container(board_panel).size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map_toolbar := HBoxContainer.new()
	map_toolbar.add_theme_constant_override("separation", 8)
	board_panel.add_child(map_toolbar)
	var map_hint := _plain_label("滚轮缩放 · 拖拽地图", 12, Color("#94a3b8"))
	map_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_toolbar.add_child(map_hint)
	_add_map_action_controls(map_toolbar)
	var fullscreen_button := Button.new()
	fullscreen_button.text = "全屏地图"
	fullscreen_button.pressed.connect(Callable(self, "_open_fullscreen_map"))
	map_toolbar.add_child(fullscreen_button)

	map_view = MapViewScript.new()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.district_selected.connect(Callable(self, "_select_district"))
	board_panel.add_child(map_view)
	map_view.custom_minimum_size = Vector2(480, 320)

	player_box = _add_panel(body, "玩家手牌")
	_panel_container(player_box).custom_minimum_size = Vector2(0, 300)

	_build_full_map_overlay()
	_build_card_resolution_overlay()
	_build_menu_overlay()


func _build_card_resolution_track(page: VBoxContainer) -> void:
	var track_box := _add_panel(page, "匿名卡牌轨道")
	_panel_container(track_box).custom_minimum_size = Vector2(0, 204)
	var hint := _plain_label("左侧是历史牌，中间是当前展示牌，右侧是候补牌；拖动或滚轮横向查看。报价公开，出牌者匿名。", 11, Color("#94a3b8"))
	track_box.add_child(hint)
	card_resolution_track_scroll = ScrollContainer.new()
	card_resolution_track_scroll.custom_minimum_size = Vector2(0, 152)
	card_resolution_track_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_resolution_track_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card_resolution_track_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_resolution_track_scroll.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_connect_card_resolution_track_drag(card_resolution_track_scroll)
	track_box.add_child(card_resolution_track_scroll)
	card_resolution_track = HBoxContainer.new()
	card_resolution_track.add_theme_constant_override("separation", 8)
	card_resolution_track.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card_resolution_track_scroll.add_child(card_resolution_track)


func _connect_card_resolution_track_drag(control: Control) -> void:
	if control == null:
		return
	control.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	var callback := Callable(self, "_on_card_resolution_track_gui_input")
	if not control.gui_input.is_connected(callback):
		control.gui_input.connect(callback)


func _on_card_resolution_track_gui_input(event: InputEvent) -> void:
	if card_resolution_track_scroll == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_scroll_card_resolution_track_by(-CARD_TRACK_WHEEL_STEP_PIXELS)
			accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_scroll_card_resolution_track_by(CARD_TRACK_WHEEL_STEP_PIXELS)
			accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_LEFT and mouse_event.pressed:
			_scroll_card_resolution_track_by(-CARD_TRACK_WHEEL_STEP_PIXELS)
			accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_RIGHT and mouse_event.pressed:
			_scroll_card_resolution_track_by(CARD_TRACK_WHEEL_STEP_PIXELS)
			accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			card_resolution_track_dragging = mouse_event.pressed
			if card_resolution_track_dragging:
				card_resolution_track_drag_start_x = get_viewport().get_mouse_position().x
				card_resolution_track_drag_start_scroll = int(card_resolution_track_scroll.scroll_horizontal)
			accept_event()
			return
	if event is InputEventMouseMotion and card_resolution_track_dragging:
		var drag_delta := card_resolution_track_drag_start_x - get_viewport().get_mouse_position().x
		if absf(drag_delta) >= CARD_TRACK_DRAG_DEADZONE_PIXELS:
			_set_card_resolution_track_scroll(card_resolution_track_drag_start_scroll + int(round(drag_delta)))
			accept_event()


func _scroll_card_resolution_track_by(delta_pixels: int) -> int:
	if card_resolution_track_scroll == null:
		return 0
	return _set_card_resolution_track_scroll(int(card_resolution_track_scroll.scroll_horizontal) + delta_pixels)


func _set_card_resolution_track_scroll(amount: int) -> int:
	if card_resolution_track_scroll == null:
		return 0
	var max_scroll := _card_resolution_track_max_scroll()
	var clamped := clampi(amount, 0, max_scroll)
	card_resolution_track_scroll.scroll_horizontal = clamped
	return clamped


func _card_resolution_track_max_scroll() -> int:
	if card_resolution_track_scroll == null:
		return 0
	var content_width := 0.0
	if card_resolution_track != null:
		content_width = card_resolution_track.get_combined_minimum_size().x
	var viewport_width := card_resolution_track_scroll.size.x
	var layout_max := maxi(0, int(ceil(content_width - viewport_width)))
	var scrollbar_max := 0
	var scrollbar := card_resolution_track_scroll.get_h_scroll_bar()
	if scrollbar != null:
		scrollbar_max = maxi(0, int(ceil(scrollbar.max_value - scrollbar.page)))
	return maxi(layout_max, scrollbar_max)


func _refresh_card_resolution_track() -> void:
	if card_resolution_track == null:
		return
	_clear_children(card_resolution_track)
	card_resolution_track.custom_minimum_size = Vector2.ZERO
	var has_entries := false
	for history_variant in resolved_card_history:
		if not (history_variant is Dictionary):
			continue
		_add_card_resolution_track_entry(history_variant as Dictionary, "已结算")
		has_entries = true
	if not active_card_resolution.is_empty():
		_add_card_resolution_track_entry(active_card_resolution, "当前展示 %.1fs" % max(0.0, card_resolution_timer))
		has_entries = true
	if not card_resolution_queue.is_empty():
		if card_resolution_auction_open:
			_sort_card_resolution_queue()
		for i in range(card_resolution_queue.size()):
			var queue_state := "锁定" if card_resolution_batch_locked else ("竞拍" if card_resolution_auction_open else "待定")
			_add_card_resolution_track_entry(card_resolution_queue[i] as Dictionary, "%s%d" % [queue_state, i + 1])
			has_entries = true
	for i in range(next_card_resolution_queue.size()):
		var next_entry_variant: Variant = next_card_resolution_queue[i]
		if not (next_entry_variant is Dictionary):
			continue
		_add_card_resolution_track_entry(next_entry_variant as Dictionary, "下批等待%d" % (i + 1))
		has_entries = true
	if not has_entries:
		var empty_label := _plain_label("还没有匿名卡牌进入轨道。打出第一张牌后，所有玩家会在这里看到相同的公开记录。", 12, Color("#64748b"))
		empty_label.custom_minimum_size = Vector2(520, 100)
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card_resolution_track.add_child(empty_label)
	_sync_card_resolution_track_width()


func _sync_card_resolution_track_width() -> void:
	if card_resolution_track == null:
		return
	var width := 0.0
	var child_count := 0
	for child_variant in card_resolution_track.get_children():
		if child_variant is Control:
			var child := child_variant as Control
			width += child.get_combined_minimum_size().x
			child_count += 1
	if child_count > 1:
		width += float(child_count - 1) * float(card_resolution_track.get_theme_constant("separation"))
	card_resolution_track.custom_minimum_size = Vector2(width, 0.0)


func _add_card_resolution_track_entry(entry: Dictionary, state_text: String) -> void:
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	var card_name := String(skill.get("name", "卡牌"))
	var card_label := _card_display_name(card_name)
	if card_label == "":
		card_label = "匿名卡牌"
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 142)
	_connect_card_resolution_track_drag(panel)
	var style := StyleBoxFlat.new()
	var accent := _card_theme_color(skill)
	style.bg_color = Color("#0f172a").lerp(accent, 0.10)
	style.border_color = accent if resolution_id == selected_card_resolution_id else Color("#334155")
	style.set_border_width_all(2 if resolution_id == selected_card_resolution_id else 1)
	style.set_corner_radius_all(9)
	panel.add_theme_stylebox_override("panel", style)
	card_resolution_track.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	var select_button := Button.new()
	select_button.text = "%s｜%s" % [state_text, card_label]
	select_button.toggle_mode = true
	select_button.button_pressed = resolution_id == selected_card_resolution_id
	select_button.tooltip_text = "点选这张匿名卡，再点击一名玩家头像竞猜出牌者。\n%s" % _card_resolution_play_requirement_text(entry)
	select_button.pressed.connect(Callable(self, "_select_card_resolution_track_entry").bind(resolution_id))
	box.add_child(select_button)
	var bid := int(entry.get("tip", entry.get("winning_bid", 0)))
	if state_text.begins_with("候补") or state_text.begins_with("锁定") or state_text.begins_with("竞拍") or state_text.begins_with("待定") or state_text.begins_with("下批"):
		var bid_label := "锁定报价" if state_text.begins_with("锁定") else ("预设报价" if state_text.begins_with("待定") or state_text.begins_with("下批") else "公开报价")
		box.add_child(_plain_label("%s ¥%d｜出牌者未知" % [bid_label, bid], 10, Color("#fde68a")))
	elif int(entry.get("winning_bid", 0)) > 0:
		box.add_child(_plain_label("成交小费 ¥%d｜出牌者%s" % [int(entry.get("winning_bid", 0)), "已揭晓" if bool(entry.get("public_owner_revealed", false)) else "未知"], 10, Color("#fde68a")))
	else:
		box.add_child(_plain_label("出牌者%s" % ("已揭晓" if bool(entry.get("public_owner_revealed", false)) else "未知"), 10, Color("#94a3b8")))
	var owner_revealed := bool(entry.get("public_owner_revealed", false))
	var owner_text := String(entry.get("public_owner_label", "")) if owner_revealed else "归属：未揭晓"
	if owner_revealed:
		var owner_index := int(entry.get("player_index", -1))
		var owner_color := _player_color(owner_index) if owner_index >= 0 else accent
		box.add_child(_track_status_badge("公开归属标签｜%s" % owner_text.replace("归属：", ""), owner_color, Color("#020617").lerp(owner_color, 0.28)))
	else:
		box.add_child(_plain_label(owner_text, 10, Color("#64748b")))
	_add_card_resolution_track_badges(box, entry, state_text, bid)
	if resolution_id != selected_card_resolution_id:
		box.add_child(_plain_label("点卡牌后选择头像竞猜", 10, Color("#64748b")))
		return
	var guessers: Array = entry.get("guessers", []) as Array
	var already_guessed := guessers.has(selected_player)
	var stake := _card_owner_guess_stake_for_player(selected_player)
	if owner_revealed:
		box.add_child(_track_status_badge("证据已公开：所有人可见", Color("#fef3c7"), Color("#713f12")))
	elif already_guessed:
		box.add_child(_track_status_badge("我的竞猜：已押注｜真实归属仍隐藏", Color("#c4b5fd"), Color("#312e81")))
	else:
		box.add_child(_track_status_badge("我的竞猜：选择头像押注¥%d" % stake, Color("#bae6fd"), Color("#0c4a6e")))
	var avatar_row := HBoxContainer.new()
	avatar_row.add_theme_constant_override("separation", 3)
	box.add_child(avatar_row)
	for player_index in range(players.size()):
		var avatar := Button.new()
		avatar.text = "P%d" % (player_index + 1)
		avatar.add_theme_color_override("font_color", _player_color(player_index))
		avatar.tooltip_text = "当前视角玩家押注¥%d，猜这张牌由玩家%d打出。" % [stake, player_index + 1]
		avatar.disabled = game_over or already_guessed or bool(entry.get("public_owner_revealed", false)) or selected_player == int(entry.get("player_index", -1)) or int((players[selected_player] as Dictionary).get("cash", 0)) < stake
		avatar.pressed.connect(Callable(self, "_guess_card_resolution_owner").bind(resolution_id, player_index))
		avatar_row.add_child(avatar)


func _add_card_resolution_track_badges(box: VBoxContainer, entry: Dictionary, state_text: String, bid: int) -> void:
	for badge_text in _card_resolution_track_badge_texts(entry, state_text, bid):
		var badge_color := _card_resolution_track_badge_color(String(badge_text))
		box.add_child(_track_status_badge(String(badge_text), badge_color, Color("#020617").lerp(badge_color, 0.22)))


func _card_resolution_track_badge_texts(entry: Dictionary, state_text: String, bid: int) -> Array:
	var badges := []
	if state_text.begins_with("当前展示"):
		badges.append("正在全屏展示")
	if state_text.begins_with("锁定1"):
		badges.append("下一张将展示")
	elif state_text.begins_with("竞拍1"):
		badges.append("当前竞价队首")
	elif state_text.begins_with("待定1"):
		badges.append("同时窗队首")
	elif state_text.begins_with("下批等待"):
		badges.append("下一批等待区")
	if card_resolution_auction_open and state_text.begins_with("竞拍") and bid > 0 and bid == _highest_card_resolution_bid():
		badges.append("最高公开报价")
	if selected_player >= 0 and selected_player < players.size() and int(entry.get("player_index", -1)) == selected_player and not bool(entry.get("public_owner_revealed", false)):
		if state_text.begins_with("已结算"):
			badges.append("我的历史匿名牌")
		elif state_text.begins_with("当前展示"):
			badges.append("我的展示中匿名牌")
		else:
			badges.append("我的候补匿名牌")
	for visual_badge in _card_resolution_track_visual_badges(entry, state_text):
		badges.append(visual_badge)
	var contract_badge := _card_resolution_contract_badge_text(entry)
	if contract_badge != "":
		badges.append(contract_badge)
	var requirement_badge := _card_resolution_requirement_badge_text(entry)
	if requirement_badge != "":
		badges.append(requirement_badge)
	if state_text.begins_with("已结算"):
		var aftermath_clue := String(entry.get("aftermath_clue", ""))
		if aftermath_clue != "":
			badges.append("余波线索｜%s" % _short_event_label(aftermath_clue, 14))
		var tip_clue := _card_resolution_tip_clue_text(entry)
		if tip_clue != "":
			badges.append("竞价线索｜%s" % _short_event_label(tip_clue, 18))
	return badges


func _card_resolution_track_visual_badges(entry: Dictionary, state_text: String) -> Array:
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	if skill.is_empty():
		return []
	var style := _card_resolution_effect_style(skill)
	var style_label := _card_resolution_effect_style_label(style)
	var stage_label := "候补"
	if state_text.begins_with("当前展示"):
		stage_label = _card_resolution_stage_label(_card_resolution_stage_index(card_resolution_timer))
	elif state_text.begins_with("已结算"):
		stage_label = "余波"
	elif state_text.begins_with("竞拍"):
		stage_label = "竞价"
	elif state_text.begins_with("锁定"):
		stage_label = "锁定"
	elif state_text.begins_with("待定"):
		stage_label = "同时窗"
	elif state_text.begins_with("下批"):
		stage_label = "下批等待"
	var map_label := _card_resolution_stage_effect_label(stage_label, style)
	return [
		"演出风格｜%s" % style_label,
		"地图播报｜%s" % map_label,
	]


func _card_resolution_track_badge_color(text: String) -> Color:
	if text.contains("我的"):
		return Color("#a7f3d0")
	if text.contains("演出风格"):
		return Color("#c4b5fd")
	if text.contains("地图播报"):
		return Color("#93c5fd")
	if text.contains("余波线索"):
		return Color("#f0abfc")
	if text.contains("竞价线索"):
		return Color("#fde68a")
	if text.contains("合约"):
		return Color("#fbbf24")
	if text.contains("出牌条件"):
		return Color("#bbf7d0")
	if text.contains("最高"):
		return Color("#fde68a")
	if text.contains("成交") or text.contains("小费"):
		return Color("#fde68a")
	if text.contains("归属未知"):
		return Color("#94a3b8")
	if text.contains("公开归属"):
		return Color("#fef3c7")
	if text.contains("下一张") or text.contains("队首"):
		return Color("#bae6fd")
	if text.contains("展示"):
		return Color("#fda4af")
	return Color("#c4b5fd")


func _refresh_card_resolution_overlay_badges(entry: Dictionary) -> void:
	if card_resolution_badge_box == null:
		return
	_clear_children(card_resolution_badge_box)
	if entry.is_empty():
		card_resolution_badge_box.visible = false
		return
	card_resolution_badge_box.visible = true
	for badge_text in _card_resolution_overlay_badge_texts(entry):
		var text := String(badge_text)
		var badge_color := _card_resolution_track_badge_color(text)
		card_resolution_badge_box.add_child(_track_status_badge(text, badge_color, Color("#020617").lerp(badge_color, 0.24)))


func _card_resolution_overlay_badge_texts(entry: Dictionary) -> Array:
	var badges := []
	var owner_revealed := bool(entry.get("public_owner_revealed", false))
	var owner_index := int(entry.get("player_index", -1))
	if owner_revealed:
		var owner_label := String(entry.get("public_owner_label", "归属：已公开")).replace("归属：", "")
		badges.append("公开归属标签｜%s" % owner_label)
	elif selected_player >= 0 and selected_player < players.size() and owner_index == selected_player:
		badges.append("我的展示中匿名牌")
	else:
		badges.append("归属未知")
	var requirement_badge := _card_resolution_requirement_badge_text(entry)
	if requirement_badge != "":
		badges.append(requirement_badge)
	var contract_badge := _card_resolution_contract_badge_text(entry)
	if contract_badge != "":
		badges.append(contract_badge)
	var bid := int(entry.get("winning_bid", entry.get("tip", 0)))
	if bid > 0:
		badges.append("成交小费¥%d｜%s" % [bid, "已私密支付" if bool(entry.get("tip_paid", false)) else "锁定"])
	var tip_clue := _card_resolution_tip_clue_text(entry)
	if tip_clue != "":
		badges.append("竞价线索｜%s" % _short_event_label(tip_clue, 20))
	if card_resolution_queue.size() > 0:
		badges.append("锁定候补%d" % card_resolution_queue.size())
	if next_card_resolution_queue.size() > 0:
		badges.append("下批等待%d" % next_card_resolution_queue.size())
	return badges


func _card_resolution_contract_badge_text(entry: Dictionary) -> String:
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	if String(skill.get("kind", "")) != "area_trade_contract":
		return ""
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	if not active_card_resolution.is_empty() and int(active_card_resolution.get("resolution_id", active_card_resolution.get("queued_order", -1))) == resolution_id:
		return "合约展示｜结束后另有5秒签约"
	var offer := _pending_contract_offer_by_id(int(entry.get("contract_offer_id", resolution_id)))
	if not offer.is_empty():
		return "合约待签｜剩%.1fs" % maxf(0.0, float(offer.get("contract_decision_timer", CONTRACT_DECISION_SECONDS)))
	return "合约结果｜%s" % _contract_response_public_label(entry)


func _card_resolution_requirement_badge_text(entry: Dictionary) -> String:
	var requirement_text := _card_resolution_play_requirement_text(entry)
	if requirement_text == "":
		return ""
	return "出牌条件｜%s" % _short_event_label(requirement_text.replace("打出条件：", ""), 22)


func _card_resolution_play_requirement_text(entry: Dictionary) -> String:
	var stored_text := String(entry.get("play_requirement_text", ""))
	if stored_text != "":
		return stored_text
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	if skill.is_empty():
		return "打出条件：未知"
	var flow_required := int(entry.get("play_requirement_flow", _skill_play_flow_required(skill)))
	var cash_cost := int(entry.get("play_cash_cost", _skill_play_cash_cost(skill)))
	if bool(skill.get("starter_play_free", false)):
		var starter_text := "打出条件：起始怪兽牌，无区域/商品流动门槛"
		if cash_cost > 0:
			starter_text += "｜额外支付¥%d" % cash_cost
		return starter_text
	if flow_required <= 0:
		var free_text := "打出条件：无商品流动门槛"
		if cash_cost > 0:
			free_text += "｜额外支付¥%d" % cash_cost
		return free_text
	var product_name := _card_resolution_requirement_product_snapshot(entry, skill)
	var text := "打出条件：%s流动≥%d（不消耗商品）" % [product_name, flow_required]
	if cash_cost > 0:
		text += "｜额外支付¥%d" % cash_cost
	return text


func _card_resolution_requirement_product_snapshot(entry: Dictionary, skill: Dictionary, fallback_player_index: int = -1) -> String:
	var snapshot := String(entry.get("play_requirement_product", ""))
	if snapshot != "":
		return snapshot
	var explicit := String(skill.get("play_product", ""))
	if explicit != "":
		return explicit
	var selected_product := String(entry.get("selected_trade_product", ""))
	if selected_product != "":
		return selected_product
	return _skill_play_product(skill, fallback_player_index)


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
	margin.add_child(_plain_label(text, 10, text_color))
	return badge


func _select_card_resolution_track_entry(resolution_id: int) -> void:
	selected_card_resolution_id = -1 if selected_card_resolution_id == resolution_id else resolution_id
	_refresh_card_resolution_track()


func _card_resolution_entry_by_id(resolution_id: int) -> Dictionary:
	if int(active_card_resolution.get("resolution_id", active_card_resolution.get("queued_order", -1))) == resolution_id:
		return active_card_resolution.duplicate(true)
	for entry_variant in card_resolution_queue:
		if entry_variant is Dictionary:
			var queued_entry := entry_variant as Dictionary
			if int(queued_entry.get("resolution_id", queued_entry.get("queued_order", -1))) == resolution_id:
				return queued_entry.duplicate(true)
	for entry_variant in next_card_resolution_queue:
		if entry_variant is Dictionary:
			var next_entry := entry_variant as Dictionary
			if int(next_entry.get("resolution_id", next_entry.get("queued_order", -1))) == resolution_id:
				return next_entry.duplicate(true)
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
	if int(active_card_resolution.get("resolution_id", active_card_resolution.get("queued_order", -1))) == resolution_id:
		active_card_resolution = entry.duplicate(true)
		return true
	for i in range(card_resolution_queue.size()):
		var queued: Dictionary = card_resolution_queue[i]
		if int(queued.get("resolution_id", queued.get("queued_order", -1))) == resolution_id:
			card_resolution_queue[i] = entry.duplicate(true)
			return true
	for i in range(next_card_resolution_queue.size()):
		var next_entry: Dictionary = next_card_resolution_queue[i]
		if int(next_entry.get("resolution_id", next_entry.get("queued_order", -1))) == resolution_id:
			next_card_resolution_queue[i] = entry.duplicate(true)
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


func _guess_card_resolution_owner(resolution_id: int, guessed_player: int) -> void:
	_guess_card_resolution_owner_for_player(selected_player, resolution_id, guessed_player, true)


func _guess_card_resolution_owner_for_player(viewer_index: int, resolution_id: int, guessed_player: int, announce: bool = true) -> bool:
	if game_over or viewer_index < 0 or viewer_index >= players.size() or guessed_player < 0 or guessed_player >= players.size():
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
	if not active_card_resolution.is_empty():
		_show_card_resolution_overlay(active_card_resolution, card_resolution_timer)
	_refresh_ui()
	return true


func _build_full_map_overlay() -> void:
	var shade := ColorRect.new()
	shade.color = Color("#020617")
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.visible = false
	full_map_overlay = shade
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	shade.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	box.add_child(toolbar)
	var title := _plain_label("全屏星球地图", 20, Color("#f8fafc"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)
	_add_map_action_controls(toolbar)
	var close_button := Button.new()
	close_button.text = "退出全屏"
	close_button.pressed.connect(Callable(self, "_close_fullscreen_map"))
	toolbar.add_child(close_button)

	full_map_view = MapViewScript.new()
	full_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	full_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	full_map_view.district_selected.connect(Callable(self, "_select_district"))
	box.add_child(full_map_view)


func _build_card_resolution_overlay() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.08, 0.42)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.visible = false
	card_resolution_overlay = shade
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 360)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0f172a").lerp(Color("#fb7185"), 0.14)
	style.border_color = Color("#fb7185")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	card_resolution_title_label = _plain_label("匿名卡牌结算", 22, Color("#f8fafc"))
	card_resolution_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(card_resolution_title_label)

	card_resolution_status_label = _plain_label("结算中", 12, Color("#fde68a"))
	card_resolution_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(card_resolution_status_label)

	var badge_center := CenterContainer.new()
	box.add_child(badge_center)
	card_resolution_badge_box = HBoxContainer.new()
	card_resolution_badge_box.add_theme_constant_override("separation", 6)
	card_resolution_badge_box.visible = false
	badge_center.add_child(card_resolution_badge_box)

	card_resolution_art = CardArtViewScript.new()
	card_resolution_art.custom_minimum_size = Vector2(0, 150)
	card_resolution_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(card_resolution_art)

	card_resolution_body_label = _plain_label("所有玩家都能看到这张牌，但不知道是谁打出的。", 13, Color("#e5e7eb"))
	card_resolution_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_resolution_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(card_resolution_body_label)


func _add_map_action_controls(toolbar: HBoxContainer) -> void:
	var city_info := _plain_label("未选择城市", 11, Color("#cbd5e1"))
	city_info.custom_minimum_size = Vector2(220, 0)
	city_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toolbar.add_child(city_info)
	map_city_info_labels.append(city_info)

	var build_button := Button.new()
	build_button.text = "城市化"
	build_button.tooltip_text = "在选中区域建造城市群。"
	build_button.pressed.connect(Callable(self, "_build_city_in_selected_district"))
	toolbar.add_child(build_button)
	map_build_buttons.append(build_button)

	var guess_option := OptionButton.new()
	guess_option.tooltip_text = "选择当前玩家对该城市真实业主的推测。"
	guess_option.add_item("归属未知")
	for i in range(MAX_PLAYER_COUNT):
		guess_option.add_item("猜玩家%d" % (i + 1))
	guess_option.item_selected.connect(Callable(self, "_on_guess_option_selected").bind(guess_option))
	toolbar.add_child(guess_option)
	map_guess_options.append(guess_option)

	var guess_button := Button.new()
	guess_button.text = "标注选区"
	guess_button.tooltip_text = "只保存到当前玩家的私人地图标注，不会揭示真实归属。"
	guess_button.pressed.connect(Callable(self, "_mark_selected_city_guess"))
	toolbar.add_child(guess_button)
	map_guess_buttons.append(guess_button)

	var role_intel_button := Button.new()
	role_intel_button.text = "身份侦测"
	role_intel_button.tooltip_text = "若当前角色有区域侦测次数，可直接查明选中陌生城市业主并写入私人标注。"
	role_intel_button.pressed.connect(Callable(self, "_use_selected_role_city_reveal"))
	toolbar.add_child(role_intel_button)
	map_role_intel_buttons.append(role_intel_button)

	var trade_option := OptionButton.new()
	trade_option.tooltip_text = "选择要在地图上显示运输路径的商品。"
	trade_option.add_item("商路关闭")
	for product_variant in PRODUCT_CATALOG:
		trade_option.add_item(String(product_variant))
	trade_option.item_selected.connect(Callable(self, "_on_trade_product_selected").bind(trade_option))
	toolbar.add_child(trade_option)
	map_trade_options.append(trade_option)

	var trade_button := Button.new()
	trade_button.text = "查看商路"
	trade_button.tooltip_text = "显示或关闭当前选区相关商品的运输路径。"
	trade_button.pressed.connect(Callable(self, "_toggle_selected_trade_route"))
	toolbar.add_child(trade_button)
	map_trade_buttons.append(trade_button)

	var trade_info := _plain_label("商路关闭", 11, Color("#93c5fd"))
	trade_info.custom_minimum_size = Vector2(150, 0)
	toolbar.add_child(trade_info)
	map_trade_info_labels.append(trade_info)

	var contract_source_button := Button.new()
	contract_source_button.text = "设供给区"
	contract_source_button.tooltip_text = "打出合约牌前必须先点：把当前选中区域设为下一张供需合约的供给区。"
	contract_source_button.pressed.connect(Callable(self, "_set_selected_contract_source_district"))
	toolbar.add_child(contract_source_button)
	map_contract_source_buttons.append(contract_source_button)

	var contract_target_button := Button.new()
	contract_target_button.text = "设需求区"
	contract_target_button.tooltip_text = "打出合约牌前必须先点：把当前选中城市设为下一张供需合约的需求/签约区。"
	contract_target_button.pressed.connect(Callable(self, "_set_selected_contract_target_district"))
	toolbar.add_child(contract_target_button)
	map_contract_target_buttons.append(contract_target_button)

	var contract_info := _plain_label("合约: 未设两端", 11, Color("#fef3c7"))
	contract_info.custom_minimum_size = Vector2(220, 0)
	toolbar.add_child(contract_info)
	map_contract_info_labels.append(contract_info)


func _build_menu_overlay() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.88)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.visible = false
	menu_overlay = shade
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0f172a")
	style.border_color = Color("#38bdf8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	menu_title_label = Label.new()
	menu_title_label.text = "Space Syndicate"
	menu_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title_label.add_theme_font_size_override("font_size", 30)
	menu_title_label.add_theme_color_override("font_color", Color("#f8fafc"))
	box.add_child(menu_title_label)

	var menu_nav := HBoxContainer.new()
	menu_nav.add_theme_constant_override("separation", 10)
	box.add_child(menu_nav)

	menu_continue_button = Button.new()
	menu_continue_button.text = "继续游戏"
	menu_continue_button.pressed.connect(Callable(self, "_close_menu"))
	menu_nav.add_child(menu_continue_button)

	menu_back_button = Button.new()
	menu_back_button.text = "返回主菜单"
	menu_back_button.pressed.connect(Callable(self, "_open_main_menu"))
	menu_nav.add_child(menu_back_button)

	var bestiary_nav := HBoxContainer.new()
	bestiary_nav.add_theme_constant_override("separation", 8)
	box.add_child(bestiary_nav)

	menu_bestiary_prev_button = Button.new()
	menu_bestiary_prev_button.text = "上一个"
	menu_bestiary_prev_button.pressed.connect(Callable(self, "_cycle_menu_catalog").bind(-1))
	bestiary_nav.add_child(menu_bestiary_prev_button)

	menu_bestiary_next_button = Button.new()
	menu_bestiary_next_button.text = "下一个"
	menu_bestiary_next_button.pressed.connect(Callable(self, "_cycle_menu_catalog").bind(1))
	bestiary_nav.add_child(menu_bestiary_next_button)

	menu_bestiary_back_button = Button.new()
	menu_bestiary_back_button.text = "返回主菜单"
	menu_bestiary_back_button.pressed.connect(Callable(self, "_back_from_catalog_menu"))
	bestiary_nav.add_child(menu_bestiary_back_button)
	menu_bestiary_prev_button.visible = false
	menu_bestiary_next_button.visible = false
	menu_bestiary_back_button.visible = false

	menu_body_label = Label.new()
	menu_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_body_label.add_theme_font_size_override("font_size", 15)
	menu_body_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	box.add_child(menu_body_label)

	menu_preview_box = VBoxContainer.new()
	menu_preview_box.add_theme_constant_override("separation", 8)
	menu_preview_box.visible = false
	box.add_child(menu_preview_box)

	menu_regular_buttons = []

	var start_section := _plain_label("开局", 12, Color("#93c5fd"))
	box.add_child(start_section)
	menu_regular_buttons.append(start_section)

	var new_run_button := Button.new()
	new_run_button.text = "开局准备"
	new_run_button.pressed.connect(Callable(self, "_start_new_run_from_menu"))
	box.add_child(new_run_button)
	menu_regular_buttons.append(new_run_button)

	var situation_section := _plain_label("局势", 12, Color("#93c5fd"))
	box.add_child(situation_section)
	menu_regular_buttons.append(situation_section)

	var standings_button := Button.new()
	standings_button.text = "局势排名"
	standings_button.pressed.connect(Callable(self, "_open_standings_menu"))
	box.add_child(standings_button)
	menu_regular_buttons.append(standings_button)

	var economy_button := Button.new()
	economy_button.text = "经济总览"
	economy_button.pressed.connect(Callable(self, "_open_economy_overview_menu"))
	box.add_child(economy_button)
	menu_regular_buttons.append(economy_button)

	var intel_button := Button.new()
	intel_button.text = "情报档案"
	intel_button.pressed.connect(Callable(self, "_open_intel_dossier_menu"))
	box.add_child(intel_button)
	menu_regular_buttons.append(intel_button)

	var reference_section := _plain_label("资料", 12, Color("#93c5fd"))
	box.add_child(reference_section)
	menu_regular_buttons.append(reference_section)

	var rules_button := Button.new()
	rules_button.text = "游戏规则"
	rules_button.pressed.connect(Callable(self, "_open_rules_menu"))
	box.add_child(rules_button)
	menu_regular_buttons.append(rules_button)

	var tutorial_button := Button.new()
	tutorial_button.text = "新手引导"
	tutorial_button.pressed.connect(Callable(self, "_open_tutorial_menu"))
	box.add_child(tutorial_button)
	menu_regular_buttons.append(tutorial_button)

	var bestiary_button := Button.new()
	bestiary_button.text = "图鉴"
	bestiary_button.pressed.connect(Callable(self, "_open_compendium_menu"))
	box.add_child(bestiary_button)
	menu_regular_buttons.append(bestiary_button)

	var save_section := _plain_label("存档", 12, Color("#93c5fd"))
	box.add_child(save_section)
	menu_regular_buttons.append(save_section)

	var save_settings_button := Button.new()
	save_settings_button.text = "保存设置"
	save_settings_button.pressed.connect(Callable(self, "_save_settings_from_menu"))
	box.add_child(save_settings_button)
	menu_regular_buttons.append(save_settings_button)

	var save_run_button := Button.new()
	save_run_button.text = "保存局面"
	save_run_button.pressed.connect(Callable(self, "_save_run_from_menu"))
	box.add_child(save_run_button)
	menu_regular_buttons.append(save_run_button)

	var load_run_button := Button.new()
	load_run_button.text = "读取局面"
	load_run_button.pressed.connect(Callable(self, "_load_run_from_menu"))
	box.add_child(load_run_button)
	menu_regular_buttons.append(load_run_button)
	menu_load_run_button = load_run_button

	menu_run_save_label = Label.new()
	menu_run_save_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_run_save_label.add_theme_font_size_override("font_size", 12)
	menu_run_save_label.add_theme_color_override("font_color", Color("#94a3b8"))
	box.add_child(menu_run_save_label)

	var system_section := _plain_label("系统", 12, Color("#93c5fd"))
	box.add_child(system_section)
	menu_regular_buttons.append(system_section)

	var quit_button := Button.new()
	quit_button.text = "退出原型"
	quit_button.pressed.connect(Callable(self, "_quit_game"))
	box.add_child(quit_button)
	menu_regular_buttons.append(quit_button)


func _open_main_menu() -> void:
	_show_menu(
		"太空辛迪加",
		"秘密城市化经营 × 陆海商路 × 怪兽牌匿名战争\n本原型朝PVE roguelike推进：每局3-8个席位，其中2-7个是AI对手。开局先进入准备页查看总席位、AI数量、外星角色卡，并为每名玩家从全部怪兽中任选一只I级怪兽作为起始怪兽牌；玩家从起始怪兽牌开始，把怪兽匿名召唤到星球上。怪兽没有硬上限，也没有玩家常驻可控单位：它们按自身概率自动行动，玩家只能通过一次性卡牌或绑定固定技能影响局势。\n星球每局随机生成陆地与海洋：陆地生产商品，海洋负责运输。城市建筑公开出现，真实业主只对建造者可见；经营周期里AI会按评分匿名扩张和执行商业行动，并记录决策样本供后续训练。玩家需要根据商品竞争、商路和怪兽偏好自行标注推测。经济总览会汇总商品热榜、商路收入前景和玩家经济隐私；情报档案会集中整理城市私标、卡牌竞猜、怪兽资金线索和公开城市线索。\n具体按键、购牌、匿名出牌和竞价细节已收纳到「游戏规则」。",
		true,
		true
	)


func _open_pause_menu() -> void:
	_show_menu(
		"暂停菜单",
		"游戏已暂停。你可以保存/读取当前局面，继续当前局、查看局势排名、经济总览、情报档案、新手引导、图鉴或游戏规则，或重新开一局怪兽牌战争。",
		not game_over,
		true
	)


func _open_help_menu() -> void:
	_open_rules_menu()


func _open_rules_menu() -> void:
	var lines := []
	lines.append("当前原型规则：")
	lines.append("")
	lines.append("1. 身份与AI席位：每局3-8个席位，其中2-7个为AI对手，剩余席位是真人/本地玩家视角。玩家都是外星辛迪加角色；每名玩家开局获得一张角色卡，并在开局准备中从全部怪兽任选一只I级怪兽作为起始怪兽牌；这张起始牌无区域/商品流动门槛，用来把第一只怪兽匿名召唤到星球上。")
	lines.append("2. 怪兽牌：开局不预选四只场上怪兽，怪兽全部来自怪兽牌。怪兽有生命值、移动速度、在场时间、召唤区域限制和自动行动概率；大多数怪兽会活动一段时间后自然离场，即使没有被杀掉。同名怪兽牌可用于升级己方同名在场怪兽，刷新生命值和在场时间。")
	lines.append("3. 星球地图：每局星球随机划分区域并分配陆地/海洋。陆地初始生产1种商品并有1种本地需求；海洋不生产，主要承载商路并影响途经商品运输。后续可用匿名合约牌扩张、替换或删除供需。区域分为生产、交通、消费与均衡倾向；商品流动量由生产/需求关系决定，流动速度由公共交通水平决定，收入最终都折算为GDP现金。")
	lines.append("4. 秘密城市化：玩家花费%d资金在陆地区域城市化。建筑公开冒起，但真实业主只对建造者可见；经营周期中，AI对手会按GDP、商品竞争、交通和怪兽风险评分，自动且匿名地在高价值空地扩张。" % CITY_BUILD_COST)
	lines.append("5. 市场价格：商品价格只能由供给、需求、商路断损、城市经营和经济天气重算，不能被玩家直接指定。扩张城市生产/需求、充实商路、引导怪兽破坏，才会改变市场。")
	lines.append("6. 购牌与升级：卡牌需要花钱购买；默认只能从怪兽落地区或相邻区获取，怪兽所在区域八折，相邻区域原价。角色能力或补给牌可把购牌范围扩到二跳或全局，但会按远程/全局倍率加价；这只影响买牌，不放宽后续怪兽牌的召唤区域。重复获得同系列卡会自动合成到最高IV级，价格仍按I级基础价。普通手牌上限为%d张，绑定固定怪兽技能不占上限。" % PLAYER_HAND_LIMIT)
	lines.append("7. 出牌门槛：I级怪兽牌没有商品流动要求；II-IV级怪兽牌和多数其他牌要求己方城市满足指定商品流动数量，商品不被消耗。少数牌会额外收取现金。")
	lines.append("8. 目标询问：打出需要目标怪兽的牌时，会先询问目标。所有出牌都是匿名事件：一次性指令/诱导、夺取归属或固定技能都只作为行动线索公开，不直接揭示玩家身份，也不让玩家持续操控怪兽。")
	lines.append("9. 手牌消耗：一次性普通牌提交后会先进入顶部匿名卡牌轨道，并立刻离开手牌；它会用提交时的卡牌快照继续等待公开展示与结算。绑定固定怪兽技能不会离手，只在成功结算后进入冷却。")
	lines.append("10. 同时出牌与竞价：空场第一张牌先进入0.5秒同时判定窗。若窗内只有一张，它直接进入自己的5秒公开展示；若出现复数牌，全部暂停结算并开启5秒匿名竞价。报价公开但报价者匿名，可用+10/+20/+50/+100/+200/+500/+1000快速加价；封盘后按报价、同价按参照玩家顺时针席位一次锁定整批顺序，批次中不重拍。封盘或展示期间打出的新牌不会被拒绝，而是集中进入下一批等待区；当前整批清空后只开启一次新竞价。每张有锁定报价的牌轮到展示时，会把小费私密付给它前一张已结算牌的出牌者；若前面没有牌则不支付。")
	lines.append("11. 匿名区域合约：打合约牌前必须先在地图分别点选供给区与需求区。第一段5秒只是把这两个要接通的区域、商品和条款向所有玩家公开展示；展示结束后，目标城市真实业主另有独立5秒签约/拒绝窗口。这个决定窗会持续留在该玩家界面，但不占用全局卡牌展示位，其他玩家可以继续出牌；超时按拒签结算。")
	lines.append("12. 匿名卡牌轨道：顶部轨道保存历史、当前牌和待结算牌，可拖动或滚轮横向查看。当前视角玩家可随时选牌并用玩家头像竞猜归属，每人每张一次、押注¥%d；猜中时牌主付给匿名竞猜者并给卡牌贴公开归属标签，猜错时竞猜者私下付给真实牌主且不揭晓归属。" % CARD_OWNER_GUESS_STAKE)
	lines.append("13. 经济隐私：游戏进行中，每名玩家只能看到自己的现金、资产归属、周期收入、资金轨迹与流水；其他玩家的经济只能推测。终局才公开并按结算资金判胜。")
	lines.append("14. 怪兽战斗线索：怪兽没有硬上限，也没有常驻玩家可控怪兽。怪兽会按自身概率行动、争抢资源、相遇战斗；怪兽受伤时，归属玩家会按怪兽最大生命值损失比例掉钱，从而暴露可推理线索。终局只按结算资金定胜负：猜对存活陌生城市业主获得¥%d情报奖金，猜错支付¥%d错误情报成本。" % [INTEL_CORRECT_GUESS_CASH, INTEL_WRONG_GUESS_COST])
	lines.append("15. 结束条件：本局按Roguelike深度给出目标现金。任一玩家的可见预估结算资金（现金+存活城市清算值；情报现金仍等终局）先达到目标时，开启%.0f秒终局倒计时；倒计时期间只公开“有人达标”，不公开触发者。倒计时不会因触发者被打回目标以下而取消；所有玩家可在最后一分钟反超、破坏或下注。倒计时结束后公开结算资金，谁的钱最多谁赢；若所有区域提前毁灭，也会立刻终局。" % VICTORY_COUNTDOWN_SECONDS)
	lines.append("16. AI训练骨架：AI席位目前会在经营周期里自动建城、需求造势或商路黑客，也会评分购牌、匿名出牌、竞价、合约回应、城市业主推理、卡牌归属押注和怪兽诱导目标；每个AI会维护经济焦点商品，并在扩张焦点、保卫商路、压制竞品三种策略意图之间切换。行动类型、目标、评分、候选集、焦点/策略理由与后续收益都会写入最近决策样本。")
	lines.append("17. 实时节奏：游戏按实时计时推进，不提供1x/2x/4x时间倍率；暂停只用于菜单、读规则和临时观察。")
	lines.append("")
	lines.append("操作入口索引：1-8选席位；Q/E选区；B城市化；G切换推测对象；M标注；R查看/关闭商路；T切换商品；C切换区域补给卡；X购买区域卡；Space暂停；Esc菜单。")
	_show_menu(
		"游戏规则",
		"\n".join(lines),
		not game_over
	)


func _open_tutorial_menu() -> void:
	_show_menu(
		"新手引导",
		"目标：你是太空辛迪加的秘密经营者，要在怪兽战争里建城、藏身份、引导破坏，最后用现金、幸存城市清算价值和情报现金结算；谁的钱最多谁赢。\n\n1. 开局：点「开始新局」后，先选外星角色卡，再从全部怪兽中任选一只I级怪兽作为起始怪兽牌。先把这张起始怪兽牌打出去，第一只怪兽不受区域/商品流动限制；之后摸到的怪兽牌会把生命值、在场时间、移动速度和召唤区域限制写在卡面上。\n2. 找地：陆地可城市化，海洋不能建城但会承载商路；滚轮缩放、拖拽地图，Q/E 选区。\n3. 秘密城市化：选中陆地后按 B 或点「城市化」，花费%d资金建城。建筑公开，但真实业主只对建造者可见；对手也会在经营周期里自动匿名扩张。\n4. 做情报：切到别的玩家视角，用 G 选择推测对象、M 保存私人标注；标注只属于当前玩家，不会揭示真实归属。猜对存活陌生城市业主获得¥%d情报奖金，猜错支付¥%d错误情报成本；区域图鉴会记录匿名需求造势、商路黑客等公开线索。\n5. 经营与商路：城市会生产和需求商品；R/T 查看商品商路。商品流动量看生产与需求，流动速度看沿线公共交通，区域/城市GDP最终变成周期现金。商品当前价随供需和断路波动；产业升级、商品换线、需求改造、交通升级与破坏都会改变经营结果。\n6. 买牌/出牌：C 切换选区补给，X 购买；默认从怪兽落地区或相邻区买牌，落地区八折、相邻区原价，角色/补给牌可临时扩到二跳或全局但会加价，且不改变怪兽召唤限制。价格按I级基础价计费，重复获得同系列卡自动合成升级到IV级但不涨价。普通手牌上限%d张，绑定固定兽技不占上限。I级怪兽牌免商品流动；II-IV级怪兽牌和多数经营牌需要己方城市满足指定商品流动，商品不消耗；需要怪兽目标的牌会先询问目标。\n7. 同时出牌：首牌先等待0.5秒。若复数玩家同时出牌，所有牌先进入5秒匿名竞价，再按报价与顺时针次序锁定整批；整批依次展示结算，中间不再拍卖。\n8. 猜卡牌归属：顶部轨道可左右拖动。随时点选一张牌，再点玩家头像押注¥%d；猜中会公开牌主标签，但竞猜者和转账对象关系仍匿名；猜错不会揭晓牌主。\n9. 保护经济隐私：只看得到自己的现金与账本。对手花了多少、还剩多少，只能结合卡牌、竞价、商品流动条件和地图变化推理。\n10. 借刀杀城：新闻热度、城市价值、商品竞争、商路负载和怪兽资源偏好都会影响怪兽目标。怪兽仍会随机行动，玩家只能用一次性卡牌或怪兽绑定固定技能制造倾斜。" % [
			CITY_BUILD_COST,
			INTEL_CORRECT_GUESS_CASH,
			INTEL_WRONG_GUESS_COST,
			PLAYER_HAND_LIMIT,
			CARD_OWNER_GUESS_STAKE,
		],
		not game_over
	)


func _open_standings_menu() -> void:
	_show_menu("局势排名", _standings_text(), not game_over)


func _open_economy_overview_menu() -> void:
	_mark_opening_guide_economy_seen(selected_player)
	_show_menu("经济总览", _economy_overview_text(), not game_over)


func _open_final_settlement_menu(reason: String, rankings: Array) -> void:
	if menu_overlay == null:
		return
	var body_lines := []
	body_lines.append("游戏结束：%s" % reason)
	body_lines.append("")
	body_lines.append(_final_run_summary_text(rankings))
	body_lines.append("")
	body_lines.append("接下来可以看局势排名确认每席资金来源，或打开经济总览复查 GDP、商品、商路和收入拆解；也可以直接回到开局准备再打一局。")
	_show_menu("终局结算", "\n".join(body_lines), false)
	if menu_continue_button != null:
		menu_continue_button.visible = false
	for button in menu_regular_buttons:
		button.visible = false
	if menu_run_save_label != null:
		menu_run_save_label.visible = false
	if menu_preview_box != null:
		menu_preview_box.visible = true
		_clear_children(menu_preview_box)
		var hint := _plain_label("赛后复盘入口：", 13, Color("#fde68a"))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu_preview_box.add_child(hint)
		_add_compendium_menu_button("查看局势排名", "逐席查看结算资金、现金/城市/情报拆解和终局玩家概览。", Callable(self, "_open_standings_menu"))
		_add_compendium_menu_button("打开经济总览", "复查商品热榜、商路收入前景、城市 GDP 拆解和经济流水。", Callable(self, "_open_economy_overview_menu"))
		_add_compendium_menu_button("开局准备", "重新选择席位、AI 数量、Roguelike 深度和外星角色，开始下一局测试。", Callable(self, "_start_new_run_from_menu"))


func _open_intel_dossier_menu() -> void:
	_show_menu("情报档案", _intel_dossier_text(selected_player), not game_over)
	_populate_intel_dossier_links(selected_player)


func _populate_intel_dossier_links(viewer_index: int) -> void:
	if menu_preview_box == null:
		return
	menu_preview_box.visible = true
	_clear_children(menu_preview_box)
	var hint := _plain_label("线索跳转（只打开相关公开资料，不揭示隐藏真相）：", 12, Color("#fde68a"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_preview_box.add_child(hint)
	var added := 0
	var city_control_entries := []
	var marked_city_entries := []
	var unmarked_city_entries := []
	for entry_variant in _intel_city_guess_entries(viewer_index, 8):
		var city_entry := entry_variant as Dictionary
		if bool(city_entry.get("marked", false)):
			marked_city_entries.append(city_entry)
		else:
			unmarked_city_entries.append(city_entry)
	for marked_entry in marked_city_entries:
		city_control_entries.append(marked_entry)
	for unmarked_entry in unmarked_city_entries:
		city_control_entries.append(unmarked_entry)
	for entry_variant in _first_entries(city_control_entries, 2):
		var control_entry := entry_variant as Dictionary
		var district_index := int(control_entry.get("district_index", -1))
		if district_index < 0:
			continue
		_add_intel_city_guess_buttons(control_entry, viewer_index)
		_add_intel_dossier_link_button(
			"查看区域线索：%s" % String(control_entry.get("name", "城市")),
			"跳到区域图鉴查看该城市的公开供需、收入拆解、公开线索和当前玩家私标状态。",
			Callable(self, "_open_intel_region_codex_link").bind(district_index)
		)
		added += 1
	for entry_variant in _intel_card_guess_entries(viewer_index, 2):
		var entry := entry_variant as Dictionary
		var card_name := String(entry.get("card_name", ""))
		if card_name == "":
			continue
		_add_intel_dossier_link_button(
			"查看卡牌线索：%s" % String(entry.get("card", card_name)),
			"跳到卡牌图鉴查看该匿名卡的目标、出牌条件、价格梯度和结算演出，帮助反推出牌者。",
			Callable(self, "_open_intel_card_codex_link").bind(card_name)
		)
		added += 1
	for entry_variant in _economy_monster_cash_clue_entries(2):
		var entry := entry_variant as Dictionary
		var monster_index := _monster_catalog_index_by_name(String(entry.get("name", "")))
		if monster_index < 0:
			continue
		_add_intel_dossier_link_button(
			"查看怪兽线索：怪%d·%s" % [int(entry.get("slot", 0)) + 1, String(entry.get("name", "怪兽"))],
			"跳到怪兽图鉴查看行动概率、资源偏好和伤害数据，用来判断它为什么袭击某处。",
			Callable(self, "_open_intel_monster_codex_link").bind(monster_index)
		)
		added += 1
	for entry_variant in _economy_city_public_clue_entries(2):
		var entry := entry_variant as Dictionary
		var clue_products: Array = entry.get("clue_products", []) as Array
		if clue_products.is_empty():
			continue
		var product_name := String(clue_products[0])
		if product_name == "" or not PRODUCT_CATALOG.has(product_name):
			continue
		_add_intel_dossier_link_button(
			"查看商品线索：%s" % product_name,
			"跳到商品图鉴查看该商品价格、供需、商路断损、经济天气和相关城市线索。",
			Callable(self, "_open_intel_product_codex_link").bind(product_name)
		)
		added += 1
	if added == 0:
		var empty_hint := _plain_label("当前还没有可跳转线索；先城市化、出牌、竞猜或制造怪兽冲突后这里会出现入口。", 11, Color("#94a3b8"))
		empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu_preview_box.add_child(empty_hint)
	_add_intel_dossier_link_button(
		"打开经济总览",
		"回到经济总览查看商品热榜、商路收入前景和当前玩家经济流水。",
		Callable(self, "_open_economy_overview_menu")
	)


func _add_intel_dossier_link_button(button_text: String, detail_text: String, target: Callable) -> void:
	if menu_preview_box == null:
		return
	var button := Button.new()
	button.text = button_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.tooltip_text = detail_text
	button.pressed.connect(target)
	menu_preview_box.add_child(button)


func _add_intel_city_guess_buttons(entry: Dictionary, viewer_index: int) -> void:
	if menu_preview_box == null or viewer_index < 0 or viewer_index >= players.size():
		return
	var district_index := int(entry.get("district_index", -1))
	if district_index < 0:
		return
	var city_name := String(entry.get("name", "城市"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := _plain_label("标注城市：%s" % _short_event_label(city_name, 9), 11, Color("#c4b5fd"))
	row.add_child(label)
	for player_index in range(players.size()):
		if player_index == viewer_index:
			continue
		var button := Button.new()
		button.text = "标玩家%d" % (player_index + 1)
		button.tooltip_text = "把%s私密标注为玩家%d的城市；终局才结算正误。" % [city_name, player_index + 1]
		button.pressed.connect(Callable(self, "_mark_city_guess_from_intel").bind(district_index, player_index))
		row.add_child(button)
	if bool(entry.get("marked", false)):
		var confidence_label := _plain_label("置信:", 11, Color("#bae6fd"))
		row.add_child(confidence_label)
		for confidence in [CITY_GUESS_CONFIDENCE_LOW, CITY_GUESS_CONFIDENCE_MEDIUM, CITY_GUESS_CONFIDENCE_HIGH]:
			var confidence_button := Button.new()
			confidence_button.text = _city_guess_confidence_label(confidence)
			confidence_button.tooltip_text = "把%s的私人标注置信度设为%s；不改变结算，只用于推理管理。" % [city_name, _city_guess_confidence_label(confidence)]
			confidence_button.pressed.connect(Callable(self, "_set_city_guess_confidence_from_intel").bind(district_index, confidence))
			row.add_child(confidence_button)
		var reason_label := _plain_label("理由:", 11, Color("#bbf7d0"))
		row.add_child(reason_label)
		for reason in _city_guess_reason_options():
			var reason_button := Button.new()
			reason_button.text = _city_guess_reason_label(reason)
			reason_button.tooltip_text = "把%s的私人标注理由记为%s；这只是玩家自己的推理备忘。" % [city_name, _city_guess_reason_label(reason)]
			reason_button.pressed.connect(Callable(self, "_set_city_guess_reason_from_intel").bind(district_index, reason))
			row.add_child(reason_button)
	var clear_button := Button.new()
	clear_button.text = "清除"
	clear_button.tooltip_text = "清除当前玩家对%s的私人城市归属标注。" % city_name
	clear_button.pressed.connect(Callable(self, "_mark_city_guess_from_intel").bind(district_index, -1))
	row.add_child(clear_button)
	menu_preview_box.add_child(row)


func _mark_city_guess_from_intel(city_index: int, guessed_player: int) -> void:
	if _mark_city_guess_for_player(selected_player, city_index, guessed_player):
		selected_district = city_index
		selected_guess_player = guessed_player
		_open_intel_dossier_menu()


func _set_city_guess_confidence_from_intel(city_index: int, confidence: int) -> void:
	if _set_city_guess_confidence_for_player(selected_player, city_index, confidence):
		selected_district = city_index
		_open_intel_dossier_menu()


func _set_city_guess_reason_from_intel(city_index: int, reason: String) -> void:
	if _set_city_guess_reason_for_player(selected_player, city_index, reason):
		selected_district = city_index
		_open_intel_dossier_menu()


func _open_intel_region_codex_link(index: int) -> void:
	catalog_return_menu = "intel"
	if index >= 0:
		region_codex_index = index
	_update_region_codex_menu()


func _open_intel_card_codex_link(card_name: String) -> void:
	catalog_return_menu = "intel"
	_open_card_codex_by_name(card_name)


func _open_intel_monster_codex_link(monster_index: int) -> void:
	catalog_return_menu = "intel"
	_open_bestiary_menu(monster_index)


func _open_intel_product_codex_link(product_name: String) -> void:
	catalog_return_menu = "intel"
	if PRODUCT_CATALOG.has(product_name):
		product_codex_index = PRODUCT_CATALOG.find(product_name)
		previewed_product_codex_index = product_codex_index
		product_codex_grid_page = _product_codex_grid_page_for_index(product_codex_index)
		product_codex_show_detail = true
	_update_product_codex_menu()


func _intel_dossier_text(viewer_index: int) -> String:
	if players.is_empty() or districts.is_empty():
		return "还没有当前局情报。开始新局并城市化、出牌、竞猜或制造怪兽冲突后，情报档案会整理当前玩家可见的推理证据。"
	_refresh_city_networks()
	var viewer_name := String(players[viewer_index].get("name", "玩家%d" % (viewer_index + 1))) if viewer_index >= 0 and viewer_index < players.size() else "无当前玩家"
	var lines := []
	lines.append("当前玩家：%s｜经营周期%d｜当前不揭示正误，不扫描对手现金。" % [
		viewer_name,
		business_cycle_count,
	])
	lines.append("情报换钱：终局资金 = 现金 + 存活城市清算×%d + 城市业主情报现金；猜对陌生城市业主+¥%d，猜错-¥%d。卡牌归属竞猜则即时私下转账¥%d，猜中才公开卡牌主人标签。" % [
		CITY_FINAL_VALUE,
		INTEL_CORRECT_GUESS_CASH,
		INTEL_WRONG_GUESS_COST,
		CARD_OWNER_GUESS_STAKE,
	])
	lines.append("")
	lines.append("城市业主情报：")
	if viewer_index < 0 or viewer_index >= players.size():
		lines.append("- 无当前玩家，无法显示私人城市标注。")
	else:
		lines.append("- %s" % _player_intel_display_summary(viewer_index))
		lines.append("- %s" % _player_city_guess_confidence_summary(viewer_index))
		lines.append("- %s" % _player_city_guess_reason_summary(viewer_index))
		lines.append("- 调查优先级：综合潜在GDP、竞争/断路、公开线索、未标注状态和低置信标注；分数越高，越值得继续查证。")
		var exposure_stats := _player_intel_exposure_stats(viewer_index)
		lines.append("- 终局范围：若全对%s / 若全错%s；进行中只显示私人标注数量和潜在风险。" % [
			_signed_int_text(int(exposure_stats.get("best_cash", 0))),
			_signed_int_text(int(exposure_stats.get("worst_cash", 0))),
		])
		var city_entries := _intel_city_guess_entries(viewer_index, 6)
		if city_entries.is_empty():
			lines.append("- 暂无可竞猜的陌生存活城市；对手匿名扩张或你切换视角后可开始标注。")
		else:
			for entry in city_entries:
				lines.append("- %s" % _intel_city_guess_line(entry as Dictionary))
	lines.append("")
	lines.append("卡牌归属档案：")
	lines.append("- 押注规则：每名玩家每张匿名卡最多押注一次；猜中公开牌主标签并由真实出牌者付款，猜错只私下转账不揭示真相。")
	var card_entries := _intel_card_guess_entries(viewer_index, 5)
	if card_entries.is_empty():
		lines.append("- 暂无匿名卡牌记录；顶部卡牌轨道出现卡牌后会在这里汇总押注状态、公开条件和目标。")
	else:
		for entry in card_entries:
			lines.append("- %s" % _intel_card_guess_line(entry as Dictionary))
	lines.append("")
	lines.append("怪兽资金档案：")
	var monster_entries := _economy_monster_cash_clue_entries(5)
	if monster_entries.is_empty():
		lines.append("- 暂无怪兽受伤资金线索；怪兽受伤后会按最大生命比例暴露归属方资金损失。")
	else:
		for entry in monster_entries:
			lines.append("- %s" % _economy_monster_cash_clue_line(entry as Dictionary))
	lines.append("")
	lines.append("城市公开线索档案：")
	var city_clue_entries := _economy_city_public_clue_entries(6)
	if city_clue_entries.is_empty():
		lines.append("- 暂无城市公开线索；匿名商业动作、合约签拒和城市经营改造会在这里留下证据。")
	else:
		for entry in city_clue_entries:
			lines.append("- %s" % _economy_city_public_clue_line(entry as Dictionary))
	lines.append("")
	lines.append("交叉阅读：先看城市生产/需求和商品竞争，再看卡牌条件、竞价小费、怪兽偏好和城市线索；任何单条证据都只是概率，不是公开真相。")
	return "\n".join(lines)


func _economy_overview_text() -> String:
	if players.is_empty() or districts.is_empty():
		return "还没有当前局经济数据。开始新局后会显示商品热榜、商路收入前景和当前玩家的私密经济账本。"
	_ensure_product_market_catalog()
	_refresh_city_networks()
	var lines := []
	lines.append("经营周期%d｜当前玩家：%s｜场上怪兽：%d只" % [
		business_cycle_count,
		String(players[selected_player].get("name", "玩家")) if selected_player >= 0 and selected_player < players.size() else "无",
		auto_monsters.size(),
	])
	lines.append("商品热榜按当前价偏离、趋势、需求、断路和经济天气综合排序；商路收入前景不揭示隐藏业主，只显示己方/未知/私人推测。情报现金只在终局兑现，私人业主标注不会提前揭示正误。进行中只有当前玩家能看到自己的现金、资产、收入、资金轨迹与流水；其他玩家的经济只能从公开行动推测。")
	lines.append("")
	var product_entries := _economy_product_entries()
	lines.append("商品热榜：")
	for entry in _first_entries(product_entries, 5):
		lines.append("- %s" % _economy_product_line(entry as Dictionary))
	lines.append("")
	var cold_entries := product_entries.duplicate(true)
	cold_entries.sort_custom(Callable(self, "_sort_economy_product_cold_entry"))
	lines.append("低价/供给压制：")
	for entry in _first_entries(cold_entries, 4):
		lines.append("- %s" % _economy_product_line(entry as Dictionary))
	lines.append("")
	var city_entries := _economy_city_income_entries()
	lines.append("商路收入前景：")
	if city_entries.is_empty():
		lines.append("- 暂无存活城市；先城市化陆地区域，经济总览会开始显示城市收入梯度。")
	else:
		for entry in _first_entries(city_entries, 5):
			lines.append("- %s" % _economy_city_income_line(entry as Dictionary))
	lines.append("")
	var card_aftermath_entries := _economy_card_aftermath_entries(5)
	lines.append("最近卡牌余波：")
	if card_aftermath_entries.is_empty():
		lines.append("- 暂无已结算匿名卡牌余波；卡牌结算后会在这里留下地图/经济/怪兽可推理线索。")
	else:
		for entry in card_aftermath_entries:
			lines.append("- %s" % _economy_card_aftermath_line(entry as Dictionary))
	lines.append("")
	var city_clue_entries := _economy_city_public_clue_entries(6)
	lines.append("最近城市公开线索：")
	if city_clue_entries.is_empty():
		lines.append("- 暂无城市公开线索；匿名商业、合约签拒和城市经营改造会在这里累积。")
	else:
		for entry in city_clue_entries:
			lines.append("- %s" % _economy_city_public_clue_line(entry as Dictionary))
	lines.append("")
	var monster_clue_entries := _economy_monster_cash_clue_entries(5)
	lines.append("最近怪兽资金线索：")
	lines.append("怪兽受伤会按最大生命比例折算为归属方资金损失；这里公开损失证据，不公开无关玩家当前现金总额。")
	if monster_clue_entries.is_empty():
		lines.append("- 暂无怪兽受伤资金线索。")
	else:
		for entry in monster_clue_entries:
			lines.append("- %s" % _economy_monster_cash_clue_line(entry as Dictionary))
	lines.append("")
	lines.append("当前玩家推理板：")
	for line in _economy_inference_board_lines(selected_player):
		lines.append("- %s" % line)
	lines.append("")
	lines.append("玩家经济隐私：")
	for entry in _economy_player_cash_entries():
		lines.append("- %s" % _economy_player_cash_line(entry as Dictionary))
	lines.append("")
	lines.append("操作提示：R/T 在地图上查看商品商路；商品催化和共生红利适合追热榜，远期采购/包销协议适合制造持续需求，期货套保适合压供给侧价格和波动，星港快线/供应链保险适合守住高潜在收入城市；短期订单/军需临单/星际会展适合给己方城市做限时现金流。")
	return "\n".join(lines)


func _first_entries(entries: Array, limit: int) -> Array:
	var result := []
	for i in range(min(limit, entries.size())):
		result.append(entries[i])
	return result


func _economy_product_entries() -> Array:
	var entries := []
	for product_variant in PRODUCT_CATALOG:
		var product_name := String(product_variant)
		var entry := _product_market_entry(product_name)
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
			"tier": String(entry.get("tier", _product_tier(product_name))),
			"supply": supply,
			"demand": demand,
			"disrupted": disrupted,
			"volatility": int(entry.get("volatility", 0)),
			"weather": _product_market_boon_text(product_name),
			"status_tags": _product_public_status_tags(product_name),
			"path": _product_price_path_text(entry, 5),
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


func _sort_economy_product_cold_entry(a: Dictionary, b: Dictionary) -> bool:
	var cold_a := int(a.get("cold_score", 0))
	var cold_b := int(b.get("cold_score", 0))
	if cold_a != cold_b:
		return cold_a > cold_b
	var price_a := int(a.get("price", 0))
	var price_b := int(b.get("price", 0))
	if price_a != price_b:
		return price_a < price_b
	return String(a.get("name", "")) < String(b.get("name", ""))


func _economy_product_line(entry: Dictionary) -> String:
	var weather := String(entry.get("weather", "无"))
	if weather == "无":
		weather = "天气无"
	else:
		weather = "天气%s" % weather
	var status_tags: Array = entry.get("status_tags", []) as Array
	var status_text := _public_status_tag_text(status_tags)
	return "%s ¥%d（%s｜偏离%s｜趋势%s｜供%d/需%d/断%d｜波%d｜%s｜公开状态%s｜路径%s）" % [
		String(entry.get("name", "商品")),
		int(entry.get("price", 0)),
		String(entry.get("tier", "未定价")),
		_signed_int_text(int(entry.get("gap", 0))),
		_signed_int_text(int(entry.get("trend", 0))),
		int(entry.get("supply", 0)),
		int(entry.get("demand", 0)),
		int(entry.get("disrupted", 0)),
		int(entry.get("volatility", 0)),
		weather,
		status_text,
		String(entry.get("path", "")),
	]


func _economy_city_income_entries() -> Array:
	var entries := []
	for index_variant in _active_city_district_indices():
		var index := int(index_variant)
		var city := _district_city(index)
		var competition := _city_competition_matches(index)
		var breakdown := _city_cycle_income_breakdown(index, competition)
		var potential_income := int(breakdown.get("net", 0))
		entries.append({
			"district_index": index,
			"name": String(districts[index].get("name", "区域%d" % (index + 1))),
			"owner_view": _city_owner_view_text_for_player(index, selected_player),
			"intel_hint": _city_intel_hint_for_player(index, selected_player),
			"income": potential_income,
			"last_income": int(city.get("last_income", 0)),
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
	var owner := int(city.get("owner", -1))
	if viewer_index >= 0 and viewer_index < players.size() and owner == viewer_index:
		return "己方"
	if viewer_index >= 0 and viewer_index < players.size():
		var guesses: Dictionary = players[viewer_index].get("city_guesses", {})
		var guess := int(guesses.get(city_index, -1))
		if guess >= 0:
			return "我的推测:玩家%d" % (guess + 1)
	return "未知业主"


func _economy_city_income_line(entry: Dictionary) -> String:
	var status_tags: Array = entry.get("status_tags", []) as Array
	return "%s｜%s｜%s｜潜在收入%d｜上次%d｜收入拆解%s｜公开状态%s｜合约%s｜供给%d/%d｜断路%d｜竞争%d｜流通%s｜生产%s｜需求%s" % [
		String(entry.get("name", "城市")),
		String(entry.get("owner_view", "未知业主")),
		String(entry.get("intel_hint", "情报：无")),
		int(entry.get("income", 0)),
		int(entry.get("last_income", 0)),
		String(entry.get("breakdown", "")),
		_public_status_tag_text(status_tags),
		String(entry.get("contract", "无")),
		int(entry.get("supplied", 0)),
		int(entry.get("demand_count", 0)),
		int(entry.get("disrupted", 0)),
		int(entry.get("competition", 0)),
		String(entry.get("flow", "无")),
		_limited_name_list(entry.get("products", []) as Array, 3),
		_limited_name_list(entry.get("demands", []) as Array, 3),
	]


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
		var owner := int(city.get("owner", -1))
		if owner == viewer_index:
			continue
		var guess := int(guesses.get(city_index, -1))
		var marked := guess >= 0 and guess < players.size()
		var competition := _city_competition_matches(city_index)
		var breakdown := _city_cycle_income_breakdown(city_index, competition)
		var result_text := "终局待判"
		if game_over and guess >= 0:
			result_text = "命中+¥%d" % INTEL_CORRECT_GUESS_CASH if guess == owner else "错标-¥%d" % INTEL_WRONG_GUESS_COST
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


func _intel_city_guess_line(entry: Dictionary) -> String:
	var guess := int(entry.get("guess", -1))
	var guess_text := "未标注"
	if guess >= 0 and guess < players.size():
		guess_text = "我的标注:玩家%d" % (guess + 1)
	var confidence_text := _city_guess_confidence_label(int(entry.get("confidence", 0))) if bool(entry.get("marked", false)) else "无"
	var reason_text := _city_guess_reason_label(String(entry.get("reason", ""))) if bool(entry.get("marked", false)) else "无"
	return "%s｜优先级%d｜%s｜置信:%s｜理由:%s｜%s｜%s｜潜在GDP%d/上次%d｜竞争%d/断路%d｜生产:%s｜需求:%s｜最近线索:%s" % [
		String(entry.get("name", "城市")),
		int(entry.get("priority", 0)),
		guess_text,
		confidence_text,
		reason_text,
		String(entry.get("hint", "情报：无")),
		String(entry.get("result", "终局待判")),
		int(entry.get("potential_income", 0)),
		int(entry.get("last_income", 0)),
		int(entry.get("competition", 0)),
		int(entry.get("disrupted", 0)),
		_limited_name_list(entry.get("products", []) as Array, 3, "无"),
		_limited_name_list(entry.get("demands", []) as Array, 3, "无"),
		String(entry.get("latest_clue", "暂无公开线索")),
	]


func _city_intel_priority_score(entry: Dictionary) -> int:
	var score := 0
	score += clampi(int(entry.get("potential_income", 0)) / 10, 0, 80)
	score += clampi(int(entry.get("last_income", 0)) / 20, 0, 30)
	score += int(entry.get("competition", 0)) * 18
	score += int(entry.get("disrupted", 0)) * 16
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


func _player_city_guess_confidence_summary(player_index: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return "置信分布：无当前玩家"
	var player: Dictionary = players[player_index]
	var guesses: Dictionary = player.get("city_guesses", {})
	var confidences: Dictionary = player.get("city_guess_confidence", {})
	var low := 0
	var medium := 0
	var high := 0
	for city_key in guesses.keys():
		var guessed_owner := int(guesses.get(city_key, -1))
		if guessed_owner < 0:
			continue
		match _normalized_city_guess_confidence(int(confidences.get(city_key, CITY_GUESS_CONFIDENCE_DEFAULT))):
			CITY_GUESS_CONFIDENCE_HIGH:
				high += 1
			CITY_GUESS_CONFIDENCE_MEDIUM:
				medium += 1
			_:
				low += 1
	return "置信分布：高%d / 中%d / 低%d｜仅用于玩家自己管理推理，不改变终局奖惩。" % [high, medium, low]


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


func _player_city_guess_reason_summary(player_index: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return "理由分布：无当前玩家"
	var player: Dictionary = players[player_index]
	var guesses: Dictionary = player.get("city_guesses", {})
	var reasons: Dictionary = player.get("city_guess_reasons", {})
	var counts := {}
	for city_key in guesses.keys():
		var guessed_owner := int(guesses.get(city_key, -1))
		if guessed_owner < 0:
			continue
		var reason := _normalized_city_guess_reason(String(reasons.get(city_key, CITY_GUESS_REASON_DEFAULT)))
		counts[reason] = int(counts.get(reason, 0)) + 1
	var pieces := []
	for reason in _city_guess_reason_options():
		var count := int(counts.get(reason, 0))
		if count > 0:
			pieces.append("%s%d" % [_city_guess_reason_label(reason), count])
	return "理由分布：%s｜只是私人推理备忘，不验证正误。" % (" / ".join(pieces) if not pieces.is_empty() else "暂无")


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
		var owner_index := int(entry.get("player_index", -1))
		var owner_revealed := bool(entry.get("public_owner_revealed", false))
		var guessers: Array = entry.get("guessers", []) as Array
		var known_owner := _private_known_card_owner_for_entry(viewer_index, entry)
		var status := "归属未知，可押注¥%d" % _card_owner_guess_stake_for_player(viewer_index)
		if owner_revealed:
			status = String(entry.get("public_owner_label", "归属已公开"))
		elif known_owner >= 0 and known_owner < players.size():
			status = "我已查明：玩家%d｜尚未公开" % (known_owner + 1)
		elif viewer_index == owner_index:
			status = "我打出的牌｜仅当前视角可知"
		elif viewer_index >= 0 and guessers.has(viewer_index):
			status = "我已押注｜真实归属仍隐藏"
		var time_value := float(entry.get("resolved_time", entry.get("queued_order", -1.0)))
		entries.append({
			"card": _card_resolution_entry_card_label(entry),
			"card_name": card_name,
			"status": status,
			"target": _card_resolution_target_text(skill, entry),
			"requirement": _card_resolution_play_requirement_text(entry).replace("打出条件：", ""),
			"tip": _card_resolution_tip_clue_text(entry),
			"time": time_value,
			"revealed": owner_revealed,
		})
	entries.sort_custom(Callable(self, "_sort_intel_card_guess_entry"))
	return _first_entries(entries, limit)


func _sort_intel_card_guess_entry(a: Dictionary, b: Dictionary) -> bool:
	var a_time := float(a.get("time", -1.0))
	var b_time := float(b.get("time", -1.0))
	if not is_equal_approx(a_time, b_time):
		return a_time > b_time
	return String(a.get("card", "")) < String(b.get("card", ""))


func _intel_card_guess_line(entry: Dictionary) -> String:
	var tip := String(entry.get("tip", ""))
	var tip_text := "｜小费线索:%s" % tip if tip != "" else ""
	return "%s｜%s｜条件:%s｜目标:%s%s" % [
		String(entry.get("card", "匿名卡牌")),
		String(entry.get("status", "归属未知")),
		String(entry.get("requirement", "未知")),
		String(entry.get("target", "目标未知")),
		tip_text,
	]


func _public_status_tag_text(tags: Array) -> String:
	if tags.is_empty():
		return "[无持续状态]"
	var pieces := []
	for tag_variant in tags:
		var tag := String(tag_variant)
		if tag != "":
			pieces.append(tag)
	if pieces.is_empty():
		return "[无持续状态]"
	return "[%s]" % "｜".join(pieces)


func _product_public_status_tags(product_name: String) -> Array:
	var entry := _product_market_entry(product_name)
	if entry.is_empty():
		return []
	var tags := []
	var growth_multiplier := float(entry.get("growth_multiplier", 1.0))
	if growth_multiplier > 1.001:
		tags.append("增速×%.2f/%s" % [
			growth_multiplier,
			_boon_turn_text(int(entry.get("growth_turns", 0))),
		])
	var route_multiplier := float(entry.get("route_flow_multiplier", 1.0))
	if route_multiplier > 1.001:
		tags.append("商路×%.2f/%s" % [
			route_multiplier,
			_boon_turn_text(int(entry.get("route_flow_turns", 0))),
		])
	var contract_turns := int(entry.get("market_contract_turns", 0))
	var contract_demand := int(entry.get("market_contract_demand", 0))
	var contract_supply := int(entry.get("market_contract_supply", 0))
	if contract_turns > 0 and (contract_demand > 0 or contract_supply > 0):
		var pressure_parts := []
		if contract_demand > 0:
			pressure_parts.append("需+%d" % contract_demand)
		if contract_supply > 0:
			pressure_parts.append("供+%d" % contract_supply)
		tags.append("商品合约%s/%s" % [
			"/".join(pressure_parts),
			_boon_turn_text(contract_turns),
		])
	var volatility := int(entry.get("volatility", 0))
	if volatility >= 12:
		tags.append("高波动%d" % volatility)
	return tags


func _city_public_status_tags(city: Dictionary) -> Array:
	var tags := []
	var contract_income := int(city.get("contract_income_bonus", 0))
	if contract_income > 0:
		tags.append("城市合约+%d/%s" % [
			contract_income,
			_boon_turn_text(int(city.get("contract_turns", 0))),
		])
	var route_multiplier := float(city.get("route_flow_multiplier", 1.0))
	if route_multiplier > 1.001:
		tags.append("流通×%.2f/%s" % [
			route_multiplier,
			_boon_turn_text(int(city.get("route_flow_turns", 0))),
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
		var style := String(entry.get("aftermath_style", _card_resolution_effect_style(skill)))
		entries.append({
			"card": card_label,
			"style": _card_resolution_effect_style_label(style),
			"clue": clue,
			"tip_clue": _card_resolution_tip_clue_text(entry),
			"target": _card_resolution_target_text(skill, entry),
			"resolved_time": float(entry.get("resolved_time", -1.0)),
			"owner_known": bool(entry.get("public_owner_revealed", false)),
		})
	return entries


func _economy_card_aftermath_line(entry: Dictionary) -> String:
	var time_text := "时间未知"
	var resolved_time := float(entry.get("resolved_time", -1.0))
	if resolved_time >= 0.0:
		time_text = "T+%.1fs" % resolved_time
	var owner_text := "归属已公开" if bool(entry.get("owner_known", false)) else "归属未知"
	var tip_clue := String(entry.get("tip_clue", ""))
	var tip_text := "｜竞价:%s" % tip_clue if tip_clue != "" else ""
	return "%s｜%s演出｜%s｜%s｜%s｜线索:%s%s" % [
		time_text,
		String(entry.get("style", "卡牌")),
		String(entry.get("card", "匿名卡牌")),
		String(entry.get("target", "目标未知")),
		owner_text,
		String(entry.get("clue", "公开结果留下匿名推理痕迹")),
		tip_text,
	]


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
	for slot in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[slot]
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


func _economy_monster_cash_clue_line(entry: Dictionary) -> String:
	var time_text := "等待伤害"
	var recent_time := float(entry.get("recent_time", -1.0))
	if recent_time >= 0.0:
		time_text = "T+%.1fs" % recent_time
	var recent_loss := int(entry.get("recent_loss", 0))
	var recent_damage := int(entry.get("recent_damage", 0))
	var recent_source := String(entry.get("recent_source", ""))
	var recent_text := "最近未产生现金损失"
	if recent_loss > 0:
		recent_text = "最近损失¥%d/%d伤害" % [recent_loss, recent_damage]
		if recent_source != "":
			recent_text += "（%s）" % recent_source
	var state_text := "倒地" if bool(entry.get("down", false)) else "在场"
	return "%s｜怪%d·%s%s｜%s｜%s｜累计损失¥%d｜资金池余¥%d/%d｜%s｜线索:%s" % [
		time_text,
		int(entry.get("slot", 0)) + 1,
		String(entry.get("name", "怪兽")),
		_level_text(clampi(int(entry.get("rank", 1)), 1, 4)),
		String(entry.get("owner_text", "归属未公开")),
		recent_text,
		int(entry.get("total_lost", 0)),
		int(entry.get("cash_pool", 0)),
		int(entry.get("cash_total", 0)),
		state_text,
		String(entry.get("clue", "暂无公开资金线索")),
	]


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
		var owner := int(city.get("owner", -1))
		if owner == viewer_index:
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
		var owner := int(entry.get("player_index", -1))
		if owner < 0 or owner >= players.size():
			continue
		counts[owner] = int(counts.get(owner, 0)) + 1
		if not examples.has(owner):
			examples[owner] = []
		var owner_examples: Array = examples[owner]
		if owner_examples.size() < 2:
			owner_examples.append(_card_resolution_entry_card_label(entry))
			examples[owner] = owner_examples
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
	if not active_card_resolution.is_empty():
		entries.append(active_card_resolution)
	for entry_variant in card_resolution_queue:
		if entry_variant is Dictionary:
			entries.append(entry_variant)
	for entry_variant in next_card_resolution_queue:
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
	return "卡牌条件反推｜%s｜只对照我方当前流动，不扫描对手经济" % "；".join(pieces)


func _recent_card_requirement_entries(limit: int = 3) -> Array:
	var entries := []
	if not active_card_resolution.is_empty():
		entries.append(active_card_resolution)
	for entry_variant in card_resolution_queue:
		if entries.size() >= limit:
			return entries
		if entry_variant is Dictionary:
			entries.append(entry_variant)
	for entry_variant in next_card_resolution_queue:
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
	var owner_text := "归属未知"
	if bool(entry.get("public_owner_revealed", false)):
		var owner_index := int(entry.get("player_index", -1))
		if owner_index >= 0 and owner_index < players.size():
			owner_text = "归属玩家%d" % (owner_index + 1)
	var required := int(entry.get("play_requirement_flow", _skill_play_flow_required(skill)))
	var cash_cost := int(entry.get("play_cash_cost", _skill_play_cash_cost(skill)))
	var requirement_text := "免商品门槛"
	if required > 0:
		var product_name := _card_requirement_product_for_entry(entry, skill, viewer_index)
		var available := _player_product_flow(viewer_index, product_name)
		var availability_text := "我方满足%d/%d" % [available, required] if available >= required else "我方不足%d/%d" % [available, required]
		requirement_text = "%s流动≥%d｜%s" % [product_name, required, availability_text]
	if cash_cost > 0:
		requirement_text += "｜额外¥%d" % cash_cost
	return "%s:%s｜%s" % [
		_short_event_label(card_label, 10),
		requirement_text,
		owner_text,
	]


func _card_requirement_product_for_entry(entry: Dictionary, skill: Dictionary, viewer_index: int) -> String:
	return _card_resolution_requirement_product_snapshot(entry, skill, viewer_index)


func _economy_inference_public_monster_owner_line() -> String:
	var counts := {}
	var examples := {}
	for slot in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[slot]
		var owner := int(actor.get("owner", -1))
		if not bool(actor.get("owner_revealed", false)) or owner < 0 or owner >= players.size():
			continue
		counts[owner] = int(counts.get(owner, 0)) + 1
		if not examples.has(owner):
			examples[owner] = []
		var owner_examples: Array = examples[owner]
		if owner_examples.size() < 2:
			owner_examples.append("%s%s累计¥%d" % [
				String(actor.get("name", "怪兽")),
				_level_text(clampi(int(actor.get("rank", 1)), 1, 4)),
				int(actor.get("owner_damage_cash_lost", 0)),
			])
			examples[owner] = owner_examples
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
			"score": _player_visible_settlement_estimate(i),
			"score_label": "结算资金" if game_over else "可见预估",
			"intel_summary": _player_intel_display_summary(i),
			"last_cycle": int(player.get("last_cycle_income", 0)),
			"role_income": int(player.get("total_role_income", 0)),
			"cycle_income": _player_cycle_income(i),
			"recent_delta": _player_recent_cash_delta(player),
			"window_delta": _player_cash_window_delta(player),
			"path": _player_cash_path_text(player, 6),
			"ledger": _player_economic_ledger_text(player, 2) if i == selected_player else "私人账本（不公开）",
			"city_count": _player_active_city_count(i),
			"private": not game_over and i != selected_player,
		})
	if game_over:
		entries.sort_custom(Callable(self, "_sort_economy_player_cash_entry"))
	return entries


func _sort_economy_player_cash_entry(a: Dictionary, b: Dictionary) -> bool:
	var score_a := int(a.get("score", 0))
	var score_b := int(b.get("score", 0))
	if score_a != score_b:
		return score_a > score_b
	return String(a.get("name", "")) < String(b.get("name", ""))


func _economy_player_cash_line(entry: Dictionary) -> String:
	if bool(entry.get("private", false)):
		return "%s｜现金、结算预估、城市资产、周期收入、资金轨迹与流水均为私人信息；只能从公开行动自行推测。" % String(entry.get("name", "玩家"))
	return "%s｜%s%d｜现金%d｜城市%d｜%s｜上次周期%s｜角色累计+%d｜潜在周期%d｜最近%s｜窗口%s｜轨迹%s｜流水%s" % [
		String(entry.get("name", "玩家")),
		String(entry.get("score_label", "可见预估")),
		int(entry.get("score", 0)),
		int(entry.get("cash", 0)),
		int(entry.get("city_count", 0)),
		String(entry.get("intel_summary", "")),
		_signed_int_text(int(entry.get("last_cycle", 0))),
		int(entry.get("role_income", 0)),
		int(entry.get("cycle_income", 0)),
		_signed_int_text(int(entry.get("recent_delta", 0))),
		_signed_int_text(int(entry.get("window_delta", 0))),
		String(entry.get("path", "")),
		String(entry.get("ledger", "暂无")),
	]


func _open_compendium_menu() -> void:
	catalog_return_menu = "main"
	_show_menu(
		"图鉴",
		"统一资料库：角色图鉴、怪兽图鉴、卡牌图鉴、商品图鉴、区域图鉴都从这里进入。这里展示公开资料和当前局面可见信息；秘密城市真实业主仍需要玩家自己推理和标注。",
		false
	)
	menu_catalog_mode = "compendium"
	menu_continue_button.visible = false
	for button in menu_regular_buttons:
		button.visible = false
	if menu_run_save_label != null:
		menu_run_save_label.visible = false
	if menu_preview_box != null:
		menu_preview_box.visible = true
		_clear_children(menu_preview_box)
		var hint := _plain_label("选择要查看的子图鉴：", 13, Color("#cbd5e1"))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu_preview_box.add_child(hint)
		_add_compendium_menu_button("角色图鉴", "查看外星辛迪加角色卡、种族特征和起始怪兽牌。", Callable(self, "_open_role_codex_from_compendium"))
		_add_compendium_menu_button("怪兽图鉴", "查看怪兽属性、自动行动表、资源偏好和对应怪兽牌。", Callable(self, "_open_bestiary_from_compendium"))
		_add_compendium_menu_button("卡牌图鉴", "查看所有卡牌规则、目标需求、价格梯度和卡面预览。", Callable(self, "_open_card_codex_from_compendium"))
		_add_compendium_menu_button("商品图鉴", "查看外星商品价格梯度、本局供需、趋势和商路断损。", Callable(self, "_open_product_codex_menu"))
		_add_compendium_menu_button("区域图鉴", "查看本局每个区域的地形、供需、城市公开状态和可提供卡牌。", Callable(self, "_open_region_codex_menu"))
		var back_button := Button.new()
		back_button.text = "返回主菜单"
		back_button.pressed.connect(Callable(self, "_open_main_menu"))
		menu_preview_box.add_child(back_button)


func _add_compendium_menu_button(button_text: String, detail_text: String, target: Callable) -> void:
	if menu_preview_box == null:
		return
	var button := Button.new()
	button.text = "%s  —  %s" % [button_text, detail_text]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.tooltip_text = detail_text
	button.pressed.connect(target)
	menu_preview_box.add_child(button)


func _standings_text() -> String:
	if players.is_empty():
		return "还没有可用玩家数据。开始新局后会显示当前资金、存活城市、情报标注和预估结算资金。"
	_refresh_city_networks()
	var lines := []
	lines.append("预估结算资金 = 当前资金 + 存活城市清算×%d + 情报现金。猜对陌生城市业主+¥%d，猜错-¥%d。" % [
		CITY_FINAL_VALUE,
		INTEL_CORRECT_GUESS_CASH,
		INTEL_WRONG_GUESS_COST,
	])
	lines.append("经营周期：%d｜实时结算｜场上怪兽：%d只" % [
		business_cycle_count,
		auto_monsters.size(),
	])
	lines.append(_victory_countdown_status_text())
	lines.append("")
	var standings := _standing_entries()
	for rank in range(standings.size()):
		var entry: Dictionary = standings[rank]
		var entry_player_index := int(entry.get("player_index", rank))
		if not game_over and entry_player_index != selected_player:
			lines.append("玩家%d. %s｜进行中经济与资产归属保密，名次只能推测。" % [entry_player_index + 1, String(entry.get("name", "玩家"))])
			continue
		var score_label := String(entry.get("score_label", "可见预估"))
		var intel_component := _signed_int_text(int(entry.get("intel_cash", 0))) if game_over else "待结算"
		lines.append("%d. %s  %s%d = 现金%d + 存活城市%d×%d + 情报%s｜本周期潜在收入%d｜累计经营%d｜已建%d座｜%s" % [
			rank + 1,
			String(entry.get("name", "玩家")),
			score_label,
			int(entry.get("score", 0)),
			int(entry.get("cash", 0)),
			int(entry.get("active_cities", 0)),
			CITY_FINAL_VALUE,
			intel_component,
			int(entry.get("cycle_income", 0)),
			int(entry.get("total_income", 0)),
			int(entry.get("cities_built", 0)),
			String(entry.get("intel_summary", "")),
		])
	lines.append("")
	lines.append("提示：领先者通常更怕商路被切断；落后者可以用热度、怪兽目标偏好和商品竞争把压力引到对手城市。")
	if game_over:
		lines.append("")
		lines.append(_final_run_summary_text(_final_score_rankings()))
	return "\n".join(lines)


func _standing_entries() -> Array:
	var entries := []
	for i in range(players.size()):
		var player: Dictionary = players[i]
		var active_city_count := _player_active_city_count(i)
		var cycle_income := _player_cycle_income(i)
		var intel_stats := _player_intel_stats(i)
		var intel_cash := int(intel_stats.get("cash", 0))
		entries.append({
			"player_index": i,
			"name": String(player.get("name", "玩家%d" % (i + 1))),
			"cash": int(player.get("cash", 0)),
			"active_cities": active_city_count,
			"score": _player_visible_settlement_estimate(i),
			"score_label": "结算资金" if game_over else "可见预估",
			"intel_cash": intel_cash if game_over else 0,
			"intel_summary": _player_intel_display_summary(i),
			"cycle_income": cycle_income,
			"total_income": int(player.get("total_city_income", 0)),
			"cities_built": int(player.get("cities_built", 0)),
		})
	if game_over:
		entries.sort_custom(Callable(self, "_sort_standing_entry"))
	return entries


func _sort_standing_entry(a: Dictionary, b: Dictionary) -> bool:
	var score_a := int(a.get("score", 0))
	var score_b := int(b.get("score", 0))
	if score_a != score_b:
		return score_a > score_b
	var cash_a := int(a.get("cash", 0))
	var cash_b := int(b.get("cash", 0))
	if cash_a != cash_b:
		return cash_a > cash_b
	var cities_a := int(a.get("active_cities", 0))
	var cities_b := int(b.get("active_cities", 0))
	if cities_a != cities_b:
		return cities_a > cities_b
	return int(a.get("player_index", 0)) < int(b.get("player_index", 0))


func _top_player_by_stat(stat_name: String) -> Dictionary:
	var best := {"player_index": -1, "amount": -999999}
	for i in range(players.size()):
		var player: Dictionary = players[i]
		var amount := int(player.get(stat_name, 0))
		if amount > int(best.get("amount", -999999)):
			best = {"player_index": i, "amount": amount}
	if int(best.get("player_index", -1)) < 0 and not players.is_empty():
		best = {"player_index": 0, "amount": 0}
	return best


func _top_city_snapshot_entry() -> Dictionary:
	var best := {"district": -1, "owner": -1, "last_income": -999999, "active": false}
	var best_score := -999999
	for i in range(districts.size()):
		var city := _district_city(i)
		if city.is_empty() or int(city.get("owner", -1)) < 0:
			continue
		var income := int(city.get("last_income", 0))
		var score := income
		if bool(city.get("active", true)):
			score += CITY_FINAL_VALUE / 2
		score += (city.get("products", []) as Array).size() * 12
		score += (city.get("demands", []) as Array).size() * 8
		if score > best_score:
			best_score = score
			best = {
				"district": i,
				"owner": int(city.get("owner", -1)),
				"last_income": income,
				"active": bool(city.get("active", true)),
				"products": _city_product_names(city),
				"demands": _city_demand_names(city),
			}
	return best


func _destroyed_district_count() -> int:
	var count := 0
	for district_variant in districts:
		var district: Dictionary = district_variant
		if bool(district.get("destroyed", false)):
			count += 1
	return count


func _card_impact_score(skill: Dictionary, entry: Dictionary) -> int:
	var score := maxi(1, _skill_rank(String(skill.get("name", "")))) * 10
	for key in ["cash", "revenue_amount", "damage", "route_damage", "repair_routes", "production_delta", "transport_delta", "consumption_delta", "market_demand_pressure", "market_supply_pressure", "draw_amount", "accept_cash", "decline_cash_penalty", "decline_route_damage", "gdp_bet_destroy_bonus"]:
		score += abs(int(skill.get(String(key), 0)))
	score += int(round(absf(float(skill.get("gdp_bet_multiplier", 0.0))) * 80.0))
	score += int(entry.get("winning_bid", entry.get("tip", 0))) / 5
	return score


func _top_card_impact_summary(limit: int = 3) -> String:
	if resolved_card_history.is_empty():
		return "关键卡牌：本局还没有已结算卡牌。"
	var stats := {}
	for entry_variant in resolved_card_history:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var skill: Dictionary = entry.get("skill", {}) as Dictionary
		var card_name := String(skill.get("name", "匿名卡牌"))
		var label := _card_display_name(card_name)
		if label == "":
			label = card_name
		var stat := (stats.get(label, {"name": label, "count": 0, "score": 0}) as Dictionary).duplicate(true)
		stat["count"] = int(stat.get("count", 0)) + 1
		stat["score"] = int(stat.get("score", 0)) + _card_impact_score(skill, entry)
		stats[label] = stat
	var ranked := []
	for key_variant in stats.keys():
		ranked.append(stats[key_variant])
	ranked.sort_custom(Callable(self, "_sort_ai_candidate_score_desc"))
	var pieces := []
	for i in range(mini(limit, ranked.size())):
		var stat := ranked[i] as Dictionary
		pieces.append("%s×%d" % [String(stat.get("name", "卡牌")), int(stat.get("count", 0))])
	return "关键卡牌：%s。" % "、".join(pieces)


func _monster_impact_summary() -> String:
	if auto_monsters.is_empty():
		return "怪兽影响：终局时场上没有怪兽。"
	var ranked := []
	for actor_variant in auto_monsters:
		if not (actor_variant is Dictionary):
			continue
		var actor := actor_variant as Dictionary
		var score := int(actor.get("owner_damage_cash_lost", 0)) + maxi(0, int(actor.get("max_hp", 0)) - int(actor.get("hp", 0))) * 12
		if bool(actor.get("down", false)):
			score += 60
		ranked.append({
			"score": score,
			"name": String(actor.get("name", "怪兽")),
			"rank": int(actor.get("rank", 1)),
			"lost": int(actor.get("owner_damage_cash_lost", 0)),
			"source": String(actor.get("last_owner_damage_source", "")),
			"focus": actor.get("resource_focus", []) as Array,
			"down": bool(actor.get("down", false)),
		})
	if ranked.is_empty():
		return "怪兽影响：终局时场上没有可统计怪兽。"
	ranked.sort_custom(Callable(self, "_sort_ai_candidate_score_desc"))
	var top := ranked[0] as Dictionary
	var state_text := "倒地" if bool(top.get("down", false)) else "存活"
	var source_text := String(top.get("source", ""))
	var source_suffix := "，最近线索:%s" % source_text if source_text != "" else ""
	return "怪兽影响：%s%s级%s，已触发归属资金损失¥%d，偏好:%s%s。" % [
		String(top.get("name", "怪兽")),
		_roman_level(int(top.get("rank", 1))),
		state_text,
		int(top.get("lost", 0)),
		_limited_name_list(top.get("focus", []) as Array, 3, "无"),
		source_suffix,
	]


func _ai_route_summary(limit: int = 3) -> String:
	var pieces := []
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		var player: Dictionary = players[player_index]
		var memory := (player.get("ai_memory", {}) as Dictionary)
		var product := String(memory.get("route_plan_product", ""))
		var stage := String(memory.get("route_plan_stage", ""))
		var intent := String(memory.get("strategic_intent", ""))
		if product == "" and intent == "":
			continue
		pieces.append("%s:%s/%s/%s" % [
			_player_name(player_index),
			product if product != "" else "未定商品",
			_ai_route_plan_stage_label(stage),
			_ai_strategy_intent_label(intent),
		])
		if pieces.size() >= limit:
			break
	if pieces.is_empty():
		return "AI路线：本局AI尚未留下稳定路线记录。"
	return "AI路线：%s。" % "；".join(pieces)


func _player_final_playstyle_summary(player_index: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return "未知路线"
	var player: Dictionary = players[player_index]
	if not bool(player.get("is_ai", false)):
		return "真人/本地玩家"
	var memory := (player.get("ai_memory", {}) as Dictionary)
	var product := String(memory.get("route_plan_product", ""))
	var stage := String(memory.get("route_plan_stage", ""))
	var intent := String(memory.get("strategic_intent", ""))
	return "AI:%s/%s/%s" % [
		product if product != "" else "未定商品",
		_ai_route_plan_stage_label(stage),
		_ai_strategy_intent_label(intent),
	]


func _final_player_breakdown_summary(rankings: Array, limit: int = 8) -> String:
	if players.is_empty():
		return "玩家概览：没有可用玩家。"
	var ordered := rankings
	if ordered.is_empty():
		ordered = _final_score_rankings()
	var pieces := []
	for rank in range(mini(limit, ordered.size())):
		var entry := ordered[rank] as Dictionary
		var player_index := int(entry.get("player_index", rank))
		if player_index < 0 or player_index >= players.size():
			continue
		var player: Dictionary = players[player_index]
		pieces.append("#%d %s ¥%d｜城收¥%d｜卡牌¥%d｜情报%s｜角色¥%d｜城%d｜%s" % [
			rank + 1,
			_player_name(player_index),
			int(entry.get("score", _player_final_score(player_index))),
			maxi(0, int(player.get("total_city_income", 0))),
			maxi(0, int(player.get("total_card_income", 0))),
			_signed_int_text(_player_intel_cash(player_index)),
			maxi(0, int(player.get("total_role_income", 0))),
			_player_active_city_count(player_index),
			_player_final_playstyle_summary(player_index),
		])
	if pieces.is_empty():
		return "玩家概览：没有可显示玩家。"
	return "玩家概览：%s。" % "；".join(pieces)


func _final_run_summary_text(rankings: Array) -> String:
	if players.is_empty():
		return "终局总结：没有可用玩家数据。"
	var ordered := rankings
	if ordered.is_empty():
		ordered = _final_score_rankings()
	var winner_index := 0
	var winner_score := _player_final_score(0)
	if not ordered.is_empty():
		var winner := ordered[0] as Dictionary
		winner_index = int(winner.get("player_index", 0))
		winner_score = int(winner.get("score", winner_score))
	var city_income := _top_player_by_stat("total_city_income")
	var card_income := _top_player_by_stat("total_card_income")
	var role_income := _top_player_by_stat("total_role_income")
	var top_city := _top_city_snapshot_entry()
	var lines := []
	lines.append("终局总结：%s获胜，结算资金¥%d；胜负按现金 + 存活城市清算 + 情报现金。" % [
		_player_name(winner_index),
		winner_score,
	])
	lines.append("钱从哪里来：城市经营最高%s累计¥%d；卡牌/情报收益最高%s累计¥%d；角色收益最高%s累计¥%d。" % [
		_player_name(int(city_income.get("player_index", 0))),
		maxi(0, int(city_income.get("amount", 0))),
		_player_name(int(card_income.get("player_index", 0))),
		maxi(0, int(card_income.get("amount", 0))),
		_player_name(int(role_income.get("player_index", 0))),
		maxi(0, int(role_income.get("amount", 0))),
	])
	lines.append("地图影响：存活城市%d座，已毁区域%d个，怪兽在场%d/%d；破坏和商路损伤最终都会反映到GDP变化。" % [
		_active_city_district_indices().size(),
		_destroyed_district_count(),
		_active_auto_monster_count(),
		auto_monsters.size(),
	])
	lines.append(_top_card_impact_summary())
	lines.append(_monster_impact_summary())
	lines.append(_ai_route_summary(maxi(3, _ai_player_indices().size())))
	lines.append(_final_player_breakdown_summary(ordered, maxi(3, players.size())))
	if int(top_city.get("district", -1)) >= 0:
		var district_index := int(top_city.get("district", -1))
		lines.append("关键城市：%s（%s）末期GDP¥%d，供:%s，需:%s。" % [
			String(districts[district_index].get("name", "未知区域")),
			_player_name(int(top_city.get("owner", -1))),
			maxi(0, int(top_city.get("last_income", 0))),
			_limited_name_list(top_city.get("products", []) as Array, 3, "无"),
			_limited_name_list(top_city.get("demands", []) as Array, 3, "无"),
		])
	return "\n".join(lines)


func _player_cycle_income(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var total := 0
	for index_variant in _active_city_district_indices():
		var index := int(index_variant)
		var city := _district_city(index)
		if int(city.get("owner", -1)) != player_index:
			continue
		total += _city_cycle_income(index, int(city.get("competition_matches", _city_competition_matches(index))))
	return total


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
		var owner := int(city.get("owner", -1))
		if owner < 0 or owner == player_index:
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
		if guessed_owner == owner:
			stats["correct"] = int(stats["correct"]) + 1
		else:
			stats["wrong"] = int(stats["wrong"]) + 1
	var role := _player_role_card_for_index(player_index)
	var correct_reward := INTEL_CORRECT_GUESS_CASH + maxi(0, int(role.get("city_guess_reward_bonus", 0)))
	stats["correct_reward"] = correct_reward
	stats["cash"] = int(stats["correct"]) * correct_reward - int(stats["wrong"]) * INTEL_WRONG_GUESS_COST
	return stats


func _player_intel_cash(player_index: int) -> int:
	return int(_player_intel_stats(player_index).get("cash", 0))


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
		var owner := int(city.get("owner", -1))
		if owner < 0 or owner == player_index:
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
	return _player_intel_summary(player_index) if game_over else _player_intel_pending_summary(player_index)


func _player_intel_hud_text(player_index: int) -> String:
	if game_over:
		return "情报现金:%s" % _signed_int_text(_player_intel_cash(player_index))
	var stats := _player_intel_exposure_stats(player_index)
	return "情报待结算:%d/%d" % [
		int(stats.get("guessed", 0)),
		int(stats.get("total_foreign", 0)),
	]


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
	var owner := int(city.get("owner", -1))
	if owner == viewer_index:
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


func _player_visible_settlement_estimate(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var intel_cash := _player_intel_cash(player_index) if game_over else 0
	return int(players[player_index].get("cash", 0)) + _player_active_city_count(player_index) * CITY_FINAL_VALUE + intel_cash


func _player_name(player_index: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return "未知玩家"
	return String((players[player_index] as Dictionary).get("name", "玩家%d" % (player_index + 1)))


func _victory_countdown_status_text() -> String:
	if not victory_countdown_active:
		return "终局倒计时：未触发｜目标现金¥%d" % _roguelike_cash_goal()
	return "终局倒计时：%.0fs｜触发者匿名｜目标¥%d" % [
		ceil(victory_countdown_timer),
		_roguelike_cash_goal(),
	]


func _victory_countdown_trigger_candidate() -> Dictionary:
	var cash_goal := _roguelike_cash_goal()
	var best := {"player_index": -1, "score": cash_goal - 1}
	for i in range(players.size()):
		var score := _player_visible_settlement_estimate(i)
		if score >= cash_goal and score > int(best.get("score", cash_goal - 1)):
			best = {"player_index": i, "score": score}
	return best


func _start_victory_countdown(player_index: int, score: int) -> void:
	if victory_countdown_active or game_over:
		return
	victory_countdown_active = true
	victory_countdown_timer = VICTORY_COUNTDOWN_SECONDS
	victory_countdown_trigger_player = player_index
	victory_countdown_trigger_score = score
	_log("有玩家达到本层目标现金线：可见预估结算已不低于目标¥%d。终局倒计时%.0f秒开始，触发者保持匿名；倒计时结束按结算资金最高者定胜负。" % [
		_roguelike_cash_goal(),
		VICTORY_COUNTDOWN_SECONDS,
	])
	if player_index >= 0 and player_index < players.size():
		_add_action_callout(
			"终局警报",
			"目标现金达成",
			"有玩家触发%.0f秒终局倒计时；所有玩家仍可反超或破坏。" % VICTORY_COUNTDOWN_SECONDS,
			Color("#facc15"),
			_district_center(selected_district)
		)
	_refresh_ui()


func _update_victory_countdown(delta: float) -> void:
	if game_over or players.is_empty():
		return
	if not victory_countdown_active:
		var trigger := _victory_countdown_trigger_candidate()
		var trigger_player := int(trigger.get("player_index", -1))
		if trigger_player >= 0:
			_start_victory_countdown(trigger_player, int(trigger.get("score", 0)))
		return
	victory_countdown_timer = maxf(0.0, victory_countdown_timer - delta)
	if victory_countdown_timer <= 0.0:
		_finish_game("%s触发的终局倒计时结束。" % _player_name(victory_countdown_trigger_player))


func _open_fullscreen_map() -> void:
	if full_map_overlay == null:
		return
	full_map_overlay.visible = true
	_refresh_board()


func _close_fullscreen_map() -> void:
	if full_map_overlay == null:
		return
	full_map_overlay.visible = false
	_refresh_board()


func _show_menu(title_text: String, body_text: String, can_continue: bool, show_main_actions: bool = false) -> void:
	if menu_overlay == null:
		return
	if time_scale > 0.0:
		speed_before_menu = time_scale
	time_scale = 0.0
	menu_catalog_mode = ""
	menu_title_label.text = title_text
	menu_body_label.text = body_text
	if menu_preview_box != null:
		_clear_children(menu_preview_box)
		menu_preview_box.visible = false
	menu_continue_button.disabled = not can_continue
	menu_continue_button.visible = true
	if menu_back_button != null:
		menu_back_button.visible = not show_main_actions
	for button in menu_regular_buttons:
		button.visible = show_main_actions
	if menu_run_save_label != null:
		menu_run_save_label.visible = show_main_actions
	_refresh_run_save_menu_state()
	if menu_bestiary_prev_button != null:
		menu_bestiary_prev_button.text = "上一个"
		menu_bestiary_next_button.text = "下一个"
		menu_bestiary_prev_button.visible = false
		menu_bestiary_next_button.visible = false
		menu_bestiary_back_button.visible = false
	menu_overlay.visible = true
	_refresh_ui()


func _open_bestiary_from_compendium() -> void:
	catalog_return_menu = "compendium"
	bestiary_show_detail = false
	bestiary_grid_page = 0
	previewed_bestiary_index = 0
	_open_bestiary_menu()


func _open_card_codex_from_compendium() -> void:
	catalog_return_menu = "compendium"
	card_codex_filter = "all"
	card_codex_grid_page = 0
	card_codex_show_detail = false
	previewed_card_codex_card = ""
	_open_card_codex_menu()


func _open_role_codex_from_compendium() -> void:
	catalog_return_menu = "compendium"
	_open_role_codex_menu()


func _back_from_catalog_menu() -> void:
	if menu_catalog_mode == "card" and card_codex_show_detail:
		card_codex_show_detail = false
		_update_card_codex_menu()
		return
	if menu_catalog_mode == "monster" and bestiary_show_detail:
		bestiary_show_detail = false
		_update_bestiary_menu()
		return
	if menu_catalog_mode == "product" and product_codex_show_detail:
		product_codex_show_detail = false
		_update_product_codex_menu()
		return
	match catalog_return_menu:
		"compendium":
			_open_compendium_menu()
		"intel":
			_open_intel_dossier_menu()
		_:
			_open_main_menu()


func _catalog_back_button_text() -> String:
	match catalog_return_menu:
		"compendium":
			return "返回图鉴"
		"intel":
			return "返回情报档案"
		_:
			return "返回主菜单"


func _open_bestiary_menu(index: int = -1) -> void:
	bestiary_show_detail = index >= 0
	if index >= 0:
		bestiary_index = index
		previewed_bestiary_index = _valid_bestiary_index(index)
		bestiary_grid_page = _bestiary_grid_page_for_index(bestiary_index)
	_update_bestiary_menu()


func _open_card_codex_menu(index: int = -1) -> void:
	card_codex_show_detail = index >= 0
	if index >= 0:
		card_codex_index = index
		card_codex_grid_page = _card_codex_grid_page_for_index(card_codex_index)
		var names := _card_codex_names()
		if card_codex_index >= 0 and card_codex_index < names.size():
			previewed_card_codex_card = String(names[card_codex_index])
	_update_card_codex_menu()


func _open_card_codex_by_name(card_name: String) -> void:
	card_codex_show_detail = false
	var direct_skill := _skill_definition(card_name)
	if not direct_skill.is_empty():
		card_codex_filter = _card_codex_category_for_card(card_name, direct_skill)
	var names := _card_codex_names()
	var index := names.find(card_name)
	if index < 0:
		var family_name := "%s1" % _skill_family(card_name)
		index = names.find(family_name)
	if index >= 0:
		card_codex_index = index
		card_codex_show_detail = true
		card_codex_grid_page = _card_codex_grid_page_for_index(card_codex_index)
		previewed_card_codex_card = String(names[card_codex_index])
	else:
		card_codex_filter = "all"
		names = _card_codex_names()
		index = names.find(card_name)
		if index < 0:
			index = names.find("%s1" % _skill_family(card_name))
		if index >= 0:
			card_codex_index = index
			card_codex_show_detail = true
			card_codex_grid_page = _card_codex_grid_page_for_index(card_codex_index)
			previewed_card_codex_card = String(names[card_codex_index])
	_update_card_codex_menu()


func _open_role_codex_menu(index: int = -1) -> void:
	if index >= 0:
		role_codex_index = index
	_update_role_codex_menu()


func _cycle_role_codex(step: int) -> void:
	if PLAYER_ROLE_CATALOG.is_empty():
		return
	role_codex_index = wrapi(role_codex_index + step, 0, PLAYER_ROLE_CATALOG.size())
	_update_role_codex_menu()


func _update_role_codex_menu() -> void:
	if PLAYER_ROLE_CATALOG.is_empty():
		_show_catalog_empty_page("角色图鉴", "还没有角色卡资料。")
		return
	role_codex_index = wrapi(role_codex_index, 0, PLAYER_ROLE_CATALOG.size())
	var role_card := _make_player_role_card(role_codex_index)
	_show_menu("角色图鉴", _role_codex_text(role_card, role_codex_index, PLAYER_ROLE_CATALOG.size()), false)
	menu_catalog_mode = "role"
	menu_continue_button.visible = false
	for button in menu_regular_buttons:
		button.visible = false
	if menu_run_save_label != null:
		menu_run_save_label.visible = false
	menu_bestiary_prev_button.visible = true
	menu_bestiary_next_button.visible = true
	menu_bestiary_back_button.visible = true
	menu_bestiary_back_button.text = _catalog_back_button_text()
	if menu_preview_box != null:
		menu_preview_box.visible = true
		_clear_children(menu_preview_box)
		_add_role_card_preview(menu_preview_box, role_card)
		_add_role_starter_links(menu_preview_box, role_card)


func _cycle_menu_catalog(step: int) -> void:
	match menu_catalog_mode:
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
	if bestiary_show_detail:
		bestiary_index = wrapi(bestiary_index + step, 0, _catalog_size())
		previewed_bestiary_index = bestiary_index
		bestiary_grid_page = _bestiary_grid_page_for_index(bestiary_index)
	else:
		var page_count := _bestiary_grid_page_count(_catalog_size())
		bestiary_grid_page = wrapi(bestiary_grid_page + step, 0, page_count)
		var first_index := _bestiary_first_index_on_page(bestiary_grid_page, _catalog_size())
		bestiary_index = first_index
		previewed_bestiary_index = first_index
	_update_bestiary_menu()


func _update_bestiary_menu() -> void:
	if _catalog_size() <= 0:
		return
	bestiary_index = wrapi(bestiary_index, 0, _catalog_size())
	previewed_bestiary_index = _valid_bestiary_index(previewed_bestiary_index)
	bestiary_grid_page = clampi(bestiary_grid_page, 0, _bestiary_grid_page_count(_catalog_size()) - 1)
	var body_text := _bestiary_text(bestiary_index) if bestiary_show_detail else _bestiary_grid_text()
	_show_menu("怪兽图鉴", body_text, false)
	menu_catalog_mode = "monster"
	menu_continue_button.visible = false
	for button in menu_regular_buttons:
		button.visible = false
	if menu_run_save_label != null:
		menu_run_save_label.visible = false
	menu_bestiary_prev_button.visible = bestiary_show_detail
	menu_bestiary_next_button.visible = bestiary_show_detail
	menu_bestiary_back_button.visible = true
	menu_bestiary_back_button.text = "返回缩略图" if bestiary_show_detail else _catalog_back_button_text()
	if menu_preview_box != null:
		menu_preview_box.visible = true
		_clear_children(menu_preview_box)
		if bestiary_show_detail:
			var center := CenterContainer.new()
			menu_preview_box.add_child(center)
			_add_monster_art_preview(center, _catalog_entry(bestiary_index), false)
			_add_bestiary_monster_card_link(menu_preview_box, bestiary_index)
		else:
			_populate_bestiary_thumbnail_page(menu_preview_box)


func _valid_bestiary_index(index: int) -> int:
	return clampi(index, 0, max(0, _catalog_size() - 1))


func _bestiary_grid_columns() -> int:
	var viewport_size := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(960, 640)
	return clampi(int(floor((viewport_size.x - 180.0) / 178.0)), 2, 4)


func _bestiary_grid_rows() -> int:
	var viewport_size := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(960, 640)
	return clampi(int(floor((viewport_size.y - 260.0) / 176.0)), 1, 3)


func _bestiary_entries_per_page() -> int:
	return maxi(1, _bestiary_grid_columns() * _bestiary_grid_rows())


func _bestiary_grid_page_count(total_count: int) -> int:
	return maxi(1, int(ceil(float(maxi(0, total_count)) / float(_bestiary_entries_per_page()))))


func _bestiary_grid_page_for_index(index: int) -> int:
	var page_index := int(floor(float(maxi(0, index)) / float(_bestiary_entries_per_page())))
	return clampi(page_index, 0, _bestiary_grid_page_count(_catalog_size()) - 1)


func _bestiary_first_index_on_page(page_index: int, total_count: int) -> int:
	return clampi(page_index * _bestiary_entries_per_page(), 0, max(0, total_count - 1))


func _bestiary_grid_text() -> String:
	var page_count := _bestiary_grid_page_count(_catalog_size())
	return "怪兽缩略图册｜第%d/%d页｜当前缩略图布局：%d×%d\n悬停或单击怪兽缩略图会在下方显示详情预览；双击缩略图进入怪兽详情。进入详情后才使用顶部「上一个/下一个」切换怪兽，也可以点「返回缩略图」回到图册。" % [
		bestiary_grid_page + 1,
		page_count,
		_bestiary_grid_columns(),
		_bestiary_grid_rows(),
	]


func _turn_bestiary_grid_page(step: int) -> void:
	if _catalog_size() <= 0:
		return
	var page_count := _bestiary_grid_page_count(_catalog_size())
	bestiary_grid_page = wrapi(bestiary_grid_page + step, 0, page_count)
	var first_index := _bestiary_first_index_on_page(bestiary_grid_page, _catalog_size())
	bestiary_index = first_index
	previewed_bestiary_index = first_index
	bestiary_show_detail = false
	_update_bestiary_menu()


func _populate_bestiary_thumbnail_page(parent: Container) -> void:
	var total_count := _catalog_size()
	if total_count <= 0:
		return
	var page_count := _bestiary_grid_page_count(total_count)
	bestiary_grid_page = clampi(bestiary_grid_page, 0, max(0, page_count - 1))
	var per_page := _bestiary_entries_per_page()
	var start_index := bestiary_grid_page * per_page
	var end_index := mini(total_count, start_index + per_page)
	if start_index >= total_count:
		start_index = _bestiary_first_index_on_page(bestiary_grid_page, total_count)
		end_index = mini(total_count, start_index + per_page)
	if previewed_bestiary_index < start_index or previewed_bestiary_index >= end_index:
		previewed_bestiary_index = start_index
		bestiary_index = start_index

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 8)
	parent.add_child(nav_row)
	var previous_button := Button.new()
	previous_button.text = "缩略图上一页"
	previous_button.disabled = page_count <= 1
	previous_button.pressed.connect(Callable(self, "_turn_bestiary_grid_page").bind(-1))
	nav_row.add_child(previous_button)
	var page_label := _plain_label("第%d/%d页｜%d只怪兽｜本页%d-%d" % [
		bestiary_grid_page + 1,
		page_count,
		total_count,
		start_index + 1,
		end_index,
	], 12, Color("#fecdd3"))
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_row.add_child(page_label)
	var next_button := Button.new()
	next_button.text = "缩略图下一页"
	next_button.disabled = page_count <= 1
	next_button.pressed.connect(Callable(self, "_turn_bestiary_grid_page").bind(1))
	nav_row.add_child(next_button)

	var grid := GridContainer.new()
	grid.columns = _bestiary_grid_columns()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	for i in range(start_index, end_index):
		_add_bestiary_thumbnail(grid, i)
	_add_bestiary_hover_preview(parent)


func _add_bestiary_thumbnail(parent: Container, catalog_index: int) -> void:
	var entry := _catalog_entry(catalog_index)
	var monster_name := String(entry.get("name", "怪兽"))
	var accent := Color("#fb7185")
	var profile := _monster_art_profile(monster_name)
	if profile.has("accent"):
		accent = profile.get("accent")
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(158, 166)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = _bestiary_detail_tooltip(catalog_index)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b1120").lerp(accent, 0.14)
	style.border_color = Color("#fef3c7") if catalog_index == previewed_bestiary_index else accent
	style.set_border_width_all(2 if catalog_index == previewed_bestiary_index else 1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_entered.connect(Callable(self, "_preview_bestiary_entry").bind(catalog_index, true))
	panel.gui_input.connect(Callable(self, "_on_bestiary_thumbnail_gui_input").bind(catalog_index))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _plain_label(monster_name, 11, Color("#f8fafc"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var art_view = MonsterArtViewScript.new()
	art_view.custom_minimum_size = Vector2(0, 86)
	art_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_view.set_monster(
		monster_name,
		String(entry.get("style", "自动怪兽。")),
		int(entry.get("hp", 0)),
		int(entry.get("armor", 0)),
		_meters_text(float(entry.get("move", MONSTER_RAMPAGE_MOVE_METERS))),
		profile,
		true
	)
	box.add_child(art_view)
	var resource_focus: Array = entry.get("resource_focus", [])
	var meta := _plain_label("HP%d｜%s｜%s" % [
		int(entry.get("hp", 0)),
		_meters_text(_catalog_move_speed(catalog_index)),
		_short_card_text("、".join(resource_focus) if not resource_focus.is_empty() else "无偏好", 16),
	], 9, Color("#cbd5e1"))
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(meta)
	var hint := _plain_label("悬停预览｜双击详情", 8, Color("#94a3b8"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _add_bestiary_hover_preview(parent: Container) -> void:
	previewed_bestiary_index = _valid_bestiary_index(previewed_bestiary_index)
	var entry := _catalog_entry(previewed_bestiary_index)
	var preview_panel := PanelContainer.new()
	var profile := _monster_art_profile(String(entry.get("name", "怪兽")))
	var accent := Color("#fb7185")
	if profile.has("accent"):
		accent = profile.get("accent")
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.13)
	style.border_color = Color("#fb7185")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	preview_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(preview_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	preview_panel.add_child(row)
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(220, 0)
	row.add_child(center)
	_add_monster_art_preview(center, entry, true)
	var detail := _plain_label("悬停详情预览：%s\n%s\n%s\n双击缩略图可进入详情页；详情页使用顶部上一个/下一个切换怪兽。" % [
		String(entry.get("name", "怪兽")),
		_bestiary_preview_text(previewed_bestiary_index),
		_bestiary_monster_card_preview_text(previewed_bestiary_index),
	], 11, Color("#fee2e2"))
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(detail)


func _bestiary_preview_text(catalog_index: int) -> String:
	var entry := _catalog_entry(catalog_index)
	var resource_focus: Array = entry.get("resource_focus", [])
	var resource_text := "、".join(resource_focus) if not resource_focus.is_empty() else "暂无固定偏好"
	return "HP:%d｜护甲:%d｜移动:%s｜资源偏好:%s｜行动:%s｜IV级权重:%s" % [
		int(entry.get("hp", 0)),
		int(entry.get("armor", 0)),
		_meters_text(_catalog_move_speed(catalog_index)),
		resource_text,
		_catalog_action_summary(catalog_index),
		_catalog_rank_iv_shift_summary(catalog_index, false),
	]


func _bestiary_monster_card_preview_text(catalog_index: int) -> String:
	var card_name := _monster_card_name(catalog_index, 1)
	var skill := _skill_definition(card_name)
	if skill.is_empty():
		return "怪兽卡：暂无"
	return "怪兽卡：%s｜¥%d｜%s" % [
		_card_display_name(card_name),
		_card_price(card_name),
		_monster_card_region_text(skill),
	]


func _bestiary_detail_tooltip(catalog_index: int) -> String:
	var entry := _catalog_entry(catalog_index)
	return "%s\n%s\n%s\n操作：悬停/单击预览；双击进入完整怪兽详情。" % [
		String(entry.get("name", "怪兽")),
		_bestiary_preview_text(catalog_index),
		_bestiary_monster_card_preview_text(catalog_index),
	]


func _preview_bestiary_entry(catalog_index: int, refresh: bool = true) -> void:
	if _catalog_size() <= 0:
		return
	previewed_bestiary_index = _valid_bestiary_index(catalog_index)
	bestiary_index = previewed_bestiary_index
	if refresh:
		_update_bestiary_menu()


func _open_bestiary_detail(catalog_index: int) -> void:
	_preview_bestiary_entry(catalog_index, false)
	bestiary_show_detail = true
	bestiary_grid_page = _bestiary_grid_page_for_index(bestiary_index)
	_update_bestiary_menu()


func _on_bestiary_thumbnail_gui_input(event: InputEvent, catalog_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.double_click:
		_open_bestiary_detail(catalog_index)
	else:
		_preview_bestiary_entry(catalog_index, true)


func _cycle_card_codex(step: int) -> void:
	var names := _card_codex_names()
	if names.is_empty():
		return
	if card_codex_show_detail:
		card_codex_index = wrapi(card_codex_index + step, 0, names.size())
		previewed_card_codex_card = String(names[card_codex_index])
		card_codex_grid_page = _card_codex_grid_page_for_index(card_codex_index)
	else:
		var page_count := _card_codex_grid_page_count(names.size())
		card_codex_grid_page = wrapi(card_codex_grid_page + step, 0, page_count)
		var first_index := _card_codex_first_index_on_page(card_codex_grid_page, names.size())
		card_codex_index = first_index
		previewed_card_codex_card = String(names[first_index])
	_update_card_codex_menu()


func _update_card_codex_menu() -> void:
	var names := _card_codex_names()
	if names.is_empty():
		_show_catalog_empty_page("卡牌图鉴", "当前分类没有卡牌。")
		return
	card_codex_index = wrapi(card_codex_index, 0, names.size())
	var page_count := _card_codex_grid_page_count(names.size())
	card_codex_grid_page = clampi(card_codex_grid_page, 0, max(0, page_count - 1))
	if previewed_card_codex_card == "" or not names.has(previewed_card_codex_card):
		previewed_card_codex_card = String(names[mini(card_codex_index, names.size() - 1)])
	var card_name := String(names[card_codex_index])
	var skill: Dictionary = _skill_definition(card_name)
	var body_text := _card_codex_text(card_name, skill, card_codex_index, names.size()) if card_codex_show_detail else _card_codex_grid_text(names.size())
	_show_menu("卡牌图鉴", body_text, false)
	menu_catalog_mode = "card"
	menu_continue_button.visible = false
	for button in menu_regular_buttons:
		button.visible = false
	if menu_run_save_label != null:
		menu_run_save_label.visible = false
	menu_bestiary_prev_button.visible = card_codex_show_detail
	menu_bestiary_next_button.visible = card_codex_show_detail
	menu_bestiary_back_button.visible = true
	menu_bestiary_back_button.text = "返回缩略图" if card_codex_show_detail else _catalog_back_button_text()
	if menu_preview_box != null:
		menu_preview_box.visible = true
		_clear_children(menu_preview_box)
		_add_card_codex_filter_buttons(menu_preview_box)
		if card_codex_show_detail:
			var center := CenterContainer.new()
			menu_preview_box.add_child(center)
			_add_card_face(center, card_name, skill, -1, false, false, false)
		else:
			_populate_card_codex_thumbnail_page(menu_preview_box, names)


func _card_codex_grid_columns() -> int:
	var viewport_size := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(960, 640)
	return clampi(int(floor((viewport_size.x - 180.0) / 150.0)), 2, 4)


func _card_codex_grid_rows() -> int:
	var viewport_size := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(960, 640)
	return clampi(int(floor((viewport_size.y - 260.0) / 180.0)), 1, 3)


func _card_codex_cards_per_page() -> int:
	return maxi(1, _card_codex_grid_columns() * _card_codex_grid_rows())


func _card_codex_grid_page_count(total_count: int) -> int:
	return maxi(1, int(ceil(float(maxi(0, total_count)) / float(_card_codex_cards_per_page()))))


func _card_codex_grid_page_for_index(index: int) -> int:
	var page_index := int(floor(float(maxi(0, index)) / float(_card_codex_cards_per_page())))
	return clampi(page_index, 0, _card_codex_grid_page_count(_card_codex_names().size()) - 1)


func _card_codex_first_index_on_page(page_index: int, total_count: int) -> int:
	return clampi(page_index * _card_codex_cards_per_page(), 0, max(0, total_count - 1))


func _card_codex_grid_text(total_count: int) -> String:
	var columns := _card_codex_grid_columns()
	var rows := _card_codex_grid_rows()
	var page_count := _card_codex_grid_page_count(total_count)
	return "缩略图册｜当前筛选:%s｜第%d/%d页｜当前缩略图布局：%d×%d\n悬停或单击卡牌缩略图会在下方显示详情预览；双击缩略图进入卡牌详情。进入详情后才使用顶部「上一个/下一个」切换卡牌，也可以点「返回缩略图」回到图册。" % [
		_card_codex_filter_label(),
		card_codex_grid_page + 1,
		page_count,
		columns,
		rows,
	]


func _turn_card_codex_grid_page(step: int) -> void:
	var names := _card_codex_names()
	if names.is_empty():
		return
	var page_count := _card_codex_grid_page_count(names.size())
	card_codex_grid_page = wrapi(card_codex_grid_page + step, 0, page_count)
	var first_index := _card_codex_first_index_on_page(card_codex_grid_page, names.size())
	card_codex_index = first_index
	previewed_card_codex_card = String(names[first_index])
	card_codex_show_detail = false
	_update_card_codex_menu()


func _populate_card_codex_thumbnail_page(parent: Container, names: Array) -> void:
	var total_count := names.size()
	var page_count := _card_codex_grid_page_count(total_count)
	card_codex_grid_page = clampi(card_codex_grid_page, 0, max(0, page_count - 1))
	var per_page := _card_codex_cards_per_page()
	var start_index := card_codex_grid_page * per_page
	var end_index := mini(total_count, start_index + per_page)
	if start_index >= total_count:
		start_index = _card_codex_first_index_on_page(card_codex_grid_page, total_count)
		end_index = mini(total_count, start_index + per_page)
	if previewed_card_codex_card == "" or not names.has(previewed_card_codex_card):
		previewed_card_codex_card = String(names[start_index])
		card_codex_index = start_index

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 8)
	parent.add_child(nav_row)
	var previous_button := Button.new()
	previous_button.text = "缩略图上一页"
	previous_button.disabled = page_count <= 1
	previous_button.pressed.connect(Callable(self, "_turn_card_codex_grid_page").bind(-1))
	nav_row.add_child(previous_button)
	var page_label := _plain_label("第%d/%d页｜%d张卡｜本页%d-%d" % [
		card_codex_grid_page + 1,
		page_count,
		total_count,
		start_index + 1,
		end_index,
	], 12, Color("#bfdbfe"))
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_row.add_child(page_label)
	var next_button := Button.new()
	next_button.text = "缩略图下一页"
	next_button.disabled = page_count <= 1
	next_button.pressed.connect(Callable(self, "_turn_card_codex_grid_page").bind(1))
	nav_row.add_child(next_button)

	var grid := GridContainer.new()
	grid.columns = _card_codex_grid_columns()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	for i in range(start_index, end_index):
		_add_card_codex_thumbnail(grid, String(names[i]), i)
	_add_card_codex_hover_preview(parent)


func _add_card_codex_thumbnail(parent: Container, card_name: String, card_index: int) -> void:
	var skill := _skill_definition(card_name)
	if skill.is_empty():
		return
	var accent := _card_theme_color(skill)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(132, 166)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = _card_detail_tooltip(card_name)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b1120").lerp(accent, 0.14)
	style.border_color = Color("#fef3c7") if card_name == previewed_card_codex_card else accent
	style.set_border_width_all(2 if card_name == previewed_card_codex_card else 1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_entered.connect(Callable(self, "_preview_card_codex_card").bind(card_name, true))
	panel.gui_input.connect(Callable(self, "_on_card_codex_thumbnail_gui_input").bind(card_name))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _plain_label("%s｜%s" % [_skill_family(card_name), _level_text(_skill_rank(card_name))], 10, Color("#f8fafc"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var art_view = CardArtViewScript.new()
	art_view.custom_minimum_size = Vector2(0, 82)
	art_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_view.set_card(_card_display_name(card_name), String(skill.get("kind", "")), _skill_tag_text(skill), accent, max(1, _skill_rank(card_name)), true, _card_art_stats(skill))
	box.add_child(art_view)
	var meta := _plain_label("%s｜¥%d" % [_card_codex_filter_label(_card_codex_category_for_card(card_name, skill)), _card_price(card_name)], 9, Color("#cbd5e1"))
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(meta)
	var hint := _plain_label("悬停预览｜双击详情", 8, Color("#94a3b8"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _add_card_codex_hover_preview(parent: Container) -> void:
	var preview_name := previewed_card_codex_card
	var names := _card_codex_names()
	if preview_name == "" or not names.has(preview_name):
		if names.is_empty():
			return
		preview_name = String(names[0])
		previewed_card_codex_card = preview_name
	var preview_skill := _skill_definition(preview_name)
	if preview_skill.is_empty():
		return
	var preview_panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(_card_theme_color(preview_skill), 0.13)
	style.border_color = Color("#38bdf8")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	preview_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(preview_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	preview_panel.add_child(row)
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(188, 0)
	row.add_child(center)
	_add_card_face(center, preview_name, preview_skill, -1, false, true, false)
	var detail := _plain_label("悬停详情预览：%s\n%s\n升级梯度：%s\n双击缩略图可进入详情页；详情页使用顶部上一个/下一个翻卡。" % [
		_card_display_name(preview_name),
		_card_rules_text(preview_name, preview_skill, true),
		_card_level_gradient_text(preview_name).replace("\n", " / "),
	], 11, Color("#dbeafe"))
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(detail)


func _preview_card_codex_card(card_name: String, refresh: bool = true) -> void:
	var names := _card_codex_names()
	if card_name == "" or not names.has(card_name):
		return
	previewed_card_codex_card = card_name
	card_codex_index = names.find(card_name)
	if refresh:
		_update_card_codex_menu()


func _open_card_codex_detail(card_name: String) -> void:
	_preview_card_codex_card(card_name, false)
	if card_codex_index < 0:
		return
	card_codex_show_detail = true
	card_codex_grid_page = _card_codex_grid_page_for_index(card_codex_index)
	_update_card_codex_menu()


func _on_card_codex_thumbnail_gui_input(event: InputEvent, card_name: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.double_click:
		_open_card_codex_detail(card_name)
	else:
		_preview_card_codex_card(card_name, true)


func _role_codex_text(role_card: Dictionary, index: int, total: int) -> String:
	var starter_card := String(role_card.get("starter_monster_card", ""))
	var starter_monster := String(role_card.get("starter_monster_name", "怪兽"))
	return "第%d/%d张｜角色卡｜%s｜%s\n特征：%s\n角色被动：%s\n起始怪兽牌：%s（召唤%s）\n设定：%s\n规则：角色卡不是手牌，不会被打出、消耗或匿名公开；它定义玩家的外星身份与开局第一张怪兽牌。起始怪兽牌通常没有区域/商品流动门槛，用来把第一只怪兽召唤到星球上；之后获得的怪兽牌仍按卡面写明的生命值、在场时间、移动速度和召唤区域限制执行。" % [
		index + 1,
		total,
		String(role_card.get("name", "外星辛迪加")),
		String(role_card.get("species", "未知外星人")),
		String(role_card.get("trait", "暂无特征")),
		_role_passive_text(role_card),
		_card_display_name(starter_card),
		starter_monster,
		String(role_card.get("flavor", "暂无设定")),
	]


func _add_role_card_preview(parent: Container, role_card: Dictionary) -> void:
	var center := CenterContainer.new()
	parent.add_child(center)
	_add_role_card_face(center, role_card, false)
	var note := _plain_label("角色卡详情收纳在开局准备与角色图鉴中：它决定起始怪兽牌，不代表玩家能常驻操控怪兽。", 11, Color("#94a3b8"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(note)


func _add_role_starter_links(parent: Container, role_card: Dictionary) -> void:
	var monster_index := _role_starter_monster_index(role_card, role_codex_index)
	var monster_name := String(role_card.get("starter_monster_name", String(_catalog_entry(monster_index).get("name", "怪兽"))))
	var card_name := String(role_card.get("starter_monster_card", _monster_card_name(monster_index, 1)))
	parent.add_child(_plain_label("起始怪兽牌（悬停看详情｜点击跳到卡牌图鉴）：", 12, Color("#fde68a")))
	var card_button := Button.new()
	card_button.text = "%s｜¥%d｜点击查看卡牌图鉴" % [_card_display_name(card_name), _card_price(card_name)]
	card_button.tooltip_text = _card_detail_tooltip(card_name)
	card_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card_button.pressed.connect(Callable(self, "_open_role_starter_card_in_codex").bind(card_name))
	parent.add_child(card_button)

	parent.add_child(_plain_label("起始怪兽（点击跳到怪兽图鉴）：", 12, Color("#fde68a")))
	var monster_button := Button.new()
	monster_button.text = "%s｜查看怪兽图鉴" % monster_name
	monster_button.tooltip_text = "跳到怪兽图鉴查看%s的自动行动概率、资源偏好、生命/速度和伤害数据。" % monster_name
	monster_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	monster_button.pressed.connect(Callable(self, "_open_role_starter_monster_in_bestiary").bind(monster_index))
	parent.add_child(monster_button)


func _open_role_starter_card_in_codex(card_name: String) -> void:
	catalog_return_menu = "compendium"
	_open_card_codex_by_name(card_name)


func _open_role_starter_monster_in_bestiary(monster_index: int) -> void:
	catalog_return_menu = "compendium"
	_open_bestiary_menu(monster_index)


func _open_product_codex_menu(index: int = -1) -> void:
	catalog_return_menu = "compendium"
	product_codex_show_detail = index >= 0
	if index >= 0:
		product_codex_index = index
		previewed_product_codex_index = _valid_product_codex_index(index)
		product_codex_grid_page = _product_codex_grid_page_for_index(product_codex_index)
	elif selected_trade_product != "" and PRODUCT_CATALOG.has(selected_trade_product):
		product_codex_index = PRODUCT_CATALOG.find(selected_trade_product)
		previewed_product_codex_index = product_codex_index
		product_codex_grid_page = _product_codex_grid_page_for_index(product_codex_index)
	_update_product_codex_menu()


func _cycle_product_codex(step: int) -> void:
	if PRODUCT_CATALOG.is_empty():
		return
	if product_codex_show_detail:
		product_codex_index = wrapi(product_codex_index + step, 0, PRODUCT_CATALOG.size())
		previewed_product_codex_index = product_codex_index
		product_codex_grid_page = _product_codex_grid_page_for_index(product_codex_index)
	else:
		var page_count := _product_codex_grid_page_count(PRODUCT_CATALOG.size())
		product_codex_grid_page = wrapi(product_codex_grid_page + step, 0, page_count)
		var first_index := _product_codex_first_index_on_page(product_codex_grid_page, PRODUCT_CATALOG.size())
		product_codex_index = first_index
		previewed_product_codex_index = first_index
	_update_product_codex_menu()


func _update_product_codex_menu() -> void:
	if PRODUCT_CATALOG.is_empty():
		_show_catalog_empty_page("商品图鉴", "当前没有商品资料。")
		return
	_ensure_product_market_catalog()
	product_codex_index = wrapi(product_codex_index, 0, PRODUCT_CATALOG.size())
	previewed_product_codex_index = _valid_product_codex_index(previewed_product_codex_index)
	product_codex_grid_page = clampi(product_codex_grid_page, 0, _product_codex_grid_page_count(PRODUCT_CATALOG.size()) - 1)
	var product_name := String(PRODUCT_CATALOG[product_codex_index])
	var body_text := _product_codex_text(product_name, product_codex_index, PRODUCT_CATALOG.size()) if product_codex_show_detail else _product_codex_grid_text()
	_show_menu("商品图鉴", body_text, false)
	menu_catalog_mode = "product"
	menu_continue_button.visible = false
	for button in menu_regular_buttons:
		button.visible = false
	if menu_run_save_label != null:
		menu_run_save_label.visible = false
	menu_bestiary_prev_button.visible = product_codex_show_detail
	menu_bestiary_next_button.visible = product_codex_show_detail
	menu_bestiary_back_button.visible = true
	menu_bestiary_back_button.text = "返回缩略图" if product_codex_show_detail else _catalog_back_button_text()
	if menu_preview_box != null:
		menu_preview_box.visible = true
		_clear_children(menu_preview_box)
		if product_codex_show_detail:
			_add_product_codex_detail_preview(menu_preview_box, product_name)
		else:
			_populate_product_codex_thumbnail_page(menu_preview_box)


func _valid_product_codex_index(index: int) -> int:
	return clampi(index, 0, max(0, PRODUCT_CATALOG.size() - 1))


func _product_codex_grid_columns() -> int:
	var viewport_size := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(960, 640)
	return clampi(int(floor((viewport_size.x - 180.0) / 170.0)), 2, 4)


func _product_codex_grid_rows() -> int:
	var viewport_size := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(960, 640)
	return clampi(int(floor((viewport_size.y - 260.0) / 150.0)), 1, 3)


func _product_codex_entries_per_page() -> int:
	return maxi(1, _product_codex_grid_columns() * _product_codex_grid_rows())


func _product_codex_grid_page_count(total_count: int) -> int:
	return maxi(1, int(ceil(float(maxi(0, total_count)) / float(_product_codex_entries_per_page()))))


func _product_codex_grid_page_for_index(index: int) -> int:
	var page_index := int(floor(float(maxi(0, index)) / float(_product_codex_entries_per_page())))
	return clampi(page_index, 0, _product_codex_grid_page_count(PRODUCT_CATALOG.size()) - 1)


func _product_codex_first_index_on_page(page_index: int, total_count: int) -> int:
	return clampi(page_index * _product_codex_entries_per_page(), 0, max(0, total_count - 1))


func _product_codex_grid_text() -> String:
	var page_count := _product_codex_grid_page_count(PRODUCT_CATALOG.size())
	return "商品缩略图册｜第%d/%d页｜当前缩略图布局：%d×%d\n悬停或单击商品缩略图会在下方显示价格、供需、经济天气和城市线索预览；双击缩略图进入商品详情。进入详情后才使用顶部「上一个/下一个」切换商品，也可以点「返回缩略图」回到图册。" % [
		product_codex_grid_page + 1,
		page_count,
		_product_codex_grid_columns(),
		_product_codex_grid_rows(),
	]


func _turn_product_codex_grid_page(step: int) -> void:
	if PRODUCT_CATALOG.is_empty():
		return
	var page_count := _product_codex_grid_page_count(PRODUCT_CATALOG.size())
	product_codex_grid_page = wrapi(product_codex_grid_page + step, 0, page_count)
	var first_index := _product_codex_first_index_on_page(product_codex_grid_page, PRODUCT_CATALOG.size())
	product_codex_index = first_index
	previewed_product_codex_index = first_index
	product_codex_show_detail = false
	_update_product_codex_menu()


func _populate_product_codex_thumbnail_page(parent: Container) -> void:
	var total_count := PRODUCT_CATALOG.size()
	if total_count <= 0:
		return
	var page_count := _product_codex_grid_page_count(total_count)
	product_codex_grid_page = clampi(product_codex_grid_page, 0, max(0, page_count - 1))
	var per_page := _product_codex_entries_per_page()
	var start_index := product_codex_grid_page * per_page
	var end_index := mini(total_count, start_index + per_page)
	if start_index >= total_count:
		start_index = _product_codex_first_index_on_page(product_codex_grid_page, total_count)
		end_index = mini(total_count, start_index + per_page)
	if previewed_product_codex_index < start_index or previewed_product_codex_index >= end_index:
		previewed_product_codex_index = start_index
		product_codex_index = start_index

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 8)
	parent.add_child(nav_row)
	var previous_button := Button.new()
	previous_button.text = "缩略图上一页"
	previous_button.disabled = page_count <= 1
	previous_button.pressed.connect(Callable(self, "_turn_product_codex_grid_page").bind(-1))
	nav_row.add_child(previous_button)
	var page_label := _plain_label("第%d/%d页｜%d种商品｜本页%d-%d" % [
		product_codex_grid_page + 1,
		page_count,
		total_count,
		start_index + 1,
		end_index,
	], 12, Color("#bbf7d0"))
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_row.add_child(page_label)
	var next_button := Button.new()
	next_button.text = "缩略图下一页"
	next_button.disabled = page_count <= 1
	next_button.pressed.connect(Callable(self, "_turn_product_codex_grid_page").bind(1))
	nav_row.add_child(next_button)

	var grid := GridContainer.new()
	grid.columns = _product_codex_grid_columns()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	for i in range(start_index, end_index):
		_add_product_codex_thumbnail(grid, i)
	_add_product_codex_hover_preview(parent)


func _add_product_codex_thumbnail(parent: Container, catalog_index: int) -> void:
	var product_name := String(PRODUCT_CATALOG[_valid_product_codex_index(catalog_index)])
	var entry: Dictionary = product_market.get(product_name, {})
	var accent := _product_codex_color(product_name)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(156, 142)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = _product_codex_tooltip(catalog_index)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b1120").lerp(accent, 0.16)
	style.border_color = Color("#fef3c7") if catalog_index == previewed_product_codex_index else accent
	style.set_border_width_all(2 if catalog_index == previewed_product_codex_index else 1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_entered.connect(Callable(self, "_preview_product_codex_entry").bind(catalog_index, true))
	panel.gui_input.connect(Callable(self, "_on_product_codex_thumbnail_gui_input").bind(catalog_index))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _plain_label(product_name, 11, Color("#f8fafc"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var price := _product_price(product_name)
	var price_label := _plain_label("¥%d｜%s｜%s" % [price, String(entry.get("tier", _product_tier(product_name))), _product_trend_text(product_name)], 10, Color("#bbf7d0"))
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(price_label)
	var market_label := _plain_label("供%d｜需%d｜断%d｜波%d" % [
		int(entry.get("supply", 0)),
		int(entry.get("demand", 0)),
		int(entry.get("disrupted", 0)),
		int(entry.get("volatility", 0)),
	], 9, Color("#cbd5e1"))
	market_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(market_label)
	var hint := _plain_label("悬停预览｜双击详情", 8, Color("#94a3b8"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _add_product_codex_hover_preview(parent: Container) -> void:
	previewed_product_codex_index = _valid_product_codex_index(previewed_product_codex_index)
	var product_name := String(PRODUCT_CATALOG[previewed_product_codex_index])
	var preview_panel := PanelContainer.new()
	var accent := _product_codex_color(product_name)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.13)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	preview_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(preview_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	preview_panel.add_child(row)
	var badge := CenterContainer.new()
	badge.custom_minimum_size = Vector2(180, 0)
	row.add_child(badge)
	_add_product_codex_badge(badge, product_name, true)
	var detail := _plain_label("悬停详情预览：%s\n%s\n双击缩略图可进入详情页；详情页使用顶部上一个/下一个切换商品。" % [
		product_name,
		_product_codex_preview_text(product_name),
	], 11, Color("#dcfce7"))
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(detail)


func _add_product_codex_detail_preview(parent: Container, product_name: String) -> void:
	var center := CenterContainer.new()
	parent.add_child(center)
	_add_product_codex_badge(center, product_name, false)


func _add_product_codex_badge(parent: Container, product_name: String, compact: bool = false) -> void:
	var accent := _product_codex_color(product_name)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 136) if compact else Vector2(240, 190)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b1120").lerp(accent, 0.18)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var title := _plain_label(product_name, 14 if compact else 18, Color("#f8fafc"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var entry: Dictionary = product_market.get(product_name, {})
	var price := _product_price(product_name)
	var base_price := int(entry.get("base_price", price))
	var price_line := _plain_label("¥%d｜基准¥%d｜%s" % [price, base_price, _product_trend_text(product_name)], 11 if compact else 13, Color("#bbf7d0"))
	price_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(price_line)
	var meter := _plain_label("供%d 需%d 断%d 波%d" % [
		int(entry.get("supply", 0)),
		int(entry.get("demand", 0)),
		int(entry.get("disrupted", 0)),
		int(entry.get("volatility", 0)),
	], 10 if compact else 12, Color("#e5e7eb"))
	meter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(meter)
	var weather := _plain_label(_short_card_text(_product_market_boon_text(product_name), 52 if compact else 80), 9 if compact else 11, Color("#fde68a"))
	weather.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(weather)


func _product_codex_preview_text(product_name: String) -> String:
	_ensure_product_market_catalog()
	var entry: Dictionary = product_market.get(product_name, {})
	var price := _product_price(product_name)
	var base_price := int(entry.get("base_price", price))
	return "当前价¥%d｜基准¥%d｜价格梯度:%s｜供给%d/需求%d/断路%d/波动%d｜天气:%s｜供给区:%s｜需求区:%s｜城市线索:%s" % [
		price,
		base_price,
		String(entry.get("tier", _product_tier(product_name))),
		int(entry.get("supply", 0)),
		int(entry.get("demand", 0)),
		int(entry.get("disrupted", 0)),
		int(entry.get("volatility", 0)),
		_product_market_boon_text(product_name),
		_product_related_district_names(product_name, "products", 3),
		_product_related_district_names(product_name, "demands", 3),
		_product_clue_preview_text(product_name),
	]


func _product_clue_preview_text(product_name: String) -> String:
	var clues := _economy_city_public_clue_entries(2, product_name)
	if clues.is_empty():
		return "暂无"
	var names := []
	for clue_variant in clues:
		var clue: Dictionary = clue_variant
		names.append("%s/%s" % [String(clue.get("city", "城市")), String(clue.get("type", "线索"))])
	return "；".join(names)


func _product_codex_color(product_name: String) -> Color:
	var seed: int = absi(hash(product_name))
	var palette := [
		Color("#22c55e"),
		Color("#06b6d4"),
		Color("#a78bfa"),
		Color("#f59e0b"),
		Color("#f472b6"),
		Color("#84cc16"),
	]
	return palette[seed % palette.size()] as Color


func _product_codex_tooltip(catalog_index: int) -> String:
	var index := _valid_product_codex_index(catalog_index)
	var product_name := String(PRODUCT_CATALOG[index])
	return "%s\n%s\n操作：悬停/单击预览；双击进入完整商品详情。" % [
		product_name,
		_product_codex_preview_text(product_name),
	]


func _preview_product_codex_entry(catalog_index: int, refresh: bool = true) -> void:
	if PRODUCT_CATALOG.is_empty():
		return
	previewed_product_codex_index = _valid_product_codex_index(catalog_index)
	product_codex_index = previewed_product_codex_index
	if refresh:
		_update_product_codex_menu()


func _open_product_codex_detail(catalog_index: int) -> void:
	_preview_product_codex_entry(catalog_index, false)
	product_codex_show_detail = true
	product_codex_grid_page = _product_codex_grid_page_for_index(product_codex_index)
	_update_product_codex_menu()


func _on_product_codex_thumbnail_gui_input(event: InputEvent, catalog_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.double_click:
		_open_product_codex_detail(catalog_index)
	else:
		_preview_product_codex_entry(catalog_index, true)


func _open_region_codex_menu(index: int = -1) -> void:
	catalog_return_menu = "compendium"
	if index >= 0:
		region_codex_index = index
	_update_region_codex_menu()


func _cycle_region_codex(step: int) -> void:
	if districts.is_empty():
		return
	region_codex_index = wrapi(region_codex_index + step, 0, districts.size())
	_update_region_codex_menu()


func _update_region_codex_menu() -> void:
	if districts.is_empty():
		_show_catalog_empty_page("区域图鉴", "开局后会在这里列出本局随机星球的全部区域：陆地/海洋、公开供需、城市公开状态、区域卡池和邻接关系。")
		return
	region_codex_index = wrapi(region_codex_index, 0, districts.size())
	_show_menu("区域图鉴", _region_codex_text(region_codex_index), false)
	menu_catalog_mode = "region"
	menu_continue_button.visible = false
	for button in menu_regular_buttons:
		button.visible = false
	if menu_run_save_label != null:
		menu_run_save_label.visible = false
	menu_bestiary_prev_button.visible = true
	menu_bestiary_next_button.visible = true
	menu_bestiary_back_button.visible = true
	menu_bestiary_back_button.text = _catalog_back_button_text()


func _show_catalog_empty_page(title_text: String, body_text: String) -> void:
	_show_menu(title_text, body_text, false)
	match title_text:
		"区域图鉴":
			menu_catalog_mode = "region"
		"角色图鉴":
			menu_catalog_mode = "role"
		"卡牌图鉴":
			menu_catalog_mode = "card"
		"怪兽图鉴":
			menu_catalog_mode = "monster"
		_:
			menu_catalog_mode = "product"
	menu_continue_button.visible = false
	for button in menu_regular_buttons:
		button.visible = false
	if menu_run_save_label != null:
		menu_run_save_label.visible = false
	menu_bestiary_prev_button.visible = false
	menu_bestiary_next_button.visible = false
	menu_bestiary_back_button.visible = true
	menu_bestiary_back_button.text = _catalog_back_button_text()


func _card_codex_filter_options() -> Array:
	return [
		{"id": "all", "label": "全部"},
		{"id": "monster", "label": "怪兽牌"},
		{"id": "economy", "label": "经济/商品"},
		{"id": "business", "label": "经营/合约"},
		{"id": "combat", "label": "战斗/指令"},
		{"id": "tactic", "label": "补给/诱导"},
		{"id": "other", "label": "其他"},
	]


func _card_codex_filter_label(filter_id: String = "") -> String:
	if filter_id == "":
		filter_id = card_codex_filter
	for option_variant in _card_codex_filter_options():
		var option: Dictionary = option_variant
		if String(option.get("id", "")) == filter_id:
			return String(option.get("label", filter_id))
	return "全部"


func _card_codex_category_for_card(card_name: String, skill: Dictionary) -> String:
	if _is_monster_card_name(card_name) or String(skill.get("kind", "")) == "monster_card":
		return "monster"
	var kind := String(skill.get("kind", ""))
	if ["product_speculation", "product_contract_boon", "product_growth_boon", "market_stabilize", "cash_gain"].has(kind):
		return "economy"
	if ["city_revenue_boost", "city_contract_boon", "area_trade_contract", "route_insurance", "city_product_upgrade", "city_product_shift", "city_demand_shift", "route_flow_boon", "region_economy_shift"].has(kind):
		return "business"
	if _skill_targets_monster(skill) or ["monster_bound_action", "move", "fly", "burrow", "attack", "charge_attack", "roll_attack", "area_damage", "mudslide", "miasma_shot", "miasma_bloom", "miasma_reclaim", "corrosive_breath", "armor_gain", "guard", "roar"].has(kind):
		return "combat"
	if ["monster_lure", "special_monster_delay", "monster_takeover", "supply_draw", "panic_shift", "route_sabotage", "card_access_boon"].has(kind):
		return "tactic"
	if ["intel_city_reveal", "intel_card_trace", "intel_contract_trace"].has(kind):
		return "other"
	return "other"


func _set_card_codex_filter(filter_id: String) -> void:
	card_codex_filter = filter_id
	card_codex_index = 0
	card_codex_grid_page = 0
	card_codex_show_detail = false
	previewed_card_codex_card = ""
	_update_card_codex_menu()


func _add_card_codex_filter_buttons(parent: Container) -> void:
	parent.add_child(_plain_label("卡牌图鉴分类：怪兽牌已经并入卡牌池；这里按子分类浏览，不再另开怪兽卡牌分支。", 11, Color("#bfdbfe")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	for option_variant in _card_codex_filter_options():
		var option: Dictionary = option_variant
		var filter_id := String(option.get("id", "all"))
		var label := String(option.get("label", filter_id))
		var count := _card_codex_names(filter_id).size()
		var button := Button.new()
		button.text = "%s%s(%d)" % ["●" if filter_id == card_codex_filter else "", label, count]
		button.toggle_mode = true
		button.button_pressed = filter_id == card_codex_filter
		button.tooltip_text = "切换到%s分类。" % label
		button.disabled = count <= 0
		button.pressed.connect(Callable(self, "_set_card_codex_filter").bind(filter_id))
		row.add_child(button)


func _card_codex_names(filter_id: String = "") -> Array:
	if filter_id == "":
		filter_id = card_codex_filter
	var names := []
	for monster_card_variant in _monster_card_names(1):
		var monster_card_name := String(monster_card_variant)
		if filter_id == "all" or filter_id == "monster":
			_append_unique_string(names, monster_card_name)
	for name_variant in SKILL_CATALOG.keys():
		var card_name := _canonical_card_supply_name(String(name_variant))
		if card_name == "" or names.has(card_name):
			continue
		var skill := _skill_definition(card_name)
		var category := _card_codex_category_for_card(card_name, skill)
		if filter_id == "all" or category == filter_id:
			_append_unique_string(names, card_name)
	names.sort()
	return names


func _card_codex_text(card_name: String, skill: Dictionary, index: int, total: int) -> String:
	var target_text := "需要指定目标怪兽" if _skill_requires_target_monster(skill) else "不需要指定怪兽"
	var source_text := "怪兽卡" if _is_monster_card_name(card_name) else ("怪兽固定技能" if _is_monster_technique_card_name(card_name) else "公共/区域补给")
	var category_text := _card_codex_filter_label(_card_codex_category_for_card(card_name, skill))
	var price := _card_price(card_name)
	var key_facts := _card_key_rule_facts(skill)
	var key_text := "；".join(key_facts) if not key_facts.is_empty() else "这张牌没有攻击/生命/范围等战斗数值，主要按效果文字结算。"
	return "第%d/%d张｜%s｜分类:%s / 当前筛选:%s｜参考价 ¥%d（%s，按I级基础价）\n标签：%s｜来源：%s｜目标：%s\n%s\n效果：%s\n打出：%s｜%s\n关键数值：%s\n升级预览：\n%s\n结算演出：%s\n卡面：游戏内手牌与图鉴使用同一套卡面。" % [
		index + 1,
		total,
		_card_display_name(card_name),
		category_text,
		_card_codex_filter_label(),
		price,
		_card_price_tier_text(price),
		_skill_tag_text(skill),
		source_text,
		target_text,
		_card_strategy_summary(skill),
		_skill_display_text(skill),
		"固定技能，不会消失" if bool(skill.get("persistent", false)) else "一次性，打出后消失",
		_skill_play_requirement_text(skill, selected_player),
		key_text,
		_card_level_gradient_text(card_name),
		_card_resolution_animation_catalog_text(card_name, skill).replace("\n", " / "),
	]


func _add_bestiary_special_card_links(parent: Container, cards: Array) -> void:
	if cards.is_empty():
		return
	parent.add_child(_plain_label("旧版关联卡片（悬停看详情｜点击跳到卡牌图鉴）：", 12, Color("#fde68a")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	for card_variant in cards:
		var card_name := String(card_variant)
		if not _skill_exists(card_name):
			continue
		var button := Button.new()
		button.text = "%s｜¥%d" % [card_name, _card_price(card_name)]
		button.tooltip_text = _card_detail_tooltip(card_name)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(Callable(self, "_open_card_codex_by_name").bind(card_name))
		grid.add_child(button)


func _add_bestiary_monster_card_link(parent: Container, catalog_index: int) -> void:
	var card_name := _monster_card_name(catalog_index, 1)
	var skill := _skill_definition(card_name)
	if skill.is_empty():
		return
	parent.add_child(_plain_label("怪兽卡（悬停看属性｜点击跳到卡牌图鉴）：", 12, Color("#fde68a")))
	var button := Button.new()
	button.text = "%s｜¥%d" % [_card_display_name(card_name), _card_price(card_name)]
	button.tooltip_text = _card_detail_tooltip(card_name)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(Callable(self, "_open_card_codex_by_name").bind(card_name))
	parent.add_child(button)


func _card_level_gradient_text(card_name: String) -> String:
	var family := _skill_family(card_name)
	var lines := []
	for level in range(1, 5):
		var level_name := "%s%d" % [family, level]
		if not _skill_exists(level_name):
			continue
		var level_skill := _skill_definition(level_name)
		var numeric_facts := _card_key_rule_facts(level_skill)
		var preview := _join_first_card_facts(numeric_facts, 4)
		if preview == "":
			preview = _short_card_text(_skill_display_text(level_skill), 36)
		lines.append("%s  ¥%d  %s" % [
			_level_text(level),
			_card_price(level_name),
			preview,
		])
	return "\n".join(lines) if not lines.is_empty() else "该卡暂无升级梯度。"


func _ensure_product_market_catalog() -> void:
	if product_market.is_empty():
		product_market = _generate_product_market()
		return
	var generated := {}
	for product_variant in PRODUCT_CATALOG:
		var product_name := String(product_variant)
		if product_market.has(product_name):
			var existing_entry: Dictionary = product_market.get(product_name, {})
			if not existing_entry.has("price_history"):
				existing_entry["price_history"] = [int(existing_entry.get("price", existing_entry.get("base_price", 50)))]
			_normalize_product_market_boon_fields(existing_entry)
			product_market[product_name] = existing_entry
			continue
		if generated.is_empty():
			generated = _generate_product_market()
		var entry: Dictionary = generated.get(product_name, {})
		product_market[product_name] = entry.duplicate(true)


func _product_trend_text(product_name: String) -> String:
	var entry: Dictionary = product_market.get(product_name, {})
	var trend := int(entry.get("trend", 0))
	if trend > 0:
		return "+%d" % trend
	if trend < 0:
		return "%d" % trend
	return "持平"


func _normalize_product_market_boon_fields(entry: Dictionary) -> void:
	if not entry.has("base_growth_multiplier"):
		entry["base_growth_multiplier"] = 1.0
	if not entry.has("growth_multiplier"):
		entry["growth_multiplier"] = float(entry.get("base_growth_multiplier", 1.0))
	if not entry.has("growth_turns"):
		entry["growth_turns"] = 0
	if not entry.has("growth_source"):
		entry["growth_source"] = ""
	if not entry.has("base_growth_source"):
		entry["base_growth_source"] = ""
	if not entry.has("base_route_flow_multiplier"):
		entry["base_route_flow_multiplier"] = 1.0
	if not entry.has("route_flow_multiplier"):
		entry["route_flow_multiplier"] = float(entry.get("base_route_flow_multiplier", 1.0))
	if not entry.has("route_flow_turns"):
		entry["route_flow_turns"] = 0
	if not entry.has("route_flow_source"):
		entry["route_flow_source"] = ""
	if not entry.has("base_route_flow_source"):
		entry["base_route_flow_source"] = ""
	if not entry.has("market_contract_demand"):
		entry["market_contract_demand"] = 0
	if not entry.has("market_contract_supply"):
		entry["market_contract_supply"] = 0
	if not entry.has("market_contract_turns"):
		entry["market_contract_turns"] = 0
	if not entry.has("market_contract_source"):
		entry["market_contract_source"] = ""


func _append_product_price_history(entry: Dictionary, price: int) -> void:
	var history: Array = entry.get("price_history", [])
	if history.is_empty() or int(history[history.size() - 1]) != price:
		history.append(price)
	while history.size() > PRODUCT_HISTORY_LIMIT:
		history.pop_front()
	entry["price_history"] = history


func _product_price_path_text(entry: Dictionary, limit: int = 7) -> String:
	var history: Array = entry.get("price_history", [])
	if history.is_empty():
		return str(int(entry.get("price", entry.get("base_price", 0))))
	var pieces := []
	var start_index: int = maxi(0, history.size() - maxi(2, limit))
	for i in range(start_index, history.size()):
		pieces.append(str(int(history[i])))
	return "→".join(pieces)


func _product_tier_summary() -> String:
	var pieces := []
	for tier_variant in PRODUCT_PRICE_TIERS:
		var tier: Dictionary = tier_variant
		pieces.append("%s¥%d-%d" % [
			String(tier.get("label", "梯度")),
			int(tier.get("min", 0)),
			int(tier.get("max", 0)),
		])
	return "；".join(pieces)


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
		"cycle": business_cycle_count,
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
	for city_index_variant in _active_city_indices_for_player(player_index):
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
	for city_index_variant in _active_city_indices_for_player(player_index):
		var city := _district_city(int(city_index_variant))
		var products := _city_product_names(city)
		if not products.is_empty():
			return String(products[0])
		var demands := _city_demand_names(city)
		if not demands.is_empty():
			return String(demands[0])
	return selected_trade_product if selected_trade_product != "" else (String(PRODUCT_CATALOG[0]) if not PRODUCT_CATALOG.is_empty() else "")


func _skill_play_product(skill: Dictionary, player_index: int) -> String:
	var explicit := String(skill.get("play_product", ""))
	if explicit != "":
		return explicit
	if selected_trade_product != "":
		return selected_trade_product
	return _first_player_flow_product(player_index)


func _skill_play_flow_required(skill: Dictionary, player_index: int = -1) -> int:
	if bool(skill.get("starter_play_free", false)):
		return 0
	var requirement := 0
	if int(skill.get("play_flow_required", 0)) > 0:
		requirement = int(skill.get("play_flow_required", 0))
	else:
		requirement = maxi(1, int(ceil(float(skill.get("cost", 2)) / 3.0)))
	var effective_player := player_index if player_index >= 0 else selected_player
	if String(skill.get("kind", "")) == "area_trade_contract" and effective_player >= 0 and effective_player < players.size():
		var role := _player_role_card_for_index(effective_player)
		requirement = maxi(0, requirement - maxi(0, int(role.get("contract_flow_discount", 0))))
	return requirement


func _skill_play_cash_cost(skill: Dictionary) -> int:
	var cost := maxi(0, int(skill.get("play_cash", 0)))
	if String(skill.get("kind", "")) == "monster_card":
		cost += auto_monsters.size() * int(skill.get("play_cash_per_monster", MONSTER_CARD_PLAY_CASH_PER_EXISTING))
	return cost


func _skill_play_requirement_text(skill: Dictionary, player_index: int = -1) -> String:
	var contract_suffix := ""
	if String(skill.get("kind", "")) == "area_trade_contract":
		contract_suffix = "｜合约两端:%s→%s" % [
			_contract_district_short_name(selected_contract_source_district),
			_contract_district_short_name(selected_contract_target_district),
		]
	if bool(skill.get("starter_play_free", false)):
		var starter_text := "打出条件：起始怪兽牌，无区域/商品流动门槛"
		var starter_cash_cost := _skill_play_cash_cost(skill)
		if starter_cash_cost > 0:
			starter_text += "｜额外支付¥%d" % starter_cash_cost
		return starter_text + contract_suffix
	var flow_product := _skill_play_product(skill, selected_player if player_index < 0 else player_index)
	var flow_required := _skill_play_flow_required(skill, player_index)
	var cash_cost := _skill_play_cash_cost(skill)
	if flow_required <= 0:
		var free_text := "打出条件：无商品流动门槛"
		if cash_cost > 0:
			free_text += "｜额外支付¥%d" % cash_cost
		return free_text + contract_suffix
	var text := "打出条件：%s流动≥%d（不消耗商品）" % [flow_product, flow_required]
	if cash_cost > 0:
		text += "｜额外支付¥%d" % cash_cost
	return text + contract_suffix


func _can_play_skill_now(player_index: int, skill: Dictionary, show_log: bool = true) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var card_label := _card_display_name(String(skill.get("name", "")))
	if card_label == "":
		card_label = "卡牌"
	if String(skill.get("kind", "")) == "area_trade_contract":
		var context := _area_trade_contract_context(skill, player_index, selected_contract_source_district, selected_contract_target_district)
		var error := String(context.get("error", ""))
		if error != "":
			if show_log:
				_log(error)
			return false
	var product_name := _skill_play_product(skill, player_index)
	var required := _skill_play_flow_required(skill, player_index)
	if required <= 0:
		var cash_cost_only := _skill_play_cash_cost(skill)
		if cash_cost_only > 0 and int(players[player_index].get("cash", 0)) < cash_cost_only:
			if show_log:
				_log("%s无法打出：额外费用¥%d，当前资金¥%d。" % [
					card_label,
					cash_cost_only,
					int(players[player_index].get("cash", 0)),
				])
			return false
		return true
	var available := _player_product_flow(player_index, product_name)
	if available < required:
		if show_log:
			_log("%s无法打出：需要己方城市%s流动≥%d，当前为%d；商品不会被消耗。" % [
				card_label,
				product_name,
				required,
				available,
			])
		return false
	var cash_cost := _skill_play_cash_cost(skill)
	if cash_cost > 0 and int(players[player_index].get("cash", 0)) < cash_cost:
		if show_log:
			_log("%s无法打出：额外费用¥%d，当前资金¥%d。" % [
				card_label,
				cash_cost,
				int(players[player_index].get("cash", 0)),
			])
		return false
	return true


func _pay_skill_play_cost(player_index: int, skill: Dictionary) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	var cash_cost := _skill_play_cash_cost(skill)
	if cash_cost <= 0:
		return
	players[player_index]["cash"] = max(0, int(players[player_index].get("cash", 0)) - cash_cost)
	var card_label := _card_display_name(String(skill.get("name", "")))
	if card_label == "":
		card_label = "卡牌"
	_record_player_card_spend(player_index, cash_cost, "打出%s" % card_label, _skill_play_requirement_text(skill, player_index))


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


func _product_related_district_names(product_name: String, field_name: String, limit: int = 6) -> String:
	if districts.is_empty():
		return "开局后显示"
	var names := []
	for i in range(districts.size()):
		var district: Dictionary = districts[i]
		var values: Array = district.get(field_name, [])
		if values.has(product_name):
			names.append(String(district.get("name", "区域%d" % (i + 1))))
	return _limited_name_list(names, limit)


func _product_related_city_names(product_name: String, field_name: String, limit: int = 6) -> String:
	if districts.is_empty():
		return "开局后显示"
	var names := []
	for i in range(districts.size()):
		var city := _district_city(i)
		if not _city_is_active(city):
			continue
		if field_name == "products":
			for product_variant in city.get("products", []):
				var product: Dictionary = product_variant
				if String(product.get("name", "")) == product_name:
					names.append(String(districts[i].get("name", "区域%d" % (i + 1))))
					break
		else:
			var demands: Array = city.get("demands", [])
			if demands.has(product_name):
				names.append(String(districts[i].get("name", "区域%d" % (i + 1))))
	return _limited_name_list(names, limit)


func _product_codex_text(product_name: String, index: int, total: int) -> String:
	_ensure_product_market_catalog()
	var entry: Dictionary = product_market.get(product_name, {})
	var current_price := _product_price(product_name)
	var base_price := int(entry.get("base_price", current_price))
	var tier_text := String(entry.get("tier", _product_tier(product_name)))
	var lines := []
	var base_gap := current_price - base_price
	lines.append("第%d/%d种｜%s｜%s｜当前价 ¥%d｜基准价 ¥%d｜偏离 %s｜趋势 %s" % [
		index + 1,
		total,
		product_name,
		tier_text,
		current_price,
		base_price,
		_signed_int_text(base_gap),
		_product_trend_text(product_name),
	])
	lines.append("市场计数：公开供给%d｜公开需求%d｜断损商路%d｜波动%d。" % [
		int(entry.get("supply", 0)),
		int(entry.get("demand", 0)),
		int(entry.get("disrupted", 0)),
		int(entry.get("volatility", 0)),
	])
	lines.append("近期价格：%s。" % _product_price_path_text(entry))
	lines.append("经济天气：%s。" % _product_market_boon_text(product_name))
	lines.append("本地供给区域：%s" % _product_related_district_names(product_name, "products"))
	lines.append("本地需求区域：%s" % _product_related_district_names(product_name, "demands"))
	lines.append("城市生产：%s" % _product_related_city_names(product_name, "products"))
	lines.append("城市需求：%s" % _product_related_city_names(product_name, "demands"))
	var product_clue_entries := _economy_city_public_clue_entries(4, product_name)
	lines.append("商品相关城市线索：")
	if product_clue_entries.is_empty():
		lines.append("- 暂无与%s直接相关的城市公开线索。" % product_name)
	else:
		for clue_entry in product_clue_entries:
			lines.append("- %s" % _economy_city_public_clue_line(clue_entry as Dictionary))
	lines.append("价格梯度：%s。供给越多越便宜，需求和断路越多越贵；每次市场周期会按本局经济状态重新修正。" % _product_tier_summary())
	return "\n".join(lines)


func _is_monster_special_card(skill_name: String) -> bool:
	return false


func _card_price(skill_name: String, district_index: int = -1, player_index: int = -1) -> int:
	if skill_name == "":
		return CARD_MIN_PRICE
	var price_name := "%s1" % _skill_family(skill_name)
	if not _skill_exists(price_name):
		price_name = skill_name
	var skill: Dictionary = _skill_definition(price_name)
	var power_cost: int = maxi(2, int(skill.get("cost", 2)))
	var price: int = CARD_PRICE_UNIT + (power_cost - 2) * CARD_PRICE_COST_STEP
	if district_index >= 0:
		match _district_card_access_kind(district_index, player_index):
			"landed":
				price = int(round(float(price) * 0.8))
			"extended":
				price = int(round(float(price) * _player_extended_card_price_multiplier(player_index)))
			"global":
				price = int(round(float(price) * _player_global_card_price_multiplier(player_index)))
	return int(max(CARD_MIN_PRICE, price))


func _card_price_tier_text(price: int) -> String:
	if price <= 125:
		return "基础档"
	if price <= 210:
		return "进阶档"
	if price <= 305:
		return "高阶档"
	return "旗舰档"


func _region_card_choice_summary(district_index: int, limit: int = 5) -> String:
	if district_index < 0 or district_index >= districts.size():
		return "无"
	var choices: Array = districts[district_index].get("card_choices", [])
	if choices.is_empty():
		return "无"
	var pieces := []
	for i in range(min(limit, choices.size())):
		var skill_name := String(choices[i])
		pieces.append("%s ¥%d（%s）" % [
			skill_name,
			_card_price(skill_name, district_index),
			_district_card_source(district_index, skill_name),
		])
	if choices.size() > limit:
		pieces.append("+%d" % (choices.size() - limit))
	return "、".join(pieces)


func _region_codex_text(index: int) -> String:
	if index < 0 or index >= districts.size():
		return "区域不存在。"
	var district: Dictionary = districts[index]
	var terrain_text := String(district.get("terrain_label", "区域"))
	var state_text := "已破坏" if bool(district.get("destroyed", false)) else "未破坏"
	var selected_text := "｜当前选中" if index == selected_district else ""
	var lines := []
	lines.append("第%d/%d区｜%s｜%s｜%s%s" % [
		index + 1,
		districts.size(),
		String(district.get("name", "区域")),
		terrain_text,
		state_text,
		selected_text,
	])
	lines.append("公开状态：HP %d/%d｜面积 %.0fm²｜热度 %d｜瘴气 %s｜运输系数 %.2f" % [
		max(0, int(district.get("hp", 0)) - int(district.get("damage", 0))),
		int(district.get("hp", 0)),
		float(district.get("area_m2", 0.0)),
		int(district.get("panic", 0)),
		"有" if bool(district.get("miasma", false)) else "无",
		float(district.get("transport_score", 1.0)),
	])
	lines.append("经济分工：%s｜生产Lv.%d｜公共交通Lv.%d（流动速度×%.2f）｜消费Lv.%d。商品流动量由生产与需求关系决定，流动速度由沿线公共交通决定。" % [
		String(district.get("economic_focus_label", _district_economy_focus_label(String(district.get("economic_focus", "balanced"))))),
		int(district.get("production_level", 1)),
		int(district.get("transport_level", 1)),
		_district_transport_speed(index),
		int(district.get("consumption_level", 1)),
	])
	var last_damage_source := String(district.get("last_damage_source", ""))
	if last_damage_source != "":
		lines.append("最近破坏：%s造成%d点区域/城市伤害。" % [
			last_damage_source,
			int(district.get("last_damage_amount", 0)),
		])
	lines.append("商路负载：%d条运输路径途经或使用此区域；区域被毁会把相关城市的断路压力写入收入结算。" % _district_trade_route_load(index))
	if String(district.get("terrain", "land")) == "ocean":
		lines.append("区域经济：海洋区不生产商品，主要承担低成本商路；本地需求 %s。" % _product_list_with_prices(district.get("demands", []), 4))
	else:
		lines.append("区域经济：本地供给 %s｜本地需求 %s。" % [
			_product_list_with_prices(district.get("products", []), 4),
			_product_list_with_prices(district.get("demands", []), 4),
		])
	var city := _district_city(index)
	if _city_is_active(city):
		lines.append("城市公开信息：城市群存在｜等级%d｜生产 %s｜需求 %s｜供给%d/%d｜断路%d｜流通加速%s｜合约%s｜最近周期收入%d｜真实业主不公开。" % [
			int(city.get("level", 1)),
			_city_product_price_summary(city),
			_city_demand_price_summary(city),
			int(city.get("supplied_demands", 0)),
			(city.get("demands", []) as Array).size(),
			int(city.get("trade_disrupted_routes", 0)),
			_city_route_flow_status_text(city),
			_city_contract_status_text(city),
			int(city.get("last_income", 0)),
		])
		for income_line in _city_income_detail_lines(index, _city_competition_matches(index)):
			lines.append(String(income_line))
		lines.append("当前玩家情报：%s" % _city_intel_hint_for_player(index, selected_player))
		var clue := String(city.get("last_public_clue", ""))
		if clue != "":
			lines.append("公开线索：%s" % clue)
		var public_clues := city.get("public_clues", []) as Array
		if not public_clues.is_empty():
			var clue_lines := []
			for i in range(public_clues.size() - 1, -1, -1):
				var clue_text := _city_public_clue_display_text(public_clues[i])
				if clue_text != "":
					clue_lines.append(clue_text)
			lines.append("最近公开线索：%s" % _limited_name_list(clue_lines, CITY_PUBLIC_CLUE_HISTORY_LIMIT))
	elif not city.is_empty():
		lines.append("城市公开信息：城市群废墟/停止经营；真实业主仍不公开。")
	else:
		lines.append("城市公开信息：尚未城市化。")
	if not auto_monsters.is_empty():
		var attraction_lines := []
		for i in range(auto_monsters.size()):
			var actor: Dictionary = auto_monsters[i]
			if bool(actor.get("down", false)):
				continue
			attraction_lines.append("怪%d·%s %s" % [
				i + 1,
				String(actor.get("name", "怪兽")),
				_auto_monster_target_reason(actor, index),
			])
		if not attraction_lines.is_empty():
			lines.append("怪兽吸引：%s" % "；".join(attraction_lines))
	lines.append("区域可提供卡牌：%s" % _region_card_choice_summary(index))
	lines.append("邻接区域：%s" % _district_connection_summary(index))
	lines.append("提示：区域图鉴会显示当前玩家自己的情报标注状态，但不会提前揭示真实业主。")
	return "\n".join(lines)


func _close_menu() -> void:
	if menu_overlay == null:
		return
	menu_overlay.visible = false
	if not game_over:
		time_scale = max(1.0, speed_before_menu)
	_refresh_ui()


func _start_new_run_from_menu() -> void:
	_open_new_game_setup_menu()


func _open_new_game_setup_menu() -> void:
	_ensure_configured_ai_player_count()
	_show_menu(
		"开局准备",
		"新局会重掷星球、陆海区域、城市商路、区域补给和所有玩家手牌。本原型朝PVE roguelike推进：每局3-8个席位，其中2-7个为AI对手；剩余席位是真人/本地玩家视角。开局不预选四只怪兽；每名玩家先选外星辛迪加角色卡，再从全部怪兽中任选一只I级怪兽作为起始怪兽牌。确认后，玩家需要先打出自己的起始怪兽牌，把第一只自动怪兽匿名召唤到星球上，才能打开默认的怪兽落地/相邻区域购牌补给；角色或补给牌可扩张购牌半径。",
		not players.is_empty() and not game_over
	)
	menu_continue_button.visible = not players.is_empty() and not game_over
	if menu_run_save_label != null:
		menu_run_save_label.visible = false
	if menu_preview_box != null:
		menu_preview_box.visible = true
		_clear_children(menu_preview_box)
		_add_new_game_setup_controls(menu_preview_box)


func _add_new_game_setup_controls(parent: Container) -> void:
	_ensure_configured_ai_player_count()
	parent.add_child(_plain_label("选择本局总席位：%d席｜真人/本地%d｜AI对手%d" % [
		configured_player_count,
		_configured_human_player_count(),
		configured_ai_player_count,
	], 13, Color("#cbd5e1")))
	var player_row := HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 6)
	parent.add_child(player_row)
	for count in range(MIN_PLAYER_COUNT, MAX_PLAYER_COUNT + 1):
		var player_button := Button.new()
		player_button.text = "%d席" % count
		player_button.toggle_mode = true
		player_button.button_pressed = count == configured_player_count
		player_button.pressed.connect(Callable(self, "_set_configured_player_count_from_new_game_menu").bind(count))
		player_row.add_child(player_button)

	parent.add_child(_plain_label("选择AI对手数量（至少2个，最多7个；不能挤掉最后一个真人/本地席位）：", 13, Color("#cbd5e1")))
	var ai_row := HBoxContainer.new()
	ai_row.add_theme_constant_override("separation", 6)
	parent.add_child(ai_row)
	var max_ai := mini(MAX_AI_PLAYER_COUNT, configured_player_count - 1)
	for count in range(MIN_AI_PLAYER_COUNT, max_ai + 1):
		var ai_button := Button.new()
		ai_button.text = "%d AI" % count
		ai_button.toggle_mode = true
		ai_button.button_pressed = count == configured_ai_player_count
		ai_button.pressed.connect(Callable(self, "_set_configured_ai_player_count_from_new_game_menu").bind(count))
		ai_row.add_child(ai_button)

	parent.add_child(_plain_label("Roguelike挑战层级：%s。浅层星球很小，可能少于10个区域；深层星球逐步扩到几十个区域。目标统一是赚到更多钱，通关现金也会随层级提高。" % _roguelike_planet_profile_text(), 13, Color("#cbd5e1")))
	var depth_row := HBoxContainer.new()
	depth_row.add_theme_constant_override("separation", 6)
	parent.add_child(depth_row)
	for depth in range(ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX + 1):
		var depth_button := Button.new()
		depth_button.text = _level_text(depth)
		depth_button.toggle_mode = true
		depth_button.button_pressed = depth == configured_roguelike_depth
		depth_button.tooltip_text = _roguelike_planet_profile_text(depth)
		depth_button.pressed.connect(Callable(self, "_set_configured_roguelike_depth_from_new_game_menu").bind(depth))
		depth_row.add_child(depth_button)

	parent.add_child(_plain_label("本局角色与起始手牌预览（角色给被动；起始I级怪兽可从全部怪兽中任选，不代表玩家能常驻操控怪兽）：", 13, Color("#fde68a")))
	var role_scroll := ScrollContainer.new()
	role_scroll.custom_minimum_size = Vector2(0, 360)
	role_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	role_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	role_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	parent.add_child(role_scroll)
	var role_grid := GridContainer.new()
	role_grid.columns = 1
	role_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_grid.add_theme_constant_override("h_separation", 8)
	role_grid.add_theme_constant_override("v_separation", 8)
	role_scroll.add_child(role_grid)
	for i in range(configured_player_count):
		var role_panel := VBoxContainer.new()
		role_panel.add_theme_constant_override("separation", 4)
		role_grid.add_child(role_panel)
		var role_card := _make_configured_player_role_card(i)
		var starter_card := _make_starting_monster_card(i, role_card)
		var seat_type := _player_seat_type_for_config_index(i)
		var ai_profile := _ai_profile_for_config_index(i)
		var seat_label := "AI·%s" % String(ai_profile.get("name", "训练中")) if seat_type == "ai" else "真人/本地"
		var player_label := _plain_label("玩家%d｜%s｜%s｜起始手牌：%s" % [
			i + 1,
			seat_label,
			String(role_card.get("species", "未知外星人")),
			_card_display_name(String(starter_card.get("name", ""))),
		], 11, Color("#bfdbfe"))
		player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_panel.add_child(player_label)
		var passive_label := _plain_label("角色被动：%s%s" % [
			_role_passive_text(role_card),
			"｜AI策略：%s" % String(ai_profile.get("style", "")) if seat_type == "ai" else "",
		], 10, Color("#fde68a"))
		passive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_panel.add_child(passive_label)
		var role_choice_row := HBoxContainer.new()
		role_choice_row.add_theme_constant_override("separation", 6)
		role_panel.add_child(role_choice_row)
		var previous_role_button := Button.new()
		previous_role_button.text = "上一个角色"
		previous_role_button.pressed.connect(Callable(self, "_cycle_configured_role_for_player_from_new_game_menu").bind(i, -1))
		role_choice_row.add_child(previous_role_button)
		var role_name_label := _plain_label("当前：%s" % String(role_card.get("name", "外星辛迪加")), 10, Color("#e0f2fe"))
		role_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		role_choice_row.add_child(role_name_label)
		var next_role_button := Button.new()
		next_role_button.text = "下一个角色"
		next_role_button.pressed.connect(Callable(self, "_cycle_configured_role_for_player_from_new_game_menu").bind(i, 1))
		role_choice_row.add_child(next_role_button)
		var monster_choice_row := HBoxContainer.new()
		monster_choice_row.add_theme_constant_override("separation", 6)
		role_panel.add_child(monster_choice_row)
		var previous_monster_button := Button.new()
		previous_monster_button.text = "上一个起始怪兽"
		previous_monster_button.pressed.connect(Callable(self, "_cycle_configured_starter_monster_for_player_from_new_game_menu").bind(i, -1))
		monster_choice_row.add_child(previous_monster_button)
		var monster_name_label := _plain_label("起始怪兽：%s" % String(role_card.get("starter_monster_name", "怪兽")), 10, Color("#fecaca"))
		monster_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		monster_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		monster_choice_row.add_child(monster_name_label)
		var next_monster_button := Button.new()
		next_monster_button.text = "下一个起始怪兽"
		next_monster_button.pressed.connect(Callable(self, "_cycle_configured_starter_monster_for_player_from_new_game_menu").bind(i, 1))
		monster_choice_row.add_child(next_monster_button)
		var card_row := HBoxContainer.new()
		card_row.add_theme_constant_override("separation", 8)
		role_panel.add_child(card_row)
		_add_role_card_face(card_row, role_card, true)
		_add_card_face(card_row, String(starter_card.get("name", "")), starter_card, -1, false, true, false)
		var starter_note := _plain_label(_starter_monster_setup_summary(starter_card), 10, Color("#a7f3d0"))
		starter_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_panel.add_child(starter_note)

	var hint := _plain_label("提示：起始怪兽牌第一次召唤不限区域；普通I级怪兽牌免商品流动但仍看落点，II-IV级怪兽牌会要求商品流动。AI席位目前会在经营周期里按评分自动建城和执行商业行动，并记录决策样本供后续训练。", 12, Color("#94a3b8"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(hint)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	parent.add_child(action_row)
	var start_button := Button.new()
	start_button.text = "开始本局"
	start_button.pressed.connect(Callable(self, "_confirm_start_new_run_from_setup"))
	action_row.add_child(start_button)
	var back_button := Button.new()
	back_button.text = "返回主菜单"
	back_button.pressed.connect(Callable(self, "_open_main_menu"))
	action_row.add_child(back_button)


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
	return "首召预览：%s｜在场%s｜免商品流动/区域门槛｜召唤后固定技能%d张｜落地区/邻区开放购牌" % [
		region_text,
		duration_text,
		fixed_skill_count,
	]


func _confirm_start_new_run_from_setup() -> void:
	_log("开始新局：%d席外星辛迪加入局，其中真人/本地%d席，AI对手%d席；怪兽将通过起始怪兽牌和后续怪兽卡匿名召唤，场上数量没有硬上限。" % [
		configured_player_count,
		_configured_human_player_count(),
		configured_ai_player_count,
	])
	_new_game()
	speed_before_menu = 1.0
	_close_menu()


func _save_settings_from_menu() -> void:
	_save_settings(true)


func _save_run_from_menu() -> void:
	var err := _save_run()
	if err == OK:
		_log("当前局面已保存，可从主菜单/暂停菜单读取继续。")
	else:
		_log("局面保存失败：%s。" % error_string(err))
	_refresh_ui()


func _load_run_from_menu() -> void:
	var err := _load_run()
	if err == OK:
		_log("已读取保存局面。")
		_open_main_menu()
	else:
		_log("局面读取失败：%s。" % error_string(err))
		_refresh_ui()


func _save_run(path: String = "") -> int:
	var resolved_path := _resolve_run_save_path(path)
	var file: FileAccess = FileAccess.open(resolved_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(_capture_run_state(), false)
	file.close()
	return OK


func _load_run(path: String = "") -> int:
	var resolved_path := _resolve_run_save_path(path)
	if not FileAccess.file_exists(resolved_path):
		return ERR_FILE_NOT_FOUND
	var state := _read_run_state(resolved_path)
	if state.is_empty():
		return ERR_INVALID_DATA
	return _apply_run_state(state)


func _refresh_run_save_menu_state() -> void:
	var has_save := _has_valid_run_save()
	if menu_load_run_button != null:
		menu_load_run_button.disabled = not has_save
	if menu_run_save_label != null:
		menu_run_save_label.text = _run_save_summary_text()


func _has_valid_run_save(path: String = "") -> bool:
	return not _read_run_state(_resolve_run_save_path(path)).is_empty()


func _run_save_summary_text(path: String = "") -> String:
	var resolved_path := _resolve_run_save_path(path)
	var state := _read_run_state(resolved_path)
	if state.is_empty():
		if FileAccess.file_exists(resolved_path):
			return "存档：存在局面文件，但版本或内容无法读取。请重新保存当前局面。"
		return "存档：暂无已保存局面。保存局面后，可从这里继续。"
	var saved_players := state.get("players", []) as Array
	var saved_districts := state.get("districts", []) as Array
	return "存档：可读取｜时间%s｜经营周期%d｜玩家%d｜存活城市%d｜领先 %s" % [
		_format_time(float(state.get("game_time", 0.0))),
		int(state.get("business_cycle_count", 0)),
		saved_players.size(),
		_saved_active_city_total_count(saved_districts),
		_saved_leader_text(saved_players, saved_districts),
	]


func _resolve_run_save_path(path: String) -> String:
	return run_save_path if path == "" else path


func _read_run_state(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var state_variant: Variant = file.get_var(false)
	file.close()
	if not (state_variant is Dictionary):
		return {}
	var state := state_variant as Dictionary
	if int(state.get("version", 0)) != RUN_SAVE_VERSION:
		return {}
	if not (state.get("players", []) is Array):
		return {}
	if not (state.get("districts", []) is Array):
		return {}
	return state


func _saved_leader_text(saved_players: Array, saved_districts: Array) -> String:
	if saved_players.is_empty():
		return "暂无"
	var best_index := 0
	var best_score := _saved_player_score(saved_players, saved_districts, 0)
	for i in range(1, saved_players.size()):
		var score := _saved_player_score(saved_players, saved_districts, i)
		if score > best_score:
			best_index = i
			best_score = score
	var player := saved_players[best_index] as Dictionary
	return "%s %d" % [String(player.get("name", "玩家%d" % (best_index + 1))), best_score]


func _saved_player_score(saved_players: Array, saved_districts: Array, player_index: int) -> int:
	if player_index < 0 or player_index >= saved_players.size():
		return 0
	var player := saved_players[player_index] as Dictionary
	return int(player.get("cash", 0)) + _saved_active_city_count(saved_districts, player_index) * CITY_FINAL_VALUE + _saved_player_intel_cash(saved_players, saved_districts, player_index)


func _saved_player_intel_cash(saved_players: Array, saved_districts: Array, player_index: int) -> int:
	if player_index < 0 or player_index >= saved_players.size():
		return 0
	var player := saved_players[player_index] as Dictionary
	var guesses: Dictionary = player.get("city_guesses", {})
	var correct := 0
	var wrong := 0
	for i in range(saved_districts.size()):
		var district_variant: Variant = saved_districts[i]
		if not (district_variant is Dictionary):
			continue
		var district := district_variant as Dictionary
		var city := district.get("city", {}) as Dictionary
		if not _city_is_active(city):
			continue
		var owner := int(city.get("owner", -1))
		if owner < 0 or owner == player_index:
			continue
		if not guesses.has(i):
			continue
		var guessed_owner := int(guesses.get(i, -1))
		if guessed_owner < 0:
			continue
		if guessed_owner == owner:
			correct += 1
		else:
			wrong += 1
	var role: Dictionary = player.get("role_card", {}) if player.get("role_card", {}) is Dictionary else {}
	var correct_reward := INTEL_CORRECT_GUESS_CASH + maxi(0, int(role.get("city_guess_reward_bonus", 0)))
	return correct * correct_reward - wrong * INTEL_WRONG_GUESS_COST


func _saved_active_city_total_count(saved_districts: Array) -> int:
	var total := 0
	for i in range(saved_districts.size()):
		var district_variant: Variant = saved_districts[i]
		if not (district_variant is Dictionary):
			continue
		var district := district_variant as Dictionary
		var city := district.get("city", {}) as Dictionary
		if _city_is_active(city):
			total += 1
	return total


func _saved_active_city_count(saved_districts: Array, player_index: int) -> int:
	var total := 0
	for i in range(saved_districts.size()):
		var district_variant: Variant = saved_districts[i]
		if not (district_variant is Dictionary):
			continue
		var district := district_variant as Dictionary
		var city := district.get("city", {}) as Dictionary
		if _city_is_active(city) and int(city.get("owner", -1)) == player_index:
			total += 1
	return total


func _capture_run_state() -> Dictionary:
	var playable_time_scale := time_scale
	if menu_overlay != null and menu_overlay.visible and speed_before_menu > 0.0:
		playable_time_scale = speed_before_menu
	var state := {
		"version": RUN_SAVE_VERSION,
		"rng_state": rng.state,
		"players": players.duplicate(true),
		"districts": districts.duplicate(true),
		"skill_market": skill_market.duplicate(true),
		"product_market": product_market.duplicate(true),
		"log_lines": log_lines.duplicate(true),
		"movement_trails": movement_trails.duplicate(true),
		"action_callouts": action_callouts.duplicate(true),
		"map_event_effects": map_event_effects.duplicate(true),
		"game_time": game_time,
		"time_scale": playable_time_scale,
		"selected_player": selected_player,
		"selected_district": selected_district,
		"selected_market_skill": selected_market_skill,
		"previewed_district_card": previewed_district_card,
		"selected_guess_player": selected_guess_player,
		"selected_trade_product": selected_trade_product,
		"selected_contract_source_district": selected_contract_source_district,
		"selected_contract_target_district": selected_contract_target_district,
		"card_resolution_queue": card_resolution_queue.duplicate(true),
		"next_card_resolution_queue": next_card_resolution_queue.duplicate(true),
		"active_card_resolution": active_card_resolution.duplicate(true),
		"pending_contract_offers": pending_contract_offers.duplicate(true),
		"card_resolution_timer": card_resolution_timer,
		"card_resolution_simultaneous_timer": card_resolution_simultaneous_timer,
		"card_resolution_auction_timer": card_resolution_auction_timer,
		"card_resolution_auction_open": card_resolution_auction_open,
		"card_resolution_batch_locked": card_resolution_batch_locked,
		"card_resolution_batch_reference_player": card_resolution_batch_reference_player,
		"card_resolution_sequence": card_resolution_sequence,
		"last_card_resolution_player_index": last_card_resolution_player_index,
		"resolved_card_history": resolved_card_history.duplicate(true),
		"selected_card_resolution_id": selected_card_resolution_id,
		"opening_guide_dismissed": opening_guide_dismissed,
		"opening_guide_economy_seen_players": opening_guide_economy_seen_players.duplicate(true),
		"business_cycle_count": business_cycle_count,
		"configured_player_count": configured_player_count,
		"configured_ai_player_count": configured_ai_player_count,
		"configured_roguelike_depth": configured_roguelike_depth,
		"configured_role_indices": configured_role_indices.duplicate(true),
		"configured_starter_monster_indices": configured_starter_monster_indices.duplicate(true),
		"game_over": game_over,
		"victory_countdown_active": victory_countdown_active,
		"victory_countdown_timer": victory_countdown_timer,
		"victory_countdown_trigger_player": victory_countdown_trigger_player,
		"victory_countdown_trigger_score": victory_countdown_trigger_score,
		"map_width_m": map_width_m,
		"map_height_m": map_height_m,
		"event_timer": event_timer,
		"special_monster_timer": special_monster_timer,
		"monster_timer": monster_timer,
		"market_timer": market_timer,
		"ai_card_decision_timer": ai_card_decision_timer,
		"ai_auction_reaction_timer": ai_auction_reaction_timer,
		"ai_intel_decision_timer": ai_intel_decision_timer,
		"auto_monsters": auto_monsters.duplicate(true),
		"next_auto_monster_uid": next_auto_monster_uid,
		"next_special_monster_slot": next_special_monster_slot,
		"selected_auto_monster_slot": selected_auto_monster_slot,
		"pending_target_player_index": pending_target_player_index,
		"pending_target_slot_index": pending_target_slot_index,
		"pending_target_paused_time": pending_target_paused_time,
		"speed_before_target_choice": speed_before_target_choice,
		"bestiary_index": bestiary_index,
		"bestiary_grid_page": bestiary_grid_page,
		"bestiary_show_detail": bestiary_show_detail,
		"previewed_bestiary_index": previewed_bestiary_index,
		"card_codex_index": card_codex_index,
		"card_codex_filter": card_codex_filter,
		"product_codex_index": product_codex_index,
		"product_codex_grid_page": product_codex_grid_page,
		"product_codex_show_detail": product_codex_show_detail,
		"previewed_product_codex_index": previewed_product_codex_index,
		"region_codex_index": region_codex_index,
		"role_codex_index": role_codex_index,
	}
	return _strip_legacy_card_runtime_fields(state) as Dictionary


func _strip_legacy_card_runtime_fields(value: Variant) -> Variant:
	if value is Dictionary:
		var dict := (value as Dictionary).duplicate(true)
		dict.erase("charge")
		dict.erase("control")
		for key_variant in dict.keys():
			dict[key_variant] = _strip_legacy_card_runtime_fields(dict[key_variant])
		return dict
	if value is Array:
		var array := (value as Array).duplicate(true)
		for i in range(array.size()):
			array[i] = _strip_legacy_card_runtime_fields(array[i])
		return array
	return value


func _apply_run_state(state: Dictionary) -> int:
	if int(state.get("version", 0)) != RUN_SAVE_VERSION:
		return ERR_INVALID_DATA
	state = _strip_legacy_card_runtime_fields(state) as Dictionary
	players = (state.get("players", []) as Array).duplicate(true)
	_ensure_player_role_cards()
	districts = (state.get("districts", []) as Array).duplicate(true)
	skill_market = (state.get("skill_market", []) as Array).duplicate(true)
	product_market = (state.get("product_market", {}) as Dictionary).duplicate(true)
	log_lines = (state.get("log_lines", []) as Array).duplicate(true)
	movement_trails = (state.get("movement_trails", []) as Array).duplicate(true)
	action_callouts = (state.get("action_callouts", []) as Array).duplicate(true)
	map_event_effects = (state.get("map_event_effects", []) as Array).duplicate(true)
	auto_monsters = (state.get("auto_monsters", []) as Array).duplicate(true)

	rng.state = int(state.get("rng_state", rng.state))
	game_time = float(state.get("game_time", 0.0))
	time_scale = float(state.get("time_scale", 1.0))
	selected_player = clampi(int(state.get("selected_player", 0)), 0, max(0, players.size() - 1))
	selected_district = clampi(int(state.get("selected_district", 0)), 0, max(0, districts.size() - 1))
	selected_market_skill = _canonical_card_supply_name(String(state.get("selected_market_skill", "")))
	previewed_district_card = _canonical_card_supply_name(String(state.get("previewed_district_card", selected_market_skill)))
	selected_guess_player = int(state.get("selected_guess_player", -1))
	selected_trade_product = String(state.get("selected_trade_product", ""))
	selected_contract_source_district = int(state.get("selected_contract_source_district", -1))
	selected_contract_target_district = int(state.get("selected_contract_target_district", -1))
	card_resolution_queue = (state.get("card_resolution_queue", []) as Array).duplicate(true)
	next_card_resolution_queue = (state.get("next_card_resolution_queue", []) as Array).duplicate(true)
	active_card_resolution = (state.get("active_card_resolution", {}) as Dictionary).duplicate(true)
	pending_contract_offers = (state.get("pending_contract_offers", []) as Array).duplicate(true)
	card_resolution_timer = max(0.0, float(state.get("card_resolution_timer", 0.0)))
	card_resolution_simultaneous_timer = max(0.0, float(state.get("card_resolution_simultaneous_timer", 0.0)))
	card_resolution_auction_timer = max(0.0, float(state.get("card_resolution_auction_timer", 0.0)))
	card_resolution_auction_open = bool(state.get("card_resolution_auction_open", false))
	card_resolution_batch_locked = bool(state.get("card_resolution_batch_locked", false))
	card_resolution_batch_reference_player = int(state.get("card_resolution_batch_reference_player", -1))
	card_resolution_sequence = int(state.get("card_resolution_sequence", 0))
	last_card_resolution_player_index = int(state.get("last_card_resolution_player_index", -1))
	resolved_card_history = (state.get("resolved_card_history", []) as Array).duplicate(true)
	selected_card_resolution_id = int(state.get("selected_card_resolution_id", -1))
	opening_guide_dismissed = bool(state.get("opening_guide_dismissed", false))
	opening_guide_economy_seen_players = (state.get("opening_guide_economy_seen_players", {}) as Dictionary).duplicate(true)
	business_cycle_count = int(state.get("business_cycle_count", 0))
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
	_ensure_player_ai_state()
	game_over = bool(state.get("game_over", false))
	victory_countdown_active = bool(state.get("victory_countdown_active", false))
	victory_countdown_timer = maxf(0.0, float(state.get("victory_countdown_timer", 0.0)))
	victory_countdown_trigger_player = int(state.get("victory_countdown_trigger_player", -1))
	victory_countdown_trigger_score = int(state.get("victory_countdown_trigger_score", 0))
	map_width_m = float(state.get("map_width_m", MAP_WIDTH_METERS))
	map_height_m = float(state.get("map_height_m", MAP_HEIGHT_METERS))
	event_timer = float(state.get("event_timer", 6.0))
	special_monster_timer = float(state.get("special_monster_timer", 5.0))
	monster_timer = float(state.get("monster_timer", 4.0))
	market_timer = float(state.get("market_timer", 8.0))
	ai_card_decision_timer = maxf(0.1, float(state.get("ai_card_decision_timer", AI_CARD_DECISION_INTERVAL_SECONDS)))
	ai_auction_reaction_timer = maxf(0.1, float(state.get("ai_auction_reaction_timer", AI_AUCTION_REACTION_INTERVAL_SECONDS)))
	ai_intel_decision_timer = maxf(0.1, float(state.get("ai_intel_decision_timer", AI_INTEL_DECISION_INTERVAL_SECONDS)))
	ui_timer = 0.0
	next_auto_monster_uid = int(state.get("next_auto_monster_uid", 1))
	next_special_monster_slot = int(state.get("next_special_monster_slot", 0))
	selected_auto_monster_slot = int(state.get("selected_auto_monster_slot", 0))
	pending_target_player_index = int(state.get("pending_target_player_index", -1))
	pending_target_slot_index = int(state.get("pending_target_slot_index", -1))
	pending_target_paused_time = bool(state.get("pending_target_paused_time", false))
	speed_before_target_choice = float(state.get("speed_before_target_choice", 1.0))
	bestiary_index = int(state.get("bestiary_index", 0))
	bestiary_grid_page = int(state.get("bestiary_grid_page", 0))
	bestiary_show_detail = bool(state.get("bestiary_show_detail", false))
	previewed_bestiary_index = int(state.get("previewed_bestiary_index", bestiary_index))
	card_codex_index = int(state.get("card_codex_index", 0))
	card_codex_filter = String(state.get("card_codex_filter", "all"))
	product_codex_index = int(state.get("product_codex_index", 0))
	product_codex_grid_page = int(state.get("product_codex_grid_page", 0))
	product_codex_show_detail = bool(state.get("product_codex_show_detail", false))
	previewed_product_codex_index = int(state.get("previewed_product_codex_index", product_codex_index))
	region_codex_index = int(state.get("region_codex_index", 0))
	role_codex_index = int(state.get("role_codex_index", 0))
	_normalize_card_supply_state()

	if skill_market.is_empty():
		skill_market = _monster_market_skills()
	if product_market.is_empty():
		product_market = _generate_product_market()
	_ensure_product_market_catalog()
	if selected_market_skill == "" and not skill_market.is_empty():
		selected_market_skill = String((skill_market[0] as Dictionary).get("name", ""))
	_refresh_city_networks()
	if not active_card_resolution.is_empty():
		_show_card_resolution_overlay(active_card_resolution, card_resolution_timer)
	elif not card_resolution_queue.is_empty() and not card_resolution_batch_locked:
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


func _load_settings_from_menu() -> void:
	_load_settings()
	_log("已读取本地开局设置；重新开局后生效。")
	_refresh_ui()


func _add_panel(parent: Container, title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111827")
	style.border_color = Color("#334155")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#f8fafc"))
	box.add_child(title)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.set_meta("panel_container", panel)
	box.add_child(content)

	parent.add_child(panel)
	return content


func _panel_container(box: VBoxContainer) -> PanelContainer:
	return box.get_meta("panel_container") as PanelContainer


func _roguelike_depth_label(depth: int = -1) -> String:
	var value := configured_roguelike_depth if depth < 0 else depth
	return "深度%s" % _level_text(clampi(value, ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX))


func _roguelike_cash_goal(depth: int = -1) -> int:
	var value := clampi(configured_roguelike_depth if depth < 0 else depth, ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX)
	return ROGUELIKE_CASH_GOAL_BASE + (value - 1) * ROGUELIKE_CASH_GOAL_STEP + value * value * 220


func _roguelike_planet_profile(depth: int = -1) -> Dictionary:
	var value := clampi(configured_roguelike_depth if depth < 0 else depth, ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX)
	var region_min := 6
	var region_max := 9
	match value:
		1:
			region_min = 6
			region_max = 9
		2:
			region_min = 10
			region_max = 14
		3:
			region_min = 15
			region_max = 21
		4:
			region_min = 22
			region_max = 30
		5:
			region_min = 31
			region_max = 41
		_:
			region_min = 40
			region_max = 54
	var scale := 0.65 + float(value) * 0.18
	return {
		"depth": value,
		"label": _roguelike_depth_label(value),
		"region_min": region_min,
		"region_max": region_max,
		"width": MAP_WIDTH_METERS * scale,
		"height": MAP_HEIGHT_METERS * scale,
		"cash_goal": _roguelike_cash_goal(value),
	}


func _roguelike_planet_profile_text(depth: int = -1) -> String:
	var profile := _roguelike_planet_profile(depth)
	return "%s｜星球%.0fm×%.0fm｜区域%d-%d｜目标现金¥%d" % [
		String(profile.get("label", "深度I")),
		float(profile.get("width", MAP_WIDTH_METERS)),
		float(profile.get("height", MAP_HEIGHT_METERS)),
		int(profile.get("region_min", MAP_REGION_COUNT_MIN)),
		int(profile.get("region_max", MAP_REGION_COUNT_MAX)),
		int(profile.get("cash_goal", _roguelike_cash_goal())),
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
			"name": district_name,
			"center": center,
			"polygon": polygon,
			"area_m2": area_m2,
			"radius_m": sqrt(area_m2 / PI),
			"hp": max(10, int(ceil(area_m2 / 26000.0))),
			"damage": 0,
			"last_damage_source": "",
			"last_damage_amount": 0,
			"last_damage_time": -1.0,
			"panic": rng.randi_range(10, 34),
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
			district["products"] = []
			district["demands"] = []
			district["production_level"] = REGION_ECONOMY_LEVEL_MIN
			district["transport_level"] = 4
			district["consumption_level"] = REGION_ECONOMY_LEVEL_MIN
			district["transport_score"] = _transport_score_from_level(int(district["transport_level"]), true)
			district["panic"] = rng.randi_range(4, 18)
			district["hp"] = max(8, int(district.get("hp", 10)) - 2)
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
			var products := _random_product_names(DISTRICT_PRODUCT_COUNT_MIN, DISTRICT_PRODUCT_COUNT_MAX)
			district["products"] = products
			district["demands"] = _random_product_names(DISTRICT_DEMAND_COUNT_MIN, DISTRICT_DEMAND_COUNT_MAX, products)
			district["transport_score"] = _transport_score_from_level(int(district["transport_level"]), false)
		districts[i] = district


func _roll_ocean_district_indices() -> Array:
	var result := []
	var count := districts.size()
	if count <= 2:
		return result
	var desired: int = clampi(int(round(float(count) * rng.randf_range(OCEAN_REGION_RATIO_MIN, OCEAN_REGION_RATIO_MAX))), 1, count - 1)
	var seed_count: int = clampi(rng.randi_range(1, 3), 1, desired)
	while result.size() < seed_count:
		var seed := rng.randi_range(0, count - 1)
		if not result.has(seed):
			result.append(seed)
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
	var pool := []
	for product_variant in PRODUCT_CATALOG:
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


func _generate_product_market() -> Dictionary:
	var result := {}
	var weights := []
	for tier_variant in PRODUCT_PRICE_TIERS:
		var tier: Dictionary = tier_variant
		weights.append(int(tier.get("weight", 1)))
	for product_variant in PRODUCT_CATALOG:
		var product_name := String(product_variant)
		var tier_index := _weighted_pick_index(weights)
		tier_index = max(0, min(tier_index, PRODUCT_PRICE_TIERS.size() - 1))
		var tier: Dictionary = PRODUCT_PRICE_TIERS[tier_index]
		var base_price := rng.randi_range(int(tier.get("min", 30)), int(tier.get("max", 60)))
		result[product_name] = {
			"tier": String(tier.get("label", "基础消费")),
			"base_price": base_price,
			"price": base_price,
			"trend": 0,
			"volatility": int(tier.get("volatility", 4)),
			"supply": 0,
			"demand": 0,
			"disrupted": 0,
			"price_history": [base_price],
			"base_growth_multiplier": 1.0,
			"growth_multiplier": 1.0,
			"growth_turns": 0,
			"growth_source": "",
			"base_growth_source": "",
			"base_route_flow_multiplier": 1.0,
			"route_flow_multiplier": 1.0,
			"route_flow_turns": 0,
			"route_flow_source": "",
			"base_route_flow_source": "",
			"market_contract_demand": 0,
			"market_contract_supply": 0,
			"market_contract_turns": 0,
			"market_contract_source": "",
		}
	return result


func _refresh_product_market_prices() -> void:
	if product_market.is_empty():
		product_market = _generate_product_market()
	var supply := {}
	var demand := {}
	var disrupted := {}
	for product_variant in PRODUCT_CATALOG:
		var product_name := String(product_variant)
		supply[product_name] = 0
		demand[product_name] = 0
		disrupted[product_name] = 0
	for i in range(districts.size()):
		var district: Dictionary = districts[i]
		if bool(district.get("destroyed", false)):
			continue
		for product_variant in district.get("products", []):
			var product_name := String(product_variant)
			supply[product_name] = int(supply.get(product_name, 0)) + 1
		for demand_variant in district.get("demands", []):
			var demand_name := String(demand_variant)
			demand[demand_name] = int(demand.get(demand_name, 0)) + 1
		var city := _district_city(i)
		if _city_is_active(city):
			for city_product_variant in city.get("products", []):
				var city_product: Dictionary = city_product_variant
				var city_product_name := String(city_product.get("name", ""))
				supply[city_product_name] = int(supply.get(city_product_name, 0)) + 2
			for city_demand_variant in city.get("demands", []):
				var city_demand_name := String(city_demand_variant)
				demand[city_demand_name] = int(demand.get(city_demand_name, 0)) + 3
			for route_variant in _city_trade_routes(i):
				var route: Dictionary = route_variant
				if bool(route.get("disrupted", false)):
					var disrupted_product := String(route.get("product", ""))
					disrupted[disrupted_product] = int(disrupted.get(disrupted_product, 0)) + 1
	for product_variant in PRODUCT_CATALOG:
		var product_name := String(product_variant)
		var entry: Dictionary = product_market.get(product_name, {})
		if entry.is_empty():
			entry = _generate_product_market().get(product_name, {})
		_normalize_product_market_boon_fields(entry)
		var base_price := int(entry.get("base_price", 50))
		var volatility := int(entry.get("volatility", 4))
		var temporary_demand := int(entry.get("temporary_demand_pressure", 0))
		var temporary_supply := int(entry.get("temporary_supply_pressure", 0))
		var contract_turns := int(entry.get("market_contract_turns", 0))
		var contract_demand := int(entry.get("market_contract_demand", 0)) if contract_turns > 0 else 0
		var contract_supply := int(entry.get("market_contract_supply", 0)) if contract_turns > 0 else 0
		var extra_demand := temporary_demand + contract_demand
		var extra_supply := temporary_supply + contract_supply
		var demand_score := int(demand.get(product_name, 0)) + extra_demand
		var supply_score := int(supply.get(product_name, 0)) + extra_supply
		var disrupted_score := int(disrupted.get(product_name, 0))
		var positive_pressure := float(demand_score * PRODUCT_DEMAND_PRICE_WEIGHT + disrupted_score * PRODUCT_ROUTE_DAMAGE_PRICE_WEIGHT)
		var growth_multiplier: float = clampf(float(entry.get("growth_multiplier", 1.0)), 1.0, PRODUCT_GROWTH_MULTIPLIER_MAX)
		var trend := int(round(
			positive_pressure * growth_multiplier
			- float(supply_score * PRODUCT_SUPPLY_PRICE_WEIGHT)
			+ rng.randf_range(-float(volatility), float(volatility))
		))
		var price := clampi(base_price + trend, PRODUCT_PRICE_MIN, PRODUCT_PRICE_MAX)
		entry["price"] = price
		entry["trend"] = trend
		entry["supply"] = supply_score
		entry["demand"] = demand_score
		entry["disrupted"] = disrupted_score
		if temporary_demand > 0:
			entry["temporary_demand_pressure"] = maxi(0, temporary_demand - 1)
		if temporary_supply > 0:
			entry["temporary_supply_pressure"] = maxi(0, temporary_supply - 1)
		_append_product_price_history(entry, price)
		product_market[product_name] = entry


func _product_price(product_name: String) -> int:
	if product_name == "":
		return 0
	if product_market.is_empty() or not product_market.has(product_name):
		product_market = _generate_product_market()
	var entry: Dictionary = product_market.get(product_name, {})
	return int(entry.get("price", entry.get("base_price", 50)))


func _product_tier(product_name: String) -> String:
	if product_market.is_empty() or not product_market.has(product_name):
		return "未定价"
	var entry: Dictionary = product_market.get(product_name, {})
	return String(entry.get("tier", "未定价"))


func _product_price_label(product_name: String) -> String:
	if product_name == "":
		return "无商品"
	var entry: Dictionary = product_market.get(product_name, {})
	var trend := int(entry.get("trend", 0))
	var trend_text := "持平"
	if trend > 0:
		trend_text = "+%d" % trend
	elif trend < 0:
		trend_text = "%d" % trend
	return "%s ¥%d｜%s｜%s" % [product_name, _product_price(product_name), _product_tier(product_name), trend_text]


func _product_list_with_prices(names: Array, limit: int = 5) -> String:
	if names.is_empty():
		return "无"
	var pieces := []
	for i in range(min(limit, names.size())):
		pieces.append(_product_price_label(String(names[i])))
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

	var featured_cards := _shuffled_card_list(_current_run_featured_cards())
	var featured_sources := _current_run_featured_card_sources()
	var cursor := 0
	for skill_name_variant in featured_cards:
		if districts.is_empty():
			break
		var skill_name := String(skill_name_variant)
		var placed := false
		for offset in range(districts.size()):
			var district_index := (cursor + offset) % districts.size()
			var choices: Array = districts[district_index]["card_choices"]
			if choices.size() >= DISTRICT_CARD_CHOICE_MAX or choices.has(skill_name):
				continue
			choices.append(skill_name)
			districts[district_index]["card_choices"] = choices
			_set_district_card_source(district_index, skill_name, String(featured_sources.get(skill_name, "怪兽卡")))
			cursor = (district_index + 1) % districts.size()
			placed = true
			break
		if not placed:
			break

	for i in range(districts.size()):
		var choices: Array = districts[i]["card_choices"]
		var choice_count: int = max(int(choice_targets[i]), choices.size())
		choice_count = min(DISTRICT_CARD_CHOICE_MAX, choice_count)
		var attempts := 0
		while choices.size() < choice_count and attempts < 80:
			var skill_name := String(skill_market[rng.randi_range(0, skill_market.size() - 1)])
			if not choices.has(skill_name):
				choices.append(skill_name)
				_set_district_card_source(i, skill_name, "公共补给")
			attempts += 1
		districts[i]["card_choices"] = choices


func _normalize_card_supply_state() -> void:
	var normalized_market := []
	_append_unique_cards(normalized_market, skill_market)
	if normalized_market.is_empty():
		normalized_market = _current_run_card_pool()
	skill_market = normalized_market
	for district_index in range(districts.size()):
		var district: Dictionary = districts[district_index]
		var old_choices: Array = district.get("card_choices", [])
		var old_sources: Dictionary = district.get("card_sources", {})
		var choices := []
		var sources := {}
		for old_name_variant in old_choices:
			var old_name := String(old_name_variant)
			var canonical_name := _canonical_card_supply_name(old_name)
			if canonical_name == "" or choices.has(canonical_name):
				continue
			choices.append(canonical_name)
			sources[canonical_name] = String(old_sources.get(old_name, old_sources.get(canonical_name, "公共补给")))
		for offset in range(normalized_market.size()):
			if choices.size() >= DISTRICT_CARD_CHOICE_MIN:
				break
			var candidate := String(normalized_market[(district_index + offset) % normalized_market.size()])
			if candidate == "" or choices.has(candidate):
				continue
			choices.append(candidate)
			sources[candidate] = "公共补给"
		while choices.size() > DISTRICT_CARD_CHOICE_MAX:
			var removed_name := String(choices.pop_back())
			sources.erase(removed_name)
		district["card_choices"] = choices
		district["card_sources"] = sources
		districts[district_index] = district


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


func _farthest_district_from(index: int) -> int:
	if index < 0 or index >= districts.size():
		return 0
	var best_index := index
	var best_distance := -1.0
	for i in range(districts.size()):
		var dist := _distance(index, i)
		if dist > best_distance:
			best_distance = dist
			best_index = i
	return best_index


func _new_game() -> void:
	players = []
	districts = []
	auto_monsters = []
	next_auto_monster_uid = 1
	next_special_monster_slot = 0
	selected_auto_monster_slot = 0
	pending_target_player_index = -1
	pending_target_slot_index = -1
	pending_target_paused_time = false
	card_resolution_queue = []
	next_card_resolution_queue = []
	active_card_resolution = {}
	pending_contract_offers = []
	card_resolution_timer = 0.0
	card_resolution_simultaneous_timer = 0.0
	card_resolution_auction_timer = 0.0
	card_resolution_auction_open = false
	card_resolution_batch_locked = false
	card_resolution_batch_reference_player = -1
	card_resolution_sequence = 0
	last_card_resolution_player_index = -1
	card_resolution_priority_reference_player = -1
	card_resolution_visual_id = -1
	card_resolution_visual_stage = -1
	resolved_card_history = []
	selected_card_resolution_id = -1
	opening_guide_dismissed = false
	opening_guide_economy_seen_players = {}
	product_market = _generate_product_market()
	skill_market = _monster_market_skills()
	log_lines = []
	movement_trails = []
	action_callouts = []
	map_event_effects = []
	game_time = 0.0
	time_scale = 1.0
	selected_player = 0
	selected_market_skill = skill_market[0] if not skill_market.is_empty() else ""
	previewed_district_card = selected_market_skill
	selected_guess_player = -1
	selected_trade_product = ""
	selected_contract_source_district = -1
	selected_contract_target_district = -1
	business_cycle_count = 0
	game_over = false
	victory_countdown_active = false
	victory_countdown_timer = 0.0
	victory_countdown_trigger_player = -1
	victory_countdown_trigger_score = 0
	ai_card_decision_timer = 1.0
	ai_auction_reaction_timer = AI_AUCTION_REACTION_INTERVAL_SECONDS
	ai_intel_decision_timer = 2.5
	ai_card_decision_enabled = true
	_prime_timers_for_new_game()

	_ensure_configured_ai_player_count()
	_ensure_configured_roguelike_depth()
	_ensure_configured_role_indices()
	_ensure_configured_starter_monster_indices()
	var configured_human_count := _configured_human_player_count()
	for i in range(configured_player_count):
		var role_card := _make_configured_player_role_card(i)
		var starting_cash := STARTING_CASH + int(role_card.get("starting_cash_bonus", 0))
		var is_ai := i >= configured_human_count
		var ai_profile := _ai_profile_for_config_index(i) if is_ai else {}
		players.append({
			"id": i,
			"name": "玩家%d" % (i + 1),
			"seat_type": "ai" if is_ai else "human",
			"is_ai": is_ai,
			"ai_profile": ai_profile,
			"ai_memory": _empty_ai_memory() if is_ai else {},
			"role_index": int(role_card.get("role_index", i)),
			"role_card": role_card,
			"cash": starting_cash,
			"cash_history": [starting_cash],
			"economic_ledger": [],
			"city_guesses": {},
			"city_guess_confidence": {},
			"city_guess_reasons": {},
			"known_card_owners": {},
			"known_contract_parties": {},
			"cities_built": 0,
			"total_city_income": 0,
			"last_cycle_income": 0,
			"total_card_spend": 0,
			"total_build_spend": 0,
			"total_card_income": 0,
			"total_role_income": 0,
			"total_business_spend": 0,
			"action_cooldown": 0.0,
			"queued_card_tip": 0,
			"slots": [_make_starting_monster_card(i, role_card)],
		})
	_ensure_player_ai_state()

	_generate_roguelike_districts()
	_assign_district_card_choices()
	_refresh_product_market_prices()
	var center := Vector2(map_width_m * 0.5, map_height_m * 0.5)
	selected_district = _nearest_district_to(center)
	if selected_district < 0:
		selected_district = 0
	_sync_selected_district_card()
	_refresh_product_market_prices()
	_start_card_ingress_animation()

	_log("即时原型启动：%d席玩家，其中真人/本地%d席、AI对手%d席；本局怪兽由怪兽卡匿名召唤，场上数量没有硬上限。" % [
		configured_player_count,
		_human_player_count(),
		_ai_player_count(),
	])
	_log("AI训练骨架启动：AI会按城市GDP、商品竞争、商路价值、怪兽风险与匿名情报评分行动，并记录最近%d条训练样本。" % AI_DECISION_SAMPLE_LIMIT)
	_log("Roguelike挑战启动：%s；任一玩家可见预估结算资金先达到目标现金¥%d时，开启%.0f秒终局倒计时；倒计时结束按结算资金最高者排名。" % [_roguelike_planet_profile_text(), _roguelike_cash_goal(), VICTORY_COUNTDOWN_SECONDS])
	_log("城市化规则启动：玩家在区域秘密建城；建筑公开出现，但对手看不到真实业主，只能保存私人推测。")
	_log("星球随机生成陆地与海洋：陆地初始生产1种商品并有1种需求，海洋不生产但承担商路运输；合约牌可继续改写供需。")
	_log("每个城市群初始生产1种商品、需求1种商品；后续通过匿名供需合约扩张或替换经营结构。同类商品越多，竞争扣减越高。保护自己的城市，同时借怪兽摧毁竞争城市。")
	_log("本局地图：%.0fm×%.0fm球面投影星球，生成%d个随机陆海区域。" % [map_width_m, map_height_m, districts.size()])
	_log("本局卡池由通用牌与怪兽卡组成；购买花钱，打出需要己方城市满足对应商品流动条件。每个区域提供%d-%d张候选卡。" % [DISTRICT_CARD_CHOICE_MIN, DISTRICT_CARD_CHOICE_MAX])
	_save_settings(false)
	_refresh_ui()


func _start_card_ingress_animation() -> void:
	if districts.is_empty():
		return
	var planet_center := Vector2(map_width_m * 0.5, map_height_m * 0.5)
	_add_action_callout(
		"区域补给网",
		"卡池生成",
		"%d个区域各生成%d-%d张候选卡；怪兽牌已混入区域补给，默认从怪兽落地区/相邻区购买，补给能力可扩张范围。" % [
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


func _district_index_for_card_source(card_name: String, source_tag: String) -> int:
	for i in range(districts.size()):
		var choices: Array = districts[i].get("card_choices", [])
		if not choices.has(card_name):
			continue
		var sources: Dictionary = districts[i].get("card_sources", {})
		if String(sources.get(card_name, "")) == source_tag:
			return i
	return -1


func _card_landing_summary(cards: Array, source_tag: String) -> String:
	var pieces := []
	for card_variant in cards:
		var card_name := String(card_variant)
		var district_index := _district_index_for_card_source(card_name, source_tag)
		if district_index >= 0:
			pieces.append("%s→%s" % [card_name, String(districts[district_index].get("name", "区域"))])
	if pieces.is_empty():
		return "暂无可显示落点"
	return "；".join(pieces)


func _make_auto_monster(slot: int, catalog_index: int, start_district: int, owner_index: int = -1, rank: int = 1) -> Dictionary:
	var template: Dictionary = _catalog_entry(catalog_index)
	rank = clampi(rank, 1, 4)
	var hp := int(round(float(template.get("hp", 40)) * (1.0 + float(rank - 1) * 0.22)))
	var move_speed := _catalog_move_speed(catalog_index) * (1.0 + float(rank - 1) * 0.10)
	var start_index: int = max(0, min(start_district, districts.size() - 1))
	var uid := next_auto_monster_uid
	next_auto_monster_uid += 1
	return {
		"uid": uid,
		"catalog_index": catalog_index,
		"slot": slot,
		"rank": rank,
		"name": String(template.get("name", "怪兽")),
		"hp": hp,
		"max_hp": hp,
		"duration": float(template.get("duration", MONSTER_CARD_DURATION_BASE_SECONDS + float(rank - 1) * MONSTER_CARD_DURATION_RANK_STEP_SECONDS)),
		"remaining_time": float(template.get("duration", MONSTER_CARD_DURATION_BASE_SECONDS + float(rank - 1) * MONSTER_CARD_DURATION_RANK_STEP_SECONDS)),
		"move": move_speed,
		"move_damage": int(template.get("move_damage", AUTO_MONSTER_DEFAULT_MOVE_DAMAGE)),
		"collision_damage": int(template.get("collision_damage", AUTO_MONSTER_DEFAULT_COLLISION_DAMAGE)),
		"movement_traits": (template.get("movement_traits", []) as Array).duplicate(true),
		"terrain_move_multiplier": (template.get("terrain_move_multiplier", {}) as Dictionary).duplicate(true),
		"resource_drain": int(template.get("resource_drain", 1)),
		"resource_focus": (template.get("resource_focus", []) as Array).duplicate(),
		"position": start_index,
		"world_position": _district_center(start_index),
		"armor": int(template.get("armor", 0)),
		"guard": 0,
		"ranged_guard": 0,
		"tether": 0,
		"down": false,
		"owner": owner_index,
		"owner_revealed": false,
		"owner_clue": "",
		"owner_damage_cash_pool": MONSTER_OWNER_DAMAGE_CASH_POOL + (rank - 1) * 220,
		"owner_damage_cash_total": MONSTER_OWNER_DAMAGE_CASH_POOL + (rank - 1) * 220,
		"owner_damage_cash_lost": 0,
		"last_owner_damage_cash_loss": 0,
		"last_owner_damage_amount": 0,
		"last_owner_damage_source": "",
		"last_owner_damage_time": -1.0,
		"revive_available": String(template.get("name", "")) == "机械杰克",
		"revive_timer": 0.0,
		"bracelet_active": false,
		"mebius_energy_announced": false,
		"hikari_revenge_armor_active": false,
	}


func _selected_auto_monster_actor() -> Dictionary:
	if auto_monsters.is_empty():
		return {}
	selected_auto_monster_slot = _valid_auto_monster_slot(selected_auto_monster_slot)
	return auto_monsters[selected_auto_monster_slot] as Dictionary


func _active_auto_monster_count() -> int:
	var count := 0
	for actor_variant in auto_monsters:
		var actor := actor_variant as Dictionary
		if not bool(actor.get("down", false)):
			count += 1
	return count


func _valid_auto_monster_slot(preferred_slot: int) -> int:
	if auto_monsters.is_empty():
		return 0
	if preferred_slot >= 0 and preferred_slot < auto_monsters.size() and not bool((auto_monsters[preferred_slot] as Dictionary).get("down", false)):
		return preferred_slot
	for i in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[i]
		if not bool(actor.get("down", false)):
			return i
	return max(0, min(preferred_slot, auto_monsters.size() - 1))


func _auto_monster_slot_by_uid(uid: int) -> int:
	if uid <= 0:
		return -1
	for i in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[i]
		if int(actor.get("uid", 0)) == uid:
			return i
	return -1


func _owner_damage_cash_total_for_rank(rank: int) -> int:
	return MONSTER_OWNER_DAMAGE_CASH_POOL + (clampi(rank, 1, 4) - 1) * 220


func _reset_owner_damage_cash_meter(actor: Dictionary, force_rank_total: bool = false) -> Dictionary:
	var rank := clampi(int(actor.get("rank", 1)), 1, 4)
	var default_total := _owner_damage_cash_total_for_rank(rank)
	var total_pool := default_total if force_rank_total else maxi(0, int(actor.get("owner_damage_cash_total", default_total)))
	if total_pool <= 0 or force_rank_total:
		total_pool = default_total
	actor["owner_damage_cash_total"] = total_pool
	actor["owner_damage_cash_lost"] = 0
	actor["owner_damage_cash_pool"] = total_pool
	actor["last_owner_damage_cash_loss"] = 0
	actor["last_owner_damage_amount"] = 0
	actor["last_owner_damage_source"] = ""
	actor["last_owner_damage_time"] = -1.0
	return actor


func _invalidate_bound_monster_skills(monster_uid: int, reason: String = "绑定怪兽已离场，此固定技能失效。") -> void:
	if monster_uid <= 0:
		return
	for player_index in range(players.size()):
		var player: Dictionary = players[player_index]
		var slots: Array = player.get("slots", [])
		for i in range(slots.size()):
			if slots[i] == null:
				continue
			var skill: Dictionary = slots[i]
			if int(skill.get("bound_monster_uid", 0)) != monster_uid:
				continue
			skill["bound_monster_uid"] = -1
			skill["lock_left"] = max(float(skill.get("lock_left", 0.0)), 9999.0)
			skill["text"] = "%s（%s）" % [String(skill.get("text", "")), reason]
			slots[i] = skill
		player["slots"] = slots
		players[player_index] = player


func _remove_auto_monster(slot: int, reason: String) -> void:
	if slot < 0 or slot >= auto_monsters.size():
		return
	var actor: Dictionary = auto_monsters[slot]
	var uid := int(actor.get("uid", 0))
	_invalidate_bound_monster_skills(uid)
	_add_action_callout(
		"怪%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
		"离场",
		reason,
		Color("#94a3b8"),
		_entity_world_position(actor)
	)
	_log("怪%d·%s离场：%s" % [slot + 1, String(actor.get("name", "怪兽")), reason])
	auto_monsters.remove_at(slot)
	for i in range(auto_monsters.size()):
		var updated: Dictionary = auto_monsters[i]
		updated["slot"] = i
		auto_monsters[i] = updated
	selected_auto_monster_slot = _valid_auto_monster_slot(selected_auto_monster_slot)
	next_special_monster_slot = wrapi(next_special_monster_slot, 0, max(1, auto_monsters.size()))


func _update_auto_monster_durations(delta: float) -> void:
	for slot in range(auto_monsters.size() - 1, -1, -1):
		var actor: Dictionary = auto_monsters[slot]
		var remaining := float(actor.get("remaining_time", -1.0))
		if remaining < 0.0:
			continue
		remaining = max(0.0, remaining - delta)
		actor["remaining_time"] = remaining
		auto_monsters[slot] = actor
		if remaining <= 0.0:
			_remove_auto_monster(slot, "怪兽卡在场时间结束；无论是否倒地，都会撤离星球。")


func _update_auto_monster_revivals(delta: float) -> void:
	for slot in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[slot]
		if not bool(actor.get("down", false)):
			continue
		var revive_timer := float(actor.get("revive_timer", 0.0))
		if revive_timer <= 0.0:
			continue
		revive_timer = max(0.0, revive_timer - delta)
		actor["revive_timer"] = revive_timer
		if revive_timer <= 0.0:
			actor["down"] = false
			actor["hp"] = int(actor.get("max_hp", actor.get("hp", 1)))
			actor["bracelet_active"] = true
			_log("怪%d·%s手镯复活完成：满血回归，并启用低伤远程反射。" % [slot + 1, String(actor.get("name", "怪兽"))])
			_add_action_callout(
				"怪%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
				"手镯复活完成",
				"满血回归，V字屏障可反射低伤远程攻击。",
				_auto_monster_color(slot),
				_entity_world_position(actor)
			)
		auto_monsters[slot] = actor


func _try_start_auto_monster_revival(slot: int, source: String, actor: Dictionary) -> bool:
	if String(actor.get("name", "")) != "机械杰克":
		return false
	if not bool(actor.get("revive_available", false)):
		return false
	actor["revive_available"] = false
	actor["down"] = true
	actor["hp"] = 0
	actor["revive_timer"] = float(rng.randi_range(1, 6)) * 4.0
	special_monster_timer = min(special_monster_timer, float(actor["revive_timer"]))
	auto_monsters[slot] = actor
	_log("%s击倒怪%d·机械杰克，手镯复活启动：%.1fs后满血回归。" % [source, slot + 1, float(actor["revive_timer"])])
	_add_action_callout(
		"怪%d·机械杰克" % (slot + 1),
		"手镯复活启动",
		"倒地等待%.1fs后满血回归。" % float(actor["revive_timer"]),
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)
	return true


func _is_auto_mebius_energy_active(slot: int) -> bool:
	if slot < 0 or slot >= auto_monsters.size():
		return false
	var actor: Dictionary = auto_monsters[slot]
	return String(actor.get("name", "")) == "梦比优斯" and not bool(actor.get("down", false)) and int(actor.get("hp", 0)) <= MEBIUS_ENERGY_THRESHOLD


func _maybe_announce_auto_mebius_energy(slot: int) -> void:
	if not _is_auto_mebius_energy_active(slot):
		return
	var actor: Dictionary = auto_monsters[slot]
	if bool(actor.get("mebius_energy_announced", false)):
		return
	actor["mebius_energy_announced"] = true
	auto_monsters[slot] = actor
	_log("怪%d·梦比优斯HP降至%d以下，梦比姆能量启动：移动力提升，近战互伤会追加火焰。" % [slot + 1, MEBIUS_ENERGY_THRESHOLD])
	_add_action_callout(
		"怪%d·梦比优斯" % (slot + 1),
		"梦比姆能量启动",
		"移动力提升，近战互伤追加火焰伤害。",
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)


func _is_auto_hikari_revenge_armor_active(slot: int) -> bool:
	if slot < 0 or slot >= auto_monsters.size():
		return false
	var actor: Dictionary = auto_monsters[slot]
	return String(actor.get("name", "")) == "希卡利" and bool(actor.get("hikari_revenge_armor_active", false))


func _maybe_announce_auto_hikari_revenge_armor(slot: int) -> void:
	if slot < 0 or slot >= auto_monsters.size():
		return
	var actor: Dictionary = auto_monsters[slot]
	if String(actor.get("name", "")) != "希卡利":
		return
	if bool(actor.get("hikari_revenge_armor_active", false)):
		return
	if int(actor.get("hp", 0)) > HIKARI_REVENGE_ARMOR_THRESHOLD:
		return
	actor["hikari_revenge_armor_active"] = true
	auto_monsters[slot] = actor
	_log("怪%d·希卡利HP降至%d以下，复仇之铠启动：受伤-1、造成伤害+1。" % [slot + 1, HIKARI_REVENGE_ARMOR_THRESHOLD])
	_add_action_callout(
		"怪%d·希卡利" % (slot + 1),
		"复仇之铠启动",
		"受伤-1，造成伤害+1。",
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)


func _auto_monster_damage_bonus_from_passives(slot: int) -> int:
	if _is_auto_hikari_revenge_armor_active(slot):
		_maybe_announce_auto_hikari_revenge_armor(slot)
		return HIKARI_REVENGE_DAMAGE_BONUS
	return 0


func _apply_owner_damage_cash_loss(slot: int, damage: int, source: String) -> void:
	if slot < 0 or slot >= auto_monsters.size() or damage <= 0:
		return
	var actor: Dictionary = auto_monsters[slot]
	var owner := int(actor.get("owner", -1))
	if owner < 0 or owner >= players.size():
		return
	var max_hp := maxi(1, int(actor.get("max_hp", 1)))
	var total_pool := maxi(0, int(actor.get("owner_damage_cash_total", actor.get("owner_damage_cash_pool", MONSTER_OWNER_DAMAGE_CASH_POOL))))
	var paid_so_far := maxi(0, int(actor.get("owner_damage_cash_lost", total_pool - int(actor.get("owner_damage_cash_pool", total_pool)))))
	var remaining_pool := maxi(0, total_pool - paid_so_far)
	var loss := mini(remaining_pool, maxi(1, int(round(float(total_pool) * float(damage) / float(max_hp)))))
	if loss <= 0:
		return
	players[owner]["cash"] = max(0, int(players[owner].get("cash", 0)) - loss)
	_record_player_economic_event(owner, "怪兽伤害暴露", String(actor.get("name", "怪兽")), -loss, "%s造成%d伤害" % [source, damage])
	_record_player_cash_snapshot(owner)
	actor["owner_damage_cash_total"] = total_pool
	actor["owner_damage_cash_lost"] = paid_so_far + loss
	actor["owner_damage_cash_pool"] = max(0, total_pool - int(actor["owner_damage_cash_lost"]))
	actor["last_owner_damage_cash_loss"] = loss
	actor["last_owner_damage_amount"] = damage
	actor["last_owner_damage_source"] = source
	actor["last_owner_damage_time"] = game_time
	actor["owner_revealed"] = true
	actor["owner_clue"] = "%s因%s受伤损失¥%d，归属线索公开。" % [players[owner]["name"], source, loss]
	auto_monsters[slot] = actor
	_add_action_callout(
		"归属线索",
		String(actor.get("name", "怪兽")),
		"%s资金-%d：这只怪兽的归属被公开指向。" % [players[owner]["name"], loss],
		Color("#fde68a"),
		_entity_world_position(actor)
	)
	_log("公开情报：怪%d·%s受%s伤害%d，%s按生命比例损失¥%d；可推断其归属。" % [
		slot + 1,
		String(actor.get("name", "怪兽")),
		source,
		damage,
		players[owner]["name"],
		loss,
	])


func _grant_bound_monster_skills(player_index: int, monster_uid: int, monster_name: String, rank: int, fixed_skill_count: int = -1) -> Array:
	var granted := []
	if player_index < 0 or player_index >= players.size():
		return granted
	var catalog_index := _monster_catalog_index_by_name(monster_name)
	if catalog_index < 0:
		return granted
	var actions := _catalog_actions(catalog_index)
	var count: int = mini(maxi(1, fixed_skill_count if fixed_skill_count > 0 else clampi(rank, 1, 4)), actions.size())
	var player: Dictionary = players[player_index]
	for action_index in range(count):
		var skill_name := _monster_technique_card_name(monster_name, action_index, rank)
		var skill := _make_skill(skill_name)
		skill["bound_monster_uid"] = monster_uid
		skill["persistent"] = true
		var slot_index := _first_empty_or_new_slot(player)
		player["slots"][slot_index] = skill
		granted.append(skill_name)
	players[player_index] = player
	return granted


func _field_monster_upgrade_slot_for_card(player_index: int, skill: Dictionary) -> int:
	var monster_name := String(skill.get("monster_name", ""))
	if monster_name == "":
		return -1
	for i in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[i]
		if bool(actor.get("down", false)):
			continue
		if int(actor.get("owner", -1)) != player_index:
			continue
		if String(actor.get("name", "")) != monster_name:
			continue
		if int(actor.get("rank", 1)) >= 4:
			continue
		return i
	return -1


func _upgrade_field_monster_from_card(player_index: int, skill: Dictionary) -> bool:
	var slot := _field_monster_upgrade_slot_for_card(player_index, skill)
	if slot < 0:
		return false
	var actor: Dictionary = auto_monsters[slot]
	var catalog_index := int(actor.get("catalog_index", skill.get("catalog_index", 0)))
	var old_rank := clampi(int(actor.get("rank", 1)), 1, 4)
	var card_rank := clampi(int(skill.get("rank", _skill_rank(String(skill.get("name", ""))))), 1, 4)
	var new_rank := clampi(maxi(old_rank + 1, card_rank), 1, 4)
	if new_rank <= old_rank:
		return false
	var upgraded_card := _make_skill(_monster_card_name(catalog_index, new_rank))
	var old_uid := int(actor.get("uid", 0))
	var old_owner_revealed := bool(actor.get("owner_revealed", false))
	var old_owner_clue := String(actor.get("owner_clue", ""))
	actor["rank"] = new_rank
	actor["hp"] = maxi(1, int(upgraded_card.get("hp", actor.get("hp", 1))))
	actor["max_hp"] = int(actor["hp"])
	actor["move"] = maxf(0.0, float(upgraded_card.get("move", actor.get("move", 0.0))))
	actor["duration"] = float(upgraded_card.get("duration", actor.get("duration", MONSTER_CARD_DURATION_BASE_SECONDS)))
	actor["remaining_time"] = float(actor["duration"])
	actor = _reset_owner_damage_cash_meter(actor, true)
	actor["owner_revealed"] = old_owner_revealed
	actor["owner_clue"] = old_owner_clue
	auto_monsters[slot] = actor
	_invalidate_bound_monster_skills(old_uid, "绑定怪兽已升级，旧固定技能失效。")
	var fixed_skill_count := int(upgraded_card.get("fixed_skill_count", new_rank))
	var granted := _grant_bound_monster_skills(player_index, old_uid, String(actor.get("name", "怪兽")), new_rank, fixed_skill_count)
	_apply_role_monster_upgrade_cash(player_index, String(actor.get("name", "怪兽")), old_rank, new_rank, _entity_world_position(actor))
	_apply_monster_economic_boons()
	_refresh_product_market_prices()
	_add_action_callout(
		"匿名怪兽卡",
		"%s升级" % String(actor.get("name", "怪兽")),
		"同名怪兽牌使场上怪兽升至%s；HP和在场时间刷新，归属不额外公开。" % _level_text(new_rank),
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)
	_log("匿名怪兽卡升级：怪%d·%s从%s升至%s，HP刷新为%d、在场时间刷新为%s；新固定技能：%s。归属不额外公开。" % [
		slot + 1,
		String(actor.get("name", "怪兽")),
		_level_text(old_rank),
		_level_text(new_rank),
		int(actor.get("max_hp", 0)),
		_monster_card_duration_text(upgraded_card),
		_limited_name_list(granted, 4, "无"),
	])
	_refresh_ui()
	return true


func _summon_monster_from_card(player: Dictionary, skill: Dictionary) -> bool:
	var catalog_index := int(skill.get("catalog_index", -1))
	if catalog_index < 0 or catalog_index >= _catalog_size():
		_log("%s没有有效的怪兽资料。" % String(skill.get("name", "怪兽卡")))
		return false
	if _upgrade_field_monster_from_card(selected_player, skill):
		return true
	if selected_district < 0 or selected_district >= districts.size() or bool(districts[selected_district].get("destroyed", false)):
		_log("%s需要选中一个未毁区域作为召唤落点。" % String(skill.get("name", "怪兽卡")))
		return false
	if not _can_summon_monster_card_at_district(skill, selected_district):
		_log("%s需要在%s打出；起始怪兽牌例外。" % [
			String(skill.get("name", "怪兽卡")),
			_monster_card_region_text(skill),
		])
		return false
	var fallback_rank := _skill_rank(String(skill.get("name", "")))
	var rank := clampi(int(skill.get("rank", fallback_rank)), 1, 4)
	var slot := auto_monsters.size()
	var actor := _make_auto_monster(slot, catalog_index, selected_district, selected_player, rank)
	var card_hp := maxi(1, int(skill.get("hp", actor.get("max_hp", 1))))
	actor["hp"] = card_hp
	actor["max_hp"] = card_hp
	actor["move"] = maxf(0.0, float(skill.get("move", actor.get("move", 0.0))))
	actor["duration"] = float(skill.get("duration", actor.get("duration", MONSTER_CARD_DURATION_BASE_SECONDS)))
	actor["remaining_time"] = float(actor["duration"])
	auto_monsters.append(actor)
	selected_auto_monster_slot = slot
	next_special_monster_slot = slot
	_apply_monster_economic_boons()
	_refresh_product_market_prices()
	var fixed_skill_count := int(skill.get("fixed_skill_count", rank))
	var granted := _grant_bound_monster_skills(selected_player, int(actor.get("uid", 0)), String(actor.get("name", "怪兽")), rank, fixed_skill_count)
	_add_visual_trail(_district_center(selected_district) + Vector2(0, -80), _district_center(selected_district), _auto_monster_color(slot), "召唤")
	_add_action_callout(
		"匿名怪兽卡",
		"召唤%s" % String(actor.get("name", "怪兽")),
		"%s降落在%s；HP%d｜在场%s｜区域限制%s；归属暂不公开，固定技能%d张进入召唤者手牌。" % [
			String(actor.get("name", "怪兽")),
			districts[selected_district]["name"],
			int(actor.get("max_hp", 0)),
			_monster_card_duration_text(skill),
			_monster_card_region_text(skill),
			granted.size(),
		],
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)
	_log("匿名怪兽卡召唤%s %s至%s；归属暂不公开。召唤者获得固定技能：%s。" % [
		String(actor.get("name", "怪兽")),
		_level_text(rank),
		districts[selected_district]["name"],
		_limited_name_list(granted, 4, "无"),
	])
	_refresh_ui()
	return true


func _make_skill(skill_name: String) -> Dictionary:
	var base: Dictionary = _skill_definition(skill_name)
	var skill := base.duplicate(true)
	skill["name"] = skill_name
	skill["cooldown"] = float(skill.get("cooldown", 0.0))
	skill["cooldown_left"] = 0.0
	skill["lock_left"] = 0.0
	return skill


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


func _role_starter_monster_index(role_card: Dictionary, fallback_index: int = 0) -> int:
	var fallback := wrapi(fallback_index, 0, max(1, _catalog_size()))
	var index := int(role_card.get("starter_monster_index", fallback))
	return clampi(index, 0, max(0, _catalog_size() - 1))


func _make_player_role_card(player_index: int, role_index: int = -1) -> Dictionary:
	var template_index := _player_role_template_index(player_index)
	if role_index >= 0:
		template_index = _clamp_role_index(role_index)
	var role := _player_role_template(player_index, template_index)
	role["kind"] = "player_role"
	role["role_index"] = template_index
	var monster_index := _role_starter_monster_index(role, player_index)
	_apply_starter_monster_to_role_card(role, monster_index)
	return role


func _apply_starter_monster_to_role_card(role: Dictionary, monster_index: int) -> void:
	monster_index = clampi(monster_index, 0, max(0, _catalog_size() - 1))
	role["starter_monster_index"] = monster_index
	role["starter_monster_name"] = String(_catalog_entry(monster_index).get("name", "怪兽"))
	role["starter_monster_card"] = _monster_card_name(monster_index, 1)
	role["text"] = "%s｜本局起始怪兽牌：%s｜特征：%s｜被动：%s" % [
		String(role.get("species", "未知外星人")),
		String(role.get("starter_monster_card", "怪兽牌")),
		String(role.get("trait", "暂无特征")),
		_role_passive_text(role),
	]


func _make_configured_player_role_card(player_index: int) -> Dictionary:
	var role := _make_player_role_card(player_index, _configured_role_index(player_index))
	_apply_starter_monster_to_role_card(role, _configured_starter_monster_index(player_index))
	return role


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
		role["trait"] = String(template.get("trait", "起始怪兽牌供应者。"))
	for field_name in _role_runtime_copy_fields():
		if not role.has(field_name) and template.has(field_name):
			role[field_name] = template[field_name]
	role["kind"] = "player_role"
	_apply_starter_monster_to_role_card(role, _role_starter_monster_index(role, player_index))
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


func _player_role_summary(role_card: Dictionary) -> String:
	if role_card.is_empty():
		return "角色卡：未配置"
	return "角色卡：%s｜%s｜特征：%s｜被动：%s｜起始怪兽牌：%s" % [
		String(role_card.get("name", "外星辛迪加")),
		String(role_card.get("species", "未知外星人")),
		String(role_card.get("trait", "暂无特征")),
		_role_passive_text(role_card),
		_card_display_name(String(role_card.get("starter_monster_card", ""))),
	]


func _role_passive_text(role_card: Dictionary) -> String:
	return String(role_card.get("passive", "暂无被动"))


func _player_role_card_for_index(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= players.size():
		return {}
	var role_variant: Variant = (players[player_index] as Dictionary).get("role_card", {})
	return role_variant as Dictionary if role_variant is Dictionary else {}


func _role_runtime_copy_fields() -> Array:
	return [
		"passive",
		"starting_cash_bonus",
		"starter_hp_bonus",
		"starter_duration_bonus",
		"starter_move_multiplier",
		"starter_fixed_skill_bonus",
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
		"card_access_extra_hops",
		"extended_card_price_multiplier",
		"card_access_global",
		"global_card_price_multiplier",
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


func _apply_role_market_income_bonus(player_index: int, district_index: int) -> int:
	if player_index < 0 or player_index >= players.size() or district_index < 0 or district_index >= districts.size():
		return 0
	var role := _player_role_card_for_index(player_index)
	var product_name := String(role.get("resource_cash_product", ""))
	var amount := int(role.get("resource_cash_amount", 0))
	if product_name == "" or amount <= 0:
		return 0
	if not _district_or_city_has_product(district_index, product_name):
		return 0
	players[player_index]["cash"] = int(players[player_index].get("cash", 0)) + amount
	players[player_index]["last_cycle_income"] = int(players[player_index].get("last_cycle_income", 0)) + amount
	players[player_index]["total_city_income"] = int(players[player_index].get("total_city_income", 0)) + amount
	players[player_index]["total_role_income"] = int(players[player_index].get("total_role_income", 0)) + amount
	_record_player_economic_event(player_index, "角色收益", String(role.get("name", "角色卡")), amount, "%s资源兑钱｜%s" % [product_name, districts[district_index]["name"]])
	_record_player_cash_snapshot(player_index)
	_log("%s触发角色卡：%s在%s把%s兑成¥%d。" % [
		players[player_index]["name"],
		String(role.get("name", "外星角色")),
		districts[district_index]["name"],
		product_name,
		amount,
	])
	return amount


func _bonus_card_candidate_for_role(player: Dictionary, district_index: int, bought_skill_name: String) -> String:
	if district_index < 0 or district_index >= districts.size():
		return ""
	var choices := (districts[district_index].get("card_choices", []) as Array).duplicate()
	var fallback := ""
	for choice_variant in choices:
		var candidate := _canonical_card_supply_name(String(choice_variant))
		if candidate == "" or not _skill_exists(candidate):
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
	var actor_label := "匿名财团" if anonymous else String(player.get("name", "玩家"))
	var bonus_card := _bonus_card_candidate_for_role(player, district_index, bought_skill_name)
	if bonus_card == "":
		_log("%s触发%s的额外拿牌条件，但手牌上限或区域候选不足，未获得额外卡。" % [
			actor_label,
			String(role.get("name", "角色卡")),
		])
		return false
	if not _acquire_card_for_player(player, bonus_card, district_index, "角色被动:%s" % String(role.get("name", "角色卡")), anonymous):
		return false
	players[player_index] = player
	_record_player_economic_event(player_index, "角色收益", "额外拿牌", 0, "%s区域购牌｜免费获得%s" % [product_name, _card_display_name(bonus_card)])
	_log("%s触发%s：在含%s的区域免费额外获得%s。" % [
		actor_label,
		String(role.get("name", "角色卡")),
		product_name,
		_card_display_name(bonus_card),
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


func _apply_role_passive_to_starting_monster_card(skill: Dictionary, role_card: Dictionary) -> void:
	if skill.is_empty() or role_card.is_empty():
		return
	var hp_bonus := int(role_card.get("starter_hp_bonus", 0))
	if hp_bonus != 0:
		skill["hp"] = maxi(1, int(skill.get("hp", 1)) + hp_bonus)
	var duration_bonus := float(role_card.get("starter_duration_bonus", 0.0))
	if abs(duration_bonus) > 0.001 and float(skill.get("duration", -1.0)) >= 0.0:
		skill["duration"] = maxf(1.0, float(skill.get("duration", 1.0)) + duration_bonus)
	var move_multiplier := float(role_card.get("starter_move_multiplier", 1.0))
	if move_multiplier > 0.001 and not is_equal_approx(move_multiplier, 1.0):
		skill["move"] = maxf(1.0, float(skill.get("move", 1.0)) * move_multiplier)
	var fixed_skill_bonus := int(role_card.get("starter_fixed_skill_bonus", 0))
	if fixed_skill_bonus != 0:
		skill["fixed_skill_count"] = maxi(1, int(skill.get("fixed_skill_count", 1)) + fixed_skill_bonus)
	skill["role_passive_summary"] = _role_passive_text(role_card)


func _make_starting_monster_card(player_index: int, role_card: Dictionary = {}) -> Dictionary:
	var monster_index := _role_starter_monster_index(role_card, player_index)
	var skill := _make_skill(_monster_card_name(monster_index, 1))
	skill["starter_play_free"] = true
	skill["summon_access"] = "any"
	skill["source_role"] = String(role_card.get("name", "玩家角色卡"))
	skill["starter_role_index"] = int(role_card.get("role_index", _player_role_template_index(player_index)))
	_apply_role_passive_to_starting_monster_card(skill, role_card)
	skill["text"] = "%s（%s的起始怪兽牌：开局第一只可直接打出，用来打开怪兽落地/相邻区域补给。）" % [
		String(skill.get("text", "")),
		String(role_card.get("name", "玩家角色卡")),
	]
	var passive := _role_passive_text(role_card)
	if passive != "":
		skill["text"] = "%s 角色被动：%s" % [String(skill.get("text", "")), passive]
	return skill


func _skill_exists(skill_name: String) -> bool:
	if skill_name == "":
		return false
	if SKILL_CATALOG.has(skill_name):
		return true
	if _is_monster_card_name(skill_name) or _is_monster_technique_card_name(skill_name):
		return not _skill_definition(skill_name).is_empty()
	var rank := _skill_rank(skill_name)
	if rank < 1 or rank > 4:
		return false
	return SKILL_CATALOG.has("%s1" % _skill_family(skill_name))


func _skill_definition(skill_name: String) -> Dictionary:
	if SKILL_CATALOG.has(skill_name):
		return (SKILL_CATALOG[skill_name] as Dictionary).duplicate(true)
	if _is_monster_card_name(skill_name):
		return _monster_card_definition(skill_name)
	if _is_monster_technique_card_name(skill_name):
		return _monster_technique_definition(skill_name)
	var rank := clampi(_skill_rank(skill_name), 1, 4)
	var family := _skill_family(skill_name)
	return _derived_rank_skill_definition(family, rank)


func _derived_rank_skill_definition(family: String, rank: int) -> Dictionary:
	var base: Dictionary = (SKILL_CATALOG.get("%s1" % family, {}) as Dictionary).duplicate(true)
	if base.is_empty() or rank < 1 or rank > 4:
		return {}
	var source_rank := 1
	var source := base.duplicate(true)
	for candidate_rank in range(rank - 1, 0, -1):
		var candidate_name := "%s%d" % [family, candidate_rank]
		if not SKILL_CATALOG.has(candidate_name):
			continue
		source_rank = candidate_rank
		source = (SKILL_CATALOG[candidate_name] as Dictionary).duplicate(true)
		break
	var steps := rank - source_rank
	if steps <= 0:
		return source
	var result := source.duplicate(true)
	var source_text := String(source.get("text", base.get("text", "")))
	result["text"] = "%s（%s：从%s继续成长；重复获得同系列卡自动升级，购买价仍按I级。）" % [
		source_text,
		_level_text(rank),
		_level_text(source_rank),
	]
	result["rank"] = rank
	result["derived_from_rank"] = source_rank
	var tags: Array = (source.get("tags", base.get("tags", [])) as Array).duplicate(true)
	if not tags.has("升级"):
		tags.append("升级")
	result["tags"] = tags
	var base_cost := maxi(1, int(base.get("cost", 1)))
	var source_cost := maxi(base_cost, int(source.get("cost", base_cost)))
	result["cost"] = source_cost + maxi(1, ceili(float(base_cost) * 0.35)) * steps
	for key in [
		"damage", "armor", "guard", "ranged_guard", "panic", "revenue_amount", "cash",
		"draw_amount", "repair_routes", "route_damage", "contract_income", "market_demand_pressure", "market_supply_pressure", "miasma_count",
		"reclaim_count", "product_level", "product_shift", "demand_shift", "contract_add_products", "contract_add_demands",
		"contract_remove_products", "contract_remove_demands", "accept_cash", "decline_cash_penalty", "decline_route_damage", "stabilize_amount",
		"reveal_city_count", "trace_card_count", "trace_contract_count", "card_access_extra_hops"
	]:
		if not source.has(key) and not base.has(key):
			continue
		var current_value := int(source.get(key, base.get(key, 0)))
		var reference_value := int(base.get(key, current_value))
		if current_value == 0:
			current_value = reference_value
		if current_value == 0:
			continue
		var growth_anchor := maxi(abs(reference_value), abs(current_value))
		var growth_step := maxi(1, ceili(float(growth_anchor) * 0.35))
		result[key] = current_value + growth_step * steps
	for key in [
		"price_delta", "volatility_delta", "production_delta", "transport_delta", "consumption_delta",
		"accept_production_delta", "accept_transport_delta", "accept_consumption_delta",
		"decline_production_delta", "decline_transport_delta", "decline_consumption_delta"
	]:
		if not source.has(key) and not base.has(key):
			continue
		var current_delta := int(source.get(key, base.get(key, 0)))
		var reference_delta := int(base.get(key, current_delta))
		if current_delta == 0:
			current_delta = reference_delta
		if current_delta == 0:
			continue
		var direction := 1 if current_delta > 0 else -1
		var delta_anchor := maxi(abs(reference_delta), abs(current_delta))
		var delta_step := maxi(1, ceili(float(delta_anchor) * 0.35))
		result[key] = current_delta + direction * delta_step * steps
	for key in ["move", "range", "knockback", "delay", "lure_speedup", "card_access_seconds"]:
		if not source.has(key) and not base.has(key):
			continue
		var current_float := float(source.get(key, base.get(key, 0.0)))
		var reference_float := float(base.get(key, current_float))
		if is_zero_approx(current_float):
			current_float = reference_float
		if is_zero_approx(current_float):
			continue
		var float_direction := 1.0 if current_float > 0.0 else -1.0
		var float_anchor := maxf(absf(reference_float), absf(current_float))
		result[key] = current_float + float_direction * maxf(0.1, float_anchor * 0.35) * float(steps)
	for key in ["growth_multiplier", "route_flow_multiplier", "accept_route_flow_multiplier", "extended_card_price_multiplier", "global_card_price_multiplier"]:
		if not source.has(key) and not base.has(key):
			continue
		var current_multiplier := float(source.get(key, base.get(key, 1.0)))
		var reference_multiplier := float(base.get(key, current_multiplier))
		var current_offset := current_multiplier - 1.0
		var reference_offset := reference_multiplier - 1.0
		if is_zero_approx(current_offset):
			current_offset = reference_offset
		if is_zero_approx(current_offset):
			continue
		var multiplier_direction := 1.0 if current_offset > 0.0 else -1.0
		var multiplier_anchor := maxf(absf(reference_offset), absf(current_offset))
		result[key] = 1.0 + current_offset + multiplier_direction * maxf(0.01, multiplier_anchor * 0.35) * float(steps)
	for key in ["contract_turns", "market_contract_turns", "growth_turns", "route_flow_turns"]:
		if source.has(key) or base.has(key):
			result[key] = maxi(1, int(source.get(key, base.get(key, 1)))) + steps
	if source.has("play_flow_required") or base.has("play_flow_required"):
		result["play_flow_required"] = maxi(0, int(source.get("play_flow_required", base.get("play_flow_required", 0)))) + steps
	return result


func _toggle_pause() -> void:
	time_scale = 1.0 if time_scale <= 0.0 else 0.0
	_refresh_ui()


func _refresh_ui() -> void:
	_refresh_status()
	_refresh_card_resolution_track()
	_refresh_board()
	_refresh_map_controls()
	_refresh_player_panel()


func _refresh_status() -> void:
	var district_name := "无区域"
	if selected_district >= 0 and selected_district < districts.size():
		district_name = String(districts[selected_district].get("name", "区域"))
	var goal_text := "%s ¥%d/%d" % [
		_roguelike_depth_label(),
		_player_visible_settlement_estimate(selected_player) if selected_player >= 0 and selected_player < players.size() else 0,
		_roguelike_cash_goal(),
	]
	status_label.text = "%s｜%s｜%s｜%s｜%s" % [
		_format_time(game_time),
		players[selected_player]["name"] if selected_player >= 0 and selected_player < players.size() else "玩家",
		goal_text,
		_card_resolution_status_text(),
		district_name,
	]


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
		selected_trade_product
	)


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
	return clampf(float(district.get("transport_score", base_score)), REGION_TRANSPORT_SCORE_MIN, REGION_TRANSPORT_SCORE_MAX)


func _district_production_factor(index: int) -> float:
	if index < 0 or index >= districts.size():
		return 1.0
	var district: Dictionary = districts[index]
	var level := clampi(int(district.get("production_level", 2)), REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var focus_bonus := 0.16 if String(district.get("economic_focus", "")) == "production" else 0.0
	return maxf(0.25, 0.72 + float(level) * 0.16 + focus_bonus)


func _district_consumption_factor(index: int) -> float:
	if index < 0 or index >= districts.size():
		return 1.0
	var district: Dictionary = districts[index]
	var level := clampi(int(district.get("consumption_level", 2)), REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var focus_bonus := 0.16 if String(district.get("economic_focus", "")) == "consumption" else 0.0
	return maxf(0.25, 0.72 + float(level) * 0.16 + focus_bonus)


func _product_supply_demand_ratio(product_name: String) -> float:
	var entry: Dictionary = product_market.get(product_name, {})
	var supply: int = maxi(1, int(entry.get("supply", 1)))
	var demand: int = maxi(1, int(entry.get("demand", 1)))
	return clampf(float(demand) / float(supply), 0.45, 2.4)


func _product_supply_availability_ratio(product_name: String) -> float:
	var entry: Dictionary = product_market.get(product_name, {})
	var supply: int = maxi(1, int(entry.get("supply", 1)))
	var demand: int = maxi(1, int(entry.get("demand", 1)))
	return clampf(float(supply) / float(demand), 0.45, 2.2)


func _city_product_price_summary(city: Dictionary) -> String:
	var names := _city_product_names(city)
	return _product_list_with_prices(names, 4)


func _city_demand_price_summary(city: Dictionary) -> String:
	var names := _city_demand_names(city)
	return _product_list_with_prices(names, 4)


func _make_city_products(district_index: int) -> Array:
	var preferred: Array = districts[district_index].get("products", []) if district_index >= 0 and district_index < districts.size() else []
	var pool := []
	for product_variant in preferred:
		var product_name := String(product_variant)
		if product_name != "" and not pool.has(product_name):
			pool.append(product_name)
	for product_variant in PRODUCT_CATALOG:
		var product_name := String(product_variant)
		if product_name != "" and not pool.has(product_name):
			pool.append(product_name)
	var result := []
	var count: int = min(pool.size(), rng.randi_range(CITY_PRODUCT_COUNT_MIN, CITY_PRODUCT_COUNT_MAX))
	while result.size() < count and not pool.is_empty():
		var pick := rng.randi_range(0, pool.size() - 1)
		var product_name := String(pool[pick])
		result.append({
			"name": product_name,
			"level": 1,
			"base_price": _product_price(product_name),
			"tier": _product_tier(product_name),
		})
		pool.remove_at(pick)
	return result


func _make_city_demands(products: Array, district_index: int) -> Array:
	var excluded := []
	for product_variant in products:
		var product: Dictionary = product_variant
		excluded.append(String(product.get("name", "")))
	var local_demands: Array = districts[district_index].get("demands", []) if district_index >= 0 and district_index < districts.size() else []
	var result := []
	for demand_variant in local_demands:
		var demand_name := String(demand_variant)
		if demand_name != "" and not excluded.has(demand_name) and not result.has(demand_name):
			result.append(demand_name)
		if result.size() >= CITY_DEMAND_COUNT_MAX:
			return result
	var target_count := rng.randi_range(CITY_DEMAND_COUNT_MIN, CITY_DEMAND_COUNT_MAX)
	var filler := _random_product_names(target_count + excluded.size(), target_count + excluded.size(), excluded)
	for demand_variant in filler:
		var demand_name := String(demand_variant)
		if demand_name != "" and not result.has(demand_name):
			result.append(demand_name)
		if result.size() >= target_count:
			break
	return result


func _city_build_error() -> String:
	if game_over:
		return "本局已结束"
	if _has_pending_target_choice():
		return "先完成卡牌目标选择"
	return _city_build_error_for(selected_player, selected_district, true)


func _city_build_error_for(player_index: int, district_index: int, require_cooldown: bool = false) -> String:
	if game_over:
		return "本局已结束"
	if players.is_empty():
		return "没有玩家"
	if player_index < 0 or player_index >= players.size():
		return "没有有效玩家"
	if district_index < 0 or district_index >= districts.size():
		return "没有选中区域"
	var district: Dictionary = districts[district_index]
	if bool(district.get("destroyed", false)):
		return "区域已毁"
	if String(district.get("terrain", "land")) == "ocean":
		return "海洋区只能运输，不能城市化"
	if not _district_city(district_index).is_empty():
		return "已有城市群"
	var player: Dictionary = players[player_index]
	if require_cooldown and float(player.get("action_cooldown", 0.0)) > 0.0:
		return "行动冷却中"
	if int(player.get("cash", 0)) < CITY_BUILD_COST:
		return "资金不足"
	return ""


func _create_city_at_district_for_player(player_index: int, district_index: int, source: String = "城市化", reveal_owner_in_log: bool = true) -> bool:
	var error := _city_build_error_for(player_index, district_index, false)
	if error != "":
		_log("%s无法城市化：%s。" % [source, error])
		return false
	var player: Dictionary = players[player_index]
	var district: Dictionary = districts[district_index]
	var products := _make_city_products(district_index)
	var demands := _make_city_demands(products, district_index)
	player["cash"] -= CITY_BUILD_COST
	player["total_build_spend"] = int(player.get("total_build_spend", 0)) + CITY_BUILD_COST
	player["cities_built"] = int(player.get("cities_built", 0)) + 1
	district["hp"] = int(district.get("hp", 10)) + CITY_HP_BONUS
	district["damage"] = max(0, int(district.get("damage", 0)) - 2)
	district["city"] = {
		"owner": player_index,
		"active": true,
		"level": 1,
		"gdp_focus": String(district.get("economic_focus", "balanced")),
		"gdp_focus_label": String(district.get("economic_focus_label", _district_economy_focus_label(String(district.get("economic_focus", "balanced"))))),
		"products": products,
		"demands": demands,
		"revenue_bonus": 0,
		"contract_income_bonus": 0,
		"contract_turns": 0,
		"contract_source": "",
		"last_income": 0,
		"competition_matches": 0,
		"trade_routes": [],
		"trade_disrupted_routes": 0,
		"trade_route_damage": 0,
		"supplied_demands": 0,
		"built_at": game_time,
		"last_public_clue": "",
		"public_clues": [],
	}
	players[player_index] = player
	districts[district_index] = district
	_refresh_city_networks()
	_refresh_product_market_prices()
	_record_player_economic_event(player_index, "建城支出", source, -CITY_BUILD_COST, String(district.get("name", "区域")))
	_record_player_cash_snapshot(player_index)
	_pulse_district(district_index, _player_color(player_index))
	_add_map_event_effect("city_rise", _district_center(district_index), _player_color(player_index), "城市冒出", CITY_BUILD_ANIMATION_SECONDS + 0.55, float(district.get("radius_m", 70.0)))
	_add_action_callout(
		"匿名财团",
		"城市化完成",
		"%s出现一座生产%d种、需求%d种商品的新城市群；真实业主未公开。" % [district["name"], products.size(), demands.size()],
		Color("#67e8f9"),
		_district_center(district_index)
	)
	if reveal_owner_in_log:
		_log("%s在%s秘密完成城市化，生产：%s；需求：%s。" % [
			player["name"],
			district["name"],
			_city_product_price_summary(district["city"]),
			_city_demand_price_summary(district["city"]),
		])
	else:
		_log("%s：%s冒出匿名城市群，生产%d种、需求%d种商品；真实业主未公开。" % [
			source,
			district["name"],
			products.size(),
			demands.size(),
		])
	return true


func _build_city_in_selected_district() -> void:
	var error := _city_build_error()
	if error != "":
		_log("无法在选区城市化：%s。" % error)
		_refresh_ui()
		return
	if _create_city_at_district_for_player(selected_player, selected_district, "玩家城市化", true):
		_start_player_cooldown(ACTION_COOLDOWN)
	_refresh_ui()


func _rival_auto_city_cap() -> int:
	return clampi(
		RIVAL_AUTO_BUILD_BASE_CITY_CAP + int(business_cycle_count / 3),
		RIVAL_AUTO_BUILD_BASE_CITY_CAP,
		RIVAL_AUTO_BUILD_MAX_CITY_CAP
	)


func _can_auto_build_city_for_player(player_index: int) -> bool:
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return false
	var player: Dictionary = players[player_index]
	if int(player.get("cash", 0)) < CITY_BUILD_COST + RIVAL_AUTO_BUILD_MIN_CASH_RESERVE:
		return false
	if _player_active_city_count(player_index) >= _rival_auto_city_cap():
		return false
	return true


func _rival_build_player_order() -> Array:
	var result := []
	for i in range(players.size()):
		if not _player_is_ai(i):
			continue
		result.append(i)
	for i in range(result.size()):
		var swap_index := rng.randi_range(i, result.size() - 1)
		var tmp = result[i]
		result[i] = result[swap_index]
		result[swap_index] = tmp
	return result


func _district_product_overlap_with_rival_cities(player_index: int, district_index: int) -> int:
	if district_index < 0 or district_index >= districts.size():
		return 0
	var local_products: Array = districts[district_index].get("products", [])
	if local_products.is_empty():
		return 0
	var matches := 0
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		if int(city.get("owner", -1)) == player_index:
			continue
		for product_name in _city_product_names(city):
			if local_products.has(product_name):
				matches += 1
	return matches


func _district_ocean_neighbor_count(district_index: int) -> int:
	if district_index < 0 or district_index >= districts.size():
		return 0
	var count := 0
	for neighbor_variant in districts[district_index].get("neighbors", []):
		var neighbor := int(neighbor_variant)
		if neighbor >= 0 and neighbor < districts.size() and String(districts[neighbor].get("terrain", "land")) == "ocean":
			count += 1
	return count


func _auto_build_monster_risk_score(district_index: int) -> int:
	if district_index < 0 or district_index >= districts.size():
		return 0
	var risk := int(round(float(districts[district_index].get("panic", 0)) / 4.0))
	for actor_variant in auto_monsters:
		var actor: Dictionary = actor_variant
		if bool(actor.get("down", false)):
			continue
		var distance := _entity_distance_to_district(actor, district_index)
		if distance <= AUTO_MONSTER_ENCOUNTER_RANGE_METERS:
			risk += 54
		elif distance <= NEARBY_RADIUS_METERS:
			risk += 34
		elif distance <= NEARBY_RADIUS_METERS * 1.75:
			risk += 16
		risk += _monster_resource_match_score(actor, district_index) * 8
	return risk


func _auto_build_score_for_player(player_index: int, district_index: int) -> int:
	if _city_build_error_for(player_index, district_index, false) != "":
		return 0
	var district: Dictionary = districts[district_index]
	var score := 40
	for product_variant in district.get("products", []):
		var product_name := String(product_variant)
		score += 8 + int(round(float(_product_price(product_name)) / 10.0))
	for demand_variant in district.get("demands", []):
		var demand_name := String(demand_variant)
		score += 4 + int(round(float(_product_price(demand_name)) / 18.0))
	score += _district_ocean_neighbor_count(district_index) * 18
	score += _district_trade_route_load(district_index) * 6
	score += _district_product_overlap_with_rival_cities(player_index, district_index) * 14
	score += _ai_district_focus_score(player_index, district_index)
	score += _ai_strategy_bonus_for_candidate(player_index, "city_build", district_index, _ai_focus_product(player_index))
	score += _ai_route_plan_bonus_for_candidate(player_index, "city_build", district_index)
	score += _ai_phase_bonus_for_candidate(player_index, "city_build", district_index, _ai_focus_product(player_index), player_index)
	score += _ai_learning_bonus(player_index, "city_build", _ai_strategy_intent(player_index), _ai_route_plan_stage(player_index), _ai_route_plan_product(player_index), "城市化")
	score += int(float(district.get("transport_score", 1.0)) * 10.0)
	score += max(0, int(district.get("hp", 0)) - int(district.get("damage", 0)))
	score -= int(district.get("damage", 0)) * 9
	score -= _auto_build_monster_risk_score(district_index)
	return max(1, score)


func _auto_build_target_for_player(player_index: int) -> int:
	var candidates := []
	var weights := []
	for i in range(districts.size()):
		var score := _auto_build_score_for_player(player_index, i)
		if score <= 0:
			continue
		candidates.append(i)
		weights.append(score)
	var picked := _weighted_pick_index(weights)
	if picked < 0:
		return -1
	return int(candidates[picked])


func _auto_expand_rival_syndicates(force: bool = false) -> int:
	if game_over or players.size() <= 1:
		return 0
	var built := 0
	var limit := players.size() - 1 if force else RIVAL_AUTO_BUILD_MAX_PER_CYCLE
	for player_index_variant in _rival_build_player_order():
		if built >= limit:
			break
		var player_index := int(player_index_variant)
		if not _can_auto_build_city_for_player(player_index):
			continue
		if not force and rng.randi_range(1, 100) > RIVAL_AUTO_BUILD_CHANCE_PERCENT:
			continue
		var target := _auto_build_target_for_player(player_index)
		if target < 0:
			continue
		var target_score := _auto_build_score_for_player(player_index, target)
		var focus_product := _ai_focus_product(player_index)
		var focus_bonus := _ai_district_focus_score(player_index, target)
		var strategy_intent := _ai_strategy_intent(player_index)
		var strategy_bonus := _ai_strategy_bonus_for_candidate(player_index, "city_build", target, focus_product)
		var route_product := _ai_route_plan_product(player_index)
		var route_stage := _ai_route_plan_stage(player_index)
		var route_bonus := _ai_route_plan_bonus_for_candidate(player_index, "city_build", target)
		var phase_info := _ai_refresh_game_phase(player_index)
		var phase_bonus := _ai_phase_bonus_for_candidate(player_index, "city_build", target, focus_product, player_index)
		var learning_bonus := _ai_learning_bonus(player_index, "city_build", strategy_intent, route_stage, route_product, "城市化")
		if _create_city_at_district_for_player(player_index, target, "对手自动扩张", false):
			_record_ai_decision(
				player_index,
				"城市化",
				target,
				target_score,
				"GDP/商品/交通/竞争/怪兽风险综合评分｜阶段:%s/%s+%d｜经济焦点:%s｜焦点加成%d｜策略:%s｜策略加成%d｜路线:%s/%s｜路线加成%d" % [_ai_game_phase_label(String(phase_info.get("phase", "midgame"))), _ai_competitive_posture_label(String(phase_info.get("posture", "contesting"))), phase_bonus, focus_product if focus_product != "" else "未定", focus_bonus, strategy_intent if strategy_intent != "" else "未定", strategy_bonus, route_product if route_product != "" else "未定", _ai_route_plan_stage_label(route_stage), route_bonus],
				[],
				{"policy_kind": "city_build", "focus_product": focus_product, "focus_score": _ai_focus_score(player_index), "focus_bonus": focus_bonus, "strategy_intent": strategy_intent, "strategy_score": _ai_strategy_score(player_index), "strategy_bonus": strategy_bonus, "route_plan_product": route_product, "route_plan_stage": route_stage, "route_plan_score": _ai_route_plan_score(player_index), "route_plan_bonus": route_bonus, "game_phase": String(phase_info.get("phase", "midgame")), "competitive_posture": String(phase_info.get("posture", "contesting")), "score_gap_to_leader": int(phase_info.get("gap", 0)), "leader_index": int(phase_info.get("leader_index", -1)), "phase_bonus": phase_bonus, "learning_bonus": learning_bonus}
			)
			built += 1
	if built > 0:
		_add_action_callout(
			"匿名财团",
			"秘密扩张",
			"%d座新城市群在经营暗流中冒出；真实业主未公开。" % built,
			Color("#67e8f9"),
			_district_center(selected_district)
		)
		_log("经营暗流：%d座匿名城市群完成自动扩张，玩家需要通过商品、商路和后续行动推理业主。" % built)
		_refresh_ui()
	return built


func _active_city_indices_for_player(player_index: int) -> Array:
	var result := []
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		if int(_district_city(city_index).get("owner", -1)) == player_index:
			result.append(city_index)
	return result


func _competing_city_indices_for_product(player_index: int, product_name: String) -> Array:
	var result := []
	if product_name == "":
		return result
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		if int(city.get("owner", -1)) == player_index:
			continue
		if _city_product_names(city).has(product_name):
			result.append(city_index)
	return result


func _rival_business_candidates_for_player(player_index: int) -> Array:
	var result := []
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return result
	if int(players[player_index].get("cash", 0)) < RIVAL_BUSINESS_ACTION_COST:
		return result
	_ensure_product_market_catalog()
	var focus_product := _ai_focus_product(player_index)
	var strategy_intent := _ai_strategy_intent(player_index)
	var strategy_score := _ai_strategy_score(player_index)
	var route_product := _ai_route_plan_product(player_index)
	var route_stage := _ai_route_plan_stage(player_index)
	var plan_route_score := _ai_route_plan_score(player_index)
	var phase_info := _ai_refresh_game_phase(player_index)
	var phase := String(phase_info.get("phase", "midgame"))
	var posture := String(phase_info.get("posture", "contesting"))
	for own_city_index_variant in _active_city_indices_for_player(player_index):
		var own_city_index := int(own_city_index_variant)
		var own_city := _district_city(own_city_index)
		for product_name_variant in _city_product_names(own_city):
			var product_name := String(product_name_variant)
			var entry: Dictionary = product_market.get(product_name, {})
			var price := int(entry.get("price", entry.get("base_price", _product_price(product_name))))
			var demand_score := int(entry.get("demand", 0))
			var supply_score := int(entry.get("supply", 0))
			var competitors := _competing_city_indices_for_product(player_index, product_name)
			var price_score := 35 + int(round(float(price) / 6.0)) + demand_score * 5 - supply_score * 2 + competitors.size() * 22
			if product_name == focus_product:
				price_score += AI_ECONOMIC_FOCUS_MATCH_BONUS
			var price_strategy_bonus := _ai_strategy_bonus_for_candidate(player_index, "product_speculation", own_city_index, product_name, player_index)
			price_score += price_strategy_bonus
			var price_route_bonus := _ai_route_plan_bonus_for_candidate(player_index, "product_speculation", own_city_index, product_name, player_index)
			price_score += price_route_bonus
			var price_phase_bonus := _ai_phase_bonus_for_candidate(player_index, "product_speculation", own_city_index, product_name, player_index)
			price_score += price_phase_bonus
			var price_learning_bonus := _ai_learning_bonus(player_index, "price_pump", strategy_intent, route_stage, product_name, "匿名商业")
			price_score += price_learning_bonus
			result.append({
				"kind": "price_pump",
				"own_city": own_city_index,
				"product": product_name,
				"score": max(1, price_score),
				"focus_product": focus_product,
				"focus_bonus": AI_ECONOMIC_FOCUS_MATCH_BONUS if product_name == focus_product else 0,
				"strategy_intent": strategy_intent,
				"strategy_score": strategy_score,
				"strategy_bonus": price_strategy_bonus,
				"route_plan_product": route_product,
				"route_plan_stage": route_stage,
				"route_plan_score": plan_route_score,
				"route_plan_bonus": price_route_bonus,
				"game_phase": phase,
				"competitive_posture": posture,
				"score_gap_to_leader": int(phase_info.get("gap", 0)),
				"leader_index": int(phase_info.get("leader_index", -1)),
				"phase_bonus": price_phase_bonus,
				"policy_kind": "price_pump",
				"learning_bonus": price_learning_bonus,
			})
			for target_city_variant in competitors:
				var target_city_index := int(target_city_variant)
				var target_city := _district_city(target_city_index)
				var route_score := 42 + int(round(float(price) / 5.0))
				route_score += (target_city.get("trade_routes", []) as Array).size() * 4
				route_score += int(target_city.get("last_income", 0)) / 8
				route_score += int(target_city.get("competition_matches", 0)) * 7
				if product_name == focus_product:
					route_score += AI_ECONOMIC_FOCUS_MATCH_BONUS + 24
				var route_strategy_bonus := _ai_strategy_bonus_for_candidate(player_index, "route_sabotage", target_city_index, product_name, int(target_city.get("owner", -1)))
				route_score += route_strategy_bonus
				var sabotage_route_bonus := _ai_route_plan_bonus_for_candidate(player_index, "route_sabotage", target_city_index, product_name, int(target_city.get("owner", -1)))
				route_score += sabotage_route_bonus
				var sabotage_phase_bonus := _ai_phase_bonus_for_candidate(player_index, "route_sabotage", target_city_index, product_name, int(target_city.get("owner", -1)))
				route_score += sabotage_phase_bonus
				var sabotage_learning_bonus := _ai_learning_bonus(player_index, "route_sabotage", strategy_intent, route_stage, product_name, "匿名商业")
				route_score += sabotage_learning_bonus
				result.append({
					"kind": "route_sabotage",
					"own_city": own_city_index,
					"target_city": target_city_index,
					"product": product_name,
					"score": max(1, route_score),
					"focus_product": focus_product,
					"focus_bonus": AI_ECONOMIC_FOCUS_MATCH_BONUS + 24 if product_name == focus_product else 0,
					"strategy_intent": strategy_intent,
					"strategy_score": strategy_score,
					"strategy_bonus": route_strategy_bonus,
					"route_plan_product": route_product,
					"route_plan_stage": route_stage,
					"route_plan_score": plan_route_score,
					"route_plan_bonus": sabotage_route_bonus,
					"game_phase": phase,
					"competitive_posture": posture,
					"score_gap_to_leader": int(phase_info.get("gap", 0)),
					"leader_index": int(phase_info.get("leader_index", -1)),
					"phase_bonus": sabotage_phase_bonus,
					"policy_kind": "route_sabotage",
					"learning_bonus": sabotage_learning_bonus,
				})
	return result


func _pick_rival_business_action(player_index: int) -> Dictionary:
	var candidates := _rival_business_candidates_for_player(player_index)
	if candidates.is_empty():
		return {}
	var weights := []
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		weights.append(int(candidate.get("score", 1)))
	var picked := _weighted_pick_index(weights)
	if picked < 0:
		return {}
	return candidates[picked] as Dictionary


func _pay_rival_business_cost(player_index: int) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	var player: Dictionary = players[player_index]
	player["cash"] = max(0, int(player.get("cash", 0)) - RIVAL_BUSINESS_ACTION_COST)
	player["total_business_spend"] = int(player.get("total_business_spend", 0)) + RIVAL_BUSINESS_ACTION_COST
	players[player_index] = player
	_record_player_economic_event(player_index, "商业支出", "匿名商业行动", -RIVAL_BUSINESS_ACTION_COST, "经营周期%d" % business_cycle_count)
	_record_player_cash_snapshot(player_index)


func _city_public_clue_products_from_text(clue: String) -> Array:
	var products := []
	for product_variant in PRODUCT_CATALOG:
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
		"cycle": business_cycle_count,
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
	_ensure_product_market_catalog()
	var entry: Dictionary = product_market.get(product_name, {})
	if entry.is_empty():
		return false
	var before_price := _product_price(product_name)
	var delta := rng.randi_range(RIVAL_BUSINESS_PRICE_DELTA_MIN, RIVAL_BUSINESS_PRICE_DELTA_MAX)
	_pay_rival_business_cost(player_index)
	var pressure := maxi(1, int(ceil(float(delta) / 10.0)))
	entry["temporary_demand_pressure"] = int(entry.get("temporary_demand_pressure", 0)) + pressure
	product_market[product_name] = entry
	_refresh_product_market_prices()
	var after_price := _product_price(product_name)
	var clue := "周期%d：匿名财团制造%s需求压力%d，市场按供需重算¥%d→¥%d；疑似有生产该商品的城市受益。" % [
		business_cycle_count,
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


func _apply_rival_route_sabotage(player_index: int, action: Dictionary) -> bool:
	var own_city_index := int(action.get("own_city", -1))
	var target_city_index := int(action.get("target_city", -1))
	var product_name := String(action.get("product", ""))
	if target_city_index < 0 or target_city_index >= districts.size() or product_name == "":
		return false
	var target_city := _district_city(target_city_index)
	if not _city_is_active(target_city):
		return false
	if int(target_city.get("owner", -1)) == player_index:
		return false
	_pay_rival_business_cost(player_index)
	var before_damage := int(target_city.get("trade_route_damage", 0))
	target_city["trade_route_damage"] = before_damage + RIVAL_BUSINESS_ROUTE_DAMAGE
	var clue := "周期%d：匿名商路黑客攻击%s，疑似围绕%s竞争；真实业主未公开。" % [
		business_cycle_count,
		districts[target_city_index]["name"],
		product_name,
	]
	target_city = _append_city_public_clue(target_city, clue)
	districts[target_city_index]["city"] = target_city
	if own_city_index >= 0 and own_city_index < districts.size():
		_set_city_public_clue(own_city_index, "周期%d：疑似有匿名财团围绕%s压制竞争城市。" % [business_cycle_count, product_name])
	_refresh_city_networks()
	_pulse_district(target_city_index, Color("#fb7185"))
	_add_action_callout(
		"匿名商业",
		"商路黑客",
		"%s新增%d条断路压力；线索商品:%s。" % [
			districts[target_city_index]["name"],
			RIVAL_BUSINESS_ROUTE_DAMAGE,
			product_name,
		],
		Color("#fb7185"),
		_district_center(target_city_index)
	)
	_log("%s 断路压力%d→%d。" % [
		clue,
		before_damage,
		int(target_city.get("trade_route_damage", 0)),
	])
	return true


func _apply_rival_business_action(player_index: int, action: Dictionary) -> bool:
	match String(action.get("kind", "")):
		"price_pump":
			return _apply_rival_price_pump(player_index, action)
		"route_sabotage":
			return _apply_rival_route_sabotage(player_index, action)
	return false


func _auto_rival_business_actions(force: bool = false) -> int:
	if game_over or players.size() <= 1:
		return 0
	var acted := 0
	var limit := players.size() - 1 if force else RIVAL_BUSINESS_ACTION_MAX_PER_CYCLE
	for player_index_variant in _rival_build_player_order():
		if acted >= limit:
			break
		var player_index := int(player_index_variant)
		if int(players[player_index].get("cash", 0)) < RIVAL_BUSINESS_ACTION_COST:
			continue
		if not force and rng.randi_range(1, 100) > RIVAL_BUSINESS_ACTION_CHANCE_PERCENT:
			continue
		var action := _pick_rival_business_action(player_index)
		if action.is_empty():
			continue
		if _apply_rival_business_action(player_index, action):
			var target := int(action.get("target_city", action.get("own_city", -1)))
			_record_ai_decision(
				player_index,
				"匿名商业",
				target,
				int(action.get("score", 0)),
				"商品:%s｜阶段:%s/%s+%d｜经济焦点:%s｜焦点加成%d｜策略:%s｜策略加成%d｜路线:%s/%s｜路线加成%d" % [
					String(action.get("product", "未知")),
					_ai_game_phase_label(String(action.get("game_phase", "midgame"))),
					_ai_competitive_posture_label(String(action.get("competitive_posture", "contesting"))),
					int(action.get("phase_bonus", 0)),
					String(action.get("focus_product", "")),
					int(action.get("focus_bonus", 0)),
					String(action.get("strategy_intent", "")),
					int(action.get("strategy_bonus", 0)),
					String(action.get("route_plan_product", "")),
					_ai_route_plan_stage_label(String(action.get("route_plan_stage", ""))),
					int(action.get("route_plan_bonus", 0)),
				],
				[],
				{"policy_kind": String(action.get("policy_kind", action.get("kind", ""))), "product": String(action.get("product", "")), "focus_product": String(action.get("focus_product", "")), "focus_bonus": int(action.get("focus_bonus", 0)), "strategy_intent": String(action.get("strategy_intent", "")), "strategy_score": int(action.get("strategy_score", 0)), "strategy_bonus": int(action.get("strategy_bonus", 0)), "route_plan_product": String(action.get("route_plan_product", "")), "route_plan_stage": String(action.get("route_plan_stage", "")), "route_plan_score": int(action.get("route_plan_score", 0)), "route_plan_bonus": int(action.get("route_plan_bonus", 0)), "game_phase": String(action.get("game_phase", "midgame")), "competitive_posture": String(action.get("competitive_posture", "contesting")), "score_gap_to_leader": int(action.get("score_gap_to_leader", 0)), "leader_index": int(action.get("leader_index", -1)), "phase_bonus": int(action.get("phase_bonus", 0)), "learning_bonus": int(action.get("learning_bonus", 0))}
			)
			acted += 1
	if acted > 0:
		_log("经营暗流：%d次匿名商业行动留下公开线索，但没有揭示真实业主。" % acted)
		_refresh_ui()
	return acted


func _on_guess_option_selected(item_index: int, _option: OptionButton) -> void:
	selected_guess_player = clampi(item_index - 1, -1, players.size() - 1)
	if selected_guess_player == selected_player:
		selected_guess_player = -1
	_refresh_map_controls()


func _cycle_guess_player(step: int) -> void:
	if players.is_empty():
		return
	for _attempt in range(players.size() + 1):
		selected_guess_player = wrapi(selected_guess_player + step + 1, 0, players.size() + 1) - 1
		if selected_guess_player != selected_player:
			break
	_refresh_map_controls()


func _on_trade_product_selected(item_index: int, _option: OptionButton) -> void:
	if item_index <= 0:
		selected_trade_product = ""
	else:
		selected_trade_product = String(PRODUCT_CATALOG[clampi(item_index - 1, 0, PRODUCT_CATALOG.size() - 1)])
	_refresh_board()
	_refresh_map_controls()


func _toggle_selected_trade_route() -> void:
	if selected_trade_product != "":
		selected_trade_product = ""
	else:
		selected_trade_product = _default_trade_product_for_selected_district()
		if selected_trade_product == "" and not PRODUCT_CATALOG.is_empty():
			selected_trade_product = String(PRODUCT_CATALOG[0])
	_refresh_board()
	_refresh_map_controls()


func _cycle_trade_product(step: int) -> void:
	if PRODUCT_CATALOG.is_empty():
		return
	if selected_trade_product == "":
		selected_trade_product = _default_trade_product_for_selected_district()
		if selected_trade_product == "":
			selected_trade_product = String(PRODUCT_CATALOG[0])
	else:
		var index := PRODUCT_CATALOG.find(selected_trade_product)
		if index < 0:
			index = 0
		index = wrapi(index + step, 0, PRODUCT_CATALOG.size())
		selected_trade_product = String(PRODUCT_CATALOG[index])
	_refresh_board()
	_refresh_map_controls()


func _valid_contract_source_district(index: int) -> bool:
	return index >= 0 and index < districts.size() and not bool(districts[index].get("destroyed", false)) and String(districts[index].get("terrain", "land")) != "ocean"


func _valid_contract_target_district(index: int) -> bool:
	if index < 0 or index >= districts.size() or bool(districts[index].get("destroyed", false)):
		return false
	return _city_is_active(_district_city(index))


func _contract_district_short_name(index: int) -> String:
	if index < 0 or index >= districts.size():
		return "未设"
	return String(districts[index].get("name", "区域"))


func _contract_pair_summary() -> String:
	var source_text := _contract_district_short_name(selected_contract_source_district)
	var target_text := _contract_district_short_name(selected_contract_target_district)
	var product_text := selected_trade_product if selected_trade_product != "" else _default_trade_product_for_selected_district()
	if product_text == "":
		product_text = "自动商品"
	var status := "就绪" if _contract_pair_ready() else "未就绪"
	return "合约:%s→%s｜%s｜%s" % [source_text, target_text, product_text, status]


func _contract_pair_ready() -> bool:
	return _valid_contract_source_district(selected_contract_source_district) and _valid_contract_target_district(selected_contract_target_district) and selected_contract_source_district != selected_contract_target_district


func _set_selected_contract_source_district() -> void:
	if not _valid_contract_source_district(selected_district):
		_log("供给区必须是未毁陆地区域；海洋区暂只承担运输，不能作为生产合约源。")
		return
	selected_contract_source_district = selected_district
	if selected_contract_target_district == selected_contract_source_district:
		selected_contract_target_district = -1
	var product_name := _default_trade_product_for_selected_district()
	if selected_trade_product == "" and product_name != "":
		selected_trade_product = product_name
	_log("已把%s设为下一张区域供需合约的供给区。" % _contract_district_short_name(selected_contract_source_district))
	_refresh_ui()


func _set_selected_contract_target_district() -> void:
	if not _valid_contract_target_district(selected_district):
		_log("需求区必须是一座存活城市群；公开展示结束后，该城市真实业主会获得独立5秒签/拒窗口。")
		return
	selected_contract_target_district = selected_district
	if selected_contract_source_district == selected_contract_target_district:
		selected_contract_source_district = -1
	var product_name := _default_trade_product_for_selected_district()
	if selected_trade_product == "" and product_name != "":
		selected_trade_product = product_name
	_log("已把%s设为下一张区域供需合约的需求/签约区；真实业主仍不公开。" % _contract_district_short_name(selected_contract_target_district))
	_refresh_ui()


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
	var owner := int(city.get("owner", -1))
	var guesses: Dictionary = players[viewer_index].get("city_guesses", {})
	var confidences: Dictionary = players[viewer_index].get("city_guess_confidence", {})
	var reasons: Dictionary = players[viewer_index].get("city_guess_reasons", {})
	if owner == viewer_index:
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


func _role_city_reveal_charges(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var role := _player_role_card_for_index(player_index)
	return maxi(0, int(role.get("intel_city_reveal_charges", 0)))


func _use_selected_role_city_reveal() -> void:
	if _use_role_city_reveal_for_player(selected_player, selected_district, "身份侦测"):
		_refresh_ui()


func _use_role_city_reveal_for_player(player_index: int, city_index: int, source: String = "身份侦测") -> bool:
	if game_over or player_index < 0 or player_index >= players.size():
		return false
	if city_index < 0 or city_index >= districts.size():
		return false
	var city := _district_city(city_index)
	if not _city_is_active(city):
		_log("%s没有可侦测的存活城市群。" % String(districts[city_index].get("name", "区域")))
		return false
	var owner := int(city.get("owner", -1))
	if owner < 0 or owner >= players.size() or owner == player_index:
		_log("%s不是陌生城市；身份侦测不会消耗。" % String(districts[city_index].get("name", "区域")))
		return false
	var role := _player_role_card_for_index(player_index)
	var charges := int(role.get("intel_city_reveal_charges", 0))
	if charges <= 0:
		_log("%s没有剩余区域身份侦测次数。" % String(role.get("name", "当前角色")))
		return false
	role["intel_city_reveal_charges"] = charges - 1
	players[player_index]["role_card"] = role
	var marked := _mark_city_guess_for_player(player_index, city_index, owner, CITY_GUESS_CONFIDENCE_HIGH, CITY_GUESS_REASON_ROLE)
	if marked:
		_record_player_economic_event(player_index, "情报", String(role.get("name", source)), 0, "查明%s真实业主为玩家%d；答案只进入私人标注。" % [
			String(districts[city_index].get("name", "区域")),
			owner + 1,
		])
		_log("%s消耗%s：查明%s的真实业主并写入私人地图；剩余%d次。" % [
			String(players[player_index].get("name", "玩家")),
			String(role.get("name", source)),
			String(districts[city_index].get("name", "区域")),
			charges - 1,
		])
	return marked


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
	var owner := int(entry.get("player_index", -1))
	if resolution_id < 0 or owner < 0 or owner >= players.size():
		return false
	var known: Dictionary = (players[viewer_index] as Dictionary).get("known_card_owners", {})
	if int(known.get(str(resolution_id), -1)) == owner:
		return false
	known[str(resolution_id)] = owner
	players[viewer_index]["known_card_owners"] = known
	_record_player_economic_event(viewer_index, "情报", source, 0, "私下查明轨道#%d《%s》由玩家%d打出。" % [
		resolution_id,
		_card_resolution_entry_card_label(entry),
		owner + 1,
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


func _remember_contract_parties_for_player(viewer_index: int, entry: Dictionary, source: String) -> bool:
	if viewer_index < 0 or viewer_index >= players.size():
		return false
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	if resolution_id < 0:
		return false
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	if String(skill.get("kind", "")) != "area_trade_contract":
		return false
	var proposer := int(entry.get("player_index", -1))
	var target_owner := int(entry.get("contract_target_owner", -1))
	if proposer < 0 or proposer >= players.size() or target_owner < 0 or target_owner >= players.size():
		return false
	var known: Dictionary = (players[viewer_index] as Dictionary).get("known_contract_parties", {})
	if known.has(str(resolution_id)):
		return false
	known[str(resolution_id)] = {
		"proposer": proposer,
		"target_owner": target_owner,
		"source_district": int(entry.get("contract_source_district", -1)),
		"target_district": int(entry.get("contract_target_district", -1)),
		"response": String(entry.get("contract_response", "")),
	}
	players[viewer_index]["known_contract_parties"] = known
	_record_player_economic_event(viewer_index, "情报", source, 0, "私下查明轨道#%d合约：出牌方玩家%d，目标业主玩家%d。" % [
		resolution_id,
		proposer + 1,
		target_owner + 1,
	])
	return true


func _traceable_contract_entries(preferred_resolution_id: int = -1, limit: int = 1) -> Array:
	var result := []
	if preferred_resolution_id >= 0:
		var preferred := _card_resolution_entry_by_id(preferred_resolution_id)
		if not preferred.is_empty() and String((preferred.get("skill", {}) as Dictionary).get("kind", "")) == "area_trade_contract":
			result.append(preferred)
	for i in range(resolved_card_history.size() - 1, -1, -1):
		if result.size() >= limit:
			return result
		var entry_variant: Variant = resolved_card_history[i]
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
		if resolution_id < 0 or resolution_id == preferred_resolution_id:
			continue
		var skill: Dictionary = entry.get("skill", {}) as Dictionary
		if String(skill.get("kind", "")) != "area_trade_contract":
			continue
		result.append(entry.duplicate(true))
	return result


func _trace_contract_parties_for_player(viewer_index: int, preferred_resolution_id: int = -1, count: int = 1, source: String = "密约回溯") -> int:
	var traced := 0
	for entry_variant in _traceable_contract_entries(preferred_resolution_id, maxi(1, count)):
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if _remember_contract_parties_for_player(viewer_index, entry, source):
			traced += 1
			_log("%s获得一条匿名合约线索：轨道#%d的双方身份已写入私人情报。" % [
				String((players[viewer_index] as Dictionary).get("name", "玩家")),
				int(entry.get("resolution_id", entry.get("queued_order", -1))),
			])
	return traced


func _reveal_city_owner_by_intel_card(player_index: int, city_index: int, source: String) -> bool:
	if player_index < 0 or player_index >= players.size() or city_index < 0 or city_index >= districts.size():
		return false
	var city := _district_city(city_index)
	if not _city_is_active(city):
		return false
	var owner := int(city.get("owner", -1))
	if owner < 0 or owner >= players.size() or owner == player_index:
		return false
	if not _mark_city_guess_for_player(player_index, city_index, owner, CITY_GUESS_CONFIDENCE_HIGH, CITY_GUESS_REASON_CARD):
		return false
	_record_player_economic_event(player_index, "情报", source, 0, "线索牌查明%s真实业主为玩家%d；答案只进入私人标注。" % [
		String(districts[city_index].get("name", "区域")),
		owner + 1,
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
	return traced > 0


func _apply_intel_contract_trace(_player: Dictionary, skill: Dictionary) -> bool:
	var traced := _trace_contract_parties_for_player(
		selected_player,
		selected_card_resolution_id,
		maxi(1, int(skill.get("trace_contract_count", 1))),
		String(skill.get("name", "密约回溯"))
	)
	return traced > 0


func _apply_card_access_boon(player: Dictionary, skill: Dictionary) -> bool:
	if selected_player < 0 or selected_player >= players.size():
		return false
	var seconds := maxf(5.0, float(skill.get("card_access_seconds", 30.0)))
	var until_time := game_time + seconds
	player["card_access_expire_time"] = maxf(float(player.get("card_access_expire_time", -1.0)), until_time)
	player["card_access_extra_hops"] = maxi(maxi(0, int(player.get("card_access_extra_hops", 0))), maxi(0, int(skill.get("card_access_extra_hops", 0))))
	player["extended_card_price_multiplier"] = maxf(float(player.get("extended_card_price_multiplier", 1.10)), float(skill.get("extended_card_price_multiplier", 1.10)))
	if bool(skill.get("card_access_global", false)):
		player["card_access_global"] = true
		player["global_card_price_multiplier"] = maxf(float(player.get("global_card_price_multiplier", 1.35)), float(skill.get("global_card_price_multiplier", 1.35)))
	players[selected_player] = player
	var effect_text := "全局采购×%.2f" % float(player.get("global_card_price_multiplier", 1.35)) if bool(player.get("card_access_global", false)) else "怪兽补给半径+%d跳，远程价×%.2f" % [
		int(player.get("card_access_extra_hops", 0)),
		float(player.get("extended_card_price_multiplier", 1.10)),
	]
	_record_player_economic_event(selected_player, "补给权限", String(skill.get("name", "远程补给链")), 0, "%s，持续%.0f秒。" % [effect_text, seconds])
	_log("匿名补给权限生效：一名未公开玩家获得%s，持续%.0f秒。" % [effect_text, seconds])
	return true


func _selected_city_owner_view_text() -> String:
	var city := _district_city(selected_district)
	if city.is_empty():
		return "未城市化"
	if not _city_is_active(city):
		return "城市废墟"
	var owner := int(city.get("owner", -1))
	if owner == selected_player:
		return "己方城市"
	var guesses: Dictionary = players[selected_player].get("city_guesses", {}) if selected_player >= 0 and selected_player < players.size() else {}
	var guess := int(guesses.get(selected_district, -1))
	return "归属未知" if guess < 0 else "我的推测：玩家%d" % (guess + 1)


func _selected_city_info_text() -> String:
	if selected_district < 0 or selected_district >= districts.size():
		return "未选择区域"
	var city := _district_city(selected_district)
	if city.is_empty():
		return "%s｜%s｜未城市化" % [districts[selected_district]["name"], String(districts[selected_district].get("terrain_label", "区域"))]
	if not _city_is_active(city):
		return "%s｜城市废墟" % districts[selected_district]["name"]
	var products := _city_product_names(city)
	var product_preview := "、".join(products.slice(0, min(3, products.size())))
	if products.size() > 3:
		product_preview += "等%d种" % products.size()
	return "%s｜%s｜%s｜需供%d/%d｜断路%d｜同类竞争%d｜%s" % [
		districts[selected_district]["name"],
		_selected_city_owner_view_text(),
		product_preview,
		int(city.get("supplied_demands", 0)),
		(city.get("demands", []) as Array).size(),
		int(city.get("trade_disrupted_routes", 0)),
		int(city.get("competition_matches", 0)),
		_city_intel_hint_for_player(selected_district, selected_player),
	]


func _refresh_map_controls() -> void:
	var build_error := _city_build_error()
	for button_variant in map_build_buttons:
		var button: Button = button_variant
		button.text = "城市化 %d" % CITY_BUILD_COST
		button.disabled = build_error != ""
		button.tooltip_text = "在选中区域秘密建造城市群。" if build_error == "" else build_error
	var city := _district_city(selected_district)
	var can_guess := _city_is_active(city) and int(city.get("owner", -1)) != selected_player
	for button_variant in map_guess_buttons:
		var button: Button = button_variant
		button.disabled = not can_guess
		button.tooltip_text = "保存私人业主推测；终局猜对+¥%d，猜错-¥%d，正误不会提前揭晓。" % [
			INTEL_CORRECT_GUESS_CASH,
			INTEL_WRONG_GUESS_COST,
		] if can_guess else "只有陌生存活城市可以标注业主推测。"
	var role_city_reveal_charges := _role_city_reveal_charges(selected_player)
	for button_variant in map_role_intel_buttons:
		var button: Button = button_variant
		button.text = "身份侦测×%d" % role_city_reveal_charges
		button.disabled = not can_guess or role_city_reveal_charges <= 0
		button.tooltip_text = "消耗1次角色身份侦测，私下查明当前城市真实业主。" if not button.disabled else "需要拥有区域侦测型角色、剩余次数，并选中陌生存活城市。"
	for option_variant in map_guess_options:
		var option: OptionButton = option_variant
		option.disabled = not can_guess
		for i in range(MAX_PLAYER_COUNT):
			option.set_item_disabled(i + 1, i >= players.size() or i == selected_player)
		option.select(clampi(selected_guess_player + 1, 0, min(players.size(), MAX_PLAYER_COUNT)))
	for label_variant in map_city_info_labels:
		var label: Label = label_variant
		label.text = _selected_city_info_text()
	var product_index := PRODUCT_CATALOG.find(selected_trade_product)
	for option_variant in map_trade_options:
		var option: OptionButton = option_variant
		option.select(product_index + 1 if product_index >= 0 else 0)
	for button_variant in map_trade_buttons:
		var button: Button = button_variant
		button.text = "关闭商路" if selected_trade_product != "" else "查看商路"
		if selected_trade_product != "":
			button.tooltip_text = "当前显示：%s。" % selected_trade_product
		else:
			button.tooltip_text = "显示当前选区相关商品的运输路径。"
	for label_variant in map_trade_info_labels:
		var label: Label = label_variant
		if selected_trade_product == "":
			label.text = "商路关闭"
		else:
			label.text = "%s｜%d条" % [selected_trade_product, _trade_routes_for_product(selected_trade_product).size()]
	var can_set_contract_source := _valid_contract_source_district(selected_district)
	for button_variant in map_contract_source_buttons:
		var button: Button = button_variant
		button.disabled = not can_set_contract_source
		button.text = "供给:%s" % ("选区" if selected_contract_source_district != selected_district else "已设")
		button.tooltip_text = "打出合约牌前必须先点：把当前选中陆地区域设为下一张合约的供给区。" if can_set_contract_source else "供给区必须是未毁陆地区域；合约牌打出前需要先点供给区。"
	var can_set_contract_target := _valid_contract_target_district(selected_district)
	for button_variant in map_contract_target_buttons:
		var button: Button = button_variant
		button.disabled = not can_set_contract_target
		button.text = "需求:%s" % ("选区" if selected_contract_target_district != selected_district else "已设")
		button.tooltip_text = "打出合约牌前必须先点：把当前存活城市群设为下一张合约的需求/签约区。" if can_set_contract_target else "需求区必须有存活城市群；合约牌打出前需要先点需求区。"
	for label_variant in map_contract_info_labels:
		var label: Label = label_variant
		label.text = _contract_pair_summary()


func _city_markers_for_selected_player() -> Array:
	var result := []
	var guesses: Dictionary = players[selected_player].get("city_guesses", {}) if selected_player >= 0 and selected_player < players.size() else {}
	for i in range(districts.size()):
		var city := _district_city(i)
		if city.is_empty():
			continue
		var owner := int(city.get("owner", -1))
		var is_own := owner == selected_player
		var guess := int(guesses.get(i, -1))
		var tag := "己" if is_own else ("?" if guess < 0 else "猜%d" % (guess + 1))
		var tag_color := _player_color(owner) if is_own else (Color("#94a3b8") if guess < 0 else _player_color(guess))
		result.append({
			"district": i,
			"position": _district_center(i),
			"level": int(city.get("level", 1)),
			"active": bool(city.get("active", true)),
			"tag": tag,
			"tag_color": tag_color,
			"products": _city_product_names(city),
			"competition": int(city.get("competition_matches", 0)),
			"rise": clamp((game_time - float(city.get("built_at", 0.0))) / CITY_BUILD_ANIMATION_SECONDS, 0.0, 1.0),
		})
	return result

func _district_button_text(index: int) -> String:
	var d: Dictionary = districts[index]
	var markers := []
	for i in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[i]
		if int(actor.get("position", -1)) == index:
			markers.append("怪%d:%s" % [i + 1, String(actor.get("name", "怪兽"))])
	if d["miasma"]:
		markers.append("瘴气")
	var marker_text := ""
	if not markers.is_empty():
		marker_text = "\n[%s]" % " / ".join(markers)
	var state := "已破坏" if d["destroyed"] else "HP %d/%d" % [max(0, d["hp"] - d["damage"]), d["hp"]]
	var terrain_text := String(d.get("terrain_label", "区域"))
	var district_products: Array = d.get("products", [])
	var district_demands: Array = d.get("demands", [])
	if String(d.get("terrain", "land")) == "ocean":
		terrain_text += "航道"
	else:
		terrain_text += " 产%d/需%d" % [district_products.size(), district_demands.size()]
	var city_text := "未城市化"
	var city: Dictionary = d.get("city", {})
	if not city.is_empty():
		city_text = "城市废墟" if not bool(city.get("active", true)) else "%d项商品" % (city.get("products", []) as Array).size()
	return "%s%s\n%s  热%d\n%.0fm²  %s  %s" % [
		d["name"],
		marker_text,
		state,
		int(d["panic"]),
		float(d.get("area_m2", 0.0)),
		terrain_text,
		city_text,
	]


func _player_quick_goal_hint(player_index: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return "目标提示：选择玩家后开始操作。"
	if game_over:
		return "目标提示：本局已结束，查看终局总结，理解钱从哪里来。"
	if _has_pending_target_choice():
		return "目标提示：这张牌需要先指定目标怪兽。"
	if not _pending_contract_offers_for_player(player_index).is_empty():
		return "目标提示：匿名合约等待回应，签或拒都会留下线索。"
	if victory_countdown_active:
		return "目标提示：终局倒计时中，保护现金/城市，或压制疑似领先者。"
	if _ai_owned_active_monster_count(player_index) <= 0:
		return "目标提示：先召唤怪兽，怪兽落地区和邻区才会开放购牌。"
	if _player_active_city_count(player_index) <= 0:
		if selected_district >= 0 and selected_district < districts.size() and _city_build_error_for(player_index, selected_district, false) == "":
			return "目标提示：当前区域可城市化；城市GDP会按周期变成钱。"
		return "目标提示：选择陆地区域建城，先建立稳定收入。"
	if selected_district >= 0 and selected_district < districts.size():
		if _can_buy_card_from_district(selected_district, player_index) and not (districts[selected_district].get("card_choices", []) as Array).is_empty():
			return "目标提示：当前区域可购牌；重复获得同名牌会自动升级。"
		if _city_build_error_for(player_index, selected_district, false) == "":
			return "目标提示：可以继续建城扩张GDP，但现金要留给购牌和竞价。"
		var city := _district_city(selected_district)
		if _city_is_active(city):
			var owner := int(city.get("owner", -1))
			if owner == player_index:
				return "目标提示：这是己方城市；用生产、需求、交通和合约提高GDP。"
			if owner >= 0:
				return "目标提示：陌生城市可标注业主；猜对终局赚钱，猜错要赔。"
	if _player_counted_hand_size(players[player_index] as Dictionary) <= 0:
		return "目标提示：去怪兽所在区或邻区买牌，手牌上限%d张。" % PLAYER_HAND_LIMIT
	return "目标提示：满足商品流动后匿名出牌；扩GDP、护商路，或压制竞争城市。"


func _opening_guide_visible(player_index: int) -> bool:
	if opening_guide_dismissed or game_over:
		return false
	if player_index < 0 or player_index >= players.size():
		return false
	return game_time <= 120.0 or _ai_owned_active_monster_count(player_index) <= 0 or _player_active_city_count(player_index) <= 0


func _opening_guide_step(done: bool, text: String) -> String:
	return "%s %s" % ["✓" if done else "□", text]


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


func _opening_guide_progress(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= players.size():
		return {}
	var player: Dictionary = players[player_index]
	var has_monster := _ai_owned_active_monster_count(player_index) > 0
	var has_city := _player_active_city_count(player_index) > 0
	var has_bought_card := int(player.get("total_card_spend", 0)) > 0 or _player_counted_hand_size(player) > 1
	var has_played_card := false
	for entry_variant in resolved_card_history:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if int(entry.get("player_index", -1)) == player_index:
			has_played_card = true
			break
	for entry_variant in card_resolution_queue:
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("player_index", -1)) == player_index:
			has_played_card = true
	for entry_variant in next_card_resolution_queue:
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("player_index", -1)) == player_index:
			has_played_card = true
	if int(active_card_resolution.get("player_index", -1)) == player_index:
		has_played_card = true
	var has_checked_economy := _opening_guide_economy_seen(player_index)
	return {
		"has_monster": has_monster,
		"has_city": has_city,
		"has_bought_card": has_bought_card,
		"has_played_card": has_played_card,
		"has_checked_economy": has_checked_economy,
	}


func _opening_guide_lines(player_index: int) -> Array:
	var progress := _opening_guide_progress(player_index)
	return [
		_opening_guide_step(bool(progress.get("has_monster", false)), "先召唤怪兽，开启落地区/邻区购牌。"),
		_opening_guide_step(bool(progress.get("has_city", false)), "在陆地建城市，GDP 周期收入会变成钱。"),
		_opening_guide_step(bool(progress.get("has_bought_card", false)), "从怪兽补给范围买牌；重复牌自动升到 II/III/IV。"),
		_opening_guide_step(bool(progress.get("has_played_card", false)), "满足商品流动后匿名出牌，需要目标的牌会先询问。"),
		_opening_guide_step(bool(progress.get("has_checked_economy", false)), "打开经济总览，看商品、商路和城市收入拆解。"),
	]


func _opening_guide_next_step_text(player_index: int) -> String:
	var progress := _opening_guide_progress(player_index)
	if progress.is_empty():
		return "当前下一步：选择玩家后开始操作。"
	if not bool(progress.get("has_monster", false)):
		return "当前下一步：选一个落点，点「在选区首召」。"
	if not bool(progress.get("has_city", false)):
		if selected_district >= 0 and selected_district < districts.size() and _city_build_error_for(player_index, selected_district, false) == "":
			return "当前下一步：点「城市化」，先建第一座收入城市。"
		return "当前下一步：切到陆地区域，再点「城市化」。"
	if not bool(progress.get("has_bought_card", false)):
		if selected_district >= 0 and selected_district < districts.size() and _can_buy_card_from_district(selected_district, player_index):
			return "当前下一步：按 X 或点当前区域候选卡，买一张牌。"
		return "当前下一步：切到怪兽落地区或邻区，按 X 买牌。"
	if not bool(progress.get("has_played_card", false)):
		return "当前下一步：选择手牌匿名出牌；需要目标的牌会先询问。"
	if not bool(progress.get("has_checked_economy", false)):
		return "当前下一步：点「经济总览」，看 GDP、商品和商路为什么赚钱。"
	return "当前下一步：扩 GDP、护商路，或压制疑似竞争城市。"


func _dismiss_opening_guide() -> void:
	opening_guide_dismissed = true
	_refresh_ui()


func _add_opening_guide_panel(parent: Container, player_index: int) -> void:
	if not _opening_guide_visible(player_index):
		return
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111827")
	style.border_color = Color("#38bdf8")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var title := _plain_label("开局轻引导（可关闭）", 12, Color("#bae6fd"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var economy_button := Button.new()
	economy_button.text = "经济总览"
	economy_button.tooltip_text = "查看GDP、商品、商路和城市收入拆解。"
	economy_button.pressed.connect(Callable(self, "_open_economy_overview_menu"))
	header.add_child(economy_button)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.tooltip_text = "本局不再显示这块轻引导。"
	close_button.pressed.connect(Callable(self, "_dismiss_opening_guide"))
	header.add_child(close_button)
	box.add_child(_plain_label(_opening_guide_next_step_text(player_index), 10, Color("#bfdbfe")))
	for line_variant in _opening_guide_lines(player_index):
		box.add_child(_plain_label(String(line_variant), 10, Color("#dbeafe")))
	box.add_child(_plain_label("最后按钱最多获胜；出牌匿名，但条件和结果会留下推理线索。", 10, Color("#fef3c7")))


func _refresh_player_panel() -> void:
	_clear_children(player_box)
	if players.is_empty():
		return
	if selected_player < 0 or selected_player >= players.size():
		selected_player = 0

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	player_box.add_child(top_row)
	var selector := HBoxContainer.new()
	selector.add_theme_constant_override("separation", 6)
	top_row.add_child(selector)
	for i in range(players.size()):
		var button := Button.new()
		button.text = players[i]["name"]
		button.toggle_mode = true
		button.button_pressed = i == selected_player
		button.pressed.connect(Callable(self, "_select_player").bind(i))
		selector.add_child(button)

	var player: Dictionary = players[selected_player]
	var player_status := _plain_label("%s｜资金:%d｜手牌:%d/%d" % [
		player["name"],
		player["cash"],
		_player_counted_hand_size(player),
		PLAYER_HAND_LIMIT,
	], 14, Color("#e2e8f0"))
	player_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(player_status)
	player_box.add_child(_plain_label(_player_quick_goal_hint(selected_player), 11, Color("#bbf7d0")))
	_add_opening_guide_panel(player_box, selected_player)

	var tip_row := HBoxContainer.new()
	tip_row.add_theme_constant_override("separation", 6)
	player_box.add_child(tip_row)
	var active_tip := _selected_card_tip_amount(selected_player)
	var queued_bid_index := _queued_card_entry_index_for_player(selected_player)
	var next_queued_bid_index := _next_batch_card_entry_index_for_player(selected_player)
	var bid_controls_locked := (queued_bid_index >= 0 and not card_resolution_auction_open) or (queued_bid_index < 0 and next_queued_bid_index >= 0)
	var tip_mode := "候补牌公开报价" if queued_bid_index >= 0 else ("下一批等待牌" if next_queued_bid_index >= 0 else "下张牌预设报价")
	var tip_hint := _plain_label("%s ¥%d：" % [tip_mode, active_tip], 11, Color("#fde68a"))
	tip_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip_row.add_child(tip_hint)
	for increment_variant in CARD_BID_INCREMENT_OPTIONS:
		var increment := int(increment_variant)
		var tip_button := Button.new()
		tip_button.text = "+%d" % increment
		tip_button.disabled = game_over or bid_controls_locked or int(player.get("cash", 0)) < active_tip + increment
		tip_button.tooltip_text = _card_bid_button_tooltip(selected_player, active_tip + increment)
		tip_button.pressed.connect(Callable(self, "_increase_selected_card_bid").bind(increment))
		tip_row.add_child(tip_button)
	var reset_bid_button := Button.new()
	reset_bid_button.text = "清零"
	reset_bid_button.disabled = game_over or bid_controls_locked or active_tip <= 0
	reset_bid_button.tooltip_text = _card_bid_button_tooltip(selected_player, 0)
	reset_bid_button.pressed.connect(Callable(self, "_reset_selected_card_bid"))
	tip_row.add_child(reset_bid_button)
	var queue_hint := _plain_label("队列：%s" % _card_resolution_status_text(), 11, Color("#94a3b8"))
	queue_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip_row.add_child(queue_hint)
	player_box.add_child(_plain_label(_card_bid_control_status_text(selected_player), 11, _card_bid_control_status_color(selected_player)))

	if _has_pending_target_choice():
		var pending_skill := _pending_target_skill()
		player_box.add_child(_plain_label("请选择目标怪兽：%s 需要指定目标后才会结算。" % String(pending_skill.get("name", "这张卡")), 13, Color("#fef3c7")))
		_add_pending_target_buttons(player_box)
	_add_active_contract_response_panel(player_box)

	_add_first_summon_prompt(player_box, player)

	var hand_box := VBoxContainer.new()
	hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_box.add_theme_constant_override("separation", 6)
	player_box.add_child(hand_box)
	hand_box.add_child(_plain_label("手牌卡面（绑定固定怪兽技能不占上限）", 12, Color("#bfdbfe")))
	var hand_scroll := ScrollContainer.new()
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_box.add_child(hand_scroll)
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 10)
	hand_scroll.add_child(hand_row)
	for i in range(player["slots"].size()):
		var skill = player["slots"][i]
		if skill == null:
			_add_empty_card_slot(hand_row, i)
			continue
		_add_card_face(hand_row, String(skill["name"]), skill as Dictionary, i, true, true)


func _active_contract_response_entry_for_player(player_index: int) -> Dictionary:
	var offers := _pending_contract_offers_for_player(player_index)
	if offers.is_empty():
		return {}
	return offers[0] as Dictionary


func _pending_contract_offer_index_for_id(contract_id: int) -> int:
	for i in range(pending_contract_offers.size()):
		var offer: Dictionary = pending_contract_offers[i]
		if int(offer.get("contract_offer_id", offer.get("resolution_id", -1))) == contract_id:
			return i
	return -1


func _pending_contract_offer_by_id(contract_id: int) -> Dictionary:
	var index := _pending_contract_offer_index_for_id(contract_id)
	if index < 0:
		return {}
	return (pending_contract_offers[index] as Dictionary).duplicate(true)


func _pending_contract_offers_for_player(player_index: int) -> Array:
	var result := []
	for offer_variant in pending_contract_offers:
		if not (offer_variant is Dictionary):
			continue
		var offer := offer_variant as Dictionary
		var skill: Dictionary = offer.get("skill", {}) as Dictionary
		if String(skill.get("kind", "")) != "area_trade_contract":
			continue
		if int(offer.get("contract_target_owner", -1)) != player_index:
			continue
		if String(offer.get("contract_response", "")) != CONTRACT_RESPONSE_PENDING:
			continue
		result.append(offer)
	return result


func _contract_entry_product_text(entry: Dictionary) -> String:
	var products: Array = entry.get("contract_products", [])
	if products.is_empty():
		return "未指定商品"
	return "、".join(products)


func _contract_response_public_label(entry: Dictionary) -> String:
	match String(entry.get("contract_response", "")):
		CONTRACT_RESPONSE_ACCEPTED:
			return "已签约"
		CONTRACT_RESPONSE_REJECTED:
			return "已拒签"
		CONTRACT_RESPONSE_TIMEOUT:
			return "超时拒签"
		CONTRACT_RESPONSE_PENDING:
			var offer_id := int(entry.get("contract_offer_id", entry.get("resolution_id", -1)))
			if offer_id >= 0 and _pending_contract_offer_index_for_id(offer_id) >= 0:
				return "签约窗口开放"
			return "等待目标业主"
	return "无签约窗口"


func _contract_accept_effect_summary(skill: Dictionary) -> String:
	var pieces := []
	var cash := int(skill.get("accept_cash", 0))
	if cash > 0:
		pieces.append("¥+%d" % cash)
	var production_delta := int(skill.get("accept_production_delta", 0))
	var transport_delta := int(skill.get("accept_transport_delta", 0))
	var consumption_delta := int(skill.get("accept_consumption_delta", 0))
	if production_delta != 0:
		pieces.append("生产%s" % _signed_int_text(production_delta))
	if transport_delta != 0:
		pieces.append("交通%s" % _signed_int_text(transport_delta))
	if consumption_delta != 0:
		pieces.append("消费%s" % _signed_int_text(consumption_delta))
	var flow_multiplier := float(skill.get("accept_route_flow_multiplier", 1.0))
	if flow_multiplier > 1.001:
		pieces.append("流通×%.2f/%d周期" % [flow_multiplier, maxi(1, int(skill.get("route_flow_turns", 1)))])
	var add_products := int(skill.get("contract_add_products", 0))
	var add_demands := int(skill.get("contract_add_demands", 0))
	var remove_products := int(skill.get("contract_remove_products", 0))
	var remove_demands := int(skill.get("contract_remove_demands", 0))
	if add_products > 0 or add_demands > 0:
		pieces.append("接入供%d/需%d" % [maxi(0, add_products), maxi(0, add_demands)])
	if remove_products > 0 or remove_demands > 0:
		pieces.append("替换供%d/需%d" % [maxi(0, remove_products), maxi(0, remove_demands)])
	return "、".join(pieces) if not pieces.is_empty() else "无额外奖励"


func _contract_decline_effect_summary(skill: Dictionary) -> String:
	var pieces := []
	var penalty := int(skill.get("decline_cash_penalty", 0))
	if penalty > 0:
		pieces.append("罚¥%d" % penalty)
	var production_delta := int(skill.get("decline_production_delta", 0))
	var transport_delta := int(skill.get("decline_transport_delta", 0))
	var consumption_delta := int(skill.get("decline_consumption_delta", 0))
	if production_delta != 0:
		pieces.append("生产%s" % _signed_int_text(production_delta))
	if transport_delta != 0:
		pieces.append("交通%s" % _signed_int_text(transport_delta))
	if consumption_delta != 0:
		pieces.append("消费%s" % _signed_int_text(consumption_delta))
	var route_damage := int(skill.get("decline_route_damage", 0))
	if route_damage > 0:
		pieces.append("断路+%d" % route_damage)
	return "、".join(pieces) if not pieces.is_empty() else "无额外惩罚"


func _add_active_contract_response_panel(parent: Container) -> void:
	var offers := _pending_contract_offers_for_player(selected_player)
	for offer_variant in offers:
		_add_pending_contract_offer_panel(parent, offer_variant as Dictionary)


func _add_pending_contract_offer_panel(parent: Container, entry: Dictionary) -> void:
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	var source_index := int(entry.get("contract_source_district", -1))
	var target_index := int(entry.get("contract_target_district", -1))
	var contract_id := int(entry.get("contract_offer_id", entry.get("resolution_id", -1)))
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1f2937")
	style.border_color = Color("#fbbf24")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	box.add_child(_plain_label("匿名合约签署窗口｜剩余%.1fs" % maxf(0.0, float(entry.get("contract_decision_timer", CONTRACT_DECISION_SECONDS))), 13, Color("#fef3c7")))
	box.add_child(_plain_label("%s：%s → %s｜商品：%s｜发起者匿名" % [
		_card_display_name(String(skill.get("name", "合约牌"))),
		_contract_district_short_name(source_index),
		_contract_district_short_name(target_index),
		_contract_entry_product_text(entry),
	], 12, Color("#fde68a")))
	box.add_child(_plain_label("签约奖励：%s｜拒签惩罚：%s" % [
		_contract_accept_effect_summary(skill),
		_contract_decline_effect_summary(skill),
	], 11, Color("#cbd5e1")))
	box.add_child(_plain_label("这是公开展示结束后的独立5秒决定窗口；它不会阻塞其他玩家继续出牌。", 11, Color("#93c5fd")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var accept_button := Button.new()
	accept_button.text = "签约"
	accept_button.tooltip_text = "接受这份已完成公开展示的匿名合约。"
	accept_button.disabled = game_over
	accept_button.pressed.connect(Callable(self, "_respond_to_pending_contract").bind(contract_id, true))
	row.add_child(accept_button)
	var reject_button := Button.new()
	reject_button.text = "拒绝"
	reject_button.tooltip_text = "拒绝匿名合约；如果卡面带拒签惩罚，结算时会生效。"
	reject_button.disabled = game_over
	reject_button.pressed.connect(Callable(self, "_respond_to_pending_contract").bind(contract_id, false))
	row.add_child(reject_button)


func _respond_to_active_contract(accept: bool) -> void:
	var entry := _active_contract_response_entry_for_player(selected_player)
	if entry.is_empty():
		_log("当前玩家没有需要回应的匿名合约。")
		return
	_respond_to_pending_contract(int(entry.get("contract_offer_id", entry.get("resolution_id", -1))), accept)


func _respond_to_pending_contract(contract_id: int, accept: bool) -> void:
	_respond_to_pending_contract_for_player(selected_player, contract_id, accept)


func _respond_to_pending_contract_for_player(player_index: int, contract_id: int, accept: bool, announce: bool = true) -> bool:
	var index := _pending_contract_offer_index_for_id(contract_id)
	if index < 0:
		if announce:
			_log("这份匿名合约已经结算或不再有效。")
		return false
	var entry: Dictionary = pending_contract_offers[index]
	if int(entry.get("contract_target_owner", -1)) != player_index:
		if announce:
			_log("只有目标城市的真实业主可以回应这份匿名合约。")
		return false
	pending_contract_offers.remove_at(index)
	entry["contract_response"] = CONTRACT_RESPONSE_ACCEPTED if accept else CONTRACT_RESPONSE_REJECTED
	entry["contract_response_player"] = player_index
	entry["contract_response_time"] = game_time
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	_apply_area_trade_contract({}, skill, entry)
	_store_pending_contract_result(entry)
	if announce:
		_log("目标城市业主已在展示后的独立5秒窗口中%s匿名合约；合约发起者仍不公开。" % ("签署" if accept else "拒绝"))
	_refresh_ui()
	return true


func _store_pending_contract_result(entry: Dictionary) -> void:
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	var stored := _card_resolution_entry_by_id(resolution_id)
	if stored.is_empty():
		stored = entry.duplicate(true)
	else:
		for field in [
			"contract_offer_id",
			"contract_target_owner",
			"contract_response",
			"contract_response_player",
			"contract_response_time",
			"contract_decision_timer",
			"contract_decision_started_time",
		]:
			if entry.has(field):
				stored[field] = entry[field]
	_store_card_resolution_entry(stored)


func _add_empty_card_slot(parent: Container, slot_index: int) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(172, 220)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0f172a")
	style.border_color = Color("#334155")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	box.add_child(_plain_label("空手牌槽 %d" % (slot_index + 1), 13, Color("#94a3b8")))
	var hint := _plain_label("从地图选中区域的补给中获取卡牌。", 11, Color("#64748b"))
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(hint)


func _add_monster_art_preview(parent: Container, entry: Dictionary, compact: bool = false) -> void:
	var art_view = MonsterArtViewScript.new()
	art_view.custom_minimum_size = Vector2(300, 230) if compact else Vector2(360, 270)
	art_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art_view.set_monster(
		String(entry.get("name", "怪兽")),
		String(entry.get("style", "自动怪兽。")),
		int(entry.get("hp", 0)),
		int(entry.get("armor", 0)),
		_meters_text(float(entry.get("move", MONSTER_RAMPAGE_MOVE_METERS))),
		_monster_art_profile(String(entry.get("name", "怪兽"))),
		compact
	)
	parent.add_child(art_view)


func _add_role_card_face(parent: Container, role_card: Dictionary, compact: bool = false) -> void:
	if role_card.is_empty():
		return
	var accent := _role_card_theme_color(role_card)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(156, 188) if compact else Vector2(238, 286)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.tooltip_text = _role_card_tooltip(role_card)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b1120").lerp(accent, 0.18)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9 if compact else 10)
	margin.add_theme_constant_override("margin_top", 9 if compact else 10)
	margin.add_theme_constant_override("margin_right", 9 if compact else 10)
	margin.add_theme_constant_override("margin_bottom", 9 if compact else 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := _plain_label(String(role_card.get("name", "外星辛迪加")), 12 if compact else 16, Color("#f8fafc"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var tag_label := _plain_label(_role_card_tag_text(role_card), 9 if compact else 11, Color("#c4b5fd"))
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag_label)

	var art_view = CardArtViewScript.new()
	art_view.custom_minimum_size = Vector2(0, 60 if compact else 112)
	art_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_view.set_card(
		String(role_card.get("name", "外星辛迪加")),
		"player_role",
		_role_card_tag_text(role_card),
		accent,
		1,
		compact,
		_role_card_art_stats(role_card)
	)
	box.add_child(art_view)

	var effect := _plain_label(_role_card_face_text(role_card, compact), 9 if compact else 11, Color("#e5e7eb"))
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(effect)


func _add_first_summon_prompt(parent: Container, player: Dictionary) -> void:
	if not auto_monsters.is_empty() or _has_pending_target_choice():
		return
	var starter_slot := _first_starter_monster_slot(player)
	if starter_slot < 0:
		return
	var slots: Array = player.get("slots", [])
	var starter_card: Dictionary = slots[starter_slot] as Dictionary
	var prompt_box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1e293b").lerp(Color("#fbbf24"), 0.10)
	style.border_color = Color("#fbbf24")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	prompt_box.add_theme_stylebox_override("panel", style)
	parent.add_child(prompt_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	prompt_box.add_child(row)
	var label := _plain_label(_first_summon_prompt_text(starter_card), 12, Color("#fef3c7"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	button.text = "排队中" if bool(starter_card.get("queued_for_resolution", false)) else "在选区首召"
	button.tooltip_text = "把起始怪兽牌打到当前选中的区域。首召不限区域/商品流动，之后才会开启怪兽落地区与相邻区购牌。"
	button.disabled = game_over or bool(starter_card.get("queued_for_resolution", false)) or not _selected_district_can_receive_first_summon() or players[selected_player]["action_cooldown"] > 0.0 or not _can_play_skill_now(selected_player, starter_card, false)
	button.pressed.connect(Callable(self, "_use_skill").bind(starter_slot))
	row.add_child(button)


func _first_starter_monster_slot(player: Dictionary) -> int:
	var slots: Array = player.get("slots", [])
	for i in range(slots.size()):
		var slot_variant: Variant = slots[i]
		if not (slot_variant is Dictionary):
			continue
		var skill := slot_variant as Dictionary
		if String(skill.get("kind", "")) == "monster_card" and bool(skill.get("starter_play_free", false)):
			return i
	return -1


func _selected_district_can_receive_first_summon() -> bool:
	return selected_district >= 0 and selected_district < districts.size() and not bool(districts[selected_district].get("destroyed", false))


func _first_summon_prompt_text(starter_card: Dictionary) -> String:
	var district_name := "未选择区域"
	if selected_district >= 0 and selected_district < districts.size():
		district_name = String(districts[selected_district].get("name", "区域"))
	return "首召引导：先选落点，再打出%s；首召不限区/免商品流动，召唤后固定技能%d张，并开放落地区/邻区购牌。当前落点：%s。" % [
		_card_display_name(String(starter_card.get("name", "起始怪兽牌"))),
		int(starter_card.get("fixed_skill_count", 1)),
		district_name,
	]


func _role_card_theme_color(role_card: Dictionary) -> Color:
	if PLAYER_COLORS.is_empty():
		return Color("#38bdf8")
	var index := wrapi(int(role_card.get("role_index", role_codex_index)), 0, PLAYER_COLORS.size())
	return (PLAYER_COLORS[index] as Color).lerp(Color("#f59e0b"), 0.18)


func _role_card_tag_text(role_card: Dictionary) -> String:
	return "角色卡 / %s" % String(role_card.get("species", "未知外星人"))


func _role_card_art_stats(role_card: Dictionary) -> String:
	var parts := ["起始:%s" % _card_display_name(String(role_card.get("starter_monster_card", "")))]
	var cash_bonus := int(role_card.get("starting_cash_bonus", 0))
	if cash_bonus > 0:
		parts.append("开局¥+%d" % cash_bonus)
	var resource_product := String(role_card.get("resource_cash_product", ""))
	var resource_amount := int(role_card.get("resource_cash_amount", 0))
	if resource_product != "" and resource_amount > 0:
		parts.append("周期:%s+¥%d" % [resource_product, resource_amount])
	var bonus_product := String(role_card.get("bonus_card_product", ""))
	if bonus_product != "":
		parts.append("购牌:%s+1" % bonus_product)
	var upgrade_cash := int(role_card.get("monster_upgrade_cash", 0))
	if upgrade_cash > 0:
		parts.append("升兽:+¥%d" % upgrade_cash)
	return "｜".join(parts)


func _role_card_face_text(role_card: Dictionary, compact: bool = false) -> String:
	var role_trait := String(role_card.get("trait", "暂无特征"))
	var starter := _card_display_name(String(role_card.get("starter_monster_card", "")))
	if compact:
		return "特征:%s\n被动:%s\n起始:%s" % [
			_short_card_text(role_trait, 34),
			_short_card_text(_role_passive_text(role_card), 26),
			_short_card_text(starter, 16),
		]
	return "特征：%s\n被动：%s\n起始怪兽牌：%s\n角色资料：不会被打出或消耗。" % [
		role_trait,
		_role_passive_text(role_card),
		starter,
	]


func _role_card_tooltip(role_card: Dictionary) -> String:
	return "%s\n种族：%s\n特征：%s\n被动：%s\n起始怪兽牌：%s\n规则：角色卡留在开局资料和角色图鉴中，不会被打出或消耗；起始怪兽牌用于开局召唤第一只自动怪兽。" % [
		String(role_card.get("name", "外星辛迪加")),
		String(role_card.get("species", "未知外星人")),
		String(role_card.get("trait", "暂无特征")),
		_role_passive_text(role_card),
		_card_display_name(String(role_card.get("starter_monster_card", ""))),
	]


func _add_card_face(parent: Container, skill_name: String, skill: Dictionary, slot_index: int = -1, is_hand_card: bool = false, compact: bool = false, show_action: bool = true) -> void:
	var accent := _card_theme_color(skill)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(178, 220) if compact else Vector2(218, 268)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.tooltip_text = _card_detail_tooltip(skill_name)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b1120").lerp(accent, 0.16)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var title := _plain_label("%s  %s" % [_skill_family(skill_name), _level_text(max(1, _skill_rank(skill_name)))], 14 if compact else 16, Color("#f8fafc"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var tag_label := _plain_label(_skill_tag_text(skill), 10 if compact else 11, Color("#c4b5fd"))
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag_label)

	var art_view = CardArtViewScript.new()
	art_view.custom_minimum_size = Vector2(0, 78 if compact else 112)
	art_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_view.set_card(
		_card_display_name(skill_name),
		String(skill.get("kind", "")),
		_skill_tag_text(skill),
		accent,
		max(1, _skill_rank(skill_name)),
		compact,
		_card_art_stats(skill)
	)
	box.add_child(art_view)

	var effect := _plain_label(_card_rules_text(skill_name, skill, compact or is_hand_card), 10 if compact else 11, Color("#e5e7eb"))
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(effect)

	if show_action:
		var action_button := Button.new()
		if is_hand_card:
			action_button.text = "排队中" if bool(skill.get("queued_for_resolution", false)) else "打出"
			action_button.disabled = game_over or bool(skill.get("queued_for_resolution", false)) or _has_pending_target_choice() or players[selected_player]["action_cooldown"] > 0.0 or float(skill.get("lock_left", 0.0)) > 0.0 or float(skill.get("cooldown_left", 0.0)) > 0.0 or not _can_play_skill_now(selected_player, skill, false)
			action_button.pressed.connect(Callable(self, "_use_skill").bind(slot_index))
		else:
			var price := _card_price(skill_name, selected_district, selected_player)
			action_button.text = "获取 ¥%d" % price
			action_button.disabled = game_over or _has_pending_target_choice() or selected_district < 0 or selected_district >= districts.size() or bool(districts[selected_district].get("destroyed", false)) or not _can_buy_card_from_district(selected_district, selected_player) or players[selected_player]["action_cooldown"] > 0.0 or int(players[selected_player].get("cash", 0)) < price or not _player_can_receive_card(players[selected_player], skill_name)
			action_button.pressed.connect(Callable(self, "_claim_district_card").bind(skill_name))
		box.add_child(action_button)


func _card_theme_color(skill: Dictionary) -> Color:
	match String(skill.get("kind", "")):
		"player_role":
			return Color("#38bdf8")
		"monster_card":
			return Color("#fb7185")
		"monster_bound_action":
			return Color("#c084fc")
		"monster_takeover":
			return Color("#f472b6")
		"city_revenue_boost", "cash_gain", "product_speculation", "product_contract_boon", "area_trade_contract", "route_insurance", "city_product_upgrade", "city_product_shift", "city_demand_shift", "market_stabilize", "product_growth_boon", "route_flow_boon", "city_contract_boon", "region_economy_shift":
			return Color("#f59e0b")
		"intel_city_reveal", "intel_card_trace", "intel_contract_trace":
			return Color("#60a5fa")
		"card_access_boon":
			return Color("#2dd4bf")
		"panic_shift":
			return Color("#f97316")
		"move", "fly", "burrow":
			return Color("#22c55e")
		"attack", "charge_attack", "roll_attack":
			return Color("#ef4444")
		"area_damage", "mudslide", "route_sabotage":
			return Color("#eab308")
		"miasma_shot", "miasma_bloom", "miasma_reclaim", "corrosive_breath":
			return Color("#a855f7")
		"armor_gain", "guard":
			return Color("#38bdf8")
		"monster_lure", "special_monster_delay", "roar":
			return Color("#818cf8")
		"supply_draw":
			return Color("#14b8a6")
	return Color("#94a3b8")


func _card_rules_text(skill_name: String, skill: Dictionary, compact: bool = false) -> String:
	var effect_text := _skill_display_text(skill)
	var strategy_text := _card_strategy_summary(skill, compact)
	var key_facts := _card_key_rule_facts(skill)
	var key_text := _join_first_card_facts(key_facts, 4)
	if key_text == "":
		key_text = "按效果文字结算"
	if compact:
		return "%s\n%s\n%s" % [
			_short_card_text(effect_text, 54),
			strategy_text,
			key_text,
		]
	return "%s\n%s\n%s｜%s" % [
		effect_text,
		strategy_text,
		"固定技能" if bool(skill.get("persistent", false)) else "一次性",
		key_text,
	]


func _card_strategy_route_label(skill: Dictionary) -> String:
	var kind := String(skill.get("kind", ""))
	var tags := _skill_tag_text(skill)
	var route_damage := int(skill.get("route_damage", 0)) + int(skill.get("decline_route_damage", 0))
	var repair_routes := int(skill.get("repair_routes", 0))
	var economy_delta := int(skill.get("production_delta", 0)) + int(skill.get("transport_delta", 0)) + int(skill.get("consumption_delta", 0))
	var accept_delta := int(skill.get("accept_production_delta", 0)) + int(skill.get("accept_transport_delta", 0)) + int(skill.get("accept_consumption_delta", 0))
	var decline_delta := int(skill.get("decline_production_delta", 0)) + int(skill.get("decline_transport_delta", 0)) + int(skill.get("decline_consumption_delta", 0))
	var market_pressure := int(skill.get("market_demand_pressure", 0)) + int(skill.get("market_supply_pressure", 0)) + int(skill.get("price_delta", 0))
	if kind == "monster_card" or kind == "monster_bound_action" or kind == "monster_lure" or kind == "monster_takeover" or tags.contains("怪兽"):
		return "怪兽路线"
	if kind == "intel_city_reveal" or kind == "intel_card_trace" or kind == "intel_contract_trace" or tags.contains("情报"):
		return "情报推理"
	if kind == "area_trade_contract" or kind == "product_contract_boon" or int(skill.get("contract_income", 0)) > 0 or accept_delta != 0 or decline_delta != 0 or int(skill.get("accept_cash", 0)) != 0 or int(skill.get("decline_cash_penalty", 0)) != 0:
		return "合约博弈"
	if kind == "city_gdp_derivative" or kind == "product_speculation" or kind == "market_stabilize" or market_pressure != 0:
		return "金融投机"
	if route_damage > 0 or economy_delta < 0 or kind == "route_sabotage" or kind == "area_damage":
		return "城市压制"
	if kind == "card_access_boon" or kind == "supply_draw" or int(skill.get("draw_amount", 0)) > 0 or bool(skill.get("card_access_global", false)) or int(skill.get("card_access_extra_hops", 0)) > 0:
		return "补给构筑"
	if repair_routes > 0 or economy_delta > 0 or kind == "city_revenue_boost" or kind == "cash_gain" or kind == "route_insurance" or kind == "city_product_upgrade" or kind == "city_product_shift" or kind == "city_demand_shift" or kind == "route_flow_boon" or kind == "product_growth_boon" or kind == "city_contract_boon" or float(skill.get("route_flow_multiplier", 1.0)) > 1.001 or float(skill.get("growth_multiplier", 1.0)) > 1.001 or int(skill.get("revenue_amount", 0)) > 0 or int(skill.get("cash", 0)) > 0:
		return "城市成长"
	if int(skill.get("damage", 0)) > 0 or kind in ["attack", "charge_attack", "roll_attack", "mudslide", "miasma_shot", "corrosive_breath"]:
		return "战斗破坏"
	if int(skill.get("panic", 0)) > 0 or kind == "panic_shift":
		return "怪兽诱导"
	return "即时战术"


func _card_strategy_use_text(skill: Dictionary) -> String:
	match _card_strategy_route_label(skill):
		"城市成长":
			return "提高己方GDP、商品/需求/交通或商路效率，适合领先或做长期收入。"
		"城市压制":
			return "压低目标城市GDP或破坏商路，适合打击竞品、配合城市做空。"
		"金融投机":
			return "围绕商品价格或城市GDP下注，把供需变化和破坏结果转成现金。"
		"合约博弈":
			return "连接或改写区域供需，签约有收益，拒签也可能留下惩罚压力。"
		"情报推理":
			return "获取城市、卡牌或合约归属线索，帮助把匿名行动反推成钱。"
		"怪兽路线":
			return "召唤、升级、诱导或夺取自动怪兽，让怪兽灾害影响资源和城市。"
		"补给构筑":
			return "扩大购牌范围或补手牌，让牌组更快升级成II/III/IV。"
		"战斗破坏":
			return "制造区域/怪兽伤害，推动城市损毁和GDP下跌。"
		"怪兽诱导":
			return "提高区域热度或改变怪兽下一步关注，制造可推理的灾害方向。"
	return "即时改变局势，通常用来补足当前回合的现金、目标或节奏缺口。"


func _card_strategy_summary(skill: Dictionary, compact: bool = false) -> String:
	var route := _card_strategy_route_label(skill)
	var use_text := _card_strategy_use_text(skill)
	if compact:
		return "路线:%s｜%s" % [route, _short_card_text(use_text, 34)]
	return "策略路线:%s｜用途:%s" % [route, use_text]


func _card_key_rule_facts(skill: Dictionary) -> Array:
	var result := []
	for fact_variant in _card_rule_facts(skill):
		var fact := String(fact_variant)
		if fact.begins_with("目标:") or fact.begins_with("出牌:") or fact.begins_with("打出条件："):
			continue
		if fact.strip_edges() != "":
			result.append(fact)
	return result


func _monster_card_duration_text(skill: Dictionary, compact: bool = false) -> String:
	var duration := float(skill.get("duration", -1.0))
	if duration < 0.0:
		return "常驻" if compact else "不限时（不会自然离场）"
	return "%.0fs" % duration if compact else "%.0f秒后自然离场" % duration


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
			return _nearest_active_monster_graph_distance(district_index, 1) >= 0
		"land_monster_zone":
			return terrain == "land" and _nearest_active_monster_graph_distance(district_index, 1) >= 0
		"ocean_monster_zone":
			return terrain == "ocean" and _nearest_active_monster_graph_distance(district_index, 1) >= 0
		"land":
			return terrain == "land"
		"ocean":
			return terrain == "ocean"
		"any", "":
			return true
	return true


func _card_art_stats(skill: Dictionary) -> String:
	if String(skill.get("kind", "")) == "city_gdp_derivative":
		return "%s｜%s×%.2f｜%d周期" % [
			_card_strategy_route_label(skill),
			"买涨" if String(skill.get("gdp_bet_direction", "up")) == "up" else "做空",
			float(skill.get("gdp_bet_multiplier", 1.0)),
			int(skill.get("gdp_bet_turns", 1)),
		]
	if String(skill.get("kind", "")) != "monster_card":
		var route := _card_strategy_route_label(skill)
		if int(skill.get("cash", 0)) > 0:
			return "%s｜+¥%d" % [route, int(skill.get("cash", 0))]
		if int(skill.get("revenue_amount", 0)) > 0:
			return "%s｜GDP+%d" % [route, int(skill.get("revenue_amount", 0))]
		if int(skill.get("route_damage", 0)) > 0:
			return "%s｜断路+%d" % [route, int(skill.get("route_damage", 0))]
		if int(skill.get("repair_routes", 0)) > 0:
			return "%s｜修路%d" % [route, int(skill.get("repair_routes", 0))]
		if int(skill.get("draw_amount", 0)) > 0:
			return "%s｜抽%d" % [route, int(skill.get("draw_amount", 0))]
		return route
	return "%s｜HP%d｜%s｜移%s｜%s" % [
		_card_strategy_route_label(skill),
		int(skill.get("hp", 0)),
		_monster_card_duration_text(skill, true),
		_meters_text(float(skill.get("move", 0.0))),
		_monster_card_region_text(skill, true),
	]


func _card_rule_facts(skill: Dictionary) -> Array:
	var facts := []
	facts.append("目标:%s" % ("指定怪兽" if _skill_requires_target_monster(skill) else "无需指定怪兽"))
	facts.append("出牌:%s" % ("固定技能，不会消失" if bool(skill.get("persistent", false)) else "一次性，打出后消失"))
	facts.append(_skill_play_requirement_text(skill, selected_player))
	if String(skill.get("kind", "")) == "monster_card":
		facts.append("生命:%d" % int(skill.get("hp", 0)))
		facts.append("在场:%s" % _monster_card_duration_text(skill))
		facts.append("召唤区域:%s" % _monster_card_region_text(skill))
	var move_m := float(skill.get("move", 0.0))
	var range_m := float(skill.get("range", 0.0))
	var damage := int(skill.get("damage", 0))
	var armor := int(skill.get("armor", 0))
	var guard := int(skill.get("guard", 0))
	var ranged_guard := int(skill.get("ranged_guard", 0))
	var knockback := float(skill.get("knockback", 0.0))
	var panic := int(skill.get("panic", 0))
	var revenue_amount := int(skill.get("revenue_amount", 0))
	var cash := int(skill.get("cash", 0))
	var draw_amount := int(skill.get("draw_amount", 0))
	var price_delta := int(skill.get("price_delta", 0))
	var repair_routes := int(skill.get("repair_routes", 0))
	var product_level := int(skill.get("product_level", 0))
	var product_shift := int(skill.get("product_shift", 0))
	var demand_shift := int(skill.get("demand_shift", 0))
	var contract_income := int(skill.get("contract_income", 0))
	var contract_turns := int(skill.get("contract_turns", 0))
	var market_demand_pressure := int(skill.get("market_demand_pressure", 0))
	var market_supply_pressure := int(skill.get("market_supply_pressure", 0))
	var market_contract_turns := int(skill.get("market_contract_turns", 0))
	var contract_add_products := int(skill.get("contract_add_products", 0))
	var contract_add_demands := int(skill.get("contract_add_demands", 0))
	var contract_remove_products := int(skill.get("contract_remove_products", 0))
	var contract_remove_demands := int(skill.get("contract_remove_demands", 0))
	var accept_cash := int(skill.get("accept_cash", 0))
	var decline_cash_penalty := int(skill.get("decline_cash_penalty", 0))
	var accept_production_delta := int(skill.get("accept_production_delta", 0))
	var accept_transport_delta := int(skill.get("accept_transport_delta", 0))
	var accept_consumption_delta := int(skill.get("accept_consumption_delta", 0))
	var decline_production_delta := int(skill.get("decline_production_delta", 0))
	var decline_transport_delta := int(skill.get("decline_transport_delta", 0))
	var decline_consumption_delta := int(skill.get("decline_consumption_delta", 0))
	var decline_route_damage := int(skill.get("decline_route_damage", 0))
	var accept_route_flow_multiplier := float(skill.get("accept_route_flow_multiplier", 1.0))
	var stabilize_amount := int(skill.get("stabilize_amount", 0))
	var volatility_delta := int(skill.get("volatility_delta", 0))
	var route_damage := int(skill.get("route_damage", 0))
	var production_delta := int(skill.get("production_delta", 0))
	var transport_delta := int(skill.get("transport_delta", 0))
	var consumption_delta := int(skill.get("consumption_delta", 0))
	var growth_multiplier := float(skill.get("growth_multiplier", 1.0))
	var growth_turns := int(skill.get("growth_turns", 0))
	var route_flow_multiplier := float(skill.get("route_flow_multiplier", 1.0))
	var route_flow_turns := int(skill.get("route_flow_turns", growth_turns))
	var delay := float(skill.get("delay", 0.0))
	var lure_speedup := float(skill.get("lure_speedup", 0.0))
	var miasma_count := int(skill.get("miasma_count", 0))
	var reclaim_count := int(skill.get("reclaim_count", 0))
	var reveal_city_count := int(skill.get("reveal_city_count", 0))
	var trace_card_count := int(skill.get("trace_card_count", 0))
	var trace_contract_count := int(skill.get("trace_contract_count", 0))
	var card_access_extra_hops := int(skill.get("card_access_extra_hops", 0))
	var card_access_seconds := float(skill.get("card_access_seconds", 0.0))
	var extended_card_price_multiplier := float(skill.get("extended_card_price_multiplier", 1.0))
	var card_access_global := bool(skill.get("card_access_global", false))
	var global_card_price_multiplier := float(skill.get("global_card_price_multiplier", 1.0))
	var gdp_bet_direction := String(skill.get("gdp_bet_direction", ""))
	var gdp_bet_multiplier := float(skill.get("gdp_bet_multiplier", 0.0))
	var gdp_bet_turns := int(skill.get("gdp_bet_turns", 0))
	var gdp_bet_destroy_bonus := int(skill.get("gdp_bet_destroy_bonus", 0))
	if move_m > 0.0:
		facts.append("移动:%s" % _meters_text(move_m))
	if range_m > 0.0:
		facts.append("范围:%s" % _meters_text(range_m))
	if damage > 0:
		facts.append("伤害:%d" % damage)
	if knockback > 0.0:
		facts.append("击退:%s" % _meters_text(knockback))
	if armor > 0:
		facts.append("护甲:+%d" % armor)
	if guard > 0:
		facts.append("格挡:%d" % guard)
	if ranged_guard > 0:
		facts.append("远程抗性:%d" % ranged_guard)
	if panic > 0:
		facts.append("热度:+%d" % panic)
	if revenue_amount > 0:
		facts.append("周期收入:+%d" % revenue_amount)
	if cash > 0:
		facts.append("资金:+%d" % cash)
	if draw_amount > 0:
		facts.append("候选卡:+%d" % draw_amount)
	if price_delta != 0:
		facts.append("%s压力:+%d" % ["需求" if price_delta > 0 else "供给", maxi(1, int(ceil(abs(float(price_delta)) / 10.0)))])
	if repair_routes > 0:
		facts.append("修复商路:%d" % repair_routes)
	if product_level > 0:
		facts.append("商品等级:+%d" % product_level)
	if product_shift > 0:
		facts.append("主营换线:%d" % product_shift)
	if demand_shift > 0:
		facts.append("需求改造:%d" % demand_shift)
	if contract_income > 0:
		facts.append("临时合约:+%d/%d周期" % [contract_income, maxi(1, contract_turns)])
	if market_demand_pressure > 0:
		facts.append("商品合约需求:+%d/%d周期" % [market_demand_pressure, maxi(1, market_contract_turns)])
	if market_supply_pressure > 0:
		facts.append("商品合约供给:+%d/%d周期" % [market_supply_pressure, maxi(1, market_contract_turns)])
	if contract_add_products > 0 or contract_add_demands > 0:
		facts.append("合约接入:供%d/需%d" % [maxi(0, contract_add_products), maxi(0, contract_add_demands)])
	if contract_remove_products > 0 or contract_remove_demands > 0:
		facts.append("合约替换:供%d/需%d" % [maxi(0, contract_remove_products), maxi(0, contract_remove_demands)])
	if accept_cash > 0:
		facts.append("签约奖励:+¥%d" % accept_cash)
	if accept_production_delta != 0 or accept_transport_delta != 0 or accept_consumption_delta != 0 or accept_route_flow_multiplier > 1.001:
		var accept_parts := []
		if accept_production_delta != 0:
			accept_parts.append("生产%s" % _signed_int_text(accept_production_delta))
		if accept_transport_delta != 0:
			accept_parts.append("交通%s" % _signed_int_text(accept_transport_delta))
		if accept_consumption_delta != 0:
			accept_parts.append("消费%s" % _signed_int_text(accept_consumption_delta))
		if accept_route_flow_multiplier > 1.001:
			accept_parts.append("流通×%.2f/%d周期" % [accept_route_flow_multiplier, maxi(1, int(skill.get("route_flow_turns", 1)))])
		facts.append("签约增益:%s" % "、".join(accept_parts))
	if decline_cash_penalty > 0:
		facts.append("拒签罚款:¥%d" % decline_cash_penalty)
	if decline_production_delta != 0 or decline_transport_delta != 0 or decline_consumption_delta != 0 or decline_route_damage > 0:
		var decline_parts := []
		if decline_production_delta != 0:
			decline_parts.append("生产%s" % _signed_int_text(decline_production_delta))
		if decline_transport_delta != 0:
			decline_parts.append("交通%s" % _signed_int_text(decline_transport_delta))
		if decline_consumption_delta != 0:
			decline_parts.append("消费%s" % _signed_int_text(decline_consumption_delta))
		if decline_route_damage > 0:
			decline_parts.append("断路+%d" % decline_route_damage)
		facts.append("拒签惩罚:%s" % "、".join(decline_parts))
	if stabilize_amount > 0:
		facts.append("削减临时供需:%d" % stabilize_amount)
	if volatility_delta != 0:
		facts.append("波动:%s" % _signed_int_text(volatility_delta))
	if route_damage > 0:
		facts.append("商路损伤:+%d" % route_damage)
	if production_delta != 0:
		facts.append("生产:%s" % _signed_int_text(production_delta))
	if transport_delta != 0:
		facts.append("交通:%s" % _signed_int_text(transport_delta))
	if consumption_delta != 0:
		facts.append("消费:%s" % _signed_int_text(consumption_delta))
	if growth_multiplier > 1.001:
		facts.append("商品增速:×%.2f/%d周期" % [growth_multiplier, maxi(1, growth_turns)])
	if route_flow_multiplier > 1.001:
		facts.append("流通:×%.2f/%d周期" % [route_flow_multiplier, maxi(1, route_flow_turns)])
	if delay > 0.0:
		facts.append("延后行动:%.1fs" % delay)
	if lure_speedup > 0.0:
		facts.append("诱导提前:%.1fs" % lure_speedup)
	if miasma_count > 0:
		facts.append("瘴气:%d" % miasma_count)
	if reclaim_count > 0:
		facts.append("回收瘴气:%d" % reclaim_count)
	if reveal_city_count > 0:
		facts.append("查区域业主:%d" % reveal_city_count)
	if trace_card_count > 0:
		facts.append("追溯出牌:%d" % trace_card_count)
	if trace_contract_count > 0:
		facts.append("追溯合约:%d" % trace_contract_count)
	if card_access_extra_hops > 0:
		facts.append("购牌半径:+%d跳/%.0fs×%.2f" % [card_access_extra_hops, maxf(1.0, card_access_seconds), maxf(1.0, extended_card_price_multiplier)])
	if card_access_global:
		facts.append("全局购牌:%.0fs×%.2f" % [maxf(1.0, card_access_seconds), maxf(1.0, global_card_price_multiplier)])
	if gdp_bet_direction != "":
		facts.append("GDP方向:%s" % ("买涨" if gdp_bet_direction == "up" else "做空"))
	if gdp_bet_multiplier > 0.0:
		facts.append("GDP倍率:×%.2f/%d周期" % [gdp_bet_multiplier, maxi(1, gdp_bet_turns)])
	if gdp_bet_destroy_bonus > 0:
		facts.append("破产奖励:¥%d" % gdp_bet_destroy_bonus)
	return facts


func _card_resolution_animation_catalog_text(card_name: String, skill: Dictionary) -> String:
	var stages := _card_resolution_animation_stages(card_name, skill)
	if stages.size() < 3:
		return "开场：卡面公开；结算：效果生效；余波：线索留在轨道。\n%s" % _card_resolution_visual_cue_text(skill)
	return "开场：%s\n结算：%s\n余波：%s\n%s" % [
		String(stages[0]),
		String(stages[1]),
		String(stages[2]),
		_card_resolution_visual_cue_text(skill),
	]


func _card_resolution_animation_text(card_name: String, skill: Dictionary, entry: Dictionary = {}, seconds_left: float = -1.0) -> String:
	var stages := _card_resolution_animation_stages(card_name, skill)
	var stage_index := _card_resolution_stage_index(seconds_left)
	var stage_label := _card_resolution_stage_label(stage_index)
	var current_stage := String(stages[clampi(stage_index, 0, max(0, stages.size() - 1))]) if not stages.is_empty() else "卡面公开，效果等待结算。"
	var target_text := _card_resolution_target_text(skill, entry)
	var timing_text := "分镜：开场→结算→余波"
	if seconds_left >= 0.0:
		timing_text = "当前分镜：%s｜剩余%.1fs" % [stage_label, maxf(0.0, seconds_left)]
	return "结算演出：%s\n%s\n%s\n落点：%s" % [
		current_stage,
		timing_text,
		_card_resolution_visual_cue_text(skill, seconds_left),
		target_text,
	]


func _card_resolution_animation_stages(card_name: String, skill: Dictionary) -> Array:
	var actual_name := card_name if card_name != "" else String(skill.get("name", "匿名卡牌"))
	var family := _skill_family(actual_name)
	var label := _card_display_name(actual_name)
	if label == "":
		label = family if family != "" else "匿名卡牌"
	var kind := String(skill.get("kind", ""))
	match kind:
		"monster_card":
			var monster_name := String(skill.get("monster_name", _monster_name_from_card_name(actual_name)))
			if monster_name == "":
				monster_name = family.replace("怪兽·", "")
			return [
				"轨道上撕开匿名召唤窗，%s的巨影先于出牌者身份坠向星球。" % monster_name,
				"落点播报生命%d、移动%s、在场%s；若同名怪兽在场，则转为升级并刷新生命/时间。" % [
					int(skill.get("hp", 0)),
					_meters_text(float(skill.get("move", 0.0))),
					_monster_card_duration_text(skill, true),
				],
				"怪兽归属仍隐藏；之后它受伤造成的资金损失才会把召唤者线索公开。",
			]
		"city_revenue_boost":
			return [
				"%s翻开时，目标城市上空亮起匿名投资光幕。" % label,
				"楼群、广告牌和隐形合同同步加码，周期收入数字从城市边缘浮起。",
				"收益留在城市经营账本里，但出牌者身份仍只能靠城市业主与商品流向推测。",
			]
		"city_contract_boon":
			return [
				"%s盖下临时合约封印，城市航港短暂变成高价订单会场。" % label,
				"合约倒计时和额外周期收入挂到城市卡片旁，持续周期逐步扣减。",
				"合同余波会继续影响GDP，其他玩家只能从该城收入异动反推匿名出牌者。",
			]
		"route_flow_boon", "route_insurance":
			return [
				"%s打开一条发光商路，运输节点像星港灯带一样被点亮。" % label,
				"受损路线被修补或加速，流通倍率贴到目标城市的商路状态上。",
				"之后几个经营周期，途经商品会以更快速度转成GDP收入。",
			]
		"route_sabotage":
			return [
				"%s以黑客遮罩侵入公开城市商路，运输线先闪烁再断裂。" % label,
				"目标城市追加商路损伤压力，区域热度也会留下可观察的破坏痕迹。",
				"真实业主仍不公开，但被破坏商路会改变相关商品的运输和城市收入。",
			]
		"product_speculation":
			return [
				"%s把当前商品推上匿名交易屏，价格曲线先剧烈抖动。" % label,
				"卡牌不直接改价，而是写入临时供需压力，等待下一次市场重算兑现。",
				"现金收益立即进匿名玩家账本；市场波动则成为其他玩家的反推证据。",
			]
		"city_gdp_derivative":
			return [
				"%s翻面时，目标城市上方出现匿名买涨/做空盘口。" % label,
				"系统记录该城当前GDP为基准；之后经营周期按GDP涨跌差额和卡面倍率兑现。",
				"若城市被怪兽摧毁，做空合约会进入破产清算；收款人仍保持匿名。",
			]
		"product_contract_boon":
			return [
				"%s把远期合约钉到当前商品，订单影像沿商路扩散。" % label,
				"持续供需压力和可能的流通倍率进入商品天气，按周期衰减。",
				"商品价格不会被手动改写，只会在后续供需重算里体现这张牌的余波。",
			]
		"area_trade_contract":
			return [
				"%s公开翻面：供给区、需求区和合约商品被投到所有玩家屏幕中央。" % label,
				"公开展示结束后，目标城市真实业主会再获得独立5秒签约/拒绝窗口；发起者仍保持匿名。",
				"签约会写入区域供需和流通奖励，拒签或超时会按卡面惩罚落到账本与商路。",
			]
		"product_growth_boon":
			return [
				"%s点燃当前商品的增长光环，相关商路出现短暂共鸣。" % label,
				"正向价格增速与流通倍率进入商品天气，并显示剩余周期。",
				"如果城市依赖该商品，后续GDP会在生产、运输或消费端被放大。",
			]
		"market_stabilize":
			return [
				"%s把交易屏切成冷色，过热的供需噪声被逐层压平。" % label,
				"当前商品的临时供需压力被削减，长期波动参数也会下降。",
				"市场仍按供需重算，稳定痕迹会留在商品图鉴和经济天气里。",
			]
		"city_product_upgrade", "city_product_shift", "city_demand_shift":
			return [
				"%s投下城市产业蓝图，目标城市的商品/需求槽位被高亮。" % label,
				"主营商品升级、换线或需求改造逐项写入城市经营结构。",
				"城市之后的GDP会按新的生产、需求和商路匹配重新结算。",
			]
		"region_economy_shift":
			return [
				"%s把区域切成生产、交通、消费三层经济网格。" % label,
				"卡面改写对应区域参数：生产量、公共交通速度或消费需求会升降。",
				"区域GDP来源随之改变，商路和商品流速会在之后周期持续体现。",
			]
		"cash_gain":
			return [
				"%s从轨道金库投下匿名资金包，卡轨只显示金额不显示收款人。" % label,
				"资金立即进入出牌者私有账本，并记录为卡牌经济事件。",
				"其他玩家只能从后续竞价、建城和购牌节奏推测这笔钱去了谁手里。",
			]
		"panic_shift":
			return [
				"%s把目标区域推上星际热搜，新闻噪声覆盖地图。" % label,
				"区域热度上升，怪兽目标概率和事件关注度随之偏移。",
				"如果热度过载，区域还可能因恐慌触发额外损伤。",
			]
		"supply_draw":
			return [
				"%s呼叫补给无人机，镜头从当前区域的卡池向手牌区拉线。" % label,
				"玩家从怪兽落地区/相邻区额外获得候选卡，重复牌会按规则合成升级。",
				"补给来源会留在卡牌记录里，但出牌者仍保持匿名。",
			]
		"monster_takeover":
			return [
				"%s在目标怪兽身上盖下新的匿名归属印记。" % label,
				"旧绑定技能被撤销，新归属者接收这只怪兽的后续资金线索和固定技能关系。",
				"夺取者不会公开；直到怪兽受伤造成资金损失，新的归属线索才浮出水面。",
			]
		"monster_lure", "special_monster_delay", "monster_bound_action":
			return [
				"%s锁定目标怪兽，中央卡面投出一次性诱导波形。" % label,
				"怪兽仍不是常驻可控单位；诱导牌只会改写下一次自动移动方向或延后一次特殊行动。",
				"指令结束后怪兽继续按自身概率自动行动，只留下匿名出牌痕迹。",
			]
		"move", "fly", "burrow":
			return [
				"%s在目标怪兽脚下画出移动轨迹，地图投影被拉成一条行动线。" % label,
				"怪兽沿路线移动，经过或落点区域会按移动破坏规则承受损伤。",
				"移动结束后区域伤害、城市受损和怪兽位置都会成为公开局势。",
			]
		"attack", "charge_attack", "roll_attack":
			return [
				"%s把目标怪兽推入近战镜头，攻击范围和击退方向同时亮起。" % label,
				"命中的怪兽承受伤害与击退；移动/击退路径会继续压坏途经城市和区域。",
				"战斗结果公开，但这次是谁借卡牌引导怪兽出手仍然匿名。",
			]
		"area_damage", "mudslide":
			return [
				"%s把地图缩到目标区域，危险半径像红色雷达圈一样展开。" % label,
				"区域HP、城市HP和热度按卡面数值结算，相关商路可能受到间接影响。",
				"破坏痕迹留在地图上，供玩家反推谁更想压低这里的GDP。",
			]
		"miasma_shot", "miasma_bloom", "miasma_reclaim", "corrosive_breath":
			return [
				"%s释放紫色瘴气分镜，雾带沿怪兽与区域之间蔓延。" % label,
				"瘴气会被布置、回收或转成伤害/回复，影响后续怪兽目标判断。",
				"被污染区域在地图上保留状态，成为资源掠夺与怪兽聚集的新诱因。",
			]
		"armor_gain", "guard":
			return [
				"%s把目标怪兽包进防御镜头，护甲或格挡数值浮到怪兽旁。" % label,
				"后续受击时先消耗防御层，部分格挡还会影响远程伤害。",
				"防御来源不公开，但怪兽耐久变化会成为所有玩家都能观察的线索。",
			]
		"roar":
			return [
				"%s让目标怪兽的吼声扩散成冲击环。" % label,
				"范围内怪兽行动被延后，自动行动节奏在时间轴上后移。",
				"控场余波不会改变归属，只改变下一轮怪兽行为窗口。",
			]
	return [
		"%s在中央轨道翻开，卡面公开但出牌者保持匿名。" % label,
		"系统按卡面效果、目标和商品流动条件进行结算。",
		"结算结果进入地图、经济账本或怪兽状态，供所有玩家继续推理。",
	]


func _card_resolution_stage_index(seconds_left: float) -> int:
	if seconds_left < 0.0:
		return 0
	var progress := _card_resolution_display_progress(seconds_left)
	if progress < 0.34:
		return 0
	if progress < 0.68:
		return 1
	return 2


func _card_resolution_display_progress(seconds_left: float) -> float:
	var duration := CARD_RESOLUTION_DISPLAY_SECONDS
	if card_resolution_force_duration > 0.0:
		duration = card_resolution_force_duration
	return clampf(1.0 - maxf(0.0, seconds_left) / maxf(0.1, duration), 0.0, 1.0)


func _card_resolution_stage_label(stage_index: int) -> String:
	match clampi(stage_index, 0, 2):
		0:
			return "开场"
		1:
			return "结算"
		2:
			return "余波"
	return "开场"


func _card_resolution_visual_cue_text(skill: Dictionary, seconds_left: float = -1.0) -> String:
	var style := _card_resolution_effect_style(skill)
	var style_label := _card_resolution_effect_style_label(style)
	if seconds_left >= 0.0:
		var stage_label := _card_resolution_stage_label(_card_resolution_stage_index(seconds_left))
		var stage_effect := _card_resolution_stage_effect_label(stage_label, style)
		var progress_percent := int(round(_card_resolution_display_progress(seconds_left) * 100.0))
		return "视觉提示：%s演出｜地图播报：%s｜展示进度：%d%%" % [
			style_label,
			stage_effect,
			progress_percent,
		]
	return "视觉提示：%s演出｜地图播报：%s / %s / %s" % [
		style_label,
		_card_resolution_stage_effect_label("开场", style),
		_card_resolution_stage_effect_label("结算", style),
		_card_resolution_stage_effect_label("余波", style),
	]


func _card_resolution_target_text(skill: Dictionary, entry: Dictionary = {}) -> String:
	var pieces := []
	var target_slot := int(entry.get("target_slot", -1))
	if target_slot >= 0:
		var actor_name := "怪兽"
		if target_slot < auto_monsters.size():
			var actor: Dictionary = auto_monsters[target_slot]
			actor_name = String(actor.get("name", "怪兽"))
		pieces.append("目标怪兽：怪%d·%s" % [target_slot + 1, actor_name])
	if String(skill.get("kind", "")) == "area_trade_contract":
		pieces.append("合约：%s→%s" % [
			_contract_district_short_name(int(entry.get("contract_source_district", -1))),
			_contract_district_short_name(int(entry.get("contract_target_district", -1))),
		])
		pieces.append("合约商品：%s" % _contract_entry_product_text(entry))
	var district_index := int(entry.get("selected_district", -1))
	if district_index >= 0 and district_index < districts.size():
		pieces.append("区域：%s" % String(districts[district_index].get("name", "区域")))
	var trade_product := String(entry.get("selected_trade_product", ""))
	if trade_product != "":
		pieces.append("商品：%s" % trade_product)
	if pieces.is_empty():
		pieces.append("目标类型：%s" % ("指定怪兽" if _skill_requires_target_monster(skill) else "按当前区域/商品结算"))
	return "｜".join(pieces)


func _sync_card_resolution_stage_visual(entry: Dictionary, skill: Dictionary, seconds_left: float) -> void:
	if entry.is_empty() or skill.is_empty():
		return
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	var stage_index := _card_resolution_stage_index(seconds_left)
	if card_resolution_visual_id == resolution_id and card_resolution_visual_stage >= stage_index:
		return
	card_resolution_visual_id = resolution_id
	card_resolution_visual_stage = stage_index
	_emit_card_resolution_stage_visual(entry, skill, stage_index)


func _emit_card_resolution_stage_visual(entry: Dictionary, skill: Dictionary, stage_index: int) -> void:
	var card_name := String(skill.get("name", "卡牌"))
	var card_label := _card_display_name(card_name)
	if card_label == "":
		card_label = card_name
	var stage_label := _card_resolution_stage_label(stage_index)
	var position := _card_resolution_effect_position(skill, entry)
	var color := _card_theme_color(skill)
	var style := _card_resolution_effect_style(skill)
	var kind := "card_open"
	var detail := "匿名卡牌进入公开展示，出牌者仍隐藏。"
	match clampi(stage_index, 0, 2):
		0:
			kind = "card_open"
			detail = "%s开场：卡面公开，目标位置被照亮。" % card_label
			var orbit_position := _wrap_world_position(position + Vector2(map_width_m * 0.08, -map_height_m * 0.06))
			_add_visual_trail(orbit_position, position, color, "匿名卡牌", 1.20, "card_ingress")
		1:
			kind = "card_resolve"
			detail = "%s结算：效果正写入地图/经济/怪兽状态。" % card_label
		2:
			kind = "card_afterglow"
			detail = "%s余波：公开结果留下推理线索。" % card_label
	_add_map_event_effect(kind, position, color, _card_resolution_stage_effect_label(stage_label, style), 1.25, _card_resolution_effect_radius(skill), style)
	_add_action_callout("匿名卡牌", "%s分镜" % stage_label, detail, color, position, 2.25)


func _add_card_resolution_aftermath_clue(entry: Dictionary, skill: Dictionary, resolved: bool) -> void:
	if skill.is_empty():
		return
	var card_name := String(skill.get("name", "卡牌"))
	var card_label := _card_display_name(card_name)
	if card_label == "":
		card_label = card_name
	var style := _card_resolution_effect_style(skill)
	var style_label := _card_resolution_effect_style_label(style)
	var clue := _card_resolution_aftermath_clue_text(skill, resolved)
	entry["aftermath_clue"] = clue
	entry["aftermath_style"] = style
	var position := _card_resolution_effect_position(skill, entry)
	var color := _card_theme_color(skill)
	if not resolved:
		color = color.darkened(0.28)
	var status := "已结算" if resolved else "未生效"
	var detail := "%s｜%s演出｜%s｜%s；轨道仍可竞猜归属。" % [
		status,
		style_label,
		_card_resolution_target_text(skill, entry),
		clue,
	]
	_add_action_callout("卡牌余波", card_label, detail, color, position, CARD_RESOLUTION_AFTERMATH_SECONDS)
	_add_map_event_effect(
		"card_afterglow",
		position,
		color,
		"余波%s" % style_label,
		CARD_RESOLUTION_AFTERMATH_SECONDS,
		_card_resolution_effect_radius(skill) * 1.12,
		style
	)


func _card_resolution_aftermath_clue_text(skill: Dictionary, resolved: bool) -> String:
	if not resolved:
		return "结算失败也会暴露条件缺口"
	var kind := String(skill.get("kind", ""))
	if kind == "monster_card":
		return "怪兽HP/时间/落点成为公开线索"
	if _skill_targets_monster(skill) or ["move", "fly", "burrow", "attack", "charge_attack", "roll_attack", "area_damage", "mudslide", "miasma_shot", "miasma_bloom", "miasma_reclaim", "corrosive_breath", "armor_gain", "guard", "roar", "monster_lure", "special_monster_delay", "monster_takeover", "monster_bound_action"].has(kind):
		return "怪兽位置/耐久/状态变化可追踪"
	if ["city_revenue_boost", "city_contract_boon", "city_product_upgrade", "city_product_shift", "city_demand_shift"].has(kind):
		return "城市经营结构和账本会持续变化"
	if kind == "area_trade_contract":
		return "匿名合约会改写区域供需与签拒线索"
	if ["route_flow_boon", "route_insurance", "route_sabotage"].has(kind):
		return "商路速度或断损会影响后续GDP"
	if ["product_speculation", "product_contract_boon", "product_growth_boon", "market_stabilize"].has(kind):
		return "商品天气和供需压力等待重算"
	if kind == "region_economy_shift":
		return "区域生产/交通/消费参数已改写"
	if kind == "panic_shift":
		return "区域热度会偏移怪兽目标"
	if kind == "supply_draw":
		return "补给来源暴露卡牌获取半径"
	if kind == "cash_gain":
		return "资金流向隐藏但节奏可推理"
	return "公开结果留下匿名推理痕迹"


func _card_resolution_effect_position(skill: Dictionary, entry: Dictionary = {}) -> Vector2:
	var target_slot := int(entry.get("target_slot", -1))
	if target_slot >= 0 and target_slot < auto_monsters.size():
		var actor: Dictionary = auto_monsters[target_slot]
		return _entity_world_position(actor)
	if String(skill.get("kind", "")) == "area_trade_contract":
		var target_index := int(entry.get("contract_target_district", -1))
		if target_index >= 0 and target_index < districts.size():
			return _district_center(target_index)
	var district_index := int(entry.get("selected_district", selected_district))
	if district_index >= 0 and district_index < districts.size():
		return _district_center(district_index)
	if not auto_monsters.is_empty():
		return _entity_world_position(auto_monsters[0] as Dictionary)
	return Vector2(map_width_m * 0.5, map_height_m * 0.5)


func _card_resolution_effect_radius(skill: Dictionary) -> float:
	var range_m := float(skill.get("range", 0.0))
	if range_m > 0.0:
		return clampf(range_m, 60.0, 340.0)
	var kind := String(skill.get("kind", ""))
	if kind == "monster_card":
		return 120.0
	if kind.contains("city") or kind == "route_sabotage" or kind == "route_flow_boon" or kind == "route_insurance" or kind == "area_trade_contract":
		return 105.0
	if kind.contains("product") or kind == "market_stabilize":
		return 90.0
	return 75.0


func _card_resolution_effect_style(skill: Dictionary) -> String:
	var kind := String(skill.get("kind", ""))
	if kind == "monster_card":
		return "summon"
	if _skill_targets_monster(skill) or ["move", "fly", "burrow", "attack", "charge_attack", "roll_attack", "area_damage", "mudslide", "miasma_shot", "miasma_bloom", "miasma_reclaim", "corrosive_breath", "armor_gain", "guard", "roar", "monster_lure", "special_monster_delay", "monster_takeover", "monster_bound_action"].has(kind):
		return "monster_command"
	if ["city_revenue_boost", "city_contract_boon", "city_product_upgrade", "city_product_shift", "city_demand_shift", "route_flow_boon", "route_insurance", "route_sabotage", "area_trade_contract"].has(kind):
		return "city"
	if ["product_speculation", "product_contract_boon", "product_growth_boon", "market_stabilize"].has(kind):
		return "product"
	if kind == "region_economy_shift":
		return "region"
	if kind == "panic_shift":
		return "heat"
	if kind == "supply_draw":
		return "supply"
	if kind == "cash_gain":
		return "cash"
	return "generic"


func _card_resolution_effect_style_label(style: String) -> String:
	return String({
		"summon": "召唤",
		"monster_command": "指令",
		"city": "城市",
		"product": "商品",
		"region": "区域",
		"heat": "热度",
		"supply": "补给",
		"cash": "资金",
		"generic": "卡牌",
	}.get(style, "卡牌"))


func _card_resolution_stage_effect_label(stage_label: String, style: String) -> String:
	var style_label := _card_resolution_effect_style_label(style)
	return "%s%s" % [style_label, stage_label]


func _join_first_card_facts(facts: Array, max_count: int) -> String:
	var pieces := []
	for i in range(min(max_count, facts.size())):
		pieces.append(String(facts[i]))
	return "｜".join(pieces)


func _short_card_text(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.left(max(1, max_len - 1)) + "…"


func _add_action_button(parent: Container, text: String, method: String) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = game_over or _has_pending_target_choice() or players[selected_player]["action_cooldown"] > 0.0
	button.pressed.connect(Callable(self, method))
	parent.add_child(button)


func _add_selected_district_card_list(parent: Container, district: Dictionary) -> void:
	var card_choices: Array = district.get("card_choices", [])
	if card_choices.is_empty():
		parent.add_child(_plain_label("区域卡牌选择：暂无候选。", 13, Color("#94a3b8")))
		return
	var header := _plain_label("区域卡牌选择（%s｜单击预览｜hover详情｜双击购买）" % _district_card_access_text(selected_district, selected_player), 13, Color("#fde68a"))
	parent.add_child(header)
	var card_grid := GridContainer.new()
	card_grid.columns = 1
	card_grid.add_theme_constant_override("v_separation", 5)
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card_grid)
	for card_name_variant in card_choices:
		var card_name := String(card_name_variant)
		if not _skill_exists(card_name):
			continue
		_add_district_card_button(card_grid, card_name)
	var preview_name := previewed_district_card if _selected_district_has_card(previewed_district_card) else selected_market_skill
	if not _selected_district_has_card(preview_name):
		preview_name = String(card_choices[0])
		_preview_district_card(preview_name, false)
	if _skill_exists(preview_name):
		var preview_skill := _skill_definition(preview_name)
		var source := _district_card_source(selected_district, preview_name)
		parent.add_child(_plain_label("当前预览：%s｜价格 ¥%d｜来源：%s｜双击区域卡或按 X 购买。" % [
			_card_display_name(preview_name),
			_card_price(preview_name, selected_district, selected_player),
			source,
		], 12, Color("#bae6fd")))
		var center := CenterContainer.new()
		parent.add_child(center)
		_add_card_face(center, preview_name, preview_skill, -1, false, true, false)


func _add_district_card_button(parent: Container, card_name: String) -> void:
	var skill := _skill_definition(card_name)
	if skill.is_empty():
		return
	var button := Button.new()
	var selected := card_name == selected_market_skill
	var upgrade_tag := " [升级]" if _is_upgrade_card(card_name) else ""
	var source := _district_card_source(selected_district, card_name)
	var price := _card_price(card_name, selected_district, selected_player)
	var access_text := _district_card_access_text(selected_district, selected_player)
	var facts := _join_first_card_facts(_card_rule_facts(skill), 3)
	var detail := _short_card_text(_skill_display_text(skill), 42)
	button.text = "%s%s%s｜¥%d｜%s｜%s｜%s｜%s" % [
		"▶ " if selected else "",
		_card_display_name(card_name),
		upgrade_tag,
		price,
		access_text,
		source,
		_skill_tag_text(skill),
		facts if facts != "" else detail,
	]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = game_over or selected_district < 0 or selected_district >= districts.size() or bool(districts[selected_district].get("destroyed", false)) or not _can_buy_card_from_district(selected_district, selected_player) or int(players[selected_player].get("cash", 0)) < price or not _player_can_receive_card(players[selected_player], card_name)
	button.tooltip_text = _card_detail_tooltip(card_name, selected_district)
	button.mouse_entered.connect(Callable(self, "_preview_district_card").bind(card_name, true))
	button.pressed.connect(Callable(self, "_preview_district_card").bind(card_name, true))
	button.gui_input.connect(Callable(self, "_on_district_card_gui_input").bind(card_name))
	parent.add_child(button)


func _preview_district_card(card_name: String, refresh: bool = true) -> void:
	if card_name == "" or not _skill_exists(card_name):
		return
	if selected_district >= 0 and selected_district < districts.size() and not _selected_district_has_card(card_name):
		return
	selected_market_skill = card_name
	previewed_district_card = card_name
	if refresh:
		_refresh_ui()


func _on_district_card_gui_input(event: InputEvent, card_name: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.double_click:
		_preview_district_card(card_name, false)
		_claim_district_card(card_name)


func _district_card_source(district_index: int, card_name: String) -> String:
	if district_index < 0 or district_index >= districts.size():
		return "未知来源"
	var sources: Dictionary = districts[district_index].get("card_sources", {})
	return String(sources.get(card_name, "公共补给"))


func _card_detail_tooltip(card_name: String, district_index: int = -1) -> String:
	if card_name == "" or not _skill_exists(card_name):
		return ""
	var skill: Dictionary = _skill_definition(card_name)
	var key_facts := _card_key_rule_facts(skill)
	var facts_text := "无攻击/生命/范围等数值；按效果文字结算。"
	if not key_facts.is_empty():
		facts_text = "｜".join(key_facts)
	var location := _card_choice_location_summary(card_name)
	var source := _district_card_source(district_index, card_name) if district_index >= 0 else "卡池"
	var price := _card_price(card_name, district_index, selected_player)
	return "%s\n参考价：¥%d（%s，按I级基础价）\n来源：%s\n标签：%s\n效果：%s\n关键数值：%s\n升级：%s\n投放：%s\n操作：单击预览；双击购买；X 购买当前预览卡。" % [
		_card_display_name(card_name),
		price,
		_card_price_tier_text(price),
		source,
		_skill_tag_text(skill),
		_skill_display_text(skill),
		facts_text,
		_card_level_gradient_text(card_name).replace("\n", " / "),
		location,
	]


func _select_player(index: int) -> void:
	if index < 0 or index >= players.size():
		return
	selected_player = index
	_load_selected_district_guess()
	_refresh_ui()


func _select_district(index: int) -> void:
	selected_district = index
	_sync_selected_district_card()
	_load_selected_district_guess()
	_refresh_ui()


func _select_auto_monster_command_target(slot: int) -> void:
	if auto_monsters.is_empty():
		return
	selected_auto_monster_slot = _valid_auto_monster_slot(slot)
	var actor: Dictionary = auto_monsters[selected_auto_monster_slot]
	_log("卡牌一次性指令目标切换为：怪%d·%s。" % [selected_auto_monster_slot + 1, String(actor.get("name", "怪兽"))])
	_refresh_ui()


func _has_pending_target_choice() -> bool:
	return pending_target_player_index >= 0 and pending_target_slot_index >= 0


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


func _begin_target_monster_choice(slot_index: int) -> void:
	if selected_player < 0 or selected_player >= players.size():
		return
	var player: Dictionary = players[selected_player]
	if slot_index < 0 or slot_index >= player["slots"].size():
		return
	var skill = player["slots"][slot_index]
	if skill == null:
		return
	if not _can_play_skill_now(selected_player, skill as Dictionary, true):
		return
	pending_target_player_index = selected_player
	pending_target_slot_index = slot_index
	pending_target_paused_time = false
	_log("匿名打出%s：请选择一个目标怪兽；选定后会进入全局卡牌结算队列。" % _card_display_name(String(skill["name"])))
	_refresh_ui()


func _clear_pending_target_choice(resume_time := true) -> void:
	pending_target_player_index = -1
	pending_target_slot_index = -1
	if resume_time and pending_target_paused_time and not game_over and (menu_overlay == null or not menu_overlay.visible):
		time_scale = max(1.0, speed_before_target_choice)
	pending_target_paused_time = false


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


func _add_pending_target_buttons(parent: Container) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	for i in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[i]
		var button := Button.new()
		button.text = "怪%d %s" % [i + 1, String(actor.get("name", "怪兽"))]
		button.disabled = bool(actor.get("down", false))
		button.pressed.connect(Callable(self, "_choose_pending_target_monster").bind(i))
		row.add_child(button)
	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.pressed.connect(Callable(self, "_cancel_pending_target_choice"))
	row.add_child(cancel_button)


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
	if not _can_play_skill_now(pending_target_player_index, skill as Dictionary, true):
		_clear_pending_target_choice()
		_refresh_ui()
		return
	if slot < 0 or slot >= auto_monsters.size() or bool((auto_monsters[slot] as Dictionary).get("down", false)):
		_log("目标怪兽无效，请重新选择。")
		_refresh_ui()
		return
	if _queue_skill_resolution(pending_target_player_index, pending_target_slot_index, slot):
		_clear_pending_target_choice(true)
	_refresh_ui()


func _resolve_targeted_skill(skill: Dictionary, player: Dictionary, target_slot: int, acting_player_index: int = -1) -> bool:
	var kind := String(skill.get("kind", ""))
	if _is_direct_monster_skill_kind(kind):
		return _trigger_auto_monster_card_command(skill, player, target_slot)
	if kind == "monster_lure":
		var actor: Dictionary = auto_monsters[target_slot]
		selected_auto_monster_slot = target_slot
		next_special_monster_slot = target_slot
		var speedup: float = float(skill.get("lure_speedup", 0.0))
		monster_timer = max(0.2, monster_timer - speedup)
		actor["lure_target_district"] = selected_district
		actor["lure_moves_left"] = 1
		actor["lure_source"] = String(skill.get("name", "怪兽诱导"))
		auto_monsters[target_slot] = actor
		_log("%s匿名诱导怪%d·%s：下一次自动移动优先朝%s推进，并提前%.1fs；诱导结算后失效。" % [
			String(skill["name"]),
			target_slot + 1,
			String(actor.get("name", "怪兽")),
			districts[selected_district]["name"] if selected_district >= 0 and selected_district < districts.size() else "当前选区",
			speedup,
		])
		_add_action_callout(
			"自动怪兽%d·%s" % [target_slot + 1, String(actor.get("name", "怪兽"))],
			"匿名诱导",
			"%s让这只怪兽下一次自动移动优先朝%s推进。" % [
				String(skill["name"]),
				districts[selected_district]["name"] if selected_district >= 0 and selected_district < districts.size() else "当前选区",
			],
			_auto_monster_color(target_slot),
			_entity_world_position(actor)
		)
		return true
	if kind == "special_monster_delay":
		var delayed_actor: Dictionary = auto_monsters[target_slot]
		var delay: float = float(skill.get("delay", 1.0))
		special_monster_timer += delay
		_log("%s干扰怪%d·%s，怪兽特殊行动节奏延后%.1fs。" % [String(skill["name"]), target_slot + 1, String(delayed_actor.get("name", "怪兽")), delay])
		_add_action_callout(
			"自动怪兽%d·%s" % [target_slot + 1, String(delayed_actor.get("name", "怪兽"))],
			"行动干扰",
			"%s使特殊行动延后%.1fs。" % [String(skill["name"]), delay],
			_auto_monster_color(target_slot),
			_entity_world_position(delayed_actor)
		)
		return true
	if kind == "monster_takeover":
		var takeover_player := acting_player_index if acting_player_index >= 0 else pending_target_player_index
		return _apply_monster_takeover(skill, target_slot, takeover_player)
	if kind == "mudslide":
		var mud_actor: Dictionary = auto_monsters[target_slot]
		var range_limit: float = float(skill.get("range", DEFAULT_AOE_RADIUS_METERS))
		if _entity_distance_to_district(mud_actor, selected_district) > range_limit:
			_log("%s目标区域距离怪%d·%s为%s，超过%s。" % [
				String(skill["name"]),
				target_slot + 1,
				String(mud_actor.get("name", "怪兽")),
				_entity_distance_to_district_label(mud_actor, selected_district),
				_meters_text(range_limit),
			])
			return false
		_damage_district(selected_district, int(skill.get("damage", 1)), String(skill["name"]))
		_add_panic(selected_district, int(skill.get("panic", 0)), String(skill["name"]))
		special_monster_timer += float(skill.get("delay", 0.0))
		_log("%s以怪%d·%s为目标触发，%s受影响。" % [String(skill["name"]), target_slot + 1, String(mud_actor.get("name", "怪兽")), districts[selected_district]["name"]])
		return true
	return false


func _cycle_district(step: int) -> void:
	if districts.is_empty():
		return
	selected_district = wrapi(selected_district + step, 0, districts.size())
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
	_save_settings(false)
	_log("下次开局AI对手数设置为：%d个；真人/本地玩家席位%d个。" % [configured_ai_player_count, _configured_human_player_count()])
	_refresh_ui()


func _ensure_configured_roguelike_depth() -> void:
	configured_roguelike_depth = clampi(configured_roguelike_depth, ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX)


func _set_configured_roguelike_depth(depth: int) -> void:
	configured_roguelike_depth = clampi(depth, ROGUELIKE_DEPTH_MIN, ROGUELIKE_DEPTH_MAX)
	_save_settings(false)
	var profile := _roguelike_planet_profile(configured_roguelike_depth)
	_log("下次开局挑战层级设为%s：约%d-%d区，目标现金¥%d。" % [
		_roguelike_depth_label(configured_roguelike_depth),
		int(profile.get("region_min", MAP_REGION_COUNT_MIN)),
		int(profile.get("region_max", MAP_REGION_COUNT_MAX)),
		_roguelike_cash_goal(configured_roguelike_depth),
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


func _ai_player_count() -> int:
	var count := 0
	for i in range(players.size()):
		if _player_is_ai(i):
			count += 1
	return count


func _human_player_count() -> int:
	return max(0, players.size() - _ai_player_count())


func _ai_player_indices() -> Array:
	var result := []
	for i in range(players.size()):
		if _player_is_ai(i):
			result.append(i)
	return result


func _ai_profile_for_config_index(player_index: int) -> Dictionary:
	if AI_PERSONALITY_CATALOG.is_empty():
		return {}
	var human_count := _configured_human_player_count()
	var ai_order: int = maxi(0, player_index - human_count)
	var profile_index := wrapi(ai_order, 0, AI_PERSONALITY_CATALOG.size())
	var profile := (AI_PERSONALITY_CATALOG[profile_index] as Dictionary).duplicate(true)
	profile["profile_index"] = profile_index
	return profile


func _empty_ai_memory() -> Dictionary:
	return {
		"decision_samples": [],
		"action_counts": {},
		"last_plan": "等待牌局决策",
		"economic_focus_product": "",
		"economic_focus_score": 0,
		"economic_focus_reason": "尚未形成商品焦点",
		"economic_focus_cycle": -1,
		"economic_focus_rankings": [],
		"strategic_intent": "",
		"strategic_intent_score": 0,
		"strategic_intent_reason": "尚未形成多周期策略意图",
		"strategic_intent_cycle": -1,
		"strategic_intent_rankings": [],
		"route_plan_product": "",
		"route_plan_stage": "",
		"route_plan_score": 0,
		"route_plan_reason": "尚未形成商品路线计划",
		"route_plan_cycle": -1,
		"route_plan_target_city": -1,
		"route_plan_partner_district": -1,
		"route_plan_rankings": [],
		"game_phase": "opening",
		"competitive_posture": "contesting",
		"score_gap_to_leader": 0,
		"leader_index": -1,
		"phase_reason": "开局：优先首召、建城和购基础牌。",
		"learned_policy_values": {},
		"learning_updates": 0,
		"learning_last_reward": 0,
		"learning_last_tags": [],
		"episode_learning_updates": 0,
		"episode_last_reward": 0,
		"episode_last_final_score": 0,
		"episode_last_rank": -1,
		"episode_last_cash_goal": 0,
		"episode_last_result": "",
		"training_note": "记录状态向量、候选评分、经营周期收益与终局资金，并把金钱结果在线回写到行动/策略/路线偏好。",
	}


func _ensure_player_ai_state() -> void:
	if players.is_empty():
		return
	configured_player_count = clampi(max(configured_player_count, players.size()), MIN_PLAYER_COUNT, MAX_PLAYER_COUNT)
	_ensure_configured_ai_player_count()
	var human_count: int = maxi(1, players.size() - configured_ai_player_count)
	for i in range(players.size()):
		var player: Dictionary = players[i]
		var seat_type := String(player.get("seat_type", "ai" if i >= human_count else "human"))
		var is_ai := seat_type == "ai" or bool(player.get("is_ai", false))
		player["seat_type"] = "ai" if is_ai else "human"
		player["is_ai"] = is_ai
		if is_ai:
			if not (player.get("ai_profile", {}) is Dictionary) or (player.get("ai_profile", {}) as Dictionary).is_empty():
				player["ai_profile"] = _ai_profile_for_config_index(i)
			if not (player.get("ai_memory", {}) is Dictionary):
				player["ai_memory"] = _empty_ai_memory()
			else:
				var memory := (player.get("ai_memory", {}) as Dictionary).duplicate(true)
				if not (memory.get("decision_samples", []) is Array):
					memory["decision_samples"] = []
				if not (memory.get("action_counts", {}) is Dictionary):
					memory["action_counts"] = {}
				if String(memory.get("last_plan", "")) == "":
					memory["last_plan"] = "等待牌局决策"
				if String(memory.get("economic_focus_product", "")) == "":
					memory["economic_focus_product"] = ""
				if not memory.has("economic_focus_score"):
					memory["economic_focus_score"] = 0
				if String(memory.get("economic_focus_reason", "")) == "":
					memory["economic_focus_reason"] = "尚未形成商品焦点"
				if not memory.has("economic_focus_cycle"):
					memory["economic_focus_cycle"] = -1
				if not (memory.get("economic_focus_rankings", []) is Array):
					memory["economic_focus_rankings"] = []
				if String(memory.get("strategic_intent", "")) == "":
					memory["strategic_intent"] = ""
				if not memory.has("strategic_intent_score"):
					memory["strategic_intent_score"] = 0
				if String(memory.get("strategic_intent_reason", "")) == "":
					memory["strategic_intent_reason"] = "尚未形成多周期策略意图"
				if not memory.has("strategic_intent_cycle"):
					memory["strategic_intent_cycle"] = -1
				if not (memory.get("strategic_intent_rankings", []) is Array):
					memory["strategic_intent_rankings"] = []
				if String(memory.get("route_plan_product", "")) == "":
					memory["route_plan_product"] = ""
				if String(memory.get("route_plan_stage", "")) == "":
					memory["route_plan_stage"] = ""
				if not memory.has("route_plan_score"):
					memory["route_plan_score"] = 0
				if String(memory.get("route_plan_reason", "")) == "":
					memory["route_plan_reason"] = "尚未形成商品路线计划"
				if not memory.has("route_plan_cycle"):
					memory["route_plan_cycle"] = -1
				if not memory.has("route_plan_target_city"):
					memory["route_plan_target_city"] = -1
				if not memory.has("route_plan_partner_district"):
					memory["route_plan_partner_district"] = -1
				if not (memory.get("route_plan_rankings", []) is Array):
					memory["route_plan_rankings"] = []
				if String(memory.get("game_phase", "")) == "":
					memory["game_phase"] = "opening"
				if String(memory.get("competitive_posture", "")) == "":
					memory["competitive_posture"] = "contesting"
				if not memory.has("score_gap_to_leader"):
					memory["score_gap_to_leader"] = 0
				if not memory.has("leader_index"):
					memory["leader_index"] = -1
				if String(memory.get("phase_reason", "")) == "":
					memory["phase_reason"] = "开局：优先首召、建城和购基础牌。"
				if not (memory.get("learned_policy_values", {}) is Dictionary):
					memory["learned_policy_values"] = {}
				if not memory.has("learning_updates"):
					memory["learning_updates"] = 0
				if not memory.has("learning_last_reward"):
					memory["learning_last_reward"] = 0
				if not (memory.get("learning_last_tags", []) is Array):
					memory["learning_last_tags"] = []
				if not memory.has("episode_learning_updates"):
					memory["episode_learning_updates"] = 0
				if not memory.has("episode_last_reward"):
					memory["episode_last_reward"] = 0
				if not memory.has("episode_last_final_score"):
					memory["episode_last_final_score"] = 0
				if not memory.has("episode_last_rank"):
					memory["episode_last_rank"] = -1
				if not memory.has("episode_last_cash_goal"):
					memory["episode_last_cash_goal"] = 0
				if not memory.has("episode_last_result"):
					memory["episode_last_result"] = ""
				if String(memory.get("training_note", "")) == "":
					memory["training_note"] = "记录状态向量、候选评分、经营周期收益与终局资金，并把金钱结果在线回写到行动/策略/路线偏好。"
				player["ai_memory"] = memory
		else:
			player["ai_profile"] = {}
			player["ai_memory"] = {}
		players[i] = player


func _ai_owned_active_monster_count(player_index: int) -> int:
	var count := 0
	for actor_variant in auto_monsters:
		var actor: Dictionary = actor_variant
		if not bool(actor.get("down", false)) and int(actor.get("owner", -1)) == player_index:
			count += 1
	return count


func _visible_score_leader_entry() -> Dictionary:
	var best := {"player_index": -1, "score": -999999}
	for i in range(players.size()):
		var score := _player_visible_settlement_estimate(i)
		if score > int(best.get("score", -999999)):
			best = {"player_index": i, "score": score}
	return best


func _ai_score_gap_to_leader(player_index: int) -> int:
	var leader := _visible_score_leader_entry()
	if int(leader.get("player_index", -1)) < 0:
		return 0
	return _player_visible_settlement_estimate(player_index) - int(leader.get("score", 0))


func _ai_game_phase(player_index: int) -> String:
	var score := _player_visible_settlement_estimate(player_index)
	var cash_goal := maxi(1, _roguelike_cash_goal())
	if victory_countdown_active or score >= int(round(float(cash_goal) * AI_ENDGAME_GOAL_RATIO)) or business_cycle_count >= AI_ENDGAME_CYCLE:
		return "endgame"
	if business_cycle_count <= AI_OPENING_CYCLE_MAX or _ai_owned_active_monster_count(player_index) <= 0 or _player_active_city_count(player_index) <= 0:
		return "opening"
	return "midgame"


func _ai_competitive_posture(player_index: int) -> String:
	var leader := _visible_score_leader_entry()
	var leader_index := int(leader.get("player_index", -1))
	var gap := _ai_score_gap_to_leader(player_index)
	if leader_index == player_index and abs(gap) <= AI_LEAD_MARGIN:
		return "leader"
	if leader_index == player_index:
		return "leader"
	if gap <= -AI_TRAILING_MARGIN:
		return "trailing"
	return "contesting"


func _ai_game_phase_reason(player_index: int, phase: String, posture: String, gap: int) -> String:
	match phase:
		"opening":
			return "开局：优先首召、建城和买基础经济牌。"
		"endgame":
			return "后期：%s，距离领先者%s；围绕现金目标冲刺、防守或压制。" % [
				_ai_competitive_posture_label(posture),
				_signed_int_text(gap),
			]
	return "中局：围绕商品路线强化GDP，并开始保护己方收益或攻击竞争城市。"


func _ai_refresh_game_phase(player_index: int, force: bool = false) -> Dictionary:
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return {
			"phase": "human",
			"posture": "human",
			"gap": 0,
			"leader_index": -1,
			"reason": "真人玩家",
		}
	var player: Dictionary = players[player_index]
	var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary).duplicate(true)
	var leader := _visible_score_leader_entry()
	var leader_index := int(leader.get("player_index", -1))
	var gap := _ai_score_gap_to_leader(player_index)
	var phase := _ai_game_phase(player_index)
	var posture := _ai_competitive_posture(player_index)
	if not force and String(memory.get("game_phase", "")) == phase and String(memory.get("competitive_posture", "")) == posture and int(memory.get("score_gap_to_leader", 0)) == gap and int(memory.get("leader_index", -1)) == leader_index:
		return {
			"phase": phase,
			"posture": posture,
			"gap": gap,
			"leader_index": leader_index,
			"reason": String(memory.get("phase_reason", "")),
		}
	var reason := _ai_game_phase_reason(player_index, phase, posture, gap)
	memory["game_phase"] = phase
	memory["competitive_posture"] = posture
	memory["score_gap_to_leader"] = gap
	memory["leader_index"] = leader_index
	memory["phase_reason"] = reason
	player["ai_memory"] = memory
	players[player_index] = player
	return {
		"phase": phase,
		"posture": posture,
		"gap": gap,
		"leader_index": leader_index,
		"reason": reason,
	}


func _ai_game_phase_label(phase: String) -> String:
	match phase:
		"opening":
			return "开局"
		"midgame":
			return "中局"
		"endgame":
			return "后期"
	return "未知阶段"


func _ai_competitive_posture_label(posture: String) -> String:
	match posture:
		"leader":
			return "领先"
		"trailing":
			return "落后"
		"contesting":
			return "争夺中"
	return "未知态势"


func _ai_best_city_for_owner(owner_index: int, prefer_damaged: bool = false) -> int:
	var best_index := -1
	var best_score := -999999
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		if int(city.get("owner", -1)) != owner_index:
			continue
		var score := int(city.get("last_income", 0)) + _city_cycle_income(city_index, _city_competition_matches(city_index))
		score += (city.get("products", []) as Array).size() * 28
		score += (city.get("demands", []) as Array).size() * 18
		score -= int(city.get("trade_route_damage", 0)) * 22
		score -= int(districts[city_index].get("damage", 0)) * 14
		if prefer_damaged:
			score += int(city.get("trade_route_damage", 0)) * 74 + int(districts[city_index].get("damage", 0)) * 36
		if score > best_score:
			best_score = score
			best_index = city_index
	return best_index


func _ai_best_pressure_target_city(player_index: int) -> int:
	var leader := _visible_score_leader_entry()
	var leader_index := int(leader.get("player_index", -1))
	if leader_index >= 0 and leader_index != player_index:
		var leader_city := _ai_best_city_for_owner(leader_index, _ai_competitive_posture(player_index) == "trailing")
		if leader_city >= 0:
			return leader_city
	return _ai_best_city_district(player_index, false)


func _ai_pressure_kind(kind: String, skill: Dictionary = {}) -> bool:
	if ["route_sabotage", "panic_shift", "monster_lure", "mudslide", "area_damage", "special_monster_delay"].has(kind):
		return true
	if kind == "city_gdp_derivative":
		return String(skill.get("gdp_bet_direction", "up")) == "down"
	if kind == "region_economy_shift":
		return int(skill.get("production_delta", 0)) + int(skill.get("transport_delta", 0)) + int(skill.get("consumption_delta", 0)) < 0
	return false


func _ai_defense_kind(kind: String, skill: Dictionary = {}) -> bool:
	if ["route_insurance", "route_flow_boon", "city_revenue_boost", "city_contract_boon", "city_product_upgrade", "city_demand_shift", "market_stabilize"].has(kind):
		return true
	if kind == "city_gdp_derivative":
		return String(skill.get("gdp_bet_direction", "up")) == "up"
	if kind == "region_economy_shift":
		return int(skill.get("production_delta", 0)) + int(skill.get("transport_delta", 0)) + int(skill.get("consumption_delta", 0)) > 0
	return false


func _ai_phase_bonus_for_candidate(player_index: int, kind: String, district_index: int, product_name: String = "", target_owner: int = -999, skill: Dictionary = {}) -> int:
	var phase_info := _ai_refresh_game_phase(player_index)
	var phase := String(phase_info.get("phase", "midgame"))
	var posture := String(phase_info.get("posture", "contesting"))
	var leader_index := int(phase_info.get("leader_index", -1))
	var helpful_target := target_owner == player_index
	var harmful_target := target_owner >= 0 and target_owner != player_index
	var targets_leader := leader_index >= 0 and target_owner == leader_index and leader_index != player_index
	var bonus := 0
	match phase:
		"opening":
			if kind == "monster_card":
				bonus += 420 if _ai_owned_active_monster_count(player_index) <= 0 else 40
			if kind == "city_build":
				bonus += 150 if _player_active_city_count(player_index) <= 0 else 55
			if ["cash_gain", "supply_draw", "card_access_boon"].has(kind):
				bonus += 60
			if _ai_pressure_kind(kind, skill):
				bonus -= 35
		"midgame":
			if _ai_defense_kind(kind, skill) and helpful_target:
				bonus += 55
			if _ai_pressure_kind(kind, skill) and harmful_target:
				bonus += 65
			if product_name != "" and (product_name == _ai_focus_product(player_index) or product_name == _ai_route_plan_product(player_index)):
				bonus += 38
		"endgame":
			if posture == "leader":
				if _ai_defense_kind(kind, skill) and (helpful_target or target_owner == -999):
					bonus += 145
				if ["cash_gain", "market_stabilize"].has(kind):
					bonus += 90
				if _ai_pressure_kind(kind, skill) and harmful_target:
					bonus += 35
			elif posture == "trailing":
				if _ai_pressure_kind(kind, skill) and (targets_leader or harmful_target):
					bonus += 170
				if kind == "city_gdp_derivative" and String(skill.get("gdp_bet_direction", "up")) == "down":
					bonus += 95
				if ["cash_gain", "product_speculation"].has(kind):
					bonus += 70
			else:
				if _ai_defense_kind(kind, skill) and helpful_target:
					bonus += 80
				if _ai_pressure_kind(kind, skill) and (targets_leader or harmful_target):
					bonus += 90
	return bonus


func _ai_observation_vector(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= players.size():
		return {}
	var focus_product := _ai_focus_product(player_index)
	var phase_info := _ai_refresh_game_phase(player_index)
	var player: Dictionary = players[player_index]
	var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary)
	var total_flow := 0
	for product_variant in PRODUCT_CATALOG:
		total_flow += _player_product_flow(player_index, String(product_variant))
	return {
		"cash": int(player.get("cash", 0)),
		"settlement_estimate": _player_visible_settlement_estimate(player_index),
		"counted_hand": _player_counted_hand_size(player),
		"cities": _player_active_city_count(player_index),
		"owned_monsters": _ai_owned_active_monster_count(player_index),
		"field_monsters": _active_auto_monster_count(),
		"total_product_flow": total_flow,
		"focus_product": focus_product,
		"focus_flow": _player_product_flow(player_index, focus_product),
		"focus_score": _ai_focus_score(player_index),
		"strategy_intent": _ai_strategy_intent(player_index),
		"strategy_score": _ai_strategy_score(player_index),
		"route_plan_product": _ai_route_plan_product(player_index),
		"route_plan_stage": _ai_route_plan_stage(player_index),
		"route_plan_score": _ai_route_plan_score(player_index),
		"game_phase": String(phase_info.get("phase", "midgame")),
		"competitive_posture": String(phase_info.get("posture", "contesting")),
		"score_gap_to_leader": int(phase_info.get("gap", 0)),
		"leader_index": int(phase_info.get("leader_index", -1)),
		"learning_updates": int(memory.get("learning_updates", 0)),
		"episode_learning_updates": int(memory.get("episode_learning_updates", 0)),
		"learned_policy_count": (memory.get("learned_policy_values", {}) as Dictionary).size(),
		"cash_goal_gap": maxi(0, _roguelike_cash_goal() - _player_visible_settlement_estimate(player_index)),
		"queue_current": card_resolution_queue.size(),
		"queue_next": next_card_resolution_queue.size(),
		"auction_open": card_resolution_auction_open,
		"cycle": business_cycle_count,
	}


func _ai_candidate_training_view(candidate: Dictionary) -> Dictionary:
	var result := {}
	for field_name in ["action", "card_name", "kind", "policy_kind", "score", "district", "target_slot", "target_city", "target_owner", "product", "price", "bid_budget", "reason", "guessed_player", "resolution_id", "stake", "confidence", "reason_key", "attack_value", "resource_match", "distance_m", "strategic_role", "focus_product", "focus_score", "focus_bonus", "strategy_intent", "strategy_score", "strategy_bonus", "route_plan_product", "route_plan_stage", "route_plan_score", "route_plan_bonus", "game_phase", "competitive_posture", "score_gap_to_leader", "leader_index", "phase_bonus", "generic_effect_bonus", "learning_bonus"]:
		if candidate.has(field_name):
			result[field_name] = candidate[field_name]
	return result


func _sort_ai_candidate_score_desc(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("score", 0)) > int(b.get("score", 0))


func _ai_candidate_training_views(candidates: Array) -> Array:
	var ordered := candidates.duplicate(true)
	ordered.sort_custom(Callable(self, "_sort_ai_candidate_score_desc"))
	var result := []
	for i in range(mini(AI_CANDIDATE_SAMPLE_LIMIT, ordered.size())):
		if ordered[i] is Dictionary:
			result.append(_ai_candidate_training_view(ordered[i] as Dictionary))
	return result


func _ai_learning_tags(action_kind: String = "", policy_kind: String = "", strategy_intent: String = "", route_stage: String = "", product_name: String = "") -> Array:
	var tags := []
	var candidates := [
		"action:%s" % action_kind if action_kind != "" else "",
		"policy:%s" % policy_kind if policy_kind != "" else "",
		"strategy:%s" % strategy_intent if strategy_intent != "" else "",
		"route:%s" % route_stage if route_stage != "" else "",
		"product:%s" % product_name if product_name != "" else "",
	]
	for tag_variant in candidates:
		var tag := String(tag_variant)
		if tag != "" and not tags.has(tag):
			tags.append(tag)
	return tags


func _ai_learning_tags_for_sample(sample: Dictionary) -> Array:
	var tags := _ai_learning_tags(
		String(sample.get("kind", "")),
		String(sample.get("policy_kind", sample.get("strategic_role", ""))),
		String(sample.get("strategy_intent", "")),
		String(sample.get("route_plan_stage", "")),
		String(sample.get("route_plan_product", sample.get("focus_product", "")))
	)
	var direct_product := String(sample.get("product", ""))
	if direct_product != "":
		var product_tag := "product:%s" % direct_product
		if not tags.has(product_tag):
			tags.append(product_tag)
	return tags


func _ai_learning_reward_for_sample(sample: Dictionary) -> int:
	var settlement_reward := int(sample.get("reward_settlement", 0))
	var cash_reward := int(sample.get("reward_cash", 0))
	return clampi(settlement_reward + int(round(float(cash_reward) * 0.25)), -AI_LEARNING_REWARD_CLAMP, AI_LEARNING_REWARD_CLAMP)


func _ai_learning_rate_for_player(player_index: int) -> float:
	var exploration := float(_ai_profile_for_player(player_index).get("exploration", 0.15))
	return clampf(AI_LEARNING_BASE_RATE + exploration * 0.35, 0.18, 0.38)


func _ai_apply_learning_tags(player_index: int, memory: Dictionary, tags: Array, reward_score: int) -> Dictionary:
	if tags.is_empty():
		return memory
	var target_value := clampf(float(reward_score) / 10.0, -AI_LEARNING_VALUE_CLAMP, AI_LEARNING_VALUE_CLAMP)
	var learning_rate := _ai_learning_rate_for_player(player_index)
	var values := (memory.get("learned_policy_values", {}) as Dictionary).duplicate(true)
	for tag_variant in tags:
		var tag := String(tag_variant)
		if tag == "":
			continue
		var entry := (values.get(tag, {}) as Dictionary).duplicate(true)
		var old_value := float(entry.get("value", 0.0))
		entry["value"] = clampf(lerpf(old_value, target_value, learning_rate), -AI_LEARNING_VALUE_CLAMP, AI_LEARNING_VALUE_CLAMP)
		entry["samples"] = int(entry.get("samples", 0)) + 1
		entry["reward_total"] = int(entry.get("reward_total", 0)) + reward_score
		entry["last_reward"] = reward_score
		entry["last_cycle"] = business_cycle_count
		values[tag] = entry
	memory["learned_policy_values"] = values
	memory["learning_updates"] = int(memory.get("learning_updates", 0)) + tags.size()
	memory["learning_last_reward"] = reward_score
	memory["learning_last_tags"] = tags
	return memory


func _ai_apply_learning_sample(player_index: int, memory: Dictionary, sample: Dictionary) -> Dictionary:
	if bool(sample.get("learning_applied", false)):
		return memory
	var reward_score := _ai_learning_reward_for_sample(sample)
	var tags := _ai_learning_tags_for_sample(sample)
	return _ai_apply_learning_tags(player_index, memory, tags, reward_score)


func _ai_learned_tag_bonus(player_index: int, tag: String) -> int:
	if tag == "" or player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return 0
	var memory := ((players[player_index] as Dictionary).get("ai_memory", _empty_ai_memory()) as Dictionary)
	var values := memory.get("learned_policy_values", {}) as Dictionary
	var entry := values.get(tag, {}) as Dictionary
	var sample_count := int(entry.get("samples", 0))
	if sample_count <= 0:
		return 0
	var confidence := float(sample_count) / float(sample_count + 2)
	return int(round(float(entry.get("value", 0.0)) * confidence))


func _ai_learning_bonus(player_index: int, policy_kind: String = "", strategy_intent: String = "", route_stage: String = "", product_name: String = "", action_kind: String = "") -> int:
	var bonus := 0
	for tag_variant in _ai_learning_tags(action_kind, policy_kind, strategy_intent, route_stage, product_name):
		bonus += _ai_learned_tag_bonus(player_index, String(tag_variant))
	return clampi(bonus, -AI_LEARNING_BONUS_CLAMP, AI_LEARNING_BONUS_CLAMP)


func _record_ai_decision(player_index: int, kind: String, target_index: int, score: int, reason: String, candidates: Array = [], metadata: Dictionary = {}) -> void:
	if not _player_is_ai(player_index):
		return
	_ai_refresh_economic_focus(player_index)
	var phase_info := _ai_refresh_game_phase(player_index)
	var observation := _ai_observation_vector(player_index)
	var player: Dictionary = players[player_index]
	var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary).duplicate(true)
	var samples := (memory.get("decision_samples", []) as Array).duplicate(true)
	var focus_product := String(memory.get("economic_focus_product", ""))
	var sample := {
		"time": game_time,
		"cycle": business_cycle_count,
		"kind": kind,
		"target": target_index,
		"score": score,
		"reason": reason,
		"state": observation,
		"candidates": _ai_candidate_training_views(candidates),
		"focus_product": focus_product,
		"focus_score": int(memory.get("economic_focus_score", 0)),
		"focus_reason": String(memory.get("economic_focus_reason", "")),
		"strategy_intent": String(memory.get("strategic_intent", "")),
		"strategy_score": int(memory.get("strategic_intent_score", 0)),
		"strategy_reason": String(memory.get("strategic_intent_reason", "")),
		"route_plan_product": String(memory.get("route_plan_product", "")),
		"route_plan_stage": String(memory.get("route_plan_stage", "")),
		"route_plan_score": int(memory.get("route_plan_score", 0)),
		"route_plan_reason": String(memory.get("route_plan_reason", "")),
		"game_phase": String(phase_info.get("phase", "midgame")),
		"competitive_posture": String(phase_info.get("posture", "contesting")),
		"score_gap_to_leader": int(phase_info.get("gap", 0)),
		"leader_index": int(phase_info.get("leader_index", -1)),
		"phase_reason": String(phase_info.get("reason", "")),
		"baseline_cash": int(player.get("cash", 0)),
		"baseline_settlement": int(observation.get("settlement_estimate", 0)),
		"reward_cash": 0,
		"reward_settlement": 0,
		"reward_score": 0,
		"reward_finalized": false,
		"learning_applied": false,
	}
	for key_variant in metadata.keys():
		sample[key_variant] = metadata[key_variant]
	samples.append(sample)
	while samples.size() > AI_DECISION_SAMPLE_LIMIT:
		samples.pop_front()
	memory["decision_samples"] = samples
	var action_counts := (memory.get("action_counts", {}) as Dictionary).duplicate(true)
	action_counts[kind] = int(action_counts.get(kind, 0)) + 1
	memory["action_counts"] = action_counts
	memory["last_plan"] = "%s｜目标%d｜评分%d｜%s" % [kind, target_index + 1, score, reason]
	player["ai_memory"] = memory
	players[player_index] = player


func _finalize_ai_decision_rewards() -> int:
	var finalized := 0
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		var player: Dictionary = players[player_index]
		var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary).duplicate(true)
		var samples := (memory.get("decision_samples", []) as Array).duplicate(true)
		var changed := false
		for i in range(samples.size()):
			if not (samples[i] is Dictionary):
				continue
			var sample: Dictionary = samples[i]
			if bool(sample.get("reward_finalized", false)) or int(sample.get("cycle", business_cycle_count)) >= business_cycle_count:
				continue
			sample["reward_cash"] = int(player.get("cash", 0)) - int(sample.get("baseline_cash", int(player.get("cash", 0))))
			sample["reward_settlement"] = _player_visible_settlement_estimate(player_index) - int(sample.get("baseline_settlement", 0))
			sample["reward_score"] = _ai_learning_reward_for_sample(sample)
			sample["reward_finalized"] = true
			sample["reward_cycle"] = business_cycle_count
			memory = _ai_apply_learning_sample(player_index, memory, sample)
			sample["learning_tags"] = _ai_learning_tags_for_sample(sample)
			sample["learning_applied"] = true
			samples[i] = sample
			finalized += 1
			changed = true
		if changed:
			memory["decision_samples"] = samples
			player["ai_memory"] = memory
			players[player_index] = player
	return finalized


func _sort_final_score_rank_desc(a: Dictionary, b: Dictionary) -> bool:
	var a_score := int(a.get("score", 0))
	var b_score := int(b.get("score", 0))
	if a_score == b_score:
		return int(a.get("player_index", 0)) < int(b.get("player_index", 0))
	return a_score > b_score


func _final_score_rankings() -> Array:
	var rankings := []
	for i in range(players.size()):
		rankings.append({
			"player_index": i,
			"score": _player_final_score(i),
		})
	rankings.sort_custom(Callable(self, "_sort_final_score_rank_desc"))
	return rankings


func _final_score_rank_for_player(rankings: Array, player_index: int) -> int:
	for i in range(rankings.size()):
		var entry := rankings[i] as Dictionary
		if int(entry.get("player_index", -1)) == player_index:
			return i
	return rankings.size()


func _ai_episode_reward_for_player(player_index: int, rankings: Array, cash_goal: int) -> Dictionary:
	var final_score := _player_final_score(player_index)
	var rank := _final_score_rank_for_player(rankings, player_index)
	var winner_score := final_score
	var winner_index := player_index
	if not rankings.is_empty():
		var winner := rankings[0] as Dictionary
		winner_score = int(winner.get("score", final_score))
		winner_index = int(winner.get("player_index", player_index))
	var score_vs_goal := final_score - cash_goal
	var reward := clampi(int(round(float(score_vs_goal) / 6.0)), -680, 680)
	if final_score >= cash_goal:
		reward += AI_EPISODE_GOAL_BONUS
	else:
		reward -= int(round(float(cash_goal - final_score) / 14.0))
	if player_index == winner_index:
		reward += AI_EPISODE_WIN_BONUS
	else:
		reward -= 95 * maxi(1, rank)
		reward += clampi(int(round(float(final_score - winner_score) / 10.0)), -360, 0)
	var seat_span := maxi(1, players.size() - 1)
	reward += int(round((float(seat_span - rank) / float(seat_span)) * 220.0)) - 90
	var result_label := "胜利" if player_index == winner_index else ("达标" if final_score >= cash_goal else "未达标")
	return {
		"reward": clampi(reward, -AI_EPISODE_REWARD_CLAMP, AI_EPISODE_REWARD_CLAMP),
		"final_score": final_score,
		"rank": rank,
		"winner_index": winner_index,
		"winner_score": winner_score,
		"cash_goal": cash_goal,
		"result": result_label,
	}


func _ai_episode_sample_reward(base_reward: int, sample: Dictionary) -> int:
	var sample_cycle := int(sample.get("cycle", business_cycle_count))
	var age := maxi(0, business_cycle_count - sample_cycle)
	var decayed := int(round(float(base_reward) * pow(AI_EPISODE_SAMPLE_DECAY, float(age))))
	return clampi(decayed, -AI_EPISODE_REWARD_CLAMP, AI_EPISODE_REWARD_CLAMP)


func _finalize_ai_episode_rewards(reason: String = "") -> int:
	if players.is_empty():
		return 0
	var rankings := _final_score_rankings()
	var cash_goal := _roguelike_cash_goal()
	var updated := 0
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		var player: Dictionary = players[player_index]
		var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary).duplicate(true)
		var samples := (memory.get("decision_samples", []) as Array).duplicate(true)
		var episode := _ai_episode_reward_for_player(player_index, rankings, cash_goal)
		var base_reward := int(episode.get("reward", 0))
		var sample_updates := 0
		for i in range(samples.size()):
			if not (samples[i] is Dictionary):
				continue
			var sample: Dictionary = samples[i]
			if bool(sample.get("episode_reward_finalized", false)):
				continue
			var sample_reward := _ai_episode_sample_reward(base_reward, sample)
			sample["episode_reward_score"] = sample_reward
			sample["episode_base_reward"] = base_reward
			sample["episode_final_score"] = int(episode.get("final_score", 0))
			sample["episode_rank"] = int(episode.get("rank", -1))
			sample["episode_cash_goal"] = cash_goal
			sample["episode_result"] = String(episode.get("result", ""))
			sample["episode_reason"] = reason
			sample["episode_reward_cycle"] = business_cycle_count
			sample["episode_reward_finalized"] = true
			var episode_tags := _ai_learning_tags_for_sample(sample)
			sample["episode_learning_tags"] = episode_tags
			memory = _ai_apply_learning_tags(player_index, memory, episode_tags, sample_reward)
			sample["episode_learning_applied"] = true
			samples[i] = sample
			sample_updates += 1
		if sample_updates <= 0:
			continue
		memory["decision_samples"] = samples
		memory["episode_learning_updates"] = int(memory.get("episode_learning_updates", 0)) + sample_updates
		memory["episode_last_reward"] = base_reward
		memory["episode_last_final_score"] = int(episode.get("final_score", 0))
		memory["episode_last_rank"] = int(episode.get("rank", -1))
		memory["episode_last_cash_goal"] = cash_goal
		memory["episode_last_result"] = String(episode.get("result", ""))
		player["ai_memory"] = memory
		players[player_index] = player
		updated += sample_updates
	return updated


func _ai_profile_for_player(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= players.size():
		return {}
	var profile_variant: Variant = (players[player_index] as Dictionary).get("ai_profile", {})
	return profile_variant as Dictionary if profile_variant is Dictionary else {}


func _ai_product_rival_city_count(player_index: int, product_name: String) -> int:
	var count := 0
	if product_name == "":
		return count
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		if int(city.get("owner", -1)) == player_index:
			continue
		if _city_product_names(city).has(product_name) or _city_demand_names(city).has(product_name):
			count += 1
	return count


func _ai_product_market_signal_score(product_name: String) -> int:
	if product_name == "":
		return 0
	_ensure_product_market_catalog()
	var entry: Dictionary = product_market.get(product_name, {})
	if entry.is_empty():
		return _product_price(product_name) / 3
	var price := int(entry.get("price", entry.get("base_price", _product_price(product_name))))
	var base_price := int(entry.get("base_price", price))
	var demand := int(entry.get("demand", 0))
	var supply := int(entry.get("supply", 0))
	var temporary_demand := int(entry.get("temporary_demand_pressure", 0))
	var temporary_supply := int(entry.get("temporary_supply_pressure", 0))
	var contract_demand := int(entry.get("market_contract_demand", 0))
	var contract_supply := int(entry.get("market_contract_supply", 0))
	var score := int(round(float(price) / 3.0))
	score += max(0, price - base_price) / 2
	score += demand * 9
	score -= supply * 4
	score += temporary_demand * 12
	score -= temporary_supply * 5
	score += contract_demand * 14
	score -= contract_supply * 5
	score += int(round((float(entry.get("growth_multiplier", 1.0)) - 1.0) * 50.0))
	score += int(round((float(entry.get("route_flow_multiplier", 1.0)) - 1.0) * 42.0))
	return score


func _ai_product_city_exposure_score(player_index: int, product_name: String) -> int:
	if product_name == "":
		return 0
	var score := _player_product_flow(player_index, product_name) * 74
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		var owner := int(city.get("owner", -1))
		var product_match := _city_product_names(city).has(product_name)
		var demand_match := _city_demand_names(city).has(product_name)
		if owner == player_index:
			if product_match:
				score += 72 + int(city.get("last_income", 0)) / 4
			if demand_match:
				score += 46
			for route_variant in city.get("trade_routes", []):
				var route: Dictionary = route_variant
				if String(route.get("product", "")) == product_name and not bool(route.get("disrupted", false)):
					score += 34
		elif product_match or demand_match:
			score += 26
			if product_match and _player_product_flow(player_index, product_name) > 0:
				score += 44
	return score


func _ai_product_focus_score(player_index: int, product_name: String) -> int:
	if product_name == "" or not PRODUCT_CATALOG.has(product_name):
		return -999
	var score := _ai_product_market_signal_score(product_name)
	score += _ai_product_city_exposure_score(player_index, product_name)
	var role := _player_role_card_for_index(player_index)
	if String(role.get("resource_cash_product", "")) == product_name:
		score += 155 + int(role.get("resource_cash_amount", 0))
	if String(role.get("bonus_card_product", "")) == product_name:
		score += 120
	var rival_count := _ai_product_rival_city_count(player_index, product_name)
	score += rival_count * (32 + (_player_product_flow(player_index, product_name) * 8))
	var cash_gap := maxi(0, _roguelike_cash_goal() - _player_visible_settlement_estimate(player_index))
	if cash_gap > 0:
		score += int(round(float(cash_gap) / 900.0)) * (8 + int(round(float(_product_price(product_name)) / 35.0)))
	if _player_product_flow(player_index, product_name) <= 0 and String(role.get("resource_cash_product", "")) != product_name and String(role.get("bonus_card_product", "")) != product_name:
		score -= 45
	return score


func _sort_ai_focus_score_desc(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("score", 0)) > int(b.get("score", 0))


func _ai_focus_reason(player_index: int, product_name: String, score: int) -> String:
	if product_name == "":
		return "尚未形成商品焦点"
	var cash_gap := maxi(0, _roguelike_cash_goal() - _player_visible_settlement_estimate(player_index))
	return "%s｜流动%d｜市价¥%d｜竞品城%d｜通关缺口¥%d｜评分%d" % [
		product_name,
		_player_product_flow(player_index, product_name),
		_product_price(product_name),
		_ai_product_rival_city_count(player_index, product_name),
		cash_gap,
		score,
	]


func _ai_refresh_economic_focus(player_index: int, force: bool = false) -> String:
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return ""
	var player: Dictionary = players[player_index]
	var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary).duplicate(true)
	var cached_product := String(memory.get("economic_focus_product", ""))
	if not force and int(memory.get("economic_focus_cycle", -1)) == business_cycle_count and cached_product != "" and PRODUCT_CATALOG.has(cached_product):
		return cached_product
	var rankings := []
	for product_variant in PRODUCT_CATALOG:
		var product_name := String(product_variant)
		if product_name == "":
			continue
		rankings.append({
			"product": product_name,
			"score": _ai_product_focus_score(player_index, product_name),
			"flow": _player_product_flow(player_index, product_name),
			"price": _product_price(product_name),
			"rivals": _ai_product_rival_city_count(player_index, product_name),
		})
	if rankings.is_empty():
		return ""
	rankings.sort_custom(Callable(self, "_sort_ai_focus_score_desc"))
	var best := rankings[0] as Dictionary
	var best_product := String(best.get("product", ""))
	var best_score := int(best.get("score", 0))
	var compact_rankings := []
	for i in range(mini(AI_ECONOMIC_FOCUS_TOP_LIMIT, rankings.size())):
		compact_rankings.append(rankings[i])
	memory["economic_focus_product"] = best_product
	memory["economic_focus_score"] = best_score
	memory["economic_focus_reason"] = _ai_focus_reason(player_index, best_product, best_score)
	memory["economic_focus_cycle"] = business_cycle_count
	memory["economic_focus_rankings"] = compact_rankings
	player["ai_memory"] = memory
	players[player_index] = player
	return best_product


func _ai_focus_product(player_index: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return ""
	if not _player_is_ai(player_index):
		return _first_player_flow_product(player_index)
	return _ai_refresh_economic_focus(player_index)


func _ai_focus_score(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return 0
	_ai_refresh_economic_focus(player_index)
	var memory := ((players[player_index] as Dictionary).get("ai_memory", _empty_ai_memory()) as Dictionary)
	return int(memory.get("economic_focus_score", 0))


func _ai_own_route_threat_score(player_index: int) -> int:
	var score := 0
	for city_index_variant in _active_city_indices_for_player(player_index):
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		score += int(city.get("trade_route_damage", 0)) * 84
		score += int(city.get("trade_disrupted_routes", 0)) * 46
		score += int(districts[city_index].get("damage", 0)) * 18
		score += int(districts[city_index].get("panic", 0)) / 3
		for actor_variant in auto_monsters:
			var actor: Dictionary = actor_variant
			if bool(actor.get("down", false)):
				continue
			var distance := _entity_distance_to_district(actor, city_index)
			if distance <= AUTO_MONSTER_ENCOUNTER_RANGE_METERS:
				score += 68
			elif distance <= NEARBY_RADIUS_METERS:
				score += 44
			elif distance <= NEARBY_RADIUS_METERS * 1.6:
				score += 22
			score += _monster_resource_match_score(actor, city_index) * 18
	return score


func _ai_focus_rival_pressure_score(player_index: int) -> int:
	var focus := _ai_focus_product(player_index)
	if focus == "":
		return 0
	var score := 0
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		if int(city.get("owner", -1)) == player_index:
			continue
		var product_match := _city_product_names(city).has(focus)
		var demand_match := _city_demand_names(city).has(focus)
		if not product_match and not demand_match:
			continue
		score += _ai_rival_city_pressure_score(player_index, city_index)
		if product_match:
			score += 58 + _player_product_flow(player_index, focus) * 14
		if demand_match:
			score += 24
	return score


func _ai_growth_need_score(player_index: int) -> int:
	var focus := _ai_focus_product(player_index)
	var cash_gap := maxi(0, _roguelike_cash_goal() - _player_visible_settlement_estimate(player_index))
	var score := 58 + cash_gap / 22
	score += maxi(0, 2 - _player_active_city_count(player_index)) * 115
	if focus != "":
		score += maxi(0, 3 - _player_product_flow(player_index, focus)) * 64
		score += _ai_focus_score(player_index) / 5
	return score


func _ai_strategy_candidates(player_index: int) -> Array:
	var focus := _ai_focus_product(player_index)
	var phase_info := _ai_refresh_game_phase(player_index)
	var phase := String(phase_info.get("phase", "midgame"))
	var posture := String(phase_info.get("posture", "contesting"))
	var phase_label := _ai_game_phase_label(phase)
	var posture_label := _ai_competitive_posture_label(posture)
	var cash_gap := maxi(0, _roguelike_cash_goal() - _player_visible_settlement_estimate(player_index))
	var route_threat := _ai_own_route_threat_score(player_index)
	var rival_pressure := _ai_focus_rival_pressure_score(player_index)
	var growth_need := _ai_growth_need_score(player_index)
	var defend_learning := _ai_learning_bonus(player_index, "", "defend_routes", "", focus, "战略选择")
	var disrupt_learning := _ai_learning_bonus(player_index, "", "disrupt_competitors", "", focus, "战略选择")
	var grow_learning := _ai_learning_bonus(player_index, "", "grow_focus", "", focus, "战略选择")
	var defend_phase_bonus := 0
	var disrupt_phase_bonus := 0
	var grow_phase_bonus := 0
	match phase:
		"opening":
			grow_phase_bonus += 150
			defend_phase_bonus += 20
			disrupt_phase_bonus -= 35
		"midgame":
			grow_phase_bonus += 45
			defend_phase_bonus += mini(80, route_threat / 3)
			disrupt_phase_bonus += mini(90, rival_pressure / 3)
		"endgame":
			if posture == "leader":
				defend_phase_bonus += 170
				grow_phase_bonus += 45
				disrupt_phase_bonus += 20
			elif posture == "trailing":
				disrupt_phase_bonus += 185
				grow_phase_bonus += 75
				defend_phase_bonus += route_threat / 2
			else:
				disrupt_phase_bonus += 90
				defend_phase_bonus += 80
				grow_phase_bonus += 50
	return [
		{
			"intent": "defend_routes",
			"score": 42 + route_threat + route_threat / 2 + int(round(float(cash_gap) / 80.0)) + defend_phase_bonus + defend_learning,
			"game_phase": phase,
			"competitive_posture": posture,
			"phase_bonus": defend_phase_bonus,
			"learning_bonus": defend_learning,
			"reason": "保卫商路｜%s/%s｜威胁%d｜通关缺口¥%d｜阶段%d｜学习%d" % [phase_label, posture_label, route_threat, cash_gap, defend_phase_bonus, defend_learning],
		},
		{
			"intent": "disrupt_competitors",
			"score": 54 + rival_pressure + _player_product_flow(player_index, focus) * 18 + disrupt_phase_bonus + disrupt_learning,
			"game_phase": phase,
			"competitive_posture": posture,
			"phase_bonus": disrupt_phase_bonus,
			"learning_bonus": disrupt_learning,
			"reason": "压制竞品｜%s/%s｜焦点%s｜竞品压力%d｜阶段%d｜学习%d" % [phase_label, posture_label, focus if focus != "" else "未定", rival_pressure, disrupt_phase_bonus, disrupt_learning],
		},
		{
			"intent": "grow_focus",
			"score": growth_need + grow_phase_bonus + grow_learning,
			"game_phase": phase,
			"competitive_posture": posture,
			"phase_bonus": grow_phase_bonus,
			"learning_bonus": grow_learning,
			"reason": "扩张焦点｜%s/%s｜焦点%s｜成长需求%d｜阶段%d｜学习%d" % [phase_label, posture_label, focus if focus != "" else "未定", growth_need, grow_phase_bonus, grow_learning],
		},
	]


func _ai_refresh_strategy_intent(player_index: int, force: bool = false) -> Dictionary:
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return {}
	_ai_refresh_economic_focus(player_index, force)
	var player: Dictionary = players[player_index]
	var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary).duplicate(true)
	var cached_intent := String(memory.get("strategic_intent", ""))
	if not force and int(memory.get("strategic_intent_cycle", -1)) == business_cycle_count and cached_intent != "":
		return {
			"intent": cached_intent,
			"score": int(memory.get("strategic_intent_score", 0)),
			"reason": String(memory.get("strategic_intent_reason", "")),
		}
	var rankings := _ai_strategy_candidates(player_index)
	if rankings.is_empty():
		return {}
	rankings.sort_custom(Callable(self, "_sort_ai_candidate_score_desc"))
	var best := rankings[0] as Dictionary
	var compact_rankings := []
	for i in range(mini(AI_STRATEGY_TOP_LIMIT, rankings.size())):
		compact_rankings.append(rankings[i])
	memory["strategic_intent"] = String(best.get("intent", "grow_focus"))
	memory["strategic_intent_score"] = int(best.get("score", 0))
	memory["strategic_intent_reason"] = String(best.get("reason", ""))
	memory["strategic_intent_cycle"] = business_cycle_count
	memory["strategic_intent_rankings"] = compact_rankings
	player["ai_memory"] = memory
	players[player_index] = player
	return best


func _ai_strategy_intent(player_index: int) -> String:
	var strategy := _ai_refresh_strategy_intent(player_index)
	return String(strategy.get("intent", ""))


func _ai_strategy_score(player_index: int) -> int:
	var strategy := _ai_refresh_strategy_intent(player_index)
	return int(strategy.get("score", 0))


func _ai_strategy_bonus_for_candidate(player_index: int, kind: String, district_index: int, product_name: String = "", target_owner: int = -999) -> int:
	var strategy := _ai_refresh_strategy_intent(player_index)
	var intent := String(strategy.get("intent", ""))
	if intent == "":
		return 0
	var focus := _ai_focus_product(player_index)
	var resolved_owner := target_owner
	if resolved_owner == -999 and district_index >= 0 and district_index < districts.size():
		var city := _district_city(district_index)
		if _city_is_active(city):
			resolved_owner = int(city.get("owner", -1))
	var bonus := 0
	match intent:
		"defend_routes":
			if ["route_insurance", "special_monster_delay", "route_flow_boon", "region_economy_shift"].has(kind):
				bonus += AI_STRATEGY_MATCH_BONUS
			if resolved_owner == player_index:
				bonus += mini(120, _ai_own_route_threat_score(player_index) / 3)
		"disrupt_competitors":
			if ["route_sabotage", "panic_shift", "monster_lure", "mudslide", "area_damage", "city_gdp_derivative"].has(kind):
				bonus += AI_STRATEGY_MATCH_BONUS
			if resolved_owner >= 0 and resolved_owner != player_index:
				bonus += 70
			if focus != "" and product_name == focus:
				bonus += 46
		"grow_focus":
			if ["city_build", "city_revenue_boost", "city_product_upgrade", "city_product_shift", "city_demand_shift", "city_contract_boon", "route_flow_boon", "product_speculation", "city_gdp_derivative", "product_contract_boon", "product_growth_boon", "cash_gain", "area_trade_contract", "region_economy_shift"].has(kind):
				bonus += AI_STRATEGY_MATCH_BONUS
			if focus != "" and product_name == focus:
				bonus += 54
			if district_index >= 0:
				bonus += mini(90, _ai_district_focus_score(player_index, district_index) / 2)
	return max(0, bonus)


func _ai_owned_city_product_count(player_index: int, product_name: String, demand_side: bool = false) -> int:
	if product_name == "":
		return 0
	var count := 0
	for city_index_variant in _active_city_indices_for_player(player_index):
		var city := _district_city(int(city_index_variant))
		if demand_side:
			if _city_demand_names(city).has(product_name):
				count += 1
		elif _city_product_names(city).has(product_name):
			count += 1
	return count


func _ai_city_touches_product(city: Dictionary, product_name: String) -> bool:
	if product_name == "":
		return false
	return _city_product_names(city).has(product_name) or _city_demand_names(city).has(product_name)


func _ai_district_touches_product(district_index: int, product_name: String) -> bool:
	if product_name == "" or district_index < 0 or district_index >= districts.size():
		return false
	var district: Dictionary = districts[district_index]
	if (district.get("products", []) as Array).has(product_name) or (district.get("demands", []) as Array).has(product_name):
		return true
	var city := _district_city(district_index)
	return _city_is_active(city) and _ai_city_touches_product(city, product_name)


func _ai_product_route_threat_score(player_index: int, product_name: String) -> int:
	if product_name == "":
		return 0
	var score := 0
	for city_index_variant in _active_city_indices_for_player(player_index):
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		var related := _ai_city_touches_product(city, product_name)
		for route_variant in city.get("trade_routes", []):
			var route: Dictionary = route_variant
			if String(route.get("product", "")) == product_name:
				related = true
				if bool(route.get("disrupted", false)):
					score += 58
		if not related:
			continue
		score += int(city.get("trade_route_damage", 0)) * 92
		score += int(city.get("trade_disrupted_routes", 0)) * 54
		score += int(districts[city_index].get("damage", 0)) * 18
		score += int(districts[city_index].get("panic", 0)) / 4
	return score


func _ai_best_seed_district_for_product(player_index: int, product_name: String) -> int:
	if product_name == "":
		return -1
	var best_index := -1
	var best_score := -1
	for i in range(districts.size()):
		if _city_build_error_for(player_index, i, false) != "":
			continue
		var district: Dictionary = districts[i]
		var score := 24 + int(round(float(_product_price(product_name)) / 7.0))
		if (district.get("products", []) as Array).has(product_name):
			score += 180
		if (district.get("demands", []) as Array).has(product_name):
			score += 72
		score += _district_ocean_neighbor_count(i) * 16
		score += _district_trade_route_load(i) * 8
		score += int(round(float(district.get("transport_score", 1.0)) * 18.0))
		score += maxi(0, int(district.get("hp", 0)) - int(district.get("damage", 0)))
		score -= int(district.get("damage", 0)) * 8
		score -= _auto_build_monster_risk_score(i) / 2
		if score > best_score:
			best_score = score
			best_index = i
	return best_index


func _ai_best_owned_route_city_for_product(player_index: int, product_name: String, prefer_damaged: bool = false) -> int:
	var best_index := -1
	var best_score := -1
	for city_index_variant in _active_city_indices_for_player(player_index):
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		var score := 20 + _ai_city_target_score(player_index, city_index, true, prefer_damaged)
		if _city_product_names(city).has(product_name):
			score += 120
		if _city_demand_names(city).has(product_name):
			score += 82
		for route_variant in city.get("trade_routes", []):
			var route: Dictionary = route_variant
			if String(route.get("product", "")) == product_name:
				score += 48
				if bool(route.get("disrupted", false)):
					score += 66
		if score > best_score:
			best_score = score
			best_index = city_index
	return best_index


func _ai_best_rival_route_city_for_product(player_index: int, product_name: String) -> Dictionary:
	var best := {"index": -1, "score": 0}
	if product_name == "":
		return best
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		if int(city.get("owner", -1)) == player_index:
			continue
		if not _ai_city_touches_product(city, product_name):
			continue
		var score := _ai_rival_city_pressure_score(player_index, city_index)
		if _city_product_names(city).has(product_name):
			score += 80
		if _city_demand_names(city).has(product_name):
			score += 34
		if score > int(best.get("score", 0)):
			best["index"] = city_index
			best["score"] = score
	return best


func _ai_route_plan_stage_label(stage: String) -> String:
	match stage:
		"build_supply":
			return "补供给城市"
		"create_demand":
			return "制造需求"
		"strengthen_route":
			return "强化商路"
		"defend_route":
			return "保护路线"
		"attack_rival":
			return "打击竞品"
	return "观察路线"


func _ai_strategy_intent_label(intent: String) -> String:
	match intent:
		"grow_focus":
			return "扩张GDP"
		"defend_routes":
			return "保护商路"
		"disrupt_competitors":
			return "压制竞品"
	return "观察局势"


func _ai_route_plan_candidates(player_index: int) -> Array:
	var result := []
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return result
	_ensure_product_market_catalog()
	var focus := _ai_focus_product(player_index)
	var strategy := _ai_strategy_intent(player_index)
	var cash_gap := maxi(0, _roguelike_cash_goal() - _player_visible_settlement_estimate(player_index))
	for product_variant in PRODUCT_CATALOG:
		var product_name := String(product_variant)
		if product_name == "":
			continue
		var flow := _player_product_flow(player_index, product_name)
		var supply_count := _ai_owned_city_product_count(player_index, product_name, false)
		var demand_count := _ai_owned_city_product_count(player_index, product_name, true)
		var route_threat := _ai_product_route_threat_score(player_index, product_name)
		var rival := _ai_best_rival_route_city_for_product(player_index, product_name)
		var rival_pressure := int(rival.get("score", 0))
		var seed_district := _ai_best_seed_district_for_product(player_index, product_name)
		var stage := "strengthen_route"
		if supply_count <= 0:
			stage = "build_supply"
		elif demand_count <= 0:
			stage = "create_demand"
		elif flow <= 0:
			stage = "strengthen_route"
		elif route_threat >= 170 or strategy == "defend_routes":
			stage = "defend_route"
		elif rival_pressure >= 260 or strategy == "disrupt_competitors":
			stage = "attack_rival"
		var target_city := _ai_best_owned_route_city_for_product(player_index, product_name, stage == "defend_route")
		var score := 70 + _ai_product_market_signal_score(product_name) / 2 + int(round(float(_product_price(product_name)) / 8.0))
		score += flow * 46 + supply_count * 34 + demand_count * 28
		score += int(round(float(cash_gap) / 95.0))
		if product_name == focus:
			score += AI_ROUTE_PLAN_MATCH_BONUS + _ai_focus_score(player_index) / 4
		match stage:
			"build_supply":
				score += 150 + maxi(0, 2 - supply_count) * 70
				if seed_district >= 0:
					score += 85
					if _ai_district_touches_product(seed_district, product_name):
						score += 70
			"create_demand":
				score += 132 + maxi(0, 2 - demand_count) * 56
			"defend_route":
				score += 112 + route_threat
			"attack_rival":
				score += 92 + rival_pressure
			_:
				score += 118 + flow * 24
		var learning_bonus := _ai_learning_bonus(player_index, "", strategy, stage, product_name, "路线规划")
		score += learning_bonus
		result.append({
			"product": product_name,
			"stage": stage,
			"score": maxi(1, score),
			"learning_bonus": learning_bonus,
			"flow": flow,
			"supply_cities": supply_count,
			"demand_cities": demand_count,
			"route_threat": route_threat,
			"rival_pressure": rival_pressure,
			"target_city": target_city,
			"rival_city": int(rival.get("index", -1)),
			"partner_district": seed_district,
			"reason": "%s｜%s｜流动%d｜供给城%d｜需求城%d｜威胁%d｜竞品%d｜学习%d" % [
				product_name,
				_ai_route_plan_stage_label(stage),
				flow,
				supply_count,
				demand_count,
				route_threat,
				rival_pressure,
				learning_bonus,
			],
		})
	return result


func _ai_refresh_route_plan(player_index: int, force: bool = false) -> Dictionary:
	if player_index < 0 or player_index >= players.size() or not _player_is_ai(player_index):
		return {}
	_ai_refresh_economic_focus(player_index, force)
	var player: Dictionary = players[player_index]
	var memory := (player.get("ai_memory", _empty_ai_memory()) as Dictionary).duplicate(true)
	var cached_product := String(memory.get("route_plan_product", ""))
	var cached_stage := String(memory.get("route_plan_stage", ""))
	if not force and int(memory.get("route_plan_cycle", -1)) == business_cycle_count and cached_product != "" and cached_stage != "":
		return {
			"product": cached_product,
			"stage": cached_stage,
			"score": int(memory.get("route_plan_score", 0)),
			"reason": String(memory.get("route_plan_reason", "")),
			"target_city": int(memory.get("route_plan_target_city", -1)),
			"partner_district": int(memory.get("route_plan_partner_district", -1)),
		}
	var rankings := _ai_route_plan_candidates(player_index)
	if rankings.is_empty():
		return {}
	rankings.sort_custom(Callable(self, "_sort_ai_candidate_score_desc"))
	var best := rankings[0] as Dictionary
	if cached_product != "" and cached_product != String(best.get("product", "")):
		for candidate_variant in rankings:
			var incumbent := candidate_variant as Dictionary
			if String(incumbent.get("product", "")) != cached_product:
				continue
			var made_progress := false
			for previous_variant in memory.get("route_plan_rankings", []):
				var previous := previous_variant as Dictionary
				if String(previous.get("product", "")) != cached_product:
					continue
				made_progress = (
					int(incumbent.get("flow", 0)) > int(previous.get("flow", 0))
					or int(incumbent.get("supply_cities", 0)) > int(previous.get("supply_cities", 0))
					or int(incumbent.get("demand_cities", 0)) > int(previous.get("demand_cities", 0))
				)
				break
			var switch_margin := AI_ROUTE_PLAN_SWITCH_MARGIN
			if int(incumbent.get("flow", 0)) > 0 or int(incumbent.get("supply_cities", 0)) > 0 or int(incumbent.get("demand_cities", 0)) > 0:
				switch_margin = AI_ROUTE_PLAN_ENTRENCHED_SWITCH_MARGIN
			if made_progress or int(incumbent.get("score", 0)) + switch_margin >= int(best.get("score", 0)):
				best = incumbent.duplicate(true)
				if made_progress:
					best["reason"] = "%s｜既有路线刚取得进展，继续推进" % String(best.get("reason", ""))
				else:
					best["reason"] = "%s｜延续既有路线，切换门槛%d" % [
						String(best.get("reason", "")),
						switch_margin,
					]
			break
	var compact_rankings := []
	for i in range(mini(AI_ROUTE_PLAN_TOP_LIMIT, rankings.size())):
		compact_rankings.append(rankings[i])
	memory["route_plan_product"] = String(best.get("product", ""))
	memory["route_plan_stage"] = String(best.get("stage", ""))
	memory["route_plan_score"] = int(best.get("score", 0))
	memory["route_plan_reason"] = String(best.get("reason", ""))
	memory["route_plan_cycle"] = business_cycle_count
	memory["route_plan_target_city"] = int(best.get("target_city", -1))
	memory["route_plan_partner_district"] = int(best.get("partner_district", -1))
	memory["route_plan_rankings"] = compact_rankings
	player["ai_memory"] = memory
	players[player_index] = player
	return best


func _ai_route_plan_product(player_index: int) -> String:
	var plan := _ai_refresh_route_plan(player_index)
	return String(plan.get("product", ""))


func _ai_route_plan_stage(player_index: int) -> String:
	var plan := _ai_refresh_route_plan(player_index)
	return String(plan.get("stage", ""))


func _ai_route_plan_score(player_index: int) -> int:
	var plan := _ai_refresh_route_plan(player_index)
	return int(plan.get("score", 0))


func _ai_route_plan_bonus_for_candidate(player_index: int, kind: String, district_index: int, product_name: String = "", target_owner: int = -999) -> int:
	var plan := _ai_refresh_route_plan(player_index)
	var plan_product := String(plan.get("product", ""))
	var stage := String(plan.get("stage", ""))
	if plan_product == "" or stage == "":
		return 0
	var resolved_owner := target_owner
	if resolved_owner == -999 and district_index >= 0 and district_index < districts.size():
		var city := _district_city(district_index)
		if _city_is_active(city):
			resolved_owner = int(city.get("owner", -1))
	var product_match := product_name == plan_product
	if not product_match:
		product_match = _ai_district_touches_product(district_index, plan_product)
	var bonus := 0
	if product_match:
		bonus += AI_ROUTE_PLAN_MATCH_BONUS
	match stage:
		"build_supply":
			if kind == "city_build":
				bonus += 110
				if district_index == int(plan.get("partner_district", -1)):
					bonus += 180
				if product_match:
					bonus += 70
			elif ["city_product_shift", "area_trade_contract", "product_contract_boon", "region_economy_shift"].has(kind) and product_match:
				bonus += 72
		"create_demand":
			if ["city_demand_shift", "area_trade_contract", "product_contract_boon", "route_flow_boon", "city_contract_boon"].has(kind) and product_match:
				bonus += 118
			if resolved_owner == player_index:
				bonus += 42
		"strengthen_route":
			if ["route_flow_boon", "city_revenue_boost", "city_product_upgrade", "city_contract_boon", "product_speculation", "city_gdp_derivative", "product_contract_boon", "product_growth_boon", "area_trade_contract"].has(kind) and product_match:
				bonus += 108
			if resolved_owner == player_index:
				bonus += 34
		"defend_route":
			if ["route_insurance", "special_monster_delay", "route_flow_boon", "region_economy_shift", "city_demand_shift"].has(kind):
				bonus += 96
			if resolved_owner == player_index:
				bonus += mini(132, _ai_product_route_threat_score(player_index, plan_product) / 2)
		"attack_rival":
			if ["route_sabotage", "monster_lure", "panic_shift", "mudslide", "area_damage", "region_economy_shift", "city_gdp_derivative"].has(kind):
				bonus += 116
			if resolved_owner >= 0 and resolved_owner != player_index:
				bonus += 76
			if product_match:
				bonus += 44
	return max(0, bonus)


func _ai_district_focus_score(player_index: int, district_index: int) -> int:
	var focus := _ai_focus_product(player_index)
	if focus == "" or district_index < 0 or district_index >= districts.size():
		return 0
	var score := 0
	if (districts[district_index].get("products", []) as Array).has(focus):
		score += AI_ECONOMIC_FOCUS_MATCH_BONUS + int(round(float(_product_price(focus)) / 4.0))
	if (districts[district_index].get("demands", []) as Array).has(focus):
		score += 48
	var city := _district_city(district_index)
	if _city_is_active(city):
		if _city_product_names(city).has(focus):
			score += 72
		if _city_demand_names(city).has(focus):
			score += 36
	return score


func _ai_product_for_skill(player_index: int, skill: Dictionary) -> String:
	var explicit := String(skill.get("play_product", ""))
	if explicit != "":
		return explicit
	var focus := _ai_focus_product(player_index)
	var route_product := _ai_route_plan_product(player_index)
	var kind := String(skill.get("kind", ""))
	var harmful_supply := int(skill.get("price_delta", 0)) < 0 or int(skill.get("market_supply_pressure", 0)) > int(skill.get("market_demand_pressure", 0))
	if harmful_supply:
		var rival_product := _ai_preferred_product(player_index, true)
		if rival_product != "":
			return rival_product
	if route_product != "" and (_player_product_flow(player_index, route_product) > 0 or ["product_speculation", "product_contract_boon", "product_growth_boon", "market_stabilize", "city_product_shift", "city_demand_shift", "region_economy_shift", "area_trade_contract"].has(kind)):
		return route_product
	if focus != "" and (_player_product_flow(player_index, focus) > 0 or ["product_speculation", "product_contract_boon", "product_growth_boon", "market_stabilize", "city_product_shift", "city_demand_shift", "region_economy_shift"].has(kind)):
		return focus
	return _skill_play_product(skill, player_index)


func _ai_first_alive_district() -> int:
	for i in range(districts.size()):
		if not bool(districts[i].get("destroyed", false)):
			return i
	return -1


func _ai_city_target_score(player_index: int, district_index: int, own_city: bool, prefer_damaged: bool = false) -> int:
	var city := _district_city(district_index)
	if not _city_is_active(city):
		return -1
	var is_owned := int(city.get("owner", -1)) == player_index
	if is_owned != own_city:
		return -1
	var score := 30
	score += int(city.get("last_income", 0))
	score += (city.get("products", []) as Array).size() * 28
	score += (city.get("demands", []) as Array).size() * 18
	score += (city.get("trade_routes", []) as Array).size() * 10
	score += int(city.get("competition_matches", 0)) * 8
	var focus := _ai_focus_product(player_index)
	if focus != "":
		if _city_product_names(city).has(focus):
			score += 82 if own_city else 96
		if _city_demand_names(city).has(focus):
			score += 44 if own_city else 34
		if not own_city and _player_product_flow(player_index, focus) > 0 and _city_product_names(city).has(focus):
			score += 78
	if prefer_damaged:
		score += int(city.get("trade_route_damage", 0)) * 80
		score += int(districts[district_index].get("damage", 0)) * 20
	else:
		score -= int(city.get("trade_route_damage", 0)) * 6
	return score


func _ai_best_city_district(player_index: int, own_city: bool, prefer_damaged: bool = false) -> int:
	var best_index := -1
	var best_score := -1
	for district_index_variant in _active_city_district_indices():
		var district_index := int(district_index_variant)
		var score := _ai_city_target_score(player_index, district_index, own_city, prefer_damaged)
		if score > best_score:
			best_score = score
			best_index = district_index
	return best_index


func _ai_preferred_product(player_index: int, use_rivals: bool = false) -> String:
	var focus := _ai_focus_product(player_index)
	if focus != "":
		if not use_rivals and _player_product_flow(player_index, focus) > 0:
			return focus
		if use_rivals and not _competing_city_indices_for_product(player_index, focus).is_empty():
			return focus
	var scores := {}
	for district_index_variant in _active_city_district_indices():
		var district_index := int(district_index_variant)
		var city := _district_city(district_index)
		var is_owned := int(city.get("owner", -1)) == player_index
		if is_owned == use_rivals:
			continue
		for product_variant in _city_product_names(city):
			var product_name := String(product_variant)
			scores[product_name] = int(scores.get(product_name, 0)) + 50 + int(round(float(_product_price(product_name)) / 4.0))
		for demand_variant in _city_demand_names(city):
			var demand_name := String(demand_variant)
			scores[demand_name] = int(scores.get(demand_name, 0)) + 25 + int(round(float(_product_price(demand_name)) / 7.0))
	var best_product := ""
	var best_score := -1
	for product_variant in PRODUCT_CATALOG:
		var product_name := String(product_variant)
		var score := int(scores.get(product_name, 0))
		if score <= 0 and scores.is_empty():
			score = _product_price(product_name)
		if score > best_score:
			best_score = score
			best_product = product_name
	return best_product


func _ai_monster_card_landing_score(player_index: int, skill: Dictionary, district_index: int) -> int:
	if not _can_summon_monster_card_at_district(skill, district_index):
		return -1
	var score := 40
	var district: Dictionary = districts[district_index]
	var catalog_index := int(skill.get("catalog_index", 0))
	var template := _catalog_entry(catalog_index)
	var probe := {"resource_focus": (template.get("resource_focus", []) as Array).duplicate(true)}
	score += _monster_resource_match_score(probe, district_index) * 28
	for product_variant in district.get("products", []):
		score += int(round(float(_product_price(String(product_variant))) / 8.0))
	score += int(round(float(district.get("transport_score", 1.0)) * 15.0))
	score += (district.get("card_choices", []) as Array).size() * 7
	var city := _district_city(district_index)
	if _city_is_active(city):
		if int(city.get("owner", -1)) == player_index:
			score -= 120
		else:
			score += 130 + int(city.get("last_income", 0))
	score -= int(district.get("damage", 0)) * 8
	return score


func _ai_best_monster_card_district(player_index: int, skill: Dictionary) -> int:
	var monster_name := String(skill.get("monster_name", ""))
	for actor_variant in auto_monsters:
		var actor: Dictionary = actor_variant
		if not bool(actor.get("down", false)) and int(actor.get("owner", -1)) == player_index and String(actor.get("name", "")) == monster_name and int(actor.get("rank", 1)) < 4:
			return int(actor.get("position", _ai_first_alive_district()))
	var best_index := -1
	var best_score := -1
	for i in range(districts.size()):
		var score := _ai_monster_card_landing_score(player_index, skill, i)
		if score > best_score:
			best_score = score
			best_index = i
	return best_index


func _ai_monster_target_for_skill(player_index: int, skill: Dictionary) -> int:
	var bound_uid := int(skill.get("bound_monster_uid", 0))
	if bound_uid > 0:
		var bound_slot := _auto_monster_slot_by_uid(bound_uid)
		if bound_slot >= 0 and not bool((auto_monsters[bound_slot] as Dictionary).get("down", false)):
			return bound_slot
	var kind := String(skill.get("kind", ""))
	var prefer_foreign := ["monster_lure", "special_monster_delay", "mudslide", "monster_takeover"].has(kind)
	var best_slot := -1
	var best_score := -1
	for slot in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[slot]
		if bool(actor.get("down", false)):
			continue
		var is_owned := int(actor.get("owner", -1)) == player_index
		if prefer_foreign and is_owned:
			continue
		if not prefer_foreign and not is_owned:
			continue
		var score := int(actor.get("rank", 1)) * 45 + int(actor.get("hp", 0)) + int(actor.get("armor", 0)) * 8
		if prefer_foreign:
			score += int(actor.get("owner_damage_cash_pool", 0)) / 20
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _ai_best_district_near_monster(player_index: int, monster_slot: int, range_limit: float = -1.0) -> int:
	if monster_slot < 0 or monster_slot >= auto_monsters.size():
		return _ai_best_city_district(player_index, false)
	var actor: Dictionary = auto_monsters[monster_slot]
	var best_index := -1
	var best_score := -1
	for i in range(districts.size()):
		if bool(districts[i].get("destroyed", false)):
			continue
		if range_limit > 0.0 and _entity_distance_to_district(actor, i) > range_limit:
			continue
		var score := _district_event_weight(i)
		var city := _district_city(i)
		if _city_is_active(city):
			score += 100 if int(city.get("owner", -1)) != player_index else -120
		if score > best_score:
			best_score = score
			best_index = i
	if best_index >= 0:
		return best_index
	return int(actor.get("position", _ai_first_alive_district()))


func _ai_city_product_overlap_score(player_index: int, target_city_index: int) -> int:
	var target_city := _district_city(target_city_index)
	if not _city_is_active(target_city):
		return 0
	var target_products := _city_product_names(target_city)
	var target_demands := _city_demand_names(target_city)
	var score := 0
	for own_city_index_variant in _active_city_indices_for_player(player_index):
		var own_city := _district_city(int(own_city_index_variant))
		for product_variant in _city_product_names(own_city):
			var product_name := String(product_variant)
			if target_products.has(product_name):
				score += 56 + int(round(float(_product_price(product_name)) / 8.0))
			if target_demands.has(product_name):
				score += 18
		for demand_variant in _city_demand_names(own_city):
			var demand_name := String(demand_variant)
			if target_products.has(demand_name):
				score += 26
	return score


func _ai_rival_city_pressure_score(player_index: int, district_index: int) -> int:
	if district_index < 0 or district_index >= districts.size() or bool(districts[district_index].get("destroyed", false)):
		return -1
	var city := _district_city(district_index)
	if not _city_is_active(city):
		return -1
	var owner := int(city.get("owner", -1))
	if owner == player_index:
		return -1
	var competition := _city_competition_matches(district_index)
	var breakdown := _city_cycle_income_breakdown(district_index, competition)
	var score := 150
	score += int(breakdown.get("net", 0))
	score += int(city.get("last_income", 0))
	score += _ai_city_product_overlap_score(player_index, district_index)
	score += (city.get("trade_routes", []) as Array).size() * 20
	score += _district_trade_route_load(district_index) * 14
	score += _city_product_names(city).size() * 24
	score += _city_demand_names(city).size() * 14
	score += competition * 18
	score -= int(city.get("trade_route_damage", 0)) * 12
	score -= int(districts[district_index].get("damage", 0)) * 5
	if owner < 0:
		score -= 25
	return maxi(1, score)


func _ai_monster_lure_plan(player_index: int, skill: Dictionary, range_limit: float = -1.0) -> Dictionary:
	var best := {}
	var best_score := -1
	for slot in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[slot]
		if bool(actor.get("down", false)):
			continue
		var actor_owner := int(actor.get("owner", -1))
		for city_index_variant in _active_city_district_indices():
			var city_index := int(city_index_variant)
			var attack_value := _ai_rival_city_pressure_score(player_index, city_index)
			if attack_value <= 0:
				continue
			var distance := _entity_distance_to_district(actor, city_index)
			if range_limit > 0.0 and distance > range_limit:
				continue
			var resource_match := _monster_resource_match_score(actor, city_index)
			var score := attack_value
			score += resource_match * 70
			score += int(actor.get("rank", 1)) * 36
			score += int(actor.get("hp", 0)) / 2
			score += _district_trade_route_load(city_index) * 8
			score -= int(round(distance / 34.0))
			if actor_owner == player_index:
				score -= 28
			elif actor_owner >= 0:
				score += 36
			else:
				score += 12
			if int(actor.get("position", -1)) == city_index:
				score += 34
			if score <= best_score:
				continue
			var city := _district_city(city_index)
			var target_products := _city_product_names(city)
			var product_name := String(target_products[0]) if not target_products.is_empty() else _ai_preferred_product(player_index, true)
			best_score = score
			best = {
				"target_slot": slot,
				"district": city_index,
				"target_city": city_index,
				"target_owner": int(city.get("owner", -1)),
				"product": product_name,
				"score": maxi(1, score),
				"attack_value": attack_value,
				"resource_match": resource_match,
				"distance_m": int(round(distance)),
				"strategic_role": "monster_lure",
				"reason": "诱导怪%d·%s压向%s｜城市价值%d｜资源吻合%d｜距离%s" % [
					slot + 1,
					String(actor.get("name", "怪兽")),
					String(districts[city_index].get("name", "竞争城市")),
					attack_value,
					resource_match,
					_meters_text(distance),
				],
			}
	return best


func _ai_monster_delay_plan(player_index: int, skill: Dictionary) -> Dictionary:
	var best := {}
	var best_score := -1
	for slot in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[slot]
		if bool(actor.get("down", false)) or int(actor.get("owner", -1)) == player_index:
			continue
		for city_index_variant in _active_city_indices_for_player(player_index):
			var city_index := int(city_index_variant)
			var city_score := _ai_city_target_score(player_index, city_index, true, false)
			if city_score <= 0:
				continue
			var distance := _entity_distance_to_district(actor, city_index)
			var resource_match := _monster_resource_match_score(actor, city_index)
			var score := 72 + city_score + resource_match * 42 + int(actor.get("rank", 1)) * 25 - int(round(distance / 28.0))
			if score <= best_score:
				continue
			best_score = score
			best = {
				"target_slot": slot,
				"district": city_index,
				"target_city": city_index,
				"target_owner": player_index,
				"score": maxi(1, score),
				"attack_value": city_score,
				"resource_match": resource_match,
				"distance_m": int(round(distance)),
				"strategic_role": "monster_delay",
				"reason": "延后怪%d·%s接近己方%s｜防守价值%d｜距离%s" % [
					slot + 1,
					String(actor.get("name", "怪兽")),
					String(districts[city_index].get("name", "城市")),
					city_score,
					_meters_text(distance),
				],
			}
	return best


func _ai_card_kind_bias(player_index: int, kind: String) -> float:
	var profile := _ai_profile_for_player(player_index)
	if kind == "monster_card" or kind == "monster_bound_action" or _skill_targets_monster({"kind": kind}):
		return float(profile.get("monster_bias", 1.0))
	if ["route_sabotage", "panic_shift", "monster_takeover", "mudslide", "special_monster_delay"].has(kind):
		return float(profile.get("business_bias", 1.0))
	return float(profile.get("economy_bias", 1.0))


func _ai_best_city_for_gdp_derivative(player_index: int, direction: String) -> int:
	var best_index := -1
	var best_score := -999999
	for index_variant in _active_city_district_indices():
		var index := int(index_variant)
		var city := _district_city(index)
		var owner := int(city.get("owner", -1))
		var last_income := int(city.get("last_income", _city_cycle_income(index, _city_competition_matches(index))))
		var damage := int(districts[index].get("damage", 0))
		var disrupted := int(city.get("trade_disrupted_routes", 0)) + int(city.get("trade_route_damage", 0))
		var score := last_income
		if direction == "up":
			score += 180 if owner == player_index else 30
			score += _ai_district_focus_score(player_index, index)
			score -= damage * 34 + disrupted * 42
		else:
			score += 150 if owner >= 0 and owner != player_index else -40
			score += damage * 52 + disrupted * 62 + int(districts[index].get("panic", 0)) / 2
			score += _ai_district_focus_score(player_index, index) / 3
		if score > best_score:
			best_score = score
			best_index = index
	return best_index


func _ai_generic_card_effect_score(player_index: int, skill: Dictionary, district_index: int, product_name: String = "", target_owner: int = -999) -> int:
	var score := 0
	var harmful_target := target_owner >= 0 and target_owner != player_index
	var helpful_target := target_owner == player_index
	score += int(skill.get("cash", 0)) / 4
	score += int(skill.get("draw_amount", 0)) * 45
	score += int(skill.get("revenue_amount", 0)) / 2
	score += int(skill.get("contract_income", 0)) * maxi(1, int(skill.get("contract_turns", 1))) / 5
	score += int(round((float(skill.get("route_flow_multiplier", 1.0)) - 1.0) * 120.0)) if helpful_target else 0
	score += int(skill.get("repair_routes", 0)) * (55 if helpful_target else 18)
	var economy_delta := int(skill.get("production_delta", 0)) + int(skill.get("transport_delta", 0)) + int(skill.get("consumption_delta", 0))
	if economy_delta > 0:
		score += economy_delta * (60 if helpful_target else 24)
	elif economy_delta < 0:
		score += abs(economy_delta) * (70 if harmful_target else -45)
	var route_damage := int(skill.get("route_damage", 0)) + int(skill.get("decline_route_damage", 0))
	if route_damage > 0:
		score += route_damage * (75 if harmful_target else 15)
	var area_damage := int(skill.get("damage", 0))
	if area_damage > 0:
		score += area_damage * (58 if harmful_target else 22)
	var demand_pressure := int(skill.get("market_demand_pressure", 0))
	var supply_pressure := int(skill.get("market_supply_pressure", 0))
	if product_name != "":
		if product_name == _ai_focus_product(player_index) or product_name == _ai_route_plan_product(player_index):
			score += abs(demand_pressure - supply_pressure) * 18
		score += int(skill.get("price_delta", 0)) / 2
	var gdp_multiplier := float(skill.get("gdp_bet_multiplier", 0.0))
	if gdp_multiplier > 0.0:
		var direction := String(skill.get("gdp_bet_direction", "up"))
		var city := _district_city(district_index)
		var last_income := int(city.get("last_income", 0))
		var risk := int(districts[district_index].get("damage", 0)) * 26 + int(city.get("trade_disrupted_routes", 0)) * 32 if district_index >= 0 and district_index < districts.size() else 0
		if direction == "up":
			score += int(round(gdp_multiplier * 55.0)) + (80 if helpful_target else 20) + maxi(0, last_income / 6 - risk)
		else:
			score += int(round(gdp_multiplier * 68.0)) + (90 if harmful_target else 20) + risk + int(skill.get("gdp_bet_destroy_bonus", 0)) / 8
	score += int(skill.get("card_access_extra_hops", 0)) * 42
	if bool(skill.get("card_access_global", false)):
		score += 105
	return score


func _ai_card_play_context(player_index: int, slot_index: int, skill: Dictionary) -> Dictionary:
	var kind := String(skill.get("kind", ""))
	var own_city := _ai_best_city_district(player_index, true)
	var rival_city := _ai_best_pressure_target_city(player_index)
	var fallback := own_city if own_city >= 0 else _ai_first_alive_district()
	var focus_product := _ai_focus_product(player_index)
	var planned_product := _ai_product_for_skill(player_index, skill)
	var route_product := _ai_route_plan_product(player_index)
	var route_stage := _ai_route_plan_stage(player_index)
	var phase_info := _ai_refresh_game_phase(player_index)
	var context := {
		"action": "出牌",
		"slot_index": slot_index,
		"card_name": String(skill.get("name", "卡牌")),
		"kind": kind,
		"policy_kind": kind,
		"district": fallback,
		"target_slot": -1,
		"product": planned_product,
		"focus_product": focus_product,
		"focus_score": _ai_focus_score(player_index),
		"focus_bonus": 0,
		"strategy_intent": _ai_strategy_intent(player_index),
		"strategy_score": _ai_strategy_score(player_index),
		"strategy_bonus": 0,
		"route_plan_product": route_product,
		"route_plan_stage": route_stage,
		"route_plan_score": _ai_route_plan_score(player_index),
		"route_plan_bonus": 0,
		"game_phase": String(phase_info.get("phase", "midgame")),
		"competitive_posture": String(phase_info.get("posture", "contesting")),
		"score_gap_to_leader": int(phase_info.get("gap", 0)),
		"leader_index": int(phase_info.get("leader_index", -1)),
		"phase_bonus": 0,
		"learning_bonus": 0,
		"contract_source": -1,
		"contract_target": -1,
		"score": 70 + maxi(0, int(skill.get("cost", 2))) * 12 + maxi(1, _skill_rank(String(skill.get("name", "")))) * 9,
		"reason": "按卡牌强度、目标价值、商品流动、路线计划与AI性格评分",
	}
	if kind == "monster_card":
		context["district"] = _ai_best_monster_card_district(player_index, skill)
		context["score"] = 1180 if bool(skill.get("starter_play_free", false)) else int(context["score"]) + 150
	elif kind == "monster_bound_action":
		var bound_slot := _ai_monster_target_for_skill(player_index, skill)
		if bound_slot < 0:
			return {}
		context["target_slot"] = bound_slot
		context["district"] = _ai_best_district_near_monster(player_index, bound_slot)
		context["score"] = int(context["score"]) + 95
	elif kind == "monster_lure":
		var lure_plan := _ai_monster_lure_plan(player_index, skill)
		if lure_plan.is_empty():
			return {}
		var base_lure_score := int(context["score"])
		context.merge(lure_plan, true)
		context["score"] = base_lure_score + int(lure_plan.get("score", 0))
		context["reason"] = String(lure_plan.get("reason", "诱导怪兽压向竞争城市"))
	elif kind == "mudslide":
		var mudslide_plan := _ai_monster_lure_plan(player_index, skill, float(skill.get("range", DEFAULT_AOE_RADIUS_METERS)))
		if mudslide_plan.is_empty():
			return {}
		var base_mudslide_score := int(context["score"])
		context.merge(mudslide_plan, true)
		context["score"] = base_mudslide_score + int(mudslide_plan.get("score", 0)) + int(skill.get("damage", 1)) * 45
		context["reason"] = "AOE打击｜%s" % String(mudslide_plan.get("reason", "锁定竞争城市"))
	elif kind == "special_monster_delay":
		var delay_plan := _ai_monster_delay_plan(player_index, skill)
		if delay_plan.is_empty():
			return {}
		var base_delay_score := int(context["score"])
		context.merge(delay_plan, true)
		context["score"] = base_delay_score + int(delay_plan.get("score", 0))
		context["reason"] = String(delay_plan.get("reason", "延后威胁怪兽"))
	elif _skill_targets_monster(skill):
		var target_slot := _ai_monster_target_for_skill(player_index, skill)
		if target_slot < 0:
			return {}
		context["target_slot"] = target_slot
		var target_range := float(skill.get("range", -1.0)) if kind == "mudslide" else -1.0
		context["district"] = _ai_best_district_near_monster(player_index, target_slot, target_range)
		context["score"] = int(context["score"]) + 80
	elif kind == "area_trade_contract":
		if own_city < 0 or rival_city < 0:
			return {}
		context["contract_source"] = own_city
		context["contract_target"] = rival_city
		context["district"] = rival_city
		var source_products := _city_product_names(_district_city(own_city))
		if focus_product != "" and source_products.has(focus_product):
			context["product"] = focus_product
			context["focus_bonus"] = int(context.get("focus_bonus", 0)) + AI_ECONOMIC_FOCUS_MATCH_BONUS
		elif not source_products.is_empty():
			context["product"] = String(source_products[0])
		context["score"] = int(context["score"]) + 110 + int(skill.get("accept_cash", 0)) / 3
	elif ["city_revenue_boost", "city_product_upgrade", "city_product_shift", "city_demand_shift", "city_contract_boon", "route_flow_boon"].has(kind):
		if own_city < 0:
			return {}
		context["district"] = own_city
		context["score"] = int(context["score"]) + 90
		context["focus_bonus"] = int(context.get("focus_bonus", 0)) + _ai_district_focus_score(player_index, own_city)
	elif kind == "route_insurance":
		var damaged_city := _ai_best_city_district(player_index, true, true)
		if damaged_city < 0 or int(_district_city(damaged_city).get("trade_route_damage", 0)) <= 0:
			return {}
		context["district"] = damaged_city
		context["score"] = int(context["score"]) + int(_district_city(damaged_city).get("trade_route_damage", 0)) * 70
	elif kind == "city_gdp_derivative":
		var gdp_direction := String(skill.get("gdp_bet_direction", "up"))
		var gdp_target := _ai_best_city_for_gdp_derivative(player_index, gdp_direction)
		if gdp_target < 0:
			return {}
		context["district"] = gdp_target
		context["policy_kind"] = "%s_%s" % [kind, gdp_direction]
		context["score"] = int(context["score"]) + 110 + int(round(float(skill.get("gdp_bet_multiplier", 1.0)) * 35.0)) + int(skill.get("gdp_bet_destroy_bonus", 0)) / 10
		context["reason"] = "匿名%s%sGDP｜倍率×%.2f｜持续%d周期" % [
			"买涨" if gdp_direction == "up" else "做空",
			districts[gdp_target]["name"],
			float(skill.get("gdp_bet_multiplier", 1.0)),
			int(skill.get("gdp_bet_turns", 1)),
		]
	elif ["route_sabotage", "panic_shift"].has(kind):
		if rival_city < 0:
			return {}
		context["district"] = rival_city
		context["product"] = _ai_preferred_product(player_index, true)
		if String(context.get("product", "")) == focus_product and focus_product != "":
			context["focus_bonus"] = int(context.get("focus_bonus", 0)) + AI_ECONOMIC_FOCUS_MATCH_BONUS
		context["score"] = int(context["score"]) + 105
	elif kind == "region_economy_shift":
		var net_shift := int(skill.get("production_delta", 0)) + int(skill.get("transport_delta", 0)) + int(skill.get("demand_delta", 0))
		context["district"] = own_city if net_shift >= 0 else rival_city
		if int(context["district"]) < 0:
			return {}
		context["focus_bonus"] = int(context.get("focus_bonus", 0)) + _ai_district_focus_score(player_index, int(context["district"]))
	elif kind == "intel_city_reveal":
		if rival_city < 0:
			return {}
		context["district"] = rival_city
		context["score"] = int(context["score"]) + 88 + _city_intel_priority_score({"potential_income": int(_district_city(rival_city).get("last_income", 0)), "last_income": int(_district_city(rival_city).get("last_income", 0)), "competition": _city_competition_matches(rival_city), "disrupted": int(_district_city(rival_city).get("trade_disrupted_routes", 0)), "products": _city_product_names(_district_city(rival_city)), "demands": _city_demand_names(_district_city(rival_city)), "marked": false})
	elif kind == "intel_card_trace":
		if _traceable_card_entries(selected_card_resolution_id, 1).is_empty():
			return {}
		context["district"] = _ai_first_alive_district()
		context["score"] = int(context["score"]) + 95 + resolved_card_history.size() * 4
	elif kind == "intel_contract_trace":
		if _traceable_contract_entries(selected_card_resolution_id, 1).is_empty():
			return {}
		context["district"] = _ai_first_alive_district()
		context["score"] = int(context["score"]) + 100 + pending_contract_offers.size() * 18
	elif kind == "card_access_boon":
		context["district"] = own_city if own_city >= 0 else _ai_first_alive_district()
		context["score"] = int(context["score"]) + 90 + int(skill.get("card_access_extra_hops", 0)) * 35
		if bool(skill.get("card_access_global", false)):
			context["score"] = int(context["score"]) + 85
	elif kind == "supply_draw":
		context["district"] = -1
		for i in range(districts.size()):
			if _can_buy_card_from_district(i, player_index) and not (districts[i].get("card_choices", []) as Array).is_empty():
				context["district"] = i
				break
		if int(context["district"]) < 0:
			return {}
	elif ["cash_gain", "product_speculation", "product_contract_boon", "market_stabilize", "product_growth_boon"].has(kind):
		context["score"] = int(context["score"]) + int(skill.get("cash", 0)) / 3 + 45
	if int(context.get("district", -1)) < 0:
		return {}
	var product_name := String(context.get("product", ""))
	if focus_product != "" and product_name == focus_product:
		context["focus_bonus"] = int(context.get("focus_bonus", 0)) + AI_ECONOMIC_FOCUS_MATCH_BONUS
		context["score"] = int(context["score"]) + int(context.get("focus_bonus", 0))
	var required := _skill_play_flow_required(skill, player_index)
	if required > 0:
		product_name = String(skill.get("play_product", ""))
		if product_name == "":
			product_name = String(context.get("product", ""))
		if product_name == "":
			product_name = _skill_play_product(skill, player_index)
		context["product"] = product_name
		var available := _player_product_flow(player_index, product_name)
		if available < required:
			return {}
		context["score"] = int(context["score"]) + available * 8
	var cash_cost := _skill_play_cash_cost(skill)
	if int((players[player_index] as Dictionary).get("cash", 0)) < cash_cost:
		return {}
	var target_owner := -999
	var context_district := int(context.get("district", -1))
	if context.has("target_owner"):
		target_owner = int(context.get("target_owner", -999))
	elif context_district >= 0 and context_district < districts.size():
		var target_city := _district_city(context_district)
		if _city_is_active(target_city):
			target_owner = int(target_city.get("owner", -1))
	var strategy_bonus := _ai_strategy_bonus_for_candidate(player_index, kind, context_district, String(context.get("product", "")), target_owner)
	if strategy_bonus > 0:
		context["strategy_bonus"] = int(context.get("strategy_bonus", 0)) + strategy_bonus
		context["score"] = int(context["score"]) + strategy_bonus
	var route_bonus := _ai_route_plan_bonus_for_candidate(player_index, kind, context_district, String(context.get("product", "")), target_owner)
	if route_bonus > 0:
		context["route_plan_bonus"] = int(context.get("route_plan_bonus", 0)) + route_bonus
		context["score"] = int(context["score"]) + route_bonus
	var phase_bonus := _ai_phase_bonus_for_candidate(player_index, kind, context_district, String(context.get("product", "")), target_owner, skill)
	if phase_bonus != 0:
		context["phase_bonus"] = phase_bonus
		context["score"] = int(context["score"]) + phase_bonus
	var generic_bonus := _ai_generic_card_effect_score(player_index, skill, context_district, String(context.get("product", "")), target_owner)
	if generic_bonus != 0:
		context["generic_effect_bonus"] = generic_bonus
		context["score"] = int(context["score"]) + generic_bonus
	var learning_bonus := _ai_learning_bonus(player_index, String(context.get("policy_kind", kind)), String(context.get("strategy_intent", "")), String(context.get("route_plan_stage", "")), String(context.get("product", "")), "匿名出牌")
	if learning_bonus != 0:
		context["learning_bonus"] = learning_bonus
		context["score"] = int(context["score"]) + learning_bonus
	context["score"] = maxi(1, int(round(float(context["score"]) * _ai_card_kind_bias(player_index, kind))))
	context["bid_budget"] = _ai_card_bid_budget(player_index, int(context["score"]), cash_cost)
	return context


func _ai_card_play_candidates(player_index: int) -> Array:
	var result := []
	if not _player_is_ai(player_index) or float((players[player_index] as Dictionary).get("action_cooldown", 0.0)) > 0.0:
		return result
	if _queued_card_entry_index_for_player(player_index) >= 0 or _next_batch_card_entry_index_for_player(player_index) >= 0:
		return result
	var slots: Array = (players[player_index] as Dictionary).get("slots", [])
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var skill: Dictionary = slots[slot_index]
		if bool(skill.get("queued_for_resolution", false)) or float(skill.get("cooldown_left", 0.0)) > 0.0 or float(skill.get("lock_left", 0.0)) > 0.0:
			continue
		var context := _ai_card_play_context(player_index, slot_index, skill)
		if not context.is_empty():
			result.append(context)
	return result


func _ai_card_buy_candidates(player_index: int) -> Array:
	var result := []
	if not _player_is_ai(player_index) or float((players[player_index] as Dictionary).get("action_cooldown", 0.0)) > 0.0:
		return result
	var player: Dictionary = players[player_index]
	var cash := int(player.get("cash", 0))
	var profile := _ai_profile_for_player(player_index)
	var focus_product := _ai_focus_product(player_index)
	var strategy_intent := _ai_strategy_intent(player_index)
	var strategy_score := _ai_strategy_score(player_index)
	var route_product := _ai_route_plan_product(player_index)
	var route_stage := _ai_route_plan_stage(player_index)
	var route_score := _ai_route_plan_score(player_index)
	var phase_info := _ai_refresh_game_phase(player_index)
	var phase := String(phase_info.get("phase", "midgame"))
	var posture := String(phase_info.get("posture", "contesting"))
	var phase_label := _ai_game_phase_label(phase)
	var posture_label := _ai_competitive_posture_label(posture)
	for district_index in range(districts.size()):
		if not _can_buy_card_from_district(district_index, player_index) or bool(districts[district_index].get("destroyed", false)):
			continue
		for card_variant in districts[district_index].get("card_choices", []):
			var card_name := _canonical_card_supply_name(String(card_variant))
			if card_name == "" or not _player_can_receive_card(player, card_name):
				continue
			var price := _card_price(card_name, district_index, player_index)
			if cash - price < AI_CARD_BUY_MIN_CASH_RESERVE:
				continue
			var skill := _make_skill(card_name)
			var kind := String(skill.get("kind", ""))
			var score := 55 + int(skill.get("cost", 2)) * 11 - int(round(float(price) / 12.0))
			var focus_bonus := _ai_district_focus_score(player_index, district_index) / 2
			var family_slot := _find_highest_family_card_slot(player, card_name)
			if family_slot >= 0:
				score += 85
			var product_name := _ai_product_for_skill(player_index, skill)
			var required := _skill_play_flow_required(skill, player_index)
			var available := _player_product_flow(player_index, product_name)
			var strategy_bonus := _ai_strategy_bonus_for_candidate(player_index, kind, district_index, product_name)
			var route_bonus := _ai_route_plan_bonus_for_candidate(player_index, kind, district_index, product_name)
			var target_owner := -999
			var city := _district_city(district_index)
			if _city_is_active(city):
				target_owner = int(city.get("owner", -1))
			var generic_bonus := _ai_generic_card_effect_score(player_index, skill, district_index, product_name, target_owner)
			var phase_bonus := _ai_phase_bonus_for_candidate(player_index, kind, district_index, product_name, target_owner, skill)
			var learning_bonus := _ai_learning_bonus(player_index, kind, strategy_intent, route_stage, product_name, "区域购牌")
			if required <= 0 or available >= required:
				score += 35
			else:
				score -= (required - available) * 12
			if focus_product != "" and product_name == focus_product:
				focus_bonus += AI_ECONOMIC_FOCUS_MATCH_BONUS
			if ["product_speculation", "product_contract_boon", "product_growth_boon", "city_product_shift", "city_demand_shift", "route_flow_boon", "region_economy_shift"].has(kind) and focus_bonus > 0:
				score += focus_bonus
			if strategy_bonus > 0:
				score += strategy_bonus
			if route_bonus > 0:
				score += route_bonus
			if generic_bonus != 0:
				score += generic_bonus
			if phase_bonus != 0:
				score += phase_bonus
			if learning_bonus != 0:
				score += learning_bonus
			var role := _player_role_card_for_index(player_index)
			if String(role.get("bonus_card_product", "")) != "" and _district_or_city_has_product(district_index, String(role.get("bonus_card_product", ""))):
				score += 65
			score = maxi(1, int(round(float(score) * _ai_card_kind_bias(player_index, kind))))
			result.append({
				"action": "购牌",
				"card_name": card_name,
				"kind": kind,
				"policy_kind": kind,
				"district": district_index,
				"product": product_name,
				"price": price,
				"score": score,
				"focus_product": focus_product,
				"focus_score": _ai_focus_score(player_index),
				"focus_bonus": focus_bonus,
				"strategy_intent": strategy_intent,
				"strategy_score": strategy_score,
				"strategy_bonus": strategy_bonus,
				"route_plan_product": route_product,
				"route_plan_stage": route_stage,
				"route_plan_score": route_score,
				"route_plan_bonus": route_bonus,
				"game_phase": phase,
				"competitive_posture": posture,
				"score_gap_to_leader": int(phase_info.get("gap", 0)),
				"leader_index": int(phase_info.get("leader_index", -1)),
				"phase_bonus": phase_bonus,
				"generic_effect_bonus": generic_bonus,
				"learning_bonus": learning_bonus,
				"reason": "%s｜费用¥%d｜流动%d/%d｜阶段%s/%s+%d｜策略%s+%d｜路线%s/%s+%d｜学习%d｜探索率%.0f%%" % [
					_card_display_name(card_name),
					price,
					available,
					required,
					phase_label,
					posture_label,
					phase_bonus,
					strategy_intent if strategy_intent != "" else "未定",
					strategy_bonus,
					route_product if route_product != "" else "未定",
					_ai_route_plan_stage_label(route_stage),
					route_bonus,
					learning_bonus,
					float(profile.get("exploration", 0.15)) * 100.0,
				],
			})
	return result


func _ai_pick_candidate(player_index: int, candidates: Array, force: bool = false) -> Dictionary:
	if candidates.is_empty():
		return {}
	var ordered := candidates.duplicate(true)
	ordered.sort_custom(Callable(self, "_sort_ai_candidate_score_desc"))
	var exploration := float(_ai_profile_for_player(player_index).get("exploration", 0.15))
	if force or ordered.size() == 1 or rng.randf() >= exploration:
		return ordered[0] as Dictionary
	var top_count := mini(4, ordered.size())
	var weights := []
	for i in range(top_count):
		weights.append(maxi(1, int((ordered[i] as Dictionary).get("score", 1))))
	var picked := _weighted_pick_index(weights)
	return ordered[picked] as Dictionary if picked >= 0 else ordered[0] as Dictionary


func _ai_card_bid_budget(player_index: int, utility_score: int, play_cash_cost: int = 0) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var profile := _ai_profile_for_player(player_index)
	var aggression := float(profile.get("bid_aggression", 1.0))
	var cash := int((players[player_index] as Dictionary).get("cash", 0))
	var affordable := maxi(0, cash - play_cash_cost - AI_CARD_BUY_MIN_CASH_RESERVE)
	var utility_budget := int(floor(float(maxi(0, utility_score - 60)) * aggression / 3.0 / 10.0)) * 10
	return mini(affordable, maxi(0, utility_budget))


func _ai_next_bid_increment(highest_bid: int) -> int:
	if highest_bid >= 500:
		return 100
	if highest_bid >= 200:
		return 50
	if highest_bid >= 50:
		return 20
	return 10


func _ai_card_decision_metadata(candidate: Dictionary, target_slot: int, bid_budget: int) -> Dictionary:
	var metadata := {
		"card_name": String(candidate.get("card_name", "")),
		"target_slot": target_slot,
		"bid_budget": bid_budget,
	}
	for field_name in ["policy_kind", "target_city", "target_owner", "product", "attack_value", "resource_match", "distance_m", "strategic_role", "focus_product", "focus_score", "focus_bonus", "strategy_intent", "strategy_score", "strategy_bonus", "route_plan_product", "route_plan_stage", "route_plan_score", "route_plan_bonus", "game_phase", "competitive_posture", "score_gap_to_leader", "leader_index", "phase_bonus", "generic_effect_bonus", "learning_bonus"]:
		if candidate.has(field_name):
			metadata[field_name] = candidate[field_name]
	return metadata


func _ai_queue_play_candidate(player_index: int, candidate: Dictionary, all_candidates: Array = []) -> bool:
	var slot_index := int(candidate.get("slot_index", -1))
	var target_slot := int(candidate.get("target_slot", -1))
	var previous_player := selected_player
	var previous_district := selected_district
	var previous_product := selected_trade_product
	var previous_source := selected_contract_source_district
	var previous_target := selected_contract_target_district
	selected_player = player_index
	selected_district = int(candidate.get("district", _ai_first_alive_district()))
	selected_trade_product = String(candidate.get("product", ""))
	selected_contract_source_district = int(candidate.get("contract_source", -1))
	selected_contract_target_district = int(candidate.get("contract_target", -1))
	var desired_bid := 0
	var budget := int(candidate.get("bid_budget", 0))
	if not card_resolution_queue.is_empty() and not card_resolution_batch_locked and active_card_resolution.is_empty():
		desired_bid = mini(budget, _highest_card_resolution_bid() + _ai_next_bid_increment(_highest_card_resolution_bid()))
	_set_card_bid_for_player(player_index, desired_bid, false)
	var queued := _queue_skill_resolution(player_index, slot_index, target_slot)
	if queued:
		var queue_index := _queued_card_entry_index_for_player(player_index)
		var in_next_batch := false
		if queue_index < 0:
			queue_index = _next_batch_card_entry_index_for_player(player_index)
			in_next_batch = true
		if queue_index >= 0:
			var entry: Dictionary = (next_card_resolution_queue[queue_index] if in_next_batch else card_resolution_queue[queue_index]) as Dictionary
			entry["ai_utility_score"] = int(candidate.get("score", 0))
			entry["ai_bid_budget"] = budget
			entry["ai_reason"] = String(candidate.get("reason", ""))
			if in_next_batch:
				next_card_resolution_queue[queue_index] = entry
			else:
				card_resolution_queue[queue_index] = entry
		_record_ai_decision(
			player_index,
			"匿名出牌",
			int(candidate.get("district", -1)),
			int(candidate.get("score", 0)),
			"%s｜目标怪兽%d｜报价预算¥%d｜%s" % [String(candidate.get("card_name", "卡牌")), target_slot + 1, budget, String(candidate.get("reason", "按卡牌策略评分"))],
			all_candidates,
			_ai_card_decision_metadata(candidate, target_slot, budget)
		)
	selected_player = previous_player
	selected_district = previous_district
	selected_trade_product = previous_product
	selected_contract_source_district = previous_source
	selected_contract_target_district = previous_target
	return queued


func _ai_execute_card_turn(player_index: int, force: bool = false) -> String:
	var play_candidates := _ai_card_play_candidates(player_index)
	var play_choice := _ai_pick_candidate(player_index, play_candidates, force)
	if not play_choice.is_empty() and _ai_queue_play_candidate(player_index, play_choice, play_candidates):
		return "play"
	var buy_candidates := _ai_card_buy_candidates(player_index)
	var buy_choice := _ai_pick_candidate(player_index, buy_candidates, force)
	if buy_choice.is_empty():
		return "wait"
	var district_index := int(buy_choice.get("district", -1))
	var card_name := String(buy_choice.get("card_name", ""))
	if _buy_card_for_player_from_district(player_index, district_index, card_name, true, force):
		_record_ai_decision(
			player_index,
			"区域购牌",
			district_index,
			int(buy_choice.get("score", 0)),
			String(buy_choice.get("reason", "按价格、流动与手牌协同评分")),
			buy_candidates,
			{
				"card_name": card_name,
				"price": int(buy_choice.get("price", 0)),
				"product": String(buy_choice.get("product", "")),
				"focus_product": String(buy_choice.get("focus_product", "")),
				"focus_score": int(buy_choice.get("focus_score", 0)),
				"focus_bonus": int(buy_choice.get("focus_bonus", 0)),
				"strategy_intent": String(buy_choice.get("strategy_intent", "")),
				"strategy_score": int(buy_choice.get("strategy_score", 0)),
				"strategy_bonus": int(buy_choice.get("strategy_bonus", 0)),
				"route_plan_product": String(buy_choice.get("route_plan_product", "")),
				"route_plan_stage": String(buy_choice.get("route_plan_stage", "")),
				"route_plan_score": int(buy_choice.get("route_plan_score", 0)),
				"route_plan_bonus": int(buy_choice.get("route_plan_bonus", 0)),
				"game_phase": String(buy_choice.get("game_phase", "")),
				"competitive_posture": String(buy_choice.get("competitive_posture", "")),
				"score_gap_to_leader": int(buy_choice.get("score_gap_to_leader", 0)),
				"leader_index": int(buy_choice.get("leader_index", -1)),
				"phase_bonus": int(buy_choice.get("phase_bonus", 0)),
				"policy_kind": String(buy_choice.get("policy_kind", buy_choice.get("kind", ""))),
				"learning_bonus": int(buy_choice.get("learning_bonus", 0)),
			}
		)
		return "buy"
	return "wait"


func _auto_ai_card_decisions(force: bool = false) -> int:
	if game_over or not ai_card_decision_enabled:
		return 0
	var acted := 0
	for player_index_variant in _ai_player_indices():
		var result := _ai_execute_card_turn(int(player_index_variant), force)
		if result != "wait":
			acted += 1
	return acted


func _auto_ai_auction_bids(force: bool = false) -> int:
	if not ai_card_decision_enabled or not card_resolution_auction_open or card_resolution_queue.size() < 2:
		return 0
	var raised := 0
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		var queue_index := _queued_card_entry_index_for_player(player_index)
		if queue_index < 0:
			continue
		var entry: Dictionary = card_resolution_queue[queue_index]
		var current_bid := int(entry.get("tip", 0))
		var highest_bid := _highest_card_resolution_bid()
		if current_bid == highest_bid and queue_index == 0:
			continue
		var budget := int(entry.get("ai_bid_budget", 0))
		var bid_learning_bonus := _ai_learning_bonus(player_index, "auction_bid", "", "", "", "匿名竞价")
		budget = maxi(0, budget + bid_learning_bonus)
		var target_bid := highest_bid + _ai_next_bid_increment(highest_bid)
		if target_bid > budget:
			continue
		var aggression := float(_ai_profile_for_player(player_index).get("bid_aggression", 1.0))
		var learned_reaction := clampf(float(bid_learning_bonus) / 240.0, -0.24, 0.24)
		if not force and rng.randf() > clampf(0.42 + aggression * 0.28 + learned_reaction, 0.0, 0.96):
			continue
		if _set_card_bid_for_player(player_index, target_bid, true):
			_record_ai_decision(
				player_index,
				"匿名竞价",
				int(entry.get("resolution_id", -1)),
				int(entry.get("ai_utility_score", 0)),
				"公开最高¥%d→报价¥%d｜预算¥%d" % [highest_bid, target_bid, budget],
				[],
				{"policy_kind": "auction_bid", "card_name": _card_resolution_entry_card_label(entry), "bid": target_bid, "bid_budget": budget, "learning_bonus": bid_learning_bonus}
			)
			raised += 1
	return raised


func _ai_contract_response_candidates(player_index: int, entry: Dictionary) -> Array:
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	var source_index := int(entry.get("contract_source_district", -1))
	var target_index := int(entry.get("contract_target_district", -1))
	var products: Array = entry.get("contract_products", []) as Array
	var source_owner := -1
	if source_index >= 0 and source_index < districts.size():
		source_owner = int(_district_city(source_index).get("owner", -1))
	var target_city := _district_city(target_index)
	var accept_score := 62
	accept_score += int(skill.get("accept_cash", 0)) / 3
	accept_score += maxi(0, int(skill.get("accept_production_delta", 0))) * 34
	accept_score += maxi(0, int(skill.get("accept_transport_delta", 0))) * 42
	accept_score += maxi(0, int(skill.get("accept_consumption_delta", 0))) * 32
	var accept_route_flow := float(skill.get("accept_route_flow_multiplier", 1.0))
	if accept_route_flow > 1.001:
		accept_score += int(round((accept_route_flow - 1.0) * 230.0)) + maxi(1, int(skill.get("route_flow_turns", 1))) * 8
	accept_score += maxi(0, int(skill.get("contract_add_products", 0))) * 38
	accept_score += maxi(0, int(skill.get("contract_add_demands", 0))) * 42
	accept_score -= maxi(0, int(skill.get("contract_remove_products", 0))) * 16
	accept_score -= maxi(0, int(skill.get("contract_remove_demands", 0))) * 16
	accept_score += products.size() * 15
	if _city_is_active(target_city):
		accept_score += int(target_city.get("trade_route_damage", 0)) * 14
		accept_score += maxi(0, 4 - (target_city.get("demands", []) as Array).size()) * 12
	if source_owner == player_index:
		accept_score += 58
	var route_product := _ai_route_plan_product(player_index)
	var route_stage := _ai_route_plan_stage(player_index)
	var route_score := _ai_route_plan_score(player_index)
	var contract_matches_route := route_product != "" and (products.has(route_product) or _ai_district_touches_product(source_index, route_product) or _ai_district_touches_product(target_index, route_product))
	var accept_route_bonus := 0
	if contract_matches_route:
		accept_route_bonus += AI_ROUTE_PLAN_MATCH_BONUS
		if ["create_demand", "strengthen_route", "defend_route"].has(route_stage):
			accept_route_bonus += 82
	if source_owner == player_index and route_product != "":
		accept_route_bonus += 46
	accept_score += accept_route_bonus
	var contract_product_tag := route_product if contract_matches_route else _limited_name_list(products, 1, "")
	var accept_learning_bonus := _ai_learning_bonus(player_index, "contract_accept", "", route_stage, contract_product_tag, "匿名合约签约")
	accept_score += accept_learning_bonus
	var reject_score := 54
	if source_owner >= 0 and source_owner != player_index:
		reject_score += 42
	reject_score += maxi(0, int(skill.get("contract_remove_products", 0)) + int(skill.get("contract_remove_demands", 0))) * 10
	var reject_route_bonus := 0
	if source_owner >= 0 and source_owner != player_index and route_stage == "attack_rival" and contract_matches_route:
		reject_route_bonus += 72
	reject_score += reject_route_bonus
	var reject_learning_bonus := _ai_learning_bonus(player_index, "contract_reject", "", route_stage, contract_product_tag, "匿名合约拒签")
	reject_score += reject_learning_bonus
	var decline_badness := 0
	decline_badness += int(skill.get("decline_cash_penalty", 0)) / 3
	decline_badness += maxi(0, -int(skill.get("decline_production_delta", 0))) * 38
	decline_badness += maxi(0, -int(skill.get("decline_transport_delta", 0))) * 44
	decline_badness += maxi(0, -int(skill.get("decline_consumption_delta", 0))) * 34
	decline_badness += maxi(0, int(skill.get("decline_route_damage", 0))) * 52
	accept_score += decline_badness
	reject_score -= int(round(float(decline_badness) * 0.55))
	return [
		{
			"action": "签约",
			"card_name": String(skill.get("name", "区域供需合约")),
			"kind": "area_trade_contract_response",
			"policy_kind": "contract_accept",
			"district": target_index,
			"product": _limited_name_list(products, 3, "未指定"),
			"score": maxi(1, accept_score),
			"reason": "签约奖励:%s｜拒签代价:%s｜商品:%s" % [
				_contract_accept_effect_summary(skill),
				_contract_decline_effect_summary(skill),
				_limited_name_list(products, 3, "未指定"),
			],
			"route_plan_product": route_product,
			"route_plan_stage": route_stage,
			"route_plan_score": route_score,
			"route_plan_bonus": accept_route_bonus,
			"learning_bonus": accept_learning_bonus,
		},
		{
			"action": "拒签",
			"card_name": String(skill.get("name", "区域供需合约")),
			"kind": "area_trade_contract_response",
			"policy_kind": "contract_reject",
			"district": target_index,
			"product": _limited_name_list(products, 3, "未指定"),
			"score": maxi(1, reject_score),
			"reason": "拒绝可能避免帮对手供给区扩张｜拒签惩罚:%s" % _contract_decline_effect_summary(skill),
			"route_plan_product": route_product,
			"route_plan_stage": route_stage,
			"route_plan_score": route_score,
			"route_plan_bonus": reject_route_bonus,
			"learning_bonus": reject_learning_bonus,
		},
	]


func _update_ai_contract_responses(force: bool = false) -> int:
	if pending_contract_offers.is_empty():
		return 0
	var responded := 0
	var offers_snapshot := pending_contract_offers.duplicate(true)
	for offer_variant in offers_snapshot:
		if not (offer_variant is Dictionary):
			continue
		var entry: Dictionary = offer_variant
		if String(entry.get("contract_response", CONTRACT_RESPONSE_PENDING)) != CONTRACT_RESPONSE_PENDING:
			continue
		var owner := int(entry.get("contract_target_owner", -1))
		if not _player_is_ai(owner):
			continue
		if not force and float(entry.get("contract_decision_timer", CONTRACT_DECISION_SECONDS)) > CONTRACT_DECISION_SECONDS - 1.0:
			continue
		var candidates := _ai_contract_response_candidates(owner, entry)
		var choice := _ai_pick_candidate(owner, candidates, force)
		if choice.is_empty():
			continue
		var accept := String(choice.get("action", "")) == "签约"
		var contract_id := int(entry.get("contract_offer_id", entry.get("resolution_id", -1)))
		_record_ai_decision(
			owner,
			"匿名合约%s" % String(choice.get("action", "回应")),
			int(entry.get("contract_target_district", -1)),
			int(choice.get("score", 0)),
			String(choice.get("reason", "按奖励、惩罚和是否帮对手评分")),
			candidates,
			{
				"card_name": String((entry.get("skill", {}) as Dictionary).get("name", "区域供需合约")),
				"contract_offer_id": contract_id,
				"contract_response": String(choice.get("action", "")),
				"policy_kind": String(choice.get("policy_kind", "")),
				"route_plan_product": String(choice.get("route_plan_product", "")),
				"route_plan_stage": String(choice.get("route_plan_stage", "")),
				"route_plan_score": int(choice.get("route_plan_score", 0)),
				"route_plan_bonus": int(choice.get("route_plan_bonus", 0)),
				"learning_bonus": int(choice.get("learning_bonus", 0)),
			}
		)
		if _respond_to_pending_contract_for_player(owner, contract_id, accept, false):
			_log("目标城市业主匿名%s了一份合约；系统只公开结果，不公开是哪位玩家回应。" % ("签署" if accept else "拒绝"))
			responded += 1
	return responded


func _ai_public_player_product_signal(viewer_index: int, guessed_player: int, product_name: String) -> int:
	if viewer_index < 0 or viewer_index >= players.size() or guessed_player < 0 or guessed_player >= players.size() or product_name == "":
		return 0
	var signal_score := 0
	var viewer: Dictionary = players[viewer_index]
	var guesses: Dictionary = viewer.get("city_guesses", {})
	var confidences: Dictionary = viewer.get("city_guess_confidence", {})
	for city_key in guesses.keys():
		if int(guesses.get(city_key, -1)) != guessed_player:
			continue
		var city_index := int(city_key)
		if city_index < 0 or city_index >= districts.size():
			continue
		var city := _district_city(city_index)
		if not _city_is_active(city):
			continue
		var confidence := _normalized_city_guess_confidence(int(confidences.get(city_key, CITY_GUESS_CONFIDENCE_DEFAULT)))
		var confidence_weight := 16 + confidence * 12
		if _city_product_names(city).has(product_name):
			signal_score += confidence_weight + 18
		if _city_demand_names(city).has(product_name):
			signal_score += confidence_weight
		var public_clues: Array = city.get("public_clues", [])
		for clue_variant in public_clues:
			var clue := _normalize_city_public_clue_entry(clue_variant)
			if (clue.get("products", []) as Array).has(product_name):
				signal_score += 8 + confidence * 3
	for entry_variant in _public_card_resolution_owner_entries():
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if not bool(entry.get("public_owner_revealed", false)) or int(entry.get("player_index", -1)) != guessed_player:
			continue
		if String(entry.get("play_requirement_product", "")) == product_name:
			signal_score += 34
		var skill: Dictionary = entry.get("skill", {}) as Dictionary
		if String(skill.get("play_product", "")) == product_name:
			signal_score += 24
	return signal_score


func _ai_city_guess_owner_candidate(viewer_index: int, city_entry: Dictionary, guessed_player: int) -> Dictionary:
	var city_index := int(city_entry.get("district_index", -1))
	if city_index < 0 or city_index >= districts.size() or guessed_player < 0 or guessed_player >= players.size() or guessed_player == viewer_index:
		return {}
	var city := _district_city(city_index)
	if not _city_is_active(city):
		return {}
	var score := int(city_entry.get("priority", 0)) + 18
	var reason_key := CITY_GUESS_REASON_INTUITION
	var reason_bits := []
	for product_variant in _city_product_names(city):
		var product_name := String(product_variant)
		var product_signal := _ai_public_player_product_signal(viewer_index, guessed_player, product_name)
		if product_signal > 0:
			score += product_signal
			reason_key = CITY_GUESS_REASON_PRODUCT
			reason_bits.append("%s商品线索+%d" % [product_name, product_signal])
	for demand_variant in _city_demand_names(city):
		var demand_name := String(demand_variant)
		var demand_signal := _ai_public_player_product_signal(viewer_index, guessed_player, demand_name) / 2
		if demand_signal > 0:
			score += demand_signal
			if reason_key == CITY_GUESS_REASON_INTUITION:
				reason_key = CITY_GUESS_REASON_ROUTE
			reason_bits.append("%s需求线索+%d" % [demand_name, demand_signal])
	var latest_clue := String(city_entry.get("latest_clue", ""))
	if latest_clue != "" and latest_clue != "暂无公开线索":
		score += 14
		if latest_clue.contains("卡") or latest_clue.contains("牌"):
			reason_key = CITY_GUESS_REASON_CARD
		reason_bits.append("公开线索")
	var current_guess := int(city_entry.get("guess", -1))
	var current_confidence := int(city_entry.get("confidence", 0))
	if current_guess == guessed_player:
		score += 10 - current_confidence * 3
	elif current_guess >= 0:
		score -= 18 + current_confidence * 10
	if reason_bits.is_empty():
		score += 5 + ((city_index + guessed_player * 3 + business_cycle_count) % 11)
		reason_bits.append("低置信直觉")
	var learning_bonus := _ai_learning_bonus(viewer_index, "city_owner_guess", "", "", "", "城市业主推理")
	score += learning_bonus
	var confidence := CITY_GUESS_CONFIDENCE_LOW
	if score >= 150:
		confidence = CITY_GUESS_CONFIDENCE_HIGH
	elif score >= 105:
		confidence = CITY_GUESS_CONFIDENCE_MEDIUM
	return {
		"action": "城市业主标注",
		"kind": "city_owner_guess",
		"policy_kind": "city_owner_guess",
		"district": city_index,
		"guessed_player": guessed_player,
		"confidence": confidence,
		"reason_key": reason_key,
		"learning_bonus": learning_bonus,
		"score": maxi(1, score),
		"reason": "%s→玩家%d｜%s" % [
			String(districts[city_index].get("name", "城市")),
			guessed_player + 1,
			"、".join(reason_bits),
		],
	}


func _ai_city_guess_candidates(player_index: int) -> Array:
	var result := []
	if not _player_is_ai(player_index):
		return result
	for entry_variant in _intel_city_guess_entries(player_index, 12):
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if bool(entry.get("marked", false)) and int(entry.get("confidence", 0)) >= CITY_GUESS_CONFIDENCE_HIGH:
			continue
		var best := {}
		for guessed_player in range(players.size()):
			var candidate := _ai_city_guess_owner_candidate(player_index, entry, guessed_player)
			if candidate.is_empty():
				continue
			if best.is_empty() or int(candidate.get("score", 0)) > int(best.get("score", 0)):
				best = candidate
		if not best.is_empty():
			result.append(best)
	return result


func _ai_apply_city_guess_candidate(player_index: int, candidate: Dictionary, all_candidates: Array) -> bool:
	var district_index := int(candidate.get("district", -1))
	var guessed_player := int(candidate.get("guessed_player", -1))
	if not _mark_city_guess_for_player(player_index, district_index, guessed_player, int(candidate.get("confidence", CITY_GUESS_CONFIDENCE_LOW)), String(candidate.get("reason_key", CITY_GUESS_REASON_INTUITION))):
		return false
	_record_ai_decision(
		player_index,
		"城市业主推理",
		district_index,
		int(candidate.get("score", 0)),
		String(candidate.get("reason", "按公开商品和城市线索标注")),
		all_candidates,
		{
			"policy_kind": String(candidate.get("policy_kind", "city_owner_guess")),
			"guessed_player": guessed_player,
			"confidence": int(candidate.get("confidence", 0)),
			"reason_key": String(candidate.get("reason_key", "")),
			"learning_bonus": int(candidate.get("learning_bonus", 0)),
		}
	)
	return true


func _ai_card_guess_candidate_for_owner(player_index: int, entry: Dictionary, guessed_player: int) -> Dictionary:
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	if resolution_id < 0 or guessed_player < 0 or guessed_player >= players.size() or guessed_player == player_index:
		return {}
	if bool(entry.get("public_owner_revealed", false)):
		return {}
	var actual_owner := int(entry.get("player_index", -1))
	if actual_owner == player_index:
		return {}
	var guessers: Array = entry.get("guessers", [])
	if guessers.has(player_index):
		return {}
	var stake := _card_owner_guess_stake_for_player(player_index)
	if int((players[player_index] as Dictionary).get("cash", 0)) < stake + AI_CARD_BUY_MIN_CASH_RESERVE:
		return {}
	var score := 48
	var reason_bits := []
	var private_known := _private_known_card_owner_for_entry(player_index, entry)
	if private_known == guessed_player:
		score += 180
		reason_bits.append("私有追帧命中")
	elif private_known >= 0:
		score -= 90
	var product_name := String(entry.get("play_requirement_product", ""))
	if product_name != "":
		var product_signal := _ai_public_player_product_signal(player_index, guessed_player, product_name)
		if product_signal > 0:
			score += product_signal + 20
			reason_bits.append("%s流动条件" % product_name)
	var selected_city := int(entry.get("selected_district", -1))
	if selected_city >= 0 and selected_city < districts.size():
		var guesses: Dictionary = (players[player_index] as Dictionary).get("city_guesses", {})
		if int(guesses.get(selected_city, -1)) == guessed_player:
			score += 26
			reason_bits.append("目标城市私标吻合")
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	var kind := String(skill.get("kind", ""))
	for previous_variant in resolved_card_history:
		if not (previous_variant is Dictionary):
			continue
		var previous := previous_variant as Dictionary
		if not bool(previous.get("public_owner_revealed", false)) or int(previous.get("player_index", -1)) != guessed_player:
			continue
		var previous_skill: Dictionary = previous.get("skill", {}) as Dictionary
		if String(previous_skill.get("kind", "")) == kind:
			score += 18
			reason_bits.append("已揭示同类牌")
			break
	var bid := int(entry.get("winning_bid", entry.get("tip", 0)))
	if bid >= 100:
		score += mini(28, bid / 20)
		reason_bits.append("高报价线索")
	if reason_bits.is_empty():
		score += ((resolution_id + guessed_player * 5 + business_cycle_count) % 13)
		reason_bits.append("弱线索试探")
	var learning_bonus := _ai_learning_bonus(player_index, "card_owner_guess", "", "", product_name, "卡牌归属押注")
	score += learning_bonus
	return {
		"action": "卡牌归属押注",
		"kind": "card_owner_guess",
		"policy_kind": "card_owner_guess",
		"resolution_id": resolution_id,
		"card_name": _card_resolution_entry_card_label(entry),
		"guessed_player": guessed_player,
		"stake": stake,
		"district": selected_city,
		"product": product_name,
		"learning_bonus": learning_bonus,
		"score": maxi(1, score),
		"reason": "轨道#%d《%s》→玩家%d｜%s" % [
			resolution_id,
			_card_resolution_entry_card_label(entry),
			guessed_player + 1,
			"、".join(reason_bits),
		],
	}


func _ai_card_guess_candidates(player_index: int) -> Array:
	var result := []
	if not _player_is_ai(player_index):
		return result
	for i in range(resolved_card_history.size() - 1, -1, -1):
		var entry_variant: Variant = resolved_card_history[i]
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if bool(entry.get("public_owner_revealed", false)):
			continue
		var best := {}
		for guessed_player in range(players.size()):
			var candidate := _ai_card_guess_candidate_for_owner(player_index, entry, guessed_player)
			if candidate.is_empty():
				continue
			if best.is_empty() or int(candidate.get("score", 0)) > int(best.get("score", 0)):
				best = candidate
		if not best.is_empty():
			result.append(best)
	return result


func _ai_apply_card_guess_candidate(player_index: int, candidate: Dictionary, all_candidates: Array) -> bool:
	_record_ai_decision(
		player_index,
		"卡牌归属押注",
		int(candidate.get("resolution_id", -1)),
		int(candidate.get("score", 0)),
		String(candidate.get("reason", "按公开条件与私有线索押注")),
		all_candidates,
		{
			"policy_kind": String(candidate.get("policy_kind", "card_owner_guess")),
			"resolution_id": int(candidate.get("resolution_id", -1)),
			"guessed_player": int(candidate.get("guessed_player", -1)),
			"stake": int(candidate.get("stake", 0)),
			"card_name": String(candidate.get("card_name", "")),
			"product": String(candidate.get("product", "")),
			"learning_bonus": int(candidate.get("learning_bonus", 0)),
		}
	)
	return _guess_card_resolution_owner_for_player(player_index, int(candidate.get("resolution_id", -1)), int(candidate.get("guessed_player", -1)), true)


func _auto_ai_intel_decisions(force: bool = false) -> int:
	if game_over or not ai_card_decision_enabled:
		return 0
	var acted := 0
	for player_index_variant in _ai_player_indices():
		var player_index := int(player_index_variant)
		var city_candidates := _ai_city_guess_candidates(player_index)
		var city_choice := _ai_pick_candidate(player_index, city_candidates, force)
		if not city_choice.is_empty() and (force or int(city_choice.get("score", 0)) >= AI_INTEL_MIN_CITY_SCORE):
			if _ai_apply_city_guess_candidate(player_index, city_choice, city_candidates):
				acted += 1
		if acted >= AI_INTEL_ACTIONS_PER_TICK and not force:
			return acted
		var card_candidates := _ai_card_guess_candidates(player_index)
		var card_choice := _ai_pick_candidate(player_index, card_candidates, force)
		if not card_choice.is_empty() and (force or int(card_choice.get("score", 0)) >= AI_INTEL_MIN_CARD_SCORE):
			if _ai_apply_card_guess_candidate(player_index, card_choice, card_candidates):
				acted += 1
		if acted >= AI_INTEL_ACTIONS_PER_TICK and not force:
			return acted
	return acted


func _update_ai_decisions(delta: float) -> void:
	if not ai_card_decision_enabled or players.is_empty():
		return
	ai_auction_reaction_timer -= delta
	if ai_auction_reaction_timer <= 0.0:
		_auto_ai_auction_bids(false)
		_update_ai_contract_responses(false)
		ai_auction_reaction_timer = AI_AUCTION_REACTION_INTERVAL_SECONDS
	ai_card_decision_timer -= delta
	if ai_card_decision_timer <= 0.0:
		_auto_ai_card_decisions(false)
		ai_card_decision_timer = AI_CARD_DECISION_INTERVAL_SECONDS
	ai_intel_decision_timer -= delta
	if ai_intel_decision_timer <= 0.0:
		_auto_ai_intel_decisions(false)
		ai_intel_decision_timer = AI_INTEL_DECISION_INTERVAL_SECONDS


func _ensure_configured_role_indices() -> void:
	var normalized := []
	for i in range(MAX_PLAYER_COUNT):
		var value := _player_role_template_index(i)
		if i < configured_role_indices.size():
			value = int(configured_role_indices[i])
		normalized.append(_clamp_role_index(value))
	configured_role_indices = normalized


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
	return _clamp_role_index(int(configured_role_indices[player_index]))


func _configured_starter_monster_index(player_index: int) -> int:
	_ensure_configured_starter_monster_indices()
	if player_index < 0 or player_index >= configured_starter_monster_indices.size():
		return wrapi(player_index, 0, max(1, _catalog_size()))
	return clampi(int(configured_starter_monster_indices[player_index]), 0, max(0, _catalog_size() - 1))


func _set_configured_role_for_player(player_index: int, role_index: int) -> void:
	if player_index < 0 or player_index >= MAX_PLAYER_COUNT:
		return
	_ensure_configured_role_indices()
	configured_role_indices[player_index] = _clamp_role_index(role_index)
	_save_settings(false)
	_log("玩家%d下次开局角色设置为：%s。" % [
		player_index + 1,
		String(_make_player_role_card(player_index, _configured_role_index(player_index)).get("name", "外星辛迪加")),
	])
	_refresh_ui()


func _cycle_configured_role_for_player(player_index: int, step: int) -> void:
	_set_configured_role_for_player(player_index, _configured_role_index(player_index) + step)


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
		"subtitle": "自动怪兽｜临时美工",
	}


func _catalog_move_speed(index: int) -> float:
	var entry: Dictionary = _catalog_entry(index)
	return float(entry.get("move", MONSTER_RAMPAGE_MOVE_METERS))


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


func _monster_mobility_summary(actor: Dictionary) -> String:
	return _monster_mobility_summary_from_fields(actor.get("movement_traits", []) as Array, actor.get("terrain_move_multiplier", {}) as Dictionary)


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
	var family := _skill_family(card_name)
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
	var rank := clampi(_skill_rank(card_name), 1, 4)
	var entry := _catalog_entry(catalog_index)
	var resource_focus: Array = entry.get("resource_focus", [])
	var play_product := String(resource_focus[0]) if not resource_focus.is_empty() else "活体芯片"
	var hp_bonus := int(round(float(entry.get("hp", 40)) * (1.0 + float(rank - 1) * 0.22)))
	var move_bonus := float(entry.get("move", MONSTER_RAMPAGE_MOVE_METERS)) * (1.0 + float(rank - 1) * 0.10)
	var duration := float(entry.get("duration", MONSTER_CARD_DURATION_BASE_SECONDS + float(rank - 1) * MONSTER_CARD_DURATION_RANK_STEP_SECONDS))
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
		"play_product": play_product,
		"play_flow_required": 0 if rank <= 1 else rank,
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
		"text": "匿名召唤%s入场，或在同名己方怪兽仍在场时用于升级并刷新生命/在场时间。卡牌属性：生命%d｜在场%s｜移动%s｜机动:%s｜区域限制：%s（起始怪兽牌会改写为不限区）。I级怪兽牌免商品流动；II-IV级需要对应商品流动。召唤者获得/刷新%d张绑定固定技能牌；怪兽仍按自身概率自动行动。场上每已有一只怪兽，额外支付¥%d。" % [
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
	return _skill_family(card_name).begins_with("兽技·")


func _monster_technique_definition(card_name: String) -> Dictionary:
	var family := _skill_family(card_name)
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
	var rank := clampi(_skill_rank(card_name), 1, 4)
	var action: Dictionary = (actions[action_index] as Dictionary).duplicate(true)
	var resource_focus: Array = _catalog_entry(catalog_index).get("resource_focus", [])
	var play_product := String(resource_focus[0]) if not resource_focus.is_empty() else "活体芯片"
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
		"play_product": play_product,
		"play_flow_required": maxi(1, rank),
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
	var name := String(entry.get("name", ""))
	if MONSTER_ACTION_TABLES.has(name):
		return MONSTER_ACTION_TABLES[name] as Array
	return MONSTER_ACTION_TABLES["尸套龙"] as Array


func _auto_monster_actions(actor: Dictionary) -> Array:
	if String(actor.get("name", "")) == "机械杰克" and bool(actor.get("bracelet_active", false)):
		return JACK_BRACELET_ACTION_TABLE
	return _catalog_actions(int(actor.get("catalog_index", 0)))


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
	var name := String(entry.get("name", ""))
	var table: Dictionary = MONSTER_SKILL_WEIGHT_TABLES.get(name, {})
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


func _auto_monster_action_weights(actor: Dictionary, any_destroyed: bool) -> Array:
	var actions := _auto_monster_actions(actor)
	var name := String(actor.get("name", ""))
	var table: Dictionary = MONSTER_SKILL_WEIGHT_TABLES.get(name, {})
	var source_weights: Array = table.get("escalated" if any_destroyed else "early", [])
	var weights := []
	if source_weights.is_empty():
		weights = _catalog_action_weights(actions, any_destroyed)
	else:
		for i in range(actions.size()):
			weights.append(int(source_weights[i]) if i < source_weights.size() else 0)
	return _ranked_action_weights(weights, int(actor.get("rank", 1)))


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


func _monster_ranked_action_weight_delta_summary(actor: Dictionary, any_destroyed: bool = false) -> String:
	var rank := clampi(int(actor.get("rank", 1)), 1, 4)
	if rank <= 1:
		return "I级无额外概率倾斜"
	var catalog_index := int(actor.get("catalog_index", 0))
	var base_weights := _catalog_action_weights_for_index(catalog_index, any_destroyed)
	var ranked_weights := _ranked_action_weights(base_weights, rank)
	return "%s：%s" % [_level_text(rank), _action_weight_delta_summary(base_weights, ranked_weights)]


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


func _assert_ranked_action_weights_escalate(index: int) -> bool:
	var rank_i := _catalog_ranked_action_weights_for_index(index, false, 1)
	var rank_iv := _catalog_ranked_action_weights_for_index(index, false, 4)
	if rank_i.size() < 4 or rank_iv.size() != rank_i.size():
		return false
	var late_i := 0
	var late_iv := 0
	for i in range(rank_i.size()):
		if i >= 3:
			late_i += int(rank_i[i])
			late_iv += int(rank_iv[i])
	return late_iv > late_i


func _assert_auto_monster_rank_weights(actor: Dictionary) -> bool:
	var rank := clampi(int(actor.get("rank", 1)), 1, 4)
	var weights := _auto_monster_action_weights(actor, false)
	var catalog_weights := _catalog_ranked_action_weights_for_index(int(actor.get("catalog_index", 0)), false, rank)
	return weights == catalog_weights


func _catalog_action_numeric_facts(action: Dictionary) -> String:
	var facts := []
	var damage := int(action.get("damage", 0))
	var range_m := float(action.get("range", 0.0))
	var move_override := float(action.get("move_override", -1.0))
	var knockback := float(action.get("knockback", 0.0))
	var panic := int(action.get("panic", 0))
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
	if panic > 0:
		facts.append("热度+%d" % panic)
	if armor > 0:
		facts.append("护甲+%d" % armor)
	if heal > 0:
		facts.append("自愈%d" % heal)
	if self_damage > 0:
		facts.append("反冲%d" % self_damage)
	return "｜".join(facts)


func _bestiary_text(index: int) -> String:
	var entry: Dictionary = _catalog_entry(index)
	var actions := _catalog_actions(index)
	var lines := []
	lines.append("%s｜怪兽卡原型" % String(entry.get("name", "怪兽")))
	lines.append(String(entry.get("style", "自动怪兽。")))
	lines.append("HP：%d｜护甲：%d｜移动速度：%s" % [
		int(entry.get("hp", 0)),
		int(entry.get("armor", 0)),
		_meters_text(_catalog_move_speed(index)),
	])
	lines.append("区域破坏数值：移动碾压%d/区｜击退撞击%d/区｜资源吸取%d｜相遇战距离%s" % [
		int(entry.get("move_damage", AUTO_MONSTER_DEFAULT_MOVE_DAMAGE)),
		int(entry.get("collision_damage", AUTO_MONSTER_DEFAULT_COLLISION_DAMAGE)),
		int(entry.get("resource_drain", 1)),
		_meters_text(AUTO_MONSTER_ENCOUNTER_RANGE_METERS),
	])
	var resource_focus: Array = entry.get("resource_focus", [])
	lines.append("资源偏好：%s；同一区域命中多种偏好资源时，目标权重会叠加，可能把多只怪兽吸到一起。" % ("、".join(resource_focus) if not resource_focus.is_empty() else "暂无固定偏好"))
	var economy_boon: Dictionary = entry.get("economy_boon", {})
	if not economy_boon.is_empty():
		var boon_text := String(economy_boon.get("text", "偏好商品会形成本局持续的正面经济天气。"))
		lines.append("正面经济天气：%s｜%s" % [
			String(economy_boon.get("label", "经济天气")),
			boon_text,
		])
	var monster_card := _skill_definition(_monster_card_name(index, 1))
	if not monster_card.is_empty():
		lines.append("怪兽卡属性：%s；%s。" % [
			_skill_play_requirement_text(monster_card),
			"生命%d｜在场%s｜区域限制%s｜固定技能%d张" % [
				int(monster_card.get("hp", 0)),
				_monster_card_duration_text(monster_card),
				_monster_card_region_text(monster_card),
				int(monster_card.get("fixed_skill_count", 1)),
			],
		])
	lines.append("")
	lines.append("自动行动概率：I级使用基础概率；II-IV级会把权重向后段高危招式倾斜。IV级开局权重修正：%s；IV级破坏后权重修正：%s。" % [
		_catalog_rank_iv_shift_summary(index, false),
		_catalog_rank_iv_shift_summary(index, true),
	])
	var early_weights := _catalog_action_weights_for_index(index, false)
	var early_total := _weight_total(early_weights)
	var escalated_weights := _catalog_action_weights_for_index(index, true)
	var escalated_total := _weight_total(escalated_weights)
	for i in range(actions.size()):
		var action: Dictionary = actions[i]
		lines.append("%d. %s｜I级开局%s / I级破坏后%s｜IV级开局%s / IV级破坏后%s｜%s" % [
			i + 1,
			String(action.get("name", "行动")),
			_probability_text(int(early_weights[i]), early_total),
			_probability_text(int(escalated_weights[i]), escalated_total),
			_catalog_ranked_probability_line(index, i, false, 4),
			_catalog_ranked_probability_line(index, i, true, 4),
			"%s｜%s" % [_catalog_action_numeric_facts(action), String(action.get("text", ""))],
		])
	return "\n".join(lines)


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
		if not _skill_exists(skill_name):
			push_warning("卡牌目录缺少：%s" % skill_name)
			continue
		result.append(skill_name)


func _canonical_card_supply_name(skill_name: String) -> String:
	if skill_name == "":
		return ""
	var rank := _skill_rank(skill_name)
	if rank <= 0:
		return skill_name if _skill_exists(skill_name) else ""
	var base_name := "%s1" % _skill_family(skill_name)
	return base_name if _skill_exists(base_name) else ""


func _current_run_card_pool() -> Array:
	var result := []
	_append_unique_cards(result, COMMON_CARD_POOL)
	_append_unique_cards(result, _monster_card_names(1))
	return result


func _current_run_featured_cards() -> Array:
	return _monster_card_names(1)


func _current_run_featured_card_sources() -> Dictionary:
	var sources := {}
	for monster_card_variant in _monster_card_names(1):
		var skill_name := String(monster_card_variant)
		sources[skill_name] = "怪兽卡"
	return sources


func _monster_market_skills() -> Array:
	return _current_run_card_pool()


func _monster_skill_summary() -> String:
	var names := []
	for skill_name in _current_run_card_pool():
		if _is_monster_card_name(skill_name):
			names.append(skill_name)
	return " / ".join(names) if not names.is_empty() else "无"


func _skill_tag_text(skill: Dictionary) -> String:
	var tags: Array = skill.get("tags", [])
	if tags.is_empty():
		tags = _derived_skill_tags(String(skill.get("kind", "")))
	return " / ".join(tags)


func _skill_display_text(skill: Dictionary) -> String:
	var text := String(skill.get("text", "即时结算干预卡。"))
	if auto_monsters.is_empty():
		return text
	text = text.replace("除自身外，所有已装备卡牌立即+1补给。", "从当前区域额外获取1张候选卡。")
	text = text.replace("除自身外，所有已装备卡牌立即+2补给", "从当前区域额外获取2张候选卡")
	text = text.replace("补给连锁", "补给连锁")
	text = text.replace("补给", "补给")
	text = text.replace("其他怪兽概率行动", "怪兽特殊行动")
	text = text.replace("其他怪兽行动", "怪兽特殊行动")
	return text


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
		"card_access_boon":
			return ["补给", "范围"]
		"route_sabotage":
			return ["经营", "破坏"]
		"panic_shift":
			return ["市场"]
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


func _player_build_summary(player: Dictionary) -> String:
	var counts := {}
	for skill in player["slots"]:
		if skill == null:
			continue
		var tag_text := _skill_tag_text(skill)
		for tag in tag_text.split(" / "):
			if tag == "":
				continue
			counts[tag] = int(counts.get(tag, 0)) + 1
	if counts.is_empty():
		return "尚未成型"
	var chunks := []
	while chunks.size() < 3 and not counts.is_empty():
		var best_tag := ""
		var best_count := -1
		for tag in counts.keys():
			var count := int(counts[tag])
			if count > best_count:
				best_tag = String(tag)
				best_count = count
		chunks.append("%s×%d" % [best_tag, best_count])
		counts.erase(best_tag)
	return " / ".join(chunks)


func _preset_float(key: String) -> float:
	return float(REALTIME_BALANCE.get(key, 0.0))


func _preset_int(key: String) -> int:
	return int(REALTIME_BALANCE.get(key, 0))


func _roll_timer(prefix: String) -> float:
	var low: float = _preset_float("%s_min" % prefix)
	var high: float = _preset_float("%s_max" % prefix)
	return low + rng.randf_range(0.0, max(0.0, high - low))


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
	var family := _skill_family(card_name)
	var rank := maxi(1, _skill_rank(card_name))
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


func _event_target_weight_parts(index: int) -> Dictionary:
	var parts := {
		"base": 0,
		"panic": 0,
		"city": 0,
		"competition": 0,
		"trade": 0,
		"miasma": 0,
		"monster": 0,
	}
	if index < 0 or index >= districts.size():
		return parts
	var d: Dictionary = districts[index]
	if d["destroyed"]:
		return parts
	parts["base"] = EVENT_TARGET_BASE_WEIGHT
	parts["panic"] = int(d["panic"]) * EVENT_TARGET_PANIC_WEIGHT
	var city := _district_city(index)
	if _city_is_active(city):
		parts["city"] = EVENT_TARGET_CITY_BONUS + (city.get("products", []) as Array).size()
		parts["competition"] = int(city.get("competition_matches", 0)) * EVENT_TARGET_COMPETITION_WEIGHT
	parts["trade"] = _district_trade_route_load(index) * EVENT_TARGET_TRADE_WEIGHT
	if d["miasma"]:
		parts["miasma"] = EVENT_TARGET_MIASMA_BONUS
	for actor_variant in auto_monsters:
		var actor: Dictionary = actor_variant
		if bool(actor.get("down", false)):
			continue
		if int(actor.get("position", -1)) == index:
			parts["monster"] = int(parts["monster"]) + EVENT_TARGET_MONSTER_BONUS
	return parts


func _district_event_weight(index: int) -> int:
	if index < 0 or index >= districts.size():
		return 0
	var d: Dictionary = districts[index]
	if d["destroyed"]:
		return 0
	return max(1, _weight_part_total(_event_target_weight_parts(index)))


func _monster_resource_match_score(actor: Dictionary, index: int) -> int:
	if index < 0 or index >= districts.size():
		return 0
	var focus: Array = actor.get("resource_focus", [])
	if focus.is_empty():
		return 0
	var score := 0
	var district_products: Array = districts[index].get("products", [])
	var district_demands: Array = districts[index].get("demands", [])
	var city := _district_city(index)
	var city_products := _city_product_names(city) if _city_is_active(city) else []
	var city_demands := _city_demand_names(city) if _city_is_active(city) else []
	for product_variant in focus:
		var product_name := String(product_variant)
		if district_products.has(product_name):
			score += 1
		if district_demands.has(product_name):
			score += 1
		if city_products.has(product_name):
			score += 2
		if city_demands.has(product_name):
			score += 1
		for route_variant in _trade_routes_for_product(product_name):
			var route: Dictionary = route_variant
			var path: Array = route.get("path", [])
			if path.has(index):
				score += 1
	return min(score, 8)


func _district_trade_route_load(index: int) -> int:
	if index < 0 or index >= districts.size():
		return 0
	var load := 0
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		for route_variant in _city_trade_routes(city_index):
			var route: Dictionary = route_variant
			var path: Array = route.get("path", [])
			if path.has(index):
				load += 1
	return load


func _prime_timers_for_new_game() -> void:
	event_timer = max(1.0, _preset_float("event_min") * 0.75)
	special_monster_timer = max(1.0, _preset_float("special_monster_min") * 0.9)
	monster_timer = max(1.0, _preset_float("monster_min") * 0.8)
	market_timer = max(1.0, _preset_float("market_min") * 0.9)


func _select_district_card(skill_name: String) -> void:
	if selected_district < 0 or selected_district >= districts.size():
		return
	if districts[selected_district]["destroyed"]:
		_log("%s已被破坏，不能从这里获取卡牌。" % districts[selected_district]["name"])
		return
	if not _selected_district_has_card(skill_name):
		_log("%s不是当前区域的候选卡。" % _card_display_name(skill_name))
		return
	selected_market_skill = skill_name
	previewed_district_card = skill_name
	_log("选中%s的区域候选卡：%s。" % [districts[selected_district]["name"], _card_display_name(skill_name)])
	_refresh_ui()


func _claim_district_card(skill_name: String) -> void:
	if selected_district < 0 or selected_district >= districts.size():
		return
	if districts[selected_district]["destroyed"]:
		_log("%s已被破坏，不能从这里获取卡牌。" % districts[selected_district]["name"])
		_refresh_ui()
		return
	if not _can_buy_card_from_district(selected_district, selected_player):
		_log("%s暂不能购买卡牌：需要怪兽落地区/相邻区，或补给范围扩张能力。" % districts[selected_district]["name"])
		_refresh_ui()
		return
	if not _selected_district_has_card(skill_name):
		_log("%s不是当前区域的候选卡。%s" % [_card_display_name(skill_name), _card_choice_location_summary(skill_name)])
		_refresh_ui()
		return
	selected_market_skill = skill_name
	_buy_selected_skill()


func _sync_selected_market_skill() -> void:
	if selected_market_skill != "" and _skill_exists(selected_market_skill):
		return
	selected_market_skill = skill_market[0] if not skill_market.is_empty() else ""


func _selected_district_card_choices() -> Array:
	var result := []
	if selected_district < 0 or selected_district >= districts.size():
		return result
	if bool(districts[selected_district].get("destroyed", false)):
		return result
	for name_variant in districts[selected_district].get("card_choices", []):
		var name := String(name_variant)
		if _skill_exists(name):
			result.append(name)
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


func _player_card_access_effect(player_index: int) -> Dictionary:
	var effect := {
		"extra_hops": 0,
		"extended_multiplier": 1.10,
		"global": false,
		"global_multiplier": 1.35,
	}
	if player_index < 0 or player_index >= players.size():
		player_index = selected_player
	if player_index < 0 or player_index >= players.size():
		return effect
	var role := _player_role_card_for_index(player_index)
	effect["extra_hops"] = maxi(int(effect["extra_hops"]), maxi(0, int(role.get("card_access_extra_hops", 0))))
	effect["extended_multiplier"] = maxf(float(effect["extended_multiplier"]), float(role.get("extended_card_price_multiplier", effect["extended_multiplier"])))
	if bool(role.get("card_access_global", false)):
		effect["global"] = true
		effect["global_multiplier"] = maxf(float(effect["global_multiplier"]), float(role.get("global_card_price_multiplier", effect["global_multiplier"])))
	var player: Dictionary = players[player_index]
	if float(player.get("card_access_expire_time", -1.0)) > game_time:
		effect["extra_hops"] = maxi(int(effect["extra_hops"]), maxi(0, int(player.get("card_access_extra_hops", 0))))
		effect["extended_multiplier"] = maxf(float(effect["extended_multiplier"]), float(player.get("extended_card_price_multiplier", effect["extended_multiplier"])))
		if bool(player.get("card_access_global", false)):
			effect["global"] = true
			effect["global_multiplier"] = maxf(float(effect["global_multiplier"]), float(player.get("global_card_price_multiplier", effect["global_multiplier"])))
	return effect


func _player_extended_card_price_multiplier(player_index: int) -> float:
	return maxf(1.0, float(_player_card_access_effect(player_index).get("extended_multiplier", 1.10)))


func _player_global_card_price_multiplier(player_index: int) -> float:
	return maxf(1.0, float(_player_card_access_effect(player_index).get("global_multiplier", 1.35)))


func _nearest_active_monster_graph_distance(district_index: int, max_steps: int) -> int:
	if district_index < 0 or district_index >= districts.size() or max_steps < 0:
		return -1
	var frontier := []
	var seen := {}
	for actor_variant in auto_monsters:
		if not (actor_variant is Dictionary):
			continue
		var actor := actor_variant as Dictionary
		if bool(actor.get("down", false)):
			continue
		var start := int(actor.get("position", -1))
		if start < 0 or start >= districts.size():
			continue
		if start == district_index:
			return 0
		frontier.append({"index": start, "distance": 0})
		seen[start] = true
	var cursor := 0
	while cursor < frontier.size():
		var item: Dictionary = frontier[cursor]
		cursor += 1
		var current := int(item.get("index", -1))
		var distance := int(item.get("distance", 0))
		if distance >= max_steps:
			continue
		for neighbor_variant in districts[current].get("neighbors", []):
			var neighbor := int(neighbor_variant)
			if neighbor < 0 or neighbor >= districts.size() or seen.has(neighbor):
				continue
			var next_distance := distance + 1
			if neighbor == district_index:
				return next_distance
			seen[neighbor] = true
			frontier.append({"index": neighbor, "distance": next_distance})
	return -1


func _district_card_access_kind(district_index: int, player_index: int = -1) -> String:
	if district_index < 0 or district_index >= districts.size():
		return "none"
	var effect := _player_card_access_effect(player_index)
	var max_steps := 1 + maxi(0, int(effect.get("extra_hops", 0)))
	var distance := _nearest_active_monster_graph_distance(district_index, max_steps)
	if distance == 0:
		return "landed"
	if distance == 1:
		return "adjacent"
	if distance > 1:
		return "extended"
	if bool(effect.get("global", false)) and not bool(districts[district_index].get("destroyed", false)):
		return "global"
	return "none"


func _district_card_access_text(district_index: int, player_index: int = -1) -> String:
	match _district_card_access_kind(district_index, player_index):
		"landed":
			return "怪兽落地区：可购买，八折"
		"adjacent":
			return "怪兽相邻区：可购买，原价"
		"extended":
			return "远程补给区：可购买，×%.2f" % _player_extended_card_price_multiplier(player_index)
		"global":
			return "全局采购区：可购买，×%.2f" % _player_global_card_price_multiplier(player_index)
	return "不可购买：需要怪兽落地、相邻或补给范围能力"


func _can_buy_card_from_district(district_index: int, player_index: int = -1) -> bool:
	return ["landed", "adjacent", "extended", "global"].has(_district_card_access_kind(district_index, player_index))


func _selected_district_has_card(skill_name: String) -> bool:
	return _district_has_card(selected_district, skill_name)


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


func _skill_rank(skill_name: String) -> int:
	var digits := ""
	var index := skill_name.length() - 1
	while index >= 0:
		var ch := skill_name.substr(index, 1)
		if not "0123456789".contains(ch):
			break
		digits = ch + digits
		index -= 1
	if digits == "":
		return 0
	return int(digits)


func _skill_family(skill_name: String) -> String:
	var end := skill_name.length()
	while end > 0 and "0123456789".contains(skill_name.substr(end - 1, 1)):
		end -= 1
	return skill_name.substr(0, end)


func _is_upgrade_card(skill_name: String) -> bool:
	if skill_name == "" or not _skill_exists(skill_name):
		return false
	var family := _skill_family(skill_name)
	var rank := _skill_rank(skill_name)
	return rank > 1 and _skill_exists("%s%d" % [family, rank - 1])


func _can_upgrade_skill_slot(player: Dictionary, slot_index: int, target_skill_name: String) -> bool:
	if game_over or player["action_cooldown"] > 0.0:
		return false
	if target_skill_name == "" or not _is_upgrade_card(target_skill_name):
		return false
	if selected_district < 0 or selected_district >= districts.size() or districts[selected_district]["destroyed"]:
		return false
	if not _selected_district_has_card(target_skill_name):
		return false
	if slot_index < 0 or slot_index >= player["slots"].size():
		return false
	var current = player["slots"][slot_index]
	if current == null:
		return false
	var current_name := String(current["name"])
	return (
		_skill_family(current_name) == _skill_family(target_skill_name)
		and _skill_rank(target_skill_name) == _skill_rank(current_name) + 1
	)


func _can_replace_skill_slot(target_skill_name: String) -> bool:
	if game_over or selected_player < 0 or selected_player >= players.size():
		return false
	if players[selected_player]["action_cooldown"] > 0.0:
		return false
	if selected_district < 0 or selected_district >= districts.size() or districts[selected_district]["destroyed"]:
		return false
	return (
		target_skill_name != ""
		and _selected_district_has_card(target_skill_name)
		and not _is_upgrade_card(target_skill_name)
	)


func _can_selected_player_act() -> bool:
	if game_over:
		return false
	if _has_pending_target_choice():
		_log("请先完成当前卡牌的目标怪兽选择。")
		return false
	var player: Dictionary = players[selected_player]
	if player["action_cooldown"] > 0.0:
		_log("%s操作冷却中，还需%.1fs。" % [player["name"], player["action_cooldown"]])
		return false
	return true


func _card_bid_control_status_text(player_index: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return "报价状态：无当前玩家"
	var active_tip := _selected_card_tip_amount(player_index)
	var queued_index := _queued_card_entry_index_for_player(player_index)
	var next_queued_index := _next_batch_card_entry_index_for_player(player_index)
	var player: Dictionary = players[player_index]
	var cash := int(player.get("cash", 0))
	if queued_index >= 0:
		var entry: Dictionary = card_resolution_queue[queued_index]
		var skill := _queued_skill_from_entry(entry)
		var play_cash_cost := _skill_play_cash_cost(skill)
		var spare_cash := cash - play_cash_cost - active_tip
		if card_resolution_auction_open:
			if spare_cash <= 0:
				return "报价状态：候补牌参拍中｜当前¥%d｜最高¥%d｜不能加价：资金不足（需保留打出费用¥%d）" % [
					active_tip,
					_highest_card_resolution_bid(),
					play_cash_cost,
				]
			return "报价状态：候补牌参拍中｜当前¥%d｜最高¥%d｜可继续加价｜可追加预算¥%d" % [
				active_tip,
				_highest_card_resolution_bid(),
				spare_cash,
			]
		if not card_resolution_batch_locked and active_card_resolution.is_empty() and card_resolution_simultaneous_timer > 0.0:
			return "报价状态：候补牌待竞价｜当前¥%d｜不能加价：等待0.5秒同时判定｜若触发竞价可继续报价" % active_tip
		var next_suffix := "｜另有1张牌已进入下一批等待" if next_queued_index >= 0 else ""
		return "报价状态：候补牌已锁定｜当前¥%d｜不能加价：批次已封盘/展示中｜候补顺序看顶部轨道%s" % [active_tip, next_suffix]
	if next_queued_index >= 0:
		return "报价状态：下一批等待牌｜预设¥%d｜当前整批清空后统一参拍｜暂不可加价" % active_tip
	if card_resolution_batch_locked or not active_card_resolution.is_empty():
		return "报价状态：暂无候补牌｜预设¥%d｜可出新牌：进入下一批等待" % active_tip
	if not card_resolution_queue.is_empty() and card_resolution_simultaneous_timer <= 0.0:
		return "报价状态：暂无候补牌｜预设¥%d｜本批同时窗已关闭；新牌进入下一批等待" % active_tip
	if not card_resolution_queue.is_empty():
		return "报价状态：预设¥%d｜本批接收中：现在打牌会加入0.5秒同时窗" % active_tip
	return "报价状态：预设¥%d｜空闲：下一张牌会先进入0.5秒同时窗" % active_tip


func _card_bid_control_status_color(player_index: int) -> Color:
	if player_index < 0 or player_index >= players.size() or game_over:
		return Color("#94a3b8")
	var queued_index := _queued_card_entry_index_for_player(player_index)
	var next_queued_index := _next_batch_card_entry_index_for_player(player_index)
	if queued_index >= 0 and card_resolution_auction_open:
		return Color("#fde68a")
	if queued_index >= 0 or next_queued_index >= 0 or card_resolution_batch_locked or not active_card_resolution.is_empty():
		return Color("#c4b5fd")
	if not card_resolution_queue.is_empty():
		return Color("#bae6fd")
	return Color("#a7f3d0")


func _card_bid_button_tooltip(player_index: int, target_tip: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return "没有当前玩家，无法设置匿名报价。"
	var active_tip := _selected_card_tip_amount(player_index)
	if game_over:
		return "游戏已经结束，不能修改匿名报价。"
	var queued_index := _queued_card_entry_index_for_player(player_index)
	var next_queued_index := _next_batch_card_entry_index_for_player(player_index)
	if queued_index >= 0:
		if not card_resolution_auction_open:
			if not card_resolution_batch_locked and active_card_resolution.is_empty() and card_resolution_simultaneous_timer > 0.0:
				return "等待同时判定：当前候补牌报价暂不可改；若出现第二张牌并转入5秒竞价后，可以继续加价。"
			return "不能修改：批次已封盘/正在公开展示，锁定报价保持¥%d。" % active_tip
		var entry: Dictionary = card_resolution_queue[queued_index]
		var skill := _queued_skill_from_entry(entry)
		var play_cash_cost := _skill_play_cash_cost(skill)
		var cash_needed := play_cash_cost + maxi(0, target_tip)
		var cash := int((players[player_index] as Dictionary).get("cash", 0))
		if cash < cash_needed:
			return "资金不足：目标报价¥%d还需预留打出费用¥%d；当前资金¥%d。" % [
				target_tip,
				play_cash_cost,
				cash,
			]
		return "把当前候补牌匿名公开报价改为¥%d；封盘后整批按报价排序，同价按顺时针席位。" % target_tip
	if next_queued_index >= 0:
		return "下一批等待牌已经提交；它会在当前整批清空后进入统一竞价，届时才可继续加价。"
	var cash := int((players[player_index] as Dictionary).get("cash", 0))
	if cash < maxi(0, target_tip):
		return "资金不足：无法把下一张牌预设匿名报价设为¥%d；当前资金¥%d。" % [target_tip, cash]
	if target_tip <= 0:
		return "清空下一张牌的预设匿名报价；已在队列中的锁定牌不受影响。"
	return "把下一张牌预设匿名报价设为¥%d；提交卡牌时会随卡进入0.5秒同时判定窗。" % target_tip


func _selected_card_tip_amount(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	var queued_index := _queued_card_entry_index_for_player(player_index)
	if queued_index >= 0:
		return int((card_resolution_queue[queued_index] as Dictionary).get("tip", 0))
	var next_queued_index := _next_batch_card_entry_index_for_player(player_index)
	if next_queued_index >= 0:
		return int((next_card_resolution_queue[next_queued_index] as Dictionary).get("tip", 0))
	var amount := int((players[player_index] as Dictionary).get("queued_card_tip", 0))
	return max(0, amount)


func _queued_card_entry_index_for_player(player_index: int) -> int:
	for i in range(card_resolution_queue.size()):
		var entry: Dictionary = card_resolution_queue[i]
		if int(entry.get("player_index", -1)) == player_index:
			return i
	return -1


func _next_batch_card_entry_index_for_player(player_index: int) -> int:
	for i in range(next_card_resolution_queue.size()):
		var entry: Dictionary = next_card_resolution_queue[i]
		if int(entry.get("player_index", -1)) == player_index:
			return i
	return -1


func _set_selected_card_tip(amount: int) -> void:
	_set_selected_card_bid_absolute(max(0, amount))


func _increase_selected_card_bid(increment: int) -> void:
	if increment <= 0:
		return
	_set_selected_card_bid_absolute(_selected_card_tip_amount(selected_player) + increment)


func _reset_selected_card_bid() -> void:
	_set_selected_card_bid_absolute(0)


func _set_selected_card_bid_absolute(amount: int) -> void:
	_set_card_bid_for_player(selected_player, amount, true)


func _set_card_bid_for_player(player_index: int, amount: int, announce: bool = true) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var clamped: int = maxi(0, amount)
	var queued_index: int = _queued_card_entry_index_for_player(player_index)
	if queued_index >= 0:
		if not card_resolution_auction_open:
			if announce:
				_log("本轮拍卖已经封盘，锁定报价不能再修改。")
			return false
		var entry: Dictionary = card_resolution_queue[queued_index]
		var old_bid := int(entry.get("tip", 0))
		if clamped == old_bid:
			return false
		var skill: Dictionary = _queued_skill_from_entry(entry)
		var cash_needed: int = _skill_play_cash_cost(skill) + clamped
		if int(players[player_index].get("cash", 0)) < cash_needed:
			if announce:
				_log("当前视角资金不足，无法把候补卡匿名报价改为¥%d（还需预留打出费用¥%d）。" % [
					clamped,
					_skill_play_cash_cost(skill),
				])
			return false
		entry["tip"] = clamped
		entry["bid_time"] = game_time
		card_resolution_queue[queued_index] = entry
		_sort_card_resolution_queue()
		if announce:
			_log("公开报价：一张匿名候补卡把小费报价%s为¥%d；其他玩家可在展示结束前继续竞价。" % ["提高" if clamped > old_bid else "撤回", clamped])
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


func _card_resolution_status_text() -> String:
	var phase_text := _card_resolution_phase_text()
	if phase_text != "":
		return phase_text
	return "阶段：空闲｜无卡牌结算"


func _card_resolution_phase_text(entry: Dictionary = {}, seconds_left: float = -1.0) -> String:
	var queued := card_resolution_queue.size()
	var next_queued := next_card_resolution_queue.size()
	if card_resolution_auction_open:
		var auction_intake := "本批0.5秒窗内可加入" if card_resolution_simultaneous_timer > 0.0 else "进入下一批等待"
		return "阶段：匿名竞价｜剩余%.1fs｜参拍%d｜最高公开报价¥%d｜可加价：是｜新牌：%s｜下批等待%d" % [
			max(0.0, card_resolution_auction_timer),
			queued,
			_highest_card_resolution_bid(),
			auction_intake,
			next_queued,
		]
	if not card_resolution_batch_locked and queued > 0:
		return "阶段：同时判定｜剩余%.1fs｜待定%d｜最高公开报价¥%d｜可加价：预设｜新牌：0.5秒内可加入" % [
			max(0.0, card_resolution_simultaneous_timer),
			queued,
			_highest_card_resolution_bid(),
		]
	var active_entry := entry
	if active_entry.is_empty() and not active_card_resolution.is_empty():
		active_entry = active_card_resolution
	if not active_entry.is_empty():
		var skill: Dictionary = active_entry.get("skill", {}) as Dictionary
		var label := _card_display_name(String(skill.get("name", "卡牌")))
		if label == "":
			label = "匿名卡牌"
		var remaining := seconds_left if seconds_left >= 0.0 else card_resolution_timer
		return "阶段：公开展示｜%s｜剩余%.1fs｜锁定候补%d｜可加价：否｜新牌：进入下一批等待｜下批等待%d｜出牌者%s" % [
			label,
			max(0.0, remaining),
			queued,
			next_queued,
			"已揭晓" if bool(active_entry.get("public_owner_revealed", false)) else "未知",
		]
	if queued > 0:
		return "阶段：批次锁定｜锁定候补%d｜可加价：否｜新牌：进入下一批等待｜下批等待%d" % [queued, next_queued]
	return ""


func _start_player_cooldown(seconds: float) -> void:
	players[selected_player]["action_cooldown"] = max(players[selected_player]["action_cooldown"], seconds)


func _find_owned_card_slot(player: Dictionary, skill_name: String) -> int:
	for i in range(player["slots"].size()):
		var skill = player["slots"][i]
		if skill == null:
			continue
		if String(skill.get("name", "")) == skill_name:
			return i
	return -1


func _find_previous_rank_card_slot(player: Dictionary, skill_name: String) -> int:
	var rank := _skill_rank(skill_name)
	if rank <= 1:
		return -1
	var family := _skill_family(skill_name)
	for i in range(player["slots"].size()):
		var skill = player["slots"][i]
		if skill == null:
			continue
		var current_name := String(skill.get("name", ""))
		if _skill_family(current_name) == family and _skill_rank(current_name) == rank - 1:
			return i
	return -1


func _next_upgrade_name(skill_name: String) -> String:
	if skill_name == "" or not _skill_exists(skill_name):
		return ""
	var family := _skill_family(skill_name)
	var rank := _skill_rank(skill_name)
	if rank <= 0 or rank >= 4:
		return ""
	var next_name := "%s%d" % [family, rank + 1]
	return next_name if _skill_exists(next_name) else ""


func _find_highest_family_card_slot(player: Dictionary, skill_name: String) -> int:
	var family := _skill_family(skill_name)
	var best_slot := -1
	var best_rank := -1
	for i in range(player["slots"].size()):
		var skill = player["slots"][i]
		if skill == null:
			continue
		var current_name := String(skill.get("name", ""))
		if _skill_family(current_name) != family:
			continue
		var rank := maxi(1, _skill_rank(current_name))
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
	return String(skill.get("kind", "")) == "monster_bound_action" and bool(skill.get("persistent", false))


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


func _player_can_add_counted_card(player: Dictionary) -> bool:
	return _player_counted_hand_size(player) < PLAYER_HAND_LIMIT


func _first_empty_or_new_counted_slot(player: Dictionary) -> int:
	if not _player_can_add_counted_card(player):
		return -1
	return _first_empty_or_new_slot(player)


func _player_can_receive_card(player: Dictionary, skill_name: String) -> bool:
	skill_name = _canonical_card_supply_name(skill_name)
	if skill_name == "" or not _skill_exists(skill_name):
		return false
	var family_slot := _find_highest_family_card_slot(player, skill_name)
	if family_slot >= 0:
		var current_skill: Dictionary = player["slots"][family_slot]
		return _next_upgrade_name(String(current_skill.get("name", skill_name))) != ""
	if _find_previous_rank_card_slot(player, skill_name) >= 0:
		return true
	var skill := _make_skill(skill_name)
	if _is_hand_limit_exempt_skill(skill):
		return true
	return _player_can_add_counted_card(player)


func _acquire_card_for_player(player: Dictionary, skill_name: String, district_index: int, source: String, anonymous: bool = false) -> bool:
	skill_name = _canonical_card_supply_name(skill_name)
	if skill_name == "" or not _skill_exists(skill_name):
		return false
	var actor_label := "匿名出牌者" if anonymous else String(player.get("name", "玩家"))
	var family_slot := _find_highest_family_card_slot(player, skill_name)
	if family_slot >= 0:
		var current_skill: Dictionary = player["slots"][family_slot]
		var current_name := String(current_skill.get("name", skill_name))
		var next_name := _next_upgrade_name(current_name)
		if next_name == "":
			_log("%s已经拥有最高阶%s，无法继续升级。" % [actor_label, _card_display_name(current_name)])
			return false
		player["slots"][family_slot] = _make_skill(next_name)
		_log("%s在%s重新获得%s系列卡，自动升级为%s。" % [
			actor_label,
			districts[district_index]["name"] if district_index >= 0 and district_index < districts.size() else source,
			_skill_family(skill_name),
			_card_display_name(next_name),
		])
		return true
	var previous_slot := _find_previous_rank_card_slot(player, skill_name)
	if previous_slot >= 0:
		var old_skill: Dictionary = player["slots"][previous_slot]
		var old_name := String(old_skill.get("name", ""))
		player["slots"][previous_slot] = _make_skill(skill_name)
		_log("%s获得%s，将%s升级为%s。" % [
			actor_label,
			_card_display_name(skill_name),
			_card_display_name(old_name),
			_card_display_name(skill_name),
		])
		return true
	var new_skill := _make_skill(skill_name)
	var empty_index := _first_empty_or_new_slot(player) if _is_hand_limit_exempt_skill(new_skill) else _first_empty_or_new_counted_slot(player)
	if empty_index < 0:
		_log("%s手牌已达%d张上限；绑定固定怪兽技能不计入上限，但普通卡牌需要先打出或合成。" % [actor_label, PLAYER_HAND_LIMIT])
		return false
	player["slots"][empty_index] = new_skill
	_log("%s从%s获得一次性卡牌：%s。" % [
		actor_label,
		districts[district_index]["name"] if district_index >= 0 and district_index < districts.size() else source,
		_card_display_name(skill_name),
	])
	return true


func _boost_selected_city_revenue(amount: int, panic_amount: int, source: String) -> bool:
	var city := _district_city(selected_district)
	if not _city_is_active(city):
		_log("%s需要选中一座存活的己方城市。" % source)
		return false
	if int(city.get("owner", -1)) != selected_player:
		_log("%s只能投入己方城市；对手城市的真实归属不会因此揭示。" % source)
		return false
	city["revenue_bonus"] = int(city.get("revenue_bonus", 0)) + amount
	districts[selected_district]["city"] = city
	if panic_amount > 0:
		_add_panic(selected_district, panic_amount, source)
	_pulse_district(selected_district, Color("#facc15"))
	_log("%s使%s的周期收入永久+%d。" % [source, districts[selected_district]["name"], amount])
	return true


func _apply_city_gdp_derivative(_player: Dictionary, skill: Dictionary) -> bool:
	var source := String(skill.get("name", "城市GDP合约"))
	var city := _district_city(selected_district)
	if not _city_is_active(city):
		_log("%s需要选中一座存活城市；买涨/买跌不要求知道真实业主。" % source)
		return false
	var direction := String(skill.get("gdp_bet_direction", "up"))
	if not ["up", "down"].has(direction):
		return false
	var baseline := _city_cycle_income(selected_district, _city_competition_matches(selected_district))
	var derivatives: Array = city.get("gdp_derivatives", [])
	derivatives.append({
		"owner": selected_player,
		"direction": direction,
		"baseline_gdp": baseline,
		"turns": maxi(1, int(skill.get("gdp_bet_turns", 2))),
		"multiplier": maxf(0.1, float(skill.get("gdp_bet_multiplier", 1.0))),
		"destroy_bonus": maxi(0, int(skill.get("gdp_bet_destroy_bonus", 0))),
		"source": source,
		"created_cycle": business_cycle_count,
	})
	city["gdp_derivatives"] = derivatives
	city = _append_city_public_clue(city, "%s匿名买%s%sGDP，基准%d，持续%d周期。" % [
		source,
		"涨" if direction == "up" else "跌",
		districts[selected_district]["name"],
		baseline,
		maxi(1, int(skill.get("gdp_bet_turns", 2))),
	])
	districts[selected_district]["city"] = city
	_pulse_district(selected_district, Color("#f97316") if direction == "down" else Color("#22c55e"))
	_add_action_callout(
		"匿名金融",
		source,
		"%s被挂上%s合约：GDP%s时结算，出牌者不公开。" % [
			districts[selected_district]["name"],
			"买涨" if direction == "up" else "做空",
			"上涨" if direction == "up" else "下跌/破产",
		],
		Color("#22c55e") if direction == "up" else Color("#fb7185"),
		_district_center(selected_district)
	)
	_log("%s匿名挂单%s：基准GDP%d，持续%d周期，倍率×%.2f。" % [
		source,
		districts[selected_district]["name"],
		baseline,
		maxi(1, int(skill.get("gdp_bet_turns", 2))),
		maxf(0.1, float(skill.get("gdp_bet_multiplier", 1.0))),
	])
	return true


func _pay_city_gdp_derivative(owner: int, amount: int, source: String, detail: String) -> void:
	if owner < 0 or owner >= players.size() or amount <= 0:
		return
	players[owner]["cash"] = int(players[owner].get("cash", 0)) + amount
	_record_player_card_income(owner, amount, source, detail)


func _resolve_city_gdp_derivatives(district_index: int, current_gdp: int, source: String = "经营周期") -> void:
	if district_index < 0 or district_index >= districts.size():
		return
	var city := _district_city(district_index)
	var derivatives: Array = city.get("gdp_derivatives", [])
	if derivatives.is_empty():
		return
	var remaining := []
	var public_hits := 0
	for entry_variant in derivatives:
		var entry: Dictionary = entry_variant
		var baseline := int(entry.get("baseline_gdp", current_gdp))
		var direction := String(entry.get("direction", "up"))
		var delta := current_gdp - baseline
		var paying_delta: int = maxi(0, delta) if direction == "up" else maxi(0, -delta)
		var payout := int(round(float(paying_delta) * maxf(0.1, float(entry.get("multiplier", 1.0)))))
		if payout > 0:
			public_hits += 1
			_pay_city_gdp_derivative(int(entry.get("owner", -1)), payout, String(entry.get("source", "城市GDP合约")), "%s %sGDP%d→%d" % [districts[district_index]["name"], source, baseline, current_gdp])
		entry["baseline_gdp"] = current_gdp
		entry["turns"] = int(entry.get("turns", 1)) - 1
		if int(entry.get("turns", 0)) > 0:
			remaining.append(entry)
	city["gdp_derivatives"] = remaining
	if public_hits > 0:
		city = _append_city_public_clue(city, "%s的GDP衍生合约因%s兑现%d笔；资金流向不公开。" % [districts[district_index]["name"], source, public_hits])
	districts[district_index]["city"] = city


func _resolve_city_gdp_derivatives_on_destroy(district_index: int, city: Dictionary, source: String) -> Dictionary:
	var derivatives: Array = city.get("gdp_derivatives", [])
	if derivatives.is_empty():
		return city
	var public_hits := 0
	for entry_variant in derivatives:
		var entry: Dictionary = entry_variant
		if String(entry.get("direction", "up")) != "down":
			continue
		var baseline := int(entry.get("baseline_gdp", 0))
		var drop_payout := int(round(float(maxi(0, baseline)) * maxf(0.1, float(entry.get("multiplier", 1.0)))))
		var payout := drop_payout + maxi(0, int(entry.get("destroy_bonus", 0)))
		if payout <= 0:
			continue
		public_hits += 1
		_pay_city_gdp_derivative(int(entry.get("owner", -1)), payout, String(entry.get("source", "城市做空")), "%s被%s摧毁，GDP%d→0" % [districts[district_index]["name"], source, baseline])
	if public_hits > 0:
		city = _append_city_public_clue(city, "%s被摧毁，城市做空/破产合约兑现%d笔；谁收钱仍需推理。" % [districts[district_index]["name"], public_hits])
	city["gdp_derivatives"] = []
	return city


func _default_economy_product() -> String:
	if selected_trade_product != "" and PRODUCT_CATALOG.has(selected_trade_product):
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
	if PRODUCT_CATALOG.is_empty():
		return ""
	return String(PRODUCT_CATALOG[0])


func _merge_boon_source(existing: String, source: String) -> String:
	if source == "":
		return existing
	if existing == "":
		return source
	if existing.contains(source):
		return existing
	return "%s、%s" % [existing, source]


func _product_market_entry(product_name: String) -> Dictionary:
	_ensure_product_market_catalog()
	var entry: Dictionary = product_market.get(product_name, {})
	if entry.is_empty():
		return {}
	_normalize_product_market_boon_fields(entry)
	product_market[product_name] = entry
	return entry


func _apply_product_market_boon(product_name: String, growth_multiplier: float, route_flow_multiplier: float, turns: int, source: String, persistent: bool = false) -> bool:
	if product_name == "" or not PRODUCT_CATALOG.has(product_name):
		return false
	var entry := _product_market_entry(product_name)
	if entry.is_empty():
		return false
	var changed := false
	var safe_turns: int = maxi(0, turns)
	if growth_multiplier > 1.0:
		var growth_value: float = clampf(growth_multiplier, 1.0, PRODUCT_GROWTH_MULTIPLIER_MAX)
		if persistent:
			if growth_value > float(entry.get("base_growth_multiplier", 1.0)):
				entry["base_growth_multiplier"] = growth_value
				entry["base_growth_source"] = _merge_boon_source(String(entry.get("base_growth_source", "")), source)
				changed = true
		else:
			entry["growth_turns"] = maxi(int(entry.get("growth_turns", 0)), safe_turns)
		if growth_value > float(entry.get("growth_multiplier", 1.0)) or persistent:
			entry["growth_multiplier"] = maxf(float(entry.get("growth_multiplier", 1.0)), growth_value)
			entry["growth_source"] = _merge_boon_source(String(entry.get("growth_source", "")), source)
			changed = true
	if route_flow_multiplier > 1.0:
		var flow_value: float = clampf(route_flow_multiplier, 1.0, ROUTE_FLOW_MULTIPLIER_MAX)
		if persistent:
			if flow_value > float(entry.get("base_route_flow_multiplier", 1.0)):
				entry["base_route_flow_multiplier"] = flow_value
				entry["base_route_flow_source"] = _merge_boon_source(String(entry.get("base_route_flow_source", "")), source)
				changed = true
		else:
			entry["route_flow_turns"] = maxi(int(entry.get("route_flow_turns", 0)), safe_turns)
		if flow_value > float(entry.get("route_flow_multiplier", 1.0)) or persistent:
			entry["route_flow_multiplier"] = maxf(float(entry.get("route_flow_multiplier", 1.0)), flow_value)
			entry["route_flow_source"] = _merge_boon_source(String(entry.get("route_flow_source", "")), source)
			changed = true
	product_market[product_name] = entry
	return changed


func _product_route_flow_multiplier(product_name: String) -> float:
	var entry := _product_market_entry(product_name)
	if entry.is_empty():
		return 1.0
	return clampf(float(entry.get("route_flow_multiplier", 1.0)), 1.0, ROUTE_FLOW_MULTIPLIER_MAX)


func _city_route_flow_multiplier(city: Dictionary, product_name: String) -> float:
	var city_multiplier: float = clampf(float(city.get("route_flow_multiplier", 1.0)), 1.0, ROUTE_FLOW_MULTIPLIER_MAX)
	return clampf(city_multiplier * _product_route_flow_multiplier(product_name), 1.0, ROUTE_FLOW_MULTIPLIER_MAX)


func _boon_turn_text(turns: int) -> String:
	if turns > 0:
		return "%d周期" % turns
	return "本局持续"


func _product_market_boon_text(product_name: String) -> String:
	var entry := _product_market_entry(product_name)
	if entry.is_empty():
		return "无"
	var pieces := []
	var growth_multiplier: float = float(entry.get("growth_multiplier", 1.0))
	if growth_multiplier > 1.001:
		var growth_source := String(entry.get("growth_source", entry.get("base_growth_source", "")))
		var growth_source_suffix := "｜%s" % growth_source if growth_source != "" else ""
		pieces.append("增速×%.2f（%s%s）" % [
			growth_multiplier,
			_boon_turn_text(int(entry.get("growth_turns", 0))),
			growth_source_suffix,
		])
	var route_multiplier: float = float(entry.get("route_flow_multiplier", 1.0))
	if route_multiplier > 1.001:
		var route_source := String(entry.get("route_flow_source", entry.get("base_route_flow_source", "")))
		var route_source_suffix := "｜%s" % route_source if route_source != "" else ""
		pieces.append("流通×%.2f（%s%s）" % [
			route_multiplier,
			_boon_turn_text(int(entry.get("route_flow_turns", 0))),
			route_source_suffix,
		])
	var contract_turns := int(entry.get("market_contract_turns", 0))
	var contract_demand := int(entry.get("market_contract_demand", 0))
	var contract_supply := int(entry.get("market_contract_supply", 0))
	if contract_turns > 0 and (contract_demand > 0 or contract_supply > 0):
		var contract_source := String(entry.get("market_contract_source", ""))
		var contract_source_suffix := "｜%s" % contract_source if contract_source != "" else ""
		var pressure_parts := []
		if contract_demand > 0:
			pressure_parts.append("需+%d" % contract_demand)
		if contract_supply > 0:
			pressure_parts.append("供+%d" % contract_supply)
		pieces.append("商品合约%s（%s%s）" % [
			"/".join(pressure_parts),
			_boon_turn_text(contract_turns),
			contract_source_suffix,
		])
	if pieces.is_empty():
		return "无"
	return "；".join(pieces)


func _city_route_flow_status_text(city: Dictionary) -> String:
	var multiplier: float = float(city.get("route_flow_multiplier", 1.0))
	if multiplier <= 1.001:
		return "无"
	var source := String(city.get("route_flow_source", ""))
	var source_suffix := "｜%s" % source if source != "" else ""
	return "×%.2f（%s%s）" % [multiplier, _boon_turn_text(int(city.get("route_flow_turns", 0))), source_suffix]


func _city_contract_status_text(city: Dictionary) -> String:
	var contract_income := int(city.get("contract_income_bonus", 0))
	if contract_income <= 0:
		return "无"
	var source := String(city.get("contract_source", ""))
	var source_suffix := "｜%s" % source if source != "" else ""
	return "+%d/周期（%s%s）" % [
		contract_income,
		_boon_turn_text(int(city.get("contract_turns", 0))),
		source_suffix,
	]


func _apply_monster_economic_boons() -> void:
	if auto_monsters.is_empty():
		return
	var summaries := []
	for actor_variant in auto_monsters:
		var actor: Dictionary = actor_variant
		var catalog_index := int(actor.get("catalog_index", 0))
		var entry := _catalog_entry(catalog_index)
		var boon: Dictionary = entry.get("economy_boon", {})
		if boon.is_empty():
			continue
		var resource_focus: Array = entry.get("resource_focus", [])
		if resource_focus.is_empty():
			continue
		var label := String(boon.get("label", String(entry.get("name", "怪兽"))))
		var growth_multiplier: float = float(boon.get("growth_multiplier", 1.0))
		var route_flow_multiplier: float = float(boon.get("route_flow_multiplier", 1.0))
		var applied_products := []
		for product_variant in resource_focus:
			var product_name := String(product_variant)
			if _apply_product_market_boon(product_name, growth_multiplier, route_flow_multiplier, 0, label, true):
				applied_products.append(product_name)
		if applied_products.is_empty():
			continue
		var summary := "%s→%s" % [String(entry.get("name", "怪兽")), _limited_name_list(applied_products, 3)]
		summaries.append(summary)
		_add_action_callout(
			String(entry.get("name", "怪兽")),
			"经济天气",
			"%s：%s" % [label, _compact_card_list(applied_products, 3)],
			_auto_monster_color(int(actor.get("slot", 0))),
			_entity_world_position(actor),
			CARD_INGRESS_CALLOUT_DURATION
		)
	if not summaries.is_empty():
		_log("怪兽经济天气启动：%s。" % "；".join(summaries))


func _age_economic_boons() -> void:
	var changed := false
	for product_variant in product_market.keys():
		var product_name := String(product_variant)
		var entry := _product_market_entry(product_name)
		if entry.is_empty():
			continue
		var growth_turns := int(entry.get("growth_turns", 0))
		if growth_turns > 0:
			growth_turns -= 1
			entry["growth_turns"] = growth_turns
			if growth_turns <= 0:
				entry["growth_multiplier"] = float(entry.get("base_growth_multiplier", 1.0))
				entry["growth_source"] = String(entry.get("base_growth_source", ""))
				changed = true
		var route_turns := int(entry.get("route_flow_turns", 0))
		if route_turns > 0:
			route_turns -= 1
			entry["route_flow_turns"] = route_turns
			if route_turns <= 0:
				entry["route_flow_multiplier"] = float(entry.get("base_route_flow_multiplier", 1.0))
				entry["route_flow_source"] = String(entry.get("base_route_flow_source", ""))
				changed = true
		var market_contract_turns := int(entry.get("market_contract_turns", 0))
		if market_contract_turns > 0:
			market_contract_turns -= 1
			entry["market_contract_turns"] = market_contract_turns
			if market_contract_turns <= 0:
				entry["market_contract_demand"] = 0
				entry["market_contract_supply"] = 0
				entry["market_contract_source"] = ""
				changed = true
		product_market[product_name] = entry
	for index_variant in _active_city_district_indices():
		var index := int(index_variant)
		var city := _district_city(index)
		var turns := int(city.get("route_flow_turns", 0))
		if turns > 0:
			turns -= 1
			city["route_flow_turns"] = turns
			if turns <= 0:
				city["route_flow_multiplier"] = 1.0
				city["route_flow_source"] = ""
				changed = true
		var contract_turns := int(city.get("contract_turns", 0))
		if contract_turns > 0:
			contract_turns -= 1
			city["contract_turns"] = contract_turns
			if contract_turns <= 0:
				city["contract_income_bonus"] = 0
				city["contract_source"] = ""
				changed = true
		districts[index]["city"] = city
	if changed:
		_refresh_city_networks()


func _apply_product_speculation(player: Dictionary, skill: Dictionary) -> bool:
	var product_name := _default_economy_product()
	if product_name == "":
		_log("%s没有可操盘商品。" % String(skill.get("name", "商品牌")))
		return false
	_ensure_product_market_catalog()
	var entry: Dictionary = product_market.get(product_name, {})
	var before_price := _product_price(product_name)
	var price_delta := int(skill.get("price_delta", 0))
	var pressure := maxi(1, int(ceil(abs(float(price_delta)) / 10.0)))
	if price_delta >= 0:
		entry["temporary_demand_pressure"] = int(entry.get("temporary_demand_pressure", 0)) + pressure
	else:
		entry["temporary_supply_pressure"] = int(entry.get("temporary_supply_pressure", 0)) + pressure
	product_market[product_name] = entry
	selected_trade_product = product_name
	var cash_gain := int(skill.get("cash", 0))
	if cash_gain > 0:
		player["cash"] = int(player.get("cash", 0)) + cash_gain
		_record_player_card_income(selected_player, cash_gain, String(skill.get("name", "商品操盘")), product_name)
	var panic_gain := int(skill.get("panic", 0))
	if panic_gain > 0 and selected_district >= 0 and selected_district < districts.size():
		_add_panic(selected_district, panic_gain, String(skill.get("name", "商品操盘")))
	var operation := "拉升" if price_delta >= 0 else "做空"
	_refresh_product_market_prices()
	var after_price := _product_price(product_name)
	_log("匿名卡牌围绕%s完成%s：制造%d点%s压力，市场按供需重算¥%d→¥%d；收益归属不公开（¥%d）。" % [
		product_name,
		operation,
		pressure,
		"需求" if price_delta >= 0 else "供给",
		before_price,
		after_price,
		cash_gain,
	])
	return true


func _apply_product_contract_boon(player: Dictionary, skill: Dictionary) -> bool:
	var source := String(skill.get("name", "商品合约"))
	var product_name := _default_economy_product()
	if product_name == "":
		_log("%s没有可签约商品。" % source)
		return false
	var entry := _product_market_entry(product_name)
	if entry.is_empty():
		_log("%s没有可签约商品。" % source)
		return false
	var before_price := _product_price(product_name)
	var before_demand := int(entry.get("market_contract_demand", 0))
	var before_supply := int(entry.get("market_contract_supply", 0))
	var before_turns := int(entry.get("market_contract_turns", 0))
	var before_volatility := int(entry.get("volatility", 4))
	var demand_pressure: int = maxi(0, int(skill.get("market_demand_pressure", 0)))
	var supply_pressure: int = maxi(0, int(skill.get("market_supply_pressure", 0)))
	var turns: int = maxi(1, int(skill.get("market_contract_turns", skill.get("growth_turns", 1))))
	var changed := false
	if demand_pressure > 0 or supply_pressure > 0:
		entry["market_contract_demand"] = maxi(before_demand, demand_pressure)
		entry["market_contract_supply"] = maxi(before_supply, supply_pressure)
		entry["market_contract_turns"] = maxi(before_turns, turns)
		entry["market_contract_source"] = _merge_boon_source(String(entry.get("market_contract_source", "")), source)
		changed = int(entry.get("market_contract_demand", 0)) > before_demand or int(entry.get("market_contract_supply", 0)) > before_supply or int(entry.get("market_contract_turns", 0)) > before_turns
	var volatility_delta := int(skill.get("volatility_delta", 0))
	if volatility_delta != 0:
		var after_volatility := clampi(before_volatility + volatility_delta, PRODUCT_VOLATILITY_MIN, PRODUCT_VOLATILITY_MAX)
		entry["volatility"] = after_volatility
		changed = changed or after_volatility != before_volatility
	product_market[product_name] = entry
	var route_flow_multiplier: float = float(skill.get("route_flow_multiplier", 1.0))
	var growth_multiplier: float = float(skill.get("growth_multiplier", 1.0))
	var flow_turns: int = maxi(turns, int(skill.get("route_flow_turns", turns)))
	if route_flow_multiplier > 1.001 or growth_multiplier > 1.001:
		changed = _apply_product_market_boon(product_name, growth_multiplier, route_flow_multiplier, flow_turns, source, false) or changed
	var cash_gain := int(skill.get("cash", 0))
	if cash_gain > 0:
		player["cash"] = int(player.get("cash", 0)) + cash_gain
		_record_player_card_income(selected_player, cash_gain, source, product_name)
		changed = true
	if not changed:
		_log("%s没有超过%s当前已有的商品合约。" % [source, product_name])
		return false
	selected_trade_product = product_name
	_refresh_product_market_prices()
	var after_price := _product_price(product_name)
	if selected_district >= 0 and selected_district < districts.size():
		_pulse_district(selected_district, Color("#f59e0b"))
	_add_action_callout(
		"商品合约",
		source,
		"%s：%s，¥%d→¥%d。" % [product_name, _product_market_boon_text(product_name), before_price, after_price],
		Color("#f59e0b"),
		_economy_effect_callout_position()
	)
	_log("%s签下%s商品合约：%s，价格¥%d→¥%d，波动%d→%d，获得¥%d。" % [
		source,
		product_name,
		_product_market_boon_text(product_name),
		before_price,
		after_price,
		before_volatility,
		int((_product_market_entry(product_name)).get("volatility", before_volatility)),
		maxi(0, cash_gain),
	])
	return true


func _make_city_product_entry(product_name: String) -> Dictionary:
	return {
		"name": product_name,
		"level": 1,
		"base_price": _product_price(product_name),
		"tier": _product_tier(product_name),
	}


func _district_product_names(index: int) -> Array:
	if index < 0 or index >= districts.size():
		return []
	var result := []
	for product_variant in districts[index].get("products", []):
		_append_unique_string(result, String(product_variant))
	return result


func _district_demand_names(index: int) -> Array:
	if index < 0 or index >= districts.size():
		return []
	var result := []
	for demand_variant in districts[index].get("demands", []):
		_append_unique_string(result, String(demand_variant))
	return result


func _contract_limited_products(products: Array, count: int) -> Array:
	var result := []
	for product_variant in products:
		if result.size() >= count:
			break
		_append_unique_string(result, String(product_variant))
	return result


func _add_district_products(index: int, products: Array, limit: int) -> Array:
	var added := []
	if index < 0 or index >= districts.size() or limit <= 0:
		return added
	var current: Array = districts[index].get("products", [])
	for product_variant in products:
		if added.size() >= limit:
			break
		var product_name := String(product_variant)
		if product_name == "" or current.has(product_name):
			continue
		current.append(product_name)
		added.append(product_name)
	districts[index]["products"] = current
	return added


func _add_district_demands(index: int, products: Array, limit: int) -> Array:
	var added := []
	if index < 0 or index >= districts.size() or limit <= 0:
		return added
	var current: Array = districts[index].get("demands", [])
	for product_variant in products:
		if added.size() >= limit:
			break
		var product_name := String(product_variant)
		if product_name == "" or current.has(product_name):
			continue
		current.append(product_name)
		added.append(product_name)
	districts[index]["demands"] = current
	return added


func _add_city_products_to_city(city: Dictionary, products: Array, limit: int) -> Array:
	var added := []
	if not _city_is_active(city) or limit <= 0:
		return added
	var entries: Array = city.get("products", [])
	var existing := _city_product_names(city)
	for product_variant in products:
		if added.size() >= limit:
			break
		var product_name := String(product_variant)
		if product_name == "" or existing.has(product_name):
			continue
		entries.append(_make_city_product_entry(product_name))
		existing.append(product_name)
		added.append(product_name)
	city["products"] = entries
	return added


func _add_city_demands_to_city(city: Dictionary, products: Array, limit: int) -> Array:
	var added := []
	if not _city_is_active(city) or limit <= 0:
		return added
	var demands: Array = city.get("demands", [])
	for product_variant in products:
		if added.size() >= limit:
			break
		var product_name := String(product_variant)
		if product_name == "" or demands.has(product_name):
			continue
		demands.append(product_name)
		added.append(product_name)
	city["demands"] = demands
	return added


func _remove_district_products(index: int, count: int, protected_products: Array) -> Array:
	var removed := []
	if index < 0 or index >= districts.size() or count <= 0:
		return removed
	var current: Array = districts[index].get("products", [])
	for i in range(current.size() - 1, -1, -1):
		if removed.size() >= count:
			break
		var product_name := String(current[i])
		if protected_products.has(product_name):
			continue
		removed.append(product_name)
		current.remove_at(i)
	districts[index]["products"] = current
	return removed


func _remove_district_demands(index: int, count: int, protected_products: Array) -> Array:
	var removed := []
	if index < 0 or index >= districts.size() or count <= 0:
		return removed
	var current: Array = districts[index].get("demands", [])
	for i in range(current.size() - 1, -1, -1):
		if removed.size() >= count:
			break
		var product_name := String(current[i])
		if protected_products.has(product_name):
			continue
		removed.append(product_name)
		current.remove_at(i)
	districts[index]["demands"] = current
	return removed


func _remove_city_products_from_city(city: Dictionary, count: int, protected_products: Array) -> Array:
	var removed := []
	if not _city_is_active(city) or count <= 0:
		return removed
	var entries: Array = city.get("products", [])
	for i in range(entries.size() - 1, -1, -1):
		if removed.size() >= count:
			break
		var entry: Dictionary = entries[i]
		var product_name := String(entry.get("name", ""))
		if protected_products.has(product_name):
			continue
		removed.append(product_name)
		entries.remove_at(i)
	city["products"] = entries
	return removed


func _remove_city_demands_from_city(city: Dictionary, count: int, protected_products: Array) -> Array:
	var removed := []
	if not _city_is_active(city) or count <= 0:
		return removed
	var demands: Array = city.get("demands", [])
	for i in range(demands.size() - 1, -1, -1):
		if removed.size() >= count:
			break
		var product_name := String(demands[i])
		if protected_products.has(product_name):
			continue
		removed.append(product_name)
		demands.remove_at(i)
	city["demands"] = demands
	return removed


func _apply_contract_region_delta(index: int, production_delta: int, transport_delta: int, consumption_delta: int, source: String) -> Dictionary:
	var result := {
		"changed": false,
		"before_production": 0,
		"after_production": 0,
		"before_transport": 0,
		"after_transport": 0,
		"before_consumption": 0,
		"after_consumption": 0,
	}
	if index < 0 or index >= districts.size():
		return result
	var district: Dictionary = districts[index]
	var before_production := clampi(int(district.get("production_level", 2)), REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var before_transport := clampi(int(district.get("transport_level", 2)), REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var before_consumption := clampi(int(district.get("consumption_level", 2)), REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var after_production := clampi(before_production + production_delta, REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var after_transport := clampi(before_transport + transport_delta, REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var after_consumption := clampi(before_consumption + consumption_delta, REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	district["production_level"] = after_production
	district["transport_level"] = after_transport
	district["consumption_level"] = after_consumption
	district["transport_score"] = _transport_score_from_level(after_transport, String(district.get("terrain", "land")) == "ocean")
	district["economic_focus_label"] = _district_economy_focus_label(String(district.get("economic_focus", "balanced")))
	var city := district.get("city", {}) as Dictionary
	if _city_is_active(city):
		city = _append_city_public_clue(city, "%s使区域经营参数变化：生产%d→%d、交通%d→%d、消费%d→%d。" % [
			source,
			before_production,
			after_production,
			before_transport,
			after_transport,
			before_consumption,
			after_consumption,
		])
		district["city"] = city
	districts[index] = district
	result["changed"] = before_production != after_production or before_transport != after_transport or before_consumption != after_consumption
	result["before_production"] = before_production
	result["after_production"] = after_production
	result["before_transport"] = before_transport
	result["after_transport"] = after_transport
	result["before_consumption"] = before_consumption
	result["after_consumption"] = after_consumption
	return result


func _grant_contract_cash(player_index: int, amount: int, label: String, detail: String) -> int:
	if player_index < 0 or player_index >= players.size() or amount <= 0:
		return 0
	players[player_index]["cash"] = int(players[player_index].get("cash", 0)) + amount
	_record_player_card_income(player_index, amount, label, detail)
	return amount


func _pay_contract_penalty(player_index: int, amount: int, label: String, detail: String) -> int:
	if player_index < 0 or player_index >= players.size() or amount <= 0:
		return 0
	var paid := mini(amount, int(players[player_index].get("cash", 0)))
	if paid <= 0:
		return 0
	players[player_index]["cash"] = int(players[player_index].get("cash", 0)) - paid
	_record_player_card_spend(player_index, paid, label, detail)
	return paid


func _apply_contract_accept_route_flow(target_index: int, skill: Dictionary, source: String) -> bool:
	if target_index < 0 or target_index >= districts.size():
		return false
	var city := _district_city(target_index)
	if not _city_is_active(city):
		return false
	var before_flow := float(city.get("route_flow_multiplier", 1.0))
	var before_turns := int(city.get("route_flow_turns", 0))
	var flow_multiplier := clampf(float(skill.get("accept_route_flow_multiplier", skill.get("route_flow_multiplier", 1.0))), 1.0, ROUTE_FLOW_MULTIPLIER_MAX)
	if flow_multiplier <= 1.001:
		return false
	var flow_turns := maxi(1, int(skill.get("route_flow_turns", 1)))
	city["route_flow_multiplier"] = maxf(before_flow, flow_multiplier)
	city["route_flow_turns"] = maxi(before_turns, flow_turns)
	city["route_flow_source"] = _merge_boon_source(String(city.get("route_flow_source", "")), source)
	districts[target_index]["city"] = city
	return float(city.get("route_flow_multiplier", 1.0)) > before_flow + 0.001 or int(city.get("route_flow_turns", 0)) > before_turns


func _enqueue_pending_area_trade_contract(skill: Dictionary, entry: Dictionary) -> bool:
	var source_index := int(entry.get("contract_source_district", -1))
	var target_index := int(entry.get("contract_target_district", -1))
	if not _valid_contract_source_district(source_index) or not _valid_contract_target_district(target_index):
		_log("%s展示结束时合约区域已经失效。" % String(skill.get("name", "区域供需合约")))
		return false
	var target_owner := int(entry.get("contract_target_owner", -1))
	if target_owner < 0 or target_owner >= players.size():
		target_owner = int(_district_city(target_index).get("owner", -1))
	if target_owner < 0 or target_owner >= players.size():
		_log("%s展示结束时找不到可回应的目标城市业主。" % String(skill.get("name", "区域供需合约")))
		return false
	var contract_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	if contract_id < 0:
		card_resolution_sequence += 1
		contract_id = card_resolution_sequence
	if _pending_contract_offer_index_for_id(contract_id) >= 0:
		return true
	var offer := entry.duplicate(true)
	offer["contract_offer_id"] = contract_id
	offer["contract_target_owner"] = target_owner
	offer["contract_response"] = CONTRACT_RESPONSE_PENDING
	offer["contract_decision_timer"] = CONTRACT_DECISION_SECONDS
	offer["contract_decision_started_time"] = game_time
	offer["skill"] = skill.duplicate(true)
	pending_contract_offers.append(offer)
	entry["contract_offer_id"] = contract_id
	entry["contract_target_owner"] = target_owner
	entry["contract_response"] = CONTRACT_RESPONSE_PENDING
	entry["contract_decision_timer"] = CONTRACT_DECISION_SECONDS
	entry["contract_decision_started_time"] = game_time
	_log("%s公开展示结束：目标城市业主获得独立5秒签约窗口；其他玩家可以继续出牌。" % String(skill.get("name", "区域供需合约")))
	return true


func _apply_area_trade_contract(_player: Dictionary, skill: Dictionary, entry: Dictionary) -> bool:
	var source := String(skill.get("name", "区域供需合约"))
	var response := String(entry.get("contract_response", CONTRACT_RESPONSE_PENDING))
	if response == CONTRACT_RESPONSE_PENDING:
		return _enqueue_pending_area_trade_contract(skill, entry)
	var source_index := int(entry.get("contract_source_district", -1))
	var target_index := int(entry.get("contract_target_district", -1))
	var target_owner := int(entry.get("contract_target_owner", -1))
	if not _valid_contract_source_district(source_index) or not _valid_contract_target_district(target_index):
		_log("%s结算时合约区域已经失效。" % source)
		return false
	var target_city := _district_city(target_index)
	if target_owner < 0 or target_owner >= players.size():
		target_owner = int(target_city.get("owner", -1))
	var products := _contract_limited_products(entry.get("contract_products", []) as Array, _area_trade_contract_product_goal(skill))
	if products.is_empty():
		products = _area_trade_contract_products(skill, source_index, target_index)
	if response == CONTRACT_RESPONSE_ACCEPTED:
		return _apply_area_trade_contract_accept(skill, source_index, target_index, target_owner, products)
	return _apply_area_trade_contract_decline(skill, source_index, target_index, target_owner, products, response)


func _apply_area_trade_contract_accept(skill: Dictionary, source_index: int, target_index: int, target_owner: int, products: Array) -> bool:
	var source := String(skill.get("name", "区域供需合约"))
	var add_products := maxi(0, int(skill.get("contract_add_products", 1)))
	var add_demands := maxi(0, int(skill.get("contract_add_demands", 1)))
	var remove_products := maxi(0, int(skill.get("contract_remove_products", 0)))
	var remove_demands := maxi(0, int(skill.get("contract_remove_demands", 0)))
	var source_city := _district_city(source_index)
	var target_city := _district_city(target_index)
	var removed_source_products := _remove_district_products(source_index, remove_products, products)
	var removed_source_city_products := _remove_city_products_from_city(source_city, remove_products, products)
	var removed_target_demands := _remove_district_demands(target_index, remove_demands, products)
	var removed_target_city_demands := _remove_city_demands_from_city(target_city, remove_demands, products)
	var added_district_products := _add_district_products(source_index, products, add_products)
	var added_city_products := _add_city_products_to_city(source_city, products, add_products)
	var added_district_demands := _add_district_demands(target_index, products, add_demands)
	var added_city_demands := _add_city_demands_to_city(target_city, products, add_demands)
	if _city_is_active(source_city):
		source_city = _append_city_public_clue(source_city, "%s签约后接入供给：%s。" % [source, _limited_name_list(products, 4)])
		districts[source_index]["city"] = source_city
	if _city_is_active(target_city):
		target_city = _append_city_public_clue(target_city, "%s签约后接入需求：%s；真实签约业主不公开。" % [source, _limited_name_list(products, 4)])
		districts[target_index]["city"] = target_city
	var production_delta := int(skill.get("accept_production_delta", 0))
	var transport_delta := int(skill.get("accept_transport_delta", 0))
	var consumption_delta := int(skill.get("accept_consumption_delta", 0))
	var source_delta := _apply_contract_region_delta(source_index, production_delta, 0, 0, source)
	var target_delta := _apply_contract_region_delta(target_index, 0, transport_delta, consumption_delta, source)
	var route_flow_changed := _apply_contract_accept_route_flow(target_index, skill, source)
	target_city = _district_city(target_index)
	if _city_is_active(target_city):
		districts[target_index]["city"] = target_city
	var cash_gain := _grant_contract_cash(target_owner, maxi(0, int(skill.get("accept_cash", 0))), "匿名签约奖励", "%s｜%s→%s" % [
		source,
		_contract_district_short_name(source_index),
		_contract_district_short_name(target_index),
	])
	_refresh_city_networks()
	_refresh_product_market_prices()
	selected_trade_product = String(products[0]) if not products.is_empty() else selected_trade_product
	_pulse_district(source_index, Color("#fbbf24"))
	_pulse_district(target_index, Color("#f59e0b"))
	_add_action_callout(
		"匿名合约",
		source,
		"%s→%s签约：%s。" % [
			_contract_district_short_name(source_index),
			_contract_district_short_name(target_index),
			_limited_name_list(products, 4),
		],
		Color("#fbbf24"),
		_district_center(target_index)
	)
	var changed := cash_gain > 0 or route_flow_changed or bool(source_delta.get("changed", false)) or bool(target_delta.get("changed", false))
	changed = changed or not added_district_products.is_empty() or not added_city_products.is_empty() or not added_district_demands.is_empty() or not added_city_demands.is_empty()
	changed = changed or not removed_source_products.is_empty() or not removed_source_city_products.is_empty() or not removed_target_demands.is_empty() or not removed_target_city_demands.is_empty()
	_log("%s匿名签约生效：%s供给区接入%s，%s需求区接入%s；签约奖励%s。出牌者和真实城市业主仍按规则隐藏。" % [
		source,
		_contract_district_short_name(source_index),
		_limited_name_list(added_district_products + added_city_products, 4, "无新增"),
		_contract_district_short_name(target_index),
		_limited_name_list(added_district_demands + added_city_demands, 4, "无新增"),
		_contract_accept_effect_summary(skill),
	])
	return true


func _apply_area_trade_contract_decline(skill: Dictionary, source_index: int, target_index: int, target_owner: int, products: Array, response: String) -> bool:
	var source := String(skill.get("name", "区域供需合约"))
	var penalty_paid := _pay_contract_penalty(target_owner, maxi(0, int(skill.get("decline_cash_penalty", 0))), "匿名拒签惩罚", "%s｜%s→%s" % [
		source,
		_contract_district_short_name(source_index),
		_contract_district_short_name(target_index),
	])
	var target_delta := _apply_contract_region_delta(
		target_index,
		int(skill.get("decline_production_delta", 0)),
		int(skill.get("decline_transport_delta", 0)),
		int(skill.get("decline_consumption_delta", 0)),
		source
	)
	var route_damage := maxi(0, int(skill.get("decline_route_damage", 0)))
	var city := _district_city(target_index)
	if _city_is_active(city):
		if route_damage > 0:
			city["trade_route_damage"] = int(city.get("trade_route_damage", 0)) + route_damage
		city = _append_city_public_clue(city, "%s被%s：拒签惩罚%s，商品线索%s。" % [
			source,
			"超时拒签" if response == CONTRACT_RESPONSE_TIMEOUT else "拒签",
			_contract_decline_effect_summary(skill),
			_limited_name_list(products, 4),
		])
		districts[target_index]["city"] = city
	_refresh_city_networks()
	_refresh_product_market_prices()
	_pulse_district(target_index, Color("#fb7185"))
	_add_action_callout(
		"匿名合约",
		"拒签惩罚" if response != CONTRACT_RESPONSE_TIMEOUT else "超时拒签",
		"%s拒绝%s，惩罚：%s。" % [
			_contract_district_short_name(target_index),
			source,
			_contract_decline_effect_summary(skill),
		],
		Color("#fb7185"),
		_district_center(target_index)
	)
	_log("%s匿名合约%s：%s未接入%s；拒签惩罚%s，实际罚款¥%d。出牌者仍不公开。" % [
		source,
		"超时拒签" if response == CONTRACT_RESPONSE_TIMEOUT else "被拒签",
		_contract_district_short_name(target_index),
		_limited_name_list(products, 4),
		_contract_decline_effect_summary(skill),
		penalty_paid,
	])
	return true


func _apply_route_insurance(player: Dictionary, skill: Dictionary) -> bool:
	var city := _district_city(selected_district)
	if not _city_is_active(city):
		_log("%s需要选中一座存活的己方城市。" % String(skill.get("name", "供应链保险")))
		return false
	if int(city.get("owner", -1)) != selected_player:
		_log("%s只能保护己方城市；对手城市真实归属不会因此揭示。" % String(skill.get("name", "供应链保险")))
		return false
	var repair_routes := int(skill.get("repair_routes", 1))
	var before_damage := int(city.get("trade_route_damage", 0))
	city["trade_route_damage"] = max(0, before_damage - max(0, repair_routes))
	var revenue_amount := int(skill.get("revenue_amount", 0))
	if revenue_amount > 0:
		city["revenue_bonus"] = int(city.get("revenue_bonus", 0)) + revenue_amount
	districts[selected_district]["city"] = city
	_refresh_city_networks()
	_refresh_product_market_prices()
	_pulse_district(selected_district, Color("#22c55e"))
	_log("%s为%s投保供应链：断路压力%d→%d，周期收入永久+%d。" % [
		String(skill.get("name", "供应链保险")),
		districts[selected_district]["name"],
		before_damage,
		int(city.get("trade_route_damage", 0)),
		revenue_amount,
	])
	return true


func _apply_city_product_upgrade(_player: Dictionary, skill: Dictionary) -> bool:
	var source := String(skill.get("name", "产业升级"))
	var city := _district_city(selected_district)
	if not _city_is_active(city):
		_log("%s需要选中一座存活的己方城市。" % source)
		return false
	if int(city.get("owner", -1)) != selected_player:
		_log("%s只能升级己方城市；对手城市真实归属不会因此揭示。" % source)
		return false
	var products: Array = city.get("products", [])
	if products.is_empty():
		_log("%s没有可升级的城市商品。" % source)
		return false
	var product_index := 0
	var lowest_level := int((products[0] as Dictionary).get("level", 1))
	for i in range(1, products.size()):
		var candidate: Dictionary = products[i]
		var candidate_level := int(candidate.get("level", 1))
		if candidate_level < lowest_level:
			lowest_level = candidate_level
			product_index = i
	var product: Dictionary = products[product_index]
	var product_name := String(product.get("name", "未知商品"))
	var level_gain: int = maxi(0, int(skill.get("product_level", 1)))
	var after_level := clampi(lowest_level + level_gain, 1, CITY_PRODUCT_LEVEL_MAX)
	var revenue_amount: int = maxi(0, int(skill.get("revenue_amount", 0)))
	if after_level == lowest_level and revenue_amount <= 0:
		_log("%s没有产生有效产业升级：%s已达到%d级。" % [source, product_name, CITY_PRODUCT_LEVEL_MAX])
		return false
	product["level"] = after_level
	products[product_index] = product
	city["products"] = products
	city["revenue_bonus"] = int(city.get("revenue_bonus", 0)) + revenue_amount
	districts[selected_district]["city"] = city
	var panic_gain: int = maxi(0, int(skill.get("panic", 0)))
	if panic_gain > 0:
		_add_panic(selected_district, panic_gain, source)
	_refresh_product_market_prices()
	_pulse_district(selected_district, Color("#facc15"))
	_add_action_callout(
		"匿名产业升级",
		source,
		"%s的%s升级至%d级，周期收入额外+%d；业主身份未公开。" % [districts[selected_district]["name"], product_name, after_level, revenue_amount],
		Color("#facc15"),
		_district_center(selected_district)
	)
	_log("匿名卡牌为%s升级%s：%d级→%d级，周期收入永久+%d；出牌者不公开。" % [
		districts[selected_district]["name"],
		product_name,
		lowest_level,
		after_level,
		revenue_amount,
	])
	return true


func _economy_candidate_product(excluded: Array, prefer_current := true, prefer_local := true) -> String:
	if prefer_current and selected_trade_product != "" and PRODUCT_CATALOG.has(selected_trade_product) and not excluded.has(selected_trade_product):
		return selected_trade_product
	var options := []
	if prefer_local and selected_district >= 0 and selected_district < districts.size():
		var district: Dictionary = districts[selected_district]
		for list_variant in [district.get("products", []), district.get("demands", [])]:
			for product_variant in list_variant:
				var local_product := String(product_variant)
				if local_product != "" and PRODUCT_CATALOG.has(local_product) and not excluded.has(local_product) and not options.has(local_product):
					options.append(local_product)
	for product_variant in PRODUCT_CATALOG:
		var product_name := String(product_variant)
		if product_name != "" and not excluded.has(product_name) and not options.has(product_name):
			options.append(product_name)
	if options.is_empty():
		return ""
	return String(options[rng.randi_range(0, options.size() - 1)])


func _lowest_level_city_product_index(products: Array) -> int:
	if products.is_empty():
		return -1
	var product_index := 0
	var lowest_level := int((products[0] as Dictionary).get("level", 1))
	for i in range(1, products.size()):
		var candidate: Dictionary = products[i]
		var candidate_level := int(candidate.get("level", 1))
		if candidate_level < lowest_level:
			lowest_level = candidate_level
			product_index = i
	return product_index


func _city_product_name_list_from_products(products: Array) -> Array:
	var result := []
	for product_variant in products:
		var product: Dictionary = product_variant
		var product_name := String(product.get("name", ""))
		if product_name != "":
			result.append(product_name)
	return result


func _apply_city_product_shift(_player: Dictionary, skill: Dictionary) -> bool:
	var source := String(skill.get("name", "商品换线"))
	var city := _district_city(selected_district)
	if not _city_is_active(city):
		_log("%s需要选中一座存活的己方城市。" % source)
		return false
	if int(city.get("owner", -1)) != selected_player:
		_log("%s只能调整己方城市；对手城市真实归属不会因此揭示。" % source)
		return false
	var products: Array = city.get("products", [])
	if products.is_empty():
		_log("%s没有可替换的主营商品。" % source)
		return false
	var shift_count: int = maxi(1, int(skill.get("product_shift", 1)))
	var changes := []
	for _i in range(shift_count):
		var excluded := _city_product_name_list_from_products(products)
		var new_product := _economy_candidate_product(excluded, true, true)
		if new_product == "":
			break
		var replace_index := _lowest_level_city_product_index(products)
		if replace_index < 0:
			break
		var old_product: Dictionary = products[replace_index]
		var old_name := String(old_product.get("name", "未知商品"))
		products[replace_index] = {"name": new_product, "level": 1}
		changes.append("%s→%s" % [old_name, new_product])
		selected_trade_product = new_product
	if changes.is_empty():
		_log("%s没有找到可替换的新商品线。" % source)
		return false
	city["products"] = products
	var revenue_amount: int = maxi(0, int(skill.get("revenue_amount", 0)))
	city["revenue_bonus"] = int(city.get("revenue_bonus", 0)) + revenue_amount
	districts[selected_district]["city"] = city
	var panic_gain: int = maxi(0, int(skill.get("panic", 0)))
	if panic_gain > 0:
		_add_panic(selected_district, panic_gain, source)
	_refresh_city_networks()
	_refresh_product_market_prices()
	_pulse_district(selected_district, Color("#f59e0b"))
	_add_action_callout(
		"匿名商品换线",
		source,
		"%s主营换线：%s；业主身份未公开。" % [districts[selected_district]["name"], "、".join(changes)],
		Color("#f59e0b"),
		_district_center(selected_district)
	)
	_log("匿名卡牌为%s执行商品换线：%s；周期收入永久+%d；出牌者不公开。" % [
		districts[selected_district]["name"],
		"、".join(changes),
		revenue_amount,
	])
	return true


func _apply_city_demand_shift(_player: Dictionary, skill: Dictionary) -> bool:
	var source := String(skill.get("name", "需求改造"))
	var city := _district_city(selected_district)
	if not _city_is_active(city):
		_log("%s需要选中一座存活的己方城市。" % source)
		return false
	if int(city.get("owner", -1)) != selected_player:
		_log("%s只能调整己方城市；对手城市真实归属不会因此揭示。" % source)
		return false
	var demands := _city_demand_names(city)
	if demands.is_empty():
		_log("%s没有可改造的城市需求。" % source)
		return false
	var product_names := _city_product_names(city)
	var shift_count: int = maxi(1, int(skill.get("demand_shift", 1)))
	var changes := []
	for i in range(shift_count):
		var replace_index := i % demands.size()
		var old_name := String(demands[replace_index])
		var excluded := product_names.duplicate()
		for demand_variant in demands:
			var demand_name := String(demand_variant)
			if demand_name != "" and not excluded.has(demand_name):
				excluded.append(demand_name)
		var new_demand := _economy_candidate_product(excluded, true, true)
		if new_demand == "":
			continue
		demands[replace_index] = new_demand
		changes.append("%s→%s" % [old_name, new_demand])
		selected_trade_product = new_demand
	if changes.is_empty():
		_log("%s没有找到可接入的新需求商品。" % source)
		return false
	city["demands"] = demands
	var repair_routes := int(skill.get("repair_routes", 0))
	if repair_routes > 0:
		city["trade_route_damage"] = max(0, int(city.get("trade_route_damage", 0)) - repair_routes)
	var revenue_amount: int = maxi(0, int(skill.get("revenue_amount", 0)))
	city["revenue_bonus"] = int(city.get("revenue_bonus", 0)) + revenue_amount
	districts[selected_district]["city"] = city
	var panic_gain: int = maxi(0, int(skill.get("panic", 0)))
	if panic_gain > 0:
		_add_panic(selected_district, panic_gain, source)
	_refresh_city_networks()
	_refresh_product_market_prices()
	_pulse_district(selected_district, Color("#22c55e"))
	_add_action_callout(
		"匿名需求改造",
		source,
		"%s需求改造：%s；商路重新计算。" % [districts[selected_district]["name"], "、".join(changes)],
		Color("#22c55e"),
		_district_center(selected_district)
	)
	_log("匿名卡牌为%s执行需求改造：%s；修复商路压力%d，周期收入永久+%d；出牌者不公开。" % [
		districts[selected_district]["name"],
		"、".join(changes),
		maxi(0, repair_routes),
		revenue_amount,
	])
	return true


func _apply_market_stabilize(skill: Dictionary) -> bool:
	var source := String(skill.get("name", "市场稳定"))
	var product_name := _default_economy_product()
	if product_name == "":
		_log("%s没有可稳定的商品。" % source)
		return false
	_ensure_product_market_catalog()
	var entry: Dictionary = product_market.get(product_name, {})
	var before_volatility := int(entry.get("volatility", 4))
	var volatility_delta := int(skill.get("volatility_delta", 0))
	var after_volatility := clampi(before_volatility + volatility_delta, PRODUCT_VOLATILITY_MIN, PRODUCT_VOLATILITY_MAX)
	var before_demand_pressure := int(entry.get("temporary_demand_pressure", 0))
	var before_supply_pressure := int(entry.get("temporary_supply_pressure", 0))
	var before_price := _product_price(product_name)
	entry["temporary_demand_pressure"] = maxi(0, before_demand_pressure - maxi(1, int(skill.get("stabilize_amount", 0)) / 12))
	entry["temporary_supply_pressure"] = maxi(0, before_supply_pressure - maxi(1, int(skill.get("stabilize_amount", 0)) / 12))
	if after_volatility == before_volatility and int(entry.get("temporary_demand_pressure", 0)) == before_demand_pressure and int(entry.get("temporary_supply_pressure", 0)) == before_supply_pressure:
		_log("%s没有产生有效变化：%s已经处于稳定区间。" % [source, product_name])
		return false
	entry["volatility"] = after_volatility
	product_market[product_name] = entry
	selected_trade_product = product_name
	_refresh_product_market_prices()
	var after_price := _product_price(product_name)
	_log("%s稳定%s：削减临时供需压力，市场按供需重算¥%d→¥%d，波动%d→%d。" % [
		source,
		product_name,
		before_price,
		after_price,
		before_volatility,
		after_volatility,
	])
	return true


func _economy_effect_callout_position() -> Vector2:
	if selected_district >= 0 and selected_district < districts.size():
		return _district_center(selected_district)
	return Vector2(map_width_m * 0.5, map_height_m * 0.5)


func _apply_product_growth_boon(skill: Dictionary) -> bool:
	var source := String(skill.get("name", "商品催化"))
	var product_name := _default_economy_product()
	if product_name == "":
		_log("%s没有可催化的商品。" % source)
		return false
	var growth_multiplier: float = float(skill.get("growth_multiplier", 1.0))
	var route_flow_multiplier: float = float(skill.get("route_flow_multiplier", 1.0))
	var growth_turns: int = maxi(0, int(skill.get("growth_turns", 0)))
	var route_flow_turns: int = maxi(0, int(skill.get("route_flow_turns", growth_turns)))
	var turns: int = maxi(growth_turns, route_flow_turns)
	if turns <= 0:
		turns = 1
	if growth_multiplier <= 1.001 and route_flow_multiplier <= 1.001:
		_log("%s没有有效的商品增益参数。" % source)
		return false
	var changed := _apply_product_market_boon(product_name, growth_multiplier, route_flow_multiplier, turns, source, false)
	if not changed:
		_log("%s没有超过%s当前已有的经济天气。" % [source, product_name])
		return false
	selected_trade_product = product_name
	_refresh_product_market_prices()
	if selected_district >= 0 and selected_district < districts.size():
		_pulse_district(selected_district, Color("#f59e0b"))
	_add_action_callout(
		"商品经济",
		source,
		"%s：%s" % [product_name, _product_market_boon_text(product_name)],
		Color("#f59e0b"),
		_economy_effect_callout_position()
	)
	_log("%s催化%s：%s。" % [source, product_name, _product_market_boon_text(product_name)])
	return true


func _apply_route_flow_boon(player: Dictionary, skill: Dictionary) -> bool:
	var source := String(skill.get("name", "星港快线"))
	var city := _district_city(selected_district)
	if not _city_is_active(city):
		_log("%s需要选中一座存活的己方城市。" % source)
		return false
	if int(city.get("owner", -1)) != selected_player:
		_log("%s只能加速己方城市；对手城市真实归属不会因此揭示。" % source)
		return false
	var before_damage := int(city.get("trade_route_damage", 0))
	var repair_routes: int = maxi(0, int(skill.get("repair_routes", 0)))
	if repair_routes > 0:
		city["trade_route_damage"] = maxi(0, before_damage - repair_routes)
	var before_multiplier := float(city.get("route_flow_multiplier", 1.0))
	var before_turns := int(city.get("route_flow_turns", 0))
	var route_flow_multiplier: float = clampf(float(skill.get("route_flow_multiplier", 1.0)), 1.0, ROUTE_FLOW_MULTIPLIER_MAX)
	var route_flow_turns: int = maxi(1, int(skill.get("route_flow_turns", skill.get("growth_turns", 1))))
	if route_flow_multiplier > 1.001:
		city["route_flow_multiplier"] = maxf(before_multiplier, route_flow_multiplier)
		city["route_flow_turns"] = maxi(before_turns, route_flow_turns)
		city["route_flow_source"] = _merge_boon_source(String(city.get("route_flow_source", "")), source)
	var after_damage := int(city.get("trade_route_damage", 0))
	var after_multiplier := float(city.get("route_flow_multiplier", 1.0))
	var after_turns := int(city.get("route_flow_turns", 0))
	var changed := after_damage != before_damage or after_multiplier > before_multiplier + 0.001 or after_turns > before_turns
	if not changed:
		_log("%s没有超过%s当前已有的流通加速。" % [source, districts[selected_district]["name"]])
		return false
	districts[selected_district]["city"] = city
	var demand_names := _city_demand_names(city)
	if not demand_names.is_empty():
		selected_trade_product = String(demand_names[0])
	_refresh_city_networks()
	_refresh_product_market_prices()
	_pulse_district(selected_district, Color("#22c55e"))
	_add_action_callout(
		"匿名物流",
		source,
		"%s流通%s；断路压力%d→%d。" % [
			districts[selected_district]["name"],
			_city_route_flow_status_text(city),
			before_damage,
			after_damage,
		],
		Color("#22c55e"),
		_district_center(selected_district)
	)
	_log("%s加速%s商路：流通×%.2f/%d周期，断路压力%d→%d；真实业主仍不公开。" % [
		source,
		districts[selected_district]["name"],
		after_multiplier,
		after_turns,
		before_damage,
		after_damage,
	])
	return true


func _apply_region_economy_shift(skill: Dictionary) -> bool:
	var source := String(skill.get("name", "区域经济卡"))
	if selected_district < 0 or selected_district >= districts.size() or bool(districts[selected_district].get("destroyed", false)):
		_log("%s需要选中一个未毁区域。" % source)
		return false
	var district: Dictionary = districts[selected_district]
	var before_production := clampi(int(district.get("production_level", 2)), REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var before_transport := clampi(int(district.get("transport_level", 2)), REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var before_consumption := clampi(int(district.get("consumption_level", 2)), REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var production_delta := int(skill.get("production_delta", 0))
	var transport_delta := int(skill.get("transport_delta", 0))
	var consumption_delta := int(skill.get("consumption_delta", 0))
	var after_production := clampi(before_production + production_delta, REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var after_transport := clampi(before_transport + transport_delta, REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	var after_consumption := clampi(before_consumption + consumption_delta, REGION_ECONOMY_LEVEL_MIN, REGION_ECONOMY_LEVEL_MAX)
	district["production_level"] = after_production
	district["transport_level"] = after_transport
	district["consumption_level"] = after_consumption
	district["transport_score"] = _transport_score_from_level(after_transport, String(district.get("terrain", "land")) == "ocean")
	if String(district.get("economic_focus", "")) == "":
		district["economic_focus"] = "balanced"
	district["economic_focus_label"] = _district_economy_focus_label(String(district.get("economic_focus", "balanced")))
	var city := district.get("city", {}) as Dictionary
	var route_damage := int(skill.get("route_damage", 0))
	if _city_is_active(city) and route_damage > 0:
		city["trade_route_damage"] = int(city.get("trade_route_damage", 0)) + route_damage
	var repair_routes := int(skill.get("repair_routes", 0))
	if _city_is_active(city) and repair_routes > 0:
		city["trade_route_damage"] = maxi(0, int(city.get("trade_route_damage", 0)) - repair_routes)
	if _city_is_active(city):
		city = _append_city_public_clue(city, "%s调整区域GDP结构：生产%d→%d、交通%d→%d、消费%d→%d。" % [
			source,
			before_production,
			after_production,
			before_transport,
			after_transport,
			before_consumption,
			after_consumption,
		])
		district["city"] = city
	districts[selected_district] = district
	var product_name := _default_economy_product()
	if product_name != "":
		_ensure_product_market_catalog()
		var entry: Dictionary = product_market.get(product_name, {})
		if not entry.is_empty():
			entry["temporary_demand_pressure"] = int(entry.get("temporary_demand_pressure", 0)) + maxi(0, int(skill.get("market_demand_pressure", 0)))
			entry["temporary_supply_pressure"] = int(entry.get("temporary_supply_pressure", 0)) + maxi(0, int(skill.get("market_supply_pressure", 0)))
			product_market[product_name] = entry
	if int(skill.get("panic", 0)) > 0:
		_add_panic(selected_district, int(skill.get("panic", 0)), source)
	_refresh_city_networks()
	_refresh_product_market_prices()
	var changed := before_production != after_production or before_transport != after_transport or before_consumption != after_consumption or route_damage > 0 or repair_routes > 0
	if not changed:
		_log("%s没有产生有效变化：%s的区域经济指标已到边界。" % [source, district["name"]])
		return false
	_pulse_district(selected_district, Color("#f59e0b"))
	_add_action_callout(
		"区域GDP",
		source,
		"%s：生产%d→%d｜交通%d→%d｜消费%d→%d。" % [
			district["name"],
			before_production,
			after_production,
			before_transport,
			after_transport,
			before_consumption,
			after_consumption,
		],
		Color("#f59e0b"),
		_district_center(selected_district)
	)
	_log("%s调整%s区域GDP结构：生产%d→%d，交通%d→%d（速度%.2f），消费%d→%d；出牌者不公开。" % [
		source,
		district["name"],
		before_production,
		after_production,
		before_transport,
		after_transport,
		_district_transport_speed(selected_district),
		before_consumption,
		after_consumption,
	])
	return true


func _apply_city_contract_boon(_player: Dictionary, skill: Dictionary) -> bool:
	var source := String(skill.get("name", "短期订单"))
	var city := _district_city(selected_district)
	if not _city_is_active(city):
		_log("%s需要选中一座存活的己方城市。" % source)
		return false
	if int(city.get("owner", -1)) != selected_player:
		_log("%s只能签给己方城市；对手城市真实归属不会因此揭示。" % source)
		return false
	var before_contract := int(city.get("contract_income_bonus", 0))
	var before_turns := int(city.get("contract_turns", 0))
	var contract_income: int = maxi(0, int(skill.get("contract_income", 0)))
	var contract_turns: int = maxi(1, int(skill.get("contract_turns", 1)))
	if contract_income > 0:
		city["contract_income_bonus"] = maxi(before_contract, contract_income)
		city["contract_turns"] = maxi(before_turns, contract_turns)
		city["contract_source"] = _merge_boon_source(String(city.get("contract_source", "")), source)
	var before_flow := float(city.get("route_flow_multiplier", 1.0))
	var before_flow_turns := int(city.get("route_flow_turns", 0))
	var route_flow_multiplier: float = clampf(float(skill.get("route_flow_multiplier", 1.0)), 1.0, ROUTE_FLOW_MULTIPLIER_MAX)
	var route_flow_turns: int = maxi(1, int(skill.get("route_flow_turns", contract_turns)))
	if route_flow_multiplier > 1.001:
		city["route_flow_multiplier"] = maxf(before_flow, route_flow_multiplier)
		city["route_flow_turns"] = maxi(before_flow_turns, route_flow_turns)
		city["route_flow_source"] = _merge_boon_source(String(city.get("route_flow_source", "")), source)
	var panic_gain: int = maxi(0, int(skill.get("panic", 0)))
	if panic_gain > 0:
		_add_panic(selected_district, panic_gain, source)
	var changed := int(city.get("contract_income_bonus", 0)) > before_contract or int(city.get("contract_turns", 0)) > before_turns or float(city.get("route_flow_multiplier", 1.0)) > before_flow + 0.001 or int(city.get("route_flow_turns", 0)) > before_flow_turns
	if not changed:
		_log("%s没有超过%s当前已有的合约/流通加速。" % [source, districts[selected_district]["name"]])
		return false
	districts[selected_district]["city"] = city
	_refresh_city_networks()
	_refresh_product_market_prices()
	_pulse_district(selected_district, Color("#fbbf24"))
	_add_action_callout(
		"匿名合约",
		source,
		"%s合约%s，流通%s；真实业主仍不公开。" % [
			districts[selected_district]["name"],
			_city_contract_status_text(city),
			_city_route_flow_status_text(city),
		],
		Color("#fbbf24"),
		_district_center(selected_district)
	)
	_log("%s为%s签下临时合约：%s；收入拆解%s。" % [
		source,
		districts[selected_district]["name"],
		_city_contract_status_text(city),
		_city_income_breakdown_summary(_city_cycle_income_breakdown(selected_district, _city_competition_matches(selected_district))),
	])
	return true


func _apply_route_sabotage(skill: Dictionary) -> bool:
	var source := String(skill.get("name", "商路黑客"))
	var city := _district_city(selected_district)
	if not _city_is_active(city):
		_log("%s需要选中一座存活的公开城市群。" % source)
		return false
	var route_damage: int = maxi(0, int(skill.get("route_damage", 1)))
	if route_damage <= 0:
		_log("%s没有产生有效商路损伤。" % source)
		return false
	var before_damage := int(city.get("trade_route_damage", 0))
	city["trade_route_damage"] = before_damage + route_damage
	districts[selected_district]["city"] = city
	var panic_gain: int = maxi(0, int(skill.get("panic", 0)))
	if panic_gain > 0:
		_add_panic(selected_district, panic_gain, source)
	_refresh_city_networks()
	_refresh_product_market_prices()
	_pulse_district(selected_district, Color("#fb7185"))
	_add_action_callout(
		"商路警报",
		source,
		"%s新增%d条断路压力；城市真实业主仍不公开。" % [districts[selected_district]["name"], route_damage],
		Color("#fb7185"),
		_district_center(selected_district)
	)
	_log("%s干扰%s：断路压力%d→%d；真实业主仍不公开。" % [
		source,
		districts[selected_district]["name"],
		before_damage,
		int(city.get("trade_route_damage", 0)),
	])
	return true


func _buy_selected_skill() -> void:
	if not _can_selected_player_act():
		return
	_sync_selected_district_card()
	_buy_card_for_player_from_district(selected_player, selected_district, selected_market_skill, false)
	_refresh_ui()


func _buy_card_for_player_from_district(player_index: int, district_index: int, skill_name: String, anonymous: bool = false, ignore_cooldown: bool = false) -> bool:
	if game_over or player_index < 0 or player_index >= players.size():
		return false
	var player: Dictionary = players[player_index]
	var actor_label := "匿名财团" if anonymous else String(player.get("name", "玩家"))
	if not ignore_cooldown and float(player.get("action_cooldown", 0.0)) > 0.0:
		if not anonymous:
			_log("%s操作冷却中，还需%.1fs。" % [actor_label, float(player.get("action_cooldown", 0.0))])
		return false
	skill_name = _canonical_card_supply_name(skill_name)
	if skill_name == "" or not _skill_exists(skill_name):
		if not anonymous:
			_log("没有可获取的选中卡牌。")
		return false
	if district_index < 0 or district_index >= districts.size() or bool(districts[district_index].get("destroyed", false)):
		if not anonymous:
			_log("目标区域无效或已被破坏，不能从这里获取卡牌。")
		return false
	if not _can_buy_card_from_district(district_index, player_index):
		if not anonymous:
			_log("%s暂不能购买卡牌：需要怪兽落地区/相邻区，或补给范围扩张能力。" % districts[district_index]["name"])
		return false
	if not _district_has_card(district_index, skill_name):
		if not anonymous:
			_log("%s不在当前区域候选中；%s。" % [_card_display_name(skill_name), _card_choice_location_summary(skill_name)])
		return false
	if not _player_can_receive_card(player, skill_name):
		if not anonymous:
			_log("%s暂不能获得%s：普通手牌上限为%d张；重复牌会自动合成。" % [actor_label, _card_display_name(skill_name), PLAYER_HAND_LIMIT])
		return false
	var price := _card_price(skill_name, district_index, player_index)
	if int(player.get("cash", 0)) < price:
		if not anonymous:
			_log("%s资金不足，购买%s需要¥%d，当前只有¥%d。" % [actor_label, _card_display_name(skill_name), price, int(player.get("cash", 0))])
		return false
	if not _acquire_card_for_player(player, skill_name, district_index, "区域获取", anonymous):
		return false
	player["cash"] = int(player.get("cash", 0)) - price
	player["action_cooldown"] = maxf(float(player.get("action_cooldown", 0.0)), MARKET_COOLDOWN)
	players[player_index] = player
	_record_player_card_spend(player_index, price, "购买%s" % _card_display_name(skill_name), districts[district_index]["name"])
	_log("%s支付¥%d购买%s；购牌身份不对外公开。" % [actor_label, price, _card_display_name(skill_name)])
	_grant_role_bonus_card_on_purchase(player_index, district_index, skill_name, anonymous)
	return true


func _upgrade_skill_slot(slot_index: int) -> void:
	if not _can_selected_player_act():
		return
	var player: Dictionary = players[selected_player]
	var upgrade_name := selected_market_skill
	if not _can_upgrade_skill_slot(player, slot_index, upgrade_name):
		_log("无法升级：需要从当前区域选中同系列高一级卡牌。")
		return
	var old_skill: Dictionary = player["slots"][slot_index]
	var old_name := String(old_skill["name"])
	var price := _card_price(upgrade_name, selected_district)
	if int(player.get("cash", 0)) < price:
		_log("%s资金不足，升级为%s需要¥%d。" % [player["name"], _card_display_name(upgrade_name), price])
		_refresh_ui()
		return
	player["cash"] = int(player.get("cash", 0)) - price
	_record_player_card_spend(selected_player, price, "升级%s" % _card_display_name(upgrade_name), districts[selected_district]["name"] if selected_district >= 0 and selected_district < districts.size() else "")
	player["slots"][slot_index] = _make_skill(upgrade_name)
	_sync_selected_market_skill()
	_log("%s支付¥%d从区域补给获得%s，将%s升级为%s；区域补给不会消失。" % [
		player["name"],
		price,
		_card_display_name(upgrade_name),
		_card_display_name(old_name),
		_card_display_name(upgrade_name),
	])
	_start_player_cooldown(MARKET_COOLDOWN)
	_refresh_ui()


func _replace_skill_slot(slot_index: int) -> void:
	if not _can_selected_player_act():
		return
	var player: Dictionary = players[selected_player]
	if slot_index < 0 or slot_index >= player["slots"].size():
		return
	var replacement_name := selected_market_skill
	if not _can_replace_skill_slot(replacement_name):
		_log("无法获取：请选择当前区域提供的卡牌。")
		return
	var price := _card_price(replacement_name, selected_district)
	if int(player.get("cash", 0)) < price:
		_log("%s资金不足，购买%s需要¥%d。" % [player["name"], _card_display_name(replacement_name), price])
		_refresh_ui()
		return
	_log("新规则下不再替换卡牌，改为从区域重新获取；若已有同名/低阶卡则自动升级。")
	if not _acquire_card_for_player(player, replacement_name, selected_district, "区域获取"):
		_refresh_ui()
		return
	player["cash"] = int(player.get("cash", 0)) - price
	_record_player_card_spend(selected_player, price, "购买%s" % _card_display_name(replacement_name), districts[selected_district]["name"] if selected_district >= 0 and selected_district < districts.size() else "")
	_log("%s支付¥%d购买%s。" % [player["name"], price, _card_display_name(replacement_name)])
	_sync_selected_market_skill()
	_start_player_cooldown(MARKET_COOLDOWN)
	_refresh_ui()


func _is_direct_monster_skill_kind(kind: String) -> bool:
	return [
		"move",
		"fly",
		"burrow",
		"attack",
		"charge_attack",
		"armor_gain",
		"guard",
		"area_damage",
		"miasma_shot",
		"miasma_bloom",
		"miasma_reclaim",
		"corrosive_breath",
		"roar",
		"roll_attack",
	].has(kind)


func _skill_targets_monster(skill: Dictionary) -> bool:
	var kind := String(skill.get("kind", ""))
	return _is_direct_monster_skill_kind(kind) or ["monster_lure", "special_monster_delay", "mudslide", "monster_takeover"].has(kind)


func _skill_requires_target_monster(skill: Dictionary) -> bool:
	return not auto_monsters.is_empty() and _skill_targets_monster(skill)


func _finish_played_skill(player_index: int, slot_index: int, skill: Dictionary, cooldown: float = COMMAND_COOLDOWN) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	_pay_skill_play_cost(player_index, skill)
	if slot_index >= 0 and slot_index < (players[player_index].get("slots", []) as Array).size():
		if bool(skill.get("persistent", false)):
			skill["cooldown_left"] = max(float(skill.get("cooldown_left", 0.0)), float(skill.get("cooldown", DEFAULT_SKILL_COOLDOWN)))
			players[player_index]["slots"][slot_index] = skill
		else:
			players[player_index]["slots"][slot_index] = null
	players[player_index]["action_cooldown"] = max(float(players[player_index].get("action_cooldown", 0.0)), cooldown)


func _trigger_auto_monster_card_command(skill: Dictionary, _player: Dictionary, target_slot: int) -> bool:
	var slot := _valid_auto_monster_slot(target_slot)
	if slot < 0 or slot >= auto_monsters.size():
		_log("%s没有找到可指挥的怪兽。" % skill["name"])
		return false
	selected_auto_monster_slot = slot
	var actor: Dictionary = auto_monsters[slot]
	if bool(actor.get("down", false)):
		_log("怪%d·%s已倒地，不能执行%s。" % [slot + 1, String(actor.get("name", "怪兽")), String(skill["name"])])
		return false
	var target: int = selected_district
	if target < 0 or target >= districts.size() or districts[target]["destroyed"]:
		_log("%s的目标区域无效或已破坏。" % skill["name"])
		return false
	var kind := String(skill.get("kind", ""))
	var before := _entity_world_position(actor)
	var moved := 0.0
	var resolved := false
	match kind:
		"move", "fly", "burrow":
			moved = _move_entity_toward(actor, _district_center(target), float(skill.get("move", 0.0)))
			if moved <= 0.5:
				_log("%s指挥怪%d·%s移动，但它没有完成有效位移。" % [String(skill["name"]), slot + 1, String(actor.get("name", "怪兽"))])
				return false
			_add_visual_trail(before, _entity_world_position(actor), _auto_monster_color(slot), String(skill["name"]))
			_apply_auto_monster_path_effects(actor, before, _entity_world_position(actor), String(skill["name"]), "fly" if kind == "fly" else _auto_monster_movement_mode(actor))
			_auto_monster_resource_drain(actor, int(actor["position"]), String(skill["name"]))
			if kind == "burrow":
				var burrow_armor: int = int(skill.get("armor", 0))
				actor["armor"] = int(actor.get("armor", 0)) + burrow_armor
			resolved = true
		"attack":
			resolved = _command_auto_monster_attack(slot, skill)
		"charge_attack":
			var charge_target := _nearest_other_auto_monster_slot(slot)
			if charge_target < 0:
				_log("%s没有可攻击的其他怪兽目标。" % skill["name"])
				return false
			var target_actor: Dictionary = auto_monsters[charge_target]
			moved = _move_entity_toward(actor, _entity_world_position(target_actor), float(skill.get("move", 0.0)))
			if moved > 0.5:
				_add_visual_trail(before, _entity_world_position(actor), _auto_monster_color(slot), String(skill["name"]))
				_apply_auto_monster_path_effects(actor, before, _entity_world_position(actor), String(skill["name"]), _auto_monster_movement_mode(actor))
				_auto_monster_resource_drain(actor, int(actor["position"]), String(skill["name"]))
			auto_monsters[slot] = actor
			resolved = _command_auto_monster_attack(slot, skill)
		"armor_gain":
			var direct_armor: int = int(skill.get("armor", 0))
			actor["armor"] = int(actor.get("armor", 0)) + direct_armor
			resolved = direct_armor > 0
		"guard":
			var guard_armor: int = max(int(skill.get("guard", 0)), int(skill.get("ranged_guard", 0)))
			actor["armor"] = int(actor.get("armor", 0)) + guard_armor
			resolved = guard_armor > 0
		"area_damage":
			var area_range := float(skill.get("range", DEFAULT_AOE_RADIUS_METERS))
			if _entity_distance_to_district(actor, target) > area_range:
				_log("%s目标距离%s，超过范围%s。" % [String(skill["name"]), _entity_distance_to_district_label(actor, target), _meters_text(area_range)])
				return false
			_add_monster_attack_effect(_entity_world_position(actor), _district_center(target), String(skill["name"]), area_range, _auto_monster_color(slot), area_range > MELEE_RANGE_METERS)
			_damage_district(target, max(1, int(skill.get("damage", 1))), String(skill["name"]))
			resolved = true
		"miasma_shot", "corrosive_breath":
			if _entity_distance_to_district(actor, target) > float(skill.get("range", 0.0)):
				_log("%s目标距离%s，超过射程%s。" % [String(skill["name"]), _entity_distance_to_district_label(actor, target), _meters_text(float(skill.get("range", 0.0)))])
				return false
			_add_monster_attack_effect(_entity_world_position(actor), _district_center(target), String(skill["name"]), float(skill.get("range", 0.0)), _auto_monster_color(slot), true)
			_damage_district(target, max(1, int(skill.get("damage", 1))), String(skill["name"]))
			_place_auto_miasma(actor, target, int(skill.get("miasma_count", 0)), String(skill["name"]))
			resolved = true
		"miasma_bloom":
			if _entity_distance_to_district(actor, target) > float(skill.get("range", DEFAULT_AOE_RADIUS_METERS)):
				_log("%s目标距离%s，超过范围%s。" % [String(skill["name"]), _entity_distance_to_district_label(actor, target), _meters_text(float(skill.get("range", DEFAULT_AOE_RADIUS_METERS)))])
				return false
			_place_auto_miasma(actor, target, int(skill.get("miasma_count", 0)), String(skill["name"]))
			resolved = true
		"miasma_reclaim":
			resolved = _command_auto_monster_reclaim_miasma(slot, skill)
		"roar":
			if _entity_distance_to_district(actor, target) > float(skill.get("range", 0.0)):
				_log("%s目标距离%s，超过范围%s。" % [String(skill["name"]), _entity_distance_to_district_label(actor, target), _meters_text(float(skill.get("range", 0.0)))])
				return false
			_add_panic(target, 28, String(skill["name"]))
			special_monster_timer += float(skill.get("delay", 1.0))
			resolved = true
		"roll_attack":
			moved = _move_entity_toward(actor, _district_center(target), float(skill.get("move", 0.0)))
			if moved <= 0.5:
				_log("%s没有完成有效翻滚。" % skill["name"])
				return false
			_add_visual_trail(before, _entity_world_position(actor), _auto_monster_color(slot), String(skill["name"]))
			_apply_auto_monster_path_effects(actor, before, _entity_world_position(actor), String(skill["name"]), _auto_monster_movement_mode(actor))
			_damage_district(int(actor["position"]), max(1, int(skill.get("damage", 1))), String(skill["name"]))
			_auto_monster_resource_drain(actor, int(actor["position"]), String(skill["name"]))
			auto_monsters[slot] = actor
			_command_auto_monster_attack(slot, skill)
			resolved = true
	if not resolved:
		return false
	auto_monsters[slot] = actor
	if moved > 0.5 and ["move", "fly", "burrow"].has(kind):
		_resolve_auto_monster_encounter(slot, "卡牌指挥后的遭遇")
	_log("匿名卡牌%s：一次性直接指挥怪%d·%s执行动作，位置%s%s；出牌者不公开。" % [
		String(skill["name"]),
		slot + 1,
		String(actor.get("name", "怪兽")),
		districts[int(actor.get("position", target))]["name"],
		"，移动%s" % _meters_text(moved) if moved > 0.5 else "",
	])
	_add_action_callout(
		"自动怪兽%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
		"卡牌指令",
		"%s一次性直接指挥这只怪兽；出牌者不公开。" % String(skill["name"]),
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)
	return true


func _trigger_bound_monster_skill(skill: Dictionary, _player: Dictionary) -> bool:
	var uid := int(skill.get("bound_monster_uid", 0))
	var slot := _auto_monster_slot_by_uid(uid)
	if slot < 0:
		_log("%s绑定的怪兽已不在场上。" % String(skill.get("name", "固定技能")))
		return false
	var actor: Dictionary = auto_monsters[slot]
	if bool(actor.get("down", false)):
		_log("怪%d·%s已倒地，无法释放%s。" % [slot + 1, String(actor.get("name", "怪兽")), String(skill.get("name", "固定技能"))])
		return false
	var action: Dictionary = (skill.get("action", {}) as Dictionary).duplicate(true)
	if action.is_empty():
		return false
	var target := selected_district
	if target < 0 or target >= districts.size() or bool(districts[target].get("destroyed", false)):
		target = _weighted_auto_monster_target(actor)
	if target < 0:
		return false
	var before := _entity_world_position(actor)
	var required_range: float = float(action.get("range", 0.0))
	var move_budget: float = float(action.get("move_override", -1.0))
	if move_budget < 0.0:
		move_budget = float(actor.get("move", MONSTER_RAMPAGE_MOVE_METERS))
	move_budget *= _monster_terrain_move_multiplier(actor, target)
	if required_range <= 0.0 or _entity_distance_to_district(actor, target) > required_range:
		_move_entity_toward(actor, _district_center(target), move_budget)
	var moved := _wrapped_distance(before, _entity_world_position(actor))
	if moved > 0.5:
		_add_visual_trail(before, _entity_world_position(actor), _auto_monster_color(slot), String(action.get("name", "兽技")))
		_apply_auto_monster_path_effects(actor, before, _entity_world_position(actor), String(action.get("name", "兽技")), _auto_monster_movement_mode(actor))
	var target_after_move := target
	if required_range <= 0.0:
		target_after_move = int(actor.get("position", target))
	var in_range := required_range <= 0.0 or _entity_distance_to_district(actor, target_after_move) <= required_range
	if in_range:
		var district_damage: int = max(AUTO_MONSTER_MIN_SPECIAL_DAMAGE, int(ceil(float(action.get("damage", 1)) * 0.5)))
		_add_monster_attack_effect(_entity_world_position(actor), _district_center(target_after_move), String(action.get("name", "兽技")), required_range, _auto_monster_color(slot), required_range > MELEE_RANGE_METERS)
		_damage_district(target_after_move, district_damage, "%s·%s" % [String(actor.get("name", "怪兽")), String(action.get("name", "兽技"))])
		_auto_monster_resource_drain(actor, target_after_move, String(action.get("name", "兽技")))
		var panic_gain := int(action.get("panic", 0))
		if panic_gain > 0:
			_add_panic(target_after_move, panic_gain, String(action.get("name", "兽技")))
		_place_auto_miasma(actor, target_after_move, int(action.get("miasma_count", 0)), String(action.get("name", "兽技")))
	var armor_gain := int(action.get("armor", 0))
	if armor_gain > 0:
		actor["armor"] = int(actor.get("armor", 0)) + armor_gain
	var self_heal := int(action.get("self_heal", 0))
	if self_heal > 0:
		actor["hp"] = min(int(actor.get("max_hp", 0)), int(actor.get("hp", 0)) + self_heal)
	auto_monsters[slot] = actor
	if int(action.get("damage", 0)) > 0:
		_try_auto_monster_hit_other(slot, action)
	_add_action_callout(
		"匿名固定技能",
		String(action.get("name", "兽技")),
		"怪%d·%s主动释放绑定技能，目标%s。" % [slot + 1, String(actor.get("name", "怪兽")), districts[target_after_move]["name"]],
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)
	_log("匿名固定技能触发：怪%d·%s释放%s，目标%s；%s。" % [
		slot + 1,
		String(actor.get("name", "怪兽")),
		String(action.get("name", "兽技")),
		districts[target_after_move]["name"],
		String(action.get("text", "")),
	])
	return true


func _apply_monster_takeover(skill: Dictionary, target_slot: int, player_index: int) -> bool:
	if target_slot < 0 or target_slot >= auto_monsters.size():
		return false
	var actor: Dictionary = auto_monsters[target_slot]
	if bool(actor.get("down", false)):
		_log("%s无法夺取倒地怪兽。" % String(skill.get("name", "夺取怪兽")))
		return false
	var old_owner := int(actor.get("owner", -1))
	var monster_uid := int(actor.get("uid", 0))
	actor["owner"] = player_index
	actor["owner_revealed"] = false
	actor["owner_clue"] = "归属刚被匿名夺取，等待下一次受伤资金线索。"
	actor = _reset_owner_damage_cash_meter(actor)
	auto_monsters[target_slot] = actor
	_invalidate_bound_monster_skills(monster_uid, "绑定怪兽归属被夺取，此固定技能失效。")
	var granted := _grant_bound_monster_skills(player_index, monster_uid, String(actor.get("name", "怪兽")), clampi(int(actor.get("rank", 1)), 1, 4))
	_add_action_callout(
		"匿名卡牌",
		"夺取怪兽",
		"怪%d·%s的归属被重写；出牌者不公开。" % [target_slot + 1, String(actor.get("name", "怪兽"))],
		_auto_monster_color(target_slot),
		_entity_world_position(actor)
	)
	_log("公开情报：怪%d·%s的归属被匿名夺取；原归属%s，新归属暂不公开。新归属者获得固定技能：%s。" % [
		target_slot + 1,
		String(actor.get("name", "怪兽")),
		("未知" if old_owner < 0 else "已被覆盖"),
		_limited_name_list(granted, 4, "无"),
	])
	_refresh_ui()
	return true


func _command_auto_monster_attack(slot: int, skill: Dictionary) -> bool:
	var target_slot := _nearest_other_auto_monster_slot(slot)
	if target_slot < 0:
		_log("%s没有可攻击的其他怪兽目标。" % String(skill.get("name", "攻击")))
		return false
	var actor: Dictionary = auto_monsters[slot]
	var target: Dictionary = auto_monsters[target_slot]
	var range_limit: float = float(skill.get("range", MELEE_RANGE_METERS))
	if range_limit <= 0.0:
		range_limit = MELEE_RANGE_METERS
	var distance: float = _wrapped_distance(_entity_world_position(actor), _entity_world_position(target))
	if distance > range_limit:
		_log("%s目标怪%d·%s距离%s，超过范围%s。" % [
			String(skill.get("name", "攻击")),
			target_slot + 1,
			String(target.get("name", "怪兽")),
			_meters_text(distance),
			_meters_text(range_limit),
		])
		return false
	_add_monster_attack_effect(_entity_world_position(actor), _entity_world_position(target), String(skill.get("name", "攻击")), range_limit, _auto_monster_color(slot), range_limit > MELEE_RANGE_METERS)
	_auto_monster_take_damage(target_slot, int(skill.get("damage", 0)), "%s·%s" % [String(actor.get("name", "怪兽")), String(skill.get("name", "攻击"))], slot)
	var knockback: float = float(skill.get("knockback", 0.0))
	if knockback > 0.5:
		_knockback_auto_monster_from_actor(target_slot, slot, knockback, String(skill.get("name", "攻击")))
	return true


func _command_auto_monster_reclaim_miasma(slot: int, skill: Dictionary) -> bool:
	var actor: Dictionary = auto_monsters[slot]
	var radius_m: float = float(skill.get("range", NEARBY_RADIUS_METERS))
	var max_tokens: int = int(skill.get("reclaim_count", 1))
	var candidates := _districts_in_radius(_entity_world_position(actor), radius_m, true)
	var reclaimed := 0
	for index in candidates:
		if reclaimed >= max_tokens:
			break
		if not districts[index]["miasma"]:
			continue
		districts[index]["miasma"] = false
		_pulse_district(index, Color("#22c55e"))
		reclaimed += 1
		_log("%s指挥怪%d·%s回收%s的瘴气。" % [
			String(skill.get("name", "瘴气回收")),
			slot + 1,
			String(actor.get("name", "怪兽")),
			districts[index]["name"],
		])
	if reclaimed <= 0:
		_log("%s范围内没有可回收的瘴气。" % String(skill.get("name", "瘴气回收")))
		return false
	actor["hp"] = min(int(actor.get("max_hp", 0)), int(actor.get("hp", 0)) + reclaimed)
	auto_monsters[slot] = actor
	return true


func _card_resolution_duration(_skill: Dictionary) -> float:
	if card_resolution_force_duration >= 0.0:
		return card_resolution_force_duration
	if DisplayServer.get_name().to_lower() == "headless":
		return 0.0
	return CARD_RESOLUTION_DISPLAY_SECONDS


func _card_simultaneous_window_duration() -> float:
	if card_resolution_force_simultaneous_window >= 0.0:
		return card_resolution_force_simultaneous_window
	if DisplayServer.get_name().to_lower() == "headless":
		return 0.0
	return CARD_SIMULTANEOUS_WINDOW_SECONDS


func _update_card_resolution_queue(delta: float) -> void:
	if not active_card_resolution.is_empty():
		card_resolution_timer = maxf(0.0, card_resolution_timer - delta)
		_show_card_resolution_overlay(active_card_resolution, card_resolution_timer)
		if card_resolution_timer <= 0.0:
			_complete_active_card_resolution()
		return
	if card_resolution_batch_locked:
		_start_next_card_resolution()
		return
	if card_resolution_queue.is_empty():
		_hide_card_resolution_overlay()
		return
	if card_resolution_simultaneous_timer > 0.0:
		card_resolution_simultaneous_timer = maxf(0.0, card_resolution_simultaneous_timer - delta)
	if card_resolution_auction_open:
		card_resolution_auction_timer = maxf(0.0, card_resolution_auction_timer - delta)
	_show_card_batch_lobby_overlay()
	if card_resolution_auction_open and card_resolution_auction_timer <= 0.0:
		_lock_card_resolution_batch()
	elif not card_resolution_auction_open and card_resolution_simultaneous_timer <= 0.0:
		_lock_card_resolution_batch()


func _update_pending_contract_offers(delta: float) -> void:
	var refresh_needed := false
	for i in range(pending_contract_offers.size() - 1, -1, -1):
		var offer: Dictionary = pending_contract_offers[i]
		if String(offer.get("contract_response", CONTRACT_RESPONSE_PENDING)) != CONTRACT_RESPONSE_PENDING:
			pending_contract_offers.remove_at(i)
			refresh_needed = true
			continue
		var previous_timer := maxf(0.0, float(offer.get("contract_decision_timer", CONTRACT_DECISION_SECONDS)))
		var next_timer := maxf(0.0, previous_timer - delta)
		offer["contract_decision_timer"] = next_timer
		pending_contract_offers[i] = offer
		if ceili(previous_timer * 10.0) != ceili(next_timer * 10.0):
			refresh_needed = true
		if next_timer > 0.0:
			continue
		pending_contract_offers.remove_at(i)
		offer["contract_response"] = CONTRACT_RESPONSE_TIMEOUT
		offer["contract_response_time"] = game_time
		var skill: Dictionary = offer.get("skill", {}) as Dictionary
		_apply_area_trade_contract({}, skill, offer)
		_store_pending_contract_result(offer)
		_log("匿名合约的独立5秒签约窗口结束：目标业主未回应，按超时拒签处理。")
		refresh_needed = true
	if refresh_needed:
		_refresh_ui()


func _is_card_resolution_busy() -> bool:
	return not active_card_resolution.is_empty() or not card_resolution_queue.is_empty() or not next_card_resolution_queue.is_empty()


func _queued_skill_from_entry(entry: Dictionary) -> Dictionary:
	var player_index := int(entry.get("player_index", -1))
	var slot_index := int(entry.get("slot_index", -1))
	if player_index >= 0 and player_index < players.size():
		var slots: Array = (players[player_index] as Dictionary).get("slots", [])
		if slot_index >= 0 and slot_index < slots.size() and slots[slot_index] is Dictionary:
			return (slots[slot_index] as Dictionary).duplicate(true)
	var snapshot: Variant = entry.get("skill", {})
	return (snapshot as Dictionary).duplicate(true) if snapshot is Dictionary else {}


func _clockwise_queue_distance(player_index: int, reference_player: int) -> int:
	var count := players.size()
	if count <= 1 or player_index < 0 or player_index >= count or reference_player < 0 or reference_player >= count:
		return 0
	if player_index == reference_player:
		return count
	var distance := (player_index - reference_player + count) % count
	return distance if distance > 0 else count


func _sort_card_resolution_queue() -> void:
	card_resolution_priority_reference_player = card_resolution_batch_reference_player
	card_resolution_queue.sort_custom(Callable(self, "_sort_card_resolution_entry_priority"))
	card_resolution_priority_reference_player = -1


func _entry_effective_card_bid(entry: Dictionary, _reference_player: int) -> int:
	return max(0, int(entry.get("tip", 0)))


func _highest_card_resolution_bid() -> int:
	var highest := 0
	for entry_variant in card_resolution_queue:
		if entry_variant is Dictionary:
			highest = maxi(highest, _entry_effective_card_bid(entry_variant as Dictionary, card_resolution_batch_reference_player))
	return highest


func _normalize_card_resolution_queue_bids(_reference_player: int) -> void:
	for i in range(card_resolution_queue.size()):
		var entry: Dictionary = card_resolution_queue[i]
		var player_index := int(entry.get("player_index", -1))
		if player_index < 0 or player_index >= players.size():
			entry["tip"] = 0
			card_resolution_queue[i] = entry
			continue
		var skill: Dictionary = _queued_skill_from_entry(entry)
		var reserve: int = _skill_play_cash_cost(skill)
		var affordable: int = maxi(0, int((players[player_index] as Dictionary).get("cash", 0)) - reserve)
		var normalized: int = mini(maxi(0, int(entry.get("tip", 0))), affordable)
		entry["tip"] = normalized
		card_resolution_queue[i] = entry


func _sort_card_resolution_entry_priority(a: Dictionary, b: Dictionary) -> bool:
	var tip_a := _entry_effective_card_bid(a, card_resolution_priority_reference_player)
	var tip_b := _entry_effective_card_bid(b, card_resolution_priority_reference_player)
	if tip_a != tip_b:
		return tip_a > tip_b
	var distance_a := _clockwise_queue_distance(int(a.get("player_index", -1)), card_resolution_priority_reference_player)
	var distance_b := _clockwise_queue_distance(int(b.get("player_index", -1)), card_resolution_priority_reference_player)
	if distance_a != distance_b:
		return distance_a < distance_b
	return int(a.get("queued_order", 0)) < int(b.get("queued_order", 0))


func _card_resolution_entry_card_label(entry: Dictionary) -> String:
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	var card_name := String(skill.get("name", "匿名卡牌"))
	var card_label := _card_display_name(card_name)
	return card_name if card_label == "" else card_label


func _last_resolved_card_resolution_entry() -> Dictionary:
	for i in range(resolved_card_history.size() - 1, -1, -1):
		var entry_variant: Variant = resolved_card_history[i]
		if entry_variant is Dictionary:
			return (entry_variant as Dictionary).duplicate(true)
	return {}


func _card_resolution_tip_clue_text(entry: Dictionary) -> String:
	var explicit_clue := String(entry.get("tip_payment_clue", ""))
	if explicit_clue != "":
		return explicit_clue
	var bid := int(entry.get("winning_bid", entry.get("tip", 0)))
	if bid <= 0:
		return ""
	var batch_position := int(entry.get("batch_position", 0))
	if batch_position <= 1:
		return "本批队首报价¥%d只决定排序；没有上一张匿名牌收款。" % bid
	var paid := int(entry.get("tip_paid_amount", 0))
	if paid > 0:
		var recipient_id := int(entry.get("tip_payment_recipient_resolution_id", -1))
		var recipient_label := String(entry.get("tip_payment_recipient_card", "上一张匿名牌"))
		var recipient_text := "上一张匿名牌"
		if recipient_id >= 0:
			recipient_text = "轨道#%d（%s）" % [recipient_id, recipient_label]
		elif recipient_label != "":
			recipient_text = recipient_label
		return "本张已私密支付¥%d给%s归属方；付款者与收款者身份仍匿名。" % [paid, recipient_text]
	return "锁定报价¥%d是公开排序线索；真实资金流只会反映在相关玩家私有账本。" % bid


func _transfer_card_resolution_tip(from_player: int, to_player: int, amount: int, card_label: String) -> int:
	if amount <= 0 or from_player < 0 or from_player >= players.size() or to_player < 0 or to_player >= players.size() or from_player == to_player:
		return 0
	var paid := mini(amount, int((players[from_player] as Dictionary).get("cash", 0)))
	if paid <= 0:
		return 0
	players[from_player]["cash"] = int(players[from_player].get("cash", 0)) - paid
	players[from_player]["total_card_spend"] = int(players[from_player].get("total_card_spend", 0)) + paid
	_record_player_economic_event(from_player, "卡牌小费", "竞价成交", -paid, "为%s取得下一结算位支付；收款者是上一张匿名卡牌的出牌者。" % card_label)
	_record_player_cash_snapshot(from_player)
	players[to_player]["cash"] = int(players[to_player].get("cash", 0)) + paid
	players[to_player]["total_card_income"] = int(players[to_player].get("total_card_income", 0)) + paid
	_record_player_economic_event(to_player, "卡牌小费", "匿名竞价收入", paid, "来自下一张结算卡；付款者不公开。")
	_record_player_cash_snapshot(to_player)
	return paid


func _area_trade_contract_context(skill: Dictionary, _player_index: int, source_index: int, target_index: int) -> Dictionary:
	var result := {
		"error": "",
		"source": source_index,
		"target": target_index,
		"target_owner": -1,
		"products": [],
	}
	var source := String(skill.get("name", "区域供需合约"))
	if not _valid_contract_source_district(source_index):
		result["error"] = "%s需要先在地图上设置一个未毁陆地供给区。" % source
		return result
	if not _valid_contract_target_district(target_index):
		result["error"] = "%s需要先在地图上设置一个有存活城市群的需求/签约区。" % source
		return result
	if source_index == target_index:
		result["error"] = "%s的供给区和需求区不能是同一区域。" % source
		return result
	var target_city := _district_city(target_index)
	var target_owner := int(target_city.get("owner", -1))
	if target_owner < 0 or target_owner >= players.size():
		result["error"] = "%s找不到目标城市真实业主，无法发起匿名签约。" % source
		return result
	var products := _area_trade_contract_products(skill, source_index, target_index)
	if products.is_empty():
		result["error"] = "%s没有可写入合约的商品。" % source
		return result
	result["target_owner"] = target_owner
	result["products"] = products
	return result


func _area_trade_contract_product_goal(skill: Dictionary) -> int:
	var add_products := maxi(0, int(skill.get("contract_add_products", 1)))
	var add_demands := maxi(0, int(skill.get("contract_add_demands", 1)))
	var requested := maxi(1, maxi(add_products, add_demands))
	if String(skill.get("contract_product_mode", "selected")) == "selected":
		return mini(requested, 1)
	return requested


func _area_trade_contract_products(skill: Dictionary, source_index: int, target_index: int) -> Array:
	var result := []
	var goal := _area_trade_contract_product_goal(skill)
	var explicit_products: Array = skill.get("contract_products", [])
	for product_variant in explicit_products:
		_append_unique_string(result, String(product_variant))
		if result.size() >= goal:
			return result
	var mode := String(skill.get("contract_product_mode", "selected"))
	if mode != "auto" and selected_trade_product != "" and PRODUCT_CATALOG.has(selected_trade_product):
		_append_unique_string(result, selected_trade_product)
		if mode == "selected" and result.size() >= goal:
			return result
	var source_city := _district_city(source_index)
	if _city_is_active(source_city):
		for product_name in _city_product_names(source_city):
			_append_unique_string(result, String(product_name))
			if result.size() >= goal:
				return result
	for product_variant in districts[source_index].get("products", []):
		_append_unique_string(result, String(product_variant))
		if result.size() >= goal:
			return result
	var target_city := _district_city(target_index)
	if _city_is_active(target_city):
		for demand_name in _city_demand_names(target_city):
			_append_unique_string(result, String(demand_name))
			if result.size() >= goal:
				return result
	for demand_variant in districts[target_index].get("demands", []):
		_append_unique_string(result, String(demand_variant))
		if result.size() >= goal:
			return result
	for catalog_variant in PRODUCT_CATALOG:
		_append_unique_string(result, String(catalog_variant))
		if result.size() >= goal:
			return result
	return result


func _queue_skill_resolution(player_index: int, slot_index: int, target_slot: int = -1) -> bool:
	if player_index < 0 or player_index >= players.size():
		return false
	var player: Dictionary = players[player_index]
	var slots: Array = player.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		return false
	if not (slots[slot_index] is Dictionary):
		return false
	var queue_to_next_batch := card_resolution_batch_locked \
		or not active_card_resolution.is_empty() \
		or (not card_resolution_queue.is_empty() and card_resolution_simultaneous_timer <= 0.0)
	var skill: Dictionary = slots[slot_index]
	var card_label := _card_display_name(String(skill.get("name", "")))
	if card_label == "":
		card_label = String(skill.get("name", "卡牌"))
	if bool(skill.get("queued_for_resolution", false)):
		_log("%s已经在结算队列中，不能重复提交。" % card_label)
		return false
	if queue_to_next_batch:
		if _next_batch_card_entry_index_for_player(player_index) >= 0:
			_log("当前玩家已经有一张牌在下一批等待区；该批开始前不能重复提交。")
			return false
	elif _queued_card_entry_index_for_player(player_index) >= 0:
		_log("当前玩家已有一张候补牌；本批0.5秒同时窗内不能提交第二张。")
		return false
	if not _can_play_skill_now(player_index, skill, true):
		return false
	var contract_context := {}
	if String(skill.get("kind", "")) == "area_trade_contract":
		contract_context = _area_trade_contract_context(skill, player_index, selected_contract_source_district, selected_contract_target_district)
		var contract_error := String(contract_context.get("error", ""))
		if contract_error != "":
			_log(contract_error)
			return false
	var desired_tip := maxi(0, int(player.get("queued_card_tip", 0))) if queue_to_next_batch else _selected_card_tip_amount(player_index)
	var play_cash_cost := _skill_play_cash_cost(skill)
	if desired_tip > 0 and int(player.get("cash", 0)) < play_cash_cost + desired_tip:
		_log("%s无法进入同时出牌窗：需要预留打出费用¥%d和匿名报价¥%d，当前资金不足。" % [card_label, play_cash_cost, desired_tip])
		return false
	var begins_new_batch := not queue_to_next_batch and card_resolution_queue.is_empty()
	if begins_new_batch:
		card_resolution_batch_reference_player = player_index
		last_card_resolution_player_index = -1
		card_resolution_simultaneous_timer = _card_simultaneous_window_duration()
		card_resolution_auction_timer = 0.0
		card_resolution_auction_open = false
	player["queued_card_tip"] = 0
	card_resolution_sequence += 1
	var queued_skill := skill.duplicate(true)
	queued_skill["queued_for_resolution"] = true
	var consumed_on_queue := not bool(skill.get("persistent", false))
	if consumed_on_queue:
		slots[slot_index] = null
	else:
		slots[slot_index] = queued_skill
	player["slots"] = slots
	players[player_index] = player
	var entry := {
		"player_index": player_index,
		"slot_index": slot_index,
		"target_slot": target_slot,
		"selected_district": selected_district,
		"selected_trade_product": selected_trade_product,
		"contract_source_district": int(contract_context.get("source", -1)),
		"contract_target_district": int(contract_context.get("target", -1)),
		"contract_target_owner": int(contract_context.get("target_owner", -1)),
		"contract_products": (contract_context.get("products", []) as Array).duplicate(true),
		"contract_response": CONTRACT_RESPONSE_PENDING if String(skill.get("kind", "")) == "area_trade_contract" else "",
		"contract_response_player": -1,
		"contract_response_time": -1.0,
		"queued_time": game_time,
		"queued_order": card_resolution_sequence,
		"resolution_id": card_resolution_sequence,
		"tip": desired_tip,
		"tip_recipient": -1,
		"queued_behind_resolution": queue_to_next_batch,
		"winning_bid": 0,
		"play_requirement_product": _skill_play_product(skill, player_index),
		"play_requirement_flow": _skill_play_flow_required(skill, player_index),
		"play_cash_cost": _skill_play_cash_cost(skill),
		"play_requirement_text": _skill_play_requirement_text(skill, player_index),
		"public_owner_revealed": false,
		"public_owner_label": "",
		"guessers": [],
		"consumed_on_queue": consumed_on_queue,
		"skill": queued_skill.duplicate(true),
	}
	if queue_to_next_batch:
		next_card_resolution_queue.append(entry)
		_log("匿名卡牌已提交到下一批等待区：%s；当前批次继续结算且不会重开竞价，清空后等待牌只统一竞价一次。" % card_label)
		_refresh_ui()
		return true
	card_resolution_queue.append(entry)
	if card_resolution_queue.size() >= 2 and not card_resolution_auction_open:
		card_resolution_auction_open = true
		card_resolution_auction_timer = _card_resolution_duration({})
		_sort_card_resolution_queue()
		_log("检测到0.5秒内有复数匿名出牌：本批%d张牌全部暂停结算，开启5秒公开竞价。" % card_resolution_queue.size())
	elif card_resolution_auction_open:
		_sort_card_resolution_queue()
		_log("又一张匿名卡在同时判定窗内加入本批｜公开报价¥%d。" % desired_tip)
	else:
		_log("匿名卡牌进入0.5秒同时判定窗：%s；若没有第二张牌，将直接进入自身公开展示。" % card_label)
	_show_card_batch_lobby_overlay()
	if card_resolution_simultaneous_timer <= 0.0 and not card_resolution_auction_open:
		_lock_card_resolution_batch()
	return true


func _lock_card_resolution_batch() -> void:
	if card_resolution_queue.is_empty() or not active_card_resolution.is_empty():
		return
	_normalize_card_resolution_queue_bids(card_resolution_batch_reference_player)
	if card_resolution_queue.size() > 1:
		_sort_card_resolution_queue()
	card_resolution_auction_open = false
	card_resolution_auction_timer = 0.0
	card_resolution_simultaneous_timer = 0.0
	card_resolution_batch_locked = true
	for i in range(card_resolution_queue.size()):
		var waiting: Dictionary = card_resolution_queue[i]
		waiting["batch_position"] = i + 1
		waiting["locked_bid"] = int(waiting.get("tip", 0))
		card_resolution_queue[i] = waiting
	if card_resolution_queue.size() > 1:
		_log("本轮5秒匿名竞价封盘：%d张牌已按报价与顺时针次序锁定，现在开始依次结算。" % card_resolution_queue.size())
	else:
		_log("0.5秒内没有第二张牌：这张匿名牌无需竞价，直接进入5秒公开展示。")
	_start_next_card_resolution()


func _start_next_card_resolution() -> void:
	if not active_card_resolution.is_empty():
		return
	if not card_resolution_batch_locked:
		return
	if card_resolution_queue.is_empty():
		_finish_card_resolution_batch()
		return
	var entry: Dictionary = card_resolution_queue.pop_front()
	var skill := _queued_skill_from_entry(entry)
	if skill.is_empty():
		_clear_queued_card_flag(entry)
		_start_next_card_resolution()
		return
	var reference_player := last_card_resolution_player_index
	var locked_bid := maxi(0, int(entry.get("tip", 0)))
	entry["winning_bid"] = locked_bid
	entry["tip_paid"] = false
	entry["tip_paid_amount"] = 0
	if locked_bid > 0 and reference_player >= 0 and reference_player != int(entry.get("player_index", -1)):
		var card_label := _card_display_name(String(skill.get("name", "卡牌")))
		var previous_entry := _last_resolved_card_resolution_entry()
		if not previous_entry.is_empty():
			entry["tip_payment_recipient_resolution_id"] = int(previous_entry.get("resolution_id", previous_entry.get("queued_order", -1)))
			entry["tip_payment_recipient_card"] = _card_resolution_entry_card_label(previous_entry)
		var paid := _transfer_card_resolution_tip(int(entry.get("player_index", -1)), reference_player, locked_bid, card_label)
		entry["tip_paid"] = paid > 0
		entry["tip_paid_amount"] = paid
		entry["tip_payment_clue"] = _card_resolution_tip_clue_text(entry)
		if paid > 0:
			_log("批次锁价结算：下一张牌按¥%d报价进入展示，并把小费私密转给前一张牌的出牌者。双方身份均不公开。" % paid)
	elif locked_bid > 0:
		entry["tip_payment_clue"] = _card_resolution_tip_clue_text(entry)
	entry["skill"] = skill.duplicate(true)
	entry["started_time"] = game_time
	active_card_resolution = entry
	card_resolution_visual_id = -1
	card_resolution_visual_stage = -1
	card_resolution_auction_open = false
	card_resolution_timer = _card_resolution_duration(skill)
	_show_card_resolution_overlay(active_card_resolution, card_resolution_timer)
	if card_resolution_timer <= 0.0:
		_complete_active_card_resolution()


func _show_card_batch_lobby_overlay() -> void:
	if card_resolution_overlay == null or card_resolution_queue.is_empty() or card_resolution_batch_locked:
		return
	card_resolution_overlay.visible = true
	_refresh_card_resolution_overlay_badges({})
	if card_resolution_auction_open:
		_sort_card_resolution_queue()
	if card_resolution_title_label != null:
		card_resolution_title_label.text = "匿名卡牌批次竞价" if card_resolution_auction_open else "同时出牌判定"
	if card_resolution_status_label != null:
		card_resolution_status_label.text = _card_resolution_phase_text()
	var leading: Dictionary = card_resolution_queue[0]
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
			_card_theme_color(skill),
			maxi(1, _skill_rank(card_name)),
			false,
			_card_art_stats(skill)
		)
	if card_resolution_body_label != null:
		var lobby_text := (
			"本批所有牌暂不结算。报价和卡面公开、出牌者匿名；5秒结束后一次性锁定全部顺序，批次中不再重拍。\n顶部轨道同步显示候补顺序，手牌区的加价按钮会改变当前玩家候补牌报价。"
			if card_resolution_auction_open
			else "系统正在用0.5秒窗口判断是否有复数玩家同时出牌；当前卡牌尚未结算。\n若没有第二张牌，它会直接进入5秒公开展示。"
		)
		var lobby_requirement := _card_resolution_play_requirement_text(leading)
		if lobby_requirement != "":
			lobby_text += "\n%s" % lobby_requirement.replace("打出条件：", "队首公开条件：")
		card_resolution_body_label.text = lobby_text


func _show_card_resolution_overlay(entry: Dictionary, seconds_left: float) -> void:
	if card_resolution_overlay == null:
		return
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	var card_name := String(skill.get("name", "卡牌"))
	var card_label := _card_display_name(card_name)
	if card_label == "":
		card_label = "匿名卡牌"
	card_resolution_overlay.visible = not active_card_resolution.is_empty() and seconds_left > 0.0
	if not card_resolution_overlay.visible:
		_refresh_card_resolution_overlay_badges({})
		return
	if card_resolution_title_label != null:
		card_resolution_title_label.text = card_label
	if card_resolution_status_label != null:
		card_resolution_status_label.text = _card_resolution_phase_text(entry, seconds_left)
	_refresh_card_resolution_overlay_badges(entry)
	_sync_card_resolution_stage_visual(entry, skill, seconds_left)
	if card_resolution_art != null and card_resolution_art.has_method("set_card"):
		card_resolution_art.call(
			"set_card",
			card_label,
			String(skill.get("kind", "")),
			_skill_tag_text(skill),
			_card_theme_color(skill),
			max(1, _skill_rank(card_name)),
			false,
			_card_art_stats(skill)
		)
	if card_resolution_body_label != null:
		card_resolution_body_label.text = "%s\n%s\n%s\n%s\n%s" % [
			_card_resolution_animation_text(card_name, skill, entry, seconds_left),
			_skill_display_text(skill),
			_card_resolution_contract_public_text(entry),
			_card_resolution_play_requirement_text(entry),
			"顶部轨道已锁定当前/候补顺序；本张展示期间不能加价，但新打出的牌会进入下一批等待区。",
		]


func _card_resolution_contract_public_text(entry: Dictionary) -> String:
	var skill: Dictionary = entry.get("skill", {}) as Dictionary
	if String(skill.get("kind", "")) != "area_trade_contract":
		return ""
	var source_index := int(entry.get("contract_source_district", -1))
	var target_index := int(entry.get("contract_target_district", -1))
	return "合约公开信息：%s → %s｜商品：%s｜回应：%s｜签约奖励：%s｜拒签惩罚：%s｜两端已在出牌前点选；本次前5秒只负责公开展示，展示结束后目标业主另有不阻塞出牌的5秒签/拒窗口。" % [
		_contract_district_short_name(source_index),
		_contract_district_short_name(target_index),
		_contract_entry_product_text(entry),
		_contract_response_public_label(entry),
		_contract_accept_effect_summary(skill),
		_contract_decline_effect_summary(skill),
	]


func _hide_card_resolution_overlay() -> void:
	if card_resolution_overlay != null:
		card_resolution_overlay.visible = false
	_refresh_card_resolution_overlay_badges({})
	card_resolution_visual_id = -1
	card_resolution_visual_stage = -1


func _complete_active_card_resolution() -> void:
	if active_card_resolution.is_empty():
		return
	var entry := active_card_resolution.duplicate(true)
	last_card_resolution_player_index = int(entry.get("player_index", last_card_resolution_player_index))
	active_card_resolution = {}
	card_resolution_auction_open = false
	card_resolution_timer = 0.0
	_hide_card_resolution_overlay()
	_resolve_queued_skill(entry)
	entry["resolved_time"] = game_time
	resolved_card_history.append(entry)
	while resolved_card_history.size() > CARD_RESOLUTION_HISTORY_LIMIT:
		resolved_card_history.pop_front()
	if not card_resolution_queue.is_empty():
		_start_next_card_resolution()
	else:
		_finish_card_resolution_batch()
	_refresh_ui()


func _finish_card_resolution_batch() -> void:
	var previous_player := last_card_resolution_player_index
	card_resolution_auction_open = false
	card_resolution_batch_locked = false
	card_resolution_simultaneous_timer = 0.0
	card_resolution_auction_timer = 0.0
	card_resolution_batch_reference_player = -1
	last_card_resolution_player_index = -1
	_hide_card_resolution_overlay()
	if not next_card_resolution_queue.is_empty():
		_promote_next_card_resolution_batch(previous_player)


func _promote_next_card_resolution_batch(previous_player: int) -> void:
	if next_card_resolution_queue.is_empty() or not active_card_resolution.is_empty() or not card_resolution_queue.is_empty():
		return
	card_resolution_queue = next_card_resolution_queue.duplicate(true)
	next_card_resolution_queue = []
	for i in range(card_resolution_queue.size()):
		var entry: Dictionary = card_resolution_queue[i]
		entry["queued_behind_resolution"] = false
		entry["promoted_time"] = game_time
		card_resolution_queue[i] = entry
	var first_entry: Dictionary = card_resolution_queue[0]
	var first_player := int(first_entry.get("player_index", -1))
	card_resolution_batch_reference_player = previous_player if previous_player >= 0 and previous_player < players.size() else first_player
	last_card_resolution_player_index = previous_player if previous_player >= 0 and previous_player < players.size() else -1
	card_resolution_simultaneous_timer = 0.0
	card_resolution_batch_locked = false
	if card_resolution_queue.size() > 1:
		card_resolution_auction_open = true
		card_resolution_auction_timer = _card_resolution_duration({})
		_sort_card_resolution_queue()
		_log("上一批已经清空：%d张等待牌合并为一个新批次，只开启这一次5秒匿名竞价；同价按上一张牌出牌者的顺时针席位排序。" % card_resolution_queue.size())
		_show_card_batch_lobby_overlay()
	else:
		card_resolution_auction_open = false
		card_resolution_auction_timer = 0.0
		_log("上一批已经清空：唯一一张等待牌直接进入自己的5秒公开展示，不额外等待0.5秒。")
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


func _resolve_queued_skill(entry: Dictionary) -> void:
	var player_index := int(entry.get("player_index", -1))
	var slot_index := int(entry.get("slot_index", -1))
	if player_index < 0 or player_index >= players.size():
		return
	var player: Dictionary = players[player_index]
	var slots: Array = player.get("slots", [])
	var skill: Dictionary = _queued_skill_from_entry(entry)
	if skill.is_empty():
		_log("一张匿名候补卡缺少卡面快照，结算取消。")
		return
	skill.erase("queued_for_resolution")
	var consumed_on_queue := bool(entry.get("consumed_on_queue", false))
	if not consumed_on_queue and slot_index >= 0 and slot_index < slots.size() and slots[slot_index] is Dictionary:
		slots[slot_index] = skill
		player["slots"] = slots
	players[player_index] = player
	var previous_contract_source := selected_contract_source_district
	var previous_contract_target := selected_contract_target_district
	if String(skill.get("kind", "")) == "area_trade_contract":
		selected_contract_source_district = int(entry.get("contract_source_district", selected_contract_source_district))
		selected_contract_target_district = int(entry.get("contract_target_district", selected_contract_target_district))
	if not _can_play_skill_now(player_index, skill, true):
		_log("%s公开展示后未能满足结算条件；%s本次不生效。" % [
			_card_display_name(String(skill.get("name", "卡牌"))),
			"已离手的一次性牌不会返还，" if consumed_on_queue else "固定技能保留，",
		])
		selected_contract_source_district = previous_contract_source
		selected_contract_target_district = previous_contract_target
		return
	var previous_player := selected_player
	var previous_district := selected_district
	var previous_trade_product := selected_trade_product
	selected_player = player_index
	selected_district = clampi(int(entry.get("selected_district", selected_district)), 0, max(0, districts.size() - 1))
	selected_trade_product = String(entry.get("selected_trade_product", selected_trade_product))
	var card_label := _card_display_name(String(skill.get("name", "")))
	if card_label == "":
		card_label = String(skill.get("name", "卡牌"))
	_log("匿名卡牌结算：%s（%s）。" % [card_label, _skill_play_requirement_text(skill, player_index)])
	var focused_actor := _selected_auto_monster_actor()
	_add_action_callout(
		"匿名卡牌",
		card_label,
		_card_resolution_animation_text(String(skill.get("name", "")), skill, entry, -1.0),
		Color("#fb7185"),
		_entity_world_position(focused_actor) if not focused_actor.is_empty() else _district_center(selected_district)
	)
	var resolved := true
	var target_slot := int(entry.get("target_slot", -1))
	if _skill_targets_monster(skill):
		if target_slot < 0 or target_slot >= auto_monsters.size() or bool((auto_monsters[target_slot] as Dictionary).get("down", false)):
			resolved = false
			_log("%s的目标怪兽已失效；%s未产生效果。" % [
				card_label,
				"已离手的一次性牌" if consumed_on_queue else "固定技能",
			])
		else:
			resolved = _resolve_targeted_skill(skill, player, target_slot, player_index)
	else:
		match skill["kind"]:
			"monster_card":
				resolved = _summon_monster_from_card(player, skill)
			"monster_bound_action":
				resolved = _trigger_bound_monster_skill(skill, player)
			"city_revenue_boost":
				resolved = _boost_selected_city_revenue(int(skill.get("revenue_amount", 40)), int(skill.get("panic", 0)), skill["name"])
			"cash_gain":
				var cash_gain: int = int(skill.get("cash", 0))
				player["cash"] += cash_gain
				_record_player_card_income(player_index, cash_gain, String(skill.get("name", "资金卡")), "直接资金")
				_log("匿名资金牌结算：一名未公开玩家获得%d资金。" % cash_gain)
			"product_speculation":
				resolved = _apply_product_speculation(player, skill)
			"city_gdp_derivative":
				resolved = _apply_city_gdp_derivative(player, skill)
			"product_contract_boon":
				resolved = _apply_product_contract_boon(player, skill)
			"area_trade_contract":
				resolved = _apply_area_trade_contract(player, skill, entry)
			"route_insurance":
				resolved = _apply_route_insurance(player, skill)
			"city_product_upgrade":
				resolved = _apply_city_product_upgrade(player, skill)
			"city_product_shift":
				resolved = _apply_city_product_shift(player, skill)
			"city_demand_shift":
				resolved = _apply_city_demand_shift(player, skill)
			"market_stabilize":
				resolved = _apply_market_stabilize(skill)
			"product_growth_boon":
				resolved = _apply_product_growth_boon(skill)
			"route_flow_boon":
				resolved = _apply_route_flow_boon(player, skill)
			"region_economy_shift":
				resolved = _apply_region_economy_shift(skill)
			"city_contract_boon":
				resolved = _apply_city_contract_boon(player, skill)
			"route_sabotage":
				resolved = _apply_route_sabotage(skill)
			"intel_city_reveal":
				resolved = _apply_intel_city_reveal(player, skill)
			"intel_card_trace":
				resolved = _apply_intel_card_trace(player, skill)
			"intel_contract_trace":
				resolved = _apply_intel_contract_trace(player, skill)
			"card_access_boon":
				resolved = _apply_card_access_boon(player, skill)
			"panic_shift":
				_add_panic(selected_district, int(skill.get("panic", 0)), skill["name"])
			"supply_draw":
				_draw_extra_district_cards(player, int(skill.get("draw_amount", 1)), skill["name"])
			_:
				resolved = false
				_log("%s暂未接入结算器，卡牌未消耗。" % card_label)
	if resolved:
		var finish_slot_index := -1 if consumed_on_queue else slot_index
		_finish_played_skill(player_index, finish_slot_index, skill, COMMAND_COOLDOWN)
	_add_card_resolution_aftermath_clue(entry, skill, resolved)
	selected_player = clampi(previous_player, 0, max(0, players.size() - 1))
	selected_district = clampi(previous_district, 0, max(0, districts.size() - 1))
	selected_trade_product = previous_trade_product
	selected_contract_source_district = previous_contract_source
	selected_contract_target_district = previous_contract_target


func _use_skill(slot_index: int) -> void:
	if _has_pending_target_choice():
		_log("请先完成当前卡牌的目标怪兽选择。")
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
	var card_label := _card_display_name(String(skill.get("name", "")))
	if card_label == "":
		card_label = String(skill.get("name", "卡牌"))
	if float(skill.get("lock_left", 0.0)) > 0.0:
		_log("%s仍被麻痹封锁，%.1fs后才能打出。" % [card_label, float(skill["lock_left"])])
		return
	if float(skill.get("cooldown_left", 0.0)) > 0.0:
		_log("%s仍在冷却，%.1fs后才能再次释放。" % [card_label, float(skill["cooldown_left"])])
		return
	if bool(skill.get("queued_for_resolution", false)):
		_log("%s已经在匿名结算轨道上。" % card_label)
		return
	if _skill_targets_monster(skill) and auto_monsters.is_empty():
		_log("%s需要指定一只在场怪兽；当前没有合法目标，卡牌未消耗。" % card_label)
		return
	if not _can_play_skill_now(selected_player, skill, true):
		return
	if _skill_requires_target_monster(skill):
		_begin_target_monster_choice(slot_index)
		return
	_queue_skill_resolution(selected_player, slot_index, -1)
	_refresh_ui()


func _add_panic(index: int, amount: int, source: String) -> void:
	if index < 0 or index >= districts.size():
		return
	var d: Dictionary = districts[index]
	if d["destroyed"] or amount <= 0:
		return
	d["panic"] = min(100, int(d["panic"]) + amount)
	_pulse_district(index, Color("#f97316"))
	_log("%s使%s热度+%d。" % [source, d["name"], amount])
	if int(d["panic"]) >= 100:
		d["panic"] = 60
		_damage_district(index, 1, "%s引发恐慌" % source)


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
	if gained > 0:
		_log("%s额外获取%d张区域候选卡。" % [source, gained])
	else:
		_log("%s没有成功获取额外卡牌。" % source)


func _world_event() -> void:
	var index := _weighted_event_district()
	if index < 0:
		_finish_game("所有区域都已破坏。")
		return
	var d: Dictionary = districts[index]
	var heat_min: int = _preset_int("event_heat_min")
	var heat_max: int = _preset_int("event_heat_max")
	var heat: int = rng.randi_range(heat_min, heat_max)
	d["panic"] = min(100, d["panic"] + heat)
	_log("星际商业新闻涌向%s：曝光热度+%d，怪兽关注上升。" % [d["name"], heat])
	_add_action_callout(
		"星际商业新闻",
		"区域曝光",
		"%s热度+%d，城市越活跃越容易成为怪兽目标。" % [d["name"], heat],
		Color("#fbbf24"),
		_district_center(index)
	)
	if d["panic"] >= 100:
		d["panic"] = 60
		_damage_district(index, 1, "民众恐慌")


func _auto_monster_lure_target(actor: Dictionary) -> int:
	var moves_left := int(actor.get("lure_moves_left", 0))
	var target := int(actor.get("lure_target_district", -1))
	if moves_left <= 0 or target < 0 or target >= districts.size():
		return -1
	if bool(districts[target].get("destroyed", false)):
		return -1
	return target


func _consume_auto_monster_lure(actor: Dictionary) -> Dictionary:
	if int(actor.get("lure_moves_left", 0)) <= 0:
		return actor
	actor["lure_moves_left"] = maxi(0, int(actor.get("lure_moves_left", 0)) - 1)
	if int(actor.get("lure_moves_left", 0)) <= 0:
		actor.erase("lure_target_district")
		actor.erase("lure_moves_left")
		actor.erase("lure_source")
	return actor


func _auto_monster_movement_tick() -> void:
	var acted := 0
	for slot in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[slot]
		if bool(actor.get("down", false)):
			continue
		var target := _weighted_auto_monster_target(actor)
		var lure_target := _auto_monster_lure_target(actor)
		var lure_source := String(actor.get("lure_source", "匿名诱导"))
		var was_lured := lure_target >= 0
		if was_lured:
			target = lure_target
			actor = _consume_auto_monster_lure(actor)
		if target < 0:
			continue
		var before := _entity_world_position(actor)
		var moved := 0.0
		var path_damage_done := 0
		if target != int(actor.get("position", -1)):
			moved = _move_entity_toward(actor, _district_center(target), _auto_monster_move_budget(actor, target) * AUTO_MONSTER_MOVE_RATIO)
		if moved > 0.5:
			var movement_label := "怪%d诱导" % (slot + 1) if was_lured else "怪%d自动" % (slot + 1)
			var movement_reason := "被%s诱导" % lure_source if was_lured else _auto_monster_target_factor_summary(actor, target)
			_add_visual_trail(before, _entity_world_position(actor), _auto_monster_color(slot), movement_label)
			_log("怪%d·%s%s向%s移动%s，进入%s（%s）。" % [
				slot + 1,
				String(actor.get("name", "怪兽")),
				"被%s诱导" % lure_source if was_lured else "按概率",
				districts[target]["name"],
				_meters_text(moved),
				districts[int(actor["position"])]["name"],
				movement_reason,
			])
			_add_action_callout(
				"自动怪兽%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
				"诱导移动" if was_lured else "自动移动",
				"%s向%s移动%s，进入%s；%s。" % [
					"被%s诱导" % lure_source if was_lured else "按概率",
					districts[target]["name"],
					_meters_text(moved),
					districts[int(actor["position"])]["name"],
					"诱导只生效一次，怪兽之后继续随机行动" if was_lured else "主因:%s" % _auto_monster_target_factor_summary(actor, target),
				],
				_auto_monster_color(slot),
				_entity_world_position(actor)
			)
			path_damage_done = _apply_auto_monster_path_effects(actor, before, _entity_world_position(actor), "诱导移动" if was_lured else "自动移动", _auto_monster_movement_mode(actor))
		else:
			_log("怪%d·%s%s停留在%s并继续施压（%s）。" % [
				slot + 1,
				String(actor.get("name", "怪兽")),
				"被%s诱导后" % lure_source if was_lured else "",
				districts[int(actor["position"])]["name"],
				"诱导目标已在脚下" if was_lured else _auto_monster_target_factor_summary(actor, target),
			])
			_add_action_callout(
				"自动怪兽%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
				"诱导停留" if was_lured else "自动停留",
				"停留在%s并继续施压；%s。" % [
					districts[int(actor["position"])]["name"],
					"诱导已消耗" if was_lured else "按当前概率表",
				],
				_auto_monster_color(slot),
				_entity_world_position(actor)
			)
		var landing_damage := _auto_monster_move_damage(actor, _auto_monster_movement_mode(actor))
		if landing_damage > 0 and (moved <= 0.5 or path_damage_done <= 0):
			_damage_district(int(actor["position"]), landing_damage, "%s自动破坏" % String(actor.get("name", "怪兽")))
		_auto_monster_resource_drain(actor, int(actor["position"]), "自动移动")
		auto_monsters[slot] = actor
		_resolve_auto_monster_encounter(slot, "同区遭遇")
		acted += 1
	if acted <= 0:
		_log("当前没有可行动怪兽；城市经营继续，等待怪兽复活、到期离场或后续召唤。")
		return
	_refresh_ui()


func _next_active_auto_monster_slot() -> int:
	if auto_monsters.is_empty():
		return -1
	for offset in range(auto_monsters.size()):
		var slot: int = (next_special_monster_slot + offset) % auto_monsters.size()
		var actor: Dictionary = auto_monsters[slot]
		if bool(actor.get("down", false)):
			continue
		next_special_monster_slot = (slot + 1) % auto_monsters.size()
		return slot
	return -1


func _auto_special_monster_tick() -> void:
	var slot := _next_active_auto_monster_slot()
	if slot < 0:
		_log("当前没有可执行特殊行动的怪兽；计时器等待下一只活跃怪兽。")
		return
	_auto_special_monster_tick_for_slot(slot)
	_refresh_ui()


func _auto_special_monster_tick_for_slot(slot: int) -> void:
	var actor: Dictionary = auto_monsters[slot]
	if bool(actor.get("down", false)):
		return
	var actions := _auto_monster_actions(actor)
	var any_destroyed := _has_destroyed_district()
	var weights := _auto_monster_action_weights(actor, any_destroyed)
	var action_index := _weighted_pick_index(weights)
	if action_index < 0:
		return
	var action: Dictionary = actions[action_index]
	var total := _weight_total(weights)
	var target := _weighted_auto_monster_target(actor)
	if target < 0:
		return
	var before := _entity_world_position(actor)
	var required_range: float = float(action.get("range", 0.0))
	var move_budget: float = float(action.get("move_override", -1.0))
	if move_budget < 0.0:
		move_budget = float(actor.get("move", MONSTER_RAMPAGE_MOVE_METERS))
	move_budget *= _monster_terrain_move_multiplier(actor, target)
	if required_range <= 0.0 or _entity_distance_to_district(actor, target) > required_range:
		_move_entity_toward(actor, _district_center(target), move_budget)
	var moved: float = _wrapped_distance(before, _entity_world_position(actor))
	if moved > 0.5:
		_add_visual_trail(before, _entity_world_position(actor), _auto_monster_color(slot), String(action.get("name", "行动")))
		_apply_auto_monster_path_effects(actor, before, _entity_world_position(actor), String(action.get("name", "行动")), _auto_monster_movement_mode(actor))
	var target_after_move: int = target
	if required_range <= 0.0:
		target_after_move = int(actor.get("position", target))
	var district_in_range: bool = required_range <= 0.0 or _entity_distance_to_district(actor, target_after_move) <= required_range
	var district_damage: int = max(AUTO_MONSTER_MIN_SPECIAL_DAMAGE, int(ceil(float(action.get("damage", 1)) * 0.5)))
	_log("怪%d·%s概率模拟选择：%s（%s），目标%s（%s）。%s" % [
		slot + 1,
		String(actor.get("name", "怪兽")),
		String(action.get("name", "行动")),
		_auto_monster_action_probability_text(actor, action_index, weights, total, any_destroyed),
		districts[target_after_move]["name"] if target_after_move >= 0 and target_after_move < districts.size() else "未知区域",
		_auto_monster_target_factor_summary(actor, target_after_move),
		String(action.get("text", "")),
	])
	_add_action_callout(
		"自动怪兽%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
		String(action.get("name", "行动")),
		"目标%s；%s" % [
			districts[target_after_move]["name"] if target_after_move >= 0 and target_after_move < districts.size() else "未知区域",
			String(action.get("text", "")),
		],
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)
	if district_in_range:
		_add_monster_attack_effect(_entity_world_position(actor), _district_center(target_after_move), String(action.get("name", "行动")), required_range, _auto_monster_color(slot), required_range > MELEE_RANGE_METERS)
		_damage_district(target_after_move, district_damage, "%s·%s" % [String(actor.get("name", "怪兽")), String(action.get("name", "行动"))])
		_auto_monster_resource_drain(actor, target_after_move, String(action.get("name", "行动")))
		var panic_gain := int(action.get("panic", 0))
		if panic_gain > 0:
			_add_panic(target_after_move, panic_gain, String(action.get("name", "行动")))
		_place_auto_miasma(actor, target_after_move, int(action.get("miasma_count", 0)), String(action.get("name", "行动")))
	else:
		_log("%s距离%s过远，特殊行动只完成移动未命中城区。" % [
			String(actor.get("name", "怪兽")),
			districts[target_after_move]["name"],
		])
	var armor_gain := int(action.get("armor", 0))
	if armor_gain > 0:
		actor["armor"] = int(actor.get("armor", 0)) + armor_gain
		_log("%s通过%s获得%d点护甲。" % [String(actor.get("name", "怪兽")), String(action.get("name", "行动")), armor_gain])
	var self_heal := int(action.get("self_heal", 0))
	if self_heal > 0:
		actor["hp"] = min(int(actor.get("max_hp", 0)), int(actor.get("hp", 0)) + self_heal)
		_log("%s通过%s回复%d HP。" % [String(actor.get("name", "怪兽")), String(action.get("name", "行动")), self_heal])
	var self_damage := int(action.get("self_damage", 0))
	auto_monsters[slot] = actor
	var hit_other := false
	if int(action.get("damage", 0)) > 0:
		hit_other = _try_auto_monster_hit_other(slot, action)
	if not hit_other:
		_resolve_auto_monster_encounter(slot, "资源争夺")
	if self_damage > 0:
		_auto_monster_take_damage(slot, self_damage, "%s反冲" % String(action.get("name", "行动")), -1)


func _monster_has_trait(actor: Dictionary, trait_name: String) -> bool:
	var traits: Array = actor.get("movement_traits", []) as Array
	return traits.has(trait_name)


func _monster_movement_mode(actor: Dictionary) -> String:
	if _monster_has_trait(actor, "flying"):
		return "fly"
	if _monster_has_trait(actor, "aquatic"):
		return "aquatic"
	return "walk"


func _auto_monster_movement_mode(actor: Dictionary) -> String:
	return _monster_movement_mode(actor)


func _monster_terrain_move_multiplier(actor: Dictionary, district_index: int) -> float:
	var multipliers: Dictionary = actor.get("terrain_move_multiplier", {}) as Dictionary
	if district_index < 0 or district_index >= districts.size():
		return float(multipliers.get("default", 1.0))
	var terrain := String(districts[district_index].get("terrain", "land"))
	return maxf(0.2, float(multipliers.get(terrain, multipliers.get("default", 1.0))))


func _auto_monster_move_budget(actor: Dictionary, target_index: int) -> float:
	return float(actor.get("move", MONSTER_RAMPAGE_MOVE_METERS)) * _monster_terrain_move_multiplier(actor, target_index)


func _auto_monster_move_damage(actor: Dictionary, movement_mode: String = "") -> int:
	var mode := movement_mode if movement_mode != "" else _auto_monster_movement_mode(actor)
	if mode == "fly" or _monster_has_trait(actor, "flying"):
		return 0
	return max(_preset_int("monster_damage"), int(actor.get("move_damage", AUTO_MONSTER_DEFAULT_MOVE_DAMAGE)))


func _auto_monster_collision_damage(actor: Dictionary) -> int:
	return max(AUTO_MONSTER_DEFAULT_COLLISION_DAMAGE, int(actor.get("collision_damage", AUTO_MONSTER_DEFAULT_COLLISION_DAMAGE)))


func _path_district_indices_between(from_position: Vector2, to_position: Vector2, final_index: int = -1, max_regions: int = AUTO_MONSTER_PATH_DAMAGE_MAX_REGIONS) -> Array:
	var result := []
	_append_unique_district_index(result, _district_at_point(from_position))
	var distance := _wrapped_distance(from_position, to_position)
	var steps: int = max(1, int(ceil(distance / AUTO_MONSTER_PATH_DAMAGE_STEP_METERS)))
	for step in range(1, steps):
		var sample := _spherical_lerp_world(from_position, to_position, float(step) / float(steps))
		_append_unique_district_index(result, _district_at_point(sample))
	var end_index := final_index
	if end_index < 0:
		end_index = _district_at_point(to_position)
	if end_index < 0:
		end_index = _nearest_district_to(to_position)
	_append_unique_district_index(result, end_index)
	while result.size() > max_regions and result.size() > 2:
		result.remove_at(result.size() - 2)
	return result


func _damage_districts_on_monster_path(actor: Dictionary, from_position: Vector2, to_position: Vector2, amount: int, source: String, max_regions: int = AUTO_MONSTER_PATH_DAMAGE_MAX_REGIONS) -> int:
	if amount <= 0:
		return 0
	var applied := 0
	var indices := _path_district_indices_between(from_position, to_position, int(actor.get("position", -1)), max_regions)
	for index_variant in indices:
		var index := int(index_variant)
		if index < 0 or index >= districts.size() or bool(districts[index].get("destroyed", false)):
			continue
		_damage_district(index, amount, source)
		applied += amount
	return applied


func _apply_auto_monster_path_effects(actor: Dictionary, from_position: Vector2, to_position: Vector2, source: String, movement_mode: String = "") -> int:
	if movement_mode == "fly" or _monster_has_trait(actor, "flying"):
		_log("%s以飞行路线穿越区域，未造成路径碾压破坏。" % String(actor.get("name", "怪兽")))
		return 0
	var damage_source := "%s·%s移动碾压" % [String(actor.get("name", "怪兽")), source]
	var applied_damage := _damage_districts_on_monster_path(actor, from_position, to_position, _auto_monster_move_damage(actor, movement_mode), damage_source)
	if applied_damage > 0:
		_log("%s沿途造成合计%d点区域/城市破坏。" % [damage_source, applied_damage])
		_add_action_callout(
			String(actor.get("name", "怪兽")),
			"路径破坏",
			"%s沿移动路径造成合计%d点区域伤害。" % [source, applied_damage],
			Color("#fb7185"),
			_entity_world_position(actor)
		)
	if String(actor.get("name", "")) != "尸套龙":
		return applied_damage
	var candidates := []
	_append_unique_district_index(candidates, _district_at_point(from_position))
	_append_unique_district_index(candidates, _nearest_district_to((from_position + to_position) * 0.5))
	_append_unique_district_index(candidates, int(actor.get("position", -1)))
	for index in candidates:
		if index < 0 or index >= districts.size():
			continue
		if districts[index]["destroyed"] or districts[index]["miasma"]:
			continue
		districts[index]["miasma"] = true
		_pulse_district(index, Color("#a855f7"))
		_log("%s使尸套龙沿路径在%s留下瘴气。" % [source, districts[index]["name"]])
		return applied_damage
	return applied_damage


func _place_auto_miasma(actor: Dictionary, center_index: int, max_tokens: int, source: String) -> void:
	if max_tokens <= 0:
		return
	var candidates := _districts_in_radius(_district_center(center_index), 260.0, true)
	var placed := 0
	for index in candidates:
		if placed >= max_tokens:
			break
		if districts[index]["destroyed"] or districts[index]["miasma"]:
			continue
		districts[index]["miasma"] = true
		_pulse_district(index, Color("#a855f7"))
		placed += 1
		_log("%s在%s散布瘴气。" % [source, districts[index]["name"]])


func _try_auto_monster_hit_other(slot: int, action: Dictionary) -> bool:
	var target_slot := _nearest_other_auto_monster_slot(slot)
	if target_slot < 0:
		return false
	var actor: Dictionary = auto_monsters[slot]
	var target: Dictionary = auto_monsters[target_slot]
	var range_limit: float = float(action.get("range", MELEE_RANGE_METERS))
	if range_limit <= 0.0:
		range_limit = MELEE_RANGE_METERS
	if _wrapped_distance(_entity_world_position(actor), _entity_world_position(target)) > range_limit:
		return false
	return _auto_monster_use_action_on_other(slot, target_slot, action, "招式命中")


func _auto_monster_brawl_action(slot: int, target_slot: int) -> Dictionary:
	if slot < 0 or slot >= auto_monsters.size() or target_slot < 0 or target_slot >= auto_monsters.size():
		return {}
	var actor: Dictionary = auto_monsters[slot]
	var target: Dictionary = auto_monsters[target_slot]
	var distance := _wrapped_distance(_entity_world_position(actor), _entity_world_position(target))
	var actions := _auto_monster_actions(actor)
	var candidates := []
	var weights := []
	for action_variant in actions:
		var action: Dictionary = action_variant
		var damage := int(action.get("damage", 0))
		if damage <= 0:
			continue
		var range_limit: float = float(action.get("range", MELEE_RANGE_METERS))
		if range_limit <= 0.0:
			range_limit = MELEE_RANGE_METERS
		if distance > range_limit:
			continue
		candidates.append(action)
		weights.append(max(1, damage * 3 + int(round(float(action.get("knockback", 0.0)) / 80.0))))
	if candidates.is_empty():
		return {
			"name": "资源争夺撞击",
			"range": AUTO_MONSTER_ENCOUNTER_RANGE_METERS,
			"damage": _auto_monster_collision_damage(actor),
			"knockback": 100.0,
			"text": "怪兽在同一区域争夺资源，发生基础撞击。",
		}
	var picked := _weighted_pick_index(weights)
	return candidates[max(0, picked)] as Dictionary


func _monster_resource_matches(actor: Dictionary, index: int) -> Array:
	var result := []
	if index < 0 or index >= districts.size():
		return result
	var focus: Array = actor.get("resource_focus", [])
	if focus.is_empty():
		return result
	var resource_pool := []
	for product_variant in districts[index].get("products", []):
		_append_unique_string(resource_pool, String(product_variant))
	for demand_variant in districts[index].get("demands", []):
		_append_unique_string(resource_pool, String(demand_variant))
	var city := _district_city(index)
	if _city_is_active(city):
		for product_name in _city_product_names(city):
			_append_unique_string(resource_pool, String(product_name))
		for demand_name in _city_demand_names(city):
			_append_unique_string(resource_pool, String(demand_name))
	for focus_variant in focus:
		var product_name := String(focus_variant)
		if product_name == "":
			continue
		if resource_pool.has(product_name):
			_append_unique_string(result, product_name)
			continue
		for route_variant in _trade_routes_for_product(product_name):
			var route: Dictionary = route_variant
			if (route.get("path", []) as Array).has(index):
				_append_unique_string(result, product_name)
				break
	return result


func _auto_monster_resource_drain(actor: Dictionary, index: int, source: String) -> int:
	if index < 0 or index >= districts.size() or bool(districts[index].get("destroyed", false)):
		return 0
	var drain_damage := int(actor.get("resource_drain", 0))
	if drain_damage <= 0:
		return 0
	var matches := _monster_resource_matches(actor, index)
	if matches.is_empty():
		return 0
	var match_text := _limited_name_list(matches, 4, "未知资源")
	_damage_district(index, drain_damage, "%s资源吸取" % String(actor.get("name", "怪兽")))
	_log("%s在%s吸取%s，额外造成%d点区域/城市伤害。" % [
		String(actor.get("name", "怪兽")),
		districts[index]["name"],
		match_text,
		drain_damage,
	])
	_add_action_callout(
		String(actor.get("name", "怪兽")),
		"资源吸取",
		"%s被%s吸引，额外造成%d点伤害。" % [match_text, source, drain_damage],
		Color("#f97316"),
		_district_center(index)
	)
	return drain_damage


func _append_unique_string(result: Array, value: String) -> void:
	if value == "":
		return
	if not result.has(value):
		result.append(value)


func _auto_monster_use_action_on_other(slot: int, target_slot: int, action: Dictionary, context: String) -> bool:
	if slot < 0 or slot >= auto_monsters.size() or target_slot < 0 or target_slot >= auto_monsters.size():
		return false
	var actor: Dictionary = auto_monsters[slot]
	var target: Dictionary = auto_monsters[target_slot]
	if bool(actor.get("down", false)) or bool(target.get("down", false)):
		return false
	var distance := _wrapped_distance(_entity_world_position(actor), _entity_world_position(target))
	var range_limit: float = float(action.get("range", MELEE_RANGE_METERS))
	if range_limit <= 0.0:
		range_limit = MELEE_RANGE_METERS
	if distance > range_limit:
		return false
	var action_name := String(action.get("name", "攻击"))
	var source := "%s·%s" % [String(actor.get("name", "怪兽")), action_name]
	var district_index := int(actor.get("position", -1))
	var resource_text := ""
	var matches := _monster_resource_matches(actor, district_index)
	if not matches.is_empty():
		resource_text = "，争夺资源：%s" % _limited_name_list(matches, 3, "未知资源")
	_log("怪%d·%s在%s与怪%d·%s相遇，%s使用%s%s。" % [
		slot + 1,
		String(actor.get("name", "怪兽")),
		districts[district_index]["name"] if district_index >= 0 and district_index < districts.size() else "未知区域",
		target_slot + 1,
		String(target.get("name", "怪兽")),
		context,
		action_name,
		resource_text,
	])
	_add_action_callout(
		"怪%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
		action_name,
		"遭遇怪%d·%s，造成%d伤害%s。" % [
			target_slot + 1,
			String(target.get("name", "怪兽")),
			int(action.get("damage", 0)),
			"，击退%s" % _meters_text(float(action.get("knockback", 0.0))) if float(action.get("knockback", 0.0)) > 0.5 else "",
		],
		_auto_monster_color(slot),
		_entity_world_position(actor)
	)
	_add_monster_attack_effect(_entity_world_position(actor), _entity_world_position(target), action_name, range_limit, _auto_monster_color(slot), range_limit > MELEE_RANGE_METERS)
	var outgoing_damage := int(action.get("damage", 0)) + _auto_monster_damage_bonus_from_passives(slot)
	_auto_monster_take_damage(target_slot, outgoing_damage, source, slot)
	if target_slot < auto_monsters.size() and _is_auto_mebius_energy_active(target_slot) and range_limit <= MELEE_RANGE_METERS:
		_maybe_announce_auto_mebius_energy(target_slot)
		_auto_monster_take_damage(slot, MEBIUS_ENERGY_FLAME_DAMAGE, "%s梦比姆反焰" % action_name, target_slot)
	var knockback := float(action.get("knockback", 0.0))
	if knockback > 0.5 and target_slot < auto_monsters.size():
		_knockback_auto_monster_from_actor(target_slot, slot, knockback, action_name)
	return true


func _resolve_auto_monster_encounter(slot: int, context: String) -> bool:
	var target_slot := _nearest_other_auto_monster_slot(slot)
	if target_slot < 0:
		return false
	var actor: Dictionary = auto_monsters[slot]
	var target: Dictionary = auto_monsters[target_slot]
	var distance := _wrapped_distance(_entity_world_position(actor), _entity_world_position(target))
	if distance > AUTO_MONSTER_ENCOUNTER_RANGE_METERS:
		return false
	var action := _auto_monster_brawl_action(slot, target_slot)
	if action.is_empty():
		return false
	return _auto_monster_use_action_on_other(slot, target_slot, action, context)


func _nearest_other_auto_monster_slot(slot: int) -> int:
	if slot < 0 or slot >= auto_monsters.size():
		return -1
	var actor: Dictionary = auto_monsters[slot]
	var best_slot := -1
	var best_distance := INF
	for i in range(auto_monsters.size()):
		if i == slot:
			continue
		var other: Dictionary = auto_monsters[i]
		if bool(other.get("down", false)):
			continue
		var distance := _wrapped_distance(_entity_world_position(actor), _entity_world_position(other))
		if distance < best_distance:
			best_distance = distance
			best_slot = i
	return best_slot


func _auto_monster_take_damage(slot: int, damage: int, source: String, source_slot: int) -> void:
	if slot < 0 or slot >= auto_monsters.size() or damage <= 0:
		return
	var actor: Dictionary = auto_monsters[slot]
	if bool(actor.get("down", false)):
		return
	var remaining := damage
	var armor := int(actor.get("armor", 0))
	if armor > 0:
		var absorbed: int = min(armor, remaining)
		actor["armor"] = armor - absorbed
		remaining -= absorbed
		_log("%s护甲抵消%d点%s伤害。" % [String(actor.get("name", "怪兽")), absorbed, source])
	auto_monsters[slot] = actor
	_maybe_announce_auto_hikari_revenge_armor(slot)
	actor = auto_monsters[slot]
	if remaining > 0 and _is_auto_hikari_revenge_armor_active(slot):
		var armor_reduced: int = min(remaining, HIKARI_REVENGE_DAMAGE_REDUCTION)
		remaining = max(0, remaining - armor_reduced)
		_log("复仇之铠抵消%d点%s伤害。" % [armor_reduced, source])
	actor["hp"] = int(actor.get("hp", 0)) - remaining
	_log("%s对怪%d·%s造成%d伤害。" % [
		source,
		slot + 1,
		String(actor.get("name", "怪兽")),
		remaining,
	])
	auto_monsters[slot] = actor
	if remaining > 0:
		_apply_owner_damage_cash_loss(slot, remaining, source)
		actor = auto_monsters[slot]
	_maybe_announce_auto_mebius_energy(slot)
	actor = auto_monsters[slot]
	if int(actor.get("hp", 0)) <= 0:
		actor["hp"] = 0
		if _try_start_auto_monster_revival(slot, source, actor):
			return
		actor["down"] = true
		_invalidate_bound_monster_skills(int(actor.get("uid", 0)))
		_log("怪%d·%s倒地，之后不再自动行动。" % [slot + 1, String(actor.get("name", "怪兽"))])
		_add_action_callout(
			"自动怪兽%d·%s" % [slot + 1, String(actor.get("name", "怪兽"))],
			"倒地",
			"%s造成致命伤害，停止自动行动。" % source,
			Color("#94a3b8"),
			_entity_world_position(actor)
		)
	auto_monsters[slot] = actor


func _knockback_auto_monster_from_actor(target_slot: int, source_slot: int, distance_m: float, source: String) -> void:
	if target_slot < 0 or target_slot >= auto_monsters.size() or source_slot < 0 or source_slot >= auto_monsters.size():
		return
	var target: Dictionary = auto_monsters[target_slot]
	var source_actor: Dictionary = auto_monsters[source_slot]
	var before := _entity_world_position(target)
	var offset := _wrapped_delta(_entity_world_position(source_actor), before)
	if offset.length() <= 0.01:
		offset = Vector2(1.0, 0.0).rotated(rng.randf_range(0.0, TAU))
	var target_position := before + offset.normalized() * distance_m
	_set_entity_world_position(target, target_position)
	var moved := _wrapped_distance(before, _entity_world_position(target))
	if moved > 0.5:
		_add_visual_trail(before, _entity_world_position(target), _auto_monster_color(target_slot), "击退")
		_log("%s击退怪%d·%s %s至%s。" % [
			source,
			target_slot + 1,
			String(target.get("name", "怪兽")),
			_meters_text(moved),
			districts[int(target["position"])]["name"],
		])
		var impact_damage := _damage_districts_on_monster_path(
			target,
			before,
			_entity_world_position(target),
			_auto_monster_collision_damage(target),
			"%s击退冲击" % source,
			AUTO_MONSTER_KNOCKBACK_DAMAGE_MAX_REGIONS
		)
		if impact_damage > 0:
			_add_action_callout(
				"击退冲击",
				source,
				"怪%d·%s被击飞，沿途造成合计%d点区域伤害。" % [
					target_slot + 1,
					String(target.get("name", "怪兽")),
					impact_damage,
				],
				Color("#fb7185"),
				_entity_world_position(target)
			)
	auto_monsters[target_slot] = target


func _monster_tick() -> void:
	_auto_monster_movement_tick()


func _special_monster_tick() -> void:
	_auto_special_monster_tick()


func _active_city_district_indices() -> Array:
	var result := []
	for i in range(districts.size()):
		if _city_is_active(_district_city(i)):
			result.append(i)
	return result


func _player_active_city_count(player_index: int) -> int:
	var count := 0
	for index in _active_city_district_indices():
		if int(_district_city(index).get("owner", -1)) == player_index:
			count += 1
	return count


func _city_competition_matches(district_index: int) -> int:
	var city := _district_city(district_index)
	if not _city_is_active(city):
		return 0
	var owner := int(city.get("owner", -1))
	var own_products := _city_product_names(city)
	var matches := 0
	for other_index in _active_city_district_indices():
		if other_index == district_index:
			continue
		var other_city := _district_city(other_index)
		if int(other_city.get("owner", -1)) == owner:
			continue
		var other_products := _city_product_names(other_city)
		for product_name in own_products:
			if other_products.has(product_name):
				matches += 1
	return matches


func _city_trade_routes(district_index: int) -> Array:
	var city := _district_city(district_index)
	if not _city_is_active(city):
		return []
	return city.get("trade_routes", []) as Array


func _route_base_flow_amount(product_name: String, source_index: int, destination_index: int) -> float:
	var source_factor := _district_production_factor(source_index)
	var destination_factor := _district_consumption_factor(destination_index)
	var relation: float = minf(_product_supply_demand_ratio(product_name), _product_supply_availability_ratio(product_name))
	return maxf(0.35, sqrt(source_factor * destination_factor) * clampf(0.55 + relation, 0.55, 1.55))


func _district_transit_gdp(district_index: int) -> Dictionary:
	if district_index < 0 or district_index >= districts.size():
		return {"income": 0, "lines": []}
	var total := 0
	var lines := []
	var public_speed := _district_transport_speed(district_index)
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		for route_variant in _city_trade_routes(city_index):
			var route: Dictionary = route_variant
			if bool(route.get("disrupted", false)):
				continue
			if int(route.get("to", -1)) == district_index:
				continue
			var path: Array = route.get("path", [])
			if not path.has(district_index):
				continue
			var product_name := String(route.get("product", ""))
			var price := _product_price(product_name)
			var amount := maxf(0.25, float(route.get("flow_amount", 1.0)))
			var unit := CITY_TRANSIT_GDP_BASE + int(round(float(price) / float(CITY_TRANSIT_PRICE_DIVISOR)))
			var income := int(round(float(unit) * amount * public_speed))
			total += income
			lines.append("%s过境 量%.2f×速%.2f:+%d" % [product_name, amount, public_speed, income])
	return {"income": total, "lines": lines}


func _city_cycle_income(district_index: int, competition_matches: int) -> int:
	return int(_city_cycle_income_breakdown(district_index, competition_matches).get("net", 0))


func _city_cycle_income_breakdown(district_index: int, competition_matches: int) -> Dictionary:
	var city := _district_city(district_index)
	if not _city_is_active(city):
		return {
			"bonus": 0,
			"contract": 0,
			"product": 0,
			"route": 0,
			"transit": 0,
			"gross": 0,
			"competition_penalty": 0,
			"route_penalty": 0,
			"damage_penalty": 0,
			"penalty": 0,
			"net_before_floor": 0,
			"net": 0,
			"product_lines": [],
			"route_lines": [],
			"transit_lines": [],
		}
	var bonus := int(city.get("revenue_bonus", 0))
	var contract_income := int(city.get("contract_income_bonus", 0))
	var product_income := 0
	var route_income_total := 0
	var transit_income_total := 0
	var product_lines := []
	var route_lines := []
	for product_variant in city.get("products", []):
		var product: Dictionary = product_variant
		var product_name := String(product.get("name", ""))
		var price := _product_price(product_name)
		var level := int(product.get("level", 1))
		var line_base := CITY_PRODUCT_BASE_REVENUE + int(round(float(price) / float(CITY_PRODUCT_PRICE_REVENUE_DIVISOR)))
		line_base += max(0, level - 1) * CITY_PRODUCT_LEVEL_REVENUE
		var flow_amount := maxf(0.25, float(level) * _district_production_factor(district_index) * _product_supply_demand_ratio(product_name))
		var flow_speed := _district_transport_speed(district_index)
		var line_income := int(round(float(line_base) * flow_amount * flow_speed * CITY_PRODUCTION_GDP_SCALE))
		product_income += line_income
		product_lines.append("%s¥%d 量%.2f×速%.2f:+%d" % [product_name, price, flow_amount, flow_speed, line_income])
	for route_variant in city.get("trade_routes", []):
		var route: Dictionary = route_variant
		if bool(route.get("disrupted", false)):
			continue
		var demand_product := String(route.get("product", ""))
		var route_price := _product_price(demand_product)
		var route_income := CITY_DEMAND_SUPPLY_REVENUE + int(round(float(route_price) / float(CITY_DEMAND_PRICE_REVENUE_DIVISOR)))
		var route_amount := maxf(0.25, float(route.get("flow_amount", 1.0)) * _district_consumption_factor(district_index) * _product_supply_availability_ratio(demand_product))
		var route_speed := float(route.get("flow_speed", _city_route_flow_multiplier(city, demand_product)))
		var final_route_income := int(round(float(route_income) * route_amount * route_speed * CITY_CONSUMPTION_GDP_SCALE))
		route_income_total += final_route_income
		route_lines.append("%s¥%d 量%.2f×速%.2f:+%d" % [demand_product, route_price, route_amount, route_speed, final_route_income])
	var transit_data := _district_transit_gdp(district_index)
	transit_income_total = int(transit_data.get("income", 0))
	var gross := bonus + contract_income + product_income + route_income_total + transit_income_total
	var competition_penalty := competition_matches * CITY_COMPETITION_PENALTY
	var route_penalty := int(city.get("trade_disrupted_routes", 0)) * TRADE_DISRUPTION_PENALTY
	var damage_penalty := int(districts[district_index].get("damage", 0)) * CITY_DAMAGE_GDP_PENALTY
	var penalties := competition_penalty + route_penalty + damage_penalty
	var net_before_floor := gross - penalties
	return {
		"bonus": bonus,
		"contract": contract_income,
		"product": product_income,
		"route": route_income_total,
		"transit": transit_income_total,
		"gross": gross,
		"competition_penalty": competition_penalty,
		"route_penalty": route_penalty,
		"damage_penalty": damage_penalty,
		"penalty": penalties,
		"net_before_floor": net_before_floor,
		"net": max(CITY_MINIMUM_INCOME, net_before_floor),
		"product_lines": product_lines,
		"route_lines": route_lines,
		"transit_lines": transit_data.get("lines", []),
	}


func _city_income_breakdown_summary(breakdown: Dictionary) -> String:
	return "生产GDP%d + 消费GDP%d + 过境GDP%d + 加成%d + 合约%d - 竞争%d - 断路%d - 损伤%d = %d" % [
		int(breakdown.get("product", 0)),
		int(breakdown.get("route", 0)),
		int(breakdown.get("transit", 0)),
		int(breakdown.get("bonus", 0)),
		int(breakdown.get("contract", 0)),
		int(breakdown.get("competition_penalty", 0)),
		int(breakdown.get("route_penalty", 0)),
		int(breakdown.get("damage_penalty", 0)),
		int(breakdown.get("net", 0)),
	]


func _city_income_detail_lines(city_index: int, competition_matches: int) -> Array:
	var breakdown := _city_cycle_income_breakdown(city_index, competition_matches)
	var lines := []
	lines.append("收入拆解：%s。" % _city_income_breakdown_summary(breakdown))
	lines.append("合约状态：%s。" % _city_contract_status_text(_district_city(city_index)))
	lines.append("生产明细：%s。" % _limited_name_list(breakdown.get("product_lines", []) as Array, 5))
	lines.append("消费明细：%s。" % _limited_name_list(breakdown.get("route_lines", []) as Array, 5))
	lines.append("过境明细：%s。" % _limited_name_list(breakdown.get("transit_lines", []) as Array, 5))
	return lines


func _refresh_city_competition_counts() -> void:
	for index_variant in _active_city_district_indices():
		var index := int(index_variant)
		var city := _district_city(index)
		city["competition_matches"] = _city_competition_matches(index)
		districts[index]["city"] = city


func _refresh_city_trade_routes() -> void:
	for index_variant in _active_city_district_indices():
		var index := int(index_variant)
		var city := _district_city(index)
		var routes := []
		var route_damage_remaining := int(city.get("trade_route_damage", 0))
		var disrupted := 0
		var supplied := 0
		for demand_variant in city.get("demands", []):
			var product_name := String(demand_variant)
			var route := _trade_route_for_product_to_city(product_name, index)
			if route.is_empty():
				disrupted += 1
				routes.append({
					"product": product_name,
					"from": -1,
					"to": index,
					"path": [],
					"points": [],
					"disrupted": true,
					"source_type": "无供给",
				})
				continue
			if route_damage_remaining > 0:
				route["disrupted"] = true
				route_damage_remaining -= 1
			if bool(route.get("disrupted", false)):
				disrupted += 1
			else:
				supplied += 1
			routes.append(route)
		disrupted += route_damage_remaining
		city["trade_routes"] = routes
		city["trade_disrupted_routes"] = disrupted
		city["supplied_demands"] = supplied
		districts[index]["city"] = city


func _refresh_city_networks() -> void:
	_refresh_city_competition_counts()
	_refresh_city_trade_routes()


func _trade_route_for_product_to_city(product_name: String, destination_index: int) -> Dictionary:
	if product_name == "" or destination_index < 0 or destination_index >= districts.size():
		return {}
	var best_route := {}
	var best_cost := INF
	for source_index in range(districts.size()):
		if not _district_supplies_product(source_index, product_name, destination_index):
			continue
		var path := _shortest_trade_path(source_index, destination_index)
		if path.is_empty():
			continue
		var raw_cost := _trade_path_cost(path)
		var public_speed := _trade_path_transport_speed(path)
		var flow_multiplier := _city_route_flow_multiplier(_district_city(destination_index), product_name)
		var flow_speed := clampf(public_speed * flow_multiplier, REGION_TRANSPORT_SCORE_MIN, REGION_TRANSPORT_SCORE_MAX * ROUTE_FLOW_MULTIPLIER_MAX)
		var flow_amount := _route_base_flow_amount(product_name, source_index, destination_index)
		var cost := raw_cost / maxf(REGION_TRANSPORT_SCORE_MIN, flow_speed)
		if cost < best_cost:
			best_cost = cost
			best_route = {
				"product": product_name,
				"from": source_index,
				"to": destination_index,
				"path": path,
				"points": _trade_path_points(path),
				"disrupted": _trade_path_is_disrupted(path),
				"source_type": _trade_source_type(source_index, product_name, destination_index),
				"cost": cost,
				"raw_cost": raw_cost,
				"flow_multiplier": flow_multiplier,
				"public_speed": public_speed,
				"flow_speed": flow_speed,
				"flow_amount": flow_amount,
			}
	return best_route


func _district_supplies_product(index: int, product_name: String, destination_index: int) -> bool:
	if index < 0 or index >= districts.size():
		return false
	if bool(districts[index].get("destroyed", false)):
		return false
	var city := _district_city(index)
	if index != destination_index and _city_is_active(city) and _city_product_names(city).has(product_name):
		return true
	if String(districts[index].get("terrain", "land")) == "land":
		var products: Array = districts[index].get("products", [])
		return products.has(product_name)
	return false


func _trade_source_type(index: int, product_name: String, destination_index: int) -> String:
	var city := _district_city(index)
	if index != destination_index and _city_is_active(city) and _city_product_names(city).has(product_name):
		return "城市"
	return "产区"


func _shortest_trade_path(source_index: int, destination_index: int) -> Array:
	if source_index < 0 or source_index >= districts.size() or destination_index < 0 or destination_index >= districts.size():
		return []
	if source_index == destination_index:
		return [source_index]
	var distances := {}
	var previous := {}
	var open := []
	for i in range(districts.size()):
		distances[i] = INF
		open.append(i)
	distances[source_index] = 0.0
	while not open.is_empty():
		var current := -1
		var current_distance := INF
		for index_variant in open:
			var index := int(index_variant)
			var distance := float(distances.get(index, INF))
			if distance < current_distance:
				current_distance = distance
				current = index
		if current < 0 or is_inf(current_distance):
			break
		open.erase(current)
		if current == destination_index:
			break
		for neighbor_variant in districts[current].get("neighbors", []):
			var neighbor := int(neighbor_variant)
			if neighbor < 0 or neighbor >= districts.size():
				continue
			var next_distance := current_distance + _trade_edge_cost(current, neighbor)
			if next_distance < float(distances.get(neighbor, INF)):
				distances[neighbor] = next_distance
				previous[neighbor] = current
	if not previous.has(destination_index):
		return []
	var path := [destination_index]
	var cursor := destination_index
	var guard := 0
	while cursor != source_index and guard < districts.size() + 2:
		guard += 1
		if not previous.has(cursor):
			return []
		cursor = int(previous[cursor])
		path.push_front(cursor)
	return path


func _trade_edge_cost(a: int, b: int) -> float:
	var distance := _distance(a, b)
	if is_inf(distance):
		return INF
	return distance * (_trade_node_cost_multiplier(a) + _trade_node_cost_multiplier(b)) * 0.5


func _trade_node_cost_multiplier(index: int) -> float:
	if index < 0 or index >= districts.size():
		return 2.0
	var multiplier := 0.88 if String(districts[index].get("terrain", "land")) == "ocean" else 1.0
	multiplier /= maxf(REGION_TRANSPORT_SCORE_MIN, _district_transport_speed(index))
	if bool(districts[index].get("destroyed", false)):
		multiplier += 4.0
	if bool(districts[index].get("miasma", false)):
		multiplier += 0.35
	multiplier += float(districts[index].get("panic", 0)) * 0.002
	return multiplier


func _trade_path_transport_speed(path: Array) -> float:
	if path.is_empty():
		return 1.0
	var total := 0.0
	var count := 0
	for index_variant in path:
		var index := int(index_variant)
		if index < 0 or index >= districts.size():
			continue
		total += _district_transport_speed(index)
		count += 1
	return clampf(total / maxf(1.0, float(count)), REGION_TRANSPORT_SCORE_MIN, REGION_TRANSPORT_SCORE_MAX)


func _trade_path_cost(path: Array) -> float:
	if path.size() <= 1:
		return 0.0
	var cost := 0.0
	for i in range(path.size() - 1):
		cost += _trade_edge_cost(int(path[i]), int(path[i + 1]))
	return cost


func _trade_path_points(path: Array) -> Array:
	var points := []
	for index_variant in path:
		points.append(_district_center(int(index_variant)))
	return points


func _trade_path_is_disrupted(path: Array) -> bool:
	if path.is_empty():
		return true
	for index_variant in path:
		var index := int(index_variant)
		if index < 0 or index >= districts.size() or bool(districts[index].get("destroyed", false)):
			return true
	return false


func _trade_routes_for_product(product_name: String) -> Array:
	var result := []
	if product_name == "":
		return result
	for index_variant in _active_city_district_indices():
		var index := int(index_variant)
		for route_variant in _city_trade_routes(index):
			var route: Dictionary = route_variant
			if String(route.get("product", "")) == product_name and not (route.get("path", []) as Array).is_empty():
				result.append(route)
	return result


func _trade_route_markers_for_selected_product() -> Array:
	var result := []
	for route_variant in _trade_routes_for_product(selected_trade_product):
		var route: Dictionary = route_variant
		result.append({
			"product": String(route.get("product", "")),
			"from": int(route.get("from", -1)),
			"to": int(route.get("to", -1)),
			"points": route.get("points", []),
			"disrupted": bool(route.get("disrupted", false)),
			"source_type": String(route.get("source_type", "")),
			"flow_multiplier": float(route.get("flow_multiplier", 1.0)),
		})
	return result


func _apply_trade_disruption_from_destroyed_district(district_index: int, source: String) -> void:
	if district_index < 0 or district_index >= districts.size():
		return
	var affected_cities := 0
	for city_index_variant in _active_city_district_indices():
		var city_index := int(city_index_variant)
		var city := _district_city(city_index)
		var affected_products := []
		for route_variant in _city_trade_routes(city_index):
			var route: Dictionary = route_variant
			var path: Array = route.get("path", [])
			var product_name := String(route.get("product", ""))
			if path.has(district_index) and product_name != "" and not affected_products.has(product_name):
				affected_products.append(product_name)
		if affected_products.is_empty():
			continue
		city["trade_route_damage"] = int(city.get("trade_route_damage", 0)) + affected_products.size()
		districts[city_index]["city"] = city
		affected_cities += 1
		_log("%s破坏%s，影响%s的商路：%s。" % [
			source,
			districts[district_index]["name"],
			districts[city_index]["name"],
			"、".join(affected_products),
		])
	if affected_cities > 0:
		_add_action_callout(
			"商路警报",
			"运输受损",
			"%s被破坏，%d座城市的途经商路受影响。" % [districts[district_index]["name"], affected_cities],
			Color("#fb7185"),
			_district_center(district_index)
		)


func _market_tick() -> void:
	business_cycle_count += 1
	_refresh_city_networks()
	_refresh_product_market_prices()
	for i in range(players.size()):
		players[i]["last_cycle_income"] = 0
	var city_indices := _active_city_district_indices()
	if city_indices.is_empty():
		_log("经营周期%d：目前还没有存活城市群产生收入。" % business_cycle_count)
	else:
		for index_variant in city_indices:
			var index := int(index_variant)
			var city := _district_city(index)
			var competition := _city_competition_matches(index)
			var income := _city_cycle_income(index, competition)
			var owner := int(city.get("owner", -1))
			city["competition_matches"] = competition
			city["last_income"] = income
			districts[index]["city"] = city
			_resolve_city_gdp_derivatives(index, income, "周期%d" % business_cycle_count)
			city = _district_city(index)
			if owner >= 0 and owner < players.size():
				players[owner]["cash"] += income
				players[owner]["last_cycle_income"] = int(players[owner].get("last_cycle_income", 0)) + income
				players[owner]["total_city_income"] = int(players[owner].get("total_city_income", 0)) + income
				_record_player_economic_event(owner, "城市收入", "周期%d收入" % business_cycle_count, income, districts[index]["name"])
				_apply_role_market_income_bonus(owner, index)
				_log("经营周期%d：%s的%s收入%d（同类竞争%d，需求供给%d，受损商路%d）。" % [
					business_cycle_count,
					players[owner]["name"],
					districts[index]["name"],
					income,
					competition,
					int(city.get("supplied_demands", 0)),
					int(city.get("trade_disrupted_routes", 0)),
				])
			_add_action_callout(
				"城市经营",
				"周期%d结算" % business_cycle_count,
				"%s生产%d种、需求供给%d、受损商路%d；真实业主仍未公开。" % [
					districts[index]["name"],
					(city.get("products", []) as Array).size(),
					int(city.get("supplied_demands", 0)),
					int(city.get("trade_disrupted_routes", 0)),
				],
				Color("#2dd4bf"),
				_district_center(index)
			)
			_pulse_district(index, Color("#2dd4bf"))
	_auto_expand_rival_syndicates(false)
	_auto_rival_business_actions(false)
	_age_economic_boons()
	_finalize_ai_decision_rewards()
	for i in range(players.size()):
		_record_player_cash_snapshot(i)


func _update_realtime_cooldowns(delta: float) -> void:
	for p in players:
		p["action_cooldown"] = max(0.0, p["action_cooldown"] - delta)
		for skill in p["slots"]:
			if skill == null:
				continue
			skill["cooldown_left"] = max(0.0, skill["cooldown_left"] - delta)
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


func _add_map_event_attack_effect(kind: String, from_position: Vector2, to_position: Vector2, color: Color, label: String = "", duration: float = 0.95, radius_m: float = 80.0) -> void:
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
	})


func _push_map_event_effect(effect: Dictionary) -> void:
	map_event_effects.append(effect)
	while map_event_effects.size() > MAX_MAP_EVENT_EFFECTS:
		map_event_effects.pop_front()


func _add_monster_attack_effect(from_position: Vector2, to_position: Vector2, source: String, range_limit_m: float, color: Color, is_ranged: bool = false) -> void:
	var kind := "laser" if is_ranged or _source_looks_ranged(source, range_limit_m) else "melee"
	_add_map_event_attack_effect(kind, from_position, to_position, color, source, 1.05 if kind == "laser" else 0.82, range_limit_m)


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


func _damage_district(index: int, amount: int, source: String) -> void:
	if index < 0 or index >= districts.size() or amount <= 0:
		return
	var d: Dictionary = districts[index]
	if d["destroyed"]:
		return
	d["damage"] += amount
	d["last_damage_source"] = source
	d["last_damage_amount"] = amount
	d["last_damage_time"] = game_time
	d["panic"] = min(100, d["panic"] + amount * 8)
	_pulse_district(index, Color("#ef4444"))
	_add_district_damage_effect(index, source, Color("#fb7185") if _source_looks_ranged(source, 0.0) else Color("#f97316"))
	_log("%s使%s受到%d点区域伤害。" % [source, d["name"], amount])
	if d["damage"] >= d["hp"]:
		d["destroyed"] = true
		_apply_trade_disruption_from_destroyed_district(index, source)
		var city := _district_city(index)
		if _city_is_active(city):
			city = _resolve_city_gdp_derivatives_on_destroy(index, city, source)
			city["active"] = false
			city["destroyed_at"] = game_time
			d["city"] = city
			_add_map_event_effect("city_destroyed", _district_center(index), Color("#ef4444"), "城市塌毁", 1.75, float(d.get("radius_m", 80.0)))
			_add_action_callout(
				"城市警报",
				"城市群毁灭",
				"%s的城市群停止经营；真实业主仍不公开。" % d["name"],
				Color("#fb7185"),
				_district_center(index)
			)
			_log("%s的城市群被摧毁，业主%s失去该城市全部周期收入。" % [d["name"], players[int(city.get("owner", 0))]["name"]])
		else:
			_log("%s的基础设施被彻底破坏。" % d["name"])
		_refresh_city_networks()


func _repair_district(index: int, amount: int, source: String) -> int:
	var d: Dictionary = districts[index]
	if d["destroyed"] or int(d["damage"]) <= 0:
		return 0
	var repaired: int = min(amount, int(d["damage"]))
	d["damage"] -= repaired
	d["panic"] = max(0, int(d["panic"]) - repaired * 6)
	_pulse_district(index, Color("#22c55e"))
	_log("%s修复%s %d点区域伤害。" % [source, d["name"], repaired])
	return repaired


func _finish_game(reason: String) -> void:
	if game_over:
		return
	game_over = true
	_log("游戏结束：%s" % reason)
	var cash_goal := _roguelike_cash_goal()
	var rankings := _final_score_rankings()
	var winner_index := int((rankings[0] as Dictionary).get("player_index", 0)) if not rankings.is_empty() else 0
	var winner_score := int((rankings[0] as Dictionary).get("score", 0)) if not rankings.is_empty() else 0
	for i in range(players.size()):
		var score := _player_final_score(i)
		_log("%s终局资金：现金%d + 存活城市%d×%d + 情报现金%s = %d（%s）。" % [
			players[i]["name"],
			players[i]["cash"],
			_player_active_city_count(i),
			CITY_FINAL_VALUE,
			_signed_int_text(_player_intel_cash(i)),
			score,
			_player_intel_summary(i),
		])
	_log("胜者：%s，结算资金最高：%d。" % [players[winner_index]["name"], winner_score])
	_log(_final_run_summary_text(rankings))
	var learned_samples := _finalize_ai_episode_rewards(reason)
	if learned_samples > 0:
		_log("AI终局训练：已用本局最终资金回写%d条决策样本。" % learned_samples)
	var local_score := _player_final_score(0) if not players.is_empty() else 0
	_log("%s通关判定：本层目标¥%d，玩家1结算¥%d，%s。" % [
		_roguelike_depth_label(),
		cash_goal,
		local_score,
		"达标，可进入更大星球" if local_score >= cash_goal else "未达标，需要赚更多钱",
	])
	_open_final_settlement_menu(reason, rankings)


func _player_final_score(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	return int(players[player_index].get("cash", 0)) + _player_active_city_count(player_index) * CITY_FINAL_VALUE + _player_intel_cash(player_index)


func _auto_monster_color(slot: int) -> Color:
	if AUTO_MONSTER_COLORS.is_empty():
		return Color("#ef4444")
	return AUTO_MONSTER_COLORS[slot % AUTO_MONSTER_COLORS.size()] as Color


func _auto_monster_markers() -> Array:
	var result := []
	for i in range(auto_monsters.size()):
		var actor: Dictionary = auto_monsters[i]
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
			"down": bool(actor.get("down", false)),
		})
	return result


func _nearest_auto_monster_distance_to_district_label(index: int) -> String:
	if auto_monsters.is_empty():
		return "无在场怪兽"
	var best := INF
	for actor_variant in auto_monsters:
		var actor: Dictionary = actor_variant
		best = min(best, _entity_distance_to_district(actor, index))
	return _meters_text(best)


func _auto_monster_target_weight_parts(actor: Dictionary, index: int) -> Dictionary:
	var parts := {
		"base": 0,
		"panic": 0,
		"city": 0,
		"competition": 0,
		"resource": 0,
		"distance": 0,
		"miasma": 0,
		"monster": 0,
	}
	if index < 0 or index >= districts.size():
		return parts
	var d: Dictionary = districts[index]
	if d["destroyed"]:
		return parts
	parts["base"] = MONSTER_TARGET_BASE_WEIGHT
	parts["panic"] = int(d["panic"]) * MONSTER_TARGET_PANIC_WEIGHT
	var city := _district_city(index)
	if _city_is_active(city):
		parts["city"] = MONSTER_TARGET_CITY_BONUS + (city.get("products", []) as Array).size() * MONSTER_TARGET_PRODUCT_WEIGHT
		parts["competition"] = int(city.get("competition_matches", 0)) * MONSTER_TARGET_COMPETITION_WEIGHT
	parts["resource"] = _monster_resource_match_score(actor, index) * MONSTER_TARGET_RESOURCE_WEIGHT
	parts["distance"] = max(0, MONSTER_TARGET_DISTANCE_BASE - _entity_distance_to_district(actor, index) * MONSTER_TARGET_DISTANCE_STEP)
	if d["miasma"]:
		parts["miasma"] = MONSTER_TARGET_MIASMA_BONUS
	for other_variant in auto_monsters:
		var other: Dictionary = other_variant
		if other == actor or bool(other.get("down", false)):
			continue
		if int(other.get("position", -1)) == index:
			parts["monster"] = MONSTER_TARGET_RIVAL_BONUS
			break
	return parts


func _auto_monster_target_weight(actor: Dictionary, index: int) -> int:
	if index < 0 or index >= districts.size():
		return 0
	if districts[index]["destroyed"]:
		return 0
	return max(1, _weight_part_total(_auto_monster_target_weight_parts(actor, index)))


func _auto_monster_target_candidates(actor: Dictionary) -> Array:
	var result := []
	for i in range(districts.size()):
		if districts[i]["destroyed"]:
			continue
		var weight := _auto_monster_target_weight(actor, i)
		if weight > 0:
			result.append({"index": i, "weight": weight})
	return result


func _weighted_auto_monster_target(actor: Dictionary) -> int:
	var weights := []
	var candidates := _auto_monster_target_candidates(actor)
	for entry in candidates:
		weights.append(int(entry["weight"]))
	var picked := _weighted_pick_index(weights)
	if picked < 0:
		return -1
	return int(candidates[picked]["index"])


func _auto_monster_target_probability_text(actor: Dictionary, index: int) -> String:
	if index < 0 or index >= districts.size():
		return "无"
	if districts[index]["destroyed"]:
		return "已排除"
	var candidates := _auto_monster_target_candidates(actor)
	var total := 0
	for entry in candidates:
		total += int(entry["weight"])
	if total <= 0:
		return "无可选目标"
	var weight := _auto_monster_target_weight(actor, index)
	return "%s（权重%d/%d）" % [_probability_text(weight, total), weight, total]


func _auto_monster_target_reason(actor: Dictionary, index: int) -> String:
	return "%s，主因:%s" % [
		_auto_monster_target_probability_text(actor, index),
		_auto_monster_target_factor_summary(actor, index),
	]


func _auto_monster_target_factor_summary(actor: Dictionary, index: int) -> String:
	if index < 0 or index >= districts.size():
		return "无"
	if districts[index]["destroyed"]:
		return "已破坏，已排除"
	var parts := _auto_monster_target_weight_parts(actor, index)
	var candidates := [
		{"name": "热度", "value": int(parts["panic"])},
		{"name": "距离", "value": int(parts["distance"])},
		{"name": "城市经营", "value": int(parts["city"])},
		{"name": "商品竞争", "value": int(parts["competition"])},
		{"name": "资源偏好", "value": int(parts["resource"])},
		{"name": "瘴气", "value": int(parts["miasma"])},
		{"name": "同场怪兽", "value": int(parts["monster"])},
	]
	var picked := []
	while picked.size() < 3 and not candidates.is_empty():
		var best_pos := -1
		var best_value := 0
		for i in range(candidates.size()):
			var value := int(candidates[i]["value"])
			if value > best_value:
				best_value = value
				best_pos = i
		if best_pos < 0:
			break
		var best: Dictionary = candidates[best_pos]
		picked.append("%s+%d" % [best["name"], best["value"]])
		candidates.remove_at(best_pos)
	if picked.is_empty():
		picked.append("基础+%d" % int(parts["base"]))
	return " / ".join(picked)


func _highest_panic_district() -> int:
	var best_index := -1
	var best_panic := -1
	for i in range(districts.size()):
		var d: Dictionary = districts[i]
		if d["destroyed"]:
			continue
		if int(d["panic"]) > best_panic:
			best_panic = int(d["panic"])
			best_index = i
	return best_index


func _weighted_event_district() -> int:
	var candidates := []
	var weights := []
	for i in range(districts.size()):
		if not districts[i]["destroyed"]:
			candidates.append(i)
			weights.append(_district_event_weight(i))
	var picked := _weighted_pick_index(weights)
	if picked < 0:
		return -1
	return int(candidates[picked])


func _distance(a: int, b: int) -> float:
	if a < 0 or a >= districts.size() or b < 0 or b >= districts.size():
		return INF
	if a == b:
		return 0.0
	return _wrapped_distance(_district_center(a), _district_center(b))


func _district_center(index: int) -> Vector2:
	if index < 0 or index >= districts.size():
		return Vector2.ZERO
	return districts[index].get("center", Vector2.ZERO)


func _entity_world_position(entity: Dictionary) -> Vector2:
	return entity.get("world_position", _district_center(int(entity.get("position", 0))))


func _wrap_world_position(position: Vector2) -> Vector2:
	var width: float = max(1.0, map_width_m)
	var height: float = max(1.0, map_height_m)
	var x := position.x
	var y := position.y
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


func _world_to_lon_lat(position: Vector2) -> Vector2:
	var wrapped := _wrap_world_position(position)
	return Vector2(
		fposmod(wrapped.x / max(1.0, map_width_m) * TAU, TAU),
		PI * 0.5 - wrapped.y / max(1.0, map_height_m) * PI
	)


func _lon_lat_to_world(lon: float, lat: float) -> Vector2:
	return _wrap_world_position(Vector2(
		fposmod(lon, TAU) / TAU * max(1.0, map_width_m),
		(PI * 0.5 - clamp(lat, -PI * 0.5, PI * 0.5)) / PI * max(1.0, map_height_m)
	))


func _sphere_unit(position: Vector2) -> Vector3:
	var lon_lat := _world_to_lon_lat(position)
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


func _entity_distance(a: Dictionary, b: Dictionary) -> float:
	return _wrapped_distance(_entity_world_position(a), _entity_world_position(b))


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


func _distance_label(from_index: int, to_index: int) -> String:
	var dist := _distance(from_index, to_index)
	if is_inf(dist):
		return "未知"
	return _meters_text(dist)


func _entity_distance_to_district_label(entity: Dictionary, district_index: int) -> String:
	return _meters_text(_entity_distance_to_district(entity, district_index))


func _meters_text(value: float) -> String:
	if value >= 1000.0:
		return "%.1fkm" % (value / 1000.0)
	return "%.0fm" % value


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	var minutes := int(total / 60)
	var rest := total % 60
	return "%02d:%02d" % [minutes, rest]


func _plain_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
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

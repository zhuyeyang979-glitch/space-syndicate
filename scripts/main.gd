extends Control

const MapViewScript := preload("res://scripts/map_view.gd")

const MIN_PLAYER_COUNT := 2
const MAX_PLAYER_COUNT := 5
const DEFAULT_PLAYER_COUNT := 4
const MAP_WIDTH_METERS := 1400.0
const MAP_HEIGHT_METERS := 950.0
const MAP_SITE_MARGIN_METERS := 70.0
const MAP_REGION_COUNT_MIN := 10
const MAP_REGION_COUNT_MAX := 20
const MONSTER_COMMAND_MOVE_METERS := 220.0
const MONSTER_RAMPAGE_MOVE_METERS := 190.0
const MELEE_RANGE_METERS := 110.0
const NEARBY_RADIUS_METERS := 240.0
const DEFAULT_AOE_RADIUS_METERS := 180.0
const STARTING_CASH := 2000
const BET_UNIT := 200
const WITHDRAW_UNIT := 100
const CHARGE_UNIT := 100
const ACTION_COOLDOWN := 1.2
const CHARGE_COOLDOWN := 1.6
const MARKET_COOLDOWN := 1.8
const CONTROL_COOLDOWN := 1.4
const COMMAND_COOLDOWN := 1.0
const DEFAULT_SKILL_COOLDOWN := 3.0

const GUARDIAN_EARLY_ACTION_WEIGHTS := [2, 2, 2, 0, 0, 0]
const GUARDIAN_ESCALATED_ACTION_WEIGHTS := [1, 1, 1, 1, 1, 1]

const MONSTER_TARGET_BASE_WEIGHT := 10
const MONSTER_TARGET_PANIC_WEIGHT := 1
const MONSTER_TARGET_BONUS_DIVISOR := 25
const MONSTER_TARGET_BET_DIVISOR := 25
const MONSTER_TARGET_DISTANCE_BASE := 48.0
const MONSTER_TARGET_DISTANCE_STEP := 0.045
const MONSTER_TARGET_MIASMA_BONUS := 18
const MONSTER_TARGET_GUARDIAN_BONUS := 10

const EVENT_TARGET_BASE_WEIGHT := 8
const EVENT_TARGET_PANIC_WEIGHT := 1
const EVENT_TARGET_BONUS_DIVISOR := 40
const EVENT_TARGET_BET_DIVISOR := 40
const EVENT_TARGET_MIASMA_BONUS := 14
const EVENT_TARGET_MONSTER_BONUS := 10

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

const SPEEDS := [
	{"label": "暂停", "value": 0.0},
	{"label": "1x", "value": 1.0},
	{"label": "2x", "value": 2.0},
	{"label": "4x", "value": 4.0},
]

const BALANCE_PRESETS := [
	{
		"label": "稳态",
		"desc": "慢节奏教学局，区域压力和控制权衰减较低。",
		"event_min": 7.0,
		"event_max": 10.0,
		"monster_min": 5.0,
		"monster_max": 7.0,
		"guardian_min": 6.0,
		"guardian_max": 8.5,
		"market_min": 9.0,
		"market_max": 13.0,
		"event_heat_min": 8,
		"event_heat_max": 18,
		"event_bonus": 100,
		"market_bonus": 100,
		"monster_damage": 1,
		"guardian_damage_bonus": 0,
		"guardian_move_bonus": 0,
		"control_decay": 0.18,
	},
	{
		"label": "标准",
		"desc": "当前默认节奏，新闻、市场、怪兽与守护者互相拉扯。",
		"event_min": 5.0,
		"event_max": 8.0,
		"monster_min": 3.5,
		"monster_max": 5.5,
		"guardian_min": 4.5,
		"guardian_max": 7.0,
		"market_min": 7.0,
		"market_max": 11.0,
		"event_heat_min": 10,
		"event_heat_max": 24,
		"event_bonus": 100,
		"market_bonus": 100,
		"monster_damage": 1,
		"guardian_damage_bonus": 0,
		"guardian_move_bonus": 0,
		"control_decay": 0.25,
	},
	{
		"label": "灾厄",
		"desc": "高压短局，事件更密集，怪兽与守护者都更危险。",
		"event_min": 3.5,
		"event_max": 6.0,
		"monster_min": 2.5,
		"monster_max": 4.0,
		"guardian_min": 3.8,
		"guardian_max": 5.5,
		"market_min": 5.0,
		"market_max": 8.0,
		"event_heat_min": 16,
		"event_heat_max": 34,
		"event_bonus": 150,
		"market_bonus": 150,
		"monster_damage": 2,
		"guardian_damage_bonus": 1,
		"guardian_move_bonus": 80,
		"control_decay": 0.35,
	},
]

const SKILL_CATALOG := {
	"赌怪1": {"cost": 3, "kind": "bet_boost", "bet_amount": 200, "damage": 0, "move": 0, "range": 0, "tags": ["经济", "下注"], "text": "立即向选中区域额外下注200。"},
	"赌怪2": {"cost": 5, "kind": "bet_boost", "bet_amount": 400, "damage": 0, "move": 0, "range": 0, "tags": ["经济", "升级"], "text": "立即向选中区域额外下注400，作为赌怪升级牌。"},
	"赌怪3": {"cost": 7, "kind": "bet_boost", "bet_amount": 600, "damage": 0, "move": 0, "range": 0, "tags": ["经济", "终端"], "text": "立即向选中区域额外下注600，形成高风险大额押注。"},
	"黑幕1": {"cost": 2, "kind": "market_boost", "market_amount": 200, "panic": 12, "damage": 0, "move": 0, "range": 0, "tags": ["市场", "热度"], "text": "选中区域奖金+200，并提高当地热度。"},
	"黑幕2": {"cost": 4, "kind": "market_boost", "market_amount": 300, "panic": 18, "damage": 0, "move": 0, "range": 0, "tags": ["市场", "升级"], "text": "选中区域奖金+300，热度+18，作为黑幕升级牌。"},
	"黑幕3": {"cost": 6, "kind": "market_boost", "market_amount": 500, "panic": 28, "damage": 0, "move": 0, "range": 0, "tags": ["市场", "终端"], "text": "选中区域奖金+500，热度+28，把区域推向高奖池。"},
	"空投筹码1": {"cost": 3, "kind": "cash_gain", "cash": 300, "damage": 0, "move": 0, "range": 0, "tags": ["经济", "续航"], "text": "立即获得300筹码，用来续航或补下一轮充能。"},
	"舆论操控1": {"cost": 3, "kind": "panic_shift", "panic": 30, "damage": 0, "move": 0, "range": 0, "tags": ["热度", "引导"], "text": "选中区域热度+30，立刻提高怪兽和新闻事件对该区的关注。"},
	"控制电波1": {"cost": 3, "kind": "control_gain", "control": 3.0, "damage": 0, "move": 0, "range": 0, "tags": ["控制", "节奏"], "text": "立即获得3点怪兽控制权，更容易接管下一次实时移动。"},
	"过载充能1": {"cost": 4, "kind": "charge_other", "charge_amount": 1, "damage": 0, "move": 0, "range": 0, "tags": ["构筑", "充能"], "text": "除自身外，所有已装备卡牌立即+1充能。"},
	"移动1": {"cost": 2, "kind": "move", "damage": 0, "move": 180.0, "range": 0.0, "text": "指挥怪兽移动约180米，进入区域造成1点区域伤害。"},
	"移动2": {"cost": 4, "kind": "move", "damage": 0, "move": 280.0, "range": 0.0, "text": "指挥怪兽最多移动约280米。"},
	"普攻1": {"cost": 2, "kind": "attack", "damage": 1, "move": 0.0, "range": 110.0, "text": "近战AOE约110米，对守护者造成1点伤害。"},
	"普攻2": {"cost": 4, "kind": "attack", "damage": 2, "move": 0.0, "range": 110.0, "text": "近战AOE约110米，对守护者造成2点伤害。"},
	"普攻3": {"cost": 6, "kind": "attack", "damage": 3, "move": 0.0, "range": 110.0, "text": "近战AOE约110米，对守护者造成3点伤害。"},
	"区域破坏1": {"cost": 2, "kind": "area_damage", "damage": 1, "move": 0.0, "range": 180.0, "text": "对180米内区域造成1点区域伤害。"},
	"区域破坏2": {"cost": 5, "kind": "area_damage", "damage": 2, "move": 0.0, "range": 180.0, "tags": ["破坏", "升级"], "text": "对180米内区域造成2点伤害，作为区域破坏升级牌。"},
	"区域破坏3": {"cost": 8, "kind": "area_damage", "damage": 3, "move": 0.0, "range": 300.0, "tags": ["破坏", "终端"], "text": "对300米内区域造成3点伤害，适合终结高价值区域。"},
	"飞行1": {"cost": 3, "kind": "fly", "damage": 0, "move": 650.0, "range": 0.0, "text": "飞行突进最多650米。"},
	"飞行2": {"cost": 6, "kind": "fly", "damage": 0, "move": 760.0, "range": 0.0, "text": "飞行突进最多760米，冷却更长但更适合后期牌池。"},
	"龙车1": {"cost": 3, "kind": "charge_attack", "damage": 3, "move": 320.0, "range": 110.0, "text": "向守护者冲刺320米，并在110米近战圈造成3点伤害。"},
	"龙车2": {"cost": 6, "kind": "charge_attack", "damage": 3, "move": 380.0, "range": 110.0, "text": "向守护者冲刺380米并造成3点近战伤害，作为龙车升级牌。"},
	"龙车3": {"cost": 8, "kind": "charge_attack", "damage": 5, "move": 440.0, "range": 120.0, "text": "强力龙车，冲刺440米并在120米近战圈造成5点伤害。"},
	"甩尾1": {"cost": 2, "kind": "attack", "damage": 2, "move": 0.0, "range": 130.0, "text": "130米尾击AOE造成2点伤害，抽象为击退。"},
	"甩尾2": {"cost": 4, "kind": "attack", "damage": 2, "move": 0.0, "range": 160.0, "text": "160米尾击AOE造成2点伤害，作为甩尾升级牌。"},
	"装甲再生1": {"cost": 3, "kind": "armor_gain", "armor": 3, "damage": 0, "move": 0, "range": 0, "tags": ["防御", "续航"], "text": "怪兽立即获得3点护甲，抵消后续守护者伤害。"},
	"瘴气炮1": {"cost": 4, "kind": "miasma_shot", "damage": 1, "move": 0.0, "range": 420.0, "text": "420米远程瘴气炮造成1点伤害，并在选中区域留下瘴气。"},
	"瘴气爆发1": {"cost": 4, "kind": "miasma_bloom", "damage": 0, "move": 0.0, "range": 220.0, "miasma_count": 3, "text": "在选中区域220米AOE内散布至多3枚瘴气。"},
	"瘴气爆发2": {"cost": 6, "kind": "miasma_bloom", "damage": 0, "move": 0.0, "range": 260.0, "miasma_count": 5, "tags": ["瘴气", "升级"], "text": "在选中区域260米AOE内散布至多5枚瘴气，作为瘴气爆发升级牌。"},
	"瘴气回收1": {"cost": 2, "kind": "miasma_reclaim", "damage": 1, "move": 0.0, "range": 180.0, "reclaim_count": 1, "text": "回收怪兽180米内1枚瘴气并回复1HP；若守护者靠近则追加伤害。"},
	"瘴气回收2": {"cost": 4, "kind": "miasma_reclaim", "damage": 1, "move": 0.0, "range": 240.0, "reclaim_count": 2, "tags": ["瘴气", "续航"], "text": "回收怪兽240米内最多2枚瘴气，每枚回复1HP；守护者靠近则追加伤害。"},
	"腐蚀吐息1": {"cost": 5, "kind": "corrosive_breath", "damage": 2, "move": 0.0, "range": 420.0, "miasma_count": 2, "tags": ["瘴气", "远程"], "text": "420米内对守护者造成2点伤害，并在选中区域周围留下2枚瘴气。"},
	"咆哮1": {"cost": 3, "kind": "roar", "damage": 0, "move": 0.0, "range": 450.0, "delay": 1.5, "text": "450米AOE内硬直守护者，延后下一次守护者概率行动。"},
	"咆哮2": {"cost": 6, "kind": "roar", "damage": 0, "move": 0.0, "range": 520.0, "delay": 3.0, "text": "520米AOE内强力硬直守护者，大幅延后下一次守护者概率行动。"},
	"地底潜行1": {"cost": 3, "kind": "burrow", "damage": 0, "move": 340.0, "range": 0.0, "armor": 2, "text": "潜行移动340米，怪兽获得2点护甲。"},
	"地底潜行2": {"cost": 6, "kind": "burrow", "damage": 0, "move": 420.0, "range": 0.0, "armor": 2, "text": "潜行移动420米，怪兽获得2点护甲，作为升级潜行牌。"},
	"地底潜行3": {"cost": 9, "kind": "burrow", "damage": 0, "move": 520.0, "range": 0.0, "armor": 3, "text": "潜行移动520米，怪兽获得3点护甲。"},
	"打滚1": {"cost": 3, "kind": "roll_attack", "damage": 2, "move": 260.0, "range": 120.0, "text": "向选中区域翻滚260米，落点造成区域伤害；若120米内贴近守护者则造成2点伤害。"},
	"狂奔2": {"cost": 6, "kind": "roll_attack", "damage": 3, "move": 460.0, "range": 130.0, "tags": ["冲撞", "升级"], "text": "向选中区域高速狂奔460米；130米内贴近守护者则造成3点伤害。"},
	"泥甲1": {"cost": 3, "kind": "armor_gain", "armor": 4, "damage": 0, "move": 0, "range": 0, "tags": ["护甲", "土砂龙"], "text": "怪兽立即获得4点护甲，适合冲撞构筑续航。"},
	"泥石流1": {"cost": 4, "kind": "mudslide", "damage": 1, "panic": 24, "delay": 1.2, "move": 0.0, "range": 220.0, "tags": ["破坏", "控场"], "text": "220米AOE内区域受到1点伤害并热度+24；若守护者在AOE内，延后其行动。"},
	"火花反制1": {"cost": 4, "kind": "guardian_delay", "delay": 2.0, "control": 1.0, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["机械杰克", "控场"], "text": "抓住火花电击前摇，守护者概率行动延后2秒并获得1点控制权。"},
	"斯派修姆锁定1": {"cost": 4, "kind": "market_boost", "market_amount": 250, "panic": 22, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["机械杰克", "引导"], "text": "把斯派修姆交火引向选中区域，奖金+250、热度+22。"},
	"奥特空投诱导1": {"cost": 5, "kind": "mudslide", "damage": 1, "panic": 18, "delay": 2.0, "move": 0.0, "range": 180.0, "tags": ["机械杰克", "破坏"], "text": "诱导奥特空投落点，180米AOE内区域受1点伤害；若守护者靠近则延后行动。"},
	"断头刀预判1": {"cost": 4, "kind": "guardian_delay", "delay": 2.5, "control": 1.5, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["机械艾斯", "控场"], "text": "读出断头刀轨迹，守护者概率行动延后2.5秒并获得1.5控制权。"},
	"电击踢破绽1": {"cost": 4, "kind": "charge_other", "charge_amount": 2, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["机械艾斯", "充能"], "text": "利用电击踢收招破绽，除自身外所有已装备卡牌立即+2充能。"},
	"垂直断头刀窗口1": {"cost": 4, "kind": "armor_gain", "armor": 5, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["机械艾斯", "防御"], "text": "在垂直断头刀命中窗口前缩身防御，怪兽立即获得5点护甲。"},
	"修复光线干扰1": {"cost": 4, "kind": "mudslide", "damage": 1, "panic": 18, "delay": 1.5, "move": 0.0, "range": 260.0, "tags": ["纳伊斯", "破坏"], "text": "污染修复光线的落点，260米AOE内区域受1点伤害并升温；守护者靠近时被延后。"},
	"定身闪光余波1": {"cost": 3, "kind": "guardian_delay", "delay": 3.0, "control": 0.0, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["纳伊斯", "控场"], "text": "借定身闪光余波制造短暂空档，守护者概率行动延后3秒。"},
	"修正铁拳读秒1": {"cost": 4, "kind": "control_gain", "control": 4.0, "damage": 0, "move": 0.0, "range": 0.0, "tags": ["纳伊斯", "控制"], "text": "读出修正铁拳冲线时间，立即获得4点怪兽控制权。"},
}

const UPGRADEABLE_SKILL_FAMILIES := [
	"赌怪",
	"黑幕",
	"移动",
	"普攻",
	"区域破坏",
	"飞行",
	"龙车",
	"甩尾",
	"瘴气爆发",
	"瘴气回收",
	"咆哮",
	"地底潜行",
	"打滚",
	"狂奔",
]

const COMMON_CARD_POOL := [
	"赌怪1",
	"赌怪2",
	"赌怪3",
	"黑幕1",
	"黑幕2",
	"黑幕3",
	"空投筹码1",
	"舆论操控1",
	"控制电波1",
	"过载充能1",
	"移动2",
	"普攻2",
	"普攻3",
	"区域破坏1",
	"区域破坏2",
	"区域破坏3",
	"飞行1",
	"装甲再生1",
]

const MARKET_SKILLS := [
	"赌怪1",
	"黑幕1",
	"空投筹码1",
	"舆论操控1",
	"控制电波1",
	"过载充能1",
	"移动2",
	"普攻2",
	"普攻3",
	"区域破坏1",
	"区域破坏2",
	"飞行1",
	"龙车1",
	"甩尾1",
	"装甲再生1",
	"瘴气炮1",
	"地底潜行1",
]

const MONSTER_ROSTER := [
	{
		"name": "尸套龙",
		"hp": 50,
		"armor": 0,
		"style": "瘴气压制型：生命高，适合用瘴气炮和持续区域压力消耗守护者。",
		"market_skills": ["赌怪1", "赌怪2", "赌怪3", "黑幕1", "黑幕2", "黑幕3", "空投筹码1", "舆论操控1", "控制电波1", "过载充能1", "移动2", "普攻2", "普攻3", "区域破坏1", "区域破坏2", "区域破坏3", "飞行1", "飞行2", "龙车1", "龙车2", "甩尾1", "甩尾2", "装甲再生1", "瘴气炮1", "瘴气爆发1", "瘴气爆发2", "瘴气回收1", "瘴气回收2", "腐蚀吐息1"],
	},
	{
		"name": "土砂龙",
		"hp": 40,
		"armor": 2,
		"style": "冲撞护甲型：初始护甲更高，卡池偏向龙车和地底潜行。",
		"market_skills": ["赌怪1", "赌怪2", "赌怪3", "黑幕1", "黑幕2", "黑幕3", "空投筹码1", "舆论操控1", "控制电波1", "过载充能1", "移动2", "普攻2", "普攻3", "区域破坏1", "区域破坏2", "区域破坏3", "龙车1", "龙车2", "龙车3", "甩尾1", "甩尾2", "装甲再生1", "咆哮1", "咆哮2", "地底潜行1", "地底潜行2", "地底潜行3", "打滚1", "狂奔2", "泥甲1", "泥石流1"],
	},
]

const GUARDIAN_ROSTER := [
	{
		"name": "机械杰克",
		"hp": 30,
		"move": 360.0,
		"style": "高速追击型：移动速度高，适合标准压力局。",
		"guardian_cards": ["火花反制1", "斯派修姆锁定1", "奥特空投诱导1"],
	},
	{
		"name": "机械艾斯",
		"hp": 45,
		"move": 280.0,
		"style": "重装火力型：生命更高，但追击速度较慢。",
		"guardian_cards": ["断头刀预判1", "电击踢破绽1", "垂直断头刀窗口1"],
	},
	{
		"name": "纳伊斯",
		"hp": 30,
		"move": 300.0,
		"style": "防守救援型：低生命、慢追击，适合教学或低压局。",
		"guardian_cards": ["修复光线干扰1", "定身闪光余波1", "修正铁拳读秒1"],
	},
]

const GUARDIAN_ACTION_TABLES := {
	"机械杰克": [
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "text": "110米近战AOE，2伤害。"},
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "text": "110米近战AOE，2伤害。"},
		{"name": "火花电击", "range": 420.0, "damage": 2, "move_override": -1.0, "text": "420米射程，2伤害。"},
		{"name": "奥特飓风", "range": 120.0, "damage": 2, "move_override": -1.0, "text": "120米近战投掷，2坠落伤害。"},
		{"name": "斯派修姆光线", "range": 600.0, "damage": 3, "move_override": -1.0, "text": "600米光线，3伤害。"},
		{"name": "奥特空投", "range": 120.0, "damage": 4, "move_override": -1.0, "text": "120米近战空投，4伤害。"},
	],
	"机械艾斯": [
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "text": "110米近战AOE，2伤害。"},
		{"name": "电击踢", "range": 120.0, "damage": 2, "move_override": -1.0, "text": "120米近战AOE，2伤害，抽象为额外压制。"},
		{"name": "闪光手刀", "range": 120.0, "damage": 3, "move_override": 420.0, "text": "高速追近420米后近战3伤害。"},
		{"name": "水平断头刀", "range": 240.0, "damage": 3, "move_override": -1.0, "text": "240米射程，3伤害。"},
		{"name": "十字断头刀", "range": 320.0, "damage": 2, "move_override": -1.0, "text": "320米射程，2伤害并压低怪兽行动窗口。"},
		{"name": "垂直断头刀", "range": 260.0, "damage": 4, "move_override": -1.0, "text": "260米射程，4伤害。"},
	],
	"纳伊斯": [
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "text": "110米近战AOE，2伤害。"},
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "text": "110米近战AOE，2伤害。"},
		{"name": "束缚光线", "range": 420.0, "damage": 2, "move_override": -1.0, "text": "420米束缚光线，2伤害。"},
		{"name": "修复光线", "range": 420.0, "damage": 3, "move_override": -1.0, "repair": 1, "text": "420米修复光线，3伤害，并修复所在区域。"},
		{"name": "定身闪光", "range": 160.0, "damage": 2, "move_override": -1.0, "repair_radius": 220.0, "text": "220米修复AOE，并对160米近身目标2伤害。"},
		{"name": "修正铁拳", "range": 130.0, "damage": 5, "move_override": 560.0, "repair_path": 1, "text": "追近560米，沿途修复落点区域，对130米内目标5伤害。"},
	],
}

var rng := RandomNumberGenerator.new()
var players := []
var districts := []
var skill_market := []
var log_lines := []

var game_time := 0.0
var time_scale := 1.0
var selected_player := 0
var selected_district := 0
var selected_market_skill := "赌怪1"
var prediction_mode := "塌陷"
var configured_player_count := DEFAULT_PLAYER_COUNT
var configured_monster_index := 0
var configured_guardian_index := 0
var current_balance_index := 1
var game_over := false
var map_width_m := MAP_WIDTH_METERS
var map_height_m := MAP_HEIGHT_METERS
var district_lookup := {}

var event_timer := 6.0
var guardian_timer := 5.0
var monster_timer := 4.0
var market_timer := 8.0
var ui_timer := 0.0

var monster := {}
var guardian := {}

var status_label: Label
var setup_box: VBoxContainer
var map_view: Control
var player_box: VBoxContainer
var district_box: VBoxContainer
var market_box: VBoxContainer
var combat_box: VBoxContainer
var log_view: RichTextLabel


func _ready() -> void:
	rng.randomize()
	_build_layout()
	_new_game()


func _process(delta: float) -> void:
	if game_over or time_scale <= 0.0:
		return

	var scaled_delta := delta * time_scale
	game_time += scaled_delta
	_update_realtime_cooldowns(scaled_delta)

	event_timer -= scaled_delta
	guardian_timer -= scaled_delta
	monster_timer -= scaled_delta
	market_timer -= scaled_delta

	if event_timer <= 0.0:
		_world_event()
		event_timer = _roll_timer("event")
	if monster_timer <= 0.0:
		_monster_tick()
		monster_timer = _roll_timer("monster")
	if guardian_timer <= 0.0:
		_guardian_tick()
		guardian_timer = _roll_timer("guardian")
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
		KEY_Q:
			_cycle_district(-1)
		KEY_E:
			_cycle_district(1)
		KEY_B:
			_place_bet()
		KEY_W:
			_withdraw_bet()
		KEY_T:
			_toggle_prediction_mode()
		KEY_Y:
			_cycle_balance_preset()
		KEY_C:
			_charge_skills()
		KEY_X:
			_buy_selected_skill()
		KEY_V:
			_seize_control()
		KEY_G:
			_direct_monster()


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

	for speed in SPEEDS:
		var speed_button := Button.new()
		speed_button.text = speed["label"]
		speed_button.pressed.connect(Callable(self, "_set_speed").bind(speed["value"]))
		header.add_child(speed_button)

	var reset_button := Button.new()
	reset_button.text = "重新开局"
	reset_button.pressed.connect(Callable(self, "_new_game"))
	header.add_child(reset_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	page.add_child(body)

	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 10)
	body.add_child(left_column)

	var board_panel := _add_panel(left_column, "实时连续地区地图")
	_panel_container(board_panel).size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view = MapViewScript.new()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.district_selected.connect(Callable(self, "_select_district"))
	board_panel.add_child(map_view)

	var bottom_row := HBoxContainer.new()
	bottom_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_row.add_theme_constant_override("separation", 10)
	left_column.add_child(bottom_row)

	district_box = _add_panel(bottom_row, "选中区域")
	_panel_container(district_box).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	combat_box = _add_panel(bottom_row, "实时战斗")
	_panel_container(combat_box).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var right_column := VBoxContainer.new()
	right_column.custom_minimum_size = Vector2(460, 0)
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 10)
	body.add_child(right_column)

	setup_box = _add_panel(right_column, "开局设置")
	player_box = _add_panel(right_column, "玩家实时操作")
	market_box = _add_panel(right_column, "即时卡牌市场")

	var log_panel := _add_panel(right_column, "事件日志")
	_panel_container(log_panel).size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = true
	log_view.fit_content = false
	log_view.scroll_following = true
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_child(log_view)


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


func _generate_roguelike_districts() -> void:
	districts = []
	district_lookup = {}
	map_width_m = MAP_WIDTH_METERS
	map_height_m = MAP_HEIGHT_METERS
	var target_region_count := rng.randi_range(MAP_REGION_COUNT_MIN, MAP_REGION_COUNT_MAX)
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
			"hp": max(3, int(ceil(area_m2 / 65000.0))),
			"damage": 0,
			"panic": rng.randi_range(10, 34),
			"bonus": 0,
			"destroyed": false,
			"miasma": false,
			"bets": {},
			"card_choices": [],
		}
		districts.append(district)


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
		return

	var choice_targets := []
	for district in districts:
		district["card_choices"] = []
		choice_targets.append(rng.randi_range(3, 4))

	var featured_cards := _shuffled_card_list(_current_run_featured_cards())
	var cursor := 0
	for skill_name_variant in featured_cards:
		if districts.is_empty():
			break
		var skill_name := String(skill_name_variant)
		var placed := false
		for offset in range(districts.size()):
			var district_index := (cursor + offset) % districts.size()
			var choices: Array = districts[district_index]["card_choices"]
			if choices.size() >= 4 or choices.has(skill_name):
				continue
			choices.append(skill_name)
			districts[district_index]["card_choices"] = choices
			cursor = (district_index + 1) % districts.size()
			placed = true
			break
		if not placed:
			break

	for i in range(districts.size()):
		var choices: Array = districts[i]["card_choices"]
		var choice_count: int = max(int(choice_targets[i]), choices.size())
		choice_count = min(4, choice_count)
		var attempts := 0
		while choices.size() < choice_count and attempts < 80:
			var skill_name := String(skill_market[rng.randi_range(0, skill_market.size() - 1)])
			if not choices.has(skill_name):
				choices.append(skill_name)
			attempts += 1
		districts[i]["card_choices"] = choices


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
	for i in range(districts.size()):
		var dist := point.distance_to(_district_center(i))
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
	var monster_template: Dictionary = _monster_template()
	var guardian_template: Dictionary = _guardian_template()
	skill_market = _monster_market_skills()
	log_lines = []
	game_time = 0.0
	time_scale = 1.0
	selected_player = 0
	selected_market_skill = skill_market[0] if not skill_market.is_empty() else ""
	prediction_mode = "塌陷"
	game_over = false
	_prime_timers_for_new_game()

	for i in range(configured_player_count):
		players.append({
			"id": i,
			"name": "玩家%d" % (i + 1),
			"cash": STARTING_CASH,
			"control": 0.0,
			"action_cooldown": 0.0,
			"slots": [_make_skill("移动1"), _make_skill("普攻1"), null],
		})

	_generate_roguelike_districts()
	_assign_district_card_choices()
	var center := Vector2(map_width_m * 0.5, map_height_m * 0.5)
	selected_district = _nearest_district_to(center)
	if selected_district < 0:
		selected_district = 0
	var guardian_start := _farthest_district_from(selected_district)

	monster = {
		"name": monster_template["name"],
		"hp": monster_template["hp"],
		"max_hp": monster_template["hp"],
		"position": selected_district,
		"world_position": _district_center(selected_district),
		"armor": monster_template["armor"],
	}
	guardian = {
		"name": guardian_template["name"],
		"hp": guardian_template["hp"],
		"max_hp": guardian_template["hp"],
		"move": guardian_template["move"],
		"position": guardian_start,
		"world_position": _district_center(guardian_start),
	}

	_log("即时原型启动：%d名玩家，%s 对战 %s。" % [configured_player_count, monster["name"], guardian["name"]])
	_log("当前平衡预设：%s。" % _balance_preset()["label"])
	_log("本局地图：%.0fm×%.0fm连续城区，生成%d个不规则区域。" % [map_width_m, map_height_m, districts.size()])
	_log("本局卡池由通用牌、%s专属牌、%s应对牌组成；每个区域提供3-4张即时候选。" % [monster["name"], guardian["name"]])
	_refresh_ui()


func _make_skill(skill_name: String) -> Dictionary:
	var base: Dictionary = SKILL_CATALOG.get(skill_name, {})
	var skill := base.duplicate(true)
	skill["name"] = skill_name
	skill["charge"] = 0
	skill["cooldown"] = DEFAULT_SKILL_COOLDOWN + float(skill.get("cost", 2)) * 0.35
	skill["cooldown_left"] = 0.0
	return skill


func _set_speed(value: float) -> void:
	time_scale = value
	_refresh_ui()


func _toggle_pause() -> void:
	time_scale = 1.0 if time_scale <= 0.0 else 0.0
	_refresh_ui()


func _refresh_ui() -> void:
	_refresh_status()
	_refresh_setup_panel()
	_refresh_board()
	_refresh_player_panel()
	_refresh_district_panel()
	_refresh_market_panel()
	_refresh_combat_panel()
	_refresh_log()


func _refresh_status() -> void:
	var controller := _monster_controller()
	var controller_text := "无人"
	if controller >= 0:
		controller_text = players[controller]["name"]
	status_label.text = "时间 %s  速度 %.0fx  预设:%s  怪兽控制:%s  怪兽行动 %.1fs  守护者 %.1fs" % [
		_format_time(game_time),
		time_scale,
		_balance_preset()["label"],
		controller_text,
		max(0.0, monster_timer),
		max(0.0, guardian_timer),
	]


func _refresh_setup_panel() -> void:
	_clear_children(setup_box)
	var monster_template: Dictionary = _monster_template()
	var guardian_template: Dictionary = _guardian_template()
	setup_box.add_child(_plain_label("下次开局配置：%d人｜%s｜%s｜%s" % [
		configured_player_count,
		monster_template["name"],
		guardian_template["name"],
		_balance_preset()["label"],
	], 13, Color("#e2e8f0")))
	setup_box.add_child(_plain_label("玩家数、怪兽、守护者会在重新开局后生效；平衡预设可即时切换。", 12, Color("#94a3b8")))
	setup_box.add_child(_plain_label("本局地图：%.0fm×%.0fm连续城区，%d个不规则区域；重新开局会重掷地图。" % [
		map_width_m,
		map_height_m,
		districts.size(),
	], 12, Color("#a7f3d0")))
	setup_box.add_child(_plain_label("本局卡池会随怪兽与守护者变化：通用牌 + %s专属牌 + %s应对牌。" % [
		monster_template["name"],
		guardian_template["name"],
	], 12, Color("#fde68a")))

	var player_row := HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 6)
	setup_box.add_child(player_row)
	player_row.add_child(_plain_label("玩家数", 12, Color("#cbd5e1")))
	for count in range(MIN_PLAYER_COUNT, MAX_PLAYER_COUNT + 1):
		var player_button := Button.new()
		player_button.text = "%d人" % count
		player_button.toggle_mode = true
		player_button.button_pressed = count == configured_player_count
		player_button.pressed.connect(Callable(self, "_set_configured_player_count").bind(count))
		player_row.add_child(player_button)

	setup_box.add_child(_plain_label("怪兽：%s — %s" % [monster_template["name"], monster_template["style"]], 12, Color("#fecaca")))
	var monster_row := HBoxContainer.new()
	monster_row.add_theme_constant_override("separation", 6)
	setup_box.add_child(monster_row)
	for i in range(MONSTER_ROSTER.size()):
		var monster_data: Dictionary = MONSTER_ROSTER[i]
		var monster_button := Button.new()
		monster_button.text = monster_data["name"]
		monster_button.toggle_mode = true
		monster_button.button_pressed = i == configured_monster_index
		monster_button.pressed.connect(Callable(self, "_set_configured_monster").bind(i))
		monster_row.add_child(monster_button)

	setup_box.add_child(_plain_label("守护者：%s — %s" % [guardian_template["name"], guardian_template["style"]], 12, Color("#bae6fd")))
	var guardian_row := HBoxContainer.new()
	guardian_row.add_theme_constant_override("separation", 6)
	setup_box.add_child(guardian_row)
	for i in range(GUARDIAN_ROSTER.size()):
		var guardian_data: Dictionary = GUARDIAN_ROSTER[i]
		var guardian_button := Button.new()
		guardian_button.text = guardian_data["name"]
		guardian_button.toggle_mode = true
		guardian_button.button_pressed = i == configured_guardian_index
		guardian_button.pressed.connect(Callable(self, "_set_configured_guardian").bind(i))
		guardian_row.add_child(guardian_button)

	var start_row := HBoxContainer.new()
	start_row.add_theme_constant_override("separation", 6)
	setup_box.add_child(start_row)
	var apply_button := Button.new()
	apply_button.text = "应用并重新开局"
	apply_button.pressed.connect(Callable(self, "_new_game"))
	start_row.add_child(apply_button)


func _refresh_board() -> void:
	if map_view == null:
		return
	map_view.set_map(
		districts,
		map_width_m,
		map_height_m,
		selected_district,
		_entity_world_position(monster),
		_entity_world_position(guardian),
		DISTRICT_PALETTE
	)

func _district_button_text(index: int) -> String:
	var d: Dictionary = districts[index]
	var markers := []
	if monster["position"] == index:
		markers.append("怪兽")
	if guardian["position"] == index:
		markers.append("守护者")
	if d["miasma"]:
		markers.append("瘴气")
	var marker_text := ""
	if not markers.is_empty():
		marker_text = "\n[%s]" % " / ".join(markers)
	var state := "已破坏" if d["destroyed"] else "HP %d/%d" % [max(0, d["hp"] - d["damage"]), d["hp"]]
	return "%s%s\n%s  热%d\n%.0fm²  注%d" % [
		d["name"],
		marker_text,
		state,
		int(d["panic"]),
		float(d.get("area_m2", 0.0)),
		_total_bets(d),
	]


func _refresh_player_panel() -> void:
	_clear_children(player_box)

	var selector := HBoxContainer.new()
	selector.add_theme_constant_override("separation", 6)
	player_box.add_child(selector)
	for i in range(players.size()):
		var button := Button.new()
		button.text = players[i]["name"]
		button.toggle_mode = true
		button.button_pressed = i == selected_player
		button.pressed.connect(Callable(self, "_select_player").bind(i))
		selector.add_child(button)

	var player: Dictionary = players[selected_player]
	player_box.add_child(_plain_label("%s  筹码:%d  控制权:%.1f  操作冷却:%.1fs" % [
		player["name"],
		player["cash"],
		player["control"],
		max(0.0, player["action_cooldown"]),
	], 16, Color("#e2e8f0")))
	player_box.add_child(_plain_label("构筑倾向：%s" % _player_build_summary(player), 12, Color("#c4b5fd")))
	player_box.add_child(_plain_label("快捷键：1-%d选玩家  Q/E选区域  T切换判断  Y切预设  B下注  W撤注  C充能  X获取区域卡  V夺控  G移动  Space暂停" % players.size(), 12, Color("#94a3b8")))

	var prediction_row := HBoxContainer.new()
	prediction_row.add_theme_constant_override("separation", 6)
	player_box.add_child(prediction_row)
	var collapse_button := Button.new()
	collapse_button.text = "判断: 塌陷"
	collapse_button.toggle_mode = true
	collapse_button.button_pressed = prediction_mode == "塌陷"
	collapse_button.pressed.connect(Callable(self, "_set_prediction").bind("塌陷"))
	prediction_row.add_child(collapse_button)
	var survive_button := Button.new()
	survive_button.text = "判断: 存活"
	survive_button.toggle_mode = true
	survive_button.button_pressed = prediction_mode == "存活"
	survive_button.pressed.connect(Callable(self, "_set_prediction").bind("存活"))
	prediction_row.add_child(survive_button)
	player_box.add_child(_plain_label(_selected_prediction_preview(districts[selected_district]), 12, Color("#fcd34d")))

	var action_row := GridContainer.new()
	action_row.columns = 2
	action_row.add_theme_constant_override("h_separation", 6)
	action_row.add_theme_constant_override("v_separation", 6)
	player_box.add_child(action_row)
	_add_action_button(action_row, "实时下注 +200", "_place_bet")
	_add_action_button(action_row, "撤回下注 -100", "_withdraw_bet")
	_add_action_button(action_row, "卡牌充能", "_charge_skills")
	_add_action_button(action_row, "获取区域卡牌", "_buy_selected_skill")
	_add_action_button(action_row, "夺取怪兽控制", "_seize_control")
	_add_action_button(action_row, "指挥怪兽移动", "_direct_monster")

	for i in range(player["slots"].size()):
		var skill = player["slots"][i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		player_box.add_child(row)
		if skill == null:
			row.add_child(_plain_label("槽%d：空" % (i + 1), 13, Color("#94a3b8")))
			continue
		var cooldown_text := ""
		if skill["cooldown_left"] > 0.0:
			cooldown_text = "  冷却%.1fs" % skill["cooldown_left"]
		var text := "%s  [%s]  %d/%d%s  %s" % [skill["name"], _skill_tag_text(skill), skill["charge"], skill["cost"], cooldown_text, skill["text"]]
		var label := _plain_label(text, 13, Color("#e5e7eb"))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var use_button := Button.new()
		use_button.text = "打出"
		use_button.disabled = game_over or player["action_cooldown"] > 0.0 or skill["charge"] < skill["cost"] or skill["cooldown_left"] > 0.0
		use_button.pressed.connect(Callable(self, "_use_skill").bind(i))
		row.add_child(use_button)
		var upgrade_button := Button.new()
		upgrade_button.text = "升级"
		upgrade_button.disabled = not _can_upgrade_skill_slot(player, i, selected_market_skill)
		upgrade_button.pressed.connect(Callable(self, "_upgrade_skill_slot").bind(i))
		row.add_child(upgrade_button)
		var replace_button := Button.new()
		replace_button.text = "替换"
		replace_button.disabled = not _can_replace_skill_slot(selected_market_skill)
		replace_button.pressed.connect(Callable(self, "_replace_skill_slot").bind(i))
		row.add_child(replace_button)


func _add_action_button(parent: Container, text: String, method: String) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = game_over or players[selected_player]["action_cooldown"] > 0.0
	button.pressed.connect(Callable(self, method))
	parent.add_child(button)


func _refresh_district_panel() -> void:
	_clear_children(district_box)
	var d: Dictionary = districts[selected_district]
	district_box.add_child(_plain_label("%s  %s" % [d["name"], "已破坏" if d["destroyed"] else "未破坏"], 16, Color("#f8fafc")))
	district_box.add_child(_plain_label("区域HP: %d/%d  面积:%.0fm²  热度:%d  奖金:%d  瘴气:%s" % [
		max(0, d["hp"] - d["damage"]),
		d["hp"],
		float(d.get("area_m2", 0.0)),
		int(d["panic"]),
		d["bonus"],
		"有" if d["miasma"] else "无",
	], 14, Color("#cbd5e1")))
	district_box.add_child(_plain_label("塌陷压力:%s  下注席位:%d/%d" % [
		_collapse_pressure_label(d),
		_bettor_count(d),
		_district_limit(),
	], 13, Color("#fbbf24")))
	district_box.add_child(_plain_label("邻近:%s  距怪兽:%s  距守护者:%s" % [
		_district_connection_summary(selected_district),
		_entity_distance_to_district_label(monster, selected_district),
		_entity_distance_to_district_label(guardian, selected_district),
	], 12, Color("#a7f3d0")))
	district_box.add_child(_plain_label("怪兽目标概率:%s  主因:%s" % [
		_monster_target_probability_text(selected_district),
		_monster_target_factor_summary(selected_district),
	], 13, Color("#fca5a5")))
	var card_choices: Array = d.get("card_choices", [])
	if card_choices.is_empty():
		district_box.add_child(_plain_label("区域卡牌选择：暂无候选。", 13, Color("#94a3b8")))
	else:
		district_box.add_child(_plain_label("区域卡牌选择：从这些即时候选里挑一张加入你的构筑；获取会占用一次市场动作。", 13, Color("#fde68a")))
		for card_name_variant in card_choices:
			var card_name := String(card_name_variant)
			if not SKILL_CATALOG.has(card_name):
				continue
			var skill: Dictionary = SKILL_CATALOG[card_name]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			district_box.add_child(row)
			var button := Button.new()
			var prefix := ">> " if card_name == selected_market_skill else ""
			var upgrade_tag := " [升级]" if _is_upgrade_card(card_name) else ""
			var availability := "" if skill_market.has(card_name) else "（已被拿走）"
			button.text = "%s%s%s%s  [%s]  %d充能  %s" % [
				prefix,
				card_name,
				upgrade_tag,
				availability,
				_skill_tag_text(skill),
				skill["cost"],
				skill["text"],
			]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.disabled = game_over or d["destroyed"] or not skill_market.has(card_name)
			button.pressed.connect(Callable(self, "_select_district_card").bind(card_name))
			row.add_child(button)
			var claim_button := Button.new()
			claim_button.text = "获取"
			claim_button.disabled = game_over or d["destroyed"] or not skill_market.has(card_name) or players[selected_player]["action_cooldown"] > 0.0
			claim_button.pressed.connect(Callable(self, "_claim_district_card").bind(card_name))
			row.add_child(claim_button)
	district_box.add_child(_plain_label("下注：\n%s" % _format_bets(d), 13, Color("#e5e7eb")))


func _refresh_market_panel() -> void:
	_clear_children(market_box)
	if skill_market.is_empty():
		market_box.add_child(_plain_label("本局卡池已被拿空。", 14, Color("#94a3b8")))
		return
	market_box.add_child(_plain_label("本局卡池参考：卡牌要在区域候选里获取，下面用于查看它们分布在哪些区域。", 12, Color("#94a3b8")))
	if selected_market_skill != "" and SKILL_CATALOG.has(selected_market_skill):
		var selected_card: Dictionary = SKILL_CATALOG[selected_market_skill]
		market_box.add_child(_plain_label("选中：%s [%s] — %s｜%s" % [
			selected_market_skill,
			_skill_tag_text(selected_card),
			selected_card["text"],
			_card_choice_location_summary(selected_market_skill),
		], 12, Color("#fde68a")))
	for skill_name in skill_market:
		var skill: Dictionary = SKILL_CATALOG[skill_name]
		var button := Button.new()
		var prefix := ">> " if skill_name == selected_market_skill else ""
		var upgrade_tag := " [升级]" if _is_upgrade_card(skill_name) else ""
		var local_tag := " 当前区域可取" if _selected_district_has_card(skill_name) else " %s" % _card_choice_location_summary(skill_name)
		button.text = "%s%s%s  [%s]  %d充能  %s" % [prefix, skill_name, upgrade_tag, _skill_tag_text(skill), skill["cost"], local_tag]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = game_over
		button.pressed.connect(Callable(self, "_select_market_skill").bind(skill_name))
		market_box.add_child(button)


func _refresh_combat_panel() -> void:
	_clear_children(combat_box)
	combat_box.add_child(_plain_label("怪兽：%s  HP %d/%d  护甲:%d  位置:%s" % [
		monster["name"],
		max(0, monster["hp"]),
		monster["max_hp"],
		monster["armor"],
		districts[monster["position"]]["name"],
	], 14, Color("#fecaca")))
	combat_box.add_child(_plain_label("怪兽卡池：%s" % _monster_skill_summary(), 12, Color("#fecdd3")))
	combat_box.add_child(_plain_label("守护者：%s  HP %d/%d  位置:%s" % [
		guardian["name"],
		max(0, guardian["hp"]),
		guardian["max_hp"],
		districts[guardian["position"]]["name"],
	], 14, Color("#bae6fd")))
	combat_box.add_child(_plain_label("概率行动表：%s" % _guardian_action_summary(), 12, Color("#bfdbfe")))
	combat_box.add_child(_plain_label("怪兽目标候选：%s" % _monster_target_debug_summary(3), 12, Color("#fca5a5")))
	combat_box.add_child(_plain_label("相距：%s  事件 %.1fs  市场 %.1fs" % [
		_meters_text(_entity_distance(monster, guardian)),
		max(0.0, event_timer),
		max(0.0, market_timer),
	], 14, Color("#cbd5e1")))
	var preset: Dictionary = _balance_preset()
	combat_box.add_child(_plain_label("平衡预设：%s｜%s" % [preset["label"], preset["desc"]], 13, Color("#fde68a")))

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 6)
	combat_box.add_child(preset_row)
	for i in range(BALANCE_PRESETS.size()):
		var preset_data: Dictionary = BALANCE_PRESETS[i]
		var preset_button := Button.new()
		preset_button.text = preset_data["label"]
		preset_button.toggle_mode = true
		preset_button.button_pressed = i == current_balance_index
		preset_button.disabled = game_over
		preset_button.pressed.connect(Callable(self, "_set_balance_preset").bind(i))
		preset_row.add_child(preset_button)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	combat_box.add_child(row)
	var guardian_button := Button.new()
	guardian_button.text = "模拟守护者行动（%s表）" % guardian["name"]
	guardian_button.disabled = game_over
	guardian_button.pressed.connect(Callable(self, "_guardian_tick"))
	row.add_child(guardian_button)
	var event_button := Button.new()
	event_button.text = "推进突发事件"
	event_button.disabled = game_over
	event_button.pressed.connect(Callable(self, "_world_event"))
	row.add_child(event_button)
	var settle_button := Button.new()
	settle_button.text = "强制结算"
	settle_button.disabled = game_over
	settle_button.pressed.connect(Callable(self, "_manual_settlement"))
	row.add_child(settle_button)


func _refresh_log() -> void:
	log_view.clear()
	for line in log_lines:
		log_view.append_text(line + "\n")


func _select_player(index: int) -> void:
	if index < 0 or index >= players.size():
		return
	selected_player = index
	_refresh_ui()


func _select_district(index: int) -> void:
	selected_district = index
	_refresh_ui()


func _cycle_district(step: int) -> void:
	selected_district = wrapi(selected_district + step, 0, districts.size())
	_refresh_ui()


func _set_prediction(mode: String) -> void:
	prediction_mode = mode
	_refresh_ui()


func _toggle_prediction_mode() -> void:
	if prediction_mode == "塌陷":
		prediction_mode = "存活"
	else:
		prediction_mode = "塌陷"
	_log("下注判断切换为：%s。" % prediction_mode)
	_refresh_ui()


func _cycle_balance_preset() -> void:
	_set_balance_preset((current_balance_index + 1) % BALANCE_PRESETS.size())


func _set_balance_preset(index: int) -> void:
	var clamped_index: int = max(0, min(index, int(BALANCE_PRESETS.size()) - 1))
	if clamped_index == current_balance_index:
		return
	current_balance_index = clamped_index
	_retime_for_balance_change()
	var preset: Dictionary = _balance_preset()
	_log("平衡预设切换为：%s。%s" % [preset["label"], preset["desc"]])
	_refresh_ui()


func _set_configured_player_count(count: int) -> void:
	configured_player_count = max(MIN_PLAYER_COUNT, min(count, MAX_PLAYER_COUNT))
	_log("下次开局玩家数设置为：%d人。" % configured_player_count)
	_refresh_ui()


func _set_configured_monster(index: int) -> void:
	configured_monster_index = max(0, min(index, int(MONSTER_ROSTER.size()) - 1))
	var monster_template: Dictionary = _monster_template()
	_log("下次开局怪兽设置为：%s。" % monster_template["name"])
	_refresh_ui()


func _set_configured_guardian(index: int) -> void:
	configured_guardian_index = max(0, min(index, int(GUARDIAN_ROSTER.size()) - 1))
	var guardian_template: Dictionary = _guardian_template()
	_log("下次开局守护者设置为：%s。" % guardian_template["name"])
	_refresh_ui()


func _balance_preset() -> Dictionary:
	return BALANCE_PRESETS[current_balance_index] as Dictionary


func _monster_template() -> Dictionary:
	return MONSTER_ROSTER[configured_monster_index] as Dictionary


func _guardian_template() -> Dictionary:
	return GUARDIAN_ROSTER[configured_guardian_index] as Dictionary


func _guardian_actions() -> Array:
	return (GUARDIAN_ACTION_TABLES.get(guardian.get("name", "机械杰克"), GUARDIAN_ACTION_TABLES["机械杰克"]) as Array)


func _guardian_action_summary() -> String:
	var actions := _guardian_actions()
	var weights := _guardian_action_weights(_has_destroyed_district())
	var total := _weight_total(weights)
	var names := []
	for i in range(actions.size()):
		var weight := int(weights[i])
		if weight <= 0:
			continue
		var action: Dictionary = actions[i]
		names.append("%s %s" % [action["name"], _probability_text(weight, total)])
	return " / ".join(names)


func _append_unique_cards(result: Array, names: Array) -> void:
	for name_variant in names:
		var skill_name := String(name_variant)
		if skill_name == "" or result.has(skill_name):
			continue
		if not SKILL_CATALOG.has(skill_name):
			push_warning("卡牌目录缺少：%s" % skill_name)
			continue
		result.append(skill_name)


func _current_run_card_pool() -> Array:
	var result := []
	var monster_template: Dictionary = _monster_template()
	var guardian_template: Dictionary = _guardian_template()
	_append_unique_cards(result, COMMON_CARD_POOL)
	_append_unique_cards(result, monster_template.get("market_skills", []))
	_append_unique_cards(result, guardian_template.get("guardian_cards", []))
	return result


func _current_run_featured_cards() -> Array:
	var result := []
	var monster_template: Dictionary = _monster_template()
	var guardian_template: Dictionary = _guardian_template()
	for name_variant in monster_template.get("market_skills", []):
		var skill_name := String(name_variant)
		if COMMON_CARD_POOL.has(skill_name):
			continue
		_append_unique_cards(result, [skill_name])
	_append_unique_cards(result, guardian_template.get("guardian_cards", []))
	return result


func _monster_market_skills() -> Array:
	return _current_run_card_pool()


func _monster_skill_summary() -> String:
	var names := []
	for skill_name in _current_run_card_pool():
		if not COMMON_CARD_POOL.has(skill_name):
			names.append(skill_name)
	return " / ".join(names)


func _skill_tag_text(skill: Dictionary) -> String:
	var tags: Array = skill.get("tags", [])
	if tags.is_empty():
		tags = _derived_skill_tags(String(skill.get("kind", "")))
	return " / ".join(tags)


func _derived_skill_tags(kind: String) -> Array:
	match kind:
		"bet_boost", "cash_gain":
			return ["经济"]
		"market_boost", "panic_shift":
			return ["市场"]
		"control_gain":
			return ["控制"]
		"charge_other":
			return ["构筑"]
		"guardian_delay":
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


func _district_limit() -> int:
	return int(ceil(float(configured_player_count) / 2.0))


func _preset_float(key: String) -> float:
	return float(_balance_preset().get(key, 0.0))


func _preset_int(key: String) -> int:
	return int(_balance_preset().get(key, 0))


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


func _has_destroyed_district() -> bool:
	for d in districts:
		if bool(d["destroyed"]):
			return true
	return false


func _guardian_action_weights(any_destroyed: bool) -> Array:
	var actions := _guardian_actions()
	var source_weights: Array = GUARDIAN_ESCALATED_ACTION_WEIGHTS if any_destroyed else GUARDIAN_EARLY_ACTION_WEIGHTS
	var weights := []
	for i in range(actions.size()):
		weights.append(int(source_weights[i]) if i < source_weights.size() else 0)
	return weights


func _weight_part_total(parts: Dictionary) -> int:
	var total := 0
	for key in parts:
		total += max(0, int(parts[key]))
	return total


func _event_target_weight_parts(index: int) -> Dictionary:
	var parts := {
		"base": 0,
		"panic": 0,
		"bonus": 0,
		"bets": 0,
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
	parts["bonus"] = int(d["bonus"] / EVENT_TARGET_BONUS_DIVISOR)
	parts["bets"] = int(_total_bets(d) / EVENT_TARGET_BET_DIVISOR)
	if d["miasma"]:
		parts["miasma"] = EVENT_TARGET_MIASMA_BONUS
	if monster["position"] == index:
		parts["monster"] = EVENT_TARGET_MONSTER_BONUS
	return parts


func _district_event_weight(index: int) -> int:
	if index < 0 or index >= districts.size():
		return 0
	var d: Dictionary = districts[index]
	if d["destroyed"]:
		return 0
	return max(1, _weight_part_total(_event_target_weight_parts(index)))


func _monster_target_weight_parts(index: int) -> Dictionary:
	var parts := {
		"base": 0,
		"panic": 0,
		"bonus": 0,
		"bets": 0,
		"distance": 0,
		"miasma": 0,
		"guardian": 0,
	}
	if index < 0 or index >= districts.size():
		return parts
	var d: Dictionary = districts[index]
	if d["destroyed"]:
		return parts
	parts["base"] = MONSTER_TARGET_BASE_WEIGHT
	parts["panic"] = int(d["panic"]) * MONSTER_TARGET_PANIC_WEIGHT
	parts["bonus"] = int(d["bonus"] / MONSTER_TARGET_BONUS_DIVISOR)
	parts["bets"] = int(_total_bets(d) / MONSTER_TARGET_BET_DIVISOR)
	parts["distance"] = max(0, MONSTER_TARGET_DISTANCE_BASE - _distance(monster["position"], index) * MONSTER_TARGET_DISTANCE_STEP)
	if d["miasma"]:
		parts["miasma"] = MONSTER_TARGET_MIASMA_BONUS
	if guardian["position"] == index:
		parts["guardian"] = MONSTER_TARGET_GUARDIAN_BONUS
	return parts


func _monster_target_weight(index: int) -> int:
	if index < 0 or index >= districts.size():
		return 0
	if districts[index]["destroyed"]:
		return 0
	return max(1, _weight_part_total(_monster_target_weight_parts(index)))


func _monster_target_candidates() -> Array:
	var result := []
	for i in range(districts.size()):
		if districts[i]["destroyed"]:
			continue
		var weight := _monster_target_weight(i)
		if weight > 0:
			result.append({"index": i, "weight": weight})
	return result


func _monster_target_weight_total() -> int:
	var total := 0
	for entry in _monster_target_candidates():
		total += int(entry["weight"])
	return total


func _monster_target_probability_text(index: int) -> String:
	if index < 0 or index >= districts.size():
		return "无"
	if districts[index]["destroyed"]:
		return "已排除"
	var total := _monster_target_weight_total()
	if total <= 0:
		return "无可选目标"
	var weight := _monster_target_weight(index)
	return "%s（权重%d/%d）" % [_probability_text(weight, total), weight, total]


func _monster_target_factor_summary(index: int) -> String:
	if index < 0 or index >= districts.size():
		return "无"
	if districts[index]["destroyed"]:
		return "已破坏，已排除"
	var parts := _monster_target_weight_parts(index)
	var candidates := [
		{"name": "热度", "value": int(parts["panic"])},
		{"name": "距离", "value": int(parts["distance"])},
		{"name": "下注", "value": int(parts["bets"])},
		{"name": "奖金", "value": int(parts["bonus"])},
		{"name": "瘴气", "value": int(parts["miasma"])},
		{"name": "守护者", "value": int(parts["guardian"])},
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


func _prime_timers_for_new_game() -> void:
	event_timer = max(1.0, _preset_float("event_min") * 0.75)
	guardian_timer = max(1.0, _preset_float("guardian_min") * 0.9)
	monster_timer = max(1.0, _preset_float("monster_min") * 0.8)
	market_timer = max(1.0, _preset_float("market_min") * 0.9)


func _retime_for_balance_change() -> void:
	event_timer = min(event_timer, _roll_timer("event"))
	guardian_timer = min(guardian_timer, _roll_timer("guardian"))
	monster_timer = min(monster_timer, _roll_timer("monster"))
	market_timer = min(market_timer, _roll_timer("market"))


func _select_market_skill(skill_name: String) -> void:
	selected_market_skill = skill_name
	_refresh_ui()


func _select_district_card(skill_name: String) -> void:
	if selected_district < 0 or selected_district >= districts.size():
		return
	if districts[selected_district]["destroyed"]:
		_log("%s已被破坏，不能从这里获取卡牌。" % districts[selected_district]["name"])
		return
	if not _selected_district_has_card(skill_name):
		_log("%s不是当前区域的候选卡。" % skill_name)
		return
	if not skill_market.has(skill_name):
		_log("%s已经被其他玩家拿走，换一张区域候选吧。" % skill_name)
		_sync_selected_market_skill()
	else:
		selected_market_skill = skill_name
		_log("选中%s的区域候选卡：%s。" % [districts[selected_district]["name"], skill_name])
	_refresh_ui()


func _claim_district_card(skill_name: String) -> void:
	if selected_district < 0 or selected_district >= districts.size():
		return
	if districts[selected_district]["destroyed"]:
		_log("%s已被破坏，不能从这里获取卡牌。" % districts[selected_district]["name"])
		_refresh_ui()
		return
	if not _selected_district_has_card(skill_name):
		_log("%s不是当前区域的候选卡。%s" % [skill_name, _card_choice_location_summary(skill_name)])
		_refresh_ui()
		return
	selected_market_skill = skill_name
	_buy_selected_skill()


func _sync_selected_market_skill() -> void:
	if selected_market_skill != "" and skill_market.has(selected_market_skill):
		return
	selected_market_skill = skill_market[0] if not skill_market.is_empty() else ""


func _district_has_card(district_index: int, skill_name: String) -> bool:
	if district_index < 0 or district_index >= districts.size() or skill_name == "":
		return false
	var choices: Array = districts[district_index].get("card_choices", [])
	return choices.has(skill_name)


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


func _remove_card_from_district_choices(skill_name: String) -> void:
	if skill_name == "":
		return
	for district in districts:
		var choices: Array = district.get("card_choices", [])
		while choices.has(skill_name):
			choices.erase(skill_name)
		district["card_choices"] = choices


func _add_card_to_district_choices(district_index: int, skill_name: String) -> void:
	if district_index < 0 or district_index >= districts.size() or skill_name == "":
		return
	if not SKILL_CATALOG.has(skill_name):
		return
	var choices: Array = districts[district_index].get("card_choices", [])
	if choices.has(skill_name):
		return
	if choices.size() >= 4:
		return
	choices.append(skill_name)
	districts[district_index]["card_choices"] = choices


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
	if skill_name == "" or not SKILL_CATALOG.has(skill_name):
		return false
	var family := _skill_family(skill_name)
	return _skill_rank(skill_name) > 1 and UPGRADEABLE_SKILL_FAMILIES.has(family)


func _can_upgrade_skill_slot(player: Dictionary, slot_index: int, target_skill_name: String) -> bool:
	if game_over or player["action_cooldown"] > 0.0:
		return false
	if target_skill_name == "" or not skill_market.has(target_skill_name) or not _is_upgrade_card(target_skill_name):
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
		and int(current["charge"]) >= int(current["cost"])
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
		and skill_market.has(target_skill_name)
		and _selected_district_has_card(target_skill_name)
		and not _is_upgrade_card(target_skill_name)
	)


func _can_selected_player_act() -> bool:
	if game_over:
		return false
	var player: Dictionary = players[selected_player]
	if player["action_cooldown"] > 0.0:
		_log("%s操作冷却中，还需%.1fs。" % [player["name"], player["action_cooldown"]])
		return false
	return true


func _start_player_cooldown(seconds: float) -> void:
	players[selected_player]["action_cooldown"] = max(players[selected_player]["action_cooldown"], seconds)


func _place_bet(ignore_cooldown := false, amount_override := BET_UNIT) -> void:
	if not ignore_cooldown and not _can_selected_player_act():
		return
	var player: Dictionary = players[selected_player]
	var district: Dictionary = districts[selected_district]
	if district["destroyed"]:
		_log("%s已被破坏，不能继续下注。" % district["name"])
		return
	if player["cash"] <= 0:
		_log("%s没有可下注筹码。" % player["name"])
		return
	var pid: int = player["id"]
	if not district["bets"].has(pid):
		if _bettor_count(district) >= _district_limit():
			_log("%s下注席位已满。" % district["name"])
			return
		district["bets"][pid] = {"amount": 0, "prediction": prediction_mode}
	var placed: int = min(amount_override, player["cash"])
	player["cash"] -= placed
	district["bets"][pid]["amount"] += placed
	district["bets"][pid]["prediction"] = prediction_mode
	district["panic"] = min(100, district["panic"] + 4)
	_log("%s实时押注%s %d，判断为%s。" % [player["name"], district["name"], placed, prediction_mode])
	if not ignore_cooldown:
		_start_player_cooldown(ACTION_COOLDOWN)
	_refresh_ui()


func _withdraw_bet() -> void:
	if not _can_selected_player_act():
		return
	var player: Dictionary = players[selected_player]
	var district: Dictionary = districts[selected_district]
	var pid: int = player["id"]
	if not district["bets"].has(pid):
		_log("%s在%s没有下注可撤回。" % [player["name"], district["name"]])
		return
	var amount: int = min(WITHDRAW_UNIT, district["bets"][pid]["amount"])
	district["bets"][pid]["amount"] -= amount
	player["cash"] += amount
	if district["bets"][pid]["amount"] <= 0:
		district["bets"].erase(pid)
	_log("%s从%s撤回%d筹码。" % [player["name"], district["name"], amount])
	_start_player_cooldown(ACTION_COOLDOWN)
	_refresh_ui()


func _charge_skills() -> void:
	if not _can_selected_player_act():
		return
	var player: Dictionary = players[selected_player]
	var spent := 0
	var limit: int = 300 + max(0, int(player["slots"].size()) - 3) * 200
	for skill in player["slots"]:
		if skill == null:
			continue
		while player["cash"] >= CHARGE_UNIT and spent + CHARGE_UNIT <= limit and skill["charge"] < skill["cost"]:
			player["cash"] -= CHARGE_UNIT
			spent += CHARGE_UNIT
			skill["charge"] += 1
	if spent == 0:
		_log("%s没有可充能卡牌或筹码不足。" % player["name"])
	else:
		_log("%s实时充能花费%d。" % [player["name"], spent])
		_start_player_cooldown(CHARGE_COOLDOWN)
	_refresh_ui()


func _buy_selected_skill() -> void:
	if not _can_selected_player_act():
		return
	var player: Dictionary = players[selected_player]
	if selected_market_skill == "" or not skill_market.has(selected_market_skill):
		_log("没有可购买的选中卡牌。")
		return
	if selected_district < 0 or selected_district >= districts.size():
		return
	if districts[selected_district]["destroyed"]:
		_log("%s已被破坏，不能从这里获取卡牌。" % districts[selected_district]["name"])
		return
	if not _selected_district_has_card(selected_market_skill):
		_log("%s不在当前区域候选中；%s。" % [selected_market_skill, _card_choice_location_summary(selected_market_skill)])
		return
	if _is_upgrade_card(selected_market_skill):
		for i in range(player["slots"].size()):
			if _can_upgrade_skill_slot(player, i, selected_market_skill):
				_upgrade_skill_slot(i)
				return
		_log("%s是升级牌：需要同名低一级卡牌满充能后才能升级，不能直接放入空槽。" % selected_market_skill)
		return
	var empty_index := -1
	for i in range(player["slots"].size()):
		if player["slots"][i] == null:
			empty_index = i
			break
	if empty_index == -1:
		if player["slots"].size() >= 6:
			_log("%s已达到6个卡槽上限。" % player["name"])
			return
		if player["cash"] < 500:
			_log("%s需要500筹码开启新卡槽。" % player["name"])
			return
		player["cash"] -= 500
		player["slots"].append(null)
		empty_index = player["slots"].size() - 1
		_log("%s支付500开启新卡槽。" % player["name"])
	var bought_name := selected_market_skill
	player["slots"][empty_index] = _make_skill(bought_name)
	skill_market.erase(bought_name)
	_remove_card_from_district_choices(bought_name)
	_log("%s购入卡牌：%s。" % [player["name"], bought_name])
	_sync_selected_market_skill()
	_start_player_cooldown(MARKET_COOLDOWN)
	_refresh_ui()


func _upgrade_skill_slot(slot_index: int) -> void:
	if not _can_selected_player_act():
		return
	var player: Dictionary = players[selected_player]
	var upgrade_name := selected_market_skill
	if not _can_upgrade_skill_slot(player, slot_index, upgrade_name):
		_log("无法升级：需要选中同系列高一级升级牌，并让原卡牌满充能。")
		return
	var old_skill: Dictionary = player["slots"][slot_index]
	var old_name := String(old_skill["name"])
	player["slots"][slot_index] = _make_skill(upgrade_name)
	skill_market.erase(upgrade_name)
	_remove_card_from_district_choices(upgrade_name)
	_sync_selected_market_skill()
	_log("%s将%s升级为%s。" % [player["name"], old_name, upgrade_name])
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
		_log("无法替换：请选择非升级牌的市场卡牌。")
		return
	var old_skill = player["slots"][slot_index]
	if old_skill == null:
		_log("空槽请直接购买卡牌。")
		return
	var old_name := String(old_skill["name"])
	var refund := int(old_skill["charge"]) * CHARGE_UNIT
	if refund > 0:
		player["cash"] += refund
	if old_name != "" and not skill_market.has(old_name):
		skill_market.append(old_name)
	player["slots"][slot_index] = _make_skill(replacement_name)
	skill_market.erase(replacement_name)
	_remove_card_from_district_choices(replacement_name)
	_add_card_to_district_choices(selected_district, old_name)
	_sync_selected_market_skill()
	_log("%s替换卡牌：%s → %s，返还充能%d。" % [player["name"], old_name, replacement_name, refund])
	_start_player_cooldown(MARKET_COOLDOWN)
	_refresh_ui()


func _seize_control() -> void:
	if not _can_selected_player_act():
		return
	var player: Dictionary = players[selected_player]
	var cost: int = min(200, int(player["cash"]))
	if cost <= 0:
		_log("%s没有筹码夺取控制权。" % player["name"])
		return
	player["cash"] -= cost
	player["control"] += 4.0 + float(cost) / 100.0
	_log("%s投入%d筹码夺取怪兽控制权。" % [player["name"], cost])
	_start_player_cooldown(CONTROL_COOLDOWN)
	_refresh_ui()


func _direct_monster() -> void:
	if not _can_selected_player_act():
		return
	var player: Dictionary = players[selected_player]
	if player["control"] < 1.0:
		_log("%s控制权不足，无法指挥怪兽。" % player["name"])
		return
	if districts[selected_district]["destroyed"]:
		_log("怪兽不能移动到已破坏区域。")
		return
	var moved := _move_entity_toward(monster, _district_center(selected_district), MONSTER_COMMAND_MOVE_METERS)
	player["control"] = max(0.0, player["control"] - 1.0)
	_log("%s实时指挥怪兽移动%s，当前进入%s。" % [player["name"], _meters_text(moved), districts[monster["position"]]["name"]])
	_damage_district(monster["position"], 1, "怪兽移动")
	_start_player_cooldown(COMMAND_COOLDOWN)
	_refresh_ui()


func _use_skill(slot_index: int) -> void:
	if not _can_selected_player_act():
		return
	var player: Dictionary = players[selected_player]
	var skill = player["slots"][slot_index]
	if skill == null or skill["charge"] < skill["cost"] or skill["cooldown_left"] > 0.0:
		return
	_log("%s即时打出%s。" % [player["name"], skill["name"]])
	match skill["kind"]:
		"bet_boost":
			_place_bet(true, int(skill.get("bet_amount", BET_UNIT)))
		"market_boost":
			_add_market_bonus(selected_district, int(skill.get("market_amount", 200)))
			_add_panic(selected_district, int(skill.get("panic", 12)), skill["name"])
		"cash_gain":
			var cash_gain: int = int(skill.get("cash", 0))
			player["cash"] += cash_gain
			_log("%s获得%d筹码。" % [player["name"], cash_gain])
		"panic_shift":
			_add_panic(selected_district, int(skill.get("panic", 0)), skill["name"])
		"control_gain":
			var control_gain: float = float(skill.get("control", 0.0))
			player["control"] += control_gain
			_log("%s获得%.1f怪兽控制权。" % [player["name"], control_gain])
		"charge_other":
			_charge_other_cards(player, slot_index, int(skill.get("charge_amount", 1)), skill["name"])
		"guardian_delay":
			var delay: float = float(skill.get("delay", 1.0))
			var control_gain: float = float(skill.get("control", 0.0))
			guardian_timer += delay
			if control_gain > 0.0:
				player["control"] += control_gain
			_log("%s干扰%s，守护者概率行动延后%.1fs，控制权+%.1f。" % [skill["name"], guardian["name"], delay, control_gain])
		"move":
			_move_monster_by_skill(float(skill["move"]), false)
		"fly":
			_move_monster_by_skill(float(skill["move"]), true)
		"burrow":
			_move_monster_by_skill(float(skill["move"]), true)
			var armor_gain: int = int(skill.get("armor", 2))
			monster["armor"] += armor_gain
			_log("怪兽获得%d点护甲。" % armor_gain)
		"attack":
			_monster_attack_guardian(int(skill["damage"]), float(skill["range"]), skill["name"], selected_player)
		"charge_attack":
			_move_monster_toward_guardian(float(skill["move"]))
			_monster_attack_guardian(int(skill["damage"]), float(skill["range"]), skill["name"], selected_player)
		"armor_gain":
			var direct_armor: int = int(skill.get("armor", 0))
			monster["armor"] += direct_armor
			_log("怪兽立即获得%d点护甲。" % direct_armor)
		"area_damage":
			if _entity_distance_to_district(monster, selected_district) <= float(skill["range"]):
				_damage_district(selected_district, int(skill["damage"]), skill["name"])
			else:
				_log("选中区域距离%s，超过%s范围%s。" % [
					_entity_distance_to_district_label(monster, selected_district),
					skill["name"],
					_meters_text(float(skill["range"])),
				])
		"miasma_shot":
			if _entity_distance(monster, guardian) <= float(skill["range"]):
				_guardian_take_damage(int(skill["damage"]), skill["name"], selected_player)
			else:
				_log("守护者不在瘴气炮%s范围内。" % _meters_text(float(skill["range"])))
			districts[selected_district]["miasma"] = true
			_log("%s留下瘴气token。" % districts[selected_district]["name"])
		"miasma_bloom":
			_place_miasma_burst(selected_district, int(skill.get("miasma_count", 3)), float(skill.get("range", DEFAULT_AOE_RADIUS_METERS)), skill["name"])
		"miasma_reclaim":
			_reclaim_miasma(int(skill.get("reclaim_count", 1)), float(skill.get("range", NEARBY_RADIUS_METERS)), skill["name"], selected_player)
		"corrosive_breath":
			if _entity_distance(monster, guardian) <= float(skill["range"]):
				_guardian_take_damage(int(skill["damage"]), skill["name"], selected_player)
			else:
				_log("守护者不在%s射程%s内。" % [skill["name"], _meters_text(float(skill["range"]))])
			_place_miasma_burst(selected_district, int(skill.get("miasma_count", 2)), float(skill.get("range", DEFAULT_AOE_RADIUS_METERS)), skill["name"])
		"roar":
			_roar_at_guardian(float(skill["range"]), float(skill.get("delay", 1.5)), skill["name"])
		"roll_attack":
			_roll_monster_attack(float(skill["move"]), float(skill.get("range", MELEE_RANGE_METERS)), int(skill["damage"]), skill["name"], selected_player)
		"mudslide":
			_mudslide(selected_district, float(skill["range"]), int(skill["damage"]), int(skill.get("panic", 0)), float(skill.get("delay", 1.0)), skill["name"])
	skill["charge"] = 0
	skill["cooldown_left"] = skill["cooldown"]
	_start_player_cooldown(COMMAND_COOLDOWN)
	_refresh_ui()


func _move_monster_by_skill(max_distance_m: float, ignore_distance: bool) -> void:
	if districts[selected_district]["destroyed"]:
		_log("怪兽不能移动到已破坏区域。")
		return
	var dist := _entity_distance_to_district(monster, selected_district)
	if not ignore_distance and dist > max_distance_m:
		_log("选中区域距离%s，超过卡牌移动力%s。" % [_meters_text(dist), _meters_text(max_distance_m)])
		return
	var moved := dist if ignore_distance else _move_entity_toward(monster, _district_center(selected_district), max_distance_m)
	if ignore_distance:
		_set_entity_world_position(monster, _district_center(selected_district))
	_log("怪兽移动%s至%s。" % [_meters_text(moved), districts[monster["position"]]["name"]])
	_damage_district(monster["position"], 1, "怪兽移动")


func _add_panic(index: int, amount: int, source: String) -> void:
	if index < 0 or index >= districts.size():
		return
	var d: Dictionary = districts[index]
	if d["destroyed"] or amount <= 0:
		return
	d["panic"] = min(100, int(d["panic"]) + amount)
	_log("%s使%s热度+%d。" % [source, d["name"], amount])
	if int(d["panic"]) >= 100:
		d["panic"] = 60
		_damage_district(index, 1, "%s引发恐慌" % source)


func _charge_other_cards(player: Dictionary, source_slot_index: int, amount: int, source: String) -> void:
	var charged := 0
	for i in range(player["slots"].size()):
		if i == source_slot_index:
			continue
		var other = player["slots"][i]
		if other == null:
			continue
		var before: int = int(other["charge"])
		other["charge"] = min(int(other["cost"]), before + amount)
		charged += int(other["charge"]) - before
	if charged > 0:
		_log("%s为其他卡牌补充%d点充能。" % [source, charged])
	else:
		_log("%s没有找到可补充能的其他卡牌。" % source)


func _mudslide(target_index: int, range_limit_m: float, damage: int, panic_amount: int, delay: float, source: String) -> void:
	if target_index < 0 or target_index >= districts.size():
		return
	if districts[target_index]["destroyed"]:
		_log("选中区域已破坏，不能打出%s。" % source)
		return
	if _entity_distance_to_district(monster, target_index) > range_limit_m:
		_log("选中区域距离%s，不在%s的%s AOE内。" % [
			_entity_distance_to_district_label(monster, target_index),
			source,
			_meters_text(range_limit_m),
		])
		return
	_damage_district(target_index, damage, source)
	_add_panic(target_index, panic_amount, source)
	if _entity_distance_to_district(guardian, target_index) <= range_limit_m:
		guardian_timer += delay
		_log("%s阻滞守护者，概率行动延后%.1fs。" % [source, delay])


func _place_miasma_burst(center_index: int, max_tokens: int, radius_m: float, source: String) -> void:
	if _entity_distance_to_district(monster, center_index) > radius_m:
		_log("%s目标距离%s，超过AOE投放范围%s。" % [source, _entity_distance_to_district_label(monster, center_index), _meters_text(radius_m)])
		return
	var candidates := _districts_in_radius(_district_center(center_index), radius_m, true)
	var placed := 0
	for index in candidates:
		if placed >= max_tokens:
			break
		var d: Dictionary = districts[index]
		if d["destroyed"] or d["miasma"]:
			continue
		d["miasma"] = true
		placed += 1
		_log("%s在%s散布瘴气。" % [source, d["name"]])
	if placed == 0:
		_log("%s没有找到可放置瘴气的区域。" % source)


func _reclaim_miasma(max_tokens: int, radius_m: float, source: String, source_pid: int) -> void:
	var candidates := _districts_in_radius(_entity_world_position(monster), radius_m, true)
	var reclaimed := 0
	var guardian_was_near := false
	for index in candidates:
		if reclaimed >= max_tokens:
			break
		if not districts[index]["miasma"]:
			continue
		districts[index]["miasma"] = false
		reclaimed += 1
		guardian_was_near = guardian_was_near or _entity_distance_to_district(guardian, index) <= radius_m
		_log("%s回收%s的瘴气。" % [source, districts[index]["name"]])
	if reclaimed <= 0:
		_log("%s没有可回收的邻近瘴气。" % source)
		return
	_monster_self_heal(reclaimed, source)
	if guardian_was_near:
		_guardian_take_damage(reclaimed, source, source_pid)


func _roar_at_guardian(range_limit_m: float, delay: float, source: String) -> void:
	if _entity_distance(monster, guardian) > range_limit_m:
		_log("守护者距离%s，不在%s范围%s内。" % [_meters_text(_entity_distance(monster, guardian)), source, _meters_text(range_limit_m)])
		return
	guardian_timer += delay
	_log("%s造成硬直，守护者概率行动延后%.1fs。" % [source, delay])


func _roll_monster_attack(max_distance_m: float, hit_radius_m: float, damage: int, source: String, source_pid: int) -> void:
	if districts[selected_district]["destroyed"]:
		_log("选中区域已破坏，不能打滚至此。")
		return
	var dist := _entity_distance_to_district(monster, selected_district)
	if dist > max_distance_m:
		_log("选中区域距离%s，超过%s移动力%s。" % [_meters_text(dist), source, _meters_text(max_distance_m)])
		return
	var moved := _move_entity_toward(monster, _district_center(selected_district), max_distance_m)
	_damage_district(monster["position"], 1, source)
	if _entity_distance(monster, guardian) <= hit_radius_m:
		_monster_attack_guardian(damage, hit_radius_m, source, source_pid)
	else:
		_log("%s移动%s至%s，但未进入%s近战圈。" % [source, _meters_text(moved), districts[monster["position"]]["name"], _meters_text(hit_radius_m)])


func _world_event() -> void:
	var index := _weighted_event_district()
	if index < 0:
		_finish_game("所有区域都已破坏。")
		return
	var d: Dictionary = districts[index]
	var heat_min: int = _preset_int("event_heat_min")
	var heat_max: int = _preset_int("event_heat_max")
	var heat: int = rng.randi_range(heat_min, heat_max)
	var event_bonus: int = _preset_int("event_bonus")
	d["panic"] = min(100, d["panic"] + heat)
	d["bonus"] += event_bonus
	_log("新闻热度按概率模型涌向%s：热度+%d，区域奖金+%d。" % [d["name"], heat, event_bonus])
	if d["panic"] >= 100:
		d["panic"] = 60
		_damage_district(index, 1, "民众恐慌")


func _monster_tick() -> void:
	var controller := _monster_controller()
	if controller < 0:
		var target := _weighted_monster_target()
		if target >= 0 and target != monster["position"]:
			var moved := _move_entity_toward(monster, _district_center(target), MONSTER_RAMPAGE_MOVE_METERS)
			_log("无人稳定操控，怪兽倾向%s（%s），移动%s后进入%s。" % [
				districts[target]["name"],
				_monster_target_reason(target),
				_meters_text(moved),
				districts[monster["position"]]["name"],
			])
		elif target >= 0:
			_log("无人稳定操控，怪兽停留在%s（%s）。" % [
				districts[monster["position"]]["name"],
				_monster_target_reason(target),
			])
	_damage_district(monster["position"], _preset_int("monster_damage"), "怪兽暴走")
	if districts[monster["position"]]["miasma"]:
		_guardian_take_damage(1, "瘴气", -1)
		districts[monster["position"]]["miasma"] = false


func _guardian_tick() -> void:
	var any_destroyed := _has_destroyed_district()
	var actions: Array = _guardian_actions()
	var weights := _guardian_action_weights(any_destroyed)
	var action_index := _weighted_pick_index(weights)
	if action_index < 0:
		return
	var action: Dictionary = actions[action_index]
	var total := _weight_total(weights)
	_log("%s概率模拟选择：%s（%s）。%s" % [
		guardian["name"],
		action["name"],
		_probability_text(int(weights[action_index]), total),
		action["text"],
	])
	_apply_guardian_support_effects(action)
	_move_guardian_until_in_range(float(action["range"]), float(action.get("move_override", -1.0)), action)
	if districts[guardian["position"]]["miasma"]:
		districts[guardian["position"]]["miasma"] = false
		_guardian_take_damage(1, "瘴气", -1)
	if _entity_distance(guardian, monster) <= float(action["range"]):
		var damage: int = int(action["damage"]) + _preset_int("guardian_damage_bonus")
		_monster_take_damage(damage, action["name"])
	else:
		_log("守护者未能进入射程，攻击落空。")
	_refresh_ui()


func _market_tick() -> void:
	var target := _highest_panic_district()
	if target < 0:
		return
	var d: Dictionary = districts[target]
	var market_bonus: int = _preset_int("market_bonus")
	d["bonus"] += market_bonus
	_log("博彩公司抬高%s奖金，区域奖金+%d。" % [d["name"], market_bonus])


func _apply_guardian_support_effects(action: Dictionary) -> void:
	if int(action.get("repair_radius", 0)) > 0:
		var repaired := 0
		var repair_radius_m := float(action["repair_radius"])
		var repair_amount := int(action.get("repair_amount", 1))
		for i in range(districts.size()):
			if _entity_distance_to_district(guardian, i) <= repair_radius_m:
				repaired += _repair_district(i, repair_amount, action["name"])
		if repaired > 0:
			_guardian_self_heal(1, action["name"])
	elif int(action.get("repair", 0)) > 0:
		var repaired_single: int = _repair_district(guardian["position"], int(action["repair"]), action["name"])
		if repaired_single > 0:
			_guardian_self_heal(1, action["name"])


func _update_realtime_cooldowns(delta: float) -> void:
	for p in players:
		p["control"] = max(0.0, p["control"] - delta * _preset_float("control_decay"))
		p["action_cooldown"] = max(0.0, p["action_cooldown"] - delta)
		for skill in p["slots"]:
			if skill == null:
				continue
			skill["cooldown_left"] = max(0.0, skill["cooldown_left"] - delta)


func _move_guardian_until_in_range(required_range_m: float, move_override_m: float = -1.0, action: Dictionary = {}) -> void:
	var move_budget: float = float(guardian["move"]) + float(_preset_int("guardian_move_bonus"))
	if move_override_m >= 0.0:
		move_budget = move_override_m + float(_preset_int("guardian_move_bonus"))
	var before := _entity_world_position(guardian)
	if _entity_distance(guardian, monster) > required_range_m:
		_move_entity_toward(guardian, _entity_world_position(monster), move_budget)
		if int(action.get("repair_path", 0)) > 0:
			_repair_district(guardian["position"], int(action["repair_path"]), action["name"])
	var moved := before.distance_to(_entity_world_position(guardian))
	if moved > 0.5:
		_log("守护者移动%s至%s。" % [_meters_text(moved), districts[guardian["position"]]["name"]])


func _move_monster_toward_guardian(max_distance_m: float) -> void:
	var before := _entity_world_position(monster)
	if _entity_distance(monster, guardian) > MELEE_RANGE_METERS:
		_move_entity_toward(monster, _entity_world_position(guardian), max_distance_m)
	var moved := before.distance_to(_entity_world_position(monster))
	if moved > 0.5:
		_damage_district(monster["position"], 1, "怪兽冲撞")
		_log("怪兽追近%s至%s。" % [_meters_text(moved), districts[monster["position"]]["name"]])


func _monster_attack_guardian(damage: int, range_limit_m: float, source: String, source_pid: int) -> void:
	if _entity_distance(monster, guardian) > range_limit_m:
		_log("守护者距离%s，不在%s范围%s内。" % [_meters_text(_entity_distance(monster, guardian)), source, _meters_text(range_limit_m)])
		return
	_guardian_take_damage(damage, source, source_pid)


func _guardian_take_damage(damage: int, source: String, source_pid: int) -> void:
	guardian["hp"] -= damage
	if source_pid >= 0:
		var reward := damage * 200
		players[source_pid]["cash"] += reward
		_log("%s对守护者造成%d伤害，%s获得%d筹码。" % [source, damage, players[source_pid]["name"], reward])
	else:
		_log("%s对守护者造成%d伤害。" % [source, damage])
	if guardian["hp"] <= 0:
		_finish_game("%s被击败。" % guardian["name"])


func _monster_take_damage(damage: int, source: String) -> void:
	var reduced: int = max(0, damage - int(monster["armor"]))
	if monster["armor"] > 0:
		_log("怪兽护甲抵消%d点伤害。" % min(damage, monster["armor"]))
	monster["armor"] = max(0, monster["armor"] - damage)
	monster["hp"] -= reduced
	var controller := _monster_controller()
	if controller >= 0 and reduced > 0:
		var loss: int = min(players[controller]["cash"], reduced * 100)
		players[controller]["cash"] -= loss
		_log("%s对怪兽造成%d伤害，%s支付%d筹码损失。" % [source, reduced, players[controller]["name"], loss])
	else:
		_log("%s对怪兽造成%d伤害。" % [source, reduced])
	if monster["hp"] <= 0:
		_finish_game("%s被击败。" % monster["name"])


func _monster_self_heal(amount: int, source: String) -> void:
	if int(monster["hp"]) >= int(monster["max_hp"]):
		return
	var healed: int = min(amount, int(monster["max_hp"]) - int(monster["hp"]))
	monster["hp"] += healed
	if healed > 0:
		_log("%s使%s回复%d HP。" % [source, monster["name"], healed])


func _damage_district(index: int, amount: int, source: String) -> void:
	var d: Dictionary = districts[index]
	if d["destroyed"]:
		return
	d["damage"] += amount
	d["panic"] = min(100, d["panic"] + amount * 8)
	_log("%s使%s受到%d点区域伤害。" % [source, d["name"], amount])
	if d["damage"] >= d["hp"]:
		d["destroyed"] = true
		_log("%s被破坏，塌陷判断立即结算。" % d["name"])
		_settle_district(index, true)


func _add_market_bonus(index: int, amount: int) -> void:
	var d: Dictionary = districts[index]
	if d["destroyed"]:
		_log("已破坏区域不能追加奖金。")
		return
	d["bonus"] += amount
	_log("%s追加%d区域奖金。" % [d["name"], amount])


func _repair_district(index: int, amount: int, source: String) -> int:
	var d: Dictionary = districts[index]
	if d["destroyed"] or int(d["damage"]) <= 0:
		return 0
	var repaired: int = min(amount, int(d["damage"]))
	d["damage"] -= repaired
	d["panic"] = max(0, int(d["panic"]) - repaired * 6)
	_log("%s修复%s %d点区域伤害。" % [source, d["name"], repaired])
	return repaired


func _guardian_self_heal(amount: int, source: String) -> void:
	if int(guardian["hp"]) >= int(guardian["max_hp"]):
		return
	var healed: int = min(amount, int(guardian["max_hp"]) - int(guardian["hp"]))
	guardian["hp"] += healed
	if healed > 0:
		_log("%s使%s回复%d HP。" % [source, guardian["name"], healed])


func _settle_district(index: int, collapsed: bool) -> void:
	var d: Dictionary = districts[index]
	var winning_prediction := "塌陷" if collapsed else "存活"
	var top_amount := -1
	var top_players := []
	for pid in d["bets"].keys():
		var bet: Dictionary = d["bets"][pid]
		if bet["prediction"] == winning_prediction:
			var payout: int = bet["amount"] * 2
			players[pid]["cash"] += payout
			_log("%s猜中%s，获得%d。" % [players[pid]["name"], winning_prediction, payout])
		else:
			_log("%s猜错%s，失去%d下注。" % [players[pid]["name"], winning_prediction, bet["amount"]])
		if bet["amount"] > top_amount:
			top_amount = bet["amount"]
			top_players = [pid]
		elif bet["amount"] == top_amount:
			top_players.append(pid)
	if d["bonus"] > 0 and not top_players.is_empty():
		var share := int(d["bonus"] / top_players.size())
		for pid in top_players:
			players[pid]["cash"] += share
			_log("%s获得%s最高下注奖金%d。" % [players[pid]["name"], d["name"], share])
	d["bets"].clear()
	d["bonus"] = 0


func _manual_settlement() -> void:
	_finish_game("手动触发最终结算。")
	_refresh_ui()


func _finish_game(reason: String) -> void:
	if game_over:
		return
	game_over = true
	_log("游戏结束：%s" % reason)
	for i in range(districts.size()):
		if not districts[i]["destroyed"]:
			_settle_district(i, false)
	var winner: Dictionary = players[0]
	for p in players:
		if p["cash"] > winner["cash"]:
			winner = p
	_log("胜者：%s，筹码%d。" % [winner["name"], winner["cash"]])


func _monster_controller() -> int:
	var best_pid := -1
	var best_control := 0.5
	for p in players:
		if p["control"] > best_control:
			best_pid = p["id"]
			best_control = p["control"]
	return best_pid


func _weighted_monster_target() -> int:
	var weights := []
	var candidates := _monster_target_candidates()
	for entry in candidates:
		weights.append(int(entry["weight"]))
	var picked := _weighted_pick_index(weights)
	if picked < 0:
		return -1
	return int(candidates[picked]["index"])


func _top_monster_target_entries(limit: int) -> Array:
	var pool := _monster_target_candidates()
	var result := []
	while result.size() < limit and not pool.is_empty():
		var best_pos := 0
		var best_weight := int(pool[0]["weight"])
		for i in range(1, pool.size()):
			var weight := int(pool[i]["weight"])
			if weight > best_weight:
				best_weight = weight
				best_pos = i
		result.append(pool[best_pos])
		pool.remove_at(best_pos)
	return result


func _monster_target_debug_summary(limit: int = 3) -> String:
	var total := _monster_target_weight_total()
	if total <= 0:
		return "无可选目标"
	var chunks := []
	for entry in _top_monster_target_entries(limit):
		var index := int(entry["index"])
		var weight := int(entry["weight"])
		chunks.append("%s %s" % [districts[index]["name"], _probability_text(weight, total)])
	return " / ".join(chunks)


func _monster_target_reason(index: int) -> String:
	return "%s，主因：%s" % [
		_monster_target_probability_text(index),
		_monster_target_factor_summary(index),
	]


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
	return _district_center(a).distance_to(_district_center(b))


func _district_center(index: int) -> Vector2:
	if index < 0 or index >= districts.size():
		return Vector2.ZERO
	return districts[index].get("center", Vector2.ZERO)


func _entity_world_position(entity: Dictionary) -> Vector2:
	return entity.get("world_position", _district_center(int(entity.get("position", 0))))


func _set_entity_world_position(entity: Dictionary, world_position: Vector2) -> void:
	entity["world_position"] = world_position
	entity["position"] = _district_at_point(world_position)
	if int(entity["position"]) < 0:
		entity["position"] = _nearest_district_to(world_position)


func _move_entity_toward(entity: Dictionary, target_position: Vector2, max_distance_m: float) -> float:
	var current := _entity_world_position(entity)
	var offset := target_position - current
	var distance := offset.length()
	if distance <= 0.01:
		_set_entity_world_position(entity, target_position)
		return 0.0
	var moved: float = min(distance, max(0.0, max_distance_m))
	var next_position: Vector2 = current + offset.normalized() * moved
	_set_entity_world_position(entity, next_position)
	return moved


func _entity_distance(a: Dictionary, b: Dictionary) -> float:
	return _entity_world_position(a).distance_to(_entity_world_position(b))


func _entity_distance_to_district(entity: Dictionary, district_index: int) -> float:
	return _entity_world_position(entity).distance_to(_district_center(district_index))


func _district_at_point(point: Vector2) -> int:
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
		var dist := center.distance_to(_district_center(i))
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


func _bettor_count(district: Dictionary) -> int:
	return district["bets"].size()


func _total_bets(district: Dictionary) -> int:
	var total := 0
	for pid in district["bets"].keys():
		total += district["bets"][pid]["amount"]
	return total


func _format_bets(district: Dictionary) -> String:
	if district["bets"].is_empty():
		return "暂无"
	var lines := []
	for pid in district["bets"].keys():
		var bet: Dictionary = district["bets"][pid]
		lines.append("%s：%d / %s" % [players[pid]["name"], bet["amount"], bet["prediction"]])
	return "\n".join(lines)


func _collapse_pressure_score(district: Dictionary) -> int:
	if district["destroyed"]:
		return 100
	var damage_score: int = int(float(district["damage"]) / max(1.0, float(district["hp"])) * 55.0)
	var panic_score: int = int(float(district["panic"]) * 0.35)
	var marker_score := 0
	var district_index: int = districts.find(district)
	if district["miasma"]:
		marker_score += 10
	if district_index >= 0 and monster["position"] == district_index:
		marker_score += 15
	if district_index >= 0 and guardian["position"] == district_index:
		marker_score -= 5
	return clamp(damage_score + panic_score + marker_score, 0, 100)


func _collapse_pressure_label(district: Dictionary) -> String:
	var score: int = _collapse_pressure_score(district)
	var tier := "低"
	if score >= 70:
		tier = "极高"
	elif score >= 45:
		tier = "高"
	elif score >= 25:
		tier = "中"
	return "%s %d%%" % [tier, score]


func _selected_prediction_preview(district: Dictionary) -> String:
	if game_over:
		return "游戏已结束，下注关闭。"
	if district["destroyed"]:
		return "当前区域已破坏，不能继续下注。"
	var player: Dictionary = players[selected_player]
	var pid: int = player["id"]
	var placed: int = min(BET_UNIT, int(player["cash"]))
	if placed <= 0:
		return "%s筹码不足，无法下注。" % player["name"]
	if not district["bets"].has(pid) and _bettor_count(district) >= _district_limit():
		return "%s下注席位已满，新玩家无法加入。" % district["name"]
	var current_amount := 0
	if district["bets"].has(pid):
		current_amount = int(district["bets"][pid]["amount"])
	var after_amount: int = current_amount + placed
	var payout: int = after_amount * 2
	var top_after: int = after_amount
	for other_pid in district["bets"].keys():
		if other_pid == pid:
			continue
		top_after = max(top_after, int(district["bets"][other_pid]["amount"]))
	var bonus_hint := "有望争夺最高下注奖金"
	if after_amount < top_after:
		bonus_hint = "暂未超过当前最高下注"
	return "%s按B将向%s追加%d，判断为「%s」；猜中预计返还%d，%s。" % [
		player["name"],
		district["name"],
		placed,
		prediction_mode,
		payout,
		bonus_hint,
	]


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

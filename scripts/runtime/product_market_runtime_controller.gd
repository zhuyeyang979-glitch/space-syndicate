@tool
extends Node
class_name ProductMarketRuntimeController

const CONTROLLER_ID := "product_market_runtime_v1"
const ECONOMY_LEGACY_TURN_SECONDS := 30.0
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
const WEATHER_ECONOMY_MULTIPLIER_MIN := 0.70
const WEATHER_ECONOMY_MULTIPLIER_MAX := 1.30
const PRODUCT_INDUSTRY_CATALOG := preload("res://resources/content/product_industry_catalog_v05.tres")
const WEATHER_PUBLIC_CONTRIBUTION_KEYS := [
	"kind",
	"weather_id",
	"event_id",
	"region_index",
	"phase",
	"intensity",
	"product_id",
	"direction",
	"multiplier",
	"price_growth_multiplier",
	"production_multiplier",
	"demand_multiplier",
	"exposure_weight",
	"reason_codes",
]

@export var terms_catalog: ProductFuturesTermsCatalogResource

const PRODUCT_CATALOG := [
	"星露莓", "磁核榴莲", "月壤葡萄", "量子蜜瓜", "彗尾柑", "脉冲咖啡",
	"真空可可", "离子香料", "孢子丝绸", "环晶电池", "重力陶瓷", "梦境香氛",
	"零点饮料", "活体芯片", "星鲸罐头", "星鳍鱼群", "云母玩具", "光合凝胶", "轨道盆栽",
	"极光盐", "蓝潮藻", "巨藻纤维", "风暴珍珠", "赤道香草", "寒冠冰糖", "太阳鳞片",
	"深海菌毯", "海底黑油", "反物质茶", "虹膜矿粉", "引力棉", "钛壳贝", "夜航香蕉",
	"陨铁酱料", "静电蜂蜜", "星尘面包", "暗礁珊瑚", "离岸水晶", "潮汐电浆", "晨昏奶酪",
	"轨迹墨水", "等离子米", "北极薄荷", "火山番茄", "卫星坚果", "梦游蘑菇",
]


const PRODUCT_PRICE_TIERS := [
	{"label": "基础消费", "weight": 36, "min": 30, "max": 58, "volatility": 4},
	{"label": "成长商品", "weight": 32, "min": 62, "max": 104, "volatility": 7},
	{"label": "奢侈品", "weight": 22, "min": 112, "max": 174, "volatility": 11},
	{"label": "战略稀缺", "weight": 10, "min": 184, "max": 260, "volatility": 16},
]

const PRODUCT_PROFILES := {
	"星露莓": {"category": "鲜果消费", "route": "食品消费线", "terrain": "温带陆地", "use": "稳定低门槛消费，适合早期城市现金流和需求扩张。", "hook": "供需变化温和，适合作为新手理解商品价格的样本。", "flavor": "结着星光露水的小浆果，是殖民城市最常见的甜味来源。", "glyph": "✦", "accent": Color("#f472b6"), "secondary": Color("#fde68a")},
	"磁核榴莲": {"category": "高能鲜果", "route": "高危能源线", "terrain": "磁暴陆地", "use": "高波动食品，可做买涨/做空和怪兽诱导的噪声商品。", "hook": "适合绑定天气、新闻和热度牌，价格上行快但容易被供给压回。", "flavor": "果核像小型磁星，运输舱要贴三层隔离膜。", "glyph": "⬢", "accent": Color("#f59e0b"), "secondary": Color("#7c3aed")},
	"月壤葡萄": {"category": "农业奢侈", "route": "食品消费线", "terrain": "月壤农区", "use": "中低风险城市消费品，适合连接生产区和高需求商业区。", "hook": "适合合约牌添加需求，形成稳定商路而不是爆发套利。", "flavor": "根系吃月尘，果皮会反射淡银色环光。", "glyph": "○", "accent": Color("#a78bfa"), "secondary": Color("#e0f2fe")},
	"量子蜜瓜": {"category": "奢侈鲜果", "route": "奢侈套利线", "terrain": "研究温室", "use": "高价高记忆点商品，适合买涨、包销和会展型城市。", "hook": "需求少时安静，一旦被合约/广告抬起来，GDP弹性很强。", "flavor": "切开前没人知道它甜不甜，商人因此发明了期货瓜。", "glyph": "◇", "accent": Color("#22d3ee"), "secondary": Color("#f0abfc")},
	"彗尾柑": {"category": "高能水果", "route": "高危能源线", "terrain": "火山/高空带", "use": "适合和高速怪兽、天气窗口、能源热潮形成联动。", "hook": "在高热天气和怪兽经济天气下适合做短时间买涨。", "flavor": "剥皮时会拖出一束橙色等离子尾光。", "glyph": "☄", "accent": Color("#fb923c"), "secondary": Color("#fef08a")},
	"脉冲咖啡": {"category": "功能饮料", "route": "食品消费线", "terrain": "城市商业区", "use": "稳定消费需求，可支撑交通/办公城市的现金流。", "hook": "适合消费刺激、短期订单和城市会展类卡牌。", "flavor": "一杯能让外星会计连续算完三座港口的账。", "glyph": "≋", "accent": Color("#92400e"), "secondary": Color("#facc15")},
	"真空可可": {"category": "基础食品", "route": "食品消费线", "terrain": "干燥陆地", "use": "低价、易流通，适合作为合约教学和早期供需连接。", "hook": "不会天然爆炸，但能让城市路线更稳。", "flavor": "在无氧仓里发酵，入口有轻微星尘味。", "glyph": "●", "accent": Color("#78350f"), "secondary": Color("#fbbf24")},
	"离子香料": {"category": "军需香料", "route": "奢侈套利线", "terrain": "干热贸易港", "use": "高需求高波动，适合军需临单、做空和怪兽偏好冲突。", "hook": "需求压力会显著推价，供给扩张也会迅速制造竞争。", "flavor": "洒进锅里会劈啪放电，舰队食堂很爱它。", "glyph": "ϟ", "accent": Color("#e879f9"), "secondary": Color("#f97316")},
	"孢子丝绸": {"category": "生物纺材", "route": "生态材料线", "terrain": "潮湿森林", "use": "偏生产型商品，适合城市工业升级和稳定外运。", "hook": "容易吸引生态怪兽，也适合通过合约补需求。", "flavor": "一卷丝绸里睡着几百万个温顺孢子。", "glyph": "∴", "accent": Color("#86efac"), "secondary": Color("#c084fc")},
	"环晶电池": {"category": "能源科技", "route": "能源科技线", "terrain": "工业/轨道区", "use": "核心能源商品，适合科技城市、固定合约和机械怪兽路线。", "hook": "已绑定专供合约和流星哨兵偏好，是最清楚的商品路线样板。", "flavor": "环形晶体里锁着可反复折叠的微型晨光。", "glyph": "◎", "accent": Color("#38bdf8"), "secondary": Color("#facc15")},
	"重力陶瓷": {"category": "工业建材", "route": "工业建设线", "terrain": "矿带陆地", "use": "建设与装甲商品，适合生产扩张、城市耐久和砂铠陆行兽压力。", "hook": "高生产价值但容易被工业竞争和怪兽冲撞盯上。", "flavor": "杯子放桌上会把桌子往杯子里拽。", "glyph": "▣", "accent": Color("#94a3b8"), "secondary": Color("#f97316")},
	"梦境香氛": {"category": "奢侈体验", "route": "奢侈套利线", "terrain": "商业/疗养区", "use": "高利润消费品，适合角色现金流、会展和需求扩张。", "hook": "需求一旦成型，价格与城市GDP都很漂亮，但容易被情报推理锁定。", "flavor": "闻到它的人会梦见自己已经盈利。", "glyph": "☁", "accent": Color("#f0abfc"), "secondary": Color("#60a5fa")},
	"零点饮料": {"category": "功能饮料", "route": "食品消费线", "terrain": "夜间城市", "use": "中价消费品，可支撑稳定需求和短线订单。", "hook": "适合作为低冲突城市的现金流底盘。", "flavor": "永远保持零度，连账本亏损都能冷静下来。", "glyph": "◌", "accent": Color("#67e8f9"), "secondary": Color("#dbeafe")},
	"活体芯片": {"category": "生物科技", "route": "情报科技线", "terrain": "研究院/数据塔", "use": "情报、追踪、怪兽夺取的关键门槛商品。", "hook": "出牌条件会暴露强烈线索，是匿名推理局的核心商品之一。", "flavor": "芯片会自己读合同，并偶尔提出反对意见。", "glyph": "▥", "accent": Color("#4ade80"), "secondary": Color("#38bdf8")},
	"星鲸罐头": {"category": "海洋食品", "route": "海洋物流线", "terrain": "远洋港口", "use": "海洋运输型食品，适合港口城市和航线合约。", "hook": "在海洋路线受损时会变成断路价格信号。", "flavor": "每罐都声称没有伤害真正的星鲸，没人完全相信。", "glyph": "◒", "accent": Color("#0ea5e9"), "secondary": Color("#f8fafc")},
	"星鳍鱼群": {"category": "海洋渔获", "route": "海洋物流线", "terrain": "外海渔场", "use": "鱼类供给商品，适合海洋区域生产、食品需求和港口运输。", "hook": "海洋被怪兽或天气破坏时，鱼群供给会成为清晰的价格线索。", "flavor": "鱼鳍像小卫星一样闪光，整群迁徙时能照亮夜海。", "glyph": "魚", "accent": Color("#38bdf8"), "secondary": Color("#e0f2fe")},
	"云母玩具": {"category": "轻工业消费", "route": "食品消费线", "terrain": "城市娱乐区", "use": "低中价消费品，适合需求扩张和广告路线。", "hook": "竞争多时利润薄，但适合做城市热度诱饵。", "flavor": "儿童会拿它拼出自己的第一艘逃税飞船。", "glyph": "□", "accent": Color("#f9a8d4"), "secondary": Color("#93c5fd")},
	"光合凝胶": {"category": "修复材料", "route": "修复避难线", "terrain": "避难/医疗区", "use": "防御、修复、灾后保险路线的核心商品。", "hook": "已绑定应急修复，适合领先者保护高GDP城市。", "flavor": "涂在墙上会自己晒太阳，顺便补洞。", "glyph": "✚", "accent": Color("#22c55e"), "secondary": Color("#bef264")},
	"轨道盆栽": {"category": "生态消费", "route": "修复避难线", "terrain": "轨道居住区", "use": "补给范围和城市舒适度商品，适合远程采购路线。", "hook": "可作为低风险补给型角色/卡牌门槛。", "flavor": "盆栽会按轨道周期开花，花粉有点会计味。", "glyph": "♧", "accent": Color("#65a30d"), "secondary": Color("#86efac")},
	"极光盐": {"category": "晶体调味", "route": "精密晶体线", "terrain": "极地/晶体带", "use": "中高价晶体商品，适合专利、天气和精密制造路线。", "hook": "容易被蓝锋骑士类科技怪兽偏好放大。", "flavor": "撒一点，汤面会出现极光。", "glyph": "✧", "accent": Color("#67e8f9"), "secondary": Color("#a78bfa")},
	"蓝潮藻": {"category": "海洋生物", "route": "海洋物流线", "terrain": "浅海/洋流", "use": "海洋基础供给，适合运输、养殖和低价大流量商路。", "hook": "海洋天气和交通升级会显著提高它的流通价值。", "flavor": "潮水退去时会在礁石上写蓝色广告。", "glyph": "≈", "accent": Color("#06b6d4"), "secondary": Color("#22c55e")},
	"巨藻纤维": {"category": "海洋纤维", "route": "海洋物流线", "terrain": "巨藻森林", "use": "海带/巨藻类材料，连接海洋生产、生态工业和修复商品。", "hook": "适合做低价大流量供给，也能被合约升级成工业需求。", "flavor": "一根巨藻能从海底长到低轨道电梯广告牌。", "glyph": "〰", "accent": Color("#10b981"), "secondary": Color("#67e8f9")},
	"风暴珍珠": {"category": "海洋奢侈", "route": "奢侈套利线", "terrain": "风暴海域", "use": "高价海洋奢侈品，适合天气预报、买涨和商路保护。", "hook": "风暴/断路会让价格信号非常明显，适合高风险玩家。", "flavor": "每颗珍珠都存着一次台风的回声。", "glyph": "◉", "accent": Color("#7dd3fc"), "secondary": Color("#fef3c7")},
	"赤道香草": {"category": "热带香料", "route": "奢侈套利线", "terrain": "赤道陆地", "use": "消费需求强，适合合约和需求扩张。", "hook": "热带城市争夺它时，会天然形成竞争目标。", "flavor": "香味会绕星球赤道跑一圈才散。", "glyph": "∿", "accent": Color("#bef264"), "secondary": Color("#f59e0b")},
	"寒冠冰糖": {"category": "极地甜品", "route": "食品消费线", "terrain": "寒冠极地", "use": "稳定消费品，适合低波动需求和极地城市特色。", "hook": "适合作为防御型城市的温和收入来源。", "flavor": "含在嘴里会短暂听见雪落在别的星球。", "glyph": "❄", "accent": Color("#bae6fd"), "secondary": Color("#ffffff")},
	"太阳鳞片": {"category": "高能材料", "route": "高危能源线", "terrain": "太阳能带", "use": "爆发型高能商品，适合怪兽热潮和GDP买涨窗口。", "hook": "价格增速被放大时很可怕，但断路/做空也会很痛。", "flavor": "摸起来像一片很有意见的太阳。", "glyph": "☀", "accent": Color("#facc15"), "secondary": Color("#ef4444")},
	"深海菌毯": {"category": "海洋生态", "route": "海洋物流线", "terrain": "深海海盆", "use": "水域生态商品，适合孢雾海皇、黑市药材和海洋城市。", "hook": "怪兽偏好强，赚钱的同时也更容易把战场拉过来。", "flavor": "像地毯一样铺在海底，踩上去会问你要不要投资。", "glyph": "▩", "accent": Color("#14b8a6"), "secondary": Color("#a855f7")},
	"海底黑油": {"category": "海底能源", "route": "高危能源线", "terrain": "深海油脊", "use": "海底石油型高收益能源，适合做空、污染新闻和高风险运输。", "hook": "被破坏时会同时影响能源价格、海路安全和城市GDP。", "flavor": "黑得像董事会的会议纪要，燃起来却很诚实。", "glyph": "油", "accent": Color("#111827"), "secondary": Color("#f97316")},
	"反物质茶": {"category": "高危饮品", "route": "高危能源线", "terrain": "实验茶馆", "use": "高波动投机商品，适合金融传闻、市场稳定和做空。", "hook": "利润感强，但应给玩家明显风险提示。", "flavor": "泡茶前要先确认茶杯和宇宙没有互相抵消。", "glyph": "☕", "accent": Color("#c084fc"), "secondary": Color("#f43f5e")},
	"虹膜矿粉": {"category": "精密矿物", "route": "工业建设线", "terrain": "矿山/研究区", "use": "工业和光学材料，适合生产扩张、专利和怪兽矿物偏好。", "hook": "砂铠陆行兽路线会让它更像战场诱饵。", "flavor": "粉末会凝视价格曲线，仿佛早就知道。", "glyph": "◈", "accent": Color("#c084fc"), "secondary": Color("#38bdf8")},
	"引力棉": {"category": "工业纺材", "route": "工业建设线", "terrain": "低重力农场", "use": "轻工业/运输包装商品，适合交通型城市。", "hook": "运输速度越高越能体现价值。", "flavor": "一团棉花能把货箱轻轻往目的地推。", "glyph": "☁", "accent": Color("#e5e7eb"), "secondary": Color("#60a5fa")},
	"钛壳贝": {"category": "海陆矿壳", "route": "工业建设线", "terrain": "礁岸/矿带", "use": "装甲建材商品，适合城市防御和工业GDP。", "hook": "高生产价值会吸引冲撞型怪兽。", "flavor": "贝壳硬到需要请律师开壳。", "glyph": "◖", "accent": Color("#64748b"), "secondary": Color("#38bdf8")},
	"夜航香蕉": {"category": "远洋水果", "route": "海洋物流线", "terrain": "夜航港口", "use": "低中价物流商品，适合港口消费和运输教学。", "hook": "玩家容易记住，适合做 UI 目录里的轻松商品。", "flavor": "成熟时会指向最近的走私航线。", "glyph": "☾", "accent": Color("#fde047"), "secondary": Color("#312e81")},
	"陨铁酱料": {"category": "工业调味", "route": "工业建设线", "terrain": "陨坑工厂", "use": "介于食品和矿物之间，适合军需/工业混合城市。", "hook": "能把生产竞争和消费需求挂在同一商品上。", "flavor": "淋在饭上会让餐盘获得轻微护甲。", "glyph": "▰", "accent": Color("#b45309"), "secondary": Color("#94a3b8")},
	"静电蜂蜜": {"category": "能量食品", "route": "食品消费线", "terrain": "雷暴农场", "use": "军需食品，适合能量怪兽和消费型城市。", "hook": "需求压力高时价格弹性不错。", "flavor": "倒出来会噼啪作响，甜到让雷达失灵。", "glyph": "⚡", "accent": Color("#facc15"), "secondary": Color("#f472b6")},
	"星尘面包": {"category": "基础食品", "route": "食品消费线", "terrain": "普通城市", "use": "最低理解成本的城市消费品，适合教学和低价大流量。", "hook": "竞争多、利润薄，但很适合合约扩需求。", "flavor": "每片面包都撒着一点合法星尘。", "glyph": "▭", "accent": Color("#fbbf24"), "secondary": Color("#fed7aa")},
	"暗礁珊瑚": {"category": "海洋建材", "route": "海洋物流线", "terrain": "暗礁海域", "use": "海洋生产和运输商品，适合商路断损/修复博弈。", "hook": "海洋区域被破坏时，它会成为可读的经济线索。", "flavor": "会在走私船底悄悄长出发票。", "glyph": "♒", "accent": Color("#f472b6"), "secondary": Color("#06b6d4")},
	"离岸水晶": {"category": "航线晶体", "route": "海洋物流线", "terrain": "离岸平台", "use": "天气、航线、全局采购和远程补给的关键商品。", "hook": "已绑定航线预报和星门采购权，是物流策略核心。", "flavor": "水晶会折射出还没到来的航线。", "glyph": "◇", "accent": Color("#38bdf8"), "secondary": Color("#f0abfc")},
	"潮汐电浆": {"category": "海浪能源", "route": "海洋物流线", "terrain": "潮汐发电阵列", "use": "海浪供电商品，适合交通速度、航线预报和能源城市买涨。", "hook": "天气预报和海洋交通水平会直接影响它的策略价值。", "flavor": "每一次浪涌都被压缩成一枚蓝白色电浆币。", "glyph": "≈⚡", "accent": Color("#0ea5e9"), "secondary": Color("#facc15")},
	"晨昏奶酪": {"category": "极地食品", "route": "食品消费线", "terrain": "晨昏牧场", "use": "中价稳定消费品，可接精密/晶体路线需求。", "hook": "适合成为城市需求端而非强投机端。", "flavor": "早晨吃像黎明，晚上吃像加班。", "glyph": "◐", "accent": Color("#fef08a"), "secondary": Color("#fb7185")},
	"轨迹墨水": {"category": "情报材料", "route": "情报科技线", "terrain": "数据塔/海关", "use": "匿名推理、合约回溯、天气干涉和竞争封锁的关键门槛。", "hook": "打出它会暴露强线索，是信息战路线核心。", "flavor": "写下去的字会标出作者刚刚去过哪里。", "glyph": "⌁", "accent": Color("#1d4ed8"), "secondary": Color("#a855f7")},
	"等离子米": {"category": "能量主粮", "route": "食品消费线", "terrain": "能源农场", "use": "军需和大众消费之间的桥梁商品。", "hook": "适合棱刃重甲/镜像猎兵相关能量食品偏好。", "flavor": "煮熟后米粒会悬浮三厘米，方便偷吃。", "glyph": "⋯", "accent": Color("#fb7185"), "secondary": Color("#facc15")},
	"北极薄荷": {"category": "修复药材", "route": "修复避难线", "terrain": "极地温室", "use": "避难、医疗、冷却城市的辅助商品。", "hook": "适合和光合凝胶组成防御经济线。", "flavor": "闻一下，过热的怪兽也会短暂怀疑人生。", "glyph": "✚", "accent": Color("#2dd4bf"), "secondary": Color("#d9f99d")},
	"火山番茄": {"category": "高热食品", "route": "高危能源线", "terrain": "火山陆地", "use": "高热高波动消费品，适合爆发怪兽和买涨窗口。", "hook": "被破坏或天气影响时 GDP 变化很戏剧化。", "flavor": "切开会冒岩浆味番茄汁。", "glyph": "◆", "accent": Color("#ef4444"), "secondary": Color("#f97316")},
	"卫星坚果": {"category": "轨道零食", "route": "食品消费线", "terrain": "轨道仓储", "use": "轻量消费和运输商品，适合补给型城市。", "hook": "中性商品，适合作为随机地图里的缓冲经济。", "flavor": "坚果壳会绕包装袋公转。", "glyph": "◍", "accent": Color("#a16207"), "secondary": Color("#facc15")},
	"梦游蘑菇": {"category": "生态奢侈", "route": "生态材料线", "terrain": "夜间菌林", "use": "高记忆点生态商品，适合奢侈消费和怪兽资源诱导。", "hook": "需求扩大后适合配合新闻/会展，但也会引怪。", "flavor": "它会自己走去价格最高的市场。", "glyph": "☽", "accent": Color("#c084fc"), "secondary": Color("#86efac")},
}


var product_market: Dictionary = {}
var business_cycle_count := 0
var market_timer := 8.0
var futures_position_sequence := 0

var _configured := false
var _ruleset_id := ""
var _world_bridge: ProductMarketRuntimeWorldBridge
var _formula_service: CardEconomyProductRouteFormulaRuntimeService
var _route_network_runtime_controller: RouteNetworkRuntimeController
var _weather_runtime_controller: WeatherRuntimeController
var _weather_telemetry_runtime_service: Node
var _futures_open_count := 0
var _futures_settlement_count := 0
var _legacy_positions_normalized := 0
var _last_futures_receipt: Dictionary = {}


func configure(ruleset_snapshot: Dictionary, formula_service: Node = null) -> void:
	_ruleset_id = str(ruleset_snapshot.get("ruleset_id", ""))
	_formula_service = formula_service as CardEconomyProductRouteFormulaRuntimeService
	var catalog_report := terms_catalog.validation_report() if terms_catalog != null else {"valid": false, "issues": ["catalog_missing"]}
	_configured = _ruleset_id == "v0.4" and _formula_service != null and bool(catalog_report.get("valid", false))
	if not _configured:
		push_error("Product futures v0.4 terms catalog is required and must contain twelve valid cards: %s" % str(catalog_report.get("issues", [])))


func set_world_bridge(bridge: ProductMarketRuntimeWorldBridge) -> void:
	_world_bridge = bridge


func set_route_network_runtime_controller(controller: RouteNetworkRuntimeController) -> void:
	_route_network_runtime_controller = controller


func set_weather_runtime_controller(controller: WeatherRuntimeController) -> void:
	_weather_runtime_controller = controller


func set_weather_telemetry_runtime_service(service: Node) -> void:
	_weather_telemetry_runtime_service = service


func reset_state() -> Dictionary:
	product_market = generate_product_market()
	business_cycle_count = 0
	market_timer = _world_bridge.next_market_interval() if _world_bridge != null else 8.0
	futures_position_sequence = 0
	_futures_open_count = 0
	_futures_settlement_count = 0
	_legacy_positions_normalized = 0
	_last_futures_receipt = {}
	return runtime_state_snapshot()


func terms_for_card_id(card_id: String) -> Dictionary:
	return terms_catalog.terms_for_card_id(card_id) if terms_catalog != null else {}


func all_futures_terms() -> Array:
	return terms_catalog.all_terms() if terms_catalog != null else []


func skill_with_terms(card_id: String, skill: Dictionary) -> Dictionary:
	if terms_catalog == null:
		push_error("Product futures terms catalog is unavailable: %s" % card_id)
		var failed := skill.duplicate(true)
		failed["futures_terms_error"] = "catalog_missing"
		return failed
	return terms_catalog.enrich_skill(card_id, skill)


func futures_terms(skill: Dictionary) -> Dictionary:
	var supplied: Dictionary = skill.get("futures_terms", {}) if skill.get("futures_terms", {}) is Dictionary else {}
	var card_id := str(skill.get("name", supplied.get("card_id", "")))
	if card_id.is_empty():
		return {}
	return terms_for_card_id(card_id)


func ensure_catalog() -> void:
	if product_market.is_empty():
		product_market = generate_product_market()
		return
	var generated := {}
	for product_variant in PRODUCT_CATALOG:
		var product_name := str(product_variant)
		if product_market.has(product_name):
			var existing_entry: Dictionary = product_market.get(product_name, {})
			if not existing_entry.has("price_history"):
				existing_entry["price_history"] = [int(existing_entry.get("price", existing_entry.get("base_price", 50)))]
			_normalize_boon_fields(existing_entry)
			product_market[product_name] = existing_entry
			continue
		if generated.is_empty():
			generated = generate_product_market()
		var entry: Dictionary = generated.get(product_name, {})
		product_market[product_name] = entry.duplicate(true)


func generate_product_market() -> Dictionary:
	var result := {}
	var weights := []
	for tier_variant in PRODUCT_PRICE_TIERS:
		var tier: Dictionary = tier_variant
		weights.append(int(tier.get("weight", 1)))
	for product_variant in PRODUCT_CATALOG:
		var product_name := str(product_variant)
		var tier_index := _weighted_pick_index(weights)
		tier_index = clampi(tier_index, 0, PRODUCT_PRICE_TIERS.size() - 1)
		var tier: Dictionary = PRODUCT_PRICE_TIERS[tier_index]
		var shared_rng := _shared_rng()
		var base_price := shared_rng.randi_range(int(tier.get("min", 30)), int(tier.get("max", 60))) if shared_rng != null else int(tier.get("min", 30))
		result[product_name] = {
			"tier": str(tier.get("label", "基础消费")),
			"base_price": base_price, "price": base_price, "trend": 0,
			"volatility": int(tier.get("volatility", 4)), "supply": 0, "demand": 0, "disrupted": 0,
			"price_history": [base_price],
			"base_growth_multiplier": 1.0, "growth_multiplier": 1.0, "growth_seconds": 0.0, "growth_turns": 0,
			"growth_source": "", "base_growth_source": "",
			"base_route_flow_multiplier": 1.0, "route_flow_multiplier": 1.0, "route_flow_seconds": 0.0, "route_flow_turns": 0,
			"route_flow_source": "", "base_route_flow_source": "",
			"market_contract_demand": 0, "market_contract_supply": 0, "market_contract_seconds": 0.0,
			"market_contract_turns": 0, "market_contract_source": "", "futures_positions": [],
		}
	return result


func refresh_prices() -> Dictionary:
	ensure_catalog()
	var world := _world_snapshot()
	var districts: Array = world.get("districts", []) as Array
	var supply := {}
	var demand := {}
	var disrupted := {}
	var weather_market_context := {}
	for product_variant in PRODUCT_CATALOG:
		var product_name := str(product_variant)
		supply[product_name] = 0
		demand[product_name] = 0
		disrupted[product_name] = 0
		weather_market_context[product_name] = {
			"total_exposure_weight": 0,
			"weighted_price_delta": 0.0,
			"contributions": [],
		}
	for district_index in range(districts.size()):
		var district_variant: Variant = districts[district_index]
		if not (district_variant is Dictionary):
			continue
		var district: Dictionary = district_variant
		if bool(district.get("destroyed", false)):
			continue
		for product_variant in district.get("products", []):
			var product_name := str(product_variant)
			supply[product_name] = int(supply.get(product_name, 0)) + 1
		for demand_variant in district.get("demands", []):
			var demand_name := str(demand_variant)
			demand[demand_name] = int(demand.get(demand_name, 0)) + 1
		var city: Dictionary = district.get("city", {}) as Dictionary
		if _city_is_active(city):
			for city_product_variant in city.get("products", []):
				if not (city_product_variant is Dictionary):
					continue
				var city_product_name := str((city_product_variant as Dictionary).get("name", ""))
				supply[city_product_name] = int(supply.get(city_product_name, 0)) + 2
			for city_demand_variant in city.get("demands", []):
				var city_demand_name := str(city_demand_variant)
				demand[city_demand_name] = int(demand.get(city_demand_name, 0)) + 3
			for route_variant in city.get("trade_routes", []):
				if route_variant is Dictionary and bool((route_variant as Dictionary).get("disrupted", false)):
					var disrupted_product := str((route_variant as Dictionary).get("product", ""))
					disrupted[disrupted_product] = int(disrupted.get(disrupted_product, 0)) + 1
		var district_exposure := _district_product_exposure(district)
		for exposed_product_variant in district_exposure.keys():
			var exposed_product := str(exposed_product_variant)
			if not weather_market_context.has(exposed_product):
				continue
			var exposure_weight := maxi(0, int(district_exposure.get(exposed_product_variant, 0)))
			var aggregate: Dictionary = weather_market_context[exposed_product]
			aggregate["total_exposure_weight"] = int(aggregate.get("total_exposure_weight", 0)) + exposure_weight
			_append_product_weather_contributions(aggregate, district_index, exposed_product, exposure_weight, district)
			weather_market_context[exposed_product] = aggregate
	var shared_rng := _shared_rng()
	for product_variant in PRODUCT_CATALOG:
		var product_name := str(product_variant)
		var entry: Dictionary = product_market.get(product_name, {})
		_normalize_boon_fields(entry)
		var base_price := int(entry.get("base_price", 50))
		var volatility := int(entry.get("volatility", 4))
		var temporary_demand := int(entry.get("temporary_demand_pressure", 0))
		var temporary_supply := int(entry.get("temporary_supply_pressure", 0))
		var contract_seconds := _remaining_seconds(entry, "market_contract_seconds", "market_contract_turns")
		var demand_score := int(demand.get(product_name, 0)) + temporary_demand + (int(entry.get("market_contract_demand", 0)) if contract_seconds > 0.0 else 0)
		var supply_score := int(supply.get(product_name, 0)) + temporary_supply + (int(entry.get("market_contract_supply", 0)) if contract_seconds > 0.0 else 0)
		var disrupted_score := int(disrupted.get(product_name, 0))
		var growth_multiplier := clampf(float(entry.get("growth_multiplier", 1.0)), 1.0, PRODUCT_GROWTH_MULTIPLIER_MAX)
		var weather_context: Dictionary = weather_market_context.get(product_name, {})
		var total_exposure_weight := maxi(0, int(weather_context.get("total_exposure_weight", 0)))
		var weighted_price_delta := float(weather_context.get("weighted_price_delta", 0.0))
		var weather_price_growth_multiplier := 1.0
		if total_exposure_weight > 0:
			weather_price_growth_multiplier = clampf(
				1.0 + weighted_price_delta / float(total_exposure_weight),
				WEATHER_ECONOMY_MULTIPLIER_MIN,
				WEATHER_ECONOMY_MULTIPLIER_MAX
			)
		var weather_modifier := int(round(float(base_price) * (weather_price_growth_multiplier - 1.0)))
		var noise := shared_rng.randf_range(-float(volatility), float(volatility)) if shared_rng != null else 0.0
		var price_model := _world_bridge.price_model(base_price, supply_score, demand_score, disrupted_score, volatility, noise, growth_multiplier, weather_modifier) if _world_bridge != null else {}
		var trend := int(price_model.get("delta", 0))
		var price := int(price_model.get("price", clampi(base_price + trend, PRODUCT_PRICE_MIN, PRODUCT_PRICE_MAX)))
		entry["price"] = price
		entry["trend"] = trend
		entry["raw_trend"] = int(price_model.get("raw_delta", trend))
		entry["price_step_cap"] = int(price_model.get("step_cap", _world_bridge.price_step_cap(volatility, base_price) if _world_bridge != null else volatility))
		entry["driver_summary"] = str(price_model.get("driver_summary", ""))
		entry["supply"] = supply_score
		entry["demand"] = demand_score
		entry["disrupted"] = disrupted_score
		entry["weather_price_growth_multiplier"] = weather_price_growth_multiplier
		entry["weather_modifier"] = weather_modifier
		entry["weather_contributions"] = _sanitize_weather_contributions(weather_context.get("contributions", []))
		entry["weather_driver_summary"] = _weather_driver_summary(entry["weather_contributions"] as Array, weather_price_growth_multiplier)
		_record_weather_price_telemetry(entry["weather_contributions"] as Array)
		if temporary_demand > 0: entry["temporary_demand_pressure"] = maxi(0, temporary_demand - 1)
		if temporary_supply > 0: entry["temporary_supply_pressure"] = maxi(0, temporary_supply - 1)
		_append_price_history(entry, price)
		product_market[product_name] = entry
	return runtime_state_snapshot()


func product_price(product_name: String) -> int:
	if product_name.is_empty(): return 0
	ensure_catalog()
	var entry: Dictionary = product_market.get(product_name, {})
	return int(entry.get("price", entry.get("base_price", 50)))


func product_tier(product_name: String) -> String:
	if product_market.is_empty() or not product_market.has(product_name): return "未定价"
	return str((product_market.get(product_name, {}) as Dictionary).get("tier", "未定价"))


func market_entry(product_name: String, include_private := true) -> Dictionary:
	ensure_catalog()
	var entry: Dictionary = (product_market.get(product_name, {}) as Dictionary).duplicate(true)
	if entry.is_empty(): return {}
	_normalize_boon_fields(entry)
	product_market[product_name] = entry.duplicate(true)
	return entry if include_private else _sanitize_entry(entry)


func apply_product_market_boon(product_name: String, growth_multiplier: float, route_flow_multiplier: float, turns: int, source: String, persistent := false, duration_seconds := -1.0) -> bool:
	if product_name.is_empty() or not PRODUCT_CATALOG.has(product_name): return false
	var entry := market_entry(product_name)
	var result := _formula("product_market_boon", {"entry": entry, "growth_multiplier": growth_multiplier, "route_flow_multiplier": route_flow_multiplier, "turns": turns, "source": source, "persistent": persistent, "duration_seconds": duration_seconds})
	if not bool(result.get("ok", false)): return false
	product_market[product_name] = (result.get("entry", entry) as Dictionary).duplicate(true)
	return bool(result.get("changed", false))


func product_route_flow_multiplier(product_name: String) -> float:
	var entry := market_entry(product_name)
	if entry.is_empty(): return 1.0
	var result := _formula("route_flow_multiplier", {"city_multiplier": 1.0, "product_multiplier": float(entry.get("route_flow_multiplier", 1.0))})
	return float(result.get("value", 1.0))


func futures_public_counts(product_name: String) -> Dictionary:
	var futures: Array = market_entry(product_name).get("futures_positions", []) as Array
	var result := {"count": 0, "up": 0, "down": 0, "warehouse": 0, "units": 0, "warehouse_units": 0, "soonest_seconds": -1.0}
	var game_time := float(_world_snapshot().get("game_time", 0.0))
	for futures_variant in futures:
		if not (futures_variant is Dictionary): continue
		var futures_position: Dictionary = futures_variant
		result["count"] = int(result["count"]) + 1
		var direction := str(futures_position.get("direction", "up"))
		result[direction if direction == "down" else "up"] = int(result[direction if direction == "down" else "up"]) + 1
		var units := maxi(1, int(futures_position.get("units", 1)))
		result["units"] = int(result["units"]) + units
		if int(futures_position.get("warehouse_district", -1)) >= 0:
			result["warehouse"] = int(result["warehouse"]) + 1
			result["warehouse_units"] = int(result["warehouse_units"]) + units
		var seconds_left := maxf(0.0, float(futures_position.get("expires_at", game_time)) - game_time)
		if float(result["soonest_seconds"]) < 0.0 or seconds_left < float(result["soonest_seconds"]): result["soonest_seconds"] = seconds_left
	return result


func futures_public_text(product_name: String, compact := false) -> String:
	var counts := futures_public_counts(product_name)
	if int(counts.get("count", 0)) <= 0: return ""
	var up_count := int(counts.get("up", 0)); var down_count := int(counts.get("down", 0)); var warehouse_count := int(counts.get("warehouse", 0))
	var duration := _duration_short_text(maxf(1.0, float(counts.get("soonest_seconds", 1.0))))
	if compact:
		var compact_parts := []
		if up_count > 0: compact_parts.append("涨%d" % up_count)
		if down_count > 0: compact_parts.append("跌%d" % down_count)
		if warehouse_count > 0: compact_parts.append("仓%d" % warehouse_count)
		return "匿名期货%s/%s" % ["".join(compact_parts), duration]
	var directions := []
	if up_count > 0: directions.append("看涨%d笔" % up_count)
	if down_count > 0: directions.append("看跌%d笔" % down_count)
	var warehouse_text := "，其中仓储%d笔/%d单位" % [warehouse_count, int(counts.get("warehouse_units", 0))] if warehouse_count > 0 else ""
	return "匿名期货%s%s，最近%s后到期" % ["、".join(directions), warehouse_text, duration]


func age_economic_boons(delta_seconds: float) -> void:
	var safe_delta := maxf(0.0, delta_seconds)
	if safe_delta <= 0.0: return
	var changed := false
	for product_variant in product_market.keys():
		var product_name := str(product_variant)
		var entry := market_entry(product_name)
		if _age_seconds(entry, "growth_seconds", "growth_turns", safe_delta):
			entry["growth_multiplier"] = float(entry.get("base_growth_multiplier", 1.0)); entry["growth_source"] = str(entry.get("base_growth_source", "")); changed = true
		if _age_seconds(entry, "route_flow_seconds", "route_flow_turns", safe_delta):
			entry["route_flow_multiplier"] = float(entry.get("base_route_flow_multiplier", 1.0)); entry["route_flow_source"] = str(entry.get("base_route_flow_source", "")); changed = true
		if _age_seconds(entry, "market_contract_seconds", "market_contract_turns", safe_delta):
			entry["market_contract_demand"] = 0; entry["market_contract_supply"] = 0; entry["market_contract_source"] = ""; changed = true
		product_market[product_name] = entry
	if _world_bridge != null:
		var world_changed := bool(_world_bridge.call_world("_age_product_market_world_boons", [safe_delta]))
		if changed and not world_changed and _route_network_runtime_controller != null:
			_route_network_runtime_controller.refresh_routes()


func apply_speculation(player_index: int, skill: Dictionary) -> bool:
	var product_name := _default_product()
	var source := str(skill.get("name", "商品牌"))
	if product_name.is_empty(): _log("%s没有可操盘商品。" % source); return false
	var before_price := product_price(product_name)
	var price_delta := int(skill.get("price_delta", 0))
	var pressure := int(_formula("product_speculation_pressure", {"price_delta": price_delta}).get("pressure", 1))
	apply_external_pressure(product_name, pressure if price_delta >= 0 else 0, pressure if price_delta < 0 else 0, 0, false)
	_set_selected_product(product_name)
	var cash_gain := int(skill.get("cash", 0))
	if cash_gain > 0: _world_bridge.commit_player_cash_delta(player_index, cash_gain, source, product_name, "card_income", cash_gain)
	var selected_district := int(_world_snapshot().get("selected_district", -1))
	if int(skill.get("panic", 0)) > 0 and selected_district >= 0: _world_bridge.call_world("_add_panic", [selected_district, int(skill.get("panic", 0)), source])
	refresh_prices()
	_log("匿名卡牌围绕%s完成%s：制造%d点%s压力，市场按供需重算¥%d→¥%d；收益归属不公开（¥%d）。" % [product_name, "拉升" if price_delta >= 0 else "做空", pressure, "需求" if price_delta >= 0 else "供给", before_price, product_price(product_name), cash_gain])
	return true


func futures_duration_seconds(skill: Dictionary) -> float:
	var terms := futures_terms(skill)
	return float(_formula("product_futures_duration", {"skill": {"futures_terms": terms}}).get("seconds", 0.0)) if not terms.is_empty() else 0.0


func apply_futures(player_index: int, skill: Dictionary) -> bool:
	return bool(open_futures_position(player_index, skill).get("committed", false))


func open_futures_position(player_index: int, skill: Dictionary) -> Dictionary:
	var source := str(skill.get("name", "商品期货")); var product_name := _default_product()
	var terms := futures_terms(skill)
	if terms.is_empty() or str(terms.get("card_id", "")) != source:
		return _futures_receipt(false, "terms_missing", source, product_name)
	if product_name.is_empty() or not PRODUCT_CATALOG.has(product_name):
		_log("%s没有可建仓商品。" % source)
		return _futures_receipt(false, "product_missing", source, product_name)
	var world := _world_snapshot(); var selected_district := int(world.get("selected_district", -1)); var warehouse_district := -1
	if bool(terms.get("requires_warehouse", false)):
		var city := _district_city(world, selected_district)
		if not _city_is_active(city):
			_log("%s需要选中一座己方存活城市作为仓库。" % source)
			return _futures_receipt(false, "warehouse_city_missing", source, product_name)
		if int(city.get("owner", -1)) != player_index:
			_log("%s只能把囤货放进己方城市仓库；仓库真实业主仍不公开。" % source)
			return _futures_receipt(false, "warehouse_owner_mismatch", source, product_name)
		warehouse_district = selected_district
	var entry := market_entry(product_name); var before_price := product_price(product_name); var direction := str(terms.get("direction", ""))
	if entry.is_empty() or not ["up", "down"].has(direction):
		return _futures_receipt(false, "position_terms_invalid", source, product_name)
	var units := maxi(1, int(terms.get("units", 1))); var duration_seconds := float(terms.get("duration_seconds", 0.0)); var game_time := float(world.get("game_time", 0.0))
	var action_fee_cash := maxi(0, int(terms.get("action_fee_cash", 0))); var margin_cash := maxi(0, int(terms.get("margin_cash", 0)))
	# The Queue owns the action-fee commit. Effect open rechecks and locks margin only.
	var cash_required := margin_cash
	var cash_before := _world_bridge.player_cash(player_index) if _world_bridge != null else -1
	if cash_before < cash_required:
		return _futures_receipt(false, "financial_margin_insufficient", source, product_name, {"cash_before": cash_before, "cash_required": cash_required})
	futures_position_sequence += 1
	var position := {
		"position_id": futures_position_sequence,
		"owner": player_index,
		"source": source,
		"card_id": source,
		"product_id": product_name,
		"direction": direction,
		"baseline_price": before_price,
		"opened_at": game_time,
		"expires_at": game_time + duration_seconds,
		"duration_seconds": duration_seconds,
		"multiplier": maxf(0.1, float(terms.get("multiplier", 1.0))),
		"units": units,
		"warehouse_district": warehouse_district,
		"action_fee_cash": action_fee_cash,
		"locked_margin": margin_cash,
		"maximum_gain": maxi(0, int(terms.get("maximum_gain", 0))),
		"maximum_loss": mini(margin_cash, maxi(0, int(terms.get("maximum_loss", 0)))),
		"terms_version": str(terms.get("terms_version", "v0.4")),
		"settlement_formula_id": str(terms.get("settlement_formula_id", "product_futures_v04_settlement")),
		"warehouse_loss_formula_id": str(terms.get("warehouse_loss_formula_id", "warehouse_futures_v04_loss")),
		"settled": false,
	}
	var cash_receipt := _world_bridge.commit_player_cash_delta(player_index, -cash_required, source, product_name, "futures_open", 0) if _world_bridge != null else {"committed": false, "reason": "world_bridge_missing"}
	if not bool(cash_receipt.get("committed", false)):
		futures_position_sequence -= 1
		return _futures_receipt(false, str(cash_receipt.get("reason", "cash_commit_failed")), source, product_name)
	if warehouse_district >= 0: _world_bridge.call_world("_append_product_futures_warehouse_clue", [warehouse_district, source, direction, product_name, units, duration_seconds])
	var futures: Array = entry.get("futures_positions", []) as Array
	futures.append(position)
	entry["futures_positions"] = futures
	entry["temporary_demand_pressure"] = int(entry.get("temporary_demand_pressure", 0)) + maxi(0, int(skill.get("market_demand_pressure", 0)))
	entry["temporary_supply_pressure"] = int(entry.get("temporary_supply_pressure", 0)) + maxi(0, int(skill.get("market_supply_pressure", 0)))
	product_market[product_name] = entry; _set_selected_product(product_name); _world_bridge.call_world("_refresh_warehouse_stockpile_city_markers"); refresh_prices()
	_world_bridge.call_world("_present_product_futures_opened", [source, product_name, direction, before_price, duration_seconds, warehouse_district])
	_futures_open_count += 1
	return _futures_receipt(true, "", source, product_name, {"position_id": futures_position_sequence, "cash_delta": -cash_required, "locked_margin": margin_cash, "cash_before": cash_before, "cash_after": int(cash_receipt.get("cash_after", cash_before - cash_required))})


func update_futures_timers() -> void:
	if product_market.is_empty(): return
	var game_time := float(_world_snapshot().get("game_time", 0.0))
	for product_variant in PRODUCT_CATALOG:
		var product_name := str(product_variant); var entry := market_entry(product_name); var futures: Array = entry.get("futures_positions", []) as Array
		if futures.is_empty(): continue
		var remaining := []; var current_price := product_price(product_name)
		for futures_variant in futures:
			if not (futures_variant is Dictionary): continue
			var position: Dictionary = futures_variant
			if game_time < float(position.get("expires_at", game_time)): remaining.append(position); continue
			var receipt := settle_futures_position(product_name, current_price, position, "expiry")
			if not bool(receipt.get("committed", false)): remaining.append(position)
		entry["futures_positions"] = remaining; product_market[product_name] = entry
	_world_bridge.call_world("_refresh_warehouse_stockpile_city_markers")


func settle_futures_position(product_name: String, current_price: int, position: Dictionary, reason := "expiry") -> Dictionary:
	if bool(position.get("settled", false)):
		return _futures_receipt(false, "position_already_settled", str(position.get("source", "商品期货")), product_name)
	var formula_id := str(position.get("settlement_formula_id", "product_futures_v04_settlement"))
	var settlement := _formula(formula_id, {"current_price": current_price, "position": position})
	if not bool(settlement.get("ok", false)):
		return _futures_receipt(false, str(settlement.get("reason", "settlement_formula_failed")), str(position.get("source", "商品期货")), product_name)
	return _commit_futures_settlement(product_name, position, settlement, reason)


func settle_futures_for_destroyed_warehouse(district_index: int, source: String, damage_receipt: Dictionary) -> Dictionary:
	if district_index < 0:
		return {"committed": false, "reason": "district_invalid", "settled_count": 0}
	var settled_count := 0
	var total_loss := 0
	for product_variant in product_market.keys():
		var product_name := str(product_variant); var entry := market_entry(product_name); var futures: Array = entry.get("futures_positions", []) as Array; var remaining := []
		for futures_variant in futures:
			if not (futures_variant is Dictionary): continue
			var position := futures_variant as Dictionary
			if int(position.get("warehouse_district", -1)) != district_index:
				remaining.append(position)
				continue
			var formula_id := str(position.get("warehouse_loss_formula_id", "warehouse_futures_v04_loss"))
			var settlement := _formula(formula_id, {"position": position, "damage_receipt": damage_receipt})
			var receipt := _commit_futures_settlement(product_name, position, settlement, "warehouse_destroyed") if bool(settlement.get("ok", false)) else {"committed": false}
			if bool(receipt.get("committed", false)):
				settled_count += 1
				total_loss += int(receipt.get("loss", 0))
			else:
				remaining.append(position)
		if remaining.size() != futures.size(): entry["futures_positions"] = remaining; product_market[product_name] = entry
	if settled_count > 0:
		_world_bridge.call_world("_refresh_warehouse_stockpile_city_markers")
		_log("%s摧毁仓库区：%d笔商品囤积按剩余生命条款结算，合计损失¥%d；资金归属不公开。" % [source, settled_count, total_loss])
	return {"committed": settled_count > 0, "reason": "" if settled_count > 0 else "no_warehouse_positions", "settled_count": settled_count, "total_loss": total_loss, "damage_receipt": damage_receipt.duplicate(true)}


func _commit_futures_settlement(product_name: String, position: Dictionary, settlement: Dictionary, reason: String) -> Dictionary:
	var source := str(position.get("source", "商品期货"))
	var player_index := int(position.get("owner", -1))
	var cash_return := maxi(0, int(settlement.get("cash_return", 0)))
	var gain := maxi(0, int(settlement.get("gain", 0)))
	var cash_receipt := _world_bridge.commit_player_cash_delta(player_index, cash_return, source, product_name, "futures_%s" % reason, gain) if _world_bridge != null else {"committed": false, "reason": "world_bridge_missing"}
	if not bool(cash_receipt.get("committed", false)):
		return _futures_receipt(false, str(cash_receipt.get("reason", "cash_commit_failed")), source, product_name)
	position["settled"] = true
	_futures_settlement_count += 1
	var receipt := _futures_receipt(true, "", source, product_name, {
		"position_id": int(position.get("position_id", -1)),
		"settlement_reason": reason,
		"gain": gain,
		"loss": maxi(0, int(settlement.get("loss", 0))),
		"margin_refund": maxi(0, int(settlement.get("margin_refund", 0))),
		"cash_return": cash_return,
		"net_pnl": int(settlement.get("net_pnl", 0)),
		"cash_after": int(cash_receipt.get("cash_after", 0)),
	})
	_log("匿名商品期货结算：%s %s，收益¥%d、损失¥%d、保证金返还¥%d；资金归属不公开。" % [product_name, "仓库毁灭" if reason == "warehouse_destroyed" else "到期", int(receipt.get("gain", 0)), int(receipt.get("loss", 0)), int(receipt.get("margin_refund", 0))])
	return receipt


func _futures_receipt(committed: bool, reason: String, source: String, product_name: String, details: Dictionary = {}) -> Dictionary:
	var receipt := {
		"committed": committed,
		"reason": reason,
		"card_id": source,
		"product_id": product_name,
	}
	receipt.merge(details.duplicate(true), true)
	_last_futures_receipt = receipt.duplicate(true)
	return receipt


func apply_market_stabilize(skill: Dictionary) -> bool:
	var source := str(skill.get("name", "市场稳定")); var product_name := _default_product()
	if product_name.is_empty(): _log("%s没有可稳定的商品。" % source); return false
	var entry := market_entry(product_name); var before_volatility := int(entry.get("volatility", 4)); var before_price := product_price(product_name)
	var before_demand := int(entry.get("temporary_demand_pressure", 0)); var before_supply := int(entry.get("temporary_supply_pressure", 0))
	entry["temporary_demand_pressure"] = maxi(0, before_demand - maxi(1, int(float(int(skill.get("stabilize_amount", 0))) / 12.0)))
	entry["temporary_supply_pressure"] = maxi(0, before_supply - maxi(1, int(float(int(skill.get("stabilize_amount", 0))) / 12.0)))
	var after_volatility := clampi(before_volatility + int(skill.get("volatility_delta", 0)), PRODUCT_VOLATILITY_MIN, PRODUCT_VOLATILITY_MAX)
	if after_volatility == before_volatility and int(entry["temporary_demand_pressure"]) == before_demand and int(entry["temporary_supply_pressure"]) == before_supply: _log("%s没有产生有效变化：%s已经处于稳定区间。" % [source, product_name]); return false
	entry["volatility"] = after_volatility; product_market[product_name] = entry; _set_selected_product(product_name); refresh_prices()
	_log("%s稳定%s：削减临时供需压力，市场按供需重算¥%d→¥%d，波动%d→%d。" % [source, product_name, before_price, product_price(product_name), before_volatility, after_volatility])
	return true


func apply_product_growth_boon(skill: Dictionary) -> bool:
	var source := str(skill.get("name", "商品催化")); var product_name := _default_product()
	if product_name.is_empty(): _log("%s没有可催化的商品。" % source); return false
	var growth_seconds := _skill_duration(skill, "growth_seconds", "growth_turns", 0)
	var route_seconds := _skill_duration(skill, "route_flow_seconds", "route_flow_turns", int(ceil(growth_seconds / ECONOMY_LEGACY_TURN_SECONDS)))
	var duration_seconds := maxf(ECONOMY_LEGACY_TURN_SECONDS, maxf(growth_seconds, route_seconds))
	var changed := apply_product_market_boon(product_name, float(skill.get("growth_multiplier", 1.0)), float(skill.get("route_flow_multiplier", 1.0)), int(ceil(duration_seconds / ECONOMY_LEGACY_TURN_SECONDS)), source, false, duration_seconds)
	if not changed: _log("%s没有超过%s当前已有的经济天气。" % [source, product_name]); return false
	_set_selected_product(product_name); refresh_prices(); _world_bridge.call_world("_present_product_growth_boon", [source, product_name])
	return true


func apply_product_contract_boon(player_index: int, skill: Dictionary) -> bool:
	var source := str(skill.get("name", "商品合约")); var product_name := _default_product()
	if product_name.is_empty(): _log("%s没有可签约商品。" % source); return false
	var entry := market_entry(product_name); var before_price := product_price(product_name); var before_volatility := int(entry.get("volatility", 4))
	var contract_seconds := _skill_duration(skill, "market_contract_seconds", "market_contract_turns", int(skill.get("growth_turns", 1)))
	var result := _formula("product_contract_boon", {"entry": entry, "demand_pressure": maxi(0, int(skill.get("market_demand_pressure", 0))), "supply_pressure": maxi(0, int(skill.get("market_supply_pressure", 0))), "contract_seconds": contract_seconds, "volatility_delta": int(skill.get("volatility_delta", 0)), "source": source})
	if not bool(result.get("ok", false)): _log("%s商品合约公式不可用。" % source); return false
	entry = result.get("entry", {}) as Dictionary; product_market[product_name] = entry; var changed := bool(result.get("changed", false))
	var flow_seconds := maxf(contract_seconds, _skill_duration(skill, "route_flow_seconds", "route_flow_turns", int(ceil(contract_seconds / ECONOMY_LEGACY_TURN_SECONDS))))
	if float(skill.get("route_flow_multiplier", 1.0)) > 1.001 or float(skill.get("growth_multiplier", 1.0)) > 1.001:
		changed = apply_product_market_boon(product_name, float(skill.get("growth_multiplier", 1.0)), float(skill.get("route_flow_multiplier", 1.0)), int(ceil(flow_seconds / ECONOMY_LEGACY_TURN_SECONDS)), source, false, flow_seconds) or changed
	var cash_gain := int(skill.get("cash", 0))
	if cash_gain > 0: _world_bridge.commit_player_cash_delta(player_index, cash_gain, source, product_name, "card_income", cash_gain); changed = true
	if not changed: _log("%s没有超过%s当前已有的商品合约。" % [source, product_name]); return false
	_set_selected_product(product_name); refresh_prices(); _world_bridge.call_world("_present_product_contract_boon", [source, product_name, before_price, product_price(product_name), before_volatility, int(market_entry(product_name).get("volatility", before_volatility)), cash_gain])
	return true


func apply_external_pressure(product_name: String, demand_delta: int, supply_delta: int, volatility_delta := 0, refresh := true) -> Dictionary:
	var entry := market_entry(product_name)
	if entry.is_empty(): return {"changed": false, "reason": "product_missing"}
	entry["temporary_demand_pressure"] = int(entry.get("temporary_demand_pressure", 0)) + maxi(0, demand_delta)
	entry["temporary_supply_pressure"] = int(entry.get("temporary_supply_pressure", 0)) + maxi(0, supply_delta)
	entry["volatility"] = clampi(int(entry.get("volatility", 4)) + volatility_delta, PRODUCT_VOLATILITY_MIN, PRODUCT_VOLATILITY_MAX)
	product_market[product_name] = entry
	if refresh: refresh_prices()
	return {"changed": true, "product_name": product_name, "price": product_price(product_name)}


func tick_market_cycle(delta: float) -> Dictionary:
	market_timer -= maxf(0.0, delta)
	if market_timer > 0.0: return {"ticked": false, "seconds_left": market_timer}
	market_tick()
	market_timer = _world_bridge.next_market_interval() if _world_bridge != null else 8.0
	return {"ticked": true, "business_cycle_count": business_cycle_count, "seconds_left": market_timer}


func market_tick() -> void:
	business_cycle_count += 1
	if _route_network_runtime_controller != null:
		_route_network_runtime_controller.refresh_routes()
	refresh_prices()
	_world_bridge.call_world("_on_product_market_cycle_completed", [business_cycle_count])


func to_save_data() -> Dictionary:
	return {"product_market": _product_market_save_snapshot(), "business_cycle_count": business_cycle_count, "market_timer": market_timer, "futures_position_sequence": futures_position_sequence}


func apply_save_data(data: Dictionary) -> Dictionary:
	product_market = (data.get("product_market", {}) as Dictionary).duplicate(true) if data.get("product_market", {}) is Dictionary else {}
	_clear_weather_projection(product_market)
	business_cycle_count = int(data.get("business_cycle_count", 0))
	market_timer = float(data.get("market_timer", 8.0))
	futures_position_sequence = maxi(0, int(data.get("futures_position_sequence", 0)))
	ensure_catalog()
	_normalize_loaded_futures_positions()
	return runtime_state_snapshot()


func runtime_state_snapshot() -> Dictionary:
	return {"product_market": product_market.duplicate(true), "business_cycle_count": business_cycle_count, "market_timer": market_timer, "futures_position_sequence": futures_position_sequence}


func public_market_snapshot() -> Dictionary:
	var public_market := {}
	for product_variant in product_market.keys(): public_market[product_variant] = _sanitize_entry(product_market[product_variant] as Dictionary)
	return {"product_market": public_market, "business_cycle_count": business_cycle_count, "market_timer": market_timer}


func product_weather_contribution_snapshot(product_name: String) -> Dictionary:
	var entry := market_entry(product_name, false)
	return {
		"available": not entry.is_empty(),
		"product_id": product_name,
		"price_growth_multiplier": clampf(float(entry.get("weather_price_growth_multiplier", 1.0)), WEATHER_ECONOMY_MULTIPLIER_MIN, WEATHER_ECONOMY_MULTIPLIER_MAX),
		"weather_modifier": int(entry.get("weather_modifier", 0)),
		"driver_summary": str(entry.get("weather_driver_summary", "无天气因素")),
		"contributions": _sanitize_weather_contributions(entry.get("weather_contributions", [])),
	}


func debug_snapshot(_viewer_index := -1) -> Dictionary:
	var last_receipt := _last_futures_receipt.duplicate(true)
	last_receipt.erase("player_index")
	return {"controller_id": CONTROLLER_ID, "ruleset_id": _ruleset_id, "controller_ready": _configured, "controller_authoritative": _configured, "product_count": product_market.size(), "business_cycle_count": business_cycle_count, "market_timer": market_timer, "futures_position_sequence": futures_position_sequence, "futures_open_count": _futures_open_count, "futures_settlement_count": _futures_settlement_count, "legacy_positions_normalized": _legacy_positions_normalized, "last_futures_receipt": last_receipt, "terms_catalog": terms_catalog.validation_report() if terms_catalog != null else {"valid": false}, "owns_product_market_state": true, "owns_product_market_rules": true, "owns_futures_cash_terms": true, "owns_weather_state": false, "weather_runtime_ready": _weather_runtime_controller != null, "owns_shared_rng": false, "formula_owner": "CardEconomyProductRouteFormulaRuntimeService", "world_bridge_ready": _world_bridge != null and _world_bridge.has_world()}


func _normalize_loaded_futures_positions() -> void:
	for product_variant in product_market.keys():
		var product_name := str(product_variant)
		var entry := market_entry(product_name)
		var normalized: Array = []
		for position_variant in entry.get("futures_positions", []):
			if not (position_variant is Dictionary):
				continue
			var position := (position_variant as Dictionary).duplicate(true)
			var card_id := str(position.get("card_id", position.get("source", "")))
			var terms := terms_for_card_id(card_id)
			if terms.is_empty():
				push_error("Cannot normalize product futures position without authored terms: %s" % card_id)
				continue
			if not position.has("terms_version"):
				position["terms_version"] = str(terms.get("terms_version", "v0.4"))
				position["locked_margin"] = 0
				position["maximum_loss"] = 0
				position["maximum_gain"] = maxi(0, int(terms.get("maximum_gain", 0)))
				_legacy_positions_normalized += 1
			position["card_id"] = card_id
			position["product_id"] = str(position.get("product_id", product_name))
			position["duration_seconds"] = float(position.get("duration_seconds", terms.get("duration_seconds", 0.0)))
			position["settlement_formula_id"] = str(position.get("settlement_formula_id", terms.get("settlement_formula_id", "product_futures_v04_settlement")))
			position["warehouse_loss_formula_id"] = str(position.get("warehouse_loss_formula_id", terms.get("warehouse_loss_formula_id", "warehouse_futures_v04_loss")))
			position["settled"] = false
			if int(position.get("position_id", 0)) <= 0:
				futures_position_sequence += 1
				position["position_id"] = futures_position_sequence
			else:
				futures_position_sequence = maxi(futures_position_sequence, int(position.get("position_id", 0)))
			normalized.append(position)
		entry["futures_positions"] = normalized
		product_market[product_name] = entry


func _normalize_boon_fields(entry: Dictionary) -> void:
	if not entry.has("base_growth_multiplier"): entry["base_growth_multiplier"] = 1.0
	if not entry.has("growth_multiplier"): entry["growth_multiplier"] = float(entry.get("base_growth_multiplier", 1.0))
	if not entry.has("growth_turns"): entry["growth_turns"] = 0
	if not entry.has("growth_seconds"): entry["growth_seconds"] = _legacy_turns_to_seconds(int(entry.get("growth_turns", 0)))
	else: _set_seconds(entry, "growth_seconds", "growth_turns", float(entry.get("growth_seconds", 0.0)))
	if not entry.has("growth_source"): entry["growth_source"] = ""
	if not entry.has("base_growth_source"): entry["base_growth_source"] = ""
	if not entry.has("base_route_flow_multiplier"): entry["base_route_flow_multiplier"] = 1.0
	if not entry.has("route_flow_multiplier"): entry["route_flow_multiplier"] = float(entry.get("base_route_flow_multiplier", 1.0))
	if not entry.has("route_flow_turns"): entry["route_flow_turns"] = 0
	if not entry.has("route_flow_seconds"): entry["route_flow_seconds"] = _legacy_turns_to_seconds(int(entry.get("route_flow_turns", 0)))
	else: _set_seconds(entry, "route_flow_seconds", "route_flow_turns", float(entry.get("route_flow_seconds", 0.0)))
	if not entry.has("route_flow_source"): entry["route_flow_source"] = ""
	if not entry.has("base_route_flow_source"): entry["base_route_flow_source"] = ""
	if not entry.has("market_contract_demand"): entry["market_contract_demand"] = 0
	if not entry.has("market_contract_supply"): entry["market_contract_supply"] = 0
	if not entry.has("market_contract_turns"): entry["market_contract_turns"] = 0
	if not entry.has("market_contract_seconds"): entry["market_contract_seconds"] = _legacy_turns_to_seconds(int(entry.get("market_contract_turns", 0)))
	else: _set_seconds(entry, "market_contract_seconds", "market_contract_turns", float(entry.get("market_contract_seconds", 0.0)))
	if not entry.has("market_contract_source"): entry["market_contract_source"] = ""
	if not entry.has("futures_positions"): entry["futures_positions"] = []
	if not entry.has("weather_price_growth_multiplier"): entry["weather_price_growth_multiplier"] = 1.0
	if not entry.has("weather_modifier"): entry["weather_modifier"] = 0
	if not entry.has("weather_contributions"): entry["weather_contributions"] = []
	if not entry.has("weather_driver_summary"): entry["weather_driver_summary"] = "无天气因素"


func _product_market_save_snapshot() -> Dictionary:
	var snapshot := product_market.duplicate(true)
	_clear_weather_projection(snapshot)
	return snapshot


func _clear_weather_projection(market: Dictionary) -> void:
	for product_variant in market.keys():
		var entry_variant: Variant = market.get(product_variant, {})
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		entry.erase("weather_price_growth_multiplier")
		entry.erase("weather_modifier")
		entry.erase("weather_contributions")
		entry.erase("weather_driver_summary")
		market[product_variant] = entry


func _append_price_history(entry: Dictionary, price: int) -> void:
	var history: Array = entry.get("price_history", []) as Array
	if history.is_empty() or int(history[-1]) != price: history.append(price)
	while history.size() > PRODUCT_HISTORY_LIMIT: history.pop_front()
	entry["price_history"] = history


func _weighted_pick_index(weights: Array) -> int:
	var total := 0
	for value in weights: total += maxi(0, int(value))
	if total <= 0: return -1
	var shared_rng := _shared_rng(); var ticket := shared_rng.randi_range(1, total) if shared_rng != null else 1; var running := 0
	for index in range(weights.size()):
		running += maxi(0, int(weights[index]))
		if ticket <= running: return index
	return weights.size() - 1


func _formula(formula_id: String, input_snapshot: Dictionary) -> Dictionary:
	return _formula_service.calculate(formula_id, input_snapshot) if _formula_service != null else {"ok": false, "reason": "formula_service_missing"}


func _world_snapshot() -> Dictionary:
	return _world_bridge.world_snapshot() if _world_bridge != null else {}


func _shared_rng() -> RandomNumberGenerator:
	return _world_bridge.shared_rng() if _world_bridge != null else null


func _default_product() -> String:
	var value: Variant = _world_bridge.call_world("_default_economy_product") if _world_bridge != null else ""
	return str(value)


func _set_selected_product(product_name: String) -> void:
	if _world_bridge != null: _world_bridge.write_world_value("selected_trade_product", product_name)


func _log(message: String) -> void:
	if _world_bridge != null: _world_bridge.call_world("_log", [message])


func _district_city(world: Dictionary, district_index: int) -> Dictionary:
	var districts: Array = world.get("districts", []) as Array
	if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary): return {}
	return ((districts[district_index] as Dictionary).get("city", {}) as Dictionary).duplicate(true)


func _city_is_active(city: Dictionary) -> bool:
	return not city.is_empty() and bool(city.get("active", true))


func _legacy_turns_to_seconds(turns: int) -> float:
	return float(maxi(0, turns)) * ECONOMY_LEGACY_TURN_SECONDS


func _skill_duration(skill: Dictionary, seconds_key: String, turns_key: String, default_turns := 0) -> float:
	return maxf(0.0, float(skill.get(seconds_key, 0.0))) if skill.has(seconds_key) else _legacy_turns_to_seconds(maxi(0, int(skill.get(turns_key, default_turns))))


func _remaining_seconds(source: Dictionary, seconds_key: String, turns_key: String) -> float:
	return maxf(0.0, float(source.get(seconds_key, 0.0))) if source.has(seconds_key) else _legacy_turns_to_seconds(maxi(0, int(source.get(turns_key, 0))))


func _set_seconds(source: Dictionary, seconds_key: String, turns_key: String, seconds: float) -> void:
	var safe := maxf(0.0, seconds); source[seconds_key] = safe; source[turns_key] = int(ceil(safe / ECONOMY_LEGACY_TURN_SECONDS)) if safe > 0.0 else 0


func _age_seconds(source: Dictionary, seconds_key: String, turns_key: String, delta: float) -> bool:
	var before := _remaining_seconds(source, seconds_key, turns_key); var after := maxf(0.0, before - maxf(0.0, delta)); _set_seconds(source, seconds_key, turns_key, after); return before > 0.0 and after <= 0.0


func _duration_short_text(seconds: float) -> String:
	var total := maxi(1, int(round(seconds)))
	if total < 60: return "%d秒" % total
	var minutes := int(float(total) / 60.0); var rest := total % 60
	return "%d分钟" % minutes if rest == 0 else "%d分%d秒" % [minutes, rest]


func _district_product_exposure(district: Dictionary) -> Dictionary:
	var exposure: Dictionary = {}
	for product_variant in district.get("products", []):
		_add_weather_exposure(exposure, str(product_variant), 1)
	for demand_variant in district.get("demands", []):
		_add_weather_exposure(exposure, str(demand_variant), 1)
	var city: Dictionary = district.get("city", {}) as Dictionary
	if _city_is_active(city):
		for city_product_variant in city.get("products", []):
			if city_product_variant is Dictionary:
				_add_weather_exposure(exposure, str((city_product_variant as Dictionary).get("name", "")), 2)
		for city_demand_variant in city.get("demands", []):
			_add_weather_exposure(exposure, str(city_demand_variant), 3)
	return exposure


func _add_weather_exposure(exposure: Dictionary, product_id: String, weight: int) -> void:
	if product_id.is_empty() or weight <= 0:
		return
	exposure[product_id] = int(exposure.get(product_id, 0)) + weight


func _append_product_weather_contributions(aggregate: Dictionary, region_index: int, product_id: String, exposure_weight: int, district: Dictionary) -> void:
	if _weather_runtime_controller == null or exposure_weight <= 0 or PRODUCT_INDUSTRY_CATALOG == null:
		return
	var product_tags: Array = PRODUCT_INDUSTRY_CATALOG.tags_for_product(product_id)
	if product_tags.is_empty():
		return
	var city: Dictionary = district.get("city", {}) as Dictionary
	var resistance := clampf(maxf(float(district.get("weather_resistance", 0.0)), float(city.get("weather_resistance", 0.0))), 0.0, 1.0)
	var exploitation := maxf(1.0, maxf(float(district.get("weather_exploitation_multiplier", 1.0)), float(city.get("weather_exploitation_multiplier", 1.0))))
	var snapshot := _weather_runtime_controller.region_effect_snapshot(region_index, {
		"product_tags": product_tags,
		"weather_resistance": resistance,
		"weather_exploitation_multiplier": exploitation,
	})
	for effect_variant in snapshot.get("effects", []):
		if not (effect_variant is Dictionary):
			continue
		var effect: Dictionary = effect_variant
		var economy: Dictionary = effect.get("economy", {}) as Dictionary
		var price_multiplier := clampf(float(economy.get("price_growth_multiplier", 1.0)), WEATHER_ECONOMY_MULTIPLIER_MIN, WEATHER_ECONOMY_MULTIPLIER_MAX)
		var production_multiplier := clampf(float(economy.get("production_multiplier", 1.0)), WEATHER_ECONOMY_MULTIPLIER_MIN, WEATHER_ECONOMY_MULTIPLIER_MAX)
		var demand_multiplier := clampf(float(economy.get("demand_multiplier", 1.0)), WEATHER_ECONOMY_MULTIPLIER_MIN, WEATHER_ECONOMY_MULTIPLIER_MAX)
		if is_equal_approx(price_multiplier, 1.0):
			continue
		aggregate["weighted_price_delta"] = float(aggregate.get("weighted_price_delta", 0.0)) + (price_multiplier - 1.0) * float(exposure_weight)
		var rows: Array = aggregate.get("contributions", []) as Array
		rows.append({
			"kind": "weather_economy",
			"weather_id": str(effect.get("definition_id", "")),
			"event_id": int(effect.get("event_id", 0)),
			"region_index": region_index,
			"phase": str(effect.get("phase", "")),
			"intensity": clampf(float(effect.get("intensity", 0.0)), 0.0, 1.0),
			"product_id": product_id,
			"direction": "price",
			"multiplier": price_multiplier,
			"price_growth_multiplier": price_multiplier,
			"production_multiplier": production_multiplier,
			"demand_multiplier": demand_multiplier,
			"exposure_weight": exposure_weight,
			"reason_codes": _string_array(effect.get("explanations", [])),
		})
		aggregate["contributions"] = rows


func _weather_driver_summary(rows: Array, weather_multiplier: float) -> String:
	if rows.is_empty() or is_equal_approx(weather_multiplier, 1.0):
		return "无天气因素"
	var region_ids: Dictionary = {}
	for row_variant in rows:
		if row_variant is Dictionary:
			region_ids[int((row_variant as Dictionary).get("region_index", -1))] = true
	return "天气价格增速%+d%%（%d区）" % [int(round((weather_multiplier - 1.0) * 100.0)), region_ids.size()]


func _record_weather_price_telemetry(rows: Array) -> void:
	if _weather_telemetry_runtime_service == null or not _weather_telemetry_runtime_service.has_method("observe_public_metric"):
		return
	var event_samples: Dictionary = {}
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var event_id := int(row.get("event_id", 0))
		if event_id <= 0:
			continue
		var multiplier := float(row.get("price_growth_multiplier", row.get("multiplier", 1.0)))
		var samples: Array = event_samples.get(event_id, []) if event_samples.get(event_id, []) is Array else []
		samples.append((multiplier - 1.0) * 100.0)
		event_samples[event_id] = samples
	for event_id_variant in event_samples.keys():
		var samples := event_samples[event_id_variant] as Array
		var total := 0.0
		for sample in samples:
			total += float(sample)
		_weather_telemetry_runtime_service.call("observe_public_metric", int(event_id_variant), "product_price_delta_percent", total / float(samples.size()))


func _sanitize_weather_contributions(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for row_variant in value:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		var clean: Dictionary = {}
		for key_variant in WEATHER_PUBLIC_CONTRIBUTION_KEYS:
			var key := str(key_variant)
			if row.has(key):
				clean[key] = row[key] if key != "reason_codes" else _string_array(row[key])
		result.append(clean)
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array or value is PackedStringArray:
		for item_variant in value:
			var item := str(item_variant).strip_edges()
			if not item.is_empty() and not result.has(item):
				result.append(item)
	return result


func _sanitize_entry(entry: Dictionary) -> Dictionary:
	var sanitized := entry.duplicate(true)
	var public_futures := []
	for position_variant in sanitized.get("futures_positions", []):
		if not (position_variant is Dictionary): continue
		var position: Dictionary = (position_variant as Dictionary).duplicate(true)
		position.erase("owner")
		position.erase("position_id")
		position.erase("locked_margin")
		position.erase("action_fee_cash")
		public_futures.append(position)
	sanitized["futures_positions"] = public_futures
	sanitized["weather_contributions"] = _sanitize_weather_contributions(sanitized.get("weather_contributions", []))
	return sanitized

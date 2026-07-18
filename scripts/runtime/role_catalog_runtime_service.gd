@tool
extends Node
class_name RoleCatalogRuntimeService

const LEGACY_CATALOG_AUDIT_SHA256 := "7609b20741bec0e835e7768f2301f587c1848180a49aad8ca7c767e6c8d1cbe0"
const EXPECTED_ROLE_COUNT := 24
const REQUIRED_PUBLIC_FIELDS := [
	"name",
	"species",
	"trait",
	"passive",
	"flavor",
]
const PUBLIC_FIELDS := [
	"name",
	"species",
	"trait",
	"passive",
	"flavor",
	"starting_cash_bonus",
	"bonus_card_product",
	"resource_cash_product",
	"resource_cash_amount",
	"monster_upgrade_cash",
	"intel_city_reveal_charges",
	"intel_card_trace_charges",
	"intel_contract_trace_charges",
	"city_guess_reward_bonus",
	"card_owner_guess_discount",
	"card_owner_guess_bonus",
	"contract_flow_discount",
	"monster_control_limit_bonus",
	"military_control_limit_bonus",
	"monster_cards_as_counter",
]

const _CATALOG := [
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


func role_count() -> int:
	return _CATALOG.size()


func ordered_role_names() -> Array[String]:
	var result: Array[String] = []
	for definition_variant in _CATALOG:
		var definition := definition_variant as Dictionary
		result.append(str(definition.get("name", "")))
	return result


func definition_at(index: int) -> Dictionary:
	if index < 0 or index >= _CATALOG.size():
		return {}
	return (_CATALOG[index] as Dictionary).duplicate(true)


func definition_by_name(role_name: String) -> Dictionary:
	var index := index_by_name(role_name)
	return definition_at(index) if index >= 0 else {}


func index_by_name(role_name: String) -> int:
	var normalized := role_name.strip_edges()
	if normalized == "":
		return -1
	for index in range(_CATALOG.size()):
		if str((_CATALOG[index] as Dictionary).get("name", "")) == normalized:
			return index
	return -1


func public_definition_at(index: int) -> Dictionary:
	var source := definition_at(index)
	if source.is_empty():
		return {}
	var result: Dictionary = {}
	for field_name in PUBLIC_FIELDS:
		if source.has(field_name):
			result[field_name] = _duplicate_variant(source[field_name])
	return result


func validate_catalog() -> Dictionary:
	var duplicate_names: Array[String] = []
	var missing_required_fields: Array[String] = []
	var unexpected_fields: Array[String] = []
	var seen_names := {}
	for index in range(_CATALOG.size()):
		var definition := _CATALOG[index] as Dictionary
		var role_name := str(definition.get("name", ""))
		if role_name == "":
			missing_required_fields.append("%02d:name" % index)
		elif seen_names.has(role_name):
			duplicate_names.append(role_name)
		seen_names[role_name] = true
		for field_name in REQUIRED_PUBLIC_FIELDS:
			if str(definition.get(field_name, "")).strip_edges() == "":
				missing_required_fields.append("%02d:%s" % [index, field_name])
		for key_variant in definition.keys():
			var key := str(key_variant)
			if not PUBLIC_FIELDS.has(key):
				unexpected_fields.append("%02d:%s" % [index, key])
	return {
		"valid": _CATALOG.size() == EXPECTED_ROLE_COUNT 			and duplicate_names.is_empty() 			and missing_required_fields.is_empty() 			and unexpected_fields.is_empty(),
		"role_count": _CATALOG.size(),
		"duplicate_names": duplicate_names,
		"missing_required_fields": missing_required_fields,
		"unexpected_fields": unexpected_fields,
		"ordered_role_names": ordered_role_names(),
		"legacy_catalog_audit_sha256": LEGACY_CATALOG_AUDIT_SHA256,
		"catalog_sha256": catalog_sha256(),
		"read_only_owner": true,
		"save_identity": "legacy_role_index_and_chinese_name",
	}


func catalog_sha256() -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(_CATALOG).to_utf8_buffer())
	return context.finish().hex_encode()


func debug_snapshot() -> Dictionary:
	var validation := validate_catalog()
	return {
		"runtime_owner": "RoleCatalogRuntimeService",
		"role_count": int(validation.get("role_count", 0)),
		"valid": bool(validation.get("valid", false)),
		"duplicate_count": (validation.get("duplicate_names", []) as Array).size(),
		"read_only_owner": true,
		"references_main": false,
		"autoload": false,
		"save_schema_owner": false,
	}


func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value

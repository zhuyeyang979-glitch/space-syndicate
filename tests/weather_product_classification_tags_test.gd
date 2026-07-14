extends SceneTree

const CATALOG_PATH := "res://resources/content/product_industry_catalog_v05.tres"
const WEATHER_TAG_IDS: Array[String] = [
	"weather_energy",
	"weather_electronic",
	"weather_biological",
	"weather_medicine",
	"weather_food",
	"weather_crystal",
]
const EXPECTED_PRODUCT_IDS: Array[String] = [
	"星露莓", "月壤葡萄", "孢子丝绸", "光合凝胶", "轨道盆栽", "寒冠冰糖", "深海菌毯", "晨昏奶酪", "北极薄荷", "星尘面包", "梦游蘑菇",
	"磁核榴莲", "彗尾柑", "环晶电池", "太阳鳞片", "海底黑油", "反物质茶", "静电蜂蜜", "等离子米", "火山番茄", "潮汐电浆",
	"重力陶瓷", "虹膜矿粉", "引力棉", "钛壳贝", "陨铁酱料", "暗礁珊瑚",
	"活体芯片", "极光盐", "轨迹墨水", "离岸水晶",
	"量子蜜瓜", "脉冲咖啡", "真空可可", "离子香料", "梦境香氛", "零点饮料", "云母玩具", "风暴珍珠", "赤道香草",
	"星鲸罐头", "星鳍鱼群", "蓝潮藻", "巨藻纤维", "夜航香蕉", "卫星坚果",
]
const EXPECTED_WEATHER_TAGS := {
	"星露莓": ["weather_biological", "weather_food"],
	"月壤葡萄": ["weather_biological", "weather_food"],
	"孢子丝绸": ["weather_biological"],
	"光合凝胶": ["weather_biological", "weather_medicine"],
	"轨道盆栽": ["weather_biological"],
	"寒冠冰糖": ["weather_biological", "weather_food"],
	"深海菌毯": ["weather_biological", "weather_medicine"],
	"晨昏奶酪": ["weather_biological", "weather_food"],
	"北极薄荷": ["weather_biological", "weather_medicine", "weather_food"],
	"星尘面包": ["weather_biological", "weather_food"],
	"梦游蘑菇": ["weather_biological"],
	"磁核榴莲": ["weather_energy", "weather_biological", "weather_food"],
	"彗尾柑": ["weather_energy", "weather_biological", "weather_food"],
	"环晶电池": ["weather_energy", "weather_electronic", "weather_crystal"],
	"太阳鳞片": ["weather_energy"],
	"海底黑油": ["weather_energy"],
	"反物质茶": ["weather_energy", "weather_food"],
	"静电蜂蜜": ["weather_energy", "weather_biological", "weather_food"],
	"等离子米": ["weather_energy", "weather_biological", "weather_food"],
	"火山番茄": ["weather_energy", "weather_biological", "weather_food"],
	"潮汐电浆": ["weather_energy"],
	"重力陶瓷": ["weather_crystal"],
	"虹膜矿粉": ["weather_crystal"],
	"引力棉": ["weather_biological"],
	"钛壳贝": ["weather_biological"],
	"陨铁酱料": ["weather_food"],
	"暗礁珊瑚": ["weather_biological"],
	"活体芯片": ["weather_electronic", "weather_biological"],
	"极光盐": ["weather_food", "weather_crystal"],
	"轨迹墨水": ["weather_electronic"],
	"离岸水晶": ["weather_crystal"],
	"量子蜜瓜": ["weather_biological", "weather_food"],
	"脉冲咖啡": ["weather_food"],
	"真空可可": ["weather_food"],
	"离子香料": ["weather_food"],
	"梦境香氛": ["weather_biological"],
	"零点饮料": ["weather_food"],
	"云母玩具": ["weather_crystal"],
	"风暴珍珠": ["weather_crystal"],
	"赤道香草": ["weather_biological", "weather_food"],
	"星鲸罐头": ["weather_biological", "weather_food"],
	"星鳍鱼群": ["weather_biological", "weather_food"],
	"蓝潮藻": ["weather_biological", "weather_food"],
	"巨藻纤维": ["weather_biological"],
	"夜航香蕉": ["weather_biological", "weather_food"],
	"卫星坚果": ["weather_biological", "weather_food"],
}

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog = load(CATALOG_PATH)
	_expect(catalog != null, "product industry catalog loads")
	if catalog == null:
		_finish()
		return
	_expect(catalog.has_method("tags_for_product"), "catalog exposes public tags_for_product API")
	_expect(EXPECTED_PRODUCT_IDS.size() == 46 and EXPECTED_WEATHER_TAGS.size() == 46, "classification oracle covers exactly 46 products")
	_expect(catalog.call("product_ids") == EXPECTED_PRODUCT_IDS, "catalog preserves all 46 product ids and their order")
	for product_id in EXPECTED_PRODUCT_IDS:
		_verify_product(catalog, product_id)
	for product_id_variant in EXPECTED_WEATHER_TAGS.keys():
		_expect(EXPECTED_PRODUCT_IDS.has(str(product_id_variant)), "classification oracle has no unexpected product id: %s" % str(product_id_variant))
	_verify_known_examples(catalog)
	_verify_no_display_name_inference()
	_verify_pure_output(catalog)
	_finish()


func _verify_product(catalog, product_id: String) -> void:
	var tags: Array[String] = catalog.call("tags_for_product", product_id)
	var industry_id := str(catalog.call("industry_for_product", product_id))
	var snapshot: Dictionary = catalog.call("product_snapshot", product_id)
	_expect(not industry_id.is_empty(), "%s preserves its industry" % product_id)
	_expect(tags.has("runtime_product") and tags.has("industry_%s" % industry_id), "%s preserves its existing tags" % product_id)
	_expect(tags == snapshot.get("optional_tags", []), "%s API matches its explicit resource tags" % product_id)
	var weather_tags: Array[String] = []
	var allowed_only := true
	for tag in tags:
		if tag.begins_with("weather_"):
			weather_tags.append(tag)
			allowed_only = allowed_only and WEATHER_TAG_IDS.has(tag)
	_expect(allowed_only and not weather_tags.is_empty(), "%s has at least one approved weather tag" % product_id)
	_expect(weather_tags == EXPECTED_WEATHER_TAGS.get(product_id, []), "%s has its exact explicit weather classification" % product_id)


func _verify_known_examples(catalog) -> void:
	var battery_tags: Array[String] = catalog.call("tags_for_product", "环晶电池")
	_expect(_has_all(battery_tags, ["weather_energy", "weather_electronic", "weather_crystal"]), "ring crystal battery is energy, electronic, and crystal")
	_expect(not battery_tags.has("weather_food") and not battery_tags.has("weather_medicine"), "ring crystal battery is not food or medicine")
	var mint_tags: Array[String] = catalog.call("tags_for_product", "北极薄荷")
	_expect(_has_all(mint_tags, ["weather_biological", "weather_medicine", "weather_food"]), "arctic mint is biological, medicine, and food")
	_expect(not mint_tags.has("weather_energy") and not mint_tags.has("weather_electronic"), "arctic mint is not energy or electronic")
	var ink_tags: Array[String] = catalog.call("tags_for_product", "轨迹墨水")
	_expect(ink_tags.has("weather_electronic") and not ink_tags.has("weather_crystal"), "trajectory ink is electronic but not crystal")
	var ceramic_tags: Array[String] = catalog.call("tags_for_product", "重力陶瓷")
	_expect(ceramic_tags.has("weather_crystal") and not ceramic_tags.has("weather_biological"), "gravity ceramic is crystal but not biological")
	_expect((catalog.call("tags_for_product", "unknown_product") as Array).is_empty(), "unknown product ids fail closed")


func _verify_no_display_name_inference() -> void:
	var catalog_script := load("res://scripts/content/product_industry_catalog_resource.gd") as Script
	var entry_script := load("res://scripts/content/product_industry_entry_resource.gd") as Script
	_expect(catalog_script != null and catalog_script.can_instantiate() and entry_script != null and entry_script.can_instantiate(), "catalog data scripts can be instantiated")
	if catalog_script == null or not catalog_script.can_instantiate() or entry_script == null or not entry_script.can_instantiate():
		return
	var catalog = catalog_script.new()
	var entry = entry_script.new()
	entry.product_id = "opaque_product_id"
	entry.display_name = "环晶电池"
	var explicit_tags: Array[String] = ["runtime_product", "weather_food"]
	entry.optional_tags = explicit_tags
	catalog.products.append(entry)
	_expect((catalog.call("tags_for_product", "环晶电池") as Array).is_empty(), "display names do not classify products")
	_expect(catalog.call("tags_for_product", "opaque_product_id") == ["runtime_product", "weather_food"], "product ids return only their explicit tags")


func _verify_pure_output(catalog) -> void:
	var tags: Array[String] = catalog.call("tags_for_product", "环晶电池")
	_expect(_is_pure_data(tags), "tags_for_product returns public pure data")
	tags.clear()
	_expect(not (catalog.call("tags_for_product", "环晶电池") as Array).is_empty(), "callers cannot mutate catalog tags through returned arrays")


func _weather_tags(tags: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for tag in tags:
		if tag.begins_with("weather_"):
			result.append(tag)
	return result


func _has_all(tags: Array[String], expected: Array) -> bool:
	for tag_variant in expected:
		if not tags.has(str(tag_variant)):
			return false
	return true


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not _is_pure_data(key) or not _is_pure_data(value[key]):
				return false
		return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("WEATHER_PRODUCT_CLASSIFICATION_TAGS_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("WEATHER_PRODUCT_CLASSIFICATION_TAGS_TEST|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)

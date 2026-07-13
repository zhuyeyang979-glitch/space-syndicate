extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/CardCodexPublicSnapshotService.tscn"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SERVICE_SCENE) as PackedScene
	_expect(packed != null, "service scene loads")
	var service := packed.instantiate() if packed != null else null
	_expect(service != null, "service scene instantiates")
	if service == null:
		_finish()
		return
	root.add_child(service)
	service.call("configure", {})
	var card := _card_source()
	var browser: Dictionary = service.call("compose_browser", {
		"names": ["轨道融资1"], "columns": 3, "rows": 2, "page_index": 0, "filter_id": "all", "selected_card": "轨道融资1",
		"filter_label": "全部牌", "icon_legend": "◆城市 / ◇商品", "run_pool_count": 12, "district_supply_count": 6,
		"filters": [{"id": "all", "label": "全部", "short_label": "全部", "icon": "◆", "count": 1, "accent": Color("#38bdf8")}],
		"cards": [card], "preview_card": card,
	})
	_expect(str(browser.get("summary_text", "")).contains("本局牌池12张"), "browser summary is composed")
	_expect((browser.get("cards", []) as Array).size() == 1 and str(((browser.get("cards", []) as Array)[0] as Dictionary).get("card_name", "")) == "轨道融资1", "browser ViewModel contract is preserved")
	_expect(str((browser.get("preview", {}) as Dictionary).get("body", "")).contains("I→IV"), "browser preview is composed")
	var snapshot: Dictionary = service.call("compose_detail", card)
	_expect(str(snapshot.get("summary_text", "")).contains("轨道融资"), "detail summary names the card")
	var detail := snapshot.get("detail", {}) as Dictionary
	_expect((detail.get("facts", []) as Array).size() == 4, "detail exposes four public fact cards")
	_expect(((detail.get("tactical", {}) as Dictionary).get("entries", []) as Array).size() == 3, "detail exposes three tactical cards")
	_expect((detail.get("upgrades", []) as Array).size() == 2, "detail exposes supplied upgrades")
	_expect(str((((detail.get("tactical", {}) as Dictionary).get("entries", []) as Array)[2] as Dictionary).get("body", "")).contains("经济实力线索"), "public clue copy uses supplied requirement facts")
	var debug: Dictionary = service.call("debug_snapshot")
	_expect(bool(debug.get("uses_existing_browser_viewmodel", false)) and bool(debug.get("uses_existing_detail_viewmodel", false)), "existing ViewModels are reused")
	_expect(not bool(debug.get("calculates_card_price", true)) and not bool(debug.get("calculates_card_effects", true)) and not bool(debug.get("calculates_play_requirements", true)), "service owns no card rules")
	_expect(_is_pure_data(browser) and _is_pure_data(snapshot) and not _contains_private_key(browser) and not _contains_private_key(snapshot), "service outputs are viewer-safe pure data")
	var injected := card.duplicate(true)
	injected["hidden_owner"] = 3
	injected["private_plan"] = "secret"
	var injected_snapshot: Dictionary = service.call("compose_detail", injected)
	_expect(not _contains_private_key(injected_snapshot) and not JSON.stringify(injected_snapshot).contains("secret"), "unknown private input is not copied")
	service.queue_free()
	await process_frame
	_finish()


func _card_source() -> Dictionary:
	return {
		"valid": true, "index": 0, "total": 12, "card_name": "轨道融资1", "display_name": "轨道融资 I", "icon": "◆", "family": "轨道融资", "kind": "city_growth", "rank": 1, "rank_label": "I", "tag_text": "城市 / 金融", "accent": Color("#38bdf8"),
		"price": 140, "category_label": "城市牌", "icon_route_label": "城市成长", "subtype_label": "融资", "source_type_label": "普通卡", "supply_layer": "区域补给",
		"art_stats": "GDP+20 / 交通+1", "use_case": "建立第一条稳定收入路线。", "strategy_route_label": "城市成长", "strategy_summary": "城市成长｜先发展再滚动收益", "strategy_use_text": "提高城市GDP与交通效率。",
		"quick_effect_compact": "目标城市GDP提高", "quick_effect_full": "令目标城市GDP提高20。", "full_effect_text": "令目标城市GDP提高20，并提高交通效率。", "rules_text_compact": "选择己方城市｜GDP+20", "level_gradient_text": "I:+20 / II:+30 / III:+40 / IV:+55", "detail_tooltip": "轨道融资 I\n公开卡面与规则", "face_route_text": "◆城市成长｜融资",
		"requires_target_monster": false, "targets_player": false, "targets_monster": false, "play_region_share_required": 25, "play_region_scope_label": "目标城市", "panic": 0, "route_damage": 0, "persistent": false, "play_requirement_text": "目标城市GDP份额≥25%", "key_rule_facts": ["GDP+20", "交通+1"],
		"read_chips": [{"text": "¥140", "tooltip": "购买价格", "fg": Color("#fde68a")}, {"text": "份额25%", "tooltip": "出牌门槛", "fg": Color("#93c5fd")}],
		"upgrades": [
			{"roman": "I", "price": 140, "strength_band": "基础", "preview": "GDP+20", "display_name": "轨道融资 I", "full_effect_text": "GDP+20", "accent": Color("#38bdf8"), "fill_weight": 0.10},
			{"roman": "II", "price": 140, "strength_band": "强化", "preview": "GDP+30", "display_name": "轨道融资 II", "full_effect_text": "GDP+30", "accent": Color("#67e8f9"), "fill_weight": 0.13},
		],
		"resolution_animation_text": "卡面公开 / 城市高亮 / GDP数字上浮",
	}


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant: Variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]): return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant): return false
	return true


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			if str(key_variant).to_lower() in ["owner", "owner_index", "hidden_owner", "private_target", "private_plan", "ai_private_plan", "hand", "cash", "private_discard"]: return true
			if _contains_private_key(value[key_variant]): return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_private_key(item_variant): return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("CARD CODEX PUBLIC SNAPSHOT SERVICE: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("CARD CODEX PUBLIC SNAPSHOT SERVICE PASS")
		quit(0)
		return
	print("CARD CODEX PUBLIC SNAPSHOT SERVICE FAIL: %d" % failures.size())
	quit(1)

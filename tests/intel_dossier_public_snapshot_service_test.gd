extends SceneTree

const SERVICE_SCENE := preload("res://scenes/runtime/IntelDossierPublicSnapshotService.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var service := SERVICE_SCENE.instantiate() as IntelDossierPublicSnapshotService
	root.add_child(service)
	service.configure()
	var source := _source()
	var source_before := source.duplicate(true)
	var snapshot := service.compose(source)
	var board := snapshot.get("board", {}) as Dictionary
	var intents := _intents(board)
	_expect(source == source_before, "compose mutates zero source data")
	_expect(str(snapshot.get("summary_text", "")).contains("公共卡牌履历"), "summary names the public history source")
	_expect((board.get("kpis", []) as Array).size() == 4 and not (board.get("clues", []) as Array).is_empty(), "board composes bounded public-world and viewer-private evidence lanes")
	_expect(_has_kind(intents, &"set_city_owner_guess") and _has_kind(intents, &"clear_city_owner_guess"), "city set and clear intents are typed")
	_expect(_has_kind(intents, &"set_city_guess_confidence") and _has_kind(intents, &"set_city_guess_reason"), "city confidence and reason intents are typed")
	_expect(_has_kind(intents, &"set_card_history_subscription") and _has_kind(intents, &"set_card_history_suspects") and _has_kind(intents, &"clear_card_history_annotation"), "card annotation controls use narrow typed commands")
	_expect(_has_kind(intents, &"open_region") and _has_kind(intents, &"open_product") and _has_kind(intents, &"open_monster") and _has_kind(intents, &"open_card") and _has_kind(intents, &"focus_history") and _has_kind(intents, &"open_economy"), "public world and history deep links use typed navigation intents")
	_expect((snapshot.get("public_navigation_links", []) as Array) == (board.get("links", []) as Array), "formatter exposes detached public navigation links as a clear contract partition")
	var rendered := JSON.stringify(snapshot)
	_expect(rendered.contains("公开区域证据") and rendered.contains("公开业主：玩家2") and rendered.contains("商品、路线与天气") and rendered.contains("怪兽吸引线索"), "formatter restores public region, facility owner, product/route/weather, and monster clues")
	_expect(not rendered.contains("warehouse_inventory") and not rendered.contains("hidden_owner") and not rendered.contains("true_owner"), "formatter never projects private inventory or hidden city ownership")
	_expect(_all_intents_exact_and_valid(intents), "every control carries the exact typed intent contract")
	_expect(not JSON.stringify(snapshot).contains("intel_city_mark_") and not JSON.stringify(snapshot).contains("track_intel_"), "payloads are never encoded in string action ids")
	_expect(not _has_kind(intents, &"use_city_reveal") and not _has_kind(intents, &"use_contract_trace"), "unowned role actions stay unavailable")
	var reveal_source := _source()
	(reveal_source.get("city_entries", []) as Array)[0]["authorized_reveal"] = true
	(reveal_source.get("city_entries", []) as Array)[0]["confidence"] = 100
	var reveal_groups: Array = ((service.compose(reveal_source).get("board", {}) as Dictionary).get("control_groups", []) as Array)
	_expect(not reveal_groups.is_empty() and ((reveal_groups[0] as Dictionary).get("actions", []) as Array).is_empty(), "authorized confidence 100 is display-only and locked")
	var injected := _source()
	injected["hidden_owner"] = 7
	injected["opponent_hand"] = ["SECRET_CARD"]
	_expect(not JSON.stringify(service.compose(injected)).contains("SECRET_CARD"), "unknown private input is not projected")
	var debug := service.debug_snapshot()
	_expect(bool(debug.get("typed_action_intents", false)) and not bool(debug.get("action_id_controls", true)), "debug contract retires string action controls")
	_expect(not bool(debug.get("city_reveal_controls_exposed", true)) and not bool(debug.get("contract_trace_controls_exposed", true)), "debug contract records unavailable role actions")
	var empty := service.compose({"valid": false, "reason": "无授权玩家"})
	_expect(str(empty.get("summary_text", "")) == "无授权玩家" and (((empty.get("board", {}) as Dictionary).get("links", []) as Array).is_empty()), "denied snapshot has no actionable fallback")
	service.queue_free()
	await process_frame
	_finish()


func _source() -> Dictionary:
	return {
		"valid": true,
		"viewer_index": 0,
		"viewer_name": "本地玩家",
		"city_owner_revision": "city-revision-1",
		"annotation_owner_revision": "annotation-revision-1",
		"focused_history_entry_id": "card-history:42",
		"public_players": [
			{"player_index": 0, "public_player_name": "本地玩家"},
			{"player_index": 1, "public_player_name": "玩家2"},
			{"player_index": 2, "public_player_name": "玩家3"},
		],
		"public_world_intel": [{
			"district_index": 1,
			"region_id": "region.001",
			"region_stable_item_id": "region:1",
			"name": "环城港",
			"terrain_label": "陆地",
			"economic_focus_label": "能源",
			"facility_count": 2,
			"anonymous_warehouse_count": 1,
			"public_facility_entries": [
				{"facility_type": "warehouse", "industry_id": "storage", "owner_kind": "player", "owner_player_index": 1, "rank": 1},
				{"facility_type": "factory", "industry_id": "energy", "owner_kind": "neutral", "owner_player_index": -1, "rank": 1},
			],
			"supply_product_ids": ["活体芯片"],
			"supply_text": "活体芯片",
			"demand_text": "燃料",
			"weather_text": "晴朗",
			"trade_route_load": 2,
			"public_clue": "公开运输痕迹",
			"monster_attraction_entries": [{"name": "流星哨兵", "reason": "被公开能源信号吸引", "stable_item_id": "monster:2"}],
		}],
		"city_entries": [{
			"district_index": 1,
			"region_id": "region.001",
			"name": "环城港",
			"city_level": 2,
			"city_last_income": 80,
			"suspected_player_index": 1,
			"confidence": 2,
			"reason_id": "card",
			"authorized_reveal": false,
		}],
		"card_entries": [{
			"history_entry_id": "card-history:42",
			"public_sequence": 42,
			"public_card_id": "orbital_finance_i",
			"public_card_name": "轨道融资 I",
			"public_target": "区域2",
			"public_result": "GDP上升",
			"viewer_annotation": {"suspected_player_indices": [1], "subscribed": false},
		}],
		"role_definition": {"name": "测试角色", "passive": "公开定义"},
		"role_usage": {"residual_catalog": 0, "public_exclusion": 0},
	}


func _intents(board: Dictionary) -> Array:
	var result: Array = []
	for entry_variant in board.get("actions", []) as Array:
		_append_intent(result, entry_variant)
	for group_variant in board.get("control_groups", []) as Array:
		for entry_variant in (group_variant as Dictionary).get("actions", []) as Array:
			_append_intent(result, entry_variant)
	for entry_variant in board.get("links", []) as Array:
		_append_intent(result, entry_variant)
	return result


func _append_intent(target: Array, entry_variant: Variant) -> void:
	if entry_variant is Dictionary and (entry_variant as Dictionary).get("intent", {}) is Dictionary:
		target.append(((entry_variant as Dictionary).get("intent", {}) as Dictionary).duplicate(true))


func _has_kind(intents: Array, kind: StringName) -> bool:
	for intent_variant in intents:
		if StringName((intent_variant as Dictionary).get("intent_kind", "")) == kind:
			return true
	return false


func _all_intents_exact_and_valid(intents: Array) -> bool:
	if intents.is_empty():
		return false
	var expected := ["schema_version", "intent_kind", "viewer_index", "subject_id", "expected_owner_revision", "payload"]
	for intent_variant in intents:
		var dictionary := intent_variant as Dictionary
		if dictionary.keys().size() != expected.size():
			return false
		for key in expected:
			if not dictionary.has(key):
				return false
		if IntelDossierActionIntent.from_dictionary(dictionary) == null:
			return false
	return true


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("INTEL_DOSSIER_PUBLIC_SNAPSHOT_SERVICE_TEST|status=PASS|checks=%d" % _checks)
		quit(0)
		return
	push_error("INTEL_DOSSIER_PUBLIC_SNAPSHOT_SERVICE_TEST failed:\n- " + "\n- ".join(_failures))
	quit(1)

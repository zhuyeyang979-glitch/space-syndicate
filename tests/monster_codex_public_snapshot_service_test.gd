extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/MonsterCodexPublicSnapshotService.tscn"

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
	var snapshot: Dictionary = service.call("compose", _source())
	_expect(str(snapshot.get("summary_text", "")).contains("岩甲兽"), "summary is composed")
	_expect(str(snapshot.get("preview_text", "")).contains("公开行动"), "preview explains public actions without probability")
	_expect(str(snapshot.get("card_preview_text", "")).contains("¥260"), "bound card preview is composed")
	var detail: Dictionary = snapshot.get("detail", {}) if snapshot.get("detail", {}) is Dictionary else {}
	_expect((detail.get("chips", []) as Array).size() == 6 and (detail.get("kpis", []) as Array).size() == 4 and (detail.get("actions", []) as Array).size() == 1, "detail contract is stable")
	var action: Dictionary = (detail.get("actions", []) as Array)[0] as Dictionary
	_expect(str(action.get("disclosure", "")) == "公开效果｜权重隐藏" and not action.has("probability") and not action.has("probability_tooltip"), "action presentation excludes probability and internal weight fields")
	_expect(_is_pure_data(snapshot) and _is_pure_data(service.call("debug_snapshot")), "service outputs are pure data")
	_expect(not _contains_private_key(snapshot), "public monster snapshot excludes private keys")
	service.queue_free()
	await process_frame
	_finish()


func _source() -> Dictionary:
	return {
		"valid": true, "index": 0, "total": 8, "selected": true,
		"entry": {"name": "岩甲兽", "style": "重装陆行怪兽。", "hp": 18, "armor": 3, "resource_focus": ["环晶电池"]},
		"ecology": {"movement_archetype": "陆行", "movement_traits": ["重装"], "role_tags": ["破坏", "仓储压力"], "bound_skill_counts": [1, 2, 2, 3], "summon_access": "monster_zone", "resource_drain": 2, "max_damage": 5, "economy_boon": {"label": "矿脉富集"}},
		"profile": {"accent": Color("#fb7185")}, "accent": Color("#fb7185"), "move_text": "80m/s", "art_move_text": "80m/s", "ecology_move_text": "80m/s", "max_range_text": "120m", "encounter_range_text": "50m", "mobility_summary": "陆地稳定移动", "action_summary": "撞击/掠夺", "level_labels": ["I", "II", "III", "IV"],
		"actions": [{"name": "撞击", "text": "攻击区域并制造公开压力。", "tags": ["攻击"], "facts": "伤害5｜压力+1"}],
		"monster_card": {"valid": true, "display_name": "岩甲兽 I", "price": 260, "region_text": "不限区"},
	}


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant: Variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			if str(key_variant).to_lower() in ["owner", "hidden_owner", "private_target", "private_plan", "ai_private_plan"]:
				return true
			if _contains_private_key(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_private_key(item_variant):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("MONSTER CODEX PUBLIC SNAPSHOT SERVICE: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("MONSTER CODEX PUBLIC SNAPSHOT SERVICE PASS")
		quit(0)
		return
	print("MONSTER CODEX PUBLIC SNAPSHOT SERVICE FAIL: %d" % failures.size())
	quit(1)

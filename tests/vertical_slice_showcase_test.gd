extends SceneTree

const SHOWCASE_SCENE := "res://scenes/ui/VerticalSliceShowcase.tscn"
const DIRECTOR_SCRIPT := preload("res://scripts/ui/showcase_director.gd")
const SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/visual_event_snapshot.gd")
const AUDIO_EVENT_MAP_PATH := "res://data/audio/audio_event_map.json"
const REQUIRED_SCENARIOS := ["first_table", "monster_pressure", "public_track_intro", "bid_practice"]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(SHOWCASE_SCENE), "VerticalSliceShowcase scene exists")
	var packed := load(SHOWCASE_SCENE) as PackedScene
	_expect(packed != null, "VerticalSliceShowcase scene loads")
	if packed == null:
		_finish()
		return
	get_root().size = Vector2i(1600, 960)
	var showcase := packed.instantiate() as Control
	get_root().add_child(showcase)
	await process_frame
	await process_frame
	_expect(showcase.has_method("play_stage") and showcase.has_method("get_showcase_contract"), "VerticalSliceShowcase exposes deterministic stage controls")
	var contract_variant: Variant = showcase.call("get_showcase_contract")
	var contract: Dictionary = contract_variant if contract_variant is Dictionary else {}
	var stage_ids: Array = contract.get("stage_ids", []) if contract.get("stage_ids", []) is Array else []
	var scenario_ids: Array = contract.get("scenario_ids", []) if contract.get("scenario_ids", []) is Array else []
	for required_stage in [
		"board_idle",
		"card_hover",
		"card_drag_valid",
		"card_drag_invalid",
		"card_play_frame_00",
		"card_play_frame_08",
		"card_play_frame_16",
		"monster_spawn",
		"monster_move",
		"monster_attack_frame_00",
		"monster_attack_frame_12",
		"monster_attack_frame_24",
		"public_track_reveal",
		"bid_highlight",
		"balance_report_preview",
	]:
		_expect(stage_ids.has(required_stage), "showcase timeline includes %s" % required_stage)
	for required_scenario in REQUIRED_SCENARIOS:
		_expect(scenario_ids.has(required_scenario), "showcase contract includes scenario %s" % required_scenario)
	_expect(bool(contract.get("has_visual_layer", false)) and bool(contract.get("has_targeting_overlay", false)) and bool(contract.get("has_hand_rack", false)), "showcase owns visual-event, targeting, and HandRack layers")
	var director: Node = DIRECTOR_SCRIPT.new()
	_expect(bool(director.call("load_sequence")), "ShowcaseDirector loads local sequence JSON")
	var all_events: Array = []
	for stage_id_variant in stage_ids:
		var stage_id := str(stage_id_variant)
		var stage_events: Array = director.call("visual_events_for_stage", stage_id)
		all_events.append_array(stage_events)
	var classes := SNAPSHOT_SCRIPT.event_classes(all_events)
	for required_class in ["card_play", "target_arrow", "card_reveal", "monster_spawn", "monster_move", "monster_attack", "city_damage", "route_damage", "cash_gain", "final_countdown"]:
		_expect(classes.has(required_class), "showcase sequence includes visual event class %s" % required_class)
	_expect(_scenario_contracts_are_complete(director), "Scenario Lab bridge covers first_table, monster_pressure, public_track_intro, and bid_practice")
	showcase.call("play_stage", "card_hover")
	await process_frame
	var hand_rack := showcase.find_child("ShowcaseHandRack", true, false)
	var hover_snapshot: Array = hand_rack.call("get_card_target_snapshot") if hand_rack != null and hand_rack.has_method("get_card_target_snapshot") else []
	_expect(not hover_snapshot.is_empty() and bool((hover_snapshot[0] as Dictionary).get("hovered", false)), "card_hover stage raises the first hand card")
	showcase.call("play_stage", "card_drag_valid")
	await process_frame
	var targeting := showcase.find_child("ShowcaseTargetingOverlay", true, false)
	_expect(targeting != null and targeting.has_method("is_targeting_active") and bool(targeting.call("is_targeting_active")), "card_drag_valid stage shows target arrow feedback")
	var visual_layer := showcase.find_child("ShowcaseVisualEventLayer", true, false)
	var visual_snapshot: Dictionary = visual_layer.call("get_visual_event_snapshot") if visual_layer != null and visual_layer.has_method("get_visual_event_snapshot") else {}
	var visual_classes: Array = visual_snapshot.get("event_classes", []) if visual_snapshot.get("event_classes", []) is Array else []
	_expect(visual_classes.has("target_arrow"), "visual layer receives target_arrow event during drag-valid stage")
	showcase.call("play_stage", "balance_report_preview")
	await process_frame
	var balance_panel := showcase.find_child("ShowcaseBalancePreview", true, false) as Control
	_expect(balance_panel != null and balance_panel.visible, "balance report preview stage exposes the report panel")
	showcase.call("play_scenario", "monster_pressure")
	await process_frame
	visual_snapshot = visual_layer.call("get_visual_event_snapshot") if visual_layer != null and visual_layer.has_method("get_visual_event_snapshot") else {}
	visual_classes = visual_snapshot.get("event_classes", []) if visual_snapshot.get("event_classes", []) is Array else []
	_expect(visual_classes.has("monster_spawn"), "play_scenario(monster_pressure) starts the monster pressure presentation segment")
	director.free()
	get_root().remove_child(showcase)
	showcase.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Vertical slice showcase test passed.")
		quit(0)
	else:
		printerr("Vertical slice showcase test failed:")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)


func _scenario_contracts_are_complete(director: Node) -> bool:
	var audio_map := _load_audio_map()
	if audio_map.is_empty():
		return false
	for scenario_id_variant in REQUIRED_SCENARIOS:
		var scenario_id := str(scenario_id_variant)
		var scenario_variant: Variant = director.call("scenario_snapshot", scenario_id)
		if not (scenario_variant is Dictionary):
			push_error("scenario snapshot missing for %s" % scenario_id)
			return false
		var scenario: Dictionary = scenario_variant
		var stage_ids: Array = scenario.get("stage_ids", []) if scenario.get("stage_ids", []) is Array else []
		var event_classes: Array = scenario.get("event_classes", []) if scenario.get("event_classes", []) is Array else []
		var audio_hooks: Array = scenario.get("audio_hooks", []) if scenario.get("audio_hooks", []) is Array else []
		var required_event_classes: Array = scenario.get("required_event_classes", []) if scenario.get("required_event_classes", []) is Array else []
		var required_audio_hooks: Array = scenario.get("required_audio_hooks", []) if scenario.get("required_audio_hooks", []) is Array else []
		if stage_ids.is_empty():
			push_error("scenario %s has no stages" % scenario_id)
			return false
		for event_class_variant in required_event_classes:
			if not event_classes.has(str(event_class_variant)):
				push_error("scenario %s missing event class %s" % [scenario_id, str(event_class_variant)])
				return false
		for hook_variant in required_audio_hooks:
			var hook := str(hook_variant)
			if not audio_hooks.has(hook):
				push_error("scenario %s missing audio hook %s" % [scenario_id, hook])
				return false
			if not audio_map.has(hook):
				push_error("audio map missing hook %s for scenario %s" % [hook, scenario_id])
				return false
	return true


func _load_audio_map() -> Dictionary:
	var text := FileAccess.get_file_as_string(AUDIO_EVENT_MAP_PATH)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

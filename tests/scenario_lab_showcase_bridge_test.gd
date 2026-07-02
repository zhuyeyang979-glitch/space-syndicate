extends SceneTree

const SHOWCASE_SCENE := "res://scenes/ui/VerticalSliceShowcase.tscn"
const FIXTURE_PATH := "res://data/showcase/scenario_lab_bridge_fixture.json"
const ADAPTER_SCRIPT := preload("res://scripts/ui/scenario_lab_showcase_adapter.gd")
const DIRECTOR_SCRIPT := preload("res://scripts/ui/showcase_director.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists("res://scripts/ui/scenario_lab_showcase_adapter.gd"), "ScenarioLabShowcaseAdapter script exists")
	_expect(ResourceLoader.exists(FIXTURE_PATH), "Scenario Lab bridge fixture exists outside data/scenarios")
	var fixture := _load_fixture()
	var payloads: Array = fixture.get("payloads", []) if fixture.get("payloads", []) is Array else []
	_expect(payloads.size() == 4, "bridge fixture covers first_table, monster_pressure, public_track_intro, and bid_practice")
	var adapter: Variant = ADAPTER_SCRIPT.new()
	var director: Node = DIRECTOR_SCRIPT.new()
	_expect(bool(director.call("load_sequence")), "ShowcaseDirector loads fallback sequence for Scenario Lab payloads")
	var expected_classes := {
		"first_table": ["card_play", "card_reveal", "cash_gain", "gdp_delta"],
		"monster_pressure": ["monster_attack", "city_damage", "cash_gain", "gdp_delta"],
		"public_track_intro": ["card_reveal", "route_damage"],
		"bid_practice": ["target_arrow", "card_reveal"],
	}
	for payload_variant in payloads:
		var payload: Dictionary = payload_variant
		var snapshot: Dictionary = adapter.call("normalize_payload", payload)
		var scenario_id := str(payload.get("scenario_id", ""))
		_expect(bool(snapshot.get("hidden_info_safe", false)), "payload %s is hidden-info safe" % scenario_id)
		_expect(str(snapshot.get("source", "")) == "scenario_lab_visual_events", "payload %s is marked as Scenario Lab visual-event source" % scenario_id)
		var classes: Array = snapshot.get("event_classes", []) if snapshot.get("event_classes", []) is Array else []
		for required_class in expected_classes.get(scenario_id, []):
			_expect(classes.has(required_class), "payload %s includes event class %s" % [scenario_id, required_class])
		var hooks: Array = snapshot.get("audio_hooks", []) if snapshot.get("audio_hooks", []) is Array else []
		_expect(not hooks.is_empty(), "payload %s produces audio hooks" % scenario_id)
		var director_snapshot: Dictionary = director.call("stage_snapshot_from_scenario_lab", payload)
		_expect(str(director_snapshot.get("source", "")) == "scenario_lab_visual_events", "director adapts payload %s through the bridge" % scenario_id)
	var unsafe: Dictionary = fixture.get("unsafe_payload_example", {}) if fixture.get("unsafe_payload_example", {}) is Dictionary else {}
	var unsafe_snapshot: Dictionary = adapter.call("normalize_payload", unsafe)
	_expect(not bool(unsafe_snapshot.get("hidden_info_safe", true)), "adapter flags Scenario Lab payloads that leak true_owner/private fields")
	_expect(not (unsafe_snapshot.get("rejected_private_fields", []) as Array).is_empty(), "unsafe payload reports rejected private fields")
	var packed := load(SHOWCASE_SCENE) as PackedScene
	_expect(packed != null, "VerticalSliceShowcase scene loads for payload playback")
	if packed != null:
		get_root().size = Vector2i(1600, 960)
		var showcase := packed.instantiate() as Control
		get_root().add_child(showcase)
		await process_frame
		await process_frame
		var monster_payload := _payload_for(payloads, "monster_pressure")
		showcase.call("clear_audio_events")
		showcase.call("play_scenario_payload", monster_payload)
		await process_frame
		var visual_layer := showcase.find_child("ShowcaseVisualEventLayer", true, false)
		var visual_snapshot: Dictionary = visual_layer.call("get_visual_event_snapshot") if visual_layer != null and visual_layer.has_method("get_visual_event_snapshot") else {}
		var visual_classes: Array = visual_snapshot.get("event_classes", []) if visual_snapshot.get("event_classes", []) is Array else []
		_expect(visual_classes.has("monster_attack") and visual_classes.has("city_damage"), "VerticalSliceShowcase renders Scenario Lab monster_pressure payload")
		var audio_snapshot: Dictionary = showcase.call("get_audio_event_snapshot")
		var audio_ids: Array = audio_snapshot.get("event_ids", []) if audio_snapshot.get("event_ids", []) is Array else []
		_expect(audio_ids.has("monster_attack") and audio_ids.has("city_damage"), "VerticalSliceShowcase emits silent audio hooks for Scenario Lab monster_pressure payload")
		showcase.call("clear_audio_events")
		showcase.call("play_scenario_payload", unsafe)
		await process_frame
		visual_snapshot = visual_layer.call("get_visual_event_snapshot") if visual_layer != null and visual_layer.has_method("get_visual_event_snapshot") else {}
		var events: Array = visual_snapshot.get("events", []) if visual_snapshot.get("events", []) is Array else []
		_expect(events.is_empty(), "VerticalSliceShowcase clears events for unsafe Scenario Lab payloads")
		audio_snapshot = showcase.call("get_audio_event_snapshot")
		audio_ids = audio_snapshot.get("event_ids", []) if audio_snapshot.get("event_ids", []) is Array else []
		_expect(audio_ids.is_empty(), "VerticalSliceShowcase does not emit audio hooks for unsafe Scenario Lab payloads")
		var inspector := showcase.find_child("ShowcaseRightInspectorRows", true, false)
		_expect(inspector != null, "showcase keeps inspector visible after rejecting unsafe payload")
		get_root().remove_child(showcase)
		showcase.queue_free()
	director.free()
	_finish()


func _load_fixture() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	return parsed if parsed is Dictionary else {}


func _payload_for(payloads: Array, scenario_id: String) -> Dictionary:
	for payload_variant in payloads:
		if payload_variant is Dictionary and str((payload_variant as Dictionary).get("scenario_id", "")) == scenario_id:
			return payload_variant
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Scenario Lab showcase bridge test passed.")
		quit(0)
	else:
		printerr("Scenario Lab showcase bridge test failed:")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)

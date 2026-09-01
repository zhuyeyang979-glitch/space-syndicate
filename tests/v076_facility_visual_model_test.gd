extends SceneTree

const MarkerScene := preload("res://scenes/ui/map/PlanetCityMarker.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var models: Dictionary = {}
	var markers: Dictionary = {}
	for facility_type in ["factory", "market", "warehouse"]:
		var marker := MarkerScene.instantiate() as Control
		_expect(marker != null, "%s marker scene instantiates" % facility_type)
		if marker == null:
			continue
		root.add_child(marker)
		marker.call("configure", {
			"marker_id": "marker.%s.001" % facility_type,
			"facility_id": "facility.%s.001" % facility_type,
			"slot_id": "slot.%s.001" % facility_type,
			"facility_type": facility_type,
			"tag": facility_type.left(1).to_upper(),
			"level": 1,
			"damage_points": 0,
			"damage_revision": 1,
			"compact": false,
			"screen_position": Vector2(100, 100),
		})
		await process_frame
		var debug := marker.call("debug_snapshot") as Dictionary
		var model_kind := str(debug.get("visual_model_kind", ""))
		models[facility_type] = model_kind
		markers[facility_type] = marker
		_expect(str(debug.get("facility_type", "")) == facility_type, "%s keeps its typed facility identity" % facility_type)
		_expect(not model_kind.is_empty(), "%s exposes a non-empty silhouette model kind" % facility_type)
		_expect(not bool(debug.get("primary_visual_letter_only", true)), "%s is not represented by a primary letter only" % facility_type)
		_expect(bool(debug.get("primary_visual_silhouette", false)), "%s uses its silhouette as the primary visual" % facility_type)
		_expect(int(debug.get("silhouette_primitive_count", 0)) >= 4, "%s silhouette has multiple visible primitives" % facility_type)
		_expect(bool(debug.get("inside_viewport", false)), "%s marker rect is inside the real viewport" % facility_type)
		_expect(bool(debug.get("human_visible", false)), "%s marker is alpha/size/rect visible" % facility_type)
		_expect(not bool(debug.get("clip_contents", true)), "%s silhouette is not clipped by its root" % facility_type)
		_expect(str(marker.tooltip_text).contains({"factory": "工厂", "market": "市场", "warehouse": "仓库"}[facility_type]), "%s tooltip names the facility type" % facility_type)
	_expect(models.size() == 3, "all three facility models are present")
	var unique_models := {}
	for model_variant in models.values():
		unique_models[str(model_variant)] = true
	_expect(unique_models.size() == 3, "factory, market, and warehouse silhouettes are visually distinct")

	var factory := markers.get("factory") as Control
	if factory != null:
		var factory_instance_id := factory.get_instance_id()
		factory.call("configure", {
			"marker_id": "marker.factory.001",
			"facility_id": "facility.factory.001",
			"slot_id": "slot.factory.001",
			"facility_type": "factory",
			"tag": "F",
			"level": 2,
			"damage_points": 1,
			"damage_revision": 2,
			"compact": false,
			"screen_position": Vector2(102, 100),
		})
		await process_frame
		var upgraded := factory.call("debug_snapshot") as Dictionary
		_expect(factory.get_instance_id() == factory_instance_id, "factory upgrade reuses the same marker Control instance")
		_expect(str(upgraded.get("marker_id", "")) == "marker.factory.001", "factory upgrade preserves stable marker identity")
		_expect(str(upgraded.get("visual_model_kind", "")) == str(models.get("factory", "")), "factory upgrade preserves its silhouette model")
		_expect(int(upgraded.get("damage_points", 0)) == 1, "factory damage state updates on the existing marker")
		factory.call("play_commit_animation")
		await process_frame
		var building := factory.call("debug_snapshot") as Dictionary
		_expect(str(building.get("lifecycle_state", "")) == "BUILDING", "factory commit exposes a real BUILDING frame")
		_expect(int(building.get("commit_animation_count", 0)) == 1, "factory commit animation starts exactly once")
		await create_timer(0.58).timeout
		var settled := factory.call("debug_snapshot") as Dictionary
		_expect(str(settled.get("lifecycle_state", "")) == "PRESENTED", "factory commit animation settles to PRESENTED")
		_expect(bool(settled.get("human_visible", false)), "settled factory remains human visible")
	for marker_variant in markers.values():
		var marker := marker_variant as Node
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
	await process_frame
	print("V076_FACILITY_VISUAL_MODEL_TEST|status=%s|checks=%d|models=%s|failures=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		JSON.stringify(models),
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)

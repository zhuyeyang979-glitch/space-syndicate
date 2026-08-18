extends SceneTree

const ResponsiveAcceptanceAudit := preload(
	"res://scripts/ui/v075/v075_responsive_acceptance_audit.gd"
)
const V075CardDefinitionRegistry := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)

var _checks := 0
var _failures: Array[String] = []
var _forced_overlap_detected := 0
var _invalid_resource_detected := 0
var _wrong_resource_type_detected := 0
var _viewport_mismatch_detected := 0
var _asset_lane_overlap_detected := 0
var _presentation_resource_paths := {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_geometry_negative_control()
	_test_asset_negative_controls()
	_test_viewport_negative_control()
	_test_combat_presentation_registry()
	_finish()


func _test_geometry_negative_control() -> void:
	var harness := Control.new()
	harness.name = "GeometryNegativeHarness"
	harness.custom_minimum_size = Vector2(200.0, 120.0)
	harness.size = Vector2(200.0, 120.0)
	root.add_child(harness)
	var left := ColorRect.new()
	left.name = "Left"
	left.position = Vector2(10.0, 10.0)
	left.size = Vector2(90.0, 60.0)
	harness.add_child(left)
	var right := ColorRect.new()
	right.name = "Right"
	right.position = Vector2(80.0, 20.0)
	right.size = Vector2(90.0, 60.0)
	harness.add_child(right)
	await process_frame
	var overlap_audit := ResponsiveAcceptanceAudit.audit_control_tree(harness)
	_forced_overlap_detected = int(
		overlap_audit.get("unintended_overlap_count", 0) > 0
	)
	_expect(
		_forced_overlap_detected == 1,
		"forced child overlap turns the geometry gate red"
	)
	right.position = Vector2(105.0, 20.0)
	await process_frame
	var clean_audit := ResponsiveAcceptanceAudit.audit_control_tree(harness)
	_expect(
		int(clean_audit.get("unintended_overlap_count", 1)) == 0,
		"non-overlapping sibling controls remain green"
	)
	_asset_lane_overlap_detected = ResponsiveAcceptanceAudit.rect_overlap_count(
		Rect2(Vector2(0.0, 0.0), Vector2(100.0, 50.0)),
		Rect2(Vector2(99.0, 10.0), Vector2(40.0, 20.0))
	)
	_expect(
		_asset_lane_overlap_detected == 1,
		"one-pixel combat/asset-lane intersection turns the gate red"
	)
	harness.queue_free()
	await process_frame


func _test_asset_negative_controls() -> void:
	var file_only := ResponsiveAcceptanceAudit.audit_resource_binding(
		"res://project.godot",
		null,
		"Texture2D"
	)
	_invalid_resource_detected = int(
		bool(file_only.get("file_exists", false))
		and int(file_only.get("failure_count", 0)) == 1
		and not bool(file_only.get("resource_loaded", true))
	)
	_expect(
		_invalid_resource_detected == 1,
		"an existing plain file cannot pass a ResourceLoader Texture2D gate"
	)
	var packed := load("res://scenes/main.tscn") as Resource
	var wrong_type := ResponsiveAcceptanceAudit.audit_resource_binding(
		"res://scenes/main.tscn",
		packed,
		"Texture2D"
	)
	_wrong_resource_type_detected = int(
		bool(wrong_type.get("file_exists", false))
		and bool(wrong_type.get("resource_loaded", false))
		and not bool(wrong_type.get("resource_type_green", true))
		and int(wrong_type.get("failure_count", 0)) == 1
	)
	_expect(
		_wrong_resource_type_detected == 1,
		"a loadable PackedScene cannot masquerade as a Texture2D"
	)


func _test_viewport_negative_control() -> void:
	var mismatch := ResponsiveAcceptanceAudit.audit_viewport_dimensions(
		Vector2i(1366, 768),
		Vector2i(1366, 768),
		Vector2i(1365, 768)
	)
	_viewport_mismatch_detected = int(
		int(mismatch.get("mismatch_count", 0)) == 1
	)
	_expect(
		_viewport_mismatch_detected == 1,
		"one-pixel captured viewport mismatch turns the visual gate red"
	)
	var exact := ResponsiveAcceptanceAudit.audit_viewport_dimensions(
		Vector2i(1920, 1080),
		Vector2i(1920, 1080),
		Vector2i(1920, 1080)
	)
	_expect(
		int(exact.get("mismatch_count", 1)) == 0,
		"exact requested/runtime/captured dimensions remain green"
	)


func _test_combat_presentation_registry() -> void:
	var card_types := (
		V075CardDefinitionRegistry.combat_presentation_card_types()
	)
	_expect(card_types.size() == 9, "presentation registry covers six monsters and three military types")
	for card_type in card_types:
		var definition_id := V075CardDefinitionRegistry.standard_definition_id(
			card_type,
			"life",
			1
		)
		var descriptor := V075CardDefinitionRegistry.presentation_descriptor(
			definition_id
		)
		var texture := V075CardDefinitionRegistry.presentation_texture(
			definition_id
		)
		var path := str(descriptor.get("resource_path", ""))
		var binding := ResponsiveAcceptanceAudit.audit_resource_binding(
			path,
			texture,
			"Texture2D"
		)
		_expect(
			V075CardDefinitionRegistry.presentation_descriptor_error(
				descriptor
			).is_empty()
				and int(binding.get("failure_count", 1)) == 0,
			"%s has a canonical loadable bound Texture2D" % card_type
		)
		_presentation_resource_paths[path] = card_type
	_expect(
		_presentation_resource_paths.size() == card_types.size(),
		"all nine combat card types have distinct presentation resources"
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V075_GEOMETRY_ASSET_FALSE_GREEN_NEGATIVE_TEST|%s" % JSON.stringify({
		"status": status,
		"checks": _checks,
		"failures": _failures,
		"forced_overlap_detected": _forced_overlap_detected,
		"invalid_resource_detected": _invalid_resource_detected,
		"wrong_resource_type_detected": _wrong_resource_type_detected,
		"viewport_mismatch_detected": _viewport_mismatch_detected,
		"asset_lane_overlap_detected": _asset_lane_overlap_detected,
		"distinct_combat_presentation_resource_count": (
			_presentation_resource_paths.size()
		),
	}))
	quit(0 if _failures.is_empty() else 1)

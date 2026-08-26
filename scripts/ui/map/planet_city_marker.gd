@tool
extends PanelContainer
class_name SpaceSyndicatePlanetCityMarker

signal facility_presentation_finished(
	receipt_id: String,
	evidence: Dictionary
)

const COMPACT_SIZE := Vector2(40.0, 40.0)
const DETAIL_SIZE := Vector2(92.0, 54.0)
const FACILITY_VISUAL_MODEL_KINDS := {
	"factory": "industrial_factory_silhouette",
	"market": "market_canopy_counter_silhouette",
	"warehouse": "warehouse_crate_bay_silhouette",
	"city": "city_core_silhouette",
}

@onready var tag_label: Label = %CityMarkerTagLabel
@onready var detail_rows: VBoxContainer = %CityMarkerDetailRows
@onready var level_label: Label = %CityMarkerLevelLabel
@onready var product_label: Label = %CityMarkerProductLabel

var _compact := true
var _facility_type := "city"
var _marker_id := ""
var _region_id := ""
var _facility_id := ""
var _slot_id := ""
var _visual_signature := ""
var _damage_points := 0
var _lifecycle_state := "PRESENTED"
var _commit_animation_count := 0
var _commit_animation_started_msec := -1
var _commit_animation_start_scale := Vector2.ONE
var _projection_tween: Tween
var _facility_presentation_tween: Tween
var _facility_presentation_active: Dictionary = {}
var _facility_presentation_queue: Array[Dictionary] = []
var _facility_presentation_fingerprints: Dictionary = {}
var _facility_presentation_finished_ids: Dictionary = {}
var _facility_presentation_evidence: Array[Dictionary] = []
var _facility_presentation_started_count := 0
var _facility_presentation_finished_count := 0
var _facility_presentation_duplicate_count := 0
var _facility_presentation_collision_count := 0
var _facility_presentation_rejection_count := 0
var _facility_presentation_sequence := 0
var _reduced_motion := false
var _instant_test_mode := false
var _screen_shake_enabled := true
var _facility_presentation_cue_counts := {
	"FACILITY_BUILD": 0,
	"FACILITY_UPGRADE": 0,
	"FACILITY_REPAIR": 0,
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	set_meta("mcp_sceneized_component", "PlanetCityMarker")
	queue_redraw()


func set_presentation_motion_policy(
	reduced_motion: bool,
	screen_shake_enabled: bool = true,
	instant_test_mode: bool = false
) -> void:
	_reduced_motion = reduced_motion
	_screen_shake_enabled = screen_shake_enabled
	_instant_test_mode = instant_test_mode


func presentation_motion_policy_snapshot() -> Dictionary:
	return {
		"schema": "V076FacilityMarkerMotionPolicyV1",
		"motion_mode": _motion_mode(),
		"reduced_motion": _reduced_motion,
		"instant_test_mode": _instant_test_mode,
		"screen_shake_enabled": (
			_screen_shake_enabled
			and not _reduced_motion
			and not _instant_test_mode
		),
		"production_ui_instant_test_mode_reachable": false,
	}


func configure(data: Dictionary) -> void:
	var next_type := str(data.get("facility_type", "city")).to_lower()
	var next_marker_id := str(data.get("marker_id", data.get("facility_id", data.get("slot_id", ""))))
	var next_damage := int(data.get("damage_points", 0))
	var next_signature := "%s|%s|%s|%s|%s|%s" % [
		next_marker_id,
		next_type,
		int(data.get("level", 1)),
		next_damage,
		int(data.get("damage_revision", 0)),
		bool(data.get("active", true)),
	]
	var lifecycle_changed := not _visual_signature.is_empty() and next_signature != _visual_signature
	var prior_damage := _damage_points
	_compact = bool(data.get("compact", true))
	_facility_type = next_type
	_marker_id = next_marker_id
	_region_id = str(data.get("region_id", ""))
	_facility_id = str(data.get("facility_id", ""))
	_slot_id = str(data.get("slot_id", ""))
	_damage_points = next_damage
	if _facility_presentation_active.is_empty():
		_lifecycle_state = "DAMAGED" if next_damage > 0 else "PRESENTED"
	var marker_size := COMPACT_SIZE if _compact else DETAIL_SIZE
	custom_minimum_size = marker_size
	size = marker_size
	position = _as_vector2(data.get("screen_position", Vector2.ZERO)) - marker_size * 0.5
	var stable_name := next_marker_id if not next_marker_id.is_empty() else str(data.get("tag", "city"))
	name = "PlanetCityMarker_%s" % stable_name.replace("/", "_").replace(":", "_")
	var tag_text := str(data.get("tag", "C"))
	var level := maxi(1, int(data.get("level", 1)))
	var products := _joined_strings(data.get("products", []))
	if tag_label != null:
		tag_label.text = tag_text.left(2)
		# The code-native silhouette is the primary facility identity.  Keep the
		# letter only as a secondary detail-mode badge; at overview scale it used
		# to cover nearly the entire factory/market/warehouse outline.
		tag_label.visible = not _compact or _facility_type == "city"
	if detail_rows != null:
		detail_rows.visible = not _compact
	if level_label != null:
		level_label.text = "L%d" % level
	if product_label != null:
		product_label.text = _short_text(products, 10)
	var type_label: String = str({"factory": "工厂", "market": "市场", "warehouse": "仓库"}.get(_facility_type, "城市"))
	var damage_label: String = "· 受损 %d" % next_damage if next_damage > 0 else "· 状态正常"
	tooltip_text = "%s · %s · L%d %s\n%s" % [type_label, tag_text, level, damage_label, products]
	_refresh_style(Color(str(data.get("accent", "#38bdf8"))), bool(data.get("active", true)))
	_visual_signature = next_signature
	queue_redraw()
	if lifecycle_changed and is_inside_tree():
		if _projection_tween != null and _projection_tween.is_valid():
			_projection_tween.kill()
		scale = (
			Vector2.ONE
			if _instant_test_mode
			else (
				Vector2(0.96, 0.96)
				if _reduced_motion
				else Vector2(0.82, 0.82)
			)
		)
		# Projection refreshes can arrive again while the globe is settling.  Keep
		# the marker above its own human-visible alpha contract throughout this
		# read-only lifecycle tween instead of briefly dimming a committed facility
		# below the 0.85 visibility floor.
		modulate = Color(1, 1, 1, 0.88)
		_projection_tween = create_tween()
		_projection_tween.set_parallel(true)
		var projection_duration := _motion_duration(0.42, 0.16)
		_projection_tween.tween_property(
			self, "scale", Vector2.ONE, projection_duration
		)
		_projection_tween.tween_property(
			self, "modulate", Color.WHITE, projection_duration
		)
	elif prior_damage > 0 and next_damage <= 0 and is_inside_tree():
		if _projection_tween != null and _projection_tween.is_valid():
			_projection_tween.kill()
		modulate = Color("#a7f3d0")
		_projection_tween = create_tween()
		_projection_tween.tween_property(
			self,
			"modulate",
			Color.WHITE,
			_motion_duration(0.42, 0.16)
		)


func update_projection(
	screen_position: Variant,
	compact_mode: bool,
	marker_data: Dictionary = {}
) -> bool:
	if compact_mode != _compact:
		return false
	if not marker_data.is_empty():
		var next_signature := "%s|%s|%s|%s|%s|%s" % [
			str(marker_data.get("marker_id", marker_data.get("facility_id", marker_data.get("slot_id", "")))),
			str(marker_data.get("facility_type", "city")).to_lower(),
			int(marker_data.get("level", 1)),
			int(marker_data.get("damage_points", 0)),
			int(marker_data.get("damage_revision", 0)),
			bool(marker_data.get("active", true)),
		]
		if next_signature != _visual_signature:
			marker_data["screen_position"] = _as_vector2(screen_position)
			configure(marker_data)
			return true
	var marker_size := size
	if marker_size.x <= 0.0 or marker_size.y <= 0.0:
		marker_size = custom_minimum_size
	position = _as_vector2(screen_position) - marker_size * 0.5
	return true


func play_commit_animation() -> void:
	"""Presentation-only build cue for an already-authoritative marker."""
	_facility_presentation_sequence += 1
	play_facility_presentation(
		"FACILITY_BUILD",
		"legacy.marker.commit.%d" % _facility_presentation_sequence
	)


func play_facility_presentation(cue_id: String, receipt_id: String) -> Dictionary:
	"""Queue a typed visual cue for an already-authoritative facility marker."""
	var normalized_cue := cue_id.strip_edges().to_upper()
	var normalized_receipt := receipt_id.strip_edges()
	if (
		normalized_receipt.is_empty()
		or not _facility_presentation_cue_counts.has(normalized_cue)
	):
		_facility_presentation_rejection_count += 1
		return {
			"accepted": false,
			"reason_code": "facility_presentation_contract_invalid",
		}
	var fingerprint := "|".join([
		normalized_receipt,
		normalized_cue,
		_marker_id,
		_slot_id,
		_region_id,
	]).sha256_text()
	if _facility_presentation_fingerprints.has(normalized_receipt):
		if str(_facility_presentation_fingerprints.get(
			normalized_receipt,
			""
		)) == fingerprint:
			_facility_presentation_duplicate_count += 1
			return {
				"accepted": false,
				"reason_code": "facility_presentation_duplicate",
				"duplicate": true,
			}
		_facility_presentation_collision_count += 1
		return {
			"accepted": false,
			"reason_code": "facility_presentation_identity_collision",
			"collision": true,
		}
	_facility_presentation_fingerprints[normalized_receipt] = fingerprint
	_facility_presentation_queue.append({
		"receipt_id": normalized_receipt,
		"cue_id": normalized_cue,
		"fingerprint": fingerprint,
	})
	if _facility_presentation_active.is_empty():
		_start_next_facility_presentation()
	return {
		"accepted": true,
		"reason_code": "none",
		"receipt_id": normalized_receipt,
		"cue_id": normalized_cue,
		"queued": true,
	}


func _start_next_facility_presentation() -> void:
	if (
		not _facility_presentation_active.is_empty()
		or _facility_presentation_queue.is_empty()
	):
		return
	var presentation := _facility_presentation_queue.pop_front() as Dictionary
	var receipt_id := str(presentation.get("receipt_id", ""))
	var cue_id := str(presentation.get("cue_id", ""))
	if receipt_id.is_empty() or not _facility_presentation_cue_counts.has(cue_id):
		_facility_presentation_rejection_count += 1
		call_deferred("_start_next_facility_presentation")
		return
	if _projection_tween != null and _projection_tween.is_valid():
		_projection_tween.kill()
	if _facility_presentation_tween != null \
			and _facility_presentation_tween.is_valid():
		_facility_presentation_tween.kill()
	pivot_offset = size * 0.5
	scale = Vector2.ONE
	modulate = Color.WHITE
	var state := {
		"FACILITY_BUILD": "BUILDING",
		"FACILITY_UPGRADE": "UPGRADING",
		"FACILITY_REPAIR": "REPAIRING",
	}.get(cue_id, "PRESENTING") as String
	var start_scale := {
		"FACILITY_BUILD": Vector2(0.62, 0.62),
		"FACILITY_UPGRADE": Vector2(0.90, 0.90),
		"FACILITY_REPAIR": Vector2(0.70, 0.70),
	}.get(cue_id, Vector2.ONE) as Vector2
	var mid_scale := {
		"FACILITY_BUILD": Vector2(0.88, 0.88),
		"FACILITY_UPGRADE": Vector2(1.12, 1.12),
		"FACILITY_REPAIR": Vector2(0.92, 0.92),
	}.get(cue_id, Vector2.ONE) as Vector2
	var start_modulate := {
		"FACILITY_BUILD": Color(1.0, 1.0, 1.0, 0.0),
		"FACILITY_UPGRADE": Color(1.0, 0.86, 0.38, 0.78),
		"FACILITY_REPAIR": Color(0.42, 1.0, 0.70, 0.62),
	}.get(cue_id, Color.WHITE) as Color
	var mid_modulate := {
		"FACILITY_BUILD": Color(1.0, 1.0, 1.0, 0.82),
		"FACILITY_UPGRADE": Color(1.0, 0.94, 0.62, 1.0),
		"FACILITY_REPAIR": Color(0.68, 1.0, 0.82, 0.92),
	}.get(cue_id, Color.WHITE) as Color
	if _reduced_motion:
		start_scale = Vector2(0.96, 0.96)
		mid_scale = Vector2(0.99, 0.99)
		start_modulate.a = maxf(0.72, start_modulate.a)
		mid_modulate.a = maxf(0.90, mid_modulate.a)
	if _instant_test_mode:
		start_scale = Vector2.ONE
		mid_scale = Vector2.ONE
		start_modulate = Color.WHITE
		mid_modulate = Color.WHITE
	_lifecycle_state = state
	_commit_animation_started_msec = Time.get_ticks_msec()
	_commit_animation_start_scale = start_scale
	if cue_id == "FACILITY_BUILD":
		_commit_animation_count += 1
	_facility_presentation_cue_counts[cue_id] = int(
		_facility_presentation_cue_counts.get(cue_id, 0)
	) + 1
	_facility_presentation_started_count += 1
	visible = true
	scale = start_scale
	modulate = start_modulate
	var evidence := {
		"schema": "V076FacilityMarkerPresentationEvidenceV1",
		"presentation_only": true,
		"public_only": true,
		"receipt_id": receipt_id,
		"cue_id": cue_id,
		"facility_action_mode": _facility_mode_for_cue(cue_id),
		"marker_id": _marker_id,
		"facility_id": _facility_id,
		"slot_id": _slot_id,
		"region_id": _region_id,
		"facility_type": _facility_type,
		"start_rect": _transformed_global_rect(),
		"mid_rect": Rect2(),
		"end_rect": Rect2(),
		"started_msec": _commit_animation_started_msec,
		"motion_mode": _motion_mode(),
		"gameplay_mutation_count": 0,
		"rng_draw_delta": 0,
		"authority_sequence_delta": 0,
		"facility_state_mutation_count": 0,
	}
	presentation["evidence"] = evidence
	_facility_presentation_active = presentation
	var duration := _motion_duration(0.52, 0.18)
	_facility_presentation_tween = create_tween()
	_facility_presentation_tween.set_trans(Tween.TRANS_BACK)
	_facility_presentation_tween.set_ease(Tween.EASE_OUT)
	_facility_presentation_tween.tween_property(
		self,
		"scale",
		mid_scale,
		duration * 0.48
	)
	_facility_presentation_tween.parallel().tween_property(
		self,
		"modulate",
		mid_modulate,
		duration * 0.48
	)
	_facility_presentation_tween.tween_callback(
		Callable(self, "_capture_facility_presentation_mid_rect").bind(
			receipt_id
		)
	)
	_facility_presentation_tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		duration * 0.52
	)
	_facility_presentation_tween.parallel().tween_property(
		self,
		"modulate",
		Color.WHITE,
		duration * 0.52
	)
	_facility_presentation_tween.tween_callback(
		Callable(self, "_complete_facility_presentation").bind(receipt_id)
	)
	queue_redraw()


func _capture_facility_presentation_mid_rect(receipt_id: String) -> void:
	if str(_facility_presentation_active.get("receipt_id", "")) != receipt_id:
		return
	var evidence := (
		_facility_presentation_active.get("evidence", {}) as Dictionary
	).duplicate(true)
	evidence["mid_rect"] = _transformed_global_rect()
	_facility_presentation_active["evidence"] = evidence


func _complete_facility_presentation(receipt_id: String) -> void:
	if _facility_presentation_finished_ids.has(receipt_id):
		_facility_presentation_duplicate_count += 1
		return
	if str(_facility_presentation_active.get("receipt_id", "")) != receipt_id:
		return
	scale = Vector2.ONE
	modulate = Color.WHITE
	_lifecycle_state = "PRESENTED"
	var evidence := (
		_facility_presentation_active.get("evidence", {}) as Dictionary
	).duplicate(true)
	var end_rect := _transformed_global_rect()
	if not (evidence.get("mid_rect", Rect2()) as Rect2).has_area():
		evidence["mid_rect"] = end_rect
	evidence["end_rect"] = end_rect
	evidence["completed_msec"] = Time.get_ticks_msec()
	evidence["rects_complete"] = (
		(evidence.get("start_rect", Rect2()) as Rect2).has_area()
		and (evidence.get("mid_rect", Rect2()) as Rect2).has_area()
		and end_rect.has_area()
	)
	_facility_presentation_finished_ids[receipt_id] = str(
		_facility_presentation_active.get("fingerprint", "")
	)
	_facility_presentation_finished_count += 1
	_facility_presentation_evidence.append(evidence.duplicate(true))
	while _facility_presentation_evidence.size() > 32:
		_facility_presentation_evidence.pop_front()
	_facility_presentation_active = {}
	_facility_presentation_tween = null
	queue_redraw()
	facility_presentation_finished.emit(receipt_id, evidence.duplicate(true))
	call_deferred("_start_next_facility_presentation")


func _facility_mode_for_cue(cue_id: String) -> String:
	return {
		"FACILITY_BUILD": "BUILD_NEW",
		"FACILITY_UPGRADE": "UPGRADE_OWN",
		"FACILITY_REPAIR": "REPAIR_OWN",
	}.get(cue_id, "") as String


func _transformed_global_rect() -> Rect2:
	var transform := get_global_transform_with_canvas()
	var corners: Array[Vector2] = [
		transform * Vector2.ZERO,
		transform * Vector2(size.x, 0.0),
		transform * size,
		transform * Vector2(0.0, size.y),
	]
	var minimum := corners[0]
	var maximum := corners[0]
	for corner in corners:
		minimum = Vector2(
			minf(minimum.x, corner.x),
			minf(minimum.y, corner.y)
		)
		maximum = Vector2(
			maxf(maximum.x, corner.x),
			maxf(maximum.y, corner.y)
		)
	return Rect2(minimum, maximum - minimum)


func debug_snapshot() -> Dictionary:
	var rect := _transformed_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var alpha := modulate.a * self_modulate.a
	var minimum_px := 24.0 if _compact else 36.0
	var silhouette_primitive_count := int({
		"factory": 4,
		"market": 4,
		"warehouse": 4,
	}.get(_facility_type, 1))
	var geometry_visible := (
		is_visible_in_tree()
		and rect.has_area()
		and rect.intersects(viewport_rect)
		and minf(rect.size.x, rect.size.y) >= minimum_px
		and alpha >= 0.85
		and not clip_contents
	)
	return {
		"kind": "facility",
		"facility_type": _facility_type,
		"marker_id": _marker_id,
		"region_id": _region_id,
		"facility_id": _facility_id,
		"slot_id": _slot_id,
		"shape_kind": _facility_type,
		"visual_model_kind": str(FACILITY_VISUAL_MODEL_KINDS.get(
			_facility_type,
			"city_core_silhouette"
		)),
		"primary_visual_letter_only": false,
		"primary_visual_silhouette": true,
		"silhouette_primitive_count": silhouette_primitive_count,
		"tag_label_visible": tag_label.visible if tag_label != null else false,
		"damage_points": _damage_points,
		"lifecycle_state": _lifecycle_state,
		"commit_animation_count": _commit_animation_count,
		"commit_animation_active": _lifecycle_state == "BUILDING",
		"commit_animation_started_msec": _commit_animation_started_msec,
		"commit_animation_start_scale": _commit_animation_start_scale,
		"facility_presentation_active_receipt_id": str(
			_facility_presentation_active.get("receipt_id", "")
		),
		"facility_presentation_pending_count": (
			_facility_presentation_queue.size()
		),
		"facility_presentation_started_count": (
			_facility_presentation_started_count
		),
		"facility_presentation_finished_count": (
			_facility_presentation_finished_count
		),
		"facility_presentation_duplicate_count": (
			_facility_presentation_duplicate_count
		),
		"facility_presentation_collision_count": (
			_facility_presentation_collision_count
		),
		"facility_presentation_rejection_count": (
			_facility_presentation_rejection_count
		),
		"facility_presentation_cue_counts": (
			_facility_presentation_cue_counts.duplicate(true)
		),
		"facility_presentation_evidence": (
			_facility_presentation_evidence.duplicate(true)
		),
		"presentation_motion_policy": (
			presentation_motion_policy_snapshot()
		),
		"presentation_gameplay_mutation_count": 0,
		"presentation_rng_draw_delta": 0,
		"presentation_authority_sequence_delta": 0,
		"presentation_facility_state_mutation_count": 0,
		"tag": tag_label.text if tag_label != null else "",
		"compact": _compact,
		"detail_visible": detail_rows.visible if detail_rows != null else false,
		"global_rect": rect,
		"viewport_rect": viewport_rect,
		"alpha": alpha,
		"clip_contents": clip_contents,
		"minimum_visual_px": minimum_px,
		"inside_viewport": rect.intersects(viewport_rect),
		"human_visible": geometry_visible,
	}


func _motion_mode() -> String:
	if _instant_test_mode:
		return "INSTANT_TEST_MODE"
	return "REDUCED_MOTION" if _reduced_motion else "FULL_MOTION"


func _motion_duration(full_seconds: float, reduced_seconds: float) -> float:
	if _instant_test_mode:
		return 0.0
	return reduced_seconds if _reduced_motion else full_seconds


func _draw() -> void:
	# Small code-native silhouettes keep the existing marker identity and avoid a
	# second facility state/asset owner.  The letter remains a secondary label.
	var center := size * 0.5
	var accent := Color("#f59e0b")
	match _facility_type:
		"factory":
			accent = Color("#f97316")
			draw_rect(Rect2(center + Vector2(-9, -4), Vector2(18, 13)), accent, false, 2.0)
			draw_line(center + Vector2(-5, -4), center + Vector2(-5, -13), accent, 2.0)
			draw_line(center + Vector2(1, -4), center + Vector2(1, -16), accent, 2.0)
			draw_circle(center + Vector2(7, 5), 3.0, accent)
		"market":
			accent = Color("#facc15")
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-12, -4), center + Vector2(0, -14),
				center + Vector2(12, -4), center + Vector2(9, 8),
				center + Vector2(-9, 8),
			]), accent.darkened(0.2))
			draw_line(center + Vector2(-12, -4), center + Vector2(12, -4), accent, 2.0)
			draw_line(center + Vector2(-5, -3), center + Vector2(-5, 8), accent, 2.0)
			draw_line(center + Vector2(5, -3), center + Vector2(5, 8), accent, 2.0)
		"warehouse":
			accent = Color("#60a5fa")
			draw_rect(Rect2(center + Vector2(-11, -8), Vector2(22, 18)), accent.darkened(0.25), true)
			draw_rect(Rect2(center + Vector2(-11, -8), Vector2(22, 18)), accent, false, 2.0)
			draw_line(center + Vector2(-7, -3), center + Vector2(7, -3), accent, 2.0)
			draw_line(center + Vector2(-7, 3), center + Vector2(7, 3), accent, 2.0)
		_:
			draw_circle(center, 9.0, Color("#38bdf8"))
	if _damage_points > 0:
		draw_line(center + Vector2(-10, -10), center + Vector2(10, 10), Color("#ef4444"), 2.0)
		draw_line(center + Vector2(10, -10), center + Vector2(-10, 10), Color("#ef4444"), 2.0)


func _refresh_style(accent: Color, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#082f49", 0.88) if active else Color("#1e293b", 0.80)
	style.border_color = accent if active else Color("#64748b", 0.72)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	var margin := 3.0 if _compact else 5.0
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	add_theme_stylebox_override("panel", style)


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	return Vector2.ZERO


func _joined_strings(value: Variant) -> String:
	var result := PackedStringArray()
	if value is Array:
		for item in value:
			result.append(str(item))
	return " / ".join(result)


func _short_text(value: String, max_chars: int) -> String:
	if value.length() <= max_chars:
		return value
	return value.substr(0, maxi(0, max_chars - 3)) + "..."

extends Control
class_name SpaceSyndicateCardIllustrationLayer

const DEFAULT_ILLUSTRATION_CATALOG: CardIllustrationCatalogResource = preload("res://resources/presentation/alpha01_card_illustration_catalog.tres")

@export var illustration_catalog: CardIllustrationCatalogResource = DEFAULT_ILLUSTRATION_CATALOG

@onready var source_texture: TextureRect = %SourceTexture
@onready var treatment_overlay: Control = %TreatmentOverlay

var _accent := Color("#38bdf8")
var _profile: Dictionary = {}
var _presentation_key := StringName()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if source_texture.material != null:
		source_texture.material = source_texture.material.duplicate()
	_apply_profile()


func set_illustration(texture: Texture2D, accent: Color, profile: Dictionary) -> void:
	_accent = accent
	_profile = profile.duplicate(true)
	source_texture.texture = texture
	visible = texture != null
	_apply_profile()
	queue_redraw()


func set_illustration_key(presentation_key: StringName, accent: Color) -> bool:
	if illustration_catalog == null:
		clear_illustration()
		return false
	var texture := illustration_catalog.texture_for_key(presentation_key)
	if texture == null:
		clear_illustration()
		return false
	_presentation_key = presentation_key
	set_illustration(texture, accent, illustration_catalog.presentation_profile_for_key(presentation_key))
	return true


func is_authored_key(presentation_key: StringName) -> bool:
	return illustration_catalog != null and illustration_catalog.is_authored_key(presentation_key)


func clear_illustration() -> void:
	_presentation_key = StringName()
	_profile.clear()
	if is_instance_valid(source_texture):
		source_texture.texture = null
	visible = false
	queue_redraw()


func get_debug_snapshot() -> Dictionary:
	var texture_size := Vector2i.ZERO
	var overlay_snapshot := {}
	if source_texture != null and source_texture.texture != null:
		texture_size = Vector2i(source_texture.texture.get_size())
	if treatment_overlay != null and treatment_overlay.has_method("get_debug_snapshot"):
		overlay_snapshot = treatment_overlay.call("get_debug_snapshot") as Dictionary
	return {
		"active": visible and source_texture != null and source_texture.texture != null,
		"presentation_key": str(_presentation_key),
		"source_type": str(_profile.get("source_type", "")),
		"visual_source_id": str(_profile.get("visual_source_id", "")),
		"fit_mode": str(_profile.get("fit_mode", "cover")),
		"tint_mode": str(_profile.get("tint_mode", "preserve")),
		"semantic_motif": str(_profile.get("semantic_motif", "")),
		"resolved_motif": str(overlay_snapshot.get("resolved_motif", "")),
		"overlay_intensity": float(overlay_snapshot.get("intensity", 0.0)),
		"texture_size": texture_size,
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_source_texture()
		queue_redraw()


func _apply_profile() -> void:
	if not is_node_ready():
		return
	var fit_mode := str(_profile.get("fit_mode", "cover")).strip_edges().to_lower()
	source_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if fit_mode == "contain" else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var filter_mode := str(_profile.get("texture_filter", "linear")).strip_edges().to_lower()
	source_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if filter_mode == "nearest" else CanvasItem.TEXTURE_FILTER_LINEAR
	var tint_mode := str(_profile.get("tint_mode", "preserve")).strip_edges().to_lower()
	var shader_material := source_texture.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("tint_mode", 1 if tint_mode == "accent_monochrome" else 0)
		shader_material.set_shader_parameter("accent_color", _accent.lightened(0.26))
		shader_material.set_shader_parameter("shadow_color", Color("#020611").lerp(_accent.darkened(0.68), 0.18))
		shader_material.set_shader_parameter("authored_grade", 0.035 if str(_profile.get("source_type", "")) == "authored" else 0.07)
	var motif := str(_profile.get("semantic_motif", ""))
	var intensity := float(_profile.get("overlay_intensity", 0.4))
	if treatment_overlay.has_method("configure"):
		treatment_overlay.call("configure", _accent, motif, intensity)
	_layout_source_texture()


func _layout_source_texture() -> void:
	if source_texture == null:
		return
	source_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	source_texture.offset_top = 0.0
	source_texture.offset_bottom = 0.0
	source_texture.offset_left = 0.0
	source_texture.offset_right = 0.0
	var layout_variant := str(_profile.get("layout_variant", "")).strip_edges().to_lower()
	if layout_variant.begins_with("left_anchor"):
		source_texture.offset_right = -size.x * 0.16
	elif layout_variant.begins_with("right_anchor"):
		source_texture.offset_left = size.x * 0.16


func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var base := Color("#020611").lerp(_accent.darkened(0.58), 0.22)
	draw_rect(rect, base, true)
	for index in range(7):
		var t := float(index) / 6.0
		var band := _accent.darkened(0.28)
		band.a = 0.018 + t * 0.015
		draw_rect(Rect2(0.0, size.y * t, size.x, size.y / 6.0 + 1.0), band, true)
	var flare := _accent.lightened(0.18)
	flare.a = 0.08
	draw_circle(Vector2(size.x * 0.18, size.y * 0.22), size.y * 0.42, flare)
	flare.a = 0.045
	draw_circle(Vector2(size.x * 0.86, size.y * 0.72), size.y * 0.52, flare)
	var rail := _accent.darkened(0.22)
	rail.a = 0.18
	draw_line(Vector2(0.0, size.y * 0.12), Vector2(size.x, size.y * 0.12), rail, 1.0)
	draw_line(Vector2(0.0, size.y * 0.88), Vector2(size.x, size.y * 0.88), rail, 1.0)

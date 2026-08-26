extends PanelContainer
class_name SpaceSyndicateCommercialSettingsSurface

## Presentation-only settings surface.  It persists no gameplay state and does
## not own the simulation clock, RNG, rules, or save data.  Animation and UI
## consumers may read the exported snapshot after the user applies a choice.

signal settings_changed(snapshot: Dictionary)

const WINDOW_MODES := ["windowed", "fullscreen"]
const RESOLUTIONS := ["1366x768", "1600x960", "1920x1080"]
const LANGUAGES := ["zh-Hans", "en"]
const DEFAULT_SETTINGS := {
	"master_volume": 1.0,
	"music_volume": 0.75,
	"sfx_volume": 0.85,
	"window_mode": "windowed",
	"resolution": "1600x960",
	"language": "zh-Hans",
	"reduced_motion": false,
	"screen_shake": true,
	"tooltip_delay_ms": 420,
}

@onready var master_volume: HSlider = %MasterVolume
@onready var music_volume: HSlider = %MusicVolume
@onready var sfx_volume: HSlider = %SfxVolume
@onready var window_mode: OptionButton = %WindowMode
@onready var resolution: OptionButton = %Resolution
@onready var language: OptionButton = %Language
@onready var reduced_motion: CheckButton = %ReducedMotion
@onready var screen_shake: CheckButton = %ScreenShake
@onready var tooltip_delay: HSlider = %TooltipDelay
@onready var status_label: Label = %SettingsStatus
@onready var apply_button: Button = %ApplySettingsButton

var _apply_count := 0
var _loaded_snapshot_count := 0
var _rejected_snapshot_count := 0
var _snapshot: Dictionary = DEFAULT_SETTINGS.duplicate(true)


func _ready() -> void:
	_populate_options()
	_apply_snapshot_to_controls()
	if not apply_button.pressed.is_connected(_on_apply_pressed):
		apply_button.pressed.connect(_on_apply_pressed)
	set_meta("presentation_only", true)


func debug_snapshot() -> Dictionary:
	return {
		"surface_id": "commercial_settings_surface_v1",
		"presentation_only": true,
		"apply_count": _apply_count,
		"loaded_snapshot_count": _loaded_snapshot_count,
		"rejected_snapshot_count": _rejected_snapshot_count,
		"settings": _snapshot.duplicate(true),
		"settings_field_count": _snapshot.size(),
		"instant_test_mode_production_ui_reachable": false,
		"owns_gameplay_state": false,
		"owns_tick": false,
		"owns_rng": false,
		"owns_save_data": false,
	}


func settings_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func load_settings_snapshot(snapshot: Dictionary) -> Dictionary:
	"""Load the MenuLifecycle session snapshot into this editable view.

	The surface never becomes the session owner.  It accepts only the production
	presentation whitelist and never exposes the test-only instant-motion flag.
	"""
	if snapshot.has("instant_test_mode"):
		_rejected_snapshot_count += 1
		return {
			"accepted": false,
			"reason_code": "instant_test_mode_production_unreachable",
			"snapshot": _snapshot.duplicate(true),
		}
	_snapshot = _normalized_settings_snapshot(snapshot, _snapshot)
	_loaded_snapshot_count += 1
	if is_node_ready():
		_apply_snapshot_to_controls()
	return {
		"accepted": true,
		"reason_code": "presentation_settings_loaded",
		"snapshot": _snapshot.duplicate(true),
	}


func _populate_options() -> void:
	window_mode.clear()
	window_mode.add_item("窗口化")
	window_mode.set_item_metadata(0, "windowed")
	window_mode.add_item("全屏")
	window_mode.set_item_metadata(1, "fullscreen")
	resolution.clear()
	for value in RESOLUTIONS:
		resolution.add_item(value)
		resolution.set_item_metadata(resolution.item_count - 1, value)
	language.clear()
	language.add_item("简体中文")
	language.set_item_metadata(0, "zh-Hans")
	language.add_item("English")
	language.set_item_metadata(1, "en")


func _apply_snapshot_to_controls() -> void:
	master_volume.value = float(_snapshot.get("master_volume", 1.0)) * 100.0
	music_volume.value = float(_snapshot.get("music_volume", 0.75)) * 100.0
	sfx_volume.value = float(_snapshot.get("sfx_volume", 0.85)) * 100.0
	reduced_motion.button_pressed = bool(_snapshot.get("reduced_motion", false))
	screen_shake.button_pressed = bool(_snapshot.get("screen_shake", true))
	tooltip_delay.value = float(_snapshot.get("tooltip_delay_ms", 420))
	_select_metadata(window_mode, str(_snapshot.get("window_mode", "windowed")))
	_select_metadata(resolution, str(_snapshot.get("resolution", "1600x960")))
	_select_metadata(language, str(_snapshot.get("language", "zh-Hans")))


func _select_metadata(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == value:
			option.select(index)
			return


func _on_apply_pressed() -> void:
	_snapshot = {
		"master_volume": clampf(float(master_volume.value) / 100.0, 0.0, 1.0),
		"music_volume": clampf(float(music_volume.value) / 100.0, 0.0, 1.0),
		"sfx_volume": clampf(float(sfx_volume.value) / 100.0, 0.0, 1.0),
		"window_mode": str(window_mode.get_selected_metadata()),
		"resolution": str(resolution.get_selected_metadata()),
		"language": str(language.get_selected_metadata()),
		"reduced_motion": reduced_motion.button_pressed,
		"screen_shake": screen_shake.button_pressed,
		"tooltip_delay_ms": int(tooltip_delay.value),
	}
	_apply_audio_snapshot()
	_apply_window_snapshot()
	_apply_count += 1
	status_label.text = "设置已应用（仅影响呈现与输入反馈）"
	settings_changed.emit(_snapshot.duplicate(true))


func _normalized_settings_snapshot(
	source: Dictionary,
	fallback: Dictionary
) -> Dictionary:
	var normalized := DEFAULT_SETTINGS.duplicate(true)
	for key_variant in DEFAULT_SETTINGS.keys():
		var key := str(key_variant)
		if fallback.has(key):
			normalized[key] = fallback.get(key)
	normalized["master_volume"] = _normalized_float_setting(
		source,
		"master_volume",
		float(normalized.get("master_volume", 1.0))
	)
	normalized["music_volume"] = _normalized_float_setting(
		source,
		"music_volume",
		float(normalized.get("music_volume", 0.75))
	)
	normalized["sfx_volume"] = _normalized_float_setting(
		source,
		"sfx_volume",
		float(normalized.get("sfx_volume", 0.85))
	)
	normalized["window_mode"] = _normalized_string_setting(
		source,
		"window_mode",
		str(normalized.get("window_mode", "windowed")),
		WINDOW_MODES
	)
	normalized["resolution"] = _normalized_string_setting(
		source,
		"resolution",
		str(normalized.get("resolution", "1600x960")),
		RESOLUTIONS
	)
	normalized["language"] = _normalized_string_setting(
		source,
		"language",
		str(normalized.get("language", "zh-Hans")),
		LANGUAGES
	)
	normalized["reduced_motion"] = _normalized_bool_setting(
		source,
		"reduced_motion",
		bool(normalized.get("reduced_motion", false))
	)
	normalized["screen_shake"] = _normalized_bool_setting(
		source,
		"screen_shake",
		bool(normalized.get("screen_shake", true))
	)
	var tooltip_value: Variant = source.get(
		"tooltip_delay_ms",
		source.get("tooltip_delay", normalized.get("tooltip_delay_ms", 420))
	)
	if typeof(tooltip_value) in [TYPE_INT, TYPE_FLOAT]:
		normalized["tooltip_delay_ms"] = clampi(
			int(tooltip_value),
			0,
			1200
		)
	return normalized


func _normalized_float_setting(
	source: Dictionary,
	key: String,
	fallback: float
) -> float:
	var value: Variant = source.get(key, fallback)
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	return clampf(float(value), 0.0, 1.0)


func _normalized_bool_setting(
	source: Dictionary,
	key: String,
	fallback: bool
) -> bool:
	var value: Variant = source.get(key, fallback)
	return bool(value) if typeof(value) == TYPE_BOOL else fallback


func _normalized_string_setting(
	source: Dictionary,
	key: String,
	fallback: String,
	allowed: Array
) -> String:
	var value: Variant = source.get(key, fallback)
	if typeof(value) != TYPE_STRING:
		return fallback
	var normalized := str(value)
	return normalized if allowed.has(normalized) else fallback


func _apply_audio_snapshot() -> void:
	for bus_name in ["Master", "Music", "SFX"]:
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0:
			continue
		var key := "%s_volume" % bus_name.to_lower()
		var linear := clampf(float(_snapshot.get(key, 1.0)), 0.0, 1.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


func _apply_window_snapshot() -> void:
	var mode := str(_snapshot.get("window_mode", "windowed"))
	if mode == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size_text := str(_snapshot.get("resolution", "1600x960"))
		var parts := size_text.split("x")
		if parts.size() == 2:
			DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))

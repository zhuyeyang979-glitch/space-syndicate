extends "res://scripts/ui/v073/v073_sample_card_button.gd"
class_name V074TrackCardButton

const TRACK_HOVER_SCALE := Vector2(1.025, 1.025)

var _track_hover_tween: Tween


func _init() -> void:
	super._init()
	custom_minimum_size = Vector2(96.0, 106.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _animate_scale(target: Vector2) -> void:
	if _track_hover_tween != null and _track_hover_tween.is_valid():
		_track_hover_tween.kill()
	var resolved := (
		Vector2.ONE
		if target == Vector2.ONE
		else TRACK_HOVER_SCALE
	)
	_track_hover_tween = create_tween()
	_track_hover_tween.set_trans(Tween.TRANS_QUAD)
	_track_hover_tween.set_ease(Tween.EASE_OUT)
	_track_hover_tween.tween_property(self, "scale", resolved, 0.1)

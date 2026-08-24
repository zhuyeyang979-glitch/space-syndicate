extends SpaceSyndicateCardResolutionTrack
class_name V075PublicActionArrangement

signal public_entry_hovered(entry: Dictionary)
signal card_drop_requested(payload: Dictionary)

var _last_public_signature := ""
var _arrangement_update_count := 0
var _arrangement_animation_count := 0
var _last_public_entry_count := 0
var _last_public_phase := ""


func apply_public_arrangement(
	entries: Array,
	phase_text: String,
	summary_text: String,
	privacy_text := "匿名牌只显示公开状态；归属公开后才显示名称。"
) -> void:
	var state := {
		"title": "中央公开排列",
		"phase": phase_text,
		"summary": summary_text,
		"entries": entries,
		"privacy_hint": privacy_text,
		"empty_text": "等待玩家出牌 · 牌会在这里形成排列",
	}
	var signature := var_to_str(state)
	if signature == _last_public_signature:
		return
	var had_content := not _last_public_signature.is_empty()
	_last_public_signature = signature
	_arrangement_update_count += 1
	_last_public_entry_count = entries.size()
	_last_public_phase = phase_text
	set_track_state(state)
	if had_content and is_inside_tree():
		_arrangement_animation_count += 1
		modulate = Color(0.72, 0.86, 1.0, 0.82)
		scale = Vector2(0.985, 0.985)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "modulate", Color.WHITE, 0.20)
		tween.tween_property(self, "scale", Vector2.ONE, 0.20)


func clear_public_arrangement() -> void:
	apply_public_arrangement([], "等待提交", "30 秒内提交的行动会在中央排列。")


func arrangement_debug_snapshot() -> Dictionary:
	var base := get_debug_snapshot()
	base.merge({
		"arrangement_update_count": _arrangement_update_count,
		"arrangement_animation_count": _arrangement_animation_count,
		"last_public_entry_count": _last_public_entry_count,
		"last_public_phase": _last_public_phase,
		"public_presentation_gameplay_mutation_count": 0,
		"public_presentation_rng_draw_delta": 0,
	}, true)
	return base


func _on_slot_hovered(entry: Dictionary) -> void:
	super._on_slot_hovered(entry)
	public_entry_hovered.emit(entry.duplicate(true))


# The arrangement is a presentation target only.  A card drop is forwarded to
# the V075 screen, which resolves the payload against its current legal-action
# projection and emits the existing `card.queue` intent.  This node never
# edits a hand, queue, asset pool, RNG stream, or batch order.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var envelope := data as Dictionary
	if str(envelope.get("drag_type", "")) != "v073_card":
		return false
	return envelope.get("payload", {}) is Dictionary \
		and not (envelope.get("payload", {}) as Dictionary).is_empty()


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var envelope := data as Dictionary
	card_drop_requested.emit(
		(envelope.get("payload", {}) as Dictionary).duplicate(true)
	)

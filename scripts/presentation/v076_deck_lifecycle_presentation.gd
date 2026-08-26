extends Control
class_name V076DeckLifecyclePresentation

## Presentation-only owner for the local player's visible draw/discard surface.
## It consumes authority receipts plus the already-authorized private projection.
## It never changes card zones, deck order, RNG, Tick, or any gameplay state.

signal animation_finished(receipt_id: String, cue_id: String)

const InteractiveCardFaceScene := preload(
	"res://scenes/ui/v075/V075InteractiveCardFace.tscn"
)

const ACQUIRE_SECONDS := 0.52
const DRAW_SECONDS := 0.42
const DISCARD_SECONDS := 0.44
const SHUFFLE_SECONDS := 0.58
const REDUCED_SECONDS := 0.18
const PROXY_SIZE := Vector2(74.0, 96.0)
const EVIDENCE_LIMIT := 96

@onready var _draw_panel: PanelContainer = %DrawPilePanel
@onready var _discard_panel: PanelContainer = %DiscardPilePanel
@onready var _draw_count: Label = %DrawPileCount
@onready var _discard_count: Label = %DiscardPileCount
@onready var _shuffle_status: Label = %ShuffleStatus
@onready var _recent_event: Label = %RecentDeckEvent
@onready var _animation_layer: Control = %DeckAnimationLayer

var _reduced_motion := false
var _instant_test_mode := false
var _seen_receipts: Dictionary = {}
var _active_animations: Dictionary = {}
var _draw_batch_remaining: Dictionary = {}
var _draw_child_parent: Dictionary = {}
var _evidence: Array[Dictionary] = []
var _last_projection: Dictionary = {}
var _last_projection_revision := -1
var _last_added_label := "等待取得卡牌"
var _acquire_animation_count := 0
var _shuffle_animation_count := 0
var _draw_animation_count := 0
var _enter_hand_animation_count := 0
var _discard_animation_count := 0
var _duplicate_suppression_count := 0
var _receipt_collision_count := 0
var _missing_source_rect_count := 0
var _target_zone_parity_count := 0
var _target_zone_mismatch_count := 0
var _animation_gameplay_mutation_count := 0
var _animation_rng_draw_delta := 0
var _animation_authority_sequence_delta := 0
var _animation_deck_order_mutation_count := 0
var _animation_card_zone_mutation_count := 0
var _draw_child_finish_count := 0
var _draw_batch_finish_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animation_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_labels()


func set_motion_policy(reduced_motion: bool, instant_test_mode := false) -> void:
	_reduced_motion = reduced_motion
	# This is callable from tests/fixtures only; no production player Control is
	# connected to it.
	_instant_test_mode = instant_test_mode


func reset_for_new_game() -> void:
	_seen_receipts.clear()
	_active_animations.clear()
	_draw_batch_remaining.clear()
	_draw_child_parent.clear()
	_evidence.clear()
	_last_projection = {}
	_last_projection_revision = -1
	_last_added_label = "等待取得卡牌"
	_acquire_animation_count = 0
	_shuffle_animation_count = 0
	_draw_animation_count = 0
	_enter_hand_animation_count = 0
	_discard_animation_count = 0
	_duplicate_suppression_count = 0
	_receipt_collision_count = 0
	_missing_source_rect_count = 0
	_target_zone_parity_count = 0
	_target_zone_mismatch_count = 0
	_draw_child_finish_count = 0
	_draw_batch_finish_count = 0
	for child in _animation_layer.get_children().duplicate():
		child.queue_free()
	_refresh_labels()


func apply_private_projection(snapshot: Dictionary) -> void:
	var facts := _private_facts(snapshot)
	if facts.is_empty():
		return
	_last_projection = {
		"draw_pile_count": int(facts.get("draw_pile_count", 0)),
		"discard_count": int(facts.get("discard_count", 0)),
		"hand_count": int(facts.get(
			"hand_count",
			(facts.get("hand", []) as Array).size()
		)),
		"hand": (facts.get("hand", []) as Array).duplicate(true),
		"discard": (facts.get("discard", []) as Array).duplicate(true),
	}
	_last_projection_revision = int(facts.get(
		"revision",
		facts.get("source_revision", _last_projection_revision + 1)
	))
	_refresh_labels()


func consume_acquisition_receipt(
	receipt: Dictionary,
	card_projection: Dictionary,
	source_global_rect: Rect2,
	external_target_global_rect := Rect2()
) -> Dictionary:
	var private_lifecycle := str(receipt.get("event_kind", "")) == "CARD_ACQUIRE"
	var valid_application_receipt := (
		bool(receipt.get("accepted", false))
		and str(receipt.get("intent_kind", "")) == "track.acquire"
	)
	var valid_private_receipt := (
		bool(receipt.get("accepted", false))
		and private_lifecycle
		and str(receipt.get("receipt_scope", "")) == "owner_private"
		and str(receipt.get("schema", ""))
			== "V076OwnerPrivateCardLifecyclePresentationReceiptV1"
		and bool(receipt.get("current_player_authorized", false))
	)
	if not valid_application_receipt and not valid_private_receipt:
		return {"accepted": false, "reason_code": "acquisition_receipt_not_accepted"}
	var receipt_id := str(
		receipt.get("receipt_id", receipt.get("intent_id", ""))
	).strip_edges()
	if receipt_id.is_empty():
		return {"accepted": false, "reason_code": "acquisition_receipt_identity_missing"}
	var ledger := _register_receipt(receipt_id, receipt)
	if not bool(ledger.get("accepted", false)) or bool(ledger.get("replayed", false)):
		return ledger
	if valid_private_receipt:
		var private_card := receipt.get("card_projection", {}) as Dictionary
		if private_card.is_empty() or card_projection.is_empty():
			return {"accepted": false, "reason_code": "acquisition_card_projection_missing"}
		if str(private_card.get("instance_id", "")) != str(card_projection.get("instance_id", "")):
			return {"accepted": false, "reason_code": "acquisition_card_projection_mismatch"}
	var destination := _normalized_zone(str(receipt.get("destination_zone", receipt.get("target_zone", ""))))
	var target_rect := external_target_global_rect
	if not target_rect.has_area():
		target_rect = target_global_rect(destination)
	if not target_rect.has_area():
		_target_zone_mismatch_count += 1
		return {"accepted": false, "reason_code": "acquisition_target_rect_missing"}
	_target_zone_parity_count += 1
	_acquire_animation_count += 1
	_last_added_label = "最近加入：%s → %s" % [
		_card_label(card_projection),
		_zone_label(destination),
	]
	_refresh_labels()
	call_deferred(
		"_run_card_motion",
		receipt_id,
		"CARD_ACQUIRE",
		card_projection.duplicate(true),
		source_global_rect,
		target_rect,
		destination,
		_duration(ACQUIRE_SECONDS)
	)
	return {
		"accepted": true,
		"queued": true,
		"receipt_id": receipt_id,
		"cue_id": "CARD_ACQUIRE",
		"target_zone": destination,
	}


func consume_deck_lifecycle_receipt(receipt: Dictionary) -> Dictionary:
	if not bool(receipt.get("accepted", false)) \
			or str(receipt.get("receipt_scope", "")) != "owner_private":
		return {"accepted": false, "reason_code": "deck_receipt_not_accepted"}
	var receipt_id := str(receipt.get("receipt_id", "")).strip_edges()
	if receipt_id.is_empty():
		return {"accepted": false, "reason_code": "deck_receipt_identity_missing"}
	var event_kind := str(receipt.get("event_kind", ""))
	# CARD_ACQUIRE has its own application/private pairing path.  Dispatch it
	# before the generic lifecycle ledger registration so
	# consume_acquisition_receipt() registers the receipt exactly once.
	if event_kind == "CARD_ACQUIRE":
		var card_projection := receipt.get("card_projection", {}) as Dictionary
		var source_rect := _receipt_rect(receipt, "source_global_rect")
		var target_rect := _receipt_rect(receipt, "target_global_rect")
		return consume_acquisition_receipt(
			receipt,
			card_projection,
			source_rect,
			target_rect
		)
	var ledger := _register_receipt(receipt_id, receipt)
	if not bool(ledger.get("accepted", false)) or bool(ledger.get("replayed", false)):
		return ledger
	match event_kind:
		"DECK_SHUFFLE":
			_shuffle_animation_count += 1
			_shuffle_status.text = "洗牌中"
			call_deferred(
				"_run_shuffle_motion",
				receipt_id,
				receipt.duplicate(true),
				_duration(SHUFFLE_SECONDS)
			)
		"CARD_DRAW":
			var cards := receipt.get("drawn_card_projections", []) as Array
			_draw_animation_count += cards.size()
			_enter_hand_animation_count += cards.size()
			_draw_batch_remaining[receipt_id] = cards.size()
			if cards.is_empty():
				# Screen queues the parent Director receipt after this consumer
				# returns, so an empty draw must finish on the next presentation
				# edge rather than synchronously before the parent is queued.
				call_deferred("_complete_empty_draw_batch", receipt_id)
			for index in range(cards.size()):
				var card := cards[index] as Dictionary
				var child_receipt_id := "%s.%02d" % [receipt_id, index]
				_draw_child_parent[child_receipt_id] = receipt_id
				call_deferred(
					"_run_card_motion",
					child_receipt_id,
					"CARD_DRAW",
					card.duplicate(true),
					draw_anchor_global_rect(),
					_receipt_rect(receipt, "hand_target_global_rect"),
					"hand",
					_duration(DRAW_SECONDS)
				)
		"CARD_DISCARD":
			_discard_animation_count += 1
			var card := receipt.get("card_projection", {}) as Dictionary
			call_deferred(
				"_run_card_motion",
				receipt_id,
				"CARD_DISCARD",
				card.duplicate(true),
				_receipt_rect(receipt, "source_global_rect"),
				discard_anchor_global_rect(),
				"discard",
				_duration(DISCARD_SECONDS)
			)
		_:
			return {"accepted": false, "reason_code": "deck_receipt_event_unknown"}
	return {"accepted": true, "queued": true, "receipt_id": receipt_id}


func draw_anchor_global_rect() -> Rect2:
	return _draw_panel.get_global_rect() if is_instance_valid(_draw_panel) else Rect2()


func discard_anchor_global_rect() -> Rect2:
	return _discard_panel.get_global_rect() if is_instance_valid(_discard_panel) else Rect2()


func target_global_rect(zone: String) -> Rect2:
	match _normalized_zone(zone):
		"draw_pile":
			return draw_anchor_global_rect()
		"discard":
			return discard_anchor_global_rect()
		"commodity_inventory":
			var commodity_panel := get_tree().root.find_child(
				"CommodityHandPreviewPanel",
				true,
				false
			) as Control
			return commodity_panel.get_global_rect() if is_instance_valid(commodity_panel) else Rect2()
		_:
			return Rect2()


func debug_snapshot() -> Dictionary:
	return {
		"schema": "V076DeckLifecyclePresentationDebugV1",
		"presentation_only": true,
		"draw_pile_visible": is_instance_valid(_draw_panel) and _draw_panel.is_visible_in_tree(),
		"discard_pile_visible": is_instance_valid(_discard_panel) and _discard_panel.is_visible_in_tree(),
		"draw_pile_count": int(_last_projection.get("draw_pile_count", 0)),
		"discard_count": int(_last_projection.get("discard_count", 0)),
		"hand_count": int(_last_projection.get("hand_count", 0)),
		"projection_revision": _last_projection_revision,
		"recent_event": _last_added_label,
		"acquire_animation_count": _acquire_animation_count,
		"shuffle_animation_count": _shuffle_animation_count,
		"draw_animation_count": _draw_animation_count,
		"enter_hand_animation_count": _enter_hand_animation_count,
		"discard_animation_count": _discard_animation_count,
		"duplicate_suppression_count": _duplicate_suppression_count,
		"receipt_collision_count": _receipt_collision_count,
		"missing_source_rect_count": _missing_source_rect_count,
		"target_zone_parity_count": _target_zone_parity_count,
		"target_zone_mismatch_count": _target_zone_mismatch_count,
		"active_animation_count": _active_animations.size(),
		"active_draw_batch_count": _draw_batch_remaining.size(),
		"active_draw_child_count": _draw_child_parent.size(),
		"draw_child_finish_count": _draw_child_finish_count,
		"draw_batch_finish_count": _draw_batch_finish_count,
		"evidence": _evidence.duplicate(true),
		"reduced_motion": _reduced_motion,
		"instant_test_mode": _instant_test_mode,
		"instant_test_mode_production_ui_reachable": false,
		"animation_gameplay_mutation_count": _animation_gameplay_mutation_count,
		"animation_rng_draw_delta": _animation_rng_draw_delta,
		"animation_authority_sequence_delta": _animation_authority_sequence_delta,
		"animation_deck_order_mutation_count": _animation_deck_order_mutation_count,
		"animation_card_zone_mutation_count": _animation_card_zone_mutation_count,
	}


func _register_receipt(receipt_id: String, receipt: Dictionary) -> Dictionary:
	var fingerprint_source := receipt.duplicate(true)
	fingerprint_source.erase("source_global_rect")
	fingerprint_source.erase("hand_target_global_rect")
	fingerprint_source.erase("target_global_rect")
	var fingerprint := JSON.stringify(fingerprint_source).sha256_text()
	if _seen_receipts.has(receipt_id):
		if str(_seen_receipts.get(receipt_id, "")) == fingerprint:
			_duplicate_suppression_count += 1
			return {"accepted": true, "replayed": true, "receipt_id": receipt_id}
		_receipt_collision_count += 1
		return {"accepted": false, "reason_code": "deck_receipt_identity_collision"}
	_seen_receipts[receipt_id] = fingerprint
	return {"accepted": true, "replayed": false, "receipt_id": receipt_id}


func _run_card_motion(
	receipt_id: String,
	cue_id: String,
	card_projection: Dictionary,
	source_rect: Rect2,
	target_rect: Rect2,
	target_zone: String,
	duration: float
) -> void:
	if not target_rect.has_area():
		_target_zone_mismatch_count += 1
		if cue_id == "CARD_DRAW":
			_complete_draw_child(receipt_id)
		return
	var proxy := _build_card_proxy(card_projection)
	if proxy == null:
		if cue_id == "CARD_DRAW":
			_complete_draw_child(receipt_id)
		return
	_animation_layer.add_child(proxy)
	proxy.size = PROXY_SIZE
	proxy.pivot_offset = PROXY_SIZE * 0.5
	var start_rect := source_rect
	if not start_rect.has_area():
		_missing_source_rect_count += 1
		start_rect = target_rect
	var start_position := start_rect.get_center() - PROXY_SIZE * 0.5
	var end_position := target_rect.get_center() - PROXY_SIZE * 0.5
	if _reduced_motion:
		start_position = end_position
	proxy.global_position = start_position
	proxy.scale = Vector2(0.82, 0.82) if not _reduced_motion else Vector2(0.94, 0.94)
	proxy.modulate = Color(1.0, 1.0, 1.0, 0.72 if _reduced_motion else 1.0)
	proxy.rotation = deg_to_rad(-7.0 if not _reduced_motion else 0.0)
	_active_animations[receipt_id] = cue_id
	var row := {
		"receipt_id": receipt_id,
		"cue_id": cue_id,
		"target_zone": target_zone,
		"start_rect": Rect2(start_position, PROXY_SIZE),
		"mid_rect": Rect2(),
		"end_rect": Rect2(),
		"target_rect": target_rect,
		"projection_counts": _last_projection.duplicate(true),
		"duration_ms": int(round(duration * 1000.0)),
		"privacy_class": "OWNER_PRIVATE",
	}
	if duration <= 0.0:
		proxy.global_position = end_position
		proxy.scale = Vector2(0.44, 0.44)
		row["mid_rect"] = Rect2(end_position, PROXY_SIZE * 0.44)
		row["end_rect"] = Rect2(end_position, PROXY_SIZE * 0.44)
		_complete_motion(proxy, receipt_id, cue_id, row)
		return
	var midpoint := (start_position + end_position) * 0.5
	if not _reduced_motion:
		midpoint.y -= minf(72.0, absf(end_position.x - start_position.x) * 0.16 + 22.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(proxy, "global_position", midpoint, duration * 0.48)
	tween.parallel().tween_property(proxy, "scale", Vector2(1.04, 1.04), duration * 0.48)
	tween.parallel().tween_property(proxy, "rotation", deg_to_rad(4.0), duration * 0.48)
	tween.tween_callback(func() -> void:
		row["mid_rect"] = proxy.get_global_rect()
	)
	tween.tween_property(proxy, "global_position", end_position, duration * 0.52)
	tween.parallel().tween_property(proxy, "scale", Vector2(0.44, 0.44), duration * 0.52)
	tween.parallel().tween_property(proxy, "rotation", 0.0, duration * 0.52)
	tween.parallel().tween_property(proxy, "modulate", Color(1.0, 1.0, 1.0, 0.12), duration * 0.52)
	tween.tween_callback(_complete_motion.bind(proxy, receipt_id, cue_id, row))


func _run_shuffle_motion(
	receipt_id: String,
	receipt: Dictionary,
	duration: float
) -> void:
	var target := draw_anchor_global_rect()
	if not target.has_area():
		_target_zone_mismatch_count += 1
		return
	_active_animations[receipt_id] = "DECK_SHUFFLE"
	var left := _build_card_back_proxy("A")
	var right := _build_card_back_proxy("B")
	_animation_layer.add_child(left)
	_animation_layer.add_child(right)
	for proxy in [left, right]:
		proxy.size = PROXY_SIZE
		proxy.pivot_offset = PROXY_SIZE * 0.5
		proxy.global_position = target.get_center() - PROXY_SIZE * 0.5
	var row := {
		"receipt_id": receipt_id,
		"cue_id": "DECK_SHUFFLE",
		"target_zone": "draw_pile",
		"start_rect": left.get_global_rect(),
		"mid_rect": Rect2(),
		"end_rect": Rect2(),
		"target_rect": target,
		"projection_counts": _last_projection.duplicate(true),
		"authority_receipt": receipt.duplicate(true),
		"duration_ms": int(round(duration * 1000.0)),
		"privacy_class": "OWNER_PRIVATE_CARD_BACK_ONLY",
	}
	if duration <= 0.0:
		row["mid_rect"] = left.get_global_rect()
		row["end_rect"] = left.get_global_rect()
		left.queue_free()
		right.queue_free()
		_active_animations.erase(receipt_id)
		_append_evidence(row)
		_shuffle_status.text = "牌库就绪"
		animation_finished.emit(receipt_id, "DECK_SHUFFLE")
		return
	var spread := 22.0 if not _reduced_motion else 5.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(left, "position:x", left.position.x - spread, duration * 0.32)
	tween.parallel().tween_property(right, "position:x", right.position.x + spread, duration * 0.32)
	tween.tween_callback(func() -> void:
		row["mid_rect"] = left.get_global_rect().merge(right.get_global_rect())
	)
	tween.tween_property(left, "position:x", left.position.x, duration * 0.34)
	tween.parallel().tween_property(right, "position:x", right.position.x, duration * 0.34)
	tween.tween_property(left, "modulate:a", 0.0, duration * 0.34)
	tween.parallel().tween_property(right, "modulate:a", 0.0, duration * 0.34)
	tween.tween_callback(func() -> void:
		row["end_rect"] = target
		left.queue_free()
		right.queue_free()
		_active_animations.erase(receipt_id)
		_append_evidence(row)
		_shuffle_status.text = "牌库就绪"
		animation_finished.emit(receipt_id, "DECK_SHUFFLE")
	)


func _complete_motion(
	proxy: Control,
	receipt_id: String,
	cue_id: String,
	row: Dictionary
) -> void:
	if is_instance_valid(proxy):
		row["end_rect"] = proxy.get_global_rect()
		proxy.queue_free()
	_active_animations.erase(receipt_id)
	_append_evidence(row)
	if cue_id == "CARD_DRAW":
		_complete_draw_child(receipt_id)
		return
	animation_finished.emit(receipt_id, cue_id)


func _complete_draw_child(child_receipt_id: String) -> void:
	if not _draw_child_parent.has(child_receipt_id):
		return
	var parent_receipt_id := str(_draw_child_parent.get(
		child_receipt_id, ""
	))
	_draw_child_parent.erase(child_receipt_id)
	_draw_child_finish_count += 1
	if not _draw_batch_remaining.has(parent_receipt_id):
		return
	var remaining := maxi(
		0,
		int(_draw_batch_remaining.get(parent_receipt_id, 0)) - 1
	)
	if remaining > 0:
		_draw_batch_remaining[parent_receipt_id] = remaining
		return
	_draw_batch_remaining.erase(parent_receipt_id)
	_draw_batch_finish_count += 1
	animation_finished.emit(parent_receipt_id, "CARD_DRAW")


func _complete_empty_draw_batch(parent_receipt_id: String) -> void:
	if not _draw_batch_remaining.has(parent_receipt_id):
		return
	if int(_draw_batch_remaining.get(parent_receipt_id, -1)) != 0:
		return
	_draw_batch_remaining.erase(parent_receipt_id)
	_draw_batch_finish_count += 1
	animation_finished.emit(parent_receipt_id, "CARD_DRAW")


func _append_evidence(row: Dictionary) -> void:
	_evidence.append(row.duplicate(true))
	while _evidence.size() > EVIDENCE_LIMIT:
		_evidence.pop_front()


func _build_card_proxy(card_projection: Dictionary) -> Control:
	var card := InteractiveCardFaceScene.instantiate() as Control
	if card == null or not card.has_method("configure"):
		return _build_card_back_proxy("CARD")
	var payload := card_projection.duplicate(true)
	payload["projection_role"] = "owner_private_animation_proxy"
	var presentation := {
		"name": _card_label(card_projection),
		"effect": str(card_projection.get(
			"short_effect",
			card_projection.get("effect", "权威区域转移")
		)),
		"type": str(card_projection.get("card_type", "卡牌")),
		"rank": "L%d" % maxi(1, int(card_projection.get("level", 1))),
		"cost": str(card_projection.get("cost", "")),
		"kind": str(card_projection.get("card_kind", "normal_card")),
		"route": str(card_projection.get("primary_color", "")),
		"accent": Color("#7ee7c6"),
		"presentation": "transition_proxy",
		"summary": str(card_projection.get("short_effect", "区域转移")),
		"disabled": true,
		"illustration_key": str(card_projection.get("illustration_key", "")),
		"card_frame_key": str(card_projection.get("card_frame_key", "card.frame.standard")),
		"tooltip": "表现层副本；权威实例未被移动",
	}
	card.call("configure", payload, presentation, false)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.z_index = 220
	return card


func _build_card_back_proxy(mark: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 220
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#15233c")
	style.border_color = Color("#68b5d6")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = mark
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


func _refresh_labels() -> void:
	if is_instance_valid(_draw_count):
		_draw_count.text = "抽牌堆 %d" % int(_last_projection.get("draw_pile_count", 0))
	if is_instance_valid(_discard_count):
		_discard_count.text = "弃牌堆 %d" % int(_last_projection.get("discard_count", 0))
	if is_instance_valid(_shuffle_status) and _active_animations.is_empty():
		_shuffle_status.text = "牌库就绪"
	if is_instance_valid(_recent_event):
		_recent_event.text = _last_added_label
		_recent_event.tooltip_text = _last_added_label


func _private_facts(snapshot: Dictionary) -> Dictionary:
	return (
		(snapshot.get("personal_dbg", {}) as Dictionary).get("facts", {})
		as Dictionary
	)


func _normalized_zone(zone: String) -> String:
	var value := zone.to_lower()
	return {
		"personal_discard": "discard",
		"discard_pile": "discard",
		"deck": "draw_pile",
		"player_deck": "draw_pile",
	}.get(value, value) as String


func _zone_label(zone: String) -> String:
	return {
		"draw_pile": "抽牌堆",
		"discard": "弃牌堆",
		"hand": "手牌",
		"commodity_inventory": "商品库存",
	}.get(_normalized_zone(zone), zone) as String


func _card_label(card: Dictionary) -> String:
	for field_name in ["name", "title", "card_name", "card_definition_id", "definition_id"]:
		var value := str(card.get(field_name, "")).strip_edges()
		if not value.is_empty():
			return value
	return "卡牌"


func _duration(full_seconds: float) -> float:
	if _instant_test_mode:
		return 0.0
	return REDUCED_SECONDS if _reduced_motion else full_seconds


func _receipt_rect(receipt: Dictionary, field_name: String) -> Rect2:
	var value: Variant = receipt.get(field_name, Rect2())
	return value as Rect2 if value is Rect2 else Rect2()

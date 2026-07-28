@tool
extends SpaceSyndicateDistrictSupplyDrawer
class_name SpaceSyndicateRegionSupplyPopup

signal game_action_offer_requested(
	offer: Dictionary,
	submission_kind: String,
	parameters: Dictionary,
	target_overrides: Dictionary
)

const ENVELOPE := preload("res://scripts/presentation/district_supply_presentation_envelope_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

var _presentation_apply_count := 0
var _presentation_reject_count := 0
var _last_visibility_scope := "closed"
var _last_rack_source_revision := ""
var _last_rack_source_version := -1
var _last_district_index := -1
var _last_surface_fingerprint := ""
var _bound_viewer_index := -1
var _bound_authorization_revision := 0
var _stale_count := 0
var _duplicate_count := 0
var _typed_offer_emit_count := 0


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_unhandled_key_input(true)


func bind_viewer(viewer_index: int, authorization_revision: int) -> void:
	if viewer_index == _bound_viewer_index \
			and authorization_revision == _bound_authorization_revision:
		return
	_bound_viewer_index = viewer_index
	_bound_authorization_revision = authorization_revision
	clear_supply()
	visible = false
	_last_visibility_scope = "closed"
	_reset_applied_source()


func apply_presentation(
	surface: Dictionary,
	viewer_index: int,
	authorization_revision: int,
	forced_surface_active: bool = false
) -> bool:
	if not bool(ENVELOPE.validation_report(surface).get("valid", false)) \
			or not PlayerVisibleSurfacePolicy.is_safe_closed_data(surface) \
			or viewer_index != _bound_viewer_index \
			or authorization_revision != _bound_authorization_revision \
			or int(surface.get("viewer_index", -1)) != _bound_viewer_index \
			or int(surface.get("authorization_revision", 0)) != _bound_authorization_revision \
			or (str(surface.get("visibility_scope", "closed")) == "viewer_private" \
				and int(surface.get("subject_player_index", -1)) != _bound_viewer_index):
		clear_supply()
		visible = false
		_last_visibility_scope = "closed"
		_reset_applied_source()
		_presentation_reject_count += 1
		return false
	var surface_fingerprint := WIRE.fingerprint(surface)
	if not bool(surface.get("visible", false)):
		if _last_visibility_scope == "closed" \
				and surface_fingerprint == _last_surface_fingerprint:
			_duplicate_count += 1
			return true
		clear_supply()
		visible = false
		_last_visibility_scope = "closed"
		_reset_applied_source()
		_last_surface_fingerprint = surface_fingerprint
		_presentation_apply_count += 1
		return true
	var snapshot: Dictionary = surface.get("snapshot", {}) \
		if surface.get("snapshot", {}) is Dictionary else {}
	if forced_surface_active or snapshot.is_empty():
		clear_supply()
		visible = false
		_last_visibility_scope = "closed"
		_reset_applied_source()
		_presentation_reject_count += 1
		return false
	var rack_source_revision := str(surface.get("rack_source_revision", ""))
	var rack_source_version := int(surface.get("rack_source_version", 0))
	var district_index := int(surface.get("district_index", -1))
	if rack_source_revision.is_empty() or rack_source_version <= 0:
		clear_supply()
		visible = false
		_last_visibility_scope = "closed"
		_reset_applied_source()
		_presentation_reject_count += 1
		return false
	if _last_rack_source_version >= 0 and rack_source_version < _last_rack_source_version:
		_stale_count += 1
		return false
	if rack_source_version == _last_rack_source_version:
		if district_index == _last_district_index \
				and not _last_rack_source_revision.is_empty() \
				and rack_source_revision != _last_rack_source_revision:
			_presentation_reject_count += 1
			return false
		if surface_fingerprint == _last_surface_fingerprint:
			_duplicate_count += 1
			return true
	set_supply(snapshot)
	visible = true
	_last_visibility_scope = str(surface.get("visibility_scope", "public"))
	_last_rack_source_revision = rack_source_revision
	_last_rack_source_version = rack_source_version
	_last_district_index = district_index
	_last_surface_fingerprint = surface_fingerprint
	_presentation_apply_count += 1
	return true


func close_popup() -> bool:
	if not visible:
		return false
	var offer: Dictionary = _snapshot.get("close_offer", {}) \
		if _snapshot.get("close_offer", {}) is Dictionary else {}
	var submitted := _emit_offer(offer, INTENT.ACTION_DISTRICT_SUPPLY_CLOSE)
	# Close the presentation immediately after the one typed request. The owner
	# receipt remains authoritative; local visibility only prevents a second
	# click from minting another request while the next snapshot is in flight.
	visible = false
	return submitted


func request_card_quote(card_name: String) -> bool:
	if card_name.is_empty() or _last_visibility_scope != "viewer_private" \
			or not _market_entries_by_name.has(card_name):
		return false
	var entry: Dictionary = _market_entries_by_name.get(card_name, {}) as Dictionary
	if _interaction_state(entry) != "quote":
		return false
	return _emit_offer(
		entry.get("quote_offer", {}) if entry.get("quote_offer", {}) is Dictionary else {},
		INTENT.ACTION_DISTRICT_SUPPLY_QUOTE
	)


func request_selected_purchase() -> bool:
	if _local_preview_card_name.is_empty() or not _market_entries_by_name.has(_local_preview_card_name):
		return false
	return _submit_card_purchase_or_quote(_local_preview_card_name)


func cycle_quote() -> bool:
	if _market_card_names.is_empty():
		return false
	var current_index := _market_card_names.find(_local_preview_card_name)
	var next_id := str(_market_card_names[0] if current_index < 0 \
		else _market_card_names[wrapi(current_index + 1, 0, _market_card_names.size())])
	super._on_card_preview_requested(next_id, "hover")
	return request_card_quote(next_id)


func presentation_target_snapshot() -> Dictionary:
	var base := debug_snapshot()
	base.merge({
		"apply_count": _presentation_apply_count,
		"reject_count": _presentation_reject_count,
		"stale_count": _stale_count,
		"duplicate_count": _duplicate_count,
		"last_visibility_scope": _last_visibility_scope,
		"rack_source_revision": _last_rack_source_revision,
		"rack_source_version": _last_rack_source_version,
		"bound_viewer_index": _bound_viewer_index,
		"bound_authorization_revision": _bound_authorization_revision,
		"typed_offer_emit_count": _typed_offer_emit_count,
		"legacy_action_emit_count": 0,
		"non_mutation_requires_owner_probe": true,
		"owns_gameplay_state": false,
		"owns_purchase_quote": false,
		"references_main": false,
	}, true)
	return base


func _on_close_pressed() -> void:
	close_popup()


func _on_card_preview_requested(card_name: String, source: String) -> void:
	if card_name.is_empty() or not _market_entries_by_name.has(card_name):
		return
	# Reuse the base drawer's passive local selection work, while deliberately
	# suppressing its retired string action signal.
	super._on_card_preview_requested(card_name, "hover")
	if source == "hover":
		return
	var entry: Dictionary = _market_entries_by_name.get(card_name, {}) as Dictionary
	if _interaction_state(entry) == "quote":
		_emit_offer(
			entry.get("quote_offer", {}) if entry.get("quote_offer", {}) is Dictionary else {},
			INTENT.ACTION_DISTRICT_SUPPLY_QUOTE
		)


func _on_card_purchase_requested(card_name: String, _source: String) -> void:
	_submit_card_purchase_or_quote(card_name)


func _submit_card_purchase_or_quote(card_name: String) -> bool:
	if card_name.is_empty() or _last_visibility_scope != "viewer_private" \
			or not _market_entries_by_name.has(card_name):
		return false
	var entry: Dictionary = _market_entries_by_name.get(card_name, {}) as Dictionary
	match _interaction_state(entry):
		"quote":
			var quote_offer: Dictionary = entry.get("quote_offer", {}) \
				if entry.get("quote_offer", {}) is Dictionary else {}
			return _emit_offer(quote_offer, INTENT.ACTION_DISTRICT_SUPPLY_QUOTE)
		"purchase":
			var purchase_offer: Dictionary = entry.get("purchase_offer", {}) \
				if entry.get("purchase_offer", {}) is Dictionary else {}
			return _emit_offer(purchase_offer, INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE)
	return false


func _emit_offer(offer: Dictionary, expected_action_id: String) -> bool:
	if _bound_viewer_index < 0 or _bound_authorization_revision <= 0 \
			or not bool(OFFER.validation_report(offer).get("valid", false)) \
			or str(offer.get("semantic_action_id", "")) != expected_action_id \
			or str(offer.get("actor_scope", "")) != "authorized_actor" \
			or str(offer.get("legality_state", "")) != "available":
		return false
	var target_spec: Dictionary = offer.get("public_or_private_target_spec", {}) \
		if offer.get("public_or_private_target_spec", {}) is Dictionary else {}
	if str(target_spec.get("visibility_scope_id", "")) != "viewer_private":
		return false
	if OFFER.target_ids(offer).has("player_id"):
		return false
	_typed_offer_emit_count += 1
	game_action_offer_requested.emit(OFFER.detached_copy(offer), "human_click", {}, {})
	return true


func _interaction_state(entry: Dictionary) -> String:
	var state: Dictionary = entry.get("purchase_state", {}) \
		if entry.get("purchase_state", {}) is Dictionary else {}
	var interaction_state := str(state.get("interaction_state", "blocked"))
	return interaction_state if interaction_state in ["quote", "purchase", "blocked"] \
		else "blocked"


func _reset_applied_source() -> void:
	_last_rack_source_revision = ""
	_last_rack_source_version = -1
	_last_district_index = -1
	_last_surface_fingerprint = ""


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not visible or mouse_event == null or not mouse_event.pressed \
			or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var drawer := get_node_or_null("DistrictSupplySideDrawer") as Control
	if drawer == null or not drawer.get_global_rect().has_point(mouse_event.global_position):
		close_popup()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_popup()
		get_viewport().set_input_as_handled()

extends RefCounted
class_name V073PlaytestEventV1
# MCP_FINALIZE

const SCHEMA_VERSION := 1
const SCHEMA_ID := "V073PlaytestEventV1"
const EVENT_TYPES := [
	"session_started", "new_game_started",
	"coach_mark_shown", "coach_mark_skipped",
	"card_hover_summary", "card_selected", "card_deselected",
	"target_selection_started", "target_bound", "target_changed",
	"target_cancelled", "action_order_changed", "action_submitted",
	"action_submission_rejected", "asset_reservation_failed",
	"track_offer_seen", "track_commodity_claimed",
	"track_normal_card_purchased", "deck_draw", "deck_discard",
	"deck_reshuffle", "optional_merge_opened",
	"optional_merge_completed", "optional_merge_cancelled",
	"asset_refresh", "asset_cap_overflow", "batch_locked",
	"batch_resolution_started", "batch_resolution_completed",
	"facility_contention", "action_fizzled", "solar_efficiency_changed",
	"ai_action_submitted", "victory_pending", "victory_resolved",
	"final_settlement_presented", "session_ended",
	"playtest_marker_recorded", "region_popup_opened", "ui_backtracked",
	"questionnaire_presented", "questionnaire_submitted",
	"questionnaire_skipped",
]
const PAYLOAD_FIELDS := [
	"accepted", "action_count", "asset_cost", "batch_duration_ms",
	"card_definition_id", "card_kind", "color_id", "count",
	"draw_count", "facility_action_mode", "facility_type", "from_index",
	"hand_count", "interaction_mode", "latency_ms", "mark_id",
	"planning_duration_ms",
	"marker_type", "note", "overflow_by_color", "phase", "player_index",
	"public_reason_code", "queue_count", "region_id", "reshuffle_count",
	"revision", "settlement_id", "skip_all", "source_surface",
	"submission_timeout", "sunlit", "to_index", "track_revision",
	"ui_surface", "value", "zero_action_batch",
]
const FORBIDDEN_FIELD_FRAGMENTS := [
	"instance_id", "actor_id", "player_id", "owner_id", "hand_contents",
	"hidden", "private", "ai_plan", "score", "cursor", "rng_state",
	"future", "absolute_path", "user_name", "account", "machine",
]


static func build(common: Dictionary, event_type: String, payload: Dictionary) -> Dictionary:
	if event_type not in EVENT_TYPES:
		return {}
	var safe_payload := sanitize_payload(payload)
	if safe_payload.is_empty() and not payload.is_empty():
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"schema_id": SCHEMA_ID,
		"session_id": str(common.get("session_id", "")),
		"build_sha": str(common.get("build_sha", "unknown-local")),
		"ruleset_id": str(common.get("ruleset_id", "v0.7.3")),
		"balance_profile_id": str(common.get("balance_profile_id", "")),
		"balance_profile_fingerprint": str(common.get(
			"balance_profile_fingerprint", ""
		)),
		"seed": int(common.get("seed", 0)),
		"player_count": int(common.get("player_count", 0)),
		"local_player_index": int(common.get("local_player_index", 0)),
		"screen_resolution": str(common.get("screen_resolution", "0x0")),
		"locale": str(common.get("locale", "unknown")),
		"event_sequence": int(common.get("event_sequence", 0)),
		"monotonic_elapsed_ms": int(common.get("monotonic_elapsed_ms", 0)),
		"batch_id": str(common.get("batch_id", "none")),
		"event_type": event_type,
		"payload": safe_payload,
	}


static func sanitize_payload(payload: Dictionary) -> Dictionary:
	var result := {}
	for key_variant in payload.keys():
		var key := str(key_variant)
		if key not in PAYLOAD_FIELDS or _forbidden_key(key):
			return {}
		var value: Variant = payload.get(key_variant)
		if not _safe_value(key, value):
			return {}
		result[key] = _sanitize_value(key, value)
	return result


static func has_hidden_info(event: Dictionary) -> bool:
	return _contains_forbidden(event)


static func _safe_value(key: String, value: Variant) -> bool:
	if value is bool or value is int or value is float:
		return true
	if value is String or value is StringName:
		return not _looks_like_absolute_path(str(value))
	if key == "overflow_by_color" and value is Dictionary:
		for color in value.keys():
			if str(color) not in [
				"life", "energy", "industry", "technology", "commerce", "shipping"
			] or not (value.get(color) is int):
				return false
		return true
	return false


static func _sanitize_value(key: String, value: Variant) -> Variant:
	if value is String or value is StringName:
		var limit := 280 if key == "note" else 160
		return _clean_text(str(value), limit)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return value


static func _clean_text(value: String, limit: int) -> String:
	var clean := ""
	for character in value:
		var code := character.unicode_at(0)
		if code >= 32 and code != 127:
			clean += character
	return clean.left(limit)


static func _forbidden_key(key: String) -> bool:
	for fragment in FORBIDDEN_FIELD_FRAGMENTS:
		if fragment in key.to_lower():
			return true
	return false


static func _contains_forbidden(value: Variant) -> bool:
	if value is Dictionary:
		for key in value.keys():
			if _forbidden_key(str(key)) or _contains_forbidden(value.get(key)):
				return true
	elif value is Array:
		for item in value:
			if _contains_forbidden(item):
				return true
	elif value is String or value is StringName:
		return _looks_like_absolute_path(str(value))
	return false


static func _looks_like_absolute_path(value: String) -> bool:
	var normalized := value.replace("\\", "/")
	return normalized.begins_with("/") or (
		normalized.length() > 2
		and normalized[1] == ":"
		and normalized[2] == "/"
	)

extends RefCounted
class_name TableInteractionModeV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const SCHEMA_VERSION := 1

const TABLE_MAP_MODE := "table_map"
const REGION_SUPPLY_POPUP_MODE := "region_supply_popup"
const CARD_TARGET_SELECTION_MODE := "card_target_selection"
const PLAYER_INSPECTION_MODE := "player_inspection"
const CONTEXT_DETAIL_MODE := "context_detail"
const FORCED_DECISION_MODE := "forced_decision"
const CARD_RESOLUTION_MODE := "card_resolution"
const MENU_OR_CODEX_MODE := "menu_or_codex"
const MODE_IDS := [
	TABLE_MAP_MODE,
	REGION_SUPPLY_POPUP_MODE,
	CARD_TARGET_SELECTION_MODE,
	PLAYER_INSPECTION_MODE,
	CONTEXT_DETAIL_MODE,
	FORCED_DECISION_MODE,
	CARD_RESOLUTION_MODE,
	MENU_OR_CODEX_MODE,
]

const REGION_CLICK_OPEN_POPUP := "open_region_supply_popup"
const REGION_CLICK_SWITCH_POPUP := "switch_region_supply_popup"
const REGION_CLICK_CLOSE_POPUP := "close_region_supply_popup"
const REGION_CLICK_SUBMIT_TARGET := "submit_card_target"
const REGION_CLICK_BLOCKED := "blocked"

const FIELDS := [
	"schema_version",
	"viewer_index",
	"authorization_revision",
	"source_revision",
	"mode_id",
	"active_region_id",
	"active_player_id",
	"active_context_id",
	"mode_fingerprint",
]
const FORBIDDEN_KEYS := [
	"node",
	"object",
	"resource",
	"callable",
	"node_path",
	"nodepath",
	"method",
	"method_name",
	"callback",
	"rng_state",
]


static func build(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) or unsealed.has("mode_fingerprint"):
		return {}
	var sealed := WIRE.sealed_copy(unsealed, "mode_fingerprint")
	return sealed if bool(validation_report(sealed).get("valid", false)) else {}


static func detached_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) \
		if bool(validation_report(value).get("valid", false)) else {}


static func matches_viewer_authorization(
	value: Variant,
	viewer_index: int,
	authorization_revision: int
) -> bool:
	return viewer_index >= 0 and authorization_revision > 0 \
		and bool(validation_report(value).get("valid", false)) \
		and int((value as Dictionary).get("viewer_index", -1)) == viewer_index \
		and int((value as Dictionary).get("authorization_revision", 0)) \
		== authorization_revision


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return _invalid("table_interaction_mode_not_closed_data")
	var mode := value as Dictionary
	if not WIRE.exact_fields(mode, FIELDS):
		return _invalid("table_interaction_mode_fields_invalid")
	if mode.get("schema_version") != SCHEMA_VERSION:
		return _invalid("table_interaction_mode_schema_invalid")
	if not WIRE.is_nonnegative_integer(mode.get("viewer_index")) \
			or not WIRE.is_positive_integer(mode.get("authorization_revision")) \
			or not WIRE.is_nonnegative_integer(mode.get("source_revision")) \
			or str(mode.get("mode_id", "")) not in MODE_IDS \
			or not _stable_id_or_empty(mode.get("active_region_id")) \
			or not _stable_id_or_empty(mode.get("active_player_id")) \
			or not _stable_id_or_empty(mode.get("active_context_id")):
		return _invalid("table_interaction_mode_identity_invalid")
	if WIRE.contains_key_recursive(mode, FORBIDDEN_KEYS):
		return _invalid("table_interaction_mode_forbidden_field")
	var context_error := _active_context_error(mode)
	if not context_error.is_empty():
		return _invalid(context_error)
	if not WIRE.is_fingerprint(mode.get("mode_fingerprint")) \
			or str(mode.get("mode_fingerprint", "")) \
			!= WIRE.fingerprint(mode, "mode_fingerprint"):
		return _invalid("table_interaction_mode_fingerprint_invalid")
	return WIRE.valid_result()


static func region_click_disposition(
	value: Variant,
	clicked_region_id: String,
	open_region_id: String = ""
) -> String:
	if not bool(validation_report(value).get("valid", false)) \
			or not WIRE.is_stable_id(clicked_region_id) \
			or not _stable_id_or_empty(open_region_id):
		return REGION_CLICK_BLOCKED
	var mode_id := str((value as Dictionary).get("mode_id", ""))
	match mode_id:
		TABLE_MAP_MODE:
			return REGION_CLICK_OPEN_POPUP
		REGION_SUPPLY_POPUP_MODE:
			return REGION_CLICK_CLOSE_POPUP if clicked_region_id == open_region_id \
				else REGION_CLICK_SWITCH_POPUP
		CARD_TARGET_SELECTION_MODE:
			return REGION_CLICK_SUBMIT_TARGET
	return REGION_CLICK_BLOCKED


static func blocks_ordinary_popups(value: Variant) -> bool:
	if not bool(validation_report(value).get("valid", false)):
		return true
	return str((value as Dictionary).get("mode_id", "")) in [
		CARD_TARGET_SELECTION_MODE,
		FORCED_DECISION_MODE,
		CARD_RESOLUTION_MODE,
		MENU_OR_CODEX_MODE,
	]


static func _active_context_error(mode: Dictionary) -> String:
	var mode_id := str(mode.get("mode_id", ""))
	var region_id := str(mode.get("active_region_id", ""))
	var player_id := str(mode.get("active_player_id", ""))
	var context_id := str(mode.get("active_context_id", ""))
	match mode_id:
		TABLE_MAP_MODE, MENU_OR_CODEX_MODE:
			if not region_id.is_empty() or not player_id.is_empty() or not context_id.is_empty():
				return "table_interaction_mode_inactive_context_invalid"
		REGION_SUPPLY_POPUP_MODE:
			if region_id.is_empty() or not player_id.is_empty() or not context_id.is_empty():
				return "table_interaction_mode_region_popup_context_invalid"
		PLAYER_INSPECTION_MODE:
			if not region_id.is_empty() or player_id.is_empty() or not context_id.is_empty():
				return "table_interaction_mode_player_inspection_context_invalid"
		CARD_TARGET_SELECTION_MODE, CONTEXT_DETAIL_MODE, FORCED_DECISION_MODE, CARD_RESOLUTION_MODE:
			if not region_id.is_empty() or not player_id.is_empty() or context_id.is_empty():
				return "table_interaction_mode_typed_context_invalid"
	return ""


static func _stable_id_or_empty(value: Variant) -> bool:
	return value is String and (str(value).is_empty() or WIRE.is_stable_id(value))


static func _invalid(reason_id: String) -> Dictionary:
	return WIRE.invalid_result(reason_id)

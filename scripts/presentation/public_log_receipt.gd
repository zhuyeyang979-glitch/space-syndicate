extends RefCounted
class_name PublicLogReceipt

const ALLOWED_VALUE_TYPES := [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]
const ALLOWED_PUBLIC_KEYS := [
	"action_kind",
	"amount_band",
	"card_name",
	"commodity_id",
	"countdown_seconds",
	"level",
	"military_unit_name",
	"monster_name",
	"outcome_id",
	"player_index",
	"price_after",
	"price_before",
	"previous_state",
	"pressure_units",
	"public_player_name",
	"public_status",
	"rank",
	"reason_code",
	"region_id",
	"region_name",
	"result",
	"state",
	"value_band",
	"winner_player_indices",
]
const FINAL_SETTLEMENT_REASON_CODES := [
	"public_audit_complete",
	"last_survivor",
	"planet_destroyed",
]
const FORBIDDEN_PUBLIC_KEYS := [
	"ai_plan",
	"ai_reason",
	"ai_utility_score",
	"cash",
	"cash_cents",
	"cash_ledger_cents",
	"discard",
	"decision_samples",
	"hand",
	"hand_count",
	"hidden_owner",
	"learning_bonus",
	"owner",
	"owner_truth",
	"private_cash",
	"private_hand",
	"private_route_plan",
	"route_plan_score",
	"slots",
	"true_owner",
]

var receipt_id := ""
var event_kind: StringName = &""
var localization_key: StringName = &""
var public_values: Dictionary = {}
var source_revision := 0
var world_time := 0.0


static func create(
	new_receipt_id: String,
	new_event_kind: StringName,
	new_localization_key: StringName,
	new_public_values: Dictionary,
	new_source_revision: int,
	new_world_time: float
) -> PublicLogReceipt:
	var receipt := PublicLogReceipt.new()
	receipt.receipt_id = new_receipt_id.strip_edges()
	receipt.event_kind = new_event_kind
	receipt.localization_key = new_localization_key
	receipt.public_values = new_public_values.duplicate(true)
	receipt.source_revision = maxi(0, new_source_revision)
	receipt.world_time = maxf(0.0, new_world_time)
	return receipt


func is_valid() -> bool:
	return not receipt_id.is_empty() \
		and not str(event_kind).is_empty() \
		and not str(localization_key).is_empty() \
		and _public_values_valid(public_values) \
		and _event_contract_valid()


func to_dictionary() -> Dictionary:
	if not is_valid():
		return {}
	return {
		"receipt_id": receipt_id,
		"event_kind": str(event_kind),
		"localization_key": str(localization_key),
		"public_values": public_values.duplicate(true),
		"source_revision": source_revision,
		"world_time": world_time,
		"visibility_scope": "public",
	}


func fingerprint() -> String:
	var data := to_dictionary()
	return JSON.stringify(_canonicalize(data)).sha256_text() if not data.is_empty() else ""


func _public_values_valid(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in value.keys():
			if not (key_variant is String or key_variant is StringName):
				return false
			var key := str(key_variant).to_lower()
			if not ALLOWED_PUBLIC_KEYS.has(key) \
				or FORBIDDEN_PUBLIC_KEYS.has(key) \
				or not _public_values_valid(value[key_variant]):
				return false
		return true
	if value is Array:
		for child in value:
			if not _public_values_valid(child):
				return false
		return true
	return ALLOWED_VALUE_TYPES.has(typeof(value))


func _event_contract_valid() -> bool:
	if event_kind == &"victory_state_changed":
		for key_variant in public_values.keys():
			if not ["previous_state", "state"].has(str(key_variant)):
				return false
	if event_kind == &"final_settlement":
		if localization_key != &"victory.public.final_settlement" \
				or public_values.size() != 4 \
				or not public_values.has("outcome_id") \
				or not public_values.has("public_status") \
				or not public_values.has("reason_code") \
				or not public_values.has("winner_player_indices") \
				or str(public_values.get("outcome_id", "")).strip_edges().is_empty() \
				or str(public_values.get("public_status", "")) != "settled" \
				or not str(public_values.get("reason_code", "")) in FINAL_SETTLEMENT_REASON_CODES \
				or not (public_values.get("winner_player_indices") is Array):
			return false
		var winner_indices := public_values.get("winner_player_indices") as Array
		if winner_indices.is_empty():
			return false
		var seen := {}
		for player_index_variant in winner_indices:
			if typeof(player_index_variant) != TYPE_INT or int(player_index_variant) < 0 \
					or seen.has(int(player_index_variant)):
				return false
			seen[int(player_index_variant)] = true
	return true


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array = source.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var normalized := {}
		for key_variant in keys:
			normalized[str(key_variant)] = _canonicalize(source[key_variant])
		return normalized
	if value is Array:
		var normalized_array: Array = []
		for child in value:
			normalized_array.append(_canonicalize(child))
		return normalized_array
	return value

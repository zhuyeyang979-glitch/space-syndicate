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
	"player_index",
	"previous_state",
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
	return true

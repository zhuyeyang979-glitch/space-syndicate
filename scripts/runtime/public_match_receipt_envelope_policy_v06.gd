extends RefCounted
class_name PublicMatchReceiptEnvelopePolicyV06

const SCHEMA_VERSION := "v0.6.public-match-receipt.1"
const PUBLIC_RECEIPT_ID_PREFIX := "pub."
const MAX_RECEIPT_ID_LENGTH := 96
const MAX_ABS_DELTA := 1_000_000_000_000

const RECEIPT_FIELDS := [
	"schema_version",
	"receipt_id",
	"sequence",
	"world_effective_us",
	"turn_marker",
	"event_kind",
	"public_outcome_code",
	"typed_deltas",
	"source_receipt_ids",
]
const PUBLIC_TYPED_DELTA_IDS := [
	"gdp_cents_per_minute_delta",
	"controlled_regions_delta",
	"route_income_cents_delta",
	"weather_value_cents_delta",
	"monster_damage_avoided_cents_delta",
	"military_spend_cents_delta",
	"inference_reward_cents_delta",
]
const TENDENCY_IDS := [
	"city_growth",
	"finance_speculation",
	"direct_interaction",
	"monster_pressure",
	"contract_route",
	"intelligence_supply",
]
const EVENT_KIND_TO_TENDENCY := {
	"public_facility_committed": "city_growth",
	"market_position_resolved": "finance_speculation",
	"public_interaction_resolved": "direct_interaction",
	"monster_pressure_resolved": "monster_pressure",
	"route_contract_resolved": "contract_route",
	"public_inference_resolved": "intelligence_supply",
}
const OUTCOME_CODES_BY_EVENT := {
	"public_facility_committed": ["facility_built", "facility_upgraded", "facility_income_realized"],
	"market_position_resolved": ["market_gain_realized", "market_loss_realized", "market_position_closed"],
	"public_interaction_resolved": ["public_pressure_applied", "public_pressure_resisted"],
	"monster_pressure_resolved": ["monster_pressure_created", "monster_damage_avoided", "monster_aftermath_resolved"],
	"route_contract_resolved": ["contract_completed", "route_income_realized", "route_protected"],
	"public_inference_resolved": ["public_inference_rewarded", "supply_secured", "public_clue_revealed"],
}
const FORBIDDEN_KEYS := {
	"player": true,
	"player_id": true,
	"player_index": true,
	"seat": true,
	"seat_id": true,
	"seat_index": true,
	"actor": true,
	"actor_id": true,
	"profile": true,
	"profile_id": true,
	"card_id": true,
	"target": true,
	"target_id": true,
	"bid": true,
	"weight": true,
	"weights": true,
	"score": true,
	"scores": true,
	"reason": true,
	"reasons": true,
	"candidate": true,
	"candidates": true,
	"plan": true,
	"plans": true,
	"learning": true,
	"owner": true,
	"owner_id": true,
	"hand": true,
	"discard": true,
	"cash": true,
	"cash_cents": true,
	"fingerprint": true,
}
const FORBIDDEN_VALUE_MARKERS := [
	"private",
	"secret",
	"sentinel",
	"player_",
	"seat_",
	"actor_",
	"profile_",
	"owner_",
	"hidden_",
	"ai_plan",
	"ai_score",
	"fingerprint",
]


func validate_and_seal(candidate: Variant) -> Dictionary:
	if not (candidate is Dictionary):
		return _failure("receipt_not_dictionary")
	if not _is_pure_public_data(candidate):
		return _failure("forbidden_or_non_data_input")
	var receipt := candidate as Dictionary
	if not _keys_exact(receipt, RECEIPT_FIELDS):
		return _failure("receipt_fields")
	if str(receipt.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("schema_version")
	var receipt_id := str(receipt.get("receipt_id", ""))
	if not _valid_public_receipt_id(receipt_id):
		return _failure("receipt_id")
	if typeof(receipt.get("sequence")) != TYPE_INT or int(receipt.get("sequence", 0)) <= 0:
		return _failure("sequence")
	if typeof(receipt.get("world_effective_us")) != TYPE_INT or int(receipt.get("world_effective_us", -1)) < 0:
		return _failure("world_effective_us")
	if typeof(receipt.get("turn_marker")) != TYPE_INT or int(receipt.get("turn_marker", -1)) < 0:
		return _failure("turn_marker")
	var event_kind := str(receipt.get("event_kind", ""))
	if not EVENT_KIND_TO_TENDENCY.has(event_kind):
		return _failure("event_kind")
	var outcome_code := str(receipt.get("public_outcome_code", ""))
	if not (OUTCOME_CODES_BY_EVENT.get(event_kind, []) as Array).has(outcome_code):
		return _failure("public_outcome_code")
	var typed_deltas_result := _canonical_typed_deltas(receipt.get("typed_deltas"))
	if not bool(typed_deltas_result.get("accepted", false)):
		return _failure(str(typed_deltas_result.get("failure_code", "typed_deltas")))
	var source_ids_result := _canonical_source_receipt_ids(receipt.get("source_receipt_ids"), receipt_id)
	if not bool(source_ids_result.get("accepted", false)):
		return _failure(str(source_ids_result.get("failure_code", "source_receipt_ids")))
	return {
		"accepted": true,
		"failure_code": "",
		"receipt": {
			"schema_version": SCHEMA_VERSION,
			"receipt_id": receipt_id,
			"sequence": int(receipt.get("sequence", 0)),
			"world_effective_us": int(receipt.get("world_effective_us", 0)),
			"turn_marker": int(receipt.get("turn_marker", 0)),
			"event_kind": event_kind,
			"public_outcome_code": outcome_code,
			"typed_deltas": (typed_deltas_result.get("typed_deltas", {}) as Dictionary).duplicate(true),
			"source_receipt_ids": (source_ids_result.get("source_receipt_ids", []) as Array).duplicate(),
		},
	}


func contract_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"receipt_fields": RECEIPT_FIELDS.duplicate(),
		"typed_delta_ids": PUBLIC_TYPED_DELTA_IDS.duplicate(),
		"tendency_ids": TENDENCY_IDS.duplicate(),
		"event_kinds": EVENT_KIND_TO_TENDENCY.keys(),
		"pure_data_only": true,
		"owns_runtime_state": false,
		"owns_save_state": false,
	}


static func tendency_id_for_event_kind(event_kind: String) -> String:
	return str(EVENT_KIND_TO_TENDENCY.get(event_kind, ""))


func _canonical_typed_deltas(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _failure("typed_deltas")
	var source := value as Dictionary
	var canonical := {}
	for key_variant: Variant in source:
		var key := str(key_variant)
		if not PUBLIC_TYPED_DELTA_IDS.has(key):
			return _failure("typed_delta_key")
		var delta_value: Variant = source[key_variant]
		if typeof(delta_value) != TYPE_INT or abs(int(delta_value)) > MAX_ABS_DELTA:
			return _failure("typed_delta_value")
	for delta_id_variant: Variant in PUBLIC_TYPED_DELTA_IDS:
		var delta_id := str(delta_id_variant)
		if source.has(delta_id):
			canonical[delta_id] = int(source[delta_id])
	return {"accepted": true, "failure_code": "", "typed_deltas": canonical}


func _canonical_source_receipt_ids(value: Variant, receipt_id: String) -> Dictionary:
	if not (value is Array):
		return _failure("source_receipt_ids")
	var canonical: Array[String] = []
	var seen := {}
	for source_variant: Variant in value as Array:
		if not (source_variant is String or source_variant is StringName):
			return _failure("source_receipt_id_type")
		var source_id := str(source_variant)
		if not _valid_public_receipt_id(source_id) or source_id == receipt_id or seen.has(source_id):
			return _failure("source_receipt_id")
		seen[source_id] = true
		canonical.append(source_id)
	canonical.sort()
	return {"accepted": true, "failure_code": "", "source_receipt_ids": canonical}


func _valid_public_receipt_id(value: String) -> bool:
	if not value.begins_with(PUBLIC_RECEIPT_ID_PREFIX) or value.length() > MAX_RECEIPT_ID_LENGTH:
		return false
	for character_variant: Variant in value:
		var character := str(character_variant)
		if not ((character >= "a" and character <= "z") or (character >= "0" and character <= "9") or character in [".", "-", "_", ":"]):
			return false
	return not _string_has_forbidden_marker(value)


func _is_pure_public_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is String or value is StringName:
		return not _string_has_forbidden_marker(str(value))
	if value is Dictionary:
		for key_variant: Variant in value as Dictionary:
			var key := str(key_variant).to_lower()
			if _forbidden_key(key) or not _is_pure_public_data((value as Dictionary)[key_variant]):
				return false
	elif value is Array:
		for entry_variant: Variant in value as Array:
			if not _is_pure_public_data(entry_variant):
				return false
	return true


func _forbidden_key(key: String) -> bool:
	return FORBIDDEN_KEYS.has(key) \
		or key.begins_with("private_") \
		or key.begins_with("hidden_") \
		or key.begins_with("ai_") \
		or key.ends_with("_player") \
		or key.ends_with("_seat") \
		or key.ends_with("_actor") \
		or key.ends_with("_owner") \
		or key.ends_with("_profile") \
		or key.ends_with("_target") \
		or key.ends_with("_bid") \
		or key.ends_with("_weight") \
		or key.ends_with("_score") \
		or key.ends_with("_reason") \
		or key.ends_with("_plan") \
		or key.ends_with("_fingerprint")


func _string_has_forbidden_marker(value: String) -> bool:
	var lowered := value.to_lower()
	for marker_variant: Variant in FORBIDDEN_VALUE_MARKERS:
		if lowered.contains(str(marker_variant)):
			return true
	return false


func _keys_exact(value: Dictionary, expected: Array) -> bool:
	var actual := value.keys()
	actual.sort()
	var wanted := expected.duplicate()
	wanted.sort()
	return actual == wanted


func _failure(code: String) -> Dictionary:
	return {"accepted": false, "failure_code": code, "receipt": {}}

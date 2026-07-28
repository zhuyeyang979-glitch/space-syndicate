@tool
extends RefCounted
class_name AiCardBatchObservationV1

const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")
const TARGET = preload("res://scripts/semantic/card_batch_prebound_target_spec_v1.gd")
const INVENTORY = preload("res://scripts/semantic/card_batch_inventory_state_v1.gd")

const SCHEMA_VERSION := 1
const RULESET_ID := "V0.7_REFERENCE_ONLY"
const VISIBILITY_SCOPE_ID := "actor_private"
const AUTHORITY_OWNER_ID := "v07.card_batch.ai_observation_source_owner.reference"
const WINDOW_DURATION_USEC := 30_000_000
const PHASE_CARD_WINDOW_OPEN := "CARD_WINDOW_OPEN"
const PHASES: Array[String] = [
	"CARD_WINDOW_CLOSED",
	PHASE_CARD_WINDOW_OPEN,
	"CARD_WINDOW_LOCKING",
	"RESOLUTION_ORDER_BUILD",
	"RESOLUTION_ORDER_REVEAL",
	"CARD_RESOLUTION_ACTIVE",
	"CARD_EFFECT_COMMIT",
	"CARD_AFTERMATH",
	"BATCH_AFTERMATH",
	"BATCH_COMPLETE",
]
const SOURCE_POOLS: Array[String] = [
	"normal_hand",
	"commodity_inventory",
	"bound_action_inventory",
]
const SUBMITTABLE_ACTION_CLASSES: Array[String] = [
	"normal_card",
	"commodity_card",
	"proactive_defense",
	"insurance",
	"batch_interference",
	"batch_action",
]
const TARGET_VISIBILITY_SCOPES: Array[String] = ["public", "actor_private"]
const SOURCE_FIELDS: Array[String] = [
	"schema_version",
	"ruleset_id",
	"viewer_actor_id",
	"viewer_seat_index",
	"visibility_scope_id",
	"batch_id",
	"batch_revision",
	"window_id",
	"window_remaining_phase_time_usec",
	"source_revision",
	"phase",
	"own_inventory",
	"legal_candidates",
	"public_resolution_receipts",
]
const AUTHORIZATION_FIELDS: Array[String] = [
	"schema_version",
	"authority_owner_id",
	"authorization_id",
	"viewer_actor_id",
	"viewer_seat_index",
	"visibility_scope_id",
	"batch_id",
	"batch_revision",
	"window_id",
	"source_revision",
	"authorized_source_fingerprint",
	"authorization_fingerprint",
]
const OBSERVATION_FIELDS: Array[String] = [
	"schema_version",
	"ruleset_id",
	"observation_id",
	"viewer_actor_id",
	"viewer_seat_index",
	"visibility_scope_id",
	"batch_id",
	"batch_revision",
	"window_id",
	"window_remaining_phase_time_usec",
	"source_revision",
	"phase",
	"own_inventory",
	"legal_candidates",
	"public_resolution_receipts",
	"authority_receipt",
	"observation_fingerprint",
]
const CANDIDATE_FIELDS: Array[String] = [
	"card_instance_id",
	"card_semantic_id",
	"source_pool",
	"source_revision",
	"action_class",
	"order_priority",
	"submission_sequence",
	"base_utility",
	"urgency",
	"legal_target_options",
]
const TARGET_OPTION_FIELDS: Array[String] = [
	"visibility_scope_id",
	"target_binding",
	"target_value",
	"threat_level",
	"synergy_value",
]
const PUBLIC_RECEIPT_FIELDS: Array[String] = [
	"receipt_id",
	"result_kind",
	"public_target_ids",
	"outcome_code",
	"batch_revision",
]
const NORMAL_CARD_FIELDS: Array[String] = [
	"card_instance_id",
	"card_semantic_id",
	"source_revision",
]
const COMMODITY_CARD_FIELDS: Array[String] = [
	"card_instance_id",
	"card_semantic_id",
	"commodity_id",
	"commodity_level",
	"source_revision",
]
const BOUND_ACTION_FIELDS: Array[String] = [
	"bound_action_id",
	"card_semantic_id",
	"action_kind",
	"source_kind",
	"source_id",
	"source_revision",
	"cooldown_remaining_phase_time_usec",
	"charges",
]
const ALLOWED_AUTHORED_PARAMETER_FIELDS: Array[String] = [
	"effect_kind",
	"defense_kind",
	"duration_batches",
	"prevention_count",
	"reduction_amount",
	"insurance_kind",
	"commodity_id",
	"facility_kind",
	"interference_kind",
	"damage_class",
	"route_kind",
	"status_kind",
	"application_rule_id",
]
const FORBIDDEN_PRIVACY_TOKENS: Array[String] = [
	"other_player_hand",
	"other_player_inventory",
	"opponent_hand",
	"opponent_inventory",
	"rival_hand",
	"rival_inventory",
	"all_hands",
	"all_inventories",
	"private_hand_by_actor",
	"private_inventory_by_actor",
	"hidden_owner",
	"anonymous_true_owner",
	"unrevealed_submission",
	"unrevealed_target",
	"future_rack",
	"future_supply",
	"future_order",
	"future_resolution_order",
	"hidden_lead",
	"hidden_first_player",
	"other_ai_plan",
	"ai_plan_by_actor",
	"decision_samples",
	"learning_metadata",
	"counter_window",
	"counter_stack",
	"pending_counter",
	"counter_submission",
	"rng_state",
	"rng_seed",
	"run_rng",
	"core_state",
	"authority_state",
	"opponent_cash",
	"rival_cash",
	"other_player_cash",
	"all_cash",
	"hidden_cash",
	"private_cash",
]


static func build_authorized(source: Dictionary, authority_owner_id: String) -> Dictionary:
	if authority_owner_id != AUTHORITY_OWNER_ID:
		return {}
	var source_report := validate_source(source)
	if not bool(source_report.get("valid", false)):
		return {}
	var normalized := _normalized_source(source_report.get("normalized", {}))
	var source_fingerprint := PURE.stable_fingerprint(normalized)
	if source_fingerprint.is_empty():
		return {}
	var authority_receipt := _build_authority_receipt(
		normalized,
		authority_owner_id,
		source_fingerprint
	)
	if authority_receipt.is_empty():
		return {}
	var observation := {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"observation_id": "ai-card-batch-observation:%s" % source_fingerprint.left(24),
		"viewer_actor_id": str(normalized.get("viewer_actor_id", "")),
		"viewer_seat_index": int(normalized.get("viewer_seat_index", -1)),
		"visibility_scope_id": VISIBILITY_SCOPE_ID,
		"batch_id": str(normalized.get("batch_id", "")),
		"batch_revision": int(normalized.get("batch_revision", -1)),
		"window_id": str(normalized.get("window_id", "")),
		"window_remaining_phase_time_usec": int(
			normalized.get("window_remaining_phase_time_usec", -1)
		),
		"source_revision": int(normalized.get("source_revision", -1)),
		"phase": str(normalized.get("phase", "")),
		"own_inventory": (
			normalized.get("own_inventory", {}) as Dictionary
		).duplicate(true),
		"legal_candidates": (
			normalized.get("legal_candidates", []) as Array
		).duplicate(true),
		"public_resolution_receipts": (
			normalized.get("public_resolution_receipts", []) as Array
		).duplicate(true),
		"authority_receipt": authority_receipt,
		"observation_fingerprint": "",
	}
	observation["observation_fingerprint"] = _fingerprint_without_field(
		observation,
		"observation_fingerprint"
	)
	return observation if bool(validate(observation).get("valid", false)) else {}


static func validate_source(value: Dictionary) -> Dictionary:
	if not PURE.has_exact_keys(value, SOURCE_FIELDS):
		return _invalid("ai_card_batch_source_fields_invalid")
	if int(value.get("schema_version", -1)) != SCHEMA_VERSION \
			or str(value.get("ruleset_id", "")) != RULESET_ID:
		return _invalid("ai_card_batch_source_schema_invalid")
	var common_error := _common_payload_error(value)
	if not common_error.is_empty():
		return _invalid(common_error)
	var viewer_actor_id := str(value.get("viewer_actor_id", ""))
	if viewer_actor_id.is_empty() or int(value.get("viewer_seat_index", -1)) < 0:
		return _invalid("ai_card_batch_source_viewer_invalid")
	if str(value.get("visibility_scope_id", "")) != VISIBILITY_SCOPE_ID:
		return _invalid("ai_card_batch_source_scope_invalid")
	if str(value.get("batch_id", "")).is_empty() \
			or str(value.get("window_id", "")).is_empty():
		return _invalid("ai_card_batch_source_identity_invalid")
	for field in ["batch_revision", "source_revision", "window_remaining_phase_time_usec"]:
		if int(value.get(field, -1)) < 0:
			return _invalid("ai_card_batch_source_revision_invalid")
	if int(value.get("window_remaining_phase_time_usec", 0)) > WINDOW_DURATION_USEC:
		return _invalid("ai_card_batch_source_window_time_invalid")
	if str(value.get("phase", "")) not in PHASES:
		return _invalid("ai_card_batch_source_phase_invalid")
	if not (value.get("own_inventory") is Dictionary):
		return _invalid("ai_card_batch_source_inventory_invalid")
	var inventory := value.get("own_inventory", {}) as Dictionary
	var phase := str(value.get("phase", ""))
	if phase == PHASE_CARD_WINDOW_OPEN:
		var inventory_report := INVENTORY.validate(inventory)
		if not bool(inventory_report.get("valid", false)) \
				or str(inventory.get("actor_id", "")) != viewer_actor_id:
			return _invalid("ai_card_batch_source_inventory_authorization_invalid")
		var inventory_projection_error := _inventory_projection_error(inventory)
		if not inventory_projection_error.is_empty():
			return _invalid(inventory_projection_error)
	elif not inventory.is_empty():
		return _invalid("ai_card_batch_source_resolution_private_inventory_forbidden")
	if not (value.get("legal_candidates") is Array):
		return _invalid("ai_card_batch_source_candidates_invalid")
	var seen_card_instances: Array[String] = []
	for candidate_variant in value.get("legal_candidates", []) as Array:
		if not (candidate_variant is Dictionary):
			return _invalid("ai_card_batch_source_candidate_invalid")
		var candidate := candidate_variant as Dictionary
		var candidate_error := _candidate_error(candidate, inventory)
		if not candidate_error.is_empty():
			return _invalid(candidate_error)
		var card_instance_id := str(candidate.get("card_instance_id", ""))
		if card_instance_id in seen_card_instances:
			return _invalid("ai_card_batch_source_candidate_duplicate")
		seen_card_instances.append(card_instance_id)
	if str(value.get("phase", "")) != PHASE_CARD_WINDOW_OPEN \
			and not seen_card_instances.is_empty():
		return _invalid("ai_card_batch_source_resolution_candidates_forbidden")
	if not (value.get("public_resolution_receipts") is Array):
		return _invalid("ai_card_batch_source_receipts_invalid")
	var seen_receipt_ids: Array[String] = []
	for receipt_variant in value.get("public_resolution_receipts", []) as Array:
		if not (receipt_variant is Dictionary):
			return _invalid("ai_card_batch_source_receipt_invalid")
		var receipt := receipt_variant as Dictionary
		var receipt_error := _public_receipt_error(receipt)
		if not receipt_error.is_empty():
			return _invalid(receipt_error)
		var receipt_id := str(receipt.get("receipt_id", ""))
		if receipt_id in seen_receipt_ids:
			return _invalid("ai_card_batch_source_receipt_duplicate")
		seen_receipt_ids.append(receipt_id)
	return {
		"valid": true,
		"reason_code": "ai_card_batch_source_valid",
		"normalized": value.duplicate(true),
	}


static func validate(value: Dictionary) -> Dictionary:
	if not PURE.has_exact_keys(value, OBSERVATION_FIELDS):
		return _invalid("ai_card_batch_observation_fields_invalid")
	if int(value.get("schema_version", -1)) != SCHEMA_VERSION \
			or str(value.get("ruleset_id", "")) != RULESET_ID:
		return _invalid("ai_card_batch_observation_schema_invalid")
	var common_error := _common_payload_error(value)
	if not common_error.is_empty():
		return _invalid(common_error)
	var source := _source_from_observation(value)
	var source_report := validate_source(source)
	if not bool(source_report.get("valid", false)):
		return _invalid(str(source_report.get("reason_code", "ai_card_batch_observation_source_invalid")))
	if not (value.get("authority_receipt") is Dictionary):
		return _invalid("ai_card_batch_observation_authority_receipt_invalid")
	var normalized_source := _normalized_source(source)
	var authority_error := _authority_receipt_error(
		value.get("authority_receipt", {}) as Dictionary,
		normalized_source
	)
	if not authority_error.is_empty():
		return _invalid(authority_error)
	var source_fingerprint := PURE.stable_fingerprint(normalized_source)
	if str(value.get("observation_id", "")) \
			!= "ai-card-batch-observation:%s" % source_fingerprint.left(24):
		return _invalid("ai_card_batch_observation_id_invalid")
	if str(value.get("observation_fingerprint", "")) \
			!= _fingerprint_without_field(value, "observation_fingerprint"):
		return _invalid("ai_card_batch_observation_fingerprint_invalid")
	return {
		"valid": true,
		"reason_code": "ai_card_batch_observation_valid",
		"normalized": value.duplicate(true),
	}


static func fingerprint(value: Dictionary) -> String:
	return str(value.get("observation_fingerprint", "")) \
		if bool(validate(value).get("valid", false)) else ""


static func _candidate_error(candidate: Dictionary, inventory: Dictionary) -> String:
	if not PURE.has_exact_keys(candidate, CANDIDATE_FIELDS):
		return "ai_card_batch_candidate_fields_invalid"
	var common_error := _common_payload_error(candidate)
	if not common_error.is_empty():
		return common_error
	var card_instance_id := str(candidate.get("card_instance_id", ""))
	var card_semantic_id := str(candidate.get("card_semantic_id", ""))
	var source_pool := str(candidate.get("source_pool", ""))
	var action_class := str(candidate.get("action_class", ""))
	if card_instance_id.is_empty() or card_semantic_id.is_empty():
		return "ai_card_batch_candidate_identity_invalid"
	if source_pool not in SOURCE_POOLS or action_class not in SUBMITTABLE_ACTION_CLASSES:
		return "ai_card_batch_candidate_semantics_invalid"
	if int(candidate.get("source_revision", -1)) < 0 \
			or int(candidate.get("submission_sequence", -1)) < 0:
		return "ai_card_batch_candidate_revision_invalid"
	if not _candidate_matches_inventory(candidate, inventory):
		return "ai_card_batch_candidate_not_in_own_inventory"
	if not (candidate.get("base_utility") is int) \
			or not (candidate.get("urgency") is int):
		return "ai_card_batch_candidate_score_invalid"
	if not (candidate.get("legal_target_options") is Array) \
			or (candidate.get("legal_target_options", []) as Array).is_empty():
		return "ai_card_batch_candidate_targets_invalid"
	var seen_target_fingerprints: Array[String] = []
	for option_variant in candidate.get("legal_target_options", []) as Array:
		if not (option_variant is Dictionary):
			return "ai_card_batch_target_option_invalid"
		var option := option_variant as Dictionary
		var option_error := _target_option_error(option)
		if not option_error.is_empty():
			return option_error
		var target_fingerprint := TARGET.fingerprint(
			option.get("target_binding", {}) as Dictionary
		)
		if target_fingerprint in seen_target_fingerprints:
			return "ai_card_batch_target_option_duplicate"
		seen_target_fingerprints.append(target_fingerprint)
	return ""


static func _target_option_error(option: Dictionary) -> String:
	if not PURE.has_exact_keys(option, TARGET_OPTION_FIELDS):
		return "ai_card_batch_target_option_fields_invalid"
	var common_error := _common_payload_error(option)
	if not common_error.is_empty():
		return common_error
	if str(option.get("visibility_scope_id", "")) not in TARGET_VISIBILITY_SCOPES:
		return "ai_card_batch_target_option_scope_invalid"
	if not (option.get("target_binding") is Dictionary):
		return "ai_card_batch_target_option_binding_invalid"
	var binding := option.get("target_binding", {}) as Dictionary
	if not bool(TARGET.validate(binding).get("valid", false)):
		return "ai_card_batch_target_option_binding_invalid"
	var authored_parameters := binding.get("authored_parameters", {}) as Dictionary
	for key_variant in authored_parameters.keys():
		if str(key_variant) not in ALLOWED_AUTHORED_PARAMETER_FIELDS:
			return "ai_card_batch_target_option_parameter_not_allowlisted"
		var parameter_value: Variant = authored_parameters.get(key_variant)
		if typeof(parameter_value) not in [
			TYPE_BOOL,
			TYPE_INT,
			TYPE_FLOAT,
			TYPE_STRING,
			TYPE_STRING_NAME,
		]:
			return "ai_card_batch_target_option_parameter_value_invalid"
	for field in ["target_value", "threat_level", "synergy_value"]:
		if not (option.get(field) is int):
			return "ai_card_batch_target_option_score_invalid"
	return ""


static func _inventory_projection_error(inventory: Dictionary) -> String:
	for card_variant in inventory.get("normal_cards", []) as Array:
		if not (card_variant is Dictionary) \
				or not PURE.has_exact_keys(card_variant as Dictionary, NORMAL_CARD_FIELDS):
			return "ai_card_batch_normal_card_projection_fields_invalid"
	for card_variant in inventory.get("commodity_cards", []) as Array:
		if not (card_variant is Dictionary) \
				or not PURE.has_exact_keys(card_variant as Dictionary, COMMODITY_CARD_FIELDS):
			return "ai_card_batch_commodity_projection_fields_invalid"
	for action_variant in inventory.get("bound_actions", []) as Array:
		if not (action_variant is Dictionary) \
				or not PURE.has_exact_keys(action_variant as Dictionary, BOUND_ACTION_FIELDS):
			return "ai_card_batch_bound_action_projection_fields_invalid"
	return ""


static func _candidate_matches_inventory(candidate: Dictionary, inventory: Dictionary) -> bool:
	var source_pool := str(candidate.get("source_pool", ""))
	var card_instance_id := str(candidate.get("card_instance_id", ""))
	var card_semantic_id := str(candidate.get("card_semantic_id", ""))
	var action_class := str(candidate.get("action_class", ""))
	if source_pool == "normal_hand":
		if action_class not in ["normal_card", "proactive_defense", "insurance", "batch_interference"]:
			return false
		return _card_array_contains(
			inventory.get("normal_cards", []) as Array,
			card_instance_id,
			card_semantic_id
		)
	if source_pool == "commodity_inventory":
		return action_class == "commodity_card" \
			and _card_array_contains(
				inventory.get("commodity_cards", []) as Array,
				card_instance_id,
				card_semantic_id
			)
	if source_pool == "bound_action_inventory":
		if action_class != "batch_action":
			return false
		for action_variant in inventory.get("bound_actions", []) as Array:
			if not (action_variant is Dictionary):
				continue
			var action := action_variant as Dictionary
			if str(action.get("bound_action_id", "")) == card_instance_id \
					and str(action.get("card_semantic_id", "")) == card_semantic_id \
					and str(action.get("action_kind", "")) == "batch_action" \
					and int(action.get("charges", 0)) > 0 \
					and int(action.get("cooldown_remaining_phase_time_usec", 1)) == 0:
				return true
	return false


static func _card_array_contains(
	cards: Array,
	card_instance_id: String,
	card_semantic_id: String
) -> bool:
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		if str(card.get("card_instance_id", "")) == card_instance_id \
				and str(card.get("card_semantic_id", "")) == card_semantic_id:
			return true
	return false


static func _public_receipt_error(receipt: Dictionary) -> String:
	if not PURE.has_exact_keys(receipt, PUBLIC_RECEIPT_FIELDS):
		return "ai_card_batch_public_receipt_fields_invalid"
	var common_error := _common_payload_error(receipt)
	if not common_error.is_empty():
		return common_error
	if str(receipt.get("receipt_id", "")).is_empty() \
			or str(receipt.get("result_kind", "")).is_empty() \
			or str(receipt.get("outcome_code", "")).is_empty() \
			or int(receipt.get("batch_revision", -1)) < 0:
		return "ai_card_batch_public_receipt_value_invalid"
	var target_ids_variant: Variant = receipt.get("public_target_ids")
	if not (target_ids_variant is Array):
		return "ai_card_batch_public_receipt_targets_invalid"
	var target_ids := PURE.string_array(target_ids_variant, true)
	if target_ids.size() != (target_ids_variant as Array).size():
		return "ai_card_batch_public_receipt_targets_invalid"
	return ""


static func _build_authority_receipt(
	source: Dictionary,
	authority_owner_id: String,
	source_fingerprint: String
) -> Dictionary:
	var receipt := {
		"schema_version": SCHEMA_VERSION,
		"authority_owner_id": authority_owner_id,
		"authorization_id": "ai-card-batch-auth:%s" % source_fingerprint.left(24),
		"viewer_actor_id": str(source.get("viewer_actor_id", "")),
		"viewer_seat_index": int(source.get("viewer_seat_index", -1)),
		"visibility_scope_id": VISIBILITY_SCOPE_ID,
		"batch_id": str(source.get("batch_id", "")),
		"batch_revision": int(source.get("batch_revision", -1)),
		"window_id": str(source.get("window_id", "")),
		"source_revision": int(source.get("source_revision", -1)),
		"authorized_source_fingerprint": source_fingerprint,
		"authorization_fingerprint": "",
	}
	receipt["authorization_fingerprint"] = _fingerprint_without_field(
		receipt,
		"authorization_fingerprint"
	)
	return receipt


static func _authority_receipt_error(receipt: Dictionary, source: Dictionary) -> String:
	if not PURE.has_exact_keys(receipt, AUTHORIZATION_FIELDS):
		return "ai_card_batch_authority_receipt_fields_invalid"
	if int(receipt.get("schema_version", -1)) != SCHEMA_VERSION \
			or str(receipt.get("authority_owner_id", "")) != AUTHORITY_OWNER_ID:
		return "ai_card_batch_authority_owner_invalid"
	var source_fingerprint := PURE.stable_fingerprint(source)
	if str(receipt.get("authorization_id", "")) \
			!= "ai-card-batch-auth:%s" % source_fingerprint.left(24) \
			or str(receipt.get("authorized_source_fingerprint", "")) != source_fingerprint:
		return "ai_card_batch_authority_source_binding_invalid"
	for field in [
		"viewer_actor_id",
		"viewer_seat_index",
		"visibility_scope_id",
		"batch_id",
		"batch_revision",
		"window_id",
		"source_revision",
	]:
		if receipt.get(field) != source.get(field):
			return "ai_card_batch_authority_field_binding_invalid"
	if str(receipt.get("authorization_fingerprint", "")) \
			!= _fingerprint_without_field(receipt, "authorization_fingerprint"):
		return "ai_card_batch_authority_fingerprint_invalid"
	return ""


static func _normalized_source(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	var inventory := (result.get("own_inventory", {}) as Dictionary).duplicate(true)
	if not inventory.is_empty():
		var normal_cards := (inventory.get("normal_cards", []) as Array).duplicate(true)
		var commodity_cards := (inventory.get("commodity_cards", []) as Array).duplicate(true)
		var bound_actions := (inventory.get("bound_actions", []) as Array).duplicate(true)
		normal_cards.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("card_instance_id", "")) < str(right.get("card_instance_id", ""))
		)
		commodity_cards.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("card_instance_id", "")) < str(right.get("card_instance_id", ""))
		)
		bound_actions.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return str(left.get("bound_action_id", "")) < str(right.get("bound_action_id", ""))
		)
		inventory["normal_cards"] = normal_cards
		inventory["commodity_cards"] = commodity_cards
		inventory["bound_actions"] = bound_actions
	result["own_inventory"] = inventory
	var candidates := (result.get("legal_candidates", []) as Array).duplicate(true)
	for index in range(candidates.size()):
		var candidate := (candidates[index] as Dictionary).duplicate(true)
		var options := (candidate.get("legal_target_options", []) as Array).duplicate(true)
		options.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return _target_option_key(left) < _target_option_key(right)
		)
		candidate["legal_target_options"] = options
		candidates[index] = candidate
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _candidate_key(left) < _candidate_key(right)
	)
	result["legal_candidates"] = candidates
	var receipts := (result.get("public_resolution_receipts", []) as Array).duplicate(true)
	receipts.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("receipt_id", "")) < str(right.get("receipt_id", ""))
	)
	result["public_resolution_receipts"] = receipts
	return result


static func _candidate_key(candidate: Dictionary) -> String:
	return "%s|%s|%s" % [
		str(candidate.get("source_pool", "")),
		str(candidate.get("card_instance_id", "")),
		str(candidate.get("card_semantic_id", "")),
	]


static func _target_option_key(option: Dictionary) -> String:
	var binding: Dictionary = option.get("target_binding", {})
	return "%s|%s" % [
		str(option.get("visibility_scope_id", "")),
		TARGET.fingerprint(binding),
	]


static func _source_from_observation(observation: Dictionary) -> Dictionary:
	return {
		"schema_version": observation.get("schema_version"),
		"ruleset_id": observation.get("ruleset_id"),
		"viewer_actor_id": observation.get("viewer_actor_id"),
		"viewer_seat_index": observation.get("viewer_seat_index"),
		"visibility_scope_id": observation.get("visibility_scope_id"),
		"batch_id": observation.get("batch_id"),
		"batch_revision": observation.get("batch_revision"),
		"window_id": observation.get("window_id"),
		"window_remaining_phase_time_usec": observation.get(
			"window_remaining_phase_time_usec"
		),
		"source_revision": observation.get("source_revision"),
		"phase": observation.get("phase"),
		"own_inventory": (
			observation.get("own_inventory", {}) as Dictionary
		).duplicate(true),
		"legal_candidates": (
			observation.get("legal_candidates", []) as Array
		).duplicate(true),
		"public_resolution_receipts": (
			observation.get("public_resolution_receipts", []) as Array
		).duplicate(true),
	}


static func _common_payload_error(value: Variant) -> String:
	if not PURE.is_pure_json_data(value):
		return "ai_card_batch_payload_not_pure_data"
	var runtime_path := PURE.first_forbidden_runtime_key(value)
	if not runtime_path.is_empty():
		return "ai_card_batch_payload_runtime_reference:%s" % runtime_path
	var counter_path := PURE.first_retired_counter_key(value)
	if not counter_path.is_empty():
		return "ai_card_batch_payload_retired_counter:%s" % counter_path
	var privacy_path := _first_privacy_violation(value)
	if not privacy_path.is_empty():
		return "ai_card_batch_payload_privacy_violation:%s" % privacy_path
	return ""


static func _first_privacy_violation(value: Variant, path: String = "root") -> String:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := _privacy_token(str(key_variant))
			if _contains_forbidden_privacy_token(key):
				return "%s.%s" % [path, str(key_variant)]
			var nested := _first_privacy_violation(
				(value as Dictionary).get(key_variant),
				"%s.%s" % [path, str(key_variant)]
			)
			if not nested.is_empty():
				return nested
	elif value is Array:
		for index in range((value as Array).size()):
			var nested := _first_privacy_violation(
				(value as Array)[index],
				"%s[%d]" % [path, index]
			)
			if not nested.is_empty():
				return nested
	elif value is String or value is StringName:
		var text := _privacy_token(str(value))
		if _contains_forbidden_privacy_token(text):
			return path
	return ""


static func _contains_forbidden_privacy_token(value: String) -> bool:
	for token in FORBIDDEN_PRIVACY_TOKENS:
		if value.contains(token):
			return true
	return false


static func _privacy_token(value: String) -> String:
	return value.strip_edges().to_lower().replace("-", "_").replace(" ", "_")


static func _fingerprint_without_field(value: Dictionary, field: String) -> String:
	var copy := value.duplicate(true)
	copy[field] = ""
	return PURE.stable_fingerprint(copy)


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code, "normalized": {}}

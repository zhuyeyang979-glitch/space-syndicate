extends RefCounted
class_name V07CanonicalRngAdapter

## Pure adapter between inherited detached Core Save payloads and the V0.7.3
## RNG ledger. It stores, advances, seeds, and restores no RNG. A ledger is only
## accepted while it remains byte-for-byte equal to the embedded owner state.

const SCHEMA_VERSION := 2
const OWNER_SCHEMA_VERSION := 3
const UNIFIED_STATE_VERSION := 5
const DBG_STATE_VERSION := 3
const ADAPTER_ID := "space_syndicate.v073.canonical_rng_adapter.v3"
const RULESET_ID := "v0.7.3"
const BALANCE_PROFILE_ID := "V073_STARTER_FREE_FIXED_ORDER_CONTENTION"
const BALANCE_PROFILE_FINGERPRINT := (
	"a413ad0ddd8a06b15ccee943d9cd93c6f7941fc66ce901a1f44934797f50231c"
)
const SOURCE_CORE_RULESET_ID := "v0.7.2"
const SOURCE_CORE_BALANCE_PROFILE_ID := "V072_STARTER_FREE_FAST"
const SOURCE_CORE_BALANCE_PROFILE_FINGERPRINT := (
	"b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48"
)

const DBG_PROFILE_ID := "dbg_tagged_sha256_counter_v1"
const UNIFIED_PROFILE_ID := "unified_park_miller_embedded_v1"
const DBG_AUTHORITY_ID := "v072.personal_dbg.core_authority.v3"
const UNIFIED_AUTHORITY_ID := "v072.unified_track.core_authority.v3"
const DBG_SAVE_SECTION_ID := "personal_dbg_and_merge"
const UNIFIED_SAVE_SECTION_ID := "unified_card_track_cycle"
const DBG_ALGORITHM_ID := "sha256.owner_bound_counter.v1"
const UNIFIED_ALGORITHM_ID := "park_miller_48271_mod_2147483647.v1"

const RNG_MODULUS := 2147483647
const RNG_MULTIPLIER := 48271
const MIN_ROSTER_SIZE := 3
const MAX_ROSTER_SIZE := 8

const LOGICAL_STREAM_IDS := [
	"starter_deck_shuffle",
	"normal_deck_reshuffle_by_player",
	"unified_track_type_draw",
	"unified_track_color_draw",
	"unified_track_normal_card_draw",
	"unified_track_commodity_draw",
	"initial_hidden_lead_order",
]
const DBG_STREAM_IDS := [
	"starter_deck_shuffle",
	"normal_deck_reshuffle_by_player",
]
const UNIFIED_STREAM_IDS := [
	"unified_track_type_draw",
	"unified_track_color_draw",
	"unified_track_normal_card_draw",
	"unified_track_commodity_draw",
	"initial_hidden_lead_order",
]
const ROW_FIELDS := [
	"schema_version",
	"stream_id",
	"stream_instance_id",
	"state_profile_id",
	"authoritative_owner_id",
	"save_section_id",
	"state",
	"state_fingerprint",
]
const TAGGED_INT64_FIELDS := ["type", "decimal"]
const DBG_RNG_STATE_FIELDS := [
	"schema_version",
	"stream_id",
	"stream_instance_id",
	"authoritative_owner_id",
	"algorithm_id",
	"seed",
	"cursor",
	"stream_revision",
	"state_fingerprint",
]
const UNIFIED_RNG_STATE_FIELDS := ["rng_state", "rng_draw_count"]

const UNIFIED_SAVE_FIELDS := [
	"schema_version",
	"interface_id",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"domain_id",
	"state_version",
	"source_revision",
	"source_core_fingerprint",
	"authority_state",
	"save_fingerprint",
]
const UNIFIED_AUTHORITY_STATE_FIELDS := [
	"schema_version",
	"state_version",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"domain_id",
	"revision",
	"match_seed",
	"match_instance_id",
	"match_instance_id_explicit",
	"roster_ids",
	"track_state",
	"type_supply_state",
	"normal_supply_state",
	"commodity_supply_state",
	"color_cycle_state",
	"batch_boundary_state",
	"hidden_lead_cycle_state",
	"projection_revisions",
	"processed_requests",
	"revision_lineage",
]
const TYPE_SUPPLY_FIELDS := [
	"stream_id",
	"ratio_basis_points",
	"bag",
	"cursor",
	"bag_cycle",
	"rng_state",
	"rng_draw_count",
]
const DEFINITION_SUPPLY_FIELDS := [
	"stream_id",
	"card_kind",
	"templates",
	"bag",
	"cursor",
	"bag_cycle",
	"rng_state",
	"rng_draw_count",
]
const COLOR_SUPPLY_FIELDS := [
	"stream_id",
	"bag",
	"cursor",
	"bag_cycle",
	"rng_state",
	"rng_draw_count",
]
const HIDDEN_LEAD_FIELDS := [
	"state_id",
	"stream_id",
	"fixed_order",
	"macro_round_number",
	"direction",
	"round_order",
	"lead_cursor",
	"current_lead_id",
	"completed_lead_ids",
	"rng_state",
	"rng_draw_count",
]

const DBG_SAVE_FIELDS := [
	"schema_id",
	"schema_version",
	"state_version",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"domain_id",
	"privacy_scope",
	"typed_state_contracts",
	"state",
	"document_section",
	"state_fingerprint",
	"core_fingerprint",
]
const DBG_STATE_FIELDS := [
	"schema_version",
	"state_version",
	"ruleset_id",
	"domain_id",
	"owner_player_id",
	"root_seed",
	"revision",
	"phase",
	"batch_index",
	"draw_pile",
	"hand",
	"committed_escrow",
	"discard",
	"merge_history",
	"next_instance_sequence",
	"commodity_inventory",
	"commodity_claim_history",
	"commodity_merge_history",
	"next_commodity_instance_sequence",
	"bound_source_state",
	"local_queue_state",
	"starter_rng",
	"reshuffle_rng",
	"processed_intent_ids",
	"receipt_journal",
	"normal_deck_minimum_count_rule_version",
	"balance_profile_id",
	"balance_profile_fingerprint",
]
const DBG_DOCUMENT_FIELDS := [
	"section_id",
	"section_version",
	"state_version",
	"ruleset_id",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"semantic_owner",
	"privacy",
	"state_revision",
	"players",
	"merge_instance_allocator_cursor",
	"processed_intent_ids",
	"receipt_ledger",
	"rng_stream_states",
]


static func adapter_contract() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"adapter_id": ADAPTER_ID,
		"ruleset_id": RULESET_ID,
		"target_ruleset_id": RULESET_ID,
		"v07_direct_resume_allowed": false,
		"logical_stream_ids": LOGICAL_STREAM_IDS.duplicate(),
		"logical_stream_id_count": LOGICAL_STREAM_IDS.size(),
		"state_profile_ids": [DBG_PROFILE_ID, UNIFIED_PROFILE_ID],
		"row_fields": ROW_FIELDS.duplicate(),
		"canonical_row_is_second_rng_authority": false,
		"draw_api_count": 0,
		"production_runtime_connection_count": 0,
	}


static func logical_stream_ids() -> Array:
	return LOGICAL_STREAM_IDS.duplicate()


static func capture_ledger(
	unified_save_state: Dictionary,
	personal_dbg_save_states: Array
) -> Dictionary:
	var unified_reason := _unified_save_error(unified_save_state)
	if not unified_reason.is_empty():
		return _capture_result(false, "unified_%s" % unified_reason, [])

	var unified_authority := (
		unified_save_state.get("authority_state", {}) as Dictionary
	)
	var roster := (unified_authority.get("roster_ids", []) as Array).duplicate(true)
	var personal_index := _personal_save_index(personal_dbg_save_states, roster)
	var personal_reason := str(personal_index.get("reason_code", ""))
	if not personal_reason.is_empty():
		return _capture_result(false, personal_reason, [])
	var saves_by_owner := personal_index.get("saves_by_owner", {}) as Dictionary

	var rows: Array = []
	for owner_variant in roster:
		var owner_id := str(owner_variant)
		var personal_save := saves_by_owner.get(owner_id, {}) as Dictionary
		var personal_state := personal_save.get("state", {}) as Dictionary
		rows.append(_canonical_row(
			"starter_deck_shuffle",
			owner_id,
			DBG_PROFILE_ID,
			DBG_AUTHORITY_ID,
			DBG_SAVE_SECTION_ID,
			personal_state.get("starter_rng", {}) as Dictionary
		))
		rows.append(_canonical_row(
			"normal_deck_reshuffle_by_player",
			owner_id,
			DBG_PROFILE_ID,
			DBG_AUTHORITY_ID,
			DBG_SAVE_SECTION_ID,
			personal_state.get("reshuffle_rng", {}) as Dictionary
		))

	for stream_variant in UNIFIED_STREAM_IDS:
		var stream_id := str(stream_variant)
		var owner_state := _unified_owner_state(unified_authority, stream_id)
		rows.append(_canonical_row(
			stream_id,
			"global",
			UNIFIED_PROFILE_ID,
			UNIFIED_AUTHORITY_ID,
			UNIFIED_SAVE_SECTION_ID,
			_unified_rng_projection(owner_state)
		))

	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_stream := str(left.get("stream_id", ""))
		var right_stream := str(right.get("stream_id", ""))
		if left_stream != right_stream:
			return left_stream < right_stream
		return str(left.get("stream_instance_id", "")) \
			< str(right.get("stream_instance_id", ""))
	)
	var ledger_reason := validate_ledger(rows, roster)
	if not ledger_reason.is_empty():
		return _capture_result(false, "captured_%s" % ledger_reason, [])
	return _capture_result(true, "canonical_rng_ledger_captured", rows)


static func preflight_ledger(
	rng_stream_states: Array,
	unified_save_state: Dictionary,
	personal_dbg_save_states: Array
) -> Dictionary:
	var captured := capture_ledger(unified_save_state, personal_dbg_save_states)
	if not bool(captured.get("accepted", false)):
		return _preflight_result(
			false,
			str(captured.get("reason_code", "canonical_rng_source_invalid")),
			0
		)
	var roster := (
		(unified_save_state.get("authority_state", {}) as Dictionary).get(
			"roster_ids", []
		) as Array
	)
	var ledger_reason := validate_ledger(rng_stream_states, roster)
	if not ledger_reason.is_empty():
		return _preflight_result(
			false,
			"canonical_rng_ledger_invalid.%s" % ledger_reason,
			rng_stream_states.size()
		)
	if rng_stream_states != captured.get("rng_stream_states", []):
		return _preflight_result(
			false,
			"canonical_rng_ledger_embedded_mismatch",
			rng_stream_states.size()
		)
	return _preflight_result(
		true,
		"canonical_rng_ledger_preflight_green",
		rng_stream_states.size()
	)


static func validate_ledger(rng_stream_states: Array, roster_ids: Array) -> String:
	var roster_reason := _roster_error(roster_ids)
	if not roster_reason.is_empty():
		return roster_reason
	if not is_strict_pure_data(rng_stream_states):
		return "ledger_not_strict_pure_data"
	var expected_count := 5 + (2 * roster_ids.size())
	if rng_stream_states.size() != expected_count:
		return "ledger_concrete_stream_count_invalid"

	var seen_pairs: Dictionary = {}
	var logical_counts: Dictionary = {}
	var previous_stream_id := ""
	var previous_instance_id := ""
	for index in range(rng_stream_states.size()):
		var row_variant: Variant = rng_stream_states[index]
		if not (row_variant is Dictionary):
			return "ledger_row_not_dictionary"
		var row := row_variant as Dictionary
		var row_reason := _row_error(row, roster_ids)
		if not row_reason.is_empty():
			return row_reason
		var stream_id := str(row.get("stream_id", ""))
		var instance_id := str(row.get("stream_instance_id", ""))
		if index > 0 and (
			stream_id < previous_stream_id
			or (stream_id == previous_stream_id and instance_id <= previous_instance_id)
		):
			return "ledger_row_order_invalid"
		previous_stream_id = stream_id
		previous_instance_id = instance_id
		var pair_key := "%s\u001f%s" % [stream_id, instance_id]
		if seen_pairs.has(pair_key):
			return "ledger_stream_instance_duplicate"
		seen_pairs[pair_key] = true
		logical_counts[stream_id] = int(logical_counts.get(stream_id, 0)) + 1

	if logical_counts.size() != LOGICAL_STREAM_IDS.size():
		return "ledger_logical_stream_set_invalid"
	for stream_variant in LOGICAL_STREAM_IDS:
		var stream_id := str(stream_variant)
		var expected_instances := roster_ids.size() if stream_id in DBG_STREAM_IDS else 1
		if int(logical_counts.get(stream_id, 0)) != expected_instances:
			return "ledger_stream_instance_count_invalid"
		if stream_id in DBG_STREAM_IDS:
			for owner_variant in roster_ids:
				var pair_key := "%s\u001f%s" % [stream_id, str(owner_variant)]
				if not seen_pairs.has(pair_key):
					return "ledger_player_stream_instance_missing"
		elif not seen_pairs.has("%s\u001fglobal" % stream_id):
			return "ledger_global_stream_instance_missing"
	return ""


static func encode_ledger_json(rng_stream_states: Array, roster_ids: Array) -> String:
	if not validate_ledger(rng_stream_states, roster_ids).is_empty():
		return ""
	return _canonical_json(rng_stream_states)


static func decode_ledger_json(encoded: String, roster_ids: Array) -> Dictionary:
	if encoded.is_empty():
		return _capture_result(false, "ledger_json_empty", [])
	var parsed: Variant = JSON.parse_string(encoded)
	if not (parsed is Array):
		return _capture_result(false, "ledger_json_shape_invalid", [])
	var normalized: Variant = _normalize_json_numbers(parsed)
	if not (normalized is Array):
		return _capture_result(false, "ledger_json_number_invalid", [])
	var rows := normalized as Array
	if _canonical_json(rows) != encoded:
		return _capture_result(false, "ledger_json_not_canonical", [])
	var reason := validate_ledger(rows, roster_ids)
	if not reason.is_empty():
		return _capture_result(false, "ledger_json_%s" % reason, [])
	return _capture_result(true, "canonical_rng_ledger_decoded", rows)


static func canonical_fingerprint(value: Variant, omitted_field: String = "") -> String:
	if not is_strict_pure_data(value):
		return ""
	var source: Variant = value.duplicate(true) \
		if value is Dictionary or value is Array else value
	if not omitted_field.is_empty():
		if not (source is Dictionary):
			return ""
		(source as Dictionary).erase(omitted_field)
	return _canonical_json(source).sha256_text().to_lower()


static func is_strict_pure_data(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	if value == null or value is bool or value is int or value is String:
		return true
	if value is Array:
		for item_variant in value as Array:
			if not is_strict_pure_data(item_variant, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String) \
					or not is_strict_pure_data(
						(value as Dictionary).get(key_variant), depth + 1
					):
				return false
		return true
	return false


static func _capture_result(accepted: bool, reason_code: String, rows: Array) -> Dictionary:
	return {
		"accepted": accepted,
		"reason_code": reason_code,
		"logical_stream_id_count": LOGICAL_STREAM_IDS.size(),
		"concrete_stream_instance_count": rows.size(),
		"rng_stream_states": rows.duplicate(true),
	}


static func _preflight_result(
	accepted: bool,
	reason_code: String,
	concrete_stream_instance_count: int
) -> Dictionary:
	return {
		"accepted": accepted,
		"reason_code": reason_code,
		"logical_stream_id_count": LOGICAL_STREAM_IDS.size(),
		"concrete_stream_instance_count": concrete_stream_instance_count,
	}


static func _personal_save_index(save_states: Array, roster_ids: Array) -> Dictionary:
	if not is_strict_pure_data(save_states):
		return {"reason_code": "personal_dbg_saves_not_strict_pure_data"}
	if save_states.size() != roster_ids.size():
		return {"reason_code": "personal_dbg_save_count_invalid"}
	var saves_by_owner: Dictionary = {}
	for save_variant in save_states:
		if not (save_variant is Dictionary):
			return {"reason_code": "personal_dbg_save_not_dictionary"}
		var save_state := save_variant as Dictionary
		var save_reason := _dbg_save_error(save_state)
		if not save_reason.is_empty():
			return {"reason_code": "personal_dbg_%s" % save_reason}
		var owner_id := str(
			(save_state.get("state", {}) as Dictionary).get("owner_player_id", "")
		)
		if saves_by_owner.has(owner_id):
			return {"reason_code": "personal_dbg_owner_duplicate"}
		saves_by_owner[owner_id] = save_state
	for owner_variant in roster_ids:
		if not saves_by_owner.has(str(owner_variant)):
			return {"reason_code": "personal_dbg_roster_mismatch"}
	return {"reason_code": "", "saves_by_owner": saves_by_owner}


static func _unified_save_error(save_state: Dictionary) -> String:
	if not is_strict_pure_data(save_state):
		return "save_not_strict_pure_data"
	if not _exact_fields(save_state, UNIFIED_SAVE_FIELDS):
		return "save_fields_invalid"
	if save_state.get("schema_version") != OWNER_SCHEMA_VERSION \
			or save_state.get("state_version") != UNIFIED_STATE_VERSION \
			or save_state.get("interface_id") \
				!= "v072.unified_track.save_state.v3" \
			or save_state.get("ruleset_id") != SOURCE_CORE_RULESET_ID \
			or save_state.get("balance_profile_id") != SOURCE_CORE_BALANCE_PROFILE_ID \
			or save_state.get("balance_profile_fingerprint") \
				!= SOURCE_CORE_BALANCE_PROFILE_FINGERPRINT \
			or save_state.get("domain_id") != "unified_card_track":
		return "save_header_invalid"
	var authority_variant: Variant = save_state.get("authority_state")
	if not (authority_variant is Dictionary):
		return "authority_state_invalid"
	var authority := authority_variant as Dictionary
	if not _exact_fields(authority, UNIFIED_AUTHORITY_STATE_FIELDS):
		return "authority_state_fields_invalid"
	if authority.get("schema_version") != OWNER_SCHEMA_VERSION \
			or authority.get("state_version") != UNIFIED_STATE_VERSION \
			or authority.get("ruleset_id") != SOURCE_CORE_RULESET_ID \
			or authority.get("balance_profile_id") != SOURCE_CORE_BALANCE_PROFILE_ID \
			or authority.get("balance_profile_fingerprint") \
				!= SOURCE_CORE_BALANCE_PROFILE_FINGERPRINT \
			or authority.get("domain_id") != "unified_card_track":
		return "authority_state_header_invalid"
	if not (authority.get("revision") is int) \
			or int(authority.get("revision", 0)) <= 0 \
			or authority.get("revision") != save_state.get("source_revision"):
		return "source_revision_invalid"
	if not (authority.get("match_seed") is int) \
			or int(authority.get("match_seed", 0)) < 1 \
			or int(authority.get("match_seed", 0)) >= RNG_MODULUS:
		return "match_seed_invalid"
	if not _is_stable_id(authority.get("match_instance_id")) \
			or not (authority.get("match_instance_id_explicit") is bool):
		return "match_identity_invalid"
	var roster_variant: Variant = authority.get("roster_ids")
	if not (roster_variant is Array):
		return "roster_invalid"
	var roster_reason := _roster_error(roster_variant as Array)
	if not roster_reason.is_empty():
		return roster_reason
	if not _fingerprint_string(save_state.get("source_core_fingerprint")) \
			or save_state.get("source_core_fingerprint") \
			!= canonical_fingerprint(authority):
		return "source_core_fingerprint_invalid"
	if not _fingerprint_string(save_state.get("save_fingerprint")) \
			or save_state.get("save_fingerprint") \
			!= canonical_fingerprint(save_state, "save_fingerprint"):
		return "save_fingerprint_invalid"

	var match_seed := int(authority.get("match_seed", 0))
	for stream_variant in UNIFIED_STREAM_IDS:
		var stream_id := str(stream_variant)
		var owner_state := _unified_owner_state(authority, stream_id)
		var stream_reason := _unified_owner_state_error(
			owner_state, stream_id, match_seed
		)
		if not stream_reason.is_empty():
			return "%s_%s" % [stream_id, stream_reason]
	return ""


static func _dbg_save_error(save_state: Dictionary) -> String:
	if not is_strict_pure_data(save_state):
		return "save_not_strict_pure_data"
	if not _exact_fields(save_state, DBG_SAVE_FIELDS):
		return "save_fields_invalid"
	if save_state.get("schema_id") != "v072.personal_dbg.save_state.v3" \
			or save_state.get("schema_version") != OWNER_SCHEMA_VERSION \
			or save_state.get("state_version") != DBG_STATE_VERSION \
			or save_state.get("ruleset_id") != SOURCE_CORE_RULESET_ID \
			or save_state.get("balance_profile_id") != SOURCE_CORE_BALANCE_PROFILE_ID \
			or save_state.get("balance_profile_fingerprint") \
				!= SOURCE_CORE_BALANCE_PROFILE_FINGERPRINT \
			or save_state.get("domain_id") != "v07.personal_dbg" \
			or save_state.get("privacy_scope") != "authority_secret":
		return "save_header_invalid"
	var state_variant: Variant = save_state.get("state")
	if not (state_variant is Dictionary):
		return "state_invalid"
	var state := state_variant as Dictionary
	if not _exact_fields(state, DBG_STATE_FIELDS):
		return "state_fields_invalid"
	if state.get("schema_version") != OWNER_SCHEMA_VERSION \
			or state.get("state_version") != DBG_STATE_VERSION \
			or state.get("ruleset_id") != SOURCE_CORE_RULESET_ID \
			or state.get("balance_profile_id") != SOURCE_CORE_BALANCE_PROFILE_ID \
			or state.get("balance_profile_fingerprint") \
				!= SOURCE_CORE_BALANCE_PROFILE_FINGERPRINT \
			or state.get("domain_id") != "v07.personal_dbg" \
			or not _is_stable_id(state.get("owner_player_id")) \
			or not _tagged_int64_valid(state.get("root_seed")):
		return "state_identity_invalid"
	if not (state.get("revision") is int) or int(state.get("revision", -1)) < 0:
		return "state_revision_invalid"
	if not _fingerprint_string(save_state.get("state_fingerprint")) \
			or save_state.get("state_fingerprint") != canonical_fingerprint(state):
		return "state_fingerprint_invalid"
	var core_state := state.duplicate(true)
	core_state.erase("receipt_journal")
	if not _fingerprint_string(save_state.get("core_fingerprint")) \
			or save_state.get("core_fingerprint") != canonical_fingerprint(core_state):
		return "core_fingerprint_invalid"

	var owner_id := str(state.get("owner_player_id", ""))
	var root_seed := _tagged_int64_value(state.get("root_seed"))
	for binding_variant in [
		["starter_deck_shuffle", "starter_rng"],
		["normal_deck_reshuffle_by_player", "reshuffle_rng"],
	]:
		var binding := binding_variant as Array
		var stream_id := str(binding[0])
		var state_field := str(binding[1])
		var rng_variant: Variant = state.get(state_field)
		if not (rng_variant is Dictionary):
			return "%s_state_invalid" % stream_id
		var rng_state := rng_variant as Dictionary
		var rng_reason := _dbg_rng_state_error(rng_state, stream_id, owner_id)
		if not rng_reason.is_empty():
			return "%s_%s" % [stream_id, rng_reason]
		var expected_seed := _derive_dbg_seed(root_seed, stream_id, owner_id)
		if _tagged_int64_value(rng_state.get("seed")) != expected_seed:
			return "%s_seed_derivation_invalid" % stream_id

	var document_variant: Variant = save_state.get("document_section")
	if not (document_variant is Dictionary):
		return "document_section_invalid"
	var document := document_variant as Dictionary
	if not _exact_fields(document, DBG_DOCUMENT_FIELDS) \
			or document.get("section_id") != DBG_SAVE_SECTION_ID \
			or document.get("section_version") != DBG_STATE_VERSION \
			or document.get("state_version") != DBG_STATE_VERSION \
			or document.get("ruleset_id") != SOURCE_CORE_RULESET_ID \
			or document.get("balance_profile_id") != SOURCE_CORE_BALANCE_PROFILE_ID \
			or document.get("balance_profile_fingerprint") \
				!= SOURCE_CORE_BALANCE_PROFILE_FINGERPRINT \
			or document.get("semantic_owner") != DBG_AUTHORITY_ID:
		return "document_section_invalid"
	var document_rng_variant: Variant = document.get("rng_stream_states")
	if not (document_rng_variant is Array):
		return "document_rng_states_invalid"
	var document_rng := document_rng_variant as Array
	if document_rng != [state.get("starter_rng"), state.get("reshuffle_rng")]:
		return "document_rng_states_mismatch"
	return ""


static func _row_error(row: Dictionary, roster_ids: Array) -> String:
	if not is_strict_pure_data(row) or not _exact_fields(row, ROW_FIELDS):
		return "ledger_row_fields_invalid"
	if row.get("schema_version") != SCHEMA_VERSION:
		return "ledger_row_schema_invalid"
	var stream_id := str(row.get("stream_id", ""))
	if stream_id not in LOGICAL_STREAM_IDS:
		return "ledger_stream_id_invalid"
	var instance_id := str(row.get("stream_instance_id", ""))
	var state_variant: Variant = row.get("state")
	if not (state_variant is Dictionary):
		return "ledger_state_invalid"
	var state := state_variant as Dictionary
	if stream_id in DBG_STREAM_IDS:
		if not roster_ids.has(instance_id) \
				or row.get("state_profile_id") != DBG_PROFILE_ID \
				or row.get("authoritative_owner_id") != DBG_AUTHORITY_ID \
				or row.get("save_section_id") != DBG_SAVE_SECTION_ID:
			return "ledger_dbg_binding_invalid"
		var dbg_reason := _dbg_rng_state_error(state, stream_id, instance_id)
		if not dbg_reason.is_empty():
			return "ledger_dbg_%s" % dbg_reason
	else:
		if instance_id != "global" \
				or row.get("state_profile_id") != UNIFIED_PROFILE_ID \
				or row.get("authoritative_owner_id") != UNIFIED_AUTHORITY_ID \
				or row.get("save_section_id") != UNIFIED_SAVE_SECTION_ID:
			return "ledger_unified_binding_invalid"
		if not _exact_fields(state, UNIFIED_RNG_STATE_FIELDS) \
				or not _valid_unified_rng_state(state.get("rng_state")) \
				or not _nonnegative_int(state.get("rng_draw_count")):
			return "ledger_unified_state_invalid"
	if not _fingerprint_string(row.get("state_fingerprint")) \
			or row.get("state_fingerprint") \
			!= canonical_fingerprint(row, "state_fingerprint"):
		return "ledger_row_fingerprint_invalid"
	return ""


static func _dbg_rng_state_error(
	rng_state: Dictionary,
	expected_stream_id: String,
	expected_instance_id: String
) -> String:
	if not _exact_fields(rng_state, DBG_RNG_STATE_FIELDS):
		return "state_fields_invalid"
	if rng_state.get("schema_version") != OWNER_SCHEMA_VERSION \
			or rng_state.get("stream_id") != expected_stream_id \
			or rng_state.get("stream_instance_id") != expected_instance_id \
			or rng_state.get("authoritative_owner_id") != DBG_AUTHORITY_ID \
			or rng_state.get("algorithm_id") != DBG_ALGORITHM_ID:
		return "state_binding_invalid"
	if not _tagged_int64_valid(rng_state.get("seed")) \
			or not _tagged_int64_valid(rng_state.get("cursor"), true) \
			or not _tagged_int64_valid(
				rng_state.get("stream_revision"), true
			):
		return "tagged_int64_invalid"
	if _tagged_int64_value(rng_state.get("cursor")) \
			!= _tagged_int64_value(rng_state.get("stream_revision")):
		return "cursor_revision_mismatch"
	if not _fingerprint_string(rng_state.get("state_fingerprint")) \
			or rng_state.get("state_fingerprint") \
			!= canonical_fingerprint(rng_state, "state_fingerprint"):
		return "state_fingerprint_invalid"
	return ""


static func _unified_owner_state_error(
	owner_state: Dictionary,
	expected_stream_id: String,
	match_seed: int
) -> String:
	var expected_fields := _unified_owner_fields(expected_stream_id)
	if expected_fields.is_empty() or not _exact_fields(owner_state, expected_fields):
		return "owner_state_fields_invalid"
	if owner_state.get("stream_id") != expected_stream_id \
			or not _valid_unified_rng_state(owner_state.get("rng_state")) \
			or not _nonnegative_int(owner_state.get("rng_draw_count")):
		return "rng_state_invalid"
	var draw_count := int(owner_state.get("rng_draw_count", -1))
	var expected_state := _derive_unified_seed(match_seed, expected_stream_id)
	expected_state = int(
		(expected_state * _modular_power(RNG_MULTIPLIER, draw_count, RNG_MODULUS))
		% RNG_MODULUS
	)
	if int(owner_state.get("rng_state", 0)) != expected_state:
		return "rng_lineage_invalid"
	return ""


static func _unified_owner_state(authority: Dictionary, stream_id: String) -> Dictionary:
	match stream_id:
		"unified_track_type_draw":
			return (authority.get("type_supply_state", {}) as Dictionary).duplicate(true)
		"unified_track_color_draw":
			var color_cycle := authority.get("color_cycle_state", {}) as Dictionary
			return (
				color_cycle.get("color_supply_state", {}) as Dictionary
			).duplicate(true)
		"unified_track_normal_card_draw":
			return (
				authority.get("normal_supply_state", {}) as Dictionary
			).duplicate(true)
		"unified_track_commodity_draw":
			return (
				authority.get("commodity_supply_state", {}) as Dictionary
			).duplicate(true)
		"initial_hidden_lead_order":
			return (
				authority.get("hidden_lead_cycle_state", {}) as Dictionary
			).duplicate(true)
	return {}


static func _unified_owner_fields(stream_id: String) -> Array:
	match stream_id:
		"unified_track_type_draw":
			return TYPE_SUPPLY_FIELDS
		"unified_track_color_draw":
			return COLOR_SUPPLY_FIELDS
		"unified_track_normal_card_draw", "unified_track_commodity_draw":
			return DEFINITION_SUPPLY_FIELDS
		"initial_hidden_lead_order":
			return HIDDEN_LEAD_FIELDS
	return []


static func _unified_rng_projection(owner_state: Dictionary) -> Dictionary:
	return {
		"rng_state": owner_state.get("rng_state"),
		"rng_draw_count": owner_state.get("rng_draw_count"),
	}


static func _canonical_row(
	stream_id: String,
	stream_instance_id: String,
	state_profile_id: String,
	authoritative_owner_id: String,
	save_section_id: String,
	state: Dictionary
) -> Dictionary:
	var row := {
		"schema_version": SCHEMA_VERSION,
		"stream_id": stream_id,
		"stream_instance_id": stream_instance_id,
		"state_profile_id": state_profile_id,
		"authoritative_owner_id": authoritative_owner_id,
		"save_section_id": save_section_id,
		"state": state.duplicate(true),
	}
	row["state_fingerprint"] = canonical_fingerprint(row)
	return row


static func _roster_error(roster_ids: Array) -> String:
	if roster_ids.size() < MIN_ROSTER_SIZE or roster_ids.size() > MAX_ROSTER_SIZE:
		return "roster_count_invalid"
	var seen: Dictionary = {}
	for owner_variant in roster_ids:
		if not _is_stable_id(owner_variant):
			return "roster_owner_id_invalid"
		var owner_id := str(owner_variant)
		if owner_id == "system" or seen.has(owner_id):
			return "roster_owner_id_duplicate_or_reserved"
		seen[owner_id] = true
	return ""


static func _derive_dbg_seed(
	root_seed: int,
	stream_id: String,
	stream_instance_id: String
) -> int:
	var digest := ("%s:%s:%s:%s" % [
		RULESET_ID,
		str(root_seed),
		stream_id,
		stream_instance_id,
	]).sha256_text()
	var upper_unsigned := int(digest.substr(0, 8).hex_to_int())
	var lower_unsigned := int(digest.substr(8, 8).hex_to_int())
	var upper_signed := upper_unsigned \
		if upper_unsigned < 2147483648 else upper_unsigned - 4294967296
	return (upper_signed * 4294967296) + lower_unsigned


static func _derive_unified_seed(match_seed: int, stream_id: String) -> int:
	var value := _normalize_unified_seed(match_seed)
	for index in range(stream_id.length()):
		value = int(
			(value * RNG_MULTIPLIER + stream_id.unicode_at(index) + index + 1)
			% (RNG_MODULUS - 1)
		) + 1
	return value


static func _normalize_unified_seed(seed: int) -> int:
	var value := seed % (RNG_MODULUS - 1)
	if value < 0:
		value += RNG_MODULUS - 1
	return value + 1


static func _modular_power(base_value: int, exponent_value: int, modulus: int) -> int:
	var result := 1
	var base := base_value % modulus
	var exponent := exponent_value
	while exponent > 0:
		if (exponent & 1) == 1:
			result = int((result * base) % modulus)
		base = int((base * base) % modulus)
		exponent = exponent >> 1
	return result


static func _tagged_int64_valid(
	value: Variant,
	require_nonnegative: bool = false
) -> bool:
	if not (value is Dictionary) \
			or not _exact_fields(value as Dictionary, TAGGED_INT64_FIELDS):
		return false
	var tagged := value as Dictionary
	if tagged.get("type") != "int64" or not (tagged.get("decimal") is String):
		return false
	var decimal := str(tagged.get("decimal", ""))
	if decimal.is_empty() or not decimal.is_valid_int():
		return false
	var parsed := decimal.to_int()
	if str(parsed) != decimal:
		return false
	return not require_nonnegative or parsed >= 0


static func _tagged_int64_value(value: Variant) -> int:
	if not _tagged_int64_valid(value):
		return 0
	return str((value as Dictionary).get("decimal", "0")).to_int()


static func _valid_unified_rng_state(value: Variant) -> bool:
	return value is int and int(value) >= 1 and int(value) < RNG_MODULUS


static func _nonnegative_int(value: Variant) -> bool:
	return value is int and int(value) >= 0


static func _fingerprint_string(value: Variant) -> bool:
	if not (value is String) or str(value).length() != 64:
		return false
	for index in range(64):
		var code := str(value).unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func _is_stable_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := str(value)
	if text.is_empty() or text.length() > 160:
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var lower := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		if not lower and not digit and code not in [45, 46, 95]:
			return false
	return true


static func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _canonical_json(value: Variant) -> String:
	if value == null:
		return "null"
	if value is bool:
		return "true" if bool(value) else "false"
	if value is int:
		return str(value)
	if value is String:
		return JSON.stringify(value)
	if value is Array:
		var items: Array[String] = []
		for item_variant in value as Array:
			items.append(_canonical_json(item_variant))
		return "[%s]" % ",".join(items)
	var source := value as Dictionary
	var keys: Array[String] = []
	for key_variant in source.keys():
		keys.append(str(key_variant))
	keys.sort()
	var members: Array[String] = []
	for key in keys:
		members.append(
			"%s:%s" % [JSON.stringify(key), _canonical_json(source.get(key))]
		)
	return "{%s}" % ",".join(members)


static func _normalize_json_numbers(value: Variant, depth: int = 0) -> Variant:
	if depth > 64:
		return null
	if value is float:
		var number := float(value)
		if is_finite(number) \
				and number == floor(number) \
				and absf(number) <= 9007199254740991.0:
			return int(number)
		return null
	if value is Array:
		var normalized_array: Array = []
		for item_variant in value as Array:
			normalized_array.append(_normalize_json_numbers(item_variant, depth + 1))
		return normalized_array
	if value is Dictionary:
		var normalized_dictionary: Dictionary = {}
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String):
				return null
			normalized_dictionary[str(key_variant)] = _normalize_json_numbers(
				(value as Dictionary).get(key_variant), depth + 1
			)
		return normalized_dictionary
	return value

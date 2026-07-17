extends RefCounted
class_name VictoryPresentationStateChangeReceipt

const TOP_LEVEL_KEYS := [
	"controller_id", "ruleset_id", "state", "victory_rule",
	"qualification_remaining_seconds", "audit_remaining_seconds", "audit_roster",
	"audit_entries", "paused", "pause_reasons", "settlement_checkpoint",
	"outcome_receipt", "visibility_scope", "cash_visibility",
	"audit_revealed_player_indices", "rank_entries",
]
const VICTORY_RULE_KEYS := [
	"surviving_region_count", "coverage_basis_points", "required_region_count",
	"gdp_per_required_region_per_minute", "required_top_k_gdp_per_minute",
	"required_top_k_gdp_per_minute_cents", "ordinary_victory_paused",
]
const CANDIDATE_KEYS := [
	"player_index", "eligible", "top_k_gdp_per_minute_cents",
	"top_k_gdp_per_minute", "top_n_gdp_per_minute", "controlled_region_count",
	"controlled_regions", "region_shares", "cash_visibility", "cash_ledger_cents",
]
const REGION_KEYS := [
	"region_id", "district_index", "surviving", "attributable_gdp_per_minute_cents",
	"attributable_gdp_per_minute", "share_basis_points", "controls",
]
const OUTCOME_KEYS := [
	"outcome_id", "schema_version", "ruleset_id", "reason_code",
	"winner_player_indices", "co_victory", "comparison_order", "rankings",
	"audit_evidence", "visibility_scope", "cash_visibility", "audit_revealed_player_indices",
]
const RANKING_KEYS := [
	"player_index", "top_k_gdp_per_minute_cents", "top_k_gdp_per_minute",
	"top_n_gdp_per_minute", "controlled_region_count", "winner",
	"cash_visibility", "cash_ledger_cents",
]

var receipt_id := ""
var revision := 0
var change_kind: StringName = &""
var previous_state := "idle"
var state := "idle"
var world_time := 0.0
var public_snapshot: Dictionary = {}
var participant_names: Dictionary = {}
var public_map_facts: Dictionary = {}
var immediate_refresh_mask: Array[StringName] = []


func is_valid() -> bool:
	return not receipt_id.is_empty() \
		and not str(change_kind).is_empty() \
		and _is_public_data(public_snapshot) \
		and _is_public_data(participant_names) \
		and _is_public_data(public_map_facts) \
		and public_snapshot == project_public_snapshot(public_snapshot) \
		and participant_names == project_participant_names(participant_names) \
		and public_map_facts == project_public_map_facts(public_map_facts)


func to_dictionary() -> Dictionary:
	if not is_valid():
		return {}
	var refresh_values: Array = []
	for value in immediate_refresh_mask:
		refresh_values.append(str(value))
	return {
		"receipt_id": receipt_id,
		"revision": revision,
		"change_kind": str(change_kind),
		"previous_state": previous_state,
		"state": state,
		"world_time": world_time,
		"public_snapshot": public_snapshot.duplicate(true),
		"participant_names": participant_names.duplicate(true),
		"public_map_facts": public_map_facts.duplicate(true),
		"immediate_refresh_mask": refresh_values,
		"visibility_scope": "public",
	}


func public_context() -> Dictionary:
	if not is_valid():
		return {}
	return {
		"victory_public_snapshot": public_snapshot.duplicate(true),
		"participant_names": participant_names.duplicate(true),
		"public_map_facts": public_map_facts.duplicate(true),
		"reason": str(change_kind),
	}


static func project_public_snapshot(source: Dictionary) -> Dictionary:
	var result := _pick(source, TOP_LEVEL_KEYS)
	result["victory_rule"] = _pick(source.get("victory_rule", {}) as Dictionary if source.get("victory_rule", {}) is Dictionary else {}, VICTORY_RULE_KEYS)
	var revealed: Array = _int_array(source.get("audit_revealed_player_indices", []))
	if str(source.get("cash_visibility", "")) == "public_audit" and not revealed.is_empty():
		result["cash_visibility"] = "public_audit"
		result["audit_revealed_player_indices"] = revealed
	else:
		result.erase("cash_visibility")
		result.erase("audit_revealed_player_indices")
	result["audit_entries"] = _candidate_array(source.get("audit_entries", []), revealed)
	result["rank_entries"] = _candidate_array(source.get("rank_entries", []), revealed) if source.has("rank_entries") else []
	if not source.has("rank_entries"):
		result.erase("rank_entries")
	result["audit_roster"] = _int_array(source.get("audit_roster", []))
	result["pause_reasons"] = _string_array(source.get("pause_reasons", []))
	result["outcome_receipt"] = _project_outcome(source.get("outcome_receipt", {}) as Dictionary if source.get("outcome_receipt", {}) is Dictionary else {}, revealed)
	result["visibility_scope"] = "public"
	return TablePresentationPureDataPolicy.detached_copy(result) as Dictionary if TablePresentationPureDataPolicy.is_pure_data(result) else {}


static func project_participant_names(source: Dictionary) -> Dictionary:
	var result := {}
	for key_variant in source.keys():
		var key := str(key_variant)
		if key.is_valid_int() and int(key) >= 0:
			result[key] = str(source[key_variant])
	return result


static func project_public_map_facts(source: Dictionary) -> Dictionary:
	return _pick(source, ["active_city_count", "destroyed_district_count", "active_monster_count", "monster_count", "key_city"])


static func _project_outcome(source: Dictionary, revealed: Array) -> Dictionary:
	if source.is_empty():
		return {}
	var result := _pick(source, OUTCOME_KEYS)
	result["winner_player_indices"] = _int_array(source.get("winner_player_indices", []))
	result["comparison_order"] = _string_array(source.get("comparison_order", []))
	var rankings: Array = []
	for row_variant in source.get("rankings", []):
		if not (row_variant is Dictionary):
			continue
		var row := _pick(row_variant as Dictionary, RANKING_KEYS)
		_enforce_cash_exception(row, revealed)
		rankings.append(row)
	result["rankings"] = rankings
	var evidence_source: Dictionary = source.get("audit_evidence", {}) if source.get("audit_evidence", {}) is Dictionary else {}
	result["audit_evidence"] = {
		"victory_rule": _pick(evidence_source.get("victory_rule", {}) as Dictionary if evidence_source.get("victory_rule", {}) is Dictionary else {}, VICTORY_RULE_KEYS),
		"audit_roster": _int_array(evidence_source.get("audit_roster", [])),
		"settlement_checkpoint": str(evidence_source.get("settlement_checkpoint", "")),
	}
	result["visibility_scope"] = "public"
	if not revealed.is_empty():
		result["cash_visibility"] = "public_audit"
		result["audit_revealed_player_indices"] = revealed.duplicate()
	else:
		result.erase("cash_visibility")
		result.erase("audit_revealed_player_indices")
	return result


static func _candidate_array(value: Variant, revealed: Array) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for row_variant in value:
		if not (row_variant is Dictionary):
			continue
		var row := _pick(row_variant as Dictionary, CANDIDATE_KEYS)
		row["controlled_regions"] = _region_array(row.get("controlled_regions", []))
		row["region_shares"] = _region_array(row.get("region_shares", []))
		_enforce_cash_exception(row, revealed)
		result.append(row)
	return result


static func _region_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for row_variant in value:
			if row_variant is Dictionary:
				result.append(_pick(row_variant as Dictionary, REGION_KEYS))
	return result


static func _enforce_cash_exception(row: Dictionary, revealed: Array) -> void:
	var player_index := int(row.get("player_index", -1))
	if revealed.has(player_index) and str(row.get("cash_visibility", "")) == "public_audit" and typeof(row.get("cash_ledger_cents", null)) == TYPE_INT:
		return
	row.erase("cash_visibility")
	row.erase("cash_ledger_cents")


static func _pick(source: Dictionary, keys: Array) -> Dictionary:
	var result := {}
	for key_variant in keys:
		var key := str(key_variant)
		if source.has(key) and TablePresentationPureDataPolicy.is_pure_data(source[key]):
			result[key] = TablePresentationPureDataPolicy.detached_copy(source[key])
	return result


static func _int_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for child in value:
			if typeof(child) == TYPE_INT and int(child) >= 0:
				result.append(int(child))
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for child in value:
			if child is String or child is StringName:
				result.append(str(child))
	return result


func _is_public_data(value: Variant) -> bool:
	if value == null or value is bool or value is int or value is float or value is String or value is StringName:
		return true
	if value is Array:
		for child in value:
			if not _is_public_data(child):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_public_data(key_variant) or not _is_public_data(value[key_variant]):
				return false
		return true
	return false

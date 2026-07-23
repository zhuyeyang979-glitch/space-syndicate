@tool
extends Node
class_name AiCardEligibilityQueryPort

const EVALUATION_MODES := ["rule", "hand", "catalog"]

@export var card_play_eligibility_world_bridge_path: NodePath
@export var card_play_eligibility_runtime_service_path: NodePath
@export var commodity_flow_runtime_controller_path: NodePath
@export var player_mana_runtime_controller_path: NodePath
@export var world_session_state_path: NodePath
@export var game_session_runtime_controller_path: NodePath

var _capabilities_by_actor: Dictionary = {}
var _capability_binding_initialized := false
var _bound_actor_roster_revision := ""
var _capability_revision := 0
var _eligibility_query_count := 0
var _requirement_query_count := 0
var _best_share_query_count := 0
var _rejected_query_count := 0


func bind_ai_capabilities(capabilities_by_actor: Dictionary) -> bool:
	var expected_actor_indices := _ai_player_indices()
	if capabilities_by_actor.size() != expected_actor_indices.size():
		return _reject_capability_binding()
	var normalized: Dictionary = {}
	var seen_tokens: Dictionary = {}
	for actor_index_variant in expected_actor_indices:
		var actor_index := int(actor_index_variant)
		var capability_variant: Variant = capabilities_by_actor.get(actor_index)
		if not (capability_variant is AiCardEligibilityCapability):
			return _reject_capability_binding()
		var token_id := (capability_variant as AiCardEligibilityCapability).get_instance_id()
		if seen_tokens.has(token_id):
			return _reject_capability_binding()
		seen_tokens[token_id] = true
		normalized[actor_index] = capability_variant
	_capabilities_by_actor = normalized
	_capability_binding_initialized = true
	_bound_actor_roster_revision = _actor_roster_revision()
	_capability_revision += 1
	return true


func is_ready() -> bool:
	return (
		_world_bridge() != null
		and _eligibility_service() != null
		and _commodity_flow() != null
		and _player_mana() != null
		and _world() != null
		and _game_session() != null
		and _capability_binding_initialized
	)


func eligibility_snapshot(
	capability: AiCardEligibilityCapability,
	actor_index: int,
	skill: Dictionary,
	evaluation_mode: String = "rule",
	selected_district: int = -1
) -> Dictionary:
	_eligibility_query_count += 1
	if (
		not _authorized(capability, actor_index)
		or not EVALUATION_MODES.has(evaluation_mode)
		or not TablePresentationPureDataPolicy.is_pure_data(skill)
	):
		_rejected_query_count += 1
		return {}
	var facts := _build_facts(actor_index, skill, selected_district)
	var value: Variant = _eligibility_service().evaluate_play({
		"player_index": actor_index,
		"skill": skill.duplicate(true),
		"evaluation_mode": evaluation_mode,
	}, facts)
	var result: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if result.is_empty():
		_rejected_query_count += 1
		return {}
	result["schema_version"] = 1
	result["visibility_scope"] = "actor_private"
	result["actor_index"] = actor_index
	result["selected_district"] = selected_district
	result["state_revision"] = _receipt_revision(
		"eligibility",
		actor_index,
		evaluation_mode,
		selected_district,
		result
	)
	if not TablePresentationPureDataPolicy.is_pure_data(result):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(result)


func requirement_snapshot(
	capability: AiCardEligibilityCapability,
	actor_index: int,
	skill: Dictionary,
	selected_district: int = -1
) -> Dictionary:
	_requirement_query_count += 1
	var eligibility := eligibility_snapshot(
		capability,
		actor_index,
		skill,
		"catalog",
		selected_district
	)
	if eligibility.is_empty():
		return {}
	var requirement: Dictionary = _dictionary(eligibility.get("requirement_status", {}))
	var result := {
		"schema_version": 1,
		"visibility_scope": "actor_private",
		"actor_index": actor_index,
		"selected_district": selected_district,
		"requirement_status": requirement,
		"cash_cost": int(eligibility.get("cash_cost", requirement.get("cash_cost", 0))),
		"state_revision": str(eligibility.get("state_revision", "")),
	}
	return TablePresentationPureDataPolicy.detached_copy(result)


func best_share_snapshot(
	capability: AiCardEligibilityCapability,
	actor_index: int
) -> Dictionary:
	_best_share_query_count += 1
	if not _authorized(capability, actor_index):
		_rejected_query_count += 1
		return {}
	var facts_variant: Variant = _world_bridge().build_facts(
		actor_index,
		{},
		{"selected_district": -1}
	)
	var facts: Dictionary = facts_variant if facts_variant is Dictionary else {}
	var result := {
		"schema_version": 1,
		"visibility_scope": "actor_private",
		"actor_index": actor_index,
		"selected_district": -1,
		"best_share_district": _best_share_district_with_gdp(facts),
	}
	result["state_revision"] = _receipt_revision(
		"best_share",
		actor_index,
		"catalog",
		-1,
		result
	)
	if not TablePresentationPureDataPolicy.is_pure_data(result):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(result)


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"capability_revision": _capability_revision,
		"actor_scoped_capability_count": _capabilities_by_actor.size(),
		"session_scoped_capabilities": true,
		"eligibility_query_count": _eligibility_query_count,
		"requirement_query_count": _requirement_query_count,
		"best_share_query_count": _best_share_query_count,
		"rejected_query_count": _rejected_query_count,
		"returns_actor_receipts_only": true,
		"returns_raw_facts": false,
		"returns_whole_players": false,
		"returns_whole_districts": false,
		"reads_table_selection": false,
		"best_share_tie_break": "share_then_region_gdp_then_earliest_index",
		"uses_read_only_player_mana": true,
		"mutates_world": false,
		"consumes_rng": false,
		"references_main": false,
		"owns_state": false,
	}


func _best_share_district_with_gdp(facts: Dictionary) -> int:
	var shares := _dictionary(facts.get("share_basis_points_by_district", {}))
	var best_district := -1
	var best_share := -1
	var best_gdp := -1
	for district_index in range(_world().districts.size()):
		var share := int(shares.get(str(district_index), 0))
		if share <= 0:
			continue
		var district: Dictionary = (
			_world().districts[district_index]
			if _world().districts[district_index] is Dictionary
			else {}
		)
		var region_id := str(district.get(
			"region_id",
			"region.%03d" % district_index
		))
		var gdp_snapshot := _commodity_flow().region_gdp_snapshot(region_id)
		var region_gdp := int(gdp_snapshot.get(
			"region_gdp_per_minute",
			0
		))
		if share > best_share or (
			share == best_share and region_gdp > best_gdp
		):
			best_district = district_index
			best_share = share
			best_gdp = region_gdp
	return best_district


func _build_facts(
	actor_index: int,
	skill: Dictionary,
	selected_district: int
) -> Dictionary:
	var value: Variant = _world_bridge().build_facts(
		actor_index,
		skill.duplicate(true),
		{"selected_district": selected_district}
	)
	var facts: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	facts["commodity_color_flow"] = _commodity_flow().player_color_flow_snapshot(actor_index)
	facts["player_mana"] = _player_mana().availability_snapshot_read_only(actor_index)
	return facts


func _authorized(
	capability: AiCardEligibilityCapability,
	actor_index: int
) -> bool:
	return (
		capability != null
		and is_ready()
		and _bound_actor_roster_revision == _actor_roster_revision()
		and _capabilities_by_actor.get(actor_index) == capability
		and not _game_session().is_finished()
		and actor_index >= 0
		and actor_index < _world().players.size()
		and _world().players[actor_index] is Dictionary
		and (
			bool((_world().players[actor_index] as Dictionary).get("is_ai", false))
			or str((_world().players[actor_index] as Dictionary).get("seat_type", "human")) == "ai"
		)
	)


func _ai_player_indices() -> Array:
	var result: Array = []
	if _world() == null:
		return result
	for actor_index in range(_world().players.size()):
		if (
			_world().players[actor_index] is Dictionary
			and (
				bool((_world().players[actor_index] as Dictionary).get("is_ai", false))
				or str((_world().players[actor_index] as Dictionary).get("seat_type", "human")) == "ai"
			)
		):
			result.append(actor_index)
	return result


func _actor_roster_revision() -> String:
	var roster_identity: Array = []
	if _world() != null:
		for actor_index_variant in _ai_player_indices():
			var actor_index := int(actor_index_variant)
			var actor := _world().players[actor_index] as Dictionary
			roster_identity.append([
				actor_index,
				str(actor.get("actor_id", actor.get("id", actor_index))),
				str(actor.get("id", actor_index)),
				str(actor.get("name", "")),
				str(actor.get("seat_type", "ai")),
			])
	return JSON.stringify([
		"ai_card_eligibility_actor_roster_v1",
		_session_identity_revision(),
		roster_identity,
	]).sha256_text()


func _session_identity_revision() -> String:
	var summary := _game_session().session_summary() if _game_session() != null else {}
	return JSON.stringify([
		"ai_card_eligibility_session_identity_v1",
		str(summary.get("ruleset_id", "")),
		str(summary.get("session_id", "")),
		str(summary.get("scenario_id", "")),
		int(summary.get("seed", 0)),
		summary.get("setup", {}),
	]).sha256_text()


func _receipt_revision(
	receipt_kind: String,
	actor_index: int,
	evaluation_mode: String,
	selected_district: int,
	receipt: Dictionary
) -> String:
	var source := receipt.duplicate(true)
	source.erase("state_revision")
	return JSON.stringify([
		"ai_card_eligibility_receipt_v1",
		receipt_kind,
		actor_index,
		_bound_actor_roster_revision,
		evaluation_mode,
		selected_district,
		source,
	]).sha256_text()


func _reject_capability_binding() -> bool:
	_capabilities_by_actor.clear()
	_capability_binding_initialized = false
	_bound_actor_roster_revision = ""
	_capability_revision += 1
	return false


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _world_bridge() -> CardPlayEligibilityWorldBridge:
	return get_node_or_null(
		card_play_eligibility_world_bridge_path
	) as CardPlayEligibilityWorldBridge


func _eligibility_service() -> CardPlayEligibilityRuntimeService:
	return get_node_or_null(
		card_play_eligibility_runtime_service_path
	) as CardPlayEligibilityRuntimeService


func _commodity_flow() -> CommodityFlowRuntimeController:
	return get_node_or_null(
		commodity_flow_runtime_controller_path
	) as CommodityFlowRuntimeController


func _player_mana() -> PlayerManaRuntimeController:
	return get_node_or_null(
		player_mana_runtime_controller_path
	) as PlayerManaRuntimeController


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _game_session() -> GameSessionRuntimeController:
	return get_node_or_null(
		game_session_runtime_controller_path
	) as GameSessionRuntimeController

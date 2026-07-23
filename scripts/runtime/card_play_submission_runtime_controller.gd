@tool
extends Node
class_name CardPlaySubmissionRuntimeController

const TARGET_MONSTER := CardTargetChoiceRuntimeController.KIND_MONSTER
const TARGET_PLAYER := CardTargetChoiceRuntimeController.KIND_PLAYER
const StableTargetEnvelope := preload("res://scripts/runtime/card_resolution_stable_target_envelope.gd")
const CardPlayRequirementPolicyScript := preload("res://scripts/cards/card_play_requirement_policy.gd")
const SHARED_RESOLUTION_EFFECT_KINDS_V06 := [
	"global_order_budget",
	"global_supply_spawn",
]
const V06_ASSET_COST_KEYS := ["life", "energy", "industry", "technology", "commerce", "shipping", "generic"]
const MAX_EXACT_JSON_INTEGER := 9_007_199_254_740_991.0

var _world_session_state: WorldSessionState
var _table_selection_state: TableSelectionState
var _eligibility_facts: CardPlayEligibilityWorldBridge
var _eligibility_service: CardPlayEligibilityRuntimeService
var _queue_service: CardResolutionQueueRuntimeService
var _resolution_controller: CardResolutionRuntimeController
var _target_choice_controller: CardTargetChoiceRuntimeController
var _product_market_controller: ProductMarketRuntimeController
var _derivative_controller: CityGdpDerivativeRuntimeController
var _selection_catalog_query_port: TableSelectionCatalogQueryPort
var _runtime_coordinator: GameRuntimeCoordinator
var _cash_commitment_query_port: MonsterWagerCashCommitmentQueryPort
var _submission_count := 0
var _accepted_count := 0
var _last_receipt: Dictionary = {}


func set_dependencies(
	world_session_state: WorldSessionState,
	table_selection_state: TableSelectionState,
	eligibility_facts: CardPlayEligibilityWorldBridge,
	eligibility_service: CardPlayEligibilityRuntimeService,
	queue_service: CardResolutionQueueRuntimeService,
	resolution_controller: CardResolutionRuntimeController,
	target_choice_controller: CardTargetChoiceRuntimeController,
	product_market_controller: ProductMarketRuntimeController,
	derivative_controller: CityGdpDerivativeRuntimeController,
	selection_catalog_query_port: TableSelectionCatalogQueryPort,
	runtime_coordinator: GameRuntimeCoordinator,
	cash_commitment_query_port: MonsterWagerCashCommitmentQueryPort = null
) -> void:
	_world_session_state = world_session_state
	_table_selection_state = table_selection_state
	_eligibility_facts = eligibility_facts
	_eligibility_service = eligibility_service
	_queue_service = queue_service
	_resolution_controller = resolution_controller
	_target_choice_controller = target_choice_controller
	_product_market_controller = product_market_controller
	_derivative_controller = derivative_controller
	_selection_catalog_query_port = selection_catalog_query_port
	_runtime_coordinator = runtime_coordinator
	_cash_commitment_query_port = cash_commitment_query_port


func request_hand_play(request: Dictionary) -> Dictionary:
	_submission_count += 1
	var player_index := int(request.get("player_index", -1))
	var slot_index := int(request.get("slot_index", -1))
	var card_context := _card_at(player_index, slot_index)
	if not bool(card_context.get("valid", false)):
		return _remember(_rejection("card_slot_invalid"))
	var skill: Dictionary = card_context.get("skill", {})
	if _is_v06_runtime_card(skill):
		var v06_envelope := _capture_stable_target_envelope(request, {})
		if v06_envelope.is_empty():
			return _remember(_rejection("stable_target_capture_failed"))
		if _uses_shared_resolution_v06(skill):
			return _remember(_submit_v06_automatic_supply_demand(player_index, slot_index, skill, v06_envelope))
		return _remember(_submit_v06(player_index, slot_index, skill, v06_envelope))
	var frozen := _prepare_legacy_submission(player_index, skill, "hand", request)
	if not bool(frozen.get("prepared", false)):
		return _remember(_rejection(str(frozen.get("reason", "stable_target_capture_failed")), _dictionary(frozen.get("details", {}))))
	var eligibility := _dictionary(frozen.get("eligibility", {}))
	if not bool(eligibility.get("allowed", false)):
		return _remember(_rejection(str(eligibility.get("reason_code", "card_play_rejected")), eligibility))
	if bool(eligibility.get("requires_target_monster", false)) and not request.has("target_slot"):
		return _remember(_begin_target(TARGET_MONSTER, player_index, slot_index, _dictionary(frozen.get("envelope", {})), StableTargetEnvelope.card_fingerprint(skill)))
	if bool(eligibility.get("requires_target_player", false)) and not request.has("target_player"):
		return _remember(_begin_target(TARGET_PLAYER, player_index, slot_index, _dictionary(frozen.get("envelope", {})), StableTargetEnvelope.card_fingerprint(skill)))
	return _remember(_submit_legacy(player_index, slot_index, eligibility, _dictionary(frozen.get("envelope", {}))))


func submit_card_play(request: Dictionary) -> Dictionary:
	_submission_count += 1
	var player_index := int(request.get("player_index", -1))
	var slot_index := int(request.get("slot_index", -1))
	var card_context := _card_at(player_index, slot_index)
	if not bool(card_context.get("valid", false)):
		return _remember(_rejection("card_slot_invalid"))
	var skill: Dictionary = card_context.get("skill", {})
	if _is_v06_runtime_card(skill):
		var v06_envelope := _capture_stable_target_envelope(request, {})
		if v06_envelope.is_empty():
			return _remember(_rejection("stable_target_capture_failed"))
		if _uses_shared_resolution_v06(skill):
			return _remember(_submit_v06_automatic_supply_demand(player_index, slot_index, skill, v06_envelope))
		return _remember(_submit_v06(player_index, slot_index, skill, v06_envelope))
	var frozen := _pending_or_new_submission(player_index, slot_index, skill, request)
	if not bool(frozen.get("prepared", false)):
		return _remember(_rejection(str(frozen.get("reason", "stable_target_capture_failed")), _dictionary(frozen.get("details", {}))))
	var eligibility := _dictionary(frozen.get("eligibility", {}))
	if not bool(eligibility.get("allowed", false)):
		return _remember(_rejection(str(eligibility.get("reason_code", "card_play_rejected")), eligibility))
	return _remember(_submit_legacy(player_index, slot_index, eligibility, _dictionary(frozen.get("envelope", {}))))


func submit_monster_counter_conversion(request: Dictionary) -> Dictionary:
	_submission_count += 1
	if str(request.get("submission_source", "")) != "ai_counter_conversion":
		return _remember(_rejection("counter_conversion_source_invalid"))
	var player_index := int(request.get("player_index", -1))
	var slot_index := int(request.get("slot_index", -1))
	var card_context := _card_at(player_index, slot_index)
	if not bool(card_context.get("valid", false)):
		return _remember(_rejection("card_slot_invalid"))
	var source_skill := _dictionary(card_context.get("skill", {}))
	var conversion_preflight := _prepare_legacy_submission(
		player_index,
		source_skill,
		"hand",
		request
	)
	if not bool(conversion_preflight.get("prepared", false)):
		return _remember(_rejection(str(conversion_preflight.get(
			"reason",
			"counter_conversion_preflight_failed"
		))))
	var conversion_eligibility := _dictionary(conversion_preflight.get("eligibility", {}))
	if str(conversion_eligibility.get("reason_code", "")) != "counter_conversion_ready":
		return _remember(_rejection(str(conversion_eligibility.get(
			"reason_code",
			"counter_conversion_not_allowed"
		))))
	var counter_skill := _counter_skill_from_monster(source_skill)
	if counter_skill.is_empty():
		return _remember(_rejection("counter_conversion_definition_missing"))
	var prepared := _prepare_legacy_submission(
		player_index,
		counter_skill,
		"rule",
		request
	)
	if not bool(prepared.get("prepared", false)):
		return _remember(_rejection(str(prepared.get(
			"reason",
			"counter_submission_preflight_failed"
		))))
	var eligibility := _dictionary(prepared.get("eligibility", {}))
	if not bool(eligibility.get("allowed", false)):
		return _remember(_rejection(
			str(eligibility.get("reason_code", "counter_submission_rejected")),
			eligibility
		))
	var receipt := _submit_legacy(
		player_index,
		slot_index,
		eligibility,
		_dictionary(prepared.get("envelope", {})),
		counter_skill
	)
	if bool(receipt.get("accepted", false)):
		receipt["converted_monster_counter"] = true
		receipt["source_card_name"] = str(source_skill.get("name", ""))
	return _remember(receipt)


func submit_v06_facility_play_action(request: Dictionary) -> Dictionary:
	_submission_count += 1
	if _runtime_coordinator == null or _world_session_state == null:
		return _remember(_rejection("v06_runtime_unavailable"))
	var player_index := int(request.get("player_index", -1))
	var slot_index := int(request.get("slot_index", -1))
	var actor_id := str(request.get("actor_id", "")).strip_edges()
	var card_id := str(request.get("card_id", "")).strip_edges()
	var runtime_instance_id := str(request.get("runtime_instance_id", "")).strip_edges()
	var region_id := str(request.get("region_id", "")).strip_edges()
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	if player_index < 0 or slot_index < 0 or actor_id.is_empty() or card_id.is_empty() \
			or runtime_instance_id.is_empty() or region_id.is_empty() or transaction_id.is_empty():
		return _remember(_rejection("v06_facility_submission_invalid"))
	var actor_binding := _runtime_coordinator.actor_id_for_player_index(player_index)
	if not bool(actor_binding.get("available", false)) or str(actor_binding.get("actor_id", "")) != actor_id:
		return _remember(_rejection("v06_actor_mapping_changed"))
	var authoritative_card := _v06_authoritative_card_at(actor_id, slot_index)
	var machine: Dictionary = authoritative_card.get("machine", {}) if authoritative_card.get("machine", {}) is Dictionary else {}
	if not _v06_is_facility_card(authoritative_card) \
			or str(machine.get("card_id", "")) != card_id \
			or str(authoritative_card.get("runtime_instance_id", "")) != runtime_instance_id:
		return _remember(_rejection("v06_authoritative_slot_changed"))
	var district_index := _district_index_for_region_id(region_id)
	if district_index < 0:
		return _remember(_rejection("public_facility_target_unavailable"))
	var gate := _v06_facility_eligibility(player_index, slot_index, authoritative_card, {
		"selected_district": district_index,
		"slot_index": slot_index,
		"game_time": _world_session_state.game_time,
	})
	if not bool(gate.get("allowed", false)) or not bool(gate.get("actionable", false)):
		return _remember(_rejection(str(gate.get("reason_code", "card_play_rejected")), gate))
	var result := _runtime_coordinator.play_v06_runtime_card({
		"actor_id": actor_id,
		"slot_index": slot_index,
		"transaction_id": transaction_id,
		"region_id": region_id,
		"game_time": _world_session_state.game_time,
	})
	var committed := bool(result.get("committed", false)) and bool(_dictionary(result.get("effect_finalization", {})).get("finalized", result.get("finalized", false)))
	if committed:
		_accepted_count += 1
	return _remember({
		"accepted": committed,
		"queued": false,
		"reason": str(result.get("reason_code", "v06_card_play_committed" if committed else "v06_card_play_rejected")),
		"v06_receipt": result.duplicate(true),
		"player_message": "卡牌事务已完成。" if committed else "卡牌当前未能生效。",
	})


func debug_snapshot() -> Dictionary:
	return {
		"controller_ready": _world_session_state != null \
			and _eligibility_facts != null \
			and _queue_service != null \
			and _selection_catalog_query_port != null,
		"submission_count": _submission_count,
		"accepted_count": _accepted_count,
		"shared_human_ai_entry": true,
		"stable_target_capture": _selection_catalog_query_port != null,
		"holds_main_reference": false,
		"monster_wager_cash_commitment_guard_bound": _cash_commitment_query_port != null,
		"last_receipt": _last_receipt.duplicate(true),
	}


func _submit_legacy(
	player_index: int,
	slot_index: int,
	eligibility: Dictionary,
	stable_target_envelope: Dictionary,
	queued_skill_override: Dictionary = {}
) -> Dictionary:
	var envelope_validation := StableTargetEnvelope.validate(stable_target_envelope)
	if not bool(envelope_validation.get("valid", false)):
		return _rejection(str(envelope_validation.get("reason_code", "stable_target_invalid")))
	var frozen_context := StableTargetEnvelope.context_at_capture(stable_target_envelope)
	if frozen_context.is_empty():
		return _rejection("stable_target_context_missing")
	var players := _world_session_state.players
	var player: Dictionary = players[player_index]
	var slots: Array = player.get("slots", [])
	var source_skill: Dictionary = (slots[slot_index] as Dictionary).duplicate(true)
	if bool(source_skill.get("queued_for_resolution", false)):
		return _rejection("already_queued")
	var target_status: Dictionary = eligibility.get("target_status", {}) if eligibility.get("target_status", {}) is Dictionary else {}
	var runtime_state := _resolution_controller.card_play_fact_snapshot() if _resolution_controller != null else {}
	var reactive_counter := bool(target_status.get("is_counter", false)) and bool(runtime_state.get("counter_window_active", false)) and not _queue_service.active_entry().is_empty()
	var submitted_skill := queued_skill_override.duplicate(true) \
		if not queued_skill_override.is_empty() else source_skill
	var queued_skill := _skill_with_financial_terms(submitted_skill)
	if queued_skill.has("submission_terms_error"):
		return _rejection(str(queued_skill.get("submission_terms_error", "financial_terms_missing")))
	if str(queued_skill.get("kind", "")) == "public_facility":
		queued_skill["target_region_index"] = int(frozen_context.get("selected_district", -1))
	var requirement_status: Dictionary = eligibility.get("requirement_status", {}) if eligibility.get("requirement_status", {}) is Dictionary else {}
	var entry_context := {
		"target_slot": int(frozen_context.get("target_slot", -1)),
		"target_monster_uid": int(frozen_context.get("target_monster_uid", -1)),
		"target_player": int(frozen_context.get("target_player", -1)),
		"selected_district": int(frozen_context.get("selected_district", -1)),
		"selected_trade_product": str(frozen_context.get("selected_trade_product", "")),
		"selected_card_resolution_id": int(frozen_context.get("selected_card_resolution_id", -1)),
		"queued_time": _world_session_state.game_time,
		"play_requirement_kind": str(requirement_status.get("kind", "none")),
		"play_requirement_scope": str(requirement_status.get("scope", "")),
		"play_requirement_gdp_share_percent": int(requirement_status.get("required_share_percent", 0)),
		"play_requirement_district": int(frozen_context.get("play_requirement_district", requirement_status.get("qualifying_district", -1))),
		"play_requirement_product": "",
		"play_requirement_flow": 0,
		"play_requirement_text": str(requirement_status.get("requirement_text", "条件：无")),
		"stable_target_envelope": stable_target_envelope.duplicate(true),
	}
	var play_cash_cost := maxi(0, int(eligibility.get("cash_cost", 0)))
	var available_cash_cents := int(player.get("cash_cents", int(player.get("cash", 0)) * 100))
	if _cash_commitment_query_port != null:
		available_cash_cents = _cash_commitment_query_port.available_cash_cents(player_index)
	var queue_plan := _runtime_coordinator.plan_card_resolution_queue_submission({
		"player_index": player_index,
		"slot_index": slot_index,
		"already_queued": bool(source_skill.get("queued_for_resolution", false)),
		"reactive_counter": reactive_counter,
		"group_card_limit": 1,
		"play_cash_cost_cents": play_cash_cost * 100,
		"financial_margin_cents": int(eligibility.get("financial_margin_cash", 0)) * 100,
		"financial_terms_version": str(eligibility.get("financial_terms_version", "")),
		"available_cash_cents": available_cash_cents,
		"cash_revision": "%d" % available_cash_cents,
		"asset_cost": _dictionary(eligibility.get("asset_cost", queued_skill.get("asset_cost", {}))),
		"skill": queued_skill,
		"entry_context": entry_context,
	}, {
		"player_count": players.size(),
		"counter_window_active": bool(runtime_state.get("counter_window_active", false)),
		"batch_locked": bool(runtime_state.get("batch_locked", false)),
		"simultaneous_timer": float(runtime_state.get("simultaneous_timer", 0.0)),
		"lock_duration": float(_resolution_controller.lock_seconds),
		"public_bid_duration": float(_resolution_controller.public_bid_seconds),
		"window_sequence": int(runtime_state.get("window_sequence", 0)),
		"reference_player": int(runtime_state.get("batch_reference_player", -1)),
	})
	if not bool(queue_plan.get("accepted", false)):
		return _rejection(str(queue_plan.get("reason", "queue_rejected")), queue_plan)
	var committed_entry: Dictionary = _dictionary(queue_plan.get("entry", {}))
	var committed_skill: Dictionary = _dictionary(committed_entry.get("skill", {}))
	var inventory_request := {
		"inventory": _inventory_snapshot(player),
		"target_slot": slot_index,
		"queued_skill": committed_skill,
		"consumed_on_queue": bool(queue_plan.get("consumed_on_queue", false)),
	}
	var inventory_plan := _runtime_coordinator.plan_card_inventory_queue_commit(inventory_request)
	if not bool(inventory_plan.get("ready", false)):
		return _rejection(str(inventory_plan.get("reason", "inventory_plan_rejected")))
	var prepared_player := player.duplicate(true)
	var inventory_commit := _runtime_coordinator.commit_card_inventory_queue_commit(prepared_player, inventory_request, inventory_plan)
	if not bool(inventory_commit.get("committed", false)):
		return _rejection(str(inventory_commit.get("reason", "inventory_commit_failed")))
	var total_cash_authorized_cents := play_cash_cost * 100 + maxi(0, int(queue_plan.get("financial_margin_cents", 0)))
	if _cash_commitment_query_port != null:
		var cash_authorization := _cash_commitment_query_port.authorize_debit_cents(player_index, total_cash_authorized_cents)
		if not bool(cash_authorization.get("authorized", false)):
			return _rejection(str(cash_authorization.get("reason_code", "cash_reserved_for_monster_wager")))
	var queue_commit := _runtime_coordinator.commit_card_resolution_queue_submission(queue_plan, {
		"authorized": true,
		"inventory_committed": true,
		"play_cost_authorized": available_cash_cents >= total_cash_authorized_cents,
		"financial_margin_authorized": available_cash_cents >= total_cash_authorized_cents,
		"asset_authorized": true,
	})
	if not bool(queue_commit.get("committed", false)):
		return _rejection(str(queue_commit.get("reason", "queue_commit_failed")))
	prepared_player["queued_card_tip"] = 0
	var prepared_cash := WorldSessionState.canonical_private_cash_record(prepared_player)
	var next_cash_cents := maxi(0, int(prepared_cash.get("cash_cents", 0)) - play_cash_cost * 100)
	prepared_player["cash_cents"] = next_cash_cents
	prepared_player["cash"] = floori(float(next_cash_cents) / 100.0)
	players[player_index] = prepared_player
	_world_session_state.players = players
	_resolution_controller.set_player_ready(player_index, false, _active_player_indices(players))
	if bool(queue_commit.get("begins_new_batch", false)):
		var sequence := int(queue_commit.get("next_window_sequence", int(runtime_state.get("window_sequence", 0)) + 1))
		_resolution_controller.begin_group_window(-1.0, int(queue_commit.get("reference_player", player_index)), sequence)
	_accepted_count += 1
	return {
		"accepted": true,
		"queued": true,
		"reason": "queued",
		"route": str(queue_commit.get("route", "current")),
		"resolution_id": int(committed_entry.get("resolution_id", -1)),
		"player_message": "卡牌已进入共享卡牌窗。",
	}


func _submit_v06(player_index: int, slot_index: int, card: Dictionary, stable_target_envelope: Dictionary) -> Dictionary:
	if _runtime_coordinator == null:
		return _rejection("v06_runtime_unavailable")
	var actor_id := str((_world_session_state.players[player_index] as Dictionary).get("actor_id", "player.%d" % player_index)).strip_edges()
	var validation := StableTargetEnvelope.validate(stable_target_envelope)
	if not bool(validation.get("valid", false)):
		return _rejection(str(validation.get("reason_code", "stable_target_invalid")))
	var region_id := str(stable_target_envelope.get("region_id", ""))
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var runtime_instance_id := str(card.get("runtime_instance_id", ""))
	var authoritative_slot := _v06_authoritative_slot(actor_id, str(machine.get("card_id", "")), runtime_instance_id, slot_index)
	if authoritative_slot < 0 or authoritative_slot != slot_index:
		return _rejection("v06_authoritative_slot_changed")
	var authoritative_card := _v06_authoritative_card_at(actor_id, authoritative_slot)
	runtime_instance_id = str(authoritative_card.get("runtime_instance_id", ""))
	if runtime_instance_id.is_empty():
		return _rejection("v06_authoritative_instance_missing")
	if _v06_is_facility_card(authoritative_card):
		var frozen_context := StableTargetEnvelope.context_at_capture(stable_target_envelope)
		if frozen_context.is_empty():
			return _rejection("stable_target_context_missing")
		frozen_context["slot_index"] = authoritative_slot
		frozen_context["game_time"] = _world_session_state.game_time
		var gate := _v06_facility_eligibility(player_index, authoritative_slot, authoritative_card, frozen_context)
		if not bool(gate.get("allowed", false)) or not bool(gate.get("actionable", false)):
			return _rejection(str(gate.get("reason_code", "card_play_rejected")), gate)
	var result := _runtime_coordinator.play_v06_runtime_card({
		"actor_id": actor_id,
		"slot_index": authoritative_slot,
		"transaction_id": "v06-play:%s:%s:%s" % [actor_id, runtime_instance_id, region_id],
		"region_id": region_id,
		"game_time": _world_session_state.game_time,
	})
	var committed := bool(result.get("committed", false)) and bool(_dictionary(result.get("effect_finalization", {})).get("finalized", result.get("finalized", false)))
	if committed:
		_accepted_count += 1
	return {
		"accepted": committed,
		"queued": false,
		"reason": str(result.get("reason_code", "v06_card_play_committed" if committed else "v06_card_play_rejected")),
		"v06_receipt": result,
		"player_message": "卡牌事务已完成。" if committed else "卡牌当前未能生效。",
	}


func _submit_v06_automatic_supply_demand(
	player_index: int,
	slot_index: int,
	card: Dictionary,
	stable_target_envelope: Dictionary
) -> Dictionary:
	if _runtime_coordinator == null or _world_session_state == null or _resolution_controller == null:
		return _rejection("v06_runtime_unavailable")
	var validation := StableTargetEnvelope.validate(stable_target_envelope)
	var frozen_context := StableTargetEnvelope.context_at_capture(stable_target_envelope)
	if not bool(validation.get("valid", false)) or frozen_context.is_empty():
		return _rejection(str(validation.get("reason_code", "stable_target_invalid")))
	var actor_binding := _runtime_coordinator.actor_id_for_player_index(player_index)
	if not bool(actor_binding.get("available", false)):
		return _rejection(str(actor_binding.get("reason_code", "v06_actor_mapping_unavailable")))
	var actor_id := str(actor_binding.get("actor_id", ""))
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var player_text: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
	var card_id := str(machine.get("card_id", ""))
	var card_instance_id := str(card.get("runtime_instance_id", ""))
	var effect_kind := str(machine.get("effect_kind", ""))
	var authoritative_slot := _v06_authoritative_slot(actor_id, card_id, card_instance_id, slot_index)
	if authoritative_slot < 0 or authoritative_slot != slot_index:
		return _rejection("v06_authoritative_slot_changed")
	var authoritative_card := _v06_authoritative_card_at(actor_id, authoritative_slot)
	card_instance_id = str(authoritative_card.get("runtime_instance_id", ""))
	if card_instance_id.is_empty():
		return _rejection("v06_authoritative_instance_missing")
	card = authoritative_card
	machine = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	player_text = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
	if not _runtime_coordinator.has_method("preflight_v06_automatic_supply_demand"):
		return _rejection("core_economic_runtime_unavailable")
	var preflight_variant: Variant = _runtime_coordinator.call("preflight_v06_automatic_supply_demand", actor_id, card.duplicate(true))
	var preflight: Dictionary = preflight_variant if preflight_variant is Dictionary else {}
	if not bool(preflight.get("ready", false)):
		return _rejection(str(preflight.get("reason_code", "queued_supply_demand_conditions_unmet")), preflight)
	var players := _world_session_state.players
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return _rejection("invalid_player")
	var player: Dictionary = players[player_index]
	var queued_skill := card.duplicate(true)
	queued_skill["name"] = str(player_text.get("name", card_id))
	queued_skill["display_name"] = str(player_text.get("name", card_id))
	queued_skill["kind"] = str(machine.get("category_id", "supply_demand"))
	queued_skill["family_id"] = str(machine.get("family_id", card_id))
	queued_skill["rank"] = maxi(1, int(machine.get("rank", 1)))
	queued_skill["persistent"] = false
	queued_skill["asset_cost"] = _dictionary(machine.get("asset_cost", {}))
	var entry_context := {
		"target_slot": int(frozen_context.get("target_slot", -1)),
		"target_monster_uid": int(frozen_context.get("target_monster_uid", -1)),
		"target_player": int(frozen_context.get("target_player", -1)),
		"selected_district": int(frozen_context.get("selected_district", -1)),
		"selected_trade_product": str(frozen_context.get("selected_trade_product", "")),
		"selected_card_resolution_id": int(frozen_context.get("selected_card_resolution_id", -1)),
		"play_requirement_district": int(frozen_context.get("play_requirement_district", -1)),
		"queued_time": _world_session_state.game_time,
		"stable_target_envelope": stable_target_envelope.duplicate(true),
		"v06_actor_id": actor_id,
		"v06_card_id": card_id,
		"v06_card_instance_id": card_instance_id,
		"v06_effect_kind": effect_kind,
	}
	var runtime_state := _resolution_controller.card_play_fact_snapshot()
	var available_cash_cents := int(player.get("cash_cents", int(player.get("cash", 0)) * 100))
	if _cash_commitment_query_port != null:
		available_cash_cents = _cash_commitment_query_port.available_cash_cents(player_index)
	var queue_plan := _runtime_coordinator.plan_card_resolution_queue_submission({
		"player_index": player_index,
		"slot_index": slot_index,
		"already_queued": bool(card.get("queued_for_resolution", false)),
		"reactive_counter": false,
		"group_card_limit": 1,
		"play_cash_cost_cents": 0,
		"financial_margin_cents": 0,
		"financial_terms_version": "",
		"available_cash_cents": available_cash_cents,
		"cash_revision": "%d" % available_cash_cents,
		"asset_cost": queued_skill["asset_cost"],
		"skill": queued_skill,
		"entry_context": entry_context,
	}, {
		"player_count": players.size(),
		"counter_window_active": bool(runtime_state.get("counter_window_active", false)),
		"batch_locked": bool(runtime_state.get("batch_locked", false)),
		"simultaneous_timer": float(runtime_state.get("simultaneous_timer", 0.0)),
		"lock_duration": float(_resolution_controller.lock_seconds),
		"public_bid_duration": float(_resolution_controller.public_bid_seconds),
		"window_sequence": int(runtime_state.get("window_sequence", 0)),
		"reference_player": int(runtime_state.get("batch_reference_player", -1)),
	})
	if not bool(queue_plan.get("accepted", false)):
		return _rejection(str(queue_plan.get("reason", "queue_rejected")), queue_plan)
	var committed_entry := _dictionary(queue_plan.get("entry", {}))
	var inventory_request := {
		"inventory": _inventory_snapshot(player),
		"target_slot": slot_index,
		"queued_skill": _dictionary(committed_entry.get("skill", {})),
		"consumed_on_queue": bool(queue_plan.get("consumed_on_queue", false)),
	}
	var inventory_plan := _runtime_coordinator.plan_card_inventory_queue_commit(inventory_request)
	if not bool(inventory_plan.get("ready", false)):
		return _rejection(str(inventory_plan.get("reason", "inventory_plan_rejected")))
	var prepared_player := player.duplicate(true)
	var inventory_commit := _runtime_coordinator.commit_card_inventory_queue_commit(prepared_player, inventory_request, inventory_plan)
	if not bool(inventory_commit.get("committed", false)):
		return _rejection(str(inventory_commit.get("reason", "inventory_commit_failed")))
	var queue_commit := _runtime_coordinator.commit_card_resolution_queue_submission(queue_plan, {
		"authorized": true,
		"inventory_committed": true,
		"play_cost_authorized": true,
		"financial_margin_authorized": true,
		"asset_authorized": true,
	})
	if not bool(queue_commit.get("committed", false)):
		return _rejection(str(queue_commit.get("reason", "queue_commit_failed")))
	prepared_player["queued_card_tip"] = 0
	players[player_index] = prepared_player
	_world_session_state.players = players
	_resolution_controller.set_player_ready(player_index, false, _active_player_indices(players))
	if bool(queue_commit.get("begins_new_batch", false)):
		var sequence := int(queue_commit.get("next_window_sequence", int(runtime_state.get("window_sequence", 0)) + 1))
		_resolution_controller.begin_group_window(-1.0, int(queue_commit.get("reference_player", player_index)), sequence)
	_accepted_count += 1
	return {
		"accepted": true,
		"queued": true,
		"reason": "queued",
		"route": str(queue_commit.get("route", "current")),
		"resolution_id": int(committed_entry.get("resolution_id", -1)),
		"player_message": "卡牌已进入共享卡牌窗。",
	}


func _v06_authoritative_slot(
	actor_id: String,
	card_id: String,
	runtime_instance_id: String = "",
	preferred_slot_index: int = -1
) -> int:
	var player := _runtime_coordinator.v06_card_player_snapshot(actor_id)
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	if preferred_slot_index >= 0 and preferred_slot_index < slots.size() and slots[preferred_slot_index] is Dictionary:
		var preferred: Dictionary = slots[preferred_slot_index]
		var preferred_machine: Dictionary = preferred.get("machine", {}) if preferred.get("machine", {}) is Dictionary else {}
		if str(preferred_machine.get("card_id", "")) == card_id \
				and (runtime_instance_id.is_empty() or str(preferred.get("runtime_instance_id", "")) == runtime_instance_id):
			return preferred_slot_index
	if runtime_instance_id.is_empty():
		return -1
	for index in range(slots.size()):
		if slots[index] is Dictionary:
			var machine: Dictionary = (slots[index] as Dictionary).get("machine", {}) if (slots[index] as Dictionary).get("machine", {}) is Dictionary else {}
			if str(machine.get("card_id", "")) == card_id \
					and str((slots[index] as Dictionary).get("runtime_instance_id", "")) == runtime_instance_id:
				return index
	return -1


func _v06_authoritative_card_at(actor_id: String, slot_index: int) -> Dictionary:
	var player := _runtime_coordinator.v06_card_player_snapshot(actor_id)
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return {}
	return (slots[slot_index] as Dictionary).duplicate(true)


func _v06_facility_eligibility(
	player_index: int,
	slot_index: int,
	card: Dictionary,
	context: Dictionary
) -> Dictionary:
	if not _v06_is_facility_card(card):
		return {"allowed": false, "actionable": false, "reason_code": "public_facility_card_unavailable"}
	var gate_context := context.duplicate(true)
	gate_context["slot_index"] = slot_index
	gate_context["game_time"] = _world_session_state.game_time if _world_session_state != null else 0.0
	return _eligibility(player_index, _normalized_v06_facility_skill(card), "hand", gate_context)


func _normalized_v06_facility_skill(card: Dictionary) -> Dictionary:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var result := {
		"name": str(machine.get("card_id", "")),
		"card_id": str(machine.get("card_id", "")),
		"family_id": str(machine.get("family_id", "")),
		"schema_version": "v0.6",
		"kind": "public_facility",
		"rank": maxi(1, int(machine.get("rank", 1))),
		"asset_cost": _normalized_v06_asset_cost(machine.get("asset_cost", {})),
		"play_cash": 0,
	}
	for state_key in ["queued_for_resolution", "lock_left", "cooldown_left"]:
		if card.has(state_key):
			result[state_key] = card.get(state_key)
	return result


func _normalized_v06_asset_cost(value: Variant) -> Dictionary:
	var source := _dictionary(value)
	var result: Dictionary = {}
	for key_variant in source.keys():
		var key := str(key_variant)
		var amount_variant: Variant = source.get(key_variant, 0)
		if V06_ASSET_COST_KEYS.has(key) and amount_variant is float \
				and is_finite(float(amount_variant)) and float(amount_variant) >= 0.0 \
				and float(amount_variant) <= MAX_EXACT_JSON_INTEGER \
				and float(amount_variant) == floor(float(amount_variant)):
			result[key] = int(amount_variant)
		else:
			result[key] = amount_variant
	return result


func _district_index_for_region_id(region_id: String) -> int:
	if _world_session_state == null:
		return -1
	for district_index in range(_world_session_state.districts.size()):
		var district_variant: Variant = _world_session_state.districts[district_index]
		if district_variant is Dictionary and str((district_variant as Dictionary).get("region_id", "")) == region_id:
			return district_index
	return -1


func _pending_or_new_submission(player_index: int, slot_index: int, skill: Dictionary, request: Dictionary) -> Dictionary:
	var choice_kind := _choice_kind_for_request(request)
	if not choice_kind.is_empty() and _target_choice_controller != null and _target_choice_controller.has_choice(choice_kind):
		var choice := _target_choice_controller.choice_snapshot(choice_kind)
		if int(choice.get("player_index", -1)) != player_index or int(choice.get("slot_index", -1)) != slot_index:
			return {"prepared": false, "reason": "stable_target_choice_binding_mismatch"}
		var envelope := _dictionary(choice.get("stable_target_envelope", {}))
		var expected_card_fingerprint := str(choice.get("source_card_fingerprint", ""))
		if envelope.is_empty() or expected_card_fingerprint.is_empty():
			return {"prepared": false, "reason": "stable_target_context_missing"}
		if StableTargetEnvelope.card_fingerprint(skill) != expected_card_fingerprint:
			return {"prepared": false, "reason": "stable_target_card_changed"}
		var bound := StableTargetEnvelope.bind_target(
			envelope,
			_envelope_target_kind(choice_kind),
			int(request.get("target_slot", -1)),
			int(request.get("target_player", -1)),
			int(request.get("target_monster_uid", -1))
		)
		if bound.is_empty():
			return {"prepared": false, "reason": "stable_target_binding_invalid"}
		var frozen_context := StableTargetEnvelope.context_at_capture(bound)
		var eligibility := _eligibility(player_index, skill, "rule", frozen_context)
		var target_matches := bool(eligibility.get("requires_target_monster", false)) if choice_kind == TARGET_MONSTER else bool(eligibility.get("requires_target_player", false))
		if not target_matches:
			return {"prepared": false, "reason": "stable_target_kind_changed", "details": eligibility}
		return {"prepared": true, "eligibility": eligibility, "envelope": bound}
	return _prepare_legacy_submission(player_index, skill, "rule", request)


func _prepare_legacy_submission(
	player_index: int,
	skill: Dictionary,
	mode: String,
	request: Dictionary,
	forced_choice_kind: String = ""
) -> Dictionary:
	var selection_snapshot := _selection_snapshot(request)
	if selection_snapshot.is_empty():
		return {"prepared": false, "reason": "table_selection_unavailable"}
	var frozen_context := {
		"selected_district": int(selection_snapshot.get("selected_district", -1)),
		"selected_trade_product": str(selection_snapshot.get("selected_trade_product", "")),
		"selected_card_resolution_id": int(selection_snapshot.get("selected_card_resolution_id", -1)),
	}
	var eligibility := _eligibility(player_index, skill, mode, frozen_context)
	var choice_kind := forced_choice_kind
	if choice_kind.is_empty():
		if bool(eligibility.get("requires_target_monster", false)):
			choice_kind = TARGET_MONSTER
		elif bool(eligibility.get("requires_target_player", false)):
			choice_kind = TARGET_PLAYER
	var requirement_status := _dictionary(eligibility.get("requirement_status", {}))
	var envelope := _capture_stable_target_envelope(selection_snapshot, {
		"target_kind": _envelope_target_kind(choice_kind),
		"target_slot": int(request.get("target_slot", -1)),
		"target_player": int(request.get("target_player", -1)),
		"play_requirement_district": int(requirement_status.get("qualifying_district", -1)),
		"capture_source": str(request.get("submission_source", "card_play_submission")),
	})
	if envelope.is_empty():
		return {"prepared": false, "reason": "stable_target_capture_failed", "details": eligibility}
	return {"prepared": true, "eligibility": eligibility, "envelope": envelope}


func _capture_stable_target_envelope(selection_or_request: Dictionary, context: Dictionary) -> Dictionary:
	if _selection_catalog_query_port == null:
		return {}
	var selection_snapshot := selection_or_request
	if not selection_snapshot.has("schema_version") \
			or not selection_snapshot.has("revision") \
			or not selection_snapshot.has("selected_district") \
			or not selection_snapshot.has("selected_trade_product"):
		selection_snapshot = _selection_snapshot(selection_or_request)
	if selection_snapshot.is_empty():
		return {}
	return StableTargetEnvelope.capture(
		selection_snapshot,
		_selection_catalog_query_port.compose_region_catalog(),
		_selection_catalog_query_port.compose_product_catalog(),
		context
	)


func _selection_snapshot(request: Dictionary) -> Dictionary:
	var submission_source := str(request.get("submission_source", ""))
	if submission_source in ["ai", "ai_counter_conversion"]:
		for key in ["selected_district", "selected_trade_product", "selected_card_resolution_id", "target_source_revision"]:
			if not request.has(key):
				return {}
		if typeof(request["selected_district"]) != TYPE_INT \
				or typeof(request["selected_trade_product"]) != TYPE_STRING \
				or typeof(request["selected_card_resolution_id"]) != TYPE_INT \
				or typeof(request["target_source_revision"]) != TYPE_INT:
			return {}
		return {
			"schema_version": 1,
			"revision": maxi(0, int(request["target_source_revision"])),
			"selected_district": int(request["selected_district"]),
			"selected_trade_product": str(request["selected_trade_product"]),
			"selected_card_resolution_id": int(request["selected_card_resolution_id"]),
		}
	if _table_selection_state == null:
		return {}
	var result := _table_selection_state.snapshot()
	if request.has("selected_card_resolution_id"):
		result["selected_card_resolution_id"] = int(request.get("selected_card_resolution_id", -1))
	return result


func _choice_kind_for_request(request: Dictionary) -> String:
	if int(request.get("target_slot", -1)) >= 0:
		return TARGET_MONSTER
	if int(request.get("target_player", -1)) >= 0:
		return TARGET_PLAYER
	return ""


func _envelope_target_kind(choice_kind: String) -> String:
	if choice_kind == TARGET_MONSTER:
		return StableTargetEnvelope.TARGET_MONSTER
	if choice_kind == TARGET_PLAYER:
		return StableTargetEnvelope.TARGET_PLAYER
	return StableTargetEnvelope.TARGET_NONE


func _eligibility(player_index: int, skill: Dictionary, mode: String, context: Dictionary = {}) -> Dictionary:
	if _eligibility_facts == null or _eligibility_service == null:
		return {"allowed": false, "reason_code": "eligibility_service_missing"}
	var facts := _eligibility_facts.build_facts(player_index, skill, context)
	facts["commodity_color_flow"] = _runtime_coordinator.commodity_color_flow_snapshot(player_index)
	facts["player_mana"] = _runtime_coordinator.player_mana_availability(player_index)
	return _eligibility_service.evaluate_play({"player_index": player_index, "skill": skill, "evaluation_mode": mode}, facts)


func _skill_with_financial_terms(skill: Dictionary) -> Dictionary:
	var result := skill.duplicate(true)
	match str(result.get("kind", "")):
		"product_futures":
			if _product_market_controller == null:
				result["submission_terms_error"] = "product_futures_terms_unavailable"
				return result
			result = _product_market_controller.skill_with_terms(str(result.get("name", "")), result)
			if result.has("futures_terms_error"):
				result["submission_terms_error"] = str(result.get("futures_terms_error"))
		"city_gdp_derivative":
			if _derivative_controller == null:
				result["submission_terms_error"] = "gdp_derivative_terms_unavailable"
				return result
			result = _derivative_controller.skill_with_terms(str(result.get("name", "")), result)
			if result.has("gdp_derivative_terms_error"):
				result["submission_terms_error"] = str(result.get("gdp_derivative_terms_error"))
	return result


func _begin_target(
	kind: String,
	player_index: int,
	slot_index: int,
	stable_target_envelope: Dictionary,
	source_card_fingerprint: String
) -> Dictionary:
	if _target_choice_controller == null:
		return _rejection("target_choice_controller_missing")
	var choice := _target_choice_controller.begin_choice(kind, player_index, slot_index, stable_target_envelope, source_card_fingerprint)
	if choice.is_empty() or not bool(choice.get("accepted", true)):
		return _rejection(str(choice.get("reason", "target_choice_rejected")), choice)
	return {
		"accepted": true,
		"queued": false,
		"target_choice_started": not choice.is_empty(),
		"target_kind": kind,
		"choice": choice,
		"reason": "target_choice_started",
		"player_message": "请选择目标怪兽。" if kind == TARGET_MONSTER else "请选择目标玩家。",
	}


func _card_at(player_index: int, slot_index: int) -> Dictionary:
	if _world_session_state == null or player_index < 0 or player_index >= _world_session_state.players.size():
		return {"valid": false}
	var player: Dictionary = _world_session_state.players[player_index]
	if bool(player.get("eliminated", false)):
		return {"valid": false, "reason": "player_eliminated"}
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return {"valid": false}
	return {"valid": true, "skill": (slots[slot_index] as Dictionary).duplicate(true)}


func _inventory_snapshot(player: Dictionary) -> Dictionary:
	var slot_facts: Array = []
	var counted := 0
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			slot_facts.append({"slot_index": slot_index, "occupied": false})
			continue
		var card: Dictionary = slots[slot_index]
		var counts := not (bool(card.get("persistent", false)) and str(card.get("kind", "")) in ["monster_bound_action", "military_command"])
		if counts:
			counted += 1
		slot_facts.append({
			"slot_index": slot_index,
			"occupied": true,
			"card_id": str(card.get("name", "")),
			"family": str(card.get("family_id", card.get("name", ""))),
			"rank": maxi(1, int(card.get("rank", 1))),
			"counts_toward_hand_limit": counts,
			"queued_for_resolution": bool(card.get("queued_for_resolution", false)),
			"lock_left": float(card.get("lock_left", 0.0)),
			"next_upgrade_id": "",
			"next_upgrade_card": {},
		})
	return {"valid": false, "counted_hand_size": counted, "hand_limit": 5, "discard_slot": -1, "slots": slot_facts}


func _active_player_indices(players: Array) -> Array:
	var result: Array = []
	for index in range(players.size()):
		if players[index] is Dictionary and not bool((players[index] as Dictionary).get("eliminated", false)):
			result.append(index)
	return result


func _is_v06_runtime_card(card: Dictionary) -> bool:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return not str(machine.get("card_id", "")).is_empty() and not str(machine.get("effect_kind", "")).is_empty()


func _v06_is_facility_card(card: Dictionary) -> bool:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return str(machine.get("category_id", "")) == "facility" \
		and str(machine.get("effect_kind", "")) == "build_upgrade_or_repair_facility" \
		and str(machine.get("target_kind", "")) == "region_unique_facility_slot"


func _uses_shared_resolution_v06(card: Dictionary) -> bool:
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return SHARED_RESOLUTION_EFFECT_KINDS_V06.has(str(machine.get("effect_kind", "")))


func _rejection(reason: String, details: Dictionary = {}) -> Dictionary:
	return {
		"accepted": false,
		"queued": false,
		"reason": reason,
		"details": details.duplicate(true),
		"player_message": "卡牌未能提交（%s）。" % reason,
	}


func _remember(receipt: Dictionary) -> Dictionary:
	_last_receipt = receipt.duplicate(true)
	return receipt


func _counter_skill_from_monster(source_skill: Dictionary) -> Dictionary:
	if _runtime_coordinator == null or str(source_skill.get("kind", "")) != "monster_card":
		return {}
	var source_name := str(source_skill.get("name", "怪兽牌"))
	var counter_rank := clampi(_runtime_coordinator.card_rank(source_name), 1, 4)
	var counter_name := "相位否决%d" % counter_rank
	var counter_skill := _runtime_coordinator.card_definition(counter_name)
	if counter_skill.is_empty():
		return {}
	counter_skill["name"] = counter_name
	counter_skill = CardPlayRequirementPolicyScript.apply_to_card(counter_name, counter_skill)
	if str(counter_skill.get("use_case", "")).strip_edges().is_empty():
		var presentation := _runtime_coordinator.compose_card_presentation({
			"card_name": counter_name,
			"skill": counter_skill,
		})
		counter_skill["use_case"] = str(presentation.get("use_case", ""))
	counter_skill["cooldown"] = float(counter_skill.get("cooldown", 0.0))
	counter_skill["cooldown_left"] = 0.0
	counter_skill["lock_left"] = 0.0
	counter_skill["source_card_name"] = source_name
	counter_skill["text"] = "%s（由%s临时改写；会消耗该怪兽牌。）" % [
		str(counter_skill.get("text", "")),
		_card_display_name(source_name),
	]
	return counter_skill


func _card_display_name(card_name: String) -> String:
	if card_name.is_empty() or _runtime_coordinator == null:
		return ""
	var family := _runtime_coordinator.card_family_id(card_name)
	var rank := clampi(_runtime_coordinator.card_rank(card_name), 1, 4)
	var roman_levels := ["I", "II", "III", "IV"]
	return "%s %s级" % [family, roman_levels[rank - 1]]


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []

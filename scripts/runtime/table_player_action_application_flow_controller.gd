@tool
extends Node
class_name TablePlayerActionApplicationFlowController

signal receipt_ready(receipt: Dictionary)

const INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const RECEIPT := preload("res://scripts/semantic/game_action_receipt_v1.gd")
const CARD_BINDING := preload("res://scripts/semantic/game_action_card_binding_v1.gd")
const AI_CAPABILITY := preload("res://scripts/runtime/game_action_ai_submission_capability.gd")

const JOURNAL_LIMIT := 128

@export var identity_boundary_path: NodePath
@export var world_session_state_path: NodePath
@export var game_session_path: NodePath
@export var table_selection_state_path: NodePath
@export var action_offer_source_path: NodePath
@export var card_play_submission_path: NodePath
@export var card_group_action_port_path: NodePath
@export var table_selection_intent_port_path: NodePath
@export var district_supply_action_port_path: NodePath
@export var presentation_query_ports_path: NodePath
@export var presentation_refresh_port_path: NodePath

var _ai_capability: GameActionAiSubmissionCapability
var _ai_capability_nonce := 0
var _journal: Dictionary = {}
var _journal_order: Array[String] = []
var _journal_session_key := ""
var _operation_revision := 0
var _submission_count := 0
var _accepted_count := 0
var _rejected_count := 0
var _replay_count := 0
var _recovery_delivery_count := 0
var _collision_count := 0
var _stale_count := 0
var _human_submission_count := 0
var _ai_submission_count := 0
var _refresh_request_count := 0
var _card_play_apply_count := 0
var _card_group_apply_count := 0
var _district_selection_apply_count := 0
var _district_adapter_apply_count := 0
var _district_quote_bindings: Dictionary = {}


func bind_ai_submission_capability(capability: GameActionAiSubmissionCapability) -> bool:
	if capability == null:
		return false
	if _ai_capability != null:
		return capability == _ai_capability
	_ai_capability_nonce = maxi(1, int(get_instance_id()))
	capability.bind_owner_nonce(_ai_capability_nonce)
	if not capability.matches_owner_nonce(_ai_capability_nonce):
		_ai_capability_nonce = 0
		return false
	_ai_capability = capability
	return true


func human_card_play_offer(
	actor_index: int,
	slot_index: int,
	source_revision: int,
	available: bool,
	disabled_reason_id: String,
	region_id := "",
	selected_resolution_id := -1
) -> Dictionary:
	var context := _identity().authorize_actor_index(actor_index, &"game_screen") if _identity() != null else null
	if context == null or not context.is_valid():
		return {}
	return _card_play_offer(
		actor_index,
		slot_index,
		source_revision,
		available,
		disabled_reason_id,
		region_id,
		selected_resolution_id
	)


func ai_card_play_offer(
	capability: GameActionAiSubmissionCapability,
	actor_index: int,
	slot_index: int,
	region_id := "",
	selected_resolution_id := -1
) -> Dictionary:
	if not _ai_capability_matches(capability) or not _actor_is_ai(actor_index):
		return {}
	return _card_play_offer(
		actor_index,
		slot_index,
		current_ai_source_revision(actor_index),
		_card_at(actor_index, slot_index).size() > 0,
		"none" if not _card_at(actor_index, slot_index).is_empty() else "card-slot-invalid",
		region_id,
		selected_resolution_id
	)


func human_action_offer(
	action_id: String,
	source_revision: int,
	available: bool,
	disabled_reason_id: String,
	target_ids: Dictionary = {},
	refresh_scope := "full",
	presentation_token_ids: Array = []
) -> Dictionary:
	if _identity() == null or not _identity().current_actor_context(&"game_screen").is_valid():
		return {}
	return _build_offer(
		action_id,
		source_revision,
		available,
		disabled_reason_id,
		target_ids,
		refresh_scope,
		presentation_token_ids
	)


func human_surface_action_offer(
	action_id: String,
	target_ids: Dictionary = {},
	refresh_scope := "full",
	presentation_token_ids: Array = []
) -> Dictionary:
	var context := _identity().current_actor_context(&"game_screen") if _identity() != null else null
	if context == null or not context.is_valid():
		return {}
	var source_revision := _current_human_source_revision(context.authorized_actor_player_index)
	if source_revision <= 0:
		return {}
	var bound_targets := target_ids.duplicate(true)
	if action_id == INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE:
		var quote_key := _district_quote_key(
			context.authorized_actor_player_index,
			str(bound_targets.get("region_id", "")),
			str(bound_targets.get("card_id", ""))
		)
		var quote_id := str(_district_quote_bindings.get(quote_key, ""))
		var district_index := _district_index_for_region_id(str(bound_targets.get("region_id", "")))
		if quote_id.is_empty() or _district_supply() == null \
				or not _district_supply().quote_is_confirmable(
					context.authorized_actor_player_index,
					district_index,
					str(bound_targets.get("card_id", "")),
					quote_id
				):
			_district_quote_bindings.erase(quote_key)
			return {}
		bound_targets["quote_id"] = quote_id
	return _build_offer(
		action_id,
		source_revision,
		true,
		"none",
		bound_targets,
		refresh_scope,
		presentation_token_ids
	)


func human_actor_authorization(source_surface_id := "game-screen") -> Dictionary:
	var context := _identity().current_actor_context(&"game_screen") if _identity() != null else null
	if context == null or not context.is_valid():
		return {}
	return _authorization(
		"human",
		context.authorized_actor_player_index,
		context.authorization_revision,
		context.session_id,
		context.session_revision,
		"authorization.%d.%d" % [context.authorization_revision, context.session_revision],
		source_surface_id
	)


func ai_actor_authorization(
	capability: GameActionAiSubmissionCapability,
	actor_index: int,
	source_surface_id := "ai-runtime"
) -> Dictionary:
	if not _ai_capability_matches(capability) or not _actor_is_ai(actor_index):
		return {}
	var session := _session()
	if session == null:
		return {}
	var summary := session.session_summary()
	return _authorization(
		"ai",
		actor_index,
		maxi(1, session.session_start_revision()),
		str(summary.get("session_id", "")),
		session.session_start_revision(),
		"ai-capability.%d" % _ai_capability_nonce,
		source_surface_id
	)


func current_ai_source_revision(actor_index: int) -> int:
	var world := _world()
	var session := _session()
	if world == null or session == null or actor_index < 0 or actor_index >= world.players.size():
		return 0
	var player: Dictionary = world.players[actor_index] if world.players[actor_index] is Dictionary else {}
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	var queue := get_node_or_null(card_group_action_port_path)
	var queue_debug: Dictionary = queue.debug_snapshot() if queue != null and queue.has_method("debug_snapshot") else {}
	return maxi(1, session.session_start_revision() * 1_000_000 + slots.size() * 1_000 + int(queue_debug.get("submission_count", 0)))


func submit_intent(intent: Dictionary, capability: GameActionAiSubmissionCapability = null) -> Dictionary:
	_submission_count += 1
	var actor_kind := _receipt_actor_kind(intent)
	var validation := INTENT.validation_report(intent)
	if not bool(validation.get("valid", false)):
		return _complete(_receipt_for(intent, false, "intent-invalid", [], "none", false, false, -1, actor_kind))
	if actor_kind == "human":
		_human_submission_count += 1
	elif actor_kind == "ai":
		_ai_submission_count += 1
	var authorization_reason := _authorization_reason(intent, capability)
	if authorization_reason != "authorized":
		return _complete(_receipt_for(intent, false, authorization_reason, [], "none", false, false, -1, actor_kind))
	var session_key := _trusted_session_key()
	if session_key.is_empty():
		return _complete(_receipt_for(intent, false, "session-unavailable", [], "none", false, false, -1, actor_kind))
	_sync_journal(session_key)
	var request_id := str(intent.get("request_id", ""))
	var request_fingerprint := INTENT.request_fingerprint(intent)
	if _journal.has(request_id):
		var prior: Dictionary = _journal.get(request_id, {}) if _journal.get(request_id, {}) is Dictionary else {}
		if str(prior.get("request_fingerprint", "")) != request_fingerprint:
			_collision_count += 1
			return _complete(_receipt_for(intent, false, "request-id-collision", [], "none", false, true, -1, actor_kind))
		if bool(prior.get("delivery_recovery_pending", false)):
			_recovery_delivery_count += 1
			return _apply_authorized_intent(intent, actor_kind, true)
		_replay_count += 1
		var replay := RECEIPT.replay_copy(prior.get("receipt", {}) as Dictionary)
		if replay.is_empty():
			return _complete(_receipt_for(intent, false, "request-replay-invalid", [], "none", true, false, -1, actor_kind), false)
		return _complete(replay, false)
	if not _source_revision_current(intent, actor_kind):
		_stale_count += 1
		return _remember_and_complete(intent, _receipt_for(intent, false, "source-revision-stale", [], "none", false, false, -1, actor_kind))
	return _apply_authorized_intent(intent, actor_kind)


func _apply_authorized_intent(
	intent: Dictionary,
	actor_kind: String,
	delivery_recovery := false
) -> Dictionary:
	var outcome := _dispatch(intent, delivery_recovery)
	var accepted := bool(outcome.get("accepted", false))
	var refresh_scope := str(outcome.get("refresh_scope", "full" if accepted else "none"))
	var effect_refs: Array = []
	var effect_ref := str(outcome.get("effect_ref", ""))
	if accepted and not effect_ref.is_empty() and effect_ref != "none":
		effect_refs.append(effect_ref)
	var receipt := _receipt_for(
		intent,
		accepted,
		str(outcome.get("reason_id", "action-rejected")),
		effect_refs,
		refresh_scope,
		bool(outcome.get("idempotent_replay", false)),
		false,
		maxi(_operation_revision + 1, int(outcome.get("authoritative_revision", 0))),
		actor_kind
	)
	return _remember_and_complete(
		intent,
		receipt,
		bool(outcome.get("domain_refresh_owned", false)),
		bool(outcome.get("delivery_recovery_pending", false))
	)


func debug_snapshot() -> Dictionary:
	return {
		"controller_id": "table_player_action_application_flow_v1",
		"submission_count": _submission_count,
		"accepted_count": _accepted_count,
		"rejected_count": _rejected_count,
		"replay_count": _replay_count,
		"recovery_delivery_count": _recovery_delivery_count,
		"collision_count": _collision_count,
		"stale_count": _stale_count,
		"human_submission_count": _human_submission_count,
		"ai_submission_count": _ai_submission_count,
		"refresh_request_count": _refresh_request_count,
		"card_play_apply_count": _card_play_apply_count,
		"card_group_apply_count": _card_group_apply_count,
		"district_selection_apply_count": _district_selection_apply_count,
		"district_adapter_apply_count": _district_adapter_apply_count,
		"district_quote_binding_count": _district_quote_bindings.size(),
		"journal_size": _journal.size(),
		"journal_limit": JOURNAL_LIMIT,
		"ai_capability_bound": _ai_capability != null,
		"scene_owned": true,
		"owns_gameplay_rules": false,
		"owns_world_state": false,
		"owns_rng": false,
		"owns_save_state": false,
		"references_main": false,
	}


func _dispatch(intent: Dictionary, delivery_recovery := false) -> Dictionary:
	var action_id := str(intent.get("semantic_action_id", ""))
	var authorization := intent.get("actor_authorization", {}) as Dictionary
	var actor_index := int(authorization.get("actor_index", -1))
	match action_id:
		INTENT.ACTION_CARD_PLAY:
			return _dispatch_card_play(intent, actor_index, delivery_recovery)
		INTENT.ACTION_CARD_GROUP_READY:
			var resolution_id := _resolution_id(intent)
			var outcome := _card_group().submit_ready(actor_index, resolution_id) if _card_group() != null else {"accepted": false, "reason_id": "card-group-port-missing"}
			if bool(outcome.get("accepted", false)):
				_card_group_apply_count += 1
			outcome["refresh_scope"] = "full" if bool(outcome.get("accepted", false)) else "none"
			return outcome
		INTENT.ACTION_CARD_GROUP_REORDER:
			var resolution_id := _resolution_id(intent)
			var direction := int((intent.get("parameters", {}) as Dictionary).get("direction", 0))
			var outcome := _card_group().submit_reorder(actor_index, resolution_id, direction) if _card_group() != null else {"accepted": false, "reason_id": "card-group-port-missing"}
			if bool(outcome.get("accepted", false)):
				_card_group_apply_count += 1
			outcome["refresh_scope"] = "full" if bool(outcome.get("accepted", false)) else "none"
			return outcome
		INTENT.ACTION_DISTRICT_SELECT:
			return _dispatch_district_selection(intent, actor_index)
		INTENT.ACTION_DISTRICT_SUPPLY_OPEN, INTENT.ACTION_DISTRICT_SUPPLY_CLOSE, \
				INTENT.ACTION_DISTRICT_SUPPLY_QUOTE, INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE, \
				INTENT.ACTION_PLAYER_STRATEGY_OPEN_SUPPLY:
			return _dispatch_district_supply(intent, actor_index)
		INTENT.ACTION_SESSION_END_TURN:
			return {
				"accepted": true,
				"reason_id": "end-turn-refresh-accepted",
				"effect_ref": "session.end-turn.refresh",
				"authoritative_revision": _operation_revision + 1,
				"refresh_scope": "full",
			}
	return {"accepted": false, "reason_id": "action-unsupported", "refresh_scope": "none"}


func _dispatch_card_play(
	intent: Dictionary,
	actor_index: int,
	delivery_recovery := false
) -> Dictionary:
	var authorization: Dictionary = intent.get("actor_authorization", {}) \
		if intent.get("actor_authorization", {}) is Dictionary else {}
	var target_ids := intent.get("target_ids", {}) as Dictionary
	var slot_index := _slot_index(str(target_ids.get("hand_slot_id", "")))
	var request := {
		"player_index": actor_index,
		"slot_index": slot_index,
		"submission_source": str(intent.get("submission_kind", "")),
		"request_id": str(intent.get("request_id", "")),
		"intent_fingerprint": str(intent.get("intent_fingerprint", "")),
		"source_revision": int(intent.get("source_revision", -1)),
		"actor_kind_id": str(authorization.get("actor_kind_id", "")),
		"actor_id": str(authorization.get("actor_id", "")),
		"session_id": str(authorization.get("session_id", "")),
		"session_revision": int(authorization.get("session_revision", -1)),
		"hand_slot_id": str(target_ids.get("hand_slot_id", "")),
		"card_instance_id": str(target_ids.get("card_instance_id", "")),
	}
	var selected_resolution_id := _parse_stable_suffix(str(target_ids.get("selected_resolution_id", "")), "card.resolution.")
	if selected_resolution_id >= 0:
		request["selected_card_resolution_id"] = selected_resolution_id
	var region_id := str(target_ids.get("region_id", ""))
	if not region_id.is_empty():
		var district_index := _district_index_for_region_id(region_id)
		if district_index < 0:
			return {"accepted": false, "reason_id": "card-target-invalid", "refresh_scope": "none"}
		request["selected_district"] = district_index
	var monster_id := str(target_ids.get("monster_id", ""))
	if not monster_id.is_empty():
		var monster_slot := _parse_stable_suffix(monster_id, "monster.slot.")
		if monster_slot < 0:
			return {"accepted": false, "reason_id": "card-target-invalid", "refresh_scope": "none"}
		request["target_slot"] = monster_slot
	var player_id := str(target_ids.get("player_id", ""))
	if not player_id.is_empty():
		var player_index := _parse_stable_suffix(player_id, "player.")
		if player_index < 0:
			return {"accepted": false, "reason_id": "card-target-invalid", "refresh_scope": "none"}
		request["target_player"] = player_index
	var card_play := _card_play()
	if card_play == null:
		return {"accepted": false, "reason_id": "card-play-port-missing", "refresh_scope": "none"}
	var result: Dictionary
	if delivery_recovery:
		result = card_play.retry_hand_play(request)
	else:
		var card := _card_at(actor_index, slot_index)
		if card.is_empty() or not CARD_BINDING.matches_private_instance_ref(
			card,
			slot_index,
			str(target_ids.get("card_instance_id", ""))
		):
			return {"accepted": false, "reason_id": "card-binding-stale", "refresh_scope": "none"}
		result = card_play.request_hand_play(request)
	var accepted := bool(result.get("accepted", result.get("queued", false)))
	var v06_receipt: Dictionary = result.get("v06_receipt", {}) \
		if result.get("v06_receipt", {}) is Dictionary else {}
	var queued := accepted and bool(v06_receipt.get("queued", false))
	if accepted and not v06_receipt.is_empty():
		if queued:
			accepted = not CARD_BINDING.resolution_ref(
				int(v06_receipt.get("resolution_id", -1))
			).is_empty()
		else:
			var finalization: Dictionary = v06_receipt.get("effect_finalization", {}) \
				if v06_receipt.get("effect_finalization", {}) is Dictionary else {}
			accepted = bool(v06_receipt.get("committed", false)) \
				and bool(finalization.get("finalized", v06_receipt.get("finalized", false)))
	if accepted:
		_card_play_apply_count += 1
	return {
		"accepted": accepted,
		"reason_id": str(result.get("reason", "card-play-accepted" if accepted else "card-play-rejected")).replace("_", "-"),
		"effect_ref": CARD_BINDING.resolution_ref(
			int(v06_receipt.get("resolution_id", -1))
		) if queued and accepted else (
			"card.play.%s" % str(target_ids.get("card_instance_id", "")) if accepted else "none"
		),
		"authoritative_revision": _operation_revision + 1,
		"refresh_scope": "full" if accepted else "none",
		"idempotent_replay": bool(v06_receipt.get("idempotent_replay", false)),
		"delivery_recovery_pending": not accepted \
			and bool(v06_receipt.get("requires_recovery", false)),
	}


func _dispatch_district_selection(intent: Dictionary, actor_index: int) -> Dictionary:
	var port := _table_selection()
	var region_id := str((intent.get("target_ids", {}) as Dictionary).get("region_id", ""))
	var district_index := _district_index_for_region_id(region_id)
	if port == null or district_index < 0:
		return {"accepted": false, "reason_id": "district-selection-port-missing" if port == null else "district-target-invalid", "refresh_scope": "none"}
	var authorization := intent.get("actor_authorization", {}) as Dictionary
	var before_revision := int(_selection_state().snapshot().get("revision", -1)) if _selection_state() != null else -1
	if before_revision < 0:
		return {"accepted": false, "reason_id": "district-selection-state-missing", "refresh_scope": "none"}
	var selection_intent := TableSelectionIntent.new()
	selection_intent.request_id = "game-action-adapter:%s" % str(intent.get("request_id", ""))
	selection_intent.selection_kind = TableSelectionIntent.KIND_SELECT_DISTRICT
	selection_intent.viewer_index = actor_index
	selection_intent.authorization_revision = int(authorization.get("actor_revision", 0))
	selection_intent.session_id = str(authorization.get("session_id", ""))
	selection_intent.session_revision = int(authorization.get("session_revision", 0))
	selection_intent.expected_selection_revision = before_revision
	selection_intent.target_district_index = district_index
	selection_intent.source_surface = &"planet_map"
	selection_intent.request_revision = _operation_revision + 1
	var result := port.submit_intent(selection_intent)
	var after_revision := result.selection_revision_after if result != null else before_revision
	var committed := result != null and result.accepted and result.applied \
		and result.changed and after_revision > before_revision
	if committed:
		_district_selection_apply_count += 1
	return {
		"accepted": committed,
		"reason_id": str(result.reason_code).replace("_", "-") if result != null else "district-selection-rejected",
		"effect_ref": "district.select.%s" % region_id if committed else "none",
		"authoritative_revision": _operation_revision + 1,
		"refresh_scope": "full" if committed else "none",
		"domain_refresh_owned": committed and result.presentation_refresh_requested,
	}


func _dispatch_district_supply(intent: Dictionary, actor_index: int) -> Dictionary:
	var port := _district_supply()
	var identity := _identity()
	if port == null or identity == null:
		return {"accepted": false, "reason_id": "district-supply-port-missing", "refresh_scope": "none"}
	var action_id := str(intent.get("semantic_action_id", ""))
	var target_ids := intent.get("target_ids", {}) as Dictionary
	var region_id := str(target_ids.get("region_id", ""))
	var district_index := _district_index_for_region_id(region_id) if not region_id.is_empty() else -1
	if action_id != INTENT.ACTION_DISTRICT_SUPPLY_CLOSE and district_index < 0:
		return {"accepted": false, "reason_id": "district-target-invalid", "refresh_scope": "none"}
	var authorization := intent.get("actor_authorization", {}) as Dictionary
	var district_intent := DistrictSupplyActionIntent.new()
	district_intent.request_id = "game-action-adapter:%s" % str(intent.get("request_id", ""))
	district_intent.action_kind = {
		INTENT.ACTION_DISTRICT_SUPPLY_CLOSE: DistrictSupplyActionIntent.KIND_CLOSE,
		INTENT.ACTION_DISTRICT_SUPPLY_QUOTE: DistrictSupplyActionIntent.KIND_QUOTE,
		INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE: DistrictSupplyActionIntent.KIND_PURCHASE,
	}.get(action_id, DistrictSupplyActionIntent.KIND_OPEN)
	district_intent.actor_player_index = actor_index
	district_intent.authorization_revision = int(authorization.get("actor_revision", 0))
	district_intent.session_id = str(authorization.get("session_id", ""))
	district_intent.session_revision = int(authorization.get("session_revision", 0))
	district_intent.district_index = district_index
	district_intent.card_id = str(target_ids.get("card_id", ""))
	var quote_key := _district_quote_key(actor_index, region_id, district_intent.card_id)
	if district_intent.action_kind == DistrictSupplyActionIntent.KIND_PURCHASE:
		var offered_quote_id := str(target_ids.get("quote_id", ""))
		if offered_quote_id.is_empty() \
				or offered_quote_id != str(_district_quote_bindings.get(quote_key, "")):
			return {
				"accepted": false,
				"reason_id": "district-quote-binding-stale",
				"refresh_scope": "none",
			}
		district_intent.locked_quote_id = offered_quote_id
	elif district_intent.action_kind == DistrictSupplyActionIntent.KIND_QUOTE:
		# Selecting another listing invalidates the prior domain quote before the
		# new typed receipt can establish a replacement binding.
		_clear_district_quotes_for_actor(actor_index)
	district_intent.source_surface = &"game_screen"
	district_intent.request_revision = _operation_revision + 1
	var result := port.submit_intent(district_intent)
	var committed := result != null and result.accepted and result.applied
	var pending_discard := committed and result.requires_discard \
		and not result.quote_id.is_empty()
	var accepted := committed
	if accepted and district_intent.action_kind == DistrictSupplyActionIntent.KIND_QUOTE \
			and not result.quote_id.is_empty():
		_district_quote_bindings[quote_key] = result.quote_id
		_request_post_bind_district_quote_refresh()
	elif committed and district_intent.action_kind in [
		DistrictSupplyActionIntent.KIND_OPEN,
		DistrictSupplyActionIntent.KIND_CLOSE,
	]:
		_clear_district_quotes_for_actor(actor_index)
	elif district_intent.action_kind == DistrictSupplyActionIntent.KIND_PURCHASE \
			and (committed or result != null and result.reason_code in [
				"locked_quote_changed",
				"locked_quote_required",
				"quote_unavailable",
				"quote_unauthorized",
				"quote_expired",
				"quote_missing",
				"quote_binding_mismatch",
				"quote_fingerprint_mismatch",
			]):
		_district_quote_bindings.erase(quote_key)
	if accepted:
		_district_adapter_apply_count += 1
	var effect_ref := "none"
	if accepted:
		match district_intent.action_kind:
			DistrictSupplyActionIntent.KIND_CLOSE:
				effect_ref = "district.supply.close"
			DistrictSupplyActionIntent.KIND_QUOTE:
				effect_ref = "district.supply.quote.%s" % SemanticWireV1.fingerprint({"quote_id": result.quote_id}).substr(0, 24)
			DistrictSupplyActionIntent.KIND_PURCHASE:
				effect_ref = (
					"district.supply.purchase.pending-discard.%s"
					% SemanticWireV1.fingerprint({"quote_id": result.quote_id}).substr(0, 24)
				) if pending_discard else "district.supply.purchase.%s" % district_intent.card_id
			_:
				effect_ref = "district.supply.open.%s" % region_id
	return {
		"accepted": accepted,
		"reason_id": str(result.reason_code).replace("_", "-") if result != null else "district-supply-rejected",
		"effect_ref": effect_ref,
		"authoritative_revision": _operation_revision + 1,
		"refresh_scope": "full" if accepted else "none",
		"domain_refresh_owned": result != null and result.presentation_refresh_requested,
	}


func _source_revision_current(intent: Dictionary, actor_kind: String) -> bool:
	var authorization := intent.get("actor_authorization", {}) as Dictionary
	var actor_index := int(authorization.get("actor_index", -1))
	var action_id := str(intent.get("semantic_action_id", ""))
	if actor_kind == "human" and action_id in [
		INTENT.ACTION_DISTRICT_SUPPLY_QUOTE,
		INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE,
	]:
		var source := get_node_or_null(action_offer_source_path)
		if source != null and source.has_method("district_supply_offer_revision_is_current"):
			return bool(source.call(
				"district_supply_offer_revision_is_current",
				actor_index,
				int(intent.get("source_revision", -1))
			))
	var expected := current_ai_source_revision(actor_index) if actor_kind == "ai" else _current_human_source_revision(actor_index)
	return expected > 0 and int(intent.get("source_revision", -1)) == expected


func _authorization_reason(intent: Dictionary, capability: GameActionAiSubmissionCapability) -> String:
	var authorization := intent.get("actor_authorization", {}) as Dictionary
	var actor_kind := str(authorization.get("actor_kind_id", ""))
	var actor_index := int(authorization.get("actor_index", -1))
	if actor_kind == "human":
		var identity := _identity()
		if identity == null:
			return "actor-authorization-missing"
		var context := identity.authorize_actor_index(actor_index, &"game_screen")
		if not context.is_valid() \
				or context.authorization_revision != int(authorization.get("actor_revision", 0)) \
				or context.session_id != str(authorization.get("session_id", "")) \
				or context.session_revision != int(authorization.get("session_revision", 0)) \
				or str(authorization.get("actor_id", "")) != "player.%d" % actor_index \
				or str(authorization.get("authorization_proof_ref", "")) != "authorization.%d.%d" % [context.authorization_revision, context.session_revision]:
			return "actor-authorization-rejected"
		return "authorized"
	if actor_kind == "ai":
		if not _ai_capability_matches(capability) or not _actor_is_ai(actor_index):
			return "ai-authorization-rejected"
		if str(authorization.get("actor_id", "")) != "player.%d" % actor_index \
				or str(authorization.get("authorization_proof_ref", "")) != "ai-capability.%d" % _ai_capability_nonce:
			return "ai-authorization-rejected"
		var session := _session()
		var summary := session.session_summary() if session != null else {}
		if session == null \
				or str(authorization.get("session_id", "")) != str(summary.get("session_id", "")) \
				or int(authorization.get("session_revision", 0)) != session.session_start_revision():
			return "ai-authorization-rejected"
		return "authorized"
	return "actor-kind-unsupported"


func _remember_and_complete(
	intent: Dictionary,
	receipt: Dictionary,
	domain_refresh_owned := false,
	delivery_recovery_pending := false
) -> Dictionary:
	_remember(
		str(intent.get("request_id", "")),
		INTENT.request_fingerprint(intent),
		receipt,
		delivery_recovery_pending
	)
	return _complete(receipt, not domain_refresh_owned)


func _complete(receipt: Dictionary, request_refresh := true) -> Dictionary:
	_operation_revision = maxi(_operation_revision + 1, int(receipt.get("authoritative_revision", 0)))
	if bool(receipt.get("accepted", false)):
		_accepted_count += 1
	else:
		_rejected_count += 1
	if request_refresh and bool(receipt.get("accepted", false)):
		var scope := StringName(str(receipt.get("refresh_scope", "none")))
		if scope != &"none" and _refresh() != null:
			_refresh().request_immediate(scope, &"game_action_receipt")
			_refresh_request_count += 1
	if bool(RECEIPT.validation_report(receipt).get("valid", false)) \
			and str(receipt.get("viewer_private_projection_ref", "none")) != "none":
		receipt_ready.emit(RECEIPT.detached_copy(receipt))
	return RECEIPT.detached_copy(receipt)


func _receipt_for(
	intent: Dictionary,
	accepted: bool,
	reason_id: String,
	committed_effect_refs: Array,
	refresh_scope: String,
	idempotent_replay: bool,
	request_id_collision: bool,
	authoritative_revision := -1,
	actor_kind := "system"
) -> Dictionary:
	var action_id := str(intent.get("semantic_action_id", INTENT.ACTION_SESSION_END_TURN))
	if INTENT.action_contract(action_id).is_empty():
		action_id = INTENT.ACTION_SESSION_END_TURN
	var request_id := str(intent.get("request_id", "invalid.request"))
	if not SemanticWireV1.is_stable_id(request_id):
		request_id = "invalid.request"
	var request_fingerprint := str(intent.get("intent_fingerprint", ""))
	if not SemanticWireV1.is_fingerprint(request_fingerprint):
		request_fingerprint = SemanticWireV1.fingerprint({"request_id": request_id, "action_id": action_id})
	var normalized_reason := reason_id.strip_edges().to_lower().replace("_", "-")
	if not SemanticWireV1.is_stable_id(normalized_reason):
		normalized_reason = "action-rejected"
	return RECEIPT.build({
		"schema_version": RECEIPT.SCHEMA_VERSION,
		"semantic_action_id": action_id,
		"accepted": accepted,
		"reason_id": normalized_reason,
		"request_id": request_id,
		"request_fingerprint": request_fingerprint,
		"authoritative_revision": maxi(0, _operation_revision + 1 if authoritative_revision < 0 else authoritative_revision),
		"committed_effect_refs": committed_effect_refs.duplicate(),
		"public_projection_ref": "none",
		"viewer_private_projection_ref": "viewer.feedback.%s" % request_id if actor_kind == "human" else "none",
		"idempotent_replay": idempotent_replay,
		"request_id_collision": request_id_collision,
		"refresh_scope": refresh_scope,
	})


func _receipt_actor_kind(intent: Dictionary) -> String:
	var authorization: Dictionary = intent.get("actor_authorization", {}) \
		if intent.get("actor_authorization", {}) is Dictionary else {}
	var actor_kind := str(authorization.get("actor_kind_id", ""))
	return actor_kind if actor_kind in ["human", "ai"] else "system"


func _trusted_session_key() -> String:
	var session := _session()
	if session == null:
		return ""
	var summary := session.session_summary()
	var session_id := str(summary.get("session_id", ""))
	var session_revision := session.session_start_revision()
	return "%s:%d" % [session_id, session_revision] \
		if not session_id.is_empty() and session_revision > 0 else ""


func _card_play_offer(
	actor_index: int,
	slot_index: int,
	source_revision: int,
	available: bool,
	disabled_reason_id: String,
	region_id: String,
	selected_resolution_id: int
) -> Dictionary:
	var card := _card_at(actor_index, slot_index)
	if card.is_empty():
		available = false
		disabled_reason_id = "card-slot-invalid"
	var targets := {
		"card_instance_id": CARD_BINDING.private_instance_ref(card, slot_index),
		"hand_slot_id": CARD_BINDING.hand_slot_ref(slot_index),
	}
	if not region_id.is_empty():
		targets["region_id"] = region_id
	if selected_resolution_id >= 0:
		targets["selected_resolution_id"] = CARD_BINDING.resolution_ref(selected_resolution_id)
	return _build_offer(
		INTENT.ACTION_CARD_PLAY,
		source_revision,
		available,
		disabled_reason_id,
		targets,
		"full",
		["action.card.play", "feedback.card.play"]
	)


func _build_offer(
	action_id: String,
	source_revision: int,
	available: bool,
	disabled_reason_id: String,
	target_ids: Dictionary,
	refresh_scope: String,
	presentation_token_ids: Array
) -> Dictionary:
	var bindings: Array = []
	for role_variant in target_ids.keys():
		var role := str(role_variant)
		var target_id := str(target_ids.get(role_variant, ""))
		if SemanticWireV1.is_stable_id(role) and SemanticWireV1.is_stable_id(target_id):
			bindings.append({"target_role_id": role, "target_id": target_id})
	bindings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("target_role_id", "")) < str(b.get("target_role_id", ""))
	)
	var reason := "none" if available else disabled_reason_id.strip_edges().to_lower().replace("_", "-")
	if not SemanticWireV1.is_stable_id(reason):
		reason = "action-disabled"
	return OFFER.build({
		"schema_version": OFFER.SCHEMA_VERSION,
		"semantic_action_id": action_id,
		"action_family_id": INTENT.action_family_id(action_id),
		"source_revision": maxi(0, source_revision),
		"actor_scope": "authorized_actor",
		"public_or_private_target_spec": {
			"visibility_scope_id": "viewer_private",
			"target_kind_id": "stable-ids",
			"target_bindings": bindings,
			"requires_target": not bindings.is_empty(),
		},
		"legality_state": "available" if available else "disabled",
		"disabled_reason_id": reason,
		"cost_spec": {"cost_kind_id": "domain-owned", "amount_units": 0, "resource_id": "none"},
		"requirement_spec": {"requirement_ids": ["domain-legality"], "source_revision_required": true},
		"consequence_spec": {"committed_effect_refs": [], "refresh_scope": refresh_scope},
		"presentation_token_ids": presentation_token_ids.duplicate(),
	})


func _authorization(
	actor_kind: String,
	actor_index: int,
	actor_revision: int,
	session_id: String,
	session_revision: int,
	proof_ref: String,
	source_surface_id: String
) -> Dictionary:
	return {
		"schema_version": INTENT.SCHEMA_VERSION,
		"actor_kind_id": actor_kind,
		"actor_id": "player.%d" % actor_index,
		"actor_index": actor_index,
		"actor_revision": actor_revision,
		"session_id": session_id,
		"session_revision": session_revision,
		"authorization_proof_ref": proof_ref,
		"source_surface_id": source_surface_id,
	}


func _current_human_source_revision(actor_index: int) -> int:
	var source := get_node_or_null(action_offer_source_path)
	if source == null or not source.has_method("current_action_offer_revision"):
		return 0
	return int(source.call("current_action_offer_revision", actor_index))


func _card_at(actor_index: int, slot_index: int) -> Dictionary:
	var world := _world()
	if world == null or actor_index < 0 or actor_index >= world.players.size() or slot_index < 0:
		return {}
	var player: Dictionary = world.players[actor_index] if world.players[actor_index] is Dictionary else {}
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	return (slots[slot_index] as Dictionary).duplicate(true) if slot_index < slots.size() and slots[slot_index] is Dictionary else {}


func _actor_is_ai(actor_index: int) -> bool:
	var world := _world()
	if world == null or actor_index < 0 or actor_index >= world.players.size():
		return false
	var player: Dictionary = world.players[actor_index] if world.players[actor_index] is Dictionary else {}
	return bool(player.get("is_ai", false)) and not bool(player.get("eliminated", false))


func _district_index_for_region_id(region_id: String) -> int:
	var world := _world()
	if world == null or region_id.is_empty():
		return -1
	for district_index in range(world.districts.size()):
		var district: Dictionary = world.districts[district_index] if world.districts[district_index] is Dictionary else {}
		if str(district.get("region_id", "")) == region_id:
			return district_index
	return -1


func _slot_index(hand_slot_id: String) -> int:
	return _parse_stable_suffix(hand_slot_id, "hand.slot.")


func _resolution_id(intent: Dictionary) -> int:
	return _parse_stable_suffix(
		str((intent.get("target_ids", {}) as Dictionary).get("resolution_id", "")),
		"card.resolution."
	)


func _parse_stable_suffix(value: String, prefix: String) -> int:
	if not value.begins_with(prefix):
		return -1
	var suffix := value.substr(prefix.length())
	return int(suffix) if suffix.is_valid_int() and int(suffix) >= 0 else -1


func _ai_capability_matches(capability: GameActionAiSubmissionCapability) -> bool:
	return capability != null and capability == _ai_capability \
		and capability.matches_owner_nonce(_ai_capability_nonce)


func _sync_journal(session_key: String) -> void:
	if session_key == _journal_session_key:
		return
	_journal.clear()
	_journal_order.clear()
	_district_quote_bindings.clear()
	_journal_session_key = session_key


func _remember(
	request_id: String,
	request_fingerprint: String,
	receipt: Dictionary,
	delivery_recovery_pending := false
) -> void:
	var already_present := _journal.has(request_id)
	_journal[request_id] = {
		"request_fingerprint": request_fingerprint,
		"receipt": RECEIPT.detached_copy(receipt),
		"delivery_recovery_pending": delivery_recovery_pending,
	}
	if not already_present:
		_journal_order.append(request_id)
	while _journal_order.size() > JOURNAL_LIMIT:
		_journal.erase(_journal_order.pop_front())


func _identity() -> PlayerIdentityAuthorizationBoundary:
	return get_node_or_null(identity_boundary_path) as PlayerIdentityAuthorizationBoundary


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_path) as GameSessionRuntimeController


func _card_play() -> CardPlaySubmissionRuntimeController:
	return get_node_or_null(card_play_submission_path) as CardPlaySubmissionRuntimeController


func _card_group() -> CardGroupActionPort:
	return get_node_or_null(card_group_action_port_path) as CardGroupActionPort


func _table_selection() -> TableSelectionIntentPort:
	return get_node_or_null(table_selection_intent_port_path) as TableSelectionIntentPort


func _selection_state() -> TableSelectionState:
	return get_node_or_null(table_selection_state_path) as TableSelectionState


func _district_supply() -> DistrictSupplyActionPort:
	return get_node_or_null(district_supply_action_port_path) as DistrictSupplyActionPort


static func _district_quote_key(actor_index: int, region_id: String, card_id: String) -> String:
	return "%d|%s|%s" % [actor_index, region_id.strip_edges(), card_id.strip_edges()]


func _clear_district_quotes_for_actor(actor_index: int) -> void:
	var prefix := "%d|" % actor_index
	for key_variant in _district_quote_bindings.keys():
		if str(key_variant).begins_with(prefix):
			_district_quote_bindings.erase(key_variant)


func _request_post_bind_district_quote_refresh() -> void:
	# The district owner can synchronously request its full refresh before
	# submit_intent() returns. At that point this adapter has not yet recorded the
	# accepted quote ID, so that projection cannot expose the bound purchase
	# offer. Refresh once after the facade binding commits instead of relying on
	# the periodic presentation cadence to repair the surface later.
	var refresh := _refresh()
	if refresh == null:
		return
	refresh.request_immediate(&"full", &"district_supply_quote_bound")
	_refresh_request_count += 1


func _refresh() -> TablePresentationRefreshPort:
	return get_node_or_null(presentation_refresh_port_path) as TablePresentationRefreshPort

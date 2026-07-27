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
var _collision_count := 0
var _stale_count := 0
var _human_submission_count := 0
var _ai_submission_count := 0
var _refresh_request_count := 0
var _card_play_apply_count := 0
var _card_group_apply_count := 0
var _district_adapter_apply_count := 0


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
	var validation := INTENT.validation_report(intent)
	if not bool(validation.get("valid", false)):
		return _complete(_receipt_for(intent, false, "intent-invalid", [], "none", false, false))
	var authorization := intent.get("actor_authorization", {}) as Dictionary
	var actor_kind := str(authorization.get("actor_kind_id", ""))
	if actor_kind == "human":
		_human_submission_count += 1
	elif actor_kind == "ai":
		_ai_submission_count += 1
	var session_key := "%s:%d" % [
		str(authorization.get("session_id", "")),
		int(authorization.get("session_revision", 0)),
	]
	_sync_journal(session_key)
	var request_id := str(intent.get("request_id", ""))
	var request_fingerprint := INTENT.request_fingerprint(intent)
	if _journal.has(request_id):
		var prior: Dictionary = _journal.get(request_id, {}) if _journal.get(request_id, {}) is Dictionary else {}
		if str(prior.get("request_fingerprint", "")) != request_fingerprint:
			_collision_count += 1
			return _complete(_receipt_for(intent, false, "request-id-collision", [], "none", false, true))
		_replay_count += 1
		var replay := RECEIPT.replay_copy(prior.get("receipt", {}) as Dictionary)
		if replay.is_empty():
			return _complete(_receipt_for(intent, false, "request-replay-invalid", [], "none", true, false), false)
		return _complete(replay, false)
	var authorization_reason := _authorization_reason(intent, capability)
	if authorization_reason != "authorized":
		return _remember_and_complete(intent, _receipt_for(intent, false, authorization_reason, [], "none", false, false))
	if not _source_revision_current(intent, actor_kind):
		_stale_count += 1
		return _remember_and_complete(intent, _receipt_for(intent, false, "source-revision-stale", [], "none", false, false))
	var outcome := _dispatch(intent)
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
		false,
		false,
		maxi(_operation_revision + 1, int(outcome.get("authoritative_revision", 0))),
		actor_kind
	)
	return _remember_and_complete(intent, receipt, bool(outcome.get("domain_refresh_owned", false)))


func debug_snapshot() -> Dictionary:
	return {
		"controller_id": "table_player_action_application_flow_v1",
		"submission_count": _submission_count,
		"accepted_count": _accepted_count,
		"rejected_count": _rejected_count,
		"replay_count": _replay_count,
		"collision_count": _collision_count,
		"stale_count": _stale_count,
		"human_submission_count": _human_submission_count,
		"ai_submission_count": _ai_submission_count,
		"refresh_request_count": _refresh_request_count,
		"card_play_apply_count": _card_play_apply_count,
		"card_group_apply_count": _card_group_apply_count,
		"district_adapter_apply_count": _district_adapter_apply_count,
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


func _dispatch(intent: Dictionary) -> Dictionary:
	var action_id := str(intent.get("semantic_action_id", ""))
	var authorization := intent.get("actor_authorization", {}) as Dictionary
	var actor_index := int(authorization.get("actor_index", -1))
	match action_id:
		INTENT.ACTION_CARD_PLAY:
			return _dispatch_card_play(intent, actor_index)
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
		INTENT.ACTION_DISTRICT_SUPPLY_OPEN, INTENT.ACTION_PLAYER_STRATEGY_OPEN_SUPPLY:
			return _dispatch_district_supply_open(intent, actor_index)
		INTENT.ACTION_SESSION_END_TURN:
			return {
				"accepted": true,
				"reason_id": "end-turn-refresh-accepted",
				"effect_ref": "none",
				"authoritative_revision": _operation_revision + 1,
				"refresh_scope": "full",
			}
	return {"accepted": false, "reason_id": "action-unsupported", "refresh_scope": "none"}


func _dispatch_card_play(intent: Dictionary, actor_index: int) -> Dictionary:
	var target_ids := intent.get("target_ids", {}) as Dictionary
	var slot_index := _slot_index(str(target_ids.get("hand_slot_id", "")))
	var card := _card_at(actor_index, slot_index)
	if card.is_empty() or not CARD_BINDING.matches_private_instance_ref(
		card,
		slot_index,
		str(target_ids.get("card_instance_id", ""))
	):
		return {"accepted": false, "reason_id": "card-binding-stale", "refresh_scope": "none"}
	var request := {
		"player_index": actor_index,
		"slot_index": slot_index,
		"submission_source": str(intent.get("submission_kind", "")),
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
	var result := _card_play().request_hand_play(request) if _card_play() != null else {}
	var accepted := bool(result.get("accepted", result.get("queued", false)))
	if accepted:
		_card_play_apply_count += 1
	return {
		"accepted": accepted,
		"reason_id": str(result.get("reason", "card-play-accepted" if accepted else "card-play-rejected")).replace("_", "-"),
		"effect_ref": "card.play.%s" % str(target_ids.get("card_instance_id", "")) if accepted else "none",
		"authoritative_revision": _operation_revision + 1,
		"refresh_scope": "full" if accepted else "none",
	}


func _dispatch_district_supply_open(intent: Dictionary, actor_index: int) -> Dictionary:
	var port := _district_supply()
	var identity := _identity()
	if port == null or identity == null:
		return {"accepted": false, "reason_id": "district-supply-port-missing", "refresh_scope": "none"}
	var region_id := str((intent.get("target_ids", {}) as Dictionary).get("region_id", ""))
	var district_index := _district_index_for_region_id(region_id)
	if district_index < 0:
		return {"accepted": false, "reason_id": "district-target-invalid", "refresh_scope": "none"}
	var authorization := intent.get("actor_authorization", {}) as Dictionary
	var district_intent := DistrictSupplyActionIntent.new()
	district_intent.request_id = "game-action-adapter:%s" % str(intent.get("request_id", ""))
	district_intent.action_kind = DistrictSupplyActionIntent.KIND_OPEN
	district_intent.actor_player_index = actor_index
	district_intent.authorization_revision = int(authorization.get("actor_revision", 0))
	district_intent.session_id = str(authorization.get("session_id", ""))
	district_intent.session_revision = int(authorization.get("session_revision", 0))
	district_intent.district_index = district_index
	district_intent.source_surface = &"game_screen"
	district_intent.request_revision = _operation_revision + 1
	var result := port.submit_intent(district_intent)
	var accepted := result != null and result.accepted
	if accepted:
		_district_adapter_apply_count += 1
	return {
		"accepted": accepted,
		"reason_id": str(result.reason_code).replace("_", "-") if result != null else "district-supply-rejected",
		"effect_ref": "district.supply.open.%s" % region_id if accepted else "none",
		"authoritative_revision": _operation_revision + 1,
		"refresh_scope": "full" if accepted else "none",
		"domain_refresh_owned": accepted,
	}


func _source_revision_current(intent: Dictionary, actor_kind: String) -> bool:
	var authorization := intent.get("actor_authorization", {}) as Dictionary
	var actor_index := int(authorization.get("actor_index", -1))
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


func _remember_and_complete(intent: Dictionary, receipt: Dictionary, domain_refresh_owned := false) -> Dictionary:
	_remember(str(intent.get("request_id", "")), INTENT.request_fingerprint(intent), receipt)
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
	if bool(RECEIPT.validation_report(receipt).get("valid", false)):
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
	actor_kind := "human"
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
		"viewer_private_projection_ref": "none" if actor_kind == "ai" else "viewer.feedback.%s" % request_id,
		"idempotent_replay": idempotent_replay,
		"request_id_collision": request_id_collision,
		"refresh_scope": refresh_scope,
	})


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
	_journal_session_key = session_key


func _remember(request_id: String, request_fingerprint: String, receipt: Dictionary) -> void:
	_journal[request_id] = {
		"request_fingerprint": request_fingerprint,
		"receipt": RECEIPT.detached_copy(receipt),
	}
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


func _district_supply() -> DistrictSupplyActionPort:
	return get_node_or_null(district_supply_action_port_path) as DistrictSupplyActionPort


func _refresh() -> TablePresentationRefreshPort:
	return get_node_or_null(presentation_refresh_port_path) as TablePresentationRefreshPort

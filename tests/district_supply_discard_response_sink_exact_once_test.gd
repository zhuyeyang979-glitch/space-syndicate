extends SceneTree

const IDENTITY_SCENE := preload("res://scenes/runtime/PlayerIdentityAuthorizationBoundary.tscn")
const RESPONSE_SCENE := preload("res://scenes/runtime/ForcedDecisionResponsePort.tscn")
const SINK_SCENE := preload("res://scenes/runtime/DistrictSupplyDiscardResponseSink.tscn")
const SINK_SCRIPT := preload("res://scripts/runtime/district_supply_discard_response_sink.gd")
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"


class FakeActionPort:
	extends DistrictSupplyActionPort

	var expected_actor_index := 0
	var expected_authorization_revision := 1
	var expected_session_id := "session-discard-sink-1"
	var expected_session_revision := 1
	var pending_discard := false
	var cash_units := 100
	var inventory_count := 0
	var submit_count := 0
	var accepted_count := 0
	var rejected_count := 0
	var confirm_count := 0
	var cancel_count := 0
	var purchase_mutation_count := 0
	var cash_mutation_count := 0
	var inventory_mutation_count := 0
	var last_intent: DistrictSupplyActionIntent


	func seed_pending_discard() -> void:
		pending_discard = true


	func submit_intent(intent: DistrictSupplyActionIntent) -> DistrictSupplyActionReceipt:
		submit_count += 1
		if intent == null or not bool(intent.validation_report().get("valid", false)):
			return _complete_fake(_receipt(intent, false, "intent_invalid"))
		last_intent = intent
		var fingerprint := intent.fingerprint()
		if _journal.has(intent.request_id):
			if str(_journal.get(intent.request_id, "")) != fingerprint:
				var collision := _receipt(intent, false, "request_id_collision")
				collision.request_id_collision = true
				return _complete_fake(collision)
			var replay := _receipt(intent, false, "request_replay")
			replay.idempotent_replay = true
			return _complete_fake(replay)
		if intent.actor_player_index != expected_actor_index \
				or intent.authorization_revision != expected_authorization_revision \
				or intent.session_id != expected_session_id \
				or intent.session_revision != expected_session_revision:
			return _complete_fake(_receipt(intent, false, "actor_authorization_rejected"))
		_journal[intent.request_id] = fingerprint
		if not pending_discard:
			return _complete_fake(_receipt(intent, false, "pending_discard_missing"))
		pending_discard = false
		if intent.action_kind == DistrictSupplyActionIntent.KIND_DISCARD_CANCEL:
			cancel_count += 1
			var cancelled := _receipt(intent, true, "discard_cancelled")
			cancelled.applied = true
			return _complete_fake(cancelled)
		if intent.action_kind != DistrictSupplyActionIntent.KIND_DISCARD_CONFIRM:
			return _complete_fake(_receipt(intent, false, "action_kind_invalid"))
		confirm_count += 1
		purchase_mutation_count += 1
		cash_mutation_count += 1
		inventory_mutation_count += 1
		cash_units -= 7
		inventory_count += 1
		var confirmed := _receipt(intent, true, "purchase_committed")
		confirmed.applied = true
		confirmed.card_id = "viewer-private-purchased-card"
		confirmed.price = 7
		return _complete_fake(confirmed)


	func _receipt(
		intent: DistrictSupplyActionIntent,
		accepted: bool,
		reason_code: String
	) -> DistrictSupplyActionReceipt:
		var receipt := DistrictSupplyActionReceipt.new()
		if intent != null:
			receipt.request_id = intent.request_id
			receipt.action_kind = intent.action_kind
			receipt.actor_player_index = intent.actor_player_index
		receipt.accepted = accepted
		receipt.reason_code = reason_code
		return receipt


	func _complete_fake(receipt: DistrictSupplyActionReceipt) -> DistrictSupplyActionReceipt:
		if receipt.accepted:
			accepted_count += 1
		else:
			rejected_count += 1
		return receipt


var _checks := 0
var _failures: Array[String] = []
var _host: Node
var _scheduler: ForcedDecisionRuntimeScheduler
var _port: ForcedDecisionResponsePort
var _action_port: FakeActionPort
var _sink: SINK_SCRIPT
var _sink_receipts: Array[DistrictSupplyActionReceipt] = []


func _init() -> void:
	_build_fixture()
	_test_production_composition_contract()
	_test_confirm_and_replay_exact_once()
	_test_request_id_collision()
	_test_cancel_without_purchase_mutation()
	_test_stale_and_unauthorized_fail_closed()
	_test_receipt_privacy_and_pure_data()
	_finish()


func _build_fixture() -> void:
	_host = Node.new()
	root.add_child(_host)
	var world := WorldSessionState.new()
	world.name = "World"
	world.players = [
		{"id": "player-0", "is_ai": false, "seat_type": "human", "eliminated": false},
		{"id": "player-1", "is_ai": true, "seat_type": "ai", "eliminated": false},
	]
	_host.add_child(world)
	var authorization := LocalViewerAuthorization.new()
	authorization.name = "Authorization"
	_host.add_child(authorization)
	authorization.configure(world)
	var session := GameSessionRuntimeController.new()
	session.name = "GameSession"
	session.set("_configured", true)
	session.set("_session_state", GameSessionRuntimeController.STATE_RUNNING)
	session.set("_session_id", "session-discard-sink-1")
	session.set("_scenario_id", "standard")
	_host.add_child(session)
	var identity := IDENTITY_SCENE.instantiate() as PlayerIdentityAuthorizationBoundary
	identity.name = "Identity"
	identity.local_viewer_authorization_path = NodePath("../Authorization")
	identity.world_session_state_path = NodePath("../World")
	identity.game_session_path = NodePath("../GameSession")
	_host.add_child(identity)
	_scheduler = ForcedDecisionRuntimeScheduler.new()
	_scheduler.name = "Scheduler"
	_scheduler.configure(["other_choice"])
	_host.add_child(_scheduler)
	_port = RESPONSE_SCENE.instantiate() as ForcedDecisionResponsePort
	_port.name = "ResponsePort"
	_port.identity_boundary_path = NodePath("../Identity")
	_port.scheduler_path = NodePath("../Scheduler")
	_host.add_child(_port)
	_action_port = FakeActionPort.new()
	_action_port.name = "ActionPort"
	_host.add_child(_action_port)
	_sink = SINK_SCENE.instantiate() as SINK_SCRIPT
	_sink.name = "Sink"
	_host.add_child(_sink)
	_expect(_sink.configure(_action_port), "sink binds one typed DistrictSupplyActionPort")
	_port.response_authorized.connect(_sink.consume_authorized_response)
	_sink.receipt_ready.connect(func(receipt: DistrictSupplyActionReceipt) -> void:
		if receipt != null:
			_sink_receipts.append(receipt)
	)
	_sync_discard_decision(1)
	var authority_probe := _request("discard-authority-probe", "discard_purchase_cancel", 1)
	_action_port.expected_actor_index = authority_probe.authorized_player_index
	_action_port.expected_authorization_revision = authority_probe.authorization_revision
	_action_port.expected_session_id = authority_probe.session_id
	_action_port.expected_session_revision = authority_probe.session_revision


func _test_production_composition_contract() -> void:
	var scene_source := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var sink_source := FileAccess.get_file_as_string("res://scripts/runtime/district_supply_discard_response_sink.gd")
	var action_port_source := FileAccess.get_file_as_string("res://scripts/runtime/district_supply_action_port.gd")
	_expect(scene_source.count("DistrictSupplyDiscardResponseSink.tscn") == 1, "production Coordinator composes one discard response scene")
	_expect(scene_source.count("[node name=\"DistrictSupplyDiscardResponseSink\"") == 1, "production Coordinator owns one discard response node")
	_expect(coordinator_source.count("response_authorized.connect(discard_sink.consume_authorized_response)") == 1, "production response port reaches the discard sink through one signal edge")
	_expect(coordinator_source.count("discard_sink.receipt_ready.connect(game_screen.apply_district_supply_discard_receipt)") == 1, "one viewer-private receipt edge reaches GameScreen")
	_expect(not sink_source.contains("scripts/main.gd") and not sink_source.contains("/root/Main"), "discard sink has no Main dependency")
	_expect(sink_source.contains('"forced-discard-adapter:%s" % request.request_id'), "adapter preserves the forced-response request identity for downstream replay protection")
	_expect(action_port_source.contains("_journal.has(intent.request_id)") \
		and action_port_source.contains("replay.idempotent_replay = true") \
		and action_port_source.contains("collision.request_id_collision = true"), "production district action authority owns replay and collision rejection")
	var debug: Dictionary = _sink.debug_snapshot()
	_expect(bool(debug.get("typed_requests_only", false)) and not bool(debug.get("owns_gameplay_state", true)), "sink only adapts typed responses and owns no gameplay state")
	_expect(not bool(debug.get("owns_rng", true)) and not bool(debug.get("references_main", true)), "sink owns no RNG and never references Main")


func _test_confirm_and_replay_exact_once() -> void:
	_action_port.seed_pending_discard()
	var request := _request("discard-confirm-1", "discard_purchase_2", 1)
	var port_receipt := _port.submit_response(request)
	var applied := _last_sink_receipt()
	_expect(port_receipt.accepted and port_receipt.emitted, "authorized confirm emits from ForcedDecisionResponsePort once")
	_expect(applied != null and applied.accepted and applied.applied \
		and applied.action_kind == DistrictSupplyActionIntent.KIND_DISCARD_CONFIRM, "confirm reaches the typed district action boundary")
	_expect(_action_port.confirm_count == 1 and _action_port.purchase_mutation_count == 1 \
		and _action_port.cash_mutation_count == 1 and _action_port.inventory_mutation_count == 1, "confirm performs one purchase, cash, and inventory mutation")
	_expect(_action_port.cash_units == 93 and _action_port.inventory_count == 1 \
		and _action_port.last_intent.discard_slot == 2, "confirm preserves the selected private discard slot and expected committed state")
	var submit_before := _action_port.submit_count
	var mutation_before := _mutation_snapshot()
	var replay := _port.submit_response(request)
	_expect(not replay.accepted and replay.idempotent_replay and replay.reason_code == "request_replay", "ForcedDecisionResponsePort rejects an identical replay")
	_expect(_action_port.submit_count == submit_before and _mutation_snapshot() == mutation_before, "port replay never redelivers or remutates the action owner")
	var direct_replay: DistrictSupplyActionReceipt = _sink.consume_authorized_response(request)
	_expect(direct_replay != null and direct_replay.idempotent_replay \
		and direct_replay.reason_code == "request_replay", "direct duplicate delivery resolves as the action-port replay")
	_expect(_mutation_snapshot() == mutation_before, "direct duplicate delivery repeats no purchase, cash, or inventory mutation")


func _test_request_id_collision() -> void:
	var mutations_before := _mutation_snapshot()
	var submit_before := _action_port.submit_count
	var collision := _request("discard-confirm-1", "discard_purchase_cancel", 2)
	var port_collision := _port.submit_response(collision)
	_expect(not port_collision.accepted and port_collision.request_id_collision \
		and port_collision.reason_code == "request_id_collision", "response port rejects a reused request ID with different content")
	_expect(_action_port.submit_count == submit_before and _mutation_snapshot() == mutations_before, "port collision never reaches the mutation boundary")
	var direct_collision: DistrictSupplyActionReceipt = _sink.consume_authorized_response(collision)
	_expect(direct_collision != null and direct_collision.request_id_collision \
		and direct_collision.reason_code == "request_id_collision", "direct conflicting delivery is rejected by the district action journal")
	_expect(_mutation_snapshot() == mutations_before, "direct request-ID collision produces zero additional mutation")


func _test_cancel_without_purchase_mutation() -> void:
	_action_port.seed_pending_discard()
	_sync_discard_decision(2)
	var mutations_before := _mutation_snapshot()
	var request := _request("discard-cancel-1", "discard_purchase_cancel", 3)
	var port_receipt := _port.submit_response(request)
	var cancelled := _last_sink_receipt()
	_expect(port_receipt.accepted and cancelled != null and cancelled.accepted and cancelled.applied \
		and cancelled.action_kind == DistrictSupplyActionIntent.KIND_DISCARD_CANCEL, "authorized cancel reaches the typed cancel action")
	_expect(_action_port.cancel_count == 1 and not _action_port.pending_discard, "cancel closes the pending private discard exactly once")
	_expect(_mutation_snapshot() == mutations_before, "cancel changes no purchase, cash, or inventory state")


func _test_stale_and_unauthorized_fail_closed() -> void:
	_action_port.seed_pending_discard()
	_sync_discard_decision(3)
	var submit_before := _action_port.submit_count
	var mutations_before := _mutation_snapshot()
	var stale := _request("discard-stale-1", "discard_purchase_0", 4)
	stale.decision_revision += 1
	var stale_receipt := _port.submit_response(stale)
	_expect(not stale_receipt.accepted and stale_receipt.reason_code == "decision_revision_stale", "stale discard decision revision fails before sink delivery")
	var unauthorized := _request("discard-unauthorized-1", "discard_purchase_0", 5)
	unauthorized.authorized_player_index = 1
	var unauthorized_receipt := _port.submit_response(unauthorized)
	_expect(not unauthorized_receipt.accepted and unauthorized_receipt.reason_code.begins_with("identity_"), "forged responding player fails identity authorization")
	_expect(_action_port.submit_count == submit_before and _mutation_snapshot() == mutations_before, "stale and unauthorized port requests create zero mutation")
	var direct_unauthorized: DistrictSupplyActionReceipt = _sink.consume_authorized_response(unauthorized)
	_expect(direct_unauthorized != null and not direct_unauthorized.accepted \
		and direct_unauthorized.reason_code == "actor_authorization_rejected", "direct unauthorized delivery still fails at the typed action authority")
	_expect(_mutation_snapshot() == mutations_before, "direct unauthorized delivery creates zero purchase, cash, or inventory mutation")
	var malformed := _request("discard-malformed-1", "discard_purchase_cancel", 6)
	malformed.option_id = "discard_purchase_-1"
	var malformed_submit_before := _action_port.submit_count
	_expect(_sink.consume_authorized_response(malformed) == null \
		and _action_port.submit_count == malformed_submit_before, "malformed discard option fails closed before action submission")


func _test_receipt_privacy_and_pure_data() -> void:
	var receipt := _sink_receipts[0] if not _sink_receipts.is_empty() else null
	_expect(receipt != null and receipt.visibility_scope == &"viewer_private", "discard response receipt remains viewer-private")
	_expect(receipt != null and TablePresentationPureDataPolicy.is_pure_data(receipt.to_dictionary()), "discard response receipt is stable pure data")
	var public_summary := receipt.public_summary() if receipt != null else {}
	var public_serialized := JSON.stringify(public_summary)
	for forbidden in ["request_id", "actor_player_index", "discard_slot", "card_id", "quote_id", "price", "cash", "inventory", "hand", "owner"]:
		_expect(not public_serialized.contains(forbidden), "public summary omits private field %s" % forbidden)
	_expect(str(public_summary.get("visibility_scope", "")) == "public_redacted", "public summary is explicitly redacted")


func _sync_discard_decision(sequence: int) -> void:
	_scheduler.sync_candidates([{
		"id": "discard_choice_%d" % sequence,
		"kind": "discard_purchase",
		"priority_group": "other_choice",
		"owner_player_index": 0,
		"visibility_scope": "private",
		"presentation_surface": "overlay",
		"opened_sequence": float(sequence),
		"blocks_global_time": false,
		"blocks_player_actions": true,
		"blocks_card_resolution": false,
		"source_ref": "discard_purchase",
	}])


func _request(request_id: String, option_id: String, request_revision: int) -> ForcedDecisionResponseRequest:
	return _port.build_request(request_id, option_id, request_revision)


func _last_sink_receipt() -> DistrictSupplyActionReceipt:
	return _sink_receipts.back() if not _sink_receipts.is_empty() else null


func _mutation_snapshot() -> Dictionary:
	return {
		"purchase": _action_port.purchase_mutation_count,
		"cash": _action_port.cash_mutation_count,
		"inventory": _action_port.inventory_mutation_count,
		"cash_units": _action_port.cash_units,
		"inventory_count": _action_port.inventory_count,
	}


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("DISTRICT_SUPPLY_DISCARD_RESPONSE_SINK_EXACT_ONCE_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("DISTRICT_SUPPLY_DISCARD_RESPONSE_SINK_EXACT_ONCE_TEST: %s" % failure)
	_host.free()
	quit(0 if _failures.is_empty() else 1)

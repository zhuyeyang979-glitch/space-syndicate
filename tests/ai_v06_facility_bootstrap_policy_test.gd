extends SceneTree

const FLOW_SCENE := preload("res://scenes/runtime/TablePlayerActionApplicationFlowController.tscn")
const GAME_ACTION_INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const GAME_ACTION_OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")

const SESSION_ID := "session.ai-facility-action-spine"
const SESSION_REVISION := 23
const RESOLUTION_ID := 73

var _checks := 0
var _failures: Array[String] = []


class FakeSession:
	extends GameSessionRuntimeController

	func session_summary() -> Dictionary:
		return {
			"session_state": STATE_RUNNING,
			"session_id": SESSION_ID,
			"scenario_id": "ai-facility-action-spine",
			"ruleset_id": "v0.6",
			"seed": 60501,
		}

	func session_start_revision() -> int:
		return SESSION_REVISION


class FakeCardPlaySubmission:
	extends CardPlaySubmissionRuntimeController

	var submission_count := 0
	var owner_mutation_count := 0
	var requests: Array[Dictionary] = []

	func request_hand_play(request: Dictionary) -> Dictionary:
		submission_count += 1
		requests.append(request.duplicate(true))
		return {
			"accepted": true,
			"queued": true,
			"reason": "facility_card_queued",
			"resolution_id": RESOLUTION_ID,
			"queue_revision": 1,
			"v06_receipt": {
				"accepted": true,
				"queued": true,
				"committed": false,
				"reason_code": "facility_card_queued",
				"resolution_id": RESOLUTION_ID,
				"queue_revision": 1,
			},
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_ai_submission_is_queue_only()
	_test_production_spine_is_unique()
	_finish()


func _test_ai_submission_is_queue_only() -> void:
	var fixture := _fixture()
	var flow := fixture.get("flow") as TablePlayerActionApplicationFlowController
	var capability := fixture.get("capability") as GameActionAiSubmissionCapability
	var card_play := fixture.get("card_play") as FakeCardPlaySubmission
	var offer := flow.ai_card_play_offer(capability, 0, 0, "region.alpha")
	var authorization := flow.ai_actor_authorization(capability, 0, "ai-runtime")
	_expect(
		bool(GAME_ACTION_OFFER.validation_report(offer).get("valid", false))
			and not authorization.is_empty(),
		"capability-bound AI receives one closed card-play offer and authorization"
	)
	var intent := GAME_ACTION_INTENT.build({
		"schema_version": GAME_ACTION_INTENT.SCHEMA_VERSION,
		"request_id": "request.ai.facility.queue.1",
		"semantic_action_id": GAME_ACTION_INTENT.ACTION_CARD_PLAY,
		"source_revision": int(offer.get("source_revision", 0)),
		"actor_authorization": authorization,
		"target_ids": GAME_ACTION_OFFER.target_ids(offer),
		"parameters": {},
		"submission_kind": "ai_decision",
	})
	_expect(
		bool(GAME_ACTION_INTENT.validation_report(intent).get("valid", false))
			and GAME_ACTION_OFFER.accepts_intent(offer, intent),
		"facility submission is a valid offer-bound GameActionIntentV1"
	)
	var forged_capability := GameActionAiSubmissionCapability.new()
	_expect(
		flow.ai_card_play_offer(forged_capability, 0, 0, "region.alpha").is_empty()
			and flow.ai_actor_authorization(forged_capability, 0).is_empty(),
		"an unbound capability cannot obtain an AI offer or authorization"
	)

	var receipt := flow.submit_intent(intent, capability)
	var effect_refs: Array = receipt.get("committed_effect_refs", []) \
		if receipt.get("committed_effect_refs", []) is Array else []
	_expect(
		bool(receipt.get("accepted", false))
			and str(receipt.get("reason_id", "")) == "facility-card-queued"
			and effect_refs == ["card.resolution.%d" % RESOLUTION_ID],
		"formal submission reports a queued resolution reference, not immediate completion"
	)
	_expect(
		card_play.submission_count == 1
			and card_play.owner_mutation_count == 0
			and card_play.requests.size() == 1,
		"submission reaches the card-play command target once and mutates no facility owner"
	)
	var request := card_play.requests[0]
	_expect(
		_same_string_set(request.keys(), [
			"player_index",
			"slot_index",
			"submission_source",
			"request_id",
			"intent_fingerprint",
			"source_revision",
			"actor_kind_id",
			"actor_id",
			"session_id",
			"session_revision",
			"hand_slot_id",
			"card_instance_id",
			"selected_district",
		])
			and int(request.get("selected_district", -1)) == 0
			and not request.has("card")
			and not request.has("method_name"),
		"application flow forwards only stable card, actor, session, and target bindings"
	)

	var replay := flow.submit_intent(intent, capability)
	var debug := flow.debug_snapshot()
	_expect(
		bool(replay.get("accepted", false))
			and bool(replay.get("idempotent_replay", false))
			and card_play.submission_count == 1
			and card_play.owner_mutation_count == 0,
		"same-intent replay does not enqueue or mutate a second time"
	)
	_expect(
		int(debug.get("card_play_apply_count", 0)) == 1
			and int(debug.get("journal_size", 0)) == 1
			and int(debug.get("replay_count", 0)) == 1,
		"the formal action journal records one application and one deterministic replay"
	)
	(fixture.get("host") as Node).free()


func _test_production_spine_is_unique() -> void:
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/runtime/table_player_action_application_flow_controller.gd")
	var submission_source := FileAccess.get_file_as_string("res://scripts/runtime/card_play_submission_runtime_controller.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var adapter_source := FileAccess.get_file_as_string("res://scripts/runtime/facility_card_queue_adapter_v06.gd")
	_expect(
		ai_source.contains("GameActionIntentV1.ACTION_CARD_PLAY")
			and ai_source.contains("_game_action_submission_port.submit_intent")
			and ai_source.contains("_game_action_submission_port.ai_card_play_offer"),
		"AI card play enters the typed offer-intent-submission spine"
	)
	_expect(
		flow_source.contains("request_hand_play(request)")
			and flow_source.contains("v06_receipt.get(\"queued\"")
			and flow_source.contains("CARD_BINDING.resolution_ref"),
		"application flow accepts facility completion only as a valid queued resolution reference"
	)
	_expect(
		submission_source.contains("func _queue_v06_facility(")
			and submission_source.contains("_facility_queue_source.submit(_facility_queue_capability")
			and not coordinator_source.contains("func queue_v06_facility_card_action(")
			and coordinator_source.contains("func resolve_queued_v06_facility_card_action(")
			and coordinator_source.contains("func advance_card_resolution_frame("),
		"facility submission and authorized resolution are separate production transitions"
	)
	_expect(
		adapter_source.contains("func submit(capability: RefCounted, request: Dictionary)")
			and adapter_source.contains("facility_queue_submission_unauthorized")
			and adapter_source.contains("func resolve(entry: Dictionary)")
			and adapter_source.contains("_queue.commit_submission")
			and adapter_source.contains("_resolution_count += 1"),
		"the one scene-owned facility adapter bridges Queue submission to later resolution"
	)
	_expect(
		not ai_source.contains("purchase_rank_i_facility")
			and not ai_source.contains("_ai_v06_facility_bootstrap")
			and not ai_source.contains("play_runtime_card")
			and not coordinator_source.contains("func play_runtime_card(")
			and coordinator_source.contains("v06_facility_requires_game_action_spine"),
		"retired bespoke AI purchase-play and direct facility-play entry points cannot return"
	)


func _fixture() -> Dictionary:
	var host := Node.new()
	host.name = "AiFacilityActionSpineFixture"
	root.add_child(host)
	var world := WorldSessionState.new()
	world.name = "WorldSessionState"
	world.players = [{
		"name": "AI",
		"is_ai": true,
		"eliminated": false,
		"slots": [{
			"runtime_instance_id": "runtime.facility.ai.1",
			"machine": {
				"card_id": "facility.factory.commerce.rank_1",
				"family_id": "facility.factory.commerce",
				"rank": 1,
			},
		}],
	}]
	world.districts = [{"region_id": "region.alpha"}]
	host.add_child(world)
	var session := FakeSession.new()
	session.name = "GameSessionRuntimeController"
	host.add_child(session)
	var card_play := FakeCardPlaySubmission.new()
	card_play.name = "CardPlaySubmissionRuntimeController"
	host.add_child(card_play)
	var flow := FLOW_SCENE.instantiate() as TablePlayerActionApplicationFlowController
	host.add_child(flow)
	var capability := GameActionAiSubmissionCapability.new()
	_expect(flow.bind_ai_submission_capability(capability), "fixture binds one opaque AI submission capability")
	return {
		"host": host,
		"flow": flow,
		"capability": capability,
		"card_play": card_play,
	}


func _same_string_set(actual: Array, expected: Array) -> bool:
	var left: Array[String] = []
	var right: Array[String] = []
	for value in actual:
		left.append(str(value))
	for value in expected:
		right.append(str(value))
	left.sort()
	right.sort()
	return left == right


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("AI_V06_FACILITY_ACTION_SPINE_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(_failures.size())

extends SceneTree

const BindingScript := preload("res://scripts/runtime/v06_save_owner_binding_resource.gd")
const RegistryScript := preload("res://scripts/runtime/v06_save_owner_registry.gd")
const HANDSHAKE_SCENE := preload("res://scenes/runtime/RulesetSaveHandshakeService.tscn")
const PRODUCTION_REGISTRY_SCENE := preload("res://scenes/runtime/V06SaveOwnerRegistry.tscn")
const CONSUMER_SCENE := preload("res://scenes/runtime/CommodityFlowPostCommitReceiptConsumer.tscn")
const WORLD_SCENE := preload("res://scenes/runtime/WorldSessionState.tscn")
const VISUAL_SCENE := preload("res://scenes/runtime/VisualCueRuntimeOwner.tscn")
const RULESET_V06 := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const FIXED_ORDER := [
	"ruleset",
	"region_infrastructure",
	"region_supply",
	"commodity_flow",
	"routes",
	"player_mana",
	"commodity_belt_visibility",
	"card_inventory",
	"player_organization",
	"monsters",
	"military",
	"weather",
	"card_resolution_queue",
	"card_resolution_execution",
	"card_resolution_history",
	"ai",
	"bankruptcy_neutral_estate",
	"victory_control",
	"session",
]

var _checks := 0
var _failures := 0


class CandidateOwner:
	extends Node
	var state: Dictionary = {}
	var apply_count := 0

	func to_save_data() -> Dictionary:
		return state.duplicate(true)

	func preflight_save_data(candidate: Dictionary) -> Dictionary:
		return {
			"accepted": true,
			"reason_code": "candidate_owner_preflight_accepted",
			"normalized_state": candidate.duplicate(true),
		}

	func apply_save_data(candidate: Dictionary) -> Dictionary:
		apply_count += 1
		state = candidate.duplicate(true)
		return {"applied": true, "reason_code": "candidate_owner_applied"}


class FixtureFlow:
	extends CommodityFlowRuntimeController
	var receipts: Array = []
	var save_apply_count := 0

	func region_gdp_snapshot(_region_id: String) -> Dictionary:
		return {
			"region_gdp_per_minute": 24,
			"region_gdp_per_minute_cents": 2400,
			"receipt_ids": ["registry-sale-1"],
			"observation_window_seconds": 30.0,
		}

	func recent_sale_receipts_snapshot(_viewer_index := -1) -> Array:
		return receipts.duplicate(true)

	func player_color_flow_snapshot(player_index: int) -> Dictionary:
		return {
			"valid": true,
			"ruleset_id": "v0.6",
			"player_index": player_index,
			"observation_window_seconds": 30.0,
			"colors": {},
			"asset_recovery_observation_only": true,
		}

	func apply_save_data(data: Dictionary) -> Dictionary:
		save_apply_count += 1
		return super.apply_save_data(data)


class FixtureDerivative:
	extends CityGdpDerivativeRuntimeController

	func positions_for_district(_district_index: int, _include_private := false) -> Array:
		return []

	func settle_district(_district_index: int, _current_gdp: int, _source := "实时GDP", _force_all := false) -> Dictionary:
		return {"committed": false, "reason": "no_positions", "settled_count": 0, "receipts": []}


class FixtureBankruptcy:
	extends BankruptcyNeutralEstateRuntimeController
	var bindings: Dictionary = {}

	func settle_checkpoint(request: Dictionary) -> Dictionary:
		var transaction_id := str(request.get("transaction_id", ""))
		var request_fingerprint := JSON.stringify([
			transaction_id,
			str(request.get("reason_code", "")),
			float(request.get("occurred_at", 0.0)),
			str(request.get("source_fingerprint", "")),
		]).sha256_text()
		bindings[transaction_id] = {
			"transaction_id": transaction_id,
			"state": "finalized",
			"finalized": true,
			"request_fingerprint": request_fingerprint,
			"source_fingerprint": str(request.get("source_fingerprint", "")),
		}
		return {
			"finalized": true,
			"transaction_id": transaction_id,
			"request_fingerprint": request_fingerprint,
		}

	func checkpoint_transaction_binding(transaction_id: String) -> Dictionary:
		return (bindings.get(transaction_id, {}) as Dictionary).duplicate(true) \
			if bindings.get(transaction_id, {}) is Dictionary else {}

	func candidate_state() -> Dictionary:
		return {
			"commodity_flow_retired_sequence": 0,
			"journal": bindings.duplicate(true),
		}


class FixtureMana:
	extends PlayerManaRuntimeController

	func advance(delta_milliseconds: int, _game_time: float, _color_gdp_by_player: Dictionary) -> Dictionary:
		return {"advanced": true, "delta_milliseconds": delta_milliseconds}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var production_registry := PRODUCTION_REGISTRY_SCENE.instantiate()
	var production_binding_ok := false
	for binding in production_registry.bindings:
		if binding != null and binding.section_id == "commodity_flow":
			production_binding_ok = binding.preflight_method == "preflight_save_data"
			break
	_expect(production_binding_ok, "production CommodityFlow binding uses the pure preflight API")
	production_registry.free()

	var finalized := _build_registry_harness(&"")
	_expect(bool(finalized.get("valid", false)), "finalized fixture builds through the real flow consumer and formal registry")
	if bool(finalized.get("valid", false)):
		_verify_finalized_registry_cases(finalized)

	var pending := _build_registry_harness(&"after_bankruptcy_target_before_mark")
	_expect(bool(pending.get("valid", false)), "pending caller-ack fixture builds through the real flow consumer and formal registry")
	if bool(pending.get("valid", false)):
		_verify_pending_registry_cases(pending)

	for fixture in [finalized, pending]:
		var harness := fixture.get("harness") as Node
		if harness != null:
			harness.queue_free()
	await process_frame
	if _failures == 0:
		print("COMMODITY POSTCOMMIT REGISTRY PREFLIGHT PASS: %d/%d" % [_checks, _checks])
		quit(0)
		return
	push_error("COMMODITY POSTCOMMIT REGISTRY PREFLIGHT FAIL: %d/%d" % [_failures, _checks])
	quit(1)


func _verify_finalized_registry_cases(fixture: Dictionary) -> void:
	var registry := fixture.get("registry") as V06SaveOwnerRegistry
	var handshake := fixture.get("handshake") as Node
	var envelope: Dictionary = (fixture.get("envelope", {}) as Dictionary).duplicate(true)
	var flow := fixture.get("flow") as FixtureFlow
	var consumer := fixture.get("consumer") as CommodityFlowPostCommitReceiptConsumer
	var before_states := _live_owner_states(fixture)
	var before_counts := _live_apply_counts(fixture)
	var flow_before := flow.to_save_data()
	var consumer_before := consumer.to_save_data()
	var valid := registry.preflight_envelope(envelope)
	_expect(
		bool(valid.get("ok", false))
		and int(valid.get("preflight_count", 0)) == FIXED_ORDER.size()
		and _live_owner_states(fixture) == before_states
		and _live_apply_counts(fixture) == before_counts
		and flow.to_save_data() == flow_before
		and consumer.to_save_data() == consumer_before,
		"valid formal-registry preflight normalizes all 19 sections without touching live owners"
	)

	var consumer_ahead := envelope.duplicate(true)
	var session_state := _decoded_section_state(handshake, consumer_ahead, "session")
	var world_state: Dictionary = (session_state.get("world_session_state", {}) as Dictionary).duplicate(true)
	world_state["commodity_postcommit_city_lineage_by_district"] = {}
	session_state["world_session_state"] = world_state
	_replace_section_state(handshake, consumer_ahead, "session", session_state)
	_expect(
		_registry_rejects_without_apply(fixture, consumer_ahead),
		"finalized consumer ahead of WorldSession is rejected after all 19 preflights with zero live apply"
	)

	var target_ahead := envelope.duplicate(true)
	session_state = _decoded_section_state(handshake, target_ahead, "session")
	world_state = (session_state.get("world_session_state", {}) as Dictionary).duplicate(true)
	var city_lineage: Dictionary = (world_state.get("commodity_postcommit_city_lineage_by_district", {}) as Dictionary).duplicate(true)
	city_lineage["1"] = {
		"batch_sequence": 2,
		"batch_id": _batch_id(2),
		"batch_fingerprint": "registry-target-ahead-batch".sha256_text(),
		"city_breakdown_fingerprint": "registry-target-ahead-city".sha256_text(),
	}
	world_state["commodity_postcommit_city_lineage_by_district"] = city_lineage
	session_state["world_session_state"] = world_state
	_replace_section_state(handshake, target_ahead, "session", session_state)
	_expect(
		_registry_rejects_without_apply(fixture, target_ahead),
		"target lineage ahead of CommodityFlow is rejected after all 19 preflights with zero live apply"
	)

	var collision := envelope.duplicate(true)
	var bankruptcy_state := _decoded_section_state(handshake, collision, "bankruptcy_neutral_estate")
	var bankruptcy_journal: Dictionary = (bankruptcy_state.get("journal", {}) as Dictionary).duplicate(true)
	var bankruptcy_id := "bankruptcy:%s" % _batch_id(1)
	var bankruptcy_record: Dictionary = (bankruptcy_journal.get(bankruptcy_id, {}) as Dictionary).duplicate(true)
	bankruptcy_record["request_fingerprint"] = "registry-bankruptcy-collision".sha256_text()
	bankruptcy_journal[bankruptcy_id] = bankruptcy_record
	bankruptcy_state["journal"] = bankruptcy_journal
	_replace_section_state(handshake, collision, "bankruptcy_neutral_estate", bankruptcy_state)
	_expect(
		_registry_rejects_without_apply(fixture, collision),
		"downstream fingerprint collision is rejected after all 19 preflights with zero live apply"
	)


func _verify_pending_registry_cases(fixture: Dictionary) -> void:
	var registry := fixture.get("registry") as V06SaveOwnerRegistry
	var handshake := fixture.get("handshake") as Node
	var envelope: Dictionary = (fixture.get("envelope", {}) as Dictionary).duplicate(true)
	var before_states := _live_owner_states(fixture)
	var before_counts := _live_apply_counts(fixture)
	var pending_valid := registry.preflight_envelope(envelope)
	_expect(
		bool(pending_valid.get("ok", false))
		and int(pending_valid.get("preflight_count", 0)) == FIXED_ORDER.size()
		and _live_owner_states(fixture) == before_states
		and _live_apply_counts(fixture) == before_counts,
		"target-success/caller-ack pending window remains recoverable and pure in the formal registry"
	)
	var missing_target := envelope.duplicate(true)
	var bankruptcy_state := _decoded_section_state(handshake, missing_target, "bankruptcy_neutral_estate")
	bankruptcy_state["journal"] = {}
	_replace_section_state(handshake, missing_target, "bankruptcy_neutral_estate", bankruptcy_state)
	_expect(
		_registry_rejects_without_apply(fixture, missing_target),
		"pending caller acknowledgement ahead of its target section is rejected with zero live apply"
	)


func _build_registry_harness(fault_stage: StringName) -> Dictionary:
	var harness := Node.new()
	harness.name = "RegistryHarness%s" % ("Pending" if not fault_stage.is_empty() else "Finalized")
	root.add_child(harness)
	var flow := FixtureFlow.new()
	flow.name = _owner_name("commodity_flow")
	var world := WORLD_SCENE.instantiate() as WorldSessionState
	world.name = "FixtureWorld"
	var derivative := FixtureDerivative.new()
	var visual := VISUAL_SCENE.instantiate() as VisualCueRuntimeOwner
	var bankruptcy := FixtureBankruptcy.new()
	var mana := FixtureMana.new()
	var consumer := CONSUMER_SCENE.instantiate() as CommodityFlowPostCommitReceiptConsumer
	var public_owner := PublicLogPresentationOwner.new()
	var public_port := PublicLogProducerPort.new()
	var scheduler := TablePresentationRefreshScheduler.new()
	for node in [flow, world, derivative, visual, bankruptcy, mana, consumer]:
		harness.add_child(node)
	consumer.add_child(public_owner)
	consumer.add_child(public_port)
	consumer.add_child(scheduler)
	public_port.configure(public_owner)
	scheduler.reset_table_cadence()
	world.replace_players([{"id": 0, "cash": 100, "cash_cents": 10000}], true)
	world.replace_districts([{"region_id": "region.000", "city": {"active": true}}], true)
	world.game_time = 5.0
	var receipt := _receipt()
	flow.receipts = [receipt]
	var configured_consumer := consumer.configure(
		flow,
		world,
		derivative,
		visual,
		bankruptcy,
		mana,
		public_port,
		scheduler
	)
	flow.set_postcommit_consumer(consumer)
	var configured_flow := flow.configure(RULESET_V06.debug_snapshot())
	if not fault_stage.is_empty():
		consumer.inject_test_failure(fault_stage)
	var consumed := consumer.consume_committed_batch(_batch(receipt))
	var expected_consumed := not bool(consumed.get("completed", true)) if not fault_stage.is_empty() \
		else bool(consumed.get("completed", false))
	var flow_state := flow.to_save_data()
	flow_state["batch_sequence"] = 1
	flow_state["flow_revision"] = 1
	var applied_flow := flow.apply_save_data(flow_state)
	flow_state = flow.to_save_data()
	var session_state := {
		"world_session_state": world.to_save_data(),
		"card_history_private_annotations": {
			"annotations_by_viewer": {"0": {"card-history:70": {}}},
		},
	}
	var candidate_states: Dictionary = {
		"commodity_flow": flow_state,
		"player_mana": mana.to_save_data(),
		"card_resolution_history": {
			"schema": "v0.6.card-resolution-history.1",
			"history_limit": 24,
			"history": [{"resolution_id": 70, "resolved": true}],
			"appended_resolution_ids": [70],
			"revision": 1,
		},
		"bankruptcy_neutral_estate": bankruptcy.candidate_state(),
		"session": session_state,
	}
	for index in range(FIXED_ORDER.size()):
		var section_id := str(FIXED_ORDER[index])
		if section_id == "commodity_flow":
			continue
		var owner := CandidateOwner.new()
		owner.name = _owner_name(section_id)
		owner.state = (candidate_states.get(section_id, {
			"section_id": section_id,
			"value": index,
		}) as Dictionary).duplicate(true)
		harness.add_child(owner)
	var handshake := HANDSHAKE_SCENE.instantiate()
	handshake.name = "RulesetSaveHandshakeService"
	harness.add_child(handshake)
	var registry := RegistryScript.new()
	registry.name = "V06SaveOwnerRegistry"
	registry.handshake_path = NodePath("../RulesetSaveHandshakeService")
	var manifest: Dictionary = handshake.call("required_section_manifest")
	var bindings: Array[BindingScript] = []
	for section_id_variant in FIXED_ORDER:
		var section_id := str(section_id_variant)
		var contract: Dictionary = manifest.get(section_id, {}) if manifest.get(section_id, {}) is Dictionary else {}
		var binding := BindingScript.new()
		binding.section_id = section_id
		binding.owner_id = str(contract.get("owner_id", ""))
		binding.state_version = int(contract.get("state_version", 0))
		binding.owner_path = NodePath("../%s" % _owner_name(section_id))
		binding.capture_method = "to_save_data"
		binding.preflight_method = "preflight_save_data"
		binding.apply_method = "apply_save_data"
		binding.rollback_method = "apply_save_data"
		binding.restore_mode = BindingScript.RESTORE_TRANSACTIONAL
		binding.unsupported_reason = ""
		bindings.append(binding)
	registry.bindings = bindings
	harness.add_child(registry)
	var capture := registry.capture_resume_envelope({
		"envelope_id": "commodity-postcommit-registry-%s" % ("pending" if not fault_stage.is_empty() else "finalized"),
		"write_id": "commodity-postcommit-registry-write",
	})
	return {
		"valid": bool(configured_consumer.get("configured", false))
			and bool(configured_flow.get("configured", false))
			and expected_consumed
			and bool(applied_flow.get("applied", false))
			and bool(capture.get("ok", false)),
		"harness": harness,
		"flow": flow,
		"consumer": consumer,
		"registry": registry,
		"handshake": handshake,
		"envelope": (capture.get("envelope", {}) as Dictionary).duplicate(true),
	}


func _registry_rejects_without_apply(fixture: Dictionary, envelope: Dictionary) -> bool:
	var registry := fixture.get("registry") as V06SaveOwnerRegistry
	var before_states := _live_owner_states(fixture)
	var before_counts := _live_apply_counts(fixture)
	var result := registry.apply_envelope(envelope)
	return not bool(result.get("ok", true)) \
		and str(result.get("reason_code", "")) == "cross_section_dependency_rejected" \
		and int(result.get("preflight_count", 0)) == FIXED_ORDER.size() \
		and _live_owner_states(fixture) == before_states \
		and _live_apply_counts(fixture) == before_counts


func _live_owner_states(fixture: Dictionary) -> Dictionary:
	var harness := fixture.get("harness") as Node
	var result: Dictionary = {}
	for section_id_variant in FIXED_ORDER:
		var section_id := str(section_id_variant)
		var owner := harness.get_node_or_null(_owner_name(section_id))
		result[section_id] = owner.to_save_data() if owner != null else {}
	return result


func _live_apply_counts(fixture: Dictionary) -> Dictionary:
	var harness := fixture.get("harness") as Node
	var result: Dictionary = {}
	for section_id_variant in FIXED_ORDER:
		var section_id := str(section_id_variant)
		var owner := harness.get_node_or_null(_owner_name(section_id))
		if owner is FixtureFlow:
			result[section_id] = (owner as FixtureFlow).save_apply_count
		elif owner is CandidateOwner:
			result[section_id] = (owner as CandidateOwner).apply_count
	return result


func _decoded_section_state(handshake: Node, envelope: Dictionary, section_id: String) -> Dictionary:
	var sections: Dictionary = envelope.get("sections", {}) if envelope.get("sections", {}) is Dictionary else {}
	var wrapper: Dictionary = sections.get(section_id, {}) if sections.get(section_id, {}) is Dictionary else {}
	var decoded: Dictionary = handshake.call("decode_codec_value", wrapper.get("owner_state"))
	return (decoded.get("value", {}) as Dictionary).duplicate(true) if decoded.get("value", {}) is Dictionary else {}


func _replace_section_state(
	handshake: Node,
	envelope: Dictionary,
	section_id: String,
	owner_state: Dictionary
) -> void:
	var sections: Dictionary = (envelope.get("sections", {}) as Dictionary).duplicate(true)
	var wrapper: Dictionary = (sections.get(section_id, {}) as Dictionary).duplicate(true)
	var encoded: Dictionary = handshake.call("encode_codec_value", owner_state)
	wrapper["owner_state"] = encoded.get("value")
	sections[section_id] = wrapper
	envelope["sections"] = sections


func _receipt() -> Dictionary:
	return {
		"receipt_id": "registry-sale-1",
		"commodity_owner": 0,
		"commodity_id": "星露莓",
		"color": "life",
		"units": 1,
		"source_region_id": "region.000",
		"market_region_id": "region.000",
		"route_id": "",
		"base_unit_price_cents": 1000,
		"shortest_legal_distance": 0,
		"distance_premium_basis_points": 0,
		"unit_price_cents": 1000,
		"gdp_value": 1000,
		"owner_net_cash": 1000,
		"rent_rows": [],
		"settled_at": 5.0,
	}


func _batch(receipt: Dictionary) -> Dictionary:
	var result := {
		"batch_id": _batch_id(1),
		"ruleset_id": "v0.6",
		"batch_sequence": 1,
		"flow_revision_before": 0,
		"flow_revision": 1,
		"settled_at": 5.0,
		"flow_delta_seconds": 1.0,
		"receipt_ids": ["registry-sale-1"],
		"receipts": [receipt.duplicate(true)],
		"flow_result_summary": {
			"advanced": true,
			"reason": "",
			"batch_id": _batch_id(1),
			"receipt_count": 1,
			"flow_revision": 1,
			"settled_at": 5.0,
			"flow_delta_seconds": 1.0,
			"postcommit_completed": false,
		},
	}
	result["batch_fingerprint"] = CommodityFlowPostCommitReceiptConsumer.batch_fingerprint(result)
	return result


func _batch_id(sequence: int) -> String:
	return "commodity-flow-batch-%010d" % sequence


func _owner_name(section_id: String) -> String:
	return "Owner_%s" % section_id.replace("-", "_")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("COMMODITY POSTCOMMIT REGISTRY PREFLIGHT: %s" % message)

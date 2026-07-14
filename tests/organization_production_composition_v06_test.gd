extends SceneTree

const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")
const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const OWNER_SCRIPT := preload("res://scripts/runtime/player_organization_runtime_controller.gd")
const PORT_SCRIPT := preload("res://scripts/cards/v06/production/organization_production_port_v06.gd")
const ROUTER_SCRIPT := preload("res://scripts/cards/v06/production/core_economic_card_effect_router_v06.gd")
const FLOW_SCRIPT := preload("res://scripts/cards/v06/card_flow_transaction_service_v06.gd")
const STATE_PORT_SCRIPT := preload("res://scripts/cards/v06/card_player_state_port_v06.gd")

const ACTOR := "human.organization"
const CARD_ID := "organization.deep_space_archive.rank_1"
const FORBIDDEN_PUBLIC_KEYS := [
	"actor_id", "exact_cash", "cash_after", "true_owner", "hidden_owner", "owner_truth",
	"hand", "discard", "ai_plan", "ai_score", "route_plan_score",
]

var _checks := 0
var _failures: Array[String] = []
var _catalog: CardRuntimeCatalogV06Resource
var _owned_nodes: Array[Node] = []
var _owned_only := false


class ReferenceConsumer:
	extends RefCounted

	func organization_consumer_capabilities_v06(domain: String) -> Dictionary:
		return {
			"ruleset_id": "v0.6",
			"domain": domain,
			"consumes_authoritative_organization_terms": true,
			"production_ready": true,
		}

	func apply_organization_asset_recovery_terms_v06(_terms: Dictionary = {}) -> Dictionary:
		return {"applied": true}

	func apply_organization_hand_limit_terms_v06(_terms: Dictionary = {}) -> Dictionary:
		return {"applied": true}

	func apply_organization_card_window_submission_capability_v06(_terms: Dictionary = {}) -> Dictionary:
		return {"applied": true}

	func apply_organization_military_command_caps_v06(_terms: Dictionary = {}) -> Dictionary:
		return {"applied": true}

	func configure_monster_binding_capability_provider_v06(value: Object) -> Dictionary:
		var ready := value != null \
			and value.has_method("current_monster_binding_window_snapshot_v06") \
			and value.has_method("monster_binding_caps") \
			and value.has_method("monster_binding_caps_for_target_owner")
		return {"configured": ready}

	func queue_state_snapshot() -> Dictionary:
		return {"last_group_window_sequence": 2, "revision": 7}


class CommitRejectingStatePort:
	extends RefCounted
	var inner: Object
	var commit_calls := 0

	func _init(value: Object) -> void:
		inner = value

	func register_player(actor_id: String, initial_state: Dictionary) -> Dictionary:
		return inner.call("register_player", actor_id, initial_state) as Dictionary

	func read_player(actor_id: String) -> Dictionary:
		return inner.call("read_player", actor_id) as Dictionary

	func reserve_transaction(transaction_id: String, intent_hash: String, expected_revisions: Dictionary, actor_ids: Array) -> Dictionary:
		return inner.call("reserve_transaction", transaction_id, intent_hash, expected_revisions, actor_ids) as Dictionary

	func commit_reserved(_reservation_id: String, _next_states: Dictionary, _effect_receipt: Dictionary) -> Dictionary:
		commit_calls += 1
		return {"committed": false, "reason_code": "reference_outer_commit_rejected"}

	func abort_reserved(reservation_id: String, reason_code: String = "reservation_aborted") -> Dictionary:
		return inner.call("abort_reserved", reservation_id, reason_code) as Dictionary

	func replay_result(transaction_id: String, intent_hash: String) -> Dictionary:
		return inner.call("replay_result", transaction_id, intent_hash) as Dictionary


class RuntimeWorld:
	extends Node
	var players: Array = []
	var districts: Array = []
	var game_time := 0.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_owned_only = OS.get_cmdline_user_args().has("--owned-only")
	_catalog = load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(_catalog != null and bool(_catalog.reload().get("valid", false)), "authoritative v0.6 catalog loads")
	if _catalog == null:
		_finish()
		return
	if not _owned_only:
		_test_scene_composition_and_production_fail_closed()
	_test_reference_complete_cardflow_lifecycle()
	_test_outer_commit_rollback_and_save_load()
	_test_field_route_forgery_and_privacy()
	_finish()


func _test_scene_composition_and_production_fail_closed() -> void:
	var packed := load(COORDINATOR_SCENE_PATH) as PackedScene
	_expect(packed != null, "Coordinator scene parses")
	if packed == null:
		return
	var coordinator := packed.instantiate()
	root.add_child(coordinator)
	_owned_nodes.append(coordinator)
	var owner_nodes := coordinator.find_children("PlayerOrganizationRuntimeController", "", true, false)
	_expect(owner_nodes.size() == 1, "Coordinator composes exactly one organization owner")
	coordinator.call("configure", PROFILE.debug_snapshot())
	var world := RuntimeWorld.new()
	world.players = [{
		"id": 0,
		"actor_id": ACTOR,
		"name": "Organization Human",
		"cash": 20,
		"cash_cents": 2000,
		"slots": [_catalog.card_snapshot(CARD_ID)],
	}]
	root.add_child(world)
	_owned_nodes.append(world)
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService")
	if queue != null and queue.has_method("replace_state"):
		queue.call("replace_state", {
			"current_queue": [], "active_entry": {}, "next_queue": [],
			"resolution_sequence": 0, "last_group_window_sequence": 2, "revision": 7,
		})
	var binding: Dictionary = coordinator.call("refresh_v06_production_player_bindings", world)
	var readiness: Dictionary = coordinator.call("organization_consumer_readiness_snapshot")
	var consumers: Dictionary = readiness.get("consumers", {}) if readiness.get("consumers", {}) is Dictionary else {}
	_expect(bool(binding.get("organization_owner_ready", false)), "production actor binding configures the unique organization owner")
	_expect(consumers.size() == 5 and consumers.has("asset_recovery") and consumers.has("hand_limit") and consumers.has("card_window") and consumers.has("monster_binding") and consumers.has("military_command"), "readiness lists all five consumer domains")
	_expect(bool((consumers.get("monster_binding", {}) as Dictionary).get("ready", false)), "B7 Monster provider interface binds the stateless organization delegate")
	_expect(not bool(readiness.get("production_ready", true)), "unwired business consumers keep organization production fail-closed")
	coordinator.set("_configured", true)
	var before_player: Dictionary = coordinator.call("v06_card_player_snapshot", ACTOR)
	var owner: Object = coordinator.call("player_organization_runtime_controller")
	var before_owner: Dictionary = owner.call("to_save_data")
	var route: Dictionary = coordinator.call("v06_runtime_card_route", _catalog.card_snapshot(CARD_ID))
	_expect(str(route.get("route_id", "")) == "core_economic_card_runtime" and str(route.get("effect_kind", "")) == "install_organization_upgrade", "effect fields route organization cards through the existing production CardFlow path")
	var request := {
		"actor_id": ACTOR,
		"slot_index": 0,
		"transaction_id": "c15-production-incomplete",
		"organization_consumer_readiness": {"production_ready": true},
	}
	var rejected: Dictionary = coordinator.call("play_v06_runtime_card", request)
	_expect(not bool(rejected.get("committed", true)) and str(rejected.get("reason_code", "")) == "organization_consumer_capabilities_incomplete", "production play rejects incomplete consumers before CardFlow commit")
	_expect(_same_data(before_player, coordinator.call("v06_card_player_snapshot", ACTOR)) and _same_data(before_owner, owner.call("to_save_data")), "incomplete readiness and forged request readiness mutate no player, card, or organization state")
	var inflight_prepared: Dictionary = owner.call("prepare_organization_upgrade", _intent(owner, "c15-checkpoint-inflight", 2))
	var blocked_save: Dictionary = coordinator.call("player_organization_to_save_data")
	_expect(bool(inflight_prepared.get("prepared", false)) and not bool(blocked_save.get("saved", true)) and not bool((blocked_save.get("checkpoint", {}) as Dictionary).get("can_checkpoint", true)), "Coordinator save gate rejects an inflight organization transaction")
	owner.call("abort_prepared_organization_upgrade", inflight_prepared)
	var save_bundle: Dictionary = coordinator.call("player_organization_to_save_data")
	_expect(bool(save_bundle.get("saved", false)) and bool((save_bundle.get("checkpoint", {}) as Dictionary).get("can_checkpoint", false)), "Coordinator save bundle includes a checkpoint-safe organization owner snapshot")
	var health: Dictionary = coordinator.call("debug_snapshot")
	var organization_health: Dictionary = health.get("player_organization_runtime", {}) if health.get("player_organization_runtime", {}) is Dictionary else {}
	_expect(bool(organization_health.get("controller_authoritative", false)) and int(organization_health.get("actor_count", 0)) == 1, "composition health reports the unique authoritative organization owner")


func _test_reference_complete_cardflow_lifecycle() -> void:
	var owner := _new_owner()
	owner.configure([ACTOR])
	var port := PORT_SCRIPT.new()
	var consumers := _reference_consumers()
	var configured: Dictionary = port.configure(owner, consumers)
	_expect(bool(configured.get("configured", false)) and bool(port.organization_consumer_readiness_snapshot().get("production_ready", false)), "reference consumers satisfy declared and functional readiness probes")
	var window: Dictionary = port.current_monster_binding_window_snapshot_v06()
	var monster_caps: Dictionary = port.monster_binding_caps(ACTOR, int(window.get("window_sequence", -1)))
	var target_owner_caps: Dictionary = port.monster_binding_caps_for_target_owner(ACTOR, int(window.get("window_sequence", -1)))
	_expect(bool(window.get("authoritative", false)) and int(window.get("window_sequence", -1)) == 2 and int(window.get("revision", -1)) == 7, "Monster delegate reads live authoritative window facts from the single Queue port")
	_expect(bool(monster_caps.get("authoritative", false)) and str(monster_caps.get("capability_kind", "")) == "monster_caps" and _same_data(monster_caps, target_owner_caps), "Monster delegate forwards current-owner and target-owner caps from the single organization owner")
	var router := ROUTER_SCRIPT.new()
	router.configure({"install_organization_upgrade": port})
	var flow := FLOW_SCRIPT.new(_catalog)
	flow.register_player(ACTOR, _player_state([_catalog.card_snapshot(CARD_ID)]))
	var target := _target(owner, 2)
	var committed: Dictionary = flow.play_card(ACTOR, 0, target, router, 0, "c15-reference-success")
	_expect(bool(committed.get("committed", false)) and bool((committed.get("effect_finalization", {}) as Dictionary).get("finalized", false)), "one outer CardFlow transaction prepares, commits, and finalizes the organization effect")
	var after_player: Dictionary = flow.player_snapshot(ACTOR)
	var after_owner: Dictionary = owner.private_snapshot(ACTOR, 3)
	_expect(_card_count(after_player) == 0 and _installed_count(after_owner) == 1 and int(owner.hand_limit_terms(ACTOR, 3).get("ordinary_hand_limit", 0)) == 6, "finalized play consumes one card and installs one next-window organization")
	var replay: Dictionary = flow.play_card(ACTOR, 0, target, router, 0, "c15-reference-success")
	_expect(bool(replay.get("committed", false)) and bool(replay.get("idempotent_replay", false)), "outer transaction replay returns the single CardFlow terminal")
	_expect(_same_data(after_player, flow.player_snapshot(ACTOR)) and _same_data(after_owner, owner.private_snapshot(ACTOR, 3)), "replay causes no second card debit or organization install")
	_expect(flow.journal_snapshot().size() == 1, "organization play uses the existing CardFlow journal only")


func _test_outer_commit_rollback_and_save_load() -> void:
	var owner := _new_owner()
	owner.configure([ACTOR])
	var port := PORT_SCRIPT.new()
	port.configure(owner, _reference_consumers())
	var router := ROUTER_SCRIPT.new()
	router.configure({"install_organization_upgrade": port})
	var state_port := CommitRejectingStatePort.new(STATE_PORT_SCRIPT.new())
	var flow := FLOW_SCRIPT.new(_catalog, state_port)
	flow.register_player(ACTOR, _player_state([_catalog.card_snapshot(CARD_ID)]))
	var before_player: Dictionary = flow.player_snapshot(ACTOR)
	var failed: Dictionary = flow.play_card(ACTOR, 0, _target(owner, 4), router, 0, "c15-reference-rollback")
	_expect(not bool(failed.get("committed", true)) and bool(failed.get("rolled_back", false)) and state_port.commit_calls == 1, "outer player-state commit failure rolls back the organization owner")
	_expect(_same_data(before_player, flow.player_snapshot(ACTOR)) and _installed_count(owner.private_snapshot(ACTOR, 5)) == 0, "rollback failure path leaves card, resources, and organization content unchanged")
	_expect(bool(owner.checkpoint_status().get("can_checkpoint", false)), "successful compensation closes organization inflight state")

	var save_owner := _new_owner()
	save_owner.configure([ACTOR])
	var save_port := PORT_SCRIPT.new()
	save_port.configure(save_owner, _reference_consumers())
	var save_router := ROUTER_SCRIPT.new()
	save_router.configure({"install_organization_upgrade": save_port})
	var save_flow := FLOW_SCRIPT.new(_catalog)
	save_flow.register_player(ACTOR, _player_state([_catalog.card_snapshot(CARD_ID)]))
	var saved_play: Dictionary = save_flow.play_card(ACTOR, 0, _target(save_owner, 6), save_router, 0, "c15-reference-save")
	_expect(bool(saved_play.get("committed", false)), "save fixture finalizes through CardFlow")
	var save_data: Dictionary = save_owner.to_save_data()
	var restored := _new_owner()
	var applied: Dictionary = restored.apply_save_data(save_data)
	_expect(bool(applied.get("applied", false)) and _same_data(save_owner.private_snapshot(ACTOR, 7), restored.private_snapshot(ACTOR, 7)), "organization owner save/load preserves finalized state and journal")
	_expect(bool(restored.checkpoint_status().get("can_checkpoint", false)), "restored finalized organization state is checkpoint-safe")


func _test_field_route_forgery_and_privacy() -> void:
	var owner := _new_owner()
	owner.configure([ACTOR])
	var incomplete_port := PORT_SCRIPT.new()
	incomplete_port.configure(owner, {})
	var intent := _intent(owner, "c15-forged-readiness", 1)
	intent["organization_consumer_readiness"] = {"production_ready": true, "asset_recovery": true}
	var rejected: Dictionary = incomplete_port.prepare_effect(intent)
	_expect(str(rejected.get("reason_code", "")) == "organization_consumer_capabilities_incomplete" and bool(owner.checkpoint_status().get("can_checkpoint", false)), "request-supplied readiness cannot authorize an organization prepare")
	var wrong := intent.duplicate(true)
	wrong["effect_kind"] = "build_upgrade_or_repair_facility"
	_expect(str(incomplete_port.prepare_effect(wrong).get("reason_code", "")) == "organization_effect_kind_invalid", "wrong effect kind cannot cross-route by card name or payload")

	var ready_port := PORT_SCRIPT.new()
	ready_port.configure(owner, _reference_consumers())
	var prepared: Dictionary = ready_port.prepare_effect(_intent(owner, "c15-public-receipt", 1))
	var committed: Dictionary = ready_port.commit_effect(prepared)
	var finalized: Dictionary = ready_port.finalize_effect(committed)
	var public_receipt: Dictionary = ready_port.public_receipt(finalized)
	var public_projection := {"snapshot": ready_port.public_snapshot(), "receipt": public_receipt}
	_expect(_privacy_leaks(public_projection).is_empty(), "public organization projection and receipt recursively leak no actor, cash, hand, owner truth, or AI plan")
	_expect(not public_receipt.has("actor_id") and not JSON.stringify(public_projection).contains(ACTOR), "public receipt omits the internal actor binding")


func _reference_consumers() -> Dictionary:
	var consumer := ReferenceConsumer.new()
	return {
		"asset_recovery": consumer,
		"hand_limit": consumer,
		"card_window": consumer,
		"monster_binding": consumer,
		"military_command": consumer,
	}


func _new_owner() -> PlayerOrganizationRuntimeController:
	var owner := OWNER_SCRIPT.new() as PlayerOrganizationRuntimeController
	_owned_nodes.append(owner)
	return owner


func _target(owner: Object, window_sequence: int) -> Dictionary:
	var private: Dictionary = owner.call("private_snapshot", ACTOR, window_sequence)
	return {
		"valid": true,
		"target_kind": "self_organization_slot",
		"target_actor_id": ACTOR,
		"window_sequence": window_sequence,
		"expected_owner_revision": int(private.get("owner_revision", -1)),
	}


func _intent(owner: Object, transaction_id: String, window_sequence: int) -> Dictionary:
	var card := _catalog.card_snapshot(CARD_ID)
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	return {
		"transaction_id": transaction_id,
		"actor_id": ACTOR,
		"card_id": CARD_ID,
		"card_instance_id": "%s-instance" % transaction_id,
		"effect_kind": str(machine.get("effect_kind", "")),
		"target_hash": "target-%s" % transaction_id,
		"payload_hash": "payload-%s" % transaction_id,
		"intent_hash": "intent-%s" % transaction_id,
		"target_context": _target(owner, window_sequence),
		"effect_payload": (machine.get("effect_payload", {}) as Dictionary).duplicate(true),
	}


func _player_state(cards: Array) -> Dictionary:
	return {
		"revision": 0,
		"cash": 20,
		"assets": {"life": 2, "energy": 2, "industry": 2, "technology": 2, "commerce": 2, "shipping": 2},
		"inventory": {"hand_limit": 5, "slots": cards.duplicate(true)},
	}


func _card_count(player: Dictionary) -> int:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary:
			count += 1
	return count


func _installed_count(private_snapshot: Dictionary) -> int:
	var slots: Array = private_snapshot.get("slots", []) if private_snapshot.get("slots", []) is Array else []
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary and not (slot_variant as Dictionary).is_empty():
			count += 1
	return count


func _privacy_leaks(value: Variant, path: String = "$") -> Array[String]:
	var leaks: Array[String] = []
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			var child_path := "%s.%s" % [path, key]
			if FORBIDDEN_PUBLIC_KEYS.has(key):
				leaks.append(child_path)
			leaks.append_array(_privacy_leaks((value as Dictionary).get(key_variant), child_path))
	elif value is Array:
		for index in range((value as Array).size()):
			leaks.append_array(_privacy_leaks((value as Array)[index], "%s[%d]" % [path, index]))
	elif value is String:
		var text := str(value).to_lower()
		for forbidden in ["exact_cash", "cash_after", "true_owner", "hidden_owner", "owner_truth", "ai_plan", "ai_score", "route_plan_score"]:
			if text.contains(forbidden):
				leaks.append(path)
	return leaks


func _same_data(first: Variant, second: Variant) -> bool:
	return JSON.stringify(first) == JSON.stringify(second)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	for node in _owned_nodes:
		if not is_instance_valid(node):
			continue
		if node.is_inside_tree():
			node.queue_free()
		else:
			node.free()
	_owned_nodes.clear()
	if _failures.is_empty():
		print("ORGANIZATION_PRODUCTION_COMPOSITION_V06_TEST|status=PASS|scope=%s|checks=%d|failures=0" % ["owned_only" if _owned_only else "composition", _checks])
		quit(0)
		return
	print("ORGANIZATION_PRODUCTION_COMPOSITION_V06_TEST|status=FAIL|scope=%s|checks=%d|failures=%d|details=%s" % ["owned_only" if _owned_only else "composition", _checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)

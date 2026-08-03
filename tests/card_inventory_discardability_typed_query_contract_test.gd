extends Node

const SERVICE_SCRIPT := preload("res://scripts/runtime/card_inventory_runtime_service.gd")
const SERVICE_SOURCE_PATH := "res://scripts/runtime/card_inventory_runtime_service.gd"
const HAND_INTERACTION_SOURCE_PATH := "res://scripts/runtime/player_hand_interaction_runtime_service.gd"
const COORDINATOR_SOURCE_PATH := "res://scripts/runtime/game_runtime_coordinator.gd"
const BENCH_SOURCE_PATH := "res://scripts/tools/card_inventory_runtime_characterization_bench.gd"
const MAIN_SOURCE_PATH := "res://scripts/main.gd"
const SETTLEMENT_SOURCE_PATH := "res://scripts/runtime/district_purchase_settlement_runtime_service.gd"
const SLOT_FACT_KEYS := [
	"slot_index",
	"occupied",
	"counts_toward_hand_limit",
	"queued_for_resolution",
	"lock_left",
]

var _contract_passed := 0
var _contract_total := 0
var _mutation_passed := 0
var _mutation_total := 0
var _privacy_passed := 0
var _privacy_total := 0
var _interaction_passed := {"zero_candidate": 0, "stale_plan": 0, "compensation": 0, "disrupt": 0}
var _interaction_total := {"zero_candidate": 0, "stale_plan": 0, "compensation": 0, "disrupt": 0}
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var service: Variant = SERVICE_SCRIPT.new()
	add_child(service as Node)
	service.call("configure", {
		"ruleset_id": "v0.4",
		"card_inventory": {"ordinary_hand_limit": 5, "maximum_card_rank": 4},
	})
	_expect_contract(bool(service.call("is_ready")), "Card Inventory discardability owner is configured")
	var hand := PlayerHandInteractionRuntimeService.new()
	add_child(hand)
	hand.set_inventory_service(service as Node)
	hand.configure()
	_interaction_expect("zero_candidate", bool(hand.debug_snapshot().get("service_ready", false)), "Hand Interaction service configures against the production inventory owner")
	_test_interaction_plan_matrix(hand)
	_test_interaction_stale_commit_matrix(hand, service as CardInventoryRuntimeService)
	_test_interaction_valid_behavior(hand, service as CardInventoryRuntimeService)

	var world_slots := [
		_card("private.queued", "facility", false, true, 0.0),
		_card("private.locked", "facility", false, false, 8.0),
		_card("private.ordinary", "facility", false, false, 0.0),
		_card("private.monster_action", "monster_bound_action", true, false, 0.0),
		_card("private.military_action", "military_command", true, false, 0.0),
		null,
		{},
	]
	var world_before := world_slots.duplicate(true)
	var service_before: Variant = service.call("capture_runtime_checkpoint")
	var facts := SERVICE_SCRIPT.discardability_facts_from_world_slots(world_slots)
	var facts_before := facts.duplicate(true)
	var discardable: Variant = service.call("discardable_slots", facts)
	var service_after: Variant = service.call("capture_runtime_checkpoint")

	_expect_contract(bool(facts.get("valid", false)) and str(facts.get("reason_code", "")) == "discardability_facts_projected", "World slots project into a valid typed facts envelope")
	var slots: Array = facts.get("slots", []) if facts.get("slots", []) is Array else []
	_expect_contract(slots.size() == world_slots.size() and _all_slot_facts_have_exact_keys(slots), "projection emits one exact five-field record per world slot")
	_expect_contract(_slot_matches(slots, 0, true, true, true, 0.0), "queued ordinary card facts preserve occupancy, count, queue and lock")
	_expect_contract(_slot_matches(slots, 1, true, true, false, 8.0), "locked ordinary card facts preserve occupancy, count, queue and lock")
	_expect_contract(_slot_matches(slots, 2, true, true, false, 0.0), "ordinary unlocked card facts preserve occupancy, count, queue and lock")
	_expect_contract(not bool((slots[3] as Dictionary).get("counts_toward_hand_limit", true)) and not bool((slots[4] as Dictionary).get("counts_toward_hand_limit", true)), "persistent monster and military actions remain non-counted")
	_expect_contract(not bool((slots[5] as Dictionary).get("occupied", true)) and not bool((slots[6] as Dictionary).get("occupied", true)), "null and empty slots are closed unoccupied facts")
	_expect_contract(discardable == [2], "authoritative owner excludes queued, locked, non-counted and empty slots")

	var sparse_facts := SERVICE_SCRIPT.discardability_facts_from_world_slots([
		_card("private.zero", "facility", false, false, 0.0),
		null,
		_card("private.two", "facility", false, false, 0.0),
		null,
		_card("private.four", "facility", false, false, 0.0),
	])
	_expect_contract(service.call("discardable_slots", sparse_facts) == [0, 2, 4], "projection preserves stable ascending world slot order")
	var explicit_non_counted := _card("private.explicit", "facility", false, false, 0.0)
	explicit_non_counted["counts_toward_hand_limit"] = false
	var explicit_facts := SERVICE_SCRIPT.discardability_facts_from_world_slots([explicit_non_counted])
	_expect_contract((service.call("discardable_slots", explicit_facts) as Array).is_empty(), "explicit non-counted cards remain excluded by the unique owner")
	_expect_contract(_projection_failed(SERVICE_SCRIPT.discardability_facts_from_world_slots([42])), "non-Dictionary world slot fails closed")
	_expect_contract(_projection_failed(SERVICE_SCRIPT.discardability_facts_from_world_slots([{"name": "private.bad_queue", "queued_for_resolution": "true"}])), "malformed queue flag fails closed")
	_expect_contract(_projection_failed(SERVICE_SCRIPT.discardability_facts_from_world_slots([{"name": "private.bad_lock", "lock_left": "8"}])), "malformed lock value fails closed")

	var service_source := FileAccess.get_file_as_string(SERVICE_SOURCE_PATH)
	var coordinator_source := FileAccess.get_file_as_string(COORDINATOR_SOURCE_PATH)
	var bench_source := FileAccess.get_file_as_string(BENCH_SOURCE_PATH)
	var main_source := FileAccess.get_file_as_string(MAIN_SOURCE_PATH)
	var settlement_source := FileAccess.get_file_as_string(SETTLEMENT_SOURCE_PATH)
	var retired_main_method := "_" + "discardable_hand_slots_for_purchase"
	var projection_source := _function_source(service_source, "discardability_facts_from_world_slots")
	var owner_source := _function_source(service_source, "discardable_slots")
	var facade_source := _function_source(coordinator_source, "card_inventory_discardable_slots")
	_expect_contract(projection_source.contains("canonical_card_counts_toward_hand_limit(card)") and not projection_source.contains("discardable_slots("), "projection reuses canonical count semantics without filtering discardability")
	_expect_contract(owner_source.contains("queued_for_resolution") and owner_source.contains("lock_left") and owner_source.contains("counts_toward_hand_limit"), "CardInventoryRuntimeService retains the complete discardability rule")
	_expect_contract(facade_source.contains("service.call(\"discardable_slots\"") and facade_source.contains("duplicate"), "Coordinator typed facade delegates to the owner and returns a copy")
	_expect_contract(not main_source.contains("func %s(" % retired_main_method) and not bench_source.contains(retired_main_method) and not settlement_source.contains("func discardable_slots("), "Main, Bench and Settlement contain no competing Alpha 0.4 discardability entrypoint")

	_expect_mutation(world_slots == world_before, "projection and query do not mutate world slot input")
	_expect_mutation(facts == facts_before, "owner query does not mutate projected facts")
	_expect_mutation(service_before == service_after, "query does not increment Card Inventory plan or commit counters")
	_expect_mutation(not projection_source.contains("Rng") and not projection_source.contains("rng") and not owner_source.contains("Rng") and not owner_source.contains("rng"), "projection and owner contain no RNG draw path")
	_expect_mutation(not projection_source.contains("print(") and not projection_source.contains("push_") and not projection_source.contains("feedback") and not owner_source.contains("print(") and not owner_source.contains("push_") and not owner_source.contains("feedback"), "projection and owner contain no log or feedback write path")

	var serialized := JSON.stringify({"facts": facts, "slots": discardable})
	_expect_privacy(not serialized.contains("private.queued") and not serialized.contains("private.locked") and not serialized.contains("private.ordinary"), "query output omits concrete private card IDs")
	_expect_privacy(not serialized.contains("runtime_instance_id") and not serialized.contains("card_id") and not serialized.contains("\"card\""), "query output omits private card identity fields")
	_expect_privacy(_data_only(facts) and _data_only(discardable), "projection and query output are pure data")
	_expect_privacy(_all_slot_facts_have_exact_keys(slots), "projection exposes only the approved discardability facts")
	_expect_privacy(not projection_source.contains("name\"") and not projection_source.contains("card_id") and not projection_source.contains("runtime_instance_id"), "projection source does not read or emit card identities")

	hand.queue_free()
	(service as Node).queue_free()
	_finish()


func _card(card_id: String, kind: String, persistent: bool, queued: bool, lock_left: float) -> Dictionary:
	return {
		"name": card_id,
		"kind": kind,
		"persistent": persistent,
		"queued_for_resolution": queued,
		"lock_left": lock_left,
	}


func _slot_matches(slots: Array, index: int, occupied: bool, counted: bool, queued: bool, lock_left: float) -> bool:
	if index < 0 or index >= slots.size() or not (slots[index] is Dictionary):
		return false
	var slot: Dictionary = slots[index]
	return int(slot.get("slot_index", -1)) == index \
		and bool(slot.get("occupied", not occupied)) == occupied \
		and bool(slot.get("counts_toward_hand_limit", not counted)) == counted \
		and bool(slot.get("queued_for_resolution", not queued)) == queued \
		and is_equal_approx(float(slot.get("lock_left", -1.0)), lock_left)


func _all_slot_facts_have_exact_keys(slots: Array) -> bool:
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			return false
		var slot: Dictionary = slot_variant
		if slot.size() != SLOT_FACT_KEYS.size():
			return false
		for key in SLOT_FACT_KEYS:
			if not slot.has(key):
				return false
	return true


func _projection_failed(projection: Dictionary) -> bool:
	return not bool(projection.get("valid", true)) \
		and projection.get("slots", null) is Array \
		and (projection.get("slots", []) as Array).is_empty()


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_instance := source.find("\nfunc ", start + 1)
	var next_static := source.find("\nstatic func ", start + 1)
	var finish := source.length()
	if next_instance >= 0:
		finish = mini(finish, next_instance)
	if next_static >= 0:
		finish = mini(finish, next_static)
	return source.substr(start, finish - start)


func _data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value as Array:
			if not _data_only(item):
				return false
		return true
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if not _data_only(key) or not _data_only((value as Dictionary).get(key)):
				return false
		return true
	return false


func _expect_contract(condition: bool, message: String) -> void:
	_contract_total += 1
	if condition:
		_contract_passed += 1
	else:
		_failures.append(message)


func _expect_mutation(condition: bool, message: String) -> void:
	_mutation_total += 1
	if condition:
		_mutation_passed += 1
	else:
		_failures.append(message)


func _expect_privacy(condition: bool, message: String) -> void:
	_privacy_total += 1
	if condition:
		_privacy_passed += 1
	else:
		_failures.append(message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("CARD_INVENTORY_DISCARDABILITY_TYPED_QUERY_CONTRACT_TEST|status=%s|contract=%d/%d|zero_mutation=%d/%d|privacy=%d/%d|interaction_zero=%d/%d|interaction_stale=%d/%d|interaction_compensation=%d/%d|interaction_disrupt=%d/%d|failures=%d" % [
		status,
		_contract_passed,
		_contract_total,
		_mutation_passed,
		_mutation_total,
		_privacy_passed,
		_privacy_total,
		int(_interaction_passed["zero_candidate"]),
		int(_interaction_total["zero_candidate"]),
		int(_interaction_passed["stale_plan"]),
		int(_interaction_total["stale_plan"]),
		int(_interaction_passed["compensation"]),
		int(_interaction_total["compensation"]),
		int(_interaction_passed["disrupt"]),
		int(_interaction_total["disrupt"]),
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Card Inventory discardability typed query contract failures:\n- " + "\n- ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)

func _test_interaction_plan_matrix(hand: PlayerHandInteractionRuntimeService) -> void:
	var zero_targets := [
		[],
		[null],
		[_interaction_card("private.special", "special", 1, false, 0.0, false)],
		[_interaction_card("private.queued", "queued", 1, true, 0.0, true)],
		[_interaction_card("private.locked", "locked", 1, false, 8.0, true)],
		[
			_interaction_card("private.mix_q", "mix.q", 1, true, 0.0, true),
			_interaction_card("private.mix_l", "mix.l", 1, false, 5.0, true),
			_interaction_card("private.mix_s", "mix.s", 1, false, 0.0, false),
		],
	]
	for index in range(zero_targets.size()):
		var plan := hand.plan_interaction(_interaction_request([], zero_targets[index], _steal_skill()))
		_interaction_expect("zero_candidate", _zero_plan_rejected(plan), "zero target matrix case %d rejects with typed reason" % index)
	var disrupt_plan := hand.plan_interaction(_interaction_request([], [], _disrupt_skill(40, 10.0)))
	_interaction_expect("zero_candidate", _zero_plan_rejected(disrupt_plan), "zero-candidate disrupt rejects before cash or lock planning")
	var valid_plan := hand.plan_interaction(_interaction_request([], [_interaction_card("private.a1", "family.a", 1)], _steal_skill()))
	_interaction_expect("zero_candidate", str(valid_plan.get("status", "")) == "ready" and int(valid_plan.get("operation_count", 0)) == 1 and valid_plan.get("candidate_slots", []) == [0], "ordinary candidate remains ready")
	var bounded_plan := hand.plan_interaction(_interaction_request([], [_interaction_card("private.a1", "family.a", 1)], _steal_skill(2)))
	_interaction_expect("zero_candidate", str(bounded_plan.get("status", "")) == "ready" and int(bounded_plan.get("requested_count", 0)) == 2 and int(bounded_plan.get("operation_count", 0)) == 1, "requested two with one candidate remains bounded to one operation")


func _test_interaction_stale_commit_matrix(hand: PlayerHandInteractionRuntimeService, inventory: CardInventoryRuntimeService) -> void:
	var base_target := [_interaction_card("private.a1", "family.a", 1)]
	var base_request := _interaction_request([], base_target, _steal_skill())
	var stale_targets := [
		[_interaction_card("private.a1", "family.a", 1, true, 0.0, true)],
		[_interaction_card("private.a1", "family.a", 1, false, 8.0, true)],
		[],
	]
	for index in range(stale_targets.size()):
		var plan := _prepared_plan(hand, base_request)
		var actor := _interaction_player([], 100)
		var target := _interaction_player(stale_targets[index], 100)
		var actor_before := actor.duplicate(true)
		var target_before := target.duplicate(true)
		var inventory_before := inventory.debug_snapshot()
		var result := hand.commit_interaction(actor, target, _interaction_request([], stale_targets[index], _steal_skill()), plan)
		var inventory_after := inventory.debug_snapshot()
		_interaction_expect("stale_plan", not bool(result.get("committed", true)) and str(result.get("reason", "")) == "no_discardable_target_cards" and actor == actor_before and target == target_before and int(inventory_after.get("committed_count", 0)) == int(inventory_before.get("committed_count", -1)), "stale candidate case %d rejects before state or inventory commit" % index)
	var malformed_request := _interaction_request([], base_target, _steal_skill())
	var malformed_plan := hand.plan_interaction(malformed_request)
	malformed_plan["selected_slots"] = [999]
	var malformed_actor := _interaction_player([], 100)
	var malformed_target := _interaction_player(base_target, 100)
	var malformed_actor_before := malformed_actor.duplicate(true)
	var malformed_target_before := malformed_target.duplicate(true)
	var malformed_result := hand.commit_interaction(malformed_actor, malformed_target, malformed_request, malformed_plan)
	_interaction_expect("stale_plan", not bool(malformed_result.get("committed", true)) and str(malformed_result.get("reason", "")) == "invalid_slot_selection" and malformed_actor == malformed_actor_before and malformed_target == malformed_target_before, "malformed selected slots fail closed")
	var rejected_request := _interaction_request([], [], _steal_skill())
	var rejected_plan := hand.plan_interaction(rejected_request)
	var rejected_actor := _interaction_player([], 100)
	var rejected_target := _interaction_player([], 100)
	var rejected_result := hand.commit_interaction(rejected_actor, rejected_target, rejected_request, rejected_plan)
	_interaction_expect("stale_plan", not bool(rejected_result.get("committed", true)) and str(rejected_result.get("reason", "")) == "no_discardable_target_cards" and rejected_actor == _interaction_player([], 100) and rejected_target == _interaction_player([], 100), "submitting an already rejected plan remains fail closed")


func _zero_plan_rejected(plan: Dictionary) -> bool:
	return str(plan.get("status", "")) == "rejected" \
		and not bool(plan.get("ready", true)) \
		and str(plan.get("reason", "")) == "no_discardable_target_cards" \
		and int(plan.get("operation_count", -1)) == 0 \
		and int(plan.get("selection_draw_count", -1)) == 0
func _test_interaction_valid_behavior(hand: PlayerHandInteractionRuntimeService, inventory: CardInventoryRuntimeService) -> void:
	hand.reset_state()
	inventory.reset_state()
	var success_request := _interaction_request([], [_interaction_card("private.a1", "family.a", 1)], _steal_skill())
	var success_actor := _interaction_player([], 100)
	var success_target := _interaction_player([_interaction_card("private.a1", "family.a", 1)], 100)
	var success_result := hand.commit_interaction(success_actor, success_target, success_request, _prepared_plan(hand, success_request))
	_interaction_expect("compensation", bool(success_result.get("committed", false)) and bool(success_result.get("resolution_success", false)) and int(success_result.get("transferred_count", 0)) == 1 and int(success_result.get("converted_count", 0)) == 0 and int(success_result.get("compensation_paid", -1)) == 0 and success_actor.get("slots", []).size() == 1 and success_target.get("slots", []) == [null], "valid steal transfers one card and pays no compensation")

	hand.reset_state()
	inventory.reset_state()
	var conversion_actor_cards := [_interaction_card("private.a4", "family.a", 4)]
	var conversion_target_cards := [_interaction_card("private.a1", "family.a", 1)]
	var conversion_request := _interaction_request(conversion_actor_cards, conversion_target_cards, _steal_skill())
	var conversion_actor := _interaction_player(conversion_actor_cards, 100)
	var conversion_target := _interaction_player(conversion_target_cards, 100)
	var conversion_result := hand.commit_interaction(conversion_actor, conversion_target, conversion_request, _prepared_plan(hand, conversion_request))
	_interaction_expect("compensation", bool(conversion_result.get("committed", false)) and int(conversion_result.get("converted_count", 0)) == 1 and int(conversion_result.get("transferred_count", 0)) == 0 and int(conversion_result.get("compensation_paid", 0)) == 60 and int(conversion_result.get("actor_cash_delta", 0)) == 60 and conversion_actor.get("slots", []).size() == 1 and conversion_target.get("slots", []) == [null], "unreceivable real card converts to removal and pays one existing compensation")

	hand.reset_state()
	inventory.reset_state()
	var mixed_target_cards := [_interaction_card("private.a1", "family.a", 1), _interaction_card("private.b1", "family.b", 1)]
	var mixed_request := _interaction_request(conversion_actor_cards, mixed_target_cards, _steal_skill(2))
	var mixed_actor := _interaction_player(conversion_actor_cards, 100)
	var mixed_target := _interaction_player(mixed_target_cards, 100)
	var mixed_result := hand.commit_interaction(mixed_actor, mixed_target, mixed_request, _prepared_plan(hand, mixed_request))
	_interaction_expect("compensation", bool(mixed_result.get("committed", false)) and int(mixed_result.get("converted_count", 0)) == 1 and int(mixed_result.get("transferred_count", 0)) == 1 and int(mixed_result.get("compensation_paid", 0)) == 60 and int(mixed_result.get("actor_cash_delta", 0)) == 60, "mixed multi-card steal preserves one-time compensation")

	var hand_interaction_source := FileAccess.get_file_as_string(HAND_INTERACTION_SOURCE_PATH)
	_interaction_expect("compensation", hand_interaction_source.contains("interaction_kind == KIND_STEAL and converted_count > 0") and not hand_interaction_source.contains("transferred_count <= 0"), "compensation source requires a real converted removal")

	hand.reset_state()
	inventory.reset_state()
	var disrupt_target_cards := [_interaction_card("private.b1", "family.b", 1)]
	var disrupt_request := _interaction_request([], disrupt_target_cards, _disrupt_skill(40))
	var disrupt_actor := _interaction_player([], 100)
	var disrupt_target := _interaction_player(disrupt_target_cards, 100)
	var disrupt_result := hand.commit_interaction(disrupt_actor, disrupt_target, disrupt_request, _prepared_plan(hand, disrupt_request))
	_interaction_expect("disrupt", bool(disrupt_result.get("committed", false)) and int(disrupt_result.get("removed_count", 0)) == 1 and int(disrupt_result.get("penalty_paid", 0)) == 40 and int(disrupt_result.get("target_cash_delta", 0)) == -40 and disrupt_target.get("slots", []) == [null], "valid disrupt removes one card before applying the existing penalty")

	hand.reset_state()
	inventory.reset_state()
	var limited_target := _interaction_player(disrupt_target_cards, 25)
	var limited_result := hand.commit_interaction(_interaction_player([], 100), limited_target, disrupt_request, _prepared_plan(hand, disrupt_request))
	_interaction_expect("disrupt", int(limited_result.get("removed_count", 0)) == 1 and int(limited_result.get("penalty_paid", 0)) == 25 and int(limited_target.get("cash", -1)) == 0 and int(limited_target.get("cash_cents", -1)) == 0, "disrupt penalty remains capped by available target cash")

	hand.reset_state()
	inventory.reset_state()
	var lock_targets := [_interaction_card("private.a1", "family.a", 1), _interaction_card("private.b1", "family.b", 1)]
	var lock_request := _interaction_request([], lock_targets, _disrupt_skill(40, 10.0))
	var lock_target := _interaction_player(lock_targets, 100)
	var lock_result := hand.commit_interaction(_interaction_player([], 100), lock_target, lock_request, _prepared_plan(hand, lock_request))
	var locked_cards := 0
	for card_variant in lock_target.get("slots", []):
		if card_variant is Dictionary and float((card_variant as Dictionary).get("lock_left", 0.0)) > 0.0:
			locked_cards += 1
	_interaction_expect("disrupt", int(lock_result.get("removed_count", 0)) == 1 and int(lock_result.get("locked_count", 0)) == 1 and locked_cards == 1, "higher-rank lock remains after one successful primary removal")
	_interaction_expect("disrupt", hand_interaction_source.contains("interaction_kind == KIND_DISRUPT and removed_count > 0 and penalty_requested > 0") and hand_interaction_source.contains("removed_count > 0 or locked_count > 0 or penalty_paid > 0"), "disrupt source gates cash and success on actual effects")


func _prepared_plan(hand: PlayerHandInteractionRuntimeService, request: Dictionary) -> Dictionary:
	var plan := hand.plan_interaction(request)
	if str(plan.get("status", "")) != "ready":
		return plan
	var candidates: Array = plan.get("candidate_slots", []) if plan.get("candidate_slots", []) is Array else []
	plan["selected_slots"] = candidates.slice(0, int(plan.get("selection_draw_count", 0)))
	return plan


func _interaction_request(actor_cards: Array, target_cards: Array, skill: Dictionary) -> Dictionary:
	var catalog := _interaction_catalog(actor_cards + target_cards)
	return {
		"actor_player_index": 0,
		"target_player_index": 1,
		"skill": skill.duplicate(true),
		"actor_inventory": _interaction_inventory(actor_cards, catalog),
		"target_inventory": _interaction_inventory(target_cards, catalog),
		"card_catalog": catalog,
	}


func _interaction_catalog(cards: Array) -> Dictionary:
	var result := {}
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant
		var card_id := str(card.get("name", ""))
		result[card_id] = {
			"family": str(card.get("family_id", card_id)),
			"rank": int(card.get("rank", 1)),
			"counts_toward_hand_limit": bool(card.get("counts_toward_hand_limit", true)),
			"next_upgrade_id": "",
			"next_upgrade_card": {},
		}
	return result


func _interaction_inventory(cards: Array, catalog: Dictionary) -> Dictionary:
	var slots: Array = []
	var counted := 0
	for index in range(cards.size()):
		var value: Variant = cards[index]
		if not (value is Dictionary):
			slots.append({"slot_index": index, "occupied": false})
			continue
		var card: Dictionary = value
		var card_id := str(card.get("name", ""))
		var metadata: Dictionary = catalog.get(card_id, {}) if catalog.get(card_id, {}) is Dictionary else {}
		var counts := bool(metadata.get("counts_toward_hand_limit", true))
		if counts:
			counted += 1
		slots.append({
			"slot_index": index,
			"occupied": true,
			"card_id": card_id,
			"family": str(metadata.get("family", card_id)),
			"rank": int(metadata.get("rank", 1)),
			"counts_toward_hand_limit": counts,
			"queued_for_resolution": bool(card.get("queued_for_resolution", false)),
			"lock_left": float(card.get("lock_left", 0.0)),
			"next_upgrade_id": "",
			"next_upgrade_card": {},
		})
	return {"valid": false, "counted_hand_size": counted, "hand_limit": 5, "discard_slot": -1, "slots": slots}
func _interaction_player(cards: Array, cash: int) -> Dictionary:
	return {
		"name": "fixture",
		"cash": cash,
		"cash_cents": cash * 100,
		"slots": cards.duplicate(true),
		"economic_ledger": [],
		"cash_history": [cash],
		"eliminated": false,
	}


func _interaction_card(card_id: String, family: String, rank: int, queued: bool = false, lock_left: float = 0.0, counted: bool = true) -> Dictionary:
	return {
		"name": card_id,
		"family_id": family,
		"rank": rank,
		"kind": "facility",
		"persistent": not counted,
		"counts_toward_hand_limit": counted,
		"queued_for_resolution": queued,
		"lock_left": lock_left,
	}


func _steal_skill(count: int = 1, lock_seconds: float = 0.0) -> Dictionary:
	return {
		"name": "影仓牵引",
		"kind": "player_hand_steal",
		"hand_steal_count": count,
		"hand_lock_seconds": lock_seconds,
		"steal_fail_cash": 60,
	}


func _disrupt_skill(penalty: int = 40, lock_seconds: float = 0.0) -> Dictionary:
	return {
		"name": "星链拆解",
		"kind": "player_hand_disrupt",
		"hand_discard_count": 1,
		"hand_lock_seconds": lock_seconds,
		"target_cash_penalty": penalty,
	}


func _interaction_expect(category: String, condition: bool, message: String) -> void:
	_interaction_total[category] = int(_interaction_total.get(category, 0)) + 1
	if condition:
		_interaction_passed[category] = int(_interaction_passed.get(category, 0)) + 1
	else:
		_failures.append(message)
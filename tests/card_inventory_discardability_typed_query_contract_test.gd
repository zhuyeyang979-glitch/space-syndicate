extends Node

const SERVICE_SCRIPT := preload("res://scripts/runtime/card_inventory_runtime_service.gd")
const SERVICE_SOURCE_PATH := "res://scripts/runtime/card_inventory_runtime_service.gd"
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
	print("CARD_INVENTORY_DISCARDABILITY_TYPED_QUERY_CONTRACT_TEST|status=%s|contract=%d/%d|zero_mutation=%d/%d|privacy=%d/%d|failures=%d" % [
		status,
		_contract_passed,
		_contract_total,
		_mutation_passed,
		_mutation_total,
		_privacy_passed,
		_privacy_total,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Card Inventory discardability typed query contract failures:\n- " + "\n- ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)

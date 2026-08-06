extends SceneTree

const RuntimeOwner := preload(
	"res://scripts/v075_runtime/v075_runtime_owner.gd"
)
const CombatOwner := preload(
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)
const Registry := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)

const PLAYER_COUNT := 8
const MATCH_SEED := 901626424
const MAP_SEED := 900626424
const MAX_LIFECYCLE_BATCHES := 10
const MAX_ACTIONS_TO_DRAW := 5

var _checks := 0
var _failures: Array[String] = []
var _runtime_faults: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("V075_COMBAT_DBG_PERSONAL_LIFECYCLE_PROGRESS|create_runtime")
	var host := Node.new()
	root.add_child(host)
	var runtime := RuntimeOwner.new()
	var combat := CombatOwner.new()
	host.add_child(runtime)
	host.add_child(combat)
	runtime.runtime_fault.connect(_on_runtime_fault)

	var bound := runtime.bind_combat_owner(combat)
	_expect(
		bool(bound.get("accepted", false)),
		"production RuntimeOwner binds exactly one combat owner"
	)
	if not bool(bound.get("accepted", false)):
		_finish()
		return

	var started := runtime.start_new_game(
		PLAYER_COUNT,
		MATCH_SEED,
		true,
		false,
		{
			"map_seed": MAP_SEED,
			"region_count": 8,
			"geography_complexity": "SIMPLE",
			"land_ocean_profile": "BALANCED",
		}
	)
	print("V075_COMBAT_DBG_PERSONAL_LIFECYCLE_PROGRESS|started=%s" % bool(started.get("accepted", false)))
	_expect(
		bool(started.get("accepted", false)),
		"production V075 game starts for the natural DBG lifecycle"
	)
	if not bool(started.get("accepted", false)):
		_finish()
		return

	var track_choice := _find_combat_track_item(runtime)
	print("V075_COMBAT_DBG_PERSONAL_LIFECYCLE_PROGRESS|track_choice=%s" % JSON.stringify(track_choice))
	_expect(
		not track_choice.is_empty(),
		"a claimable monster or military normal card is visible on the real track"
	)
	if track_choice.is_empty():
		_print_diagnostic(runtime, {})
		_finish()
		return

	var owner_id := str(track_choice.get("owner_player_id", ""))
	var track_instance_id := str(track_choice.get("track_instance_id", ""))
	var definition_id := str(track_choice.get("definition_id", ""))
	var before_facts := _runtime_dbg_facts(runtime, owner_id)
	var before_discard_ids := _zone_ids(before_facts.get("discard", []) as Array)
	_expect(
		not owner_id.is_empty() and not track_instance_id.is_empty(),
		"track choice has an owner and a source instance identity"
	)
	_expect(
		not before_facts.is_empty(),
		"owner personal DBG projection is available before purchase"
	)

	var purchase := runtime.acquire_track_item(owner_id, track_instance_id)
	print("V075_COMBAT_DBG_PERSONAL_LIFECYCLE_PROGRESS|purchase=%s" % JSON.stringify(purchase))
	_expect(
		bool(purchase.get("accepted", false))
			and str(purchase.get("destination_zone", "")) == "personal_discard",
		"real track acquisition places the combat card in personal discard"
	)
	if not bool(purchase.get("accepted", false)):
		_print_diagnostic(runtime, track_choice)
		_finish()
		return

	var after_purchase_facts := _runtime_dbg_facts(runtime, owner_id)
	var after_purchase_discard := after_purchase_facts.get("discard", []) as Array
	var created_ids := _new_ids(before_discard_ids, after_purchase_discard)
	_expect(
		created_ids.size() == 1,
		"purchase creates exactly one new personal DBG card instance"
	)
	if created_ids.size() != 1:
		_print_diagnostic(runtime, track_choice)
		_finish()
		return

	var personal_instance_id := str(created_ids[0])
	var purchased_card := _card_by_id(after_purchase_discard, personal_instance_id)
	_expect(
		personal_instance_id != track_instance_id,
		"personal DBG instance is distinct from the removed sushi-track instance"
	)
	_expect(
		personal_instance_id != ""
			and personal_instance_id != track_instance_id
			and not before_discard_ids.has(personal_instance_id),
		"new card identity is allocated by DBG after purchase, not injected"
	)
	_expect(
		str(purchased_card.get("definition_id", "")) == definition_id
			and str(purchased_card.get("instance_id", "")) == personal_instance_id,
		"personal discard preserves the authored combat definition and new ID"
	)
	_expect(
		not _zone_has_id(after_purchase_facts.get("hand", []) as Array, track_instance_id)
			and not _zone_has_id(after_purchase_discard, track_instance_id),
		"the consumed track instance ID does not enter the personal DBG"
	)

	var reshuffle_observed := false
	var found_in_hand := false
	for _batch_index in range(MAX_LIFECYCLE_BATCHES):
		print("V075_COMBAT_DBG_PERSONAL_LIFECYCLE_PROGRESS|batch=%d|phase=%s" % [_batch_index + 1, runtime.phase()])
		var current_facts := _runtime_dbg_facts(runtime, owner_id)
		if _zone_has_id(current_facts.get("hand", []) as Array, personal_instance_id):
			found_in_hand = true
			break
		var batch_result := _advance_natural_batch(
			runtime,
			runtime.player_ids(),
			owner_id,
			personal_instance_id
		)
		print("V075_COMBAT_DBG_PERSONAL_LIFECYCLE_PROGRESS|batch_result=%s" % JSON.stringify(batch_result))
		_expect(
			bool(batch_result.get("accepted", false)),
			"natural batch %d advances through production DBG and runtime authorities"
			% (_batch_index + 1)
		)
		reshuffle_observed = reshuffle_observed or bool(
			batch_result.get("reshuffle_observed", false)
		)
		if not bool(batch_result.get("accepted", false)):
			break
		var next_facts := _runtime_dbg_facts(runtime, owner_id)
		if _zone_has_id(next_facts.get("hand", []) as Array, personal_instance_id):
			found_in_hand = true
			break

	_expect(
		reshuffle_observed,
		"personal DBG naturally reshuffles its discard before drawing the purchase"
	)
	_expect(
		found_in_hand,
		"the same personal DBG instance is naturally drawn into the hand"
	)

	if found_in_hand:
		print("V075_COMBAT_DBG_PERSONAL_LIFECYCLE_PROGRESS|legal_action_lookup")
		var legal := runtime.legal_card_actions(owner_id)
		var option := _legal_option_for_card(legal, personal_instance_id)
		_expect(
			not option.is_empty(),
			"drawn combat card exposes a legal authoritative target option"
		)
		if not option.is_empty():
			var queued := runtime.queue_card_action(
				owner_id,
				personal_instance_id,
				str(option.get("target_slot_id", "")),
				option
			)
			_expect(
				bool(queued.get("accepted", false)),
				"drawn combat card enters a legal prebound action queue"
			)
			var binding := queued.get("binding", {}) as Dictionary
			_expect(
				str(binding.get("card_instance_id", "")) == personal_instance_id
					and str(binding.get("target_slot_id", ""))
						== str(option.get("target_slot_id", ""))
					and bool(binding.get("target_bound", false)),
				"prebound action keeps the DBG instance and legal target identity"
			)

	var final_debug := runtime.debug_snapshot()
	_expect(
		int(final_debug.get("runtime_error_count", 0)) == 0,
		"natural personal DBG lifecycle introduces no runtime errors"
	)
	_expect(
		_runtime_faults.is_empty(),
		"natural personal DBG lifecycle emits no runtime fault receipt"
	)
	if not found_in_hand or not reshuffle_observed:
		_print_diagnostic(runtime, track_choice)
	_finish()


func _find_combat_track_item(runtime: RuntimeOwner) -> Dictionary:
	var military_fallback: Dictionary = {}
	for actor_variant in runtime.player_ids():
		var actor_id := str(actor_variant)
		var track := runtime.call(
			"_v075_track_projection",
			actor_id
		) as Dictionary
		var private_facts := track.get("viewer_private_facts", {}) as Dictionary
		for item_variant in private_facts.get("own_segment_items", []) as Array:
			var item := item_variant as Dictionary
			if (
				not bool(item.get("claimable", false))
				or str(item.get("card_kind", "")) != "normal_card"
			):
				continue
			var definition := Registry.definition(
				str(item.get("card_definition_id", ""))
			)
			var domain := Registry.card_domain(str(definition.get("card_type", "")))
			if domain not in ["monster", "military"]:
				continue
			var row := {
				"owner_player_id": actor_id,
				"track_instance_id": str(item.get("instance_id", "")),
				"definition_id": str(item.get("card_definition_id", "")),
				"domain": domain,
				"primary_color": str(item.get("primary_color", "")),
			}
			if domain == "monster":
				return row
			if military_fallback.is_empty():
				military_fallback = row
	return military_fallback


func _advance_natural_batch(
	runtime: RuntimeOwner,
	roster: Array,
	owner_id: String,
	target_instance_id: String
) -> Dictionary:
	var before_facts := _runtime_dbg_facts(runtime, owner_id)
	var before_draw_count := int(before_facts.get("draw_pile_count", 0))
	var before_discard_count := int(before_facts.get("discard_count", 0))
	_queue_zero_cost_facility_cards(runtime, owner_id, target_instance_id)

	for actor_variant in roster:
		var actor_id := str(actor_variant)
		var locked := runtime.lock_player_submission(actor_id)
		if not bool(locked.get("accepted", false)):
			return {
				"accepted": false,
				"reason_code": "natural_submission_lock_failed",
				"actor_id": actor_id,
				"receipt": locked,
			}

	var resolution_steps := 0
	while runtime.phase() == "resolving":
		var resolved := runtime.resolve_next_action()
		if not bool(resolved.get("accepted", false)):
			return {
				"accepted": false,
				"reason_code": "natural_resolution_failed",
				"receipt": resolved,
			}
		resolution_steps += 1
		if resolution_steps > 64:
			return {
				"accepted": false,
				"reason_code": "natural_resolution_step_guard",
			}

	var after_resolution_facts := _runtime_dbg_facts(runtime, owner_id)
	var after_draw_count := int(after_resolution_facts.get("draw_pile_count", 0))
	var reshuffle_observed := (
		before_discard_count > 0
		and after_draw_count > before_draw_count
	)

	if runtime.phase() == "maintenance":
		for actor_variant in roster:
			var finished := runtime.finish_maintenance(str(actor_variant))
			# The DBG refill can exhaust and reshuffle during this same
			# maintenance receipt. Observe the authoritative count instead of
			# inferring it from the batch-start pile sizes.
			reshuffle_observed = reshuffle_observed or int(
				finished.get("reshuffle_count", 0)
			) > 0
			if not bool(finished.get("success", finished.get("accepted", false))):
				return {
					"accepted": false,
					"reason_code": "natural_maintenance_failed",
					"receipt": finished,
				}
	elif runtime.phase() == "failed":
		return {
			"accepted": false,
			"reason_code": "runtime_failed_during_natural_batch",
		}

	return {
		"accepted": true,
		"reshuffle_observed": reshuffle_observed,
		"before_draw_count": before_draw_count,
		"after_draw_count": after_draw_count,
		"before_discard_count": before_discard_count,
		"phase": runtime.phase(),
	}


func _queue_zero_cost_facility_cards(
	runtime: RuntimeOwner,
	owner_id: String,
	target_instance_id: String
) -> void:
	var used_cards: Dictionary = {}
	var used_slots: Dictionary = {}
	var queued_count := 0
	var facts := _runtime_dbg_facts(runtime, owner_id)
	for card_variant in facts.get("hand", []) as Array:
		if queued_count >= MAX_ACTIONS_TO_DRAW:
			break
		var card := card_variant as Dictionary
		var card_id := str(card.get("instance_id", ""))
		if (
			Registry.card_domain(str(card.get("card_type", ""))) != "facility"
			or card_id.is_empty()
			or card_id == target_instance_id
			or used_cards.has(card_id)
			or int(card.get("primary_asset_cost", 0)) != 0
		):
			continue
		var slots := runtime.call(
			"_legal_slots_for_card",
			owner_id,
			card
		) as Array
		for slot_variant in slots:
			if queued_count >= MAX_ACTIONS_TO_DRAW:
				break
			var slot := slot_variant as Dictionary
			var slot_id := str(slot.get("slot_id", ""))
			if slot_id.is_empty() or used_slots.has(slot_id):
				continue
			var queued := runtime.queue_card_action(
				owner_id,
				card_id,
				slot_id
			)
			if bool(queued.get("accepted", false)):
				used_cards[card_id] = true
				used_slots[slot_id] = true
				queued_count += 1
				break


func _legal_option_for_card(legal: Array, card_instance_id: String) -> Dictionary:
	for option_variant in legal:
		var option := option_variant as Dictionary
		if (
			str(option.get("card_instance_id", "")) == card_instance_id
			and str(option.get("action_domain", "")) in ["monster", "military"]
			and not str(option.get("target_slot_id", "")).is_empty()
		):
			return option.duplicate(true)
	return {}


func _runtime_dbg_facts(runtime: RuntimeOwner, owner_id: String) -> Dictionary:
	var projection := runtime.call("_dbg_projection", owner_id) as Dictionary
	return (projection.get("facts", {}) as Dictionary).duplicate(true)


func _zone_ids(zone: Array) -> Dictionary:
	var result: Dictionary = {}
	for card_variant in zone:
		var card := card_variant as Dictionary
		var instance_id := str(card.get("instance_id", ""))
		if not instance_id.is_empty():
			result[instance_id] = true
	return result


func _new_ids(before_ids: Dictionary, after_zone: Array) -> Array:
	var result: Array = []
	for instance_id_variant in _zone_ids(after_zone).keys():
		var instance_id := str(instance_id_variant)
		if not before_ids.has(instance_id):
			result.append(instance_id)
	return result


func _zone_has_id(zone: Array, instance_id: String) -> bool:
	return _zone_ids(zone).has(instance_id)


func _card_by_id(zone: Array, instance_id: String) -> Dictionary:
	for card_variant in zone:
		var card := card_variant as Dictionary
		if str(card.get("instance_id", "")) == instance_id:
			return card.duplicate(true)
	return {}


func _on_runtime_fault(receipt: Dictionary) -> void:
	_runtime_faults.append(receipt.duplicate(true))


func _print_diagnostic(runtime: RuntimeOwner, track_choice: Dictionary) -> void:
	print("V075_COMBAT_DBG_PERSONAL_LIFECYCLE_DIAGNOSTIC|%s" % JSON.stringify({
		"track_choice": track_choice,
		"phase": runtime.phase(),
		"fault_count": _runtime_faults.size(),
		"debug": runtime.debug_snapshot(),
	}))


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("V075_COMBAT_DBG_PERSONAL_LIFECYCLE_TEST|FAIL|%s" % message)


func _finish() -> void:
	print(
		"V075_COMBAT_DBG_PERSONAL_LIFECYCLE_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)

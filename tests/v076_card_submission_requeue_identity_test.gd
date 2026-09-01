extends SceneTree

const RuntimeOwner := preload(
	"res://scripts/v073_runtime/v073_sample_runtime_owner.gd"
)

const MATCH_SEED := 730045

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime := RuntimeOwner.new()
	root.add_child(runtime)
	var started := runtime.start_new_game(3, MATCH_SEED, false, false)
	runtime.set_process(false)
	_expect(
		bool(started.get("accepted", false)),
		"production V073 runtime starts for the queue identity regression: %s"
		% JSON.stringify(started)
	)
	if not bool(started.get("accepted", false)):
		_finish()
		return

	var actor_id := runtime.local_player_id()
	var legal := runtime.legal_card_actions(actor_id)
	_expect(not legal.is_empty(), "local player has a natural legal card action")
	if legal.is_empty():
		_finish()
		return
	var option := legal[0] as Dictionary
	var card_instance_id := str(option.get("card_instance_id", ""))
	var target_slot_id := str(option.get("target_slot_id", ""))
	var initial_state := _dbg_state(runtime, actor_id)
	var initial_revision := int(initial_state.get("revision", -1))
	_expect(
		_authority_zone(initial_state, card_instance_id) == "hand"
		and _zone_occurrence_count(initial_state, card_instance_id) == 1,
		"selected card begins in exactly one authoritative hand zone"
	)

	var first_queue := runtime.queue_card_action(
		actor_id,
		card_instance_id,
		target_slot_id
	)
	var first_binding := first_queue.get("binding", {}) as Dictionary
	var first_action_id := str(first_binding.get("action_id", ""))
	var first_reserve_id := str(first_binding.get(
		"card_reservation_request_id",
		""
	))
	var first_queued_state := _dbg_state(runtime, actor_id)
	_expect(
		bool(first_queue.get("accepted", false))
		and not first_action_id.is_empty()
		and not first_reserve_id.is_empty(),
		"first queue allocates an action and exact-once reserve identity"
	)
	_expect(
		_authority_zone(first_queued_state, card_instance_id)
			== "committed_escrow"
		and _zone_occurrence_count(first_queued_state, card_instance_id) == 1,
		"accepted first queue moves the same instance hand to committed escrow"
	)

	var removed := runtime.remove_queued_action(actor_id, first_action_id)
	var released_state := _dbg_state(runtime, actor_id)
	var first_release_id := "intent.release.%s" % first_action_id
	_expect(
		bool(removed.get("accepted", false)),
		"removing the first queued action releases its reservation"
	)
	_expect(
		_authority_zone(released_state, card_instance_id) == "hand"
		and _zone_occurrence_count(released_state, card_instance_id) == 1,
		"remove returns the identical escrow instance to exactly one hand zone"
	)

	var second_queue := runtime.queue_card_action(
		actor_id,
		card_instance_id,
		target_slot_id
	)
	var second_binding := second_queue.get("binding", {}) as Dictionary
	var second_action_id := str(second_binding.get("action_id", ""))
	var second_reserve_id := str(second_binding.get(
		"card_reservation_request_id",
		""
	))
	var second_queued_state := _dbg_state(runtime, actor_id)
	_expect(
		bool(second_queue.get("accepted", false))
		and second_action_id != first_action_id
		and second_reserve_id != first_reserve_id,
		"remove then requeue allocates fresh monotonic action and reserve identities"
	)
	_expect(
		_authority_zone(second_queued_state, card_instance_id)
			== "committed_escrow"
		and _zone_occurrence_count(second_queued_state, card_instance_id) == 1,
		"requeue performs a new hand to escrow mutation without a multi-zone card"
	)
	var journal := second_queued_state.get("receipt_journal", {}) as Dictionary
	_expect(
		journal.has(first_reserve_id)
		and journal.has(first_release_id)
		and journal.has(second_reserve_id)
		and int(second_queued_state.get("revision", -1)) == initial_revision + 3,
		"reserve release reserve are three distinct exact-once DBG commits"
	)

	var before_stale_remove := second_queued_state.duplicate(true)
	var stale_remove := runtime.remove_queued_action(actor_id, first_action_id)
	var after_stale_remove := _dbg_state(runtime, actor_id)
	_expect(
		not bool(stale_remove.get("accepted", true))
		and after_stale_remove == before_stale_remove,
		"replaying the removed action identity cannot release the new reservation"
	)

	var final_remove := runtime.remove_queued_action(actor_id, second_action_id)
	var final_state := _dbg_state(runtime, actor_id)
	_expect(
		bool(final_remove.get("accepted", false))
		and _authority_zone(final_state, card_instance_id) == "hand"
		and _zone_occurrence_count(final_state, card_instance_id) == 1,
		"fresh requeue identity releases exactly once and restores the hand"
	)

	runtime.queue_free()
	_finish()


func _dbg_state(runtime: Node, actor_id: String) -> Dictionary:
	var owners := runtime.get("_dbg_by_player") as Dictionary
	var dbg := owners.get(actor_id) as RefCounted
	if dbg == null:
		return {}
	var authority := dbg.call("core_authority_snapshot") as Dictionary
	return (authority.get("state", {}) as Dictionary).duplicate(true)


func _authority_zone(state: Dictionary, card_instance_id: String) -> String:
	for zone_name in ["draw_pile", "hand", "committed_escrow", "discard"]:
		for card_variant in state.get(zone_name, []) as Array:
			if str((card_variant as Dictionary).get("instance_id", "")) \
					== card_instance_id:
				return zone_name
	return ""


func _zone_occurrence_count(
	state: Dictionary,
	card_instance_id: String
) -> int:
	var count := 0
	for zone_name in ["draw_pile", "hand", "committed_escrow", "discard"]:
		for card_variant in state.get(zone_name, []) as Array:
			if str((card_variant as Dictionary).get("instance_id", "")) \
					== card_instance_id:
				count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print(
		"V076_CARD_SUBMISSION_REQUEUE_IDENTITY_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)

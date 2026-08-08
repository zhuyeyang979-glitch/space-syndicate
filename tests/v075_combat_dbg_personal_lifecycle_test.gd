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
const DbgCore := preload(
	"res://scripts/v07_semantic/v07_dbg_deck_core.gd"
)
const PublicActionBatchCore := preload(
	"res://scripts/v075/runtime/v075_public_action_batch_core.gd"
)
const CombatDamageCore := preload(
	"res://scripts/v075/combat/v075_combat_damage_core.gd"
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
	var effect_witness_source_id := ""
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
	_expect(
		str(track_choice.get("domain", "")) == "monster",
		"fixed lifecycle fixture selects a real monster card for deploy/refresh gates"
	)
	if str(track_choice.get("domain", "")) != "monster":
		_print_diagnostic(runtime, track_choice)
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
		var option := _legal_option_for_card(
			legal,
			personal_instance_id,
			"DEPLOY_NEW"
		)
		_expect(
			not option.is_empty(),
			"drawn monster card exposes a legal authoritative deploy option"
		)
		if not option.is_empty():
			var canonical_card_binding := runtime.call(
				"_authoritative_card_action_binding",
				owner_id,
				personal_instance_id
			) as Dictionary
			var option_card_binding := (
				option.get("card_action_binding", {}) as Dictionary
			)
			_expect(
				not canonical_card_binding.is_empty()
				and option_card_binding == canonical_card_binding
				and str(option_card_binding.get("owner_player_id", ""))
					== owner_id
				and str(option_card_binding.get("card_instance_id", ""))
					== personal_instance_id
				and str(option_card_binding.get("card_definition_id", ""))
					== definition_id
				and str(option_card_binding.get("authoritative_zone", ""))
					== "hand",
				"AI/player legal option carries the exact live DBG binding"
			)
			var missing_binding_option := option.duplicate(true)
			missing_binding_option.erase("card_action_binding")
			var missing_binding_queue := runtime.queue_card_action(
				owner_id,
				personal_instance_id,
				str(option.get("target_slot_id", "")),
				missing_binding_option
			)
			_expect(
				not bool(missing_binding_queue.get("accepted", true))
				and str(missing_binding_queue.get("reason_code", ""))
					== "combat_target_binding_invalid_or_stale"
				and (_queued_rows(runtime, owner_id)).is_empty()
				and _zone_has_id(
					_runtime_dbg_facts(runtime, owner_id).get("hand", []) as Array,
					personal_instance_id
				),
				"queue gate rejects a missing binding with zero ownership mutation"
			)
			var forged_binding_option := option.duplicate(true)
			var forged_card_binding := option_card_binding.duplicate(true)
			forged_card_binding["binding_fingerprint"] = "0".repeat(64)
			forged_binding_option["card_action_binding"] = forged_card_binding
			var forged_binding_queue := runtime.queue_card_action(
				owner_id,
				personal_instance_id,
				str(option.get("target_slot_id", "")),
				forged_binding_option
			)
			_expect(
				not bool(forged_binding_queue.get("accepted", true))
				and str(forged_binding_queue.get("reason_code", ""))
					== "combat_target_binding_invalid_or_stale"
				and (_queued_rows(runtime, owner_id)).is_empty(),
				"queue gate rejects a forged binding with zero queued action"
			)
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
				and bool(binding.get("target_bound", false))
				and binding.get("card_action_binding")
					== canonical_card_binding,
				"prebound action keeps the DBG instance and legal target identity"
			)
			var accepted_queues := (
				runtime.get("_queued_by_player") as Dictionary
			).duplicate(true)
			var forged_queues := accepted_queues.duplicate(true)
			var forged_rows := forged_queues.get(owner_id, []) as Array
			var forged_row := (forged_rows[0] as Dictionary).duplicate(true)
			var forged_lock_binding := (
				forged_row.get("card_action_binding", {}) as Dictionary
			).duplicate(true)
			forged_lock_binding["zone_revision"] = int(
				forged_lock_binding.get("zone_revision", 0)
			) + 1
			forged_row["card_action_binding"] = forged_lock_binding
			forged_rows[0] = forged_row
			forged_queues[owner_id] = forged_rows
			runtime.set("_queued_by_player", forged_queues)
			var lock_state_before := _identity_gate_state(
				runtime,
				combat,
				owner_id
			)
			var rollback_count_before := int(runtime.debug_snapshot().get(
				"submission_transaction_rollback_count",
				0
			))
			var forged_lock := runtime.lock_player_submission(owner_id)
			_expect(
				not bool(forged_lock.get("accepted", true))
				and str(forged_lock.get("reason_code", ""))
					== "prebound_action_build_failed"
				and int(runtime.debug_snapshot().get(
					"submission_transaction_rollback_count",
					0
				)) == rollback_count_before + 1
				and _identity_gate_state(runtime, combat, owner_id)
					== lock_state_before,
				"lock gate revalidates the live binding and rolls back without partial effects"
			)
			runtime.set("_queued_by_player", accepted_queues)
			var all_locked := _lock_all_players(runtime)
			_expect(
				all_locked
				and runtime.phase() == "resolving",
				"canonical binding locks through the production submission boundary"
			)
			if all_locked and runtime.phase() == "resolving":
				var play_count_before := _dbg_play_receipt_count(
					runtime,
					owner_id,
					personal_instance_id
				)
				var public_monster_count_before := (
					combat.public_monsters() as Array
				).size()
				var resolved := runtime.resolve_next_action()
				var facts_after_success := _runtime_dbg_facts(
					runtime,
					owner_id
				)
				_expect(
					bool(resolved.get("accepted", false))
					and str(resolved.get("outcome_id", ""))
						== "monster_action_resolved"
					and str(resolved.get("normal_card_destination", ""))
						== "discard"
					and _dbg_play_receipt_count(
						runtime,
						owner_id,
						personal_instance_id
					) == play_count_before + 1
					and _normal_card_occurrence_count(
						facts_after_success,
						personal_instance_id
					) == 1
					and (combat.public_monsters() as Array).size()
						== public_monster_count_before + 1,
					"successful deploy completes exactly one DBG lifecycle into personal discard"
				)
				if bool(resolved.get("accepted", false)):
					var combat_public_result := (
						resolved.get("combat_public_result", {}) as Dictionary
					)
					var deployed_source_id := str(combat_public_result.get(
						"source_instance_id",
						""
					))
					effect_witness_source_id = deployed_source_id
					var damaged := _damage_monster_for_refresh(
						combat,
						deployed_source_id,
						"after.deploy"
					)
					_expect(
						bool(damaged.get("accepted", false)),
						"typed combat damage creates a real refresh target"
					)
					var maintenance := _finish_all_maintenance(runtime)
					_expect(
						bool(maintenance.get("accepted", false)),
						"post-deploy maintenance returns to submission"
					)
					var redraw := _await_card_redraw(
						runtime,
						owner_id,
						personal_instance_id,
						bool(maintenance.get("reshuffle_observed", false))
					)
					_expect(
						bool(redraw.get("found", false))
						and bool(redraw.get("reshuffle_observed", false)),
						"the deployed card naturally reshuffles and redraws for a second lifecycle"
					)
					if bool(redraw.get("found", false)):
						var refreshed_damage := _damage_monster_for_refresh(
							combat,
							deployed_source_id,
							"before.refresh"
						)
						_expect(
							bool(refreshed_damage.get("accepted", false)),
							"redrawn card keeps a live damaged same-family source"
						)
						var redraw_facts := _runtime_dbg_facts(runtime, owner_id)
						var redraw_authority_state := (
							_runtime_dbg_authority(runtime, owner_id).get(
								"state",
								{}
							) as Dictionary
						)
						var redraw_legal := runtime.legal_card_actions(owner_id)
						print(
							"V075_COMBAT_DBG_PERSONAL_LIFECYCLE_PROGRESS|redraw_batch=%d|runtime_phase=%s|dbg_phase=%s|card_present=%s|option_count=%d"
							% [
								int(redraw_authority_state.get("batch_index", 0)),
								runtime.phase(),
								str(redraw_authority_state.get("phase", "")),
								not _card_by_id(
									redraw_facts.get("hand", []) as Array,
									personal_instance_id
								).is_empty(),
								_legal_options_for_card(
									redraw_legal,
									personal_instance_id
								).size(),
							]
						)
						var refresh_option := _legal_option_for_card(
							redraw_legal,
							personal_instance_id,
							"REFRESH_EXISTING",
							deployed_source_id
						)
						var refresh_binding := (
							refresh_option.get(
								"card_action_binding",
								{}
							) as Dictionary
						)
						_expect(
							not refresh_option.is_empty()
							and refresh_binding.get(
								"immutable_identity_fingerprint"
							) == option_card_binding.get(
								"immutable_identity_fingerprint"
							)
							and refresh_binding.get("binding_fingerprint")
								!= option_card_binding.get("binding_fingerprint")
							and int(refresh_binding.get("zone_revision", 0))
								> int(option_card_binding.get("zone_revision", 0)),
							"same card identity receives a new hand-entry binding after redraw"
						)
						if not refresh_option.is_empty():
							var stale_refresh_option := refresh_option.duplicate(true)
							stale_refresh_option["card_action_binding"] = (
								option_card_binding.duplicate(true)
							)
							var stale_replay := runtime.queue_card_action(
								owner_id,
								personal_instance_id,
								str(refresh_option.get("target_slot_id", "")),
								stale_refresh_option
							)
							_expect(
								not bool(stale_replay.get("accepted", true))
								and str(stale_replay.get("reason_code", ""))
									== "combat_target_binding_invalid_or_stale"
								and _queued_rows(runtime, owner_id).is_empty(),
								"production queue rejects the previous lifecycle binding after redraw"
							)
							var refresh_queued := runtime.queue_card_action(
								owner_id,
								personal_instance_id,
								str(refresh_option.get("target_slot_id", "")),
								refresh_option
							)
							_expect(
								bool(refresh_queued.get("accepted", false)),
								"new lifecycle binding queues the real refresh action"
							)
							var refresh_locked := _lock_all_players(runtime)
							_expect(
								refresh_locked and runtime.phase() == "resolving",
								"new lifecycle binding survives the second lock gate"
							)
							if refresh_locked and runtime.phase() == "resolving":
								var pre_resolve_green := _prove_pre_resolve_gate(
									runtime,
									combat,
									owner_id,
									personal_instance_id,
									refresh_binding
								)
								_expect(
									pre_resolve_green,
									"pre-resolve gate rejects a card that left hand without any downstream effect"
								)
								var intervening := _intervening_refresh_to_full(
									combat,
									owner_id,
									definition_id,
									deployed_source_id
								)
								_expect(
									bool(intervening.get("accepted", false)),
									"typed intervening refresh creates a real target race"
								)
								var play_count_before_fizzle := (
									_dbg_play_receipt_count(
										runtime,
										owner_id,
										personal_instance_id
									)
								)
								var fizzled := runtime.resolve_next_action()
								var facts_after_fizzle := _runtime_dbg_facts(
									runtime,
									owner_id
								)
								_expect(
									bool(fizzled.get("accepted", false))
									and str(fizzled.get("outcome_id", ""))
										== "monster_action_fizzled"
									and str(fizzled.get("reason_code", ""))
										== "monster_refresh_full_hp_illegal"
									and bool(fizzled.get(
										"asset_reservation_released",
										false
									))
									and str(fizzled.get(
										"normal_card_destination",
										""
									)) == "discard"
									and _dbg_play_receipt_count(
										runtime,
										owner_id,
										personal_instance_id
									) == play_count_before_fizzle + 1
									and _normal_card_occurrence_count(
										facts_after_fizzle,
										personal_instance_id
									) == 1,
									"target-race Fizzle completes exactly one DBG lifecycle into discard"
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
	_expect(
		not effect_witness_source_id.is_empty()
			and _prove_effect_witness_exact_once(
				combat,
				effect_witness_source_id
			),
		"independent effect witness accepts distinct commits and exact replay but rejects native-ledger loss"
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
	var queued_count := _queue_zero_cost_facility_cards(
		runtime,
		owner_id,
		target_instance_id,
		2
	)
	if queued_count != 2:
		return {
			"accepted": false,
			"reason_code": "natural_facility_advance_action_missing",
		}
	var cycled := _cycle_non_target_dbg_cards(
		runtime,
		owner_id,
		target_instance_id,
		MAX_ACTIONS_TO_DRAW - 2
	)
	if not bool(cycled.get("accepted", false)):
		return cycled

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
	target_instance_id: String,
	max_actions: int = MAX_ACTIONS_TO_DRAW
) -> int:
	var used_cards: Dictionary = {}
	var used_slots: Dictionary = {}
	var queued_count := 0
	var facts := _runtime_dbg_facts(runtime, owner_id)
	for card_variant in facts.get("hand", []) as Array:
		if queued_count >= max_actions:
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
			if queued_count >= max_actions:
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
	return queued_count


func _cycle_non_target_dbg_cards(
	runtime: RuntimeOwner,
	owner_id: String,
	target_instance_id: String,
	max_cards: int
) -> Dictionary:
	var queued_card_ids: Dictionary = {}
	for row_variant in _queued_rows(runtime, owner_id):
		queued_card_ids[str((row_variant as Dictionary).get(
			"card_instance_id",
			""
		))] = true
	var dbg := _runtime_dbg_owner(runtime, owner_id)
	var state := (
		_runtime_dbg_authority(runtime, owner_id).get("state", {}) as Dictionary
	)
	var batch_index := int(state.get("batch_index", 0))
	var played_count := 0
	for card_variant in (
		_runtime_dbg_facts(runtime, owner_id).get("hand", []) as Array
	).duplicate(true):
		if played_count >= max_cards:
			break
		var card := card_variant as Dictionary
		var card_id := str(card.get("instance_id", ""))
		if (
			card_id.is_empty()
			or card_id == target_instance_id
			or queued_card_ids.has(card_id)
		):
			continue
		var intent := dbg.create_intent(
			"request.lifecycle.cycle.%02d.%s" % [
				batch_index,
				card_id.sha256_text().substr(0, 12),
			],
			owner_id,
			DbgCore.ACTION_PLAY_CARD,
			{"instance_id": card_id},
			DbgCore.DECISION_PLAYER_EXPLICIT
		) as Dictionary
		var receipt := dbg.apply_intent(intent) as Dictionary
		if not bool(receipt.get("success", false)):
			return {
				"accepted": false,
				"reason_code": "authoritative_cycle_play_failed",
				"receipt": receipt,
			}
		played_count += 1
	return {
		"accepted": true,
		"reason_code": "authoritative_cycle_cards_played",
		"played_count": played_count,
	}


func _legal_option_for_card(
	legal: Array,
	card_instance_id: String,
	monster_card_mode: String = "",
	target_source_instance_id: String = ""
) -> Dictionary:
	for option_variant in legal:
		var option := option_variant as Dictionary
		if (
			str(option.get("card_instance_id", "")) == card_instance_id
			and str(option.get("action_domain", "")) in ["monster", "military"]
			and not str(option.get("target_slot_id", "")).is_empty()
			and (
				monster_card_mode.is_empty()
				or str(option.get("monster_card_mode", "")) == monster_card_mode
			)
			and (
				target_source_instance_id.is_empty()
				or str(option.get("target_source_instance_id", ""))
					== target_source_instance_id
			)
		):
			return option.duplicate(true)
	return {}


func _legal_options_for_card(
	legal: Array,
	card_instance_id: String
) -> Array:
	var result: Array = []
	for option_variant in legal:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if str(option.get("card_instance_id", "")) == card_instance_id:
			result.append(option.duplicate(true))
	return result


func _queued_rows(runtime: RuntimeOwner, actor_id: String) -> Array:
	return (
		(runtime.get("_queued_by_player") as Dictionary).get(actor_id, [])
		as Array
	).duplicate(true)


func _identity_gate_state(
	runtime: RuntimeOwner,
	combat: CombatOwner,
	actor_id: String
) -> Dictionary:
	var combat_checkpoint := combat.capture_checkpoint(
		"checkpoint.identity.gate"
	)
	return {
		"asset_state": (runtime.get("_asset_state") as Dictionary).duplicate(true),
		"facility_state": (
			runtime.get("_facility_state") as Dictionary
		).duplicate(true),
		"queued_rows": _queued_rows(runtime, actor_id),
		"locked_by_player": (
			runtime.get("_locked_by_player") as Dictionary
		).duplicate(true),
		"dbg": _runtime_dbg_authority(runtime, actor_id),
		"combat": (
			combat_checkpoint.get("state", {}) as Dictionary
		).duplicate(true),
		"phase": runtime.phase(),
	}


func _lock_all_players(runtime: RuntimeOwner) -> bool:
	for actor_variant in runtime.player_ids():
		var locked := runtime.lock_player_submission(str(actor_variant))
		if not bool(locked.get("accepted", false)):
			_failures.append(
				"production submission lock failed: %s"
				% JSON.stringify(locked)
			)
			return false
	return true


func _runtime_dbg_owner(runtime: RuntimeOwner, owner_id: String) -> RefCounted:
	return (
		(runtime.get("_dbg_by_player") as Dictionary).get(owner_id)
		as RefCounted
	)


func _runtime_dbg_authority(
	runtime: RuntimeOwner,
	owner_id: String
) -> Dictionary:
	var dbg := _runtime_dbg_owner(runtime, owner_id)
	return dbg.core_authority_snapshot() as Dictionary


func _dbg_play_receipt_count(
	runtime: RuntimeOwner,
	owner_id: String,
	card_instance_id: String
) -> int:
	var state := (
		_runtime_dbg_authority(runtime, owner_id).get("state", {}) as Dictionary
	)
	var count := 0
	for receipt_variant in (
		state.get("receipt_journal", {}) as Dictionary
	).values():
		var receipt := receipt_variant as Dictionary
		if (
			str(receipt.get("action_kind", "")) == "play_card"
			and card_instance_id in (
				receipt.get("changed_instance_ids", []) as Array
			)
		):
			count += 1
	return count


func _normal_card_occurrence_count(
	facts: Dictionary,
	card_instance_id: String
) -> int:
	var count := 0
	for zone_name in ["hand", "draw_pile", "committed_escrow", "discard"]:
		for card_variant in facts.get(zone_name, []) as Array:
			if str((card_variant as Dictionary).get(
				"instance_id",
				""
			)) == card_instance_id:
				count += 1
	return count


func _public_monster_by_id(
	combat: CombatOwner,
	source_instance_id: String
) -> Dictionary:
	for source_variant in combat.public_monsters() as Array:
		var source := source_variant as Dictionary
		if str(source.get("source_instance_id", "")) == source_instance_id:
			return source.duplicate(true)
	return {}


func _damage_monster_for_refresh(
	combat: CombatOwner,
	source_instance_id: String,
	label: String
) -> Dictionary:
	var source := _public_monster_by_id(combat, source_instance_id)
	if source.is_empty():
		return {"accepted": false, "reason_code": "source_missing"}
	if int(source.get("hp", 0)) < int(source.get("max_hp", 0)):
		return {"accepted": true, "reason_code": "source_already_damaged"}
	var intent := CombatDamageCore.build_monster_damage_intent(
		"effect.lifecycle.%s" % label,
		source_instance_id,
		int(source.get("source_generation", 0)),
		int(source.get("source_revision", 0)),
		int(source.get("armor", 0)) + 1,
		str(source.get("region_id", "")),
		"combat.receipt.lifecycle.%s" % label
	)
	if intent.is_empty():
		return {"accepted": false, "reason_code": "damage_intent_invalid"}
	var result := combat.apply_monster_damage_intent(intent)
	if not bool(result.get("accepted", false)):
		return result
	var damaged := _public_monster_by_id(combat, source_instance_id)
	return {
		"accepted": (
			int(damaged.get("hp", 0)) < int(damaged.get("max_hp", 0))
		),
		"reason_code": str(result.get("reason_code", "")),
		"receipt": result.get("receipt", {}),
	}


func _prove_effect_witness_exact_once(
	combat: CombatOwner,
	source_instance_id: String
) -> bool:
	var source_before := _public_monster_by_id(combat, source_instance_id)
	if source_before.is_empty():
		return false
	var native_state_before_a := (
		combat.get("_monster_state") as Dictionary
	).duplicate(true)
	var skill_state_before_a := (
		combat.get("_skill_state") as Dictionary
	).duplicate(true)
	var receipt_journal_before_a := (
		combat.get("_combat_receipt_journal") as Array
	).duplicate(true)
	var witness_before_a := (
		combat.get("_effect_commit_witness") as Dictionary
	).duplicate(true)
	var revision_before_a := int(combat.get("_revision"))
	var intent_a := CombatDamageCore.build_monster_damage_intent(
		"effect.witness.distinct.a",
		source_instance_id,
		int(source_before.get("source_generation", 0)),
		int(source_before.get("source_revision", 0)),
		int(source_before.get("armor", 0)) + 1,
		str(source_before.get("region_id", "")),
		"combat.receipt.witness.distinct.a"
	)
	if intent_a.is_empty():
		return false
	var debug_before_a := combat.debug_snapshot()
	var first_a := combat.apply_monster_damage_intent(intent_a)
	var state_after_a := (
		combat.get("_monster_state") as Dictionary
	).duplicate(true)
	var skill_after_a := (
		combat.get("_skill_state") as Dictionary
	).duplicate(true)
	var receipt_journal_after_a := (
		combat.get("_combat_receipt_journal") as Array
	).duplicate(true)
	var witness_after_a := (
		combat.get("_effect_commit_witness") as Dictionary
	).duplicate(true)
	var source_after_a := _public_monster_by_id(combat, source_instance_id)
	var debug_after_a := combat.debug_snapshot()
	var revision_after_a := int(combat.get("_revision"))
	var receipt_a := (first_a.get("receipt", {}) as Dictionary).duplicate(true)
	var witness_key_a := "monster_transition|operation.%s" % str(
		intent_a.get("combat_receipt_id", "")
	)
	var expected_receipt_journal_after_a := receipt_journal_before_a.duplicate(true)
	if receipt_journal_after_a.size() == receipt_journal_before_a.size() + 1:
		expected_receipt_journal_after_a.append(
			receipt_journal_after_a[receipt_journal_before_a.size()]
		)
	var expected_witness_after_a := witness_before_a.duplicate(true)
	if witness_after_a.has(witness_key_a):
		expected_witness_after_a[witness_key_a] = (
			witness_after_a.get(witness_key_a, {}) as Dictionary
		).duplicate(true)
	var receipt_envelope_a: Dictionary = {}
	if receipt_journal_after_a.size() > receipt_journal_before_a.size():
		receipt_envelope_a = (
			receipt_journal_after_a[receipt_journal_before_a.size()] as Dictionary
		).duplicate(true)
	var witness_entry_a := (
		witness_after_a.get(witness_key_a, {}) as Dictionary
	)
	var first_a_green: bool = (
		bool(first_a.get("accepted", false))
		and bool(first_a.get("newly_committed", false))
		and not source_after_a.is_empty()
		and int(source_after_a.get("hp", -1))
			== int(source_before.get("hp", 0)) - 1
		and int(source_after_a.get("source_revision", -1))
			== int(source_before.get("source_revision", 0)) + 1
		and revision_after_a == revision_before_a + 1
		and state_after_a != native_state_before_a
		and receipt_journal_after_a == expected_receipt_journal_after_a
		and receipt_journal_after_a.size()
			== receipt_journal_before_a.size() + 1
		and str(receipt_envelope_a.get("event_kind", ""))
			== "monster_damaged"
		and receipt_envelope_a.get("payload") == receipt_a
		and witness_after_a == expected_witness_after_a
		and witness_after_a.size() == witness_before_a.size() + 1
		and str(witness_entry_a.get("input_fingerprint", ""))
			== str(intent_a.get("intent_fingerprint", ""))
		and str(witness_entry_a.get("receipt_id", ""))
			== str(receipt_a.get("receipt_id", ""))
		and str(witness_entry_a.get("receipt_fingerprint", ""))
			== str(receipt_a.get("receipt_fingerprint", ""))
		and int(debug_after_a.get("monster_damage_commit_count", -1))
			== int(debug_before_a.get("monster_damage_commit_count", -1)) + 1
		and int(debug_after_a.get("combat_duplicate_effect_count", -1)) == 0
	)
	var replay_a := combat.apply_monster_damage_intent(intent_a)
	var source_after_replay := _public_monster_by_id(
		combat,
		source_instance_id
	)
	var receipt_journal_after_replay := (
		combat.get("_combat_receipt_journal") as Array
	).duplicate(true)
	var witness_after_replay := (
		combat.get("_effect_commit_witness") as Dictionary
	).duplicate(true)
	var debug_after_replay := combat.debug_snapshot()
	var replay_green: bool = (
		bool(replay_a.get("accepted", false))
		and bool(replay_a.get("idempotent_replay", false))
		and not bool(replay_a.get("newly_committed", true))
		and replay_a.get("receipt") == receipt_a
		and source_after_replay == source_after_a
		and combat.get("_monster_state") == state_after_a
		and combat.get("_skill_state") == skill_after_a
		and receipt_journal_after_replay == receipt_journal_after_a
		and witness_after_replay == witness_after_a
		and int(debug_after_replay.get("monster_damage_commit_count", -1))
			== int(debug_after_a.get("monster_damage_commit_count", -2))
		and int(combat.get("_revision")) == revision_after_a
		and int(debug_after_replay.get("combat_duplicate_effect_count", -1)) == 0
	)
	var source_before_b := _public_monster_by_id(combat, source_instance_id)
	if source_before_b.is_empty():
		return false
	var revision_before_b := int(combat.get("_revision"))
	var receipt_journal_before_b := (
		combat.get("_combat_receipt_journal") as Array
	).duplicate(true)
	var witness_before_b := (
		combat.get("_effect_commit_witness") as Dictionary
	).duplicate(true)
	var intent_b := CombatDamageCore.build_monster_damage_intent(
		"effect.witness.distinct.b",
		source_instance_id,
		int(source_before_b.get("source_generation", 0)),
		int(source_before_b.get("source_revision", 0)),
		int(source_before_b.get("armor", 0)) + 1,
		str(source_before_b.get("region_id", "")),
		"combat.receipt.witness.distinct.b"
	)
	if intent_b.is_empty():
		return false
	var second_b := combat.apply_monster_damage_intent(intent_b)
	var source_after_b := _public_monster_by_id(combat, source_instance_id)
	var state_after_b := (
		combat.get("_monster_state") as Dictionary
	).duplicate(true)
	var receipt_journal_after_b := (
		combat.get("_combat_receipt_journal") as Array
	).duplicate(true)
	var witness_after_b := (
		combat.get("_effect_commit_witness") as Dictionary
	).duplicate(true)
	var revision_after_b := int(combat.get("_revision"))
	var debug_after_b := combat.debug_snapshot()
	var receipt_b := (second_b.get("receipt", {}) as Dictionary).duplicate(true)
	var witness_key_b := "monster_transition|operation.%s" % str(
		intent_b.get("combat_receipt_id", "")
	)
	var expected_receipt_journal_after_b := receipt_journal_before_b.duplicate(true)
	if receipt_journal_after_b.size() == receipt_journal_before_b.size() + 1:
		expected_receipt_journal_after_b.append(
			receipt_journal_after_b[receipt_journal_before_b.size()]
		)
	var expected_witness_after_b := witness_before_b.duplicate(true)
	if witness_after_b.has(witness_key_b):
		expected_witness_after_b[witness_key_b] = (
			witness_after_b.get(witness_key_b, {}) as Dictionary
		).duplicate(true)
	var receipt_envelope_b: Dictionary = {}
	if receipt_journal_after_b.size() > receipt_journal_before_b.size():
		receipt_envelope_b = (
			receipt_journal_after_b[receipt_journal_before_b.size()] as Dictionary
		).duplicate(true)
	var witness_entry_b := (
		witness_after_b.get(witness_key_b, {}) as Dictionary
	)
	var distinct_green: bool = (
		bool(second_b.get("accepted", false))
		and bool(second_b.get("newly_committed", false))
		and not source_after_b.is_empty()
		and int(source_after_b.get("hp", -1))
			== int(source_before_b.get("hp", 0)) - 1
		and int(source_after_b.get("source_revision", -1))
			== int(source_before_b.get("source_revision", 0)) + 1
		and revision_after_b == revision_before_b + 1
		and state_after_b != state_after_a
		and receipt_journal_after_b == expected_receipt_journal_after_b
		and receipt_journal_after_b.size()
			== receipt_journal_before_b.size() + 1
		and str(receipt_envelope_b.get("event_kind", ""))
			== "monster_damaged"
		and receipt_envelope_b.get("payload") == receipt_b
		and witness_after_b == expected_witness_after_b
		and witness_after_b.size() == witness_before_b.size() + 1
		and witness_key_b != witness_key_a
		and str(witness_entry_b.get("input_fingerprint", ""))
			== str(intent_b.get("intent_fingerprint", ""))
		and str(witness_entry_b.get("receipt_id", ""))
			== str(receipt_b.get("receipt_id", ""))
		and str(witness_entry_b.get("receipt_fingerprint", ""))
			== str(receipt_b.get("receipt_fingerprint", ""))
		and int(debug_after_b.get("monster_damage_commit_count", -1))
			== int(debug_before_a.get("monster_damage_commit_count", -1)) + 2
		and int(debug_after_b.get("combat_duplicate_effect_count", -1)) == 0
	)
	# Fault injection is test-only: restore the native core to its valid state
	# from immediately before A while deliberately retaining the independent
	# owner witness. The next call still uses the real public damage entry.
	combat.set("_monster_state", native_state_before_a)
	combat.set("_skill_state", skill_state_before_a)
	var state_before_divergence := (
		combat.get("_monster_state") as Dictionary
	).duplicate(true)
	var skill_before_divergence := (
		combat.get("_skill_state") as Dictionary
	).duplicate(true)
	var source_before_divergence := _public_monster_by_id(
		combat,
		source_instance_id
	)
	var receipts_before_divergence := (
		combat.get("_combat_receipt_journal") as Array
	).duplicate(true)
	var witness_before_divergence := (
		combat.get("_effect_commit_witness") as Dictionary
	).duplicate(true)
	var debug_before_divergence := combat.debug_snapshot()
	var revision_before_divergence := int(combat.get("_revision"))
	var divergence := combat.apply_monster_damage_intent(intent_a)
	var source_after_divergence := _public_monster_by_id(
		combat,
		source_instance_id
	)
	var debug_after_divergence := combat.debug_snapshot()
	var divergence_integrity := (
		debug_after_divergence.get("combat_effect_integrity", {}) as Dictionary
	)
	var divergence_green: bool = (
		not bool(divergence.get("accepted", true))
		and str(divergence.get("reason_code", ""))
			== "combat_effect_native_ledger_divergence"
		and combat.get("_monster_state") == state_before_divergence
		and combat.get("_skill_state") == skill_before_divergence
		and source_after_divergence == source_before_divergence
		and combat.get("_combat_receipt_journal")
			== receipts_before_divergence
		and combat.get("_effect_commit_witness")
			== witness_before_divergence
		and int(debug_after_divergence.get("monster_damage_commit_count", -1))
			== int(debug_before_divergence.get(
				"monster_damage_commit_count",
				-2
			))
		and int(combat.get("_revision")) == revision_before_divergence
		and int(debug_after_divergence.get("combat_duplicate_effect_count", 0)) == 1
		and int(divergence_integrity.get("duplicate_commit_count", 0)) == 1
		and not bool(divergence_integrity.get("green", true))
	)
	var altered_intent := CombatDamageCore.build_monster_damage_intent(
		"effect.witness.forged.authority",
		source_instance_id,
		int(source_before.get("source_generation", 0)),
		int(source_before.get("source_revision", 0)),
		int(source_before.get("armor", 0)) + 1,
		str(source_before.get("region_id", "")),
		"combat.receipt.witness.distinct.a"
	)
	var state_before_collision := (
		combat.get("_monster_state") as Dictionary
	).duplicate(true)
	var skill_before_collision := (
		combat.get("_skill_state") as Dictionary
	).duplicate(true)
	var source_before_collision := _public_monster_by_id(
		combat,
		source_instance_id
	)
	var receipts_before_collision := (
		combat.get("_combat_receipt_journal") as Array
	).duplicate(true)
	var witness_before_collision := (
		combat.get("_effect_commit_witness") as Dictionary
	).duplicate(true)
	var revision_before_collision := int(combat.get("_revision"))
	var collision := combat.apply_monster_damage_intent(altered_intent)
	var source_after_collision := _public_monster_by_id(
		combat,
		source_instance_id
	)
	var debug_after_collision := combat.debug_snapshot()
	var collision_integrity := (
		debug_after_collision.get("combat_effect_integrity", {}) as Dictionary
	)
	var collision_green: bool = (
		not bool(collision.get("accepted", true))
		and str(collision.get("reason_code", ""))
			== "combat_effect_identity_collision"
		and combat.get("_monster_state") == state_before_collision
		and combat.get("_skill_state") == skill_before_collision
		and source_after_collision == source_before_collision
		and combat.get("_combat_receipt_journal") == receipts_before_collision
		and combat.get("_effect_commit_witness") == witness_before_collision
		and int(combat.get("_revision")) == revision_before_collision
		and int(debug_after_collision.get("combat_duplicate_effect_count", 0)) == 2
		and int(collision_integrity.get("identity_collision_count", 0)) == 1
	)
	return (
		first_a_green
		and replay_green
		and distinct_green
		and divergence_green
		and collision_green
	)


func _finish_all_maintenance(runtime: RuntimeOwner) -> Dictionary:
	var reshuffle_observed := false
	if runtime.phase() == "submission":
		return {
			"accepted": true,
			"reshuffle_observed": false,
		}
	if runtime.phase() != "maintenance":
		return {
			"accepted": false,
			"reason_code": "maintenance_phase_missing",
		}
	for actor_variant in runtime.player_ids():
		var finished := runtime.finish_maintenance(str(actor_variant))
		reshuffle_observed = reshuffle_observed or int(
			finished.get("reshuffle_count", 0)
		) > 0
		if not bool(finished.get(
			"success",
			finished.get("accepted", false)
		)):
			return {
				"accepted": false,
				"reason_code": "maintenance_finish_failed",
				"receipt": finished,
			}
	return {
		"accepted": runtime.phase() == "submission",
		"reason_code": (
			"maintenance_finished"
			if runtime.phase() == "submission"
			else "submission_not_reopened"
		),
		"reshuffle_observed": reshuffle_observed,
	}


func _await_card_redraw(
	runtime: RuntimeOwner,
	owner_id: String,
	card_instance_id: String,
	reshuffle_already_observed: bool = false
) -> Dictionary:
	var reshuffle_observed := reshuffle_already_observed
	if _zone_has_id(
		_runtime_dbg_facts(runtime, owner_id).get("hand", []) as Array,
		card_instance_id
	):
		return {
			"found": true,
			"reshuffle_observed": reshuffle_observed,
			"batch_count": 0,
		}
	for batch_offset in range(MAX_LIFECYCLE_BATCHES):
		var advanced := _advance_natural_batch(
			runtime,
			runtime.player_ids(),
			owner_id,
			card_instance_id
		)
		if not bool(advanced.get("accepted", false)):
			return {
				"found": false,
				"reshuffle_observed": reshuffle_observed,
				"reason_code": "redraw_batch_failed",
				"receipt": advanced,
			}
		reshuffle_observed = reshuffle_observed or bool(
			advanced.get("reshuffle_observed", false)
		)
		if _zone_has_id(
			_runtime_dbg_facts(runtime, owner_id).get("hand", []) as Array,
			card_instance_id
		):
			return {
				"found": true,
				"reshuffle_observed": reshuffle_observed,
				"batch_count": batch_offset + 1,
			}
	return {
		"found": false,
		"reshuffle_observed": reshuffle_observed,
		"reason_code": "redraw_guard_exhausted",
	}


func _prove_pre_resolve_gate(
	runtime: RuntimeOwner,
	combat: CombatOwner,
	owner_id: String,
	card_instance_id: String,
	expected_binding: Dictionary
) -> bool:
	var preview := PublicActionBatchCore.resolve_next(
		(runtime.get("_facility_state") as Dictionary).duplicate(true)
	)
	if not bool(preview.get("accepted", false)):
		return false
	var dbg := _runtime_dbg_owner(runtime, owner_id)
	var checkpoint := dbg.capture_checkpoint_v1() as Dictionary
	if checkpoint.is_empty():
		return false
	var play_intent := dbg.create_intent(
		"request.lifecycle.pre_resolve.leave_hand",
		owner_id,
		DbgCore.ACTION_PLAY_CARD,
		{"instance_id": card_instance_id},
		DbgCore.DECISION_PLAYER_EXPLICIT
	) as Dictionary
	var played := dbg.apply_intent(play_intent) as Dictionary
	if not bool(played.get("success", false)):
		return false
	var state_after_leave := _pre_resolve_state(runtime, combat, owner_id)
	var rejected := runtime.call(
		"_resolve_combat_public_action",
		preview.get("receipt", {}) as Dictionary,
		preview.get("state", {}) as Dictionary,
		{}
	) as Dictionary
	var state_after_rejection := _pre_resolve_state(
		runtime,
		combat,
		owner_id
	)
	var rejected_green := (
		not bool(rejected.get("accepted", true))
		and str(rejected.get("reason_code", ""))
			== "card_binding_not_current_hand"
		and state_after_rejection == state_after_leave
		and runtime.phase() == "resolving"
	)
	var rolled_back := dbg.rollback_v1(checkpoint) as Dictionary
	var restored_binding := runtime.call(
		"_authoritative_card_action_binding",
		owner_id,
		card_instance_id
	) as Dictionary
	return (
		rejected_green
		and bool(rolled_back.get("accepted", false))
		and bool(rolled_back.get("rolled_back", false))
		and restored_binding == expected_binding
		and _zone_has_id(
			_runtime_dbg_facts(runtime, owner_id).get("hand", []) as Array,
			card_instance_id
		)
	)


func _pre_resolve_state(
	runtime: RuntimeOwner,
	combat: CombatOwner,
	owner_id: String
) -> Dictionary:
	var combat_checkpoint := combat.capture_checkpoint(
		"checkpoint.lifecycle.pre_resolve"
	)
	return {
		"asset_state": (runtime.get("_asset_state") as Dictionary).duplicate(true),
		"facility_state": (
			runtime.get("_facility_state") as Dictionary
		).duplicate(true),
		"public_history": (
			runtime.get("_public_history") as Array
		).duplicate(true),
		"combat_public_history": (
			runtime.get("_combat_public_history") as Array
		).duplicate(true),
		"dbg": _runtime_dbg_authority(runtime, owner_id),
		"combat": (
			combat_checkpoint.get("state", {}) as Dictionary
		).duplicate(true),
		"phase": runtime.phase(),
		"runtime_error_count": int(runtime.debug_snapshot().get(
			"runtime_error_count",
			0
		)),
	}


func _intervening_refresh_to_full(
	combat: CombatOwner,
	owner_id: String,
	card_definition_id: String,
	source_instance_id: String
) -> Dictionary:
	var source := _public_monster_by_id(combat, source_instance_id)
	if source.is_empty():
		return {"accepted": false, "reason_code": "source_missing"}
	var prebound := combat.prebind_monster_card_action({
		"request_id": "request.lifecycle.intervening_refresh",
		"card_instance_id": "card.lifecycle.intervening_refresh",
		"card_definition_id": card_definition_id,
		"owner_player_id": owner_id,
		"monster_card_mode": "REFRESH_EXISTING",
		"target_region_id": "",
		"target_source_instance_id": source_instance_id,
	})
	if not bool(prebound.get("accepted", false)):
		return prebound
	var resolved := combat.resolve_monster_card_action(
		prebound.get("action", {}) as Dictionary
	)
	if not bool(resolved.get("accepted", false)):
		return resolved
	var refreshed := _public_monster_by_id(combat, source_instance_id)
	return {
		"accepted": (
			int(refreshed.get("hp", 0)) == int(refreshed.get("max_hp", -1))
		),
		"reason_code": str(resolved.get("reason_code", "")),
		"receipt": resolved.get("receipt", {}),
	}


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

extends SceneTree

const RuntimeOwner := preload(
	"res://scripts/v075_simulation/v075_combat_simulation_runtime_driver.gd"
)
const CombatOwner := preload(
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)
const CombatCardDefinitions := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var runtime := RuntimeOwner.new()
	var combat := CombatOwner.new()
	host.add_child(runtime)
	host.add_child(combat)
	var bound := runtime.bind_combat_owner(combat)
	if not bool(bound.get("accepted", false)):
		push_error("combat bind failed")
		quit(1)
		return
	var started := runtime.start_new_game(
		4,
		901626424,
		true,
		true,
		{
			"map_seed": 901626424,
			"region_count": 16,
			"geography_complexity": "STANDARD",
			"land_ocean_profile": "BALANCED",
		}
	)
	print("TRACE_START|%s" % JSON.stringify(started))
	if not bool(started.get("accepted", false)):
		quit(1)
		return
	for step in range(90):
		var started_usec := Time.get_ticks_usec()
		if (
			str(runtime.debug_snapshot().get("phase", "")) == "submission"
			and int(runtime.debug_snapshot().get("batch_number", 0)) >= 3
		):
			for actor_id in [
				"player.ai.1",
				"player.ai.2",
				"player.ai.3",
			]:
				var hand_snapshot := runtime._dbg_projection(actor_id).get(
					"facts",
					{}
				) as Dictionary
				var hand := hand_snapshot.get("hand", []) as Array
				var legal := runtime._auto_legal_actions(actor_id)
				var queue := runtime._queued_by_player.get(actor_id, []) as Array
				var available := runtime._auto_available_actions(
					actor_id,
					queue,
					legal
				)
				var combat_hand: Array = []
				for card_variant in hand:
					if not (card_variant is Dictionary):
						continue
					var card := card_variant as Dictionary
					var domain := CombatCardDefinitions.card_domain(
						str(card.get("card_type", ""))
					)
					if domain in ["monster", "military"]:
						combat_hand.append({
							"id": str(card.get("instance_id", "")),
							"domain": domain,
							"definition": str(card.get("definition_id", "")),
						})
				var combat_legal: Array = []
				for option_variant in legal:
					if not (option_variant is Dictionary):
						continue
					var option := option_variant as Dictionary
					if str(option.get("action_domain", "")) in ["monster", "military"]:
						combat_legal.append({
							"id": str(option.get("card_instance_id", "")),
							"domain": str(option.get("action_domain", "")),
							"mode": str(option.get("monster_card_mode", option.get("task_kind", ""))),
							"slot": str(option.get("target_slot_id", "")),
						})
				print("TRACE_AI|%s|hand=%s|legal=%s|available=%d|queue=%d" % [
					actor_id,
					JSON.stringify(combat_hand),
					JSON.stringify(combat_legal),
					available.size(),
					queue.size(),
				])
			print("TRACE_TARGET_BATCH|%s" % JSON.stringify(runtime.debug_snapshot()))
			quit(0)
		runtime._process(1.0)
		var elapsed := int((Time.get_ticks_usec() - started_usec) / 1000)
		var debug := runtime.debug_snapshot()
		var combat_debug := debug.get("combat", {}) as Dictionary
		var locked := 0
		for player_id in [
			"player.local",
			"player.ai.1",
			"player.ai.2",
			"player.ai.3",
		]:
			var player := runtime.player_snapshot(player_id)
			if bool(player.get("submission_locked", false)):
				locked += 1
		print("TRACE_STEP|%d|ms=%d|phase=%s|batch=%d|locked=%d|queue=%d|cursor=%d|errors=%d|combat_phase=%s|receipts=%d" % [
			step,
			elapsed,
			str(debug.get("phase", "")),
			int(debug.get("batch_number", 0)),
			locked,
			int(debug.get("queued_action_count", 0)),
			int(debug.get("public_resolution_cursor", -1)),
			int(debug.get("runtime_error_count", 0)),
			str(combat_debug.get("phase", "")),
			int(combat_debug.get("combat_receipt_count", 0)),
		])
		if str(debug.get("phase", "")) in ["settled", "failed"]:
			break
	print("TRACE_DONE|%s" % JSON.stringify(runtime.debug_snapshot()))
	quit(0)

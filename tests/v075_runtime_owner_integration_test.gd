extends SceneTree

const RuntimeOwner := preload(
	"res://scripts/v075_runtime/v075_runtime_owner.gd"
)
const CombatOwner := preload(
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)
const SAMPLE_MATCH_SEED := 901626424
const SAMPLE_MAP_SEED := 900626424

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var runtime := RuntimeOwner.new()
	var combat := CombatOwner.new()
	host.add_child(runtime)
	host.add_child(combat)
	runtime.runtime_fault.connect(_on_runtime_fault)
	var bound := runtime.bind_combat_owner(combat)
	_expect(bool(bound.get("accepted", false)), "combat owner binds")
	var started := runtime.start_new_game(
		4,
		SAMPLE_MATCH_SEED,
		true,
		true,
		{
			"map_seed": SAMPLE_MAP_SEED,
			"region_count": 16,
			"geography_complexity": "STANDARD",
			"land_ocean_profile": "BALANCED",
		}
	)
	_expect(bool(started.get("accepted", false)), "V075 new game starts")
	_expect(
		str(started.get("ruleset_id", "")) == "v0.7.5",
		"new game reports V075 ruleset"
	)

	var snapshot := runtime.player_snapshot("player.local")
	_expect(not snapshot.is_empty(), "local player projection exists")
	_expect(
		str(snapshot.get("ruleset_id", "")) == "v0.7.5",
		"player projection reports V075"
	)
	_expect(
		(snapshot.get("special_actions", []) as Array).is_empty(),
		"legacy tactical support placeholder is absent"
	)
	var combat_projection := snapshot.get(
		"v075_combat_projection",
		{}
	) as Dictionary
	_expect(
		str(combat_projection.get("ruleset_id", "")) == "v0.7.5",
		"combat projection is connected"
	)
	_expect(
		int((combat_projection.get("privacy_report", {}) as Dictionary).get(
			"public_skill_card_disclosure_count",
			0
		)) == 0,
		"public combat projection leaks no skill cards"
	)
	var debug := runtime.debug_snapshot()
	_expect(
		int(debug.get("combat_runtime_owner_count", 0)) == 1
		and int(debug.get("combat_state_writer_count", 0)) == 1,
		"single combat writer is production connected"
	)
	_expect(
		int(debug.get("unified_track_local_visible_card_capacity", 0)) == 10,
		"ten-card shared track remains configured"
	)
	_expect(
		str(debug.get("track_refill_mode_id", "")) == "shared_scroll_vacancy",
		"shared scroll vacancy refill remains configured"
	)
	_expect(
		int(debug.get("track_immediate_authoritative_refill_count", -1)) == 0,
		"combat cutover adds no immediate track refill"
	)
	_expect(
		int(debug.get("special_support_placeholder_count", -1)) == 0,
		"runtime debug reports no special support placeholder"
	)
	_expect(
		int(debug.get("ai_action_slot_limit", 0)) == 5,
		"V075 AI can use all five normal anonymous action slots"
	)
	_expect(
		int(debug.get("old_monster_controller_production_reachable_count", -1)) == 0
		and int(debug.get("old_military_controller_production_reachable_count", -1)) == 0,
		"legacy combat controllers remain unreachable"
	)
	var accelerated := runtime.run_accelerated_until_settled(4000)
	if not bool(accelerated.get("accepted", false)):
		var stalled_debug := accelerated.get("debug", {}) as Dictionary
		var stalled_combat := stalled_debug.get("combat", {}) as Dictionary
		print("V075_RUNTIME_STALL_DIAGNOSTIC|%s" % JSON.stringify({
			"reason_code": accelerated.get("reason_code", ""),
			"steps": accelerated.get("steps", 0),
			"phase": accelerated.get("phase", ""),
			"batch_number": stalled_debug.get("batch_number", 0),
			"public_progress_points": stalled_debug.get(
				"public_progress_points",
				0
			),
			"public_progress_target": stalled_debug.get(
				"public_progress_target",
				0
			),
			"queued_action_count": _queued_action_count(runtime),
			"track_scroll_sequence": stalled_debug.get(
				"track_scroll_sequence",
				0
			),
			"combat": {
				"phase": stalled_combat.get("phase", ""),
				"receipt_count": stalled_combat.get("combat_receipt_count", 0),
				"monster_sources": stalled_combat.get("monster_source_count", 0),
				"monster_moves": stalled_combat.get("monster_movement_count", 0),
				"military_region": stalled_combat.get(
					"military_region_assault_count",
					0
				),
				"military_monster": stalled_combat.get(
					"military_monster_assault_count",
					0
				),
			},
			"runtime_error_count": stalled_debug.get("runtime_error_count", 0),
		}))

	_expect(
		bool(accelerated.get("accepted", false)),
		"accelerated production loop reaches settlement"
	)
	_expect(
		str(accelerated.get("phase", "")) == "settled",
		"production loop settles exactly once"
	)
	var final_debug := runtime.debug_snapshot()
	_expect(
		int(final_debug.get("final_settlement_count", 0)) == 1,
		"final settlement count is one"
	)
	var presentation_debug := (
		final_debug.get("combat_presentation", {}) as Dictionary
	)
	_expect(
		int(presentation_debug.get("applied_receipt_count", 0)) > 0
			and int(presentation_debug.get("collision_receipt_count", -1)) == 0
			and int(presentation_debug.get("duplicate_receipt_count", -1)) == 0
			and int(final_debug.get("presentation_identity_rejection_count", -1))
				== 0,
		"fixed-seed natural runtime applies V2 presentation receipts without collision"
	)
	var combat_debug := final_debug.get("combat", {}) as Dictionary
	var monster_modes := combat_debug.get(
		"monster_card_mode_counts",
		{}
	) as Dictionary
	var resolved_combat_actions := (
		int(monster_modes.get("DEPLOY_NEW", 0))
		+ int(monster_modes.get("REFRESH_EXISTING", 0))
		+ int(monster_modes.get("UPGRADE_EXISTING", 0))
		+ int(monster_modes.get("REPLACE_EXISTING", 0))
		+ int(combat_debug.get("military_region_assault_count", 0))
		+ int(combat_debug.get("military_monster_assault_count", 0))
	)
	if resolved_combat_actions == 0:
		var aggregate_dbg := {
			"player_projection_count": 0,
			"queued_action_count": 0,
			"hand_count": 0,
			"draw_pile_count": 0,
			"discard_count": 0,
		}
		for player_id in [
			"player.local",
			"player.ai.1",
			"player.ai.2",
			"player.ai.3",
		]:
			var player_view := runtime.player_snapshot(player_id)
			if player_view.is_empty():
				continue
			aggregate_dbg["player_projection_count"] = int(
				aggregate_dbg.get("player_projection_count", 0)
			) + 1
			aggregate_dbg["queued_action_count"] = int(
				aggregate_dbg.get("queued_action_count", 0)
			) + (player_view.get("queued_actions", []) as Array).size()
			var dbg_facts := (
				(player_view.get("canonical_player_projection", {}) as Dictionary)
				.get("personal_dbg", {}) as Dictionary
			).get("facts", {}) as Dictionary
			for count_field in [
				"hand_count",
				"draw_pile_count",
				"discard_count",
			]:
				aggregate_dbg[count_field] = int(
					aggregate_dbg.get(count_field, 0)
				) + int(dbg_facts.get(count_field, 0))
		print(
			"V075_NATURAL_COMBAT_DIAGNOSTIC|%s"
			% JSON.stringify({
				"monster_card_purchase_count": int(final_debug.get(
					"monster_card_purchase_count",
					0
				)),
				"military_card_purchase_count": int(final_debug.get(
					"military_card_purchase_count",
					0
				)),
				"first_monster_card_purchase_batch": int(final_debug.get(
					"first_monster_card_purchase_batch",
					-1
				)),
				"first_military_card_purchase_batch": int(final_debug.get(
					"first_military_card_purchase_batch",
					-1
				)),
				"monster_card_mode_counts": monster_modes.duplicate(true),
				"military_region_assault_count": int(combat_debug.get(
					"military_region_assault_count",
					0
				)),
				"military_monster_assault_count": int(combat_debug.get(
					"military_monster_assault_count",
					0
				)),
				"final_settlement_count": int(final_debug.get(
					"final_settlement_count",
					0
				)),
				"batch_number": int(final_debug.get("batch_number", 0)),
				"aggregate_dbg": aggregate_dbg,
			})
		)
	_expect(
		resolved_combat_actions > 0,
		"fixed-seed natural DBG loop resolves a combat card before settlement"
	)
	_finish()


func _queued_action_count(runtime: RuntimeOwner) -> int:
	var total := 0
	for player_id in [
		"player.local",
		"player.ai.1",
		"player.ai.2",
		"player.ai.3",
	]:
		var snapshot := runtime.player_snapshot(player_id)
		total += (snapshot.get("queued_actions", []) as Array).size()
	return total


func _on_runtime_fault(receipt: Dictionary) -> void:
	var detail := receipt.get("detail", {}) as Dictionary
	var bridge_receipt := detail.get("receipt", {}) as Dictionary
	print("V075_RUNTIME_FAULT_DIAGNOSTIC|%s" % JSON.stringify({
		"reason_code": receipt.get("reason_code", ""),
		"detail_reason_code": detail.get("reason_code", ""),
		"detail_accepted": detail.get("accepted", false),
		"detail_duplicate": detail.get("duplicate", false),
		"target_facility_id": bridge_receipt.get("target_facility_id", ""),
		"expected_generation": bridge_receipt.get("expected_generation", -1),
		"facility_generation_before": bridge_receipt.get(
			"facility_generation_before",
			-1
		),
		"damage_kind": bridge_receipt.get("damage_kind", ""),
		"requested_damage": bridge_receipt.get("requested_damage", 0),
		"bridge_receipt_reason_code": bridge_receipt.get("reason_code", ""),
		"facility_slot_count": (detail.get("facility_slots", []) as Array).size(),
	}))
func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_RUNTIME_OWNER_INTEGRATION_TEST|%s"
		% JSON.stringify({
			"status": "PASS" if _failures.is_empty() else "FAIL",
			"passed": _checks - _failures.size(),
			"total": _checks,
			"failures": _failures,
		})
	)
	quit(0 if _failures.is_empty() else 1)

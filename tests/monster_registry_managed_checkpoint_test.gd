extends SceneTree

const FIXTURE := preload("res://tests/fixtures/monster_save_full_state_fixture.gd")
const CODEC := preload("res://scripts/runtime/monster_save_wire_codec_v2.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := FIXTURE.create(self)
	var owner = fixture.get("owner")
	var built := FIXTURE.build_nontrivial_state(fixture)
	_expect(bool(built.get("ok", false)), "nontrivial registry checkpoint fixture is ready")
	var checkpoint_a: Dictionary = owner.call("to_save_data")
	var decoded_a := CODEC.decode_save_state(checkpoint_a)
	var state_a: Dictionary = decoded_a.get("value", {}) if bool(decoded_a.get("ok", false)) and decoded_a.get("value") is Dictionary else {}
	_expect(not owner.has_method("capture_runtime_checkpoint") and not owner.has_method("restore_runtime_checkpoint"), "Monster keeps the registry-managed checkpoint strategy")
	_expect(not checkpoint_a.is_empty() and bool(decoded_a.get("ok", false)), "registry checkpoint A is one closed Monster Save v2 payload")

	owner.auto_monsters = []
	owner.next_auto_monster_uid = 1
	owner.next_special_monster_slot = 0
	owner.selected_auto_monster_slot = 0
	owner.active_monster_wagers = []
	owner.resolved_monster_wager_history = []
	owner.monster_wager_sequence = 0
	owner.public_card_bid_monster_wager_pool = 0
	owner.monster_timer = 91.25
	owner.special_monster_timer = 92.5
	owner.auto_monster_action_sequence = 0
	owner.set("_autonomous_move_sequence", 0)
	owner.set("_monster_wager_settlement_revision", 0)
	owner.set("_monster_wager_settlement_terminal_journal", {})
	owner.set("_monster_card_revision_v06", 0)
	owner.set("_monster_starter_state_v06", {})
	owner.set("_monster_card_reservations_v06", {})
	owner.set("_monster_card_terminal_journal_v06", {})
	owner.set("_monster_card_presentation_journal_v06", {})
	owner.set("_bankruptcy_estate_journal", {})

	var rollback: Dictionary = owner.call("apply_save_data", checkpoint_a)
	var checkpoint_b: Dictionary = owner.call("to_save_data")
	var decoded_b := CODEC.decode_save_state(checkpoint_b)
	var state_b: Dictionary = decoded_b.get("value", {}) if bool(decoded_b.get("ok", false)) and decoded_b.get("value") is Dictionary else {}
	var roster_parity: bool = state_a.get("auto_monsters") == state_b.get("auto_monsters")
	var timer_parity: bool = state_a.get("monster_timer") == state_b.get("monster_timer") \
		and state_a.get("special_monster_timer") == state_b.get("special_monster_timer")
	var wager_parity: bool = state_a.get("active_monster_wagers") == state_b.get("active_monster_wagers") \
		and state_a.get("resolved_monster_wager_history") == state_b.get("resolved_monster_wager_history") \
		and state_a.get("monster_wager_settlement_terminal_journal") == state_b.get("monster_wager_settlement_terminal_journal")
	var atomic_parity: bool = state_a.get("monster_card_atomic_reservations") == state_b.get("monster_card_atomic_reservations") \
		and state_a.get("monster_card_atomic_terminal_journal") == state_b.get("monster_card_atomic_terminal_journal") \
		and state_a.get("monster_card_atomic_presentation_journal") == state_b.get("monster_card_atomic_presentation_journal") \
		and state_a.get("bankruptcy_estate_journal") == state_b.get("bankruptcy_estate_journal")
	var allocator_parity: bool = state_a.get("next_auto_monster_uid") == state_b.get("next_auto_monster_uid") \
		and state_a.get("autonomous_move_sequence") == state_b.get("autonomous_move_sequence") \
		and state_a.get("auto_monster_action_sequence") == state_b.get("auto_monster_action_sequence")
	_expect(bool(rollback.get("applied", false)), "registry rollback applies the preflight-approved checkpoint")
	_expect(checkpoint_a == checkpoint_b, "registry-managed Monster checkpoint A equals B")
	_expect(roster_parity and timer_parity and wager_parity and atomic_parity and allocator_parity, "roster, timers, wagers, journals, and allocators restore exactly")

	FIXTURE.cleanup(fixture)
	await process_frame
	print("MONSTER_REGISTRY_MANAGED_CHECKPOINT_TEST|status=%s|checks=%d|failures=%d|checkpoint_a_equals_b=%s|roster_parity=%s|timer_parity=%s|wager_parity=%s|atomic_parity=%s|uid_allocator_parity=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		str(checkpoint_a == checkpoint_b).to_lower(),
		str(roster_parity).to_lower(),
		str(timer_parity).to_lower(),
		str(wager_parity).to_lower(),
		str(atomic_parity).to_lower(),
		str(allocator_parity).to_lower(),
	])
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)

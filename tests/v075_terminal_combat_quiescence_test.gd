extends SceneTree

const ProjectionAdapter := preload(
	"res://scripts/v075/player/v075_combat_projection_adapter.gd"
)
const AIAdapter := preload(
	"res://scripts/v075/ai/v075_combat_ai_adapter.gd"
)
const Presentation := preload(
	"res://scripts/v075/presentation/v075_combat_presentation_consumer.gd"
)
const Telemetry := preload(
	"res://scripts/v075/telemetry/v075_combat_telemetry_contract.gd"
)
const Bench := preload(
	"res://scripts/tools/v075/v075_combat_player_surface_bench.gd"
)
const SkillCore := preload(
	"res://scripts/v075/monster/v075_monster_private_skill_core.gd"
)
const SkillBench := preload(
	"res://scripts/tools/v075/v075_monster_private_skill_bench.gd"
)
const CombatRuntime := preload(
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var authority := Bench.make_authority_snapshot()
	authority["phase"] = "final_settlement"
	authority["terminal_quiescence"] = {
		"green": true,
		"private_queue_count": 0,
		"private_skill_resolving_count": 0,
		"private_skill_atomic_inflight_count": 0,
		"unresolved_military_lock_count": 0,
	}
	var projection := ProjectionAdapter.new().project_for_viewer(
		authority,
		"player.local"
	)
	_expect(
		bool(projection.get("terminal_combat_quiescent", false))
		and not bool(projection.get("combat_requests_allowed", true)),
		"terminal projection disables new combat requests"
	)
	var sources := projection.get(
		"own_monster_skill_sources",
		[]
	) as Array
	_expect(not sources.is_empty(), "owner may still inspect terminal skill state")
	var skill_rows := (sources[0] as Dictionary).get("skills", []) as Array
	var all_disabled_for_request := true
	for skill_variant in skill_rows:
		all_disabled_for_request = all_disabled_for_request and not bool(
			(skill_variant as Dictionary).get("can_request", true)
		)
	_expect(
		all_disabled_for_request,
		"terminal projection marks every skill request unavailable"
	)
	var ai_own := {
		"viewer_player_id": "player.local",
		"owned_monsters": [],
	}
	var ai_public := {
		"phase": "final_settlement",
		"facilities": [],
		"monsters": [],
	}
	var ai_result := AIAdapter.new().enumerate_candidates(
		ai_own,
		ai_public
	)
	_expect(
		(ai_result.get("candidates", []) as Array).is_empty()
		and str(ai_result.get("reason_code", "")) ==
			"terminal_combat_quiescent",
		"terminal AI produces no new action"
	)
	var presentation := Presentation.new()
	root.add_child(presentation)
	presentation.set_terminal_phase("final_settlement")
	var post_settlement := presentation.consume_receipt({
		"combat_receipt_id": "terminal.receipt.001",
		"event_kind": "military_monster_assault",
		"target_kind": "monster",
		"damage_amount": 4,
	})
	_expect(
		not bool(post_settlement.get("applied", true)),
		"terminal presentation rejects post-settlement effect"
	)
	var telemetry := Telemetry.new()
	var event := telemetry.record_event(
		"monster_private_skill_resolved",
		{
			"source_rank": 4,
			"public_effect_id": "effect.public",
			"skill_definition_id": "hidden",
			"skill_target": "hidden",
			"cooldown_remaining_batches": 4,
		},
		"batch.0007"
	)
	_expect(
		not event.is_empty()
		and not _contains_key(event, "skill_definition_id")
		and not _contains_key(event, "skill_target")
		and not _contains_key(event, "cooldown_remaining_batches"),
		"telemetry allowlist strips hidden skill fields"
	)
	_expect(
		int(telemetry.debug_snapshot().get(
			"gameplay_owner_count",
			-1
		)) == 0
		and int(telemetry.debug_snapshot().get(
			"rng_owner_count",
			-1
		)) == 0,
		"telemetry remains read-only"
	)
	_test_terminal_transition_requires_measured_quiescence()
	_test_duplicate_effect_metric_is_measured()
	presentation.queue_free()
	_finish()


func _test_terminal_transition_requires_measured_quiescence() -> void:
	var state := SkillBench.TestFixture.state()
	var request := SkillBench.TestFixture.request(
		state,
		"request.terminal.pending.001"
	)
	var submitted := SkillCore.submit_request(
		state,
		request,
		SkillBench.TestFixture.asset_view()
	)
	var pending_state := submitted.get("state", {}) as Dictionary
	var pending_report := SkillCore.terminal_quiescence_report(pending_state)
	var rejected := SkillCore.set_phase(
		pending_state,
		"final_settlement"
	)
	_expect(
		bool(submitted.get("accepted", false))
		and not bool(pending_report.get("green", true))
		and int(pending_report.get("private_queue_count", 0)) == 1
		and not bool(rejected.get("accepted", true))
		and str(rejected.get("reason_code", "")) ==
			"terminal_phase_not_quiescent"
		and rejected.get("state", {}) == pending_state,
		"terminal transition fails closed while a private request is pending"
	)
	var reservation := submitted.get(
		"asset_reservation_request",
		{}
	) as Dictionary
	var reservation_receipt := SkillCore.build_asset_reservation_receipt(
		reservation,
		true,
		"reservation_committed",
		2
	)
	var reserved := SkillCore.apply_asset_reservation_receipt(
		pending_state,
		reservation_receipt
	)
	var taken := SkillCore.take_next_ready_request(
		reserved.get("state", {}) as Dictionary
	)
	var inflight_state := taken.get("state", {}) as Dictionary
	var inflight_report := SkillCore.terminal_quiescence_report(
		inflight_state
	)
	var inflight_rejected := SkillCore.set_phase(
		inflight_state,
		"terminal"
	)
	_expect(
		bool(taken.get("accepted", false))
		and not bool(inflight_report.get("green", true))
		and int(inflight_report.get("resolving_count", 0)) == 1
		and int(inflight_report.get("atomic_inflight_count", -1)) == 0
		and not bool(inflight_rejected.get("accepted", true)),
		"terminal transition rejects a resolving private skill transaction"
	)
	var atomic_started := SkillCore.begin_atomic_receipt(
		state,
		"receipt.terminal.atomic.001"
	)
	var atomic_state := atomic_started.get("state", {}) as Dictionary
	var atomic_report := SkillCore.terminal_quiescence_report(atomic_state)
	var atomic_rejected := SkillCore.set_phase(atomic_state, "terminal")
	var atomic_completed := SkillCore.complete_atomic_receipt(
		atomic_state,
		"receipt.terminal.atomic.001"
	)
	_expect(
		bool(atomic_started.get("accepted", false))
		and not bool(atomic_report.get("green", true))
		and int(atomic_report.get("resolving_count", -1)) == 0
		and int(atomic_report.get("atomic_inflight_count", 0)) == 1
		and not bool(atomic_rejected.get("accepted", true))
		and bool(atomic_completed.get("accepted", false)),
		"terminal transition rejects an inflight atomic receipt transaction"
	)
	var effect_receipt := SkillCore.build_effect_receipt(
		taken.get("execution_intent", {}) as Dictionary,
		true,
		"resolved",
		{
			"target_kind": "enemy_facility",
			"target_id": "facility.target.001",
			"target_region_id": "region.001",
		},
		{
			"effect_summary_key": "monster.skill.test",
			"damage_amount": 2,
			"combat_receipt_id": "combat.receipt.terminal.001",
		}
	)
	var resolved := SkillCore.resolve_current(inflight_state, effect_receipt)
	var resolved_state := resolved.get("state", {}) as Dictionary
	var final_report := SkillCore.terminal_quiescence_report(resolved_state)
	var accepted := SkillCore.set_phase(
		resolved_state,
		"final_settlement"
	)
	_expect(
		bool(resolved.get("accepted", false))
		and bool(final_report.get("green", false))
		and bool(accepted.get("accepted", false)),
		"terminal transition succeeds only after every private transaction clears"
	)


func _test_duplicate_effect_metric_is_measured() -> void:
	var receipt := {
		"receipt_id": "receipt.combat.measure.001",
		"receipt_fingerprint": "fingerprint.measure.001",
	}
	var green := CombatRuntime.combat_receipt_integrity_report([receipt])
	var duplicate := CombatRuntime.combat_receipt_integrity_report([
		receipt,
		receipt.duplicate(true),
	])
	var collision_receipt := receipt.duplicate(true)
	collision_receipt["receipt_fingerprint"] = "fingerprint.measure.changed"
	var collision := CombatRuntime.combat_receipt_integrity_report([
		receipt,
		collision_receipt,
	])
	_expect(
		bool(green.get("green", false))
		and int(green.get("duplicate_receipt_row_count", -1)) == 0
		and not bool(duplicate.get("green", true))
		and int(duplicate.get("duplicate_receipt_row_count", 0)) == 1
		and not bool(collision.get("green", true))
		and int(collision.get("receipt_identity_collision_count", 0)) == 1,
		"receipt-row integrity is measured independently from effect exact-once telemetry"
	)


func _contains_key(value: Variant, expected: String) -> bool:
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			if str(key_variant) == expected:
				return true
			if _contains_key(dictionary.get(key_variant), expected):
				return true
	elif value is Array:
		for child_variant in value as Array:
			if _contains_key(child_variant, expected):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_TERMINAL_COMBAT_QUIESCENCE_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)

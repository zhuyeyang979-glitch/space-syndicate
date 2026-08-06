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

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var authority := Bench.make_authority_snapshot()
	authority["phase"] = "final_settlement"
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
	presentation.queue_free()
	_finish()


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
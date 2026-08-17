extends SceneTree

const Identity := preload(
	"res://scripts/v075/presentation/v075_presentation_receipt_identity_v2.gd"
)
const Consumer := preload(
	"res://scripts/v075/presentation/v075_combat_presentation_consumer.gd"
)
const RuntimeOwner := preload(
	"res://scripts/v075_runtime/v075_runtime_owner.gd"
)
const FIXTURE_PATH := "res://tests/fixtures/v075_presentation_collision_pairs_v1.json"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(FIXTURE_PATH)
	)
	_expect(fixture is Dictionary, "collision_fixture_parses")
	if not (fixture is Dictionary):
		_finish()
		return
	var pairs := (fixture as Dictionary).get("pairs", []) as Array
	var before_collision_count := 0
	var after_collision_count := 0
	for pair_variant in pairs:
		var pair := pair_variant as Dictionary
		var source_id := str(pair.get("legacy_receipt_id", ""))
		var source_fingerprint := str(
			pair.get("source_receipt_fingerprint", "")
		)
		var sequence := int(pair.get("source_authority_sequence", -1))
		var kind := str(pair.get("presentation_kind", ""))
		var session_id := str((fixture as Dictionary).get("session_id", ""))
		var first_payload := Identity.normalize_serialized_public_payload(
			pair.get("first_payload", {}) as Dictionary
		)
		var second_payload := Identity.normalize_serialized_public_payload(
			pair.get("second_payload", {}) as Dictionary
		)
		var first := Identity.build_public(
			source_id,
			source_fingerprint,
			sequence,
			kind,
			0,
			"v0.7.5",
			session_id,
			first_payload
		)
		var legacy_second := Identity.build_public(
			source_id,
			source_fingerprint,
			sequence,
			kind,
			0,
			"v0.7.5",
			session_id,
			second_payload
		)
		var legacy_consumer := Consumer.new()
		root.add_child(legacy_consumer)
		var accepted := legacy_consumer.consume_receipt(first)
		var collided := legacy_consumer.consume_receipt(legacy_second)
		if str(collided.get("reason_code", "")) == (
			"combat_presentation_receipt_collision"
		):
			before_collision_count += 1
		_expect(
			bool(accepted.get("applied", false))
				and str(collided.get("reason_code", ""))
					== "combat_presentation_receipt_collision",
			"%s reproduces legacy coarse-ID collision" % str(
				pair.get("case_id", "")
			)
		)
		legacy_consumer.queue_free()
		var runtime := RuntimeOwner.new()
		root.add_child(runtime)
		runtime.set("_match_id", session_id)
		runtime.call("_connect_combat_observers")
		var repaired_consumer := runtime.combat_presentation_consumer()
		runtime.call(
			"_publish_combat_event",
			kind,
			first_payload,
			source_id,
			source_id,
			source_fingerprint,
			sequence,
			0
		)
		# The second legacy application wrapper remains on the application and
		# telemetry bus. It cannot enter the dedicated V2 Consumer.
		runtime.emit_signal(
			"resolution_presented",
			second_payload.duplicate(true)
		)
		await process_frame
		var repaired_debug := repaired_consumer.debug_snapshot() as Dictionary
		after_collision_count += int(
			repaired_debug.get("collision_receipt_count", 0)
		)
		_expect(
			int(repaired_debug.get("applied_receipt_count", -1)) == 1
				and int(repaired_debug.get("collision_receipt_count", -1)) == 0,
			"%s real runtime dedicated bus excludes the legacy application wrapper"
				% str(pair.get("case_id", ""))
		)
		runtime.queue_free()
		await process_frame
	_expect(
		before_collision_count == 2,
		"frozen_collision_pair_reproduction_before_fix_is_2_of_2"
	)
	_expect(
		after_collision_count == 0,
		"frozen_collision_pair_collision_after_fix_is_0_of_2"
	)
	var negative_source := "source.negative.collision.001"
	var negative_fingerprint := Identity.canonical_sha256("negative-source")
	var negative_first := Identity.build_public(
		negative_source,
		negative_fingerprint,
		9,
		"monster_basic_attack",
		0,
		"v0.7.5",
		"session.negative.collision",
		{"damage_amount": 3, "target_region_id": "region.001"}
	)
	var negative_changed := Identity.build_public(
		negative_source,
		negative_fingerprint,
		9,
		"monster_basic_attack",
		0,
		"v0.7.5",
		"session.negative.collision",
		{"damage_amount": 4, "target_region_id": "region.001"}
	)
	var negative_consumer := Consumer.new()
	root.add_child(negative_consumer)
	var negative_applied := negative_consumer.consume_receipt(negative_first)
	var duplicate := negative_consumer.consume_receipt(
		negative_first.duplicate(true)
	)
	var negative_collision := negative_consumer.consume_receipt(negative_changed)
	_expect(
		bool(negative_applied.get("applied", false))
			and str(duplicate.get("reason_code", ""))
				== "combat_presentation_receipt_duplicate"
			and str(negative_collision.get("reason_code", ""))
				== "combat_presentation_receipt_collision",
		"same_id_same_fingerprint_is_idempotent_and_same_id_different_fingerprint_fails_closed"
	)
	negative_consumer.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_PRESENTATION_RECEIPT_COLLISION_REPRODUCTION_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)

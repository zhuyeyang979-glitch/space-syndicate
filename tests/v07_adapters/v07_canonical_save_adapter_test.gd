extends SceneTree

const CODEC := preload(
	"res://scripts/v07_adapters/v07_canonical_data_codec.gd"
)
const ADAPTER := preload(
	"res://scripts/v07_adapters/v07_canonical_save_adapter.gd"
)
const UNIFIED_CORE := preload(
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
)
const DBG_CORE := preload(
	"res://scripts/v07_semantic/v07_dbg_deck_core.gd"
)
const ASSET_BATCH_CORE := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const SOLAR_VICTORY_CORE := preload(
	"res://scripts/v07_semantic/v07_solar_victory_core.gd"
)

const ROSTER := ["player.alpha", "player.beta", "player.gamma"]
const FIXED_SEED := 900626424
const MATCH_INSTANCE_ID := "match.v07.canonical.adapter"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_codec_contract()
	var sections := _build_sections()
	_expect(sections.size() == 5, "fixture builds all five semantic sections")
	var metadata := _metadata("save.v07.canonical.primary", "2026-08-01T00:00:00Z")
	var capture := ADAPTER.capture_new_v07_game(metadata, sections)
	_expect(
		bool(capture.get("captured", false))
			and str(capture.get("source_kind", "")) == ADAPTER.SOURCE_NEW_V07_GAME,
		"NEW_V071_GAME capture accepts the five detached Core payloads"
	)
	var envelope := capture.get("envelope", {}) as Dictionary
	_expect(
		CODEC.has_exact_fields(envelope, ADAPTER.ENVELOPE_FIELDS)
			and CODEC.is_pure_data(envelope),
		"capture emits one closed pure-data canonical envelope"
	)
	_expect(
		(envelope.get("sections", {}) as Dictionary).size() == 5
			and (envelope.get("rng_stream_states", []) as Array).size() == 11,
		"envelope contains five sections and 5 + 2N concrete RNG streams"
	)
	_expect(
		str(envelope.get("envelope_fingerprint", ""))
			== CODEC.fingerprint(envelope, "envelope_fingerprint"),
		"envelope fingerprint seals the complete closed payload"
	)
	_test_rng_ledger(envelope)
	_test_preflight(envelope)
	_test_detached_plan(envelope, sections)
	_test_exact_roundtrip(envelope)
	_test_strict_rejections(envelope, sections)
	_test_source_gate(envelope)
	_test_source_isolation()
	_finish()


func _test_codec_contract() -> void:
	var canonical := CODEC.canonical_json({"z": 1, "a": [true, null, 1.0]})
	_expect(
		canonical == "{\"a\":[true,null,1],\"z\":1}",
		"codec sorts object keys and preserves ordered arrays and semantic floats"
	)
	var decoded := CODEC.decode_text(canonical)
	_expect(
		bool(decoded.get("accepted", false))
			and bool(decoded.get("canonical", false)),
		"codec accepts its own canonical UTF-8 JSON (%s)"
			% str(decoded.get("reason_code", "missing_reason"))
	)
	_expect(
		not bool(CODEC.decode_text(" " + canonical).get("accepted", true)),
		"strict decode rejects noncanonical whitespace"
	)
	_expect(
		CODEC.is_tagged_int64({"type": "int64", "decimal": "9223372036854775807"})
			and not CODEC.is_tagged_int64({"type": "int64", "decimal": "01"})
			and not CODEC.is_tagged_int64({"type": "int64", "decimal": "9223372036854775808"}),
		"tagged Int64 validation is canonical and range checked"
	)
	_expect(
		not CODEC.is_pure_data(self) and CODEC.is_pure_data(decoded),
		"codec excludes SceneTree and accepts only closed JSON data"
	)


func _test_rng_ledger(envelope: Dictionary) -> void:
	var rows := envelope.get("rng_stream_states", []) as Array
	var keys: Array[String] = []
	var rows_valid := true
	for row_variant in rows:
		var row := row_variant as Dictionary
		keys.append("%s|%s" % [
			str(row.get("stream_id", "")),
			str(row.get("stream_instance_id", "")),
		])
		rows_valid = rows_valid \
			and CODEC.has_exact_fields(row, ADAPTER.RNG_ROW_FIELDS) \
			and str(row.get("state_fingerprint", "")) \
				== CODEC.fingerprint(row, "state_fingerprint")
	var sorted_keys := keys.duplicate()
	sorted_keys.sort()
	_expect(rows_valid, "every canonical RNG row has exact fields and fingerprint")
	_expect(keys == sorted_keys, "canonical RNG rows are sorted by stream and instance")
	var stream_ids := {}
	for row_variant in rows:
		stream_ids[str((row_variant as Dictionary).get("stream_id", ""))] = true
	_expect(stream_ids.size() == 7, "RNG ledger contains exactly seven logical stream IDs")


func _test_preflight(envelope: Dictionary) -> void:
	var preflight := ADAPTER.preflight_restore(
		envelope, ADAPTER.SOURCE_NEW_V07_GAME
	)
	_expect(
		bool(preflight.get("accepted", false))
			and bool(preflight.get("preflight_complete", false))
			and int(preflight.get("preflight_count", 0)) == 5,
		"strict envelope preflight validates all five sections before apply"
	)
	_expect(
		str(preflight.get("canonical_text", "")) == CODEC.canonical_json(envelope)
			and int(preflight.get("rng_stream_count", 0)) == 11,
		"preflight returns the exact canonical text and concrete RNG count"
	)
	var parsed := CODEC.decode_text(str(preflight.get("canonical_text", "")))
	_expect(
		bool(parsed.get("accepted", false))
			and CODEC.canonical_json(parsed.get("value"))
				== CODEC.canonical_json(envelope),
		"canonical envelope text decodes to the exact semantic envelope"
	)


func _test_detached_plan(envelope: Dictionary, source_sections: Dictionary) -> void:
	var plan_result := ADAPTER.build_detached_restore_plan(envelope)
	_expect(
		bool(plan_result.get("accepted", false))
			and int(plan_result.get("node_count", 0)) == 10,
		"detached restore planner materializes the ten-node PR79 graph"
	)
	var plan := plan_result.get("plan", {}) as Dictionary
	_expect(
		bool(ADAPTER.preflight_restore_plan(plan).get("accepted", false))
			and (plan.get("restore_nodes", []) as Array).size() == 10,
		"detached plan is closed, fingerprinted, and independently preflightable"
	)
	var observed_nodes: Array[String] = []
	var node_fingerprints_valid := true
	for node_variant in plan.get("restore_nodes", []) as Array:
		var node := node_variant as Dictionary
		observed_nodes.append(str(node.get("node_id", "")))
		node_fingerprints_valid = node_fingerprints_valid \
			and str(node.get("payload_fingerprint", "")) \
				== CODEC.fingerprint(node.get("payload"))
	_expect(
		observed_nodes == ADAPTER.restore_node_ids() and node_fingerprints_valid,
		"restore nodes preserve topological order and seal every detached payload"
	)

	var old_sections := _build_sections()
	var old_capture := ADAPTER.capture_new_v07_game(
		_metadata("save.v07.canonical.old", "2026-07-31T23:59:59Z"),
		old_sections
	)
	var old_snapshot := old_capture.get("envelope", {}) as Dictionary
	var checkpoint := ADAPTER.capture_checkpoint(old_snapshot, plan)
	_expect(
		not checkpoint.is_empty()
			and checkpoint.get("snapshot") == old_snapshot
			and str(checkpoint.get("checkpoint_fingerprint", ""))
				== CODEC.fingerprint(checkpoint, "checkpoint_fingerprint"),
		"checkpoint captures and seals the complete prior detached snapshot"
	)
	var committed := ADAPTER.execute_detached_restore(plan, old_snapshot)
	_expect(
		bool(committed.get("committed", false))
			and committed.get("snapshot") == envelope
			and (committed.get("applied_node_ids", []) as Array).size() == 10,
		"successful execution publishes one complete detached snapshot"
	)
	_expect(
		not bool(committed.get("rollback_attempted", true))
			and bool(committed.get("rollback_complete", false)),
		"successful detached commit requires no rollback"
	)

	var failed := ADAPTER.execute_detached_restore(
		plan, old_snapshot, "unified_card_track_cycle"
	)
	_expect(
		not bool(failed.get("committed", true))
			and bool(failed.get("rollback_attempted", false))
			and bool(failed.get("rollback_complete", false)),
		"node rejection produces an explicit successful rollback result"
	)
	_expect(
		failed.get("snapshot") == old_snapshot
			and failed.get("rollback_node_ids") == [
				"hidden_lead_cycle",
				"personal_dbg_and_merge",
				"rng_stream_states",
				"envelope_identity",
			],
		"rollback restores the checkpoint and reports exact reverse apply order"
	)

	(source_sections.get(ADAPTER.SECTION_DBG) as Array).clear()
	_expect(
		((envelope.get("sections") as Dictionary).get(
			ADAPTER.SECTION_DBG
		) as Array).size() == ROSTER.size(),
		"capture and plan remain detached from caller-owned section mutations"
	)


func _test_exact_roundtrip(envelope: Dictionary) -> void:
	var result := ADAPTER.exact_roundtrip(envelope)
	_expect(
		bool(result.get("accepted", false))
			and bool(result.get("exact", false))
			and str(result.get("reason_code", ""))
				== "v07_canonical_roundtrip_exact",
		"canonical encode, detached restore, and recapture roundtrip exactly (%s)"
			% str(result.get("reason_code", "missing_reason"))
	)
	_expect(
		result.get("recaptured_envelope") == envelope
			and result.get("envelope_fingerprint")
				== envelope.get("envelope_fingerprint")
			and int(result.get("canonical_byte_count", 0)) > 0,
		"exact roundtrip preserves identity metadata, bytes, and fingerprint"
	)
	_expect(
		int(result.get("section_count", 0)) == 5
			and int(result.get("rng_stream_count", 0)) == 11
			and int(result.get("node_count", 0)) == 10,
		"roundtrip reports the complete section, RNG, and restore-node counts"
	)


func _test_strict_rejections(
	envelope: Dictionary,
	sections: Dictionary
) -> void:
	var unknown_field := envelope.duplicate(true)
	unknown_field["future_field"] = true
	_reseal(unknown_field, "envelope_fingerprint")
	_expect(
		str(ADAPTER.preflight_restore(unknown_field).get("reason_code", ""))
			== "envelope_fields_invalid",
		"unknown envelope fields fail closed even with a valid replacement seal"
	)

	var outer_tamper := envelope.duplicate(true)
	outer_tamper["save_id"] = "save.v07.canonical.tampered"
	_expect(
		str(ADAPTER.preflight_restore(outer_tamper).get("reason_code", ""))
			== "envelope_fingerprint_invalid",
		"outer metadata tampering fails the canonical fingerprint gate"
	)

	var section_tamper := envelope.duplicate(true)
	var tampered_unified := (
		(section_tamper.get("sections") as Dictionary).get(
			ADAPTER.SECTION_UNIFIED
		) as Dictionary
	)
	tampered_unified["source_revision"] = int(
		tampered_unified.get("source_revision", 0)
	) + 1
	_reseal(section_tamper, "envelope_fingerprint")
	_expect(
		str(ADAPTER.preflight_restore(section_tamper).get(
			"reason_code", ""
		)).begins_with("section_preflight_failed.unified_card_track_cycle"),
		"resealed semantic section tampering reaches and fails local Core preflight"
	)

	var player_order := envelope.duplicate(true)
	var player_payloads := (
		(player_order.get("sections") as Dictionary).get(
			ADAPTER.SECTION_DBG
		) as Array
	)
	player_payloads.reverse()
	_reseal(player_order, "envelope_fingerprint")
	_expect(
		str(ADAPTER.preflight_restore(player_order).get(
			"reason_code", ""
		)).contains("player_order_invalid"),
		"personal DBG payloads must be sorted and unique by owner player ID"
	)

	var pair_mismatch := envelope.duplicate(true)
	var hidden_order := _hidden_round_order(sections)
	var other_state := ASSET_BATCH_CORE.create_state(
		"batch.v07.canonical.other",
		ROSTER,
		hidden_order,
		_assets_by_player(2),
		{},
		2000,
		1000
	)
	(pair_mismatch.get("sections") as Dictionary)[ADAPTER.SECTION_BATCH] = (
		ASSET_BATCH_CORE.to_batch_save_state(other_state)
	)
	_reseal(pair_mismatch, "envelope_fingerprint")
	_expect(
		str(ADAPTER.preflight_restore(pair_mismatch).get(
			"reason_code", ""
		)).begins_with("section_pair_preflight_failed"),
		"asset and card-batch sections cannot restore from different shared states"
	)

	var rng_mismatch := envelope.duplicate(true)
	var rows := rng_mismatch.get("rng_stream_states") as Array
	rows.reverse()
	_reseal(rng_mismatch, "envelope_fingerprint")
	_expect(
		str(ADAPTER.preflight_restore(rng_mismatch).get("reason_code", ""))
			== "canonical_rng_stream_states_mismatch",
		"top-level RNG ledger must exactly equal sorted embedded Core states"
	)


func _test_source_gate(envelope: Dictionary) -> void:
	var legacy := {"save_version": 3, "ruleset_id": "v0.6", "sections": {}}
	var rejected := ADAPTER.preflight_restore(legacy, ADAPTER.SOURCE_V06_SAVE)
	_expect(
		not bool(rejected.get("accepted", true))
			and str(rejected.get("reason_code", ""))
				== ADAPTER.V06_BACKUP_REQUIRED_REASON
			and bool(rejected.get("requires_backup", false))
			and bool(rejected.get("backup_required", false)),
		"V06 Save direct resume fails closed with the backup-required reason"
	)
	_expect(
		bool(rejected.get("new_v071_game_required", false))
			and not bool(rejected.get("direct_resume_allowed", true)),
		"V06 rejection requires a new V071 game and never reports direct resume"
	)
	var wrong_source := ADAPTER.preflight_restore(envelope, "V07_SAVE")
	_expect(
		not bool(wrong_source.get("accepted", true))
			and str(wrong_source.get("reason_code", ""))
				== ADAPTER.V07_DIRECT_RESUME_REJECTED_REASON
			and not bool(wrong_source.get("requires_backup", true)),
		"V0.7 Save direct resume fails closed; only NEW_V071_GAME is accepted"
	)
	var contract := ADAPTER.adapter_contract()
	_expect(
		contract.get("source_kinds_allowed") == [ADAPTER.SOURCE_NEW_V07_GAME]
			and contract.get("target_ruleset_id") == "v0.7.1"
			and contract.get("v07_direct_resume_allowed") == false
			and contract.get("v06_direct_resume_allowed") == false
			and contract.get("v06_backup_required") == true,
		"adapter contract publishes the closed source and backup policy"
	)


func _test_source_isolation() -> void:
	var adapter_source := FileAccess.get_file_as_string(
		"res://scripts/v07_adapters/v07_canonical_save_adapter.gd"
	)
	var codec_source := FileAccess.get_file_as_string(
		"res://scripts/v07_adapters/v07_canonical_data_codec.gd"
	)
	_expect(
		adapter_source.begins_with("extends RefCounted")
			and codec_source.begins_with("extends RefCounted")
			and not adapter_source.contains("extends Node")
			and not codec_source.contains("extends Node"),
		"codec and adapter remain pure RefCounted/static data surfaces"
	)
	_expect(
		not adapter_source.contains("res://scripts/runtime/")
			and not adapter_source.contains("res://scripts/main.gd")
			and not adapter_source.contains(".tscn")
			and not adapter_source.contains("V06SaveOwnerRegistry"),
		"adapter imports no V06 owner, Registry, Main, runtime, or scene"
	)
	_expect(
		adapter_source.contains("static func preflight_restore")
			and adapter_source.contains("static func exact_roundtrip")
			and adapter_source.contains("static func rollback_to_checkpoint"),
		"all canonical lifecycle entrypoints are static"
	)


func _build_sections() -> Dictionary:
	var unified := UNIFIED_CORE.new(
		ROSTER,
		FIXED_SEED,
		{"match_instance_id": MATCH_INSTANCE_ID}
	)
	var unified_save: Dictionary = unified.save_state_v1()
	var dbg_saves: Array = []
	for index in range(ROSTER.size()):
		var dbg := DBG_CORE.new()
		var initialized := dbg.initialize(ROSTER[index], FIXED_SEED + index)
		if not bool(initialized.get("initialized", false)):
			return {}
		dbg_saves.append(dbg.to_save_state())
	var hidden_order := (
		((unified_save.get("authority_state") as Dictionary).get(
			"hidden_lead_cycle_state"
		) as Dictionary).get("round_order", []) as Array
	).duplicate()
	var asset_batch_state := ASSET_BATCH_CORE.create_state(
		"batch.v07.canonical.primary",
		ROSTER,
		hidden_order,
		_assets_by_player(2),
		{},
		1000,
		1000
	)
	var macro_round := int(
		((unified_save.get("authority_state") as Dictionary).get(
			"hidden_lead_cycle_state"
		) as Dictionary).get("macro_round_number", 1)
	)
	var solar_state := SOLAR_VICTORY_CORE.create_state(
		false, macro_round, MATCH_INSTANCE_ID
	)
	return {
		ADAPTER.SECTION_UNIFIED: unified_save,
		ADAPTER.SECTION_DBG: dbg_saves,
		ADAPTER.SECTION_ASSET: ASSET_BATCH_CORE.to_asset_save_state(
			asset_batch_state
		),
		ADAPTER.SECTION_BATCH: ASSET_BATCH_CORE.to_batch_save_state(
			asset_batch_state
		),
		ADAPTER.SECTION_SOLAR: SOLAR_VICTORY_CORE.to_save_state(solar_state),
	}


func _hidden_round_order(sections: Dictionary) -> Array:
	return (
		(((sections.get(ADAPTER.SECTION_UNIFIED) as Dictionary).get(
			"authority_state"
		) as Dictionary).get("hidden_lead_cycle_state") as Dictionary).get(
			"round_order", []
		) as Array
	).duplicate()


func _metadata(save_id: String, created_at_utc: String) -> Dictionary:
	return {
		"save_id": save_id,
		"scenario_fingerprint": "a".repeat(64),
		"repository_head": "2e38764791cb37cdc45b2eb0836957f550822dd5",
		"created_at_utc": created_at_utc,
		"balance_profile_id": ADAPTER.BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": ADAPTER.BALANCE_PROFILE_FINGERPRINT,
	}


func _assets_by_player(amount: int) -> Dictionary:
	var result := {}
	for player_id in ROSTER:
		result[player_id] = {
			"life": amount,
			"energy": amount,
			"industry": amount,
			"technology": amount,
			"commerce": amount,
			"shipping": amount,
		}
	return result


func _reseal(value: Dictionary, fingerprint_field: String) -> void:
	value.erase(fingerprint_field)
	value[fingerprint_field] = CODEC.fingerprint(value)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"V071_CANONICAL_SAVE_ADAPTER_READY|status=PASS|checks=%d"
			% _checks
		)
		print(
			"V071_CANONICAL_SAVE_ADAPTER_TEST|status=PASS|checks=%d|failures=0|sections=5|rng_streams=11|restore_nodes=10"
			% _checks
		)
		quit(0)
		return
	print(
		"V071_CANONICAL_SAVE_ADAPTER_TEST|status=FAIL|checks=%d|failures=%d|sections=5|rng_streams=11|restore_nodes=10"
		% [_checks, _failures.size()]
	)
	for failure in _failures:
		print(" - %s" % failure)
	quit(1)

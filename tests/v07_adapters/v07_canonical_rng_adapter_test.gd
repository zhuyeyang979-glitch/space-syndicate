extends SceneTree

const Adapter := preload(
	"res://scripts/v07_adapters/v07_canonical_rng_adapter.gd"
)
const UnifiedCore := preload(
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
)
const DbgCore := preload("res://scripts/v07_semantic/v07_dbg_deck_core.gd")

const FIXED_SEED := 900626424
const ROSTER := ["player.alpha", "player.beta", "player.gamma"]
const MATCH_INSTANCE_ID := "match.canonical_rng_adapter"
const RNG_MODULUS := 2147483647
const RNG_MULTIPLIER := 48271

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := _new_fixture()
	_expect(bool(fixture.get("ready", false)), "V07 local RNG fixture initializes")
	if not bool(fixture.get("ready", false)):
		_finish()
		return
	_test_static_contract()
	_test_capture_and_shape(fixture)
	_test_roundtrip_and_replay_parity(fixture)
	_test_strict_rejections(fixture)
	_test_isolation_and_no_second_authority(fixture)
	_finish()


func _test_static_contract() -> void:
	var adapter := Adapter.new()
	var contract := Adapter.adapter_contract()
	_expect(
		adapter is RefCounted
			and not adapter.has_method("get_tree")
			and not adapter.has_method("add_child"),
		"adapter is pure RefCounted rather than a Node or scene owner"
	)
	_expect(
		Adapter.logical_stream_ids() == [
			"starter_deck_shuffle",
			"normal_deck_reshuffle_by_player",
			"unified_track_type_draw",
			"unified_track_color_draw",
			"unified_track_normal_card_draw",
			"unified_track_commodity_draw",
			"initial_hidden_lead_order",
		],
		"adapter freezes exactly the seven logical stream IDs"
	)
	_expect(
		int(contract.get("logical_stream_id_count", 0)) == 7
			and _same_string_set(
				contract.get("state_profile_ids", []) as Array,
				[
					"dbg_tagged_sha256_counter_v1",
					"unified_park_miller_embedded_v1",
				]
			),
		"adapter freezes exactly two strict state profiles"
	)
	_expect(
		not bool(contract.get("canonical_row_is_second_rng_authority", true))
			and int(contract.get("draw_api_count", -1)) == 0
			and int(contract.get("production_runtime_connection_count", -1)) == 0,
		"adapter declares no RNG authority, draw API, or production connection"
	)
	var source := FileAccess.get_file_as_string(
		"res://scripts/v07_adapters/v07_canonical_rng_adapter.gd"
	)
	_expect(
		source.contains("extends RefCounted")
			and not source.contains("RandomNumberGenerator")
			and not source.contains("preload(")
			and not source.contains("res://scenes/")
			and not source.contains("scripts/main.gd")
			and not source.to_lower().contains("v06"),
		"adapter has no RNG object, V06, Main, preload, or scene dependency"
	)
	var nonstatic_method_found := false
	for line in source.split("\n"):
		if str(line).strip_edges().begins_with("func "):
			nonstatic_method_found = true
			break
	_expect(not nonstatic_method_found, "every adapter method is static")


func _test_capture_and_shape(fixture: Dictionary) -> void:
	var unified_save := fixture.get("unified_save", {}) as Dictionary
	var personal_saves := fixture.get("personal_saves", []) as Array
	var unified_before := unified_save.duplicate(true)
	var personal_before := personal_saves.duplicate(true)
	var captured := Adapter.capture_ledger(unified_save, personal_saves)
	var ledger := captured.get("rng_stream_states", []) as Array
	_expect(
		bool(captured.get("accepted", false))
			and str(captured.get("reason_code", ""))
				== "canonical_rng_ledger_captured",
		"valid local Save payloads capture a canonical RNG ledger"
	)
	_expect(
		int(captured.get("logical_stream_id_count", 0)) == 7
			and int(captured.get("concrete_stream_instance_count", 0)) == 11
			and ledger.size() == 5 + (2 * ROSTER.size()),
		"three players produce seven logical IDs and eleven concrete instances"
	)
	_expect(
		Adapter.validate_ledger(ledger, ROSTER).is_empty(),
		"captured ledger passes independent strict validation"
	)
	_expect(
		_rows_have_exact_shape_and_fingerprints(ledger),
		"every canonical row has the exact closed fields and fingerprint"
	)
	_expect(_rows_are_sorted(ledger), "rows sort by stream ID then instance ID")
	var profile_counts := _profile_counts(ledger)
	_expect(
		int(profile_counts.get("dbg_tagged_sha256_counter_v1", 0)) == 6
			and int(profile_counts.get("unified_park_miller_embedded_v1", 0)) == 5,
		"ledger contains two DBG rows per player and five global unified rows"
	)
	_expect(
		_logical_stream_set(ledger) == _sorted_strings(Adapter.logical_stream_ids()),
		"concrete rows cover all seven logical stream IDs exactly"
	)
	_expect(
		unified_save == unified_before and personal_saves == personal_before,
		"capture mutates no local Save payload"
	)
	var reversed_saves := personal_saves.duplicate(true)
	reversed_saves.reverse()
	var recaptured := Adapter.capture_ledger(
		unified_save, reversed_saves
	).get("rng_stream_states", []) as Array
	_expect(
		recaptured == ledger,
		"capture is deterministic and independent of personal Save input order"
	)
	_expect(
		Adapter.is_strict_pure_data(captured),
		"capture result is detached strict pure data"
	)


func _test_roundtrip_and_replay_parity(fixture: Dictionary) -> void:
	var unified_save := fixture.get("unified_save", {}) as Dictionary
	var personal_saves := fixture.get("personal_saves", []) as Array
	var ledger := Adapter.capture_ledger(
		unified_save, personal_saves
	).get("rng_stream_states", []) as Array
	var encoded := Adapter.encode_ledger_json(ledger, ROSTER)
	var decoded_result := Adapter.decode_ledger_json(encoded, ROSTER)
	var decoded := decoded_result.get("rng_stream_states", []) as Array
	_expect(decoded == ledger, "canonical ledger survives exact JSON roundtrip")
	_expect(
		bool(decoded_result.get("accepted", false))
			and Adapter.validate_ledger(decoded, ROSTER).is_empty(),
		"JSON-roundtripped ledger retains strict seed, cursor, and state types"
	)
	var preflight := Adapter.preflight_ledger(
		decoded, unified_save, personal_saves
	)
	_expect(
		bool(preflight.get("accepted", false))
			and str(preflight.get("reason_code", ""))
				== "canonical_rng_ledger_preflight_green",
		"roundtripped ledger remains exactly bound to embedded owner state"
	)

	var restored_unified := UnifiedCore.new()
	var unified_restore := restored_unified.restore_save_state_v1(
		unified_save.duplicate(true)
	)
	var restored_personal_saves: Array = []
	var all_personal_restored := true
	for personal_save_variant in personal_saves:
		var restored_dbg := DbgCore.new()
		var restore_result := restored_dbg.apply_save_state(
			(personal_save_variant as Dictionary).duplicate(true)
		)
		all_personal_restored = all_personal_restored \
			and bool(restore_result.get("applied", false))
		restored_personal_saves.append(restored_dbg.to_save_state())
	_expect(
		bool(unified_restore.get("accepted", false)) and all_personal_restored,
		"both local RNG profiles restore from detached Save roundtrips"
	)
	var restored_ledger := Adapter.capture_ledger(
		restored_unified.save_state_v1(), restored_personal_saves
	).get("rng_stream_states", []) as Array
	_expect(
		restored_ledger == ledger,
		"local Save restore and exact recapture preserve every canonical row"
	)
	_expect(
		_next_value_projection(restored_ledger) == _next_value_projection(ledger),
		"restored rows produce identical next-value replay projections"
	)
	var fresh := _new_fixture()
	var fresh_ledger := Adapter.capture_ledger(
		fresh.get("unified_save", {}) as Dictionary,
		fresh.get("personal_saves", []) as Array
	).get("rng_stream_states", []) as Array
	_expect(
		fresh_ledger == ledger,
		"same seeds and same roster deterministically reproduce all concrete streams"
	)


func _test_strict_rejections(fixture: Dictionary) -> void:
	var unified_save := fixture.get("unified_save", {}) as Dictionary
	var personal_saves := fixture.get("personal_saves", []) as Array
	var ledger := Adapter.capture_ledger(
		unified_save, personal_saves
	).get("rng_stream_states", []) as Array

	var missing := ledger.duplicate(true)
	missing.pop_back()
	_expect(
		not Adapter.validate_ledger(missing, ROSTER).is_empty(),
		"ledger rejects a missing concrete stream instance"
	)
	var wrong_order := ledger.duplicate(true)
	var first: Variant = wrong_order[0]
	wrong_order[0] = wrong_order[1]
	wrong_order[1] = first
	_expect(
		Adapter.validate_ledger(wrong_order, ROSTER) == "ledger_row_order_invalid",
		"ledger rejects noncanonical row order"
	)
	var unknown_field := ledger.duplicate(true)
	(unknown_field[0] as Dictionary)["unexpected"] = true
	_expect(
		Adapter.validate_ledger(unknown_field, ROSTER)
			== "ledger_row_fields_invalid",
		"ledger rows reject unknown fields"
	)
	var float_state := ledger.duplicate(true)
	var unified_index := _row_index(float_state, "unified_track_type_draw", "global")
	((float_state[unified_index] as Dictionary).get("state", {}) as Dictionary)[
		"rng_state"
	] = 1.0
	_expect(
		Adapter.validate_ledger(float_state, ROSTER)
			== "ledger_not_strict_pure_data",
		"unified RNG state rejects raw floats"
	)
	var malformed_cursor := ledger.duplicate(true)
	var dbg_index := _row_index(
		malformed_cursor,
		"normal_deck_reshuffle_by_player",
		"player.alpha"
	)
	var malformed_row := malformed_cursor[dbg_index] as Dictionary
	var malformed_state := malformed_row.get("state", {}) as Dictionary
	malformed_state["cursor"] = {"type": "int64", "decimal": "01"}
	malformed_state["stream_revision"] = {"type": "int64", "decimal": "01"}
	malformed_state["state_fingerprint"] = Adapter.canonical_fingerprint(
		malformed_state, "state_fingerprint"
	)
	malformed_row["state_fingerprint"] = Adapter.canonical_fingerprint(
		malformed_row, "state_fingerprint"
	)
	_expect(
		Adapter.validate_ledger(malformed_cursor, ROSTER)
			== "ledger_dbg_tagged_int64_invalid",
		"DBG cursor rejects noncanonical tagged Int64 text"
	)
	var stale_fingerprint := ledger.duplicate(true)
	var stale_row := stale_fingerprint[dbg_index] as Dictionary
	(stale_row.get("state", {}) as Dictionary)["cursor"] = {
		"type": "int64", "decimal": "1"
	}
	_expect(
		not Adapter.validate_ledger(stale_fingerprint, ROSTER).is_empty(),
		"ledger rejects stale nested and outer state fingerprints"
	)
	var missing_personal := personal_saves.duplicate(true)
	missing_personal.pop_back()
	_expect(
		not bool(Adapter.capture_ledger(
			unified_save, missing_personal
		).get("accepted", true)),
		"capture rejects a missing player's two stream instances"
	)
	var duplicate_personal := personal_saves.duplicate(true)
	duplicate_personal[1] = duplicate_personal[0].duplicate(true)
	_expect(
		not bool(Adapter.capture_ledger(
			unified_save, duplicate_personal
		).get("accepted", true)),
		"capture rejects duplicate per-player ownership"
	)
	var forged_unified := unified_save.duplicate(true)
	var forged_authority := forged_unified.get("authority_state", {}) as Dictionary
	var forged_type := forged_authority.get("type_supply_state", {}) as Dictionary
	forged_type["rng_state"] = _different_rng_state(int(forged_type.get("rng_state", 1)))
	_expect(
		not bool(Adapter.capture_ledger(
			forged_unified, personal_saves
		).get("accepted", true)),
		"capture rejects tampered embedded unified state"
	)
	_expect(
		not Adapter.is_strict_pure_data({"runtime_object": RefCounted.new()}),
		"strict pure-data gate rejects runtime objects"
	)


func _test_isolation_and_no_second_authority(fixture: Dictionary) -> void:
	var unified_save := fixture.get("unified_save", {}) as Dictionary
	var personal_saves := fixture.get("personal_saves", []) as Array
	var source_before := {
		"unified": unified_save.duplicate(true),
		"personal": personal_saves.duplicate(true),
	}
	var ledger := Adapter.capture_ledger(
		unified_save, personal_saves
	).get("rng_stream_states", []) as Array
	var candidate := ledger.duplicate(true)
	var target_index := _row_index(
		candidate,
		"normal_deck_reshuffle_by_player",
		"player.alpha"
	)
	var target_row := candidate[target_index] as Dictionary
	var target_state := target_row.get("state", {}) as Dictionary
	var next_cursor := _tagged_value(target_state.get("cursor")) + 1
	target_state["cursor"] = {"type": "int64", "decimal": str(next_cursor)}
	target_state["stream_revision"] = {
		"type": "int64", "decimal": str(next_cursor)
	}
	target_state["state_fingerprint"] = Adapter.canonical_fingerprint(
		target_state, "state_fingerprint"
	)
	target_row["state_fingerprint"] = Adapter.canonical_fingerprint(
		target_row, "state_fingerprint"
	)
	_expect(
		Adapter.validate_ledger(candidate, ROSTER).is_empty(),
		"resealed candidate is structurally valid without becoming authoritative"
	)
	_expect(
		_all_rows_except_equal(ledger, candidate, target_index),
		"changing one concrete stream leaves every other stream byte-identical"
	)
	var candidate_before := candidate.duplicate(true)
	var rejected := Adapter.preflight_ledger(
		candidate, unified_save, personal_saves
	)
	_expect(
		not bool(rejected.get("accepted", true))
			and str(rejected.get("reason_code", ""))
				== "canonical_rng_ledger_embedded_mismatch",
		"validly resealed canonical row cannot override embedded owner state"
	)
	_expect(candidate == candidate_before, "failed preflight mutates no candidate row")
	_expect(
		unified_save == source_before.get("unified")
			and personal_saves == source_before.get("personal"),
		"failed preflight mutates no local RNG owner state"
	)

	var detached := Adapter.capture_ledger(
		unified_save, personal_saves
	).get("rng_stream_states", []) as Array
	var detached_row := detached[target_index] as Dictionary
	(detached_row.get("state", {}) as Dictionary)["cursor"] = {
		"type": "int64", "decimal": "99"
	}
	var source_rng := (
		(personal_saves[0] as Dictionary).get("state", {}) as Dictionary
	).get("reshuffle_rng", {}) as Dictionary
	_expect(
		_tagged_value(source_rng.get("cursor")) == 0,
		"captured rows are deep detached copies of local owner state"
	)
	var final_capture := Adapter.capture_ledger(unified_save, personal_saves)
	_expect(
		final_capture.get("rng_stream_states", []) == ledger,
		"candidate and detached-copy mutations cannot influence later capture"
	)


func _new_fixture() -> Dictionary:
	var unified := UnifiedCore.new()
	var started := unified.start_match(
		ROSTER,
		FIXED_SEED,
		{"match_instance_id": MATCH_INSTANCE_ID}
	)
	if not bool(started.get("accepted", false)):
		return {"ready": false, "reason_code": started.get("reason_code", "")}
	var personal_saves: Array = []
	for owner_variant in ROSTER:
		var dbg := DbgCore.new()
		var initialized := dbg.initialize(str(owner_variant), FIXED_SEED)
		if not bool(initialized.get("initialized", false)):
			return {
				"ready": false,
				"reason_code": initialized.get("reason_code", ""),
			}
		personal_saves.append(dbg.to_save_state())
	return {
		"ready": true,
		"unified_save": unified.save_state_v1(),
		"personal_saves": personal_saves,
	}


func _rows_have_exact_shape_and_fingerprints(rows: Array) -> bool:
	for row_variant in rows:
		if not (row_variant is Dictionary):
			return false
		var row := row_variant as Dictionary
		if not _has_exact_fields(row, Adapter.ROW_FIELDS):
			return false
		if row.get("state_fingerprint") \
				!= Adapter.canonical_fingerprint(row, "state_fingerprint"):
			return false
	return true


func _rows_are_sorted(rows: Array) -> bool:
	var previous_stream := ""
	var previous_instance := ""
	for index in range(rows.size()):
		var row := rows[index] as Dictionary
		var stream_id := str(row.get("stream_id", ""))
		var instance_id := str(row.get("stream_instance_id", ""))
		if index > 0 and (
			stream_id < previous_stream
			or (stream_id == previous_stream and instance_id <= previous_instance)
		):
			return false
		previous_stream = stream_id
		previous_instance = instance_id
	return true


func _profile_counts(rows: Array) -> Dictionary:
	var counts: Dictionary = {}
	for row_variant in rows:
		var profile_id := str((row_variant as Dictionary).get("state_profile_id", ""))
		counts[profile_id] = int(counts.get(profile_id, 0)) + 1
	return counts


func _logical_stream_set(rows: Array) -> Array:
	var seen: Dictionary = {}
	for row_variant in rows:
		seen[str((row_variant as Dictionary).get("stream_id", ""))] = true
	return _sorted_strings(seen.keys())


func _sorted_strings(values: Array) -> Array:
	var result: Array[String] = []
	for value_variant in values:
		result.append(str(value_variant))
	result.sort()
	return result


func _next_value_projection(rows: Array) -> Dictionary:
	var result: Dictionary = {}
	for row_variant in rows:
		var row := row_variant as Dictionary
		var stream_id := str(row.get("stream_id", ""))
		var instance_id := str(row.get("stream_instance_id", ""))
		var state := row.get("state", {}) as Dictionary
		var key := "%s:%s" % [stream_id, instance_id]
		if str(row.get("state_profile_id", "")) \
				== "dbg_tagged_sha256_counter_v1":
			var material := "%s:%s:%s:%s:%s:%d" % [
				"v0.7.1",
				str(state.get("algorithm_id", "")),
				stream_id,
				instance_id,
				str((state.get("seed", {}) as Dictionary).get("decimal", "")),
				_tagged_value(state.get("cursor")),
			]
			result[key] = {
				"next_value": int(material.sha256_text().substr(0, 15).hex_to_int()),
				"next_cursor": _tagged_value(state.get("cursor")) + 1,
			}
		else:
			var next_state := int(
				(int(state.get("rng_state", 0)) * RNG_MULTIPLIER) % RNG_MODULUS
			)
			result[key] = {
				"next_state": next_state,
				"next_draw_count": int(state.get("rng_draw_count", -1)) + 1,
			}
	return result


func _row_index(rows: Array, stream_id: String, instance_id: String) -> int:
	for index in range(rows.size()):
		var row := rows[index] as Dictionary
		if row.get("stream_id") == stream_id \
				and row.get("stream_instance_id") == instance_id:
			return index
	return -1


func _all_rows_except_equal(first: Array, second: Array, excluded_index: int) -> bool:
	if first.size() != second.size():
		return false
	for index in range(first.size()):
		if index != excluded_index and first[index] != second[index]:
			return false
	return true


func _different_rng_state(current: int) -> int:
	return 1 if current != 1 else 2


func _tagged_value(value: Variant) -> int:
	return str((value as Dictionary).get("decimal", "0")).to_int() \
		if value is Dictionary else 0


func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


func _same_string_set(first: Array, second: Array) -> bool:
	return _sorted_strings(first) == _sorted_strings(second)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("V071 CANONICAL RNG ADAPTER: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("V071_CANONICAL_RNG_ADAPTER_READY | status=PASS | checks=%d" % _checks)
		quit(0)
		return
	push_error(
		"V0.7.1 canonical RNG adapter test failed:\n- %s" % "\n- ".join(_failures)
	)
	quit(1)

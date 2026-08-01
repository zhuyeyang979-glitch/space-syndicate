extends SceneTree

const FIXTURE := preload("res://tests/fixtures/monster_save_full_state_fixture.gd")
const CODEC := preload("res://scripts/runtime/monster_save_wire_codec_v2.gd")
const SCALAR := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source_fixture := FIXTURE.create(self)
	var source_owner = source_fixture.get("owner")
	var rich := FIXTURE.build_nontrivial_state(source_fixture)
	_expect(bool(rich.get("ok", false)), "nontrivial Monster fixture is constructed")
	var save_a: Dictionary = rich.get("save", {}) if rich.get("save", {}) is Dictionary else {}
	var preflight_a: Dictionary = source_owner.call("preflight_save_data", save_a)
	_expect(bool(preflight_a.get("accepted", false)), "nontrivial Monster Save v2 passes full preflight: %s" % str(preflight_a.get("reason_code", "")))
	_expect(WIRE.is_closed_data(save_a), "Monster Save v2 is strict closed data")
	var source_before: Dictionary = source_owner.call("to_save_data")
	var source_second: Dictionary = source_owner.call("to_save_data")
	_expect(source_before == source_second, "repeated Monster Save capture is deterministic and mutation-free")

	var encoded_json := JSON.stringify(save_a)
	var parsed: Variant = JSON.parse_string(encoded_json)
	_expect(parsed is Dictionary and WIRE.is_closed_data(parsed), "Monster Save v2 remains closed after real JSON parse")
	var target_fixture := FIXTURE.create(self)
	var target_owner = target_fixture.get("owner")
	var applied: Dictionary = target_owner.call("apply_save_data", parsed as Dictionary if parsed is Dictionary else {})
	_expect(bool(applied.get("applied", false)), "JSON-parsed Monster Save v2 applies atomically: %s" % str(applied.get("reason_code", "")))
	var save_b: Dictionary = target_owner.call("to_save_data")
	_expect(save_a == save_b, "Monster Save v2 A equals B after JSON roundtrip")
	_expect(JSON.stringify(save_a).sha256_text() == JSON.stringify(save_b).sha256_text(), "Monster Save v2 fingerprint is stable")

	var decoded_a := CODEC.decode_save_state(save_a)
	var decoded_b := CODEC.decode_save_state(save_b)
	_expect(bool(decoded_a.get("ok", false)) and bool(decoded_b.get("ok", false)), "both Save captures decode through the unique v2 codec")
	var raw_a: Dictionary = decoded_a.get("value", {}) if decoded_a.get("value", {}) is Dictionary else {}
	var raw_b: Dictionary = decoded_b.get("value", {}) if decoded_b.get("value", {}) is Dictionary else {}
	_expect(_same_value(raw_a, raw_b), "decoded authoritative runtime state restores exactly")
	_expect(_float_bits_equal(raw_a.get("monster_timer"), raw_b.get("monster_timer")), "monster_timer restores bit-exactly")
	_expect(_float_bits_equal(raw_a.get("special_monster_timer"), raw_b.get("special_monster_timer")), "special_monster_timer restores bit-exactly")
	var roster_a := raw_a.get("auto_monsters", []) as Array
	var roster_b := raw_b.get("auto_monsters", []) as Array
	_expect(roster_a.size() >= 2 and roster_b.size() == roster_a.size(), "active and recovery roster restores")
	if roster_a.size() >= 2 and roster_b.size() >= 2:
		var first_a := roster_a[0] as Dictionary
		var first_b := roster_b[0] as Dictionary
		var second_a := roster_a[1] as Dictionary
		var second_b := roster_b[1] as Dictionary
		_expect(_vector_bits_equal(first_a.get("world_position"), first_b.get("world_position")) and _vector_bits_equal(first_a.get("linear_move_target_position"), first_b.get("linear_move_target_position")), "active movement vectors restore component bits")
		_expect(_float_bits_equal(first_a.get("remaining_time"), first_b.get("remaining_time")) and _float_bits_equal(first_a.get("linear_move_speed_mps"), first_b.get("linear_move_speed_mps")), "movement and lifecycle floats restore bit-exactly")
		_expect(bool(second_a.get("down", false)) and bool(second_b.get("down", false)) and _float_bits_equal(second_a.get("revive_timer"), second_b.get("revive_timer")), "down/recovery state restores exactly")
	_expect(_same_value(raw_a.get("active_monster_wagers"), raw_b.get("active_monster_wagers")) and _same_value(raw_a.get("resolved_monster_wager_history"), raw_b.get("resolved_monster_wager_history")), "active and resolved wager lifecycle restores exactly")
	_expect(_same_value(raw_a.get("monster_wager_settlement_terminal_journal"), raw_b.get("monster_wager_settlement_terminal_journal")), "wager terminal journal restores exactly once")
	_expect(_same_value(raw_a.get("monster_card_atomic_reservations"), raw_b.get("monster_card_atomic_reservations")) and _same_value(raw_a.get("monster_card_atomic_terminal_journal"), raw_b.get("monster_card_atomic_terminal_journal")) and _same_value(raw_a.get("monster_card_atomic_presentation_journal"), raw_b.get("monster_card_atomic_presentation_journal")), "atomic reservation, terminal, and presentation journals restore exactly")
	_expect(int(raw_b.get("autonomous_move_sequence", -1)) == 11 and int(raw_b.get("auto_monster_action_sequence", -1)) == 13, "both command sequences restore without reuse")
	_expect(_same_value(raw_a.get("bankruptcy_estate_journal"), raw_b.get("bankruptcy_estate_journal")) and not (raw_b.get("bankruptcy_estate_journal", {}) as Dictionary).is_empty(), "bankruptcy participant journal restores exactly")

	FIXTURE.cleanup(source_fixture)
	FIXTURE.cleanup(target_fixture)
	await process_frame
	print("MONSTER_SAVE_NONTRIVIAL_JSON_ROUNDTRIP_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Monster Save nontrivial JSON roundtrip failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)


func _float_bits_equal(left: Variant, right: Variant) -> bool:
	return left is float and right is float and SCALAR.f64_bits_hex(float(left)) == SCALAR.f64_bits_hex(float(right))


func _vector_bits_equal(left: Variant, right: Variant) -> bool:
	if not (left is Vector2) or not (right is Vector2):
		return false
	var left_vector := left as Vector2
	var right_vector := right as Vector2
	return SCALAR.f64_bits_hex(left_vector.x) == SCALAR.f64_bits_hex(right_vector.x) \
			and SCALAR.f64_bits_hex(left_vector.y) == SCALAR.f64_bits_hex(right_vector.y)


func _same_value(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if left is Dictionary:
		var left_dictionary := left as Dictionary
		var right_dictionary := right as Dictionary
		if left_dictionary.size() != right_dictionary.size():
			return false
		for key_variant: Variant in left_dictionary.keys():
			if not right_dictionary.has(key_variant) or not _same_value(left_dictionary.get(key_variant), right_dictionary.get(key_variant)):
				return false
		return true
	if left is Array:
		var left_array := left as Array
		var right_array := right as Array
		if left_array.size() != right_array.size():
			return false
		for index in range(left_array.size()):
			if not _same_value(left_array[index], right_array[index]):
				return false
		return true
	if left is float:
		return SCALAR.f64_bits_hex(float(left)) == SCALAR.f64_bits_hex(float(right))
	if left is Vector2:
		return _vector_bits_equal(left, right)
	return left == right


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

extends SceneTree

const FIXTURE := preload("res://tests/product_market_save_v2_test_fixture.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var source := FIXTURE.make_controller(29.999, 7, 12)
	var target := FIXTURE.make_controller(4.5, 1, 2)
	var wire := source.to_save_data()
	var runtime_before := source.runtime_state_snapshot()
	_expect(int(wire.get("state_version", 0)) == 2 and str(wire.get("ruleset_id", "")) == "v0.6", "new-session checkpoint is Product Market Save v2")
	_expect(FIXTURE.timer_is_f64_tag(wire), "market_timer is a f64_bits_hex_v1 closed tag")
	var restored := target.restore_new_session_checkpoint(wire)
	_expect(bool(restored.get("applied", false)) and bool(restored.get("restored", false)), "new-session restore accepts Save v2 closed wire")
	var wire_diff := _first_difference(wire, target.to_save_data())
	var runtime_diff := _first_difference(runtime_before, target.runtime_state_snapshot())
	_expect(wire_diff.is_empty(), "new-session restore recaptures byte-equivalent semantic wire: %s" % wire_diff)
	_expect(runtime_diff.is_empty(), "new-session restore recovers decoded runtime state exactly: %s" % runtime_diff)
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/product_market_runtime_controller.gd")
	var decoder_source := _function_source(controller_source, "_decode_and_normalize_save_v2")
	var preflight_source := _function_source(controller_source, "preflight_save_data")
	var apply_source := _function_source(controller_source, "apply_save_data")
	var restore_source := _function_source(controller_source, "restore_new_session_checkpoint")
	_expect(decoder_source.count("CLOSED_SCALAR_CODEC.decode_tree(") == 1 and preflight_source.contains("_decode_and_normalize_save_v2") and apply_source.contains("_decode_and_normalize_save_v2") and not restore_source.contains("decode_tree("), "Save v2 has one private decoder source")
	_expect(not preflight_source.contains("decoded_state"), "public Save preflight exposes closed normalized wire only")
	_expect(controller_source.count("func _apply_decoded_save_v2(") == 1 and apply_source.contains("_apply_decoded_save_v2") and restore_source.contains("apply_save_data(checkpoint)"), "Save apply and new-session restore share one application path")
	_expect(not restore_source.contains("float(checkpoint.get") and not controller_source.contains("func decode_f64("), "restore has no raw float fallback or duplicate F64 codec")
	var projected_source := FIXTURE.make_controller(14.25, 3, 5)
	var projected_ids: Array = projected_source.product_market.keys()
	projected_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	var projected_id := str(projected_ids[0])
	var projected_entry := (projected_source.product_market.get(projected_id, {}) as Dictionary).duplicate(true)
	projected_entry["weather_price_growth_multiplier"] = 1.2
	projected_entry["weather_modifier"] = 9
	projected_entry["weather_contributions"] = [{"derived": true}]
	projected_entry["weather_driver_summary"] = "derived"
	projected_source.product_market[projected_id] = projected_entry
	var projected_wire := projected_source.to_save_data()
	var projected_target := FIXTURE.make_controller(2.0, 0, 1)
	var projected_restore := projected_target.restore_new_session_checkpoint(projected_wire)
	var restored_entry := projected_target.product_market.get(projected_id, {}) as Dictionary
	_expect(bool(projected_restore.get("restored", false)) and not restored_entry.has("weather_price_growth_multiplier") \
			and not restored_entry.has("weather_modifier") and not restored_entry.has("weather_contributions") \
			and not restored_entry.has("weather_driver_summary"), "new-session restore clears derived weather projection without refreshing prices")
	source.free()
	target.free()
	projected_source.free()
	projected_target.free()
	_finish()


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _first_difference(left: Variant, right: Variant, path := "$") -> String:
	if typeof(left) != typeof(right):
		return "%s type %s != %s" % [path, type_string(typeof(left)), type_string(typeof(right))]
	if left is Dictionary:
		var left_keys: Array = (left as Dictionary).keys()
		var right_keys: Array = (right as Dictionary).keys()
		left_keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		right_keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		if left_keys != right_keys:
			return "%s keys %s != %s" % [path, JSON.stringify(left_keys), JSON.stringify(right_keys)]
		for key in left_keys:
			var nested := _first_difference((left as Dictionary).get(key), (right as Dictionary).get(key), "%s.%s" % [path, str(key)])
			if not nested.is_empty():
				return nested
		return ""
	if left is Array:
		if (left as Array).size() != (right as Array).size():
			return "%s size %d != %d" % [path, (left as Array).size(), (right as Array).size()]
		for index in range((left as Array).size()):
			var nested := _first_difference((left as Array)[index], (right as Array)[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return ""
	return "" if left == right else "%s %s != %s" % [path, str(left), str(right)]


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("PRODUCT_MARKET_NEW_SESSION_CHECKPOINT_DECODE_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	if not _failures.is_empty():
		push_error("Product Market new-session checkpoint decode failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)

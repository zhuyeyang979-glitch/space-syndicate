extends SceneTree

const MARKET := preload("res://scripts/runtime/product_market_runtime_controller.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const HANDSHAKE := preload("res://scripts/runtime/ruleset_save_handshake_service.gd")
const CODEC := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var source := MARKET.new() as ProductMarketRuntimeController
	var target := MARKET.new() as ProductMarketRuntimeController
	var handshake := HANDSHAKE.new() as RulesetSaveHandshakeService
	source.product_market = {"fixture.product": _entry()}
	source.business_cycle_count = 7
	source.market_timer = 29.999
	source.futures_position_sequence = 12
	var save := source.to_save_data()
	_expect(int(save.get("state_version", 0)) == 2 and str(save.get("ruleset_id", "")) == "v0.6", "Product Market emits Save State v2")
	_expect(WIRE.is_closed_data(save) and _raw_float_count(save) == 0, "Product Market Save v2 is strict closed data")
	var entry := (save.get("product_market", {}) as Dictionary).get("fixture.product", {}) as Dictionary
	_expect(_is_f64_tag(entry.get("growth_multiplier")) and _is_f64_tag(save.get("market_timer")), "growth and timer use the shared F64 tag")
	var disk := handshake.encode_codec_value(save)
	var parsed: Variant = JSON.parse_string(JSON.stringify(disk.get("value")))
	var readback := handshake.decode_codec_value(parsed)
	var apply := target.apply_save_data(readback.get("value", {}) as Dictionary)
	var roundtrip := target.to_save_data()
	_expect(bool(apply.get("applied", false)) and roundtrip == save, "Product Market Save JSON apply recaptures exactly")
	var roundtrip_entry := (roundtrip.get("product_market", {}) as Dictionary).get("fixture.product", {}) as Dictionary
	_expect(roundtrip_entry.get("growth_multiplier") == entry.get("growth_multiplier"), "growth multiplier bits survive Save apply")
	_expect(roundtrip.get("market_timer") == save.get("market_timer"), "market timer bits survive Save apply")
	_expect(roundtrip_entry.get("raw_trend") == entry.get("raw_trend") \
			and roundtrip_entry.get("price_step_cap") == entry.get("price_step_cap") \
			and roundtrip_entry.get("driver_summary") == entry.get("driver_summary"), \
			"authoritative price diagnostics survive Save apply")

	var before_invalid := target.capture_runtime_checkpoint()
	var raw_float := save.duplicate(true)
	raw_float["market_timer"] = 1.25
	var rejected := target.apply_save_data(raw_float)
	_expect(not bool(rejected.get("applied", true)) and target.capture_runtime_checkpoint() == before_invalid, "raw float Save fails before mutation")
	var legacy := save.duplicate(true)
	legacy.erase("state_version")
	legacy.erase("ruleset_id")
	_expect(str(target.preflight_save_data(legacy).get("reason_code", "")) == "product_market_save_v2_invalid", "legacy Product Market Save fails closed")

	var checkpoint_a := source.capture_runtime_checkpoint()
	_expect(int(checkpoint_a.get("schema_version", 0)) == 2 and WIRE.is_closed_data(checkpoint_a) and _raw_float_count(checkpoint_a) == 0, "Product Market checkpoint v2 is closed")
	source.market_timer = -0.25
	(source.product_market.get("fixture.product", {}) as Dictionary)["growth_multiplier"] = 2.75
	var restored := source.restore_runtime_checkpoint(checkpoint_a)
	var checkpoint_b := source.capture_runtime_checkpoint()
	_expect(bool(restored.get("restored", false)) and checkpoint_b == checkpoint_a, "Product Market checkpoint A equals B after mutation and restore")

	var negative_checkpoint := checkpoint_a.duplicate(true)
	negative_checkpoint["market_timer"] = _f64_tag(-0.25)
	var negative_restore := source.restore_runtime_checkpoint(negative_checkpoint)
	_expect(bool(negative_restore.get("restored", false)) and source.capture_runtime_checkpoint().get("market_timer") == negative_checkpoint.get("market_timer"), "runtime checkpoint preserves a finite negative timer")
	_expect(source.to_save_data().is_empty(), "persistent Save rejects a negative market timer")
	var live_before_tamper := source.capture_runtime_checkpoint()
	var tampered := checkpoint_a.duplicate(true)
	var timer_tag := (tampered.get("market_timer", {}) as Dictionary).duplicate(true)
	timer_tag["bits"] = str(timer_tag.get("bits", "")).to_upper()
	tampered["market_timer"] = timer_tag
	var tampered_result := source.restore_runtime_checkpoint(tampered)
	_expect(not bool(tampered_result.get("restored", true)) and source.capture_runtime_checkpoint() == live_before_tamper, "malformed final F64 tag causes zero checkpoint mutation")

	handshake.free()
	source.free()
	target.free()
	_finish()


func _entry() -> Dictionary:
	return {
		"tier": "fixture",
		"base_price": 100,
		"price": 113,
		"trend": 2,
		"raw_trend": 4,
		"price_step_cap": 2,
		"volatility": 4,
		"supply": 3,
		"demand": 7,
		"disrupted": 0,
		"price_history": [100, 113],
		"base_growth_multiplier": 1.0,
		"growth_multiplier": 1.125,
		"growth_seconds": 29.999,
		"growth_turns": 1,
		"growth_source": "fixture",
		"base_growth_source": "fixture-base",
		"base_route_flow_multiplier": 1.0,
		"route_flow_multiplier": 1.25,
		"route_flow_seconds": 30.0,
		"route_flow_turns": 1,
		"route_flow_source": "fixture",
		"base_route_flow_source": "fixture-base",
		"market_contract_demand": 2,
		"market_contract_supply": 1,
		"market_contract_seconds": 30.0,
		"market_contract_turns": 1,
		"market_contract_source": "fixture",
		"driver_summary": "fixture-driver",
		"futures_positions": [_position()],
		"weather_price_growth_multiplier": 1.05,
		"weather_modifier": 1,
		"weather_contributions": [],
		"weather_driver_summary": "fixture-weather",
	}


func _position() -> Dictionary:
	return {
		"position_id": 12,
		"owner": 0,
		"source": "fixture.card",
		"card_id": "fixture.card",
		"product_id": "fixture.product",
		"direction": "up",
		"baseline_price": 100,
		"opened_at": 12.125,
		"expires_at": 42.124,
		"duration_seconds": 29.999,
		"multiplier": 1.5,
		"units": 1,
		"warehouse_district": 0,
		"warehouse_region_id": "region.001",
		"action_fee_cash": 0,
		"locked_margin": 100,
		"maximum_gain": 200,
		"maximum_loss": 100,
		"terms_version": "v0.6",
		"settlement_formula_id": "fixture-settlement",
		"warehouse_loss_formula_id": "fixture-loss",
		"settled": false,
	}


func _f64_tag(value: float) -> Dictionary:
	return (CODEC.encode_f64(value).get("value", {}) as Dictionary).duplicate(true)


func _is_f64_tag(value: Variant) -> bool:
	return value is Dictionary \
			and str((value as Dictionary).get("codec", "")) == CODEC.F64_CODEC_ID \
			and str((value as Dictionary).get("bits", "")).length() == 16


func _raw_float_count(value: Variant) -> int:
	if value is float:
		return 1
	if value is Array:
		var array_count := 0
		for item in value as Array:
			array_count += _raw_float_count(item)
		return array_count
	if value is Dictionary:
		var dictionary_count := 0
		for item in (value as Dictionary).values():
			dictionary_count += _raw_float_count(item)
		return dictionary_count
	return 0


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("PRODUCT_MARKET_SAVE_V2_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Product Market Save v2 failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)

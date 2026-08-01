extends SceneTree

const COMMODITY_SCENE := preload("res://scenes/runtime/CommodityCardInventoryRuntimeController.tscn")
const PRODUCT := preload("res://scripts/runtime/product_market_runtime_controller.gd")
const DISTRICT := preload("res://scripts/runtime/district_purchase_runtime_controller.gd")
const OWNER := preload("res://scripts/runtime/card_inventory_save_owner.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const CODEC := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")
const HANDSHAKE := preload("res://scripts/runtime/ruleset_save_handshake_service.gd")
const INSPECTOR := preload("res://scripts/tools/card_inventory_checkpoint_purity_inspector_v1.gd")
const FAULT_STAGES := ["commodity_after", "product_market_after", "district_purchase_after"]


class StatePortFixture:
	extends Node

	var saved := {"state_version": 1, "ruleset_id": "v0.6", "journal": {}, "next_reservation_sequence": 1}
	var checkpoint := _new_checkpoint()

	func actor_player_indices() -> Dictionary: return {}
	func register_player(_actor_id: String, _state: Dictionary) -> Dictionary: return {"configured": true}
	func read_player(_actor_id: String) -> Dictionary: return {"found": false}
	func reserve_transaction(_transaction_id: String, _intent_hash: String, _expected: Dictionary, _actors: Array) -> Dictionary: return {"reserved": false}
	func prepare_reserved_mutations(_reservation: Dictionary, _mutations: Dictionary) -> Dictionary: return {"prepared": false}
	func commit_reserved(_reservation: Dictionary, _receipt: Dictionary = {}) -> Dictionary: return {"committed": false}
	func abort_reserved(_reservation: Dictionary) -> Dictionary: return {"aborted": true}
	func to_save_data() -> Dictionary: return saved.duplicate(true)
	func preflight_save_data(data: Dictionary) -> Dictionary:
		return {"accepted": data.get("journal") is Dictionary, "normalized_state": data.duplicate(true), "reason_code": "fixture_state_valid"}
	func apply_save_data(data: Dictionary) -> Dictionary:
		saved = data.duplicate(true)
		return {"applied": true}
	func checkpoint_status() -> Dictionary: return {"can_checkpoint": true}
	func capture_runtime_checkpoint() -> Dictionary: return checkpoint.duplicate(true)
	func restore_runtime_checkpoint(data: Dictionary) -> Dictionary:
		checkpoint = data.duplicate(true)
		return {"applied": true, "restored": true}
	func reset_state() -> void: pass
	func _new_checkpoint() -> Dictionary:
		return {
			"schema_version": 1,
			"reservations": {},
			"prepared_mutations": {},
			"player_locks": {},
			"inflight_transactions": {},
			"journal": {},
			"reservation_results": {},
			"bankruptcy_estate_journal": {},
			"next_reservation_sequence": 1,
			"reserve_count": 0,
			"commit_count": 0,
			"abort_count": 0,
			"reject_count": 0,
			"last_reason_code": "",
		}


class FlowFixture:
	extends Node
	func install_commodity(_request: Dictionary) -> Dictionary: return {}
	func finalize_commodity_installation(_receipt: Dictionary) -> Dictionary: return {}
	func rollback_commodity_installation(_transaction_id: String) -> Dictionary: return {}
	func card_effect_candidates_snapshot(_request: Dictionary = {}) -> Dictionary: return {}
	func prepare_card_effect_batch(_request: Dictionary) -> Dictionary: return {}
	func commit_card_effect_batch(_request: Dictionary) -> Dictionary: return {}
	func rollback_card_effect_batch(_request: Dictionary) -> Dictionary: return {}
	func finalize_card_effect_batch(_request: Dictionary) -> Dictionary: return {}


class InfrastructureFixture:
	extends Node
	func facilities_snapshot() -> Array: return []
	func region_snapshot(_region_id: String) -> Dictionary: return {}
	func apply_facility_action(_request: Dictionary) -> Dictionary: return {}
	func rollback_facility_action(_request: Dictionary) -> Dictionary: return {}
	func finalize_facility_action(_request: Dictionary) -> Dictionary: return {}
	func facility_action_checkpoint_status() -> Dictionary: return {"can_checkpoint": true}
	func facility_rollback_atomic_ready() -> bool: return true


class QuoteAuthorityFixture:
	extends Node

	var quotes: Dictionary = {}
	var next_quote_sequence := 2

	func install(quote: Dictionary) -> void:
		quotes[str(quote.get("quote_id", ""))] = quote.duplicate(true)
	func export_quote_for_session(quote_id: String) -> Dictionary:
		return (quotes.get(quote_id, {}) as Dictionary).duplicate(true) if quotes.get(quote_id) is Dictionary else {}
	func export_quote_for_pending_session(quote_id: String) -> Dictionary: return export_quote_for_session(quote_id)
	func preflight_quote_from_session(snapshot: Dictionary) -> Dictionary:
		return {"accepted": not snapshot.is_empty(), "normalized_state": snapshot.duplicate(true), "reason_code": "fixture_quote_valid"}
	func restore_quote_from_session(snapshot: Dictionary) -> Dictionary:
		install(snapshot)
		return {"restored": true, "quote": snapshot.duplicate(true)}
	func restore_pending_quote_from_session(snapshot: Dictionary) -> Dictionary: return restore_quote_from_session(snapshot)
	func quote_snapshot(quote_id: String) -> Dictionary: return export_quote_for_session(quote_id)
	func capture_allocator_cursor() -> Dictionary:
		return {"schema_version": 1, "next_quote_sequence": next_quote_sequence}
	func restore_allocator_cursor(cursor: Dictionary) -> Dictionary:
		next_quote_sequence = int(cursor.get("next_quote_sequence", 1))
		return {"restored": true}
	func capture_runtime_checkpoint() -> Dictionary:
		return {"schema_version": 1, "next_quote_sequence": next_quote_sequence, "quotes_by_id": quotes.duplicate(true)}
	func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
		if int(checkpoint.get("schema_version", 0)) != 1 \
				or not (checkpoint.get("quotes_by_id") is Dictionary) \
				or not (checkpoint.get("next_quote_sequence") is int):
			return {"restored": false, "reason_code": "fixture_quote_checkpoint_invalid"}
		quotes = (checkpoint.get("quotes_by_id", {}) as Dictionary).duplicate(true)
		next_quote_sequence = int(checkpoint.get("next_quote_sequence", 1))
		return {"restored": true}
	func reset_state() -> void:
		quotes.clear()
		next_quote_sequence = 1


var _checks := 0
var _failures: Array[String] = []
var _fault_passed := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source: Dictionary = await _fixture("source", true)
	_expect(bool(source.get("ready", false)), "all three real child Owners and the composite Owner are ready: %s" % JSON.stringify(source.get("diagnostics", {})))
	if not bool(source.get("ready", false)):
		await _release([source])
		_finish()
		return
	var owner := source.get("owner") as CardInventorySaveOwner
	var observation_before_save := _observation(source)
	var save_a := owner.to_save_data()
	var observation_after_save := _observation(source)
	var observation_before_checkpoint := _observation(source)
	var checkpoint_a := owner.capture_runtime_checkpoint()
	var observation_after_checkpoint := _observation(source)
	var save_report := INSPECTOR.inspect(save_a)
	var checkpoint_report := INSPECTOR.inspect(checkpoint_a)

	_expect(int(save_a.get("schema_version", 0)) == 4 and WIRE.is_closed_data(save_a), "Card Inventory Save v4 is strict closed data")
	_expect(int(checkpoint_a.get("schema_version", 0)) == 2 and WIRE.is_closed_data(checkpoint_a), "Card Inventory checkpoint v2 is strict closed data")
	_expect(int(save_report.get("strict_non_closed_leaf_count", -1)) == 0, "persistent Save has zero non-closed leaves")
	_expect(int(checkpoint_report.get("strict_non_closed_leaf_count", -1)) == 0, "runtime checkpoint has zero non-closed leaves")
	_expect(observation_before_save == observation_after_save, "Save capture is observational and mutation-free")
	_expect(observation_before_checkpoint == observation_after_checkpoint, "checkpoint capture is observational and mutation-free")
	_expect(_raw_float_count(save_a) == 0 and _f64_tag_count(save_a) > 0, "Save contains shared F64 tags and no raw float")
	_expect(_raw_float_count(checkpoint_a) == 0 and _f64_tag_count(checkpoint_a) > 0, "checkpoint contains shared F64 tags and no raw float")
	var envelope_codec := HANDSHAKE.new() as RulesetSaveHandshakeService
	var encoded_save := envelope_codec.encode_codec_value(save_a)
	var parsed_encoded: Variant = JSON.parse_string(JSON.stringify(encoded_save.get("value")))
	var decoded_save := envelope_codec.decode_codec_value(parsed_encoded)
	envelope_codec.free()
	var parsed: Variant = decoded_save.get("value")
	var json_difference := _first_difference(save_a, parsed, "$")
	if not json_difference.is_empty():
		print("CARD_INVENTORY_SAVE_JSON_FIRST_DIFFERENCE|%s" % JSON.stringify(json_difference))
	_expect(bool(encoded_save.get("ok", false)) and bool(decoded_save.get("ok", false)) \
			and parsed is Dictionary and parsed == save_a, \
			"Save v4 survives production Envelope codec plus JSON roundtrip exactly")

	var target: Dictionary = await _fixture("target", false)
	_expect(bool(target.get("ready", false)), "isolated equivalent target composition is ready")
	if bool(target.get("ready", false)):
		var target_owner := target.get("owner") as CardInventorySaveOwner
		var target_apply := target_owner.apply_save_data(parsed as Dictionary)
		if not bool(target_apply.get("applied", false)):
			print("CARD_INVENTORY_SAVE_APPLY_FAILURE|%s" % JSON.stringify({
				"reason_code": str(target_apply.get("reason_code", "")),
				"failing_child": str(target_apply.get("failing_child", "")),
				"rollback_attempted": bool(target_apply.get("rollback_attempted", false)),
				"rollback_complete": bool(target_apply.get("rollback_complete", false)),
			}))
		var save_b := target_owner.to_save_data()
		_expect(bool(target_apply.get("applied", false)) and save_b == save_a, "Card Inventory Save A equals B after isolated apply")
		_expect(WIRE.fingerprint(save_b) == WIRE.fingerprint(save_a), "Save A/B fingerprints match")
		_expect(_product_tag(save_b, "market_timer") == _product_tag(save_a, "market_timer"), "market timer bits survive Save roundtrip")
		_expect(_growth_tag(save_b) == _growth_tag(save_a), "growth multiplier bits survive Save roundtrip")
		_expect(_district_cursor(save_b) == _district_cursor(save_a), "District allocator cursor survives Save roundtrip")
		_expect(_commodity_field(save_b, "transaction_journal") == _commodity_field(save_a, "transaction_journal"), "transaction journal survives Save roundtrip")
		_expect(_commodity_field(save_b, "terminal_operations") == _commodity_field(save_a, "terminal_operations"), "terminal operations survive Save roundtrip")

	var commodity_before := _commodity_snapshot(source)
	var product_before := _product_snapshot(source)
	var district_before := _district_snapshot(source)
	_mutate(source, 1)
	var restored := owner.restore_runtime_checkpoint(checkpoint_a)
	var checkpoint_b := owner.capture_runtime_checkpoint()
	_expect(bool(restored.get("restored", false)) and checkpoint_b == checkpoint_a, "composite checkpoint A equals B after restore")
	_expect(_commodity_snapshot(source) == commodity_before, "Commodity child restores exactly")
	_expect(_product_snapshot(source) == product_before, "Product Market child restores exactly")
	_expect(_district_snapshot(source) == district_before, "District Purchase child and allocator restore exactly")
	_expect(_district_key_map(checkpoint_b) == _district_key_map(checkpoint_a), "canonical District player-key map survives restore")

	for stage_index in range(FAULT_STAGES.size()):
		var stage := str(FAULT_STAGES[stage_index])
		_mutate(source, stage_index + 10)
		var live := owner.capture_runtime_checkpoint()
		var armed := owner.arm_test_fault_once(stage)
		var failed := owner.apply_save_data(save_a)
		var passed := armed and not bool(failed.get("applied", true)) \
				and bool(failed.get("rollback_attempted", false)) \
				and bool(failed.get("rollback_complete", false)) \
				and owner.capture_runtime_checkpoint() == live
		if passed:
			_fault_passed += 1
		_expect(passed, "%s fault restores all three child checkpoints exactly" % stage)

	print("CARD_INVENTORY_COMPOSITE_RESTORE_PARITY_EVIDENCE|%s" % JSON.stringify({
		"persistent_leaf_count": int(save_report.get("checkpoint_leaf_count", 0)),
		"persistent_non_closed_leaf_count_after": int(save_report.get("strict_non_closed_leaf_count", -1)),
		"checkpoint_leaf_count": int(checkpoint_report.get("checkpoint_leaf_count", 0)),
		"checkpoint_non_closed_leaf_count_after": int(checkpoint_report.get("strict_non_closed_leaf_count", -1)),
		"save_f64_tag_count": _f64_tag_count(save_a),
		"checkpoint_f64_tag_count": _f64_tag_count(checkpoint_a),
		"save_capture_mutation_count": 0 if observation_before_save == observation_after_save else 1,
		"checkpoint_capture_mutation_count": 0 if observation_before_checkpoint == observation_after_checkpoint else 1,
		"fault_rollback_tests": "%d/%d" % [_fault_passed, FAULT_STAGES.size()],
		"private_payload_redacted": true,
	}))
	await _release([source, target])
	_finish()


func _fixture(label: String, nontrivial: bool) -> Dictionary:
	var state_port := StatePortFixture.new()
	var flow := FlowFixture.new()
	var infrastructure := InfrastructureFixture.new()
	var commodity := COMMODITY_SCENE.instantiate() as CommodityCardInventoryRuntimeController
	var product := PRODUCT.new() as ProductMarketRuntimeController
	var quote_authority := QuoteAuthorityFixture.new()
	var district := DISTRICT.new() as DistrictPurchaseRuntimeController
	var owner := OWNER.new() as CardInventorySaveOwner
	var nodes: Array[Node] = [state_port, flow, infrastructure, commodity, product, quote_authority, district, owner]
	for node in nodes:
		node.name = "%s%s" % [label.capitalize(), node.get_class()]
		root.add_child(node)
	await process_frame
	var commodity_config := commodity.configure({"ruleset_id": "v0.6"}, state_port, flow, infrastructure)
	district.set_quote_authority(quote_authority)
	district.configure()
	var owner_config := owner.configure_dependencies(commodity, product, district)
	var fixture := {
		"ready": bool(commodity_config.get("configured", false)) and bool(owner_config.get("configured", false)),
		"diagnostics": {
			"commodity_configured": bool(commodity_config.get("configured", false)),
			"commodity_reason": str(commodity_config.get("reason_code", "")),
			"owner_configured": bool(owner_config.get("configured", false)),
			"owner_reason": str(owner_config.get("reason_code", "")),
		},
		"nodes": nodes,
		"commodity": commodity,
		"product": product,
		"quote_authority": quote_authority,
		"district": district,
		"owner": owner,
	}
	if nontrivial and bool(fixture.get("ready", false)):
		var seed_diagnostics := _seed_nontrivial(fixture)
		(fixture.get("diagnostics", {}) as Dictionary)["seed"] = seed_diagnostics
		fixture["ready"] = bool(seed_diagnostics.get("ready", false))
	return fixture


func _seed_nontrivial(fixture: Dictionary) -> Dictionary:
	var commodity := fixture.get("commodity") as CommodityCardInventoryRuntimeController
	var product := fixture.get("product") as ProductMarketRuntimeController
	var quote_authority := fixture.get("quote_authority") as QuoteAuthorityFixture
	var district := fixture.get("district") as DistrictPurchaseRuntimeController
	var card: Dictionary = commodity.catalog().call("card_snapshot", "commodity.star_dew_berry.rank_1")
	var market_card: Dictionary = commodity.catalog().call("card_snapshot", "facility.factory.life.rank_1")
	var belt := commodity.configure_belt(7, [{
		"item_id": "belt:composite",
		"card": card,
		"claimable": true,
		"visible_actor_ids": ["player.0"],
	}])
	var market := commodity.configure_market(11, {
		"item_id": "market:composite",
		"card": market_card,
		"price_cash": 4,
		"claimable": true,
		"legal_actor_ids": ["player.0"],
		"source_district_index": 2,
		"source_region_id": "region.002",
		"supply_revision": "supply:composite",
	})
	var seeded_journal := _seed_commodity_journal(commodity)
	product.product_market = {"fixture.product": _product_entry()}
	product.business_cycle_count = 7
	product.market_timer = 29.999
	product.futures_position_sequence = 12
	var quote := {
		"quote_id": "market-quote-1000-1",
		"player_index": 0,
		"district_index": 2,
		"card_id": "fixture.card",
		"supply_revision": "fixture-r1",
	}
	quote_authority.install(quote)
	quote_authority.next_quote_sequence = 9
	var opened := district.open_window(0, 2, {"supply_revision": "fixture-r1"})
	var selected := district.acknowledge_card_selection(0, 2, "fixture.card", "fixture-r1")
	var attached := district.attach_quote(0, 2, quote)
	var pending := district.reserve_pending_discard({
		"player_index": 0,
		"district_index": 2,
		"card_id": "fixture.card",
		"quote_id": "market-quote-1000-1",
		"price": 101,
		"opened_at": 12.125,
	})
	var ready := not card.is_empty() and not market_card.is_empty() and bool(belt.get("configured", false)) \
			and bool(market.get("configured", false)) and seeded_journal \
			and not opened.is_empty() and not selected.is_empty() \
			and not attached.is_empty() and not pending.is_empty()
	return {
		"ready": ready,
		"card_present": not card.is_empty(),
		"market_card_present": not market_card.is_empty(),
		"belt_configured": bool(belt.get("configured", false)),
		"belt_reason": str(belt.get("reason_code", "")),
		"market_configured": bool(market.get("configured", false)),
		"market_reason": str(market.get("reason_code", "")),
		"journal_seeded": seeded_journal,
		"window_opened": not opened.is_empty(),
		"selection_acknowledged": not selected.is_empty(),
		"quote_attached": not attached.is_empty(),
		"pending_reserved": not pending.is_empty(),
	}


func _seed_commodity_journal(commodity: CommodityCardInventoryRuntimeController) -> bool:
	var initial := commodity.to_save_data()
	var decoded := CODEC.decode_tree(initial)
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is Dictionary):
		return false
	var raw := (decoded.get("value", {}) as Dictionary).duplicate(true)
	var journal := raw.get("transaction_journal", {}) as Dictionary
	var terminals := raw.get("terminal_operations", {}) as Dictionary
	for operation in ["belt_claim", "market_purchase"]:
		var transaction_id := "alpha04c-composite-%s" % operation
		var record := {
			"intent_hash": ("intent:%s" % operation).sha256_text(),
			"result": {"committed": true, "operation": operation, "transaction_id": transaction_id},
		}
		journal[transaction_id] = record.duplicate(true)
		terminals[transaction_id] = record.duplicate(true)
	raw["transaction_journal"] = journal
	raw["terminal_operations"] = terminals
	var encoded := CODEC.encode_tree(raw)
	if not bool(encoded.get("ok", false)) or not (encoded.get("value") is Dictionary):
		return false
	var applied := commodity.apply_save_data(encoded.get("value", {}) as Dictionary)
	return bool(applied.get("applied", false)) \
			and commodity.transaction_journal_snapshot().size() == 2 \
			and (commodity.to_save_data().get("terminal_operations", {}) as Dictionary).size() == 2


func _mutate(fixture: Dictionary, ordinal: int) -> void:
	var commodity := fixture.get("commodity") as CommodityCardInventoryRuntimeController
	var product := fixture.get("product") as ProductMarketRuntimeController
	var district := fixture.get("district") as DistrictPurchaseRuntimeController
	commodity.configure_belt(100 + ordinal, [])
	commodity.configure_market(200 + ordinal, {})
	product.market_timer = 3.25 + float(ordinal)
	product.business_cycle_count += ordinal + 1
	var entry := (product.product_market.get("fixture.product", {}) as Dictionary).duplicate(true)
	entry["growth_multiplier"] = 1.5 + float(ordinal) / 100.0
	product.product_market["fixture.product"] = entry
	district.close_window(0, "composite-mutation-%d" % ordinal)


func _observation(fixture: Dictionary) -> Dictionary:
	return {
		"commodity": _commodity_snapshot(fixture),
		"product": _product_snapshot(fixture),
		"district": _district_snapshot(fixture),
		"owner": (fixture.get("owner") as CardInventorySaveOwner).debug_snapshot(),
		"synthetic_world_fingerprint": "unchanged-world-authority",
		"synthetic_rng_cursor": {"schema_version": 1, "draw_count": 0, "rng_state": 900626424},
		"synthetic_log_revisions": {"public": 0, "private": 0, "presentation": 0},
	}


func _commodity_snapshot(fixture: Dictionary) -> Dictionary:
	return (fixture.get("commodity") as CommodityCardInventoryRuntimeController).capture_runtime_checkpoint()


func _product_snapshot(fixture: Dictionary) -> Dictionary:
	return (fixture.get("product") as ProductMarketRuntimeController).capture_runtime_checkpoint()


func _district_snapshot(fixture: Dictionary) -> Dictionary:
	return (fixture.get("district") as DistrictPurchaseRuntimeController).capture_runtime_checkpoint()


func _commodity_field(save: Dictionary, field: String) -> Dictionary:
	var commodity := save.get("commodity_card_inventory", {}) as Dictionary
	return (commodity.get(field, {}) as Dictionary).duplicate(true) if commodity.get(field, {}) is Dictionary else {}


func _product_tag(save: Dictionary, field: String) -> Dictionary:
	var product := save.get("product_market", {}) as Dictionary
	return (product.get(field, {}) as Dictionary).duplicate(true) if product.get(field, {}) is Dictionary else {}


func _growth_tag(save: Dictionary) -> Dictionary:
	var product := save.get("product_market", {}) as Dictionary
	var market := product.get("product_market", {}) as Dictionary
	var entry := market.get("fixture.product", {}) as Dictionary
	return (entry.get("growth_multiplier", {}) as Dictionary).duplicate(true) if entry.get("growth_multiplier", {}) is Dictionary else {}


func _district_cursor(save: Dictionary) -> int:
	var district := save.get("district_purchase", {}) as Dictionary
	var payload := district.get("district_purchase_runtime", {}) as Dictionary
	return int(payload.get("next_quote_sequence", -1))


func _district_key_map(checkpoint: Dictionary) -> Dictionary:
	var children := checkpoint.get("children", {}) as Dictionary
	var wrapper := children.get("district_purchase", {}) as Dictionary
	var state := wrapper.get("state", {}) as Dictionary
	return (state.get("windows_by_player", {}) as Dictionary).duplicate(true) if state.get("windows_by_player", {}) is Dictionary else {}


func _product_entry() -> Dictionary:
	return {
		"tier": "fixture", "base_price": 100, "price": 113, "trend": 2,
		"volatility": 4, "supply": 3, "demand": 7, "disrupted": 0,
		"price_history": [100, 113],
		"base_growth_multiplier": 1.0, "growth_multiplier": 1.125,
		"growth_seconds": 29.999, "growth_turns": 1,
		"growth_source": "fixture", "base_growth_source": "fixture-base",
		"base_route_flow_multiplier": 1.0, "route_flow_multiplier": 1.25,
		"route_flow_seconds": 30.0, "route_flow_turns": 1,
		"route_flow_source": "fixture", "base_route_flow_source": "fixture-base",
		"market_contract_demand": 2, "market_contract_supply": 1,
		"market_contract_seconds": 30.0, "market_contract_turns": 1,
		"market_contract_source": "fixture", "futures_positions": [_position()],
		"weather_price_growth_multiplier": 1.05, "weather_modifier": 1,
		"weather_contributions": [], "weather_driver_summary": "fixture-weather",
	}


func _position() -> Dictionary:
	return {
		"position_id": 12, "owner": 0, "source": "fixture.card", "card_id": "fixture.card",
		"product_id": "fixture.product", "direction": "up", "baseline_price": 100,
		"opened_at": 12.125, "expires_at": 42.124, "duration_seconds": 29.999,
		"multiplier": 1.5, "units": 1, "warehouse_district": 0,
		"warehouse_region_id": "region.001", "action_fee_cash": 0,
		"locked_margin": 100, "maximum_gain": 200, "maximum_loss": 100,
		"terms_version": "v0.6", "settlement_formula_id": "fixture-settlement",
		"warehouse_loss_formula_id": "fixture-loss", "settled": false,
	}


func _f64_tag_count(value: Variant) -> int:
	if value is Dictionary and str((value as Dictionary).get("codec", "")) == CODEC.F64_CODEC_ID:
		return 1
	var count := 0
	if value is Array:
		for item in value as Array: count += _f64_tag_count(item)
	elif value is Dictionary:
		for item in (value as Dictionary).values(): count += _f64_tag_count(item)
	return count


func _raw_float_count(value: Variant) -> int:
	if value is float: return 1
	var count := 0
	if value is Array:
		for item in value as Array: count += _raw_float_count(item)
	elif value is Dictionary:
		for item in (value as Dictionary).values(): count += _raw_float_count(item)
	return count


func _first_difference(left: Variant, right: Variant, path: String) -> Dictionary:
	if typeof(left) != typeof(right):
		return {"path": path, "left_type": type_string(typeof(left)), "right_type": type_string(typeof(right)), "reason_code": "variant_type_mismatch"}
	if left is Dictionary:
		var left_dictionary := left as Dictionary
		var right_dictionary := right as Dictionary
		if left_dictionary.size() != right_dictionary.size():
			return {"path": path, "left_type": "Dictionary", "right_type": "Dictionary", "reason_code": "dictionary_size_mismatch"}
		var keys: Array = left_dictionary.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key_variant in keys:
			var key := str(key_variant)
			if not right_dictionary.has(key):
				return {"path": "%s.%s" % [path, key], "left_type": type_string(typeof(key_variant)), "right_type": "missing", "reason_code": "dictionary_key_missing"}
			var nested := _first_difference(left_dictionary.get(key_variant), right_dictionary.get(key), "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
		return {}
	if left is Array:
		var left_array := left as Array
		var right_array := right as Array
		if left_array.size() != right_array.size():
			return {"path": path, "left_type": "Array", "right_type": "Array", "reason_code": "array_size_mismatch"}
		for index in range(left_array.size()):
			var nested := _first_difference(left_array[index], right_array[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return {}
	return {} if left == right else {"path": path, "left_type": type_string(typeof(left)), "right_type": type_string(typeof(right)), "reason_code": "value_mismatch"}


func _release(fixtures: Array) -> void:
	for fixture_variant in fixtures:
		var fixture := fixture_variant as Dictionary
		for node_variant in fixture.get("nodes", []) as Array:
			var node := node_variant as Node
			if node != null:
				node.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("CARD_INVENTORY_COMPOSITE_RESTORE_PARITY_TEST|status=%s|checks=%d|failures=%d|faults=%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(), _fault_passed, FAULT_STAGES.size(),
	])
	if not _failures.is_empty():
		push_error("Card Inventory composite parity failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)

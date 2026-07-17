extends SceneTree

const ControllerScript := preload("res://scripts/runtime/region_supply_runtime_controller.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source: RegionSupplyRuntimeController = ControllerScript.new()
	root.add_child(source)
	var configured := source.configure(90210, _regions(), _cards(), 3)
	_expect(bool(configured.get("configured", false)), "source controller configured")
	_advance_slot(source, "region.a", 0, "tx.seed.0")
	_advance_slot(source, "region.b", 1, "tx.seed.1")
	_advance_slot(source, "region.a", 2, "tx.seed.2")

	var save := source.to_save_data()
	var restored: RegionSupplyRuntimeController = ControllerScript.new()
	root.add_child(restored)
	var applied := restored.apply_save_data(save)
	_expect(bool(applied.get("applied", false)), "save applies")
	_expect(_fingerprint(source.public_rack_snapshot()) == _fingerprint(restored.public_rack_snapshot()), "current racks survive roundtrip")
	_expect(int(source.debug_snapshot().get("state_revision", -1)) == int(restored.debug_snapshot().get("state_revision", -2)), "state revision survives roundtrip")

	for step in range(12):
		var region_id := "region.a" if step % 2 == 0 else "region.b"
		var slot_index := step % 3
		var source_listing := _slot(source, region_id, slot_index)
		var restored_listing := _slot(restored, region_id, slot_index)
		_expect(_fingerprint(source_listing) == _fingerprint(restored_listing), "step %d starts from identical listing" % step)
		var tx := "tx.next.%d" % step
		var source_plan := source.prepare_slot_refill(
			region_id,
			slot_index,
			str(source_listing.get("item_id", "")),
			str(source_listing.get("supply_revision", "")),
			tx
		)
		var restored_plan := restored.prepare_slot_refill(
			region_id,
			slot_index,
			str(restored_listing.get("item_id", "")),
			str(restored_listing.get("supply_revision", "")),
			tx
		)
		_expect(
			_fingerprint(source_plan.get("next_listing", {})) == _fingerprint(restored_plan.get("next_listing", {})),
			"step %d next draw remains deterministic after load" % step
		)
		source.commit_slot_refill(tx)
		restored.commit_slot_refill(tx)
		source.finalize_slot_refill(tx)
		restored.finalize_slot_refill(tx)

	var before_corrupt := restored.to_save_data()
	var corrupt := before_corrupt.duplicate(true)
	corrupt["state_version"] = 999
	var rejected := restored.apply_save_data(corrupt)
	_expect(not bool(rejected.get("applied", false)), "wrong save schema is rejected")
	_expect(_fingerprint(before_corrupt) == _fingerprint(restored.to_save_data()), "rejected save has zero side effects")
	var public_text := JSON.stringify(restored.public_rack_snapshot())
	_expect(not public_text.contains("bags_by_region") and not public_text.contains("rng_state_by_region"), "public snapshot never exposes saved future order")

	source.free()
	restored.free()
	_finish()


func _advance_slot(controller: RegionSupplyRuntimeController, region_id: String, slot_index: int, tx: String) -> void:
	var listing := _slot(controller, region_id, slot_index)
	var prepared := controller.prepare_slot_refill(
		region_id,
		slot_index,
		str(listing.get("item_id", "")),
		str(listing.get("supply_revision", "")),
		tx
	)
	_expect(bool(prepared.get("prepared", false)), "%s prepared" % tx)
	_expect(bool(controller.commit_slot_refill(tx).get("committed", false)), "%s committed" % tx)
	_expect(bool(controller.finalize_slot_refill(tx).get("finalized", false)), "%s finalized" % tx)


func _slot(controller: RegionSupplyRuntimeController, region_id: String, slot_index: int) -> Dictionary:
	var snapshot := controller.public_rack_snapshot(region_id)
	var regions: Array = snapshot.get("regions", [])
	if regions.is_empty():
		return {}
	var slots: Array = (regions[0] as Dictionary).get("slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		return {}
	return (slots[slot_index] as Dictionary).duplicate(true)


func _regions() -> Array:
	return [
		{"region_id": "region.a", "region_index": 0, "terrain": "land", "active": true},
		{"region_id": "region.b", "region_index": 1, "terrain": "ocean", "active": true},
	]


func _cards() -> Array:
	var rows: Array = []
	for index in range(10):
		rows.append({
			"card_id": "card.%02d" % index,
			"family_id": "family.%02d" % index,
			"card_type": ["facility_factory", "facility_market", "route", "warehouse", "monster"][index % 5],
			"rank": "I",
			"display_name": "测试牌%02d" % index,
			"price_cash": 5 + index,
			"region_supply_weight": 1 + (index % 3),
			"enabled": true,
			"valid": true,
			"potential_target_exists": true,
		})
	return rows


func _fingerprint(value: Variant) -> String:
	return JSON.stringify(value, "", true)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("REGION_SUPPLY_RNG_SAVE_ROUNDTRIP_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("REGION_SUPPLY_RNG_SAVE_ROUNDTRIP_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(1)

extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for region supply policy")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	for depth in range(1, 7):
		main.set("configured_roguelike_depth", depth)
		var rng := main.get("rng") as RandomNumberGenerator
		rng.seed = 7300 + depth
		main.call("_new_game")
		await process_frame
		_check_depth(main, depth)
	_check_save_load_stability(main)
	_check_product_change_revalidates_fixed_slot(main)
	root.remove_child(main)
	main.queue_free()
	_finish()


func _check_depth(main: Node, depth: int) -> void:
	var report := _diagnostics(main).district_reserved_supply_audit()
	var district_count := int(report.get("district_count", 0))
	_expect(bool(report.get("ok", false)), "depth %d reserved supply audit passes: %s" % [depth, str(report.get("issues", []))])
	_expect(int(report.get("development_slot_count", -1)) == district_count, "depth %d gives every region one development slot" % depth)
	_expect(int(report.get("monster_slot_count", -1)) == district_count, "depth %d gives every region one monster slot" % depth)
	var districts := main.get("districts") as Array
	var ocean_count := 0
	var occurrence_counts := {}
	var adjacent_repeat_pairs := {}
	for district_index in range(districts.size()):
		var district := districts[district_index] as Dictionary
		var choices := district.get("card_choices", []) as Array
		var development_cards := []
		var monster_cards := []
		for card_variant in choices:
			var card_name := String(card_variant)
			if bool(main.call("_is_city_development_card_name", card_name)):
				development_cards.append(card_name)
			elif bool(main.call("_is_monster_card_name", card_name)):
				monster_cards.append(card_name)
		_expect(choices.size() >= 4 and choices.size() <= 5, "depth %d region %d keeps 4-5 cards" % [depth, district_index])
		_expect(development_cards.size() == 1, "depth %d region %d has exactly one development card" % [depth, district_index])
		_expect(monster_cards.size() == 1, "depth %d region %d has exactly one monster card" % [depth, district_index])
		if not development_cards.is_empty():
			var definition := _card_definition(main, String(development_cards[0]))
			var local_products := main.call("_district_local_product_names", district_index) as Array
			_expect(local_products.has(String(definition.get("product_id", ""))), "depth %d region %d development card uses a local product" % [depth, district_index])
		if String(district.get("terrain", "land")) == "ocean":
			ocean_count += 1
		if not monster_cards.is_empty():
			var monster_name := String(monster_cards[0])
			occurrence_counts[monster_name] = int(occurrence_counts.get(monster_name, 0)) + 1
			for neighbor_variant in district.get("neighbors", []):
				var neighbor := int(neighbor_variant)
				if neighbor <= district_index or neighbor < 0 or neighbor >= districts.size():
					continue
				if String((districts[neighbor] as Dictionary).get("monster_guarantee_card", "")) == monster_name:
					adjacent_repeat_pairs["%d:%d" % [district_index, neighbor]] = true
	_expect(ocean_count > 0, "depth %d includes ocean regions with fixed development slots" % depth)
	var monster_family_count := (main.call("_run_allowed_monster_card_names", 1) as Array).size()
	if district_count <= monster_family_count:
		_expect(occurrence_counts.size() == district_count, "depth %d fixed monster cards are globally unique while capacity permits" % depth)
	else:
		var counts := occurrence_counts.values()
		var min_count := 999999
		var max_count := 0
		for count_variant in counts:
			min_count = mini(min_count, int(count_variant))
			max_count = maxi(max_count, int(count_variant))
		_expect(max_count - min_count <= 1, "depth %d unavoidable monster repeats are evenly distributed" % depth)
		var adjacent_repeat_limit := maxi(1, int(ceil(float(district_count) * 0.10)))
		_expect(adjacent_repeat_pairs.size() <= adjacent_repeat_limit, "depth %d keeps unavoidable adjacent monster repeats below 10%% (%d/%d)" % [depth, adjacent_repeat_pairs.size(), adjacent_repeat_limit])


func _check_save_load_stability(main: Node) -> void:
	var before := _fixed_slot_signature(main.get("districts") as Array)
	# Region supply stores canonical card-name strings; a save may have no
	# current market selection and must restore without assuming dictionaries.
	main.set("selected_market_skill", "")
	var state := main.call("_capture_run_state") as Dictionary
	var saved_rng_state := int(state.get("rng_state", 0))
	_expect(int(main.call("_apply_run_state", state)) == OK, "saved run state reloads")
	var after := _fixed_slot_signature(main.get("districts") as Array)
	_expect(before == after, "save/load preserves every region's fixed development and monster cards")
	_expect(String(main.get("selected_market_skill")) != "", "save/load restores a valid selection from a string-based regional market")
	var rng := main.get("rng") as RandomNumberGenerator
	_expect(int(rng.state) == saved_rng_state, "supply normalization does not advance restored gameplay RNG")


func _check_product_change_revalidates_fixed_slot(main: Node) -> void:
	var districts := (main.get("districts") as Array).duplicate(true)
	if districts.is_empty():
		_expect(false, "product revalidation fixture has a region")
		return
	var run_products := main.call("_current_run_product_names") as Array
	if run_products.size() < 2:
		_expect(false, "product revalidation fixture has multiple products")
		return
	var district := districts[0] as Dictionary
	var old_card := String(district.get("city_development_guarantee_card", ""))
	var old_definition := _card_definition(main, old_card)
	var old_product := String(old_definition.get("product_id", ""))
	var replacement := ""
	for product_variant in run_products:
		if String(product_variant) != old_product:
			replacement = String(product_variant)
			break
	if replacement == "":
		_expect(false, "product revalidation finds a replacement product")
		return
	district["products"] = [replacement]
	district["demands"] = []
	district["city"] = {}
	districts[0] = district
	main.set("districts", districts)
	main.call("_refresh_city_networks")
	var refreshed_district := (main.get("districts") as Array)[0] as Dictionary
	var refreshed_card := String(refreshed_district.get("city_development_guarantee_card", ""))
	var refreshed_definition := _card_definition(main, refreshed_card)
	_expect(String(refreshed_definition.get("product_id", "")) == replacement, "changing regional goods revalidates the fixed development card")


func _card_definition(main: Node, card_id: String) -> Dictionary:
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if main != null else null
	var value: Variant = coordinator.call("card_definition", card_id) if coordinator != null else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _diagnostics(main: Node) -> GameplayBalanceDiagnosticsRuntimeService:
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	return coordinator.gameplay_balance_diagnostics_service() if coordinator is GameRuntimeCoordinator else null


func _fixed_slot_signature(districts: Array) -> Array:
	var result := []
	for district_variant in districts:
		var district := district_variant as Dictionary
		result.append([
			String(district.get("city_development_guarantee_card", "")),
			String(district.get("monster_guarantee_card", "")),
		])
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Region supply policy test passed.")
		quit(0)
		return
	push_error("Region supply policy test failed:\n- " + "\n- ".join(_failures))
	quit(1)

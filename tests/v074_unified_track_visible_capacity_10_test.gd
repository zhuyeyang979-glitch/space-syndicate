extends SceneTree

const RuntimeOwner := preload(
	"res://scripts/v074_runtime/v074_runtime_owner.gd"
)
const LOCAL_PLAYER_ID := "player.local"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime := RuntimeOwner.new()
	get_root().add_child(runtime)
	var started := runtime.start_new_game(
		3,
		7407410,
		false,
		false,
		{
			"map_seed": 7407410,
			"region_count": 8,
			"geography_complexity": "SIMPLE",
			"land_ocean_profile": "BALANCED",
		}
	)
	_expect(bool(started.get("accepted", false)), "V0.7.4 runtime starts")
	if not bool(started.get("accepted", false)):
		_finish(runtime)
		return

	var core_variant: Variant = runtime.get("_track_core")
	var core := core_variant as RefCounted
	_expect(core != null, "shared sushi track core is connected")
	if core == null:
		_finish(runtime)
		return

	var before_state := _authority_state(core)
	var before_track := before_state.get("track_state", {}) as Dictionary
	var capacity := int(before_track.get("capacity", 0))
	var before_items := before_track.get("items", []) as Array
	_expect(capacity == 30, "three players produce thirty shared path positions")
	_expect(before_items.size() == capacity, "initial shared track is fully populated")

	var before_projection := core.call(
		"player_projection_v1",
		LOCAL_PLAYER_ID
	) as Dictionary
	var before_private := (
		before_projection.get("viewer_private_facts", {}) as Dictionary
	)
	var own_items := (
		before_private.get("own_segment_items", []) as Array
	).duplicate(true)
	_expect(own_items.size() == 10, "local visible capacity is ten real cards")
	_expect(
		_unique_instance_count(own_items) == 10,
		"the ten visible cards have unique instance identities"
	)
	var ratios := (
		before_projection.get("public_facts", {}) as Dictionary
	).get("card_kind_ratio_basis_points", {}) as Dictionary
	_expect(
		int(ratios.get("normal_card", 0)) == 6000
		and int(ratios.get("commodity_card", 0)) == 4000,
		"normal and commodity supply ratio remains 60/40"
	)

	var target := _item_nearest_slot(own_items, 4)
	_expect(not target.is_empty(), "a local acquisition target exists")
	if target.is_empty():
		_finish(runtime)
		return
	var target_id := str(target.get("instance_id", ""))
	var before_rows := _item_rows_by_id(before_items)
	var target_row := before_rows.get(target_id, {}) as Dictionary
	var vacated_path_position := int(
		target_row.get("path_position", -1)
	)
	var before_supply := _supply_consumption_probe(before_state)
	var receipt := runtime.acquire_track_item(LOCAL_PLAYER_ID, target_id)
	_expect(
		bool(receipt.get("accepted", false)),
		"visible card acquisition commits: %s" % JSON.stringify(receipt)
	)
	var after_state := _authority_state(core)
	var acquisition_public_facts := _acquisition_public_facts(after_state)
	_expect(
		int(acquisition_public_facts.get("replacement_count", -1)) == 0,
		"acquisition receipt reports zero immediate replacement"
	)
	var after_track := after_state.get("track_state", {}) as Dictionary
	var after_items := after_track.get("items", []) as Array
	var after_rows := _item_rows_by_id(after_items)
	_expect(
		after_items.size() == capacity - 1,
		"acquisition leaves one authoritative shared-track vacancy"
	)
	_expect(not after_rows.has(target_id), "the acquired instance is removed")
	_expect(
		_supply_consumption_probe(after_state) == before_supply,
		"acquisition consumes no future supply or RNG state"
	)
	_expect(
		_survivors_unchanged(before_rows, after_rows, target_id),
		"all surviving cards keep their path positions and segment owners"
	)
	_expect(
		_missing_path_positions(after_items, capacity)
		== [vacated_path_position],
		"the vacancy remains at the purchased card path position"
	)

	var after_projection := core.call(
		"player_projection_v1",
		LOCAL_PLAYER_ID
	) as Dictionary
	var after_own_items := (
		(after_projection.get(
			"viewer_private_facts",
			{}
		) as Dictionary).get("own_segment_items", []) as Array
	)
	_expect(
		after_own_items.size() == 9,
		"local projection exposes nine real cards plus one UI vacancy"
	)
	var debug_after_purchase := core.call("debug_snapshot_v074") as Dictionary
	_expect(
		int(debug_after_purchase.get(
			"immediate_authoritative_refill_count",
			-1
		)) == 0,
		"immediate authoritative refill count stays zero"
	)
	_expect(
		int(debug_after_purchase.get(
			"supply_rng_draw_delta_on_acquisition",
			-1
		)) == 0,
		"acquisition supply RNG draw delta stays zero"
	)
	_expect(
		int(debug_after_purchase.get(
			"supply_cursor_delta_on_acquisition",
			-1
		)) == 0,
		"acquisition supply cursor delta stays zero"
	)
	_expect(
		int(debug_after_purchase.get(
			"supply_instance_sequence_delta_on_acquisition",
			-1
		)) == 0,
		"acquisition instance sequence delta stays zero"
	)

	var purchase_items := after_items.duplicate(true)
	var purchase_rows := _item_rows_by_id(purchase_items)
	var natural_advance := _advance_track(core, 1, "first")
	_expect(
		bool(natural_advance.get("accepted", false)),
		"shared natural scroll commits"
	)
	var scrolled_state := _authority_state(core)
	var scrolled_track := scrolled_state.get("track_state", {}) as Dictionary
	var scrolled_items := scrolled_track.get("items", []) as Array
	_expect(
		scrolled_items.size() == capacity - 1,
		"vacancy persists while moving through the shared path"
	)
	_expect(
		_missing_path_positions(scrolled_items, capacity)
		== [vacated_path_position + 1],
		"natural scroll advances the vacancy by exactly one position"
	)
	_expect(
		_survivors_advance_once(purchase_rows, scrolled_items, capacity),
		"natural scroll advances surviving cards exactly once"
	)
	_expect(
		_has_new_head_instance(purchase_rows, scrolled_items),
		"natural scroll draws one new queue-head instance"
	)
	var new_head := _item_at_path_position(scrolled_items, 0)
	var new_head_owner := str(new_head.get("segment_owner_id", ""))
	var new_head_id := str(new_head.get("instance_id", ""))
	var new_head_projection := core.call(
		"player_projection_v1",
		new_head_owner
	) as Dictionary
	var projected_new_head := _item_by_id(
		(
			(new_head_projection.get(
				"viewer_private_facts",
				{}
			) as Dictionary).get("own_segment_items", []) as Array
		),
		new_head_id
	)
	_expect(
		projected_new_head.get("claimable") == false
		and str(projected_new_head.get("claimability_state", ""))
		== "incoming_locked",
		"natural head draw preserves the inherited replacement lock"
	)
	var locked_receipt := runtime.acquire_track_item(
		new_head_owner,
		new_head_id
	)
	_expect(
		not bool(locked_receipt.get("accepted", false))
		and str(locked_receipt.get("reason_code", ""))
		== "track_replacement_locked_until_next_scroll",
		"incoming head card rejects same-scroll acquisition with typed feedback"
	)

	var gap_position := vacated_path_position + 1
	var steps_until_gap_exits := capacity - gap_position
	var exit_advance := _advance_track(
		core,
		steps_until_gap_exits,
		"vacancy_exit"
	)
	_expect(
		bool(exit_advance.get("accepted", false)),
		"natural scroll carries the vacancy through the shared tail"
	)
	var restored_state := _authority_state(core)
	var restored_track := restored_state.get("track_state", {}) as Dictionary
	var restored_items := restored_track.get("items", []) as Array
	_expect(
		restored_items.size() == capacity,
		"track returns to full capacity only after the vacancy exits the tail"
	)
	_expect(
		_missing_path_positions(restored_items, capacity).is_empty(),
		"no path vacancy remains after natural tail exit"
	)
	var restored_debug := core.call("debug_snapshot_v074") as Dictionary
	_expect(
		int(restored_debug.get("vacancy_count", -1)) == 0,
		"shared-track debug vacancy count returns to zero"
	)
	_expect(
		int(restored_debug.get(
			"immediate_authoritative_refill_count",
			-1
		)) == 0
		and int(restored_debug.get(
			"supply_rng_draw_delta_on_acquisition",
			-1
		)) == 0,
		"natural scrolling never reclassifies its draws as purchase-time refill"
	)
	_finish(runtime)


func _advance_track(
	core: RefCounted,
	steps: int,
	suffix: String
) -> Dictionary:
	var intent := core.call(
		"build_intent_v1",
		"request.v074.shared_scroll.%s" % suffix,
		"system",
		core.ACTION_ADVANCE_TRACK,
		{"steps": steps}
	) as Dictionary
	return core.call("apply_intent_v1", intent) as Dictionary


func _authority_state(core: RefCounted) -> Dictionary:
	return (
		(core.call("core_authority_v1") as Dictionary).get(
			"authority_state",
			{}
		) as Dictionary
	).duplicate(true)


func _item_nearest_slot(items: Array, preferred_slot: int) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 999999
	for item_variant in items:
		var item := item_variant as Dictionary
		if not bool(item.get("claimable", false)):
			continue
		var distance := absi(
			int(item.get("local_slot_index", -1)) - preferred_slot
		)
		if distance < best_distance:
			best = item.duplicate(true)
			best_distance = distance
	return best


func _unique_instance_count(items: Array) -> int:
	var ids := {}
	for item_variant in items:
		ids[str((item_variant as Dictionary).get("instance_id", ""))] = true
	ids.erase("")
	return ids.size()


func _item_at_path_position(items: Array, path_position: int) -> Dictionary:
	for item_variant in items:
		var item := item_variant as Dictionary
		if int(item.get("path_position", -1)) == path_position:
			return item.duplicate(true)
	return {}


func _item_by_id(items: Array, instance_id: String) -> Dictionary:
	for item_variant in items:
		var item := item_variant as Dictionary
		if str(item.get("instance_id", "")) == instance_id:
			return item.duplicate(true)
	return {}


func _item_rows_by_id(items: Array) -> Dictionary:
	var rows := {}
	for item_variant in items:
		var item := item_variant as Dictionary
		rows[str(item.get("instance_id", ""))] = {
			"path_position": int(item.get("path_position", -1)),
			"segment_owner_id": str(item.get("segment_owner_id", "")),
		}
	rows.erase("")
	return rows


func _survivors_unchanged(
	before_rows: Dictionary,
	after_rows: Dictionary,
	removed_id: String
) -> bool:
	for instance_id_variant in before_rows.keys():
		var instance_id := str(instance_id_variant)
		if instance_id == removed_id:
			continue
		if not after_rows.has(instance_id):
			return false
		if after_rows.get(instance_id) != before_rows.get(instance_id):
			return false
	return true


func _survivors_advance_once(
	before_rows: Dictionary,
	after_items: Array,
	capacity: int
) -> bool:
	var after_rows := _item_rows_by_id(after_items)
	for instance_id_variant in before_rows.keys():
		var instance_id := str(instance_id_variant)
		var before := before_rows.get(instance_id, {}) as Dictionary
		var before_position := int(before.get("path_position", -1))
		if before_position + 1 >= capacity:
			if after_rows.has(instance_id):
				return false
			continue
		if not after_rows.has(instance_id):
			return false
		var after := after_rows.get(instance_id, {}) as Dictionary
		if int(after.get("path_position", -1)) != before_position + 1:
			return false
	return true


func _has_new_head_instance(
	before_rows: Dictionary,
	after_items: Array
) -> bool:
	for item_variant in after_items:
		var item := item_variant as Dictionary
		if (
			int(item.get("path_position", -1)) == 0
			and not before_rows.has(str(item.get("instance_id", "")))
		):
			return true
	return false


func _missing_path_positions(items: Array, capacity: int) -> Array:
	var occupied := {}
	for item_variant in items:
		var item := item_variant as Dictionary
		occupied[int(item.get("path_position", -1))] = true
	var missing: Array = []
	for path_position in range(capacity):
		if not occupied.has(path_position):
			missing.append(path_position)
	return missing


func _acquisition_public_facts(state: Dictionary) -> Dictionary:
	var processed := state.get("processed_requests", {}) as Dictionary
	for record_variant in processed.values():
		var record := record_variant as Dictionary
		var action_id := str(record.get("action_id", ""))
		if action_id in [
			"claim_visible_commodity",
			"purchase_visible_normal_card",
		]:
			return (
				record.get("public_facts", {}) as Dictionary
			).duplicate(true)
	return {}


func _supply_consumption_probe(state: Dictionary) -> Dictionary:
	var track := state.get("track_state", {}) as Dictionary
	var type_supply := state.get("type_supply_state", {}) as Dictionary
	var normal_supply := state.get("normal_supply_state", {}) as Dictionary
	var commodity_supply := (
		state.get("commodity_supply_state", {}) as Dictionary
	)
	var color_cycle := state.get("color_cycle_state", {}) as Dictionary
	var color_supply := (
		color_cycle.get("color_supply_state", {}) as Dictionary
	)
	return {
		"next_instance_sequence": int(
			track.get("next_instance_sequence", 0)
		),
		"type_cursor": int(type_supply.get("cursor", 0)),
		"type_rng_draw_count": int(type_supply.get("rng_draw_count", 0)),
		"normal_cursor": int(normal_supply.get("cursor", 0)),
		"normal_rng_draw_count": int(
			normal_supply.get("rng_draw_count", 0)
		),
		"commodity_cursor": int(commodity_supply.get("cursor", 0)),
		"commodity_rng_draw_count": int(
			commodity_supply.get("rng_draw_count", 0)
		),
		"color_cursor": int(color_supply.get("cursor", 0)),
		"color_rng_draw_count": int(
			color_supply.get("rng_draw_count", 0)
		),
	}


func _finish(runtime: Node) -> void:
	print(
		"V074_UNIFIED_TRACK_VISIBLE_CAPACITY_10_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	runtime.queue_free()
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)

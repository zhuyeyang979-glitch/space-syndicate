extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main.tscn loads for card batch auction visibility")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	await _wait_frames(4)
	main.call("_new_game")
	await _wait_frames(4)
	var batch_entries := _make_batch_entries()
	main.set("card_resolution_queue", batch_entries)
	main.set("next_card_resolution_queue", [])
	main.set("active_card_resolution", {})
	main.set("card_resolution_auction_open", true)
	main.set("card_resolution_auction_timer", 5.0)
	main.set("card_resolution_batch_locked", false)
	main.set("selected_player", 0)
	main.set("selected_card_resolution_id", 703)
	var track_entries: Array = main.call("_runtime_card_track_snapshot_source") as Array
	var auction_track_count := 0
	for entry_variant in track_entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if str(entry.get("state", "")).begins_with("竞拍"):
			auction_track_count += 1
	_expect(auction_track_count >= batch_entries.size(), "public card track exposes every card in the current auction batch")
	var bid_board: Dictionary = main.call("_runtime_player_board_bid_board", 0) as Dictionary
	var links: Array = bid_board.get("track_links", []) if bid_board.get("track_links", []) is Array else []
	_expect(links.size() >= batch_entries.size(), "BidBoard exposes clickable pointers for the full current batch")
	for resolution_id in [701, 702, 703, 704, 705]:
		_expect(_links_have_resolution(links, resolution_id), "BidBoard includes batch card resolution %d" % resolution_id)
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)
	_finish()


func _make_batch_entries() -> Array:
	var names := ["轨道融资 I", "深海运单 I", "相位新闻 I", "棱镜怪兽 I", "合约快线 I"]
	var entries: Array = []
	for i in range(names.size()):
		entries.append({
			"resolution_id": 701 + i,
			"queued_order": 701 + i,
			"player_index": i % 4,
			"slot_index": -1,
			"tip": 10 + i * 10,
			"skill": {
				"name": names[i],
				"kind": "economy",
				"rank": 1,
				"route_tags": ["city_growth"],
			},
		})
	return entries


func _links_have_resolution(links: Array, resolution_id: int) -> bool:
	var expected_id := "track_select_%d" % resolution_id
	for link_variant in links:
		if not (link_variant is Dictionary):
			continue
		var link: Dictionary = link_variant
		if str(link.get("id", "")) == expected_id:
			return true
	return false


func _wait_frames(count: int) -> void:
	for _i in range(maxi(1, count)):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Card batch auction visibility test passed.")
	else:
		push_error("Card batch auction visibility test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())

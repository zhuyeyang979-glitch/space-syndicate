extends SceneTree

const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")
const OUTPUT_DIR := "res://reports/ui/player_seat_host"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var requested_count := int(OS.get_environment("SPACE_SYNDICATE_SEAT_CAPTURE_COUNT"))
	var capture_counts := [requested_count] if requested_count in [3, 4, 6, 8] else [3, 4, 6, 8]
	for seat_count in capture_counts:
		var screen := GAME_SCREEN_SCENE.instantiate() as Control
		get_root().add_child(screen)
		screen.call("apply_state", {
			"planet": {
				"title": "星球牌桌｜%d席" % seat_count,
				"hint": "正式生产玩家席位宿主",
				"public_player_seat_sources": _sources(seat_count),
			},
			"player_board": {"identity": "本地测试者", "hand_cards": []},
			"top_bar": {"identity": "本地测试者", "table_state": "经营中"},
		})
		await process_frame
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := get_root().get_texture().get_image()
		var path := "%s/player_seat_host_%d_players_1600x960.png" % [OUTPUT_DIR, seat_count]
		var error := image.save_png(ProjectSettings.globalize_path(path))
		if error != OK:
			push_error("Failed to save %s: %s" % [path, error_string(error)])
			quit(1)
			return
		print("CAPTURED: %s" % path)
		screen.queue_free()
		await process_frame
		await process_frame
	print("PLAYER_SEAT_HOST_CAPTURE COMPLETE")
	quit()


func _sources(count: int) -> Array:
	var entries: Array = []
	for index in range(count):
		entries.append({
			"player_index": index,
			"public_player_name": "玩家%d" % (index + 1),
			"role_name": ["环港走私议会", "深海菌毯使团", "重力矿联董事会", "离子军购局", "光合修复会", "虹膜数据券商", "星鲸餐饮垄断", "静电蜂巢银行"][index],
			"player_color": Color.from_hsv(float(index) / float(count), 0.66, 0.96),
			"is_local_player": index == 0,
			"public_status": &"ready",
			"is_publicly_active": false,
		})
	return entries

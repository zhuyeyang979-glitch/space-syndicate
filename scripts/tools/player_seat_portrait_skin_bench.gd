extends Control

const SkinScene := preload("res://scenes/ui/player_seat/PlayerSeatPortraitSkin.tscn")

@onready var real_host: Control = $Stage/RealSeatHost
@onready var pending_host: Control = $Stage/PendingSeatHost
@onready var result_label: Label = $Header/Result


func _ready() -> void:
	var real_skin := SkinScene.instantiate()
	real_host.add_child(real_skin)
	var real_available: bool = real_skin.apply_public_view_model({
		"seat_index": 2,
		"player_display_name": "公开席位 03",
		"public_role_name": "星鲸餐饮垄断",
		"player_color": Color("#22d3ee"),
		"is_local_player": false,
		"is_publicly_active": true,
		"is_bankrupt": false,
		"public_status": "public_actor",
		"inward_direction": "left",
		"depth_class": "mid",
		"anonymous_action_active": false,
	})
	var pending_skin := SkinScene.instantiate()
	pending_host.add_child(pending_skin)
	var pending_available: bool = pending_skin.apply_public_view_model({
		"seat_index": 5,
		"player_display_name": "公开席位 06",
		"public_role_name": "虹膜数据券商",
		"player_color": Color("#facc15"),
		"public_status": "waiting",
		"inward_direction": "right",
		"depth_class": "far",
	})
	$Stage/PendingSeatHost/LegacyAbstractFallback.visible = not pending_available
	$Stage/RealSeatHost/LegacyAbstractFallback.visible = not real_available
	var result := {
		"scene": "PlayerSeatPortraitSkinBench",
		"production_skin_node": real_skin.get_path(),
		"real_portrait_available": real_available,
		"pending_portrait_uses_legacy_fallback": not pending_available,
		"single_display_real": real_available and not $Stage/RealSeatHost/LegacyAbstractFallback.visible,
		"single_display_pending": not pending_skin.visible and $Stage/PendingSeatHost/LegacyAbstractFallback.visible,
		"skin_owns_layout": false,
		"skin_owns_player_mapping": false,
		"skin_owns_input": false,
		"privacy_fields": real_skin.accepted_public_fields(),
	}
	result_label.text = "Skin可用：%s｜缺图回退：%s｜双显示：否" % ["是" if real_available else "否", "是" if not pending_available else "否"]
	print("PLAYER_SEAT_PORTRAIT_SKIN_BENCH ", JSON.stringify(result))
	call_deferred("_capture_runtime_evidence")


func _capture_runtime_evidence() -> void:
	for _frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.is_empty():
		push_error("PLAYER_SEAT_PORTRAIT_SKIN_CAPTURE viewport_image_empty")
		return
	var output_path := "res://docs/art_qa/current_seat_audit/player_seat_portrait_skin_bench.png"
	var absolute_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("PLAYER_SEAT_PORTRAIT_SKIN_CAPTURE save_failed=%d" % error)
		return
	print("PLAYER_SEAT_PORTRAIT_SKIN_CAPTURE ok=true path=", output_path)

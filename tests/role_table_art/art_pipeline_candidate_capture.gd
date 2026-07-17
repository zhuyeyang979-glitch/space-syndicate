extends SceneTree

const RIG_SCENE := preload("res://scenes/tools/RolePortraitRenderRig.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rig := RIG_SCENE.instantiate()
	root.add_child(rig)
	await process_frame
	var result: Dictionary = await rig.render_all_indexed_candidates()
	if bool(result.get("ok", false)):
		print(
			"ART_PIPELINE_CANDIDATE_CAPTURE PASS rendered=%d total=%d"
			% [int(result.get("rendered", 0)), int(result.get("total", 0))]
		)
		rig.queue_free()
		quit(0)
		return
	push_error("candidate capture failed: %s" % JSON.stringify(result))
	rig.queue_free()
	quit(1)

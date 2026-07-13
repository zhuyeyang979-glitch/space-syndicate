extends RefCounted
class_name PlayerTextVisibilityContractV05

const PlayerTextSpecScript := preload("res://scripts/presentation/player_text_spec_v05.gd")


static func authorize(spec: Dictionary, viewer_context: Dictionary) -> Dictionary:
	if not PlayerTextSpecScript.is_pure_data(spec) or not PlayerTextSpecScript.is_pure_data(viewer_context):
		return {"allowed": false, "reason": "visibility_payload_not_pure_data", "authorized_spec": {}}
	var scope := str(spec.get("visibility_scope", ""))
	var viewer_index := int(viewer_context.get("viewer_index", -1))
	var is_spectator := bool(viewer_context.get("is_spectator", false))
	var endgame_reveal := bool(viewer_context.get("endgame_reveal", false))
	var developer_mode := bool(viewer_context.get("developer_mode", false))
	var allowed := false
	var reason := "visibility_scope_denied"
	match scope:
		"public":
			allowed = true
			reason = "public"
		"viewer_private":
			allowed = not is_spectator and viewer_index >= 0 and viewer_index == int(spec.get("viewer_index", -1))
			reason = "viewer_private_match" if allowed else "viewer_private_denied"
		"revealed_at_endgame":
			allowed = endgame_reveal
			reason = "endgame_revealed" if allowed else "endgame_not_revealed"
		"spectator_sanitized":
			allowed = is_spectator and bool(spec.get("sanitized", false))
			reason = "spectator_sanitized" if allowed else "spectator_payload_not_authorized"
		"developer_only":
			allowed = developer_mode
			reason = "developer_mode" if allowed else "developer_only_denied"
		_:
			reason = "visibility_scope_invalid"
	return {
		"allowed": allowed,
		"reason": reason,
		"authorized_spec": spec.duplicate(true) if allowed else {},
	}

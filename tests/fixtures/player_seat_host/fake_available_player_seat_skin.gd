extends Control

var _available := false


func apply_public_view_model(view_model: Dictionary) -> bool:
	_available = str(view_model.get("public_role_name", "")).strip_edges() != ""
	set_meta("received_view_model", view_model.duplicate(true))
	return _available


func skin_available() -> bool:
	return _available

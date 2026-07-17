extends Control


func apply_public_view_model(view_model: Dictionary) -> bool:
	set_meta("received_view_model", view_model.duplicate(true))
	return false


func skin_available() -> bool:
	return false

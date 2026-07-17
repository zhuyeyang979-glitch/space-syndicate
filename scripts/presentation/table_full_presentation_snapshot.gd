extends RefCounted
class_name TableFullPresentationSnapshot

var revision := 0
var viewer_index := -1
var authorization_revision := 0
var table_state: Dictionary = {}


func is_valid() -> bool:
	return revision >= 0 and viewer_index >= 0 and authorization_revision > 0 \
		and TablePresentationPureDataPolicy.is_pure_data(table_state)


func to_dictionary() -> Dictionary:
	return TablePresentationPureDataPolicy.detached_copy(table_state) as Dictionary if is_valid() else {}

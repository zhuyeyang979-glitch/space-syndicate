extends RefCounted
class_name CardBatchViewerAuthorizationV1

var _revision := 1


func _init(initial_revision: int = 1) -> void:
	_revision = maxi(1, initial_revision)


func revision() -> int:
	return _revision


func rotate() -> void:
	_revision += 1

extends RefCounted
class_name DeveloperBalancePresentationSnapshot

var revision := 0
var enabled := false
var report: Dictionary = {}


func is_valid() -> bool:
	return revision >= 0 and (not enabled or TablePresentationPureDataPolicy.is_pure_data(report))

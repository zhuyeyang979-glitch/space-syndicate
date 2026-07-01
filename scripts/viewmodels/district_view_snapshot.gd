extends RefCounted
class_name DistrictViewSnapshot

var id: String = ""
var title: String = ""
var detail: String = ""
var chips: Array = []
var primary_actions: Array = []


func apply_dictionary(data: Dictionary) -> RefCounted:
	id = str(data.get("id", data.get("district_id", "")))
	title = str(data.get("title", data.get("name", "当前区域")))
	detail = str(data.get("detail", data.get("summary", "选择地图区域后显示短详情。")))
	chips = data.get("chips", []) if data.get("chips", []) is Array else []
	primary_actions = data.get("actions", []) if data.get("actions", []) is Array else []
	return self


func to_ui_dictionary() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"detail": detail,
		"chips": chips,
		"actions": primary_actions,
	}

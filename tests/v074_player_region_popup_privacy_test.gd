extends SceneTree

const Adapter := preload("res://scripts/v074/player/v074_player_map_projection_adapter.gd")
const PopupDto := preload("res://scripts/v074/player/v074_region_popup_dto_v1.gd")
const Bench := preload("res://scripts/v074/player/v074_player_map_projection_bench.gd")
const SampleScreen := preload("res://scripts/ui/v074/v074_sample_game_screen.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var adapter := Adapter.new()
	var projection: Dictionary = adapter.adapt(
		"player.local",
		Bench.make_map_receipt(16),
		Bench.make_public_facilities(16),
		Bench.make_legal_actions(16)
	)
	var popup: Dictionary = adapter.region_popup("region.001")
	_expect(bool(PopupDto.validation_report(popup).get("valid", false)), "public Region Popup DTO validates")
	_expect(str(popup.get("terrain_class", "")) == "ocean", "terrain class is public")
	_expect(int(popup.get("public_warehouse_count", 0)) == 1, "occupied warehouse is public")
	var warehouse: Dictionary = {}
	for value in popup.get("public_facilities", []) as Array:
		var row := value as Dictionary
		if str(row.get("facility_type", "")) == "warehouse":
			warehouse = row
			break
	_expect(int(warehouse.get("capacity_units", 0)) == 12, "warehouse public capacity is projected")
	_expect(int(warehouse.get("ingress_throughput_units", 0)) == 4, "dark ingress throughput is public")
	_expect(int(warehouse.get("egress_throughput_units", 0)) == 3, "dark egress throughput is public")
	_expect(str(warehouse.get("damage_state", "")) == "damaged", "warehouse damage state is public")
	_expect(
		SampleScreen._public_facility_owner_label({
			"owner_public_label": "",
			"owner_public_id": "player.ai.4",
		}) == "player.ai.4",
		"empty public owner label falls back to public owner id"
	)
	var encoded := JSON.stringify(projection)
	for forbidden in ["warehouse_stock", "warehouse_inventory", "PRIVATE_SENTINEL", "private_logistics_plan"]:
		_expect(not encoded.contains(forbidden), "%s is omitted" % forbidden)
	_expect(adapter.region_popup("region.999").is_empty(), "unknown region fails closed")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("V074_PLAYER_REGION_POPUP_PRIVACY_TEST|status=%s|passed=%d|total=%d|details=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(), _checks, JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)

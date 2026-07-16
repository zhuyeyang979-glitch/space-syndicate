extends Node

var players := [{}, {}, {}, {}]


func _local_human_player_index() -> int:
	return 2


func _player_name(player_index: int) -> String:
	return "公开玩家%d" % (player_index + 1)


func _player_role_card_for_index(player_index: int) -> Dictionary:
	return {"name": "公开角色%d" % (player_index + 1), "private_plan": "must_not_escape"}


func _player_color(player_index: int) -> Color:
	return Color.from_hsv(float(player_index) / 4.0, 0.6, 0.9)


func _player_is_eliminated(player_index: int) -> bool:
	return player_index == 3

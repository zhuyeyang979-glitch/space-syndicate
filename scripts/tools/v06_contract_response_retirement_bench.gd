extends Node


func _ready() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var catalog_text := FileAccess.get_file_as_string("res://data/cards/card_runtime_catalog_v06.json")
	var main_text := FileAccess.get_file_as_string("res://scenes/main.tscn")
	var passed := main_scene != null \
		and catalog_text.find("area_trade_contract") < 0 \
		and main_text.find("ContractResponse") < 0
	print("V06_CONTRACT_RESPONSE_RETIREMENT_BENCH_%s" % ("PASS" if passed else "FAIL"))
	# Keep the MCP debug process alive briefly so the mandatory runtime evidence is observable.
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(0 if passed else 1)

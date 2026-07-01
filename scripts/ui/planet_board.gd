extends PanelContainer
class_name SpaceSyndicatePlanetBoard

@onready var title_label: Label = %PlanetTitle
@onready var hint_label: Label = %PlanetHint

func set_board_state(data: Dictionary) -> void:
	title_label.text = str(data.get("title", "星球赌桌"))
	hint_label.text = str(data.get("hint", "中央星球 / 地图占位\n滚轮缩放｜拖拽星球｜双击区域看牌架"))

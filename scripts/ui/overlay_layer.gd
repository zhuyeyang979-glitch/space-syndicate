extends CanvasLayer
class_name SpaceSyndicateOverlayLayer

@onready var tooltip_panel: PanelContainer = %TooltipPanel
@onready var tooltip_label: Label = %TooltipLabel
@onready var confirm_panel: PanelContainer = %ConfirmPanel
@onready var confirm_label: Label = %ConfirmLabel

func show_tooltip(text: String) -> void:
	tooltip_label.text = text
	tooltip_panel.visible = text.strip_edges() != ""


func hide_tooltip() -> void:
	tooltip_panel.visible = false


func show_confirm(text: String) -> void:
	confirm_label.text = text
	confirm_panel.visible = true


func hide_confirm() -> void:
	confirm_panel.visible = false

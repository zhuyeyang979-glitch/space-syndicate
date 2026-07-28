@tool
extends "res://scripts/ui/planet_map_view.gd"
class_name V07ReferencePlanetMapView


func _ready() -> void:
	_enforce_reference_visual_boundary()
	super._ready()
	_enforce_reference_visual_boundary()


func _process(delta: float) -> void:
	_enforce_reference_visual_boundary()
	super._process(delta)


func _draw() -> void:
	_enforce_reference_visual_boundary()
	super._draw()


func _enforce_reference_visual_boundary() -> void:
	sceneized_visual_cutover_enabled = true
	legacy_draw_fallback_enabled = false

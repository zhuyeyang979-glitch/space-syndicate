extends Node
class_name V075CombatTelemetryService

signal telemetry_event_ready(event: Dictionary)

const Bridge := preload(
	"res://scripts/v075/telemetry/v075_combat_telemetry_bridge.gd"
)

var _bridge: RefCounted = Bridge.new()


func _init() -> void:
	_bridge.telemetry_event_ready.connect(_on_telemetry_event_ready)


func consume_public_receipt(
	receipt: Dictionary,
	batch_id := ""
) -> Dictionary:
	return _bridge.call(
		"consume_public_receipt",
		receipt,
		batch_id
	) as Dictionary


func consume_public_cue(cue: Dictionary, batch_id := "") -> Dictionary:
	return _bridge.call(
		"consume_public_cue",
		cue,
		batch_id
	) as Dictionary


func recent_events(limit := 40) -> Array:
	return _bridge.call("recent_events", limit) as Array


func reset_for_new_match() -> void:
	_bridge.call("reset_for_new_match")


func debug_snapshot() -> Dictionary:
	var result := _bridge.call("debug_snapshot") as Dictionary
	result["schema"] = "V075CombatTelemetryServiceDebugV1"
	result["service_node_count"] = 1
	result["gameplay_owner_count"] = 0
	result["rng_owner_count"] = 0
	result["world_mutation_count"] = 0
	return result


func _on_telemetry_event_ready(event: Dictionary) -> void:
	telemetry_event_ready.emit(event.duplicate(true))

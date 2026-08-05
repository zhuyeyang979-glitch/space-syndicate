extends Control
class_name V074ApplicationBootstrap

@onready var _application_flow: Node = %V074RuntimeComposition
@onready var _game_screen: Control = %V074GameScreen
@onready var _playtest_telemetry: Node = (
	$V074RuntimeComposition/V073PlaytestTelemetryService
)


func _ready() -> void:
	_game_screen.call(
		"bind_application_flow",
		_application_flow,
		_application_flow.call("identity_snapshot"),
		_application_flow.call("capability_snapshot")
	)
	_playtest_telemetry.call("bind_sources", _application_flow, _game_screen)
	_game_screen.call("bind_playtest_telemetry", _playtest_telemetry)
	_game_screen.connect(
		"application_intent_requested",
		_on_application_intent_requested
	)
	_application_flow.connect("projection_changed", _on_projection_changed)
	_application_flow.connect("receipt_ready", _on_receipt_ready)
	_application_flow.connect(
		"final_settlement_presented",
		_on_final_settlement_presented
	)
	_application_flow.connect(
		"runtime_fault_presented",
		_on_runtime_fault_presented
	)


func _on_application_intent_requested(intent: Dictionary) -> void:
	_application_flow.call("submit_intent", intent)


func _on_projection_changed(snapshot: Dictionary) -> void:
	_game_screen.call("apply_snapshot", snapshot)


func _on_receipt_ready(receipt: Dictionary) -> void:
	_game_screen.call("apply_receipt", receipt)


func _on_final_settlement_presented(settlement: Dictionary) -> void:
	_game_screen.call("present_final_settlement", settlement)


func _on_runtime_fault_presented(receipt: Dictionary) -> void:
	_game_screen.call("present_runtime_fault", receipt)

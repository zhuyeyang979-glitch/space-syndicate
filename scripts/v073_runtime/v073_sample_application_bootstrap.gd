extends Control
class_name V073SampleApplicationBootstrap

@onready var _application_flow: V073SampleApplicationFlow = %V073RuntimeComposition
@onready var _game_screen: Control = %V073SampleGameScreen
@onready var _playtest_telemetry: Node = (
	$V073RuntimeComposition/V073PlaytestTelemetryService
)
# MCP_FINALIZE


func _ready() -> void:
	_game_screen.call(
		"bind_application_flow",
		_application_flow,
		_application_flow.identity_snapshot(),
		_application_flow.capability_snapshot()
	)
	_playtest_telemetry.call("bind_sources", _application_flow, _game_screen)
	_game_screen.call("bind_playtest_telemetry", _playtest_telemetry)
	_game_screen.connect(
		"application_intent_requested",
		_on_application_intent_requested
	)
	_application_flow.projection_changed.connect(_on_projection_changed)
	_application_flow.receipt_ready.connect(_on_receipt_ready)
	_application_flow.final_settlement_presented.connect(
		_on_final_settlement_presented
	)
	_application_flow.runtime_fault_presented.connect(_on_runtime_fault_presented)


func _on_application_intent_requested(intent: Dictionary) -> void:
	_application_flow.submit_intent(intent)


func _on_projection_changed(snapshot: Dictionary) -> void:
	_game_screen.call("apply_snapshot", snapshot)


func _on_receipt_ready(receipt: Dictionary) -> void:
	_game_screen.call("apply_receipt", receipt)


func _on_final_settlement_presented(settlement: Dictionary) -> void:
	_game_screen.call("present_final_settlement", settlement)


func _on_runtime_fault_presented(receipt: Dictionary) -> void:
	_game_screen.call("present_runtime_fault", receipt)

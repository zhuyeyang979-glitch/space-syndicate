extends Control
class_name V075ApplicationBootstrap

const RuntimeContextQuery := preload(
	"res://scripts/v075_runtime/game_runtime_context_query.gd"
)
const V076HumanGoldenProfile := preload(
	"res://scripts/playtest/v076_alpha07_human_golden_candidate_profile.gd"
)

@onready var _application_flow: Node = %V075RuntimeComposition
@onready var _game_screen: Control = %V075GameScreen
@onready var _new_game_loading_overlay: Control = (
	%V075NewGameLoadingOverlay
)
@onready var _playtest_telemetry: Node = (
	$V075RuntimeComposition/V073PlaytestTelemetryService
)


func _ready() -> void:
	var telemetry_configured := bool(_playtest_telemetry.call(
		"configure_candidate_profile",
		V076HumanGoldenProfile.snapshot()
	))
	if not telemetry_configured:
		push_warning("V076 human-Golden observation profile was not configured")
	_game_screen.call(
		"bind_application_flow",
		_application_flow,
		_application_flow.call("identity_snapshot"),
		_application_flow.call("capability_snapshot")
	)
	_playtest_telemetry.call("bind_sources", _application_flow, _game_screen)
	_game_screen.call("bind_playtest_telemetry", _playtest_telemetry)
	_new_game_loading_overlay.call(
		"bind_sources",
		_application_flow,
		_game_screen,
		_playtest_telemetry
	)
	if _new_game_loading_overlay.has_signal("loading_stage_changed"):
		_new_game_loading_overlay.connect(
			"loading_stage_changed",
			Callable(self, "_on_loading_stage_changed")
		)
	_on_loading_stage_changed(
		_new_game_loading_overlay.call("debug_snapshot") as Dictionary
	)
	_game_screen.application_intent_requested.connect(
		_on_application_intent_requested
	)
	_application_flow.projection_changed.connect(_on_projection_changed)
	_application_flow.receipt_ready.connect(_on_receipt_ready)
	_application_flow.owner_private_receipt_ready.connect(
		_on_owner_private_receipt_ready
	)
	_application_flow.deck_lifecycle_presentation_receipt_ready.connect(
		_on_deck_lifecycle_presentation_receipt_ready
	)
	_application_flow.public_resolution_ready.connect(
		_on_public_resolution_ready
	)
	_application_flow.final_settlement_presented.connect(
		_on_final_settlement_presented
	)
	_application_flow.runtime_fault_presented.connect(
		_on_runtime_fault_presented
	)


func game_runtime_context_query() -> RuntimeContextQuery:
	return RuntimeContextQuery.bind(
		self,
		_application_flow,
		_game_screen,
		_playtest_telemetry
	)


func _on_application_intent_requested(intent: Dictionary) -> void:
	if (
		_new_game_loading_overlay.has_method("intercept_application_intent")
		and bool(_new_game_loading_overlay.call(
			"intercept_application_intent",
			intent
		))
	):
		return
	_application_flow.call("submit_intent", intent)


func _on_projection_changed(snapshot: Dictionary) -> void:
	_game_screen.call("apply_snapshot", snapshot)


func _on_receipt_ready(receipt: Dictionary) -> void:
	_game_screen.call("apply_receipt", receipt)


func _on_owner_private_receipt_ready(receipt: Dictionary) -> void:
	_game_screen.call("apply_owner_private_receipt", receipt)


func _on_deck_lifecycle_presentation_receipt_ready(
	receipt: Dictionary
) -> void:
	_game_screen.call("apply_deck_lifecycle_receipt", receipt)


func _on_public_resolution_ready(receipt: Dictionary) -> void:
	_game_screen.call("apply_public_resolution_receipt", receipt)


func _on_final_settlement_presented(settlement: Dictionary) -> void:
	_game_screen.call("present_final_settlement", settlement)


func _on_runtime_fault_presented(receipt: Dictionary) -> void:
	_game_screen.call("present_runtime_fault", receipt)


func _on_loading_stage_changed(snapshot: Dictionary) -> void:
	if _game_screen.has_method("set_presentation_loading_active"):
		_game_screen.call(
			"set_presentation_loading_active",
			bool(snapshot.get("loading", snapshot.get("visible", false)))
		)

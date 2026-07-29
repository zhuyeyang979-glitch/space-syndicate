extends SceneTree

const INTENT := preload("res://scripts/runtime/table_selection_intent.gd")
const IDENTITY_REQUEST := preload("res://scripts/runtime/player_identity_action_request.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	_expect(INTENT.PLAYER_INSPECTION_SOURCE_SURFACES.has(&"player_roster"), "player roster is an authorized inspection source")
	_expect(not INTENT.PLAYER_INSPECTION_SOURCE_SURFACES.has(&"player_seat"), "retired player seat is not an inspection source")
	_expect(not INTENT.CARD_RESOLUTION_SELECTION_SOURCE_SURFACES.has(&"right_inspector"), "retired RightInspector is not a card-resolution source")
	_expect(IDENTITY_REQUEST.SOURCE_SURFACES.has(&"player_roster"), "shared identity envelope authorizes player roster")
	_expect(not IDENTITY_REQUEST.SOURCE_SURFACES.has(&"player_seat"), "shared identity envelope retires player seat")
	_expect(not IDENTITY_REQUEST.SOURCE_SURFACES.has(&"right_inspector"), "shared identity envelope retires RightInspector")
	for source_surface in INTENT.PLAYER_INSPECTION_SOURCE_SURFACES:
		_expect(IDENTITY_REQUEST.SOURCE_SURFACES.has(source_surface), "identity envelope covers inspection source %s" % str(source_surface))
	for source_surface in INTENT.CARD_RESOLUTION_SELECTION_SOURCE_SURFACES:
		_expect(IDENTITY_REQUEST.SOURCE_SURFACES.has(source_surface), "identity envelope covers card-resolution source %s" % str(source_surface))

	var roster_intent := _selection_intent(INTENT.KIND_INSPECT_PLAYER, &"player_roster")
	roster_intent.target_player_index = 2
	_expect(bool(roster_intent.validation_report().get("valid", false)), "player roster inspection intent validates")
	var old_seat_intent := _selection_intent(INTENT.KIND_INSPECT_PLAYER, &"player_seat")
	old_seat_intent.target_player_index = 2
	_expect(str(old_seat_intent.validation_report().get("reason_code", "")) == "source_surface_invalid", "old player seat intent fails closed")
	var old_inspector_intent := _selection_intent(INTENT.KIND_SELECT_CARD_RESOLUTION, &"right_inspector")
	old_inspector_intent.target_card_resolution_id = 4
	_expect(str(old_inspector_intent.validation_report().get("reason_code", "")) == "source_surface_invalid", "old RightInspector focus intent fails closed")
	var track_intent := _selection_intent(INTENT.KIND_SELECT_CARD_RESOLUTION, &"card_resolution_track")
	track_intent.target_card_resolution_id = 4
	_expect(bool(track_intent.validation_report().get("valid", false)), "public card-resolution track remains authorized")

	var identity := IDENTITY_REQUEST.new()
	identity.request_id = "identity:player-roster"
	identity.viewer_index = 0
	identity.authorized_player_index = 0
	identity.authorization_revision = 3
	identity.session_id = "session:alpha04b"
	identity.session_revision = 5
	identity.source_surface = &"player_roster"
	identity.request_revision = 1
	_expect(bool(identity.validation_report().get("valid", false)), "player roster survives the shared identity boundary")
	_finish()


func _selection_intent(kind: StringName, source_surface: StringName) -> TableSelectionIntent:
	var intent := INTENT.new()
	intent.request_id = "selection:%s:%s" % [str(kind), str(source_surface)]
	intent.selection_kind = kind
	intent.viewer_index = 0
	intent.authorization_revision = 3
	intent.session_id = "session:alpha04b"
	intent.session_revision = 5
	intent.expected_selection_revision = 0
	intent.source_surface = source_surface
	intent.request_revision = 1
	return intent


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("ALPHA04B_TABLE_SELECTION_SOURCE_SURFACE_CONTRACT_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("ALPHA04B_TABLE_SELECTION_SOURCE_SURFACE_CONTRACT_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)

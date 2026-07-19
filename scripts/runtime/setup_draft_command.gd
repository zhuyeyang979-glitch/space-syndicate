extends RefCounted
class_name SetupDraftCommand

const SCHEMA_VERSION := 1
const KIND_SET_PLAYER_COUNT := &"set_player_count"
const KIND_SET_AI_PLAYER_COUNT := &"set_ai_player_count"
const KIND_SET_CHALLENGE_DEPTH := &"set_challenge_depth"
const KIND_STEP_ROLE := &"step_role"
const KIND_SET_ROLE_RANDOM := &"set_role_random"
const KIND_STEP_STARTER_MONSTER := &"step_starter_monster"
const KIND_RESET_DEFAULTS := &"reset_defaults"
const ALLOWED_KINDS := [
	KIND_SET_PLAYER_COUNT,
	KIND_SET_AI_PLAYER_COUNT,
	KIND_SET_CHALLENGE_DEPTH,
	KIND_STEP_ROLE,
	KIND_SET_ROLE_RANDOM,
	KIND_STEP_STARTER_MONSTER,
	KIND_RESET_DEFAULTS,
]

var command_id := ""
var command_kind := StringName()
var expected_draft_revision := -1
var player_index := -1
var integer_value := 0
var source_context := "setup_ui"


static func create(
	id: String,
	kind: StringName,
	expected_revision: int,
	value: int = 0,
	seat_index: int = -1,
	context: String = "setup_ui"
) -> SetupDraftCommand:
	var command := SetupDraftCommand.new()
	command.command_id = id.strip_edges()
	command.command_kind = kind
	command.expected_draft_revision = expected_revision
	command.integer_value = value
	command.player_index = seat_index
	command.source_context = context.strip_edges()
	return command


func is_valid() -> bool:
	if command_id.is_empty() or not ALLOWED_KINDS.has(command_kind):
		return false
	if expected_draft_revision < 0 or source_context.is_empty():
		return false
	if command_kind in [&"step_role", &"set_role_random", &"step_starter_monster"]:
		return player_index >= 0
	return player_index == -1


func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"command_id": command_id,
		"command_kind": String(command_kind),
		"expected_draft_revision": expected_draft_revision,
		"player_index": player_index,
		"integer_value": integer_value,
		"source_context": source_context,
	}


func fingerprint() -> String:
	return JSON.stringify(to_dictionary())

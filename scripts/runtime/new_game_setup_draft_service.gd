@tool
extends Node
class_name NewGameSetupDraftService

const MIN_PLAYER_COUNT := 3
const MAX_PLAYER_COUNT := 8
const MIN_AI_PLAYER_COUNT := 2
const MAX_AI_PLAYER_COUNT := 7
const MIN_CHALLENGE_DEPTH := 1
const MAX_CHALLENGE_DEPTH := 6
const ROLE_RANDOM_INDEX := -1
const MonsterCatalog := preload("res://scripts/runtime/monster_catalog_v06.gd")
const AlphaContentLoader := preload("res://scripts/runtime/alpha01_content_manifest_loader.gd")

@export var role_catalog_path: NodePath

var _draft_revision := 0
var _player_count := 4
var _ai_player_count := 3
var _challenge_depth := 1
var _role_indices: Array[int] = []
var _starter_monster_indices: Array[int] = []
var _monster_catalog_count := 0


func _ready() -> void:
	_monster_catalog_count = MonsterCatalog.catalog_size()
	reset_to_defaults()


func configure_monster_catalog_count(count: int) -> void:
	_monster_catalog_count = maxi(0, count)
	_normalize(false)


func reset_to_defaults() -> Dictionary:
	_player_count = 4
	_ai_player_count = 3
	_challenge_depth = 1
	_role_indices.clear()
	_starter_monster_indices.clear()
	var content := AlphaContentLoader.load_active_selection()
	var allowed_roles: Array[int] = []
	var allowed_monsters: Array[int] = []
	if content.is_valid():
		allowed_roles = content.role_source_indices()
		allowed_monsters = content.monster_source_indices()
	for index in range(MAX_PLAYER_COUNT):
		_role_indices.append(allowed_roles[index % maxi(1, allowed_roles.size())] if not allowed_roles.is_empty() else 0)
		_starter_monster_indices.append(allowed_monsters[index % maxi(1, allowed_monsters.size())] if not allowed_monsters.is_empty() else 0)
	_normalize(false)
	_draft_revision += 1
	return draft_snapshot()


func draft_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"draft_revision": _draft_revision,
		"player_count": _player_count,
		"ai_player_count": _ai_player_count,
		"challenge_depth": _challenge_depth,
		"role_indices": _role_indices.duplicate(),
		"starter_monster_indices": _starter_monster_indices.duplicate(),
		"human_player_count": maxi(1, _player_count - _ai_player_count),
	}


func preflight_command(command: SetupDraftCommand) -> Dictionary:
	if command == null or not command.is_valid():
		return {"accepted": false, "reason_code": "setup_command_invalid"}
	if command.expected_draft_revision != _draft_revision:
		return {"accepted": false, "reason_code": "setup_draft_revision_stale"}
	match command.command_kind:
		&"set_player_count":
			if command.integer_value < MIN_PLAYER_COUNT or command.integer_value > MAX_PLAYER_COUNT:
				return {"accepted": false, "reason_code": "setup_player_count_invalid"}
		&"set_ai_player_count":
			if command.integer_value < MIN_AI_PLAYER_COUNT or command.integer_value > mini(MAX_AI_PLAYER_COUNT, _player_count - 1):
				return {"accepted": false, "reason_code": "setup_ai_count_invalid"}
		&"set_challenge_depth":
			if command.integer_value < MIN_CHALLENGE_DEPTH or command.integer_value > MAX_CHALLENGE_DEPTH:
				return {"accepted": false, "reason_code": "setup_challenge_depth_invalid"}
		&"step_role", &"set_role_random", &"step_starter_monster":
			if command.player_index < 0 or command.player_index >= _player_count:
				return {"accepted": false, "reason_code": "setup_player_index_invalid"}
			if command.command_kind == &"set_role_random" and command.player_index < _player_count - _ai_player_count:
				return {"accepted": false, "reason_code": "setup_random_role_human_forbidden"}
			if command.command_kind != &"set_role_random" and command.integer_value == 0:
				return {"accepted": false, "reason_code": "setup_step_zero"}
	return {"accepted": true, "reason_code": "setup_command_valid"}


func apply_command(command: SetupDraftCommand) -> SetupDraftCommandReceipt:
	var preflight := preflight_command(command)
	if not bool(preflight.get("accepted", false)):
		return SetupDraftCommandReceipt.make(command, false, false, str(preflight.get("reason_code", "setup_command_invalid")), _draft_revision)
	match command.command_kind:
		&"set_player_count":
			_player_count = command.integer_value
		&"set_ai_player_count":
			_ai_player_count = command.integer_value
		&"set_challenge_depth":
			_challenge_depth = command.integer_value
		&"step_role":
			var stepped_role := _step_selected_identity(_role_indices[command.player_index], command.integer_value, _allowed_role_indices())
			_role_indices[command.player_index] = _next_available_role(command.player_index, stepped_role)
		&"set_role_random":
			_role_indices[command.player_index] = ROLE_RANDOM_INDEX
		&"step_starter_monster":
			var allowed_monsters := _allowed_monster_indices()
			if allowed_monsters.is_empty():
				return SetupDraftCommandReceipt.make(command, false, false, "setup_monster_catalog_empty", _draft_revision)
			_starter_monster_indices[command.player_index] = _step_selected_identity(_starter_monster_indices[command.player_index], command.integer_value, allowed_monsters)
		&"reset_defaults":
			reset_to_defaults()
			return SetupDraftCommandReceipt.make(command, true, true, "setup_defaults_reset", _draft_revision)
	_normalize(false)
	_draft_revision += 1
	return SetupDraftCommandReceipt.make(command, true, true, "setup_command_applied", _draft_revision)


func capture_checkpoint() -> Dictionary:
	return draft_snapshot()


func restore_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if not _valid_snapshot(checkpoint):
		return {"restored": false, "reason_code": "setup_checkpoint_invalid"}
	_draft_revision = int(checkpoint.get("draft_revision", 0))
	_player_count = int(checkpoint.get("player_count", 4))
	_ai_player_count = int(checkpoint.get("ai_player_count", 3))
	_challenge_depth = int(checkpoint.get("challenge_depth", 1))
	_role_indices.assign(checkpoint.get("role_indices", []))
	_starter_monster_indices.assign(checkpoint.get("starter_monster_indices", []))
	_normalize(false)
	return {"restored": true, "reason_code": "setup_checkpoint_restored"}


func debug_snapshot() -> Dictionary:
	return {
		"owner_id": "new_game_setup_draft_service_v1",
		"draft_revision": _draft_revision,
		"unique_setup_draft_owner": true,
		"active_role_count": _allowed_role_indices().size(),
		"active_monster_count": _allowed_monster_indices().size(),
		"save_section_count": 0,
		"owns_live_world": false,
		"references_main": false,
	}


func _normalize(bump_revision: bool) -> void:
	_player_count = clampi(_player_count, MIN_PLAYER_COUNT, MAX_PLAYER_COUNT)
	_ai_player_count = clampi(_ai_player_count, MIN_AI_PLAYER_COUNT, mini(MAX_AI_PLAYER_COUNT, _player_count - 1))
	_challenge_depth = clampi(_challenge_depth, MIN_CHALLENGE_DEPTH, MAX_CHALLENGE_DEPTH)
	var allowed_roles := _allowed_role_indices()
	var allowed_monsters := _allowed_monster_indices()
	while _role_indices.size() < MAX_PLAYER_COUNT:
		_role_indices.append(allowed_roles[_role_indices.size() % maxi(1, allowed_roles.size())] if not allowed_roles.is_empty() else 0)
	while _starter_monster_indices.size() < MAX_PLAYER_COUNT:
		_starter_monster_indices.append(allowed_monsters[_starter_monster_indices.size() % maxi(1, allowed_monsters.size())] if not allowed_monsters.is_empty() else 0)
	_role_indices.resize(MAX_PLAYER_COUNT)
	_starter_monster_indices.resize(MAX_PLAYER_COUNT)
	var used := {}
	for index in range(MAX_PLAYER_COUNT):
		var role_index := _role_indices[index]
		if role_index == ROLE_RANDOM_INDEX and index >= _player_count - _ai_player_count:
			continue
		_role_indices[index] = _next_available_role(index, role_index, used if index < _player_count else {})
		if index < _player_count:
			used[_role_indices[index]] = true
		if not allowed_monsters.is_empty():
			if not allowed_monsters.has(_starter_monster_indices[index]):
				_starter_monster_indices[index] = allowed_monsters[index % allowed_monsters.size()]
		else:
			_starter_monster_indices[index] = 0
	if bump_revision:
		_draft_revision += 1


func _next_available_role(_player_index: int, start_index: int, used_override: Dictionary = {}) -> int:
	var allowed_roles := _allowed_role_indices()
	if allowed_roles.is_empty():
		return 0
	var used := used_override
	if used_override.is_empty():
		used = {}
		for index in range(_player_count):
			if index == _player_index or index >= _role_indices.size() or _role_indices[index] < 0:
				continue
			used[_role_indices[index]] = true
	var start_position := allowed_roles.find(start_index)
	if start_position < 0:
		start_position = 0
	for offset in range(allowed_roles.size()):
		var candidate := allowed_roles[wrapi(start_position + offset, 0, allowed_roles.size())]
		if not used.has(candidate):
			return candidate
	return allowed_roles[start_position]


func _role_count() -> int:
	return _allowed_role_indices().size()


func _allowed_role_indices() -> Array[int]:
	var content := AlphaContentLoader.load_active_selection()
	if not content.is_valid():
		return []
	var catalog := get_node_or_null(role_catalog_path) as RoleCatalogRuntimeService
	var result: Array[int] = []
	for source_index in content.role_source_indices():
		if catalog != null and not catalog.definition_at(source_index).is_empty():
			result.append(source_index)
	return result


func _allowed_monster_indices() -> Array[int]:
	var content := AlphaContentLoader.load_active_selection()
	if not content.is_valid():
		return []
	var result: Array[int] = []
	for source_index in content.monster_source_indices():
		if source_index >= 0 and source_index < mini(_monster_catalog_count, MonsterCatalog.catalog_size()):
			result.append(source_index)
	return result


func _step_selected_identity(current: int, step: int, allowed: Array[int]) -> int:
	if allowed.is_empty():
		return 0
	var position := allowed.find(current)
	if position < 0:
		position = 0
	return allowed[wrapi(position + step, 0, allowed.size())]


func _valid_snapshot(snapshot: Dictionary) -> bool:
	return int(snapshot.get("schema_version", 0)) == 1 \
		and snapshot.get("role_indices") is Array \
		and snapshot.get("starter_monster_indices") is Array \
		and int(snapshot.get("player_count", 0)) in range(MIN_PLAYER_COUNT, MAX_PLAYER_COUNT + 1)

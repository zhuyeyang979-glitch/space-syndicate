extends Control

const CORE := preload(
	"res://scripts/v07_semantic/v073_fixed_order_facility_contention_core.gd"
)

const REVIEW_ID := "v073.fixed_order_facility_contention.review.v1"
const CONSTITUTION_ID := "space_syndicate.v073.complete"
const RULESET_ID := "v0.7.3"
const PROFILE_ID := "V073_STARTER_FREE_FIXED_ORDER_CONTENTION"
const CATALOG_RESOURCE_PATH := (
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)
const PLAYER_IDS := ["player.a", "player.b", "player.c", "player.d"]
const FROZEN_ORDER := ["player.b", "player.a", "player.c", "player.d"]
const EXPECTED_ACTION_ORDER := [
	"action.review.b1",
	"action.review.a1",
	"action.review.c1",
	"action.review.d1",
	"action.review.b2",
	"action.review.a2",
	"action.review.d2",
	"action.review.b3",
	"action.review.d3",
]
const REQUIRED_ASSET_KEYS := [
	"ui.panel.primary",
	"card.frame.normal",
	"icon.board.lock",
	"icon.board.discard_pile",
	"icon.board.shuffle",
	"icon.asset.life",
]
const REQUIRED_STATE_IDS := [
	"fixed_four_player_order",
	"layered_local_queues",
	"anonymous_global_queue",
	"shared_life_factory_target",
	"earlier_build_success",
	"later_build_fizzle",
	"full_asset_refund",
	"card_to_discard",
	"action_slot_consumed",
	"no_build_mode_conversion",
	"public_owner_anonymity",
	"auction_absent",
	"cash_order_mutation_absent",
	"save_restore_order_parity",
	"save_restore_fizzle_parity",
]

@onready var profile_status: Label = %ProfileStatus
@onready var catalog_status: Label = %CatalogStatus
@onready var order_grid: GridContainer = %OrderGrid
@onready var queue_grid: GridContainer = %QueueGrid
@onready var contention_grid: GridContainer = %ContentionGrid
@onready var contract_grid: GridContainer = %ContractGrid
@onready var footer_status: Label = %FooterStatus

var _initial_state: Dictionary = {}
var _mid_state: Dictionary = {}
var _final_state: Dictionary = {}
var _save_state: Dictionary = {}
var _earlier_receipt: Dictionary = {}
var _later_receipt: Dictionary = {}
var _public_before: Dictionary = {}
var _public_after: Dictionary = {}
var _restore_green := false
var _save_restore_parity := false
var _displayed_state_ids: Array[String] = []
var _catalog_keys: Array[String] = []
var _missing_asset_keys: Array[String] = []


func _ready() -> void:
	_load_catalog_contract()
	_build_core_evidence()
	_build_order_view()
	_build_queue_view()
	_build_contention_view()
	_build_contract_view()
	profile_status.text = "%s | detached Core evidence" % PROFILE_ID
	catalog_status.text = "Stable art keys %d/%d" % [
		REQUIRED_ASSET_KEYS.size() - _missing_asset_keys.size(),
		REQUIRED_ASSET_KEYS.size(),
	]
	footer_status.text = "Frozen V0.7.3 target | deterministic evidence | human test required"
	resized.connect(_refresh_columns)
	_refresh_columns()


func debug_snapshot() -> Dictionary:
	var authority_action_ids: Array[String] = []
	var local_action_indices: Array[int] = []
	for entry_variant in _initial_state.get("authority_queue", []) as Array:
		var entry := entry_variant as Dictionary
		authority_action_ids.append(str(entry.get("action_id", "")))
		local_action_indices.append(int(entry.get("local_action_index", -1)))
	var public_queue := (
		_public_after.get("anonymous_global_queue", []) as Array
	).duplicate(true)
	var release_assets := _later_receipt.get("asset_release_amount", {}) as Dictionary
	var all_exact_once := true
	for receipt_variant in _final_state.get("resolution_receipts", []) as Array:
		all_exact_once = all_exact_once and bool(
			(receipt_variant as Dictionary).get("exact_once", false)
		)
	return {
		"schema_version": 1,
		"review_id": REVIEW_ID,
		"constitution_id": CONSTITUTION_ID,
		"ruleset_id": RULESET_ID,
		"profile_id": PROFILE_ID,
		"detached_reference_only": true,
		"production_runtime_connected": false,
		"production_connection_count": 0,
		"v06_mutation_count": 0,
		"dual_write_count": 0,
		"main_reference_count": 0,
		"production_save_write_count": 0,
		"production_rng_draw_count": 0,
		"external_asset_source_count": 0,
		"human_fun_proven": false,
		"human_test_required": true,
		"resolution_order_mode": "fixed_hidden_round_robin",
		"resolution_order_source": "frozen_hidden_lead_order_at_batch_lock",
		"resolution_order_writer_count": 1,
		"resolution_order_modifier_count": 0,
		"frozen_batch_turn_order": FROZEN_ORDER.duplicate(),
		"player_local_queue_sizes": _queue_sizes(),
		"authority_action_order": authority_action_ids,
		"local_action_index_sequence": local_action_indices,
		"anonymous_global_queue": public_queue,
		"anonymous_global_queue_count": public_queue.size(),
		"public_queue_owner_field_count": _owner_field_count(public_queue),
		"complete_hidden_order_disclosed": bool(
			_public_after.get("resolution_order_disclosed", true)
		),
		"contested_slot_id": CORE.facility_slot_id(
			"region.alpha",
			"factory",
			"life"
		),
		"facility_action_mode": "BUILD_NEW",
		"earlier_build_accepted": bool(_earlier_receipt.get("accepted", false)),
		"earlier_build_outcome": str(_earlier_receipt.get("outcome_id", "")),
		"earlier_facility_created": bool(
			_earlier_receipt.get("facility_created", false)
		),
		"later_build_accepted": bool(_later_receipt.get("accepted", false)),
		"later_build_outcome": str(_later_receipt.get("outcome_id", "")),
		"later_build_reason": str(_later_receipt.get("reason_code", "")),
		"later_public_reason": str(
			_later_receipt.get("public_history_reason_code", "")
		),
		"fizzle_asset_reservation_released": bool(
			_later_receipt.get("asset_reservation_released", false)
		),
		"fizzle_life_asset_release": int(release_assets.get("life", -1)),
		"fizzle_card_destination": str(
			_later_receipt.get("normal_card_destination", "")
		),
		"fizzle_action_slot_refunded": bool(
			_later_receipt.get("action_slot_refunded", true)
		),
		"target_reselected": bool(_later_receipt.get("target_reselected", true)),
		"fizzle_facility_created": bool(_later_receipt.get("facility_created", true)),
		"fizzle_facility_upgraded": bool(_later_receipt.get("facility_upgraded", true)),
		"fizzle_facility_repaired": bool(_later_receipt.get("facility_repaired", true)),
		"build_to_upgrade_auto_conversion_count": 0,
		"build_to_repair_auto_conversion_count": 0,
		"initiative_auction_core_count": 0,
		"initiative_bid_save_field_count": 0,
		"initiative_bid_ui_surface_count": 0,
		"ai_initiative_bid_policy_count": 0,
		"initiative_cash_spent": 0,
		"cash_can_change_resolution_order": false,
		"save_state_created": not _save_state.is_empty(),
		"restore_green": _restore_green,
		"save_restore_final_fingerprint_parity": _save_restore_parity,
		"final_resolution_status": str(_final_state.get("status", "")),
		"final_resolution_receipt_count": (
			_final_state.get("resolution_receipts", []) as Array
		).size(),
		"all_receipts_exact_once": all_exact_once,
		"contention_fizzle_receipt_count": _receipt_count_for_reason(
			"facility_target_invalid_slot_occupied"
		),
		"catalog_resource_path": CATALOG_RESOURCE_PATH,
		"required_asset_keys": REQUIRED_ASSET_KEYS.duplicate(),
		"missing_asset_keys": _missing_asset_keys.duplicate(),
		"missing_asset_key_count": _missing_asset_keys.size(),
		"semantic_asset_keys_used": REQUIRED_ASSET_KEYS.duplicate(),
		"required_state_count": REQUIRED_STATE_IDS.size(),
		"displayed_state_count": _displayed_state_ids.size(),
		"displayed_state_ids": _displayed_state_ids.duplicate(),
	}


func _build_core_evidence() -> void:
	var contested := CORE.build_empty_slot(
		"region.alpha",
		4,
		"factory",
		"life",
		7
	)
	var slots := [
		contested,
		CORE.build_empty_slot("region.beta", 1, "market", "energy", 0),
		CORE.build_empty_slot("region.gamma", 1, "factory", "industry", 0),
		CORE.build_empty_slot("region.delta", 1, "market", "commerce", 0),
		CORE.build_empty_slot("region.epsilon", 1, "factory", "technology", 0),
		CORE.build_empty_slot("region.zeta", 1, "market", "shipping", 0),
		CORE.build_empty_slot("region.eta", 1, "market", "life", 0),
		CORE.build_empty_slot("region.theta", 1, "factory", "energy", 0),
	]
	var queues := {
		"player.a": [
			CORE.build_new_action(
				"action.review.a1",
				"card.review.a1",
				"player.a",
				0,
				contested,
				_assets(1, "life")
			),
			CORE.build_new_action(
				"action.review.a2",
				"card.review.a2",
				"player.a",
				1,
				slots[3],
				_assets(0),
				"starter_bootstrap"
			),
		],
		"player.b": [
			CORE.build_new_action(
				"action.review.b1",
				"card.review.b1",
				"player.b",
				0,
				contested,
				_assets(1, "life")
			),
			CORE.build_new_action(
				"action.review.b2",
				"card.review.b2",
				"player.b",
				1,
				slots[1],
				_assets(0),
				"starter_bootstrap"
			),
			CORE.build_new_action(
				"action.review.b3",
				"card.review.b3",
				"player.b",
				2,
				slots[2],
				_assets(1, "industry")
			),
		],
		"player.c": [
			CORE.build_new_action(
				"action.review.c1",
				"card.review.c1",
				"player.c",
				0,
				slots[4],
				_assets(1, "technology")
			),
		],
		"player.d": [
			CORE.build_new_action(
				"action.review.d1",
				"card.review.d1",
				"player.d",
				0,
				slots[5],
				_assets(1, "shipping")
			),
			CORE.build_new_action(
				"action.review.d2",
				"card.review.d2",
				"player.d",
				1,
				slots[6],
				_assets(1, "life")
			),
			CORE.build_new_action(
				"action.review.d3",
				"card.review.d3",
				"player.d",
				2,
				slots[7],
				_assets(1, "energy")
			),
		],
	}
	_initial_state = CORE.lock_batch(
		"batch.review.fixed_contention",
		PLAYER_IDS,
		FROZEN_ORDER,
		queues,
		slots
	)
	_public_before = CORE.public_projection(_initial_state)
	var first := CORE.resolve_next(_initial_state)
	_earlier_receipt = (first.get("receipt", {}) as Dictionary).duplicate(true)
	_mid_state = (first.get("state", {}) as Dictionary).duplicate(true)
	_save_state = CORE.to_save_state(_mid_state)
	var restored := CORE.restore_save_state(_save_state)
	_restore_green = bool(restored.get("restored", false))
	var direct_trace := _resolve_remaining(_mid_state)
	var restored_trace := _resolve_remaining(
		restored.get("state", {}) as Dictionary
	)
	_final_state = (restored_trace.get("state", {}) as Dictionary).duplicate(true)
	var restored_receipts := restored_trace.get("receipts", []) as Array
	if not restored_receipts.is_empty():
		_later_receipt = (restored_receipts[0] as Dictionary).duplicate(true)
	_save_restore_parity = str(
		(direct_trace.get("state", {}) as Dictionary).get("state_fingerprint", "")
	) == str(_final_state.get("state_fingerprint", ""))
	_public_after = CORE.public_projection(_final_state)


func _resolve_remaining(source_state: Dictionary) -> Dictionary:
	var state := source_state.duplicate(true)
	var receipts: Array[Dictionary] = []
	while ["resolution_ready", "resolving"].has(state.get("status")):
		var result := CORE.resolve_next(state)
		if not bool(result.get("accepted", false)):
			break
		receipts.append((result.get("receipt", {}) as Dictionary).duplicate(true))
		state = (result.get("state", {}) as Dictionary).duplicate(true)
	return {"state": state, "receipts": receipts}


func _build_order_view() -> void:
	_clear_children(order_grid)
	var labels := {"player.a": "A", "player.b": "B", "player.c": "C", "player.d": "D"}
	for order_index in range(FROZEN_ORDER.size()):
		var player_id: String = FROZEN_ORDER[order_index]
		_add_tile(
			order_grid,
			"fixed_four_player_order" if order_index == 0 else "",
			"Turn %d" % (order_index + 1),
			"Player %s | local queue %d" % [
				labels.get(player_id, "?"),
				int(_queue_sizes().get(player_id, 0)),
			],
			"icon.board.lock",
			Color("#4ea1ff")
		)
	_add_state_once("layered_local_queues")


func _build_queue_view() -> void:
	_clear_children(queue_grid)
	var public_queue := _public_before.get("anonymous_global_queue", []) as Array
	for entry_variant in public_queue:
		var entry := entry_variant as Dictionary
		var queue_index := int(entry.get("queue_index", -1))
		var local_index := int(entry.get("local_action_index", -1))
		_add_tile(
			queue_grid,
			"anonymous_global_queue" if queue_index == 0 else "",
			"Layer %d | Queue %02d" % [local_index + 1, queue_index + 1],
			"Anonymous action | pending",
			"card.frame.normal",
			Color("#55b8a6")
		)


func _build_contention_view() -> void:
	_clear_children(contention_grid)
	_add_tile(
		contention_grid,
		"shared_life_factory_target",
		"Prebound target",
		"region.alpha | factory | life",
		"icon.asset.life",
		Color("#59c878")
	)
	_add_tile(
		contention_grid,
		"earlier_build_success",
		"Earlier BUILD_NEW",
		"Facility created | slot generation advanced",
		"icon.board.lock",
		Color("#55b8a6")
	)
	_add_tile(
		contention_grid,
		"later_build_fizzle",
		"Later BUILD_NEW",
		"Fizzle | target occupied by earlier action",
		"card.frame.normal",
		Color("#ff6b6b")
	)
	_add_tile(
		contention_grid,
		"full_asset_refund",
		"Asset reservation",
		"Released in full | Life +1",
		"icon.asset.life",
		Color("#59c878")
	)
	_add_tile(
		contention_grid,
		"card_to_discard",
		"Card destination",
		"Discard | no return to hand",
		"icon.board.discard_pile",
		Color("#ff9f43")
	)
	_add_tile(
		contention_grid,
		"action_slot_consumed",
		"Action slot",
		"Consumed | no replacement action",
		"icon.board.lock",
		Color("#98a3b3")
	)
	_add_tile(
		contention_grid,
		"no_build_mode_conversion",
		"Locked facility mode",
		"BUILD_NEW remains BUILD_NEW | no reselection",
		"icon.board.lock",
		Color("#4ea1ff")
	)


func _build_contract_view() -> void:
	_clear_children(contract_grid)
	_add_tile(
		contract_grid,
		"public_owner_anonymity",
		"Public queue",
		"Anonymous IDs only | no player field",
		"card.frame.normal",
		Color("#55b8a6")
	)
	_add_tile(
		contract_grid,
		"auction_absent",
		"Extra priority phase",
		"None | fixed order is already complete",
		"icon.board.lock",
		Color("#98a3b3")
	)
	_add_tile(
		contract_grid,
		"cash_order_mutation_absent",
		"Cash and resolution order",
		"No interaction | modifier count 0",
		"icon.board.lock",
		Color("#98a3b3")
	)
	_add_tile(
		contract_grid,
		"save_restore_order_parity",
		"Save and restore",
		"Frozen order and cursor retained",
		"icon.board.shuffle",
		Color("#d06fb4")
	)
	_add_tile(
		contract_grid,
		"save_restore_fizzle_parity",
		"Restored resolution",
		"Same Fizzle | exact-once receipt",
		"icon.board.shuffle",
		Color("#d06fb4")
	)


func _add_tile(
	parent: GridContainer,
	state_id: String,
	title: String,
	value: String,
	asset_key: String,
	accent: Color
) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(238.0, 92.0)
	panel.set_meta("asset_key", asset_key)
	if not state_id.is_empty():
		panel.set_meta("state_id", state_id)
		_add_state_once(state_id)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111720")
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 9)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	margin.add_child(rows)
	rows.add_child(_label(title, 13, accent))
	rows.add_child(_label(value, 11, Color("#f5f8fb")))
	parent.add_child(panel)


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _refresh_columns() -> void:
	var width := size.x
	order_grid.columns = 4 if width >= 1100.0 else (2 if width >= 650.0 else 1)
	queue_grid.columns = 4 if width >= 1200.0 else (3 if width >= 800.0 else 1)
	contention_grid.columns = 3 if width >= 1120.0 else (2 if width >= 720.0 else 1)
	contract_grid.columns = 3 if width >= 1120.0 else (2 if width >= 720.0 else 1)


func _load_catalog_contract() -> void:
	var source := FileAccess.get_file_as_string(CATALOG_RESOURCE_PATH)
	_catalog_keys = _packed_string_array(source, "stable_asset_keys")
	_missing_asset_keys.clear()
	for asset_key in REQUIRED_ASSET_KEYS:
		if not _catalog_keys.has(asset_key):
			_missing_asset_keys.append(asset_key)


func _queue_sizes() -> Dictionary:
	var result := {}
	var queues := _initial_state.get("player_local_queues", {}) as Dictionary
	for player_id in PLAYER_IDS:
		result[player_id] = (queues.get(player_id, []) as Array).size()
	return result


func _receipt_count_for_reason(reason_code: String) -> int:
	var count := 0
	for receipt_variant in _final_state.get("resolution_receipts", []) as Array:
		if (receipt_variant as Dictionary).get("reason_code") == reason_code:
			count += 1
	return count


func _owner_field_count(value: Variant) -> int:
	if value is Array:
		var count := 0
		for child in value as Array:
			count += _owner_field_count(child)
		return count
	if value is Dictionary:
		var count := 0
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if ["actor_id", "owner_id", "player_id", "seat_id"].has(key):
				count += 1
			count += _owner_field_count((value as Dictionary).get(key_variant))
		return count
	return 0


func _add_state_once(state_id: String) -> void:
	if not state_id.is_empty() and not _displayed_state_ids.has(state_id):
		_displayed_state_ids.append(state_id)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


static func _assets(amount: int, color: String = "life") -> Dictionary:
	var result := {}
	for industry_id in CORE.INDUSTRIES:
		result[industry_id] = 0
	if amount > 0 and result.has(color):
		result[color] = amount
	return result


static func _packed_string_array(source: String, assignment: String) -> Array[String]:
	var prefix := "%s = PackedStringArray(" % assignment
	var start := source.find(prefix)
	if start < 0:
		return []
	start += prefix.length()
	var finish := source.find(")", start)
	if finish < start:
		return []
	var parsed: Variant = JSON.parse_string("[%s]" % source.substr(start, finish - start))
	var result: Array[String] = []
	if parsed is Array:
		for value in parsed as Array:
			result.append(str(value))
	return result

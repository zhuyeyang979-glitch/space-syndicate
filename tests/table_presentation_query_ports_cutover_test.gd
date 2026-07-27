extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const FORBIDDEN_KEYS := [
	"ai_plan", "ai_reason", "cash", "decision_samples", "hand", "hand_count",
	"hidden_owner", "learning_bonus", "owner", "owner_truth", "private_route_plan",
	"route_plan_score", "true_owner",
]
const FINAL_SETTLEMENT_ACK_KEYS := [
	"schema_version", "receipt_id", "outcome_id", "receipt_fingerprint",
	"accepted", "duplicate", "reason_id",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	var state := coordinator.world_session_state()
	state.replace_players(_fixture_players(), true)
	state.replace_districts(_fixture_districts(), true)
	state.set_game_time(75.0)
	coordinator.table_selection_state().set_active_context(0, 0, "crystal")
	var ports := coordinator.table_presentation_query_ports()
	_expect(ports != null, "production coordinator composes query ports")
	_expect(coordinator.find_children("TablePresentationQueryPorts", "", true, false).size() == 1, "query ports have one production instance")
	_expect(coordinator.presentation_authorized_viewer_index() == 0, "exactly one local human is authorized")
	_expect(coordinator.presentation_can_view_private_subject(0), "local viewer can read own private projection")
	_expect(not coordinator.presentation_can_view_private_subject(1), "local viewer cannot read opponent private projection")

	var public_world := coordinator.presentation_public_world_projection()
	_expect(public_world.players.size() == 3 and public_world.districts.size() == 2, "public world query exposes public participants and districts")
	_expect(not _contains_forbidden_key(public_world.to_dictionary()), "public world projection contains no private keys")
	_expect(not (public_world.districts[0] as Dictionary).get("city", {}).has("owner"), "public district city omits true owner")
	var own_private := coordinator.presentation_private_world_projection(0, 0)
	_expect(own_private.authorized and int(own_private.player.get("cash", -1)) == 900, "authorized viewer receives own cash")
	_expect((own_private.player.get("hand", []) as Array).size() == 1, "authorized viewer receives own allowlisted hand")
	_expect(not _contains_key_recursive(own_private.to_dictionary(), "hidden_owner"), "private projection strips hidden owner metadata")
	var opponent_private := coordinator.presentation_private_world_projection(0, 1)
	_expect(not opponent_private.authorized and opponent_private.player.is_empty(), "opponent private query fails closed")

	var map_projection := coordinator.presentation_public_map_projection(0, "crystal")
	_expect(map_projection.city_markers.size() == 2, "map projection contains public city markers")
	_expect(str((map_projection.city_markers[0] as Dictionary).get("owner_relation", "")) == "own", "own city is represented only as viewer relation")
	_expect(str((map_projection.city_markers[1] as Dictionary).get("owner_relation", "")) == "guessed", "opponent city uses the viewer's guess rather than owner truth")
	_expect(not _contains_forbidden_key(map_projection.to_dictionary()), "map projection is owner-truth redacted")

	var published := coordinator.record_public_log_event(&"table_public_update", &"public.table.updated", {"action_kind": "table", "public_status": "updated"}, 1, 75.0, "test-log-1")
	_expect(bool(published.get("applied", false)), "typed public log receipt is accepted once")
	var duplicate := coordinator.append_public_log_receipt(PublicLogReceipt.create("test-log-1", &"table_public_update", &"public.table.updated", {"action_kind": "table", "public_status": "updated"}, 1, 75.0))
	_expect(bool(duplicate.get("duplicate", false)), "duplicate public log receipt is rejected idempotently")
	var private_log := PublicLogReceipt.create("private-log", &"bad", &"bad", {"ai_plan": "SECRET"}, 1, 75.0)
	_expect(not private_log.is_valid(), "public log receipt rejects AI-private fields")
	var cash_log := PublicLogReceipt.create("cash-log", &"bad", &"bad", {"cash": 777}, 1, 75.0)
	_expect(not cash_log.is_valid(), "public log receipt rejects exact cash fields")
	var hand_log := PublicLogReceipt.create("hand-log", &"bad", &"bad", {"hand_count": 4}, 1, 75.0)
	_expect(not hand_log.is_valid(), "public log receipt rejects private hand fields")
	var owner_log := PublicLogReceipt.create("owner-log", &"bad", &"bad", {"owner_truth": 1}, 1, 75.0)
	_expect(not owner_log.is_valid(), "public log receipt rejects hidden owner truth")
	var arbitrary_log := PublicLogReceipt.create("arbitrary-log", &"bad", &"bad", {"internal_debug_payload": "SECRET"}, 1, 75.0)
	_expect(not arbitrary_log.is_valid(), "public log receipt rejects fields outside the public allowlist")
	_expect(coordinator.presentation_recent_public_log_messages(3).size() == 1, "public log owner is the only stored public history")
	var private_feedback := coordinator.record_legacy_viewer_feedback("当前只有¥123，私人目标已取消。")
	_expect(bool(private_feedback.get("applied", false)), "legacy local feedback is stored only for the authorized viewer")
	_expect(coordinator.presentation_recent_public_log_messages(3).size() == 1, "viewer-private feedback never enters public history")
	var production_log_cases := [
		["military-log", &"military_public_update", &"public.military.updated", {"action_kind": "military", "public_status": "updated"}],
		["monster-log", &"monster_public_update", &"public.monster.updated", {"action_kind": "monster", "public_status": "updated"}],
		["market-log", &"market_public_update", &"public.market.updated", {"action_kind": "market", "public_status": "updated"}],
		["weather-log", &"weather_public_update", &"public.weather.updated", {"action_kind": "weather", "public_status": "updated"}],
		["victory-log", &"victory_state_changed", &"victory.public.state_changed", {"previous_state": "idle", "state": "qualification"}],
	]
	for index in range(production_log_cases.size()):
		var log_case: Array = production_log_cases[index]
		var receipt := PublicLogReceipt.create(str(log_case[0]), log_case[1] as StringName, log_case[2] as StringName, log_case[3] as Dictionary, 10 + index, 80.0 + index)
		_expect(bool(coordinator.append_public_log_receipt(receipt).get("applied", false)), "production public log key is accepted by typed owner")
	var player_messages := coordinator.presentation_recent_public_log_messages(16)
	var player_messages_json := JSON.stringify(player_messages)
	_expect(not player_messages_json.contains("public.") and not player_messages_json.contains("victory."), "player-facing public log messages never expose localization keys")
	for raw_enum in ["updated", "idle", "qualification", "resolving"]:
		_expect(not player_messages_json.contains(raw_enum), "player-facing public log messages never expose raw enum: %s" % raw_enum)
	for localized_copy in ["军事部署已更新", "怪兽局势已更新", "商品市场已更新", "天气局势已更新", "胜利进程：等待 → 资格确认"]:
		_expect(player_messages_json.contains(localized_copy), "production localization key renders closed player copy: %s" % localized_copy)
	var sensitive_feedback_samples := [
		"资金不足：购买需要¥900，当前只有¥123。",
		"你的手牌有5张，必须选择一张弃牌。",
		"已私下弃置秘密牌。",
		"把乙城私人标注为玩家2。",
		"乙城标注置信度调整为高。",
		"乙城私人标注理由：牌序线索。",
		"匿名牌轨#3的真实出牌者已写入私人情报。",
		"合约真实签署者已写入私人情报。",
		"追加私有悬赏线索：城市2条。",
		"已取消怪兽目标选择，卡牌未消耗。",
		"已取消玩家目标选择，卡牌未消耗。",
		"目标玩家无效，请重新选择。",
		"当前操作冷却还需2.5秒。",
		"你购买了秘密卡牌，报价¥300。",
		"下次开局角色设置为黑潮风险基金。",
		"卡牌履历私人标注已更新；不产生现金或GDP。",
	]
	var public_count_before_sensitive := coordinator.presentation_recent_public_log_entries(64).size()
	for sample in sensitive_feedback_samples:
		_expect(bool(coordinator.record_legacy_viewer_feedback(sample).get("applied", false)), "sensitive local feedback is accepted only for the viewer")
	_expect(coordinator.presentation_recent_public_log_entries(64).size() == public_count_before_sensitive, "sixteen sensitive local feedback samples never enter PublicLog")
	_expect(coordinator.table_presentation_query_ports().recent_viewer_private_feedback(0, 32).size() >= 16, "authorized viewer can recover the sixteen private feedback samples")

	var settlement_receipt := _final_settlement_log_receipt("settlement-ack-1", "victory.v06.ack-1", [0], 40)
	var first_ack := {}
	ports.acknowledge_final_settlement_public_log(settlement_receipt, first_ack)
	_expect(_has_exact_keys(first_ack, FINAL_SETTLEMENT_ACK_KEYS) and TablePresentationPureDataPolicy.is_pure_data(first_ack), "FinalSettlement log acknowledgement is exact-key pure data")
	_expect(bool(first_ack.get("accepted", false)) and not bool(first_ack.get("duplicate", true)) and str(first_ack.get("receipt_id", "")) == settlement_receipt.receipt_id and str(first_ack.get("outcome_id", "")) == "victory.v06.ack-1" and str(first_ack.get("receipt_fingerprint", "")) == settlement_receipt.fingerprint(), "first log acknowledgement binds receipt, outcome, and fingerprint")
	var replay_ack := {}
	ports.acknowledge_final_settlement_public_log(settlement_receipt, replay_ack)
	_expect(bool(replay_ack.get("accepted", false)) and bool(replay_ack.get("duplicate", false)) and str(replay_ack.get("receipt_fingerprint", "")) == settlement_receipt.fingerprint(), "exact replay is accepted only as a fingerprint-bound duplicate")
	var collision_receipt := _final_settlement_log_receipt("settlement-ack-1", "victory.v06.ack-collision", [1], 40)
	var collision_ack := {}
	ports.acknowledge_final_settlement_public_log(collision_receipt, collision_ack)
	_expect(not bool(collision_ack.get("accepted", true)) and not bool(collision_ack.get("duplicate", true)) and str(collision_ack.get("reason_id", "")) == "public_log_receipt_binding_collision", "same receipt ID with a different outcome fingerprint fails as a collision")

	var configured_log_port := ports.public_log_port
	var unavailable_log_port := PublicLogProducerPort.new()
	ports.public_log_port = unavailable_log_port
	var fail_once_receipt := _final_settlement_log_receipt("settlement-fail-once", "victory.v06.fail-once", [0], 41)
	var rejected_ack := {}
	ports.acknowledge_final_settlement_public_log(fail_once_receipt, rejected_ack)
	_expect(not bool(rejected_ack.get("accepted", true)) and str(rejected_ack.get("reason_id", "")) == "public_log_owner_missing", "missing public-log owner fails closed without an acknowledgement success")
	ports.public_log_port = configured_log_port
	var retry_ack := {}
	ports.acknowledge_final_settlement_public_log(fail_once_receipt, retry_ack)
	_expect(bool(retry_ack.get("accepted", false)) and not bool(retry_ack.get("duplicate", true)), "fail-once public-log rejection retries as a first apply")
	unavailable_log_port.free()

	var reused_outcome_receipt := _final_settlement_log_receipt("final-settlement-victory-v06-1", "victory.v06.1", [0], 42)
	var first_session_ack := {}
	ports.acknowledge_final_settlement_public_log(reused_outcome_receipt, first_session_ack)
	_expect(bool(first_session_ack.get("accepted", false)), "first session accepts victory.v06.1")
	ports._on_session_authorization_context_changed("session_began")
	var second_session_ack := {}
	ports.acknowledge_final_settlement_public_log(reused_outcome_receipt, second_session_ack)
	_expect(bool(second_session_ack.get("accepted", false)) and not bool(second_session_ack.get("duplicate", true)), "session reset lets the next session reuse victory.v06.1 as a fresh receipt")

	var victory_receipt := ports.capture_victory_advance({"public_snapshot": {"state": "qualification", "remaining_seconds": 5.0, "victory_rule": {"required_region_count": 2}}})
	_expect(victory_receipt != null and victory_receipt.is_valid(), "victory state change produces a typed public receipt")
	var redacted_victory := ports.capture_victory_advance({"public_snapshot": {"state": "audit", "players": [{"cash": 999}]}})
	_expect(redacted_victory != null and redacted_victory.is_valid() and not redacted_victory.to_dictionary().has("players") and not JSON.stringify(redacted_victory.to_dictionary()).contains("999"), "victory presentation redacts private world payloads")
	var accept_terminal_presentation := [false]
	var terminal_presentation_attempts := [0]
	var terminal_refresh_sequence := [0]
	var terminal_receipt_snapshots: Array = []
	ports.victory_presentation_receipt_ready.connect(func(receipt: VictoryPresentationStateChangeReceipt) -> void:
		terminal_presentation_attempts[0] = int(terminal_presentation_attempts[0]) + 1
		terminal_receipt_snapshots.append(receipt.to_dictionary())
		var receipt_outcome: Dictionary = receipt.public_snapshot.get("outcome_receipt", {}) \
			if receipt.public_snapshot.get("outcome_receipt", {}) is Dictionary else {}
		ports.record_victory_outcome_presentation_result({
			"schema_version": 1,
			"receipt_id": receipt.receipt_id,
			"accepted": bool(accept_terminal_presentation[0]),
			"duplicate": false,
			"reason_id": "" if bool(accept_terminal_presentation[0]) else "fixture_dependency_missing",
			"outcome_id": str(receipt_outcome.get("outcome_id", "")) if bool(accept_terminal_presentation[0]) else "",
		})
		if bool(accept_terminal_presentation[0]):
			for kind in receipt.immediate_refresh_mask:
				terminal_refresh_sequence[0] = int(terminal_refresh_sequence[0]) + 1
				ports.record_victory_outcome_refresh_result(
					receipt,
					_accepted_refresh_apply_receipt(kind, int(terminal_refresh_sequence[0]))
				)
	)
	var terminal_public := _terminal_public_snapshot()
	_expect(ports.capture_victory_outcome(terminal_public) == null and int((ports.debug_snapshot().get("victory_receipts", {}) as Dictionary).get("applied_outcome_count", -1)) == 0, "rejected FinalSettlement acceptance releases the outcome for a normal retry")
	state.set_game_time(175.0)
	accept_terminal_presentation[0] = true
	var accepted_terminal := ports.capture_victory_outcome(terminal_public)
	_expect(accepted_terminal != null and accepted_terminal.is_valid() and int(terminal_presentation_attempts[0]) == 2, "accepted FinalSettlement acknowledgement returns the typed terminal receipt")
	_expect(terminal_receipt_snapshots.size() == 2 and terminal_receipt_snapshots[0] == terminal_receipt_snapshots[1] and int((terminal_receipt_snapshots[0] as Dictionary).get("revision", -1)) == accepted_terminal.revision and is_equal_approx(float((terminal_receipt_snapshots[0] as Dictionary).get("world_time", -1.0)), accepted_terminal.world_time), "rejected outcome retry reuses the exact receipt revision, world time, and fingerprint inputs after world time advances")
	_expect(ports.victory_outcome_refresh_complete(accepted_terminal) and ports.pending_accepted_victory_outcome_refresh_kinds(accepted_terminal).is_empty(), "accepted terminal refresh lineage records every target apply exactly once")
	_expect(ports.capture_victory_outcome(terminal_public) == null and int((ports.debug_snapshot().get("victory_receipts", {}) as Dictionary).get("applied_outcome_count", -1)) == 1, "accepted terminal outcome remains exact-once")

	var producer_checkpoint := ports.public_log_port.capture_session_checkpoint()
	var producer_before_reject := ports.public_log_port.debug_snapshot()
	var producer_unknown_key := producer_checkpoint.duplicate(true)
	producer_unknown_key["unexpected"] = true
	_expect(TablePresentationPureDataPolicy.is_pure_data(producer_checkpoint) and producer_checkpoint.size() == 2 and not ports.public_log_port.restore_session_checkpoint(producer_unknown_key) and ports.public_log_port.debug_snapshot() == producer_before_reject, "PublicLog producer checkpoint is exact-key pure data and rejects unknown keys without mutation")
	var viewer_checkpoint := ports.viewer_private_feedback_owner.capture_session_checkpoint()
	var viewer_before_reject := ports.viewer_private_feedback_owner.debug_snapshot()
	var viewer_messages_before_reject := ports.recent_viewer_private_feedback(0, ViewerPrivateFeedbackOwner.MAX_MESSAGES_PER_VIEWER)
	var viewer_unknown_key := viewer_checkpoint.duplicate(true)
	viewer_unknown_key["unexpected"] = true
	_expect(TablePresentationPureDataPolicy.is_pure_data(viewer_checkpoint) and viewer_checkpoint.size() == 3 and not ports.viewer_private_feedback_owner.restore_session_checkpoint(viewer_unknown_key) and ports.viewer_private_feedback_owner.debug_snapshot() == viewer_before_reject and ports.recent_viewer_private_feedback(0, ViewerPrivateFeedbackOwner.MAX_MESSAGES_PER_VIEWER) == viewer_messages_before_reject, "viewer-private checkpoint is exact-key pure data and rejects unknown keys without mutation")
	var table_ports_source := FileAccess.get_file_as_string("res://scripts/presentation/table_presentation_query_ports.gd")
	_expect(not table_ports_source.contains('.set("_') and not table_ports_source.contains('.get("_'), "TablePresentationQueryPorts never accesses another owner's private transient fields through Object set/get")

	var public_log_before_rollback := ports.public_log_owner.to_save_data()
	var public_log_debug_before_rollback := ports.public_log_owner.debug_snapshot()
	var public_log_port_before_rollback := ports.public_log_port.debug_snapshot()
	var private_feedback_before_rollback := ports.recent_viewer_private_feedback(0, ViewerPrivateFeedbackOwner.MAX_MESSAGES_PER_VIEWER)
	var private_feedback_debug_before_rollback := ports.viewer_private_feedback_owner.debug_snapshot()
	var victory_receipts_before_rollback := ports.victory_receipt_service.debug_snapshot()
	var outcome_result_count_before_rollback := int(ports.debug_snapshot().get("outcome_presentation_result_count", -1))
	ports._on_session_authorization_context_changed("session_plan_applied")
	_expect(ports.public_log_owner.recent_public_entries(90).is_empty() and ports.recent_viewer_private_feedback(0, ViewerPrivateFeedbackOwner.MAX_MESSAGES_PER_VIEWER).is_empty() and int((ports.debug_snapshot().get("victory_receipts", {}) as Dictionary).get("applied_outcome_count", -1)) == 0, "session plan apply presents an empty new-session journal while retaining an in-memory rollback checkpoint")
	ports._on_session_authorization_context_changed("session_checkpoint_rolled_back")
	_expect(ports.public_log_owner.to_save_data() == public_log_before_rollback and ports.public_log_owner.debug_snapshot() == public_log_debug_before_rollback and ports.public_log_port.debug_snapshot() == public_log_port_before_rollback, "session rollback restores public-log rows, bindings, revisions, counters, and producer sequence exactly")
	_expect(ports.recent_viewer_private_feedback(0, ViewerPrivateFeedbackOwner.MAX_MESSAGES_PER_VIEWER) == private_feedback_before_rollback and ports.viewer_private_feedback_owner.debug_snapshot() == private_feedback_debug_before_rollback, "session rollback restores viewer-private feedback and its revision exactly")
	_expect(ports.victory_receipt_service.debug_snapshot() == victory_receipts_before_rollback and int(ports.debug_snapshot().get("outcome_presentation_result_count", -1)) == outcome_result_count_before_rollback, "session rollback restores retained outcome receipts and acknowledgement journal exactly")
	var post_rollback_replay_ack := {}
	ports.acknowledge_final_settlement_public_log(reused_outcome_receipt, post_rollback_replay_ack)
	_expect(bool(post_rollback_replay_ack.get("accepted", false)) and bool(post_rollback_replay_ack.get("duplicate", false)) and str(post_rollback_replay_ack.get("receipt_fingerprint", "")) == reused_outcome_receipt.fingerprint(), "restored public-log exact-once binding accepts the old receipt only as an exact duplicate")

	var public_log_before_failed_load := ports.public_log_owner.to_save_data()
	var public_log_port_before_failed_load := ports.public_log_port.debug_snapshot()
	var private_feedback_before_failed_load := ports.recent_viewer_private_feedback(0, ViewerPrivateFeedbackOwner.MAX_MESSAGES_PER_VIEWER)
	var victory_before_failed_load := ports.victory_receipt_service.debug_snapshot()
	var query_debug_before_failed_load := ports.debug_snapshot()
	ports._on_session_authorization_context_changed("session_save_applied")
	var quarantined_debug := ports.debug_snapshot()
	_expect(ports.public_log_owner.recent_public_entries(90).is_empty() and ports.recent_viewer_private_feedback(0, ViewerPrivateFeedbackOwner.MAX_MESSAGES_PER_VIEWER).is_empty() and int((quarantined_debug.get("victory_receipts", {}) as Dictionary).get("applied_outcome_count", -1)) == 0 and str(quarantined_debug.get("session_lifecycle_checkpoint_kind", "")) == "session_save_applied", "first save-owner apply quarantines predecessor presentation journals during load validation")
	ports._on_session_authorization_context_changed("session_save_applied")
	var restored_after_failed_load := ports.debug_snapshot()
	_expect(ports.public_log_owner.to_save_data() == public_log_before_failed_load and ports.public_log_port.debug_snapshot() == public_log_port_before_failed_load and ports.recent_viewer_private_feedback(0, ViewerPrivateFeedbackOwner.MAX_MESSAGES_PER_VIEWER) == private_feedback_before_failed_load, "reverse-order save rollback restores public and viewer-private journals exactly")
	_expect(ports.victory_receipt_service.debug_snapshot() == victory_before_failed_load and int(restored_after_failed_load.get("outcome_presentation_result_count", -1)) == int(query_debug_before_failed_load.get("outcome_presentation_result_count", -2)) and int(restored_after_failed_load.get("outcome_immediate_refresh_count", -1)) == 1 and ports.victory_outcome_refresh_complete(accepted_terminal), "failed load restores terminal receipt, acknowledgement, and fully applied refresh lineage")

	ports._on_session_authorization_context_changed("session_save_applied")
	ports._on_session_authorization_context_changed("session_load_completed")
	var committed_load_debug := ports.debug_snapshot()
	_expect(ports.public_log_owner.recent_public_entries(90).is_empty() and int(committed_load_debug.get("outcome_presentation_result_count", -1)) == 0 and int(committed_load_debug.get("outcome_immediate_refresh_count", -1)) == 0 and str(committed_load_debug.get("session_lifecycle_checkpoint_kind", "stale")) == "", "successful load commits an empty new-session presentation lineage and retires the rollback checkpoint")
	var loaded_session_terminal := ports.capture_victory_outcome(terminal_public)
	_expect(loaded_session_terminal != null and loaded_session_terminal.is_valid() and int(terminal_presentation_attempts[0]) == 3, "successful load may reuse the predecessor outcome ID as a fresh terminal presentation")
	_expect(ports.victory_outcome_refresh_complete(loaded_session_terminal) and ports.pending_accepted_victory_outcome_refresh_kinds(loaded_session_terminal).is_empty(), "successful load owns an independent exact-once terminal refresh lineage")
	var no_op_lifecycle_before := {
		"public_log": ports.public_log_owner.to_save_data(),
		"producer": ports.public_log_port.debug_snapshot(),
		"private_feedback": ports.recent_viewer_private_feedback(0, ViewerPrivateFeedbackOwner.MAX_MESSAGES_PER_VIEWER),
		"victory": ports.victory_receipt_service.debug_snapshot(),
		"query": ports.debug_snapshot(),
	}
	for non_reset_reason in ["session_paused", "session_resumed", "session_finished"]:
		ports._on_session_authorization_context_changed(non_reset_reason)
	var no_op_lifecycle_after := {
		"public_log": ports.public_log_owner.to_save_data(),
		"producer": ports.public_log_port.debug_snapshot(),
		"private_feedback": ports.recent_viewer_private_feedback(0, ViewerPrivateFeedbackOwner.MAX_MESSAGES_PER_VIEWER),
		"victory": ports.victory_receipt_service.debug_snapshot(),
		"query": ports.debug_snapshot(),
	}
	_expect(no_op_lifecycle_after == no_op_lifecycle_before, "pause, resume, and session-finished lifecycle notices preserve terminal presentation journals exactly")
	var main_scene_source := FileAccess.get_file_as_string("res://scenes/main.tscn")
	_expect(main_scene_source.contains('signal="victory_presentation_result_ready"') and main_scene_source.contains('method="record_victory_outcome_presentation_result"'), "main scene composes the typed FinalSettlement acceptance return path")
	_expect(main_scene_source.contains('signal="public_log_receipt_requested"') and main_scene_source.contains('method="acknowledge_final_settlement_public_log"') and not main_scene_source.contains('method="append_public_log_receipt"]'), "main scene routes FinalSettlement logs only through the synchronous query-port acknowledgement")
	_expect(main_scene_source.count('signal="authorization_context_changed"') >= 2 and main_scene_source.contains('method="_on_session_authorization_context_changed"') and table_ports_source.contains('SESSION_SAVE_APPLIED_REASON_ID := "session_save_applied"') and table_ports_source.contains('SESSION_LOAD_COMPLETED_REASON_ID := "session_load_completed"'), "production session lifecycle transactionally replaces settlement and log acknowledgement state")

	state.replace_players([_fixture_players()[0], {"name": "真人二", "is_ai": false}], true)
	_expect(coordinator.presentation_authorized_viewer_index() == -1, "multiple local humans fail closed until a viewer is explicitly modeled")
	_expect(not coordinator.presentation_can_view_private_subject(0), "ambiguous viewer cannot read private state")
	coordinator.queue_free()
	await process_frame
	_finish()


func _terminal_public_snapshot() -> Dictionary:
	return {
		"controller_id": "victory_control_runtime_v06",
		"ruleset_id": "v0.6",
		"state": "resolved",
		"victory_rule": {"required_region_count": 2, "required_top_k_gdp_per_minute": 72},
		"qualification_remaining_seconds": 0.0,
		"audit_remaining_seconds": 0.0,
		"audit_roster": [0],
		"audit_entries": [],
		"paused": false,
		"pause_reasons": [],
		"settlement_checkpoint": "post_world_settlement",
		"outcome_receipt": {
			"outcome_id": "victory.v06.query-port-fixture",
			"schema_version": "victory_outcome_v1",
			"ruleset_id": "v0.6",
			"reason_code": "public_audit_complete",
			"winner_player_indices": [0],
			"co_victory": false,
			"comparison_order": ["top_k_gdp_per_minute", "controlled_region_count", "cash_ledger_cents"],
			"rankings": [{"player_index": 0, "top_k_gdp_per_minute": 120, "controlled_region_count": 3, "winner": true}],
			"audit_evidence": {"victory_rule": {}, "audit_roster": [0], "settlement_checkpoint": "post_world_settlement"},
			"visibility_scope": "public",
		},
		"visibility_scope": "public",
	}


func _accepted_refresh_apply_receipt(
	kind: StringName,
	sequence: int
) -> TablePresentationApplyReceipt:
	var receipt := TablePresentationApplyReceipt.new()
	receipt.refresh_receipt_id = "terminal-refresh-%s-%d" % [str(kind), sequence]
	receipt.sequence = sequence
	receipt.kind = kind
	receipt.applied = true
	receipt.snapshot_revision = sequence
	receipt.target_revision = sequence
	return receipt


func _final_settlement_log_receipt(
	receipt_id: String,
	outcome_id: String,
	winner_player_indices: Array,
	source_revision: int
) -> PublicLogReceipt:
	return PublicLogReceipt.create(
		receipt_id,
		&"final_settlement",
		&"victory.public.final_settlement",
		{
			"outcome_id": outcome_id,
			"public_status": "settled",
			"reason_code": "public_audit_complete",
			"winner_player_indices": winner_player_indices.duplicate(),
		},
		source_revision,
		185.0
	)


func _fixture_players() -> Array:
	return [
		{"name": "本地玩家", "is_ai": false, "cash": 900, "slots": [{"name": "城市发展", "rank": 1, "hidden_owner": "SECRET"}], "city_guesses": {1: 2}, "ai_plan": "SECRET"},
		{"name": "AI一", "is_ai": true, "cash": 777, "slots": [{"name": "秘密牌"}], "ai_plan": "SECRET"},
		{"name": "AI二", "is_ai": true, "cash": 666, "slots": [{"name": "秘密牌"}], "decision_samples": [1]},
	]


func _fixture_districts() -> Array:
	return [
		{"region_id": "r0", "name": "甲区", "center": Vector2(100, 100), "terrain": "land", "city": {"owner": 0, "active": true, "level": 1, "products": ["crystal"]}},
		{"region_id": "r1", "name": "乙区", "center": Vector2(300, 100), "terrain": "land", "city": {"owner": 1, "active": true, "level": 2, "demands": ["crystal"]}},
	]


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in value.keys():
			var key := str(key_variant).to_lower()
			if FORBIDDEN_KEYS.has(key) or _contains_forbidden_key(value[key_variant]):
				return true
	elif value is Array:
		for child in value:
			if _contains_forbidden_key(child):
				return true
	return false


func _contains_key_recursive(value: Variant, needle: String) -> bool:
	if value is Dictionary:
		for key_variant in value.keys():
			if str(key_variant).to_lower() == needle or _contains_key_recursive(value[key_variant], needle):
				return true
	elif value is Array:
		for child in value:
			if _contains_key_recursive(child, needle):
				return true
	return false


func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(key_variant):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("table_presentation_query_ports_cutover_test: %s %d/%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
	quit(_failures.size())

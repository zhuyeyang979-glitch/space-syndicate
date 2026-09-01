extends Control
class_name VerticalSliceShowcase

## Phase 8 commercial-presentation fixture. This wrapper instances the real
## production main scene and consumes its one V076PresentationAnimationDirector.
## It never creates gameplay, RNG, tick, map, card-zone, facility, victory, or
## settlement authority. The deterministic motion proxy is presentation-only
## evidence and remains visibly labelled as a fixture at every frame.

const PresentationReceiptIdentity := preload(
	"res://scripts/v075/presentation/v075_presentation_receipt_identity_v2.gd"
)

const CANONICAL_SCENE_PATH := (
	"res://scenes/tools/CommercialPresentationShowcase.tscn"
)
const PRODUCTION_MAIN_SCENE_PATH := "res://scenes/main.tscn"
const FIXTURE_CLASS := "PRESENTATION_FIXTURE"
const FIXTURE_BANNER_TEXT := (
	"PRESENTATION_FIXTURE — NOT NATURAL GAMEPLAY / NOT HUMAN GREEN"
)
const FRAME_PHASES := ["start", "mid", "end"]
const FIXTURE_SCHEMA := "V076CommercialPresentationShowcaseFixtureV1"
## There is exactly one Showcase -> production-host boundary.  The host may
## expose several typed presentation surfaces (card-table, settlement, and the
## general Director), but the Showcase never calls those surfaces directly
## from episode orchestration.  All ingress is normalized by this bridge.
const FIXTURE_BRIDGE_SCHEMA := "V076CommercialPresentationFixtureBridgeV1"
const FIXTURE_BRIDGE_METHOD := (
	"VerticalSliceShowcase.submit_presentation_fixture"
)
const FIXTURE_BRIDGE_HOST_ROLE := "PRODUCTION_PRESENTATION_HOST_ONLY"
const CARD_TABLE_FIXTURE_RECEIPT_KIND_BY_CUE := {
	"CARD_SELECT": "card_selection_receipt",
	"CARD_PLAY_PUBLIC": "public_card_play_receipt",
	"CARD_RESOLUTION_FOCUS": "public_resolution_receipt",
	"FINAL_SETTLEMENT": "final_settlement_receipt",
}
const AUTHORITY_OWNER_SCRIPT_CATEGORIES := {
	"res://scripts/v075_runtime/v075_ruleset_runtime_owner.gd": ["gameplay"],
	"res://scripts/v075_runtime/v075_runtime_owner.gd": [
		"gameplay", "rng", "tick", "card_zone", "facility", "settlement",
	],
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd": ["gameplay"],
	"res://scripts/v076/simulation/v076_deterministic_kernel.gd": [
		"gameplay", "rng", "tick",
	],
	"res://scripts/v076/direct_action/v076_private_direct_action_input_owner_v1.gd": [
		"gameplay",
	],
}

const EPISODES := [
	{
		"id": "main_menu",
		"title": "主菜单 / Product Shell",
		"receipt_kind": "product_shell.main_menu.presented",
		"cue_id": "",
		"surface_cue_id": "PRODUCT_SHELL_MAIN_MENU",
		"source_node": "CommercialMenuButton",
		"target_node": "MenuSurfacePanel",
		"source_anchor_path": "V075GameScreen/RootMargin/Shell/Header/HeaderMargin/HeaderRows/HeaderPrimaryRow/CommercialMenuButton",
		"target_anchor_path": "V075GameScreen/OverlayLayer/CommercialShellSurfaceLayer/MenuModalOverlay/MenuSurfacePanel",
		"surface_kind": "menu",
	},
	{
		"id": "loading",
		"title": "New Game Loading",
		"receipt_kind": "product_shell.loading.presented",
		"cue_id": "",
		"surface_cue_id": "PRODUCT_SHELL_LOADING",
		"source_node": "CommercialMenuButton",
		"target_node": "V075NewGameLoadingOverlay",
		"source_anchor_path": "V075GameScreen/RootMargin/Shell/Header/HeaderMargin/HeaderRows/HeaderPrimaryRow/CommercialMenuButton",
		"target_anchor_path": "V075NewGameLoadingOverlay",
		"surface_kind": "loading",
	},
	{
		"id": "acquire_to_deck",
		"title": "买牌进入牌库",
		"receipt_kind": "card.enter_deck",
		"cue_id": "CARD_ENTER_DECK",
		"source_node": "TrackPanel",
		"target_node": "DrawPilePanel",
		"source_anchor_path": "V075GameScreen/RootMargin/Shell/TrackPanel",
		"target_anchor_path": "V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockHeader/V076DeckLifecyclePresentation/DeckHudRow/DrawPilePanel",
		"surface_kind": "motion",
	},
	{
		"id": "shuffle",
		"title": "牌库洗牌",
		"receipt_kind": "deck.shuffle",
		"cue_id": "DECK_SHUFFLE",
		"source_node": "DiscardPilePanel",
		"target_node": "DrawPilePanel",
		"source_anchor_path": "V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockHeader/V076DeckLifecyclePresentation/DeckHudRow/DiscardPilePanel",
		"target_anchor_path": "V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockHeader/V076DeckLifecyclePresentation/DeckHudRow/DrawPilePanel",
		"surface_kind": "motion",
	},
	{
		"id": "draw",
		"title": "抽牌进入手牌",
		"receipt_kind": "card.draw",
		"cue_id": "CARD_DRAW",
		"source_node": "DrawPilePanel",
		"target_node": "HandScroll",
		"source_anchor_path": "V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockHeader/V076DeckLifecyclePresentation/DeckHudRow/DrawPilePanel",
		"target_anchor_path": "V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/HandScroll",
		"surface_kind": "motion",
	},
	{
		"id": "hand_hover",
		"title": "手牌 Hover",
		"receipt_kind": "card.select",
		"cue_id": "CARD_SELECT",
		"source_node": "HandScroll",
		"target_node": "HandScroll",
		"source_anchor_path": "V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/HandScroll",
		"target_anchor_path": "V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/HandScroll",
		"surface_kind": "motion",
	},
	{
		"id": "public_play",
		"title": "公共牌出牌",
		"receipt_kind": "card.play.public",
		"cue_id": "CARD_PLAY_PUBLIC",
		"source_node": "HandScroll",
		"target_node": "CentralPublicActionArrangement",
		"source_anchor_path": "V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/HandScroll",
		"target_anchor_path": "V075GameScreen/RootMargin/Shell/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport/CentralPublicActionArrangement",
		"surface_kind": "motion",
	},
	{
		"id": "public_resolution",
		"title": "公开逐张结算",
		"receipt_kind": "card.resolution.focus",
		"cue_id": "CARD_RESOLUTION_FOCUS",
		"source_node": "CentralPublicActionArrangement",
		"target_node": "CurrentActionBanner",
		"source_anchor_path": "V075GameScreen/RootMargin/Shell/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport/CentralPublicActionArrangement",
		"target_anchor_path": "V075GameScreen/RootMargin/Shell/TableArea/V075RightSidebar/PublicActionFeedPanel/FeedMargin/FeedRows/CurrentActionBanner",
		"surface_kind": "motion",
	},
	{
		"id": "facility",
		"title": "设施建造",
		"receipt_kind": "facility.build",
		"cue_id": "FACILITY_BUILD",
		"source_node": "DockPanel",
		"target_node": "PlanetStageViewport",
		"source_anchor_path": "V075GameScreen/RootMargin/Shell/DockPanel",
		"target_anchor_path": "V075GameScreen/RootMargin/Shell/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport",
		"surface_kind": "motion",
	},
	{
		"id": "monster",
		"title": "怪兽攻击",
		"receipt_kind": "monster.melee",
		"cue_id": "MONSTER_MELEE",
		"source_node": "PublicMonsterPanel",
		"target_node": "PlanetStageViewport",
		"source_anchor_path": "V075GameScreen/RootMargin/Shell/TableArea/V075RightSidebar/V075CombatStackHost/V075CombatOverlay/Margin/Rows/SurfaceHost/CombatSurface/Rows/PublicMonsterPanel",
		"target_anchor_path": "V075GameScreen/RootMargin/Shell/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport",
		"surface_kind": "motion",
	},
	{
		"id": "military",
		"title": "军队攻击",
		"receipt_kind": "military.assault_region",
		"cue_id": "MILITARY_ASSAULT_REGION",
		"source_node": "MilitaryPanel",
		"target_node": "PlanetStageViewport",
		"source_anchor_path": "V075GameScreen/RootMargin/Shell/TableArea/V075RightSidebar/V075CombatStackHost/V075CombatOverlay/Margin/Rows/SurfaceHost/CombatSurface/Rows/PrivateGrid/MilitaryPanel",
		"target_anchor_path": "V075GameScreen/RootMargin/Shell/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport",
		"surface_kind": "motion",
	},
	{
		"id": "track_handoff",
		"title": "寿司轨交接",
		"receipt_kind": "track.handoff",
		"cue_id": "TRACK_HANDOFF",
		"source_node": "TrackPanel",
		"target_node": "HandScroll",
		"source_anchor_path": "V075GameScreen/RootMargin/Shell/TrackPanel",
		"target_anchor_path": "V075GameScreen/RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/HandScroll",
		"surface_kind": "motion",
	},
	{
		"id": "final_settlement",
		"title": "FinalSettlement",
		"receipt_kind": "final.settlement",
		"cue_id": "FINAL_SETTLEMENT",
		"source_node": "CentralPublicActionArrangement",
		"target_node": "SettlementOverlay",
		"source_anchor_path": "V075GameScreen/RootMargin/Shell/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport/CentralPublicActionArrangement",
		"target_anchor_path": "V075GameScreen/OverlayLayer/SettlementOverlay",
		"surface_kind": "settlement",
	},
]

@export var reduced_motion := false

@onready var _production_main: Control = %ProductionMain
@onready var _fixture_banner: Label = %FixtureBanner
@onready var _episode_label: Label = %EpisodeLabel
@onready var _fixture_proxy: PanelContainer = %FixtureMotionProxy
@onready var _fixture_proxy_label: Label = %FixtureMotionProxyLabel

var _game_screen: Control
var _runtime_composition: Node
var _menu_lifecycle: Node
var _loading_overlay: Control
var _director: Node
var _menu_overlay: Control
var _start_overlay: Control
var _settlement_overlay: Control

var _active_episode: Dictionary = {}
var _active_receipt: Dictionary = {}
var _active_projection: Dictionary = {}
var _active_cue: Dictionary = {}
var _active_phase := "start"
var _active_progress := 0.0
var _source_rect := Rect2()
var _target_rect := Rect2()
var _start_proxy_rect := Rect2()
var _authority_hash_before := ""
var _enqueue_count := 0
var _finish_count := 0
var _local_duplicate_suppressed_count := 0
var _local_receipt_ledger: Dictionary = {}
var _last_replay_result: Dictionary = {}
var _last_surface_phase := ""
var _anchor_resolution_valid := false
var _source_anchor_resolved_path := ""
var _target_anchor_resolved_path := ""
var _source_anchor_resolution_count := 0
var _target_anchor_resolution_count := 0
var _prepare_rejection_reason := ""
var _active_fixture_source_id := ""
var _fixture_bridge_submit_count := 0
var _fixture_bridge_replay_count := 0
var _fixture_bridge_finish_count := 0
var _fixture_bridge_rejection_count := 0
var _fixture_bridge_duplicate_suppressed_count := 0
var _fixture_bridge_route_counts: Dictionary = {}
var _fixture_bridge_last_route := ""
var _fixture_bridge_last_result: Dictionary = {}
var _fixture_bridge_lifecycle_before: Dictionary = {}
var _fixture_bridge_lifecycle_after: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resolve_production_nodes()
	_fixture_banner.text = FIXTURE_BANNER_TEXT
	_fixture_banner.visible = true
	_fixture_proxy.visible = false
	_apply_production_presentation_policy()
	_fixture_bridge_lifecycle_before = _host_lifecycle_snapshot()
	_fixture_bridge_lifecycle_after = _fixture_bridge_lifecycle_before.duplicate(true)


func _resolve_production_nodes() -> void:
	if _production_main == null:
		return
	_game_screen = _production_main.get_node_or_null("V075GameScreen") as Control
	_runtime_composition = _production_main.get_node_or_null(
		"V075RuntimeComposition"
	)
	_menu_lifecycle = _production_main.get_node_or_null(
		"CommercialMenuLifecycleApplicationFlowController"
	)
	_loading_overlay = _production_main.get_node_or_null(
		"V075NewGameLoadingOverlay"
	) as Control
	if _game_screen != null:
		_director = _production_main.get_node_or_null(
			"V075GameScreen/V076PresentationAnimationDirector"
		)
		_menu_overlay = _production_main.get_node_or_null(
			"V075GameScreen/OverlayLayer/CommercialShellSurfaceLayer/MenuModalOverlay"
		) as Control
		_start_overlay = _production_main.get_node_or_null(
			"V075GameScreen/OverlayLayer/StartOverlay"
		) as Control
		_settlement_overlay = _production_main.get_node_or_null(
			"V075GameScreen/OverlayLayer/SettlementOverlay"
		) as Control


func _apply_production_presentation_policy() -> void:
	if _game_screen == null or not _game_screen.has_method(
		"apply_presentation_settings"
	):
		return
	_game_screen.call("apply_presentation_settings", {
		"master_volume": 0.0,
		"music_volume": 0.0,
		"sfx_volume": 0.0,
		"reduced_motion": reduced_motion,
		"screen_shake": not reduced_motion,
		"text_scale": 1.0,
		"color_assist_mode": "default",
	})


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	_apply_production_presentation_policy()


func prepare_episode(episode_id: String) -> bool:
	var episode := _episode_for_id(episode_id)
	if episode.is_empty() or _director == null:
		return false
	if not _active_receipt.is_empty() and _finish_count == 0:
		finish_episode()
	_reset_surface_state()
	_active_episode = episode.duplicate(true)
	_active_phase = "start"
	_active_progress = 0.0
	_enqueue_count = 0
	_finish_count = 0
	_active_receipt = {}
	_active_projection = {}
	_active_cue = {}
	_last_replay_result = {}
	_last_surface_phase = ""
	_prepare_rejection_reason = ""
	_active_fixture_source_id = ""
	var source_resolution := _resolve_unique_anchor_control(
		str(episode.get("source_anchor_path", "")),
		str(episode.get("source_node", ""))
	)
	var target_resolution := _resolve_unique_anchor_control(
		str(episode.get("target_anchor_path", "")),
		str(episode.get("target_node", ""))
	)
	_source_anchor_resolved_path = str(source_resolution.get("resolved_path", ""))
	_target_anchor_resolved_path = str(target_resolution.get("resolved_path", ""))
	_source_anchor_resolution_count = int(source_resolution.get("name_count", 0))
	_target_anchor_resolution_count = int(target_resolution.get("name_count", 0))
	_anchor_resolution_valid = (
		bool(source_resolution.get("valid", false))
		and bool(target_resolution.get("valid", false))
	)
	if not _anchor_resolution_valid:
		_prepare_rejection_reason = "showcase_anchor_resolution_invalid"
		return false
	_source_rect = source_resolution.get("rect", Rect2()) as Rect2
	_target_rect = target_resolution.get("rect", Rect2()) as Rect2
	_source_rect = _proxy_rect_for_anchor(_source_rect)
	_target_rect = _proxy_rect_for_anchor(_target_rect)
	if _rects_equal(_source_rect, _target_rect):
		_source_rect.position += Vector2(0.0, 38.0)
	_active_receipt = _fixture_receipt(episode)
	_active_projection = _fixture_projection(episode)
	_active_fixture_source_id = str(_active_receipt.get("receipt_id", ""))
	var authority_guard := _authority_guard_snapshot()
	if not bool(authority_guard.get("valid", false)):
		_prepare_rejection_reason = "showcase_authority_guard_invalid"
		return false
	_authority_hash_before = str(authority_guard.get("snapshot_sha256", ""))
	var bridge_result := submit_presentation_fixture(
		_active_receipt,
		_active_projection,
		episode_id
	)
	if not bool(bridge_result.get("accepted", false)):
		_prepare_rejection_reason = str(bridge_result.get(
			"reason_code",
			"showcase_fixture_bridge_rejected"
		))
		return false
	_active_cue = (bridge_result.get("queued_cue", {}) as Dictionary).duplicate(true)
	_enqueue_count = 1
	_apply_surface_episode_once("start")
	_apply_proxy_progress(0.0)
	_start_proxy_rect = Rect2()
	_update_episode_label()
	return true


func set_episode_frame(episode_id: String, phase: String) -> bool:
	if str(_active_episode.get("id", "")) != episode_id:
		if not prepare_episode(episode_id):
			return false
	if not FRAME_PHASES.has(phase):
		return false
	_active_phase = phase
	match phase:
		"start":
			_active_progress = 0.0
		"mid":
			_active_progress = 0.5
		"end":
			_active_progress = 1.0
	_apply_surface_episode_once(phase)
	_apply_proxy_progress(_active_progress)
	_update_episode_label()
	return true


func finish_episode() -> bool:
	if _active_receipt.is_empty() or _finish_count > 0:
		return false
	var finish_result := finish_presentation_fixture(
		str(_active_receipt.get("receipt_id", ""))
	)
	var finished := bool(finish_result.get("accepted", false))
	if finished:
		_finish_count = 1
	return finished


func replay_active_receipt() -> Dictionary:
	if _active_receipt.is_empty():
		return {"suppressed": false, "reason_code": "no_active_receipt"}
	_last_replay_result = replay_presentation_fixture(
		_active_receipt,
		_active_projection,
		str(_active_episode.get("id", ""))
	)
	return _last_replay_result.duplicate(true)


## The one canonical Showcase ingress.  Callers cannot select a production
## route: the sealed episode identity determines the fixture-only adapter.
func submit_presentation_fixture(
	receipt: Dictionary,
	projection: Dictionary,
	episode_id: String
) -> Dictionary:
	var validation := _validate_fixture_submission(
		receipt,
		projection,
		episode_id
	)
	if not bool(validation.get("valid", false)):
		return _fixture_bridge_rejection(str(validation.get(
			"reason_code",
			"showcase_fixture_bridge_contract_invalid"
		)))
	var episode := validation.get("episode", {}) as Dictionary
	var route := _fixture_route_for_episode(episode)
	if route.is_empty():
		return _fixture_bridge_rejection(
			"showcase_fixture_bridge_route_unavailable"
		)
	_fixture_bridge_submit_count += 1
	_fixture_bridge_last_route = route
	_bump_fixture_bridge_route(route, "submit_count")
	var result: Dictionary = {}
	match route:
		"PRODUCT_SHELL_FIXTURE":
			_active_cue = _surface_transition_cue(episode)
			_register_local_fixture_receipt(receipt)
			result = {
				"accepted": true,
				"reason_code": "showcase_fixture_surface_registered",
				"queued_cue": _active_cue.duplicate(true),
			}
		"CARD_TABLE_FIXTURE":
			if _enqueue_card_table_fixture_episode(episode):
				result = {
					"accepted": true,
					"reason_code": "showcase_card_table_fixture_registered",
					"queued_cue": _active_cue.duplicate(true),
				}
			else:
				result = {
					"accepted": false,
					"reason_code": _prepare_rejection_reason,
				}
		"GENERIC_DIRECTOR_FIXTURE":
			result = _submit_generic_fixture_host(receipt, projection)
	_fixture_bridge_lifecycle_after = _host_lifecycle_snapshot()
	return _fixture_bridge_result(route, result)


func replay_presentation_fixture(
	receipt: Dictionary,
	projection: Dictionary,
	episode_id: String
) -> Dictionary:
	if episode_id != str(_active_episode.get("id", "")):
		return _fixture_bridge_rejection(
			"showcase_fixture_bridge_replay_episode_mismatch"
		)
	if not _active_fixture_envelope_valid(receipt, projection):
		return _fixture_bridge_rejection(
			"showcase_fixture_bridge_replay_contract_invalid"
		)
	var route := _fixture_route_for_episode(_active_episode)
	_fixture_bridge_replay_count += 1
	_fixture_bridge_last_route = route
	_bump_fixture_bridge_route(route, "replay_count")
	var result: Dictionary = {}
	if route == "PRODUCT_SHELL_FIXTURE":
		var receipt_id := str(receipt.get("receipt_id", ""))
		var suppressed := _local_receipt_ledger.has(receipt_id)
		if suppressed:
			_local_duplicate_suppressed_count += 1
		result = {
			"accepted": false,
			"suppressed": suppressed,
			"duplicate": suppressed,
			"reason_code": (
				"fixture_surface_receipt_duplicate_suppressed"
				if suppressed
				else "fixture_surface_receipt_missing"
			),
			"queued_count_before": _enqueue_count,
			"queued_count_after": _enqueue_count,
		}
	elif route == "CARD_TABLE_FIXTURE":
		var before := _screen_card_table_debug()
		var duplicate := _game_screen.call(
			"enqueue_card_table_presentation",
			receipt.duplicate(true),
			projection.duplicate(true),
			FIXTURE_CLASS
		) as Dictionary
		var after := _screen_card_table_debug()
		result = {
			"accepted": bool(duplicate.get("accepted", false)),
			"suppressed": (
				not bool(duplicate.get("accepted", false))
				and bool(duplicate.get("duplicate", false))
			),
			"duplicate": bool(duplicate.get("duplicate", false)),
			"reason_code": str(duplicate.get("reason_code", "")),
			"queued_count_before": int(before.get("queued_count", -1)),
			"queued_count_after": int(after.get("queued_count", -1)),
			"duplicate_count_before": int(before.get("duplicate_count", -1)),
			"duplicate_count_after": int(after.get("duplicate_count", -1)),
		}
	else:
		var before := _director_debug()
		var duplicate_result := _submit_generic_fixture_host(receipt, projection)
		var after := _director_debug()
		result = {
			"accepted": bool(duplicate_result.get("accepted", false)),
			"suppressed": (
				not bool(duplicate_result.get("accepted", false))
				and bool(duplicate_result.get("duplicate", false))
			),
			"duplicate": bool(duplicate_result.get("duplicate", false)),
			"reason_code": str(duplicate_result.get(
				"reason_code",
				after.get("last_rejection_reason", "")
			)),
			"queued_count_before": int(before.get("queued_cue_count", -1)),
			"queued_count_after": int(after.get("queued_cue_count", -1)),
			"duplicate_count_before": int(before.get("receipt_duplicate_count", -1)),
			"duplicate_count_after": int(after.get("receipt_duplicate_count", -1)),
		}
	if bool(result.get("suppressed", false)):
		_fixture_bridge_duplicate_suppressed_count += 1
		_bump_fixture_bridge_route(route, "duplicate_suppressed_count")
	_fixture_bridge_lifecycle_after = _host_lifecycle_snapshot()
	return _fixture_bridge_result(route, result)


func finish_presentation_fixture(receipt_id: String) -> Dictionary:
	var normalized := receipt_id.strip_edges()
	if (
		normalized.is_empty()
		or normalized != str(_active_receipt.get("receipt_id", ""))
	):
		return _fixture_bridge_rejection(
			"showcase_fixture_bridge_finish_identity_mismatch"
		)
	var route := _fixture_route_for_episode(_active_episode)
	var cue_id := str(_active_episode.get("cue_id", ""))
	var finished := false
	if route == "PRODUCT_SHELL_FIXTURE":
		finished = true
		if (
			str(_active_episode.get("surface_kind", "")) == "loading"
			and _loading_overlay != null
			and _loading_overlay.has_method("is_presentation_fixture_loading")
			and bool(_loading_overlay.call("is_presentation_fixture_loading"))
			and _loading_overlay.has_method("end_presentation_fixture")
		):
			finished = bool(_loading_overlay.call("end_presentation_fixture"))
	elif route == "CARD_TABLE_FIXTURE":
		finished = _finish_card_table_fixture_episode(cue_id)
	elif route == "GENERIC_DIRECTOR_FIXTURE":
		finished = (
			_game_screen != null
			and _game_screen.has_method(
				"finish_commercial_showcase_presentation_fixture"
			)
			and bool(_game_screen.call(
				"finish_commercial_showcase_presentation_fixture",
				normalized
			))
		)
	var result := {
		"accepted": finished,
		"reason_code": (
			"showcase_fixture_bridge_finished"
			if finished
			else "showcase_fixture_bridge_finish_rejected"
		),
	}
	if finished:
		_fixture_bridge_finish_count += 1
		_bump_fixture_bridge_route(route, "finish_count")
	else:
		_fixture_bridge_rejection_count += 1
		_bump_fixture_bridge_route(route, "rejection_count")
	_fixture_bridge_last_route = route
	_fixture_bridge_lifecycle_after = _host_lifecycle_snapshot()
	return _fixture_bridge_result(route, result)


func get_episode_evidence() -> Dictionary:
	var director_debug := _director_debug()
	var current_rect := _current_proxy_rect()
	# Container minimum-size resolution settles on the following frame. Record
	# the visible start Rect when evidence is sampled, not before layout has run.
	if _active_phase == "start":
		_start_proxy_rect = current_rect
	elif not _start_proxy_rect.has_area():
		_start_proxy_rect = _source_rect
	var authority_guard_after := _authority_guard_snapshot()
	var authority_hash_after := str(authority_guard_after.get(
		"snapshot_sha256", ""
	))
	var result := {
		"schema": "V076CommercialPresentationEpisodeEvidenceV1",
		"episode_id": str(_active_episode.get("id", "")),
		"title": str(_active_episode.get("title", "")),
		"frame_phase": _active_phase,
		"frame_progress": _active_progress,
		"fixture_class": FIXTURE_CLASS,
		"natural_gameplay": false,
		"gameplay_green": false,
		"human_green": false,
		"production_green": false,
		"human_retest_deferred": true,
		"step13_status": "PENDING",
		"canonical_scene_path": CANONICAL_SCENE_PATH,
		"production_main_scene_path": PRODUCTION_MAIN_SCENE_PATH,
		"production_main_instance_count": _node_name_count("ProductionMain"),
		"presentation_director_instance_count": _node_name_count(
			"V076PresentationAnimationDirector"
		),
		"uses_production_director": (
			_director != null
			and _game_screen != null
			and _game_screen.is_ancestor_of(_director)
		),
		"receipt": _active_receipt.duplicate(true),
		"animation_cue": _active_cue.duplicate(true),
		"projection": _active_projection.duplicate(true),
		"fixture_bridge": _fixture_bridge_debug_snapshot(),
		"card_table_fixture_bridge_applicable": _is_card_table_fixture_cue(
			str(_active_episode.get("cue_id", ""))
		),
		"card_table_fixture_bridge": _screen_card_table_debug(),
		"anchor_resolution_valid": _anchor_resolution_valid,
		"source_anchor_resolved_path": _source_anchor_resolved_path,
		"target_anchor_resolved_path": _target_anchor_resolved_path,
		"source_anchor_resolution_count": _source_anchor_resolution_count,
		"target_anchor_resolution_count": _target_anchor_resolution_count,
		"anchor_fallback_count": 0,
		"prepare_rejection_reason": _prepare_rejection_reason,
		"source_rect": _rect_data(_source_rect),
		"target_rect": _rect_data(_target_rect),
		"start_rect": _rect_data(_start_proxy_rect),
		"current_rect": _rect_data(current_rect),
		"rect_changed_from_start": not _rects_equal(
			_start_proxy_rect, current_rect
		),
		"final_rect_matches_target": (
			_rects_equal(current_rect, _target_rect)
			if _active_phase == "end"
			else false
		),
		"authority_boundary_hash_before": _authority_hash_before,
		"authority_boundary_hash_after": authority_hash_after,
		"authority_guard": authority_guard_after.duplicate(true),
		"authority_projection_consistent": (
			_authority_hash_before != ""
			and bool(authority_guard_after.get("valid", false))
			and _authority_hash_before == authority_hash_after
		),
		"enqueue_count": _enqueue_count,
		"finish_count": _finish_count,
		"last_replay_result": _last_replay_result.duplicate(true),
		"performance": director_debug.get("performance", {}),
		"animation_gameplay_mutation_count": int(director_debug.get(
			"animation_gameplay_mutation_count", -1
		)),
		"animation_rng_draw_delta": int(director_debug.get(
			"animation_rng_draw_delta", -1
		)),
		"animation_authority_sequence_delta": int(director_debug.get(
			"animation_authority_sequence_delta", -1
		)),
		"animation_deck_order_mutation_count": int(director_debug.get(
			"animation_deck_order_mutation_count", -1
		)),
		"animation_card_zone_mutation_count": int(director_debug.get(
			"animation_card_zone_mutation_count", -1
		)),
		"animation_facility_state_mutation_count": int(director_debug.get(
			"animation_facility_state_mutation_count", -1
		)),
		"surface_state": _surface_state_snapshot(),
	}
	result["evidence_hash_sha256"] = (
		PresentationReceiptIdentity.canonical_sha256(result)
	)
	return result


func get_showcase_contract() -> Dictionary:
	var episode_ids: Array[String] = []
	for episode_variant in EPISODES:
		var episode := episode_variant as Dictionary
		episode_ids.append(str(episode.get("id", "")))
	var showcase_owner_audit := _authority_owner_audit(self, _production_main)
	var production_owner_audit := _authority_owner_audit(_production_main, null)
	return {
		"schema": FIXTURE_SCHEMA,
		"canonical_scene_path": CANONICAL_SCENE_PATH,
		"production_main_scene_path": PRODUCTION_MAIN_SCENE_PATH,
		"fixture_class": FIXTURE_CLASS,
		"fixture_banner_text": FIXTURE_BANNER_TEXT,
		"fixture_banner_visible": _fixture_banner != null and _fixture_banner.visible,
		"natural_gameplay": false,
		"gameplay_green": false,
		"human_green": false,
		"production_green": false,
		"human_retest_deferred": true,
		"step13_status": "PENDING",
		"episode_ids": episode_ids,
		"episode_count": episode_ids.size(),
		"frame_phases": FRAME_PHASES.duplicate(),
		"frame_count": episode_ids.size() * FRAME_PHASES.size(),
		"presentation_director_instance_count": _node_name_count(
			"V076PresentationAnimationDirector"
		),
		"production_gameplay_owner_count": int(production_owner_audit.get(
			"gameplay", 0
		)),
		"production_authority_owner_audit": production_owner_audit,
		"showcase_gameplay_owner_count": int(showcase_owner_audit.get(
			"gameplay", 0
		)),
		"showcase_rng_owner_count": int(showcase_owner_audit.get("rng", 0)),
		"showcase_tick_owner_count": int(showcase_owner_audit.get("tick", 0)),
		"showcase_card_zone_owner_count": int(showcase_owner_audit.get(
			"card_zone", 0
		)),
		"showcase_facility_owner_count": int(showcase_owner_audit.get(
			"facility", 0
		)),
		"showcase_settlement_owner_count": int(showcase_owner_audit.get(
			"settlement", 0
		)),
		"showcase_authority_owner_audit": showcase_owner_audit,
		"uses_production_main": _production_main != null,
		"uses_production_director": _director != null,
		"production_main_role": FIXTURE_BRIDGE_HOST_ROLE,
		"fixture_bridge_instance_count": 1,
		"fixture_bridge_schema": FIXTURE_BRIDGE_SCHEMA,
		"fixture_bridge_method": FIXTURE_BRIDGE_METHOD,
		"fixture_bridge": _fixture_bridge_debug_snapshot(),
		"card_table_fixture_cue_ids": (
			CARD_TABLE_FIXTURE_RECEIPT_KIND_BY_CUE.keys()
		),
		"fixture_host_adapter_methods": [
			"V075GameScreen.enqueue_card_table_presentation",
			"V075GameScreen.enqueue_commercial_showcase_presentation_fixture",
			"V075GameScreen.present_final_settlement_fixture",
		],
		"reduced_motion": reduced_motion,
	}


func performance_snapshot() -> Dictionary:
	return (_director_debug().get("performance", {}) as Dictionary).duplicate(true)


func animation_debug_snapshot() -> Dictionary:
	return _director_debug()


func play_stage(stage_id: String) -> void:
	## Historical compatibility now routes to the canonical fixture rather than
	## creating a second table or Director.
	var mapping := {
		"board_idle": "main_menu",
		"card_hover": "hand_hover",
		"card_drag_valid": "public_play",
		"card_drag_invalid": "public_resolution",
		"card_play_frame_00": "public_play",
		"card_play_frame_08": "public_play",
		"card_play_frame_16": "public_resolution",
		"monster_spawn": "monster",
		"monster_move": "monster",
		"monster_attack_frame_00": "monster",
		"monster_attack_frame_12": "monster",
		"monster_attack_frame_24": "monster",
		"public_track_reveal": "track_handoff",
		"bid_highlight": "public_resolution",
		"balance_report_preview": "final_settlement",
	}
	var episode_id := str(mapping.get(stage_id, stage_id))
	var phase := "mid"
	if stage_id.ends_with("_00"):
		phase = "start"
	elif stage_id.ends_with("_16") or stage_id.ends_with("_24"):
		phase = "end"
	set_episode_frame(episode_id, phase)


func set_showcase_time(seconds: float) -> void:
	var index := clampi(int(seconds / 3.0), 0, EPISODES.size() - 1)
	var episode := EPISODES[index] as Dictionary
	set_episode_frame(str(episode.get("id", "main_menu")), "mid")


func play_scenario(scenario_id: String) -> void:
	var mapping := {
		"first_table": "main_menu",
		"monster_pressure": "monster",
		"public_track_intro": "track_handoff",
		"bid_practice": "public_resolution",
	}
	set_episode_frame(str(mapping.get(scenario_id, "main_menu")), "mid")


func get_scenario_contract(scenario_id: String) -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"presentation_fixture": true,
		"natural_gameplay": false,
		"human_green": false,
	}


func play_scenario_payload(payload: Dictionary) -> void:
	set_episode_frame(str(payload.get("episode_id", "main_menu")), "mid")


func clear_audio_events() -> void:
	## Audio remains owned by the production host. The Showcase never creates a
	## parallel event bus.
	pass


func get_audio_event_snapshot() -> Dictionary:
	var host := (
		_game_screen.find_child("CommercialAudioPresentationHost", true, false)
		if _game_screen != null
		else null
	)
	if host != null and host.has_method("debug_snapshot"):
		return host.call("debug_snapshot") as Dictionary
	return {}


func _apply_surface_episode(phase: String) -> void:
	var surface_kind := str(_active_episode.get("surface_kind", "motion"))
	match surface_kind:
		"menu":
			if _start_overlay != null:
				_start_overlay.visible = true
			# Production main has already opened and populated its root shell on
			# startup. The fixture only samples/modulates that surface; calling
			# MenuLifecycle.open_root_menu again would submit a pacing intent.
			if _menu_overlay != null:
				_menu_overlay.visible = true
				_menu_overlay.modulate.a = _phase_alpha(phase)
		"loading":
			if _start_overlay != null:
				_start_overlay.visible = false
			if _menu_overlay != null:
				_menu_overlay.visible = false
			if _loading_overlay != null:
				if phase == "start" and _loading_overlay.has_method(
					"begin_presentation_fixture"
				):
					_loading_overlay.call(
						"begin_presentation_fixture",
						"commercial-m1-presentation-fixture"
					)
				elif phase == "mid" and _loading_overlay.has_method(
					"advance_presentation_fixture"
				):
					_loading_overlay.call(
						"advance_presentation_fixture",
						"authority_initialization"
					)
				elif phase == "end" and _loading_overlay.has_method(
					"advance_presentation_fixture"
				):
					_loading_overlay.call(
						"advance_presentation_fixture", "projection_received"
					)
				_loading_overlay.visible = true
		"settlement":
			if _start_overlay != null:
				_start_overlay.visible = false
			if _menu_overlay != null:
				_menu_overlay.visible = false
			# The dedicated fixture surface was started while the episode was
			# prepared. Never call the production FinalSettlement entry point here.
			if _settlement_overlay != null:
				_settlement_overlay.visible = true
				_settlement_overlay.modulate.a = _phase_alpha(phase)
		_:
			if _start_overlay != null:
				_start_overlay.visible = false
			if _menu_overlay != null:
				_menu_overlay.visible = false


func _apply_surface_episode_once(phase: String) -> void:
	if _last_surface_phase == phase:
		return
	_apply_surface_episode(phase)
	_last_surface_phase = phase


func _reset_surface_state() -> void:
	if _menu_overlay != null:
		_menu_overlay.modulate = Color.WHITE
		_menu_overlay.visible = false
	if _loading_overlay != null:
		if (
			_loading_overlay.has_method("is_presentation_fixture_loading")
			and bool(_loading_overlay.call("is_presentation_fixture_loading"))
			and _loading_overlay.has_method("end_presentation_fixture")
		):
			_loading_overlay.call("end_presentation_fixture")
		_loading_overlay.visible = false
	if _settlement_overlay != null:
		_settlement_overlay.modulate = Color.WHITE
		_settlement_overlay.visible = false
	_fixture_proxy.visible = false


func _apply_proxy_progress(progress: float) -> void:
	var current := Rect2(
		_source_rect.position.lerp(_target_rect.position, progress),
		_source_rect.size.lerp(_target_rect.size, progress)
	)
	_fixture_proxy.position = current.position
	_fixture_proxy.size = current.size
	_fixture_proxy.pivot_offset = current.size * 0.5
	_fixture_proxy.rotation = lerpf(-0.035, 0.0, progress)
	_fixture_proxy.scale = Vector2.ONE * (
		1.08 if is_equal_approx(progress, 0.5) and not reduced_motion else 1.0
	)
	_fixture_proxy.modulate.a = 0.58 if is_equal_approx(progress, 0.0) else 0.94
	_fixture_proxy.visible = true
	_fixture_proxy_label.text = "%s\n%s · %s" % [
		str(_active_episode.get("title", "")),
		str(_active_cue.get("cue_id", _active_episode.get(
			"surface_cue_id", "PRESENTATION"
		))),
		_active_phase.to_upper(),
	]


func _update_episode_label() -> void:
	_episode_label.text = "PHASE 8 · %s · %s" % [
		str(_active_episode.get("id", "")),
		_active_phase.to_upper(),
	]


func _validate_fixture_submission(
	receipt: Dictionary,
	projection: Dictionary,
	episode_id: String
) -> Dictionary:
	var normalized_id := episode_id.strip_edges()
	var episode := _episode_for_id(normalized_id)
	if episode.is_empty():
		return {
			"valid": false,
			"reason_code": "showcase_fixture_bridge_episode_unknown",
		}
	var expected_receipt := _fixture_receipt(episode)
	var expected_projection := _fixture_projection(episode)
	if (
		str(receipt.get("fixture_class", "")) != FIXTURE_CLASS
		or str(receipt.get("receipt_source_class", "")) != FIXTURE_CLASS
		or bool(receipt.get("natural_gameplay", true))
		or bool(receipt.get("authority_receipt", true))
		or not bool(receipt.get("fixture_sealed", false))
		or bool(receipt.get("gameplay_green", true))
		or bool(receipt.get("production_green", true))
		or bool(receipt.get("human_green", true))
		or str(receipt.get("fixture_source", "")) != CANONICAL_SCENE_PATH
		or str(projection.get("fixture_class", "")) != FIXTURE_CLASS
		or bool(projection.get("natural_gameplay", true))
		or bool(projection.get("production_green", true))
		or bool(projection.get("human_green", true))
	):
		return {
			"valid": false,
			"reason_code": "showcase_fixture_bridge_classification_invalid",
		}
	if (
		not _receipt_fingerprint_valid(receipt)
		or PresentationReceiptIdentity.canonical_sha256(receipt)
			!= PresentationReceiptIdentity.canonical_sha256(expected_receipt)
		or PresentationReceiptIdentity.canonical_sha256(projection)
			!= PresentationReceiptIdentity.canonical_sha256(expected_projection)
	):
		return {
			"valid": false,
			"reason_code": "showcase_fixture_bridge_seal_invalid",
		}
	return {"valid": true, "episode": episode}


func _active_fixture_envelope_valid(
	receipt: Dictionary,
	projection: Dictionary
) -> bool:
	return (
		not _active_receipt.is_empty()
		and not _active_projection.is_empty()
		and str(receipt.get("fixture_class", "")) == FIXTURE_CLASS
		and str(receipt.get("receipt_source_class", FIXTURE_CLASS)) == FIXTURE_CLASS
		and not bool(receipt.get("natural_gameplay", true))
		and not bool(receipt.get("authority_receipt", false))
		and bool(receipt.get("fixture_sealed", false))
		and not bool(receipt.get("gameplay_green", true))
		and not bool(receipt.get("production_green", true))
		and not bool(receipt.get("human_green", true))
		and str(projection.get("fixture_class", "")) == FIXTURE_CLASS
		and not bool(projection.get("natural_gameplay", true))
		and _receipt_fingerprint_valid(receipt)
		and PresentationReceiptIdentity.canonical_sha256(receipt)
			== PresentationReceiptIdentity.canonical_sha256(_active_receipt)
		and PresentationReceiptIdentity.canonical_sha256(projection)
			== PresentationReceiptIdentity.canonical_sha256(_active_projection)
	)


func _fixture_route_for_episode(episode: Dictionary) -> String:
	var cue_id := str(episode.get("cue_id", "")).strip_edges()
	if cue_id.is_empty():
		return "PRODUCT_SHELL_FIXTURE"
	if _is_card_table_fixture_cue(cue_id):
		return "CARD_TABLE_FIXTURE"
	return "GENERIC_DIRECTOR_FIXTURE"


func _submit_generic_fixture_host(
	receipt: Dictionary,
	projection: Dictionary
) -> Dictionary:
	## Fail closed if any of the four typed card-table cues attempts to bypass
	## its dedicated fixture surface through the generic Director consumer.
	var cue_id := str(receipt.get("cue_id", "")).strip_edges()
	if _is_card_table_fixture_cue(cue_id):
		return {
			"accepted": false,
			"reason_code": "showcase_card_table_generic_route_forbidden",
		}
	if (
		_game_screen == null
		or not _game_screen.has_method(
			"enqueue_commercial_showcase_presentation_fixture"
		)
	):
		return {
			"accepted": false,
			"reason_code": "showcase_screen_fixture_consumer_missing",
		}
	return _game_screen.call(
		"enqueue_commercial_showcase_presentation_fixture",
		receipt.duplicate(true),
		projection.duplicate(true)
	) as Dictionary


func _fixture_bridge_result(route: String, raw_result: Dictionary) -> Dictionary:
	var result := raw_result.duplicate(true)
	result["schema"] = FIXTURE_BRIDGE_SCHEMA
	result["bridge_method"] = FIXTURE_BRIDGE_METHOD
	result["bridge_instance_count"] = 1
	result["route"] = route
	result["fixture_class"] = FIXTURE_CLASS
	result["natural_gameplay"] = false
	result["authority_receipt"] = false
	result["gameplay_green"] = false
	result["human_green"] = false
	result["production_green"] = false
	result["production_main_role"] = FIXTURE_BRIDGE_HOST_ROLE
	result["host_lifecycle_unchanged"] = _fixture_host_lifecycle_unchanged()
	_fixture_bridge_last_result = result.duplicate(true)
	return result


func _fixture_bridge_rejection(reason_code: String) -> Dictionary:
	_fixture_bridge_rejection_count += 1
	var result := {
		"accepted": false,
		"suppressed": false,
		"duplicate": false,
		"reason_code": reason_code,
	}
	return _fixture_bridge_result("REJECTED", result)


func _bump_fixture_bridge_route(route: String, counter: String) -> void:
	var row := _fixture_bridge_route_counts.get(route, {}) as Dictionary
	row[counter] = int(row.get(counter, 0)) + 1
	_fixture_bridge_route_counts[route] = row


func _host_lifecycle_snapshot() -> Dictionary:
	var composition_debug: Dictionary = {}
	if _runtime_composition != null and _runtime_composition.has_method(
		"debug_snapshot"
	):
		composition_debug = _runtime_composition.call("debug_snapshot") as Dictionary
	var ruleset_debug := composition_debug.get("ruleset", {}) as Dictionary
	var guard := _authority_guard_snapshot()
	return {
		"schema": "V076CommercialShowcaseHostLifecycleSnapshotV1",
		"session_sequence": int(composition_debug.get("session_sequence", -1)),
		"new_game_publication_count": int(composition_debug.get(
			"new_game_publication_count", -1
		)),
		"last_published_session_id": str(composition_debug.get(
			"last_published_session_id", ""
		)),
		"new_game_transaction_in_progress": bool(composition_debug.get(
			"new_game_transaction_in_progress", true
		)),
		"save_request_count": int(ruleset_debug.get("save_request_count", -1)),
		"load_request_count": int(ruleset_debug.get("load_request_count", -1)),
		"production_save_slot_write_count": int(ruleset_debug.get(
			"production_save_slot_write_count", -1
		)),
		"kernel_current_tick": int(guard.get("kernel_current_tick", -1)),
		"kernel_next_authority_sequence": int(guard.get(
			"kernel_next_authority_sequence", -1
		)),
		"kernel_rng_state_sha256": str(guard.get(
			"kernel_rng_state_sha256", ""
		)),
		"authority_snapshot_sha256": str(guard.get("snapshot_sha256", "")),
	}


func _fixture_host_lifecycle_unchanged() -> bool:
	if (
		_fixture_bridge_lifecycle_before.is_empty()
		or _fixture_bridge_lifecycle_after.is_empty()
	):
		return false
	# The full authority snapshot hash is proved per episode by the existing
	# authority guard.  This bridge-specific witness independently seals the
	# lifecycle values that could otherwise fake a "presentation" by starting a
	# Session, requesting Save/Load, advancing Tick/sequence, or drawing RNG.
	for key in [
		"session_sequence",
		"new_game_publication_count",
		"last_published_session_id",
		"new_game_transaction_in_progress",
		"save_request_count",
		"load_request_count",
		"production_save_slot_write_count",
		"kernel_current_tick",
		"kernel_next_authority_sequence",
		"kernel_rng_state_sha256",
	]:
		if _fixture_bridge_lifecycle_before.get(key) != (
			_fixture_bridge_lifecycle_after.get(key)
		):
			return false
	return true


func _fixture_bridge_debug_snapshot() -> Dictionary:
	return {
		"schema": FIXTURE_BRIDGE_SCHEMA,
		"bridge_method": FIXTURE_BRIDGE_METHOD,
		"bridge_instance_count": 1,
		"production_main_role": FIXTURE_BRIDGE_HOST_ROLE,
		"fixture_class": FIXTURE_CLASS,
		"natural_gameplay": false,
		"authority_receipt": false,
		"gameplay_green": false,
		"human_green": false,
		"production_green": false,
		"submit_count": _fixture_bridge_submit_count,
		"replay_count": _fixture_bridge_replay_count,
		"finish_count": _fixture_bridge_finish_count,
		"rejection_count": _fixture_bridge_rejection_count,
		"duplicate_suppressed_count": (
			_fixture_bridge_duplicate_suppressed_count
		),
		"route_counts": _fixture_bridge_route_counts.duplicate(true),
		"last_route": _fixture_bridge_last_route,
		"last_result": _fixture_bridge_last_result.duplicate(true),
		"lifecycle_before": _fixture_bridge_lifecycle_before.duplicate(true),
		"lifecycle_after": _fixture_bridge_lifecycle_after.duplicate(true),
		"host_lifecycle_unchanged": _fixture_host_lifecycle_unchanged(),
		"fixture_created_session_count": 0,
		"fixture_save_request_count": 0,
		"fixture_rng_draw_count": 0,
		"fixture_tick_advance_count": 0,
	}


func _is_card_table_fixture_cue(cue_id: String) -> bool:
	return CARD_TABLE_FIXTURE_RECEIPT_KIND_BY_CUE.has(cue_id.strip_edges())


func _screen_card_table_debug() -> Dictionary:
	if (
		_game_screen == null
		or not _game_screen.has_method("combat_debug_snapshot")
	):
		return {}
	var debug := _game_screen.call("combat_debug_snapshot") as Dictionary
	return (debug.get("card_table_presentation", {}) as Dictionary).duplicate(true)


func _enqueue_card_table_fixture_episode(episode: Dictionary) -> bool:
	if _game_screen == null:
		_prepare_rejection_reason = "showcase_card_table_screen_missing"
		return false
	var cue_id := str(episode.get("cue_id", "")).strip_edges()
	if cue_id == "FINAL_SETTLEMENT":
		if not _game_screen.has_method("present_final_settlement_fixture"):
			_prepare_rejection_reason = "showcase_final_settlement_fixture_surface_missing"
			return false
		var fixture_source_id := str(_active_fixture_source_id)
		var settlement := _fixture_settlement_projection()
		settlement["settlement_id"] = fixture_source_id
		var settlement_result := _game_screen.call(
			"present_final_settlement_fixture",
			settlement,
			fixture_source_id
		) as Dictionary
		if not bool(settlement_result.get("accepted", false)):
			_prepare_rejection_reason = str(settlement_result.get(
				"reason_code",
				"showcase_final_settlement_fixture_rejected"
			))
			return false
		var bridge := _screen_card_table_debug()
		var cue_evidence := bridge.get("cue_evidence", {}) as Dictionary
		var final_evidence := cue_evidence.get("FINAL_SETTLEMENT", {}) as Dictionary
		var envelope := final_evidence.get("envelope", {}) as Dictionary
		if envelope.is_empty():
			_prepare_rejection_reason = "showcase_final_settlement_fixture_envelope_missing"
			return false
		_active_receipt = envelope.duplicate(true)
		if not _receipt_fingerprint_valid_or_add(_active_receipt):
			_prepare_rejection_reason = "showcase_final_settlement_fixture_fingerprint_invalid"
			return false
		_active_cue = (settlement_result.get("queued_cue", {}) as Dictionary).duplicate(true)
		_enqueue_count = 1
		return true

	if not _game_screen.has_method("enqueue_card_table_presentation"):
		_prepare_rejection_reason = "showcase_card_table_bridge_missing"
		return false
	var queued := _game_screen.call(
		"enqueue_card_table_presentation",
		_active_receipt.duplicate(true),
		_active_projection.duplicate(true),
		FIXTURE_CLASS
	) as Dictionary
	if not bool(queued.get("accepted", false)):
		_prepare_rejection_reason = str(queued.get(
			"reason_code",
			"showcase_card_table_fixture_enqueue_rejected"
		))
		return false
	_active_cue = (queued.get("queued_cue", {}) as Dictionary).duplicate(true)
	var bridge_receipt_id := str(queued.get("receipt_id", ""))
	if bridge_receipt_id.is_empty() or not _game_screen.has_method(
		"begin_card_table_presentation_surface"
	):
		_prepare_rejection_reason = "showcase_card_table_fixture_surface_missing"
		return false
	var started := bool(_game_screen.call(
		"begin_card_table_presentation_surface",
		bridge_receipt_id,
		{
			"schema": "V076PresentationFixtureSurfaceStartV1",
			"receipt_id": bridge_receipt_id,
			"source_rect": _source_rect,
			"target_rect": _target_rect,
			"presentation_only": true,
			"gameplay_mutation_count": 0,
			"rng_draw_delta": 0,
			"authority_sequence_delta": 0,
		},
		FIXTURE_CLASS
	))
	if not started:
		_prepare_rejection_reason = "showcase_card_table_fixture_surface_start_rejected"
		return false
	_enqueue_count = 1
	return true


func _finish_card_table_fixture_episode(cue_id: String) -> bool:
	if cue_id == "FINAL_SETTLEMENT":
		if not _game_screen.has_method("finish_final_settlement_fixture"):
			return false
		return bool(_game_screen.call(
			"finish_final_settlement_fixture",
			_active_fixture_source_id
		))
	if (
		_game_screen == null
		or not _game_screen.has_method("finish_card_table_presentation")
	):
		return false
	var receipt_id := str(_active_receipt.get("receipt_id", ""))
	return bool(_game_screen.call(
		"finish_card_table_presentation",
		receipt_id,
		{
			"schema": "V076PresentationFixtureSurfaceFinishV1",
			"receipt_id": receipt_id,
			"end_rect": _current_proxy_rect(),
			"terminal_status": "FIXTURE_COMPLETE",
			"presentation_only": true,
			"gameplay_mutation_count": 0,
			"rng_draw_delta": 0,
			"authority_sequence_delta": 0,
		},
		FIXTURE_CLASS
	))


func _receipt_fingerprint_valid_or_add(receipt: Dictionary) -> bool:
	var supplied := str(receipt.get("receipt_fingerprint", ""))
	var source := receipt.duplicate(true)
	source.erase("receipt_fingerprint")
	var canonical := PresentationReceiptIdentity.canonical_sha256(source)
	if supplied.is_empty():
		receipt["receipt_fingerprint"] = canonical
		return true
	return supplied == canonical


func _receipt_fingerprint_valid(receipt: Dictionary) -> bool:
	var supplied := str(receipt.get("receipt_fingerprint", ""))
	var source := receipt.duplicate(true)
	source.erase("receipt_fingerprint")
	return (
		supplied.length() == 64
		and supplied == PresentationReceiptIdentity.canonical_sha256(source)
	)


func _episode_for_id(episode_id: String) -> Dictionary:
	for episode_variant in EPISODES:
		var episode := episode_variant as Dictionary
		if str(episode.get("id", "")) == episode_id:
			return episode.duplicate(true)
	return {}


func _fixture_receipt(episode: Dictionary) -> Dictionary:
	var episode_id := str(episode.get("id", ""))
	var cue_id := str(episode.get("cue_id", ""))
	var card_table_fixture := _is_card_table_fixture_cue(cue_id)
	var receipt := {
		"schema": (
			"V076PresentationFixtureEnvelopeV1"
			if card_table_fixture
			else "V076CommercialPresentationFixtureReceiptV1"
		),
		"schema_version": 1,
		"accepted": true,
		"receipt_id": "commercial-m1-fixture/%s/v1" % episode_id,
		"receipt_kind": str(
			CARD_TABLE_FIXTURE_RECEIPT_KIND_BY_CUE.get(
				cue_id,
				episode.get("receipt_kind", "")
			)
		),
		"cue_id": cue_id,
		"fixture_sequence": 760800 + _episode_index(episode_id),
		"fixture_class": FIXTURE_CLASS,
		"receipt_source_class": FIXTURE_CLASS,
		"authority_receipt": false,
		"fixture_sealed": true,
		"fixture_source": CANONICAL_SCENE_PATH,
		"natural_gameplay": false,
		"gameplay_green": false,
		"human_green": false,
		"production_green": false,
	}
	receipt["receipt_fingerprint"] = (
		PresentationReceiptIdentity.canonical_sha256(receipt)
	)
	return receipt


func _fixture_projection(episode: Dictionary) -> Dictionary:
	return {
		"schema": "V076CommercialPresentationFixtureProjectionV1",
		"episode_id": str(episode.get("id", "")),
		"public_label": str(episode.get("title", "")),
		"current_player_authorized": true,
		"source_anchor": str(episode.get("source_node", "")),
		"target_anchor": str(episode.get("target_node", "")),
		"source_anchor_path": str(episode.get("source_anchor_path", "")),
		"target_anchor_path": str(episode.get("target_anchor_path", "")),
		"fixture_sequence": 760800 + _episode_index(str(
			episode.get("id", "")
		)),
		"fixture_class": FIXTURE_CLASS,
		"natural_gameplay": false,
		"human_green": false,
		"production_green": false,
	}


func _surface_transition_cue(episode: Dictionary) -> Dictionary:
	return {
		"schema": "V076CommercialSurfaceTransitionCueV1",
		"cue_id": str(episode.get("surface_cue_id", "")),
		"receipt_kind": str(episode.get("receipt_kind", "")),
		"duration_ms": 360 if not reduced_motion else 120,
		"motion_mode": "REDUCED_MOTION" if reduced_motion else "FULL_MOTION",
		"completion_policy": "presentation_surface_visible",
		"director_owned": false,
		"product_shell_owned": true,
	}


func _register_local_fixture_receipt(receipt: Dictionary) -> void:
	var receipt_id := str(receipt.get("receipt_id", ""))
	if receipt_id.is_empty() or _local_receipt_ledger.has(receipt_id):
		return
	_local_receipt_ledger[receipt_id] = str(receipt.get(
		"receipt_fingerprint", ""
	))
	_enqueue_count = 1


func _fixture_settlement_projection() -> Dictionary:
	return {
		"settlement_id": "commercial-m1-presentation-fixture",
		"winner_player_id": "player.local",
		"standings": [
			{
				"rank": 1,
				"player_id": "player.local",
				"display_name": "本席玩家",
				"facility_count": 4,
				"asset_total": 12,
			},
			{
				"rank": 2,
				"player_id": "player.ai.01",
				"display_name": "电脑对手 A",
				"facility_count": 3,
				"asset_total": 10,
			},
			{
				"rank": 3,
				"player_id": "player.ai.02",
				"display_name": "电脑对手 B",
				"facility_count": 2,
				"asset_total": 8,
			},
			{
				"rank": 4,
				"player_id": "player.ai.03",
				"display_name": "电脑对手 C",
				"facility_count": 1,
				"asset_total": 6,
			},
		],
		"fixture_class": FIXTURE_CLASS,
		"natural_gameplay": false,
		"human_green": false,
	}


func _authority_guard_snapshot() -> Dictionary:
	if (
		_runtime_composition == null
		or not _runtime_composition.has_method(
			"presentation_authority_guard_snapshot"
		)
	):
		return {}
	return _runtime_composition.call(
		"presentation_authority_guard_snapshot"
	) as Dictionary


func _director_debug() -> Dictionary:
	if _director != null and _director.has_method("animation_debug_snapshot"):
		return _director.call("animation_debug_snapshot") as Dictionary
	return {}


func _resolve_unique_anchor_control(
	declared_path: String,
	expected_terminal_name: String
) -> Dictionary:
	if (
		declared_path.is_empty()
		or expected_terminal_name.is_empty()
		or _production_main == null
	):
		return {"valid": false, "name_count": 0}
	var node := _production_main.get_node_or_null(NodePath(declared_path))
	var control := node as Control
	var name_count := _count_named_recursive(
		_production_main, expected_terminal_name
	)
	var resolved_path := (
		str(_production_main.get_path_to(control))
		if control != null
		else ""
	)
	var rect := control.get_global_rect() if control != null else Rect2()
	return {
		"valid": (
			control != null
			and str(control.name) == expected_terminal_name
			and resolved_path == declared_path
			and name_count == 1
			and rect.size.x > 1.0
			and rect.size.y > 1.0
		),
		"resolved_path": resolved_path,
		"name_count": name_count,
		"rect": rect,
	}


func _proxy_rect_for_anchor(anchor: Rect2) -> Rect2:
	var proxy_size := Vector2(
		clampf(anchor.size.x * 0.54, 132.0, 244.0),
		clampf(anchor.size.y * 0.54, 74.0, 132.0)
	)
	return Rect2(
		anchor.position + (anchor.size - proxy_size) * 0.5,
		proxy_size
	)


func _current_proxy_rect() -> Rect2:
	return Rect2(_fixture_proxy.position, _fixture_proxy.size)


func _rects_equal(left: Rect2, right: Rect2) -> bool:
	return (
		left.position.distance_to(right.position) <= 0.5
		and left.size.distance_to(right.size) <= 0.5
	)


func _rect_data(rect: Rect2) -> Dictionary:
	return {
		"x": snappedf(rect.position.x, 0.001),
		"y": snappedf(rect.position.y, 0.001),
		"width": snappedf(rect.size.x, 0.001),
		"height": snappedf(rect.size.y, 0.001),
	}


func _surface_state_snapshot() -> Dictionary:
	var loading_debug: Dictionary = {}
	if _loading_overlay != null and _loading_overlay.has_method("debug_snapshot"):
		loading_debug = _loading_overlay.call("debug_snapshot") as Dictionary
	return {
		"menu_visible": _menu_overlay != null and _menu_overlay.visible,
		"loading_visible": _loading_overlay != null and _loading_overlay.visible,
		"settlement_visible": (
			_settlement_overlay != null and _settlement_overlay.visible
		),
		"fixture_proxy_visible": _fixture_proxy != null and _fixture_proxy.visible,
		"fixture_banner_visible": _fixture_banner != null and _fixture_banner.visible,
		"loading_debug": loading_debug,
	}


func _phase_alpha(phase: String) -> float:
	match phase:
		"start":
			return 0.46
		"mid":
			return 0.76
		_:
			return 1.0


func _episode_index(episode_id: String) -> int:
	for index in range(EPISODES.size()):
		var episode := EPISODES[index] as Dictionary
		if str(episode.get("id", "")) == episode_id:
			return index
	return -1


func _node_name_count(node_name: String) -> int:
	return _count_named_recursive(self, node_name)


func _count_named_recursive(node: Node, node_name: String) -> int:
	var count := int(node.name == node_name)
	for child_variant in node.get_children():
		if child_variant is Node:
			count += _count_named_recursive(child_variant as Node, node_name)
	return count


func _authority_owner_audit(root_node: Node, excluded_subtree: Node) -> Dictionary:
	var result := {
		"gameplay": 0,
		"rng": 0,
		"tick": 0,
		"card_zone": 0,
		"facility": 0,
		"settlement": 0,
		"instances_by_script": {},
		"duplicate_authority_owner_count": 0,
	}
	_collect_authority_owner_audit(root_node, excluded_subtree, result)
	for count_variant in (result.get(
		"instances_by_script", {}
	) as Dictionary).values():
		result["duplicate_authority_owner_count"] += maxi(
			0, int(count_variant) - 1
		)
	return result


func _collect_authority_owner_audit(
	node: Node,
	excluded_subtree: Node,
	result: Dictionary
) -> void:
	if node == null or node == excluded_subtree:
		return
	var script := node.get_script() as Script
	if script != null:
		var script_path := script.resource_path
		if AUTHORITY_OWNER_SCRIPT_CATEGORIES.has(script_path):
			var instances := result.get("instances_by_script", {}) as Dictionary
			instances[script_path] = int(instances.get(script_path, 0)) + 1
			result["instances_by_script"] = instances
			for category_variant in (
				AUTHORITY_OWNER_SCRIPT_CATEGORIES.get(script_path, []) as Array
			):
				var category := str(category_variant)
				result[category] = int(result.get(category, 0)) + 1
	for child_variant in node.get_children():
		if child_variant is Node:
			_collect_authority_owner_audit(
				child_variant as Node, excluded_subtree, result
			)

extends SceneTree

const COMPOSITION_PATH := "res://scenes/runtime/V075RuntimeComposition.tscn"
const PRODUCTION_SCREEN_PATH := "res://scenes/ui/v075/V075SampleGameScreen.tscn"
const AssetBatchCore := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const PublicActionBatchCore := preload(
	"res://scripts/v075/runtime/v075_public_action_batch_core.gd"
)
const FacilityCore := preload(
	"res://scripts/v074/facility/v074_facility_runtime_core.gd"
)
const DbgCore := preload(
	"res://scripts/v07_semantic/v07_dbg_deck_core.gd"
)
const CardDefinitions := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const StateCodec := preload(
	"res://scripts/v076/simulation/v076_authority_state_codec.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(COMPOSITION_PATH) as PackedScene
	_expect(packed != null, "production V075 composition loads")
	if packed == null:
		_finish()
		return
	var composition := packed.instantiate()
	root.add_child(composition)
	await process_frame
	await process_frame
	var screen_packed := load(PRODUCTION_SCREEN_PATH) as PackedScene
	_expect(screen_packed != null, "production V075 GameScreen loads")
	var production_screen := (
		screen_packed.instantiate() if screen_packed != null else null
	)
	if production_screen != null:
		root.add_child(production_screen)
		await process_frame
		production_screen.call(
			"bind_application_flow",
			composition,
			composition.call("identity_snapshot") as Dictionary,
			composition.call("capability_snapshot") as Dictionary
		)
		composition.projection_changed.connect(
			Callable(production_screen, "apply_snapshot")
		)
	var runtime := composition.get_node_or_null("V075RuntimeOwner")
	var kernel := composition.get_node_or_null("V076DeterministicKernel")
	var eta := composition.get_node_or_null("V076MilitaryPhysicalEtaOwnerV1")
	var adapter := composition.get_node_or_null("V076V075ProductionAdapterV1")
	var direct := composition.get_node_or_null("V076PrivateDirectActionInputOwnerV1")
	_expect(runtime != null, "composition reuses one V075 runtime Owner")
	_expect(kernel != null, "composition exposes one V076 Kernel")
	_expect(eta != null, "composition exposes one V076 physical ETA Owner")
	_expect(adapter != null, "composition exposes one stateless V075 adapter")
	_expect(direct != null, "composition exposes one private Direct Action Owner")
	if runtime == null or kernel == null or eta == null or adapter == null or direct == null:
		composition.queue_free()
		await process_frame
		_finish()
		return
	var started := composition.call("_start_new_game", {
		"player_count": 4,
		"seed": 900626424,
		"map_seed": 900626424,
		"region_count": 16,
		"geography_complexity": "STANDARD",
		"land_ocean_profile": "BALANCED",
	}) as Dictionary
	_expect(bool(started.get("accepted", false)), "production new game configures V076 once")
	var flow_debug := composition.call("debug_snapshot") as Dictionary
	_expect(bool(flow_debug.get("v076_production_ready", false)), "V076 production bridge is ready")
	_expect(int(flow_debug.get("v076_kernel_owner_count", 0)) == 1, "Kernel owner count is one")
	_expect(int(flow_debug.get("v076_private_direct_action_owner_count", 0)) == 1, "Direct Action owner count is one")
	_expect(int(flow_debug.get("v076_production_adapter_count", 0)) == 1, "adapter count is one")
	_expect(int(flow_debug.get("v076_military_eta_owner_count", 0)) == 1, "ETA owner count is one")
	var actor_id := str(runtime.call("local_player_id"))
	_expect(not actor_id.is_empty(), "local actor identity is authoritative")
	var asset_setup := _install_assets(runtime)
	_expect(bool(asset_setup.get("accepted", false)), "fixture installs positive existing-owner assets")
	var facility_setup := _install_enemy_facility(runtime, actor_id)
	_expect(bool(facility_setup.get("accepted", false)), "fixture installs one legal enemy facility")
	var card_setup := _install_military_card(runtime, actor_id)
	_expect(bool(card_setup.get("accepted", false)), "fixture installs one exact V075 military card")
	runtime.call("_clear_v075_submission_caches")
	var snapshot := runtime.call("player_snapshot", actor_id) as Dictionary
	var combat_projection := snapshot.get("v075_combat_projection", {}) as Dictionary
	var option := _first_region_option(
		combat_projection.get("military_task_options", []) as Array,
		str(card_setup.get("card_instance_id", ""))
	)
	_expect(not option.is_empty(), "owner-private projection supplies one legal region assault")
	var source_face := int(runtime.call("v076_production_face_binding", str(
		runtime.call("_v076_production_source_region_for_actor", actor_id)
	)))
	var target_face := int(runtime.call(
		"v076_production_face_binding",
		str(option.get("target_region_id", ""))
	))
	_expect(source_face >= 0 and target_face >= 0, "V075 regions bind to canonical V076 faces")
	_expect(source_face != target_face, "fixture traverses a non-zero physical route")
	var color := str(card_setup.get("primary_color", ""))
	var before_assets := _actor_assets(runtime, actor_id)
	var private_receipts: Array[Dictionary] = []
	composition.owner_private_receipt_ready.connect(func(receipt: Dictionary) -> void:
		private_receipts.append(receipt.duplicate(true))
	)
	var production_events: Array[Dictionary] = []
	composition.public_resolution_ready.connect(func(receipt: Dictionary) -> void:
		production_events.append(receipt.duplicate(true))
	)
	var asset_projection_events: Array[Dictionary] = []
	composition.projection_changed.connect(func(projected: Dictionary) -> void:
		asset_projection_events.append(projected.duplicate(true))
	)
	if production_screen != null:
		production_screen.call(
			"apply_snapshot",
			composition.call("local_snapshot") as Dictionary
		)
	var before_asset_model := _asset_pip_model(production_screen, color)
	_expect(
		int(before_asset_model.get("current", -1))
			== int(before_assets.get(color, -2)),
		"production AssetRail renders the existing Owner's pre-action quantity"
	)
	var intent_id := "intent.v076.production.military.001"
	var diagnostic_bundle := runtime.call(
		"authorize_v076_production_military_bundle", actor_id, option
	) as Dictionary
	var diagnostic_request := runtime.call(
		"build_v076_production_military_request",
		actor_id,
		"v076.production.military.%s" % intent_id,
		option,
		diagnostic_bundle.get("bundle", {}) as Dictionary
	) as Dictionary
	if str((diagnostic_bundle.get("bundle", {}) as Dictionary).get(
		"authorization_fingerprint", ""
	)).is_empty():
		print("V076_PRODUCTION_BUNDLE_DIAGNOSTIC|%s" % JSON.stringify(
			StateCodec.validate(diagnostic_bundle.get("bundle", {}))
		))
	var diagnostic_plan := (diagnostic_request.get("request", {}) as Dictionary).get(
		"asset_reservation_plan", {}
	) as Dictionary
	var diagnostic_plan_error := AssetBatchCore._private_direct_action_reservation_request_error(
		diagnostic_plan
	)
	if not diagnostic_plan_error.is_empty():
		print("V076_PRODUCTION_ASSET_PLAN_DIAGNOSTIC|%s|%s" % [
			diagnostic_plan_error,
			JSON.stringify(diagnostic_plan),
		])
	var submitted := composition.call("submit_intent", {
		"intent_id": intent_id,
		"intent_kind": "combat.military_mission.select",
		"parameters": option.duplicate(true),
	}) as Dictionary
	if not bool(submitted.get("accepted", false)):
		print("V076_PRODUCTION_SUBMIT_DIAGNOSTIC|%s" % JSON.stringify(submitted))
	_expect(bool(submitted.get("accepted", false)), "production Flow submits private military action")
	_expect(str(submitted.get("receipt_scope", "")) == "owner_private", "submission acknowledgement is owner-private")
	_expect(not JSON.stringify(submitted).contains(str(card_setup.get("card_instance_id", ""))), "private acknowledgement omits card identity")
	var direct_after_submit := direct.call("debug_snapshot") as Dictionary
	_expect(int(direct_after_submit.get("submission_count", 0)) == 1, "one private root submission is recorded")
	_expect(int(kernel.call("root_commands").size()) == 1, "Kernel receives one root command")
	var collision := composition.call("submit_intent", {
		"intent_id": "intent.v076.production.military.002",
		"intent_kind": "combat.military_mission.select",
		"parameters": option.duplicate(true),
	}) as Dictionary
	_expect(not bool(collision.get("accepted", true)), "same card cannot gain a second in-flight submission")
	_expect(int(direct.call("debug_snapshot").get("submission_count", 0)) == 1, "in-flight rejection adds no second root")
	var asset_state_error := AssetBatchCore._state_error(
		runtime.get("_asset_state") as Dictionary
	)
	if not asset_state_error.is_empty():
		print("V076_PRODUCTION_ASSET_STATE_DIAGNOSTIC|%s" % asset_state_error)
	composition.call("_process", 40.0)
	var direct_after_settlement := direct.call("debug_snapshot") as Dictionary
	if int(direct_after_settlement.get("settlement_count", 0)) != 1:
		var ready_ids := direct.call("withdrawal_ready_submission_ids") as Array
		var settle_diagnostic := (
			direct.call("settle_completed_submission", str(ready_ids[0])) as Dictionary
			if not ready_ids.is_empty()
			else {}
		)
		print("V076_PRODUCTION_SETTLEMENT_DIAGNOSTIC|%s" % JSON.stringify(
			settle_diagnostic
		))
	_expect(int(direct_after_settlement.get("settlement_count", 0)) == 1, "mission settles exactly once")
	_expect(int(direct_after_settlement.get("damage_settlement_count", 0)) == 1, "typed damage settles exactly once")
	_expect(int(direct_after_settlement.get("public_batch_entry_count", -1)) == 0, "military action never enters public batch")
	_expect(int(direct_after_settlement.get("shared_sushi_track_resolution_count", -1)) == 0, "military action never enters sushi track")
	_expect((runtime.call("_card_in_hand", actor_id, str(card_setup.get("card_instance_id", ""))) as Dictionary).is_empty(), "card instance is consumed only after withdrawal")
	var after_assets := _actor_assets(runtime, actor_id)
	_expect(int(after_assets.get(color, -1)) == int(before_assets.get(color, -1)) - int(card_setup.get("cost", 0)), "existing asset Owner debits the exact authored cost once")
	_expect(asset_projection_events.size() == 1, "final military asset consequence publishes one production projection")
	var projected_assets := (
		(asset_projection_events[0] as Dictionary).get("six_color_assets", {})
		as Dictionary
	)
	_expect(
		int((projected_assets.get("own_exact_assets", {}) as Dictionary).get(
			color, -1
		)) == int(after_assets.get(color, -2)),
		"published player projection exposes the authoritative post-action quantity"
	)
	var after_asset_model := _asset_pip_model(production_screen, color)
	_expect(
		int(after_asset_model.get("current", -1))
			== int(after_assets.get(color, -2))
			and int(after_asset_model.get("available", -1))
				== int(after_assets.get(color, -2)),
		"production AssetRail visibly consumes the one post-action projection"
	)
	_expect(
		_count_presentation_kind(production_events, "military_region_assault") == 1
			and _count_presentation_kind(production_events, "military_withdrawn") == 1,
		"region assault and withdrawal are presented once through the existing V075 Owner"
	)
	var region_presentation := _first_presentation_kind(
		production_events, "military_region_assault"
	)
	_expect(
		str(region_presentation.get("route_sha256", "")).length() == 64
			and int(region_presentation.get("total_distance_mu", 0)) > 0
			and int(region_presentation.get("eta_ticks", 0)) > 0,
		"visible military consequence binds the canonical physical route and ETA"
	)
	var first_entry := ((kernel.call(
		"domain_state", "future.private_direct_action_input"
	) as Dictionary).get("submission_ledger", {}) as Dictionary).get(
		"v076.production.military.%s" % intent_id, {}
	) as Dictionary
	var consequence_replay := runtime.call(
		"consume_v076_military_consequence",
		direct.call(
			"_military_consequence_envelope",
			first_entry,
			first_entry.get("mission_receipt", {}) as Dictionary
		) as Dictionary
	) as Dictionary
	_expect(
		bool(consequence_replay.get("accepted", false))
			and bool(consequence_replay.get("duplicate", false)),
		"terminal military consequence replay is acknowledged as duplicate"
	)
	_expect(
		asset_projection_events.size() == 1
			and _count_presentation_kind(
				production_events, "military_region_assault"
			) == 1
			and _count_presentation_kind(
				production_events, "military_withdrawn"
			) == 1,
		"consequence replay creates no duplicate asset projection or presentation"
	)
	var screen_debug := (
		production_screen.call("combat_debug_snapshot") as Dictionary
		if production_screen != null
		else {}
	)
	var screen_acceptance := (
		production_screen.get("acceptance_state") as Dictionary
		if production_screen != null
		else {}
	)
	_expect(
		int(screen_debug.get("presentation_gameplay_mutation_count", -1)) == 0
			and int((screen_debug.get("presentation", {}) as Dictionary).get(
				"presentation_gameplay_mutation_count", -1
			)) == 0
			and int(screen_acceptance.get(
				"asset_pip_gameplay_mutation_count", -1
			)) == 0,
		"existing combat and AssetRail presentation own no gameplay mutation"
	)
	_expect((runtime.get("_v076_production_military_submission_by_uid") as Dictionary).is_empty(), "withdrawal clears the in-flight source claim")
	var monster_setup := _install_enemy_monster(
		runtime,
		actor_id,
		str(facility_setup.get("region_id", ""))
	)
	_expect(bool(monster_setup.get("accepted", false)), "fixture deploys one target through the existing V075 monster Owner")
	var monster_card := _install_military_card(runtime, actor_id)
	_expect(bool(monster_card.get("accepted", false)), "fixture installs a second exact V075 military card")
	runtime.call("_clear_v075_submission_caches")
	var monster_projection := (
		(runtime.call("player_snapshot", actor_id) as Dictionary).get(
			"v075_combat_projection", {}
		) as Dictionary
	)
	var monster_option := _first_monster_option(
		monster_projection.get("military_task_options", []) as Array,
		str(monster_card.get("card_instance_id", "")),
		str(monster_setup.get("source_instance_id", ""))
	)
	_expect(not monster_option.is_empty(), "owner-private projection supplies one legal monster assault")
	var monster_source_face := int(runtime.call(
		"v076_production_face_binding",
		str(runtime.call("_v076_production_source_region_for_actor", actor_id))
	))
	var monster_target_face := int(runtime.call(
		"v076_production_face_binding",
		str(monster_setup.get("region_id", ""))
	))
	_expect(
		monster_source_face >= 0
			and monster_target_face >= 0
			and monster_source_face != monster_target_face,
		"monster mission traverses a non-zero canonical geodesic route"
	)
	var monster_before := _public_monster(
		runtime, str(monster_setup.get("source_instance_id", ""))
	)
	var monster_color := str(monster_card.get("primary_color", ""))
	var monster_assets_before := _actor_assets(runtime, actor_id)
	asset_projection_events.clear()
	var monster_intent_id := "intent.v076.production.military.003"
	var monster_submitted := composition.call("submit_intent", {
		"intent_id": monster_intent_id,
		"intent_kind": "combat.military_mission.select",
		"parameters": monster_option.duplicate(true),
	}) as Dictionary
	_expect(bool(monster_submitted.get("accepted", false)), "production Flow submits private monster assault")
	_expect(
		not JSON.stringify(monster_submitted).contains(str(
			monster_setup.get("source_instance_id", "")
		)),
		"private monster acknowledgement omits target identity"
	)
	composition.call("_process", 40.0)
	var after_monster_settlement := direct.call("debug_snapshot") as Dictionary
	var monster_after := _public_monster(
		runtime, str(monster_setup.get("source_instance_id", ""))
	)
	var monster_assets_after := _actor_assets(runtime, actor_id)
	_expect(int(after_monster_settlement.get("settlement_count", 0)) == 2, "region and monster missions each settle exactly once")
	_expect(int(after_monster_settlement.get("damage_settlement_count", 0)) == 2, "both production typed damage paths settle exactly once")
	_expect(int(kernel.call("root_commands").size()) == 2, "both production missions share the one Kernel root ledger")
	_expect(
		int(monster_after.get("hp", -1)) < int(monster_before.get("hp", -1))
			or int(monster_after.get("armor", -1))
				< int(monster_before.get("armor", -1)),
		"monster assault mutates only the existing V075 monster Owner"
	)
	_expect(
		int(monster_assets_after.get(monster_color, -1))
			== int(monster_assets_before.get(monster_color, -1))
				- int(monster_card.get("cost", 0)),
		"monster assault debits the exact authored asset cost once"
	)
	_expect(
		asset_projection_events.size() == 1
			and _count_presentation_kind(
				production_events, "military_monster_assault"
			) == 1
			and _count_presentation_kind(
				production_events, "military_withdrawn"
			) == 2,
		"monster assault publishes one asset projection and one attack/withdrawal consequence"
	)
	_expect(
		(runtime.call(
			"_card_in_hand", actor_id,
			str(monster_card.get("card_instance_id", ""))
		) as Dictionary).is_empty(),
		"monster assault card is consumed after execute-once withdrawal"
	)
	_expect(
		(runtime.get("_v076_production_military_submission_by_uid") as Dictionary).is_empty(),
		"monster withdrawal clears the in-flight source claim"
	)
	var autonomy_facility := _install_enemy_facility(
		runtime,
		actor_id,
		str(monster_after.get("region_id", "")),
		"facility.v076.production.monster.autonomy",
		actor_id,
		"life"
	)
	_expect(bool(autonomy_facility.get("accepted", false)), "fixture installs a live enemy facility in another region for Monster autonomy")
	var monster_before_autonomy := _public_monster(
		runtime, str(monster_setup.get("source_instance_id", ""))
	)
	var facility_damage_event_count_before_autonomy := _count_presentation_kind(
		production_events, "facility_combat_damaged"
	)
	var combat_debug_before := (
		(runtime.call("debug_snapshot") as Dictionary).get("combat", {}) as Dictionary
	)
	var roots_before_autonomy := (kernel.call("root_commands") as Array).size()
	var maintenance: Dictionary = {}
	for _attempt in range(16):
		maintenance = runtime.call("_resolve_combat_maintenance") as Dictionary
		if not bool(maintenance.get("accepted", false)) \
				or int(maintenance.get("v076_monster_root_submission_count", 0)) == 1:
			break
	_expect(bool(maintenance.get("accepted", false)), "production maintenance stages one Monster cutover root")
	_expect(bool(maintenance.get("v076_monster_cutover_active", false)), "production maintenance declares the V076 Monster cutover active")
	_expect(int(maintenance.get("v076_monster_root_submission_count", 0)) == 1, "one autonomy plan submits one atomic Monster root batch")
	var maintenance_autonomy := maintenance.get("autonomy", {}) as Dictionary
	_expect((maintenance_autonomy.get("movement_receipts", []) as Array).is_empty(), "old V075 autonomy movement receipt never reaches its historical writer")
	_expect((maintenance_autonomy.get("trample_region_receipts", []) as Array).is_empty(), "old V075 trample resolver never reaches production")
	var combat_debug_after_plan := (
		(runtime.call("debug_snapshot") as Dictionary).get("combat", {}) as Dictionary
	)
	_expect(
		int(combat_debug_after_plan.get("monster_movement_count", -1))
			== int(combat_debug_before.get("monster_movement_count", -2)),
		"V075 Monster movement writer count remains unchanged at the cutover boundary"
	)
	_expect(
		(kernel.call("root_commands") as Array).size() == roots_before_autonomy + 1,
		"Monster autonomy shares the existing Kernel root ledger"
	)
	composition.call("_process", 40.0)
	var monster_after_autonomy := _public_monster(
		runtime, str(monster_setup.get("source_instance_id", ""))
	)
	var monster_domain := kernel.call(
		"domain_state", "monster.l1.move"
	) as Dictionary
	var v076_monster := ((monster_domain.get("monsters", {}) as Dictionary).get(
		str(monster_setup.get("source_instance_id", "")), {}
	) as Dictionary)
	_expect(
		str(monster_after_autonomy.get("region_id", ""))
			!= str(monster_before_autonomy.get("region_id", "")),
		"V075 public Monster projection consumes the V076 physical destination"
	)
	_expect(
		bool(v076_monster.get("production_cutover", false))
			and str(v076_monster.get("status", "")) == "ARRIVED"
			and int(v076_monster.get("region_crossing_count", 0)) > 0,
		"unique V076 Monster Owner completes one physical geodesic crossing"
	)
	_expect(
		(monster_domain.get("assets", {}) as Dictionary).is_empty()
			and (monster_domain.get("asset_activation_log", []) as Array).is_empty(),
		"production Monster movement creates no second asset quantity or activation ledger"
	)
	_expect(
		_count_presentation_kind(production_events, "facility_combat_damaged")
			== facility_damage_event_count_before_autonomy + 1
			and _presentation_damage(
				production_events,
				"facility_combat_damaged"
			) > 0,
		"V076 trample damage is consumed once by the existing facility HP Owner"
	)
	_expect(
		_count_presentation_kind(production_events, "monster_moved") == 1,
		"one V076 terminal movement is presented exactly once"
	)
	_expect(
		_count_presentation_kind(production_events, "monster_trample_resolved") == 1,
		"one V076 trample consequence is presented exactly once"
	)
	var repeated_drain := adapter.call("drain_monster_production_receipts") as Dictionary
	_expect(
		bool(repeated_drain.get("accepted", false))
			and int(repeated_drain.get("committed_count", -1)) == 0
			and int(repeated_drain.get("duplicate_count", 0)) >= 1,
		"terminal Monster receipt replay is acknowledged without a second consequence"
	)
	_expect(
		_count_presentation_kind(production_events, "monster_moved") == 1
			and _count_presentation_kind(
				production_events, "monster_trample_resolved"
			) == 1,
		"receipt replay creates no duplicate movement or trample presentation"
	)
	var runtime_after_monster := runtime.call("debug_snapshot") as Dictionary
	_expect(int(runtime_after_monster.get("v075_production_monster_movement_writer_count", -1)) == 0, "V075 production Monster movement writer is retired")
	_expect(int(runtime_after_monster.get("v076_production_monster_movement_owner_count", 0)) == 1, "V076 production Monster movement Owner count is exactly one")
	_expect(int(runtime_after_monster.get("v076_production_monster_asset_quantity_count", -1)) == 0, "V076 production Monster Owner owns no asset quantity")
	var adapter_debug := adapter.call("debug_snapshot") as Dictionary
	_expect(not bool(adapter_debug.get("owns_tick", true)), "adapter owns no tick")
	_expect(not bool(adapter_debug.get("owns_asset_quantity", true)), "adapter owns no asset quantity")
	_expect(not bool(adapter_debug.get("owns_military_unit_state", true)), "adapter owns no military state")
	_expect(not bool(adapter_debug.get("owns_presentation", true)), "adapter owns no presentation")
	var direct_debug := direct.call("debug_snapshot") as Dictionary
	_expect(
		not bool(direct_debug.get("owns_presentation", true))
			and str(direct_debug.get("military_consequence_owner", ""))
				== "V075RuntimeOwner",
		"private input Owner hands consequences to the existing V075 presentation Owner"
	)
	var generic_receipt := (composition.call("debug_snapshot") as Dictionary).get("last_receipt", {}) as Dictionary
	_expect(str(generic_receipt.get("receipt_scope", "")) == "owner_private_redacted", "generic receipt stays redacted")
	_expect(private_receipts.size() >= 4, "owner-private channel receives both submission and settlement acknowledgements")
	var tick_before_restart := int(kernel.call("current_tick"))
	var root_count_before_restart := int((kernel.call("root_commands") as Array).size())
	var direct_before_restart := direct.call("debug_snapshot") as Dictionary
	var restarted := composition.call("_start_new_game", {
		"player_count": 4,
		"seed": 900626425,
		"map_seed": 900626425,
		"region_count": 16,
		"geography_complexity": "STANDARD",
		"land_ocean_profile": "BALANCED",
	}) as Dictionary
	_expect(
		not bool(restarted.get("accepted", true))
			and str(restarted.get("reason_code", ""))
				== "new_game_requires_idle_runtime",
		"active V075 new-game-only session rejects in-place restart before Kernel reconfiguration"
	)
	_expect(
		int(kernel.call("current_tick")) == tick_before_restart
			and int((kernel.call("root_commands") as Array).size())
				== root_count_before_restart,
		"rejected restart preserves the one Kernel tick and command ledger"
	)
	var direct_after_restart_rejection := direct.call("debug_snapshot") as Dictionary
	_expect(
		int(direct_after_restart_rejection.get("submission_count", -1))
			== int(direct_before_restart.get("submission_count", -2))
			and int(direct_after_restart_rejection.get("settlement_count", -1))
				== int(direct_before_restart.get("settlement_count", -2)),
		"rejected restart preserves the Input Owner exact-once ledgers"
	)
	composition.queue_free()
	if production_screen != null:
		production_screen.queue_free()
	await process_frame
	_finish()


func _install_assets(runtime: Node) -> Dictionary:
	var current := runtime.get("_asset_state") as Dictionary
	var player_ids := runtime.call("player_ids") as Array
	var initial_assets := {}
	for player_variant in player_ids:
		initial_assets[str(player_variant)] = {
			"life": 6, "energy": 6, "industry": 6,
			"technology": 6, "commerce": 6, "shipping": 6,
		}
	var state := AssetBatchCore.create_state(
		str(current.get("batch_id", "")),
		player_ids,
		current.get("submission_hidden_lead_order", []) as Array,
		initial_assets,
		{},
		int(current.get("opened_at_ms", 0)),
		int(current.get("gdp_milli_per_asset", 1000))
	)
	if state.is_empty():
		return {"accepted": false}
	runtime.set("_asset_state", state)
	runtime.call("_sync_asset_balances")
	return {"accepted": true}


func _install_enemy_facility(
	runtime: Node,
	actor_id: String,
	excluded_region_id: String = "",
	facility_id: String = "facility.v076.production.enemy",
	facility_owner_id: String = "player.ai.2",
	required_industry_id: String = ""
) -> Dictionary:
	var state := (runtime.get("_facility_state") as Dictionary).duplicate(true)
	var substate := PublicActionBatchCore.facility_substate(state)
	var slots := substate.get("facility_slots", {}) as Dictionary
	var slot_ids: Array[String] = []
	for value in slots.keys():
		slot_ids.append(str(value))
	slot_ids.sort()
	if slot_ids.is_empty():
		return {"accepted": false}
	var actor_source_region := str(runtime.call(
		"_v076_production_source_region_for_actor", actor_id
	))
	var selected_id := ""
	for slot_id in slot_ids:
		var candidate := slots.get(slot_id, {}) as Dictionary
		if (
			str(candidate.get("region_id", "")) != actor_source_region
			and str(candidate.get("region_id", "")) != excluded_region_id
			and (
				required_industry_id.is_empty()
				or str(candidate.get("industry_id", "")) == required_industry_id
			)
		):
			selected_id = slot_id
			break
	if selected_id.is_empty():
		return {"accepted": false}
	var selected := slots.get(selected_id, {}) as Dictionary
	var occupied := FacilityCore.build_occupied_slot(
		str(selected.get("region_id", "")),
		int(selected.get("region_revision", 0)),
		str(selected.get("facility_type", "")),
		str(selected.get("industry_id", "")),
		int(selected.get("slot_generation", 0)) + 1,
		facility_id,
		1,
		facility_owner_id,
		1,
		0,
		0,
		"dark"
	)
	var replacements: Array = []
	for slot_id in slot_ids:
		replacements.append(
			occupied.duplicate(true)
			if slot_id == selected_id
			else (slots.get(slot_id, {}) as Dictionary).duplicate(true)
		)
	var next_state := PublicActionBatchCore.replace_facility_slots(state, replacements)
	if next_state.is_empty():
		return {"accepted": false}
	runtime.set("_facility_state", next_state)
	runtime.call("_sync_facility_slots")
	return {
		"accepted": true,
		"region_id": str(selected.get("region_id", "")),
		"facility_id": str(occupied.get("facility_id", "")),
	}


func _install_military_card(runtime: Node, actor_id: String) -> Dictionary:
	var dbg := (runtime.get("_dbg_by_player") as Dictionary).get(actor_id) as RefCounted
	if dbg == null:
		return {"accepted": false}
	var color := "life"
	var spec := dbg.call(
		"standard_card_spec_for_active_profile",
		color,
		"military.planetary_defense_force",
		1
	) as Dictionary
	var save := dbg.call("to_save_data") as Dictionary
	var state := (save.get("state", {}) as Dictionary).duplicate(true)
	var sequence := int(state.get("next_instance_sequence", 0))
	var instance_id := "dbg.%s.%06d" % [actor_id, sequence]
	var card := spec.duplicate(true)
	card["instance_id"] = instance_id
	card["card_instance_id"] = instance_id
	card["card_definition_id"] = str(spec.get("definition_id", ""))
	card["locked"] = false
	var draw_pile := (state.get("draw_pile", []) as Array).duplicate(true)
	draw_pile.append_array((state.get("hand", []) as Array).duplicate(true))
	state["draw_pile"] = draw_pile
	state["hand"] = [card]
	state["next_instance_sequence"] = sequence + 1
	save["state"] = state
	save["document_section"] = DbgCore._document_save_section(state)
	save["state_fingerprint"] = DbgCore._fingerprint(state)
	save["core_fingerprint"] = DbgCore._core_fingerprint(state)
	var applied := dbg.call("apply_save_data", save) as Dictionary
	return {
		"accepted": bool(applied.get("applied", false)),
		"card_instance_id": instance_id,
		"primary_color": color,
		"cost": int(spec.get("primary_asset_cost", 0)),
	}


func _install_enemy_monster(
	runtime: Node,
	actor_id: String,
	excluded_region_id: String = ""
) -> Dictionary:
	var combat := runtime.get("_combat_owner") as Node
	if not is_instance_valid(combat):
		return {"accepted": false}
	var enemy_id := ""
	for player_variant in runtime.call("player_ids") as Array:
		if str(player_variant) != actor_id:
			enemy_id = str(player_variant)
			break
	var source_region := str(runtime.call(
		"_v076_production_source_region_for_actor", actor_id
	))
	var target_region := ""
	for region_variant in runtime.call("_runtime_region_ids") as Array:
		if (
			str(region_variant) != source_region
			and str(region_variant) != excluded_region_id
		):
			target_region = str(region_variant)
			break
	if enemy_id.is_empty() or target_region.is_empty():
		return {"accepted": false}
	var definition_id := CardDefinitions.standard_definition_id(
		"monster.spore_tide_emperor", "life", 4
	)
	var bound := combat.call("prebind_monster_card_action", {
		"request_id": "request.v076.production.monster.fixture",
		"card_instance_id": "card.v076.production.monster.fixture",
		"card_definition_id": definition_id,
		"owner_player_id": enemy_id,
		"monster_card_mode": "DEPLOY_NEW",
		"target_region_id": target_region,
		"target_source_instance_id": "",
		"expected_region_revision": int(runtime.call(
			"_facility_authority_revision"
		)),
	}) as Dictionary
	if not bool(bound.get("accepted", false)):
		return {"accepted": false, "reason": bound.get("reason_code", "")}
	var resolved := combat.call(
		"resolve_monster_card_action", bound.get("action", {}) as Dictionary
	) as Dictionary
	if not bool(resolved.get("accepted", false)):
		return {"accepted": false, "reason": resolved.get("reason_code", "")}
	var receipt := resolved.get("receipt", {}) as Dictionary
	return {
		"accepted": true,
		"source_instance_id": str(receipt.get("source_instance_id", "")),
		"region_id": target_region,
	}


func _first_region_option(options: Array, card_instance_id: String) -> Dictionary:
	for variant in options:
		var option := variant as Dictionary
		if str(option.get("card_instance_id", "")) == card_instance_id \
				and str(option.get("task_kind", "")) == "assault_region":
			return option.duplicate(true)
	return {}


func _first_monster_option(
	options: Array,
	card_instance_id: String,
	monster_source_instance_id: String
) -> Dictionary:
	for variant in options:
		var option := variant as Dictionary
		if str(option.get("card_instance_id", "")) == card_instance_id \
				and str(option.get("task_kind", "")) == "assault_monster" \
				and str(option.get("target_monster_source_instance_id", "")) \
					== monster_source_instance_id:
			return option.duplicate(true)
	return {}


func _public_monster(runtime: Node, source_instance_id: String) -> Dictionary:
	for row_variant in runtime.call("_v075_public_monsters") as Array:
		var row := row_variant as Dictionary
		if str(row.get("source_instance_id", "")) == source_instance_id:
			return row.duplicate(true)
	return {}


func _actor_assets(runtime: Node, actor_id: String) -> Dictionary:
	var players := (runtime.get("_asset_state") as Dictionary).get(
		"players", {}
	) as Dictionary
	return ((players.get(actor_id, {}) as Dictionary).get(
		"assets", {}
	) as Dictionary).duplicate(true)


func _asset_pip_model(screen: Node, color_id: String) -> Dictionary:
	if screen == null:
		return {}
	var group := screen.find_child("AssetPips_%s" % color_id, true, false)
	if group == null:
		return {}
	var model: Variant = group.get_meta("asset_pip_model", {})
	return (model as Dictionary).duplicate(true) if model is Dictionary else {}


func _count_presentation_kind(receipts: Array, kind: String) -> int:
	var count := 0
	for receipt_variant in receipts:
		if str((receipt_variant as Dictionary).get("event_kind", "")) == kind:
			count += 1
	return count


func _first_presentation_kind(receipts: Array, kind: String) -> Dictionary:
	for receipt_variant in receipts:
		var receipt := receipt_variant as Dictionary
		if str(receipt.get("event_kind", "")) == kind:
			return receipt.duplicate(true)
	return {}


func _presentation_damage(receipts: Array, kind: String) -> int:
	for receipt_variant in receipts:
		var receipt := receipt_variant as Dictionary
		if str(receipt.get("event_kind", "")) == kind:
			return int(receipt.get("damage_amount", 0))
	return 0


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("V076 PRODUCTION MILITARY COMPOSITION: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		(
			"V076_PRODUCTION_MILITARY_COMPOSITION|status=%s|passed=%d|total=%d"
			+ "|production_scene_path=scenes/main.tscn|atomic_cutover=true"
			+ "|public_batch_entry_count=0|shared_sushi_track_resolution_count=0"
			+ "|production_green=false|human_green=false|details=%s"
		) % [status, _checks - _failures.size(), _checks, JSON.stringify(_failures)]
	)
	quit(0 if _failures.is_empty() else 1)

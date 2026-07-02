extends SceneTree

const CAMPAIGN_SCRIPT := preload("res://scripts/campaign/campaign_definition.gd")
const RECOMMEND_SCRIPT := preload("res://scripts/recommendations/recommended_start_service.gd")

const EXPECTED_CHAPTER_IDS := [
	"00_tavern_entry",
	"01_first_table",
	"02_market_hand",
	"03_public_track",
	"04_bid_practice",
	"05_monster_pressure",
	"06_contract_goods",
	"07_intel_guess",
	"08_final_countdown",
	"09_graduation_match",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_docs()
	_check_campaign_contract()
	_check_recommendations()
	_check_main_hooks()
	_finish()


func _check_docs() -> void:
	for path in [
		"res://docs/player_journey_spec.md",
		"res://docs/tutorial_campaign_spec.md",
		"res://docs/scenario_reward_spec.md",
		"res://docs/player_onboarding_scorecard.md",
		"res://docs/menu_commercial_shell_spec.md",
	]:
		_expect(FileAccess.file_exists(path), "%s exists" % path)
	var journey := FileAccess.get_file_as_string("res://docs/player_journey_spec.md")
	for marker in ["00:00", "01:00", "12:00", "15:00", "奖励", "复盘"]:
		_expect(journey.contains(marker), "player journey spec contains %s" % marker)


func _check_campaign_contract() -> void:
	var campaign: Dictionary = CAMPAIGN_SCRIPT.new().load_by_id("tutorial_campaign")
	var chapters: Array = campaign.get("chapters", []) if campaign.get("chapters", []) is Array else []
	_expect(chapters.size() >= EXPECTED_CHAPTER_IDS.size(), "campaign includes the 30-minute chapter chain")
	for i in range(EXPECTED_CHAPTER_IDS.size()):
		_expect(i < chapters.size() and str((chapters[i] as Dictionary).get("id", "")) == EXPECTED_CHAPTER_IDS[i], "campaign chapter order %d is %s" % [i, EXPECTED_CHAPTER_IDS[i]])


func _check_recommendations() -> void:
	var data: Dictionary = RECOMMEND_SCRIPT.new().load_recommendations()
	_expect(int(data.get("player_count", 0)) == 4 and int(data.get("ai_count", 0)) == 3, "tutorial recommendation is 4 seats / 3 AI")
	_expect((data.get("presets", []) as Array).size() >= 3, "quick start has at least 3 presets")


func _check_main_hooks() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	for needle in [
		"CampaignMenuScene",
		"_open_campaign_menu",
		"_open_campaign_briefing_menu",
		"_open_campaign_reward_menu",
		"_open_campaign_recap_menu",
		"_open_campaign_settings_menu",
		"新手战役",
		"快速开局",
		"资料库",
		"重开本关",
		"返回战役",
		"查看复盘",
		"animation_intensity",
		"font_scale_label",
		"ui_volume",
	]:
		_expect(main_source.contains(needle), "main hook contains %s" % needle)
	for path in [
		"res://scenes/ui/CampaignMenu.tscn",
		"res://scenes/ui/CampaignBriefing.tscn",
		"res://scenes/ui/CampaignRewardPanel.tscn",
		"res://scenes/ui/CampaignProgressMap.tscn",
		"res://scenes/ui/MatchRecapPanel.tscn",
		"res://tests/campaign_runtime_flow_test.gd",
		"res://tests/campaign_snapshot_capture.gd",
	]:
		_expect(FileAccess.file_exists(path), "%s exists" % path)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Player journey 30-minute test passed.")
	else:
		push_error("Player journey 30-minute test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())

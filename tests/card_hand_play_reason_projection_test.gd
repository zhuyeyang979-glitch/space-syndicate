extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/CardPresentationRuntimeService.tscn"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SERVICE_SCENE) as PackedScene
	var service := packed.instantiate() as CardPresentationRuntimeService if packed != null else null
	_expect(service != null, "card presentation service loads")
	if service == null:
		_finish()
		return
	var source := {
		"slot": 2,
		"card": {
			"category_id": "facility",
			"display_name": "测试设施",
			"skill": {
				"name": "facility.test.rank_1",
				"card_id": "facility.test.rank_1",
				"kind": "public_facility",
				"facility_kind": "factory",
				"industry_id": "technology",
			},
		},
		"eligibility": {
			"allowed": false,
			"actionable": false,
			"reason_code": "public_facility_product_unavailable",
		},
	}
	var hand := service.compose_hand_card(source)
	_expect(str(hand.get("play_reason_id", "")) == "public_facility_product_unavailable", "hand DTO carries the stable eligibility reason id")
	_expect(str(hand.get("kind", "")) == "facility_v06" and not bool(hand.get("actionable", true)), "reason projection does not change facility kind or legal action state")
	_expect(str(hand.get("facility_kind", "")) == "factory" and str(hand.get("industry_id", "")) == "technology", "authorized private facility DTO retains typed target semantics without exposing its raw card payload")
	_expect(str(hand.get("card_id", "")) == "facility.test.rank_1" and not hand.has("runtime_instance_id"), "authorized private facility DTO retains canonical card identity without exposing a runtime instance ID")
	_expect(not hand.has("reason_args") and not hand.has("eligibility") and not hand.has("skill"), "hand DTO does not expose the raw eligibility or card payload")
	var forged := source.duplicate(true)
	(forged["eligibility"] as Dictionary)["reason_code"] = "中文提示 不是稳定ID"
	_expect(str(service.compose_hand_card(forged).get("play_reason_id", "")) == "invalid_payload", "localized or free-form reason text fails closed")
	(forged["eligibility"] as Dictionary)["reason_code"] = "private_plan"
	_expect(str(service.compose_hand_card(forged).get("play_reason_id", "")) == "invalid_payload", "unknown ASCII tokens cannot become stable hand-play reason ids")
	service.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("CARD_HAND_PLAY_REASON_PROJECTION|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	for failure in _failures:
		push_error(failure)
	quit(_failures.size())

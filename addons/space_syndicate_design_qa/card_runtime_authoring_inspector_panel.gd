@tool
extends PanelContainer

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v04.tres"
const AUTHORING_BENCH_PATH := "res://scenes/tools/RuntimeCardAuthoringWorkflowBench.tscn"

@onready var target_label: Label = %AuthoringTargetLabel
@onready var status_label: Label = %AuthoringStatusLabel
@onready var validate_button: Button = %ValidateAuthoringTargetButton
@onready var capture_button: Button = %CaptureCardBaselineButton
@onready var review_button: Button = %BuildCardChangeReviewButton
@onready var qa_button: Button = %RunCardAuthoringQaButton
@onready var catalog_button: Button = %OpenCardAuthoringCatalogButton
@onready var output_button: Button = %OpenCardAuthoringOutputButton

var _target: Resource
var _host_plugin: EditorPlugin
var _service := CardRuntimeAuthoringService.new()


func configure(target: Resource, host_plugin: EditorPlugin) -> void:
	_target = target
	_host_plugin = host_plugin
	_service.configure()
	if is_node_ready():
		_refresh_target()


func _ready() -> void:
	_connect_button(validate_button, "_on_validate_pressed")
	_connect_button(capture_button, "_on_capture_baseline_pressed")
	_connect_button(review_button, "_on_build_review_pressed")
	_connect_button(qa_button, "_on_run_qa_pressed")
	_connect_button(catalog_button, "_on_open_catalog_pressed")
	_connect_button(output_button, "_on_open_output_pressed")
	_refresh_target()


func _refresh_target() -> void:
	if target_label == null:
		return
	var identity := _target_identity()
	target_label.text = "%s | %s" % [str(identity.get("kind", "Resource")), str(identity.get("id", "unselected"))]
	status_label.text = "Ready for Inspector validation and change review."


func _on_validate_pressed() -> void:
	var report := _service.validate_target(_target)
	status_label.text = "VALID | %d checks | %d warnings" % [(report.get("checks", []) as Array).size(), int(report.get("warning_count", 0))] if bool(report.get("valid", false)) else "BLOCKED | %d errors | %d warnings" % [int(report.get("error_count", 0)), int(report.get("warning_count", 0))]
	print("Card authoring validation: %s" % JSON.stringify(report))


func _on_capture_baseline_pressed() -> void:
	var result := _service.capture_baseline()
	status_label.text = "Baseline captured: %s" % str(result.get("path", "failed")) if bool(result.get("captured", false)) else "Baseline failed: %s" % str(result.get("error", "unknown"))
	print("Card authoring baseline: %s" % JSON.stringify(result))


func _on_build_review_pressed() -> void:
	var review := _service.build_change_review(true)
	status_label.text = "Review %s | changed %d | added %d | removed %d" % [str(review.get("review_status", "unknown")), int(review.get("changed_count", 0)), int(review.get("added_count", 0)), int(review.get("removed_count", 0))]
	print("Card authoring review JSON: %s" % str(review.get("review_json_path", "")))
	print("Card authoring review Markdown: %s" % str(review.get("review_markdown_path", "")))


func _on_run_qa_pressed() -> void:
	if _host_plugin != null and _host_plugin.has_method("run_scene"):
		_host_plugin.call("run_scene", AUTHORING_BENCH_PATH)
	status_label.text = "Running card authoring QA."


func _on_open_catalog_pressed() -> void:
	if _host_plugin != null and _host_plugin.has_method("open_resource"):
		_host_plugin.call("open_resource", CATALOG_PATH)
	status_label.text = "Opened authoritative Runtime Card Catalog."


func _on_open_output_pressed() -> void:
	var absolute_path := ProjectSettings.globalize_path(_service.output_dir())
	var error := OS.shell_open(absolute_path)
	status_label.text = "Opened authoring output." if error == OK else "Authoring output: %s" % _service.output_dir()


func _target_identity() -> Dictionary:
	if _target is CardRuntimeCatalogResource:
		return {"kind": "Catalog", "id": (_target as CardRuntimeCatalogResource).catalog_version}
	if _target is CardRuntimePackResource:
		return {"kind": "Pack", "id": str((_target as CardRuntimePackResource).pack_id)}
	if _target is CardRuntimeFamilyResource:
		return {"kind": "Family", "id": (_target as CardRuntimeFamilyResource).family_id}
	if _target is CardRuntimeRankResource:
		return {"kind": "Card", "id": (_target as CardRuntimeRankResource).card_id}
	return {"kind": "Resource", "id": _target.resource_path if _target != null else "unselected"}


func _connect_button(button: Button, method_name: String) -> void:
	if button == null:
		return
	var callback := Callable(self, method_name)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)

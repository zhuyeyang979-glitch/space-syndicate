extends Resource
class_name PlayerTextCatalogEntryResource

@export var message_key: String = ""
@export_enum(
	"machine_identifier",
	"developer_diagnostic",
	"translator_metadata",
	"player_visible",
	"player_assistive",
	"player_generated"
) var audience: String = "player_visible"
@export var surface: String = "label"
@export var owner: String = ""
@export var translation_context: String = "player_text_v05"
@export_multiline var translator_note: String = ""
@export_range(1, 4096, 1) var character_budget: int = 80
@export var argument_types: Dictionary = {}
@export var assistive_message_key: String = ""


func to_snapshot() -> Dictionary:
	return {
		"message_key": message_key,
		"audience": audience,
		"surface": surface,
		"owner": owner,
		"translation_context": translation_context,
		"translator_note": translator_note,
		"character_budget": character_budget,
		"argument_types": argument_types.duplicate(true),
		"assistive_message_key": assistive_message_key,
	}

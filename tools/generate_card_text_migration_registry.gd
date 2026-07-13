extends SceneTree

const Builder := preload("res://scripts/tools/card_text_migration_registry_builder.gd")


func _init() -> void:
	var result := Builder.write_registry()
	print("CardTextMigrationRegistryBuilder: %s" % JSON.stringify(result))
	quit(0 if bool(result.get("written", false)) else 1)

extends RefCounted
class_name PlayerGeneratedTextSanitizerV05

const DEFAULT_MAX_LENGTH := 32


static func sanitize(value: String, max_length: int = DEFAULT_MAX_LENGTH) -> Dictionary:
	var bounded_length := clampi(max_length, 1, 256)
	var cleaned := ""
	var last_was_space := false
	for character in value:
		var codepoint := character.unicode_at(0)
		if codepoint < 32 or codepoint == 127:
			continue
		var output_character := character
		match character:
			"[":
				output_character = "［"
			"]":
				output_character = "］"
			"<":
				output_character = "＜"
			">":
				output_character = "＞"
		var is_space := output_character == " " or output_character == "\t" or output_character == "\n" or output_character == "\r"
		if is_space:
			if last_was_space or cleaned.is_empty():
				continue
			cleaned += " "
			last_was_space = true
		else:
			cleaned += output_character
			last_was_space = false
	cleaned = cleaned.strip_edges()
	var truncated := cleaned.length() > bounded_length
	if truncated:
		cleaned = cleaned.left(bounded_length).strip_edges()
	return {
		"valid": not cleaned.is_empty(),
		"sanitized_text": cleaned,
		"truncated": truncated,
		"original_length": value.length(),
		"sanitized_length": cleaned.length(),
		"max_length": bounded_length,
		"reason": "" if not cleaned.is_empty() else "player_generated_text_empty",
	}

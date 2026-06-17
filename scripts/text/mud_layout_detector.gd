extends RefCounted

const BOX_DRAWING_START: int = 0x2500
const BOX_DRAWING_END: int = 0x257F
const BLOCK_ELEMENTS_START: int = 0x2580
const BLOCK_ELEMENTS_END: int = 0x259F
const PRIVATE_USE_START: int = 0xE000
const PRIVATE_USE_END: int = 0xF8FF

const TOP_LEFT: int = 0x250C
const TOP_RIGHT: int = 0x2510
const BOTTOM_LEFT: int = 0x2514
const BOTTOM_RIGHT: int = 0x2518
const LEFT_TEE: int = 0x251C
const RIGHT_TEE: int = 0x2524
const VERTICAL: int = 0x2502


func visible_prefix(bb_chunk: String, count: int = 30) -> String:
	var output: String = ""
	var in_tag: bool = false
	for index: int in range(bb_chunk.length()):
		var character: String = bb_chunk.substr(index, 1)
		if character == "[":
			in_tag = true
			continue
		elif character == "]":
			in_tag = false
			continue
		if in_tag:
			continue
		output += character
		if output.length() >= count:
			break
	return output.strip_edges()


func line_map_slice_indices(bb_line: String) -> Array[int]:
	var left: int = -1
	var right: int = -1
	var in_tag: bool = false
	for index: int in range(bb_line.length()):
		var character: String = bb_line.substr(index, 1)
		if character == "[":
			in_tag = true
			continue
		elif character == "]":
			in_tag = false
			continue
		if in_tag:
			continue

		var codepoint: int = bb_line.unicode_at(index)
		if left == -1 and _is_left_border_codepoint(codepoint):
			left = index
		if _is_right_border_codepoint(codepoint):
			right = index

	if left == -1 or right == -1 or right < left:
		var empty_result: Array[int] = []
		return empty_result
	return [left, right] as Array[int]


func has_bottom_ignoring_tags(bb_line: String) -> bool:
	var in_tag: bool = false
	for index: int in range(bb_line.length()):
		var character: String = bb_line.substr(index, 1)
		if character == "[":
			in_tag = true
			continue
		elif character == "]":
			in_tag = false
			continue
		if in_tag:
			continue
		if bb_line.unicode_at(index) == BOTTOM_LEFT:
			return true
	return false


func contains_box_art(bb_line: String) -> bool:
	var in_tag: bool = false
	for index: int in range(bb_line.length()):
		var character: String = bb_line.substr(index, 1)
		if character == "[":
			in_tag = true
			continue
		elif character == "]":
			in_tag = false
			continue
		if in_tag:
			continue
		if is_box_art_codepoint(bb_line.unicode_at(index)):
			return true
	return false


func color_prefix_before_index(line: String, upto: int) -> Dictionary:
	var stack: Array[String] = []
	var in_tag: bool = false
	var tag: String = ""
	for index: int in range(min(upto, line.length())):
		var character: String = line.substr(index, 1)
		if not in_tag:
			if character == "[":
				in_tag = true
				tag = ""
			continue
		if character == "]":
			var trimmed_tag: String = tag.strip_edges()
			if trimmed_tag == "/color":
				if stack.size() > 0:
					stack.pop_back()
			elif trimmed_tag.begins_with("color"):
				stack.append("[" + trimmed_tag + "]")
			in_tag = false
		else:
			tag += character

	var prefix: String = ""
	for tag_text: String in stack:
		prefix += tag_text
	return {"prefix": prefix, "stack": stack}


func update_color_stack_with_text(stack: Array, text: String) -> void:
	var in_tag: bool = false
	var tag: String = ""
	for index: int in range(text.length()):
		var character: String = text.substr(index, 1)
		if not in_tag:
			if character == "[":
				in_tag = true
				tag = ""
			continue
		if character == "]":
			var trimmed_tag: String = tag.strip_edges()
			if trimmed_tag == "/color":
				if stack.size() > 0:
					stack.pop_back()
			elif trimmed_tag.begins_with("color"):
				stack.append("[" + trimmed_tag + "]")
			in_tag = false
		else:
			tag += character


func closing_for_stack(stack: Array) -> String:
	var output: String = ""
	for index: int in range(stack.size() - 1, -1, -1):
		if String(stack[index]).begins_with("[color"):
			output += "[/color]"
	return output


func is_box_art_codepoint(codepoint: int) -> bool:
	return (
		(codepoint >= BOX_DRAWING_START and codepoint <= BOX_DRAWING_END)
		or (codepoint >= BLOCK_ELEMENTS_START and codepoint <= BLOCK_ELEMENTS_END)
		or (codepoint >= PRIVATE_USE_START and codepoint <= PRIVATE_USE_END)
		or codepoint == 0xFFFD
	)


func _is_left_border_codepoint(codepoint: int) -> bool:
	return codepoint == TOP_LEFT or codepoint == LEFT_TEE or codepoint == BOTTOM_LEFT


func _is_right_border_codepoint(codepoint: int) -> bool:
	return codepoint == TOP_RIGHT or codepoint == RIGHT_TEE or codepoint == BOTTOM_RIGHT

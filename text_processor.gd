class_name TextProcessor
extends Node2D

signal bb_data(text: String)
signal location_name(text: String)
signal status_text(text: String)
signal mobs_text(text: String)
signal exits_text(text: String)
signal container_request(data: String, container_type: String)
signal npc_look_description(data: Dictionary)

const AnsiParser := preload("res://scripts/text/ansi_parser.gd")
const MudLayoutDetector := preload("res://scripts/text/mud_layout_detector.gd")


var _in_map := false
var _cur_map: Array = []
var _first_msg := true
var _backpack_prohibit = false
var _ansi_parser: RefCounted = AnsiParser.new()
var _layout_detector: RefCounted = MudLayoutDetector.new()

# remember first line + left index to compute prefix
var _first_line_raw := ""
var _first_left_idx := 0

func _ready() -> void:
	var display: RichTextLabel = $TextDisplay
	# UI setup
	display.bbcode_enabled = true
	if display.has_method("set_scroll_following"):
		display.set_scroll_following(true)   # Godot 4.x keeps scrolled to bottom
	set_process(true)


func reset_session(clear_display: bool = true) -> void:
	_in_map = false
	_cur_map.clear()
	_first_msg = true
	_backpack_prohibit = false
	_first_line_raw = ""
	_first_left_idx = 0
	if clear_display and has_node("TextDisplay"):
		$TextDisplay.clear()

func update_lines(input: String) -> void:
	var parsed_data: Array[Dictionary] = parse_ansi_colored_text(input)
	_data_to_bb(parsed_data)

func _update_one_line(input: String) -> void:
	$TextDisplay.append_text("\n Sent: " + input + "\n")
	
	
func parse_ansi_colored_text(input: String) -> Array[Dictionary]:
	return _ansi_parser.parse(input)

	
func _data_to_bb(data: Array) -> void:
	var out := ""
	var cur = ""
	var buf := ""
	for seg in data:
		var t: String = seg.get("text", "")
		var c: String = seg.get("color", "")
		if c != cur:
			if buf != "":
				out += _wrap_color(cur, buf)
				buf = ""
			cur = c
		buf += t
	if buf != "":
		out += _wrap_color(cur, buf)
	_process_one_bb_line(out)

func _wrap_color(c: String, text: String) -> String:
	var safe := _bb_escape(text)
	if c == "" or c == null:
		return safe
	return "[color=%s]%s[/color]" % [c, safe]

static func _bb_escape(t: String) -> String:
	# Do NOT escape backslashes here.
	t = t.replace("\r","")
	t = t.replace("[", "(")
	t = t.replace("]", ")")
	return t

func _normalize_spaces(s: String) -> String:
	var re := RegEx.new()
	re.compile("[ \t]+")
	return re.sub(s.strip_edges(), " ", true)

func _visible_prefix(bb_chunk: String, n: int = 30) -> String:
	return _layout_detector.visible_prefix(bb_chunk, n)
	
func _process_one_bb_line(bb_chunk: String) -> void:
	var descs: Array = []

	for raw_line in bb_chunk.split("\n", false):
		var line := raw_line.rstrip("\r")
		var pair := _line_map_slice_indices(line)

		if pair.is_empty():
			# pure description line
			descs.append(line)
			# don't return; keep processing the rest of the chunk
			continue

		# Map is GMCP-driven now. Legacy text map extraction is too broad and
		# can steal boxed shop/list ASCII tables away from the main log.
		descs.append(line)
		continue

		var left: int = pair[0]
		var right: int = pair[1]
		var slice := line.substr(left, right - left + 1)
		var desc := line.substr(0, left)

		if not _is_probable_map_slice(slice):
			descs.append(line)
			continue

		if desc.length() > 0:
			descs.append(desc)

		if not _in_map:
			_in_map = true
			_first_line_raw = line
			_first_left_idx = left
			_cur_map.clear()

		_cur_map.append(slice)

		if _has_bottom_ignoring_tags(slice):
			# Build balanced, colored final string for the map block
			var prefix_info := _color_prefix_before_index(_first_line_raw, _first_left_idx)
			var joined := "\n".join(_cur_map)
			var stack: Array = prefix_info.stack.duplicate()
			_update_color_stack_with_text(stack, joined)
			var final = prefix_info.prefix + joined + _closing_for_stack(stack)
			bb_data.emit(final)
			_cur_map.clear()
			_in_map = false

	# After processing all lines in the chunk, append descriptions once
	var descs_size = descs.size()
	#print("Desc size = ", descs_size)
	#print("Start to process desc.....")
	
	var text = ""
	
	# one line message
	if descs_size == 1:
		#print("------------------------------")
		#print("One line desc: ", descs)
		#print("------------------------------")
		if _visible_prefix(descs[0], 1) == "(":
			# status text
			status_text.emit(str(descs[0]))
			return
		elif _visible_prefix(descs[0], 100) in ["TEXTMASK:false", "TEXTMASK:true"]:
			return
		else:
			if _append_box_table_if_needed(descs, bb_chunk):
				return
			$TextDisplay.append_text(bb_chunk)
	
	# two line message
	if descs_size == 2:
		#print("------------------------------")
		#print("Two line desc: ", descs)
		#print("------------------------------")
		if _visible_prefix(descs[0], 5) == "Exits":
			# exits
			exits_text.emit(bb_chunk)
			return
		elif _visible_prefix(descs[0], 9) == "Also here":
			mobs_text.emit(descs[0])
		else:
			if _append_box_table_if_needed(descs, bb_chunk):
				return
			$TextDisplay.append_text(bb_chunk)
			return
			
	# big message
	if descs_size > 2:
		#print("Large desc ---------------")
		if _first_msg:
			if not _append_box_table_if_needed(descs, bb_chunk):
				$TextDisplay.append_text(bb_chunk)
			_first_msg = false
			return

		# --- Step 1: Trim each line and remove empties ---
		for i in range(descs_size):
			descs[i] = descs[i].strip_edges()
			#print("Desc appended ", i, " : ", descs[i])

		# --- Step 2: Join with newlines instead of spaces ---
		text = " ".join(descs)

		# --- Step 3: Collapse multiple spaces within lines only ---
		var re_space := RegEx.new()
		re_space.compile(" {2,}")  # 2 or more spaces
		text = re_space.sub(text, " ", true)
		text = text.strip_edges()
		
		var l0_prefix_100 = _visible_prefix(descs[0], 100)
		var l1_prefix_100 = _visible_prefix(descs[1], 100)
		var _l2_prefix_100 = _visible_prefix(descs[2], 100)
		#print("------------------------------")
		#print("L0 Prefix: ", l0_prefix_100)
		#print("L1 Prefix: ", l1_prefix_100)
		#print("L2 Prefix: ", l2_prefix_100)
		#print("------------------------------")
		
		if l1_prefix_100.begins_with(".: ("):
			# location name
			location_name.emit(bb_chunk)
			mobs_text.emit("")
			$TextDisplay.append_text(bb_chunk)
		
		elif text.contains("Info") and text.contains("Attributes"):
			# status table legacy route; GMCP status is preferred.
			container_request.emit(bb_chunk, "status")
			_backpack_prohibit = true
			
		elif l0_prefix_100.contains("Equipment"):
			# equipment/backpack legacy route; GMCP is preferred.
			if not _backpack_prohibit:
				container_request.emit(bb_chunk, "equipment")
			else:
				_backpack_prohibit = false
		
		elif text.contains("Skills"):
			container_request.emit(bb_chunk, "skills")
		
		elif l0_prefix_100.contains(".: Spells") or text.contains(".: Spells"):
			container_request.emit(bb_chunk, "spells")
				
		elif text.contains("Name") and text.contains("Level") and text.contains("Alignment") and text.contains("Profession"):
			$TextDisplay.append_text(bb_chunk)
		
		elif l1_prefix_100 == ".: Pets by Rodric":
			$TextDisplay.append_text(bb_chunk)
			
		elif _is_npc_look_description(descs, text):
			npc_look_description.emit(_npc_look_description_data(descs, text))
			
		else:
			if not _append_box_table_if_needed(descs, bb_chunk):
				$TextDisplay.append_text(_clean_general_text_for_display(bb_chunk))
		
# ---------------- helpers ----------------
func _line_map_slice_indices(bb_line: String) -> Array:
	return _layout_detector.line_map_slice_indices(bb_line)

func _has_bottom_ignoring_tags(bb_line: String) -> bool:
	return _layout_detector.has_bottom_ignoring_tags(bb_line)

# Parse opening color tags active BEFORE column `upto`
func _color_prefix_before_index(line: String, upto: int) -> Dictionary:
	return _layout_detector.color_prefix_before_index(line, upto)

# Update color stack by scanning BBCode in `text`
func _update_color_stack_with_text(stack: Array, text: String) -> void:
	_layout_detector.update_color_stack_with_text(stack, text)

func _closing_for_stack(stack: Array) -> String:
	return _layout_detector.closing_for_stack(stack)


func _is_npc_look_description(_descs: Array, joined_text: String) -> bool:
	var npc_look_visible: String = _strip_bbcode(joined_text)
	if not npc_look_visible.to_lower().contains("description"):
		return false
	var health_re := RegEx.new()
	health_re.compile("(?i)\\b.+\\s+is\\s+in\\s+.+\\s+health\\b")
	return health_re.search(npc_look_visible) != null


func _npc_look_description_data(descs: Array, joined_text: String) -> Dictionary:
	var visible_lines: Array[String] = []
	for desc: Variant in descs:
		var clean_line: String = _clean_npc_look_line(str(desc))
		if clean_line != "" and not _is_decorative_box_line(clean_line):
			visible_lines.append(clean_line)
	var visible_text: String = _normalize_spaces(" ".join(visible_lines))
	var description: String = _clean_npc_description_text(visible_text)
	var npc_name: String = _extract_npc_name_from_description(visible_text)
	return {
		"name": npc_name,
		"description": description,
		"raw": joined_text,
	}


func _clean_npc_description_text(visible_text: String) -> String:
	var text: String = _remove_mud_box_art(visible_text)
	text = text.replace("Description", " ")
	text = text.replace(".:Description", " ")
	text = text.replace(".:", " ")
	var health_re := RegEx.new()
	health_re.compile("(?i)\\b[^.\\n]+\\s+is\\s+in\\s+[^.\\n]+\\s+health\\.?")
	text = health_re.sub(text, " ", true)
	return _normalize_spaces(text)


func _extract_npc_name_from_description(visible_text: String) -> String:
	var health_re := RegEx.new()
	health_re.compile("(?i)\\b([A-Za-z][A-Za-z0-9 '\\-]*)\\s+is\\s+in\\s+[^.\\n]+\\s+health\\b")
	var match: RegExMatch = health_re.search(visible_text)
	if match == null:
		return ""
	return match.get_string(1).strip_edges()


func _strip_bbcode(data: String) -> String:
	var re := RegEx.new()
	re.compile("\\[[^\\]]+\\]")
	return re.sub(data, "", true)


func _clean_npc_look_line(line: String) -> String:
	var clean_line: String = _remove_mud_box_art(_strip_bbcode(line))
	clean_line = clean_line.replace(".:Description", " Description ")
	clean_line = clean_line.replace("Description", " Description ")
	return _normalize_spaces(clean_line)


func _remove_mud_box_art(text: String) -> String:
	var output: String = ""
	for index: int in range(text.length()):
		var codepoint: int = text.unicode_at(index)
		var character: String = text.substr(index, 1)
		if _is_box_art_codepoint(codepoint):
			output += " "
			continue
		if character in ["|", "+"]:
			output += " "
			continue
		output += character
	return output


func _is_box_art_codepoint(codepoint: int) -> bool:
	return _layout_detector.is_box_art_codepoint(codepoint)


func _is_decorative_box_line(line: String) -> bool:
	var text: String = line.strip_edges()
	if text == "":
		return true
	var re := RegEx.new()
	re.compile("^[\\s_\\-=:\\.,'`~]+$")
	return re.search(text) != null


func _append_box_table_if_needed(descs: Array, original_chunk: String) -> bool:
	if not _descs_contain_box_art(descs):
		return false

	$TextDisplay.append_text(original_chunk)
	if not original_chunk.ends_with("\n"):
		$TextDisplay.append_text("\n")
	return true


func _descs_contain_box_art(descs: Array) -> bool:
	for desc: Variant in descs:
		if _layout_detector.contains_box_art(str(desc)):
			return true
	return false


func _clean_main_text_table_line(line: String) -> String:
	var clean_line: String = _remove_mud_box_art(_strip_bbcode(line))
	clean_line = clean_line.replace(".:", " ")
	return _normalize_spaces(clean_line)


func _clean_general_text_for_display(bb_chunk: String) -> String:
	var lines: PackedStringArray = bb_chunk.split("\n")
	var kept: Array[String] = []
	for line: String in lines:
		var vis: String = _strip_bbcode(line).strip_edges()
		if vis.length() == 0:
			kept.append(line)
			continue
		var has_alnum: bool = false
		for i: int in range(vis.length()):
			var cp: int = vis.unicode_at(i)
			if (cp >= 48 and cp <= 57) or (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122):
				has_alnum = true
				break
		if has_alnum:
			kept.append(line)
	if kept.is_empty():
		return ""
	var result: String = "\n".join(kept)
	if not result.ends_with("\n"):
		result += "\n"
	return result


func _is_probable_map_slice(slice: String) -> bool:
	var stripped: String = _strip_bbcode(slice)
	var clean_slice: String = _remove_mud_box_art(stripped)
	var normalized: String = _normalize_spaces(clean_slice)
	if normalized == "":
		return true

	if normalized.contains("|"):
		return false

	var alnum_count: int = 0
	for index: int in range(normalized.length()):
		var codepoint: int = normalized.unicode_at(index)
		if (codepoint >= 48 and codepoint <= 57) or (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122):
			alnum_count += 1

	return alnum_count <= 2

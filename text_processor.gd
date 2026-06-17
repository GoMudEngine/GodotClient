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

const _LEFT_CHARS  := {"╔": true, "║": true, "╚": true}
const _RIGHT_CHARS := {"╗": true, "║": true, "╝": true}

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

func _update_lines(input: String) -> void:
	var parsed_data: Array[Dictionary] = parse_ansi_colored_text(input)
	_data_to_bb(parsed_data)

func _update_one_line(input: String) -> void:
	$TextDisplay.append_text("\n Sent: " + input + "\n")
	
# ANSI 8-bit color mapping (you can customize this table)
const ANSI_COLORS := {
	"0": "#AAAAAA",  # reset / default gray

	# Standard colors
	"30": "#000000",  # black
	"31": "#800000",  # red
	"32": "#008000",  # green
	"33": "#808000",  # yellow
	"34": "#000080",  # blue
	"35": "#800080",  # magenta
	"36": "#008080",  # cyan
	"37": "#C0C0C0",  # white

	# Bright colors (90–97)
	"90": "#808080",  # bright black (gray)
	"91": "#FF0000",  # bright red
	"92": "#00FF00",  # bright green
	"93": "#FFFF00",  # bright yellow
	"94": "#0000FF",  # bright blue
	"95": "#FF00FF",  # bright magenta
	"96": "#00FFFF",  # bright cyan
	"97": "#FFFFFF",  # bright white

	# Common composite styles
	"1;30": "#555555",  # bold black
	"1;31": "#FF5555",
	"1;32": "#55FF55",
	"1;33": "#FFFF55",
	"1;34": "#5555FF",
	"1;35": "#FF55FF",
	"1;36": "#55FFFF",
	"1;37": "#FFFFFF",

	# Other useful combos
	"1;90": "#AAAAAA",
	"1;91": "#FF8888",
	"1;92": "#88FF88",
	"1;93": "#FFFF88",
	"1;94": "#8888FF",
	"1;95": "#FF88FF",
	"1;96": "#88FFFF",
	"1;97": "#FFFFFF"
}

func _xterm256_to_hex(idx: int) -> String:
	idx = clamp(idx, 0, 255)
	var base16 := [
		"#000000","#800000","#008000","#808000",
		"#000080","#800080","#008080","#C0C0C0",
		"#808080","#FF0000","#00FF00","#FFFF00",
		"#0000FF","#FF00FF","#00FFFF","#FFFFFF"
	]
	if idx < 16:
		return base16[idx]
	if idx <= 231:
		var n := idx - 16
		var steps := PackedInt32Array([0,95,135,175,215,255])
		var r = steps[n / 36]
		var g = steps[(n / 6) % 6]
		var b = steps[n % 6]
		return "#%02X%02X%02X" % [r, g, b]
	var v = clamp(8 + 10 * (idx - 232), 0, 255)  # grayscale 232..255
	return "#%02X%02X%02X" % [v, v, v]
	
func _resolve_fg_from_codes(code_str: String, fallback: String) -> String:
	# Exact table hit first (handles common "1;31" etc.)
	if ANSI_COLORS.has(code_str):
		return ANSI_COLORS[code_str]

	var parts := code_str.split(";")
	if parts.is_empty():
		return ""

	var fg := fallback
	var changed := false
	var i := 0
	while i < parts.size():
		var c := int(parts[i])

		# 16-color sets
		if c >= 30 and c <= 37:
			fg = _xterm256_to_hex(c - 30); changed = true
		elif c >= 90 and c <= 97:
			fg = _xterm256_to_hex(8 + (c - 90)); changed = true

		# 256-color or truecolor foreground
		elif c == 38 and i + 1 < parts.size():
			var mode := int(parts[i + 1])
			if mode == 5 and i + 2 < parts.size():                 # 38;5;n
				fg = _xterm256_to_hex(int(parts[i + 2])); changed = true; i += 2
			elif mode == 2 and i + 4 < parts.size():               # 38;2;r;g;b
				var r = clamp(int(parts[i + 2]), 0, 255)
				var g = clamp(int(parts[i + 3]), 0, 255)
				var b = clamp(int(parts[i + 4]), 0, 255)
				fg = "#%02X%02X%02X" % [r, g, b]; changed = true; i += 4
			# else ignore malformed

		# we ignore backgrounds: 40–47 / 100–107 / 48;*  (not supported in RichTextLabel)
		i += 1

	return fg if changed else ""
	
func parse_ansi_colored_text(input: String) -> Array[Dictionary]:
	return _ansi_parser.parse(input)
	var result: Array[Dictionary] = []
	var current_color = ANSI_COLORS.get("0", "#AAAAAA")

	var s := input.replace("\r","")   # avoid carriage-return oddities
	var i := 0
	var last := 0
	while i < s.length():
		var ch := s[i]
		# ESC [
		if ch == "\u001b" and i + 1 < s.length() and s[i + 1] == "[":
			# flush plain text up to ESC
			if i > last:
				result.append({"text": s.substr(last, i - last), "color": current_color})

			# find CSI final byte (@..~). If it's 'm' → SGR; else ignore
			var j := i + 2
			while j < s.length():
				var fin := s[j]
				if fin >= "@" and fin <= "~":
					break
				j += 1
			if j >= s.length():
				break

			var final_char := s[j]
			var body := s.substr(i + 2, j - (i + 2))  # e.g. "1;38;5;214" or "2K" body will be "2K"? no—final is 'K'
			if final_char == "m":
				var new_color := _resolve_fg_from_codes(body, current_color)
				if new_color != "":
					current_color = new_color
				elif body == "" or body == "0":
					current_color = ANSI_COLORS.get("0", "#AAAAAA")
			# else: cursor control/erase/etc → ignore (no output)

			i = j + 1
			last = i
			continue

		i += 1

	# tail
	if last < s.length():
		result.append({"text": s.substr(last), "color": current_color})

	return result
	
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
		var l2_prefix_100 = _visible_prefix(descs[2], 100)
		#print("------------------------------")
		#print("L0 Prefix: ", l0_prefix_100)
		#print("L1 Prefix: ", l1_prefix_100)
		#print("L2 Prefix: ", l2_prefix_100)
		#print("------------------------------")
		
		if _visible_prefix(l1_prefix_100, 4) == ".: (":
			# location name
			location_name.emit(bb_chunk)
			mobs_text.emit("")
			$TextDisplay.append_text(bb_chunk)
		
		elif l2_prefix_100 == "┌─ .:Info ──────────────────────┐ ┌─ .:Attributes ───────────────────────────┐":
			# status table
			container_request.emit(bb_chunk, "status")
			_backpack_prohibit = true
			
		elif l0_prefix_100 == "┌─ .:Equipment ──────────────────────────────────────────────────────────────┐":
			# backpack
			if not _backpack_prohibit:
				container_request.emit(bb_chunk, "equipment")
			else:
				_backpack_prohibit = false
		
		elif l1_prefix_100 == "┌─ .:Skills ─────────────────────────────────────────────────────────────────┐":
			# skills table
			container_request.emit(bb_chunk, "skills")
		
		elif l0_prefix_100 == ".: Spells":
			# skills table
			container_request.emit(bb_chunk, "spells")
				
		elif l0_prefix_100 == "┌─────────────────────────────────────────────────────────────────────────┐":
			# sunrise and sunset
			$TextDisplay.append_text(bb_chunk)
		
		elif l2_prefix_100 == "│ Name   │ Level │ Alignment │ Profession │ Online │ Role │":
			# player table
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
	var in_tag := false
	for i in range(bb_line.length()):
		var ch := bb_line.substr(i, 1)
		if ch == "[":
			in_tag = true
			continue
		elif ch == "]":
			in_tag = false
			continue
		if in_tag:
			continue
		if ch == "╝":
			return true
	return false

# Parse opening color tags active BEFORE column `upto`
func _color_prefix_before_index(line: String, upto: int) -> Dictionary:
	return _layout_detector.color_prefix_before_index(line, upto)
	var stack: Array = []   # store exact opening tags like "[color=#808080]"
	var in_tag := false
	var tag := ""
	for i in range(min(upto, line.length())):
		var ch := line.substr(i, 1)
		if not in_tag:
			if ch == "[":
				in_tag = true
				tag = ""
			continue
		if ch == "]":
			var t := tag.strip_edges()
			if t == "/color":
				if stack.size() > 0: stack.pop_back()
			elif t.begins_with("color"):
				stack.append("[" + t + "]")
			in_tag = false
		else:
			tag += ch
	var prefix := ""
	for t in stack:
		prefix += t
	return {"prefix": prefix, "stack": stack}

# Update color stack by scanning BBCode in `text`
func _update_color_stack_with_text(stack: Array, text: String) -> void:
	_layout_detector.update_color_stack_with_text(stack, text)
	return
	var in_tag := false
	var tag := ""
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		if not in_tag:
			if ch == "[":
				in_tag = true
				tag = ""
			continue
		if ch == "]":
			var t := tag.strip_edges()
			if t == "/color":
				if stack.size() > 0: stack.pop_back()
			elif t.begins_with("color"):
				stack.append("[" + t + "]")
			in_tag = false
		else:
			tag += ch

func _closing_for_stack(stack: Array) -> String:
	return _layout_detector.closing_for_stack(stack)
	var s := ""
	for i in range(stack.size() - 1, -1, -1):
		if String(stack[i]).begins_with("[color"):
			s += "[/color]"
	return s


func _is_npc_look_description(descs: Array, joined_text: String) -> bool:
	var visible: String = _strip_bbcode(joined_text)
	if not visible.to_lower().contains("description"):
		return false
	var health_re := RegEx.new()
	health_re.compile("(?i)\\b.+\\s+is\\s+in\\s+.+\\s+health\\b")
	return health_re.search(visible) != null


func _npc_look_description_data(descs: Array, joined_text: String) -> Dictionary:
	var visible_lines: Array[String] = []
	for desc: Variant in descs:
		var clean_line: String = _clean_npc_look_line(str(desc))
		if clean_line != "" and not _is_decorative_box_line(clean_line):
			visible_lines.append(clean_line)
	var visible: String = _normalize_spaces(" ".join(visible_lines))
	var description: String = _clean_npc_description_text(visible)
	var name: String = _extract_npc_name_from_description(visible)
	return {
		"name": name,
		"description": description,
		"raw": joined_text,
	}


func _clean_npc_description_text(visible: String) -> String:
	var text: String = _remove_mud_box_art(visible)
	text = text.replace("Description", " ")
	text = text.replace(".:Description", " ")
	text = text.replace(".:", " ")
	var health_re := RegEx.new()
	health_re.compile("(?i)\\b[^.\\n]+\\s+is\\s+in\\s+[^.\\n]+\\s+health\\.?")
	text = health_re.sub(text, " ", true)
	return _normalize_spaces(text)


func _extract_npc_name_from_description(visible: String) -> String:
	var health_re := RegEx.new()
	health_re.compile("(?i)\\b([A-Za-z][A-Za-z0-9 '\\-]*)\\s+is\\s+in\\s+[^.\\n]+\\s+health\\b")
	var match: RegExMatch = health_re.search(visible)
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
	var visible: String = _strip_bbcode(slice)
	var clean_slice: String = _remove_mud_box_art(visible)
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

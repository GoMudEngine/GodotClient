extends Node2D

signal bb_data(text: String)
signal location_name(text: String)
signal status_text(text: String)
signal mobs_text(text: String)
signal items_text(text: String)
signal exits_text(text: String)
signal container_request(data: Array)
signal auto_commands_submitted(cmd: String)

const _LEFT_CHARS  := {"╔": true, "║": true, "╚": true}
const _RIGHT_CHARS := {"╗": true, "║": true, "╝": true}

var _in_map := false
var _cur_map: Array = []
var _backpack_prohibit = false
var _prevent_location_name: int = 0
var _prevent_location_desc: int = 0
var _mob_list = []

# remember first line + left index to compute prefix
var _first_line_raw := ""
var _first_left_idx := 0

func _ready() -> void:
	var display = $TextDisplay
	# UI setup
	display.bbcode_enabled = true
	if display.has_method("set_scroll_following"):
		display.set_scroll_following(true)   # Godot 4.x keeps scrolled to bottom
	set_process(true)

func _update_lines(input: String) -> void:
	var parsed_data = parse_ansi_colored_text(input)
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
	
func parse_ansi_colored_text(input: String) -> Array:
	var result: Array = []
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
	var out := ""
	var in_tag := false
	for i in range(bb_chunk.length()):
		var ch := bb_chunk[i]
		if ch == "[":
			in_tag = true
			continue
		elif ch == "]":
			in_tag = false
			continue
		if in_tag:
			continue
		out += ch
		if out.length() >= n:
			break
	return out.strip_edges()
	
func _process_one_bb_line(bb_chunk: String) -> void:
	var descs: Array = []
	var sys_msg: bool = false
	if contains_term(bb_chunk, ".:") or contains_term(bb_chunk, "───────────"):
		sys_msg = true
	
	for raw_line in bb_chunk.split("\n", false):
		var line := raw_line.rstrip("\r")
		var pair := _line_map_slice_indices(line)

		if pair.is_empty():
			# pure description line
			descs.append(line)
			# don't return; keep processing the rest of the chunk
			continue

		# line contains a map slice
		var left: int = pair[0]
		var right: int = pair[1]
		var slice := line.substr(left, right - left + 1)
		var desc := line.substr(0, left)

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
			emit_signal("bb_data", final)
			_cur_map.clear()
			_in_map = false

	# After processing all lines in the chunk, append descriptions once
	var descs_size = descs.size()
	var text = ""
	
	# one line message
	if descs_size == 1:
		if _visible_prefix(descs[0], 1) == "(":
			# status text
			emit_signal("status_text", str(descs[0]))
			return
		elif _visible_prefix(descs[0], 100) in ["TEXTMASK:false", "TEXTMASK:true"]:
			return
		else:
			# classified as short msg
			var short_msg = _visible_prefix(descs[0], 30)
			if len(short_msg) > 3:
				if short_msg not in ["look", "status", "equipment", "skills", "spells"]:
					$TextDisplay.append_text(bb_chunk)
					return
	
	# two line message
	if descs_size == 2:
		if contains_term(descs[0], "Exits"):
			# exits
			emit_signal("exits_text", bb_chunk)
			return
		elif contains_term(descs[0], "Also here"):
			# mobs
			emit_signal("mobs_text", descs[0])
			var mobs = _visible_prefix(descs[0], 200)
			_mob_list = []
			mobs = mobs.replace("Also here: ","")
			if contains_term(mobs, "and"):
				_mob_list.append(mobs.split("and")[1])
				if contains_term(mobs.split("and")[0], ","):
					for m in mobs.split("and")[0].split(","):
						_mob_list.append(m)
				else:
					_mob_list.append(mobs.split("and")[0])
			else:
				_mob_list.append(mobs)
			
			for j in range(_mob_list.size()):
				_mob_list[j] = _mob_list[j].strip_edges()
			
			if Global_Status._target_list.size() > 0:
				var _cmd_to_execute = ""
				for t in Global_Status._target_list:
					if t in _mob_list:
						_cmd_to_execute = "kill " + str(t)
				emit_signal("auto_commands_submitted", _cmd_to_execute)
			
		elif contains_term(descs[0], "On the Ground"):
			# items
			emit_signal("items_text", descs[0])
		else:
			$TextDisplay.append_text(bb_chunk)
			# auto refresh the mobs
			var l0_prefix_100 = _visible_prefix(descs[0], 100)
			if contains_term(l0_prefix_100, "You pick up"):
				_prevent_location_name += 1
				_prevent_location_desc += 1
				emit_signal("auto_commands_submitted", "look")
				emit_signal("auto_commands_submitted", "i")
			if contains_term(l0_prefix_100, "You drop"):
				_prevent_location_name += 1
				_prevent_location_desc += 1
				emit_signal("auto_commands_submitted", "look")
				emit_signal("auto_commands_submitted", "i")
			if contains_term(l0_prefix_100, "enters"):
				_prevent_location_name += 1
				_prevent_location_desc += 1
				emit_signal("auto_commands_submitted", "look")
			if contains_term(l0_prefix_100, "leaves"):
				_prevent_location_name += 1
				_prevent_location_desc += 1
				emit_signal("auto_commands_submitted", "look")
			if contains_term(l0_prefix_100, "died"):
				_prevent_location_name += 1
				_prevent_location_desc += 1
				emit_signal("auto_commands_submitted", "look")
			if contains_term(l0_prefix_100, "prepares"):
				_prevent_location_name += 1
				_prevent_location_desc += 1
				emit_signal("auto_commands_submitted", "look")
			return
			
	# big message
	if descs_size > 2:
		#print("Large desc ---------------")
		if Global_Status._first_msg:
			$TextDisplay.append_text(bb_chunk)
			Global_Status._first_msg = false
			return

		# --- Step 1: Trim each line and remove empties ---
		for i in range(descs_size):
			descs[i] = descs[i].strip_edges()

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
			
		if contains_term(l1_prefix_100, ".: ("):
			# location name
			emit_signal("location_name", bb_chunk)
			emit_signal("mobs_text", "")
			emit_signal("items_text", "")
			if _prevent_location_name < 1:
				$TextDisplay.append_text(bb_chunk)
			else:
				_prevent_location_name -= 1
				return
		
		elif contains_term(l2_prefix_100, ".:Attributes"):
			# status table
			emit_signal("container_request", bb_chunk, "status")
			_backpack_prohibit = true
			
		elif contains_term(l0_prefix_100, ".:Equipment"):
			# backpack
			if not _backpack_prohibit:
				emit_signal("container_request", bb_chunk, "equipment")
			else:
				_backpack_prohibit = false
		
		elif contains_term(l1_prefix_100, ".:Skills"):
			# skills table
			emit_signal("container_request", bb_chunk, "skills")
		
		elif contains_term(l0_prefix_100, ".: Spells"):
			# skills table
			emit_signal("container_request", bb_chunk, "spells")
		
		else:
			if sys_msg:
				$TextDisplay.append_text(bb_chunk)
				return
			if _prevent_location_desc < 1:
				$TextDisplay.append_text(text + "\n")
			else:
				_prevent_location_desc -= 1
				return

# ---------------- helpers ----------------
func _line_map_slice_indices(bb_line: String) -> Array:
	var left := -1
	var right := -1
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
		if left == -1 and _LEFT_CHARS.has(ch):
			left = i
		if _RIGHT_CHARS.has(ch):
			right = i
	return [] if (left == -1 or right == -1 or right < left) else [left, right]

func _has_bottom_ignoring_tags(bb_line: String) -> bool:
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
	var s := ""
	for i in range(stack.size() - 1, -1, -1):
		if String(stack[i]).begins_with("[color"):
			s += "[/color]"
	return s

func contains_term(message: String, term: String) -> bool:
	return message.find(term) != -1

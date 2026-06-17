extends RefCounted

const ANSI_COLORS: Dictionary = {
	"0": "#AAAAAA",
	"30": "#000000",
	"31": "#800000",
	"32": "#008000",
	"33": "#808000",
	"34": "#000080",
	"35": "#800080",
	"36": "#008080",
	"37": "#C0C0C0",
	"90": "#808080",
	"91": "#FF0000",
	"92": "#00FF00",
	"93": "#FFFF00",
	"94": "#0000FF",
	"95": "#FF00FF",
	"96": "#00FFFF",
	"97": "#FFFFFF",
	"1;30": "#555555",
	"1;31": "#FF5555",
	"1;32": "#55FF55",
	"1;33": "#FFFF55",
	"1;34": "#5555FF",
	"1;35": "#FF55FF",
	"1;36": "#55FFFF",
	"1;37": "#FFFFFF",
	"1;90": "#AAAAAA",
	"1;91": "#FF8888",
	"1;92": "#88FF88",
	"1;93": "#FFFF88",
	"1;94": "#8888FF",
	"1;95": "#FF88FF",
	"1;96": "#88FFFF",
	"1;97": "#FFFFFF",
}


func parse(input: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var current_color: String = ANSI_COLORS.get("0", "#AAAAAA")
	var text: String = input.replace("\r", "")
	var index: int = 0
	var last: int = 0

	while index < text.length():
		var character: String = text[index]
		if character == "\u001b" and index + 1 < text.length() and text[index + 1] == "[":
			if index > last:
				result.append({"text": text.substr(last, index - last), "color": current_color})

			var final_index: int = index + 2
			while final_index < text.length():
				var final_candidate: String = text[final_index]
				if final_candidate >= "@" and final_candidate <= "~":
					break
				final_index += 1

			if final_index >= text.length():
				break

			var final_char: String = text[final_index]
			var body: String = text.substr(index + 2, final_index - (index + 2))
			if final_char == "m":
				var new_color: String = _resolve_fg_from_codes(body, current_color)
				if new_color != "":
					current_color = new_color
				elif body == "" or body == "0":
					current_color = ANSI_COLORS.get("0", "#AAAAAA")

			index = final_index + 1
			last = index
			continue

		index += 1

	if last < text.length():
		result.append({"text": text.substr(last), "color": current_color})

	return result


func xterm256_to_hex(index: int) -> String:
	index = clamp(index, 0, 255)
	var base16: Array[String] = [
		"#000000", "#800000", "#008000", "#808000",
		"#000080", "#800080", "#008080", "#C0C0C0",
		"#808080", "#FF0000", "#00FF00", "#FFFF00",
		"#0000FF", "#FF00FF", "#00FFFF", "#FFFFFF",
	]
	if index < 16:
		return base16[index]
	if index <= 231:
		var color_index: int = index - 16
		var steps: PackedInt32Array = PackedInt32Array([0, 95, 135, 175, 215, 255])
		var red: int = steps[color_index / 36]
		var green: int = steps[(color_index / 6) % 6]
		var blue: int = steps[color_index % 6]
		return "#%02X%02X%02X" % [red, green, blue]

	var value: int = clamp(8 + 10 * (index - 232), 0, 255)
	return "#%02X%02X%02X" % [value, value, value]


func _resolve_fg_from_codes(code_str: String, fallback: String) -> String:
	if ANSI_COLORS.has(code_str):
		return ANSI_COLORS[code_str]

	var parts: PackedStringArray = code_str.split(";")
	if parts.is_empty():
		return ""

	var foreground: String = fallback
	var changed: bool = false
	var index: int = 0
	while index < parts.size():
		var code: int = int(parts[index])

		if code >= 30 and code <= 37:
			foreground = xterm256_to_hex(code - 30)
			changed = true
		elif code >= 90 and code <= 97:
			foreground = xterm256_to_hex(8 + (code - 90))
			changed = true
		elif code == 38 and index + 1 < parts.size():
			var mode: int = int(parts[index + 1])
			if mode == 5 and index + 2 < parts.size():
				foreground = xterm256_to_hex(int(parts[index + 2]))
				changed = true
				index += 2
			elif mode == 2 and index + 4 < parts.size():
				var red: int = clamp(int(parts[index + 2]), 0, 255)
				var green: int = clamp(int(parts[index + 3]), 0, 255)
				var blue: int = clamp(int(parts[index + 4]), 0, 255)
				foreground = "#%02X%02X%02X" % [red, green, blue]
				changed = true
				index += 4

		index += 1

	return foreground if changed else ""

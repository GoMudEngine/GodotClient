class_name MapPanel
extends Node2D

const MAP_RADIUS: int = 2
const CURRENT_ROOM_SYMBOL: String = "@"
const UNKNOWN_ROOM_SYMBOL: String = "."
const DEFAULT_ROOM_SYMBOL: String = "o"
const TILE_MATRIX_SIZE: int = MAP_RADIUS * 4 + 1
const TILE_CELL_SIZE: Vector2 = Vector2(24.0, 18.0)
const DEFAULT_MAP_HISTORY_PATH: String = "user://map_history.json"
const TILE_FONT: FontVariation = preload("res://fonts/kc_fonts_regular.tres")
const MAP_SAVE_DEBOUNCE_MS: int = 5000

var _has_gmcp_room: bool = false
var _current_coord: Vector3i = Vector3i.ZERO
var _current_area: String = ""
var _rooms_by_key: Dictionary = {}
var _tile_grid: GridContainer = null
var _tile_cells: Array[Label] = []
var _map_history_loaded: bool = false
var _map_history_path: String = DEFAULT_MAP_HISTORY_PATH
var _map_dirty: bool = false
var _last_save_time_ms: int = 0


func _ready() -> void:
	$Map_BG/TextDisplay_Location_Name.bbcode_enabled = true
	$Map_BG/TextDisplay_Exits.bbcode_enabled = true
	_load_map_history()
	_ensure_tile_map_view()


func _process(_delta: float) -> void:
	if not _map_dirty:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_save_time_ms >= MAP_SAVE_DEBOUNCE_MS:
		_map_dirty = false
		_last_save_time_ms = now
		_save_map_history()


func apply_gmcp(topic: String, data: Variant, _gmcp_state: Dictionary) -> void:
	if topic != "Room.Info" or not data is Dictionary:
		return

	_has_gmcp_room = true
	var room: Dictionary = data
	_current_area = str(room.get("area", _current_area))
	_current_coord = _parse_room_coords(str(room.get("coords", "")), _current_area)
	_store_room(room)
	_store_exit_placeholders(room)
	_map_dirty = true
	_render_gmcp_room(room)


func _render_gmcp_room(room: Dictionary) -> void:
	$Map_BG/TextDisplay_Location_Name.text = _format_room_title(room)
	$Map_BG/TextDisplay_Exits.text = _format_gmcp_exits(_room_exits(room))
	if has_node("Map_BG/TextDisplay"):
		$Map_BG/TextDisplay.clear()
		$Map_BG/TextDisplay.visible = false
	_render_gmcp_tile_map()


func _format_room_title(room: Dictionary) -> String:
	var title: String = str(room.get("name", "Unknown Room"))
	var area: String = str(room.get("area", ""))
	var legend: String = str(room.get("maplegend", ""))
	var environment: String = str(room.get("environment", ""))
	var meta: Array[String] = []
	if area != "":
		meta.append(area)
	if legend != "":
		meta.append(legend)
	elif environment != "":
		meta.append(environment)
	if meta.is_empty():
		return title
	return "%s\n%s" % [title, " | ".join(meta)]


func _room_exits(room: Dictionary) -> Dictionary:
	var exits_v2: Variant = room.get("exitsv2", {})
	if exits_v2 is Dictionary and not exits_v2.is_empty():
		return exits_v2
	var exits: Variant = room.get("exits", {})
	if exits is Dictionary:
		return exits
	return {}


func _format_gmcp_exits(exits: Dictionary) -> String:
	var directions: Array[String] = []
	for direction: Variant in exits.keys():
		directions.append(str(direction))
	directions.sort()
	if directions.is_empty():
		return "Exits: none"
	return "Exits: " + ", ".join(directions)


func _build_gmcp_map_text(room: Dictionary) -> String:
	var size: int = MAP_RADIUS * 2 + 1
	var canvas_size: int = size * 2 - 1
	var lines: Array[String] = []
	for _row: int in range(canvas_size):
		lines.append(" ".repeat(canvas_size))

	for y_offset: int in range(-MAP_RADIUS, MAP_RADIUS + 1):
		for x_offset: int in range(-MAP_RADIUS, MAP_RADIUS + 1):
			var coord: Vector3i = Vector3i(
				_current_coord.x + x_offset,
				_current_coord.y + y_offset,
				_current_coord.z
			)
			var symbol: String = _symbol_for_coord(coord)
			if symbol == "":
				continue
			_set_canvas_char(lines, (x_offset + MAP_RADIUS) * 2, (y_offset + MAP_RADIUS) * 2, symbol)

	for coord_key: Variant in _rooms_by_key.keys():
		var stored: Dictionary = _rooms_by_key.get(coord_key, {})
		if str(stored.get("area", "")) != _current_area:
			continue
		var coord: Vector3i = stored.get("coord", Vector3i.ZERO)
		if coord.z != _current_coord.z:
			continue
		var x_offset: int = coord.x - _current_coord.x
		var y_offset: int = coord.y - _current_coord.y
		if abs(x_offset) > MAP_RADIUS or abs(y_offset) > MAP_RADIUS:
			continue
		_draw_room_exits(lines, coord, stored)

	var output: Array[String] = []
	for line: String in lines:
		output.append(line.rstrip(" "))
	var details: String = _format_room_details(room)
	if details != "":
		output.append("")
		output.append(details)
	return "\n".join(output)


func _ensure_tile_map_view() -> void:
	var map_bg: Panel = $Map_BG
	_tile_grid = map_bg.get_node_or_null("TileMapView") as GridContainer
	if _tile_grid == null:
		_tile_grid = GridContainer.new()
		_tile_grid.name = "TileMapView"
		_tile_grid.columns = TILE_MATRIX_SIZE
		_tile_grid.offset_left = 36.0
		_tile_grid.offset_top = 84.0
		_tile_grid.offset_right = 252.0
		_tile_grid.offset_bottom = 246.0
		_tile_grid.add_theme_constant_override("h_separation", 0)
		_tile_grid.add_theme_constant_override("v_separation", 0)
		map_bg.add_child(_tile_grid)
	_tile_grid.visible = false
	_tile_cells.clear()
	for child: Node in _tile_grid.get_children():
		if child is Label:
			_tile_cells.append(child)
	while _tile_cells.size() < TILE_MATRIX_SIZE * TILE_MATRIX_SIZE:
		var tile: Label = Label.new()
		tile.name = "Tile_%02d" % _tile_cells.size()
		tile.custom_minimum_size = TILE_CELL_SIZE
		tile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tile.clip_text = true
		tile.autowrap_mode = TextServer.AUTOWRAP_OFF
		tile.add_theme_font_size_override("font_size", 16)
		tile.add_theme_font_override("font", TILE_FONT)
		_tile_grid.add_child(tile)
		_tile_cells.append(tile)


func _render_gmcp_tile_map() -> void:
	_ensure_tile_map_view()
	_tile_grid.visible = true
	for tile: Label in _tile_cells:
		_set_tile(tile, "", "empty")

	for y_offset: int in range(-MAP_RADIUS, MAP_RADIUS + 1):
		for x_offset: int in range(-MAP_RADIUS, MAP_RADIUS + 1):
			var coord: Vector3i = Vector3i(
				_current_coord.x + x_offset,
				_current_coord.y + y_offset,
				_current_coord.z
			)
			var symbol: String = _symbol_for_coord(coord)
			if symbol == "":
				continue
			var kind: String = "current" if coord == _current_coord else "unknown" if symbol == UNKNOWN_ROOM_SYMBOL else "room"
			_set_tile_at((x_offset + MAP_RADIUS) * 2, (y_offset + MAP_RADIUS) * 2, symbol, kind)

	for coord_key: Variant in _rooms_by_key.keys():
		var stored: Dictionary = _rooms_by_key.get(coord_key, {})
		if str(stored.get("area", "")) != _current_area:
			continue
		var coord: Vector3i = stored.get("coord", Vector3i.ZERO)
		if coord.z != _current_coord.z:
			continue
		var x_offset: int = coord.x - _current_coord.x
		var y_offset: int = coord.y - _current_coord.y
		if abs(x_offset) > MAP_RADIUS or abs(y_offset) > MAP_RADIUS:
			continue
		_draw_tile_exits(coord, stored)


func _draw_tile_exits(coord: Vector3i, stored: Dictionary) -> void:
	var exits: Dictionary = stored.get("exitsv2", {})
	var from_x: int = (coord.x - _current_coord.x + MAP_RADIUS) * 2
	var from_y: int = (coord.y - _current_coord.y + MAP_RADIUS) * 2
	for direction: Variant in exits.keys():
		var exit_data: Variant = exits.get(direction)
		if not exit_data is Dictionary:
			continue
		var dx: int = int(exit_data.get("dx", 0))
		var dy: int = int(exit_data.get("dy", 0))
		var is_cardinal: bool = (abs(dx) + abs(dy) == 1)
		var is_diagonal: bool = (abs(dx) == 1 and abs(dy) == 1)
		if not is_cardinal and not is_diagonal:
			continue
		var connector: String
		if is_diagonal:
			connector = "╱" if (dx * dy < 0) else "╲"
		else:
			connector = "─" if dx != 0 else "│"
		_set_tile_at(from_x + dx, from_y + dy, connector, "connector")


func _set_tile_at(x: int, y: int, text: String, kind: String) -> void:
	var tile: Label = _tile_at(x, y)
	if tile == null:
		return
	_set_tile(tile, text, kind)


func _tile_at(x: int, y: int) -> Label:
	if x < 0 or y < 0 or x >= TILE_MATRIX_SIZE or y >= TILE_MATRIX_SIZE:
		return null
	var index: int = y * TILE_MATRIX_SIZE + x
	if index < 0 or index >= _tile_cells.size():
		return null
	return _tile_cells[index]


func _set_tile(tile: Label, text: String, kind: String) -> void:
	tile.text = text
	tile.add_theme_color_override("font_color", _tile_font_color(kind))
	tile.add_theme_stylebox_override("normal", _tile_style(kind))


func _tile_font_color(kind: String) -> Color:
	match kind:
		"current":
			return Color(1.0, 0.86, 0.32, 1.0)
		"connector":
			return Color(0.64, 0.82, 0.90, 1.0)
		"unknown":
			return Color(0.56, 0.60, 0.66, 1.0)
		"room":
			return Color(0.88, 0.92, 0.94, 1.0)
		_:
			return Color(1, 1, 1, 0)


func _tile_style(kind: String) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	match kind:
		"current":
			style.bg_color = Color(0.18, 0.13, 0.04, 0.95)
			style.border_color = Color(0.95, 0.72, 0.22, 1.0)
		"room":
			style.bg_color = Color(0.05, 0.07, 0.075, 0.92)
			style.border_color = Color(0.25, 0.34, 0.38, 1.0)
		"unknown":
			style.bg_color = Color(0.035, 0.04, 0.045, 0.72)
			style.border_color = Color(0.16, 0.20, 0.23, 0.9)
		"connector":
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color(0, 0, 0, 0)
		_:
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color(0, 0, 0, 0)
	if kind == "current" or kind == "room" or kind == "unknown":
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
	return style


func _draw_room_exits(lines: Array[String], coord: Vector3i, stored: Dictionary) -> void:
	var exits: Dictionary = stored.get("exitsv2", {})
	var from_x: int = (coord.x - _current_coord.x + MAP_RADIUS) * 2
	var from_y: int = (coord.y - _current_coord.y + MAP_RADIUS) * 2
	for direction: Variant in exits.keys():
		var exit_data: Variant = exits.get(direction)
		if not exit_data is Dictionary:
			continue
		var dx: int = int(exit_data.get("dx", 0))
		var dy: int = int(exit_data.get("dy", 0))
		var is_cardinal: bool = (abs(dx) + abs(dy) == 1)
		var is_diagonal: bool = (abs(dx) == 1 and abs(dy) == 1)
		if not is_cardinal and not is_diagonal:
			continue
		var link_x: int = from_x + dx
		var link_y: int = from_y + dy
		if link_x < 0 or link_y < 0 or link_y >= lines.size() or link_x >= lines[link_y].length():
			continue
		var connector: String
		if is_diagonal:
			connector = "/" if (dx * dy < 0) else "\\"
		else:
			connector = "-" if dx != 0 else "|"
		_set_canvas_char(lines, link_x, link_y, connector)


func _format_room_details(room: Dictionary) -> String:
	var parts: Array[String] = []
	var coords: String = str(room.get("coords", ""))
	if coords != "":
		parts.append(coords)
	var details: Variant = room.get("details", [])
	if details is Array and not details.is_empty():
		parts.append("Details: " + ", ".join(_variant_array_to_strings(details)))
	return "\n".join(parts)


func _store_room(room: Dictionary) -> void:
	var key: String = _coord_key(_current_area, _current_coord)
	_rooms_by_key[key] = {
		"area": _current_area,
		"coord": _current_coord,
		"name": str(room.get("name", "")),
		"symbol": _room_symbol(room),
		"exitsv2": _normalized_exits_v2(room),
		"last_seen": Time.get_datetime_string_from_system(),
	}


func _store_exit_placeholders(room: Dictionary) -> void:
	var exits: Dictionary = _normalized_exits_v2(room)
	for direction: Variant in exits.keys():
		var exit_data: Dictionary = exits.get(direction, {})
		var dx: int = int(exit_data.get("dx", 0))
		var dy: int = int(exit_data.get("dy", 0))
		var dz: int = int(exit_data.get("dz", 0))
		var is_cardinal: bool = (abs(dx) + abs(dy) + abs(dz) == 1)
		var is_diagonal: bool = (abs(dx) == 1 and abs(dy) == 1 and dz == 0)
		if not is_cardinal and not is_diagonal:
			continue
		var coord: Vector3i = Vector3i(_current_coord.x + dx, _current_coord.y + dy, _current_coord.z + dz)
		var key: String = _coord_key(_current_area, coord)
		if _rooms_by_key.has(key):
			continue
		_rooms_by_key[key] = {
			"area": _current_area,
			"coord": coord,
			"name": "",
			"symbol": UNKNOWN_ROOM_SYMBOL,
			"exitsv2": {},
		}


func _load_map_history() -> void:
	if _map_history_loaded:
		return
	_map_history_loaded = true
	if not FileAccess.file_exists(_map_history_path):
		return
	var file: FileAccess = FileAccess.open(_map_history_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var rooms: Variant = parsed.get("rooms", {})
	if not rooms is Dictionary:
		return
	_rooms_by_key.clear()
	for key: Variant in rooms.keys():
		var stored: Variant = rooms.get(key)
		if not stored is Dictionary:
			continue
		var room: Dictionary = _deserialize_stored_room(stored)
		if room.is_empty():
			continue
		_rooms_by_key[str(key)] = room


func _save_map_history() -> void:
	var rooms: Dictionary = {}
	for key: Variant in _rooms_by_key.keys():
		var stored: Variant = _rooms_by_key.get(key)
		if stored is Dictionary:
			rooms[str(key)] = _serialize_stored_room(stored)
	var payload: Dictionary = {
		"version": 1,
		"rooms": rooms,
	}
	var file: FileAccess = FileAccess.open(_map_history_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))


func _serialize_stored_room(room: Dictionary) -> Dictionary:
	var coord: Vector3i = room.get("coord", Vector3i.ZERO)
	return {
		"area": str(room.get("area", "")),
		"x": coord.x,
		"y": coord.y,
		"z": coord.z,
		"name": str(room.get("name", "")),
		"symbol": str(room.get("symbol", DEFAULT_ROOM_SYMBOL)),
		"exitsv2": _string_keyed_dictionary(room.get("exitsv2", {})),
		"last_seen": str(room.get("last_seen", "")),
	}


func _deserialize_stored_room(room: Dictionary) -> Dictionary:
	var area: String = str(room.get("area", ""))
	var coord: Vector3i = Vector3i(
		int(room.get("x", 0)),
		int(room.get("y", 0)),
		int(room.get("z", 0))
	)
	if area == "":
		return {}
	return {
		"area": area,
		"coord": coord,
		"name": str(room.get("name", "")),
		"symbol": str(room.get("symbol", DEFAULT_ROOM_SYMBOL)),
		"exitsv2": _string_keyed_dictionary(room.get("exitsv2", {})),
		"last_seen": str(room.get("last_seen", "")),
	}


func _string_keyed_dictionary(value: Variant) -> Dictionary:
	var output: Dictionary = {}
	if not value is Dictionary:
		return output
	for key: Variant in value.keys():
		var item: Variant = value.get(key)
		output[str(key)] = item
	return output


func _normalized_exits_v2(room: Dictionary) -> Dictionary:
	var exits_v2: Variant = room.get("exitsv2", {})
	if exits_v2 is Dictionary:
		return exits_v2
	return {}


func _symbol_for_coord(coord: Vector3i) -> String:
	if coord == _current_coord:
		return CURRENT_ROOM_SYMBOL
	var room: Dictionary = _rooms_by_key.get(_coord_key(_current_area, coord), {})
	if room.is_empty():
		return ""
	return str(room.get("symbol", DEFAULT_ROOM_SYMBOL))


func _room_symbol(room: Dictionary) -> String:
	var symbol: String = str(room.get("mapsymbol", "")).strip_edges()
	if symbol == "":
		return DEFAULT_ROOM_SYMBOL
	return symbol.substr(0, 1)


func _set_canvas_char(lines: Array[String], x: int, y: int, value: String) -> void:
	if y < 0 or y >= lines.size():
		return
	var line: String = lines[y]
	if x < 0 or x >= line.length():
		return
	lines[y] = line.substr(0, x) + value.substr(0, 1) + line.substr(x + 1)


func _parse_room_coords(raw_coords: String, fallback_area: String) -> Vector3i:
	var parts: PackedStringArray = raw_coords.split(",", false)
	if parts.size() >= 4:
		_current_area = parts[0].strip_edges()
		return Vector3i(
			int(float(parts[1].strip_edges())),
			int(float(parts[2].strip_edges())),
			int(float(parts[3].strip_edges()))
		)
	if fallback_area != "":
		_current_area = fallback_area
	return _current_coord


func _coord_key(area: String, coord: Vector3i) -> String:
	return "%s:%d:%d:%d" % [area, coord.x, coord.y, coord.z]


func _variant_array_to_strings(values: Array) -> Array[String]:
	var output: Array[String] = []
	for value: Variant in values:
		output.append(str(value))
	return output


func organize_location_name(data: String) -> String:
	var organized_location_name: Array[String] = []
	var re_paren := RegEx.new()
	re_paren.compile("\\s*\\(\\d+/\\d+\\)")
	for raw_line: String in data.split("\n", false):
		var line: String = raw_line.rstrip("\r")
		line = re_paren.sub(line, "", true)
		line = line.replace("[color=#808080]([/color][color=#FFFFFF]?兞/color][color=#808080])[/color]", "")
		line = line.replace(".:", "")
		line = line.replace("  ", "")
		organized_location_name.append(line + "\n")
	return "".join(organized_location_name)


func organize_exits(data: String) -> String:
	var organized_exits: Array[String] = []
	var re_paren := RegEx.new()
	re_paren.compile("\\s*\\(\\d+/\\d+\\)")
	for raw_line: String in data.split("\n", false):
		var line: String = raw_line.rstrip("\r")
		line = re_paren.sub(line, "", true)
		organized_exits.append(line + "\n")
	return "".join(organized_exits)

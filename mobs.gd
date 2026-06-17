extends Node2D

const CARD_GAP: int = 6
const OBJECT_KIND_NPC: String = "npc"
const OBJECT_KIND_ITEM: String = "item"
const OBJECT_KIND_CONTAINER: String = "container"
const OBJECT_KIND_PLAYER: String = "player"
const OBJECT_CARD_SCENE: PackedScene = preload("res://object_card.tscn")
const ITEM_ICON_BY_ID_DIR: String = "res://assets/items/by_id"
const MOB_ICON_BY_NAME_DIR: String = "res://assets/mobs/by_name"
const DEFAULT_ITEM_ICON_PATH: String = "res://assets/items/default_item.png"
const DEFAULT_MOB_ICON_PATH: String = "res://assets/mobs/default_mob.png"

signal button_commands_submitted(data: String)

var _card_scroll: ScrollContainer = null
var _card_list: VBoxContainer = null
var _card_size: Vector2 = Vector2.ZERO
var _has_gmcp_contents: bool = false
var _last_object_entries: Array[Dictionary] = []


func _ready() -> void:
	var text_processor: Variant = $"../TextProcessor"
	text_processor.mobs_text.connect(_on_mobs_text_received)
	$Mobs_BG/TextDisplay.bbcode_enabled = true
	_ensure_card_ui()
	$Mobs_BG.resized.connect(_sync_card_scroll_bounds)


func _on_mobs_text_received(bb_line: String) -> void:
	if _has_gmcp_contents:
		_set_card_ui_visible(true)
		return
	_set_card_ui_visible(false)
	bb_line = bb_line.substr(34)
	var r: RichTextLabel = $Mobs_BG/TextDisplay
	r.visible = true
	r.clear()
	r.parse_bbcode("Objects here: " + bb_line)


func apply_gmcp(topic: String, data: Variant, gmcp_state: Dictionary) -> void:
	if topic != "Room.Info" and not topic.begins_with("Room.Info.Contents"):
		return
	var contents: Variant = _room_contents(gmcp_state)
	if contents is Dictionary and contents.is_empty() and data is Dictionary and data.has("Contents"):
		contents = data.get("Contents")
	if (not contents is Dictionary or contents.is_empty()) and data is Array:
		contents = _contents_from_direct_topic(topic, data)
	if not contents is Dictionary:
		return
	_has_gmcp_contents = true
	_render_object_cards(contents)


func _ensure_card_ui() -> void:
	if _card_list != null:
		return
	_card_scroll = ScrollContainer.new()
	_card_scroll.name = "ObjectCards"
	_card_scroll.visible = false
	_card_scroll.offset_left = 0.0
	_card_scroll.offset_top = 0.0
	_card_scroll.clip_contents = true
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	$Mobs_BG.add_child(_card_scroll)
	_sync_card_scroll_bounds()

	_card_list = VBoxContainer.new()
	_card_list.name = "CardList"
	_card_list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_card_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_card_list.add_theme_constant_override("separation", CARD_GAP)
	_card_scroll.add_child(_card_list)


func _set_card_ui_visible(visible: bool) -> void:
	_ensure_card_ui()
	_card_scroll.visible = visible
	$Mobs_BG/TextDisplay.visible = not visible


func _render_object_cards(contents: Dictionary) -> void:
	_ensure_card_ui()
	_clear_children(_card_list)
	_set_card_ui_visible(true)
	_sync_card_scroll_bounds()
	var card_size: Vector2 = _object_card_size()
	_card_list.custom_minimum_size = Vector2(card_size.x, 0.0)

	var entries: Array[Dictionary] = _room_object_entries(contents)
	_last_object_entries = entries.duplicate(true)
	if entries.is_empty():
		_card_list.add_child(_make_empty_card())
		return

	for entry: Dictionary in entries:
		_card_list.add_child(_make_object_card(entry))


func _sync_card_scroll_bounds() -> void:
	if _card_scroll == null:
		return
	_card_scroll.offset_left = 0.0
	_card_scroll.offset_top = 0.0
	_card_scroll.offset_right = $Mobs_BG.size.x
	_card_scroll.offset_bottom = $Mobs_BG.size.y


func _render_npc_cards(entries: Variant) -> void:
	_render_object_cards({"Npcs": entries})


func _make_empty_card() -> PanelContainer:
	var card: PanelContainer = _new_object_card()
	card.call(
		"configure",
		"No objects here",
		"",
		"",
		_default_mob_icon_path(),
		[],
		Color(0.09, 0.1, 0.11, 0.82),
		Color(0.35, 0.39, 0.43, 0.8)
	)
	return card


func _make_object_card(object: Dictionary) -> PanelContainer:
	var card: PanelContainer = _new_object_card()
	card.call(
		"configure",
		str(object.get("name", _object_kind_label(object))),
		_object_tag_text(object),
		_object_tooltip(object),
		_object_icon_path(object),
		_object_actions(object),
		_object_fill_color(object),
		_object_border_color(object)
	)
	return card


func _new_object_card() -> PanelContainer:
	var card: PanelContainer = OBJECT_CARD_SCENE.instantiate()
	card.custom_minimum_size = _object_card_size()
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.connect("action_pressed", _on_action_pressed)
	return card


func _object_card_size() -> Vector2:
	if _card_size != Vector2.ZERO:
		return _card_size
	var card: PanelContainer = OBJECT_CARD_SCENE.instantiate()
	_card_size = Vector2(
		max(card.custom_minimum_size.x, card.size.x),
		max(card.custom_minimum_size.y, card.size.y)
	)
	card.queue_free()
	if _card_size.x <= 0.0:
		_card_size.x = 1.0
	if _card_size.y <= 0.0:
		_card_size.y = 1.0
	return _card_size


func _on_action_pressed(command: String) -> void:
	if command != "":
		button_commands_submitted.emit(command)


func object_for_command_target(target: String) -> Dictionary:
	var normalized_target: String = target.strip_edges()
	if normalized_target == "":
		return {}
	for object: Dictionary in _last_object_entries:
		if _object_command_target(object) == normalized_target:
			return object.duplicate(true)
	return {}


func _object_actions(object: Dictionary) -> Array[Dictionary]:
	var target: String = _object_command_target(object)
	if target == "":
		return []
	var actions: Array[Dictionary] = [
		{"label": "Look", "command": "look " + target},
	]
	var kind: String = _object_kind(object)
	var adjectives: Array[String] = _string_array(object.get("adjectives", []))
	match kind:
		OBJECT_KIND_NPC:
			actions.append({"label": "Atk", "command": "attack " + target, "tooltip": "Attack " + target})
			if bool(object.get("quest_flag", false)):
				actions.append({"label": "Ask", "command": "ask " + target})
			if adjectives.has("shop"):
				actions.append({"label": "List", "command": "list " + target})
		OBJECT_KIND_ITEM:
			actions.append({"label": "Get", "command": "get " + target, "tooltip": "Get " + target})
		OBJECT_KIND_CONTAINER:
			actions.append({"label": "Open", "command": "open " + target, "tooltip": "Open " + target})
	return actions


func _object_command_target(object: Dictionary) -> String:
	var id: String = str(object.get("id", "")).strip_edges()
	if id != "":
		return id
	return str(object.get("name", "")).strip_edges()


func _object_tooltip(object: Dictionary) -> String:
	var lines: Array[String] = [str(object.get("name", _object_kind_label(object)))]
	lines.append("Kind: " + _object_kind_label(object))
	var id: String = str(object.get("id", "")).strip_edges()
	if id != "":
		lines.append("Target: " + id)
	var tags: String = _object_tag_text(object)
	if tags != "":
		lines.append("Tags: " + tags)
	return "\n".join(lines)


func _object_tag_text(object: Dictionary) -> String:
	var tags: Array[String] = [_object_kind_label(object)]
	tags.append_array(_string_array(object.get("adjectives", [])))
	if bool(object.get("aggro", false)):
		tags.append("aggro")
	if bool(object.get("quest_flag", false)):
		tags.append("quest")
	return ", ".join(tags)


func _object_fill_color(object: Dictionary) -> Color:
	var tags: Array[String] = _string_array(object.get("adjectives", []))
	if bool(object.get("aggro", false)):
		return Color(0.26, 0.05, 0.05, 0.92)
	if bool(object.get("quest_flag", false)):
		return Color(0.24, 0.18, 0.04, 0.92)
	if tags.has("shop"):
		return Color(0.03, 0.19, 0.2, 0.92)
	match _object_kind(object):
		OBJECT_KIND_ITEM:
			return Color(0.16, 0.12, 0.06, 0.9)
		OBJECT_KIND_CONTAINER:
			return Color(0.08, 0.15, 0.16, 0.9)
		OBJECT_KIND_PLAYER:
			return Color(0.06, 0.1, 0.18, 0.9)
	return Color(0.1, 0.11, 0.12, 0.88)


func _object_border_color(object: Dictionary) -> Color:
	var tags: Array[String] = _string_array(object.get("adjectives", []))
	if bool(object.get("aggro", false)):
		return Color(0.82, 0.15, 0.12, 1.0)
	if bool(object.get("quest_flag", false)):
		return Color(0.95, 0.72, 0.22, 1.0)
	if tags.has("shop"):
		return Color(0.16, 0.8, 0.85, 1.0)
	match _object_kind(object):
		OBJECT_KIND_ITEM:
			return Color(0.76, 0.56, 0.22, 1.0)
		OBJECT_KIND_CONTAINER:
			return Color(0.25, 0.65, 0.68, 1.0)
		OBJECT_KIND_PLAYER:
			return Color(0.35, 0.55, 0.95, 1.0)
	return Color(0.45, 0.5, 0.55, 1.0)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		child.queue_free()


func _room_contents(gmcp_state: Dictionary) -> Dictionary:
	var room: Dictionary = gmcp_state.get("Room", {})
	var info: Dictionary = room.get("Info", {})
	return info.get("Contents", {})


func _contents_from_direct_topic(topic: String, data: Array) -> Dictionary:
	if topic.ends_with(".Npcs"):
		return {"Npcs": data}
	if topic.ends_with(".Items"):
		return {"Items": data}
	if topic.ends_with(".Containers"):
		return {"Containers": data}
	if topic.ends_with(".Players"):
		return {"Players": data}
	return {}


func _room_object_entries(contents: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	_append_room_object_entries(entries, contents.get("Npcs", []), OBJECT_KIND_NPC)
	_append_room_object_entries(entries, contents.get("Items", []), OBJECT_KIND_ITEM)
	_append_room_object_entries(entries, contents.get("Containers", []), OBJECT_KIND_CONTAINER)
	_append_room_object_entries(entries, contents.get("Players", []), OBJECT_KIND_PLAYER)
	return entries


func _append_room_object_entries(entries: Array[Dictionary], values: Variant, kind: String) -> void:
	if not values is Array:
		return
	for value: Variant in values:
		if value is Dictionary:
			var object: Dictionary = value.duplicate(true)
			object["_kind"] = kind
			entries.append(object)


func _object_kind(object: Dictionary) -> String:
	return str(object.get("_kind", OBJECT_KIND_ITEM))


func _object_kind_label(object: Dictionary) -> String:
	match _object_kind(object):
		OBJECT_KIND_NPC:
			return "npc"
		OBJECT_KIND_CONTAINER:
			return "container"
		OBJECT_KIND_PLAYER:
			return "player"
		_:
			return "item"


func _object_icon_path(object: Dictionary) -> String:
	match _object_kind(object):
		OBJECT_KIND_ITEM:
			return _item_icon_path(object)
		OBJECT_KIND_CONTAINER:
			return DEFAULT_ITEM_ICON_PATH
		OBJECT_KIND_NPC, OBJECT_KIND_PLAYER:
			return _mob_icon_path(object)
		_:
			return DEFAULT_ITEM_ICON_PATH


func _item_icon_path(item: Dictionary) -> String:
	var spec_id: String = _item_spec_id(str(item.get("id", "")))
	if spec_id == "":
		return DEFAULT_ITEM_ICON_PATH
	var path: String = "%s/%s.png" % [ITEM_ICON_BY_ID_DIR, spec_id]
	return path if _icon_file_exists(path) else DEFAULT_ITEM_ICON_PATH


func _mob_icon_path(object: Dictionary) -> String:
	var slug: String = _name_slug(str(object.get("name", "")))
	if slug == "":
		return _default_mob_icon_path()
	var path: String = "%s/%s.png" % [MOB_ICON_BY_NAME_DIR, slug]
	return path if _icon_file_exists(path) else _default_mob_icon_path()


func _default_mob_icon_path() -> String:
	return DEFAULT_MOB_ICON_PATH if _icon_file_exists(DEFAULT_MOB_ICON_PATH) else DEFAULT_ITEM_ICON_PATH


func _item_spec_id(instance_id: String) -> String:
	var value: String = instance_id.strip_edges()
	if value.begins_with("!"):
		value = value.substr(1)
	var colon_index: int = value.find(":")
	if colon_index != -1:
		value = value.substr(0, colon_index)
	return value if value.is_valid_int() else ""


func _name_slug(name: String) -> String:
	var slug: String = ""
	for index: int in range(name.length()):
		var character: String = name.substr(index, 1).to_lower()
		if character >= "a" and character <= "z":
			slug += character
		elif character >= "0" and character <= "9":
			slug += character
		elif slug != "" and not slug.ends_with("_"):
			slug += "_"
	return slug.trim_suffix("_")


func _icon_file_exists(path: String) -> bool:
	return path != "" and (FileAccess.file_exists(path) or ResourceLoader.exists(path))


func _string_array(values: Variant) -> Array[String]:
	var strings: Array[String] = []
	if values is Array:
		for value: Variant in values:
			var text: String = str(value).strip_edges()
			if text != "":
				strings.append(text)
	return strings

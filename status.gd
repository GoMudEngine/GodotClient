extends Node2D

const PLAYER_PORTRAIT_DIR: String = "res://assets/player_portraits/by_race_class"
const STATUS_CHARACTER_ICON_PATH: String = "res://assets/ui/status_icons/status.png"
const PROFESSION_RANK_PREFIXES: Array[String] = [
	"novice", "apprentice", "journeyman", "adept", "expert", "master", "grandmaster",
]

var _status_char_icon: TextureRect = null
var _status_char_name: Label = null
var _status_char_meta: Label = null
var _hp_label: Label = null
var _sp_label: Label = null
var _gold_label: Label = null
var _xp_label: Label = null
var _mobk_label: Label = null
var _pvpk_label: Label = null
var _affects_label: Label = null


func _ready() -> void:
	_ensure_status_bar_ui()


func _ensure_status_bar_ui() -> void:
	if _bind_scene_ui():
		return
	_build_dynamic_ui()


func _bind_scene_ui() -> bool:
	var layout: Node = $Status_BG.get_node_or_null("StatusLayout")
	if layout == null:
		return false
	$Status_BG/TextDisplay.visible = false
	var icon_node: Node = layout.get_node_or_null("CharacterInfo/CharacterIcon")
	if icon_node is TextureRect:
		_status_char_icon = icon_node as TextureRect
		if ResourceLoader.exists(STATUS_CHARACTER_ICON_PATH):
			_status_char_icon.texture = load(STATUS_CHARACTER_ICON_PATH) as Texture2D
	var name_node: Node = layout.get_node_or_null("CharacterInfo/CharacterName")
	if name_node is Label:
		_status_char_name = name_node as Label
	var meta_node: Node = layout.get_node_or_null("CharacterInfo/CharacterMeta")
	if meta_node is Label:
		_status_char_meta = meta_node as Label
	var grid: Node = layout.get_node_or_null("StatsSection/StatsGrid")
	if grid != null:
		_hp_label = _get_label(grid, "HPValue")
		_sp_label = _get_label(grid, "SPValue")
		_gold_label = _get_label(grid, "GoldValue")
		_xp_label = _get_label(grid, "XPValue")
		_mobk_label = _get_label(grid, "MobKValue")
		_pvpk_label = _get_label(grid, "PvPValue")
	var affects_node: Node = layout.get_node_or_null("StatsSection/AffectsRow/AffectsValue")
	if affects_node is Label:
		_affects_label = affects_node as Label
	return _status_char_name != null


func _get_label(parent: Node, node_name: String) -> Label:
	var node: Node = parent.get_node_or_null(node_name)
	return node as Label if node is Label else null


func _build_dynamic_ui() -> void:
	$Status_BG/TextDisplay.visible = false
	var bg: Panel = $Status_BG
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "StatusLayout"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 8)
	bg.add_child(hbox)

	_status_char_icon = TextureRect.new()
	_status_char_icon.custom_minimum_size = Vector2(48.0, 48.0)
	_status_char_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_status_char_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_status_char_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_status_char_icon)

	var name_vbox: VBoxContainer = VBoxContainer.new()
	name_vbox.add_theme_constant_override("separation", 2)
	name_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(name_vbox)

	_status_char_name = Label.new()
	name_vbox.add_child(_status_char_name)
	_status_char_meta = Label.new()
	name_vbox.add_child(_status_char_meta)

	var vitals_label: RichTextLabel = RichTextLabel.new()
	vitals_label.bbcode_enabled = true
	vitals_label.scroll_active = false
	vitals_label.fit_content = true
	vitals_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vitals_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(vitals_label)


func apply_gmcp(topic: String, data: Variant, gmcp_state: Dictionary) -> void:
	if topic != "Char" \
			and topic != "Char.Vitals" \
			and topic != "Char.Worth" \
			and topic != "Char.Kills" \
			and topic != "Char.Affects" \
			and not topic.begins_with("Char.Info"):
		return

	var char_data: Dictionary = gmcp_state.get("Char", {})
	var data_dict: Dictionary = data if data is Dictionary else {}
	var info_fb: Dictionary = data_dict if topic.begins_with("Char.Info") else {}
	var info: Dictionary = char_data.get("Info", info_fb)
	var vitals: Dictionary = char_data.get("Vitals", data_dict if topic == "Char.Vitals" else {})
	var worth: Dictionary = char_data.get("Worth", data_dict if topic == "Char.Worth" else {})
	var kills: Dictionary = char_data.get("Kills", data_dict if topic == "Char.Kills" else {})
	var affects: Dictionary = char_data.get("Affects", data_dict if topic == "Char.Affects" else {})

	if not info.is_empty():
		if _status_char_name != null:
			_status_char_name.text = str(info.get("name", ""))
		if _status_char_meta != null:
			var race: String = str(info.get("race", ""))
			var job: String = str(info.get("class", ""))
			_status_char_meta.text = "%s %s" % [race, job]
		if _status_char_icon != null:
			_status_char_icon.texture = _resolve_portrait_texture(info)

	if not vitals.is_empty():
		if _hp_label != null:
			_hp_label.text = "%s/%s" % [vitals.get("hp", "?"), vitals.get("hp_max", "?")]
		if _sp_label != null:
			_sp_label.text = "%s/%s" % [vitals.get("sp", "?"), vitals.get("sp_max", "?")]

	if not worth.is_empty():
		if _gold_label != null:
			_gold_label.text = str(worth.get("gold_carry", 0))
		if _xp_label != null:
			_xp_label.text = "%s/%s" % [worth.get("xp", 0), worth.get("tnl", 0)]

	if not kills.is_empty():
		var mob: Dictionary = kills.get("mob", {})
		var pvp: Dictionary = kills.get("pvp", {})
		if _mobk_label != null and not mob.is_empty():
			_mobk_label.text = str(mob.get("total", 0))
		if _pvpk_label != null and not pvp.is_empty():
			_pvpk_label.text = str(pvp.get("total", 0))

	if not affects.is_empty() and _affects_label != null:
		var names: Array[String] = []
		for key: String in affects.keys():
			names.append(str(key))
		_affects_label.text = ", ".join(names) if not names.is_empty() else "-"


func _resolve_portrait_texture(info: Dictionary) -> Texture2D:
	var race: String = str(info.get("race", "")).to_lower().strip_edges()
	var job: String = str(info.get("class", "")).to_lower().strip_edges()
	for prefix: String in PROFESSION_RANK_PREFIXES:
		if job.begins_with(prefix + " "):
			job = job.substr(prefix.length() + 1).strip_edges()
	if race != "" and job != "":
		var path: String = "%s/%s_%s.png" % [PLAYER_PORTRAIT_DIR, race, job]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	if ResourceLoader.exists(STATUS_CHARACTER_ICON_PATH):
		return load(STATUS_CHARACTER_ICON_PATH) as Texture2D
	return null

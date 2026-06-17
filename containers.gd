class_name ContainersController
extends Node2D

const ITEM_ICON_BY_ID_DIR: String = "res://assets/items/by_id"
const MOB_ICON_BY_NAME_DIR: String = "res://assets/mobs/by_name"
const PLAYER_PORTRAIT_BY_RACE_CLASS_DIR: String = "res://assets/player_portraits/by_race_class"
const ITEM_METADATA_PATH: String = "res://data/item_metadata.json"
const STATUS_CHARACTER_ICON_PATH: String = "res://assets/ui/status_icons/status.png"
const STATUS_ICON_PATHS: Dictionary = {
	"Alignment": "res://assets/ui/status_icons/alignment.png",
	"SkillPoints": "res://assets/ui/status_icons/skills.png",
	"TrainingPoints": "res://assets/ui/status_icons/training.png",
	"Attributes": "res://assets/ui/status_icons/status.png",
	"HP": "res://assets/ui/status_icons/hp.png",
	"SP": "res://assets/ui/status_icons/sp.png",
	"Gold": "res://assets/ui/status_icons/gold.png",
	"Bank": "res://assets/ui/status_icons/bank.png",
	"XP": "res://assets/ui/status_icons/xp.png",
	"TNL": "res://assets/ui/status_icons/xp.png",
	"Affects": "res://assets/ui/status_icons/affects.png",
	"MobKills": "res://assets/ui/status_icons/MobK.png",
	"PvpKills": "res://assets/ui/status_icons/pvpk.png",
}
const DEFAULT_ITEM_ICON_PATH: String = "res://assets/items/default_item.png"
const ATTRIBUTE_SPECS := [
	{"key": "Strength", "label": "STR"},
	{"key": "Speed",    "label": "SPD"},
	{"key": "Smarts",   "label": "SMT"},
	{"key": "Vitality", "label": "VIT"},
	{"key": "Mysticism","label": "MYS"},
	{"key": "Perception","label": "PER"},
]
const DEFAULT_MOB_ICON_PATH: String = "res://assets/mobs/default_mob.png"
const EMPTY_ITEM_ICON_PATH: String = "res://assets/items/empty_slot.png"
const EMPTY_ITEM_NAME: String = "-nothing-"
const EQUIPMENT_SLOT_ORDER: Array[String] = [
	"head",
	"neck",
	"body",
	"gloves",
	"ring",
	"belt",
	"legs",
	"feet",
	"weapon",
	"offhand",
]
const EQUIPMENT_GRID_COLUMNS: int = 5
const BACKPACK_GRID_COLUMNS: int = 5
const INVENTORY_GRID_GAP: int = 6
const INVENTORY_PANEL_MARGIN: float = 12.0
const INVENTORY_SCROLLBAR_GUTTER: float = 28.0
const INVENTORY_DETAIL_HEIGHT: float = 120.0
const INVENTORY_ACTION_LOOK: int = 1
const INVENTORY_ACTION_INSPECT: int = 2
const INVENTORY_ACTION_EQUIP: int = 3
const INVENTORY_ACTION_REMOVE: int = 4
const INVENTORY_ACTION_USE: int = 5
const INVENTORY_ACTION_DRINK: int = 6
const INVENTORY_ACTION_EAT: int = 7
const INVENTORY_ACTION_DROP: int = 8
const MAX_OPEN_CONTAINERS: int = 3
const PROFESSION_RANK_PREFIXES: Array[String] = [
	"novice",
	"apprentice",
	"journeyman",
	"adept",
	"expert",
	"master",
	"grandmaster",
]

signal button_commands_submitted(data: String)

var _equipment_root: VBoxContainer = null
var _equipment_scroll: ScrollContainer = null
var _equipment_title: Label = null
var _equipment_grid: GridContainer = null
var _backpack_title: Label = null
var _backpack_grid: GridContainer = null
var _equipment_detail: RichTextLabel = null
var _backpack_equipment_uses_scene_ui: bool = false
var _status_panel: Control = null
var _status_root: VBoxContainer = null
var _status_character_icon: TextureRect = null
var _status_character_name: Label = null
var _status_character_meta: Label = null
var _status_value_labels: Dictionary = {}
var _status_icon_nodes: Dictionary = {}
var _skills_gmcp: Control = null
var _skills_jobs_list: VBoxContainer = null
var _skills_list: VBoxContainer = null
var _skills_summary: Label = null
var _spells_gmcp: Control = null
var _spells_list: VBoxContainer = null
var _spells_summary: Label = null
var _player_equipment_scroll: ScrollContainer = null
var _player_equipment_root: VBoxContainer = null
var _player_equipment_grid: GridContainer = null
var _player_equipment_detail: RichTextLabel = null
var _npc_look_header: VBoxContainer = null
var _npc_look_icon: TextureRect = null
var _npc_look_description: RichTextLabel = null
var _npc_look_actions: HBoxContainer = null
var _npc_look_scroll: ScrollContainer = null
var _npc_look_root: VBoxContainer = null
var _npc_look_grid: GridContainer = null
var _npc_look_detail: RichTextLabel = null
var _inventory_slot_size: Vector2 = Vector2(112.0, 82.0)
var _inventory_icon_size: Vector2 = Vector2(42.0, 42.0)
var _item_metadata_by_id: Dictionary = {}
var _item_metadata_loaded: bool = false
var _pending_npc_look_context: Dictionary = {}
var _pending_npc_look_description: Dictionary = {}
var _open_container_order: Array[String] = []
	
func _ready() -> void:
	$Backpack.visible = false
	$Equipment.visible = false
	$Attributes.visible = false
	$Skills.visible = false
	$Spells.visible = false
	if has_node("NpcLook"):
		$NpcLook.visible = false
	_configure_text_popup($Skills/TextDisplay)
	_configure_text_popup($Spells/TextDisplay)
	_ensure_equipment_ui()
	_ensure_status_ui()
	_ensure_skills_ui()
	_ensure_spells_ui()
	_ensure_player_equipment_ui()
	_ensure_npc_look_ui()
	var text_processor: Variant = $"../TextProcessor"
	text_processor.container_request.connect(_on_container_request_received)
	if text_processor.has_signal("npc_look_description"):
		text_processor.npc_look_description.connect(_on_npc_look_description_received)


func _configure_text_popup(label: RichTextLabel) -> void:
	label.bbcode_enabled = true
	label.scroll_active = true
	label.fit_content = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _on_backpack_button_pressed() -> void:
	button_commands_submitted.emit("/ui inventory")
	
func _on_status_button_pressed() -> void:
	button_commands_submitted.emit("/ui status")


func _on_equipment_button_pressed() -> void:
	button_commands_submitted.emit("/ui equipment")
	
func _on_skills_button_pressed() -> void:
	button_commands_submitted.emit("/ui skills")

func _on_spells_button_pressed() -> void:
	button_commands_submitted.emit("spells")

func clean_unwanted_symbols(data: String) -> String:
	data = data.replace(".:", "")
	return data

func _close_all_containers() -> void:
	$Backpack.visible = false
	$Equipment.visible = false
	$Attributes.visible = false
	$Skills.visible = false
	$Spells.visible = false
	if has_node("NpcLook"):
		$NpcLook.visible = false
	_open_container_order.clear()


func _close_container(key: String) -> void:
	var panel: CanvasItem = _container_node(key)
	if panel != null:
		panel.visible = false
	_open_container_order.erase(key)


func _show_container(key: String, mark_recent: bool = true) -> void:
	var panel: CanvasItem = _container_node(key)
	if panel == null:
		return
	panel.visible = true
	if panel.has_method("move_to_front"):
		panel.move_to_front()
	if not mark_recent:
		return
	_open_container_order.erase(key)
	_open_container_order.append(key)
	while _open_container_order.size() > MAX_OPEN_CONTAINERS:
		var oldest_key: String = _open_container_order.pop_front()
		var oldest_panel: CanvasItem = _container_node(oldest_key)
		if oldest_panel != null:
			oldest_panel.visible = false


func _toggle_container(key: String) -> void:
	var panel: CanvasItem = _container_node(key)
	if panel == null:
		return
	if panel.visible:
		_close_container(key)
	else:
		_show_container(key)


func _container_node(key: String) -> CanvasItem:
	match key:
		"backpack":
			return $Backpack
		"equipment":
			return $Equipment
		"status":
			return $Attributes
		"skills":
			return $Skills
		"spells":
			return $Spells
		"npc_look":
			return $NpcLook if has_node("NpcLook") else null
		_:
			return null

func _on_container_request_received(data: String, type: String) -> void:
	data = clean_unwanted_symbols(data)
	if type == "equipment":
		if not _pending_npc_look_description.is_empty():
			if show_npc_look_text(_pending_npc_look_description, data):
				_pending_npc_look_description = {}
				return
			_pending_npc_look_description = {}
		if show_equipment_text(data):
			return
		_set_equipment_ui_visible(false)
		return
	
	if type == "status":
		_set_status_gmcp_visible(true)
		_show_container("status")
	
	if type == "skills":
		data = organize_skills(data)
		$Skills/TextDisplay.text = data
		$Skills/TextDisplay.visible = true
		if _skills_gmcp != null:
			_skills_gmcp.visible = false
		_show_container("skills")
	
	if type == "spells":
		data = organize_spells(data)
		if not show_spells_text(data):
			$Spells/TextDisplay.text = data
			$Spells/TextDisplay.visible = true
			if _spells_gmcp != null:
				_spells_gmcp.visible = false
			_show_container("spells")


func show_spells_text(data: String, mark_recent: bool = true) -> bool:
	_ensure_spells_ui()
	var spells: Array[Dictionary] = _parse_spells_text(data)
	if spells.is_empty() or not _has_spells_visual_ui():
		return false
	_populate_spells_visual_ui(spells)
	if has_node("Spells/TextDisplay"):
		$Spells/TextDisplay.visible = false
	if _spells_gmcp != null:
		_spells_gmcp.visible = true
	if $Spells.has_node("Move"):
		$Spells/Move.text = "Spells"
	_show_container("spells", mark_recent)
	return true

func _on_close_pressed() -> void:
	_close_all_containers()


func _on_backpack_close_pressed() -> void:
	_close_container("backpack")


func _on_equipment_close_pressed() -> void:
	_close_container("equipment")


func _on_attributes_close_pressed() -> void:
	_close_container("status")


func _on_skills_close_pressed() -> void:
	_close_container("skills")


func _on_spells_close_pressed() -> void:
	_close_container("spells")


func _on_npc_look_close_pressed() -> void:
	_close_container("npc_look")


func apply_gmcp(topic: String, _data: Variant, gmcp_state: Dictionary) -> void:
	if topic == "Char" or topic.begins_with("Char.Inventory"):
		if $Backpack.visible:
			show_equipment_gmcp(gmcp_state, false)
		if $Equipment.visible:
			show_player_equipment_gmcp(gmcp_state, false)
	if topic == "Char" or topic.begins_with("Char.Info") or topic.begins_with("Char.Stats"):
		if $Attributes.visible:
			show_status_gmcp(gmcp_state, false)
	if topic == "Char" or topic.begins_with("Char.Skills") or topic.begins_with("Char.Jobs"):
		if $Skills.visible:
			show_skills_gmcp(gmcp_state, false)


func show_equipment_gmcp(gmcp_state: Dictionary, mark_recent: bool = true) -> void:
	var char_data: Dictionary = _char_data(gmcp_state)
	var inventory: Dictionary = char_data.get("Inventory", {})
	var backpack: Dictionary = inventory.get("Backpack", {})
	_ensure_equipment_ui()
	_sync_backpack_child_widths()
	_set_backpack_title("Backpack")
	_set_inventory_sections_visible(false, true, false)
	_set_equipment_ui_visible(true)
	_populate_backpack_grid(backpack)
	_show_container("backpack", mark_recent)


func show_player_equipment_gmcp(gmcp_state: Dictionary, mark_recent: bool = true) -> void:
	var char_data: Dictionary = _char_data(gmcp_state)
	var inventory: Dictionary = char_data.get("Inventory", {})
	var worn: Dictionary = inventory.get("Worn", {})
	_ensure_player_equipment_ui()
	_layout_player_equipment_ui()
	_populate_player_equipment_grid(worn)
	_show_container("equipment", mark_recent)


func show_equipment_text(data: String) -> bool:
	var worn: Dictionary = _parse_legacy_equipment_text(data)
	if worn.is_empty():
		return false
	_ensure_player_equipment_ui()
	_layout_player_equipment_ui()
	_clear_children(_player_equipment_grid)
	var rendered_slots: Dictionary = {}
	for slot: String in EQUIPMENT_SLOT_ORDER:
		rendered_slots[slot] = true
		var item: Dictionary = _dictionary_or_empty(worn.get(slot, {}))
		_player_equipment_grid.add_child(_make_equipment_slot_cell(slot.capitalize(), item, "display", _player_equipment_detail))
	for slot: String in _sorted_string_keys(worn):
		if rendered_slots.has(slot):
			continue
		var item: Dictionary = _dictionary_or_empty(worn.get(slot, {}))
		_player_equipment_grid.add_child(_make_equipment_slot_cell(slot.capitalize(), item, "display", _player_equipment_detail))
	if _player_equipment_detail != null:
		_player_equipment_detail.text = "Legacy equipment output"
	_show_container("equipment")
	return true


func set_pending_npc_look_context(context: Dictionary) -> void:
	_pending_npc_look_context = context.duplicate(true)
	_pending_npc_look_description = {}


func clear_pending_npc_look() -> void:
	_pending_npc_look_context = {}
	_pending_npc_look_description = {}


func _on_npc_look_description_received(data: Dictionary) -> void:
	_pending_npc_look_description = data.duplicate(true)
	if has_node("NpcLook") and $NpcLook.visible:
		_update_npc_look_header(_pending_npc_look_description, _pending_npc_look_context)


func show_npc_look_text(description_data: Dictionary, equipment_text: String) -> bool:
	var worn: Dictionary = _parse_legacy_equipment_text(equipment_text)
	_ensure_npc_look_ui()
	var context: Dictionary = _pending_npc_look_context.duplicate(true)
	var name: String = _npc_look_name(description_data, context)
	if $NpcLook.has_node("Move"):
		$NpcLook/Move.text = name if name != "" else "NPC"
	_update_npc_look_header(description_data, context)
	_populate_npc_look_equipment_grid(worn)
	if _npc_look_detail != null:
		_npc_look_detail.text = "Select NPC equipment to view details."
	_show_container("npc_look")
	return true


func show_status_gmcp(gmcp_state: Dictionary, mark_recent: bool = true) -> void:
	var char_data: Dictionary = _char_data(gmcp_state)
	var info: Dictionary = char_data.get("Info", {})
	var stats: Dictionary = char_data.get("Stats", {})
	_ensure_status_ui()
	_set_status_gmcp_visible(true)
	if $Attributes.has_node("Move"):
		$Attributes/Move.text = "Score"
	_update_status_summary_ui(info, stats)
	_show_container("status", mark_recent)


func show_skills_gmcp(gmcp_state: Dictionary, mark_recent: bool = true) -> void:
	var char_data: Dictionary = _char_data(gmcp_state)
	var skills: Variant = char_data.get("Skills", [])
	var jobs: Variant = char_data.get("Jobs", [])
	_ensure_skills_ui()
	if _has_skills_visual_ui():
		_populate_skills_visual_ui(skills, jobs)
		if has_node("Skills/TextDisplay"):
			$Skills/TextDisplay.visible = false
		if _skills_gmcp != null:
			_skills_gmcp.visible = true
		if $Skills.has_node("Move"):
			$Skills/Move.text = "Skills"
		_show_container("skills", mark_recent)
		return
	var lines: Array[String] = ["Skills / Jobs"]
	if skills is Array and not skills.is_empty():
		lines.append("Skills:")
		for skill: Variant in skills:
			if skill is Dictionary:
				var suffix: String = " (max)" if skill.get("maximum", false) else ""
				lines.append("- %s: %s%s" % [skill.get("name", ""), skill.get("level", "?"), suffix])
	if jobs is Array and not jobs.is_empty():
		lines.append("Jobs:")
		for job: Variant in jobs:
			if job is Dictionary:
				lines.append("- %s: %s (%s%%)" % [job.get("name", ""), job.get("proficiency", ""), job.get("completion", 0)])
	if lines.size() == 1:
		lines.append("- no skill or job data")
	$Skills/TextDisplay.text = "\n".join(lines)
	_show_container("skills", mark_recent)


func _ensure_skills_ui() -> void:
	if _skills_gmcp != null:
		return
	if _bind_skills_scene_ui():
		return

	_skills_gmcp = Control.new()
	_skills_gmcp.name = "SkillsGMCP"
	_skills_gmcp.offset_left = 16.0
	_skills_gmcp.offset_top = 34.0
	_skills_gmcp.offset_right = 781.0
	_skills_gmcp.offset_bottom = 218.0
	$Skills.add_child(_skills_gmcp)

	var root: HBoxContainer = HBoxContainer.new()
	root.name = "SkillsContent"
	root.offset_right = 765.0
	root.offset_bottom = 184.0
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	_skills_gmcp.add_child(root)

	var jobs_section: VBoxContainer = _make_skills_section("Jobs", 470.0)
	root.add_child(jobs_section)
	_skills_jobs_list = VBoxContainer.new()
	_skills_jobs_list.name = "JobsList"
	_skills_jobs_list.add_theme_constant_override("separation", 4)
	jobs_section.add_child(_make_skills_scroll("JobsScroll", _skills_jobs_list))

	var skills_section: VBoxContainer = _make_skills_section("Skills", 260.0)
	root.add_child(skills_section)
	_skills_summary = Label.new()
	_skills_summary.name = "SkillsSummary"
	_skills_summary.add_theme_font_size_override("font_size", 13)
	_skills_summary.add_theme_color_override("font_color", Color(0.68, 0.88, 1.0, 1.0))
	_skills_summary.clip_text = true
	skills_section.add_child(_skills_summary)
	_skills_list = VBoxContainer.new()
	_skills_list.name = "SkillsList"
	_skills_list.add_theme_constant_override("separation", 4)
	skills_section.add_child(_make_skills_scroll("SkillsScroll", _skills_list))


func _bind_skills_scene_ui() -> bool:
	var panel_node: Node = $Skills.get_node_or_null("SkillsGMCP")
	if not panel_node is Control:
		return false
	var panel: Control = panel_node
	_skills_gmcp = panel
	var jobs_node: Node = _skills_gmcp.get_node_or_null("SkillsContent/JobsSection/JobsScroll/JobsList")
	var skills_node: Node = _skills_gmcp.get_node_or_null("SkillsContent/SkillsSection/SkillsScroll/SkillsList")
	var summary_node: Node = _skills_gmcp.get_node_or_null("SkillsContent/SkillsSection/SkillsSummary")
	if jobs_node is VBoxContainer:
		var jobs_list: VBoxContainer = jobs_node as VBoxContainer
		_skills_jobs_list = jobs_list
	if skills_node is VBoxContainer:
		var skills_list: VBoxContainer = skills_node as VBoxContainer
		_skills_list = skills_list
	if summary_node is Label:
		var summary_label: Label = summary_node as Label
		_skills_summary = summary_label
	return _has_skills_visual_ui()


func _has_skills_visual_ui() -> bool:
	return _skills_gmcp != null and _skills_jobs_list != null and _skills_list != null


func _make_skills_section(title: String, width: float) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.name = title + "Section"
	section.custom_minimum_size = Vector2(width, 0.0)
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 5)
	var label: Label = Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42, 1.0))
	section.add_child(label)
	return section


func _make_skills_scroll(scroll_name: String, content: Control) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = scroll_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.add_child(content)
	return scroll


func _populate_skills_visual_ui(skills: Variant, jobs: Variant) -> void:
	_clear_children(_skills_jobs_list)
	_clear_children(_skills_list)
	var job_items: Array[Dictionary] = _dictionary_array(jobs)
	var skill_items: Array[Dictionary] = _dictionary_array(skills)
	if _skills_summary != null:
		_skills_summary.text = "%d skills   %d jobs" % [skill_items.size(), job_items.size()]
	if job_items.is_empty():
		_skills_jobs_list.add_child(_make_empty_skills_row("No job data"))
	else:
		for job: Dictionary in job_items:
			_skills_jobs_list.add_child(_make_job_progress_row(job))
	if skill_items.is_empty():
		_skills_list.add_child(_make_empty_skills_row("No skill data"))
	else:
		for skill: Dictionary in skill_items:
			_skills_list.add_child(_make_skill_row(skill))


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if value is Array:
		for item: Variant in value:
			if item is Dictionary:
				items.append(item)
	return items


func _make_job_progress_row(job: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _skills_row_style())
	panel.custom_minimum_size = Vector2(0.0, 34.0)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var name_label: Label = _make_skills_label(str(job.get("name", "unknown")).capitalize(), Color(0.90, 0.94, 1.0, 1.0), 13)
	name_label.custom_minimum_size = Vector2(132.0, 0.0)
	name_label.clip_text = true
	row.add_child(name_label)

	var proficiency_label: Label = _make_skills_label(str(job.get("proficiency", "?")), Color(1.0, 0.86, 0.42, 1.0), 13)
	proficiency_label.custom_minimum_size = Vector2(78.0, 0.0)
	proficiency_label.clip_text = true
	row.add_child(proficiency_label)

	var progress: ProgressBar = ProgressBar.new()
	progress.custom_minimum_size = Vector2(120.0, 16.0)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.show_percentage = false
	progress.min_value = 0.0
	progress.max_value = 100.0
	progress.value = _completion_percent(job.get("completion", 0.0))
	row.add_child(progress)

	var percent_label: Label = _make_skills_label("%d%%" % int(round(progress.value)), Color(0.68, 0.88, 1.0, 1.0), 12)
	percent_label.custom_minimum_size = Vector2(42.0, 0.0)
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(percent_label)
	return panel


func _make_skill_row(skill: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _skills_row_style())
	panel.custom_minimum_size = Vector2(0.0, 30.0)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var name_label: Label = _make_skills_label(str(skill.get("name", "unknown")).capitalize(), Color(0.90, 0.94, 1.0, 1.0), 13)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)

	var level_text: String = str(skill.get("level", "?"))
	if bool(skill.get("maximum", false)):
		level_text += " max"
	var level_label: Label = _make_skills_label(level_text, Color(1.0, 0.86, 0.42, 1.0), 13)
	level_label.custom_minimum_size = Vector2(58.0, 0.0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(level_label)
	return panel


func _make_empty_skills_row(text: String) -> Label:
	var label: Label = _make_skills_label(text, Color(0.58, 0.62, 0.68, 1.0), 13)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0.0, 28.0)
	return label


func _make_skills_label(text: String, color: Color, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _skills_row_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.055, 0.065, 0.95)
	style.border_color = Color(0.22, 0.30, 0.34, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6.0
	style.content_margin_top = 4.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 4.0
	return style


func _completion_percent(value: Variant) -> float:
	var number: float = float(value)
	if number <= 1.0:
		return clamp(number * 100.0, 0.0, 100.0)
	return clamp(number, 0.0, 100.0)


func _ensure_spells_ui() -> void:
	if _spells_gmcp != null:
		return
	if _bind_spells_scene_ui():
		return

	_spells_gmcp = Control.new()
	_spells_gmcp.name = "SpellsGMCP"
	_spells_gmcp.offset_left = 16.0
	_spells_gmcp.offset_top = 33.0
	_spells_gmcp.offset_right = 778.0
	_spells_gmcp.offset_bottom = 217.0
	$Spells.add_child(_spells_gmcp)

	var root: VBoxContainer = VBoxContainer.new()
	root.name = "SpellsContent"
	root.offset_right = 762.0
	root.offset_bottom = 184.0
	root.add_theme_constant_override("separation", 6)
	_spells_gmcp.add_child(root)

	_spells_summary = Label.new()
	_spells_summary.name = "SpellsSummary"
	_spells_summary.add_theme_font_size_override("font_size", 13)
	_spells_summary.add_theme_color_override("font_color", Color(0.68, 0.88, 1.0, 1.0))
	root.add_child(_spells_summary)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "SpellsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	root.add_child(scroll)

	_spells_list = VBoxContainer.new()
	_spells_list.name = "SpellsList"
	_spells_list.custom_minimum_size = Vector2(720.0, 0.0)
	_spells_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_spells_list)


func _bind_spells_scene_ui() -> bool:
	var panel_node: Node = $Spells.get_node_or_null("SpellsGMCP")
	if not panel_node is Control:
		return false
	_spells_gmcp = panel_node as Control
	var list_node: Node = _spells_gmcp.get_node_or_null("SpellsContent/SpellsScroll/SpellsList")
	var summary_node: Node = _spells_gmcp.get_node_or_null("SpellsContent/SpellsSummary")
	if list_node is VBoxContainer:
		_spells_list = list_node as VBoxContainer
	if summary_node is Label:
		_spells_summary = summary_node as Label
	return _has_spells_visual_ui()


func _has_spells_visual_ui() -> bool:
	return _spells_gmcp != null and _spells_list != null


func _populate_spells_visual_ui(spells: Array[Dictionary]) -> void:
	_clear_children(_spells_list)
	if _spells_summary != null:
		_spells_summary.text = "%d known spells" % spells.size()
	for spell: Dictionary in spells:
		_spells_list.add_child(_make_spell_row(spell))


func _parse_spells_text(data: String) -> Array[Dictionary]:
	var spells: Array[Dictionary] = []
	for raw_line: String in _visible_text_lines(data):
		var line: String = raw_line.strip_edges()
		if line == "" or line.find("|") == -1:
			continue
		var columns: PackedStringArray = line.split("|", false)
		var cells: Array[String] = []
		for column: String in columns:
			var cell: String = _normalize_spaces(column)
			if cell != "":
				cells.append(cell)
		if cells.size() < 8:
			continue
		if cells[0].to_lower() == "spellid" or cells[0] == "-":
			continue
		if cells[4].is_valid_int() or cells[4].is_valid_float():
			spells.append({
				"id": cells[0],
				"name": cells[1],
				"description": cells[2],
				"target": cells[3],
				"mp": cells[4],
				"wait": cells[5],
				"casts": cells[6],
				"chance": cells[7],
			})
	return spells


func _make_spell_row(spell: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _spell_row_style(str(spell.get("target", ""))))
	panel.custom_minimum_size = Vector2(0.0, 48.0)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var text_box: VBoxContainer = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 1)
	row.add_child(text_box)

	var top_line: HBoxContainer = HBoxContainer.new()
	top_line.add_theme_constant_override("separation", 8)
	text_box.add_child(top_line)

	var name_label: Label = _make_skills_label(str(spell.get("name", "unknown")), Color(0.90, 0.94, 1.0, 1.0), 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	top_line.add_child(name_label)

	var target_label: Label = _make_skills_label(str(spell.get("target", "")), _spell_target_color(str(spell.get("target", ""))), 12)
	target_label.custom_minimum_size = Vector2(86.0, 0.0)
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	target_label.clip_text = true
	top_line.add_child(target_label)

	var desc_label: Label = _make_skills_label(str(spell.get("description", "")), Color(0.62, 0.68, 0.74, 1.0), 12)
	desc_label.clip_text = true
	text_box.add_child(desc_label)

	var meta_label: Label = _make_skills_label("MP %s   Wait %s   Casts %s   Chance %s" % [
		spell.get("mp", "?"),
		spell.get("wait", "?"),
		spell.get("casts", "?"),
		spell.get("chance", "?"),
	], Color(1.0, 0.86, 0.42, 1.0), 12)
	meta_label.clip_text = true
	text_box.add_child(meta_label)

	var cast_button: Button = Button.new()
	cast_button.text = "Cast"
	cast_button.custom_minimum_size = Vector2(58.0, 34.0)
	cast_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cast_button.pressed.connect(_on_spell_cast_pressed.bind(str(spell.get("id", ""))))
	row.add_child(cast_button)
	return panel


func _spell_row_style(target: String) -> StyleBoxFlat:
	var style: StyleBoxFlat = _skills_row_style()
	style.border_color = _spell_target_color(target)
	style.bg_color = Color(0.045, 0.050, 0.060, 0.96)
	return style


func _spell_target_color(target: String) -> Color:
	var normalized: String = target.to_lower()
	if normalized.find("harm") != -1 or normalized.find("enemy") != -1:
		return Color(0.90, 0.22, 0.18, 1.0)
	if normalized.find("help") != -1 or normalized.find("ally") != -1:
		return Color(0.32, 0.82, 0.55, 1.0)
	return Color(0.62, 0.72, 1.0, 1.0)


func _on_spell_cast_pressed(spell_id: String) -> void:
	var clean_id: String = spell_id.strip_edges()
	if clean_id == "":
		return
	button_commands_submitted.emit("cast " + clean_id)


func show_affects_gmcp(gmcp_state: Dictionary) -> void:
	show_status_gmcp(gmcp_state)


func show_kills_gmcp(gmcp_state: Dictionary) -> void:
	show_status_gmcp(gmcp_state)


func _char_data(gmcp_state: Dictionary) -> Dictionary:
	return gmcp_state.get("Char", {})


func _ensure_equipment_ui() -> void:
	if _equipment_root != null:
		return
	if _bind_backpack_equipment_scene_ui():
		return

	_backpack_equipment_uses_scene_ui = false
	_equipment_scroll = ScrollContainer.new()
	_equipment_scroll.name = "BackpackGMCP"
	_equipment_scroll.visible = false
	_equipment_scroll.offset_left = INVENTORY_PANEL_MARGIN
	_equipment_scroll.offset_top = 34.0
	_equipment_scroll.offset_right = 648.0
	_equipment_scroll.offset_bottom = 570.0
	_equipment_scroll.follow_focus = true
	$Backpack.add_child(_equipment_scroll)

	_equipment_root = VBoxContainer.new()
	_equipment_root.name = "BackpackContent"
	_equipment_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equipment_root.add_theme_constant_override("separation", 8)
	_equipment_scroll.add_child(_equipment_root)

	_backpack_grid = GridContainer.new()
	_backpack_grid.name = "BackpackGrid"
	_backpack_grid.columns = BACKPACK_GRID_COLUMNS
	_backpack_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_backpack_grid.add_theme_constant_override("h_separation", INVENTORY_GRID_GAP)
	_backpack_grid.add_theme_constant_override("v_separation", INVENTORY_GRID_GAP)
	_equipment_root.add_child(_backpack_grid)

	_equipment_detail = RichTextLabel.new()
	_equipment_detail.name = "BackpackDetail"
	_equipment_detail.visible = false
	_equipment_detail.custom_minimum_size = Vector2(0.0, INVENTORY_DETAIL_HEIGHT)
	_equipment_detail.bbcode_enabled = true
	_equipment_detail.scroll_active = true
	_equipment_detail.fit_content = false
	$Backpack.add_child(_equipment_detail)


func _bind_backpack_equipment_scene_ui() -> bool:
	var scroll: ScrollContainer = $Backpack.get_node_or_null("BackpackGMCP")
	if scroll == null:
		return false
	var root: VBoxContainer = scroll.get_node_or_null("BackpackContent")
	var backpack_grid: GridContainer = scroll.get_node_or_null("BackpackContent/BackpackGrid")
	var detail: RichTextLabel = $Backpack.get_node_or_null("BackpackDetail")
	if root == null or backpack_grid == null or detail == null:
		return false

	_backpack_equipment_uses_scene_ui = true
	_equipment_scroll = scroll
	_equipment_root = root
	_equipment_title = null
	_equipment_grid = null
	_backpack_title = null
	_backpack_grid = backpack_grid
	_equipment_detail = detail
	_npc_look_header = null
	_npc_look_icon = null
	_npc_look_description = null
	_npc_look_actions = null

	_equipment_scroll.visible = false
	_equipment_scroll.follow_focus = true
	_backpack_grid.columns = BACKPACK_GRID_COLUMNS
	_equipment_detail.visible = false
	_equipment_detail.bbcode_enabled = true
	_equipment_detail.scroll_active = true
	_equipment_detail.fit_content = false
	_equipment_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return true


func _ensure_status_ui() -> void:
	if _status_root != null:
		return

	if _bind_status_scene_ui():
		return

	_status_panel = Control.new()
	_status_panel.name = "AttributesGMCP"
	_status_panel.visible = false
	$Attributes.add_child(_status_panel)

	_status_root = VBoxContainer.new()
	_status_root.name = "AttributesContent"
	_status_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_root.add_theme_constant_override("separation", 8)
	_status_panel.add_child(_status_root)

func _bind_status_scene_ui() -> bool:
	var panel_node: Node = $Attributes.get_node_or_null("AttributesGMCP")
	if not panel_node is Control:
		return false
	var panel: Control = panel_node
	var root_node: Node = panel.get_node_or_null("AttributesContent")
	if not root_node is VBoxContainer:
		return false
	var root: VBoxContainer = root_node

	_status_panel = panel
	_status_root = root
	_bind_status_visual_nodes(panel)
	return true


func _ensure_player_equipment_ui() -> void:
	if _player_equipment_root != null:
		return
	if _bind_player_equipment_scene_ui():
		_layout_player_equipment_ui()
		return

	_player_equipment_scroll = ScrollContainer.new()
	_player_equipment_scroll.name = "EquipmentGMCP"
	_player_equipment_scroll.visible = true
	_player_equipment_scroll.follow_focus = true
	$Equipment.add_child(_player_equipment_scroll)

	_player_equipment_root = VBoxContainer.new()
	_player_equipment_root.name = "EquipmentContent"
	_player_equipment_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_equipment_root.add_theme_constant_override("separation", 8)
	_player_equipment_scroll.add_child(_player_equipment_root)

	var equipment_title: Label = _make_section_label("Equipment")
	equipment_title.name = "EquipmentTitle"
	_player_equipment_root.add_child(equipment_title)

	_player_equipment_grid = GridContainer.new()
	_player_equipment_grid.name = "EquipmentGrid"
	_player_equipment_grid.columns = EQUIPMENT_GRID_COLUMNS
	_player_equipment_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_player_equipment_grid.add_theme_constant_override("h_separation", INVENTORY_GRID_GAP)
	_player_equipment_grid.add_theme_constant_override("v_separation", INVENTORY_GRID_GAP)
	_player_equipment_root.add_child(_player_equipment_grid)

	_player_equipment_detail = RichTextLabel.new()
	_player_equipment_detail.name = "EquipmentDetail"
	_player_equipment_detail.bbcode_enabled = true
	_player_equipment_detail.scroll_active = true
	_player_equipment_detail.fit_content = false
	_player_equipment_detail.custom_minimum_size = Vector2(0.0, 92.0)
	_player_equipment_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_player_equipment_root.add_child(_player_equipment_detail)
	_layout_player_equipment_ui()


func _bind_player_equipment_scene_ui() -> bool:
	var scroll: ScrollContainer = $Equipment.get_node_or_null("EquipmentGMCP")
	if scroll == null:
		return false
	var root: VBoxContainer = scroll.get_node_or_null("EquipmentContent")
	var equipment_grid: GridContainer = scroll.get_node_or_null("EquipmentContent/EquipmentGrid")
	var equipment_detail: RichTextLabel = scroll.get_node_or_null("EquipmentContent/EquipmentDetail")
	if equipment_detail == null:
		equipment_detail = $Equipment.get_node_or_null("EquipmentDetail")
	if equipment_detail == null:
		var found_detail: Node = $Equipment.find_child("EquipmentDetail", true, false)
		if found_detail is RichTextLabel:
			equipment_detail = found_detail
	if root == null or equipment_grid == null or equipment_detail == null:
		return false

	_player_equipment_scroll = scroll
	_player_equipment_root = root
	_player_equipment_grid = equipment_grid
	_player_equipment_detail = equipment_detail
	_player_equipment_scroll.follow_focus = true
	_player_equipment_grid.columns = EQUIPMENT_GRID_COLUMNS
	_player_equipment_detail.bbcode_enabled = true
	_player_equipment_detail.scroll_active = true
	_player_equipment_detail.fit_content = false
	_player_equipment_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return true


func _ensure_npc_look_ui() -> void:
	if _npc_look_root != null:
		return
	if _bind_npc_look_scene_ui():
		return

	var panel: Panel = Panel.new()
	panel.name = "NpcLook"
	panel.visible = false
	panel.offset_right = 520.0
	panel.offset_bottom = 620.0
	add_child(panel)

	_npc_look_scroll = ScrollContainer.new()
	_npc_look_scroll.name = "NpcLookGMCP"
	_npc_look_scroll.offset_left = 16.0
	_npc_look_scroll.offset_top = 38.0
	_npc_look_scroll.offset_right = 504.0
	_npc_look_scroll.offset_bottom = 500.0
	_npc_look_scroll.follow_focus = true
	panel.add_child(_npc_look_scroll)

	_npc_look_root = VBoxContainer.new()
	_npc_look_root.name = "NpcLookContent"
	_npc_look_root.add_theme_constant_override("separation", 8)
	_npc_look_scroll.add_child(_npc_look_root)
	_create_npc_look_header(_npc_look_root)

	var title: Label = _make_section_label("Equipment")
	title.name = "EquipmentTitle"
	_npc_look_root.add_child(title)

	_npc_look_grid = GridContainer.new()
	_npc_look_grid.name = "EquipmentGrid"
	_npc_look_grid.columns = EQUIPMENT_GRID_COLUMNS
	_npc_look_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_npc_look_grid.add_theme_constant_override("h_separation", INVENTORY_GRID_GAP)
	_npc_look_grid.add_theme_constant_override("v_separation", INVENTORY_GRID_GAP)
	_npc_look_root.add_child(_npc_look_grid)

	_npc_look_detail = RichTextLabel.new()
	_npc_look_detail.name = "NpcLookDetail"
	_npc_look_detail.bbcode_enabled = true
	_npc_look_detail.scroll_active = true
	_npc_look_detail.fit_content = false
	_npc_look_detail.offset_left = 16.0
	_npc_look_detail.offset_top = 508.0
	_npc_look_detail.offset_right = 504.0
	_npc_look_detail.offset_bottom = 592.0
	panel.add_child(_npc_look_detail)


func _bind_npc_look_scene_ui() -> bool:
	if not has_node("NpcLook"):
		return false
	var scroll: ScrollContainer = $NpcLook.get_node_or_null("NpcLookGMCP")
	if scroll == null:
		return false
	var root: VBoxContainer = scroll.get_node_or_null("NpcLookContent")
	var header: VBoxContainer = scroll.get_node_or_null("NpcLookContent/NpcLookHeader")
	var icon: TextureRect = scroll.get_node_or_null("NpcLookContent/NpcLookHeader/NpcLookTopRow/NpcLookIcon")
	var description: RichTextLabel = scroll.get_node_or_null("NpcLookContent/NpcLookHeader/NpcLookTopRow/NpcLookDescription")
	var actions: HBoxContainer = scroll.get_node_or_null("NpcLookContent/NpcLookHeader/NpcLookActions")
	var grid: GridContainer = scroll.get_node_or_null("NpcLookContent/EquipmentGrid")
	var detail: RichTextLabel = $NpcLook.get_node_or_null("NpcLookDetail")
	if detail == null:
		var found_detail: Node = $NpcLook.find_child("NpcLookDetail", true, false)
		if found_detail is RichTextLabel:
			detail = found_detail
	if root == null or header == null or icon == null or description == null or actions == null or grid == null or detail == null:
		return false

	_npc_look_scroll = scroll
	_npc_look_root = root
	_npc_look_header = header
	_npc_look_icon = icon
	_npc_look_description = description
	_npc_look_actions = actions
	_npc_look_grid = grid
	_npc_look_detail = detail
	_npc_look_scroll.follow_focus = true
	_npc_look_description.bbcode_enabled = true
	_npc_look_description.scroll_active = true
	_npc_look_detail.bbcode_enabled = true
	_npc_look_detail.scroll_active = true
	_npc_look_detail.fit_content = false
	_npc_look_grid.columns = EQUIPMENT_GRID_COLUMNS
	return true


func _create_npc_look_header(parent: VBoxContainer) -> void:
	_npc_look_header = VBoxContainer.new()
	_npc_look_header.name = "NpcLookHeader"
	_npc_look_header.add_theme_constant_override("separation", 6)
	parent.add_child(_npc_look_header)

	var npc_top_row: HBoxContainer = HBoxContainer.new()
	npc_top_row.name = "NpcLookTopRow"
	npc_top_row.add_theme_constant_override("separation", 8)
	_npc_look_header.add_child(npc_top_row)

	_npc_look_icon = TextureRect.new()
	_npc_look_icon.name = "NpcLookIcon"
	_npc_look_icon.custom_minimum_size = Vector2(80.0, 80.0)
	_npc_look_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_npc_look_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	npc_top_row.add_child(_npc_look_icon)

	_npc_look_description = RichTextLabel.new()
	_npc_look_description.name = "NpcLookDescription"
	_npc_look_description.bbcode_enabled = true
	_npc_look_description.fit_content = false
	_npc_look_description.scroll_active = true
	_npc_look_description.custom_minimum_size = Vector2(0.0, 92.0)
	_npc_look_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	npc_top_row.add_child(_npc_look_description)

	_npc_look_actions = HBoxContainer.new()
	_npc_look_actions.name = "NpcLookActions"
	_npc_look_actions.add_theme_constant_override("separation", 6)
	_npc_look_header.add_child(_npc_look_actions)


func _bind_status_visual_nodes(panel: Control) -> void:
	_status_value_labels.clear()
	_status_icon_nodes.clear()
	_status_character_icon = panel.get_node_or_null("AttributesContent/AttributesSection/AttributesHeader/CharacterIcon")
	_status_character_name = panel.get_node_or_null("AttributesContent/AttributesSection/AttributesHeader/CharacterText/CharacterName")
	_status_character_meta = panel.get_node_or_null("AttributesContent/AttributesSection/AttributesHeader/CharacterText/CharacterMeta")
	for stat_key: String in [
		"Alignment",
		"SkillPoints",
		"TrainingPoints",
		"Strength",
		"Speed",
		"Smarts",
		"Vitality",
		"Mysticism",
		"Perception",
	]:
		var label: Label = panel.get_node_or_null("AttributesContent/AttributesSection/AttributesStats/" + stat_key + "Value")
		if label != null:
			_status_value_labels[stat_key] = label
		var icon: TextureRect = panel.get_node_or_null("AttributesContent/AttributesSection/AttributesStats/" + stat_key + "Icon")
		if icon != null:
			_status_icon_nodes[stat_key] = icon
			if icon.texture == null and STATUS_ICON_PATHS.has(stat_key):
				icon.texture = _load_icon_texture(str(STATUS_ICON_PATHS[stat_key]))
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if _status_character_icon != null and _status_character_icon.texture == null:
		_status_character_icon.texture = _load_icon_texture(STATUS_CHARACTER_ICON_PATH)
	if _status_character_icon != null:
		_status_character_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_status_character_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _update_status_summary_ui(info: Dictionary, stats: Dictionary) -> void:
	if _has_status_visual_ui():
		_update_status_visual_ui(info, stats)
		return

	_set_status_gmcp_visible(false)
	_show_container("status")


func _has_status_visual_ui() -> bool:
	return _status_character_name != null and _status_character_meta != null and not _status_value_labels.is_empty()


func _update_status_visual_ui(info: Dictionary, stats: Dictionary) -> void:
	if _status_character_icon != null:
		_status_character_icon.texture = _resolve_status_character_icon(info)
	if _status_character_name != null:
		_status_character_name.text = str(info.get("name", "Unknown"))
	if _status_character_meta != null:
		_status_character_meta.text = "Level %s  %s %s" % [
			info.get("level", "?"),
			info.get("race", ""),
			info.get("class", ""),
		]
	_set_status_value("Alignment", str(info.get("alignment", "?")))
	_set_status_value("SkillPoints", str(info.get("skillpoints", 0)))
	_set_status_value("TrainingPoints", str(info.get("trainingpoints", 0)))
	for spec: Dictionary in ATTRIBUTE_SPECS:
		var key: String = spec.get("key", "")
		var stats_key: String = key.to_lower()
		var mod_key: String = stats_key + "mod"
		var base_val: int = int(stats.get(stats_key, 0))
		var mod_val: int = int(stats.get(mod_key, 0))
		var display: String = str(base_val) if base_val != 0 else "?"
		if mod_val != 0:
			var mod_sign: String = "+" if mod_val > 0 else ""
			display += " (%s%d)" % [mod_sign, mod_val]
		_set_status_value(key, display)


func _set_status_value(key: String, value: String) -> void:
	var label: Variant = _status_value_labels.get(key)
	if label is Label:
		label.text = value


func _set_equipment_ui_visible(visible: bool) -> void:
	_ensure_equipment_ui()
	_equipment_scroll.visible = visible
	_equipment_detail.visible = visible


func _set_status_gmcp_visible(visible: bool) -> void:
	_ensure_status_ui()
	_status_panel.visible = visible


func _set_npc_look_header_visible(visible: bool) -> void:
	_ensure_npc_look_ui()
	if _npc_look_header != null:
		_npc_look_header.visible = visible


func _update_npc_look_header(description_data: Dictionary, context: Dictionary) -> void:
	_ensure_npc_look_ui()
	var name: String = _npc_look_name(description_data, context)
	var description: String = str(description_data.get("description", "")).strip_edges()
	if _npc_look_icon != null:
		_npc_look_icon.texture = _load_icon_texture(_npc_icon_path(name, context))
	if _npc_look_description != null:
		var lines: Array[String] = []
		if description != "":
			lines.append(_bb_escape(description))
		_npc_look_description.text = "\n".join(lines)
	if _npc_look_actions != null:
		_clear_children(_npc_look_actions)
		for action: Dictionary in _npc_look_actions_for_context(context):
			_npc_look_actions.add_child(_make_npc_look_action_button(action))


func _npc_look_name(description_data: Dictionary, context: Dictionary) -> String:
	var object: Dictionary = _npc_context_object(context)
	var object_name: String = str(object.get("name", "")).strip_edges()
	if object_name != "":
		return object_name
	return str(description_data.get("name", "")).strip_edges()


func _npc_context_object(context: Dictionary) -> Dictionary:
	var object: Variant = context.get("object", {})
	return object if object is Dictionary else {}


func _npc_icon_path(name: String, context: Dictionary) -> String:
	var object: Dictionary = _npc_context_object(context)
	var object_name: String = str(object.get("name", name)).strip_edges()
	var slug: String = _name_slug(object_name)
	if slug != "":
		var path: String = "%s/%s.png" % [MOB_ICON_BY_NAME_DIR, slug]
		if _icon_file_exists(path):
			return path
	return DEFAULT_MOB_ICON_PATH if _icon_file_exists(DEFAULT_MOB_ICON_PATH) else DEFAULT_ITEM_ICON_PATH


func _npc_look_actions_for_context(context: Dictionary) -> Array[Dictionary]:
	var target: String = str(context.get("target", "")).strip_edges()
	var object: Dictionary = _npc_context_object(context)
	if target == "":
		target = str(object.get("id", "")).strip_edges()
	if target == "":
		return []
	var actions: Array[Dictionary] = [
		{"label": "Look", "command": "look " + target},
		{"label": "Atk", "command": "attack " + target},
	]
	var adjectives: Array[String] = _string_array(object.get("adjectives", []))
	if bool(object.get("quest_flag", false)):
		actions.append({"label": "Ask", "command": "ask " + target})
	if adjectives.has("shop"):
		actions.append({"label": "List", "command": "list " + target})
	return actions


func _make_npc_look_action_button(action: Dictionary) -> Button:
	var button: Button = Button.new()
	button.text = str(action.get("label", ""))
	button.custom_minimum_size = Vector2(58.0, 28.0)
	button.tooltip_text = str(action.get("command", ""))
	button.pressed.connect(_on_npc_look_action_pressed.bind(str(action.get("command", ""))))
	return button


func _on_npc_look_action_pressed(command: String) -> void:
	if command != "":
		button_commands_submitted.emit(command)


func _set_inventory_sections_visible(show_equipment: bool, show_backpack: bool, show_backpack_title: bool = true) -> void:
	_ensure_equipment_ui()
	if _equipment_title != null:
		_equipment_title.visible = show_equipment
	if _equipment_grid != null:
		_equipment_grid.visible = show_equipment
	if _backpack_title != null:
		_backpack_title.visible = show_backpack and show_backpack_title
	if _backpack_grid != null:
		_backpack_grid.visible = show_backpack


func _set_backpack_title(text: String) -> void:
	if $Backpack.has_node("Move"):
		$Backpack/Move.text = text


func _sync_backpack_child_widths() -> void:
	var width: float = max($Backpack.size.x, 360.0)
	var inner_right: float = max(width - 3.0, 0.0)
	if $Backpack.has_node("Move"):
		$Backpack/Move.offset_right = inner_right
	if $Backpack.has_node("Close"):
		$Backpack/Close.offset_right = inner_right


func _layout_equipment_ui() -> void:
	_ensure_equipment_ui()
	_sync_backpack_child_widths()
	var content_width: float = 320.0
	if _backpack_equipment_uses_scene_ui:
		var scroll_width: float = _equipment_scroll.size.x
		if scroll_width <= 0.0:
			scroll_width = max(_equipment_scroll.offset_right - _equipment_scroll.offset_left, 320.0)
		content_width = max(scroll_width - INVENTORY_SCROLLBAR_GUTTER, 320.0)
	else:
		var left: float = INVENTORY_PANEL_MARGIN
		var right: float = max($Backpack.size.x - INVENTORY_PANEL_MARGIN, 360.0)
		var close_top: float = $Backpack/Close.offset_top
		var detail_bottom: float = max(close_top - 8.0, 360.0)
		var detail_top: float = max(detail_bottom - INVENTORY_DETAIL_HEIGHT, 220.0)
		_equipment_scroll.offset_left = left
		_equipment_scroll.offset_right = right
		_equipment_scroll.offset_top = 34.0
		_equipment_scroll.offset_bottom = max(detail_top - 8.0, 180.0)
		_equipment_detail.offset_left = left
		_equipment_detail.offset_right = right - INVENTORY_SCROLLBAR_GUTTER
		_equipment_detail.offset_top = detail_top
		_equipment_detail.offset_bottom = detail_bottom
		content_width = max(right - left - INVENTORY_SCROLLBAR_GUTTER, 320.0)
	_equipment_root.custom_minimum_size = Vector2(content_width, 0.0)
	var slot_width: float = floor((content_width - float(EQUIPMENT_GRID_COLUMNS - 1) * INVENTORY_GRID_GAP) / float(EQUIPMENT_GRID_COLUMNS))
	var slot_height: float = clamp(slot_width * 0.72, 72.0, 84.0)
	_inventory_slot_size = Vector2(slot_width, slot_height)
	_inventory_icon_size = Vector2(slot_height * 0.52, slot_height * 0.52)


func _layout_player_equipment_ui() -> void:
	_ensure_player_equipment_ui()
	var scroll_width: float = _player_equipment_scroll.size.x
	if scroll_width <= 0.0:
		scroll_width = max(_player_equipment_scroll.offset_right - _player_equipment_scroll.offset_left, 360.0)
	var content_width: float = max(scroll_width - INVENTORY_SCROLLBAR_GUTTER, 320.0)
	if _player_equipment_root != null:
		_player_equipment_root.custom_minimum_size = Vector2(content_width, 0.0)
	var slot_width: float = floor((content_width - float(EQUIPMENT_GRID_COLUMNS - 1) * INVENTORY_GRID_GAP) / float(EQUIPMENT_GRID_COLUMNS))
	var slot_height: float = clamp(slot_width * 0.72, 72.0, 84.0)
	_inventory_slot_size = Vector2(slot_width, slot_height)
	_inventory_icon_size = Vector2(slot_height * 0.52, slot_height * 0.52)


func _layout_npc_look_ui() -> void:
	_ensure_npc_look_ui()
	var scroll_width: float = _npc_look_scroll.size.x
	if scroll_width <= 0.0:
		scroll_width = max(_npc_look_scroll.offset_right - _npc_look_scroll.offset_left, 360.0)
	var content_width: float = max(scroll_width - INVENTORY_SCROLLBAR_GUTTER, 320.0)
	if _npc_look_root != null:
		_npc_look_root.custom_minimum_size = Vector2(content_width, 0.0)
	var slot_width: float = floor((content_width - float(EQUIPMENT_GRID_COLUMNS - 1) * INVENTORY_GRID_GAP) / float(EQUIPMENT_GRID_COLUMNS))
	var slot_height: float = clamp(slot_width * 0.72, 72.0, 84.0)
	_inventory_slot_size = Vector2(slot_width, slot_height)
	_inventory_icon_size = Vector2(slot_height * 0.52, slot_height * 0.52)


func _make_section_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	return label


func _populate_equipment_grid(worn: Dictionary, location: String = "equipment") -> void:
	_layout_equipment_ui()
	_clear_children(_equipment_grid)
	var rendered_slots: Dictionary = {}
	for slot: String in EQUIPMENT_SLOT_ORDER:
		rendered_slots[slot] = true
		var item: Dictionary = _dictionary_or_empty(worn.get(slot, {}))
		_equipment_grid.add_child(_make_equipment_slot_cell(slot.capitalize(), item, location))
	for slot: String in _sorted_string_keys(worn):
		if rendered_slots.has(slot):
			continue
		var item: Dictionary = _dictionary_or_empty(worn.get(slot, {}))
		_equipment_grid.add_child(_make_equipment_slot_cell(slot.capitalize(), item, location))


func _populate_player_equipment_grid(worn: Dictionary) -> void:
	_layout_player_equipment_ui()
	_clear_children(_player_equipment_grid)
	var rendered_slots: Dictionary = {}
	for slot: String in EQUIPMENT_SLOT_ORDER:
		rendered_slots[slot] = true
		var item: Dictionary = _dictionary_or_empty(worn.get(slot, {}))
		_player_equipment_grid.add_child(_make_equipment_slot_cell(slot.capitalize(), item, "equipment", _player_equipment_detail))
	for slot: String in _sorted_string_keys(worn):
		if rendered_slots.has(slot):
			continue
		var item: Dictionary = _dictionary_or_empty(worn.get(slot, {}))
		_player_equipment_grid.add_child(_make_equipment_slot_cell(slot.capitalize(), item, "equipment", _player_equipment_detail))
	if _player_equipment_detail != null:
		_player_equipment_detail.text = "Select equipment to view details."


func _populate_npc_look_equipment_grid(worn: Dictionary) -> void:
	_layout_npc_look_ui()
	_clear_children(_npc_look_grid)
	var rendered_slots: Dictionary = {}
	for slot: String in EQUIPMENT_SLOT_ORDER:
		rendered_slots[slot] = true
		var item: Dictionary = _dictionary_or_empty(worn.get(slot, {}))
		_npc_look_grid.add_child(_make_equipment_slot_cell(slot.capitalize(), item, "display", _npc_look_detail))
	for slot: String in _sorted_string_keys(worn):
		if rendered_slots.has(slot):
			continue
		var item: Dictionary = _dictionary_or_empty(worn.get(slot, {}))
		_npc_look_grid.add_child(_make_equipment_slot_cell(slot.capitalize(), item, "display", _npc_look_detail))


func _populate_backpack_grid(backpack: Dictionary) -> void:
	_layout_equipment_ui()
	_clear_children(_backpack_grid)
	var items: Array[Dictionary] = _backpack_items(backpack)
	var summary: Dictionary = backpack.get("Summary", {})
	var max_slots: int = int(summary.get("max", 0)) if summary is Dictionary else 0
	var slot_count: int = max(max_slots, max(items.size(), BACKPACK_GRID_COLUMNS))
	for index: int in range(slot_count):
		var item: Dictionary = items[index] if index < items.size() else {}
		_backpack_grid.add_child(_make_inventory_slot(str(index + 1), item, "backpack"))
	_update_equipment_detail("Backpack: %d/%d" % [items.size(), slot_count])


func _make_equipment_slot_cell(slot_label: String, item: Dictionary, location: String = "equipment", detail_label: RichTextLabel = null) -> VBoxContainer:
	var cell: VBoxContainer = VBoxContainer.new()
	cell.custom_minimum_size = Vector2(_inventory_slot_size.x, _inventory_slot_size.y + 22.0)
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_theme_constant_override("separation", 2)

	var label: Label = Label.new()
	label.text = slot_label
	label.custom_minimum_size = Vector2(_inventory_slot_size.x, 18.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.clip_text = true
	cell.add_child(label)

	cell.add_child(_make_inventory_slot(slot_label, item, location, false, detail_label))
	return cell


func _make_inventory_slot(slot_label: String, item: Dictionary, location: String, show_slot_label: bool = true, detail_label: RichTextLabel = null) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = _inventory_slot_size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _slot_style(_is_empty_item(item)))
	var detail_text: String = _item_tooltip(slot_label, item)
	panel.mouse_entered.connect(_update_item_detail.bind(detail_text, detail_label))
	if not _is_empty_item(item) and location != "display":
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(_on_inventory_slot_gui_input.bind(panel, item.duplicate(true), location))

	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = _inventory_icon_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _resolve_item_icon(item)
	box.add_child(icon)

	var label: Label = Label.new()
	label.text = "%s\n%s" % [slot_label, _short_item_name(item)] if show_slot_label else _short_item_name(item)
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return panel


func _on_inventory_slot_gui_input(event: InputEvent, panel: PanelContainer, item: Dictionary, location: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_inventory_action_menu(panel, item, location)
		panel.accept_event()


func _show_inventory_action_menu(panel: PanelContainer, item: Dictionary, location: String) -> void:
	var actions: Array[Dictionary] = _inventory_actions_for_item(item, location)
	if actions.is_empty():
		return

	var popup: PopupMenu = PopupMenu.new()
	popup.name = "InventoryActionMenu"
	for index: int in range(actions.size()):
		var action: Dictionary = actions[index]
		popup.add_item(str(action.get("label", "")), int(action.get("id", 0)))
		popup.set_item_metadata(index, action)
	popup.id_pressed.connect(_on_inventory_action_selected.bind(popup))
	popup.popup_hide.connect(popup.queue_free)
	add_child(popup)

	var mouse_position: Vector2i = Vector2i(get_viewport().get_mouse_position())
	popup.position = mouse_position
	popup.popup()
	if location == "equipment" and _player_equipment_detail != null and _player_equipment_scroll != null and _player_equipment_scroll.visible:
		_update_item_detail(_item_tooltip("", item), _player_equipment_detail)
	else:
		_update_equipment_detail(_item_tooltip("", item))


func _inventory_actions_for_item(item: Dictionary, location: String) -> Array[Dictionary]:
	var target: String = _item_command_target(item)
	if target == "":
		return []
	var actions: Array[Dictionary] = [
		{"id": INVENTORY_ACTION_LOOK, "label": "Look", "command": "look " + target},
		{"id": INVENTORY_ACTION_INSPECT, "label": "Inspect", "command": "inspect " + target},
	]
	if location == "equipment":
		actions.append({"id": INVENTORY_ACTION_REMOVE, "label": "Remove", "command": "remove " + target})
		return actions

	actions.append({"id": INVENTORY_ACTION_EQUIP, "label": "Equip", "command": "equip " + target})
	var type: String = str(item.get("type", "")).strip_edges().to_lower()
	var subtype: String = str(item.get("subtype", "")).strip_edges().to_lower()
	if subtype == "drinkable" or type == "potion" or type == "drink":
		actions.append({"id": INVENTORY_ACTION_DRINK, "label": "Drink", "command": "drink " + target})
	elif type == "food" or subtype == "edible":
		actions.append({"id": INVENTORY_ACTION_EAT, "label": "Eat", "command": "eat " + target})
	else:
		actions.append({"id": INVENTORY_ACTION_USE, "label": "Use", "command": "use " + target})
	actions.append({"id": INVENTORY_ACTION_DROP, "label": "Drop", "command": "drop " + target})
	return actions


func _on_inventory_action_selected(id: int, popup: PopupMenu) -> void:
	var item_index: int = popup.get_item_index(id)
	if item_index < 0:
		return
	var action: Variant = popup.get_item_metadata(item_index)
	if not action is Dictionary:
		return
	var command: String = str(action.get("command", "")).strip_edges()
	if command == "":
		return
	button_commands_submitted.emit(command)
	popup.hide()


func _item_command_target(item: Dictionary) -> String:
	var id: String = str(item.get("id", "")).strip_edges()
	if id.begins_with("!"):
		return id
	var spec_id: String = _item_spec_id(id)
	if spec_id != "":
		return "!" + spec_id
	return str(item.get("name", "")).strip_edges()


func _slot_style(empty: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.045, 0.05, 0.94) if empty else Color(0.10, 0.08, 0.055, 0.96)
	style.border_color = Color(0.35, 0.38, 0.42, 1.0) if empty else Color(0.78, 0.64, 0.36, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	return style


func _resolve_item_icon(item: Dictionary) -> Texture2D:
	var icon_path: String = _icon_path_for_item(item)
	var texture: Texture2D = _load_icon_texture(icon_path)
	if texture != null:
		return texture
	return _load_icon_texture(DEFAULT_ITEM_ICON_PATH)


func _load_icon_texture(icon_path: String) -> Texture2D:
	if icon_path == "":
		return null
	if ResourceLoader.exists(icon_path):
		var resource: Resource = load(icon_path)
		if resource is Texture2D:
			return resource
	if FileAccess.file_exists(icon_path):
		var image: Image = Image.load_from_file(icon_path)
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return null


func _resolve_status_character_icon(info: Dictionary) -> Texture2D:
	var portrait_path: String = _player_portrait_icon_path(info)
	var portrait_texture: Texture2D = _load_icon_texture(portrait_path)
	if portrait_texture != null:
		return portrait_texture
	return _load_icon_texture(STATUS_CHARACTER_ICON_PATH)


func _player_portrait_icon_path(info: Dictionary) -> String:
	var race_slug: String = _name_slug(str(info.get("race", "")))
	var job_slug: String = _status_job_slug(info)
	if race_slug == "" or job_slug == "":
		return ""
	var icon_path: String = "%s/%s_%s.png" % [PLAYER_PORTRAIT_BY_RACE_CLASS_DIR, race_slug, job_slug]
	return icon_path if _icon_file_exists(icon_path) else ""


func _status_job_slug(info: Dictionary) -> String:
	var raw_job: String = ""
	for key: String in ["class", "profession", "job", "Job", "Profession"]:
		raw_job = str(info.get(key, "")).strip_edges()
		if raw_job != "":
			break
	if raw_job == "":
		return ""
	var first_job: String = raw_job.split("/", false)[0].split(",", false)[0].strip_edges()
	var slug: String = _name_slug(first_job)
	if slug == "":
		return ""
	var parts: PackedStringArray = slug.split("_", false)
	if parts.size() > 1 and PROFESSION_RANK_PREFIXES.has(parts[0]):
		var trimmed: Array[String] = []
		for index: int in range(1, parts.size()):
			trimmed.append(parts[index])
		slug = "_".join(trimmed)
	return slug


func _icon_path_for_item(item: Dictionary) -> String:
	if _is_empty_item(item):
		return EMPTY_ITEM_ICON_PATH
	var id: String = str(item.get("id", "")).strip_edges().to_lower()
	var spec_id: String = _item_spec_id(id)
	if spec_id == "":
		return DEFAULT_ITEM_ICON_PATH
	var by_id_path: String = "%s/%s.png" % [ITEM_ICON_BY_ID_DIR, spec_id]
	return by_id_path if _icon_file_exists(by_id_path) else DEFAULT_ITEM_ICON_PATH


func _item_spec_id(instance_id: String) -> String:
	var value: String = instance_id.strip_edges()
	if value.begins_with("!"):
		value = value.substr(1)
	var colon_index: int = value.find(":")
	if colon_index != -1:
		value = value.substr(0, colon_index)
	return value if value.is_valid_int() else ""


func _icon_file_exists(icon_path: String) -> bool:
	if ResourceLoader.exists(icon_path):
		return true
	return FileAccess.file_exists(icon_path)


func _backpack_items(backpack: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for key: String in ["items", "Items"]:
		var value: Variant = backpack.get(key, [])
		if value is Array:
			for item: Variant in value:
				if item is Dictionary:
					items.append(item)
			if not items.is_empty():
				return items
	return items


func _parse_legacy_equipment_text(data: String) -> Dictionary:
	var lines: Array[String] = _visible_text_lines(data)
	var worn: Dictionary = {}
	var current_slot: String = ""
	var saw_equipment_heading: bool = false
	for line: String in lines:
		if _is_legacy_equipment_noise_line(line):
			continue
		var clean_line: String = _normalize_legacy_equipment_line(line)
		if clean_line == "":
			continue
		var normalized: String = clean_line.to_lower()
		if normalized == "equipment":
			saw_equipment_heading = true
			current_slot = ""
			continue
		var slot: String = _equipment_slot_from_label(clean_line)
		if slot != "":
			current_slot = slot
			continue
		if current_slot != "":
			worn[current_slot] = _legacy_equipment_item(clean_line, current_slot)
			current_slot = ""
	if worn.is_empty():
		worn = _parse_legacy_equipment_tokens(lines)
	if not saw_equipment_heading and worn.is_empty():
		return {}
	return worn


func _parse_legacy_equipment_tokens(lines: Array[String]) -> Dictionary:
	var tokens: Array[String] = []
	var saw_equipment_heading: bool = false
	for line: String in lines:
		if _is_legacy_equipment_noise_line(line):
			continue
		var clean_line: String = _normalize_legacy_equipment_line(line)
		if clean_line == "":
			continue
		for token: String in clean_line.split(" ", false):
			var trimmed: String = token.strip_edges()
			if trimmed != "":
				tokens.append(trimmed)
	if tokens.is_empty():
		return {}

	var worn: Dictionary = {}
	var index: int = 0
	while index < tokens.size():
		var token: String = tokens[index]
		if token.to_lower() == "equipment":
			saw_equipment_heading = true
			index += 1
			continue
		if _is_legacy_equipment_section_end(tokens, index):
			break
		var slot: String = _equipment_slot_from_label(token)
		if slot == "":
			index += 1
			continue

		var item_words: Array[String] = []
		index += 1
		while index < tokens.size():
			var next_token: String = tokens[index]
			if next_token.to_lower() == "equipment" or _equipment_slot_from_label(next_token) != "" or _is_legacy_equipment_section_end(tokens, index):
				break
			item_words.append(next_token)
			index += 1
		if not item_words.is_empty():
			worn[slot] = _legacy_equipment_item(" ".join(item_words), slot)
		else:
			worn[slot] = {}

	if not saw_equipment_heading and worn.is_empty():
		return {}
	return worn


func _visible_text_lines(data: String) -> Array[String]:
	var text: String = _strip_bbcode(data)
	var lines: Array[String] = []
	for raw_line: String in text.replace("\r", "").split("\n", false):
		lines.append(raw_line)
	return lines


func _strip_bbcode(data: String) -> String:
	var re := RegEx.new()
	re.compile("\\[[^\\]]+\\]")
	return re.sub(data, "", true)


func _normalize_spaces(data: String) -> String:
	var re := RegEx.new()
	re.compile("\\s+")
	return re.sub(data.strip_edges(), " ", true)


func _bb_escape(data: String) -> String:
	return data.replace("[", "(").replace("]", ")")


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


func _normalize_legacy_equipment_line(line: String) -> String:
	var value: String = line
	value = value.replace(".:", " ")
	value = value.replace(":", " ")
	value = value.strip_edges()
	var re := RegEx.new()
	re.compile("\\s+")
	return re.sub(value, " ", true).strip_edges()


func _is_legacy_equipment_noise_line(line: String) -> bool:
	var value: String = _strip_bbcode(line).strip_edges()
	if value == "":
		return true
	var has_visible_character: bool = false
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		var character: String = value.substr(index, 1)
		if _is_ascii_letter_or_digit_codepoint(codepoint):
			return false
		if _is_legacy_box_art_codepoint(codepoint) or character in [" ", "\t", "|", "+", "-", "_", "=", ".", ",", "'", "`", "~"]:
			has_visible_character = true
			continue
		return false
	return has_visible_character


func _is_ascii_letter_or_digit_codepoint(codepoint: int) -> bool:
	return (
		(codepoint >= 48 and codepoint <= 57)
		or (codepoint >= 65 and codepoint <= 90)
		or (codepoint >= 97 and codepoint <= 122)
	)


func _is_legacy_box_art_codepoint(codepoint: int) -> bool:
	return (
		(codepoint >= 0x2500 and codepoint <= 0x257F)
		or (codepoint >= 0x2580 and codepoint <= 0x259F)
		or (codepoint >= 0xE000 and codepoint <= 0xF8FF)
		or codepoint == 0xFFFD
	)


func _equipment_slot_from_label(label: String) -> String:
	var normalized: String = label.to_lower().replace(" ", "")
	for slot: String in EQUIPMENT_SLOT_ORDER:
		if normalized == slot:
			return slot
	return ""


func _legacy_equipment_item(name: String, slot: String) -> Dictionary:
	var clean_name: String = _strip_legacy_equipment_trailing_sections(name)
	if clean_name == "" or clean_name.to_lower() == EMPTY_ITEM_NAME:
		return {}
	var item: Dictionary = {
		"id": "",
		"name": clean_name,
		"type": slot,
		"subtype": "",
		"uses": 0,
		"details": [],
	}
	var metadata_id: String = _metadata_id_for_name(clean_name, slot)
	if metadata_id != "":
		var metadata: Dictionary = _metadata_by_id(metadata_id)
		item["id"] = "!" + metadata_id
		item["name"] = str(metadata.get("name", clean_name))
		item["type"] = str(metadata.get("type", slot))
		item["subtype"] = str(metadata.get("subtype", ""))
	return item


func _strip_legacy_equipment_trailing_sections(name: String) -> String:
	var clean_name: String = name.strip_edges()
	var lower_name: String = clean_name.to_lower()
	for marker: String in [" carrying no objects", " carrying nothing", " carries no objects", " carries nothing"]:
		var marker_index: int = lower_name.find(marker)
		if marker_index != -1:
			clean_name = clean_name.substr(0, marker_index).strip_edges()
			lower_name = clean_name.to_lower()
	for exact_empty: String in ["-nothing-", "nothing", "no objects"]:
		if lower_name == exact_empty or lower_name.begins_with(exact_empty + " ") or lower_name.begins_with(exact_empty + "|"):
			return ""
	return clean_name


func _is_legacy_equipment_section_end(tokens: Array[String], index: int) -> bool:
	if index >= tokens.size():
		return true
	var current: String = tokens[index].to_lower()
	var next: String = tokens[index + 1].to_lower() if index + 1 < tokens.size() else ""
	var next_next: String = tokens[index + 2].to_lower() if index + 2 < tokens.size() else ""
	return current in ["carrying", "carries"] or (current == "no" and next == "objects") or (current == "carrying" and next == "no" and next_next == "objects")


func _dictionary_or_empty(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _is_empty_item(item: Dictionary) -> bool:
	var name: String = str(item.get("name", "")).strip_edges()
	return item.is_empty() or name == "" or name == EMPTY_ITEM_NAME


func _short_item_name(item: Dictionary) -> String:
	if _is_empty_item(item):
		return "Empty"
	var name: String = str(item.get("name", "Item"))
	return name if name.length() <= 18 else name.substr(0, 15) + "..."


func _item_tooltip(slot_label: String, item: Dictionary) -> String:
	if _is_empty_item(item):
		return "%s: empty" % [slot_label]
	var metadata: Dictionary = _metadata_for_item(item)
	var name: String = str(item.get("name", metadata.get("name", "Item")))
	var title: String = name if slot_label == "" else slot_label + ": " + name
	var lines: Array[String] = [title]
	var type: String = str(item.get("type", metadata.get("type", ""))).strip_edges()
	var subtype: String = str(item.get("subtype", metadata.get("subtype", ""))).strip_edges()
	if type != "" or subtype != "":
		lines.append("Type: %s %s" % [type, subtype])
	var description: String = _first_text_field(item, ["description", "Description", "desc", "Desc"])
	if description == "":
		description = str(metadata.get("description", "")).strip_edges()
	if description != "":
		lines.append(description)
	var details: Variant = item.get("details", [])
	if details is Array and not details.is_empty():
		lines.append("Details: " + ", ".join(_string_array(details)))
	if item.has("uses"):
		lines.append("Uses: " + str(item.get("uses")))
	return "\n".join(lines)


func _metadata_for_item(item: Dictionary) -> Dictionary:
	_load_item_metadata()
	var spec_id: String = _item_spec_id(str(item.get("id", "")))
	if spec_id == "":
		return {}
	return _metadata_by_id(spec_id)


func _metadata_by_id(spec_id: String) -> Dictionary:
	var metadata: Variant = _item_metadata_by_id.get(spec_id, {})
	return metadata if metadata is Dictionary else {}


func _metadata_id_for_name(name: String, slot: String = "") -> String:
	_load_item_metadata()
	var target: String = name.strip_edges().to_lower()
	if target == "":
		return ""
	var normalized_slot: String = slot.strip_edges().to_lower()
	var fallback_id: String = ""
	for spec_id: Variant in _item_metadata_by_id.keys():
		var metadata: Variant = _item_metadata_by_id.get(spec_id)
		if not metadata is Dictionary:
			continue
		if not _metadata_matches_name(metadata, target):
			continue
		var metadata_type: String = str(metadata.get("type", "")).strip_edges().to_lower()
		if normalized_slot == "" or metadata_type == "" or metadata_type == normalized_slot:
			return str(spec_id)
		if fallback_id == "":
			fallback_id = str(spec_id)
	return fallback_id


func _metadata_matches_name(metadata: Dictionary, target: String) -> bool:
	for key: String in ["name", "namesimple", "displayname"]:
		if str(metadata.get(key, "")).strip_edges().to_lower() == target:
			return true
	var aliases: Variant = metadata.get("aliases", [])
	if aliases is Array:
		for alias: Variant in aliases:
			if str(alias).strip_edges().to_lower() == target:
				return true
	return false


func _load_item_metadata() -> void:
	if _item_metadata_loaded:
		return
	_item_metadata_loaded = true
	if not FileAccess.file_exists(ITEM_METADATA_PATH):
		return
	var text: String = FileAccess.get_file_as_string(ITEM_METADATA_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_item_metadata_by_id = parsed


func _first_text_field(data: Dictionary, keys: Array[String]) -> String:
	for key: String in keys:
		var value: String = str(data.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""


func _update_equipment_detail(text: String) -> void:
	if _equipment_detail == null:
		return
	_equipment_detail.text = text


func _update_item_detail(text: String, detail_label: RichTextLabel = null) -> void:
	if detail_label != null:
		detail_label.text = text
		return
	_update_equipment_detail(text)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		child.queue_free()


func _sorted_string_keys(dict: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key: Variant in dict.keys():
		keys.append(str(key))
	keys.sort()
	return keys


func _string_array(values: Array) -> Array[String]:
	var strings: Array[String] = []
	for value: Variant in values:
		strings.append(str(value))
	return strings

# helpers to organize info
func organize_spells(data: String) -> String:
	return data
	
func organize_skills(data: String) -> String:
	return data
	
func organize_status(data: String) -> String:
	return data
	
func organize_backpack(data: String) -> String:
	return data

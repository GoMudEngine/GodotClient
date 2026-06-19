class_name ContainersController
extends Node2D

const MAX_OPEN_CONTAINERS: int = 3

signal button_commands_submitted(data: String)

@onready var backpack: BackpackPanel = $Backpack
@onready var equipment: EquipmentPanel = $Equipment
@onready var attributes: AttributesPanel = $Attributes
@onready var skills: SkillsPanel = $Skills
@onready var spells: SpellsPanel = $Spells
@onready var npc_look: NpcLookPanel = $NpcLook

var _open_container_order: Array[String] = []


func _ready() -> void:
	backpack.visible = false
	equipment.visible = false
	attributes.visible = false
	skills.visible = false
	spells.visible = false
	npc_look.visible = false

	backpack.command_submitted.connect(button_commands_submitted.emit)
	equipment.command_submitted.connect(button_commands_submitted.emit)
	spells.command_submitted.connect(button_commands_submitted.emit)
	npc_look.command_submitted.connect(button_commands_submitted.emit)

	var text_processor: TextProcessor = $"../TextProcessor"
	text_processor.container_request.connect(_on_container_request_received)
	if text_processor.has_signal("npc_look_description"):
		text_processor.npc_look_description.connect(npc_look.on_npc_look_description_received)


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
		if backpack.visible:
			show_equipment_gmcp(gmcp_state, false)
		if equipment.visible:
			show_player_equipment_gmcp(gmcp_state, false)
	if topic == "Char" or topic.begins_with("Char.Info") or topic.begins_with("Char.Stats"):
		if attributes.visible:
			show_status_gmcp(gmcp_state, false)
	if topic == "Char" or topic.begins_with("Char.Skills") or topic.begins_with("Char.Jobs"):
		if skills.visible:
			show_skills_gmcp(gmcp_state, false)


func show_equipment_gmcp(gmcp_state: Dictionary, mark_recent: bool = true) -> void:
	backpack.refresh_gmcp(gmcp_state)
	_show_container("backpack", mark_recent)


func show_player_equipment_gmcp(gmcp_state: Dictionary, mark_recent: bool = true) -> void:
	equipment.refresh_gmcp(gmcp_state)
	_show_container("equipment", mark_recent)


func show_status_gmcp(gmcp_state: Dictionary, mark_recent: bool = true) -> void:
	attributes.refresh_gmcp(gmcp_state)
	_show_container("status", mark_recent)


func show_skills_gmcp(gmcp_state: Dictionary, mark_recent: bool = true) -> void:
	if skills.refresh_gmcp(gmcp_state):
		_show_container("skills", mark_recent)


func show_affects_gmcp(gmcp_state: Dictionary) -> void:
	show_status_gmcp(gmcp_state)


func show_kills_gmcp(gmcp_state: Dictionary) -> void:
	show_status_gmcp(gmcp_state)


func set_pending_npc_look_context(context: Dictionary) -> void:
	npc_look.set_pending_context(context)


func clear_pending_npc_look() -> void:
	npc_look.clear_pending()


func _on_container_request_received(data: String, type: String) -> void:
	data = data.replace(".:", "")
	match type:
		"equipment":
			if npc_look.try_show_with_equipment(data):
				_show_container("npc_look")
				return
			if equipment.refresh_legacy(data):
				_show_container("equipment")
				return
		"status":
			attributes.set_gmcp_visible(true)
			_show_container("status")
		"spells":
			if not spells.refresh_legacy(data):
				spells.show_text_fallback(data)
			_show_container("spells")


func _show_container(key: String, mark_recent: bool = true) -> void:
	var panel: CanvasItem = _container_node(key)
	if panel == null:
		return
	panel.visible = true
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


func _close_container(key: String) -> void:
	var panel: CanvasItem = _container_node(key)
	if panel != null:
		panel.visible = false
	_open_container_order.erase(key)


func _toggle_container(key: String) -> void:
	var panel: CanvasItem = _container_node(key)
	if panel == null:
		return
	if panel.visible:
		_close_container(key)
	else:
		_show_container(key)


func _close_all_containers() -> void:
	backpack.visible = false
	equipment.visible = false
	attributes.visible = false
	skills.visible = false
	spells.visible = false
	npc_look.visible = false
	_open_container_order.clear()


func _container_node(key: String) -> CanvasItem:
	match key:
		"backpack":
			return backpack
		"equipment":
			return equipment
		"status":
			return attributes
		"skills":
			return skills
		"spells":
			return spells
		"npc_look":
			return npc_look
		_:
			return null

extends Node2D

@onready var connection: Variant = $Connection
@onready var text_processor: Variant = $TextProcessor
@onready var command_input: Variant = $Input
@onready var map_panel: Variant = $Map
@onready var status_panel: Variant = $Status
@onready var mobs_panel: Variant = $Mobs
@onready var containers_panel: Variant = $Containers

var gmcp_state: Dictionary = {}
var _gmcp_ready: bool = false


func _ready() -> void:
	connection.connected.connect(_on_connection_connected)
	connection.text_received.connect(_on_text_received)
	connection.sound_received.connect(_on_sound_received)
	connection.gmcp_received.connect(_on_gmcp_received)
	command_input.cmd_text_submitted.connect(_on_cmd_text_submitted)


func _on_text_received(data: String) -> void:
	text_processor._update_lines(data)


func _on_sound_received(data: Dictionary) -> void:
	pass


func _on_gmcp_received(data: Dictionary) -> void:
	var topic: String = data.get("topic", "")
	var topic_details: Variant = data.get("data")
	_process_gmcp(topic, topic_details)


func _process_gmcp(topic: String, data: Variant) -> void:
	if topic == "":
		return
	_gmcp_ready = true
	_apply_gmcp_payload(topic, data)
	_dispatch_gmcp_payload(topic, data)


func _apply_gmcp_payload(topic: String, data: Variant) -> void:
	var parts: PackedStringArray = topic.split(".", false)
	if parts.is_empty():
		return
	var cursor: Dictionary = gmcp_state
	for index: int in range(parts.size() - 1):
		var part: String = parts[index]
		if not cursor.has(part) or not cursor[part] is Dictionary:
			cursor[part] = {}
		cursor = cursor[part]
	cursor[parts[parts.size() - 1]] = data


func _dispatch_gmcp_payload(topic: String, data: Variant) -> void:
	for panel: Variant in [map_panel, status_panel, mobs_panel, containers_panel]:
		if panel != null and panel.has_method("apply_gmcp"):
			panel.apply_gmcp(topic, data, gmcp_state)


func _on_connection_connected() -> void:
	gmcp_state.clear()
	_gmcp_ready = false
	if text_processor != null and text_processor.has_method("reset_session"):
		text_processor.reset_session(true)
	if containers_panel != null and containers_panel.has_method("clear_pending_npc_look"):
		containers_panel.clear_pending_npc_look()


func _request_gmcp_snapshot() -> void:
	for topic: String in ["Room.Info", "Char", "Party", "Game"]:
		_send_gmcp_if_connected(topic)


func _send_gmcp_if_connected(topic: String, additional: String = "") -> void:
	if connection != null and connection.has_method("is_open") and connection.is_open():
		connection.send_gmcp_request(topic, additional)


func _on_cmd_text_submitted(data: String) -> void:
	if _handle_local_command(data):
		return
	if not _prepare_look_context(data):
		if containers_panel != null and containers_panel.has_method("clear_pending_npc_look"):
			containers_panel.clear_pending_npc_look()
	connection.send_message(data)


func _handle_local_command(data: String) -> bool:
	var command: String = data.strip_edges()
	if not command.begins_with("/"):
		return _handle_gmcp_command(command)

	var parts: PackedStringArray = command.split(" ", false)
	var local_command: String = parts[0].to_lower()
	match local_command:
		"/connect":
			if parts.size() > 1:
				var target: String = parts[1].to_lower()
				match target:
					"official":
						connection.connect_to_server(connection.OFFICIAL_SERVER_URL)
					"catacombs":
						connection.connect_to_server(connection.CATACOMBS_SERVER_URL)
					_:
						connection.connect_to_server(parts[1])
			else:
				connection.connect_to_server()
			return true
		"/disconnect":
			connection.disconnect_from_server()
			return true
		"/gmcp":
			if not _gmcp_ready:
				connection.show_status_message("Login first. GMCP is enabled after the server sends character data.")
				return true
			if parts.size() > 1:
				var topic: String = parts[1]
				var additional: String = command.substr(command.find(topic) + topic.length()).strip_edges()
				connection.send_gmcp_request(topic, additional)
			return true
		"/ui":
			if parts.size() < 2:
				return true
			return _handle_gmcp_command(parts[1].to_lower(), true)
		_:
			return false


func _handle_gmcp_command(command: String, force_local: bool = false) -> bool:
	if not _gmcp_ready:
		if force_local:
			connection.show_status_message("Login first. GMCP windows are available after the server sends character data.")
			return true
		return false

	var normalized: String = command.to_lower()
	match normalized:
		"i", "inv", "inventory":
			containers_panel.show_equipment_gmcp(gmcp_state)
			_send_gmcp_if_connected("Char.Inventory")
			return true
		"eq", "equipment":
			containers_panel.show_player_equipment_gmcp(gmcp_state)
			_send_gmcp_if_connected("Char.Inventory")
			return true
		"status", "score":
			containers_panel.show_status_gmcp(gmcp_state)
			_send_gmcp_if_connected("Char.Info")
			_send_gmcp_if_connected("Char.Stats")
			return true
		"skills", "jobs":
			containers_panel.show_skills_gmcp(gmcp_state)
			_send_gmcp_if_connected("Char.Skills")
			return true
		"affects", "effects":
			containers_panel.show_affects_gmcp(gmcp_state)
			_send_gmcp_if_connected("Char.Affects")
			return true
		"kills", "killstats":
			containers_panel.show_kills_gmcp(gmcp_state)
			_send_gmcp_if_connected("Char.Kills")
			return true
		_:
			return false


func _prepare_look_context(command: String) -> bool:
	var normalized: String = command.strip_edges()
	if normalized == "":
		return false
	var parts: PackedStringArray = normalized.split(" ", false)
	var verb: String = parts[0].to_lower()
	if verb != "look" and verb != "l":
		return false
	var target: String = normalized.substr(parts[0].length()).strip_edges()
	if target == "":
		return false
	var context: Dictionary = {"target": target}
	if mobs_panel != null and mobs_panel.has_method("object_for_command_target"):
		var object: Variant = mobs_panel.object_for_command_target(target)
		if object is Dictionary:
			context["object"] = object
	if containers_panel != null and containers_panel.has_method("set_pending_npc_look_context"):
		containers_panel.set_pending_npc_look_context(context)
	return true

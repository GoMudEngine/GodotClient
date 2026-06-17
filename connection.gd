class_name GameConnection
extends Node2D

const OFFICIAL_SERVER_URL: String = "wss://gomud.net/ws"
const CATACOMBS_SERVER_URL: String = "wss://game.kegscatacombs.online/ws"
const GMCP_DEBUG_LOG_PROJECT_PATH: String = "res://developer_tools/logs/gmcp_debug.log"
const GMCP_DEBUG_LOG_USER_PATH: String = "user://gmcp_debug.log"
const LEGACY_DEBUG_LOG_PROJECT_PATH: String = "res://developer_tools/logs/legacy_debug.log"
const LEGACY_DEBUG_LOG_USER_PATH: String = "user://legacy_debug.log"

@export var websocket_url: String = OFFICIAL_SERVER_URL
@export var connect_on_ready: bool = false
@export var enable_gmcp_debug_log: bool = true
@export var enable_legacy_debug_log: bool = true

signal text_received(text: String)
signal sound_received(data: Dictionary)
signal gmcp_received(data: Dictionary)
signal connected()

@onready var status: Label = $Status_BG/Status
@onready var connect_button: Button = $Status_BG/ConnectButton

const AUTO_RECONNECT_DELAY: float = 5.0

var socket: WebSocketPeer = WebSocketPeer.new()
var _token_regex: RegEx = RegEx.new()
var _pending_messages: Array[String] = []
var _gmcp_debug_log_path: String = ""
var _legacy_debug_log_path: String = ""
var _was_open: bool = false
var _user_disconnected: bool = false
var _reconnect_countdown: float = 0.0


func _ready() -> void:
	_setup_gmcp_debug_log()
	_setup_legacy_debug_log()
	_token_regex.compile("!!(SOUND|MUSIC|GMCP)\\(([\\s\\S]*?)\\)")
	set_process(false)
	if connect_on_ready:
		connect_to_server()
	else:
		status.text = "Disconnected. Connection is manual."
	_update_connect_button()


func _process(delta: float) -> void:
	if _reconnect_countdown > 0.0:
		_reconnect_countdown -= delta
		var secs: int = ceili(_reconnect_countdown)
		status.text = "Disconnected. Reconnecting in %ds..." % secs
		if _reconnect_countdown <= 0.0:
			_reconnect_countdown = 0.0
			connect_to_server()
		return

	socket.poll()
	var state: WebSocketPeer.State = socket.get_ready_state()
	if state == WebSocketPeer.STATE_CONNECTING:
		status.text = "Connecting to: " + websocket_url
		_update_connect_button()
	elif state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			_user_disconnected = false
			status.text = "Connected."
			_append_debug_event("connected", {"url": websocket_url})
			_update_connect_button()
			connected.emit()
			_flush_pending_messages()
		_process_packets()
	elif state == WebSocketPeer.STATE_CLOSING or state == WebSocketPeer.STATE_CLOSED:
		_append_debug_event("closed", {
			"code": socket.get_close_code(),
			"reason": socket.get_close_reason(),
		})
		_was_open = false
		if not _user_disconnected:
			_reconnect_countdown = AUTO_RECONNECT_DELAY
		else:
			status.text = _closed_status_text()
			set_process(false)
		_update_connect_button()


func _process_packets() -> void:
	while socket.get_available_packet_count() > 0:
		var data_received: String = socket.get_packet().get_string_from_utf8()
		if data_received != "":
			var unix_now: int = Time.get_unix_time_from_system()
			status.text = "Data received: " + str(unix_now)
			_parse_and_emit(data_received)
		else:
			status.text = "Failed to get data."
			print("Failed to get data: ", data_received)


func connect_to_server(url: String = "") -> void:
	if url != "":
		websocket_url = normalize_websocket_url(url)

	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_update_connect_button()
		return
	if socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		status.text = "Already connecting to: " + websocket_url
		_update_connect_button()
		return

	socket = WebSocketPeer.new()
	_was_open = false
	var error: Error = socket.connect_to_url(websocket_url)
	status.text = "Connecting to: " + websocket_url
	print("Connecting to: ", websocket_url)
	if error != OK:
		status.text = "Failed to connect."
		print("Failed to connect: ", error)
		set_process(false)
		_update_connect_button()
		return

	set_process(true)
	_update_connect_button()


func normalize_websocket_url(raw_url: String) -> String:
	var value: String = raw_url.strip_edges()
	if value == "":
		return websocket_url
	if value.begins_with("https://"):
		return _normalize_http_url_to_websocket(value, "https://", "wss://")
	if value.begins_with("http://"):
		return _normalize_http_url_to_websocket(value, "http://", "ws://")
	if value.begins_with("wss://") or value.begins_with("ws://"):
		return _ensure_websocket_path(value)
	return _ensure_websocket_path("wss://" + value)


func _normalize_http_url_to_websocket(value: String, http_scheme: String, websocket_scheme: String) -> String:
	var without_scheme: String = value.substr(http_scheme.length())
	var slash_index: int = without_scheme.find("/")
	var host: String = without_scheme if slash_index == -1 else without_scheme.substr(0, slash_index)
	var path: String = "" if slash_index == -1 else without_scheme.substr(slash_index)
	if path.begins_with("/ws"):
		return websocket_scheme + host + path
	return websocket_scheme + host + "/ws"


func _ensure_websocket_path(value: String) -> String:
	var scheme_end: int = value.find("://")
	if scheme_end == -1:
		return value
	var path_start: int = value.find("/", scheme_end + 3)
	if path_start == -1:
		return value + "/ws"
	if value.substr(path_start) == "/":
		return value.substr(0, path_start) + "/ws"
	return value


func _closed_status_text() -> String:
	var close_code: int = socket.get_close_code()
	var close_reason: String = socket.get_close_reason()
	if close_code > 0 and close_reason != "":
		return "Connection closed. Code %d: %s" % [close_code, close_reason]
	if close_code > 0:
		return "Connection closed. Code %d." % [close_code]
	return "Connection closed."


func disconnect_from_server() -> void:
	_user_disconnected = true
	_reconnect_countdown = 0.0
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.close()
	_pending_messages.clear()
	_was_open = false
	set_process(false)
	status.text = "Disconnected."
	_update_connect_button()


func is_open() -> bool:
	return socket.get_ready_state() == WebSocketPeer.STATE_OPEN


func is_connecting() -> bool:
	return socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING


func show_manual_connect_hint() -> void:
	status.text = "Connecting. Command queued."


func show_status_message(message: String) -> void:
	status.text = message


func queue_message(cmd: String) -> void:
	_pending_messages.append(cmd)
	if not is_open() and not is_connecting():
		connect_to_server()
	elif is_open():
		_flush_pending_messages()


func _flush_pending_messages() -> void:
	while is_open() and not _pending_messages.is_empty():
		var pending_message: String = _pending_messages.pop_front()
		_send_open_message(pending_message)


func _parse_and_emit(text: String) -> void:
	var last: int = 0
	for token_match: RegExMatch in _token_regex.search_all(text):
		var start: int = token_match.get_start()
		var stop: int = token_match.get_end()

		if start > last:
			var plain_text: String = text.substr(last, start - last)
			if plain_text != "":
				_append_legacy_debug_log("in", plain_text)
				text_received.emit(plain_text)

		var kind: String = token_match.get_string(1)
		var body: String = token_match.get_string(2)

		if kind == "SOUND" or kind == "MUSIC":
			sound_received.emit(_parse_sound(body))
		else:
			var gmcp_data: Dictionary = _parse_gmcp(body)
			_append_gmcp_debug_log("in", gmcp_data.get("topic", ""), gmcp_data.get("data"), body)
			gmcp_received.emit(gmcp_data)

		last = stop

	if last < text.length():
		var tail: String = text.substr(last)
		if tail != "":
			_append_legacy_debug_log("in", tail)
			text_received.emit(tail)


func _parse_sound(body: String) -> Dictionary:
	var parts: PackedStringArray = body.strip_edges().split(" ", false)
	var path: String = parts[0] if parts.size() > 0 else ""
	var params: Dictionary = {}
	for index: int in range(1, parts.size()):
		var key_value: PackedStringArray = parts[index].split("=", false, 2)
		if key_value.size() == 2:
			var key: String = key_value[0]
			var value: String = key_value[1]
			if value.is_valid_int():
				params[key] = int(value)
			elif value.is_valid_float():
				params[key] = float(value)
			else:
				params[key] = value

	return {"path": path, "params": params}


func _parse_gmcp(body: String) -> Dictionary:
	var stripped: String = body.strip_edges()
	var json_index: int = _find_gmcp_payload_index(stripped)
	var topic: String = stripped.substr(0, json_index).strip_edges() if json_index != -1 else _gmcp_topic_from_text(stripped)
	var payload: String = stripped.substr(json_index).strip_edges() if json_index != -1 else _gmcp_payload_from_text(stripped)
	var data: Variant = payload

	if payload.begins_with("{") or payload.begins_with("["):
		var json: JSON = JSON.new()
		if json.parse(payload) == OK:
			data = json.data

	return {"topic": topic, "data": data}


func _find_gmcp_payload_index(value: String) -> int:
	var object_index: int = value.find("{")
	var array_index: int = value.find("[")
	if object_index == -1:
		return array_index
	if array_index == -1:
		return object_index
	return min(object_index, array_index)


func _gmcp_topic_from_text(value: String) -> String:
	var space_index: int = value.find(" ")
	return value.substr(0, space_index) if space_index != -1 else value


func _gmcp_payload_from_text(value: String) -> String:
	var space_index: int = value.find(" ")
	return value.substr(space_index + 1).strip_edges() if space_index != -1 else ""


func send_message(cmd: String) -> void:
	if not is_open():
		queue_message(cmd)
		return
	_send_open_message(cmd)


func send_gmcp_request(identifier: String, additional: String = "") -> void:
	var payload: String = identifier
	if additional != "":
		payload += " " + additional
	_append_gmcp_debug_log("out", identifier, additional, payload)
	send_message("!!GMCP(" + payload + ")")


func get_gmcp_debug_log_path() -> String:
	return ProjectSettings.globalize_path(_gmcp_debug_log_path) if _gmcp_debug_log_path != "" else ""


func _setup_gmcp_debug_log() -> void:
	if not enable_gmcp_debug_log:
		return

	var project_log_dir: String = ProjectSettings.globalize_path("res://logs")
	DirAccess.make_dir_recursive_absolute(project_log_dir)

	for candidate_path: String in [GMCP_DEBUG_LOG_PROJECT_PATH, GMCP_DEBUG_LOG_USER_PATH]:
		var file: FileAccess = FileAccess.open(candidate_path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
		else:
			file = FileAccess.open(candidate_path, FileAccess.WRITE)
		if file == null:
			continue
		_gmcp_debug_log_path = candidate_path
		file.store_line(JSON.stringify({
			"time": Time.get_datetime_string_from_system(true),
			"event": "gmcp_log_started",
			"path": get_gmcp_debug_log_path(),
		}))
		file.close()
		print("GMCP debug log: ", get_gmcp_debug_log_path())
		return

	push_warning("GMCP debug log could not be opened.")


func _setup_legacy_debug_log() -> void:
	if not enable_legacy_debug_log:
		return
	var project_log_dir: String = ProjectSettings.globalize_path("res://logs")
	DirAccess.make_dir_recursive_absolute(project_log_dir)
	for candidate_path: String in [LEGACY_DEBUG_LOG_PROJECT_PATH, LEGACY_DEBUG_LOG_USER_PATH]:
		var file: FileAccess = FileAccess.open(candidate_path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
		else:
			file = FileAccess.open(candidate_path, FileAccess.WRITE)
		if file == null:
			continue
		_legacy_debug_log_path = candidate_path
		file.store_line(JSON.stringify({
			"time": Time.get_datetime_string_from_system(true),
			"event": "legacy_log_started",
		}))
		file.close()
		print("Legacy debug log: ", ProjectSettings.globalize_path(_legacy_debug_log_path))
		return
	push_warning("Legacy debug log could not be opened.")


func _append_legacy_debug_log(direction: String, text: String) -> void:
	if not enable_legacy_debug_log or _legacy_debug_log_path == "":
		return
	var file: FileAccess = FileAccess.open(_legacy_debug_log_path, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify({
		"time": Time.get_datetime_string_from_system(true),
		"direction": direction,
		"text": text,
	}))
	file.close()


func _append_debug_event(event_name: String, data: Dictionary) -> void:
	_append_log_entry({
		"time": Time.get_datetime_string_from_system(true),
		"event": event_name,
		"data": data,
	})


func _append_gmcp_debug_log(direction: String, topic: String, data: Variant, raw_body: String) -> void:
	_append_log_entry({
		"time": Time.get_datetime_string_from_system(true),
		"direction": direction,
		"topic": topic,
		"raw_utf8_base64": Marshalls.raw_to_base64(raw_body.to_utf8_buffer()),
		"data_json": JSON.stringify(data),
	})


func _append_log_entry(entry: Dictionary) -> void:
	if not enable_gmcp_debug_log or _gmcp_debug_log_path == "":
		return
	var file: FileAccess = FileAccess.open(_gmcp_debug_log_path, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(entry))
	file.close()


func _send_open_message(cmd: String) -> void:
	socket.send_text(cmd)
	_append_legacy_debug_log("out", cmd)
	status.text = "Sent: " + cmd
	print("Sent: ", cmd)


func _on_connect_button_pressed() -> void:
	if is_open() or is_connecting():
		disconnect_from_server()
	else:
		connect_to_server()


func _update_connect_button() -> void:
	if connect_button == null:
		return
	if is_open():
		connect_button.text = "Disconnect"
		connect_button.disabled = true
		connect_button.visible = false
	elif is_connecting():
		connect_button.text = "Connecting"
		connect_button.disabled = false
		connect_button.visible = true
	else:
		connect_button.text = "Connect"
		connect_button.disabled = false
		connect_button.visible = true

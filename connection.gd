extends Node

var official_server_url = "wss://gomud.willowdalemud.com/ws"
var catacombs_server_url = "wss://game.kegscatacombs.online/ws"
var websocket_url = official_server_url
var socket := WebSocketPeer.new()

@onready var status = $Status_BG/Status
@onready var reconnect_button = $Status_BG/ReconnectButton

signal text_received(text: String)
signal sound_received(path: String, params: Dictionary)
signal GMCP_received(topic: String, data: Variant)

var _re_token := RegEx.new()

func _ready():
	_re_token.compile("!!(SOUND|MUSIC|GMCP)\\(([\\s\\S]*?)\\)")
	reconnect_button.connect("pressed", Callable(self, "_on_reconnect_pressed"))
	_connect_to_server()

func _connect_to_server():
	status.text = "Connecting to: " + str(websocket_url)
	socket = WebSocketPeer.new()
	var err = socket.connect_to_url(websocket_url)
	if err != OK:
		status.text = "Failed to connect..."
		print(status.text)
		set_process(false)
	else:
		set_process(true)
		reconnect_button.visible = false
		await get_tree().create_timer(2).timeout
		status.text = "Connection initiated..."
		print(status.text)

func _on_reconnect_pressed():
	status.text = "Reconnecting..."
	Global_Status._first_msg = true
	print("Reconnecting to server...")
	_connect_to_server()

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			if socket.get_available_packet_count() > 0:
				var data_received = socket.get_packet().get_string_from_utf8()
				if data_received:
					var unix_now = Time.get_unix_time_from_system()
					status.text = "Data received: " + str(unix_now)
					_parse_and_emit(data_received)
				else:
					status.text = "Failed to get data."
					print(status.text)

		WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED:
			if reconnect_button.visible == false:
				status.text = "Connection closed. Click Reconnect."
				reconnect_button.visible = true
				print(status.text)
				set_process(false)

# ---------- core splitter ----------
func _parse_and_emit(s: String) -> void:
	var last := 0
	for m in _re_token.search_all(s):
		var start = m.get_start()
		var stop  = m.get_end()
		if start > last:
			var txt := s.substr(last, start - last)
			if txt != "":
				emit_signal("text_received", txt)

		var kind = m.get_string(1)
		var body = m.get_string(2)

		match kind:
			"SOUND", "MUSIC":
				var snd = _parse_sound(body)
				emit_signal("sound_received", snd)
			"GMCP":
				var gm = _parse_gmcp(body)
				emit_signal("GMCP_received", gm)

		last = stop

	if last < s.length():
		var tail := s.substr(last)
		if tail != "":
			emit_signal("text_received", tail)

# ---------- SOUND parser ----------
func _parse_sound(body: String) -> Dictionary:
	var parts := body.strip_edges().split(" ", false)
	var path := parts[0] if parts.size() > 0 else ""
	var params: Dictionary = {}
	for i in range(1, parts.size()):
		var kv := parts[i].split("=", false, 2)
		if kv.size() == 2:
			var k := kv[0]
			var v := kv[1]
			if v.is_valid_int():
				params[k] = int(v)
			elif v.is_valid_float():
				params[k] = float(v)
			else:
				params[k] = v
	return {"path": path, "params": params}

# ---------- GMCP parser ----------
func _parse_gmcp(body: String) -> Dictionary:
	var s := body.strip_edges()
	var sp := s.find(" ")

	var topic := s.substr(0, sp) if sp != -1 else s
	var payload := s.substr(sp + 1).strip_edges() if sp != -1 else ""
	var data: Variant = payload

	if payload.begins_with("{") or payload.begins_with("["):
		var j := JSON.new()
		if j.parse(payload) == OK:
			data = j.data
	return {"topic": topic, "data": data}

func send_message(cmd: String):
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		status.text = "Cannot send message. Socket not open."
		print(status.text)
		return
	socket.send_text(cmd)
	status.text = "Sent: " + cmd
	print(status.text)

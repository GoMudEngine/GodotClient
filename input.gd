extends Node2D

var _previous_cmd: Array = []
var _cmd_index: int = -1
var _input_editing: bool = false

signal cmd_text_submitted(data: String)

func _ready() -> void:
	$"../Options".connect("button_commands_submitted", Callable(self, "_on_button_command_text_submitted"))
	$"../TextProcessor".connect("auto_commands_submitted", Callable(self, "_on_auto_commands_submitted"))
	$Command.connect("focus_entered", Callable(self, "_on_focus_entered"))
	$Command.connect("focus_exited", Callable(self, "_on_focus_exited"))

func _on_auto_commands_submitted(cmd: String) -> void:
	emit_signal("cmd_text_submitted", cmd)

func _on_focus_entered() -> void:
	_input_editing = true

func _on_focus_exited() -> void:
	_input_editing = false

func _on_button_command_text_submitted(data: String) -> void:
	if data.strip_edges() != "":
		emit_signal("cmd_text_submitted", data)

func _on_command_text_submitted(data: String) -> void:
	data = data.strip_edges()
	if data == "":
		return
	emit_signal("cmd_text_submitted", data)
	if _previous_cmd.size() >= 10:
		_previous_cmd.pop_front()
	_previous_cmd.append(data)
	_cmd_index = _previous_cmd.size()  # reset to latest
	$Command.clear()

func _process(_delta: float) -> void:
	if _input_editing:
		# ESC to exit edit mode
		if Input.is_action_just_pressed("ui_cancel"):
			_input_editing = false
			$Command.release_focus()
			return

		# Handle command history navigation
		if Input.is_action_just_pressed("ui_up"):
			if _previous_cmd.size() == 0:
				return
			_cmd_index = max(_cmd_index - 1, 0)
			$Command.text = _previous_cmd[_cmd_index]
			$Command.caret_column = $Command.text.length()
		elif Input.is_action_just_pressed("ui_down"):
			if _previous_cmd.size() == 0:
				return
			_cmd_index = min(_cmd_index + 1, _previous_cmd.size() - 1)
			$Command.text = _previous_cmd[_cmd_index]
			$Command.caret_column = $Command.text.length()

	else:
		if Input.is_action_just_pressed("ui_accept"):
			_input_editing = true
			$Command.grab_focus()
			return
			
		# Handle directional movement when not typing
		if Input.is_action_just_pressed("ui_up"):
			emit_signal("cmd_text_submitted", "n")
		elif Input.is_action_just_pressed("ui_down"):
			emit_signal("cmd_text_submitted", "s")
		elif Input.is_action_just_pressed("ui_left"):
			emit_signal("cmd_text_submitted", "w")
		elif Input.is_action_just_pressed("ui_right"):
			emit_signal("cmd_text_submitted", "e")

func _on_button_pressed() -> void:
	_input_editing = true
	$Command.grab_focus()

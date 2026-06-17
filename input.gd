class_name CommandInput
extends Node2D

signal cmd_text_submitted(data: String)

const _HISTORY_LIMIT: int = 100

@onready var command: LineEdit = $Command

var _history: Array[String] = []
var _history_index: int = -1
var _history_draft: String = ""


func _ready() -> void:
	var containers: Variant = $"../Containers"
	containers.button_commands_submitted.connect(_on_button_command_text_submitted)
	var mobs: Variant = $"../Mobs"
	if mobs != null and mobs.has_signal("button_commands_submitted"):
		mobs.button_commands_submitted.connect(_on_button_command_text_submitted)


func _on_button_command_text_submitted(data: String) -> void:
	if data.length() > 0:
		cmd_text_submitted.emit(data)


func _on_command_text_submitted(data: String) -> void:
	var text: String = data if data.length() > 0 else command.text
	cmd_text_submitted.emit(text)
	if text.length() > 0:
		_push_history(text)
	command.clear()
	_history_index = -1
	_history_draft = ""


func _push_history(text: String) -> void:
	if _history.is_empty() or _history.back() != text:
		_history.append(text)
		if _history.size() > _HISTORY_LIMIT:
			_history.pop_front()


func _history_step(direction: int) -> void:
	if _history.is_empty():
		return
	if direction < 0:
		if _history_index == -1:
			_history_draft = command.text
			_history_index = _history.size() - 1
		elif _history_index > 0:
			_history_index -= 1
	else:
		if _history_index == -1:
			return
		elif _history_index < _history.size() - 1:
			_history_index += 1
		else:
			_history_index = -1
	command.text = _history[_history_index] if _history_index != -1 else _history_draft
	command.set_caret_column(command.text.length())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var key: InputEventKey = event as InputEventKey
	if command.has_focus():
		match key.keycode:
			KEY_UP:
				_history_step(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_history_step(1)
				get_viewport().set_input_as_handled()
		return
	match key.keycode:
		KEY_UP:
			cmd_text_submitted.emit("n")
		KEY_DOWN:
			cmd_text_submitted.emit("s")
		KEY_LEFT:
			cmd_text_submitted.emit("w")
		KEY_RIGHT:
			cmd_text_submitted.emit("e")

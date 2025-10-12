extends Node2D

signal cmd_text_submitted(data: String)

func _ready():
	$"../Options".connect("button_commands_submitted", Callable(self, "_on_button_command_text_submitted"))

func _on_button_command_text_submitted(data: String) -> void:
	if len(data) > 0:
		emit_signal("cmd_text_submitted", data)
	
func _on_command_text_submitted(data: String) -> void:
	if len(data) > 0:
		emit_signal("cmd_text_submitted", data)
		$Command.clear()
		return
	var new_text = $Command.text
	emit_signal("cmd_text_submitted", new_text)
	$Command.clear()
	
func _unhandled_input(event: InputEvent) -> void:
	# Handle arrow key input globally (even when Command has focus)
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			match event.keycode:
				KEY_UP:
					emit_signal("cmd_text_submitted", "n")
				KEY_DOWN:
					emit_signal("cmd_text_submitted", "s")
				KEY_LEFT:
					emit_signal("cmd_text_submitted", "w")
				KEY_RIGHT:
					emit_signal("cmd_text_submitted", "e")

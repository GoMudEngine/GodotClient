extends Node2D

signal button_commands_submitted(data: String)

func _on_backpack_button_pressed() -> void:
	emit_signal("button_commands_submitted", "eq")
	
func _on_status_button_pressed() -> void:
	emit_signal("button_commands_submitted", "status")
	
func _on_skills_button_pressed() -> void:
	emit_signal("button_commands_submitted", "skills")

func _on_spells_button_pressed() -> void:
	emit_signal("button_commands_submitted", "spells")

func _on_exit_button_pressed() -> void:
	emit_signal("button_commands_submitted", "quit")

func _on_look_button_pressed() -> void:
	emit_signal("button_commands_submitted", "look")

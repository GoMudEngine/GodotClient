extends Node2D

signal button_commands_submitted(data: String)
	
func _ready():
	$Backpack.visible = false
	$Status.visible = false
	$"../TextProcessor".connect("container_request", Callable(self, "_on_container_request_received"))

func _on_backpack_button_pressed() -> void:
	emit_signal("button_commands_submitted", "eq")
	
func _on_status_button_pressed() -> void:
	emit_signal("button_commands_submitted", "status")
	
func _on_skills_button_pressed() -> void:
	emit_signal("button_commands_submitted", "skills")

func _on_spells_button_pressed() -> void:
	emit_signal("button_commands_submitted", "spells")

func clean_unwanted_symbols(data: String) -> String:
	data = data.replace("┌"," ")
	data = data.replace("┐"," ")
	data = data.replace("└"," ")
	data = data.replace("─"," ")
	data = data.replace("┘"," ")
	data = data.replace(".:"," ")
	data = data.replace("│"," ")
	return data

func _close_all_containers() -> void:
	$Backpack.visible = false
	$Status.visible = false
	$Skills.visible = false
	$Spells.visible = false

func _on_container_request_received(data: String, type: String) -> void:
	data = clean_unwanted_symbols(data)
	_close_all_containers()
	if type == "equipment":
		data = organize_backpack(data)
		$Backpack/TextDisplay.text = data
		if $Backpack.visible:
			$Backpack.visible = false
		else:
			$Backpack.visible = true
	
	if type == "status":
		data = organize_status(data)
		$Status/TextDisplay.text = data
		if $Status.visible:
			$Status.visible = false
		else:
			$Status.visible = true
	
	if type == "skills":
		data = organize_skills(data)
		$Skills/TextDisplay.text = data
		if $Skills.visible:
			$Skills.visible = false
		else:
			$Skills.visible = true
	
	if type == "spells":
		data = organize_spells(data)
		$Spells/TextDisplay.text = data
		if $Spells.visible:
			$Spells.visible = false
		else:
			$Spells.visible = true

func _on_close_pressed() -> void:
	_close_all_containers()

# helpers to organize info
func organize_spells(data: String) -> String:
	return data
	
func organize_skills(data: String) -> String:
	return data
	
func organize_status(data: String) -> String:
	return data
	
func organize_backpack(data: String) -> String:
	return data

extends Node2D
	
func _ready():
	$Backpack.visible = false
	$Status.visible = false
	$"../TextProcessor".connect("container_request", Callable(self, "_on_container_request_received"))

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
	$Targets.visible = false

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

func _on_add_pressed() -> void:
	var new_target = $Targets/LineEdit.text
	if new_target == "":
		return  # skip empty input
	$Targets/LineEdit.text = ""
	Global_Status._target_list.append(new_target)
	if Global_Status._target_list.size() > 5:
		Global_Status._target_list.pop_front()
	_update_target_list()

func _on_remove_pressed() -> void:
	var target_to_remove = $Targets/LineEdit.text
	if target_to_remove == "":
		return  # skip empty input
	$Targets/LineEdit.text = ""
	if target_to_remove in Global_Status._target_list:
		Global_Status._target_list.erase(target_to_remove)
	_update_target_list()
	
func _update_target_list() -> void:
	$Targets/TextDisplay.clear()
	if Global_Status._target_list.size() > 0:
		for t in Global_Status._target_list:
			$Targets/TextDisplay.append_text(t + "\n")

extends Node2D


func _ready():
	$"../TextProcessor".connect("bb_data", Callable(self, "_on_bb_data_received"))
	$"../TextProcessor".connect("exits_text", Callable(self, "_on_exits_text_received"))
	$"../TextProcessor".connect("location_name", Callable(self, "_on_location_name_received"))
	$Map_BG/TextDisplay.bbcode_enabled = true  # important

func _on_bb_data_received(bb_line: String) -> void:
	$Map_BG/TextDisplay.clear()
	$Map_BG/TextDisplay.append_text(bb_line)

func _on_exits_text_received(bb_line: String) -> void:
	bb_line = organize_exits(bb_line)
	$Map_BG/TextDisplay_Exits.text = bb_line

func _on_location_name_received(bb_line: String) -> void:
	bb_line = organize_location_name(bb_line)
	$Map_BG/TextDisplay_Location_Name.text = bb_line

func organize_location_name(data: String) -> String:
	var organized_location_name = []
	var i = 0
	var re_paren := RegEx.new()
	re_paren.compile("\\s*\\(\\d+/\\d+\\)")  # matches "   (11/5)" or "(3/10)" etc.
	for raw_line in data.split("\n", false):
		var line := raw_line.rstrip("\r")
		line = re_paren.sub(line, "", true)
		line = line.replace("[color=#808080]([/color][color=#FFFFFF]•[/color][color=#808080])[/color]","")
		line = line.replace(".:","")
		line = line.replace("  ","")
		organized_location_name.append(line + "\n")
		i += 1
	var text = "".join(organized_location_name)
	return text

func organize_exits(data: String) -> String:
	var organized_exits = []
	var i = 0
	var re_paren := RegEx.new()
	re_paren.compile("\\s*\\(\\d+/\\d+\\)")  # matches "   (11/5)" or "(3/10)" etc.
	for raw_line in data.split("\n", false):
		var line := raw_line.rstrip("\r")
		line = re_paren.sub(line, "", true)
		#print(i, line)
		organized_exits.append(line + "\n")
	var text = "".join(organized_exits)
	return text

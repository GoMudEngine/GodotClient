extends Node2D

func _ready():
	$"../TextProcessor".connect("status_text", Callable(self, "_on_status_text_received"))
	$Status_BG/TextDisplay.bbcode_enabled = true  # important

func _on_status_text_received(bb_line: String) -> void:
	#print(bb_line)
	var n := bb_line.length()
	if n >= 2:
		bb_line = bb_line.substr(24, n -49)
	var r: RichTextLabel = $Status_BG/TextDisplay
	r.clear()
	r.parse_bbcode(bb_line)

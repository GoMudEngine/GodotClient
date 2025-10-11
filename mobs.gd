extends Node2D

func _ready():
	$"../TextProcessor".connect("mobs_text", Callable(self, "_on_mobs_text_received"))
	$Mobs_BG/TextDisplay.bbcode_enabled = true  # important

func _on_mobs_text_received(bb_line: String) -> void:
	bb_line = bb_line.substr(34)
	var r: RichTextLabel = $Mobs_BG/TextDisplay
	r.clear()
	r.parse_bbcode("Objects here: " + bb_line)

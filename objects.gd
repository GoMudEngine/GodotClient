extends Node2D

func _ready():
	$"../TextProcessor".connect("mobs_text", Callable(self, "_on_mobs_text_received"))
	$"../TextProcessor".connect("items_text", Callable(self, "_on_items_text_received"))

func _on_mobs_text_received(bb_line: String) -> void:
	bb_line = bb_line.replace("Also here: ","")
	var r: RichTextLabel = $TextDisplay_Mobs
	r.clear()
	r.parse_bbcode("Mobs here: " + bb_line)

func _on_items_text_received(bb_line: String) -> void:
	bb_line = bb_line.replace("On the Ground: ","")
	var r: RichTextLabel = $TextDisplay_Items
	r.clear()
	r.parse_bbcode("Items here: " + bb_line)

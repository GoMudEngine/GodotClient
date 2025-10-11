extends Node


func _ready():
	$Connection.connect("text_received", Callable(self, "_on_text_received"))
	$Connection.connect("sound_received", Callable(self, "_on_sound_received"))
	$Connection.connect("GMCP_received", Callable(self, "_on_GMCP_received"))
	$Input.connect("cmd_text_submitted", Callable(self, "_on_cmd_text_submitted"))

func _on_text_received(data: String) -> void:
	$TextProcessor._update_lines(data)

func _on_sound_received(data: Dictionary) -> void:
	#print(data)
	pass

func _on_GMCP_received(data: Dictionary) -> void:
	var topic = data.get("topic")
	var topic_details = data.get("data")
	#print(topic)
	#print("------------------------------")
	#print(data)
	#print("------------------------------")
	
func _on_cmd_text_submitted(data: String) -> void:
	$Connection.send_message(data)

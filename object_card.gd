extends PanelContainer

signal action_pressed(command: String)

var name_label: Label = null
var tag_label: Label = null
var icon_texture: TextureRect = null
var action_row: HBoxContainer = null


func configure(object_name: String, tags: String, tooltip: String, icon_path: String, actions: Array, fill: Color, border: Color) -> void:
	_bind_nodes()
	if name_label != null:
		name_label.text = object_name
	if tag_label != null:
		tag_label.text = tags
	if icon_texture != null:
		icon_texture.texture = _load_icon_texture(icon_path)
	tooltip_text = tooltip
	add_theme_stylebox_override("panel", _card_style(fill, border))
	if action_row != null:
		_clear_children(action_row)
		for action: Variant in actions:
			if action is Dictionary:
				action_row.add_child(_make_action_button(action))


func _bind_nodes() -> void:
	if name_label != null:
		return
	name_label = _first_node([
		"Layout/Content/TextBox/NameLabel",
		"Layout/TextBox/NameLabel",
	]) as Label
	tag_label = _first_node([
		"Layout/Content/TextBox/TagLabel",
		"Layout/TextBox/TagLabel",
	]) as Label
	icon_texture = _first_node([
		"Layout/IconFrame/IconTexture",
	]) as TextureRect
	action_row = _first_node([
		"Layout/Content/ActionRow",
		"Layout/ActionRow",
	]) as HBoxContainer


func _first_node(paths: Array[String]) -> Node:
	for path: String in paths:
		var node: Node = get_node_or_null(path)
		if node != null:
			return node
	return null


func _make_action_button(action: Dictionary) -> Button:
	var button: Button = Button.new()
	button.text = str(action.get("label", "Go"))
	button.tooltip_text = str(action.get("tooltip", action.get("command", "")))
	button.custom_minimum_size = Vector2(34.0, 22.0)
	button.add_theme_font_size_override("font_size", 10)
	button.pressed.connect(_on_action_button_pressed.bind(str(action.get("command", ""))))
	return button


func _on_action_button_pressed(command: String) -> void:
	if command != "":
		action_pressed.emit(command)


func _load_icon_texture(icon_path: String) -> Texture2D:
	if icon_path == "":
		return null
	if ResourceLoader.exists(icon_path):
		var resource: Resource = load(icon_path)
		if resource is Texture2D:
			return resource
	if FileAccess.file_exists(icon_path):
		var image: Image = Image.load_from_file(icon_path)
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return null


func _card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		child.queue_free()

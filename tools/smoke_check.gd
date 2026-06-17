extends SceneTree

const MAIN_SCENE_PATH: String = "res://main.tscn"


func _initialize() -> void:
	var failures: Array[String] = []
	var packed_scene: PackedScene = load(MAIN_SCENE_PATH)
	if packed_scene == null:
		_fail(["Could not load " + MAIN_SCENE_PATH])
		return

	var main: Node = packed_scene.instantiate()
	root.add_child(main)
	await process_frame

	_check_node(main, "Connection", failures)
	_check_node(main, "Connection/Status_BG/ConnectButton", failures)
	_check_node(main, "TextProcessor", failures)
	_check_node(main, "Input", failures)
	_check_node(main, "Containers", failures)

	var connection: Variant = main.get_node_or_null("Connection")
	if connection != null:
		if connection.connect_on_ready:
			failures.append("Connection.connect_on_ready must default to false.")
		_check_signal_args(connection, "text_received", ["text"], failures)
		_check_signal_args(connection, "sound_received", ["data"], failures)
		_check_signal_args(connection, "gmcp_received", ["data"], failures)
		_check_signal_args(connection, "connected", [], failures)
		_check_method(connection, "send_gmcp_request", failures)
		_check_method(connection, "get_gmcp_debug_log_path", failures)
		_check_gmcp_parse(connection, failures)
		_check_websocket_url_normalization(connection, failures)

	var text_processor: Variant = main.get_node_or_null("TextProcessor")
	if text_processor != null:
		_check_signal_args(text_processor, "container_request", ["data", "container_type"], failures)
		_check_signal_args(text_processor, "npc_look_description", ["data"], failures)
		_check_npc_look_description_cleaning(text_processor, failures)
		_check_ascii_table_preserved(text_processor, failures)
	var map: Variant = main.get_node_or_null("Map")
	if map != null:
		_check_map_gmcp_priority(map, failures)

	var containers: Variant = main.get_node_or_null("Containers")
	if containers != null:
		_check_equipment_gmcp_ui(containers, failures)
		_check_legacy_equipment_text_ui(containers, failures)
		_check_npc_look_container(containers, failures)
		_check_spells_visual_ui(containers, failures)
	_check_three_window_container_limit(containers, failures)
	var mobs: Variant = main.get_node_or_null("Mobs")
	if mobs != null:
		_check_object_cards(mobs, failures)
	var status: Variant = main.get_node_or_null("Status")
	if status != null:
		_check_status_gmcp_priority(status, failures)

	if connection != null and containers != null:
		_check_inventory_command_alias(main, containers, failures)
	if containers != null:
		_check_draggable_panel_bounds(containers, failures)

	main.queue_free()
	await process_frame

	if failures.is_empty():
		print("Smoke check passed.")
		quit(0)
	else:
		_fail(failures)


func _check_node(parent: Node, node_path: NodePath, failures: Array[String]) -> void:
	if parent.get_node_or_null(node_path) == null:
		failures.append("Missing node: " + str(node_path))


func _check_signal_args(object: Object, signal_name: String, expected_args: Array[String], failures: Array[String]) -> void:
	for signal_info: Dictionary in object.get_signal_list():
		if signal_info.get("name", "") != signal_name:
			continue
		var args: Array = signal_info.get("args", [])
		if args.size() != expected_args.size():
			failures.append("Signal %s expected %d args, found %d." % [signal_name, expected_args.size(), args.size()])
			return
		for index: int in range(expected_args.size()):
			var arg_info: Dictionary = args[index]
			if arg_info.get("name", "") != expected_args[index]:
				failures.append("Signal %s arg %d expected %s, found %s." % [signal_name, index, expected_args[index], arg_info.get("name", "")])
				return
		return
	failures.append("Missing signal: " + signal_name)


func _check_method(object: Object, method_name: String, failures: Array[String]) -> void:
	if not object.has_method(method_name):
		failures.append("Missing method: " + method_name)


func _check_gmcp_parse(connection: Object, failures: Array[String]) -> void:
	var parsed: Dictionary = connection._parse_gmcp("Room.Info {\"name\":\"Test Room\",\"exits\":{\"north\":2}}")
	if parsed.get("topic", "") != "Room.Info":
		failures.append("GMCP parser returned wrong topic.")
		return
	var data: Variant = parsed.get("data")
	if not data is Dictionary or data.get("name", "") != "Test Room":
		failures.append("GMCP parser did not decode JSON object payload.")


func _check_websocket_url_normalization(connection: Object, failures: Array[String]) -> void:
	var cases: Dictionary = {
		"https://gomud.net/": "wss://gomud.net/ws",
		"https://gomud.net": "wss://gomud.net/ws",
		"http://localhost:8080/": "ws://localhost:8080/ws",
		"gomud.net": "wss://gomud.net/ws",
		"wss://gomud.net": "wss://gomud.net/ws",
		"wss://gomud.net/ws": "wss://gomud.net/ws",
	}
	for input: String in cases.keys():
		var normalized: String = connection.normalize_websocket_url(input)
		if normalized != cases[input]:
			failures.append("URL normalization failed for %s: got %s." % [input, normalized])


func _check_status_gmcp_priority(status: Object, failures: Array[String]) -> void:
	if not status.has_method("apply_gmcp"):
		failures.append("Status panel is missing GMCP apply method.")
		return
	var state: Dictionary = {"Char": {"Vitals": {"hp": 6, "hp_max": 6, "sp": 5, "sp_max": 5}}}
	status.apply_gmcp("Char.Vitals", state["Char"]["Vitals"], state)
	var label: RichTextLabel = status.get_node_or_null("Status_BG/TextDisplay")
	if label == null:
		failures.append("Status panel is missing TextDisplay.")
		return
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		failures.append("Status bar must disable autowrap to avoid HP/SP line breaks.")
	var gmcp_text: String = label.text
	if gmcp_text.find("\n") != -1:
		failures.append("GMCP status bar should render as one compact line.")
	status._on_status_text_received("(legacy fallback\nshould not replace gmcp)")
	if label.text != gmcp_text:
		failures.append("Legacy status text should not replace active GMCP vitals.")


func _check_equipment_gmcp_ui(containers: Object, failures: Array[String]) -> void:
	if not containers.has_method("show_equipment_gmcp"):
		failures.append("Missing method: show_equipment_gmcp")
		return
	var gmcp_state: Dictionary = {
		"Char": {
			"Info": {
				"name": "Tester",
				"level": 7,
				"race": "elf",
				"class": "scrub",
				"alignment": "neutral",
				"skillpoints": 1,
				"trainingpoints": 6,
			},
			"Stats": {
				"strength": 8,
				"strengthmod": 1,
				"speed": 7,
				"smarts": 6,
				"vitality": 9,
				"mysticism": 5,
				"perception": 4,
			},
			"Vitals": {"hp": 6, "hp_max": 6, "sp": 5, "sp_max": 5},
			"Worth": {"gold_carry": 0, "gold_bank": 100, "xp": 36031, "tnl": 45300},
			"Affects": {"Illumination": {}, "Night Vision": {}},
			"Kills": {"mob": {"total": 82, "deaths": 2}, "pvp": {"total": 0, "deaths": 0}},
			"Inventory": {
				"Backpack": {
					"Summary": {"max": 5},
					"items": [],
				},
				"Worn": {
					"weapon": {
						"id": "!test",
						"name": "sharp stick",
						"type": "weapon",
						"subtype": "bludgeoning",
						"uses": 0,
						"details": ["1-handed"],
					},
				},
			},
		},
	}
	containers.show_equipment_gmcp(gmcp_state)
	var backpack: Node = containers.get_node_or_null("Backpack")
	if backpack == null or not backpack.visible:
		failures.append("GMCP equipment UI did not show the Backpack panel.")
	var equipment_scroll: ScrollContainer = containers.get_node_or_null("Backpack/BackpackGMCP")
	if equipment_scroll == null:
		failures.append("GMCP backpack scroll root should be editable as Backpack/BackpackGMCP.")
	if containers.get_node_or_null("Backpack/EquipmentGMCP") != null:
		failures.append("Backpack must not contain legacy EquipmentGMCP nodes.")
	if containers.get_node_or_null("Backpack/BackpackGMCP/BackpackContent/NpcLookHeader") != null:
		failures.append("Backpack must not contain NPC look UI nodes.")
	if containers.get_node_or_null("Backpack/BackpackGMCP/BackpackContent/EquipmentGrid") != null:
		failures.append("Backpack must not contain an equipment grid.")
	var backpack_grid: GridContainer = containers.get_node_or_null("Backpack/BackpackGMCP/BackpackContent/BackpackGrid")
	if backpack_grid == null or not backpack_grid.visible:
		failures.append("Player Backpack GMCP UI should show only the backpack item grid.")
	if containers.get_node_or_null("Backpack/BackpackDetail") == null:
		failures.append("Backpack item detail panel should be editable as Backpack/BackpackDetail.")
	containers.show_status_gmcp(gmcp_state)
	var status_panel_node: Node = containers.get_node_or_null("Status/StatusGMCP")
	var status_panel: Control = status_panel_node if status_panel_node is Control else null
	var status_close: Control = containers.get_node_or_null("Status/Close")
	if status_panel == null:
		failures.append("Score GMCP UI should be editable in Containers.tscn as Status/StatusGMCP.")
	if status_panel != null and status_close != null and status_panel.offset_bottom > status_close.offset_top - 4.0:
		failures.append("Score GMCP panel must stay above the Close button.")
	var character_icon: TextureRect = containers.get_node_or_null("Status/StatusGMCP/StatusContent/StatusSection/StatusHeader/CharacterIcon")
	if character_icon == null:
		failures.append("Score status section should include an editable CharacterIcon node.")
	elif character_icon.texture == null:
		failures.append("Score status CharacterIcon should load a player portrait or status fallback icon.")
	if containers.has_method("_player_portrait_icon_path"):
		var portrait_path: String = containers._player_portrait_icon_path(gmcp_state["Char"]["Info"])
		if portrait_path != "res://assets/player_portraits/by_race_class/elf_scrub.png":
			failures.append("Score status CharacterIcon should resolve player portraits by race and class.")
	var character_name: Label = containers.get_node_or_null("Status/StatusGMCP/StatusContent/StatusSection/StatusHeader/CharacterText/CharacterName")
	if character_name == null:
		failures.append("Score status section should include an editable CharacterName label.")
	elif character_name.text != "Tester":
		failures.append("Score status CharacterName should be filled from GMCP Char.Info.")
	var hp_value: Label = containers.get_node_or_null("Status/StatusGMCP/StatusContent/StatusSection/StatusStats/HPValue")
	if hp_value == null:
		failures.append("Score status table should include an HPValue label.")
	elif hp_value.text != "6 / 6":
		failures.append("Score status HPValue should be filled from GMCP Char.Vitals.")
	var xp_label: Label = containers.get_node_or_null("Status/StatusGMCP/StatusContent/StatusSection/StatusStats/XPLabel")
	var xp_value: Label = containers.get_node_or_null("Status/StatusGMCP/StatusContent/StatusSection/StatusStats/XPValue")
	var tnl_value: Label = containers.get_node_or_null("Status/StatusGMCP/StatusContent/StatusSection/StatusStats/TNLValue")
	if xp_label == null or xp_label.text != "XP/TNL":
		failures.append("Score status XP row should be labeled XP/TNL.")
	if xp_value == null or xp_value.text != "36031 / 45300":
		failures.append("Score status XPValue should combine XP and TNL as XP / TNL.")
	if tnl_value != null and tnl_value.visible:
		failures.append("Score status should not show a separate TNL value row.")
	var attributes_value: Label = containers.get_node_or_null("Status/StatusGMCP/StatusContent/StatusSection/StatusStats/AttributesValue")
	if attributes_value == null:
		failures.append("Score status table should include an AttributesValue label for Char.Stats.")
	elif not attributes_value.text.contains("STR 8(+1)") or not attributes_value.text.contains("PER 4"):
		failures.append("Score status AttributesValue should be filled from GMCP Char.Stats.")
	for icon_path: String in [
		"Status/StatusGMCP/StatusContent/StatusSection/StatusStats/HPIcon",
		"Status/StatusGMCP/StatusContent/StatusSection/StatusStats/SPIcon",
		"Status/StatusGMCP/StatusContent/StatusSection/StatusStats/GoldIcon",
		"Status/StatusGMCP/StatusContent/StatusSection/StatusStats/XPIcon",
		"Status/StatusGMCP/StatusContent/StatusSection/StatusStats/AffectsIcon",
	]:
		var icon: TextureRect = containers.get_node_or_null(icon_path)
		if icon == null:
			failures.append("Score status icon node is missing: " + icon_path)
		elif icon.texture == null:
			failures.append("Score status icon texture is missing: " + icon_path)
	if containers.get_node_or_null("Status/StatusEquipmentGMCP") != null:
		failures.append("Player equipment must live in its own Equipment popup, not under Status.")
	containers.show_player_equipment_gmcp(gmcp_state)
	var equipment_icon: TextureRect = containers.get_node_or_null("Equipment/Move/EquipmentIcon")
	if equipment_icon == null:
		equipment_icon = containers.get_node_or_null("Equipment/EquipmentGMCP/EquipmentContent/EquipmentIcon")
	if equipment_icon == null:
		failures.append("Player Equipment popup should include an editable EquipmentIcon node.")
	elif equipment_icon.texture == null:
		failures.append("Player Equipment popup icon texture is missing.")
	var status_equipment_grid: GridContainer = containers.get_node_or_null("Equipment/EquipmentGMCP/EquipmentContent/EquipmentGrid")
	if containers.get_node_or_null("Status/StatusGMCP/StatusContent/EquipmentGrid") != null:
		failures.append("Score equipment section must not be nested inside StatusGMCP/StatusContent.")
	if status_equipment_grid == null or status_equipment_grid.get_child_count() == 0:
		failures.append("Player Equipment popup should render the player equipment section.")
	else:
		var first_cell: Node = status_equipment_grid.get_child(0)
		if not first_cell is VBoxContainer:
			failures.append("Player equipment slots must render as labeled cells.")
		elif first_cell.get_child_count() < 2 or not first_cell.get_child(0) is Label:
			failures.append("Player equipment slot cell is missing its slot label.")
		var weapon_cell: VBoxContainer = status_equipment_grid.get_child(8) if status_equipment_grid.get_child_count() > 8 and status_equipment_grid.get_child(8) is VBoxContainer else null
		var weapon_slot: PanelContainer = weapon_cell.get_child(1) if weapon_cell != null and weapon_cell.get_child_count() > 1 and weapon_cell.get_child(1) is PanelContainer else null
		if weapon_slot == null:
			failures.append("Player equipment weapon slot did not render as a clickable panel.")
		elif weapon_slot.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
			failures.append("Player equipment items should be clickable for look/remove actions.")
	var detail: RichTextLabel = containers.get_node_or_null("Equipment/EquipmentDetail")
	if detail == null:
		detail = containers.get_node_or_null("Equipment/EquipmentGMCP/EquipmentContent/EquipmentDetail")
	if detail == null:
		var found_detail: Node = containers.get_node("Equipment").find_child("EquipmentDetail", true, false)
		if found_detail is RichTextLabel:
			detail = found_detail
	if detail == null:
		failures.append("Player equipment detail label was not created.")
	elif not detail.scroll_active:
		failures.append("Player equipment detail label must allow scrolling for long item info.")
	if not containers.has_method("_item_command_target") or not containers.has_method("_inventory_actions_for_item"):
		failures.append("GMCP equipment UI is missing inventory slot action helpers.")
		return
	var potion: Dictionary = {
		"id": "!30002:1-0290546cb363900-01-00000000000000",
		"name": "ambrosia potion",
		"type": "potion",
		"subtype": "drinkable",
	}
	if containers._item_command_target(potion) != potion["id"]:
		failures.append("Inventory action target must preserve the full GMCP item id.")
	if containers._item_tooltip("1", potion).contains("ID:"):
		failures.append("Inventory detail should not display raw GMCP item ids.")
	var belt: Dictionary = {
		"id": "!20009:1-test",
		"name": "cloth belt",
		"type": "belt",
		"subtype": "wearable",
	}
	if not containers._item_tooltip("Belt", belt).contains("Just enough to hold your pants up."):
		failures.append("Inventory detail should include local item metadata descriptions when GMCP omits them.")
	var actions: Array = containers._inventory_actions_for_item(potion, "backpack")
	var has_look: bool = false
	var has_drink: bool = false
	var has_drop: bool = false
	for action: Dictionary in actions:
		has_look = has_look or str(action.get("command", "")) == "look " + potion["id"]
		has_drink = has_drink or str(action.get("command", "")) == "drink " + potion["id"]
		has_drop = has_drop or str(action.get("command", "")) == "drop " + potion["id"]
	if not has_look or not has_drink or not has_drop:
		failures.append("Backpack potion actions must include look, drink, and drop commands.")
	var equipment_actions: Array = containers._inventory_actions_for_item({
		"id": "!10001:1-equipped",
		"name": "sharp stick",
		"type": "weapon",
		"subtype": "bludgeoning",
	}, "equipment")
	var has_remove: bool = false
	for action: Dictionary in equipment_actions:
		has_remove = has_remove or str(action.get("command", "")) == "remove !10001:1-equipped"
	if not has_remove:
		failures.append("Score equipment actions must include remove commands for equipped items.")


func _check_legacy_equipment_text_ui(containers: Object, failures: Array[String]) -> void:
	if not containers.has_method("show_equipment_text"):
		failures.append("Missing method: show_equipment_text")
		return
	var shown: bool = containers.show_equipment_text("Equipment\nWeapon\nsharp stick\nOffhand\n-nothing-\nHead\nrusty pot\n")
	if not shown:
		failures.append("Legacy equipment text should render through the GMCP-style equipment UI.")
		return
	var compact_shown: bool = containers.show_equipment_text("[color=#0000FF]Equipment[/color] Weapon -nothing- Offhand -nothing- Head rusty pot Neck -nothing-")
	if not compact_shown:
		failures.append("Legacy equipment text parser should handle compact ANSI/BBCode output.")
		return
	var carrying_shown: bool = containers.show_equipment_text("Equipment Body animal skin Carrying no objects Feet -nothing- Carrying no objects")
	if not carrying_shown:
		failures.append("Legacy equipment text parser should stop before carrying sections.")
		return
	var body_item: Dictionary = containers._legacy_equipment_item("animal skin Carrying no objects", "body")
	if str(body_item.get("name", "")).contains("Carrying"):
		failures.append("Legacy equipment item names must not include carrying section text.")
	var simple_body_item: Dictionary = containers._legacy_equipment_item("shirt", "body")
	if str(simple_body_item.get("id", "")) != "!20008" or str(simple_body_item.get("name", "")) != "cotton shirt":
		failures.append("Legacy NPC equipment should resolve namesimple item names using the equipment slot.")
	if not containers._item_tooltip("Body", simple_body_item).contains("Surprisingly clean."):
		failures.append("Namesimple-resolved NPC equipment should use local item metadata details.")
	var empty_feet: Dictionary = containers._legacy_equipment_item("-nothing- Carrying no objects", "feet")
	if not empty_feet.is_empty():
		failures.append("Legacy empty equipment slots must stay empty when followed by carrying section text.")
	var boxed_empty_feet: Dictionary = containers._legacy_equipment_item("-nothing- | __________________________", "feet")
	if not boxed_empty_feet.is_empty():
		failures.append("Legacy empty equipment slots must stay empty when followed by box/table separator text.")
	var boxed_equipment: Dictionary = containers._parse_legacy_equipment_text("Equipment\nFeet\n-nothing- |\n________________________________________\nWeapon\nsword\n")
	var parsed_feet: Dictionary = boxed_equipment.get("feet", {}) if boxed_equipment.get("feet", {}) is Dictionary else {}
	if not boxed_equipment.has("weapon") or not parsed_feet.is_empty():
		failures.append("Legacy equipment parser must ignore box/table separator lines after empty NPC equipment slots.")
	if containers.get_node_or_null("Backpack/TextDisplay") != null:
		failures.append("Backpack should not keep a legacy TextDisplay because it is GMCP-only.")
	var equipment_grid: GridContainer = containers.get_node_or_null("Equipment/EquipmentGMCP/EquipmentContent/EquipmentGrid")
	if equipment_grid == null or equipment_grid.get_child_count() == 0:
		failures.append("Legacy equipment text should render in the Equipment popup, not Backpack.")


func _check_npc_look_container(containers: Object, failures: Array[String]) -> void:
	if not containers.has_method("show_npc_look_text") or not containers.has_method("set_pending_npc_look_context"):
		failures.append("Containers is missing NPC look container methods.")
		return
	if containers.has_method("_close_all_containers"):
		containers._close_all_containers()
	containers.set_pending_npc_look_context({
		"target": "#131",
		"object": {
			"id": "#131",
			"name": "wench",
			"adjectives": ["shop"],
			"quest_flag": true,
		},
	})
	var shown: bool = containers.show_npc_look_text({
		"name": "wench",
		"description": "In the lively atmosphere of the inn, a serving wench navigates through the crowd.",
	}, "Equipment\nBody\nshirt\nFeet\nboots\nWeapon\nsword\n")
	if not shown:
		failures.append("NPC look text should render in its own NPC Look popup.")
		return
	var npc_panel: Node = containers.get_node_or_null("NpcLook")
	if npc_panel == null or not npc_panel.visible:
		failures.append("NPC look should show the NpcLook popup.")
	var equipment_panel: Node = containers.get_node_or_null("Equipment")
	if equipment_panel != null and equipment_panel.visible:
		failures.append("NPC look must not reuse or show the player Equipment popup.")
	var title: Button = containers.get_node_or_null("NpcLook/Move")
	if title == null or title.text != "wench":
		failures.append("NPC look popup title should be the NPC name.")
	var description: RichTextLabel = containers.get_node_or_null("NpcLook/NpcLookGMCP/NpcLookContent/NpcLookHeader/NpcLookTopRow/NpcLookDescription")
	if description == null or not description.text.contains("serving wench"):
		failures.append("NPC look popup should include the cleaned NPC description.")
	var action_row: HBoxContainer = containers.get_node_or_null("NpcLook/NpcLookGMCP/NpcLookContent/NpcLookHeader/NpcLookActions")
	if action_row == null:
		failures.append("NPC look popup should include interaction buttons.")
	else:
		var actions: Array[String] = []
		for child: Node in action_row.get_children():
			if child is Button:
				actions.append(child.text)
		for expected: String in ["Look", "Atk", "Ask", "List"]:
			if not actions.has(expected):
				failures.append("NPC look popup is missing action button: " + expected)
	var npc_grid: GridContainer = containers.get_node_or_null("NpcLook/NpcLookGMCP/NpcLookContent/EquipmentGrid")
	if npc_grid == null or npc_grid.get_child_count() == 0:
		failures.append("NPC look popup should render NPC equipment in its own grid.")


func _check_spells_visual_ui(containers: Object, failures: Array[String]) -> void:
	if not containers.has_method("show_spells_text"):
		failures.append("Containers must expose show_spells_text for spell table output.")
		return
	var sample: String = "\n".join([
		".: Spells",
		"| SpellId | Name | Description | Target | MPs | Wait | Casts | % Chance |",
		"| 101 | Minor Heal | Restore a small amount of health | ally | 5 | 2 | 14 | 90 |",
	])
	if not containers.show_spells_text(sample, false):
		failures.append("Spells popup should parse legacy spell table into visual UI.")
		return
	var spells_gmcp: CanvasItem = containers.get_node_or_null("Spells/SpellsGMCP")
	var spells_text: CanvasItem = containers.get_node_or_null("Spells/TextDisplay")
	var spells_list_node: Node = containers.get_node_or_null("Spells/SpellsGMCP/SpellsContent/SpellsScroll/SpellsList")
	var spells_list: VBoxContainer = spells_list_node as VBoxContainer
	if spells_gmcp == null or not spells_gmcp.visible:
		failures.append("Spells visual UI should be visible after parsing spell table.")
	if spells_text != null and spells_text.visible:
		failures.append("Spells legacy TextDisplay should be hidden when visual UI is active.")
	if spells_list == null or spells_list.get_child_count() == 0:
		failures.append("Spells visual UI should render at least one spell row.")


func _check_npc_look_description_cleaning(text_processor: Object, failures: Array[String]) -> void:
	if not text_processor.has_method("_npc_look_description_data"):
		failures.append("TextProcessor is missing NPC look description parser.")
		return
	var descs: Array = [
		"\u250C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510",
		"\u2502 .:Description \u2502",
		"\u2502 In the lively atmosphere of the inn, a serving wench navigates through the crowd. \u2502",
		"\u2502 wench is in perfect health. \u2502",
		"\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518",
	]
	var parsed: Dictionary = text_processor._npc_look_description_data(descs, " ".join(descs))
	var description: String = str(parsed.get("description", ""))
	if not description.contains("serving wench"):
		failures.append("NPC look description parser should keep description content.")
	if description.contains("\u2502") or description.contains("\u2500") or description.contains("Description"):
		failures.append("NPC look description parser should remove legacy box drawing and title text.")
	if description.to_lower().contains("perfect health"):
		failures.append("NPC look description parser should remove health status text from the description.")


func _check_ascii_table_preserved(text_processor: Object, failures: Array[String]) -> void:
	if not text_processor.has_method("_process_one_bb_line"):
		failures.append("TextProcessor is missing line processing for ASCII table preservation.")
		return
	var display: RichTextLabel = text_processor.get_node_or_null("TextDisplay")
	if display == null:
		failures.append("TextProcessor is missing TextDisplay.")
		return
	display.clear()
	var shop_table: String = "\n".join([
		".: Items available by armorer",
		"┌─────┬────────────────────┬──────────┬───────┐",
		"│ Qty │ Name               │ Type     │ Price │",
		"├─────┼────────────────────┼──────────┼───────┤",
		"│ 1   │ worn boots         │ feet     │ 22    │",
		"│ 1   │ cotton shirt       │ body     │ 22    │",
		"└─────┴────────────────────┴──────────┴───────┘",
		"To buy something, type: buy [name]",
	])
	text_processor._process_one_bb_line(shop_table)
	var output: String = _rich_text_content(display)
	if not output.contains("┌") or not output.contains("│ Qty │") or not output.contains("└"):
		failures.append("Boxed shop/list ASCII art should stay intact in the main text display.")
	if output.contains("Qty Name Type Price") or output.contains("1 worn boots feet 22"):
		failures.append("Boxed shop/list ASCII art should not be flattened into plain text columns.")


func _check_map_gmcp_priority(map: Object, failures: Array[String]) -> void:
	if not map.has_method("apply_gmcp"):
		failures.append("Map panel is missing GMCP apply method.")
		return
	map._map_history_path = "user://smoke_map_history.json"
	map._rooms_by_key.clear()
	map._map_history_loaded = true
	map.apply_gmcp("Room.Info", {
		"name": "The Sanctuary",
		"area": "Frostfang",
		"coords": "Frostfang, 2, 4, 0",
		"mapsymbol": ".",
		"maplegend": "Interior",
		"exitsv2": {
			"west": {"dx": -1, "dy": 0, "dz": 0},
			"east": {"dx": 1, "dy": 0, "dz": 0},
		},
	}, {})
	var map_text: RichTextLabel = map.get_node_or_null("Map_BG/TextDisplay")
	var exits_text: RichTextLabel = map.get_node_or_null("Map_BG/TextDisplay_Exits")
	var tile_grid: GridContainer = map.get_node_or_null("Map_BG/TileMapView")
	if map_text == null or exits_text == null or tile_grid == null:
		failures.append("Map panel is missing display labels.")
		return
	var gmcp_map_text: String = _rich_text_content(map_text)
	var gmcp_exits_text: String = _rich_text_content(exits_text)
	if not tile_grid.visible or map_text.visible:
		failures.append("GMCP map should render as tile grid and hide legacy text map display.")
	var has_current_tile: bool = false
	var has_connector_tile: bool = false
	for child: Node in tile_grid.get_children():
		if child is Label:
			has_current_tile = has_current_tile or child.text == "@"
			has_connector_tile = has_connector_tile or child.text == "─" or child.text == "│"
	if not has_current_tile or not has_connector_tile or not gmcp_exits_text.contains("east") or not gmcp_exits_text.contains("west"):
		failures.append("Map panel should render current room, connectors, and exits from GMCP Room.Info.")
	if map.has_method("_on_bb_data_received"):
		map._on_bb_data_received("legacy text map should not overwrite gmcp")
	if _rich_text_content(map_text) != gmcp_map_text or not tile_grid.visible:
		failures.append("Legacy map text must not overwrite GMCP Room.Info tile map output.")
	map._rooms_by_key.clear()
	map._map_history_loaded = false
	map._load_map_history()
	var saved_room: Dictionary = map._rooms_by_key.get("Frostfang:2:4:0", {})
	if str(saved_room.get("name", "")) != "The Sanctuary":
		failures.append("GMCP map history should persist visited rooms to user:// storage and reload them.")


func _rich_text_content(label: RichTextLabel) -> String:
	if label.has_method("get_parsed_text"):
		return label.get_parsed_text()
	return label.text


func _check_object_cards(mobs: Object, failures: Array[String]) -> void:
	var emitted: Array[String] = []
	mobs.button_commands_submitted.connect(func(command: String) -> void: emitted.append(command))
	mobs.apply_gmcp("Room.Info", {
		"Contents": {
			"Npcs": [
				{
					"id": "#45",
					"name": "Rodric",
					"adjectives": ["shop"],
					"aggro": false,
					"quest_flag": true,
				},
				{
					"id": "#11",
					"name": "guard",
					"adjectives": ["patrolling"],
					"aggro": true,
					"quest_flag": false,
				},
			],
			"Items": [
				{
					"id": "!20001:0",
					"name": "rat pelt",
					"quest_flag": false,
				},
			],
			"Containers": [],
			"Players": [],
		},
	}, {})
	var scroll: ScrollContainer = mobs.get_node_or_null("Mobs_BG/ObjectCards")
	if scroll == null:
		failures.append("GMCP object card scroll root was not created.")
		return
	if not scroll.visible:
		failures.append("GMCP object card list should be visible after Room.Info Contents payload.")
	if scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		failures.append("GMCP object card list should allow vertical scrolling.")
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		failures.append("GMCP object card list should be a single vertical column without horizontal scrolling.")
	if mobs.has_method("_on_mobs_text_received"):
		mobs._on_mobs_text_received("legacy objects line that should not replace GMCP cards")
		if not scroll.visible:
			failures.append("Legacy look text should not hide GMCP object cards after Room.Info Contents payload.")
	var card_list: VBoxContainer = mobs.get_node_or_null("Mobs_BG/ObjectCards/CardList")
	if card_list == null:
		failures.append("GMCP object card list was not created.")
		return
	if card_list.get_child_count() != 3:
		failures.append("GMCP object card list should render one card per room NPC or item.")
		return
	var first_card: Node = card_list.get_child(0)
	if not first_card is PanelContainer:
		failures.append("GMCP room objects should render as card panels.")
	else:
		var icon_texture: TextureRect = first_card.get_node_or_null("Layout/IconFrame/IconTexture")
		var action_row: HBoxContainer = first_card.get_node_or_null("Layout/Content/ActionRow")
		if icon_texture == null:
			failures.append("GMCP object card should include an editable icon texture slot.")
		if action_row == null:
			failures.append("GMCP object card actions should render in the content action row.")
	var object_card_scene: PackedScene = load("res://object_card.tscn")
	var template_card: Control = object_card_scene.instantiate()
	var expected_card_size: Vector2 = Vector2(
		max(template_card.custom_minimum_size.x, template_card.size.x),
		max(template_card.custom_minimum_size.y, template_card.size.y)
	)
	if first_card is Control and first_card.custom_minimum_size != expected_card_size:
		failures.append("GMCP object cards should keep object_card.tscn edited size.")
	template_card.queue_free()
	if mobs.has_method("_name_slug") and mobs._name_slug("SulanViervilla's Guide") != "sulanviervilla_s_guide":
		failures.append("GMCP mob icon name normalization should match the documented mob icon paths.")
	if mobs.has_method("_object_icon_path"):
		var item_icon_path: String = mobs._object_icon_path({"_kind": "item", "id": "!20001:0", "name": "rat pelt"})
		if item_icon_path != "res://assets/items/by_id/20001.png":
			failures.append("GMCP item object cards should resolve item icons by stable GoMud item id.")
		var mob_icon_path: String = mobs._object_icon_path({"_kind": "npc", "id": "#1", "name": "rat"})
		if not mob_icon_path.begins_with("res://assets/mobs/by_name/") and mob_icon_path != "res://assets/items/default_item.png":
			failures.append("GMCP mob object cards should resolve by normalized mob name or default mob fallback.")
	var first_button: Button = _find_button_with_text(first_card, "Look")
	if first_button == null:
		failures.append("GMCP object card should include a Look action.")
	else:
		first_button.pressed.emit()
		if emitted.is_empty() or emitted[0] != "look #45":
			failures.append("GMCP NPC Look action should target the server-provided #id.")
	var item_card: Node = card_list.get_child(2)
	var get_button: Button = _find_button_with_text(item_card, "Get")
	if get_button == null:
		failures.append("GMCP item card should include a Get action.")
	else:
		get_button.pressed.emit()
		if emitted.size() < 2 or emitted[1] != "get !20001:0":
			failures.append("GMCP item Get action should target the server-provided !id.")
	var many_npcs: Array[Dictionary] = []
	for index: int in range(18):
		many_npcs.append({
			"id": "#%d" % (100 + index),
			"name": "rat",
			"adjectives": [],
			"aggro": index % 2 == 0,
			"quest_flag": false,
		})
	mobs.apply_gmcp("Room.Info", {"Contents": {"Npcs": many_npcs, "Items": [], "Containers": [], "Players": []}}, {})
	var overflowing_list: VBoxContainer = mobs.get_node_or_null("Mobs_BG/ObjectCards/CardList")
	if overflowing_list != null and scroll.size.y > 0.0 and overflowing_list.get_combined_minimum_size().y <= scroll.size.y:
		failures.append("GMCP object card content should exceed the scroll viewport when many room objects render.")
	if scroll.size.y > mobs.get_node("Mobs_BG").size.y:
		failures.append("GMCP object card scroll viewport should not grow taller than the Objects panel.")


func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child: Node in node.get_children():
		var found: Button = _find_button_with_text(child, text)
		if found != null:
			return found
	return null


func _check_inventory_command_alias(main: Object, containers: Object, failures: Array[String]) -> void:
	if not main.has_method("_process_gmcp") or not main.has_method("_handle_local_command"):
		failures.append("Main is missing GMCP command helper methods.")
		return
	main._process_gmcp("Char.Inventory", {
		"Backpack": {"Summary": {"max": 5}},
		"Worn": {
			"weapon": {
				"id": "!10001:test",
				"name": "sharp stick",
				"type": "weapon",
				"subtype": "bludgeoning",
				"uses": 0,
				"details": ["1-handed"],
			},
		},
	})
	if not main._handle_local_command("i"):
		failures.append("Inventory alias 'i' was not handled as a local GMCP command.")
		return
	if not main._handle_local_command("/ui inventory"):
		failures.append("Toolbar inventory command was not handled as a local GMCP UI command.")
		return
	var equipment_root: Node = containers.get_node_or_null("Backpack/BackpackGMCP")
	if equipment_root == null or not equipment_root.visible:
		failures.append("Inventory alias 'i' did not show the GMCP Backpack UI.")


func _check_draggable_panel_bounds(containers: Node, failures: Array[String]) -> void:
	var backpack: Control = containers.get_node_or_null("Backpack")
	if backpack == null:
		failures.append("Missing draggable Backpack panel.")
		return
	if not backpack.has_method("_clamp_inside_viewport"):
		failures.append("Draggable panels must expose viewport clamp behavior.")
		return

	backpack.visible = true
	backpack.global_position = Vector2(-120.0, -80.0)
	backpack._clamp_inside_viewport()
	var viewport_rect: Rect2 = backpack.get_viewport().get_visible_rect()
	if backpack.global_position.x < viewport_rect.position.x or backpack.global_position.y < viewport_rect.position.y:
		failures.append("Draggable panel clamp must prevent negative viewport positions.")

	backpack.global_position = viewport_rect.position + viewport_rect.size + Vector2(120.0, 80.0)
	backpack._clamp_inside_viewport()
	var backpack_rect: Rect2 = backpack.get_global_rect()
	if backpack_rect.end.x > viewport_rect.end.x + 0.1 or backpack_rect.end.y > viewport_rect.end.y + 0.1:
		failures.append("Draggable panel clamp must keep the panel inside the viewport end bounds.")


func _check_three_window_container_limit(containers: Object, failures: Array[String]) -> void:
	if not containers.has_method("show_equipment_gmcp") or not containers.has_method("show_player_equipment_gmcp") or not containers.has_method("show_skills_gmcp") or not containers.has_method("show_status_gmcp"):
		failures.append("Containers must expose GMCP popup methods for window limit checks.")
		return
	var gmcp_state: Dictionary = {
		"Char": {
			"Inventory": {"Backpack": {"Summary": {"max": 5}}, "Worn": {}},
			"Info": {"name": "Tester", "level": 1, "race": "human", "class": "none"},
			"Vitals": {"hp": 6, "hp_max": 6, "sp": 5, "sp_max": 5},
			"Skills": [{"name": "slash", "level": 1, "maximum": false}],
			"Jobs": [{"name": "warrior", "proficiency": "scrub", "completion": 0.25}],
		},
	}
	containers.show_equipment_gmcp(gmcp_state)
	containers.show_skills_gmcp(gmcp_state)
	var skills_gmcp: CanvasItem = containers.get_node_or_null("Skills/SkillsGMCP")
	var skills_text: CanvasItem = containers.get_node_or_null("Skills/TextDisplay")
	var jobs_list_node: Node = containers.get_node_or_null("Skills/SkillsGMCP/SkillsContent/JobsSection/JobsScroll/JobsList")
	var jobs_list: VBoxContainer = jobs_list_node as VBoxContainer
	var skills_list_node: Node = containers.get_node_or_null("Skills/SkillsGMCP/SkillsContent/SkillsSection/SkillsScroll/SkillsList")
	var skills_list: VBoxContainer = skills_list_node as VBoxContainer
	if skills_gmcp == null or not skills_gmcp.visible:
		failures.append("Skills popup should render GMCP data through editable SkillsGMCP UI.")
	if skills_text != null and skills_text.visible:
		failures.append("Skills legacy TextDisplay should be hidden when GMCP skills UI is active.")
	if jobs_list == null or jobs_list.get_child_count() == 0:
		failures.append("Skills GMCP UI should render job rows.")
	if skills_list == null or skills_list.get_child_count() == 0:
		failures.append("Skills GMCP UI should render skill rows.")
	containers.show_status_gmcp(gmcp_state)
	var backpack: CanvasItem = containers.get_node_or_null("Backpack")
	var skills: CanvasItem = containers.get_node_or_null("Skills")
	var status: CanvasItem = containers.get_node_or_null("Status")
	var equipment: CanvasItem = containers.get_node_or_null("Equipment")
	if backpack == null or skills == null or status == null or equipment == null:
		failures.append("Container panels missing during window limit check.")
		return
	if not backpack.visible or not skills.visible or not status.visible:
		failures.append("Opening three popups should keep all three visible.")
	containers.show_player_equipment_gmcp(gmcp_state)
	if backpack.visible:
		failures.append("Opening a fourth popup should close the oldest popup.")
	if not skills.visible or not status.visible or not equipment.visible:
		failures.append("Opening a fourth popup should keep the three most recent popups visible.")


func _fail(failures: Array[String]) -> void:
	for failure: String in failures:
		push_error(failure)
	quit(1)

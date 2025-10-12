GoMudEngine / GodotClient

GoDot Mud Client for GoMud
A Godot-based client for connecting to and interacting with GoMud servers.

📦 Features

Real-time MUD (text-based) client in Godot

Supports commands, output parsing, and client-side UI

Modular scenes: input, text processing, status, maps, mobs, containers, etc.

UTF-8 / Unicode support for multilingual text

Lightweight and extendable — built in GDScript

Ready for HTML5 export / desktop

🚀 Getting Started
Prerequisites

Godot engine (version ≥ 4.x recommended)

Basic familiarity with Godot scenes, signals, and scripting

Installation / Setup

Clone the repository

git clone https://github.com/GoMudEngine/GodotClient.git
cd GodMudClient


Open the project in Godot
Open the project.godot file with your Godot editor.

Run the main scene
The main.tscn is the entry point. Start it to launch the client.

Configure connection
Adjust connection settings (host, port, protocol) in connection.gd or via UI, depending on your server setup.

🛠️ Usage & Structure

Here is a quick overview of core modules / scenes in the project:

File / Scene	Responsibility
main.tscn / main.gd	Entry point; orchestrates UI and connections
Connection.tscn / connection.gd	Handles socket / network communications
TextProcessor.tscn / text_processor.gd	Parses inbound text (color codes, commands)
Input.tscn / input.gd	Input command line, user typing, history
Containers, mobs, map, status	UI modules for inventory, NPCs, world map, player status
fonts/	Font assets (e.g. primary text font, fallback)
export_presets.cfg	Preset settings for exporting (desktop, HTML5, etc.)

You can extend or replace each module to customize behavior, style, or protocol handling.

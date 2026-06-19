# KC Client

<p align="center">
  <img src="assets/player_portraits/by_race_class/human_warrior.png"   alt="Human Warrior"   width="68">
  <img src="assets/player_portraits/by_race_class/human_assassin.png"  alt="Human Assassin"  width="68">
  <img src="assets/player_portraits/by_race_class/elf_sorcerer.png"    alt="Elf Sorcerer"    width="68">
  <img src="assets/player_portraits/by_race_class/elf_ranger.png"      alt="Elf Ranger"      width="68">
  &nbsp;&nbsp;&nbsp;
  <img src="assets/mobs/by_name/rat.png"          alt="Rat"          width="68">
  <img src="assets/mobs/by_name/skeleton.png"     alt="Skeleton"     width="68">
  <img src="assets/mobs/by_name/lich.png"         alt="Lich"         width="68">
  <img src="assets/mobs/by_name/spider_queen.png" alt="Spider Queen" width="68">
</p>

<p align="center">
  A <strong>Godot 4.6</strong> desktop client for <a href="https://github.com/GoMudEngine/GoMud">GoMud</a> — Keg's Catacombs.<br>
  WebSocket · Full GMCP · RPG equipment UI · Live room map · Portrait art
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Godot-4.6-478CBF?logo=godotengine&logoColor=white" alt="Godot 4.6">
  <img src="https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-informational" alt="Platform">
  <img src="https://img.shields.io/badge/Protocol-WebSocket%20%2B%20GMCP-blueviolet" alt="Protocol">
  <img src="https://img.shields.io/badge/Language-GDScript-brightgreen" alt="GDScript">
</p>

---

## Features

| Feature | Description |
| --- | --- |
| **RPG Inventory & Equipment** | Click-to-equip backpack grid and worn equipment slots — each slot resolves to a local icon |
| **Live Room Map** | Tile-based map rendered from `Room.Info` GMCP with persistent session history |
| **Character Status Bar** | Compact HP / SP / XP / Gold strip updated in real-time from `Char.Vitals` |
| **Skills & Spells** | Browseable panels from `Char.Skills` / `Char.Jobs` and parsed spell tables |
| **Active Effects** | Popup from `Char.Affects` listing all current status effects |
| **Kill Statistics** | Statistics panel from `Char.Kills` |
| **Room Objects** | NPC / mob list per room with portrait images and quick-action buttons |
| **NPC Look** | Inspect NPCs with full description, health state, and worn equipment grid |
| **Item Context Menu** | Look · Inspect · Equip · Drink/Eat/Use · Drop — targeting by full GMCP item ID |
| **Player & Mob Portraits** | Per race/class player portraits; per-mob portraits; extend with a PNG drop |
| **GMCP Debug Log** | JSON Lines log of all inbound/outbound GMCP traffic |

---

## Item Icons

<p>
  <img src="assets/items/by_id/10001.png" alt="Club"           width="44">
  <img src="assets/items/by_id/10002.png" alt="Sword"          width="44">
  <img src="assets/items/by_id/10005.png" alt="Dagger"         width="44">
  <img src="assets/items/by_id/20004.png" alt="Shield"         width="44">
  <img src="assets/items/by_id/20001.png" alt="Leather Gloves" width="44">
  <img src="assets/items/by_id/20002.png" alt="Cloak"          width="44">
  <img src="assets/items/by_id/30001.png" alt="Red Potion"     width="44">
  <img src="assets/items/by_id/30002.png" alt="Yellow Potion"  width="44">
</p>

Drop a PNG at `assets/items/by_id/<item_id>.png` — no code changes needed.

### Portraits

<table>
<tr>
  <th>Players</th>
  <th>NPCs &amp; Mobs</th>
</tr>
<tr>
<td>
  <img src="assets/player_portraits/by_race_class/human_warrior.png"  alt="Human Warrior"  width="60">
  <img src="assets/player_portraits/by_race_class/human_assassin.png" alt="Human Assassin" width="60">
  <img src="assets/player_portraits/by_race_class/elf_sorcerer.png"   alt="Elf Sorcerer"   width="60">
  <img src="assets/player_portraits/by_race_class/elf_ranger.png"     alt="Elf Ranger"     width="60">
</td>
<td>
  <img src="assets/mobs/by_name/rat.png"          alt="Rat"          width="60">
  <img src="assets/mobs/by_name/skeleton.png"     alt="Skeleton"     width="60">
  <img src="assets/mobs/by_name/lich.png"         alt="Lich"         width="60">
  <img src="assets/mobs/by_name/spider_queen.png" alt="Spider Queen" width="60">
</td>
</tr>
</table>

---

## Quick Start

**Requirements:** Godot 4.6.1 or newer.

```
1.  Open this folder in Godot (Project → Import).
2.  Set main scene to  res://main.tscn  and press Run (F5).
3.  Click Connect in the status area, or just type a MUD command — the
    client connects and queues the command automatically.
```

### Connection Commands

| Command | Action |
| --- | --- |
| `/connect` | Connect to the default server |
| `/connect official` | Connect to the official GoMud server |
| `/connect catacombs` | Connect to Keg's Catacombs |
| `/connect wss://host/ws` | Connect to a custom server (raw WebSocket URL) |
| `/disconnect` | Close the active connection |

Website-style URLs are accepted — `https://gomud.net/` and `gomud.net` both normalise to `wss://gomud.net/ws`.

---

## UI Commands

After login, these commands render from cached GMCP state and trigger a server refresh:

| Command | GMCP Source | Panel |
| --- | --- | --- |
| `eq` · `equipment` | `Char.Inventory.Worn` | Equipment slots |
| `i` · `inv` · `inventory` | `Char.Inventory.Backpack` | Backpack grid |
| `status` · `score` | `Char` + `Char.Info` + `Char.Stats` | Score / attributes |
| `skills` · `jobs` | `Char.Skills` + `Char.Jobs` | Skills & job progress |
| `affects` · `effects` | `Char.Affects` | Active effects |
| `kills` · `killstats` | `Char.Kills` | Kill statistics |
| `spells` | Legacy text (GMCP fallback) | Spell browser |

Legacy ANSI text is the fallback for commands without a confirmed GMCP payload.

---

## Architecture

```
main.tscn / main.gd                 Root scene — signal wiring, gmcp_state cache
├── connection.gd                   WebSocket lifecycle, GMCP / SOUND / text parsing
├── text_processor.gd               ANSI → BBCode, MUD layout detection
│   scripts/text/ansi_parser.gd
│   scripts/text/mud_layout_detector.gd
├── scripts/ui/draggable_panel.gd   Shared draggable popup base (DraggablePanel)
│
├── map.tscn    / map.gd            Tile-based room map (Room.Info GMCP)
├── status.tscn / status.gd         Compact HP / SP / XP / Gold bar
├── mobs.tscn   / mobs.gd           Room objects / NPC card list
├── Input.tscn  / input.gd          Command text input
│
└── Containers.tscn / containers.gd Panel coordinator (ContainersController)
    ├── BackpackPanel               scripts/panels/backpack_panel.gd
    ├── EquipmentPanel              scripts/panels/equipment_panel.gd
    ├── NpcLookPanel                scripts/panels/npc_look_panel.gd
    ├── AttributesPanel             scripts/panels/attributes_panel.gd
    ├── SkillsPanel                 scripts/panels/skills_panel.gd
    └── SpellsPanel                 scripts/panels/spells_panel.gd
        scripts/panels/inventory_panel_base.gd  (shared slot / action logic)
```

### GMCP Topic Routing

| GMCP Topic | Panel(s) |
| --- | --- |
| `Room.Info` | Map + Mobs |
| `Char.Vitals` · `Char.Worth` | Status bar |
| `Char.Inventory.Backpack` | BackpackPanel |
| `Char.Inventory.Worn` | EquipmentPanel |
| `Char.Info` · `Char.Stats` | AttributesPanel |
| `Char.Skills` · `Char.Jobs` | SkillsPanel |
| `Char.Affects` | AttributesPanel |
| `Char.Kills` | AttributesPanel |

---

## Adding Assets

### Item Icons

Resolution order at runtime:

1. `assets/items/by_id/<item_id>.png`
2. `assets/items/default_item.png`

Empty equipment slots use `assets/items/empty_slot.png`.
No `.import` file yet? The client falls back to a direct disk PNG load automatically.

See [`developer_tools/docs/ITEM_ICONS.md`](developer_tools/docs/ITEM_ICONS.md) for full conventions.

### Mob Portraits

`assets/mobs/by_name/<normalized_name>.png` — spaces → underscores, all lowercase.
Falls back to `assets/mobs/default_mob.png` when no match is found.

### Player Portraits

`assets/player_portraits/by_race_class/<race>_<class>.png`
— e.g. `human_warrior.png`, `elf_sorcerer.png`.

---

## Developer Tools

**Generate placeholder item icons** for all GoMud default-world items:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\developer_tools\tools\generate_item_icons.ps1
```

**Generate AI image-generation prompts** for item PNGs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\developer_tools\tools\generate_item_icon_prompts.ps1
```

**Headless smoke check** — loads `main.tscn`, verifies key nodes and signal contracts, confirms no auto-connect to production on startup:

```powershell
& 'C:\Godot\Godot_v4.6.1-stable_win64_console.exe' --path . --headless --script res://tools/smoke_check.gd
```

---

## GMCP Debug Log

Enabled by default in `connection.gd`.

| | |
| --- | --- |
| **Primary path** | `developer_tools/logs/gmcp_debug.log` |
| **Fallback path** | `user://gmcp_debug.log` |
| **Format** | JSON Lines — GMCP inbound/outbound + connection open/close events |
| **Mode** | Append-only — new sessions do not overwrite existing entries |
| **Privacy** | Login text and submitted commands are never written; passwords are safe |

---

## WebSocket Protocol Notes

- WebSocket clients connect to `/ws`; GoMud treats them as `WebClient` (GMCP-enabled).
- **Server → client** GMCP is text-wrapped: `!!GMCP(<namespace> <json>)`
- **Client → server** GMCP uses the same wrapper: `!!GMCP(Room.Info)` or `!!GMCP(Help train)`
- Do **not** send GMCP requests immediately on socket open — GoMud installs the WebSocket GMCP handler **after login**. Sending `!!GMCP(...)` during the login sequence will be treated as prompt input.
- Raw telnet GMCP uses IAC/SB option `201`; this client follows the WebSocket text protocol only.

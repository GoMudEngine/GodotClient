<h1 align="center">🕹️ GoMudEngine / GodotClient</h1>
<p align="center"><b>A Godot-based MUD Client for the GoMud Server</b></p>

<p align="center">
A lightweight, extensible, and fully Unicode-compatible client built with <b>Godot 4.x</b>, 
designed for connecting to and interacting with <b>GoMud</b> (and other compatible MUD servers).
</p>

<hr>

<h2>✨ Overview</h2>
<p>
<b>GoMudEngine / GodotClient</b> provides a flexible and modular interface for real-time text-based worlds. 
It’s written entirely in <b>GDScript</b>, with clean scene separation and built-in support for color-coded text, 
UI modularity, and cross-platform exports (including HTML5).
</p>

<hr>

<h2>📦 Features</h2>
<ul>
  <li>⚡ <b>Real-time text interaction</b> with MUD servers</li>
  <li>💬 <b>Command input and output parsing</b> with BBCode color rendering</li>
  <li>🧩 <b>Modular scene structure</b> — easy to extend or replace (input, map, mobs, containers, etc.)</li>
  <li>🌍 <b>UTF-8 / Unicode support</b> for multilingual text and symbols</li>
  <li>🪶 <b>Lightweight & fast</b> — pure GDScript, no external dependencies</li>
  <li>🌐 <b>Cross-platform ready</b> — works on desktop and web (HTML5 export supported)</li>
</ul>

<hr>

<h2>🚀 Getting Started</h2>

<h3>🔧 Prerequisites</h3>
<ul>
  <li><a href="https://godotengine.org/download"><b>Godot Engine</b></a> v4.0 or later</li>
  <li>Basic understanding of <b>Godot scenes</b>, <b>signals</b>, and <b>resources</b></li>
</ul>

<h3>📥 Installation</h3>
<pre><code>git clone https://github.com/GoMudEngine/GodotClient.git
cd GodotClient
</code></pre>

<ol>
  <li><b>Open the project</b> in Godot → <code>project.godot</code></li>
  <li><b>Run the main scene</b> → <code>main.tscn</code> (entry point)</li>
  <li><b>Configure your connection</b> → edit <code>connection.gd</code> (host, port, protocol) or use the in-game UI</li>
</ol>

<hr>

<h2>🛠️ Project Structure</h2>

<table>
<thead>
<tr><th>File / Scene</th><th>Description</th></tr>
</thead>
<tbody>
<tr><td><code>main.tscn</code> / <code>main.gd</code></td><td>Entry point — orchestrates UI and manages the client lifecycle</td></tr>
<tr><td><code>Connection.tscn</code> / <code>connection.gd</code></td><td>Handles WebSocket / socket communication</td></tr>
<tr><td><code>TextProcessor.tscn</code> / <code>text_processor.gd</code></td><td>Parses incoming text, applies colors and formatting</td></tr>
<tr><td><code>Input.tscn</code> / <code>input.gd</code></td><td>Command line input, history navigation</td></tr>
<tr><td><code>Containers</code>, <code>Mobs</code>, <code>Map</code>, <code>Status</code></td><td>Modules for inventory, NPCs, world map, player stats</td></tr>
<tr><td><code>fonts/</code></td><td>Contains main and fallback fonts (e.g., Noto Sans + Unifont)</td></tr>
<tr><td><code>export_presets.cfg</code></td><td>Export settings for desktop and HTML5 builds</td></tr>
</tbody>
</table>

<p><i>🧠 Each module is independent — you can easily extend, replace, or restyle any system without breaking the others.</i></p>

<hr>

<h2>⚙️ Customization</h2>
<ul>
  <li>🎨 <b>Themes & Fonts</b> – Use your own color palette or UI skin in the Theme resource</li>
  <li>🧮 <b>Protocol adapters</b> – Extend the <code>Connection</code> class for custom Telnet / WebSocket protocols</li>
  <li>⚔️ <b>Macros & Aliases</b> – Add local command automation or key bindings</li>
  <li>📜 <b>Logging / Transcript</b> – Implement chat logging for debugging or story replay</li>
  <li>🔔 <b>Audio / Visual Feedback</b> – Integrate sound cues or animations for events</li>
</ul>

<hr>

<h2>🧾 Example Session</h2>

<pre><code>&gt; connect mud.example.com 4000
[Connected successfully!]

&lt; The MUD server says: “Welcome, adventurer.” &gt;
&gt; look
You are in a small forest glade. Paths lead north and east.
&gt; go north
</code></pre>

<p>Text input is handled by <code>Input.gd</code>, output is processed via <code>TextProcessor.gd</code>, and displayed in a <code>RichTextLabel</code> with BBCode formatting.</p>

<hr>

<h2>🧰 Tech Stack</h2>
<ul>
  <li><b>Engine:</b> Godot 4.x</li>
  <li><b>Language:</b> GDScript</li>
  <li><b>Networking:</b> WebSocket / TCP Socket (customizable)</li>
  <li><b>License:</b> MIT / GPL / Apache — choose your preferred license</li>
</ul>

<hr>

<h2>🤝 Contributing</h2>
<p>Contributions, suggestions, and pull requests are welcome!  
If you’d like to collaborate, please follow these steps:</p>

<ol>
  <li>Fork the repository</li>
  <li>Create a feature branch</li>
  <li>Submit a pull request with a clear description</li>
</ol>

<p><i>💡 For major changes, please open an issue first to discuss what you’d like to improve.</i></p>

<hr>

<h2>📬 Contact</h2>
<ul>
  <li><b>GitHub:</b> <a href="https://github.com/GoMudEngine">GoMudEngine</a></li>
  <li><b>Project Maintainer:</b> (add your name or contact)</li>
</ul>

<hr>

<h2>🧙‍♂️ Quote</h2>
<blockquote><i>"In text, the world becomes infinite."</i> — <b>GoMudEngine Philosophy</b></blockquote>

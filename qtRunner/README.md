<div align="center">
    <img src="https://img.icons8.com/color/160/portal.png" width="120" height="120" alt="qtRunner Logo"/>
</div>

<h1 align="center">qtRunner</h1>

<p align="center">
    <em>The lightning-fast warp lookup and teleportation runner for World of Warcraft 3.3.5a</em>
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-usage">Usage</a> •
  <a href="#-settings">Settings</a> •
  <a href="#-project-structure">Structure</a>
</p>

---

## ✨ Features

- 🔍 **Instant Search**: Filter learned destinations as you type (Name or Alias)
- ⚡ **Direct Teleport**: Jump straight to the selected zone
- 🖼️ **Icon Preview**: See the destination spell icon before you commit
- ⭐ **Default Zones**: Set a favorite destination to be highlighted on open
- ✏️ **Alias Editor**: Manage shorthand names in-game (no Lua editing needed)
- ⌨️ **Submit Keys**: Customizable behavior for `Enter` and `` ` ``
- 🎨 **Themes**: Switch between **Dark** and **Light** modes
- 🎮 **Quick Access**: Keybind support and slash commands

---

## 📦 Installation

1. Download or clone this repository.
2. Place the `qtRunner` folder into your WoW addons directory:
   ```text
   Synastria/Interface/AddOns/qtRunner/
   ```
3. Ensure the following files are present inside the folder:
   - `qtRunner.toc`
   - `qtRunner.lua`
   - `qtRunnerData.lua`
   - `qtRunnerConfig.lua`
   - `qtRunnerOptions.lua`
   - `Bindings.xml`
4. Enable **qtRunner** on the character selection screen.

---

## 🕹️ Usage

### Open the runner
- Press `` ` `` (default keybind)
- Or type `/qtr`

### Basic flow
1. **Search**: Start typing a zone name or alias.
2. **Select**: Use the list to find your target.
3. **Teleport**: Press `Enter` or `` ` `` to warp (per your settings).
4. **Close**: Press `Escape` to hide the window.

💡 **Pro Tip**: Double-clicking a row teleports you immediately.

---

## 💬 Slash Commands

| Command | Action |
|:---|:---|
| `/qtr` | Toggle the runner window |
| `/qtr show` | Force show the window |
| `/qtr hide` | Force hide the window |
| `/qtr config` | Open the Control Center (Themes, Aliases, Keys) |
| `/qtr panel` | Open Blizzard Interface Options |

---

## ⚙️ Settings

Use `/qtr config` to customize your experience:
- **Default Destination**: Choose which zone highlights first.
- **Key Behavior**: Toggle submit on `Enter` or the hotkey.
- **Visuals**: Toggle between Light and Dark themes.
- **Alias Management**: Add, edit, or delete your custom shorthand.
- **Factory Reset**: Wipe settings back to default.

---

## 🧭 Default Aliases

Shorthand names included out of the box:
- `dal` → **Dalaran**
- `shat` → **Shattrath City**
- `org` → **Orgrimmar**
- `sw` → **Stormwind City**
- `zg` → **Stranglethorn Vale**

---

## 📁 Project Structure

```text
qtRunner/
├── qtRunner.toc         # Addon Manifest
├── qtRunner.lua         # Core Logic & UI
├── qtRunnerData.lua     # Warp Database
├── qtRunnerConfig.lua   # Settings & Control Center
├── qtRunnerOptions.lua  # Blizzard Interface Panel
└── Bindings.xml         # Keybind Registration
```

---

<div align="center">
    <sub>Built for efficiency. Part of the <b>Synastria</b> addon suite.</sub><br>
    <a href="LICENSE">MIT License</a>
</div>
```
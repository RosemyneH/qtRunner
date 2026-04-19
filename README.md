<div align="center">
    <img src="https://i.imgur.com/0cOfkms.jpeg" width="1280" alt="qtRunner Banner"/>
</div>

<h1 align="center">qtRunner</h1>

<p align="center">
    <em>The lightning-fast warp lookup and teleportation runner for World of Warcraft 3.3.5a</em>
</p>

<p align="center">
    <a href="https://www.lua.org/">
        <img src="https://img.shields.io/badge/Lua-5.1-2C2D72?style=for-the-badge&logo=lua" alt="Lua 5.1"/>
    </a>
    <a href="#">
        <img src="https://img.shields.io/badge/WoW-3.3.5a-C79C6E?style=for-the-badge" alt="WoW 3.3.5a"/>
    </a>
    <a href="LICENSE">
        <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License"/>
    </a>
</p>

---

## 📋 Table of Contents
- [✨ Features](#-features)
- [📸 Preview](#-preview)
- [📦 Installation](#-installation)
- [💬 Slash Commands](#-slash-commands)
- [⚙️ Settings](#️-settings)
- [🧭 Default Aliases](#-default-aliases)
- [📁 Project Structure](#-project-structure)

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

## 📸 Preview

<div align="center">
    <table>
        <tr>
            <td rowspan="2" valign="center">
                <img src="https://github.com/user-attachments/assets/00737a0b-9ee9-4190-8076-c7bdae90b465" width="300" alt="Main UI"/>
            </td>
            <td>
                <img src="https://github.com/user-attachments/assets/09784564-1e9a-461c-91c7-2a819d236c9e" width="500" alt="Config UI 1"/>
            </td>
        </tr>
        <tr>
            <td>
                <img src="https://github.com/user-attachments/assets/d975cfc6-3f92-4af7-bf23-34363e49aa41" width="500" alt="Config UI 2"/>
            </td>
        </tr>
    </table>
    <p><em>Modern search interface and deep customization panels.</em></p>
</div>

---

## 📦 Installation

1. Download or clone this repository.
2. Place the `qtRunner` folder into your WoW addons directory:
   ```text
   Synastria/Interface/AddOns/qtRunner/
   ```
3. Ensure the following files are present inside the folder:
   - `qtRunner.toc`, `qtRunner.lua`, `qtRunnerData.lua`, `qtRunnerConfig.lua`, `qtRunnerOptions.lua`, `Bindings.xml`
4. Enable **qtRunner** on the character selection screen.

---

## 🕹️ Usage

### Open the runner
- Press `` ` `` (default keybind) or type `/qtr`

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

---

## 🧭 Default Aliases

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

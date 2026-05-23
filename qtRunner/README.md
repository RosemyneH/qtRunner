# qtRunner



## The lightning-fast warp lookup and teleportation runner for World of Warcraft 3.3.5a



#### Lua 5.1 | WoW 3.3.5a | MIT License



\------------------------------------------------------------



## Table of Contents



##### \- Features

##### \- Preview

##### \- Installation

##### \- Usage

##### \- Slash Commands

##### \- Settings

##### \- Default Aliases

##### \- Project Structure

##### \- License



\------------------------------------------------------------



#### Features



|**Feature**|**Description**|
|-|-|
|**Instant Search**|**Filter learned destinations as you type**|
|**Direct Teleport**|**Jump straight to the selected zone**|
|**Icon Preview**|**See the destination spell icon before**|
|**Default Zones**|**Set a favorite to highlight on open**|
|**Alias Editor**|**Manage shorthand names in-game**|
|**Submit Keys**|**Customizable behavior for Enter and `**|
|**Themes**|**Switch between Dark and Light modes**|
|**Quick Access**|**Keybind support and slash commands**|



\------------------------------------------------------------



### Preview



Main UI:

https://github.com/user-attachments/assets/00737a0b-9ee9-4190-8076-c7bdae90b465



Config UI 1:

https://github.com/user-attachments/assets/09784564-1e9a-461c-91c7-2a819d236c9e



Config UI 2:

https://github.com/user-attachments/assets/d975cfc6-3f92-4af7-bf23-34363e49aa41



Modern search interface and deep customization panels.



\------------------------------------------------------------



### Installation



1\. Download or clone this repository.



2\. Place the qtRunner folder into your WoW addons directory:



&#x20;  Synastria/Interface/AddOns/qtRunner/



3\. Ensure the following files are present inside the folder:



&#x20;  - qtRunner.toc

&#x20;  - qtRunner.lua

&#x20;  - qtRunnerData.lua

&#x20;  - qtRunnerConfig.lua

&#x20;  - qtRunnerOptions.lua

&#x20;  - Bindings.xml



4\. Enable qtRunner on the character selection screen.



\------------------------------------------------------------



\## Usage



\### Open the runner



Press the backtick key (`) by default, or type:



&#x20;  /qtr



\### Basic flow



1\. Search:

&#x20;  Start typing a zone name or alias.



2\. Select:

&#x20;  Use the list to find your target.



3\. Teleport:

&#x20;  Press Enter or the backtick key (`) to warp, depending on your settings.



4\. Close:

&#x20;  Press Escape to hide the window.



Pro Tip:

Double-clicking a row teleports you immediately.



\------------------------------------------------------------



## Slash Commands



|Command|Action|
|-|-|
|/qtr|Toggle the runner window|
|/qtr show|Force show the window|
|/qtr config|Open the Control Center|
|/qtr panel|Open Blizzard Interface Options|



\------------------------------------------------------------



Settings



Use the following command to customize your experience:



* &#x20;  /qtr config


Available settings:



\- Default Destination:

&#x20; Choose which zone highlights first.



\- Key Behavior:

&#x20; Toggle submit on Enter or the hotkey.



\- Visuals:

&#x20; Toggle between Light and Dark themes.



\- Alias Management:

&#x20; Add, edit, or delete your custom shorthand.



\------------------------------------------------------------



\## Default Aliases



|Alias|Destination|
|-|-|
|dal|Dalaran|
|shat|Shattrath City|
|org|Orgrimmar|
|sw|Stormwind City|
|zg|Stranglethorn Vale|



\------------------------------------------------------------



\## Project Structure



qtRunner/

|-- qtRunner.toc         # Addon Manifest

|-- qtRunner.lua         # Core Logic and UI

|-- qtRunnerData.lua     # Warp Database

|-- qtRunnerConfig.lua   # Settings and Control Center

|-- qtRunnerOptions.lua  # Blizzard Interface Panel

`-- Bindings.xml         # Keybind Registration



\------------------------------------------------------------



\## License



MIT License



See LICENSE for details.



\------------------------------------------------------------



Built for efficiency.

Part of the Synastria addon suite.


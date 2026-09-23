<div align="center">

<img src="Assets/assetIcon.png" alt="Keypath Icon" width="128"/>

</div>

<h1 align="center">Keypath</h1>

<div align="center">


A personal macOS app that allows for easy navigation across your apps via keybinds.

</div>

<div align="center">

<img src="Assets/appPreview.png" alt="Keypath Icon"/>

</div>

### About The Project

Keypath is a menu bar utility for switching between running Mac apps from the keyboard. macOS handles moving focus to an app on another Space; Keypath does not move windows between Spaces.

### Commands

#### Hyper Key

The Hyper Key is a quick double tap of the **left Option** key. It is represented by a superellipse:

`⌃⌃`

#### Open or close the app HUD

` ⌃⌃ K `

#### Recent apps

` ⌃⌃ Tab ` opens the recent-app picker. `Tab` moves forward, `Shift-Tab` moves backward, `Return` switches to the selected app, and `Escape` closes the picker.

#### Other commands

| Shortcut | Action |
| --- | --- |
| `⌃⌃ C` | Show or hide the command reference while the HUD is open |
| `⌃⌃ /` | Show or hide saved app keybinds |
| `⌃⌃ S` | Toggle selection mode; use left and right arrows to move |
| `⌃⌃ U` | Assign a keybind to the selected app; press a supported letter or number |
| `Escape` | Cancel keybind entry or close the app HUD |

When assigning a key that belongs to another app, Keypath asks before moving it. After a successful assignment or reset, an Undo action is available in the HUD for 30 seconds. Press `Tab` to focus Undo, then `Return` or `Enter` to restore the previous bindings.

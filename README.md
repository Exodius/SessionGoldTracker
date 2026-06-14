# SessionGoldTracker

A lightweight World of Warcraft addon that tracks your gold activity in real time during each play session.

![WoW Version](https://img.shields.io/badge/WoW-12.0.5-blue) ![Version](https://img.shields.io/badge/Version-1.0-green)

---

## Installation

1. Download or clone this repository
2. Place the `SessionGoldTracker` folder into your addons directory:
   ```
   World of Warcraft/_retail_/Interface/AddOns/SessionGoldTracker/
   ```
3. Launch WoW and enable **SessionGoldTracker** in the AddOns menu on the character select screen

---

## Features

### Main Window
The core display shows six lines of live data:

| Line | Description |
|------|-------------|
| **Session Time** | How long you've been playing since login or last reset |
| **Started At** | How much gold you had when the session began |
| **Current** | Your live gold total, updates instantly |
| **Earned** | Total gold received this session (looting, quests, AH sales, etc.) |
| **Spent** | Total gold paid out this session (repairs, AH fees, purchases, etc.) |
| **Net** | Difference between Earned and Spent. Total gold earned or spent during the session. |

---

### Extra Data Panel
**Extra Data** panel shows some deeper session stats:

- 📈 **Gold/hr rate** — your earning rate extrapolated to an hourly figure
- 💰 **Biggest single gain** — The largest single gold increase during the session
- 💸 **Biggest single loss** — the largest single gold decrease during the session

---

### Session History
Persists across logouts via `SavedVariables` and stores up to **20 past sessions**, each showing:

- 📅 Date and time the session started
- ⏱️ How long the session lasted
- 🪙 Net gold earned or lost

> Sessions are saved automatically on logout and when you hit Reset. Sessions shorter than 10 seconds are ignored to avoid junk entries from quick reloads. A **Clear All** button is available to wipe the log.

---

### Mini-Mode
Click the **M** button in the top-right corner of the main window to collapse everything into a single compact bar showing just the Net. Click it again to return to full view.

---

## Slash Commands

| Command | Description |
|---------|-------------|
| `/sgt` | Print current session net to chat |
| `/sgt reset` | Save the current session to history and start fresh |
| `/sgt show` | Show the tracker window |
| `/sgt hide` | Hide the tracker window |
| `/sgt mini` | Switch to mini-mode |

---

## Compatibility

- **Retail WoW** — Interface version 12.0.5
- If you are on a different patch, update the `## Interface` version in `SessionGoldTracker.toc` to match. You can find the correct value on the [Wowpedia Interface version list](https://wowpedia.fandom.com/wiki/Interface_version), or simply enable **Load out of date AddOns** in the character select AddOns menu.

---

## License

This project is licensed under the [MIT License](LICENSE). Free to use, modify, fork, and distribute. No warranty or liability is provided by the original author.

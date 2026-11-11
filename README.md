# deoxizn.clock — Clock with Today's Events on Hover

A shell bar clock for Omarchy that replaces the stock `omarchy.clock` widget. Hovering it shows today's agenda instead of a version stamp. Clicking it opens the month grid with a day agenda, countdown badge, and multi-calendar sync.

![Clock with Countdown Badge](assets/screenshot.png)

## What it does

| Feature | Description |
| :--- | :--- |
| **Today's-events tooltip** | Hovering the clock shows today's date, each timed event with its start time, and a count of all-day events. No events means "No events today". |
| **Countdown badge** | Events starting within 60 minutes show beside the clock (`HH:mm • Team Sync in 12m` or `Team Sync now`). Configurable via `badgeMinutes`. |
| **In-place replacement** | Uses Omarchy's `clonedFrom` routing, so stock date/time formats and cycle rings carry over automatically. |
| **Multi-calendar sync** | Fetches read-only schedules from Google Calendar or any iCalendar (`.ics`) secret URLs and local files. No OAuth, no tokens, no daemons. |
| **Interactive agenda** | Clicking the clock opens a month grid; selecting a day shows its agenda cards with times, accounts, and meeting links. |
| **Event dots on grid** | Up to 4 colored indicator dots on days with scheduled events, matching calendar feed colors. |
| **Account filter chips** | Filter the agenda by account (`All`, `Personal`, `Work`, etc.). |
| **1-click meeting join** | Detects Google Meet, Zoom, Teams, and Webex links and renders Join buttons. |
| **Markdown copy** | Copy the selected day's agenda as structured Markdown (`y` hotkey or toolbar button). |
| **Local events** | Create and delete private local events from the UI or CLI. Stored as standard RFC 5545 `.ics` at `~/.config/deoxizn.clock/local.ics`. |

## Installation

If you are still running the upstream `fred.clock`, remove it first:

```bash
omarchy plugin remove fred.clock
```

Then install the fork:

```bash
omarchy plugin add https://github.com/Deoxizn/omarchy-clock.git --enable --yes
```

### Bar center anchor

Omarchy does not rewrite the bar center anchor when a clone is enabled, so point it at the new widget in `~/.config/omarchy/shell.json`:

```bash
sed -i 's/"centerAnchor": "fred.clock"/"centerAnchor": "deoxizn.clock"/' ~/.config/omarchy/shell.json
```

(If you are coming from the stock clock instead, replace `omarchy.clock` in that command.) Restart the shell after installing.

## Configuration

Calendar feeds live in `~/.config/deoxizn.clock/calendars.json` (permissions `0600`).

**You do not have to create this file.** On first run the fetcher seeds it for you: if a legacy `~/.config/fred.clock/calendars.json` exists it is copied over with your feeds intact, otherwise the bundled `calendars.example.json` sample is copied in. Edit the URLs in place and save; the widget watches the file and refetches immediately.

```json
[
  {
    "account": "Personal",
    "name": "Personal Calendar",
    "url": "https://calendar.google.com/calendar/ical/your-id%40gmail.com/private-xxxx/basic.ics",
    "color": "#4285f4",
    "enabled": true
  },
  {
    "account": "Family",
    "name": "Family Calendar",
    "url": "https://calendar.google.com/calendar/ical/your-group%40group.calendar.google.com/private-yyyy/basic.ics",
    "color": "#34a853",
    "enabled": true
  },
  {
    "account": "Local",
    "name": "Local Events",
    "path": "~/Documents/calendar.ics",
    "color": "#fbbc05",
    "enabled": false
  }
]
```

### Finding your Google Calendar secret URL

1. In Google Calendar, click the gear icon in the upper right.
2. Under **Settings for my calendars**, click the calendar you want to sync.
3. Scroll down to **Integrate calendar**.
4. Copy the **Secret address in iCal format** URL (*not* the public address).
5. Paste it into the `"url"` field of your `calendars.json`.

Public `.ics` URLs work too, but only for calendars that are actually public. A private calendar's public address returns nothing; that is what the secret address is for. Never commit a file containing a secret URL. The repo ships a redacted `calendars.example.json` for that reason, and `calendars.json` itself is gitignored.

### Feed properties

| Property | Type | Description |
| :--- | :--- | :--- |
| `account` | string | Category label shown on event cards and used for agenda filter chips (e.g. `Personal`, `Work`). |
| `name` | string | Descriptive calendar name (e.g. `Primary`, `Family`). |
| `url` | string | Secret `.ics` HTTP/HTTPS subscription URL. |
| `path` | string | Absolute or home-relative path to a local `.ics` file (alternative to `url`). |
| `color` | string | Hex color code (e.g. `"#4285f4"`) for grid dots and event card strips. |
| `enabled` | boolean | Set to `false` to temporarily skip fetching this feed without removing it. |

### Automatic synchronization

Events are pulled and cached automatically in the background. No terminal commands or daemon setups are required:

- **Instant on save**: The bar widget watches `~/.config/deoxizn.clock/calendars.json`. Saving changes triggers an immediate background fetch.
- **Periodic background sync**: All enabled feeds refresh every 15 minutes.
- **On panel open**: Opening the calendar panel refreshes events if the cache is older than 5 minutes.
- **Shell startup**: Fetches automatically whenever the desktop session initializes.
- **Manual (optional)**: Force a refresh from the terminal:

```bash
python3 ~/.config/omarchy/plugins/deoxizn.clock/fetch-events.py
```

## Managing local events

Create and manage private local calendar events without external Google Calendar dependencies. Events are stored in standard RFC 5545 format at `~/.config/deoxizn.clock/local.ics` (permissions `0600`) and automatically registered under the `"Local"` account. A legacy `~/.config/fred.clock/local.ics` is migrated on first run.

### From the user interface

- Click the **`+`** button in the agenda header or press **`n`** / **`a`** while the panel is open.
- Enter the event title, choose all-day or specify start/end times (e.g. `14:00` – `15:30`), optionally enter a location, and click **Save Event** (or press Enter).
- To delete a local event, click the trash can icon on any local event card.

### From the command line / IPC

```bash
# Add an all-day local event
python3 ~/.config/omarchy/plugins/deoxizn.clock/manage-event.py add --date 2026-11-15 --summary "Doctor's Appointment" --all-day

# Add a timed local event with location
python3 ~/.config/omarchy/plugins/deoxizn.clock/manage-event.py add --date 2026-11-15 --start-time 14:00 --end-time 15:30 --summary "Design Review" --location "Office 3B"

# Delete a local event by UID
python3 ~/.config/omarchy/plugins/deoxizn.clock/manage-event.py delete --uid "<event-uid>"

# Or trigger creation directly via Omarchy Shell IPC:
omarchy-shell deoxizn.clock createEvent "Sprint Planning" "2026-11-15" "false" "10:00" "11:00" "Conference Room"
```

## Bar settings

Inline widget settings in `~/.config/omarchy/shell.json`:

- `format`: Clock date/time format string (default: `"ddd MMM d HH:mm"`).
- `formatAlt`: Alternative date/time format string (default: `"d MMMM 'W'ww yyyy"`).
- `verticalFormat`: Format string when the bar is vertical (default: `"HH\n—\nmm"`).
- `badgeMinutes`: Maximum minutes ahead to show upcoming event countdown badges (default: `60`, set to `0` to disable).

## Interactions and shortcuts

### Bar

- **Left click**: Open / close the calendar and agenda panel.
- **Right click**: Cycle through configured date and time formats.
- **Middle click**: Open the Omarchy timezone switcher (`omarchy-menu-timezone`).

### Agenda panel

- **Click day cell**: Select that date and display its agenda.
- **`n` / `N` / `a` / `A`** (or `+` button): Open the inline "New Local Event" creator.
- **Trash button**: Delete a local event from its agenda card.
- **`y` / `Y`** (or copy button): Copy the selected day's agenda as Markdown to clipboard.
- **`t` / `T`** (or hero date click): Return to today.
- **`[` / `]`**: Previous / next month.
- **`{` / `}`**: Previous / next year.
- **`w` / `W`** (or "W" heading click): Toggle week start day (Sunday vs. Monday).
- **Escape**: Close the inline add event form (if open) or close the panel.

## Security model

`deoxizn.clock` runs inside the Quickshell desktop shell environment. All process executions, network interactions, and filesystem writes adhere to a strict least-privilege security model designed to resist malicious feeds, unbounded resource consumption, and ambient environment leakage.

### Supervised process execution

Nothing in the plugin invokes ambient shells (`bash`), unconstrained execution (`execDetached`), or nested child processes. Every process is spawned through a dedicated `Launch.qml` supervisor with an absolute executable path, a closed environment constructed from a minimal allowlist (`clearEnvironment: true`), and an automated watchdog timer that sends `SIGTERM` followed by `SIGKILL`:

| Process | Trigger | Executable | Environment allowlist | Deadline / watchdog |
| :--- | :--- | :--- | :--- | :--- |
| **Event fetcher** | Session start, 15m timer, panel open if stale (>5m), config change | `/usr/bin/python3` (`fetch-events.py`) | `HOME`, `TZ`, `LANG`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME` | 60s QML watchdog (SIGTERM + SIGKILL after 3s); 45s self-imposed `signal.alarm` |
| **Event manager** | Add / delete local event in UI or IPC | `/usr/bin/python3` (`manage-event.py`) | `HOME`, `TZ`, `LANG`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME` | 20s QML watchdog |
| **Meeting URL opener** | Click "Join Meeting" button in agenda | `/usr/bin/xdg-open` | `HOME`, `LANG`, `XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY`, `DISPLAY`, `DBUS_SESSION_BUS_ADDRESS`, `XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE`, `XDG_DATA_HOME`, `XDG_DATA_DIRS`, `XDG_CONFIG_HOME`, `XDG_CONFIG_DIRS`, `HYPRLAND_INSTANCE_SIGNATURE` | 10s QML watchdog |
| **Clipboard copy** | Press `y` or click agenda copy button | `/usr/bin/wl-copy` | `XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY` | 10s QML watchdog (text piped directly to stdin) |
| **Desktop notifications** | Event added/deleted, agenda copied, or calendar busy | `$OMARCHY_PATH/bin/omarchy-notification-send` | `HOME`, `XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY`, `DBUS_SESSION_BUS_ADDRESS`, `OMARCHY_PATH` | 10s QML watchdog (skipped if `OMARCHY_PATH` is unset) |

#### Component-relative helper resolution

Like all Omarchy shell plugins, the plugin installation directory is user-writable by design. Helper scripts (`fetch-events.py`, `manage-event.py`) are never resolved by guessing hard-coded paths; instead, they are dynamically resolved as sibling paths of the loaded QML component via `Model.helperPath(Qt.resolvedUrl(...))`.

### Resource bounds and aggregation limits

To prevent memory exhaustion, slow-drip HTTP attacks, or calendar recurrence bombs, `fetch-events.py` operates under strict resource limits and self-supervision:

| Constant | Value | Rationale |
| :--- | :--- | :--- |
| `MAX_CONFIG_BYTES` | 64 KiB | dozens of feeds is already generous |
| `MAX_FEEDS` | 32 | thread pool is 8; 32 keeps a run under the deadline |
| `MAX_FEED_BYTES` | 8 MiB | a busy multi-year Google calendar is 1–3 MiB |
| `FEED_DEADLINE_S` | 20 s | socket timeout stays 10 s; this bounds slow-drip bodies |
| `MAX_LINE_BYTES` | 64 KiB | RFC 5545 folds at 75 octets; 64 KiB tolerates sloppy exporters |
| `MAX_LINES` | 200 000 | ~8 MiB at typical line lengths |
| `MAX_VEVENTS_PER_FEED` | 20 000 | |
| `MAX_EXDATES` | 2 000 per event | |
| `MAX_INSTANCES_PER_EVENT` | 1 000 iterations | window is 31 days; daily = 31, hourly is not supported |
| `INTERVAL` / `COUNT` clamp | `[1, 366]` / `[1, 10 000]` | |
| `MAX_SUMMARY` / `MAX_LOCATION` / `MAX_DESCRIPTION` | 512 / 2 048 / 4 096 chars | description feeds only the agenda tooltip and meeting-URL regex |
| `MAX_EVENTS_TOTAL` | 5 000 | agenda shows one day at a time |
| `MAX_OUTPUT_BYTES` | 4 MiB | `FileView` loads it into the shell's heap on every change |
| `DEADLINE_S` (`signal.alarm`) | 45 s | inside the QML 60 s watchdog |
| `RLIMIT_CPU` / `RLIMIT_AS` / `RLIMIT_FSIZE` / `RLIMIT_NOFILE` | 30 s / 512 MiB / 16 MiB / 64 | |
| QML deadlines | fetch 60 s, manage 20 s, others 10 s | TERM, then KILL after 3 s |

### Cache directory contract and atomic writes

All cache and configuration file writes go through `write_private_file`:

- **Directory validation**: The target directory (`~/.cache/deoxizn.clock` or `~/.config/deoxizn.clock`) must be a private, self-owned directory (`st_uid == getuid()`, mode `0700`, no group/other write permissions). Parent directories must not be group/other-writable unless the sticky bit is set.
- **Atomic replacement**: Content is written to a temporary file in the same directory (`O_EXCL`, `O_NOFOLLOW`), `fsync`ed, and then renamed over the destination so readers never observe a torn write.
- **Permission enforcement**: All files are created with mode `0600`.

## Uninstall

To remove `deoxizn.clock` and restore the default stock clock:

```bash
sed -i 's/"centerAnchor": "deoxizn.clock"/"centerAnchor": "omarchy.clock"/' ~/.config/omarchy/shell.json
omarchy plugin remove deoxizn.clock
```

Your feeds stay in `~/.config/deoxizn.clock/calendars.json` if you ever reinstall.

## License

GPL-3.0-or-later. See `LICENSE`. Upstream provenance and the Omarchy clone ancestry are recorded in `UPSTREAM.md`.

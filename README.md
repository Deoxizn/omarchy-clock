# pizza.dirty.clock — Clock

A bar clock that shows today's events on hover and opens a month calendar when you click it.

![Clock with Countdown Badge](assets/screenshot.png)

## Install

```bash
omarchy plugin add https://github.com/Deoxizn/omarchy-clock.git --enable --yes
```

Point the bar center at it in `~/.config/omarchy/shell.json`:

```bash
sed -i 's/"centerAnchor": "omarchy.clock"/"centerAnchor": "pizza.dirty.clock"/' ~/.config/omarchy/shell.json
```

Then restart the shell.

## Use it

- **Hover:** today's events and times.
- **Click:** month grid. Click a day to see its events. Click a Join button to jump into a meeting.
- **Right-click:** settings. Add calendars there, no file editing needed.
- **Middle-click:** timezone picker.

A badge next to the clock counts down to your next event (within 60 minutes).

### Calendars

Right-click the clock, then paste an iCal link (`https://` or `webcal://`) or a local `.ics` file path.

For Google Calendar: Settings (gear icon) > pick a calendar > Integrate calendar > copy the **Secret address in iCal format** link.

### Local events

Click the **+** button in the agenda, or press **n** while the panel is open. Fill in the title and times, hit Save. Click the trash icon on an event to delete it.

Other keys while the panel is open: **y** copies the day's agenda, **t** jumps back to today, **[** / **]** change month, **Esc** closes.

## Settings

In `~/.config/omarchy/shell.json`:

- `format`: how the clock looks (default `"dddd HH:mm"`).
- `formatAlt`: the second format (default `"d MMMM 'W'ww yyyy"`).
- `verticalFormat`: how it looks on a vertical bar (default `"HH\n—\nmm"`).
- `badgeMinutes`: how far ahead the countdown badge looks, in minutes (default `60`, `0` turns it off).

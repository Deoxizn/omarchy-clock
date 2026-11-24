#!/usr/bin/env python3
"""Tests for the clock's standalone settings popup (ClockSettings.qml).

The popup mirrors the bar settings window's Calendar tab: list/add/remove
the clock's calendars, writing calendars.json through the plugin's own
copy of write-calendars.py. All URLs below are placeholders; no real
calendar link is used anywhere.
"""

import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest

TEST_DIR = os.path.dirname(os.path.abspath(__file__))
PLUGIN_DIR = os.path.dirname(TEST_DIR)
BAR_SCRIPT = os.path.join(
    os.path.expanduser("~"),
    "workspace",
    "nyxiri-fix",
    "scripts",
    "write-calendars.py",
)
WRITE_SCRIPT = os.path.join(PLUGIN_DIR, "scripts", "write-calendars.py")

PLACEHOLDER_URL = "https://example.com/calendars/feed.ics"


def read(name):
    with open(os.path.join(PLUGIN_DIR, name)) as f:
        return f.read()


class TestClockSettingsPopup(unittest.TestCase):
    def test_right_click_cycles_format(self):
        # 2026-11-24, Devi: right-click used to cycle the clock format
        # and the settings popup stole it. A plain right-click cycles
        # again; Shift+right-click opens settings instead.
        widget = read("BarWidget.qml")
        self.assertIn("function cycleFormat()", widget)
        self.assertIn("function cycleFormat(): void { root.cycleFormat() }", widget)
        self.assertIn("onPressed: function(b, modifiers)", widget)
        self.assertIn("root.cycleFormat(); return", widget)
        self.assertNotIn(
            "if (b === Qt.RightButton) { root.toggleSettings(); return }",
            widget,
        )

    def test_shift_right_click_opens_settings(self):
        widget = read("BarWidget.qml")
        self.assertIn("property bool settingsOpen: false", widget)
        self.assertIn("function toggleSettings()", widget)
        self.assertIn("root.settingsOpen = !root.settingsOpen", widget)
        self.assertIn("ClockSettings {", widget)
        self.assertIn("visible: root.settingsOpen", widget)
        self.assertIn(
            "if (modifiers & Qt.ShiftModifier) { root.toggleSettings(); return }",
            widget,
        )
        # Left-click still toggles the calendar panel, middle-click still
        # opens the timezone picker.
        self.assertIn('root.bar.run("hexciri-menu-timezone")', widget)
        self.assertIn("else root.togglePanel()", widget)
        popup = read("ClockSettings.qml")
        self.assertIn(
            "Right-click the clock cycles its format; Shift+right-click opens this window.",
            popup,
        )

    def test_popup_mirrors_calendar_tab(self):
        popup = read("ClockSettings.qml")
        self.assertIn("PanelWindow {", popup)
        self.assertIn(
            'WlrLayershell.namespace: "pizza.dirty.clock-settings"', popup
        )
        self.assertIn('SectionLabel { text: "CALENDAR" }', popup)
        self.assertIn("Repeater {", popup)
        self.assertIn("model: popup.calendars", popup)
        # Links are masked by default with a per-row eye toggle; local
        # paths show in plain text.
        self.assertIn('"••••••••••••"', popup)
        self.assertIn("showSecret", popup)
        self.assertIn('"\\udb80\\ude08"', popup)
        self.assertIn('"\\udb80\\ude09"', popup)
        self.assertIn("function addCalendar()", popup)
        self.assertIn("function removeCalendar(index)", popup)
        self.assertIn("function setCalendarEnabled(index, enabled)", popup)
        self.assertIn("function saveCalendars(list)", popup)
        self.assertIn("function loadCalendars()", popup)
        # Writes go through the plugin's own copy of the helper, and the
        # clock refetches on the file change, so no separate refresh.
        self.assertIn("pizza.dirty.clock/scripts/write-calendars.py", popup)
        self.assertIn('text: "Add calendar"', popup)
        self.assertIn('text: "Close"', popup)
        self.assertIn('sequence: "Escape"', popup)
        self.assertIn("mask: Region { item: windowBody }", popup)
        # The clock's display format settings stay in shell.json; they
        # are not part of this popup.
        self.assertNotIn('setting("format"', popup)
        self.assertNotIn('setting("formatAlt"', popup)
        self.assertNotIn('setting("badgeMinutes"', popup)

    def test_add_rejects_plain_http(self):
        popup = read("ClockSettings.qml")
        self.assertIn('link.indexOf("http://") === 0', popup)
        self.assertIn("Use https://", popup)


class TestWriteCalendarsScript(unittest.TestCase):
    def test_script_exists_and_compiles(self):
        self.assertTrue(os.path.exists(WRITE_SCRIPT))
        with open(WRITE_SCRIPT) as f:
            source = f.read()
        compile(source, WRITE_SCRIPT, "exec")

    def test_script_matches_bar_copy_except_docstring(self):
        with open(BAR_SCRIPT) as f:
            bar_lines = f.read().splitlines()
        with open(WRITE_SCRIPT) as f:
            clock_lines = f.read().splitlines()
        # The only difference is the docstring caller lines at the top.
        self.assertEqual(bar_lines[6:], clock_lines[7:])

    def run_script(self, entries, tmp_dir):
        target = os.path.join(tmp_dir, "calendars.json")
        proc = subprocess.run(
            [sys.executable, WRITE_SCRIPT, "--file", target, json.dumps(entries)],
            capture_output=True,
            text=True,
            timeout=30,
        )
        return proc, target

    def test_writes_placeholder_list_at_0600(self):
        entries = [
            {
                "account": "Personal",
                "name": "Placeholder",
                "url": PLACEHOLDER_URL,
                "color": "#4285f4",
                "enabled": True,
            },
            {
                "account": "Local",
                "name": "Local",
                "path": "~/Documents/calendar.ics",
                "color": "#fbbc05",
                "enabled": False,
            },
        ]
        with tempfile.TemporaryDirectory() as tmp_dir:
            proc, target = self.run_script(entries, tmp_dir)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            self.assertEqual(json.loads(proc.stdout)["status"], "ok")
            self.assertEqual(oct(os.stat(target).st_mode & 0o777), "0o600")
            self.assertEqual(oct(os.stat(tmp_dir).st_mode & 0o777), "0o700")
            with open(target) as f:
                written = json.load(f)
            self.assertEqual(len(written), 2)
            self.assertEqual(written[0]["url"], PLACEHOLDER_URL)
            self.assertEqual(written[1]["path"], "~/Documents/calendar.ics")

    def test_rejects_plain_http_without_echoing_value(self):
        entries = [
            {
                "account": "Personal",
                "name": "Bad",
                "url": "http://example.com/feed.ics",
                "color": "#4285f4",
                "enabled": True,
            }
        ]
        with tempfile.TemporaryDirectory() as tmp_dir:
            proc, _ = self.run_script(entries, tmp_dir)
            self.assertNotEqual(proc.returncode, 0)
            self.assertNotIn("example.com", proc.stdout + proc.stderr)

    def test_rejects_invalid_json(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            target = os.path.join(tmp_dir, "calendars.json")
            proc = subprocess.run(
                [sys.executable, WRITE_SCRIPT, "--file", target, "not json"],
                capture_output=True,
                text=True,
                timeout=30,
            )
            self.assertNotEqual(proc.returncode, 0)


if __name__ == "__main__":
    unittest.main()

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Standalone clock settings. A floating layer-shell window with the
// same controls as the bar's settings window Calendar tab, for when the
// clock plugin runs on its own (stock Omarchy bar, no Nyxiri bar), where
// there is no bar settings window to open. Opened by
// Shift+right-clicking the clock widget (a plain right-click cycles the
// label format); the widget's toggleSettings() flips it.
// The clock is the calendar, basically: this tab IS the clock's settings.
// It lists the clock's calendars, adds one from an iCal / .ics link or a
// local .ics file, and removes one, writing calendars.json through the
// plugin's own copy of write-calendars.py. The clock widget watches that
// file and refetches when it changes, so writing it is the refresh: the
// bar's Calendar tab and this popup write the same file the same way, so
// the two stay in sync. The clock's display format settings (format,
// formatAlt, badgeMinutes) are not here; they stay in shell.json.
PanelWindow {
  id: popup

  // `bar` is passed from the widget (the bar the widget sits on, Nyxiri
  // or stock); `hostWidget` is the clock widget root.
  property var bar: null
  property var hostWidget: null

  // A real layer-shell surface, not a popup: it takes keyboard focus
  // natively, so the name and link fields just work. Floating: it
  // reserves no bar space, and the mask limits input to the window body
  // so clicks outside it pass through to the windows below.
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "pizza.dirty.clock-settings"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  // Close is named closeSettings, not close: PanelWindow is a QQuickWindow
  // and already has a close() method, which this must not shadow.
  function closeSettings() {
    if (hostWidget) hostWidget.settingsOpen = false
  }

  // ---------------------------------------------------------------- calendar

  // The clock plugin's calendars live in a plain file, not a widget
  // setting: ~/.config/pizza.dirty.clock/calendars.json, a list of
  // {account, name, url|path, color, enabled}. A remote feed has `url`
  // (an iCal/.ics link, https:// or webcal:// — the fetcher refuses
  // plain http); a local file has `path` (a .ics file, ~ expands).
  // The clock widget watches this file and refetches when it changes,
  // so writing it is the whole refresh mechanism. The file is 0600:
  // the links are secret, so each row masks its link like a password
  // field and only reveals one when its eye toggle is tapped.
  readonly property string calendarsPath: (Quickshell.env("HOME") || "") + "/.config/pizza.dirty.clock/calendars.json"
  readonly property string calendarsScript: (Quickshell.env("HOME") || "") + "/.config/hexciri/plugins/pizza.dirty.clock/scripts/write-calendars.py"
  property var calendars: []
  property var calendarsBeforeSave: []
  property string calendarsStatus: ""
  property string calendarsWriteOutput: ""
  property bool newCalShowLink: false

  function loadCalendars() {
    try {
      var parsed = JSON.parse(String(calendarsFile.text() || "[]"))
      popup.calendars = Array.isArray(parsed) ? parsed : []
    } catch (e) {
      popup.calendars = []
    }
  }

  // The list is one argv to the helper (never a shell string, so secret
  // URLs pass through untouched). The helper validates, writes atomically
  // at 0600, and prints {"status": "ok"} or {"status": "error", ...};
  // its errors never echo a value back, so a link cannot leak into the
  // status line. The list is updated optimistically and restored if the
  // write fails, so the popup never shows a calendar that is not on disk.
  function saveCalendars(list) {
    popup.calendarsBeforeSave = popup.calendars
    popup.calendars = list
    popup.calendarsStatus = ""
    calendarsWrite.command = ["python3", popup.calendarsScript, "--file", popup.calendarsPath, JSON.stringify(list)]
    calendarsWrite.running = true
  }

  function addCalendar() {
    var name = String(newNameField.text || "").trim()
    var link = String(newLinkField.text || "").trim()
    var account = String(newAccountField.text || "").trim() || "Personal"
    if (name === "") { popup.calendarsStatus = "Give the calendar a name."; return }
    if (link === "") { popup.calendarsStatus = "Paste a link or a local file path."; return }
    var entry = { account: account, name: name, color: "#4285f4", enabled: true }
    if (link.indexOf("http://") === 0) {
      popup.calendarsStatus = "Use https:// — the clock refuses plain http links."
      return
    }
    if (link.indexOf("https://") === 0 || link.indexOf("webcal://") === 0) entry.url = link
    else entry.path = link
    var list = popup.calendars.slice()
    list.push(entry)
    popup.saveCalendars(list)
    newNameField.text = ""
    newAccountField.text = ""
    newLinkField.text = ""
    popup.newCalShowLink = false
  }

  function removeCalendar(index) {
    var list = popup.calendars.slice()
    if (index < 0 || index >= list.length) return
    list.splice(index, 1)
    popup.saveCalendars(list)
  }

  function setCalendarEnabled(index, enabled) {
    var list = popup.calendars.slice()
    if (index < 0 || index >= list.length) return
    var entry = {}
    for (var k in list[index]) entry[k] = list[index][k]
    entry.enabled = enabled
    list[index] = entry
    popup.saveCalendars(list)
  }

  // ------------------------------------------------------------------- ui

  component SectionLabel: Text {
    color: Qt.darker(popup.bar.foreground, 1.35)
    font.family: popup.bar.fontFamily
    font.pixelSize: Style.font.title
    font.bold: true
    font.letterSpacing: 0.4
    textFormat: Text.PlainText
    topPadding: Style.space(16)
    bottomPadding: Style.spacing.md
  }

  // Sub-headers under a section (Add a calendar): one step smaller than
  // a section header, still bigger than the old caption labels, with room
  // under them too.
  component SubLabel: Text {
    color: Qt.darker(popup.bar.foreground, 1.4)
    font.family: popup.bar.fontFamily
    font.pixelSize: Style.font.body
    font.bold: true
    textFormat: Text.PlainText
    bottomPadding: Style.spacing.sm
  }

  component BodyText: Text {
    color: popup.bar.foreground
    font.family: popup.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
  }

  // Text input in a popup does not take keyboard focus on click by itself:
  // the click selects text but no cursor appears and keys go nowhere.
  // Stock panels force focus explicitly, deferred: forcing focus
  // synchronously during the press can run before the click has activated
  // the popup window, so it lands nowhere. This defers it the same way,
  // and lets the press through so cursor placement and selection keep
  // working. The field owns its text and only syncs from `settingText`
  // when the saved value actually changes, so typing is never clobbered
  // by an unrelated layout write. It commits on its own: 400ms after the
  // last keystroke, and immediately on Enter or focus loss, so typing
  // sticks however the window is left.
  component FocusField: TextField {
    signal commit(string value)

    property string settingText: ""
    onSettingTextChanged: {
      if (settingText !== text) text = settingText
      lastCommitted = settingText
    }

    property string lastCommitted: ""

    Component.onCompleted: lastCommitted = text

    function commitNow() {
      commitTimer.stop()
      if (text === lastCommitted) return
      lastCommitted = text
      commit(text)
    }

    Timer {
      id: commitTimer
      interval: 400
      onTriggered: commitNow()
    }

    onTextChanged: commitTimer.restart()
    onEditingFinished: commitNow()

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      onPressed: function(mouse) {
        mouse.accepted = false
        var field = parent
        Qt.callLater(function() { field.forceActiveFocus() })
      }
    }
  }

  Shortcut {
    sequence: "Escape"
    enabled: popup.visible
    onActivated: popup.closeSettings()
  }

  // The clock's calendars file, watched so the popup follows edits made
  // elsewhere (and the clock widget refetches on the same change). The
  // file may not exist yet on a fresh install — the popup then shows an
  // empty list and the first add creates it.
  FileView {
    id: calendarsFile
    path: popup.calendarsPath
    watchChanges: true
    printErrors: false
    onLoaded: popup.loadCalendars()
    onLoadFailed: popup.calendars = []
    onFileChanged: popup.loadCalendars()
  }

  Process {
    id: calendarsWrite
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: popup.calendarsWriteOutput = String(text || "")
    }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      var msg = ""
      try {
        var parsed = JSON.parse(popup.calendarsWriteOutput || "{}")
        msg = String(parsed.error || "")
      } catch (e) {}
      if (exitCode !== 0) {
        popup.calendars = popup.calendarsBeforeSave
        popup.calendarsStatus = msg !== "" ? msg : "Could not save calendars"
      } else {
        popup.calendarsStatus = "Saved."
        calendarsFile.reload()
      }
    }
  }

  // The window body: a fixed-size surface centered on its screen. The
  // PanelWindow itself spans the screen (transparent) and the mask limits
  // input to this body, so clicks outside it pass through.
  BorderSurface {
    id: windowBody
    anchors.centerIn: parent
    width: Style.space(560)
    height: Style.space(600)
    radius: Style.cornerRadius
    color: popup.bar.background
    borderSpec: Border.flat(popup.bar.foreground, 1)

    Column {
      anchors.fill: parent
      anchors.margins: Style.spacing.md
      spacing: Style.spacing.sm

      Flickable {
        id: scrollArea
        width: parent.width
        height: parent.height - closeButton.height - parent.spacing
        contentWidth: width
        contentHeight: body.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        clip: true

        Column {
          id: body
          width: scrollArea.width
          spacing: Style.space(16)

          SectionLabel { text: "CALENDAR" }

          Text {
            width: body.width
            text: "The clock's calendars. Add an iCal / .ics link or a local .ics file — no need to edit calendars.json by hand."
            color: Qt.darker(popup.bar.foreground, 1.45)
            font.family: popup.bar.fontFamily
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
          }

          BodyText {
            visible: popup.calendars.length === 0
            width: body.width
            text: "No calendars yet. Add one below."
            color: Qt.darker(popup.bar.foreground, 1.35)
            font.pixelSize: Style.font.caption
          }

          Repeater {
            model: popup.calendars

            delegate: Column {
              id: calRow
              required property var modelData
              required property int index
              property bool showSecret: false
              width: body.width
              spacing: Style.spacing.xxs

              Row {
                width: parent.width
                spacing: Style.spacing.sm

                Rectangle {
                  width: Style.space(12)
                  height: Style.space(12)
                  radius: Style.space(6)
                  color: String(calRow.modelData.color || "#4285f4")
                  anchors.verticalCenter: parent.verticalCenter
                }

                BodyText {
                  text: String(calRow.modelData.name || "Calendar")
                  font.bold: true
                  width: parent.width - Style.space(12) - enabledSwitch.width - removeButton.width - parent.spacing * 3
                  elide: Text.ElideRight
                  anchors.verticalCenter: parent.verticalCenter
                }

                ToggleSwitch {
                  id: enabledSwitch
                  anchors.verticalCenter: parent.verticalCenter
                  checked: calRow.modelData.enabled !== false
                  foreground: popup.bar.foreground
                  onToggled: popup.setCalendarEnabled(calRow.index, !(calRow.modelData.enabled !== false))
                }

                Button {
                  id: removeButton
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Remove"
                  bordered: true
                  foreground: popup.bar.foreground
                  onClicked: popup.removeCalendar(calRow.index)
                }
              }

              Row {
                visible: calRow.modelData.url !== undefined && calRow.modelData.url !== null && String(calRow.modelData.url || "") !== ""
                width: parent.width
                spacing: Style.spacing.xs

                // Display only: a Text, not a field. The link shows
                // as bullets until this row's eye toggle reveals it.
                Text {
                  width: parent.width - linkEye.width - parent.spacing
                  text: calRow.showSecret ? String(calRow.modelData.url || "") : "••••••••••••"
                  elide: Text.ElideRight
                  color: popup.bar.foreground
                  font.family: popup.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  textFormat: Text.PlainText
                  verticalAlignment: Text.AlignVCenter
                }

                Item {
                  id: linkEye
                  width: Style.space(32)
                  height: Style.space(28)
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    anchors.centerIn: parent
                    // nf-md-eye / nf-md-eye-off, U+F0208 / U+F0209.
                    text: calRow.showSecret ? "\udb80\ude09" : "\udb80\ude08"
                    color: popup.bar.foreground
                    font.family: popup.bar.fontFamily
                    font.pixelSize: Style.font.body
                    textFormat: Text.PlainText
                  }

                  MouseArea {
                    anchors.fill: parent
                    onClicked: calRow.showSecret = !calRow.showSecret
                  }
                }
              }

              BodyText {
                visible: (calRow.modelData.url === undefined || calRow.modelData.url === null || String(calRow.modelData.url || "") === "") && calRow.modelData.path !== undefined && calRow.modelData.path !== null && String(calRow.modelData.path || "") !== ""
                width: parent.width
                text: String(calRow.modelData.path || "")
                elide: Text.ElideRight
                color: Qt.darker(popup.bar.foreground, 1.4)
                font.pixelSize: Style.font.caption
              }
            }
          }

          SubLabel { text: "Add a calendar" }

          FocusField {
            id: newNameField
            width: body.width
            placeholderText: "Name"
            foreground: popup.bar.foreground
            font.family: popup.bar.fontFamily
            font.pixelSize: Style.font.body
          }

          FocusField {
            id: newAccountField
            width: body.width
            placeholderText: "Account (optional, default Personal)"
            foreground: popup.bar.foreground
            font.family: popup.bar.fontFamily
            font.pixelSize: Style.font.body
          }

          Row {
            width: body.width
            spacing: Style.spacing.xs

            FocusField {
              id: newLinkField
              width: parent.width - newLinkEye.width - parent.spacing
              echoMode: popup.newCalShowLink ? TextInput.Normal : TextInput.Password
              placeholderText: "https://…/basic.ics or ~/path/to/file.ics"
              foreground: popup.bar.foreground
              font.family: popup.bar.fontFamily
              font.pixelSize: Style.font.body
            }

            Item {
              id: newLinkEye
              width: Style.space(32)
              height: newLinkField.height

              Text {
                anchors.centerIn: parent
                // nf-md-eye / nf-md-eye-off, U+F0208 / U+F0209.
                text: popup.newCalShowLink ? "\udb80\ude09" : "\udb80\ude08"
                color: popup.bar.foreground
                font.family: popup.bar.fontFamily
                font.pixelSize: Style.font.body
                textFormat: Text.PlainText
              }

              MouseArea {
                anchors.fill: parent
                onClicked: popup.newCalShowLink = !popup.newCalShowLink
              }
            }
          }

          Text {
            width: body.width
            text: "An iCal / .ics link (https:// or webcal://) or a local .ics file path. Links stay hidden unless you tap the eye."
            color: Qt.darker(popup.bar.foreground, 1.4)
            font.family: popup.bar.fontFamily
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
          }

          Button {
            text: "Add calendar"
            bordered: true
            foreground: popup.bar.foreground
            onClicked: popup.addCalendar()
          }

          BodyText {
            visible: popup.calendarsStatus !== ""
            width: body.width
            text: popup.calendarsStatus
            color: Qt.darker(popup.bar.foreground, 1.35)
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }

      Button {
        id: closeButton
        width: parent.width
        text: "Close"
        bordered: true
        foreground: popup.bar.foreground
        onClicked: popup.closeSettings()
      }

      BodyText {
        width: body.width
        text: "Right-click the clock cycles its format; Shift+right-click opens this window."
        color: Qt.darker(popup.bar.foreground, 1.35)
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }

  // Input goes only to the window body; the rest of the fullscreen surface
  // is transparent to the pointer.
  mask: Region { item: windowBody }
}

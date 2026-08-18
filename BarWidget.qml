import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "gigor.notifications"

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/notifications"
  readonly property string settingsPath: Quickshell.env("HOME") + "/.local/state/omarchy/notifications.json"
  property bool doNotDisturb: false
  readonly property bool hasNotifications: liveNotifications.count > 0 || historyNotifications.count > 0
  readonly property string iconText: doNotDisturb ? "󰪓" : (hasNotifications ? "󱅫" : "󰂜")

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function readDoNotDisturb(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      if (typeof parsed.dnd === "boolean") doNotDisturb = parsed.dnd
    } catch (error) {
      if (!dndProbe.running) dndProbe.running = true
    }
  }

  function refreshDoNotDisturb() {
    if (!dndProbe.running) dndProbe.running = true
  }

  function showHistory() {
    if (!showHistoryProcess.running) showHistoryProcess.running = true
  }

  function hideAndClearHistory() {
    if (!dismissAllProcess.running && !clearHistoryProcess.running)
      dismissAllProcess.running = true
  }

  function toggleDoNotDisturb() {
    if (!toggleDndProcess.running) toggleDndProcess.running = true
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.iconText
    tooltipText: ""

    onPressed: function(b) {
      if (b === Qt.RightButton) root.hideAndClearHistory()
      else if (b === Qt.MiddleButton) root.toggleDoNotDisturb()
      else root.showHistory()
    }
  }

  FolderListModel {
    id: liveNotifications
    folder: "file://" + root.stateDir
    nameFilters: ["*.json"]
    showDirs: false
    showFiles: true
    showDotAndDotDot: false
  }

  FolderListModel {
    id: historyNotifications
    folder: "file://" + root.stateDir + "/history"
    nameFilters: ["*.json"]
    showDirs: false
    showFiles: true
    showDotAndDotDot: false
  }

  FileView {
    id: dndSettings
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.readDoNotDisturb(text())
    onLoadFailed: root.refreshDoNotDisturb()
    onFileChanged: reload()
  }

  Timer {
    id: actionRefreshTimer
    interval: 250
    repeat: false
    onTriggered: root.refreshDoNotDisturb()
  }

  Process {
    id: dndProbe
    running: false
    command: ["omarchy-shell", "notifications", "dndState"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var state = String(text || "").trim()
        if (state === "on" || state === "off") root.doNotDisturb = state === "on"
      }
    }
  }

  Process {
    id: showHistoryProcess
    running: false
    command: ["omarchy-shell", "notifications", "showHistory"]
    onExited: actionRefreshTimer.restart()
  }

  Process {
    id: dismissAllProcess
    running: false
    command: ["omarchy-shell", "notifications", "dismissAll"]
    onExited: {
      if (!clearHistoryProcess.running) clearHistoryProcess.running = true
    }
  }

  Process {
    id: clearHistoryProcess
    running: false
    command: ["omarchy-shell", "notifications", "clear"]
    onExited: actionRefreshTimer.restart()
  }

  Process {
    id: toggleDndProcess
    running: false
    command: ["omarchy-toggle-notification-silencing"]
    onExited: actionRefreshTimer.restart()
  }

  Component.onCompleted: root.refreshDoNotDisturb()
}

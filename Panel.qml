import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.ofilafoo.pomarchy"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property string commandPath: ""
  property string phase: "focus"
  property string timerStatus: "ready"
  property int remainingSeconds: 1500
  property int durationSeconds: 1500
  property int completedInCycle: 0
  property int dailySessions: 0
  property int dailySeconds: 0
  property int focusMinutes: 25
  property int shortBreakMinutes: 5
  property int longBreakMinutes: 15
  property int longBreakAfter: 4
  property bool showCountdown: true
  property bool autoStart: false
  property bool notifications: true
  property bool sound: false
  property int cursorIndex: 0
  property bool confirmReset: false
  property string errorText: ""
  property string pendingActionOutput: ""
  property string pendingActionError: ""

  function applyStatus(value) {
    var parsed = typeof value === "string" ? JSON.parse(value) : value
    root.phase = parsed.phase || root.phase
    root.timerStatus = parsed.status || root.timerStatus
    root.remainingSeconds = Number(parsed.remainingSeconds === undefined ? root.remainingSeconds : parsed.remainingSeconds)
    root.durationSeconds = Number(parsed.durationSeconds || root.durationSeconds)
    root.completedInCycle = Number(parsed.completedInCycle || 0)
    if (parsed.daily) {
      root.dailySessions = Number(parsed.daily.focusSessions || 0)
      root.dailySeconds = Number(parsed.daily.focusSeconds || 0)
    }
    if (parsed.settings) {
      var nextFocus = Number(parsed.settings.focusMinutes)
      var nextShort = Number(parsed.settings.shortBreakMinutes)
      var nextLong = Number(parsed.settings.longBreakMinutes)
      var nextAfter = Number(parsed.settings.longBreakAfter)
      var nextShowCountdown = parsed.settings.showCountdown !== false
      var nextAuto = parsed.settings.autoStart === true
      var nextNotifications = parsed.settings.notifications === true
      var nextSound = parsed.settings.sound === true
      if (root.focusMinutes !== nextFocus) root.focusMinutes = nextFocus
      if (root.shortBreakMinutes !== nextShort) root.shortBreakMinutes = nextShort
      if (root.longBreakMinutes !== nextLong) root.longBreakMinutes = nextLong
      if (root.longBreakAfter !== nextAfter) root.longBreakAfter = nextAfter
      if (root.showCountdown !== nextShowCountdown) root.showCountdown = nextShowCountdown
      if (root.autoStart !== nextAuto) root.autoStart = nextAuto
      if (root.notifications !== nextNotifications) root.notifications = nextNotifications
      if (root.sound !== nextSound) root.sound = nextSound
    }
  }

  function runAction(action, argument, value) {
    if (actionProcess.running || !root.commandPath) return
    var args = [root.commandPath, action]
    if (argument !== undefined) args.push(String(argument))
    if (value !== undefined) args.push(String(value))
    root.errorText = ""
    root.pendingActionOutput = ""
    root.pendingActionError = ""
    actionProcess.command = args
    actionProcess.running = true
  }

  function primaryAction() {
    if (timerStatus === "ready") runAction("start")
    else if (timerStatus === "running") runAction("pause")
    else runAction("resume")
  }

  function adjust(delta) {
    var keys = ["focusMinutes", "shortBreakMinutes", "longBreakMinutes", "longBreakAfter"]
    var values = [root.focusMinutes, root.shortBreakMinutes, root.longBreakMinutes, root.longBreakAfter]
    var mins = [1, 1, 1, 1]
    var maxs = [120, 60, 120, 12]
    var settingIndex = cursorIndex - 3
    if (settingIndex < 0 || settingIndex > 3) return
    var key = keys[settingIndex]
    var next = Math.max(mins[settingIndex], Math.min(maxs[settingIndex], values[settingIndex] + delta))
    runAction("configure", key, next)
  }

  function moveCursor(dx, dy) {
    if (root.cursorIndex <= 2) {
      if (dx !== 0) root.cursorIndex = Math.max(0, Math.min(2, root.cursorIndex + dx))
      else if (dy > 0) root.cursorIndex = 3
      return
    }
    if (dy < 0 && root.cursorIndex === 3) root.cursorIndex = 0
    else if (dy !== 0) root.cursorIndex = Math.max(3, Math.min(11, root.cursorIndex + dy))
    else root.adjust(dx)
  }

  function beginSelectedEdit(initialText) {
    if (root.cursorIndex === 3) focusSetting.beginEdit(initialText)
    else if (root.cursorIndex === 4) shortSetting.beginEdit(initialText)
    else if (root.cursorIndex === 5) longSetting.beginEdit(initialText)
    else if (root.cursorIndex === 6) cycleSetting.beginEdit(initialText)
  }

  function requestReset() {
    if (actionProcess.running) return
    if (timerStatus === "running" && !confirmReset) {
      confirmReset = true
      return
    }
    confirmReset = false
    runAction("reset")
  }

  function activateCursor() {
    if (actionProcess.running) return
    if (cursorIndex === 0) primaryAction()
    else if (cursorIndex === 1) {
      if (timerStatus !== "ready") runAction("skip")
    }
    else if (cursorIndex === 2) root.requestReset()
    else if (cursorIndex >= 7 && cursorIndex <= 10) {
      var keys = ["showCountdown", "autoStart", "notifications", "sound"]
      var values = [root.showCountdown, root.autoStart, root.notifications, root.sound]
      var key = keys[cursorIndex - 7]
      runAction("configure", key, !values[cursorIndex - 7])
    } else if (cursorIndex === 11) runAction("defaults")
  }

  function open() { root.controller.show(); statusRefresh.restart() }
  function close() { confirmReset = false; root.controller.hide() }
  function toggle() { if (root.opened) close(); else open() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function") return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  Process {
    id: actionProcess
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.pendingActionOutput = String(text || "").trim() }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.pendingActionError = String(text || "").trim() }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.errorText = root.pendingActionError !== "" ? root.pendingActionError : "Pomarchy command failed (exit " + exitCode + ")."
        if (root.hostWidget) root.hostWidget.refresh()
        return
      }
      try {
        if (root.pendingActionOutput !== "") root.applyStatus(root.pendingActionOutput)
      } catch (error) {
        root.errorText = "Invalid Pomarchy response: " + error
      }
    }
  }

  Timer { id: statusRefresh; interval: 1000; repeat: true; running: root.opened; onTriggered: if (root.hostWidget) root.hostWidget.refresh() }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: focusSetting.editing || shortSetting.editing || longSetting.editing || cycleSetting.editing
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(value) {
        if (/^\d$/.test(value) && root.cursorIndex >= 3 && root.cursorIndex <= 6)
          root.beginSelectedEdit(value)
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(6)

        Text { width: parent.width; text: "Pomarchy · " + Model.phaseLabel(root.phase); color: root.barForeground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
        Text { width: parent.width; text: Model.formatSeconds(root.remainingSeconds); color: root.barForeground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.title; font.bold: true; horizontalAlignment: Text.AlignHCenter }
        Rectangle { width: parent.width; height: Style.space(4); color: Qt.darker(root.barForeground, 2); radius: height / 2; Rectangle { height: parent.height; width: parent.width * Math.max(0, Math.min(1, 1 - root.remainingSeconds / Math.max(1, root.durationSeconds))); color: Color.accent; radius: height / 2 } }
        Text { width: parent.width; text: Model.statusLabel(root.timerStatus) + " · Today: " + root.dailySessions + " sessions / " + Math.round(root.dailySeconds / 60) + " min"; color: root.barForeground; opacity: 0.75; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Style.font.caption }

        Row {
          width: parent.width; spacing: Style.space(8)
          ActionButton { width: (parent.width - parent.spacing * 2) / 3; label: root.timerStatus === "ready" ? "Start" : (root.timerStatus === "running" ? "Pause" : "Resume"); selected: root.cursorIndex === 0; onTriggered: root.primaryAction() }
          ActionButton { width: (parent.width - parent.spacing * 2) / 3; label: "Skip"; selected: root.cursorIndex === 1; enabled: root.timerStatus !== "ready"; onTriggered: root.runAction("skip") }
          ActionButton { width: (parent.width - parent.spacing * 2) / 3; label: root.confirmReset ? "Confirm reset" : "Reset"; selected: root.cursorIndex === 2; urgent: root.confirmReset; onTriggered: root.requestReset() }
        }

        Text { text: "DURATIONS"; color: root.barForeground; opacity: 0.6; font.bold: true; font.pixelSize: Style.font.caption }
        SettingRow { id: focusSetting; label: "Focus"; suffix: "min"; value: root.focusMinutes; minimum: 1; maximum: 120; selected: root.cursorIndex === 3; onDecrease: root.runAction("configure", "focusMinutes", Math.max(minimum, value - 1)); onIncrease: root.runAction("configure", "focusMinutes", Math.min(maximum, value + 1)); onCommitValue: function(next) { root.runAction("configure", "focusMinutes", next) } }
        SettingRow { id: shortSetting; label: "Short break"; suffix: "min"; value: root.shortBreakMinutes; minimum: 1; maximum: 60; selected: root.cursorIndex === 4; onDecrease: root.runAction("configure", "shortBreakMinutes", Math.max(minimum, value - 1)); onIncrease: root.runAction("configure", "shortBreakMinutes", Math.min(maximum, value + 1)); onCommitValue: function(next) { root.runAction("configure", "shortBreakMinutes", next) } }
        SettingRow { id: longSetting; label: "Long break"; suffix: "min"; value: root.longBreakMinutes; minimum: 1; maximum: 120; selected: root.cursorIndex === 5; onDecrease: root.runAction("configure", "longBreakMinutes", Math.max(minimum, value - 1)); onIncrease: root.runAction("configure", "longBreakMinutes", Math.min(maximum, value + 1)); onCommitValue: function(next) { root.runAction("configure", "longBreakMinutes", next) } }
        SettingRow { id: cycleSetting; label: "Long break after"; suffix: "focus"; value: root.longBreakAfter; minimum: 1; maximum: 12; selected: root.cursorIndex === 6; onDecrease: root.runAction("configure", "longBreakAfter", Math.max(minimum, value - 1)); onIncrease: root.runAction("configure", "longBreakAfter", Math.min(maximum, value + 1)); onCommitValue: function(next) { root.runAction("configure", "longBreakAfter", next) } }
        ToggleRow { label: "Show countdown in bar"; checked: root.showCountdown; selected: root.cursorIndex === 7; onTriggered: root.runAction("configure", "showCountdown", !checked) }
        ToggleRow { label: "Auto-start next phase"; checked: root.autoStart; selected: root.cursorIndex === 8; onTriggered: root.runAction("configure", "autoStart", !checked) }
        ToggleRow { label: "Notifications"; checked: root.notifications; selected: root.cursorIndex === 9; onTriggered: root.runAction("configure", "notifications", !checked) }
        ToggleRow { label: "Sound"; checked: root.sound; selected: root.cursorIndex === 10; onTriggered: root.runAction("configure", "sound", !checked) }
        ActionButton { width: parent.width; label: "Restore Pomodoro defaults"; selected: root.cursorIndex === 11; onTriggered: root.runAction("defaults") }
        Text { visible: root.errorText !== ""; width: parent.width; text: root.errorText; color: Color.urgent; wrapMode: Text.WordWrap; font.pixelSize: Style.font.caption }
        Text { width: parent.width; text: "j/k rows · h/l actions or values · Enter select · Esc close"; color: root.barForeground; opacity: 0.5; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter }
      }
    }
  }

  component ActionButton: Rectangle {
    id: action
    property string label: ""
    property bool selected: false
    property bool urgent: false
    property bool hovered: false
    signal triggered()
    implicitWidth: Style.space(88)
    implicitHeight: Style.space(30)
    radius: Style.cornerRadius
    color: selected || hovered
      ? Style.hoverFillFor(root.barForeground, Color.accent)
      : Style.normalFillFor(root.barForeground, Color.accent)
    border.width: 1
    border.color: urgent ? Color.urgent
      : (selected || hovered ? Color.accent : Qt.darker(root.barForeground, 1.8))

    Text {
      anchors.centerIn: parent
      text: action.label
      color: action.enabled ? root.barForeground : Qt.darker(root.barForeground, 2)
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: action.selected
    }

    MouseArea {
      anchors.fill: parent
      enabled: action.enabled
      hoverEnabled: true
      cursorShape: action.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onEntered: action.hovered = true
      onExited: action.hovered = false
      onClicked: action.triggered()
    }
  }

  component SettingRow: Rectangle {
    id: setting
    property string label: ""; property string suffix: ""; property int value: 0; property int minimum: 1; property int maximum: 120; property bool selected: false; property bool editing: false
    signal decrease(); signal increase(); signal commitValue(int value)
    function beginEdit(initialText) {
      editor.text = initialText === undefined ? String(setting.value) : String(initialText)
      setting.editing = true
      Qt.callLater(function() { editor.forceActiveFocus(); editor.selectAll() })
    }
    function finishEdit(commit) {
      if (!setting.editing) return
      var next = parseInt(editor.text, 10)
      setting.editing = false
      if (commit && !isNaN(next) && next >= setting.minimum && next <= setting.maximum)
        setting.commitValue(next)
      keyCatcher.forceActiveFocus()
    }
    width: parent.width; implicitHeight: Style.space(32); radius: Style.cornerRadius; color: selected ? Style.hoverFillFor(root.barForeground, Color.accent) : "transparent"
    Text { anchors.left: parent.left; anchors.leftMargin: Style.space(6); anchors.verticalCenter: parent.verticalCenter; text: setting.label; color: root.barForeground; font.pixelSize: Style.font.bodySmall }
    Row { anchors.right: parent.right; anchors.rightMargin: Style.space(4); anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(4)
      ActionButton { label: "−"; implicitWidth: Style.space(30); implicitHeight: Style.space(26); onTriggered: setting.decrease() }
      ActionButton { visible: !setting.editing; label: setting.value + " " + setting.suffix; implicitWidth: Style.space(64); implicitHeight: Style.space(26); onTriggered: setting.beginEdit() }
      TextField {
        id: editor
        visible: setting.editing
        width: Style.space(64)
        foreground: root.barForeground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        horizontalAlignment: TextInput.AlignHCenter
        inputMethodHints: Qt.ImhDigitsOnly
        validator: IntValidator { bottom: setting.minimum; top: setting.maximum }
        onAccepted: setting.finishEdit(true)
        Keys.onEscapePressed: function(event) { setting.finishEdit(false); event.accepted = true }
        onActiveFocusChanged: if (!activeFocus && setting.editing) setting.finishEdit(true)
      }
      ActionButton { label: "+"; implicitWidth: Style.space(30); implicitHeight: Style.space(26); onTriggered: setting.increase() }
    }
  }

  component ToggleRow: Rectangle {
    id: toggleRow
    property string label: ""; property bool checked: false; property bool selected: false
    signal triggered()
    width: parent.width; implicitHeight: Style.space(32); radius: Style.cornerRadius; color: selected ? Style.hoverFillFor(root.barForeground, Color.accent) : "transparent"
    Text { anchors.left: parent.left; anchors.leftMargin: Style.space(6); anchors.verticalCenter: parent.verticalCenter; text: toggleRow.label; color: root.barForeground; font.pixelSize: Style.font.bodySmall }
    ToggleSwitch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; checked: toggleRow.checked; trackHeight: Style.space(18); onToggled: toggleRow.triggered() }
  }
}

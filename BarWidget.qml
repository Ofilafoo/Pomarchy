import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.ofilafoo.pomarchy"

  property string phase: "focus"
  property string timerStatus: "ready"
  property int remainingSeconds: 1500
  property bool showCountdown: true
  property color focusColor: Color.accent
  property color breakColor: Color.urgent
  property string lastError: ""
  property string pendingStatusOutput: ""
  property string pendingStatusError: ""
  property string pendingIpcError: ""
  readonly property color neutralColor: root.bar ? root.bar.barForeground : Color.foreground
  readonly property color tomatoColor: root.timerStatus !== "running"
    ? root.neutralColor
    : (root.phase === "focus" ? root.focusColor : root.breakColor)
  readonly property string commandPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.ofilafoo.pomarchy/pomarchy"
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function applyStatus(value) {
    try {
      var parsed = JSON.parse(String(value || "{}"))
      root.phase = parsed.phase || "focus"
      root.timerStatus = parsed.status || "ready"
      root.remainingSeconds = Number(parsed.remainingSeconds || 0)
      if (parsed.settings) root.showCountdown = parsed.settings.showCountdown !== false
      if (panelLoader.item) panelLoader.item.applyStatus(parsed)
    } catch (error) {
      root.lastError = "Invalid timer status: " + error
    }
  }

  function refresh() {
    if (!statusProcess.running) {
      root.pendingStatusOutput = ""
      root.pendingStatusError = ""
      statusProcess.running = true
    }
  }

  function loadThemePalette(raw) {
    var lines = String(raw || "").split("\n")
    var green = "", color2 = "", red = "", color1 = ""
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*(green|color2|red|color1)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
      if (!match) continue
      if (match[1] === "green") green = match[2]
      else if (match[1] === "color2") color2 = match[2]
      else if (match[1] === "red") red = match[2]
      else if (match[1] === "color1") color1 = match[2]
    }
    root.focusColor = green !== "" ? green : (color2 !== "" ? color2 : Color.accent)
    root.breakColor = red !== "" ? red : (color1 !== "" ? color1 : Color.urgent)
  }

  function runIpcAction(action) {
    if (ipcProcess.running) return
    root.pendingIpcError = ""
    ipcProcess.command = [root.commandPath, action]
    ipcProcess.running = true
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = buttonLoader.item
    panelLoader.item.hostWidget = root
    panelLoader.item.commandPath = root.commandPath
    panelLoader.item.applyStatus({phase: root.phase, status: root.timerStatus, remainingSeconds: root.remainingSeconds})
  }

  implicitWidth: buttonLoader.item ? buttonLoader.item.implicitWidth : 0
  implicitHeight: buttonLoader.item ? buttonLoader.item.implicitHeight : 0
  onBarChanged: injectPanel()
  Component.onCompleted: refresh()

  Process {
    id: statusProcess
    command: [root.commandPath, "status"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.pendingStatusOutput = String(text || "").trim() }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.pendingStatusError = String(text || "").trim() }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = root.pendingStatusError !== "" ? root.pendingStatusError : "Pomarchy status failed (exit " + exitCode + ")."
        return
      }
      root.lastError = ""
      root.applyStatus(root.pendingStatusOutput)
    }
  }

  Process {
    id: ipcProcess
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.pendingIpcError = String(text || "").trim() }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        root.lastError = root.pendingIpcError !== "" ? root.pendingIpcError : "Pomarchy IPC action failed (exit " + exitCode + ")."
      root.refresh()
    }
  }

  FileView {
    id: themePalette
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadThemePalette(text())
    onFileChanged: reload()
  }

  Timer { interval: 1000; repeat: true; running: true; onTriggered: root.refresh() }

  IpcHandler {
    target: "io.github.ofilafoo.pomarchy"
    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function start() { root.runIpcAction("start") }
    function pause() { root.runIpcAction("pause") }
    function resume() { root.runIpcAction("resume") }
    function skip() { root.runIpcAction("skip") }
    function reset() { root.runIpcAction("reset") }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  Loader {
    id: buttonLoader
    anchors.fill: parent
    sourceComponent: root.showCountdown ? countdownButtonComponent : tomatoButtonComponent
    onLoaded: root.injectPanel()
  }

  Component {
    id: countdownButtonComponent
    WidgetButton {
      bar: root.bar
      text: (root.timerStatus === "paused" ? "Ⅱ " : (root.phase === "focus" ? "" : "☕ ")) + Model.formatSeconds(root.remainingSeconds)
      tooltipText: Model.phaseLabel(root.phase) + " · " + Model.statusLabel(root.timerStatus) + " · " + Model.formatSeconds(root.remainingSeconds)
      onPressed: function(buttonCode) { if (buttonCode === Qt.LeftButton) root.toggle() }
    }
  }

  Component {
    id: tomatoButtonComponent
    BarIconButton {
      bar: root.bar
      tooltipText: Model.phaseLabel(root.phase) + " · " + Model.statusLabel(root.timerStatus) + " · " + Model.formatSeconds(root.remainingSeconds)
      iconComponent: tomatoIconComponent
      onPressed: function(buttonCode) { if (buttonCode === Qt.LeftButton) root.toggle() }
    }
  }

  Component {
    id: tomatoIconComponent
    Canvas {
      id: tomato
      property color fillColor: root.tomatoColor
      onFillColorChanged: requestPaint()
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        var w = width
        var h = height
        ctx.clearRect(0, 0, w, h)
        ctx.fillStyle = fillColor

        // Rounded tomato body with a slightly indented top and broad base.
        ctx.beginPath()
        ctx.moveTo(w * 0.50, h * 0.28)
        ctx.bezierCurveTo(w * 0.72, h * 0.18, w * 0.91, h * 0.36, w * 0.87, h * 0.59)
        ctx.bezierCurveTo(w * 0.84, h * 0.82, w * 0.65, h * 0.91, w * 0.50, h * 0.91)
        ctx.bezierCurveTo(w * 0.35, h * 0.91, w * 0.16, h * 0.82, w * 0.13, h * 0.59)
        ctx.bezierCurveTo(w * 0.09, h * 0.36, w * 0.28, h * 0.18, w * 0.50, h * 0.28)
        ctx.fill()

        // Tomato crown and short stem, kept monochrome for theme tinting.
        ctx.beginPath()
        ctx.moveTo(w * 0.50, h * 0.08)
        ctx.lineTo(w * 0.56, h * 0.27)
        ctx.lineTo(w * 0.76, h * 0.22)
        ctx.lineTo(w * 0.61, h * 0.36)
        ctx.lineTo(w * 0.50, h * 0.29)
        ctx.lineTo(w * 0.39, h * 0.36)
        ctx.lineTo(w * 0.24, h * 0.22)
        ctx.lineTo(w * 0.44, h * 0.27)
        ctx.closePath()
        ctx.fill()
      }
    }
  }
}

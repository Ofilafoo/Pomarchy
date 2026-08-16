.pragma library

function formatSeconds(value) {
  var seconds = Math.max(0, Math.floor(Number(value) || 0))
  var hours = Math.floor(seconds / 3600)
  var minutes = Math.floor((seconds % 3600) / 60)
  var rest = seconds % 60
  if (hours > 0)
    return hours + ":" + (minutes < 10 ? "0" : "") + minutes + ":" + (rest < 10 ? "0" : "") + rest
  return (minutes < 10 ? "0" : "") + minutes + ":" + (rest < 10 ? "0" : "") + rest
}

function phaseLabel(phase) {
  if (phase === "short-break") return "Short break"
  if (phase === "long-break") return "Long break"
  return "Focus"
}

function statusLabel(status) {
  if (status === "running") return "Running"
  if (status === "paused") return "Paused"
  return "Ready"
}

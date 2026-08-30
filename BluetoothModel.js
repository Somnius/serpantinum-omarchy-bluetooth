function label(device) {
  if (!device) return "Unknown device"
  var value = String(device.name || device.deviceName || "").trim()
  return value.length > 0 ? value : "Unnamed device"
}

function snapshot(device) {
  var rawBattery = device && device.batteryAvailable ? Number(device.battery) : NaN
  var hasBattery = isFinite(rawBattery)
  return {
    address: device && device.address ? String(device.address) : "",
    name: label(device),
    connected: !!(device && device.connected),
    remembered: !!(device && (device.paired || device.bonded || device.trusted)),
    pairing: !!(device && device.pairing),
    batteryAvailable: hasBattery,
    battery: hasBattery ? Math.round(Math.max(0, Math.min(1, rawBattery)) * 100) : -1
  }
}

function compareRows(left, right) {
  if (left.connected !== right.connected) return left.connected ? -1 : 1
  if (left.remembered !== right.remembered) return left.remembered ? -1 : 1
  return left.name.localeCompare(right.name)
}

function rows(devices) {
  var result = []
  for (var index = 0; index < devices.length; index++) {
    if (devices[index]) result.push(snapshot(devices[index]))
  }
  result.sort(compareRows)
  return result
}

function status(row, pending) {
  if (pending === "connecting") return "Connecting…"
  if (pending === "disconnecting") return "Disconnecting…"
  if (row.pairing) return "Pairing…"
  if (row.connected && row.batteryAvailable) return row.battery + "% battery"
  if (row.connected) return "Connected"
  if (row.remembered) return "Paired"
  return "Available"
}

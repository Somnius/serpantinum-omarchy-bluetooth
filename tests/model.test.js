const assert = require("node:assert/strict")
const fs = require("node:fs")
const vm = require("node:vm")

const source = fs.readFileSync(new URL("../BluetoothModel.js", `file://${__dirname}/`), "utf8")
const model = {}
vm.createContext(model)
vm.runInContext(source, model)

const rows = Array.from(model.rows([
  { address: "C", name: "Keyboard", paired: true },
  { address: "A", name: "Headphones", connected: true, paired: true, batteryAvailable: true, battery: 0.72 },
  { address: "B", deviceName: "Mouse" }
]))

assert.equal(rows[0].name, "Headphones")
assert.equal(rows[0].battery, 72)
assert.equal(rows[1].name, "Keyboard")
assert.equal(rows[2].name, "Mouse")
assert.equal(model.label({}), "Unnamed device")
assert.equal(model.status(rows[0], ""), "72% battery")
assert.equal(model.status(rows[1], "connecting"), "Connecting…")
assert.equal(model.snapshot({ batteryAvailable: true, battery: "bad" }).batteryAvailable, false)
assert.equal(model.snapshot({ batteryAvailable: true, battery: 2 }).battery, 100)
assert.equal(model.snapshot({ batteryAvailable: true, battery: -1 }).battery, 0)
console.log("bluetooth model tests passed")

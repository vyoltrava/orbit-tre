const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync(`${__dirname}/../omarchy-plugin/Model.js`, "utf8")
  .replace(/^\.pragma library\s*/, "");
const model = {};
vm.runInNewContext(source, model);

const tree = model.normalizedItems([
  {
    type: "folder",
    name: "Tools",
    children: [{ type: "app", name: "Browser", cmd: "firefox %U" }]
  }
], 0);
assert.equal(model.itemsAt(tree, [0])[0].name, "Browser");
assert.deepEqual(Array.from(model.itemsAt(tree, [9])), []);
const searchEntries = model.entriesFromSearchResults([
  { entry: { id: "org.example.App", name: "Example" }, score: 1 },
  { entry: null, score: 0 },
  { id: "unwrapped-result" }
]);
assert.deepEqual(Array.from(searchEntries, entry => entry.id), ["org.example.App"]);
const updated = model.replaceArrayAt(tree, [0], [
  { type: "app", name: "Terminal", cmd: "foot" }
]);
assert.equal(model.itemsAt(updated, [0])[0].name, "Terminal");
assert.equal(model.itemsAt(tree, [0])[0].name, "Browser");
assert.equal(model.replaceArrayAt(tree, [9], []), tree);
let deepTree = [{ type: "app", name: "Deep app", cmd: "deep-app" }];
for (let depth = 0; depth < 10; depth++) {
  deepTree = [{ type: "folder", name: `Folder ${depth}`, children: deepTree }];
}
assert.equal(model.itemsAt(model.normalizedItems(deepTree), Array(10).fill(0))[0].name, "Deep app");
assert.deepEqual(Array.from(model.parseCommand(`browser --profile "work mode"`)), [
  "browser", "--profile", "work mode"
]);
assert.deepEqual(Array.from(model.parseCommand("browser; touch /tmp/nope")), []);
assert.deepEqual(Array.from(model.parseCommand(`browser "$(touch nope)"`)), [
  "browser", "$(touch nope)"
]);
assert.deepEqual(Array.from(model.parseCommand(`browser "unfinished`)), []);

console.log("Orbit plugin model tests passed");

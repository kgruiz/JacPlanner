import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { _jac } from "../.jac/client/mobile/compiled/jac_prelude.js";

// Build with `jac build --platform web mobile` before testing emitted handlers.
const compiled = readFileSync(
  new URL("../.jac/client/mobile/compiled/mobile/main.js", import.meta.url),
  "utf8",
);
const start = compiled.indexOf("  async function Add()");
const end = compiled.indexOf("  function TaskCard(", start);
const resetStart = compiled.indexOf('"accessibilityLabel": "Add task", "onPress": () => {');
const resetEnd = compiled.indexOf("  }},", resetStart);

if (start < 0 || end < 0 || resetStart < 0 || resetEnd < 0) {
  throw new Error("Build the updated mobile client before running editor tests.");
}

const fields = ["busy", "error", "estimate", "editingId", "title", "course", "dueDate", "priority", "plannedDate", "notes", "plannedTime", "recurrence", "adding", "selectedDate"];
const parameters = fields.map(name => "__jacS_" + name);
const handlers = new Function(
  "_jac", ...parameters, "__jacCallFunction", "TaskResult", "BridgeError", "Keyboard", "Refresh",
  compiled.slice(start, end) + "return { Add, Edit };",
);
const reset = new Function(
  ...parameters,
  compiled.slice(compiled.indexOf("{", resetStart) + 1, resetEnd),
);

function State(value) {
  return { val: value, set(next) { this.val = next; } };
}

class BridgeFailure extends Error {}

function Harness(response = { ok: true }) {
  const defaults = { busy: false, error: "", estimate: "30", editingId: "", title: "Reading", course: "EECS 449", dueDate: "", priority: "medium", plannedDate: "", notes: "Draft", plannedTime: "", recurrence: "daily", adding: true, selectedDate: "2026-10-05" };
  const state = Object.fromEntries(fields.map(name => [name, State(defaults[name])]));
  const values = fields.map(name => state[name]);
  const calls = [];
  let refreshes = 0;
  let dismisses = 0;
  const app = handlers(_jac, ...values, async (name, args) => {
    calls.push({ name, args });

    if (response instanceof Error) {
      throw response;
    }

    return response;
  }, { __from_wire: value => value }, BridgeFailure, { dismiss() { dismisses += 1; } }, async () => { refreshes += 1; });

  return { ...app, state, calls, reset: () => reset(...values), refreshes: () => refreshes, dismisses: () => dismisses };
}

test("editing loads weekly recurrence and sends it with the saved task", async () => {
  const app = Harness();
  app.Edit({ taskId: "weekly", title: "Reading", course: "EECS 449", dueDate: "2026-10-06", priority: "high", estimateMinutes: 45, plannedDate: "2026-10-05", plannedTime: "14:00", recurrence: "weekly", notes: "Chapter 2" });

  expect(app.state.recurrence.val).toBe("weekly");
  expect(app.state.adding.val).toBe(true);
  await app.Add();
  expect(app.calls).toEqual([{ name: "SaveTask", args: { taskId: "weekly", title: "Reading", course: "EECS 449", dueDate: "2026-10-06", priority: "high", estimateMinutes: 45, plannedDate: "2026-10-05", notes: "Chapter 2", plannedTime: "14:00", recurrence: "weekly" } }]);
  expect(app.state.recurrence.val).toBe("none");
  expect(app.state.adding.val).toBe(false);
  expect(app.refreshes()).toBe(1);
  expect(app.dismisses()).toBe(1);
});

test("creation allows empty dates and resets recurrence when opening a fresh draft", async () => {
  const app = Harness();
  await app.Add();

  expect(app.calls[0].args).toMatchObject({ taskId: "", plannedDate: "", dueDate: "", recurrence: "daily" });
  app.state.recurrence.set("weekly");
  app.state.editingId.set("old");
  app.reset();
  expect(app.state.recurrence.val).toBe("none");
  expect(app.state.editingId.val).toBe("");
  expect(app.state.plannedDate.val).toBe("2026-10-05");
  expect(app.state.adding.val).toBe(true);
});

for (const response of [{ ok: false, error: "Cannot save task" }, new BridgeFailure("offline")]) {
  test("a failed save preserves the recurrence and draft: " + (response.error || "bridge failure"), async () => {
    const app = Harness(response);
    await app.Add();

    expect(app.state.recurrence.val).toBe("daily");
    expect(app.state.title.val).toBe("Reading");
    expect(app.state.notes.val).toBe("Draft");
    expect(app.state.adding.val).toBe(true);
    expect(app.state.busy.val).toBe(false);
    expect(app.state.error.val).not.toBe("");
    expect(app.refreshes()).toBe(0);
    expect(app.dismisses()).toBe(0);
  });
}

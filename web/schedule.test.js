import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { _jac } from "../.jac/client/web/compiled/jac_prelude.js";

// Exercise the emitted handler and rendering projection with a deferred bridge call.
const compiled = readFileSync(
  new URL("../.jac/client/web/compiled/web/main.js", import.meta.url),
  "utf8",
);
const scheduleStart = compiled.indexOf("  async function Schedule(");
const scheduleEnd = compiled.indexOf("  function ClearDrag()", scheduleStart);
const clockStart = compiled.indexOf("function ClockValue(");
const clockEnd = compiled.indexOf("function DragMinutes(", clockStart);
const projection = compiled.match(/  let displayedTasks = .*;/)?.[0];
if (scheduleStart < 0 || scheduleEnd < 0 || clockStart < 0 || clockEnd < 0 || !projection) {
  throw new Error("Build the updated web client before running scheduling tests.");
}
const handler = new Function(
  "_jac", "__jacS_busy", "__jacS_error", "__jacS_tasks", "__jacS_pendingSchedule",
  "__jacCallFunction", "TaskResult", "BridgeError",
  compiled.slice(clockStart, clockEnd) + compiled.slice(scheduleStart, scheduleEnd)
    + "return Schedule;",
);
const display = new Function("__jacS_tasks", "__jacS_pendingSchedule", projection + "return displayedTasks;");

function State(value) {
  return { val: value, set(next) { this.val = next; } };
}

class BridgeFailure extends Error {}

function Harness() {
  const original = { taskId: "A", title: "Homework", plannedDate: "2026-10-01", plannedTime: "09:00", estimateMinutes: 30 };
  const other = { ...original, taskId: "B" };
  const tasks = State([original, other]);
  const busy = State(false);
  const error = State("");
  const pending = State(null);
  const calls = [];
  let resolve;
  let reject;
  const response = new Promise((accept, fail) => { resolve = accept; reject = fail; });
  const schedule = handler(_jac, busy, error, tasks, pending, (name, args) => {
    calls.push({ name, args });
    return response;
  }, { __from_wire: value => value }, BridgeFailure);

  return { original, other, tasks, busy, error, pending, calls, resolve, reject, schedule, displayed: () => display(tasks, pending) };
}

test("pending scheduling shows the destination immediately and accepts the authoritative saved task", async () => {
  const app = Harness();
  const saving = app.schedule("A", "2026-10-02", 615);

  expect(app.busy.val).toBe(true);
  expect(app.tasks.val[0]).toBe(app.original);
  expect(app.displayed()[0]).toEqual({ ...app.original, plannedDate: "2026-10-02", plannedTime: "10:15" });
  expect(app.displayed()[1]).toBe(app.other);
  expect(app.calls).toEqual([{ name: "ScheduleTask", args: { taskId: "A", plannedDate: "2026-10-02", plannedTime: "10:15" } }]);
  await app.schedule("A", "2026-10-03", 720);
  expect(app.calls).toHaveLength(1);

  const authoritative = { ...app.original, title: "Saved homework", plannedDate: "2026-10-02", plannedTime: "10:15" };
  app.resolve({ ok: true, task: authoritative });
  await saving;
  expect(app.tasks.val[0]).toBe(authoritative);
  expect(app.displayed()[0]).toBe(authoritative);
  expect(app.pending.val).toBeNull();
  expect(app.busy.val).toBe(false);
});

test("a rejected schedule rolls the displayed position back to the original task", async () => {
  const app = Harness();
  const saving = app.schedule("A", "2026-10-02", 615);
  app.resolve({ ok: false, task: null, error: "Cannot schedule task" });
  await saving;

  expect(app.tasks.val[0]).toBe(app.original);
  expect(app.displayed()[0]).toBe(app.original);
  expect(app.pending.val).toBeNull();
  expect(app.busy.val).toBe(false);
  expect(app.error.val).toBe("Cannot schedule task");
});

test("a bridge failure clears the pending position and preserves the original task", async () => {
  const app = Harness();
  const saving = app.schedule("A", "2026-10-02", 615);
  app.reject(new BridgeFailure("offline"));
  await saving;

  expect(app.tasks.val[0]).toBe(app.original);
  expect(app.displayed()[0]).toBe(app.original);
  expect(app.pending.val).toBeNull();
  expect(app.busy.val).toBe(false);
  expect(app.error.val).toContain("Could not schedule this task");
});

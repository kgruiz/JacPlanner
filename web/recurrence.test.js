import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { _jac } from "../.jac/client/web/compiled/jac_prelude.js";

const compiled = readFileSync(
  new URL("../.jac/client/web/compiled/web/main.js", import.meta.url),
  "utf8",
);
const fields = ["busy", "error", "editing", "taskId", "title", "course", "dueDate", "priority", "recurrence", "estimate", "plannedDate", "plannedTime", "notes"];

function Extract(start, end) {
  const first = compiled.indexOf(start);
  const last = compiled.indexOf(end, first);

  if (first < 0 || last < 0 || !compiled.includes("__jacS_recurrence")) {
    throw new Error("Build the updated web client before running recurrence tests.");
  }

  return compiled.slice(first, last);
}

function Harness() {
  const state = Object.fromEntries(fields.map(name => [name, {
    val: name === "busy" || name === "editing" ? false : "",
    set(value) { this.val = value; },
  }]));
  const calls = [];
  let refreshes = 0;
  const handlers = new Function(
    "_jac", ...fields.map(name => "__jacS_" + name), "__jacCallFunction", "TaskResult", "BridgeError", "Refresh",
    Extract("  function Edit(", "  function NewSlot(")
      + Extract("  async function Save()", "  async function Remove(")
      + "return { Edit, NewTask, Save, Toggle };",
  )(_jac, ...fields.map(name => state[name]), async (name, args) => {
    calls.push({ name, args });
    return { ok: true };
  }, { __from_wire: value => value }, Error, async () => { refreshes += 1; });

  return { state, calls, ...handlers, refreshes: () => refreshes };
}

const task = {
  taskId: "A", title: "Read chapter", course: "EECS 449", dueDate: "2026-10-07",
  priority: "medium", recurrence: "weekly", estimateMinutes: 45,
  plannedDate: "2026-10-06", plannedTime: "10:00", notes: "Chapter 3", completed: false,
};

test("editing a recurring task preserves its recurrence in the save request", async () => {
  const app = Harness();
  app.Edit(task);

  expect(app.state.recurrence.val).toBe("weekly");
  app.state.title.set("Read chapter and notes");
  await app.Save();
  const { completed, ...savedTask } = task;
  expect(app.calls[0].args).toEqual({ ...savedTask, title: "Read chapter and notes" });
  expect(app.state.editing.val).toBe(false);
  expect(app.refreshes()).toBe(1);
});

test("new task resets a previous recurring draft and sends the chosen repeat interval", async () => {
  const app = Harness();
  app.Edit(task);
  app.NewTask();

  expect(app.state.recurrence.val).toBe("none");
  expect(app.state.taskId.val).toBe("");
  expect(app.state.plannedDate.val).toBe("");
  app.state.title.set("Daily review");
  app.state.recurrence.set("daily");
  await app.Save();
  expect(app.calls[0].args.recurrence).toBe("daily");
  expect(app.calls[0].args.taskId).toBe("");
  app.NewTask();
  expect(app.state.recurrence.val).toBe("none");
});

test("completion refreshes the task list so a generated successor can appear", async () => {
  const app = Harness();
  await app.Toggle(task);

  expect(app.calls).toEqual([{ name: "SetCompleted", args: { taskId: "A", completed: true } }]);
  expect(app.refreshes()).toBe(1);
  expect(app.state.busy.val).toBe(false);
});

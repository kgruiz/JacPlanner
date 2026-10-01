import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { _jac } from "../.jac/client/web/compiled/jac_prelude.js";

// Build with `jac build --as client web` so these exercise the emitted Jac helpers.
const compiled = readFileSync(
  new URL("../.jac/client/web/compiled/web/main.js", import.meta.url),
  "utf8",
);
const { EventStyle, ShiftDate, WeekStart, ResizeMinutes, IsOverdue, ScheduleLabel, DisplayDate, TimeLabel, EventTimeVisible, EventCourseVisible, DragMinutes, ClockValue } = new Function(
  "_jac",
  compiled.slice(compiled.indexOf("function Today()"), compiled.indexOf("function Field(props)"))
    + "return { EventStyle, ShiftDate, WeekStart, ResizeMinutes, IsOverdue, ScheduleLabel, DisplayDate, TimeLabel, EventTimeVisible, EventCourseVisible, DragMinutes, ClockValue };",
)(_jac);

function Task(taskId, plannedTime, estimateMinutes, plannedDate = "2026-09-30") {
  return { taskId, plannedTime, estimateMinutes, plannedDate };
}

test("consecutive short tasks stay in separate visible lanes", () => {
  const tasks = [Task("A", "09:00", 1), Task("B", "09:01", 1), Task("C", "09:02", 1)];
  const styles = tasks.map(task => EventStyle(task, tasks));

  expect(new Set(styles.map(style => style.left)).size).toBe(3);
  expect(styles.every(style => style.height === "28px")).toBe(true);
});

test("isolated events regain full width after overlapping groups", () => {
  const tasks = [Task("A", "09:00", 60), Task("B", "09:30", 60), Task("C", "14:00", 60)];

  expect(EventStyle(tasks[0], tasks).width).toBe("calc(50% - 10px)");
  expect(EventStyle(tasks[2], tasks).width).toBe("calc(100% - 10px)");
});

test("late minimum-height events fit inside the day and remain separate", () => {
  const tasks = [Task("A", "23:30", 29), Task("B", "23:59", 1)];
  const styles = tasks.map(task => EventStyle(task, tasks));

  for (const style of styles) {
    expect(parseFloat(style.top) + parseFloat(style.height)).toBeLessThanOrEqual(1536);
  }

  expect(styles[0].left).not.toBe(styles[1].left);
});

test("abutting hour-long tasks and tasks on another day do not share columns", () => {
  const tasks = [Task("A", "09:00", 60), Task("B", "10:00", 60), Task("C", "09:00", 60, "2026-10-01")];

  expect(tasks.every(task => EventStyle(task, tasks).width === "calc(100% - 10px)")).toBe(true);
});

test("week navigation handles daylight saving, leap day, and year rollover", () => {
  expect(ShiftDate("2026-03-08", 7)).toBe("2026-03-15");
  expect(ShiftDate("2026-11-01", 7)).toBe("2026-11-08");
  expect(ShiftDate("2028-02-29", 7)).toBe("2028-03-07");
  expect(ShiftDate("2026-12-31", 7)).toBe("2027-01-07");
  expect(WeekStart("2026-11-01")).toBe("2026-10-26");
});


test("resize preserves a click, snaps movement, and clamps at both day boundaries", () => {
  expect(ResizeMinutes(Task("A", "09:00", 31), 0)).toBe(31);
  expect(ResizeMinutes(Task("A", "09:00", 1), 2)).toBe(1);
  expect(ResizeMinutes(Task("A", "09:00", 60), 16)).toBe(75);
  expect(ResizeMinutes(Task("A", "09:00", 60), -16)).toBe(45);
  expect(ResizeMinutes(Task("A", "09:00", 60), -1000)).toBe(1);
  expect(ResizeMinutes(Task("A", "23:59", 1), 1000)).toBe(1);
  expect(ResizeMinutes(Task("A", "23:30", 15), 1000)).toBe(30);
});

test("only incomplete tasks with a past deadline are overdue", () => {
  const task = { dueDate: "2026-09-30", completed: false };
  expect(IsOverdue(task, "2026-10-01")).toBe(true);
  expect(IsOverdue({ ...task, dueDate: "2026-10-01" }, "2026-10-01")).toBe(false);
  expect(IsOverdue({ ...task, dueDate: "" }, "2026-10-01")).toBe(false);
  expect(IsOverdue({ ...task, completed: true }, "2026-10-01")).toBe(false);
});

test("date and scheduling labels distinguish missing deadlines and times", () => {
  expect(DisplayDate("2026-10-01")).toBe("10/01/2026");
  expect(TimeLabel(0)).toBe("12:00 AM");
  expect(TimeLabel(13 * 60 + 15)).toBe("1:15 PM");
  expect(ScheduleLabel({ plannedDate: "", plannedTime: "" })).toBe("Not scheduled");
  expect(ScheduleLabel({ plannedDate: "2026-10-01", plannedTime: "" })).toBe("Scheduled 10/01/2026 (time not set)");
  expect(ScheduleLabel({ plannedDate: "2026-10-01", plannedTime: "13:15" })).toBe("Scheduled 10/01/2026 at 1:15 PM");
});

test("short events omit details before they can be cut off", () => {
  expect(EventTimeVisible(Task("A", "09:00", 15))).toBe(false);
  expect(EventTimeVisible(Task("A", "09:00", 30))).toBe(false);
  expect(EventTimeVisible(Task("A", "09:00", 60))).toBe(true);
  expect(EventCourseVisible(Task("A", "09:00", 60))).toBe(false);
  expect(EventCourseVisible(Task("A", "09:00", 90))).toBe(true);
});


test("drag preview snaps to quarters, respects the grab offset, and retains duration", () => {
  expect(DragMinutes(10 * 64 + 16, 0, 60)).toBe(615);
  expect(DragMinutes(10 * 64 + 16, 16, 60)).toBe(600);
  expect(DragMinutes(-50, 0, 60)).toBe(0);
  expect(DragMinutes(24 * 64, 0, 90)).toBe(1350);
  expect(DragMinutes(24 * 64, 0, 1)).toBe(1439);
  expect(ClockValue(615)).toBe("10:15");
  expect(ClockValue(0)).toBe("00:00");
  expect(ClockValue(1439)).toBe("23:59");
});

function PointerHarness(excluded = false) {
  const state = value => ({ val: value, set(next) { this.val = next; } });
  const busy = state(false), resizing = state("");
  const dragged = state(""), day = state(""), minutes = state(0);
  const listeners = new Map(), sourceListeners = new Map();
  const timers = [], saves = [];
  let captured = false, inside = true;
  const add = (map, name, handler) => {
    if (!map.has(name)) map.set(name, new Set());
    map.get(name).add(handler);
  };
  const remove = (map, name, handler) => map.get(name)?.delete(handler);
  const grid = { dataset: { day: "2026-10-02" }, getBoundingClientRect: () => ({ top: 0 }) };
  const source = {
    getBoundingClientRect: () => ({ top: 640 }),
    setPointerCapture() { captured = true; },
    hasPointerCapture: () => captured,
    releasePointerCapture() { captured = false; },
    addEventListener: (name, handler) => add(sourceListeners, name, handler),
    removeEventListener: (name, handler) => remove(sourceListeners, name, handler),
  };
  const document = {
    elementFromPoint: () => inside ? { closest: () => grid } : null,
    addEventListener: (name, handler) => add(listeners, name, handler),
    removeEventListener: (name, handler) => remove(listeners, name, handler),
  };
  const start = compiled.indexOf("  function ClearDrag() {");
  const ending = compiled.indexOf("  function DragTask(", start);
  const setup = new Function("_jac", "__jacS_busy", "__jacS_resizingId", "__jacS_draggedId", "__jacS_dragDay", "__jacS_dragMinutes", "document", "window", "DragMinutes", "Schedule",
    compiled.slice(start, ending) + "return PointerStart;");
  const PointerStart = setup(_jac, busy, resizing, dragged, day, minutes, document,
    { setTimeout: fn => timers.push(fn) }, DragMinutes, (...args) => saves.push(args));
  PointerStart({ button: 0, pointerId: 1, clientX: 100, clientY: 650,
    currentTarget: source, target: { closest: () => excluded ? source : null } }, Task("A", "10:00", 60));
  function fire(name, props = {}) {
    const event = { type: name, pointerId: 1, clientX: 100, clientY: 650,
      prevented: false, stopped: false, preventDefault() { this.prevented = true; },
      stopPropagation() { this.stopped = true; }, ...props };
    for (const handler of [...(listeners.get(name) ?? [])]) handler(event);
    return event;
  }
  return { dragged, day, minutes, saves, fire, captured: () => captured,
    outside: () => { inside = false; },
    flush: () => { while (timers.length) timers.shift()(); },
    listeners: () => [...listeners.values(), ...sourceListeners.values()].reduce((sum, set) => sum + set.size, 0) };
}

test("pointer movement under the threshold preserves click to edit", () => {
  const app = PointerHarness();
  app.fire("pointermove", { clientX: 103 });
  expect(app.dragged.val).toBe("");
  expect(app.captured()).toBe(false);
  app.fire("pointerup");
  expect(app.fire("click").prevented).toBe(false);
  expect(app.saves).toEqual([]);
  expect(app.listeners()).toBe(0);
});

test("pointer move previews and saves the same snapped time after release", () => {
  const app = PointerHarness();
  app.fire("pointermove", { clientY: 714 });
  expect(app.dragged.val).toBe("A");
  expect(app.day.val).toBe("2026-10-02");
  expect(app.minutes.val).toBe(660);
  expect(app.captured()).toBe(true);
  app.fire("pointerup", { clientY: 714 });
  expect(app.saves).toEqual([["A", "2026-10-02", 660]]);
  expect(app.fire("click").prevented).toBe(true);
  app.flush();
  expect(app.captured()).toBe(false);
  expect(app.dragged.val).toBe("");
  expect(app.listeners()).toBe(0);
});

test("Escape cancels movement and suppresses the release click until pointerup", () => {
  const app = PointerHarness();
  app.fire("pointermove", { clientY: 714 });
  expect(app.fire("keydown", { key: "Escape" }).prevented).toBe(true);
  app.flush();
  expect(app.dragged.val).toBe("");
  expect(app.captured()).toBe(false);
  app.fire("pointerup");
  expect(app.fire("click").prevented).toBe(true);
  app.flush();
  expect(app.fire("click").prevented).toBe(false);
  expect(app.saves).toEqual([]);
  expect(app.listeners()).toBe(0);
});

test("outside release and pointer cancellation clear previews without saving", () => {
  for (const action of ["outside", "pointercancel"]) {
    const app = PointerHarness();
    app.fire("pointermove", { clientY: 714 });
    if (action === "outside") { app.outside(); app.fire("pointerup"); }
    else app.fire("pointercancel");
    app.flush();
    expect(app.saves).toEqual([]);
    expect(app.dragged.val).toBe("");
    expect(app.listeners()).toBe(0);
  }
  expect(PointerHarness(true).listeners()).toBe(0);
});

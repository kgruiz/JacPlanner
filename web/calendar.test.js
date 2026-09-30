import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { _jac } from "../.jac/client/web/compiled/jac_prelude.js";

// Build with `jac build --as client web` so these exercise the emitted Jac helpers.
const compiled = readFileSync(
  new URL("../.jac/client/web/compiled/web/main.js", import.meta.url),
  "utf8",
);
const { EventStyle, ShiftDate, WeekStart } = new Function(
  "_jac",
  compiled.slice(compiled.indexOf("function Today()"), compiled.indexOf("function Field(props)"))
    + "return { EventStyle, ShiftDate, WeekStart };",
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
